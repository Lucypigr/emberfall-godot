class_name RiftRegionMap
extends Node3D

const HALF_WIDTH := 34.0
const NORTH_EDGE := -150.0
const SOUTH_EDGE := 150.0
const REGION_LENGTH := 300.0

var _materials: Dictionary = {}

func build() -> void:
    name = "Region01_ShatteredMarch"
    _make_materials()
    _build_ground()
    _build_main_road()
    _build_regions()
    _build_boundaries()

func clamp_player(position: Vector3) -> Vector3:
    position.x = clampf(position.x, -HALF_WIDTH + 1.5, HALF_WIDTH - 1.5)
    position.z = clampf(position.z, NORTH_EDGE + 2.0, SOUTH_EDGE - 2.0)
    return position

func spawn_position() -> Vector3:
    return Vector3(0, 0, 128)

func enemy_spawn_position(slot: int, serial: int) -> Vector3:
    var zones := [108.0, 72.0, 30.0, -18.0, -62.0, -108.0]
    var z: float = zones[(slot + serial) % zones.size()] + randf_range(-10.0, 10.0)
    var road_center := _road_x(z)
    var side := -1.0 if (slot + serial) % 2 == 0 else 1.0
    return Vector3(clampf(road_center + side * randf_range(5.0, 14.0), -29.0, 29.0), 0, z)

func _make_materials() -> void:
    _materials["earth"] = _material(Color(0.055, 0.075, 0.060), 1.0)
    _materials["road"] = _material(Color(0.19, 0.155, 0.105), 1.0)
    _materials["grass"] = _material(Color(0.075, 0.13, 0.075), 1.0)
    _materials["marsh"] = _material(Color(0.045, 0.095, 0.09), 0.92)
    _materials["rock"] = _material(Color(0.12, 0.115, 0.105), 0.96)
    _materials["ruin"] = _material(Color(0.21, 0.19, 0.16), 0.94)
    _materials["rift"] = _material(Color(0.16, 0.045, 0.075), 0.9, Color(0.34, 0.02, 0.08))
    _materials["water"] = _material(Color(0.025, 0.13, 0.17, 0.72), 0.32)

