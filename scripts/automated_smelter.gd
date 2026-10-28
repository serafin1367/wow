extends StaticBody3D
## WOW 0.6: huta zuzywa 2 rudy zelaza na 1 sztabe metalu co 3 sekundy.
## Produkcja zuzywa energie; surowce nie sa tworzone bez wejscia.

signal stock_changed

const MODEL = preload("res://scripts/factory_models.gd")
const CLEARANCE_RADIUS: float = 3.9
const POWER_KW: float = 2.5
const CYCLE_SECONDS: float = 3.0
const ORE_PER_METAL: int = 2
const MAX_ORE: int = 80
const MAX_METAL: int = 40

var power_enabled: bool = false
var ore_stock: int = 0
var metal_stock: int = 0
var accumulated: float = 0.0
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
		machine_visual.is_working = power_enabled and ore_stock >= ORE_PER_METAL and metal_stock < MAX_METAL
	if not power_enabled or ore_stock < ORE_PER_METAL or metal_stock >= MAX_METAL:
		return
	accumulated += delta
	while accumulated >= CYCLE_SECONDS and ore_stock >= ORE_PER_METAL and metal_stock < MAX_METAL:
		accumulated -= CYCLE_SECONDS
		ore_stock -= ORE_PER_METAL
		metal_stock += 1
		stock_changed.emit()


func deposit_ore(quantity: int) -> int:
	var accepted: int = mini(maxi(quantity, 0), MAX_ORE - ore_stock)
	ore_stock += accepted
	if accepted > 0:
		stock_changed.emit()
	return accepted


func collect_metal(requested: int) -> int:
	var amount: int = mini(maxi(requested, 0), metal_stock)
	metal_stock -= amount
	if amount > 0:
		stock_changed.emit()
	return amount


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
		"ore_stock": ore_stock, "metal_stock": metal_stock, "accumulated": accumulated}


func from_dict(data: Dictionary) -> void:
	set_meta("save_id", str(data.get("save_id", "")))
	ore_stock = clampi(int(data.get("ore_stock", 0)), 0, MAX_ORE)
	metal_stock = clampi(int(data.get("metal_stock", 0)), 0, MAX_METAL)
	accumulated = maxf(0.0, float(data.get("accumulated", 0.0)))
