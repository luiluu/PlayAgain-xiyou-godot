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
## - 难度倍率（DIFFICULTY）：寻常 1、艰险 1.1、九死 1.3、炼狱 1.5、证道 1.8，和全队倍率相乘；读 balance_table.json 每档 scaling.reward（XTianqiBalance.reward_mult，和金钱共用）。
## - 招牌掉落（SIGNATURE，第二期）：怪物表里留下的行。史诗及以上的装备不再乘 0.2，按品质夹在范围里
##   （史诗 3%～10%、传说 2%～6%、不朽 1%～3%、神话 0.5%～2%，原来必掉的还是必掉）；材料和道具实际概率不变（原表 × 0.2），最低 0.5%。
##   乘全队倍率和难度倍率后按递增概率掷（Dota 2 的伪随机分布）：同一只怪的同一件东西每次没出，下一次概率涨一截，出了归零，
##   长期平均等于面板概率。连着没出的次数、掷过的总次数、种子都记在存档（flags.tianqi.drop），随机数由它们算出来，读档重打结果一样。
##   SIGNATURE 关着（或 BONUS 关着，招牌的倍率要用新加成）时：留下的行照原表 × 0.2 × 加成，用战斗随机流掷。
##
## - 第三期：守层者不走每场的掷法，固定给（首杀 1 件高一档＋3 件门槛档，再打 2 件，28～30 层没有随机遇敌、再打 6 件），不吃加成；
##   副本里按所选档位把高一档、高两档的权重乘 1／1.3／1.6／2（件数不变）；商店买来的装备打上 tq_bought，不能喂法宝（NO_FEED_BOUGHT）。
##
## - 第四期：挂机「屏蔽掉落」开着时，通用掉落里低于门槛档的自动按卖价折成钱、够门槛的留着（AUTO_SELL；原版是精良及以下全丢）；
##   怪物图鉴、地图传送预览的掉率换成招牌掉落的面板概率，图鉴里标「已连续 N 次没出」。
##
## 回退（O-403）：`SEED_FROM_SAVE`／`PITY_RESET_ON_SURE`（O-429，返修）关掉回旧写法；`AUTO_SELL = false` 屏蔽掉落照原版丢；`NO_FEED_BOUGHT = false` 商店货也能喂；`XTianqiDrop.ENABLED = false` 整个关；`GENERIC`／`BONUS`／`DIFFICULTY`／`SIGNATURE` 各关一项。

static var ENABLED := true
static var GENERIC := true
static var BONUS := true
static var DIFFICULTY := true
static var SIGNATURE := true
static var NO_FEED_BOUGHT := true
static var AUTO_SELL := true
## 返修（O-429）：旧档首次掉落种子由存档种子派生；必掉也清连败、推进总次数
static var SEED_FROM_SAVE := true
static var PITY_RESET_ON_SURE := true

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
	out.append_array(XTianqiTrumpet.drop_sources(a))  # 天启篇号卷七号·赏赐（定值，不落档）
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
	return XTianqiBalance.reward_mult(s)  # 难度奖励倍率：balance_table.json scaling.reward，和金钱共用（金钱重构 v0.2）


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


# ---- 招牌掉落 ----

static func signature_on(s = null) -> bool:
	return SIGNATURE and on(s)


## 一行的面板概率（没乘全队倍率、难度倍率）：raw 是原表的概率（1÷分母，或 <Enemy Drops> 的百分数）
static func signature_base(kind: int, id: int, raw: float) -> float:
	var g: Dictionary = table().get("signature", {})
	var item_p := minf(1.0, maxf(raw * float(g.get("item_base", BASE_RATE)), float(g.get("item_floor", 0.005))))
	if kind < 2:
		return item_p
	if raw >= 1.0:
		return 1.0
	var range_ = g.get("gear_range", {}).get(str(XQuality.grade(XDB.rec("Weapons" if kind == 2 else "Armors", id))))
	if not range_ is Array:
		return item_p  # 精良及以下（通用掉落关着或异化装备挑本体时才会问到）
	return clampf(raw, float(range_[0]), float(range_[1]))


## 递增概率的步长 C：第 n 次（从 1 数）掷中的几率是 min(1, C×n)，长期平均是 p
static var _prd: Dictionary = {}
static func prd_step(p: float) -> float:
	if p <= 0.0:
		return 0.0
	if p >= 1.0:
		return 1.0
	var key := snappedf(p, 0.001)
	if key <= 0.0:
		return PI * p * p / 2.0
	if _prd.has(key):
		return float(_prd[key])
	var c: float
	if key < float(table().get("signature", {}).get("prd_exact_from", 0.05)):
		c = PI * key * key / 2.0  # 小概率的近似式，误差百分之几
	else:
		var lo := 0.0
		var hi := key
		for i in 40:
			c = (lo + hi) / 2.0
			if _prd_mean(c) > key:
				hi = c
			else:
				lo = c
		c = (lo + hi) / 2.0
	_prd[key] = c
	return c