func _material(color: Color, roughness: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    if color.a < 0.99:
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    if emission != Color.BLACK:
        mat.emission_enabled = true
        mat.emission = emission
        mat.emission_energy_multiplier = 1.8
    return mat

func _build_ground() -> void:
    _box("Ground", Vector3(0, -0.16, 0), Vector3(HALF_WIDTH * 2.0, 0.30, REGION_LENGTH), _materials["earth"], true)

func _build_main_road() -> void:
    for z in range(int(NORTH_EDGE) + 3, int(SOUTH_EDGE) - 2, 6):
        var zf := float(z)
        var width := 8.2 + sin(zf * 0.07) * 1.1
        _box("Road_%d" % z, Vector3(_road_x(zf), 0.025, zf), Vector3(width, 0.05, 6.4), _materials["road"])

func _road_x(z: float) -> float:
    return sin(z * 0.038) * 7.0 + sin(z * 0.091) * 2.2

func _build_regions() -> void:
    _camp_region()
    _forest_region()
    _ruins_region()
    _marsh_region()
    _canyon_region()
    _rift_region()

func _camp_region() -> void:
    for p in [Vector3(-10,0.5,132), Vector3(10,0.5,128), Vector3(-14,0.5,116), Vector3(13,0.5,112)]:
        _box("CampProp", p, Vector3(2.4, 1.0, 2.4), _materials["ruin"], true)
    _box("CampGateL", Vector3(-5.8,1.5,101), Vector3(1.2,3.0,1.2), _materials["ruin"], true)
    _box("CampGateR", Vector3(5.8,1.5,101), Vector3(1.2,3.0,1.2), _materials["ruin"], true)

func _forest_region() -> void:
    for i in range(42):
        var z := randf_range(52.0, 98.0)
        var center := _road_x(z)
        var side := -1.0 if i % 2 == 0 else 1.0
        var x := center + side * randf_range(8.0, 29.0)
        _tree(Vector3(x, 0, z), randf_range(0.8, 1.45))

func _ruins_region() -> void:
    for i in range(18):
        var z := randf_range(8.0, 48.0)
        var side := -1.0 if i % 2 == 0 else 1.0
        var x := _road_x(z) + side * randf_range(9.0, 25.0)
        _box("Ruin_%d" % i, Vector3(x, randf_range(0.5,1.2), z), Vector3(randf_range(1.2,3.8), randf_range(1.0,2.4), randf_range(1.0,3.0)), _materials["ruin"], true)
    _box("Bridge", Vector3(_road_x(7), 0.22, 4), Vector3(10,0.4,10), _materials["ruin"], true)

func _marsh_region() -> void:
    for i in range(13):
        var z := randf_range(-42.0, 2.0)
        var x := randf_range(-28.0, 28.0)
        if absf(x - _road_x(z)) < 6.5: continue
        _box("Pool_%d" % i, Vector3(x,-0.03,z), Vector3(randf_range(3.5,8.0),0.04,randf_range(3.0,7.0)), _materials["water"])
    for i in range(24):
        var z := randf_range(-42.0, 2.0)
        _rock(Vector3(randf_range(-30,30),0,z), randf_range(0.5,1.3))

func _canyon_region() -> void:
    for z in range(-96, -44, 7):
        var center := _road_x(float(z))
        _rock(Vector3(center - randf_range(12,19),0,float(z)), randf_range(1.5,2.8), true)
        _rock(Vector3(center + randf_range(12,19),0,float(z)), randf_range(1.5,2.8), true)

func _rift_region() -> void:
    for i in range(22):
        var z := randf_range(-143.0, -101.0)
        var x := randf_range(-29.0, 29.0)
        if absf(x - _road_x(z)) < 5.0: continue
        _rock(Vector3(x,0,z), randf_range(0.8,2.0))
    for i in range(8):
        var z := -108.0 - float(i) * 4.2
        _box("RiftSpire_%d" % i, Vector3(_road_x(z) + (-1 if i%2==0 else 1) * randf_range(7,14), randf_range(1.4,2.8), z), Vector3(randf_range(0.7,1.4), randf_range(2.8,5.6), randf_range(0.7,1.4)), _materials["rift"], true)

func _build_boundaries() -> void:
    for z in range(int(NORTH_EDGE), int(SOUTH_EDGE) + 1, 8):
        _rock(Vector3(-HALF_WIDTH - 1.2,0,float(z)), randf_range(1.4,2.6), true)
        _rock(Vector3(HALF_WIDTH + 1.2,0,float(z)), randf_range(1.4,2.6), true)

func _tree(pos: Vector3, scale_value: float) -> void:
    var trunk := _box("Tree", pos + Vector3(0,1.0*scale_value,0), Vector3(0.7,2.0,0.7)*scale_value, _materials["rock"], true)
    var crown := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.2 * scale_value
    mesh.bottom_radius = 1.7 * scale_value
    mesh.height = 3.4 * scale_value
    crown.mesh = mesh
    crown.position = pos + Vector3(0,3.0*scale_value,0)
    crown.material_override = _materials["grass"]
    add_child(crown)

func _rock(pos: Vector3, scale_value: float, collision := false) -> void:
    var size := Vector3(1.4, randf_range(1.0,2.0), 1.2) * scale_value
    _box("Rock", pos + Vector3(0,size.y*0.5,0), size, _materials["rock"], collision)

func _box(node_name: String, pos: Vector3, size: Vector3, material: Material, collision := false) -> MeshInstance3D:
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    mesh_node.position = pos
    mesh_node.material_override = material
    add_child(mesh_node)
    if collision:
        var body := StaticBody3D.new()
        var shape_node := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        shape_node.shape = shape
        body.position = pos
        body.add_child(shape_node)
        add_child(body)
    return mesh_node
