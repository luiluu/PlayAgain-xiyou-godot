extends Node
## 【cc·T299·未经审查】新界面卡 K：制作（XSkinCraftingPage）＋宝珠坊、种族祝福（版型四 XSkinMenuTreePage）。
## - 开关：天启篇＋新皮肤才建新页；XSkinMenuTreePage.ENABLED＝false、西游存档都回旧页。
## - 宝珠坊、种族祝福：照旧专项的点选路线（xiyou_orb_shop_ui 的 FLOWS／STEPS、race_menu 参照的 steps）新旧页各走一遍，
##   每页 {info, rows}（log）、背包、提示一条不差；新页每一步核「旧页显示的每一项新页都取得到」（选项行字还原、右牌＝说明几行、
##   面包屑逐层加、确认页走统一确认弹窗、结果页右牌旧金＋「知道了」、不画环、首页即第 0 层菜单）。
## - 制作：T254 3.5 对应表逐行断言；数量选择焦点规则（列表上上下只换行、左右不改数；确定落到数量条；←/→ ±1、↑/↓ ±10、E 最多、Q 回 1；
##   再确定制作；取消回列表、数量复位）；做完走提示道；锻造选原件（面包屑、Y 切词条）；触屏（点数量钮、点主按钮）。
## 带 -- --out=<目录> 且有窗口时截图：每页 16:9（800×450）＋20:9（1000×450）真尺寸（断言图就是这个尺寸，不缩放）、各状态、字体 130%、旧画法对照。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const OrbT = preload("res://tests/xiyou_orb_shop_ui.gd")
const RaceT = preload("res://tests/xiyou_race_menu.gd")
const CraftT = preload("res://tests/xiyou_crafting.gd")

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
		print("FAIL ", name, " ", JSON.stringify(detail).left(800))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


## 真尺寸：窗口直接设成这个大小拍，断言拍下来的图就是这个尺寸（不缩放）
func shot(name: String, sz := Vector2i(800, 450)) -> void:
	if not windowed():
		return
	XSkinNoticeLane.reset()   # 前面几步留下的提示（暂存宝珠、成就）不进截图
	_clear_popups(get_tree().root)
	var win := get_window()
	var old := win.size
	win.size = sz
	await frames(12)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	check("size_" + name, img.get_size() == sz, [img.get_size(), sz])
	check("screenshot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK)
	win.size = old
	await frames(4)


func _clear_popups(n: Node) -> void:
	for c in n.get_children():
		if c is XToast or c is XAchievementPopup:
			c.queue_free()
		else:
			_clear_popups(c)


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


func _tianqi(s: XState) -> XState:
	s.flags["tianqi"] = {"rules": 1}
	XState.current = s
	return s


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_card_k")
	get_viewport().gui_disable_input = windowed()
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XFontScale.set_value("global", 100)
	await _gates()
	await _orb()
	await _race()
	await _craft()
	await _font_and_old()
	XSkinMenuTreePage.ENABLED = true
	XUiSkin.motion_override = -1
	XFontScale.set_value("global", 100)
	XState.current = null
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.3, true, false, true).timeout
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 开关 ----
func _gates() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var built := []
	for on in [false, true]:   # 西游存档：一律旧页
		if on:
			_tianqi(s)
		for enabled in [true, false]:
			XSkinMenuTreePage.ENABLED = enabled
			var c := XCraftingScene.new()
			var o := XOrbShop.new()
			var r := XRaceMenu.new()
			for p in [c, o, r]:
				add_child(p)
			await frames()
			built.append([on, enabled, c.skin != null, o.tree != null, r.tree != null])
			for p in [c, o, r]:
				p.queue_free()
			await frames()
	XSkinMenuTreePage.ENABLED = true
	check("gates", built == [[false, true, false, false, false], [false, false, false, false, false], [true, true, true, true, true], [true, false, false, false, false]], built)


# ---- 宝珠坊、种族祝福：新页每一步「旧页显示的每一项新页都取得到」 ----

## 一行的字能不能还原成原来的选项（split_row 只挪位置不改字）
static func row_restores(item: Dictionary, label: String) -> bool:
	var t := str(item.get("text", ""))
	var r := str(item.get("right", ""))
	if r == "":
		return t == label
	return label in [t + " " + r, t + "（" + r + "）", t + " → " + r, t + " · " + r]


