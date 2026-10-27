extends SceneTree
## WOW 0.8: test recznych waypointow, podgladu i ciaglych odcinkow tasmy.


func _initialize() -> void:
	call_deferred("_run_test")


func _fail(reason: String) -> void:
	push_error("MANUAL BELT TEST: " + reason)
	quit(1)


func _run_test() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	var ore_deposit = game.get_node("IronOreDeposit")
	var mine = load("res://scripts/automated_mine.gd").new()
	mine.ore_source = ore_deposit
	mine.position = ore_deposit.position
	game.add_child(mine)
	game.factory_mine = mine
	ore_deposit.collision_layer = 0
	ore_deposit.visible = false
	game.navigation.block_circle(Vector2(mine.position.x, mine.position.z), mine.get_access_radius())

	var smelter = load("res://scripts/automated_smelter.gd").new()
	smelter.position = Vector3(18.0, 0.0, 22.0)
	game.add_child(smelter)
	game.factory_smelter = smelter
	game.navigation.block_circle(Vector2(smelter.position.x, smelter.position.z), smelter.get_access_radius())
	game.resource_totals["metal"] = 30
	game._update_factory_power()

	var waypoint := Vector3(11.0, 0.0, 16.0)
	if not game.navigation.is_circle_walkable(Vector2(waypoint.x, waypoint.z), 0.35):
		_fail("Wybrany punkt testowy jest zajety")
		return

	game._start_manual_conveyor("ore")
	if game.manual_conveyor_kind != "ore":
		_fail("Nie udalo sie wlaczyc trybu recznego")
		return
	game.manual_conveyor_points.append(waypoint)
	if not game._refresh_manual_preview():
		_fail("Nie udalo sie zbudowac podgladu przez waypoint")
		return
	var preview = game.manual_conveyor_preview
	if preview == null or not preview.preview_mode:
		_fail("Brak podgladu trasy")
		return
	if not preview.path_points.has(waypoint):
		_fail("Wyznaczona trasa nie przechodzi przez punkt wybrany przez gracza")
		return

	var metal_before: int = int(game.resource_totals["metal"])
	var ore_before: int = mine.stock
	preview._process(60.0)
	if int(game.resource_totals["metal"]) != metal_before or mine.stock != ore_before or preview.packets.size() != 0:
		_fail("Podglad trasy zuzywa surowce")
		return

	game._confirm_manual_conveyor()
	if game.ore_conveyor == null:
		_fail("Enter nie utworzyl tasmy")
		return
	if int(game.resource_totals["metal"]) != metal_before - 5:
		_fail("Zly koszt budowy tasmy recznej")
		return
	if game.manual_conveyor_kind != "":
		_fail("Tryb reczny nie zostal zakonczony")
		return
	var link = game.ore_conveyor
	if not link.path_points.has(waypoint):
		_fail("Po budowie zniknal recznie dodany punkt")
		return
	if link.path_points[0].distance_to(mine.global_position) > mine.get_access_radius() + 0.25:
		_fail("Wylot tasmy nie dotyka kopalni")
		return
	if link.path_points[link.path_points.size() - 1].distance_to(smelter.global_position) > smelter.get_access_radius() + 0.25:
		_fail("Wlot tasmy nie dotyka huty")
		return
	if link.find_child("ConveyorOUTPUT", true, false) == null or link.find_child("ConveyorINPUT", true, false) == null:
		_fail("Brak przybudowanych modulow wylotu/wlotu")
		return
	if link.find_child("DriveRoller", true, false) == null:
		_fail("Brak rolek pod tasma")
		return
	if link.find_child("CornerJoint", true, false) == null:
		_fail("Brak modulu zakretu")
		return

	# Obie metody (reczna i automatyczna) korzystaja z tego samego bilansu.
	game._build_conveyor("metal")
	if game.metal_conveyor == null or int(game.resource_totals["metal"]) != 17:
		_fail("Automatyczne J/N nie wspolpracuje z recznym ukladaniem")
		return

	print("MANUAL BELT SMOKE OK: waypoint, preview, connectors, turns and cost")
	game.queue_free()
	await process_frame
	quit(0)
