extends SceneTree
## WOW 0.16: dane receptur, bilans z Inventory, rezerwacje i wsteczny zapis.
const REGISTRY = preload("res://scripts/recipe_registry.gd")
const RECIPE = preload("res://scripts/production_recipe.gd")
const SMELTER = preload("res://scripts/automated_smelter.gd")


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("RECIPE TEST: " + message)
	quit(1)


func _run() -> void:
	if not REGISTRY.validate_registry():
		_fail("Niepoprawne definicje w RecipeRegistry")
		return
	var ids: Array[String] = REGISTRY.all_ids()
	if ids.size() < 2 or not ids.has("smelt_iron") or not ids.has("mine_iron_ore"):
		_fail("Rejestr nie zawiera podstawowych receptur")
		return
	var iron = REGISTRY.get_recipe("smelt_iron")
	if iron == null or iron.machine_kind != "smelter":
		_fail("Nie mozna pobrac receptury huty")
		return
	if iron.input_amount("iron_ore") != 2 or iron.output_amount("metal") != 1:
		_fail("Zmieniono bilans dotychczasowej huty 2:1")
		return
	if absf(iron.duration_seconds - 3.0) > 0.001 or absf(iron.power_kw - 2.5) > 0.001:
		_fail("Zmieniono czas lub pobor mocy huty")
		return
	var mine = REGISTRY.recipes_for_machine("mine")
	if mine.size() != 1 or mine[0].output_amount("iron_ore") != 4:
		_fail("Brak danych receptury kopalni")
		return
	if REGISTRY.get_recipe("unknown") != null or not REGISTRY.recipes_for_machine("unknown").is_empty():
		_fail("Rejestr przyjmuje nieznana recepture lub maszyne")
		return
	# Katalog jest niezalezny od mutacji obiektu zwroconego przez get_recipe().
	iron.inputs["iron_ore"] = 999
	if REGISTRY.get_recipe("smelt_iron").input_amount("iron_ore") != 2:
		_fail("Wywolujacy zmienil globalna definicje receptury")
		return
	iron = REGISTRY.get_recipe("smelt_iron")
	var roundtrip = RECIPE.from_dict(JSON.parse_string(JSON.stringify(iron.to_dict())))
	if roundtrip == null or roundtrip.input_amount("iron_ore") != 2:
		_fail("Nie mozna serializowac definicji przez JSON")
		return
	var invalid: Dictionary = iron.to_dict()
	invalid["inputs"] = {"iron_ore": 2.5}
	if RECIPE.from_dict(invalid) != null:
		_fail("Receptura dopuszcza ulamkowe zuzycie materialu")
		return
	invalid = iron.to_dict()
	invalid["outputs"] = {"metal": -1}
	if RECIPE.from_dict(invalid) != null:
		_fail("Receptura dopuszcza produkcje o ujemnym bilansie")
		return

	var smelter = SMELTER.new()
	root.add_child(smelter)
	await process_frame
	if smelter.active_recipe == null or smelter.recipe_id != "smelt_iron":
		_fail("Huta nie zostala podlaczona do rejestru")
		return
	if smelter.set_recipe_id("mine_iron_ore") or smelter.set_recipe_id("nonexistent"):
		_fail("Huta zaakceptowala recepture kopalni lub nieznany identyfikator")
		return
	smelter.power_enabled = true
	smelter.ore_stock = 10
	smelter._process(3.0)
	if smelter.ore_stock != 8 or smelter.metal_stock != 1 or smelter.total_smelted != 1:
		_fail("Huta nie przetwarza 2 rudy -> 1 metal w jednym cyklu")
		return
	# Wolne miejsce 39 jest zarezerwowane na dostawe: huta nie moze
	# go uzyc, nawet jesli fizycznie bufor metalu nie jest pelny.
	if not smelter.output_buffer.reserve_input("incoming-metal", "metal", 39):
		_fail("Nie mozna ustawic rezerwacji bufora wyjsciowego")
		return
	smelter._process(3.0)
	if smelter.ore_stock != 8 or smelter.metal_stock != 1:
		_fail("Huta zuzyla rude mimo zarezerwowanego wyjscia")
		return
	smelter.output_buffer.cancel_input("incoming-metal")
	if not smelter.input_buffer.reserve_output("robot-pickup", "iron_ore", 7):
		_fail("Nie mozna zarezerwowac rudy dla robota")
		return
	smelter._process(3.0)
	if smelter.ore_stock != 8 or smelter.metal_stock != 1:
		_fail("Huta zuzyla rude zarezerwowana przez robota")
		return
	smelter.input_buffer.cancel_output("robot-pickup")
	smelter._process(3.0)
	if smelter.ore_stock != 6 or smelter.metal_stock != 2 or smelter.total_smelted != 2:
		_fail("Nie wznowiono przetapiania po zwolnieniu rezerwacji")
		return

	var saved: Dictionary = smelter.to_dict()
	if saved.get("recipe_id", "") != "smelt_iron":
		_fail("W zapisie brakuje recipe_id")
		return
	var loaded = SMELTER.new()
	root.add_child(loaded)
	loaded.from_dict(JSON.parse_string(JSON.stringify(saved)))
	if loaded.recipe_id != "smelt_iron" or loaded.ore_stock != 6 or loaded.metal_stock != 2:
		_fail("Odczyt huty zgubil recepture lub stan buforow")
		return
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("recipe_id")
	loaded.from_dict(legacy)
	if loaded.recipe_id != "smelt_iron":
		_fail("Stary zapis z WOW 0.15 bez recipe_id nie jest kompatybilny")
		return
	var foreign: Dictionary = saved.duplicate(true)
	foreign["recipe_id"] = "missing_recipe"
	loaded.from_dict(foreign)
	if loaded.recipe_id != "smelt_iron":
		_fail("Niepoprawny recipe_id narzucil obca recepture")
		return
	print("RECIPE REGISTRY SMOKE OK: JSON, independent definitions, 2:1 smelting, reservations and legacy save")
	smelter.queue_free()
	loaded.queue_free()
	await process_frame
	quit(0)
