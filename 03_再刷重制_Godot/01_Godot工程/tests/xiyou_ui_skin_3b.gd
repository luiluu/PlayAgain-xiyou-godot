extends Node
## 新界面第 3B 批（ui-skin-3b）：天启篇标题（清册 #4）、四线选线卡（#76）、方桌提示（#77）、异化工坊（#78）。
## - 标题：skin_on() 开发构建开、发行构建（simulate_release）／ENABLED = false 不开；开着时 T4 光标藏起、红乙选中条垫在选中项后、
##   上下移动选中条跟着走，确定照旧执行；extras 里的按钮换黑面板细线；关着没有选中条、光标照旧显示。
## - 选线卡：天启篇存档开（skin）、左右循环、确定／取消返回的值同旧；卡带 skin 画法、按键提示；ENABLED = false 走旧画法。
## - 方桌提示：三种状态的字；面朝方桌、没在跑事件、新皮肤开着才显示，忙时、背对、关掉都不显示。
## - 异化工坊：节点树（flatten）开关两边一致；开着时页签（异化装备／异化核／装备重铸）、Q／E 换页、列表与操作栏；
##   点屏上的按钮走旧逻辑（分解→确认框→确认分解真的分解）；关着照旧（PaneFrame 面板）。
## 加 -- --out=<目录> 且有窗口时存截图（16:9、20:9）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		if arg == "--touch":   # 收口批：按触屏画（提示胶囊）
			XUiSkin.touch_override = 1
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(str(detail)))
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


## 16:9 拍一张；有窗口时再把窗口拉到 1600×720 拍 20:9
func shots(name: String, settle := 20) -> void:
	await frames(settle)
	await shot(name + "_16x9")
	if windowed():
		var win := get_window()
		var old := win.size
		win.size = Vector2i(1600, 720)
		await frames(settle)
		await shot(name + "_20x9")
		win.size = old
		await frames(5)


func _key(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_3b")
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	await _title()
	await _cards()
	await _table()
	await _workshop()
	XUiSkin.ENABLED = true
	XUiSkin.motion_override = -1
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 天启篇状态 ----

func _tq_state(line := "") -> XState:
	var ids := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id)).slice(0, 4)
	var s := XTianqi.start_new_game(3, "jianxian", ids)
	XTianqi.take_pending()
	for id in ids:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 0
	XState.current = s
	if line != "":
		s.flags.tianqi["line"] = line
	return s


# ---- 标题 ----

