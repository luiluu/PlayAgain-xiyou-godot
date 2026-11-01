class_name XYunshang
extends RefCounted
## 【cc·白龙_9·未经审查】174 云裳（正式 js/codex/runtime/installNativeYunshangRuntime.js，W.CodexYunshang）第一期：招募、技能同步、
## 能力值、被动缓存、公式、伤害钩子，以及只看云裳本人的战斗包装（必中、暴击、段数、目标、能不能用）。行号是该文件的。
## - 进阶次数 stage＝原版 a._AdvancedNum（XAdvance.rank）。unlocked(id)：配置 gates[id]＝[等级, 进阶]，没有就算解锁（第 43 行）。
## - 同步 Y.sync（第 51～56 行，包在 setup、levelUp、changeLevel 之后）：gates 里 10270～10281 与天衣铺 10287 解锁就学、没解锁就忘；
##   10282～10286（山河击、换锦、赠行、收存余光、符针结算）是天衣给的技能，不在这里学。
## - 能力值（第 57～70 行，Game_Actor.param 整个换掉、调旧链）：最大生命／魔攻／敏捷按等级与进阶 ×1.5（25 级）／2（30）／2.5（35 且进阶≥1）／
##   3（40 且≥1）／4（50 且≥2），取整、夹 [下限, 上限]。战斗内的六衡裁身、万法同裳、借来的能力、御风敏捷 ×1.33 是第二期。
## - 被动缓存（第 267～274 行，refreshPassiveCache 包装）：学了云丝展幅 10276 时 n＝min(99,等级)−24（≥0），暴伤 +1.88n、终伤 +0.1888n；
##   戴织神天梭 7935 另加终伤 3。
## - 公式 CodexYunshang.formula(this,a,b)（第 275～283 行）：pin 66.66、cut 111.88 ×max(0,魔攻−防×0.1)，gather 246.21×max(0,魔攻−防×0.05)×觉醒回合数，
##   山河击 888.88×max(0,物防＋魔防−防×0.1)，符针 33.33×max(0,魔攻−防×0.1)；防在 CodexDamage 计算中为 0，计算外取目标魔防（物理路线取物防，第二期）。
##   觉醒回合数（_yunGatherRounds）、符针记下的魔攻、_yunRaw 都来自第二期的觉醒与派生伤害，第一期为 0／本人魔攻／无。
## - 伤害钩子 yunshang 的 build（第 765～773 行）：云裳的伤害行动（伤害类型 1／2／5／6）定魔法；学了双针并行 10277 技能倍率 ×0.555；
##   学了云丝展幅且单体行动、目标不是主目标 _yunPrimary 时 ×0.77（银针织阵 10278）／0.66（双针）／0.5；主目标＝startAction 包装里
##   makeTargets 后的第一个目标（第 394 行，重制在 targets_for 末尾记，见 primary）；戴织神天梭时技能结算 ×1.99。split／enter、六衡与万法同裳的 categoryMax、
##   符针与灯的倍率是第二期。原版 makeDamageValue 整个换掉的那层（第 309～329 行）被后装的 installDamageElementRuntime 整个换掉、不调旧链，
##   不生效，同黄泉／宿傩不移植（山河击取暴伤／终伤下限那段也在里面）。
## - 战斗（第 252～265 行）：云裳的伤害技能 itemHit 1、itemEva 0；戴织神天梭时会暴击的行动暴击率 +3（夹到 1）；学了双针并行时伤害行动段数 ×2；
##   学了云丝展幅时单体对敌伤害行动打主目标再打其余活着的敌人（每个按段数重复）；能不能用：没解锁的不能用，敕衣点神 10273 要有活着的出战成员穿天衣，
##   收针 10274 要有人觉醒（觉醒是第二期，第一期一直不能用）。
## - 招募 Y.recruit（第 206 行）：入队、同步；本档第一次招募时背包得一件织神天梭（只进背包，不装）；提示「云裳已加入队伍」。
##   原版进阶次数取订单账本（独立文件，天衣铺进阶才会变），重制进阶次数本来就在存档里，不另设；账本、订单、天衣铺是养成期。
## 第二期：觉醒、赊账、幽灵、借技能、赠行／储行、拆段、符针、御风、天衣各件的战斗效果、自动战斗。
const ACTOR := 174
const RELIC := 7935
const ROBE_FIRST := 7920
const ROBE_END := 7935  # 不含
const PIN := 10270
const CUT := 10271
const WAKE := 10273
const GATHER := 10274
const SPREAD := 10276
const DOUBLE := 10277
const SILVER := 10278
const MOUNTAIN := 10282
const EXCHANGE := 10283
const NEEDLE := 10286
const SHOP := 10287
const WIND := 10272
const RANDOM := 10275
const FORMATION := 10279
const SEAMLESS := 10281
const GIFT := 10284
const STORE := 10285
## 配置 transferDebuffs／shareBuffs（第 5 行；异化另把 statePairs 的诅咒与腐蚀加进 transferDebuffs，见 transfer_debuffs）
const TRANSFER_DEBUFFS := [5, 6, 7, 8, 9, 10, 17, 18, 19, 20, 21, 29, 30, 33, 37, 77, 87, 93, 100, 107, 118, 124, 126, 127, 131, 151, 178, 184, 185, 192,
	234, 263, 268, 296, 318, 320, 333, 412, 474, 487, 491, 511, 513, 522, 552, 600, 636, 701, 722, 723, 724, 725, 726, 727, 728, 729, 730, 742, 778, 797,
	799, 817, 918, 919, 920, 921, 922, 923, 924, 925, 926, 941, 1011, 1014, 1015, 1016, 1019, 1055, 1095, 1101, 1102, 1119, 1129, 1131, 1135, 1319, 1646,
	1650, 1654, 1755, 2503, 2504, 2505, 2506, 2507, 2508, 2509, 2510, 2511, 2512, 2513, 2580]
const SHARE_BUFFS := [43, 55, 64, 65, 72, 78, 82, 92, 113, 117, 119, 123, 130, 158, 162, 166, 168, 174, 193, 194, 205, 207, 209, 211, 215, 222, 230,
	232, 237, 248, 267, 271, 273, 276, 287, 327, 380, 472, 519, 525, 531, 557, 565, 576, 592, 593, 619, 624, 626, 628, 635, 645, 688, 689, 803, 805, 806,
	807, 808, 828, 829, 834, 933, 953, 1013, 1017, 1027, 1046, 1303, 1304, 1321, 1598, 1606, 1619, 1620, 1655, 2517, 2628, 2629]
const RECRUIT_TEXT := "云裳已加入队伍"
const RECRUITED_FLAG := "_codexYunshangRecruited"
const GATES := {10270: [1, 0], 10271: [10, 0], 10272: [20, 0], 10273: [35, 1], 10274: [50, 2], 10275: [35, 1], 10276: [25, 0], 10277: [30, 0],
	10278: [35, 1], 10279: [40, 1], 10280: [45, 1], 10281: [55, 2], 10282: [1, 0], 10283: [1, 0], 10284: [1, 0], 10285: [1, 0], 10286: [1, 0], 10287: [20, 0]}
const COEFFICIENTS := {PIN: 66.66, CUT: 111.88, GATHER: 246.21, NEEDLE: 33.33, MOUNTAIN: 888.88}
## robeDamageCoefficients：山河作骨 bank、赊月偿星 debt 转附加伤害的倍率（Y.storedDamage）
const STORED := {"bank": 188.88, "debt": 188.88}


static func own(a) -> bool:
	return a is XActor and int(a.actor_id) == ACTOR


static func stage(a) -> int:
	return XAdvance.rank(XState.current, ACTOR) if own(a) else 0


static func unlocked(a, id: int) -> bool:
	var g = GATES.get(id)
	return g == null or int(a.level) >= int(g[0]) and stage(a) >= int(g[1])


static func knows(a, id: int) -> bool:
	return a != null and a.skill_ids.has(id)


## robe(a)：身上第一件天衣（本体 7920～7934），没有为空
static func robe(a) -> Dictionary:
	if not a is XActor:
		return {}
	for e in a.equip_list():
		var b := int(e.get("base", e.get("id", 0)))
		if b >= ROBE_FIRST and b < ROBE_END:
			return e
	return {}


static func key(a) -> int:
	var r := robe(a)
	return int(r.get("base", r.get("id", 0))) - ROBE_FIRST if not r.is_empty() else -1


static func relic(a) -> bool:
	return own(a) and a.has_base_equip("armor", RELIC)


## 伤害行动（damageAction）：伤害类型 1／2／5／6；派生伤害（第二期）不算
static func damage_action(item: Dictionary) -> bool:
	return int(item.get("damage", {}).get("type", 0)) in [1, 2, 5, 6]


static func for_one(item: Dictionary) -> bool:
	return int(item.get("scope", 0)) in [1, 3, 7, 9, 11]


static func sync(a) -> void:
	if not own(a):
		return
	for id in GATES:
		if id >= MOUNTAIN and id != SHOP:
			continue
		if unlocked(a, id):
			a.learn_skill(id)
		else:
			a.forget_skill(id)
	a.refresh_passive()


static func param(a, i: int, v: float) -> float:
	if not own(a):
		return v
	if i in [0, 4, 6]:
		var lv := int(a.level)
		var st := stage(a)
		var m := 1.0
		if lv >= 25: m = 1.5
		if lv >= 30: m = 2.0
		if lv >= 35 and st >= 1: m = 2.5
		if lv >= 40 and st >= 1: m = 3.0
		if lv >= 50 and st >= 2: m = 4.0
		v *= m
	return v  # 包装末尾的取整夹值对所有角色都做，在 XActor.final_clamp（哪吒 dev.246），这里不重复


