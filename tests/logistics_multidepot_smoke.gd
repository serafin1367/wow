extends SceneTree
## WOW 0.14: dwa magazyny rezerwuja wspolne wyjscie kopalni bez duplikacji.


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("MULTIDEPOT TEST: " + message)
	quit(1)


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._spawn_planned_structure({"kind": "mine", "site": game.IRON_DEPOSIT_POSITION, "quarters": 0})
	game._spawn_planned_structure({"kind": "smelter", "site": Vector3(18, 0, 22), "quarters": 0})
	var positions: Array[Vector3] = []
	for z in range(10, 36, 4):
		for x in range(3, 32, 4):
			var at := Vector3(float(x), 0.0, float(z))
			if game._can_place_structure_at(at, "depot"):
				positions.append(at)
				game._spawn_planned_structure({"kind": "depot", "site": at, "quarters": 0})
				if positions.size() == 2:
					break
		if positions.size() == 2:
			break
	if positions.size() != 2:
		_fail("Nie znaleziono dwoch miejsc magazynowych")
		return
	game.factory_mine.stock = 30
	game.factory_mine.power_enabled = false
	game.factory_smelter.power_enabled = false
	game.workers[1].set_physics_process(false)
	var cleared: Array[Vector3] = []
	game.workers[1].command_move(cleared)
	game._tick_logistics(0.9)
	var ids: Dictionary = {}
	var reserved: int = 0
	for job in game.logistics_manager.jobs:
		if job["source_id"] == "factory:mine":
			reserved += int(job["amount"])
			ids[job["destination_id"]] = true
	if ids.size() != 2 or reserved != 30:
		_fail("Dwa magazyny nie podzielily dostepnej rudy: %d, %s" % [reserved, str(ids)])
		return
	if game.factory_mine.output_buffer.available_output("iron_ore") != 0:
		_fail("Ruda zostala przydzielona dwukrotnie")
		return
	var one = game.logistics_depots[0]
	var two = game.logistics_depots[1]
	if one.get_meta("save_id") == two.get_meta("save_id") or one.cargo.save_id == two.cargo.save_id:
		_fail("Dwa magazyny otrzymaly ten sam identyfikator")
		return
	var save = game.SAVE_SCRIPT.new()
	var snapshot: Dictionary = save.to_dict(game)
	if not save.validate(snapshot):
		_fail("Niepoprawny snapshot aktywnych zlecen z dwoma magazynami")
		return
	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	if not save.from_dict(fresh, snapshot):
		_fail("Nie mozna odtworzyc wielu magazynow")
		return
	if fresh.logistics_depots.size() != 2 or fresh.logistics_manager.jobs.size() != game.logistics_manager.jobs.size():
		_fail("Zniknal magazyn lub zlecenie po odczycie")
		return
	if fresh.factory_mine.output_buffer.available_output("iron_ore") != 0:
		_fail("Odczyt zwolnil rezerwacje i dopuszcza duplikacje")
		return
	print("MULTIDEPOT SMOKE OK: two warehouses share ore reservations, independent IDs, persisted jobs")
	fresh.queue_free()
	game.queue_free()
	await process_frame
	quit(0)
