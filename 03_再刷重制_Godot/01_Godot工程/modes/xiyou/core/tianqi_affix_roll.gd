class_name XTianqiAffixRoll
extends RefCounted
## 【cc·天启篇·未经审查】天启篇普通装备获得时掷天启篇词条（天启篇词条重构设计稿 v0.3 第 3.2～3.6、7、11 节；表 tianqi_data/affix_table.json）。
## XGear.roll_item 末尾调 apply：天启篇存档里新生成的武器、防具（掉落、商店、事件、深渊商人都经 XGear.create／roll_item）。
## - 原版随机词缀行在天启篇里不掷（设计稿 11 节：affix_rate 不再调用），必出的行（几率合计 ≥100）照原版合进装备，属于装备固有效果。
##   跳过的行不取预掷随机数，所以天启篇存档的装备随机流和原版对不上，原版档不受影响。
## - 槽数按品质（普通 0、优秀／精良 1、史诗／传说 2、不朽／神话 3），阶按装备等级需求（<req_level>：1～29 一阶…70 以上四阶）。
## - 栏位组：武器、副手→兵器；头、甲、护手、腰带、裤、鞋→防具；项链、戒指→饰品。法宝（光环按养成分阶）、坐骑、神器栏不掷。
## - 项链先掷一次「是否光环」（二阶起 15%，占一个普通槽）。其余每槽按难度的层几率掷层，层不够格或到每件上限就按表里的退路往下找；
##   在「这一层 ∩ 本组标签 ∩ 这件还没有 ∩ 这一阶能出」里按权重抽（稀有词条权重低）；成色先掷极 3%，再按品质掷上品，其余普通。
## - 记在装备实例的 tianqi_affixes = [{key, tier, grade, extra}]（XTianqiAffixBattle 认这个键算效果），说明末尾加上每条一行（XTianqiAffixText）。
## 已经带天启篇词条或七印标记、净印／遗物的装备不掷。只认天启篇存档（XTianqiAffixBattle.on）。
##
## 开关（O-347）：false＝天启篇存档的装备照原版掷词缀，不掷天启篇词条

## 开关：false＝回到原版词缀
static var ENABLED := true

const T := preload("res://modes/xiyou/core/tianqi_affix_table.gd")
const QUALITY_KEYS := ["putong", "youxiu", "jingliang", "shishi", "chuanshuo", "buxiu", "shenhua"]
## 装备类型号 → 栏位键（表里 slots 的键）；没有的不掷
const SLOT_OF_ETYPE := {1: "weapon", 2: "offhand", 3: "head", 4: "body", 6: "hands", 8: "waist", 5: "legs", 7: "feet", 9: "necklace", 10: "ring"}


static func on(s: XState = null) -> bool:
	if s == null:
		s = XState.current
	return ENABLED and s != null and XTianqiAffixBattle.on(s)


## 原版的这一行词缀在天启篇里跳过（几率合计不到 100 的随机行）
static func skips_row(row: Dictionary, s: XState) -> bool:
	if not on(s):
		return false
	var total := 0
	for c in row.get("choices", []):
		total += int(c.get("chance", 0))
	return total < 100


static func slot_key(item: Dictionary) -> String:
	var et := 1 if str(item.get("kind", "")) == "weapon" else int(item.get("etypeId", 0))
	return str(SLOT_OF_ETYPE.get(et, ""))


static func quality_key(item: Dictionary) -> String:
	return str(QUALITY_KEYS[clampi(XQuality.grade(item), 0, QUALITY_KEYS.size() - 1)])


static func tier_of(item: Dictionary) -> int:
	return T.tier_of_level(maxi(1, int(str(item.get("meta", {}).get("req_level", "1")))))


## XGear.roll_item 末尾：天启篇存档的新装备掷天启篇词条（rng 返回 [0,1)，缺省 XGear.roll）
static func apply(item: Dictionary, s: XState, rng := Callable()) -> void:
	if item.is_empty() or not on(s) or item.has("tianqi_affixes") or item.has("qiyin") or item.has("tq_reward"):
		return
	var slot := slot_key(item)
	if slot == "":
		return
	if not rng.is_valid():
		rng = func(): return XGear.roll(s)
	var list := roll(item, slot, _difficulty(s), rng)
	if list.is_empty():
		return
	set_affixes(item, list)


## 换一件的天启篇词条并重写说明（原说明记在 tianqi_desc_base，词条行每次重拼）
static func set_affixes(item: Dictionary, list: Array) -> void:
	if not item.has("tianqi_desc_base"):
		item["tianqi_desc_base"] = str(item.get("description", ""))
	item["tianqi_affixes"] = list
	var lines := PackedStringArray()
	for a in list:
		var t := XTianqiAffixText.line(str(a.key), int(a.tier), str(a.grade), a.get("extra", {}))
		if t != "":
			lines.append(t)
	var d := str(item.tianqi_desc_base)
	item.description = d if lines.is_empty() else (d + "\n" if d != "" else "") + "\n".join(lines)


