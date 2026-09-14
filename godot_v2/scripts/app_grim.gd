extends Node3D

const MobileUIScript = preload("res://scripts/mobile_ui.gd")
const FontServiceScript = preload("res://scripts/font_service.gd")
const GrimData = preload("res://scripts/grim_data.gd")
const LootSystem = preload("res://scripts/loot_system.gd")
const PLAYER_TEXTURE = preload("res://art/player_ranger.svg")
const ENEMY_TEXTURE = preload("res://art/rift_beast.svg")

const PLAYER_SPEED := 6.2
const WORLD_LIMIT := 18.0
const MAX_ENEMIES := 7
const ATTACK_RANGE := 11.5
const ATTACK_DAMAGE := 28.0
const ATTACK_COOLDOWN := 0.36
const PROJECTILE_TRAVEL_TIME := 0.28
const MOUSE_TARGET_RADIUS := 86.0
const LOOT_PICKUP_RANGE := 1.25

var player: CharacterBody3D
var player_visual: Sprite3D
var camera: Camera3D
var enemies_root: Node3D
var projectiles_root: Node3D
var loot_root: Node3D
var ui: RiftMobileUI
var ui_font: FontFile

var enemies: Array[Dictionary] = []
var loot_drops: Array[Dictionary] = []
var enemy_serial := 0
var projectile_serial := 0
var loot_serial := 0
var move_input := Vector2.ZERO
var player_hp := 100.0
var player_max_hp := 100.0
var attack_cooldown := 0.0
var kills := 0
var picked_loot := 0
var mouse_fire_held := false
var mouse_fire_position := Vector2.ZERO

func _ready() -> void:
    randomize()
    ui_font = FontServiceScript.load_ui_font()
    if ui_font == null:
        push_error("Riftforged cannot start without the bundled Traditional Chinese font")
        return

    _build_world()
    _build_player()
    _build_enemies_root()
    _build_projectiles_root()
    _build_loot_root()
    _build_ui()
    for i in range(MAX_ENEMIES):
        _spawn_enemy(i == MAX_ENEMIES - 1, i)

func _build_world() -> void:
    var environment_node := WorldEnvironment.new()
    environment_node.name = "WorldEnvironment"
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.026, 0.032, 0.043)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.52, 0.58, 0.68)
    environment.ambient_light_energy = 0.72
    environment_node.environment = environment
    add_child(environment_node)

    var light := DirectionalLight3D.new()
    light.name = "KeyLight"
    light.rotation_degrees = Vector3(-55, -30, 0)
    light.light_energy = 1.15
    light.shadow_enabled = true
    add_child(light)

    var ground := MeshInstance3D.new()
    ground.name = "Ground"
    var plane := PlaneMesh.new()
    plane.size = Vector2(42, 42)
    ground.mesh = plane
    var ground_mat := StandardMaterial3D.new()
    ground_mat.albedo_color = Color(0.075, 0.10, 0.085)
    ground_mat.roughness = 1.0
    ground.material_override = ground_mat
    add_child(ground)

    var ground_body := StaticBody3D.new()
    ground_body.name = "GroundCollision"
    var shape_node := CollisionShape3D.new()
    var ground_shape := BoxShape3D.new()
    ground_shape.size = Vector3(42, 0.2, 42)
    shape_node.shape = ground_shape
    shape_node.position.y = -0.11
    ground_body.add_child(shape_node)
    add_child(ground_body)

    for z in range(-15, 16, 3):
        var tile := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = Vector3(3.8, 0.04, 2.1)
        tile.mesh = mesh
        tile.position = Vector3(float((z / 3) % 2) * 0.65, 0.025, float(z))
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.16, 0.145, 0.12)
        mat.roughness = 1.0
        tile.material_override = mat
        add_child(tile)

    var props := [
        Vector3(-5.5, 0.65, -4.0), Vector3(5.8, 0.65, 4.2),
        Vector3(-7.5, 0.65, 6.0), Vector3(7.5, 0.65, -5.8),
        Vector3(0.0, 0.65, -9.0), Vector3(-1.0, 0.65, 9.0)
    ]
    for i in range(props.size()):
        var prop := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = Vector3(1.2, 1.1 + float(i % 3) * 0.45, 1.2)
        prop.mesh = box
        prop.position = props[i]
        var prop_mat := StandardMaterial3D.new()
        prop_mat.albedo_color = Color(0.17, 0.15, 0.135)
        prop_mat.roughness = 0.95
        prop.material_override = prop_mat
        add_child(prop)

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    add_child(player)

    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.42
    capsule.height = 1.55
    collision.shape = capsule
    collision.position.y = 0.78
    player.add_child(collision)

    var shadow := MeshInstance3D.new()
    shadow.name = "Shadow"
    var shadow_mesh := CylinderMesh.new()
    shadow_mesh.top_radius = 0.58
    shadow_mesh.bottom_radius = 0.58
    shadow_mesh.height = 0.025
    shadow.mesh = shadow_mesh
    shadow.position.y = 0.02
    var shadow_mat := StandardMaterial3D.new()
    shadow_mat.albedo_color = Color(0, 0, 0, 0.38)
    shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    shadow.material_override = shadow_mat
    player.add_child(shadow)

    player_visual = Sprite3D.new()
    player_visual.name = "Visual"
    player_visual.texture = PLAYER_TEXTURE
    player_visual.pixel_size = 0.0072
    player_visual.position.y = 1.15
    player_visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    player_visual.shaded = false
    player.add_child(player_visual)

    camera = Camera3D.new()
    camera.name = "Camera3D"
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 17.5
    camera.keep_aspect = Camera3D.KEEP_WIDTH
    camera.position = Vector3(0, 10.8, 11.4)
    camera.rotation_degrees = Vector3(-44, 0, 0)
    camera.current = true
    player.add_child(camera)