static func passive_cache(a, c: Dictionary) -> void:
	if not own(a):
		return
	var n := maxi(0, mini(99, int(a.level)) - 24) if knows(a, SPREAD) else 0
	c.critHarmRi += n * 1.88
	c.globalHarmRi += n * 0.1888 + (3.0 if relic(a) else 0.0)


## CodexYunshang.formula(this,a,b)；calculating＝CodexDamage.isCalculating()（伤害计算里防为 0）
static func formula(a, b, item: Dictionary, calculating := true) -> float:
	var id := int(item.get("id", 0))
	var defense := 0.0 if calculating else float(b.mdf)
	var v := 0.0
	match id:
		PIN, CUT:
			v = COEFFICIENTS[id] * maxf(0.0, a.mat - defense * 0.1)
		NEEDLE:
			v = COEFFICIENTS[id] * maxf(0.0, float(derived_frame.get("mat", a.mat)) - defense * 0.1)  # action._yunNeedleMat||a.mat
		GATHER:
			v = COEFFICIENTS[id] * maxf(0.0, a.mat - defense * 0.05) * gather_rounds
		MOUNTAIN:
			v = COEFFICIENTS[id] * maxf(0.0, a.def + a.mdf - defense * 0.1)
	if derived_frame.has("raw"):
		v = float(derived_frame.raw)  # action._yunRaw（山河 bank、赊账 debt 的附加伤害）
	return maxf(0.0, v)

## 收针的觉醒回合数（action._yunGatherRounds，prepare 时按所选觉醒者算好）
static var gather_rounds := 0


## 主目标（action._yunPrimary）：云裳每次 makeTargets（targets_for）后记第一个目标；apply 包装（第 408 行）没记时取第一个打到的，重制的行动都先过 targets_for
static var primary = null


static func set_primary(u, list: Array) -> void:
	if own(u):
		primary = list[0] if not list.is_empty() else null


static func damage_ops(item: Dictionary, a, b) -> Array:
	var ops := []
	var derived := not derived_frame.is_empty()
	var mine: bool = not derived and is_same(frame.get("user"), a)
	if own(a) and damage_action(item) and not derived:
		ops.append({"op": "set", "field": "mode", "value": "magical"})
		if knows(a, DOUBLE):
			ops.append({"op": "mul", "field": "skillMultiplier", "value": 0.555})
		if knows(a, SPREAD) and for_one(item) and b != primary:
			ops.append({"op": "mul", "field": "skillMultiplier", "value": 0.77 if knows(a, SILVER) else (0.66 if knows(a, DOUBLE) else 0.5)})
	if relic(a) and not XBattleLogic.is_item(item) and int(item.get("damage", {}).get("type", 0)) > 0:
		ops.append({"op": "mul", "field": "settlementMultiplier", "value": 1.99 * (float(frame.get("glow", 1.0)) if mine else 1.0)})
	if derived:
		ops.append({"op": "mul", "field": "skillMultiplier", "value": float(derived_frame.get("rate", 1.0)) * float(derived_frame.get("glow", 1.0))})
	if mine and bool(frame.get("weaken", false)):
		ops.append({"op": "mul", "field": "incomingMultiplier", "value": 0.67})
	if key(a) == 13:
		ops.append({"op": "set", "field": "categoryMax", "value": true})
	return ops


## itemHit 1／itemEva 0：云裳的伤害技能
static func sure(u, skill: Dictionary) -> bool:
	return own(u) and not XBattleLogic.is_item(skill) and int(skill.get("damage", {}).get("type", 0)) > 0


## itemCri 包装：戴织神天梭、行动会暴击时 +3（夹 0～1）
static func cri(u, skill: Dictionary, n: float) -> float:
	return clampf(n + 3.0, 0.0, 1.0) if relic(u) and bool(skill.get("damage", {}).get("critical", false)) else n


## numRepeats 包装：学了双针并行的伤害行动 ×2
static func repeats(u, skill: Dictionary, n: int) -> int:
	return n * 2 if own(u) and knows(u, DOUBLE) and damage_action(skill) else n


## makeTargets 包装：学了云丝展幅的单体对敌伤害行动＝[主目标]＋其余活着的敌人（没有主目标就是全部活着的敌人）；
## 千军入袖收袖（第 265 行，本次行动 frame.sleeve）：对敌全体（scope 2），或云裳学了云丝展幅的伤害行动，记下全部活着的对手
## （_yunSleeveTargets，伤害按他们各算一次相加，见 split），目标收成 smoothTarget 那一个（段数照外层重复）
static func targets(logic, u, skill: Dictionary, list: Array, chosen = null) -> Array:
	var out := list
	if own(u) and knows(u, SPREAD) and int(skill.get("scope", 0)) in [1, 3] and damage_action(skill):
		var foes: Array = logic.alive(logic.enemies)
		out = foes if list.is_empty() else [list[0]] + foes.filter(func(x): return x != list[0])
	if battle != 0 and is_same(frame.get("user"), u) and bool(frame.get("sleeve", false)) \
			and (int(skill.get("scope", 0)) == 2 or own(u) and knows(u, SPREAD) and damage_action(skill)):
		var opp: Array = logic.alive(logic.enemies if u is XActor else logic.actors)
		frame.sleeve_targets = opp.duplicate()
		var t = chosen if chosen != null and opp.has(chosen) else (opp[0] if not opp.is_empty() else null)
		out = [t] if t != null else []
	return out


## meetsSkillConditions 包装：没解锁的不能用；敕衣点神要有活着的出战成员穿天衣；收针要有人觉醒（第二期，现恒否）
static func meets(a, skill: Dictionary, logic) -> bool:
	if XBattleLogic.is_item(skill):
		return true
	var id := int(skill.get("id", 0))
	if own(a) and not unlocked(a, id):
		return false
	if id == WAKE and not logic.actors.any(func(m): return m.is_alive() and not robe(m).is_empty()):
		return false
	if id == GATHER and not logic.actors.any(func(m): return awake(m)):
		return false
	if id == GIFT and (key(a) != 11 or int(data(a).get("gifts", 0)) >= 3 or not source_original(a) or int(data(a).get("ghost", 0)) > 0):
		return false
	if id == STORE and (key(a) != 9 or not source_original(a) or int(data(a).get("ghost", 0)) > 0):
		return false
	if key(a) == 6 and not knows(a, id):  # 空袖藏星（第 253 行）：借来的技能要排在可借的前几个、主人在出战且会、可借
		var choices: Array = setting(a).borrow
		for i in choices.size():
			if int(choices[i].skill) != id:
				continue
			var owner = _borrow_owner(int(choices[i].owner))
			if i >= (3 if awake(a) else 1) or owner == null or not knows(owner, id) or not borrowable(skill):
				return false
			break
	return true


## Y.recruit：入队、同步；本档第一次得一件织神天梭（只进背包）
static func recruit(s: XState) -> void:
	s.add_actor(ACTOR)
	sync(s.actor(ACTOR))
	if not bool(s.flags.get(RECRUITED_FLAG, false)):
		s.gain_gear("armor", RELIC, 1)
		s.flags[RECRUITED_FLAG] = true


# ---- 第二期 A 批：战斗内（觉醒、收针、余辉、符针、御风、赠行／储行、六衡裁身、万法同裳、七曜流霞）----
## round＝原版 round（startBattle 为 1，每回合 startTurn 后＝max(1, 敌群回合数)，endBattle 归 0）；battle＝本场编号（0＝不在战斗）。
## 各表按战斗者对象记（原版挂在 actor 上的 _yunBattle／_yunWindUntil／_yunAfterglow／_yunGiftReceived／_yunActionSource、敌人的 _yunNeedles／_yunPinUntil）。
static var round := 0
static var battle := 0
static var _battle_seq := 0
static var _round_start := -1
static var _data := {}
static var _acted := []
static var _gift_sources := {}
static var source := {}
static var afterglow := {}
static var wind_until := {}
static var gift_received := {}
static var needles := {}
static var pin_until := {}
## 天衣铺的战前设置（setting(a)）：没有当前存档时（单元测试）放这里；有存档时进 flags（见 setting）
static var settings := {}
const SETTINGS_FLAG := "_yunSettings"
## 当前主动行动（原版记在 Game_Action 上）：user、prepared、glow（余辉）、weaken（钉影虚弱）、total（本次扣血）、
## burst／command／dispel（每次行动一次）、planted（已种针的目标）
static var frame := {}
## 派生伤害（符针 derived）：mat、rate、glow；不空时伤害钩子按派生算
static var derived_frame := {}
## 收针选的觉醒者（原版选择窗 onSkillOk 写 action._yunWakeTarget）：下一次收针用，空就照自动战斗 aiGather 选
static var wake_target = null


static func data(a) -> Dictionary:
	var r := robe(a)
	if r.is_empty():
		return {}
	var uid := str(r.get("instanceId", "native:%d" % int(r.get("base", 0))))
	var d = _data.get(a)
	if d == null or d.uid != uid or int(d.battle) != battle:
		d = {"uid": uid, "battle": battle, "key": key(a), "wake_until": 0, "stored": 0, "gifts": 0, "free_gift_round": -1,
			"release_round": -1, "cut_round": -1, "cut_values": null, "cut_choices": [], "cut_snapshot": {}, "cut_awake": false,
			"bank": 0.0, "debts": [], "captured": [], "ghost": 0, "ghost_done": 0, "ghost_used": false, "ghost_expires": 0, "revived": false,
			"clone_round": -1, "debt_conversion": false, "exchange_charge": false, "guard_until": 0, "lamp_round": -1,
			"needle_used": false, "needle_other": [], "needle_bypass_round": -1}
		_data[a] = d
	return d


