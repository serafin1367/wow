extends StaticBody3D
## WOW 0.6: huta zuzywa 2 rudy zelaza na 1 sztabe metalu co 3 sekundy.
## Produkcja zuzywa energie; surowce nie sa tworzone bez wejscia.

signal stock_changed

const MODEL = preload("res://scripts/factory_models.gd")
const INVENTORY = preload("res://scripts/inventory.gd")
const CLEARANCE_RADIUS: float = 3.9
const POWER_KW: float = 2.5
const CYCLE_SECONDS: float = 3.0
const ORE_PER_METAL: int = 2
const MAX_ORE: int = 80
const MAX_METAL: int = 40

var power_enabled: bool = false
var production_paused: bool = false
var cycles_remaining: int = -1
var input_buffer = INVENTORY.new("factory:smelter:input")
var output_buffer = INVENTORY.new("factory:smelter:output")
var ore_stock: int:
	get:
		return input_buffer.quantity("iron_ore")
	set(value):
		input_buffer.stock["iron_ore"] = clampi(value, 0, MAX_ORE)
var metal_stock: int:
	get:
		return output_buffer.quantity("metal")
	set(value):
		output_buffer.stock["metal"] = clampi(value, 0, MAX_METAL)


func _init() -> void:
	input_buffer.configure("iron_ore", MAX_ORE)
	output_buffer.configure("metal", MAX_METAL)

var accumulated: float = 0.0
var total_smelted: int = 0
var machine_visual = null


func _ready() -> void:
	name = "OreSmelter"
	collision_layer = 4 | 8
	collision_mask = 0
	var visual = MODEL.new()
	machine_visual = visual
	visual.machine_type = "smelter"
	add_child(visual)

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.2, 5.0, 4.9)
	collider.shape = shape
	collider.position.y = 2.5
	add_child(collider)

	var title := Label3D.new()
	title.text = "HUTA 01"
	title.font_size = 45
	title.pixel_size = 0.008
	title.position = Vector3(0, 6.3, 0)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.visible = false
	add_child(title)


func _process(delta: float) -> void:
	if machine_visual != null:
		machine_visual.is_working = power_enabled and not production_paused and cycles_remaining != 0 and ore_stock >= ORE_PER_METAL and metal_stock < MAX_METAL
	if not power_enabled or production_paused or cycles_remaining == 0 or ore_stock < ORE_PER_METAL or metal_stock >= MAX_METAL:
		return
	accumulated += delta
	while accumulated >= CYCLE_SECONDS and ore_stock >= ORE_PER_METAL and metal_stock < MAX_METAL and cycles_remaining != 0:
		accumulated -= CYCLE_SECONDS
		var consumed: int = input_buffer.pull("iron_ore", ORE_PER_METAL)
		if consumed < ORE_PER_METAL:
			return
		var produced: int = output_buffer.push("metal", 1)
		assert(produced == 1, "Smelter output must have space before consuming ore")
		total_smelted += produced
		if cycles_remaining > 0:
			cycles_remaining -= 1
		stock_changed.emit()


func set_production_target(cycles: int) -> void:
	cycles_remaining = maxi(-1, cycles)


func deposit_ore(quantity: int) -> int:
	return deposit_resource("iron_ore", quantity)


func collect_metal(requested: int) -> int:
	return withdraw_resource("metal", requested)


func deposit_resource(resource_type: String, quantity: int) -> int:
	var accepted: int = input_buffer.push(resource_type, quantity)
	if accepted > 0:
		stock_changed.emit()
	return accepted


func withdraw_resource(resource_type: String, requested: int) -> int:
	var amount: int = output_buffer.pull(resource_type, requested)
	if amount > 0:
		stock_changed.emit()
	return amount


func get_input_port(resource_type: String):
	return input_buffer if resource_type == "iron_ore" else null


func get_output_port(resource_type: String):
	return output_buffer if resource_type == "metal" else null


func get_access_radius() -> float:
	return CLEARANCE_RADIUS


func describe() -> String:
	var status := "PRZETAPIANIE" if power_enabled else "BRAK ENERGII"
	if power_enabled and ore_stock < ORE_PER_METAL:
		status = "OCZEKIWANIE NA RUDE"
	elif metal_stock >= MAX_METAL:
		status = "MAGAZYN PELNY"
	return "%s | Ruda: %d/%d | Metal: %d/%d | %.1f kW" % [
		status, ore_stock, MAX_ORE, metal_stock, MAX_METAL, POWER_KW
	]


func to_dict() -> Dictionary:
	return {"save_id": str(get_meta("save_id", "")), "position":
		[global_position.x, global_position.y, global_position.z], "rotation_y": rotation.y,
		"ore_stock": ore_stock, "metal_stock": metal_stock, "accumulated": accumulated,
		"input_buffer": input_buffer.to_dict(), "output_buffer": output_buffer.to_dict(),
		"total_smelted": total_smelted, "production_paused": production_paused,
		"cycles_remaining": cycles_remaining}


func from_dict(data: Dictionary) -> void:
	set_meta("save_id", str(data.get("save_id", "")))
	if data.has("input_buffer"):
		input_buffer.from_dict(data["input_buffer"])
	else:
		ore_stock = clampi(int(data.get("ore_stock", 0)), 0, MAX_ORE)
	if data.has("output_buffer"):
		output_buffer.from_dict(data["output_buffer"])
	else:
		metal_stock = clampi(int(data.get("metal_stock", 0)), 0, MAX_METAL)
	accumulated = maxf(0.0, float(data.get("accumulated", 0.0)))
	total_smelted = maxi(0, int(data.get("total_smelted", 0)))
	production_paused = bool(data.get("production_paused", false))
	cycles_remaining = maxi(-1, int(data.get("cycles_remaining", -1)))
