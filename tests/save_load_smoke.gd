extends SceneTree
## WOW 0.13: zapisz w trakcie transportu, wczytaj, porownaj bilans oraz pozycje pakietow.
const MANAGER = preload("res://scripts/save_game_manager.gd")
const TEST_FILE: String = "user://wow-save-smoke.json"


func _initialize() -> void:
	call_deferred("_run_test")


func _fail(message: String) -> void:
	push_error("SAVE TEST: " + message)
	quit(1)


func _run_test() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var manager = MANAGER.new()
	var iron = game.get_node("IronOreDeposit")
	game._spawn_planned_structure({"kind": "mine", "site": game.IRON_DEPOSIT_POSITION, "quarters": 1})
	game._spawn_planned_structure({"kind": "smelter", "site": Vector3(18.0, 0.0, 22.0), "quarters": 2})
	game._spawn_planned_structure({"kind": "solar", "site": Vector3(12.0, 0.0, -15.0), "quarters": 1})
	game._spawn_planned_structure({"kind": "battery", "site": Vector3(-17.0, 0.0, -2.0), "quarters": 0})
	game.battery_banks[0].stored_kwh = 4.375
	game.factory_mine.stock = 28
	game.factory_smelter.ore_stock = game.factory_smelter.MAX_ORE
	game.factory_smelter.metal_stock = 9
	game.landing_rocket.health = 77.0
	game.resource_totals["wood"] = 43
	game.resource_totals["stone"] = 22
	game.resource_totals["metal"] = 13
	game.planet_env.select_planet("Kepler")
	var worker = game.workers[1]
	worker.carried_type = "metal"
	worker.carried_amount = 7
	worker.energy = 44.4
	worker.state = worker.WorkState.IDLE

	var endpoints: Array[Vector3] = [Vector3(-30, 0, 4), Vector3(-22, 0, 4)]
	var road: Array[Vector2i] = game.roads.route(endpoints, game.navigation)
	if road.size() < 2:
		_fail("Nie mozna przygotowac drogi")
		return
	game.roads.commit(road)

	var point := Vector3(-35, 0, 20)
	if not game._can_place_structure_at(point, "forester"):
		point = _find_site(game, "forester")
	if point == Vector3.INF:
		_fail("Brak miejsca na hologram")
		return
	game.blueprints.add_blueprint("forester", point, 3)

	var raw_route: Array[Vector3] = game.navigation.find_conveyor_route(
		game.factory_mine.global_position, game.factory_mine.get_access_radius(),
		game.factory_smelter.global_position, game.factory_smelter.get_access_radius())
	if raw_route.size() < 2:
		_fail("Nie znaleziono trasy tasmy do testu")
		return
	var belt = game.CONVEYOR_SCRIPT.new()
	belt.setup("ore", game.factory_mine, game.factory_smelter, raw_route)
	game.add_child(belt)
	game.ore_conveyor = belt
	belt.powered = true
	belt._process(0.82)
	belt._process(0.65)
	if belt.packets.is_empty():
		_fail("Nie utworzono pakietu w ruchu")
		return
	var distance_before: float = float(belt.packets[0]["distance"])
	var mass_before: int = _ore_balance(game)
	var carried_before: int = worker.carried_amount
	var state_before: Dictionary = manager.to_dict(game)
	if not manager.validate(state_before):
		var ids: Array = []
		for category in ["resources", "structures", "robots", "belts"]:
			for row in state_before[category]:
				ids.append("%s:%s" % [category, row.get("save_id", "<missing>")])
		_fail("Nieprawidlowy format: %s | planet=%s | counts=%s" % [
			str(ids), str(state_before["planet"]), str(game.resource_totals)])
		return
	if not manager.save_file(game, TEST_FILE):
		_fail("Nie mozna zapisac pliku testowego")
		return
	var disk: Dictionary = manager.read_file(TEST_FILE)
	if disk.is_empty():
		_fail("Nie mozna wczytac pliku z dysku")
		return
	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	await process_frame
	if not manager.from_dict(fresh, disk):
		_fail("Odtwarzanie sceny odrzucone")
		return
	if fresh.ore_conveyor == null or fresh.ore_conveyor.packets.size() != 1:
		_fail("Zniknal ladunek na tasmociagu po wczytaniu")
		return
	if absf(float(fresh.ore_conveyor.packets[0]["distance"]) - distance_before) > 0.0001:
		_fail("Pakiet stracil postep transportu")
		return
	var visual: Node3D = fresh.ore_conveyor.packets[0]["visual"]
	var expected: Vector3 = fresh.ore_conveyor._at_distance(distance_before) + Vector3(0, 0.74, 0)
	if visual.position.distance_to(expected) > 0.005:
		_fail("Paczka zawisla poza tasma po odczycie")
		return
	if fresh.factory_smelter.ore_stock != game.factory_smelter.ore_stock:
		_fail("Nie odtworzono pelnego bufora huty")
		return
	if _ore_balance(fresh) != mass_before:
		_fail("Bilans rud zmienil sie przez save/load")
		return
	if fresh.workers[1].carried_amount != carried_before or absf(fresh.workers[1].energy - 44.4) > 0.001:
		_fail("Robot utracil energie lub ladunek")
		return
	if fresh.resource_totals != game.resource_totals or fresh.planet_env.current_planet != "Kepler":
		_fail("Rozbieznosc magazynu/planety: fresh=%s source=%s planet=%s" % [
			str(fresh.resource_totals), str(game.resource_totals), fresh.planet_env.current_planet
		])
		return
	if fresh.blueprints.entries.size() != 1 or fresh.roads.built_cells.size() != road.size():
		_fail("Nie odtworzono drog i projektow")
		return
	if absf(fresh.battery_banks[0].stored_kwh - 4.375) > 0.0001:
		_fail("Nie odtworzono poziomu akumulatora")
		return

	# Wylaczamy proces pozostalych maszyn na chwile kontrolowanej symulacji.
	fresh.factory_mine.power_enabled = false
	fresh.factory_smelter.power_enabled = false
	fresh.ore_conveyor.powered = true
	var pending: int = int(fresh.ore_conveyor.packets[0]["amount"])
	fresh.ore_conveyor._process(fresh.ore_conveyor.route_length / 7.0 + 1.0)
	if fresh.ore_conveyor.packets.is_empty() or int(fresh.ore_conveyor.packets[0]["amount"]) != pending:
		_fail("Paczka zniknela podczas oczekiwania przed pelnym buforem")
		return
	# Symulacja przetopienia zwalnia miejsce bez niszczenia masy:
	# 2 jednostki rudy zamieniamy na 1 sztabke metalu.
	fresh.factory_smelter.ore_stock -= pending
	fresh.factory_smelter.metal_stock += pending / 2
	fresh.ore_conveyor._process(0.1)
	if int(fresh.ore_conveyor.total_transferred) < pending:
		_fail("Paczka nie wznowila dostawy po zwolnieniu bufora")
		return
	if _ore_balance(fresh) != mass_before:
		_fail("Bilans przed=%d po=%d mine=%d smelter=%d parcels=%s" % [
			mass_before, _ore_balance(fresh), fresh.factory_mine.stock,
			fresh.factory_smelter.ore_stock, str(fresh.ore_conveyor.to_dict()["packets"])])
		return

	# Stan graniczny: po wyczerpaniu i zniknieciu zloza budynek kopalni
	# nadal musi przezyc odczyt, bez prob dereferencji nieistniejacego Node.
	var finished_ore = fresh.get_node_or_null("IronOreDeposit")
	if finished_ore != null:
		fresh.remove_child(finished_ore)
		finished_ore.queue_free()
	fresh.factory_mine.ore_source = null
	var exhausted_data: Dictionary = manager.to_dict(fresh)
	var recovered = load("res://scenes/main.tscn").instantiate()
	root.add_child(recovered)
	if not manager.from_dict(recovered, exhausted_data):
		_fail("Nie mozna wczytac kolonii z wyczerpanym zlozem")
		return
	if recovered.factory_mine == null or recovered.factory_mine.has_ore():
		_fail("Ekstraktor po odczycie pustego zloza ma niepoprawny stan")
		return
	recovered.queue_free()

	var damaged: Dictionary = disk.duplicate(true)
	damaged["schema_version"] = 999
	if manager.validate(damaged):
		_fail("Brak kontroli wersji zapisu")
		return
	var garbage := FileAccess.open(TEST_FILE, FileAccess.WRITE)
	garbage.store_string("{unreadable")
	garbage.close()
	if not manager.read_file(TEST_FILE).is_empty():
		_fail("Uszkodzony plik nie zostal odrzucony")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))
	print("SAVE LOAD SMOKE OK: disk, structures, roads, workers, full buffer and in-flight cargo conserved")
	fresh.queue_free()
	game.queue_free()
	await process_frame
	quit(0)


func _ore_balance(game) -> int:
	var total: int = int(game.factory_mine.stock) + int(game.factory_smelter.ore_stock) + int(game.factory_smelter.metal_stock) * 2
	for parcel in game.ore_conveyor.packets:
		total += int(parcel["amount"])
	return total


func _find_site(game, kind: String) -> Vector3:
	for z in range(-35, 35, 5):
		for x in range(-35, 35, 5):
			var p := Vector3(float(x), 0, float(z))
			if game._can_place_structure_at(p, kind):
				return p
	return Vector3.INF