static func awake(a) -> bool:
	var d := data(a)
	return not d.is_empty() and int(d.wake_until) >= round and int(d.wake_until) > 0


## setting(a)（第 220 行）：天衣铺的战前设置，按身上那件天衣存（原版 a._yunSettings[_yunUid 或 native:id]，随角色进存档）：
## 借用技能 borrow [{owner, skill}]、针眼 eye、七曜元素组 elements 与当前元素 element。重制存进 flags._yunSettings[角色号][天衣]（读档后数字是浮点，读的地方都取 int）
static func setting(a) -> Dictionary:
	var r := robe(a)
	var uid := str(r.get("instanceId", "native:%d" % int(r.get("base", 0)))) if not r.is_empty() else "undefined"
	var box: Dictionary
	if XState.current != null and a is XActor:
		var all: Dictionary = XState.current.flags.get_or_add(SETTINGS_FLAG, {})
		box = all.get_or_add(str(a.actor_id), {})
	else:
		box = settings.get_or_add(a, {})
	if not box.has(uid):
		box[uid] = {"borrow": [], "eye": 0, "elements": [2, 3, 4], "element": 2}
	return box[uid]


static func source_original(a) -> bool:
	return not str(source.get(a, "original")) in ["gift", "stored"]


static func transfer_debuffs() -> Array:
	var out := TRANSFER_DEBUFFS.duplicate()
	for v in XAlienation.templates().get("statePairs", {}).values():
		if not out.has(int(v)):
			out.append(int(v))
	if not out.has(XAlienBattle.corrosion_id()):
		out.append(XAlienBattle.corrosion_id())
	return out


static func _cloud(logic) -> XActor:
	for m in logic.actors:
		if own(m):
			return m
	return null


## Y.wake：没醒的唤醒到下一回合末；首次唤醒时六衡裁身按觉醒重裁；戴织神天梭的云裳在场时给余辉。异化绝缘（外来）挡掉
static func wake(logic, a) -> bool:
	if XAlienBattle._insulated(a):
		return false
	var d := data(a)
	if d.is_empty() or a.is_dead():
		return false
	var fresh := not awake(a)
	d.wake_until = maxi(int(d.wake_until), round + 1)
	if fresh:
		d.debt_conversion = true
		d.exchange_charge = true
		if int(d.key) == 7 and int(setting(a).eye) > 0:
			a.cooldowns.erase(int(setting(a).eye))  # 九曲回针：觉醒那一刻清针眼冷却
	if fresh and int(d.key) == 8 and int(d.cut_round) == round:
		cut(a, d.cut_choices)
	var c := _cloud(logic)
	if c != null and relic(c):
		afterglow[c] = true
	_refresh(a)
	return true


static func _refresh(a) -> void:
	a.param_mark_dirty()
	a.param_refresh()


## startBattle 包装（原 startBattle 之后）：新一场、round 1；清出战成员的战斗数据、御风、余辉再建；同步云裳；天衣无缝全醒
static func start_battle(logic) -> void:
	_battle_seq += 1
	battle = _battle_seq
	round = 1
	_round_start = -1
	_acted = []
	_gift_sources = {}
	needles = {}
	pin_until = {}
	source = {}
	frame = {}
	for a in logic.actors:
		_data.erase(a)
		wind_until.erase(a)
		afterglow.erase(a)
		data(a)
	var c := _cloud(logic)
	if c != null:
		sync(c)
		if c.is_alive() and knows(c, SEAMLESS):
			for a in logic.actors:
				if not robe(a).is_empty():
					wake(logic, a)


## startTurn 包装（原 startTurn 之后，每回合一次）：resetRound
static func start_turn(logic) -> void:
	if battle == 0 or _round_start == int(logic.turn):
		return
	_round_start = int(logic.turn)
	round = maxi(1, int(logic.turn))
	for a in logic.actors:
		gift_received[a] = 0
		var d := data(a)
		if d.is_empty():
			continue
		d.gifts = 0
		d.lamp_round = -1
		d.needle_other = []
		if int(d.key) == 9 and awake(a):
			d.stored = mini(3, int(d.stored) + 1)
	_acted = []
	_gift_sources = {}
	lamp_shared = []
	var c := _cloud(logic)
	if c != null and c.is_alive() and knows(c, RANDOM):
		var sleeping: Array = logic.actors.filter(func(m): return m.is_alive() and not robe(m).is_empty() and not awake(m))
		if not sleeping.is_empty():
			wake(logic, sleeping[logic._int(0, sleeping.size() - 1, "yunshang_random_wake")])
	for a in logic.actors:
		if wind_until.has(a):
			_refresh(a)


## endTurn 包装：到期的债扣生命、衣魂过期倒下、六衡裁身回合末清除
static func end_turn(logic) -> void:
	for a in logic.actors:
		var d := data(a)
		if d.is_empty():
			continue
		var due := 0.0
		var rest := []
		for x in d.debts:
			if int(x.due) <= round:
				due += float(x.amount)
			else:
				rest.append(x)
		d.debts = rest
		if due > 0.0:
			logic.gain_hp(a, -due)
		if int(d.ghost) > 0 and round >= int(d.ghost_expires):
			end_ghost(logic, a, d)
		if d.cut_values != null:
			d.cut_values = null
			_refresh(a)


## endBattle 包装：结清赊账、结束衣魂，再清所有战斗数据
static func end_battle(logic = null) -> void:
	if logic != null and battle != 0:
		for a in logic.actors:
			var d: Dictionary = _data.get(a, {})
			if d.is_empty() or int(d.battle) != battle:
				continue
			settle_debt(logic, a, d)
			if int(d.ghost) > 0:
				end_ghost(logic, a, d)
	pending.clear()
	exchange_pick = null
	lamp_shared = []
	team_buff = false
	_data.clear()
	borrow_stats.clear()
	element_round.clear()
	wind_until.clear()
	afterglow.clear()
	gift_received.clear()
	needles.clear()
	pin_until.clear()
	source.clear()
	_gift_sources.clear()
	_acted.clear()
	frame = {}
	derived_frame = {}
	wake_target = null
	battle = 0
	round = 0


## getNextSubject 包装：角色这次行动的来源（赠行／储行的标签按入队先后取）
static func took(b) -> void:
	if b is XActor and battle != 0:
		var tags: Array = _gift_sources.get(int(b.actor_id), [])
		source[b] = str(tags.pop_front()) if not tags.is_empty() else "original"


## Game_Battler 的 param 包装里战斗内那几层（所有角色）：六衡裁身改值、万法同裳物攻／魔攻取高、御风敏捷 ×1.33
static var _pair_guard := false
static func battle_param(a, i: int, v: float) -> float:
	if battle == 0 or not a is XActor:
		return v
	var d := data(a)
	if not d.is_empty() and int(d.cut_round) == round and d.cut_values != null and i >= 2 and i <= 7:
		if bool(d.cut_awake) != awake(a):
			cut(a, d.cut_choices)
		v = float(d.cut_values[i])
	if not d.is_empty() and int(d.key) == 13 and i in [2, 4] and not _pair_guard:
		_pair_guard = true
		v = maxf(v, a.param(4 if i == 2 else 2))
		_pair_guard = false
	if borrow_stats.has(a) and i in [2, 4]:
		v = maxf(v, float(borrow_stats[a].get(i, 0.0)))  # 空袖藏星：醒着用借来的技能时物攻／魔攻至少取主人的
	if i == 6 and int(wind_until.get(a, -1)) >= round:
		v *= 1.33
	return v


## Y.cut（六衡裁身）：选一项（觉醒两项，不够自动补第一个没选的），按本回合快照把其余各项的 33% 裁入；没醒时其余 ×0.67
static func cut(a, choices: Array) -> bool:
	var d := data(a)
	if d.is_empty() or int(d.key) != 8 or choices.is_empty():
		return false
	var pair := awake(a)
	var selected: Array = choices.slice(0, 2 if pair else 1)
	if pair and selected.size() < 2:
		selected.append([2, 3, 4, 5, 6, 7].filter(func(i): return i != int(selected[0]))[0])
	var snap: Dictionary = d.cut_snapshot if int(d.cut_round) == round and not (d.cut_snapshot as Dictionary).is_empty() else {}
	if int(d.cut_round) != round:
		d.cut_values = null
		_refresh(a)
		for i in range(2, 8):
			snap[i] = a.param(i)
	var sum := 0.0
	for j in range(2, 8):
		if not selected.has(j):
			sum += float(snap[j]) * 0.33
	var values := {}
	for k in range(2, 8):
		values[k] = float(snap[k]) + sum if selected.has(k) else (float(snap[k]) if pair else float(snap[k]) * 0.67)
	d.cut_snapshot = snap
	d.cut_choices = selected
	d.cut_values = values
	d.cut_round = round
	d.cut_awake = pair
	_refresh(a)
	return true


## Game_Actor.skills 包装：天衣给的技能（山河作骨 0 山河击、逆命换锦 4 换锦、同袍换日 11 赠行、寸光留仙 9 收存余光；空袖藏星 6 借技能是下一期）
static func skill_ids(a, ids: Array) -> Array:
	var k := key(a)
	var extra: int = {0: MOUNTAIN, 4: EXCHANGE, 11: GIFT, 9: STORE}.get(k, 0)
	if extra != 0 and not ids.has(extra):
		ids.append(extra)
	if k == 6:  # 空袖藏星（第 248 行）：天衣铺设的借用技能，没醒取前 1 个、醒取前 3 个；主人在出战且会、可借
		for r in (setting(a).borrow as Array).slice(0, 3 if awake(a) else 1):
			var owner = _borrow_owner(int(r.owner))
			var sid := int(r.skill)
			if owner != null and knows(owner, sid) and not ids.has(sid) and borrowable(XDB.rec("Skills", sid)):
				ids.append(sid)
	return ids


