extends RefCounted
## WOW 0.14: wspolny, niezalezny od Node bufor surowcow.
## Ta sama transakcja moze byc uzyta przez robota, tasme i maszyne.
## Rezerwacje sa zapisywalne, dzieki czemu restart nie zwalnia cudzej przestrzeni.

const OBJECT_VERSION: int = 1
var save_id: String = ""
var capacity: Dictionary = {}
var stock: Dictionary = {}
var reserved_input: Dictionary = {}
var reserved_output: Dictionary = {}


func _init(id: String = "") -> void:
	save_id = id


func configure(resource_type: String, max_amount: int, initial_amount: int = 0) -> void:
	capacity[resource_type] = maxi(0, max_amount)
	stock[resource_type] = clampi(initial_amount, 0, int(capacity[resource_type]))


func quantity(resource_type: String) -> int:
	return int(stock.get(resource_type, 0))


func limit(resource_type: String) -> int:
	return int(capacity.get(resource_type, 0))


func _reserved_for(resource_type: String, input: bool) -> int:
	var list: Dictionary = reserved_input if input else reserved_output
	var amount: int = 0
	for reservation in list.values():
		if str(reservation.get("resource_type", "")) == resource_type:
			amount += int(reservation.get("amount", 0))
	return amount


func available_input(resource_type: String) -> int:
	return maxi(0, limit(resource_type) - quantity(resource_type) - _reserved_for(resource_type, true))


func available_output(resource_type: String) -> int:
	return maxi(0, quantity(resource_type) - _reserved_for(resource_type, false))


func reserve_input(job_id: String, resource_type: String, amount: int) -> bool:
	if job_id.is_empty() or amount <= 0 or reserved_input.has(job_id) or amount > available_input(resource_type):
		return false
	reserved_input[job_id] = {"resource_type": resource_type, "amount": amount}
	return true


func reserve_output(job_id: String, resource_type: String, amount: int) -> bool:
	if job_id.is_empty() or amount <= 0 or reserved_output.has(job_id) or amount > available_output(resource_type):
		return false
	reserved_output[job_id] = {"resource_type": resource_type, "amount": amount}
	return true


func cancel_input(job_id: String) -> void:
	reserved_input.erase(job_id)


func cancel_output(job_id: String) -> void:
	reserved_output.erase(job_id)


func commit_output(job_id: String) -> int:
	if not reserved_output.has(job_id):
		return 0
	var reservation: Dictionary = reserved_output[job_id]
	var resource_type: String = str(reservation["resource_type"])
	var amount: int = int(reservation["amount"])
	if amount > quantity(resource_type):
		return 0
	stock[resource_type] = quantity(resource_type) - amount
	reserved_output.erase(job_id)
	return amount


func commit_input(job_id: String) -> int:
	if not reserved_input.has(job_id):
		return 0
	var reservation: Dictionary = reserved_input[job_id]
	var resource_type: String = str(reservation["resource_type"])
	var amount: int = int(reservation["amount"])
	if amount > limit(resource_type) - quantity(resource_type):
		return 0
	stock[resource_type] = quantity(resource_type) + amount
	reserved_input.erase(job_id)
	return amount


func transfer_to(other, resource_type: String, requested: int, job_id: String) -> int:
	# Jedna transakcja wykonywana w glownej petli gry, bez await.
	# Zlecenia dlugotrwale uzywaja dwoch rezerwacji i commit po dojezdzie.
	if other == null or other == self or requested <= 0:
		return 0
	var amount: int = mini(requested, mini(available_output(resource_type), other.available_input(resource_type)))
	if amount <= 0:
		return 0
	var out_id: String = job_id + ":out"
	var in_id: String = job_id + ":in"
	if not reserve_output(out_id, resource_type, amount):
		return 0
	if not other.reserve_input(in_id, resource_type, amount):
		cancel_output(out_id)
		return 0
	var removed: int = commit_output(out_id)
	if removed != amount:
		cancel_output(out_id)
		other.cancel_input(in_id)
		return 0
	var inserted: int = other.commit_input(in_id)
	assert(inserted == removed, "Inventory invariant broken: transferred cargo must be conserved")
	return inserted


func to_dict() -> Dictionary:
	return {"save_id": save_id, "type_id": "inventory:buffer",
		"object_version": OBJECT_VERSION, "capacity": capacity.duplicate(true),
		"stock": stock.duplicate(true), "reserved_input": reserved_input.duplicate(true),
		"reserved_output": reserved_output.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	# Walidator formatu gry sprawdza typy przed wywolaniem tej metody.
	save_id = str(data.get("save_id", save_id))
	capacity.clear()
	stock.clear()
	reserved_input.clear()
	reserved_output.clear()
	for key in data.get("capacity", {}).keys():
		capacity[str(key)] = maxi(0, int(data["capacity"][key]))
	for key in data.get("stock", {}).keys():
		stock[str(key)] = clampi(int(data["stock"][key]), 0, limit(str(key)))
	for slot in ["reserved_input", "reserved_output"]:
		var target: Dictionary = reserved_input if slot == "reserved_input" else reserved_output
		for id in data.get(slot, {}).keys():
			var item: Dictionary = data[slot][id]
			var count: int = int(item.get("amount", 0))
			if count > 0 and capacity.has(str(item.get("resource_type", ""))):
				target[str(id)] = {"resource_type": str(item["resource_type"]), "amount": count}
