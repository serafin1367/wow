extends SceneTree
## WOW 0.14: planowanie i budowa magazynu posredniego, porty, zapis i odczyt.


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("DEPOT TEST: " + message)
	quit(1)


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var site := _free_site(game)
	if site == Vector3.INF:
		_fail("Brak wolnego obszaru na magazyn")
		return
	if game._build_cost("depot") != {"wood": 15, "stone": 10}:
		_fail("Nieprawidlowy koszt magazynu")
		return
	if not game._can_place_structure_at(site, "depot"):
		_fail("Nie mozna zbudowac magazynu na wolnym terenie")
		return
	var wood_before: int = int(game.resource_totals["wood"])
	var stone_before: int = int(game.resource_totals["stone"])
	game.blueprints.add_blueprint("depot", site, 1)
	if game._can_place_structure_at(site, "solar"):
		_fail("Projektowany magazyn nie rezerwuje terenu")
		return
	game._confirm_blueprints()
	if game.logistics_depots.size() != 1:
		_fail("Nie zbudowano magazynu z planu")
		return
	if int(game.resource_totals["wood"]) != wood_before - 15 or int(game.resource_totals["stone"]) != stone_before - 10:
		_fail("Projekt magazynu pobiera niepoprawny koszt")
		return
	if game._can_place_structure_at(site, "depot"):
		_fail("Konstrukcje moga nachodzic na magazyn")
		return
	var depot = game.logistics_depots[0]
	if depot.get_output_port("iron_ore") != depot.get_input_port("iron_ore"):
		_fail("Robot i tasma widza rozne bufory magazynowe")
		return
	if depot.deposit_resource("iron_ore", 123) != 120:
		_fail("Magazyn przekroczyl limit wejscia 120")
		return
	if depot.get_input_port("iron_ore").reserve_input("belt:incoming", "iron_ore", 1):
		_fail("Mozna zarezerwowac miejsce w pelnym magazynie")
		return
	if depot.withdraw_resource("iron_ore", 23) != 23:
		_fail("Robot nie mogl pobrac rudy przez wspolny port")
		return
	if depot.deposit_resource("metal", 7) != 7:
		_fail("Odrzucono prawidlowa dostawę metalu")
		return
	if not depot.get_output_port("iron_ore").reserve_output("hauler:pickup", "iron_ore", 8):
		_fail("Nie mozna zarezerwowac wyjazdu transportowca")
		return

	var mgr = game.SAVE_SCRIPT.new()
	var snapshot: Dictionary = mgr.to_dict(game)
	if not mgr.validate(snapshot):
		_fail("Snapshot magazynu nie przechodzi walidacji")
		return
	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	if not mgr.from_dict(fresh, snapshot):
		_fail("Nie mozna odtworzyc magazynu z jego rezerwacjami")
		return
	if fresh.logistics_depots.size() != 1:
		_fail("Odczyt usunal magazyn posredni")
		return
	var restored = fresh.logistics_depots[0]
	if restored.cargo.quantity("iron_ore") != 97 or restored.cargo.quantity("metal") != 7:
		_fail("Utracono zapas rudy lub metalu po wczytaniu")
		return
	if restored.cargo.available_output("iron_ore") != 89:
		_fail("Odczyt nie zachowal rezerwacji robotow")
		return
	if not is_equal_approx(restored.rotation.y, PI * 0.5):
		_fail("Utracono orientacje magazynu")
		return
	print("DEPOT SMOKE OK: planning, no overlap, shared ports, capacity and saved reservations")
	game.queue_free()
	fresh.queue_free()
	await process_frame
	quit(0)


func _free_site(game) -> Vector3:
	for z in range(-35, 40, 5):
		for x in range(-35, 40, 5):
			var site := Vector3(float(x), 0, float(z))
			if game._can_place_structure_at(site, "depot"):
				return site
	return Vector3.INF
