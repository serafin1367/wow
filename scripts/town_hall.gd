extends StaticBody3D
## Prototypowy ratusz: wizualizacja, kolizje i punkt szkolenia robotnikow.

const FOOTPRINT_RADIUS: float = 4.5


func _ready() -> void:
	name = "TownHall"
	# Warstwa 4 blokuje jednostki; warstwa 8 pozwala wybierac budynki osobno.
	collision_layer = 4 | 8
	collision_mask = 0

	var foundation := MeshInstance3D.new()
	foundation.name = "Foundation"
	var foundation_mesh := BoxMesh.new()
	foundation_mesh.size = Vector3(7.0, 0.35, 6.0)
	foundation.mesh = foundation_mesh
	foundation.position.y = 0.18
	foundation.material_override = _material(Color(0.38, 0.39, 0.36))
	add_child(foundation)

	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	var walls_mesh := BoxMesh.new()
	walls_mesh.size = Vector3(6.0, 3.4, 5.0)
	walls.mesh = walls_mesh
	walls.position.y = 2.0
	walls.material_override = _material(Color(0.65, 0.51, 0.34))
	add_child(walls)

	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(7.1, 0.65, 6.1)
	roof.mesh = roof_mesh
	roof.position.y = 4.05
	roof.material_override = _material(Color(0.27, 0.32, 0.39))
	add_child(roof)

	var door := MeshInstance3D.new()
	door.name = "Door"
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(1.25, 2.15, 0.12)
	door.mesh = door_mesh
	door.position = Vector3(0.0, 1.25, 2.56)
	door.material_override = _material(Color(0.33, 0.22, 0.12))
	add_child(door)

	var label := Label3D.new()
	label.text = "RATUSZ"
	label.position.y = 5.15
	label.font_size = 44
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

	var hitbox := CollisionShape3D.new()
	hitbox.name = "BuildingCollision"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(6.0, 4.4, 5.0)
	hitbox.shape = box_shape
	hitbox.position.y = 2.2
	add_child(hitbox)


func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	return result
