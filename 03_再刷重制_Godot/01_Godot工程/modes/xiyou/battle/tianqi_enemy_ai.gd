class_name XTianqiEnemyAI
extends RefCounted
## 【cc·六维卡3·未经审查】天启篇敌方六维 AI（T277；设定稿 天启篇_角色六维_v0.3定稿 第二节、第三节 3.3、第六节卡 3，Kyo D234、D236 乙）。
## 只管敌人怎么选招、选谁、会不会慌：不碰伤害、血防、敏捷、行动次数，不碰我方自动战斗（XSmartAI、挂机、auto_battle_action）。
## 估值用 T282 的 XBattleEval（只读、不抽随机流）；六维表只读 XTianqiSixDim（tianqi_data/six_dim.json）。
##
## 谁走六维 AI（协调 11-20 Q1＝A）：只认六维表里真录了的敌人（enemies 有这一号，或骑士键 knights 有这条线）；
## 没录的照原版 enemy_action 一点不变。西游档、XTianqiSixDim.ENABLED／本类 ENABLED 关着一律原版。
## 脚本首领最高：五条悟试炼、四骑士回合表、七印寂静、终焉收尸、小猫巨龙都在 BattleLogic.decide 里先走，走到这里的才是自由行动；
## 四骑士只接自由点名（XTianqiHorsemen._pick_target 没给 chosen 时，协调 11-20 Q2＝B），技能序列不动。
##
## 随机流掷数不变（协调认可）：
## - 选招：同原版 enemy_action，同一条「enemy_action」只掷一次，只是每招的权重按六维改了；战商 1 档（蒙昧）直接调原版。
## - 选目标：BattleLogic._random_target 同原版只掷一次「target」，只改各目标权重；骑士 _pick_target 仍只掷一次「horseman_target」。
##   （PCG 有界取数在极小概率 ≈ 区间长／2^32 下会重掷，这一点跟原版同理，不另处理。）
## - 慌乱：只有韧性 E／D、残血或同伴刚倒下的录表小怪才多掷（six_dim_panic、six_dim_panic_kind），别的敌人一个数都不多取。
##
## 全部系数是整数百分比（附则 E）；ai_weights 里有的读表，表里没有的（战商档规则、速度抢节奏、慌乱血线）写在下面常量里。

static var ENABLED := true

## 战商 3 档起（老练）：全体免疫／吸收 ×10%、打得到弱点 ×130%、白交控制 ×10%
const IMMUNE_PCT := 10
const WEAK_PCT := 130
const WASTED_CONTROL_PCT := 10
## 不需要的支援／召唤／自奶（满血空奶、满员空召）×10%（r1 P1-2：不管辅助几档都压低，不再留 100% 原权）
const IDLE_PCT := 10
## 战商 4 档起（狡黠）：能斩杀 ×140%；只剩 1 个敌人还交群体伤害招（有单体伤害招可选时）×50%
const KILL_PCT := 140
const AOE_WASTE_PCT := 50
## 战商 5 档（宗师）：我方主力被厚盾护着时，高耗爆发 ×35%、增益／减益／驱散铺垫 ×130%；厚盾＝护盾 ≥ 剩余血量的 50%
const HOLD_BURST_PCT := 35
const SETUP_PCT := 130
const THICK_SHIELD_PCT := 50
## 高耗爆发：MP 消耗 ≥ 最大 MP 的 30%，或 TP 消耗 ≥ 50
const BURST_MP_PCT := 30
const BURST_TP := 50
## 速度 A 起：先手增益／控制／减速类抢节奏招（稿 2.3 第 3 条；表里没这列）
const TEMPO_PCT := {"A": 125, "S": 125, "SS": 145, "SSS": 145}
## 低韧性慌乱血线（整数百分比，稿 3.3）：E ＜25%（或本回合刚有同伴倒下）、D ＜20%；概率读表 panic_pct
const PANIC_HP_PCT := {"E": 25, "D": 20}
## 目标权重（整数百分比）
const T_IMMUNE_PCT := 10
const T_WEAK_PCT := 130
const T_KILL_PCT := 600
const T_HEALER_PCT := 150
const T_CORE_PCT := 200
const T_WALL_PCT := 50
## 骑士自由点名：残血（＜30%）当斩杀看
const T_LOW_HP_PCT := 30

const META_LAST := "tq_six_dim_last_skill"
const META_PANIC := "tq_six_dim_panic"

