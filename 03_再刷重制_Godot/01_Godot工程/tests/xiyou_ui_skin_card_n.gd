extends Node
## 【cc·T306·未经审查】新界面卡 N：仓库 XSkinWarehousePage、星级仓库 XSkinStarWarehousePage、深渊商人 XSkinMerchantPage。
## - 门控：天启篇建新页；一个开关 XSkinWarehousePage.ENABLED＝false、西游存档、XUiSkin.ENABLED＝false 都不建（三页同一个开关）。
## - 仓库：T254 3.9 对应表逐行（页名、页签、环四类、行尾数量／序号、「新」小标、空间条、右牌、满仓主按钮）；
##   上下键换行不改别的（16:9 一列 ±1、20:9 两列 ±2）；Q／E 换存取；确定存取一件光标不动；满了蜂鸣不存。
## - 星级仓库：页名随存放／取出；装备＋宠物两球、宠物隐藏时不画环进页在列表；行只有名字（装备带图标）、右牌装备有宠物只写名字；声音只有确定音。
## - 深渊商人：T254 3.18 对应表（页名、面包屑、列表行＝旧 rows、列表标题右小字＝旧标题第二行、右牌装备详情＋分页、右牌底翻详情、
##   点数不够主按钮变灰写还差多少、出错进右牌、战利品点进右上货币、默认帮助句进左块）。
## 带 -- --out=<目录> 且有窗口时截图：每页 800×450＋1000×450（断言真尺寸）、各状态、字体 130%、旧画法对照。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results: Array = []
var out_dir := ""
var toasts: Array = []
var opened := 0


class FakeHost:
	extends RefCounted
	var page: Node
	func toast(t: String) -> void:
		page.toasts.append(t)
	func refresh_events() -> void:
		pass
	func open_merchant29() -> void:
		page.opened += 1


class FakeInterp:
	extends RefCounted
	var host: FakeHost


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--detail-off":   # T360 截图对照：DETAIL_V1 关
			XUiSkin.DETAIL_V1 = false
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


func _tq(s: XState, on := true) -> XState:
	XState.current = s
	if on:
		s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian"}
	return s


