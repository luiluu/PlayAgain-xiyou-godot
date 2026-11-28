extends Node
## T621 专项（Kyo 11-28）：深渊／不朽商人
## 1. 不强制弹出（XAbyssMerchant.NO_FORCE_OPEN）：打完首领商人出现时只提示、不打开界面，商人事件第 2 页照旧成立，玩家对话（openCurrent）才打开；
##    开关关掉回到原版：出现就打开。
## 2. 卡墙里的站位（XAbyssMerchant.MOVE_STUCK）：174/184/211/216、177/210/223 挪到 (16,14)／(4,7)，新建事件与读旧档都挪；
##    用游戏自己的通行判断（穿墙开关关着）从首领格出发走：新位置四邻至少一格走得到，原位置走不到或只挨着一格；其余图不动；开关关掉回原位。
## 3. 五张路线图补商人（XAbyssMerchant.EXTRA_ROUTES）：53/107/110/113/175 首领页插了 complete、插在首领战后（53 在 CE1438 后）、只插一次；
##    执行时同一套领点与出现、107 不弹出、输了不领、175 当场打开；开关关掉不执行也不插。
var results := []
var opened := 0
var toasts: Array = []


class FakeHost:
	extends RefCounted
	var page: Node
	func toast(t: String) -> void:
		page.toasts.append(t)
	func refresh_events() -> void:
		pass
	func open_merchant29() -> void:
		page.opened += 1


class FakeInterp:
	extends RefCounted
	var host: FakeHost


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	print(("PASS " if ok else "FAIL ") + name + ("" if ok else " " + JSON.stringify(detail)))


func interp() -> FakeInterp:
	var h := FakeHost.new()
	h.page = self
	var i := FakeInterp.new()
	i.host = h
	return i


func fresh(map: int) -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	s.party.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	s.map_id = 4
	toasts = []
	opened = 0
	XAbyssMerchant.battle = {}
	XAbyssMerchant.active = false
	MVEventCore.fixed_random = 0.5
	XAlienBattle.on_map_setup(s, s.map_id, map)
	XYunshangOrders.on_map_setup(s, s.map_id, map)
	XAbyssMerchant.on_map_setup(s, s.map_id, map)
	s.map_id = map
	return s


## 首领打赢、出现率掷 0.1（出现）后 complete
func win_and_appear(s: XState) -> void:
	XAbyssMerchant.battle_started(s, int(XAbyssMerchant.route(int(s.map_id)).troops[0]))
	XAbyssMerchant.battle_ended(0)
	MVEventCore.fixed_random = 0.1
	await XAbyssMerchant.complete(s, interp())
	MVEventCore.fixed_random = 0.5


func merchant_event(map: int) -> Dictionary:
	for me in XDB.table("CodexMerchants").merchantEvents:
		if int(me.map) == map:
			for ev in XDB.map(map).events:
				if ev != null and int(ev.id) == int(me.event):
					return ev
	return {}


## 从首领格走（四向通行都看两头），返回走得到的格
func reachable(tm: MVTilemap, md: Dictionary, start: Vector2i, skip: Vector2i) -> Dictionary:
	var dirs := {2: Vector2i(0, 1), 4: Vector2i(-1, 0), 6: Vector2i(1, 0), 8: Vector2i(0, -1)}
	var rev := {2: 8, 4: 6, 6: 4, 8: 2}
	var seen := {start: true}
	var q := [start]
	while not q.is_empty():
		var p: Vector2i = q.pop_front()
		for d in dirs:
			var n: Vector2i = p + dirs[d]
			if seen.has(n) or n == skip:
				continue
			if tm.is_passable(p.x, p.y, d) and tm.is_passable(n.x, n.y, rev[d]):
				seen[n] = true
				q.append(n)
	return seen


func faces(seen: Dictionary, p: Vector2i) -> int:
	var n := 0
	for d in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
		if seen.has(p + d):
			n += 1
	return n


