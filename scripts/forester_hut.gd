extends StaticBody3D
## Lesniczowka okresowo zglasza potrzebe posadzenia drzewa.
## Miejsce nasadzenia i dojrzewanie kontroluje glowna scena.

signal plant_requested(hut: StaticBody3D)

const FOOTPRINT_RADIUS: float = 3.1
const PLANT_RADIUS: float = 17.0
const PLANT_INTERVAL: float = 8.0
const MAX_LOCAL_TREES: int = 12

var plant_attempts: int = 0
var planting_timer: Timer


func _ready() -> void:
	name = "ForesterHut"
	collision_layer = 4 | 8
	collision_mask = 0

	var foundation := MeshInstance3D.new()
	foundation.name = "Foundation"
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(4.0, 0.35, 4.0)
	foundation.mesh = base_mesh
	foundation.position.y = 0.18
	foundation.material_override = _material(Color(0.36, 0.33, 0.25))
	add_child(foundation)

	var hut := MeshInstance3D.new()
	hut.name = "Hut"
	var hut_mesh := BoxMesh.new()
	hut_mesh.size = Vector3(3.3, 2.6, 3.3)
	hut.mesh = hut_mesh
	hut.position.y = 1.6
	hut.material_override = _material(Color(0.56, 0.38, 0.23))
	add_child(hut)

	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(4.2, 0.55, 4.2)
	roof.mesh = roof_mesh
	roof.position.y = 3.1
	roof.material_override = _material(Color(0.16, 0.37, 0.20))
	add_child(roof)

	var doorway := MeshInstance3D.new()
	doorway.name = "Door"
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(0.9, 1.9, 0.12)
	doorway.mesh = door_mesh
	doorway.position = Vector3(0.0, 1.1, 1.72)
	doorway.material_override = _material(Color(0.25, 0.17, 0.10))
	add_child(doorway)

	var title := Label3D.new()
	title.name = "Title"
	title.text = "LESNICZOWKA"
	title.position.y = 4.2
	title.font_size = 38
	title.pixel_size = 0.009
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(title)

	var collision := CollisionShape3D.new()
	collision.name = "BuildingCollision"
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


func _material(tint: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = tint
	result.roughness = 0.95
	return result
