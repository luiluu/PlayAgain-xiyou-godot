extends Node
## T304 卡 M「挂机设置及子页」专项（T254 3.8、版型三）：挂机设置主页＋技能次数／技能顺序／自动吃药／自动卖出四个子页套 XSkinSubPage。
## - 主页：13 行顺序照旧、行名＝参数 WD 名、值（范围数字／开关「开」「关」／子页「设置 ›」）与旧页一一对应、右牌说明＝旧说明窗那一句；
##   范围预览只在「挂机范围」一行出现、铺满右牌内宽、15×9 方格；Y／点预览看大图、取消／Y／点一下收回；确定 +1、左 −1 回绕照旧；
## - 子页：选人那一层合掉（直接进第一个出战成员、Q／E 换人）；吃药一页两枚页签（回生命、回魔法），每行一种药＋剩余＋开关，没药一行灰字；
##   卖出七档＋保留词条品质，两行说明进右牌；旧页每项新页都取得到（关掉开关建同一页逐行比）；
## - 设置主页进挂机设置：自带新皮肤、不套 1280×720 外框；开关关（SKIN_M＝false）时挂机仍走旧外框、旧窗口；西游存档旧画法；
## - 共用件三处：skin_list 灰行选中字色 #c9cbd0、skin_card「可选」节字号跟字体设置、skin_sub_page 简化档不淡入淡出。
## 带 -- --out=<目录> 且有窗口时截图（16:9 800×450、20:9 1000×450；各状态；字体 130%；旧画法对照）。
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
	if name.ends_with("_20x9"):
		check("shot_size_" + name, img.get_size() == Vector2i(1000, 450), img.get_size())
	elif name.ends_with("_16x9"):
		check("shot_size_" + name, img.get_size() == Vector2i(800, 450), img.get_size())


func shots(name: String, wide := true) -> void:
	if not windowed():
		return
	var win := get_window()
	var old := win.size
	var old_aspect := win.content_scale_aspect
	win.size = Vector2i(800, 450)
	await frames(14)
	await shot(name + "_16x9")
	if wide:
		win.unresizable = false
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
		win.size = Vector2i(1000, 450)
		DisplayServer.window_set_size(Vector2i(1000, 450))
		await get_tree().create_timer(0.6).timeout
		await frames(12)
		await shot(name + "_20x9")
	win.content_scale_aspect = old_aspect
	win.size = old
	await frames(4)


