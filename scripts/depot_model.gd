extends Node3D
## WOW 0.5 — magazyn robotycznej kolonii.
## Sam model graficzny, bez kolizji: te pozostaja w main.gd.

const KENNEY = preload("res://scripts/kenney_assets.gd")


func _ready() -> void:
    name = "IndustrialWarehouseVisual"
    var graphite := _material(Color(0.12, 0.18, 0.22))
    var steel := _material(Color(0.40, 0.51, 0.55))
    var orange := _material(Color(0.94, 0.45, 0.10))
    var cyan := _material(Color(0.21, 0.90, 0.95), true)

    # Betonowa baza, stalowy magazyn i wysuniety daszek dla ladunkow.
    _box("Foundation", Vector3(0, 0.19, 0), Vector3(5.45, 0.38, 5.2), graphite)
    _box("MainStorage", Vector3(0, 1.62, -0.58), Vector3(4.2, 2.45, 3.18), steel)
    _box("Roof", Vector3(0, 2.99, -0.54), Vector3(4.75, 0.31, 3.68), graphite)
    _box("FrontLoadingDock", Vector3(0, 0.48, 1.64), Vector3(3.8, 0.20, 1.68), steel)
    _box("DockGate", Vector3(0, 1.48, 1.11), Vector3(2.7, 1.55, 0.13), graphite)
    _box("GateLight", Vector3(0, 2.49, 1.19), Vector3(2.6, 0.13, 0.10), cyan)
    _box("RoofTrim", Vector3(0, 3.19, 1.02), Vector3(4.75, 0.12, 0.20), orange)

    for side in [-1.0, 1.0]:
        _box("WarehouseSideBeam", Vector3(side * 2.12, 1.63, -0.58), Vector3(0.21, 2.52, 3.38), graphite)
        _box("CranePost", Vector3(side * 1.83, 1.04, 1.69), Vector3(0.15, 1.7, 0.15), orange)
        _box("LoadingGuide", Vector3(side * 1.80, 0.60, 1.74), Vector3(0.14, 0.11, 1.44), cyan)
        _box("RoofSideIndicator", Vector3(side * 1.82, 3.18, 1.08), Vector3(0.54, 0.1, 0.07), cyan)

    # Kontenery/paczki z autorskiej paczki Kenney Factory Kit.
    var crates: Array[Vector3] = [
        Vector3(-1.1, 0.55, 1.74),
        Vector3(1.0, 0.55, 1.73),
        Vector3(-0.8, 1.10, 1.26)
    ]
    for i in range(crates.size()):
        var model = KENNEY.model("factory", "box-large" if i == 1 else "box-small", 1.20)
        if model != null:
            model.position = crates[i]
            add_child(model)

    var label := Label3D.new()
    label.name = "DepotTitle"
    label.text = "MAGAZYN"
    label.position = Vector3(0, 3.75, 0)
    label.font_size = 42
    label.pixel_size = 0.008
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(label)


func _box(part: String, pos: Vector3, size: Vector3, mat: Material) -> void:
    var item := MeshInstance3D.new()
    item.name = part
    var mesh := BoxMesh.new()
    mesh.size = size
    item.mesh = mesh
    item.position = pos
    item.material_override = mat
    add_child(item)


func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.40
    mat.roughness = 0.52
    if glow:
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return mat
