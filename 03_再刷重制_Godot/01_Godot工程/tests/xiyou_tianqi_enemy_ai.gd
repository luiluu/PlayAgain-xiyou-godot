extends Node
## 天启篇六维③敌方 AI（T277，卡 3）专项：XTianqiEnemyAI。六维档全在测试里自设（T280 正重算，不写死角色档位），结尾还原内存表。
## 一、门控：没录的敌人、开关关、西游档＝原版 enemy_action，取数一条不差（协调 11-20 Q1＝A）。
## 二、选招权重逐条：战商 3 档避免疫／打弱点／不白交控制，4 档斩杀与群攻浪费，5 档留牌；输出、辅助（不空奶）、生存血线、速度复读与抢节奏。
## 三、实战选招：同一池子 1 档≈原版、3 档几乎不交全体免疫招；开／关两边 enemy_action 掷数一样。
## 四、选目标：2 档一半盯最低血、嘲讽照打；3 档避免疫；4 档斩杀与治疗点；5 档主力与铁壁；只对六维 AI 决定的这一招生效；target 仍只掷一次。
## 五、低韧性慌乱：E／D 残血（E 另认同伴刚倒下）才掷、三种表现、战报；韧性 C、首领、骑士 0 触发；同种子可复现。
## 六、四骑士（四条线本体＋影子）：开关开／关技能序列一致、掷数一致；没给 chosen 的自由点名按战商加权；五条悟试炼回合表不变。
## 七、不改数值：敌人能力值与估伤开关两边一致；我方自动战斗选招开／关一致（敌人韧性取 C，避开 T276 非 C＋非必中控制边界，P3-1）。
## 八、boss_control_state 正则预编译（T276 核查 P2-1）：全库状态判定与现编正则逐个一致。

class CountStream extends XRandomStream:
	## 照真流取数，另按 reason 计数（看掷数）
	var counts := {}
	var ints := {}  # reason → 固定返回（给了就不取真数，仍计数）
	func _init(seed_hex := "00000000000000a7") -> void:
		domain = "rule"
		_rng.seed = XRandomStream.parse64(seed_hex)
	func _note(reason: String) -> void:
		counts[reason] = int(counts.get(reason, 0)) + 1
	func next_float(reason: String, event_key := "") -> float:
		_note(reason)
		return super.next_float(reason, event_key)
	func next_uint(reason: String, event_key := "") -> int:
		return super.next_uint(reason, event_key)
	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		_note(reason)
		if ints.has(reason):
			return clampi(int(ints[reason]), lo, hi)
		return super.next_int_inclusive(lo, hi, reason, event_key)

var results: Array = []
var _saved: Dictionary = {}
var DMG_E := 0  # 单体带属性伤害招
var DMG_N := 0  # 单体无属性伤害招
var AOE := 0  # 全体无属性伤害招
var HEAL := 0  # 友方单体治疗
var CTRL := 0  # 控制状态（眩晕）
var CTRL_REC := {}  # 合成的单体纯控制招（库里没有不带伤害的）
var IMMUNE_ST := 0  # 让我方对 DMG_E 的属性免疫的状态
var WEAK_ST := 0  # 让我方对 DMG_E 的属性弱的状态
var WEAK_ALL := []  # 候选（我方本身可能带这一属性的抗性，挑加上后真变弱的那个）
var TAUNT_ST := 0  # 受击率 ×2 以上的状态（嘲讽）


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids() -> Array:
	return XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state(tianqi := true, tough := 0.0) -> XState:
	var w := _ids()
	var lineup := [w[0], w[1], w[2], w[3], w[5]]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, "jianxian", lineup)
		XTianqi.take_pending()
	else:
		s = XState.new()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in lineup:
		var a := s.actor(id)
		if tough > 0.0:
			a.add_param(0, tough)
			a.add_param(3, 10000.0)
			a.add_param(5, 10000.0)
		a.recover_all()
	return s


func _logic(tianqi := true, troop := 2) -> XBattleLogic:
	var lg := XBattleLogic.new()
	lg.setup(troop, _state(tianqi))
	return lg


func _seed(lg: XBattleLogic, hex := "00000000000000a7") -> CountStream:
	var cs := CountStream.new(hex)
	lg.random.rule = cs
	return cs


func _six(o := "C", sv := "C", sp := "C", wit := "C", res := "C", sup := "C", cls := "minion") -> Dictionary:
	return {"class": cls, "output": o, "survive": sv, "speed": sp, "wit": wit, "resolve": res, "support": sup}


func _set_enemy(e: XEnemy, row: Dictionary) -> void:
	XTianqiSixDim.data().get("enemies", {})[str(e.enemy_id)] = row


func _clear_enemy(e: XEnemy) -> void:
	XTianqiSixDim.data().get("enemies", {}).erase(str(e.enemy_id))


func _act(id: int, rating := 5) -> Dictionary:
	return {"skillId": id, "rating": rating, "conditionType": 0, "conditionParam1": 0, "conditionParam2": 0}


## ids：技能号，或直接给记录（纯控制招库里没有，用合成记录 CTRL_REC）；rating 一律 5、zero 2 → 底分 300
func _w(lg: XBattleLogic, e: XEnemy, ids: Array, tier := -1) -> Array:
	var recs := ids.map(func(x): return x if x is Dictionary else XDB.rec("Skills", int(x)))
	var list := recs.map(func(r): return _act(int(r.get("id", 0))))
	return XTianqiEnemyAI.action_weights(lg, e, list, 2, tier if tier > 0 else XTianqiEnemyAI.tier(lg, e), recs)


func _simple(s: Dictionary) -> bool:
	var f := str(s.get("damage", {}).get("formula", ""))
	return not ("v[" in f or "if" in f or "=" in f or ";" in f or "user." in f) and int(s.get("mpCost", 0)) == 0 and int(s.get("tpCost", 0)) == 0 \
		and str(s.get("note", "")).findn("<Custom Target Eval>") < 0 and not s.get("meta", {}).has("Hide in Battle")


