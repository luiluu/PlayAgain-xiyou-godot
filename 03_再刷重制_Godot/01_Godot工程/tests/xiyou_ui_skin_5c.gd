extends Node
## 新界面第 5C 批（ui-skin-5c）专项：设置主页 XSkinOptionsPage、设置子页（旧页放进居中外框）、文本输入、返回标题，以及两个新设置项。
## - 存盘：只新增 codexUiSkin／codexUiMotion 两个键；旧档没有这两个键时读到默认（新／没选过）；
## - 界面风格：天启篇默认新、选原版后 XUiSkin.on() 为 false；西游存档（重制版）不列这一行、on() 恒 false；
## - 界面动效：没选过按省电模式（全部／简化），选过按选的；测试写 motion_override 优先；
## - 设置页：天启篇建新布局、旧窗口藏起来，分类、列表、详情牌、方向键／确定／Q／E／取消；西游存档照旧不建新布局、列表里没有两个新行；
## - 切换界面风格：本页立刻换风格，关页时 to_map；子页：外框居中、返回后新布局还在；
## - 文本输入、返回标题：新界面换皮与叫法，西游存档照旧。
## 带 -- --out=<目录> 且有窗口时截图（16:9、20:9）。注意 XConfig 用 TestEnv.isolate 的 path_override，不读 Kyo 本机真实 options.json。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results: Array = []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


