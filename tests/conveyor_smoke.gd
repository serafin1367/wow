extends SceneTree
## WOW 0.7: test tras A*, bilansu materialu, automatycznych tasmiociagow
## i wylaczenia linii przy niedoborze energii.


func _initialize() -> void:
	call_deferred("_run_test")


func _fail(message: String) -> void:
	push_error("CONVEYOR TEST: " + message)
	quit(1)


func _run_test() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var deposit = game.get_node("IronOreDeposit")
	var mine = load("res://scripts/automated_mine.gd").new()
	mine.position = deposit.position
	mine.ore_source = deposit
	game.add_child(mine)
	game.factory_mine = mine
	deposit.visible = false
	deposit.collision_layer = 0
	game.navigation.block_circle(Vector2(mine.position.x, mine.position.z), mine.get_access_radius())

	var smelter = load("res://scripts/automated_smelter.gd").new()
	smelter.position = Vector3(18.0, 0.0, 22.0)
	game.add_child(smelter)
	game.factory_smelter = smelter
	game.navigation.block_circle(Vector2(smelter.position.x, smelter.position.z), smelter.get_access_radius())
	game._update_factory_power()

	game.resource_totals["metal"] = 30
	game._build_conveyor("ore")
	if game.ore_conveyor == null or game.ore_conveyor.path_points.size() < 2:
		_fail("Nie utworzono tasmy pomiedzy kopalnia i huta")
		return
	if int(game.resource_totals["metal"]) != 25:
		_fail("Nie pobrano 5 metalu na tasme rudy")
		return

	game._build_conveyor("metal")
	if game.metal_conveyor == null or game.metal_conveyor.path_points.size() < 2:
		_fail("Nie utworzono tasmy pomiedzy huta i magazynem")
		return
	if int(game.resource_totals["metal"]) != 17:
		_fail("Nie pobrano 8 metalu na tasme metalu")
		return
	var ore_link = game.ore_conveyor
	var metal_link = game.metal_conveyor
	if not ore_link.powered or not metal_link.powered:
		_fail("Brak mocy na dwie tasmy przy mocy poczatkowej statku")
		return

	# Osobna symulacja: testujemy przeplyw bez uplywu czasu sceny.
	var left_before: int = deposit.remaining
	mine._process(24.0)
	var extracted: int = left_before - deposit.remaining
	if extracted <= 0:
		_fail("Kopalnia nie wydobyla rudy")
		return

	# Kilka sekund pracy: ruda na tasmie, 2 rudy -> 1 metal.
	for i in range(300):
		ore_link._process(0.2)
		smelter._process(0.2)
		metal_link._process(0.2)

	var metal_produced: int = int(game.resource_totals["metal"]) - 17
	if ore_link.total_transferred <= 0:
		_fail("Tasma rudy nie dostarczyla zadnej paczki")
		return
	if metal_link.total_transferred <= 0 or metal_produced <= 0:
		_fail("Tasma metalu nie dostarczyla wyrobu do magazynu")
		return

	var ore_in_flight: int = 0
	for p in ore_link.packets:
		ore_in_flight += int(p["amount"])
	var metal_in_flight: int = 0
	for p in metal_link.packets:
		metal_in_flight += int(p["amount"])
	# Kazda sztabka to dokladnie dwie jednostki zuzytej rudy.
	var accounted: int = mine.stock + ore_in_flight + smelter.ore_stock + 2 * (
		smelter.metal_stock + metal_in_flight + metal_produced
	)
	if accounted != extracted:
		_fail("Zgubiono lub skopiowano material: wydobyto=%d, rozliczono=%d" % [extracted, accounted])
		return

	# Zanik zasilania nie moze skasowac ladunku juz na tasmie.
	game.landing_rocket.health = 1.0
	game._update_factory_power()
	if ore_link.powered or metal_link.powered:
		_fail("Tasmy pracuja przy wylaczonej sieci")
		return
	var delivered_before: int = ore_link.total_transferred + metal_link.total_transferred
	var packets_before: int = ore_link.packets.size() + metal_link.packets.size()
	for i in range(10):
		ore_link._process(0.2)
		metal_link._process(0.2)
	if packets_before != ore_link.packets.size() + metal_link.packets.size():
		_fail("Wylaczenie zasilania usunelo paczki z tasm")
		return
	if delivered_before != ore_link.total_transferred + metal_link.total_transferred:
		_fail("Material przesuwal sie bez zasilania")
		return

	print("CONVEYOR SMOKE OK: mine -> belt -> smelter -> belt -> warehouse; mass and power conserved")
	game.queue_free()
	await process_frame
	quit(0)