## 在天启篇存档下挑（技能重构、元素重做会改记录，按 XDB.rec 看到的挑）
func _pick() -> void:
	var tbl: Array = XDB.table("Skills")
	for i in tbl.size():
		if not tbl[i] is Dictionary or tbl[i].is_empty():
			continue
		var s := XDB.rec("Skills", i)
		var d: Dictionary = s.get("damage", {})
		var sc := int(s.get("scope", 0))
		var fx: Array = s.get("effects", [])
		if DMG_E == 0 and sc == 1 and int(d.type) == 1 and int(d.elementId) == 2 and fx.is_empty() and _simple(s) and "a." in str(d.formula):
			DMG_E = int(s.id)
		if DMG_N == 0 and sc == 1 and int(d.type) == 1 and int(d.elementId) == 0 and fx.is_empty() and _simple(s) and "a." in str(d.formula):
			DMG_N = int(s.id)
		if AOE == 0 and sc == 2 and int(d.type) == 1 and int(d.elementId) == 0 and fx.is_empty() and _simple(s) and "a." in str(d.formula):
			AOE = int(s.id)
		if HEAL == 0 and sc == 7 and int(d.type) == 3 and fx.is_empty() and _simple(s) and not XTianqiEnemyAI.is_summon(s):
			HEAL = int(s.id)
	if DMG_N == 0:
		DMG_N = 1  # 天启篇元素重做把无属性单体招都转了属性：用普攻（属性跟攻击者，测试敌人没有攻击属性）
	# 库里没有不带伤害的纯控制招：合成一条（只给打分用，不进库）
	var stbl: Array = XDB.table("States")
	for i in stbl.size():
		if CTRL == 0 and stbl[i] is Dictionary and not stbl[i].is_empty() and str(stbl[i].get("name", "")) == "眩晕" and XEnemy.boss_control_state(i):
			CTRL = i
	CTRL_REC = {"id": 990001, "name": "测试定身", "scope": 1, "damage": {"type": 0, "elementId": 0, "formula": "0"},
		"effects": [{"code": 21, "dataId": CTRL, "value1": 1.0, "value2": 0.0}], "mpCost": 0, "tpCost": 0, "note": "", "meta": {}}
	for i in stbl.size():
		if not stbl[i] is Dictionary or stbl[i].is_empty():
			continue
		var st := XDB.rec("States", i)
		for t in st.get("traits", []):
			if TAUNT_ST == 0 and int(t.code) == 23 and int(t.dataId) == 0 and float(t.value) >= 2.0 and int(st.get("restriction", 0)) == 0:
				TAUNT_ST = i
			if int(t.code) == XBattler.TRAIT_ELEMENT_RATE and int(t.dataId) == 2:
				if IMMUNE_ST == 0 and float(t.value) == 0.0:
					IMMUNE_ST = int(st.id)
				if float(t.value) > 1.0:
					WEAK_ALL.append(i)
					if WEAK_ST == 0:
						WEAK_ST = int(st.id)


func _run() -> void:
	XMessageBox.auto = true
	seed(20261120)
	XTianqiSixDim.ENABLED = true
	XTianqiEnemyAI.ENABLED = true
	_logic().end_battle()  # 先立天启篇存档，按它看到的记录挑招
	_pick()
	_check("picked", DMG_E > 0 and DMG_N > 0 and AOE > 0 and HEAL > 0 and CTRL > 0 and IMMUNE_ST > 0 and WEAK_ST > 0,
		[DMG_E, DMG_N, AOE, HEAL, CTRL, IMMUNE_ST, WEAK_ST])
	if not results[-1].passed:
		print("FAIL picked ", JSON.stringify(results[-1].detail))
		get_tree().quit.call_deferred(1)
		return
	_saved = XTianqiSixDim.data().duplicate(true)
	_gate()
	_restore()
	_weights()
	_restore()
	_real_pick()
	_restore()
	_targets()
	_restore()
	_panic()
	_restore()
	_knights()
	_restore()
	_gojo()
	_restore()
	_xuan_auto()
	_restore()
	_no_numbers()
	_restore()
	_control_regex()
	XTianqiEnemyAI.ENABLED = true
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _restore() -> void:
	XTianqiSixDim._data = _saved.duplicate(true)
	XTianqiEnemyAI.ENABLED = true
	XTianqiEnemyAI.note_decision(null, null, [])
	XRaven.any_death = false


## 换敌人的行动表（共用 DB 记录，跑完还原）
func _with_actions(e: XEnemy, acts: Array, f: Callable) -> void:
	var d := e.data()
	var old = d.get("actions", [])
	d["actions"] = acts
	f.call()
	d["actions"] = old


## n 次决定的技能号序列＋各 reason 掷数
func _decide_n(lg: XBattleLogic, e: XEnemy, n: int, hex := "00000000000000a7") -> Dictionary:
	var cs := _seed(lg, hex)
	var seq := []
	for i in n:
		var d := lg.decide(e)
		seq.append(int(d[0].id) if d[0] is Dictionary else -1)
	return {"seq": seq, "counts": cs.counts.duplicate()}


