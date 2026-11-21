extends Node
## 【cc·T365·未经审查】新界面卡 Q：成就簿 XSkinAchievementPage、更衣 XSkinChangeClothesPage、赌场数量框 XSkinCasinoDialog。
## - 门控：天启篇建新页；各页回退开关、西游存档都不建（旧窗口、旧控件照旧）。
## - 成就簿：T254 3.17 对应表逐行（环 8 球、环心、这一类「n / m」、行名字／条件／行尾「已获得」、未得不露名字条件、右牌各项、142／143 徽章图标、
##   不列宠物成就）；确定进列表、取消回类型、Q／E 翻页、取消关闭。
## - 更衣：3.13 对应表逐行（环 8 球、环心、列表两列、未解锁「？？？」、穿着小标、右牌各项、两枚钮）；确定换上、X 还原、取消回分类／离开。
## - 赌场框：3.19 对应表逐行（两行、数量选择、状态行够用绿／不够橙、进行态、停止态、20 连抽文案）；回车开始、Esc 取消；停止走 XCasinoBatch 原流程。
## 带 -- --out=<目录> 且有窗口时截图：每页 800×450＋1000×450（断言真尺寸）、各状态、字体 130%、旧画法对照。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results: Array = []
var out_dir := ""


class FakeParent extends RefCounted:
	var pending_lines: Array = []
	var skipped: Array = []
	var event_id := 60
	var host = null


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(800))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


