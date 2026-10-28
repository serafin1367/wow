extends SceneTree
## WOW 0.16: dane receptur, bilans z Inventory, rezerwacje i wsteczny zapis.
const REGISTRY = preload("res://scripts/recipe_registry.gd")
const RECIPE = preload("res://scripts/production_recipe.gd")
const SMELTER = preload("res://scripts/automated_smelter.gd")
const INVENTORY = preload("res://scripts/inventory.gd")


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
	if mine.size() != 1 or mine[0].output_amount("iron_ore") != 4 or not mine[0].requires_external_source:
		_fail("Brak definicji kopalni wymagajacej skonczonego zloza")
		return
	var unsourced_ore = INVENTORY.new("test:ore")
	unsourced_ore.configure("iron_ore", 50)
	if mine[0].process_once(null, unsourced_ore) or unsourced_ore.quantity("iron_ore") != 0:
		_fail("Rejestr pozwala wytwarzac rude bez jej wydobywania ze zloza")
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
	invalid = iron.to_dict()
	invalid["inputs"] = {"iron_ore": 2}
	invalid["outputs"] = {"iron_ore": 2}
	var same_input_output = RECIPE.from_dict(invalid)
	if same_input_output == null or same_input_output.output_amount("iron_ore") != 2:
		_fail("Parser gubi wyjscie, gdy wejscie i wyjscie sa identyczne")
		return

	# WOW 0.16: drugi lancuch — metal -> stal -> elektronika.
	# Receptury sa danymi, warsztat zostanie podlaczony w nastepnym kroku.
	var steel_recipe = REGISTRY.get_recipe("forge_steel")
	var electronics_recipe = REGISTRY.get_recipe("assemble_electronics")
	if steel_recipe == null or electronics_recipe == null:
		_fail("Brakuje definicji nowych produktow")
		return
	if steel_recipe.machine_kind != "workshop" or electronics_recipe.machine_kind != "workshop":
		_fail("Nowe receptury przypisano niewlasciwej maszynie")
		return
	if steel_recipe.input_amount("metal") != 2 or steel_recipe.output_amount("steel") != 1:
		_fail("Niepoprawny bilans stali")
		return
	if electronics_recipe.input_amount("steel") != 1 or electronics_recipe.input_amount("metal") != 1 or electronics_recipe.output_amount("electronics") != 1:
		_fail("Niepoprawny bilans elektroniki")
		return
	var workshop_input = INVENTORY.new("test:workshop:input")
	var workshop_output = INVENTORY.new("test:workshop:output")
	workshop_input.configure("metal", 20, 3)
	workshop_input.configure("steel", 20)
	workshop_output.configure("steel", 1)
	workshop_output.configure("electronics", 1)
	if not steel_recipe.process_once(workshop_input, workshop_output):
		_fail("Nie wyprodukowano stali mimo dostepnych surowcow")
		return
	if workshop_input.quantity("metal") != 1 or workshop_output.quantity("steel") != 1:
		_fail("Produkcja stali zlamala bilans materialowy")
		return
	if steel_recipe.process_once(workshop_input, workshop_output) or workshop_input.quantity("metal") != 1:
		_fail("Produkcja zuzyla surowce przy braku skladnikow/miejsca")
		return
	if workshop_output.pull("steel", 1) != 1 or workshop_input.push("steel", 1) != 1:
		_fail("Nie mozna przekazac stali do drugiego etapu")
		return
	if not workshop_output.reserve_input("reserved-electronics", "electronics", 1):
		_fail("Nie mozna zarezerwowac wyjscia elektroniki")
		return
	if electronics_recipe.process_once(workshop_input, workshop_output):
		_fail("Elektronika powstala mimo rezerwacji bufora wyjsciowego")
		return
	if workshop_input.quantity("metal") != 1 or workshop_input.quantity("steel") != 1:
		_fail("Zniknely skladniki przy zablokowanym wyjsciu")
		return
	workshop_output.cancel_input("reserved-electronics")
	if not electronics_recipe.process_once(workshop_input, workshop_output):
		_fail("Nie wznowiono produkcji elektroniki po zwolnieniu wyjscia")
		return
	if workshop_input.quantity("metal") != 0 or workshop_input.quantity("steel") != 0 or workshop_output.quantity("electronics") != 1:
		_fail("Elektronika naruszyla bilans metal + stal -> elektronika")
		return
	var electronic_json = RECIPE.from_dict(JSON.parse_string(JSON.stringify(electronics_recipe.to_dict())))
	if electronic_json == null or electronic_json.input_amount("steel") != 1:
		_fail("Niepoprawny JSON nowej receptury")
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
