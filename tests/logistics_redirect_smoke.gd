extends SceneTree
## WOW 0.14: loaded cargo retarget keeps exactly one receiver reservation.
const SAVE = preload("res://scripts/save_game_manager.gd")


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("REDIRECT TEST: " + message)
	quit(1)


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._spawn_planned_structure({"kind": "mine", "site": game.IRON_DEPOSIT_POSITION, "quarters": 0})
	var sites: Array[Vector3] = []
	for x in range(5, 35, 5):
		for z in range(12, 35, 5):
			var at := Vector3(float(x), 0, float(z))
			if game._can_place_structure_at(at, "depot"):
				game._spawn_planned_structure({"kind": "depot", "site": at, "quarters": 0})
				sites.append(at)
				if sites.size() == 2:
					break
		if sites.size() == 2:
			break
	if sites.size() != 2:
		_fail("Nie mozna wybudowac dwoch magazynow")
		return
	var mine = game.factory_mine
	mine.stock = 20
	mine.power_enabled = false
	var a = game.logistics_depots[0]
	var b = game.logistics_depots[1]
	mine.set_meta("save_id", "factory:mine")
	var id: String = game.logistics_manager.submit(mine, a, "iron_ore", 20, 110)
	if id.is_empty():
		_fail("Brak podstawowego zlecenia transportowego")
		return
	var robot = game.workers[1]
	robot.state = robot.WorkState.IDLE
	robot.factory_route_active = false
	robot.set_physics_process(false)
	var job = game.logistics_manager.get_job(id)
	if not robot.command_logistics_job(job, mine, a, game.logistics_manager, game.navigation):
		_fail("Robot nie moze dotrzec do zrodla")
		return
	job["status"] = "assigned"
	job["worker_id"] = "worker:1"
	robot._finish_route()
	if robot.carried_amount != 20:
		_fail("Nie pobrano surowca z zarezerwowanego bufora")
		return
	if b.deposit_resource("iron_ore", 120) != 120:
		_fail("Nie przygotowano pelnego bufora docelowego")
		return
	var before: int = mine.stock + robot.carried_amount + a.cargo.quantity("iron_ore") + b.cargo.quantity("iron_ore")
	if game.logistics_manager.reroute_picked(id, b, game.workers):
		_fail("Przekierowano ladunek do pelnego bufora")
		return
	if a.cargo.available_input("iron_ore") != 100:
		_fail("Nieudany transfer utracil stara rezerwacje")
		return
	b.withdraw_resource("iron_ore", 120)
	before -= 120
	if not game.logistics_manager.reroute_picked(id, b, game.workers):
		_fail("Nie mozna przekierowac transportu do wolnego magazynu")
		return
	if a.cargo.available_input("iron_ore") != 120 or b.cargo.available_input("iron_ore") != 100:
		_fail("Nowy cel nie przejal jednoznacznej rezerwacji")
		return
	var saved: Dictionary = SAVE.new().to_dict(game)
	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	if not SAVE.new().from_dict(fresh, saved):
		_fail("Nie mozna wznowic przekierowanej dostawy")
		return
	var restored_job = fresh.logistics_manager.get_job(id)
	if restored_job.is_empty() or str(restored_job["destination_id"]) != str(b.get_meta("save_id")):
		_fail("Po odczycie ladunek ma stary cel")
		return
	var restored_robot = fresh.workers[1]
	restored_robot.set_physics_process(false)
	restored_robot.state = restored_robot.WorkState.TO_LOGISTICS_DELIVERY
	restored_robot._finish_route()
	if restored_robot.carried_amount != 0 or fresh.logistics_depots[1].cargo.quantity("iron_ore") != 20:
		_fail("Po przekierowaniu dostawa nie trafila do nowego magazynu")
		return
	var after: int = fresh.factory_mine.stock + restored_robot.carried_amount
	for hub in fresh.logistics_depots:
		after += hub.cargo.quantity("iron_ore")
	if before != after:
		_fail("Zgubiono/duplikowano material: %d -> %d" % [before, after])
		return
	print("LOGISTICS REDIRECT SMOKE OK: full buffer rollback, re-route, preserved cargo and saved destination")
	game.queue_free()
	fresh.queue_free()
	await process_frame
	quit(0)
