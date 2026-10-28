extends Node3D
## WOW 0.12: techniczne drogi kolonii. Przejezdne, bez fizycznych kolizji.
## Jeden kamien wystarcza na cztery nowe pola; wspolne odcinki liczone raz.
const COST_CELLS_PER_STONE: int = 4
const MAX_PATH_CELLS: int = 160

var built_cells: Dictionary = {}
var current_preview: Array[Vector2i] = []
var paved: MultiMeshInstance3D
var preview_surface: MultiMeshInstance3D
var line_markers: MultiMeshInstance3D


func _ready() -> void:
	name = "TechnicalRoadNetwork"
	paved = _make_multimesh("BuiltRoadSurface", Color(0.19, 0.26, 0.28, 1.0), 0.92, 0.042)
	line_markers = _make_multimesh("RoadGuideMarks", Color(0.98, 0.56, 0.17, 1.0), 0.13, 0.05)
	preview_surface = _make_multimesh("RoadPlanningPreview", Color(0.21, 0.97, 0.72, 0.52), 0.90, 0.079)


func _make_multimesh(label: String, color: Color, extent: float, height: float) -> MultiMeshInstance3D:
	var view := MultiMeshInstance3D.new()
	view.name = label
	var tile := PlaneMesh.new()
	tile.size = Vector2(extent, extent)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tile.material = mat
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = tile
	batch.instance_count = 0
	view.multimesh = batch
	view.position.y = height
	add_child(view)
	return view


func has_cell(cell: Vector2i) -> bool:
	return built_cells.has(cell)


func route(points: Array[Vector3], nav: RefCounted) -> Array[Vector2i]:
	if points.size() < 2:
		return []
	var seen: Dictionary = {}
	var result: Array[Vector2i] = []
	for i in range(1, points.size()):
		var origin: Vector3 = points[i - 1]
		var target: Vector3 = points[i]
		var start := Vector2i(roundi(origin.x), roundi(origin.z))
		var finish := Vector2i(roundi(target.x), roundi(target.z))
		if not nav.grid.region.has_point(start) or not nav.grid.region.has_point(finish):
			return []
		if nav.grid.is_point_solid(start) or nav.grid.is_point_solid(finish):
			return []
		var leg: Array[Vector3] = nav.find_path(origin, target)
		if leg.is_empty() or Vector2i(roundi(leg[leg.size() - 1].x), roundi(leg[leg.size() - 1].z)) != finish:
			return []
		for position in leg:
			var cell := Vector2i(roundi(position.x), roundi(position.z))
			if not seen.has(cell):
				result.append(cell)
				seen[cell] = true
		if result.size() > MAX_PATH_CELLS:
			return []
	return result


func new_cells(path: Array[Vector2i]) -> Array[Vector2i]:
	var fresh: Array[Vector2i] = []
	for cell in path:
		if not built_cells.has(cell):
			fresh.append(cell)
	return fresh


func cost(path: Array[Vector2i]) -> int:
	var count: int = new_cells(path).size()
	return ceili(float(count) / float(COST_CELLS_PER_STONE))


func preview(path: Array[Vector2i]) -> void:
	current_preview = path.duplicate()
	var pending: Array[Vector2i] = new_cells(path)
	_draw_tiles(preview_surface.multimesh, pending)


func cancel_preview() -> void:
	current_preview.clear()
	preview_surface.multimesh.instance_count = 0


func commit(path: Array[Vector2i]) -> int:
	# Wywolujacy odpowiada za pobranie kosztu i rewalidacje.
	var pending: Array[Vector2i] = new_cells(path)
	for cell in pending:
		built_cells[cell] = true
	cancel_preview()
	_refresh_built()
	return pending.size()


func _refresh_built() -> void:
	var tiles: Array[Vector2i] = []
	var dashes: Array[Vector2i] = []
	for cell in built_cells.keys():
		tiles.append(cell)
		if posmod(cell.x + cell.y, 3) == 0:
			dashes.append(cell)
	_draw_tiles(paved.multimesh, tiles)
	_draw_tiles(line_markers.multimesh, dashes)


func _draw_tiles(batch: MultiMesh, cells: Array[Vector2i]) -> void:
	batch.instance_count = cells.size()
	for i in range(cells.size()):
		var cell: Vector2i = cells[i]
		batch.set_instance_transform(i, Transform3D(Basis(), Vector3(float(cell.x), 0.0, float(cell.y))))


func to_dict() -> Dictionary:
	var cells: Array = []
	for c in built_cells.keys():
		cells.append([c.x, c.y])
	return {"save_id": "roads", "cells": cells}


func from_dict(data: Dictionary) -> void:
	built_cells.clear()
	for raw in data.get("cells", []):
		if raw is Array and raw.size() == 2:
			built_cells[Vector2i(int(raw[0]), int(raw[1]))] = true
	cancel_preview()
	_refresh_built()
