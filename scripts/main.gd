extends Node3D
## WOW: pierwszy prototyp RTS bez zewnetrznych zasobow graficznych.

const WORKER_SCRIPT = preload("res://scripts/worker.gd")
const CAMERA_SCRIPT = preload("res://scripts/rts_camera.gd")
const MAP_SIZE: float = 100.0

var workers: Array = []
var selected_workers: Array = []


func _ready() -> void:
	_create_environment()
	_create_ground()
	_create_resources()
	_create_workers()
	_create_camera()
	_create_hud()


func _create_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.58, 0.78, 0.92)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.84, 0.95)
	environment.ambient_light_energy = 0.8
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50.0, -25.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)


func _create_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 0
	add_child(ground)

	var visual := MeshInstance3D.new()
	visual.name = "Grass"
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP_SIZE, MAP_SIZE)
	visual.mesh = plane
	visual.material_override = _make_material(Color(0.26, 0.50, 0.23))
	ground.add_child(visual)

	var shape := BoxShape3D.new()
	shape.size = Vector3(MAP_SIZE, 0.2, MAP_SIZE)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -0.1
	ground.add_child(collision)


func _create_resources() -> void:
	var forest := Node3D.new()
	forest.name = "Forest"
	add_child(forest)
	var tree_positions: Array[Vector2] = [
		Vector2(-35, -29), Vector2(-31, -25), Vector2(-27, -33),
		Vector2(-37, -20), Vector2(-24, -24), Vector2(-31, -17),
		Vector2(20, -30), Vector2(25, -27), Vector2(30, -32),
		Vector2(34, -25)
	]
	for location in tree_positions:
		_add_tree(forest, location)

	_add_deposit("GoldMine", Vector3(-25.0, 0.0, 9.0), Color(0.9, 0.67, 0.12))
	_add_deposit("StoneQuarry", Vector3(29.0, 0.0, 18.0), Color(0.48, 0.50, 0.53))


func _add_tree(parent_node: Node3D, coords: Vector2) -> void:
	var tree := Node3D.new()
	tree.name = "Tree"
	tree.position = Vector3(coords.x, 0.0, coords.y)
	parent_node.add_child(tree)

	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.32
	cylinder.bottom_radius = 0.48
	cylinder.height = 2.5
	trunk.mesh = cylinder
	trunk.position.y = 1.25
	trunk.material_override = _make_material(Color(0.40, 0.25, 0.12))
	tree.add_child(trunk)

	var leaves := MeshInstance3D.new()
	leaves.name = "Crown"
	var sphere := SphereMesh.new()
	sphere.radius = 1.7
	sphere.height = 3.4
	leaves.mesh = sphere
	leaves.position.y = 3.35
	leaves.material_override = _make_material(Color(0.10, 0.37, 0.16))
	tree.add_child(leaves)


func _add_deposit(deposit_name: String, location: Vector3, tint: Color) -> void:
	var deposit := Node3D.new()
	deposit.name = deposit_name
	deposit.position = location
	add_child(deposit)

	for i in range(4):
		var rock := MeshInstance3D.new()
		rock.name = "Rock%d" % i
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		rock.mesh = sphere
		var offset_x := float(i % 2) * 2.0 - 1.0
		var offset_z := float(i / 2) * 2.0 - 1.0
		rock.position = Vector3(offset_x, 0.9, offset_z)
		rock.scale = Vector3(1.5, 1.0 + float(i) * 0.15, 1.4)
		rock.material_override = _make_material(tint)
		deposit.add_child(rock)


func _create_workers() -> void:
	var starting_positions: Array[Vector3] = [
		Vector3(-3.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(3.0, 0.0, 0.0)
	]
	for start in starting_positions:
		var worker = WORKER_SCRIPT.new()
		worker.name = "Worker%d" % (workers.size() + 1)
		worker.position = start
		add_child(worker)
		workers.append(worker)


func _create_camera() -> void:
	var camera_rig = CAMERA_SCRIPT.new()
	camera_rig.name = "RTSCameraRig"
	camera_rig.position = Vector3(0.0, 0.0, 0.0)
	add_child(camera_rig)


func _create_hud() -> void:
	var ui := CanvasLayer.new()
	ui.name = "HUD"
	add_child(ui)
	var hint := Label.new()
	hint.name = "Controls"
	hint.text = "WOW - RTS prototype | LPM: wybierz | Shift+LPM: dodaj | PPM: ruch | WASD / krawedzie: kamera | Rolka: zoom"
	hint.position = Vector2(16, 14)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x", 2)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	ui.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _raycast(event.position, 2)
		var append := Input.is_key_pressed(KEY_SHIFT)
		if not append:
			_clear_selection()
		if hit.has("collider") and hit["collider"] in workers:
			_select_worker(hit["collider"])

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if selected_workers.is_empty():
			return
		var hit := _raycast(event.position, 1)
		if hit.is_empty():
			return
		var target: Vector3 = hit["position"]
		for i in range(selected_workers.size()):
			var column := float(i % 3)
			var row := float(floori(float(i) / 3.0))
			var offset := Vector3((column - 1.0) * 1.8, 0.0, row * 1.8)
			selected_workers[i].command_move(target + offset)


func _raycast(screen_position: Vector2, mask: int) -> Dictionary:
	var active_camera := get_viewport().get_camera_3d()
	if active_camera == null:
		return {}
	var origin := active_camera.project_ray_origin(screen_position)
	var end := origin + active_camera.project_ray_normal(screen_position) * 500.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, mask)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _clear_selection() -> void:
	for worker in selected_workers:
		worker.set_selected(false)
	selected_workers.clear()


func _select_worker(worker: CharacterBody3D) -> void:
	if worker in selected_workers:
		return
	selected_workers.append(worker)
	worker.set_selected(true)


func _make_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.92
	return material
