extends "res://scripts/app_arpg_hud.gd"

const RegionMapScript = preload("res://scripts/region_map.gd")
var region_map: RiftRegionMap

func _build_world() -> void:
    var environment_node := WorldEnvironment.new()
    environment_node.name = "WorldEnvironment"
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.018, 0.024, 0.030)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.43, 0.50, 0.58)
    environment.ambient_light_energy = 0.68
    environment_node.environment = environment
    add_child(environment_node)

    var light := DirectionalLight3D.new()
    light.name = "RegionLight"
    light.rotation_degrees = Vector3(-58, -34, 0)
    light.light_energy = 1.08
    light.shadow_enabled = false
    add_child(light)

    region_map = RegionMapScript.new()
    add_child(region_map)
    region_map.build()

func _build_player() -> void:
    super._build_player()
    if region_map != null:
        player.position = region_map.spawn_position()

func _spawn_enemy(force_elite: bool = false, slot: int = -1) -> void:
    super._spawn_enemy(force_elite, slot)
    if region_map == null or enemies.is_empty():
        return
    var entry: Dictionary = enemies[enemies.size() - 1]
    var enemy := entry["node"] as CharacterBody3D
    if is_instance_valid(enemy):
        enemy.position = region_map.enemy_spawn_position(maxi(slot, 0), enemy_serial)

# The inherited runtime eventually reaches app_grim.gd, where the legacy arena
# clamps the player to +/-18. The region therefore owns the movement step until
# the common runtime has a world-bounds strategy. Keep every higher-level tick
# here as well: mana regen, skill cooldowns, pooled-AI/label maintenance, loot,
# and HUD refresh must continue while exploring the large map.
func _physics_process(delta: float) -> void:
    if player == null:
        return

    player_mana = minf(player_max_mana, player_mana + MANA_REGEN_PER_SECOND * delta)
    _resource_ui_accumulator += delta

    for i in range(skill_cooldowns.size()):
        skill_cooldowns[i] = maxf(0.0, skill_cooldowns[i] - delta)
    _skill_ui_accumulator += delta

    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    var keyboard := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): keyboard.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): keyboard.x += 1
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): keyboard.y -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): keyboard.y += 1
    keyboard = keyboard.normalized()

    var input_vector := move_input if move_input.length() > 0.03 else keyboard
    player.velocity = Vector3(input_vector.x, 0, input_vector.y) * PLAYER_SPEED
    player.move_and_slide()
    if region_map != null:
        player.position = region_map.clamp_player(player.position)
    if player_visual != null and absf(input_vector.x) > 0.05:
        player_visual.flip_h = input_vector.x < 0.0

    _update_enemies(delta)
    _update_loot()
    _update_label_visibility()
    if mouse_fire_held and attack_cooldown <= 0.0:
        _attack_at_screen(mouse_fire_position)

    if _skill_ui_accumulator >= 0.10:
        _skill_ui_accumulator = 0.0
        var gameplay_ui := ui as RiftGameplayUI
        if gameplay_ui != null:
            gameplay_ui.set_skill_cooldowns(skill_cooldowns)

    if _resource_ui_accumulator >= 0.10:
        _resource_ui_accumulator = 0.0
        _refresh_resource_hud()

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
    if region_map != null:
        destination = region_map.clamp_player(destination)
    _spawn_hit_flash(start + Vector3(0, 0.65, 0), Color(0.30, 0.62, 1.0), 3.2)
    player.global_position = destination
    _spawn_hit_flash(destination + Vector3(0, 0.65, 0), Color(0.30, 0.62, 1.0), 3.2)
    ui.set_hint("裂隙衝刺：快速位移")

func _damage_player(amount: float) -> void:
    player_hp = maxf(0.0, player_hp - amount)
    ui.set_hp(player_hp, player_max_hp)
    if player_hp <= 0.0:
        player_hp = player_max_hp
        player.velocity = Vector3.ZERO
        player.position = region_map.spawn_position() if region_map != null else Vector3.ZERO
        ui.set_hp(player_hp, player_max_hp)
        ui.set_hint("你被裂隙吞沒，已在南方營地重生")

func debug_region_state() -> Dictionary:
    return {
        "region": region_map.name if region_map != null else "",
        "north_edge": RiftRegionMap.NORTH_EDGE,
        "south_edge": RiftRegionMap.SOUTH_EDGE,
        "half_width": RiftRegionMap.HALF_WIDTH,
        "player_spawn": region_map.spawn_position() if region_map != null else Vector3.ZERO,
    }