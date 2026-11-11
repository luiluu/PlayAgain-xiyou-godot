extends Node
## 天启篇默认开局的贯通测试（审查 95 P3-2）：从标题按真实输入一路走到方桌大厅，再从标题读回来。
## xiyou_tianqi_opening 直接调 XTianqi.start_new_game 建局；这里只发按键／触屏事件，走 entry.gd 的标题与三页。
## 一、键盘：标题回车「新的游戏」→ 存档位页右移到已有存档的 2 号位 → 「换一格」取消覆盖（旧档逐字不变）→ 再选 2 号位「覆盖它」
##     → 难度页下移一档 → 随机阵容页重抽（名单换了）→ 「就是他们了」→ 大厅（道号、存档位、难度、阵容与确认页一致）
##     → 回标题「旧的回忆」回车三次读回 2 号位，进大厅、天启篇标记与道号都在。
## 二、触屏（XPlatform.force_mobile）：点「新的游戏」→ 点 5 号空位 → 点第一档 → 点重抽 → 点确认 → 大厅 → 点「旧的回忆」读回。
## 三、开关回退：XTianqi.ENABLED = false 时回车「新的游戏」走原版 Map001 开局（Map001 之后的流程由 xiyou_flow 实走）。
## 存档写到 user://test_xiyou_tianqi_title，测试结束删除。

const HUB := 4

var results: Array = []


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


func _scene() -> Node:
	return get_tree().current_scene


func _frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(cond: Callable, timeout := 6000) -> bool:
	for i in range(timeout):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _map_idle(map_id: int) -> bool:
	var s = _scene()
	return s is XMapScene and s.map_id == map_id and s.player != null and not s.busy


func _find(name: String) -> Node:
	var s = _scene()
	return s.find_child(name, true, false) if s != null else null


## 真实按键：按下、松开各发一次（松开不发会让动作一直算按着，见 Godot 回显键的坑）
func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(1)
	await _frames(2)


## 触屏点一下：ScreenTouch 按下、抬起（工程开着触摸模拟鼠标，按钮照常收到点击）
func _tap(c: Control) -> void:
	var pos: Vector2 = get_viewport().get_final_transform() * c.get_global_rect().get_center()
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = pos
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(1)
	await _frames(2)


func _tap_at(global: Vector2) -> void:
	var pos: Vector2 = get_viewport().get_final_transform() * global
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = pos
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(1)
	await _frames(2)


func _focus_name() -> String:
	var f := get_viewport().gui_get_focus_owner()
	return str(f.name) if f != null else ""


func _title() -> Node:
	var old_id := _scene().get_instance_id() if _scene() != null else 0   # 存 id：旧场景切走后被释放，闭包抓对象会变 null
	GameApp.enter_mode("xiyou")
	await _wait(func(): return _scene() != null and _scene().get_instance_id() != old_id and _scene().has_method("is_title_page") and _scene().is_title_page(), 300)
	await _frames(2)
	return _scene()


## 随机阵容页上的角色名（按 1～5 号位）
func _lineup_names() -> Array:
	var out := []
	var col = _scene().column if _scene() != null else null
	if col == null:
		return out
	for row in col.get_children():
		if row is HBoxContainer and row.get_child_count() >= 2 and row.get_child(1) is Label:
			out.append((row.get_child(1) as Label).text.replace("　（1 号位）", ""))
	return out


func _party_names(s: XState) -> Array:
	return s.party.map(func(id): return str(XDB.rec("Actors", int(id)).get("name", "")))


func _run() -> void:
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XSave.dir_override = "user://test_xiyou_tianqi_title"
	Engine.time_scale = 6.0
	seed(20261111)
	_clean()
	await _keyboard()
	await _touch()
	await _revert()
	_clean()
	XPlatform.force_mobile = null
	XTianqi.ENABLED = true
	Engine.time_scale = 1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _clean() -> void:
	var d := DirAccess.open(XSave.dir())
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(XSave.dir())


