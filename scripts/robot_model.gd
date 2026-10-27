extends Node3D
## Proceduralne, autorskie roboty low-poly. Wszystkie elementy sa meshowane w Godot.
## Role: miner / hauler / engineer. Jeden skrypt odpowiada za spojnosc stylu.

var robot_role: String = "miner"
var dark: StandardMaterial3D
var metal: StandardMaterial3D
var accent: StandardMaterial3D
var lit: StandardMaterial3D


func _ready() -> void:
	dark = _material(Color(0.11, 0.16, 0.21))
	metal = _material(Color(0.36, 0.43, 0.46))
	var tint := Color(0.96, 0.51, 0.13)
	if robot_role == "hauler":
		tint = Color(0.14, 0.73, 0.76)
	elif robot_role == "engineer":
		tint = Color(0.92, 0.82, 0.26)
	accent = _material(tint)
	lit = _material(Color(0.35, 0.93, 1.0), true)

	_add_box("Chassis", Vector3(0, 0.84, 0), Vector3(1.05, 0.55, 1.15), dark)
	_add_box("Hull", Vector3(0, 1.23, 0.02), Vector3(0.92, 0.48, 0.86), metal)
	_add_box("Armor", Vector3(0, 1.38, 0.47), Vector3(0.67, 0.25, 0.07), accent)
	_add_box("Sensor", Vector3(0, 1.38, 0.53), Vector3(0.43, 0.11, 0.04), lit)

	for side in [-1.0, 1.0]:
		for length in [-0.4, 0.4]:
			_add_cylinder("Wheel", Vector3(side * 0.56, 0.46, length), 0.23, 0.19, dark, Vector3(0, 0, 90))
		_add_box("Hub", Vector3(side * 0.66, 0.46, 0), Vector3(0.06, 0.17, 0.17), accent)

	if robot_role == "miner":
		_add_box("DrillMount", Vector3(0.59, 1.06, 0.04), Vector3(0.42, 0.34, 0.38), accent)
		_add_cylinder("DrillArm", Vector3(0.87, 1.03, 0.04), 0.12, 0.56, metal, Vector3(0, 0, 90))
		_add_cylinder("DrillTip", Vector3(1.2, 1.03, 0.04), 0.14, 0.23, accent, Vector3(0, 0, 90))
		_add_box("BatteryBox", Vector3(-0.06, 1.65, -0.2), Vector3(0.63, 0.22, 0.53), dark)
	elif robot_role == "hauler":
		_add_box("CargoPlatform", Vector3(0, 1.68, -0.16), Vector3(1.36, 0.16, 1.04), accent)
		_add_box("CargoLoad", Vector3(0, 1.95, -0.14), Vector3(0.95, 0.39, 0.7), metal)
		for side in [-1.0, 1.0]:
			_add_box("CargoRail", Vector3(side * 0.65, 1.92, -0.16), Vector3(0.07, 0.5, 1.03), dark)
	else:
		_add_box("ToolChest", Vector3(0, 1.68, -0.25), Vector3(0.85, 0.32, 0.65), accent)
		_add_box("ManipulatorPivot", Vector3(0.57, 1.39, -0.1), Vector3(0.28, 0.28, 0.3), dark)
		_add_box("Manipulator", Vector3(0.74, 1.24, 0.22), Vector3(0.16, 0.18, 0.83), metal)
		_add_box("RepairTip", Vector3(0.74, 1.22, 0.65), Vector3(0.25, 0.22, 0.22), lit)

	_add_cylinder("Antenna", Vector3(-0.26, 1.78, -0.19), 0.032, 0.45, metal)
	_add_box("AntennaLight", Vector3(-0.26, 2.03, -0.19), Vector3(0.14, 0.14, 0.14), lit)


func _add_box(node_name: String, at: Vector3, dimensions: Vector3, mat: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = at
	instance.material_override = mat
	add_child(instance)


func _add_cylinder(node_name: String, at: Vector3, radius: float, height: float, mat: Material, rotate: Vector3 = Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = at
	instance.rotation_degrees = rotate
	instance.material_override = mat
	add_child(instance)


func _material(color: Color, glowing: bool = false) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color = color
	value.metallic = 0.35
	value.roughness = 0.58
	if glowing:
		value.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return value
