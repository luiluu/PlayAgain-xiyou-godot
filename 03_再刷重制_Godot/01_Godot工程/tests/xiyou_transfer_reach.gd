extends Node
## 传送连通性端到端（悟空 floor6）：fixtures/transfer_landings.json 由 03_转换工具/地图盘点.py 生成，列出切片里放了的事件与
## 切片公共事件的全部传送落点（直接指定，或先常量赋值再按变量指定），以及每张图的出口事件（任一页有传送，含调用的公共事件）。
## 每张目标图在地图场景里开一次（新开局状态），对每个落点：断言在图内；从落点按图块通行 BFS（xiyou_reach_check，同层事件挡路），
## 至少走得到一个出口事件，或图上有自动／并行的出口，或这张图在 known_no_exit 里写明了离开办法（如热键 1 回大厅，副本中不可用）。
## 走不到的写进输出 STUCK 行；floor7 起再按页查开关／变量换页的传送页（见 _pages）；fixture 的 known 列出已查明原因的落点（原版就这样且有别的离开办法），其余的挂。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const FIX := "res://tests/fixtures/transfer_landings.json"
const KNOWN := "res://tests/fixtures/transfer_reach_known.json"
const CASE_MS := 30000
const WaitBudget := preload("res://tests/wait_budget.gd")
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const REACH := preload("res://tests/xiyou_reach_check.gd")

## 不走的图：Map002 是开局剧情与选英雄（进图自动事件一路演到选人界面，玩家不自己走；开局流程另有 xiyou_opening_* 专项），
## 在这里开它，选人界面的资源到退出时还没放，Godot 报「resources still in use」
const SKIP_MAPS := {2: "开局剧情图"}

@export var part := 1
@export var parts := 4
## 只跑这些图（排查用；空＝按分片）
@export var only_maps: Array = []

var results: Array = []
var fails: Array = []


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set("part", part)
	runner.set("parts", parts)
	runner.set("only_maps", only_maps)
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
	while t0.waiting() and not (_map_ready(m) and not _scene().busy):
		await get_tree().process_frame
	# 进图自动事件（副本图的同图移动等）会重载场景：多等几帧，取稳定后的场景
	for i in 10:
		await get_tree().process_frame
	while t0.waiting() and not (_map_ready(m) and not _scene().busy):
		await get_tree().process_frame
	if not _check("m%d_loaded" % m, _map_ready(m), _scene().get("map_id")):
		return
	var map: XMapScene = _scene()
	var raw: Dictionary = exits.get(str(m), {"walk": [], "auto": []})
	# JSON 数字读进来是浮点：转成整数再和事件号比
	var ex := {"walk": Array(raw.walk).map(func(v): return int(v)), "auto": Array(raw.auto).map(func(v): return int(v))}
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
	_pages(map, m, Array(raw.get("pages", [])), landings, known)


## floor7：开关／变量换页的传送页（fixture exits.pages，参照逐页跑过的）。在已开好的图上逐页：按页条件设状态（开关开、变量取到值、
## 独立开关、物品、角色入队），更高的页被一起满足时关掉它多出来的条件，refresh_events 后断言该事件选中这一页；再从各落点 BFS
## 走得到它（自动／并行页不用走）。整段同步执行、不等帧，查完立刻还原状态再刷新，自动执行页来不及启动。
## 选不中（更高页条件是它的子集、页条件被 page_switch_ignore 拦下）记 SHADOWED，走不到记 STUCK；已知项键「p地图:事件:页」。
func _pages(map: XMapScene, m: int, pages: Array, landings: Array, known: Dictionary) -> void:
	var s := XState.current
	var at_list: Array = []
	for l in landings:
		var at := _fixed_landing(m, Vector2i(int(l.xy[0]), int(l.xy[1])), l.from)
		if map.lower.is_valid(at):
			at_list.append(at)
	for pg in pages:
		var ev := int(pg.event)
		var want := int(pg.page)
		var tag := "m%d_e%d_p%d" % [m, ev, want]
		var why = known.get("p%d:%d:%d" % [m, ev, want], known.get(str(m)))
		var e: MVEvent = null
		for x in map.events:
			if x.event_id == ev:
				e = x
		if not _check(tag + "_event", e != null or why != null):
			continue
		if e == null:
			continue
		var snap := [s.switches.duplicate(), s.variables.duplicate(), s.self_switches.duplicate(), s.items.duplicate(), s.party.duplicate()]
		var erased := e.erased
		e.erased = false
		_satisfy(s, m, ev, e.data.pages[want].conditions)
		map.refresh_events()
		var guard := 0
		while e.page_index > want and guard < e.data.pages.size():
			guard += 1
			if not _break(s, m, ev, e.data.pages[want].conditions, e.data.pages[e.page_index].conditions):
				break
			map.refresh_events()
		var got := e.page_index
		var ok := got == want
		var reach := ok
		if ok and int(pg.trigger) not in [3, 4]:
			reach = at_list.any(func(at): return REACH.unreachable(map, at, [ev]).is_empty())
			if not reach and at_list.any(func(at): return _tiles_reach(map, at, [ev])):
				reach = true
				print("BLOCKED ", JSON.stringify({"map": m, "event": ev, "page": want}))
		s.switches = snap[0]
		s.variables = snap[1]
		s.self_switches = snap[2]
		s.items = snap[3]
		s.party = snap[4]
		e.erased = erased
		map.refresh_events()
		if not ok:
			print("SHADOWED ", JSON.stringify({"map": m, "event": ev, "page": want, "got": got, "cond": pg.cond}))
			_check(tag + "_page", why != null, {"got": got})
		elif not reach:
			print("STUCK ", JSON.stringify({"map": m, "event": ev, "page": want, "grid": [e.grid.x, e.grid.y], "cond": pg.cond}))
			_check(tag + "_reach", why != null, pg.cond)


