extends Node
## 正式入口（BI）：发行构建直达西游标题、调试构建保留入口菜单、回退开关、发行标题不放「返回版本选择」。
## 调试构建里用 ReleaseEntry.simulate_release 模拟发行分支；真正的发行包由 07_开发环境/发行入口冒烟.py 在包内确认。
## 标题只看独立空存档命名空间，不读写玩家存档。

const MENU := "res://scenes/entry_menu.tscn"
const TITLE := "res://modes/xiyou/entry.tscn"
var results: Array = []

func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)

func _check(name: String, ok: bool) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL " + name)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _scene() -> String:
	return get_tree().current_scene.scene_file_path if get_tree().current_scene else ""

func _find(name: String) -> Node:
	return get_tree().current_scene.find_child(name, true, false) if get_tree().current_scene else null

func _has_label(text: String) -> bool:
	for n in get_tree().current_scene.find_children("*", "Label", true, false):
		if (n as Label).text == text:
			return true
	return false

func _run() -> void:
	XSave.dir_override = "user://test_entry_release/" + str(Time.get_ticks_usec())
	# 调试构建：照旧先到入口菜单
	_check("debug_build_is_not_release", OS.is_debug_build() and not ReleaseEntry.is_release())
	_check("debug_build_keeps_menu", not ReleaseEntry.skips_menu())
	get_tree().change_scene_to_file(MENU)
	await _frames(4)
	_check("debug_menu_shown", _scene() == MENU and _find("XiyouEntry") != null)
	# 发行分支：入口菜单立即转去西游标题
	ReleaseEntry.simulate_release = true
	_check("release_skips_menu", ReleaseEntry.skips_menu())
	get_tree().change_scene_to_file(MENU)
	await _frames(6)
	_check("release_lands_on_title", _scene() == TITLE)
	_check("release_mode_is_xiyou", GameApp.current_mode == "xiyou" and GameApp.save_directory() == "user://modes/xiyou")
	_check("release_no_mode_cards", _find("XiyouEntry") == null and _find("NewEntry") == null)
	if XDB.available():
		_check("release_title_has_no_version_select", _find("ReturnToMenu") == null)
		_check("release_title_shows_app_name", _has_label(ReleaseEntry.APP_NAME))
		# 安卓返回键：发行包的西游标题页是顶层（XPlatform 两秒内按两次退出，cc BH 续）
		_check("release_title_is_back_top_level", get_tree().current_scene.is_title_page() and GameApp.platform.is_top_level())
	# 发行分支下 return_to_menu 回到标题，不回模式选择
	GameApp.return_to_menu()
	await _frames(6)
	_check("release_return_goes_to_title", _scene() == TITLE and GameApp.current_mode == "xiyou")
	# 回退开关：发行构建也显示入口菜单
	ReleaseEntry.direct_title = false
	_check("rollback_keeps_menu", not ReleaseEntry.skips_menu())
	get_tree().change_scene_to_file(MENU)
	await _frames(6)
	_check("rollback_menu_shown", _scene() == MENU and _find("XiyouEntry") != null)
	ReleaseEntry.direct_title = true
	ReleaseEntry.simulate_release = false
	# 调试构建标题仍有「返回版本选择」
	GameApp.enter_mode("xiyou")
	await _frames(6)
	if XDB.available():
		_check("debug_title_keeps_version_select", _find("ReturnToMenu") != null)
	_check("app_name", ReleaseEntry.APP_NAME == "再刷一把：天启篇")
	_check("no_user_saves_written", not DirAccess.dir_exists_absolute(XSave.dir()))
	var passed := results.filter(func(r): return r["passed"]).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
