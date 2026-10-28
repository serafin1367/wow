extends StaticBody3D
## WOW 0.14: niezalezny magazyn posredni, obslugiwany przez te same porty co fabryki.
const INVENTORY = preload("res://scripts/inventory.gd")
const CLEARANCE_RADIUS: float = 3.2
const CAPACITY_PER_RESOURCE: int = 120
const ACCEPTED: Array[String] = ["wood", "stone", "gold", "iron_ore", "metal"]

var cargo = INVENTORY.new("building:depot:buffer")


func _init() -> void:
	for material in ACCEPTED:
		cargo.configure(material, CAPACITY_PER_RESOURCE)


func _ready() -> void:
	name = "LogisticsDepot"
	collision_layer = 4 | 8
	collision_mask = 0
	var shell := _mat(Color(0.28, 0.39, 0.43))
	var roof := _mat(Color(0.11, 0.16, 0.19))
	var edge := _mat(Color(0.95, 0.56, 0.15))
	_box("Base", Vector3(0.0, 0.24, 0.0), Vector3(4.8, 0.48, 4.7), roof)
	_box("Warehouse", Vector3(0.0, 1.75, 0.0), Vector3(3.65, 2.6, 3.5), shell)
	_box("Roof", Vector3(0.0, 3.13, 0.0), Vector3(4.4, 0.28, 4.2), roof)
	_box("LoadingDock", Vector3(0.0, 0.56, 2.18), Vector3(2.7, 0.32, 1.0), edge)
	_box("Gateway", Vector3(0.0, 1.37, 1.80), Vector3(2.0, 2.1, 0.1), roof)
	for side in [-1.0, 1.0]:
		_box("Beacon", Vector3(side * 2.04, 3.40, 1.66), Vector3(0.23, 0.32, 0.23), edge)
	var title := Label3D.new()
	title.text = "DEPOT"
	title.position.y = 4.2
	title.font_size = 42
	title.pixel_size = 0.009
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(title)
	var collider := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(4.5, 3.45, 4.2)
	collider.shape = volume
	collider.position.y = 1.72
	add_child(collider)


func _box(label: String, pos: Vector3, dim: Vector3, material: Material) -> void:
	var visual := MeshInstance3D.new()
	visual.name = label
	var mesh := BoxMesh.new()
	mesh.size = dim
	visual.mesh = mesh
	visual.position = pos
	visual.material_override = material
	add_child(visual)


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.74
	return mat


func get_access_radius() -> float:
	return CLEARANCE_RADIUS


func get_input_port(resource_type: String):
	return cargo if ACCEPTED.has(resource_type) else null


func get_output_port(resource_type: String):
	return cargo if ACCEPTED.has(resource_type) else null


func deposit_resource(resource_type: String, amount: int) -> int:
	return cargo.push(resource_type, amount)


func withdraw_resource(resource_type: String, amount: int) -> int:
	return cargo.pull(resource_type, amount)


func describe() -> String:
	var chunks: Array[String] = []
	for resource_type in ACCEPTED:
		if cargo.quantity(resource_type) > 0:
			chunks.append("%s:%d" % [resource_type, cargo.quantity(resource_type)])
	return "Magazyn posredni | " + (", ".join(chunks) if chunks.size() > 0 else "pusty") + " | limit %d/typ" % CAPACITY_PER_RESOURCE


func to_dict() -> Dictionary:
	return {"save_id": str(get_meta("save_id", "")), "position":
		[global_position.x, global_position.y, global_position.z],
		"rotation_y": rotation.y, "inventory": cargo.to_dict()}


func from_dict(data: Dictionary) -> void:
	set_meta("save_id", str(data.get("save_id", "")))
	if data.has("inventory"):
		cargo.from_dict(data["inventory"])
