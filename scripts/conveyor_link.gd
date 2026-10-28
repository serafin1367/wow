extends Node3D
## WOW 0.7: fizycznie widoczne paczki surowcow na prawdziwej trasie
## tasmociagu A*. Bilansowane bufory, ograniczona przepustowosc i zasilanie.

signal cargo_delivered(resource_type: String, amount: int)

const POWER_KW: float = 0.15
const PACKET_SIZE: int = 2
const MAX_PACKETS: int = 18
const SPAWN_INTERVAL: float = 0.8
const TRAVEL_SPEED: float = 7.0

var mode: String = "ore"
var source = null
var destination = null
var path_points: Array[Vector3] = []
var path_distances: Array[float] = []
var route_length: float = 0.0
var packets: Array[Dictionary] = []
var powered: bool = false
var preview_mode: bool = false
var roller_material: StandardMaterial3D
var glow_material: StandardMaterial3D
var elapsed: float = 0.0
var total_transferred: int = 0

var frame_material: StandardMaterial3D
var belt_material: StandardMaterial3D
var accent_material: StandardMaterial3D
var ore_material: StandardMaterial3D
var metal_material: StandardMaterial3D


func _ready() -> void:
	name = "OreConveyor" if mode == "ore" else "MetalConveyor"
	frame_material = _mat(Color(0.11, 0.16, 0.21))
	belt_material = _mat(Color(0.30, 0.37, 0.41))
	accent_material = _mat(Color(0.97, 0.49, 0.13))
	ore_material = _mat(Color(0.41, 0.32, 0.24))
	metal_material = _mat(Color(0.25, 0.86, 0.88))
	roller_material = _mat(Color(0.64, 0.68, 0.70))
	glow_material = _mat(Color(0.28, 0.88, 0.93))
	if preview_mode:
		accent_material = glow_material
	if path_points.size() >= 2:
		_build_track()


func setup(new_mode: String, new_source, new_destination, new_path: Array[Vector3]) -> void:
	mode = new_mode
	source = new_source
	destination = new_destination
	path_points = []
	if new_path.size() >= 2:
		# Wejscie i wyjscie sa rzeczywistymi punktami na obrysie budynku.
		# A* zapewnia odcinek wolny od przeszkod miedzy tymi portami.
		var source_center: Vector3 = new_source.global_position if is_instance_valid(new_source) else new_path[0]
		var dest_center: Vector3 = new_destination.global_position if is_instance_valid(new_destination) else new_path[new_path.size() - 1]
		var source_radius: float = new_source.get_access_radius() if is_instance_valid(new_source) and new_source.has_method("get_access_radius") else 3.0
		var dest_radius: float = new_destination.get_access_radius() if is_instance_valid(new_destination) and new_destination.has_method("get_access_radius") else 3.1
		var start_port: Vector3 = source_center.move_toward(new_path[0], source_radius * 0.90)
		var end_port: Vector3 = dest_center.move_toward(new_path[new_path.size() - 1], dest_radius * 0.90)
		start_port.y = 0.0
		end_port.y = 0.0
		path_points.append(start_port)
		for p in new_path:
			if p.distance_to(path_points[path_points.size() - 1]) > 0.08:
				path_points.append(p)
		if end_port.distance_to(path_points[path_points.size() - 1]) > 0.08:
			path_points.append(end_port)
	path_distances.clear()
	route_length = 0.0
	if path_points.is_empty():
		return
	path_distances.append(0.0)
	for i in range(1, path_points.size()):
		route_length += path_points[i - 1].distance_to(path_points[i])
		path_distances.append(route_length)

func _process(delta: float) -> void:
	if preview_mode:
		return
	if not powered or path_points.size() < 2:
		return
	# Paczki w drodze nie znikaja po wylaczeniu zasilania.
	for i in range(packets.size() - 1, -1, -1):
		var packet: Dictionary = packets[i]
		var progress: float = minf(route_length, float(packet["distance"]) + TRAVEL_SPEED * delta)
		packet["distance"] = progress
		var model: Node3D = packet["visual"]
		model.position = _at_distance(progress) + Vector3(0, 0.74, 0)
		if progress >= route_length - 0.001:
			var accepted: int = _unload_packet(int(packet["amount"]))
			packet["amount"] = int(packet["amount"]) - accepted
			if accepted > 0:
				total_transferred += accepted
				cargo_delivered.emit("iron_ore" if mode == "ore" else "metal", accepted)
			if int(packet["amount"]) == 0:
				model.queue_free()
				packets.remove_at(i)
				continue
		packets[i] = packet

	elapsed += delta
	if elapsed >= SPAWN_INTERVAL and packets.size() < MAX_PACKETS:
		elapsed = fmod(elapsed, SPAWN_INTERVAL)
		# Zbyt duza ilosc paczek przy wylocie blokuje kolejny zaladunek.
		if not packets.is_empty() and float(packets[packets.size() - 1]["distance"]) < 1.1:
			return
		var amount: int = _load_packet(PACKET_SIZE)
		if amount > 0:
			var mesh := MeshInstance3D.new()
			mesh.name = "OrePacket" if mode == "ore" else "MetalPacket"
			var parcel := BoxMesh.new()
			parcel.size = Vector3(0.62, 0.35, 0.58)
			mesh.mesh = parcel
			mesh.material_override = ore_material if mode == "ore" else metal_material
			add_child(mesh)
			mesh.position = _at_distance(0.0) + Vector3(0, 0.74, 0)
			packets.append({"distance": 0.0, "amount": amount, "visual": mesh})