## OTB 队列加行动（Y.addActions）：带来源标签；不在出战或倒下的不加；异化绝缘（外来）挡掉
static func add_actions(logic, a, count: int, tag: String) -> bool:
	if a.is_dead() or not logic.actors.has(a) or XAlienBattle._insulated(a):
		return false
	var q: Array = logic.current_order
	var pending := q.count(a)
	var tags: Array = _gift_sources.get(int(a.actor_id), [])
	_gift_sources[int(a.actor_id)] = tags
	while tags.size() < pending:
		tags.append("original")
	for i in range(count):
		q.append(a)
		tags.append(tag)
	return true


## Y.freeGift（同袍换日觉醒）：每回合一次免费赠队友 2 次行动；同一接收者每回合最多 2 次；异化绝缘挡掉
static func free_gift(logic, a, t) -> bool:
	var d := data(a)
	if d.is_empty() or int(d.key) != 11 or not awake(a) or int(d.free_gift_round) == round or a == t or t == null or t.is_dead() \
			or not logic.actors.has(t) or int(gift_received.get(t, 0)) >= 2 or XAlienBattle.has(t, "insulation"):
		return false
	d.free_gift_round = round
	gift_received[t] = 2
	return add_actions(logic, t, 2, "gift")


## Y.storeActions（收存余光）：队列里自己剩下的原有行动收起（最多 3 份），再多存 1 份
static func store_actions(logic, a) -> bool:
	var d := data(a)
	if d.is_empty() or int(d.key) != 9 or not source_original(a):
		return false
	var tags: Array = _gift_sources.get(int(a.actor_id), [])
	var used := 0
	var remaining := []
	var kept := []
	var idx := 0
	for b in logic.current_order:
		if b != a:
			remaining.append(b)
			continue
		var tag := str(tags[idx]) if idx < tags.size() else "original"
		idx += 1
		if tag == "original" and int(d.stored) < 3:
			d.stored = int(d.stored) + 1
			used += 1
		else:
			remaining.append(a)
			kept.append(tag)
	if int(d.stored) < 3:
		d.stored = int(d.stored) + 1
		used += 1
	_gift_sources[int(a.actor_id)] = kept
	logic.current_order.assign(remaining)
	return used > 0


## Y.release（放行）：每回合一次，把储存的行动加回队列（觉醒时每份 2 次）
static func release(logic, a) -> bool:
	var d := data(a)
	if d.is_empty() or int(d.key) != 9 or int(d.release_round) == round or int(d.stored) == 0:
		return false
	var count := int(d.stored) * (2 if awake(a) else 1)
	d.stored = 0
	d.release_round = round
	return add_actions(logic, a, count, "stored")


## aiGather：觉醒剩余回合最多的、不是自己的优先，再按队伍顺序
static func _gather_holder(logic, u):
	var holders: Array = logic.actors.filter(func(t): return t.is_alive() and awake(t))
	holders.sort_custom(func(x, y):
		if int(data(x).wake_until) != int(data(y).wake_until):
			return int(data(x).wake_until) > int(data(y).wake_until)
		if (x == u) != (y == u):
			return y == u
		return logic.actors.find(x) < logic.actors.find(y))
	return holders[0] if not holders.is_empty() else null


## prepareAction（startAction 包装，原 startAction 之前）：敌人行动前引爆身上全部符针、带钉影的伤害行动虚弱；
## 云裳的余辉；收针取所选觉醒者的剩余回合并消耗觉醒。返回派生伤害的记录（行动者因此倒下时整次行动取消，见 battle_logic）
static func prepare(logic, u, skill: Dictionary) -> Array:
	var logs := []
	frame = {}
	if battle == 0 or skill.is_empty():
		return logs
	frame = {"user": u, "glow": 1.0, "weaken": false, "total": 0.0, "burst": false, "command": false, "dispel": false, "planted": [], "hits": [],
		"robe_hit": false, "bank": 0.0, "debt": 0.0, "finished": false}
	if u is XEnemy:
		logs.append_array(burst(logic, u, true))
		if int(pin_until.get(u, -1)) >= round and damage_action(skill):
			frame.weaken = true
			pin_until.erase(u)
	if u.is_dead():
		return logs
	if own(u) and damage_action(skill) and bool(afterglow.get(u, false)):
		frame.glow = 1.33
		afterglow[u] = false
	if int(skill.get("id", 0)) == GATHER and not XBattleLogic.is_item(skill):
		var t = wake_target if wake_target != null else _gather_holder(logic, u)
		wake_target = null
		gather_rounds = 0
		if t != null and awake(t):
			gather_rounds = int(data(t).wake_until) - round + 1
			data(t).wake_until = 0
			_refresh(t)
	var d := data(u)
	if int(d.get("key", -1)) == 0 and int(skill.get("id", 0)) == MOUNTAIN and not XBattleLogic.is_item(skill):
		frame.bank = float(d.bank)
		d.bank = 0.0
		d.guard_until = round + 1
	if int(d.get("key", -1)) == 2 and awake(u) and bool(d.debt_conversion) and damage_action(skill):
		frame.debt = debt_total(d)
	frame.sleeve = bool(sleeve.get(u, false))  # action._yunSleeve（指令窗或自动战斗设的收袖开关）
	var sid := int(skill.get("id", 0)) if not XBattleLogic.is_item(skill) else 0
	if int(d.get("key", -1)) == 6 and awake(u) and sid > 0:
		for b in setting(u).borrow:
			if int(b.skill) == sid:
				var owner = _borrow_owner(int(b.owner))
				if owner != null:
					borrow_stats[u] = {2: float(owner.atk), 4: float(owner.mat)}
					_refresh(u)
				break
	if eye_bypass(u, skill):  # 九曲回针：醒着每回合一次越过冷却（付费前清掉，付费再照常进冷却）
		d.needle_bypass_round = round
		u.cooldowns.erase(sid)
	if not _acted.has(u):
		_acted.append(u)
	team_buff = int(skill.get("scope", 0)) in [8, 10]  # startAction 包装：对友方全体的行动
	return logs


## Game_Action.apply 包装（原 apply 之后）：命中时的指令（御风、敕衣点神、赠行、收存余光，每次行动一次）、钉影种针、拆神驱散、
## 觉醒中的伤害引爆目标一根符针。返回派生伤害的记录
static func applied(logic, u, skill: Dictionary, t, r: Dictionary, used: bool) -> Array:
	var logs := pending.duplicate()
	pending.clear()
	if battle == 0 or not is_same(frame.get("user"), u) or not derived_frame.is_empty():
		return logs
	if not frame.has("primary"):
		frame.primary = primary if own(u) else t  # action._yunPrimary
	if damage_action(skill):
		frame.total = float(frame.total) + maxf(0.0, float(r.get("hp", 0.0)))
	if not used or bool(r.get("missed", false)) or bool(r.get("evaded", false)):
		return logs
	var id := int(skill.get("id", 0)) if not XBattleLogic.is_item(skill) else 0
	if not bool(frame.command):
		frame.command = true
		_command(logic, u, id, t)
	if own(u) and id == PIN and not (frame.planted as Array).has(t):
		(frame.planted as Array).append(t)
		var count := 3 if knows(u, FORMATION) else (2 if knows(u, SILVER) else 1)
		var rate := 0.4 if count == 3 else (0.555 if count == 2 else 1.0)
		var parts := 2 if knows(u, DOUBLE) else 1
		var spread := 1.0 if t == primary else (0.77 if knows(u, SILVER) else (0.66 if knows(u, DOUBLE) else 0.5))
		if not needles.has(t):
			needles[t] = []
		for i in range(count):
			(needles[t] as Array).append({"mat": u.mat, "parts": parts, "rate": rate * (0.555 if parts == 2 else 1.0) * spread, "glow": float(frame.glow)})
		pin_until[t] = round + 1
	if own(u) and id == CUT and not bool(frame.dispel):
		frame.dispel = true
		_dispel(logic, t)
	if damage_action(skill) and awake(u) and float(frame.total) > 0.0 and not bool(frame.burst):
		frame.burst = true
		logs.append_array(burst(logic, t, false))
	var d := data(u)
	if not d.is_empty() and damage_action(skill) and not bool(frame.robe_hit) and float(frame.total) > 0.0:
		frame.robe_hit = true
		logs.append_array(_robe_hit(logic, u, d))
	if o_sleeve_overflow and frame.has("sleeve_targets") and not d.is_empty() and awake(u) and id > 0 and t.hp <= 0.0 and float(r.get("hp", 0.0)) > 0.0:
		# 千军入袖觉醒（第 422 行）：打倒目标时溢出量（这段伤害−打前生命）依次传给其余活着的敌人
		var overflow := maxf(0.0, float(r.hp) - float(frame.get("hp_before", 0.0)))
		for e in logic.alive(logic.enemies).filter(func(x): return x != t and x.hp > 0.0):
			if overflow <= 0.0:
				break
			var before: float = e.hp
			logs.append_array(derived(logic, u, e, id, {"damage": overflow}))
			overflow = maxf(0.0, overflow - before)
	return logs


