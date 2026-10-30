extends RefCounted
## 楼层专项公共检查：从落点按图块通行（MVTilemap.is_passable，与 MV checkPassage 同规则，进出两格都要通）BFS，
## 看给定事件走不走得到。同层事件（is_normal_priority）挡路，只能站到它四邻按确认或撞上去；角色下方／上方的事件要能踩上去。
## 用法：const REACH := preload("res://tests/xiyou_reach_check.gd")；REACH.unreachable(map, map.player.grid, [1, 2, 3]) 返回走不到的事件号。
## 只管图块与事件阻挡，不看事件出现条件、不看飞艇；进地图后马上调用（事件还在初始位置）。

const DIRS := {2: Vector2i(0, 1), 4: Vector2i(-1, 0), 6: Vector2i(1, 0), 8: Vector2i(0, -1)}


## 从 from 走得到的格（含 from）
static func reachable(map: XMapScene, from: Vector2i) -> Dictionary:
	var blocked := {}
	for e in map.events:
		if not e.page.is_empty() and e.is_normal_priority() and not e.through:
			blocked[e.grid] = true
	var seen := {from: true}
	var q := [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in DIRS:
			var n: Vector2i = c + DIRS[d]
			if seen.has(n) or blocked.has(n) or not map.lower.is_valid(n):
				continue
			if map.lower.is_passable(c.x, c.y, d) and map.lower.is_passable(n.x, n.y, 10 - d):
				seen[n] = true
				q.append(n)
	return seen


## 走不到的事件号（事件不在图上也算走不到）
static func unreachable(map: XMapScene, from: Vector2i, ids: Array) -> Array:
	var cells := reachable(map, from)
	var out := []
	for id in ids:
		var e: MVEvent = null
		for x in map.events:
			if x.event_id == id:
				e = x
		if e == null:
			out.append(id)
		elif e.is_normal_priority() and not e.through:
			if not DIRS.values().any(func(o): return cells.has(e.grid + o)):
				out.append(id)
		elif not cells.has(e.grid):
			out.append(id)
	return out