func _title() -> void:
	XState.current = null
	# T102：skin_on() 现在也看「界面风格」设置；先钉成「新」，不随本机 options.json 变（只改内存）
	XConfig.ensure_loaded()
	XConfig._values["codexUiSkin"] = true
	check("title_skin_dev_on", XTianqiTitle.skin_on())
	check("title_xiyou_skin_untouched", not XUiSkin.on())   # 皮肤层本身在标题照旧不开（p0 口径），标题自己按构建判断
	ReleaseEntry.simulate_release = true
	check("title_skin_release_off", not XTianqiTitle.skin_on())
	ReleaseEntry.simulate_release = false
	XUiSkin.ENABLED = false
	check("title_skin_disabled_off", not XTianqiTitle.skin_on())
	XUiSkin.ENABLED = true
	# T102：标题和开局三页共用 skin_on()，设置「界面风格」选原版（codexUiSkin＝false）时回旧框（只改内存，不写本机设置）
	XConfig._values["codexUiSkin"] = false
	check("title_skin_setting_old_off", not XTianqiTitle.skin_on())
	XConfig._values["codexUiSkin"] = true   # 本测试后面都按「新」（只在内存里，不写回本机设置）
	check("title_skin_setting_new_on", XTianqiTitle.skin_on())
	if not XTianqiTitle.available():
		check("title_assets", false, "content/title 素材不全")
		return
	var hit := []
	var acts := {"new_game": func(): hit.append("new_game"), "load": func(): hit.append("load"),
		"options": func(): hit.append("options"), "achievements": func(): hit.append("achievements"),
		"check_update": func(): hit.append("check_update"), "back_to_menu": func(): hit.append("back")}
	XTianqiTitle.last_key = ""
	var t := XTianqiTitle.new()
	t.setup(acts, [])
	add_child(t)
	var extra := Button.new()
	extra.text = "继续（切后台时自动存的档）"
	extra.size = Vector2(280, 40)
	t.extras.add_child(extra)
	await frames(3)
	check("title_skin_bar", t.skin_bar != null and not t.cursor.visible and t.skin_bar.get_parent() == t.menu and t.skin_bar.get_index() == 0)
	var r0: Rect2 = t.skin_bar.target
	var b0: Button = t.item(t.selected()).node
	check("title_bar_on_selected", absf(r0.get_center().y - (b0.position.y + b0.size.y / 2.0)) <= 1.0 and absf(r0.get_center().x - (b0.position.x + b0.size.x / 2.0)) <= 1.0, [r0, b0.position])
	var sel0 := t.selected()
	t.move(1)
	t.step(0.2)
	t.skin_bar.advance(0.2)
	var b1: Button = t.item(t.selected()).node
	check("title_bar_follows", t.selected() == sel0 + 1 and absf(t.skin_bar.current_rect().get_center().y - (b1.position.y + b1.size.y / 2.0)) <= 1.0)
	check("title_extras_skinned", extra.has_meta("skin_done") and extra.get_theme_stylebox("hover") is XSkinSelectStyle
		and t.back_button.has_meta("skin_done"))
	check("title_extras_keep_size", extra.size == Vector2(280, 40), extra.size)   # entry.gd 按原大小上下叠放（反馈群号与问卷）
	check("title_hints", t.skin_hints != null and t.skin_hints.hints.size() == 2)
	# 收口批返修（小A核 P1-1）：触屏胶囊高 44，整颗留在画面里
	var to0 := XUiSkin.touch_override
	XUiSkin.touch_override = 1
	t.skin_hints.set_hints(t.skin_hints.hints)
	t._layout()
	var vy := t.get_viewport_rect().size.y
	check("title_touch_hints_inside", t.skin_hints.position.y + t.skin_hints.height() <= vy - XUiSkin.HINT_BOTTOM + 0.5, [t.skin_hints.position, vy])
	XUiSkin.touch_override = to0
	t.skin_hints.set_hints(t.skin_hints.hints)
	t._layout()
	check("title_activate_same", t.activate() and hit == [str(XTianqiTitle.COMMANDS[sel0 + 1].key)], hit)
	await shots("ui_skin_3b_title")
	t.queue_free()
	await frames()
	# 关掉：没有选中条，T4 光标照旧
	XUiSkin.ENABLED = false
	var t2 := XTianqiTitle.new()
	t2.setup(acts, [])
	add_child(t2)
	await frames(3)
	check("title_off_old", t2.skin_bar == null and t2.cursor.visible and t2.skin_hints == null)
	t2.queue_free()
	XUiSkin.ENABLED = true
	await frames()


# ---- 选线卡 ----

