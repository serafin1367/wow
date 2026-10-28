extends SceneTree
## WOW 0.14 — 20 aktywnych jednostek, wiele magazynow, zachowanie masy.
const SAVE = preload("res://scripts/save_game_manager.gd")


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FLEET TEST: " + message)
	quit(1)


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._spawn_planned_structure({"kind": "mine", "site": game.IRON_DEPOSIT_POSITION, "quarters": 0})
	game._spawn_planned_structure({"kind": "smelter", "site": Vector3(18, 0, 22), "quarters": 0})
	for x in range(-28, 33, 5):
		for z in range(-28, 33, 5):
			var at := Vector3(float(x), 0, float(z))
			if game._can_place_structure_at(at, "depot"):
				game._spawn_planned_structure({"kind": "depot", "site": at, "quarters": 0})
				if game.logistics_depots.size() == 2:
					break
		if game.logistics_depots.size() == 2:
			break
	if game.logistics_depots.size() != 2:
		_fail("Nie mozna przygotowac magazynow")
		return
	game.factory_mine.stock = 80
	game.factory_smelter.ore_stock = 10
	game.factory_smelter.metal_stock = 20
	game.factory_mine.power_enabled = false
	game.factory_smelter.power_enabled = false
	while game.workers.size() < 20:
		var index: int = game.workers.size()
		var x: float = -19.0 + float(index % 8) * 1.6
		var z: float = -32.0 + float(index / 8) * 2.3
		game._spawn_worker(Vector3(x, 0, z), "hauler")
	for i in range(game.workers.size()):
		if game.workers[i].robot_role == "hauler":
			game.workers[i].state = game.workers[i].WorkState.IDLE
			game.workers[i].factory_route_active = false
	var original: Dictionary = _balance(game)
	# Fizyczny ruch, planowanie i przekazywanie ladunkow przez 5 sekund.
	for frame in range(300):
		await physics_frame
		if frame % 60 == 0 and _balance(game) != original:
			_fail("Zmienil sie bilans przy ruchu 20 robotow (klatka %d)" % frame)
			return
	if _balance(game) != original:
		_fail("Zaginely surowce w trakcie pracy floty")
		return
	var snapshot: Dictionary = SAVE.new().to_dict(game)
	if not SAVE.new().validate(snapshot):
		_fail("Zapis 20 robotow nie przechodzi walidacji")
		return
	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	if not SAVE.new().from_dict(fresh, snapshot):
		_fail("Nie mozna odtworzyc floty")
		return
	if fresh.workers.size() != 20 or fresh.logistics_depots.size() != 2:
		_fail("Zapis utracil roboty lub magazyny")
		return
	if _balance(fresh) != _balance(game):
		_fail("Zapis/odczyt dwudziestu transportowcow zmienil bilans")
		return
	print("LOGISTICS FLEET SMOKE OK: 20 robots, 2 depots, 300 physics ticks and save/load conservation")
	game.queue_free()
	fresh.queue_free()
	await process_frame
	quit(0)


func _balance(game) -> Dictionary:
	var ore: int = game.factory_mine.stock + game.factory_smelter.ore_stock
	var metal: int = game.factory_smelter.metal_stock + int(game.resource_totals["metal"])
	for hub in game.logistics_depots:
		ore += hub.cargo.quantity("iron_ore")
		metal += hub.cargo.quantity("metal")
	for robot in game.workers:
		if robot.carried_type == "iron_ore":
			ore += robot.carried_amount
		elif robot.carried_type == "metal":
			metal += robot.carried_amount
	return {"ore": ore, "metal": metal}