## 步长 c 时的长期平均概率
static func _prd_mean(c: float) -> float:
	var by := 0.0
	var expect := 0.0
	var n := 1
	while by < 1.0 - 1e-12 and n <= 100000:
		var on_n := minf(1.0, c * n) * (1.0 - by)
		by += on_n
		expect += n * on_n
		n += 1
	return 1.0 / expect if expect > 0.0 else 1.0


## 存档里的掉落账：{seed, pity: {键: [连着没出的次数, 掷过的总次数]}}
static func store(s: XState) -> Dictionary:
	var tq: Dictionary = s.flags.tianqi
	if not tq.get("drop") is Dictionary:
		# 没有掉落账的旧档：种子由存档里已有的宝珠种子（orbSeed，随存档保存；更旧的档由存档内容算出）派生，
		# 读同一个档每次都一样，首次招牌掉落不能靠读档重掷（gpt 甲档补核 P2）。SEED_FROM_SAVE 关掉回到全局随机
		tq["drop"] = {"seed": XOrbs.hash32("tianqi-drop|%d" % int(s.orb_seed)) if SEED_FROM_SAVE else randi(), "pity": {}}
	var d: Dictionary = tq.drop
	if not d.get("pity") is Dictionary:
		d["pity"] = {}
	return d


## 这一次掷中的几率（已经连着没出 n 次）
static func signature_chance(p: float, fails: int) -> float:
	return minf(1.0, prd_step(p) * float(fails + 1)) if p < 1.0 else 1.0


## 掷一次招牌掉落：key＝「敌人号:种类:编号」，p＝乘完倍率的面板概率。结果由存档里的种子和次数算出，记账后返回中没中
static func roll_signature(s: XState, key: String, p: float) -> bool:
	if p <= 0.0:
		return false
	if p >= 1.0:
		# 必掉也算出了：已有账的清掉连败、推进总次数（「出了归零」，gpt 甲档补核 P2）；没账的不新建，免得存档里堆一堆必掉行。
		# PITY_RESET_ON_SURE 关掉回到直接返回
		if PITY_RESET_ON_SURE and s.flags.tianqi.get("drop") is Dictionary:
			var row0 = s.flags.tianqi.drop.get("pity", {}).get(key)
			if row0 is Array and row0.size() >= 2:
				s.flags.tianqi.drop.pity[key] = [0, int(row0[1]) + 1]
		return true
	var d := store(s)
	var row = d.pity.get(key)
	var fails := int(row[0]) if row is Array and row.size() >= 2 else 0
	var total := int(row[1]) if row is Array and row.size() >= 2 else 0
	# 字符串自带的 hash 对相邻的次数不够散（实测命中率偏低），用 sha256 的前 32 位
	var r := float(("%d|%s|%d" % [int(d.get("seed", 0)), key, total]).sha256_text().substr(0, 8).hex_to_int()) / 4294967296.0
	var hit := r < signature_chance(p, fails)
	d.pity[key] = [0 if hit else fails + 1, total + 1]
	return hit


## 连着没出几次了（图鉴指路用）
static func signature_fails(s: XState, key: String) -> int:
	if not signature_on(s) or not s.flags.tianqi.get("drop") is Dictionary:
		return 0
	var row = s.flags.tianqi.drop.get("pity", {}).get(key)
	return int(row[0]) if row is Array and row.size() >= 2 else 0


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


## 副本里高一档、高两档权重的倍数（不在副本里是 1）
static func dungeon_up(s: XState) -> float:
	if s == null or int(s.variable(XDungeon.VAR_INSIDE)) <= 0:
		return 1.0
	var tiers: Array = table().get("dungeon_up", {}).get("by_tier", [1.0])
	return float(tiers[clampi(int(s.variable(XDungeon.VAR_TIER)) - 1, 0, tiers.size() - 1)])


## 品质档：r 是 0～1 随机数；up 是高一档、高两档权重的倍数
static func roll_grade(floor_no: int, r: float, up := 1.0) -> int:
	var g: Dictionary = table().get("generic", {})
	var w: Array = (g.get("quality_weights", [30, 55, 12, 3]) as Array).duplicate()
	for i in range(2, w.size()):
		w[i] = float(w[i]) * up
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


## 守层者这一场固定给的品质档列表（不是守层者返回 null）：首杀＝还没过这一层（变量 20 不大于这一层）
static func guardian_grades(s: XState, troop_id: int):
	var floor_no := int(XZhenqi.GUARDIANS.get(troop_id, 0))
	var range_: Array = table().get("generic", {}).get("floors", [1, 30])
	if floor_no < int(range_[0]) or floor_no > int(range_[1]):
		return null
	var g: Dictionary = table().get("guardian", {})
	var gate := gate_grade(floor_no)
	var top := int(table().get("generic", {}).get("top_grade", 5))
	var out := []
	if int(s.variable(20)) <= floor_no:
		var first: Array = g.get("first", [1, 3])
		for i in int(first[0]):
			out.append(mini(gate + 1, top))
		for i in int(first[1]):
			out.append(gate)
	else:
		for i in int(g.get("late_repeat", 6)) if floor_no >= int(g.get("late_floors", 28)) else int(g.get("repeat", 2)):
			out.append(gate)
	return [floor_no, out]