func _cards() -> void:
	var s := _tq_state()
	check("cards_skin_on", XUiSkin.on())
	var c := XTianqiLineCards.new()
	c.lines = XTianqi.LINES
	c.playable = [true, true, false, true]
	add_child(c)
	await frames(3)
	check("cards_skin", c.skin and c._cards.size() == 4 and c._cards.all(func(k): return k.skin) and c._hints != null)
	check("cards_min_font", c._cards.all(func(k): return k.get_children().filter(func(l): return l is Label).all(func(l): return l.get_theme_font_size("font_size") >= XUiSkin.FS_MIN)))
	var hr := Rect2(c._hints.position, c._hints.size)
	check("cards_hints_clear_version", hr.end.x <= XSkinKeyHints.right_edge(c.size) + 0.5 and (not XVersionLabel.SHOW or hr.end.x < c.size.x - XVersionLabel.MARGIN.x - 16.0), [hr, c.size])
	check("cards_unready_text", c._cards[2].get_children().any(func(l): return l is Label and l.text == "暂未开放"))
	check("cards_inside_safe", c._cards[0].position.x >= XSkinLayout.margin_for(c.size.x) and c._cards[3].position.x + c._cards[3].size.x <= c.size.x - XSkinLayout.margin_for(c.size.x), [c._cards[0].position, c.size])
	await shots("ui_skin_3b_line_cards")
	c._handle(_key("ui_left"))
	check("cards_left_wrap", c.index == 3 and c._cards[3].selected)
	c._handle(_key("ui_right"))
	c._handle(_key("ui_right"))
	var out := []
	c.decided.connect(func(i): out.append(i))
	c._handle(_key("ui_accept"))
	check("cards_accept_same", out == [1], out)
	c.queue_free()
	await frames()
	var c2 := XTianqiLineCards.new()
	c2.lines = XTianqi.LINES
	c2.playable = [true, true, true, true]
	add_child(c2)
	await frames(2)
	var out2 := []
	c2.decided.connect(func(i): out2.append(i))
	c2._handle(_key("ui_cancel"))
	check("cards_cancel_same", out2 == [-1], out2)
	c2.queue_free()
	XUiSkin.ENABLED = false
	var c3 := XTianqiLineCards.new()
	c3.lines = XTianqi.LINES
	c3.playable = [true, true, true, true]
	add_child(c3)
	await frames(2)
	check("cards_off_old", not c3.skin and c3._hints == null and c3._cards.all(func(k): return not k.skin))
	c3.queue_free()
	XUiSkin.ENABLED = true
	await frames()


# ---- 方桌提示 ----

class FakePlayer extends RefCounted:
	var direction := 8
	var grid := Vector2i(14, 13)
	func front_cell(d: int) -> Vector2i:
		return grid + (Vector2i(0, -1) if d == 8 else Vector2i(0, 1))


class FakeHost extends Node2D:
	var player = FakePlayer.new()
	var busy := false


func _table() -> void:
	check("table_text", XTianqiTable.chip_text("hint", "") == "调查" and XTianqiTable.chip_text("split", "") == "选一条路"
		and XTianqiTable.chip_text("chosen", "war") == str(XTianqi.line_info("war").get("name", "")) + "之路" and XTianqiTable.chip_text("", "") == "")
	var s := _tq_state()
	s.set_variable(20, 6)
	var host := FakeHost.new()
	add_child(host)
	var t := XTianqiTable.new()
	host.add_child(t)
	t.setup()
	t._process(0.016)
	check("table_chip_facing", t.chip.visible and t.chip.text == XTianqiTable.chip_text(t.state, t.line), [t.state, t.chip.text])
	host.busy = true
	t._process(0.016)
	check("table_chip_busy_hidden", not t.chip.visible)
	host.busy = false
	host.player.direction = 2
	t._process(0.016)
	check("table_chip_away_hidden", not t.chip.visible)
	host.player.direction = 8
	XUiSkin.ENABLED = false
	t._process(0.016)
	check("table_chip_off_hidden", not t.chip.visible)
	XUiSkin.ENABLED = true
	if windowed():
		# 截图：黑底上放大看提示胶囊
		var bg := ColorRect.new()
		bg.color = Color(0.12, 0.1, 0.1)
		bg.size = Vector2(1280, 720)
		add_child(bg)
		host.move_to_front()
		host.position = Vector2(-13 * 48 + 640 - 72, -11 * 48 + 360)
		host.scale = Vector2(1, 1)
		t._process(0.016)
		await shots("ui_skin_3b_table_chip", 6)
		bg.queue_free()
	host.queue_free()
	await frames()


# ---- 异化工坊 ----

func _ws_state() -> XState:
	var s := _tq_state("plague")
	s.gain_item(XAlienation.stone_id(), 3)
	var i: Dictionary = XTianqiAlienGear.create(s, "armor", 52, "plague", "huaxing", "mimic").ok
	s.gear.append(i)
	XTianqiAlienGear.add_core(s, "plague", "insulation", "shigu", "test")
	s.gain_gear("armor", 53, 1)
	return s


func _find(n: Node, pred: Callable) -> Node:
	for c in n.get_children():
		if pred.call(c):
			return c
		var r := _find(c, pred)
		if r != null:
			return r
	return null


