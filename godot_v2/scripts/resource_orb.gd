extends Control
class_name RiftResourceOrb

var _value_label: Label
var _caption_label: Label
var _liquid_color := Color.WHITE
var _empty_color := Color(0.022, 0.028, 0.040, 1.0)
var _rim_color := Color(0.42, 0.31, 0.16, 1.0)
var _current := 0.0
var _maximum := 1.0

func setup(font: FontFile, caption: String, liquid_color: Color) -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _liquid_color = liquid_color

    _caption_label = Label.new()
    _caption_label.name = "Caption"
    _caption_label.text = caption
    _caption_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _caption_label.offset_top = 23
    _caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _caption_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    _caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _caption_label.add_theme_font_override("font", font)
    _caption_label.add_theme_font_size_override("font_size", 13)
    _caption_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.72))
    add_child(_caption_label)

    _value_label = Label.new()
    _value_label.name = "Value"
    _value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _value_label.offset_top = 40
    _value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _value_label.add_theme_font_override("font", font)
    _value_label.add_theme_font_size_override("font_size", 15)
    _value_label.add_theme_color_override("font_color", Color.WHITE)
    _value_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.96))
    _value_label.add_theme_constant_override("shadow_offset_x", 1)
    _value_label.add_theme_constant_override("shadow_offset_y", 2)
    add_child(_value_label)

    set_value(1.0, 1.0)

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

func _draw() -> void:
    if size.x <= 2.0 or size.y <= 2.0:
        return
    var center := size * 0.5
    var radius := minf(size.x, size.y) * 0.47
    var ratio_value := ratio()

    # Draw the empty glass first. The colored liquid is drawn as horizontal
    # scan lines clipped mathematically to the circular interior. This avoids
    # relying on a custom CanvasItem shader, which was not displaying the orb
    # colors reliably in the Web/Compatibility renderer.
    draw_circle(center, radius, _empty_color)

    if ratio_value > 0.001:
        var top_y := center.y + radius - (radius * 2.0 * ratio_value)
        var bottom_y := center.y + radius
        var line_count := maxi(36, int(ceil(radius * 1.5)))
        for i in range(line_count + 1):
            var t := float(i) / float(line_count)
            var y := lerpf(top_y, bottom_y, t)
            var dy := y - center.y
            var half_width := sqrt(maxf(radius * radius - dy * dy, 0.0))
            if half_width > 0.0:
                draw_line(
                    Vector2(center.x - half_width, y),
                    Vector2(center.x + half_width, y),
                    _liquid_color,
                    2.2,
                    true
                )

    # Glass/rim treatment kept deliberately simple and Web-safe.
    draw_arc(center, radius, 0.0, TAU, 96, _rim_color, 5.0, true)
    draw_arc(center, radius * 0.84, 0.0, TAU, 96, Color(0.76, 0.62, 0.36, 0.48), 2.0, true)
    draw_circle(center + Vector2(-radius * 0.28, -radius * 0.26), radius * 0.11, Color(1, 1, 1, 0.10))

func set_value(current: float, maximum: float) -> void:
    _maximum = maxf(maximum, 0.001)
    _current = clampf(current, 0.0, _maximum)
    if _value_label != null:
        _value_label.text = "%d / %d" % [int(round(_current)), int(round(_maximum))]
    queue_redraw()

func ratio() -> float:
    return _current / _maximum

func debug_liquid_color() -> Color:
    return _liquid_color

func debug_render_mode() -> String:
    return "canvas_draw"