# 一、门控
func _gate() -> void:
	var lg := _logic()
	var e: XEnemy = lg.enemies[0]
	_clear_enemy(e)
	_check("gate_unregistered_tier1", not XTianqiEnemyAI.registered(lg, e) and XTianqiEnemyAI.tier(lg, e) == 1)
	var acts := [_act(DMG_E, 5), _act(DMG_N, 4), _act(AOE, 3)]
	_with_actions(e, acts, func():
		XTianqiEnemyAI.ENABLED = false
		var off := _decide_n(lg, e, 60)
		XTianqiEnemyAI.ENABLED = true
		var unreg := _decide_n(lg, e, 60)
		_check("gate_unregistered_same_as_off", off == unreg, [off.counts, unreg.counts])
		_set_enemy(e, _six("C", "C", "C", "E"))  # 战商 E＝1 档
		var t1 := _decide_n(lg, e, 60)
		_check("gate_tier1_same_as_off", XTianqiEnemyAI.tier(lg, e) == 1 and t1 == off, [t1.counts, off.counts])
		_set_enemy(e, _six("C", "C", "C", "SS"))
		var t5 := _decide_n(lg, e, 60)
		_check("gate_tier5_same_draws", t5.counts == off.counts, [t5.counts, off.counts])
		XTianqiSixDim.ENABLED = false
		var six_off := _decide_n(lg, e, 60)
		var was_on := XTianqiEnemyAI.on()
		XTianqiSixDim.ENABLED = true
		_check("gate_sixdim_off_same", six_off == off and not was_on))
	lg.end_battle()
	# 西游档
	var xl := _logic(false)
	var xe: XEnemy = xl.enemies[0]
	_set_enemy(xe, _six("SSS", "C", "C", "SS"))
	_check("gate_xiyou_off", not XTianqiEnemyAI.on() and XTianqiEnemyAI.tier(xl, xe) == 1 and XTianqiEnemyAI.panic(xl, xe).is_empty())
	_with_actions(xe, acts, func():
		XTianqiEnemyAI.ENABLED = false
		var off := _decide_n(xl, xe, 30)
		XTianqiEnemyAI.ENABLED = true
		_check("gate_xiyou_same", _decide_n(xl, xe, 30) == off))
	xl.end_battle()


