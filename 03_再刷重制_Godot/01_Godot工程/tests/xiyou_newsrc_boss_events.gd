extends Node
## 新源（v0.62.12）剑道争锋与死神觉醒的地图 Boss 事件（悟空 floor4，切片 keepEvents 补进 16 个事件）。
## 每例：新开局 → 站到来源图 → 按第 0 页页条件设状态（角色在队、变量、开关、物品）→ 断言事件在地图上生成且自然选中第 0 页
## → 在地图场景里执行（选项答第一个，战斗一开始击倒全部敌人）→ 断言打的是原版敌群、胜利分支里的「变量＝常量」与独立开关照原版写上。
## 页条件、敌群与胜利分支都从原版地图数据读（不手抄）；事件本身逐条对照另由 xiyou_event_compare 做。
## Map145 EV11（开关 71 的切换，无战斗）只断言生成与选页。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const CASE_MS := 30000
const WaitBudget := preload("res://tests/wait_budget.gd")
const CASES := [[116, 11], [116, 12], [145, 9], [145, 10], [64, 11], [64, 12], [119, 19], [119, 20], [155, 25], [155, 26],
	[45, 10], [116, 13], [144, 15], [148, 39], [145, 12], [145, 11]]

var results: Array = []
var fails: Array = []


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
		fails.append(name)
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _scene() -> Node:
	return get_tree().current_scene


func _map_ready(map_id: int) -> bool:
	var s = _scene()
	return s is XMapScene and s.map_id == map_id and s.player != null


func _battle_of(map: Node) -> XBattleScene:
	if not (map is XMapScene):
		return null
	for n in map.ui.get_children():
		if n is XBattleScene:
			return n
	return null


## 胜利分支（601 到同缩进的 603／604）里的 122「变量＝常量」与 123 独立开关；第一个 301 的敌群
static func _expect(list: Array) -> Dictionary:
	var out := {"troop": 0, "vars": {}, "self": {}}
	var win_indent := -1
	for c in list:
		var code := int(c.code)
		if code == 301 and out.troop == 0:
			out.troop = int(c.parameters[1])
		elif code == 601 and win_indent < 0 and out.troop != 0:
			win_indent = int(c.indent)
		elif win_indent >= 0 and int(c.indent) == win_indent and code in [603, 604]:
			break
		elif win_indent >= 0 and int(c.indent) == win_indent + 1:
			if code == 122 and int(c.parameters[2]) == 0 and int(c.parameters[3]) == 0:
				for v in range(int(c.parameters[0]), int(c.parameters[1]) + 1):
					out.vars[str(v)] = float(c.parameters[4])
			elif code == 123:
				out.self[str(c.parameters[0])] = int(c.parameters[1]) == 0
	return out


func _apply_conditions(s: XState, cond: Dictionary) -> void:
	if cond.switch1Valid:
		s.set_switch(int(cond.switch1Id), true)
	if cond.switch2Valid:
		s.set_switch(int(cond.switch2Id), true)
	if cond.variableValid:
		s.set_variable(int(cond.variableId), float(cond.variableValue))
	if cond.itemValid:
		s.gain_item(int(cond.itemId), 1)
	if cond.actorValid:
		var id := int(cond.actorId)
		s.add_actor(id)
		if not s.party.has(id):  # 超强者（一护 148）默认难度被拦：照已入队的存档直接放进队伍
			s.actor(id)
			s.party.append(id)


func _case(m: int, ev_id: int) -> void:
	var tag := "m%de%d" % [m, ev_id]
	var data: Dictionary = {}
	for x in XDB.map(m).get("events", []):
		if x != null and int(x.id) == ev_id:
			data = x
	if not _check(tag + "_data", not data.is_empty()):
		return
	var page0: Dictionary = data.pages[0]
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.map_id = m
	s.x = int(data.x)
	s.y = int(data.y) + 1
	s.direction = 8
	_apply_conditions(s, page0.conditions)
	XActor.test_param_max = 1.0e30
	get_tree().change_scene_to_file(MAP_SCENE)
	var t0 := WaitBudget.new(CASE_MS)
	while t0.waiting() and not (_map_ready(m) and not _scene().busy):
		await get_tree().process_frame
	if not _check(tag + "_map_loaded", _map_ready(m), [_scene().get("map_id")]):
		return
	var map: XMapScene = _scene()
	var e: MVEvent = null
	for x in map.events:
		if x.event_id == ev_id:
			e = x
	if not _check(tag + "_spawned", e != null):
		return
	if not _check(tag + "_page0", e.page_index == 0, e.page_index):
		return
	var want := _expect(page0.list)
	if int(want.troop) == 0:
		return
	XMessageBox.auto_answers = [0]
	var st := {"done": false}
	(func():
		await map.run_event(e)
		st.done = true).call()
	var troop := 0
	t0 = WaitBudget.new(CASE_MS)
	while t0.waiting() and not st.done:
		var b := _battle_of(_scene())
		if b != null and not b.logic.enemies.is_empty():
			troop = int(b.troop_id)
			for en in b.logic.enemies:
				if en.is_alive():
					en.hp = 0.0
					en.add_state(1)
		await get_tree().process_frame
	_check(tag + "_finished", st.done)
	_check(tag + "_troop", troop == int(want.troop), {"want": want.troop, "got": troop})
	var got_vars := {}
	for k in want.vars:
		got_vars[k] = s.variable(int(k))
	_check(tag + "_win_vars", got_vars == want.vars, {"want": want.vars, "got": got_vars})
	var got_self := {}
	for ch in want.self:
		got_self[ch] = s.self_switch(m, ev_id, ch)
	_check(tag + "_win_self", got_self == want.self, {"want": want.self, "got": got_self})


func _run() -> void:
	GameApp.fast_forward()
	TestEnv.isolate("xiyou_newsrc_boss_events")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261107)
	for c in CASES:
		await _case(int(c[0]), int(c[1]))
	print("失败：", JSON.stringify(fails))
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


const TestEnv = preload("res://tests/xiyou_test_env.gd")
