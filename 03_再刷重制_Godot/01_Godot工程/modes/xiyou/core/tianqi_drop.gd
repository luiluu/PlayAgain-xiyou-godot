class_name XTianqiDrop
extends RefCounted
## 【cc·天启篇·未经审查】天启篇掉落重构第一期（掉落重构方案 v0.8，Kyo 2026-11-13 23:15「根据你的建议来」）。
## 只对天启篇存档生效（XTianqi.active），原版档照旧。规则表 tianqi_data/drop_table.json。
##
## - 通用掉落（GENERIC）：每场打赢掷一次，不看每只怪的表。件数期望 pieces（第 1 层翻倍）× 全队倍率 × 难度倍率；
##   品质以这一层法宝上限的喂养门槛档（XFabaoFeed.min_grade）为中心：低一档 30%、门槛 55%、高一档 12%、高两档 3%，最高到不朽；
##   装备从「敌人掉落表里出现过、不是专属、保留栏位」的池里按等级段挑，六成偏向当前队伍能穿的。只管 1～30 层（31 层起归七印祭坛）。
##   同时怪物表里精良及以下的装备不再掷（都交给通用掉落）。
## - 掉率加成（BONUS）：上场＋助力位的全部来源相加，再按 有效＝合计×k÷(合计＋k) 递减（k＝200，最高逼近 3 倍）。
##   来源：被动 passiveIRUP（技能重构改过的照它的值，别的按原值落五档 5／10／15／20／30）、套装物品掉率（同样落档）、
##   寻宝猎人状态 +30（原版是把 0.2 底率变成 1）、亡魂汲取 +20、词条「物品掉落」。原版是全部连乘。
## - 难度倍率（DIFFICULTY）：寻常 1、艰险 1.1、九死 1.3、炼狱 1.5、证道 1.8，和全队倍率相乘。
## 招牌掉落的改率与递增概率是第二期；本期怪物表里史诗及以上的装备、材料仍照原表 × 0.2 底率，只是加成换了新算法。
##
## 回退（O-待定-1）：`XTianqiDrop.ENABLED = false` 整个关；`GENERIC`／`BONUS`／`DIFFICULTY` 各关一项。

static var ENABLED := true
static var GENERIC := true
static var BONUS := true
static var DIFFICULTY := true

const PATH := "res://modes/xiyou/tianqi_data/drop_table.json"
const BASE_RATE := 0.2
const TREASURE_HUNTER := 5  # 特性 64 的「双倍掉落」（XMapTransfer.DROP_ITEM_DOUBLE）

static var _table: Dictionary = {}
static var _load_failed := false
## 品质档 → [[种类 2／3, 编号, 等级需求], …]
static var _pool: Dictionary = {}


static func table() -> Dictionary:
	if _table.is_empty():
		if _load_failed or XDataFile.missing(PATH):  # 发行包里没有（没发行的内容）
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
		if not parsed is Dictionary:
			_load_failed = true
			push_error("XTianqiDrop: 读不到或解析失败 " + PATH)
			return {}
		_table = parsed
	return _table


static func on(s = null) -> bool:
	if not ENABLED:
		return false
	if s == null:
		s = XState.current
	return XTianqi.active(s) and not table().is_empty()


static func generic_on(s = null) -> bool:
	return GENERIC and on(s)


static func bonus_on(s = null) -> bool:
	return BONUS and on(s)


# ---- 掉率加成 ----

## 原值落档（不是技能重构定过的来源）；负的照样是负的
static func tier(v: float) -> float:
	var b: Dictionary = table().get("bonus", {})
	var a := absf(v)
	if a <= 0.0:
		return 0.0
	var out := float(b.get("top", 30))
	for row in b.get("tiers", []):
		if a < float(row[0]):
			out = float(row[1])
			break
	return out if v > 0.0 else -out


## 技能重构给这个技能定的掉率（没定过返回 NAN）。重构只对指定角色生效，所以还要和实际读到的值对上才算
static func rework_value(skill_id: int) -> float:
	var e = XTianqiSkills.data().get("skills", {}).get(str(skill_id))
	if not e is Dictionary:
		return NAN
	var m := RegEx.create_from_string("passiveIRUP:\\s*(-?[\\d.]+)").search(str(e.get("note_add", "")))
	return float(m.get_string(1)) if m else NAN


