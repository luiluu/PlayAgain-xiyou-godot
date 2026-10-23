extends Node
## 神魔战场九个军团的「训练科技」（公共事件 990～998，变量 675～683 记档）逐档验收：期望值直接从公共事件的指令列表里读
## （每档：变量＝k、肝帝积分变量 206 ≥ pts、果实 ≥ need；扣 206 与果实，全体角色 forget/learn 技能，变量加一），
## 用地图事件（EV2、24～31 的自开关 C 页，选「训练科技」）真走一遍。另测满级、积分不足、果实不足三种不升级的情形。
## 科技技能对战斗的实际作用（被动／状态）不在这里验。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
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
	s.map_id = map_id
	s.x = x
	s.y = y
	s.direction = 8
	_party()
	get_tree().change_scene_to_file(MAP_SCENE)
	return s



const LEGACIES := [[0, 814, 778, 6219, 857], [1, 815, 779, 6233, 881], [2, 816, 776, 6227, 882], [3, 817, 777, 6223, 883], [4, 824, 785, 2829, 884]]



const WAR := 186
const LEGION_EVENTS := [2, 24, 25, 26, 27, 28, 29, 30, 31]
const PARTY_IDS := [1, 8, 9, 10]

var tiers_checked := 0


## 读公共事件 ce：[{k, pts, item, need, spend, forget: [], learn: [], limit}]；档位块以 111 [1, var, 0, k, 1] 开头
func _parse(ce: int, var_id: int) -> Array:
	var out := []
	var cur = null
	var tmp := -1
	for c in XDB.rec("CommonEvents", ce).list:
		var p: Array = c.parameters
		var code := int(c.code)
		if code == 111 and int(p[0]) == 1 and int(p[1]) == var_id and int(p[4]) == 1 and int(p[2]) == 0:
			cur = {"k": int(p[3]), "pts": -1, "item": 0, "need": 0, "remove": 0, "remove_item": 0, "spend": 0, "forget": [], "learn": [], "limit": 0}
			tmp = -1
			out.append(cur)
		elif cur == null:
			continue
		elif code == 111 and int(p[0]) == 1 and int(p[1]) == 206:
			cur.pts = int(p[3])
		elif code == 122 and int(p[3]) == 3 and int(p[4]) == 0:   # 临时变量 ＝ 持有物品数
			tmp = int(p[0])
			cur.item = int(p[5])
		elif code == 111 and int(p[0]) == 1 and int(p[1]) == tmp:
			cur.need = int(p[3])
		elif code == 126 and int(p[1]) == 1 and int(p[2]) == 0:   # 失去物品（原版个别档的数量与需求不同：笔误照做）
			cur.remove = int(p[3])
			cur.remove_item = int(p[0])
		elif code == 122 and int(p[0]) == 206 and int(p[2]) == 2:
			cur.spend = int(p[4])
		elif code == 355 or code == 655:
			var t := str(p[0])
			for m in RegEx.create_from_string("forgetSkill\\((\\d+)\\)").search_all(t):
				cur.forget.append(int(m.get_string(1)))
			for m in RegEx.create_from_string("learnSkill\\((\\d+)\\)").search_all(t):
				cur.learn.append(int(m.get_string(1)))
			var lm := RegEx.create_from_string("j < (\\d+)").search(t)
			if lm:
				cur.limit = int(lm.get_string(1))
	return out


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_legion_tech"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XGuide.MILESTONE_ENABLED = false
	seed(20261023)
	for i in range(9):
		await _legion(i)
	_check("tiers_total", tiers_checked >= 9 * 9, tiers_checked)
	_finish()


