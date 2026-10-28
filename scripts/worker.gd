extends CharacterBody3D
## WOW 0.2: roboty kolonii - gornik, transportowiec i technik.
## Wspolny ruch A*, akumulator, ladowanie, transport oraz naprawy.

signal resource_delivered(resource_type: String, quantity: int)

const MODEL_SCRIPT = preload("res://scripts/robot_model.gd")

enum WorkState { IDLE, MOVING, TO_RESOURCE, GATHERING, TO_DEPOT, TO_CHARGER, CHARGING, TO_REPAIR, REPAIRING, TO_FACTORY_PICKUP, WAIT_FACTORY_PICKUP, TO_FACTORY_INPUT, WAIT_FACTORY_OUTPUT, TO_FACTORY_DEPOT, TO_LOGISTICS_PICKUP, TO_LOGISTICS_DELIVERY }

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
var road_network = null
const ROAD_SPEED_MULTIPLIER: float = 1.25
var charging_station = null
var depot_position: Vector3 = Vector3.ZERO
var energy: float = BATTERY_MAX
var harvest_elapsed: float = 0.0
var idle_search_elapsed: float = 0.0
var carried_type: String = ""
var carried_amount: int = 0

var suspended_state: WorkState = WorkState.IDLE
var suspended_destination: Vector3 = Vector3.ZERO
var factory_mine = null
var factory_smelter = null
var factory_route_active: bool = false
var factory_stage: String = "pickup"
var factory_wait_elapsed: float = 0.0
var ore_belt_enabled: bool = false
var metal_belt_enabled: bool = false
var logistics_job_id: String = ""
var logistics_source = null
var logistics_destination = null
var logistics_manager = null
var logistics_type: String = ""
var logistics_amount: int = 0
var logistics_sink: bool = false


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

	if state == WorkState.WAIT_FACTORY_PICKUP or state == WorkState.WAIT_FACTORY_OUTPUT:
		velocity = Vector3.ZERO
		_process_factory_wait(delta)
		return

	if state == WorkState.IDLE:
		velocity = Vector3.ZERO
		if logistics_job_id != "":
			factory_wait_elapsed += delta
			if factory_wait_elapsed > 1.0:
				factory_wait_elapsed = 0.0
				_route_logistics(carried_amount == 0)
			return
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
	var current_speed: float = move_speed
	if is_instance_valid(road_network) and road_network != null:
		var current_cell := Vector2i(roundi(global_position.x), roundi(global_position.z))
		if road_network.has_cell(current_cell):
			current_speed *= ROAD_SPEED_MULTIPLIER
	velocity = difference.normalized() * minf(current_speed, difference.length() / maxf(delta, 0.001))
	move_and_slide()
	if velocity.length_squared() > 0.05:
		var visual := get_node_or_null("RobotVisual") as Node3D
		if visual != null:
			visual.rotation.y = atan2(velocity.x, velocity.z)


func command_move(new_path: Array[Vector3]) -> void:
	if logistics_job_id != "":
		return  # Rezervowany ladunek musi zostac dostarczony lub odzyskany.
	factory_route_active = false
	resource_target = null
	repair_target = null
	preferred_resource_type = ""
	waypoints = new_path
	next_waypoint = 0
	state = WorkState.MOVING if not new_path.is_empty() else WorkState.IDLE


func command_gather(target: Node3D, grid: RefCounted, drop_point: Vector3) -> void:
	if robot_role == "engineer":
		return
	if not is_instance_valid(target) or not target.has_method("harvest") or target.resource_type == "iron_ore":
		return
	factory_route_active = false
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
	factory_route_active = false
	preferred_resource_type = ""
	resource_target = null
	repair_target = target
	navigation_grid = grid
	_go_to_repair()


func command_charge() -> void:
	factory_route_active = false
	preferred_resource_type = ""
	resource_target = null
	repair_target = null
	suspended_state = WorkState.IDLE
	if not _navigate_to_charger():
		state = WorkState.IDLE


func command_factory_route(mine: Node3D, smelter: Node3D, grid: RefCounted, drop_point: Vector3) -> void:
	if logistics_job_id != "":
		return
	if robot_role != "hauler" or not is_instance_valid(mine) or not is_instance_valid(smelter):
		return
	factory_mine = mine
	factory_smelter = smelter
	factory_route_active = true
	factory_stage = "pickup"
	preferred_resource_type = ""
	resource_target = null
	repair_target = null
	navigation_grid = grid
	depot_position = drop_point
	if carried_amount > 0:
		_go_to_depot()
	else:
		_travel_factory_stage("pickup")