func _build_enemies_root() -> void:
    enemies_root = Node3D.new()
    enemies_root.name = "Enemies"
    add_child(enemies_root)

func _build_projectiles_root() -> void:
    projectiles_root = Node3D.new()
    projectiles_root.name = "Projectiles"
    add_child(projectiles_root)

func _build_loot_root() -> void:
    loot_root = Node3D.new()
    loot_root.name = "Loot"
    add_child(loot_root)

func _build_ui() -> void:
    ui = MobileUIScript.new()
    ui.name = "MobileUI"
    add_child(ui)
    ui.setup(ui_font)
    ui.movement_changed.connect(func(value: Vector2): move_input = value)
    ui.attack_requested.connect(_attack)
    ui.set_hp(player_hp, player_max_hp)
    ui.set_hint("手機：左下移動、右下攻擊｜電腦：WASD、按住左鍵連射｜怪物會施放技能並掉裝")

func _spawn_enemy(force_elite: bool = false, slot: int = -1) -> void:
    enemy_serial += 1
    var spawn_slot := enemy_serial if slot < 0 else slot
    var level := 1 + int(kills / 8)
    var archetype := GrimData.scaled_stats(GrimData.enemy_archetype(spawn_slot, force_elite), level)

    var enemy := CharacterBody3D.new()
    enemy.name = "Enemy_%d" % enemy_serial
    var angle := randf() * TAU
    var radius := randf_range(8.5, 15.5)
    enemy.position = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
    enemies_root.add_child(enemy)

    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.50 if force_elite else 0.44
    capsule.height = 1.68 if force_elite else 1.5
    collision.shape = capsule
    collision.position.y = 0.82
    enemy.add_child(collision)

    var visual := Sprite3D.new()
    visual.name = "Visual"
    visual.texture = ENEMY_TEXTURE
    visual.pixel_size = 0.0072 * float(archetype["scale"])
    visual.position.y = 1.15 * float(archetype["scale"])
    visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    visual.shaded = false
    visual.modulate = archetype["color"] as Color
    enemy.add_child(visual)

    var max_hp := float(archetype["hp"])
    var label := Label3D.new()
    label.name = "NameLabel"
    label.text = "%s Lv.%d  %d" % [String(archetype["name"]), level, int(max_hp)]
    label.position = Vector3(0, 2.55 * float(archetype["scale"]), 0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font = ui_font
    label.font_size = 27
    label.outline_size = 8
    label.modulate = Color(1.0, 0.84, 0.56) if force_elite else Color(0.94, 0.90, 1.0)
    enemy.add_child(label)

    enemies.append({
        "id": enemy_serial,
        "node": enemy,
        "visual": visual,
        "label": label,
        "archetype": archetype,
        "hp": max_hp,
        "max_hp": max_hp,
        "elite": force_elite,
        "touch_cd": 0.0,
        "skill_cd": randf_range(0.5, maxf(0.6, float(archetype["skill_delay"]))),
        "berserk": false,
    })

func _physics_process(delta: float) -> void:
    if player == null:
        return

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
    player.position.x = clampf(player.position.x, -WORLD_LIMIT, WORLD_LIMIT)
    player.position.z = clampf(player.position.z, -WORLD_LIMIT, WORLD_LIMIT)
    if player_visual != null and absf(input_vector.x) > 0.05:
        player_visual.flip_h = input_vector.x < 0.0

    _update_enemies(delta)
    _update_loot()
    if mouse_fire_held and attack_cooldown <= 0.0:
        _attack_at_screen(mouse_fire_position)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        mouse_fire_position = (event as InputEventMouseMotion).position
    elif event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.button_index == MOUSE_BUTTON_LEFT:
            mouse_fire_position = mouse.position
            mouse_fire_held = mouse.pressed
            if mouse.pressed:
                _attack_at_screen(mouse.position)
            get_viewport().set_input_as_handled()

func _update_enemies(delta: float) -> void:
    for i in range(enemies.size() - 1, -1, -1):
        var entry: Dictionary = enemies[i]
        var enemy := entry["node"] as CharacterBody3D
        if not is_instance_valid(enemy):
            enemies.remove_at(i)
            continue

        var archetype: Dictionary = entry["archetype"]
        entry["touch_cd"] = maxf(0.0, float(entry["touch_cd"]) - delta)
        entry["skill_cd"] = maxf(0.0, float(entry["skill_cd"]) - delta)
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
                enemy.move_and_slide()
            elif distance < desired - 1.4:
                enemy.velocity = -direction * speed * 0.72
                enemy.move_and_slide()
            else:
                enemy.velocity = Vector3.ZERO

            if float(entry["skill_cd"]) <= 0.0 and distance <= 8.5:
                entry["skill_cd"] = float(archetype["skill_delay"])
                if randf() <= float(archetype["skill_chance"]):
                    _enemy_cast_projectile(enemy, float(archetype["skill_damage"]))
        else:
            if distance > float(archetype["desired_range"]):
                enemy.velocity = direction * speed
                enemy.move_and_slide()
            else:
                enemy.velocity = Vector3.ZERO
                if float(entry["touch_cd"]) <= 0.0:
                    var damage := float(archetype["touch_damage"])
                    if bool(entry["berserk"]): damage *= 1.25
                    _damage_player(damage)
                    entry["touch_cd"] = float(archetype["touch_delay"])
        enemies[i] = entry

func _enemy_cast_projectile(enemy: CharacterBody3D, damage: float) -> void:
    if not is_instance_valid(enemy) or not is_instance_valid(player):
        return
    projectile_serial += 1
    var projectile := _create_orb("EnemyHex_%d" % projectile_serial, Color(0.36, 0.60, 1.0), Color(0.22, 0.36, 1.0), 0.17, 0.29)
    projectiles_root.add_child(projectile)
    projectile.global_position = enemy.global_position + Vector3(0, 1.0, 0)
    var destination := player.global_position + Vector3(0, 0.82, 0)
    var tween := create_tween()
    tween.tween_property(projectile, "global_position", destination, 0.62)
    tween.tween_callback(_resolve_enemy_projectile.bind(projectile, destination, damage))

func _resolve_enemy_projectile(projectile: Node3D, destination: Vector3, damage: float) -> void:
    if is_instance_valid(projectile): projectile.queue_free()
    var flat_player := player.global_position
    flat_player.y = destination.y
    if flat_player.distance_to(destination) <= 1.35:
        _damage_player(damage)
        _spawn_hit_flash(destination, Color(0.35, 0.55, 1.0))

func _attack() -> void:
    if attack_cooldown > 0.0 or enemies.is_empty():
        return
    var index := _nearest_enemy_index()
    if index < 0:
        ui.set_hint("附近沒有敵人")
        return
    var entry: Dictionary = enemies[index]
    var enemy := entry["node"] as CharacterBody3D
    if player.global_position.distance_to(enemy.global_position) > ATTACK_RANGE:
        ui.set_hint("敵人超出攻擊距離")
        return
    attack_cooldown = ATTACK_COOLDOWN
    _spawn_projectile(int(entry["id"]), enemy)

func _attack_at_screen(screen_position: Vector2) -> void:
    if attack_cooldown > 0.0 or camera == null or player == null:
        return
    var screen_target := _enemy_index_near_screen(screen_position)
    if screen_target >= 0:
        var targeted_entry: Dictionary = enemies[screen_target]
        var targeted_enemy := targeted_entry["node"] as CharacterBody3D
        var targeted_direction := targeted_enemy.global_position - player.global_position
        targeted_direction.y = 0
        if targeted_direction.length() <= ATTACK_RANGE:
            if player_visual != null and absf(targeted_direction.x) > 0.02:
                player_visual.flip_h = targeted_direction.x < 0.0
            attack_cooldown = ATTACK_COOLDOWN
            _spawn_projectile(int(targeted_entry["id"]), targeted_enemy)
            return

    var ground_point := _screen_to_ground(screen_position)
    var aim := ground_point - player.global_position
    aim.y = 0
    var aim_distance := aim.length()
    if aim_distance < 0.12: return
    var direction := aim / aim_distance
    var shot_distance := minf(ATTACK_RANGE, aim_distance)
    if player_visual != null and absf(direction.x) > 0.02:
        player_visual.flip_h = direction.x < 0.0
    attack_cooldown = ATTACK_COOLDOWN

    var hit_index := _enemy_index_on_aim(direction, shot_distance)
    if hit_index >= 0:
        var entry: Dictionary = enemies[hit_index]
        _spawn_projectile(int(entry["id"]), entry["node"] as CharacterBody3D)
    else:
        _spawn_miss_projectile(player.global_position + direction * shot_distance + Vector3(0, 1.0, 0))

func _enemy_index_near_screen(screen_position: Vector2) -> int:
    var best := -1
    var best_screen_distance := MOUSE_TARGET_RADIUS
    for i in range(enemies.size()):
        var enemy := enemies[i]["node"] as CharacterBody3D
        if not is_instance_valid(enemy): continue
        if player.global_position.distance_to(enemy.global_position) > ATTACK_RANGE: continue
        if camera.is_position_behind(enemy.global_position): continue
        var enemy_screen := camera.unproject_position(enemy.global_position + Vector3(0, 1.0, 0))
        var screen_distance := enemy_screen.distance_to(screen_position)
        if screen_distance <= best_screen_distance:
            best = i
            best_screen_distance = screen_distance
    return best

func _screen_to_ground(screen_position: Vector2) -> Vector3:
    var ray_origin := camera.project_ray_origin(screen_position)
    var ray_direction := camera.project_ray_normal(screen_position)
    if absf(ray_direction.y) < 0.0001: return player.global_position
    var t := -ray_origin.y / ray_direction.y
    if t <= 0.0: return player.global_position
    return ray_origin + ray_direction * t

func _enemy_index_on_aim(direction: Vector3, max_distance: float) -> int:
    var best := -1
    var best_along := INF
    for i in range(enemies.size()):
        var enemy := enemies[i]["node"] as CharacterBody3D
        if not is_instance_valid(enemy): continue
        var offset := enemy.global_position - player.global_position
        offset.y = 0
        var along := offset.dot(direction)
        if along < 0.0 or along > max_distance: continue
        var side := (offset - direction * along).length()
        if side <= 0.85 and along < best_along:
            best = i
            best_along = along
    return best

func _spawn_projectile(enemy_id: int, target: CharacterBody3D) -> void:
    if projectiles_root == null or not is_instance_valid(target): return
    projectile_serial += 1
    var projectile := _create_orb("RiftBolt_%d" % projectile_serial, Color(1.0, 0.72, 0.22), Color(1.0, 0.24, 0.04), 0.18, 0.31)
    projectiles_root.add_child(projectile)
    projectile.global_position = player.global_position + Vector3(0, 1.02, 0)
    var destination := target.global_position + Vector3(0, 0.95, 0)
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_IN)
    tween.tween_property(projectile, "global_position", destination, PROJECTILE_TRAVEL_TIME)
    tween.tween_callback(_resolve_projectile_hit.bind(enemy_id, projectile))

