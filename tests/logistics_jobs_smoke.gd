extends SceneTree
## WOW 0.14: robot bierze zlecenie ze wspolnego bufora, zachowuje je w zapisie,
## po odczycie kontynuuje i dostarcza bez powielenia materialow.
const SAVE = preload("res://scripts/save_game_manager.gd")
const TEST_PATH: String = "user://wow-logistics-smoke.json"


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("JOB TEST: " + message)
	quit(1)


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._spawn_planned_structure({"kind": "mine", "site": game.IRON_DEPOSIT_POSITION, "quarters": 0})
	game._spawn_planned_structure({"kind": "smelter", "site": Vector3(18, 0, 22), "quarters": 0})
	var hub_location := Vector3(8, 0, 19)
	if not game._can_place_structure_at(hub_location, "depot"):
		hub_location = _find_site(game)
	if hub_location == Vector3.INF:
		_fail("Brak wolnego miejsca na test logistyki")
		return
	game._spawn_planned_structure({"kind": "depot", "site": hub_location, "quarters": 0})
	var depot = game.logistics_depots[0]
	game.factory_mine.stock = 20
	game.factory_mine.power_enabled = false
	game.factory_smelter.power_enabled = false
	var robot = game.workers[1]
	robot.set_physics_process(false)
	robot.command_move([])
	game._tick_logistics(0.9)
	var job: Dictionary = {}
	for candidate in game.logistics_manager.jobs:
		if candidate["source_id"] == "factory:mine" and candidate["resource_type"] == "iron_ore":
			job = candidate
			break
	if job.is_empty():
		_fail("Nie utworzono zlecenia kopalnia -> depot")
		return
	if job["amount"] != 20:
		_fail("Nie zarezerwowano calego dostepnego ladunku")
		return
	if job["status"] != "assigned" or robot.logistics_job_id != job["id"]:
		_fail("Brak przydzialu zlecenia wolnemu transportowcowi")
		return
	if game.factory_mine.output_buffer.available_output("iron_ore") != 0:
		_fail("Ta sama ruda pozostala dostepna dla tasmy")
		return
	# Symulujemy dotarcie robota do miejsca zaladunku.
	robot._finish_route()
	if robot.carried_amount != 20 or robot.carried_type != "iron_ore":
		_fail("Odebranie rudy przez robota zmienilo ilosc ladunku")
		return
	if depot.cargo.available_input("iron_ore") != depot.CAPACITY_PER_RESOURCE - 20:
		_fail("Zniknela rezerwacja miejsca w magazynie")
		return
	if game.logistics_manager.get_job(job["id"])["status"] != "picked":
		_fail("Zlecenie nie przeszlo w etap transportu")
		return

	var mass_before: int = _balance(game)
	var manager = SAVE.new()
	if not manager.save_file(game, TEST_PATH):
		_fail("Nie mozna zapisac aktywnego zlecenia")
		return
	var snapshot: Dictionary = manager.read_file(TEST_PATH)
	if snapshot.is_empty():
		_fail("Nie mozna odczytac zapisanych zlecen")
		return
	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	if not manager.from_dict(fresh, snapshot):
		_fail("Brak odtwarzania aktywnego transportu")
		return
	var fresh_worker = fresh.workers[1]
	fresh_worker.set_physics_process(false)
	if fresh_worker.logistics_job_id != job["id"] or fresh_worker.carried_amount != 20:
		_fail("Wczytanie zgubilo robotowi zlecenie lub ladunek")
		return
	if fresh.logistics_manager.get_job(job["id"])["status"] != "picked":
		_fail("Menedzer utracil stan w trakcie jazdy")
		return
	if _balance(fresh) != mass_before:
		_fail("Nie zachowano bilansu rudy po odczycie transportu")
		return
	var final_depot = fresh.logistics_depots[0]
	if final_depot.cargo.available_input("iron_ore") != final_depot.CAPACITY_PER_RESOURCE - 20:
		_fail("Zapis usunal rezerwacje miejsca przy odbiorcy")
		return
	# Symulujemy dojazd do magazynu po przywroceniu sciezki A*.
	fresh_worker.state = fresh_worker.WorkState.TO_LOGISTICS_DELIVERY
	fresh_worker._finish_route()
	if fresh_worker.carried_amount != 0 or final_depot.cargo.quantity("iron_ore") != 20:
		_fail("Po odczycie robot nie dostarczyl zarezerwowanego ladunku")
		return
	if not fresh.logistics_manager.get_job(job["id"]).is_empty():
		_fail("Ukonczone zlecenie nadal blokuje rezerwacje")
		return
	if _balance(fresh) != mass_before:
		_fail("Dostawa powielila lub zgubila zasoby")
		return
	# W kolejnej turze utworz przeplyw depot -> huta.
	fresh._tick_logistics(0.9)
	var second: Dictionary = {}
	for candidate in fresh.logistics_manager.jobs:
		if candidate["source_id"] == str(final_depot.get_meta("save_id", "")) and candidate["destination_id"] == "factory:smelter":
			second = candidate
	if second.is_empty():
		_fail("Magazyn nie generuje dostaw do huty")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("LOGISTICS JOB SMOKE OK: reserved robot pickup, saved journey, delivery and depot to smelter")
	game.queue_free()
	fresh.queue_free()
	await process_frame
	quit(0)


func _balance(game) -> int:
	var total: int = game.factory_mine.stock + game.factory_smelter.ore_stock
	for depot in game.logistics_depots:
		total += depot.cargo.quantity("iron_ore")
	for worker in game.workers:
		if worker.carried_type == "iron_ore":
			total += worker.carried_amount
	return total


func _find_site(game) -> Vector3:
	for z in range(10, 34, 4):
		for x in range(6, 29, 4):
			var site := Vector3(float(x), 0, float(z))
			if game._can_place_structure_at(site, "depot"):
				return site
	return Vector3.INF