## 当前这一层：列表＝选项、右牌＝说明几行（或页面给的牌）、确认页＝弹窗；返回不对的地方（空＝对）
func tree_mismatch(tree: XSkinMenuTreePage, own_card := false) -> String:
	if tree.ring.visible:
		return "画了环"
	if tree.dialog != null:
		var labels := tree.dialog.buttons.map(func(b): return str(b.text))
		if labels != tree.rows.map(func(r): return str(r.label)):
			return "弹窗钮 %s" % [labels]
		if tree.dialog.body != "\n".join(tree.info.map(func(t): return str(t))):
			return "弹窗正文"
		return ""
	if tree.list.items.size() != tree.rows.size():
		return "行数 %d/%d" % [tree.list.items.size(), tree.rows.size()]
	for i in tree.rows.size():
		if not row_restores(tree.list.items[i], str(tree.rows[i].label)):
			return "行 %s ≠ %s" % [tree.list.items[i], tree.rows[i].label]
		if bool(tree.list.items[i].get("disabled", false)) != (tree.rows[i].get("enabled", true) == false):
			return "可选 %d" % i
	if tree.crumb_node.parts != (tree.crumb.map(func(p): return str(p)) if tree.crumb.size() > 1 else []) or tree.crumb.is_empty():
		return "面包屑"
	if not own_card and not tree.info.is_empty():
		if tree.card.title != str(tree.info[0]):
			return "牌名 %s" % tree.card.title
		var shown := []
		for sec in tree.card.sections:
			for row in sec.get("rows", []):
				shown.append(str(row.text))
		if shown != tree.info.slice(1).map(func(t): return str(t)):
			return "说明 %s" % [shown]
	return ""


## 旧专项的 _state（实例方法）：借一个不进树的实例用完就放
func _orb_state(f: Array) -> XState:
	var o = OrbT.new()
	var s: XState = o._state(f[0], f[1], f[2], f[3], f[4])
	o.free()
	return s


func _orb_run(name: String, skin: bool) -> Dictionary:
	var f: Array = OrbT.FLOWS[name]
	var s := _orb_state(f)
	_tianqi(s)
	XSkinMenuTreePage.ENABLED = skin
	var toast0 := XToast.shown.size()
	var shop := XOrbShop.new()
	var closed := [false]
	shop.closed.connect(func(): closed[0] = true)
	add_child(shop)
	await frames()
	var bad := ""
	var depth := []
	var ctl = shop.tree if skin else shop.choice
	if skin and bad == "":
		bad = tree_mismatch(shop.tree)
	for step in OrbT.STEPS[name]:
		if closed[0]:
			break
		if step == "<":
			ctl.cancel()
		elif step == "!first":
			ctl.index = ctl.rows.find_custom(func(r): return not r.get("back", false))
			ctl.ok()
		else:
			var i: int = ctl.rows.find_custom(func(r): return str(r.label) == step)
			if i < 0:
				bad = "找不到 " + step
				break
			ctl.index = i
			ctl.ok()
		if skin and not closed[0]:
			await frames(1)
			var m := tree_mismatch(shop.tree)
			if m != "" and bad == "":
				bad = "%s：%s" % [step, m]
			depth.append(shop.tree.crumb.size())
	var out := {"log": shop.log.duplicate(true), "bag": s.items.duplicate(), "toasts": XToast.shown.slice(toast0), "closed": closed[0], "bad": bad, "depth": depth}
	if skin:
		out["tree"] = shop.tree
		out["shop"] = shop
	else:
		shop.queue_free()
	return out


