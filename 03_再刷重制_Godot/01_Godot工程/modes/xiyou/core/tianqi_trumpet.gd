class_name XTianqiTrumpet
extends RefCounted
## 【cc·天启篇·未经审查】天启篇号卷：七卷「号卷」替换原洪荒权能书（设计仓库《天启篇_权能书重做方案_v0.4》，Kyo 2026-11-14「都可以」）。
## 只对天启篇存档（XTianqi.active）生效，发行构建另要 XTianqi.RELEASE_OPEN；原版档、洪荒路线照旧走 XHonghuang／XPowerBooks。
## 数据：modes/xiyou/tianqi_data/trumpet.json（数值全是占位，交技能重构线校准）。
##
## 怎么接（各一行）：
## - 记录：XDB.rec 遇到七卷的道具号、技能号和遗忘符 3044 时换成改写后的副本（新名字、说明；技能备注只留显示行，原洪荒效果标签全去掉，
##   效果在下面的战斗钩子里做）。另外三本（命运指引、生命之火、阴阳合一·阳）不动，天启篇里也不掉。
## - 学习：XPowerBooks.limit 改读本表（弱者 3、强者 2、超强者 1，档位按天启篇名单）；学习、封卷的提示文字换成号卷、封卷。
## - 掉落：XHonghuang.battle_started／roll_power 在天启篇存档改走这里——只在炼狱、证道两档，打赢副本里的不朽存在（XYunshangOrders.immortal_clear，
##   不看路线），本段每卷掷一次，起步 3%、每次没出 +3%、乘全队物品掉率（XTianqiDrop.party_mult，不乘难度倍率），出了以后这个存档不再掉。
##   原版诅咒倍率、副本熟练度倍率都不乘。
## - 商店：大厅特殊物品店（Map004 EV063）的封卷只在炼狱、证道上架（mv_interpreter 302）。
## - 战斗：开战 start、回合开始 turn_begin（五号站起来，在排顺序之前）／start_turn（六号第 1 回合排到最前，排顺序之后）、
##   伤害帧 damage_ops（XActorDamageHooks）、暴击率 cri、扣血 hp_damage（四号留 1 点）、技能消耗 cost、持续伤害／回复 dot_value（XExtDot）、
##   减益回合 state_added（XBattler.add_state）、金钱 gold（奖励）、物品掉率 drop_sources（XTianqiDrop.sources_of）、收场 finish。
##
## 我的读法（稿子没写死的地方，写进交付单待审）：
## - 伤害的加减都进「伤害加成」池（finalAdd，和词条的伤害加成同一个加法池）；初号的「全体」按范围 敌方全体、随机 2～4 体算，
##   「单体」按 敌方单体、随机 1 体算，普攻不算技能；二号看目标出手前的生命比例。
## - 三号的「减益 +33%」读成回合数 ×1.33（向上取整）；持续伤害、持续回复读成 XExtDot 的每跳数值 ×1.33（施加者是自己）；
##   特性里的 HP 再生率（不记施加者）不算。「受到的治疗」只算治疗技能（伤害类型 3）。
## - 五号站起来那一回合不行动（顺序在死的时候就排过了），下一回合起照常。
## 开关（O-413）：ENABLED＝false 整个关（天启篇里回到原版十本洪荒权能书：名字效果照旧、掉落跟原版只认洪荒开关，天启篇实际不掉）。

static var ENABLED := true

const PATH := "res://modes/xiyou/tianqi_data/trumpet.json"
const DEATH_STATE := 1
const AOE_SCOPES := [2, 4, 5, 6]  # 敌方全体、随机敌方 2～4 体（RPG Maker scope 号）
const SINGLE_SCOPES := [1, 3]  # 敌方单体、随机敌方 1 体

static var _data: Dictionary = {}
static var _load_failed := false
static var _by_skill: Dictionary = {}
static var _by_item: Dictionary = {}
static var _recs: Dictionary = {}  # "种类:号" → [原记录, 改写后]


static func data() -> Dictionary:
	if _data.is_empty():
		if _load_failed or XDataFile.missing(PATH):  # 发行包里没有（没发行的内容）
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
		if not parsed is Dictionary:
			_load_failed = true
			push_error("XTianqiTrumpet: 读不到或解析失败 " + PATH)
			return {}
		_data = parsed
		for sc in _data.get("scrolls", []):
			_by_skill[int(sc.skill)] = int(sc.n)
			_by_item[int(sc.item)] = int(sc.n)
	return _data


static func on(s = null) -> bool:
	if not ENABLED:
		return false
	if s == null:
		s = XState.current
	return XTianqi.active(s) and (XTianqi.RELEASE_OPEN or not ReleaseEntry.is_release()) and not data().is_empty()


