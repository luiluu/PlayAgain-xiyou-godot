extends Node
## 列表滚轮、翻页（ui9）：XMenu 公共函数照 Window_Selectable（rpg_windows.js）的 processWheel／scrollDown／scrollUp、
## cursorPagedown／cursorPageup；翻页键照正式版运行时的 Input.keyMapper（generated/oracle/party.json 的 keys：Q＝pageup、
## E＝pagedown、W＝up）。
## - 商店买入列表（Window_ShopBuy）：商品多于一页时光标带着窗口滚（ui9 前买入列表没有 topRow，光标会画到窗口外）；
##   用 shop_buy 参照里商品最多的店（冻结 v0.28 有 84 家店整理后多于 14 件）。
## - 主菜单指令窗、技能列表（两列）、存档、设置：翻页一次 topRow ＋ 页行数、index ＋ 页项数，末页再按不动。
## - 技能类型窗的 Q／E 仍是换角色（原版 setHandler('pageup'…)），不改成翻页。
## - 装备指令窗、状态页的换角色键也是 Q／E（ui10：原来写的 Q／W，W 在正式版是「上」）；按住不连发。
## - 回退开关 XMenu.LIST_PAGING = false：翻页键、滚轮都不认。
## - 扫描：modes/xiyou/ui 下用 XMenu._scroll_to 的列表页都要接滚轮与翻页，豁免的写明原因（防新页漏）。

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n := 2) -> void:
	for _i in range(n):
		await get_tree().process_frame


