extends "res://scripts/gameplay_ui.gd"
class_name RiftDesktopGameplayUI

signal fullscreen_requested
signal flask_requested(slot: int)

const ResourceOrbScript = preload("res://scripts/resource_orb.gd")
const BASIC_ICON = preload("res://art/ui/skill_basic.svg")
const SKILL_ICONS = [
    preload("res://art/ui/skill_volley.svg"),
    preload("res://art/ui/skill_burst.svg"),
    preload("res://art/ui/skill_dash.svg"),
]

var fullscreen_button: Button
var desktop_mode := false
var bottom_hud: Panel
var action_dock: Panel
var life_orb: RiftResourceOrb
var mana_orb: RiftResourceOrb
var basic_attack_slot: Panel
var basic_attack_icon: TextureRect
var flask_buttons: Array[Button] = []
var _flask_charges: Array[int] = [3, 3]

func setup(font: FontFile) -> void:
    super.setup(font)
    fullscreen_button = Button.new()
    fullscreen_button.name = "FullscreenButton"
    fullscreen_button.text = "全螢幕"
    fullscreen_button.focus_mode = Control.FOCUS_NONE
    fullscreen_button.add_theme_font_size_override("font_size", 14)
    fullscreen_button.add_theme_stylebox_override("normal", _forged_style(Color(0.035, 0.040, 0.052, 0.97), Color(0.42, 0.31, 0.16), 10, 2))
    fullscreen_button.add_theme_stylebox_override("hover", _forged_style(Color(0.075, 0.070, 0.060, 0.99), Color(0.72, 0.53, 0.26), 10, 2))
    fullscreen_button.add_theme_stylebox_override("pressed", _forged_style(Color(0.12, 0.10, 0.07, 1.0), Color(0.86, 0.66, 0.34), 10, 2))
    fullscreen_button.pressed.connect(func(): fullscreen_requested.emit())
    root_control.add_child(fullscreen_button)
    _build_arpg_hud(font)
    _layout()

