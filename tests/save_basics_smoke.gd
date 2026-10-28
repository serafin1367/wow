extends SceneTree
## S1/S2 — format JSON v1, zasoby, planeta, pozycja, obrot i
## ochrona ostatniego poprawnego slotu przed nieudana serializacja.
const MANAGER = preload("res://scripts/save_game_manager.gd")
const SAVE_PATH: String = "user://wow-s1-s2-smoke.json"


func _initialize() -> void:
	call_deferred("_test")


func _fail(message: String) -> void:
	push_error("SAVE BASICS TEST: " + message)
	quit(1)


func _invalid_json_path(value: Variant, at: String = "root") -> String:
	if value == null or value is String or value is bool or value is int or value is float:
		return ""
	if value is Array:
		for i in range(value.size()):
			var invalid: String = _invalid_json_path(value[i], "%s[%d]" % [at, i])
			if not invalid.is_empty():
				return invalid
		return ""
	if value is Dictionary:
		for key in value.keys():
			if not (key is String):
				return "%s: unexpected key type %s" % [at, type_string(typeof(key))]
			var invalid: String = _invalid_json_path(value[key], "%s.%s" % [at, str(key)])
			if not invalid.is_empty():
				return invalid
		return ""
	return "%s: unexpected value type %s" % [at, type_string(typeof(value))]


func _test() -> void:
	var manager = MANAGER.new()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.planet_env.select_planet("Kepler")
	game.resource_totals["wood"] = 37
	game.resource_totals["gold"] = 19
	game.resource_totals["stone"] = 23
	game.resource_totals["metal"] = 11
	game._spawn_planned_structure({"kind": "smelter", "site": Vector3(18.0, 0.0, 22.0), "quarters": 1})
	if game.factory_smelter == null:
		_fail("Nie powstal budynek testowy")
		return
	game.factory_smelter.ore_stock = 8
	game.factory_smelter.metal_stock = 3

	var snapshot: Dictionary = manager.to_dict(game)
	if int(snapshot.get("schema_version", -1)) != 1 or not manager.validate(snapshot):
		_fail("Niepoprawny schemat JSON v1")
		return
	var bad_path: String = _invalid_json_path(snapshot)
	if not bad_path.is_empty():
		_fail("Snapshot nie jest zgodny z JSON: " + bad_path)
		return
	var record: Dictionary = {}
	for building in snapshot["structures"]:
		if building.get("kind", "") == "smelter":
			record = building
			break
	if record.is_empty() or str(record.get("save_id", "")) != "factory:smelter":
		_fail("Brak stabilnego save_id dla budynku")
		return
	if record.get("type_id", "") != "building:smelter" or int(record.get("object_version", -1)) != 1:
		_fail("Brak jawnego identyfikatora typu lub wersji obiektu")
		return
	if not (record.get("position", null) is Array) or record["position"].size() != 3:
		_fail("Pozycja budynku nie jest zapisana jako [x, y, z]")
		return
	if absf(float(record.get("rotation_y", 0.0)) - PI / 2.0) > 0.00001:
		_fail("Zapis gubi obrot budynku")
		return
	var json_value: Variant = JSON.parse_string(JSON.stringify(snapshot))
	if not manager.validate(json_value):
		_fail("Round-trip Dictionary -> JSON -> Dictionary narusza schemat")
		return
	if not manager.save_file(game, SAVE_PATH):
		_fail("Nie mozna zapisac poprawnego snapshotu")
		return
	var disk: Dictionary = manager.read_file(SAVE_PATH)
	if disk.is_empty() or disk["resources_total"] != snapshot["resources_total"]:
		_fail("Plik JSON nie odtworzyl stanu zasobow")
		return
	var good_file: String = FileAccess.get_file_as_string(SAVE_PATH)
	# Dalszy zapis z ujemnym stanem musi zawiesc, a poprzedni
	# poprawny plik musi pozostac nietkniety.
	game.resource_totals["wood"] = -10
	if manager.save_file(game, SAVE_PATH):
		_fail("Niepoprawny snapshot zostal zapisany na dysk")
		return
	if FileAccess.get_file_as_string(SAVE_PATH) != good_file:
		_fail("Nieudany zapis nadpisal ostatni poprawny slot")
		return
	game.resource_totals["wood"] = 37
	var invalid: Dictionary = disk.duplicate(true)
	invalid["schema_version"] = 99
	if manager.validate(invalid):
		_fail("Obca wersja schematu zostala zaakceptowana")
		return

	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	await process_frame
	if not manager.from_dict(fresh, disk):
		_fail("Nie mozna odtworzyc nowej sceny z pliku v1")
		return
	if fresh.planet_env.current_planet != "Kepler" or fresh.resource_totals["wood"] != 37:
		_fail("Nie odtworzono planety lub zasobow")
		return
	if fresh.factory_smelter == null or fresh.factory_smelter.ore_stock != 8 or fresh.factory_smelter.metal_stock != 3:
		_fail("Nie odtworzono stanow maszyny")
		return
	if absf(fresh.factory_smelter.rotation.y - PI / 2.0) > 0.00001:
		_fail("Nie odtworzono orientacji budynku")
		return
	if fresh.factory_smelter.global_position.distance_to(Vector3(18.0, 0.0, 22.0)) > 0.01:
		_fail("Nie odtworzono pozycji budynku")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("SAVE BASICS SMOKE OK: schema v1, JSON safe, resources, planet, building rotation and safe overwrite")
	game.queue_free()
	fresh.queue_free()
	await process_frame
	quit(0)
