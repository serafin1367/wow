extends StaticBody3D
## WOW 0.2: modularna rakieta kolonizacyjna w stylu przemyslowego low-poly.
## Sylwetka klasycznej rakiety wielostopniowej: smukly kadlub, dwa boostery,
## stozkowa owiewka, stopnie rakietowe, dysze, rozkladane kompaktowe panele PV.
## Paleta zgodna z pomaranczowym robotem gorniczym: grafit/stal/oranz/turkus.

signal health_changed(current_health: float, maximum_health: float)

const CLEARANCE_RADIUS: float = 4.2
const MAX_HEALTH: float = 100.0
const NOMINAL_SOLAR_POWER: float = 12.0

var health: float = 70.0
var info: Label3D


func _ready() -> void:
	name = "LandingRocket"
	collision_layer = 4 | 8
	collision_mask = 0

	var graphite := _material(Color(0.105, 0.15, 0.20))
	var graphite_light := _material(Color(0.18, 0.24, 0.30))
	var steel := _material(Color(0.51, 0.58, 0.59))
	var steel_light := _material(Color(0.74, 0.79, 0.78))
	var orange := _material(Color(0.96, 0.46, 0.11))
	var orange_light := _material(Color(1.0, 0.67, 0.22))
	var solar := _material(Color(0.055, 0.20, 0.34))
	var light_cyan := _material(Color(0.22, 0.91, 0.99), true)

	# CENTRALNY KADLUB: dwa widoczne stopnie i ruchome jak w KSP sekcje.
	_add_cylinder("EngineHousing", Vector3(0, 1.15, 0), 1.18, 1.9, graphite)
	_add_cylinder("MainTankLower", Vector3(0, 4.4, 0), 1.13, 5.15, steel_light)
	_add_cylinder("LowerTankGuard", Vector3(0, 3.2, 0), 1.17, 0.45, graphite_light)
	_add_cylinder("LowerOrangeBand", Vector3(0, 5.45, 0), 1.19, 0.38, orange)
	_add_cylinder("StageDecoupler", Vector3(0, 7.18, 0), 1.28, 0.56, graphite)
	_add_cylinder("StageOrangeClamps", Vector3(0, 7.2, 0), 1.31, 0.15, orange)
	_add_cylinder("UpperTank", Vector3(0, 10.38, 0), 1.03, 5.95, steel)
	_add_cylinder("UpperTankBand", Vector3(0, 11.35, 0), 1.09, 0.33, graphite)
	_add_cylinder("UpperOrangeTrim", Vector3(0, 12.85, 0), 1.08, 0.24, orange)
	_add_cylinder("NoseBase", Vector3(0, 13.61, 0), 1.07, 0.48, graphite)
	_add_cone("PayloadFairing", Vector3(0, 15.18, 0), 2.75, 1.02, 0.05, steel_light)
	_add_cone("OrangeNoseTip", Vector3(0, 16.60, 0), 0.54, 0.22, 0.015, orange)

	# Techniczne panele na glownym zbiorniku, z przodu (+Z) widocznym dla kamery.
	_add_box("ControlPanel", Vector3(0, 9.23, 1.065), Vector3(0.82, 0.58, 0.08), graphite)
	_add_box("ControlDisplay", Vector3(0, 9.28, 1.12), Vector3(0.48, 0.14, 0.05), light_cyan)
	for y in [3.85, 4.45, 5.05, 8.50, 9.95, 10.50]:
		_add_box("ServiceStripe", Vector3(0, y, 1.148 if y < 6.0 else 1.049), Vector3(0.78, 0.095, 0.055), graphite_light)
	_add_box("MainHullMarking", Vector3(0, 5.84, 1.14), Vector3(0.72, 0.22, 0.08), orange)
	_add_box("UpperHullMarking", Vector3(0, 11.95, 1.06), Vector3(0.82, 0.18, 0.07), orange)

	# DWA BOCZNE BOOSTERY / ZBIORNIKI POMOCNICZE.
	for side in [-1.0, 1.0]:
		var bx: float = side * 2.12
		_add_cylinder("BoosterHull", Vector3(bx, 4.43, 0), 0.73, 6.45, steel)
		_add_cylinder("BoosterEngineMount", Vector3(bx, 0.92, 0), 0.79, 0.95, graphite)
		_add_cylinder("BoosterOrangeBandLower", Vector3(bx, 2.7, 0), 0.78, 0.28, orange)
		_add_cylinder("BoosterOrangeBandUpper", Vector3(bx, 6.52, 0), 0.78, 0.24, orange)
		_add_cone("BoosterFairing", Vector3(bx, 8.43, 0), 1.70, 0.74, 0.02, steel_light)
		_add_cylinder("BoosterNoseBand", Vector3(bx, 7.61, 0), 0.78, 0.19, graphite)
		_add_cone("BoosterNoseTip", Vector3(bx, 9.26, 0), 0.25, 0.14, 0.015, orange)

		# Widoczne mocowania zbiornikow do glownego kadluba.
		for by in [2.45, 6.50]:
			_add_box("BoosterTruss", Vector3(side * 1.50, by, 0), Vector3(1.1, 0.24, 0.45), graphite)
			_add_box("BoosterClamp", Vector3(side * 1.99, by, 0.43), Vector3(0.34, 0.38, 0.10), orange)
		_add_cone("BoosterNozzle", Vector3(bx, 0.36, 0), 0.66, 0.42, 0.64, graphite_light)
		_add_cylinder("BoosterThroat", Vector3(bx, 0.21, 0), 0.32, 0.12, orange_light)
		_add_box("Fin", Vector3(side * 2.82, 1.15, -0.25), Vector3(0.7, 1.4, 0.3), orange)
		_add_box("FinRib", Vector3(side * 2.85, 1.25, -0.06), Vector3(0.17, 0.80, 0.10), graphite)

		# Podpory ladowania rozstawione szerzej niz stopien glowny.
		_add_box("LandingStrut", Vector3(side * 3.38, 0.95, 0), Vector3(0.20, 1.55, 0.22), graphite, Vector3(0, 0, side * 12.0))
		_add_box("LandingFoot", Vector3(side * 3.53, 0.16, 0), Vector3(1.08, 0.26, 1.15), graphite_light)
		_add_box("LandingOrangeSafety", Vector3(side * 3.52, 0.31, 0.52), Vector3(0.86, 0.08, 0.11), orange)

	# Glowny zespol trzech dysz wylotowych.
	for ex in [-0.53, 0.53]:
		_add_cone("MainEngineBell", Vector3(ex, 0.44, 0.40), 0.73, 0.32, 0.53, graphite)
		_add_cylinder("MainEngineThroat", Vector3(ex, 0.14, 0.40), 0.28, 0.12, orange_light)
	_add_cone("MainEngineCenter", Vector3(0, 0.43, -0.55), 0.75, 0.32, 0.53, graphite)

	# Kompaktowe rozkladane panele fotowoltaiczne powyzej boosterow.
	# Ich szerokosc jest ograniczona: rakieta nadal wyglada jak rakieta.
	for side in [-1.0, 1.0]:
		_add_box("SolarHinge", Vector3(side * 1.35, 11.35, 0), Vector3(0.82, 0.17, 0.16), graphite)
		_add_box("SolarFrame", Vector3(side * 2.20, 11.15, 0), Vector3(1.55, 2.20, 0.17), orange)
		_add_box("SolarCells", Vector3(side * 2.20, 11.15, 0.10), Vector3(1.37, 1.99, 0.09), solar)
		for column in [-0.45, 0.0, 0.45]:
			_add_box("SolarGrid", Vector3(side * 2.20 + column, 11.15, 0.16), Vector3(0.035, 1.96, 0.025), light_cyan)
		for row in [-0.55, 0.0, 0.55]:
			_add_box("SolarGrid", Vector3(side * 2.20, 11.15 + row, 0.16), Vector3(1.37, 0.026, 0.025), graphite_light)

	# Luk ladunkowy i otwarta rampa robotow: strona +Z.
	_add_box("CargoDoorFrame", Vector3(0, 1.79, 1.15), Vector3(1.53, 2.20, 0.20), orange)
	_add_box("CargoDoorInterior", Vector3(0, 1.74, 1.28), Vector3(1.28, 1.87, 0.08), graphite)
	_add_box("CargoDoorSeam", Vector3(0, 2.64, 1.34), Vector3(0.85, 0.08, 0.055), light_cyan)
	_add_box("ExitRamp", Vector3(0, 0.16, 3.05), Vector3(1.67, 0.22, 3.35), graphite_light)
	for side in [-1.0, 1.0]:
		_add_box("RampGuide", Vector3(side * 0.73, 0.31, 3.05), Vector3(0.10, 0.12, 3.20), orange)
	for z in [2.2, 2.9, 3.6, 4.25]:
		_add_box("RampStripe", Vector3(0, 0.29, z), Vector3(1.11, 0.025, 0.055), light_cyan)

	# Jedno polaczone fizyczne cialo rakiety; kolizje boosterow sa oddzielne.
	_add_cylinder_collision(Vector3(0, 5.70, 0), 1.25, 11.1)
	for side in [-1.0, 1.0]:
		_add_cylinder_collision(Vector3(side * 2.12, 4.45, 0), 0.80, 8.0)

	info = Label3D.new()
	info.name = "ShipStatus"
	info.position.y = 18.0
	info.font_size = 43
	info.pixel_size = 0.009
	info.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	info.visible = false # Wskazania przeniesione do panelu HUD.
	add_child(info)
	_refresh_label()


