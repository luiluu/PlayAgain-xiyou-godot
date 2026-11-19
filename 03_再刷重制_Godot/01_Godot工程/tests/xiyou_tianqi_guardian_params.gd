extends Node
## 【cc·T237】31～34 层守层者能力值重锚（XGuardianRework.PARAMS，tianqi_data/guardian_params.json）：
## 一、天启篇艰险 31／32／33 层守层者（女娲、伏羲、鸿蒙老祖）物防、魔防＝30 层玉皇大帝原数据 4950 × 107／114／121％ × 难度 1.5
##     （7946／8465／8985）；攻击、敏捷、生命上限之外的项照原数据（女娲物攻 118650、敏捷 179300）。
## 二、34 层鸿钧（借鸿蒙老祖、乘 summit rate）物防、魔防按 128％ 重锚：开着÷关着＝6336÷(322950×1.5)（线上异化倍率两边一样，比值不受影响）。
## 三、30 层玉皇大帝不动（7425）；回退开关关掉时 31 层女娲物防照原数据 49425。
## 四、西游档 31 层照原数据（开关开关一样）。
## 五、表里的数都是整数（附则 E）。

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
	_check("default_on", XGuardianRework.PARAMS)
	_table()
	_floors()
	_hongjun()
	_off()
	_xiyou()
	XGuardianRework.PARAMS = was
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
	XGuardianRework.PARAMS = true
	var on := _guardian(467, false)
	XGuardianRework.PARAMS = false
	var off := _guardian(467, false)
	XGuardianRework.PARAMS = true
	_check("xiyou.same", on != null and off != null and int(on.param(3)) == int(off.param(3)) and int(on.param(3)) > 30000,
		[on.param(3) if on != null else null, off.param(3) if off != null else null])
