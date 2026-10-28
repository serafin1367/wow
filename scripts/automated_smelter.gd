extends StaticBody3D
## WOW 0.6: huta zuzywa 2 rudy zelaza na 1 sztabe metalu co 3 sekundy.
## Produkcja zuzywa energie; surowce nie sa tworzone bez wejscia.

signal stock_changed

const MODEL = preload("res://scripts/factory_models.gd")
const INVENTORY = preload("res://scripts/inventory.gd")
const RECIPE_REGISTRY = preload("res://scripts/recipe_registry.gd")
const DEFAULT_RECIPE_ID: String = "smelt_iron"
const CLEARANCE_RADIUS: float = 3.9
## Wartosci zgodnosciowe dla istniejacego HUD i testow WOW 0.15.
## Jedynym zrodlem danych dla rzeczywistej produkcji jest RecipeRegistry.
const POWER_KW: float = 2.5
const CYCLE_SECONDS: float = 3.0
const ORE_PER_METAL: int = 2
const MAX_ORE: int = 80
const MAX_METAL: int = 40

var power_enabled: bool = false
var production_paused: bool = false
var production_priority: int = 90
var cycles_remaining: int = -1
var production_queue: Array[Dictionary] = []
var next_order_id: int = 1
var recipe_id: String = DEFAULT_RECIPE_ID
var active_recipe = RECIPE_REGISTRY.get_recipe(DEFAULT_RECIPE_ID)
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
	assert(active_recipe != null and active_recipe.is_valid(), "Smelter recipe missing from registry")
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
	# Rezerwacje ladunkow robotow i tasm sa wspolne z Inventory.
	# Receptura kontroluje komplet wejsc i wyjsc przed kazdym cyklem.
	var ready: bool = active_recipe != null and active_recipe.can_process(input_buffer, output_buffer)
	if machine_visual != null:
		machine_visual.is_working = power_enabled and not production_paused and cycles_remaining != 0 and ready
	if not power_enabled or production_paused or cycles_remaining == 0 or not ready:
		return
	accumulated += delta
	while accumulated >= active_recipe.duration_seconds and cycles_remaining != 0:
		if not active_recipe.process_once(input_buffer, output_buffer):
			# Pelny/zarezerwowany bufor: nie pobieraj rudy ani nie
			# odbieraj kolejnej jednostki za niedokonczony cykl.
			break
		accumulated -= active_recipe.duration_seconds
		total_smelted += active_recipe.output_amount("metal")
		if cycles_remaining > 0:
			cycles_remaining -= 1
			if cycles_remaining == 0:
				_activate_next_order()
		stock_changed.emit()


func set_recipe_id(new_id: String) -> bool:
	var selected = RECIPE_REGISTRY.get_recipe(new_id)
	if selected == null or selected.machine_kind != "smelter":
		return false
	# Nie zmieniaj przepisu w srodku cyklu. Przyszly edytor
	# receptur bedzie mogl zlecić zmiane po jego zakonczeniu.
	if accumulated > 0.0 and not is_equal_approx(accumulated, 0.0):
		return false
	active_recipe = selected
	recipe_id = new_id
	return true


func set_production_target(cycles: int) -> void:
	production_queue.clear()
	cycles_remaining = maxi(-1, cycles)


func enqueue_production(cycles: int, priority: int = 100) -> bool:
	if cycles <= 0 or cycles > 1000 or production_queue.size() >= 16:
		return false
	var order: Dictionary = {"id": next_order_id, "cycles": cycles,
		"priority": clampi(priority, 0, 200)}
	next_order_id += 1
	if cycles_remaining <= 0:
		cycles_remaining = cycles
	elif cycles_remaining == -1:
		cycles_remaining = cycles
	else:
		production_queue.append(order)
	return true


func _activate_next_order() -> void:
	if production_queue.is_empty():
		return
	production_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["priority"]) > int(b["priority"]))
	var next_order: Dictionary = production_queue.pop_front()
	cycles_remaining = int(next_order["cycles"])


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
	return input_buffer if active_recipe != null and active_recipe.inputs.has(resource_type) else null


func get_output_port(resource_type: String):
	return output_buffer if active_recipe != null and active_recipe.outputs.has(resource_type) else null


func get_access_radius() -> float:
	return CLEARANCE_RADIUS


func describe() -> String:
	var status := "PRZETAPIANIE" if power_enabled else "BRAK ENERGII"
	if power_enabled and ore_stock < active_recipe.input_amount("iron_ore"):
		status = "OCZEKIWANIE NA RUDE"
	elif metal_stock >= MAX_METAL:
		status = "MAGAZYN PELNY"
	return "%s | Ruda: %d/%d | Metal: %d/%d | %.1f kW" % [
		status, ore_stock, MAX_ORE, metal_stock, MAX_METAL, active_recipe.power_kw
	]


func to_dict() -> Dictionary:
	return {"save_id": str(get_meta("save_id", "")), "position":
		[global_position.x, global_position.y, global_position.z], "rotation_y": rotation.y,
		"ore_stock": ore_stock, "metal_stock": metal_stock, "accumulated": accumulated,
		"input_buffer": input_buffer.to_dict(), "output_buffer": output_buffer.to_dict(),
		"total_smelted": total_smelted, "production_paused": production_paused,
		"cycles_remaining": cycles_remaining, "production_priority": production_priority,
		"recipe_id": recipe_id,
		"production_queue": production_queue.duplicate(true), "next_order_id": next_order_id}


func from_dict(data: Dictionary) -> void:
	# Legacy save v1 (WOW 0.15) nie zawieral recipe_id.
	# Nie pozwalamy obcemu ID wybrac receptury innego typu maszyny.
	recipe_id = DEFAULT_RECIPE_ID
	active_recipe = RECIPE_REGISTRY.get_recipe(DEFAULT_RECIPE_ID)
	var stored_id: String = str(data.get("recipe_id", DEFAULT_RECIPE_ID))
	var stored_recipe = RECIPE_REGISTRY.get_recipe(stored_id)
	if stored_recipe != null and stored_recipe.machine_kind == "smelter":
		recipe_id = stored_id
		active_recipe = stored_recipe
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
	production_priority = clampi(int(data.get("production_priority", 90)), 0, 200)
	cycles_remaining = maxi(-1, int(data.get("cycles_remaining", -1)))
	next_order_id = maxi(1, int(data.get("next_order_id", 1)))
	production_queue.clear()
	for item in data.get("production_queue", []):
		if item is Dictionary and production_queue.size() < 16:
			var count: int = int(item.get("cycles", 0))
			if count > 0 and count <= 1000:
				production_queue.append({"id": maxi(1, int(item.get("id", 1))),
					"cycles": count,
					"priority": clampi(int(item.get("priority", 100)), 0, 200)})
