extends SceneTree
## WOW 0.11: model 3D, obrot konstrukcji, snap i brak skutkow ubocznych.
const KINDS: Array[String] = ["center", "forester", "mine", "smelter", "solar", "battery"]


func _initialize() -> void:
	call_deferred("_run_test")


func _fail(reason: String) -> void:
	push_error("GHOST TEST: " + reason)
	quit(1)


func _run_test() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var preview = game.build_preview
	var ghost = preview.ghost
	if ghost == null:
		_fail("Brak podgladu 3D")
		return

	var resources_before: Dictionary = game.resource_totals.duplicate(true)
	var workers_before: int = game.workers.size()
	for kind in KINDS:
		var site: Vector3 = game.IRON_DEPOSIT_POSITION if kind == "mine" else _find_free_site(game, kind)
		if site == Vector3.INF:
			_fail("Brak dostepnego pola dla %s" % kind)
			return
		preview.update_area(
			site, game._build_radius(kind), game._can_place_structure_at(site, kind),
			Callable(game, "_build_grid_cell_free").bind(kind), kind, 1, 2
		)
		if not preview.visible or ghost.model == null or not ghost.visible:
			_fail("Model %s nie pokazuje sie przy kursorze" % kind)
			return
		if ghost.current_kind != kind:
			_fail("Podglad przedstawia niewlasciwy budynek: %s" % kind)
			return
		if ghost.model.process_mode != Node.PROCESS_MODE_DISABLED:
			_fail("Hologram moze wykonywac produkcje: %s" % kind)
			return
		if not is_equal_approx(ghost.model.rotation.y, PI * 0.5):
			_fail("Obrot modelu w podgladzie jest bledny")
			return
		if ghost.model is CollisionObject3D and ghost.model.collision_layer != 0:
			_fail("Hologram blokuje pole budowy: %s" % kind)
			return
		if not _safe_descendants(ghost.model):
			_fail("Hologram ma wlaczona kolizje lub zegar: %s" % kind)
			return
		if game.resource_totals != resources_before or game.workers.size() != workers_before:
			_fail("Podglad zmienil ekonomie gry: %s" % kind)
			return

	preview.update_area(Vector3(0, 0, 8), game._build_radius("solar"), false,
		Callable(game, "_build_grid_cell_free").bind("solar"), "solar", 2, 1)
	if ghost.hologram_material.albedo_color != ghost.INVALID_COLOR:
		_fail("Kolor hologramu nie zmienia sie na czerwony na zajetym polu")
		return

	game._toggle_build_mode()
	if game._active_build_kind() != "center":
		_fail("Tryb budowy centrum sie nie wlaczyl")
		return
	game._rotate_build_preview()
	if game.placement_rotation_quarters != 1:
		_fail("R nie obraca konstrukcji")
		return
	game._rotate_build_preview(true)
	if game.placement_rotation_quarters != 0:
		_fail("Shift+R nie obraca wstecz")
		return
	game._cycle_build_snap()
	if game.placement_snap_size != 2:
		_fail("G nie wybiera siatki 2m")
		return
	var snapped: Vector3 = game._snap_build_point(Vector3(3.2, 0, -5.6), "solar")
	if snapped != Vector3(4, 0, -6):
		_fail("Budowa nie przyciaga do siatki 2m")
		return
	game._cycle_build_snap()
	if game.placement_snap_size != 4 or game._snap_build_point(Vector3(3.2, 0, -5.6), "solar") != Vector3(4, 0, -4):
		_fail("Brak siatki 4m")
		return
	game._cycle_build_snap()
	if game.placement_snap_size != 1:
		_fail("Cykl 1/2/4m nie wraca do poczatku")
		return

	game.placement_rotation_quarters = 3
	var finished := Node3D.new()
	game._apply_build_rotation(finished)
	if not is_equal_approx(finished.rotation.y, 3.0 * PI * 0.5):
		_fail("Gotowy budynek ma inny obrot niz podglad")
		return
	finished.free()

	game._cancel_build_modes()
	preview.clear()
	if preview.visible or ghost.visible:
		_fail("Podglad pozostaje po Esc")
		return
	if game.resource_totals != resources_before:
		_fail("Podglad lub anulowanie pobraly surowce")
		return
	print("GHOST SMOKE OK: 3D model, green/red tint, R rotation, G snap, no collision or costs")
	game.queue_free()
	await process_frame
	quit(0)


func _safe_descendants(node: Node) -> bool:
	for child in node.get_children():
		if child is CollisionObject3D and child.collision_layer != 0:
			return false
		if child is CollisionShape3D and not child.disabled:
			return false
		if child is Timer and not child.is_stopped():
			return false
		if not _safe_descendants(child):
			return false
	return true


func _find_free_site(game, kind: String) -> Vector3:
	for z in range(-38, 40, 5):
		for x in range(-38, 40, 5):
			var site := Vector3(float(x), 0.0, float(z))
			if game._can_place_structure_at(site, kind):
				return site
	return Vector3.INF
