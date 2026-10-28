extends SceneTree
## WOW 0.16: warsztat, bilans materialowy, rezerwacje i zapis.
const WORKSHOP = preload("res://scripts/automated_workshop.gd")
const REGISTRY = preload("res://scripts/recipe_registry.gd")

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("WORKSHOP SMOKE: " + message)
	quit(1)

func _run() -> void:
	var workshop = WORKSHOP.new()
	root.add_child(workshop)
	await process_frame
	if workshop.active_recipe == null or workshop.recipe_id != "forge_steel":
		_fail("Nie wczytano receptury stali")
		return
	if workshop.set_recipe_id("smelt_iron"):
		_fail("Warsztat zaakceptowal recepture huty")
		return
	if workshop.deposit_resource("metal", 5) != 5:
		_fail("Nie mozna dostarczyc metalu")
		return
	workshop.power_enabled = false
	workshop._process(20.0)
	if workshop.total_cycles != 0:
		_fail("Warsztat produkuje bez energii")
		return
	workshop.power_enabled = true
	workshop.set_production_target(1)
	workshop._process(5.0)
	if workshop.total_cycles != 1 or workshop.input_buffer.quantity("metal") != 3 or workshop.output_buffer.quantity("steel") != 1:
		_fail("Warsztat naruszyl bilans 2 metal -> stal")
		return
	workshop._process(10.0)
	if workshop.total_cycles != 1:
		_fail("Zignorowano limit cykli")
		return
	if workshop.withdraw_resource("steel", 1) != 1:
		_fail("Nie mozna odebrac stali")
		return
	if workshop.deposit_resource("steel", 1) != 1 or not workshop.set_recipe_id("assemble_electronics"):
		_fail("Nie mozna przejsc do receptury elektroniki")
		return
	workshop.set_production_target(1)
	if not workshop.output_buffer.reserve_input("robot:delivery", "electronics", 40):
		_fail("Nie mozna zarezerwowac odbioru")
		return
	workshop._process(8.0)
	if workshop.total_cycles != 1 or workshop.input_buffer.quantity("steel") != 1:
		_fail("Warsztat zuzywa material przy pelnym/zarezerwowanym wyjsciu")
		return
	workshop.output_buffer.cancel_input("robot:delivery")
	workshop._process(8.0)
	if workshop.total_cycles != 2 or workshop.total_electronics != 1 or workshop.input_buffer.quantity("steel") != 0 or workshop.input_buffer.quantity("metal") != 2:
		_fail("Bilans elektroniki jest niepoprawny")
		return
	var saved: Dictionary = workshop.to_dict()
	var loaded = WORKSHOP.new()
	root.add_child(loaded)
	loaded.from_dict(JSON.parse_string(JSON.stringify(saved)))
	if loaded.recipe_id != "assemble_electronics" or loaded.output_buffer.quantity("electronics") != 1 or loaded.total_cycles != 2:
		_fail("Odczyt warsztatu zgubil produkty lub stan")
		return
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("recipe_id")
	loaded.from_dict(legacy)
	if loaded.recipe_id != "forge_steel":
		_fail("Brak bezpiecznego fallback receptury")
		return
	print("WORKSHOP SMOKE OK: power, limits, two recipes, reservations, save/load")
	workshop.queue_free()
	loaded.queue_free()
	await process_frame
	quit(0)
