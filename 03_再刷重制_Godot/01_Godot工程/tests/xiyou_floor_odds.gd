extends Node
## 盘点表小件（content2）放上地图：默认路径已有事件对照（与冻结 v0.28 一致），这里在地图场景里查放上、走得到、各支跑通：
## - 镇凶火焰（神秘生物刷新点，Star_PetSystem PetMap 1～4）：Map010 EV11、Map012 EV23、Map047 EV15、Map064 EV3；独立开关 A 开时出现，
##   打敌群 1，胜后关 A、成就 61。
## - Map064：去信徒藏身 Map192 (6,28) 的另一格（6）、小毒（7，变量 14≥1 时询问→接受：公共事件 1330 一线生机与天道注视，独立开关 A）、
##   铃兰彩蛋（8，角色 127 在队给物品 1436）。
## - Map017：戴律茂（4，牛头人 66 击杀数 ≥999 解锁称号 5、成就 121；不够认证失败）、开关 172 后去剑气长城 Map139 (13,30) 的门（5）、
##   张楚岚彩蛋（6，角色 128，物品 1437）；Map046 天虎令彩蛋（5，角色 104，物品 1431）。
## - Map213 一护修炼卍解（2）：角色 109 在队、变量 1309≥1、1318≥1 时打敌群 962，胜后物品 2852、变量 1305／1306＝1、独立开关 B；
##   第 2 页（B 且 1306≥1）变量 1311、1309 都 ≥1 给武器 807。
## - Map119 天才灵魂（15）：「进行修炼」设修炼表项 25～32 并开修炼界面。
## - Map166 EV8：传到本图 (30,21)。
## - 十五层雷劫 Map032 EV9：开关 2285 时打敌群 823，99 号角色忘掉 8069、关开关 2285。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const REACH := preload("res://tests/xiyou_reach_check.gd")
const TIMEOUT_MS := 240000
const WaitBudget := preload("res://tests/wait_budget.gd")
## 本期放上的事件（地图 → 事件号）与落点（大厅门／副本入口传来的位置）
const ADDED := {
	10: [11], 12: [23], 47: [15], 64: [3, 6, 7, 8], 17: [4, 5, 6], 46: [5], 213: [2], 119: [15], 166: [8], 32: [9, 10],
}
const LANDING := {
	10: Vector2i(17, 16), 12: Vector2i(13, 17), 47: Vector2i(14, 40), 64: Vector2i(30, 24), 17: Vector2i(26, 29),
	46: Vector2i(21, 49), 213: Vector2i(13, 2), 119: Vector2i(22, 33), 166: Vector2i(14, 35), 32: Vector2i(31, 14),
}
## 出现条件（走得到检查前先满足）：独立开关、开关、入队角色、变量
const SETUP := {
	[10, 11]: {"self": "A"}, [12, 23]: {"self": "A"}, [47, 15]: {"self": "A"}, [64, 3]: {"self": "A"},
	[64, 8]: {"actor": 127}, [17, 5]: {"switch": 172}, [17, 6]: {"actor": 128}, [46, 5]: {"actor": 104},
	[213, 2]: {"actor": 109, "vars": {1309: 1}}, [32, 9]: {"switch": 2285}, [32, 10]: {"switch": 2285},
}
## 并行事件不用走到
const PARALLEL := [[32, 10]]

var results: Array = []
var battles: Array = []   # 每场：{troop, result}
var pages: Array = []     # 打开过的界面


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
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
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while t0.waiting():
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
		XActor.test_param_max = 1.0e30  # 队伍属性堆过原版上限 99999999（XActor.PARAM_MAX），只在测试里放开
		a.refresh_passive()
		a.hp = a.mhp
		a.mp = a.mmp


## 开局：放到落点，按 SETUP 满足出现条件
func _start(m: int, id: int, extra := {}) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.map_id = m
	s.x = LANDING[m].x
	s.y = LANDING[m].y
	s.direction = 8
	s.set_variable(20, 31)
	var setup: Dictionary = SETUP.get([m, id], {}).merged(extra, true)
	if str(setup.get("self", "")) != "":
		s.set_self_switch(m, id, str(setup.self), true)
	if setup.has("switch"):
		s.set_switch(int(setup.switch), true)
	if setup.has("actor"):
		s.add_actor(int(setup.actor))
	for v in setup.get("vars", {}):
		s.set_variable(int(v), int(setup.vars[v]))
	_party()
	get_tree().change_scene_to_file(MAP_SCENE)
	return s


func _battle_of(map: XMapScene) -> XBattleScene:
	for n in map.ui.get_children():
		if n is XBattleScene:
			return n
	return null


