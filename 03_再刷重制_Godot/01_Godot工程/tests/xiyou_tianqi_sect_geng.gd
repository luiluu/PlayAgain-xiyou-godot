extends Node
## 天启篇教派连带内容·包庚「传承与武运」（XTianqiSect.GENG）：
## 一、魔塔外围五位传承 NPC（Map195 EV016～020）天启篇默认开放（走 sw1:2303 线、不走轮回页），台词改写；
## 二、15／20／25 层传承人（Map032 EV008、Map116 EV007、Map147 EV005）默认开放，30 层前都能补，31 层起关；
## 三、城隍庙（Map189 EV021）天启篇照随机页走（四小强无损学 3920），去掉 6216／6241 两步与「随机模式下」字样；
## 四、事件经 MVInterpreter 真跑、XSave 真实写盘读档验证；开关 GENG 关掉回原样；西游普通档不受影响。

var results: Array = []


class MockHost:
	extends Node
	var message: XMessageBox
	var toasts: Array = []

	func _init() -> void:
		message = XMessageBox.new()
		add_child(message)

	func show_message(msg: Dictionary) -> int:
		return await message.run(msg)

	func toast(text: String) -> void:
		toasts.append(text)

	func character(_id: int, _eid: int = 0):
		return null

	func refresh_events() -> void:
		pass

	func start_battle(_troop_id: int, _can_escape: bool = false, _can_lose: bool = false, _random_encounter := false) -> int:
		return 0


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	await _test_outskirts_inheritance()
	await _test_floor_inheritors()
	await _test_chenghuang_wuyun()
	await _test_xsave_roundtrip()
	_test_switch_off_and_plain()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _tianqi_state() -> XState:
	var s := XState.new_game_blank()
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "jiusi", "lineup": [8, 9, 10, 11]}
	XState.current = s
	return s


func _plain_state() -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	return s


func _event_data(map_id: int, event_id: int) -> Dictionary:
	for ev in XDB.map(map_id).get("events", []):
		if ev != null and int(ev.id) == event_id:
			return ev
	return {}


func _make_event(map_id: int, event_id: int) -> MVEvent:
	var e := MVEvent.new()
	e.setup_event(map_id, _event_data(map_id, event_id))
	return e


func _make_host() -> MockHost:
	var h := MockHost.new()
	add_child(h)
	return h


func _test_outskirts_inheritance() -> void:
	var s := _tianqi_state()
	var host := _make_host()
	var expected := {
		16: 1968,
		17: 1970,
		18: 1969,
		19: 1966,
		20: 1972,
	}
	for eid in expected.keys():
		var e := _make_event(195, eid)
		_check("outskirts_ev%d_find_page_kept_blocked" % eid, e._find_page() == -1, e._find_page())
		_check("outskirts_ev%d_refresh_visible" % eid, e.page_index == 100 and not e.page.is_empty() and not e.command_list().is_empty(), e.page_index)
		_check("outskirts_ev%d_intercepts" % eid, XTianqiSect.intercepts(s, 195, eid))
		e.free()
		XMessageBox.transcript.clear()
		XMessageBox.auto_answers = [0]
		await XTianqiSect.run_event(host, s, 195, eid)
		var book_id: int = expected[eid]
		_check("outskirts_ev%d_gives_book_%d" % [eid, book_id], s.item_count(book_id) == 1, s.item_count(book_id))
		_check("outskirts_ev%d_sets_self_a" % eid, s.self_switch(195, eid, "A"))
		var text := JSON.stringify(XMessageBox.transcript)
		_check("outskirts_ev%d_text_clean" % eid,
			not text.contains("两派") and not text.contains("教派") and not text.contains("天道使者") and not text.contains("求道者"),
			text)
	# EV020（六道魔君）在 var 20 >= 24 且 self:A 时仍能触发第 3 页（七煞功，idx 2 → page_index 102）
	s.set_variable(20, 24)
	var e20 := _make_event(195, 20)
	_check("outskirts_ev20_qisha_page", e20.page_index == 102, e20.page_index)
	e20.free()
	host.queue_free()


func _test_floor_inheritors() -> void:
	var s := _tianqi_state()
	var host := _make_host()
	# 15/20/25 层传承人：过了对应层守层者（var 20 = 16/21/26）乃至 30 层时仍开放；31 层起关闭
	for pair in [[32, 8, 16], [116, 7, 21], [147, 5, 26], [32, 8, 30]]:
		var mid: int = pair[0]
		var eid: int = pair[1]
		var fl: int = pair[2]
		s.set_variable(20, fl)
		var e := _make_event(mid, eid)
		_check("inheritor_m%d_v%d_find_page_blocked" % [mid, fl], e._find_page() == -1, e._find_page())
		_check("inheritor_m%d_v%d_open" % [mid, fl], e.page_index == 100 and not e.page.is_empty(), e.page_index)
		e.free()
	# 实跑 15 层传承人（var 20 = 20，已过 15 层守层者）：选第一项「传承一：无畏之愿」，调 CE 1347 让变量 857 对应角色学 6218
	s.set_variable(20, 20)
	s.set_variable(857, 8)
	XMessageBox.transcript.clear()
	XMessageBox.auto_answers = [0]
	await XTianqiSect.run_event(host, s, 32, 8)
	_check("inheritor_m32_learns_6218_at_floor20", s.actor(8).skill_ids.has(6218), s.actor(8).skill_ids)
	_check("inheritor_m32_sets_var810", int(s.variable(810)) == 1, s.variable(810))
	var msg := JSON.stringify(XMessageBox.transcript)
	_check("inheritor_m32_text_updated", msg.contains("31") and not msg.contains("一旦通过该层守护者"), msg)
	# 31 层起关闭（page_index == 101，传承之火已熄）
	s.set_variable(20, 31)
	for pair in [[32, 8], [116, 7], [147, 5]]:
		var e := _make_event(pair[0], pair[1])
		_check("inheritor_m%d_closed_at_31" % pair[0], e.page_index == 101, e.page_index)
		e.free()
	host.queue_free()


