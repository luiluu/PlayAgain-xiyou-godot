extends Node
## 天启篇开局三页的取消键（pro-newgame-back2，取代 pro-newgame-back；xiyou_tianqi_e2e 贯通测试发现）：选存档位、选难度、随机阵容页
## （连同已有存档的覆盖确认页）按取消键退回上一页，和点页里「返回」「换一格」一样。
## 四种来源各走一遍：Esc、X（原版取消键，XKeyMap 补进 ui_cancel）、ui_cancel 动作（虚拟取消键、手柄 B 发的就是它）、
## 安卓返回键（GameApp.platform.go_back，模拟发行构建：子页发 ui_cancel，标题页才是顶层）。
## 不影响：标题页按取消键不换页（发行构建下返回键在标题页照旧提示「再按一次退出」）；取消回到选格不碰已有存档；
## 退回难度页再进阵容仍是原来那格；进大厅后 Esc 照旧开主菜单、再按关掉。
## 标题页不设 _back：新标题（XTianqiTitle）与原版图片指令标题（XTianqiTitle.ENABLED = false）各测一遍。
## 顺手的四个窗口页（导出选档、导入选格、一句话结果页、「继续」自动存档确认）：Esc 回标题。
## 存档写到 user://test_xiyou_newgame_back，测试结束删除。

const HUB := 4
const OLD_SLOT := 2     # 预先放一份旧档，测覆盖确认页
const NEW_SLOT := 3     # 空格，测三页逐页退回与最后开局
const METHODS := ["esc", "x", "action", "back"]

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


func _find(name: String) -> Node:
	var s = _scene()
	return s.find_child(name, true, false) if s != null else null


func _focus_name() -> String:
	var f := get_viewport().gui_get_focus_owner()
	return str(f.name) if f != null else ""


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(1)
	await _frames(2)


## 按一下取消：四种来源之一
func _cancel(method: String) -> void:
	match method:
		"esc":
			await _key(KEY_ESCAPE)
		"x":
			await _key(KEY_X)
		"action":
			for pressed in [true, false]:
				var e := InputEventAction.new()
				e.action = "ui_cancel"
				e.pressed = pressed
				Input.parse_input_event(e)
				await _frames(1)
			await _frames(2)
		"back":
			# 发行构建（跳过入口菜单直达标题）：子页不是顶层，返回键当取消键；时间隔开，免得被当成「两秒内再按」
			ReleaseEntry.simulate_release = true
			var got := GameApp.platform.go_back(_back_ms)
			ReleaseEntry.simulate_release = false
			_back_ms += 5000
			_last_back = got
			await _frames(3)

var _back_ms := 100000
var _last_back := ""


func _title() -> Node:
	var old_id := _scene().get_instance_id() if _scene() != null else 0
	GameApp.enter_mode("xiyou")
	await _wait(func(): return _scene() != null and _scene().get_instance_id() != old_id and _scene().has_method("is_title_page") and _scene().is_title_page(), 300)
	await _frames(2)
	return _scene()


func _on_title() -> bool:
	var s = _scene()
	return s != null and s.has_method("is_title_page") and s.is_title_page()


func _on_slots() -> bool:
	return _find("TianqiSlot1") != null


func _on_difficulty() -> bool:
	return _find("TianqiSlot1") == null and _focus_name().begins_with("TianqiDifficulty_")


func _on_lineup() -> bool:
	return _find("TianqiReroll") != null


## 标题回车「新的游戏」进选格页（有存档时 selectLast 会先停在「旧的回忆」，先选回第一项）
func _open_slots(entry) -> void:
	if entry._tq_title != null:
		entry._tq_title.select(0)
	else:
		entry._select(0, true)
	await _frames(1)
	await _key(KEY_ENTER)


## 选格页把焦点挪到第 slot 格（两列：右移一格、下移一行两格）并回车
func _pick_slot(slot: int) -> void:
	var b := _find("TianqiSlot%d" % slot) as Button
	if b != null:
		b.grab_focus()
		await _frames(1)
	await _key(KEY_ENTER)


func _run() -> void:
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XSave.dir_override = "user://test_xiyou_newgame_back"
	Engine.time_scale = 6.0
	seed(20261111)
	_clean()
	GameApp.platform.quit_on_back = false
	XState.new_game_blank()
	XState.current.actor_name = "旧档"
	_check("seed_old_save", XSave.save(OLD_SLOT))
	var before := FileAccess.get_file_as_bytes(XSave.path(OLD_SLOT))
	for m in METHODS:
		await _pages(m, before)
	await _title_untouched()
	await _picture_title_untouched()
	await _side_pages()
	await _title()
	await _open_slots(_scene())
	await _start_and_hub()
	_clean()
	XPlatform.force_mobile = null
	ReleaseEntry.simulate_release = false
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