func _spawn_miss_projectile(destination: Vector3) -> void:
    projectile_serial += 1
    var projectile := _create_orb("RiftMiss_%d" % projectile_serial, Color(1.0, 0.72, 0.22), Color(1.0, 0.24, 0.04), 0.18, 0.31)
    projectiles_root.add_child(projectile)
    projectile.global_position = player.global_position + Vector3(0, 1.02, 0)
    var tween := create_tween()
    tween.tween_property(projectile, "global_position", destination, PROJECTILE_TRAVEL_TIME)
    tween.tween_callback(projectile.queue_free)

func _create_orb(name_text: String, core_color: Color, aura_color: Color, core_radius: float, aura_radius: float) -> Node3D:
    var projectile := Node3D.new()
    projectile.name = name_text
    var core := MeshInstance3D.new()
    var core_mesh := SphereMesh.new()
    core_mesh.radius = core_radius
    core_mesh.height = core_radius * 2.0
    core.mesh = core_mesh
    var core_mat := StandardMaterial3D.new()
    core_mat.albedo_color = core_color
    core_mat.emission_enabled = true
    core_mat.emission = core_color
    core_mat.emission_energy_multiplier = 3.0
    core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    core.material_override = core_mat
    projectile.add_child(core)

    var aura := MeshInstance3D.new()
    var aura_mesh := SphereMesh.new()
    aura_mesh.radius = aura_radius
    aura_mesh.height = aura_radius * 2.0
    aura.mesh = aura_mesh
    var aura_mat := StandardMaterial3D.new()
    aura_mat.albedo_color = Color(aura_color.r, aura_color.g, aura_color.b, 0.22)
    aura_mat.emission_enabled = true
    aura_mat.emission = aura_color
    aura_mat.emission_energy_multiplier = 1.5
    aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    aura.material_override = aura_mat
    projectile.add_child(aura)
    return projectile