func _orb() -> void:
	for name in OrbT.FLOWS:
		var old: Dictionary = await _orb_run(name, false)
		await frames()
		var neu: Dictionary = await _orb_run(name, true)
		check("orb_same_" + name, old.log == neu.log and old.bag == neu.bag and old.toasts == neu.toasts and old.closed == neu.closed,
			[old.log.size(), neu.log.size(), old.toasts, neu.toasts])
		check("orb_shown_" + name, neu.bad == "", neu.bad)
		if is_instance_valid(neu.get("shop")):
			neu.shop.queue_free()
		await frames()
	XSkinMenuTreePage.ENABLED = true
	# 首页即第 0 层：不画环、面包屑只有「宝珠坊」、左块首页小字、右上残片
	var f: Array = OrbT.FLOWS["identify"]
	var s := _orb_state(f)
	_tianqi(s)
	var shop := XOrbShop.new()
	add_child(shop)
	await frames()
	var t := shop.tree
	check("orb_home", not t.ring.visible and t.crumb == ["宝珠坊"] and t.list_title == "宝珠坊" and t.rows.size() == shop.log[0].rows.size()
		and t.left_lines == ["未鉴定 13 枚", "宝珠残片 40"] and t.currency_pairs()[0][1] == "40" and t.left_icon > 0, [t.crumb, t.left_lines, t.currency_pairs()])
	check("orb_home_info_unwrapped", t.info.size() == 4 and t.card.title == "宝珠坊" and t.hint_list[-1] == ["取消", "离开"], [t.info, t.hint_list])
	await shots("orb_home")
	# 鉴定菜单 → 鉴定详情：面包屑逐层、行尾数量
	t.index = t.rows.find_custom(func(r): return r.label == "鉴定神秘珠")
	t.ok()
	await frames()
	check("orb_menu", t.crumb == ["宝珠坊", "鉴定神秘珠"] and str(t.list.items[0].get("right", "")).begins_with("×"), [t.crumb, t.list.items[0]])
	await shots("orb_identify_menu")
	t.ok()
	await frames()
	check("orb_detail", t.crumb.size() == 3 and t.hint_list[-1] == ["取消", "返回"], t.crumb)
	await shots("orb_identify_detail")
	# 确认页：统一确认弹窗、普通灰边停「确认」，列表不换（仍是详情那一层）
	var detail_rows := t.list.items.size()
	t.index = 0
	t.ok()
	await frames()
	check("orb_confirm_dialog", t.dialog != null and not t.dialog.danger and t.dialog.index == 0 and t.list.items.size() == detail_rows
		and str(t.dialog.title).ends_with("？"), [t.dialog != null, t.list.items.size()])
	await shots("orb_identify_confirm")
	# 弹窗上按左右换钮、取消回详情
	act(t, "ui_right")
	check("orb_dialog_move", t.index == 1 and t.dialog.index == 1, t.index)
	act(t, "ui_cancel")
	await frames()
	check("orb_dialog_cancel", t.dialog == null and t.crumb.size() == 3)
	# 确定鉴定 → 结果页：右牌旧金、「知道了」＝回上一层
	t.index = 0
	t.ok()
	await frames()
	t.index = 0
	t.ok()
	await frames()
	var res_ok: bool = t.card.title_color == XUiSkin.GOLD and t.card.buttons.size() == 1 and str(t.card.buttons[0].text) == "知道了" and t.crumb.back() == "鉴定完成"
	check("orb_result", res_ok, [t.card.title, t.card.buttons, t.crumb])
	await shots("orb_result")
	t.card.button_pressed.emit(0)
	await frames()
	check("orb_result_back", t.crumb == ["宝珠坊", "鉴定神秘珠"], t.crumb)
	shop.queue_free()
	await frames()
	# 分解：橙边、停在「取消」
	f = OrbT.FLOWS["dismantle"]
	s = _orb_state(f)
	_tianqi(s)
	shop = XOrbShop.new()
	add_child(shop)
	await frames()
	t = shop.tree
	for step in ["分解宝珠", "宝珠·锋刃·归真 ×6", "分解 5 颗 → 155 残片"]:
		t.index = t.rows.find_custom(func(r): return r.label == step)
		t.ok()
		await frames()
	check("orb_dismantle_danger", t.dialog != null and t.dialog.danger and t.index == t.rows.size() - 1 and t.dialog.index == t.rows.size() - 1, [t.index])
	await shots("orb_dismantle_confirm")
	act(t, "ui_accept")   # 停在「取消」上按确定＝不分解，回详情
	await frames()
	check("orb_dismantle_default_cancel", t.dialog == null and s.item_count(2951) == 6, s.item_count(2951))
	shop.queue_free()
	await frames()
	# 套装说明：长说明自动折行进右牌
	f = OrbT.FLOWS["home-empty"]
	s = _orb_state(f)
	_tianqi(s)
	shop = XOrbShop.new()
	add_child(shop)
	await frames()
	t = shop.tree
	for step in ["套装图谱与当前配装", "焚雷：烈焰／雷霆／灵慧"]:
		t.index = t.rows.find_custom(func(r): return r.label == step)
		t.ok()
		await frames()
	check("orb_set_page", t.crumb == ["宝珠坊", "套装图谱", "宝珠套装：焚雷".get_slice("：", 1)] or t.crumb.size() == 3, t.crumb)
	await shots("orb_set_detail")
	# 鼠标：右键＝取消
	var rc := InputEventMouseButton.new()
	rc.button_index = MOUSE_BUTTON_RIGHT
	rc.pressed = true
	t._on_gui(rc)
	await frames()
	check("orb_right_click", t.crumb == ["宝珠坊", "套装图谱"], t.crumb)
	shop.queue_free()
	await frames()


