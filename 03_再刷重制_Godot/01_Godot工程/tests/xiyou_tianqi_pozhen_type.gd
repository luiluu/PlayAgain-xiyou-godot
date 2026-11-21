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
## 四、【T322】守层者变身后继承守层者身份（XGuardianRework.TRANSFORM_IDENTITY）：30～33 层带满 3 层成长强化变身，变身前后八项能力值不跳；
##     growth_on、元素牌组（source guardian、本层）、is_boss_enemy、一刀切抗性折算都照本层守层者；楼层小怪（只记 META_FLOOR）变身不记身份；
##     开关关＝T317（成长 +25%/层 → 能力值跳 +28.7%、929／930 走 dungeon_boss 牌组、538 空牌组且不算首领、抗性不折）；西游档不记。
##     破阵分类（XDamage.item_mode skills_only）：道具 392 不借同号技能的 magical，正式结算（不传）照原版。

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
	var was_id := XGuardianRework.TRANSFORM_IDENTITY
	_check("tfid.default_on", XGuardianRework.TRANSFORM_IDENTITY)  # T323（T322 P3-1）：先断言默认值，再由各段改
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
	_identity()
	_identity_off()
	_identity_minion()
	_identity_xiyou()
	_item_mode_items()
	XTianqiElements.POZHEN_BY_TYPE = was
	XTianqiElements.POZHEN_OFF = was_off
	XGuardianRework.TRANSFORM_ANCHOR = was_t
	XGuardianRework.TRANSFORM_IDENTITY = was_id
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
		XTianqiElements.ensure_deck(s, 20261120)  # T345：新局元素牌组由随机宝珠种子建，31 层女娲对火的抗性随机（0／0.67／1.0）→ 火焰估伤偶发 0；钉死种子
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
	_check("ai.fire_not_immune", e.element_rate(int(XDB.rec("Skills", MAG).damage.get("elementId", 0))) > 0.0)  # T345 守卫：牌组种子钉住后火不是免疫
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


# ---- T322：变身后继承守层者身份 ----
const TF_PAIRS := [[466, 538, 30], [467, 929, 31], [468, 929, 32], [469, 930, 33]]


## 先给守层者八项各上满 3 层强化（成长招就是这么加的），再变身；返回变身前后能力值与身份判定
func _tf_grown(troop: int, to: int, tianqi := true) -> Dictionary:
	var logic := _logic(troop, tianqi)
	var e: XEnemy = logic.enemies[0]
	for i in range(8):
		for k in range(3):
			logic.sequence_buff(e, i, true, true, 5)
	e.param_mark_dirty()
	e.param_refresh()
	var before := _params(e)
	var buffs_before: Array = e.buffs.duplicate()
	var res_before := XGuardianRework.resistance(e, 0.5)
	logic.enemy_transform(0, to)
	e.param_mark_dirty()
	e.param_refresh()
	var prof := XTianqiElements.enemy_profile(e, logic)
	var out := {"flag": e.boss_difficulty_boss, "before": before, "after": _params(e), "buffs": buffs_before, "buffs_after": e.buffs.duplicate(), "id": e.enemy_id,
		"tf_floor": XGuardianRework.transform_floor(e), "gfloor": XGuardianRework.guardian_floor(e), "growth": XGuardianRework.growth_on(e),
		"source": str(prof.get("source", "")), "pfloor": int(prof.get("floor", 0)), "weak": prof.get("weak", []),
		"boss": XTianqiElements.is_boss_enemy(e), "res_before": res_before, "res_after": XGuardianRework.resistance(e, 0.5)}
	logic.sequence_buff(e, 2, true, true, 5)  # T323（T322 P3-1）：变身后再上第 4 层强化（各项判定都取完了再上）
	out["buffs_4th"] = e.buffs.duplicate()
	return out


func _same8(a: Array, b: Array) -> bool:
	for i in range(8):
		if absf(float(a[i]) - float(b[i])) > maxf(1.0, absf(float(b[i])) * 1e-9):
			return false
	return true


