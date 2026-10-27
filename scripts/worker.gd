extends CharacterBody3D
## Prosty robotnik RTS: ruch A*, zbieranie surowca i dostawa do magazynu.

signal resource_delivered(resource_type: String, quantity: int)

enum WorkState { IDLE, MOVING, TO_RESOURCE, GATHERING, TO_DEPOT }

const CARRY_CAPACITY: int = 10
const HARVEST_PER_TICK: int = 2
const HARVEST_INTERVAL: float = 1.0

@export var move_speed: float = 6.0

var waypoints: Array[Vector3] = []
var next_waypoint: int = 0
var selection_ring: MeshInstance3D

var state: WorkState = WorkState.IDLE
var resource_target = null
var navigation_grid = null
var depot_position: Vector3 = Vector3.ZERO
var harvest_elapsed: float = 0.0
var carried_type: String = ""
var carried_amount: int = 0


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
	if state == WorkState.GATHERING:
		velocity = Vector3.ZERO
		_process_harvest(delta)
		return

	if state == WorkState.IDLE:
		velocity = Vector3.ZERO
		return

	while next_waypoint < waypoints.size():
		var offset := waypoints[next_waypoint] - global_position
		offset.y = 0.0
		if offset.length() <= 0.16:
			next_waypoint += 1
		else:
			break

	if next_waypoint >= waypoints.size():
		velocity = Vector3.ZERO
		_finish_route()
		return

	var difference := waypoints[next_waypoint] - global_position
	difference.y = 0.0
	velocity = difference.normalized() * minf(move_speed, difference.length() / maxf(delta, 0.001))
	move_and_slide()


func command_move(new_path: Array[Vector3]) -> void:
	# Rozkaz przemieszczania przerywa biezace zbieranie.
	resource_target = null
	waypoints = new_path
	next_waypoint = 0
	state = WorkState.MOVING if not new_path.is_empty() else WorkState.IDLE


func command_gather(target: Node3D, grid: RefCounted, drop_point: Vector3) -> void:
	if not is_instance_valid(target) or not target.has_method("harvest"):
		return
	resource_target = target
	navigation_grid = grid
	depot_position = drop_point

	# Przed zmiana rodzaju surowca oddaj wczesniejszy ladunek.
	if carried_amount > 0 and carried_type != resource_target.resource_type:
		_go_to_depot()
	else:
		_go_to_resource()


func _go_to_resource() -> void:
	if not _resource_available():
		if carried_amount > 0:
			_go_to_depot()
		else:
			state = WorkState.IDLE
		return
	var target_position: Vector3 = resource_target.global_position
	_start_route(target_position, WorkState.TO_RESOURCE)


func _go_to_depot() -> void:
	if carried_amount <= 0:
		state = WorkState.IDLE
		return
	_start_route(depot_position, WorkState.TO_DEPOT)


func _start_route(target: Vector3, next_state: int) -> void:
	if navigation_grid == null:
		state = WorkState.IDLE
		return
	var route: Array[Vector3] = navigation_grid.find_path(global_position, target)
	if route.is_empty():
		state = WorkState.IDLE
		return
	waypoints = route
	next_waypoint = 0
	state = next_state


func _finish_route() -> void:
	if state == WorkState.TO_RESOURCE:
		if _resource_available():
			harvest_elapsed = 0.0
			state = WorkState.GATHERING
		elif carried_amount > 0:
			_go_to_depot()
		else:
			state = WorkState.IDLE
	elif state == WorkState.TO_DEPOT:
		if carried_amount > 0:
			resource_delivered.emit(carried_type, carried_amount)
			carried_amount = 0
			carried_type = ""
		if _resource_available():
			_go_to_resource()
		else:
			state = WorkState.IDLE
	else:
		state = WorkState.IDLE


func _process_harvest(delta: float) -> void:
	if not _resource_available():
		if carried_amount > 0:
			_go_to_depot()
		else:
			state = WorkState.IDLE
		return

	harvest_elapsed += delta
	if harvest_elapsed < HARVEST_INTERVAL:
		return
	harvest_elapsed = 0.0

	var quantity: int = mini(HARVEST_PER_TICK, CARRY_CAPACITY - carried_amount)
	var obtained: int = resource_target.harvest(quantity)
	if obtained > 0:
		if carried_amount == 0:
			carried_type = resource_target.resource_type
		carried_amount += obtained

	if carried_amount >= CARRY_CAPACITY or not _resource_available():
		_go_to_depot()


func _resource_available() -> bool:
	return is_instance_valid(resource_target) and resource_target != null and resource_target.remaining > 0


func set_selected(value: bool) -> void:
	selection_ring.visible = value