## 天衣命中（每次伤害行动一次）：百厄成锦 1 把收录的减益转给主目标（醒：全部敌人）；赊月偿星 2 觉醒时把债转成符针附加伤害；山河作骨 0 山河击取 bank 转附加伤害
static func _robe_hit(logic, u, d: Dictionary) -> Array:
	var logs := []
	var target = frame.get("primary")
	if int(d.key) == 1 and not (d.captured as Array).is_empty():
		var enemies: Array = logic.alive(logic.enemies) if awake(u) else [target]
		var pending_states := []
		for s in d.captured:
			var ok := false
			for e in enemies:
				ok = state_copy(logic, u, e, int(s.id), s.turns) or ok
			if awake(u) or ok:
				logic._state_remove(u, int(s.id))
			else:
				pending_states.append(s)
		d.captured = pending_states
	if int(d.key) == 2 and float(frame.debt) > 0.0:
		var n := float(frame.debt)
		d.debt_conversion = false
		repay(d, n)
		logs.append_array(derived(logic, u, target, NEEDLE, {"raw": n * STORED.debt, "kind": "debt"}))
		frame.debt = 0.0
	if int(d.key) == 0 and float(frame.bank) > 0.0:
		logs.append_array(derived(logic, u, target, MOUNTAIN, {"raw": float(frame.bank) * STORED.bank, "kind": "bank"}))
		frame.bank = 0.0
	return logs


static func _command(logic, u, id: int, t) -> void:
	if id == WIND:
		for m in logic.actors:
			wind_until[m] = round + 1
			_refresh(m)
		var allies: Array = logic.current_order.filter(func(x): return x is XActor and not _acted.has(x))
		allies.sort_custom(func(x, y): return x.agi > y.agi)
		var rest: Array = logic.current_order.filter(func(x): return not allies.has(x))
		logic.current_order.assign(allies + rest)
	elif id == WAKE:
		wake(logic, t)
	elif id == GIFT:
		data(u).gifts = int(data(u).gifts) + 1
		add_actions(logic, t, 1, "gift")
	elif id == STORE:
		store_actions(logic, u)
	elif id == EXCHANGE:
		_exchange(logic, u, t)


## 换锦（逆命换锦 4）：觉醒后第一次（每次觉醒一次）全队普通减益转给全部敌人、夺敌人最多 3 个普通增益给全队；
## 否则自己的一个减益与目标的一个增益互换（原版战斗里的选择窗，重制 exchange_pick＝[自己的减益, 目标的增益]，不给就照自动战斗：各取第一个）
static func _exchange(logic, u, t) -> void:
	var d := data(u)
	var bad_ids := transfer_debuffs()
	if awake(u) and bool(d.exchange_charge):
		d.exchange_charge = false
		var bad := {}
		for x in logic.actors:
			for i in x.state_ids:
				if bad_ids.has(int(i)) and not bad.has(int(i)):
					bad[int(i)] = x
		var good := {}
		for x in logic.alive(logic.enemies):
			for i in x.state_ids:
				if SHARE_BUFFS.has(int(i)) and not good.has(int(i)) and good.size() < 3:
					good[int(i)] = x
		var bk: Array = bad.keys()
		bk.sort()  # JS Object.keys：整数键按数值升序
		for i in bk:
			var ok := false
			for x in logic.alive(logic.enemies):
				ok = state_copy(logic, bad[i], x, i) or ok
			if ok:
				for x in logic.actors:
					logic._state_remove(x, i)
		var gk: Array = good.keys()
		gk.sort()
		for i in gk:
			var ok := false
			for x in logic.actors:
				ok = state_copy(logic, good[i], x, i) or ok
			if ok:
				for x in logic.alive(logic.enemies):
					logic._state_remove(x, i)
		return
	var pick = exchange_pick
	exchange_pick = null
	if pick == null:
		var mine_list: Array = u.state_ids.filter(func(i): return bad_ids.has(int(i)))
		var theirs_list: Array = t.state_ids.filter(func(i): return SHARE_BUFFS.has(int(i)))
		pick = [int(mine_list[0]) if not mine_list.is_empty() else 0, int(theirs_list[0]) if not theirs_list.is_empty() else 0]
	var mine := int(pick[0])
	var theirs := int(pick[1])
	if mine != 0 and u.state_ids.has(mine) and state_copy(logic, u, t, mine):
		logic._state_remove(u, mine)
	if theirs != 0 and t.state_ids.has(theirs) and state_copy(logic, t, u, theirs):
		logic._state_remove(t, theirs)


## 拆神：去掉目标第一个普通增益；成功时队伍（醒着的先）里第一个有普通减益的去掉一个
static func _dispel(logic, t) -> void:
	var allowed: Array = t.state_ids.filter(func(i): return SHARE_BUFFS.has(int(i)))
	if allowed.is_empty():
		return
	logic._state_remove(t, int(allowed[0]))
	var team: Array = logic.actors.duplicate()
	var ranked := []
	for m in team:
		if awake(m):
			ranked.append(m)
	for m in team:
		if not awake(m):
			ranked.append(m)
	var bad_ids := transfer_debuffs()
	for m in ranked:
		var bad: Array = m.state_ids.filter(func(i): return bad_ids.has(int(i)))
		if not bad.is_empty():
			logic._state_remove(m, int(bad[0]))
			break


## burst：引爆目标身上的符针（all＝全部，否则一根）；每根按种下时的魔攻、倍率、余辉打 parts 段符针结算（派生伤害）
static func burst(logic, t, all: bool) -> Array:
	var logs := []
	var list: Array = needles.get(t, [])
	var take := list.size() if all else mini(1, list.size())
	var src: XActor = logic.state.actor(ACTOR) if logic.state != null else null
	for i in range(take):
		var n: Dictionary = list.pop_front()
		for p in range(int(n.parts)):
			if t.is_dead():
				break
			logs.append_array(derived(logic, src, t, NEEDLE, {"mat": n.mat, "rate": n.rate, "glow": n.glow}))
	return logs


## derived：派生伤害（不是主动行动：不判命中、不触发云裳的双针／展幅、不种针）；暴击照 itemCri 掷，伤害走伤害计算后直接扣血
static func derived(logic, src, t, skill_id: int, o: Dictionary) -> Array:
	if src == null or t == null or t.is_dead():
		return []
	var skill := XDB.rec("Skills", skill_id)
	var saved_frame := frame
	derived_frame = o
	frame = {}
	var base_cri: float = src.cri * (1.0 - t.cev) if bool(skill.get("damage", {}).get("critical", false)) else 0.0
	var critical: bool = logic._float("yunshang_derived_critical") < clampf(cri(src, skill, base_cri), 0.0, 1.0)
	var value := 0.0
	if o.has("damage"):
		value = roundf(float(o.damage))  # 一身两世复演：照每段命中的数值，不再计算
	else:
		# 山河 bank／赊账 debt（_yunStoredKind）直接调 nativeDamage，那段的符文下限在这条路上生效：被动缓存的暴伤、终伤至少取
		# offensiveGrowth（n＝min(99,等级)−24：暴伤 1.88n、终伤 0.1888n），算完还原（山河击本身与反击走后装的 makeDamageValue，不经这段）
		var cache: Dictionary = src.passive_cache() if o.has("kind") else {}
		var saved := [cache.get("critHarmRi", 0.0), cache.get("globalHarmRi", 0.0)]
		if o.has("kind"):
			var g := maxf(0.0, mini(99, int(src.level)) - 24.0)
			cache.critHarmRi = maxf(float(saved[0]), g * 1.88)
			cache.globalHarmRi = maxf(float(saved[1]), g * 0.1888)
		value = logic._damage_value(src, skill, t, critical)
		if o.has("kind"):
			cache.critHarmRi = saved[0]
			cache.globalHarmRi = saved[1]
		if o.has("raw") and relic(src):
			value *= 1.99  # nativeDamage(raw) 之外另乘（伤害钩子里戴梭的 ×1.99 照算）
		value = roundf(value)
	derived_frame = {}
	frame = saved_frame
	logic.gain_hp(t, -value)
	var logs := [{"type": "yunshang_derived", "user": src, "skill": skill, "target": t, "hp": value, "critical": critical, "views": logic.views([t])}]
	if t.is_dead():
		logs.append({"type": "collapse", "target": t, "views": logic.views([t])})
	return logs


## 伤害钩子 yunshang 的 split：七曜流霞（没醒用选定元素，醒了用元素组）、万法同裳觉醒（物理、魔法两路各算一次）
## 千军入袖收袖（第 752 行）：对 _yunSleeveTargets 每个目标各算一次（"_target"，取各自的防御、元素抗性，公式也按各自求值）
static func split(u, skill: Dictionary) -> Array:
	if battle == 0 or not derived_frame.is_empty() or not damage_action(skill):
		return []
	var d := data(u)
	if d.is_empty():
		return []
	var es = null
	if int(d.key) == 14:
		es = (setting(u).elements as Array).map(func(e): return int(e)) if awake(u) else [int(setting(u).element)]
	var routes := ["magical", "physical"] if int(d.key) == 13 and awake(u) else [""]
	var sleeved: Array = frame.get("sleeve_targets", []) if is_same(frame.get("user"), u) else []
	if es == null and routes.size() == 1 and sleeved.size() <= 1:
		return []
	var parts := []
	for t in (sleeved if not sleeved.is_empty() else [null]):
		for mode in routes:
			var o := {}
			if t != null:
				o["_target"] = t
			if es != null:
				o["elements"] = es
			if mode != "":
				o["mode"] = mode  # 字符串键（o.mode 会建 StringName 键，伤害计算的模块快照不认）
			parts.append(o)
	return parts


