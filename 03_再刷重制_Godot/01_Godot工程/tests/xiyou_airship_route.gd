extends RefCounted
## 楼层专项公共步骤：在天之上（69）／神魔战场（186）坐飞艇真走到某个事件再触发（从 xiyou_airship_fly 的上艇、飞行、降落、走路抽出来）。
## 用法：const ROUTE := preload("res://tests/xiyou_airship_route.gd")；
##   var r := ROUTE.new(self, map)；var ok: bool = await r.go(事件号, 应答)
## 开图前先 park(状态, 图号)；go：从现在的位置走到飞艇、按确认上艇、等升空，
## 飞到离事件最近（曼哈顿 ≥ 2）且下艇后走得到事件旁的可降落格（XMapScene.airship_land_ok），按确认降落，
## 再按图块通行 BFS 走过去：同层事件从下、上、左、右靠过去撞它，下方的踩上去。事件跑过（或换了图）返回 true。
## walk_to(事件号, 应答)：不坐飞艇，从现在的位置走过去踩／撞（入口跟落点在同一块时用）。
## 只在测试里用；走不到（没有能降落又走得到的格）返回 false，调用方照原版记缺口。

const DIRS := {2: Vector2i(0, 1), 4: Vector2i(-1, 0), 6: Vector2i(1, 0), 8: Vector2i(0, -1)}
## 飞艇停靠格（地图号 → 格）：天之上恰兰吉尔那块，同 xiyou_airship_fly
const PARK := {69: Vector2i(65, 56)}
const WAIT := 6000

var host: Node
var map: XMapScene
## 最后一次 go 降落的格（调用方核块号用）
var landed := Vector2i(-1, -1)


func _init(h: Node, m: XMapScene) -> void:
	host = h
	map = m


func _airship() -> Dictionary:
	return XState.current.vehicle("airship")


func _until(cond: Callable, limit := WAIT) -> bool:
	for i in limit:
		if cond.call():
			return true
		await host.get_tree().physics_frame
	return cond.call()


func _event(id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null


func _step_to(c: Vector2i) -> bool:
	map.player.touch_target = c
	return await _until(func(): return map.busy or (map.player.grid == c and not map.player.is_moving()), 600)


func _press() -> void:
	await _until(func(): return not map.busy)
	await map._on_action()


## 走路 BFS（图块双向通行、事件格不踩，goal 除外）
func path(from: Vector2i, goal: Vector2i) -> Array:
	var occupied := {}
	for e in map.events:
		if not e.page.is_empty():
			occupied[e.grid] = true
	var prev := {from: from}
	var q := [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == goal:
			var out := []
			while c != from:
				out.push_front(c)
				c = prev[c]
			return out
		for d in DIRS:
			var n: Vector2i = c + DIRS[d]
			if prev.has(n) or not map.lower.is_valid(n) or (occupied.has(n) and n != goal):
				continue
			if map.lower.is_passable(c.x, c.y, d) and map.lower.is_passable(n.x, n.y, 10 - d):
				prev[n] = c
				q.append(n)
	return []


func _walk(goal: Vector2i) -> bool:
	for c in path(map.player.grid, goal):
		if not await _step_to(c) or map.busy:
			return false
	return map.player.grid == goal


func _sides(e: MVEvent) -> Array:
	var g := e.grid
	return [g + DIRS[2], g + DIRS[8], g + DIRS[4], g + DIRS[6]] if e.is_normal_priority() else [g]


## 离事件最近、降落后走得到事件旁的可降落格；没有返回 (−1, −1)
func landing_for(e: MVEvent) -> Vector2i:
	var cand := []
	for y in map.lower.height:
		for x in map.lower.width:
			var c := Vector2i(x, y)
			var d := absi(c.x - e.grid.x) + absi(c.y - e.grid.y)
			if d >= 2 and map.airship_land_ok(c):
				cand.append([d, c.y, c.x])
	cand.sort()
	for k in mini(cand.size(), 60):
		var c := Vector2i(cand[k][2], cand[k][1])
		if _sides(e).any(func(side): return side == c or not path(c, side).is_empty()):
			return c
	return Vector2i(-1, -1)


## 开图之前调：飞艇不在这张图就停到 PARK 那格（地图载入时才摆飞艇）
static func park(s: XState, map_id: int) -> void:
	var a := s.vehicle("airship")
	if int(a.get("mapId", 0)) != map_id and PARK.has(map_id):
		a.mapId = map_id
		a.x = PARK[map_id].x
		a.y = PARK[map_id].y


func board() -> bool:
	var a := _airship()
	if int(a.get("mapId", 0)) != map.map_id:
		return false
	var at := Vector2i(int(a.x), int(a.y))
	if map.player.grid != at and not await _walk(at):
		return false
	await _press()
	return await _until(func(): return XState.current.vehicle_type == "airship" and map.vehicle_can_move())


func go(ev_id: int, answers := []) -> bool:
	var e := _event(ev_id)
	if e == null:
		return false
	var land := landing_for(e)
	if land.x < 0 or not await board():
		return false
	map.player.touch_target = land
	if not await _until(func(): return map.player.grid == land and not map.player.is_moving()):
		return false
	await _press()
	if not await _until(func(): return XState.current.vehicle_type == "walk" and map.vehicle_can_move()):
		return false
	landed = land
	return await walk_to(ev_id, answers)


## 不坐飞艇：从现在的位置按图块通行走过去踩／撞事件（同 go 降落之后那段）。事件跑过（或换了图）返回 true。
func walk_to(ev_id: int, answers := []) -> bool:
	var e := _event(ev_id)
	if e == null:
		return false
	var map_id := map.map_id
	var normal := e.is_normal_priority()
	for side in _sides(e):
		if map.player.grid != side and path(map.player.grid, side).is_empty():
			continue
		XMessageBox.auto_answers = answers.duplicate()
		var ran := [false]
		var cb := func(b: bool): ran[0] = ran[0] or b
		map.busy_changed.connect(cb)
		await _walk(side)
		if normal and not map.busy and map.map_id == map_id:
			await _step_to(e.grid)   # 撞上去：走不过去时面向目标、按调查
		await _until(func(): return not map.busy)
		if is_instance_valid(map) and map.busy_changed.is_connected(cb):
			map.busy_changed.disconnect(cb)
		if ran[0] or not is_instance_valid(map) or map.map_id != map_id:
			return true
	return false
