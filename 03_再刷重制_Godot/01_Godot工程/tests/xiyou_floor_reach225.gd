extends Node
## 神庙与蜜雪冰城（盘点簇 14／12，悟空_55）＋指令 317（更改能力值）流程：
## - Map166 EV9／EV10 → Map171 神庙 (4,8)；Map171 EV1 九尾狐按变量 248（随机 1～16，固定住逐个试）给全队永久加减：
##   生命／魔法 ±1000、物攻／物防／魔攻／魔防／敏捷／幸运 ±100，记进 XState.mv_param_plus 并反映在角色能力上；
## - 参照（原版 Game_Interpreter.command317＋Game_Actor.addParam，参照引擎实测）：增加只加上限不回血；减到生命上限 1 时生命被截到 1；
##   指定角色只动该角色；能力值不低于 0；存档读回不丢；
## - Map004 EV70（开关 2496「宝宝难度」）→ Map225 蜜雪冰城 (38,32)；EV8 福利助手 ±5000／±1000；EV2 开启宝宝增益学会技能 5561；EV1 回 Map004 (17,6)。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const TIMEOUT_MS := 240000   # 并行负载下单个事件可能跑到一两分钟，别用 90 秒的墙钟判失败

var results: Array = []
var battles: Array = []   # 每场：{troop, result}


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	# 换场景（传送）时测试节点不能挂在当前场景下，挂到根节点
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _scene() -> Node:
	return get_tree().current_scene


