extends CanvasLayer

var model: EmberfallLoadout
var app: Node
var root: Control
var panel: PanelContainer
var body: VBoxContainer
var notice: Label
var selected_row: int = 0
var selected_socket: int = -1
var tab: String = "equipment"
var opened: bool = false

func setup(owner_app: Node, data: EmberfallLoadout, font: FontFile) -> void:
    app = owner_app
    model = data
    layer = 20
    process_mode = Node.PROCESS_MODE_ALWAYS
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.theme = RiftFontService.build_theme(font)
    add_child(root)
    var shade := ColorRect.new()
    shade.color = Color(0.01,0.025,0.025,0.85)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(shade)
    panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", style(Color("10211e"),Color("967343")))
    root.add_child(panel)
    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation",12)
    panel.add_child(outer)
    var header := HBoxContainer.new()
    outer.add_child(header)
    var title := Label.new()
    title.text = "燼境 · 自由孔洞"
    title.add_theme_font_size_override("font_size",24)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    header.add_child(button("繼續遊戲 ×",toggle))
    var tabs := HBoxContainer.new()
    outer.add_child(tabs)
    for entry in [["equipment","裝備／孔洞"],["bag","背包"],["gems","寶石資訊"]]:
        tabs.add_child(button(entry[1],func(): tab=entry[0]; selected_socket=-1; rebuild()))
    notice = Label.new()
    notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    outer.add_child(notice)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    outer.add_child(scroll)
    body = VBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation",14)
    scroll.add_child(body)
    get_viewport().size_changed.connect(layout)
    root.hide()
    layout()

func style(fill: Color, border: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = fill
    s.border_color = border
    s.set_border_width_all(1)
    s.set_corner_radius_all(8)
    s.content_margin_left = 12
    s.content_margin_right = 12
    s.content_margin_top = 10
    s.content_margin_bottom = 10
    return s

func button(text_value: String, action: Callable, color: Color = Color("eae6d3")) -> Button:
    var b := Button.new()
    b.text = text_value
    b.custom_minimum_size.y = 44
    b.add_theme_color_override("font_color",color)
    b.add_theme_stylebox_override("normal",style(Color("1a3029"),Color("526044")))
    b.add_theme_stylebox_override("hover",style(Color("294739"),Color("d2ad69")))
    b.add_theme_stylebox_override("pressed",style(Color("365642"),Color("edc879")))
    b.pressed.connect(action)
    return b

func label(text_value: String, parent: Node, color: Color = Color("eae6d3")) -> Label:
    var l := Label.new()
    l.text = text_value
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_color_override("font_color",color)
    parent.add_child(l)
    return l

func layout() -> void:
    if panel == null: return
    var screen: Vector2 = get_viewport().get_visible_rect().size
    panel.position = Vector2(10,10)
    panel.size = Vector2(minf(1050,screen.x-20),screen.y-20)
    panel.position.x = (screen.x-panel.size.x)*0.5

func toggle() -> void:
    opened = not opened
    root.visible = opened
    app.mouse_fire_held = false
    app.move_input = Vector2.ZERO
    get_tree().paused = opened
    if opened: rebuild()
    else: app.call("_refresh_gameplay_ui")

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_B,KEY_I,KEY_ESCAPE]:
        if event.keycode != KEY_ESCAPE or opened:
            toggle()
            get_viewport().set_input_as_handled()

func rebuild() -> void:
    for child in body.get_children():
        body.remove_child(child)
        child.queue_free()
    notice.text = "幻彩石 %d · 匠魂石 %d · 連結石 %d\n%s" % [model.currency.chromatic,model.currency.jeweller,model.currency.fusing,"工坊已開放" if model.forge_unlocked else "擊敗首領後開放工坊"]
    if tab == "equipment": equipment()
    elif tab == "bag": inventory()
    else: gems()

