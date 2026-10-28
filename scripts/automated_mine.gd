extends StaticBody3D
## WOW 0.6: automatyczna kopalnia rudy zelaza na zlozu.
## Nie tworzy surowcow z niczego. Kazda jednostka trafia z naturalnego zloza
## do lokalnego bufora, odbieranego przez robota transportowego.

signal stock_changed

const MODEL = preload("res://scripts/factory_models.gd")
const INVENTORY = preload("res://scripts/inventory.gd")
const CLEARANCE_RADIUS: float = 3.0
const POWER_KW: float = 1.5
const CYCLE_SECONDS: float = 1.5
const RATE: int = 4
const MAX_BUFFER: int = 80

var ore_source = null
var power_enabled: bool = false
var output_buffer = INVENTORY.new("factory:mine:output")
var stock: int:
	get:
		return output_buffer.quantity("iron_ore")
	set(value):
		output_buffer.stock["iron_ore"] = clampi(value, 0, MAX_BUFFER)


func _init() -> void:
	output_buffer.configure("iron_ore", MAX_BUFFER)

var accumulated: float = 0.0
var total_extracted: int = 0
var machine_visual = null


func _ready() -> void:
	name = "IronExtractor"
	collision_layer = 4 | 8
	collision_mask = 0

	var visual = MODEL.new()
	machine_visual = visual
	visual.machine_type = "extractor"
	add_child(visual)

	var shape := BoxShape3D.new()
	shape.size = Vector3(4.25, 3.7, 4.0)
	var hitbox := CollisionShape3D.new()
	hitbox.shape = shape
	hitbox.position = Vector3(0.0, 1.85, 0.0)
	add_child(hitbox)

	var panel := Label3D.new()
	panel.text = "EXTRACTOR 01"
	panel.position = Vector3(0.0, 4.3, 0.0)
	panel.font_size = 42
	panel.pixel_size = 0.008
	panel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	panel.visible = false
	add_child(panel)


func _process(delta: float) -> void:
	if machine_visual != null:
		machine_visual.is_working = power_enabled and has_ore() and stock < MAX_BUFFER
	if not power_enabled or not has_ore() or stock >= MAX_BUFFER:
		return
	accumulated += delta
	while accumulated >= CYCLE_SECONDS and stock < MAX_BUFFER and has_ore():
		accumulated -= CYCLE_SECONDS
		var count: int = mini(RATE, MAX_BUFFER - stock)
		var extracted: int = ore_source.harvest(count)
		if extracted > 0:
			var accepted: int = output_buffer.push("iron_ore", extracted)
			assert(accepted == extracted, "Mine output buffer must accept extracted ore")
			total_extracted += accepted
			stock_changed.emit()


func has_ore() -> bool:
	return is_instance_valid(ore_source) and ore_source != null and ore_source.remaining > 0


func withdraw(requested: int) -> int:
	return withdraw_resource("iron_ore", requested)


func withdraw_resource(resource_type: String, requested: int) -> int:
	var amount: int = output_buffer.pull(resource_type, requested)
	if amount > 0:
		stock_changed.emit()
	return amount


func get_output_port(resource_type: String):
	return output_buffer if resource_type == "iron_ore" else null


func get_access_radius() -> float:
	return CLEARANCE_RADIUS


func describe() -> String:
	var raw_left: String = str(ore_source.remaining) if has_ore() else "0"
	var status: String = "PRODUKCJA" if power_enabled else "BRAK ENERGII"
	if stock >= MAX_BUFFER:
		status = "BUFORY PELNE"
	elif not has_ore():
		status = "ZLOZE WYCZERPANE"
	return "%s | Ruda: %d/%d | Zloze: %s | %.1f kW" % [status, stock, MAX_BUFFER, raw_left, POWER_KW]


func to_dict() -> Dictionary:
	return {"save_id": str(get_meta("save_id", "")), "position":
		[global_position.x, global_position.y, global_position.z], "rotation_y": rotation.y,
		"stock": stock, "accumulated": accumulated,
		"source_id": str(ore_source.get_meta("save_id", "")) if is_instance_valid(ore_source) else "",
		"output_buffer": output_buffer.to_dict(), "total_extracted": total_extracted}


func from_dict(data: Dictionary) -> void:
	set_meta("save_id", str(data.get("save_id", "")))
	if data.has("output_buffer"):
		output_buffer.from_dict(data["output_buffer"])
	else:
		stock = clampi(int(data.get("stock", 0)), 0, MAX_BUFFER)
	accumulated = maxf(0.0, float(data.get("accumulated", 0.0)))
	total_extracted = maxi(0, int(data.get("total_extracted", 0)))