func _act(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _key(page: Node, action: String) -> void:
	page._unhandled_input(_act(action))


func _keycode(page: Node, code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	page._unhandled_input(e)


func _click(c: Control, at: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = at
	c.gui_input.emit(e)


func _state(tianqi := true) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	if tianqi:
		s.flags["tianqi"] = {"rules": 1}
	return s


## 假地图截图：1280×720 的格子图（每 48 一格深浅相间），预览里看得出格子对不对位
func _fake_shot() -> Texture2D:
	var img := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	for x in range(0, 1280, 48):
		for y in range(0, 720, 48):
			var c := Color(0.25, 0.42, 0.3) if (x / 48 + y / 48) % 2 == 0 else Color(0.32, 0.5, 0.36)
			img.fill_rect(Rect2i(x, y, 48, 48), c)
	img.fill_rect(Rect2i(48 * 10, 48 * 4, 48 * 3, 48), Color(0.55, 0.5, 0.45))   # 一段「墙」
	return ImageTexture.create_from_image(img)


func _options() -> XHangUpOptionsScene:
	var p := XHangUpOptionsScene.new()
	p.map_shot = _fake_shot()
	p.player_tile = Vector2(13, 7)
	add_child(p)
	await frames(4)
	return p


func _sub(kind: String) -> XHangUpSubPage:
	var p := XHangUpSubPage.new().setup(kind)
	add_child(p)
	await frames(4)
	return p


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_card_m")
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	await _main_page()
	await _range()
	await _counts_order()
	await _medication()
	await _sell()
	await _hosting()
	await _rollback()
	await _shared()
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


# ---- 挂机设置主页 ----
func _main_page() -> void:
	var s := _state()
	var p := await _options()
	var sk := p.skin
	if not check("main_built", sk != null and p.skin_self_hosted()):
		p.queue_free()
		return
	var n := XHangUpOptionsScene.SYMS.size()
	check("main_rows_13", n == 13 and sk.list.items.size() == n, sk.list.items.size())
	check("main_cat_hangup", sk.ring.items[sk.ring.index].key == "hangup", sk.ring.items[sk.ring.index])
	check("main_crumb", sk.crumb.size() == 2 and str(sk.crumb[1]) == "挂机设置", sk.crumb)
	check("main_old_hidden", not p.title_win.visible and not p.range_win.visible and p.item_wins.all(func(w): return not w.visible))
	check("main_no_blur_bg", not p._black.visible and p.get_children().all(func(c): return not (c is TextureRect)))
	# 旧页每一项：名字、状态（范围数字／YES·NO→开·关／open→设置 ›）、说明窗
	for i in n:
		var sym: String = XHangUpOptionsScene.SYMS[i]
		var r: Dictionary = p.skin_rows()[i]
		var w: Array = XHangUpOptionsScene.words(sym)
		var want := ""
		if sym in XHangUpOptionsScene.SUBPAGES:
			want = "设置 ›"
		elif sym == "range":
			want = str(int(p.settings().range))
		else:
			want = "开" if p.settings().get(sym) else "关"
		check("main_row_%s" % sym, r.text == w[0] and r.right == want and sk.list.items[i].text == w[0], [r, w])
		var c: Dictionary = p.skin_card(i)
		check("main_card_%s" % sym, c.title == w[0] and c.desc == w[1], c)
	check("main_names_nonempty", p.skin_rows().all(func(r): return str(r.text) != ""))
	# 开关：确定、左右都取反（同旧页）
	var ti := XHangUpOptionsScene.SYMS.find("showInter")
	p.select(ti)
	await frames(2)
	var before: bool = true if p.settings().get("showInter") else false
	_key(p, "ui_accept")
	await frames(3)
	check("main_toggle_ok", (true if p.settings().get("showInter") else false) != before and sk.list.items[ti].right == ("开" if not before else "关"), sk.list.items[ti])
	_key(p, "ui_left")
	await frames(2)
	check("main_toggle_left", (true if p.settings().get("showInter") else false) == before)
	check("main_toggle_card_choices", p.skin_card(ti).sections[0].title == "可选" and p.skin_card(ti).sections[0].lines.size() == 2)
	# 点行：点非当前行＝选中，点当前行＝确定
	sk.list.index_changed.emit(2)
	await frames(2)
	check("main_click_select", p.index == 2, p.index)
	var v2: bool = true if p.settings().get(XHangUpOptionsScene.SYMS[2]) else false
	sk.list.activated.emit(2)
	await frames(2)
	check("main_click_ok", (true if p.settings().get(XHangUpOptionsScene.SYMS[2]) else false) != v2)
	p.select(1)
	await frames(3)
	await shots("M_挂机设置_常态")
	XFontScale.set_value("global", 130)
	await frames(3)
	await shots("M_挂机设置_字体130", false)
	XFontScale.set_value("global", 100)
	# 子页行：确定进入子页（照旧先切同名字段），取消回来
	var si := XHangUpOptionsScene.SYMS.find("AutomaticSellWeapon")
	p.select(si)
	await frames(2)
	_key(p, "ui_accept")
	await frames(4)
	check("main_open_sub", p._page != null and p._page.kind == "sell" and p._page.skin != null and not sk.visible, p._page)
	if p._page != null:
		check("main_sub_crumb", p._page.skin.crumb == ["挂机与操作", "挂机设置", XHangUpOptionsScene.words("AutomaticSellWeapon")[0]], p._page.skin.crumb)
		_key(p._page, "ui_cancel")
		await frames(4)
	check("main_back_from_sub", p._page == null and sk.visible and not p.title_win.visible and not p._big.visible and not p._black.visible)
	# 取消：closed
	var closed := [false]
	p.closed.connect(func(): closed[0] = true)
	_key(p, "ui_cancel")
	check("main_cancel_closes", closed[0])
	p.queue_free()
	await frames(2)


# ---- 范围预览、大图 ----
func _range() -> void:
	var s := _state()
	var p := await _options()
	var sk := p.skin
	p.select(0)
	await frames(3)
	var prev := p._preview
	var c := sk.card
	check("range_preview_shown", prev.visible, prev.visible)
	check("range_preview_full_width", is_equal_approx(prev.size.x, c.size.x - c.pad * 2.0), [prev.size, c.size])
	var box := p.preview_box()
	check("range_preview_15x9", is_equal_approx(box.size.x / 15.0, box.size.y / 9.0), box)
	check("range_reserve", is_equal_approx(c.reserve_bottom, p.preview_height()), [c.reserve_bottom, p.preview_height()])
	check("range_preview_inside_card", prev.position.y + prev.size.y <= c.size.y - c.pad + 0.5, [prev.position, prev.size, c.size])
	await shots("M_挂机设置_选范围")
	# 确定 +1、左 −1、1～max 回绕
	var mx := XHangUpOptionsScene.max_range()
	p.settings().range = mx
	_key(p, "ui_accept")
	await frames(2)
	check("range_ok_wraps", int(p.settings().range) == 1 and sk.list.items[0].right == "1", p.settings().range)
	_key(p, "ui_left")
	await frames(2)
	check("range_left_wraps", int(p.settings().range) == mx, p.settings().range)
	p.settings().range = 5
	p._refresh()
	await frames(2)
	check("range_lattice_5", p.lattice().size() == 60, p.lattice().size())   # 曼哈顿 ≤5 共 61 格去掉玩家格
	# 大图：Y 打开、取消收回；点一下也收回；点预览打开
	_keycode(p, KEY_Y)
	await frames(2)
	check("range_y_opens_big", p._big.visible and p.skin_hints() == [["取消", "收起"]])
	var r := p.big_rect()
	check("range_big_size", r.size.x <= 854.0 and is_equal_approx(r.size.x / r.size.y, 854.0 / 480.0), r)
	await shots("M_挂机设置_范围大图")
	var rng := int(p.settings().range)
	_key(p, "ui_down")
	await frames(2)
	check("range_big_swallows_keys", p.index == 0 and p._big.visible, p.index)
	_key(p, "ui_cancel")
	await frames(2)
	check("range_cancel_closes_big", not p._big.visible and int(p.settings().range) == rng)
	_click(prev, prev.size / 2.0)
	await frames(2)
	check("range_tap_preview_opens", p._big.visible)
	_click(p._big, Vector2(5, 5))
	await frames(2)
	check("range_tap_big_closes", not p._big.visible)
	_keycode(p, KEY_Y)
	_keycode(p, KEY_Y)
	await frames(2)
	check("range_y_toggles", not p._big.visible)
	# 别的行：没有预览，Y 不开大图
	p.select(1)
	await frames(3)
	check("range_preview_only_on_range", not prev.visible and is_equal_approx(sk.card.reserve_bottom, 0.0))
	_keycode(p, KEY_Y)
	await frames(2)
	check("range_y_other_row_noop", not p._big.visible)
	# 没截图时预览照样画（黑底＋格子），不报错
	p.map_shot = null
	p.select(0)
	await frames(3)
	check("range_no_shot_ok", prev.visible)
	p.queue_free()
	await frames(2)


# ---- 技能次数、技能顺序 ----
func _counts_order() -> void:
	var s := _state()
	var actors := XHangUpAuto.actors(s)
	var p := await _sub("actors_count")
	check("counts_merged", p.kind == "counts" and p.switch_actor and p.actor == actors[0] and p.skin != null, p.kind)
	check("counts_ring_hidden_left_actor", not p.skin.ring.visible and p._left != null and p._left.visible)
	# 旧页逐行：关掉开关建同一页同一个人，比名字、次数
	XHangUpOptionsScene.SKIN_M = false
	var old := XHangUpSubPage.new().setup("counts", actors[0])
	add_child(old)
	await frames(3)
	XHangUpOptionsScene.SKIN_M = true
	check("counts_old_has_no_skin", old.skin == null and old.win.visible)
	var orows: Array = old.rows()
	var nrows: Array = p.skin_rows()
	check("counts_rows_count", orows.size() == nrows.size() and orows.size() >= 2, [orows.size(), nrows.size()])
	for i in mini(orows.size(), nrows.size()):
		var k := int(orows[i][1])
		check("counts_row_%d" % i, nrows[i].text == orows[i][0] and nrows[i].right == ("%d 次" % k if k > 0 else "不用"), [nrows[i], orows[i]])
	old.queue_free()
	# → 加一次、← 减一次（0～20 回绕）
	p.select(0)
	var c0 := int(XHangUpAuto.counts(s, p.actor, p._skills)[0])
	_key(p, "ui_right")
	await frames(2)
	check("counts_right_plus", int(XHangUpAuto.counts(s, p.actor, p._skills)[0]) == (c0 + 1 if c0 < 20 else 0))
	_key(p, "ui_left")
	await frames(2)
	check("counts_left_minus", int(XHangUpAuto.counts(s, p.actor, p._skills)[0]) == c0)
	_key(p, "ui_right")
	_key(p, "ui_right")
	_key(p, "ui_right")
	await frames(3)
	await shots("M_技能次数_常态")
	# Q／E 换人
	_keycode(p, KEY_E)
	await frames(3)
	check("counts_e_next_actor", actors.size() < 2 or p.actor == actors[1], p.actor.display_name())
	check("counts_e_rows_follow", p.skin.list.items.size() == XHangUpAuto.bet_skills(p._logic, p.actor).size())
	_keycode(p, KEY_Q)
	await frames(2)
	check("counts_q_back", p.actor == actors[0])
	_click(p._left, Vector2(p._left.size.x * 0.75, 10))
	await frames(2)
	check("counts_tap_left_next", actors.size() < 2 or p.actor == actors[1])
	check("counts_crumb", p.skin.crumb.size() == 3 and str(p.skin.crumb[2]) == "技能次数", p.skin.crumb)
	XFontScale.set_value("global", 130)
	await frames(3)
	await shots("M_技能次数_字体130", false)
	XFontScale.set_value("global", 100)
	p.queue_free()
	await frames(2)
	# 顺序页
	var q := await _sub("actors_order")
	check("order_merged", q.kind == "order" and q.switch_actor and q.skin != null)
	XHangUpOptionsScene.SKIN_M = false
	var oldq := XHangUpSubPage.new().setup("order", actors[0])
	add_child(oldq)
	await frames(3)
	XHangUpOptionsScene.SKIN_M = true
	var oq: Array = oldq.rows()
	var nq: Array = q.skin_rows()
	check("order_rows_count", oq.size() == nq.size(), [oq.size(), nq.size()])
	for i in mini(oq.size(), nq.size()):
		check("order_row_%d" % i, nq[i].text == "%s　%s" % [oq[i][1], oq[i][0]], [nq[i], oq[i]])
	oldq.queue_free()
	if nq.size() >= 2:
		q.select(1)
		var moved: String = str(q._order.skills[1].skill.name)
		_key(q, "ui_accept")
		await frames(2)
		check("order_ok_moves_up", str(q._order.skills[0].skill.name) == moved, moved)
	await shots("M_技能顺序_常态", false)
	q.queue_free()
	await frames(2)


# ---- 自动吃药 ----
func _medication() -> void:
	var s := _state()
	s.items[1] = 3
	s.items[2] = 5
	var p := await _sub("medication")
	check("med_merged", p.kind == "med_tabs" and p.tab == 0 and p.skin != null and p._tabs != null)
	# 旧页：hp 页一行一种药＋剩余＋开关；新页第 0 行比例、后面药
	XHangUpOptionsScene.SKIN_M = false
	var oldm := XHangUpSubPage.new().setup("medication")
	add_child(oldm)
	await frames(3)
	var omed: Array = oldm.rows()
	oldm.queue_free()
	var oldh := XHangUpSubPage.new().setup("hp")
	add_child(oldh)
	await frames(3)
	var ohp: Array = oldh.rows()
	oldh.queue_free()
	XHangUpOptionsScene.SKIN_M = true
	var rows: Array = p.skin_rows()
	# 旧吃药页的「Hp恢复开关」「Mp恢复开关」两行（进入各自的药页）＝新页两枚页签
	check("med_switch_rows_are_tabs", omed.size() == 4 and omed[0][0] == "Hp恢复开关" and omed[1][0] == "Mp恢复开关"
		and XHangUpSubPage.TAB_NAMES == ["回生命的", "回魔法的"] and p.tab == 0, omed)
	check("med_rate_row", rows[0].text == omed[2][0] and rows[0].right == str(omed[2][1]) + "%", [rows[0], omed[2]])
	check("med_hp_rows_count", rows.size() == ohp.size() + 1, [rows.size(), ohp.size()])
	for i in ohp.size():
		var e: Dictionary = p._potions[i]
		var nm := str(XDB.rec("Items", int(e.id)).get("name", ""))
		check("med_hp_row_%d" % i, ohp[i][0] == "%s 剩余:%d" % [nm, int(e.num)] and rows[i + 1].text == nm and rows[i + 1].sub == "剩余 %d" % int(e.num)
			and rows[i + 1].right == ("开" if ohp[i][1] == "ON" else "关"), [rows[i + 1], ohp[i]])
	# 比例 +10、药开关
	var hv := int(XHangUpAuto.recovery(s).HpV)
	_key(p, "ui_accept")
	await frames(2)
	check("med_rate_plus10", int(XHangUpAuto.recovery(s).HpV) == (hv + 10 if hv < 100 else 10))
	if rows.size() > 1:
		p.select(1)
		var was: String = p.skin_rows()[1].right
		_key(p, "ui_accept")
		await frames(2)
		check("med_potion_toggle", p.skin_rows()[1].right != was, [was, p.skin_rows()[1].right])
	p.select(1 if rows.size() > 1 else 0)
	await frames(3)
	await shots("M_自动吃药_回生命")
	# 页签：E 换到回魔法
	_keycode(p, KEY_E)
	await frames(3)
	check("med_tab_mp", p.tab == 1 and p.index == 0 and p.skin_rows()[0].text == omed[3][0], p.skin_rows()[0])
	XHangUpOptionsScene.SKIN_M = false
	var oldmp := XHangUpSubPage.new().setup("mp")
	add_child(oldmp)
	await frames(3)
	var omp: Array = oldmp.rows()
	oldmp.queue_free()
	XHangUpOptionsScene.SKIN_M = true
	var mrows: Array = p.skin_rows()
	check("med_mp_rows_count", mrows.size() == omp.size() + 1, [mrows.size(), omp.size()])
	for i in omp.size():
		check("med_mp_row_%d" % i, str(omp[i][0]).begins_with(str(mrows[i + 1].text) + " 剩余:") and mrows[i + 1].right == ("开" if omp[i][1] == "ON" else "关"), [mrows[i + 1], omp[i]])
	await shots("M_自动吃药_回魔法", false)
	_click(p._tabs, p.tab_rect(0).get_center())
	await frames(2)
	check("med_tab_click", p.tab == 0)
	p.queue_free()
	await frames(2)
	# 没药：列表一行灰字（不退回），比例行照旧能改
	s.items.erase(1)
	s.items.erase(2)
	var e2 := await _sub("medication")
	var r2: Array = e2.skin_rows()
	check("med_empty_row", r2.size() == 2 and r2[1].text == "背包里没有这类药" and r2[1].get("disabled", false), r2)
	check("med_empty_not_closed", e2.is_inside_tree() and not e2.is_queued_for_deletion())
	e2.select(1)
	await frames(3)
	check("med_empty_selected_gray_hi", e2.skin.list.dis_color(1) == XSkinList.DIS_SEL)
	await shots("M_自动吃药_没药", false)
	e2.queue_free()
	await frames(2)


# ---- 自动卖出 ----
func _sell() -> void:
	var s := _state()
	var p := await _sub("sell")
	XHangUpOptionsScene.SKIN_M = false
	var old := XHangUpSubPage.new().setup("sell")
	add_child(old)
	await frames(3)
	XHangUpOptionsScene.SKIN_M = true
	check("sell_old_help_win", (old.help_win != null and old.help_win.visible) == XSafeSell.ENABLED)
	var orows: Array = old.rows()
	old.queue_free()
	var rows: Array = p.skin_rows()
	check("sell_rows_count", rows.size() == orows.size() and rows.size() == 1 + 7 + (1 if XSafeSell.ENABLED else 0), [rows.size(), orows.size()])
	for i in mini(rows.size(), orows.size()):
		check("sell_row_%d" % i, rows[i].text == orows[i][0] and rows[i].right == orows[i][1], [rows[i], orows[i]])
	check("sell_help_hidden", p.help_win == null or not p.help_win.visible)
	if XSafeSell.ENABLED:
		var c: Dictionary = p.skin_card(1)
		check("sell_help_in_card", c.sections.any(func(x): return str(x.get("text", "")) == XSafeSell.HELP), c)
	# 七档：确定整档切换
	p.select(1)
	var st0 := XHangUpAuto.grade_state(s, 0)
	_key(p, "ui_accept")
	await frames(2)
	check("sell_grade_toggle", XHangUpAuto.grade_state(s, 0) != st0 and p.skin_rows()[1].right != rows[1].right)
	check("sell_grade_choices", p.skin_card(1).sections[0].title == "可选" and p.skin_card(1).sections[0].lines.size() == 3)
	# 间隔：+1
	p.select(0)
	var ev := int(XHangUpAuto.sell_config(s).SellQuality)
	_key(p, "ui_accept")
	await frames(2)
	check("sell_every_plus", int(XHangUpAuto.sell_config(s).SellQuality) == (0 if ev > 10 else ev + 1))
	if XSafeSell.ENABLED:
		p.select(rows.size() - 1)
		var lb := XSafeSell.label(s)
		_key(p, "ui_right")
		await frames(2)
		check("sell_safe_right", XSafeSell.label(s) != lb and p.skin_rows()[rows.size() - 1].right == XSafeSell.label(s))
		p.select(rows.size() - 1)
	await frames(3)
	await shots("M_自动卖出_常态")
	p.queue_free()
	await frames(2)


# ---- 设置主页进挂机 ----
func _hosting() -> void:
	_state()
	var opt := XOptionsScene.new()
	add_child(opt)
	await frames(4)
	var hi: int = opt.symbols().find("HangUp")
	if not check("host_hangup_row", hi >= 0):
		opt.queue_free()
		return
	opt.index = hi
	opt._refresh()
	await frames(2)
	opt.ok()
	await frames(4)
	var pg: Node = opt._page
	check("host_self", pg is XHangUpOptionsScene and pg.get_parent() == opt and pg.skin != null, pg)
	check("host_no_wrapper", opt.find_child("SkinSubPageHost", false, false) == null)
	check("host_ring_follows_main", pg.skin.ring.items.size() == opt.skin.ring.items.size() and pg.skin.ring.index == opt.skin.cur)
	check("host_cat_hangup", pg.skin.ring.items[pg.skin.ring.index].key == "hangup")
	check("host_crumb_cat", str(pg.skin.crumb[0]) == str(opt.skin.cats[opt.skin.cur].name), pg.skin.crumb)
	check("host_main_hidden", not opt.skin.visible)
	await shots("M_主页进挂机_常态", false)
	# 进技能次数：环跟主页、左块换成角色
	var si: int = XHangUpOptionsScene.SYMS.find("SetSkilllist")
	pg.select(si)
	await frames(2)
	_key(pg, "ui_accept")
	await frames(4)
	var sub: Node = pg._page
	check("host_counts_open", sub is XHangUpSubPage and sub.kind == "counts" and sub.skin != null and sub.skin.crumb.size() == 3, sub)
	if sub != null:
		await shots("M_主页进技能次数_常态")
		_key(sub, "ui_cancel")
		await frames(3)
	_key(pg, "ui_cancel")
	await frames(3)
	check("host_closed", opt._page == null and opt.skin.visible)
	# 开关关：挂机仍走旧外框（1280×720）、旧窗口可见、不建新页
	XHangUpOptionsScene.SKIN_M = false
	opt.index = hi
	opt._refresh()
	await frames(2)
	opt.ok()
	await frames(4)
	var op: Node = opt._page
	check("host_off_wrapper", op is XHangUpOptionsScene and op.get_parent().name == "SkinSubPageHost" and op.get_parent().size == Vector2(1280, 720), op.get_parent().name if op else null)
	check("host_off_old", op != null and op.skin == null and not op.skin_self_hosted() and op.title_win.visible and op.range_win.visible)
	check("host_off_status_old", op != null and op.status_text(XHangUpOptionsScene.SYMS.find("SetSkilllist")) == "进入")
	if op != null:
		_key(op, "ui_cancel")
		await frames(3)
	XHangUpOptionsScene.SKIN_M = true
	opt.queue_free()
	await frames(2)


# ---- 回退 ----
func _rollback() -> void:
	_state()
	XHangUpOptionsScene.SKIN_M = false
	var p := await _options()
	check("rb_off_main", p.skin == null and p.title_win.visible and p.item_wins.size() == 13 and p._preview == null)
	await shots("M_旧画法对照_挂机设置", false)
	p.queue_free()
	for k in ["actors_count", "medication", "sell"]:
		var q := await _sub(k)
		check("rb_off_sub_%s" % k, q.skin == null and q.kind == k and q.win.visible, q.kind)
		q.queue_free()
	await frames(2)
	XHangUpOptionsScene.SKIN_M = true
	# XSkinSubPage 总开关关也回旧画法
	XSkinSubPage.ENABLED = false
	var p2 := await _options()
	check("rb_subpage_off_main", p2.skin == null and p2.title_win.visible)
	p2.queue_free()
	XSkinSubPage.ENABLED = true
	# 西游存档：旧画法
	_state(false)
	var p3 := await _options()
	check("rb_xiyou_main", p3.skin == null and p3.title_win.visible)
	p3.queue_free()
	var q3 := await _sub("sell")
	check("rb_xiyou_sub", q3.skin == null and q3.win.visible)
	q3.queue_free()
	await frames(2)


# ---- 共用件三处 ----
func _shared() -> void:
	_state()
	# skin_list：灰行选中字色 #c9cbd0，没选中／列表不活动／开关关时 TEXT_3
	var l := XSkinList.new()
	l.columns = 1
	add_child(l)
	l.size = Vector2(400, 200)
	l.set_items([{"text": "a"}, {"text": "b", "disabled": true}])
	l.select(1, false)
	l.active = true
	check("shared_dis_sel", l.dis_color(1) == Color("c9cbd0"), l.dis_color(1))
	check("shared_dis_unsel", l.dis_color(0) == XUiSkin.TEXT_3)
	l.active = false
	check("shared_dis_inactive", l.dis_color(1) == XUiSkin.TEXT_3)
	l.active = true
	XSkinList.DIS_SEL_ON = false
	check("shared_dis_off", l.dis_color(1) == XUiSkin.TEXT_3)
	XSkinList.DIS_SEL_ON = true
	l.queue_free()
	# skin_card：lines 节行高随字号撑开；开关关回写死 30
	check("shared_line_h_100", is_equal_approx(XSkinCard.line_h(), 30.0), XSkinCard.line_h())
	XFontScale.set_value("global", 130)
	var lh130 := XSkinCard.line_h()
	check("shared_line_h_130", lh130 > 30.0 and lh130 >= XUiSkin.fs(21) * 1.2, lh130)
	XSkinCard.LINES_V2 = false
	check("shared_line_h_off", is_equal_approx(XSkinCard.line_h(), 30.0))
	XSkinCard.LINES_V2 = true
	# 130% 下「可选」节比 100% 高（字号跟着放大）
	var card := XSkinCard.new()
	add_child(card)
	card.setup({"title": "x", "sections": [XSkinSubPage.choices_section(["一", "二", "三", "四", "五"], 0, 1)]})
	var h130 := card.natural_height(312)
	XFontScale.set_value("global", 100)
	var h100 := card.natural_height(312)
	check("shared_choices_grow_130", h130 > h100, [h100, h130])
	check("shared_ascii", XSkinCard._ascii("12%") and not XSkinCard._ascii("现在"))
	card.queue_free()
	# skin_sub_page：简化档淡出／淡入立刻到位（不再 0.12 秒）
	var p := await _sub("sell")
	XUiSkin.motion_override = XUiSkin.Motion.SIMPLE
	p.skin.fade_out()
	check("shared_simple_fade_out_instant", not p.skin.visible and is_equal_approx(p.skin.modulate.a, 0.0) and p.skin._fade == null)
	p.skin.fade_in()
	check("shared_simple_fade_in_instant", p.skin.visible and is_equal_approx(p.skin.modulate.a, 1.0))
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	p.skin.fade_out()
	check("shared_full_fade_tween", p.skin._fade != null and p.skin.visible)
	await get_tree().create_timer(0.25).timeout
	check("shared_full_fade_done", not p.skin.visible)
	p.skin.fade_in()
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	p.queue_free()
	await frames(2)
