extends RefCounted
## WOW 0.13: wersjonowany zapis stanu bez serializacji Node/NodePath.
## Odtwarzanie: obiekty -> identyfikatory -> relacje -> wznowienie symulacji.

const SCHEMA_VERSION: int = 1
const SAVE_PATH: String = "user://wow-save-1.json"
const MAX_SAVE_BYTES: int = 16 * 1024 * 1024
const RESOURCE_NAMES: Array[String] = ["GoldMine", "StoneQuarry", "IronOreDeposit"]


func _id(node: Node, fallback: String) -> String:
	if not is_instance_valid(node):
		return ""
	var result: String = str(node.get_meta("save_id", ""))
	if result.is_empty():
		result = fallback
		node.set_meta("save_id", result)
	return result


func vec(raw: Variant) -> Vector3:
	if raw is Array and raw.size() == 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3.ZERO


func to_dict(game: Node3D) -> Dictionary:
	var resources: Array = []
	for resource in game.get_tree().get_nodes_in_group("resource_nodes"):
		if not is_instance_valid(resource) or not game.is_ancestor_of(resource):
			continue
		var p: Vector3 = resource.global_position
		var stable_id: String = "deposit:" + resource.name if resource.name in RESOURCE_NAMES else "resource:%s:%d:%d" % [resource.resource_type, roundi(p.x * 10.0), roundi(p.z * 10.0)]
		_id(resource, stable_id)
		var record: Dictionary = resource.to_dict()
		# Godot automatycznie zmienia nazwy rodzenstwa Tree na Tree2 / @...;
		# logiczny typ zrodla nie moze zalezec od nazwy Node.
		record["node_name"] = "Tree" if resource.resource_type == "wood" else str(resource.name)
		record["type_id"] = "resource:" + resource.resource_type
		record["object_version"] = 1
		resources.append(record)
	# Zloze pod kopalnia nie nalezy juz do grupy resource_nodes.
	var iron = game.get_node_or_null("IronOreDeposit")
	if iron != null and not iron.is_in_group("resource_nodes"):
		_id(iron, "deposit:IronOreDeposit")
		var hidden: Dictionary = iron.to_dict()
		hidden["node_name"] = "IronOreDeposit"
		hidden["type_id"] = "resource:iron_ore"
		hidden["object_version"] = 1
		resources.append(hidden)
	var structures: Array = []
	var groups: Dictionary = {
		"mine": [game.factory_mine], "smelter": [game.factory_smelter],
		"center": [game.town_hall], "forester": game.foresters,
		"solar": game.solar_arrays, "battery": game.battery_banks,
		"depot": game.logistics_depots
	}
	for kind in ["mine", "smelter", "center", "forester", "solar", "battery", "depot"]:
		var nodes: Array = groups[kind]
		for i in range(nodes.size()):
			var node = nodes[i]
			if not is_instance_valid(node):
				continue
			_id(node, "factory:%s" % kind if kind == "mine" or kind == "smelter" else "building:%s:%d" % [kind, i])
			var state: Dictionary = node.to_dict()
			state["kind"] = kind
			state["type_id"] = "building:" + kind
			state["object_version"] = 1
			structures.append(state)
	var robots: Array = []
	for i in range(game.workers.size()):
		var robot = game.workers[i]
		_id(robot, "worker:%d" % i)
		var robot_record: Dictionary = robot.to_dict()
		robot_record["type_id"] = "worker:" + robot.robot_role
		robot_record["object_version"] = 1
		robots.append(robot_record)
	var belts: Array = []
	for conveyor in [game.ore_conveyor, game.metal_conveyor]:
		if is_instance_valid(conveyor):
			_id(conveyor, "belt:" + conveyor.mode)
			belts.append(conveyor.to_dict())

	return {
		"schema_version": SCHEMA_VERSION,
		"planet": game.planet_env.current_planet,
		"resources_total": game.resource_totals.duplicate(true),
		"resources": resources,
		"structures": structures,
		"robots": robots,
		"belts": belts,
		"roads": game.roads.to_dict(),
		"blueprints": game.blueprints.to_dict(),
		"logistics": game.logistics_manager.to_dict(),
		"production_monitor": game.production_monitor.to_dict(),
		"lander": game.landing_rocket.to_dict(),
		"charger": game.charging_pad.to_dict(),
		"training": {"active": game.training_in_progress,
			"role": game.training_role,
			"time_left": game.training_timer.time_left},
		"building_options": {"planning": game.planning_enabled,
			"sticky": game.sticky_build_enabled, "snap": game.placement_snap_size}
	}


