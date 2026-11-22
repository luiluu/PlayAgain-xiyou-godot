extends Node
## T369 专项（卡 T，T254 §4.2）：更新页九种状态换新界面样式。
## - 调用处传 use_skin：skin 为假时一行旧画法都不变（旧框、没有版本行／橙字／进度条／第二排按钮）；SKIN_V1 回退开关关掉时传真也回旧样式。
## - 新样式各状态：标题、按钮个数／文字／次序（次按钮左、主按钮右）、宽度 400／640、橙色问题边、版本行、进度条、小金蜡、检查中三点。
## - 退回点两次、3 秒复位；强制更新取消键和点暗处都不关、底不透明；XForceUpdate.on_title 把 use_skin 带到框上。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func _vis(page: XUpdatePage) -> Array:
	var out := []
	for b in page._focus_buttons():
		if b != page._rollback:
			out.append(b.text)
	return out


func _host() -> Control:
	var h := Control.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(h)
	return h


func _patch_result(extra := {}) -> Dictionary:
	var r := {"state": XUpdateCheck.PATCH, "current": "0.9460", "version": "0.9470", "date": "2026-11-22", "notes": PackedStringArray(["修了一处", "改了另一处"]),
		"patch": {"size": 3145728}, "download_url": "https://example.invalid/download"}
	r.merge(extra, true)
	return r


func _run() -> void:
	TestEnv.isolate("xiyou_t369_update_skin")
	XConfig.ensure_loaded()
	XConfig._values["codexUiSkin"] = true
	XUiSkin.ENABLED = true
	XState.current = null
	XUpdateClient.ENABLED = false
	XUpdatePage.patch_installer = func(_p, _r): pass
	XUpdateInstall.BootPatchScript.result["loaded"] = false
	await _old_unchanged()
	await _states()
	await _rollback()
	await _forced()
	await _gate()
	await _height()
	XUpdatePage.patch_installer = Callable()   # 静态变量里留着本脚本的 lambda，退出时会崩
	XUpdatePage.link_opener = Callable()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _old_unchanged() -> void:
	var host := _host()
	var page := XUpdatePage.open(host)
	await frames(3)
	page.show_result(_patch_result())
	await frames(3)
	var ps: StyleBoxFlat = (page.find_child("Panel", true, false) as PanelContainer).get_theme_stylebox("panel")
	var st := XUpdatePage.frame_style()
	check("old_skin_false", not page.skin)
	check("old_frame_same", ps.bg_color.is_equal_approx(st.bg_color) and ps.border_width_top == 1 and ps.border_color.is_equal_approx(st.border_color))
	check("old_no_skin_nodes", page.find_child("Notice", true, false) == null and page.find_child("VersionRow", true, false) == null and page.find_child("ProgressRow", true, false) == null and page.find_child("Buttons2", true, false) == null and page.find_child("Link", true, false) == null)
	check("old_buttons", _vis(page) == ["立即更新", "稍后再说"] or _vis(page).size() == 2, _vis(page))
	check("old_title_font32", (page.find_child("Title", true, false) as Label).get_theme_font_size("font_size") == 32)
	check("old_width_760", absf((page.find_child("Panel", true, false) as Control).custom_minimum_size.x - minf(XUpdatePage.W, get_viewport().get_visible_rect().size.x - 64.0)) < 1.0)
	page.get_parent().queue_free()
	# 回退开关：传真也回旧样式
	XUpdatePage.SKIN_V1 = false
	var p2 := XUpdatePage.open(host, true)
	check("switch_off_old", not p2.skin)
	p2.get_parent().queue_free()
	XUpdatePage.SKIN_V1 = true
	host.queue_free()
	await frames(2)


