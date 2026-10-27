extends RefCounted
## Siatka A* dla plaskiego terenu X/Z.
## Przeszkody sa powiekszone o zapas dla szerokosci robotnika.

const MIN_CELL: int = -49
const MAX_CELL: int = 49
const MAX_SEARCH_RADIUS: int = 12

var grid: AStarGrid2D
var obstacle_counts: Dictionary = {}


func _init() -> void:
	grid = AStarGrid2D.new()
	grid.region = Rect2i(MIN_CELL, MIN_CELL, MAX_CELL - MIN_CELL + 1, MAX_CELL - MIN_CELL + 1)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()


func block_circle(center: Vector2, radius: float) -> void:
	_change_blocking(center, radius, 1)


func unblock_circle(center: Vector2, radius: float) -> void:
	_change_blocking(center, radius, -1)


func _change_blocking(center: Vector2, radius: float, change: int) -> void:
	for x in range(maxi(MIN_CELL, floori(center.x - radius)), mini(MAX_CELL, ceili(center.x + radius)) + 1):
		for z in range(maxi(MIN_CELL, floori(center.y - radius)), mini(MAX_CELL, ceili(center.y + radius)) + 1):
			if Vector2(float(x), float(z)).distance_squared_to(center) <= radius * radius:
				var cell := Vector2i(x, z)
				var count: int = maxi(0, int(obstacle_counts.get(cell, 0)) + change)
				if count == 0:
					obstacle_counts.erase(cell)
				else:
					obstacle_counts[cell] = count
				grid.set_point_solid(cell, count > 0)


func find_free_spawn_near(center: Vector3, sequence: int = 0) -> Vector3:
	# Kandydaci sa poza promieniem blokowania ratusza (4.5 pola).
	for radius in range(5, 12):
		for i in range(16):
			var angle := TAU * float((i + sequence * 3) % 16) / 16.0
			var position := Vector3(
				center.x + cos(angle) * float(radius),
				0.0,
				center.z + sin(angle) * float(radius)
			)
			var cell := _world_to_cell(position)
			if abs(cell.x) > 47 or abs(cell.y) > 47:
				continue
			if not grid.is_point_solid(cell):
				return Vector3(float(cell.x), 0.0, float(cell.y))
	return Vector3(0.0, 0.0, 0.0)


func find_path(origin: Vector3, target: Vector3) -> Array[Vector3]:
	var from_id := _world_to_cell(origin)
	var to_id := _nearest_walkable(_world_to_cell(target))
	var path: Array[Vector3] = []
	if grid.is_point_solid(from_id) or grid.is_point_solid(to_id):
		return path

	var cells: Array[Vector2i] = grid.get_id_path(from_id, to_id)
	for cell in cells:
		path.append(Vector3(float(cell.x), 0.0, float(cell.y)))
	return path


func _world_to_cell(world: Vector3) -> Vector2i:
	return Vector2i(
		clampi(roundi(world.x), MIN_CELL, MAX_CELL),
		clampi(roundi(world.z), MIN_CELL, MAX_CELL)
	)


func _nearest_walkable(target: Vector2i) -> Vector2i:
	if not grid.is_point_solid(target):
		return target

	# Dla klikniecia w kopalnie/drzewo znajdz dostepny punkt obok przeszkody.
	for radius in range(1, MAX_SEARCH_RADIUS + 1):
		var best_cell := target
		var best_distance := INF
		for x in range(maxi(MIN_CELL, target.x - radius), mini(MAX_CELL, target.x + radius) + 1):
			for z in range(maxi(MIN_CELL, target.y - radius), mini(MAX_CELL, target.y + radius) + 1):
				var cell := Vector2i(x, z)
				if grid.is_point_solid(cell):
					continue
				var distance := Vector2(cell).distance_squared_to(Vector2(target))
				if distance < best_distance:
					best_distance = distance
					best_cell = cell
		if best_distance < INF:
			return best_cell
	return target
