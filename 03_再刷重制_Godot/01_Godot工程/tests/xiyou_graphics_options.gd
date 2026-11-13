extends Node
## 画质设置（XGraphics、XGraphicsOptionsScene；设计见 00_设计/画质设置.md）：
## - 默认不干预：没存过时四项都是默认档，apply 后缩放方式、整数倍、帧率上限都与原先一样；
## - 存盘：改了写进配置、重读还在；坏值按默认补；
## - 整数倍缩放：窗口放得下才生效，屏幕→画面换算按整倍算；
## - 帧率上限、省电模式（30 帧、画面平滑当作开、画面特效当作关，不改那几项存的值）；
## - 固定窗口大小居中、放不下等比收小；
## - 设置页多一行「画质设置」，子页确定换档、左右走档到头不动，窗口大小只在桌面列；
## - 回退：ENABLED = false 时不列、apply 不碰、画面特效只看自己的开关。
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


func _run() -> void:
	TestEnv.isolate("xiyou_graphics_options")
	var root := get_tree().root
	var mode0 := root.content_scale_mode
	var fps0 := Engine.max_fps
	XPlatform.force_mobile = false
	XGraphics.HEADLESS_APPLY = true
	XConfig.set_flag(XScreenScale.KEY, false)

	# ---- 默认不干预 ----
	check("defaults", XGraphics.settings() == XGraphics.DEFAULTS, XGraphics.settings())
	XGraphics.apply(get_tree())
	check("default_canvas", root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, root.content_scale_mode)
	check("default_fractional", root.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_FRACTIONAL)
	check("default_fps", Engine.max_fps == 0 and XGraphics.fps_cap() == 0, Engine.max_fps)
	check("default_fx", XGraphics.fx_on() == XConfig.flag("codexScreenFx"))

	# ---- 坏值校正 ----
	var bad := XGraphics.sanitize({"integer": "yes", "fps": 45, "window": "800x600", "low": 1})
	check("sanitize_bad", bad == XGraphics.DEFAULTS, bad)
	check("sanitize_not_dict", XGraphics.sanitize(null) == XGraphics.DEFAULTS and XGraphics.sanitize([1]) == XGraphics.DEFAULTS)
	var good := XGraphics.sanitize({"integer": true, "fps": 30.0, "window": "full", "low": true})
	check("sanitize_good", good == {"integer": true, "fps": 30, "window": "full", "low": true}, good)
	check("set_wrong_type", not XGraphics.set_value("fps", "60") and not XGraphics.set_value("nope", true))
	check("set_flag_refused", not XConfig.set_flag(XGraphics.KEY, true) and XGraphics.settings() == XGraphics.DEFAULTS)

	# ---- 帧率上限＋存盘 ----
	check("fps_set", XGraphics.set_value("fps", 60) and Engine.max_fps == 60, Engine.max_fps)
	check("fps_same", not XGraphics.set_value("fps", 60))
	_reload()
	check("fps_saved", XGraphics.settings()["fps"] == 60, XGraphics.settings())
	var raw = JSON.parse_string(FileAccess.get_file_as_string(XConfig.path()))
	check("file_has_key", raw is Dictionary and raw.get(XGraphics.KEY) is Dictionary and int(raw[XGraphics.KEY]["fps"]) == 60, raw.get(XGraphics.KEY) if raw is Dictionary else raw)

	# ---- 省电模式：覆盖生效值，不改存的值 ----
	XConfig.set_flag("codexScreenFx", true)
	XGraphics.set_value("low", true)
	check("low_fps", Engine.max_fps == 30 and XGraphics.fps_cap() == 30, Engine.max_fps)
	check("low_smooth", root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT and not XConfig.flag(XScreenScale.KEY))
	check("low_fx_off", not XGraphics.fx_on() and XConfig.flag("codexScreenFx"))
	check("low_fx_lobby", not XLobbyCorruption.fx_on())
	XGraphics.set_value("low", false)
	check("low_off_restores", Engine.max_fps == 60 and root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and XGraphics.fx_on(),
		[Engine.max_fps, root.content_scale_mode])
	check("low_keeps_lower", XGraphics.fps_cap({"integer": false, "fps": 30, "window": "auto", "low": true}) == 30
		and XGraphics.fps_cap({"integer": false, "fps": 0, "window": "auto", "low": true}) == 30)
	XGraphics.set_value("fps", 0)

	# ---- 整数倍缩放 ----
	var w := Window.new()
	w.visible = false
	w.size = Vector2i(1920, 1200)
	w.content_scale_size = Vector2i(1280, 720)
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	add_child(w)
	await frames(1)
	check("factor_1", XGraphics.integer_factor(w) == 1, XGraphics.integer_factor(w))
	XGraphics._apply_integer(w, {"integer": true})
	check("integer_on", w.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER)
	# 1920×1200 里按 1 倍画：画面 1280×720 居中，左右各 320、上下各 240 黑边
	var p := XScreenScale.screen_to_view(w) * Vector2(960, 600)
	check("integer_view_center", p.distance_to(Vector2(640, 360)) < 0.5, p)
	p = XScreenScale.screen_to_view(w) * Vector2(320, 240)
	check("integer_view_corner", p.distance_to(Vector2.ZERO) < 0.5, p)
	w.size = Vector2i(2880, 1800)
	check("factor_2", XGraphics.integer_factor(w) == 2, XGraphics.integer_factor(w))
	p = XScreenScale.screen_to_view(w) * Vector2(160, 180)
	check("integer_view_2x", p.distance_to(Vector2.ZERO) < 0.5, p)
	# 比 1280×720 小：不生效（否则画面被裁）
	w.size = Vector2i(1024, 600)
	XGraphics._apply_integer(w, {"integer": true})
	check("integer_small_off", XGraphics.integer_factor(w) == 0 and w.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_FRACTIONAL)
	XGraphics._apply_integer(w, {"integer": false})
	check("integer_off", w.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_FRACTIONAL)
	w.queue_free()
	XGraphics.set_value("integer", true)
	check("integer_root", (root.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER) == (XGraphics.integer_factor(root) >= 1),
		[root.size, root.content_scale_stretch])
	check("resize_hooked", root.size_changed.is_connected(XGraphics._resized))
	XGraphics.set_value("integer", false)
	check("integer_root_off", root.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_FRACTIONAL)

	# ---- 固定窗口大小 ----
	var rc := XGraphics.window_rect("1600x900", Rect2i(0, 25, 1920, 1055))
	check("window_center", rc == Rect2i(160, 102, 1600, 900), rc)
	rc = XGraphics.window_rect("1920x1080", Rect2i(0, 0, 1280, 800))
	check("window_shrink", rc.size == Vector2i(1280, 720) and rc.position == Vector2i(0, 40), rc)
	check("window_bad", XGraphics.window_rect("auto", Rect2i(0, 0, 1280, 800)).size == Vector2i.ZERO)
	check("window_saved", XGraphics.set_value("window", "full") and XGraphics.settings()["window"] == "full")
	XGraphics.set_value("window", "auto")

	# ---- 设置页与子页 ----
	XState.current = XState.new_game(3, 1, [8, 9, 10])
	var opt := XOptionsScene.new()
	add_child(opt)
	await frames(2)
	var syms := opt.symbols()
	check("options_row", syms.has(XGraphics.KEY) and syms.find(XGraphics.KEY) == syms.find(XScreenScale.KEY) + 1, syms.slice(-3))
	opt.index = syms.find(XGraphics.KEY)
	check("options_status", opt.status_text(opt.index) == "调整")
	opt.ok()
	await frames(2)
	var page := opt._page as XGraphicsOptionsScene
	check("page_open", page != null)
	check("page_rows_desktop", page.keys() == ["integer", "fps", "window", "low"], page.keys())
	check("page_status_default", page.status_text(0) == "关" and page.status_text(1) == "跟随屏幕" and page.status_text(2) == "自动" and page.status_text(3) == "关",
		[page.status_text(0), page.status_text(1), page.status_text(2), page.status_text(3)])
	page.index = 1
	page.ok()
	check("page_ok_cycles", XGraphics.settings()["fps"] == 60 and page.status_text(1) == "60 帧", page.status_text(1))
	page.side(true)
	page.side(true)
	check("page_right_stops", XGraphics.settings()["fps"] == 30)
	page.ok()
	check("page_ok_wraps", XGraphics.settings()["fps"] == 0)
	page.side(false)
	check("page_left_stops", XGraphics.settings()["fps"] == 0)
	page.index = 3
	page.side(true)
	check("page_low_on", XGraphics.settings()["low"] and page.status_text(3) == "开")
	page.side(true)
	check("page_low_stays", XGraphics.settings()["low"])
	# 省电模式开着时，在设置页关「画面平滑」不会把缩放切回去
	opt._set_flag(XScreenScale.KEY, true)
	opt._set_flag(XScreenScale.KEY, false)
	check("low_keeps_viewport", root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT, root.content_scale_mode)
	page.side(false)
	check("page_low_off", not XGraphics.settings()["low"] and root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	page.index = 0
	page.ok()
	check("page_integer_status", page.status_text(0).begins_with("开"), page.status_text(0))
	page.ok()
	page.cancel()
	await frames(2)
	check("page_closed", opt._page == null)
	opt.queue_free()
	await frames(1)
	# 手机：不列窗口大小
	XPlatform.force_mobile = true
	check("page_rows_mobile", XGraphicsOptionsScene.rows().map(func(x): return x[0]) == ["integer", "fps", "low"])
	XPlatform.force_mobile = false

	# ---- 回退开关 ----
	XGraphics.set_value("low", true)
	XGraphics.set_value("integer", true)
	XGraphics.ENABLED = false
	Engine.max_fps = 0
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	XGraphics.apply(get_tree())
	check("disabled_untouched", Engine.max_fps == 0 and root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		and root.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_FRACTIONAL)
	check("disabled_fx", XGraphics.fx_on() and not XGraphics.low_power())
	var opt2 := XOptionsScene.new()
	add_child(opt2)
	await frames(2)
	check("disabled_no_row", not opt2.symbols().has(XGraphics.KEY), opt2.symbols().slice(-3))
	opt2.queue_free()
	XGraphics.ENABLED = true
	XGraphics.set_value("low", false)
	XGraphics.set_value("integer", false)

	XGraphics.HEADLESS_APPLY = false
	XPlatform.force_mobile = null
	Engine.max_fps = fps0
	root.content_scale_mode = mode0
	await frames(1)
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
