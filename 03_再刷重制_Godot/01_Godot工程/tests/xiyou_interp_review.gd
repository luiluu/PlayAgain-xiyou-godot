extends Node
## 云端审查（dev.049～081）转来的解释器三项（八戒_47）：与 mv_oracle/review_fix_probe.cjs 的 erase.*、flush.225.* 逐例比。
## erase.*：指令 214 只在解释器起跑的地图＝当前地图时消除（isOnCurrentMap）；消除随存档（$gameMap 进存档、同版本读档不重设地图），
## 同图移动保留，换图再回来恢复。真实 XMapScene（Map008 副本怪事件 3）、真实 XSave 存读档后重开地图场景、真实 transfer。
## flush.225.*：316 升级提示进待显示文字后，225 勾等待时 MV 在等待的 10 帧里显示消息、等完才执行 122（参照帧号 > 1）；
## 不勾等待时同一帧执行 122。Godot 把「等待期间显示」做成等待前先显示（同 230），对照「122 执行前消息是否已显示」。
## transfer.*（八戒_48）：同图 201 不重建事件——事件节点、位置、朝向、强制路线与索引、页原样保留，玩家与跟随者重新放置；
## 换图再回来恢复初始。参照里给事件 3 挂的等待解释器（模拟并行事件）Godot 无对应（切片地图没有并行事件），不比 interp。
## MV 不强制路线时 _moveRoute 是当前页的自主路线，Godot 留在 page.moveRoute，route 长度按此取。
## 为免过渡淡入淡出期间路线自己往前走，两个事件先停掉 _physics_process（参照引擎里同样不推进帧）。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const ORACLE := "res://modes/xiyou/generated/oracle/review_fix.json"
const TIMEOUT_MS := 60000
const WaitBudget := preload("res://tests/wait_budget.gd")  # 墙钟与帧数都过了才算超时（tools30）

var results: Array = []
var s: XState


## 只推进核心时的宿主：122 改变量后刷新事件页
class StubHost:
	extends Node
	func refresh_events() -> void:
		pass


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	# 换场景时测试节点不能挂在当前场景下，挂到根节点
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _wait_map(map_id: int) -> XMapScene:
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while t0.waiting():
		var m = get_tree().current_scene
		if m is XMapScene and m.map_id == map_id and m.player != null and not m.busy:
			return m
		await get_tree().process_frame
	return null


func _open(map_id: int, x: int, y: int) -> XMapScene:
	s.map_id = map_id
	s.x = x
	s.y = y
	get_tree().change_scene_to_file(MAP_SCENE)
	return await _wait_map(map_id)


static func _erased(map: XMapScene) -> Array:
	return map.events.filter(func(e): return e.erased).map(func(e): return float(e.event_id))  # JSON 读出的参照数字是 float


static func _cmd(code: int, parameters: Array) -> Dictionary:
	return {"code": code, "indent": 0, "parameters": parameters}


func _run_list(map: XMapScene, list: Array, event_id: int) -> void:
	await MVInterpreter.new(map, map.map_id, event_id, list).run()


## 新局站在 Map008 以事件 3 的身份跑一条 214
func _erase8() -> XMapScene:
	s = XState.new_game(3, 1, [8, 9, 10])
	var map := await _open(8, 29, 26)
	if map != null:
		await _run_list(map, [_cmd(214, []), _cmd(0, [])], 3)
	return map


## XSave 真存档再读档，重开地图场景（同 Scene_Load → Scene_Map，不重设地图）
func _roundtrip() -> XMapScene:
	if not XSave.save(1) or not XSave.load_slot(1):
		return null
	s = XState.current
	get_tree().change_scene_to_file(MAP_SCENE)
	return await _wait_map(s.map_id)


func _erase_case(id: String) -> Dictionary:
	if id == "erase.afterTransfer":
		s = XState.new_game(3, 1, [8, 9, 10])
		var hub := await _open(4, 14, 23)
		if hub == null:
			return {"error": "Map004 未载入"}
		await _run_list(hub, [_cmd(201, [0, 8, 29, 26, 2, 0]), _cmd(214, []), _cmd(0, [])], 3)
		var m8 := await _wait_map(8)
		return {"map": float(m8.map_id), "after": _erased(m8)} if m8 else {"error": "Map008 未载入"}
	var map := await _erase8()
	if map == null:
		return {"error": "Map008 未载入"}
	var after := _erased(map)
	map = await _roundtrip()
	if map == null:
		return {"error": "存读档后地图未载入"}
	match id:
		"erase.save":
			return {"after": after, "loaded": _erased(map), "map": float(map.map_id)}
		"erase.sameMap":
			await map.transfer(8, 28, 26, 2)
			map = await _wait_map(8)
			return {"after": _erased(map)}
		"erase.otherMap":
			await map.transfer(4, 14, 23, 2)
			map = await _wait_map(4)
			await map.transfer(8, 29, 26, 2)
			map = await _wait_map(8)
			return {"back": _erased(map)}
	return {}


const EV_FIELDS := ["x", "y", "d", "page", "forcing", "routeIndex", "route"]

