extends Node
## T055（玩家 11-16「副本内可以存档回城，副本外刚好反过来」）：变量 21「在副本内」计数在副本外停在 −1。
## 回城公共事件（CE10 回到大厅等 45 个）条件「变量 21＝0」才传送，否则「当前正在挑战副本，不可使用该物品！」。
## 根因①：抽奖强制存档（CE1431～1434，Map141 深渊:未知存在进门就调 CE1434）「变量 21 减一→调 CE1 存档→加一」，
##   原版读档会从存档那条接着跑把一补回来，重制不存解释器，副本里存的档读回来变量 21＝0，逃离后成 −1（XDungeon.save_resume_fix）。
## 根因②：原版数据猿神空间门（Map128／154 事件 3）「重置副本」连减两次变量 21（XDungeon.inside_repair，顶层事件结束不留负数）。
## 旧档兼容：读档按副本上下文修正（XDungeon.repair_after_load）。西游档与天启篇档各跑一遍；开关关掉时能复现原 bug。
## 用真实数据：Map003 EV7 二层副本门（第 0 页，开关 1565）、Map123 EV6 逃离、CE10 回到大厅、CE1434 第 70～72 条、Map128 EV3。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const BLOCK := "当前正在挑战副本，不可使用该物品！"

var results := []


class Host:
	extends "res://tests/xiyou_event_compare.gd".EventHost
	var real_save := true

	func save_game(slot: int) -> bool:
		trace.append({"t": "save", "slot": slot})
		return XSave.save(slot) if real_save else true


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


static func _page_list(map_id: int, ev_id: int, page: int) -> Array:
	for e in XDB.map(map_id).get("events", []):
		if e is Dictionary and int(e.id) == ev_id:
			return e.pages[page].list
	return []


func _run_list(host: Host, map_id: int, ev_id: int, list: Array, answers := []) -> void:
	MVInterpreter.max_steps = 20000
	MVInterpreter.steps = 0
	MVInterpreter.aborted = false
	host.trace = []
	host.answers = answers.duplicate()
	var interp := MVInterpreter.new(host, map_id, ev_id, list.duplicate(true))
	await interp.run()


## 用回城物品（CE10 回到大厅）：返回 "ok"（传送了）、"block"（被拦）或别的
func _use_return(host: Host) -> String:
	var s := XState.current
	await _run_list(host, s.map_id, 0, XDB.rec("CommonEvents", 10).list)
	var moved := host.trace.any(func(e): return e.t == "transfer")
	var blocked := host.trace.any(func(e): return e.t == "msg" and Array(e.lines).has(BLOCK))
	return "ok" if moved and not blocked else ("block" if blocked and not moved else JSON.stringify(host.trace).left(300))


func _enter(host: Host) -> void:
	var s := XState.current
	s.map_id = 3
	s.set_switch(1565, true)
	s.gain_item(24, 1)
	await _run_list(host, 3, 7, _page_list(3, 7, 0), [0])   # 挑战副本


func _escape(host: Host) -> void:
	XState.current.map_id = 123
	await _run_list(host, 123, 6, _page_list(123, 6, 0), [0])   # 逃离
	XState.current.map_id = 3


## CE1434 第 70～72 条（变量 21 减一、调 CE1 存档、变量 21 加一），缩进归 0
func _lottery_save_list() -> Array:
	var ce: Array = XDB.rec("CommonEvents", 1434).list
	var out := []
	for i in [70, 71, 72]:
		var c: Dictionary = ce[i].duplicate(true)
		c.indent = 0
		out.append(c)
	out.append({"code": 0, "indent": 0, "parameters": []})
	return out


func _v21() -> int:
	return int(XState.current.variable(XDungeon.VAR_INSIDE))


func _new_state(kind: String) -> void:
	var s: XState
	if kind == "tianqi":
		s = XTianqi.start_new_game(3, "lianyu", [1])
	else:
		s = XState.new_game(3, 1, [8, 10, 9])
	s.map_id = 3
	s.x = 41
	s.y = 17
	s.flags.SaveGameId = 1
	s.set_switch(161, true)   # CE1 存档位 1


