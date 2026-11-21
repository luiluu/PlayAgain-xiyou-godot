extends Node
## T331 自动战斗放复活技（XSmartAI.o_revive_ce）专项：
## 一、六个带公共事件的复活技（4549、622、825、3760、4829、5782）认得出是复活、公共事件里没有危险指令，能放时进候选；
## 二、有队友倒下：会复活的人选复活技、目标是倒下的那个；没人倒下：不选；MP 不够：不选；开关关：照原版不选；
## 三、同一回合同一个倒下的人只安排一次（note_revive／revive_planned），下一回合重新算；
## 四、没人倒下时开关开关选招完全一样（不影响非复活技能）；
## 五、整回合自动战斗（run_turn）：两个会复活的人只有一个去救，救起来；公共事件 987 的强制行动只跑一次、事件不卡住；
## 六、天启篇存档：改前已会放（O-623），开关开关都选复活技。
const BIG_HP := 1e12
var results := []


## 记下整回合里每次行动与强制行动，不改结算
class RecLogic extends XBattleLogic:
	var acts: Array = []
	var forced: Array = []

	func act(u: XBattler, skill, target) -> Array:
		var logs := super(u, skill, target)
		acts.append({"user": u, "id": int(skill.get("id", 0)) if skill is Dictionary else 0, "target": target,
			"alive_after": target.is_alive() if target is XBattler else false})
		return logs

	func _forced_run(u: XBattler, skill: Dictionary, target: XBattler, first_subject: XBattler) -> Array:
		forced.append(int(skill.get("id", 0)))
		return super(u, skill, target, first_subject)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	seed(20261121)
	XSave.dir_override = "user://test_xiyou_smart_ai_revive"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XConfig._loaded_path = ""
	XConfig.ensure_loaded()
	XConfig.set_smart_ai(true)
	_data()
	_choose_cases()
	_plan()
	_untouched()
	_whole_turn()
	_tianqi()
	XSmartAI.o_revive_ce = true
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail).left(600))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 西游档：16 克莱德领队＋8、9、10，99 级，敌人血加厚（伤害分压低，复活 60000 分稳在最前）
func _setup(logic: XBattleLogic = null) -> XBattleLogic:
	var s := XState.new_game(1, 16, [8, 9, 10])
	s.items = {}
	XState.current = s
	if logic == null:
		logic = XBattleLogic.new()
	logic.setup(2, s)
	logic.turn = 1
	for a in logic.actors:
		a.change_level(99)
		a.refresh_passive()
		a.recover_all()
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += BIG_HP
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	return logic


func _actor(logic: XBattleLogic, id: int) -> XActor:
	for a in logic.actors:
		if int(a.actor_id) == id:
			return a
	return null


func _data() -> void:
	XSmartAI.o_revive_ce = true
	for id in [4549, 622, 825, 3760, 4829, 5782]:
		var rec := XDB.rec("Skills", id)
		var ces: Array = rec.get("effects", []).filter(func(e): return int(e.code) == 44).map(func(e): return int(e.dataId))
		_check("data.%d.revives" % id, XSmartAI.revives(rec))
		_check("data.%d.ce_safe" % id, not ces.is_empty() and ces.all(func(c): return not XSmartAI._ce_dangerous(c, {})), ces)
	_check("data.attack_not_revive", not XSmartAI.revives(XDB.rec("Skills", XBattleLogic.ATTACK_SKILL)))
	var logic := _setup()
	var healer := _actor(logic, 16)
	healer.learn_skill(4549)
	healer.learn_skill(622)
	var ai := XSmartAI.new(logic, healer)
	_check("legal.4549", ai.legal(XDB.rec("Skills", 4549), false), [healer.mp, healer.mmp])
	_check("legal.622", ai.legal(XDB.rec("Skills", 622), false))
	XSmartAI.o_revive_ce = false
	_check("legal.off_4549", not ai.legal(XDB.rec("Skills", 4549), false))
	XSmartAI.o_revive_ce = true


func _pick(logic: XBattleLogic, a: XActor) -> Dictionary:
	var r := XSmartAI.choose(logic, a)
	return {"id": int(r.skill.id) if r.has("skill") else 0, "target": r.get("target"), "rank": r.get("candidates", []).map(func(x): return [x.id, x.score])}


