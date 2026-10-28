extends RefCounted
## WOW 0.14: kolejka zlecen transportowych, kazda jednostka ladunku ma
## jedna rezerwacje u nadawcy i u odbiorcy. Node referencje tylko runtime.
## Persisted data contains stable IDs, no serialized scene nodes.

const MAX_JOBS: int = 16
const MAX_ROUTE_FAILURES: int = 3
const LANE_COOLDOWN_TICKS: int = 16
var next_number: int = 1
var jobs: Array[Dictionary] = []
var sources: Dictionary = {}
var destinations: Dictionary = {}
var priority_overrides: Dictionary = {}
var lane_cooldowns: Dictionary = {}


func _node_id(node: Node) -> String:
	return str(node.get_meta("save_id", "")) if is_instance_valid(node) else ""


func _source_port(node, resource_type: String):
	return node.get_output_port(resource_type) if is_instance_valid(node) and node.has_method("get_output_port") else null


func _destination_port(node, resource_type: String):
	return node.get_input_port(resource_type) if is_instance_valid(node) and node.has_method("get_input_port") else null


func _lane_key(source_id: String, destination_id: String, resource_type: String) -> String:
	return source_id + "|" + destination_id + "|" + resource_type


func _tick_cooldowns() -> void:
	for key in lane_cooldowns.keys():
		var ticks: int = int(lane_cooldowns[key]) - 1
		if ticks <= 0:
			lane_cooldowns.erase(key)
		else:
			lane_cooldowns[key] = ticks


func has_lane(from_node, to_node, resource_type: String) -> bool:
	for job in jobs:
		if job["source_id"] == _node_id(from_node) and job["destination_id"] == _node_id(to_node) and job["resource_type"] == resource_type:
			return true
	return false


func submit(from_node, to_node, resource_type: String, amount: int, priority: int = 50, sink: bool = false) -> String:
	if jobs.size() >= MAX_JOBS or amount <= 0 or not is_instance_valid(from_node) or not is_instance_valid(to_node):
		return ""
	var source_id: String = _node_id(from_node)
	var dest_id: String = _node_id(to_node)
	if source_id.is_empty() or dest_id.is_empty() or has_lane(from_node, to_node, resource_type):
		return ""
	var lane: String = _lane_key(source_id, dest_id, resource_type)
	if int(lane_cooldowns.get(lane, 0)) > 0:
		return ""
	var source_port = _source_port(from_node, resource_type)
	var destination_port = _destination_port(to_node, resource_type)
	if source_port == null or (destination_port == null and not sink):
		return ""
	var count: int = mini(amount, source_port.available_output(resource_type))
	if from_node.has_method("available_export"):
		count = mini(count, from_node.available_export(resource_type))
	if not sink:
		count = mini(count, destination_port.available_input(resource_type))
		if to_node.has_method("available_import"):
			count = mini(count, to_node.available_import(resource_type))
	if count <= 0:
		return ""
	var id: String = "logistics:%d" % next_number
	if not source_port.reserve_output(id + ":out", resource_type, count):
		return ""
	if not sink and not destination_port.reserve_input(id + ":in", resource_type, count):
		source_port.cancel_output(id + ":out")
		return ""
	next_number += 1
	jobs.append({"id": id, "source_id": source_id, "destination_id": dest_id,
		"resource_type": resource_type, "amount": count,
		"priority": int(priority_overrides.get(lane, priority)),
		"status": "queued", "worker_id": "", "sink": sink, "route_failures": 0})
	sources[id] = from_node
	destinations[id] = to_node
	return id


func get_job(job_id: String) -> Dictionary:
	for job in jobs:
		if job["id"] == job_id:
			return job
	return {}


