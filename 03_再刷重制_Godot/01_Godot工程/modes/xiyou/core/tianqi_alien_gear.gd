class_name XTianqiAlienGear
extends RefCounted
## 【cc·天启篇·未经审查】天启篇异化装备（四线异化与异化装备重构 v0.8 第 4 节；四线剧情与关卡设计稿 v0.4 第 3.4、6 节）。
## 数据 tianqi_data/alien_gear.json（测试参数，draft）；每线 4 条词条和新名字读 rewards.json 的 finale（和终焉异化核同一份）。
##
## - 掉落：天启篇的异化怪（各线异化模块本场记下的 units：开场、使徒、按段异化）倒下、我方赢了，按级掷一次：
##   侵染 3%、蚀骨 8%、化形 20%、终焉必掉 1 件（BattleLogic.grant 里、原版异化发奖之后）。
##   本体从那只怪自己掉落表里的武器、防具里挑（排除专属武器、法宝、灵兽、坐骑、神器栏，七印装备、净印和遗物也不算）；
##   掉落表里一件能用的都没有时：终焉照样给，改成一颗同级异化核；其余级不给。
## - 装备：普通独立装备实例多一个原版的 alien 标记（XAlienation：uid、affix、pool、config…），另加 tq = {line, level}；
##   原有 12 条词条（血铠＝空壳等）的战斗效果直接走原版异化的那一套（XAlienBattle），名字「级·新词条名·原名」。
##   本线新词条（临终、再动、节俭、带毒）只记在装备上，战斗效果还没接（详情里写「未生效」）；四级数值分档也还没做（数值阶段定）。
## - 词条：每件 1 条，从掉落那条线的 4 条里出；共生、夺舍、寄生要化形及以上才出。
## - 工坊（原版异化工坊页，天启篇存档多出几个按钮；规则都在这里，XAlienation 遇到带 tq 的装备转过来）：
##   分解按级给能量（1／2／5／8）；重抽只在本线本级内抽、新旧二选一（沿用原版待选）；
##   取核：装备没了，得一颗异化核（记线、词条、级），和终焉异化核放在一起（flags.tianqi.rewards.cores）；
##   刻印：花 1 颗异化石，把一颗核刻到背包里任何一件能异化的武器、防具上，已有词条的替换；
##   净化：花 1 颗异化石，去掉词条还原成普通装备，退还一部分分解能量。
##
## 开关（O-336）：ENABLED＝false 时天启篇的怪不掉异化装备，工坊里没有取核、刻印、净化；已有的天启篇异化装备照原版异化的规则还在。
## 只认天启篇存档（XTianqiLine.open_for：发行构建里还要 XTianqi.RELEASE_OPEN），原版异化整套隐藏时（XAlienBattle.hidden）也不出。

const PATH := "res://modes/xiyou/tianqi_data/alien_gear.json"
## 能异化的装备类型（武器、副手、头、甲、裤、护手、鞋、腰带、项链、戒指）；法宝 13、灵兽、坐骑、神器栏不算
const BODY_ETYPES := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
## 各线异化模块本场的标记（键）和线
const MODULES := [["xwar_alien", "war"], ["xfamine_alien", "famine"], ["xplague_alien", "plague"], ["xdeath_alien", "death"]]

## 开关：false＝天启篇的怪不掉异化装备，工坊没有取核、刻印、净化
static var ENABLED := true
## 测试用：≥0 时选词条、选本体固定取它
static var force_roll := -1.0

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiAlienGear: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("XTianqiAlienGear: JSON 解析失败 " + PATH)
	return _data


static func reload() -> void:
	_data = {}


static func nice_number_violations() -> Array:
	var out := []
	XTianqiHorsemen._scan(data(), "", [], out)
	return out


# ---- 开关、标记、名字 ----

static func on(s: XState = null) -> bool:
	if s == null:
		s = XState.current
	return ENABLED and s != null and XTianqiLine.open_for(s) and not XAlienBattle.hidden()


## 天启篇异化装备的标记 {line, level}；不是就空
static func tq(i) -> Dictionary:
	var t = XAlienation.mark(i).get("tq", {})
	return t if t is Dictionary else {}


static func is_tq(i) -> bool:
	return not tq(i).is_empty()


static func level_info(level: String) -> Dictionary:
	return data().get("levels", {}).get(level, {})


static func level_name(level: String) -> String:
	return str(level_info(level).get("name", level))


static func level_index(level: String) -> int:
	return (data().get("level_order", []) as Array).find(level)