## 这一次行动是谁按六维 AI 决定的（_random_target 只对这一位、这一招改权重；脚本首领、混乱、烙印等别的来源不改）
static var _decided_user = null
static var _decided_skill_id := -1


static func on() -> bool:
	return ENABLED and XTianqiSixDim.active()


## 表里这一行（模板合并后，含 class 等非六维字段）；没录回 {}
static func row_of(logic, b) -> Dictionary:
	if b == null or not on():
		return {}
	var d := XTianqiSixDim.data()
	if logic != null and XTianqiHorsemen.is_knight(logic, b):
		var k = d.get("knights", {}).get(str(XTianqiHorsemen.fight(logic).get("line", "")))
		return k.duplicate() if k is Dictionary else {}
	if not b is XEnemy:
		return {}
	var row = d.get("enemies", {}).get(str(int(b.enemy_id)))
	if not row is Dictionary:
		return {}
	var out: Dictionary = {}
	var tpl = d.get("templates", {}).get(str(row.get("template", "")))
	if tpl is Dictionary:
		out = tpl.duplicate()
	for k in row:
		out[k] = row[k]
	return out


static func registered(logic, b) -> bool:
	return not row_of(logic, b).is_empty()


static func tier(logic, b) -> int:
	return XTianqiSixDim.ai_tier(b, logic) if registered(logic, b) else 1


# ---- 技能意图分类 ----
static func _dmg_type(rec: Dictionary) -> int:
	return int(rec.get("damage", {}).get("type", 0))


static func is_damage(rec: Dictionary) -> bool:
	return XBattleEval.for_opponent(rec) and _dmg_type(rec) in [1, 2, 5, 6]


static func control_states(rec: Dictionary) -> Array:
	var out := []
	if not XBattleEval.for_opponent(rec):
		return out
	for e in rec.get("effects", []):
		if int(e.code) == 21 and int(e.dataId) > 1 and XEnemy.boss_control_state(int(e.dataId)):
			out.append(int(e.dataId))
	return out


static func is_control(rec: Dictionary) -> bool:
	return not control_states(rec).is_empty()


## 减益铺垫：对敌附加非控制的有害状态、降能力、解对方增益
static func is_debuff(rec: Dictionary) -> bool:
	if not XBattleEval.for_opponent(rec):
		return false
	for e in rec.get("effects", []):
		var c := int(e.code)
		if c in [32, 33] or (c == 21 and int(e.dataId) > 1 and XBattleEval.harmful_state(int(e.dataId)) and not XEnemy.boss_control_state(int(e.dataId))):
			return true
	return false


## 友方支援：治疗、复活、增益、解减益（自己一个人用的算自保，不算这里）
static func is_support(rec: Dictionary) -> bool:
	if not XBattleEval.for_friend(rec) or XBattleEval.for_user(rec):
		return false
	if _dmg_type(rec) in [3, 4] or XBattleEval.for_dead_friend(rec):
		return true
	for e in rec.get("effects", []):
		var c := int(e.code)
		if c in [11, 12, 31, 34] or (c == 21 and int(e.dataId) > 1 and not XBattleEval.harmful_state(int(e.dataId))) \
				or (c == 22 and XBattleEval.harmful_state(int(e.dataId))):
			return true
	return false


static var _summon_re := RegEx.create_from_string("(召唤|援军|召集|呼唤|叫来|摇人|Summon)")


## 召唤援军：按名字和备注认（库里没有统一标记）
static func is_summon(rec: Dictionary) -> bool:
	return _summon_re.search(str(rec.get("name", "")) + str(rec.get("note", ""))) != null


## 嘲讽状态：特性 23（特殊能力值）0 号受击率 > 1
static func _taunt_state(id: int) -> bool:
	for t in XDB.rec("States", id).get("traits", []):
		if int(t.code) == 23 and int(t.dataId) == 0 and float(t.value) > 1.0:
			return true
	return false


## 嘲讽／叠防／拖回合（生存 A 起平时就乘，低于血线也乘）：给己方挂嘲讽，或给自己加防御／魔防增益
static func is_stall(rec: Dictionary) -> bool:
	if XBattleEval.for_opponent(rec):
		return false
	for e in rec.get("effects", []):
		var c := int(e.code)
		if (c == 21 and int(e.dataId) > 1 and _taunt_state(int(e.dataId))) or (c == 31 and int(e.dataId) in [3, 5] and XBattleEval.for_user(rec)):
			return true
	return false