func set_factory_belts(ore_active: bool, metal_active: bool) -> void:
	ore_belt_enabled = ore_active
	metal_belt_enabled = metal_active
	if factory_route_active and carried_amount == 0:
		_travel_factory_stage("pickup")


func command_logistics_job(job: Dictionary, source: Node3D, destination: Node3D, manager: RefCounted, grid: RefCounted) -> bool:
	if robot_role != "hauler" or carried_amount != 0 or logistics_job_id != "" or state != WorkState.IDLE:
		return false
	logistics_job_id = str(job["id"])
	logistics_source = source
	logistics_destination = destination
	logistics_manager = manager
	logistics_type = str(job["resource_type"])
	logistics_amount = int(job["amount"])
	logistics_sink = bool(job["sink"])
	navigation_grid = grid
	factory_route_active = false
	preferred_resource_type = ""
	resource_target = null
	return _route_logistics(true)


func _route_logistics(pickup: bool) -> bool:
	var target = logistics_source if pickup else logistics_destination
	if not is_instance_valid(target) or navigation_grid == null:
		state = WorkState.IDLE
		return false
	var radius: float = target.get_access_radius() + 0.55 if target.has_method("get_access_radius") else 3.5
	var route: Array[Vector3] = navigation_grid.find_access_path(global_position, target.global_position, radius)
	if route.is_empty():
		state = WorkState.IDLE
		return false
	waypoints = route
	next_waypoint = 0
	state = WorkState.TO_LOGISTICS_PICKUP if pickup else WorkState.TO_LOGISTICS_DELIVERY
	return true


func _finish_logistics_leg() -> void:
	if logistics_manager == null or logistics_job_id.is_empty():
		state = WorkState.IDLE
		return
	if state == WorkState.TO_LOGISTICS_PICKUP:
		var port = logistics_source.get_output_port(logistics_type)
		var taken: int = port.commit_output(logistics_job_id + ":out") if port != null else 0
		if taken != logistics_amount:
			logistics_manager.finish(logistics_job_id)
			logistics_job_id = ""
			state = WorkState.IDLE
			return
		carried_type = logistics_type
		carried_amount = taken
		logistics_manager.note_pickup(logistics_job_id, taken)
		_route_logistics(false)
		return
	if state == WorkState.TO_LOGISTICS_DELIVERY:
		if logistics_sink:
			resource_delivered.emit(carried_type, carried_amount)
			carried_amount = 0
		else:
			var port = logistics_destination.get_input_port(logistics_type)
			var delivered: int = port.commit_input(logistics_job_id + ":in") if port != null else 0
			if delivered != carried_amount:
				state = WorkState.IDLE  # Zachowaj ladunek i sprobuj ponownie.
				return
			carried_amount = 0
		carried_type = ""
		logistics_manager.finish(logistics_job_id)
		logistics_job_id = ""
		state = WorkState.IDLE


func _travel_factory_stage(next_stage: String) -> void:
	if not factory_route_active or navigation_grid == null:
		state = WorkState.IDLE
		return
	if not is_instance_valid(factory_mine) or not is_instance_valid(factory_smelter):
		factory_route_active = false
		state = WorkState.IDLE
		return

	# Dokoncz aktualny transport przy zmianie robot -> tasmociag.
	if carried_type == "iron_ore" and carried_amount > 0:
		next_stage = "input"
	elif carried_type == "metal" and carried_amount > 0:
		next_stage = "depot"
	elif next_stage == "pickup" and ore_belt_enabled:
		next_stage = "output"

	if next_stage == "output" and metal_belt_enabled and carried_amount == 0:
		factory_route_active = false
		state = WorkState.IDLE
		return

	factory_stage = next_stage
	var destination: Vector3 = depot_position
	var radius: float = 3.5
	var next_state: WorkState = WorkState.TO_FACTORY_DEPOT
	if next_stage == "pickup":
		destination = factory_mine.global_position
		radius = factory_mine.get_access_radius() + 0.5
		next_state = WorkState.TO_FACTORY_PICKUP
	elif next_stage == "input" or next_stage == "output":
		destination = factory_smelter.global_position
		radius = factory_smelter.get_access_radius() + 0.5
		next_state = WorkState.TO_FACTORY_INPUT
	var route: Array[Vector3] = navigation_grid.find_access_path(global_position, destination, radius)
	if route.is_empty():
		state = WorkState.IDLE
		return
	waypoints = route
	next_waypoint = 0
	state = next_state


