extends Node
## 75 簇期一：天之上 → 食人魔防线 75 → 厄运要塞 76 南半 → 厄运城堡 78 大厅（地图场景里真走一遍）：
## - 进：Map069 (65,56) 上飞艇，飞到 EV18 所在小岛（块 56）降落，走到 EV18 (22,52) 下方面朝上按确认 → 75 (17,49)；
## - 75：遇敌表 272～275 都抽得到、真遇敌打完一场；从落点按图块 BFS 六个出口都走得到（xiyou_reach_check）；
##   走到北口踩上 EV5（面朝上）→ 76 (17,47)；
## - 76 南半：遇敌表 276～279；EV1～3、EV7 门、EV14 原作者 NPC 走得到，EV14 对话；撞门 EV7 → 78 (21,34)；
## - 78 大厅：遇敌表 276～280；EV1～6 走得到；EV3／EV4 进 76 两个小凹位 (8,20)／(26,20) 再由 76 EV8／EV9 回 (4,35)／(38,35)；
##   EV6 被困的灵魂认证「食人魔之王」：背包有武器 1347、防具 1762、1763 才发成就 126（缺一件、武器穿在身上都不算，原版 hasItem 不含装备）；
##   称号 ConfigManager.DesignationN[9] 重制没有称号系统，照先例跳过；
##   两扇副本门（EV2 厄运王座 17、EV5 厄运监狱 16）本期不进副本：缺符文提示、「离开」、「重置副本」三支；
##   B1（O-120，MVInterpreter.seal_check_fix）：有副本没重置（变量 5＝1）时点「挑战副本」只提示「请重置副本！」，不扣符文不进门；
##   seal_check_fix 设 {} 时条件照原版按变量 5＝副本号比（只核条件，不传进副本图）；
## - 回：78 EV1 → 76 (17,26)，76 EV2 面朝下 → 75 (17,0)，75 EV2 面朝下 → 69 (22,53)，走回飞艇再上；
## - 敌群 272～280 各打赢一场；共用核心条件类型 9／10（持有武器／防具，含装备一支）单独核。
## 队伍生命攻击都很大（只查流程）。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const FIXTURE := "res://tests/fixtures/airship_land.json"
const REACH := preload("res://tests/xiyou_reach_check.gd")
const WAIT := 6000
const TIMEOUT_MS := 240000
const DIRS := {2: Vector2i(0, 1), 4: Vector2i(-1, 0), 6: Vector2i(1, 0), 8: Vector2i(0, -1)}
const RUNE := 397

var results: Array = []
var battles: Array = []
var walk_battles: Array = []   # 走路途中真遇敌打的
var s: XState
var fx: Dictionary
var map: XMapScene


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


## 同 xiyou_airship_fly._fast_clock
func _fast_clock(on: bool) -> void:
	if not has_meta("clock"):
		set_meta("clock", [OS.low_processor_usage_mode_sleep_usec, Engine.physics_ticks_per_second, Engine.max_physics_steps_per_frame])
	var orig: Array = get_meta("clock")
	OS.low_processor_usage_mode_sleep_usec = 0 if on else orig[0]
	Engine.physics_ticks_per_second = 600 if on else orig[1]
	Engine.max_physics_steps_per_frame = 64 if on else orig[2]
	Engine.time_scale = 30.0 if on else 1.0


func _until(cond: Callable, limit := WAIT) -> bool:
	for i in limit:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func _wait_map(id: int) -> XMapScene:
	var ok := await _until(func():
		var m = get_tree().current_scene
		return m is XMapScene and m.map_id == id and m.player != null and is_instance_valid(m.player) and not m.busy)
	map = get_tree().current_scene if ok else null
	if map != null and not map.has_meta("watched"):
		map.set_meta("watched", true)
		map.ui.child_entered_tree.connect(_on_ui_child)
	return map


func _on_ui_child(n: Node) -> void:
	if n is XBattleScene:
		n.finished.connect(func(r): battles.append({"troop": n.logic.troop_id, "result": r}), CONNECT_ONE_SHOT)