func _on_ui_child(n: Node) -> void:
	if n is XBattleScene:
		n.finished.connect(func(r): battles.append({"troop": n.logic.troop_id, "result": r}), CONNECT_ONE_SHOT)
	elif n.has_signal("closed"):
		pages.append(n.get_class() if n.get_script() == null else str(n.get_script().get_global_name()))
		n.closed.emit.call_deferred()


## 跑一个事件到结束；战斗一开始击倒全部敌人
func _run_event(map: XMapScene, id: int, answers: Array) -> bool:
	var e := _event(map, id)
	if not _check("map%d_event%d_present" % [map.map_id, id], e != null):
		return false
	if not map.has_meta("watched"):
		map.set_meta("watched", true)
		map.ui.child_entered_tree.connect(_on_ui_child)
	XMessageBox.auto_answers = answers.duplicate()
	var st := {"done": false}
	(func():
		await map.run_event(e)
		st.done = true).call()
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while not st.done and t0.waiting():
		var b := _battle_of(map)
		if b != null and not b.logic.enemies.is_empty():
			for en in b.logic.enemies:
				if en.is_alive():
					en.hp = 0.0
					en.add_state(1)
		await get_tree().process_frame
	return _check("map%d_event%d_finished" % [map.map_id, id], st.done)


## 开局并跑一个事件；返回开局的存档（地图没起来返回 null）
func _play(m: int, id: int, answers: Array, extra := {}) -> XState:
	var s := _start(m, id, extra)
	if not _check("start_map%d_ev%d" % [m, id], await _wait_map(m)):
		return null
	var map: XMapScene = _scene()
	map.skipped_log.clear()
	battles.clear()
	pages.clear()
	XToast.shown.clear()
	await _run_event(map, id, answers)
	if is_instance_valid(map):
		_check("no_skipped_map%d_ev%d" % [m, id], map.skipped_log.is_empty(), map.skipped_log.slice(0, 3))
	return s


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_floor_odds"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XShop.auto_close = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261102)
	_kept()
	for m in ADDED:
		for id in ADDED[m]:
			await _reach(m, id)
	await _flames()
	await _map064()
	await _map017()
	await _ichigo()
	await _misc()
	_finish()


func _kept() -> void:
	var keep: Dictionary = XMapScene.slice().get("keepEvents", {})
	for m in ADDED:
		var got: Array = keep.get(str(m), []).map(func(v): return int(v))
		_check("kept_map%d" % m, (ADDED[m] as Array).all(func(id): return got.has(int(id))), [got, ADDED[m]])


## 满足出现条件后出现（有页）、从落点走得到
func _reach(m: int, id: int) -> void:
	_start(m, id)
	if not _check("reach_start_map%d_ev%d" % [m, id], await _wait_map(m)):
		return
	var e := _event(_scene(), id)
	_check("shown_map%d_ev%d" % [m, id], e != null and e.page_index >= 0, e.page_index if e != null else null)
	if PARALLEL.has([m, id]):
		return
	var miss := REACH.unreachable(_scene(), _scene().player.grid, [id])
	_check("reach_map%d_ev%d" % [m, id], miss.is_empty(), miss)


## 镇凶火焰：独立开关 A 关时不出现；开时打敌群 1，胜后关 A、成就 61
func _flames() -> void:
	for p in [[10, 11], [12, 23], [47, 15], [64, 3]]:
		var s := _start(p[0], p[1], {"self": ""})
		s.set_self_switch(p[0], p[1], "A", false)
		if await _wait_map(p[0]):
			var e := _event(_scene(), p[1])
			_check("flame_hidden_map%d" % p[0], e == null or e.page_index == -1, e.page_index if e != null else null)
		s = await _play(p[0], p[1], [])
		if s == null:
			continue
		_check("flame_battle_map%d" % p[0], battles.size() == 1 and int(battles[0].troop) == 1 and int(battles[0].result) == 0, battles)
		_check("flame_off_map%d" % p[0], not s.self_switch(p[0], p[1], "A"))
		_check("flame_ac61_map%d" % p[0], bool(s.achievements.get("61", false)), s.achievements.keys())


