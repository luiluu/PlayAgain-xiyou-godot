extends Node
## 贪婪宫殿 109 与两处深渊副本（110 蚀之深渊、113 蚀之魔渊）（地图场景里真走一遍）：
## - 天之上 EV65「挑战副本」：缺终极副本挑战符文（物品 397）不进，三张齐了扣 3 张进 109 (12,28)，副本号变量 6＝20。
## - 109：EV1／16／17／18／19 首领 374／373／375／376／377 各打赢一场并开开关 181～185（EV19 另发成就 47）；
##   EV19 开关 185 后是「进入此门」：无深渊派对邀请函（物品 179）不进，有则扣一张、随机（变量 107）进 110 或 113 (19,23)；
##   「离开这是非之地」与 EV21「逃离」回天之上 (122,20) 并重置副本。
## - 110／113：EV5 解开封印后随机（变量 108）打 7 个首领之一并发成就 82，变量 217 掷出 1 时再发成就 139；EV6 商人按变量 109（1～47）卖对应一件；
##   EV7(110)／EV8(113) 按变量 215（1～11）卖物品或打首领 413～416；出口回天之上并重置副本。
## 事件随机数用 MVEventCore.fixed_random 固定，逐支核对（商品对照表来自冻结源事件命令）。队伍生命攻击都很大（只查流程）。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const TIMEOUT_MS := 240000   # 并行负载下单个事件可能跑到一两分钟，别用 90 秒的墙钟判失败

var results: Array = []
var battles: Array = []   # 每场：{troop, result}
var trainings := 0


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
		map.ui.child_entered_tree.connect(_on_ui_child)
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


func _start(map_id: int, x: int, y: int, dir := 8) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.map_id = map_id
	s.x = x
	s.y = y
	s.direction = dir
	_party()
	get_tree().change_scene_to_file(MAP_SCENE)
	return s



func _on_ui_child(n: Node) -> void:
	if n is XBattleScene:
		n.finished.connect(func(r): battles.append({"troop": n.logic.troop_id, "result": r}), CONNECT_ONE_SHOT)
	elif n is XTrainingScene:
		trainings += 1
		n.closed.emit.call_deferred()


func _run_call(map: XMapScene, call: Callable, mode := "win") -> bool:
	if not map.has_meta("watched"):
		map.set_meta("watched", true)
		map.ui.child_entered_tree.connect(_on_ui_child)
	var st := {"done": false}
	(func():
		await call.call()
		st.done = true).call()
	var t0 := Time.get_ticks_msec()
	while not st.done and Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		var b := _battle_of(map)
		if b != null and not b.logic.enemies.is_empty() and mode == "win":
			for en in b.logic.enemies:
				if en.is_alive():
					en.hp = 0.0
					en.add_state(1)
		await get_tree().process_frame
	return _check("call_finished", st.done)


const SHOP110_EV6 := {1: [1, 1410], 2: [1, 1411], 3: [1, 1412], 4: [1, 1413], 5: [1, 1415], 6: [2, 2659], 7: [2, 2660], 8: [2, 2661], 9: [2, 2662], 10: [2, 2663], 11: [2, 2664], 12: [2, 2665], 13: [2, 2667], 14: [1, 1416], 15: [2, 2666], 16: [0, 662], 17: [1, 1414], 18: [1, 1419], 19: [1, 1422], 20: [1, 1426], 21: [1, 1428], 22: [1, 1427], 23: [1, 1429], 24: [2, 2937], 25: [2, 2938], 26: [2, 2939], 27: [2, 2940], 28: [2, 2941], 29: [2, 2942], 30: [2, 2943], 31: [2, 2944], 32: [0, 663], 33: [0, 761], 34: [0, 762], 35: [0, 763], 36: [0, 764], 37: [0, 765], 38: [0, 766], 39: [0, 767], 40: [0, 768], 41: [0, 769], 42: [1, 1433], 43: [1, 1434], 44: [2, 2983], 45: [2, 2984], 46: [2, 2985], 47: [0, 771]}
const SHOP_EV7 := {1: [0, 744], 2: [0, 745], 3: [0, 746], 6: [0, 757], 7: [0, 758], 8: [0, 759], 11: [0, 731]}
const FIGHT_EV7 := {4: 413, 5: 414, 9: 415, 10: 416}


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_floor_reach109"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XShop.auto_close = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261027)
	await _palace()
	await _abyss(110, [379, 380, 381, 382, 401, 403, 417], 7, 8)
	await _abyss(113, [383, 384, 385, 386, 402, 404, 418], 8, 7)
	MVEventCore.fixed_random = -1.0
	_finish()


