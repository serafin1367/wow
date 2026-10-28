extends SceneTree
## WOW 0.15: panel produkcji nie nachodzi na HUD na 720p i 1080p.

func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("PRODUCTION LAYOUT TEST: " + message)
	quit(1)


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var panel = game.hud.production_panel
	game._toggle_production_panel()
	if panel == null or not panel.visible:
		_fail("Nie mozna otworzyc panelu")
		return
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(900, 680)]:
		root.size = resolution
		await process_frame
		panel._fit_viewport()
		await process_frame
		var viewport: Vector2 = root.get_visible_rect().size
		var bounds: Rect2 = panel.get_global_rect()

		if bounds.position.x < -0.1 or bounds.position.y < -0.1:
			_fail("Panel wyszedl poza lewy/gorny brzeg: %s: %s" % [str(resolution), str(bounds)])
			return
		if bounds.end.x > viewport.x + 0.1 or bounds.end.y > viewport.y + 0.1:
			_fail("Panel wyszedl poza prawa/dolna krawedz ekranu: %s: %s" % [str(resolution), str(bounds)])
			return
		var top_bar := game.hud.root.get_node("TopStatusBar") as Control
		var command_bar := game.hud.root.get_node("CommandBar") as Control
		if bounds.position.y < top_bar.get_global_rect().end.y - 2.0:
			_fail("Panel zakrywa gorny pasek statusu")
			return
		if bounds.end.y > command_bar.get_global_rect().position.y + 2.0:
			_fail("Panel zakrywa dolny pasek narzedzi")
			return
		if bounds.size.x < 200 or bounds.size.y < 200:
			_fail("Panel staje sie nieuzywalny w mniejszym oknie")
			return
	game.hud.toggle_logistics_panel()
	if game.hud.production_panel.visible:
		_fail("Konsola logistyki naklada sie na panel produkcji")
		return
	game.hud.toggle_production_panel()
	if game.hud.logistics_panel.visible:
		_fail("Panel produkcji naklada sie na konsole logistyki")
		return
	print("PRODUCTION LAYOUT SMOKE OK: no overlap at 720p/1080p, scrollable HUD and exclusive panels")
	game.queue_free()
	await process_frame
	quit(0)
