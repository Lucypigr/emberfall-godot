extends "res://scripts/app_grim_perf2.gd"

const GameplayUIScript = preload("res://scripts/gameplay_ui.gd")
const WeaponSkillSystem = preload("res://scripts/weapon_skill_system.gd")

var equipped_weapon: Dictionary = {}
var weapon_inventory: Array[Dictionary] = []
var skill_cooldowns: Array[float] = [0.0, 0.0, 0.0]
var last_aim_direction := Vector3(1.0, 0.0, 0.0)
var _skill_ui_accumulator := 0.0

func _ready() -> void:
    equipped_weapon = WeaponSkillSystem.starter_weapon()
    weapon_inventory.append(equipped_weapon.duplicate(true))
    super._ready()
    _refresh_gameplay_ui()

func _build_ui() -> void:
    ui = GameplayUIScript.new()
    ui.name = "MobileUI"
    add_child(ui)
    ui.setup(ui_font)
    ui.movement_changed.connect(func(value: Vector2): move_input = value)
    ui.attack_requested.connect(_attack)
    var gameplay_ui := ui as RiftGameplayUI
    gameplay_ui.skill_requested.connect(_use_skill)
    gameplay_ui.weapon_equip_requested.connect(_equip_weapon_index)
    ui.set_hp(player_hp, player_max_hp)
    ui.set_hint("手機：搖桿＋攻擊／技能｜電腦：WASD＋左鍵、1/2/3 技能｜拾取武器可直接換裝")

func _physics_process(delta: float) -> void:
    for i in range(skill_cooldowns.size()):
        skill_cooldowns[i] = maxf(0.0, skill_cooldowns[i] - delta)
    _skill_ui_accumulator += delta
    super._physics_process(delta)
    if _skill_ui_accumulator >= 0.10:
        _skill_ui_accumulator = 0.0
        var gameplay_ui := ui as RiftGameplayUI
        if gameplay_ui != null:
            gameplay_ui.set_skill_cooldowns(skill_cooldowns)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key := event as InputEventKey
        if key.pressed and not key.echo:
            if key.keycode == KEY_1:
                _use_skill(0)
                get_viewport().set_input_as_handled()
                return
            if key.keycode == KEY_2:
                _use_skill(1)
                get_viewport().set_input_as_handled()
                return
            if key.keycode == KEY_3:
                _use_skill(2)
                get_viewport().set_input_as_handled()
                return
    super._unhandled_input(event)

func _attack() -> void:
    if attack_cooldown > 0.0 or enemies.is_empty():
        return
    var index := _nearest_enemy_index()
    if index < 0:
        return
    var entry: Dictionary = enemies[index]
    var enemy := entry["node"] as CharacterBody3D
    var direction := enemy.global_position - player.global_position
    direction.y = 0
    if direction.length() > _weapon_range():
        ui.set_hint("敵人超出武器距離")
        return
    if direction.length() > 0.05:
        last_aim_direction = direction.normalized()
    _perform_basic_attack(index)

func _attack_at_screen(screen_position: Vector2) -> void:
    if attack_cooldown > 0.0 or camera == null or player == null:
        return
    var ground_point := _screen_to_ground(screen_position)
    var aim := ground_point - player.global_position
    aim.y = 0
    if aim.length() > 0.12:
        last_aim_direction = aim.normalized()
        if player_visual != null and absf(last_aim_direction.x) > 0.02:
            player_visual.flip_h = last_aim_direction.x < 0.0

    var weapon_type := String(equipped_weapon.get("weapon_type", "bow"))
    var range := _weapon_range()
    var screen_target := _enemy_index_near_screen(screen_position)
    if screen_target >= 0:
        var target := enemies[screen_target]["node"] as CharacterBody3D
        if is_instance_valid(target) and player.global_position.distance_to(target.global_position) <= range:
            _perform_basic_attack(screen_target)
            return

    var hit_index := _enemy_index_on_aim(last_aim_direction, range)
    if hit_index >= 0:
        _perform_basic_attack(hit_index)
        return

    attack_cooldown = _weapon_cooldown()
    if weapon_type == "blade":
        _spawn_hit_flash(player.global_position + last_aim_direction * 1.25 + Vector3(0, 0.8, 0), Color(0.92, 0.92, 1.0), 2.2)
    else:
        _spawn_miss_projectile(player.global_position + last_aim_direction * range + Vector3(0, 1.0, 0))

