extends Node
## 神魔战场（Map186，100×100）期一：入口门（Map116 EV5，开关 940）、返回门 EV1、九个军团（EV2、24～31：按变量 665～673 档 7／8／9 连打精英小队与元帅，
## 胜后封刀奖励 CE999、自开关 A／B 重建城、C 科技与商店）、农田（EV3～15：占领连打五场、收取果实按 playtime、增减奴隶）、
## 矿（EV16～23）、超级 Boos EV32（敌群 739，playtime−变量 707≥180）、外界使者 EV33（送物品 1634）。
## 走地图场景真走一遍；数值（敌群事件）由 xiyou_troop_events 对照参照。
## 分段（照 xiyou_rules 拆场景，免得单场景超过 600 秒上限的一半）：xiyou_map186 跑入口门＋九军团，_b 跑农田与矿，_c 跑超级 Boss 与使者；
## 各段都自己开新局，三个场景断言合计与不拆时相同。不设时四段全跑。
@export var sections: Array = ["gate", "legion", "farm", "boss"]
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const TIMEOUT_MS := 90000  # 墙钟与帧数（60 帧/秒折算）都过了、事件也不再推进才算卡住，见 wait_budget.gd
const WaitBudget := preload("res://tests/wait_budget.gd")
var results: Array = []
var battles: Array = []   # 每场：{troop, result}


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	# 换场景（传送）时测试节点不能挂在当前场景下，挂到根节点
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set("sections", sections)
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
	var w := WaitBudget.new(TIMEOUT_MS)
	while w.waiting():
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
		XActor.test_param_max = 1.0e30  # 队伍属性堆过原版上限 99999999（XActor.PARAM_MAX），只在测试里放开
		a.refresh_passive()
		a.hp = a.mhp
		a.mp = a.mmp


func _battle_of(map: XMapScene) -> XBattleScene:
	for n in map.ui.get_children():
		if n is XBattleScene:
			return n
	return null


## 事件进度签名：打完的场数、当前战斗（哪一场、第几回合、敌人剩几个）、还没用掉的自动回答
func _progress(map: XMapScene) -> Array:
	var b := _battle_of(map)
	var alive := -1
	if b != null:
		alive = b.logic.enemies.filter(func(en): return en.is_alive()).size()
	return [battles.size(), b.get_instance_id() if b != null else 0, b.logic.turn if b != null else -1, alive, XMessageBox.auto_answers.size()]


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
	# 事件还在推进（打完一场、换了一场、回合往前、答了一句）就续等，不单靠墙钟（tools30）
	var w := WaitBudget.new(TIMEOUT_MS)
	while not st.done and w.waiting(_progress(map)):
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
	s.map_id = map_id
	s.x = x
	s.y = y
	s.direction = 8
	_party()
	get_tree().change_scene_to_file(MAP_SCENE)
	return s



const LEGACIES := [[0, 814, 778, 6219, 857], [1, 815, 779, 6233, 881], [2, 816, 776, 6227, 882], [3, 817, 777, 6223, 883], [4, 824, 785, 2829, 884]]



const GATE_MAP := 116
const WAR := 186


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_map186"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261023)
	if "gate" in sections:
		await _gate()
	if "legion" in sections:
		await _legion()
	if "farm" in sections:
		await _farm()
	if "boss" in sections:
		await _boss_and_envoy()
	_finish()


func _in_war(x := 46, y := 52) -> Array:
	var s := _start(WAR, x, y)
	if not await _wait_map(WAR):
		_check("war_loaded", false)
		return []
	return [s, _scene()]


func _gate() -> void:
	var s := _start(GATE_MAP, 28, 24)
	if not _check("gate_loaded", await _wait_map(GATE_MAP)):
		return
	var map: XMapScene = _scene()
	s.set_switch(940, true)
	map.refresh_events()
	await _run_event(map, 5, [1], "")
	_check("gate_no", _scene().map_id == GATE_MAP)
	await _run_event(map, 5, [0], "")
	_check("gate_to_war", await _wait_map(WAR) and _scene().player.grid == Vector2i(46, 51), [_scene().name])
	var ok := true
	for v in range(665, 674):
		ok = ok and int(s.variable(v)) >= 7 and int(s.variable(v)) <= 9
	_check("gate_levels_7_9", ok, range(665, 674).map(func(v): return s.variable(v)))
	# 返回门 EV1
	var map2: XMapScene = _scene()
	await _run_event(map2, 1, [1], "")
	_check("back_no", _scene().map_id == WAR)
	await _run_event(map2, 1, [0], "")
	_check("back_to_gate", await _wait_map(GATE_MAP) and _scene().player.grid == Vector2i(28, 25), [_scene().name])


