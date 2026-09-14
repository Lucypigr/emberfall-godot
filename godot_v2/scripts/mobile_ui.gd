extends CanvasLayer
class_name RiftMobileUI

signal movement_changed(value: Vector2)
signal attack_requested

const JOYSTICK_RADIUS := 52.0

var root_control: Control
var ui_theme: Theme
var joystick_back: Panel
var joystick_knob: Panel
var attack_button: Button
var gem_button: Button
var gem_panel: Panel
var title_label: Label
var status_label: Label
var hint_label: Label
var hp_bar: ProgressBar

var joystick_touch_id := -1
var joystick_center := Vector2.ZERO
var movement := Vector2.ZERO

func setup(font: FontFile) -> void:
    ui_theme = RiftFontService.build_theme(font)
    root_control = Control.new()
    root_control.name = "Root"
    root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_control.mouse_filter = Control.MOUSE_FILTER_PASS
    root_control.theme = ui_theme
    add_child(root_control)

    title_label = Label.new()
    title_label.name = "Title"
    title_label.text = "裂隙遠征 · 重製版"
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 22)
    title_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.70))
    root_control.add_child(title_label)

    status_label = Label.new()
    status_label.name = "Status"
    status_label.text = "生命 100 / 100"
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 16)
    root_control.add_child(status_label)

    hp_bar = ProgressBar.new()
    hp_bar.name = "HpBar"
    hp_bar.min_value = 0
    hp_bar.max_value = 100
    hp_bar.value = 100
    hp_bar.show_percentage = false
    root_control.add_child(hp_bar)

    hint_label = Label.new()
    hint_label.name = "Hint"
    hint_label.text = "手機：搖桿／攻擊 · 電腦：WASD＋滑鼠左鍵射擊"
    hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint_label.add_theme_font_size_override("font_size", 13)
    hint_label.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88))
    root_control.add_child(hint_label)

    gem_button = Button.new()
    gem_button.name = "GemButton"
    gem_button.text = "寶石"
    gem_button.focus_mode = Control.FOCUS_NONE
    gem_button.add_theme_font_size_override("font_size", 16)
    gem_button.add_theme_stylebox_override("normal", _round_style(Color(0.08, 0.13, 0.22, 0.94), 16))
    gem_button.add_theme_stylebox_override("pressed", _round_style(Color(0.12, 0.22, 0.38, 0.98), 16))
    gem_button.pressed.connect(_toggle_gem_panel)
    root_control.add_child(gem_button)

    attack_button = Button.new()
    attack_button.name = "AttackButton"
    attack_button.text = "攻擊"
    attack_button.focus_mode = Control.FOCUS_NONE
    attack_button.add_theme_font_size_override("font_size", 20)
    attack_button.add_theme_stylebox_override("normal", _round_style(Color(0.46, 0.10, 0.13, 0.88), 48))
    attack_button.add_theme_stylebox_override("pressed", _round_style(Color(0.76, 0.18, 0.20, 0.98), 48))
    attack_button.pressed.connect(func(): attack_requested.emit())
    root_control.add_child(attack_button)

    joystick_back = Panel.new()
    joystick_back.name = "Joystick"
    joystick_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    joystick_back.add_theme_stylebox_override("panel", _round_style(Color(0.07, 0.09, 0.13, 0.58), 70))
    root_control.add_child(joystick_back)

    joystick_knob = Panel.new()
    joystick_knob.name = "JoystickKnob"
    joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
    joystick_knob.add_theme_stylebox_override("panel", _round_style(Color(0.66, 0.72, 0.84, 0.78), 30))
    joystick_back.add_child(joystick_knob)

    _build_gem_panel()
    get_viewport().size_changed.connect(_layout)
    _layout()