# 二、选招权重
func _weights() -> void:
	var lg := _logic()
	var e: XEnemy = lg.enemies[0]
	var foes := lg.alive(lg.actors)
	# 战商 3 档：全体免疫 ×10，打得到弱点 ×130；2 档不看
	for a in foes:
		a.add_state(IMMUNE_ST)
	_set_enemy(e, _six())
	var w3 := _w(lg, e, [DMG_E, DMG_N])
	_check("w3_immune_x10", w3 == [30, 300], w3)
	_set_enemy(e, _six("C", "C", "C", "D"))
	var w2 := _w(lg, e, [DMG_E, DMG_N])
	_check("w2_ignores_immune", w2 == [300, 300], w2)
	for a in foes:
		a.remove_state(IMMUNE_ST)
	var elem := int(XDB.rec("Skills", DMG_E).damage.elementId)
	for cand in WEAK_ALL:
		foes[0].add_state(cand)
		var ok: bool = foes[0].element_rate(elem) > 1.0
		foes[0].remove_state(cand)
		if ok:
			WEAK_ST = cand
			break
	for a in foes:
		a.add_state(WEAK_ST)
	_set_enemy(e, _six())
	var ww := _w(lg, e, [DMG_E, DMG_N])
	_check("w3_weak_x130", ww == [390, 300], [ww, foes.map(func(a): return a.element_rate(elem))])
	for a in foes:
		a.remove_state(WEAK_ST)
	# 白交控制：我方都已挂着这个控制
	var cid := CTRL
	var wc0 := _w(lg, e, [CTRL_REC, DMG_N])
	for a in foes:
		a.add_state(cid)
	var wc1 := _w(lg, e, [CTRL_REC, DMG_N])
	for a in foes:
		a.remove_state(cid)
	_check("w3_wasted_control_x10", wc0[0] == 300 and wc1[0] == wc0[0] * 10 / 100, [wc0, wc1, cid])
	# 4 档斩杀 ×140：我方一人血剩 1
	var hp0: float = foes[2].hp
	foes[2].hp = 1.0
	_set_enemy(e, _six("C", "C", "C", "A"))
	var wk := _w(lg, e, [DMG_N])
	_set_enemy(e, _six())
	var wk3 := _w(lg, e, [DMG_N])
	_check("w4_kill_x140", wk == [420] and wk3 == [300], [wk, wk3])
	foes[2].hp = hp0
	# 4 档：只剩一个敌人时群攻 ×50（有单体可选）
	for i in range(1, foes.size()):
		foes[i].hp = 0.0
		foes[i].add_state(1)
	_set_enemy(e, _six("C", "C", "C", "A"))
	var wa := _w(lg, e, [AOE, DMG_N])
	_check("w4_aoe_waste_x50", wa == [150, 300], wa)
	var rnd: Dictionary = XDB.rec("Skills", AOE).duplicate(true)
	rnd.scope = 4  # 随机 2 下：单敌时全段集中，不算群攻浪费（r1 P2-1）
	var wr := _w(lg, e, [rnd, DMG_N])
	_check("w4_random_not_waste", XBattleEval.for_random(rnd) and wr == [300, 300], wr)
	for i in range(1, foes.size()):
		foes[i].remove_state(1)
		foes[i].recover_all()
	# 5 档：我方主力（威胁最高）护盾 ≥ 剩余血 50% 时，高耗爆发 ×35
	var top = foes[0]
	for f in foes:
		if XBattleEval.threat_in(f, foes) > XBattleEval.threat_in(top, foes):
			top = f
	var burst := {}
	for s in XDB.table("Skills"):
		if s is Dictionary and not s.is_empty() and int(s.get("scope", 0)) == 1 and int(s.get("damage", {}).get("type", 0)) == 1 and int(s.get("tpCost", 0)) >= 50 and s.get("effects", []).is_empty():
			burst = s
			break
	_check("w5_found_burst", not burst.is_empty() and XTianqiEnemyAI.is_burst(e, burst))
	_set_enemy(e, _six("C", "C", "C", "SS"))
	var wb0 := _w(lg, e, [int(burst.get("id", DMG_N)), DMG_N])
	top.shield = top.hp
	var wb1 := _w(lg, e, [int(burst.get("id", DMG_N)), DMG_N])
	top.shield = 0.0
	_check("w5_hold_burst_x35", wb1[0] == wb0[0] * 35 / 100 and wb1[1] == wb0[1], [wb0, wb1])
	# 输出：伤害招 E 75 … SSS 180
	_set_enemy(e, _six("E"))
	var oe := _w(lg, e, [DMG_N, CTRL_REC])
	_set_enemy(e, _six("SSS"))
	var os := _w(lg, e, [DMG_N, CTRL_REC])
	_check("w_aggro", oe[0] == 225 and os[0] == 540 and oe[1] == os[1], [oe, os])
	# 辅助：队友受伤才乘（不空奶）；E 40、SSS 240
	var mate: XEnemy = lg.enemies[1] if lg.enemies.size() > 1 else null
	_check("w_has_mate", mate != null, lg.enemies.size())
	if mate != null:
		_set_enemy(e, _six("C", "C", "C", "C", "C", "SSS"))
		var full := _w(lg, e, [HEAL])
		mate.hp = mate.mhp * 0.5
		var hurt := _w(lg, e, [HEAL])
		_set_enemy(e, _six("C", "C", "C", "C", "C", "E"))
		var lone := _w(lg, e, [HEAL])
		mate.recover_all()
		mate.recover_all()
		var lone_full := _w(lg, e, [HEAL])
		_check("w_support", full == [30] and hurt == [720] and lone == [120] and lone_full == [30], [full, hurt, lone, lone_full])
		# 召唤：有空位（队里有倒下的）才按辅助乘，满员 ×10（r1 P1-2）
		var summon := {"id": 990002, "name": "召唤援军", "scope": 11, "damage": {"type": 0, "elementId": 0, "formula": "0"}, "effects": [], "mpCost": 0, "tpCost": 0, "note": "", "meta": {}}
		_set_enemy(e, _six("C", "C", "C", "C", "C", "E"))
		var s_full_e := _w(lg, e, [summon])
		mate.hp = 0.0
		mate.add_state(1)
		var s_slot_e := _w(lg, e, [summon])
		_set_enemy(e, _six("C", "C", "C", "C", "C", "SSS"))
		var s_slot_s := _w(lg, e, [summon])
		mate.remove_state(1)
		mate.recover_all()
		var s_full_s := _w(lg, e, [summon])
		_check("w_summon", XTianqiEnemyAI.is_summon(summon) and s_full_e == [30] and s_slot_e == [90] and s_slot_s == [780] and s_full_s == [30],
			[s_full_e, s_slot_e, s_slot_s, s_full_s])
	# 生存（r1 P1-1）：防御／自保只在低于自己的血线才乘——E 55% 以下 ×150、C 35% 以下 ×130、A 20%、SS 15%；满血不乘
	var g := XBattleLogic.GUARD_SKILL
	e.hp = e.mhp * 0.5
	_set_enemy(e, _six("C", "E"))
	var ge := _w(lg, e, [g])
	_set_enemy(e, _six("C", "C"))
	var gc := _w(lg, e, [g])
	e.hp = e.mhp * 0.3
	var gc3 := _w(lg, e, [g])
	e.recover_all()
	_set_enemy(e, _six("C", "A"))
	var ga := _w(lg, e, [g])
	e.hp = e.mhp * 0.25
	var ga25 := _w(lg, e, [g])
	e.hp = e.mhp * 0.15
	var ga15 := _w(lg, e, [g])
	_set_enemy(e, _six("C", "SS"))
	e.hp = e.mhp * 0.18
	var gs18 := _w(lg, e, [g])
	e.hp = e.mhp * 0.1
	var gs10 := _w(lg, e, [g])
	e.recover_all()
	_check("w_guard", ge == [450] and gc == [300] and gc3 == [390] and ga == [300] and ga25 == [300] and ga15 == [390] and gs18 == [300] and gs10 == [450],
		[ge, gc, gc3, ga, ga25, ga15, gs18, gs10])
	# 嘲讽／叠防：生存 A 起满血也乘，C 满血不乘
	var taunt := {"id": 990003, "name": "测试挑衅", "scope": 11, "damage": {"type": 0, "elementId": 0, "formula": "0"},
		"effects": [{"code": 21, "dataId": TAUNT_ST, "value1": 1.0, "value2": 0.0}], "mpCost": 0, "tpCost": 0, "note": "", "meta": {}}
	_set_enemy(e, _six("C", "A"))
	var ta := _w(lg, e, [taunt])
	_set_enemy(e, _six("C", "SS"))
	var tss := _w(lg, e, [taunt])
	_set_enemy(e, _six("C", "C"))
	var tc := _w(lg, e, [taunt])
	_check("w_stall", XTianqiEnemyAI.is_stall(taunt) and ta == [390] and tss == [450] and tc == [300], [ta, tss, tc])
	# 满血不空奶自己：自奶满血 ×10、低血按生存乘
	var self_heal := {"id": 990004, "name": "测试自愈", "scope": 11, "damage": {"type": 3, "elementId": 0, "formula": "100"}, "effects": [],
		"mpCost": 0, "tpCost": 0, "note": "", "meta": {}}
	_set_enemy(e, _six("C", "A"))
	var sh_full := _w(lg, e, [self_heal])
	e.hp = e.mhp * 0.1
	var sh_low := _w(lg, e, [self_heal])
	e.recover_all()
	_check("w_self_heal", sh_full == [30] and sh_low == [390], [sh_full, sh_low])
	# 速度：上一招复读。E ×110、SS ×55；池里只有一招不算；SS 抢节奏（控制）×145
	e.set_meta(XTianqiEnemyAI.META_LAST, DMG_N)
	_set_enemy(e, _six("C", "C", "E"))
	var re := _w(lg, e, [DMG_N, AOE])
	_set_enemy(e, _six("C", "C", "SS"))
	var rs := _w(lg, e, [DMG_N, AOE])
	var only := _w(lg, e, [DMG_N])
	var tempo := _w(lg, e, [CTRL_REC])
	e.remove_meta(XTianqiEnemyAI.META_LAST)
	_check("w_repeat", re[0] == 330 and rs[0] == 165 and re[1] == 300 and only == [300], [re, rs, only])
	_check("w_tempo", tempo == [435], tempo)
	lg.end_battle()