## 军团：变量 665＝7 时 7 场 676＋元帅 677；犒劳三军 → CE999 掉落、自开关 A；重建城要铁锭铜锭各 75 → 自开关 C；科技页
func _legion() -> void:
	var r := await _in_war()
	if r.is_empty():
		return
	var s: XState = r[0]
	var map: XMapScene = r[1]
	s.set_variable(665, 7)
	var n0 := battles.size()
	await _run_event(map, 2, [2], "")
	_check("legion_think", battles.size() == n0)
	await _run_event(map, 2, [0, 0], "win")
	var fought: Array = battles.slice(n0).map(func(b): return b.troop)
	_check("legion_battles", fought == [676, 676, 676, 676, 676, 676, 676, 677], fought)
	_check("legion_loot", s.item_count(1826) >= 1 and s.item_count(1827) >= 1 and s.item_count(1828) >= 1, [s.item_count(1826), s.item_count(1827), s.item_count(1828)])
	var e: MVEvent = _event(map, 2)
	_check("legion_page_A", e.page_index == 2, e.page_index)
	# 重建：材料不够不动、够了换到科技页（自开关 C）
	await _run_event(map, 2, [0], "")
	_check("rebuild_short", _event(map, 2).page_index == 2)
	s.gain_item(1810, 75)
	s.gain_item(1811, 75)
	await _run_event(map, 2, [0], "")
	_check("rebuild_done", _event(map, 2).page_index == 3 and s.item_count(1810) == 0 and s.item_count(1811) == 0, [_event(map, 2).page_index, s.item_count(1810)])
	# 科技页：训练科技（CE990：变量 675 档，要肝帝积分与西瓜）；西瓜不足时不升级
	s.set_variable(675, 0)
	await _run_event(map, 2, [0], "")
	_check("tech_no_fruit", int(s.variable(675)) == 0)
	s.gain_item(934, 5000)
	s.set_variable(206, 100000)
	await _run_event(map, 2, [0], "")
	_check("tech_level_up", int(s.variable(675)) == 1, s.variable(675))
	# 另一档（变量 665＝8）与「安抚百姓」（自开关 B 页）
	r = await _in_war()
	s = r[0]
	map = r[1]
	s.set_variable(665, 8)
	n0 = battles.size()
	await _run_event(map, 2, [0, 1], "win")
	fought = battles.slice(n0).map(func(b): return b.troop)
	_check("legion8_battles", fought == [676, 676, 676, 676, 676, 676, 676, 676, 677], fought)
	_check("legion8_page_B", _event(map, 2).page_index == 1, _event(map, 2).page_index)


## 农田（EV3 西瓜地：变量 561 随机 1～9 档，每档五场（敌群 676＋2×(档−1)）；占领后收取果实＝(1＋干活奴隶)×(playtime−变量 601)×0.01 个西瓜）与矿（EV16～23）
func _farm() -> void:
	for k in [0.0, 0.99]:
		var r := await _in_war(14, 42)
		if r.is_empty():
			return
		var s: XState = r[0]
		var map: XMapScene = r[1]
		MVEventCore.fixed_random = k
		var n0 := battles.size()
		await _run_event(map, 3, [0], "win")
		var fought: Array = battles.slice(n0).map(func(b): return b.troop)
		var level := 1 if k == 0.0 else 9
		_check("farm_battles_%d" % level, fought.size() == 5 and fought.all(func(t): return t == 676 + 2 * (level - 1)), fought)
		if level == 1:
			_check("farm_page_A", _event(map, 3).page_index == 1, _event(map, 3).page_index)
			# 刚占领：果实 0，说「别急」
			var f0 := s.item_count(934)
			await _run_event(map, 3, [0], "")
			_check("farm_wait", s.item_count(934) == f0)
			# 增减奴隶
			await _run_event(map, 3, [1], "")
			_check("slave_none", int(s.variable(603)) == 0)
			s.set_variable(565, 3)
			await _run_event(map, 3, [1], "")
			_check("slave_add", int(s.variable(603)) == 1 and int(s.variable(565)) == 2, [s.variable(603), s.variable(565)])
			await _run_event(map, 3, [2], "")
			_check("slave_remove", int(s.variable(603)) == 0 and int(s.variable(565)) == 3)
			# 时间够了：每 100 秒产 1，收取
			s.set_variable(601, -10000)
			await _run_event(map, 3, [0], "")
			_check("farm_harvest", s.item_count(934) >= 100, s.item_count(934))
	MVEventCore.fixed_random = -1.0
	# 矿：每个事件占领一次（至少开一场战斗、翻到收取页）
	for id in range(16, 24):
		var r := await _in_war(46, 52)
		if r.is_empty():
			return
		var map: XMapScene = r[1]
		MVEventCore.fixed_random = 0.0
		var n0 := battles.size()
		await _run_event(map, id, [0], "win")
		_check("mine%d_battle" % id, battles.size() > n0, battles.slice(n0))
		_check("mine%d_page" % id, _event(map, id).page_index == 1, _event(map, id).page_index)
	MVEventCore.fixed_random = -1.0


## 超级 Boos EV32（敌群 739，距上次 3 分钟以上）与外界使者 EV33
func _boss_and_envoy() -> void:
	var r := await _in_war(48, 6)
	if r.is_empty():
		return
	var s: XState = r[0]
	var map: XMapScene = r[1]
	# 第一次变量 707＝0 先记 −1200，满足 ≥180 开战
	var n0 := battles.size()
	await _run_event(map, 32, [], "win")
	_check("boss_fight", battles.size() == n0 + 1 and battles[-1].troop == 739 and battles[-1].result == 0, battles.slice(n0))
	var n1 := battles.size()
	await _run_event(map, 32, [], "")
	_check("boss_rest", battles.size() == n1)
	await _run_event(map, 33, [], "")
	_check("envoy_gift", s.item_count(1634) == 1, s.item_count(1634))
	await _run_event(map, 33, [], "")
	_check("envoy_once", s.item_count(1634) == 1)


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