func _race_run(p: Dictionary, skin: bool) -> Dictionary:
	var rt = RaceT.new()
	var s: XState = rt._state()
	rt._prep(str(p.name), s)
	_tianqi(s)
	XSkinMenuTreePage.ENABLED = skin
	var toast0 := XToast.shown.size()
	var menu := XRaceMenu.new()
	if p.options is Dictionary:
		menu.rank = int(p.options.rank)
	var closed := [false]
	menu.closed.connect(func(): closed[0] = true)
	add_child(menu)
	await frames()
	var ctl = menu.tree if skin else menu.choice
	var bad := ""
	if skin:
		bad = tree_mismatch(menu.tree, true)
	for step in p.steps:
		if closed[0]:
			break
		var st := str(step)
		if st == "<":
			ctl.cancel()
		else:
			var i: int = int(st.substr(1)) if st.begins_with("@") else ctl.rows.find_custom(func(r): return str(r.label) == st)
			if i < 0 or i >= ctl.rows.size():
				bad = "找不到 " + st
				break
			ctl.index = i
			ctl.ok()
		if skin and not closed[0]:
			await frames(1)
			var m := tree_mismatch(menu.tree, true)
			if m != "" and bad == "":
				bad = "%s：%s" % [st, m]
	var out := {"log": menu.log.duplicate(true), "bag": s.items.duplicate(), "toasts": XToast.shown.slice(toast0), "closed": closed[0], "bad": bad}
	menu.queue_free()
	rt.free()
	return out


func _race() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(RaceT.ORACLE)) if FileAccess.file_exists(RaceT.ORACLE) else null
	if check("race_oracle", d is Dictionary and not d.get("flows", d.get("pages", [])).is_empty(), RaceT.ORACLE):
		for p in d.get("flows", d.get("pages", [])):
			var old: Dictionary = await _race_run(p, false)
			await frames()
			var neu: Dictionary = await _race_run(p, true)
			await frames()
			check("race_same_" + str(p.name), old.log == neu.log and old.bag == neu.bag and old.toasts == neu.toasts and old.closed == neu.closed,
				[old.log.size(), neu.log.size(), old.toasts, neu.toasts])
			check("race_shown_" + str(p.name), neu.bad == "", neu.bad)
	XSkinMenuTreePage.ENABLED = true
	# 队员页：行尾种族和阶位、能进阶的「可进阶」金色小标、右牌当前加成＋下一阶、左块跟着光标
	var rt = RaceT.new()
	var s: XState = rt._state()
	_tianqi(s)
	XRace.set_default(s, 5)
	s.gain_item(int(XRace.config().stones[0]), 1)
	var menu := XRaceMenu.new()
	add_child(menu)
	await frames()
	var t := menu.tree
	var members := s.members()
	var rows_ok := t.list.items.size() == members.size()
	for i in members.size():
		var a: XActor = members[i]
		var it: Dictionary = t.list.items[i]
		rows_ok = rows_ok and it.text == a.display_name() and it.right == XRace.label(s, a) and (it.get("tags", []) as Array).size() == 1 and it.tags[0].text == "可进阶" and it.tags[0].color == XUiSkin.GOLD
	check("race_member_rows", rows_ok and not t.ring.visible, t.list.items)
	var a0: XActor = members[0]
	var secs := t.card.sections.map(func(x): return str(x.title))
	check("race_member_card", t.card.title == a0.display_name() and secs == ["当前加成", "下一阶（第2阶）"]
		and t.card.sections[0].rows.map(func(r): return r.text) == XRace.effects(5, 1), [t.card.title, secs])
	check("race_left_actor", t.current_row().get("actor") == a0)
	await shots("race_members")
	act(t, "ui_down")
	await frames()
	check("race_left_follows", t.current_row().get("actor") == members[1] and t.card.title == members[1].display_name())
	act(t, "ui_accept")
	await frames()
	check("race_actor_page", t.crumb == ["种族祝福", members[1].display_name()] and menu._actor == members[1], t.crumb)
	await shots("race_actor")
	t.index = 0   # 调整种族
	t.ok()
	await frames()
	check("race_race_page", t.list.items.size() == 7 and t.card.title == XRace.race_name(0) + "族", t.card.title)
	await shots("race_races")
	t.index = 2
	t.ok()
	await frames()
	check("race_confirm_dialog", t.dialog != null and t.dialog.title == "改为%s族？" % XRace.race_name(2) and t.dialog.index == 0, t.dialog.title if t.dialog else null)
	await shots("race_confirm")
	act(t, "ui_cancel")
	await frames()
	check("race_confirm_cancel", t.dialog == null and t.list.items.size() == 7)
	menu.queue_free()
	await frames()
	# 开局默认（还没选族）：右牌第 1 阶加成，确认弹窗
	s = rt._state()
	_tianqi(s)
	menu = XRaceMenu.new()
	add_child(menu)
	await frames()
	t = menu.tree
	check("race_defaults", t.crumb == ["种族祝福", "开局默认"] and t.card.sections[0].title == "第1阶加成", t.crumb)
	await shots("race_defaults")
	menu.queue_free()
	rt.free()
	await frames()