static func _ev_state(map: XMapScene, id: int) -> Dictionary:
	for e in map.events:
		if e.event_id == id:
			return {"x": float(e.grid.x), "y": float(e.grid.y), "d": float(e.direction), "page": float(e.page_index),
				"forcing": e._route_forcing, "routeIndex": float(e._route_index), "route": float((e._route if e._route_forcing else e.page.get("moveRoute", {})).get("list", []).size())}
	return {}

static func _event_node(map: XMapScene, id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null

static func _pick(d: Dictionary) -> Dictionary:
	var out := {}
	for k in EV_FIELDS:
		out[k] = d.get(k)
	return out

static func _player_state(map: XMapScene, n: int) -> Dictionary:
	var fs := []
	for i in range(n):
		var f: MVFollower = map.followers[i]
		fs.append([float(f.grid.x), float(f.grid.y), float(f.direction)])
	return {"x": float(map.player.grid.x), "y": float(map.player.grid.y), "d": float(map.player.direction), "followers": fs}

func _transfer_case(id: String, want: Dictionary) -> Dictionary:
	s = XState.new_game(3, 1, [8, 9, 10])
	var map := await _open(8, 29, 26)
	if map == null:
		return {"error": "Map008 未载入"}
	var route := {"list": [_cmd(12, []), _cmd(12, []), _cmd(12, []), _cmd(0, [])], "repeat": false, "skippable": true, "wait": false}
	var marks := {}
	for eid in [3, 6]:
		var e := _event_node(map, eid)
		e.process_mode = Node.PROCESS_MODE_DISABLED
		e.locate(e.grid.x + 1, e.grid.y)
		e.set_direction(8)
		e.force_move_route(route.duplicate(true))
		e._route_index = 2
		marks[eid] = e
	var nf: int = want.player.followers.size()
	if id == "transfer.sameMap.events":
		var before := {"3": _pick(_ev_state(map, 3)), "6": _pick(_ev_state(map, 6))}
		await _run_list(map, [_cmd(201, [0, 8, 28, 26, 4, 0]), _cmd(0, [])], 7)
		map = await _wait_map(8)
		return {"map": float(map.map_id), "before": before, "after": {"3": _pick(_ev_state(map, 3)), "6": _pick(_ev_state(map, 6))},
			"sameObjects": [_event_node(map, 3) == marks[3], _event_node(map, 6) == marks[6]], "player": _player_state(map, nf)}
	await map.transfer(4, 14, 23, 2)
	map = await _wait_map(4)
	await map.transfer(8, 29, 26, 2)
	map = await _wait_map(8)
	return {"map": float(map.map_id), "back": {"3": _pick(_ev_state(map, 3)), "6": _pick(_ev_state(map, 6))},
		"sameObjects": [_event_node(map, 3) == marks.get(3), _event_node(map, 6) == marks.get(6)], "player": _player_state(map, nf)}

static func _want_transfer(want: Dictionary) -> Dictionary:
	var out := want.duplicate(true)
	out.erase("sameMapInterpreter")
	for part in ["before", "after", "back"]:
		if out.has(part):
			for k in out[part]:
				out[part][k] = _pick(out[part][k])
	return out


## 只推进核心：记下待显示文字是在 122（设变量 1）之前还是之后显示的
func _flush_case(wait: bool) -> Dictionary:
	s = XState.new_game(3, 1, [8, 9, 10])
	var host := StubHost.new()
	var it := MVInterpreter.new(host, 4, 0, [_cmd(316, [0, 1, 0, 0, 1, true]), _cmd(225, [5, 5, 10, wait]), _cmd(122, [1, 1, 0, 0, 1]), _cmd(0, [])])
	var lines := []
	var shown_before_var = null
	for i in range(20):
		var r := it.advance()
		if r.kind == "done":
			break
		if r.kind == "message":
			lines.append_array(r.msg.lines)
			if shown_before_var == null:
				shown_before_var = int(s.variable(1)) == 0
		it.waiting_frame().resume(true)
	host.free()
	return {"lines": lines, "shownBeforeVar": shown_before_var, "var": int(s.variable(1)), "level": s.actor(1).level}


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_interp_review"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	var cases: Array = (data.cases if data is Dictionary else []).filter(func(c): return str(c.id).begins_with("erase.") or str(c.id).begins_with("flush.225.") or str(c.id).begins_with("transfer."))
	if _check("oracle_cases", cases.size() == 8, cases.map(func(c): return c.id)):
		for c in cases:
			if not c.errors.is_empty():
				_check("oracle_" + c.id, false, c.errors)
				continue
			var want: Dictionary = c.observed
			if str(c.id).begins_with("transfer."):
				var got := await _transfer_case(c.id, want)
				var exp := _want_transfer(want)
				_check(c.id, JSON.stringify(got) == JSON.stringify(exp), [got, exp])
			elif str(c.id).begins_with("erase."):
				var got := await _erase_case(c.id)
				_check(c.id, JSON.stringify(got) == JSON.stringify(want), [got, want])
			else:
				var got := _flush_case(c.id == "flush.225.wait")
				_check(c.id + ".lines", got.lines == want.lines, [got, want])
				_check(c.id + ".order", got.shownBeforeVar == (int(want.varSet.frame) > 1) and got.var == 1, [got, want])
				_check(c.id + ".level", got.level == int(want.level), [got, want])
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_interp_review", "passed": results.size() - failed.size(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