func _scenario(kind: String, host: Host) -> void:
	var p := kind + "."
	XDungeon.save_resume_fix = true
	XDungeon.inside_repair = true
	# 数据前提：CE10 的条件就是「变量 21＝0」；CE1434 第 70～72 条就是减一→CE1→加一
	var c10: Dictionary = XDB.rec("CommonEvents", 10).list[5]
	check(p + "data.ce10_cond", int(c10.code) == 111 and Array(c10.parameters).map(func(v): return int(v)) == [1, 21, 0, 0, 0], c10)
	var lot := _lottery_save_list()
	check(p + "data.ce1434_wrap", XDungeon.save_bias(lot, 1, 1) == {21: 1}, lot)
	check(p + "data.wrap_only_ce1", XDungeon.save_bias(lot, 1, 2).is_empty() and XDungeon.save_bias(lot, 0, 1).is_empty())

	# 1. 副本外可用
	_new_state(kind)
	check(p + "outside_ok", await _use_return(host) == "ok", _v21())
	# 2. 副本内禁用
	await _enter(host)
	check(p + "entered", _v21() == 1 and XDungeon.inside(XState.current), _v21())
	XState.current.map_id = 123
	check(p + "inside_block", await _use_return(host) == "block")
	# 3. 从副本出来后可用
	await _escape(host)
	check(p + "escaped", _v21() == 0, _v21())
	check(p + "after_escape_ok", await _use_return(host) == "ok")

	# 4. 根因①：副本里抽奖强制存档→读档→逃离→副本外可用
	_new_state(kind)
	await _enter(host)
	XState.current.map_id = 123
	await _run_list(host, 123, 0, lot)
	check(p + "lottery.saved", host.trace.any(func(e): return e.t == "save") and _v21() == 1, host.trace)
	var raw = JSON.parse_string(XSaveSeal.read_text(XSave.path(1)))
	var saved21 = raw.get("variables", {}).get("21", raw.get("variables", {}).get(21)) if raw is Dictionary else null
	check(p + "lottery.file_has_1", saved21 != null and int(saved21) == 1, saved21)
	check(p + "lottery.load", XSave.load_slot(1) and _v21() == 1, _v21())
	XState.current.map_id = 123
	check(p + "lottery.inside_block", await _use_return(host) == "block")
	await _escape(host)
	check(p + "lottery.after_escape_ok", _v21() == 0 and await _use_return(host) == "ok", _v21())

	# 4b. 开关全关＝旧写法：复现玩家报的「副本外被拦」
	XDungeon.save_resume_fix = false
	XDungeon.inside_repair = false
	_new_state(kind)
	await _enter(host)
	XState.current.map_id = 123
	await _run_list(host, 123, 0, lot)
	XSave.load_slot(1)
	check(p + "off.loaded_0", _v21() == 0, _v21())
	XState.current.map_id = 123
	check(p + "off.inside_ok_bug", await _use_return(host) == "ok")
	await _escape(host)
	check(p + "off.outside_block_bug", _v21() == -1 and await _use_return(host) == "block", _v21())
	# 把这份坏档存下来，当旧档用
	XState.current.map_id = 3
	check(p + "off.save_bad", XSave.save(2))
	XDungeon.save_resume_fix = true
	XDungeon.inside_repair = true

	# 5. 旧档兼容：副本外 −1 读档归零、残留上下文清掉
	check(p + "legacy.out_load", XSave.load_slot(2) and _v21() == 0 and XDungeon.context(XState.current).is_empty(), [_v21(), XDungeon.context(XState.current)])
	check(p + "legacy.out_ok", await _use_return(host) == "ok")
	# 旧档兼容：副本里存的 0（有上下文、变量 5＝1）读回 1
	_new_state(kind)
	await _enter(host)
	XState.current.set_variable(XDungeon.VAR_INSIDE, 0)
	XState.current.map_id = 123
	check(p + "legacy.in_save", XSave.save(3))
	check(p + "legacy.in_load", XSave.load_slot(3) and _v21() == 1, _v21())
	check(p + "legacy.in_block", await _use_return(host) == "block")

	# 6. 根因②：猿神空间门重置连减两次，修正后归 0；关掉照原版 −1
	for fix in [true, false]:
		XDungeon.inside_repair = fix
		_new_state(kind)
		var s := XState.current
		s.map_id = 128
		s.set_variable(5, 1)
		s.set_variable(6, 24)
		s.set_variable(21, 1)
		await _run_list(host, 128, 3, _page_list(128, 3, 0), [1])   # 重置副本
		var want := 0 if fix else -1
		check(p + "yuanshen.reset_%s" % ("fix" if fix else "orig"), _v21() == want and int(s.variable(5)) == 0, [_v21(), s.variable(5)])
		s.map_id = 3
		check(p + "yuanshen.return_%s" % ("fix" if fix else "orig"), await _use_return(host) == ("ok" if fix else "block"))
	XDungeon.inside_repair = true


func _run() -> void:
	GameApp.fast_headless_frames()
	TestEnv.isolate("xiyou_dungeon_inside_flag")
	XMessageBox.auto = true
	var host := Host.new()
	add_child(host)
	for kind in ["xiyou", "tianqi"]:
		await _scenario(kind, host)
	_finish()


func _finish() -> void:
	XDungeon.save_resume_fix = true
	XDungeon.inside_repair = true
	MVInterpreter.max_steps = 0
	for f in DirAccess.get_files_at(XSave.dir()):
		DirAccess.remove_absolute(XSave.dir().path_join(f))
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