# ---- 制作 ----
func _craft() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(CraftT.FIXTURE))
	if not check("craft_fixture", ref is Dictionary):
		return
	var ct = CraftT.new()
	var s: XState = ct._setup(ref)
	_tianqi(s)
	var page := XCraftingScene.new()
	add_child(page)
	await frames()
	var sk := page.skin
	# 对应表：类别窗 → 环 4 球；类别等级窗 → 环下一条；金币窗 → 右上
	check("craft_ring", sk.ring.visible and sk.ring.items.map(func(i): return i.name) == XCrafting.CATEGORIES and sk.focus == "ring", sk.ring.items)
	var lp := XSkinCraftingPage.level_parts(s, 0)
	check("craft_level_bar", lp[0] == "%s等级 %d" % [XCrafting.CATEGORIES[0], XCrafting.craft_level(s, 0)]
		and lp[1] == "%s / %s" % [XSkinTemplatePage._group(XCrafting.craft_exp(s, 0)), XSkinTemplatePage._group(XCrafting.exp_next(s, 0))], lp)
	check("craft_currency", sk.currency_pairs()[0][1] == XSkinTemplatePage._group(s.gold))
	check("craft_old_hidden", not page.list_win.visible and not page.cat_win.visible and not page.gauge_win.visible and not page.source_card.visible)
	await shots("craft_category")
	# 环上左右换类别
	act(page, "ui_right")
	check("craft_ring_move", page.cat_index == 1 and sk.ring.index == 1)
	act(page, "ui_left")
	# 进列表（配方 1 那一类：测试存档里能做 3 件）
	page.select_category(XCrafting.category_id(XCrafting.recipe(1)))
	act(page, "ui_accept")
	check("craft_list", page.mode == "list" and sk.focus == "list")
	var ci := page.list.find_custom(func(x): return int(x.id) == 1)
	page.select(ci)
	# 配方列表：行尾「可做 N」、做不了的变灰写原因
	var rows_ok := sk.list.items.size() == page.list.size()
	for i in page.list.size():
		var r: Dictionary = page.list[i]
		var it: Dictionary = sk.list.items[i]
		if XCrafting.craftable(s, r):
			rows_ok = rows_ok and it.right == "可做 %d" % XCrafting.amount_craftable(s, r) and not it.get("disabled", false)
		else:
			rows_ok = rows_ok and it.get("disabled", false) and it.right in ["等级不够", "材料不够", XSkinCraftingPage.currency_unit() + "不够"]
		rows_ok = rows_ok and it.text == str(XCrafting.item_of(r.result).get("name", ""))
	check("craft_rows", rows_ok, sk.list.items.slice(0, 3))
	# 详情：说明、要求、材料（持有 / 需要）、费用
	await shots("craft_list_rows")
	var r0 := page.current()
	var titles := sk.card.sections.map(func(x): return str(x.title))
	var mat_ok := true
	for k in r0.materials.size():
		var m: Dictionary = r0.materials[k]
		var ln: Dictionary = sk.card.sections[1].lines[k]
		mat_ok = mat_ok and ln.left == str(XCrafting.item_of(m).get("name", "")) and ln.right == "%d / %d" % [XCrafting.material_count(s, m, r0), int(m.amount)]
	check("craft_card", sk.card.title == str(XCrafting.item_of(r0.result).get("name", "")) and titles[0] == "要求" and titles[1] == "材料"
		and (int(r0.goldCost) <= 0 or "费用" in titles) and sk.card.desc == XSkinCraftingPage._plain(str(XCrafting.item_of(r0.result).get("description", ""))) and mat_ok, [titles, sk.card.desc])
	check("craft_stepper_list", sk.stepper.visible and sk.stepper.value == 1 and not sk.stepper.focused and sk.card.buttons[0].text == "制作")
	await shots("craft_list")
	# 焦点规则：列表上上下只换行、左右不改数
	var n := page.list.size()
	if n > 1:
		act(page, "ui_down")
		check("craft_down_moves_row", page.index == (ci + 1) % n and page.amount == 1 and sk.stepper.value == 1, [page.index, page.amount])
		act(page, "ui_up")
	act(page, "ui_right")
	act(page, "ui_left")
	check("craft_lr_no_amount", page.index == ci and page.amount == 1 and page.mode == "list")
	# 确定 → 落到数量条
	var mx := XCrafting.amount_craftable(s, page.current())
	act(page, "ui_accept")
	check("craft_confirm_focus", page.mode == "confirm" and sk.stepper.focused and sk.hint_list[0] == ["← / →", "±1"], sk.hint_list)
	await shots("craft_confirm")
	act(page, "ui_right")
	check("craft_plus1", page.amount == mini(2, mx) and sk.stepper.value == page.amount, page.amount)
	act(page, "ui_up")
	check("craft_plus10", page.amount == mini(mini(2, mx) + 10, mx), page.amount)
	key(page, KEY_Q)
	check("craft_q_one", page.amount == 1)
	key(page, KEY_E)
	check("craft_e_max", page.amount == mx, [page.amount, mx])
	# 取消 → 回列表、数量复位
	act(page, "ui_cancel")
	check("craft_cancel_reset", page.mode == "list" and sk.stepper.value == 1 and not sk.stepper.focused)
	act(page, "ui_accept")   # 再进数量条从 1 起（旧页 _enter_confirm 复位）
	check("craft_reenter_one", page.mode == "confirm" and page.amount == 1 and sk.stepper.value == 1)
	act(page, "ui_cancel")
	# 确定、确定 → 做一件；提示道
	var t0 := XToast.shown.size()
	var before := XCrafting.amount_craftable(s, page.current())
	var name := str(XCrafting.item_of(page.current().result).get("name", ""))
	act(page, "ui_accept")
	act(page, "ui_accept")
	check("craft_made", page.mode == "list" and XCrafting.amount_craftable(s, page.list[ci]) == before - 1 and XToast.shown.slice(t0) == ["1x %s %s" % [name, XCraftingScene.CRAFTED_TEXT]],
		[page.mode, XToast.shown.slice(t0)])
	# 触屏：列表态点主按钮＝确定、确定
	t0 = XToast.shown.size()
	if XCrafting.craftable(s, page.current()):
		sk.card.button_pressed.emit(0)
		check("craft_touch_button", page.mode == "list" and XToast.shown.size() == t0 + 1)
	# 触屏：列表态点数量钮＝先落到数量条
	if XCrafting.craftable(s, page.current()):
		sk.stepper.touched.emit()
		check("craft_touch_stepper", page.mode == "confirm")
		act(page, "ui_cancel")
	# 做不了的：主按钮灰、没有数量条
	var bad_i := -1
	for i in page.list.size():
		if not XCrafting.craftable(s, page.list[i]):
			bad_i = i
			break
	if bad_i >= 0:
		page.select(bad_i)
		check("craft_disabled_card", sk.card.buttons[0].disabled and not sk.stepper.visible)
		await shots("craft_disabled")
	# 空类别
	act(page, "ui_cancel")
	var empty_cat := -1
	for c in XCrafting.CATEGORIES.size():
		page.select_category(c)
		if page.list.is_empty():
			empty_cat = c
			break
	if empty_cat >= 0:
		check("craft_empty", sk.list.items.is_empty() and sk.list.empty_text == XSkinCraftingPage.T_EMPTY)
		await shots("craft_empty")
	page.queue_free()
	await frames()
	await _forge(s)
	ct.free()


