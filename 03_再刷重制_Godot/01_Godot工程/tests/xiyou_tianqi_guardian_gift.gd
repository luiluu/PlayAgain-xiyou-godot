extends Node
## 天启篇去见面礼（XTianqiGuardianGift，T236，Kyo 11-19「224甲」）：
## 一、数据：天启篇档 18 张守层者图第 0 页选单没有「缴纳见面礼」、取消键指「离开」、分支号连续；打赢后判断 842 前先清零；
##     打赢后那页开头有补发段（首胜标记＝0 才给）；西游档、回退开关关掉时地图和原数据一字不差；31～33 层不动。
## 二、真地图 13 层（Map064 圣骑士·瑟伦，敌群 111）：天启篇新档打赢必给 3 个宝珠（物品 2000）、置首胜标记 861、开独立开关 A；
##     旧档已交礼（842＝1）没打 → 打赢照给；旧档已交礼打过（A 开、861＝0）→ 第 1 页开口补发一次，再开口不重复；
##     西游档交了礼打赢不给（原版）。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
const WaitBudget := preload("res://tests/wait_budget.gd")
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const TIMEOUT_MS := 90000
const FLOOR_MAP := 64
const FLOOR_EV := 1
const ORB := 2000
const FLAG := 861
## 地图号 → [首胜标记变量, 宝珠物品, 数量]（原版不交礼那次）
const EXPECT := {
	64: [861, 2000, 3], 30: [862, 2018, 3], 32: [863, 2019, 3], 33: [864, 2016, 3], 45: [865, 2023, 3], 46: [866, 2017, 3],
	47: [867, 2003, 1], 116: [868, 2025, 1], 117: [869, 2028, 1], 119: [870, 2030, 1], 118: [871, 2031, 1], 120: [872, 2035, 1],
	147: [873, 2046, 1], 155: [874, 2052, 1], 182: [875, 2050, 1], 145: [876, 2053, 1], 144: [877, 2051, 1], 146: [878, 2049, 1],
}
const FLOOR31_33 := [148, 156, 157]

var results: Array = []


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok, "detail": detail})
	return ok


func _run() -> void:
	var kit = Kit.new("xiyou_tianqi_guardian_gift")
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	XBattleScene.force_auto = true   # 战斗全自动（同 xiyou_floor_run）
	_data()
	await _live()
	XTianqiGuardianGift.ENABLED = true
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	kit.teardown()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _reload() -> void:
	XTextFix.clear_cache()


func _raw_map(map_id: int) -> Dictionary:
	var d = XDB.load_json("maps/Map%03d.json" % map_id)
	XTextFix.patch_map(map_id, d)   # 只比本模块：别的读图修正两边都做
	return d


func _ev(data: Dictionary, id: int) -> Dictionary:
	for ev in data.get("events", []):
		if ev is Dictionary and int(ev.id) == id:
			return ev
	return {}


func _first_choice(list: Array) -> Dictionary:
	for c in list:
		if int(c.code) == 102:
			return c
	return {}


# ---------- 一、数据 ----------

func _ints(a: Array) -> Array:
	return a.map(func(v): return int(v) if (v is float or v is int) else v)


func _data() -> void:
	_check("guardian_list_18", XTianqiGuardianGift.GUARDIANS.size() == 18 and EXPECT.keys().all(func(k): return XTianqiGuardianGift.GUARDIANS.has(k)), XTianqiGuardianGift.GUARDIANS.keys())
	# 西游档：原样
	var x := XState.new_game_blank()
	XState.current = x
	_reload()
	var same := []
	for m in EXPECT:
		if JSON.stringify(XDB.map(m)) != JSON.stringify(_raw_map(m)):
			same.append(m)
	_check("xiyou_maps_untouched", same.is_empty(), same)
	_check("xiyou_has_gift_choice", (_first_choice(_ev(XDB.map(FLOOR_MAP), FLOOR_EV).pages[0].list).parameters[0] as Array).has("缴纳见面礼"))
	# 天启篇档
	Kit.new_game("jiusi")
	_reload()
	for m in EXPECT:
		_floor_data(m)
	for m in FLOOR31_33:
		_check("floor31_33_untouched_%d" % m, JSON.stringify(XDB.map(m)) == JSON.stringify(_raw_map(m)))
	# 回退开关
	XTianqiGuardianGift.ENABLED = false
	_reload()
	var off := []
	for m in EXPECT:
		if JSON.stringify(XDB.map(m)) != JSON.stringify(_raw_map(m)):
			off.append(m)
	_check("switch_off_original", off.is_empty(), off)
	XTianqiGuardianGift.ENABLED = true
	XTianqiGuardianGift.BACKFILL = false
	_reload()
	var p1: Array = _ev(XDB.map(FLOOR_MAP), FLOOR_EV).pages[1].list
	_check("backfill_off_no_prefix", int(p1[0].code) != 111, p1[0])
	XTianqiGuardianGift.BACKFILL = true
	_reload()


