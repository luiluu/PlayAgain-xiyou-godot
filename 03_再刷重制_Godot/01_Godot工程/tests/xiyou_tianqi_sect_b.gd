extends Node
## 天启篇教派连带内容·包乙「小小鱼破枷锁」（XTianqiSect 的 YI 段）：
## 一、15／20／25 层原来破枷锁的人（Map032 EV007、Map116 EV006、Map147 EV004）和大厅讲抽奖被动上限的人（Map004 EV003）天启篇不出；
## 二、开局抽奖被动上限五档照旧（5／5／10／17／22），小小鱼开局说一句；
## 三、挣脱枷锁三个被动在天启篇只留「抽奖被动上限+1」：没有全属性、没有伤害结果乘区的开战状态；
## 四、实跑四条线：15 层回声、20 层使徒打赢、25 层传闻之后各 +1、学对应被动，存档读回不重复发，三重后 8／8／13／20／25；
##     使徒输了、别的敌群、开场没打完都不发；
## 五、回退开关 YI 关掉回原样；原版档不受影响。

## 地图场景的替身：文字记下，开战按 results 依次给结果
class FakeHost extends RefCounted:
	var said: Array = []
	var save_on_first_text := false
	var results: Array = []
	var map_id := 4
	func show_text(_f: String, _i: int, lines: Array) -> void:
		if save_on_first_text:  # 演出中途存档（节点已标 seen、台词还没演完）
			save_on_first_text = false
			XSave.save(3)
		said.append_array(lines)
	func show_text_with_choices(_f: String, _i: int, _lines: Array, options: Array, _cancel: int) -> int:
		return options.size() - 1
	func transfer(id: int, _x: int, _y: int, _d: int, _fade := 0) -> void:
		map_id = id
		XState.current.map_id = id
	func start_battle(_troop: int, _e: bool, _l: bool, _random := false) -> int:
		XTianqiWarAlien._pending = ""
		XTianqiHorsemen._pending = ""
		return int(results.pop_front()) if not results.is_empty() else 0


class InterpHost:
	extends "res://tests/xiyou_event_compare.gd".EventHost


var results: Array = []
const SLOT := 3
const SAVE_DIR := "user://test_xiyou_tianqi_sect_b"


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	XSave.dir_override = SAVE_DIR
	_hall_and_floors()
	_opening()
	_skills()
	for line in XTianqiLine.KEYS:
		await _chain(line)
	await _guards()
	_original()
	for slot in range(1, 11):
		DirAccess.remove_absolute(XSave.path(slot))
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _ids() -> Array:
	return XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


## 天启篇存档、5 个弱者、已通关 5 层
func _tianqi(diff := "jianxian", line := "") -> XState:
	var lineup := _ids().slice(0, 5)
	var s := XTianqi.start_new_game(3, diff, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, 6)
	XState.current = s
	if line != "":
		s.flags.tianqi["line"] = line
	return s


func _plain() -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	return s


func _page_of(map_id: int, event_id: int) -> int:
	for ev in XDB.map(map_id).get("events", []):
		if ev != null and int(ev.id) == event_id:
			var e := MVEvent.new()
			e.map_id = map_id
			e.event_id = event_id
			e.data = ev
			var p := e._find_page()
			e.free()
			return p
	return -2


const NPCS := [[4, 3], [32, 7], [116, 6], [147, 4]]


func _hall_and_floors() -> void:
	var s := _tianqi()
	s.set_variable(14, 1)  # 天道枷锁（原 NPC 页要它）
	var shown := NPCS.filter(func(p): return _page_of(int(p[0]), int(p[1])) != -1)
	_check("npcs_hidden", shown.is_empty(), shown)
	_check("hides_only_those", not XTianqiSect.hides(32, 8) and not XTianqiSect.hides(116, 7) and not XTianqiSect.hides(147, 5) and not XTianqiSect.hides(4, 54))
	XTianqiSect.YI = false
	var off := NPCS.filter(func(p): return _page_of(int(p[0]), int(p[1])) < 0)
	XTianqiSect.YI = true
	_check("switch_off_npcs_shown", off.is_empty(), off)
	var p := _plain()
	p.set_variable(14, 1)
	var orig := NPCS.filter(func(q): return _page_of(int(q[0]), int(q[1])) < 0)
	_check("original_npcs_shown", orig.is_empty(), orig)


