extends RefCounted
## WOW 0.16 — definicja jednej receptury. Czyste dane, bez Node i sceny.
## Bilans wykonywany jest atomowo w jednej klatce, przez wspolne Inventory.

var recipe_id: String = ""
var machine_kind: String = ""
var display_name: String = ""
var inputs: Dictionary = {}
var outputs: Dictionary = {}
var duration_seconds: float = 0.0
var power_kw: float = 0.0
var requires_external_source: bool = false


func _init(id: String = "", kind: String = "", title: String = "",
		consumes: Dictionary = {}, produces: Dictionary = {},
		seconds: float = 0.0, kilowatts: float = 0.0,
		external_source: bool = false) -> void:
	recipe_id = id
	machine_kind = kind
	display_name = title
	inputs = consumes.duplicate(true)
	outputs = produces.duplicate(true)
	duration_seconds = seconds
	power_kw = kilowatts
	requires_external_source = external_source


func is_valid() -> bool:
	if recipe_id.is_empty() or machine_kind.is_empty() or display_name.is_empty():
		return false
	if not is_finite(duration_seconds) or duration_seconds <= 0.0:
		return false
	if not is_finite(power_kw) or power_kw < 0.0 or outputs.is_empty():
		return false
	for ingredients in [inputs, outputs]:
		for material in ingredients.keys():
			if not (material is String) or str(material).is_empty():
				return false
			if not (ingredients[material] is int) or int(ingredients[material]) <= 0:
				return false
	return true


func input_amount(resource_type: String) -> int:
	return int(inputs.get(resource_type, 0))


func output_amount(resource_type: String) -> int:
	return int(outputs.get(resource_type, 0))


func can_process(input_port, output_port) -> bool:
	if not is_valid() or output_port == null or requires_external_source:
		# Zloza musza byc pobierane przez harvest() i sa skonczone.
		# Sama definicja kopalni nie moze tworzyc rudy z niczego.
		return false
	if not inputs.is_empty() and input_port == null:
		return false
	for material in inputs.keys():
		if input_port.available_output(str(material)) < int(inputs[material]):
			return false
	for material in outputs.keys():
		if output_port.available_input(str(material)) < int(outputs[material]):
			return false
	return true


func process_once(input_port, output_port) -> bool:
	# Jedna transakcja, bez await: sprawdzamy oba porty zanim cokolwiek
	# zmienimy. Rezerwacje dla robotow/tasm nie moga zostac zuzyte.
	if not can_process(input_port, output_port):
		return false
	for material in inputs.keys():
		var amount: int = int(inputs[material])
		var removed: int = input_port.pull(str(material), amount)
		assert(removed == amount, "Recipe input changed mid-transaction")
	for material in outputs.keys():
		var amount: int = int(outputs[material])
		var added: int = output_port.push(str(material), amount)
		assert(added == amount, "Recipe output changed mid-transaction")
	return true


func to_dict() -> Dictionary:
	return {
		"recipe_id": recipe_id,
		"machine_kind": machine_kind,
		"display_name": display_name,
		"inputs": inputs.duplicate(true),
		"outputs": outputs.duplicate(true),
		"duration_seconds": duration_seconds,
		"power_kw": power_kw,
		"requires_external_source": requires_external_source
	}


static func _parse_amounts(raw: Variant) -> Variant:
	if not (raw is Dictionary):
		return null
	var parsed: Dictionary = {}
	for key in raw.keys():
		if not (key is String) or str(key).is_empty():
			return null
		var quantity: Variant = raw[key]
		if not (quantity is int or quantity is float):
			return null
		var amount: float = float(quantity)
		if not is_finite(amount) or amount <= 0.0 or amount > 1000000.0 or amount != float(int(amount)):
			return null
		parsed[str(key)] = int(amount)
	return parsed


static func from_dict(data: Dictionary):
	# Niejawne rzutowanie JSON float/int nie moze zmieniac
	# ilosci zasobow. Akceptujemy jedynie dodatnie liczby calkowite.
	var consumes: Variant = _parse_amounts(data.get("inputs", null))
	var produces: Variant = _parse_amounts(data.get("outputs", null))
	if consumes == null or produces == null:
		return null
	var result_recipe = load("res://scripts/production_recipe.gd").new(
		str(data.get("recipe_id", "")), str(data.get("machine_kind", "")),
		str(data.get("display_name", "")), consumes, produces,
		float(data.get("duration_seconds", 0.0)),
		float(data.get("power_kw", -1.0)),
		bool(data.get("requires_external_source", false)))
	return result_recipe if result_recipe.is_valid() else null