# 三、实战选招
func _real_pick() -> void:
	var lg := _logic()
	var e: XEnemy = lg.enemies[0]
	for a in lg.actors:
		a.add_state(IMMUNE_ST)
	_with_actions(e, [_act(DMG_E, 5), _act(DMG_N, 5)], func():
		_set_enemy(e, _six("C", "C", "C", "E"))
		var r1 := _decide_n(lg, e, 200)
		_set_enemy(e, _six())
		var r3 := _decide_n(lg, e, 200)
		var n1: int = r1.seq.count(DMG_E)
		var n3: int = r3.seq.count(DMG_E)
		_check("real_tier1_half", n1 > 70 and n1 < 130, n1)
		_check("real_tier3_avoids_immune", n3 < 40, n3)
		_check("real_same_draws", r1.counts.get("enemy_action", 0) == 200 and r3.counts.get("enemy_action", 0) == 200, [r1.counts, r3.counts])
		var again := _decide_n(lg, e, 200)
		_check("real_determinism", again == r3))
	for a in lg.actors:
		a.remove_state(IMMUNE_ST)
	lg.end_battle()


# 四、选目标
func _targets() -> void:
	var lg := _logic()
	var e: XEnemy = lg.enemies[0]
	var foes := lg.alive(lg.actors)
	var base := foes.map(func(b): return float(b.tgr))
	var atk := XDB.rec("Skills", DMG_N)
	var dec := [atk, null]
	# 没登记：原样
	_set_enemy(e, _six("C", "C", "C", "SS"))
	_check("t_not_decided_same", XTianqiEnemyAI.target_weights(lg, e, foes, base, atk) == base)
	XTianqiEnemyAI.note_decision(lg, e, dec)
	_check("t_other_skill_same", XTianqiEnemyAI.target_weights(lg, e, foes, base, XDB.rec("Skills", AOE)) == base)
	# 2 档：最低血 +50
	_set_enemy(e, _six("C", "C", "C", "D"))
	XTianqiEnemyAI.note_decision(lg, e, dec)
	foes[2].hp = foes[2].mhp * 0.1
	var w2 := XTianqiEnemyAI.target_weights(lg, e, foes, base, atk)
	var share: float = w2[2] / w2.reduce(func(x, y): return x + y, 0.0)
	_check("t2_lowest_half", share > 0.5 and share < 0.75, [w2, share])
	foes[0].add_state(TAUNT_ST)  # 嘲讽（受击率特性 > 1）
	var tg := foes.map(func(b): return float(b.tgr))
	_check("t2_taunt_kept", TAUNT_ST > 0 and tg[0] >= 2.0 and XTianqiEnemyAI.target_weights(lg, e, foes, tg, atk) == tg, [TAUNT_ST, tg])
	foes[0].remove_state(TAUNT_ST)
	# 天生／装备的高受击率（没挂嘲讽状态）不当嘲讽：照样盯最低血（r1 P2-2）
	var hi := base.duplicate()
	hi[0] = 10.0
	var w2h := XTianqiEnemyAI.target_weights(lg, e, foes, hi, atk)
	_check("t2_high_tgr_not_taunt", not XTianqiEnemyAI.taunting(foes[0]) and w2h != hi and w2h[2] > hi[2], [w2h, hi])
	foes[2].recover_all()
	# 3 档：免疫目标 ×10
	_set_enemy(e, _six())
	var fire := XDB.rec("Skills", DMG_E)
	XTianqiEnemyAI.note_decision(lg, e, [fire, null])
	foes[1].add_state(IMMUNE_ST)
	var w3 := XTianqiEnemyAI.target_weights(lg, e, foes, base, fire)
	foes[1].remove_state(IMMUNE_ST)
	_check("t3_immune_x10", is_equal_approx(w3[1] * 10.0, w3[0]) and is_equal_approx(w3[0], base[0]), w3)
	# 4 档：能斩杀的 ×400 且排最前
	_set_enemy(e, _six("C", "C", "C", "A"))
	XTianqiEnemyAI.note_decision(lg, e, dec)
	foes[3].hp = 1.0
	var w4 := XTianqiEnemyAI.target_weights(lg, e, foes, base, atk)
	foes[3].recover_all()
	var top4 := 0
	for i in w4.size():
		if w4[i] > w4[top4]:
			top4 = i
	_check("t4_kill_first", top4 == 3 and w4[3] > 3.0 * w4[0], w4)
	# 5 档：主力 ×200（威胁也高），厚盾 ×50
	_set_enemy(e, _six("C", "C", "C", "SS"))
	XTianqiEnemyAI.note_decision(lg, e, dec)
	var core := XTianqiEnemyAI._core_index(foes)
	var w5 := XTianqiEnemyAI.target_weights(lg, e, foes, base, atk)
	var other := (core + 1) % foes.size()
	foes[other].shield = foes[other].hp
	var w5s := XTianqiEnemyAI.target_weights(lg, e, foes, base, atk)
	foes[other].shield = 0.0
	_check("t5_core_up", w5[core] >= w5.max(), [w5, core])
	_check("t5_wall_down", w5s[other] < w5[other], [w5, w5s])
	# 掷数：_random_target 开／关都只掷一次 target
	XTianqiEnemyAI.note_decision(lg, e, dec)
	var cs := _seed(lg)
	for i in 50:
		lg._random_target(foes, e, atk)
	XTianqiEnemyAI.ENABLED = false
	for i in 50:
		lg._random_target(foes, e, atk)
	_check("t_one_draw", int(cs.counts.get("target", 0)) == 100, cs.counts)
	XTianqiEnemyAI.ENABLED = true
	# 端到端：4 档点名经 decide → targets_for 落到能斩杀的那一个上多
	_with_actions(e, [_act(DMG_N, 5)], func():
		foes[3].hp = 1.0
		_seed(lg, "00000000000000b1")
		var hit := 0
		for i in 100:
			var d := lg.decide(e)
			var tl := lg.targets_for(e, d[0], d[1], true)
			if not tl.is_empty() and tl[0] == foes[3]:
				hit += 1
		foes[3].recover_all()
		XTianqiEnemyAI.ENABLED = false
		foes[3].hp = 1.0
		_seed(lg, "00000000000000b1")
		var hit_off := 0
		for i in 100:
			var d := lg.decide(e)
			var tl := lg.targets_for(e, d[0], d[1], true)
			if not tl.is_empty() and tl[0] == foes[3]:
				hit_off += 1
		foes[3].recover_all()
		XTianqiEnemyAI.ENABLED = true
		_check("t_e2e_kill_target", hit > 55 and hit_off < 40, [hit, hit_off]))
	lg.end_battle()


