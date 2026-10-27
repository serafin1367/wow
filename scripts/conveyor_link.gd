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
	if path_points.size() >= 2:
		_build_track()


func setup(new_mode: String, new_source, new_destination, new_path: Array[Vector3]) -> void:
	mode = new_mode
	source = new_source
	destination = new_destination
	path_points = new_path.duplicate()
	path_distances.clear()
	route_length = 0.0
	if path_points.is_empty():
		return
	path_distances.append(0.0)
	for i in range(1, path_points.size()):
		route_length += path_points[i - 1].distance_to(path_points[i])
		path_distances.append(route_length)


func _process(delta: float) -> void:
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
	if mode == "ore":
		return source.withdraw(requested)
	return source.collect_metal(requested)


func _unload_packet(requested: int) -> int:
	if not is_instance_valid(destination):
		return 0
	if mode == "ore":
		return destination.deposit_ore(requested)
	# Do magazynu trafia tylko metal, nie ruda.
	return requested


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
	for i in range(1, path_points.size()):
		var begin := path_points[i - 1]
		var end := path_points[i]
		var center := (begin + end) * 0.5
		var length: float = begin.distance_to(end)
		if length <= 0.01:
			continue
		var rotation: float = atan2(end.x - begin.x, end.z - begin.z)
		_add_box("Frame", center + Vector3(0, 0.30, 0), Vector3(1.16, 0.25, length + 0.08), frame_material, rotation)
		_add_box("Belt", center + Vector3(0, 0.48, 0), Vector3(0.92, 0.09, length + 0.08), belt_material, rotation)
		for side in [-1.0, 1.0]:
			var lateral: Vector3 = Vector3(cos(rotation), 0.0, -sin(rotation)) * float(side) * 0.52
			_add_box("OrangeRail", center + lateral + Vector3(0, 0.63, 0), Vector3(0.075, 0.22, length + 0.08), accent_material, rotation)


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
