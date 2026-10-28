extends Node3D
## WOW: pierwszy prototyp RTS bez zewnetrznych zasobow graficznych.

const WORKER_SCRIPT = preload("res://scripts/worker.gd")
const CAMERA_SCRIPT = preload("res://scripts/rts_camera.gd")
const NAVIGATION_SCRIPT = preload("res://scripts/navigation_grid.gd")
const SELECTION_BOX_SCRIPT = preload("res://scripts/selection_box.gd")
const RESOURCE_SCRIPT = preload("res://scripts/resource_node.gd")
const TOWN_HALL_SCRIPT = preload("res://scripts/town_hall.gd")
const FORESTER_SCRIPT = preload("res://scripts/forester_hut.gd")
const LANDER_SCRIPT = preload("res://scripts/colony_lander.gd")
const CHARGER_SCRIPT = preload("res://scripts/charging_pad.gd")
const HUD_SCRIPT = preload("res://scripts/colony_hud.gd")
const KENNEY_ASSETS = preload("res://scripts/kenney_assets.gd")
const PLANET_SCRIPT = preload("res://scripts/planet_environment.gd")
const DEPOT_VISUAL_SCRIPT = preload("res://scripts/depot_model.gd")
const MINE_SCRIPT = preload("res://scripts/automated_mine.gd")
const SMELTER_SCRIPT = preload("res://scripts/automated_smelter.gd")
const CONVEYOR_SCRIPT = preload("res://scripts/conveyor_link.gd")
const SOLAR_SCRIPT = preload("res://scripts/solar_array.gd")
const BATTERY_SCRIPT = preload("res://scripts/battery_bank.gd")
const POWER_CABLE_SCRIPT = preload("res://scripts/power_cable.gd")
const BUILD_PREVIEW_SCRIPT = preload("res://scripts/build_placement_preview.gd")
const ROADS_SCRIPT = preload("res://scripts/technical_roads.gd")
const BLUEPRINTS_SCRIPT = preload("res://scripts/construction_blueprints.gd")
const START_PLANET = "Mars"
const LANDER_POSITION: Vector3 = Vector3(0.0, 0.0, -12.0)
const CHARGER_POSITION: Vector3 = Vector3(-9.0, 0.0, -10.0)
const FORESTER_COST: Dictionary = {"wood": 30, "stone": 10}
const FORESTER_RADIUS: float = 3.1
const MAX_FORESTERS: int = 4
const TREE_GROW_SECONDS: float = 30.0
const TOWN_HALL_COST: Dictionary = {"wood": 40, "stone": 20}
const WORKER_COST: Dictionary = {"wood": 10, "gold": 20}
const TOWN_HALL_RADIUS: float = 4.5
const DEPOT_BLOCK_RADIUS: float = 3.2
const IRON_DEPOSIT_POSITION: Vector3 = Vector3(18.0, 0.0, 8.0)
const MINE_COST: Dictionary = {"wood": 20, "stone": 10}
const SMELTER_COST: Dictionary = {"wood": 30, "stone": 20}
const SMELTER_RADIUS: float = 3.9
const ORE_CONVEYOR_COST: Dictionary = {"metal": 5}
const METAL_CONVEYOR_COST: Dictionary = {"metal": 8}
const SOLAR_ARRAY_COST: Dictionary = {"metal": 8, "stone": 5}
const BATTERY_BANK_COST: Dictionary = {"metal": 12, "stone": 8}
const MAX_SOLAR_ARRAYS: int = 5
const MAX_BATTERIES: int = 3
const MAX_WORKERS: int = 30
const DEPOT_POSITION: Vector3 = Vector3(0.0, 0.0, 8.0)
const MAP_SIZE: float = 100.0

var workers: Array = []
var selected_workers: Array = []
var navigation = NAVIGATION_SCRIPT.new()
var selection_box: Control
var mouse_down: bool = false
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
# Paczka startowa statku: materiały wystarczą na pierwszy ekstraktor i hute.
var resource_totals: Dictionary = {"wood": 90, "gold": 0, "stone": 60, "metal": 0}
var forester_build_mode: bool = false
var foresters: Array = []
var build_mode: bool = false
var town_hall: StaticBody3D
var training_timer: Timer
var training_in_progress: bool = false
var landing_rocket = null
var charging_pad = null
var hud_elapsed: float = 0.0
var hud = null
var selected_structure = null
var planet_env = null
var factory_mine = null
var factory_smelter = null
var mine_build_mode: bool = false
var smelter_build_mode: bool = false
var unused_power_kw: float = 0.0
var ore_conveyor = null
var metal_conveyor = null
var manual_conveyor_kind: String = ""
var manual_conveyor_points: Array[Vector3] = []
var manual_conveyor_preview = null
var solar_arrays: Array = []
var battery_banks: Array = []
var power_cables: Array = []
var energy_build_kind: String = ""
var grid_generation_kw: float = 0.0
var grid_consumption_kw: float = 0.0
var battery_draw_kw: float = 0.0
var build_preview = null
var preview_elapsed: float = 0.0
var placement_rotation_quarters: int = 0
var placement_snap_size: int = 1
var roads = null
var blueprints = null
var planning_enabled: bool = false
var sticky_build_enabled: bool = false
var road_mode: bool = false
var road_anchors: Array[Vector3] = []
var road_preview_route: Array[Vector2i] = []
var road_hover_elapsed: float = 0.0


func _ready() -> void:
	_create_environment()
	_create_ground()
	_create_resources()
	_create_depot()
	_create_landing_site()
	_create_planet_environment()
	_create_workers()
	_create_camera()
	_create_hud()
	_create_build_preview()
	_create_infrastructure_planner()
	_create_training_timer()


func _create_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.27, 0.39, 0.48)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.64, 0.75, 0.82)
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50.0, -25.0, 0.0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	add_child(sun)


func _create_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 0
	add_child(ground)

	var visual := MeshInstance3D.new()
	visual.name = "Grass"
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP_SIZE, MAP_SIZE)
	visual.mesh = plane
	visual.material_override = _make_material(Color(0.22, 0.34, 0.30))
	ground.add_child(visual)

	var shape := BoxShape3D.new()
	shape.size = Vector3(MAP_SIZE, 0.2, MAP_SIZE)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -0.1
	ground.add_child(collision)

	# Material proceduralny i detale planety tworzy PlanetEnvironment.
	# Podloze pozostaje poziome, aby zachowac obecna nawigacje A*.

	# Strefa ladowania rakiety, z przemyslowym obramowaniem.
	var pad := MeshInstance3D.new()
	pad.name = "LandingZone"
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 8.2
	pad_mesh.bottom_radius = 8.2
	pad_mesh.height = 0.07
	pad_mesh.radial_segments = 12
	pad.mesh = pad_mesh
	pad.position = Vector3(LANDER_POSITION.x, 0.035, LANDER_POSITION.z)
	pad.material_override = _make_material(Color(0.18, 0.24, 0.27))
	add_child(pad)

	var core := MeshInstance3D.new()
	core.name = "LandingMarking"
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 7.45
	core_mesh.bottom_radius = 7.45
	core_mesh.height = 0.015
	core_mesh.radial_segments = 12
	core.mesh = core_mesh
	core.position = Vector3(LANDER_POSITION.x, 0.079, LANDER_POSITION.z)
	core.material_override = _make_material(Color(0.26, 0.36, 0.37))
	add_child(core)


func _create_resources() -> void:
	var forest := Node3D.new()
	forest.name = "Forest"
	add_child(forest)
	var tree_positions: Array[Vector2] = [
		Vector2(-35, -29), Vector2(-31, -25), Vector2(-27, -33),
		Vector2(-37, -20), Vector2(-24, -24), Vector2(-31, -17),
		Vector2(20, -30), Vector2(25, -27), Vector2(30, -32),
		Vector2(34, -25)
	]
	for location in tree_positions:
		_add_tree(forest, location)

	_add_deposit("GoldMine", Vector3(-25.0, 0.0, 9.0), Color(0.9, 0.67, 0.12))
	_add_deposit("StoneQuarry", Vector3(29.0, 0.0, 18.0), Color(0.48, 0.50, 0.53))
	_add_deposit("IronOreDeposit", IRON_DEPOSIT_POSITION, Color(0.32, 0.40, 0.45))


