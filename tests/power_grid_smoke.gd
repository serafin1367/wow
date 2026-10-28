extends SceneTree
## WOW 0.9: energetyka, bilans, magazynowanie oraz efekty maszyn.

func _initialize() -> void:
	call_deferred("_run_test")


func _fail(message: String) -> void:
	push_error("POWER TEST: " + message)
	quit(1)


func _run_test() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._update_factory_power()
	if absf(game.grid_generation_kw - 8.4) > 0.01:
		_fail("Rakieta nie zasila kolonii 8,4 kW")
		return

	var panel = load("res://scripts/solar_array.gd").new()
	panel.position = Vector3(12, 0, -15)
	game.add_child(panel)
	game.solar_arrays.append(panel)
	game._connect_power_node(panel)
	game._update_factory_power()
	if absf(game.grid_generation_kw - 12.4) > 0.01:
		_fail("Nowy panel nie dodal 4 kW")
		return
	var yaw_before: float = panel.tracker.rotation.y
	panel._process(3.0)
	if absf(panel.tracker.rotation.y - yaw_before) <= 0.01:
		_fail("Panel nie obraca sie i nie sledzi swiatla")
		return

	var bank = load("res://scripts/battery_bank.gd").new()
	bank.position = Vector3(-17, 0, -2)
	game.add_child(bank)
	game.battery_banks.append(bank)
	game._connect_power_node(bank)
	game._update_factory_power()
	game._tick_battery_grid(30.0)
	if bank.stored_kwh < 1.0 or bank.stored_kwh > bank.CAPACITY_KWH:
		_fail("Akumulator nie gromadzi nadwyzki PV")
		return

	var deposit = game.get_node("IronOreDeposit")
	var mine = load("res://scripts/automated_mine.gd").new()
	mine.position = deposit.position
	mine.ore_source = deposit
	game.add_child(mine)
	game.factory_mine = mine
	var furnace = load("res://scripts/automated_smelter.gd").new()
	furnace.position = Vector3(15, 0, 19)
	game.add_child(furnace)
	game.factory_smelter = furnace
	furnace.ore_stock = 10
	game._connect_power_node(mine)
	game._connect_power_node(furnace)
	game._update_factory_power()
	if not mine.power_enabled or not furnace.power_enabled:
		_fail("Nowa generacja nie zasila kopalni i huty")
		return
	mine._process(1.0)
	var rotation_before: float = mine.machine_visual.drill_motor.rotation.y
	mine.machine_visual._process(0.5)
	if mine.machine_visual.drill_motor.rotation.y <= rotation_before:
		_fail("Glowica kopalni nie obraca sie podczas wydobycia")
		return
	furnace._process(0.1)
	furnace.machine_visual._process(0.2)
	if not furnace.machine_visual.sparks.active:
		_fail("Huta nie generuje iskier podczas przetapiania")
		return
	furnace.machine_visual.sparks._process(0.1)
	if not furnace.machine_visual.sparks.sparks[0].visible:
		_fail("Iskry nie sa widoczne")
		return

	game.landing_rocket.health = 5.0
	game._update_factory_power()
	if game.battery_draw_kw <= 0.01:
		_fail("Siec nie pobiera energii z akumulatora po awarii PV")
		return
	var energy_before: float = bank.stored_kwh
	game._tick_battery_grid(5.0)
	if bank.stored_kwh >= energy_before:
		_fail("Rozladowanie nie pomniejszylo zapasu energii")
		return

	var connected: int = 0
	for cable in game.power_cables:
		if cable.get_node_or_null("CableSheath") != null:
			connected += 1
	if connected < 4:
		_fail("Instalacje nie zostaly polaczone widocznymi przewodami")
		return

	print("POWER GRID SMOKE OK: motorized solar, battery, cables, rotating drill, smelter sparks")
	game.queue_free()
	await process_frame
	quit(0)