# 五、低韧性慌乱
func _panic() -> void:
	var lg := _logic()
	var e: XEnemy = lg.enemies[0]
	var cs := _seed(lg)
	_set_enemy(e, _six("C", "C", "C", "C", "E"))
	_check("p_full_hp_no_draw", XTianqiEnemyAI.panic(lg, e).is_empty() and not cs.counts.has("six_dim_panic"), cs.counts)
	e.hp = e.mhp * 0.2
	cs.ints["six_dim_panic"] = 0
	for k in 3:
		cs.ints["six_dim_panic_kind"] = k
		var p := XTianqiEnemyAI.panic(lg, e)
		var want = [XBattleLogic.GUARD_SKILL, int(e.attack_skill().id), -1][k]
		_check("p_kind_%d" % k, p.size() == 2 and (int(p[0].id) if p[0] is Dictionary else -1) == want and p[1] == null, p)
		var logs := XTianqiEnemyAI.take_logs(e)
		_check("p_text_%d" % k, logs.size() == 1 and str(logs[0].text) == XTianqiEnemyAI.panic_text(e, k) and str(logs[0].text).begins_with(e.display_name() + "阵脚大乱，")
			and bool(logs[0].get("tianqi_fit", false)) and XTianqiEnemyAI.take_logs(e).is_empty(), logs)
	cs.ints["six_dim_panic"] = 20  # E＝20%：掷到 20 不慌
	_check("p_E_20pct_edge", XTianqiEnemyAI.panic(lg, e).is_empty())
	# D：<20% 才掷、10%
	_set_enemy(e, _six("C", "C", "C", "C", "D"))
	cs.ints["six_dim_panic"] = 9
	e.hp = e.mhp * 0.22
	var before := int(cs.counts.get("six_dim_panic", 0))
	_check("p_D_above_line", XTianqiEnemyAI.panic(lg, e).is_empty() and int(cs.counts.get("six_dim_panic", 0)) == before)
	e.hp = e.mhp * 0.15
	_check("p_D_low", not XTianqiEnemyAI.panic(lg, e).is_empty())
	XTianqiEnemyAI.take_logs(e)
	cs.ints["six_dim_panic"] = 10
	_check("p_D_10pct_edge", XTianqiEnemyAI.panic(lg, e).is_empty())
	# E：满血但本回合同伴刚倒下也掷
	_set_enemy(e, _six("C", "C", "C", "C", "E"))
	e.recover_all()
	cs.ints["six_dim_panic"] = 0
	XRaven.any_death = true
	_check("p_E_mate_died", not XTianqiEnemyAI.panic(lg, e).is_empty())
	XTianqiEnemyAI.take_logs(e)
	_set_enemy(e, _six("C", "C", "C", "C", "D"))
	_check("p_D_mate_died_no", XTianqiEnemyAI.panic(lg, e).is_empty())
	XRaven.any_death = false
	# 韧性 C 起、首领、精英以外类别：0 触发、不掷
	e.hp = e.mhp * 0.05
	before = int(cs.counts.get("six_dim_panic", 0))
	for l in ["C", "B", "A", "S", "SS", "SSS"]:
		_set_enemy(e, _six("C", "C", "C", "C", l))
		_check("p_none_" + l, XTianqiEnemyAI.panic(lg, e).is_empty())
	_set_enemy(e, _six("C", "C", "C", "C", "E", "C", "strong"))
	_check("p_class_boss_none", XTianqiEnemyAI.panic(lg, e).is_empty())
	_set_enemy(e, _six("C", "C", "C", "C", "E"))
	e.boss_difficulty_boss = true
	_check("p_boss_none", XTianqiEnemyAI.panic(lg, e).is_empty())
	e.boss_difficulty_boss = false
	_check("p_no_draws_when_ineligible", int(cs.counts.get("six_dim_panic", 0)) == before, cs.counts)
	# 战报进 act 的记录；同种子整回合可复现
	cs.ints.clear()
	var run := func(hex: String) -> Array:
		var l2 := _logic()
		var e2: XEnemy = l2.enemies[0]
		_set_enemy(e2, _six("C", "C", "C", "C", "E"))
		e2.hp = e2.mhp * 0.1
		_seed(l2, hex)
		var texts := []
		for i in 40:
			var d := l2.decide(e2)
			for x in l2.act(e2, d[0], d[1]):
				if x is Dictionary and str(x.get("type", "")) == "battle_text":
					texts.append(str(x.text))
			e2.hp = e2.mhp * 0.1
			for a in l2.actors:
				a.recover_all()
		l2.end_battle()
		return texts
	var t1: Array = run.call("00000000000000c3")
	var t2: Array = run.call("00000000000000c3")
	_check("p_determinism", t1 == t2 and t1.size() > 0 and t1.size() < 20, t1.size())
	lg.end_battle()


