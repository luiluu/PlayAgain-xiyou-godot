extends Node
## T621 专项（Kyo 11-28「装备检索显示不全还不能滑动」）：西游档装备词条检索的下拉（分类、部位、品质、位置、指定词条、排序）
## 超高时放进可见区域、能滚。桌面 OptionButton 菜单限高到窗口内、超出用菜单自带滚动条；触屏每个下拉都是可拖动列表、限高、拖得动。
## XGearSearch.XIYOU_SELECT_FIT 关掉＝回到 T409（只指定词条可拖、菜单不限高）。
## 给 --out=<目录> 且有窗口时在 1920×864（手机横屏比例）与 1280×720（电脑）各拍部位下拉展开图。
var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	print(("PASS " if ok else "FAIL ") + name + ("" if ok else " " + JSON.stringify(detail)))


func frames(n := 6) -> void:
	for i in range(n):
		await get_tree().process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await frames(4)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _win(w: int, h: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var win := get_window()
	win.unresizable = false
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.size = Vector2i(w, h)
	DisplayServer.window_set_size(Vector2i(w, h))
	await get_tree().create_timer(0.6).timeout
	await frames(12)


## 40 个部位选项（安卓截图里的部位有 30 来种），排在 y＝200 一行（同截图「部位」那一行）
func _values() -> Array:
	var v := [["", "全部装备"]]
	for i in range(40):
		v.append(["t%d" % i, "部位 · 第%d种" % (i + 1)])
	return v


func _field(panel: XGearSearch, y: float, picked: Array) -> Control:
	var box := panel._select("部位", _values(), "", func(v): picked.append(v))
	box.position = Vector2(240, y)
	panel.add_child(box)
	return box


func _desktop(panel: XGearSearch, y: float, tag: String) -> void:
	var picked := []
	var box := _field(panel, y, picked)
	await frames()
	var option := box.get_child(1) as OptionButton
	check(tag + "_desktop_is_option", option != null)
	if option == null:
		box.queue_free()
		return
	option.show_popup()
	await frames()
	var popup := option.get_popup()
	var view := get_viewport().get_visible_rect().size
	var rect := Rect2(Vector2(popup.position), Vector2(popup.size))
	var inside := rect.position.y >= -0.5 and rect.end.y <= view.y + 0.5
	var full := popup.get_contents_minimum_size().y
	check(tag + "_desktop_popup_inside_window", popup.visible and inside, [rect, view])
	check(tag + "_desktop_popup_scrolls", popup.size.y < full, [popup.size, full])
	await shot("t621_%s_desktop" % tag)
	popup.hide()
	box.queue_free()
	await frames()


func _touch(panel: XGearSearch, y: float, tag: String) -> void:
	var picked := []
	var box := _field(panel, y, picked)
	await frames()
	var button := box.get_child(1) as Button
	var popups := button.find_children("*", "PopupPanel", true, false)
	check(tag + "_touch_is_drag_list", not (button is OptionButton) and popups.size() == 1)
	if popups.is_empty():
		box.queue_free()
		return
	var popup := popups[0] as PopupPanel
	var list := popup.get_child(0) as XSkinList
	button.pressed.emit()
	await frames()
	var view := get_viewport().get_visible_rect().size
	var rect := Rect2(Vector2(popup.position), Vector2(popup.size))
	check(tag + "_touch_popup_inside_window", popup.visible and rect.position.y >= -0.5 and rect.end.y <= view.y + 0.5, [rect, view])
	check(tag + "_touch_scrollable", list.scrollable(), [list.size, list.rows_total()])
	# 触屏拖动：往上拖 170 像素，列表往下滚、不选中
	var start := Vector2(120, minf(220, list.size.y - 10))
	var end := start - Vector2(0, 170)
	_click(popup, start, true)
	var drag := InputEventMouseMotion.new()
	drag.device = InputEvent.DEVICE_ID_EMULATION
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.position = end
	drag.relative = end - start
	popup.push_input(drag, true)
	_click(popup, end, false)
	await frames()
	check(tag + "_touch_drag_scrolls", list.top_row > 0 and picked.is_empty() and popup.visible, [list.top_row, picked])
	await shot("t621_%s_touch" % tag)
	popup.hide()
	box.queue_free()
	await frames()


func _click(popup: PopupPanel, pos: Vector2, pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.device = InputEvent.DEVICE_ID_EMULATION
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = pos
	click.pressed = pressed
	popup.push_input(click, true)


func _run() -> void:
	print("T621 XTestMode.enabled=", XTestMode.enabled())   # 本机测试模式开着，先记一笔
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var original_mobile = XPlatform.force_mobile
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	XGearSearch.reset_session()
	var panel := XGearSearch.open(host, XGearQuery.collection(s))
	await frames()
	for size in [[1920, 864, "phone"], [1280, 720, "pc"]]:
		await _win(size[0], size[1])
		var view := get_viewport().get_visible_rect().size
		XPlatform.force_mobile = false
		await _desktop(panel, 200.0, str(size[2]) + "_mid")
		await _desktop(panel, view.y - 80.0, str(size[2]) + "_low")   # 按钮靠底：翻到上面
		XPlatform.force_mobile = true
		await _touch(panel, 200.0, str(size[2]) + "_mid")
		await _touch(panel, view.y - 80.0, str(size[2]) + "_low")
	# 回退开关：关掉后触屏部位回到 OptionButton（T409 只指定词条可拖）
	XGearSearch.XIYOU_SELECT_FIT = false
	var box := _field(panel, 200.0, [])
	check("switch_off_touch_option", box.get_child(1) is OptionButton)
	box.queue_free()
	XGearSearch.XIYOU_SELECT_FIT = true
	# 天启篇不走：启封档的下拉照旧（这里只核开关条件不误伤 OptionButton 路径）
	XPlatform.force_mobile = original_mobile
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
