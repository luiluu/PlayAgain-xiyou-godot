extends Node
## 【cc·T317】31～34 层守层者二阶段全免疫：
## 〇、默认（协调 11-20 定 B，XTianqiElements.POZHEN_OFF 开、POZHEN_BY_TYPE 关）：天启篇里 1047／1048 什么都不挡。
## 一、破阵 1047「物理免疫」／1048「元素免疫」（React：行动元素里有没有元素 1）开乙（POZHEN_BY_TYPE）时改认伤害类型：
##     1048 只放行物理类（XDamage.item_mode＝physical：攻击 12、十字军打击 109），挡魔法类（火焰 9）；1047 反过来；混合类（狂风箭矢 444）两边都放行。
##     两个开关都关＝改前：天启篇 1048 什么都挡（物理已转无属性）、1047 什么都不挡。
##     西游档照原版认元素 1：1048 只放行带元素 1 的攻击 12，十字军打击（光）、火焰、狂风箭矢（风）都挡；开关怎么开都一样。
## 二、自动战斗估伤：底座 XBattleEval.hit_detail（preview 走同一条 React）与我方卡 1（XSmartAI.expected_damage，o_tianqi_react_zero）
##     开乙时 1048 下火焰估 0、攻击估正数；o_tianqi_react_zero 关掉＝改前，火焰照估正数；默认（B）火焰估正数。
## 三、守层者变身（XGuardianRework.TRANSFORM_ANCHOR）：30 层玉皇大帝→入魔 538、31 层女娲／32 层伏羲→天道·魔神 929、33 层鸿蒙老祖→天道·混沌至高 930，
##     变身后八项能力值＝变身前、出伤倍率（output_scale）仍是本层的；开关关掉＝改前（31 层魔神物攻是女娲 2.36 倍、出伤倍率掉回 1）。
##     西游档变身照原数据，开关开关一样。

var results: Array = []
const PHYS := 12
const PHYS_LIGHT := 109
const MAG := 9
const MIXED := 444


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	MVInterpreter.fixed_random = 0.5
	XEnemy.force_roll = 100.0  # 守层者不按神话
	seed(20261120)
	var was := XTianqiElements.POZHEN_BY_TYPE
	var was_off := XTianqiElements.POZHEN_OFF
	var was_t := XGuardianRework.TRANSFORM_ANCHOR
	_check("default_off_on", XTianqiElements.POZHEN_OFF)
	_check("default_type_off", not XTianqiElements.POZHEN_BY_TYPE)
	_check("transform.default_on", XGuardianRework.TRANSFORM_ANCHOR)
	_modes()
	_tianqi_default()
	_tianqi_on()
	_tianqi_off()
	_xiyou()
	_ai()
	_transform()
	_transform_off()
	_transform_xiyou()
	XTianqiElements.POZHEN_BY_TYPE = was
	XTianqiElements.POZHEN_OFF = was_off
	XGuardianRework.TRANSFORM_ANCHOR = was_t
	XEnemy.force_roll = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _state(tianqi := true) -> XState:
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
	s.map_id = 4
	XState.current = s
	return s


func _logic(troop: int, tianqi := true) -> XBattleLogic:
	var s := _state(tianqi)
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	return logic


## 带 state 的 31 层女娲吃 skill 一下 1000 点（React 之后的值）
func _react(logic: XBattleLogic, state: int, skill: int) -> float:
	var e: XEnemy = logic.enemies[0]
	for id in [1047, 1048]:
		if e.is_state_affected(id):
			e.remove_state(id)
	e.add_state(state)
	logic._refresh_battler(e)  # 实战加状态走 refresh；不刷的话这一下读的还是加之前的状态表
	var a: XBattler = logic.actors[0]
	return XDamage.apply_state_effects(1000.0, XDB.rec("Skills", skill), a, e, [], "react", false)


