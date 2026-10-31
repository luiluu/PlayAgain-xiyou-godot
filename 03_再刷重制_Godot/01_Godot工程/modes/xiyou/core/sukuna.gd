class_name XSukuna
extends RefCounted
## 172 宿傩（正式 js/codex/runtime/installNativeSukunaRuntime.js，W.CodexSukuna）第一期：招募、技能同步、能力值／被动、公式、伤害钩子。
## - 进阶次数 rank＝原版 a._AdvancedNum（XAdvance.rank）。allowed(id)：技能备注 CodexUnlockLevel ≤ 等级、CodexUnlockRank ≤ 进阶次数，
##   有 CodexUnlockMaxRank 时进阶次数不超过它。stage：学会且允许 10245／10244／10243 → 3／2／1，否则 0。
## - 同步 S.sync（包在 setup、levelUp、changeLevel 之后，进阶确定后也调）：10229～10249（10236～10238 除外）允许就学、不允许就忘；
##   没学黑闪 10225 就学。
## - 能力值：stage 3 时八项 ×3（取整、夹上限）；xparam 命中／暴击加 stage 1／2／3 → 3／6.66／9.99；被动缓存 stage 2／3 时
##   终伤与暴伤各加 6.66／9.99（refreshPassiveCache 包装）。
## - 公式 CodexSukuna.damage(a,b,id,this)：权重 × (火术用魔攻，否则攻击) × coefficient × (1＋0.15×熟练度)，神灶：开的权重另乘准备层数（第一期 0）；CodexDamage 结算里减防项为 0
##   （防御由伤害钩子 sukuna 的物防／魔防率 ×0.5、捌 ×0.15 处理）。coefficient：没学 10247 为 88888，否则 50～上限级插值。
##   斩击另乘：适应层（战斗内，第一期 0）、捌打护盾 ×1.5、领域 ×1.3、黑闪觉醒、带伤口且戴神武解 ×1.2 等——只有护盾、伤口、神武解
##   这几项不靠战斗机制，照写；其余战斗内状态第一期恒为初值。
## - 伤害钩子 sukuna（XActorDamageHooks）：10229～10238 定物理（神灶 10232／10233 为魔法）；空间斩／次元斩（10234／10235）为真伤、
##   属性 13；其余物防率 ×0.5（捌非冲击段 ×0.15）、魔防率 ×0.5；stage 3 结算 ×1.5。
##   原版 stage 3 另包 makeDamageValue（结果 ×1.99）是死代码：installDamageElementRuntime 后装、整个换掉 makeDamageValue 不调旧链，
##   不生效（第一期曾并进钩子，第二期 sukuna_battle 参照 3 进阶各段比值证实没有，已去掉；二十指说明也只写结算 ×1.5）。
## - 招募（公共事件 9007 的 try { if (!CodexSukuna.recruit()) 还号角 }）：已在队返回 false；没戴神武解 4581 时背包有就拿、没有就生成，
##   装进装备类型 13 的槽；入队、同步；右上角提示「宿傩加入队伍，已装备神武解。」。
## 第二期（战斗内，S.begin／finish／endRound 与 Game_Action.apply 包装）：看破层数（10240，每回合每目标最多 +2、上限 3，敌人行动结束也给自己 +1）、
##   三层时主技能转空间斩／次元斩（终式：真伤、属性 13、免护盾、不触发捌冲击段，结束清层）、伤口（施放前目标≥2 层且命中→附 2637，
##   下一回合结束解除；受治疗减半在 XResourceContext.gain）、捌 10230 先打一段冲击（权重 0.3、物防 ×0.5、不算斩击）再打斩击段、
##   领域 10231（开始行动即展开 4 回合：斩击 ×1.3、回合结束对全体敌人御厨子·斩击 10237、准备层 +1 至 4，到期且会神灶就全体神灶：开，
##   之后 3 回合内不能再展开；stage≥2 时领域中解／捌 TP ×0.5）、神灶 10232 只能打被主技能命中过的目标（命中后消耗）、
##   神灶：开 10233（直接施放不结算，行动结束按准备层数对全体打）、追斩 10241（每回合一次 10236）、咒力体术 10238 命中回 20 TP、
##   魔虚罗适应 10246（被敌人主行动扣血后 +1 层至 3，斩击 ×(1＋0.05×层)）、开战 TP 至少 60、技能条件与战斗中技能列表过滤。
## 第三期：黑闪接 XBlackFlash（与甚尔共用；施放帧 emp＝觉醒时的斩击强化层，解／捌／伏魔御厨子 ×(1＋领域 0.35／否则 0.2＋0.05×(层−1))，
##   觉醒时内部神灶：开另 ×1.2，终式不判黑闪，回合结束不觉醒才清 emp）；阵亡清战斗数据（on_death）。
## 未移植：看破的闪避归零在西游无效（YEP 闪避公式为 0，照写）、applyCriticalRate 改写在 CodexDamage 下不走（原版注释：旧暴击链会重复乘），
##   无需移植；熟练度上限包装（重制熟练度恒 0）；神灶选目标窗只列已蓄力的敌人、战斗日志文字（画面车道）；技能分类与界面、外观、旧档迁移。
const ACTOR := 172
const ARMOR := 4581
const WOUND := 2637
const DOMAIN := 2636
const MAHO := 2638
const AWAKE := 2639
const RECRUIT_TEXT := "宿傩加入队伍，已装备神武解。"
const WEIGHTS := {10229: 1.0, 10230: 1.6, 10231: 1.0, 10232: 4.0, 10233: 5.4, 10234: 4.0, 10235: 7.0, 10236: 0.2, 10237: 9.0, 10238: 0.3}
const SLASH := [10229, 10230, 10231, 10234, 10235, 10236, 10237]
const PRIMARY := [10229, 10230, 10231]
const MASTERY_SOURCE := {10233: 10232, 10234: 10229, 10235: 10229, 10236: 10229, 10237: 10231, 10238: 10229}


