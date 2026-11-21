extends Node
## 【cc·T348】天启篇守层者清正值双闪、暴闪、每回合回血（XGuardianRework.STRIP，Kyo 11-22 待办 10；照 T315 心魔）：
## 一、天启篇存档：1～33 层守层者（含 26 层金角银角）与 30～33 层残血变身二阶段 538／929／930 的记录里没有闪避 1、暴击闪避 3、
##     魔法闪避 4、每回合回血 7 的正值特性；原数据里这些项有正值的，清掉的正是那几条，别的特性条数不变。
## 二、实战：各层守层者那场开打后，守层者 xparam(1/3/4/7) 都是 0（含 T285 封顶路）；30～33 层用 enemy_transform 变身后也是 0；
##     34 层鸿钧（借鸿蒙老祖 537 的记录）也是 0。
## 三、负值不动：1～6 层守层者原数据的负闪避照留。
## 四、拆开量的开关：STRIP_XPARAM=[3] 只清暴闪（回血、闪避留着），[7] 只清回血。
## 五、回退：STRIP=false 时记录与原数据同一份、xparam 回正值。六、西游档：记录原样（同一份）、xparam 照原值。

const IDS := [1, 3, 4, 7]
const TRANSFORM := {30: 538, 31: 929, 32: 929, 33: 930}

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	MVInterpreter.fixed_random = 0.5
	seed(20261122)
	var was_on := XGuardianRework.STRIP
	var was_ids: Array = XGuardianRework.STRIP_XPARAM.duplicate()
	_check("default_on", XGuardianRework.STRIP and XGuardianRework.STRIP_XPARAM == [1, 3, 4, 7])
	_records()
	_battles()
	_hongjun()
	_split()
	_rollback()
	_xiyou()
	XGuardianRework.STRIP = was_on
	XGuardianRework.STRIP_XPARAM = was_ids
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _state(passed_floor: int, tianqi := true) -> XState:
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
		s = XState.new_game(3, 1, [2, 8, 9, 10])
	s.map_id = 4
	s.set_variable(20, passed_floor + 1)
	XState.current = s
	return s


## 原数据（不走 XDB.rec）里第 i 项特性之和
func _raw_sum(id: int, i: int, positive_only := false) -> float:
	var sum := 0.0
	for t in (XDB.table("Enemies")[id] as Dictionary).get("traits", []):
		if int(t.code) == XBattler.TRAIT_XPARAM and int(t.dataId) == i and (not positive_only or float(t.value) > 0.0):
			sum += float(t.value)
	return sum


func _rec_pos(id: int, ids: Array) -> Array:
	var out := []
	for t in XDB.rec("Enemies", id).get("traits", []):
		if int(t.code) == XBattler.TRAIT_XPARAM and ids.has(int(t.dataId)) and float(t.value) > 0.0:
			out.append([int(t.dataId), float(t.value)])
	return out


## 1～33 层守层者号（原数据名带「守层者」）＋变身号
func _guardians() -> Dictionary:
	var out := {}
	for f in XGuardianRework.TROOPS:
		for m in XDB.rec("Troops", int(XGuardianRework.TROOPS[f])).get("members", []):
			var id := int(m.get("enemyId", 0))
			if id > 0 and str((XDB.table("Enemies")[id] as Dictionary).get("name", "")).contains("守层者"):
				out[id] = int(f)
	for f in TRANSFORM:
		out[int(TRANSFORM[f])] = int(f)
	return out


func _records() -> void:
	_state(33)
	var g := _guardians()
	_check("rec.count", g.size() == 37 and g.has(529) and g.has(530) and g.has(538) and g.has(929) and g.has(930), [g.size(), g.keys()])
	var bad := []
	var cut := 0
	for id in g:
		if not _rec_pos(int(id), IDS).is_empty():
			bad.append([id, _rec_pos(int(id), IDS)])
		var raw: Array = (XDB.table("Enemies")[int(id)] as Dictionary).get("traits", [])
		var pos := raw.filter(func(t): return int(t.code) == XBattler.TRAIT_XPARAM and IDS.has(int(t.dataId)) and float(t.value) > 0.0).size()
		cut += pos
		if XDB.rec("Enemies", int(id)).get("traits", []).size() != raw.size() - pos:
			bad.append([id, "other_traits_changed"])
	_check("rec.stripped", bad.is_empty(), bad)
	_check("rec.something_cut", cut >= 90, cut)  # 7～33 层＋变身 3 只，原数据正值约百条
	for id in [538, 929, 930]:
		_check("rec.transform_%d_had_pos" % id, _raw_sum(id, 3, true) > 0.0 and _raw_sum(id, 7, true) > 0.0 and _rec_pos(id, IDS).is_empty())
	_check("rec.negative_kept", _raw_sum(6, 1) < 0.0 and is_equal_approx(_xp_rec(6, 1), _raw_sum(6, 1)), [_raw_sum(6, 1), _xp_rec(6, 1)])
	_check("rec.minion_untouched", not g.has(29) and XDB.rec("Enemies", 29).get("traits", []).size() == (XDB.table("Enemies")[29] as Dictionary).get("traits", []).size())


