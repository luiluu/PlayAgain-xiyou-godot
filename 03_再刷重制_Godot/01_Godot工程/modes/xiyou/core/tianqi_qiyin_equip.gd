class_name XTianqiQiyinEquip
extends RefCounted
## 【cc·天启篇·未经审查】七印祭坛：揭开的件变成能穿的装备、熔、分解、印屑兑换、献武器（七印祭坛方案 v0.4 第 4.1、5.1、6.1、6.3、6.4 节）。
## 底子表 tianqi_data/qiyin_equip.json（只读，draft）；装备数据 XTianqiQiyinGear；掉落与熔／分解／兑换的判定 XTianqiQiyinDrop；
## 战斗效果认 XTianqiQiyinEffects.mark() 打的 qiyin 标记。
##
## 装备实例：照 XTianqiRewards 的做法，借 base_id 那件的图标和栏位，属性、特性、原版词缀、备注清空，名字、说明、底子换成七印的；
## 不改原版数据库，存档照装备实例存。实例上的 qiyin 标记除了 mark() 写的 {kind, seal, part|key, true_seal, unique}，
## 本模块再记 wtype（武器中文类名）、grades（三条成色，掉落时掷定）、affixes（[{key, grade, extra}…]，揭开时掷，四阶）、level。
## 词条用天启篇词条表（XTianqiAffixTable，三槽、神话、防具组／兵器组），只算出来写进说明；天启篇词条的战斗效果还没有模块接（交付单）。
##
## 套装件不分甲种（方案 4.1 节「谁都能穿」）：XActor.can_equip 里一行 any_class。神器进神器栏：XTianqiGear.allows 认 qiyin 标记。
##
## 开关（O-待定）：ENABLED＝false 时揭开只亮成色、不生成装备（回到 cc/qiyin-altar 的样子），祭坛不出熔、分解、兑换，献只剩印屑。

static var ENABLED := true

const PATH := "res://modes/xiyou/tianqi_data/qiyin_equip.json"
const T := preload("res://modes/xiyou/core/tianqi_affix_table.gd")
const GRADE_KEYS := {"putong": "normal", "shangpin": "fine", "ji": "perfect"}

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {}
	return _data


static func reload() -> void:
	_data = {}


static func nice_number_violations() -> Array:
	var out := []
	XTianqiQiyinDrop._scan_nice(data(), "", data().get("nice_number_exempt", []), out)
	return out


static func on(s: XState = null) -> bool:
	return ENABLED and XTianqiQiyin.allowed(s)


# ---- 认装备 ----

## 这件是不是七印装备（套装件、毕业武器、神器）
static func is_qiyin(item) -> bool:
	return item is Dictionary and str(XTianqiQiyinEffects.mark_of(item).get("kind", "")) in ["set", "weapon", "artifact"]


## 套装件不分甲种：XActor.can_equip 判甲种前问这里
static func any_class(item) -> bool:
	return ENABLED and str(XTianqiQiyinEffects.mark_of(item).get("kind", "")) == "set" and bool(data().get("armor", {}).get("any_class", false))


## 熔／分解／兑换／献用的掉落描述（XTianqiQiyinDrop 认的格式）：{kind, seal, part|wtype, true_seal, grades, id}
static func desc_of(item: Dictionary) -> Dictionary:
	var m := XTianqiQiyinEffects.mark_of(item)
	var d := {"kind": str(m.get("kind", "")), "seal": str(m.get("seal", "")), "true_seal": bool(m.get("true_seal", false)),
		"grades": m.get("grades", []).duplicate(), "id": str(item.get("instanceId", ""))}
	if d.kind == "set":
		d.part = str(m.get("part", ""))
	elif d.kind == "weapon":
		d.wtype = str(m.get("wtype", ""))
	return d


## 武器中文类名 → 类表那一行 {key, name, wtype_id}
static func weapon_type(wtype: String) -> Dictionary:
	for t in XTianqiQiyinGear.weapon_types():
		if str(t.get("name", "")) == wtype or str(t.get("key", "")) == wtype:
			return t
	return {}


# ---- 生成 ----

