extends SceneTree
## WOW 0.10: jeden mechanizm blokowania budowy + zielona/czerwona siatka.
## Testuje kola zajetosci, nakladanie wszystkich budynkow i wyjatek zloza.

const KINDS: Array[String] = ["center", "forester", "smelter", "solar", "battery"]


func _initialize() -> void:
	call_deferred("_run_test")


func _fail(message: String) -> void:
	push_error("PLACEMENT TEST: " + message)
	quit(1)


func _run_test() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if game.build_preview == null:
		_fail("Brak lokalnej siatki podgladu budowania")
		return
	for kind in KINDS:
		if game._can_place_structure_at(game.LANDER_POSITION, kind):
			_fail("Mozna postawic %s bezposrednio na rakiecie" % kind)
			return
		if game._can_place_structure_at(game.DEPOT_POSITION, kind):
			_fail("Mozna postawic %s bezposrednio na magazynie" % kind)
			return
		if game._can_place_structure_at(game.CHARGER_POSITION, kind):
			_fail("Mozna postawic %s bezposrednio na ladowarce" % kind)
			return
		if game._can_place_structure_at(Vector3(48, 0, 48), kind):
			_fail("Mozna budowac poza dozwolona mapa: %s" % kind)
			return
		if game._can_place_structure_at(game.IRON_DEPOSIT_POSITION, kind):
			_fail("Zwykly budynek moze zastapic zloze zelaza: %s" % kind)
			return

	# Kopalnia jest jedynym budynkiem dopuszczonym na zlozu zelaza.
	if not game._can_place_structure_at(game.IRON_DEPOSIT_POSITION, "mine"):
		_fail("Nie mozna postawic kopalni na dedykowanym zlozu")
		return
	if game._can_place_structure_at(Vector3(14, 0, 8), "mine"):
		_fail("Kopalnia moze stac poza centrum zloza")
		return

	# Dodajemy nowe budynki po kolei, zaznaczajac ich obrys w A*.
	# Sasiadujace pola musza byc nieaktywne dla WSZYSTKICH typow konstrukcji.
	var scripts: Dictionary = {
		"center": load("res://scripts/town_hall.gd"),
		"forester": load("res://scripts/forester_hut.gd"),
		"smelter": load("res://scripts/automated_smelter.gd"),
		"solar": load("res://scripts/solar_array.gd"),
		"battery": load("res://scripts/battery_bank.gd")
	}
	for kind in KINDS:
		var site := _find_free_site(game, kind)
		if site == Vector3.INF:
			_fail("Nie znaleziono pustego pola dla %s" % kind)
			return
		var radius: float = game._build_radius(kind)
		if radius <= 0.0:
			_fail("Nieprawidlowy obrys %s" % kind)
			return
		var structure = scripts[kind].new()
		structure.position = site
		game.add_child(structure)
		match kind:
			"center":
				game.town_hall = structure
			"forester":
				game.foresters.append(structure)
			"smelter":
				game.factory_smelter = structure
			"solar":
				game.solar_arrays.append(structure)
			"battery":
				game.battery_banks.append(structure)
		game.navigation.block_circle(Vector2(site.x, site.z), radius)
		for next_kind in KINDS:
			if game._can_place_structure_at(site, next_kind):
				_fail("Nakladanie na %s dozwolone dla: %s" % [kind, next_kind])
				return
			if game._can_place_structure_at(site + Vector3(1.0, 0, 0), next_kind):
				_fail("Zbyt maly odstep obok %s dla %s" % [kind, next_kind])
				return
		# Podglad korzysta z dokladnie tego samego walidatora co klikniecie.
		game.build_preview.update_area(
			site, radius, game._can_place_structure_at(site, kind),
			Callable(game, "_build_grid_cell_free").bind(kind)
		)
		if not game.build_preview.visible:
			_fail("Podglad nie pokazuje siatki w trybie budowania")
			return
		if game.build_preview.hover_caption.text != "ZAJETE / NIEDOSTEPNE":
			_fail("Zajety budynek nie jest oznaczony na czerwono")
			return

	game.build_preview.clear()
	if game.build_preview.visible:
		_fail("Siatka zostaje po anulowaniu budowania")
		return

	print("PLACEMENT SMOKE OK: shared footprint, blocked structures, green/red overlay, mine exception")
	game.queue_free()
	await process_frame
	quit(0)


func _find_free_site(game, kind: String) -> Vector3:
	for z in range(-38, 40, 5):
		for x in range(-38, 40, 5):
			var site := Vector3(float(x), 0, float(z))
			if game._can_place_structure_at(site, kind):
				return site
	return Vector3.INF