## 随机数固定到「rand(1..n) 恰为 k」
func _pick(k: int, n: int) -> void:
	MVEventCore.fixed_random = (k - 0.5) / float(n)


func _sw(s: XState, ids: Array, on: bool) -> void:
	for i in ids:
		s.set_switch(int(i), on)


func _palace() -> void:
	var s := _start(69, 122, 20, 8)
	if not _check("p_sky", await _wait_map(69)):
		return
	var map: XMapScene = _scene()
	# 缺符文不进
	s.items.erase(397)
	await _run_event(map, 65, [0], "")
	_check("p_no_rune", _scene().map_id == 69 and int(s.variable(6)) != 20, [_scene().map_id, s.variable(6)])
	# 三张符文：扣 3 张进 109 (12,28)
	s.gain_item(397, 3)
	await _run_event(map, 65, [0], "")
	if not _check("p_entered", await _wait_map(109) and _scene().player.grid == Vector2i(12, 28), [_scene().map_id, _scene().player.grid]):
		return
	_check("p_rune_used", s.item_count(397) == 0 and int(s.variable(6)) == 20 and int(s.variable(5)) == 1, [s.item_count(397), s.variable(6), s.variable(5)])
	map = _scene()
	_check("p_events", [1, 16, 17, 18, 19, 21].all(func(i): return _event(map, i) != null))
	_check("p_no_table", map.map_data.encounterList.is_empty())
	# 五个首领
	var bosses := [[1, 374, 181], [16, 373, 182], [17, 375, 183], [18, 376, 184], [19, 377, 185]]
	for b in bosses:
		var n0 := battles.size()
		await _run_event(map, int(b[0]), [], "win")
		_check("p_boss_%d" % b[1], battles.size() == n0 + 1 and int(battles[-1].troop) == int(b[1]) and battles[-1].result == 0 and s.switch(int(b[2])), battles.slice(n0))
	_check("p_ach47", s.achievements.has("47"), s.achievements.keys())
	# 进入此门：无邀请函不进
	s.items.erase(179)
	await _run_event(map, 19, [0], "")
	_check("p_door_no_ticket", _scene().map_id == 109, _scene().map_id)
	# 有邀请函：随机 1→110，2→113，各扣一张
	for k in [1, 2]:
		var tgt := 110 if k == 1 else 113
		s = _start(109, 12, 1, 2)
		_sw(s, [181, 182, 183, 184, 185], true)
		s.set_variable(6, 20)
		s.gain_item(179, 1)
		if not _check("p_door_start%d" % k, await _wait_map(109)):
			return
		_pick(k, 2)
		await _run_event(_scene(), 19, [0], "")
		_check("p_door_%d" % tgt, await _wait_map(tgt) and _scene().player.grid == Vector2i(19, 23) and s.item_count(179) == 0, [_scene().map_id, _scene().player.grid, s.item_count(179)])
		MVEventCore.fixed_random = -1.0
	# 离开这是非之地：回天之上 (122,20) 并重置副本
	s = _start(109, 12, 1, 2)
	_sw(s, [181, 182, 183, 184, 185], true)
	s.set_variable(6, 20)
	s.set_variable(5, 1)
	if not _check("p_leave_start", await _wait_map(109)):
		return
	await _run_event(_scene(), 19, [1], "")
	_check("p_leave", await _wait_map(69) and _scene().player.grid == Vector2i(122, 20) and int(s.variable(6)) == 0 and not s.switch(181) and not s.switch(185), [_scene().map_id, _scene().player.grid, s.variable(6)])
	# EV21 逃离
	s = _start(109, 12, 28, 8)
	s.set_variable(6, 20)
	s.set_variable(5, 1)
	if not _check("p_escape_start", await _wait_map(109)):
		return
	await _run_event(_scene(), 21, [0], "")
	_check("p_escape", await _wait_map(69) and _scene().player.grid == Vector2i(122, 20) and int(s.variable(6)) == 0, [_scene().map_id, _scene().player.grid, s.variable(6)])