func _is_json_safe(value: Variant, depth: int = 0) -> bool:
	# JSON.stringify() zamienialoby np. StringName/Vector3 na tekst.
	# Nie dopuszczamy takiej utraty informacji w zapisie v1.
	if depth > 32:
		return false
	if value == null or value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_json_safe(item, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not (key is String) or not _is_json_safe(value[key], depth + 1):
				return false
		return true
	return false


func validate(data: Variant) -> bool:
	if not (data is Dictionary) or not _is_json_safe(data):
		return false
	if int(data.get("schema_version", -1)) != SCHEMA_VERSION:
		return false
	for key in ["planet", "resources_total", "resources", "structures", "robots", "belts", "roads", "blueprints"]:
		if not data.has(key):
			return false
	if not (data["resources_total"] is Dictionary):
		return false
	for key in ["wood", "gold", "stone", "metal"]:
		if not data["resources_total"].has(key) or int(data["resources_total"][key]) < 0:
			return false
	for key in ["resources", "structures", "robots", "belts"]:
		if not (data[key] is Array):
			return false
	if data["resources"].size() > 1000 or data["structures"].size() > 100 or data["robots"].size() > 100 or data["belts"].size() > 2:
		return false
	if not data["planet"] in ["Mars", "Ziemia", "Kepler"]:
		return false
	if not (data["roads"] is Dictionary) or not (data["roads"].get("cells", null) is Array):
		return false
	if not (data["blueprints"] is Dictionary) or not (data["blueprints"].get("entries", null) is Array):
		return false
	if data["blueprints"]["entries"].size() > 12:
		return false
	var seen_ids: Dictionary = {}
	for key in ["resources", "structures", "robots", "belts"]:
		for record in data[key]:
			if not (record is Dictionary):
				return false
			var record_id: String = str(record.get("save_id", ""))
			if record_id.is_empty() or seen_ids.has(record_id):
				return false
			seen_ids[record_id] = true
	for key in ["resources", "structures", "robots", "belts"]:
		for record in data[key]:
			if not str(record.get("type_id", "")).contains(":") or int(record.get("object_version", -1)) != 1:
				return false
	for row in data["resources"]:
		if not (row.get("position", null) is Array) or row["position"].size() != 3:
			return false
		if int(row.get("remaining", -1)) < 0:
			return false
		if not str(row.get("node_name", "")) in ["Tree", "GoldMine", "StoneQuarry", "IronOreDeposit"]:
			return false
	for row in data["structures"]:
		if not str(row.get("kind", "")) in ["mine", "smelter", "center", "forester", "solar", "battery", "depot"]:
			return false
		if not (row.get("position", null) is Array) or row["position"].size() != 3:
			return false
	for row in data["robots"]:
		if not str(row.get("role", "")) in ["miner", "hauler", "engineer"]:
			return false
		if not (row.get("position", null) is Array) or row["position"].size() != 3:
			return false
		if int(row.get("cargo_amount", -1)) < 0:
			return false
	if data.has("logistics"):
		if not (data["logistics"] is Dictionary) or not (data["logistics"].get("jobs", null) is Array):
			return false
		if data["logistics"]["jobs"].size() > 16:
			return false
	for belt in data["belts"]:
		if not (belt is Dictionary) or not belt.get("mode", "") in ["ore", "metal"]:
			return false
		if not (belt.get("path_points", null) is Array) or belt["path_points"].size() < 2:
			return false
		for item in belt.get("packets", []):
			if not (item is Dictionary) or int(item.get("amount", 0)) <= 0:
				return false
	return true


func save_file(game: Node3D, path: String = SAVE_PATH) -> bool:
	var data: Dictionary = to_dict(game)
	# Nie nadpisuj poprawnego slotu, jesli serializacja wygenerowala
	# niekompletny snapshot (np. kolizje save_id lub zla strukture).
	if not validate(data):
		push_warning("WOW save: snapshot rejected by schema v1; existing save untouched")
		return false
	var json_text: String = JSON.stringify(data, "\t")
	if json_text.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		push_warning("WOW save: snapshot exceeds schema v1 safety limit")
		return false
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_warning("WOW save: cannot open temporary file: " + temporary)
		return false
	file.store_string(json_text)
	file.flush()
	file.close()
	# Jedna operacja rename; w razie błędu poprzedni zapis pozostaje bez zmian.
	var status: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary),
		ProjectSettings.globalize_path(path))
	if status != OK:
		push_warning("WOW save: cannot install new file: %s" % error_string(status))
		return false
	return true


