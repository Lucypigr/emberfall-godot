extends RefCounted
class_name EmberfallLoadout

signal changed
const CATALOG_PATH = "res://data/emberfall.json"
const SLOT_TYPES = ["weapon", "weapon", "weapon", "cloak", "legs"]
const SLOT_NAMES = ["武器欄 01", "武器欄 02", "武器欄 03", "披風", "腿部"]
const TINTS = {"R": "#e28e7c", "G": "#aed591", "B": "#91ccec", "W": "#eae6d3"}
var catalog: Dictionary = {}
var gear: Array = []
var equipped: Array = ["starter", "", "", "", ""]
var sockets: Array = [["active:fireball", "", "", ""], ["", "", "", ""], ["", "", "", ""], ["", "", "", ""], ["", "", "", ""]]
var owned: Array = ["active:fireball"]
var levels: Dictionary = {}
var auras: Dictionary = {}
var currency: Dictionary = {"chromatic": 0, "jeweller": 0, "fusing": 0}
var forge_unlocked: bool = false
var serial: int = 0

func _init() -> void:
    catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
    gear = [{"id":"starter", "name":"旅人的朽木杖", "slot":"weapon", "rarity":"common", "bonus":"spell", "power":0, "sockets":["B", "W"], "linked":2}]

func definition(key: String) -> Dictionary:
    var pair = key.split(":")
    if pair.size() != 2 or not catalog.has(pair[0]):
        return {}
    return catalog[pair[0]].get(pair[1], {})

func tint(key: String) -> Color:
    return Color(TINTS.get(definition(key).get("socket", "W"), TINTS.W))

func item_at(row: int) -> Dictionary:
    if row < 0 or row >= equipped.size():
        return {}
    for item in gear:
        if item.id == equipped[row]:
            return item
    return {}

func compatible(active: String, support: String) -> bool:
    var a: Dictionary = definition("active:" + active)
    var s: Dictionary = definition("support:" + support)
    for tag in s.get("tags", []):
        if tag in a.get("tags", []):
            return true
    return false

func skills() -> Array:
    var result: Array = []
    for row in range(5):
        var item: Dictionary = item_at(row)
        if item.is_empty():
            continue
        for pos in range(item.sockets.size()):
            var key: String = sockets[row][pos]
            if not key.begins_with("active:") or definition(key).is_empty():
                continue
            var id: String = key.trim_prefix("active:")
            var supports: Array = []
            for other in range(item.sockets.size()):
                var candidate: String = sockets[row][other]
                if pos < int(item.linked) and other < int(item.linked) and candidate.begins_with("support:"):
                    var sid: String = candidate.trim_prefix("support:")
                    if compatible(id, sid):
                        supports.append(sid)
            result.append({"active":id, "supports":supports, "row":row, "socket":pos, "weapon":item, "key":"%d:%d:%s" % [row,pos,id]})
    return result

func install(row: int, pos: int, key: String) -> String:
    var item: Dictionary = item_at(row)
    if item.is_empty() or pos < 0 or pos >= item.sockets.size():
        return "此孔尚未開啟"
    if item.has("intrinsic") and pos == 0:
        return "傳說專屬技能固定於首孔"
    if key != "":
        if key not in owned or definition(key).is_empty() or definition(key).get("exclusive", false):
            return "尚未取得此寶石"
        for r in range(5):
            for p in range(4):
                if sockets[r][p] == key and (r != row or p != pos):
                    return "寶石已裝在其他孔，請先取下"
    var previous: String = sockets[row][pos]
    sockets[row][pos] = key
    if previous != key:
        auras.erase(previous.trim_prefix("active:"))
    changed.emit()
    return "已取下寶石" if key == "" else "已裝入；相連且相容的輔助自動生效"

func equip(row: int, id: String) -> String:
    if row < 0 or row >= 5:
        return "裝備欄不存在"
    for item in gear:
        if item.id != id:
            continue
        if item.slot != SLOT_TYPES[row] or (id in equipped and equipped[row] != id):
            return "類型不符或已裝在其他欄"
        if item.has("intrinsic"):
            for other in range(5):
                if other != row and item_at(other).get("intrinsic", "") == item.intrinsic:
                    return "同一專屬技能只能裝備一把"
        equipped[row] = id
        for p in range(4):
            if p >= item.sockets.size() or definition(sockets[row][p]).get("exclusive", false):
                sockets[row][p] = ""
        if item.has("intrinsic"):
            sockets[row][0] = "active:" + item.intrinsic
        var equipped_ids: Array = skills().map(func(s): return s.active)
        for aura in auras.keys():
            if aura not in equipped_ids:
                auras.erase(aura)
        changed.emit()
        return "已裝備 " + item.name
    return "找不到裝備"