func _resolve_projectile_hit(enemy_id: int, projectile: Node3D) -> void:
    if is_instance_valid(projectile): projectile.queue_free()
    var index := _enemy_index_by_id(enemy_id)
    if index < 0: return
    _damage_enemy(index, ATTACK_DAMAGE)

func _damage_enemy(index: int, damage: float) -> void:
    if index < 0 or index >= enemies.size(): return
    var entry: Dictionary = enemies[index]
    var enemy := entry["node"] as CharacterBody3D
    if not is_instance_valid(enemy): return
    entry["hp"] = maxf(0.0, float(entry["hp"]) - damage)
    var archetype: Dictionary = entry["archetype"]
    var label := entry["label"] as Label3D
    label.text = "%s Lv.%d  %d" % [String(archetype["name"]), int(archetype["level"]), int(entry["hp"])]
    _spawn_hit_flash(enemy.global_position + Vector3(0, 0.95, 0), Color(1.0, 0.45, 0.08))
    if float(entry["hp"]) <= 0.0:
        _kill_enemy(index)
    else:
        enemies[index] = entry

func _kill_enemy(index: int) -> void:
    var entry: Dictionary = enemies[index]
    var enemy := entry["node"] as CharacterBody3D
    var death_position := enemy.global_position
    var archetype: Dictionary = entry["archetype"]
    var was_elite := bool(entry["elite"])

    if float(archetype["dying_burst"]) > 0.0:
        _dying_burst(death_position, float(archetype["dying_burst"]))
    _drop_loot(death_position, entry, false)
    enemy.queue_free()
    enemies.remove_at(index)
    kills += 1
    ui.set_hint("擊倒 %s · 擊殺 %d · 地面裝備 %d" % [String(archetype["name"]), kills, loot_drops.size()])
    _spawn_enemy(was_elite if kills % 9 == 0 else false, kills)

