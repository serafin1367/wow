extends Node3D
## Osobna scena podgladu modeli WOW 0.2 (uruchom scene F6).
const ROBOT_SCRIPT = preload("res://scripts/robot_model.gd")
const LANDER_SCRIPT = preload("res://scripts/colony_lander.gd")
const CHARGER_SCRIPT = preload("res://scripts/charging_pad.gd")
const FACTORY_SCRIPT = preload("res://scripts/factory_models.gd")
const KENNEY_ASSETS = preload("res://scripts/kenney_assets.gd")
const SOLAR = preload("res://scripts/solar_array.gd")
const BATTERY = preload("res://scripts/battery_bank.gd")
const GRID_CABLE = preload("res://scripts/power_cable.gd")


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

	# Podglad rzeczywistych plikow Kenney Factory Kit v3.0 (CC0).
	var factory_names: Array[String] = ["machine", "conveyor-long", "machine-window", "robot-arm-a", "hopper-square"]
	for i in range(factory_names.size()):
		var factory = KENNEY_ASSETS.model("factory", factory_names[i], 2.0 if i < 3 else 1.6)
		if factory == null:
			factory = FACTORY_SCRIPT.new()
			factory.machine_type = "conveyor" if i == 1 else "extractor"
		factory.position = Vector3(float(i) * 6.2 - 13.0, 0.0, 8.0)
		add_child(factory)
		_label(factory_names[i].to_upper(), factory.position + Vector3(0, 4.5, 0))

	# Osobna galeria przyrody: dziala nawet bez glownej mapy.
	var nature_names: Array[String] = ["tree-oak", "tree-default", "tree-cone", "rock-largea", "rock-largeb"]
	for i in range(nature_names.size()):
		var scale: float = 3.8 if i < 3 else 3.0
		var nature = KENNEY_ASSETS.model("nature", nature_names[i], scale)
		if nature != null:
			nature.position = Vector3(float(i) * 5.2 - 12.0, 0.0, 18.0)
			add_child(nature)
			_label(nature_names[i].to_upper(), nature.position + Vector3(0, 5.4, 0))

	# WOW 0.9: fotowoltaika i akumulatory do obejrzenia z bliska.
	var panel = SOLAR.new()
	panel.position = Vector3(19, 0, -3)
	add_child(panel)
	_label("SOLAR 4 kW", panel.position + Vector3(0, 6.0, 0))
	var bank = BATTERY.new()
	bank.position = Vector3(19, 0, 5)
	bank.stored_kwh = 4.0
	add_child(bank)
	_label("BATTERY 8 kWh", bank.position + Vector3(0, 4.2, 0))

	var cable = GRID_CABLE.new()
	cable.setup(panel.position, bank.position)
	add_child(cable)

	var extractor = FACTORY_SCRIPT.new()
	extractor.machine_type = "extractor"
	extractor.is_working = true
	extractor.position = Vector3(-21, 0, 7)
	add_child(extractor)
	_label("DRILL - MOVING", extractor.position + Vector3(0, 5.1, 0))
	var furnace = FACTORY_SCRIPT.new()
	furnace.machine_type = "smelter"
	furnace.is_working = true
	furnace.position = Vector3(-21, 0, 17)
	add_child(furnace)
	_label("FURNACE - SPARKS", furnace.position + Vector3(0, 7.0, 0))

	var camera := Camera3D.new()
	camera.position = Vector3(-2, 39, 65)
	camera.fov = 65.0
	add_child(camera)
	camera.look_at(Vector3(0, 4, 6), Vector3.UP)
	camera.current = true


func _label(title: String, location: Vector3) -> void:
	var caption := Label3D.new()
	caption.text = title
	caption.position = location
	caption.font_size = 48
	caption.pixel_size = 0.010
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(caption)