func _map064() -> void:
	# 信徒藏身另一格：传到 Map192 (6,28)
	var s := await _play(64, 6, [])
	if s != null:
		_check("m64e6_transfer", await _wait_map(192) and _scene().player.grid == Vector2i(6, 28), [_scene().map_id, _scene().player.grid])
	# 小毒：变量 14 为 0 时不给；≥1 时询问→接受
	s = await _play(64, 7, [0, 0])
	if s != null:
		_check("m64e7_no_will", not s.self_switch(64, 7, "A") and not s.actor(8).skill_ids.has(6213))
	s = await _play(64, 7, [0, 0], {"vars": {14: 1}})
	if s != null:
		_check("m64e7_accept", s.self_switch(64, 7, "A"), s.self_switch(64, 7, "A"))
		_check("m64e7_gaze", s.actor(8).skill_ids.has(6213), s.actor(8).skill_ids.filter(func(k): return k in [6212, 6213]))
		_check("m64e7_toasts", XToast.shown.any(func(t): return str(t).contains("一线生机")) and XToast.shown.any(func(t): return str(t).contains("天道所注视")), XToast.shown)
	# 铃兰彩蛋：角色 127 在队
	s = await _play(64, 8, [])
	if s != null:
		_check("m64e8_gift", s.item_count(1436) == 1 and s.self_switch(64, 8, "A"), s.item_count(1436))


func _map017() -> void:
	# 戴律茂：牛头人（敌人 66）击杀数不够 → 失败；≥999 → 称号 5、成就 121
	var s := await _play(17, 4, [0])
	if s != null:
		_check("m17e4_fail", not XDesignation.unlocked(5) and not s.achievements.has("121"))
	s = _start(17, 4)
	XEnemyBook._book(s).defeat["66"] = 999
	if await _wait_map(17):
		XToast.shown.clear()
		await _run_event(_scene(), 4, [0])
		_check("m17e4_pass", XDesignation.unlocked(5) and bool(s.achievements.get("121", false)), s.achievements.keys())
	# 剑气长城门：开关 172 时选「前往」
	s = await _play(17, 5, [0])
	if s != null:
		_check("m17e5_transfer", await _wait_map(139) and _scene().player.grid == Vector2i(13, 30), [_scene().map_id, _scene().player.grid])
	# 张楚岚彩蛋、天虎令彩蛋
	s = await _play(17, 6, [])
	if s != null:
		_check("m17e6_gift", s.item_count(1437) == 1 and s.self_switch(17, 6, "A"), s.item_count(1437))
	s = await _play(46, 5, [])
	if s != null:
		_check("m46e5_gift", s.item_count(1431) == 1 and s.self_switch(46, 5, "A"), s.item_count(1431))


## 一护修炼卍解：决心（变量 1318）不够不打；够了打敌群 962，再来第 2 页给斩月-II（武器 807）
func _ichigo() -> void:
	var s := await _play(213, 2, [])
	if s != null:
		_check("m213e2_no_will", battles.is_empty() and s.item_count(2852) == 0, battles)
	s = await _play(213, 2, [], {"vars": {1309: 1, 1318: 1}})
	if s == null:
		return
	_check("m213e2_battle", battles.size() == 1 and int(battles[0].troop) == 962 and int(battles[0].result) == 0, battles)
	_check("m213e2_reward", s.item_count(2852) == 1 and int(s.variable(1305)) == 1 and int(s.variable(1306)) == 1 and s.self_switch(213, 2, "B"),
		[s.item_count(2852), s.variable(1305), s.variable(1306)])
	var e := _event(_scene(), 2)
	_check("m213e2_page2", e != null and e.page_index == 1, e.page_index if e != null else null)
	s.set_variable(1311, 1)
	battles.clear()
	await _run_event(_scene(), 2, [])
	_check("m213e2_weapon", s.gear_count("weapon", 807) == 1 and s.self_switch(213, 2, "A") and battles.is_empty(), s.gear_count("weapon", 807))


func _misc() -> void:
	# 天才灵魂：进行修炼
	var s := await _play(119, 15, [0])
	if s != null:
		_check("m119e15_training", pages.has("XTrainingScene") and XTraining.xiulian == [25, 26, 27, 28, 29, 30, 31, 32], [pages, XTraining.xiulian])
	# Map166 EV8：传到本图 (30,21)
	s = await _play(166, 8, [])
	if s != null:
		_check("m166e8_transfer", await _wait_map(166) and _scene().player.grid == Vector2i(30, 21), _scene().player.grid)
	# 雷劫：打敌群 823，99 号角色忘掉 8069，关开关 2285
	s = _start(32, 9)
	s.actor(99).learn_skill(8069)
	if await _wait_map(32):
		battles.clear()
		XToast.shown.clear()
		await _run_event(_scene(), 9, [])
		_check("m32e9_battle", battles.size() == 1 and int(battles[0].troop) == 823 and int(battles[0].result) == 0, battles)
		_check("m32e9_unseal", not s.actor(99).skill_ids.has(8069) and not s.switch(2285), [s.actor(99).skill_ids.has(8069), s.switch(2285)])
		_check("m32e9_toast", XToast.shown.any(func(t): return str(t).contains("封闭枷锁")), XToast.shown)
		var e := _event(_scene(), 9)
		_check("m32e9_gone", e == null or e.page_index == -1)


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
