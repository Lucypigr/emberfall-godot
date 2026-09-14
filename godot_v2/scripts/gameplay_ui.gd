extends "res://scripts/mobile_ui.gd"
class_name RiftGameplayUI

signal skill_requested(slot: int)
signal weapon_equip_requested(index: int)

var equipment_button: Button
var equipment_panel: Panel
var equipment_list: VBoxContainer
var weapon_status: Label
var skill_buttons: Array[Button] = []
var _skill_names := ["武器技", "爆裂", "衝刺"]

func setup(font: FontFile) -> void:
    super.setup(font)
    _build_gameplay_controls()
    # setup() is also used by RiftDesktopGameplayUI. Do not dispatch the
    # overridable _layout() until the desktop subclass has finished building
    # its own HUD nodes; lay out only the controls owned by this layer here.
    _layout_gameplay_controls()

func _build_gameplay_controls() -> void:
    weapon_status = Label.new()
    weapon_status.name = "WeaponStatus"
    weapon_status.text = "武器：旅者短弓"
    weapon_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    weapon_status.add_theme_font_size_override("font_size", 13)
    weapon_status.add_theme_color_override("font_color", Color(0.94, 0.82, 0.58))
    root_control.add_child(weapon_status)

    equipment_button = Button.new()
    equipment_button.name = "EquipmentButton"
    equipment_button.text = "裝備"
    equipment_button.focus_mode = Control.FOCUS_NONE
    equipment_button.add_theme_font_size_override("font_size", 16)
    equipment_button.add_theme_stylebox_override("normal", _round_style(Color(0.16, 0.12, 0.08, 0.94), 16))
    equipment_button.add_theme_stylebox_override("pressed", _round_style(Color(0.34, 0.24, 0.10, 0.98), 16))
    equipment_button.pressed.connect(_toggle_equipment_panel)
    root_control.add_child(equipment_button)

    for i in range(3):
        var button := Button.new()
        button.name = "SkillButton%d" % i
        button.text = "%d\n%s" % [i + 1, _skill_names[i]]
        button.focus_mode = Control.FOCUS_NONE
        button.add_theme_font_size_override("font_size", 14)
        button.add_theme_stylebox_override("normal", _round_style(Color(0.10, 0.12, 0.18, 0.92), 18))
        button.add_theme_stylebox_override("pressed", _round_style(Color(0.24, 0.30, 0.48, 0.98), 18))
        button.pressed.connect(_request_skill.bind(i))
        root_control.add_child(button)
        skill_buttons.append(button)

    equipment_panel = Panel.new()
    equipment_panel.name = "EquipmentPanel"
    equipment_panel.visible = false
    equipment_panel.add_theme_stylebox_override("panel", _round_style(Color(0.026, 0.030, 0.042, 0.985), 18))
    root_control.add_child(equipment_panel)

    var content := VBoxContainer.new()
    content.name = "Content"
    content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.offset_left = 14
    content.offset_top = 14
    content.offset_right = -14
    content.offset_bottom = -14
    content.add_theme_constant_override("separation", 8)
    equipment_panel.add_child(content)

    var title := Label.new()
    title.text = "武器背包"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", Color(0.96, 0.82, 0.54))
    content.add_child(title)

    var help := Label.new()
    help.text = "拾取武器後會收入這裡。點擊即可裝備，武器會改變攻擊距離、傷害與攻速。"
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    help.add_theme_font_size_override("font_size", 13)
    content.add_child(help)

    equipment_list = VBoxContainer.new()
    equipment_list.name = "WeaponList"
    equipment_list.add_theme_constant_override("separation", 6)
    content.add_child(equipment_list)

func _layout() -> void:
    super._layout()
    _layout_gameplay_controls()

func _layout_gameplay_controls() -> void:
    if root_control == null or equipment_button == null:
        return
    var size := get_viewport().get_visible_rect().size

    equipment_button.size = Vector2(72, 44)
    equipment_button.position = Vector2(size.x - 164, 16)
    weapon_status.position = Vector2(12, 132)
    weapon_status.size = Vector2(size.x - 24, 22)

    var skill_size := Vector2(64, 64)
    var gap := 8.0
    var start_x := size.x - 78
    var y := size.y - 210
    for i in range(skill_buttons.size()):
        skill_buttons[i].size = skill_size
        skill_buttons[i].position = Vector2(start_x - float(2 - i) * (skill_size.x + gap), y)

    var panel_width := minf(380, size.x - 24)
    var panel_height := minf(430, size.y - 190)
    equipment_panel.size = Vector2(panel_width, panel_height)
    equipment_panel.position = Vector2((size.x - panel_width) * 0.5, maxf(158, (size.y - panel_height) * 0.5))

func _request_skill(slot: int) -> void:
    skill_requested.emit(slot)

func _toggle_equipment_panel() -> void:
    equipment_panel.visible = not equipment_panel.visible
    if equipment_panel.visible and gem_panel != null:
        gem_panel.visible = false

func _toggle_gem_panel() -> void:
    super._toggle_gem_panel()
    if gem_panel.visible and equipment_panel != null:
        equipment_panel.visible = false

func set_weapon_status(text: String) -> void:
    if weapon_status != null:
        weapon_status.text = "武器：" + text

func set_skill_names(names: Array[String]) -> void:
    _skill_names = names.duplicate()
    for i in range(mini(skill_buttons.size(), _skill_names.size())):
        skill_buttons[i].text = "%d\n%s" % [i + 1, _skill_names[i]]

func set_skill_cooldowns(cooldowns: Array[float]) -> void:
    for i in range(mini(skill_buttons.size(), cooldowns.size())):
        var remaining := cooldowns[i]
        var suffix := ""
        if remaining > 0.05:
            suffix = "\n%.1f" % remaining
        skill_buttons[i].text = "%d\n%s%s" % [i + 1, _skill_names[i], suffix]
        skill_buttons[i].disabled = remaining > 0.05

func set_weapon_inventory(items: Array[Dictionary], equipped_name: String) -> void:
    if equipment_list == null:
        return
    for child in equipment_list.get_children():
        child.queue_free()
    for i in range(items.size()):
        var item: Dictionary = items[i]
        var button := Button.new()
        var marker := "✓ " if String(item.get("name", "")) == equipped_name else ""
        button.text = "%s%s｜傷害 %.0f｜%.2fs" % [marker, String(item.get("name", "武器")), float(item.get("damage", 0.0)), float(item.get("cooldown", 0.0))]
        button.custom_minimum_size = Vector2(0, 48)
        button.focus_mode = Control.FOCUS_NONE
        button.add_theme_font_size_override("font_size", 14)
        button.pressed.connect(_request_weapon.bind(i))
        equipment_list.add_child(button)

func _request_weapon(index: int) -> void:
    weapon_equip_requested.emit(index)