func read_file(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	# Limit rozmiaru zabezpiecza przed przypadkowym odczytem
	# uszkodzonego lub niekontrolowanie rozrosnietego pliku.
	if file.get_length() > MAX_SAVE_BYTES:
		push_warning("WOW save: file exceeds schema v1 safety limit")
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not validate(parser.data):
		push_warning("WOW save: damaged or incompatible file")
		return {}
	return parser.data


func from_dict(game: Node3D, data: Dictionary) -> bool:
	if not validate(data):
		return false
	# Caller should create a fresh game scene. This method never operates on
	# a half-constructed Node tree and never creates/saves Node references.
	var tree: SceneTree = game.get_tree()
	var previously_paused: bool = tree.paused
	tree.paused = true

	game._cancel_build_modes()
	game._clear_selection()
	game.resource_totals.clear()
	for resource_key in ["wood", "gold", "stone", "metal"]:
		game.resource_totals[resource_key] = int(data["resources_total"][resource_key])

	for old_worker in game.workers:
		game.remove_child(old_worker)
		old_worker.queue_free()
	game.workers.clear()

	var forest: Node3D = game.get_node("Forest")
	for tree_node in forest.get_children():
		if not tree_node.is_sapling and tree_node.remaining > 0:
			game.navigation.unblock_circle(
				Vector2(tree_node.position.x, tree_node.position.z), tree_node.clearance_radius)
		forest.remove_child(tree_node)
		tree_node.queue_free()

	var resource_lookup: Dictionary = {}
	for row in data["resources"]:
		if not (row is Dictionary):
			continue
		var name: String = str(row.get("node_name", ""))
		if name != "Tree":
			continue
		var amount: int = int(row.get("remaining", 0))
		if amount <= 0 and not bool(row.get("is_sapling", false)):
			continue
		var p: Vector3 = vec(row.get("position", []))
		var new_tree = game._add_tree(forest, Vector2(p.x, p.z), bool(row.get("is_sapling", false)))
		new_tree.from_dict(row)
		resource_lookup[str(row.get("save_id", ""))] = new_tree

	for deposit_name in RESOURCE_NAMES:
		var existing = game.get_node_or_null(deposit_name)
		if existing == null:
			continue
		var found: Dictionary = {}
		for row in data["resources"]:
			if str(row.get("node_name", "")) == deposit_name:
				found = row
				break
		if found.is_empty():
			game.navigation.unblock_circle(Vector2(existing.position.x, existing.position.z), existing.clearance_radius)
			game.remove_child(existing)
			existing.queue_free()
		else:
			existing.from_dict(found)
			existing.set_meta("save_id", "deposit:" + deposit_name)
			resource_lookup["deposit:" + deposit_name] = existing
			if existing.remaining <= 0:
				game.navigation.unblock_circle(Vector2(existing.position.x, existing.position.z), existing.clearance_radius)

	game.landing_rocket.from_dict(data.get("lander", {}))
	game.charging_pad.from_dict(data.get("charger", {}))
	resource_lookup["lander"] = game.landing_rocket
	resource_lookup["charger"] = game.charging_pad

	for row in data["structures"]:
		var kind: String = str(row.get("kind", ""))
		if not kind in ["mine", "smelter", "center", "forester", "solar", "battery", "depot"]:
			continue
		var pos: Vector3 = vec(row.get("position", []))
		var quarters: int = posmod(roundi(float(row.get("rotation_y", 0.0)) / (PI * 0.5)), 4)
		# Budynki stawiamy bez kosztów: materiały już są w stanie zapisu.
		game._spawn_planned_structure({"kind": kind, "site": pos, "quarters": quarters})
		var building = null
		match kind:
			"mine": building = game.factory_mine
			"smelter": building = game.factory_smelter
			"center": building = game.town_hall
			"forester": building = game.foresters[game.foresters.size() - 1]
			"solar": building = game.solar_arrays[game.solar_arrays.size() - 1]
			"battery": building = game.battery_banks[game.battery_banks.size() - 1]
			"depot": building = game.logistics_depots[game.logistics_depots.size() - 1]
		if building == null:
			continue
		building.from_dict(row)
		building.rotation.y = float(row.get("rotation_y", 0.0))
		resource_lookup[str(row.get("save_id", ""))] = building
		if kind == "mine":
			resource_lookup["factory:mine"] = building
		elif kind == "smelter":
			resource_lookup["factory:smelter"] = building

	game.roads.from_dict(data["roads"])
	game.blueprints.from_dict(data["blueprints"])

	for belt_data in data["belts"]:
		var mode: String = str(belt_data.get("mode", ""))
		if game.factory_mine == null or game.factory_smelter == null:
			continue
		var link = game.CONVEYOR_SCRIPT.new()
		link.setup_saved_route(belt_data,
			game.factory_mine if mode == "ore" else game.factory_smelter,
			game.factory_smelter if mode == "ore" else game.get_node("Stockpile"))
		game.add_child(link)
		link.from_dict(belt_data)
		if mode == "ore":
			game.ore_conveyor = link
		else:
			game.metal_conveyor = link
			link.cargo_delivered.connect(game._on_conveyor_delivered)

	for record in data["robots"]:
		var p: Vector3 = vec(record.get("position", []))
		var worker = game._spawn_worker(p, str(record.get("role", "miner")))
		worker.visible = true
		worker.rotation.y = float(record.get("rotation_y", 0.0))
		worker.from_dict(record)
		worker.road_network = game.roads

	for i in range(data["robots"].size()):
		game.workers[i].restore_links(data["robots"][i], resource_lookup,
			game.navigation, game.charging_pad, game.DEPOT_POSITION)

	# Wszystkie obiekty juz istnieja: mozna teraz rozwiazac relacje
	# zlecen po stabilnych identyfikatorach, bez bezposredniej serializacji Node.
	resource_lookup["stockpile"] = game.get_node("Stockpile")
	for index in range(game.logistics_depots.size()):
		var hub = game.logistics_depots[index]
		resource_lookup[str(hub.get_meta("save_id", "building:depot:%d" % index))] = hub
	game.logistics_manager.from_dict(data.get("logistics", {}), resource_lookup)
	game.production_monitor.from_dict(data.get("production_monitor", {}))
	for robot in game.workers:
		if robot.logistics_job_id != "":
			var assigned: Dictionary = game.logistics_manager.get_job(robot.logistics_job_id)
			if assigned.is_empty():
				robot.logistics_job_id = ""
				robot.state = robot.WorkState.IDLE
				continue
			robot.logistics_manager = game.logistics_manager
			robot.logistics_source = resource_lookup.get(assigned["source_id"])
			robot.logistics_destination = resource_lookup.get(assigned["destination_id"])
			robot.logistics_type = str(assigned["resource_type"])
			robot.logistics_amount = int(assigned["amount"])
			robot.logistics_sink = bool(assigned["sink"])

	game.training_role = str(data.get("training", {}).get("role", "miner"))
	game.training_in_progress = bool(data.get("training", {}).get("active", false))
	if game.training_in_progress:
		game.training_timer.start(maxf(0.1, float(data["training"].get("time_left", 4.0))))
	var options: Dictionary = data.get("building_options", {})
	game.planning_enabled = bool(options.get("planning", false))
	game.sticky_build_enabled = bool(options.get("sticky", false))
	game.placement_snap_size = int(options.get("snap", 1))

	game.planet_env.select_planet(str(data["planet"]))
	game.planet_env.apply_resource_colors(game.get_tree().get_nodes_in_group("resource_nodes"))
	game.hud.set_planet(str(data["planet"]))
	game._update_factory_power()
	game._update_resource_hud()
	game._update_action_buttons()
	game._update_planning_hud()
	game._update_colony_hud()
	tree.paused = previously_paused
	return true