func _xp_rec(id: int, i: int) -> float:
	var sum := 0.0
	for t in XDB.rec("Enemies", id).get("traits", []):
		if int(t.code) == XBattler.TRAIT_XPARAM and int(t.dataId) == i:
			sum += float(t.value)
	return sum


func _guardian_battle(f: int, tianqi := true) -> Array:
	var s := _state(f, tianqi)
	var logic := XBattleLogic.new()
	logic.setup(int(XGuardianRework.TROOPS[f]), s)
	var out := []
	for e in logic.enemies:
		if XGuardianRework.floor_of(e.enemy_id) == f or (not tianqi and str(e.data().get("name", "")).contains("守层者")):
			out.append(e)
	return [logic, out]


func _xp(e: XEnemy) -> Array:
	return IDS.map(func(i): return snappedf(e.xparam(i), 0.0001))


func _battles() -> void:
	var bad := []
	var n := 0
	for f in range(1, 34):
		var r := _guardian_battle(f)
		for e in r[1]:
			n += 1
			if f >= 7 and _xp(e) != [0.0, 0.0, 0.0, 0.0]:
				bad.append([f, e.enemy_id, _xp(e)])
			if f < 7 and (e.xparam(3) != 0.0 or e.xparam(4) != 0.0 or e.xparam(7) != 0.0):
				bad.append([f, e.enemy_id, _xp(e)])
	_check("battle.xparam_zero", bad.is_empty() and n == 34, [n, bad])
	for f in TRANSFORM:
		var r := _guardian_battle(int(f))
		var logic: XBattleLogic = r[0]
		var e: XEnemy = r[1][0]
		var before := _xp(e)
		logic.enemy_transform(logic.enemies.find(e), int(TRANSFORM[f]))
		_check("transform.f%d_%d" % [f, TRANSFORM[f]], e.enemy_id == int(TRANSFORM[f]) and _xp(e) == [0.0, 0.0, 0.0, 0.0] and before == [0.0, 0.0, 0.0, 0.0], [e.enemy_id, before, _xp(e)])


func _hongjun() -> void:
	var s := _state(33)
	s.flags.tianqi["line"] = "death"
	var ok := XTianqiSummit.prepare_hongjun(s)
	var logic := XBattleLogic.new()
	logic.setup(int(XGuardianRework.TROOPS[33]), s)
	var h: Array = logic.enemies.filter(func(x): return str(x.horseman.get("rec", {}).get("_ref", "")) == "hongjun")
	_check("hongjun.zero", ok and h.size() == 1 and _xp(h[0]) == [0.0, 0.0, 0.0, 0.0], [ok, h.size(), _xp(h[0]) if h.size() > 0 else null])


func _split() -> void:
	XGuardianRework.STRIP_XPARAM = [3]
	var e: XEnemy = _guardian_battle(25)[1][0]
	_check("split.cev_only", e.xparam(3) == 0.0 and e.xparam(7) > 0.0 and e.xparam(1) > 0.0 and _rec_pos(528, [3]).is_empty() and not _rec_pos(528, [7]).is_empty(), _xp(e))
	XGuardianRework.STRIP_XPARAM = [7]
	e = _guardian_battle(31)[1][0]
	_check("split.hrg_only", e.xparam(7) == 0.0 and e.xparam(3) > 0.0 and _rec_pos(535, [7]).is_empty() and not _rec_pos(535, [3]).is_empty(), _xp(e))
	XGuardianRework.STRIP_XPARAM = [1, 3, 4, 7]


func _rollback() -> void:
	XGuardianRework.STRIP = false
	_state(25)
	_check("rollback.rec_same", is_same(XDB.rec("Enemies", 528), XDB.table("Enemies")[528]) and is_same(XDB.rec("Enemies", 929), XDB.table("Enemies")[929]))
	var e: XEnemy = _guardian_battle(25)[1][0]
	_check("rollback.xparam_back", e.xparam(1) > 0.0 and e.xparam(3) > 0.0 and e.xparam(4) > 0.0 and e.xparam(7) > 0.0, _xp(e))
	var r := _guardian_battle(30)
	var t: XEnemy = r[1][0]
	r[0].enemy_transform(r[0].enemies.find(t), 538)
	_check("rollback.transform_back", t.xparam(7) > 0.0 and t.xparam(3) > 0.0, _xp(t))
	XGuardianRework.STRIP = true


func _xiyou() -> void:
	_state(25, false)
	_check("xiyou.rec_same", is_same(XDB.rec("Enemies", 528), XDB.table("Enemies")[528]) and is_same(XDB.rec("Enemies", 930), XDB.table("Enemies")[930]))
	var r := _guardian_battle(25, false)
	_check("xiyou.xparam_kept", r[1].size() == 1 and r[1][0].xparam(7) > 0.0 and r[1][0].xparam(3) > 0.0 and r[1][0].xparam(1) > 0.0, _xp(r[1][0]) if r[1].size() > 0 else null)