## 一个角色身上的掉率来源：[{name, value}]（界面和测试也用）
static func sources_of(a: XActor) -> Array:
	var out := []
	var ignore: Array = table().get("bonus", {}).get("ignore_skills", []).map(func(x): return int(x))
	for sk in a.skills():
		var m: Dictionary = sk.get("meta", {})
		if not m.has("passiveIRUP") or ignore.has(int(sk.get("id", 0))):
			continue
		var v := XActor._num(m["passiveIRUP"])
		var rw := rework_value(int(sk.get("id", 0)))
		out.append({"name": str(sk.get("name", "")), "value": v if not is_nan(rw) and is_equal_approx(rw, v) else tier(v)})
	for b in XEquipSuits.active(a):
		var plus: Array = b.get("bResultPlus", [])
		if plus.size() > 2 and float(plus[2]) != 0.0:
			out.append({"name": "套装", "value": tier(float(plus[2]))})
	return out


## 全队掉率加成合计（百分数，没递减）。members 不给时取出战栏的上场＋助力位
static func party_bonus(s: XState, members = null) -> float:
	var ms: Array = members if members is Array else XTianqiAffixBattle.members(s)
	var b: Dictionary = table().get("bonus", {})
	var total := 0.0
	var hunter := false
	var drain := false
	for a in ms:
		for src in sources_of(a):
			total += float(src.value)
		hunter = hunter or not a.traits_with_id(64, TREASURE_HUNTER).is_empty()
		drain = drain or XRaven.has(a, XRaven.SOUL_DRAIN)
	if hunter:
		total += float(b.get("treasure_hunter", 30))
	if drain:
		total += float(b.get("soul_drain", 20))
	total += XTianqiAffixBattle.party_sum(ms, "drop_rate")
	return total


## 递减后的有效加成（百分数）
static func effective(total: float) -> float:
	var b: Dictionary = table().get("bonus", {})
	if total <= 0.0:
		return maxf(total, float(b.get("negative_floor", -90)))
	var k := float(b.get("k", 200))
	return total * k / (total + k)


static func party_mult(s: XState, members = null) -> float:
	return 1.0 + effective(party_bonus(s, members)) / 100.0


static func difficulty_mult(s: XState) -> float:
	if not DIFFICULTY or s == null or not s.flags.get("tianqi") is Dictionary:
		return 1.0
	return float(table().get("difficulty", {}).get(str(s.flags.tianqi.get("difficulty", "")), 1.0))


## 怪物表掉落的倍率（XBattleLogic.drop_chances；本期仍带 0.2 底率，不再有寻宝猎人的 ×5 和神话怪）
static func table_rate(logic) -> float:
	var s: XState = logic.state
	return BASE_RATE * party_mult(s, _members(logic)) * difficulty_mult(s)


static func _members(logic) -> Array:
	var ms: Array = XTianqiAffixBattle._reward_members(logic)
	return ms if not ms.is_empty() else XTianqiAffixBattle.members(logic.state)


## 怪物表里这一条在天启篇还掷不掷：通用掉落开着时，精良及以下的装备不掷
static func keeps_row(s: XState, kind: int, id: int) -> bool:
	if not generic_on(s) or kind < 2:
		return true
	var rec := XDB.rec("Weapons" if kind == 2 else "Armors", id)
	return XQuality.grade(rec) > int(table().get("generic", {}).get("table_cut_grade", 2))


# ---- 通用掉落 ----

## 这场战斗算哪一层（0＝不掉通用装备）
static func floor_of(s: XState) -> int:
	var f := XDungeon.boss_floor(s.map_id)
	var range_: Array = table().get("generic", {}).get("floors", [1, 30])
	return f if f >= int(range_[0]) and f <= int(range_[1]) else 0


## 这一层的门槛品质档（法宝上限对应的喂养门槛）
static func gate_grade(floor_no: int) -> int:
	return XFabaoFeed.min_grade(float(mini(XMagicWeapon.CAP_TOP, 9 + 3 * maxi(1, floor_no))))


## 这一层挑装备用的等级（按层插值）
static func level_of(floor_no: int) -> int:
	var rows: Array = table().get("generic", {}).get("level_by_floor", [])
	if rows.is_empty():
		return 99
	var prev: Array = rows[0]
	for row in rows:
		if floor_no <= int(row[0]):
			if int(row[0]) == int(prev[0]):
				return int(row[1])
			var t := float(floor_no - int(prev[0])) / float(int(row[0]) - int(prev[0]))
			return roundi(lerpf(float(prev[1]), float(row[1]), clampf(t, 0.0, 1.0)))
		prev = row
	return int(prev[1])


## 每场期望件数
static func pieces(s: XState, floor_no: int, members = null) -> float:
	var g: Dictionary = table().get("generic", {})
	var n := float(g.get("pieces", 0.9)) * float(g.get("floor_mult", {}).get(str(floor_no), 1.0))
	return maxf(0.0, n * party_mult(s, members) * difficulty_mult(s))