static func scrolls() -> Array:
	return data().get("scrolls", [])


## 第 n 卷（1～7）的表行；没有返回空
static func scroll(n: int) -> Dictionary:
	for sc in scrolls():
		if int(sc.n) == n:
			return sc
	return {}


static func of_skill(id: int) -> int:
	data()
	return int(_by_skill.get(id, 0))


static func of_item(id: int) -> int:
	data()
	return int(_by_item.get(id, 0))


# ---- 记录改写（XDB.rec） ----

## XDB.rec 的快路径：这个号是不是要改写的（只查表，不看存档；不是这几个号的调用不再往下走）
static func touches(table: String, id: int) -> bool:
	if not ENABLED or _load_failed:
		return false
	data()
	if table == "Skills":
		return _by_skill.has(id)
	return _by_item.has(id) or id == XPowerBooks.FORGET_ITEM

static func _pos(label: String, text: String) -> String:
	return "<pos=APs text=%s:%s size=18 color=rgba(255,255,255,1) line=false align=0>" % [label, text]


static func _limit_line() -> String:
	var l: Dictionary = data().get("limit", {})
	return "弱者最多%d卷，强者%d卷，超强者%d卷" % [int(l.get(XTier.WEAK, 3)), int(l.get(XTier.STRONG, 2)), int(l.get(XTier.SUPER, 1))]


static func _source_line(sc: Dictionary) -> String:
	var seg: Array = data().get("drop", {}).get("segments", [])[int(sc.segment) - 1]
	var hi := "以上" if int(seg[1]) >= 99 else "～%d层" % int(seg[1])
	return "炼狱、证道副本%d层%s的不朽存在通关后掉落，每个存档只掉一次" % [maxi(1, int(seg[0])), hi]


## 七卷的技能号、道具号、遗忘符：天启篇存档换成改写后的记录
static func rec(table: String, id: int, base: Dictionary) -> Dictionary:
	if base.is_empty() or not on():
		return base
	var key := "%s:%d" % [table, id]
	var hit = _recs.get(key)
	if hit is Array and is_same(hit[0], base):
		return hit[1]
	var out := base
	if table == "Skills" and of_skill(id) > 0:
		out = _skill(base, scroll(of_skill(id)))
	elif table == "Items" and of_item(id) > 0:
		out = _item(base, scroll(of_item(id)))
	elif table == "Items" and id == XPowerBooks.FORGET_ITEM:
		out = _forget(base)
	else:
		return base
	_recs[key] = [base, out]
	return out


static func _skill(base: Dictionary, sc: Dictionary) -> Dictionary:
	var r: Dictionary = base.duplicate(true)
	r.name = str(sc.name)
	r.description = "被动\n天启号卷"
	var note := "\n".join(["<Hide in Battle>", "<ici:12>", "<quality:12>", _pos("\\c[1]效果", str(sc.sweet)), _pos("\\c[2]代价", str(sc.bitter)),
		"<TianqiTrumpet: %d>" % int(sc.n)])
	r.note = note
	r.meta = XTianqiSkills.parse_meta(note)
	return r


static func _item(base: Dictionary, sc: Dictionary) -> Dictionary:
	var r: Dictionary = base.duplicate(true)
	r.name = "号卷：" + str(sc.name)
	r.description = "天启号卷\n学习后获得被动「%s」" % str(sc.name)
	var note := "\n".join(["<quality:12>", "<ici:12>", _pos("\\c[1]效果", str(sc.sweet)), _pos("\\c[2]代价", str(sc.bitter)),
		_pos("\\c[1]获得", _source_line(sc)), "<CodexPower: %d>" % int(sc.segment), _pos("限制", _limit_line()),
		_pos("\\c[8]号声", str(sc.lore))])
	r.note = note
	r.meta = XTianqiSkills.parse_meta(note)
	return r


static func _forget(base: Dictionary) -> Dictionary:
	var fg: Dictionary = data().get("forget", {})
	var r: Dictionary = base.duplicate(true)
	r.name = str(fg.get("name", "封卷"))
	r.description = str(fg.get("desc", ""))
	var note := "\n".join(["<quality:10>", "<ici:10>", "<Item 2530 Buy Price: 500>", "<CodexPowerForget>",
		_pos("\\c[1]效果", "选择一名角色，封上一卷已学的号卷"), _pos("代价", "每次消耗1枚，号卷不返还"),
		_pos("\\c[8]出处", "七雷所说的你要封上")])
	r.note = note
	r.meta = XTianqiSkills.parse_meta(note)
	return r


