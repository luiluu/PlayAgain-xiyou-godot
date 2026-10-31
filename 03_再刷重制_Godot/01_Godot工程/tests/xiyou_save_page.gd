extends Node
## 存档／读档页（XSaveScene）与正式 YEP_SaveCore 运行时读数（tests/fixtures/save_page_oracle.json）比对：窗口矩形、
## 列表行（图标、文字、空格半透明、初选最近保存的一格）、操作窗三格与可用性、信息窗（游戏名、头像、名字、等级、
## 两列数据与暗底、空格）、确认窗大小与行文、选格→操作→确认→读取/删除/取消的流程；另测保存次数（存两次是 2，
## 没有 saveCount 的旧档读出 0、再存是 1）。窗口模式加 -- --out=<目录> 存对照截图。

var results := []
var out_dir := ""
const FIXTURE := "res://tests/fixtures/save_page_oracle.json"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(2000))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


static func rect_of(w: Control) -> Array:
	return [w.position.x, w.position.y, w.size.x, w.size.y]


static func nums(a: Array) -> Array:
	return a.map(func(v): return float(v))


func _state() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.gold = 123456
	s.set_variable(20, 15)
	s.set_variable(206, 3)
	s.map_id = 4
	s.x = 10
	s.y = 10
	s.play_seconds = 19.4
	s.actor(1).change_level(10)   # 与正式读数相同（狗逍遥 Lv 10，其余 Lv 1）
	return s


func _run() -> void:
	XSave.dir_override = OS.get_user_data_dir().path_join("test_save_page_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(XSave.dir_override)
	var fx = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)) if FileAccess.file_exists(FIXTURE) else null
	if check("fixture_loaded", fx is Dictionary, FIXTURE):
		_save_count()
		var s := _state()
		XSave.save(1)
		XSave.save(3)
		await _page(fx, s)
		await _menu_load()
	_file_size_original()
	for i in range(1, XSave.SLOTS + 1):
		XSave.remove(i)
	DirAccess.remove_absolute(XSave.dir_override)
	XSave.dir_override = ""
	# 满负载下混音线程释放播放对象较慢：停掉后按真实时间再等 0.5 秒（不受 time_scale 影响；同 xiyou_orb_shop_ui）
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.5, true, false, true).timeout
	await frames(3)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _save_count() -> void:
	var s := _state()
	XSave.save(5)
	XSave.save(5)
	var d = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(5)))
	check("save_count_two", int(d.get("saveCount", -1)) == 2 and s.save_count == 2)
	d.erase("saveCount")
	var f := FileAccess.open(XSave.path(5), FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	check("save_count_legacy_zero", XSave.load_slot(5) and XState.current.save_count == 0)
	XSave.save(5)
	d = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(5)))
	check("save_count_legacy_then_one", int(d.get("saveCount", -1)) == 1)
	XSave.remove(5)
	check("remove_slot", not XSave.exists(5))


