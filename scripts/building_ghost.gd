extends Node3D
## WOW 0.11: hologram dokladnie tego modelu, ktory gracz postawi.
## Nie ma kolizji, nie uruchamia produkcji ani automatyzacji.
const CENTER = preload("res://scripts/town_hall.gd")
const FORESTER = preload("res://scripts/forester_hut.gd")
const MINE = preload("res://scripts/automated_mine.gd")
const SMELTER = preload("res://scripts/automated_smelter.gd")
const SOLAR = preload("res://scripts/solar_array.gd")
const BATTERY = preload("res://scripts/battery_bank.gd")
const DEPOT = preload("res://scripts/logistics_depot.gd")

const VALID_COLOR: Color = Color(0.24, 0.98, 0.68, 0.47)
const INVALID_COLOR: Color = Color(1.0, 0.24, 0.19, 0.48)

var current_kind: String = ""
var model: Node3D = null
var hologram_material: StandardMaterial3D


func _ready() -> void:
	name = "ConstructionHologram"
	hologram_material = StandardMaterial3D.new()
	hologram_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hologram_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hologram_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	hologram_material.albedo_color = VALID_COLOR


func show_building(kind: String, orientation_quarters: int, allowed: bool) -> void:
	if current_kind != kind or not is_instance_valid(model):
		_clear_model()
		model = _build_model(kind)
		current_kind = kind
		if model == null:
			return
		# NIGDY nie wlaczaj kolizji ani zadnych procesow fizycznych
		# dla hologramu. _ready() tworzy meshe, ale nie pobiera surowcow.
		if model is CollisionObject3D:
			(model as CollisionObject3D).collision_layer = 0
			(model as CollisionObject3D).collision_mask = 0
		model.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(model)
		_disable_model_physics(model)
		_apply_hologram_material(model)
	if model != null:
		model.rotation.y = float(posmod(orientation_quarters, 4)) * PI * 0.5
		hologram_material.albedo_color = VALID_COLOR if allowed else INVALID_COLOR
	visible = true


func _build_model(kind: String) -> Node3D:
	match kind:
		"center":
			return CENTER.new()
		"forester":
			return FORESTER.new()
		"mine":
			return MINE.new()
		"smelter":
			return SMELTER.new()
		"solar":
			return SOLAR.new()
		"battery":
			return BATTERY.new()
		"depot":
			return DEPOT.new()
	return null


func _disable_model_physics(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	if node is Timer:
		(node as Timer).stop()
	if node is Label3D:
		(node as Label3D).visible = false
	if node is GPUParticles3D:
		(node as GPUParticles3D).emitting = false
	for child in node.get_children():
		_disable_model_physics(child)


func _apply_hologram_material(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = hologram_material
	for child in node.get_children():
		_apply_hologram_material(child)


func _clear_model() -> void:
	if is_instance_valid(model):
		remove_child(model)
		model.queue_free()
	model = null
	current_kind = ""


func clear() -> void:
	visible = false
	_clear_model()
