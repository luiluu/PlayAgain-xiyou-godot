extends Node
## 传送连通性端到端（悟空 floor6）：fixtures/transfer_landings.json 由 03_转换工具/地图盘点.py 生成，列出切片里放了的事件与
## 切片公共事件的全部传送落点（直接指定，或先常量赋值再按变量指定），以及每张图的出口事件（任一页有传送，含调用的公共事件）。
## 每张目标图在地图场景里开一次（新开局状态），对每个落点：断言在图内；从落点按图块通行 BFS（xiyou_reach_check，同层事件挡路），
## 至少走得到一个出口事件，或图上有自动／并行的出口，或这张图在 known_no_exit 里写明了离开办法（如热键 1 回大厅，副本中不可用）。
## 走不到的写进输出 STUCK 行；fixture 的 known 列出已查明原因的落点（原版就这样且有别的离开办法），其余的挂。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const FIX := "res://tests/fixtures/transfer_landings.json"
const KNOWN := "res://tests/fixtures/transfer_reach_known.json"
const PARTS := 2
const CASE_MS := 30000
const WaitBudget := preload("res://tests/wait_budget.gd")
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const REACH := preload("res://tests/xiyou_reach_check.gd")

@export var part := 1

var results: Array = []
var fails: Array = []


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set("part", part)
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


func _map(m: int, landings: Array, exits: Dictionary, known: Dictionary) -> void:
	var first: Array = landings[0].xy
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.map_id = m
	s.x = int(first[0])
	s.y = int(first[1])
	get_tree().change_scene_to_file(MAP_SCENE)
	var t0 := WaitBudget.new(CASE_MS)
	while t0.waiting() and not _map_ready(m):
		await get_tree().process_frame
	if not _check("m%d_loaded" % m, _map_ready(m), _scene().get("map_id")):
		return
	var map: XMapScene = _scene()
	var ex: Dictionary = exits.get(str(m), {"walk": [], "auto": []})
	for l in landings:
		var at := _fixed_landing(m, Vector2i(int(l.xy[0]), int(l.xy[1])), l.from)
		var tag := "m%d_%d_%d" % [m, at.x, at.y]
		var why = known.get("%d:%d:%d" % [m, at.x, at.y], known.get(str(m)))
		if not map.lower.is_valid(at):
			print("OUTSIDE ", JSON.stringify({"map": m, "xy": l.xy, "from": l.from}))
			_check(tag + "_in_map", why != null, {"size": [map.lower.width, map.lower.height], "from": l.from})
			continue
		var ok: bool = not ex.auto.is_empty()
		if not ok and not ex.walk.is_empty():
			ok = REACH.unreachable(map, at, ex.walk).size() < ex.walk.size()
			# 同层事件挡路（守关的精英、首领）：只看图块走得到出口的，打过它就让开，记 BLOCKED 不算卡死
			if not ok and _tiles_reach(map, at, ex.walk):
				ok = true
				print("BLOCKED ", JSON.stringify({"map": m, "xy": l.xy, "from": l.from, "exits": ex.walk}))
		if not ok:
			var spawned := map.events.filter(func(e): return ex.walk.has(e.event_id)).map(func(e): return [e.event_id, e.grid.x, e.grid.y, e.page_index])
			print("STUCK ", JSON.stringify({"map": m, "xy": l.xy, "from": l.from, "exits": ex.walk, "spawned": spawned,
				"cells": REACH.reachable(map, at).size(), "player": [map.player.grid.x, map.player.grid.y]}))
			_check(tag + "_exit", why != null, {"from": l.from, "exits": ex.walk})


## 只看图块（不算事件挡路）从 from 走不走得到任一出口事件（同层的站到四邻，其余踩上去）
func _tiles_reach(map: XMapScene, from: Vector2i, ids: Array) -> bool:
	var seen := {from: true}
	var q := [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in REACH.DIRS:
			var n: Vector2i = c + REACH.DIRS[d]
			if seen.has(n) or not map.lower.is_valid(n):
				continue
			if map.lower.is_passable(c.x, c.y, d) and map.lower.is_passable(n.x, n.y, 10 - d):
				seen[n] = true
				q.append(n)
	for e in map.events:
		if ids.has(e.event_id) and (seen.has(e.grid) or REACH.DIRS.values().any(func(o): return seen.has(e.grid + o))):
			return true
	return false


## 落点修正（MVInterpreter.TRANSFER_FIX，如三十三层 (24,12)→(24,13)）：来源写成「MapNNN EVn pK」
func _fixed_landing(m: int, at: Vector2i, from: Array) -> Vector2i:
	for f in from:
		var r := RegEx.create_from_string("^Map(\\d+) EV(\\d+)").search(str(f))
		if r == null:
			continue
		var key := "%d:%d:%d:%d:%d" % [int(r.get_string(1)), int(r.get_string(2)), m, at.x, at.y]
		if MVInterpreter.TRANSFER_FIX.has(key):
			return MVInterpreter.TRANSFER_FIX[key]
	return at


func _run() -> void:
	GameApp.fast_forward()
	TestEnv.isolate("xiyou_transfer_reach_%d" % part)
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX))
	var known: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KNOWN)).get("known", {}) if FileAccess.file_exists(KNOWN) else {}
	var by_map := {}
	for l in data.landings:
		if not by_map.has(int(l.map)):
			by_map[int(l.map)] = []
		by_map[int(l.map)].append(l)
	var ids := by_map.keys()
	ids.sort()
	var mine := 0
	for i in ids.size():
		if i % PARTS == part - 1:
			mine += 1
			await _map(int(ids[i]), by_map[ids[i]], data.exits, known)
	_check("part%d_has_maps" % part, mine > 0)
	print("失败：", JSON.stringify(fails))
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