## 低血自保（只在低于血线时乘，r1 P1-1）：防御，以及只对自己的其它招（自奶、自增益）；嘲讽／叠防另算 is_stall
static func is_self_save(rec: Dictionary) -> bool:
	if int(rec.get("id", 0)) == XBattleLogic.GUARD_SKILL and not XBattleEval.is_item(rec):
		return true
	return XBattleEval.for_user(rec) and not is_stall(rec)


## 挂着嘲讽状态（受击率特性 > 1 的状态）
static func taunting(b) -> bool:
	return b.state_ids.any(func(id): return _taunt_state(int(id)))


## 自保／嘲讽总称（分类测试用）
static func is_guard(rec: Dictionary) -> bool:
	return is_self_save(rec) or is_stall(rec)


## 只对自己回血（满血时空奶）
static func _self_heal(rec: Dictionary) -> bool:
	return XBattleEval.for_user(rec) and (_dmg_type(rec) == 3 or rec.get("effects", []).any(func(x): return int(x.code) == 11))


## 抢节奏：控制、增益、减速（降敏捷）
static func is_tempo(rec: Dictionary) -> bool:
	if is_control(rec):
		return true
	for e in rec.get("effects", []):
		var c := int(e.code)
		if (c == 31 and XBattleEval.for_friend(rec)) or (c == 32 and int(e.dataId) == 6):
			return true
	return false


static func is_burst(user: XBattler, rec: Dictionary) -> bool:
	if not is_damage(rec):
		return false
	return int(rec.get("mpCost", 0)) * 100 >= int(user.mmp) * BURST_MP_PCT and int(rec.get("mpCost", 0)) > 0 \
		or int(rec.get("tpCost", 0)) >= BURST_TP


static func _hard_immune(logic, t: XBattler, id: int) -> bool:
	return t.traits_set(XBattler.TRAIT_STATE_RESIST).has(id) or logic.state_rate(t, id) <= 0.0 \
		or (t is XEnemy and t.boss_hyper_armor and XEnemy.boss_control_state(id))


static func _protected(t: XBattler) -> bool:
	return XBattleEval.shield_points(t, true) * 100.0 >= maxf(1.0, t.hp) * THICK_SHIELD_PCT


static func _pct(v: int, pct: int) -> int:
	return maxi(1, v * pct / 100)


# ---- 选招 ----
## 替原版 enemy_action：没录或 1 档直接原版；否则同样的候选与 rating 带，按六维改权重，同一条 enemy_action 只掷一次
static func enemy_action(logic, e: XEnemy) -> Dictionary:
	var t := tier(logic, e)
	if t <= 1:
		return logic.enemy_action(e)
	var list: Array = e.data().get("actions", []).filter(func(act): return logic._meets(e, act) and logic.can_use(e, XDB.rec("Skills", int(act.skillId))))
	if list.is_empty():
		return {}
	var rmax := 0
	for act in list:
		rmax = maxi(rmax, int(act.rating))
	var zero := rmax - 3
	list = list.filter(func(act): return int(act.rating) > zero)
	var weights := action_weights(logic, e, list, zero, t)
	var sum := 0
	for w in weights:
		sum += int(w)
	var r: int = logic._int(0, sum - 1, "enemy_action")
	var pick: Dictionary = list[0]
	for i in list.size():
		r -= int(weights[i])
		if r < 0:
			pick = list[i]
			break
	var rec := XDB.rec("Skills", int(pick.skillId))
	e.set_meta(META_LAST, int(rec.get("id", 0)))
	return rec


