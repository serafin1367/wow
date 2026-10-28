extends Node3D
## WOW 0.10: lokalna nakladka siatki na ziemi. Zero kolizji.
## Renderowanie przez dwa MultiMesh: zielony teren wolny, czerwony zajety.
## Kolor obrysu odpowiada faktycznej walidacji calego budynku.

const GRID_RADIUS: int = 8
const FREE_COLOR: Color = Color(0.12, 0.88, 0.48, 0.31)
const BLOCKED_COLOR: Color = Color(0.97, 0.18, 0.16, 0.39)

var free_mesh: MultiMeshInstance3D
var blocked_mesh: MultiMeshInstance3D
var footprint: MeshInstance3D
var hover_caption: Label3D
var last_radius: float = -1.0


func _ready() -> void:
	name = "LocalBuildGrid"
	free_mesh = _make_cells("BuildableCells", FREE_COLOR)
	blocked_mesh = _make_cells("OccupiedCells", BLOCKED_COLOR)
	footprint = MeshInstance3D.new()
	footprint.name = "FootprintOutline"
	footprint.material_override = _material(Color(0.10, 0.97, 0.56, 0.95))
	footprint.position.y = 0.16
	add_child(footprint)

	hover_caption = Label3D.new()
	hover_caption.name = "PlacementCaption"
	hover_caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hover_caption.font_size = 36
	hover_caption.pixel_size = 0.008
	hover_caption.position.y = 2.3
	hover_caption.no_depth_test = true
	add_child(hover_caption)
	visible = false


func _make_cells(title: String, color: Color) -> MultiMeshInstance3D:
	var result := MultiMeshInstance3D.new()
	result.name = title
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.90, 0.90)
	var mat := _material(color)
	mesh.material = mat
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = 0
	result.multimesh = instances
	add_child(result)
	return result


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func update_area(site: Vector3, radius: float, can_build: bool, free_cell: Callable) -> void:
	visible = true
	position = Vector3(roundf(site.x), 0.0, roundf(site.z))
	if absf(radius - last_radius) > 0.01:
		var torus := TorusMesh.new()
		torus.inner_radius = maxf(0.10, radius - 0.10)
		torus.outer_radius = radius + 0.10
		torus.rings = 8
		torus.ring_segments = 64
		footprint.mesh = torus
		last_radius = radius
	footprint.material_override = _material(
		Color(0.18, 1.0, 0.45, 0.96) if can_build else Color(1.0, 0.20, 0.13, 0.96)
	)
	hover_caption.text = "WOLNE MIEJSCE" if can_build else "ZAJETE / NIEDOSTEPNE"
	hover_caption.modulate = Color(0.30, 1.0, 0.52) if can_build else Color(1.0, 0.39, 0.31)

	var available: Array[Vector3] = []
	var unavailable: Array[Vector3] = []
	for dx in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for dz in range(-GRID_RADIUS, GRID_RADIUS + 1):
			var cell := Vector2i(roundi(site.x) + dx, roundi(site.z) + dz)
			var inside_footprint: bool = Vector2(float(dx), float(dz)).length() <= radius
			var free: bool = free_cell.call(cell)
			# Kiedy caly obrys nie miesci sie, jasno oznaczamy go czerwonym.
			if inside_footprint and not can_build:
				free = false
			var at := Vector3(float(dx), 0.075, float(dz))
			if free:
				available.append(at)
			else:
				unavailable.append(at)
	_fill_instances(free_mesh.multimesh, available)
	_fill_instances(blocked_mesh.multimesh, unavailable)


func _fill_instances(multimesh: MultiMesh, places: Array[Vector3]) -> void:
	multimesh.instance_count = places.size()
	for i in range(places.size()):
		multimesh.set_instance_transform(i, Transform3D(Basis(), places[i]))


func clear() -> void:
	visible = false
