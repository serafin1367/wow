extends StaticBody3D
## WOW 0.9: magazyn energii, 8 kWh w przyspieszonym czasie kolonii.
const KENNEY = preload("res://scripts/kenney_assets.gd")
const CLEARANCE_RADIUS: float = 2.5
const CAPACITY_KWH: float = 8.0
const MAX_INPUT_KW: float = 3.0
const MAX_OUTPUT_KW: float = 3.0
const GAME_HOURS_PER_SECOND: float = 1.0 / 60.0

var stored_kwh: float = 0.0
var indicator: MeshInstance3D
var elapsed: float = 0.0
var active_flow: float = 0.0


func _ready() -> void:
	name = "BatteryBank"
	collision_layer = 4 | 8
	collision_mask = 0
	var hull := _mat(Color(0.12, 0.18, 0.23))
	var steel := _mat(Color(0.42, 0.53, 0.57))
	var amber := _mat(Color(0.98, 0.49, 0.12))
	var cyan := _mat(Color(0.18, 0.82, 0.87), true)
	_box("BatteryPlinth", Vector3(0, 0.22, 0), Vector3(3.8, 0.44, 3.2), hull)
	for i in range(3):
		_box("Cell%d" % i, Vector3(float(i - 1) * 1.09, 1.40, 0), Vector3(0.9, 1.93, 1.56), steel)
		_box("OrangeCellCap%d" % i, Vector3(float(i - 1) * 1.09, 2.43, 0), Vector3(1.04, 0.24, 1.63), amber)
		_box("BatteryLight%d" % i, Vector3(float(i - 1) * 1.09, 1.68, 0.82), Vector3(0.56, 0.28, 0.11), cyan)
	indicator = MeshInstance3D.new()
	indicator.name = "BatteryChargeBar"
	var bar := BoxMesh.new()
	bar.size = Vector3(2.4, 0.18, 0.12)
	indicator.mesh = bar
	indicator.material_override = cyan
	indicator.position = Vector3(0, 0.74, 0.93)
	add_child(indicator)
	var kenney = KENNEY.model("factory", "box-large", 0.85)
	if kenney != null:
		kenney.name = "KenneyServiceModule"
		kenney.position = Vector3(1.65, 0.34, -0.92)
		add_child(kenney)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.8, 2.9, 3.0)
	collider.shape = shape
	collider.position.y = 1.45
	add_child(collider)


func _process(delta: float) -> void:
	elapsed += delta
	if indicator != null:
		indicator.scale.x = maxf(0.035, stored_kwh / CAPACITY_KWH)
		indicator.position.x = -(1.0 - indicator.scale.x) * 1.2
		indicator.visible = stored_kwh > 0.01


func charge_kw(requested_kw: float, delta: float) -> float:
	if delta <= 0.0:
		return 0.0
	var allowed_kw: float = minf(MAX_INPUT_KW, maxf(0.0, requested_kw))
	var max_possible: float = (CAPACITY_KWH - stored_kwh) / (delta * GAME_HOURS_PER_SECOND)
	var actual: float = minf(allowed_kw, maxf(0.0, max_possible))
	stored_kwh = minf(CAPACITY_KWH, stored_kwh + actual * delta * GAME_HOURS_PER_SECOND)
	active_flow = actual
	return actual


func discharge_kw(requested_kw: float, delta: float) -> float:
	if delta <= 0.0:
		return 0.0
	var max_possible: float = stored_kwh / (delta * GAME_HOURS_PER_SECOND)
	var actual: float = minf(minf(MAX_OUTPUT_KW, maxf(0.0, requested_kw)), maxf(0.0, max_possible))
	stored_kwh = maxf(0.0, stored_kwh - actual * delta * GAME_HOURS_PER_SECOND)
	active_flow = -actual
	return actual


func get_access_radius() -> float:
	return CLEARANCE_RADIUS


func describe() -> String:
	return "Energia %.2f / %.1f kWh | %.1f kW max IN/OUT" % [stored_kwh, CAPACITY_KWH, MAX_INPUT_KW]


func _box(part: String, pos: Vector3, size: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = part
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = material
	add_child(mesh)


func _mat(color: Color, glow: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.46
	result.metallic = 0.4
	if glow:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result
