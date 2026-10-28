extends StaticBody3D
## WOW 0.9: obrotowa farma fotowoltaiczna +4 kW, bez paliwa.
## Panel rusza sie wolno, tylko wtedy gdy generuje energie.
const KENNEY = preload("res://scripts/kenney_assets.gd")
const OUTPUT_KW: float = 4.0
const CLEARANCE_RADIUS: float = 2.8

var tracking: bool = true
var tracker: Node3D
var module: Node3D
var elapsed: float = 0.0


func _ready() -> void:
	name = "SolarArray"
	collision_layer = 4 | 8
	collision_mask = 0
	var metal := _mat(Color(0.14, 0.20, 0.25))
	var steel := _mat(Color(0.43, 0.52, 0.56))
	var orange := _mat(Color(0.99, 0.50, 0.13))
	var cyan := _mat(Color(0.15, 0.32, 0.55))
	var glow := _mat(Color(0.20, 0.87, 0.94), true)

	_box(self, "Footing", Vector3(0, 0.23, 0), Vector3(4.4, 0.46, 4.3), metal)
	_box(self, "OrangeBaseTrim", Vector3(0, 0.52, 0), Vector3(3.3, 0.12, 3.2), orange)
	var imported = KENNEY.model("factory", "machine", 1.05)
	if imported != null:
		imported.name = "KenneyIndustrialDrive"
		imported.position = Vector3(0, 0.55, -0.18)
		add_child(imported)
	_box(self, "Axle", Vector3(0, 1.70, 0), Vector3(0.43, 2.0, 0.46), steel)
	_box(self, "TrackingHead", Vector3(0, 2.84, 0), Vector3(1.6, 0.28, 0.95), orange)

	tracker = Node3D.new()
	tracker.name = "SolarAzimuthMotor"
	tracker.position.y = 2.95
	add_child(tracker)
	module = Node3D.new()
	module.name = "SolarTiltMotor"
	tracker.add_child(module)
	_box(module, "MainPanel", Vector3.ZERO, Vector3(5.4, 0.16, 3.4), metal)
	_box(module, "BlueCells", Vector3(0, 0.10, 0), Vector3(5.08, 0.065, 3.10), cyan)
	for x in range(1, 7):
		_box(module, "PVGridX", Vector3(-2.5 + float(x) * 0.72, 0.14, 0), Vector3(0.034, 0.02, 3.04), glow)
	for z in range(1, 5):
		_box(module, "PVGridZ", Vector3(0, 0.14, -1.55 + float(z) * 0.62), Vector3(5.04, 0.02, 0.034), steel)

	var collider := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = Vector3(4.25, 3.0, 4.1)
	collider.shape = cube
	collider.position.y = 1.5
	add_child(collider)


func _process(delta: float) -> void:
	if tracking:
		elapsed += delta
		tracker.rotation.y = sin(elapsed * 0.17) * 0.72
		module.rotation.x = -0.28 + sin(elapsed * 0.12) * 0.19


func solar_output() -> float:
	return OUTPUT_KW if tracking else 0.0


func get_access_radius() -> float:
	return CLEARANCE_RADIUS


func describe() -> String:
	return "Panel obrotowy | %.1f kW | sledzenie slonca %s" % [
		solar_output(), "TAK" if tracking else "NIE"
	]


func _box(parent: Node3D, part: String, pos: Vector3, size: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = part
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = material
	parent.add_child(mesh)


func _mat(color: Color, self_illuminated: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = 0.43
	result.roughness = 0.48
	if self_illuminated:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result


func to_dict() -> Dictionary:
	return {"save_id": str(get_meta("save_id", "")), "position":
		[global_position.x, global_position.y, global_position.z],
		"rotation_y": rotation.y, "tracking": tracking, "elapsed": elapsed}


func from_dict(data: Dictionary) -> void:
	set_meta("save_id", str(data.get("save_id", "")))
	tracking = bool(data.get("tracking", true))
	elapsed = float(data.get("elapsed", 0.0))