func _legion(i: int) -> void:
	var ce := 990 + i
	var var_id := 675 + i
	var ev: int = LEGION_EVENTS[i]
	var tiers := _parse(ce, var_id)
	var tag := "legion%d" % ce
	_check(tag + "_tiers", tiers.size() == 11 and tiers[0].k == 10, tiers.map(func(t): return t.k))
	var s := _start(WAR, 46, 52)
	if not _check(tag + "_loaded", await _wait_map(WAR)):
		return
	var map: XMapScene = _scene()
	s.set_self_switch(WAR, ev, "C", true)
	map.refresh_events()
	if not _check(tag + "_page_C", _event(map, ev).page_index == 3, _event(map, ev).page_index):
		return
	# 商店（第 2 项）：打开商品表 [奴隶契约 983, 各军团自己的心法 1351＋序号]（买入价在物品备注，由 xiyou_shop_buy 对照参照）
	var shops := []
	map.ui.child_entered_tree.connect(func(n):
		if n is XShop:
			shops.append(n.goods.map(func(g): return [int(g[0]), int(g[1]), int(g[2]), int(g[3])]))
			n.closed.emit.call_deferred())
	await _run_event(map, ev, [1], "")
	_check(tag + "_shop", shops == [[[0, 983, 0, 0], [0, 1351 + i, 0, 0]]], shops)
	# 满级：变量 10 → 只提示，不变
	s.set_variable(var_id, 10)
	s.set_variable(206, 10000000)
	await _run_event(map, ev, [0], "")
	_check(tag + "_max", int(s.variable(var_id)) == 10 and int(s.variable(206)) == 10000000)
	for t in tiers.slice(1):
		var name := "%s_k%d" % [tag, t.k]
		if t.pts < 0 or t.need <= 0 or t.item <= 0 or t.spend <= 0 or t.remove <= 0:
			_check(name + "_parsed", false, t)
			continue
		var actors := PARTY_IDS.map(func(id): return s.actor(id))
		# 资源不足：积分不够 / 果实不够，都不升级
		s.set_variable(var_id, t.k)
		s.set_variable(206, t.pts - 1)
		s.items[t.item] = t.need + 5
		await _run_event(map, ev, [0], "")
		_check(name + "_short_points", int(s.variable(var_id)) == t.k and s.item_count(t.item) == t.need + 5)
		s.set_variable(206, t.pts + 7)
		s.items[t.item] = t.need - 1
		await _run_event(map, ev, [0], "")
		_check(name + "_short_item", int(s.variable(var_id)) == t.k and int(s.variable(206)) == t.pts + 7)
		# 够了：升级，扣积分和果实，技能忘／学
		s.items[t.item] = t.need + 3
		s.items[t.remove_item] = maxi(s.item_count(t.remove_item), t.remove + 3) if t.remove_item != t.item else t.need + 3
		for a in actors:
			for f in t.forget:
				a.learn_skill(f)
			for l in t.learn:
				a.forget_skill(l)
		var before_remove := s.item_count(t.remove_item)
		await _run_event(map, ev, [0], "")
		_check(name + "_level", int(s.variable(var_id)) == t.k + 1, s.variable(var_id))
		_check(name + "_points", int(s.variable(206)) == t.pts + 7 - t.spend, [s.variable(206), t.pts, t.spend])
		# 原版笔误照做：嘤嘤城（990）以外的军团，第 2、1 档扣的是西瓜（物品 934）13000／1200 个，不是自家果实
		_check(name + "_item", s.item_count(t.remove_item) == maxi(0, before_remove - t.remove), [t.item, t.remove_item, before_remove, s.item_count(t.remove_item), t.remove])
		if t.remove_item != t.item:
			_check(name + "_own_fruit_kept", s.item_count(t.item) == t.need + 3, s.item_count(t.item))
		var skills_ok := true
		for a in actors:
			for f in t.forget:
				skills_ok = skills_ok and not a.skill_ids.has(f)
			for l in t.learn:
				skills_ok = skills_ok and (a.skill_ids.has(l) or XDB.rec("Skills", l).is_empty())
		_check(name + "_skills", skills_ok, [t.forget, t.learn])
		tiers_checked += 1


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
