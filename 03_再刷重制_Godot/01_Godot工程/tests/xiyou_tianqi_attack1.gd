extends Node
## T553（事项82 甲）：天启篇我方 1 号普攻＝物攻 ×1 × 等级缩放（XTianqiSkills.ATTACK1），敌人 1 号照原版 a.atk*4。
## 一、我方 99 级 ×1、1 级 ×0.5、50 级按线性；二、敌人出伤开关两态一致且＝物攻×4；三、ATTACK1＝false 我方回 ×4；
## 四、西游档零改动；五、「普攻变 X」不再倒挂（怒战≥1 号、堕天一击＝2 倍）；六、1 号记录本身不改（心魔影·原招、疫囊扩散照读原记录）。

const ACTOR := 1
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _state(tianqi := true) -> XState:
	var lineup := [ACTOR]
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
	return s


func _val(item: Dictionary, a, b) -> float:
	return float(XFormulaExecution.run_item(item, a, b, {}).value)


func _run() -> void:
	XTianqi.JOIN_GIFTS = false
	XMessageBox.auto = true
	seed(20261127)
	XTianqiSkills.reload_table()
	_check("default_on", XTianqiSkills.ATTACK1 and XTianqiSkills.cards_flag() and not XTianqiSkills.has(1))
	var s := _state()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var a: XActor = s.actor(ACTOR)
	var b: XBattler = lg.enemies[0]
	var atk1 := XDB.rec("Skills", 1)
	# 六：记录本身不动（敌我共用，心魔 ying_skill 复制它、alien spread_pest 读它）
	_check("record_untouched", str(atk1.damage.formula).begins_with("a.atk * 4") and str(atk1.damage.get("formulaProgram", {}).get("status", "")) != "module", atk1.damage)
	# 一：我方
	a.change_level(99)
	_check("actor_lv99_x1", is_equal_approx(_val(atk1, a, b), a.atk * 1.0), [_val(atk1, a, b), a.atk])
	a.change_level(1)
	_check("actor_lv1_half", is_equal_approx(_val(atk1, a, b), a.atk * 0.5), [_val(atk1, a, b), a.atk])
	a.change_level(50)
	_check("actor_lv50_linear", is_equal_approx(_val(atk1, a, b), a.atk * (0.5 + 0.5 * 49.0 / 98.0)), [_val(atk1, a, b), a.atk])
	a.change_level(99)
	# 二：敌人不变（开关两态一致，且＝物攻×4）
	var e_on := _val(atk1, b, a)
	XTianqiSkills.ATTACK1 = false
	var e_off := _val(atk1, b, a)
	# 三：回退
	_check("rollback_actor_x4", is_equal_approx(_val(atk1, a, b), a.atk * 4.0), [_val(atk1, a, b), a.atk])
	XTianqiSkills.ATTACK1 = true
	_check("enemy_unchanged", is_equal_approx(e_on, e_off) and is_equal_approx(e_on, b.atk * 4.0), [e_on, e_off, b.atk])
	# 五：普攻变 X 不倒挂
	var base := _val(atk1, a, b)
	var nu := _val(XDB.rec("Skills", 10718), a, b)
	var dt := _val(XDB.rec("Skills", 3521), a, b)
	_check("nuzhan_not_inverted", nu >= base - 0.001, [nu, base, nu / maxf(1.0, base)])
	_check("duotian_x2", is_equal_approx(dt, base * 2.0), [dt, base])
	print("T553_RATIO nuzhan=%.4f duotian=%.4f" % [nu / maxf(1.0, base), dt / maxf(1.0, base)])
	lg.end_battle(0)
	# 四：西游档零改动
	var s2 := _state(false)
	var lg2 := XBattleLogic.new()
	lg2.setup(2, s2)
	var a2: XActor = s2.actor(ACTOR)
	var b2: XBattler = lg2.enemies[0]
	var r2 := XDB.rec("Skills", 1)
	var x_on := _val(r2, a2, b2)
	XTianqiSkills.ATTACK1 = false
	var x_off := _val(r2, a2, b2)
	XTianqiSkills.ATTACK1 = true
	_check("xiyou_unchanged", is_equal_approx(x_on, x_off) and is_equal_approx(x_on, a2.atk * 4.0) and not XTianqiSkills.attack1_applies(r2, a2), [x_on, x_off, a2.atk])
	lg2.end_battle(0)
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