## 伤害计算（_calculate_damage）：有 split 时按各段（元素、物理／魔法路线、收袖的各目标）各算一次再相加（CodexDamage dispatch：取整、任一段暴击算暴击）。
## 收袖的段对别的目标时公式按那个目标重新求值（raw_for，原版 compute 每段 evalDamageFormula(p.target)）；打到的目标那段沿用已算好的
static func calculate_split(skill: Dictionary, u, t, options: Dictionary, raw_for := Callable()) -> Dictionary:
	var parts := split(u, skill)
	if parts.is_empty():
		return XDamage.calculate(skill, u, t, options)
	var out := {}
	var total := 0.0
	for p in parts:
		var pt = p.get("_target", t)
		var o := options.merged(p, true)
		o.erase("_target")
		if pt != t and raw_for.is_valid():
			o["rawValue"] = raw_for.call(pt)
		var res := XDamage.calculate(skill, u, pt, o)
		if out.is_empty():
			out = res
		elif bool(res.get("critical", false)):
			out.critical = true
		total += float(res.get("value", 0.0))
	out.value = roundf(total)
	out.breakdown = {}  # 分段结果没有单一元素行：固定减伤（apply_fixed_mitigation）不再按第一段的行摊（原版各段 breakdown 存在 segments 里）
	return out


# ---- 第二期 B 批前一半：状态复制、赊账（2 赊月偿星）、衣魂（3 不渡黄泉）、山河作骨 0、百厄成锦 1、逆命换锦 4、一身两世 12 ----
## 派生伤害的记录里没法当场返回的（敌人打山河作骨守势者时的反击）：下一次 applied 带出去
static var pending := []
## 换锦的选择（原版选择窗写 action._yunExchangeSelf／_yunExchangeEnemy）：[自己的减益, 目标的增益]，用一次就清
static var exchange_pick = null
static var _transferring := 0
## 孤灯照众：本回合醒着的灯已共享过的增益（Y._lampShared）；全体增益技能施放中（Y._teamBuffApplying）
static var lamp_shared := []
static var team_buff := false
## O-135：stateCopy 的来源身上没有这个状态时（一身两世复演复制技能附加的状态），原版把回合数写成 undefined，
## 这个状态在回合末永不到期（只等战斗结束或被驱散）。true＝保留附加时掷出的回合数；false＝照原版永不按回合到期
static var o_copy_turns := true
const NEVER_EXPIRES := 1 << 30


static func ghost(a) -> bool:
	return battle != 0 and int(data(a).get("ghost", 0)) > 0


static func debt_total(d: Dictionary) -> float:
	var n := 0.0
	for x in d.get("debts", []):
		n += float(x.amount)
	return n


## repay：按记债先后还 n
static func repay(d: Dictionary, n: float) -> void:
	for x in d.debts:
		if n <= 0.0:
			break
		var pay := minf(n, float(x.amount))
		x.amount = float(x.amount) - pay
		n -= pay
	d.debts = (d.debts as Array).filter(func(x): return float(x.amount) > 0.0)


## settleDebt：一次扣完全部债
static func settle_debt(logic, a, d: Dictionary) -> void:
	var total := debt_total(d)
	d.debts = []
	if total > 0.0:
		logic.gain_hp(a, -total)


## endGhost：衣魂结束，生命归 0、倒下
static func end_ghost(logic, a, d: Dictionary) -> void:
	d.ghost = 0
	d.ghost_ending = true
	logic.gain_hp(a, -a.hp)
	logic._die(a)
	d.erase("ghost_ending")


## Game_Actor.addState 包装（原 addState 之前）的阵亡那段与 die 包装 ghostDie：不渡黄泉 3 每场首次倒下不阵亡，留衣魂 2 次行动（生命 1，到下一回合末）；
## 衣魂期间不再阵亡。返回真＝这次不加阵亡状态
static func ghost_death(a, id: int) -> bool:
	if battle == 0 or id != 1:
		return false
	var d := data(a)
	if d.is_empty() or int(d.key) != 3 or d.has("ghost_ending"):
		return false
	if not bool(d.ghost_used):
		d.ghost_used = true
		d.ghost = 2
		d.ghost_done = 0
		d.ghost_expires = round + 1
		a.hp = 1.0
		return true
	return int(d.ghost) > 0


## stateAdded 包装（原 addState 之后，新附加的状态）：百厄成锦 1 收录普通减益（没醒 3 个、醒 6 个；醒着当场去掉）；
## 孤灯照众 10 共享普通增益（有醒着的穿戴者时，任何队员新得的、每回合最多 3 种；没醒的穿戴者自己每回合第一次新得的），全体增益技能施放中不共享。
## 原版也包在 Game_Battler.addState 上，但敌人得到的增益参照里不共享（p4.lamp），所以只接角色
static func state_added(a, id: int, had: bool) -> void:
	if battle == 0 or had or _transferring > 0 or not a.state_ids.has(id):
		return
	var d := data(a)
	if SHARE_BUFFS.has(id) and not team_buff:
		var logic = XAlienBattle.active_logic()
		var lamps: Array = logic.actors.filter(func(x): return key(x) == 10 and awake(x)) if logic != null else []
		var use: bool = not lamps.is_empty() and not lamp_shared.has(id) and lamp_shared.size() < 3
		if not use and int(d.get("key", -1)) == 10 and not awake(a) and int(d.lamp_round) != round:
			d.lamp_round = round
			use = true
		if use and logic != null:
			if not lamps.is_empty():
				lamp_shared.append(id)
			for m in logic.actors:
				if m != a:
					state_copy(logic, a, m, id)
	if d.is_empty() or int(d.key) != 1 or not transfer_debuffs().has(id):
		return
	var cap := 6 if awake(a) else 3
	if (d.captured as Array).size() < cap and not (d.captured as Array).any(func(x): return int(x.id) == id):
		d.captured.append({"id": id, "turns": a.state_turns.get(id), "cleaned": awake(a)})
		if awake(a):
			var logic = XAlienBattle.active_logic()
			if logic != null:
				logic._state_remove(a, id)


## stateCopy：异化支援帧里（来源＝from）给 to 附加 id，回合数照 turns（不给就照 from 身上的）；腐蚀同步层数
static func state_copy(logic, from, to, id: int, turns = null) -> bool:
	if to == null or to.is_dead() or to.traits_set(XBattler.TRAIT_STATE_RESIST).has(id) or logic.state_rate(to, id) <= 0.0:
		return false
	_transferring += 1
	XAlienBattle._support(to, from, func(): logic._state_add(to, id))
	if to.state_ids.has(id):
		if turns == null:
			turns = from.state_turns.get(id)
		if turns != null:
			to.state_turns[id] = int(turns)
		elif not o_copy_turns:
			to.state_turns[id] = NEVER_EXPIRES
		if id == XAlienBattle.corrosion_id():
			XAlienBattle.sync_corrosion(to)
	_transferring -= 1
	return to.state_ids.has(id)


## executeHpDamage 包装（原扣血之前）：山河作骨 0 觉醒者替出战队友分担 33%（记进 bank，上限最大生命 ×3）；赊月偿星 2 把 50% 记成债（债总额上限最大生命 ×2，到期＝下一回合末）
static func hp_damage(logic, _u, t, value: float) -> float:
	if battle != 0 and derived_frame.is_empty() and is_same(frame.get("user"), _u):
		frame.hp_before = t.hp  # executeDamage 包装：action._yunHpBefore（千军入袖溢出用）
	if battle == 0 or value <= 0.0:
		return value
	if t is XActor and logic.actors.has(t):
		var guards: Array = logic.actors.filter(func(x): return x != t and x.is_alive() and key(x) == 0 and awake(x))
		if not guards.is_empty():
			var total := floorf(value * 0.33)
			var each := floorf(total / guards.size())
			var remainder := total - each * guards.size()
			value -= total
			for i in guards.size():
				var g = guards[i]
				var take := each + (remainder if i == 0 else 0.0)
				var before: float = g.hp
				logic.gain_hp(g, -take)
				data(g).bank = minf(g.mhp * 3.0, float(data(g).bank) + minf(before, take))
	var d := data(t)
	if int(d.get("key", -1)) == 2:
		var delay := minf(floorf(value * 0.5), maxf(0.0, t.mhp * 2.0 - debt_total(d)))
		if delay > 0.0:
			d.debts.append({"amount": delay, "due": round + 1})
			value -= delay
	return value


## executeHpDamage 包装（原扣血之后）：记主动伤害行动的每段命中（一身两世复演用）；山河作骨守势中被敌人打，反击一次山河击 ×0.5
static func after_hp(logic, u, t, value: float, item: Dictionary) -> void:
	if battle == 0:
		return
	if derived_frame.is_empty() and is_same(frame.get("user"), u) and damage_action(item):
		(frame.hits as Array).append({"target": t, "value": value, "critical": bool(logic._action_resources.result(t).get("critical", false))})
	var d := data(t)
	if int(d.get("key", -1)) == 0 and int(d.guard_until) >= round and int(d.guard_until) > 0 and derived_frame.is_empty() and u is XEnemy and value > 0.0:
		d.guard_until = 0
		pending.append_array(derived(logic, t, u, MOUNTAIN, {"rate": 0.5}))