func _load_packet(requested: int) -> int:
	if not is_instance_valid(source):
		return 0
	var resource_type: String = "iron_ore" if mode == "ore" else "metal"
	if source.has_method("withdraw_resource"):
		return source.withdraw_resource(resource_type, requested)
	return 0


func _unload_packet(requested: int) -> int:
	if not is_instance_valid(destination):
		return 0
	var resource_type: String = "iron_ore" if mode == "ore" else "metal"
	if destination.has_method("deposit_resource"):
		return destination.deposit_resource(resource_type, requested)
	# Koncowy magazyn nadal rozlicza zasoby przez sygnal cargo_delivered.
	return requested if mode == "metal" else 0


func _at_distance(distance: float) -> Vector3:
	if path_points.is_empty():
		return Vector3.ZERO
	var clamped: float = clampf(distance, 0.0, route_length)
	for i in range(1, path_points.size()):
		if clamped <= path_distances[i] or i == path_points.size() - 1:
			var segment: float = path_distances[i] - path_distances[i - 1]
			if segment <= 0.001:
				return path_points[i]
			return path_points[i - 1].lerp(path_points[i], (clamped - path_distances[i - 1]) / segment)
	return path_points[path_points.size() - 1]


func _build_track() -> void:
	# Wszystkie odcinki lacza sie bez przerw. Naroza otrzymuja pokrywe,
	# a rolki i strzalki pokazuja kierunek przeplywu.
	var support_counter: int = 0
	for i in range(1, path_points.size()):
		var begin: Vector3 = path_points[i - 1]
		var end: Vector3 = path_points[i]
		var delta: Vector3 = end - begin
		var length: float = delta.length()
		if length <= 0.01:
			continue
		var center: Vector3 = (begin + end) * 0.5
		var rotation: float = atan2(delta.x, delta.z)
		var section := Node3D.new()
		section.name = "TrackSegment_%d" % i
		section.position = center
		section.rotation.y = rotation
		add_child(section)
		_box_on(section, "LowerChassis", Vector3(0, 0.34, 0), Vector3(1.22, 0.28, length + 0.12), frame_material)
		_box_on(section, "MovingBelt", Vector3(0, 0.53, 0), Vector3(0.91, 0.10, length + 0.12), belt_material)
		for side in [-1.0, 1.0]:
			_box_on(section, "SafetyRail", Vector3(float(side) * 0.56, 0.71, 0), Vector3(0.09, 0.25, length + 0.15), accent_material)
		# Rolki w widocznych odstepach. Os Y walca obracamy w os X.
		var rollers: int = maxi(1, floori(length / 0.8))
		for r in range(rollers):
			var along: float = -length * 0.5 + (float(r) + 0.5) * length / float(rollers)
			_add_roller(section, Vector3(0, 0.595, along))
		# Turkusowy wskaznik ruchu co kilka modulow.
		if i % 3 == 0:
			_box_on(section, "FlowIndicator", Vector3(0, 0.605, 0.0), Vector3(0.43, 0.025, 0.14), glow_material)
			support_counter += 1
		if support_counter % 2 == 0 or i == 1:
			_box_on(section, "SupportLegL", Vector3(-0.45, 0.18, 0.0), Vector3(0.15, 0.36, 0.23), frame_material)
			_box_on(section, "SupportLegR", Vector3(0.45, 0.18, 0.0), Vector3(0.15, 0.36, 0.23), frame_material)

	# Naroza maskuja szczeliny pomiedzy odcinkami A* i wygladaja jak
	# normalny mechanizm obracajacy material o 45 lub 90 stopni.
	for i in range(1, path_points.size() - 1):
		var previous: Vector3 = (path_points[i] - path_points[i - 1]).normalized()
		var following: Vector3 = (path_points[i + 1] - path_points[i]).normalized()
		if previous.dot(following) < 0.997:
			_add_junction(path_points[i])
	# Dedykowane gardziele ladunkowe, przy obu maszynach i magazynie.
	_add_port("OUTPUT", path_points[0], path_points[1] - path_points[0])
	_add_port("INPUT", path_points[path_points.size() - 1], path_points[path_points.size() - 1] - path_points[path_points.size() - 2])


func _add_junction(at: Vector3) -> void:
	var joint := Node3D.new()
	joint.name = "CornerJoint"
	joint.position = at
	add_child(joint)
	_box_on(joint, "CornerBase", Vector3(0, 0.40, 0), Vector3(1.32, 0.28, 1.32), frame_material)
	_box_on(joint, "CornerBelt", Vector3(0, 0.58, 0), Vector3(1.12, 0.07, 1.12), belt_material)
	var rim := MeshInstance3D.new()
	rim.name = "TurntableRim"
	var disk := CylinderMesh.new()
	disk.top_radius = 0.41
	disk.bottom_radius = 0.41
	disk.height = 0.065
	disk.radial_segments = 12
	rim.mesh = disk
	rim.position = Vector3(0, 0.62, 0)
	rim.material_override = accent_material
	joint.add_child(rim)