## 进大厅后的公共核对；返回当时的存档字典
func _hub(tag: String, slot: int, key: String, dao: String, names: Array) -> void:
	var s := XState.current
	var ok := await _wait(func(): return _map_idle(HUB) and XState.current.self_switch(HUB, 20, "A"))
	s = XState.current
	_check(tag + "_hub_reached", ok, [s.map_id])
	_check(tag + "_tianqi", XTianqi.active(s) and str(s.flags.get("tianqi", {}).get("difficulty", "")) == key, s.flags.get("tianqi"))
	_check(tag + "_dao_hao", s.actor_name == dao, s.actor_name)
	_check(tag + "_slot", s.fixed_save_slot() == slot and XSave.exists(slot), [s.fixed_save_slot(), XSave.exists(slot)])
	_check(tag + "_party_matches_page", s.party.size() == 5 and XTianqi.lineup_ok(key, s.party) and _party_names(s) == names, [_party_names(s), names])
	var saved = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(slot)))
	var flags = saved.get("flags", {}) if saved is Dictionary else {}
	_check(tag + "_saved", flags is Dictionary and flags.get("tianqi") is Dictionary and str(flags.tianqi.get("difficulty", "")) == key
		and str(saved.get("actor_name", dao)) == dao, flags.get("tianqi") if flags is Dictionary else saved)
	# 大厅首次到达的漩涡过场（EV76）放完再离开，免得协程挂着
	await _wait(func(): return _map_idle(HUB) and XState.current.self_switch(HUB, 76, "A"))


## 读回：标题「旧的回忆」→ 读档页（最近存的一格）→ 读取 → 确认
func _load_back(tag: String, slot: int, key: String, dao: String, touch: bool) -> void:
	var entry = await _title()
	var load_cmd: Button = entry._commands[1].node
	_check(tag + "_load_enabled", entry._commands[1].enabled)
	if touch:
		await _tap(load_cmd)
	else:
		await _key(KEY_DOWN)
		await _key(KEY_ENTER)
	var page = _find("LoadPage")
	_check(tag + "_load_page", page != null and page.slot() == slot, page.slot() if page != null else null)
	if page == null:
		return
	if touch:
		var lw: XMVWindow = page.list_win
		var row: int = page.index - page.top
		await _tap_at(lw.global_position + Vector2(XMVWindow.PADDING + 40, XMVWindow.PADDING + XSaveScene.LH * (row + 0.5)))
		var aw: XMVWindow = page.action_win
		await _tap_at(aw.global_position + Vector2.ONE * XMVWindow.PADDING + page.action_rect(0).get_center())
		var cw: XMVWindow = page.confirm_win
		await _tap_at(cw.global_position + Vector2(XMVWindow.PADDING + 40, XMVWindow.PADDING + XSaveScene.LH * 1.5))
	else:
		for i in 3:
			await _key(KEY_ENTER)
	var ok := await _wait(func(): return _map_idle(HUB))
	var s := XState.current
	_check(tag + "_loaded", ok and XTianqi.active(s) and s.actor_name == dao and s.fixed_save_slot() == slot
		and str(s.flags.get("tianqi", {}).get("difficulty", "")) == key, [ok, s.map_id, s.actor_name, s.fixed_save_slot(), s.flags.get("tianqi")])


