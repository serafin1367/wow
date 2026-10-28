extends Node3D
## WOW 0.9: iskry, zadymienie i goracy metal bez tekstur i silnika GPU particles.
## Widoczne tylko gdy huta pracuje, zerowy wplyw na gospodarke.

const SPARK_COUNT: int = 18
var active: bool = false
var elapsed: float = 0.0
var sparks: Array[MeshInstance3D] = []
var sparks_velocity: Array[Vector3] = []


func _ready() -> void:
	name = "ForgeSparks"
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.67, 0.13)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.40, 0.06)
	material.emission_energy_multiplier = 3.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(SPARK_COUNT):
		var ember := MeshInstance3D.new()
		ember.name = "Spark_%d" % i
		var spark_mesh := SphereMesh.new()
		spark_mesh.radius = 0.065 + float(i % 3) * 0.023
		spark_mesh.height = 0.17
		spark_mesh.radial_segments = 6
		spark_mesh.rings = 3
		ember.mesh = spark_mesh
		ember.material_override = material
		ember.visible = false
		add_child(ember)
		sparks.append(ember)
		sparks_velocity.append(Vector3(
			sin(float(i) * 7.91) * 0.85,
			1.4 + float(i % 6) * 0.30,
			cos(float(i) * 4.13) * 0.75
		))


func _process(delta: float) -> void:
	elapsed += delta
	for i in range(sparks.size()):
		var particle: MeshInstance3D = sparks[i]
		particle.visible = active
		if not active:
			continue
		var lifetime: float = 0.72 + float(i % 4) * 0.11
		var age: float = fposmod(elapsed + float(i) * 0.119, lifetime)
		particle.position = Vector3(0.6, 0.0, 0.0) + sparks_velocity[i] * age
		particle.position.y -= 0.7 * age * age
		particle.scale = Vector3.ONE * maxf(0.08, 1.0 - age / lifetime)