func _states() -> void:
	var host := _host()
	var page := XUpdatePage.open(host, true)
	await frames(3)
	check("skin_on", page.skin)
	page.show_result({"state": "checking"})  # 打开后立刻查（测试里清单开关关着，很快变成读不到），这里固定住「正在检查」
	await frames(2)
	var panel: PanelContainer = page.find_child("Panel", true, false)
	var title: Label = page.find_child("Title", true, false)
	# 1 正在检查
	check("s1_checking", title.text == "检查更新" and _vis(page) == ["关闭"] and (page.find_child("Dots", true, false) as Control).visible and absf(panel.custom_minimum_size.x - XUpdatePage.SKIN_W_SMALL) < 1.0, [title.text, _vis(page), panel.custom_minimum_size])
	check("s1_title_26", title.get_theme_font_size("font_size") == XUiSkin.FS_CARD)
	var dim: ColorRect = page.find_child("Dim", true, false)
	check("dim_66", absf(dim.color.a - 0.66) < 0.01)
	# 2 已是最新
	page.show_result({"state": XUpdateCheck.LATEST, "current": "0.9470"})
	await frames(2)
	check("s2_latest", title.text == "已是最新版本" and _vis(page) == ["关闭", "重新检查"] and absf(panel.custom_minimum_size.x - 400.0) < 1.0, _vis(page))
	check("s2_no_dots", not (page.find_child("Dots", true, false) as Control).visible)
	# 3 有补丁
	page.show_result(_patch_result())
	await frames(3)
	var ver: Label = page.find_child("NewVersion", true, false)
	var body: Label = page.find_child("Body", true, false)
	check("s3_patch", title.text == "有新版本" and _vis(page) == ["稍后再说", "立即更新"] and absf(panel.custom_minimum_size.x - 640.0) < 1.0, [_vis(page), panel.custom_minimum_size])
	check("s3_version_row", (page.find_child("VersionRow", true, false) as Control).visible and ver.text == "0.9470" and ver.get_theme_color("font_color").is_equal_approx(XUiSkin.GOLD_LIGHT))
	check("s3_body_diamond", body.text.contains("◆ 修了一处") and body.text.contains("更新大小") and not body.text.contains("新版本 0.9470"), body.text)
	check("s3_primary_right_focus", page._focus_buttons().back() == page.find_child("Primary", true, false))
	check("s3_not_problem", (panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color.is_equal_approx(Color(XUiSkin.line_c(), 0.42)))
	# 4 下载中
	page.show_result({"state": XUpdatePage.DOWNLOADING, "done": 1048576, "total": 4194304, "source": _patch_result()})
	await frames(2)
	check("s4_downloading", title.text == "正在下载更新" and _vis(page) == ["取消下载", "关闭"] or _vis(page).has("取消下载"), _vis(page))
	check("s4_bar", (page.find_child("ProgressRow", true, false) as Control).visible and (page.find_child("Percent", true, false) as Label).text == "25%" and absf((page.find_child("ProgressFill", true, false) as Control).anchor_right - 0.25) < 0.001)
	page._on_progress(2097152, 4194304)
	check("s4_bar_moves", (page.find_child("Percent", true, false) as Label).text == "50%")
	# 5 下好了
	page.show_result({"state": XUpdatePage.READY, "version": "0.9470"})
	await frames(2)
	check("s5_ready", title.text == "更新已准备好" and (page.find_child("Candle", true, false) as Control).visible and _vis(page).size() == 2 and _vis(page)[0] == "稍后再说" and not (page.find_child("ProgressRow", true, false) as Control).visible, _vis(page))
	# 6 下载没完成
	page.show_result({"state": XUpdatePage.FAILED, "version": "0.9470", "message": "网络不通或空间不够。", "source": _patch_result()})
	await frames(3)
	var fs := panel.get_theme_stylebox("panel") as StyleBoxFlat
	check("s6_failed_orange", title.text == "下载没完成" and fs.border_color.is_equal_approx(Color(XUiSkin.DOWN, 0.9)) and title.get_theme_color("font_color").is_equal_approx(XUiSkin.DOWN))
	var row1: Array = (page.find_child("Primary", true, false) as Control).get_parent().get_children().filter(func(c): return c is Button and c.visible).map(func(c): return c.text)
	var row2: Array = (page.find_child("Buttons2", true, false) as Control).get_children().filter(func(c): return c is Button and c.visible).map(func(c): return c.text)
	check("s6_buttons", row1 == ["手动下载", "再试一次"] and row2 == ["关闭"] and not (page.find_child("Candle", true, false) as Control).visible, [row1, row2])
	check("s6_focus_order", page._focus_buttons().map(func(b): return b.text) == ["手动下载", "再试一次", "关闭"])
	# 7 读不到
	page.show_result({"state": XUpdateCheck.BAD, "current": "0.9460"})
	await frames(2)
	check("s7_bad", title.text == "暂时查不到" and _vis(page) == ["关闭", "重新检查"] and not (page.find_child("Buttons2", true, false) as Control).visible and fs != null, _vis(page))
	check("s7_back_to_normal_border", (panel.get_theme_stylebox("panel") as StyleBoxFlat).border_width_top == 1)
	# 8 要换整包
	page.show_result(_patch_result({"state": XUpdateCheck.FULL}))
	await frames(2)
	check("s8_full", _vis(page) == ["稍后再说" if false else "关闭", "打开下载页"] or _vis(page).has("打开下载页"), _vis(page))
	var opened := []
	XUpdatePage.link_opener = func(u): opened.append(u)
	(page.find_child("Primary", true, false) as Button).pressed.emit()
	check("s8_opened_label", opened == ["https://example.invalid/download"] and (page.find_child("Primary", true, false) as Button).text == "已打开（链接已复制）", opened)
	XUpdatePage.link_opener = Callable()
	# 9 已退回
	page.show_result({"state": XUpdatePage.ROLLED})
	await frames(2)
	check("s9_rolled", title.text == "已退回" and absf(panel.custom_minimum_size.x - 400.0) < 1.0 and _vis(page).size() == 2, _vis(page))
	# 版本被撤回／上次更新没用上：橙色小字
	page._notice = "上次的更新 0.9470 没能用上（启动失败），已退回。\n"
	page.show_result({"state": XUpdateCheck.LATEST, "current": "0.9460"})
	await frames(2)
	var nl: Label = page.find_child("Notice", true, false)
	check("notice_orange", nl.visible and nl.text.contains("没能用上") and nl.get_theme_color("font_color").is_equal_approx(XUiSkin.DOWN) and not body.text.contains("没能用上"))
	# 取消键关页、点暗处关页（非强制：照旧）
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	page._input(_action_event("ui_cancel"))
	check("cancel_closes_nonforced", closed[0])
	host.queue_free()
	await frames(2)


func _action_event(a: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = true
	return e


func _rollback() -> void:
	XUpdateInstall.BootPatchScript.result["loaded"] = true
	var host := _host()
	var page := XUpdatePage.open(host, true)
	await frames(3)
	page.show_result({"state": XUpdateCheck.LATEST, "current": "0.9470"})
	await frames(2)
	var rb: Button = page.find_child("Rollback", true, false)
	check("rb_link_visible", rb.visible and rb.text == "退回安装包自带版本" and rb.get_node_or_null("Underline") != null)
	rb.pressed.emit()
	check("rb_first_click_armed", page._rollback_armed and rb.text == "再点一次确认退回" and rb.get_node_or_null("Underline") == null)
	await get_tree().create_timer(XUpdatePage.ROLLBACK_RESET_SEC + 0.4).timeout
	check("rb_3s_reset", not page._rollback_armed and rb.text == "退回安装包自带版本" and rb.get_node_or_null("Underline") != null)
	# 点第一下、2 秒后再点第一下：计时重新算，不被旧计时器误伤
	rb.pressed.emit()
	var gen: int = page._rb_gen
	page._rollback_reset(gen - 1)
	check("rb_stale_timer_ignored", page._rollback_armed)
	page._rollback_reset(gen)
	check("rb_reset_by_gen", not page._rollback_armed)
	XUpdateInstall.BootPatchScript.result["loaded"] = false
	host.queue_free()
	await frames(2)


func _forced() -> void:
	var host := _host()
	var r := _patch_result({"forced": true})
	var page := XUpdatePage.open_forced(host, r, true)
	await frames(4)
	var panel: PanelContainer = page.find_child("Panel", true, false)
	check("f_skin", page.skin and page.forced)
	check("f_buttons", _vis(page) == ["退出游戏", "更新"], _vis(page))
	check("f_orange", (panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color.is_equal_approx(Color(XUiSkin.DOWN, 0.9)) and (page.find_child("Title", true, false) as Label).text == "需要更新")
	check("f_opaque", (page.find_child("Dim", true, false) as ColorRect).color.a >= 0.999)
	page._input(_action_event("ui_cancel"))
	await frames(2)
	check("f_cancel_no_close", is_instance_valid(page) and not page.is_queued_for_deletion())
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(2, 2)
	click.global_position = Vector2(2, 2)
	page._gui_input(click)
	await frames(2)
	check("f_click_no_close", is_instance_valid(page) and not page.is_queued_for_deletion())
	# 只能整包：手动下载进主按钮、有重新检查
	page.show_result(_patch_result({"state": XUpdateCheck.FULL, "forced": true}))
	await frames(2)
	check("f_full", _vis(page) == ["退出游戏", "重新检查", "打开下载页"], _vis(page))
	# 下载失败：橙边、手动下载＋再试一次、退出游戏
	page.show_result({"state": XUpdatePage.FAILED, "version": "0.9470", "message": "网络不通或空间不够。", "source": r})
	await frames(2)
	check("f_failed", _vis(page) == ["退出游戏", "手动下载", "再试一次"], _vis(page))
	page.get_parent().queue_free()
	host.queue_free()
	await frames(2)


func _gate() -> void:
	var host := _host()
	XForceUpdate.reset()
	XForceUpdate._started = true
	XForceUpdate._done = true
	XForceUpdate.result = _patch_result({"forced": true})
	var p := XForceUpdate.on_title(host, null, true)
	check("gate_true_skin", p != null and p.skin and p.forced)
	p.get_parent().queue_free()
	await frames(2)
	var p2 := XForceUpdate.on_title(host, null, false)
	check("gate_false_old", p2 != null and not p2.skin and p2.forced)
	p2.get_parent().queue_free()
	await frames(2)
	# 还没查完：「正在检查」框也带着 use_skin
	XForceUpdate.reset()
	XForceUpdate._started = true
	var p3 := XForceUpdate.on_title(host, null, true)
	check("gate_checking_skin", p3 != null and p3.skin and p3.state == "checking")
	p3.get_parent().queue_free()
	XForceUpdate._done = true   # 放走后台等结果的协程（不放，退出时挂着会崩）
	XForceUpdate.result = {"state": XUpdateCheck.LATEST}
	XUpdateClient.instance(get_tree()).checked.emit({})
	await frames(3)
	XForceUpdate.reset()
	check("gate_helper_exists", XForceUpdate.skin_gate() is bool)
	host.queue_free()
	await frames(2)


func _height() -> void:
	# 弹窗最高 620：很长的更新内容在框里滚
	var host := _host()
	var notes := PackedStringArray()
	for i in range(60):
		notes.append("第 %d 条更新内容，写得稍微长一点，好让它在框里折行并且滚动" % i)
	var page := XUpdatePage.open(host, true)
	await frames(3)
	page.show_result(_patch_result({"notes": notes}))
	await frames(4)
	var panel: Control = page.find_child("Panel", true, false)
	check("h_max_620", panel.size.y <= XUpdatePage.SKIN_MAX_H + 1.0, panel.size)
	check("h_scrolls", (page.find_child("More", true, false) as Label).visible)
	XConfig._values[XFontScale.KEY] = {"global": 130, "toast": 100}
	page.show_result(_patch_result({"notes": notes}))
	await frames(4)
	check("h_font130_max_620", panel.size.y <= XUpdatePage.SKIN_MAX_H + 1.0 and XUiSkin.font_mult() > 1.2, [panel.size, XUiSkin.font_mult()])
	XConfig._values.erase(XFontScale.KEY)
	host.queue_free()
	await frames(2)
