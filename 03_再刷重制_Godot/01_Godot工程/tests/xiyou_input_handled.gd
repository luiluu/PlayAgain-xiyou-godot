extends Node
## 按键标已处理不闪退（O-212，11-06）：标题按空格/J 开新游戏，change_scene 立刻把标题摘下树，
## 原来的 get_viewport().set_input_as_handled() 对 null 调用——调试版报错，发行版空指针闪退。
## 现在统一走 XKeyMap.handled(self)：不在树上就跳过。回退开关 XKeyMap.SAFE_HANDLED。
## 测试里按的是「返回版本选择」（同一条路径）。标题只用独立空存档目录，不读写玩家存档。

const TITLE := "res://modes/xiyou/entry.tscn"
var results: Array = []
var _log := ErrorLog.new()


class ErrorLog extends Logger:
	var errors: Array = []
	var _m := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		_m.lock()
		errors.append("%s %s:%d %s %s" % [function, file, line, code, rationale])
		_m.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take(needle: String) -> Array:
		_m.lock()
		var hit := errors.filter(func(e): return needle in e)
		errors.clear()
		_m.unlock()
		return hit


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _scene() -> String:
	return get_tree().current_scene.scene_file_path if get_tree().current_scene else ""


func _key(code: Key, pressed: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	return e


## 源码里不再有直接写法（新加的页面也要走 XKeyMap.handled）
func _direct_calls(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var p := dir.path_join(f)
			if "get_viewport().set_input_as_handled()" in FileAccess.get_file_as_string(p):
				out.append(p)
	for d in DirAccess.get_directories_at(dir):
		if d != "tests" and not d.begins_with("."):
			_direct_calls(dir.path_join(d), out)


func _run() -> void:
	OS.add_logger(_log)
	XSave.dir_override = "user://test_input_handled/" + str(Time.get_ticks_usec())
	var direct: Array = []
	_direct_calls("res://", direct)
	_check("no_direct_set_input_as_handled", direct.is_empty(), direct)
	# 不在树上的节点：跳过，不报错
	var orphan := Node.new()
	XKeyMap.handled(orphan)
	_check("orphan_no_error", _log.take("set_input_as_handled").is_empty())
	orphan.free()
	# 在树上：照常标已处理（不报错）
	XKeyMap.handled(self)
	_check("in_tree_no_error", _log.take("").is_empty())
	# 回退开关：照旧直接调用（不在树上会对 null 调用，这里不去触发；只确认在树上照常）
	XKeyMap.SAFE_HANDLED = false
	XKeyMap.handled(self)
	_check("rollback_in_tree_no_error", _log.take("").is_empty())
	XKeyMap.SAFE_HANDLED = true
	if XDB.available():
		var tq_title := XTianqiTitle.ENABLED
		XTianqiTitle.ENABLED = false  # 本段测原版标题图片指令的按键处理；新标题的按键由 xiyou_tianqi_title 测
		for code in [KEY_SPACE, KEY_J]:
			GameApp.enter_mode("xiyou")
			await _frames(6)
			_check("title_shown_%d" % code, _scene() == TITLE)
			# 选「返回版本选择」：和「新的游戏」一样在按键处理里 change_scene（新游戏会挂着开局事件，退出时算泄漏，这里不用它）
			var title = get_tree().current_scene
			title._select(title._commands.size() - 1)
			_log.take("")
			Input.parse_input_event(_key(code, true))
			Input.flush_buffered_events()
			await _frames(2)
			Input.parse_input_event(_key(code, false))
			Input.flush_buffered_events()
			await _frames(6)
			_check("accept_left_title_%d" % code, _scene() == "res://scenes/entry_menu.tscn", _scene())
			var hit := _log.take("set_input_as_handled")
			_check("accept_no_null_viewport_%d" % code, hit.is_empty(), hit)
		XTianqiTitle.ENABLED = tq_title
	OS.remove_logger(_log)
	_log = null
	var passed := results.filter(func(r): return r["passed"]).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
