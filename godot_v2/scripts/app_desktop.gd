extends "res://scripts/app_gameplay.gd"

const DesktopGameplayUIScript = preload("res://scripts/desktop_gameplay_ui.gd")
const DESKTOP_BASE_SIZE := Vector2i(1280, 720)
const MOBILE_BASE_SIZE := Vector2i(390, 844)

var desktop_layout_enabled := false
var mobile_landscape_enabled := false

func _enter_tree() -> void:
    desktop_layout_enabled = _should_use_desktop_layout()
    mobile_landscape_enabled = _is_mobile_runtime() and desktop_layout_enabled
    if desktop_layout_enabled:
        _apply_desktop_window_profile()

func _ready() -> void:
    super._ready()
    get_window().size_changed.connect(_on_window_size_changed)
    _sync_layout_profile(true)
    _refresh_gameplay_ui()

func _build_ui() -> void:
    ui = DesktopGameplayUIScript.new()
    ui.name = "MobileUI"
    add_child(ui)
    ui.setup(ui_font)
    ui.movement_changed.connect(func(value: Vector2): move_input = value)
    ui.attack_requested.connect(_attack)
    var gameplay_ui := ui as RiftDesktopGameplayUI
    gameplay_ui.skill_requested.connect(_use_skill)
    gameplay_ui.weapon_equip_requested.connect(_equip_weapon_index)
    gameplay_ui.fullscreen_requested.connect(_toggle_fullscreen)
    gameplay_ui.set_desktop_mode(desktop_layout_enabled)
    ui.set_hp(player_hp, player_max_hp)
    _apply_runtime_hint()

func _unhandled_input(event: InputEvent) -> void:
    if desktop_layout_enabled and not mobile_landscape_enabled and event is InputEventKey:
        var key := event as InputEventKey
        if key.pressed and not key.echo and (key.keycode == KEY_F or key.keycode == KEY_F11):
            _toggle_fullscreen()
            get_viewport().set_input_as_handled()
            return
    super._unhandled_input(event)

func _on_window_size_changed() -> void:
    call_deferred("_sync_layout_profile")

func _sync_layout_profile(force_refresh: bool = false) -> void:
    var next_desktop := _should_use_desktop_layout()
    var next_mobile_landscape := _is_mobile_runtime() and next_desktop
    var changed := next_desktop != desktop_layout_enabled or next_mobile_landscape != mobile_landscape_enabled
    if not changed and not force_refresh:
        _apply_mobile_landscape_touch_overlay()
        return

    desktop_layout_enabled = next_desktop
    mobile_landscape_enabled = next_mobile_landscape
    if desktop_layout_enabled:
        _apply_desktop_window_profile()
        _apply_desktop_camera_profile()
    else:
        _apply_mobile_window_profile()
        _apply_mobile_camera_profile()

    var gameplay_ui := ui as RiftDesktopGameplayUI
    if gameplay_ui != null:
        gameplay_ui.set_desktop_mode(desktop_layout_enabled)
    _apply_runtime_hint()
    _apply_mobile_landscape_touch_overlay()

func _apply_desktop_window_profile() -> void:
    var window := get_window()
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
    window.content_scale_size = DESKTOP_BASE_SIZE
    if not _is_mobile_runtime() and not OS.has_feature("web") and not OS.has_feature("headless"):
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _apply_mobile_window_profile() -> void:
    var window := get_window()
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
    window.content_scale_size = MOBILE_BASE_SIZE

func _apply_desktop_camera_profile() -> void:
    if camera == null:
        return
    camera.keep_aspect = Camera3D.KEEP_HEIGHT
    camera.size = 16.8
    camera.position = Vector3(0.0, 11.2, 12.4)

func _apply_mobile_camera_profile() -> void:
    if camera == null:
        return
    camera.keep_aspect = Camera3D.KEEP_WIDTH
    camera.size = 17.5
    camera.position = Vector3(0.0, 10.8, 11.4)

func _apply_runtime_hint() -> void:
    if ui == null:
        return
    if mobile_landscape_enabled:
        ui.set_hint("手機橫屏：桌面版視野＋介面｜左側搖桿移動｜右側攻擊／技能")
    elif desktop_layout_enabled:
        ui.set_hint("WASD 移動｜按住左鍵射擊｜1/2/3 技能｜右上可切換全螢幕")
    else:
        ui.set_hint("手機：搖桿＋攻擊／技能｜拾取武器可直接換裝")

func _apply_mobile_landscape_touch_overlay() -> void:
    var gameplay_ui := ui as RiftDesktopGameplayUI
    if gameplay_ui == null or not mobile_landscape_enabled:
        return
    var size := get_viewport().get_visible_rect().size
    if gameplay_ui.joystick_back != null:
        gameplay_ui.joystick_back.visible = true
        gameplay_ui.joystick_back.size = Vector2(116, 116)
        gameplay_ui.joystick_back.position = Vector2(18, maxf(118.0, size.y - 302.0))
        gameplay_ui.joystick_center = gameplay_ui.joystick_back.position + gameplay_ui.joystick_back.size * 0.5
        gameplay_ui.call("_set_knob", gameplay_ui.movement)
    if gameplay_ui.attack_button != null:
        gameplay_ui.attack_button.visible = true
        gameplay_ui.attack_button.size = Vector2(82, 82)
        gameplay_ui.attack_button.position = Vector2(size.x - 100.0, maxf(132.0, size.y - 278.0))
        gameplay_ui.attack_button.add_theme_font_size_override("font_size", 15)

func _toggle_fullscreen() -> void:
    var mode := DisplayServer.window_get_mode()
    var is_fullscreen := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _is_mobile_runtime() -> bool:
    return (
        OS.has_feature("mobile")
        or OS.has_feature("android")
        or OS.has_feature("ios")
        or OS.has_feature("web_android")
        or OS.has_feature("web_ios")
    )

func _should_use_desktop_layout() -> bool:
    if not _is_mobile_runtime():
        return true
    return _is_landscape_display()

func _is_landscape_display() -> bool:
    if OS.has_feature("web"):
        var browser_landscape = JavaScriptBridge.eval("window.innerWidth > window.innerHeight", true)
        if browser_landscape != null:
            return bool(browser_landscape)
    var window_size := DisplayServer.window_get_size()
    return window_size.x > window_size.y

func debug_desktop_profile() -> Dictionary:
    var gameplay_ui := ui as RiftDesktopGameplayUI
    return {
        "enabled": desktop_layout_enabled,
        "mobile_landscape": mobile_landscape_enabled,
        "content_scale_size": get_window().content_scale_size,
        "camera_keep_aspect": camera.keep_aspect if camera != null else -1,
        "joystick_visible": gameplay_ui.joystick_back.visible if gameplay_ui != null and gameplay_ui.joystick_back != null else true,
        "attack_button_visible": gameplay_ui.attack_button.visible if gameplay_ui != null and gameplay_ui.attack_button != null else true,
        "fullscreen_button": gameplay_ui.fullscreen_button != null if gameplay_ui != null else false,
    }
