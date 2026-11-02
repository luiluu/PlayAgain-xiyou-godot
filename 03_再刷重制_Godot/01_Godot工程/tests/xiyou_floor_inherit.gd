extends Node
## 传承人（content2）：十五层 Map032 EV8、二十层 Map116 EV7、二十五层 Map147 EV5，只在开关 2303（选择随机角色）或 2307（轮回模式）时出现。
## 默认路径已有事件对照（m32e8p*／m116e7p*／m147e5p*）；这里在地图场景里查：
## - 放上地图：切片 keepEvents 含这三个事件；落点（大厅门传来的 (31,14)／(17,27)／(12,21)）按图块走得到。
## - 页：开关 2303 第 1 页、2307 第 3 页；变量 20（层数）过了本层（≥16／21／26）换「传承之火已熄」页（2／4），没有战斗；两个开关都关不出现。
## - 五支传承逐支：先用技能书的公共事件（1346／1350／1356／1360／1366）记下学习者（物品选中 8 号），
##   选这一支 → 打传承战（敌群）→ 学习公共事件让 8 号忘旧学新 → 变量置 1、提示「你获得了…的传承！」；再选同一支只说「你已经获得我的传承」，不再打。
## - 敌群事件（每层第一支）：第 0 回合页调公共事件 1396 强者领域，全队加 1105 霸者*灭绝、敌人加 1109 等；没有跳过的指令。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const REACH := preload("res://tests/xiyou_reach_check.gd")
const TIMEOUT_MS := 240000
const WaitBudget := preload("res://tests/wait_budget.gd")
const LEARNER := 8
## 技能书公共事件：记学习者（$gameParty._targetActorId）到变量
const BOOK_CE := {857: 1346, 881: 1350, 882: 1356, 883: 1360, 884: 1366}
## 地图 → 事件、层数、落点、五支（选项顺序）：传承变量、敌群、记学习者的变量、学会／忘掉的技能
const FLOORS := {
	32: {"event": 8, "floor": 15, "land": Vector2i(31, 14), "rows": [
		{"var": 810, "troop": 774, "actorVar": 857, "learn": [6218], "forget": []},
		{"var": 811, "troop": 775, "actorVar": 881, "learn": [6232], "forget": []},
		{"var": 812, "troop": 772, "actorVar": 882, "learn": [6226], "forget": [6225]},
		{"var": 813, "troop": 773, "actorVar": 883, "learn": [6222], "forget": [6221]},
		{"var": 823, "troop": 784, "actorVar": 884, "learn": [2828], "forget": []}]},
	116: {"event": 7, "floor": 20, "land": Vector2i(17, 27), "rows": [
		{"var": 814, "troop": 778, "actorVar": 857, "learn": [6219], "forget": []},
		{"var": 815, "troop": 779, "actorVar": 881, "learn": [6233], "forget": []},
		{"var": 816, "troop": 776, "actorVar": 882, "learn": [6227], "forget": [6226]},
		{"var": 817, "troop": 777, "actorVar": 883, "learn": [6223], "forget": [6222]},
		{"var": 824, "troop": 785, "actorVar": 884, "learn": [2829], "forget": []}]},
	147: {"event": 5, "floor": 25, "land": Vector2i(12, 21), "rows": [
		{"var": 818, "troop": 782, "actorVar": 857, "learn": [6220], "forget": []},
		{"var": 819, "troop": 783, "actorVar": 881, "learn": [6234], "forget": []},
		{"var": 820, "troop": 780, "actorVar": 882, "learn": [6228], "forget": [6227]},
		{"var": 830, "troop": 781, "actorVar": 883, "learn": [6224], "forget": [6223]},
		{"var": 825, "troop": 786, "actorVar": 884, "learn": [2830], "forget": []}]},
}

var results: Array = []
var battles: Array = []   # 每场：{troop, result}
var battle_skipped: Array = []
## 敌群事件第 0 回合页之后看到的状态：{troop, actor1105, enemy1109}
var observed: Array = []


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


func _start(map_id: int, switches: Array, floor_var: int) -> XState:
	var s := XState.new_game(3, 1, [LEARNER, 9, 10])
	XState.current = s
	s.map_id = map_id
	var land: Vector2i = FLOORS[map_id].land
	s.x = land.x
	s.y = land.y
	s.direction = 8
	s.set_variable(20, floor_var)
	for sw in switches:
		s.set_switch(int(sw), true)
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
		n.finished.connect(func(r):
			battles.append({"troop": n.logic.troop_id, "result": r})
			battle_skipped.append_array(n.logic.troop_event_skipped)
			battle_skipped.append_array(n.logic.common_event_skipped), CONNECT_ONE_SHOT)


## 跑事件到结束：mode "win"＝战斗一开始就击倒敌人；"observe"＝先等敌群第 0 回合页跑完（全队有 1105）记下状态再击倒
func _run_event(map: XMapScene, id: int, answers: Array, mode := "win") -> bool:
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
		if b != null and not b.logic.enemies.is_empty() and b.logic.enemies.any(func(en): return en.is_alive()):
			var kill := mode == "win"
			if mode == "observe":
				var a1105: bool = b.logic.actors.all(func(a): return a.is_state_affected(1105))
				if a1105 or b.logic.turn >= 3:
					observed.append({"troop": b.logic.troop_id, "actor1105": a1105,
						"enemy1109": b.logic.enemies.all(func(en): return en.is_state_affected(1109))})
					mode = "win"
					kill = true
			if kill:
				for en in b.logic.enemies:
					if en.is_alive():
						en.hp = 0.0
						en.add_state(1)
		await get_tree().process_frame
	return _check("map%d_event%d_finished" % [map.map_id, id], st.done)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_floor_inherit"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XShop.auto_close = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261102)
	_kept()
	for m in FLOORS:
		await _pages(m)
		for i in 5:
			await _branch(m, i)
	_finish()


