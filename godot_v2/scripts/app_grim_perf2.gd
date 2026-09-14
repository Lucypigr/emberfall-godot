extends "res://scripts/app_grim_perf.gd"

const CombatPool = preload("res://scripts/combat_pool.gd")

# Second browser-performance pass: keep movement at 60 Hz while moving AI
# decisions, label visibility and ground-loot housekeeping off the hot path.

const AI_PHASES := 2
const MAX_GROUND_LOOT := 24
const LABEL_SCAN_MS := 180
const ENEMY_LABEL_DISTANCE_SQ := 240.25
const LOOT_LABEL_DISTANCE_SQ := 121.0

var _last_label_scan_ms := 0
var _combat_pool

func _ready() -> void:
    super._ready()
    if projectiles_root == null:
        return
    _combat_pool = CombatPool.new()
    _combat_pool.setup(
        projectiles_root,
        self,
        _player_core_mesh,
        _player_aura_mesh,
        _enemy_core_mesh,
        _enemy_aura_mesh,
        _player_core_mat,
        _player_aura_mat,
        _enemy_core_mat,
        _enemy_aura_mat,
        _flash_mesh
    )

func _spawn_enemy(force_elite: bool = false, slot: int = -1) -> void:
    super._spawn_enemy(force_elite, slot)
    if enemies.is_empty():
        return
    var index := enemies.size() - 1
    var entry: Dictionary = enemies[index]
    entry["ai_phase"] = int(entry["id"]) % AI_PHASES
    enemies[index] = entry

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    _update_label_visibility()

func _update_enemies(delta: float) -> void:
    var frame_phase := int(Engine.get_physics_frames()) % AI_PHASES
    for i in range(enemies.size() - 1, -1, -1):
        var entry: Dictionary = enemies[i]
        var enemy := entry["node"] as CharacterBody3D
        if not is_instance_valid(enemy):
            enemies.remove_at(i)
            continue

        entry["touch_cd"] = maxf(0.0, float(entry["touch_cd"]) - delta)
        entry["skill_cd"] = maxf(0.0, float(entry["skill_cd"]) - delta)

        var phase := int(entry.get("ai_phase", int(entry["id"]) % AI_PHASES))
        if phase != frame_phase:
            if enemy.velocity.length_squared() > 0.0001:
                enemy.move_and_slide()
            enemies[i] = entry
            continue

        var archetype: Dictionary = entry["archetype"]
        var to_player := player.global_position - enemy.global_position
        to_player.y = 0
        var distance := to_player.length()
        var direction := to_player.normalized() if distance > 0.001 else Vector3.ZERO
        var visual := entry["visual"] as Sprite3D
        if visual != null and absf(to_player.x) > 0.05:
            visual.flip_h = to_player.x > 0.0

        var trigger := float(archetype["low_health_trigger"])
        if not bool(entry["berserk"]) and trigger > 0.0 and float(entry["hp"]) / float(entry["max_hp"]) <= trigger:
            entry["berserk"] = true
            if visual != null:
                visual.modulate = Color(1.0, 0.30, 0.22)

        var speed := float(archetype["speed"])
        if bool(entry["berserk"]):
            speed *= float(archetype["berserk_speed"])

        if String(archetype["behavior"]) == "ranged":
            var desired := float(archetype["desired_range"])
            if distance > desired + 1.4:
                enemy.velocity = direction * speed
            elif distance < desired - 1.4:
                enemy.velocity = -direction * speed * 0.72
            else:
                enemy.velocity = Vector3.ZERO

            if float(entry["skill_cd"]) <= 0.0 and distance <= 8.5:
                entry["skill_cd"] = float(archetype["skill_delay"])
                if randf() <= float(archetype["skill_chance"]):
                    _enemy_cast_projectile(enemy, float(archetype["skill_damage"]))
        else:
            if distance > float(archetype["desired_range"]):
                enemy.velocity = direction * speed
            else:
                enemy.velocity = Vector3.ZERO
                if float(entry["touch_cd"]) <= 0.0:
                    var damage := float(archetype["touch_damage"])
                    if bool(entry["berserk"]):
                        damage *= 1.25
                    _damage_player(damage)
                    entry["touch_cd"] = float(archetype["touch_delay"])

        if enemy.velocity.length_squared() > 0.0001:
            enemy.move_and_slide()
        enemies[i] = entry

func _enemy_cast_projectile(enemy: CharacterBody3D, damage: float) -> void:
    if _combat_pool == null:
        super._enemy_cast_projectile(enemy, damage)
        return
    var projectile: Node3D = _combat_pool.acquire_projectile(true, "EnemyHex_%d" % projectile_serial)
    if projectile == null:
        super._enemy_cast_projectile(enemy, damage)
        return
    projectile_serial += 1
    projectile.global_position = enemy.global_position + Vector3(0, 1.0, 0)
    var destination := player.global_position + Vector3(0, 0.82, 0)
    var tween := create_tween()
    tween.tween_property(projectile, "global_position", destination, 0.62)
    tween.tween_callback(_resolve_enemy_projectile.bind(projectile, destination, damage))