func _cap_of(cmds: Array) -> int:
	var v := -1
	for c in cmds:
		if int(c.code) == 122 and int(c.parameters[0]) == 9:
			v = int(c.parameters[4])
	return v


const CAPS := {"xunchang": 5, "jianxian": 5, "jiusi": 10, "lianyu": 17, "zhengdao": 22}


func _opening() -> void:
	var got := {}
	for d in CAPS:
		got[d] = _cap_of(XTianqi.opening_commands(1, d, [1, 2, 3, 5, 6]))
	_check("opening_caps_unchanged", got == CAPS, got)
	var text := JSON.stringify(XTianqiSect.opening_commands())
	_check("opening_guide_line", text.contains("抽奖学来的被动"), text)
	XTianqiSect.YI = false
	var off := JSON.stringify(XTianqiSect.opening_commands())
	XTianqiSect.YI = true
	_check("opening_switch_off", not off.contains("抽奖学来的被动"))
	var all := text + JSON.stringify(XTianqiSect.YI_LINES)
	_check("texts_clean", not all.contains("教派") and not all.contains("天道使者") and not all.contains("求道者"), all)
	_check("texts_no_four", not (JSON.stringify(XTianqiSect.YI_LINES) + XTianqiSect.YI_OPENING_LINE).contains("4"))


func _skills() -> void:
	_tianqi()
	var bad := []
	for sid in XTianqiSect.YI_SKILLS:
		var r := XDB.rec("Skills", int(sid))
		var note := str(r.note)
		var meta: Dictionary = r.meta
		if note.contains("passivePBST") or note.contains("StartPushState") or note.contains("伤害结果") or note.contains("全属性") \
				or meta.keys().any(func(k): return str(k).begins_with("passivePBST") or str(k).begins_with("StartPushState")) \
				or not note.contains("抽奖被动上限+1") or not str(r.name).begins_with("挣脱枷锁"):
			bad.append([sid, note])
	_check("tianqi_skills_slot_only", bad.is_empty(), bad)
	_check("generated_untouched", str(XDB.table("Skills")[6178].note).contains("passivePBST2"))
	XTianqiSect.YI = false
	var off := str(XDB.rec("Skills", 6180).note)
	XTianqiSect.YI = true
	_check("skills_switch_off", off.contains("passivePBST2") and off.contains("StartPushState1003"))
	_plain()
	_check("skills_original", str(XDB.rec("Skills", 6179).note).contains("StartPushState1002"))