## 真尺寸截图：窗口设成 sz，截出来的图必须正好 sz（不缩放）
func shot(name: String, sz := Vector2i(800, 450)) -> void:
	if not windowed():
		return
	var win := get_window()
	var old := win.size
	win.size = sz
	await frames(12)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	check("screenshot_size_" + name, img.get_size() == sz, [img.get_size(), sz])
	check("screenshot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK)
	win.size = old
	await frames(4)


func shots(name: String) -> void:
	if not windowed():
		return
	await shot(name + "_16x9", Vector2i(800, 450))
	await shot(name + "_20x9", Vector2i(1000, 450))


func act(page: Node, action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	page._unhandled_input(e)


func key(page: Node, k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	page._unhandled_input(e)


func _state(tianqi := true) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	if tianqi:
		s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian"}
	s.gold = 123456
	s.set_variable(206, 3)
	s.map_id = 4
	s.x = 10
	s.y = 10
	return s


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_card_q")
	get_viewport().gui_disable_input = windowed()
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XFontScale.set_value("global", 100)
	XAchievement.time_override = "2026年11月22日 12:34:56"
	await _achievement()
	await _clothes()
	await _casino()
	await _font_and_old()
	XUiSkin.motion_override = -1
	XFontScale.set_value("global", 100)
	XAchievement.time_override = ""
	XCasinoBatch.session = {}
	XState.current = null
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.5, true, false, true).timeout
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 成就簿 ----

func _own_some() -> Array:
	## 第一类里拿几项：头两项、第一个带特殊奖励的；返回这一类（去宠物后）的 id 列表
	XConfig.achievements().clear()
	var ids: Array = XTianqiPetHide.filter_achievements(XAchievement.of_type(str(XAchievement.types()[0])))
	var have: Array = [ids[0], ids[1]]
	for id in ids:
		if str(XAchievement.def(int(id)).evalText) != "" and not have.has(id):
			have.append(id)
			break
	for id in have:
		XConfig.achievements()[str(id)] = true
		XConfig.achievements()[str(id) + "Time"] = XAchievement.time_override
		XState.current.achievements[str(id)] = true   # 环心计数要全局和本局都有
	return ids


func _achievement() -> void:
	var s := _state()
	var ids := _own_some()
	XSkinAchievementPage.ENABLED = false
	var old := XAchievementScene.new()
	add_child(old)
	await frames(2)
	check("ach.gate.rollback_old", old.skin == null and old.type_win.visible and old.list_win.visible and old.count_win.visible)
	old.queue_free()
	XSkinAchievementPage.ENABLED = true
	s.flags.erase("tianqi")
	old = XAchievementScene.new()
	add_child(old)
	await frames(2)
	check("ach.gate.xiyou_old", old.skin == null)
	old.queue_free()
	s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian"}
	var p := XAchievementScene.new()
	var closed := [0]
	p.closed.connect(func(): closed[0] += 1)
	add_child(p)
	await frames(3)
	var sk := p.skin
	check("ach.gate.tianqi_builds", sk != null and not p.type_win.visible and not p.list_win.visible and not p.count_win.visible)
	# 对应表：类型窗 8 类 → 环上 8 个球
	var types := XAchievement.types()
	check("ach.ring_types", sk.ring.items.size() == types.size() and types.size() == 8 and sk.ring.items.map(func(c): return c.name) == types.map(func(t): return str(t)), sk.ring.items)
	check("ach.ring_orb_52", is_equal_approx(sk.ring.orb_radius * 2.0, 52.0))
	check("ach.ring_glyphs", sk.ring.items.all(func(c): return str(c.get("glyph", "")) == str(c.name).left(1)), sk.ring.items)
	# 计数窗 → 环心；这一类「n / m」→ 列表标题右边
	var n: Array = XAchievement.count(s)
	check("ach.ring_center", sk.ring_center == ["%d / %d" % n, "已获得"], sk.ring_center)
	check("ach.list_title_right", sk.list_title == str(types[0]) and sk.list_right == "%d / %d" % [ids.filter(func(i): return XAchievement.global_has(int(i))).size(), ids.size()], [sk.list_title, sk.list_right])
	# 列表：只含不隐藏宠物的；行 64 高两行式
	check("ach.rows_ids", sk.list.items.map(func(r): return r._id) == ids.map(func(i): return int(i)))
	check("ach.row_h_64", sk.list.row_height == 64)
	for r in sk.list.items:
		var d := XAchievement.def(int(r._id))
		if XAchievement.global_has(int(r._id)):
			check("ach.row_owned_%d" % int(r._id), r._name == str(d.name) and r._cond == str(d.trigger) and r.right == "◆ 已获得" and r.right_color == XUiSkin.GOLD and not r.disabled, r)
		else:
			check("ach.row_locked_%d" % int(r._id), r._name == "还没拿到" and r._cond == "拿到后才显示名字和条件" and r.disabled and not r.has("right") and not str(r).contains(str(d.name)), r)
	# 右牌：已得
	var cd := sk.card_data()
	var d0 := XAchievement.def(int(ids[0]))
	var date: String = XAchievement.time_override.split(" ")[0]
	check("ach.card_owned", cd.title == str(d0.name) and cd.subtitle == "%s · %s 拿到" % [d0.type, date] and str(cd.sections).contains(str(d0.trigger)) and str(cd.sections).contains("怎么拿"), cd)
	var with_reward := ids.filter(func(i): return XAchievement.global_has(int(i)) and str(XAchievement.def(int(i)).evalText) != "")
	if not with_reward.is_empty():
		p.index = ids.find(with_reward[0])
		p.mode = "list"
		p._refresh()
		var cr := sk.card_data()
		check("ach.card_reward", str(cr.sections).contains("特殊奖励") and str(cr.sections).contains(str(XAchievement.def(int(with_reward[0])).evalText)), cr)
		p.index = -1
		p.mode = "type"
		p._refresh()
	else:
		check("ach.card_reward", false, "没有带特殊奖励的成就可测")
	# 右牌：未得不露名字、条件
	var locked_i := -1
	for i in ids.size():
		if not XAchievement.global_has(int(ids[i])):
			locked_i = i
			break
	p.index = locked_i
	p.mode = "list"
	p._refresh()
	var cl := sk.card_data()
	check("ach.card_locked", cl.title == "还没拿到" and not str(cl).contains(str(XAchievement.def(int(ids[locked_i])).name)) and not str(cl).contains(str(XAchievement.def(int(ids[locked_i])).trigger)), cl)
	p.index = -1
	p.mode = "type"
	p._refresh()
	await shots("ach")
	# 键：确定进列表选第 0 项，列表里确定无反应，上下换项，Q／E 翻页，取消回类型
	act(p, "ui_accept")
	check("ach.ok_enters_list", p.mode == "list" and p.index == 0 and sk.focus == "list" and sk.list.index == 0)
	await shots("ach_list")
	act(p, "ui_accept")
	check("ach.list_ok_noop", p.mode == "list" and p.index == 0 and closed[0] == 0)
	act(p, "ui_down")
	check("ach.down_moves", p.index == 1 and sk.list.index == 1)
	key(p, KEY_E)
	check("ach.page_e_moves", sk.list.index >= 1 and p.index == sk.list.index, [p.index, sk.list.index])
	act(p, "ui_cancel")
	check("ach.cancel_back_to_type", p.mode == "type" and p.index == -1 and sk.focus == "ring" and closed[0] == 0)
	# 换类：下键在类型上换类，环、列表标题、列表跟着变
	act(p, "ui_down")
	check("ach.type_down", p.type_index == 1 and sk.ring.index == 1 and sk.list_title == str(types[1]), [p.type_index, sk.ring.index])
	act(p, "ui_right")
	check("ach.type_right", p.type_index == 2 and sk.ring.index == 2)
	# 点列表行＝进列表
	if sk.list.items.size() > 0:
		sk._on_list_index(0) if p.mode == "type" else null
	check("ach.click_row_enters_list", p.mode == "list" and p.index == 0, p.mode)
	act(p, "ui_cancel")
	act(p, "ui_cancel")
	check("ach.cancel_closes", closed[0] == 1)
	# 空类型：不画右牌
	p.queue_free()
	await frames(2)
	# 142／143 徽章图标：专用徽章走 Texture2D，普通成就走图标号
	check("ach.badge_icons", XSkinAchievementPage.icon_of(XAchievementBadge.KYO_ID, false) is Texture2D and XSkinAchievementPage.icon_of(XAchievementBadge.KYO_ID, true) is Texture2D
		and XSkinAchievementPage.icon_of(XAchievementBadge.ESSENCE_ID, true) is Texture2D and XSkinAchievementPage.icon_of(XAchievementBadge.ESSENCE_ID, false) == null)
	check("ach.icon_plain", XSkinAchievementPage.icon_of(int(ids[0]), true) == int(XAchievement.def(int(ids[0])).icon) and XSkinAchievementPage.icon_of(int(ids[0]), false) == null)
	# 宠物成就不列：每一类的列表都没有被隐藏的
	var pet_ok := true
	for t in types:
		var q := XAchievementScene.new()
		add_child(q)
		q.type_index = types.find(t)
		q._load_list()
		var want: Array = XTianqiPetHide.filter_achievements(XAchievement.of_type(str(t)))
		pet_ok = pet_ok and q.skin.list.items.map(func(r): return r._id) == want.map(func(i): return int(i))
		q.queue_free()
	check("ach.no_pet_rows", pet_ok)
	await frames(2)


# ---- 更衣 ----

func _unlock_some() -> Array:
	var cat0 := XChangeClothes.list(0)
	var picks := []
	for e in cat0:
		if picks.size() >= 3:
			break
		if str(e.get("characterName", "")) != "":
			picks.append(e)
	for e in picks:
		XChangeClothes.unlock(int(e.id))
	return picks


func _clothes() -> void:
	var s := _state()
	XConfig.clothes_unlocked().clear()
	var picks := _unlock_some()
	XSkinChangeClothesPage.ENABLED = false
	var old := XChangeClothesScene.new()
	add_child(old)
	await frames(2)
	check("cl.gate.rollback_old", old.skin == null and old.mode == "bottom" and old.cat_win.visible and old.bottom_win.visible)
	await shot("clothes_old_compare_16x9")
	old.queue_free()
	XSkinChangeClothesPage.ENABLED = true
	s.flags.erase("tianqi")
	old = XChangeClothesScene.new()
	add_child(old)
	await frames(2)
	check("cl.gate.xiyou_old", old.skin == null and old.mode == "bottom")
	old.queue_free()
	s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian"}
	var p := XChangeClothesScene.new()
	var closed := [0]
	p.closed.connect(func(): closed[0] += 1)
	add_child(p)
	await frames(3)
	var sk := p.skin
	check("cl.gate.tianqi_builds", sk != null and not p.cat_win.visible and not p.list_win.visible and not p.status_win.visible and not p.bottom_win.visible)
	check("cl.enter_on_category", p.mode == "category" and p.category == 0 and sk.focus == "ring")
	# 分类 8 档 → 环上 8 个球；环心「N / M 已解锁」
	check("cl.ring_8", sk.ring.items.size() == 8 and sk.ring.items.map(func(c): return c.name) == Array(XChangeClothes.CATEGORIES), sk.ring.items.size())
	check("cl.ring_orb_52", is_equal_approx(sk.ring.orb_radius * 2.0, 52.0))
	check("cl.ring_glyphs", sk.ring.items.all(func(c): return str(c.get("glyph", "")) == str(c.name).left(1)), sk.ring.items)
	var tot := XSkinChangeClothesPage.totals()
	var have := 0
	var all := 0
	for k in 8:
		for e in XChangeClothes.list(k):
			all += 1
			have += 1 if XChangeClothes.unlocked(int(e.id)) else 0
	check("cl.ring_center", sk.ring_center == ["%d / %d" % [have, all], "已解锁"] and tot == [have, all], [sk.ring_center, tot])
	# 名单两列、小人缩略＋名字；未解锁「？？？」变灰
	check("cl.two_columns", sk.list.columns == 2)
	var rows_ok := sk.list.items.size() == p.data.size()
	for k in p.data.size():
		var e: Dictionary = p.data[k]
		var r: Dictionary = sk.list.items[k]
		if XChangeClothes.unlocked(int(e.id)):
			rows_ok = rows_ok and r.text == str(e.name) and r.icon is Texture2D and not r.get("disabled", false)
		else:
			rows_ok = rows_ok and r.text == "？？？" and r.disabled and not r.has("icon")
	check("cl.rows_unlocked_locked", rows_ok)
	var open_n := sk.list.items.filter(func(r): return r._open).size()
	check("cl.list_right", sk.list_right == "%d / %d" % [open_n, p.data.size()], sk.list_right)
	# 右牌：预览本档第一项；两枚按钮；未进列表时「换上」灰
	var cd := sk.card_data()
	var e0: Dictionary = p.data[0]
	var how := XChangeClothes.source_text(e0).trim_prefix("获得途径：")
	check("cl.card_fields", cd.subtitle == "%s · %s" % [XChangeClothes.CATEGORIES[0], "已解锁" if XChangeClothes.unlocked(int(e0.id)) else "未解锁"]
		and str(cd.sections).contains("怎么拿到") and str(cd.sections).contains(how) and cd.buttons.size() == 2 and cd.buttons[0].text == "换上" and cd.buttons[1].text == "还原形象", cd)
	check("cl.wear_grey_in_category", cd.buttons[0].disabled)
	await shots("clothes")
	# 确定进列表、再确定换上（走旧 apply）
	act(p, "ui_accept")
	check("cl.ok_enters_list", p.mode == "list" and p.index == 0 and sk.focus == "list")
	check("cl.card_wear_on", not sk.card_data().buttons[0].disabled)
	var first_open := -1
	for k in p.data.size():
		if XChangeClothes.unlocked(int(p.data[k].id)):
			first_open = k
			break
	p._select(first_open)
	await shots("clothes_list")
	act(p, "ui_accept")
	var worn: Dictionary = p.data[first_open]
	check("cl.wear_applies", XSkinChangeClothesPage.is_worn(s, worn) and str(s.player_costume.characterName) == str(worn.characterName))
	check("cl.worn_tag", (sk.list.items[first_open].get("tags", []) as Array).has("穿着"), sk.list.items[first_open])
	await shots("clothes_worn")
	# 光标：上下走一整行（±2），左右 ±1（本档不够四格时只核不越界）
	p._select(0)
	if p.data.size() < 4:
		act(p, "ui_down")
		check("cl.down_wraps_small", p.index == 0, p.index)
		act(p, "ui_right")
		check("cl.right_small", p.index == 1, p.index)
		act(p, "ui_left")
		check("cl.left_back", p.index == 0, p.index)
	else:
		act(p, "ui_down")
		check("cl.down_moves_row", p.index == 2 and sk.list.index == 2, p.index)
		act(p, "ui_right")
		check("cl.right_moves_col", p.index == 3, p.index)
		act(p, "ui_left")
		act(p, "ui_up")
		check("cl.up_back", p.index == 0, p.index)
	# 未解锁一格：右牌不画小人、「换上」灰，确定提示「未解锁」不换
	var locked_k := -1
	for k in p.data.size():
		if not XChangeClothes.unlocked(int(p.data[k].id)):
			locked_k = k
			break
	if locked_k >= 0:
		p._select(locked_k)
		var cl := sk.card_data()
		check("cl.card_locked", cl.title == "？？？" and cl.buttons[0].disabled and cl.subtitle.ends_with("未解锁") and float(cl.reserve_bottom) == 0.0, cl)
		await shots("clothes_locked")
	# X 还原
	key(p, KEY_X)
	check("cl.x_restores", s.player_costume.is_empty() and not (sk.list.items[first_open].get("tags", []) as Array).has("穿着"), [s.player_costume, p.mode, p.data.size()])
	# 牌上按钮：还原形象钮、换上钮
	p._select(first_open)
	sk._on_card_button(0)
	check("cl.button_wear", XSkinChangeClothesPage.is_worn(s, worn))
	sk._on_card_button(1)
	check("cl.button_restore", s.player_costume.is_empty())
	# 满：条目最多的一档（一屏放不下、翻页件），多解锁几个
	var big := 0
	for k in 8:
		if XChangeClothes.list(k).size() > XChangeClothes.list(big).size():
			big = k
	act(p, "ui_cancel")
	p._select_category(big)
	for e in XChangeClothes.list(big).slice(0, 12):
		XChangeClothes.unlock(int(e.id))
	act(p, "ui_accept")
	check("cl.big_category_cursor_ok", p.data.size() > 4 and p.mode == "list", p.data.size())
	if p.data.size() > 4:
		p._select(0)
		act(p, "ui_down")
		check("cl.down_moves_row", p.index == 2 and sk.list.index == 2, p.index)
		act(p, "ui_right")
		check("cl.right_moves_col", p.index == 3, p.index)
		act(p, "ui_left")
		act(p, "ui_up")
		check("cl.up_back", p.index == 0, p.index)
		key(p, KEY_E)
		check("cl.page_e_moves", p.index > 0 and sk.list.index == p.index, [p.index, sk.list.index])
	await shots("clothes_full")
	# 换档：右键／取消回分类，环上换档名单跟着换
	p._select_category(0)
	act(p, "ui_cancel")
	check("cl.cancel_to_category", p.mode == "category" and p.index == -1 and closed[0] == 0, [p.mode, p.index, closed[0]])
	act(p, "ui_down")
	check("cl.category_moves", p.category == 1 and sk.ring.index == 1 and sk.list_title == XChangeClothes.CATEGORIES[1] and p.shown_category == 1, [p.category, sk.list_title])
	act(p, "ui_cancel")
	check("cl.cancel_closes", closed[0] == 1)
	p.queue_free()
	await frames(2)


# ---- 赌场数量框 ----

func _casino_open(mode: String, tickets: int) -> XCasinoDialog:
	var s := XState.current
	var have := s.item_count(XCasinoBatch.TICKET)
	s.gain_item(XCasinoBatch.TICKET, tickets - have)
	var rules: Dictionary = XCasinoBatch.MODES[mode]
	var se := {"parent": FakeParent.new(), "host": null, "mode": mode, "rules": rules, "state": "quantity", "requested": 0, "used": 0,
		"second": 0, "proof": 0, "new_proof": false, "initial_proof": false, "points": int(s.variable(XCasinoBatch.VAR_POINTS)),
		"samples": [], "stop": false}
	XCasinoBatch.session = se
	var dialog := XCasinoDialog.new()
	dialog.session = se
	se.dialog = dialog
	add_child(dialog)
	XSkinLayout.request_wide(dialog)   # 真游戏里赌场框坐在大厅地图上，地图已铺满；这里单拿出来拍 20:9，要自己要宽屏
	return dialog


func _casino_close() -> void:
	var se := XCasinoBatch.session
	if not se.is_empty():
		var dlg = se.get("dialog")
		XCasinoBatch.session = {}
		if is_instance_valid(dlg):
			dlg.queue_free()


func _casino() -> void:
	var s := _state()
	s.set_variable(XCasinoBatch.VAR_POINTS, 100)
	s.set_switch(XCasinoBatch.SWITCH_OPEN, true)
	# 门控
	XSkinCasinoDialog.ENABLED = false
	var old := _casino_open("single", 7)
	await frames(2)
	check("cs.gate.rollback_old", old.skin == null and old.input != null and old.max_button != null)
	await shot("casino_old_compare_16x9")
	_casino_close()
	await frames(2)
	XSkinCasinoDialog.ENABLED = true
	s.flags.erase("tianqi")
	old = _casino_open("single", 7)
	await frames(2)
	check("cs.gate.xiyou_old", old.skin == null and old.input != null)
	_casino_close()
	await frames(2)
	s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian"}
	# 单抽：两行、数量选择、状态行
	var dlg := _casino_open("single", 37)
	await frames(3)
	var sk := dlg.skin
	check("cs.gate.tianqi_builds", sk != null and dlg.input == null and sk.title == "自定义单抽")
	check("cs.rows_single", sk.stock_text() == "持有奖券 37 张" and sk.max_text() == "最多能抽 37 抽", [sk.stock_text(), sk.max_text()])
	check("cs.stepper_range", sk.stepper.min_value == 1 and sk.stepper.max_value == 37 and sk.stepper.value == 1 and sk.stepper.enabled)
	check("cs.status_preview", sk.status_text == "共 1 抽，消耗 1 张券；积分门槛 -30000。" and not sk.status_bad, sk.status_text)
	check("cs.default_focus_start", sk.index == 1 and sk.buttons.map(func(b): return b.text) == ["取消", "开始抽取"], [sk.index, sk.buttons])
	# 最多一下到顶；数量改了状态行跟着；键 ←/→ ±1、↑/↓ ±10
	sk.stepper.to_max()
	check("cs.max_to_top", sk.stepper.value == 37 and sk.status_text == "共 37 抽，消耗 37 张券；积分门槛 -30000。", [sk.stepper.value, sk.status_text])
	act(dlg, "ui_left")
	check("cs.left_minus1", sk.stepper.value == 36)
	act(dlg, "ui_down")
	check("cs.down_minus10", sk.stepper.value == 26)
	act(dlg, "ui_up")
	act(dlg, "ui_up")
	check("cs.up_clamps_max", sk.stepper.value == 37)
	sk.stepper.set_value(5)
	# 积分低于门槛：状态行标橙
	s.set_variable(XCasinoBatch.VAR_POINTS, -40000)
	sk.preview()
	check("cs.status_warn_orange", sk.status_bad)
	s.set_variable(XCasinoBatch.VAR_POINTS, 100)
	sk.preview()
	check("cs.status_ok_green", not sk.status_bad)
	await shots("casino")
	# 回车＝开始抽取：进行态原地换
	act(dlg, "ui_accept")
	var se := XCasinoBatch.session
	check("cs.enter_begins", se.state == "drawing" and int(se.requested) == 5 and sk.phase == "drawing", [se.state, sk.phase])
	check("cs.drawing_stepper_grey", not sk.stepper.enabled)
	check("cs.drawing_buttons", sk.buttons.size() == 1 and sk.buttons[0].text == "停止后续抽取", sk.buttons)
	se.used = 2
	se.second = 1
	dlg.set_status("已完成 2 / 5抽；二阶段 1 次")
	check("cs.progress_status", sk.status_text == "已完成 2 / 5抽；二阶段 1 次" and is_equal_approx(sk.progress(), 0.4))
	await shots("casino_drawing")
	# 按停止：灰按钮写「正在完成当前一抽」，XCasinoBatch 标停止
	sk.activate(0)
	check("cs.stop_pressed", se.stop and sk.phase == "stopping" and sk.buttons[0].text == "正在完成当前一抽" and sk.buttons[0].disabled, [se.stop, sk.buttons])
	await shots("casino_stopping")
	_casino_close()
	await frames(2)
	# 20 连抽文案
	dlg = _casino_open("twenty", 65)
	await frames(3)
	sk = dlg.skin
	check("cs.rows_twenty", sk.stock_text() == "持有奖券 65 张" and sk.max_text() == "最多能抽 3 次（20 连）", [sk.stock_text(), sk.max_text()])
	check("cs.twenty_status", sk.status_text == "共 20 抽，消耗 20 张券；积分门槛 -200000。", sk.status_text)
	check("cs.twenty_body", sk.body.begins_with("每次消耗20张券"))
	await shots("casino_twenty")
	sk.stepper.to_max()
	sk._on_chosen(1)
	se = XCasinoBatch.session
	check("cs.twenty_begin", se.state == "drawing" and int(se.requested) == 3)
	sk.activate(0)
	check("cs.twenty_stop_text", sk.buttons[0].text == "正在完成当前20连抽", sk.buttons)
	_casino_close()
	await frames(2)
	# Esc／取消：数量态关框（XCasinoBatch.cancel 走 finish("取消")）
	dlg = _casino_open("single", 10)
	await frames(2)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	dlg._input(esc)
	check("cs.esc_cancels", XCasinoBatch.session.is_empty(), XCasinoBatch.session.keys())
	await frames(2)
	# 点「取消」钮
	dlg = _casino_open("single", 10)
	await frames(2)
	dlg.skin._on_chosen(0)
	check("cs.cancel_button", XCasinoBatch.session.is_empty())
	await frames(2)
	# 手输：数字键敲 1、2＝12，超上限夹到上限
	dlg = _casino_open("single", 30)
	await frames(2)
	key(dlg, KEY_1)
	key(dlg, KEY_2)
	check("cs.type_digits", dlg.skin.stepper.value == 12, dlg.skin.stepper.value)
	key(dlg, KEY_9)
	check("cs.type_clamps", dlg.skin.stepper.value == 30, dlg.skin.stepper.value)
	_casino_close()
	await frames(2)


# ---- 字体 130%、旧画法对照 ----

func _font_and_old() -> void:
	var s := _state()
	_own_some()
	XConfig.clothes_unlocked().clear()
	_unlock_some()
	s.set_variable(XCasinoBatch.VAR_POINTS, 100)
	s.set_switch(XCasinoBatch.SWITCH_OPEN, true)
	XFontScale.set_value("global", 130)
	check("font130.mult", XUiSkin.font_mult() >= 1.29)
	var a := XAchievementScene.new()
	add_child(a)
	await frames(3)
	act(a, "ui_accept")
	await shots("ach_font130")
	a.queue_free()
	var c := XChangeClothesScene.new()
	add_child(c)
	await frames(3)
	act(c, "ui_accept")
	await shots("clothes_font130")
	c.queue_free()
	var d := _casino_open("single", 37)
	await frames(3)
	await shots("casino_font130")
	_casino_close()
	XFontScale.set_value("global", 100)
	await frames(2)
	# 旧画法对照（旧页只按 1280×720 摆，20:9 窗口是上下左右留边，不拍）
	XSkinAchievementPage.ENABLED = false
	var oa := XAchievementScene.new()
	add_child(oa)
	await frames(3)
	check("old.achievement", oa.skin == null and oa.type_win.visible)
	await shot("ach_old_compare_16x9")
	oa.queue_free()
	XSkinAchievementPage.ENABLED = true
	await frames(2)
