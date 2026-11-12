class_name XTianqiSegAlien
extends RefCounted
## 【cc·天启篇·未经审查】按段异化（四线共用；四线剧情与关卡设计稿 v0.4 第 3.1、3.3、5.1 节，四线异化 v0.8 第 2.1 节）。
## 数据 tianqi_data/seg_alien.json（只读，测试参数）。
##
## 每场战斗（BattleLogic.setup，四骑士和本线预设异化之后）按这一档走的线、所在楼层、难度，决定敌群里哪一只异化成什么级、什么种类，
## 再经 XTianqiLine.alien_apply 交给本线的异化模块（战争线 XTianqiWarAlien、饥荒线 XTianqiFamineAlien 的 apply）去改数值、挂规则：
## - 谁能异化：看敌人数据名的【前缀】。稀有、精英＝稀有；前所未见、亘古未有、首领＝非常稀有；守层者；被封印者、未知存在、古神＝深渊怪。
##   无前缀、罕见、十分罕见＝小怪，不异化（会被同场的异化种类带动，例如号令官）。一场最多异化 max_units 只（1），按 守层者＞深渊＞非常稀有＞稀有 的顺序挨个掷。
## - 楼层：所在地图的层（XDungeon.map_floor 沿地图树找「N层」）；找不到（深渊副本等）按修行进度层（变量 20 − 1）。1～5 层（序幕）一概不异化，守层者也不。
## - 段表（第 3.3 节）：几率、基础级、升一级的几率；守层者、深渊怪一定异化；31～36 层守层者终焉。
## - 难度：寻常几率 ×0.5、稀有最高侵染、守层者低一级；九死 +10 个百分点；炼狱、证道 +20 个百分点、稀有的级上限高一级（最高化形）。
## - 种类：本线到这一层为止教过的种类里随机一种（第 5.1 节，每段多一种）；深渊怪本线种类全出。只抽本线模块已经做好的种类（战争线的连击兵还没做）。
## 已经有异化的战斗（本线预设：开场、使徒）和四骑士战不动；没选线、还没做好的线（死亡、瘟疫）不动；新线做好后在 XTianqiLine 的 alien_apply／alien_kinds 各加一行即可。
##
## 开关 ENABLED（false＝按段异化一概不出，只剩本线预设的几场）；只认天启篇存档且选了做好的线，发行构建里还要 XTianqi.RELEASE_OPEN。

const PATH := "res://modes/xiyou/tianqi_data/seg_alien.json"

## 开关：false＝普通楼层的怪不按段异化
static var ENABLED := true

static var _data: Dictionary = {}
static var _tag := XRx.re("^【([^】]+)】")


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiSegAlien: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("XTianqiSegAlien: JSON 解析失败 " + PATH)
	return _data


static func reload() -> void:
	_data = {}


static func nice_number_violations() -> Array:
	var out := []
	XTianqiHorsemen._scan(data(), "", data().get("nice_number_exempt", []), out)
	return out


# ---- 开关与线 ----

## 这一档能按段异化：开关开着、这一档走的线能跑（XTianqiLine.current：天启篇存档、发行构建里已开放、选了线且这条线做好了）
static func allowed(s: XState) -> bool:
	return ENABLED and s != null and XTianqiLine.current(s) != ""


## 这一场已经有本线预设的异化（开场、使徒）或是四骑士战
static func _taken(logic) -> bool:
	return XTianqiHorsemen.active(logic) or XTianqiLine.alien_active(logic)


# ---- 判定 ----

## 敌人的稀有度类：rare／very_rare／guardian／abyss；小怪返回 ""
static func class_of(e) -> String:
	var name := str(e.data().get("name", "")) if e is XEnemy else str(e)
	var m := _tag.search(name)
	if m == null:
		return ""
	return str(data().get("classes", {}).get(m.get_string(1), ""))


## 战斗所在楼层：地图所在层，找不到按修行进度层（变量 20 − 1）
static func floor_of(s: XState) -> int:
	var f := XDungeon.map_floor(int(s.map_id))
	if f <= 0:
		f = XTianqi.cleared_floors(s)
	return mini(f, int(data().get("floor_max", 36)))


static func segment(floor_no: int) -> Dictionary:
	for seg in data().get("segments", []):
		if floor_no >= int(seg.from) and floor_no <= int(seg.to):
			return seg
	return {}


static func _tier_idx(tier: String) -> int:
	return Array(data().get("tiers", [])).find(tier)


static func _tier_at(i: int) -> String:
	var t: Array = data().get("tiers", [])
	return str(t[clampi(i, 0, t.size() - 1)])