static func own(a) -> bool:
	return a is XActor and int(a.actor_id) == ACTOR


static func rank(a) -> int:
	return XAdvance.rank(XState.current, ACTOR) if own(a) else 0


static func _meta_int(meta: Dictionary, key: String, fallback: int) -> int:
	var t := str(meta.get(key, "")).strip_edges()
	return int(t) if t.is_valid_int() and int(t) != 0 else fallback


static func allowed(a, id: int) -> bool:
	if not own(a):
		return false
	var meta: Dictionary = XDB.rec("Skills", id).get("meta", {})
	var max_rank := _meta_int(meta, "CodexUnlockMaxRank", 0)
	return int(a.level) >= _meta_int(meta, "CodexUnlockLevel", 1) and rank(a) >= _meta_int(meta, "CodexUnlockRank", 0) and (max_rank == 0 or rank(a) <= max_rank)


static func knows(a, id: int) -> bool:
	return allowed(a, id) and a.skill_ids.has(id)


static func stage(a) -> int:
	return 3 if knows(a, 10245) else (2 if knows(a, 10244) else (1 if knows(a, 10243) else 0))


static func sync(a) -> void:
	if not own(a):
		return
	for id in range(10229, 10250):
		if id in [10236, 10237, 10238]:
			continue
		if allowed(a, id):
			a.learn_skill(id)
		else:
			a.forget_skill(id)
	a.learn_skill(10225)
	a.refresh_passive()


static func coefficient(a) -> float:
	if not knows(a, 10247):
		return 88888.0
	var cap := 99 if knows(a, 10249) else (70 if knows(a, 10248) else 60)
	var level := clampi(int(a.level), 50, cap)
	var nodes := [[50, 88888], [55, 100000], [60, 111111], [70, 133333], [81, 155555], [99, 200000]]
	for i in range(1, nodes.size()):
		if level <= nodes[i][0]:
			return XPower.js_round(nodes[i - 1][1] + (nodes[i][1] - nodes[i - 1][1]) * float(level - nodes[i - 1][0]) / (nodes[i][0] - nodes[i - 1][0]))
	return 200000.0


static func artifact(a) -> bool:
	return a.equip_list().any(func(e): return int(e.get("base", e.get("id", 0))) == ARMOR)


