extends Node3D
## WOW 0.12: projekty budynkow bez kosztow i bez kolizji.
## Plan mozna zmieniac, wyczyscic lub zatwierdzic calosciowo.
const GHOST = preload("res://scripts/building_ghost.gd")
const MAX_BLUEPRINTS: int = 12

var entries: Array[Dictionary] = []
var ghosts: Array[Node3D] = []


func _ready() -> void:
	name = "ConstructionBlueprints"


func add_blueprint(kind: String, at: Vector3, quarters: int) -> bool:
	if entries.size() >= MAX_BLUEPRINTS:
		return false
	var ghost = GHOST.new()
	ghost.name = "BlueprintGhost%d" % (entries.size() + 1)
	ghost.position = at
	add_child(ghost)
	ghost.show_building(kind, quarters, true)
	ghost.hologram_material.albedo_color = Color(0.32, 0.79, 1.0, 0.50)
	ghosts.append(ghost)
	entries.append({"kind": kind, "site": at, "quarters": quarters})
	return true


func count_kind(kind: String) -> int:
	var total := 0
	for entry in entries:
		if entry["kind"] == kind:
			total += 1
	return total


func pop_last() -> bool:
	if entries.is_empty():
		return false
	entries.pop_back()
	var ghost: Node3D = ghosts.pop_back()
	remove_child(ghost)
	ghost.queue_free()
	return true


func clear_plan() -> void:
	while pop_last():
		pass


func total_cost(cost_lookup: Callable) -> Dictionary:
	var total: Dictionary = {}
	for entry in entries:
		var cost: Dictionary = cost_lookup.call(entry["kind"])
		for resource_type in cost:
			total[resource_type] = int(total.get(resource_type, 0)) + int(cost[resource_type])
	return total


func describe_cost(cost_lookup: Callable) -> String:
	var total: Dictionary = total_cost(cost_lookup)
	var pieces: Array[String] = []
	for resource_type in ["wood", "stone", "metal", "gold"]:
		if int(total.get(resource_type, 0)) > 0:
			pieces.append("%s %d" % [resource_type, int(total[resource_type])])
	return ", ".join(pieces)


func to_dict() -> Dictionary:
	var serialized: Array = []
	for entry in entries:
		var p: Vector3 = entry["site"]
		serialized.append({"kind": str(entry["kind"]), "site": [p.x, p.y, p.z],
			"quarters": int(entry["quarters"])})
	return {"save_id": "blueprints", "entries": serialized}


func from_dict(data: Dictionary) -> void:
	clear_plan()
	for entry in data.get("entries", []):
		var xyz = entry.get("site", [])
		if xyz is Array and xyz.size() == 3:
			add_blueprint(str(entry.get("kind", "")),
				Vector3(float(xyz[0]), float(xyz[1]), float(xyz[2])),
				int(entry.get("quarters", 0)))