func _test_chenghuang_wuyun() -> void:
	var s := _tianqi_state()
	var host := _make_host()
	for aid in [8, 9, 10, 11]:
		s.actor(aid).learn_skill(6216)
	var e := _make_event(189, 21)
	_check("chenghuang_before_page", e.page_index == 101 and XTianqiSect.intercepts(s, 189, 21), e.page_index)
	var choices_text := JSON.stringify(e.command_list())
	_check("chenghuang_no_random_mode_text", not choices_text.contains("随机模式下"), choices_text)
	e.free()
	XMessageBox.transcript.clear()
	XMessageBox.auto_answers = [0, 0]
	await XTianqiSect.run_event(host, s, 189, 21)
	for aid in [8, 9, 10, 11]:
		var sk: Array = s.actor(aid).skill_ids
		_check("chenghuang_actor%d_learns_3920" % aid, sk.has(3920), sk)
		_check("chenghuang_actor%d_keeps_6216" % aid, sk.has(6216), sk)
		_check("chenghuang_actor%d_no_6241" % aid, not sk.has(6241), sk)
	_check("chenghuang_other_actor_no_3921", not s.actor(1).skill_ids.has(3921), s.actor(1).skill_ids)
	_check("chenghuang_sets_self_a", s.self_switch(189, 21, "A"))
	_check("chenghuang_after_no_intercept", not XTianqiSect.intercepts(s, 189, 21))
	var e_after := _make_event(189, 21)
	_check("chenghuang_after_page4", e_after.page_index == 3, e_after.page_index)
	e_after.free()
	host.queue_free()


func _test_xsave_roundtrip() -> void:
	var prev_dir := XSave.dir_override
	var test_dir := "user://test_xiyou_tianqi_sect_geng"
	XSave.dir_override = test_dir
	DirAccess.make_dir_recursive_absolute(test_dir)
	var s := _tianqi_state()
	var host := _make_host()
	s.set_variable(20, 20)
	s.set_variable(857, 8)
	s.actor(8).learn_skill(6216)
	XMessageBox.auto_answers = [0]
	await XTianqiSect.run_event(host, s, 195, 16)
	XMessageBox.auto_answers = [0]
	await XTianqiSect.run_event(host, s, 32, 8)
	XMessageBox.auto_answers = [0, 0]
	await XTianqiSect.run_event(host, s, 189, 21)
	var saved := XSave.save(1)
	_check("xsave_write_ok", saved)
	XState.current = null
	var load_ok := XSave.load_slot(1)
	var loaded := XState.current
	_check("xsave_load_ok", load_ok and loaded != null)
	if load_ok and loaded != null:
		XState.current = loaded
		_check("xsave_book_1968", loaded.item_count(1968) == 1, loaded.item_count(1968))
		_check("xsave_self_a_195_16", loaded.self_switch(195, 16, "A"))
		_check("xsave_skill_6218", loaded.actor(8).skill_ids.has(6218), loaded.actor(8).skill_ids)
		_check("xsave_skill_3920_6216_no_6241",
			loaded.actor(8).skill_ids.has(3920) and loaded.actor(8).skill_ids.has(6216) and not loaded.actor(8).skill_ids.has(6241),
			loaded.actor(8).skill_ids)
		var e189 := _make_event(189, 21)
		_check("xsave_chenghuang_stays_page4", e189.page_index == 3, e189.page_index)
		e189.free()
	XSave.remove(1)
	XSave.dir_override = prev_dir
	host.queue_free()


func _test_switch_off_and_plain() -> void:
	var s := _tianqi_state()
	XTianqiSect.GENG = false
	_check("switch_off_no_intercept_195", not XTianqiSect.intercepts(s, 195, 16))
	_check("switch_off_no_intercept_32", not XTianqiSect.intercepts(s, 32, 8))
	_check("switch_off_no_intercept_189", not XTianqiSect.intercepts(s, 189, 21))
	var e195_off := _make_event(195, 16)
	var e189_off := _make_event(189, 21)
	_check("switch_off_195_hidden", e195_off.page_index == -1, e195_off.page_index)
	_check("switch_off_189_page1", e189_off.page_index == 0, e189_off.page_index)
	e195_off.free()
	e189_off.free()
	XTianqiSect.GENG = true

	var plain := _plain_state()
	_check("plain_no_intercept_195", not XTianqiSect.intercepts(plain, 195, 16))
	_check("plain_no_intercept_32", not XTianqiSect.intercepts(plain, 32, 8))
	_check("plain_no_intercept_189", not XTianqiSect.intercepts(plain, 189, 21))
	var e195_plain := _make_event(195, 16)
	var e189_plain := _make_event(189, 21)
	_check("plain_195_hidden_without_2303", e195_plain.page_index == -1, e195_plain.page_index)
	_check("plain_189_page1", e189_plain.page_index == 0, e189_plain.page_index)
	e195_plain.free()
	e189_plain.free()
