extends Node
## 【cc·T237】31～34 层守层者能力值重锚（XGuardianRework.PARAMS，tianqi_data/guardian_params.json）：
## 一、天启篇艰险 31／32／33 层守层者（女娲、伏羲、鸿蒙老祖）物防、魔防＝30 层玉皇大帝原数据 4950 × 107／114／121％ × 难度 1.5
##     （7946／8465／8985）；攻击、敏捷、生命上限之外的项照原数据（女娲物攻 118650、敏捷 179300）。
## 二、34 层鸿钧（借鸿蒙老祖、乘 summit rate）物防、魔防按 128％ 重锚：开着÷关着＝6336÷(322950×1.5)（线上异化倍率两边一样，比值不受影响）。
## 三、30 层玉皇大帝不动（7425）；回退开关关掉时 31 层女娲物防照原数据 49425。
## 四、西游档 31 层照原数据（开关开关一样）。
## 五、表里的数都是整数（附则 E）。
## 六（T245）、七印里副本（白印 Boss 战 Boss ×0.8、白印精英战 ×0.5）和七首之龙（×0.8）双防：开着÷关着＝玉皇大帝 4950×121％÷鸿蒙老祖 322950
##     （顶替参照那一项，rate 照旧）；攻击不动；PARAMS_QIYIN 和 PARAMS 各管各的。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	MVInterpreter.fixed_random = 0.5
	XEnemy.force_roll = 100.0  # 守层者不按神话
	seed(20261119)
	var was := XGuardianRework.PARAMS
	var was_q := XGuardianRework.PARAMS_QIYIN
	_check("qiyin.default_on", XGuardianRework.PARAMS_QIYIN)
	_check("default_on", XGuardianRework.PARAMS)
	_table()
	_floors()
	_hongjun()
	_off()
	_xiyou()
	_qiyin()
	_dragon()
	XGuardianRework.PARAMS = was
	XGuardianRework.PARAMS_QIYIN = was_q
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


func _guardian(troop: int, tianqi := true, hongjun := false) -> XEnemy:
	var s := _state(tianqi)
	if hongjun:
		s.flags.tianqi["line"] = "death"
		XTianqiSummit.prepare_hongjun(s)
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	for e in logic.enemies:
		if XGuardianRework.params_floor(e) > 0 or XGuardianRework.floor_of(e.enemy_id) > 0:
			return e
	return null


func _table() -> void:
	var d := XGuardianRework.params_data()
	var ints := true
	for f in d.get("floors", {}):
		for k in d.floors[f]:
			var v = d.floors[f][k]
			ints = ints and (v is float or v is int) and float(v) == floorf(float(v))
	_check("table.loaded", d.get("floors", {}).size() == 4, d.get("floors", {}).keys())
	_check("table.integers", ints)
	_check("table.target31", int(XGuardianRework.params_target(31, 3)) == 5297, XGuardianRework.params_target(31, 3))
	_check("table.untouched_atk", XGuardianRework.params_target(31, 2) < 0.0)


func _floors() -> void:
	XGuardianRework.PARAMS = true
	var want := {467: 7946, 468: 8465, 469: 8985}
	for troop in want:
		var e := _guardian(int(troop))
		_check("t%d.found" % troop, e != null)
		if e == null:
			continue
		_check("t%d.def" % troop, int(e.param(3)) == int(want[troop]), e.param(3))
		_check("t%d.mdf" % troop, int(e.param(5)) == int(want[troop]), e.param(5))
	var nv := _guardian(467)
	if nv != null:
		_check("t467.atk_same", int(nv.param(2)) == 118650, nv.param(2))
		_check("t467.agi_same", int(nv.param(6)) == 179300, nv.param(6))
	var yh := _guardian(466)
	_check("t466.def_same", yh != null and int(yh.param(3)) == 7425, yh.param(3) if yh != null else null)


func _hongjun() -> void:
	XGuardianRework.PARAMS = true
	var on := _guardian(469, true, true)
	XGuardianRework.PARAMS = false
	var off := _guardian(469, true, true)
	XGuardianRework.PARAMS = true
	var ok := on != null and off != null and str(on.data().get("_ref", "")) == "hongjun"
	_check("hongjun.found", ok)
	if not ok:
		return
	var ratio := float(on.param(3)) / float(off.param(3))
	_check("hongjun.def_ratio", absf(ratio - 6336.0 / 484425.0) < 0.0002, [on.param(3), off.param(3)])
	_check("hongjun.atk_same", int(on.param(2)) == int(off.param(2)), [on.param(2), off.param(2)])


func _off() -> void:
	XGuardianRework.PARAMS = false
	var e := _guardian(467)
	_check("off.t467_def", e != null and int(e.param(3)) == 49425, e.param(3) if e != null else null)
	XGuardianRework.PARAMS = true


func _xiyou() -> void:
	# 漩涡怪物异化对齐大厅稿会把西游档守层者随机变成异化怪（战狂 ×1.5），两次开档抽到的不一样；这里关掉（同 xiyou_combat.gd），由 tests/xiyou_rift_alien 核
	var align := XRiftAlien.ALIGN_LOBBY
	XRiftAlien.ALIGN_LOBBY = false
	XGuardianRework.PARAMS = true
	var on := _guardian(467, false)
	XGuardianRework.PARAMS = false
	var off := _guardian(467, false)
	XGuardianRework.PARAMS = true
	XRiftAlien.ALIGN_LOBBY = align
	_check("xiyou.same", on != null and off != null and int(on.param(3)) == int(off.param(3)) and int(on.param(3)) > 30000,
		[on.param(3) if on != null else null, off.param(3) if off != null else null])


