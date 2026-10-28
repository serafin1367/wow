extends SceneTree
## WOW 0.14: niedostepna trasa nie blokuje rezerwacji na zawsze.
const MANAGER = preload("res://scripts/logistics_manager.gd")

class BlockedNavigation:
	extends RefCounted
	func find_path(_from: Vector3, _to: Vector3) -> Array[Vector3]:
		var empty: Array[Vector3] = []
		return empty


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("RECOVERY TEST: " + message)
	quit(1)


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._spawn_planned_structure({"kind": "mine", "site": game.IRON_DEPOSIT_POSITION, "quarters": 0})
	var target := Vector3(8, 0, 20)
	if not game._can_place_structure_at(target, "depot"):
		for x in range(-32, 32, 4):
			for z in range(-32, 32, 4):
				if game._can_place_structure_at(Vector3(x, 0, z), "depot"):
					target = Vector3(x, 0, z)
					break
	game._spawn_planned_structure({"kind": "depot", "site": target, "quarters": 0})
	var mine = game.factory_mine
	var depot = game.logistics_depots[0]
	mine.set_meta("save_id", "factory:mine")
	mine.stock = 12
	var manager = MANAGER.new()
	var job_id: String = manager.submit(mine, depot, "iron_ore", 12, 100)
	if job_id.is_empty():
		_fail("Brak zlecenia testowego")
		return
	var hauler = game.workers[1]
	hauler.state = hauler.WorkState.IDLE
	hauler.factory_route_active = false
	var fleet: Array = [hauler]
	var blocked = BlockedNavigation.new()
	for retry in range(MANAGER.MAX_ROUTE_FAILURES):
		manager.dispatch(fleet, blocked)
	if not manager.get_job(job_id).is_empty() or mine.output_buffer.available_output("iron_ore") != 12:
		_fail("Trasa niedostepna nie zwolnila zarezerwowanej rudy")
		return
	if depot.cargo.available_input("iron_ore") != depot.CAPACITY_PER_RESOURCE:
		_fail("Zawieszona dostawa pozostawila niepotrzebna rezerwacje miejsca")
		return
	if manager.submit(mine, depot, "iron_ore", 12) != "":
		_fail("Po awarii trasy brakuje okresu oczekiwania na ponowna probe")
		return
	var snapshot: Dictionary = manager.to_dict()
	var restored = MANAGER.new()
	var lookup: Dictionary = {"factory:mine": mine, str(depot.get_meta("save_id", "")): depot}
	restored.from_dict(JSON.parse_string(JSON.stringify(snapshot)), lookup)
	if restored.lane_cooldowns.is_empty():
		_fail("Odczyt nie zachowal okresu blokady trasy")
		return
	for i in range(MANAGER.LANE_COOLDOWN_TICKS):
		var no_workers: Array = []
		restored.dispatch(no_workers, blocked)
	var new_id: String = restored.submit(mine, depot, "iron_ore", 12, 90)
	if new_id.is_empty():
		_fail("Po odczekaniu nie wznowiono dostepnosci zlecen")
		return
	if not restored.set_priority(new_id, 172):
		_fail("Nie ustawiono priorytetu")
		return
	if not restored.cancel(new_id, fleet):
		_fail("Nie mozna bezpiecznie anulowac oczekujacego zlecenia")
		return
	if mine.stock != 12 or mine.output_buffer.available_output("iron_ore") != 12:
		_fail("Anulowanie nie oddalo rudy do bufora zrodla")
		return
	var later: String = restored.submit(mine, depot, "iron_ore", 12, 90)
	if later.is_empty() or int(restored.get_job(later)["priority"]) != 172:
		_fail("Nowe zlecenie nie odziedziczylo priorytetu ustawionego w UI")
		return
	print("LOGISTICS RECOVERY SMOKE OK: blocked route rollback, cooldown, save, retries and priorities")
	game.queue_free()
	await process_frame
	quit(0)