## 遗忘道具叫什么（界面用）
static func forget_name() -> String:
	if not on():
		return "权能遗忘符"
	return str(data().get("forget", {}).get("name", "封卷"))


## 书叫什么（提示文字用）
static func book_word() -> String:
	if not on():
		return "权能书"
	return "号卷"


# ---- 学习 ----

## 天启篇的档位（名单），不是名单里的角色按原版强弱
static func tier_of(a: XActor) -> String:
	if not on():
		return ""
	var t := XTianqiSkills.tier_of(a)
	return t if t != "" else XPowerBooks.actor_class(a)


static func limit(a: XActor) -> int:
	if not on():
		return 0
	return int(data().get("limit", {}).get(tier_of(a), 1))


## 这个人学了第 n 卷没有（天启篇存档）
static func has(a, n: int) -> bool:
	if not (a is XActor) or not on():
		return false
	var sc := scroll(n)
	return not sc.is_empty() and (a as XActor).skill_ids.has(int(sc.skill))


## 这个人学了哪几卷
static func learned(a) -> Array:
	if not (a is XActor) or not on():
		return []
	var out := []
	for sc in scrolls():
		if (a as XActor).skill_ids.has(int(sc.skill)):
			out.append(int(sc.n))
	return out


## XPowerBooks.param_rate_bonus：七卷的原 CodexParamRate 在天启篇不算（缓存按技能号，跨存档会串）
static func skips_rate(id: int) -> bool:
	if not on():
		return false
	return of_skill(id) > 0


# ---- 掉落 ----

static func _difficulty(s: XState) -> String:
	return str(s.flags.tianqi.get("difficulty", "")) if XTianqi.active(s) else ""


static func drops_here(s: XState) -> bool:
	if not on(s):
		return false
	return (data().get("drop", {}).get("difficulties", []) as Array).has(_difficulty(s))


## 大厅特殊物品店上不上架封卷
static func sells_forget(s: XState) -> bool:
	if not on(s):
		return true
	return (data().get("forget", {}).get("difficulties", []) as Array).has(_difficulty(s))


## 商品表过滤（mv_interpreter 302）
static func shop_goods(s: XState, goods: Array) -> Array:
	if sells_forget(s):
		return goods
	return goods.filter(func(g): return int(g[0]) != 0 or int(g[1]) != XPowerBooks.FORGET_ITEM)


static func segment(floor_no: int) -> int:
	var segs: Array = data().get("drop", {}).get("segments", [])
	for i in segs.size():
		if floor_no >= int(segs[i][0]) and floor_no <= int(segs[i][1]):
			return i + 1
	return segs.size()


## 存档里的账：{dropped: {"n": true}, fails: {"n": 次数}}
static func store(s: XState) -> Dictionary:
	var tq: Dictionary = s.flags.tianqi
	if not tq.get("trumpet") is Dictionary:
		tq["trumpet"] = {"dropped": {}, "fails": {}}
	return tq.trumpet


static func dropped(s: XState, n: int) -> bool:
	if not XTianqi.active(s) or not s.flags.tianqi.get("trumpet") is Dictionary:
		return false
	return bool(s.flags.tianqi.trumpet.get("dropped", {}).get(str(n), false))


## 这一次掷中的概率（0～1）
static func chance(s: XState, n: int) -> float:
	var d: Dictionary = data().get("drop", {})
	var fails := int(store(s).fails.get(str(n), 0))
	var pct := float(d.get("base", 3)) + float(d.get("step", 3)) * fails
	return clampf(pct / 100.0 * XTianqiDrop.party_mult(s), 0.0, 1.0)


## XHonghuang.battle_started：这场算不算号卷掉落战（返回 null＝不是天启篇存档，照原版）
static func eligible(s: XState, troop: int):
	if not on(s):
		return null
	return drops_here(s) and XYunshangOrders.immortal_clear(s, troop)


## XHonghuang.roll_power：本段每卷掷一次。返回 {got, toasts}；不是天启篇存档返回空（照原版）
static func roll(s: XState, floor_no: int, rand: Callable) -> Dictionary:
	if not on(s):
		return {}
	var got := []
	var toasts := []
	var st := store(s)
	var seg := segment(floor_no)
	for sc in scrolls():
		var n := int(sc.n)
		if int(sc.segment) != seg or dropped(s, n):
			continue
		var p := chance(s, n)
		if float(rand.call()) < p:
			st.dropped[str(n)] = true
			st.fails.erase(str(n))
			s.gain_item(int(sc.item), 1)
			got.append(int(sc.item))
			toasts.append("号声响起：%s！" % str(XDB.rec("Items", int(sc.item)).get("name", "")))
		else:
			st.fails[str(n)] = int(st.fails.get(str(n), 0)) + 1
	return {"got": got, "toasts": toasts}