## CodexSukuna.damage(a,b,id,this)：施放帧 cast（_sukunaCast）有终式时按终式算；part＝"impact" 是捌的冲击段
static func formula(a, b, item: Dictionary) -> float:
	var id := int(item.get("id", 0))
	if not own(a) or not WEIGHTS.has(id):
		return 0.0
	var c: Dictionary = cast
	var terminal := int(c.get("terminal", 0))
	var actual := terminal if terminal != 0 else id
	var d := temp(a)
	var dom := active_domain(a)
	var m := float(a.skillMasteryLevel(MASTERY_SOURCE.get(actual, actual)))
	var fire := actual == 10232 or actual == 10233
	var weight: float = 0.3 if part == "impact" else WEIGHTS[actual]
	if actual == 10233:
		weight *= preparation if internal else int(d.prep)  # action._sukunaPreparation || d.prep
	var value := maxf(0.0, (a.mat if fire else a.atk) * weight) * coefficient(a) * (1 + 0.15 * m)
	if slash(actual, part):
		value *= 1 + int(d.adapt) * 0.05
		if actual == 10230 and float(b.shield) > 0.0:
			value *= 1.5
		if dom and actual != 10237:
			value *= 1.3
		var emp := int(c.get("emp", 0))
		if emp > 0 and PRIMARY.has(id):
			value *= 1 + (0.35 if dom else 0.2) + (emp - 1) * 0.05
		var wounded: bool = bool(c.wounded) if not c.is_empty() else b.state_ids.has(WOUND)
		if wounded and artifact(a) and PRIMARY.has(id):
			value *= 1.2
		if actual == 10237 and stage(a) >= 2 and wounded:
			value *= 1.2
	if actual == 10233 and artifact(a):
		value *= 1.2
	if internal and actual == 10233 and XBlackFlash.status(a).awake:
		value *= 1.2  # 共用觉醒只管直接施放，内部神灶：开自己乘一次
	return value

static func param(a, i: int, v: float) -> float:
	if not own(a) or stage(a) != 3:
		return v
	return XPower.js_round(minf(a.param_max(i), v * 3))


static func xparam(a, i: int, v: float) -> float:
	if not own(a) or not (i == 0 or i == 2):
		return v
	var s := stage(a)
	return v + (0.0 if s == 0 else (9.99 if s == 3 else (6.66 if s == 2 else 3.0)))


static func passive_cache(a, c: Dictionary) -> void:
	if not own(a):
		return
	var s := stage(a)
	var v := 9.99 if s == 3 else (6.66 if s == 2 else 0.0)
	c.globalHarmRi += v
	c.critHarmRi += v


static func damage_ops(item: Dictionary, a) -> Array:
	if not own(a):
		return []
	var terminal := int(cast.get("terminal", 0))
	var id := terminal if terminal != 0 else int(item.get("id", 0))
	var ops := []
	if id >= 10229 and id <= 10238:
		ops.append({"op": "set", "field": "mode", "value": "magical" if id == 10232 or id == 10233 else "physical"})
		if true_hit(a, item):
			ops.append({"op": "set", "field": "kind", "value": "true"})
			ops.append({"op": "set", "field": "elements", "value": [13]})
		else:
			ops.append({"op": "mul", "field": "physicalDefenseRate", "value": 0.15 if id == 10230 and part != "impact" else 0.5})
			ops.append({"op": "mul", "field": "magicalDefenseRate", "value": 0.5})
	if stage(a) == 3:
		ops.append({"op": "mul", "field": "settlementMultiplier", "value": 1.5})
	return ops

## CodexSukuna.recruit()
static func recruit(s: XState) -> bool:
	if s.party.has(ACTOR):
		return false
	var a := s.actor(ACTOR)
	var slot := a.equip_slots().find(13)
	if slot < 0:
		push_error("[xiyou] 神武解装备槽不可用")
		return false
	var worn = a.equips[slot]
	if not (worn is Dictionary and int(worn.get("base", 0)) == ARMOR):
		var idx := s.gear.find_custom(func(e): return e.kind == "armor" and int(e.base) == ARMOR)
		if idx < 0:
			s.gain_gear("armor", ARMOR, 1)
			idx = s.gear.size() - 1
		var item: Dictionary = s.gear[idx]
		s.gear.remove_at(idx)
		if worn is Dictionary and not worn.is_empty():
			s.gear.append(worn)
		a.equips[slot] = item
	s.add_actor(ACTOR)
	sync(a)
	return true


# ---- 战斗内（第二期）----
## S.round：开战归 0，每次 endRound 结束 +1。cast＝当前主动行动的施放帧（_sukunaCast，S.begin 建），internal＝S.perform 的内部行动
## （_sukunaInternal：追斩、御厨子·斩击、神灶：开），preparation＝内部神灶：开的 _sukunaPreparation。
static var round := 0
static var cast := {}
static var part := ""
static var internal := false
static var preparation := 0
static var _temp := {}
static var _target := {}
static var _acting = null
static var _victim = null