## 空白底子：借 base_id 的图标和栏位，其余清空
static func _blank(kind: String, base_id: int) -> Dictionary:
	var item := XGear.template(kind, base_id)
	if item.is_empty():
		return {}
	item.params = [0, 0, 0, 0, 0, 0, 0, 0]
	item.traits = []
	item.note = ""
	item.meta = {"quality": str(int(data().get("quality_legacy", 14)))}
	item.price = 0
	item.affixIds = []
	item.upgradeSlots = 0
	item.originalUpgradeSlots = 0
	var eq: Dictionary = item.get("equipment", {}).duplicate(true)
	eq["affixes"] = []
	eq["slots"] = 0
	eq["requirements"] = {}
	item["equipment"] = eq
	return item


static func _scaled(params: Array, mult: float) -> Array:
	return params.map(func(v): return roundi(float(v) * mult))


## 掷三条词条（天启篇词条表：每槽按难度的层几率抽层，特效最多 2、传说最多 1，抽不到退到下一层；同名不重复；成色用掉落时掷定的）。
## 抽取顺序：每槽 层 → 词条 →（随机系）系 →（有变体）变体
static func roll_affixes(group: String, grades: Array, difficulty: String, rng: XRandomStream) -> Array:
	var tier := 4
	var odds := T.layer_odds(difficulty)
	if odds.is_empty():
		odds = T.layer_odds("jianxian")
	var count := {}
	var picked := []
	var out := []
	for i in grades.size():
		var r := rng.next_float("qiyin_affix_layer")
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
			var cap = T.layer(k).get("per_item_max")
			if cap != null and int(count.get(k, 0)) >= int(cap):
				continue
			var cands: Array = T.candidates(k, group).filter(func(a): return not picked.has(a) and T.available(a, tier))
			if cands.is_empty():
				continue
			var total := 0.0
			for a in cands:
				total += float(T.affix(a).get("weight", 1))
			var x := rng.next_float("qiyin_affix_pick") * total
			key = str(cands[-1])
			for a in cands:
				x -= float(T.affix(a).get("weight", 1))
				if x < 0:
					key = str(a)
					break
			count[k] = int(count.get(k, 0)) + 1
			break
		if key == "":
			continue
		picked.append(key)
		var extra := {}
		var a := T.affix(key)
		if bool(a.get("random_element", false)):
			var els: Array = T.data().get("elements", []).filter(func(e): return str(e.key) != "physical")
			if not els.is_empty():
				extra.element = str(els[rng.next_index_mod(els.size(), "qiyin_affix_element")].key)
		var variants: Array = a.get("variants", [])
		if not variants.is_empty():
			extra.variant = str(variants[rng.next_index_mod(variants.size(), "qiyin_affix_variant")].key)
		out.append({"key": key, "grade": str(GRADE_KEYS.get(str(grades[i]), "normal")), "extra": extra})
	return out


## 掉落描述 → 能穿的装备实例（没进背包）。desc：XTianqiQiyinDrop 的物品字典 {kind, seal, part|wtype, true_seal, grades}，
## 可带 level（守层者首杀那件 75）、affixes（熔、测试直接给）；神器 {kind: "artifact", key}。不认识返回空。
static func make(desc: Dictionary, difficulty: String, rng: XRandomStream) -> Dictionary:
	match str(desc.get("kind", "")):
		"set":
			return _make_set(desc, difficulty, rng)
		"weapon":
			return _make_weapon(desc, difficulty, rng)
		"artifact":
			return make_artifact(str(desc.get("key", "")))
	return {}


static func _make_set(desc: Dictionary, difficulty: String, rng: XRandomStream) -> Dictionary:
	var seal := str(desc.get("seal", ""))
	var part := str(desc.get("part", ""))
	var row: Dictionary = data().get("armor", {}).get("parts", {}).get(part, {})
	var piece := {}
	for pc in XTianqiQiyinGear.set_of(seal).get("pieces", []):
		if str(pc.get("part", "")) == part:
			piece = pc
	if row.is_empty() or piece.is_empty():
		return {}
	var item := _blank("armor", int(row.base_id))
	if item.is_empty():
		return {}
	var rule := XTianqiQiyinGear.set_rule()
	var true_seal := bool(desc.get("true_seal", false))
	var mult := float(rule.get("true_seal", {}).get("base_mult", 1.0)) if true_seal else 1.0
	item.etypeId = int(piece.etype)
	item.atypeId = int(data().armor.get("atype", 1))
	item.params = _scaled(row.params, mult)
	var level := int(desc.get("level", rule.get("level", 80)))
	item.meta.req_level = str(level)
	item.name = ("%s%s" % [str(data().names.true_seal), str(piece.name)]) if true_seal else str(piece.name)
	item.baseName = str(item.name)
	var m := XTianqiQiyinEffects.mark(item, desc, rng)
	_finish(item, m, desc, "fangju", difficulty, level, rng)
	return item