# 六、四骑士
func _knight_run(line: String, mode: String, on: bool, wit: String) -> Dictionary:
	var s := _state(true, 20000000.0)
	XTianqiHorsemen.prepare(line, s, mode)
	var lg := XBattleLogic.new()
	lg.setup(0, s)
	XTianqiSixDim.data().get("knights", {})[line] = _six("C", "C", "C", wit, "C", "C", "knight")
	XTianqiEnemyAI.ENABLED = on
	var cs := _seed(lg, "00000000000000d5")
	var kinds := []
	var targets := []
	var kn = XTianqiHorsemen.fight(lg).get("knight")
	var tier := XTianqiEnemyAI.tier(lg, kn)
	var weights := XTianqiEnemyAI.knight_target_weights(lg, kn, lg.alive(lg.actors))
	var cmds := {}
	for a in lg.actors:
		cmds[a] = [XDB.rec("Skills", XBattleLogic.GUARD_SKILL), null]
	for n in 8:
		if lg.is_over():
			break
		for x in lg.run_turn(cmds):
			if x is Dictionary and str(x.get("type", "")) == "action" and x.get("skill") is Dictionary and x.skill.has("tianqi_horseman"):
				kinds.append(str(x.skill.tianqi_horseman))
			if x is Dictionary and str(x.get("type", "")) == "hit" and x.get("target") != null:
				targets.append(lg.actors.find(x.target))
		for a in lg.actors:
			a.recover_all()
	var draws := 0
	for k in cs.counts:
		draws += int(cs.counts[k])
	lg.end_battle()
	XTianqiEnemyAI.ENABLED = true
	return {"kinds": kinds, "targets": targets, "counts": cs.counts.duplicate(), "draws": draws, "tier": tier, "weights": weights}


func _knights() -> void:
	var wits := {"death": "D", "war": "B", "famine": "A", "plague": "SS"}  # 四条线各占 2～5 档
	for line in XTianqiHorsemen.LINES:
		for mode in ["body", "shadow"]:
			var off := _knight_run(line, mode, false, wits[line])
			var on := _knight_run(line, mode, true, wits[line])
			var tag: String = line + "_" + mode
			_check("k_skills_same_" + tag, on.kinds == off.kinds and not on.kinds.is_empty(), [on.kinds, off.kinds])
			_check("k_draws_same_" + tag, on.counts == off.counts, [on.counts, off.counts])
			_check("k_weighted_" + tag, on.tier >= 2 and on.weights.size() >= 2 and off.weights.is_empty(), [on.tier, on.weights, off.weights])
			if mode == "body":
				var e1 := _knight_run(line, mode, true, "E")  # 1 档＝原版均匀，目标也一致
				_check("k_tier1_same_" + tag, e1.kinds == off.kinds and e1.targets == off.targets and e1.counts == off.counts, [e1.targets, off.targets])
	# 加权：2 档最低血一人占一半以上；5 档主力 ×200
	var s := _state(true, 20000000.0)
	XTianqiHorsemen.prepare("war", s)
	var lg := XBattleLogic.new()
	lg.setup(0, s)
	var kn = XTianqiHorsemen.fight(lg).get("knight")
	var live := lg.alive(lg.actors)
	XTianqiSixDim.data().get("knights", {})["war"] = _six("C", "C", "C", "D", "C", "C", "knight")
	live[1].hp = live[1].mhp * 0.1
	var w2 := XTianqiEnemyAI.knight_target_weights(lg, kn, live)
	_check("k2_lowest_half", w2.size() == live.size() and w2[1] * 2 >= w2.reduce(func(x, y): return x + y, 0), w2)
	live[1].recover_all()
	XTianqiSixDim.data().get("knights", {})["war"] = _six("C", "C", "C", "SS", "C", "C", "knight")
	var w5 := XTianqiEnemyAI.knight_target_weights(lg, kn, live)
	_check("k5_core", w5[XTianqiEnemyAI._core_index(live)] >= w5.max(), w5)
	_check("k_chosen_kept", XTianqiHorsemen._pick_target(lg, live[2], kn) == live[2])
	lg.end_battle()


# 五条悟试炼：回合表在六维 AI 之前，影子录成宗师也不变
func _gojo() -> void:
	var w := XTianqiSkills.ids(XTier.WEAK, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))
	var lineup := [w[0], w[1], w[2]]
	var s := XTianqi.start_new_game(3, "lianyu", lineup)
	XTianqi.take_pending()
	XState.current = s
	for id in lineup + [XGojo.ACTOR]:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 132
	var seqs := []
	for on in [false, true]:
		XTianqiEnemyAI.ENABLED = on
		XTianqiGojoTrial.begin(s, 1)
		XTianqiGojoTrial.prepare(1)
		var lg := XBattleLogic.new()
		lg.setup(int(XTianqiGojoTrial.data().troop), s)
		var e: XEnemy = lg.enemies[0]
		_set_enemy(e, _six("SSS", "C", "SS", "SS", "E"))
		_seed(lg)
		var seq := []
		for n in [1, 1, 2, 2, 3, 3]:
			lg.turn = n
			var d := lg.decide(e)
			seq.append(int(d[0].id) if d[0] is Dictionary else -1)
		seqs.append(seq)
		lg.end_battle()
	XTianqiEnemyAI.ENABLED = true
	_check("gojo_trial_same", seqs[0] == seqs[1] and not seqs[0].has(-1), seqs)