func _forged_style(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
    var style := _round_style(fill, radius)
    style.border_color = border
    style.border_width_left = width
    style.border_width_top = width
    style.border_width_right = width
    style.border_width_bottom = width
    style.shadow_color = Color(0, 0, 0, 0.72)
    style.shadow_size = 6
    return style

func _build_arpg_hud(font: FontFile) -> void:
    bottom_hud = Panel.new()
    bottom_hud.name = "BottomHudFrame"
    bottom_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom_hud.z_index = -20
    var hud_style := _forged_style(Color(0.018, 0.020, 0.027, 0.975), Color(0.30, 0.23, 0.14, 0.96), 0, 2)
    hud_style.border_width_left = 0
    hud_style.border_width_right = 0
    hud_style.border_width_bottom = 0
    hud_style.shadow_size = 12
    bottom_hud.add_theme_stylebox_override("panel", hud_style)
    root_control.add_child(bottom_hud)
    root_control.move_child(bottom_hud, 0)

    action_dock = Panel.new()
    action_dock.name = "ActionDock"
    action_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
    action_dock.z_index = -10
    action_dock.add_theme_stylebox_override("panel", _forged_style(Color(0.030, 0.032, 0.042, 0.99), Color(0.50, 0.37, 0.19, 0.96), 16, 2))
    root_control.add_child(action_dock)

    for i in range(skill_buttons.size()):
        var skill := skill_buttons[i]
        skill.z_index = 5
        skill.icon = SKILL_ICONS[i]
        skill.expand_icon = true
        skill.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
        skill.add_theme_constant_override("icon_max_width", 42)
        skill.add_theme_color_override("font_color", Color(0.96, 0.91, 0.80))
        skill.add_theme_color_override("font_hover_color", Color.WHITE)
        skill.add_theme_color_override("font_pressed_color", Color.WHITE)
        skill.add_theme_color_override("font_disabled_color", Color(0.58, 0.60, 0.66))

    life_orb = ResourceOrbScript.new() as RiftResourceOrb
    life_orb.name = "LifeOrb"
    life_orb.z_index = 5
    root_control.add_child(life_orb)
    life_orb.setup(font, "生命", Color(0.90, 0.035, 0.055, 1.0))

    mana_orb = ResourceOrbScript.new() as RiftResourceOrb
    mana_orb.name = "ManaOrb"
    mana_orb.z_index = 5
    root_control.add_child(mana_orb)
    mana_orb.setup(font, "魔力", Color(0.035, 0.24, 0.96, 1.0))

    basic_attack_slot = Panel.new()
    basic_attack_slot.name = "BasicAttackSlot"
    basic_attack_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
    basic_attack_slot.z_index = 5
    basic_attack_slot.add_theme_stylebox_override("panel", _forged_style(Color(0.055, 0.041, 0.030, 0.99), Color(0.67, 0.47, 0.22), 12, 2))
    root_control.add_child(basic_attack_slot)

    basic_attack_icon = TextureRect.new()
    basic_attack_icon.name = "Icon"
    basic_attack_icon.texture = BASIC_ICON
    basic_attack_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    basic_attack_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    basic_attack_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    basic_attack_slot.add_child(basic_attack_icon)

    var attack_label := Label.new()
    attack_label.name = "Label"
    attack_label.text = "左鍵  基本攻擊"
    attack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    attack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    attack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    attack_label.add_theme_font_size_override("font_size", 12)
    attack_label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.56))
    attack_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
    attack_label.add_theme_constant_override("shadow_offset_x", 1)
    attack_label.add_theme_constant_override("shadow_offset_y", 1)
    basic_attack_slot.add_child(attack_label)

    var flask_defs := [
        {"name": "生命藥水", "key": "4", "color": Color(0.28, 0.035, 0.045, 0.98), "border": Color(0.66, 0.22, 0.18)},
        {"name": "魔力藥水", "key": "5", "color": Color(0.025, 0.075, 0.25, 0.98), "border": Color(0.20, 0.38, 0.76)},
    ]
    for i in range(flask_defs.size()):
        var data: Dictionary = flask_defs[i]
        var flask := Button.new()
        flask.name = "FlaskButton%d" % i
        flask.z_index = 5
        flask.focus_mode = Control.FOCUS_NONE
        flask.add_theme_font_size_override("font_size", 11)
        flask.add_theme_color_override("font_color", Color(0.96, 0.90, 0.80))
        flask.add_theme_stylebox_override("normal", _forged_style(data["color"] as Color, data["border"] as Color, 10, 2))
        flask.add_theme_stylebox_override("hover", _forged_style((data["color"] as Color).lightened(0.10), (data["border"] as Color).lightened(0.20), 10, 2))
        flask.add_theme_stylebox_override("pressed", _forged_style(Color(0.36, 0.27, 0.14, 0.99), Color(0.86, 0.67, 0.35), 10, 2))
        flask.pressed.connect(_request_flask.bind(i))
        root_control.add_child(flask)
        flask_buttons.append(flask)
    set_flask_charges(_flask_charges)

func _request_flask(slot: int) -> void:
    flask_requested.emit(slot)

func set_desktop_mode(enabled: bool) -> void:
    desktop_mode = enabled
    _layout()

func _layout() -> void:
    super._layout()
    if root_control == null or equipment_button == null:
        return

    var size := get_viewport().get_visible_rect().size
    if fullscreen_button != null:
        fullscreen_button.visible = desktop_mode
    if life_orb != null:
        life_orb.visible = true
    if mana_orb != null:
        mana_orb.visible = true
    if bottom_hud != null:
        bottom_hud.visible = true
    if action_dock != null:
        action_dock.visible = true
    if basic_attack_slot != null:
        basic_attack_slot.visible = desktop_mode
    for flask in flask_buttons:
        flask.visible = desktop_mode

    if not desktop_mode:
        _layout_mobile_portrait(size)
        return

    _layout_desktop(size)

