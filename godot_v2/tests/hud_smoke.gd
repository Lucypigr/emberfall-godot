extends SceneTree

# Regression guard for the desktop ARPG HUD: colored resource orbs and the
# foreground skill row must both survive the Web/Compatibility path.
func _fail(message: String) -> void:
    push_error(message)
    quit(1)

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://main.tscn") as PackedScene
    if packed == null:
        _fail("Unable to load ARPG HUD scene")
        return
    var scene := packed.instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame

    var ui_root := scene.get_node_or_null("MobileUI/Root") as Control
    if ui_root == null:
        _fail("Desktop UI root is missing")
        return

    var life_orb := ui_root.get_node_or_null("LifeOrb") as Control
    var mana_orb := ui_root.get_node_or_null("ManaOrb") as Control
    var bottom_hud := ui_root.get_node_or_null("BottomHudFrame") as Panel
    var action_dock := ui_root.get_node_or_null("ActionDock") as Panel
    var basic_slot := ui_root.get_node_or_null("BasicAttackSlot") as Panel
    var skill0 := ui_root.get_node_or_null("SkillButton0") as Button
    var skill1 := ui_root.get_node_or_null("SkillButton1") as Button
    var skill2 := ui_root.get_node_or_null("SkillButton2") as Button
    var flask0 := ui_root.get_node_or_null("FlaskButton0") as Button
    var flask1 := ui_root.get_node_or_null("FlaskButton1") as Button
    if life_orb == null or mana_orb == null or bottom_hud == null or action_dock == null or basic_slot == null or skill0 == null or skill1 == null or skill2 == null or flask0 == null or flask1 == null:
        _fail("ARPG bottom HUD controls did not mount")
        return
    if not life_orb.visible or not mana_orb.visible or not bottom_hud.visible or not action_dock.visible:
        _fail("Desktop ARPG HUD is not visible")
        return

    var life_color: Color = life_orb.call("debug_liquid_color")
    var mana_color: Color = mana_orb.call("debug_liquid_color")
    if life_color.r < 0.80 or life_color.g > 0.15 or life_color.b > 0.15:
        _fail("Life orb is not configured as a strong red liquid")
        return
    if mana_color.b < 0.80 or mana_color.r > 0.15 or mana_color.g > 0.40:
        _fail("Mana orb is not configured as a strong blue liquid")
        return
    if String(life_orb.call("debug_render_mode")) != "canvas_draw" or String(mana_orb.call("debug_render_mode")) != "canvas_draw":
        _fail("Resource orbs still depend on the unreliable Web shader path")
        return

    for skill in [skill0, skill1, skill2]:
        if not skill.visible:
            _fail("Desktop active skill row contains a hidden button")
            return
        if skill.z_index <= action_dock.z_index:
            _fail("Desktop active skill button is rendered behind the action dock")
            return
    if not skill0.text.contains("1") or not skill1.text.contains("2") or not skill2.text.contains("3"):
        _fail("Desktop active skill hotkeys are not visible")
        return

    var viewport_width := get_root().get_visible_rect().size.x
    if life_orb.position.x >= viewport_width * 0.5 or mana_orb.position.x <= viewport_width * 0.5:
        _fail("Life/mana orbs are not anchored to opposite sides")
        return

    var state: Dictionary = scene.call("debug_resource_state")
    if float(state.get("max_mana", 0.0)) < 100.0 or float(state.get("mana_regen", 0.0)) <= 0.0:
        _fail("Mana resource system is not active")
        return
    var costs: Array = state.get("skill_mana_costs", [])
    if costs.size() != 3 or float(costs[0]) <= 0.0:
        _fail("Skill mana costs are missing")
        return

    scene.call("debug_set_mana", 100.0)
    var before_skill := float(scene.call("debug_resource_state").get("mana", 0.0))
    scene.call("_use_skill", 0)
    await process_frame
    var after_skill := float(scene.call("debug_resource_state").get("mana", 0.0))
    if after_skill >= before_skill:
        _fail("Using an active skill did not consume mana")
        return

    scene.call("debug_set_mana", 20.0)
    var before_mana_flask: Dictionary = scene.call("debug_resource_state")
    scene.call("_use_flask", 1)
    var after_mana_flask: Dictionary = scene.call("debug_resource_state")
    if float(after_mana_flask.get("mana", 0.0)) <= float(before_mana_flask.get("mana", 0.0)):
        _fail("Mana flask did not restore mana")
        return
    var before_charges: Array = before_mana_flask.get("flask_charges", [])
    var after_charges: Array = after_mana_flask.get("flask_charges", [])
    if before_charges.size() < 2 or after_charges.size() < 2 or int(after_charges[1]) != int(before_charges[1]) - 1:
        _fail("Mana flask charge was not consumed")
        return

    scene.call("debug_set_hp", 40.0)
    var hp_before := float(scene.call("debug_resource_state").get("hp", 0.0))
    scene.call("_use_flask", 0)
    var hp_after := float(scene.call("debug_resource_state").get("hp", 0.0))
    if hp_after <= hp_before:
        _fail("Life flask did not restore health")
        return

    if not flask0.text.contains("生命藥水") or not flask1.text.contains("魔力藥水"):
        _fail("Desktop flask labels are incomplete")
        return

    print("RIFTFORGED_HUD_SMOKE_OK red-life/blue-mana/visible-skill-row/resources ready")
    quit(0)
