extends SceneTree

const FONT_PATH := "res://fonts/NotoSansTC-Riftforged.ttf"
const LootSystem = preload("res://scripts/loot_system.gd")
const WeaponSkillSystem = preload("res://scripts/weapon_skill_system.gd")
const REQUIRED_GLYPHS := ["攻", "擊", "寶", "石", "裂", "隙", "獸", "菁", "英", "獵", "犬", "衛", "士", "咒", "徒", "裝", "備", "武", "器", "技", "能", "衝", "刺", "爆", "全", "螢", "幕", "◆", "◇"]

var _finished := false
var _last_stage := "boot"

func _init() -> void:
    call_deferred("_watchdog")
    call_deferred("_run")

func _stage(name: String) -> void:
    _last_stage = name
    print("RIFTFORGED_SMOKE_STAGE ", name)

func _watchdog() -> void:
    await create_timer(12.0).timeout
    if not _finished:
        _fail("Smoke test timed out at stage: %s" % _last_stage)

func _fail(message: String) -> void:
    _finished = true
    push_error(message)
    quit(1)

func _run() -> void:
    _stage("font")
    var file := FileAccess.open(FONT_PATH, FileAccess.READ)
    if file == null:
        _fail("Missing bundled Traditional Chinese TTF")
        return
    var magic := file.get_buffer(4)
    file.close()
    if magic.size() != 4 or magic[0] != 0 or magic[1] != 1 or magic[2] != 0 or magic[3] != 0:
        _fail("Traditional Chinese font is not a TrueType file")
        return

    var imported_resource := ResourceLoader.load(FONT_PATH, "FontFile", ResourceLoader.CACHE_MODE_REUSE)
    var imported_font := imported_resource as FontFile
    if imported_font == null or imported_font.data.is_empty():
        _fail("Godot could not load the imported Traditional Chinese FontFile")
        return
    imported_font.allow_system_fallback = false
    for sample in REQUIRED_GLYPHS:
        if not imported_font.has_char(sample.unicode_at(0)):
            _fail("Imported font missing required glyph: %s" % sample)
            return

    _stage("scene")
    var packed := load("res://main.tscn") as PackedScene
    if packed == null:
        _fail("Unable to load main.tscn")
        return
    var scene := packed.instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame

    for path in ["Player", "Enemies", "Projectiles", "Loot", "MobileUI"]:
        if scene.get_node_or_null(path) == null:
            _fail("Missing required runtime node: %s" % path)
            return

    _stage("region")
    if not scene.has_method("debug_region_state"):
        _fail("Large-region runtime contract is missing")
        return
    var region_state: Dictionary = scene.call("debug_region_state")
    var region_name := String(region_state.get("region", ""))
    var region_root := scene.get_node_or_null(NodePath(region_name)) as Node3D
    if region_name.is_empty() or region_root == null:
        _fail("Large playable region did not mount")
        return
    if region_root.get_node_or_null("Ground") == null:
        _fail("Region terrain ground is missing from the region hierarchy")
        return
    var north_edge := float(region_state.get("north_edge", 0.0))
    var south_edge := float(region_state.get("south_edge", 0.0))
    var half_width := float(region_state.get("half_width", 0.0))
    if south_edge - north_edge < 290.0 or half_width * 2.0 < 60.0:
        _fail("Large playable region dimensions regressed")
        return

    _stage("perf")
    var perf: Dictionary = scene.call("debug_perf_pass2")
    if int(perf.get("ai_phases", 0)) != 2 or int(perf.get("loot_cap", 0)) != 24:
        _fail("Second performance layer is not active")
        return
    var pool: Dictionary = perf.get("pool", {})
    if int(pool.get("player_projectiles", 0)) < 10 or int(pool.get("enemy_projectiles", 0)) < 10 or int(pool.get("flashes", 0)) < 14:
        _fail("Combat effect pools were not prewarmed")
        return

    _stage("desktop")
    var desktop: Dictionary = scene.call("debug_desktop_profile")
    if not bool(desktop.get("enabled", false)):
        _fail("Desktop runtime profile did not activate on desktop CI")
        return
    if desktop.get("content_scale_size", Vector2i.ZERO) != Vector2i(1280, 720):
        _fail("Desktop logical viewport is not 1280x720 landscape")
        return
    if bool(desktop.get("joystick_visible", true)) or bool(desktop.get("attack_button_visible", true)):
        _fail("Desktop layout still shows mobile joystick/attack controls")
        return
    if not bool(desktop.get("fullscreen_button", false)):
        _fail("Desktop fullscreen control is missing")
        return

    var player := scene.get_node("Player") as CharacterBody3D
    if player == null:
        _fail("Player is not a CharacterBody3D")
        return
    var expected_spawn: Vector3 = region_state.get("player_spawn", Vector3.ZERO)
    if player.global_position.distance_to(expected_spawn) > 0.25:
        _fail("Player did not spawn at the region start")
        return
    var camera := player.get_node_or_null("Camera3D") as Camera3D
    if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL or camera.keep_aspect != Camera3D.KEEP_HEIGHT:
        _fail("Desktop landscape orthographic camera is not active")
        return
    var player_visual := player.get_node_or_null("Visual") as Sprite3D
    if player_visual == null or player_visual.texture == null:
        _fail("Player Sprite3D visual is missing")
        return

    var enemies := scene.get_node("Enemies") as Node3D
    if enemies == null or enemies.get_child_count() < 7:
        _fail("Grim-inspired combat pack did not spawn")
        return
    var archetypes: Array = scene.call("debug_archetypes")
    for expected in ["rift_stalker", "rift_warden", "rift_hexer", "rift_champion"]:
        if not archetypes.has(expected):
            _fail("Missing data-driven enemy archetype: %s" % expected)
            return

    var first_enemy := enemies.get_child(0) as CharacterBody3D
    if first_enemy == null:
        _fail("First enemy is not a CharacterBody3D")
        return
    var enemy_visual := first_enemy.get_node_or_null("Visual") as Sprite3D
    var enemy_label := first_enemy.get_node_or_null("NameLabel") as Label3D
    if enemy_visual == null or enemy_visual.texture == null or enemy_label == null or enemy_label.font == null:
        _fail("Enemy visual/Traditional Chinese label is incomplete")
        return
    if not enemy_label.text.contains("裂隙"):
        _fail("Enemy Traditional Chinese archetype name is missing")
        return

    _stage("ui")
    var ui_root := scene.get_node("MobileUI/Root") as Control
    if ui_root == null:
        _fail("Desktop UI root is missing")
        return
    var attack := ui_root.get_node_or_null("AttackButton") as Button
    var gem := ui_root.get_node_or_null("GemButton") as Button
    var equipment := ui_root.get_node_or_null("EquipmentButton") as Button
    var fullscreen := ui_root.get_node_or_null("FullscreenButton") as Button
    var skill0 := ui_root.get_node_or_null("SkillButton0") as Button
    var skill1 := ui_root.get_node_or_null("SkillButton1") as Button
    var skill2 := ui_root.get_node_or_null("SkillButton2") as Button
    var hint := ui_root.get_node_or_null("Hint") as Label
    if attack == null or gem == null or equipment == null or fullscreen == null or skill0 == null or skill1 == null or skill2 == null or hint == null:
        _fail("Weapon/skill desktop UI did not mount")
        return
    if attack.text != "攻擊" or gem.text != "寶石" or equipment.text != "裝備" or fullscreen.text != "全螢幕":
        _fail("Traditional Chinese desktop controls changed unexpectedly")
        return
    if attack.visible:
        _fail("Desktop attack button should be hidden in favor of left-click combat")
        return
    if not hint.text.contains("WASD") or not hint.text.contains("1/2/3") or not hint.text.contains("全螢幕"):
        _fail("Desktop landscape controls are not documented")
        return
    if ui_root.theme == null or ui_root.theme.default_font != imported_font:
        _fail("Shared imported Traditional Chinese theme is not active")
        return

    var weapon: Dictionary = scene.call("debug_weapon_state")
    if String(weapon.get("weapon_type", "")) != "bow" or float(weapon.get("damage", 0.0)) <= 0.0:
        _fail("Starter weapon is not active")
        return
    var skill_ids: Array = scene.call("debug_skill_ids")
    if skill_ids != ["weapon_skill", "burst", "rift_dash"]:
        _fail("Playable skill catalog is incomplete")
        return

    _stage("basic_attack")
    var before_mobile := enemy_label.text
    first_enemy.global_position = player.global_position + Vector3(2.0, 0.0, 0.0)
    scene.call("_attack")
    await process_frame
    if int(scene.call("debug_projectile_count")) < 1:
        _fail("Basic attack did not activate a pooled projectile")
        return
    await create_timer(0.36).timeout
    await process_frame
    if not is_instance_valid(enemy_label):
        _fail("Basic attack unexpectedly removed the smoke-test enemy")
        return
    if enemy_label.text == before_mobile:
        _fail("Basic projectile did not damage its target")
        return

    _stage("mouse_attack")
    first_enemy.global_position = player.global_position + Vector3(3.0, 0.0, 0.0)
    var before_mouse := enemy_label.text
    var mouse_event := InputEventMouseButton.new()
    mouse_event.button_index = MOUSE_BUTTON_LEFT
    mouse_event.pressed = true
    mouse_event.position = camera.unproject_position(first_enemy.global_position + Vector3(0, 1.0, 0))
    scene.call("_unhandled_input", mouse_event)
    await process_frame
    var release_event := InputEventMouseButton.new()
    release_event.button_index = MOUSE_BUTTON_LEFT
    release_event.pressed = false
    release_event.position = mouse_event.position
    scene.call("_unhandled_input", release_event)
    if int(scene.call("debug_projectile_count")) < 1:
        _fail("Desktop left click did not activate a pooled projectile")
        return
    await create_timer(0.36).timeout
    await process_frame
    if not is_instance_valid(enemy_label):
        _fail("Mouse attack unexpectedly removed the smoke-test enemy")
        return
    if enemy_label.text == before_mouse:
        _fail("Desktop cursor-targeted projectile did not damage its target")
        return

    _stage("skill")
    var skill_enemy := enemies.get_child(0) as CharacterBody3D
    if skill_enemy == null:
        _fail("Skill target enemy is missing")
        return
    skill_enemy.global_position = player.global_position + Vector3(3.0, 0.0, 0.0)
    scene.call("_use_skill", 0)
    await process_frame
    var cds: Array = scene.call("debug_skill_cooldowns")
    if cds.size() != 3 or float(cds[0]) <= 0.0:
        _fail("Weapon skill did not enter cooldown")
        return
    if int(scene.call("debug_projectile_count")) < 1:
        _fail("Ranged weapon skill did not spawn pooled projectiles")
        return

    _stage("region_runtime")
    var cooldown_before_tick := float(cds[0])
    skill_enemy.global_position = expected_spawn + Vector3(20.0, 0.0, 0.0)
    await create_timer(0.16).timeout
    await process_frame
    var cooldown_after_tick := float((scene.call("debug_skill_cooldowns") as Array)[0])
    if cooldown_after_tick >= cooldown_before_tick - 0.05:
        _fail("Large-region runtime stopped ticking skill cooldowns")
        return

    scene.call("debug_set_mana", 20.0)
    var mana_before := float((scene.call("debug_resource_state") as Dictionary).get("mana", 0.0))
    await create_timer(0.16).timeout
    await process_frame
    var mana_after := float((scene.call("debug_resource_state") as Dictionary).get("mana", 0.0))
    if mana_after <= mana_before + 0.5:
        _fail("Large-region runtime stopped regenerating mana")
        return

    player.global_position = expected_spawn
    player.velocity = Vector3.ZERO
    scene.set("last_aim_direction", Vector3(0.0, 0.0, -1.0))
    var dash_start := player.global_position
    scene.call("_use_skill", 2)
    await process_frame
    var dash_end := player.global_position
    if dash_start.distance_to(dash_end) < 4.0:
        _fail("Region dash did not move the player")
        return
    if absf(dash_start.z) > 18.5 and absf(dash_end.z) <= 18.5:
        _fail("Region dash snapped player back to the legacy arena bounds")
        return

    scene.call("_damage_player", 10000.0)
    await process_frame
    if player.global_position.distance_to(expected_spawn) > 0.25:
        _fail("Region death did not respawn the player at the south camp")
        return

    _stage("equipment")
    scene.call("debug_add_test_weapon", "blade")
    if int(scene.call("debug_weapon_inventory_count")) < 2:
        _fail("Weapon inventory did not accept a picked weapon")
        return
    scene.call("_equip_weapon_index", 1)
    var blade: Dictionary = scene.call("debug_weapon_state")
    if String(blade.get("weapon_type", "")) != "blade" or not skill0.text.contains("旋刃"):
        _fail("Equipping a blade did not change the active weapon skill")
        return

    var starter := WeaponSkillSystem.starter_weapon()
    if float(starter.get("range", 0.0)) < 10.0 or float(starter.get("cooldown", 0.0)) <= 0.0:
        _fail("Weapon stat normalization failed")
        return

    _stage("loot")
    scene.call("debug_force_loot_drop")
    await process_frame
    if int(scene.call("debug_loot_count")) < 1:
        _fail("Hierarchical loot system did not create a ground drop")
        return
    var rolled: Array[Dictionary] = LootSystem.roll_master("champion", 4, true, true)
    if rolled.is_empty() or not rolled[0].has("rarity") or not rolled[0].has("prefix") or not rolled[0].has("suffix"):
        _fail("Dynamic weighted loot/affix record is incomplete")
        return

    _finished = true
    print("RIFTFORGED_V2_SMOKE_OK desktop-1280x720/fullscreen/weapon-skills/pools/loot/large-region-runtime ready")
    quit(0)