func solar_output() -> float:
	# Kompletna produkcja PV wymaga naprawy uszkodzonego statku.
	return NOMINAL_SOLAR_POWER * health / MAX_HEALTH


func get_access_radius() -> float:
	return CLEARANCE_RADIUS


func repair(amount: float) -> float:
	var restored: float = minf(maxf(amount, 0.0), MAX_HEALTH - health)
	health += restored
	if restored > 0.0:
		health_changed.emit(health, MAX_HEALTH)
		_refresh_label()
	return restored


func needs_repair() -> bool:
	return health < MAX_HEALTH - 0.01


func _refresh_label() -> void:
	if info != null:
		info.text = "RAKIETA KOLONIJNA | PV %.1f kW | %d%%" % [solar_output(), roundi(health)]


func _add_box(part: String, at: Vector3, dimensions: Vector3, mat: Material, rotate: Vector3 = Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.name = part
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = at
	instance.rotation_degrees = rotate
	instance.material_override = mat
	add_child(instance)


func _add_cylinder(part: String, at: Vector3, radius: float, height: float, mat: Material) -> void:
	_add_cone(part, at, height, radius, radius, mat)


func _add_cone(part: String, at: Vector3, height: float, bottom_radius: float, top_radius: float, mat: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = part
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.radial_segments = 16
	instance.mesh = mesh
	instance.position = at
	instance.material_override = mat
	add_child(instance)


func _add_cylinder_collision(at: Vector3, radius: float, height: float) -> void:
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	collision.position = at
	add_child(collision)


func _material(color: Color, glowing: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.57
	mat.metallic = 0.36
	if glowing:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