func _add_tree(parent_node: Node3D, coords: Vector2, sapling: bool = false) -> StaticBody3D:
	var tree = RESOURCE_SCRIPT.new()
	tree.resource_type = "wood"
	tree.is_sapling = sapling
	tree.remaining = 0 if sapling else 200
	tree.clearance_radius = 1.6
	tree.depleted.connect(_on_resource_depleted)
	tree.collision_layer = 0 if sapling else 4
	tree.scale = Vector3.ONE * 0.16 if sapling else Vector3.ONE
	tree.collision_mask = 0
	tree.name = "Tree"
	tree.position = Vector3(coords.x, 0.0, coords.y)
	parent_node.add_child(tree)
	tree.add_to_group("resource_nodes")

	# Prawdziwe modele low-poly Kenney Nature Kit (CC0).
	# Pozostawiamy oryginalne hitboxy i parametry scinania.
	var variants: Array[String] = ["tree-oak", "tree-default", "tree-cone", "tree-pinedefaulta"]
	var variant_index: int = posmod(roundi(coords.x * 11.0 + coords.y * 23.0), variants.size())
	var tree_visual = KENNEY_ASSETS.model("nature", variants[variant_index], 3.8)
	if tree_visual != null:
		tree_visual.name = "KenneyTree"
		tree.add_child(tree_visual)
	else:
		# Fallback jesli GLB zostanie usuniety z projektu.
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.height = 2.5
		trunk_mesh.top_radius = 0.32
		trunk_mesh.bottom_radius = 0.48
		trunk.mesh = trunk_mesh
		trunk.position.y = 1.25
		trunk.material_override = _make_material(Color(0.40, 0.25, 0.12))
		tree.add_child(trunk)
		var leaves := MeshInstance3D.new()
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 1.7
		crown_mesh.height = 3.4
		leaves.mesh = crown_mesh
		leaves.position.y = 3.35
		leaves.material_override = _make_material(Color(0.10, 0.37, 0.16))
		tree.add_child(leaves)

	var trunk_collision := CollisionShape3D.new()
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.6
	trunk_shape.height = 2.5
	trunk_collision.shape = trunk_shape
	trunk_collision.position.y = 1.25
	tree.add_child(trunk_collision)

	# Klikniecie korony drzewa rowniez zleca scinanie.
	var crown_collision := CollisionShape3D.new()
	var crown_shape := SphereShape3D.new()
	crown_shape.radius = 1.7
	crown_collision.shape = crown_shape
	crown_collision.position.y = 3.35
	tree.add_child(crown_collision)

	if planet_env != null:
		planet_env.apply_resource_colors([tree])

	if sapling:
		var growth := create_tween()
		growth.tween_property(tree, "scale", Vector3.ONE, TREE_GROW_SECONDS)
		growth.tween_callback(_finish_sapling_growth.bind(tree))
	else:
		navigation.block_circle(coords, 1.6)
	return tree


func _finish_sapling_growth(sapling) -> void:
	if not is_instance_valid(sapling) or not sapling.is_sapling:
		return
	# Nie wstawiaj nowej kolizji na stojacej tam jednostce.
	for worker in workers:
		if _ground_distance(worker.global_position, sapling.global_position) < 2.1:
			get_tree().create_timer(2.5).timeout.connect(_finish_sapling_growth.bind(sapling))
			return
	sapling.scale = Vector3.ONE
	sapling.is_sapling = false
	sapling.remaining = 200
	sapling.collision_layer = 4
	var point: Vector3 = sapling.global_position
	navigation.block_circle(Vector2(point.x, point.z), sapling.clearance_radius)


func _add_deposit(deposit_name: String, location: Vector3, tint: Color) -> void:
	var deposit = RESOURCE_SCRIPT.new()
	deposit.resource_type = "gold" if deposit_name == "GoldMine" else ("iron_ore" if deposit_name == "IronOreDeposit" else "stone")
	deposit.remaining = 4500 if deposit.resource_type == "iron_ore" else (3000 if deposit.resource_type == "gold" else 2000)
	deposit.clearance_radius = 3.6
	deposit.depleted.connect(_on_resource_depleted)
	deposit.collision_layer = 4
	deposit.collision_mask = 0
	deposit.name = deposit_name
	deposit.position = location
	add_child(deposit)
	deposit.add_to_group("resource_nodes")

	# Ciemy kamien i fizyczne zyly mineralne zamiast zoltych bryl.
	var rock_variants: Array[String] = ["rock-largea", "rock-largeb", "rock-largec"]
	for i in range(4):
		var offset := Vector3(float(i % 2) * 2.0 - 1.0, 0.0, float(i / 2) * 2.0 - 1.0)
		var base_rock: Color = Color(0.27, 0.24, 0.24) if deposit.resource_type == "gold" else Color(0.40, 0.42, 0.43)
		var rock = KENNEY_ASSETS.model("nature", rock_variants[i % rock_variants.size()], 2.8 + float(i) * 0.16)
		if rock != null:
			rock.name = "OreRock_%d" % i
			rock.position = offset
			KENNEY_ASSETS.tint_meshes(rock, base_rock)
			deposit.add_child(rock)
		else:
			var fallback := MeshInstance3D.new()
			fallback.name = "OreRock_%d" % i
			var mesh := SphereMesh.new()
			mesh.radius = 0.9
			fallback.mesh = mesh
			fallback.position = offset + Vector3(0, 0.9, 0)
			fallback.material_override = _make_material(base_rock)
			deposit.add_child(fallback)

		# Blaszczace zyla w skale i krysztaly wystajace z powierzchni.
		var vein := MeshInstance3D.new()
		vein.name = "Vein_%d" % i
		var vein_mesh := BoxMesh.new()
		vein_mesh.size = Vector3(1.05 + float(i) * 0.17, 0.13, 0.22)
		vein.mesh = vein_mesh
		vein.position = offset + Vector3(-0.12, 1.25 + float(i % 2) * 0.16, 0.10)
		vein.rotation_degrees = Vector3(0.0, float(i * 34), 8.0 + float(i) * 5.0)
		vein.material_override = _make_material(Color(0.95, 0.65, 0.15) if deposit.resource_type == "gold" else Color(0.33, 0.78, 0.83))
		deposit.add_child(vein)
		if deposit.resource_type == "gold":
			var tip := MeshInstance3D.new()
			tip.name = "OreCrystal_%d" % i
			var crystal := CylinderMesh.new()
			crystal.bottom_radius = 0.38
			crystal.top_radius = 0.025
			crystal.height = 0.92 + float(i % 3) * 0.22
			crystal.radial_segments = 5
			tip.mesh = crystal
			tip.position = offset + Vector3(0.26, 1.65, -0.20)
			tip.material_override = _make_material(Color(0.91, 0.56, 0.12))
			deposit.add_child(tip)

	var obstacle_collision := CollisionShape3D.new()
	var obstacle_shape := BoxShape3D.new()
	obstacle_shape.size = Vector3(5.0, 2.5, 5.0)
	obstacle_collision.shape = obstacle_shape
	obstacle_collision.position.y = 1.25
	deposit.add_child(obstacle_collision)
	navigation.block_circle(Vector2(location.x, location.z), 3.6)


func _create_depot() -> void:
	var depot := StaticBody3D.new()
	depot.name = "Stockpile"
	depot.position = DEPOT_POSITION
	depot.collision_layer = 4
	depot.collision_mask = 0
	add_child(depot)

	var storage_collision := CollisionShape3D.new()
	var storage_shape := BoxShape3D.new()
	storage_shape.size = Vector3(4.0, 2.8, 4.0)
	storage_collision.shape = storage_shape
	storage_collision.position.y = 1.4
	depot.add_child(storage_collision)
	navigation.block_circle(Vector2(DEPOT_POSITION.x, DEPOT_POSITION.z), DEPOT_BLOCK_RADIUS)

	var warehouse = DEPOT_VISUAL_SCRIPT.new()
	depot.add_child(warehouse)

func _create_landing_site() -> void:
	# Rakieta jest juz po ladowaniu. Zostanie pozniej zastapiona animacja lotu.
	landing_rocket = LANDER_SCRIPT.new()
	landing_rocket.position = LANDER_POSITION
	add_child(landing_rocket)
	navigation.block_circle(Vector2(LANDER_POSITION.x, LANDER_POSITION.z), landing_rocket.get_access_radius())

	charging_pad = CHARGER_SCRIPT.new()
	charging_pad.position = CHARGER_POSITION
	charging_pad.power_source = landing_rocket
	add_child(charging_pad)
	navigation.block_circle(Vector2(CHARGER_POSITION.x, CHARGER_POSITION.z), charging_pad.get_access_radius())

	_connect_power_node(charging_pad)


func _create_planet_environment() -> void:
	planet_env = PLANET_SCRIPT.new()
	add_child(planet_env)
	planet_env.initialize(
		get_node("Ground/Grass") as MeshInstance3D,
		get_node("WorldEnvironment") as WorldEnvironment,
		get_node("Sun") as DirectionalLight3D,
		START_PLANET
	)
	planet_env.apply_resource_colors(get_tree().get_nodes_in_group("resource_nodes"))