static func _make_weapon(desc: Dictionary, difficulty: String, rng: XRandomStream) -> Dictionary:
	var seal := str(desc.get("seal", ""))
	var t := weapon_type(str(desc.get("wtype", "")))
	var row: Dictionary = data().get("weapons", {}).get(str(t.get("key", "")), {})
	if t.is_empty() or row.is_empty() or t.get("wtype_id") == null:
		return {}
	var item := _blank("weapon", int(row.base_id))
	if item.is_empty():
		return {}
	var rule := XTianqiQiyinGear.weapon_rule()
	item.etypeId = 1
	item.wtypeId = int(t.wtype_id)
	item.params = _scaled(row.params, float(rule.get("base_mult", 1.0)))
	var level := int(desc.get("level", rule.get("level", 80)))
	item.meta.req_level = str(level)
	var d := desc.duplicate(true)
	d.wtype = str(t.name)
	var m := XTianqiQiyinEffects.mark(item, d, rng)
	var w := XTianqiQiyinGear.weapon(str(m.get("key", "")))
	var true_seal := bool(desc.get("true_seal", false))
	item.name = ("%s%s" % [str(data().names.true_seal), str(w.get("name", ""))]) if true_seal else str(w.get("name", ""))
	item.baseName = str(item.name)
	_finish(item, m, d, "bingqi", difficulty, level, rng)
	return item


## 神器（方案 6.4 节）：神器栏、不挑角色，没有词条
static func make_artifact(key: String) -> Dictionary:
	var a := XTianqiQiyinGear.artifact(key)
	if a.is_empty():
		return {}
	var item := _blank("armor", int(data().get("artifact", {}).get("base_id", 0)))
	if item.is_empty():
		return {}
	item.etypeId = int(XTianqiQiyinGear.artifact_rule().get("etype", XTianqiGear.ARTIFACT))
	item.name = str(a.get("name", key))
	item.baseName = str(item.name)
	XTianqiQiyinEffects.mark(item, {"kind": "artifact", "key": key})
	var lines := [str(data().names.kind_artifact)]
	for fx in a.get("effects", []):
		lines.append(str(fx.get("text", "")))
	for fx in a.get("costs", []):
		lines.append(str(data().names.cost) % str(fx.get("text", "")))
	item.description = "\n".join(PackedStringArray(lines))
	return item


## 写 qiyin 标记里本模块的字段、掷词条、写说明
static func _finish(item: Dictionary, m: Dictionary, desc: Dictionary, group: String, difficulty: String, level: int, rng: XRandomStream) -> void:
	var grades: Array = desc.get("grades", []).duplicate()
	if grades.is_empty():
		grades = ["putong", "putong", "putong"]
	m.grades = grades
	m.level = level
	if str(m.kind) == "weapon":
		m.wtype = str(desc.get("wtype", ""))
	var given = desc.get("affixes", null)
	m.affixes = given.duplicate(true) if given is Array else roll_affixes(group, grades, difficulty, rng)
	describe(item)


