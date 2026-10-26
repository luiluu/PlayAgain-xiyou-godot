extends Node
## 二十八层（Map145 众分天）副本与死界萨麦尔格的整段流程（地图场景里真走一遍；数值与规则对照由 xiyou_dungeon 的 d28a／d28b 参照剧本、
## xiyou_event_compare 的 m145e5 承担，这里查流程是否跑得通）：
## - 副本入口 EV2（进 Map208 西天）／EV4（进 Map209 小西天）：不朽灵魂 640、难度档页（开关 1669），进副本后四间「肉鸽」房（11～14）的自动页自己开出房间页
##   （随机变量 529～532 选首领／物品／随机 buff），四间都打开（变量 527／528 到 4）才出最后首领（Map208 恶·如来 695、Map209 善·无天 706），
##   首领战胜后宝箱问「是否前往妄语深渊」（Map211 未开放）选否 → 传回二十八层 (9,37)／(14,37) 并重置；首领在四间没开完前没有可用的页。
## - 死界萨麦尔格（EV5，敌群 833，位置 (43,0)）：「挑战」胜 → 全员学 5560、独立开关 A 开，第 2 页不再有指令；败 → 肝帝积分（变量 206）减 500；
##   「离开」什么也不做。脚本里 `$.toaster` 的单引号没闭合，正式版经 YEP_CoreEngine 的 command355 try/catch 吞掉，不提示（本版同）。
## 队伍生命攻击都很大（只查流程）；战斗中直接击倒敌人（败阵分支则击倒队伍）。事件走地图场景的 run_event（同玩家调查事件的入口，快速通过不走路）。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const FLOOR_MAP := 145
const RUNE := 640
const ROOMS := [11, 12, 13, 14]
const BOSS_EVENT := 1
const SAMAEL := 5
## 入口事件、副本地图、首领敌群、房间计数变量、回到二十八层的位置、该副本的变量 6 值
const DUNGEONS := [
	{"door": 2, "map": 208, "boss": 695, "count": 527, "back": Vector2i(9, 37), "v6": 38},
	{"door": 4, "map": 209, "boss": 706, "count": 528, "back": Vector2i(14, 37), "v6": 39},
]
## 首领战的随机头目（CE1020／1021）与其余敌群
const ROOM_BOSSES := [696, 697, 698, 699, 700, 701, 702, 703, 704, 707, 708, 709, 710, 711, 712, 713, 714, 715]
const TIMEOUT_MS := 90000

var results: Array = []
var battles: Array = []   # 每场：{troop, result}


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	# 换场景（传送）时测试节点不能挂在当前场景下，挂到根节点
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _scene() -> Node:
	return get_tree().current_scene


func _wait_map(map_id: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
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
		a.refresh_passive()
		a.hp = a.mhp
		a.mp = a.mmp


func _battle_of(map: XMapScene) -> XBattleScene:
	for n in map.ui.get_children():
		if n is XBattleScene:
			return n
	return null


## 跑一个事件到结束；mode：""＝不干预，"win"＝战斗一开始击倒全部敌人，"lose"＝击倒全部队员
func _run_event(map: XMapScene, id: int, answers: Array, mode := "win") -> bool:
	var e := _event(map, id)
	if not _check("map%d_event%d_present" % [map.map_id, id], e != null):
		return false
	if not map.has_meta("watched"):
		map.set_meta("watched", true)
		map.ui.child_entered_tree.connect(func(n):
			if n is XBattleScene:
				n.finished.connect(func(r): battles.append({"troop": n.logic.troop_id, "result": r}), CONNECT_ONE_SHOT))
	XMessageBox.auto_answers = answers.duplicate()
	var st := {"done": false}
	(func():
		await map.run_event(e)
		st.done = true).call()
	var t0 := Time.get_ticks_msec()
	while not st.done and Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		var b := _battle_of(map)
		if b != null and not b.logic.enemies.is_empty():
			if mode == "win":
				for en in b.logic.enemies:
					if en.is_alive():
						en.hp = 0.0
						en.add_state(1)
			elif mode == "lose":
				for a in b.logic.actors:
					if a.is_alive():
						a.hp = 0.0
						a.add_state(1)
		await get_tree().process_frame
	return _check("map%d_event%d_finished" % [map.map_id, id], st.done)


func _start(map_id: int, x: int, y: int) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.gain_item(RUNE, 2)
	s.set_switch(1669, true)   # 副本初始化（CE822）开第一档页
	s.map_id = map_id
	s.x = x
	s.y = y
	s.direction = 8
	_party()
	get_tree().change_scene_to_file(MAP_SCENE)
	return s


func _run() -> void:
	GameApp.fast_forward()  # 真走地图打战斗、等的是物理帧与计时器：headless 快进 4 倍（见 07_开发环境/测试提速.md）
	XSave.dir_override = "user://test_xiyou_floor28_dungeon"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261019)
	for d in DUNGEONS:
		if not await _dungeon(d):
			_finish()
			return
	await _samael()
	_finish()


