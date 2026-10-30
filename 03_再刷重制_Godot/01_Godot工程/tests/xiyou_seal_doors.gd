extends Node
## 副本门与王座宝箱的两条可回退优化（无界面，用 xiyou_dungeon 的 DungeonHost 直接跑事件页）：
## - B1（O-120，MVInterpreter.seal_check_fix）：「请重置副本！」写成「变量 5＝副本号」的 6 扇门——Map023 事件 2（7）、Map029 事件 2（8）、
##   Map069 事件 65 贪婪宫殿（20）、Map156 事件 2、157 事件 2、158 事件 1（14）。每扇门：变量 5＝1（本副本没重置）时「挑战副本」
##   只提示「请重置副本！」，不扣符文、不传送；随后「重置副本」认得（重置完毕，变量 5、6 归零，变量 21 减一）；
##   seal_check_fix 设 {} 时照原版：变量 5＝1 照样扣符文进门、变量 5 叠成 2（正式引擎实跑同此，见交付单）。
## - B2（O-120，MVInterpreter.removed_gate_fix）：厄运王座宝箱（Map080 事件 13）打完首领（变量 175≥3）出深渊之门，
##   持邀请函 179、随机数 0.5（变量 106＝1、107＝2）选「进入此门」：正式版只提示「区域已移除」，人留在王座、宝箱能再开；
##   重制改走「离开这是非之地」：回 Map078 (21,26)、副本重置、退邀请函，宝箱回到第 1 页。设 {} 时同正式引擎（参照数字见交付单）。
##   另核不出门（不持邀请函）与只打厄运之王（第 2 页，金钱 100000）两支与正式引擎一致。
const DH := preload("res://tests/xiyou_dungeon.gd")
const PARTY := [1, 8, 10, 9]
## [地图, 事件, 原版比较的副本号, 符文, 门要的枚数, 进门传到的地图]
const DOORS := [[23, 2, 7, 110, 1, 34], [29, 2, 8, 110, 1, 35], [69, 65, 20, 397, 3, 109],
	[156, 2, 14, 171, 1, 54], [157, 2, 14, 171, 1, 54], [158, 1, 14, 171, 1, 54]]
const INVITE := 179

var results := []
var host


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _run() -> void:
	GameApp.fast_headless_frames()
	XSave.dir_override = "user://test_xiyou_seal_doors"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	host = DH.DungeonHost.new()
	add_child(host)
	for d in DOORS:
		await _door(d)
	await _chest()
	_finish()


func _finish() -> void:
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	MVInterpreter.max_steps = 0
	MVInterpreter.fixed_random = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _new_state(map_id: int, x: int, y: int) -> XState:
	var s := XState.new_game_blank()
	for id in PARTY:
		s.add_actor(id)
	s.difficulty = 3
	XState.current = s
	XDungeon.battle = {}
	MVInterpreter.fixed_random = 0.5
	s.map_id = map_id
	s.x = x
	s.y = y
	host.erased = {}
	return s


## 跑当前地图事件的当前页；picks 依次回答选项。返回 {page, trace}
func _event(id: int, picks: Array, battle := "win") -> Dictionary:
	var s := XState.current
	host.trace = []
	host.picks = picks.duplicate()
	host.battle_result = battle
	var page := DH.page_of(s.map_id, id, host.erased)
	if page >= 0:
		MVInterpreter.max_steps = 20000
		MVInterpreter.steps = 0
		MVInterpreter.aborted = false
		var interp := MVInterpreter.new(host, s.map_id, id, DH.event_rec(s.map_id, id).pages[page].list.duplicate(true))
		await interp.run()
	return {"page": page, "trace": host.trace.duplicate(true)}


static func _said(r: Dictionary, text: String) -> bool:
	return r.trace.any(func(t): return str(t.get("t")) == "msg" and str(t.get("lines", [])).contains(text))


static func _moved(r: Dictionary) -> bool:
	return r.trace.any(func(t): return str(t.get("t")) == "transfer")