# ---- 战斗 ----

static func _store(logic) -> Dictionary:
	if logic == null or not logic.has_meta("xtrumpet"):
		return {}
	return logic.get_meta("xtrumpet")


static func _active(logic) -> bool:
	return logic != null and logic.has_meta("xtrumpet")


static func _logic():
	return XAlienBattle.active_logic()


static func _unit(logic, b) -> Dictionary:
	var st := _store(logic)
	if not st.units.has(b):
		st.units[b] = {"saves": 0, "revives": 0, "risen": false}
	return st.units[b]


## 本场学了第 n 卷的人（开战时记的，上场＋助力位）
static func _holder(logic, n: int):
	for a in _store(logic).get("holders", {}).get(n, []):
		return a
	return null


static func _p(n: int, key: String, fallback := 0.0) -> float:
	return float(scroll(n).get(key, fallback))


## 开战：建本场数据，记谁学了哪卷、七号齐鸣成没成
static func start(logic) -> void:
	if logic.has_meta("xtrumpet"):
		logic.remove_meta("xtrumpet")
	if not on(logic.state):
		return
	var holders := {}
	var fighters := {}
	var ms: Array = logic.actors.duplicate()
	for m in XTianqiAffixBattle.members(logic.state):
		if not ms.has(m):
			ms.append(m)
	for a in ms:
		for n in learned(a):
			if not holders.has(n):
				holders[n] = []
			holders[n].append(a)
			if logic.actors.has(a):
				fighters[n] = true
	var chorus := fighters.size() >= scrolls().size() and scrolls().size() > 0
	logic.set_meta("xtrumpet", {"holders": holders, "units": {}, "chorus": chorus, "members": ms})


static func finish(logic) -> void:
	if logic != null and logic.has_meta("xtrumpet"):
		logic.remove_meta("xtrumpet")


## 七号齐鸣成了没有（本场）
static func chorus(logic) -> bool:
	return _active(logic) and bool(_store(logic).chorus)


static func _has_now(logic, a, n: int) -> bool:
	return _active(logic) and (_store(logic).holders.get(n, []) as Array).has(a)


## 回合开始、排顺序之前：五号站起来（死亡线终焉下 remove_state 自己就不让起来，不算用掉）
static func turn_begin(logic) -> void:
	if not _active(logic):
		return
	for a in _store(logic).holders.get(5, []):
		if not logic.actors.has(a) or not a.state_ids.has(DEATH_STATE):
			continue
		var u := _unit(logic, a)
		if int(u.revives) >= int(_p(5, "revives", 1)):
			continue
		a.remove_state(DEATH_STATE)
		if a.state_ids.has(DEATH_STATE):
			continue
		a.hp = maxf(1.0, floorf(a.mhp * _p(5, "revive_hp", 33) / 100.0))
		u.revives = int(u.revives) + 1
		u.risen = true


## 回合开始、排顺序之后：六号第 1 回合排到所有人前面
static func start_turn(logic) -> void:
	if not _active(logic) or int(logic.turn) != 1:
		return
	var front := []
	for a in _store(logic).holders.get(6, []):
		if logic.current_order.has(a):
			while logic.current_order.has(a):
				logic.current_order.erase(a)
				front.append(a)
	for i in range(front.size() - 1, -1, -1):
		logic.current_order.push_front(front[i])


## 伤害帧（XActorDamageHooks.capture）：都进伤害加成池；四号承伤、三号受治疗是乘
static func damage_ops(item: Dictionary, a, b) -> Array:
	var logic = _logic()
	if not _active(logic) or a == null or b == null:
		return []
	var ops := []
	var type := int(item.get("damage", {}).get("type", 0))
	if type == 3:
		if b is XActor and _has_now(logic, b, 3):
			ops.append({"op": "mul", "field": "healingMultiplier", "value": maxf(0.0, 1.0 + _p(3, "heal_taken") / 100.0)})
		return ops
	if not type in [1, 5]:
		return ops
	if a is XActor and not (b is XActor):
		var fin := 0.0
		var skill: bool = not a.is_attack(item)
		var scope: int = int(item.get("scope", 0))
		if skill and _has_now(logic, a, 1):
			if AOE_SCOPES.has(scope):
				fin += _p(1, "aoe")
			elif SINGLE_SCOPES.has(scope):
				fin += _p(1, "single")
		if _has_now(logic, a, 2) and b.mhp > 0.0:
			var r: float = b.hp / b.mhp
			if r < _p(2, "low_rate", 33) / 100.0:
				fin += _p(2, "low")
			elif r > _p(2, "high_rate", 66) / 100.0:
				fin += _p(2, "high")
		if _has_now(logic, a, 5) and bool(_unit(logic, a).risen):
			fin += _p(5, "after")
		if _has_now(logic, a, 6) and int(logic.turn) >= int(_p(6, "from_turn", 6)):
			fin += _p(6, "late")
		if chorus(logic) and int(logic.turn) == 1 and logic.actors.has(a):
			fin += float(data().get("chorus", {}).get("first_turn_damage", 10))
		if fin != 0.0:
			ops.append({"op": "add", "field": "finalAdd", "value": fin / 100.0})
	if b is XActor and _has_now(logic, b, 4):
		ops.append({"op": "mul", "field": "incomingMultiplier", "value": maxf(0.0, 1.0 + _p(4, "taken") / 100.0)})
	return ops