func _modes() -> void:
	_check("mode.phys", XDamage.item_mode(XDB.rec("Skills", PHYS)) == "physical")
	_check("mode.phys_light", XDamage.item_mode(XDB.rec("Skills", PHYS_LIGHT)) == "physical")
	_check("mode.mag", XDamage.item_mode(XDB.rec("Skills", MAG)) == "magical")
	_check("mode.mixed", XDamage.item_mode(XDB.rec("Skills", MIXED)) == "mixed")


func _expect(tag: String, logic: XBattleLogic, state: int, want: Dictionary) -> void:
	for skill in want:
		var v := _react(logic, state, int(skill))
		_check("%s.%d.%d" % [tag, state, int(skill)], v == float(want[skill]), v)


func _tianqi_default() -> void:
	var logic := _logic(467)
	_expect("tq_b", logic, 1048, {PHYS: 1000, PHYS_LIGHT: 1000, MAG: 1000, MIXED: 1000})
	_expect("tq_b", logic, 1047, {PHYS: 1000, PHYS_LIGHT: 1000, MAG: 1000, MIXED: 1000})


func _tianqi_on() -> void:
	XTianqiElements.POZHEN_BY_TYPE = true
	var logic := _logic(467)
	_check("tq.deck_on", XTianqiElements.deck_on())
	_expect("tq", logic, 1048, {PHYS: 1000, PHYS_LIGHT: 1000, MAG: 0, MIXED: 1000})
	_expect("tq", logic, 1047, {PHYS: 0, PHYS_LIGHT: 0, MAG: 1000, MIXED: 1000})
	XTianqiElements.POZHEN_BY_TYPE = false


func _tianqi_off() -> void:
	XTianqiElements.POZHEN_BY_TYPE = false
	XTianqiElements.POZHEN_OFF = false
	var logic := _logic(467)
	_expect("tq_off", logic, 1048, {PHYS: 0, PHYS_LIGHT: 0, MAG: 0, MIXED: 0})
	_expect("tq_off", logic, 1047, {PHYS: 1000, PHYS_LIGHT: 1000, MAG: 1000, MIXED: 1000})
	XTianqiElements.POZHEN_OFF = true


func _xiyou() -> void:
	var align := XRiftAlien.ALIGN_LOBBY
	XRiftAlien.ALIGN_LOBBY = false
	for combo in [[false, true], [true, true], [false, false]]:
		XTianqiElements.POZHEN_BY_TYPE = combo[0]
		XTianqiElements.POZHEN_OFF = combo[1]
		var logic := _logic(467, false)
		var tag := "xy_%s_%s" % combo
		_expect(tag, logic, 1048, {PHYS: 1000, PHYS_LIGHT: 0, MAG: 0, MIXED: 0})
		_expect(tag, logic, 1047, {PHYS: 0, PHYS_LIGHT: 1000, MAG: 1000, MIXED: 1000})
	XTianqiElements.POZHEN_BY_TYPE = false
	XTianqiElements.POZHEN_OFF = true
	XRiftAlien.ALIGN_LOBBY = align