func dispatch(workers: Array, navigation: RefCounted) -> void:
	_tick_cooldowns()
	var sorted: Array[Dictionary] = jobs.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["priority"]) > int(b["priority"]))
	for job in sorted:
		if job["status"] != "queued":
			continue
		var source = sources.get(job["id"])
		var destination = destinations.get(job["id"])
		if not is_instance_valid(source) or not is_instance_valid(destination):
			continue
		for worker in workers:
			if worker.robot_role != "hauler" or worker.carried_amount != 0:
				continue
			if worker.logistics_job_id != "" or worker.factory_route_active or worker.state != worker.WorkState.IDLE:
				continue
			if worker.command_logistics_job(job, source, destination, self, navigation):
				job["worker_id"] = _node_id(worker)
				job["status"] = "assigned"
				job["route_failures"] = 0
				break
			job["route_failures"] = int(job.get("route_failures", 0)) + 1
			if int(job["route_failures"]) >= MAX_ROUTE_FAILURES:
				var lane: String = _lane_key(job["source_id"], job["destination_id"], job["resource_type"])
				lane_cooldowns[lane] = LANE_COOLDOWN_TICKS
				finish(job["id"])
				break


func note_pickup(job_id: String, amount: int) -> void:
	var job: Dictionary = get_job(job_id)
	if not job.is_empty() and job["status"] == "assigned" and amount == int(job["amount"]):
		job["status"] = "picked"


func set_priority(job_id: String, priority: int) -> bool:
	var job: Dictionary = get_job(job_id)
	if job.is_empty():
		return false
	job["priority"] = clampi(priority, 0, 200)
	priority_overrides[_lane_key(job["source_id"], job["destination_id"], job["resource_type"])] = int(job["priority"])
	return true


func cancel(job_id: String, workers: Array) -> bool:
	var job: Dictionary = get_job(job_id)
	if job.is_empty() or job["status"] == "picked":
		# Po pobraniu transportowiec posiada ladunek, nie mozemy go skasowac.
		return false
	if job["status"] == "assigned":
		for worker in workers:
			if worker.logistics_job_id == job_id:
				if worker.carried_amount > 0:
					return false
				worker.logistics_job_id = ""
				worker.logistics_source = null
				worker.logistics_destination = null
				worker.logistics_manager = null
				worker.waypoints.clear()
				worker.state = worker.WorkState.IDLE
				break
	finish(job_id)
	return true


func finish(job_id: String) -> void:
	var job: Dictionary = get_job(job_id)
	if job.is_empty():
		return
	var source = sources.get(job_id)
	var destination = destinations.get(job_id)
	if is_instance_valid(source):
		var source_port = _source_port(source, job["resource_type"])
		if source_port != null:
			source_port.cancel_output(job_id + ":out")
	if is_instance_valid(destination):
		var destination_port = _destination_port(destination, job["resource_type"])
		if destination_port != null:
			destination_port.cancel_input(job_id + ":in")
	jobs.erase(job)
	sources.erase(job_id)
	destinations.erase(job_id)


func to_dict() -> Dictionary:
	return {"save_id": "logistics:manager", "type_id": "service:logistics",
		"object_version": 1, "next_number": next_number, "jobs": jobs.duplicate(true),
		"priority_overrides": priority_overrides.duplicate(true),
		"lane_cooldowns": lane_cooldowns.duplicate(true)}


func from_dict(data: Dictionary, lookup: Dictionary) -> void:
	jobs.clear()
	sources.clear()
	destinations.clear()
	next_number = maxi(1, int(data.get("next_number", 1)))
	priority_overrides = data.get("priority_overrides", {}).duplicate(true)
	lane_cooldowns = data.get("lane_cooldowns", {}).duplicate(true)
	for raw in data.get("jobs", []):
		if not (raw is Dictionary):
			continue
		var source = lookup.get(str(raw.get("source_id", "")))
		var destination = lookup.get(str(raw.get("destination_id", "")))
		if not is_instance_valid(source) or not is_instance_valid(destination):
			continue
		var entry: Dictionary = raw.duplicate(true)
		var id: String = str(entry.get("id", ""))
		if id.is_empty():
			continue
		jobs.append(entry)
		sources[id] = source
		destinations[id] = destination