## 这一场的通用掉落 [{kind, id, generic}]；roll 每次给一个 0～1 随机数。troop_id 是守层者时固定给
static func roll(s: XState, members: Array, roll_fn: Callable, troop_id := 0) -> Array:
	var out := []
	if not generic_on(s):
		return out
	var fixed = guardian_grades(s, troop_id) if troop_id > 0 else null
	if fixed is Array:
		for gr in fixed[1]:
			var d := pick(s, int(fixed[0]), int(gr), members, float(roll_fn.call()), float(roll_fn.call()))
			if not d.is_empty():
				out.append(d)
		return out
	var floor_no := floor_of(s)
	if floor_no <= 0:
		return out
	var n := pieces(s, floor_no, members)
	var count := floori(n)
	if float(roll_fn.call()) < n - float(count):
		count += 1
	var up := dungeon_up(s)
	for i in count:
		var d := pick(s, floor_no, roll_grade(floor_no, float(roll_fn.call()), up), members, float(roll_fn.call()), float(roll_fn.call()))
		if not d.is_empty():
			out.append(d)
	return out


## 商店成交后调：这次买进来的装备（背包里 from 之后新增的）打上标记，不能喂法宝；price≥0 时记下单价（回售价封顶用，XTianqiMoney.sell_price）。
## 标记只是记账，天启篇档都打，不看掉落总开关：用不用由各自的开关定（NO_FEED_BOUGHT 管喂、XTianqiMoney.SELL_BOUGHT_CAP 管卖）
static func mark_bought(s: XState, from: int, price := -1) -> void:
	if s == null or not XTianqi.active(s):
		return
	for i in range(maxi(0, from), s.gear.size()):
		if s.gear[i] is Dictionary:
			s.gear[i]["tq_bought"] = true
			if price >= 0:
				s.gear[i]["tq_buy_price"] = price


## 这件装备因为是商店买的不能喂法宝
static func feed_blocked(s: XState, item: Dictionary) -> bool:
	return NO_FEED_BOUGHT and on(s) and bool(item.get("tq_bought", false))


## XBattleLogic.rewards 调：一场只掷一次（rewards 会被多处调用），屏蔽掉落照样管
static func battle_drops(logic) -> Array:
	if not generic_on(logic.state):
		return []
	if not logic.has_meta("tianqi_generic"):
		var drops := []
		if not logic.enemies.any(func(e): return e.zq_trial_loot) and logic.enemies.any(func(e): return not e.hidden):
			drops = roll(logic.state, _members(logic), func(): return logic.random.reward.next_float("tianqi_generic", "battle"), int(logic.troop_id))
			drops = XPingbi.filter_drops(logic.state, _auto_sell(logic, drops))
		logic.set_meta("tianqi_generic", drops)
	return (logic.get_meta("tianqi_generic") as Array).duplicate(true)


## 挂机「屏蔽掉落」开着时：通用掉落里低于这一层门槛档的不进背包，按卖价折成钱（原版是普通、优秀、精良一律丢掉；
## 天启篇这些装备是法宝的口粮，够门槛的要留着）。折的钱记在本场，XBattleLogic.grant 里发。AUTO_SELL 关着时照原版丢。
static func _auto_sell(logic, drops: Array) -> Array:
	var s: XState = logic.state
	if not (XHangUp.is_active(s) and bool(XHangUp.settings(s).DropShield)):
		return drops
	if not AUTO_SELL:
		return XHangUp.shield_drops(s, drops)
	var fixed = guardian_grades(s, int(logic.troop_id))
	var gate := gate_grade(int(fixed[0]) if fixed is Array else floor_of(s))
	var kept := []
	var gold := 0
	for d in drops:
		var rec := XDB.rec("Weapons" if int(d.kind) == 2 else "Armors", int(d.id))
		if XQuality.grade(rec) < gate:
			var tq := XTianqiMoney.sell_price_grade(s, XQuality.grade(rec))  # 金钱重构：按品质的卖价（场钱）
			gold += tq if tq >= 0 else floori(float(rec.get("price", 0)) / 2.0)
		else:
			kept.append(d)
	logic.set_meta("tianqi_generic_gold", gold)
	return kept


## XBattleLogic.grant 调：发自动卖掉的钱
static func grant_sold(logic) -> int:
	var gold := int(logic.get_meta("tianqi_generic_gold", 0))
	if gold > 0:
		logic.state.gain_gold(gold)
		logic.set_meta("tianqi_generic_gold", 0)
	return gold


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
