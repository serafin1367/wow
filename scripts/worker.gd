extends CharacterBody3D
## Robotnik idzie po punktach trasy wyznaczonej przez AStarGrid2D.

@export var move_speed: float = 6.0

var waypoints: Array[Vector3] = []
var next_waypoint: int = 0
var selection_ring: MeshInstance3D


func _ready() -> void:
	collision_layer = 2
	# Kolizje ze stalymi przeszkodami, bez wzajemnego blokowania robotnikow.
	collision_mask = 4

	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.45
	capsule_shape.height = 1.8
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = capsule_shape
	collision.position.y = 0.9
	add_child(collision)

	var body := MeshInstance3D.new()
	body.name = "PlaceholderModel"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	body.mesh = capsule
	body.position.y = 0.9
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.18, 0.42, 0.92)
	body.material_override = blue
	add_child(body)

	selection_ring = MeshInstance3D.new()
	selection_ring.name = "SelectionRing"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.65
	ring.outer_radius = 0.8
	selection_ring.mesh = ring
	selection_ring.position.y = 0.07
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.28, 1.0, 0.35)
	green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_ring.material_override = green
	selection_ring.visible = false
	add_child(selection_ring)


func _physics_process(delta: float) -> void:
	while next_waypoint < waypoints.size():
		var offset := waypoints[next_waypoint] - global_position
		offset.y = 0.0
		if offset.length() <= 0.16:
			next_waypoint += 1
		else:
			break

	if next_waypoint >= waypoints.size():
		velocity = Vector3.ZERO
		return

	var difference := waypoints[next_waypoint] - global_position
	difference.y = 0.0
	velocity = difference.normalized() * minf(move_speed, difference.length() / maxf(delta, 0.001))
	move_and_slide()


func command_move(new_path: Array[Vector3]) -> void:
	waypoints = new_path
	next_waypoint = 0


func set_selected(value: bool) -> void:
	selection_ring.visible = value
