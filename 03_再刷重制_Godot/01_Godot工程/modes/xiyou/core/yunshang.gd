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


## makeTargets 包装：学了云丝展幅的单体对敌伤害行动＝[主目标]＋其余活着的敌人（没有主目标就是全部活着的敌人）
static func targets(logic, u, skill: Dictionary, list: Array) -> Array:
	if not (own(u) and knows(u, SPREAD) and int(skill.get("scope", 0)) in [1, 3] and damage_action(skill)):
		return list
	var foes: Array = logic.alive(logic.enemies)
	if list.is_empty():
		return foes
	return [list[0]] + foes.filter(func(x): return x != list[0])


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
	if id == GIFT and (key(a) != 11 or int(data(a).get("gifts", 0)) >= 3 or not source_original(a)):
		return false
	if id == STORE and (key(a) != 9 or not source_original(a)):
		return false
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
## 天衣铺的战前设置（setting(a)：针眼、元素组、当前元素；选择界面是养成期，先用原版默认值）
static var settings := {}
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
			"release_round": -1, "cut_round": -1, "cut_values": null, "cut_choices": [], "cut_snapshot": {}, "cut_awake": false}
		_data[a] = d
	return d


static func awake(a) -> bool:
	var d := data(a)
	return not d.is_empty() and int(d.wake_until) >= round and int(d.wake_until) > 0


static func setting(a) -> Dictionary:
	if not settings.has(a):
		settings[a] = {"eye": 0, "elements": [2, 3, 4], "element": 2}
	return settings[a]


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
		if int(d.key) == 9 and awake(a):
			d.stored = mini(3, int(d.stored) + 1)
	_acted = []
	_gift_sources = {}
	var c := _cloud(logic)
	if c != null and c.is_alive() and knows(c, RANDOM):
		var sleeping: Array = logic.actors.filter(func(m): return m.is_alive() and not robe(m).is_empty() and not awake(m))
		if not sleeping.is_empty():
			wake(logic, sleeping[logic._int(0, sleeping.size() - 1, "yunshang_random_wake")])
	for a in logic.actors:
		if wind_until.has(a):
			_refresh(a)


## endTurn 包装：六衡裁身回合末清除（赊账到期、衣魂是 B 批）
static func end_turn(logic) -> void:
	for a in logic.actors:
		var d := data(a)
		if not d.is_empty() and d.cut_values != null:
			d.cut_values = null
			_refresh(a)


## endBattle 包装：清所有战斗数据
static func end_battle() -> void:
	_data.clear()
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


## Game_Actor.skills 包装：天衣给的技能（同袍换日 11 赠行、寸光留仙 9 收存余光；其余天衣的技能是 B 批）
static func skill_ids(a, ids: Array) -> Array:
	var k := key(a)
	var extra := GIFT if k == 11 else (STORE if k == 9 else 0)
	if extra != 0 and not ids.has(extra):
		ids.append(extra)
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
	frame = {"user": u, "glow": 1.0, "weaken": false, "total": 0.0, "burst": false, "command": false, "dispel": false, "planted": []}
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
	if not _acted.has(u):
		_acted.append(u)
	return logs


## Game_Action.apply 包装（原 apply 之后）：命中时的指令（御风、敕衣点神、赠行、收存余光，每次行动一次）、钉影种针、拆神驱散、
## 觉醒中的伤害引爆目标一根符针。返回派生伤害的记录
static func applied(logic, u, skill: Dictionary, t, r: Dictionary, used: bool) -> Array:
	var logs := []
	if battle == 0 or not is_same(frame.get("user"), u) or not derived_frame.is_empty():
		return logs
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
	var value := roundf(logic._damage_value(src, skill, t, critical))
	derived_frame = {}
	frame = saved_frame
	logic.gain_hp(t, -value)
	var logs := [{"type": "yunshang_derived", "user": src, "skill": skill, "target": t, "hp": value, "critical": critical, "views": logic.views([t])}]
	if t.is_dead():
		logs.append({"type": "collapse", "target": t, "views": logic.views([t])})
	return logs


## 伤害钩子 yunshang 的 split：七曜流霞（没醒用选定元素，醒了用元素组）、万法同裳觉醒（物理、魔法两路各算一次）
static func split(u, skill: Dictionary) -> Array:
	if battle == 0 or not derived_frame.is_empty() or not damage_action(skill):
		return []
	var d := data(u)
	if d.is_empty():
		return []
	var es = null
	if int(d.key) == 14:
		es = (setting(u).elements as Array).duplicate() if awake(u) else [int(setting(u).element)]
	var routes := ["magical", "physical"] if int(d.key) == 13 and awake(u) else [""]
	if es == null and routes.size() == 1:
		return []
	var parts := []
	for mode in routes:
		var o := {}
		if es != null:
			o["elements"] = es
		if mode != "":
			o["mode"] = mode  # 字符串键（o.mode 会建 StringName 键，伤害计算的模块快照不认）
		parts.append(o)
	return parts


## 伤害计算（_calculate_damage）：有 split 时按各段（元素、物理／魔法路线）各算一次再相加（CodexDamage dispatch：取整、任一段暴击算暴击）
static func calculate_split(skill: Dictionary, u, t, options: Dictionary) -> Dictionary:
	var parts := split(u, skill)
	if parts.is_empty():
		return XDamage.calculate(skill, u, t, options)
	var out := {}
	var total := 0.0
	for p in parts:
		var res := XDamage.calculate(skill, u, t, options.merged(p, true))
		if out.is_empty():
			out = res
		elif bool(res.get("critical", false)):
			out.critical = true
		total += float(res.get("value", 0.0))
	out.value = roundf(total)
	out.breakdown = {}  # 分段结果没有单一元素行：固定减伤（apply_fixed_mitigation）不再按第一段的行摊（原版各段 breakdown 存在 segments 里）
	return out