## 这件能出的某层词条（本组标签、这一阶能出、品质够格）
static func layer_candidates(item: Dictionary, layer: String) -> Array:
	var slot := slot_key(item)
	if slot == "" or not T.quality_layers(quality_key(item)).has(layer):
		return []
	var tier := tier_of(item)
	return T.candidates(layer, T.slot_group(slot)).filter(func(a): return T.available(a, tier))


## 保证这件带一条 key（已带就不动）：同层已有的（传说每件 1 条）换掉，否则有空槽就加，没有就换掉最后一条基础词条
static func ensure_affix(item: Dictionary, key: String, rng: Callable) -> bool:
	if not layer_candidates(item, str(T.affix(key).get("layer", ""))).has(key):
		return false
	var list: Array = (item.get("tianqi_affixes", []) as Array).duplicate(true)
	if list.any(func(a): return str(a.key) == key):
		return true
	var layer := str(T.affix(key).get("layer", ""))
	var e := _entry(key, tier_of(item), quality_key(item), rng)
	var same := -1
	var cap = T.layer(layer).get("per_item_max")
	if cap != null and list.filter(func(a): return str(T.affix(str(a.key)).get("layer", "")) == layer).size() >= int(cap):
		for i in list.size():
			if str(T.affix(str(list[i].key)).get("layer", "")) == layer:
				same = i
	if same >= 0:
		list[same] = e
	elif list.size() < T.slot_count(quality_key(item)):
		list.append(e)
	else:
		var base := -1
		for i in list.size():
			if str(T.affix(str(list[i].key)).get("layer", "")) == "base":
				base = i
		list[base if base >= 0 else list.size() - 1] = e
	set_affixes(item, list)
	return true


static func _difficulty(s: XState) -> String:
	var t = s.flags.get("tianqi", {})
	return str(t.get("difficulty", "jianxian")) if t is Dictionary else "jianxian"


## 掷一件的词条（纯逻辑）：[{key, tier, grade, extra}]
static func roll(item: Dictionary, slot: String, difficulty: String, rng: Callable) -> Array:
	var group := T.slot_group(slot)
	var q := quality_key(item)
	var n := T.slot_count(q)
	var tier := tier_of(item)
	var allowed: Array = T.quality_layers(q)
	if group == "" or n <= 0 or group == "fabao" or group == "zuoqi":
		return []
	var odds := T.layer_odds(difficulty)
	if odds.is_empty():
		odds = T.layer_odds("jianxian")
	var picked := []
	var count := {}
	var out := []
	var na: Dictionary = T.data().get("necklace_aura", {})
	if T.slot_has_aura(slot) and slot == "necklace" and tier >= int(na.get("min_tier", 2)) and float(rng.call()) < float(na.get("chance", 0.0)):
		var key := _pick(T.candidates("aura", group).filter(func(a): return T.available(a, tier)), rng)
		if key != "":
			picked.append(key)
			out.append(_entry(key, tier, q, rng))
			n -= 1
	for _i in n:
		var r := float(rng.call())
		var layer := "base"
		var acc := 0.0
		for k in ["base", "special", "legendary"]:
			acc += float(odds.get(k, 0.0))
			if r < acc:
				layer = k
				break
		var tries: Array = [layer]
		for k in T.data().get("layer_fallback", []):
			if not tries.has(k):
				tries.append(k)
		var key := ""
		for k in tries:
			if not allowed.has(k):
				continue
			var cap = T.layer(k).get("per_item_max")
			if cap != null and int(count.get(k, 0)) >= int(cap):
				continue
			key = _pick(T.candidates(k, group).filter(func(a): return not picked.has(a) and T.available(a, tier)), rng)
			if key != "":
				count[k] = int(count.get(k, 0)) + 1
				break
		if key == "":
			continue
		picked.append(key)
		out.append(_entry(key, tier, q, rng))
	return out


static func _pick(cands: Array, rng: Callable) -> String:
	if cands.is_empty():
		return ""
	var total := 0.0
	for a in cands:
		total += float(T.affix(a).get("weight", 1))
	var x := float(rng.call()) * total
	for a in cands:
		x -= float(T.affix(a).get("weight", 1))
		if x < 0:
			return str(a)
	return str(cands[-1])


## 一条：成色先掷极，再按品质掷上品；随机系掷系，有变体掷变体
static func _entry(key: String, tier: int, q: String, rng: Callable) -> Dictionary:
	var grade := "normal"
	if float(rng.call()) < T.perfect_chance():
		grade = "perfect"
	elif float(rng.call()) < T.fine_chance(q):
		grade = "fine"
	var extra := {}
	var a := T.affix(key)
	if bool(a.get("random_element", false)):
		var els: Array = T.data().get("elements", []).filter(func(e): return str(e.key) != "physical")
		if not els.is_empty():
			extra.element = str(els[mini(floori(float(rng.call()) * els.size()), els.size() - 1)].key)
	var variants: Array = a.get("variants", [])
	if not variants.is_empty():
		extra.variant = str(variants[mini(floori(float(rng.call()) * variants.size()), variants.size() - 1)].key)
	return {"key": key, "tier": tier, "grade": grade, "extra": extra}
