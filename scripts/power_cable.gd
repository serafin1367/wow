extends Node3D
## WOW 0.9: wizualny przewod energetyczny, podswietlone impulsy.
## Bez kolizji: nie blokuje robotow i trasy A*.

var start_point: Vector3
var end_point: Vector3
var pulse_nodes: Array[MeshInstance3D] = []
var elapsed: float = 0.0
var powered: bool = true


func setup(source: Vector3, destination: Vector3) -> void:
	start_point = source
	end_point = destination


func _ready() -> void:
	name = "GridPowerCable"
	var vector: Vector3 = end_point - start_point
	var length: float = Vector2(vector.x, vector.z).length()
	if length < 0.5:
		return
	var center: Vector3 = (start_point + end_point) * 0.5
	center.y = 0.12
	var body := MeshInstance3D.new()
	body.name = "CableSheath"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.20, 0.11, length)
	body.mesh = mesh
	body.position = center
	body.rotation.y = atan2(vector.x, vector.z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.19, 0.24)
	mat.metallic = 0.35
	body.material_override = mat
	add_child(body)
	for i in range(5):
		var dot := MeshInstance3D.new()
		dot.name = "EnergyPulse%d" % i
		var orb := SphereMesh.new()
		orb.radius = 0.13
		orb.height = 0.26
		dot.mesh = orb
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(0.16, 0.91, 0.98)
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dot.material_override = glow
		add_child(dot)
		pulse_nodes.append(dot)


func _process(delta: float) -> void:
	elapsed += delta
	for i in range(pulse_nodes.size()):
		var pulse: MeshInstance3D = pulse_nodes[i]
		pulse.visible = powered
		var alpha: float = fposmod(elapsed * 0.35 + float(i) / float(pulse_nodes.size()), 1.0)
		pulse.position = start_point.lerp(end_point, alpha) + Vector3(0, 0.20, 0)