func _cycle_planet() -> void:
	if planet_env == null:
		return
	var planet_name: String = planet_env.next_planet()
	planet_env.apply_resource_colors(get_tree().get_nodes_in_group("resource_nodes"))
	if hud != null:
		hud.set_planet(planet_name)
	_set_status("Podglad biomu: %s. To zmiana wygladu mapy, bez teleportacji." % planet_name)


func _create_infrastructure_planner() -> void:
	roads = ROADS_SCRIPT.new()
	add_child(roads)
	blueprints = BLUEPRINTS_SCRIPT.new()
	add_child(blueprints)
	for robot in workers:
		robot.road_network = roads
	_update_planning_hud()


func _update_planning_hud() -> void:
	if hud != null and blueprints != null:
		hud.set_planning_state(planning_enabled, sticky_build_enabled,
		blueprints.entries.size(), blueprints.describe_cost(Callable(self, "_build_cost")))


func _build_cost(kind: String) -> Dictionary:
	match kind:
		"mine":
			return MINE_COST
		"smelter":
			return SMELTER_COST
		"center":
			return TOWN_HALL_COST
		"forester":
			return FORESTER_COST
		"solar":
			return SOLAR_ARRAY_COST
		"battery":
			return BATTERY_BANK_COST
	return {}


func _toggle_planning() -> void:
	planning_enabled = not planning_enabled
	_update_planning_hud()
	_set_status("PROJEKT: %s | Shift+LPM dodaje plan; Enter buduje, Backspace cofa." %
		("WLACZONY" if planning_enabled else "WYLACZONY"))


func _toggle_sticky_build() -> void:
	sticky_build_enabled = not sticky_build_enabled
	_update_planning_hud()
	_set_status("Seria budowy %s (L, V i K)." %
		("AKTYWNA" if sticky_build_enabled else "WYLACZONA"))


func _queue_building_blueprint(screen_position: Vector2) -> void:
	var kind: String = _active_build_kind()
	var hit: Dictionary = _build_site_at_mouse(screen_position, kind)
	if hit.is_empty():
		_set_status("Projekt: wybierz teren mapy.")
		return
	var site: Vector3 = hit["site"]
	if not _can_place_structure_at(site, kind):
		_set_status("Projekt koliduje z istniejacym lub zaplanowanym budynkiem.")
		return
	if blueprints.entries.size() >= blueprints.MAX_BLUEPRINTS:
		_set_status("Limit projektu: 12 konstrukcji.")
		return
	var total: Dictionary = blueprints.total_cost(Callable(self, "_build_cost"))
	for res_type in _build_cost(kind):
		total[res_type] = int(total.get(res_type, 0)) + int(_build_cost(kind)[res_type])
	if not _can_afford(total):
		_set_status("W projekcie brakuje zasobow do kolejnej konstrukcji.")
		return
	blueprints.add_blueprint(kind, site, placement_rotation_quarters)
	_update_planning_hud()
	_set_status("Projekt: %d budynkow (%s). Enter zatwierdzi calosc." %
		[blueprints.entries.size(), blueprints.describe_cost(Callable(self, "_build_cost"))])


func _clear_blueprints() -> void:
	if blueprints != null:
		blueprints.clear_plan()
	_update_planning_hud()
	_set_status("Wyczyszczono niezrealizowany projekt (bez kosztow).")


func _undo_blueprint() -> void:
	if blueprints != null and blueprints.pop_last():
		_update_planning_hud()
		_set_status("Cofnieto ostatni element projektu.")


func _create_build_preview() -> void:
	build_preview = BUILD_PREVIEW_SCRIPT.new()
	add_child(build_preview)


func _active_build_kind() -> String:
	if energy_build_kind != "":
		return energy_build_kind
	if mine_build_mode:
		return "mine"
	if smelter_build_mode:
		return "smelter"
	if build_mode:
		return "center"
	if forester_build_mode:
		return "forester"
	return ""


func _build_radius(kind: String) -> float:
	match kind:
		"mine":
			return MINE_SCRIPT.CLEARANCE_RADIUS
		"smelter":
			return SMELTER_RADIUS
		"center":
			return TOWN_HALL_RADIUS
		"forester":
			return FORESTER_RADIUS
		"solar":
			return SOLAR_SCRIPT.CLEARANCE_RADIUS
		"battery":
			return BATTERY_SCRIPT.CLEARANCE_RADIUS
	return 0.0


func _mine_resource():
	var resource = get_node_or_null("IronOreDeposit")
	if not is_instance_valid(resource) or resource == null or resource.remaining <= 0 or factory_mine != null:
		return null
	return resource


func _snap_build_point(point: Vector3, kind: String = "") -> Vector3:
	# Kopalnia ma jedyny dozwolony punkt montazu: centrum zloza.
	if kind == "mine":
		var source = _mine_resource()
		if source != null:
			return source.global_position
	var size: float = float(placement_snap_size)
	return Vector3(roundf(point.x / size) * size, 0.0, roundf(point.z / size) * size)


func _rotate_build_preview(backward: bool = false) -> void:
	if _active_build_kind() == "":
		return
	placement_rotation_quarters = posmod(placement_rotation_quarters + (-1 if backward else 1), 4)
	preview_elapsed = 1.0
	_update_build_preview(0.0)


func _cycle_build_snap() -> void:
	if _active_build_kind() == "":
		return
	match placement_snap_size:
		1:
			placement_snap_size = 2
		2:
			placement_snap_size = 4
		_:
			placement_snap_size = 1
	preview_elapsed = 1.0
	_update_build_preview(0.0)


func _apply_build_rotation(building: Node3D) -> void:
	building.rotation.y = float(placement_rotation_quarters) * PI * 0.5


func _build_site_at_mouse(screen_position: Vector2, kind: String) -> Dictionary:
	var ground_hit: Dictionary = _raycast(screen_position, 1)
	if ground_hit.is_empty():
		return {}
	var point: Vector3 = ground_hit["position"]
	var site: Vector3 = _snap_build_point(point, kind)
	if kind == "mine":
		var source = _mine_resource()
		if source == null:
			return {}
		var resource_hit: Dictionary = _raycast(screen_position, 4)
		if resource_hit.has("collider") and resource_hit["collider"] == source:
			site = source.global_position
		elif _ground_distance(point, source.global_position) <= source.clearance_radius:
			site = source.global_position
	return {"site": site}


func _build_grid_cell_free(cell: Vector2i, kind: String = "") -> bool:
	# Ta sama siatka przeszkod, z ktorej korzystaja roboty. Zloze zelaza
	# moze zostac zajete WYLACZNIE przez kopalnie.
	if abs(cell.x) > 43 or abs(cell.y) > 43:
		return false
	var count: int = int(navigation.obstacle_counts.get(cell, 0))
	if kind == "mine":
		var source = _mine_resource()
		if source != null:
			var coords := Vector2(float(cell.x), float(cell.y))
			var ore_center := Vector2(source.global_position.x, source.global_position.z)
			if coords.distance_squared_to(ore_center) <= source.clearance_radius * source.clearance_radius:
				count -= 1
	return count <= 0


