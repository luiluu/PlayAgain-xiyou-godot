extends Node
## 天启篇标题页 XTianqiTitle（不经过 entry.gd，没有转换产物也能跑）：
## 一、素材：都能加载；五个按钮图高度是偶数（切上下两半）；七张睁眼帧尺寸一致、等于裁切区 307×297；Logo 显示宽 610。
## 二、五项顺序；回调按确定被调到；没存档时「旧的回忆」灰掉，按确定不执行、上下键跳过；返回版本选择只在传了回调时有。
## 三、上下键首尾循环；选中项用上半图、放大到 1.1，未选中下半、0.9；光标滑入后停在选中项左侧、中线对齐。
## 四、进场：t=0 全黑、贴闭眼；淡入第 26 帧起逐帧睁眼、第 32 帧去掉贴片；Logo 第 36～56 帧上浮淡入；推进到结束后
##     贴片去掉、Logo 不透明、菜单可操作；进场中按键直接跳到结束；按 time_scale 换算真实秒。
## 五、不调 play_entrance() 一建好就是最终画面；XIntroAnim.ENABLED = false 时 play_entrance() 不做进场。
## 六、开关：ENABLED = false 或 XTianqi.ENABLED = false 时 available() 为假（测完恢复）。

var results: Array = []
var calls: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _actions(with_back := true) -> Dictionary:
	var a := {}
	for k in ["new_game", "load", "options", "achievements", "check_update"]:
		a[k] = func(): calls.append(k)
	if with_back:
		a["back_to_menu"] = func(): calls.append("back_to_menu")
	return a


func _make(disabled: Array = [], with_back := true) -> XTianqiTitle:
	var t := XTianqiTitle.new()
	t.setup(_actions(with_back), disabled)
	add_child(t)
	return t