func _choose_cases() -> void:
	# 倒一人：会复活的人放复活技，目标是倒下的
	var logic := _setup()
	var healer := _actor(logic, 16)
	healer.learn_skill(4549)
	var down := _actor(logic, 9)
	down.add_state(1)
	_check("setup.dead", down.is_dead())
	var p := _pick(logic, healer)
	_check("one_down.picks_revive", p.id == 4549, p)
	_check("one_down.targets_dead", p.target == down, p)
	# 没人倒：不放
	logic = _setup()
	healer = _actor(logic, 16)
	healer.learn_skill(4549)
	p = _pick(logic, healer)
	_check("none_down.no_revive", p.id != 4549 and p.id != 0, p)
	# MP 不够：不放（MP 留 1499，4549 要 1500）
	logic = _setup()
	healer = _actor(logic, 16)
	healer.learn_skill(4549)
	_actor(logic, 9).add_state(1)
	healer.mp = minf(healer.mp, 1499.0)
	p = _pick(logic, healer)
	_check("mp_short.no_revive", p.id != 4549, [p, healer.mp])
	# 冷却中：不放（825 冷却 6）
	logic = _setup()
	healer = _actor(logic, 10)
	healer.learn_skill(825)
	_actor(logic, 9).add_state(1)
	var free := _pick(logic, healer)
	_check("cooldown.free_picks", free.id == 825, [free, healer.mp])
	healer.pay_cooldown(XDB.rec("Skills", 825))
	var cd := _pick(logic, healer)
	_check("cooldown.no_revive", healer.cooldown_left(825) > 0 and cd.id != 825, [cd, healer.cooldown_left(825)])
	# 开关关：照原版不放
	logic = _setup()
	healer = _actor(logic, 16)
	healer.learn_skill(4549)
	_actor(logic, 9).add_state(1)
	XSmartAI.o_revive_ce = false
	p = _pick(logic, healer)
	XSmartAI.o_revive_ce = true
	_check("switch_off.no_revive", p.id != 4549, p)


## 同一回合同一个倒下的人只安排一次；下一回合重新算；全体复活记下所有倒下的
func _plan() -> void:
	var logic := _setup()
	var a := _actor(logic, 16)
	var b := _actor(logic, 8)
	a.learn_skill(4549)
	b.learn_skill(622)
	var down := _actor(logic, 9)
	down.add_state(1)
	var first := logic.auto_battle_action(a)
	_check("plan.first_revives", int(first[0].id) == 4549 and first[1] == down, [first[0].get("id"), first[1]])
	_check("plan.recorded", XSmartAI.revive_planned(logic, down))
	var second := logic.auto_battle_action(b)
	_check("plan.second_not_same_target", not (XSmartAI.revives(second[0]) and (second[1] == down or second[1] == null)), [second[0].get("id"), second[1]])
	logic.turn += 1
	_check("plan.next_turn_clear", not XSmartAI.revive_planned(logic, down))
	var again := logic.auto_battle_action(b)
	_check("plan.next_turn_revives", int(again[0].id) == 622 and again[1] == down, [again[0].get("id"), again[1]])
	# 别的战斗（另一个 logic）不受这份安排影响
	var other := _setup()
	_check("plan.other_logic", not XSmartAI.revive_planned(other, _actor(other, 9)))
	# 两人倒下、全体复活 4829：记下两个
	logic = _setup()
	a = _actor(logic, 16)
	a.learn_skill(4829)
	_actor(logic, 9).add_state(1)
	_actor(logic, 10).add_state(1)
	var all := logic.auto_battle_action(a)
	_check("plan.all_revive_pick", int(all[0].id) == 4829 or a.mp < 1800.0, [all[0].get("id"), a.mp])
	if int(all[0].id) == 4829:
		_check("plan.all_marks_both", XSmartAI.revive_planned(logic, _actor(logic, 9)) and XSmartAI.revive_planned(logic, _actor(logic, 10)))
	# 开关关：不记
	logic = _setup()
	a = _actor(logic, 16)
	a.learn_skill(622)
	_actor(logic, 9).add_state(1)
	XSmartAI.o_revive_ce = false
	XSmartAI.note_revive(logic, a, XDB.rec("Skills", 622), _actor(logic, 9))
	_check("plan.off_not_planned", not XSmartAI.revive_planned(logic, _actor(logic, 9)))
	XSmartAI.o_revive_ce = true