## 一种取消来源：覆盖确认 → 选格；阵容 → 难度 → 选格 → 标题
func _pages(m: String, before: PackedByteArray) -> void:
	var entry = await _title()
	await _open_slots(entry)
	_check(m + "_slot_page", _on_slots())
	# 已有存档的格：覆盖确认页按取消＝「换一格」
	await _pick_slot(OLD_SLOT)
	_check(m + "_overwrite_page", not _on_slots() and _find("WindowBack") != null and (_find("WindowBack") as Button).text == "换一格")
	await _cancel(m)
	_check(m + "_overwrite_back_to_slots", _on_slots(), _last_back)
	_check(m + "_overwrite_keeps_old_save", FileAccess.get_file_as_bytes(XSave.path(OLD_SLOT)) == before)
	# 空格 → 难度 → 阵容，再逐页退回
	await _pick_slot(NEW_SLOT)
	_check(m + "_difficulty_page", _on_difficulty(), _focus_name())
	await _key(KEY_ENTER)
	_check(m + "_lineup_page", _on_lineup(), _focus_name())
	await _cancel(m)
	_check(m + "_lineup_back_to_difficulty", _on_difficulty() and not _on_lineup(), _focus_name())
	await _cancel(m)
	_check(m + "_difficulty_back_to_slots", _on_slots(), _focus_name())
	await _cancel(m)
	_check(m + "_slots_back_to_title", _on_title() and _scene() == entry, _last_back)
	if m == "back":
		_check("back_subpages_are_cancel", _last_back == "cancel", _last_back)
	_check(m + "_old_save_untouched", FileAccess.get_file_as_bytes(XSave.path(OLD_SLOT)) == before and not XSave.exists(NEW_SLOT))


## 标题页：取消键不换页（菜单还是同一个、选中不动）；发行构建下返回键在标题页照旧提示再按一次退出
func _title_untouched() -> void:
	var entry = await _title()
	var tq = entry._tq_title
	_check("title_is_new_title", tq != null and not entry._back.is_valid())
	for m in ["esc", "x", "action"]:
		await _cancel(m)
		_check("title_" + m + "_stays", _on_title() and entry._tq_title == tq and _find("TianqiSlot1") == null)
	await _cancel("back")
	_check("title_back_hints", _last_back == "hint" and _on_title() and entry._tq_title == tq and GameApp.platform.hint_text().contains("再按一次"), _last_back)
	# 标题页的确认键照旧开「新的游戏」
	await _open_slots(entry)
	_check("title_accept_still_works", _on_slots())


## 退回难度页再进阵容仍是原来那格；开局进大厅后 Esc 照旧开、关主菜单
func _start_and_hub() -> void:
	# 上一步停在选格页
	await _pick_slot(NEW_SLOT)
	await _key(KEY_ENTER)
	await _cancel("esc")
	var key := _focus_name().trim_prefix("TianqiDifficulty_")
	await _key(KEY_ENTER)
	_check("relineup_page", _on_lineup())
	var ok_btn := _find("TianqiConfirm") as Button
	if ok_btn == null:
		_check("confirm_button", false)
		return
	ok_btn.grab_focus()
	await _frames(1)
	XMessageBox.auto_answers = ["返回键道号"]
	await _key(KEY_ENTER)
	var reached := await _wait(func():
		var s = _scene()
		return s is XMapScene and s.map_id == HUB and s.player != null and not s.busy and XState.current.self_switch(HUB, 76, "A"))
	var st := XState.current
	_check("hub_reached", reached, [st.map_id])
	_check("hub_slot_kept", st.fixed_save_slot() == NEW_SLOT and str(st.flags.get("tianqi", {}).get("difficulty", "")) == key,
		[st.fixed_save_slot(), st.flags.get("tianqi"), key])
	if not reached:
		return
	var map := _scene() as XMapScene
	# 大厅偶尔冒出说明对话（地图 busy，Esc 会被吞）：先按确定翻掉
	for i in 8:
		if not map.busy:
			break
		await _key(KEY_ENTER)
		await _wait(func(): return not map.busy, 120)
	await _key(KEY_ESCAPE)
	var opened := await _wait(func(): return map._menu_open, 300)
	_check("hub_esc_opens_menu", opened)
	await _frames(6)
	await _key(KEY_ESCAPE)
	var closed := await _wait(func(): return not map._menu_open, 300)
	_check("hub_esc_closes_menu", closed)
	await _frames(6)


## 原版图片指令标题（XTianqiTitle.ENABLED = false）：同样不设 _back，取消键不换页、返回键提示再按一次退出；确认键照旧进选格页，选格页 Esc 回到这个标题
func _picture_title_untouched() -> void:
	var en := XTianqiTitle.ENABLED
	XTianqiTitle.ENABLED = false
	var entry = await _title()
	var layer = entry._layer
	_check("picture_title_shown", entry._tq_title == null and not entry._commands.is_empty() and not entry._back.is_valid(), entry._commands.size())
	for m in ["esc", "x", "action"]:
		await _cancel(m)
		_check("picture_title_" + m + "_stays", _on_title() and entry._layer == layer and _find("TianqiSlot1") == null)
	await _cancel("back")
	_check("picture_title_back_hints", _last_back == "hint" and _on_title() and entry._layer == layer, _last_back)
	await _open_slots(entry)
	_check("picture_title_accept_opens_slots", _on_slots())
	await _cancel("esc")
	_check("picture_title_slots_back", _on_title() and entry._tq_title == null and not entry._commands.is_empty())
	XTianqiTitle.ENABLED = en


## 顺手的四个窗口页：Esc＝点「取消／返回」回标题
func _side_pages() -> void:
	var entry = await _title()
	var pages := {
		"export": func(): entry._export_save(),
		"import_slot": func(): entry._choose_import_slot({}),
		"notice": func(): entry._notice("导入存档", "测试"),
		"auto_confirm": func(): entry._confirm_auto(),
	}
	for k in pages:
		pages[k].call()
		await _frames(2)
		var b := _find("WindowBack") as Button
		_check("side_" + k + "_has_back", b != null and entry._back.is_valid() and not _on_title())
		await _cancel("esc")
		_check("side_" + k + "_esc_to_title", _on_title() and not entry._back.is_valid())