func _floor_data(m: int) -> void:
	var exp: Array = EXPECT[m]
	var ev := _ev(XDB.map(m), XTianqiGuardianGift.GUARDIANS[m])
	var p0: Array = ev.pages[0].list
	var ch := _first_choice(p0)
	var opts: Array = ch.parameters[0]
	_check("choices_%d" % m, opts == ["挑战", "关于本层", "离开"], opts)
	_check("cancel_leave_%d" % m, int(ch.parameters[1]) == 2 and int(ch.parameters[2]) == 0, ch.parameters)
	# 选单分支：402 号 0、1、2，各自的名字对上，没有「缴纳见面礼」分支
	var branches := []
	var ci := p0.find(ch)
	for i in range(ci + 1, p0.size()):
		var c: Dictionary = p0[i]
		if int(c.indent) == int(ch.indent) and int(c.code) == 404:
			break
		if int(c.indent) == int(ch.indent) and int(c.code) == 402:
			branches.append([int(c.parameters[0]), str(c.parameters[1])])
	_check("branches_%d" % m, branches == [[0, "挑战"], [1, "关于本层"], [2, "离开"]], branches)
	# 挑战分支里打赢后判断 842 之前先清零；分支里给宝珠（数量照原版）、置首胜标记
	var at := -1
	for i in p0.size():
		var c: Dictionary = p0[i]
		if int(c.code) == 111 and int(c.parameters[0]) == 1 and int(c.parameters[1]) == 842:
			at = i
			break
	_check("reset_before_if_%d" % m, at > 0 and int(p0[at - 1].code) == 122 and _ints(p0[at - 1].parameters) == [842, 842, 0, 0, 0] and int(p0[at - 1].indent) == int(p0[at].indent), p0[at - 1] if at > 0 else null)
	var body := []
	for i in range(at + 1, p0.size()):
		if int(p0[i].indent) <= int(p0[at].indent):
			break
		body.append(p0[i])
	_check("reward_body_%d" % m, body.any(func(c): return int(c.code) == 126 and _ints(c.parameters) == [exp[1], 0, 0, exp[2]]) \
		and XTianqiGuardianGift.flag_var(body) == exp[0], body)
	# 打赢后那页（独立开关 A）：开头补发段＝如果标记＝0 → 给宝珠、置标记
	var pa: Dictionary = {}
	for i in range(1, ev.pages.size()):
		var cd: Dictionary = ev.pages[i].conditions
		if cd.selfSwitchValid and not cd.switch1Valid:
			pa = ev.pages[i]
			break
	var pl: Array = pa.get("list", [])
	var ok: bool = pl.size() > 4 and int(pl[0].code) == 111 and _ints(pl[0].parameters) == [1, exp[0], 0, 0, 0] and int(pl[0].indent) == 0 \
		and int(pl[1].code) == 126 and _ints(pl[1].parameters) == [exp[1], 0, 0, exp[2]] and int(pl[1].indent) == 1
	var end := -1
	for i in pl.size():
		if int(pl[i].code) == 412 and int(pl[i].indent) == 0:
			end = i
			break
	_check("backfill_%d" % m, ok and end > 0 and XTianqiGuardianGift.flag_var(pl.slice(1, end)) == exp[0], pl.slice(0, 6))
	# 店还在原地（看首胜标记的那个分支照旧）
	_check("shop_branch_%d" % m, pl.slice(max(end, 0)).any(func(c): return int(c.code) == 111 and _ints(c.parameters) == [1, exp[0], 0, 1, 0]))


# ---------- 二、真地图 ----------

func _scene() -> Node:
	return get_tree().current_scene


func _wait_map(map_id: int) -> bool:
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while t0.waiting():
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