## 说明：类别、套装 2／3／5 件或流派印记＋独有效果、真印追加、三条词条
static func describe(item: Dictionary) -> void:
	var m := XTianqiQiyinEffects.mark_of(item)
	var n: Dictionary = data().names
	var lines := []
	var seal := str(m.get("seal", ""))
	if str(m.get("kind", "")) == "set":
		var st := XTianqiQiyinGear.set_of(seal)
		lines.append("%s「%s」" % [str(n.kind_set), str(st.get("name", ""))])
		for b in st.get("bonuses", []):
			var texts: Array = b.get("effects", []).map(func(fx): return str(fx.get("text", "")))
			lines.append(str(n.set_bonus) % [int(b.count), "；".join(PackedStringArray(texts))])
	else:
		var sc := XTianqiQiyinGear.school(seal)
		lines.append("%s「%s」" % [str(n.kind_weapon), str(sc.get("name", ""))])
		for fx in sc.get("mark", []):
			lines.append(str(n.school_mark) % str(fx.get("text", "")))
		if bool(m.get("true_seal", false)):
			for fx in sc.get("true_extra", []):
				lines.append(str(n.true_extra) % str(fx.get("text", "")))
		for fx in XTianqiQiyinGear.weapon(str(m.get("key", ""))).get("effects", []):
			if str(fx.get("code", "")) != "random_unique":
				lines.append(str(n.unique) % str(fx.get("text", "")))
		if str(m.get("unique", "")) != "":
			for fx in XTianqiQiyinGear.weapon(str(m.unique)).get("effects", []):
				lines.append(str(n.engraved) % str(fx.get("text", "")))
	for a in m.get("affixes", []):
		lines.append(affix_line(a))
	item.description = "\n".join(PackedStringArray(lines))


static func affix_line(a: Dictionary) -> String:
	return XTianqiAffixText.line(str(a.get("key", "")), 4, str(a.get("grade", "normal")), a.get("extra", {}))


# ---- 背包 ----

