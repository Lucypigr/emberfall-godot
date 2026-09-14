extends "res://scripts/app_region.gd"

const LoadoutScript = preload("res://scripts/emberfall_loadout.gd")
const PanelScript = preload("res://scripts/emberfall_panel.gd")
const GemCombatScript = preload("res://scripts/emberfall_combat.gd")
const SAVE_PATH: String = "user://emberfall-independent-v1.json"
var loadout: EmberfallLoadout
var forge_panel: CanvasLayer
var gem_combat: Node

func _ready() -> void:
    loadout=LoadoutScript.new()
    _load_progress()
    super._ready()
    if ui == null or player == null: return
    forge_panel=PanelScript.new()
    add_child(forge_panel)
    forge_panel.setup(self,loadout,ui_font)
    var hud: RiftDesktopGameplayUI = ui as RiftDesktopGameplayUI
    for connection in hud.equipment_button.pressed.get_connections():
        hud.equipment_button.pressed.disconnect(connection.callable)
    hud.equipment_button.text="裝備／孔洞"
    hud.equipment_button.pressed.connect(forge_panel.toggle)
    if hud.gem_button != null:
        for connection in hud.gem_button.pressed.get_connections():
            hud.gem_button.pressed.disconnect(connection.callable)
        hud.gem_button.pressed.connect(func(): forge_panel.tab="gems"; forge_panel.toggle())
    gem_combat=GemCombatScript.new()
    add_child(gem_combat)
    gem_combat.setup(self,loadout)
    loadout.changed.connect(_on_loadout_changed)
    _refresh_gameplay_ui()
    ui.set_hint("技能依孔洞自動施放 · B／裝備 配置寶石 · 1 衝刺 · 2／3 藥水")

func _on_loadout_changed() -> void:
    _save_progress()
    _refresh_gameplay_ui()

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    if loadout == null or player == null: return
    var aura: Dictionary = loadout.aura_stats()
    if aura.regen > 0: player_hp=minf(player_max_hp,player_hp+float(aura.regen)*delta)

func _refresh_gameplay_ui() -> void:
    if ui == null or loadout == null: return
    var hud: RiftGameplayUI = ui as RiftGameplayUI
    hud.set_weapon_status("%d 個技能 · 裝備／孔洞配置" % loadout.skills().size())
    var names: Array[String] = ["裂隙衝刺","生命藥水","魔力藥水"]
    hud.set_skill_names(names)
    hud.set_skill_cooldowns(skill_cooldowns)
    hud.skill_buttons[0].tooltip_text="裂隙衝刺 · 位移 4.6 · 消耗魔力 16 · 冷卻 5 秒"
    hud.skill_buttons[1].tooltip_text="生命藥水 · 回復 42 生命"
    hud.skill_buttons[2].tooltip_text="魔力藥水 · 回復 58 魔力"

func _use_skill(slot: int) -> void:
    if slot == 1: _use_flask(0); return
    if slot == 2: _use_flask(1); return
    if slot != 0 or skill_cooldowns[0]>0 or player_mana<16: return
    player_mana-=16
    var direction: Vector3 = _movement_direction()
    if direction.length()<0.1: direction=last_aim_direction
    player.move_and_collide(direction.normalized()*4.6)
    if region_map != null: player.position=region_map.clamp_player(player.position)
    skill_cooldowns[0]=5.0
    _refresh_resource_hud()

func _drop_loot(position: Vector3, entry: Dictionary, guaranteed: bool) -> void:
    if loadout == null: return
    var boss: bool = entry.get("elite",false)
    if guaranteed or randf() < (0.8 if boss else 0.03):
        var item: Dictionary = loadout.roll_gear(maxi(1,int(entry.archetype.level)))
        _spawn_loot_visual(position,{"name":item.name,"color":Color("d4a3ff") if item.rarity=="epic" else (Color("f4d07d") if item.rarity=="rare" else Color("e9e2c9")),"kind":"gear","gear":item,"slot":"裝備"})
    if randf() < (0.35 if boss else 0.05):
        var pool: Array = []
        for kind in ["active","support"]:
            for id in loadout.catalog[kind]:
                var d: Dictionary = loadout.catalog[kind][id]
                if not d.get("exclusive",false) and not d.has("rarity"): pool.append(kind+":"+id)
        var key: String = pool.pick_random()
        _spawn_loot_visual(position+Vector3(0.5,0,0),{"name":loadout.definition(key).name,"color":loadout.tint(key),"kind":"gem","gem":key,"slot":"寶石"})
    if boss:
        loadout.forge_unlocked=true
        loadout.currency.chromatic+=2
        loadout.currency.jeweller+=1
        loadout.currency.fusing+=1
        loadout.changed.emit()
    elif randf()<0.05:
        var kind: String = ["chromatic","jeweller","fusing"].pick_random()
        loadout.currency[kind]+=1
        loadout.changed.emit()

func _pickup_item(item: Dictionary) -> void:
    if item.get("kind","")=="gem": loadout.collect_gem(item.gem)
    elif item.get("kind","")=="gear": loadout.stash(item.gear)
    picked_loot+=1
    ui.set_hint("拾取："+item.name)

func _damage_player(amount: float) -> void:
    var armor: float = float(loadout.aura_stats().armor) if loadout != null else 0.0
    if loadout != null:
        for row in range(5):
            var item: Dictionary = loadout.item_at(row)
            armor+=float(item.get("armor",0))+loadout.affix_total(item,"armor")
    super._damage_player(maxf(1.0,amount-armor))

func _save_progress() -> void:
    var file := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
    if file == null: return
    file.store_string(JSON.stringify({"schema":1,"gear":loadout.gear,"equipped":loadout.equipped,"sockets":loadout.sockets,"owned":loadout.owned,"levels":loadout.levels,"auras":loadout.auras,"currency":loadout.currency,"serial":loadout.serial,"forge":loadout.forge_unlocked}))

func _load_progress() -> void:
    if not FileAccess.file_exists(SAVE_PATH): return
    var state = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
    if not state is Dictionary or state.get("schema",0)!=1: return
    if not state.get("equipped") is Array or state.equipped.size()!=5: return
    if not state.get("sockets") is Array or state.sockets.size()!=5: return
    for row in state.sockets:
        if not row is Array or row.size()!=4: return
    if not state.get("gear") is Array or not state.get("owned") is Array: return
    for field in ["levels","auras","currency"]:
        if not state.get(field) is Dictionary: return
    for item in state.gear:
        if not item is Dictionary or not item.get("sockets") is Array: return
        if item.sockets.size()>4 or item.sockets.size()<1: return
        if not item.has_all(["id","slot","linked","name","rarity","bonus","power"]): return
        if int(item.linked)<0 or int(item.linked)>item.sockets.size(): return
    loadout.gear=state.gear
    loadout.equipped=state.equipped
    loadout.sockets=state.sockets
    loadout.owned=state.owned
    loadout.levels=state.levels
    loadout.auras=state.auras
    for key in loadout.currency: loadout.currency[key]=maxi(0,int(state.currency.get(key,0)))
    loadout.serial=int(state.get("serial",0))
    loadout.forge_unlocked=bool(state.get("forge",false))

func _region_move_speed() -> float:
    if loadout == null: return PLAYER_SPEED
    var speed: float = float(loadout.aura_stats().speed)
    for row in range(5):
        var item: Dictionary = loadout.item_at(row)
        speed += float(item.get("speed",0)) + loadout.affix_total(item,"speed")
    return PLAYER_SPEED * maxf(0.2,1+speed/100.0)
