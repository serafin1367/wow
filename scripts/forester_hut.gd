extends StaticBody3D
## Modul rekultywacji: sadzi drzewa, funkcjonalnie zastępuje lesniczowke.

signal plant_requested(hut: StaticBody3D)

const FOOTPRINT_RADIUS: float = 3.1
const PLANT_RADIUS: float = 17.0
const PLANT_INTERVAL: float = 8.0
const MAX_LOCAL_TREES: int = 12

var plant_attempts: int = 0
var planting_timer: Timer


func _ready() -> void:
	name = "BioRegenerator"
	collision_layer = 4 | 8
	collision_mask = 0
	var hull := _material(Color(0.14, 0.22, 0.27))
	var shell := _material(Color(0.53, 0.66, 0.64))
	var green := _material(Color(0.30, 0.98, 0.55), true)
	var orange := _material(Color(0.96, 0.53, 0.19))

	_add_box("Foundation", Vector3(0, 0.23, 0), Vector3(4.4, 0.46, 4.3), hull)
	_add_box("Core", Vector3(0, 1.53, 0), Vector3(3.2, 2.45, 3.1), shell)
	_add_box("Roof", Vector3(0, 2.92, 0), Vector3(3.8, 0.4, 3.55), hull)
	_add_box("Entrance", Vector3(0, 1.14, 1.65), Vector3(1.1, 1.85, 0.12), hull)
	_add_box("GreenhouseWindow", Vector3(0, 2.16, 1.74), Vector3(2.5, 0.45, 0.1), green)

	for side in [-1.0, 1.0]:
		_add_box("Support", Vector3(side * 1.88, 1.37, 0), Vector3(0.25, 2.1, 3.35), hull)
		_add_box("Ventilation", Vector3(side * 1.15, 3.28, 0), Vector3(0.8, 0.38, 0.72), orange)
	_add_cylinder("SeedVessel", Vector3(0, 3.76, -0.72), 0.65, 1.1, green)

	var label := Label3D.new()
	label.text = "MODUL REKULTYWACJI"
	label.position.y = 5.05
	label.font_size = 36
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.8, 3.2, 3.8)
	collision.shape = shape
	collision.position.y = 1.6
	add_child(collision)

	planting_timer = Timer.new()
	planting_timer.name = "PlantingTimer"
	planting_timer.wait_time = PLANT_INTERVAL
	planting_timer.one_shot = false
	planting_timer.timeout.connect(_on_planting_timer)
	add_child(planting_timer)
	planting_timer.start()


func _on_planting_timer() -> void:
	plant_attempts += 1
	plant_requested.emit(self)


func _add_box(node_name: String, at: Vector3, size: Vector3, mat: Material) -> void:
	var item := MeshInstance3D.new()
	item.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.position = at
	item.material_override = mat
	add_child(item)


func _add_cylinder(node_name: String, at: Vector3, radius: float, height: float, mat: Material) -> void:
	var item := MeshInstance3D.new()
	item.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	item.mesh = mesh
	item.position = at
	item.material_override = mat
	add_child(item)


func _material(tint: Color, glowing: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = tint
	result.metallic = 0.34
	result.roughness = 0.52
	if glowing:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result


func to_dict() -> Dictionary:
	return {"save_id": str(get_meta("save_id", "")), "position":
		[global_position.x, global_position.y, global_position.z],
		"rotation_y": rotation.y, "plant_attempts": plant_attempts,
		"timer_left": planting_timer.time_left if planting_timer != null else 0.0}


func from_dict(data: Dictionary) -> void:
	set_meta("save_id", str(data.get("save_id", "")))
	plant_attempts = int(data.get("plant_attempts", 0))
	if planting_timer != null and planting_timer.is_inside_tree():
		planting_timer.start(maxf(0.01, float(data.get("timer_left", 8.0))))