func _keyboard() -> void:
	# 2 号位先放一份原版开局的档，用来测「换一格」不碰它
	XState.new_game_blank()
	XState.current.actor_name = "旧档"
	_check("kb_seed_save", XSave.save(2))
	var before := FileAccess.get_file_as_bytes(XSave.path(2))
	var entry = await _title()
	_check("kb_title_new_game_selected", entry._sel == 0)
	await _key(KEY_ENTER)
	_check("kb_slot_page", _find("TianqiSlot1") != null and _focus_name() == "TianqiSlot1", _focus_name())
	await _key(KEY_RIGHT)
	_check("kb_slot2_focused", _focus_name() == "TianqiSlot2", _focus_name())
	await _key(KEY_ENTER)
	# 已有存档：「覆盖它」「换一格」；先换一格（取消覆盖）
	_check("kb_overwrite_prompt", _find("TianqiSlot1") == null and _find("TianqiDifficulty_jiusi") == null)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	_check("kb_cancel_back_to_slots", _find("TianqiSlot2") != null)
	_check("kb_cancel_keeps_old_save", FileAccess.get_file_as_bytes(XSave.path(2)) == before)
	await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	await _key(KEY_ENTER)   # 覆盖它
	var first := _focus_name()
	_check("kb_difficulty_page", first.begins_with("TianqiDifficulty_"), first)
	await _key(KEY_DOWN)
	var chosen := _focus_name().trim_prefix("TianqiDifficulty_")
	_check("kb_difficulty_moved", chosen != first.trim_prefix("TianqiDifficulty_") and not XTianqi.difficulty(chosen).is_empty(), chosen)
	await _key(KEY_ENTER)
	_check("kb_lineup_page", _find("TianqiReroll") != null and _focus_name() == "TianqiReroll", _focus_name())
	var names := _lineup_names()
	var rerolled := false
	for i in 4:   # 重抽：随机的，偶尔抽到同一组就再抽
		var old_btn := _find("TianqiReroll")
		await _key(KEY_ENTER)
		rerolled = _find("TianqiReroll") != old_btn and _lineup_names() != names
		if rerolled:
			break
	_check("kb_reroll_changes_lineup", rerolled, [names, _lineup_names()])
	names = _lineup_names()
	_check("kb_lineup_five", names.size() == 5, names)
	await _key(KEY_DOWN)
	_check("kb_confirm_focused", _focus_name() == "TianqiConfirm", _focus_name())
	XMessageBox.auto_answers = ["键盘道号"]
	await _key(KEY_ENTER)
	await _hub("kb", 2, chosen, "键盘道号", names)
	await _load_back("kb", 2, chosen, "键盘道号", false)


func _touch() -> void:
	XPlatform.force_mobile = true
	var entry = await _title()
	await _tap(entry._commands[0].node)
	var slot5 = _find("TianqiSlot5")
	_check("tc_slot_page", slot5 != null)
	if slot5 == null:
		return
	await _tap(slot5)
	var key := ""
	for d in XTianqi.DIFFICULTIES:
		if not XTianqi.locked(d.key):
			key = str(d.key)
			break
	var diff = _find("TianqiDifficulty_" + key)
	_check("tc_difficulty_page", diff != null, key)
	if diff == null:
		return
	await _tap(diff)
	var names := _lineup_names()
	var rerolled := false
	for i in 4:
		var old_btn := _find("TianqiReroll")
		if old_btn == null:
			break
		await _tap(old_btn)
		rerolled = _find("TianqiReroll") != old_btn and _lineup_names() != names
		if rerolled:
			break
	_check("tc_reroll_changes_lineup", rerolled, [names, _lineup_names()])
	names = _lineup_names()
	XMessageBox.auto_answers = ["触屏道号"]
	var ok_btn = _find("TianqiConfirm")
	_check("tc_confirm_button", ok_btn != null)
	if ok_btn == null:
		return
	await _tap(ok_btn)
	await _hub("tc", 5, key, "触屏道号", names)
	await _load_back("tc", 5, key, "触屏道号", true)
	XPlatform.force_mobile = null


## 开关回退：XTianqi.ENABLED = false 时回车「新的游戏」回到原版 Map001 开局（不是天启篇存档）
func _revert() -> void:
	XTianqi.ENABLED = false
	await _title()
	var prev := XState.current
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ENTER
		e.physical_keycode = KEY_ENTER
		e.pressed = pressed
		Input.parse_input_event(e)
	await _wait(func(): return XState.current != prev, 10)
	var s := XState.current
	_check("revert_state_built", s != prev)
	if s == prev:
		await _title()
		XTianqi.ENABLED = true
		return
	_check("revert_original_opening", s.map_id == 1 and not XTianqi.active(s) and not XTianqi.has_pending() and _find("TianqiSlot1") == null,
		[s.map_id, s.flags])
	# 同一帧再切回标题，不真的进 Map001（开局事件的协程挂着退出会报资源未释放；Map001 之后由 xiyou_flow 实走）
	await _title()
	_check("revert_no_map_left", not (_scene() is XMapScene))
	XTianqi.ENABLED = true