static func temp(a) -> Dictionary:
	if not _temp.has(a):
		_temp[a] = {"domain": 0, "prep": 0, "available": 0, "chase": -1, "adapt": 0, "adapt_round": -1, "emp": 0}
	return _temp[a]


static func target_data(t) -> Dictionary:
	if not _target.has(t):
		_target[t] = {"layers": 0, "round": -1, "gained": 0, "charged": false, "wound_until": -1}
	return _target[t]


static func active_domain(a) -> bool:
	return int(temp(a).domain) > 0 and a.state_ids.has(DOMAIN) and a.is_alive()


static func slash(id: int, p := "") -> bool:
	return SLASH.has(id) and p != "impact"


## trueHit：宿傩的终式或空间斩／次元斩（真伤；免属性、物魔率、防御、harmRe，executeHpDamage 时护盾视为 0）
static func true_hit(a, item: Dictionary) -> bool:
	return own(a) and (int(cast.get("terminal", 0)) != 0 or int(item.get("id", 0)) in [10234, 10235])


static func _terminal(a, id: int, layers: int) -> int:
	if not PRIMARY.has(id) or layers != 3:
		return 0
	return 10235 if knows(a, 10235) else (10234 if knows(a, 10234) else 0)


static func _members(logic) -> Array:
	return logic.actors.filter(func(x): return own(x))


static func _text(text: String) -> Dictionary:
	return {"type": "battle_text", "text": text}  # BattleManager._logWindow addText（画面未接）


static func _layers(logic, t, n: int) -> void:
	var d := target_data(t)
	d.layers = clampi(n, 0, 3)
	for j in range(3):
		if t.state_ids.has(2640 + j):
			logic._state_remove(t, 2640 + j)
	if int(d.layers) > 0:
		logic._state_add(t, 2639 + int(d.layers))


static func _add_layer(logic, a, t) -> void:
	if not knows(a, 10240) or t == null or not t.is_alive():
		return
	var d := target_data(t)
	if int(d.round) != round:
		d.round = round
		d.gained = 0
	if int(d.gained) < 2 and int(d.layers) < 3:
		d.gained = int(d.gained) + 1
		_layers(logic, t, int(d.layers) + 1)


static func _wound(logic, t) -> void:
	logic._state_add(t, WOUND)
	target_data(t).wound_until = round + 1


static func _end_domain(logic, a) -> void:
	var d := temp(a)
	d.domain = 0
	d.prep = 0
	d.available = round + 3
	if a.state_ids.has(DOMAIN):
		logic._state_remove(a, DOMAIN)


static func _clear(logic, a) -> void:
	_temp.erase(a)
	for id in [DOMAIN, MAHO, AWAKE]:
		if a.state_ids.has(id):
			logic._state_remove(a, id)


## BattleManager.startBattle 包装：之前 round 归 0、清出战宿傩的战斗数据并同步、清敌人目标数据；之后（start_tp）TP 至少 60
static func start_battle(logic) -> void:
	round = 0
	_temp.clear()
	_target.clear()
	cast = {}
	part = ""
	internal = false
	for a in _members(logic):
		_clear(logic, a)
		sync(a)


static func start_tp(logic) -> void:
	for a in _members(logic):
		a.tp = minf(a.max_tp(), maxf(a.tp, 60.0))


static func end_battle(logic) -> void:
	for a in _members(logic):
		_clear(logic, a)
	_temp.clear()
	_target.clear()
	cast = {}


## S.perform：内部行动（不经 startAction／endAction），按 Game_Action.apply（含本包装）结算
static func perform(logic, a, id: int, t, prep := 0) -> Array:
	if t == null or not t.is_alive():
		return []
	var saved := [cast, part, internal, preparation]
	cast = {}
	part = ""
	internal = true
	preparation = prep
	var logs: Array = logic.mark_views(apply(logic, a, XDB.rec("Skills", id), t))
	cast = saved[0]
	part = saved[1]
	internal = saved[2]
	preparation = saved[3]
	return logs


