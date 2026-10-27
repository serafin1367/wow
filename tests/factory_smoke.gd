extends SceneTree
## WOW 0.6: test zachowania ilosci surowcow, poboru mocy i cyklu transportu.
## Nie wymaga klikania ani renderowania interfejsu.


func _initialize() -> void:
	call_deferred("_run_test")


func _fail(message: String) -> void:
	push_error("FACTORY TEST: " + message)
	quit(1)


func _run_test() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame

	var deposit = game.get_node_or_null("IronOreDeposit")
	if deposit == null or deposit.remaining < 100:
		_fail("Brak zloza zelaza")
		return

	var mine = load("res://scripts/automated_mine.gd").new()
	mine.ore_source = deposit
	mine.position = deposit.position
	game.add_child(mine)
	game.factory_mine = mine
	var smelter = load("res://scripts/automated_smelter.gd").new()
	smelter.position = Vector3(16.0, 0.0, 20.0)
	game.add_child(smelter)
	game.factory_smelter = smelter
	game._update_factory_power()

	if not mine.power_enabled or not smelter.power_enabled:
		_fail("Fabryka nie dostaje energii na starcie")
		return
	if game.unused_power_kw < 0.0:
		_fail("Bilans energii ujemny")
		return

	# Symulujemy 12 sekund pracy ekstraktora bez realnego uplywu czasu.
	var left_before: int = deposit.remaining
	mine._process(12.0)
	var produced: int = mine.stock
	if produced != 32 or deposit.remaining != left_before - produced:
		_fail("Wydobycie ma niewlasciwy bilans ilosci")
		return

	# Robot transportowy wykonuje zadanie kopalnia -> huta -> magazyn.
	var hauler = game.workers[1]
	hauler.set_physics_process(false)
	hauler.command_factory_route(mine, smelter, game.navigation, game.DEPOT_POSITION)
	if not hauler.factory_route_active:
		_fail("Transportowiec nie dostal trasy")
		return

	hauler.state = hauler.WorkState.WAIT_FACTORY_PICKUP
	hauler._process_factory_wait(0.5)
	if hauler.carried_type != "iron_ore" or hauler.carried_amount <= 0:
		_fail("Robot nie pobral rudy")
		return
	var loaded: int = hauler.carried_amount
	hauler.state = hauler.WorkState.WAIT_FACTORY_OUTPUT
	hauler._process_factory_wait(0.5)
	if hauler.carried_amount != 0 or smelter.ore_stock != loaded:
		_fail("Ruda nie dotarla do huty")
		return

	smelter._process(18.0)
	var smelted: int = smelter.metal_stock
	if smelted <= 0 or smelted * 2 > loaded:
		_fail("Bledna receptura 2 rudy -> 1 metal")
		return

	hauler.state = hauler.WorkState.WAIT_FACTORY_OUTPUT
	hauler._process_factory_wait(0.5)
	if hauler.carried_type != "metal" or hauler.carried_amount != smelted:
		_fail("Robot nie odebral gotowego metalu")
		return

	var inventory_before: int = int(game.resource_totals["metal"])
	hauler.state = hauler.WorkState.TO_FACTORY_DEPOT
	hauler._finish_route()
	if int(game.resource_totals["metal"]) != inventory_before + smelted:
		_fail("Dostawa metalu nie powiekszyla magazynu")
		return
	if hauler.carried_amount != 0:
		_fail("Robot nie zwolnil ladowni")
		return

	# Uszkodzenie PV ponizej progu ma wstrzymac wydobycie.
	game.landing_rocket.health = 20.0
	game._update_factory_power()
	if mine.power_enabled or smelter.power_enabled:
		_fail("Fabryka dziala bez wymaganej energii")
		return
	var ore_when_off: int = mine.stock
	mine._process(6.0)
	if mine.stock != ore_when_off:
		_fail("Kopalnia produkuje bez energii")
		return

	print("FACTORY SMOKE OK: iron ore -> robot -> smelter -> metal -> warehouse + power")
	game.queue_free()
	await process_frame
	quit(0)