func _can_place_structure_at(site: Vector3, kind: String) -> bool:
	var radius: float = _build_radius(kind)
	if radius <= 0.0:
		return false
	if absf(site.x) + radius > 43.0 or absf(site.z) + radius > 43.0:
		return false
	if kind == "mine":
		var source = _mine_resource()
		if source == null or _ground_distance(site, source.global_position) > 0.1:
			return false
	if kind == "smelter" and factory_smelter != null:
		return false
	if kind == "center" and town_hall != null:
		return false
	if kind == "forester" and foresters.size() >= MAX_FORESTERS:
		return false
	if kind == "solar" and solar_arrays.size() >= MAX_SOLAR_ARRAYS:
		return false
	if kind == "battery" and battery_banks.size() >= MAX_BATTERIES:
		return false
	# Badamy caly obrys budynku, nie tylko pole pod kursorem.
	for x in range(floori(site.x - radius), ceili(site.x + radius) + 1):
		for z in range(floori(site.z - radius), ceili(site.z + radius) + 1):
			if Vector2(float(x), float(z)).distance_squared_to(Vector2(site.x, site.z)) <= radius * radius:
				if not _build_grid_cell_free(Vector2i(x, z), kind):
					return false
	# Dodatkowo sprawdzamy realne polozenie budynkow i zrodel
	# (okragi na siatce A* sa dyskretne, wiec moglyby zostawic szczeliny).
	var reserved: Array[Dictionary] = [
		{"node": landing_rocket, "radius": 4.2},
		{"node": charging_pad, "radius": CHARGER_SCRIPT.CLEARANCE_RADIUS},
		{"node": get_node_or_null("Stockpile"), "radius": DEPOT_BLOCK_RADIUS},
		{"node": town_hall, "radius": TOWN_HALL_RADIUS},
		{"node": factory_mine, "radius": MINE_SCRIPT.CLEARANCE_RADIUS},
		{"node": factory_smelter, "radius": SMELTER_RADIUS}
	]
	for hut in foresters:
		reserved.append({"node": hut, "radius": FORESTER_RADIUS})
	for solar in solar_arrays:
		reserved.append({"node": solar, "radius": SOLAR_SCRIPT.CLEARANCE_RADIUS})
	for bank in battery_banks:
		reserved.append({"node": bank, "radius": BATTERY_SCRIPT.CLEARANCE_RADIUS})
	for resource in get_tree().get_nodes_in_group("resource_nodes"):
		if kind == "mine" and resource == _mine_resource():
			continue
		if resource.remaining > 0 or resource.is_sapling:
			reserved.append({"node": resource, "radius": resource.clearance_radius})
	for occupied in reserved:
		var node = occupied["node"]
		if is_instance_valid(node) and node != null:
			if _ground_distance(site, node.global_position) < radius + float(occupied["radius"]) + 0.25:
				return false
	for worker in workers:
		if is_instance_valid(worker) and _ground_distance(site, worker.global_position) < radius + 1.0:
			return false
	return true


func _update_build_preview(delta: float) -> void:
	if build_preview == null:
		return
	var kind: String = _active_build_kind()
	if kind == "":
		build_preview.clear()
		preview_elapsed = 0.0
		return
	preview_elapsed += delta
	if preview_elapsed < 0.12:
		return
	preview_elapsed = 0.0
	var hit: Dictionary = _build_site_at_mouse(get_viewport().get_mouse_position(), kind)
	if hit.is_empty():
		build_preview.clear()
		return
	var site: Vector3 = hit["site"]
	build_preview.update_area(
		site, _build_radius(kind), _can_place_structure_at(site, kind),
		Callable(self, "_build_grid_cell_free").bind(kind),
		kind, placement_rotation_quarters, placement_snap_size
	)


func _cancel_build_modes() -> void:
	placement_rotation_quarters = 0
	energy_build_kind = ""
	_cancel_manual_conveyor()
	build_mode = false
	forester_build_mode = false
	mine_build_mode = false
	smelter_build_mode = false


func _toggle_mine_mode() -> void:
	if mine_build_mode:
		mine_build_mode = false
		_set_status("Anulowano budowe kopalni.")
		return
	_cancel_build_modes()
	if factory_mine != null:
		_set_status("Kopalnia juz istnieje. W tej wersji mozna postawic jedna.")
		return
	if not _can_afford(MINE_COST):
		_set_status("Kopalnia: potrzeba 20 drewna i 10 kamienia.")
		return
	mine_build_mode = true
	_set_status("Wybierz LPM zloze zelaza po prawej stronie mapy, aby postawic kopalnie.")


func _try_place_mine(screen_position: Vector2) -> void:
	var hit: Dictionary = _build_site_at_mouse(screen_position, "mine")
	var source = _mine_resource()
	if hit.is_empty() or source == null or not _can_place_structure_at(hit["site"], "mine"):
		_set_status("Kopalnia wymaga wolnego zloza ZELAZA bez kolizji z innymi budynkami.")
		return
	if not _spend_resources(MINE_COST):
		mine_build_mode = false
		return
	factory_mine = MINE_SCRIPT.new()
	factory_mine.ore_source = source
	factory_mine.position = source.global_position
	_apply_build_rotation(factory_mine)
	add_child(factory_mine)
	_connect_power_node(factory_mine)
	# Zloze zachowuje ilosc surowca, ale wydobywa je tylko ekstraktor.
	source.collision_layer = 0
	source.visible = false
	source.remove_from_group("resource_nodes")
	mine_build_mode = false
	navigation.block_circle(Vector2(source.global_position.x, source.global_position.z), factory_mine.get_access_radius())
	_update_factory_power()
	_update_action_buttons()
	_set_status("Kopalnia uruchomiona! H: postaw hute w poblizu magazynu.")
	_start_logistics_if_ready()


func _toggle_smelter_mode() -> void:
	if smelter_build_mode:
		smelter_build_mode = false
		_set_status("Anulowano budowe huty.")
		return
	_cancel_build_modes()
	if factory_smelter != null:
		_set_status("Huta juz istnieje. W tej wersji mozna postawic jedna.")
		return
	if not _can_afford(SMELTER_COST):
		_set_status("Huta: potrzeba 30 drewna i 20 kamienia.")
		return
	smelter_build_mode = true
	_set_status("Wybierz LPM wolne miejsce na hute (z dala od rakiety i magazynu).")


func _try_place_smelter(screen_position: Vector2) -> void:
	var hit := _raycast(screen_position, 1)
	if hit.is_empty():
		_set_status("Postaw hute na gruncie.")
		return
	var hit_pos: Vector3 = hit["position"]
	var site: Vector3 = _snap_build_point(hit_pos, "smelter")
	if not _is_smelter_site_clear(site):
		_set_status("Huta nie zmiesci sie tutaj: odsun ja od przeszkod.")
		return
	if not _spend_resources(SMELTER_COST):
		smelter_build_mode = false
		return
	factory_smelter = SMELTER_SCRIPT.new()
	factory_smelter.position = site
	_apply_build_rotation(factory_smelter)
	add_child(factory_smelter)
	_connect_power_node(factory_smelter)
	navigation.block_circle(Vector2(site.x, site.z), SMELTER_RADIUS)
	smelter_build_mode = false
	_update_factory_power()
	_update_action_buttons()
	_set_status("Huta gotowa. 2 rudy -> 1 metal. Transport uruchamia sie automatycznie.")
	_start_logistics_if_ready()


func _is_smelter_site_clear(site: Vector3) -> bool:
	return _can_place_structure_at(site, "smelter")


func _connect_power_node(node: Node3D) -> void:
	if not is_instance_valid(landing_rocket):
		return
	var cable = POWER_CABLE_SCRIPT.new()
	cable.setup(LANDER_POSITION, node.global_position)
	add_child(cable)
	power_cables.append(cable)


func _start_energy_build(kind: String) -> void:
	_cancel_build_modes()
	var limit: int = MAX_SOLAR_ARRAYS if kind == "solar" else MAX_BATTERIES
	var current: int = solar_arrays.size() if kind == "solar" else battery_banks.size()
	if current >= limit:
		_set_status("Osiagnieto limit instalacji energetycznych: %d." % limit)
		return
	var cost: Dictionary = SOLAR_ARRAY_COST if kind == "solar" else BATTERY_BANK_COST
	if not _can_afford(cost):
		_set_status("Brak materialow: %d metalu + %d kamienia." % [cost["metal"], cost["stone"]])
		return
	energy_build_kind = kind
	_set_status("LPM: umiesc %s na wolnym terenie. Esc/PPM: anuluj." % ("panel PV" if kind == "solar" else "magazyn energii"))


func _try_place_energy_build(screen_position: Vector2) -> void:
	var hit: Dictionary = _raycast(screen_position, 1)
	if hit.is_empty():
		_set_status("Wybierz wolny grunt.")
		return
	var where: Vector3 = hit["position"]
	var at: Vector3 = _snap_build_point(where, energy_build_kind)
	var kind: String = energy_build_kind
	var radius: float = SOLAR_SCRIPT.CLEARANCE_RADIUS if kind == "solar" else BATTERY_SCRIPT.CLEARANCE_RADIUS
	if not _is_energy_site_clear(at, radius):
		_set_status("Brak miejsca na instalacje. Odsun ja od przeszkod.")
		return
	var cost: Dictionary = SOLAR_ARRAY_COST if kind == "solar" else BATTERY_BANK_COST
	if not _spend_resources(cost):
		_set_status("Brakuje zasobow do budowy.")
		return
	var building = SOLAR_SCRIPT.new() if kind == "solar" else BATTERY_SCRIPT.new()
	building.position = at
	_apply_build_rotation(building)
	add_child(building)
	navigation.block_circle(Vector2(at.x, at.z), radius)
	_connect_power_node(building)
	if kind == "solar":
		solar_arrays.append(building)
	else:
		battery_banks.append(building)
	energy_build_kind = ""
	_update_factory_power()
	_update_action_buttons()
	_set_status("Zainstalowano %s. Przewod podlaczony do sieci statku." % ("panel sloneczny" if kind == "solar" else "akumulator"))