func _workshop() -> void:
	var s := _ws_state()
	XAlienWorkshop.selected = ""
	var page := XAlienWorkshop.new()
	add_child(page)
	await frames(4)
	var flat_on := XAlienWorkshop.flatten(page.tree)
	check("ws_skin", page.skin and page.root != null and page.root.name == "SkinPage")
	var names: Array = page.skin_tabs.map(func(x): return str(x[0]))
	check("ws_tabs", names.size() >= 3 and names[0] == "异化装备" and names.any(func(x): return x.begins_with("异化核")) and names.has("装备重铸"), names)
	check("ws_list_and_actions", _find(page, func(c): return c.name == "SkinList") != null and _find(page, func(c): return c.name == "SkinActions") != null)
	var acts: Node = _find(page, func(c): return c.name == "SkinActions")
	var dis: Button = _find(acts, func(c): return c is Button and c.text.begins_with("分解为"))
	check("ws_dismantle_in_bar", dis != null and not dis.disabled)
	await shots("ui_skin_3b_alien_workshop")
	# 换页
	var ev := InputEventKey.new()
	ev.keycode = KEY_E
	ev.pressed = true
	page._unhandled_input(ev)
	await frames(3)
	check("ws_tab_switch", page.skin_tab == 1 and page.skin_tab_name().begins_with(names[1]), page.skin_tab_name())
	await shots("ui_skin_3b_alien_workshop_tab2", 8)
	var pd := InputEventAction.new()
	pd.action = "ui_page_up"
	pd.pressed = true
	page._unhandled_input(pd)
	await frames(3)
	check("ws_tab_back_pageup", page.skin_tab == 0)
	var wh: XSkinKeyHints = page._skin_hints
	check("ws_hints_clear_version", wh.position.x + wh.size.x <= XSkinKeyHints.right_edge(page.size) + 0.5, [wh.position, wh.size])
	# 点屏上的按钮：分解→确认框→确认分解（走 XAlienation.dismantle）
	acts = _find(page, func(c): return c.name == "SkinActions")
	dis = _find(acts, func(c): return c is Button and c.text.begins_with("分解为"))
	dis.pressed.emit()
	await frames(4)
	check("ws_confirm_shown", page.confirming and XAlienWorkshop.flatten(page.tree).any(func(r): return str(r.get("text", "")) == "确认分解"))
	var focus := get_viewport().gui_get_focus_owner()
	check("ws_confirm_focus", focus is Button and (focus as Button).text == "确认分解", focus)
	await shots("ui_skin_3b_alien_workshop_confirm", 8)
	var n0 := s.gear.filter(func(e): return XTianqiAlienGear.is_tq(e)).size()
	var yes: Button = _find(page.root, func(c): return c is Button and c.text == "确认分解")
	yes.pressed.emit()
	await frames(4)
	check("ws_dismantle_done", s.gear.filter(func(e): return XTianqiAlienGear.is_tq(e)).size() == n0 - 1 and not page.confirming, [n0])
	page.queue_free()
	await frames()
	# 关掉：同一份存档的节点树和开着时一样，画面照旧（PaneFrame 面板）
	s = _ws_state()
	XAlienWorkshop.selected = ""
	XUiSkin.ENABLED = false
	var old := XAlienWorkshop.new()
	add_child(old)
	await frames(4)
	check("ws_off_old", not old.skin and _find(old, func(c): return c is PanelContainer and c.get_theme_stylebox("panel") is XAlienWorkshop.PaneFrame) != null)
	var flat_off := XAlienWorkshop.flatten(old.tree)
	check("ws_tree_same", JSON.stringify(_strip(flat_off)) == JSON.stringify(_strip(flat_on)), [flat_off.size(), flat_on.size()])
	old.queue_free()
	XUiSkin.ENABLED = true
	await frames()


## 节点树比较时去掉装备 uid 之类每次新建都不同的字（只比结构和标签）
func _strip(rows: Array) -> Array:
	return rows.map(func(r): return [r.get("tag"), r.get("depth"), r.get("class", ""), r.has("text")])