func _kept() -> void:
	var keep: Dictionary = XMapScene.slice().get("keepEvents", {})
	for m in FLOORS:
		var got: Array = keep.get(str(m), []).map(func(v): return int(v))
		_check("kept_map%d" % m, got.has(int(FLOORS[m].event)), got)


## 页的选择、落点走得到、过层后熄灭
func _pages(m: int) -> void:
	var f: Dictionary = FLOORS[m]
	var id := int(f.event)
	# 开关 2303：第 1 页；落点走得到
	var s := _start(m, [2303], int(f.floor))
	if not _check("start_map%d" % m, await _wait_map(m)):
		return
	var e := _event(_scene(), id)
	_check("page_2303_map%d" % m, e != null and e.page_index == 0, e.page_index if e != null else null)
	_check("reach_map%d" % m, REACH.unreachable(_scene(), _scene().player.grid, [id]).is_empty())
	# 开关 2307：第 3 页
	s = _start(m, [2307], int(f.floor))
	if await _wait_map(m):
		e = _event(_scene(), id)
		_check("page_2307_map%d" % m, e != null and e.page_index == 2, e.page_index if e != null else null)
	# 两个开关都关：不出现
	s = _start(m, [], int(f.floor))
	if await _wait_map(m):
		e = _event(_scene(), id)
		_check("page_none_map%d" % m, e == null or e.page_index == -1, e.page_index if e != null else null)
	# 过了本层（层数＋1）：「传承之火已熄」页，选不了、不打
	for sw in [[2303, 1], [2307, 3]]:
		s = _start(m, [sw[0]], int(f.floor) + 1)
		if not await _wait_map(m):
			continue
		e = _event(_scene(), id)
		_check("page_out_%d_map%d" % [sw[0], m], e != null and e.page_index == sw[1], e.page_index if e != null else null)
		battles.clear()
		await _run_event(_scene(), id, [0], "win")
		_check("out_no_battle_%d_map%d" % [sw[0], m], battles.is_empty() and int(s.variable(int(f.rows[0].var))) == 0, battles)


## 第 i 支：技能书记学习者 → 选这支 → 传承战 → 学技能、变量置 1；再选只说已获得
func _branch(m: int, i: int) -> void:
	var f: Dictionary = FLOORS[m]
	var row: Dictionary = f.rows[i]
	var tag := "map%d_b%d" % [m, i]
	var s := _start(m, [2303 if i % 2 == 0 else 2307], int(f.floor))
	if not _check("start_" + tag, await _wait_map(m)):
		return
	var map: XMapScene = _scene()
	map.skipped_log.clear()
	var a := s.actor(LEARNER)
	for sk in row.forget:
		a.learn_skill(int(sk))
	s.item_target_actor_id = LEARNER
	await map.run_common_event(int(BOOK_CE[int(row.actorVar)]))
	_check("book_" + tag, int(s.variable(int(row.actorVar))) == LEARNER, s.variable(int(row.actorVar)))
	s.item_target_actor_id = 0
	battles.clear()
	battle_skipped.clear()
	XToast.shown.clear()
	await _run_event(map, int(f.event), [i], "observe" if i == 0 else "win")
	_check("battle_" + tag, battles.size() == 1 and int(battles[0].troop) == int(row.troop) and int(battles[0].result) == 0, battles)
	_check("var_" + tag, int(s.variable(int(row.var))) == 1, s.variable(int(row.var)))
	var learned: bool = (row.learn as Array).all(func(sk): return a.skill_ids.has(int(sk)))
	var forgot: bool = (row.forget as Array).all(func(sk): return not a.skill_ids.has(int(sk)))
	_check("skills_" + tag, learned and forgot, [row.learn, row.forget, a.skill_ids.filter(func(sk): return int(sk) >= 6218 and int(sk) <= 6234 or int(sk) >= 2828 and int(sk) <= 2830)])
	_check("toast_" + tag, XToast.shown.any(func(t): return str(t).contains("的传承！")), XToast.shown)
	if i == 0:
		var ob: Dictionary = observed.back() if not observed.is_empty() else {}
		_check("troop_event_" + tag, int(ob.get("troop", 0)) == int(row.troop) and bool(ob.get("actor1105", false)) and bool(ob.get("enemy1109", false)), ob)
	# 再选同一支：已获得，不再打
	battles.clear()
	await _run_event(map, int(f.event), [i], "win")
	_check("again_" + tag, battles.is_empty() and int(s.variable(int(row.var))) == 1, battles)
	_check("no_skipped_" + tag, map.skipped_log.is_empty() and battle_skipped.is_empty(), [map.skipped_log.slice(0, 3), battle_skipped.slice(0, 3)])


func _finish() -> void:
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	print("敌群事件：", JSON.stringify(observed))
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