func _click(pos: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	return e


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_card_n")
	get_viewport().gui_disable_input = windowed()
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XFontScale.set_value("global", 100)
	await _warehouse()
	await _star()
	await _merchant()
	await _font_and_old()
	XUiSkin.motion_override = -1
	XFontScale.set_value("global", 100)
	XSkinWarehousePage.ENABLED = true
	XTianqiPetHide.ENABLED = true
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


# ---- 仓库 ----

func _wh_state(tianqi := true, cap := 200) -> XState:
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	_tq(s, tianqi)
	for p in [[1, 5], [2, 3], [6, 2], [4, 1]]:
		s.gain_item(p[0], p[1])
	s.gain_gear("weapon", 2, 1)
	s.gain_gear("weapon", 9, 1)
	s.gain_gear("weapon", 52, 1)
	s.gain_gear("weapon", 3, 1)
	s.gain_gear("weapon", 4, 1)
	s.gain_gear("armor", 2, 1)
	XWarehouse.create(s, "<仓库:%d>" % cap)
	XWarehouse.open(s, "<仓库>")
	XWarehouse.deposit(s, "item", XDB.rec("Items", 1))
	XWarehouse.deposit(s, "item", XDB.rec("Items", 1))
	XWarehouse.deposit(s, "keyItem", XDB.rec("Items", 4))
	XWarehouse.deposit(s, "weapon", XItemScene.bag_gear("weapon").filter(func(e): return int(e.base) == 2)[0])
	return s


func _warehouse() -> void:
	var s := _wh_state()
	# 门控：开关关了、XUiSkin 关了、西游存档都是旧页
	XSkinWarehousePage.ENABLED = false
	var old := XWarehouseScene.new()
	add_child(old)
	await frames(2)
	check("wh.gate.rollback_old", old.skin == null and old.option_win.visible and old.mode == "option")
	await shot("warehouse_old_compare_16x9")
	old.queue_free()
	XSkinWarehousePage.ENABLED = true
	XUiSkin.ENABLED = false
	var off := XWarehouseScene.new()
	add_child(off)
	await frames(2)
	check("wh.gate.skin_off_old", off.skin == null)
	off.queue_free()
	XUiSkin.ENABLED = true
	_tq(s, false)
	s.flags.erase("tianqi")
	var xiyou := XWarehouseScene.new()
	add_child(xiyou)
	await frames(2)
	check("wh.gate.xiyou_old", xiyou.skin == null)
	xiyou.queue_free()
	_tq(s, true)
	var p := XWarehouseScene.new()
	var closed := [0]
	p.closed.connect(func(): closed[0] += 1)
	add_child(p)
	await frames(3)
	var sk := p.skin
	check("wh.gate.tianqi_builds", sk != null and not p.option_win.visible and not p.cat_win.visible and not p.list_win.visible and not p.info_win.visible and not p.title_win.visible)
	check("wh.title", sk.title == XWarehouse.last_active and sk.title != "")
	check("wh.enter_on_ring", p.mode == "category" and p.category == 0 and p.option == 0 and sk.focus == "ring")
	# 对应表：环四类（名字＋件数）、页签、空间
	var names := XWarehouseScene.cat_names()
	var ring_ok := sk.ring.items.size() == 4
	for i in 4:
		var n := XWarehouse.stored(s, XWarehouse.CATEGORIES[i]).size()
		ring_ok = ring_ok and str(sk.ring.items[i].name) == "%s %d" % [names[i], n]
	check("wh.ring4", ring_ok, sk.ring.items)
	check("wh.tabs", sk.inner_tabs.tabs == XSkinWarehousePage.T_TABS and sk.inner_tabs.index == 1, [sk.inner_tabs.tabs, sk.inner_tabs.index])
	check("wh.space_line", sk.space_line() == "仓库空间　剩 %d / %d" % [XWarehouse.max_capacity(s) - XWarehouse.used(s), XWarehouse.max_capacity(s)]
		and XWarehouse.info_text(s).contains("%d / %d" % [XWarehouse.max_capacity(s) - XWarehouse.used(s), XWarehouse.max_capacity(s)]), sk.space_line())
	# 对应表：取出列表＝仓库里的（物品 ×数量）；名字品质色；右牌
	var st := XWarehouse.stored(s, "item")
	var rows_ok := sk.list.items.size() == st.size()
	for i in st.size():
		var it: Dictionary = sk.list.items[i]
		rows_ok = rows_ok and it.text == XQuality.list_name(st[i].rec) and it.right == "×" + XMenu._group(int(st[i].qty)) and int(it.icon) == int(st[i].rec.get("iconIndex", 0))
	check("wh.rows_withdraw", rows_ok, sk.list.items)
	var cd := sk.card_data()
	check("wh.card_preview_no_button", cd.title == XQuality.list_name(st[0].rec) and cd.buttons.is_empty() and str(cd.subtitle).contains("仓库里 ×"), cd)
	await shots("warehouse")
	# 环上 ↓ 换到武器（旧 category 左右；新环竖排）
	act(p, "ui_down")
	check("wh.ring_down", p.category == 1 and sk.list.items.size() == XWarehouse.stored(s, "weapon").size() and sk.ring.index == 1)
	act(p, "ui_up")
	check("wh.ring_up", p.category == 0)
	# 确定进列表、选第 1 项，右牌出主按钮「取出」
	act(p, "ui_accept")
	check("wh.ok_enters_list", p.mode == "list" and p.index == 0 and sk.list.index == 0 and sk.focus == "list" and sk.card_data().buttons[0].text == "取出")
	await shots("warehouse_list")
	# 确定＝取出一件，光标不动；仓库里的物品 1 少一件、背包多一件
	var before := XWarehouse.used(s)
	var bag1 := s.item_count(1)
	act(p, "ui_accept")
	check("wh.withdraw_one", XWarehouse.used(s) == before - 1 and s.item_count(1) == bag1 + 1 and p.index == 0, [XWarehouse.used(s), before])
	# 取空这一类（物品 1 还剩一件）再取：光标夹回，列表空了右牌不画
	act(p, "ui_accept")
	check("wh.withdraw_to_empty", sk.list.items.is_empty() and not sk.card.visible and sk.list.empty_text == XSkinWarehousePage.T_EMPTY, sk.list.items)
	await shots("warehouse_empty")
	act(p, "ui_accept")   # 空列表确定：旧 _enabled() 假＝蜂鸣、不动
	check("wh.empty_accept_stays", p.mode == "list")
	# 取消：列表→环；环上取消＝离开（旧页要先回选项窗再离开，新页没有这一层）
	act(p, "ui_cancel")
	check("wh.cancel_to_ring", p.mode == "category" and p.index == -1 and closed[0] == 0)
	# Q／E：换到「存进去（背包）」；行尾「序号/9,999」或「×数量」同旧
	key(p, KEY_Q)
	check("wh.q_deposit_tab", p.option == 1 and sk.inner_tabs.index == 0 and XWarehouse.last_option == 1)
	var cs := XWarehouse.carried(s, "item")
	var okc := sk.list.items.size() == cs.size()
	for i in cs.size():
		okc = okc and sk.list.items[i].right == XItemRow.right_text(cs[i]) and sk.list.items[i].text == XQuality.list_name(cs[i].rec)
	check("wh.rows_deposit", okc, sk.list.items)
	# 武器：背包里「序号/9,999」
	act(p, "ui_down")
	var wc := XWarehouse.carried(s, "weapon")
	check("wh.deposit_weapon_rows", p.category == 1 and sk.list.items.size() == wc.size() and sk.list.items[0].right == XItemRow.right_text(wc[0]) and sk.list.items[0].right.contains("/"), sk.list.items)
	await shots("warehouse_deposit")
	# 两列 vs 一列：上下键步长按列数
	sk.layout.view_override = Vector2(1600, 720)
	sk.relayout()
	check("wh.cols20x9", sk.cols() == 2 and sk.list.columns == 2 and p.cols() == 2)
	sk.layout.view_override = Vector2(1280, 720)
	sk.relayout()
	check("wh.cols16x9", sk.cols() == 1 and sk.list.columns == 1)
	act(p, "ui_accept")
	check("wh.list_idx0", p.mode == "list" and p.index == 0)
	act(p, "ui_down")
	check("wh.down_one_col_step1", p.index == 1 and sk.list.index == 1, [p.index, wc.size()])
	act(p, "ui_right")
	check("wh.right_ignored_one_col", p.index == 1)
	act(p, "ui_up")
	check("wh.up_back", p.index == 0)
	sk.layout.view_override = Vector2(1600, 720)
	sk.relayout()
	act(p, "ui_down")
	check("wh.down_two_cols_step2", p.index == mini(2, wc.size() - 1) and sk.list.index == p.index, p.index)
	act(p, "ui_right")
	check("wh.right_two_cols", wc.size() >= 4 and p.index == 3, [p.index, wc.size()])
	await shots("warehouse_two_col")
	sk.layout.view_override = Vector2.ZERO
	sk.relayout()
	# 存入：包里装备→仓库，满了不能存
	p._select(0)
	var used0 := XWarehouse.used(s)
	act(p, "ui_accept")
	check("wh.deposit_one", XWarehouse.used(s) == used0 + 1 and p.index == 0)
	# 小仓库：容量用满
	var cap := XWarehouse.max_capacity(s)
	var cur := XWarehouse.current(s)
	cur["maxCapacity"] = XWarehouse.used(s)
	p._reload()
	var cdf := sk.card_data()
	check("wh.full_button", cdf.buttons[0].text == XSkinWarehousePage.T_FULL and cdf.buttons[0].disabled, cdf)
	XSound.system_log.clear()
	var used1 := XWarehouse.used(s)
	act(p, "ui_accept")
	check("wh.full_buzz_no_store", XSound.system_log.has(3) and XWarehouse.used(s) == used1, XSound.system_log)
	await shots("warehouse_full")
	cur["maxCapacity"] = cap
	p._reload()
	# 点灰按钮：蜂鸣、焦点框不留
	cur["maxCapacity"] = XWarehouse.used(s)
	p._reload()
	var wev := _click(sk.card.button_rect(0).get_center())
	XSound.system_log.clear()
	sk._on_card_gui(wev)
	await frames(2)
	check("wh.click_disabled_buzz", XSound.system_log.has(3) and sk.card.button_index == -1, [XSound.system_log, sk.card.button_index])
	cur["maxCapacity"] = cap
	p._reload()
	act(p, "ui_cancel")
	act(p, "ui_cancel")
	check("wh.cancel_closes", closed[0] == 1)
	p.queue_free()
	await frames(2)
	# 旧对应表：每个旧窗的内容新页都取得到（标题、选项两个字、分类四个字、信息）
	var p2 := XWarehouseScene.new()
	add_child(p2)
	await frames(2)
	var opt := XWarehouseScene.option_ops().map(func(o): return str(o[1]))
	var s2 := p2.skin
	check("wh.old_to_new_option_words", opt.size() == 2 and s2.inner_tabs.tabs[0].begins_with("存") and s2.inner_tabs.tabs[1].begins_with("取"), opt)
	check("wh.old_to_new_cat_words", XWarehouseScene.cat_ops().map(func(o): return str(o[1])) == names, names)
	p2.queue_free()
	await frames(2)


# ---- 星级仓库 ----

const DIR := "user://test_xiyou_ui_skin_card_n_star"


func _fresh_star() -> void:
	XSave.dir_override = DIR
	XStarWarehouse.path_override = ""
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in ["star_warehouse.json", "star_warehouse.json.tmp", "star_warehouse.ksv"]:
		DirAccess.remove_absolute(DIR.path_join(f))
	XStarWarehouse._loaded_path = "<unloaded>"
	XStarWarehouse.o_save_now = true
	XStarWarehouse.o_alien_reset = true
	XStarWarehouse.o_block_bound = true
	XStarWarehouse.o_withdraw_txn = true
	XStarWarehouse._pending = []


func _pet(enemy: int) -> Dictionary:
	return {"enemy": enemy, "elite": false, "letter": "", "push": [0, 0, 0, 0, 0, 0, 0, 0], "skills": [], "lv_skills": {}, "exp": 0, "ls": 0, "ls_max": 1}


func _star_state() -> XState:
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	_tq(s, true)
	for b in [2, 52, 3]:
		s.gain_gear("weapon", b, 1)
	s.gain_gear("armor", 2, 1)
	s.pets = {"list": [_pet(1), _pet(2), _pet(3)], "war": 1, "team_a": 0}
	return s


func _star_open(save_mode: bool) -> XStarWarehouseScene:
	var p := XStarWarehouseScene.new()
	p.save_mode = save_mode
	add_child(p)
	return p


func _star() -> void:
	_fresh_star()
	var s := _star_state()
	# 门控
	XSkinWarehousePage.ENABLED = false
	var old := _star_open(true)
	await frames(2)
	check("sw.gate.rollback_old", old.skin == null and old.cat_win.visible)
	await shot("star_old_compare_16x9")
	old.queue_free()
	XSkinWarehousePage.ENABLED = true
	var xi := XState.new_game_blank()
	XState.current = xi
	var oldx := _star_open(true)
	await frames(2)
	check("sw.gate.xiyou_old", oldx.skin == null)
	oldx.queue_free()
	XState.current = s
	# 宠物隐藏（天启篇）：只剩装备，不画环，进页在列表
	var h := _star_open(true)
	await frames(3)
	var sk := h.skin
	check("sw.hidden.builds", sk != null and not sk.show_ring and not h.cat_win.visible and not h.list_win.visible and not h.help_card.visible)
	check("sw.hidden.title", sk.title == "星级仓库 · 存放", sk.title)
	check("sw.hidden.enter_on_list", h.mode == "list" and h.index == 0 and sk.focus == "list")
	check("sw.hidden.no_ring", not sk.ring.visible or not sk.show_ring)
	var gear := XStarWarehouse.carried_gear()
	var ok_rows := sk.list.items.size() == gear.size()
	for i in gear.size():
		var it: Dictionary = sk.list.items[i]
		ok_rows = ok_rows and it.text == XQuality.list_name(gear[i]) and int(it.icon) == int(gear[i].get("iconIndex", 0)) and not it.has("right") and not it.has("tags")
	check("sw.rows_equip_no_qty_no_new", ok_rows, sk.list.items)
	var cd := sk.card_data()
	check("sw.card_equip", cd.title == XQuality.list_name(gear[0]) and cd.buttons[0].text == "存放" and not str(cd.subtitle).contains("持有"), cd)
	await shots("star")
	# 无环且背包没有装备：进页焦点在列表（不残留在环上），提示不写「进入列表」
	var bag_keep := XState.current.gear.duplicate()
	XState.current.gear.clear()
	var he := _star_open(true)
	await frames(3)
	check("sw.hidden.empty_focus_list", he.skin.focus == "list" and he.mode == "list" and he.data.is_empty() and not str(he.skin._hints()).contains("进入列表") and he.skin.list.empty_text == "背包里没有可存放的装备", [he.skin.focus, he.skin._hints()])
	he.queue_free()
	await frames(2)
	XState.current.gear.assign(bag_keep)
	# 存放一件：只响确定音，不蜂鸣不响装备音，光标不动
	XSound.system_log.clear()
	var n0 := gear.size()
	act(h, "ui_accept")
	check("sw.deposit_sound_only_ok", XStarWarehouse.carried_gear().size() == n0 - 1 and XSound.system_log == [1] and h.index == 0, [XSound.system_log, XStarWarehouse.carried_gear().size()])
	# Q／E 整页翻：一列时跳一屏，夹到边
	key(h, KEY_E)
	check("sw.page_key", h.index == mini(sk.list.visible_rows() * sk.cols(), h.data.size() - 1) or h.data.size() <= 1, [h.index, h.data.size()])
	act(h, "ui_cancel")
	check("sw.hidden.cancel_leaves", true)
	h.queue_free()
	await frames(2)
	# 宠物显示：两球；宠物行只名字（出战带「[出战]」）；右牌宠物只写名字
	XTianqiPetHide.ENABLED = false
	_fresh_star()
	_star_state()
	var p := _star_open(true)
	var closed := [0]
	p.closed.connect(func(): closed[0] += 1)
	await frames(3)
	sk = p.skin
	check("sw.ring2", sk.show_ring and sk.ring.items.size() == 2 and str(sk.ring.items[0].name) == "装备" and str(sk.ring.items[1].name) == "宠物", sk.ring.items)
	check("sw.enter_on_ring", p.mode == "category" and sk.focus == "ring")
	await shots("star_ring")
	act(p, "ui_down")
	check("sw.ring_down_to_pet", p.category == 1)
	var pets := XPets.list(XState.current)
	var prow := sk.list.items.map(func(r): return r.text)
	check("sw.rows_pet_names", prow == pets.map(func(x): return XPets.pet_name(XState.current, x)) and prow.any(func(t): return str(t).contains("[出战]")), prow)
	check("sw.pet_rows_no_icon", sk.list.items.all(func(r): return not r.has("icon")))
	act(p, "ui_accept")
	var cdp := sk.card_data()
	check("sw.card_pet_only_name", cdp.title == p.pet_label(p.data[0]) and (cdp.sections as Array).is_empty(), cdp)
	await shots("star_pet")
	act(p, "ui_cancel")
	check("sw.cancel_list_to_ring", p.mode == "category" and closed[0] == 0)
	act(p, "ui_cancel")
	check("sw.cancel_ring_closes", closed[0] == 1)
	p.queue_free()
	await frames(2)
	# 取出档：页名「· 取出」；仓库空时空列表句
	XTianqiPetHide.ENABLED = true
	var t := _star_open(false)
	await frames(3)
	check("sw.take.title", t.skin.title == "星级仓库 · 取出" and t.skin.list.items.is_empty() and t.skin.list.empty_text == XSkinStarWarehousePage.T_EMPTY_TAKE)
	await shots("star_take_empty")
	t.queue_free()
	await frames(2)
	# 把一件存进去再开取出档：行＝仓库装备
	var g0: Dictionary = XStarWarehouse.carried_gear()[0]
	XStarWarehouse.deposit_gear(XState.current, g0)
	var t2 := _star_open(false)
	await frames(3)
	check("sw.take.rows", t2.skin.list.items.size() == XStarWarehouse.withdrawable_gear().size() and t2.skin.list.items.size() >= 1)
	check("sw.take.button", t2.skin.card_data().buttons[0].text == "取出", t2.skin.card_data())
	await shots("star_take")
	t2.queue_free()
	await frames(2)
	XTianqiPetHide.ENABLED = true
	_fresh_star()
	XSave.dir_override = "user://test_xiyou_ui_skin_card_n"


# ---- 深渊商人 ----

func _interp() -> FakeInterp:
	var hh := FakeHost.new()
	hh.page = self
	var i := FakeInterp.new()
	i.host = hh
	return i


func _present(map: int, bal: int) -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	s.party.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	s.map_id = 4
	_tq(s, true)
	XAbyssMerchant.battle = {}
	XAbyssMerchant.active = false
	MVEventCore.fixed_random = 0.5
	XAlienBattle.on_map_setup(s, s.map_id, map)
	XYunshangOrders.on_map_setup(s, s.map_id, map)
	XAbyssMerchant.on_map_setup(s, s.map_id, map)
	s.map_id = map
	XAbyssMerchant.battle_started(s, int(XAbyssMerchant.route(map).troops[0]))
	XAbyssMerchant.battle_ended(0)
	MVEventCore.fixed_random = 0.1
	await XAbyssMerchant.complete(s, _interp())
	MVEventCore.fixed_random = 0.5
	XAbyssMerchant.ledger(s).balances[str(XAbyssMerchant.run(s).identity.key)] = bal
	XAbyssMerchant.active = false
	return s


func _merchant() -> void:
	var s := await _present(37, 100)
	XAbyssMerchant.LAYER_LEDGER = false   # 同旧专项：每图分账，点数就是上面写的 100
	XSkinWarehousePage.ENABLED = false
	var old := XMerchant29Page.new()
	add_child(old)
	await frames(2)
	check("mc.gate.rollback_old", old.tree == null and old.list.visible and old.header.visible)
	await shot("merchant_old_compare_16x9")
	old.queue_free()
	XSkinWarehousePage.ENABLED = true
	var page := XMerchant29Page.new()
	add_child(page)
	await frames(3)
	var tr := page.tree
	check("mc.gate.builds", tr != null and not page.list.visible and not page.header.visible and not page.detail.visible and not page.nav.visible)
	check("mc.page_title", tr.title == "深渊商人")
	# 首页：行＝旧 home_rows；标题第二行进列表标题右边；面包屑一段；右上货币；左块默认帮助句
	var home := XMerchant29Page.home_rows(s)
	var ok_home := tr.list.items.size() == home.size()
	for i in home.size():
		ok_home = ok_home and tr.list.items[i].text == home[i].text and bool(tr.list.items[i].get("disabled", false)) == (home[i].get("enabled", true) == false)
	check("mc.home.rows", ok_home, tr.list.items)
	var info := XMerchant29Page.home_info(s)
	check("mc.home.list_right_is_second_line", tr.list_right == info[1] and tr.list_title == info[0].split("　")[0] + " · " + info[0].split("　")[1], [tr.list_right, tr.list_title])
	check("mc.home.currency", str(tr.currencies) == str([["战利品点", "100"]]), tr.currencies)
	check("mc.default_help_in_left", XSkinMerchantPage.T_DEFAULT_HELP == XMerchant29Page.DEFAULT_HELP)
	check("mc.home.card_title_lines", tr.card.title == info[0], tr.card.title)
	await shots("merchant_home")
	# 武器一层（天启篇两档货架：寻宝、珍藏）：面包屑「深渊商人 · 路线 › 抽取武器」；行同旧 tianqi_rows；点数不够写还差多少
	tr.list.select(1)
	tr.index = 1
	tr.ok()
	var tier := XMerchant29Page.tianqi_rows(s, "武器")
	check("mc.tier.crumb", tr.crumb == ["深渊商人 · " + info[0].split("　")[1], "抽取武器"], tr.crumb)
	var ok_tier := tr.list.items.size() == tier.size()
	for i in tier.size():
		ok_tier = ok_tier and tr.list.items[i].text == tier[i].text and bool(tr.list.items[i].get("disabled", false)) == (not tier[i].enabled)
	check("mc.tier.rows", ok_tier, tr.list.items)
	check("mc.tier.list_title_right", tr.list_right == page.title_lines[1], [tr.list_right, page.title_lines])
	var c0 := tr.card_data(tr.rows[0])
	check("mc.tier.card_help_and_button", str(c0.sections).contains(str(tier[0].help)) and c0.buttons[0].text == "抽取" and not c0.buttons[0].disabled, c0)
	await shots("merchant_tier")
	var key0 := str(XAbyssMerchant.run(s).identity.key)
	var cost0 := int(XTianqiMerchant.shelf("treasure").cost)
	# 点数不够：灰按钮＋橙字「还差 N 点」
	XAbyssMerchant.ledger(s).balances[key0] = cost0 - 4
	page.tiers("武器")
	var cs := tr.card_data(tr.rows[0])
	check("mc.tier.short_gray_button", cs.buttons[0].disabled and cs.buttons[0].text == XSkinMerchantPage.T_SHORT_POINTS and str(cs.sections).contains("还差 4 点"), cs)
	await shots("merchant_tier_short")
	# 灰行行尾写原因（T254 3.18）：点数不够／次数已用完／（首页池空）不可选；灰按钮点一下蜂鸣、焦点不留
	check("mc.row_reason_short", tr.list.items[0].get("right", "") == "点数不够" and tr.list.items[0].get("disabled", false), tr.list.items)
	var wev := _click(tr.card.button_rect(0).get_center())
	XSound.system_log.clear()
	tr._on_card_gui(wev)
	await frames(2)
	check("mc.click_disabled_buzz", XSound.system_log.has(3) and tr.card.button_index == -1, [XSound.system_log, tr.card.button_index])
	var run_used: int = int(XAbyssMerchant.run(s).used)
	XAbyssMerchant.ledger(s).balances[key0] = 100
	XAbyssMerchant.run(s).used = int(XAbyssMerchant.config().get("visitLimit", 0))
	page.tiers("武器")
	check("mc.row_reason_times", tr.list.items[0].get("right", "") == "次数已用完" and tr.card_data(tr.rows[0]).buttons[0].text == "次数已用完", tr.list.items)
	XAbyssMerchant.run(s).used = run_used
	# 珍藏行：按钮文字与可否进入跟列表行一致（不写「抽取」）
	XAbyssMerchant.ledger(s).balances[key0] = 100
	page.tiers("武器")
	var crow: Dictionary = tr.rows[1]
	var cc := tr.card_data(crow)
	check("mc.collection_button_matches_row", cc.buttons[0].disabled == (crow.get("enabled", true) == false) and cc.buttons[0].text != "抽取" and cc.buttons[0].text == ("不可选" if crow.get("enabled", true) == false else "选词条"), cc.buttons)
	check("mc.collection_row_reason", crow.get("enabled", true) != false or tr.list.items[1].get("right", "") == "不可选", tr.list.items[1])
	XAbyssMerchant.ledger(s).balances[key0] = cost0 - 4
	page.tiers("武器")
	# 灰行确定：蜂鸣、不扣点
	tr.index = 0
	XSound.system_log.clear()
	tr.ok()
	check("mc.tier.disabled_buzz", XSound.system_log == [3] and XAbyssMerchant.balance(s, key0) == cost0 - 4, XSound.system_log)
	# 点数够：确定＝抽一次，扣点，右上点数跟着变，次数 +1
	XAbyssMerchant.ledger(s).balances[key0] = 100
	page.tiers("武器")
	var used0 := int(XAbyssMerchant.run(s).used)
	tr.index = 0
	tr.ok()
	check("mc.tier.draw", XAbyssMerchant.balance(s, key0) == 100 - cost0 and tr.currencies[0][1] == XSkinTemplatePage._group(100 - cost0) and int(XAbyssMerchant.run(s).used) == used0 + 1, [tr.currencies, XAbyssMerchant.balance(s, key0)])
	# 出错的字进右牌：置灰行不会走到这里，直接调页的 set_text（同旧 choose29 的 catch）
	page.set_text("测试错误")
	check("mc.error_in_card", tr.card.title == XSkinMerchantPage.T_ERROR and str(tr.card.sections).contains("测试错误"), tr.card.sections)
	await shots("merchant_error")
	tr.cancel()   # 回首页：错误清掉
	check("mc.cancel_back_home", tr.crumb.size() == 1 and tr.flash == "" and tr.list.items.size() == home.size())
	# 装备池：每行「名字　分组」；右牌＝标准详情牌；按确定＝翻详情下一页；旧详情行每一条都在某一页里
	tr.index = 0
	tr.ok()
	var pool := XMerchant29Page.pool_rows(37)
	check("mc.pool.rows", tr.list.items.size() == pool.size() and tr.list.items[0].text == pool[0].text and tr.crumb[1] == "完整装备池", tr.list.items.size())
	var it0: Dictionary = pool[0].item
	check("mc.pool.card_title", tr.card.title == str(XSkinItemPage.card_data(it0).title).replace(XItemMarks.LOCK, "").strip_edges() or tr.card.title != "", tr.card.title)
	var want := XSkinTemplatePage.help_rows(XHelpCard.desc_params(XAffixAbsorb.view(it0), 1 if XHelpCard.kind_of(it0) == "weapon" else 2))
	var seen := {}
	for pg in tr._pages:
		for sec in pg:
			for r in sec.rows:
				seen[str(r.text).replace(":", "：")] = true   # T360 D250：属性行冒号统一成全角
	var all_in := true
	for r in want:
		all_in = all_in and seen.has(str(r.text).replace(":", "："))
	check("mc.pool.all_old_detail_rows_reachable", all_in and not want.is_empty(), [want.size(), seen.size()])
	check("mc.pool.page_text", tr.page_text() == "详情 %d / %d" % [tr.detail_page + 1, tr.detail_pages])
	check("mc.pool.pager_visible_iff_multi", tr.pager_bar.visible == (tr.detail_pages > 1))
	await shots("merchant_pool")
	# 翻详情：确定翻下一页（到头不动）、Q／E、滚轮、点两头都是同一个 turn
	var pages_n := tr.detail_pages
	tr.ok()
	check("mc.pool.ok_turns_next", tr.detail_page == mini(1, pages_n - 1), [tr.detail_page, pages_n])
	key(tr, KEY_Q)
	check("mc.pool.q_prev", tr.detail_page == 0)
	key(tr, KEY_E)
	check("mc.pool.e_next", tr.detail_page == mini(1, pages_n - 1))
	if pages_n > 1:
		tr.pager_bar.size = Vector2(300, 36)
		tr._on_pager_gui(_click(Vector2(10, 5)))
		check("mc.pool.click_left", tr.detail_page == 0)
		tr._on_pager_gui(_click(Vector2(290, 5)))
		check("mc.pool.click_right", tr.detail_page == 1)
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		tr._on_card_wheel(wheel)
		check("mc.pool.wheel_up", tr.detail_page == 0)
		tr.turn(1)
		await shots("merchant_pool_p2")
		check("mc.pool.list_not_paged_by_turn", tr.index == 0)
		tr.turn(-1)
	# 换一行：详情回第 1 页
	tr.list.select(1)
	check("mc.pool.row_change_resets_page", tr.detail_page == 0)
	# 分页器本身：每行恰好出现一次、每页至少一行、页数随预算
	var secs := [{"title": "甲", "rows": range(6).map(func(i): return {"text": "第%d行很长很长很长很长很长很长很长很长" % i})}, {"title": "乙", "rows": [{"text": "短"}]}]
	var pgs := XSkinMerchantPage.pack_pages(secs, 130.0, 160.0)
	var flat := []
	for pg in pgs:
		for sec in pg:
			for r in sec.rows:
				flat.append(r.text)
	check("mc.pack_pages.each_row_once", pgs.size() >= 2 and flat.size() == 7 and flat == secs[0].rows.map(func(r): return r.text) + ["短"], [pgs.size(), flat])
	check("mc.pack_pages.one_big_page", XSkinMerchantPage.pack_pages(secs, 99999.0, 160.0).size() == 1)
	tr.cancel()
	page.queue_free()
	await frames(2)
	# 专武·特效吸取：同一页，页名换成「特效吸取」，根面包屑「特效吸取」，右上不画战利品点
	var ab := XMerchant29Page.new()
	ab.mode = "absorb"
	add_child(ab)
	await frames(3)
	check("mc.absorb.title_and_crumb", ab.tree != null and ab.tree.title == "特效吸取" and ab.tree.crumb == ["特效吸取"] and ab.tree.currencies.is_empty(), [ab.tree.title, ab.tree.crumb])
	ab.queue_free()
	await frames(2)
	XAbyssMerchant.LAYER_LEDGER = true


# ---- 字体 130%、旧画法对照 ----

func _font_and_old() -> void:
	var s := _wh_state()
	XFontScale.set_value("global", 130)
	check("font130.mult", XUiSkin.font_mult() >= 1.29)
	var w := XWarehouseScene.new()
	add_child(w)
	await frames(3)
	check("font130.wh_builds", w.skin != null)
	await shots("warehouse_font130")
	w.queue_free()
	_fresh_star()
	_star_state()
	var st := _star_open(true)
	await frames(3)
	await shots("star_font130")
	st.queue_free()
	var s2 := await _present(37, 100)
	XAbyssMerchant.LAYER_LEDGER = false
	var m := XMerchant29Page.new()
	add_child(m)
	await frames(3)
	m.tree.index = 1
	m.tree.ok()
	m.tree.index = 2
	m.tree.sync()
	await shots("merchant_font130")
	m.queue_free()
	XAbyssMerchant.LAYER_LEDGER = true
	XFontScale.set_value("global", 100)
	await frames(2)
	_fresh_star()
	XSave.dir_override = "user://test_xiyou_ui_skin_card_n"
	if s2 == null or s == null:
		check("never", false)