func _spawn_projectile(enemy_id: int, target: CharacterBody3D) -> void:
    if _combat_pool == null:
        super._spawn_projectile(enemy_id, target)
        return
    var projectile: Node3D = _combat_pool.acquire_projectile(false, "RiftBolt_%d" % projectile_serial)
    if projectile == null:
        super._spawn_projectile(enemy_id, target)
        return
    projectile_serial += 1
    projectile.global_position = player.global_position + Vector3(0, 1.02, 0)
    var destination := target.global_position + Vector3(0, 0.95, 0)
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_IN)
    tween.tween_property(projectile, "global_position", destination, PROJECTILE_TRAVEL_TIME)
    tween.tween_callback(_resolve_projectile_hit.bind(enemy_id, projectile))

func _spawn_miss_projectile(destination: Vector3) -> void:
    if _combat_pool == null:
        super._spawn_miss_projectile(destination)
        return
    var projectile: Node3D = _combat_pool.acquire_projectile(false, "RiftMiss_%d" % projectile_serial)
    if projectile == null:
        super._spawn_miss_projectile(destination)
        return
    projectile_serial += 1
    projectile.global_position = player.global_position + Vector3(0, 1.02, 0)
    var tween := create_tween()
    tween.tween_property(projectile, "global_position", destination, PROJECTILE_TRAVEL_TIME)
    tween.tween_callback(_release_or_free_projectile.bind(projectile))

func _resolve_projectile_hit(enemy_id: int, projectile: Node3D) -> void:
    _release_or_free_projectile(projectile)
    var index := _enemy_index_by_id(enemy_id)
    if index >= 0:
        _damage_enemy(index, ATTACK_DAMAGE)

func _resolve_enemy_projectile(projectile: Node3D, destination: Vector3, damage: float) -> void:
    _release_or_free_projectile(projectile)
    var flat_player := player.global_position
    flat_player.y = destination.y
    if flat_player.distance_to(destination) <= 1.35:
        _damage_player(damage)
        _spawn_hit_flash(destination, Color(0.35, 0.55, 1.0))

func _release_or_free_projectile(projectile: Node3D) -> void:
    if not is_instance_valid(projectile):
        return
    if projectile.has_meta("pool_active") and _combat_pool != null:
        _combat_pool.release_projectile(projectile)
    else:
        projectile.queue_free()

func _spawn_hit_flash(position: Vector3, color: Color, scale_to: float = 2.8) -> void:
    if _combat_pool == null:
        super._spawn_hit_flash(position, color, scale_to)
        return
    var flash: MeshInstance3D = _combat_pool.acquire_flash()
    if flash == null:
        super._spawn_hit_flash(position, color, scale_to)
        return
    flash.position = position
    var key := color.to_html(true)
    var mat := _flash_materials.get(key) as StandardMaterial3D
    if mat == null:
        mat = _emissive(color, 2.0)
        _flash_materials[key] = mat
    flash.material_override = mat
    var tween := create_tween()
    tween.tween_property(flash, "scale", Vector3.ONE * scale_to, 0.14)
    tween.tween_callback(_combat_pool.release_flash.bind(flash))

func _spawn_loot_visual(position: Vector3, item: Dictionary) -> void:
    super._spawn_loot_visual(position, item)
    while loot_drops.size() > MAX_GROUND_LOOT:
        var oldest: Dictionary = loot_drops[0]
        var node := oldest.get("node") as Node3D
        if is_instance_valid(node):
            node.queue_free()
        loot_drops.remove_at(0)

func _update_label_visibility() -> void:
    var now := Time.get_ticks_msec()
    if now - _last_label_scan_ms < LABEL_SCAN_MS:
        return
    _last_label_scan_ms = now

    for entry in enemies:
        var enemy := entry.get("node") as Node3D
        var label := entry.get("label") as Label3D
        if is_instance_valid(enemy) and is_instance_valid(label):
            label.visible = player.global_position.distance_squared_to(enemy.global_position) <= ENEMY_LABEL_DISTANCE_SQ

    for entry in loot_drops:
        var drop := entry.get("node") as Node3D
        if not is_instance_valid(drop):
            continue
        var distance_sq := player.global_position.distance_squared_to(drop.global_position)
        for child in drop.get_children():
            if child is Label3D:
                (child as Label3D).visible = distance_sq <= LOOT_LABEL_DISTANCE_SQ

func debug_projectile_count() -> int:
    var active := 0
    if _combat_pool != null:
        active = _combat_pool.active_projectile_count()
    for child in projectiles_root.get_children():
        if not child.has_meta("pool_active"):
            active += 1
    return active

func debug_perf_pass2() -> Dictionary:
    var pool_stats: Dictionary = {}
    if _combat_pool != null:
        pool_stats = _combat_pool.stats()
    return {
        "ai_phases": AI_PHASES,
        "loot_cap": MAX_GROUND_LOOT,
        "label_scan_ms": LABEL_SCAN_MS,
        "pool": pool_stats,
    }