## 某类怪在这一层、这一档难度下的规则 {rate 百分数, tier, up, up_rate}；不异化为空
static func rule(cls: String, floor_no: int, diff_key: String) -> Dictionary:
	var row = segment(floor_no).get(cls)
	if not row is Dictionary:
		return {}
	var r: Dictionary = row.duplicate()
	r["up"] = str(r.get("up", ""))
	r["up_rate"] = float(r.get("up_rate", 0))
	var d: Dictionary = data().get("difficulty", {}).get(diff_key, {})
	var rate := float(r.rate)
	if cls == "rare" or cls == "very_rare":
		rate = rate * float(d.get("rate_mult", 1)) + float(d.get("rate_add", 0))
	r["rate"] = clampf(rate, 0.0, 100.0)
	if cls == "rare":
		var shift := int(d.get("rare_up_shift", 0))
		if shift > 0:
			if str(r.up) == "":
				r.up = _tier_at(_tier_idx(str(r.tier)) + shift)
				r.up_rate = float(d.get("rare_up_rate", 0))
			else:
				r.up = _tier_at(_tier_idx(str(r.up)) + shift)
		if d.has("rare_max"):
			var cap := _tier_idx(str(d.rare_max))
			if _tier_idx(str(r.tier)) > cap:
				r.tier = _tier_at(cap)
			if str(r.up) != "" and _tier_idx(str(r.up)) > cap:
				r.up = _tier_at(cap)
			if str(r.up) == str(r.tier):
				r.up = ""
				r.up_rate = 0.0
	elif cls == "guardian" and str(r.tier) != "zhongyan":
		var g := int(d.get("guardian_shift", 0))
		if g != 0:
			r.tier = _tier_at(clampi(_tier_idx(str(r.tier)) + g, 0, _tier_idx("huaxing")))
	return r


## 本线到这一层为止教过、模块也做好了的种类；深渊怪本线种类全出
static func kinds_for(line: String, floor_no: int, cls: String) -> Array:
	var have := XTianqiLine.alien_kinds(line)
	var out := []
	var teach = data().get("lines", {}).get(line, {}).get("teach", [])
	for step in teach:
		if cls == "abyss" or floor_no >= int(step[0]):
			for k in step[1]:
				if have.has(k) and not out.has(k):
					out.append(k)
	return out


## 给一场敌群定异化：返回 [{enemy, tier, kind, class}]。roll(理由, 键) 返回 [0,1) 的随机数（战斗用本场随机流，测试可换）
static func plan(s: XState, enemies: Array, roll: Callable) -> Array:
	if not allowed(s):
		return []
	var line := XTianqiLine.current(s)
	var floor_no := floor_of(s)
	if segment(floor_no).is_empty() or floor_no <= 5:
		return []
	var diff := str(s.flags.tianqi.get("difficulty", ""))
	var order: Array = data().get("priority", [])
	var cands := []
	for i in enemies.size():
		var e = enemies[i]
		if e.hidden:
			continue
		var cls := class_of(e)
		if cls != "":
			cands.append([order.find(cls), i, e, cls])
	cands.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out := []
	for c in cands:
		if out.size() >= int(data().get("max_units", 1)):
			break
		var e = c[2]
		var cls: String = c[3]
		var r := rule(cls, floor_no, diff)
		if r.is_empty():
			continue
		var key := "%d:%d" % [int(c[1]), int(e.enemy_id)]
		if float(r.rate) < 100.0 and float(roll.call("tianqi_seg.rate", key)) * 100.0 >= float(r.rate):
			continue
		var tier := str(r.tier)
		if str(r.up) != "" and float(roll.call("tianqi_seg.up", key)) * 100.0 < float(r.up_rate):
			tier = str(r.up)
		var ks := kinds_for(line, floor_no, cls)
		if ks.is_empty():
			continue
		var kind = ks[mini(floori(float(roll.call("tianqi_seg.kind", key)) * ks.size()), ks.size() - 1)]
		out.append({"enemy": e, "tier": tier, "kind": str(kind), "class": cls})
	return out


## BattleLogic.setup：四骑士、本线预设异化之后调
static func setup(logic, s: XState) -> void:
	if s == null or _taken(logic) or not allowed(s):
		return
	var rng = logic._rule()
	var list := plan(s, logic.enemies, func(reason: String, key: String) -> float: return rng.next_float(reason, key))
	if not list.is_empty():
		XTianqiLine.alien_apply(XTianqiLine.current(s), logic, s, list)
