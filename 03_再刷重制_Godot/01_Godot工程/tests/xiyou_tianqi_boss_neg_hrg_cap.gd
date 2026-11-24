extends Node
## 【小A·T405】天启篇守层者与首领回合末负 HP 再生封顶（D273，Kyo 11-23）：
## - 天启篇存档下，守层者（含残血变身后入魔 538）、副本首领（422 嘤孙）等首领敌人回合末负 HP 再生
##   （灼伤 I～V 叠加 −14%、再叠中毒 −24% 等）合计每回合最多扣表里 boss_neg_hrg_cap_pct%（5%）最大生命；
## - 单条未超上限的状态（如灼伤 II −2%）照扣不放大；
## - 带正再生的守层者（11 层，STRIP=false）正再生照旧 ×w²、负再生封顶 −5%，合算精确；
## - 普通小怪（1 层嘤嘤怪）不封顶，挂灼伤 I～V 照扣 14%；
## - 开关回退 XTianqiCombat.BOSS_NEG_HRG_CAP=false 后守层者回到 14%；
## - 西游存档零变化，开关开与关逐值一致（照原版 ×w²）。

var results: Array = []
const BURN5 := [17, 18, 19, 20, 21]  # 6133 永恒之火：灼伤 I～V，天启篇合计 -14%（19 为 -2%）


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


func _add_states(e: XEnemy, ids: Array) -> void:
	for sid in ids:
		e.state_ids.append(int(sid))
		XActor.state_touch(int(sid))
	e.param_mark_dirty()


func _tick_loss(logic: XBattleLogic, e: XEnemy) -> float:
	var mhp := float(e.mhp)
	e.hp = mhp
	logic._regenerate(e, [])
	return mhp - float(e.hp)


