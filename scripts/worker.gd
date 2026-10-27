extends CharacterBody3D
## Tymczasowy robotnik; proste przemieszczanie w linii prostej po plaskiej mapie.
## Omijanie przeszkod i nawigacja grupowa to osobny etap.

@export var move_speed: float = 6.0

var destination: Vector3 = Vector3.ZERO
var has_destination: bool = false
var selection_ring: MeshInstance3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0

	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.8
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
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
	if not has_destination:
		velocity = Vector3.ZERO
		return

	var difference := destination - global_position
	difference.y = 0.0
	if difference.length() < 0.12:
		has_destination = false
		velocity = Vector3.ZERO
		return

	velocity = difference.normalized() * minf(move_speed, difference.length() / maxf(delta, 0.001))
	move_and_slide()


func command_move(target: Vector3) -> void:
	destination = Vector3(clampf(target.x, -48.0, 48.0), 0.0, clampf(target.z, -48.0, 48.0))
	has_destination = true


func set_selected(value: bool) -> void:
	selection_ring.visible = value
