extends Node3D
## WOW: pierwszy prototyp RTS bez zewnetrznych zasobow graficznych.

const WORKER_SCRIPT = preload("res://scripts/worker.gd")
const CAMERA_SCRIPT = preload("res://scripts/rts_camera.gd")
const NAVIGATION_SCRIPT = preload("res://scripts/navigation_grid.gd")
const SELECTION_BOX_SCRIPT = preload("res://scripts/selection_box.gd")
const RESOURCE_SCRIPT = preload("res://scripts/resource_node.gd")
const DEPOT_POSITION: Vector3 = Vector3(0.0, 0.0, 8.0)
const MAP_SIZE: float = 100.0

var workers: Array = []
var selected_workers: Array = []
var navigation = NAVIGATION_SCRIPT.new()
var selection_box: Control
var mouse_down: bool = false
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var resource_totals: Dictionary = {"wood": 0, "gold": 0, "stone": 0}
var resource_label: Label


func _ready() -> void:
	_create_environment()
	_create_ground()
	_create_resources()
	_create_depot()
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
	var tree = RESOURCE_SCRIPT.new()
	tree.resource_type = "wood"
	tree.remaining = 60
	tree.clearance_radius = 1.6
	tree.depleted.connect(_on_resource_depleted)
	tree.collision_layer = 4
	tree.collision_mask = 0
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

	var trunk_collision := CollisionShape3D.new()
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.6
	trunk_shape.height = 2.5
	trunk_collision.shape = trunk_shape
	trunk_collision.position.y = 1.25
	tree.add_child(trunk_collision)

	# Klikniecie korony drzewa rowniez zleca scinanie.
	var crown_collision := CollisionShape3D.new()
	var crown_shape := SphereShape3D.new()
	crown_shape.radius = 1.7
	crown_collision.shape = crown_shape
	crown_collision.position.y = 3.35
	tree.add_child(crown_collision)
	navigation.block_circle(coords, 1.6)


func _add_deposit(deposit_name: String, location: Vector3, tint: Color) -> void:
	var deposit = RESOURCE_SCRIPT.new()
	deposit.resource_type = "gold" if deposit_name == "GoldMine" else "stone"
	deposit.remaining = 300
	deposit.clearance_radius = 3.6
	deposit.depleted.connect(_on_resource_depleted)
	deposit.collision_layer = 4
	deposit.collision_mask = 0
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

	var obstacle_collision := CollisionShape3D.new()
	var obstacle_shape := BoxShape3D.new()
	obstacle_shape.size = Vector3(5.0, 2.5, 5.0)
	obstacle_collision.shape = obstacle_shape
	obstacle_collision.position.y = 1.25
	deposit.add_child(obstacle_collision)
	navigation.block_circle(Vector2(location.x, location.z), 3.6)


func _create_depot() -> void:
	var depot := Node3D.new()
	depot.name = "Stockpile"
	depot.position = DEPOT_POSITION
	add_child(depot)

	var platform := MeshInstance3D.new()
	platform.name = "StoragePlatform"
	var platform_mesh := BoxMesh.new()
	platform_mesh.size = Vector3(4.0, 0.35, 4.0)
	platform.mesh = platform_mesh
	platform.position.y = 0.18
	platform.material_override = _make_material(Color(0.43, 0.34, 0.20))
	depot.add_child(platform)

	for i in range(3):
		var crate := MeshInstance3D.new()
		crate.name = "Crate%d" % i
		var crate_mesh := BoxMesh.new()
		crate_mesh.size = Vector3(0.95, 1.0 + float(i) * 0.25, 0.95)
		crate.mesh = crate_mesh
		crate.position = Vector3(float(i) - 1.0, 0.85, 0.0)
		crate.material_override = _make_material(Color(0.52, 0.33, 0.17))
		depot.add_child(crate)

	var depot_name := Label3D.new()
	depot_name.text = "MAGAZYN"
	depot_name.position.y = 2.6
	depot_name.font_size = 40
	depot_name.pixel_size = 0.008
	depot_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	depot.add_child(depot_name)