func _build_gem_panel() -> void:
    gem_panel = Panel.new()
    gem_panel.name = "GemPanel"
    gem_panel.visible = false
    gem_panel.add_theme_stylebox_override("panel", _round_style(Color(0.025, 0.032, 0.048, 0.985), 20))
    root_control.add_child(gem_panel)

    var content := VBoxContainer.new()
    content.name = "Content"
    content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.offset_left = 16
    content.offset_top = 16
    content.offset_right = -16
    content.offset_bottom = -16
    content.add_theme_constant_override("separation", 12)
    gem_panel.add_child(content)

    var panel_title := Label.new()
    panel_title.name = "GemTitle"
    panel_title.text = "裂隙寶石 · 四連孔"
    panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    panel_title.add_theme_font_size_override("font_size", 22)
    panel_title.add_theme_color_override("font_color", Color(0.96, 0.82, 0.54))
    content.add_child(panel_title)

    var help := Label.new()
    help.name = "GemHelp"
    help.text = "這是重製版的乾淨介面測試。確認中文字正常後，再移植完整寶石規則。"
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    help.add_theme_font_size_override("font_size", 14)
    content.add_child(help)

    var sockets := HBoxContainer.new()
    sockets.name = "Sockets"
    sockets.alignment = BoxContainer.ALIGNMENT_CENTER
    sockets.add_theme_constant_override("separation", 8)
    content.add_child(sockets)

    for i in range(4):
        var socket := Label.new()
        socket.name = "Socket%d" % i
        socket.custom_minimum_size = Vector2(66, 66)
        socket.text = "◆" if i == 0 else "◇"
        socket.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        socket.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        socket.add_theme_font_size_override("font_size", 34)
        socket.add_theme_color_override("font_color", Color(0.94, 0.34, 0.27) if i == 0 else Color(0.67, 0.72, 0.82))
        sockets.add_child(socket)

    var stash_title := Label.new()
    stash_title.text = "寶石背包"
    stash_title.add_theme_font_size_override("font_size", 17)
    content.add_child(stash_title)

    for text in ["翠綠連鎖", "翠綠多重", "緋紅爆裂"]:
        var item := Button.new()
        item.text = text
        item.focus_mode = Control.FOCUS_NONE
        item.custom_minimum_size = Vector2(0, 52)
        item.add_theme_font_size_override("font_size", 17)
        content.add_child(item)

func _layout() -> void:
    if root_control == null:
        return
    var size := get_viewport().get_visible_rect().size

    title_label.position = Vector2(16, 18)
    title_label.size = Vector2(size.x - 100, 30)
    status_label.position = Vector2(16, 52)
    status_label.size = Vector2(size.x - 32, 24)
    hp_bar.position = Vector2(20, 80)
    hp_bar.size = Vector2(size.x - 40, 16)
    hint_label.position = Vector2(12, 102)
    hint_label.size = Vector2(size.x - 24, 28)

    gem_button.size = Vector2(72, 44)
    gem_button.position = Vector2(size.x - 84, 16)

    attack_button.size = Vector2(96, 96)
    attack_button.position = Vector2(size.x - 122, size.y - 132)

    joystick_back.size = Vector2(140, 140)
    joystick_back.position = Vector2(18, size.y - 170)
    joystick_center = joystick_back.position + joystick_back.size * 0.5
    _set_knob(movement)

    var panel_width := minf(364, size.x - 24)
    var panel_height := minf(520, size.y - 160)
    gem_panel.size = Vector2(panel_width, panel_height)
    gem_panel.position = Vector2((size.x - panel_width) * 0.5, maxf(118, (size.y - panel_height) * 0.5))

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            var size := get_viewport().get_visible_rect().size
            if joystick_touch_id == -1 and touch.position.x < size.x * 0.55 and touch.position.y > size.y * 0.45:
                joystick_touch_id = touch.index
                _update_joystick(touch.position)
                get_viewport().set_input_as_handled()
        elif touch.index == joystick_touch_id:
            joystick_touch_id = -1
            movement = Vector2.ZERO
            movement_changed.emit(movement)
            _set_knob(movement)
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == joystick_touch_id:
            _update_joystick(drag.position)
            get_viewport().set_input_as_handled()

func _update_joystick(screen_position: Vector2) -> void:
    var delta := screen_position - joystick_center
    movement = delta.limit_length(JOYSTICK_RADIUS) / JOYSTICK_RADIUS
    if movement.length() < 0.08:
        movement = Vector2.ZERO
    movement_changed.emit(movement)
    _set_knob(movement)

func _set_knob(value: Vector2) -> void:
    if joystick_knob == null:
        return
    joystick_knob.size = Vector2(58, 58)
    var center := joystick_back.size * 0.5 - joystick_knob.size * 0.5
    joystick_knob.position = center + value * JOYSTICK_RADIUS

func _toggle_gem_panel() -> void:
    gem_panel.visible = not gem_panel.visible

func set_hp(current: float, maximum: float) -> void:
    hp_bar.max_value = maximum
    hp_bar.value = current
    status_label.text = "生命 %d / %d" % [int(current), int(maximum)]

func set_hint(text: String) -> void:
    hint_label.text = text

func _round_style(color: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.border_color = Color(1, 1, 1, 0.13)
    return style