func _page(fx: Dictionary, s: XState) -> void:
	var page := XSaveScene.new()
	page.mode = "load"
	var loaded := [false]
	page.loaded.connect(func(): loaded[0] = true)
	add_child(page)
	await frames()
	var w: Dictionary = fx.windows
	check("window_rects", rect_of(page.help_win) == nums(w.help) and rect_of(page.list_win) == nums(w.list) and rect_of(page.action_win) == nums(w.action) \
		and rect_of(page.info_win) == nums(w.info), [rect_of(page.help_win), rect_of(page.list_win), rect_of(page.action_win), rect_of(page.info_win)])
	check("list_initial", page.index == int(fx.list.index_latest) and page.top == int(fx.list.top) and page.page_rows() == int(fx.list.pageRows), [page.index, page.top, page.page_rows()])
	check("help_select", page.help_text == str(fx.help.select))
	# 列表行
	var rc := RecCanvas.new()
	rc.size = page.list_win.canvas.size
	page._paint_list(rc)
	var icons: Array = rc.log.filter(func(x): return x[0] == "icon")
	var texts: Array = rc.log.filter(func(x): return x[0] == "text")
	var row: Dictionary = fx.list.row
	check("list_rows", icons.size() == 16 and icons[0].slice(1, 4) == [int(row.icon_saved), 2.0, 2.0] and icons[1][1] == int(row.icon_empty) and icons[1][4] < 1.0 \
		and texts[0].slice(1, 5) == ["文件 1", 36.0, 0.0, 180.0] and texts[1][1] == "文件 2" and texts[1][8] < 1.0, [icons.slice(0, 2), texts.slice(0, 2)])
	rc.free()
	# 操作窗
	var a: Dictionary = fx.action
	var rects := range(3).map(func(i): var r := page.action_rect(i); return [r.position.x, r.position.y, r.size.x, r.size.y])
	check("action_rects", rects == a.rects.map(func(r): return nums(r)), rects)
	page.index = 0
	check("action_enabled_valid", range(3).map(func(i): return page.action_enabled(i)) == a.load_mode_enabled_valid)
	page.index = 1
	check("action_enabled_empty", range(3).map(func(i): return page.action_enabled(i)) == a.load_mode_enabled_empty)
	# 信息窗（有档）
	page.index = 0
	rc = RecCanvas.new()
	rc.size = page.info_win.canvas.size
	page._paint_info(rc)
	check("info_contents_size", [rc.size.x, rc.size.y] == nums(fx.info.contents), rc.size)
	_info_valid(fx, page, rc)
	rc.free()
	# 信息窗（空格）
	page.index = 1
	rc = RecCanvas.new()
	rc.size = page.info_win.canvas.size
	page._paint_info(rc)
	var e: Dictionary = fx.info.empty
	var et: Array = rc.log.filter(func(x): return x[0] == "text")
	check("info_empty", page.dark_rects.size() == 1 and [page.dark_rects[0].position.x, page.dark_rects[0].position.y, page.dark_rects[0].size.x, page.dark_rects[0].size.y] == nums(e.dark_rect) \
		and et.size() == 1 and et[0][1] == str(e.text) and et[0][3] == float(e.y) and et[0][7] == XUI.SYSTEM, [page.dark_rects, et])
	rc.free()
	page.index = 2
	page._refresh()
	await shot("load_slot3")
	# 流程：选格 → 操作（读取）→ 确认 → 取消 → 删除 → 确认 → 文件没了；再读取有档的一格
	page.index = 0
	page.ok()
	check("list_ok_to_action", page._phase == "action" and page.act == 0 and page.help_text == str(fx.help.load), [page._phase, page.act, page.help_text])
	page.ok()
	var c: Dictionary = fx.confirm
	check("confirm_load", page._phase == "confirm" and page.confirm_text == str(c.load) and rect_of(page.confirm_win) == nums(c.rect), [page.confirm_text, rect_of(page.confirm_win)])
	var confirm_canvas := RecCanvas.new()
	confirm_canvas.size = page.confirm_win.canvas.size
	page._paint_confirm(confirm_canvas)
	var question: Array = confirm_canvas.log.filter(func(x): return x[0] == "text").slice(0, str(c.load).length())
	check("confirm_question_single_line", question.size() == str(c.load).length() and question.all(func(x): return x[3] == 0.0), question)
	check("confirm_masks_underlying_windows", page.confirm_back.visible and page.confirm_back.position == page.confirm_win.position and page.confirm_back.size == page.confirm_win.size)
	confirm_canvas.free()
	await shot("load_confirm")
	page.confirm_index = 1
	page.ok()
	check("confirm_no_back_to_action", page._phase == "action" and page.act == 0 and not page.confirm_win.visible)
	page.move(1)
	page.move(1)
	check("delete_help", page.act == 2 and page.help_text == str(fx.help.delete))
	page.ok()
	check("confirm_delete", page._phase == "confirm" and page.confirm_text == str(c.delete))
	page.ok()
	check("delete_done", not XSave.exists(1) and page._phase == "list" and page.help_text == str(fx.help.select), [XSave.exists(1), page._phase])
	page.index = 2
	page.ok()
	page.ok()
	page.ok()
	check("load_done", loaded[0] and XSave.current_slot == 3)
	page.queue_free()
	await frames()
	# 存档模式：操作窗停在「保存」，空格直接存、有档要确认覆盖
	var sp := XSaveScene.new()
	sp.mode = "save"
	add_child(sp)
	await frames()
	sp.index = 6
	sp.ok()
	check("save_mode_action", sp._phase == "action" and sp.act == 1 and sp.help_text == str(fx.help.save))
	sp.ok()
	check("save_empty_direct", XSave.exists(7) and sp._phase == "list")
	sp.ok()
	sp.ok()
	check("save_overwrite_confirm", sp._phase == "confirm" and sp.confirm_text == str(c.save))
	sp.queue_free()
	await frames()


class LoadMenu extends XMenu:
	var reloads := 0
	func _reload_after_load() -> void:
		reloads += 1


func _menu_load() -> void:
	check("menu_map_scene_exists", ResourceLoader.exists(XMenu.MAP_SCENE, "PackedScene"))
	var s := _state()
	s.gold = 112233
	s.map_id = 5
	XSave.save(9)
	s.gold = 7
	s.map_id = 4
	var menu := LoadMenu.new()
	add_child(menu)
	menu._show_save()
	await frames()
	var pages := menu.get_children().filter(func(n): return n is XSaveScene)
	check("menu_save_page_exists", pages.size() == 1)
	if pages.size() == 1:
		var page: XSaveScene = pages[0]
		check("save_page_mouse_handler", page.has_method("_gui_input"))
		if page.has_method("_gui_input"):
			page.index = 0
			page.top = 0
			page._refresh()
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = page.list_win.position + Vector2(30, 14 + 8 * 36 + 8)
			page.call("_gui_input", click)
			check("mouse_selects_save_slot", page.index == 8 and page._phase == "list")
			page.call("_gui_input", click)
			check("mouse_opens_save_actions", page._phase == "action" and page.act == 1)
			click.position = page.action_win.position + Vector2(30, 30)
			page.call("_gui_input", click)
			check("mouse_selects_load_action", page.act == 0 and page._phase == "action")
			page.call("_gui_input", click)
			check("mouse_opens_load_confirmation", page._phase == "confirm")
			click.position = page.confirm_win.position + Vector2(30, 14 + 36 + 8)
			page.call("_gui_input", click)
		else:
			page.index = 8
			page.ok()
			page.act = 0
			page.ok()
			page.ok()
		check("menu_load_restores_state", XState.current.gold == 112233 and XState.current.map_id == 5 and XSave.current_slot == 9)
		check("menu_load_reenters_map", menu.reloads == 1)
	menu.queue_free()
	await frames()