static func key(code: Key, echo := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	e.echo = echo
	return e


static func wheel(down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	e.pressed = true
	return e


static func action(name: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	return e


class CursorCanvas extends XMVCanvas:
	var cursors := []

	func text(_s: String, _x: float, _y: float, _max_w: float, _align := "left", _color := XUI.TEXT, _size := XUI.FONT_SIZE, _lh := XUI.LINE_HEIGHT, _alpha := 1.0, _zoom := 1.0, _pivot := Vector2.ZERO, _outline := OUTLINE) -> void:
		pass

	func icon(_index: int, _x: float, _y: float, _alpha := 1.0, _size := 32.0) -> void:
		pass

	func cursor(r: Rect2, _active := true) -> void:
		cursors.append(r)


## 技能列表用固定的 40 个技能（不依赖哪个角色学了多少）
class FixedSkillScene extends XSkillScene:
	var fixed := []

	func entries() -> Array:
		return fixed


func _run() -> void:
	_pure()
	_keys()
	await _shop()
	await _menu()
	await _skill()
	await _save_and_options()
	await _actor_switch_keys()
	await _ui11_pages()
	_scan()
	_scan_cursor_sound()
	XMenu.LIST_PAGING = true
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


## Window_Selectable 的翻页、滚轮算式（单列 30 项、一页 14 行；两列 41 项、一页 5 行）
func _pure() -> void:
	check("page_down", XMenu.page(0, 3, 30, 14, 1) == [14, 17], XMenu.page(0, 3, 30, 14, 1))
	check("page_down_clamp_top", XMenu.page(14, 20, 30, 14, 1) == [16, 29], XMenu.page(14, 20, 30, 14, 1))
	check("page_down_last_page_still", XMenu.page(16, 29, 30, 14, 1) == [16, 29])
	check("page_up", XMenu.page(16, 29, 30, 14, -1) == [2, 15], XMenu.page(16, 29, 30, 14, -1))
	check("page_up_first_page_still", XMenu.page(0, 5, 30, 14, -1) == [0, 5])
	check("page_short_list_still", XMenu.page(0, 2, 10, 14, 1) == [0, 2])
	check("page_two_cols", XMenu.page(0, 1, 41, 5, 1, 2) == [5, 11], XMenu.page(0, 1, 41, 5, 1, 2))
	check("page_two_cols_end", XMenu.page(5, 11, 41, 5, 1, 2) == [10, 21], XMenu.page(5, 11, 41, 5, 1, 2))
	check("page_empty", XMenu.page(0, 0, 0, 14, 1) == [0, 0])
	check("wheel_down", XMenu.wheel(0, 30, 14, 1) == 1)
	check("wheel_bottom_still", XMenu.wheel(16, 30, 14, 1) == 16)
	check("wheel_top_still", XMenu.wheel(0, 30, 14, -1) == 0)
	check("wheel_two_cols", XMenu.wheel(15, 41, 5, 1, 2) == 16 and XMenu.wheel(16, 41, 5, 1, 2) == 16)


func _keys() -> void:
	check("key_e_pagedown", XMenu.page_dir(key(KEY_E)) == 1)
	check("key_q_pageup", XMenu.page_dir(key(KEY_Q)) == -1)
	check("key_w_is_up_not_page", XMenu.page_dir(key(KEY_W)) == 0)
	check("key_pagedown_action", XMenu.page_dir(action("ui_page_down")) == 1 and XMenu.page_dir(action("ui_page_up")) == -1)
	check("key_echo_not_repeat", XMenu.page_dir(key(KEY_E, true)) == 0)
	check("wheel_dir", XMenu.wheel_dir(wheel(true)) == 1 and XMenu.wheel_dir(wheel(false)) == -1 and XMenu.wheel_dir(key(KEY_E)) == 0)
	XMenu.LIST_PAGING = false
	check("rollback_no_page_keys", XMenu.page_dir(key(KEY_E)) == 0 and XMenu.page_dir(action("ui_page_down")) == 0 and XMenu.wheel_dir(wheel(true)) == 0)
	XMenu.LIST_PAGING = true


func _biggest_shop() -> Array:
	var data = XDB.load_json("oracle/shop_buy.json")
	var best := []
	if data is Dictionary:
		for sh in data.shops:
			if sh.prepared.size() > best.size():
				best = sh.raw
	return best


func _shop() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.gold = 99999999
	var raw := _biggest_shop()
	var shop := XShop.new()
	shop.setup(raw, false)
	add_child(shop)
	await frames(4)
	var n := shop._buy_data().size()
	var rows := shop._list_rows()
	check("shop_many_goods", n > rows and rows == 14, [n, rows])
	shop._cmd = 0
	shop._ok()
	check("shop_in_buy", shop._mode == "buy")
	# 方向键走到第 20 件：窗口跟着滚，光标画在窗口里（ui9 前画到 y=720，窗口外）
	for _i in range(20):
		shop._move(1, true)
	shop._refresh()
	var c := CursorCanvas.new()
	c.size = shop.list_win.canvas.size
	shop._paint_list(c)
	var ys: Array = c.cursors.map(func(r): return r.position.y)
	check("shop_buy_scroll_follow", shop._buy_index == 20 and shop._buy_top == 7 and ys == [13 * XShop.LH], [shop._buy_index, shop._buy_top, ys])
	check("shop_buy_arrows", shop.list_win.up_arrow and shop.list_win.down_arrow)
	c.cursors.clear()
	# 滚轮：只滚窗口，光标不动
	shop._gui_input(wheel(true))
	check("shop_wheel_down", shop._buy_top == 8 and shop._buy_index == 20, [shop._buy_top, shop._buy_index])
	shop._gui_input(wheel(false))
	shop._gui_input(wheel(false))
	check("shop_wheel_up", shop._buy_top == 6 and shop._buy_index == 20, [shop._buy_top, shop._buy_index])
	# 点第 0 行选中的是 topRow 那件
	var p := shop.LIST_RECT.position + Vector2(XMVWindow.PADDING + 10, XMVWindow.PADDING + 5)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = p
	shop._gui_input(click)
	check("shop_click_top_row", shop._buy_index == 6, shop._buy_index)
	# E 翻页
	shop._unhandled_input(key(KEY_E))
	check("shop_page_down", shop._buy_top == 20 and shop._buy_index == 20, [shop._buy_top, shop._buy_index])
	for _i in range(10):
		shop._unhandled_input(key(KEY_E))
	# 86 件：topRow 20→34→48→62→72（夹到 maxTopRow），index 每次 ＋14 到 76；到末页后再按不动（不跳到末项）
	var last := 20 + rows * ceili((n - rows - 20) / float(rows))
	check("shop_page_down_end", shop._buy_top == n - rows and shop._buy_index == last, [shop._buy_top, shop._buy_index, n, last])
	shop._unhandled_input(key(KEY_Q))
	check("shop_page_up", shop._buy_top == n - 2 * rows and shop._buy_index == last - rows, [shop._buy_top, shop._buy_index])
	# 说明卡跟着画面里的行
	shop._update_help()
	check("shop_help_row", shop.help_card.visible, shop.help_card.visible)
	# 回退开关：翻页键与滚轮都不认（买入列表滚动本身是缺陷修正，不随开关回退）
	XMenu.LIST_PAGING = false
	var before := [shop._buy_top, shop._buy_index]
	shop._unhandled_input(key(KEY_E))
	shop._gui_input(wheel(true))
	check("shop_rollback", [shop._buy_top, shop._buy_index] == before, [shop._buy_top, shop._buy_index, before])
	XMenu.LIST_PAGING = true
	c.free()
	shop.queue_free()
	await frames()


func _menu() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var menu := XMenu.new()
	menu.event_state = s
	add_child(menu)
	await frames()
	menu._cmd_index = 2
	menu._unhandled_input(key(KEY_E))
	var n := XMenu.COMMANDS.size()
	check("menu_cmd_page_down", menu._cmd_top == n - XMenu.CMD_VISIBLE and menu._cmd_index == mini(2 + XMenu.CMD_VISIBLE, n - 1), [menu._cmd_top, menu._cmd_index])
	menu._unhandled_input(key(KEY_Q))
	check("menu_cmd_page_up", menu._cmd_top == 0 and menu._cmd_index == mini(2 + XMenu.CMD_VISIBLE, n - 1) - XMenu.CMD_VISIBLE, [menu._cmd_top, menu._cmd_index])
	menu.queue_free()
	await frames()


func _skill() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var page := FixedSkillScene.new()
	var skills: Array = XDB.table("Skills")
	for rec in skills:
		if rec is Dictionary and not rec.is_empty() and str(rec.get("name", "")) != "" and page.fixed.size() < 40:
			page.fixed.append(rec)
	add_child(page)
	await frames()
	var rows := page._list_rows()
	# 类型窗：Q／E 照原版是换角色
	page.mode = "type"
	page._unhandled_input(key(KEY_E))
	check("skill_type_q_e_change_actor", page.actor_index == 1 and page.top == 0, [page.actor_index, page.top])
	page.mode = "list"
	page.index = 1
	page.top = 0
	page._unhandled_input(key(KEY_E))
	# 40 项两列＝20 行：topRow 夹到 20 − 行数，index ＋ 行数×2
	check("skill_list_page_down", page.actor_index == 1 and page.top == 20 - rows and page.index == 1 + rows * 2, [page.actor_index, page.top, page.index, rows])
	page._unhandled_input(key(KEY_Q))
	check("skill_list_page_up", page.top == 0 and page.index == 1, [page.top, page.index])
	page._gui_input(wheel(true))
	check("skill_list_wheel", page.top == 1 and page.index == 1, [page.top, page.index])
	XMenu.LIST_PAGING = false
	page._unhandled_input(key(KEY_E))
	check("skill_list_rollback_changes_actor", page.actor_index == 2, page.actor_index)
	XMenu.LIST_PAGING = true
	page.queue_free()
	await frames()


## 装备指令窗（YEP_EquipCore setHandler pageup／pagedown）、状态页（JAH_StatusMenuCore）：Q 上一位、E 下一位、W 不换
func _actor_switch_keys() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	check("actor_key_helper", XMenu.actor_key(key(KEY_E), KEY_E) and not XMenu.actor_key(key(KEY_E, true), KEY_E) and not XMenu.actor_key(null, KEY_E))
	var eq := XEquipScene.new()
	add_child(eq)
	await frames()
	var i0 := eq.actor_index
	eq._unhandled_input(key(KEY_W))
	check("equip_w_not_switch", eq.actor_index == i0, [i0, eq.actor_index])
	eq._unhandled_input(key(KEY_E))
	check("equip_e_next_actor", eq.actor_index == i0 + 1, [i0, eq.actor_index])
	eq._unhandled_input(key(KEY_E, true))
	check("equip_e_echo_still", eq.actor_index == i0 + 1, eq.actor_index)
	eq._unhandled_input(key(KEY_Q))
	check("equip_q_prev_actor", eq.actor_index == i0, eq.actor_index)
	eq.queue_free()
	await frames()
	var st := XStatusPage.new()
	add_child(st)
	await frames()
	var j0 := st.actor_index
	st._unhandled_input(key(KEY_W))
	check("status_w_not_switch", st.actor_index == j0, [j0, st.actor_index])
	st._unhandled_input(key(KEY_E))
	check("status_e_next_actor", st.actor_index == j0 + 1, [j0, st.actor_index])
	st._unhandled_input(key(KEY_Q))
	check("status_q_prev_actor", st.actor_index == j0, st.actor_index)
	st.queue_free()
	await frames()


func _save_and_options() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var sp := XSaveScene.new()
	sp.mode = "load"
	add_child(sp)
	await frames()
	var rows := sp.page_rows()
	sp._unhandled_input(key(KEY_E))
	check("save_page_down", sp.top == mini(rows, XSave.SLOTS - rows) and sp.index == rows, [sp.top, sp.index, rows])
	sp._unhandled_input(action("ui_page_up"))
	check("save_page_up", sp.top == 0 and sp.index == 0, [sp.top, sp.index])
	sp.queue_free()
	await frames()
	var opt := XOptionsScene.new()
	add_child(opt)
	await frames()
	var n := opt._list.size()
	opt._unhandled_input(key(KEY_E))
	check("options_page_down", n > XOptionsScene.ROWS and opt.top == mini(XOptionsScene.ROWS, n - XOptionsScene.ROWS) and opt.index == XOptionsScene.ROWS, [n, opt.top, opt.index])
	opt.queue_free()
	await frames()


## ui11：事件选项窗、更衣、角色进阶、修炼目录、图鉴掉落列表（原版都是 Window_Selectable／Window_Command，不接管 pageup／pagedown）
func _ui11_pages() -> void:
	var ids := []
	for i in range(1, 41):
		ids.append(i)
	var s := XState.new_game(3, 1, ids)
	XState.current = s
	# 事件选项窗 30 行、一页 12 行
	var cw := XChoiceWindow.new()
	add_child(cw)
	await frames()
	var list := []
	for i in range(30):
		list.append({"label": "选项%d" % i})
	cw.open(list, func(_r): pass, func(): pass)
	var pr := cw.page_rows()
	cw._unhandled_input(key(KEY_E))
	check("choice_page_down", pr == 12 and cw.top == 12 and cw.index == 12, [pr, cw.top, cw.index])
	cw._unhandled_input(key(KEY_E))  # 12→18（夹到 maxTopRow），光标 24
	cw._unhandled_input(key(KEY_E))  # 末页再按不动（topRow＋页行数＝总行数）
	check("choice_page_end_clamped", cw.top == 18 and cw.index == 24, [cw.top, cw.index])
	cw._unhandled_input(key(KEY_Q))
	check("choice_page_up", cw.top == 6 and cw.index == 12, [cw.top, cw.index])
	cw._unhandled_input(key(KEY_W))
	check("choice_w_not_page", cw.top == 6 and cw.index == 12, [cw.top, cw.index])
	cw.queue_free()
	# 更衣：名单换成 30 人（只测翻页算式落在页上）
	var cs := XCostumesScene.new()
	add_child(cs)
	await frames()
	cs.actors = s.members().slice(0, 30)
	cs.index = 0
	cs.top = 0
	cs._unhandled_input(key(KEY_E))
	check("costumes_page_down", cs.top == XCostumesScene.ROWS and cs.index == XCostumesScene.ROWS, [cs.top, cs.index])
	cs._unhandled_input(action("ui_page_up"))
	check("costumes_page_up", cs.top == 0 and cs.index == 0, [cs.top, cs.index])
	cs.queue_free()
	# 角色进阶：名单 40 人
	var aa := XActorAdvancedScene.new()
	add_child(aa)
	await frames()
	var ar := aa.rows()
	var na: int = aa.members.size()
	aa._unhandled_input(key(KEY_E))
	check("advanced_page_down", na > ar and aa.top == mini(ar, na - ar) and aa.index == ar, [na, ar, aa.top, aa.index])
	var w0 := XMenu.wheel_dir(wheel(true))
	aa._unhandled_input(key(KEY_Q))
	check("advanced_page_up", aa.top == 0 and aa.index == 0 and w0 == 1, [aa.top, aa.index])
	aa.queue_free()
	# 修炼目录：40 人、一页 19 行；滚轮只滚不动光标
	var tr := XTrainingScene.new()
	add_child(tr)
	await frames()
	tr._unhandled_input(key(KEY_E))
	check("training_page_down", tr.top == XTrainingScene.INDEX_ROWS and tr.index == XTrainingScene.INDEX_ROWS, [tr.top, tr.index])
	tr._unhandled_input(key(KEY_Q))
	var wv := wheel(true)
	wv.position = Vector2(100, 100)
	tr._gui_input(wv)
	check("training_wheel_scrolls_only", tr.top == 1 and tr.index == 0, [tr.top, tr.index])
	tr.queue_free()
	# 图鉴掉落列表：塞 60 行（复制一只敌人的掉落行），一页按 drop_rows_visible
	var eb := XEnemyBookPage.new()
	add_child(eb)
	await frames()
	var row0 := {}
	for id in range(1, 200):
		var dr := XEnemyBookPage.drop_rows(XEnemyBookPage.new_enemy(id))
		if not dr.is_empty():
			row0 = dr[0]
			break
	var fake := []
	for i in range(60):
		fake.append(row0)
	eb.mode = "drops"
	eb.drop_list = fake
	eb.drop_index = 0
	eb.drop_top = 0
	var dv := eb.drop_rows_visible()
	eb._unhandled_input(key(KEY_E))
	check("book_drops_page_down", not row0.is_empty() and eb.drop_top == dv and eb.drop_index == dv, [dv, eb.drop_top, eb.drop_index])
	var wb := wheel(true)
	wb.position = XEnemyBookPage.STATUS_RECT.get_center()
	eb._gui_input(wb)
	check("book_drops_wheel", eb.drop_top == dv + 1 and eb.drop_index == dv, [eb.drop_top, eb.drop_index])
	eb.mode = "index"
	eb.queue_free()
	await frames()


## 用 XMenu._scroll_to 的列表页都要接滚轮与翻页；豁免写原因
const SCAN_EXEMPT := {
}


func _scan() -> void:
	var dir := "res://modes/xiyou/ui/"
	var listed := 0
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string(dir + f)
		if not src.contains("_scroll_to("):
			continue
		listed += 1
		if f in SCAN_EXEMPT:
			continue
		var has_wheel := src.contains("MOUSE_BUTTON_WHEEL") or src.contains("XMenu.wheel_dir(") or src.contains("wheel_dir(")
		var has_page := src.contains("page_dir(") or src.contains("ui_page_down")
		check("scan_wheel_" + f, has_wheel)
		check("scan_page_" + f, has_page)
	check("scan_found_pages", listed >= 20, listed)


## 光标音（ui15）：界面里「移动／翻页」函数（名叫 _move／move／_move_list／page／_page／_scroll）本身或它调到的同文件函数里要有 XSound.system(0)；
## 原版 Window_Selectable 的 cursorUp／Down／pageup／pagedown／选项移动都响 SoundManager.playCursor。豁免写明原因。
const CURSOR_FUNCS := ["_move", "move", "_move_list", "page", "_page", "_scroll"]
const CURSOR_DIRS := ["res://modes/xiyou/ui/", "res://modes/xiyou/battle/"]
## 文件 → 原因（整个文件不扫）／ 文件::函数 → 原因（只豁免这个函数）
const CURSOR_EXEMPT := {
	"sequence_player.gd": "战斗演出序列的 move 指令（移动精灵），不是列表光标",
	"otb_bar.gd": "行动条图标位移，不是列表光标",
	"menu.gd::_move": "静态纯函数（算新下标）；光标音在输入处理里响（index 变了才响，同 processCursorMove）",
	"menu.gd::page": "静态纯函数（算翻页后的顶行、下标）；光标音在输入处理里响",
	"achievement_scene.gd::_scroll": "鼠标滚轮只滚动显示、不移光标：Window_Selectable.processWheel 不响",
	"battle_list.gd::_scroll": "鼠标滚轮只滚动显示、不移光标：Window_Selectable.processWheel 不响",
	"battle_list.gd::page": "光标音在 _unhandled_input 末尾 if index != last 统一响（原版 processCursorMove 同样看下标变没变）",
	"status_page.gd::_scroll": "JAH_Window_Status_PageSelect 是横排命令窗，上下键 cursorUp/Down 不改下标（index < maxCols）→ processCursorMove 不响；只有左右换页（set_page）响。2026-11-05 核对 JAH_StatusMenuCore.js:2105、rpg_windows.js:1018",
}


static func _func_bodies(src: String) -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string("(?m)^(?:static )?func (\\w+)")
	var ms := re.search_all(src)
	for i in range(ms.size()):
		var end := ms[i + 1].get_start() if i + 1 < ms.size() else src.length()
		out[ms[i].get_string(1)] = out.get(ms[i].get_string(1), "") + src.substr(ms[i].get_start(), end - ms[i].get_start())
	return out


static func _plays_cursor(name: String, bodies: Dictionary, seen := {}) -> bool:
	if seen.has(name) or not bodies.has(name):
		return false
	seen[name] = true
	var body: String = bodies[name]
	if body.contains("XSound.system(0)"):
		return true
	for callee in bodies.keys():
		if callee != name and body.contains(callee + "(") and _plays_cursor(callee, bodies, seen):
			return true
	return false


func _scan_cursor_sound() -> void:
	var seen_funcs := 0
	for dir in CURSOR_DIRS:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd") or f in CURSOR_EXEMPT:
				continue
			var bodies := _func_bodies(FileAccess.get_file_as_string(dir + f))
			for fn in CURSOR_FUNCS:
				if bodies.has(fn) and not CURSOR_EXEMPT.has(f + "::" + fn):
					seen_funcs += 1
					check("cursor_se_%s::%s" % [f, fn], _plays_cursor(fn, bodies))
	check("cursor_scan_found", seen_funcs >= 30, seen_funcs)