## 每个候选的整数权重（原版 rating−zero 先 ×100，再逐条乘整数百分比）；测试也直接调（given：测试给的技能记录，与 list 一一对应）
static func action_weights(logic, e: XEnemy, list: Array, zero: int, t: int, given: Array = []) -> Array:
	var six := XTianqiSixDim.of_battler(e, logic)
	var w := XTianqiSixDim.ai_weights_of(six)
	var ev := XBattleEval.create_for(logic, e, {"check_weakness": t >= 3, "check_kill": t >= 4})
	var foes: Array = logic.alive(logic.actors)
	var recs := given
	if recs.size() != list.size():
		recs = []
		for act in list:
			recs.append(XDB.rec("Skills", int(act.skillId)))
	var last := int(e.get_meta(META_LAST, -1))
	var distinct := {}
	for rec in recs:
		distinct[int(rec.get("id", 0))] = true
	var has_single_damage := recs.any(func(rec): return is_damage(rec) and not XBattleEval.for_all(rec))
	var low := e.hp_rate() * 100.0 < float(w.guard_hp_pct)
	var tough := XTianqiSixDim.score(XTianqiSixDim.letter(six, "survive")) >= 5  # A 起平时就爱嘲讽／套盾
	var speed := XTianqiSixDim.letter(six, "speed")
	var main_guarded := false
	if t >= 5 and not foes.is_empty():
		var top = foes[0]
		for f in foes:
			if XBattleEval.threat_in(f, foes) > XBattleEval.threat_in(top, foes):
				top = f
		main_guarded = _protected(top)
	var out := []
	for i in list.size():
		var rec: Dictionary = recs[i]
		var v := (int(list[i].rating) - zero) * 100
		if is_damage(rec):
			v = _pct(v, int(w.aggro_pct))
		if is_support(rec):
			v = _pct(v, int(w.support_pct) if _support_needed(logic, e, rec) else IDLE_PCT)
		if is_summon(rec):
			v = _pct(v, int(w.summon_pct) if logic.enemies.any(func(m): return m.is_dead()) else IDLE_PCT)
		if is_stall(rec) and (low or tough):
			v = _pct(v, int(w.guard_score_pct))
		elif is_self_save(rec):
			if _self_heal(rec) and e.hp >= e.mhp:
				v = _pct(v, IDLE_PCT)  # 满血不空奶自己
			elif low:
				v = _pct(v, int(w.guard_score_pct))  # 低于自己的血线才缩（A／S 20%、SS／SSS 15%）
		if int(rec.get("id", 0)) == last and distinct.size() > 1:
			v = _pct(v, int(w.repeat_pct))
		if TEMPO_PCT.has(speed) and is_tempo(rec):
			v = _pct(v, int(TEMPO_PCT[speed]))
		if t >= 3 and not foes.is_empty():
			if is_damage(rec):
				var kinds := foes.map(func(f): return ev.element_kind(f, rec))
				if kinds.all(func(k): return k in ["immune", "absorb"]):
					v = _pct(v, IMMUNE_PCT)
				elif kinds.any(func(k): return str(k) in ["weak", "converted_weak"]):
					v = _pct(v, WEAK_PCT)
			var ctrl := control_states(rec)
			if not ctrl.is_empty() and _dmg_type(rec) == 0:
				var useful := foes.any(func(f): return ctrl.any(func(id): return not f.is_state_affected(id) and not _hard_immune(logic, f, id)))
				if not useful:
					v = _pct(v, WASTED_CONTROL_PCT)
		if t >= 4 and not foes.is_empty() and is_damage(rec):
			if foes.any(func(f): return _killable(ev, e, f, rec)):
				v = _pct(v, KILL_PCT)
			if foes.size() == 1 and XBattleEval.for_all(rec) and has_single_damage:  # 随机 n 下（scope 3～6）单敌时全段集中，不算浪费（r1 P2-1）
				v = _pct(v, AOE_WASTE_PCT)
		if t >= 5 and main_guarded:
			if is_burst(e, rec):
				v = _pct(v, HOLD_BURST_PCT)
			elif is_debuff(rec) or is_tempo(rec) or _dispels(rec):
				v = _pct(v, SETUP_PCT)
		out.append(maxi(1, v))
	return out


## 驱散：解对方增益（效果 33），或对敌解除非有害状态
static func _dispels(rec: Dictionary) -> bool:
	for e in rec.get("effects", []):
		if int(e.code) == 33 or (int(e.code) == 22 and XBattleEval.for_opponent(rec) and not XBattleEval.harmful_state(int(e.dataId))):
			return true
	return false