## 锻造：选原件（面包屑、行第二行信息、不能锻的变灰）；Y 切「这一件的词条」
func _forge(s: XState) -> void:
	var id := XGrowthForge.LEVIATHAN_RECIPE
	var base := int(XGrowthForge.KINDS[id].base)
	var kind := "armor" if not XDB.rec("Armors", base).is_empty() else "weapon"
	s.gain_gear(kind, base, 1)
	XGrowthForge.unlock(s, id)
	s.gain_item(XGrowthForge.FRAGMENT, XGrowthForge.FRAGMENT_COST)
	s.gain_item(XGrowthForge.HAMMER, XGrowthForge.HAMMER_COST)
	var r := XCrafting.recipe(id)
	var cat := XCrafting.category_id(r)
	var page := XCraftingScene.new()
	add_child(page)
	await frames()
	var sk := page.skin
	page.select_category(cat)
	page.ok()
	var i := page.list.find_custom(func(x): return int(x.id) == id)
	if not check("forge_listed", i >= 0, [cat, page.list.size()]):
		page.queue_free()
		return
	page.select(i)
	check("forge_button", sk.card.buttons[0].text == XSkinCraftingPage.T_PICK and "锻造后" in sk.card.sections.map(func(x): return x.title), sk.card.buttons)
	page.ok()
	await frames()
	check("forge_pick", page.mode == "pick" and sk.crumb_node.visible and sk.crumb_node.parts == XSkinCraftingPage.PICK_CRUMB
		and sk.list.items.size() == page.picks.size() and str(sk.list.items[0].sub) == XGrowthForge.source_row(s, id, page.picks[0]), [page.mode, sk.list.items])
	await shots("craft_forge_pick")
	key(page, KEY_Y)
	await frames()
	check("forge_y_source", page.source_shown and sk.card.title.contains(str(page.picks[0].get("name", "")).left(2)) and sk.hint_list[1][1] == "返回升级预览", [sk.card.title])
	await shots("craft_forge_source")
	key(page, KEY_Y)
	check("forge_y_back", not page.source_shown)
	act(page, "ui_cancel")
	check("forge_cancel", page.mode == "list" and not sk.crumb_node.visible)
	page.queue_free()
	await frames()