## 放进背包
static func give(s: XState, item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	s.register_gear(item)
	s.gear.append(item)
	return item


## 背包里的七印装备（kind：set／weapon／artifact／"" 全部）
static func in_bag(s: XState, kind := "") -> Array:
	return s.gear.filter(func(e): return is_qiyin(e) and (kind == "" or str(XTianqiQiyinEffects.mark_of(e).kind) == kind))


## 身上穿着的七印装备
static func worn(s: XState) -> Array:
	var out := []
	for a in s.actors.values():
		for e in a.equip_list():
			if is_qiyin(e):
				out.append(e)
	return out


## 背包和身上已有的套装部位 {印: [部位…]}（掉落「已有部位减半」用）
static func owned_parts(s: XState) -> Dictionary:
	var out := {}
	for e in in_bag(s, "set") + worn(s).filter(func(x): return str(XTianqiQiyinEffects.mark_of(x).kind) == "set"):
		var m := XTianqiQiyinEffects.mark_of(e)
		var k := str(m.seal)
		if not out.has(k):
			out[k] = []
		if not out[k].has(str(m.part)):
			out[k].append(str(m.part))
	return out


# ---- 熔、分解、兑换（方案 6.3 节；判定在 XTianqiQiyinDrop） ----

## 主件能和背包里哪些副件熔（同印同部位、武器同类、真印配真印）
static func melt_partners(s: XState, main: Dictionary) -> Array:
	var md := desc_of(main)
	return in_bag(s).filter(func(e): return not is_same(e, main) and bool(XTianqiQiyinDrop.melt_check(md, desc_of(e), 1 << 30).ok))


## 副件里能换过去的词条下标：主件已有的同名词条换过去也只生效一条，不给选（O-待定 同一个开关）
static func melt_choices(main: Dictionary, sub: Dictionary, slot: int) -> Array:
	var mine: Array = XTianqiQiyinEffects.mark_of(main).get("affixes", [])
	var theirs: Array = XTianqiQiyinEffects.mark_of(sub).get("affixes", [])
	var out := []
	for i in theirs.size():
		var k := str(theirs[i].get("key", ""))
		var dup := false
		for j in mine.size():
			if j != slot and str(mine[j].get("key", "")) == k:
				dup = true
		if not dup:
			out.append(i)
	return out


## 熔：副件第 sub_idx 条词条换到主件第 slot 条，副件消失，花印屑。返回 {ok, reason, cost}
static func melt(s: XState, main: Dictionary, sub: Dictionary, slot: int, sub_idx: int) -> Dictionary:
	var chk := XTianqiQiyinDrop.melt_check(desc_of(main), desc_of(sub), XTianqiQiyin.shards(s))
	if not chk.ok:
		return chk
	if not s.gear.any(func(e): return is_same(e, sub)):
		return {"ok": false, "reason": "sub_not_in_bag", "cost": chk.cost}
	if not s.owns_gear(main):
		return {"ok": false, "reason": "main_not_owned", "cost": chk.cost}
	var mine: Array = XTianqiQiyinEffects.mark_of(main).get("affixes", [])
	var theirs: Array = XTianqiQiyinEffects.mark_of(sub).get("affixes", [])
	if slot < 0 or slot >= mine.size() or not melt_choices(main, sub, slot).has(sub_idx):
		return {"ok": false, "reason": "bad_affix", "cost": chk.cost}
	mine[slot] = theirs[sub_idx].duplicate(true)
	XTianqiQiyinEffects.mark_of(main).affixes = mine
	describe(main)
	s.lose_gear(sub)
	XTianqiQiyin.progress(s).shards = XTianqiQiyin.shards(s) - int(chk.cost)
	return {"ok": true, "reason": "", "cost": chk.cost}


## 分解（只分背包里的）：给印屑。返回给了几个
static func dismantle(s: XState, item: Dictionary) -> int:
	if not s.gear.any(func(e): return is_same(e, item)):
		return 0
	var v := XTianqiQiyinDrop.dismantle_value(desc_of(item))
	if v <= 0:
		return 0
	s.lose_gear(item)
	XTianqiQiyin.progress(s).shards = XTianqiQiyin.shards(s) + v
	return v


## 兑换：花印屑换一件封着的（进印库）。返回 XTianqiQiyinDrop.exchange 的结果
static func exchange(s: XState, kind: String, seal: String, rng: XRandomStream) -> Dictionary:
	var r := XTianqiQiyinDrop.exchange(kind, seal, XTianqiQiyin.shards(s), XTianqiQiyin._owned_by_seal(s), rng)
	if not r.ok:
		return r
	XTianqiQiyin.progress(s).shards = XTianqiQiyin.shards(s) - int(r.cost)
	XTianqiQiyin._stash(s, r.item)
	return r


# ---- 献武器（方案 6.3 节） ----

## 背包里能献的本印毕业武器
static func offer_weapons(s: XState, seal: String) -> Array:
	return in_bag(s, "weapon").filter(func(e): return str(XTianqiQiyinEffects.mark_of(e).seal) == seal)


## 献武器的 offering（XTianqiQiyinDrop 认 {kind, wtype}；gear 记是哪一把，进副本时拿掉）
static func weapon_offering(item: Dictionary) -> Dictionary:
	return {"kind": XTianqiQiyinDrop.OFFER_WEAPON, "wtype": str(XTianqiQiyinEffects.mark_of(item).get("wtype", "")), "gear": str(item.get("instanceId", ""))}


## 进副本时拿掉献的那把。返回拿到没有
static func take_offering(s: XState, offering: Dictionary) -> bool:
	var id := str(offering.get("gear", ""))
	for e in s.gear:
		if str(e.get("instanceId", "")) == id and is_qiyin(e):
			return s.lose_gear(e)
	return false


# ---- 祭坛菜单「熔炼、分解、兑换」 ----

static func _ask(host, head: String, options: Array) -> int:
	return await host.show_text_with_choices("", 0, [head], options, options.size() - 1)


static func _say(host, text: String) -> void:
	await host.show_text("", 0, [text])


static func run_forge(host, s: XState) -> void:
	var n: Dictionary = data().names
	var melt_cost := int(XTianqiQiyinDrop.data().get("melt", {}).get("cost", 3))
	var ex: Dictionary = XTianqiQiyinDrop.data().get("exchange", {})
	while true:
		var opts := [str(n.forge_melt) % melt_cost, str(n.forge_dismantle), str(n.forge_exchange) % [int(ex.get("set", 0)), int(ex.get("weapon", 0))], "返回"]
		var i: int = await _ask(host, str(n.forge_head) % XTianqiQiyin.shards(s), opts)
		match i:
			0:
				await _run_melt(host, s)
			1:
				await _run_dismantle(host, s)
			2:
				await _run_exchange(host, s)
			_:
				return


## 能当主件的（背包和身上，有副件可熔的）
static func melt_mains(s: XState) -> Array:
	return (in_bag(s) + worn(s)).filter(func(e): return str(XTianqiQiyinEffects.mark_of(e).kind) != "artifact" and not melt_partners(s, e).is_empty())


static func _run_melt(host, s: XState) -> void:
	var n: Dictionary = data().names
	var mains := melt_mains(s)
	if mains.is_empty():
		await _say(host, str(n.melt_none))
		return
	var labels: Array = mains.map(func(e): return str(e.name))
	labels.append("返回")
	var a: int = await _ask(host, str(n.melt_main), labels)
	if a < 0 or a >= mains.size():
		return
	var main: Dictionary = mains[a]
	var subs := melt_partners(s, main)
	labels = subs.map(func(e): return "%s（%s）" % [str(e.name), "／".join(PackedStringArray(XTianqiQiyinEffects.mark_of(e).get("affixes", []).map(func(x): return affix_line(x))))])
	labels.append("返回")
	var b: int = await _ask(host, str(n.melt_sub), labels)
	if b < 0 or b >= subs.size():
		return
	var sub: Dictionary = subs[b]
	var mine: Array = XTianqiQiyinEffects.mark_of(main).get("affixes", [])
	labels = mine.map(func(x): return affix_line(x))
	labels.append("返回")
	var slot: int = await _ask(host, str(n.melt_slot), labels)
	if slot < 0 or slot >= mine.size():
		return
	var choices := melt_choices(main, sub, slot)
	if choices.is_empty():
		await _say(host, str(n.melt_dup))
		return
	var theirs: Array = XTianqiQiyinEffects.mark_of(sub).get("affixes", [])
	labels = choices.map(func(k): return affix_line(theirs[k]))
	labels.append("返回")
	var c: int = await _ask(host, str(n.melt_pick), labels)
	if c < 0 or c >= choices.size():
		return
	var r := melt(s, main, sub, slot, int(choices[c]))
	if not r.ok:
		await _say(host, str(n.get("fail_" + str(r.reason), n.fail_other)))
		return
	await _say(host, str(n.melt_done) % [str(main.name), affix_line(mine[slot])])


static func _run_dismantle(host, s: XState) -> void:
	var n: Dictionary = data().names
	var list := in_bag(s).filter(func(e): return str(XTianqiQiyinEffects.mark_of(e).kind) != "artifact")
	if list.is_empty():
		await _say(host, str(n.dismantle_none))
		return
	var labels: Array = list.map(func(e): return str(n.dismantle_item) % [str(e.name), XTianqiQiyinDrop.dismantle_value(desc_of(e))])
	labels.append("返回")
	var i: int = await _ask(host, str(n.dismantle_head), labels)
	if i < 0 or i >= list.size():
		return
	var ok: int = await _ask(host, str(n.dismantle_confirm) % str(list[i].name), ["分解", "算了"])
	if ok != 0:
		return
	var v := dismantle(s, list[i])
	await _say(host, str(n.dismantle_done) % v)


static func _run_exchange(host, s: XState) -> void:
	var n: Dictionary = data().names
	var ex: Dictionary = XTianqiQiyinDrop.data().get("exchange", {})
	var k: int = await _ask(host, str(n.exchange_head) % XTianqiQiyin.shards(s), [str(n.exchange_set) % int(ex.get("set", 0)), str(n.exchange_weapon) % int(ex.get("weapon", 0)), "返回"])
	if k < 0 or k > 1:
		return
	var kind := XTianqiQiyinDrop.KIND_SET if k == 0 else XTianqiQiyinDrop.KIND_WEAPON
	var seals := XTianqiQiyin.unlocked_seals(s)
	var labels: Array = seals.map(func(x): return "%s %s" % [str(XTianqiQiyin.seal_info(x).seal), str(XTianqiQiyin.seal_info(x).name)])
	labels.append("返回")
	var j: int = await _ask(host, str(n.exchange_seal), labels)
	if j < 0 or j >= seals.size():
		return
	var r := exchange(s, kind, str(seals[j]), XTianqiQiyin._rng())
	if not r.ok:
		await _say(host, str(n.get("fail_" + str(r.reason), n.fail_other)))
		return
	await _say(host, str(n.exchange_done) % XTianqiQiyin.sealed_label(r.item))
