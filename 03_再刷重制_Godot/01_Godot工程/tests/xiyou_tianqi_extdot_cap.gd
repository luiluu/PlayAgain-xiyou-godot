extends Node
## 【cc·T453】D273 封顶纳入 XExtDot：传承 2617 火海披风（开战给全体敌人挂 State 243 火海，XExtDot 按血量 100%±20%）
## 对守层者／首领的回合末持续伤害与再生合计每回合 ≤ ⌊最大生命×5%⌋（表 boss_neg_hrg_cap_extdot_states、开关 BOSS_NEG_HRG_CAP）。
## 一、带披风开战：22／29／30 层守层者与副本首领都挂上 243；三个回合键各量一次，XExtDot＋再生合计 ≤5%；
## 二、243 ＋ 灼伤 I～V（再生 −14%）同挂：合计仍 ≤5%（预算两路共用）；
## 三、普通小怪不封（1 层嘤嘤怪挂 243 照扣约 100%）；四、开关关：守层者回到整血级掉血；五、西游档零变化（同样挂 243 不封）；
## 六、不在表里的状态（灼伤单独）不走 XExtDot 预算，仍只由再生那一路封顶。

var results: Array = []
const BURN5 := [17, 18, 19, 20, 21]


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _state(tianqi: bool) -> XState:
	var lineup := [1, 2, 8, 9, 10]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, "jianxian", lineup)
		XTianqi.take_pending()
		for id in lineup:
			XTianqi._joining = true
			s.add_actor(int(id))
			XTianqi._joining = false
	else:
		s = XState.new_game(3, 1, [8, 9, 10])
	var legacy := XTianqi.legacy_of("jianxian") if tianqi else 3
	for i in range(1, 9):
		s.flags["DCultyL%d" % i] = i == legacy
	s.map_id = 4
	XState.current = s
	return s


func _wear_cloak(s: XState) -> void:
	var a: XActor = s.actor(1)
	a.change_level(81)
	var item := XGear.create("armor", 2617, s)
	a.equips[a.equip_slots().find(int(item.etypeId))] = item
	a.refresh_passive()


func _add_states(e: XEnemy, ids: Array) -> void:
	for sid in ids:
		if not e.state_ids.has(int(sid)):
			e.state_ids.append(int(sid))
		XActor.state_touch(int(sid))
	e.param_mark_dirty()


## 一个回合末：XExtDot.tick → _regenerate；返回掉血量（血量每回合补满）。turn_key 变一个，持续伤害的随机波动跟着换。
func _turn_loss(logic: XBattleLogic, e: XEnemy, turn_key: int) -> float:
	logic.turn = turn_key
	e.hp = e.mhp
	XExtDot.tick(logic, e, [])
	logic._regenerate(e, [])
	return float(e.mhp) - float(e.hp)


func _cloak_battle(s: XState, troop: int) -> Array:
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	lg._battle_start_states()
	return [lg, lg.enemies[0]]


func _run() -> void:
	XMessageBox.auto = true
	MVInterpreter.fixed_random = 0.5
	XEnemy.force_roll = 100.0
	var was_cap := XTianqiCombat.BOSS_NEG_HRG_CAP
	var was_strip := XGuardianRework.STRIP
	XTianqiCombat.BOSS_NEG_HRG_CAP = true
	XGuardianRework.STRIP = true

	var s := _state(true)
	_wear_cloak(s)
	# 一、带披风开战，22／29／30 层守层者、副本首领：243 挂上，三个回合键各量一次
	for entry in [["f22", 458], ["f29", 465], ["f30", 466], ["dungeon", 422]]:
		var pair := _cloak_battle(s, int(entry[1]))
		var lg: XBattleLogic = pair[0]
		var e: XEnemy = pair[1]
		var budget := floorf(float(e.mhp) * 0.05)
		_check("tq.%s.cloak_state_243_applied" % entry[0], e.state_ids.has(243), e.state_ids)
		var worst := 0.0
		var best := INF
		for k in [11, 22, 33]:
			var loss := _turn_loss(lg, e, k)
			worst = maxf(worst, loss)
			best = minf(best, loss)
		_check("tq.%s.cloak_dot_capped_5pct" % entry[0], worst <= budget + 0.5 and best >= budget - 0.5, [worst, best, budget, e.mhp])

	# 二、243 ＋ 灼伤 I～V（再生 −14%）同挂：合计仍 ≤5%
	var pair2 := _cloak_battle(s, 465)
	var lg2: XBattleLogic = pair2[0]
	var e2: XEnemy = pair2[1]
	_add_states(e2, BURN5)
	var budget2 := floorf(float(e2.mhp) * 0.05)
	var worst2 := 0.0
	for k in [11, 22, 33]:
		worst2 = maxf(worst2, _turn_loss(lg2, e2, k))
	_check("tq.f29.cloak_plus_burn_total_le_5pct", worst2 <= budget2 + 0.5, [worst2, budget2])

	# 三、普通小怪（1 层嘤嘤怪，敌群 1）：243 不封顶
	var pair3 := _cloak_battle(s, 1)
	var emob: XEnemy = pair3[1]
	var lmob := _turn_loss(pair3[0], emob, 11)
	_check("tq.mob.cloak_not_capped", not XTianqiCombat.is_neg_hrg_boss(emob) and lmob > float(emob.mhp) * 0.5, [lmob, emob.mhp])

	# 四、开关关：守层者回到整血级掉血
	XTianqiCombat.BOSS_NEG_HRG_CAP = false
	var pair4 := _cloak_battle(s, 465)
	var e4: XEnemy = pair4[1]
	var l4 := _turn_loss(pair4[0], e4, 11)
	_check("tq.f29.switch_off_full_dot", l4 > float(e4.mhp) * 0.5, [l4, e4.mhp])
	XTianqiCombat.BOSS_NEG_HRG_CAP = true

	# 五、西游档：同样挂 243，照原版 10000±20%（不换成按血量比例、不封），开关开／关一样
	var sx := _state(false)
	var lx := XBattleLogic.new()
	lx.setup(4, sx)
	var ex: XEnemy = lx.enemies[0]
	_add_states(ex, [243])
	var lx_on := _turn_loss(lx, ex, 11)
	XTianqiCombat.BOSS_NEG_HRG_CAP = false
	var lx_off := _turn_loss(lx, ex, 11)
	_check("xiyou.cloak_dot_unchanged_on_eq_off", absf(lx_on - 10000.0) < 3000.0 and absf(lx_off - 10000.0) < 3000.0 and not ex.has_meta(XTianqiCombat.META_DOT_USED), [lx_on, lx_off, ex.mhp])
	XTianqiCombat.BOSS_NEG_HRG_CAP = true

	# 六、灼伤单独（不在 XExtDot 预算表里）：仍只走再生那一路 5% 封顶，预算账不残留
	XState.current = s
	var pair6 := _cloak_battle(s, 465)
	var e6: XEnemy = pair6[1]
	e6.state_ids.erase(243)
	_add_states(e6, BURN5)
	var l6 := _turn_loss(pair6[0], e6, 11)
	_check("tq.f29.burn_only_still_5pct_no_meta_left", is_equal_approx(l6, floorf(float(e6.mhp) * 0.05)) and not e6.has_meta(XTianqiCombat.META_DOT_USED), [l6, e6.mhp])

	XTianqiCombat.BOSS_NEG_HRG_CAP = was_cap
	XGuardianRework.STRIP = was_strip
	XEnemy.force_roll = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
