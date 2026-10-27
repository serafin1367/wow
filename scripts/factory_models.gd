extends Node3D
## Autorskie procedurale modele: wiertnica, tasmociag, huta.
## Prototypy wizualne, bez produkcji/logistyki. Gotowe do instancjonowania.

@export_enum("extractor", "conveyor", "smelter") var machine_type: String = "extractor"

var hull: StandardMaterial3D
var steel: StandardMaterial3D
var orange: StandardMaterial3D
var glow: StandardMaterial3D


func _ready() -> void:
	hull = _material(Color(0.13, 0.19, 0.23))
	steel = _material(Color(0.47, 0.53, 0.56))
	orange = _material(Color(0.98, 0.52, 0.13))
	glow = _material(Color(0.24, 0.91, 0.98), true)
	match machine_type:
		"extractor":
			_build_extractor()
		"conveyor":
			_build_conveyor()
		"smelter":
			_build_smelter()


func _build_extractor() -> void:
	_add_box("DrillBase", Vector3(0, 0.27, 0), Vector3(4.6, 0.54, 4.1), hull)
	_add_box("RaisedPlatform", Vector3(0, 0.67, 0), Vector3(3.8, 0.25, 3.4), orange)
	_add_box("Engine", Vector3(-0.72, 1.3, -0.5), Vector3(1.8, 1.2, 1.7), steel)
	_add_box("EngineAccent", Vector3(-0.72, 1.68, 0.42), Vector3(1.1, 0.18, 0.08), glow)
	_add_cylinder("DrillShaft", Vector3(0.9, 1.5, 0.2), 0.32, 3.0, steel)
	_add_cylinder("DrillCrown", Vector3(0.9, 0.22, 0.2), 0.56, 0.35, hull)
	_add_box("DrillTower", Vector3(0.92, 3.1, 0.2), Vector3(1.36, 0.8, 1.36), orange)
	for x in [-1.8, 1.8]:
		_add_box("Support", Vector3(x, 0.95, 0), Vector3(0.27, 1.4, 3.3), hull)
	_add_box("OreOutlet", Vector3(0.0, 0.9, 2.25), Vector3(1.15, 0.65, 1.05), steel)


func _build_conveyor() -> void:
	_add_box("LowerSupport", Vector3(0, 0.37, 0), Vector3(1.55, 0.3, 5.4), hull)
	_add_box("Belt", Vector3(0, 0.58, 0), Vector3(1.55, 0.12, 5.05), steel)
	for x in [-0.81, 0.81]:
		_add_box("Rail", Vector3(x, 0.84, 0), Vector3(0.12, 0.44, 5.2), orange)
	for z in [-2.0, -1.0, 0.0, 1.0, 2.0]:
		_add_box("BeltSegment", Vector3(0, 0.66, z), Vector3(1.3, 0.04, 0.14), hull)
	for z in [-1.9, 1.9]:
		for x in [-0.6, 0.6]:
			_add_box("Leg", Vector3(x, 0.22, z), Vector3(0.16, 0.45, 0.25), hull)
	_add_box("DirectionLight", Vector3(0, 1.05, -2.65), Vector3(0.57, 0.11, 0.07), glow)


func _build_smelter() -> void:
	_add_box("Foundation", Vector3(0, 0.3, 0), Vector3(5.5, 0.6, 5.2), hull)
	_add_box("FurnaceHousing", Vector3(0, 2.1, -0.25), Vector3(4.2, 3.35, 3.65), steel)
	_add_box("HeatShield", Vector3(0, 1.8, 1.65), Vector3(2.4, 1.65, 0.22), orange)
	_add_box("MoltenLight", Vector3(0, 1.75, 1.79), Vector3(1.5, 0.4, 0.08), glow)
	for x in [-1.55, 1.55]:
		_add_cylinder("Exhaust", Vector3(x, 4.1, -0.6), 0.48, 3.0, hull)
		_add_cylinder("ExhaustRim", Vector3(x, 5.6, -0.6), 0.59, 0.25, orange)
		_add_box("Panel", Vector3(x, 2.9, 1.62), Vector3(0.53, 0.51, 0.12), glow)
	_add_box("Input", Vector3(-2.35, 0.8, 0), Vector3(0.72, 0.8, 1.35), hull)
	_add_box("Output", Vector3(2.35, 0.8, 0), Vector3(0.72, 0.8, 1.35), orange)


func _add_box(node_name: String, at: Vector3, size: Vector3, mat: Material) -> void:
	var item := MeshInstance3D.new()
	item.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.position = at
	item.material_override = mat
	add_child(item)


func _add_cylinder(node_name: String, at: Vector3, radius: float, height: float, mat: Material) -> void:
	var item := MeshInstance3D.new()
	item.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	item.mesh = mesh
	item.position = at
	item.material_override = mat
	add_child(item)


func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.52
	mat.metallic = 0.42
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