## 没人倒下时，会复活技的人开关开关选招一样（技能与分数）
func _untouched() -> void:
	for id in [16, 8, 9, 10]:
		var logic := _setup()
		var a := _actor(logic, id)
		for sk in [4549, 622, 825, 4829, 5782]:
			a.learn_skill(sk)
		var on := _pick(logic, a)
		XSmartAI.o_revive_ce = false
		var off := _pick(logic, a)
		XSmartAI.o_revive_ce = true
		# 候选表里多出来的复活技都是 0 分（不会被选），只比有分的
		var pos := func(x): return float(x[1]) > 0.0
		_check("untouched.%d" % id, on.id == off.id and on.target == off.target and str(on.rank.filter(pos)) == str(off.rank.filter(pos)), [on, off])
		_check("untouched.%d.revive_zero" % id, on.rank.filter(func(x): return int(x[0]) in [4549, 622, 825, 4829, 5782]).all(func(x): return float(x[1]) == 0.0), on.rank)


## 整回合自动战斗：16 会次级复活术（公共事件 987，会毒奶粉 4551 → 强制毒奶术 4552）、8 会复苏之歌；9 倒下
func _whole_turn() -> void:
	var logic: RecLogic = _setup(RecLogic.new())
	var a := _actor(logic, 16)
	var b := _actor(logic, 8)
	a.learn_skill(4549)
	a.learn_skill(4551)
	b.learn_skill(622)
	var down := _actor(logic, 9)
	down.add_state(1)
	logic.auto = true
	logic.message_responder = func(msg): return msg.get("default", null)
	logic.turn = 0
	var logs := logic.run_turn({})
	var revives := logic.acts.filter(func(x): return x.id in [4549, 622])
	_check("turn.one_reviver", revives.size() == 1, logic.acts.map(func(x): return [x.user.actor_id if x.user is XActor else -1, x.id]))
	_check("turn.revived", not revives.is_empty() and revives[0].target == down and revives[0].alive_after,
		revives.map(func(x): return [x.id, x.alive_after]))
	_check("turn.no_waiting", not logic.is_event_waiting())
	_check("turn.cursor_clear", logic._runner == null and logic._check.is_empty())
	var by_a := revives.filter(func(x): return x.id == 4549).size()
	_check("turn.ce_force_once", logic.forced.count(4552) == by_a, [logic.forced, by_a])
	_check("turn.ce_no_skipped", logic.common_event_skipped.filter(func(s): return str(s).contains("公共事件987")).is_empty(), logic.common_event_skipped)
	# 下一回合没人倒下：不放复活
	var before := logic.acts.size()
	if not logic.is_over():
		logic.run_turn({})
		var later := logic.acts.slice(before).filter(func(x): return x.id in [4549, 622])
		_check("turn2.no_revive_when_alive", down.is_dead() or later.is_empty(), later.map(func(x): return x.id))


## 天启篇存档：同样放
func _tianqi() -> void:
	XTianqiSkills.reload_table()
	var s := XTianqi.start_new_game(3, "lianyu", [1, 100, 131])
	XTianqi.take_pending()
	for id in [1, 100, 131]:
		XTianqi._joining = true
		s.add_actor(id)
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in [1, 100, 131]:
		s.actor(id).change_level(60)
	s.battle_slots = [1, 100, 131, 0, 0]
	var logic := XBattleLogic.new()
	logic.setup(2, s)
	logic.turn = 1
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += BIG_HP
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	_check("tianqi.on", XSmartAI.tq_on())
	print("INFO tianqi actors ", logic.actors.map(func(x): return x.actor_id))
	var healer: XActor = logic.actors[0]
	healer.learn_skill(622)
	var down: XActor = logic.actors[1]
	down.add_state(1)
	var p := _pick(logic, healer)
	_check("tianqi.picks_revive", p.id == 622 and p.target == down, p)
	XSmartAI.o_revive_ce = false
	var off := _pick(logic, healer)
	XSmartAI.o_revive_ce = true
	# 改前天启篇已放行（O-623 tq_ce_ok，六个都在重构表里）：622 关开关也照选，5782 关开关也合法——天启篇本单只多了「同回合同目标只派一次」
	_check("tianqi.before_already_622", off.id == 622 and XTianqiSkills.has(622), off)
	healer.learn_skill(5782)
	var ai := XSmartAI.new(logic, healer)
	var r5782 := XDB.rec("Skills", 5782)
	var on_legal := ai.legal(r5782, false) or healer.mp < float(r5782.get("mpCost", 0))
	XSmartAI.o_revive_ce = false
	var off_legal := ai.legal(r5782, false)
	XSmartAI.o_revive_ce = true
	print("INFO tianqi 5782 type=%d mp=%d/%d legal_on=%s legal_off=%s" % [int(r5782.damage.type), int(healer.mp), int(r5782.get("mpCost", 0)), ai.legal(r5782, false), off_legal])
	_check("tianqi.5782_legal_both", on_legal and off_legal)  # 天启篇重构后的 5782 改前也放行