## 本线 4 条（rewards.json finale.lines）
static func line_keys(line: String) -> Array:
	return XTianqiRewards.data().get("finale", {}).get("lines", {}).get(line, [])


## 词条在天启篇的名字（血铠、救赎…）；没登记的回原名
static func affix_name(key: String) -> String:
	var n = XTianqiRewards.data().get("finale", {}).get("names", {}).get(key)
	if n != null:
		return str(n)
	return str(XAlienation.affix(key).get("name", key))


## 新词条（★，原版没有）
static func is_new_affix(key: String) -> bool:
	return data().get("new_affixes", {}).has(key) and key != "_note"


## 工坊卡片用的词条说明 {key, name, benefit, cost}：天启篇存档里换新名字、新词条读本表；原版档照原版
static func affix_view(s: XState, key: String) -> Dictionary:
	var f := XAlienation.affix(key).duplicate()
	if is_new_affix(key):
		var n: Dictionary = data().new_affixes[key]
		f = {"key": key, "name": key, "benefit": str(n.get("benefit", "")), "cost": str(n.get("cost", ""))}
	if s != null and XTianqiLine.open_for(s) and not f.is_empty():
		f.name = affix_name(key)
	return f


## 这一级能出的词条（共生、夺舍、寄生要化形及以上）
static func family(line: String, level: String) -> Array:
	var late: Dictionary = data().get("late_only", {})
	var low := level_index(level) < level_index(str(late.get("min_level", "huaxing")))
	return line_keys(line).filter(func(k): return not (low and (late.get("keys", []) as Array).has(k)))


static func _roll(rng: Callable) -> float:
	return force_roll if force_roll >= 0.0 else float(rng.call())


static func _pick(xs: Array, rng: Callable):
	return xs[clampi(floori(_roll(rng) * xs.size()), 0, xs.size() - 1)]


static func _db_rec(i: Dictionary) -> Dictionary:
	return XDB.rec("Weapons" if str(i.get("kind", "")) == "weapon" else "Armors", int(i.get("base", 0)))


## 能做异化本体／能刻印：武器或这几类防具，不是专属武器，不是七印装备、净印、遗物、神器
static func body_ok(i) -> bool:
	if not i is Dictionary or i.is_empty() or not ["weapon", "armor"].has(str(i.get("kind", ""))):
		return false
	if not XTianqiQiyinEffects.mark_of(i).is_empty() or i.has("tq_reward") or XEquipment.is_exclusive(i):
		return false
	var et := 1 if str(i.kind) == "weapon" else int(_db_rec(i).get("etypeId", 0))
	return BODY_ETYPES.has(et)


## 名字「级·新词条名·原名」
static func relabel(i: Dictionary) -> void:
	var m := XAlienation.mark(i)
	var t := tq(i)
	if t.is_empty():
		return
	if str(i.name) != str(m.get("lastName", "")):
		m.plainName = _strip(str(i.name))
	i.name = "%s·%s·%s" % [level_name(str(t.level)), affix_name(str(m.affix)), str(m.plainName)]
	m.lastName = i.name


## 去掉名字前面的「级·词条·」或原版的「词条·」
static func _strip(n: String) -> String:
	var lv := PackedStringArray()
	for k in data().get("levels", {}):
		lv.append(level_name(k))
	var names := PackedStringArray()
	for f in XAlienation.config().get("affixes", []):
		names.append(str(f.name))
	for k in XTianqiRewards.data().get("finale", {}).get("names", {}).values():
		names.append(str(k))
	var re := RegEx.create_from_string("^(?:(?:" + "|".join(lv) + ")·)?(?:(?:" + "|".join(names) + ")·)?")
	return re.sub(n, "")


## 给一件装备打上天启篇异化（掉落、刻印共用）。affix 空＝本线本级随机
static func attach(s: XState, i: Dictionary, line: String, level: String, affix := "", rng := Callable()) -> Dictionary:
	if level_info(level).is_empty() or line_keys(line).is_empty():
		return {"error": "没有这条线或这一级"}
	var fam := family(line, level)
	if affix == "":
		if fam.is_empty():
			return {"error": "这一级没有能出的词条"}
		affix = str(_pick(fam, rng if rng.is_valid() else func(): return randf()))
	elif not line_keys(line).has(affix):
		return {"error": "这条词条不是本线的"}
	var old := XAlienation.mark(i)
	var plain := str(old.get("plainName", i.name)) if not old.is_empty() else str(i.name)
	XAlienation.ledger(s).sequence = int(XAlienation.ledger(s).sequence) + 1
	i.alien = {"uid": "alien-%d" % int(XAlienation.ledger(s).sequence), "origin": "boss" if level_index(level) >= 2 else "mob",
		"affix": affix, "pool": fam.duplicate(), "config": {}, "plainName": plain, "lastName": "",
		"tq": {"line": line, "level": level}}
	relabel(i)
	return {"ok": i}


