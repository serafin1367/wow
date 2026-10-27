extends CharacterBody3D
## WOW 0.2: roboty kolonii - gornik, transportowiec i technik.
## Wspolny ruch A*, akumulator, ladowanie, transport oraz naprawy.

signal resource_delivered(resource_type: String, quantity: int)

const MODEL_SCRIPT = preload("res://scripts/robot_model.gd")

enum WorkState { IDLE, MOVING, TO_RESOURCE, GATHERING, TO_DEPOT, TO_CHARGER, CHARGING, TO_REPAIR, REPAIRING }

const BATTERY_MAX: float = 100.0
const LOW_BATTERY: float = 22.0
const BATTERY_RESUME: float = 98.0
const HARVEST_INTERVAL: float = 1.0
const REPAIR_RATE: float = 6.0

@export var move_speed: float = 6.0
@export_enum("miner", "hauler", "engineer") var robot_role: String = "miner"

var waypoints: Array[Vector3] = []
var next_waypoint: int = 0
var selection_ring: MeshInstance3D

var state: WorkState = WorkState.IDLE
var resource_target = null
var repair_target = null
var preferred_resource_type: String = ""
var navigation_grid = null
var charging_station: Node3D
var depot_position: Vector3 = Vector3.ZERO
var energy: float = BATTERY_MAX
var harvest_elapsed: float = 0.0
var idle_search_elapsed: float = 0.0
var carried_type: String = ""
var carried_amount: int = 0

var suspended_state: WorkState = WorkState.IDLE
var suspended_destination: Vector3 = Vector3.ZERO


func _ready() -> void:
	collision_layer = 2
	collision_mask = 4

	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.47
	capsule_shape.height = 1.8
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = capsule_shape
	collision.position.y = 0.9
	add_child(collision)

	var body = MODEL_SCRIPT.new()
	body.name = "RobotVisual"
	body.robot_role = robot_role
	add_child(body)

	selection_ring = MeshInstance3D.new()
	selection_ring.name = "SelectionRing"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.68
	ring.outer_radius = 0.81
	selection_ring.mesh = ring
	selection_ring.position.y = 0.07
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.28, 1.0, 0.35)
	green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_ring.material_override = green
	selection_ring.visible = false
	add_child(selection_ring)


func _physics_process(delta: float) -> void:
	if state == WorkState.CHARGING:
		velocity = Vector3.ZERO
		if is_instance_valid(charging_station):
			energy = minf(BATTERY_MAX, energy + charging_station.available_rate() * delta)
		if energy >= BATTERY_RESUME:
			_resume_after_charging()
		return

	var usage: float = 0.035
	if state == WorkState.GATHERING:
		usage = 1.15
	elif state == WorkState.REPAIRING:
		usage = 1.4
	elif state != WorkState.IDLE and state != WorkState.TO_CHARGER:
		usage = 0.7
	elif state == WorkState.TO_CHARGER:
		usage = 0.35
	energy = maxf(0.0, energy - usage * delta)

	if state != WorkState.TO_CHARGER and energy <= LOW_BATTERY and is_instance_valid(charging_station):
		if _begin_recharge():
			return

	if state == WorkState.GATHERING:
		velocity = Vector3.ZERO
		_process_harvest(delta)
		return

	if state == WorkState.REPAIRING:
		velocity = Vector3.ZERO
		_process_repair(delta)
		return

	if state == WorkState.IDLE:
		velocity = Vector3.ZERO
		if preferred_resource_type != "" and navigation_grid != null and energy > LOW_BATTERY:
			idle_search_elapsed += delta
			if idle_search_elapsed >= 2.0:
				idle_search_elapsed = 0.0
				_go_to_resource()
		return

	while next_waypoint < waypoints.size():
		var offset := waypoints[next_waypoint] - global_position
		offset.y = 0.0
		if offset.length() <= 0.18:
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
	if velocity.length_squared() > 0.05:
		var visual := get_node_or_null("RobotVisual") as Node3D
		if visual != null:
			visual.rotation.y = atan2(velocity.x, velocity.z)


func command_move(new_path: Array[Vector3]) -> void:
	resource_target = null
	repair_target = null
	preferred_resource_type = ""
	waypoints = new_path
	next_waypoint = 0
	state = WorkState.MOVING if not new_path.is_empty() else WorkState.IDLE


func command_gather(target: Node3D, grid: RefCounted, drop_point: Vector3) -> void:
	if robot_role == "engineer":
		return
	if not is_instance_valid(target) or not target.has_method("harvest"):
		return
	repair_target = null
	resource_target = target
	preferred_resource_type = target.resource_type
	navigation_grid = grid
	depot_position = drop_point
	if carried_amount > 0 and carried_type != resource_target.resource_type:
		_go_to_depot()
	else:
		_go_to_resource()


func command_repair(target: Node3D, grid: RefCounted) -> void:
	if robot_role != "engineer":
		return
	if not is_instance_valid(target) or not target.has_method("repair"):
		return
	preferred_resource_type = ""
	resource_target = null
	repair_target = target
	navigation_grid = grid
	_go_to_repair()


func command_charge() -> void:
	preferred_resource_type = ""
	resource_target = null
	repair_target = null
	suspended_state = WorkState.IDLE
	if not _navigate_to_charger():
		state = WorkState.IDLE


func _begin_recharge() -> bool:
	if navigation_grid == null:
		return false
	var previous: WorkState = state
	var target := global_position
	if not waypoints.is_empty():
		target = waypoints[waypoints.size() - 1]
	if not _navigate_to_charger():
		return false
	suspended_state = previous
	suspended_destination = target
	return true