## 支援招有没有用武之地（不空奶）：治疗看有没有受伤的、复活看有没有倒下的、增益看有没有还没挂上的
static func _support_needed(logic, e: XEnemy, rec: Dictionary) -> bool:
	var mates: Array = logic.enemies
	if XBattleEval.for_dead_friend(rec):
		return mates.any(func(m): return m.is_dead())
	var live := mates.filter(func(m): return m.is_alive() and m != e) if not XBattleEval.for_all(rec) else mates.filter(func(m): return m.is_alive())
	var fx: Array = rec.get("effects", [])
	if (_dmg_type(rec) == 3 or fx.any(func(x): return int(x.code) == 11)) and live.any(func(m): return m.hp < m.mhp):
		return true
	if (_dmg_type(rec) == 4 or fx.any(func(x): return int(x.code) == 12)) and live.any(func(m): return m.mp < m.mmp):
		return true
	for x in fx:
		var c := int(x.code)
		var id := int(x.dataId)
		if c == 21 and id > 1 and live.any(func(m): return not m.is_state_affected(id)):
			return true
		if c == 31 and id >= 0 and id < 8 and live.any(func(m): return int(m.buffs[id]) < 2):
			return true
		if c == 34 and id >= 0 and id < 8 and live.any(func(m): return int(m.buffs[id]) < 0):
			return true
		if c == 22 and id > 1 and XBattleEval.harmful_state(id) and live.any(func(m): return m.is_state_affected(id)):
			return true
	return false


static func _killable(ev: XBattleEval, e: XEnemy, f: XBattler, rec: Dictionary) -> bool:
	if not _dmg_type(rec) in [1, 5]:
		return false  # MP 伤害不算斩杀（r1 P3-3）
	var dmg := ev.expected_damage(e, f, rec, ev._raw(f, rec), ev.hits_of(rec))
	return dmg > 0.0 and dmg >= f.hp + XBattleEval.shield_points(f, true)


# ---- 选目标（BattleLogic._random_target）----
## BattleLogic.decide 走到自由行动时登记：这一位这一招接下来的随机点名按六维改权重
static func note_decision(logic, e, decision: Array) -> void:
	_decided_user = null
	_decided_skill_id = -1
	if e == null or decision.is_empty() or not decision[0] is Dictionary or tier(logic, e) <= 1:
		return
	_decided_user = e
	_decided_skill_id = int(decision[0].get("id", 0))


## 原版权重 base（tgr×烙印项）进来，按战商改了出去；不适用原样返回（同一个数组）
static func target_weights(logic, user, list: Array, base: Array, skill: Dictionary) -> Array:
	if user == null or not is_same(user, _decided_user) or skill.is_empty() or int(skill.get("id", 0)) != _decided_skill_id or not on():
		return base
	var t := tier(logic, user)
	if t <= 1 or list.size() < 2:
		return base
	var taunted := list.any(func(b): return taunting(b))  # 有人挂着嘲讽状态：照受击率打嘲讽的（2 档）／只按免疫筛（3 档起）。天生、装备的高受击率不算（r1 P2-2），只在 base 里照常加权
	var out := base.duplicate()
	if t == 2:
		if taunted:
			return base
		var total := 0.0
		for w in base:
			total += float(w)
		var lowest := 0
		for i in list.size():
			if list[i].hp_rate() < list[lowest].hp_rate():
				lowest = i
		for i in list.size():
			out[i] = float(base[i]) * 50.0 / maxf(total, 0.000001) + (50.0 if i == lowest else 0.0)  # 一半盯最低血、一半照受击率
		return out
	var ev := XBattleEval.create_for(logic, user, {"check_weakness": true, "check_kill": t >= 4})
	var dmg := is_damage(skill)
	var core := _core_index(list)
	for i in list.size():
		var b: XBattler = list[i]
		var pct := 100
		if dmg:
			var k := ev.element_kind(b, skill)
			if k in ["immune", "absorb"]:
				pct = pct * T_IMMUNE_PCT / 100
			elif k in ["weak", "converted_weak"]:
				pct = pct * T_WEAK_PCT / 100
		if t >= 4 and not taunted:
			if dmg and _killable(ev, user, b, skill):
				pct = pct * T_KILL_PCT / 100
			if healer(b):
				pct = pct * (T_CORE_PCT if t >= 5 else T_HEALER_PCT) / 100
			pct = pct * int(roundf(ev.threat(b) * 100.0)) / 100
		if t >= 5 and not taunted:
			if i == core:
				pct = pct * T_CORE_PCT / 100
			if _protected(b):
				pct = pct * T_WALL_PCT / 100
		out[i] = float(base[i]) * float(maxi(1, pct)) / 100.0
	return out


## 治疗／复活点：会对友方回血或复活
static func healer(b: XBattler) -> bool:
	if not b is XActor:
		return false
	for s in b.skills():
		if XBattleEval.for_friend(s) and not XBattleEval.for_user(s) and (_dmg_type(s) == 3 or XBattleEval.for_dead_friend(s) \
				or s.get("effects", []).any(func(x): return int(x.code) == 11)):
			return true
	return false


