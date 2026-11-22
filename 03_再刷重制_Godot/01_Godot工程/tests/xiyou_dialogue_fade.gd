extends Node
## T330 剧情对白逐字渐显：错开／淡入的公式、只在新皮肤开、按确认先显示全句再翻页、开关与跳过项关掉就不演、回退后行为同旧。

var results := []
var box: XMessageBox


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _phys(n := 1) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	get_viewport().push_input(e)
	await _phys()
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	get_viewport().push_input(r)


func _until(cond: Callable, n := 600) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await _phys()
	return false


func _wait_pause() -> void:
	await _until(func(): return box.win.pause and box._wait == 0)


func _say(text: String) -> Dictionary:
	await _until(func(): return not box.is_busy(), 300)
	await _phys(2)
	var r := {"value": null}
	var t := func(): r.value = await box.run({"lines": [text]})
	t.call()
	await _until(func(): return box.win.is_open() and not box._page_glyphs.is_empty())
	return r


func _run() -> void:
	XConfig.path_override = "user://t330_fade_options.json"
	XMessageBox.auto = false
	XState.new_game(3, 1, [])
	var bg := ColorRect.new()
	bg.size = Vector2(1280, 720)
	add_child(bg)
	box = XMessageBox.new()
	add_child(box)
	await _phys()

	# 公式
	_check("stagger_38ms", is_equal_approx(XSkinDialogueFade.total_ms(11) - XSkinDialogueFade.total_ms(10), 38.0))
	_check("adjacent_offset_tens_of_ms", XSkinDialogueFade.STAGGER_MS >= 20.0 and XSkinDialogueFade.STAGGER_MS <= 80.0)
	_check("progress_0_before_start", XSkinDialogueFade.progress(5, 5.0 * 38.0 - 1.0) == 0.0)
	_check("progress_1_after_fade", XSkinDialogueFade.progress(0, 240.0) == 1.0)
	_check("progress_monotonic", XSkinDialogueFade.progress(0, 60.0) < XSkinDialogueFade.progress(0, 120.0))
	_check("total_empty_0", XSkinDialogueFade.total_ms(0) == 0.0)

	# 旧皮肤（西游档）不演
	XUiSkin.FORCE = false
	var r0 := await _say("西游档对白，不演渐显。")
	_check("old_skin_no_fade", box._fade_start_ms == -1 and not XSkinDialogueFade.on(), box._fade_start_ms)
	await _wait_pause()
	await _press("ui_accept")
	await _until(func(): return r0.value != null, 60)
	_check("old_skin_one_press_advances", r0.value == 0)
	await _phys(20)

	# 新皮肤：演；按确认先显示全句不翻页，再按才翻
	XUiSkin.FORCE = true
	var r1 := await _say("这是一句用来测试逐字渐显的天启篇对白，字数要够多才演得久。")
	_check("fade_on_in_skin", XSkinDialogueFade.on() and box._fade_start_ms >= 0 and box._fade_running(), box._fade_start_ms)
	await _wait_pause()
	_check("pause_while_fading", box.win.pause and box._fade_running())
	await _press("ui_accept")
	await _phys(3)
	_check("first_press_shows_all", box._fade_start_ms == -1 and r1.value == null and box.win.pause, [box._fade_start_ms, r1.value])
	await _press("ui_accept")
	await _until(func(): return r1.value != null, 60)
	_check("second_press_advances", r1.value == 0, r1.value)
	await _phys(20)

	# 自然演完后一次确认就翻页
	var r2 := await _say("短句。")
	await _until(func(): return not box._fade_running(), 120)
	_check("fade_ends_naturally", not box._fade_running())
	await _wait_pause()
	await _press("ui_accept")
	await _until(func(): return r2.value != null, 60)
	_check("after_fade_one_press_advances", r2.value == 0)
	await _phys(20)

	# 「对话跳过」设置：整页不演
	XConfig.set_session("dhtg", true)
	var r3 := await _say("对话跳过开着不演。")
	_check("skip_setting_no_fade", box._fade_start_ms == -1, box._fade_start_ms)
	await _until(func(): return r3.value != null, 300)
	XConfig.set_session("dhtg", null)
	await _phys(20)

	# 开关关掉＝回到旧行为
	XSkinDialogueFade.ENABLED = false
	var r4 := await _say("开关关掉后不演。")
	_check("switch_off_no_fade", box._fade_start_ms == -1 and not XSkinDialogueFade.on(), box._fade_start_ms)
	await _wait_pause()
	await _press("ui_accept")
	await _until(func(): return r4.value != null, 60)
	_check("switch_off_one_press_advances", r4.value == 0)
	XSkinDialogueFade.ENABLED = true
	XUiSkin.FORCE = false

	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _ready() -> void:
	_run.call_deferred()
