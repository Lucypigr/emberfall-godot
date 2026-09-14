extends "res://scripts/app_desktop.gd"

const SKILL_MANA_COSTS: Array[float] = [12.0, 22.0, 16.0]
const MANA_REGEN_PER_SECOND := 11.0
const HEALTH_FLASK_HEAL := 42.0
const MANA_FLASK_RESTORE := 58.0

var player_mana := 100.0
var player_max_mana := 100.0
var flask_charges: Array[int] = [3, 3]
var _resource_ui_accumulator := 0.0

func _ready() -> void:
    super._ready()
    var gameplay_ui := ui as RiftDesktopGameplayUI
    if gameplay_ui != null:
        if not gameplay_ui.flask_requested.is_connected(_use_flask):
            gameplay_ui.flask_requested.connect(_use_flask)
    _refresh_resource_hud()

func _physics_process(delta: float) -> void:
    player_mana = minf(player_max_mana, player_mana + MANA_REGEN_PER_SECOND * delta)
    _resource_ui_accumulator += delta
    super._physics_process(delta)
    if _resource_ui_accumulator >= 0.10:
        _resource_ui_accumulator = 0.0
        _refresh_resource_hud()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key := event as InputEventKey
        if key.pressed and not key.echo:
            if key.keycode == KEY_4:
                _use_flask(0)
                get_viewport().set_input_as_handled()
                return
            if key.keycode == KEY_5:
                _use_flask(1)
                get_viewport().set_input_as_handled()
                return
    super._unhandled_input(event)

func _use_skill(slot: int) -> void:
    if slot < 0 or slot >= SKILL_MANA_COSTS.size():
        return
    if slot >= skill_cooldowns.size() or skill_cooldowns[slot] > 0.0:
        return
    var mana_cost := SKILL_MANA_COSTS[slot]
    if player_mana + 0.001 < mana_cost:
        ui.set_hint("魔力不足：需要 %d" % int(mana_cost))
        return
    player_mana -= mana_cost
    super._use_skill(slot)
    _refresh_resource_hud()

func _use_flask(slot: int) -> void:
    if slot < 0 or slot >= flask_charges.size() or flask_charges[slot] <= 0:
        return
    if slot == 0:
        if player_hp >= player_max_hp - 0.5:
            ui.set_hint("生命已滿")
            return
        flask_charges[0] -= 1
        player_hp = minf(player_max_hp, player_hp + HEALTH_FLASK_HEAL)
        ui.set_hp(player_hp, player_max_hp)
        ui.set_hint("生命藥水：恢復 %d 生命" % int(HEALTH_FLASK_HEAL))
    else:
        if player_mana >= player_max_mana - 0.5:
            ui.set_hint("魔力已滿")
            return
        flask_charges[1] -= 1
        player_mana = minf(player_max_mana, player_mana + MANA_FLASK_RESTORE)
        ui.set_hint("魔力藥水：恢復 %d 魔力" % int(MANA_FLASK_RESTORE))
    _refresh_resource_hud()

func _refresh_resource_hud() -> void:
    var gameplay_ui := ui as RiftDesktopGameplayUI
    if gameplay_ui == null:
        return
    gameplay_ui.set_hp(player_hp, player_max_hp)
    gameplay_ui.set_mana(player_mana, player_max_mana)
    gameplay_ui.set_flask_charges(flask_charges)

func debug_resource_state() -> Dictionary:
    return {
        "hp": player_hp,
        "max_hp": player_max_hp,
        "mana": player_mana,
        "max_mana": player_max_mana,
        "mana_regen": MANA_REGEN_PER_SECOND,
        "skill_mana_costs": SKILL_MANA_COSTS.duplicate(),
        "flask_charges": flask_charges.duplicate(),
    }

func debug_set_mana(value: float) -> void:
    player_mana = clampf(value, 0.0, player_max_mana)
    _refresh_resource_hud()

func debug_set_hp(value: float) -> void:
    player_hp = clampf(value, 0.0, player_max_hp)
    _refresh_resource_hud()