func _info_valid(fx: Dictionary, page: XSaveScene, rc: RecCanvas) -> void:
	var texts: Array = rc.log.filter(func(x): return x[0] == "text")
	var color := {"text": XUI.TEXT, "system": XUI.SYSTEM}
	# 逐项：[y, x, 文字, 对齐, 字号, 颜色, 宽]；数值随存档不同的几项（保存次数、游戏时间、容量）只比位置
	var loose := ["4", "00:00:19", "存档容量：505.6KB"]
	var bad := []
	for want in fx.info.valid:
		var hit := false
		for t in texts:
			var joined := str(t[1])
			if want[5] == "system" and int(want[6]) == 0:
				# drawTextEx 逐字：拼同一行同色的字
				joined = "".join(texts.filter(func(u): return u[3] == t[3] and u[7] == t[7] and u[2] >= t[2]).map(func(u): return u[1]))
			var same_text: bool = (str(want[2]) in loose and t[3] == float(want[0])) or joined.begins_with(str(want[2]))
			if same_text and absf(t[2] - float(want[1])) < 0.5 and t[3] == float(want[0]) and t[6] == int(want[4]) and t[7] == color[want[5]] \
					and (int(want[6]) == 0 or (absf(t[4] - float(want[6])) < 0.5 and t[5] == str(want[3]))):
				hit = true
				break
		if not hit:
			bad.append(want)
	check("info_texts", bad.is_empty(), [bad, texts.map(func(t): return [t[3], t[2], t[1], t[5], t[6]])])
	var faces: Array = rc.log.filter(func(x): return x[0] == "face").map(func(x): return [x[3], x[4], x[5], x[6]])
	check("info_faces", faces.size() == 4 and faces.map(func(f): return [floorf(f[0] + maxf(f[2] - 144.0, 0) / 2.0), f[1], 144.0, 144.0]) == fx.info.faces.map(func(f): return nums(f)), faces)
	var lv: Array = texts.filter(func(t): return t[3] == float(fx.info.levels.y) and t[1] == "L").map(func(t): return snappedf(t[2], 0.01))
	check("info_levels", lv.size() == 4 and lv.all(func(x): return absf(x - float(fx.info.levels.first_x[lv.find(x)])) < 3.0), lv)
	var icon: Array = rc.log.filter(func(x): return x[0] == "icon")
	check("info_var_icon", icon.size() == 1 and icon[0][1] == int(fx.info.icon_206[0]) and absf(icon[0][2] - float(fx.info.icon_206[1])) < 0.5, icon)
	var dark := page.dark_rects.map(func(r): return [r.position.x, r.position.y, r.size.x, r.size.y])
	check("info_dark_rects", dark == fx.info.dark_rects.map(func(r): return nums(r)), dark)


class RecCanvas extends XMVCanvas:
	var log := []

	func text(s: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, lh := XUI.LINE_HEIGHT, alpha := 1.0, zoom := 1.0, pivot := Vector2.ZERO, outline := OUTLINE) -> void:
		log.append(["text", s, x, y, max_w, align, size, color, alpha])

	func icon(index: int, x: float, y: float, alpha := 1.0, size := 32.0) -> void:
		log.append(["icon", index, x, y, alpha])

	func face(face_name: String, index: int, x: float, y: float, w := 144.0, h := 144.0, alpha := 1.0) -> void:
		log.append(["face", face_name, index, x, y, w, h])

	func cursor(r: Rect2, active := true) -> void:
		log.append(["cursor", r, active])


## O-042 回退（REAL_FILE_SIZE = false）：原版 drawFileSize 数的是 encodeURI 后 %XX 的个数（只算要转义的字节）。
## 内容 a b"中：实际 7 字节；要转义的是空格、引号各 1 字节和「中」3 字节，共 5
func _file_size_original() -> void:
	var f := FileAccess.open(XSave.path(XSave.SLOTS), FileAccess.WRITE)
	f.store_string('a b"中')
	f.close()
	var real := XSaveScene.file_size(XSave.SLOTS)
	XSaveScene.REAL_FILE_SIZE = false
	var orig := XSaveScene.file_size(XSave.SLOTS)
	XSaveScene.REAL_FILE_SIZE = true
	check("file_size_real", real == "7B", real)
	check("file_size_original_escape_count", orig == "5B", orig)
