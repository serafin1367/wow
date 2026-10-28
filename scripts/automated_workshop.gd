extends StaticBody3D
## WOW 0.16: warsztat zasilany rejestrem receptur i wspolnym Inventory.
signal stock_changed

const REGISTRY = preload("res://scripts/recipe_registry.gd")
const INVENTORY = preload("res://scripts/inventory.gd")
const DEFAULT_RECIPE_ID: String = "forge_steel"
const CLEARANCE_RADIUS: float = 3.9

var recipe_id: String = DEFAULT_RECIPE_ID
var active_recipe = REGISTRY.get_recipe(DEFAULT_RECIPE_ID)
var input_buffer = INVENTORY.new("factory:workshop:input")
var output_buffer = INVENTORY.new("factory:workshop:output")
var power_enabled: bool = false
var production_paused: bool = false
var production_priority: int = 80
var cycles_remaining: int = -1
var accumulated: float = 0.0
var total_cycles: int = 0
var total_steel: int = 0
var total_electronics: int = 0
var machine_visual: Node3D
var assembly_arm: MeshInstance3D

func _init() -> void:
	assert(active_recipe != null and active_recipe.is_valid())
	for resource in ["metal", "steel"]:
		input_buffer.configure(resource, 80)
	for resource in ["steel", "electronics"]:
		output_buffer.configure(resource, 40)

func _ready() -> void:
	name = "AssemblyWorkshop"
	collision_layer = 4 | 8
	collision_mask = 0
	machine_visual = Node3D.new()
	machine_visual.name = "WorkshopVisual"
	add_child(machine_visual)
	var steel_material := StandardMaterial3D.new()
	steel_material.albedo_color = Color(0.25, 0.35, 0.42)
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.98, 0.61, 0.18)
	_add_box("Base", Vector3(0, 0.25, 0), Vector3(5.2, 0.5, 4.8), steel_material)
	_add_box("AssemblyHousing", Vector3(0, 1.6, -0.3), Vector3(3.5, 2.2, 2.7), steel_material)
	_add_box("AssemblyArm", Vector3(0, 3.0, 0.3), Vector3(0.5, 1.5, 0.5), accent)
	assembly_arm = machine_visual.get_node("AssemblyArm")
	_add_box("InputDock", Vector3(-2.3, 0.8, 0), Vector3(0.8, 0.9, 1.4), accent)
	_add_box("OutputDock", Vector3(2.3, 0.8, 0), Vector3(0.8, 0.9, 1.4), accent)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.2, 3.7, 4.8)
	collider.shape = shape
	collider.position.y = 1.85
	add_child(collider)

func _add_box(label: String, pos: Vector3, dimensions: Vector3, material: Material) -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh_node.mesh = mesh
	mesh_node.position = pos
	mesh_node.material_override = material
	machine_visual.add_child(mesh_node)

func _process(delta: float) -> void:
	if assembly_arm != null and power_enabled and not production_paused and cycles_remaining != 0 and active_recipe.can_process(input_buffer, output_buffer):
		assembly_arm.rotation.y += delta * 3.0
	if active_recipe == null or not power_enabled or production_paused or cycles_remaining == 0:
		return
	if not active_recipe.can_process(input_buffer, output_buffer):
		return
	accumulated += maxf(0.0, delta)
	while accumulated >= active_recipe.duration_seconds and cycles_remaining != 0:
		if not active_recipe.process_once(input_buffer, output_buffer):
			break
		accumulated -= active_recipe.duration_seconds
		total_cycles += 1
		total_steel += active_recipe.output_amount("steel")
		total_electronics += active_recipe.output_amount("electronics")
		if cycles_remaining > 0:
			cycles_remaining -= 1
		stock_changed.emit()

func set_recipe_id(new_id: String) -> bool:
	var candidate = REGISTRY.get_recipe(new_id)
	if candidate == null or candidate.machine_kind != "workshop":
		return false
	if accumulated > 0.0:
		return false
	for resource in candidate.inputs:
		if not input_buffer.capacity.has(str(resource)):
			return false
	for resource in candidate.outputs:
		if not output_buffer.capacity.has(str(resource)):
			return false
	recipe_id = new_id
	active_recipe = candidate
	return true

func set_production_target(cycles: int) -> void:
	cycles_remaining = maxi(-1, cycles)

func deposit_resource(resource_type: String, quantity: int) -> int:
	var amount: int = input_buffer.push(resource_type, quantity)
	if amount > 0:
		stock_changed.emit()
	return amount

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

func to_dict() -> Dictionary:
	return {"save_id": str(get_meta("save_id", "")), "type_id": "building:workshop",
		"object_version": 1, "position": [global_position.x, global_position.y, global_position.z],
		"rotation_y": rotation.y, "recipe_id": recipe_id,
		"input_buffer": input_buffer.to_dict(), "output_buffer": output_buffer.to_dict(),
		"accumulated": accumulated, "production_paused": production_paused,
		"production_priority": production_priority, "cycles_remaining": cycles_remaining,
		"total_cycles": total_cycles, "total_steel": total_steel,
		"total_electronics": total_electronics}

func from_dict(data: Dictionary) -> void:
	input_buffer.from_dict(data.get("input_buffer", {}))
	output_buffer.from_dict(data.get("output_buffer", {}))
	accumulated = maxf(0.0, float(data.get("accumulated", 0.0)))
	production_paused = bool(data.get("production_paused", false))
	production_priority = clampi(int(data.get("production_priority", 80)), 0, 200)
	cycles_remaining = maxi(-1, int(data.get("cycles_remaining", -1)))
	total_cycles = maxi(0, int(data.get("total_cycles", 0)))
	total_steel = maxi(0, int(data.get("total_steel", 0)))
	total_electronics = maxi(0, int(data.get("total_electronics", 0)))
	set_meta("save_id", str(data.get("save_id", "")))
	var location: Array = data.get("position", [])
	if location.size() == 3:
		global_position = Vector3(float(location[0]), float(location[1]), float(location[2]))
	rotation.y = float(data.get("rotation_y", 0.0))
	# Niezgodny identyfikator nie moze aktywowac obcej receptury.
	var stored_id: String = str(data.get("recipe_id", DEFAULT_RECIPE_ID))
	var selected = REGISTRY.get_recipe(stored_id)
	if selected == null or selected.machine_kind != "workshop":
		stored_id = DEFAULT_RECIPE_ID
	recipe_id = stored_id
	active_recipe = REGISTRY.get_recipe(stored_id)