# ---- 字体 130%、旧画法对照 ----
func _font_and_old() -> void:
	XFontScale.set_value("global", 130)
	var ct = CraftT.new()
	var s: XState = ct._setup(JSON.parse_string(FileAccess.get_file_as_string(CraftT.FIXTURE)))
	_tianqi(s)
	var page := XCraftingScene.new()
	add_child(page)
	await frames()
	page.ok()
	await shots("craft_font130")
	page.queue_free()
	var f: Array = OrbT.FLOWS["identify"]
	var so := _orb_state(f)
	_tianqi(so)
	var shop := XOrbShop.new()
	add_child(shop)
	await frames()
	await shots("orb_font130")
	shop.queue_free()
	var rt = RaceT.new()
	var sr: XState = rt._state()
	_tianqi(sr)
	XRace.set_default(sr, 5)
	var menu := XRaceMenu.new()
	add_child(menu)
	await frames()
	await shots("race_font130")
	menu.queue_free()
	XFontScale.set_value("global", 100)
	await frames()
	# 旧画法对照：同一份天启篇存档关掉卡 K 开关
	XSkinMenuTreePage.ENABLED = false
	_tianqi(s)
	page = XCraftingScene.new()
	add_child(page)
	await frames()
	page.ok()
	check("old_craft", page.skin == null)
	await shot("craft_old_16x9")   # 旧页不铺横屏（没有 request_wide），只拍 16:9
	page.queue_free()
	_tianqi(so)
	shop = XOrbShop.new()
	add_child(shop)
	await frames()
	check("old_orb", shop.tree == null and shop.choice.visible)
	await shot("orb_old_16x9")
	shop.queue_free()
	_tianqi(sr)
	menu = XRaceMenu.new()
	add_child(menu)
	await frames()
	await shot("race_old_16x9")
	menu.queue_free()
	XSkinMenuTreePage.ENABLED = true
	ct.free()
	rt.free()
	await frames()