func _ai() -> void:
	XTianqiElements.POZHEN_BY_TYPE = true
	var logic := _logic(467)
	var e: XEnemy = logic.enemies[0]
	e.add_state(1048)
	logic._refresh_battler(e)
	var a: XBattler = logic.actors[0]
	var ev := XBattleEval.create_for(logic, a)
	var mag := float(ev.hit_detail(a, e, XDB.rec("Skills", MAG), 1000.0).value)
	var phys := float(ev.hit_detail(a, e, XDB.rec("Skills", PHYS), 1000.0).value)
	_check("ai.mag_zero", mag == 0.0, mag)
	_check("ai.phys_positive", phys > 0.0, phys)
	# 我方自动战斗默认走卡 1（统一预览 O-624 默认关）：React 整下挡掉的招估 0（XSmartAI.o_tianqi_react_zero）
	var pv := XSmartAI.o_tianqi_preview_damage
	XSmartAI.o_tianqi_preview_damage = false
	var actor: XActor = logic.actors[0]
	var mag1 := XSmartAI.new(logic, actor).expected_damage(actor, e, XDB.rec("Skills", MAG))
	var phys1 := XSmartAI.new(logic, actor).expected_damage(actor, e, XDB.rec("Skills", PHYS))
	_check("smart.mag_zero", mag1 == 0.0, mag1)
	_check("smart.phys_positive", phys1 > 0.0, phys1)
	XSmartAI.o_tianqi_react_zero = false
	var mag_off := XSmartAI.new(logic, actor).expected_damage(actor, e, XDB.rec("Skills", MAG))
	XSmartAI.o_tianqi_react_zero = true
	_check("smart_off.mag_positive", mag_off > 0.0, mag_off)
	XTianqiElements.POZHEN_BY_TYPE = false
	var mag_b := XSmartAI.new(logic, actor).expected_damage(actor, e, XDB.rec("Skills", MAG))
	_check("smart_b.mag_positive", mag_b > 0.0, mag_b)
	XSmartAI.o_tianqi_preview_damage = pv


func _params(e: XEnemy) -> Array:
	var out := []
	for i in range(8):
		out.append(e.param(i))
	return out


func _transform_one(troop: int, to: int, tianqi := true) -> Dictionary:
	var logic := _logic(troop, tianqi)
	var e: XEnemy = logic.enemies[0]
	var before := _params(e)
	var scale_before := e.output_scale
	logic.enemy_transform(0, to)
	e.param_mark_dirty()
	e.param_refresh()  # 读真值：回退分支变身后能力值缓存要等下一次置脏才换（T313 量到的魔神 56 万物攻就是换过以后）
	return {"before": before, "after": _params(e), "scale_before": scale_before, "scale_after": e.output_scale, "id": e.enemy_id}


func _transform() -> void:
	XGuardianRework.TRANSFORM_ANCHOR = true
	for pair in [[466, 538], [467, 929], [468, 929], [469, 930]]:
		var r := _transform_one(int(pair[0]), int(pair[1]))
		var tag := "tf.%d" % int(pair[0])
		print("T317 变身 %d→%d 前 %s 后 %s 出伤倍率 %s→%s" % [pair[0], pair[1], r.before, r.after, r.scale_before, r.scale_after])
		_check(tag + ".id", r.id == int(pair[1]), r.id)
		var same := true
		for i in range(8):
			same = same and absf(float(r.after[i]) - float(r.before[i])) <= maxf(1.0, absf(float(r.before[i])) * 1e-9)
		_check(tag + ".params_same", same, [r.before, r.after])
		_check(tag + ".scale_kept", r.scale_after == r.scale_before and r.scale_before < 1.0, [r.scale_before, r.scale_after])


func _transform_off() -> void:
	XGuardianRework.TRANSFORM_ANCHOR = false
	var r := _transform_one(467, 929)
	print("T317 回退 467→929 前 %s 后 %s 出伤倍率 %s→%s" % [r.before, r.after, r.scale_before, r.scale_after])
	_check("tf_off.atk_jumps", float(r.after[2]) > float(r.before[2]) * 2.0, [r.before[2], r.after[2]])
	_check("tf_off.scale_lost", r.scale_after == 1.0 and r.scale_before < 1.0, [r.scale_before, r.scale_after])
	XGuardianRework.TRANSFORM_ANCHOR = true


func _transform_xiyou() -> void:
	var align := XRiftAlien.ALIGN_LOBBY
	XRiftAlien.ALIGN_LOBBY = false
	XGuardianRework.TRANSFORM_ANCHOR = true
	var on := _transform_one(467, 929, false)
	XGuardianRework.TRANSFORM_ANCHOR = false
	var off := _transform_one(467, 929, false)
	XGuardianRework.TRANSFORM_ANCHOR = true
	XRiftAlien.ALIGN_LOBBY = align
	_check("tf_xy.same", on.after == off.after and float(on.after[2]) > float(on.before[2]), [on.after, off.after])