func _is_energy_site_clear(site: Vector3, radius: float) -> bool:
	# Parametr radius zachowany dla kompatybilnosci ze starszym API.
	return _can_place_structure_at(site, energy_build_kind)


func _tick_battery_grid(delta: float) -> void:
	if delta <= 0.0 or battery_banks.is_empty():
		return
	if battery_draw_kw > 0.0:
		var needed_kw: float = battery_draw_kw
		for bank in battery_banks:
			needed_kw -= bank.discharge_kw(needed_kw, delta)
	else:
		var remaining_kw: float = unused_power_kw
		for bank in battery_banks:
			remaining_kw -= bank.charge_kw(remaining_kw, delta)
		unused_power_kw = maxf(0.0, remaining_kw)


func _update_factory_power() -> void:
	if landing_rocket == null or charging_pad == null:
		return

	# Bilans fizyczny: generacja, pobor odbiornikow, zasob w akumulatorze.
	# Odbiorniki maja stale priorytety jak we wczesniejszych wersjach.
	grid_generation_kw = landing_rocket.solar_output()
	for array in solar_arrays:
		grid_generation_kw += array.solar_output()
	var available: float = grid_generation_kw
	for bank in battery_banks:
		if bank.stored_kwh > 0.00001:
			available += minf(bank.MAX_OUTPUT_KW, bank.stored_kwh / (0.25 * bank.GAME_HOURS_PER_SECOND))
	var budget: float = available
	charging_pad.grid_management_enabled = true
	charging_pad.grid_charge_enabled = charging_pad.health > 20.0 and budget + 0.001 >= charging_pad.REQUIRED_POWER
	if charging_pad.grid_charge_enabled:
		budget -= charging_pad.REQUIRED_POWER
	if factory_mine != null:
		factory_mine.power_enabled = budget + 0.001 >= factory_mine.POWER_KW
		if factory_mine.power_enabled:
			budget -= factory_mine.POWER_KW
	if factory_smelter != null:
		factory_smelter.power_enabled = budget + 0.001 >= factory_smelter.POWER_KW
		if factory_smelter.power_enabled:
			budget -= factory_smelter.POWER_KW
	for belt in [ore_conveyor, metal_conveyor]:
		if belt != null:
			belt.powered = budget + 0.001 >= belt.POWER_KW
			if belt.powered:
				budget -= belt.POWER_KW

	grid_consumption_kw = maxf(0.0, available - budget)
	battery_draw_kw = maxf(0.0, grid_consumption_kw - grid_generation_kw)
	unused_power_kw = maxf(0.0, grid_generation_kw - grid_consumption_kw)
	for cable in power_cables:
		if is_instance_valid(cable):
			cable.powered = grid_generation_kw > 0.01 or battery_draw_kw > 0.01



func _start_logistics_if_ready() -> void:
	if factory_mine == null or factory_smelter == null:
		return
	for robot in workers:
		if robot.robot_role == "hauler":
			robot.command_factory_route(factory_mine, factory_smelter, navigation, DEPOT_POSITION)
			_set_status("Automatyka: transportowiec odbiera rude, wiezie do huty i dostarcza metal.")
			return


func _assign_factory_haulers(robots: Array) -> void:
	if factory_mine == null or factory_smelter == null:
		_set_status("Najpierw postaw kopalnie (M) i hute (H).")
		return
	var assigned: int = 0
	for robot in robots:
		if robot.robot_role == "hauler":
			robot.command_factory_route(factory_mine, factory_smelter, navigation, DEPOT_POSITION)
			assigned += 1
	_set_status("Transport przydzielony: %d robot(ow). PPM na ziemi przerywa zadanie." % assigned)


func _start_manual_conveyor(kind: String) -> void:
	if factory_mine == null or factory_smelter == null:
		_set_status("Zbuduj najpierw kopalnie (M) i hute (H).")
		return
	if (kind == "ore" and ore_conveyor != null) or (kind == "metal" and metal_conveyor != null):
		_set_status("To polaczenie jest juz zbudowane.")
		return
	var cost: Dictionary = ORE_CONVEYOR_COST if kind == "ore" else METAL_CONVEYOR_COST
	if not _can_afford(cost):
		_set_status("Brakuje metalu. Potrzeba %d sztabek." % int(cost["metal"]))
		return
	_cancel_build_modes()
	manual_conveyor_kind = kind
	manual_conveyor_points.clear()
	_set_status("RECZNA TRASA %s: LPM dodaje punkty, Enter buduje, PPM/Esc anuluje." % kind.to_upper())


func _manual_conveyor_click(mouse_position: Vector2) -> void:
	if manual_conveyor_points.size() >= 12:
		_set_status("Maksymalnie 12 punktow pomocniczych. Enter zatwierdzi trase.")
		return
	var ground_hit: Dictionary = _raycast(mouse_position, 1)
	if ground_hit.is_empty():
		_set_status("Wybierz punkt na terenie.")
		return
	var place: Vector3 = ground_hit["position"]
	var waypoint := Vector3(roundf(place.x), 0.0, roundf(place.z))
	if not navigation.is_circle_walkable(Vector2(waypoint.x, waypoint.z), 0.35):
		_set_status("Punkt znajduje sie w przeszkodzie. Wybierz wolny teren.")
		return
	manual_conveyor_points.append(waypoint)
	if not _refresh_manual_preview():
		manual_conveyor_points.pop_back()
		_refresh_manual_preview()
		_set_status("Brak ciaglej trasy przez ten punkt. Sprobuj innego.")
		return
	_set_status("Dodano punkt %d. LPM dodaje kolejny; Enter buduje trase." % manual_conveyor_points.size())


func _compute_conveyor_route(kind: String, waypoints: Array[Vector3] = []) -> Array[Vector3]:
	var source_position: Vector3 = factory_mine.global_position if kind == "ore" else factory_smelter.global_position
	var target_position: Vector3 = factory_smelter.global_position if kind == "ore" else DEPOT_POSITION
	var source_radius: float = factory_mine.get_access_radius() if kind == "ore" else factory_smelter.get_access_radius()
	var target_radius: float = factory_smelter.get_access_radius() if kind == "ore" else DEPOT_BLOCK_RADIUS
	return navigation.find_conveyor_route_via(source_position, source_radius, target_position, target_radius, waypoints)


func _refresh_manual_preview() -> bool:
	if is_instance_valid(manual_conveyor_preview):
		manual_conveyor_preview.queue_free()
	manual_conveyor_preview = null
	if manual_conveyor_kind == "":
		return false
	var route: Array[Vector3] = _compute_conveyor_route(manual_conveyor_kind, manual_conveyor_points)
	if route.size() < 2 or route.size() > 95:
		return false
	manual_conveyor_preview = CONVEYOR_SCRIPT.new()
	manual_conveyor_preview.preview_mode = true
	manual_conveyor_preview.setup(manual_conveyor_kind,
		factory_mine if manual_conveyor_kind == "ore" else factory_smelter,
		factory_smelter if manual_conveyor_kind == "ore" else get_node("Stockpile"), route)
	add_child(manual_conveyor_preview)
	return true


func _confirm_manual_conveyor() -> void:
	if manual_conveyor_kind == "":
		return
	var kind: String = manual_conveyor_kind
	_build_conveyor(kind, manual_conveyor_points)


func _cancel_manual_conveyor() -> void:
	if is_instance_valid(manual_conveyor_preview):
		manual_conveyor_preview.queue_free()
	manual_conveyor_preview = null
	manual_conveyor_kind = ""
	manual_conveyor_points.clear()


func _build_ore_conveyor() -> void:
	_build_conveyor("ore")


func _build_metal_conveyor() -> void:
	_build_conveyor("metal")