func shot(name: String) -> void:
	if not windowed():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	check("screenshot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK, img.get_size())


## 16:9 拍一张，有窗口时再拍 20:9
func shots(name: String) -> void:
	if not windowed():
		return
	await frames(20)
	await shot(name + "_16x9")
	var win := get_window()
	var old := win.size
	win.size = Vector2i(1600, 720)
	await frames(12)
	await shot(name + "_20x9")
	win.size = old
	await frames(8)


func _act(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	return e


func _state(tianqi := true) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	if tianqi:
		s.flags["tianqi"] = {"rules": 1}
	return s


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_5c")
	XUiSkin.motion_override = -1
	_config()
	await _options_tianqi()
	await _options_xiyou()
	await _sub_pages()
	await _prompt_and_end()
	XUiSkin.motion_override = -1
	XState.current = null
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- XConfig 存读、XUiSkin 读取 ----
func _config() -> void:
	XConfig._loaded_path = "<unloaded>"
	check("cfg_default_skin_new", XConfig.ui_skin_new() == true)
	check("cfg_default_motion_unset", XConfig.ui_motion() == -1)
	_state()
	check("skin_tianqi_on_by_default", XUiSkin.on() and XUiSkin.selectable())
	check("motion_default_full", XUiSkin.motion() == XUiSkin.Motion.FULL or XGraphics.low_power(), XUiSkin.motion())
	XConfig.set_flag("codexUiSkin", false)
	check("skin_old_choice_off", not XUiSkin.on() and XUiSkin.selectable())
	XConfig.set_ui_motion(1)
	check("motion_chosen_simple", XUiSkin.motion() == XUiSkin.Motion.SIMPLE)
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	check("motion_override_wins", XUiSkin.motion() == XUiSkin.Motion.OFF)
	XUiSkin.motion_override = -1
	XConfig.set_ui_motion(7)
	check("motion_clamped", XConfig.ui_motion() == 2)
	# 存盘：两个键写进去，重新读回来
	XConfig.set_flag("codexUiSkin", false)
	XConfig.set_ui_motion(2)
	XConfig._loaded_path = "<unloaded>"
	check("cfg_roundtrip", XConfig.ui_skin_new() == false and XConfig.ui_motion() == 2, [XConfig.ui_skin_new(), XConfig.ui_motion()])
	# 旧档（没有这两个键）读到默认
	var data = JSON.parse_string(FileAccess.get_file_as_string(XConfig.path()))
	data.erase("codexUiSkin")
	data.erase("codexUiMotion")
	var f := FileAccess.open(XConfig.path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	XConfig._loaded_path = "<unloaded>"
	check("cfg_old_file_defaults", XConfig.ui_skin_new() == true and XConfig.ui_motion() == -1, [XConfig.ui_skin_new(), XConfig.ui_motion()])
	# 不是数字的动效档读回默认；其余旧键不受影响
	data["codexUiMotion"] = "abc"
	data["bgmVolume"] = 60
	f = FileAccess.open(XConfig.path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	XConfig._loaded_path = "<unloaded>"
	check("cfg_bad_motion_default", XConfig.ui_motion() == -1 and XConfig.volume("bgmVolume") == 60)
	_state(false)
	check("skin_xiyou_never_on", not XUiSkin.on() and not XUiSkin.selectable())
	XConfig.set_flag("codexUiSkin", true)
	check("skin_xiyou_still_off", not XUiSkin.on())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(XConfig.path()))
	XConfig._loaded_path = "<unloaded>"


func _symbols(page: XOptionsScene) -> Array:
	return page.symbols()


# ---- 设置主页（天启篇：新布局）----
func _options_tianqi() -> void:
	_state()
	XUiSkin.motion_override = -1   # 截图用默认动效档（没选过＝全部），不钉成「关」
	var page := XOptionsScene.new()
	var closed := {"n": 0}
	page.closed.connect(func(): closed.n += 1)
	add_child(page)
	await frames(3)
	var sk := page.skin
	check("opt_skin_built", sk != null and not page.win.visible)
	check("opt_rows_have_style", _symbols(page).has("codexUiSkin") and _symbols(page).has("codexUiMotion"), _symbols(page))
	check("opt_cats", sk.cats.map(func(c): return c.name) == ["常规", "战斗", "遇敌", "画面", "声音", "挂机与操作"] or sk.cats.size() >= 5, sk.cats.map(func(c): return c.name))
	var names := []
	for c in sk.cats:
		for i in c.idx:
			names.append(str(page._list[i][1]))
	check("opt_ads_hidden", not names.has("wxxonoff") and not names.has("wxlonoff") and not names.has("wxtonoff"), names)
	check("opt_dead_hidden", not names.has("codexFeedbackPending"), names)
	check("opt_ring_center_count", sk.ring_center == [str(sk.cats[0].idx.size()), "项"], sk.ring_center)
	check("opt_first_cat_rows", sk.list.items.size() == sk.cats[0].idx.size())
	# 常规第一项：坐标显示，确定切换
	var before := XConfig.flag("MapXy")
	sk.input(_act("ui_accept"))
	await frames(2)
	check("opt_ok_toggles", XConfig.flag("MapXy") != before)
	check("opt_row_status_updates", str(sk.list.items[0].right) == ("开" if XConfig.flag("MapXy") else "关"), sk.list.items[0])
	check("opt_card_title", sk.card.title == "坐标显示" and sk.card.desc != "", [sk.card.title, sk.card.desc])
	# 屏蔽掉落是会话开关但确定进子页：详情牌写「确定进入」；战斗变速第 4 档显示「原速」；状态词没有英文 ON／OFF
	var pi: int = page._list.find_custom(func(o): return o[1] == "pingbiDrop")
	sk._sync_card(pi)
	check("opt_pingbi_card_enter", str(sk.card.sections[0].text) == "确定进入。", sk.card.sections)
	var bi: int = page._list.find_custom(func(o): return o[1] == "battleAniSpeed")
	var sp0 := XConfig.battle_speed()
	XConfig.set_battle_speed(4)
	check("opt_speed_off_is_original", sk.status_of(bi) == "原速" and page.status_text(bi) == "OFF", [sk.status_of(bi), page.status_text(bi)])
	XConfig.set_battle_speed(sp0)
	var bad := false
	for i in page._list.size():
		bad = bad or ["ON", "OFF"].has(sk.status_of(i))
	check("opt_no_english_status", not bad)
	check("opt_single_backdrop", page.skin.backdrop == null and page.skin.get_node_or_null("SkinBackdrop") == null)
	# 下一项
	sk.input(_act("ui_down"))
	await frames(2)
	check("opt_down_moves", page.index == sk.cats[0].idx[1] and sk.list.index == 1, [page.index, sk.list.index])
	# Q／E 换分类
	sk.input(_key(KEY_E))
	await frames(2)
	check("opt_e_next_cat", sk.cur == 1 and sk.ring.index == 1 and sk.list_title == "战斗", [sk.cur, sk.list_title])
	sk.input(_key(KEY_Q))
	await frames(2)
	check("opt_q_prev_cat", sk.cur == 0)
	sk.input(_key(KEY_Q))
	await frames(2)
	check("opt_q_wraps", sk.cur == sk.cats.size() - 1, sk.cur)
	# 声音：左右调音量
	var sound_i := sk.cats.find_custom(func(c): return c.key == "sound")
	sk.step_category(sound_i - sk.cur)
	await frames(2)
	check("opt_sound_cat", sk.cats[sk.cur].key == "sound" and sk.list.items.size() == 4)
	var v0 := XConfig.volume("bgmVolume")
	sk.input(_act("ui_right"))
	await frames(2)
	check("opt_right_volume_up", XConfig.volume("bgmVolume") == mini(v0 + 20, 100), XConfig.volume("bgmVolume"))
	sk.input(_act("ui_left"))
	await frames(2)
	check("opt_left_volume_down", XConfig.volume("bgmVolume") == v0)
	# 点分类圆球
	sk.ring.select(0)
	await frames(2)
	check("opt_ring_select_changes_cat", sk.cur == 0 and page.index == sk.cats[0].idx[0], [sk.cur, page.index])
	# 画面分类：界面风格、界面动效
	var screen_i := sk.cats.find_custom(func(c): return c.key == "screen")
	sk.step_category(screen_i - sk.cur)
	await frames(2)
	var texts: Array = sk.list.items.map(func(r): return r.text)
	check("opt_screen_has_both", texts.has("界面风格") and texts.has("界面动效"), texts)
	await shots("ui_skin_5c_options_screen")
	# 界面动效：选中后左右 / 确定循环（先让全局动效别干扰）
	var mi := texts.find("界面动效")
	page.index = sk.cats[sk.cur].idx[mi]
	page._refresh()
	await frames(2)
	XUiSkin.motion_override = -1
	XConfig.set_ui_motion(-1)
	var effective := XUiSkin.motion()
	page.ok()
	await frames(2)
	check("opt_motion_cycles", XConfig.ui_motion() == (effective + 1) % 3, [effective, XConfig.ui_motion()])
	check("opt_motion_row_text", str(sk.list.items[mi].right) == XOptionsScene.MOTION_NAMES[XConfig.ui_motion()], sk.list.items[mi])
	page._side(false)
	await frames(1)
	check("opt_motion_left_down", XConfig.ui_motion() == maxi((effective + 1) % 3 - 1, 0))
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	# 界面风格：选原版——本页立刻换成旧界面
	var si := texts.find("界面风格")
	page.index = sk.cats[sk.cur].idx[si]
	page._refresh()
	await frames(2)
	check("opt_style_row_new", str(sk.list.items[si].right) == "新", sk.list.items[si])
	page.ok()
	await frames(3)
	check("opt_style_to_old", not XConfig.ui_skin_new() and page.skin == null and page.win.visible and page.to_map)
	check("opt_style_old_rows_kept", _symbols(page).has("codexUiSkin") and not _symbols(page).has("codexUiMotion"), _symbols(page))
	check("opt_style_old_backdrop", page._bg_nodes.size() > 0 and page._bg_nodes.all(func(n): return is_instance_valid(n) and n.name != "SkinBackdrop"))
	check("opt_style_old_status", page.status_text(page.index) == "原版")
	await shots("ui_skin_5c_options_old_style")
	# 再选回新
	page.ok()
	await frames(3)
	check("opt_style_back_new", XConfig.ui_skin_new() and page.skin != null and not page.win.visible)
	check("opt_style_new_backdrop", page._bg_nodes.any(func(n): return is_instance_valid(n) and n.name == "SkinBackdrop"))
	# 取消：关页
	page.skin.input(_act("ui_cancel"))
	check("opt_cancel_closes", closed.n == 1)
	page.queue_free()
	await frames(3)
	XConfig.set_flag("codexUiSkin", true)


# ---- 设置主页（西游存档：照旧）----
func _options_xiyou() -> void:
	_state(false)
	var page := XOptionsScene.new()
	add_child(page)
	await frames(3)
	check("xy_no_skin", page.skin == null and page.win.visible)
	check("xy_no_new_rows", not _symbols(page).has("codexUiSkin") and not _symbols(page).has("codexUiMotion"), _symbols(page))
	check("xy_ads_still_listed", _symbols(page).has("wxxonoff"))
	check("xy_not_to_map", not page.to_map)
	page.queue_free()
	await frames(3)


# ---- 子页放进居中外框 ----
func _sub_pages() -> void:
	_state()
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	var page := XOptionsScene.new()
	add_child(page)
	await frames(3)
	var sk := page.skin
	var shot_names := {"codexQuality": "graphics", "codexNotices": "notice", "pingbiDrop": "pingbi", "codexCostumes": "costumes", "HangUp": "hangup"}
	for sym in shot_names:
		var i := page._list.find_custom(func(o): return o[1] == sym)
		if i < 0:
			check("sub_%s_listed" % sym, false)
			continue
		page.index = i
		page._refresh()
		await frames(2)
		if sym == "codexCostumes" and not XCostumes.can_open(XState.current):
			check("sub_costumes_cannot_open_in_test", true)
			continue
		page.ok()
		await frames(3)
		var host := page.get_node_or_null("SkinSubPageHost")
		check("sub_%s_open" % sym, page._page != null and host != null and not sk.visible and page._page.get_parent() == host, sym)
		if host != null:
			check("sub_%s_host_centered" % sym, is_equal_approx(host.position.x, maxf(roundf((get_viewport().get_visible_rect().size.x - 1280.0) / 2.0), 0.0)))
		var backdrop_visible := false
		for n in page._bg_nodes:
			backdrop_visible = backdrop_visible or n.visible
		check("sub_%s_page_backdrop_kept" % sym, backdrop_visible)
		await shots("ui_skin_5c_sub_" + shot_names[sym])
		page._page.cancel() if page._page.has_method("cancel") else page._page.closed.emit()
		await frames(3)
		check("sub_%s_back" % sym, page._page == null and sk.visible and page.get_node_or_null("SkinSubPageHost") == null, sym)
	page.queue_free()
	await frames(3)
	# 西游存档：子页直接加在页里，没有外框
	_state(false)
	var old := XOptionsScene.new()
	add_child(old)
	await frames(3)
	var qi := old._list.find_custom(func(o): return o[1] == "codexQuality")
	old.index = qi
	old.ok()
	await frames(3)
	check("sub_xiyou_no_host", old._page != null and old.get_node_or_null("SkinSubPageHost") == null and old._page.get_parent() == old)
	old.queue_free()
	await frames(3)


# ---- 文本输入、返回标题 ----
func _prompt_and_end() -> void:
	_state()
	var tp := XTextPrompt.new()
	tp.setup("给存档起个名字", "存档甲")
	add_child(tp)
	await frames(3)
	check("prompt_skinned", tp.get_child(0) is ColorRect and tp.edit.has_theme_stylebox_override("focus"))
	await shots("ui_skin_5c_text_prompt")
	tp.queue_free()
	var end := XGameEndPanel.new()
	end.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(end)
	await frames(3)
	check("end_skin_text", end._skin and end._holder != null)
	check("end_centered_offset", is_equal_approx(end._holder.position.x, maxf(roundf((get_viewport().get_visible_rect().size.x - 1280.0) / 2.0), 0.0)))
	var got := {"title": 0, "closed": 0}
	end.to_title.connect(func(): got.title += 1)
	end.closed.connect(func(): got.closed += 1)
	end._unhandled_input(_act("ui_accept"))
	check("end_first_returns_title", got.title == 1)
	end._unhandled_input(_act("ui_down"))
	end._unhandled_input(_act("ui_accept"))
	check("end_second_cancels", got.closed == 1 and got.title == 1)
	await shots("ui_skin_5c_game_end")
	end.queue_free()
	await frames(2)
	_state(false)
	var tp2 := XTextPrompt.new()
	tp2.setup("给存档起个名字", "存档甲")
	add_child(tp2)
	await frames(3)
	check("prompt_xiyou_old", not (tp2.get_child(0) is ColorRect) and not tp2.edit.has_theme_stylebox_override("focus"))
	tp2.queue_free()
	var end2 := XGameEndPanel.new()
	end2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(end2)
	await frames(3)
	check("end_xiyou_old", not end2._skin and end2._holder.position == Vector2.ZERO)
	end2.queue_free()
	await frames(2)