func _apply_skill_frame_styles(mobile: bool) -> void:
    var skill_fills := [Color(0.035, 0.105, 0.085, 0.99), Color(0.18, 0.055, 0.035, 0.99), Color(0.055, 0.065, 0.18, 0.99)]
    var skill_borders := [Color(0.26, 0.65, 0.49), Color(0.80, 0.35, 0.17), Color(0.36, 0.43, 0.90)]
    for i in range(skill_buttons.size()):
        var skill := skill_buttons[i]
        skill.visible = true
        skill.z_index = 5
        skill.add_theme_constant_override("icon_max_width", 34 if mobile else 42)
        skill.add_theme_font_size_override("font_size", 11 if mobile else 14)
        skill.add_theme_stylebox_override("normal", _forged_style(skill_fills[i], skill_borders[i], 12, 2))
        skill.add_theme_stylebox_override("hover", _forged_style(skill_fills[i].lightened(0.12), skill_borders[i].lightened(0.18), 12, 2))
        skill.add_theme_stylebox_override("pressed", _forged_style(skill_fills[i].lightened(0.22), Color(0.92, 0.78, 0.48), 12, 2))
        skill.add_theme_stylebox_override("disabled", _forged_style(Color(0.035, 0.038, 0.050, 0.97), Color(0.22, 0.22, 0.25), 12, 1))

func _layout_mobile_portrait(size: Vector2) -> void:
    if joystick_back != null:
        joystick_back.visible = true
        joystick_back.size = Vector2(116, 116)
        joystick_back.position = Vector2(16, size.y - 142)
        joystick_center = joystick_back.position + joystick_back.size * 0.5
        _set_knob(movement)
    if attack_button != null:
        attack_button.visible = true
        attack_button.size = Vector2(92, 92)
        attack_button.position = Vector2(size.x - 108, size.y - 128)
        attack_button.add_theme_font_size_override("font_size", 17)
    if status_label != null:
        status_label.visible = false
    if hp_bar != null:
        hp_bar.visible = false

    title_label.position = Vector2(14, 14)
    title_label.size = Vector2(size.x - 188, 28)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    title_label.add_theme_font_size_override("font_size", 18)

    equipment_button.size = Vector2(72, 38)
    equipment_button.position = Vector2(size.x - 156, 12)
    equipment_button.add_theme_font_size_override("font_size", 14)
    gem_button.size = Vector2(72, 38)
    gem_button.position = Vector2(size.x - 80, 12)
    gem_button.add_theme_font_size_override("font_size", 14)

    weapon_status.position = Vector2(14, 50)
    weapon_status.size = Vector2(size.x - 28, 22)
    weapon_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    weapon_status.add_theme_font_size_override("font_size", 12)
    hint_label.position = Vector2(14, 75)
    hint_label.size = Vector2(size.x - 28, 38)
    hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    hint_label.add_theme_font_size_override("font_size", 11)

    var orb_size := Vector2(92, 92)
    life_orb.size = orb_size
    life_orb.position = Vector2(12, 116)
    mana_orb.size = orb_size
    mana_orb.position = Vector2(size.x - orb_size.x - 12, 116)

    bottom_hud.position = Vector2(0, size.y - 156)
    bottom_hud.size = Vector2(size.x, 156)
    action_dock.size = Vector2(236, 84)
    action_dock.position = Vector2(size.x - 250, size.y - 244)

    _apply_skill_frame_styles(true)
    var skill_size := Vector2(70, 70)
    var gap := 8.0
    var row_width := skill_size.x * 3.0 + gap * 2.0
    var start_x := size.x - row_width - 12.0
    var skill_y := size.y - 237.0
    for i in range(skill_buttons.size()):
        skill_buttons[i].size = skill_size
        skill_buttons[i].position = Vector2(start_x + float(i) * (skill_size.x + gap), skill_y)

    var panel_width := minf(360.0, size.x - 24.0)
    var panel_height := minf(500.0, size.y - 150.0)
    equipment_panel.size = Vector2(panel_width, panel_height)
    equipment_panel.position = Vector2((size.x - panel_width) * 0.5, 122.0)
    if gem_panel != null:
        gem_panel.size = Vector2(panel_width, panel_height)
        gem_panel.position = Vector2((size.x - panel_width) * 0.5, 122.0)