func craft(row: int, action: String, pos: int = 0, color: String = "B") -> String:
    if not forge_unlocked:
        return "擊敗首領後開放工坊"
    var item: Dictionary = item_at(row)
    if item.is_empty():
        return "尚未裝備"
    var type: String = "chromatic"
    var cost: int = 2
    match action:
        "socket":
            if item.sockets.size() >= 4: return "已達 4 孔上限"
            type = "jeweller"
        "link":
            if item.linked >= item.sockets.size(): return "現有孔洞已全部連結"
            type = "fusing"
        "recolor":
            if pos < 0 or pos >= item.sockets.size() or color not in ["R", "G", "B"]: return "請選擇有效孔位與顏色"
            if pos == 0 and item.has("intrinsic"): return "專屬孔固定白色"
            if item.sockets[pos] == color: return "已經是此顏色"
        "reroll": cost = 1
        _: return "未知製作方式"
    if currency[type] < cost:
        return "通貨不足，需要 %d 顆" % cost
    currency[type] -= cost
    match action:
        "socket": item.sockets.append(["R", "G", "B"].pick_random())
        "link": item.linked += 1
        "recolor": item.sockets[pos] = color
        "reroll":
            for p in range(item.sockets.size()):
                item.sockets[p] = "W" if p == 0 and item.has("intrinsic") else ["R", "G", "B"].pick_random()
    changed.emit()
    return "製作完成"

func collect_gem(key: String) -> void:
    if definition(key).is_empty(): return
    if key not in owned:
        owned.append(key)
    elif key.begins_with("active:") and not definition(key).has("aura"):
        var id: String = key.trim_prefix("active:")
        levels[id] = int(levels.get(id, 0)) + 1
    else:
        currency.jeweller += 1
    changed.emit()

func stash(item: Dictionary) -> void:
    gear.append(item)
    for row in range(5):
        if equipped[row] == "" and SLOT_TYPES[row] == item.slot:
            equip(row, item.id)
            break
    if gear.size() > 40:
        for old in gear:
            if old.id not in equipped and old.rarity != "legendary":
                gear.erase(old)
                currency.jeweller += 2
                break
    changed.emit()

func roll_gear(tier: int) -> Dictionary:
    var pool: Array = catalog.weapons + catalog.armor
    var item: Dictionary = pool.pick_random().duplicate(true)
    serial += 1
    var roll: float = randf()
    var rarity: String = "epic" if tier >= 7 and roll > 0.6 else ("rare" if roll > 0.4 else "common")
    var power: int = 8 + tier * 3 + (20 if rarity == "epic" else (10 if rarity == "rare" else 0))
    item.merge({"id":"gear-%d" % serial,"slot":item.get("slot","weapon"),"rarity":rarity,"power":power,"sockets":[],"linked":2,"affixes":[]})
    item.armor = 2 + int(power / 8) if item.slot == "cloak" else 0
    item.speed = mini(25, 5 + int(power / 4)) if item.slot == "legs" else 0
    for p in range(mini(4, 2 + (1 if tier >= 4 else 0) + (1 if rarity == "epic" else 0))):
        item.sockets.append("W" if p == 0 else ["R", "G", "B"].pick_random())
    if item.slot == "weapon":
        for kind in ["prefix", "suffix"]:
            var choices: Array = catalog.affixes.filter(func(a): return a.kind == kind).duplicate(true)
            choices.shuffle()
            for n in range(2 if rarity == "epic" else (1 if rarity == "rare" else 0)):
                var affix: Dictionary = choices[n]
                affix.tier = 1 if tier >= 7 else (2 if tier >= 4 else 3)
                affix.value = roundf(randf_range(affix.min, affix.max) * (1 + (3 - affix.tier) * 0.5))
                item.affixes.append(affix)
                if n == 0: item.name = affix.name + item.name if kind == "prefix" else item.name + affix.name
    return item

func affix_total(item: Dictionary, stat: String) -> float:
    var total: float = 0.0
    for a in item.get("affixes", []):
        if a.stat == stat: total += float(a.value)
    return total

func aura_stats() -> Dictionary:
    var result: Dictionary = {"damage":1.0,"speed":0.0,"armor":0.0,"regen":0.0}
    for row in skills():
        var d: Dictionary = definition("active:" + row.active)
        if d.has("aura") and auras.get(row.active, false):
            result.damage *= float(d.aura.get("damage", 1))
            for key in ["speed", "armor", "regen"]:
                result[key] += float(d.aura.get(key, 0))
    return result

