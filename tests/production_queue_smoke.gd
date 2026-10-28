extends SceneTree
## WOW 0.15: kilka partii jednej receptury, priorytety i save/load.

func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("PRODUCTION QUEUE TEST: " + message)
	quit(1)


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._spawn_planned_structure({"kind": "mine", "site": game.IRON_DEPOSIT_POSITION, "quarters": 0})
	game._spawn_planned_structure({"kind": "smelter", "site": Vector3(18, 0, 22), "quarters": 0})
	var mine = game.factory_mine
	var smelter = game.factory_smelter
	mine.set_production_target(1)
	if not mine.enqueue_production(3, 10) or not mine.enqueue_production(2, 190):
		_fail("Nie mozna zaplanowac dwoch zamowien")
		return
	mine.power_enabled = true
	mine._process(1.5)
	if mine.cycles_remaining != 2 or mine.production_queue.size() != 1 or int(mine.production_queue[0]["cycles"]) != 3:
		_fail("Wybrano nieprawidlowa partie: priorytet 190 powinien byc pierwszy")
		return
	var data: Dictionary = game.SAVE_SCRIPT.new().to_dict(game)
	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	if not game.SAVE_SCRIPT.new().from_dict(fresh, data):
		_fail("Nie mozna odczytac zaplanowanej kolejki")
		return
	fresh.set_process(false)
	var restored = fresh.factory_mine
	if restored.production_queue.size() != 1 or restored.cycles_remaining != 2:
		_fail("Zapis utracil druga partie")
		return
	restored.power_enabled = true
	restored._process(3.0)
	if restored.cycles_remaining != 3 or not restored.production_queue.is_empty():
		_fail("Nie przeszedl do drugiego zamowienia po zakonczeniu pierwszego")
		return
	restored._process(4.5)
	if restored.cycles_remaining != 0 or restored.stock != 24 or restored.total_extracted != 24:
		_fail("Zgubiono albo powielono rude w kolejkach produkcji")
		return
	restored._process(4.5)
	if restored.stock != 24:
		_fail("Fabryka kontynuuje produkcje po oproznieniu kolejki")
		return

	# Huta: trzy partie o roznych priorytetach i zachowanie receptury 2:1.
	smelter.set_production_target(1)
	smelter.ore_stock = 24
	smelter.power_enabled = true
	if not smelter.enqueue_production(2, 40) or not smelter.enqueue_production(3, 180):
		_fail("Nie dodano zlecen huty")
		return
	smelter._process(3.0)
	if smelter.cycles_remaining != 3 or smelter.production_queue.size() != 1:
		_fail("Wysoki priorytet zamowienia huty nie zadzialal")
		return
	smelter._process(9.0)
	if smelter.cycles_remaining != 2:
		_fail("Huta nie przeszla do drugiego zamowienia")
		return
	smelter._process(6.0)
	if smelter.cycles_remaining != 0 or smelter.ore_stock != 12 or smelter.metal_stock != 6:
		_fail("Niezgodnosc rudy i metalu po trzech partiach huty")
		return
	game._enqueue_machine_production("smelter", 4, 175)
	if smelter.cycles_remaining != 4:
		_fail("UI gry nie uruchomilo kolejnej partii")
		return
	print("PRODUCTION QUEUE SMOKE OK: priority order, two factories, save/load, inventory and finite batches")
	game.queue_free()
	fresh.queue_free()
	await process_frame
	quit(0)