static func open(logic, a) -> Array:
	var d := temp(a)
	var p := int(d.prep)
	if not active_domain(a) or p < 1 or not knows(a, 10233):
		return []
	var logs := [_text(a.display_name() + "发动了神灶：开！")]
	for t in logic.alive(logic.enemies).duplicate():
		logs.append_array(perform(logic, a, 10233, t, p))
	_end_domain(logic, a)
	return logs


## Game_Action.apply 包装（宿傩 10229～10238）。返回 apply 记录列表：神灶：开直接施放、神灶打没蓄力的目标都不结算（空列表）；
## 捌（非终式）先冲击段、目标还活着再斩击段。
static func wraps(a, skill: Dictionary) -> bool:
	var id := int(skill.get("id", 0))
	return own(a) and id >= 10229 and id <= 10238 and not XBattleLogic.is_item(skill)


static func apply(logic, a, skill: Dictionary, t) -> Array:
	var id := int(skill.id)
	if id == 10233 and not internal:
		return []
	if id == 10232 and not bool(target_data(t).charged):
		return []
	if not internal and cast.is_empty():
		cast = _new_cast(a, id, t)
	var logs := []
	if id == 10230 and not internal and int(cast.terminal) == 0:
		part = "impact"
		logs.append(logic.apply(a, skill, t))
		if not t.is_alive():
			part = ""
			return logs
	var used: bool = t.is_alive() or int(skill.get("scope", 0)) in [9, 10]
	part = "slash"
	var r: Dictionary = logic.apply(a, skill, t)
	part = ""
	logs.append(r)
	var hit: bool = used and not r.missed and not r.evaded
	var layers := int(cast.layers) if not cast.is_empty() else int(target_data(t).layers)
	if hit and slash(id) and layers >= 2:
		_wound(logic, t)
	if not cast.is_empty() and hit:
		cast.hit = true
	if id == 10232 and hit:
		target_data(t).charged = false
	return logs


static func _new_cast(a, id: int, t) -> Dictionary:
	var q := target_data(t)
	return {"target": t, "layers": int(q.layers), "wounded": t.state_ids.has(WOUND), "emp": int(temp(a).emp) if XBlackFlash.status(a).awake else 0,
		"terminal": _terminal(a, id, int(q.layers)), "hit": false}


## S.begin（BattleManager.startAction 之后）：伏魔御厨子展开领域；按第一个目标建施放帧，终式记日志。任何人的行动都清上一帧。
static func begin(logic, u, skill: Dictionary, targets: Array) -> Array:
	cast = {}
	part = ""
	_acting = u
	_victim = null
	if not own(u) or XBattleLogic.is_item(skill):
		return []
	var id := int(skill.get("id", 0))
	if id == 10231:
		temp(u).domain = 4
		temp(u).prep = 0
		logic._state_add(u, DOMAIN)
	if targets.is_empty() or id < 10229 or id > 10238:
		return []
	cast = _new_cast(u, id, targets[0])
	if int(cast.terminal) != 0:
		if not XBlackFlash.cast.is_empty():
			XBlackFlash.cast.eligible = false  # 终式不判黑闪
		return [_text(u.display_name() + "发动了" + str(XDB.rec("Skills", int(cast.terminal)).get("name", "")) + "！")]
	return []


## S.finish（BattleManager.endAction 之前）
static func finish(logic, u, skill, forcing := false) -> Array:
	var logs := []
	var id := int(skill.get("id", 0)) if skill is Dictionary and not skill.is_empty() else 0
	var c: Dictionary = cast
	if own(u) and id >= 10229 and id <= 10238:
		if id == 10233:
			logs.append_array(open(logic, u))
			_done()
			return logs
		if id == 10238 and bool(c.get("hit", false)) and u.is_alive():
			u.tp = minf(u.max_tp(), u.tp + 20.0)  # gainSilentTp(20)
		if bool(c.get("hit", false)) and u.is_alive() and (PRIMARY.has(id) or id == 10232 or id == 10238):
			var t = c.target
			if knows(u, 10241) and int(temp(u).chase) != round:
				temp(u).chase = round
				logs.append_array(perform(logic, u, 10236, t))
			if PRIMARY.has(id):
				target_data(t).charged = true
				if int(c.terminal) != 0:
					_layers(logic, t, 0)
				else:
					_add_layer(logic, u, t)
		if PRIMARY.has(id) and not c.is_empty():
			temp(u).emp = 0
	if u is XEnemy and not forcing:
		for s in _members(logic):
			_add_layer(logic, s, u)
	var v = _victim
	if v != null and v.is_alive() and knows(v, 10246) and int(temp(v).adapt_round) != round:
		var d := temp(v)
		d.adapt_round = round
		d.adapt = mini(3, int(d.adapt) + 1)
		logic._state_add(v, MAHO)
	_done()
	return logs