## 新建一件（不放进背包）
static func create(s: XState, kind: String, id: int, line: String, level: String, affix := "", rng := Callable()) -> Dictionary:
	var inst := XGear.create(kind, id, s)
	if inst.is_empty():
		return {"error": "本体缺失"}
	s.register_gear(inst)
	return attach(s, inst, line, level, affix, rng)


# ---- 掉落 ----

## 本场天启篇的异化怪 [{enemy, line, level}]（各线异化模块的 units）
static func alien_units(logic) -> Array:
	var out := []
	for mod in MODULES:
		if not logic.has_meta(mod[0]):
			continue
		var f = logic.get_meta(mod[0])
		if not f is Dictionary:
			continue
		for e in f.get("units", {}):
			out.append({"enemy": e, "line": mod[1], "level": str(f.units[e].get("tier", ""))})
	return out


## 这只怪掉落表里能做本体的 [{kind, id}]
static func bodies(logic, e) -> Array:
	var out := []
	for c in logic.drop_chances(e):
		if [2, 3].has(int(c.kind)):
			var kind := "weapon" if int(c.kind) == 2 else "armor"
			var tpl := XGear.template(kind, int(c.id))
			if not tpl.is_empty() and body_ok(tpl) and not out.any(func(o): return o.kind == kind and o.id == int(c.id)):
				out.append({"kind": kind, "id": int(c.id)})
	return out


## BattleLogic.grant（赢了发奖）里调：异化怪倒下的按级掷，掉的放进背包；返回发了什么（名字）
static func grant(logic) -> Array:
	var s: XState = logic.state
	if not on(s):
		return []
	var got := []
	for u in alien_units(logic):
		var e = u.enemy
		var info := level_info(str(u.level))
		if info.is_empty() or not e.is_dead():
			continue
		var id: String = logic.stable_id(e)
		var rng := func(): return logic.random.reward.next_float("tianqi_alien_gear", id)
		if _roll(rng) >= float(info.get("rate", 0.0)):
			continue
		var list := bodies(logic, e)
		if list.is_empty():
			if str(u.level) == "zhongyan":
				var core := add_core(s, str(u.line), str(_pick(family(str(u.line), str(u.level)), rng)), str(u.level), "drop")
				got.append(core_label(core))
			continue
		var b: Dictionary = _pick(list, rng)
		var r := create(s, str(b.kind), int(b.id), str(u.line), str(u.level), "", rng)
		if r.has("error"):
			continue
		var i: Dictionary = r.ok
		s.gear.append(i)
		var l := XAlienation.ledger(s)
		(l.recent as Array).push_front({"name": str(i.name), "origin": str(i.alien.origin), "uid": str(i.alien.uid), "kind": XAlienation.kind(i), "id": str(i.get("instanceId", ""))})
		l.recent = (l.recent as Array).slice(0, 30)
		got.append(str(i.name))
	for n in got:
		logic.victory_texts.append("获得 " + n)
	return got


# ---- 异化核（和终焉异化核同一张表：flags.tianqi.rewards.cores） ----

static func cores(s: XState) -> Array:
	return XTianqiRewards.progress(s).get("cores", [])


static func add_core(s: XState, line: String, affix: String, level: String, from: String) -> Dictionary:
	var core := {"line": line, "affix": affix, "level": level, "from": from}
	var p := XTianqiRewards.progress(s)
	var list: Array = p.get("cores", [])
	list.append(core)
	p["cores"] = list
	return core


static func core_label(core: Dictionary) -> String:
	return "%s·%s 异化核" % [level_name(str(core.get("level", ""))), affix_name(str(core.get("affix", "")))]


# ---- 工坊 ----

static func dismantle_gain(i: Dictionary) -> int:
	return int(level_info(str(tq(i).get("level", ""))).get("energy", 1))


static func purify_refund(i: Dictionary) -> int:
	return int(level_info(str(tq(i).get("level", ""))).get("refund", 0))


static func _cost(key: String) -> int:
	return int(data().get("costs", {}).get(key, 1))


static func dismantle(s: XState, i: Dictionary) -> Dictionary:
	if not XAlienation.can_operate(s, i):
		return {"error": XAlienation.OPERATE_ERROR}
	var n := dismantle_gain(i)
	if s.item_count(XAlienation.energy_id()) + n > XAlienation.MAX_ITEMS:
		return {"error": "异化能量已达持有上限"}
	s.lose_gear(i)
	s.gain_item(XAlienation.energy_id(), n)
	return {"ok": n}