## 暴击率（XBattleLogic.item_cri）：四号减百分点
static func cri(u, rate: float) -> float:
	var logic = _logic()
	if not _active(logic) or not _has_now(logic, u, 4):
		return rate
	return maxf(0.0, rate + _p(4, "crit") / 100.0)


## 扣血最外层（execute_hp_damage）：四号每场一次致命伤留 1 点（死期这类即死、骑士队长破保命时不管用）
static func hp_damage(logic, u, t, value: float) -> float:
	if not _active(logic) or value <= 0.0 or not (t is XActor) or not t.is_alive() or not _has_now(logic, t, 4):
		return value
	if value < t.hp + t.shield or XTianqiQiyinEffects.doom_kill or XTianqiDeathAlien.breaks_saves(logic):
		return value
	var un := _unit(logic, t)
	if int(un.saves) >= int(_p(4, "saves", 1)):
		return value
	un.saves = int(un.saves) + 1
	return maxf(0.0, t.hp + t.shield - 1.0)


## 技能消耗：六号第 1 回合不花（普攻、道具本来就不花）
static func cost(a, skill: Dictionary, c: Dictionary) -> Dictionary:
	return {"mp": 0, "tp": 0} if free_turn(a) else c


## 六号持有者自己、本场第 1 回合（天启篇战斗里、开关开着）
static func free_turn(a) -> bool:
	var logic = _logic()
	return _active(logic) and int(logic.turn) == 1 and _has_now(logic, a, 6)


## 六号「这一回合自己的技能不花消耗」覆盖全部费用（Kyo 11-14 定：真全免）：除 MP／TP（cost）外，
## HP 定值／比例（skill_hp_cost）、道具（can_pay_items／pay_items）、屠苏噬主代付、异化缄默锁生命上限、米拉禁忌生命代价、
## 饥荒线异化的口粮与透支都不检查、不扣。冷却、熟练度计次、残梦／镜流月／五条悟印这类战斗里攒的量照旧（不是费用）。
## 开关（O-待定）：FREE_ALL＝false 回到只免 MP／TP 的旧行为
static var FREE_ALL := true


static func free_all(a) -> bool:
	return FREE_ALL and free_turn(a)


## 持续伤害、持续回复（XExtDot，施加者 a）：三号 ×(1＋33%)
static func dot_value(a, value: float) -> float:
	var logic = _logic()
	if not _active(logic) or not _has_now(logic, a, 3):
		return value
	return value * (1.0 + _p(3, "over_time") / 100.0)


## 附加状态（XBattler.add_state，回合数刚掷完）：三号上的有害状态回合数 ×1.33（向上取整）
static func state_added(b, id: int, source) -> void:
	var logic = _logic()
	if not _active(logic) or id == DEATH_STATE or source == null or is_same(source, b) or not _has_now(logic, source, 3):
		return
	if not b.state_turns.has(id) or not XSmartAI.harmful_state(id):
		return
	b.state_turns[id] = int(ceilf(float(b.state_turns[id]) * (1.0 + _p(3, "over_time") / 100.0)))


## 奖励（XBattleLogic 奖励）：七号金钱 −30%（全队有人带着就算，助力位也算）
static func gold(logic, out: Dictionary) -> void:
	if not _active(logic) or (_store(logic).holders.get(7, []) as Array).is_empty():
		return
	out.gold = int(floorf(float(out.gold) * maxf(0.0, 1.0 + _p(7, "gold") / 100.0)))


## XTianqiDrop.sources_of：七号的物品掉率（写死的值，不落档）
static func drop_sources(a) -> Array:
	if not has(a, 7):
		return []
	return [{"name": str(scroll(7).name), "value": _p(7, "drop")}]