func _perform_basic_attack(index: int) -> void:
    if index < 0 or index >= enemies.size():
        return
    var entry: Dictionary = enemies[index]
    var enemy := entry["node"] as CharacterBody3D
    if not is_instance_valid(enemy):
        return
    attack_cooldown = _weapon_cooldown()
    var weapon_type := String(equipped_weapon.get("weapon_type", "bow"))
    var damage := _roll_weapon_damage(1.0)
    if weapon_type == "blade":
        _spawn_hit_flash(enemy.global_position + Vector3(0, 0.85, 0), Color(0.88, 0.92, 1.0), 2.5)
        _damage_enemy(index, damage)
    else:
        _spawn_gameplay_projectile(int(entry["id"]), enemy, damage, 0.0, 0.0)

func _spawn_gameplay_projectile(enemy_id: int, target: CharacterBody3D, damage: float, burst_radius: float, splash_damage: float) -> void:
    if not is_instance_valid(target):
        return
    projectile_serial += 1
    var projectile: Node3D = null
    if _combat_pool != null:
        projectile = _combat_pool.acquire_projectile(false, "WeaponBolt_%d" % projectile_serial)
    if projectile == null:
        projectile = _create_orb("WeaponBolt_%d" % projectile_serial, Color(1.0, 0.72, 0.22), Color(1.0, 0.24, 0.04), 0.18, 0.31)
        projectiles_root.add_child(projectile)
    projectile.global_position = player.global_position + Vector3(0, 1.02, 0)
    var destination := target.global_position + Vector3(0, 0.95, 0)
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_IN)
    tween.tween_property(projectile, "global_position", destination, PROJECTILE_TRAVEL_TIME)
    tween.tween_callback(_resolve_gameplay_projectile.bind(enemy_id, projectile, damage, burst_radius, splash_damage))

func _resolve_gameplay_projectile(enemy_id: int, projectile: Node3D, damage: float, burst_radius: float, splash_damage: float) -> void:
    _release_or_free_projectile(projectile)
    var index := _enemy_index_by_id(enemy_id)
    if index < 0:
        return
    var enemy := enemies[index]["node"] as CharacterBody3D
    var hit_position := enemy.global_position if is_instance_valid(enemy) else player.global_position
    _damage_enemy(index, damage)
    if burst_radius > 0.0 and splash_damage > 0.0:
        _spawn_hit_flash(hit_position + Vector3(0, 0.8, 0), Color(1.0, 0.24, 0.08), 4.8)
        _damage_area(hit_position, burst_radius, splash_damage, enemy_id)

func _damage_area(center: Vector3, radius: float, damage: float, exclude_id: int = -1) -> void:
    var targets: Array[int] = []
    for entry in enemies:
        var id := int(entry["id"])
        if id == exclude_id:
            continue
        var enemy := entry["node"] as CharacterBody3D
        if is_instance_valid(enemy) and enemy.global_position.distance_to(center) <= radius:
            targets.append(id)
    for id in targets:
        var index := _enemy_index_by_id(id)
        if index >= 0:
            _damage_enemy(index, damage)

func _use_skill(slot: int) -> void:
    if slot < 0 or slot >= skill_cooldowns.size() or skill_cooldowns[slot] > 0.0:
        return
    match slot:
        0: _use_weapon_skill()
        1: _use_burst_skill()
        2: _use_dash_skill()
    _refresh_gameplay_ui()

