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


func is_circle_walkable(center: Vector2, radius: float) -> bool:
	# Kontrola pod budynki i sadzonki. Nie akceptuj miejsc za granica mapy.
	var min_x: int = floori(center.x - radius)
	var max_x: int = ceili(center.x + radius)
	var min_y: int = floori(center.y - radius)
	var max_y: int = ceili(center.y + radius)
	if min_x < MIN_CELL or max_x > MAX_CELL or min_y < MIN_CELL or max_y > MAX_CELL:
		return false
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			if Vector2(float(x), float(y)).distance_squared_to(center) <= radius * radius:
				if grid.is_point_solid(Vector2i(x, y)):
					return false
	return true


func find_free_spawn_near(center: Vector3, camera_position: Vector3, occupied: Array[Vector3]) -> Variant:
	# Umieszczaj nowe jednostki na stronie ratusza widocznej od kamery.
	var towards_camera := Vector2(camera_position.x - center.x, camera_position.z - center.z)
	if towards_camera.length_squared() < 0.001:
		towards_camera = Vector2(0.0, 1.0)
	var base_angle := towards_camera.angle()
	var angle_offsets: Array[float] = [
		0.0, 0.30, -0.30, 0.60, -0.60, 0.90, -0.90,
		1.20, -1.20, 1.48, -1.48, 1.80, -1.80, PI
	]
	for radius in [6.0, 7.5, 9.0, 10.5, 12.0]:
		for offset in angle_offsets:
			var angle: float = base_angle + offset
			var candidate := Vector3(
				center.x + cos(angle) * radius,
				0.0,
				center.z + sin(angle) * radius
			)
			var cell := _world_to_cell(candidate)
			if abs(cell.x) >= 48 or abs(cell.y) >= 48:
				continue
			if grid.is_point_solid(cell):
				continue
			var free_space: bool = true
			for unit_position in occupied:
				if Vector2(float(cell.x), float(cell.y)).distance_to(Vector2(unit_position.x, unit_position.z)) < 1.6:
					free_space = false
					break
			if free_space:
				return Vector3(float(cell.x), 0.0, float(cell.y))
	return null


func find_access_path(origin: Vector3, center: Vector3, clearance_radius: float) -> Array[Vector3]:
	# Magazyn jest fizyczna przeszkoda, dlatego dostawa konczy sie PRZED budynkiem.
	# Wybieramy najkrotsza dostepna trase do jednego z punktow wokol niego.
	var best: Array[Vector3] = []
	var shortest: float = INF
	for radius_offset in [0.0, 0.8, 1.6]:
		var distance: float = clearance_radius + radius_offset
		for i in range(16):
			var angle := TAU * float(i) / 16.0
			var desired := Vector3(center.x + cos(angle) * distance, 0.0, center.z + sin(angle) * distance)
			var cell := _world_to_cell(desired)
			if grid.is_point_solid(cell):
				continue
			var path: Array[Vector3] = find_path(origin, Vector3(float(cell.x), 0.0, float(cell.y)))
			if path.is_empty():
				continue
			var score: float = 0.0
			for step in range(1, path.size()):
				score += path[step - 1].distance_to(path[step])
			# Wybor blizszego budynkowi pola rozstrzyga remisy.
			score += radius_offset * 0.1
			if score < shortest:
				shortest = score
				best = path
	return best

func find_conveyor_route(source: Vector3, source_radius: float, target: Vector3, target_radius: float) -> Array[Vector3]:
	# Zaden odcinek nie zaczyna sie wewnatrz kolizji budynku. Sprawdzamy
	# dostepne punkty otaczajace wylot i prowadzimy omijajaca przeszkody trase A*.
	var best: Array[Vector3] = []
	for offset in [0.8, 1.5]:
		for i in range(16):
			var angle: float = TAU * float(i) / 16.0
			var distance: float = source_radius + offset
			var candidate := Vector3(
				source.x + cos(angle) * distance, 0.0,
				source.z + sin(angle) * distance
			)
			var point: Vector2i = _world_to_cell(candidate)
			if grid.is_point_solid(point):
				continue
			var start := Vector3(float(point.x), 0.0, float(point.y))
			var route: Array[Vector3] = find_access_path(start, target, target_radius + 0.65)
			if route.size() < 2:
				continue
			if best.is_empty() or route.size() < best.size():
				best = route
				if route.size() <= 4:
					return best
	return best


func find_conveyor_route_via(source: Vector3, source_radius: float, target: Vector3, target_radius: float, waypoints: Array[Vector3]) -> Array[Vector3]:
	if waypoints.is_empty():
		return find_conveyor_route(source, source_radius, target, target_radius)
	var first: Vector3 = waypoints[0]
	var best_first: Array[Vector3] = []
	for offset in [0.8, 1.5]:
		for i in range(16):
			var angle: float = TAU * float(i) / 16.0
			var around := source + Vector3(cos(angle) * (source_radius + offset), 0, sin(angle) * (source_radius + offset))
			var cell: Vector2i = _world_to_cell(around)
			if grid.is_point_solid(cell):
				continue
			var possible: Array[Vector3] = find_path(Vector3(float(cell.x), 0, float(cell.y)), first)
			if possible.is_empty():
				continue
			if best_first.is_empty() or possible.size() < best_first.size():
				best_first = possible
	if best_first.is_empty():
		return []
	var route: Array[Vector3] = best_first.duplicate()
	for j in range(1, waypoints.size()):
		var leg: Array[Vector3] = find_path(route[route.size() - 1], waypoints[j])
		if leg.is_empty():
			return []
		_append_unique(route, leg)
	var last_leg: Array[Vector3] = find_access_path(route[route.size() - 1], target, target_radius + 0.65)
	if last_leg.is_empty():
		return []
	_append_unique(route, last_leg)
	return route


func _append_unique(result: Array[Vector3], points: Array[Vector3]) -> void:
	for p in points:
		if result.is_empty() or result[result.size() - 1].distance_squared_to(p) > 0.01:
			result.append(p)


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