## 重抽：本线本级、去掉现有的那条；沿用原版待选（XAlienation.resolve 收尾）
static func reroll(s: XState, i: Dictionary) -> Dictionary:
	if not XAlienation.can_operate(s, i):
		return {"error": XAlienation.OPERATE_ERROR}
	var m := XAlienation.mark(i)
	var t := tq(i)
	m.pool = family(str(t.line), str(t.level))
	var pool: Array = m.pool.filter(func(k): return k != m.affix)
	if pool.is_empty():
		return {"error": "这一级没有别的词条可抽"}
	if s.item_count(XAlienation.stone_id()) < _cost("reroll"):
		return {"error": "缺少异化石"}
	s.gain_item(XAlienation.stone_id(), -_cost("reroll"))
	XAlienation.ledger(s).pending = {"uid": m.uid, "kind": XAlienation.kind(i), "id": str(i.get("instanceId", "")), "old": m.affix,
		"next": _pick(pool, func(): return XAlienation.force_roll if XAlienation.force_roll >= 0 else randf())}
	return {"ok": XAlienation.ledger(s).pending}


## 取核：装备没了，得一颗同线同级同词条的异化核
static func extract_core(s: XState, i: Dictionary) -> Dictionary:
	if not on(s):
		return {"error": "现在不能取核"}
	if not XAlienation.can_operate(s, i):
		return {"error": XAlienation.OPERATE_ERROR}
	var t := tq(i)
	var m := XAlienation.mark(i)
	s.lose_gear(i)
	return {"ok": add_core(s, str(t.line), str(m.affix), str(t.level), "extract")}


## 能刻印的装备：背包里（没穿、没锁、没被吞器占用）能做本体的武器、防具
static func engrave_targets(s: XState) -> Array:
	return XAlienation.owned(s).filter(func(i): return body_ok(i) and not XAlienation.locked(i) and not XAlienation.bound(s, i))


## 刻印：花异化石把第 index 颗核刻到 target 上（已有词条的替换）
static func engrave(s: XState, index: int, target: Dictionary) -> Dictionary:
	if not on(s):
		return {"error": "现在不能刻印"}
	var list := cores(s)
	if index < 0 or index >= list.size():
		return {"error": "没有这颗异化核"}
	if XAlienation.ledger(s).pending != null:
		return {"error": "先完成待选重抽"}
	if not engrave_targets(s).any(func(e): return is_same(e, target)):
		return {"error": "只能刻到背包里没穿、没锁定、没被占用的武器或防具上"}
	if s.item_count(XAlienation.stone_id()) < _cost("engrave"):
		return {"error": "缺少异化石"}
	var core: Dictionary = list[index]
	var r := attach(s, target, str(core.line), str(core.level), str(core.affix))
	if r.has("error"):
		return r
	s.gain_item(XAlienation.stone_id(), -_cost("engrave"))
	list.remove_at(index)
	return r


## 净化：去掉词条还原成普通装备，退还一部分分解能量
static func purify(s: XState, i: Dictionary) -> Dictionary:
	if not on(s):
		return {"error": "现在不能净化"}
	if not XAlienation.can_operate(s, i):
		return {"error": XAlienation.OPERATE_ERROR}
	if s.item_count(XAlienation.stone_id()) < _cost("purify"):
		return {"error": "缺少异化石"}
	var n := purify_refund(i)
	s.gain_item(XAlienation.stone_id(), -_cost("purify"))
	i.name = str(XAlienation.mark(i).get("plainName", i.name))
	i.erase("alien")
	s.gain_item(XAlienation.energy_id(), mini(n, XAlienation.MAX_ITEMS - s.item_count(XAlienation.energy_id())))
	return {"ok": n}


## 工坊详情的前几行（配置行由 XAlienation.details 接着加）
static func details(s: XState, i: Dictionary) -> Array:
	var m := XAlienation.mark(i)
	var t := tq(i)
	var key := str(m.get("affix", ""))
	var f := affix_view(s, key)
	var out := ["异化：%s（%s）" % [affix_name(key), level_name(str(t.level))],
		"收益：" + str(f.get("benefit", "")), "代价：" + str(f.get("cost", "")),
		"来源：%s线异化怪；分解获得%d点能量" % [str(XTianqi.line_info(str(t.line)).get("name", t.line)), dismantle_gain(i)]]
	if is_new_affix(key):
		out.append("未生效：本线新词条的战斗效果还没做。")
	return out