func _door(d: Array) -> void:
	var map_id: int = d[0]
	var ev: int = d[1]
	var id: int = d[2]
	var rune: int = d[3]
	var need: int = d[4]
	var tag := "m%d_ev%d" % [map_id, ev]
	var rec := DH.event_rec(map_id, ev)
	var s := _new_state(map_id, int(rec.x), int(rec.y) + 1)
	var c: Dictionary = rec.pages[0].conditions
	if c.selfSwitchValid:
		s.set_self_switch(map_id, ev, str(c.selfSwitchCh), true)
	var vars := func(): return [int(s.variable(5)), int(s.variable(6)), int(s.variable(21)), s.item_count(rune)]
	# B1：本副本没重置（变量 5＝1、6＝本副本），带够符文点挑战 → 请重置副本，不扣符文、不传送
	s.gain_item(rune, need)
	s.set_variable(5, 1)
	s.set_variable(6, id)
	s.set_variable(21, 1)
	var r := await _event(ev, [0])
	check(tag + "_b1_blocked", r.page == 0 and _said(r, "请重置副本") and not _moved(r) and vars.call() == [1, id, 1, need], [r, vars.call()])
	# 别的副本（厄运王座 17）没重置也拦
	s.set_variable(6, 17)
	r = await _event(ev, [0])
	check(tag + "_b1_other", _said(r, "请重置副本") and not _moved(r) and vars.call() == [1, 17, 1, need], [r, vars.call()])
	# 重置能认：变量 5、6 归零，变量 21 减一
	s.set_variable(6, id)
	r = await _event(ev, [1])
	check(tag + "_reset", _said(r, "重置完毕") and vars.call() == [0, 0, 0, need], [r, vars.call()])
	# 回退：seal_check_fix 设 {} 时照原版，变量 5＝1 照样扣符文进门、变量 5 叠成 2
	s.set_variable(5, 1)
	s.set_variable(6, id)
	s.set_variable(21, 1)
	var saved := MVInterpreter.seal_check_fix
	MVInterpreter.seal_check_fix = {}
	r = await _event(ev, [0])
	MVInterpreter.seal_check_fix = saved
	check(tag + "_fix_off_original", _moved(r) and s.map_id == int(d[5]) and vars.call() == [2, id, 2, 0], [r.trace.filter(func(t): return t.t == "transfer"), vars.call()])


## 王座：进门（Map078 事件 2）→ 厄运之王（Map080 事件 15）→ 变量 175 记成 4（另三位首领打完）→ 宝箱
func _throne(invite: bool, extra_bosses := true) -> XState:
	var s := _new_state(78, 21, 26)
	s.gain_item(397, 2)
	if invite:
		s.gain_item(INVITE, 1)
	s.direction = 8
	await _event(2, [0])
	await _event(15, [0])
	if extra_bosses:
		s.set_variable(175, 4)
	return s


func _chest() -> void:
	var gear := func(s: XState): return s.gear_count("armor", 1845)
	# 优化后：选「进入此门」提示区域已移除，再走离开分支
	var s := await _throne(true)
	check("throne_entered", s.map_id == 80 and s.switch(127) and int(s.variable(5)) == 1 and int(s.variable(6)) == 17, [s.map_id, s.variable(5)])
	var r := await _event(13, [0])
	var done := s.map_id == 78 and Vector2i(s.x, s.y) == Vector2i(21, 26) and not s.switch(127) and int(s.variable(5)) == 0 and int(s.variable(6)) == 0 \
		and int(s.variable(21)) == 0 and int(s.variable(175)) == 0
	check("b2_fix_notice_then_leave", r.page == 2 and _said(r, "【区域已移除】深渊:魔神之渊因地图文件损坏，已从当前版本移除。") and done
		and gear.call(s) == 1 and s.item_count(INVITE) == 1 and not s.switch(107), [r, s.map_id, gear.call(s), s.item_count(INVITE)])
	s.map_id = 80
	r = await _event(13, [0])
	check("b2_fix_chest_closed", r.page == 0 and _said(r, "只有击败厄运之王以后才能够打开") and gear.call(s) == 1, r)
	# 回退：removed_gate_fix 设 {} 时同正式引擎——留在王座、邀请函被吞，宝箱再开又得一件，然后（不再出门）回 78 重置
	var saved := MVInterpreter.removed_gate_fix
	MVInterpreter.removed_gate_fix = {}
	s = await _throne(true)
	r = await _event(13, [0])
	check("b2_original_stays", r.page == 2 and _said(r, "【区域已移除】") and s.map_id == 80 and s.switch(127) and gear.call(s) == 1
		and s.item_count(INVITE) == 0 and s.switch(107) and int(s.variable(107)) == 2, [r, s.map_id, gear.call(s)])
	r = await _event(13, [0])
	check("b2_original_again", r.page == 2 and s.map_id == 78 and not s.switch(127) and gear.call(s) == 2 and int(s.variable(106)) == 2, [r, s.map_id, gear.call(s)])
	MVInterpreter.removed_gate_fix = saved
	# 不持邀请函：变量 106＝2 不出门，直接回 78 重置
	s = await _throne(false)
	r = await _event(13, [0])
	check("b2_no_gate", r.page == 2 and not _said(r, "深渊之门") and s.map_id == 78 and not s.switch(127) and gear.call(s) == 1, [r, s.map_id])
	# 出门选「离开这是非之地」：回 78、退邀请函（原版就这样）
	s = await _throne(true)
	r = await _event(13, [1])
	check("b2_leave", _said(r, "深渊之门") and s.map_id == 78 and gear.call(s) == 1 and s.item_count(INVITE) == 1 and not s.switch(107), [r, s.map_id])
	# 只打厄运之王（变量 175＝1）：第 2 页，金钱 100000，回 78
	s = await _throne(false, false)
	var gold := s.gold
	r = await _event(13, [])
	check("b2_page2_gold", r.page == 1 and s.gold - gold == 100000 and s.map_id == 78 and not s.switch(127), [r, s.gold - gold])
