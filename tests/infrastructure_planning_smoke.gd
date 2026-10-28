extends SceneTree
## WOW 0.12: projekt kilku budynkow, jednorazowe rozliczenie, drogi i kolizje.


func _initialize() -> void:
	call_deferred("_run_test")


func _fail(message: String) -> void:
	push_error("INFRA TEST: " + message)
	quit(1)


func _run_test() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if game.roads == null or game.blueprints == null:
		_fail("Brak menedzerow drog lub projektow")
		return
	if game.workers[0].road_network != game.roads:
		_fail("Roboty nie wiedza o nowej sieci drog")
		return

	var costs_before: Dictionary = game.resource_totals.duplicate(true)
	game._toggle_planning()
	if not game.planning_enabled:
		_fail("F nie wlacza trybu projektowego")
		return

	var ore_site: Vector3 = game.IRON_DEPOSIT_POSITION
	if not game._can_place_structure_at(ore_site, "mine"):
		_fail("Zloze zelaza nie jest dostepne na poczatku")
		return
	game.blueprints.add_blueprint("mine", ore_site, 1)
	if game._can_place_structure_at(ore_site, "mine"):
		_fail("Mozna planowac kopalnie drugi raz na tym samym zlozu")
		return

	var smelt_site: Vector3 = _find_free_site(game, "smelter")
	if smelt_site == Vector3.INF:
		_fail("Nie znaleziono wolnego miejsca na hute")
		return
	game.blueprints.add_blueprint("smelter", smelt_site, 2)
	if game._can_place_structure_at(smelt_site, "battery"):
		_fail("Zaplanowana huta nie rezerwuje przestrzeni")
		return

	var forest_site: Vector3 = _find_free_site(game, "forester")
	if forest_site == Vector3.INF:
		_fail("Nie znaleziono miejsca na rekultywacje")
		return
	game.blueprints.add_blueprint("forester", forest_site, 3)
	if game.blueprints.entries.size() != 3:
		_fail("Kolejka projektowa nie przechowuje trzech budowli")
		return
	if game.resource_totals != costs_before:
		_fail("Samo planowanie pobiera materialy")
		return

	var overall_cost: Dictionary = game.blueprints.total_cost(Callable(game, "_build_cost"))
	if int(overall_cost.get("wood", 0)) != 80 or int(overall_cost.get("stone", 0)) != 40:
		_fail("Bledny koszt zbiorczy projektu")
		return

	# Cofanie w planie i ponowne dodanie nie moze pobierac zasobow.
	if not game.blueprints.pop_last():
		_fail("Nie dziala cofniecie pojedynczego hologramu")
		return
	if game.resource_totals != costs_before:
		_fail("Cofanie projektu zmienia ekonomie")
		return
	game.blueprints.add_blueprint("forester", forest_site, 3)

	# Zatwierdzenie musi byc atomowe przy niedoborze materialow.
	game.resource_totals["wood"] = 75
	game._confirm_blueprints()
	if game.blueprints.entries.size() != 3 or game.factory_mine != null or game.factory_smelter != null:
		_fail("Czesciowo wykonano nieoplacony projekt")
		return
	game.resource_totals["wood"] = costs_before["wood"]

	game._confirm_blueprints()
	if game.factory_mine == null or game.factory_smelter == null or game.foresters.size() != 1:
		_fail("Enter nie wybudowal kompleksu fabrycznego")
		return
	if game.resource_totals["wood"] != costs_before["wood"] - 80 or game.resource_totals["stone"] != costs_before["stone"] - 40:
		_fail("Niepoprawne jednorazowe rozliczenie zbiorczej budowy")
		return
	if game.blueprints.entries.size() != 0:
		_fail("Hologramy zostaly po realizacji projektu")
		return
	if not is_equal_approx(game.factory_mine.rotation.y, PI * 0.5) or not is_equal_approx(game.factory_smelter.rotation.y, PI):
		_fail("Orientacja planowanych konstrukcji nie zostala zachowana")
		return

	# Dwa odcinki drog: omijanie przeszkod, pokazanie ceny, brak kolizji.
	var endpoints: Array[Vector3] = _road_endpoints(game)
	if endpoints.size() < 2:
		_fail("Nie znaleziono dostepnych pol do testu drog")
		return
	var path: Array[Vector2i] = game.roads.route(endpoints, game.navigation)
	if not game._valid_road_route(path):
		_fail("Nie znaleziono przejezdnej trasy przez techniczna siec")
		return
	var road_price: int = game.roads.cost(path)
	if road_price <= 0 or road_price != ceili(float(path.size()) / 4.0):
		_fail("Droga nie kosztuje jednego kamienia na cztery pola")
		return
	var stone_before: int = int(game.resource_totals["stone"])
	game.road_mode = true
	game.road_preview_route = path
	game.roads.preview(path)
	if game.roads.built_cells.size() != 0 or int(game.resource_totals["stone"]) != stone_before:
		_fail("Podglad drogi pobiera materialy przed budowa")
		return
	game._confirm_road()
	if game.roads.built_cells.size() != path.size() or int(game.resource_totals["stone"]) != stone_before - road_price:
		_fail("Droga zostala nieprawidlowo zbudowana lub rozliczona")
		return
	if not game.roads.has_cell(path[0]) or game._build_grid_cell_free(path[0]):
		_fail("Droga nie rezerwuje swojego pola przed nowymi budowlami")
		return
	if game.navigation.grid.is_point_solid(path[0]):
		_fail("Droga blokuje A* i ruch robotow")
		return
	if game.roads.cost(path) != 0:
		_fail("Ponowna budowa tej samej drogi mialaby naliczyc podwojny koszt")
		return
	if game._can_place_structure_at(Vector3(float(path[0].x), 0, float(path[0].y)), "solar"):
		_fail("Mozna postawic panel na juz wybudowanej drodze")
		return

	print("INFRA SMOKE OK: road preview, route cost, queue rollback, grouped factory and free robot path")
	game.queue_free()
	await process_frame
	quit(0)


func _find_free_site(game, kind: String) -> Vector3:
	for z in range(-38, 39, 6):
		for x in range(-38, 39, 6):
			var p := Vector3(float(x), 0, float(z))
			if game._can_place_structure_at(p, kind):
				return p
	return Vector3.INF


func _road_endpoints(game) -> Array[Vector3]:
	for z in range(-32, 33, 8):
		for x in range(-32, 21, 8):
			var a := Vector3(float(x), 0, float(z))
			var b := a + Vector3(7, 0, 0)
			if not game._road_cell_available(Vector2i(roundi(a.x), roundi(a.z))) or not game._road_cell_available(Vector2i(roundi(b.x), roundi(b.z))):
				continue
			var endpoints: Array[Vector3] = [a, b]
			if game._valid_road_route(game.roads.route(endpoints, game.navigation)):
				return endpoints
	return []
