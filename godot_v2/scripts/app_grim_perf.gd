extends "res://scripts/app_grim.gd"

# Performance layer for the Web/Compatibility build.
# The gameplay script intentionally stays unchanged; this subclass removes the
# most obvious per-shot resource churn and expensive dynamic shadows.

var _player_core_mesh: SphereMesh
var _player_aura_mesh: SphereMesh
var _enemy_core_mesh: SphereMesh
var _enemy_aura_mesh: SphereMesh
var _flash_mesh: SphereMesh

var _player_core_mat: StandardMaterial3D
var _player_aura_mat: StandardMaterial3D
var _enemy_core_mat: StandardMaterial3D
var _enemy_aura_mat: StandardMaterial3D
var _flash_materials: Dictionary = {}
var _last_loot_scan_ms := 0

func _ready() -> void:
    _init_perf_resources()
    super._ready()

func _init_perf_resources() -> void:
    _player_core_mesh = _sphere(0.18)
    _player_aura_mesh = _sphere(0.31)
    _enemy_core_mesh = _sphere(0.17)
    _enemy_aura_mesh = _sphere(0.29)
    _flash_mesh = _sphere(0.18)

    _player_core_mat = _emissive(Color(1.0, 0.72, 0.22), 3.0)
    _player_aura_mat = _emissive(Color(1.0, 0.24, 0.04, 0.22), 1.5, true)
    _enemy_core_mat = _emissive(Color(0.36, 0.60, 1.0), 3.0)
    _enemy_aura_mat = _emissive(Color(0.22, 0.36, 1.0, 0.22), 1.5, true)

func _sphere(radius: float) -> SphereMesh:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 12
    mesh.rings = 6
    return mesh

func _emissive(color: Color, energy: float, transparent: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = Color(color.r, color.g, color.b)
    mat.emission_energy_multiplier = energy
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    if transparent:
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return mat

func _build_world() -> void:
    super._build_world()
    var key_light := get_node_or_null("KeyLight") as DirectionalLight3D
    if key_light != null:
        key_light.shadow_enabled = false
    for child in get_children():
        if child is GeometryInstance3D:
            (child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_player() -> void:
    super._build_player()
    if player == null:
        return
    for child in player.get_children():
        if child is GeometryInstance3D:
            (child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _spawn_enemy(force_elite: bool = false, slot: int = -1) -> void:
    super._spawn_enemy(force_elite, slot)
    if enemies.is_empty():
        return
    var entry: Dictionary = enemies.back()
    var visual := entry.get("visual") as Sprite3D
    if visual != null:
        visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var label := entry.get("label") as Label3D
    if label != null:
        label.outline_size = 4

func _create_orb(name_text: String, _core_color: Color, _aura_color: Color, _core_radius: float, _aura_radius: float) -> Node3D:
    var projectile := Node3D.new()
    projectile.name = name_text
    var enemy_orb := name_text.begins_with("EnemyHex_")

    var core := MeshInstance3D.new()
    core.mesh = _enemy_core_mesh if enemy_orb else _player_core_mesh
    core.material_override = _enemy_core_mat if enemy_orb else _player_core_mat
    core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    projectile.add_child(core)

    var aura := MeshInstance3D.new()
    aura.mesh = _enemy_aura_mesh if enemy_orb else _player_aura_mesh
    aura.material_override = _enemy_aura_mat if enemy_orb else _player_aura_mat
    aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    projectile.add_child(aura)
    return projectile

func _spawn_hit_flash(position: Vector3, color: Color, scale_to: float = 2.8) -> void:
    var flash := MeshInstance3D.new()
    flash.mesh = _flash_mesh
    flash.position = position
    flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    var key := color.to_html(true)
    var mat := _flash_materials.get(key) as StandardMaterial3D
    if mat == null:
        mat = _emissive(color, 2.0)
        _flash_materials[key] = mat
    flash.material_override = mat
    add_child(flash)

    var tween := create_tween()
    tween.tween_property(flash, "scale", Vector3.ONE * scale_to, 0.14)
    tween.tween_callback(flash.queue_free)

func _spawn_loot_visual(position: Vector3, item: Dictionary) -> void:
    super._spawn_loot_visual(position, item)
    if loot_drops.is_empty():
        return
    var entry: Dictionary = loot_drops.back()
    var drop := entry.get("node") as Node3D
    if drop == null:
        return
    for child in drop.get_children():
        if child is GeometryInstance3D:
            (child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        if child is Label3D:
            (child as Label3D).outline_size = 4

func _update_loot() -> void:
    # Pickup distance does not need a 60 Hz scan. 12.5 Hz is responsive while
    # avoiding a growing per-frame loop when many drops are on the ground.
    var now := Time.get_ticks_msec()
    if now - _last_loot_scan_ms < 80:
        return
    _last_loot_scan_ms = now
    super._update_loot()

func debug_perf_layer() -> bool:
    return true