func _process_factory_wait(delta: float) -> void:
	if not factory_route_active:
		state = WorkState.IDLE
		return
	if not is_instance_valid(factory_mine) or not is_instance_valid(factory_smelter):
		factory_route_active = false
		state = WorkState.IDLE
		return
	factory_wait_elapsed += delta
	if factory_wait_elapsed < 0.4:
		return
	factory_wait_elapsed = 0.0

	if state == WorkState.WAIT_FACTORY_PICKUP:
		var ore: int = factory_mine.withdraw_resource("iron_ore", 25 - carried_amount)
		if ore > 0:
			carried_type = "iron_ore"
			carried_amount += ore
		if carried_amount >= 12 or (carried_amount > 0 and not factory_mine.has_ore()):
			_travel_factory_stage("input")
		elif ore_belt_enabled and carried_amount == 0:
			_travel_factory_stage("output")

	elif state == WorkState.WAIT_FACTORY_OUTPUT:
		if carried_type == "iron_ore" and carried_amount > 0:
			var accepted: int = factory_smelter.deposit_resource("iron_ore", carried_amount)
			carried_amount -= accepted
			if carried_amount == 0:
				carried_type = ""
			else:
				# Bufor odbiorczy pelny: nie zgub rudy.
				return

		if metal_belt_enabled:
			# Transport powrotny przejela tasma. Robot moze zajac sie innym zadaniem.
			_travel_factory_stage("pickup")
			return

		var metal: int = factory_smelter.withdraw_resource("metal", 25)
		if metal > 0:
			carried_type = "metal"
			carried_amount = metal
			_travel_factory_stage("depot")
		elif not ore_belt_enabled and factory_smelter.ore_stock < 2 and factory_mine.stock > 0:
			_travel_factory_stage("pickup")
		elif not ore_belt_enabled and factory_smelter.ore_stock == 0 and factory_mine.stock == 0 and not factory_mine.has_ore():
			factory_route_active = false
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
	if logistics_job_id != "":
		_route_logistics(carried_amount == 0)
		return
	if factory_route_active:
		_travel_factory_stage(factory_stage)
		return
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
	var radius: float = repair_target.get_access_radius() + 0.55
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
	if state == WorkState.TO_LOGISTICS_PICKUP or state == WorkState.TO_LOGISTICS_DELIVERY:
		_finish_logistics_leg()
		return
	if state == WorkState.TO_FACTORY_PICKUP:
		factory_wait_elapsed = 0.0
		state = WorkState.WAIT_FACTORY_PICKUP
		return
	if state == WorkState.TO_FACTORY_INPUT:
		factory_wait_elapsed = 0.0
		state = WorkState.WAIT_FACTORY_OUTPUT
		return
	if state == WorkState.TO_FACTORY_DEPOT:
		if carried_amount > 0 and carried_type == "metal":
			resource_delivered.emit("metal", carried_amount)
			carried_amount = 0
			carried_type = ""
		_travel_factory_stage("pickup")
		return
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
		if factory_route_active:
			_travel_factory_stage("pickup")
		elif preferred_resource_type != "":
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
		WorkState.TO_FACTORY_PICKUP:
			return "Do kopalni"
		WorkState.WAIT_FACTORY_PICKUP:
			return "Zaladunek rudy"
		WorkState.TO_FACTORY_INPUT:
			return "Dostawa do huty"
		WorkState.WAIT_FACTORY_OUTPUT:
			return "Odbior metalu"
		WorkState.TO_FACTORY_DEPOT:
			return "Metal do magazynu"
	return "Oczekiwanie"