func _run() -> void:
	print("T621 XTestMode.enabled=", XTestMode.enabled())
	var path := "user://test_t621_merchant.json"
	XConfig.path_override = path   # 本机设置可能开着穿墙（cq），通行判断要用干净设置
	# ---- 1. 不强制弹出 ----
	var s := fresh(37)
	await win_and_appear(s)
	check("no_force.not_opened", opened == 0 and XAbyssMerchant.has_merchant(s) and MVEvent.merchant29_present(), [opened, toasts])
	check("no_force.toast", toasts.size() == 1 and str(toasts[0]).ends_with("深渊商人出现了，走过去和他对话就能交易。"), toasts)
	var ok: bool = await XAbyssMerchant.open_current(interp())   # 玩家走过去对话：商人第 2 页的 openCurrent
	check("no_force.talk_opens", ok and opened == 1, opened)
	s = fresh(152)
	await win_and_appear(s)
	check("no_force.unknown_not_opened", opened == 0 and XAbyssMerchant.has_merchant(s), [opened, toasts])
	s = fresh(37)
	XAbyssMerchant.battle_started(s, int(XAbyssMerchant.route(37).troops[0]))
	XAbyssMerchant.battle_ended(0)
	MVEventCore.fixed_random = 0.9   # 不出现：提示里没有商人那句
	await XAbyssMerchant.complete(s, interp())
	MVEventCore.fixed_random = 0.5
	check("no_force.not_appeared_text", toasts.size() == 1 and not str(toasts[0]).contains("商人") and opened == 0, toasts)
	XAbyssMerchant.NO_FORCE_OPEN = false
	s = fresh(37)
	await win_and_appear(s)
	check("switch_off.force_opens", opened == 1 and str(toasts[0]).ends_with("深渊商人出现了。"), [opened, toasts])
	XAbyssMerchant.NO_FORCE_OPEN = true

	# ---- 2. 站位 ----
	for map in XAbyssMerchant.STUCK_POS:
		var row: Array = XAbyssMerchant.STUCK_POS[map]
		if not FileAccess.file_exists("res://modes/xiyou/generated/maps/Map%03d.json" % map):
			print("SKIP pos.%d 不在切片（无入口，不入包）" % map)
			continue
		var md := XDB.map(map)
		var ev := merchant_event(map)
		check("pos.%d.data_matches" % map, Vector2i(int(ev.x), int(ev.y)) == row[0], [ev.x, ev.y])
		var tm := MVTilemap.new()
		add_child(tm)
		tm.setup(md, false)
		tm.open_cells = MVTilemap.opened_cells(map, md)
		var start := Vector2i(8, 21) if map == 175 else (Vector2i(19, 17) if int(md.width) == 39 else Vector2i(9, 10))
		var seen := reachable(tm, md, start, row[1])
		var old_seen := reachable(tm, md, start, row[0])
		check("pos.%d.new_reachable" % map, faces(seen, row[1]) >= 2 and not seen.has(row[0]), [faces(seen, row[1])])
		check("pos.%d.old_stuck" % map, faces(old_seen, row[0]) <= 1, faces(old_seen, row[0]))
		var occupied := false
		for e in md.events:
			if e != null and int(e.id) != int(ev.id) and Vector2i(int(e.x), int(e.y)) == row[1]:
				occupied = true
		check("pos.%d.free_cell" % map, not occupied)
		# 新建事件挪过去；读旧档（记着原位）也挪过去
		var e := MVEvent.new()
		e.tilemap = tm
		add_child(e)
		e.setup_event(map, ev)
		check("pos.%d.setup_moved" % map, e.grid == row[1], e.grid)
		e.restore_state({"page": e.page_index, "x": row[0].x, "y": row[0].y, "direction": 2})
		check("pos.%d.restore_moved" % map, e.grid == row[1], e.grid)
		e.queue_free()
		tm.queue_free()
	# 其余商人图不动
	var ev37 := merchant_event(37)
	check("pos.37.unchanged", XAbyssMerchant.fixed_pos(37, ev37) == Vector2i(-1, -1))
	check("pos.53.unchanged", XAbyssMerchant.fixed_pos(53, merchant_event(53)) == Vector2i(-1, -1))
	XAbyssMerchant.MOVE_STUCK = false
	check("switch_off.pos", XAbyssMerchant.fixed_pos(174, merchant_event(174)) == Vector2i(-1, -1))
	XAbyssMerchant.MOVE_STUCK = true
	# ---- 3. 五张路线图补商人（EXTRA_ROUTES） ----
	for map in XAbyssMerchant.EXTRA_PAGES:
		var md := XDB.map(map)
		var n := 0
		for pair in XAbyssMerchant.EXTRA_PAGES[map]:
			var list: Array = md.events[pair[0]].pages[pair[1]].list
			var hits := list.filter(func(c): return int(c.code) == 355 and str(c.parameters[0]).begins_with("CodexAbyssMerchant.completeExtra"))
			n += hits.size()
			# 插在首领战之后：前面有 301，且 53 在 CE1438 之后（同 37 的次序）
			var at := list.find(hits[0]) if not hits.is_empty() else -1
			var before := list.slice(0, maxi(at, 0))
			var placed := at > 0 and before.any(func(c): return int(c.code) == 301)
			if map == 53:
				placed = placed and int(list[at - 1].code) == 117 and int(list[at - 1].parameters[0]) == 1438
			check("extra.%d.ev%d.placed" % [map, pair[0]], placed, at)
		check("extra.%d.count" % map, n == (XAbyssMerchant.EXTRA_PAGES[map] as Array).size(), n)
		XDB.map(map)   # 再取一次不重复插
		var again := 0
		for pair in XAbyssMerchant.EXTRA_PAGES[map]:
			again += (md.events[pair[0]].pages[pair[1]].list as Array).filter(func(c): return int(c.code) == 355 and str(c.parameters[0]).begins_with("CodexAbyssMerchant.completeExtra")).size()
		check("extra.%d.once" % map, again == n, again)
	# 107 打赢首领后执行补的那句：领点、出现、不弹出；对话才开
	s = fresh(107)
	XAbyssMerchant.battle_started(s, 344)
	XAbyssMerchant.battle_ended(0)
	MVEventCore.fixed_random = 0.1
	await MVScript.run(XAbyssMerchant.EXTRA_JS, interp())
	MVEventCore.fixed_random = 0.5
	var r = XAbyssMerchant.run(s)
	check("extra.107.claim", r != null and bool(r.claimed) and bool(r.appeared) and opened == 0 and XAbyssMerchant.balance(s, str(r.identity.key)) > 0
		and str(r.identity.key) == "layer:天之上:abyss", [r, toasts])
	check("extra.107.walk_text", toasts.size() == 1 and str(toasts[0]).ends_with("走过去和他对话就能交易。"), toasts)
	# 53 输了不领
	s = fresh(53)
	XAbyssMerchant.battle_started(s, 213)
	XAbyssMerchant.battle_ended(2)
	await MVScript.run(XAbyssMerchant.EXTRA_JS, interp())
	check("extra.53.lose_no_claim", not bool(XAbyssMerchant.run(s).claimed))
	# 175：当场打开（人留不下）
	s = fresh(175)
	XAbyssMerchant.battle_started(s, 560)
	XAbyssMerchant.battle_ended(0)
	MVEventCore.fixed_random = 0.1
	await MVScript.run(XAbyssMerchant.EXTRA_JS_OPEN, interp())
	MVEventCore.fixed_random = 0.5
	check("extra.175.opens_now", opened == 1 and str(toasts[0]).ends_with("商人出现了。"), [opened, toasts])
	# 回退：EXTRA_ROUTES 关掉，补的那句不执行、新载入的地图数据也不插
	XAbyssMerchant.EXTRA_ROUTES = false
	s = fresh(110)
	XAbyssMerchant.battle_started(s, 379)
	XAbyssMerchant.battle_ended(0)
	await MVScript.run(XAbyssMerchant.EXTRA_JS, interp())
	check("switch_off.extra_no_claim", not bool(XAbyssMerchant.run(s).claimed) and toasts.is_empty())
	var raw: Dictionary = XDB.load_json("maps/Map113.json")
	XAbyssMerchant.patch_map(113, raw)
	check("switch_off.extra_no_patch", not JSON.stringify(raw).contains("completeExtra"))
	XAbyssMerchant.EXTRA_ROUTES = true

	XConfig.path_override = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