func _dying_burst(position: Vector3, damage: float) -> void:
    _spawn_hit_flash(position + Vector3(0, 0.55, 0), Color(1.0, 0.18, 0.08), 5.0)
    var flat_player := player.global_position
    flat_player.y = position.y
    if flat_player.distance_to(position) <= 2.8:
        _damage_player(damage)

func _drop_loot(position: Vector3, entry: Dictionary, guaranteed: bool) -> void:
    var archetype: Dictionary = entry["archetype"]
    var rolled: Array[Dictionary] = LootSystem.roll_master(String(archetype["loot_profile"]), int(archetype["level"]), bool(entry["elite"]), guaranteed)
    for item in rolled:
        _spawn_loot_visual(position + Vector3(randf_range(-0.45, 0.45), 0, randf_range(-0.45, 0.45)), item)

func _spawn_loot_visual(position: Vector3, item: Dictionary) -> void:
    loot_serial += 1
    var drop := Node3D.new()
    drop.name = "Loot_%d" % loot_serial
    loot_root.add_child(drop)
    drop.global_position = position

    var glow := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.20
    mesh.bottom_radius = 0.20
    mesh.height = 0.06
    glow.mesh = mesh
    glow.position.y = 0.08
    var mat := StandardMaterial3D.new()
    var color := item["color"] as Color
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = 2.1
    glow.material_override = mat
    drop.add_child(glow)

    var label := Label3D.new()
    label.text = "%s  [%s]" % [String(item["name"]), String(item["rarity"])]
    label.position = Vector3(0, 0.75, 0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font = ui_font
    label.font_size = 25
    label.outline_size = 8
    label.modulate = color
    drop.add_child(label)
    loot_drops.append({"node": drop, "item": item})

func _update_loot() -> void:
    for i in range(loot_drops.size() - 1, -1, -1):
        var entry: Dictionary = loot_drops[i]
        var node := entry["node"] as Node3D
        if not is_instance_valid(node):
            loot_drops.remove_at(i)
            continue
        if player.global_position.distance_to(node.global_position) <= LOOT_PICKUP_RANGE:
            var item: Dictionary = entry["item"]
            picked_loot += 1
            ui.set_hint("拾取：%s · %s · 共 %d 件" % [String(item["name"]), String(item["slot"]), picked_loot])
            node.queue_free()
            loot_drops.remove_at(i)

func _enemy_index_by_id(enemy_id: int) -> int:
    for i in range(enemies.size()):
        if int(enemies[i]["id"]) == enemy_id: return i
    return -1

func _nearest_enemy_index() -> int:
    var best := -1
    var best_distance := INF
    for i in range(enemies.size()):
        var enemy := enemies[i]["node"] as CharacterBody3D
        if not is_instance_valid(enemy): continue
        var distance := player.global_position.distance_squared_to(enemy.global_position)
        if distance < best_distance:
            best_distance = distance
            best = i
    return best

func _damage_player(amount: float) -> void:
    player_hp = maxf(0.0, player_hp - amount)
    ui.set_hp(player_hp, player_max_hp)
    if player_hp <= 0.0:
        player_hp = player_max_hp
        player.position = Vector3.ZERO
        ui.set_hp(player_hp, player_max_hp)
        ui.set_hint("你被裂隙吞沒，已在營火重生")

func _spawn_hit_flash(position: Vector3, color: Color, scale_to: float = 2.8) -> void:
    var flash := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.18
    sphere.height = 0.36
    flash.mesh = sphere
    flash.position = position
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = 2.0
    flash.material_override = mat
    add_child(flash)
    var tween := create_tween()
    tween.tween_property(flash, "scale", Vector3.ONE * scale_to, 0.14)
    tween.tween_callback(flash.queue_free)

func debug_font() -> FontFile:
    return ui_font

func debug_enemy_count() -> int:
    return enemies.size()

func debug_projectile_count() -> int:
    return projectiles_root.get_child_count() if projectiles_root != null else 0

func debug_loot_count() -> int:
    return loot_drops.size()

func debug_archetypes() -> Array[String]:
    var result: Array[String] = []
    for entry in enemies:
        result.append(String((entry["archetype"] as Dictionary)["id"]))
    return result

func debug_force_loot_drop() -> void:
    if enemies.is_empty(): return
    var entry: Dictionary = enemies[0]
    var enemy := entry["node"] as CharacterBody3D
    _drop_loot(enemy.global_position, entry, true)