func _use_weapon_skill() -> void:
    var weapon_type := String(equipped_weapon.get("weapon_type", "bow"))
    skill_cooldowns[0] = 2.4
    if weapon_type == "blade":
        var targets := _enemy_ids_in_range(3.15, 99)
        _spawn_hit_flash(player.global_position + Vector3(0, 0.8, 0), Color(0.72, 0.78, 1.0), 5.2)
        for id in targets:
            var index := _enemy_index_by_id(id)
            if index >= 0:
                _damage_enemy(index, _roll_weapon_damage(0.90))
        ui.set_hint("旋刃：近身範圍斬擊")
        return

    var target_ids := _enemy_ids_in_range(_weapon_range(), 3)
    if target_ids.is_empty():
        for angle in [-0.16, 0.0, 0.16]:
            var direction := last_aim_direction.rotated(Vector3.UP, angle)
            _spawn_miss_projectile(player.global_position + direction * _weapon_range() + Vector3(0, 1.0, 0))
    else:
        for id in target_ids:
            var index := _enemy_index_by_id(id)
            if index >= 0:
                var enemy := enemies[index]["node"] as CharacterBody3D
                _spawn_gameplay_projectile(id, enemy, _roll_weapon_damage(0.78), 0.0, 0.0)
    ui.set_hint("%s：一次發射三道攻擊" % WeaponSkillSystem.skill_name(0, weapon_type))

func _use_burst_skill() -> void:
    skill_cooldowns[1] = 4.5
    var weapon_type := String(equipped_weapon.get("weapon_type", "bow"))
    var range := maxf(_weapon_range(), 3.0) if weapon_type != "blade" else 3.0
    var targets := _enemy_ids_in_range(range, 1)
    if targets.is_empty():
        ui.set_hint("爆裂打擊：範圍內沒有敵人")
        return
    var id := targets[0]
    var index := _enemy_index_by_id(id)
    if index < 0:
        return
    var enemy := enemies[index]["node"] as CharacterBody3D
    if weapon_type == "blade":
        var center := enemy.global_position
        _damage_enemy(index, _roll_weapon_damage(1.55))
        _spawn_hit_flash(center + Vector3(0, 0.8, 0), Color(1.0, 0.22, 0.06), 5.0)
        _damage_area(center, 2.8, _roll_weapon_damage(0.60), id)
    else:
        _spawn_gameplay_projectile(id, enemy, _roll_weapon_damage(1.30), 2.8, _roll_weapon_damage(0.60))
    ui.set_hint("爆裂打擊：主目標＋範圍傷害")

func _use_dash_skill() -> void:
    skill_cooldowns[2] = 5.0
    var direction := _movement_direction()
    if direction.length_squared() < 0.01:
        direction = last_aim_direction
    if direction.length_squared() < 0.01:
        direction = Vector3(1, 0, 0)
    direction = direction.normalized()
    var start := player.global_position
    var destination := start + direction * 4.6
    destination.x = clampf(destination.x, -WORLD_LIMIT, WORLD_LIMIT)
    destination.z = clampf(destination.z, -WORLD_LIMIT, WORLD_LIMIT)
    _spawn_hit_flash(start + Vector3(0, 0.65, 0), Color(0.30, 0.62, 1.0), 3.2)
    player.global_position = destination
    _spawn_hit_flash(destination + Vector3(0, 0.65, 0), Color(0.30, 0.62, 1.0), 3.2)
    ui.set_hint("裂隙衝刺：快速位移")

func _movement_direction() -> Vector3:
    var input := move_input
    if input.length() <= 0.03:
        input = Vector2.ZERO
        if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input.x -= 1
        if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input.x += 1
        if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input.y -= 1
        if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input.y += 1
    if input.length() <= 0.03:
        return Vector3.ZERO
    input = input.normalized()
    return Vector3(input.x, 0, input.y)

func _enemy_ids_in_range(range: float, limit: int) -> Array[int]:
    var result: Array[int] = []
    var candidates: Array[Dictionary] = []
    for entry in enemies:
        var enemy := entry["node"] as CharacterBody3D
        if not is_instance_valid(enemy):
            continue
        var distance := player.global_position.distance_to(enemy.global_position)
        if distance <= range:
            candidates.append({"id": int(entry["id"]), "distance": distance})
    candidates.sort_custom(func(a: Dictionary, b: Dictionary): return float(a["distance"]) < float(b["distance"]))
    for i in range(mini(limit, candidates.size())):
        result.append(int(candidates[i]["id"]))
    return result

