extends StaticBody3D
## Modul kolonizacyjny: statek startowy, fotowoltaika i element do naprawy.

signal health_changed(current_health: float, maximum_health: float)

const CLEARANCE_RADIUS: float = 3.8
const MAX_HEALTH: float = 100.0
const NOMINAL_SOLAR_POWER: float = 12.0

var health: float = 70.0
var info: Label3D
var accent_light: StandardMaterial3D


func _ready() -> void:
	name = "LandingRocket"
	collision_layer = 4 | 8
	collision_mask = 0
	var body_material := _material(Color(0.76, 0.8, 0.78))
	var metal_material := _material(Color(0.19, 0.25, 0.32))
	var solar_material := _material(Color(0.08, 0.22, 0.48))
	var trim_material := _material(Color(0.95, 0.49, 0.14))
	accent_light = _material(Color(0.21, 0.9, 1.0), true)

	_add_cylinder("MainHull", Vector3(0, 3.3, 0), 1.47, 5.5, body_material)
	_add_cylinder("Engine", Vector3(0, 0.6, 0), 1.05, 1.1, metal_material)
	_add_cylinder("Cockpit", Vector3(0, 6.4, 0), 0.9, 1.15, solar_material)
	_add_cylinder("Nose", Vector3(0, 7.16, 0), 0.48, 0.55, trim_material)
	_add_box("SolarControl", Vector3(0, 4.2, 1.5), Vector3(1.2, 0.78, 0.12), metal_material)
	_add_box("ControlLight", Vector3(0, 4.2, 1.57), Vector3(0.8, 0.22, 0.06), accent_light)

	for side in [-1.0, 1.0]:
		_add_box("LandingLeg", Vector3(side * 1.75, 0.8, 0.0), Vector3(0.34, 1.6, 0.4), metal_material)
		_add_box("LandingFoot", Vector3(side * 1.85, 0.13, 0.0), Vector3(1.3, 0.23, 0.95), metal_material)
		_add_box("SolarArm", Vector3(side * 2.72, 4.0, 0.0), Vector3(2.0, 0.16, 0.16), metal_material)
		_add_box("SolarPanel", Vector3(side * 4.7, 3.93, 0.0), Vector3(2.85, 0.14, 3.25), solar_material)
		for strip in [-1.0, 0.0, 1.0]:
			_add_box("PanelGrille", Vector3(side * 4.7 + strip * 0.87, 4.02, 0.0), Vector3(0.045, 0.03, 3.25), accent_light)
		_add_box("SolarBorder", Vector3(side * 4.7, 4.02, 1.64), Vector3(2.85, 0.12, 0.055), metal_material)
		_add_box("SolarBorder", Vector3(side * 4.7, 4.02, -1.64), Vector3(2.85, 0.12, 0.055), metal_material)

	# Otwor wyjsciowy skierowany w strone dolu ekranu kamery RTS (+Z).
	_add_box("DockEntrance", Vector3(0, 1.55, 1.5), Vector3(1.7, 2.4, 0.16), metal_material)
	_add_box("DockLight", Vector3(0, 2.8, 1.61), Vector3(1.2, 0.11, 0.04), accent_light)
	_add_box("ExitRamp", Vector3(0, 0.14, 2.58), Vector3(1.8, 0.2, 2.2), metal_material)
	for x in [-0.6, 0.6]:
		_add_box("RampLight", Vector3(x, 0.27, 2.58), Vector3(0.09, 0.045, 2.1), trim_material)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.65
	shape.height = 6.1
	collision.shape = shape
	collision.position.y = 3.0
	add_child(collision)

	info = Label3D.new()
	info.text = "MODUL LADOWANIA"
	info.position.y = 8.2
	info.font_size = 36
	info.pixel_size = 0.009
	info.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(info)
	_refresh_label()


func solar_output() -> float:
	# Uszkodzenia ograniczaja produkcje, ale panel pozostaje czynny.
	return NOMINAL_SOLAR_POWER * health / MAX_HEALTH


func get_access_radius() -> float:
	return CLEARANCE_RADIUS


func repair(amount: float) -> float:
	var restored: float = minf(maxf(amount, 0.0), MAX_HEALTH - health)
	health += restored
	if restored > 0.0:
		health_changed.emit(health, MAX_HEALTH)
		_refresh_label()
	return restored


func needs_repair() -> bool:
	return health < MAX_HEALTH - 0.01


func _refresh_label() -> void:
	if info != null:
		info.text = "STATEK | PV %.1f kW | %d%%" % [solar_output(), roundi(health)]


func _add_box(node_name: String, at: Vector3, dimensions: Vector3, mat: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = at
	instance.material_override = mat
	add_child(instance)


func _add_cylinder(node_name: String, at: Vector3, radius: float, height: float, mat: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	instance.mesh = mesh
	instance.position = at
	instance.material_override = mat
	add_child(instance)


func _material(color: Color, glowing: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.52
	mat.metallic = 0.45
	if glowing:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
