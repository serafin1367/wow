extends StaticBody3D
## Centrum dowodzenia kolonii - sci-fi, zachowuje kolizje starego ratusza.

const FOOTPRINT_RADIUS: float = 4.5


func _ready() -> void:
	name = "ColonyCommandCenter"
	collision_layer = 4 | 8
	collision_mask = 0

	var hull := _material(Color(0.17, 0.24, 0.30))
	var steel := _material(Color(0.55, 0.62, 0.64))
	var orange := _material(Color(0.98, 0.53, 0.15))
	var blue := _material(Color(0.24, 0.94, 0.98), true)

	_add_box("Foundation", Vector3(0, 0.22, 0), Vector3(7.1, 0.45, 6.1), hull)
	_add_box("MainModule", Vector3(0, 1.98, 0), Vector3(6.0, 3.05, 4.9), steel)
	_add_box("RoofModule", Vector3(0, 3.64, -0.45), Vector3(6.6, 0.42, 5.4), hull)
	_add_box("Bridge", Vector3(0, 3.42, 1.8), Vector3(4.2, 1.05, 1.5), hull)
	_add_box("PanoramaWindow", Vector3(0, 3.51, 2.59), Vector3(3.1, 0.49, 0.09), blue)
	_add_box("Entrance", Vector3(0, 1.27, 2.55), Vector3(1.45, 2.25, 0.11), hull)
	_add_box("EntranceLight", Vector3(0, 2.54, 2.61), Vector3(1.6, 0.13, 0.08), orange)

	for side in [-1.0, 1.0]:
		_add_box("SidePanel", Vector3(side * 3.08, 2.05, 0.1), Vector3(0.17, 2.2, 4.4), hull)
		_add_box("SideStripe", Vector3(side * 3.18, 2.22, 0), Vector3(0.07, 0.14, 3.4), blue)
		_add_box("SolarDeck", Vector3(side * 1.9, 4.14, -0.7), Vector3(2.0, 0.12, 2.9), _material(Color(0.07, 0.20, 0.46)))

	_add_cylinder("CommunicationsPylon", Vector3(0, 5.09, -1.35), 0.13, 2.55, steel)
	_add_box("AntennaBeacon", Vector3(0, 6.48, -1.35), Vector3(0.44, 0.3, 0.44), blue)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.0, 4.4, 5.0)
	collision.shape = shape
	collision.position.y = 2.2
	add_child(collision)

	var caption := Label3D.new()
	caption.name = "BuildingName"
	caption.text = "CENTRUM DOWODZENIA"
	caption.position.y = 7.15
	caption.font_size = 40
	caption.pixel_size = 0.009
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(caption)


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
	mesh.height = height
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	item.mesh = mesh
	item.position = at
	item.material_override = mat
	add_child(item)


func _material(color: Color, glowing: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = 0.35
	result.roughness = 0.5
	if glowing:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result


func to_dict() -> Dictionary:
	return {"save_id": str(get_meta("save_id", "")), "position":
		[global_position.x, global_position.y, global_position.z], "rotation_y": rotation.y}


func from_dict(data: Dictionary) -> void:
	set_meta("save_id", str(data.get("save_id", "")))