func _navigate_to_charger() -> bool:
	if not is_instance_valid(charging_station) or navigation_grid == null:
		return false
	var route: Array[Vector3] = navigation_grid.find_access_path(global_position, charging_station.global_position, 2.7)
	if route.is_empty():
		return false
	waypoints = route
	next_waypoint = 0
	state = WorkState.TO_CHARGER
	return true


func _resume_after_charging() -> void:
	var next: WorkState = suspended_state
	suspended_state = WorkState.IDLE
	if next == WorkState.TO_DEPOT:
		_go_to_depot()
	elif next == WorkState.TO_RESOURCE or next == WorkState.GATHERING:
		_go_to_resource()
	elif next == WorkState.TO_REPAIR or next == WorkState.REPAIRING:
		_go_to_repair()
	elif next == WorkState.MOVING and navigation_grid != null:
		var route: Array[Vector3] = navigation_grid.find_path(global_position, suspended_destination)
		command_move(route)
	else:
		state = WorkState.IDLE


func _go_to_resource() -> void:
	if not _resource_available():
		resource_target = _find_alternative_resource()
	if not _resource_available():
		if carried_amount > 0:
			_go_to_depot()
		else:
			state = WorkState.IDLE
		return
	_start_route(resource_target.global_position, WorkState.TO_RESOURCE)


func _go_to_depot() -> void:
	if carried_amount <= 0:
		state = WorkState.IDLE
		return
	if navigation_grid == null:
		state = WorkState.IDLE
		return
	var route: Array[Vector3] = navigation_grid.find_access_path(global_position, depot_position, 3.5)
	if route.is_empty():
		state = WorkState.IDLE
		push_warning("Brak trasy do magazynu.")
		return
	waypoints = route
	next_waypoint = 0
	state = WorkState.TO_DEPOT


func _go_to_repair() -> void:
	if not is_instance_valid(repair_target) or not repair_target.needs_repair():
		state = WorkState.IDLE
		return
	if navigation_grid == null:
		state = WorkState.IDLE
		return
	var radius: float = repair_target.CLEARANCE_RADIUS + 0.55
	var route: Array[Vector3] = navigation_grid.find_access_path(global_position, repair_target.global_position, radius)
	if route.is_empty():
		state = WorkState.IDLE
		push_warning("Brak dostepu do naprawianej instalacji.")
		return
	waypoints = route
	next_waypoint = 0
	state = WorkState.TO_REPAIR


func _find_alternative_resource() -> Node3D:
	var nearest: Node3D = null
	var best: float = INF
	for source in get_tree().get_nodes_in_group("resource_nodes"):
		if source.resource_type != preferred_resource_type or source.remaining <= 0:
			continue
		var distance: float = global_position.distance_squared_to(source.global_position)
		if distance < best:
			best = distance
			nearest = source
	return nearest


func _start_route(target: Vector3, next_state: WorkState) -> void:
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
		else:
			_go_to_resource()
	elif state == WorkState.TO_DEPOT:
		if carried_amount > 0:
			resource_delivered.emit(carried_type, carried_amount)
			carried_amount = 0
			carried_type = ""
		if preferred_resource_type != "":
			_go_to_resource()
		else:
			state = WorkState.IDLE
	elif state == WorkState.TO_CHARGER:
		state = WorkState.CHARGING
	elif state == WorkState.TO_REPAIR:
		state = WorkState.REPAIRING
	else:
		state = WorkState.IDLE


func _process_harvest(delta: float) -> void:
	if not _resource_available():
		if carried_amount > 0:
			_go_to_depot()
		else:
			_go_to_resource()
		return
	harvest_elapsed += delta
	if harvest_elapsed < HARVEST_INTERVAL:
		return
	harvest_elapsed = 0.0
	var capacity: int = 25 if robot_role == "hauler" else 10
	var rate: int = 2 if robot_role == "hauler" else 4
	var quantity: int = mini(rate, capacity - carried_amount)
	var obtained: int = resource_target.harvest(quantity)
	if obtained > 0:
		if carried_amount == 0:
			carried_type = resource_target.resource_type
		carried_amount += obtained
	if carried_amount >= capacity or not _resource_available():
		_go_to_depot()


func _process_repair(delta: float) -> void:
	if not is_instance_valid(repair_target):
		state = WorkState.IDLE
		return
	if not repair_target.needs_repair():
		state = WorkState.IDLE
		return
	repair_target.repair(REPAIR_RATE * delta)


func _resource_available() -> bool:
	return is_instance_valid(resource_target) and resource_target != null and resource_target.remaining > 0


func set_selected(value: bool) -> void:
	if selection_ring != null:
		selection_ring.visible = value


func role_name() -> String:
	if robot_role == "hauler":
		return "TRANSPORT"
	if robot_role == "engineer":
		return "NAPRAWA"
	return "GORNIK"


func status_text() -> String:
	match state:
		WorkState.IDLE:
			return "Oczekiwanie"
		WorkState.MOVING:
			return "Przejazd"
		WorkState.TO_RESOURCE:
			return "Jedzie po surowce"
		WorkState.GATHERING:
			return "Wydobywanie"
		WorkState.TO_DEPOT:
			return "Dostawa"
		WorkState.TO_CHARGER:
			return "Jedzie na ladowanie"
		WorkState.CHARGING:
			return "Ladowanie"
		WorkState.TO_REPAIR:
			return "Jedzie naprawiac"
		WorkState.REPAIRING:
			return "Naprawa"
	return "Oczekiwanie"