func _run() -> void:
	XMessageBox.auto = true
	MVInterpreter.fixed_random = 0.5
	XEnemy.force_roll = 100.0
	seed(20261123)
	var was_cap := XTianqiCombat.BOSS_NEG_HRG_CAP
	var was_strip := XGuardianRework.STRIP
	XTianqiCombat.BOSS_NEG_HRG_CAP = true
	XGuardianRework.STRIP = true

	# 1. 29 层守层者（太白金星 465）挂 灼伤 I～V（-14%）：天启篇封顶 5%
	var s := _state(true)
	var logic := XBattleLogic.new()
	logic.setup(465, s)
	var e29: XEnemy = logic.enemies[0]
	_add_states(e29, BURN5)
	var loss29 := _tick_loss(logic, e29)
	var want29 := -floorf(float(e29.mhp) * -0.05)
	_check("tq.f29.burn5_capped_5pct", is_equal_approx(loss29, want29), [loss29, want29, e29.mhp])

	# 2. 22 层守层者（三眼娃 458）挂 灼伤 I～V + 中毒（-24%）：仍封顶 5%
	var logic22 := XBattleLogic.new()
	logic22.setup(458, s)
	var e22: XEnemy = logic22.enemies[0]
	_add_states(e22, BURN5 + [4])
	var loss22 := _tick_loss(logic22, e22)
	var want22 := -floorf(float(e22.mhp) * -0.05)
	_check("tq.f22.burn5_poison_capped_5pct", is_equal_approx(loss22, want22), [loss22, want22, e22.mhp])

	# 3. 守层者挂单条未超上限（灼伤 II -2%）：照扣 2%，不放大
	var logic22_small := XBattleLogic.new()
	logic22_small.setup(458, s)
	var e22s: XEnemy = logic22_small.enemies[0]
	_add_states(e22s, [18])
	var loss22s := _tick_loss(logic22_small, e22s)
	var want22s := -floorf(float(e22s.mhp) * -0.02)
	_check("tq.f22.burn2_uncapped_2pct", is_equal_approx(loss22s, want22s), [loss22s, want22s, e22s.mhp])

	# 4. 30 层守层者变身成入魔 538（不在原 boss 表）：仍吃 5% 封顶
	var logic30 := XBattleLogic.new()
	logic30.setup(466, s)
	var e30: XEnemy = logic30.enemies[0]
	logic30.enemy_transform(0, 538)
	_add_states(e30, BURN5)
	var loss30 := _tick_loss(logic30, e30)
	var want30 := -floorf(float(e30.mhp) * -0.05)
	_check("tq.f30.transform538_capped_5pct", XTianqiCombat.is_neg_hrg_boss(e30) and is_equal_approx(loss30, want30), [loss30, want30])

	# 5. 副本首领（1 层嘤孙 422）：吃 5% 封顶
	var logic_boss := XBattleLogic.new()
	logic_boss.setup(422, s)
	var eboss: XEnemy = logic_boss.enemies[0]
	_add_states(eboss, BURN5)
	var loss_boss := _tick_loss(logic_boss, eboss)
	var want_boss := -floorf(float(eboss.mhp) * -0.05)
	_check("tq.dungeon_boss.capped_5pct", XTianqiCombat.is_neg_hrg_boss(eboss) and is_equal_approx(loss_boss, want_boss), [loss_boss, want_boss])

	# 6. 普通小怪（1 层嘤嘤怪，敌群 1）：不封顶，挂灼伤 I～V 照扣 14%
	var logic_mob := XBattleLogic.new()
	logic_mob.setup(1, s)
	var emob: XEnemy = logic_mob.enemies[0]
	_add_states(emob, BURN5)
	var loss_mob := _tick_loss(logic_mob, emob)
	var want_mob := -floorf(float(emob.mhp) * -0.14)
	_check("tq.mob.not_capped_14pct", not XTianqiCombat.is_neg_hrg_boss(emob) and is_equal_approx(loss_mob, want_mob), [loss_mob, want_mob, emob.mhp])

	# 7. 带正再生的守层者（11 层，STRIP=false）+ 灼伤 I～V：正再生照旧 ×w²、负再生封顶 -5%
	XGuardianRework.STRIP = false
	var logic11 := XBattleLogic.new()
	logic11.setup(int(XGuardianRework.TROOPS[11]), s)
	var e11: XEnemy = logic11.enemies[0]
	var w11 := e11.warehouse_rate()
	var pos11 := e11.hrg / w11
	var rec11 := e11.rec / w11
	_add_states(e11, BURN5)
	e11.hp = floorf(float(e11.mhp) / 2.0)
	var hp11_0 := float(e11.hp)
	logic11._regenerate(e11, [])
	var got11 := float(e11.hp) - hp11_0
	var want11 := floorf(float(e11.mhp) * (pos11 * w11 * w11 - 0.05) * rec11)
	_check("tq.f11.pos_kept_neg_capped", pos11 > 0.0 and is_equal_approx(got11, want11), [pos11, got11, want11])
	XGuardianRework.STRIP = true

	# 8. 开关回退：BOSS_NEG_HRG_CAP=false 后 29 层守层者回到 14%
	XTianqiCombat.BOSS_NEG_HRG_CAP = false
	var loss29_off := _tick_loss(logic, e29)
	var want29_off := -floorf(float(e29.mhp) * -0.14)
	_check("tq.f29.switch_off_14pct", is_equal_approx(loss29_off, want29_off), [loss29_off, want29_off])
	XTianqiCombat.BOSS_NEG_HRG_CAP = true

	# 9. 西游档零变化（1 层守层者敌群 4，自带正再生 0）：开关开与关逐值一致（照原版 ×w²，西游档 17~21 合计 -15%，×2×2 = -60%）
	var sx := _state(false)
	var lx := XBattleLogic.new()
	lx.setup(4, sx)
	var ex: XEnemy = lx.enemies[0]
	var wx := ex.warehouse_rate()
	_add_states(ex, BURN5)
	XTianqiCombat.BOSS_NEG_HRG_CAP = true
	var lx_on := _tick_loss(lx, ex)
	XTianqiCombat.BOSS_NEG_HRG_CAP = false
	var lx_off := _tick_loss(lx, ex)
	var want_x := -floorf(float(ex.mhp) * -0.15 * wx * wx)
	_check("xiyou.unchanged_on_eq_off", is_equal_approx(lx_on, lx_off) and is_equal_approx(lx_on, want_x), [lx_on, lx_off, want_x, ex.mhp])

	# 10. cap_neg_hrg 边界：b_rec > 1.0（如 2.0）时 eff_neg × b_rec 仍不超过 -5%
	XTianqiCombat.BOSS_NEG_HRG_CAP = true
	XState.current = s
	var c_rec2 := e29.cap_neg_hrg(-0.14, 2.0)
	_check("tq.f29.rec2_capped_5pct", is_equal_approx(c_rec2 * 2.0, -0.05), [c_rec2, c_rec2 * 2.0])
	var c_rec_half := e29.cap_neg_hrg(-0.04, 0.5)
	_check("tq.f29.rec_half_uncapped", is_equal_approx(c_rec_half, -0.04), [c_rec_half])

	XTianqiCombat.BOSS_NEG_HRG_CAP = was_cap
	XGuardianRework.STRIP = was_strip
	XEnemy.force_roll = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