static func _done() -> void:
	cast = {}
	part = ""
	_acting = null
	_victim = null


## executeHpDamage 包装：真伤时护盾视为 0（返回原护盾，结算后 restore_shield 放回）；敌人主行动扣了宿傩的血就记为受害者
static func strip_shield(u, t, item: Dictionary) -> float:
	if not true_hit(u, item):
		return -1.0
	var shield: float = t.shield
	t.shield = 0.0
	return shield


static func restore_shield(u, t, saved: float, hp_before: float) -> void:
	if saved >= 0.0:
		t.shield = saved
	if own(t) and u is XEnemy and u == _acting and hp_before > t.hp:
		_victim = t


## S.endRound（BattleManager.endTurn 包装，原 endTurn 之前）
static func end_round(logic) -> Array:
	var logs := []
	for a in _members(logic):
		var d := temp(a)
		if active_domain(a):
			logs.append(_text(a.display_name() + "的伏魔御厨子持续斩击！"))
			for t in logic.alive(logic.enemies).duplicate():
				logs.append_array(perform(logic, a, 10237, t))
			d.prep = mini(4, int(d.prep) + 1)
			d.domain = int(d.domain) - 1
			if int(d.domain) == 0:
				d.domain = 1
				if knows(a, 10233) and not logic.alive(logic.enemies).is_empty():
					logs.append_array(open(logic, a))
				else:
					_end_domain(logic, a)
		elif int(d.domain) != 0:
			_end_domain(logic, a)
		if not XBlackFlash.status(a).awake:
			d.emp = 0
	for t in logic.enemies:
		if int(target_data(t).wound_until) <= round and t.state_ids.has(WOUND):
			logic._state_remove(t, WOUND)
	round += 1
	return logs


## meetsSkillConditions 包装
static func meets(a, skill: Dictionary, logic = null) -> bool:
	if not own(a):
		return true
	var id := int(skill.get("id", 0))
	if id >= 10229 and id <= 10249 and not allowed(a, id):
		return false
	var d := temp(a)
	if id == 10231 and (active_domain(a) or round < int(d.available)):
		return false
	if id == 10233 and (not active_domain(a) or int(d.prep) < 1):
		return false
	if id == 10232 and (logic == null or not logic.alive(logic.enemies).any(func(t): return bool(target_data(t).charged))):
		return false
	return true


## Game_Actor.skills 包装的战斗中过滤（allowed 之外）：空间斩／次元斩、领域有准备层时的神灶、没有准备层时的神灶：开不列出
static func listed(a, skill: Dictionary) -> bool:
	if not own(a):
		return true
	var id := int(skill.get("id", 0))
	if id >= 10229 and id <= 10249 and not allowed(a, id):
		return false
	if id in [10234, 10235]:
		return false
	if id == 10232 and active_domain(a) and int(temp(a).prep) > 0:
		return false
	if id == 10233 and (not active_domain(a) or int(temp(a).prep) < 1):
		return false
	return true


## skillTpCost 包装（熟练度之后）：stage≥2 且领域中，解／捌 TP ×0.5
static func tp_cost(a, skill: Dictionary, v: int) -> int:
	if own(a) and stage(a) >= 2 and active_domain(a) and int(skill.get("id", 0)) in [10229, 10230]:
		return floori(v * 0.5)
	return v


## itemEva 包装：斩击打施放前≥1 层看破的目标不闪避（西游 YEP 闪避公式本为 0）
static func no_evade(a, skill: Dictionary, t) -> bool:
	if not own(a) or not slash(int(skill.get("id", 0)), part):
		return false
	return (int(cast.layers) if not cast.is_empty() else int(target_data(t).layers)) >= 1


## Game_Actor.die 包装：清战斗数据
static func on_death(b) -> void:
	_temp.erase(b)


## gainHp 包装：带伤口的受治疗减半
static func heal(b, amount: float) -> float:
	return floorf(amount * 0.5) if amount > 0.0 and b.state_ids.has(WOUND) else amount
