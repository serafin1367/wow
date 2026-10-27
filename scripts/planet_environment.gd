extends Node3D
## WOW 0.5: 3 biomy/planety, bez zmiany siatki ruchu i gospodarki.
## Przelaczanie dotyczy tylko wygladu; podroz miedzy planetami to przyszly etap.

const KENNEY = preload("res://scripts/kenney_assets.gd")
const PLANETS = ["Mars", "Ziemia", "Kepler"]
const TERRAIN_SHADER = """
shader_type spatial;
render_mode diffuse_burley, cull_back;

uniform vec4 soil_color : source_color = vec4(0.39, 0.22, 0.18, 1.0);
uniform vec4 layer_color : source_color = vec4(0.48, 0.31, 0.22, 1.0);
uniform vec4 dust_color : source_color = vec4(0.23, 0.18, 0.17, 1.0);
varying vec2 planet_coordinates;

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash2(i);
    float b = hash2(i + vec2(1.0, 0.0));
    float c = hash2(i + vec2(0.0, 1.0));
    float d = hash2(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
void vertex() {
    planet_coordinates = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
    float wide = noise2(planet_coordinates * 0.085);
    float fine = noise2(planet_coordinates * 0.37);
    float micro = noise2(planet_coordinates * 1.35);
    float strata = smoothstep(0.34, 0.67, 0.75 * wide + 0.25 * fine);
    vec3 col = mix(soil_color.rgb, layer_color.rgb, strata);
    float cracks = smoothstep(0.66, 0.81, fine * 0.7 + micro * 0.3);
    col = mix(col, dust_color.rgb, cracks * 0.62);
    ALBEDO = col * (0.93 + micro * 0.14);
    ROUGHNESS = 0.92;
}
"""

var current_planet: String = "Mars"
var scatter: Node3D
var terrain_material: ShaderMaterial
var environment_node: WorldEnvironment
var sunlight: DirectionalLight3D
var ground_mesh: MeshInstance3D


func _ready() -> void:
    name = "PlanetEnvironment"
    scatter = Node3D.new()
    scatter.name = "VisualDetails_NoCollision"
    add_child(scatter)
    var shader := Shader.new()
    shader.code = TERRAIN_SHADER
    terrain_material = ShaderMaterial.new()
    terrain_material.shader = shader


func initialize(terrain: MeshInstance3D, world: WorldEnvironment, sun: DirectionalLight3D, planet: String = "Mars") -> void:
    ground_mesh = terrain
    environment_node = world
    sunlight = sun
    select_planet(planet)


func next_planet() -> String:
    var index: int = PLANETS.find(current_planet)
    select_planet(PLANETS[(index + 1) % PLANETS.size()])
    return current_planet


func select_planet(planet: String) -> void:
    if not planet in PLANETS:
        return
    current_planet = planet
    var scheme: Dictionary = _palette(planet)
    terrain_material.set_shader_parameter("soil_color", scheme["soil"])
    terrain_material.set_shader_parameter("layer_color", scheme["layer"])
    terrain_material.set_shader_parameter("dust_color", scheme["dust"])
    if is_instance_valid(ground_mesh):
        ground_mesh.material_override = terrain_material
    if is_instance_valid(environment_node):
        environment_node.environment.background_color = scheme["sky"]
        environment_node.environment.ambient_light_color = scheme["ambient"]
    if is_instance_valid(sunlight):
        sunlight.light_color = scheme["sun"]

    for item in scatter.get_children():
        scatter.remove_child(item)
        item.queue_free()
    _build_decor(scheme)


func rock_color(resource_type: String, variant: int) -> Color:
    var scheme: Dictionary = _palette(current_planet)
    var rock: Color = scheme["rock"]
    var delta: float = float(variant % 3) * 0.065 - 0.045
    if resource_type == "gold":
        return rock.darkened(0.19 + float(variant % 2) * 0.10)
    return Color(
        clampf(rock.r + delta, 0.0, 1.0),
        clampf(rock.g + delta, 0.0, 1.0),
        clampf(rock.b + delta, 0.0, 1.0),
        1.0
    )


func crystal_color() -> Color:
    return _palette(current_planet)["glow"]


func apply_resource_colors(resources: Array) -> void:
    for deposit in resources:
        if not is_instance_valid(deposit) or deposit.resource_type == "wood":
            continue
        for child in deposit.get_children():
            if child.name.begins_with("OreRock_"):
                var digits: int = int(child.name.trim_prefix("OreRock_"))
                KENNEY.tint_meshes(child, rock_color(deposit.resource_type, digits))
            elif child.name.begins_with("Vein_"):
                _recolor_meshes(child, Color(0.98, 0.70, 0.24) if deposit.resource_type == "gold" else _palette(current_planet)["glow"])