func _wait_map(map_id: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		var s = _scene()
		if s is XMapScene and s.map_id == map_id and s.player != null and not s.busy:
			return true
		await get_tree().process_frame
	return false


func _event(map: XMapScene, id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null


## 队伍参数：生命极大、攻击魔攻 5e13（一回合打完）
func _party() -> void:
	for a in XState.current.members():
		var eq: Array = a.equip_list()
		var item: Dictionary
		if not eq.is_empty():
			item = eq[0]
		else:
			for id in range(1, 200):
				if XDB.rec("Weapons", id).is_empty():
					continue
				var inst := XGear.create("weapon", id)
				if not inst.is_empty() and a.can_equip(inst):
					XState.current.register_gear(inst)
					a.equips[0] = inst
					item = inst
					break
		if item.is_empty():
			continue
		item.params = [1.0e14, 1.0e6, 5.0e13, 5.0e6, 5.0e13, 5.0e6, 1.0e5, 1.0e3]
		a.refresh_passive()
		a.hp = a.mhp
		a.mp = a.mmp


func _battle_of(map: XMapScene) -> XBattleScene:
	for n in map.ui.get_children():
		if n is XBattleScene:
			return n
	return null


## 跑一个事件到结束；mode：""＝不干预，"win"＝战斗一开始击倒全部敌人，"lose"＝击倒全部队员
func _run_event(map: XMapScene, id: int, answers: Array, mode := "win") -> bool:
	var e := _event(map, id)
	if not _check("map%d_event%d_present" % [map.map_id, id], e != null):
		return false
	if not map.has_meta("watched"):
		map.set_meta("watched", true)
		map.ui.child_entered_tree.connect(func(n):
			if n is XBattleScene:
				n.finished.connect(func(r): battles.append({"troop": n.logic.troop_id, "result": r}), CONNECT_ONE_SHOT))
	XMessageBox.auto_answers = answers.duplicate()
	var st := {"done": false}
	(func():
		await map.run_event(e)
		st.done = true).call()
	var t0 := Time.get_ticks_msec()
	while not st.done and Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		var b := _battle_of(map)
		if b != null and not b.logic.enemies.is_empty():
			if mode == "win":
				for en in b.logic.enemies:
					if en.is_alive():
						en.hp = 0.0
						en.add_state(1)
			elif mode == "lose":
				for a in b.logic.actors:
					if a.is_alive():
						a.hp = 0.0
						a.add_state(1)
		await get_tree().process_frame
	return _check("map%d_event%d_finished" % [map.map_id, id], st.done)


func _start(map_id: int, x: int, y: int, dir := 8) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.map_id = map_id
	s.x = x
	s.y = y
	s.direction = dir
	_party()
	get_tree().change_scene_to_file(MAP_SCENE)
	return s


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_floor_reach225"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261024)
	await _temple()
	await _reference()
	await _baby_bus()
	MVEventCore.fixed_random = -1.0
	_finish()


func _plus(s: XState, id: int, param: int) -> int:
	var row = s.mv_param_plus.get(str(id))
	return int(row[param]) if row is Array else 0


## 神庙：Map166 EV9／EV10 进，九尾狐 16 种结果
func _temple() -> void:
	var s := _start(166, 30, 22, 8)
	if not _check("temple_loaded", await _wait_map(166)):
		return
	await _run_event(_scene(), 9, [], "")
	if not _check("temple_entered", await _wait_map(171) and _scene().player.grid == Vector2i(4, 8), [_scene().map_id]):
		return
	_check("temple_events", _event(_scene(), 1) != null)
	var amounts := [1000, 1000, 1000, 1000, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100]
	for i in range(16):
		MVEventCore.fixed_random = (float(i) + 0.5) / 16.0
		s = _start(171, 4, 5, 8)
		if not _check("fox_%d_loaded" % (i + 1), await _wait_map(171)):
			return
		var before := XState.current.members().map(func(a): return [a.mhp, a.mmp, a.param(2)])
		await _run_event(_scene(), 1, [], "")
		var param := int(i / 2)
		var sign_ := 1 if i % 2 == 0 else -1
		var want: int = sign_ * int(amounts[i])
		var ok := true
		for a in s.members():
			ok = ok and _plus(s, a.actor_id, param) == want
		_check("fox_%d_plus" % (i + 1), ok, [param, want, s.mv_param_plus])
		_check("fox_%d_other_params_zero" % (i + 1), s.members().all(func(a): return range(8).all(func(p): return p == param or _plus(s, a.actor_id, p) == 0)), [s.mv_param_plus])
		if param == 0 and sign_ == 1:
			var m: XActor = s.members()[0]
			_check("fox_mhp_up", int(m.mhp) == int(before[0][0]) + 1000, [m.mhp, before[0][0]])
		if param == 2 and sign_ == 1:
			var m2: XActor = s.members()[0]
			_check("fox_atk_up", int(m2.param(2)) == int(before[0][2]) + 100, [m2.param(2), before[0][2]])
		_check("fox_%d_switch" % (i + 1), s.switch(246))
	# 出口
	s = _start(171, 4, 8, 2)
	if _check("temple_exit_loaded", await _wait_map(171)):
		await _run_event(_scene(), 2, [], "")
		_check("temple_exit", await _wait_map(166) and _scene().player.grid == Vector2i(21, 9), [_scene().map_id, _scene().player.grid])


## 与参照引擎一致的几例（见头注）：host 用地图场景
func _reference() -> void:
	var s := _start(171, 4, 8, 2)
	if not _check("ref_loaded", await _wait_map(171)):
		return
	var map: XMapScene = _scene()
	s.add_actor(1)
	var ids := [8, 9, 10, 1]
	var base := {}
	for id in ids:
		var a := s.actor(id)
		base[id] = {"mhp": a.mhp, "hp": a.hp, "atk": a.param(2), "agi": a.param(6)}
	var list := [
		{"code": 317, "indent": 0, "parameters": [0, 0, 0, 0, 0, 1000]},
		{"code": 317, "indent": 0, "parameters": [0, 0, 6, 1, 0, 100]},
		{"code": 317, "indent": 0, "parameters": [0, 8, 2, 0, 0, 100]},
		{"code": 0, "indent": 0, "parameters": []}]
	await MVInterpreter.new(map, 171, 0, list).run()
	for id in ids:
		var a2 := s.actor(id)
		_check("ref_%d_mhp" % id, int(a2.mhp) == int(base[id].mhp) + 1000, [a2.mhp, base[id].mhp])
		_check("ref_%d_hp_kept" % id, int(a2.hp) == int(base[id].hp), [a2.hp, base[id].hp])
		_check("ref_%d_agi_floor" % id, int(a2.param(6)) == maxi(0, int(base[id].agi) - 100), [a2.param(6), base[id].agi])
		_check("ref_%d_atk" % id, int(a2.param(2)) == int(base[id].atk) + (100 if id == 8 else 0), [a2.param(2), base[id].atk])
	# 变量指定角色＋变量操作数：变量 5＝10 号角色，变量 6＝300
	s.set_variable(5, 10)
	s.set_variable(6, 300)
	await MVInterpreter.new(map, 171, 0, [{"code": 317, "indent": 0, "parameters": [1, 5, 3, 0, 1, 6]}, {"code": 0, "indent": 0, "parameters": []}]).run()
	_check("ref_var_actor", _plus(s, 10, 3) == 300 and _plus(s, 8, 3) == 0, [s.mv_param_plus])
	# 全队减到底：上限 1、生命截到 1
	s.set_variable(6, 1.0e15)   # 测试队伍装备把生命上限堆到 1e14，减得比它大才到底
	await MVInterpreter.new(map, 171, 0, [{"code": 317, "indent": 0, "parameters": [0, 0, 0, 1, 1, 6]}, {"code": 0, "indent": 0, "parameters": []}]).run()
	for id in ids:
		var a3 := s.actor(id)
		_check("ref_%d_floor" % id, int(a3.mhp) == 1 and int(a3.hp) == 1, [a3.mhp, a3.hp])
	# 存档读回
	var d := s.to_dict()
	var back := XState.from_dict(d)
	_check("ref_save_roundtrip", back != null and back.mv_param_plus == s.mv_param_plus, [d.get("mvParamPlus")])


## 蜜雪冰城：Map004 EV70（开关 2496）
func _baby_bus() -> void:
	var s := _start(4, 17, 6, 2)
	if not _check("bus_loaded", await _wait_map(4)):
		return
	var map: XMapScene = _scene()
	_check("bus_npc_present", _event(map, 70) != null)
	s.set_switch(2496, true)
	map.refresh_events()
	await _run_event(map, 70, [1], "")   # 不去
	_check("bus_declined", _scene().map_id == 4)
	await _run_event(map, 70, [0], "")
	if not _check("bus_entered", await _wait_map(225) and _scene().player.grid == Vector2i(38, 32), [_scene().map_id]):
		return
	map = _scene()
	_check("bus_events", [1, 2, 4, 8].all(func(i): return _event(map, i) != null))
	# EV8：+5000／+1000，再 −5000／−1000，回到 0
	var ids: Array = s.members().map(func(a): return a.actor_id)
	await _run_event(map, 8, [0], "")
	_check("bus_up", ids.all(func(id): return _plus(s, id, 0) == 5000 and _plus(s, id, 1) == 5000 and range(2, 8).all(func(p): return _plus(s, id, p) == 1000)), [s.mv_param_plus])
	await _run_event(map, 8, [1], "")
	_check("bus_down", ids.all(func(id): return range(8).all(func(p): return _plus(s, id, p) == 0)), [s.mv_param_plus])
	# EV2 福利助手：领取积分与材料 → 开启宝宝buff增益（技能 5561）
	await _run_event(map, 2, [1, 3], "")
	_check("bus_buff_skill", s.members().all(func(a): return a.skill_ids.has(5561)), [s.members().map(func(a): return a.skill_ids.has(5561))])
	await _run_event(map, 1, [], "")
	_check("bus_back", await _wait_map(4) and _scene().player.grid == Vector2i(17, 6), [_scene().map_id, _scene().player.grid])


func _finish() -> void:
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	print("战斗：", JSON.stringify(battles))
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