func _identity() -> void:
	XGuardianRework.TRANSFORM_ANCHOR = true
	XGuardianRework.TRANSFORM_IDENTITY = true
	for row in TF_PAIRS:
		var f := int(row[2])
		var r := _tf_grown(int(row[0]), int(row[1]))
		var tag := "tfid.%d" % f
		print("T322 变身（3 层强化）%d→%d 前 %s 后 %s 强化 %s 牌组 %s/%d 首领 %s 抗性 %s→%s" % [row[0], row[1], r.before, r.after, r.buffs,
			r.source, r.pfloor, r.boss, r.res_before, r.res_after])
		_check(tag + ".buffs3", r.buffs.slice(0, 8).all(func(v): return int(v) == 3) and r.buffs_after == r.buffs, [r.buffs, r.buffs_after])
		_check(tag + ".params_same", _same8(r.after, r.before), [r.before, r.after])
		_check(tag + ".floor", r.tf_floor == f and r.gfloor == f, [r.tf_floor, r.gfloor])
		_check(tag + ".growth", r.growth)
		_check(tag + ".deck", r.source == "guardian" and r.pfloor == f and not (r.weak as Array).is_empty(), [r.source, r.pfloor, r.weak])
		_check(tag + ".boss", r.boss)
		_check(tag + ".boss_flag", r.flag, r.id)  # T323（T322 P2-1）：538 不在首领表，变身后 boss_difficulty_boss 也要保底为真（首领规则、减益减半、击晕豁免、状态栏都读它）
		_check(tag + ".buff_cap3", int(r.buffs_4th[2]) == 3, r.buffs_4th)
		_check(tag + ".resist", r.res_after == r.res_before and r.res_before > 0.5, [r.res_before, r.res_after])


## 开关关＝T317：成长按原版 +25%/层，能力值跳 ×1.75/1.36；929／930 走 dungeon_boss 牌组，538 空牌组且不算首领，抗性不折
func _identity_off() -> void:
	XGuardianRework.TRANSFORM_IDENTITY = false
	for row in TF_PAIRS:
		var f := int(row[2])
		var r := _tf_grown(int(row[0]), int(row[1]))
		var tag := "tfid_off.%d" % f
		print("T322 回退 %d→%d 前 %s 后 %s 牌组 %s 首领 %s 抗性 %s" % [row[0], row[1], r.before, r.after, r.source, r.boss, r.res_after])
		var k := float(r.after[2]) / float(r.before[2])
		_check(tag + ".atk_jump", absf(k - 1.75 / 1.36) < 0.01, k)
		_check(tag + ".growth_lost", not r.growth and r.tf_floor == 0)
		_check(tag + ".deck_lost", r.source != "guardian", r.source)
		_check(tag + ".resist_lost", r.res_after == 0.5, r.res_after)
		if int(row[1]) == 538:
			_check(tag + ".boss_lost_538", not r.boss and not r.flag, [r.boss, r.flag])
	XGuardianRework.TRANSFORM_IDENTITY = true


## 楼层小怪（只记 META_FLOOR、不是守层者）变身：不记守层者身份，成长、牌组、首领、抗性照新敌人号
func _identity_minion() -> void:
	var logic := _logic(1)
	var e: XEnemy = logic.enemies[0]
	e.set_meta(XGuardianRework.META_FLOOR, 31)
	_check("tfid_minion.not_guardian", XGuardianRework.guardian_floor(e) == 0)
	logic.enemy_transform(0, 538)
	_check("tfid_minion.no_identity", XGuardianRework.transform_floor(e) == 0 and not e.has_meta(XGuardianRework.META_TRANSFORM)
		and not XGuardianRework.growth_on(e) and XGuardianRework.guardian_floor(e) == 0, e.get_meta_list())
	_check("tfid_minion.resist", XGuardianRework.resistance(e, 0.5) == 0.5)


func _identity_xiyou() -> void:
	var align := XRiftAlien.ALIGN_LOBBY
	XRiftAlien.ALIGN_LOBBY = false
	var r := _tf_grown(467, 929, false)
	var r538 := _tf_grown(466, 538, false)
	XRiftAlien.ALIGN_LOBBY = align
	_check("tfid_xy.none", r.tf_floor == 0 and not r.growth and r.source == "", [r.tf_floor, r.growth, r.source])
	_check("tfid_xy.538_not_boss", r538.tf_floor == 0 and not r538.flag, [r538.tf_floor, r538.flag])  # T323：西游档 538 照原版不是首领


## P3-2：破阵分类先判是不是技能；道具 392（与带 mode=magical 的技能同号、命中类型非魔法）分类按命中类型，正式结算照原版借同号
func _item_mode_items() -> void:
	var it: Dictionary = XDB.rec("Items", 392)
	_check("mode.item_formal_as_original", XDamage.item_mode(it) == "magical", XDamage.item_mode(it))
	_check("mode.item_class_by_hit", XDamage.item_mode(it, true) == "physical", XDamage.item_mode(it, true))
	_check("mode.skill_class_same", XDamage.item_mode(XDB.rec("Skills", MAG), true) == "magical" and XDamage.item_mode(XDB.rec("Skills", MIXED), true) == "mixed")