func to_dict() -> Dictionary:
	var route: Array = []
	for point in waypoints:
		route.append([point.x, point.y, point.z])
	return {"save_id": str(get_meta("save_id", "")),
		"role": robot_role, "position": [global_position.x, global_position.y, global_position.z],
		"rotation_y": rotation.y, "energy": energy, "state": int(state),
		"cargo_type": carried_type, "cargo_amount": carried_amount,
		"waypoints": route, "next_waypoint": next_waypoint,
		"preferred_resource_type": preferred_resource_type,
		"resource_id": str(resource_target.get_meta("save_id", "")) if is_instance_valid(resource_target) else "",
		"repair_id": str(repair_target.get_meta("save_id", "")) if is_instance_valid(repair_target) else "",
		"factory_route": factory_route_active, "factory_stage": factory_stage,
		"ore_belt_enabled": ore_belt_enabled, "metal_belt_enabled": metal_belt_enabled,
		"suspended_state": int(suspended_state),
		"suspended_destination": [suspended_destination.x, suspended_destination.y, suspended_destination.z],
		"depot_position": [depot_position.x, depot_position.y, depot_position.z],
		"harvest_elapsed": harvest_elapsed, "factory_wait_elapsed": factory_wait_elapsed,
		"logistics_job_id": logistics_job_id}


func from_dict(data: Dictionary) -> void:
	set_meta("save_id", str(data.get("save_id", "")))
	energy = clampf(float(data.get("energy", BATTERY_MAX)), 0.0, BATTERY_MAX)
	carried_type = str(data.get("cargo_type", ""))
	carried_amount = maxi(0, int(data.get("cargo_amount", 0)))
	logistics_job_id = str(data.get("logistics_job_id", ""))
	state = clampi(int(data.get("state", int(WorkState.IDLE))), 0, int(WorkState.TO_LOGISTICS_DELIVERY)) as WorkState
	suspended_state = clampi(int(data.get("suspended_state", 0)), 0, int(WorkState.TO_FACTORY_DEPOT)) as WorkState
	preferred_resource_type = str(data.get("preferred_resource_type", ""))
	factory_route_active = bool(data.get("factory_route", false))
	factory_stage = str(data.get("factory_stage", "pickup"))
	ore_belt_enabled = bool(data.get("ore_belt_enabled", false))
	metal_belt_enabled = bool(data.get("metal_belt_enabled", false))
	harvest_elapsed = float(data.get("harvest_elapsed", 0.0))
	factory_wait_elapsed = float(data.get("factory_wait_elapsed", 0.0))
	var suspended = data.get("suspended_destination", [0, 0, 0])
	suspended_destination = Vector3(float(suspended[0]), float(suspended[1]), float(suspended[2]))
	var depot = data.get("depot_position", [0, 0, 0])
	depot_position = Vector3(float(depot[0]), float(depot[1]), float(depot[2]))
	waypoints.clear()
	for point in data.get("waypoints", []):
		if point is Array and point.size() == 3:
			waypoints.append(Vector3(float(point[0]), float(point[1]), float(point[2])))
	next_waypoint = clampi(int(data.get("next_waypoint", 0)), 0, waypoints.size())


func restore_links(data: Dictionary, lookup: Dictionary, nav: RefCounted, charger: Node3D, drop_point: Vector3) -> void:
	navigation_grid = nav
	charging_station = charger
	depot_position = drop_point
	resource_target = lookup.get(str(data.get("resource_id", "")))
	repair_target = lookup.get(str(data.get("repair_id", "")))
	factory_mine = lookup.get("factory:mine")
	factory_smelter = lookup.get("factory:smelter")
	if logistics_job_id != "":
		# Menedzer zostanie dolaczony po odtworzeniu wszystkich obiektow.
		logistics_source = null
		logistics_destination = null
	if factory_route_active and (factory_mine == null or factory_smelter == null):
		factory_route_active = false
		state = WorkState.IDLE
	if (state == WorkState.TO_RESOURCE or state == WorkState.GATHERING) and resource_target == null:
		state = WorkState.IDLE
	if (state == WorkState.TO_REPAIR or state == WorkState.REPAIRING) and repair_target == null:
		state = WorkState.IDLE
	if state != WorkState.IDLE and state != WorkState.CHARGING and state != WorkState.GATHERING and state != WorkState.REPAIRING and state != WorkState.WAIT_FACTORY_PICKUP and state != WorkState.WAIT_FACTORY_OUTPUT and waypoints.is_empty():
		state = WorkState.IDLE