## 品质档：r 是 0～1 随机数
static func roll_grade(floor_no: int, r: float) -> int:
	var g: Dictionary = table().get("generic", {})
	var w: Array = g.get("quality_weights", [30, 55, 12, 3])
	var gate := gate_grade(floor_no)
	var total := 0.0
	for x in w:
		total += float(x)
	var acc := 0.0
	var pick := w.size() - 1
	for i in w.size():
		acc += float(w[i])
		if r * total < acc:
			pick = i
			break
	return clampi(gate - 1 + pick, 0, int(g.get("top_grade", 5)))


static func pool(grade: int) -> Array:
	if _pool.is_empty():
		for r in XTianqiGear.drop_pool():
			var rec := XDB.rec("Weapons" if int(r[0]) == 2 else "Armors", int(r[1]))
			if not XTianqiGear._reroll_ok(int(r[0]), rec):
				continue
			if int(r[0]) == 3 and XTianqiGear.deleted_armor(int(r[1])):
				continue
			var gr := XQuality.grade(rec)
			if not _pool.has(gr):
				_pool[gr] = []
			_pool[gr].append([int(r[0]), int(r[1]), int(rec.get("meta", {}).get("req_level", 0))])
	return _pool.get(grade, [])


## 有人能穿这一件（按栏位、类型、专属判，等级也算）
static func _wearable(s: XState, row: Array, members: Array) -> bool:
	var rec := XDB.rec("Weapons" if int(row[0]) == 2 else "Armors", int(row[1]))
	if rec.is_empty():
		return false
	var item := rec.duplicate()
	item["kind"] = "weapon" if int(row[0]) == 2 else "armor"
	for a in members:
		if a.can_equip(item):
			return true
	return false


## 挑一件：品质档 grade（池空就往下一档），等级不超过这一层、尽量贴近。r1 决定要不要偏向能穿的，r2 挑哪一件。没得挑返回 {}
static func pick(s: XState, floor_no: int, grade: int, members: Array, r1: float, r2: float) -> Dictionary:
	var g: Dictionary = table().get("generic", {})
	var lv := level_of(floor_no)
	var window := int(g.get("level_window", 15))
	var gr := grade
	while gr >= 0:
		var all: Array = pool(gr)
		var cands: Array = all.filter(func(x): return int(x[2]) <= lv and int(x[2]) >= lv - window)
		if cands.is_empty():
			cands = all.filter(func(x): return int(x[2]) <= lv)
		if not cands.is_empty():
			if r1 < float(g.get("smart_share", 0.6)):
				var smart: Array = cands.filter(func(x): return _wearable(s, x, members))
				if not smart.is_empty():
					cands = smart
			var row: Array = cands[clampi(floori(r2 * cands.size()), 0, cands.size() - 1)]
			return {"kind": int(row[0]), "id": int(row[1]), "generic": true}
		gr -= 1
	return {}


## 这一场的通用掉落 [{kind, id, generic}]；roll 每次给一个 0～1 随机数
static func roll(s: XState, members: Array, roll_fn: Callable) -> Array:
	var out := []
	var floor_no := floor_of(s)
	if not generic_on(s) or floor_no <= 0:
		return out
	var n := pieces(s, floor_no, members)
	var count := floori(n)
	if float(roll_fn.call()) < n - float(count):
		count += 1
	for i in count:
		var d := pick(s, floor_no, roll_grade(floor_no, float(roll_fn.call())), members, float(roll_fn.call()), float(roll_fn.call()))
		if not d.is_empty():
			out.append(d)
	return out


## XBattleLogic.rewards 调：一场只掷一次（rewards 会被多处调用），屏蔽掉落照样管
static func battle_drops(logic) -> Array:
	if not generic_on(logic.state):
		return []
	if not logic.has_meta("tianqi_generic"):
		var drops := []
		if not logic.enemies.any(func(e): return e.zq_trial_loot) and logic.enemies.any(func(e): return not e.hidden):
			drops = roll(logic.state, _members(logic), func(): return logic.random.reward.next_float("tianqi_generic", "battle"))
			drops = XPingbi.filter_drops(logic.state, XHangUp.shield_drops(logic.state, drops))
		logic.set_meta("tianqi_generic", drops)
	return (logic.get_meta("tianqi_generic") as Array).duplicate(true)


## 数字避开 4（规则表自检）
static func nice_number_violations() -> Array:
	var bad := []
	_scan(table(), table().get("nice_number_exempt", []), "", bad)
	return bad


static func _scan(v, exempt: Array, path: String, bad: Array) -> void:
	if v is Dictionary:
		for k in v:
			if not exempt.has(str(k)) and not str(k).begins_with("_"):
				_scan(v[k], exempt, path + "/" + str(k), bad)
	elif v is Array:
		for i in v.size():
			_scan(v[i], exempt, path + "/" + str(i), bad)
	elif (v is float or v is int) and str(v).contains("4"):
		bad.append(path + "=" + str(v))