func _battle_of(map: XMapScene) -> XBattleScene:
	for n in map.ui.get_children():
		if n is XBattleScene:
			return n
	return null


## 跑一个事件到结束；kill：战斗一开始就把敌人全部击倒
func _run_event(map: XMapScene, id: int, answers: Array, kill := false) -> bool:
	var e := _event(map, id)
	if not _check("map%d_event%d_present" % [map.map_id, id], e != null and not e.page.is_empty()):
		return false
	XMessageBox.auto_answers = answers.duplicate()
	var st := {"done": false}
	(func():
		await map.run_event(e)
		st.done = true).call()
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while not st.done and t0.waiting():
		if kill:
			var b := _battle_of(map)
			if b != null and not b.logic.enemies.is_empty():
				for en in b.logic.enemies:
					if en.is_alive():
						en.hp = 0.0
						en.add_state(1)
		await get_tree().process_frame
	return _check("map%d_event%d_finished" % [map.map_id, id], st.done)


func _goto(s: XState) -> XMapScene:
	s.set_variable(20, 12)
	s.map_id = FLOOR_MAP
	s.x = 35
	s.y = 5
	s.direction = 8
	XState.current = s
	XTextFix.sync_mode()
	_reload()
	get_tree().change_scene_to_file(MAP_SCENE)
	if not await _wait_map(FLOOR_MAP):
		return null
	return _scene()


func _live() -> void:
	# 1. 天启篇新档：没交礼（也交不了），打赢必给
	var s := Kit.new_game("jiusi")
	var map := await _goto(s)
	if not _check("floor13_loaded", map != null):
		return
	var orbs := s.item_count(ORB)
	map.toasts.clear()
	await _run_event(map, FLOOR_EV, [0], true)
	_check("tq_win_orbs", s.item_count(ORB) == orbs + 3, [orbs, s.item_count(ORB)])
	_check("tq_win_flag", int(s.variable(FLAG)) == 1 and int(s.variable(842)) == 0, [s.variable(FLAG), s.variable(842)])
	_check("tq_win_selfsw", s.self_switch(FLOOR_MAP, FLOOR_EV, "A"))
	_check("tq_win_toast", map.toasts.any(func(t): return str(t).contains("启示眷属") and str(t).contains("三个宝珠")), map.toasts)
	# 打赢后那页开口：标记已是 1，不补发
	await _run_event(map, FLOOR_EV, [2])
	_check("tq_no_double", s.item_count(ORB) == orbs + 3, s.item_count(ORB))
	# 2. 旧天启篇档：已交礼打过（A 开、861＝0）→ 开口补发一次，再开口不重复
	s.set_variable(FLAG, 0)
	var before := s.item_count(ORB)
	await _run_event(map, FLOOR_EV, [2])
	_check("tq_backfill_once", s.item_count(ORB) == before + 3 and int(s.variable(FLAG)) == 1, [before, s.item_count(ORB), s.variable(FLAG)])
	await _run_event(map, FLOOR_EV, [2])
	_check("tq_backfill_no_repeat", s.item_count(ORB) == before + 3, s.item_count(ORB))
	# 3. 旧天启篇档：已交礼（842＝1）还没打 → 打赢照给
	s.set_self_switch(FLOOR_MAP, FLOOR_EV, "A", false)
	s.set_variable(FLAG, 0)
	s.set_variable(842, 1)
	map.refresh_events()
	before = s.item_count(ORB)
	await _run_event(map, FLOOR_EV, [0], true)
	_check("tq_paid_old_save_still_gets", s.item_count(ORB) == before + 3 and int(s.variable(FLAG)) == 1 and int(s.variable(842)) == 0, [before, s.item_count(ORB), s.variable(FLAG)])
	# 4. 西游档：交了礼打赢不给（原版）
	var x := XState.new_game(3, 1, [8, 9, 10])
	x.set_variable(842, 1)
	map = await _goto(x)
	if not _check("xiyou_floor13_loaded", map != null):
		return
	var xo := x.item_count(ORB)
	await _run_event(map, FLOOR_EV, [0], true)
	_check("xiyou_paid_no_orb", x.item_count(ORB) == xo and int(x.variable(FLAG)) == 0 and x.self_switch(FLOOR_MAP, FLOOR_EV, "A"), [xo, x.item_count(ORB), x.variable(FLAG)])
