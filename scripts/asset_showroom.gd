extends Node3D
## Osobna scena podgladu modeli WOW 0.2 (uruchom scene F6).
const ROBOT_SCRIPT = preload("res://scripts/robot_model.gd")
const LANDER_SCRIPT = preload("res://scripts/colony_lander.gd")
const CHARGER_SCRIPT = preload("res://scripts/charging_pad.gd")
const FACTORY_SCRIPT = preload("res://scripts/factory_models.gd")


func _ready() -> void:
	var world := WorldEnvironment.new()
	var atmosphere := Environment.new()
	atmosphere.background_mode = Environment.BG_COLOR
	atmosphere.background_color = Color(0.45, 0.61, 0.66)
	atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_color = Color(0.85, 0.91, 0.96)
	atmosphere.ambient_light_energy = 0.8
	world.environment = atmosphere
	add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-47, -31, 0)
	light.light_energy = 1.5
	light.shadow_enabled = true
	add_child(light)

	var floor_mesh := MeshInstance3D.new()
	var ground := PlaneMesh.new()
	ground.size = Vector2(70, 55)
	floor_mesh.mesh = ground
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.32, 0.39, 0.36)
	floor_mesh.material_override = ground_mat
	add_child(floor_mesh)

	var lander = LANDER_SCRIPT.new()
	lander.position = Vector3(-16, 0, -7)
	add_child(lander)

	var charger = CHARGER_SCRIPT.new()
	charger.position = Vector3(-15, 0, 5)
	charger.power_source = lander
	add_child(charger)

	var variants: Array[String] = ["miner", "hauler", "engineer"]
	for i in range(3):
		var robot = ROBOT_SCRIPT.new()
		robot.robot_role = variants[i]
		robot.position = Vector3(float(i) * 4.5 - 1.5, 0, -7)
		add_child(robot)
		_label(variants[i].to_upper(), robot.position + Vector3(0, 2.9, 0))

	var names: Array[String] = ["extractor", "conveyor", "smelter"]
	for i in range(3):
		var factory = FACTORY_SCRIPT.new()
		factory.machine_type = names[i]
		factory.position = Vector3(float(i) * 8.0 - 7.0, 0, 7.0)
		add_child(factory)
		_label(names[i].to_upper(), factory.position + Vector3(0, 6.3, 0))

	var camera := Camera3D.new()
	camera.current = true
	camera.position = Vector3(0, 26, 36)
	camera.look_at(Vector3(0, 1, -1), Vector3.UP)
	camera.fov = 65.0
	add_child(camera)


func _label(title: String, location: Vector3) -> void:
	var caption := Label3D.new()
	caption.text = title
	caption.position = location
	caption.font_size = 48
	caption.pixel_size = 0.010
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(caption)