## finishAction（endAction 包装，原 endAction 之前）：赊月偿星 2 用伤害还债 33%；一身两世 12 复演（每回合一次，醒着每次 2 遍）；衣魂计次（赠行、收存余光不算）
static func finish(logic, u, skill) -> Array:
	var logs := []
	team_buff = false
	if borrow_stats.has(u):  # delete a._yunBorrowStats
		borrow_stats.erase(u)
		_refresh(u)
	if battle == 0 or skill == null or not skill is Dictionary or skill.is_empty():
		return logs
	var d := data(u)
	if d.is_empty():
		return logs
	var id := int(skill.get("id", 0))
	var mine: bool = is_same(frame.get("user"), u) and not bool(frame.get("finished", true))  # 防御不走 prepare（见交付单），没有本次行动的帧
	if mine:
		frame.finished = true
	var dmg := mine and damage_action(skill)
	if int(d.key) == 7 and (mine or id == XBattleLogic.GUARD_SKILL) and not XBattleLogic.is_item(skill):  # 防御不走 prepare，也算一次别的技能
		var eye := int(setting(u).eye)
		if id == eye:
			d.needle_used = true
		elif bool(d.needle_used) and (d.needle_other as Array).size() < 3 and not (d.needle_other as Array).has(id):
			(d.needle_other as Array).append(id)  # 九曲回针：用过针眼后，别的技能（每回合最多 3 种）各让针眼冷却 −1
			var left := maxf(0.0, float(u.cooldowns.get(eye, 0.0)) - 1.0)
			if left > 0.0:
				u.cooldowns[eye] = left
			else:
				u.cooldowns.erase(eye)
	if int(d.key) == 2 and dmg:
		repay(d, float(frame.total) * 0.33)
	if int(d.key) == 12 and dmg and (awake(u) or int(d.clone_round) != round):
		var clones := 2 if awake(u) else 1
		d.clone_round = round
		var foes: Array = logic.enemies if u is XActor else logic.actors
		for n in clones:
			for h in frame.hits:
				var t = h.target if h.target.is_alive() else (logic.alive(foes)[0] if not logic.alive(foes).is_empty() else null)
				if t == null:
					continue
				logs.append_array(derived(logic, u, t, id, {"damage": h.value}))
				for e in skill.get("effects", []):
					if int(e.code) == 21 and (transfer_debuffs().has(int(e.dataId)) or SHARE_BUFFS.has(int(e.dataId))) and logic._float("yunshang_clone_state") < float(e.value1):
						state_copy(logic, u, t, int(e.dataId))
	if int(d.ghost) > 0 and not (not XBattleLogic.is_item(skill) and id in [GIFT, STORE]):
		d.ghost = int(d.ghost) - 1
		d.ghost_done = int(d.ghost_done) + 1
		if awake(u) and int(d.ghost_done) >= 2 and not bool(d.revived):
			d.revived = true
			d.ghost = 0
			u.hp = floorf(u.mhp * 0.5)
			u.mp = floorf(u.mmp * 0.5)
		elif int(d.ghost) <= 0:
			end_ghost(logic, u, d)
	return logs


# ---- 第二期 B 批后一半：千军入袖 5、空袖藏星 6、九曲回针 7（孤灯照众 10 见 state_added）----
## 千军入袖的收袖开关（原版 a._yunSleeve：指令窗「收袖」切换，自动战斗设为开）；每次行动 prepare 时抄进 frame.sleeve
static var sleeve := {}
## O-135：千军入袖觉醒的溢出（第 422 行）要 !live(target)，可原版行动中目标有 YEP IMMORTAL（行动序列 immortal: targets, true），
## 生命到 0 也不倒下，溢出从来不触发，打倒目标后剩下的段照样打在它身上。true＝目标生命到 0 就算打倒、溢出照写的传给其余敌人；
## false＝照原版（不传）
static var o_sleeve_overflow := true
## 空袖藏星：醒着用借来的技能时主人的物攻／魔攻（a._yunBorrowStats，prepare 记、finish 清）
static var borrow_stats := {}
static var _borrow_res := []


## 借用技能的主人：在出战（members()＝battleMembers；不取 XState.battle_members，它会整队）
static func _borrow_owner(owner_id: int):
	var s := XState.current
	if s == null or not s.party.has(owner_id) or not s.battle_slots.has(owner_id):
		return null
	return s.actor(owner_id)


## Y.borrowable（第 249 行）：普通技能才能借（编号在云裳技能之前、不是不能用的场合、不是被动类别 4；备注、公式、名字的排除；
## 不带特殊效果 43／44，附加／解除状态 21／22 只许普通增减益）
static func borrowable(s: Dictionary) -> bool:
	if s.is_empty() or int(s.get("id", 0)) >= PIN or int(s.get("occasion", 0)) == 3 or int(s.get("stypeId", 0)) == 4:
		return false
	if _borrow_res.is_empty():
		_borrow_res = [RegEx.create_from_string("(?i)<(?:Custom|Passive|SkillKill|SkillFrUse|Switch|Variable|Actor|req_|MagicWeapon)"),
			RegEx.create_from_string("Codex|\\$game|\\ba\\._|\\bb\\._|\\ba\\.[A-Za-z]+\\s*\\("),
			RegEx.create_from_string("形态|领域|觉醒|进阶|制作|唤醒|召唤|复活|变身|解放|无限|天与")]
	if _borrow_res[0].search(str(s.get("note", ""))) != null or _borrow_res[1].search(str(s.get("damage", {}).get("formula", ""))) != null \
			or _borrow_res[2].search(str(s.get("name", ""))) != null:
		return false
	var bad := transfer_debuffs()
	for e in s.get("effects", []):
		var code := int(e.get("code", 0))
		var sid := int(e.get("dataId", 0))
		if code in [43, 44] or code in [21, 22] and not bad.has(sid) and not SHARE_BUFFS.has(sid):
			return false
	return true


## 九曲回针（第 254 行）：醒着、这是针眼、本回合还没越过——能不能用时不看冷却（预热照看）
static func eye_bypass(a, skill: Dictionary) -> bool:
	if not a is XActor or XBattleLogic.is_item(skill) or battle == 0:
		return false
	var d := data(a)
	return int(d.get("key", -1)) == 7 and int(setting(a).eye) == int(skill.get("id", 0)) and int(setting(a).eye) > 0 \
		and awake(a) and int(d.needle_bypass_round) != round


# ---- 自动战斗（第 448～505、541 行）：智能 AI 档案 registerProfile、估算器 CodexAIEstimators、makeAutoBattleActions 包装 ----
## 原版另包了 Game_Action.evaluate（关掉智能 AI 时的原生自动战斗估值）；重制关掉智能 AI 时自动战斗直接普通攻击（XBattleLogic.auto_battle_action），那层用不上，不移植
const AI_FORMULA := "CodexYunshang.formula(this,a,b)"


## aiBattle：本场、同一件天衣的战斗数据（不新建）
static func _ai_data(a) -> Dictionary:
	var r := robe(a)
	var d = _data.get(a)
	if r.is_empty() or d == null or d.uid != str(r.get("instanceId", "native:%d" % int(r.get("base", 0)))) or int(d.battle) != battle:
		return {}
	return d


static func _ai_awake(a) -> bool:
	var d := _ai_data(a)
	return not d.is_empty() and int(d.wake_until) > 0 and int(d.wake_until) >= round


## aiGather：收针会选的觉醒者（剩余回合多的先，同样多时行动者自己排后，再按队伍顺序）
static func _ai_gather(logic, u):
	var holders: Array = logic.actors.filter(func(t): return t.is_alive() and _ai_awake(t))
	var best = null
	for t in holders:
		if best == null:
			best = t
			continue
		var dt := int(_ai_data(t).wake_until) - int(_ai_data(best).wake_until)
		if dt > 0 or dt == 0 and (best == u and t != u or (t == u) == (best == u) and logic.actors.find(t) < logic.actors.find(best)):
			best = t
	return best


## CodexAIEstimators（第 470 行）：云裳公式的五个伤害技能，防取 0（统一伤害另算防御），收针按 aiGather 选的觉醒者回合数；不适用返回 null
static func ai_raw(logic, a, t, rec: Dictionary):
	var id := int(rec.get("id", 0))
	if XBattleLogic.is_item(rec) or str(rec.get("damage", {}).get("formula", "")) != AI_FORMULA or not id in [PIN, CUT, GATHER, MOUNTAIN, NEEDLE]:
		return null
	var saved := gather_rounds
	gather_rounds = 0
	if id == GATHER:
		var h = _ai_gather(logic, a)
		gather_rounds = maxi(0, int(_ai_data(h).wake_until) - round + 1) if h != null else 0
	var v := formula(a, t, rec, true)
	gather_rounds = saved
	return v


## aiAccept／aiExchange：普通增减益、对方能附加；换锦会换的一对（自己的减益、目标的增益，对方身上已有的不算）
static func _ai_accept(logic, to, id: int) -> bool:
	return (transfer_debuffs().has(id) or SHARE_BUFFS.has(id)) and to != null and to.is_alive() \
		and not to.traits_set(XBattler.TRAIT_STATE_RESIST).has(id) and logic.state_rate(to, id) > 0.0


static func _ai_exchange(logic, a, t) -> Array:
	var bad := transfer_debuffs()
	var mine := 0
	var theirs := 0
	for id in a.state_ids:
		if bad.has(int(id)) and not t.state_ids.has(id) and _ai_accept(logic, t, int(id)):
			mine = int(id)
			break
	for id in t.state_ids:
		if SHARE_BUFFS.has(int(id)) and not a.state_ids.has(id) and _ai_accept(logic, a, int(id)):
			theirs = int(id)
			break
	return [mine, theirs]


## aiOutput：会用的伤害技能（含普通攻击）对各敌人 safeDamage 的最大值
static func _ai_output(ai, a, foes: Array) -> float:
	var best := 0.0
	for s in a.skills() + [a.attack_skill()]:
		if not int(s.get("damage", {}).get("type", 0)) in [1, 5] or not ai.logic.can_use(a, s):
			continue
		for t in foes:
			best = maxf(best, ai.safe_damage(a, t, s))
	return best