func _weapon_damage() -> float:
    return float(equipped_weapon.get("damage", ATTACK_DAMAGE))

func _weapon_range() -> float:
    return float(equipped_weapon.get("range", ATTACK_RANGE))

func _weapon_cooldown() -> float:
    return float(equipped_weapon.get("cooldown", ATTACK_COOLDOWN))

func _roll_weapon_damage(multiplier: float) -> float:
    var damage := _weapon_damage() * multiplier
    if randf() * 100.0 < float(equipped_weapon.get("crit_chance", 5.0)):
        damage *= 1.65
    return damage

func _update_loot() -> void:
    var now := Time.get_ticks_msec()
    if now - _last_loot_scan_ms < 80:
        return
    _last_loot_scan_ms = now
    for i in range(loot_drops.size() - 1, -1, -1):
        var entry: Dictionary = loot_drops[i]
        var node := entry["node"] as Node3D
        if not is_instance_valid(node):
            loot_drops.remove_at(i)
            continue
        if player.global_position.distance_to(node.global_position) <= LOOT_PICKUP_RANGE:
            var item: Dictionary = entry["item"]
            _pickup_item(item)
            node.queue_free()
            loot_drops.remove_at(i)

func _pickup_item(item: Dictionary) -> void:
    picked_loot += 1
    if String(item.get("slot", "")) == "武器":
        var weapon := WeaponSkillSystem.normalize_weapon(item)
        weapon_inventory.append(weapon)
        var auto_equipped := false
        if float(weapon.get("score", 0.0)) > float(equipped_weapon.get("score", 0.0)) * 1.12:
            equipped_weapon = weapon.duplicate(true)
            auto_equipped = true
        _refresh_gameplay_ui()
        ui.set_hint("拾取武器：%s%s" % [String(weapon["name"]), " · 已自動換裝" if auto_equipped else " · 可到裝備切換"])
    else:
        ui.set_hint("拾取：%s · %s · 共 %d 件" % [String(item["name"]), String(item["slot"]), picked_loot])

func _equip_weapon_index(index: int) -> void:
    if index < 0 or index >= weapon_inventory.size():
        return
    equipped_weapon = weapon_inventory[index].duplicate(true)
    attack_cooldown = 0.0
    _refresh_gameplay_ui()
    ui.set_hint("已裝備：%s" % String(equipped_weapon["name"]))

func _refresh_gameplay_ui() -> void:
    var gameplay_ui := ui as RiftGameplayUI
    if gameplay_ui == null:
        return
    gameplay_ui.set_weapon_status(WeaponSkillSystem.describe_weapon(equipped_weapon))
    var names: Array[String] = []
    var weapon_type := String(equipped_weapon.get("weapon_type", "bow"))
    for i in range(3):
        names.append(WeaponSkillSystem.skill_name(i, weapon_type))
    gameplay_ui.set_skill_names(names)
    gameplay_ui.set_skill_cooldowns(skill_cooldowns)
    gameplay_ui.set_weapon_inventory(weapon_inventory, String(equipped_weapon.get("name", "")))

func debug_weapon_state() -> Dictionary:
    return equipped_weapon.duplicate(true)

func debug_weapon_inventory_count() -> int:
    return weapon_inventory.size()

func debug_skill_ids() -> Array[String]:
    var result: Array[String] = []
    for skill in WeaponSkillSystem.skill_catalog():
        result.append(String(skill["id"]))
    return result

func debug_skill_cooldowns() -> Array[float]:
    return skill_cooldowns.duplicate()

func debug_add_test_weapon(weapon_type: String) -> void:
    var item := {
        "id": "rift_blade" if weapon_type == "blade" else ("rift_focus" if weapon_type == "focus" else "rust_bow"),
        "base_name": "測試武器",
        "name": "測試武器",
        "slot": "武器",
        "level": 1,
        "rarity": "普通",
        "prefix": {},
        "suffix": {},
        "color": Color.WHITE,
    }
    weapon_inventory.append(WeaponSkillSystem.normalize_weapon(item))
    _refresh_gameplay_ui()