func _key(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _run() -> void:
	_assets()
	await _menu()
	await _entrance()
	_switches()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _assets() -> void:
	var missing := XTianqiTitle.files().filter(func(p): return not (load(p) is Texture2D))
	_check("assets_load", missing.is_empty() and XTianqiTitle.files().size() == 3 + 5 + 7, missing)
	var odd := []
	for c in XTianqiTitle.COMMANDS:
		var tex: Texture2D = load(XTianqiTitle.DIR + c.image)
		if tex.get_height() % 2 != 0 or tex.get_width() != 200:
			odd.append([c.image, tex.get_size()])
	_check("buttons_even_height", odd.is_empty(), odd)
	var sizes := []
	for i in XTianqiTitle.EYE_COUNT:
		sizes.append((load(XTianqiTitle.DIR + "eye_%d.png" % i) as Texture2D).get_size())
	_check("eye_frames_same_size", sizes.all(func(s): return s == XTianqiTitle.EYE_RECT.size) and XTianqiTitle.EYE_RECT.size == Vector2(307, 297), sizes)
	var bg: Texture2D = load(XTianqiTitle.BG)
	_check("bg_1280x720", bg.get_size() == Vector2(1280, 720), bg.get_size())


func _menu() -> void:
	calls.clear()
	var t := _make(["load"])
	await get_tree().process_frame
	var keys := []
	for i in t.item_count():
		keys.append(t.item(i).key)
	_check("menu_order", keys == ["new_game", "load", "options", "achievements", "check_update"], keys)
	_check("title_page", t.is_title_page() and not t.entering())
	_check("back_button_present", t.find_child("ReturnToMenu", true, false) != null)
	# 灰掉的「旧的回忆」
	_check("load_greyed", not t.item_enabled(1) and absf(t.item(1).node.modulate.a - XTianqiTitle.DISABLED_ALPHA) < 0.01 and t.item(0).node.modulate.a == 1.0)
	_check("load_disabled_no_call", not t.activate(1) and calls.is_empty(), calls)
	# 上下键：0 → 下 → 跳过 1 到 2；上 → 跳过 1 回 0；上 → 循环到 4；下 → 回 0
	_check("start_on_first", t.selected() == 0)
	var seq := []
	for a in ["ui_down", "ui_up", "ui_up", "ui_down"]:
		t._unhandled_input(_key(a))
		seq.append(t.selected())
	_check("updown_cycle_skip_disabled", seq == [2, 0, 4, 0], seq)
	# 确定：调到当前项的回调
	t.select(2)
	t._unhandled_input(_key("ui_accept"))
	_check("accept_calls_selected", calls == ["options"], calls)
	for i in [0, 3, 4]:
		t.activate(i)
	t.item(0).node.pressed.emit()
	(t.find_child("ReturnToMenu", true, false) as Button).pressed.emit()
	_check("callbacks_called", calls == ["options", "new_game", "achievements", "check_update", "new_game", "back_to_menu"], calls)
	# 选中态：上半图、放大；过渡走完
	t.select(3)
	for i in 30:
		t.step(1.0 / 60.0)
	var it3: Dictionary = t.item(3)
	var it0: Dictionary = t.item(0)
	_check("selected_uses_top_half", it3.rect.texture == it3.top and it3.top.region.position.y == 0.0 and it0.rect.texture == it0.bottom and it0.bottom.region.position.y > 0.0)
	_check("selected_scaled", is_equal_approx(it3.node.scale.x, XTianqiTitle.SCALE_ON) and is_equal_approx(it0.node.scale.x, XTianqiTitle.SCALE_OFF), [it3.node.scale, it0.node.scale])
	# 光标：在选中项字的左侧、竖向居中
	var b: Button = it3.node
	var c: TextureRect = t.cursor
	var art_right := c.position.x + (XTianqiTitle.CURSOR_ART.end.x) * XTianqiTitle.CURSOR_SCALE
	var art_mid := c.position.y + (XTianqiTitle.CURSOR_ART.get_center().y) * XTianqiTitle.CURSOR_SCALE
	var text_left := b.position.x + b.size.x / 2.0 - (b.size.x / 2.0 - XTianqiTitle.TEXT_LEFT) * XTianqiTitle.SCALE_ON
	_check("cursor_left_of_selected", art_right < text_left and text_left - art_right < 15.0 and absf(art_mid - (b.position.y + b.size.y / 2.0)) < 1.0,
		[art_right, text_left, art_mid, b.position.y + b.size.y / 2.0])
	# 光标滑入：刚切换时在左 4 像素，0.2 秒后到位
	t.select(4)
	var start: Vector2 = t.cursor.position
	var target: Vector2 = t.cursor_target()
	t.step(0.1)
	var mid: Vector2 = t.cursor.position
	t.step(0.11)
	_check("cursor_slides_in", is_equal_approx(start.x, target.x - XTianqiTitle.CURSOR_SLIDE) and mid.x > start.x and mid.x < target.x and t.cursor.position == target,
		[start, mid, t.cursor.position, target])
	# 鼠标悬停选中（灰掉的项不选）
	t.item(1).node.mouse_entered.emit()
	_check("hover_disabled_ignored", t.selected() == 4)
	t.item(2).node.mouse_entered.emit()
	_check("hover_selects", t.selected() == 2)
	# 布局：五项中心 x 640，行距 50
	var centers := []
	for i in t.item_count():
		var n: Button = t.item(i).node
		centers.append(n.position + n.size / 2.0)
	_check("menu_layout", centers[0] == Vector2(640, 390) and centers[4] == Vector2(640, 590), centers)
	# 不调 play_entrance：一建好就是最终画面
	var s := t.state()
	_check("final_without_entrance", not s.entering and not s.eye_visible and s.logo_alpha == 1.0 and s.menu_alpha == 1.0 and s.black == 0.0 and s.logo_y == XTianqiTitle.LOGO_POS.y, s)
	_check("logo_size", is_equal_approx(t.logo.size.x, XTianqiTitle.LOGO_WIDTH), t.logo.size)
	t.queue_free()
	# 没有回调的项灰掉；不传 back_to_menu 就没有返回按钮
	var t2 := XTianqiTitle.new()
	t2.setup({"new_game": func(): pass})
	add_child(t2)
	_check("missing_action_greyed", t2.item_enabled(0) and not t2.item_enabled(2) and t2.find_child("ReturnToMenu", true, false) == null)
	t2.queue_free()
	await get_tree().process_frame


func _entrance() -> void:
	calls.clear()
	var t := _make()
	t.play_entrance()
	var s0 := t.state()
	_check("entrance_starts_black_closed", s0.entering and s0.black == 1.0 and s0.eye_visible and s0.eye_frame == 0 and s0.logo_alpha == 0.0 and s0.menu_alpha == 0.0, s0)
	# 进场中确定键不触发菜单
	t._unhandled_input(_key("ui_accept"))
	_check("entrance_menu_inert", calls.is_empty(), calls)
	# 逐帧（30 帧／秒）记下睁眼帧号
	var frames := []
	var black_half := -1.0
	var logo_at := {}
	for f in 70:
		frames.append(t.state().eye_frame)
		if f == 18:
			black_half = t.state().black
		if f in [35, 46, 56]:
			logo_at[f] = [t.state().logo_alpha, t.state().logo_y]
		t.step(1.0 / 30.0)
	_check("eye_timeline", frames.slice(0, 26).all(func(x): return x == 0) and frames.slice(26, 33) == [1, 2, 3, 4, 5, 6, -1], frames.slice(20, 36))
	_check("fade_in_midway", black_half > 0.2 and black_half < 0.8, black_half)
	_check("logo_rise", logo_at[35][0] == 0.0 and logo_at[46][0] > 0.2 and logo_at[46][0] < 0.8 and logo_at[46][1] > XTianqiTitle.LOGO_POS.y and absf(logo_at[56][0] - 1.0) < 0.01, logo_at)
	var s1 := t.state()
	_check("entrance_done", not s1.entering and not s1.eye_visible and s1.logo_alpha == 1.0 and s1.menu_alpha == 1.0 and s1.black == 0.0 and s1.logo_y == XTianqiTitle.LOGO_POS.y, s1)
	t._unhandled_input(_key("ui_accept"))
	_check("menu_operable_after", calls == ["new_game"], calls)
	t.queue_free()
	# 进场中按任意键跳到结束（按键被吃掉，不触发菜单）
	calls.clear()
	var t2 := _make()
	var done := [false]
	t2.entrance_finished.connect(func(): done[0] = true)
	t2.play_entrance()
	t2.step(0.5)
	var k := InputEventKey.new()
	k.keycode = KEY_ENTER
	k.pressed = true
	t2._input(k)
	var s2 := t2.state()
	_check("skip_to_final", done[0] and not s2.entering and not s2.eye_visible and s2.logo_alpha == 1.0 and s2.menu_alpha == 1.0 and s2.black == 0.0 and calls.is_empty(), s2)
	t2.queue_free()
	# 真实秒：游戏 1.6 倍速时 _process 除掉 time_scale
	var t3 := _make()
	t3.play_entrance()
	Engine.time_scale = 1.6
	t3._process(1.6)
	Engine.time_scale = 1.0
	_check("real_seconds", is_equal_approx(t3.state().t, 1.0), t3.state().t)
	t3.queue_free()
	# XIntroAnim.ENABLED = false：不做进场
	var ia := XIntroAnim.ENABLED
	XIntroAnim.ENABLED = false
	var t4 := _make()
	t4.play_entrance()
	_check("no_entrance_without_intro", not t4.entering() and t4.state().logo_alpha == 1.0 and not t4.state().eye_visible)
	XIntroAnim.ENABLED = ia
	t4.queue_free()
	await get_tree().process_frame


func _switches() -> void:
	_check("available_default", XTianqiTitle.available())
	var en := XTianqiTitle.ENABLED
	XTianqiTitle.ENABLED = false
	_check("off_switch", not XTianqiTitle.available())
	XTianqiTitle.ENABLED = en
	var tq := XTianqi.ENABLED
	XTianqi.ENABLED = false
	_check("off_without_tianqi", not XTianqiTitle.available())
	XTianqi.ENABLED = tq
	_check("switches_restored", XTianqiTitle.available() and XTianqiTitle.ENABLED and XTianqi.ENABLED)