func _build_conveyor(kind: String, waypoints: Array[Vector3] = []) -> void:
	if factory_mine == null or factory_smelter == null:
		_set_status("Najpierw zbuduj kopalnie (M) i hute (H).")
		return
	if kind == "ore" and ore_conveyor != null:
		_set_status("Tasmociag rudy juz jest polaczony.")
		return
	if kind == "metal" and metal_conveyor != null:
		_set_status("Tasmociag metalu juz jest polaczony.")
		return

	var cost: Dictionary = ORE_CONVEYOR_COST if kind == "ore" else METAL_CONVEYOR_COST
	if not _can_afford(cost):
		_set_status("Potrzeba %d metalu z huty, aby zbudowac tasme." % int(cost["metal"]))
		return

	var route: Array[Vector3] = _compute_conveyor_route(kind, waypoints)
	if route.size() < 2:
		_set_status("Nie mozna poprowadzic tasmy. Postaw budynki w dostepnej okolicy.")
		return
	if route.size() > 95:
		_set_status("Ta wersja obsluguje tasmociagi do 95 segmentow.")
		return
	if not _spend_resources(cost):
		return
	_cancel_manual_conveyor()

	var link = CONVEYOR_SCRIPT.new()
	link.setup(kind, factory_mine if kind == "ore" else factory_smelter,
		factory_smelter if kind == "ore" else get_node("Stockpile"), route)
	add_child(link)
	if kind == "ore":
		ore_conveyor = link
	else:
		metal_conveyor = link
		link.cargo_delivered.connect(_on_conveyor_delivered)
	_update_factory_power()
	_sync_factory_haulers()
	_update_action_buttons()
	_set_status("Podlaczono %s. Obserwuj przesuwajace sie paczki i prace robotow." % (
		"rude z kopalni do huty" if kind == "ore" else "metal z huty do magazynu"
	))


func _on_conveyor_delivered(resource_type: String, amount: int) -> void:
	_on_resource_delivered(resource_type, amount)


func _sync_factory_haulers() -> void:
	for robot in workers:
		if robot.robot_role == "hauler":
			robot.set_factory_belts(ore_conveyor != null, metal_conveyor != null)


func _on_resource_depleted(resource, clearance_radius: float) -> void:
	var p: Vector3 = resource.global_position
	navigation.unblock_circle(Vector2(p.x, p.z), clearance_radius)
	# Martwe drzewa / puste zloza nie musza zostawac w drzewie sceny.
	resource.queue_free()


func _create_workers() -> void:
	# Wylot ze statku w strone kamery RTS. Jednostki ukazuja sie kolejno.
	var robot_roles: Array[String] = ["miner", "hauler", "engineer"]
	var rally: Array[Vector3] = [
		Vector3(-4.0, 0.0, -2.0),
		Vector3(0.0, 0.0, -3.0),
		Vector3(4.0, 0.0, -2.0)
	]
	for i in range(3):
		var start := LANDER_POSITION + Vector3(float(i - 1) * 0.7, 0.0, 4.7)
		var worker = _spawn_worker(start, robot_roles[i])
		worker.visible = false
		worker.set_physics_process(false)
		get_tree().create_timer(0.7 + float(i) * 0.9).timeout.connect(
			_launch_starting_robot.bind(worker, rally[i])
		)


func _launch_starting_robot(worker, destination: Vector3) -> void:
	if not is_instance_valid(worker):
		return
	worker.visible = true
	worker.set_physics_process(true)
	var path: Array[Vector3] = navigation.find_path(worker.global_position, destination)
	if not path.is_empty():
		worker.command_move(path)
	_announce_new_worker(worker)


func _spawn_worker(at_position: Vector3, role: String = "miner"):
	var worker = WORKER_SCRIPT.new()
	worker.name = "Robot%d_%s" % [workers.size() + 1, role]
	worker.robot_role = role
	worker.charging_station = charging_pad
	worker.navigation_grid = navigation
	worker.position = at_position
	add_child(worker)
	worker.resource_delivered.connect(_on_resource_delivered)
	workers.append(worker)
	return worker


func _announce_new_worker(worker) -> void:
	var marker := Label3D.new()
	marker.text = worker.role_name()
	marker.position.y = 2.5
	marker.font_size = 55
	marker.pixel_size = 0.007
	marker.modulate = Color(1.0, 0.95, 0.25)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	worker.add_child(marker)
	var anim := create_tween()
	anim.tween_property(marker, "position:y", 4.0, 2.8)
	anim.tween_callback(marker.queue_free)


func _create_camera() -> void:
	var camera_rig = CAMERA_SCRIPT.new()
	camera_rig.name = "RTSCameraRig"
	camera_rig.position = Vector3(0.0, 0.0, 0.0)
	add_child(camera_rig)


func _create_hud() -> void:
	hud = HUD_SCRIPT.new()
	hud.name = "ColonyHUD"
	hud.build_center_requested.connect(_toggle_build_mode)
	hud.build_forester_requested.connect(_toggle_forester_mode)
	hud.train_robot_requested.connect(_train_worker)
	hud.charge_requested.connect(_charge_selected)
	hud.mine_requested.connect(_toggle_mine_mode)
	hud.smelter_requested.connect(_toggle_smelter_mode)
	hud.ore_conveyor_requested.connect(_build_ore_conveyor)
	hud.metal_conveyor_requested.connect(_build_metal_conveyor)
	hud.solar_array_requested.connect(_start_energy_build.bind("solar"))
	hud.battery_bank_requested.connect(_start_energy_build.bind("battery"))
	hud.planet_change_requested.connect(_cycle_planet)
	add_child(hud)

	selection_box = SELECTION_BOX_SCRIPT.new()
	selection_box.name = "SelectionBox"
	hud.add_selection_overlay(selection_box)

	_set_status("Trzy roboty opuscily rakiete. Zacznij od wydobycia i naprawy paneli.")
	_update_action_buttons()
	_update_resource_hud()
	hud.set_planet(START_PLANET)
	_update_colony_hud()


func _process(delta: float) -> void:
	_update_build_preview(delta)
	hud_elapsed += delta
	if hud_elapsed >= 0.25:
		var elapsed_energy: float = hud_elapsed
		hud_elapsed = 0.0
		_update_factory_power()
		_tick_battery_grid(elapsed_energy)
		_update_colony_hud()


func _update_colony_hud() -> void:
	if hud == null:
		return
	if landing_rocket != null and charging_pad != null:
		hud.set_power(grid_generation_kw, charging_pad.can_charge())
		hud.set_power_balance(unused_power_kw)
		var stored_kwh: float = 0.0
		for bank in battery_banks:
			stored_kwh += bank.stored_kwh
		hud.set_energy_storage(stored_kwh, float(battery_banks.size()) * BATTERY_SCRIPT.CAPACITY_KWH, grid_generation_kw)

	if selected_workers.size() == 1:
		var robot = selected_workers[0]
		hud.set_robot(robot.role_name(), robot.status_text(), robot.energy, robot.carried_amount)
	elif selected_workers.size() > 1:
		hud.set_robot_group(selected_workers.size())
	elif is_instance_valid(selected_structure) and selected_structure != null:
		if selected_structure == landing_rocket:
			hud.set_structure("RAKIETA KOLONIJNA", "Produkcja PV: %.1f kW" % landing_rocket.solar_output(), landing_rocket.health)
		elif selected_structure == charging_pad:
			hud.set_structure("STACJA LADOWANIA", "Moc: %s" % ("dostepna" if charging_pad.can_charge() else "brak"), charging_pad.health)
		elif selected_structure == town_hall:
			hud.set_structure("CENTRUM DOWODZENIA", "Produkcja robotow: klawisz T.")
		elif selected_structure in foresters:
			hud.set_structure("MODUL REKULTYWACJI", "Odnawianie drzew: cykl 8 sekund.")
		elif selected_structure == factory_mine:
			hud.set_structure("KOPALNIA ZELAZA", factory_mine.describe() + (" | TASMA RUDA" if ore_conveyor != null else ""))
		elif selected_structure == factory_smelter:
			hud.set_structure("HUTA METALU", factory_smelter.describe() + (" | TASMA METAL" if metal_conveyor != null else ""))
		elif selected_structure in solar_arrays:
			hud.set_structure("PANEL SLONECZNY", selected_structure.describe())
		elif selected_structure in battery_banks:
			hud.set_structure("MAGAZYN ENERGII", selected_structure.describe())
		else:
			hud.set_no_selection()
	else:
		hud.set_no_selection()


