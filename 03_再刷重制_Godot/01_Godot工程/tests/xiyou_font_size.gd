extends Node
## 字体大小、弹窗字号（XFontScale；设置在「画质设置」子页，存 codexFontSize）：
## - 默认 100＝原版：MV 画布、逐字排版、主题、提示框的字号都不变；
## - 坏值按默认、存盘重读还在、不进 codexQuality、set_flag 改不了；
## - 全局放大：XMVCanvas.text_width、XMVText 字宽、XUI.theme／label 跟着放大，弹窗不跟；
## - 弹窗放大：提示框字号、行高放大，框宽最多 1.5 倍，全局不跟；
## - 设置子页：两行在最后（手机、电脑都列），确定换档、左右走档到头不动、改弹窗字号弹示例、点行可选可调；
## - 回退：ENABLED = false 时恒按原版、子页不列。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _reload() -> void:
	XConfig._loaded_path = "<unloaded>"


## 最近一条提示框里 Label 的字号
func _last_toast_size() -> int:
	var layer := get_tree().root.get_node_or_null("XToast") as XToast
	if layer == null or layer.stack.get_child_count() == 0:
		return -1
	var slot := layer.stack.get_child(layer.stack.get_child_count() - 1)
	var label := slot.get_child(0).get_child(0) as Label
	return label.get_theme_font_size("font_size")


func _run() -> void:
	TestEnv.isolate("xiyou_font_size")
	XPlatform.force_mobile = false
	var font := XUI.font()
	var s := "肝帝积分+1"

	# ---- 默认＝原版 ----
	check("defaults", XFontScale.percent("global") == 100 and XFontScale.percent("toast") == 100)
	check("size_default", XFontScale.size(26) == 26 and XFontScale.size(18) == 18)
	var canvas := XMVCanvas.new()
	var w26 := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	check("canvas_default", canvas.text_width(s) == w26, [canvas.text_width(s), w26])
	check("mvtext_default", XMVText.new(s).text_width("肝") == font.get_string_size("肝", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x)
	check("theme_default", XUI.theme().default_font_size == XUI.FONT_SIZE)
	check("toast_default", XToast.metrics() == [XToast.FONT_SIZE, XToast.LINE_HEIGHT, XToast.WIDTH], XToast.metrics())
	XToast.show_text("默认提示", true)
	check("toast_default_label", _last_toast_size() == 18, _last_toast_size())

	# ---- 坏值、存盘 ----
	check("sanitize_bad", XFontScale.sanitize({"global": 115, "toast": "150"}) == XFontScale.DEFAULTS)
	check("sanitize_null", XFontScale.sanitize(null) == XFontScale.DEFAULTS)
	check("sanitize_float", XFontScale.sanitize({"global": 120.0, "toast": 200}) == {"global": 120, "toast": 200})
	check("set_bad", not XFontScale.set_value("global", 115) and not XFontScale.set_value("nope", 110))
	check("set_flag_refused", not XConfig.set_flag(XFontScale.KEY, true))
	check("set_global", XFontScale.set_value("global", 130))
	check("set_same", not XFontScale.set_value("global", 130))
	check("set_toast", XFontScale.set_value("toast", 150))
	_reload()
	check("saved", XFontScale.percent("global") == 130 and XFontScale.percent("toast") == 150)
	var raw = JSON.parse_string(FileAccess.get_file_as_string(XConfig.path()))
	check("file_key", raw is Dictionary and raw.get(XFontScale.KEY) is Dictionary and int(raw[XFontScale.KEY]["global"]) == 130
		and not (raw.get(XGraphics.KEY) as Dictionary).has("global"), raw.get(XFontScale.KEY) if raw is Dictionary else raw)

	# ---- 全局放大 ----
	check("size_130", XFontScale.size(26) == 34 and XFontScale.size(20) == 26, XFontScale.size(26))
	check("canvas_scaled", canvas.text_width(s) == font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x)
	check("mvtext_scaled", XMVText.new(s).text_width("肝") == font.get_string_size("肝", HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x)
	var mt := XMVText.new(s)
	mt.run()
	check("mvtext_glyph_raw_size", mt.glyphs[0].size == 26)  # 画布画时再放大，不重复放
	var lb := XUI.label("x")
	check("theme_scaled", XUI.theme().default_font_size == 34 and lb.get_theme_font_size("font_size") == 34)
	lb.free()
	# 弹窗不跟全局
	XFontScale.set_value("toast", 100)
	check("toast_ignores_global", XToast.metrics()[0] == 18)
	canvas.free()

	# ---- 弹窗放大，全局不跟 ----
	XFontScale.set_value("global", 100)
	XFontScale.set_value("toast", 200)
	check("toast_200", XToast.metrics() == [36, 42, XToast.WIDTH * 1.5], XToast.metrics())
	XToast.show_text("放大提示", true)
	check("toast_200_label", _last_toast_size() == 36, _last_toast_size())
	check("global_ignores_toast", XFontScale.size(26) == 26)
	XFontScale.set_value("toast", 100)

	# ---- 设置子页 ----
	XState.current = XState.new_game(3, 1, [8, 9, 10])
	var page := XGraphicsOptionsScene.new()
	add_child(page)
	await frames(2)
	var keys := page.keys()
	check("rows_desktop", keys.slice(-2) == ["font", "toast"], keys)
	var fi: int = keys.find("font")
	var ti: int = keys.find("toast")
	check("status_default", page.status_text(fi) == "100%" and page.status_text(ti) == "100%", [page.status_text(fi), page.status_text(ti)])
	page.index = fi
	page.ok()
	check("page_ok", XFontScale.percent("global") == 110 and page.status_text(fi) == "110%")
	page.side(true)
	page.side(true)
	page.side(true)
	check("page_right_stops", XFontScale.percent("global") == 130)
	page.ok()
	check("page_ok_wraps", XFontScale.percent("global") == 100)
	page.side(false)
	check("page_left_stops", XFontScale.percent("global") == 100)
	# 点行：先选中，再点一次换档（手机点按同走这里）
	var rect: Rect2 = page.list_rect()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = rect.position + Vector2(XMVWindow.PADDING + 20, XMVWindow.PADDING + ti * XGraphicsOptionsScene.LH + 10)
	page._gui_input(click)
	check("tap_select", page.index == ti)
	var n0 := XToast.shown.size()
	page._gui_input(click)
	check("tap_change", XFontScale.percent("toast") == 125, XFontScale.percent("toast"))
	check("toast_sample", XToast.shown.size() == n0 + 1 and XToast.shown[-1] == XGraphicsOptionsScene.TOAST_SAMPLE)
	check("toast_sample_size", _last_toast_size() == 23, _last_toast_size())
	page.queue_free()
	await frames(1)
	XPlatform.force_mobile = true
	check("rows_mobile", XGraphicsOptionsScene.rows().map(func(x): return x[0]).slice(-2) == ["font", "toast"])
	XPlatform.force_mobile = false

	# ---- 回退开关 ----
	XFontScale.set_value("global", 120)
	XFontScale.ENABLED = false
	check("disabled_size", XFontScale.size(26) == 26 and XToast.metrics()[0] == 18)
	check("disabled_rows", not XGraphicsOptionsScene.rows().any(func(x): return x[0] == "font" or x[0] == "toast"))
	XFontScale.ENABLED = true
	XFontScale.set_value("global", 100)
	XFontScale.set_value("toast", 100)

	XPlatform.force_mobile = null
	var layer := get_tree().root.get_node_or_null("XToast")
	if layer != null:
		layer.queue_free()
	await frames(2)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