func equipment() -> void:
    for row in range(5):
        var item: Dictionary = model.item_at(row)
        var box := VBoxContainer.new()
        body.add_child(box)
        label(EmberfallLoadout.SLOT_NAMES[row] + " · " + item.get("name","未裝備"),box,Color("dec389"))
        if item.is_empty(): continue
        label("%d 孔已開啟 · %d 孔串連 · %s" % [item.sockets.size(),item.linked,item.get("rarity","common")],box)
        var cluster := Control.new()
        cluster.custom_minimum_size = Vector2(180,180)
        box.add_child(cluster)
        var points: Array = [Vector2(8,8),Vector2(104,8),Vector2(104,104),Vector2(8,104)]
        for p in range(item.sockets.size()):
            if p > 0 and p < int(item.linked):
                var bridge := ColorRect.new()
                bridge.color = Color("d7b86b")
                bridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
                bridge.position = [Vector2.ZERO,Vector2(72,38),Vector2(134,72),Vector2(72,134)][p]
                bridge.size = Vector2(34,6) if p != 2 else Vector2(6,34)
                cluster.add_child(bridge)
            var key: String = model.sockets[row][p]
            var d: Dictionary = model.definition(key)
            var powered: bool = key.begins_with("active:")
            for skill in model.skills():
                if skill.row == row and key.trim_prefix("support:") in skill.supports: powered=true
            var text_value: String = d.get("icon", "○")
            if key.begins_with("active:") and not d.has("aura"):
                text_value += "\n+%d" % int(model.levels.get(key.trim_prefix("active:"),0))
            var color: Color = model.tint(key) if key != "" else Color(EmberfallLoadout.TINTS[item.sockets[p]])
            var b: Button = button(text_value,func(): selected_row=row; selected_socket=p; tab="gems"; rebuild(),color)
            b.position = points[p]
            b.size = Vector2(66,66)
            b.add_theme_stylebox_override("normal",style(Color("274b39") if powered else Color("182722"),color))
            b.tooltip_text = "孔 %d・%s・%s\n不限寶石顏色" % [p+1,d.get("name","空孔"),"生效" if powered else "未生效"]
            b.disabled = p == 0 and item.has("intrinsic")
            cluster.add_child(b)
        for skill in model.skills():
            if skill.row != row: continue
            var key: String = "active:" + skill.active
            label(model.definition(key).name + "\n" + model.skill_info(key,skill),box,model.tint(key))
            if model.definition(key).has("aura"):
                box.add_child(button(("關閉 " if model.auras.get(skill.active,false) else "開啟 ") + model.definition(key).name,func(): model.auras[skill.active]=not model.auras.get(skill.active,false); model.changed.emit(); rebuild()))
        var actions := HFlowContainer.new()
        box.add_child(actions)
        for craft in [["socket","開孔 · 匠魂石 ×2"],["link","連孔 · 連結石 ×2"],["reroll","隨機改色 · 幻彩石 ×1"]]:
            var b: Button = button(craft[1],func(): var msg=model.craft(row,craft[0]); rebuild(); notice.text=msg)
            b.disabled = not model.forge_unlocked
            actions.add_child(b)

func inventory() -> void:
    for item in model.gear:
        label(item.name + " · " + item.slot + " · " + item.rarity,body,Color("dec389"))
        label("%d 孔／%d 孔串連・%s 傷害 +%d%%・護甲 %d・移速 +%d%%" % [item.sockets.size(),item.linked,item.bonus,item.power,item.get("armor",0),item.get("speed",0)],body)
        for affix in item.get("affixes",[]):
            label("%s T%d · %s +%s%s" % [affix.kind,affix.tier,affix.label,affix.value,affix.unit],body)
        var actions := HFlowContainer.new()
        body.add_child(actions)
        for row in range(5):
            if item.slot != EmberfallLoadout.SLOT_TYPES[row]: continue
            var b: Button = button("裝入 " + EmberfallLoadout.SLOT_NAMES[row],func(): var msg=model.equip(row,item.id); rebuild(); notice.text=msg)
            b.disabled = item.id in model.equipped
            actions.add_child(b)

func gems() -> void:
    if selected_socket >= 0:
        label("%s · 孔 %d · 點選寶石裝入" % [EmberfallLoadout.SLOT_NAMES[selected_row],selected_socket+1],body)
        body.add_child(button("取下此孔寶石",func(): var msg=model.install(selected_row,selected_socket,""); rebuild(); notice.text=msg))
        var colors := HFlowContainer.new()
        body.add_child(colors)
        for color in ["R","G","B"]:
            colors.add_child(button("改為 " + {"R":"紅","G":"綠","B":"藍"}[color] + " · 幻彩石 ×2",func(): var msg=model.craft(selected_row,"recolor",selected_socket,color); rebuild(); notice.text=msg,Color(EmberfallLoadout.TINTS[color])))
    for kind in ["active","support"]:
        for id in model.catalog[kind]:
            var key: String = kind+":"+id
            var d: Dictionary = model.definition(key)
            var held: bool = key in model.owned
            if selected_socket >= 0 and not held: continue
            var b: Button = button(d.name + (" · 已持有" if held else " · 尚未持有"),func():
                if selected_socket >= 0:
                    var msg: String = model.install(selected_row,selected_socket,key)
                    tab="equipment"; selected_socket=-1; rebuild(); notice.text=msg
                ,model.tint(key))
            var used: bool = false
            for row in range(5):
                for p in range(4):
                    if model.sockets[row][p] == key and (row != selected_row or p != selected_socket): used=true
            b.disabled = selected_socket < 0 or used or not held
            body.add_child(b)
            label(model.skill_info(key),body,model.tint(key))
