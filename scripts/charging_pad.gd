extends StaticBody3D
## Stacja ladujaca zasilana energia sloneczna ze statku.

const CLEARANCE_RADIUS: float = 2.0
const MAX_HEALTH: float = 100.0
const CHARGE_RATE: float = 23.0
const REQUIRED_POWER: float = 4.0

var power_source: Node3D
var health: float = 85.0
var status_label: Label3D


func _ready() -> void:
	name = "ChargingStation"
	collision_layer = 4 | 8
	collision_mask = 0
	var hull := _material(Color(0.18, 0.25, 0.32))
	var trim := _material(Color(0.95, 0.5, 0.15))
	var powered := _material(Color(0.21, 0.94, 0.94), true)
	_add_box("Foundation", Vector3(0, 0.2, 0), Vector3(3.25, 0.4, 3.1), hull)
	_add_box("ParkingArea", Vector3(0, 0.43, 0), Vector3(2.55, 0.08, 2.5), trim)
	_add_box("ChargingColumn", Vector3(0, 1.25, -1.15), Vector3(1.25, 1.8, 0.4), hull)
	_add_box("ControlScreen", Vector3(0, 1.56, -0.92), Vector3(0.84, 0.62, 0.07), powered)
	for x in [-1.15, 1.15]:
		_add_box("PlatformLED", Vector3(x, 0.49, 0.0), Vector3(0.11, 0.09, 1.8), powered)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.8, 2.2, 2.8)
	collision.shape = shape
	collision.position.y = 1.1
	add_child(collision)

	status_label = Label3D.new()
	status_label.position.y = 2.85
	status_label.font_size = 40
	status_label.pixel_size = 0.008
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(status_label)
	_refresh_label()


func can_charge() -> bool:
	return is_instance_valid(power_source) and power_source != null and power_source.has_method("solar_output") and power_source.solar_output() >= REQUIRED_POWER and health > 20.0


func available_rate() -> float:
	return CHARGE_RATE if can_charge() else 0.0


func get_access_radius() -> float:
	return CLEARANCE_RADIUS


func repair(amount: float) -> float:
	var restored: float = minf(maxf(amount, 0.0), MAX_HEALTH - health)
	health += restored
	_refresh_label()
	return restored


func needs_repair() -> bool:
	return health < MAX_HEALTH - 0.01


func _refresh_label() -> void:
	if status_label != null:
		status_label.text = "LADOWARKA | %d%%" % roundi(health)


func _add_box(node_name: String, at: Vector3, dimensions: Vector3, mat: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = at
	instance.material_override = mat
	add_child(instance)


func _material(color: Color, glowing: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.3
	mat.roughness = 0.52
	if glowing:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
