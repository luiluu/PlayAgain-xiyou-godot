extends Node
## T553（事项82 甲）：天启篇我方 1 号普攻＝物攻 ×1 × 等级缩放（XTianqiSkills.ATTACK1），敌人 1 号照原版 a.atk*4。
## 一、我方 99 级 ×1、1 级 ×0.5、50 级按线性；二、敌人出伤开关两态一致且＝物攻×4；三、ATTACK1＝false 我方回 ×4；
## 四、西游档零改动；五、「普攻变 X」不再倒挂（堕天一击＝2 倍）；六、1 号记录本身不改（心魔影·原招、疫囊扩散照读原记录）。
## T565（D295）：怒战八方——艾坤学 2419 后实际攻击指令换成 10718，伤害＝1 号×1.2（比普攻高 20%，不再允许同伤）；
## 三种子单角色木桩实打单段伤害比（打印 T565_RATIO）；T553 核 P2-2：同号 1 的道具（小治疗药水）不走 1 号普攻分流。

const ACTOR := 1
const AIKUN := 3
const T541 = preload("res://tests/xiyou_t541_equip_skills.gd")
const SEEDS := ["0000000000000001", "0000000000000002", "0000000000000003"]
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


## T565（D295）：艾坤学怒战八方，实际攻击指令（attack_skill_id）＝10718，出伤＝1 号×1.2
func _test_nuzhan() -> void:
	var h = T541.new()
	var s: XState = h._make_tianqi([AIKUN, ACTOR], 25)
	var k: XActor = s.actor(AIKUN)
	k.change_level(99)
	k.learn_skill(2419)
	k.refresh_passive()
	k.recover_all()
	var aid := k.attack_skill_id()
	_check("nuzhan_attack_cmd", aid == 10718, aid)
	var lg: XBattleLogic = h._make_dummy_battle(s, 2, SEEDS[0])
	var e: XBattler = lg.enemies[0]
	var base := _val(XDB.rec("Skills", 1), k, e)
	var nu := _val(XDB.rec("Skills", aid), k, e)
	_check("nuzhan_x1_2", is_equal_approx(nu, base * 1.2) and nu > base, [nu, base, nu / maxf(1.0, base)])
	print("T553_RATIO nuzhan=%.4f" % (nu / maxf(1.0, base)))
	lg.end_battle(0)
	# 量数（D295 口径：单角色木桩、三种子、单段伤害比）：同种子各开一场，1 号普攻对实际攻击指令
	# 暴击段按暴击倍率 1.5 折回（两招暴击判定各自掷，同种子也可能一暴一不暴）；原始比一起打印
	var ratios := []
	for sd in SEEDS:
		var r1 := _hit_dmg(h, s, k, 1, sd)
		var r2 := _hit_dmg(h, s, k, aid, sd)
		var d1: float = r1[0] / (1.5 if r1[1] else 1.0)
		var d2: float = r2[0] / (1.5 if r2[1] else 1.0)
		ratios.append(d2 / maxf(1.0, d1))
		print("T565_RATIO seed=%s atk1=%.0f%s nuzhan=%.0f%s raw=%.4f ratio=%.4f" % [sd, r1[0], "(暴)" if r1[1] else "", r2[0], "(暴)" if r2[1] else "", r2[0] / maxf(1.0, r1[0]), d2 / maxf(1.0, d1)])
	_check("nuzhan_seeds_x1_2", ratios.all(func(r): return absf(float(r) - 1.2) < 0.02), ratios)
	XState.current = null
	h.free()


## 一段实打：对木桩放 sid，返回 [这一招自己的第一段伤害, 是否暴击]
func _hit_dmg(h, s: XState, k: XActor, sid: int, sd: String) -> Array:
	XState.current = s
	k.recover_all()
	var lg: XBattleLogic = h._make_dummy_battle(s, 2, sd)
	var logs := lg.act(k, XDB.rec("Skills", sid), lg.enemies[0])
	var out := [0.0, false]
	for r in logs:
		if r is Dictionary and r.get("type") == "hit" and int((r.get("skill", {}) as Dictionary).get("id", 0)) == sid and is_same(r.get("user"), k):
			out = [maxf(0.0, float(r.get("hp", 0.0))), bool(r.get("critical", false))]
			break
	lg.end_battle(0)
	return out


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
	var pv := XDamage.eval_formula(atk1, a, b, [])  # AI 估伤／预估快路径（pure 程序）同正式结算
	_check("actor_preview_x1", is_equal_approx(pv, a.atk * 1.0), [pv, a.atk])
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
	_check("enemy_preview_x4", is_equal_approx(XDamage.eval_formula(atk1, b, a, []), b.atk * 4.0))
	_check("enemy_unchanged", is_equal_approx(e_on, e_off) and is_equal_approx(e_on, b.atk * 4.0), [e_on, e_off, b.atk])
	# 五：普攻变 X 不倒挂
	var base := _val(atk1, a, b)
	var dt := _val(XDB.rec("Skills", 3521), a, b)
	_check("duotian_x2", is_equal_approx(dt, base * 2.0), [dt, base])
	# T553 核 P2-2：道具 1（治疗药水(小)）不是技能记录，不走 1 号普攻分流；开关两态同值
	var it1 := XDB.rec("Items", 1)
	var i_on := _val(it1, a, a)
	XTianqiSkills.ATTACK1 = false
	var i_off := _val(it1, a, a)
	XTianqiSkills.ATTACK1 = true
	_check("item1_not_attack1", not XTianqiSkills.attack1_applies(it1, a) and is_equal_approx(i_on, i_off) and is_equal_approx(XDamage.eval_formula(it1, a, a, []), i_off), [i_on, i_off])
	lg.end_battle(0)
	_test_nuzhan()
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