## 让一页的条件成立（直接改存档表，不走 set_switch 的跨存档钩子；调用方查完整份还原）
func _satisfy(s: XState, m: int, ev: int, c: Dictionary) -> void:
	if c.switch1Valid:
		s.switches[int(c.switch1Id)] = true
	if c.switch2Valid:
		s.switches[int(c.switch2Id)] = true
	if c.variableValid and s.variable(int(c.variableId)) < float(c.variableValue):
		s.variables[int(c.variableId)] = float(c.variableValue)
	if c.selfSwitchValid:
		s.self_switches["%d,%d,%s" % [m, ev, str(c.selfSwitchCh)]] = true
	if c.itemValid and s.item_count(int(c.itemId)) <= 0:
		s.items[int(c.itemId)] = 1
	if c.actorValid and not s.party.has(int(c.actorId)):
		s.actor(int(c.actorId))
		s.party.append(int(c.actorId))


## 更高的页 q 一起成立时，关掉 q 有、目标页 c 不要求的一个条件；没有可关的返回 false（目标页被 q 盖住）
func _break(s: XState, m: int, ev: int, c: Dictionary, q: Dictionary) -> bool:
	var need := []
	if c.switch1Valid:
		need.append(int(c.switch1Id))
	if c.switch2Valid:
		need.append(int(c.switch2Id))
	for k in ["switch1", "switch2"]:
		if q[k + "Valid"] and not need.has(int(q[k + "Id"])):
			s.switches[int(q[k + "Id"])] = false
			return true
	if q.variableValid:
		# 同一个变量：取目标页要的下限（q 要求更高时才分得开）；不同变量：压到 q 的门槛下一格
		var same: bool = c.variableValid and int(c.variableId) == int(q.variableId)
		if not same or float(q.variableValue) > float(c.variableValue):
			s.variables[int(q.variableId)] = float(c.variableValue) if same else float(q.variableValue) - 1.0
			return true
	if q.selfSwitchValid and not (c.selfSwitchValid and str(c.selfSwitchCh) == str(q.selfSwitchCh)):
		s.self_switches["%d,%d,%s" % [m, ev, str(q.selfSwitchCh)]] = false
		return true
	if q.itemValid and not (c.itemValid and int(c.itemId) == int(q.itemId)):
		s.items[int(q.itemId)] = 0
		return true
	if q.actorValid and not (c.actorValid and int(c.actorId) == int(q.actorId)) and s.party.size() > 1:
		s.party.erase(int(q.actorId))
		return true
	return false


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
	for k in SKIP_MAPS:
		ids.erase(k)
	for i in ids.size():
		if (only_maps.is_empty() and i % parts == part - 1) or only_maps.has(int(ids[i])):
			mine += 1
			await _map(int(ids[i]), by_map[ids[i]], data.exits, known)
	_check("part%d_has_maps" % part, mine > 0)
	# 收掉最后一张图（进图自动事件的解释器还挂着会在退出时报资源没释放）
	var t1 := WaitBudget.new(10000)
	while t1.waiting() and _scene() is XMapScene and _scene().busy:
		await get_tree().process_frame
	var last := _scene()
	if last != null:
		last.queue_free()
	for i in 60:
		await get_tree().process_frame
	print("失败：", JSON.stringify(fails))
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