func _dungeon(d: Dictionary) -> bool:
	var tag := "d%d" % d.map
	var back: Vector2i = d.back
	var s := _start(FLOOR_MAP, back.x, back.y)
	if not _check(tag + "_floor28_loaded", await _wait_map(FLOOR_MAP)):
		return false
	var map: XMapScene = _scene()
	# 入口：「挑战副本」
	await _run_event(map, d.door, [0], "")
	if not _check(tag + "_entered", await _wait_map(d.map), [_scene().name, battles]):
		return false
	map = _scene()
	_check(tag + "_rune_consumed", s.item_count(RUNE) == 1, s.item_count(RUNE))
	_check(tag + "_entry_vars", int(s.variable(5)) == 1 and int(s.variable(6)) == d.v6 and int(s.variable(450)) == 1, [s.variable(5), s.variable(6), s.variable(450)])
	# 进地图后四间房的自动页立刻跑完：开房间页（1723～1725 之一）并关掉自己的开关
	await _frames(10)
	# 事件 11、12、13、14 的自动页开关（Map208：1721／1726／1736／1731；Map209：1741／1746／1751／1756）
	var starts := [1741, 1746, 1751, 1756] if d.map == 209 else [1721, 1726, 1736, 1731]
	for i in 4:
		var sw: int = starts[i]
		var kinds := [s.switch(sw + 2), s.switch(sw + 3), s.switch(sw + 4)]
		# Map209 事件 14 的自动页末尾关的是 1757（房间完成开关）而不是自己的 1756，原版笔误：1756 一直开着，
		# 但房间页（1758～1760）开了以后页序靠后的优先，自动页不再重复，不影响玩
		var quirk: bool = d.map == 209 and i == 3
		_check(tag + "_room%d_autorun" % ROOMS[i], (quirk or not s.switch(sw)) and kinds.count(true) == 1, [sw, s.switch(sw), kinds])
	# 首领在四间房没开完前没有可用的页
	var locked := _event(map, BOSS_EVENT)
	_check(tag + "_boss_locked", locked == null or locked.command_list().is_empty(), locked.command_list() if locked != null else null)
	# 四间房
	for i in 4:
		var before := battles.size()
		var counter_before := int(s.variable(d.count))
		if not await _run_event(map, ROOMS[i], [], "win"):
			return false
		_check(tag + "_room%d_counted" % ROOMS[i], int(s.variable(d.count)) == counter_before + 1, [counter_before, s.variable(d.count)])
		_check(tag + "_room%d_done" % ROOMS[i], s.switch(starts[i] + 1), starts[i] + 1)
		var fought := battles.slice(before)
		_check(tag + "_room%d_battle" % ROOMS[i], fought.all(func(b): return ROOM_BOSSES.has(int(b.troop)) and b.result == 0), fought)
		map = _scene()
	# 最后首领
	var before_b := battles.size()
	if not await _run_event(map, BOSS_EVENT, [], "win"):
		return false
	_check(tag + "_boss_battle_won", battles.size() == before_b + 1 and battles[-1].troop == d.boss and battles[-1].result == 0, battles.slice(before_b))
	map = _scene()
	# 宝箱：问是否前往妄语深渊，选否 → 传回二十八层、副本重置
	await _run_event(map, BOSS_EVENT, [1], "")
	_check(tag + "_returned", await _wait_map(FLOOR_MAP) and _scene().player.grid == back, [_scene().map_id, _scene().player.grid if _scene() is XMapScene else null])
	_check(tag + "_reset", int(s.variable(5)) == 0 and int(s.variable(6)) == 0 and int(s.variable(450)) == 0, [s.variable(5), s.variable(6), s.variable(450)])
	# 两张图的出口都调公共事件 1024（Map209 的宝箱／逃离也不是 1025，原版如此）：只重置 Map208 的房间开关与计数变量 527；
	# Map209 的 528 与房间开关留着，下次从入口 EV4 进去时 CE1025 才刷新
	if d.map == 208:
		_check(tag + "_reset_rooms", starts.all(func(sw): return s.switch(sw)) and int(s.variable(527)) == 0, [starts, s.variable(527)])
	else:
		_check(tag + "_reset_rooms_via_1024", [1721, 1726, 1736, 1731].all(func(sw): return s.switch(sw)) and int(s.variable(527)) == 0 and int(s.variable(528)) == 4, [s.variable(527), s.variable(528)])
	return true


func _samael() -> void:
	var s := _start(FLOOR_MAP, 43, 1)
	if not _check("samael_loaded", await _wait_map(FLOOR_MAP)):
		return
	var map: XMapScene = _scene()
	var tracked := [8, 9, 10]
	var n0 := battles.size()
	# 离开：什么也不变
	await _run_event(map, SAMAEL, [1], "")
	_check("samael_leave", not s.self_switch(FLOOR_MAP, SAMAEL, "A") and tracked.all(func(a): return not s.actor(a).skill_ids.has(5560)) and battles.size() == n0, battles)
	# 败：肝帝积分减 500（变量 206 可以减成负数），独立开关不动
	s.set_variable(206, 1000)
	await _run_event(map, SAMAEL, [0], "lose")
	map = _scene()
	_check("samael_lose_battle", battles.size() == n0 + 1 and battles[-1].troop == 833 and battles[-1].result == 2, battles)
	_check("samael_lose_penalty", int(s.variable(206)) == 500 and not s.self_switch(FLOOR_MAP, SAMAEL, "A"), s.variable(206))
	# 胜：全员学 5560、独立开关 A 开、没有提示（脚本里 toaster 引号没闭合）
	_party()
	map.toasts.clear()
	await _run_event(map, SAMAEL, [0], "win")
	map = _scene()
	_check("samael_win_battle", battles.size() == n0 + 2 and battles[-1].troop == 833 and battles[-1].result == 0, battles)
	_check("samael_win_skill", tracked.all(func(a): return s.actor(a).skill_ids.has(5560)) and s.actor(1).skill_ids.has(5560), s.actor(8).skill_ids)
	_check("samael_win_switch", s.self_switch(FLOOR_MAP, SAMAEL, "A") and int(s.variable(206)) == 500, [s.variable(206)])
	_check("samael_win_no_toast", not map.toasts.any(func(t): return str(t).contains("萨麦尔格")), map.toasts)
	# 第 2 页：不再有指令
	var e := _event(map, SAMAEL)
	_check("samael_page2_empty", e != null and e.command_list().all(func(c): return int(c.code) == 0), e.command_list() if e != null else null)


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
