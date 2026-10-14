extends Node
## 对话框验收（非自动模式，逐帧）：窗口矩形与正式版运行时读数一致、逐字速度、等待/翻页、自动换行、
## 名字框、选项窗（行数/位置/取消规则/滚动）、数值输入、连续对话不关窗。全部用内存新游戏，不写任何存档。
## 窗口模式加 -- --out=<目录> 截取与原版参照（04_验证/本地结果/原版参照/02、03、06、30）同一画面。

var results := []
var out_dir := ""
var box: XMessageBox


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _phys(n := 1) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


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


func _rect(w: XMVWindow) -> Array:
	return [w.position.x, w.position.y, w.size.x, w.size.y]


## 等到翻页标记出现并过了 startPause 的 10 帧等待（期间按键无效，同 MV）
func _wait_pause() -> void:
	await _until(func(): return box.win.pause and box._wait == 0)


## 等到 cond 成立（最多 n 个物理帧）
func _until(cond: Callable, n := 600) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await _phys()
	return false


func _run() -> void:
	XMessageBox.auto = false
	XState.new_game(3, 1, [])
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(1280, 720)
	add_child(bg)
	box = XMessageBox.new()
	add_child(box)
	await _phys()

	# 1) 中间位置、名字框（原版 02：消息 0,274,1280,172；名字框 0,210,246,64）
	# 解释器是同步接着调用下一条的，这里用一个协程串起三条对话
	var r1 := {"value": null}
	var r2 := {"value": null}
	var r3 := {"value": null}
	var chain := func():
		r1.value = await box.run({"face": "Actor3", "index": 5, "position": 1,
			"lines": ["\\n<毒大炮>本游戏是免费游戏千万别在其他地方付费购买！", "\\|\\!"]})
		r2.value = await box.run({"face": "Actor3", "index": 5, "position": 1, "lines": ["\\n<毒大炮>接着说。"]})
		r3.value = await box.run({"face": "Actor3", "index": 5, "position": 0,
			"lines": ["\\n<毒大炮>本游戏是免费游戏千万别在其他地方付费购买！"]})
	chain.call()
	await _phys()
	_check("msg_middle_rect", _rect(box.win) == [0.0, 274.0, 1280.0, 172.0], _rect(box.win))
	_check("name_rect", _rect(box.name_win) == [0.0, 210.0, 246.0, 64.0], _rect(box.name_win))
	# 开窗 8 帧（每帧 +32）后才画字；正式 clearFlags 强制 _showFast，打开后一帧内整页画到 \| 等待
	await _phys(6)
	_check("opening_8_frames", box.win.openness < 255 and box._page_glyphs.is_empty(), box.win.openness)
	await _phys(3)
	_check("page_drawn_at_once", box.win.is_open() and box._page_glyphs.size() == 21, box._page_glyphs.size())
	var first: Dictionary = box._page_glyphs[0]
	_check("text_indent_168_line_34", first.x == 168.0 and first.h == 34.0, [first.x, first.h])
	_check("wait_60", box._wait > 40 and not box.win.pause, box._wait)
	await _wait_pause()
	await _phys(12)
	await _shot("msg_02_middle_name")
	_check("pause_sign_after_wait", box.win.pause)
	await _press("ui_accept")
	await _until(func(): return r1.value != null, 60)
	_check("message_done", r1.value == 0, r1.value)

	# 2) 连续对话（同设置）不关窗；改到顶部则先关再开（原版 30：名字框在消息窗下方 0,172）
	_check("continue_keeps_open", box.win.openness == 255 and not box.win.is_closing(), box.win.openness)
	await _wait_pause()
	await _press("ui_accept")
	await _until(func(): return r2.value != null, 60)
	await _phys()
	_check("position_change_closes_first", box.win.is_closing(), box.win.openness)
	await _wait_pause()
	_check("msg_top_rect", _rect(box.win) == [0.0, 0.0, 1280.0, 172.0], _rect(box.win))
	_check("name_below_top", _rect(box.name_win) == [0.0, 172.0, 246.0, 64.0], _rect(box.name_win))
	await _phys(12)
	await _shot("msg_30_top")
	await _press("ui_cancel")
	await _until(func(): return r3.value != null, 60)
	_check("cancel_advances_message", r3.value == 0)
	await _phys(12)
	_check("closed_after_end", box.win.is_closed() and box.name_win.is_closed(), [box.win.openness, box.name_win.openness])

	# 3) 存档位选项（原版 03：选项窗 1130,304,150,244，6 行可滚）
	var slots := []
	for i in range(10):
		slots.append("%d号存档" % (i + 1))
	var r4 := {"value": null}
	var t4 := func(): r4.value = await box.run({"face": "Actor3", "index": 5, "position": 2,
		"lines": ["\\n<毒大炮>首先你需要选择你的存档位置，存档位置确定后不得再更改，如果你选择的位置已经有存档那么将会覆盖这个存档。"],
		"choices": slots, "cancel": -1, "default": 0})
	t4.call()
	await _until(func(): return box.choice_win.is_open())
	var cr := _rect(box.choice_win)
	_check("choice_rect_bottom", absf(cr[0] - 1130.0) <= 2 and absf(cr[2] - 150.0) <= 2 and cr[1] == 304.0 and cr[3] == 244.0, cr)
	_check("choice_scroll_arrow", box.choice_win.down_arrow and not box.choice_win.up_arrow)
	# 自动换行：第一行到右边界前换行，第二行从 168 开始
	var ys := {}
	for g in box._page_glyphs:
		ys[g.y] = true
	var max_x := 0.0
	for g in box._page_glyphs:
		max_x = maxf(max_x, g.x + g.w)
	_check("auto_wrap_two_lines", ys.size() == 2 and max_x <= 1252.0, [ys.keys(), max_x])
	await _phys(4)
	await _shot("msg_03_slot_choice")
	await _press("ui_cancel")
	await _phys(2)
	_check("cancel_disabled", r4.value == null and box.choice_win.is_open())
	await _press("ui_up")
	await _phys()
	_check("up_wraps_to_last", box._choice_index == 9 and box._choice_top == 4, [box._choice_index, box._choice_top])
	await _press("ui_down")
	await _phys()
	_check("down_wraps_to_first", box._choice_index == 0 and box._choice_top == 0)
	await _press("ui_down")
	await _press("ui_accept")
	await _until(func(): return r4.value != null, 30)
	_check("choice_result", r4.value == 1, r4.value)

	# 4) 难度选项（原版 06：默认不选、6 行不滚）；取消分支
	var r5 := {"value": null}
	var t5 := func(): r5.value = await box.run({"face": "Actor3", "index": 5, "position": 2,
		"lines": ["\\n<助手>超强者仅限\\c[4]地狱及以上难度\\c[0]获取与出战。", "宝宝、简单、普通、困难难度中，超强者只能留在替补。"],
		"choices": ["宝宝难度", "简单难度", "普通难度", "困难难度", "地狱难度", "天灾难度"], "cancel": -1, "default": -1})
	t5.call()
	await _until(func(): return box.choice_win.is_open())
	cr = _rect(box.choice_win)
	_check("difficulty_rect", absf(cr[0] - 1138.0) <= 2 and cr[1] == 304.0 and cr[3] == 244.0 and not box.choice_win.down_arrow, cr)
	_check("default_none", box._choice_index == -1)
	var colored := box._page_glyphs.filter(func(g): return g.color == XUI.text_color(4))
	_check("color_code", colored.size() == 7, colored.size())
	await _press("ui_accept")
	await _phys(2)
	_check("ok_without_selection_buzzes", r5.value == null)
	await _press("ui_down")
	await _phys()
	_check("down_from_none_selects_first", box._choice_index == 0)
	await _press("ui_down")
	await _phys(4)
	await _shot("msg_06_difficulty")
	await _press("ui_accept")
	await _until(func(): return r5.value != null, 30)
	_check("difficulty_result", r5.value == 1, r5.value)

	var r6 := {"value": null}
	var t6 := func(): r6.value = await box.run({"choices": ["是", "否"], "cancel": 2, "position": 1})
	t6.call()
	await _until(func(): return box.choice_win.is_open())
	_check("standalone_choice_no_message", box.win.is_closed() or box.win.is_closing())
	await _press("ui_cancel")
	await _until(func(): return r6.value != null, 30)
	_check("cancel_branch", r6.value == -2, r6.value)

	# 5) 中间消息时选项最多 4 行
	var r7 := {"value": null}
	var t7 := func(): r7.value = await box.run({"position": 1, "lines": ["选吧"], "choices": ["一", "二", "三", "四", "五", "六"], "cancel": 0})
	t7.call()
	await _until(func(): return box.choice_win.is_open())
	_check("middle_choice_4_rows", box.choice_win.size.y == 4 * 36 + 28 and box.choice_win.position.y == 274 + 172, _rect(box.choice_win))
	await _press("ui_cancel")
	await _until(func(): return r7.value != null, 30)
	_check("cancel_index", r7.value == 0, r7.value)

	# 6) 数值输入（5 位，消息在下：窗口 546,484,188,64）
	var r8 := {"value": null}
	var t8 := func(): r8.value = await box.run({"position": 2, "lines": ["\\n<讨债人>说吧~你想要多少肝帝积分？"], "digits": 5, "number_value": 120})
	t8.call()
	await _until(func(): return box.num_win.is_open())
	_check("number_rect", _rect(box.num_win) == [546.0, 484.0, 188.0, 64.0], _rect(box.num_win))
	await _press("ui_up")
	await _press("ui_right")
	await _press("ui_down")
	await _press("ui_left")
	await _press("ui_left")
	await _phys()
	_check("number_digits", box._number == 19120 and box._digit_index == 4, [box._number, box._digit_index])
	await _press("ui_accept")
	await _until(func(): return r8.value != null, 30)
	_check("number_result", r8.value == 19120, r8.value)

	# 7) 超过 4 行：满页等待，翻页后接着显示（自动换行越界的字留到下一页，优化 O-005）
	var long := "一二三四五六七八九十".repeat(30)
	var r9 := {"value": null}
	var t9 := func(): r9.value = await box.run({"lines": [long]})
	t9.call()
	await _wait_pause()
	var page1 := box._page_glyphs.size()
	_check("page_full_4_lines", page1 > 0 and box._page_glyphs.back().y == 34.0 * 3, [page1, box._page_glyphs.back().y if page1 else -1])
	await _press("ui_accept")
	await _wait_pause()
	_check("next_page_rest", page1 + box._page_glyphs.size() == 300, [page1, box._page_glyphs.size()])
	await _press("ui_accept")
	await _until(func(): return r9.value != null, 30)

	# 8) \. 等 15 帧
	var r10 := {"value": null}
	var t10 := func(): r10.value = await box.run({"lines": ["甲\\.乙"]})
	t10.call()
	await _until(func(): return box._page_glyphs.size() == 1 and box._wait > 0)
	var waited := 0
	while box._page_glyphs.size() == 1 and waited < 40:
		await _phys()
		waited += 1
	_check("wait_15_frames", waited >= 15 and waited <= 17, waited)
	await _wait_pause()
	await _press("ui_accept")
	await _until(func(): return r10.value != null, 30)
	_check("plain_text", XMVText.plain("\\c[4]地狱\\c[0]难度\\.") == "地狱难度")

	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
