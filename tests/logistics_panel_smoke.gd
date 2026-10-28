extends SceneTree
## WOW 0.14: rzeczywisty panel HUD zapisuje limity i zmienia zlecenia.


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("LOGISTICS UI TEST: " + message)
	quit(1)


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var panel = game.hud.logistics_panel
	if panel == null or panel.visible:
		_fail("Panel nie istnieje lub zaslania gre przed otwarciem")
		return
	var site := Vector3(8, 0, 20)
	if not game._can_place_structure_at(site, "depot"):
		for x in range(-34, 34, 4):
			for z in range(-34, 34, 4):
				var possible := Vector3(float(x), 0, float(z))
				if game._can_place_structure_at(possible, "depot"):
					site = possible
					break
	game._spawn_planned_structure({"kind": "depot", "site": site, "quarters": 1})
	game._toggle_logistics_panel()
	if not panel.visible or panel.depot_picker.item_count != 1:
		_fail("Otwarcie O nie zaladowalo magazynu do panelu")
		return
	panel.minimum_editor.value = 9
	panel.maximum_editor.value = 70
	panel._apply_limits()
	var depot = game.logistics_depots[0]
	if int(depot.minimum_stock["iron_ore"]) != 9 or int(depot.maximum_stock["iron_ore"]) != 70:
		_fail("ZASTOSUJ nie modyfikuje limitow wskazanego magazynu")
		return
	game._spawn_planned_structure({"kind": "mine", "site": game.IRON_DEPOSIT_POSITION, "quarters": 0})
	game._spawn_planned_structure({"kind": "smelter", "site": Vector3(18, 0, 22), "quarters": 0})
	game.factory_mine.stock = 22
	game.factory_mine.power_enabled = false
	game.factory_smelter.power_enabled = false
	game._tick_logistics(0.9)
	game._refresh_logistics_panel()
	if panel.job_container.get_child_count() < 1 or game.logistics_manager.jobs.is_empty():
		_fail("Panel nie pokazuje oczekujacych dostaw")
		return
	var job_id: String = str(game.logistics_manager.jobs[0]["id"])
	panel.priority_requested.emit(job_id, 164)
	if int(game.logistics_manager.get_job(job_id)["priority"]) != 164:
		_fail("Kontrolka priorytetu nie jest podlaczona do menedzera")
		return
	panel.cancel_requested.emit(job_id)
	if not game.logistics_manager.get_job(job_id).is_empty():
		_fail("Przycisk anulowania nie zwolnil oczekujacego zlecenia")
		return
	var save = game.SAVE_SCRIPT.new()
	var data: Dictionary = save.to_dict(game)
	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	if not save.from_dict(fresh, data):
		_fail("Nie mozna odtworzyc progow ustawionych z HUD")
		return
	if fresh.logistics_depots[0].minimum_stock["iron_ore"] != 9 or fresh.logistics_depots[0].maximum_stock["iron_ore"] != 70:
		_fail("Zapis/odczyt nie zachowal konfiguracji panelu")
		return
	game._toggle_logistics_panel()
	if panel.visible:
		_fail("Panel nie zamknal sie po ponownym O")
		return
	print("LOGISTICS PANEL SMOKE OK: open, stock limits, priority, cancellation, save/load and close")
	game.queue_free()
	fresh.queue_free()
	await process_frame
	quit(0)
