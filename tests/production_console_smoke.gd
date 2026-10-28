extends SceneTree
## WOW 0.15: sterowanie z HUD, realna produkcja, alerty, focus, zapis.

func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("PRODUCTION CONSOLE TEST: " + message)
	quit(1)


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._spawn_planned_structure({"kind": "mine", "site": game.IRON_DEPOSIT_POSITION, "quarters": 0})
	game._spawn_planned_structure({"kind": "smelter", "site": Vector3(18, 0, 22), "quarters": 0})
	var mine = game.factory_mine
	var smelter = game.factory_smelter
	if mine == null or smelter == null or not mine.has_ore():
		_fail("Nie utworzono poprawnej fabryki")
		return
	var panel = game.hud.production_panel
	if panel == null or panel.visible:
		_fail("Brak panelu produkcji lub panel zaslania ekran")
		return
	game._toggle_production_panel()
	if not panel.visible or panel.machines_container.get_child_count() != 2:
		_fail("Panel V nie pokazuje kopalni i huty")
		return
	panel.pause_requested.emit("mine")
	if not mine.production_paused:
		_fail("Pauza nie trafila z UI do kopalni")
		return
	mine.power_enabled = true
	var initial: int = mine.stock
	mine._process(8.0)
	if mine.stock != initial:
		_fail("Zatrzymana kopalnia nadal produkuje")
		return
	panel.queue_requested.emit("mine", 2)
	panel.pause_requested.emit("mine")
	if mine.production_paused or mine.cycles_remaining != 2:
		_fail("Wznowienie i limit cykli nie zostaly przyjete")
		return
	mine.power_enabled = true
	mine._process(10.0)
	if mine.stock != initial + 8 or mine.cycles_remaining != 0:
		_fail("Limit 2 cykli wydobycia nie jest przestrzegany")
		return
	game._update_factory_power()
	if mine.power_enabled:
		_fail("Zakonczona kolejka nadal pobiera energie")
		return
	panel.queue_requested.emit("smelter", 3)
	smelter.ore_stock = 10
	smelter.power_enabled = true
	smelter._process(10.0)
	if smelter.metal_stock != 3 or smelter.ore_stock != 4 or smelter.cycles_remaining != 0:
		_fail("Huta nie wykonala dokladnie trzech cykli")
		return
	var snapshot: Dictionary = game._production_snapshot()
	if int(snapshot["busy_robots"]) + int(snapshot["idle_robots"]) + int(snapshot["charging_robots"]) != game.workers.size():
		_fail("Obciazenie robotow nie obejmuje calej floty")
		return
	if snapshot["machines"].size() != 2:
		_fail("Raport produkcji nie pokazuje dwoch maszyn")
		return
	panel.focus_requested.emit("mine")
	if game.selected_structure != mine:
		_fail("Alarm nie zaznaczyl wskazanej maszyny")
		return
	mine.set_production_target(-1)
	mine.production_paused = false
	mine.power_enabled = false
	var alerts: Dictionary = game._production_snapshot()
	var has_power_alarm: bool = false
	for alert in alerts["alarms"]:
		if str(alert["kind"]) == "mine" and str(alert["message"]).contains("ENERGII"):
			has_power_alarm = true
	if not has_power_alarm:
		_fail("Brak alarmu braku zasilania")
		return
	# Wylacz proces przed testem round-trip, zeby parametry nie zmienialy sie w trakcie.
	game.set_process(false)
	var saved: Dictionary = game.SAVE_SCRIPT.new().to_dict(game)
	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	if not game.SAVE_SCRIPT.new().from_dict(fresh, saved):
		_fail("Nie mozna odczytac gry z zakonczona kolejka produkcji")
		return
	if fresh.factory_smelter.cycles_remaining != 0 or fresh.factory_smelter.metal_stock != 3:
		_fail("Po zapisie huta zgubila plan produkcji lub wytworzony metal")
		return
	if fresh.factory_mine.cycles_remaining != -1 or fresh.factory_mine.production_paused:
		_fail("Po zapisie kopalnia zgubila produkcje ciagla")
		return
	game._toggle_production_panel()
	if panel.visible:
		_fail("Panel nie zamknal sie po ponownym V")
		return
	print("PRODUCTION CONSOLE SMOKE OK: pause, finite queues, no idle power, robots, focus, alarms, save/load")
	game.queue_free()
	fresh.queue_free()
	await process_frame
	quit(0)
