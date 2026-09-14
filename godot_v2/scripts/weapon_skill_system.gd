extends RefCounted
class_name RiftWeaponSkillSystem

const STARTER_WEAPON := {
    "id": "starter_bow",
    "base_name": "旅者短弓",
    "name": "旅者短弓",
    "slot": "武器",
    "level": 1,
    "rarity": "普通",
    "prefix": {},
    "suffix": {},
    "color": Color(0.86, 0.84, 0.76),
    "weapon_type": "bow",
    "base_damage": 24.0,
    "attack_cooldown": 0.36,
    "range": 11.5,
}

const WEAPON_DEFAULTS := {
    "starter_bow": {"weapon_type":"bow", "base_damage":24.0, "attack_cooldown":0.36, "range":11.5},
    "rust_bow": {"weapon_type":"bow", "base_damage":27.0, "attack_cooldown":0.35, "range":11.8},
    "rift_blade": {"weapon_type":"blade", "base_damage":42.0, "attack_cooldown":0.48, "range":2.55},
    "rift_focus": {"weapon_type":"focus", "base_damage":34.0, "attack_cooldown":0.52, "range":10.2},
}

const SKILLS := [
    {"id":"weapon_skill", "name":"武器技", "short":"武器技", "cooldown":2.4},
    {"id":"burst", "name":"爆裂打擊", "short":"爆裂", "cooldown":4.5},
    {"id":"rift_dash", "name":"裂隙衝刺", "short":"衝刺", "cooldown":5.0},
]

static func starter_weapon() -> Dictionary:
    return normalize_weapon(STARTER_WEAPON)

static func normalize_weapon(item: Dictionary) -> Dictionary:
    if String(item.get("slot", "")) != "武器":
        return {}
    var weapon := item.duplicate(true)
    var id := String(weapon.get("id", "rust_bow"))
    var defaults: Dictionary = WEAPON_DEFAULTS.get(id, WEAPON_DEFAULTS["rust_bow"])
    weapon["weapon_type"] = String(weapon.get("weapon_type", defaults["weapon_type"]))
    weapon["base_damage"] = float(weapon.get("base_damage", defaults["base_damage"]))
    weapon["attack_cooldown"] = float(weapon.get("attack_cooldown", defaults["attack_cooldown"]))
    weapon["range"] = float(weapon.get("range", defaults["range"]))

    var damage_pct := 0.0
    var attack_speed_pct := 0.0
    var flat_damage := 0.0
    var crit_chance := 5.0
    for affix_key in ["prefix", "suffix"]:
        var affix: Dictionary = weapon.get(affix_key, {})
        if affix.is_empty():
            continue
        var stat := String(affix.get("stat", ""))
        var value := float(affix.get("value", 0.0))
        match stat:
            "傷害": damage_pct += value
            "攻速": attack_speed_pct += value
            "火焰": flat_damage += value
            "暴擊": crit_chance += value

    weapon["damage"] = roundf((float(weapon["base_damage"]) * (1.0 + damage_pct / 100.0) + flat_damage) * 10.0) / 10.0
    weapon["cooldown"] = maxf(0.16, float(weapon["attack_cooldown"]) / (1.0 + attack_speed_pct / 100.0))
    weapon["crit_chance"] = clampf(crit_chance, 0.0, 60.0)
    weapon["score"] = float(weapon["damage"]) / float(weapon["cooldown"])
    return weapon

static func skill_catalog() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for skill in SKILLS:
        result.append(skill.duplicate(true))
    return result

static func skill_name(slot: int, weapon_type: String) -> String:
    if slot == 0:
        match weapon_type:
            "blade": return "旋刃"
            "focus": return "三重裂光"
            _: return "三重射擊"
    if slot == 1:
        return "爆裂打擊"
    return "裂隙衝刺"

static func describe_weapon(weapon: Dictionary) -> String:
    if weapon.is_empty():
        return "未裝備武器"
    var type_name := "短弓"
    match String(weapon.get("weapon_type", "bow")):
        "blade": type_name = "短刃"
        "focus": type_name = "法器"
    return "%s｜%s｜傷害 %.0f｜攻速 %.2fs" % [String(weapon.get("name", "武器")), type_name, float(weapon.get("damage", 0.0)), float(weapon.get("cooldown", 0.0))]