func _recolor_meshes(root: Node, color: Color) -> void:
    if root is MeshInstance3D:
        var material := StandardMaterial3D.new()
        material.albedo_color = color
        material.metallic = 0.35
        material.roughness = 0.41
        (root as MeshInstance3D).material_override = material
    for child in root.get_children():
        _recolor_meshes(child, color)


func _palette(planet: String) -> Dictionary:
    match planet:
        "Ziemia":
            return {
                "soil": Color(0.22, 0.35, 0.24),
                "layer": Color(0.31, 0.38, 0.24),
                "dust": Color(0.40, 0.32, 0.24),
                "sky": Color(0.37, 0.55, 0.71),
                "ambient": Color(0.78, 0.84, 0.89),
                "sun": Color(1.0, 0.95, 0.82),
                "rock": Color(0.41, 0.41, 0.39),
                "glow": Color(0.26, 0.71, 0.70),
                "scrub": Color(0.17, 0.47, 0.28)
            }
        "Kepler":
            return {
                "soil": Color(0.17, 0.21, 0.30),
                "layer": Color(0.31, 0.22, 0.36),
                "dust": Color(0.13, 0.35, 0.35),
                "sky": Color(0.15, 0.19, 0.31),
                "ambient": Color(0.52, 0.60, 0.76),
                "sun": Color(0.77, 0.83, 1.0),
                "rock": Color(0.25, 0.31, 0.38),
                "glow": Color(0.23, 0.91, 0.90),
                "scrub": Color(0.38, 0.66, 0.73)
            }
        _:
            return {
                "soil": Color(0.37, 0.205, 0.16),
                "layer": Color(0.48, 0.30, 0.22),
                "dust": Color(0.24, 0.18, 0.175),
                "sky": Color(0.34, 0.32, 0.40),
                "ambient": Color(0.71, 0.69, 0.69),
                "sun": Color(1.0, 0.84, 0.68),
                "rock": Color(0.36, 0.31, 0.30),
                "glow": Color(0.26, 0.84, 0.91),
                "scrub": Color(0.27, 0.41, 0.36)
            }


func _build_decor(scheme: Dictionary) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 20261027
    for i in range(96):
        var location := Vector3(rng.randf_range(-46.0, 46.0), 0.0, rng.randf_range(-46.0, 46.0))
        if Vector2(location.x, location.z + 12.0).length() < 12.5:
            continue
        if Vector2(location.x, location.z - 8.0).length() < 6.3:
            continue
        if Vector2(location.x + 9.0, location.z + 10.0).length() < 4.5:
            continue
        if Vector2(location.x + 25.0, location.z - 9.0).length() < 6.0:
            continue
        if Vector2(location.x - 29.0, location.z - 18.0).length() < 6.0:
            continue

        if i % 4 == 0:
            var pebble = KENNEY.model("nature", "rock-smalla", rng.randf_range(0.42, 1.3))
            if pebble != null:
                pebble.position = location
                pebble.rotation.y = rng.randf_range(0.0, TAU)
                KENNEY.tint_meshes(pebble, scheme["rock"])
                scatter.add_child(pebble)
        elif i % 5 == 0 and current_planet != "Ziemia":
            _add_crystal(location, scheme["glow"], rng.randf_range(0.28, 0.8))
        else:
            _add_scrub(location, scheme["scrub"], rng.randf_range(0.3, 0.8))


func _add_crystal(location: Vector3, color: Color, scale_factor: float) -> void:
    var crystal := MeshInstance3D.new()
    crystal.name = "NonInteractiveCrystal"
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.0
    mesh.bottom_radius = 0.29
    mesh.height = 1.2
    mesh.radial_segments = 5
    crystal.mesh = mesh
    crystal.position = location + Vector3(0.0, 0.6 * scale_factor, 0.0)
    crystal.scale = Vector3.ONE * scale_factor
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 0.34
    crystal.material_override = material
    scatter.add_child(crystal)


func _add_scrub(location: Vector3, color: Color, scale_factor: float) -> void:
    var tuft := MeshInstance3D.new()
    tuft.name = "NonInteractiveScrub"
    var blade_mesh := PrismMesh.new()
    blade_mesh.size = Vector3(0.6, 0.56, 0.68)
    tuft.mesh = blade_mesh
    tuft.position = location + Vector3(0.0, 0.23 * scale_factor, 0.0)
    tuft.scale = Vector3.ONE * scale_factor
    tuft.rotation.y = float((int(location.x * 11.0) + int(location.z)) % 10) * 0.3
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.87
    tuft.material_override = mat
    scatter.add_child(tuft)