## 主力输出：攻、魔里较高那项最高的一位
static func _core_index(list: Array) -> int:
	var best := 0
	for i in list.size():
		if maxf(list[i].atk, list[i].mat) > maxf(list[best].atk, list[best].mat):
			best = i
	return best


# ---- 四骑士自由点名（XTianqiHorsemen._pick_target）----
## 返回各目标整数权重；不适用（没录、1 档、开关关）返回 []，调用方照原版均匀掷
static func knight_target_weights(logic, u, live: Array) -> Array:
	if u == null or live.size() < 2 or not on() or not XTianqiHorsemen.is_knight(logic, u):
		return []
	var t := tier(logic, u)
	if t <= 1:
		return []
	var out := []
	for b in live:
		out.append(100)
	if t == 2:
		var lowest := 0
		for i in live.size():
			if live[i].hp_rate() < live[lowest].hp_rate():
				lowest = i
		out[lowest] += 100 * live.size()  # 一半盯最低血、一半均匀
		return out
	var core := _core_index(live)
	for i in live.size():
		var b: XBattler = live[i]
		var pct := 100
		if _protected(b):
			pct = pct * T_WALL_PCT / 100  # 打不动的少打
		if t >= 4:
			if b.hp_rate() * 100.0 < T_LOW_HP_PCT:
				pct = pct * T_KILL_PCT / 100
			if healer(b):
				pct = pct * (T_CORE_PCT if t >= 5 else T_HEALER_PCT) / 100
		if t >= 5 and i == core:
			pct = pct * T_CORE_PCT / 100
		out[i] = maxi(1, pct)
	return out


# ---- 低韧性慌乱（稿 3.3）----
## 只录表的普通小怪（class minion／elite，非首领、非骑士援军）；能行动、韧性 E／D、残血或（E）本回合有同伴倒下时掷 panic_pct。
## 慌了返回 [技能, 目标]（防御／乱打普攻／发抖空过三选一等权），并记一条战报；没慌返回 []（没资格不取数）
static func panic(logic, e) -> Array:
	if not e is XEnemy or not on() or not logic.can_move(e):
		return []
	var row := row_of(logic, e)
	if row.is_empty() or not str(row.get("class", "minion")) in ["minion", "elite"]:
		return []
	if XBattleEval.is_boss(e) or XEnemy.boss_id(int(e.enemy_id)) or e.boss_difficulty_boss or XTianqiHorsemen.is_add(logic, e) or XTianqiHorsemen.is_knight(logic, e):
		return []
	var six := XTianqiSixDim.of_battler(e, logic)
	var res := XTianqiSixDim.letter(six, "resolve")
	if not PANIC_HP_PCT.has(res):
		return []
	var chance := int(XTianqiSixDim.ai_weights_of(six).panic_pct)
	var shaken: bool = e.hp_rate() * 100.0 < float(PANIC_HP_PCT[res]) or (res == "E" and XRaven.any_death)
	if chance <= 0 or not shaken:
		return []
	if logic._int(0, 99, "six_dim_panic") >= chance:
		return []
	var kind: int = logic._int(0, 2, "six_dim_panic_kind")
	e.set_meta(META_PANIC, panic_text(e, kind))
	match kind:
		0:
			return [XDB.rec("Skills", XBattleLogic.GUARD_SKILL), null]  # 原地防御退缩
		1:
			return [e.attack_skill(), null]  # 不看目标乱打：普攻，目标照原版受击率随机（不登记六维点名）
	return [null, null]  # 发抖空过


## 慌乱战报（小A r1 文字审定稿：按三种表现分句）
const PANIC_TEXT := ["%s阵脚大乱，慌忙缩身防守！", "%s阵脚大乱，胡乱挥出一击！", "%s阵脚大乱，呆在原地没敢出手！"]


static func panic_text(e, kind: int) -> String:
	return PANIC_TEXT[clampi(kind, 0, 2)] % e.display_name()


## BattleLogic.act 开头取：这一位刚慌乱就出一条战报
static func take_logs(u) -> Array:
	if u == null or not u.has_meta(META_PANIC):
		return []
	var text := str(u.get_meta(META_PANIC))
	u.remove_meta(META_PANIC)
	return [{"type": "battle_text", "text": text, "tianqi_fit": true}]  # tianqi_fit：战斗画面停 FIT_TEXT_FRAMES 帧再往下（r1 P1-3，同烙印发作）