func _layout_desktop(size: Vector2) -> void:
    if joystick_back != null:
        joystick_back.visible = false
    if attack_button != null:
        attack_button.visible = false
    if status_label != null:
        status_label.visible = false
    if hp_bar != null:
        hp_bar.visible = false

    title_label.position = Vector2(24, 16)
    title_label.size = Vector2(330, 32)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    title_label.add_theme_font_size_override("font_size", 22)
    weapon_status.position = Vector2(24, 48)
    weapon_status.size = Vector2(minf(520.0, size.x * 0.42), 26)
    weapon_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    weapon_status.add_theme_font_size_override("font_size", 13)
    hint_label.position = Vector2(24, 76)
    hint_label.size = Vector2(minf(620.0, size.x * 0.50), 34)
    hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    hint_label.add_theme_font_size_override("font_size", 13)

    gem_button.size = Vector2(82, 42)
    gem_button.position = Vector2(size.x - 96, 16)
    equipment_button.size = Vector2(82, 42)
    equipment_button.position = Vector2(size.x - 188, 16)
    fullscreen_button.size = Vector2(104, 42)
    fullscreen_button.position = Vector2(size.x - 302, 16)

    var hud_height := 164.0
    bottom_hud.position = Vector2(0, size.y - hud_height)
    bottom_hud.size = Vector2(size.x, hud_height)

    var orb_size := Vector2(148, 148)
    life_orb.size = orb_size
    life_orb.position = Vector2(18, size.y - 154)
    mana_orb.size = orb_size
    mana_orb.position = Vector2(size.x - orb_size.x - 18, size.y - 154)

    var dock_width := minf(650.0, size.x - 420.0)
    action_dock.size = Vector2(dock_width, 118)
    action_dock.position = Vector2((size.x - dock_width) * 0.5, size.y - 126)

    var slot_size := Vector2(116, 82)
    var gap := 10.0
    var total_width := slot_size.x * 4.0 + gap * 3.0
    var start_x := (size.x - total_width) * 0.5
    var slot_y := size.y - 106
    basic_attack_slot.size = slot_size
    basic_attack_slot.position = Vector2(start_x, slot_y)
    basic_attack_icon.position = Vector2(8, 5)
    basic_attack_icon.size = Vector2(52, 52)
    var attack_label := basic_attack_slot.get_node("Label") as Label
    attack_label.position = Vector2(4, 55)
    attack_label.size = Vector2(slot_size.x - 8, 22)

    _apply_skill_frame_styles(false)
    for i in range(skill_buttons.size()):
        skill_buttons[i].size = slot_size
        skill_buttons[i].position = Vector2(start_x + float(i + 1) * (slot_size.x + gap), slot_y)

    var flask_size := Vector2(74, 70)
    var flask_x: float = life_orb.position.x + orb_size.x + 18.0
    var flask_y: float = size.y - 91.0
    for i in range(flask_buttons.size()):
        flask_buttons[i].size = flask_size
        flask_buttons[i].position = Vector2(flask_x + float(i) * (flask_size.x + 8.0), flask_y)

    var panel_width := minf(430.0, size.x * 0.42)
    var panel_height := minf(500.0, size.y - 190.0)
    equipment_panel.size = Vector2(panel_width, panel_height)
    equipment_panel.position = Vector2(size.x - panel_width - 24.0, 76.0)
    if gem_panel != null:
        var gem_width := minf(410.0, size.x * 0.40)
        var gem_height := minf(520.0, size.y - 190.0)
        gem_panel.size = Vector2(gem_width, gem_height)
        gem_panel.position = Vector2(size.x - gem_width - 24.0, 76.0)

func set_hp(current: float, maximum: float) -> void:
    super.set_hp(current, maximum)
    if life_orb != null:
        life_orb.set_value(current, maximum)

func set_mana(current: float, maximum: float) -> void:
    if mana_orb != null:
        mana_orb.set_value(current, maximum)

func set_flask_charges(charges: Array[int]) -> void:
    _flask_charges = charges.duplicate()
    var labels := ["生命藥水", "魔力藥水"]
    var keys := ["4", "5"]
    for i in range(mini(flask_buttons.size(), _flask_charges.size())):
        flask_buttons[i].text = "%s\n%s ×%d" % [keys[i], labels[i], _flask_charges[i]]
        flask_buttons[i].disabled = _flask_charges[i] <= 0
