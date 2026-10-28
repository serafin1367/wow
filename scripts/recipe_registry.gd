extends RefCounted
## WOW 0.16 — jeden rejestr definicji gospodarki.
## Kazde get_recipe zwraca niezalezna instancje; konsumenci nie
## modyfikuja katalogu. Tu dodajemy receptury nowych maszyn.

const PRODUCTION_RECIPE = preload("res://scripts/production_recipe.gd")

const DEFINITIONS: Dictionary = {
	"smelt_iron": {
		"recipe_id": "smelt_iron",
		"machine_kind": "smelter",
		"display_name": "Wytop zelaza",
		"inputs": {"iron_ore": 2},
		"outputs": {"metal": 1},
		"duration_seconds": 3.0,
		"power_kw": 2.5
	},
	"mine_iron_ore": {
		"recipe_id": "mine_iron_ore",
		"machine_kind": "mine",
		"display_name": "Wydobycie rudy zelaza",
		"inputs": {},
		"outputs": {"iron_ore": 4},
		"duration_seconds": 1.5,
		"power_kw": 1.5
	}
}


static func get_recipe(id: String):
	if not DEFINITIONS.has(id):
		return null
	var recipe = PRODUCTION_RECIPE.from_dict(DEFINITIONS[id])
	return recipe


static func recipes_for_machine(kind: String) -> Array:
	var found: Array = []
	for id in DEFINITIONS.keys():
		var recipe = get_recipe(str(id))
		if recipe != null and recipe.machine_kind == kind:
			found.append(recipe)
	return found


static func all_ids() -> Array[String]:
	var result: Array[String] = []
	for id in DEFINITIONS.keys():
		result.append(str(id))
	result.sort()
	return result


static func validate_registry() -> bool:
	var seen: Dictionary = {}
	for id in DEFINITIONS.keys():
		var recipe = get_recipe(str(id))
		if recipe == null or recipe.recipe_id != str(id) or seen.has(recipe.recipe_id):
			return false
		seen[recipe.recipe_id] = true
	return not seen.is_empty()