func _event(id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null


func _airship() -> Dictionary:
	return s.vehicle("airship")


## 队伍参数：生命极大、攻击魔攻 5e13（一回合打完），同 xiyou_floor_reach106
func _party() -> void:
	for a in s.members():
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
					s.register_gear(inst)
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


# ---- 走路（同 xiyou_airship_fly）----

func _step_to(c: Vector2i) -> bool:
	map.player.touch_target = c
	return await _until(func(): return map.busy or (map.player.grid == c and not map.player.is_moving()), 600)


func _press() -> void:
	await _until(func(): return not map.busy)
	await map._on_action()


## 走路 BFS（图块双向通行；不踩别的事件格）
func _path(from: Vector2i, goal: Vector2i) -> Array:
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


## 走路途中真遇敌：打完（击倒全部敌人）接着走，记在 walk_battles
func _walk(goal: Vector2i) -> bool:
	if map.player.grid == goal:
		return true
	var path := _path(map.player.grid, goal)
	if path.is_empty():
		return false
	var id := map.map_id
	for c in path:
		for attempt in 3:
			await _step_to(c)
			var fighting := map.busy and map.map_id == id and await _in_battle()
			if fighting:
				var n0 := battles.size()
				await _win(func(): await _until(func(): return not map.busy, 60000))
				walk_battles.append_array(battles.slice(n0))
				continue
			break
		if map.busy or map.player.grid != c:
			return false
	return map.player.grid == goal


func _in_battle() -> bool:
	for i in 60:
		if map.ui.get_children().any(func(n): return n is XBattleScene):
			return true
		await get_tree().process_frame
	return false


## 走到 from 再一步踩上 cell（接触触发的出口：踩上去时的朝向就是走的方向）；等到换图
func _step_onto(from: Vector2i, cell: Vector2i, dest: int) -> bool:
	if not await _walk(from):
		return false
	await _step_to(cell)
	return await _wait_map(dest) != null


## 走到同层事件旁、面向它按确认；answers 按顺序答选项
func _talk(ev_id: int, answers: Array) -> bool:
	var e := _event(ev_id)
	if e == null:
		return false
	for d in [2, 8, 4, 6]:
		var side: Vector2i = e.grid + DIRS[d]
		if map.player.grid != side and _path(map.player.grid, side).is_empty():
			continue
		if not await _walk(side):
			continue
		map.player.set_direction(10 - d)
		XMessageBox.auto_answers = answers.duplicate()
		XMessageBox.transcript.clear()
		await _press()
		await _until(func(): return not map.busy)
		return true
	return false


func _said(text: String) -> bool:
	return XMessageBox.transcript.any(func(t): return str(t).contains(text))


func _get_on(tag: String) -> bool:
	await _press()
	return _check(tag + "_flying", await _until(func(): return map.vehicle_can_move()) and s.vehicle_type == "airship" and int(_airship().altitude) == 48, _airship())


func _land(tag: String) -> bool:
	await _press()
	return _check(tag + "_walk", await _until(func(): return s.vehicle_type == "walk" and map.vehicle_can_move()) and int(_airship().altitude) == 0, _airship())


# ---- 遇敌 ----

func _table(tag: String, troops: Array) -> void:
	_check(tag + "_table", map.map_data.encounterList.map(func(r): return int(r.troopId)) == troops, map.map_data.encounterList)
	var total := 0
	for r in map.map_data.encounterList:
		total += int(r.weight)
	var seen := {}
	for r in range(total):
		seen[XMapScene.encounter_troop(map.map_data.encounterList, r)] = true
	_check(tag + "_rolls", seen.size() == troops.size() and troops.all(func(t): return seen.has(t)), seen.keys())


## 跑一段（遇敌、开战）到结束；战斗一开始击倒全部敌人
func _win(call: Callable) -> bool:
	var st := {"done": false}
	(func():
		await call.call()
		st.done = true).call()
	var t0 := Time.get_ticks_msec()
	while not st.done and Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		for n in map.ui.get_children():
			if n is XBattleScene and not n.logic.enemies.is_empty():
				for en in n.logic.enemies:
					if en.is_alive():
						en.hp = 0.0
						en.add_state(1)
		await get_tree().process_frame
	return st.done


func _fight(tag: String, troops: Array) -> void:
	var n0 := battles.size()
	var ok := await _win(func(): await map._encounter())
	_check(tag + "_encounter", ok and battles.size() == n0 + 1 and troops.has(int(battles[-1].troop)) and battles[-1].result == 0, battles.slice(n0))


# ---- 各段 ----

## 69 上飞艇 → 块 56 降落 → 走到 EV18 下方面朝上按确认 → 75 (17,49)
func _fly_in() -> bool:
	_airship().mapId = 69
	_airship().x = 65
	_airship().y = 56
	s.map_id = 69
	s.x = 65
	s.y = 56
	get_tree().change_scene_to_file(MAP_SCENE)
	if not _check("sky", await _wait_map(69) != null) or not await _get_on("board"):
		return false
	var ev18 := _event(18)
	if not _check("ev18_present", ev18 != null and ev18.grid == Vector2i(22, 52)):
		return false
	# 块 56 里离 EV18 最近、不和它相邻的可降落格
	var best := Vector2i(-1, -1)
	var bd := 1 << 30
	for k in fx["69"].block:
		if int(fx["69"].block[k]) != 56:
			continue
		var p: PackedStringArray = k.split(",")
		var c := Vector2i(int(p[0]), int(p[1]))
		var d := absi(c.x - 22) + absi(c.y - 52)
		if d >= 2 and (d < bd or (d == bd and (c.y < best.y or (c.y == best.y and c.x < best.x)))):
			bd = d
			best = c
	if not _check("block56_landing", best.x >= 0, best):
		return false
	map.player.touch_target = best
	await _until(func(): return map.player.grid == best and not map.player.is_moving())
	if not await _land("block56"):
		return false
	if not _check("walk_below_ev18", await _walk(Vector2i(22, 53)), map.player.grid):
		return false
	map.player.set_direction(8)
	await _press()
	return _check("enter_75", await _wait_map(75) != null and map.player.grid == Vector2i(17, 49), [map.map_id if map else -1, map.player.grid if map else null])


func _map75() -> bool:
	_check("75_events", range(1, 7).all(func(i): return _event(i) != null))
	_check("75_reach", REACH.unreachable(map, map.player.grid, [1, 2, 3, 4, 5, 6]).is_empty(), REACH.unreachable(map, map.player.grid, [1, 2, 3, 4, 5, 6]))
	_table("75", [272, 273, 274, 275])
	await _fight("75", [272, 273, 274, 275])
	return _check("75_to_76", await _step_onto(Vector2i(17, 1), Vector2i(17, 0), 76) and map.player.grid == Vector2i(17, 47), [map.map_id if map else -1, map.player.grid if map else null])


func _map76() -> bool:
	_check("76_events", [1, 2, 3, 7, 8, 9, 10, 11, 12, 13, 14].all(func(i): return _event(i) != null))
	_check("76_reach_south", REACH.unreachable(map, map.player.grid, [1, 2, 3, 7, 14]).is_empty(), REACH.unreachable(map, map.player.grid, [1, 2, 3, 7, 14]))
	# 北半（指挥官 EV10、去 80 的 EV11～13）是王座副本里的路，从南半走不到（期二）
	_check("76_north_apart", REACH.unreachable(map, map.player.grid, [10, 11, 12, 13]).size() == 4)
	_table("76", [276, 277, 278, 279])
	await _fight("76", [276, 277, 278, 279])
	_check("76_npc14", await _talk(14, []) and _said("bug过多"), XMessageBox.transcript)
	# 撞门（EV7 同层、接触触发）：门打开的移动路线跑完再传送
	return _check("76_door_to_78", await _step_onto(Vector2i(17, 26), Vector2i(17, 25), 78) and map.player.grid == Vector2i(21, 34), [map.map_id if map else -1, map.player.grid if map else null])


func _map78() -> void:
	_check("78_events", range(1, 7).all(func(i): return _event(i) != null))
	_check("78_reach", REACH.unreachable(map, map.player.grid, [1, 2, 3, 4, 5, 6]).is_empty(), REACH.unreachable(map, map.player.grid, [1, 2, 3, 4, 5, 6]))
	_table("78", [276, 277, 278, 279, 280])
	await _fight("78", [276, 277, 278, 279, 280])
	# 两个小凹位（从下方一格往上踩）：78 EV3 → 76 (8,20)，76 EV8 (8,21) → 78 (4,35)；EV4 → 76 (26,20)，EV9 (26,21) → 78 (38,35)
	for row in [[3, Vector2i(4, 34), Vector2i(8, 20), Vector2i(8, 21), Vector2i(4, 35)], [4, Vector2i(38, 34), Vector2i(26, 20), Vector2i(26, 21), Vector2i(38, 35)]]:
		var tag := "alcove_ev%d" % row[0]
		var cell: Vector2i = row[1]
		if not _check(tag + "_in", await _step_onto(cell + Vector2i(0, 1), cell, 76) and map.player.grid == row[2], [map.map_id if map else -1, map.player.grid if map else null]):
			return
		# 小凹位只有几格，只能原路回去
		_check(tag + "_dead_end", REACH.reachable(map, map.player.grid).size() <= 8, REACH.reachable(map, map.player.grid).size())
		if not _check(tag + "_back", await _step_onto(row[2], row[3], 78) and map.player.grid == row[4], [map.map_id if map else -1, map.player.grid if map else null]):
			return
	# 认证与门口：本图遇敌表清空（走过去的路上遇敌会必掉符文，测试固定 XEnemy.force_roll），只影响这个场景实例
	map.map_data.encounterList = []
	await _soul()
	await _doors()


## EV6 被困的灵魂：认证「食人魔之王」
func _soul() -> void:
	await _talk(6, [0])
	_check("soul_none", _said("认证需要") and not _said("认证成功") and not s.achievements.has("126"), XMessageBox.transcript)
	s.gain_gear("weapon", 1347, 1)
	s.gain_gear("armor", 1762, 1)
	await _talk(6, [0])
	_check("soul_missing_1763", not _said("认证成功") and not s.achievements.has("126"), XMessageBox.transcript)
	s.gain_gear("armor", 1763, 1)
	# 武器穿在身上不算（条件不含装备）
	var a: XActor = s.members()[0]
	var old: Dictionary = a.equips[0]
	var w: Dictionary = s.gear.filter(func(e): return e.kind == "weapon" and int(e.base) == 1347)[0]
	s.gear.erase(w)
	a.equips[0] = w
	await _talk(6, [0])
	_check("soul_equipped_not_counted", not _said("认证成功") and not s.achievements.has("126"), XMessageBox.transcript)
	a.equips[0] = old
	s.gear.append(w)
	a.refresh_passive()
	await _talk(6, [0])
	_check("soul_done", _said("认证成功") and s.achievements.has("126"), XMessageBox.transcript)
	# 认证不扣物品
	_check("soul_keeps_items", s.gear_count("weapon", 1347) == 1 and s.gear_count("armor", 1762) == 1 and s.gear_count("armor", 1763) == 1)
	await _talk(6, [1])
	_check("soul_leave", _said("选择：离开"), XMessageBox.transcript)


func _vars() -> Array:
	return [int(s.variable(5)), int(s.variable(6)), int(s.variable(21)), s.item_count(RUNE)]


## 两扇副本门：本期不进副本
func _doors() -> void:
	for row in [[2, 17, [127, 128, 129, 130, 131]], [5, 16, [111, 112, 113, 114, 115, 116, 117, 118]]]:
		var ev: int = row[0]
		var id: int = row[1]
		var tag := "door%d" % ev
		# 缺符文（遇敌必掉的符文先清掉：测试固定 XEnemy.force_roll）
		s.gain_item(RUNE, -s.item_count(RUNE))
		s.set_variable(5, 0)
		s.set_variable(6, 0)
		s.set_variable(21, 0)
		await _talk(ev, [0])
		_check(tag + "_no_rune", _said("缺少") and _vars() == [0, 0, 0, 0] and map.map_id == 78, [_vars(), XMessageBox.transcript])
		# 离开
		await _talk(ev, [2])
		_check(tag + "_leave", _said("选择：离开") and _vars() == [0, 0, 0, 0] and map.map_id == 78, [_vars(), XMessageBox.transcript])
		# 没有要重置的
		await _talk(ev, [1])
		_check(tag + "_nothing_to_reset", _said("当前副本不需要重置") and _vars() == [0, 0, 0, 0], [_vars(), XMessageBox.transcript])
		# B1：本副本没重置（变量 5＝1、变量 6＝本副本），带着符文点挑战 → 请重置副本，不扣符文、不进门
		s.gain_item(RUNE, 1)
		s.set_variable(5, 1)
		s.set_variable(6, id)
		s.set_variable(21, 1)
		await _talk(ev, [0])
		_check(tag + "_b1_same", _said("请重置副本") and _vars() == [1, id, 1, 1] and map.map_id == 78, [_vars(), XMessageBox.transcript, map.map_id])
		# B1：别的副本（贪婪宫殿 20）没重置也拦
		s.set_variable(6, 20)
		await _talk(ev, [0])
		_check(tag + "_b1_other", _said("请重置副本") and _vars() == [1, 20, 1, 1] and map.map_id == 78, [_vars(), XMessageBox.transcript, map.map_id])
		# 别的副本没重置时本门重置不了（照原版：去那扇门重置）
		await _talk(ev, [1])
		_check(tag + "_other_not_reset_here", _said("当前副本不需要重置") and _vars() == [1, 20, 1, 1], [_vars(), XMessageBox.transcript])
		# 重置本副本：变量 5、6 归零，变量 21 减一，副本开关全关
		s.set_variable(6, id)
		for sw in row[2]:
			s.set_switch(sw, true)
		await _talk(ev, [1])
		_check(tag + "_reset", _said("重置完毕") and _vars() == [0, 0, 0, 1] and row[2].all(func(sw): return not s.switch(sw)), [_vars(), XMessageBox.transcript])
		s.gain_item(RUNE, -1)
		# 回退：seal_check_fix 设 {} 时条件照原版（变量 5＝副本号才拦）；只核条件，不传进副本图
		s.set_variable(5, 1)
		var it := MVInterpreter.new(map, 78, ev, [])
		var fixed: bool = it._condition([1, 5, 0, id, 0])
		var saved := MVInterpreter.seal_check_fix
		MVInterpreter.seal_check_fix = {}
		var orig: bool = it._condition([1, 5, 0, id, 0])
		s.set_variable(5, id)
		var orig_id: bool = it._condition([1, 5, 0, id, 0])
		MVInterpreter.seal_check_fix = saved
		var other := MVInterpreter.new(map, 76, ev, [])
		_check(tag + "_fix_switch", fixed and not orig and orig_id and not it._condition([1, 5, 0, id, 0]) and other._condition([1, 5, 0, id, 0]), [fixed, orig, orig_id])
		s.set_variable(5, 0)


## 回程：78 EV1 → 76 (17,26)；76 EV2 面朝下 → 75 (17,0)；75 EV2 面朝下 → 69 (22,53)；走回飞艇再上
func _walk_home() -> void:
	if not _check("home_78_to_76", await _step_onto(Vector2i(21, 33), Vector2i(21, 34), 76) and map.player.grid == Vector2i(17, 26), [map.map_id if map else -1, map.player.grid if map else null]):
		return
	if not _check("home_76_to_75", await _step_onto(Vector2i(17, 46), Vector2i(17, 47), 75) and map.player.grid == Vector2i(17, 0), [map.map_id if map else -1, map.player.grid if map else null]):
		return
	if not _check("home_75_to_69", await _step_onto(Vector2i(17, 48), Vector2i(17, 49), 69) and map.player.grid == Vector2i(22, 53), [map.map_id if map else -1, map.player.grid if map else null]):
		return
	var at := Vector2i(int(_airship().x), int(_airship().y))
	if _check("walk_to_airship", int(_airship().mapId) == 69 and await _walk(at), [_airship(), map.player.grid]):
		await _get_on("reboard")


## 敌群 272～280 各打赢一场（直接开战）
func _troops() -> void:
	if map == null:
		return
	for t in range(272, 281):
		var n0 := battles.size()
		await _win(func(): await map.start_battle(t, false, false))
		_check("troop_%d" % t, battles.size() == n0 + 1 and int(battles[-1].troop) == t and battles[-1].result == 0, battles.slice(n0))


## 共用核心条件类型 9／10：背包按底材编号；含装备时队员身上的也算
func _gear_conditions() -> void:
	var a: XActor = s.members()[0]
	var w: Dictionary = a.equips[0]
	var base := int(w.base)
	var it := MVInterpreter.new(map, 0, 0, [])
	var bag := s.gear_count("weapon", base)
	_check("cond9_equipped", it._condition([9, base, true]) and (bag > 0) == it._condition([9, base, false]), [base, bag])
	_check("cond10_absent", not it._condition([10, 1764, true]) and not it._condition([10, 1764, false]))


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_floor_reach075"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XShop.auto_close = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261030)
	_fast_clock(true)
	fx = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	s = XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.set_variable(21, 0)
	_party()
	if await _fly_in() and await _map75() and await _map76():
		await _map78()
		await _walk_home()
	await _troops()
	await _gear_conditions()
	_finish()


func _finish() -> void:
	_fast_clock(false)
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	XMessageBox.auto_answers = []
	print("战斗：", JSON.stringify(battles), " 走路遇敌：", JSON.stringify(walk_battles))
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