## registerProfile（第 476～505 行）：云裳的伤害技能（双针 ×0.555、戴梭 ×1.99、余辉再 ×1.33、展幅溅射）、天衣的倍率（一身两世 12、万法同裳 13），
## 敕衣点神／御风／换锦／赠行／储行的目标限制与收益。回调都是 (目标, 情境, XSmartAI)；不是云裳、也不是天衣给的技能返回空
static func ai_profile(a, rec: Dictionary) -> Dictionary:
	var id := 0 if XBattleLogic.is_item(rec) else int(rec.get("id", 0))
	var cloud := own(a)
	if not cloud and not id in [MOUNTAIN, EXCHANGE, GIFT, STORE]:
		return {}
	var offense := damage_action(rec)
	var d := _ai_data(a)
	var p := {}
	var mult := 1.0
	if cloud and offense:
		if knows(a, DOUBLE):
			mult *= 0.555
		if relic(a):
			mult *= 1.99 * (1.33 if bool(afterglow.get(a, false)) else 1.0)
		if knows(a, SPREAD):
			p.splash = 0.77 if knows(a, SILVER) else (0.66 if knows(a, DOUBLE) else 0.5)
	if offense and not d.is_empty():
		var logic = XAlienBattle.active_logic()
		var active: bool = _ai_awake(a) and not (id == GATHER and logic != null and _ai_gather(logic, a) == a)
		if int(d.key) == 12:
			mult *= 3.0 if active else (1.0 if int(d.clone_round) == round else 2.0)
		if int(d.key) == 13 and active:
			mult *= 2.0
	p.multiplier = mult
	if id == WAKE:
		p.targetAllowed = func(t, _c, _ai): return t.is_alive() and not robe(t).is_empty() and not _ai_awake(t)
		p.targetUtility = func(t, c, _ai):
			if not bool(c.longFight):
				return 0.0
			var td := _ai_data(t)
			return 12500.0 if bool(c.urgent) and not td.is_empty() and int(td.key) in [0, 3] else 6500.0
	elif id == WIND:
		p.targetUtility = func(_t, c, ai):
			if not bool(c.longFight) or int(wind_until.get(a, -1)) >= round:
				return 0.0
			var q: Array = ai.logic.current_order
			var first := -1
			for i in q.size():
				if q[i] is XEnemy:
					first = i
					break
			for i in q.size():
				if first >= 0 and i > first and q[i] is XActor and q[i] != a and not _acted.has(q[i]):
					return 5500.0 / maxf(1.0, (c.friends as Array).filter(func(f): return f.is_alive()).size())
			return 0.0
	elif id == EXCHANGE:
		p.targetUtility = func(t, c, ai):
			var pair := _ai_exchange(ai.logic, a, t)
			var count := int(pair[0] != 0) + int(pair[1] != 0)
			if not d.is_empty() and _ai_awake(a) and bool(d.exchange_charge):
				var bad := {}
				var good := {}
				var ids := transfer_debuffs()
				for f in (c.friends as Array).filter(func(x): return x.is_alive()):
					for sid in f.state_ids:
						if ids.has(int(sid)) and (c.foes as Array).any(func(e): return not e.state_ids.has(sid) and _ai_accept(ai.logic, e, int(sid))):
							bad[int(sid)] = true
				for e in c.foes:
					for sid in e.state_ids:
						if SHARE_BUFFS.has(int(sid)) and (c.friends as Array).any(func(f): return not f.state_ids.has(sid) and _ai_accept(ai.logic, f, int(sid))):
							good[int(sid)] = true
				count = bad.size() + mini(3, good.size())
			return count * 8500.0 * (1.0 if bool(c.longFight) else 0.15)
		p.prepareTarget = func(t, _c, ai): exchange_pick = _ai_exchange(ai.logic, a, t)  # action._yunExchangeSelf／_yunExchangeEnemy
	elif id == GIFT:
		p.targetAllowed = func(t, _c, _ai): return t.is_alive() and t != a
		p.targetUtility = func(t, c, ai):
			var mine := _ai_output(ai, a, c.foes)
			var theirs := _ai_output(ai, t, c.foes)
			return minf(18000.0, 5500.0 * theirs / maxf(1.0, mine)) * (1.0 if bool(c.longFight) else 0.1) if theirs > mine else 0.0
	elif id == STORE:
		# 储行要牺牲这次行动：存满不再存，已经打得到人时不拖
		p.targetUtility = func(_t, c, ai):
			return 4500.0 if not d.is_empty() and int(d.stored) < 3 and bool(c.longFight) and _ai_output(ai, a, c.foes) == 0.0 else 0.0
	return p


## makeAutoBattleActions 包装（第 541 行，原 makeAutoBattleActions 之后）：觉醒的同袍换日免费赠给双攻最高的队友（每人最多受赠 2）、
## 寸光留仙放行、六衡裁身选（魔攻≥物攻 ? 魔攻＋敏捷 : 物攻＋敏捷）、千军入袖开收袖。收针选觉醒者（aiGather）与 prepare 没选时的默认相同，不另记
static func auto_battle(logic, a) -> void:
	var d := data(a)
	if d.is_empty():
		return
	if int(d.key) == 11 and awake(a):
		var best = null
		for t in logic.actors:
			if t != a and t.is_alive() and int(gift_received.get(t, 0)) < 2 and (best == null or t.atk + t.mat > best.atk + best.mat):
				best = t
		if best != null:
			free_gift(logic, a, best)
	if int(d.key) == 9:
		release(logic, a)
	if int(d.key) == 8 and int(d.cut_round) != round:
		cut(a, [4, 6] if a.mat >= a.atk else [2, 6])
	if int(d.key) == 5:
		sleeve[a] = true


# ---- 界面一期：战斗指令窗（第 534～538 行）----
## 七曜流霞本回合选过元素（a._yunElementChosenRound）
static var element_round := {}


## Window_ActorCommand.makeCommandList 包装（原列表之后、种族血契之前）：同袍换日觉醒时「神纹赠行（免费）」、寸光留仙「释放余光」、
## 六衡裁身、千军入袖「收袖：开启／关闭」、七曜流霞「选择七曜元素」。返回 [{text, key, enabled}]
static func command_entries(a) -> Array:
	var d := data(a)
	if d.is_empty():
		return []
	var out := []
	var k := int(d.key)
	if k == 11 and awake(a):
		out.append({"text": "神纹赠行（免费）", "key": "yunGift", "enabled": int(d.free_gift_round) != round and int(d.ghost) <= 0})
	if k == 9:
		out.append({"text": "释放余光", "key": "yunRelease", "enabled": int(d.stored) > 0 and int(d.release_round) != round and int(d.ghost) <= 0})
	if k == 8:
		out.append({"text": "六衡裁身", "key": "yunCut", "enabled": int(d.cut_round) != round})
	if k == 5:
		out.append({"text": "收袖：开启" if bool(sleeve.get(a, false)) else "收袖：关闭", "key": "yunSleeve", "enabled": true})
	if k == 14:
		out.append({"text": "选择七曜元素", "key": "yunElement", "enabled": int(element_round.get(a, -1)) != round})
	return out


## 赠行选人（第 535 行 yunGift）：出战里除自己外活着的，受赠满 2 次的灰显
static func gift_rows(logic, a) -> Array:
	return logic.actors.filter(func(t): return t != a and t.is_alive()).map(func(t): return {"text": t.display_name(), "target": t, "enabled": int(gift_received.get(t, 0)) < 2})


## 裁身选项（yunCut）：物攻、魔攻、物防、魔防、敏捷、运气（这个次序），去掉已选的
static func cut_rows(chosen: Array) -> Array:
	var names: Array = XDB.system().get("terms", {}).get("params", [])
	return [2, 4, 3, 5, 6, 7].filter(func(i): return not chosen.has(i)).map(func(i): return {"text": str(names[i]) if i < names.size() else "", "id": i, "enabled": true})


## 七曜元素（yunElement）：天衣铺设的元素组
static func element_rows(a) -> Array:
	var names: Array = XDB.system().get("elements", [])
	return (setting(a).elements as Array).map(func(e): return {"text": str(names[int(e)]) if int(e) < names.size() else "", "id": int(e), "enabled": true})


## 收针选人（onSkillOk）：出战里觉醒中的
static func gather_rows(logic) -> Array:
	return logic.actors.filter(func(t): return awake(t)).map(func(t): return {"text": t.display_name(), "target": t, "enabled": true})


## 换锦选状态（onSkillOk 选自己的、onEnemyOk 选目标的）：首行「不选自身状态／不选敌方状态」，再列身上的普通增减益
static func exchange_rows(b, enemy: bool) -> Array:
	var bad := transfer_debuffs()
	var out := [{"text": "不选敌方状态" if enemy else "不选自身状态", "id": 0, "enabled": true}]
	for i in b.state_ids:
		if bad.has(int(i)) or SHARE_BUFFS.has(int(i)):
			out.append({"text": str(XDB.rec("States", int(i)).get("name", "")), "id": int(i), "enabled": true})
	return out


## onSkillOk 包装：没醒的换锦要先选自己的状态（醒着的全队互换不用选）
static func exchange_needs_pick(a, skill: Dictionary) -> bool:
	return not XBattleLogic.is_item(skill) and int(skill.get("id", 0)) == EXCHANGE and not awake(a)


## onActorOk 包装：敕衣点神选的人要穿着天衣、赠行不能选自己，否则蜂鸣、留在选人
static func rejects_target(a, skill: Dictionary, t) -> bool:
	if XBattleLogic.is_item(skill):
		return false
	var id := int(skill.get("id", 0))
	return id == WAKE and (t == null or robe(t).is_empty()) or id == GIFT and t == a