func compile(row: Dictionary, damage: float = 24.0, attack_rate: float = 1.8) -> Dictionary:
    var id: String = row.active
    var a: Dictionary = definition("active:" + id)
    if a.is_empty(): return {}
    var w: Dictionary = row.get("weapon", {})
    var s: Dictionary = {"id":id,"color":a.color,"damage":(float(a.damage)+affix_total(w,"flat"))*(damage/24.0)*float(aura_stats().damage)*(1+int(levels.get(id,0))*0.12),"rate":float(a.rate)*(attack_rate/1.8),"speed":380.0,"radius":0.0,"blast":0.0,"count":1,"pierce":0,"chain":0,"slow":0.0,"fork":false,"echo":false,"burn":0.0,"leech":0.0,"execute":false,"duration":3.0,"poison":0.0,"knockback":0.0,"crit":0.0,"ricochet":0,"returning":false}
    for key in ["speed","radius","blast","count","pierce","chain","slow","duration","poison","knockback","ricochet","returning"]:
        if a.has(key): s[key] = a[key]
    s.damage *= 1 + (affix_total(w,"damage") + (affix_total(w,"spell") if "spell" in a.tags else 0.0) + (affix_total(w,"projectile") if "projectile" in a.tags else 0.0))/100.0
    s.rate *= 1 + affix_total(w,"rate")/100.0
    for support in row.get("supports", []):
        if not compatible(id, support): continue
        match support:
            "multi": s.count += 2; s.damage *= 0.75
            "pierce": s.pierce += 2; s.damage *= 0.9
            "chain": s.chain += 2; s.damage *= 0.9
            "fork": s.fork = true
            "echo": s.echo = true; s.damage *= 0.7
            "area": s.radius *= 1.45; s.blast *= 1.45; s.damage *= 0.9
            "swift": s.rate *= 1.35; s.damage *= 0.9
            "burn": s.burn = 0.15
            "leech": s.leech = 0.03
            "execute": s.execute = true
            "poison": s.poison = maxf(float(s.poison),0.18)
            "knockback": s.knockback += 22
            "duration": s.duration *= 1.6
            "velocity": s.speed *= 1.5; s.damage *= 1.1
            "concentrate": s.radius *= 0.75; s.blast *= 0.75; s.damage *= 1.45
            "critical": s.crit = 0.25
            "chill": s.slow = maxf(float(s.slow),0.4)
            "empower": s.damage *= 1.25
            "infinity": s.count += 10
            "dominion": s.damage *= 3
            "eternity": s.chain += 8; s.rate *= 1.5
            "heavy": s.damage *= 1.5; s.rate *= 0.8
            "wide": s.radius *= 1.7; s.blast *= 1.7; s.damage *= 0.7
            "lingering": s.duration *= 1.8; s.damage *= 0.8
            "siphon": s.leech = maxf(float(s.leech),0.06); s.damage *= 0.85
    s.crit = minf(1.0,float(s.crit)+affix_total(w,"crit")/100.0)
    if w.get("bonus", "") in a.tags: s.damage *= 1 + float(w.get("power",0))/100.0
    return s

func skill_info(key: String, row: Dictionary = {}) -> String:
    var d: Dictionary = definition(key)
    if d.is_empty(): return "空孔"
    if key.begins_with("support:"): return d.desc + "\n不直接造成傷害・不適用精煉\n需與相容技能連線才生效。"
    if d.has("aura"): return d.desc + "\n直接傷害：0・不適用精煉"
    var id: String = key.trim_prefix("active:")
    if row.is_empty():
        for candidate in skills():
            if candidate.active == id: row = candidate; break
    var s: Dictionary = compile(row if not row.is_empty() else {"active":id,"supports":[]})
    var lines: Array = [d.desc,"精煉 +%d・傷害加成 +%d%%" % [int(levels.get(id,0)),int(levels.get(id,0))*12],"單次命中 %.2f 傷害・%.2f 次／秒" % [s.damage,s.rate]]
    if "projectile" in d.tags: lines.append("投射物 %d・穿透 %d・連鎖 %d" % [int(s.count)*(4 if id=="barrage" else 1),s.pierce,s.chain])
    if s.chain > 0: lines.append("每次連鎖保留 85% 傷害，不重複命中同一敵人")
    if s.blast > 0: lines.append("爆炸波及 %.2f 傷害" % (s.damage*0.45))
    for status in ["poison","burn"]:
        if s[status] > 0: lines.append("%s %.2f／秒，持續 3 秒" % ["腐蝕" if status=="poison" else "燃燒",s.damage*s[status]])
    if s.crit > 0: lines.append("暴擊 %.0f%%・暴擊傷害 %.2f" % [s.crit*100,s.damage*2])
    if s.echo: lines.append("0.22 秒後再施放一次")
    if s.fork: lines.append("首次命中分裂 2 枚，每枚 %.2f 傷害" % (s.damage*0.6))
    if s.leech > 0: lines.append("偷取 %.0f%%・每秒最多回復 8 點" % (s.leech*100))
    if s.slow > 0: lines.append("緩速 %.0f%%，持續 2 秒" % (s.slow*100))
    if s.execute: lines.append("命中後生命低於 10% 直接擊殺")
    return "\n".join(lines)
