extends RefCounted
class_name RiftFontService

const FONT_PATH := "res://fonts/NotoSansTC-Riftforged.ttf"

static func load_ui_font() -> FontFile:
    # Project fonts must be loaded through ResourceLoader so Godot uses the
    # imported FontFile resource embedded in the export. load_dynamic_font()
    # is intended for external runtime files and was unreliable in iOS Safari.
    var resource := ResourceLoader.load(FONT_PATH, "FontFile", ResourceLoader.CACHE_MODE_REUSE)
    var font := resource as FontFile
    if font == null:
        push_error("Riftforged v2: unable to load imported Traditional Chinese font at %s" % FONT_PATH)
        return null
    if font.data.is_empty():
        push_error("Riftforged v2: imported Traditional Chinese font has no embedded data")
        return null
    font.allow_system_fallback = false
    return font

static func build_theme(font: FontFile) -> Theme:
    if font == null:
        return null
    var theme := Theme.new()
    theme.default_font = font
    theme.default_font_size = 17
    return theme

static func required_glyph_count(font: FontFile) -> int:
    if font == null:
        return 0
    var count := 0
    for sample in ["攻", "擊", "寶", "石", "裂", "隙", "獸", "菁", "英", "◆", "◇"]:
        if font.has_char(sample.unicode_at(0)):
            count += 1
    return count
