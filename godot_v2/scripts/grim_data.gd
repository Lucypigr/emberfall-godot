extends RefCounted
class_name RiftGrimData

# Original Riftforged data shaped after the data-driven monster records studied in Grim Dawn.
# No proprietary names, assets, or database records are copied here.

static func enemy_archetype(slot: int, force_elite: bool = false) -> Dictionary:
    if force_elite:
        return {
            "id": "rift_champion",
            "name": "菁英裂隙獸",
            "hp": 165.0,
            "speed": 2.05,
            "touch_damage": 15.0,
            "touch_delay": 0.78,
            "behavior": "melee",
            "desired_range": 1.1,
            "skill_delay": 2.6,
            "skill_chance": 0.0,
            "skill_damage": 0.0,
            "low_health_trigger": 0.34,
            "berserk_speed": 1.38,
            "dying_burst": 9.0,
            "loot_profile": "champion",
            "color": Color(1.0, 0.72, 0.28),
            "scale": 1.18,
        }

    match slot % 3:
        0:
            return {
                "id": "rift_stalker",
                "name": "裂隙獵犬",
                "hp": 62.0,
                "speed": 2.55,
                "touch_damage": 9.0,
                "touch_delay": 0.78,
                "behavior": "melee",
                "desired_range": 1.05,
                "skill_delay": 0.0,
                "skill_chance": 0.0,
                "skill_damage": 0.0,
                "low_health_trigger": 0.0,
                "berserk_speed": 1.0,
                "dying_burst": 0.0,
                "loot_profile": "beast",
                "color": Color(0.62, 0.27, 0.76),
                "scale": 0.96,
            }
        1:
            return {
                "id": "rift_warden",
                "name": "裂隙衛士",
                "hp": 98.0,
                "speed": 1.72,
                "touch_damage": 13.0,
                "touch_delay": 0.92,
                "behavior": "melee",
                "desired_range": 1.12,
                "skill_delay": 0.0,
                "skill_chance": 0.0,
                "skill_damage": 0.0,
                "low_health_trigger": 0.38,
                "berserk_speed": 1.32,
                "dying_burst": 0.0,
                "loot_profile": "warden",
                "color": Color(0.72, 0.35, 0.34),
                "scale": 1.08,
            }
        _:
            return {
                "id": "rift_hexer",
                "name": "裂隙咒徒",
                "hp": 72.0,
                "speed": 1.58,
                "touch_damage": 8.0,
                "touch_delay": 1.0,
                "behavior": "ranged",
                "desired_range": 5.8,
                "skill_delay": 2.25,
                "skill_chance": 0.78,
                "skill_damage": 12.0,
                "low_health_trigger": 0.0,
                "berserk_speed": 1.0,
                "dying_burst": 0.0,
                "loot_profile": "caster",
                "color": Color(0.37, 0.60, 0.96),
                "scale": 1.0,
            }

static func scaled_stats(base: Dictionary, level: int) -> Dictionary:
    var out := base.duplicate(true)
    var lv := maxi(1, level)
    out["level"] = lv
    out["hp"] = float(base["hp"]) * (1.0 + float(lv - 1) * 0.16)
    out["touch_damage"] = float(base["touch_damage"]) * (1.0 + float(lv - 1) * 0.11)
    out["skill_damage"] = float(base["skill_damage"]) * (1.0 + float(lv - 1) * 0.10)
    return out