func _charge_selected() -> void:
	if selected_workers.is_empty():
		_set_status("Wybierz co najmniej jednego robota.")
		return
	for robot in selected_workers:
		robot.command_charge()
	_set_status("Rozkaz: wybrane roboty jada do stacji ladowania.")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and _active_build_kind() != "":
			_rotate_build_preview(event.shift_pressed)
			return
		if event.keycode == KEY_G and _active_build_kind() != "":
			_cycle_build_snap()
			return
		if event.keycode == KEY_B:
			_toggle_build_mode()
			return
		if event.keycode == KEY_T:
			_train_worker()
			return
		if event.keycode == KEY_L:
			_toggle_forester_mode()
			return
		if event.keycode == KEY_C:
			_charge_selected()
			return
		if event.keycode == KEY_P:
			_cycle_planet()
			return
		if event.keycode == KEY_M:
			_toggle_mine_mode()
			return
		if event.keycode == KEY_H:
			_toggle_smelter_mode()
			return
		if event.keycode == KEY_J:
			if event.shift_pressed:
				_start_manual_conveyor("ore")
			else:
				_build_ore_conveyor()
			return
		if event.keycode == KEY_N:
			if event.shift_pressed:
				_start_manual_conveyor("metal")
			else:
				_build_metal_conveyor()
			return
		if event.keycode == KEY_V:
			_start_energy_build("solar")
			return
		if event.keycode == KEY_K:
			_start_energy_build("battery")
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if manual_conveyor_kind != "":
				_confirm_manual_conveyor()
				return
		if event.keycode == KEY_ESCAPE and energy_build_kind != "":
			energy_build_kind = ""
			_set_status("Anulowano budowe instalacji energetycznej.")
			return
		if event.keycode == KEY_ESCAPE and manual_conveyor_kind != "":
			_cancel_manual_conveyor()
			_set_status("Anulowano reczne ukladanie tasmy.")
			return
		if event.keycode == KEY_ESCAPE and (build_mode or forester_build_mode or mine_build_mode or smelter_build_mode):
			_cancel_build_modes()
			_set_status("Anulowano budowe.")
			return

	if event is InputEventMouseMotion and mouse_down:
		var distance := drag_start.distance_to(event.position)
		if distance >= 8.0:
			is_dragging = true
		if is_dragging:
			selection_box.show_selection(drag_start, event.position)
		return

	if not (event is InputEventMouseButton):
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if energy_build_kind != "":
			if event.pressed:
				_try_place_energy_build(event.position)
			return
		if manual_conveyor_kind != "":
			if event.pressed:
				_manual_conveyor_click(event.position)
			return
		if mine_build_mode:
			if event.pressed:
				_try_place_mine(event.position)
			return
		if smelter_build_mode:
			if event.pressed:
				_try_place_smelter(event.position)
			return
		if forester_build_mode:
			if event.pressed:
				_try_place_forester(event.position)
			return
		if build_mode:
			if event.pressed:
				_try_place_town_hall(event.position)
			return
		if event.pressed:
			mouse_down = true
			is_dragging = false
			drag_start = event.position
		elif mouse_down:
			mouse_down = false
			selection_box.hide_selection()
			if is_dragging:
				_select_in_rectangle(Rect2(drag_start, event.position - drag_start).abs(), event.shift_pressed)
			else:
				_select_by_click(event.position, event.shift_pressed)
			is_dragging = false

	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if energy_build_kind != "":
			energy_build_kind = ""
			_set_status("Anulowano budowe instalacji energetycznej.")
			return
		if manual_conveyor_kind != "":
			_cancel_manual_conveyor()
			_set_status("Anulowano reczne ukladanie tasmy.")
			return
		if build_mode or forester_build_mode or mine_build_mode or smelter_build_mode:
			_cancel_build_modes()
			_set_status("Anulowano budowe.")
		else:
			_command_move_selected(event.position)


func _select_by_click(screen_position: Vector2, additive: bool) -> void:
	var hit := _raycast(screen_position, 2)
	if not additive:
		_clear_selection()
	if hit.has("collider") and hit["collider"] in workers:
		_select_worker(hit["collider"])
		return

	var building_hit := _raycast(screen_position, 8)
	if building_hit.has("collider"):
		var structure = building_hit["collider"]
		if structure == landing_rocket or structure == charging_pad or structure == town_hall or structure in foresters or structure == factory_mine or structure == factory_smelter or structure in solar_arrays or structure in battery_banks:
			selected_structure = structure
			if structure == town_hall:
				_set_status("Centrum: T szkoli kolejnego gornika.")
			elif structure in foresters:
				_set_status("Modul rekultywacji automatycznie sadzi nowe drzewa.")
			elif structure == landing_rocket:
				_set_status("Wybierz technika i kliknij PPM na rakiecie, aby ja naprawic.")
			elif structure == charging_pad:
				_set_status("Ladowarka: C wysyla zaznaczone roboty do ladowania.")
			elif structure == factory_mine:
				_set_status("Kopalnia: %s" % factory_mine.describe())
			elif structure == factory_smelter:
				_set_status("Huta: %s" % factory_smelter.describe())
			elif structure in solar_arrays or structure in battery_banks:
				_set_status(structure.describe())


func _select_in_rectangle(rectangle: Rect2, additive: bool) -> void:
	if not additive:
		_clear_selection()
	var active_camera := get_viewport().get_camera_3d()
	if active_camera == null:
		return
	for worker in workers:
		var point: Vector3 = worker.global_position + Vector3(0.0, 0.9, 0.0)
		if active_camera.is_position_behind(point):
			continue
		var projected: Vector2 = active_camera.unproject_position(point)
		if rectangle.has_point(projected):
			_select_worker(worker)


func _command_move_selected(screen_position: Vector2) -> void:
	if selected_workers.is_empty():
		return

	var resource_hit := _raycast(screen_position, 4)
	if resource_hit.has("collider"):
		var clicked_object = resource_hit["collider"]
		if clicked_object == factory_mine or clicked_object == factory_smelter:
			_assign_factory_haulers(selected_workers)
			return
		if clicked_object.has_method("harvest") and clicked_object.resource_type == "iron_ore":
			_set_status("Ruda zelaza wymaga kopalni: M, a potem LPM na zlozu.")
			return
		if clicked_object.has_method("harvest"):
			for worker in selected_workers:
				if worker.robot_role != "engineer":
					worker.command_gather(clicked_object, navigation, DEPOT_POSITION)
			_set_status("Roboty wydobywcze i transportowe zbieraja surowce.")
			return
		if clicked_object == charging_pad:
			for worker in selected_workers:
				if worker.robot_role == "engineer" and charging_pad.needs_repair():
					worker.command_repair(charging_pad, navigation)
				else:
					worker.command_charge()
			_set_status("Ladowarka: uzupelnianie energii / naprawa.")
			return
		if clicked_object.has_method("repair"):
			var engineers: int = 0
			for worker in selected_workers:
				if worker.robot_role == "engineer":
					worker.command_repair(clicked_object, navigation)
					engineers += 1
			if engineers > 0:
				_set_status("Technik jedzie naprawic instalacje.")
			else:
				_set_status("Naprawy wymaga robota technicznego (zolty).")
			return

	var hit := _raycast(screen_position, 1)
	if hit.is_empty():
		return
	var target: Vector3 = hit["position"]
	for i in range(selected_workers.size()):
		var column := float(i % 3)
		var row := float(floori(float(i) / 3.0))
		var offset := Vector3((column - 1.0) * 1.8, 0.0, row * 1.8)
		var worker = selected_workers[i]
		var path: Array[Vector3] = navigation.find_path(worker.global_position, target + offset)
		if not path.is_empty():
			worker.command_move(path)


func _raycast(screen_position: Vector2, mask: int) -> Dictionary:
	var active_camera := get_viewport().get_camera_3d()
	if active_camera == null:
		return {}
	var origin := active_camera.project_ray_origin(screen_position)
	var end := origin + active_camera.project_ray_normal(screen_position) * 500.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, mask)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _clear_selection() -> void:
	for worker in selected_workers:
		worker.set_selected(false)
	selected_workers.clear()
	selected_structure = null
	_update_action_buttons()


func _select_worker(worker: CharacterBody3D) -> void:
	if worker in selected_workers:
		return
	selected_workers.append(worker)
	selected_structure = null
	worker.set_selected(true)
	_update_action_buttons()


func _create_training_timer() -> void:
	training_timer = Timer.new()
	training_timer.name = "WorkerTraining"
	training_timer.one_shot = true
	training_timer.wait_time = 4.0
	training_timer.timeout.connect(_finish_training)
	add_child(training_timer)


func _toggle_build_mode() -> void:
	var was_active: bool = build_mode
	_cancel_build_modes()
	if was_active:
		_set_status("Anulowano budowe centrum.")
		return
	if town_hall != null:
		_set_status("Centrum dowodzenia juz istnieje. Mozesz produkowac roboty.")
		return
	if build_mode:
		build_mode = false
		_set_status("Anulowano budowe.")
		return
	if not _can_afford(TOWN_HALL_COST):
		_set_status("Brakuje surowcow: centrum wymaga 40 drewna i 20 kamienia.")
		return
	build_mode = true
	_set_status("Wybierz LPM miejsce na centrum; PPM lub Esc anuluje.")