## T245：白印 Boss 战（boss）或第一场精英战，返回按鸿蒙老祖重标的敌人（Boss 在前）
func _qiyin_fight(params_q: bool, params := true, boss := true) -> Array:
	XGuardianRework.PARAMS_QIYIN = params_q
	XGuardianRework.PARAMS = params
	var s := _state()
	s.flags.tianqi["line"] = "death"
	XTianqiQiyin.set_current("")
	XTianqiQiyinRule.prepare("bai", boss)
	var troops: Array = XTianqiQiyin.seal_info("bai").troops
	var logic := XBattleLogic.new()
	logic.setup(int(troops[-1] if boss else troops[0]), s)
	XGuardianRework.PARAMS_QIYIN = true
	XGuardianRework.PARAMS = true
	var out := logic.enemies.filter(func(e): return XGuardianRework.is_qiyin_ref(e))
	out.sort_custom(func(a, b): return bool(a.data().get("_qiyin_boss", false)) and not bool(b.data().get("_qiyin_boss", false)))
	return out


func _qiyin() -> void:
	var want := 5990.0 / 322950.0  # round(4950×121%) ÷ 鸿蒙老祖物防
	_check("qiyin.target", int(XGuardianRework.qiyin_target(3)) == 5990 and int(XGuardianRework.qiyin_target(5)) == 5990
		and XGuardianRework.qiyin_target(2) < 0.0, [XGuardianRework.qiyin_target(3), XGuardianRework.qiyin_target(2)])
	var on := _qiyin_fight(true)
	var off := _qiyin_fight(false)
	var ok := on.size() >= 1 and on.size() == off.size() and bool(on[0].data().get("_qiyin_boss", false))
	_check("qiyin.found", ok, [on.size(), off.size()])
	var eon := _qiyin_fight(true, true, false)
	var eoff := _qiyin_fight(false, true, false)
	var eok := eon.size() >= 1 and eon.size() == eoff.size() and not bool(eon[0].data().get("_qiyin_boss", false))
	_check("qiyin.elite_found", eok, [eon.size(), eoff.size()])
	if not ok or not eok:
		return
	var on_all: Array = [on[0], eon[0]]
	var off_all: Array = [off[0], eoff[0]]
	on = on_all
	off = off_all
	print("T245 qiyin def/mdf/atk on=", [on[0].param(3), on[0].param(5), on[0].param(2), eon[0].param(3), eon[0].param(5)],
		" off=", [off[0].param(3), off[0].param(5), off[0].param(2), eoff[0].param(3), eoff[0].param(5)])
	for k in on.size():
		var tag := "boss" if k == 0 else "elite"
		for i in [3, 5]:
			var r := float(on[k].param(i)) / float(off[k].param(i))
			_check("qiyin.%s.p%d_ratio" % [tag, i], absf(r - want) < 0.0005, [on[k].param(i), off[k].param(i)])
		_check("qiyin.%s.atk_same" % tag, int(on[k].param(2)) == int(off[k].param(2)), [on[k].param(2), off[k].param(2)])
	# 起点量级：Boss（×0.8）双防不超过 33 层守层者 8985，精英（×0.5）在它一半上下
	_check("qiyin.boss_level", on[0].param(3) > 4000.0 and on[0].param(3) < 9000.0, on[0].param(3))
	_check("qiyin.elite_level", on[1].param(3) > 2000.0 and on[1].param(3) < 6000.0, on[1].param(3))
	_check("qiyin.off_raw", off[0].param(3) > 200000.0, off[0].param(3))
	# 两个开关各管各的：PARAMS 关掉不影响里副本
	var p_off := _qiyin_fight(true, false)
	_check("qiyin.independent", not p_off.is_empty() and int(p_off[0].param(3)) == int(on[0].param(3)), [p_off[0].param(3) if not p_off.is_empty() else null, on[0].param(3)])


func _dragon_one(params_q: bool) -> XEnemy:
	XGuardianRework.PARAMS_QIYIN = params_q
	var s := _state()
	s.set_variable(20, 36)
	s.flags.tianqi["line"] = "war"
	XTianqiWarLine.progress(s)["stage"] = XTianqiWarLine.STAGE_DONE
	XTianqiQiyin.set_current("")
	XTianqiQiyinDragonRun.prepare("jianxian")
	var logic := XBattleLogic.new()
	logic.setup(int(XTianqiQiyinDragonRun.fight_info().troop), s)
	XGuardianRework.PARAMS_QIYIN = true
	return XTianqiQiyinDragonRun.dragon(logic)


func _dragon() -> void:
	var on := _dragon_one(true)
	var off := _dragon_one(false)
	var ok := on != null and off != null and str(on.data().get("_ref", "")) == "dragon"
	_check("dragon.found", ok)
	if not ok:
		return
	print("T245 dragon def/mdf on=", [on.param(3), on.param(5)], " off=", [off.param(3), off.param(5)])
	var r := float(on.param(3)) / float(off.param(3))
	_check("dragon.def_ratio", absf(r - 5990.0 / 322950.0) < 0.0005, [on.param(3), off.param(3)])
	_check("dragon.atk_same", int(on.param(2)) == int(off.param(2)), [on.param(2), off.param(2)])
	_check("dragon.hp_same", absf(on.mhp - off.mhp) <= 2.0, [on.mhp, off.mhp])
