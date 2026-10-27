extends StaticBody3D
## Zrodlo surowca: drzewo, zloto albo kamien.
## Po wyczerpaniu znika i przestaje blokowac droge.

signal depleted(resource, clearance_radius)

@export_enum("wood", "gold", "stone") var resource_type: String = "wood"
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