func _add_port(port_name: String, at: Vector3, vector: Vector3) -> void:
	var port := Node3D.new()
	port.name = "Conveyor" + port_name
	port.position = at
	port.rotation.y = atan2(vector.x, vector.z)
	add_child(port)
	_box_on(port, "LoadingSill", Vector3(0, 0.42, 0), Vector3(1.42, 0.28, 1.25), frame_material)
	_box_on(port, "PortStripe", Vector3(0, 0.60, 0), Vector3(1.28, 0.06, 0.28), accent_material)
	for side in [-1.0, 1.0]:
		_box_on(port, "WarningPost", Vector3(float(side) * 0.68, 1.01, 0), Vector3(0.11, 1.08, 0.15), frame_material)
	_box_on(port, "SensorBar", Vector3(0, 1.59, 0), Vector3(1.5, 0.14, 0.17), glow_material)


func _add_roller(parent: Node3D, at: Vector3) -> void:
	var roller := MeshInstance3D.new()
	roller.name = "DriveRoller"
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.085
	shaft.bottom_radius = 0.085
	shaft.height = 0.84
	shaft.radial_segments = 10
	roller.mesh = shaft
	roller.position = at
	roller.rotation_degrees.z = 90.0
	roller.material_override = roller_material
	parent.add_child(roller)


func _box_on(parent: Node3D, part: String, at: Vector3, dimensions: Vector3, mat: Material) -> void:
	var box := MeshInstance3D.new()
	box.name = part
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	box.mesh = mesh
	box.position = at
	box.material_override = mat
	parent.add_child(box)


func _add_box(part: String, at: Vector3, dimensions: Vector3, mat: Material, facing: float) -> void:
	var model := MeshInstance3D.new()
	model.name = part
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	model.mesh = mesh
	model.position = at
	model.rotation.y = facing
	model.material_override = mat
	add_child(model)


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.35
	mat.roughness = 0.62
	return mat


func describe() -> String:
	var status: String = "TRANSPORT" if powered else "BRAK ENERGII"
	return "%s | Paczki: %d | Dostarczono: %d | Pobor: %.2f kW" % [
		status, packets.size(), total_transferred, POWER_KW
	]


func to_dict() -> Dictionary:
	var route: Array = []
	for point in path_points:
		route.append([point.x, point.y, point.z])
	var cargo: Array = []
	for packet in packets:
		var d: float = float(packet["distance"])
		cargo.append({"distance": d, "amount": int(packet["amount"]),
			"resource_type": "iron_ore" if mode == "ore" else "metal",
			"direction": "forward",
			"delivery_state": "blocked_at_destination" if d >= route_length - 0.001 else "in_transit"})
	return {"save_id": str(get_meta("save_id", "belt:" + mode)),
		"type_id": "conveyor:" + mode, "object_version": 1, "mode": mode,
		"path_points": route, "packets": cargo, "elapsed": elapsed,
		"total_transferred": total_transferred}


func setup_saved_route(data: Dictionary, new_source, new_destination) -> void:
	mode = str(data.get("mode", "ore"))
	source = new_source
	destination = new_destination
	path_points.clear()
	path_distances.clear()
	route_length = 0.0
	for raw in data.get("path_points", []):
		if raw is Array and raw.size() == 3:
			var point := Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
			if not path_points.is_empty():
				route_length += path_points[path_points.size() - 1].distance_to(point)
			path_points.append(point)
			path_distances.append(route_length)


func from_dict(data: Dictionary) -> void:
	set_meta("save_id", str(data.get("save_id", "belt:" + mode)))
	elapsed = clampf(float(data.get("elapsed", 0.0)), 0.0, SPAWN_INTERVAL)
	total_transferred = maxi(0, int(data.get("total_transferred", 0)))
	for old in packets:
		if is_instance_valid(old.get("visual")):
			old["visual"].queue_free()
	packets.clear()
	# Pozycje 3D wyliczamy z trasy, a nie z historycznego transformu mesha.
	for item in data.get("packets", []):
		if not (item is Dictionary) or path_points.size() < 2:
			continue
		var amount: int = int(item.get("amount", 0))
		if amount <= 0:
			continue
		var distance: float = clampf(float(item.get("distance", 0.0)), 0.0, route_length)
		var visual := MeshInstance3D.new()
		visual.name = "OrePacket" if mode == "ore" else "MetalPacket"
		var parcel := BoxMesh.new()
		parcel.size = Vector3(0.62, 0.35, 0.58)
		visual.mesh = parcel
		visual.material_override = ore_material if mode == "ore" else metal_material
		add_child(visual)
		visual.position = _at_distance(distance) + Vector3(0.0, 0.74, 0.0)
		packets.append({"distance": distance, "amount": amount, "visual": visual})
