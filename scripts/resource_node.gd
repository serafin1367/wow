extends StaticBody3D
## Zrodlo surowca: drzewo, zloto, kamien albo ruda zelaza.
## Po wyczerpaniu znika i przestaje blokowac droge.

signal depleted(resource, clearance_radius)

@export_enum("wood", "gold", "stone", "iron_ore") var resource_type: String = "wood"
@export var remaining: int = 100
@export var clearance_radius: float = 1.6
var is_sapling: bool = false


func harvest(requested: int) -> int:
	if is_sapling or remaining <= 0 or requested <= 0:
		return 0

	var harvested: int = mini(requested, remaining)
	remaining -= harvested
	if remaining == 0:
		collision_layer = 0
		visible = false
		depleted.emit(self, clearance_radius)
	return harvested


func to_dict() -> Dictionary:
	return {"save_id": str(get_meta("save_id", "")), "resource_type": resource_type,
		"position": [global_position.x, global_position.y, global_position.z],
		"remaining": remaining, "clearance_radius": clearance_radius,
		"is_sapling": is_sapling, "visible": visible}


func from_dict(data: Dictionary) -> void:
	set_meta("save_id", str(data.get("save_id", "")))
	remaining = maxi(0, int(data.get("remaining", remaining)))
	is_sapling = bool(data.get("is_sapling", is_sapling))
	clearance_radius = float(data.get("clearance_radius", clearance_radius))
	visible = bool(data.get("visible", visible))
	collision_layer = 0 if is_sapling or remaining <= 0 or not visible else 4