# 七、不改数值；我方自动战斗不变
# P2-3（小A 复核 r2）：队伍带绑定、开自律的璇时，XXuanBattle.start_action 在 execute 前先 targets_for 预检一次；
# 六维点名登记不能被它清掉（原来清在 targets_for 非 confusable 处）。改到 act 末尾和 _forced_run 开头清。
func _xuan_auto() -> void:
	var w := _ids()
	var lineup := [w[0], w[1], w[2], XXuanBattle.XUAN]
	var s := XTianqi.start_new_game(3, "lianyu", lineup)  # 炼狱：可带一名超强者（璇）
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	var free_slot := s.battle_slots.find(0)
	if free_slot >= 0 and not s.battle_slots.has(XXuanBattle.XUAN):
		s.battle_slots[free_slot] = XXuanBattle.XUAN
	var xa: XActor = s.actor(XXuanBattle.XUAN)
	xa.change_level(60)
	s.actor_advance[XXuanBattle.XUAN] = 3
	XTusuXuan.sync_marks(s, xa)
	XXuanChart.set_control(s, xa, "auto")
	for id in lineup:
		s.actor(id).add_param(0, 1e9)
		s.actor(id).refresh_passive()
		s.actor(id).recover_all()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var x = XXuanBattle.xuan()
	var host = lg.actors.filter(func(b): return b != x)[0] if x != null else null
	var bound: bool = x != null and XBinding.bind(x, host)
	_check("xuan_setup", x != null and bound and XXuanBattle.auto_enabled() and XBinding.is_bound(x), [x != null, bound, XXuanBattle.auto_enabled()])
	var e: XEnemy = lg.enemies[0]
	_set_enemy(e, _six("C", "C", "C", "A"))  # 战商 A＝4 档：能斩杀的 ×600
	var free := lg.alive(lg.actors).filter(func(b): return b != x and b != host)
	var prey: XActor = free[0] if not free.is_empty() else null
	var count := func(on: bool) -> int:
		XTianqiEnemyAI.ENABLED = on
		_seed(lg, "00000000000000f3")
		var n := 0
		for i in 60:
			for b in lg.actors:
				b.recover_all()
			prey.hp = 1.0
			var d := lg.decide(e)
			var held := is_same(XTianqiEnemyAI._decided_user, e) if on else true
			for l in lg.act(e, d[0], d[1]):
				if l is Dictionary and str(l.get("type", "")) == "hit" and is_same(l.get("user"), e) and is_same(l.get("target"), prey):
					n += 1
					break
			if on and not held:
				n -= 1000
		XTianqiEnemyAI.ENABLED = true
		return n
	_with_actions(e, [_act(DMG_N, 5)], func():
		var on_hits: int = count.call(true)
		var off_hits: int = count.call(false)
		_check("xuan_auto_keeps_weights", prey != null and on_hits > off_hits + 15 and on_hits > 30, [on_hits, off_hits])
		_check("xuan_cleared_after_act", XTianqiEnemyAI._decided_user == null))
	# 强制行动开头清登记
	XTianqiEnemyAI.note_decision(lg, e, [XDB.rec("Skills", DMG_N), null])
	lg._forced_run(e, XDB.rec("Skills", DMG_N), null, null)
	_check("forced_run_clears", XTianqiEnemyAI._decided_user == null)
	for b in lg.actors:
		b.recover_all()
	lg.end_battle()


func _no_numbers() -> void:
	var lg := _logic()
	var e: XEnemy = lg.enemies[0]
	var a: XActor = lg.actors[0]
	var snap := func() -> Array:
		var ev := XBattleEval.create_for(lg, e)
		return [e.mhp, e.atk, e.def, e.mat, e.mdf, e.agi, ev.hit_value(e, a, XDB.rec("Skills", DMG_N), 1000.0), lg.state_rate(a, 1)]
	XTianqiEnemyAI.ENABLED = false
	_clear_enemy(e)
	var off: Array = snap.call()
	XTianqiEnemyAI.ENABLED = true
	_set_enemy(e, _six("SSS", "SSS", "SSS", "SSS", "C", "SSS"))  # 韧性 C：P3-1 边界
	var on: Array = snap.call()
	_check("numbers_same", on == off, [on, off])
	# 我方自动战斗：开／关同种子选招一致
	lg.auto = true
	var picks := []
	for flag in [false, true]:
		XTianqiEnemyAI.ENABLED = flag
		_seed(lg, "00000000000000e9")
		var row := []
		for x in lg.actors:
			var d := lg.auto_battle_action(x)
			row.append([int(d[0].id) if d[0] is Dictionary else -1, lg.actors.find(d[1]) if d[1] is XActor else lg.enemies.find(d[1])])
		picks.append(row)
	XTianqiEnemyAI.ENABLED = true
	_check("auto_battle_same", picks[0] == picks[1], picks)
	lg.end_battle()


# 八、控制标签正则预编译
func _control_regex() -> void:
	var re := RegEx.create_from_string("(?i)<BuffType:\\s*(?:沉默|封印|眩晕|睡眠|麻痹|混乱|魅惑|恐惧|冰冻)\\s*>")
	var bad := []
	var n := 0
	for st in XDB.table("States"):
		if not st is Dictionary or st.is_empty():
			continue
		var id := int(st.id)
		var want: bool = not (id in [1, XEnemy.BOSS_ARMOR_STATE]) and (int(st.get("restriction", 0)) > 0 or re.search(str(st.get("note", ""))) != null \
			or st.get("traits", []).any(func(t): return int(t.code) in [42, 44]))
		if XEnemy.boss_control_state(id) != want:
			bad.append(id)
		n += 1
	_check("control_regex_same", bad.is_empty() and n > 100, [bad, n])