## 深渊：seal＝EV5 封印、shop＝EV6 商人、box＝EV7／EV8 宝箱商人、exit＝出口
## 宝珠（物品 758、759、761～769）只卖宝珠的商店一打开就提示并关闭（Scene_Shop.start → popScene），不进商店界面
func _shop_ok(n: int, want: Array) -> bool:
	var id := int(want[1])
	if int(want[0]) == 0 and (id == 758 or id == 759 or (id >= 761 and id <= 769)):
		return XShop.auto_log.size() == n
	return XShop.auto_log.size() == n + 1 and XShop.auto_log[-1].goods.size() > 0 and int(XShop.auto_log[-1].goods[0][0]) == int(want[0]) and id == int(XShop.auto_log[-1].goods[0][1])


func _abyss(map_id: int, troops: Array, box_ev: int, exit_ev: int) -> void:
	var tag := "a%d" % map_id
	var s := _start(map_id, 19, 23, 8)
	_sw(s, [181, 182, 183, 184, 185], true)
	s.set_variable(6, 20)
	s.set_variable(5, 1)
	if not _check(tag + "_start", await _wait_map(map_id)):
		return
	var map: XMapScene = _scene()
	_check(tag + "_events", range(1, 9).all(func(i): return _event(map, i) != null))
	_check(tag + "_no_table", map.map_data.encounterList.is_empty())
	# 封印：解开封印（开关 75），再随机打 7 个首领之一
	await _run_event(map, 5, [0], "")
	_check(tag + "_unseal", s.switch(75))
	for k in range(1, 8):
		_sw(s, [76, 77, 78, 695, 696, 697], false)
		map.refresh_events()
		await _wait_map(map_id)
		_pick(k, 7)
		var n0 := battles.size()
		await _run_event(map, 5, [0], "win")
		_check("%s_seal_%d" % [tag, troops[k - 1]], battles.size() == n0 + 1 and int(battles[-1].troop) == int(troops[k - 1]) and battles[-1].result == 0 and s.achievements.has("82") and s.switch(76), battles.slice(n0))
		await _wait_map(map_id)
	# 掷出变量 217＝1（rand 1～3000 取最小）时再发成就 139
	MVEventCore.fixed_random = 0.0001
	_sw(s, [76, 77, 78, 695, 696, 697], false)
	map.refresh_events()
	await _wait_map(map_id)
	await _run_event(map, 5, [0], "win")
	_check(tag + "_ach139", s.achievements.has("139"), s.achievements.keys())
	MVEventCore.fixed_random = -1.0
	await _wait_map(map_id)
	# 商人 EV6：变量 109＝k 卖第 k 件
	for k in SHOP110_EV6:
		_sw(s, [76, 78], false)
		s.set_switch(77, true)
		s.set_variable(109, k)
		map.refresh_events()
		var n := XShop.auto_log.size()
		await _wait_map(map_id)
		await _run_event(map, 6, [0], "")
		var want: Array = SHOP110_EV6[k]
		if not _shop_ok(n, want):
			_check("%s_shop%d" % [tag, k], false, [want, XShop.auto_log.slice(n)])
	_check(tag + "_shop_all", true)
	# 宝箱商人：变量 215＝k，卖物品或打首领
	for k in range(1, 12):
		_sw(s, [695, 697], false)
		s.set_switch(696, true)
		s.set_variable(215, k)
		map.refresh_events()
		await _wait_map(map_id)
		var n := XShop.auto_log.size()
		var n0 := battles.size()
		await _run_event(map, box_ev, [0], "win")
		if SHOP_EV7.has(k):
			var want: Array = SHOP_EV7[k]
			_check("%s_box%d" % [tag, k], _shop_ok(n, want), XShop.auto_log.slice(n))
		else:
			_check("%s_box%d" % [tag, k], battles.size() == n0 + 1 and int(battles[-1].troop) == int(FIGHT_EV7[k]) and battles[-1].result == 0 and XShop.auto_log.size() == n and s.switch(697), battles.slice(n0))
	# 出口：回天之上 (122,20)，重置副本
	s.set_variable(6, 20)
	await _wait_map(map_id)
	await _run_event(map, exit_ev, [0], "")
	_check(tag + "_exit", await _wait_map(69) and _scene().player.grid == Vector2i(122, 20) and int(s.variable(6)) == 0 and not s.switch(75) and not s.switch(181), [_scene().map_id, _scene().player.grid, s.variable(6)])


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