func _try_place_town_hall(screen_position: Vector2) -> void:
	var hit := _raycast(screen_position, 1)
	if hit.is_empty():
		_set_status("Wskaz teren na mapie, aby zbudowac ratusz.")
		return
	var point: Vector3 = hit["position"]
	var site: Vector3 = _snap_build_point(point, "center")
	if not _is_build_site_clear(site):
		_set_status("Brak miejsca: odsun ratusz od jednostek, magazynu i zloz.")
		return
	if not _spend_resources(TOWN_HALL_COST):
		build_mode = false
		_set_status("Nie masz juz wystarczajacych surowcow.")
		return

	town_hall = TOWN_HALL_SCRIPT.new()
	town_hall.position = site
	_apply_build_rotation(town_hall)
	add_child(town_hall)
	navigation.block_circle(Vector2(site.x, site.z), TOWN_HALL_RADIUS)
	build_mode = false
	_set_status("Centrum gotowe! Mozesz produkowac roboty gornicze (T).")
	_update_action_buttons()


func _is_build_site_clear(site: Vector3) -> bool:
	return _can_place_structure_at(site, "center")


func _ground_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _toggle_forester_mode() -> void:
	var was_active: bool = forester_build_mode
	_cancel_build_modes()
	if was_active:
		_set_status("Anulowano budowe lesniczowki.")
		return
	if foresters.size() >= MAX_FORESTERS:
		_set_status("Limit lesniczowek na mapie: %d." % MAX_FORESTERS)
		return
	if not _can_afford(FORESTER_COST):
		_set_status("Brakuje surowcow: lesniczowka kosztuje 30 drewna i 10 kamienia.")
		return
	forester_build_mode = true
	_set_status("LPM: wybierz miejsce na lesniczowke. Esc lub PPM: anuluj.")


func _try_place_forester(screen_position: Vector2) -> void:
	var hit := _raycast(screen_position, 1)
	if hit.is_empty():
		_set_status("Kliknij wolny teren na mapie.")
		return
	var location: Vector3 = hit["position"]
	var site: Vector3 = _snap_build_point(location, "forester")
	if not _is_forester_site_clear(site):
		_set_status("Brak miejsca na lesniczowke. Wybierz inne miejsce.")
		return
	if not _spend_resources(FORESTER_COST):
		forester_build_mode = false
		_set_status("Brakuje surowcow do budowy.")
		return
	var hut = FORESTER_SCRIPT.new()
	hut.position = site
	_apply_build_rotation(hut)
	hut.plant_requested.connect(_on_forester_plant_request)
	add_child(hut)
	foresters.append(hut)
	navigation.block_circle(Vector2(site.x, site.z), FORESTER_RADIUS)
	forester_build_mode = false
	_set_status("Lesniczowka gotowa! Co 8 s szuka miejsca na sadzonke.")
	_update_action_buttons()


func _is_forester_site_clear(site: Vector3) -> bool:
	return _can_place_structure_at(site, "forester")


func _on_forester_plant_request(hut) -> void:
	if not is_instance_valid(hut):
		return
	var occupied_trees: int = 0
	for source in get_tree().get_nodes_in_group("resource_nodes"):
		if source.resource_type == "wood" and (source.remaining > 0 or source.is_sapling):
			if _ground_distance(source.global_position, hut.global_position) <= 17.0:
				occupied_trees += 1
	if occupied_trees >= 12:
		return

	var rings: Array[float] = [6.0, 8.0, 10.0, 12.0, 14.0, 16.0]
	for attempt in range(48):
		var angle: float = TAU * float((attempt * 7 + hut.plant_attempts * 11) % 48) / 48.0
		var distance: float = rings[(attempt + hut.plant_attempts) % rings.size()]
		var planting_site := Vector2(
			roundf(hut.global_position.x + cos(angle) * distance),
			roundf(hut.global_position.z + sin(angle) * distance)
		)
		if _is_tree_planting_site_clear(planting_site, hut):
			var forest: Node3D = get_node("Forest") as Node3D
			_add_tree(forest, planting_site, true)
			return


func _is_tree_planting_site_clear(spot: Vector2, hut: StaticBody3D) -> bool:
	var location := Vector3(spot.x, 0.0, spot.y)
	if absf(spot.x) > 45.0 or absf(spot.y) > 45.0:
		return false
	if _ground_distance(location, hut.global_position) > 17.0:
		return false
	if not navigation.is_circle_walkable(spot, 1.8):
		return false
	if _ground_distance(location, DEPOT_POSITION) < DEPOT_BLOCK_RADIUS + 2.8:
		return false
	if _ground_distance(location, LANDER_POSITION) < 6.6:
		return false
	if _ground_distance(location, CHARGER_POSITION) < 4.5:
		return false
	if town_hall != null and _ground_distance(location, town_hall.global_position) < TOWN_HALL_RADIUS + 2.8:
		return false
	for house in foresters:
		if _ground_distance(location, house.global_position) < FORESTER_RADIUS + 2.8:
			return false
	for source in get_tree().get_nodes_in_group("resource_nodes"):
		if source.remaining > 0 or source.is_sapling:
			if _ground_distance(location, source.global_position) < source.clearance_radius + 2.4:
				return false
	for worker in workers:
		if _ground_distance(location, worker.global_position) < 1.8:
			return false
	return true


func _train_worker() -> void:
	if town_hall == null:
		_set_status("Najpierw zbuduj ratusz (B).")
		return
	if training_in_progress:
		_set_status("Trwa szkolenie robotnika, zaczekaj chwile.")
		return
	if workers.size() >= MAX_WORKERS:
		_set_status("Osiagnieto limit %d robotnikow." % MAX_WORKERS)
		return
	if not _spend_resources(WORKER_COST):
		_set_status("Brakuje surowcow: robotnik kosztuje 10 drewna i 20 zlota.")
		return
	training_in_progress = true
	training_timer.start()
	_set_status("Trwa szkolenie robotnika (4 sekundy).")
	_update_action_buttons()


func _finish_training() -> void:
	training_in_progress = false
	var camera := get_viewport().get_camera_3d()
	var camera_position: Vector3 = town_hall.global_position + Vector3(0.0, 20.0, 20.0)
	if camera != null:
		camera_position = camera.global_position
	var occupied: Array[Vector3] = []
	for existing_worker in workers:
		occupied.append(existing_worker.global_position)
	var spawn_position = navigation.find_free_spawn_near(town_hall.global_position, camera_position, occupied)
	if spawn_position == null:
		_refund_resources(WORKER_COST)
		_set_status("Brak wolnego miejsca na robotnika. Zasoby zwrocone.")
		_update_action_buttons()
		return
	var worker = _spawn_worker(spawn_position)
	_announce_new_worker(worker)
	_update_resource_hud()
	_set_status("Nowy robotnik gotowy przed ratuszem. Liczba robotnikow: %d." % workers.size())
	_update_action_buttons()


func _can_afford(cost: Dictionary) -> bool:
	for resource_type in cost.keys():
		if int(resource_totals.get(resource_type, 0)) < int(cost[resource_type]):
			return false
	return true


func _spend_resources(cost: Dictionary) -> bool:
	if not _can_afford(cost):
		return false
	for resource_type in cost.keys():
		resource_totals[resource_type] = int(resource_totals[resource_type]) - int(cost[resource_type])
	_update_resource_hud()
	return true


func _refund_resources(cost: Dictionary) -> void:
	for resource_type in cost.keys():
		resource_totals[resource_type] = int(resource_totals[resource_type]) + int(cost[resource_type])
	_update_resource_hud()


func _set_status(message: String) -> void:
	if hud != null:
		hud.set_status(message)


func _update_action_buttons() -> void:
	if hud != null:
		hud.set_action_availability(
			town_hall != null,
			workers.size() >= MAX_WORKERS,
			training_in_progress,
			foresters.size() >= MAX_FORESTERS,
			not selected_workers.is_empty()
		)
		hud.set_factory_availability(factory_mine != null, factory_smelter != null)
		hud.set_conveyor_availability(ore_conveyor != null, metal_conveyor != null, factory_mine != null and factory_smelter != null)
		hud.set_energy_build_availability(solar_arrays.size(), MAX_SOLAR_ARRAYS, battery_banks.size(), MAX_BATTERIES)


func _on_resource_delivered(resource_type: String, amount: int) -> void:
	if not resource_totals.has(resource_type):
		return
	resource_totals[resource_type] = int(resource_totals[resource_type]) + amount
	_update_resource_hud()


func _update_resource_hud() -> void:
	if hud == null:
		return
	hud.set_resources(
		int(resource_totals["wood"]),
		int(resource_totals["gold"]),
		int(resource_totals["stone"]),
		int(resource_totals["metal"]),
		workers.size(),
		MAX_WORKERS
	)


func _make_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.92
	return material
