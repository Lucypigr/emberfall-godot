extends RefCounted

# Small fixed pools for browser builds. Visual resources are shared by the
# caller; the pool only reuses Node3D/MeshInstance3D objects.

const PROJECTILE_PREWARM := 10
const PROJECTILE_LIMIT := 28
const FLASH_PREWARM := 14
const FLASH_LIMIT := 32

var projectile_root: Node3D
var effect_root: Node3D
var player_core_mesh: SphereMesh
var player_aura_mesh: SphereMesh
var enemy_core_mesh: SphereMesh
var enemy_aura_mesh: SphereMesh
var player_core_mat: StandardMaterial3D
var player_aura_mat: StandardMaterial3D
var enemy_core_mat: StandardMaterial3D
var enemy_aura_mat: StandardMaterial3D
var flash_mesh: SphereMesh

var player_projectiles: Array[Node3D] = []
var enemy_projectiles: Array[Node3D] = []
var flashes: Array[MeshInstance3D] = []

func setup(
    p_root: Node3D,
    e_root: Node3D,
    p_core_mesh: SphereMesh,
    p_aura_mesh: SphereMesh,
    e_core_mesh: SphereMesh,
    e_aura_mesh: SphereMesh,
    p_core_mat: StandardMaterial3D,
    p_aura_mat: StandardMaterial3D,
    e_core_mat: StandardMaterial3D,
    e_aura_mat: StandardMaterial3D,
    shared_flash_mesh: SphereMesh
) -> void:
    projectile_root = p_root
    effect_root = e_root
    player_core_mesh = p_core_mesh
    player_aura_mesh = p_aura_mesh
    enemy_core_mesh = e_core_mesh
    enemy_aura_mesh = e_aura_mesh
    player_core_mat = p_core_mat
    player_aura_mat = p_aura_mat
    enemy_core_mat = e_core_mat
    enemy_aura_mat = e_aura_mat
    flash_mesh = shared_flash_mesh

    for i in range(PROJECTILE_PREWARM):
        player_projectiles.append(_make_projectile(false, "PlayerPool_%d" % i))
        enemy_projectiles.append(_make_projectile(true, "EnemyPool_%d" % i))
    for i in range(FLASH_PREWARM):
        flashes.append(_make_flash("FlashPool_%d" % i))

func acquire_projectile(enemy_orb: bool, node_name: String) -> Node3D:
    var pool: Array[Node3D] = enemy_projectiles if enemy_orb else player_projectiles
    for projectile in pool:
        if not bool(projectile.get_meta("pool_active", false)):
            _set_projectile_active(projectile, true)
            projectile.name = node_name
            return projectile

    if pool.size() < PROJECTILE_LIMIT:
        var created := _make_projectile(enemy_orb, node_name)
        pool.append(created)
        _set_projectile_active(created, true)
        return created

    return null

func release_projectile(projectile: Node3D) -> void:
    if not is_instance_valid(projectile):
        return
    _set_projectile_active(projectile, false)

func acquire_flash() -> MeshInstance3D:
    for flash in flashes:
        if not bool(flash.get_meta("pool_active", false)):
            flash.set_meta("pool_active", true)
            flash.visible = true
            flash.scale = Vector3.ONE
            return flash

    if flashes.size() < FLASH_LIMIT:
        var created := _make_flash("FlashPool_%d" % flashes.size())
        flashes.append(created)
        created.set_meta("pool_active", true)
        created.visible = true
        return created

    return null

func release_flash(flash: MeshInstance3D) -> void:
    if not is_instance_valid(flash):
        return
    flash.visible = false
    flash.scale = Vector3.ONE
    flash.set_meta("pool_active", false)

func active_projectile_count() -> int:
    var active := 0
    for projectile in player_projectiles:
        if bool(projectile.get_meta("pool_active", false)):
            active += 1
    for projectile in enemy_projectiles:
        if bool(projectile.get_meta("pool_active", false)):
            active += 1
    return active

func stats() -> Dictionary:
    return {
        "player_projectiles": player_projectiles.size(),
        "enemy_projectiles": enemy_projectiles.size(),
        "flashes": flashes.size(),
    }

func _make_projectile(enemy_orb: bool, node_name: String) -> Node3D:
    var projectile := Node3D.new()
    projectile.name = node_name
    projectile.set_meta("pool_active", false)

    var core := MeshInstance3D.new()
    core.name = "Core"
    core.mesh = enemy_core_mesh if enemy_orb else player_core_mesh
    core.material_override = enemy_core_mat if enemy_orb else player_core_mat
    core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    core.visible = false
    projectile.add_child(core)

    var aura := MeshInstance3D.new()
    aura.name = "Aura"
    aura.mesh = enemy_aura_mesh if enemy_orb else player_aura_mesh
    aura.material_override = enemy_aura_mat if enemy_orb else player_aura_mat
    aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    aura.visible = false
    projectile.add_child(aura)

    projectile_root.add_child(projectile)
    return projectile

func _set_projectile_active(projectile: Node3D, active: bool) -> void:
    projectile.set_meta("pool_active", active)
    projectile.scale = Vector3.ONE
    for child in projectile.get_children():
        if child is GeometryInstance3D:
            (child as GeometryInstance3D).visible = active

func _make_flash(node_name: String) -> MeshInstance3D:
    var flash := MeshInstance3D.new()
    flash.name = node_name
    flash.mesh = flash_mesh
    flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    flash.visible = false
    flash.set_meta("pool_active", false)
    effect_root.add_child(flash)
    return flash