## 实跑：开局指令经 MVInterpreter 跑完（阵容、变量 9 都由开局指令写），一条线从开场打完到 25 层；存读档走 XSave 真实写盘
func _chain(line: String) -> void:
	var lineup := _ids().slice(0, 5)
	XMessageBox.auto_answers = ["测试道号"]
	XTianqi.start_new_game(3, "jiusi", lineup)
	var s := XState.current
	s.map_id = 4
	var ih := InterpHost.new()  # 地图场景的解释器宿主替身（事件对照用的那个）
	add_child(ih)
	var interp := MVInterpreter.new(ih, 4, 0, XTianqi.take_pending())
	await interp.run()
	ih.queue_free()
	_check(line + "_opening_ran", s.party == lineup and int(s.variable(9)) == 10 and int(s.variable(14)) == 1, [s.party, s.variable(9), interp.skipped.slice(0, 3)])
	s.set_variable(20, 6)
	s.flags.tianqi["line"] = line
	XTianqiLine.progress(line, s)["stage"] = XTianqiLine.stage_done(line)
	var host := FakeHost.new()
	var cap0 := int(s.variable(9))
	var a := s.actor(int(s.party[0]))
	var atk0 := a.param(2)
	# 15 层回声：演出第一句时存档（已标 seen、台词还没说完），读回来这一重也已经在
	host.save_on_first_text = true
	await XTianqiLine.run_arrival(host, s, 32)
	host.save_on_first_text = false
	_check(line + "_echo15", int(s.variable(9)) == cap0 + 1 and a.skill_ids.has(6178) and not a.skill_ids.has(6179) \
			and host.said.any(func(t): return str(t).contains("我改一下")), [s.variable(9), host.said])
	_check(line + "_no_stats", is_equal_approx(a.param(2), atk0), [atk0, a.param(2)])
	_check(line + "_all_actors", s.actor(int(_ids()[7])).skill_ids.has(6178))  # 不在队的也学（原版 for $dataActors）
	_check(line + "_load_slot", XSave.load_slot(SLOT))
	var mid: XState = XState.current
	_check(line + "_mid_beat_save_kept", mid != s and XTianqiLine.seen(line, mid, "echo15") and XTianqiSect.fetters_given(mid) == [1] \
			and int(mid.variable(9)) == cap0 + 1 and mid.actor(int(mid.party[0])).skill_ids.has(6178), [XTianqiSect.fetters_given(mid), mid.variable(9)])
	s = mid
	a = s.actor(int(s.party[0]))
	await XTianqiLine.run_arrival(host, s, 32)
	_check(line + "_echo15_once", int(s.variable(9)) == cap0 + 1)
	# 20 层使徒：输了不发、赢了发第二重
	var troop := int(XTianqiLine.alien_preset(line, "apostle20").troop)
	await XTianqiLine.before_battle(host, s, troop)
	XTianqiWarAlien._pending = ""
	await XTianqiSect.after_map_battle(host, s, troop, 2)
	_check(line + "_apostle_lost", int(s.variable(9)) == cap0 + 1)
	await XTianqiSect.after_map_battle(host, s, troop, 0)
	_check(line + "_apostle20", int(s.variable(9)) == cap0 + 2 and a.skill_ids.has(6179) and host.said.any(func(t): return str(t).contains("再松一格")))
	# 存档读回：已发的不再发
	_check(line + "_save", XSave.save(SLOT) and XSave.load_slot(SLOT))
	var back: XState = XState.current
	_check(line + "_saved", back != s and XTianqiSect.fetters_given(back) == [1, 2], XTianqiSect.fetters_given(back))
	await XTianqiSect.after_map_battle(host, back, troop, 0)
	await XTianqiLine.run_arrival(host, back, 32)
	_check(line + "_load_no_repeat", int(back.variable(9)) == cap0 + 2, back.variable(9))
	host.said.clear()
	await XTianqiLine.run_arrival(host, back, 147)  # 25 层传闻
	_check(line + "_rumor25", int(back.variable(9)) == cap0 + 3 and back.actor(int(back.party[0])).skill_ids.has(6180) and host.said.any(func(t): return str(t).contains("最后一次")), [back.variable(9), host.said])
	_check(line + "_final_cap", int(back.variable(9)) == 13, back.variable(9))  # 九死：10 → 13


func _guards() -> void:
	# 五档三重后的上限
	var got := {}
	for d in CAPS:
		var s := _tianqi(d, "war")
		s.set_variable(9, _cap_of(XTianqi.opening_commands(1, d, [1, 2, 3, 5, 6])))
		for t in [1, 2, 3]:
			XTianqiSect.grant_fetter(s, t)
		got[d] = int(s.variable(9))
	_check("caps_after_three", got == {"xunchang": 8, "jianxian": 8, "jiusi": 13, "lianyu": 20, "zhengdao": 25}, got)
	var s := _tianqi("jianxian", "war")
	var host := FakeHost.new()
	var cap0 := int(s.variable(9))
	# 开场没打完：节点、使徒都不发
	await XTianqiLine.run_arrival(host, s, 32)
	await XTianqiSect.after_map_battle(host, s, 456, 0)
	_check("before_opening_none", int(s.variable(9)) == cap0)
	XTianqiLine.progress("war", s)["stage"] = XTianqiLine.stage_done("war")
	await XTianqiSect.after_map_battle(host, s, 30, 0)
	_check("other_troop_none", int(s.variable(9)) == cap0)
	# 开关关掉：节点照说、不发
	XTianqiSect.YI = false
	await XTianqiLine.run_arrival(host, s, 32)
	await XTianqiSect.after_map_battle(host, s, 456, 0)
	XTianqiSect.YI = true
	_check("switch_off_none", int(s.variable(9)) == cap0 and not s.actor(int(s.party[0])).skill_ids.has(6178) and XTianqiSect.fetters_given(s).is_empty())
	# 没选线：没有节点
	var n := _tianqi("jianxian", "")
	var c := int(n.variable(9))
	await XTianqiLine.run_arrival(host, n, 32)
	await XTianqiSect.after_map_battle(host, n, 456, 0)
	_check("no_line_none", int(n.variable(9)) == c)


func _original() -> void:
	var s := _plain()
	s.set_variable(9, 5)
	_check("original_grant_refused", not XTianqiSect.grant_fetter(s, 1) and int(s.variable(9)) == 5)
	_check("original_hides_none", not XTianqiSect.hides(32, 7) and not XTianqiSect.hides(4, 3))
