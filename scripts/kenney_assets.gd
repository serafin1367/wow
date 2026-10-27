extends RefCounted
## Wspolny loader modeli Kenney GLB. Import Godot odbywa sie automatycznie.
## Modele maja wlasne kolory; skrypt nie zmienia ich licencji ani zawartosci.

static func model(pack: String, asset: String, uniform_scale: float = 1.0) -> Node3D:
	var path: String = "res://assets/kenney/%s/%s.glb" % [pack, asset]
	if not ResourceLoader.exists(path):
		push_warning("Kenney: brak zaimportowanego modelu: %s" % path)
		return null
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_warning("Kenney: nie mozna odczytac modelu %s" % path)
		return null
	var instance: Node3D = scene.instantiate() as Node3D
	if instance == null:
		push_warning("Kenney: GLB nie zawiera sceny 3D: %s" % path)
		return null
	instance.name = asset.replace("-", "_")
	instance.scale = Vector3.ONE * uniform_scale
	return instance


static func tint_meshes(node: Node, tint: Color) -> void:
	# Kolor zoltego zloza: kolorowanie nie zmienia fizyki/zasobu.
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = 0.75
		mat.metallic = 0.1
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		tint_meshes(child, tint)
