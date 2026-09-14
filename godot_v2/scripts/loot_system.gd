extends RefCounted
class_name RiftLootSystem

# Simplified original loot pipeline inspired by the hierarchy studied in Grim Dawn:
# Master profile -> level band -> dynamic weighted item table -> weighted affixes.

const BASE_ITEMS := [
    {"id":"rust_bow", "name":"殘鐵短弓", "slot":"武器", "weapon_type":"bow", "base_damage":27.0, "attack_cooldown":0.35, "range":11.8, "min_level":1, "weight":24.0},
    {"id":"rift_blade", "name":"裂痕短刃", "slot":"武器", "weapon_type":"blade", "base_damage":42.0, "attack_cooldown":0.48, "range":2.55, "min_level":1, "weight":22.0},
    {"id":"rift_focus", "name":"咒痕法器", "slot":"武器", "weapon_type":"focus", "base_damage":34.0, "attack_cooldown":0.52, "range":10.2, "min_level":2, "weight":15.0},
    {"id":"hide_coat", "name":"旅者皮甲", "slot":"護甲", "min_level":1, "weight":22.0},
    {"id":"old_boots", "name":"荒徑長靴", "slot":"鞋", "min_level":1, "weight":16.0},
    {"id":"rift_charm", "name":"微光護符", "slot":"護符", "min_level":2, "weight":12.0},
    {"id":"warden_plate", "name":"衛士殘甲", "slot":"護甲", "min_level":3, "weight":8.0},
]

const PREFIXES := [
    {"name":"鋒銳的", "weight":18.0, "stat":"傷害", "value":8},
    {"name":"堅韌的", "weight":18.0, "stat":"生命", "value":18},
    {"name":"迅捷的", "weight":15.0, "stat":"攻速", "value":6},
    {"name":"灼痕的", "weight":10.0, "stat":"火焰", "value":10},
    {"name":"裂隙的", "weight":7.0, "stat":"暴擊", "value":4},
]

const SUFFIXES := [
    {"name":"之獵殺", "weight":18.0, "stat":"傷害", "value":7},
    {"name":"之守望", "weight":18.0, "stat":"護甲", "value":12},
    {"name":"之疾行", "weight":15.0, "stat":"移速", "value":5},
    {"name":"之餘燼", "weight":10.0, "stat":"火焰", "value":9},
    {"name":"之深痕", "weight":7.0, "stat":"暴擊", "value":3},
]

static func roll_master(profile: String, monster_level: int, elite: bool, guaranteed: bool = false) -> Array[Dictionary]:
    var drops: Array[Dictionary] = []
    var drop_chance := 1.0 if guaranteed else (0.92 if elite else 0.46)
    if randf() > drop_chance:
        return drops

    drops.append(_roll_dynamic(profile, monster_level, elite))
    if elite and randf() < 0.42:
        drops.append(_roll_dynamic(profile, monster_level, true))
    return drops

static func _roll_dynamic(profile: String, monster_level: int, elite: bool) -> Dictionary:
    var candidates: Array[Dictionary] = []
    for source in BASE_ITEMS:
        if int(source["min_level"]) > monster_level + 1:
            continue
        var item: Dictionary = source.duplicate(true)
        if profile == "caster" and String(item["id"]) == "rift_focus":
            item["weight"] = float(item["weight"]) * 2.6
        elif profile == "warden" and String(item["id"]) == "warden_plate":
            item["weight"] = float(item["weight"]) * 2.2
        candidates.append(item)
    if candidates.is_empty():
        candidates.append(BASE_ITEMS[0].duplicate(true))

    var base := _weighted_pick(candidates).duplicate(true)
    var rarity_roll := randf()
    var rarity := "普通"
    var affix_count := 0
    if elite:
        if rarity_roll < 0.28:
            rarity = "稀有"
            affix_count = 2
        elif rarity_roll < 0.74:
            rarity = "魔法"
            affix_count = 1
    else:
        if rarity_roll < 0.10:
            rarity = "稀有"
            affix_count = 2
        elif rarity_roll < 0.42:
            rarity = "魔法"
            affix_count = 1

    var prefix: Dictionary = {}
    var suffix: Dictionary = {}
    if affix_count >= 1:
        prefix = _weighted_pick(PREFIXES).duplicate(true)
    if affix_count >= 2:
        suffix = _weighted_pick(SUFFIXES).duplicate(true)

    var display_name := String(base["name"])
    if not prefix.is_empty():
        display_name = String(prefix["name"]) + display_name
    if not suffix.is_empty():
        display_name += String(suffix["name"])

    var color := Color(0.84, 0.84, 0.80)
    if rarity == "魔法":
        color = Color(0.44, 0.66, 1.0)
    elif rarity == "稀有":
        color = Color(1.0, 0.82, 0.28)

    var result := {
        "id": String(base["id"]),
        "base_name": String(base["name"]),
        "name": display_name,
        "slot": String(base["slot"]),
        "level": maxi(1, monster_level),
        "rarity": rarity,
        "prefix": prefix,
        "suffix": suffix,
        "color": color,
        "profile": profile,
    }
    for key in ["weapon_type", "base_damage", "attack_cooldown", "range"]:
        if base.has(key):
            result[key] = base[key]
    return result

static func _weighted_pick(entries: Array) -> Dictionary:
    var total := 0.0
    for entry in entries:
        total += float(entry["weight"])
    var roll := randf() * total
    for entry in entries:
        roll -= float(entry["weight"])
        if roll <= 0.0:
            return entry
    return entries.back()