func _on_resource_depleted(resource, clearance_radius: float) -> void:
	var p: Vector3 = resource.global_position
	navigation.unblock_circle(Vector2(p.x, p.z), clearance_radius)


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
		worker.resource_delivered.connect(_on_resource_delivered)
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
	hint.text = "WOW | LPM: wybierz | Przeciagnij LPM: grupa | PPM na surowcu: zbieraj | PPM na ziemi: idz | WASD: kamera"
	hint.position = Vector2(16, 14)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x", 2)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	ui.add_child(hint)

	resource_label = Label.new()
	resource_label.name = "ResourceCounters"
	resource_label.position = Vector2(16, 43)
	resource_label.add_theme_font_size_override("font_size", 22)
	resource_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.80))
	resource_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	resource_label.add_theme_constant_override("shadow_offset_x", 2)
	resource_label.add_theme_constant_override("shadow_offset_y", 2)
	ui.add_child(resource_label)
	_update_resource_hud()

	selection_box = SELECTION_BOX_SCRIPT.new()
	selection_box.name = "SelectionBox"
	selection_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(selection_box)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_down:
		var distance := drag_start.distance_to(event.position)
		if distance >= 8.0:
			is_dragging = true
		if is_dragging:
			selection_box.show_selection(drag_start, event.position)
		return

	if not (event is InputEventMouseButton):
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_down = true
			is_dragging = false
			drag_start = event.position
		elif mouse_down:
			mouse_down = false
			selection_box.hide_selection()
			if is_dragging:
				_select_in_rectangle(Rect2(drag_start, event.position - drag_start).abs(), event.shift_pressed)
			else:
				_select_by_click(event.position, event.shift_pressed)
			is_dragging = false

	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_command_move_selected(event.position)


func _select_by_click(screen_position: Vector2, additive: bool) -> void:
	var hit := _raycast(screen_position, 2)
	if not additive:
		_clear_selection()
	if hit.has("collider") and hit["collider"] in workers:
		_select_worker(hit["collider"])


func _select_in_rectangle(rectangle: Rect2, additive: bool) -> void:
	if not additive:
		_clear_selection()
	var active_camera := get_viewport().get_camera_3d()
	if active_camera == null:
		return
	for worker in workers:
		var point: Vector3 = worker.global_position + Vector3(0.0, 0.9, 0.0)
		if active_camera.is_position_behind(point):
			continue
		var projected: Vector2 = active_camera.unproject_position(point)
		if rectangle.has_point(projected):
			_select_worker(worker)


func _command_move_selected(screen_position: Vector2) -> void:
	if selected_workers.is_empty():
		return

	var resource_hit := _raycast(screen_position, 4)
	if resource_hit.has("collider"):
		var clicked_object = resource_hit["collider"]
		if clicked_object.has_method("harvest"):
			for worker in selected_workers:
				worker.command_gather(clicked_object, navigation, DEPOT_POSITION)
			return

	var hit := _raycast(screen_position, 1)
	if hit.is_empty():
		return
	var target: Vector3 = hit["position"]
	for i in range(selected_workers.size()):
		var column := float(i % 3)
		var row := float(floori(float(i) / 3.0))
		var offset := Vector3((column - 1.0) * 1.8, 0.0, row * 1.8)
		var worker = selected_workers[i]
		var path: Array[Vector3] = navigation.find_path(worker.global_position, target + offset)
		if not path.is_empty():
			worker.command_move(path)


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


func _on_resource_delivered(resource_type: String, amount: int) -> void:
	if not resource_totals.has(resource_type):
		return
	resource_totals[resource_type] = int(resource_totals[resource_type]) + amount
	_update_resource_hud()


func _update_resource_hud() -> void:
	if resource_label == null:
		return
	resource_label.text = "Drewno: %d     Zloto: %d     Kamien: %d" % [
		int(resource_totals["wood"]),
		int(resource_totals["gold"]),
		int(resource_totals["stone"])
	]


func _make_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.92
	return material
