extends Node
## 三十层（Map146 住峰天）玉皇大帝「向守层员索要礼物」与奇异石碑里的 `$gameVariables.setValue(900／899, 1)`：这两条脚本必须走 XState.set_variable，
## 值才会存进跨存档（XGlobalVars，dev.098）；新开局时 900／899 盖回来，开局事件调的公共事件 1322／1328 让全员学到 6176 胜天半子／6205 代天巡狩。
## 普通流程（开关 2302 关）：玉皇大帝胜后第 2 页——索礼变量 878（没交见面礼胜后置 1）、变量 14（是否开启高难度）决定给 6176（真）还是 6177（伪）；
## 石碑只在开关 2302 开时有分支（878＝1 才触碰得到）。Map158 古龙祭坛入口 EV1 里的 setValue(1476, 1) 同一条脚本写法（Map158 不在切片，只有写法由 mv_script 覆盖）。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const FLOOR_MAP := 146
const TIMEOUT_MS := 90000

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


func _battle_of(map: XMapScene) -> XBattleScene:
	for n in map.ui.get_children():
		if n is XBattleScene:
			return n
	return null


## 跑一个事件到结束（或换了地图）；kill：战斗一开始就把敌人全部击倒
func _run_event(map: XMapScene, id: int, answers: Array, kill := false) -> bool:
	var e := _event(map, id)
	if not _check("map%d_event%d_present" % [map.map_id, id], e != null and not e.page.is_empty()):
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
		if kill:
			var b := _battle_of(map)
			if b != null and not b.logic.enemies.is_empty():
				for en in b.logic.enemies:
					if en.is_alive():
						en.hp = 0.0
						en.add_state(1)
		await get_tree().process_frame
	return _check("map%d_event%d_finished" % [map.map_id, id], st.done)



## 复刻 Map146 宿主需要的：解释器 host（新开局后重放公共事件 1322／1328，只用到脚本里的学技能循环）
func toast(_text: String) -> void:
	pass

func refresh_events() -> void:
	pass


func _learned(s: XState, skill: int) -> bool:
	return [8, 9, 10].all(func(a): return s.actor(a).skill_ids.has(skill))


func _none_learned(s: XState, skill: int) -> bool:
	return [8, 9, 10].all(func(a): return not s.actor(a).skill_ids.has(skill))


func _stored(id: int):
	return XGlobalVars.stored().variables.get(id)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_floor30_gifts"
	XConfig.path_override = XSave.dir().path_join("options.json")
	DirAccess.make_dir_recursive_absolute(XSave.dir_override)
	DirAccess.remove_absolute(XSave.dir_override.path_join("global.json"))
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.set_variable(20, 31)           # 守层者玉皇大帝已打过（变量 20 加一）
	s.set_self_switch(FLOOR_MAP, 1, "A", true)
	s.map_id = FLOOR_MAP
	s.x = 22
	s.y = 14
	s.direction = 8
	# 起点：新开局没有跨存档值
	_check("start_no_900", _stored(900) == null and s.variable(900) == 0, [_stored(900), s.variable(900)])
	get_tree().change_scene_to_file(MAP_SCENE)
	if not _check("floor30_loaded", await _wait_map(FLOOR_MAP)):
		_finish()
		return
	var map: XMapScene = _scene()
	# 第 2 页（守层者胜后）「向守层员索要礼物」（选项下标 1）：878（没交见面礼、胜后置 1）为 0 时只劝一句，什么也不写
	await _run_event(map, 1, [1])
	_check("no_gift_without_878", s.variable(900) == 0 and _stored(900) == null and _none_learned(s, 6176) and _none_learned(s, 6177), [s.variable(900), _stored(900)])
	# 878＝1、变量 14（是否开启高难度）＝0：公共事件 1323 学「胜天半子*伪」6177，不写 900
	s.set_variable(878, 1)
	map.toasts.clear()
	await _run_event(map, 1, [1])
	_check("fake_passive", _learned(s, 6177) and _none_learned(s, 6176) and s.variable(900) == 0 and _stored(900) == null, [s.variable(900), _stored(900)])
	_check("fake_toast", map.toasts.has("获得被动：胜天半子*伪！"), map.toasts)
	# 变量 14＝1：脚本 $gameVariables.setValue(900, 1) 写变量 900，走 set_variable 才存进跨存档；再公共事件 1322 学 6176
	s.set_variable(14, 1)
	map.toasts.clear()
	await _run_event(map, 1, [1])
	_check("setvalue_900", s.variable(900) == 1.0, s.variable(900))
	_check("global_900_stored", _stored(900) == 1.0, XGlobalVars.stored())
	_check("global_900_file", FileAccess.file_exists(XGlobalVars.path()) and float(JSON.parse_string(FileAccess.get_file_as_string(XGlobalVars.path())).variables.get("900", 0)) == 1.0, XGlobalVars.path())
	_check("passive_6176", _learned(s, 6176), s.actor(8).skill_ids)
	_check("passive_toast", map.toasts.has("你达成了高难度挑战，获得被动：胜天半子！"), map.toasts)
	# 新开局：900 从跨存档盖回来，开局 Map002 调的公共事件 1322 让全员学到 6176
	var fresh := XState.new_game(3, 1, [8, 9, 10])
	_check("new_game_900", fresh.variable(900) == 1.0, fresh.variable(900))
	_check("new_game_not_yet_learned", _none_learned(fresh, 6176))
	var interp := MVInterpreter.new(self, 0, 0, XDB.rec("CommonEvents", 1322).list)
	await interp.run()
	_check("new_game_learns_6176", _learned(fresh, 6176), fresh.actor(8).skill_ids)
	_check("new_game_900_skips_6205", _none_learned(fresh, 6205))
	# 奇异石碑（2）「伸手触碰」（选项下标 0）：只在开关 2302 时有分支；878＝0 时只提示，878＝1 时 setValue(899, 1)＋公共事件 1328
	XState.current = s
	s.set_switch(2302, true)
	s.set_variable(878, 0)
	XMessageBox.transcript.clear()
	await _run_event(map, 2, [0])
	_check("stone_refused", s.variable(899) == 0 and _stored(899) == null and XMessageBox.transcript.any(func(t): return str(t).contains("你还没有战胜最后的敌人")), [s.variable(899), XMessageBox.transcript])
	s.set_variable(878, 1)
	map.toasts.clear()
	await _run_event(map, 2, [0])
	_check("setvalue_899", s.variable(899) == 1.0 and _stored(899) == 1.0, [s.variable(899), _stored(899)])
	_check("passive_6205", _learned(s, 6205), s.actor(8).skill_ids)
	_check("stone_toast", map.toasts.has("你达成了高难度挑战，获得被动：代天巡狩！"), map.toasts)
	# 新开局：899 盖回来，公共事件 1328 学 6205
	fresh = XState.new_game(3, 1, [8, 9, 10])
	_check("new_game_899", fresh.variable(899) == 1.0 and fresh.variable(900) == 1.0, [fresh.variable(899), fresh.variable(900)])
	interp = MVInterpreter.new(self, 0, 0, XDB.rec("CommonEvents", 1328).list)
	await interp.run()
	_check("new_game_learns_6205", _learned(fresh, 6205), fresh.actor(8).skill_ids)
	_finish()


func _finish() -> void:
	DirAccess.remove_absolute(XGlobalVars.path())
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
