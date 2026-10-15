class_name XShop
extends Control
## 商店，按正式版运行时逐像素复现（参照截图：04_验证/本地结果/原版参照/20～25）。
## goods = [[类型 0物品/1武器/2防具, ID, 价格类型 0标准/1指定, 价格], ...]；买入用数据库价格或指定价格，卖出半价（MV）。
## 窗口（YEP_ShopMenuCore＋本 MOD 调整，1280×720）：
## - 指令 (0,1,240,172)：购买 / 出售 / 一键出售 / 取消，居中；出售时换成分类窗（物品/消耗品/武器/护甲/重要物品）。
## - 信息 (240,1,1040,172)：YEP 物品状态（XItemStatusPainter）。
## - 列表 (0,173,768,547)：购买列表、出售列表、数量窗共用此位置；指令阶段是空窗。
## - 状态 (768,173,512,483)：持有数；装备显示「<< 队员 >>」与 8 项能力增减（本 MOD 右移 220，左边留给物品说明卡）。
## - 金钱 (768,656,512,64)。
## - HelpExtend 说明卡（XHelpCard）：购买/出售列表选中行旁；数量窗、分类、指令阶段隐藏（原版 onBuyOk/onSellOk 时 clear）。
## - 一键出售（Star_ShopOnekey＋installUnifiedQualityRuntime）：Window_OnekeySellCommand (350,150,240,行数×36+内边距×2)，
##   七档「出售X品质」左对齐；确定即卖出背包里该档（旧档 0～14）不带「[锁定]」的装备、无确认，然后回到指令窗（取消同）。
## - 出售列表套用出售锁定／道具置顶（XItemMarks.apply_list）；选中锁定的物品时提示「已锁定 无法出售」并留在列表。
## 尚未复现：新物品「NEW」标记，见 界面风格.md。

signal closed

const CMD_RECT := Rect2(0, 1, 240, 172)
const INFO_RECT := Rect2(240, 1, 1040, 172)
const LIST_RECT := Rect2(0, 173, 768, 547)
const STATUS_RECT := Rect2(768, 173, 512, 483)
const GOLD_RECT := Rect2(768, 656, 512, 64)
const LH := 36.0
const GOLD_FONT := 20
const QTY_FONT := 20
const MAX_ITEMS := 9999
const COMMANDS := [["购买", "buy"], ["出售", "sell"], ["一键出售", "onekey"], ["取消", "cancel"]]
const ONEKEY_POS := Vector2(350, 150)
const ONEKEY_W := 240.0
const CATEGORIES := [["物品", "item"], ["消耗品", "consumable"], ["武器", "weapon"], ["护甲", "armor"], ["重要物品", "keyItem"]]

var goods: Array = []
var purchase_only := false
var _mode := "command"          # command / buy / category / sell / number / onekey
var _onekey := 0
var _cmd := 0
var _cat := 0
var _cat_top := 0
var _buy_index := 0
var _sell_index := 0
var _sell_top := 0
var _number := 1
var _number_from := "buy"
var _actor_index := 0
var cmd_win: XMVWindow
var info_win: XMVWindow
var list_win: XMVWindow
var status_win: XMVWindow
var gold_win: XMVWindow
var onekey_win: XMVWindow
var help_card: XHelpCard


func setup(g: Array, only: bool) -> void:
	goods = g
	purchase_only = only


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var op := XUI.MENU_WINDOW_OPACITY
	cmd_win = XMVWindow.make(self, CMD_RECT, op, _paint_cmd)
	info_win = XMVWindow.make(self, INFO_RECT, op, _paint_info)
	list_win = XMVWindow.make(self, LIST_RECT, op, _paint_list)
	status_win = XMVWindow.make(self, STATUS_RECT, op, _paint_status)
	gold_win = XMVWindow.make(self, GOLD_RECT, op, _paint_gold)
	var n := XItemMarks.onekey_grades().size()
	onekey_win = XMVWindow.make(self, Rect2(ONEKEY_POS, Vector2(ONEKEY_W, n * LH + XMVWindow.PADDING * 2)), op, _paint_onekey)
	onekey_win.visible = false
	for w in [cmd_win, list_win, onekey_win]:
		w.canvas.blink = true
	help_card = XHelpCard.new()
	add_child(help_card)
	_refresh()


func _refresh() -> void:
	var cats := _mode in ["category", "sell"] or (_mode == "number" and _number_from == "sell")
	cmd_win.down_arrow = cats and _cat_top < CATEGORIES.size() - 4
	cmd_win.up_arrow = cats and _cat_top > 0
	var n := _sell_data().size()
	list_win.down_arrow = _mode == "sell" and _sell_top < n - _list_rows()
	list_win.up_arrow = _mode == "sell" and _sell_top > 0
	onekey_win.visible = _mode == "onekey"
	for w in [cmd_win, info_win, list_win, status_win, gold_win, onekey_win]:
		w.refresh()
	_update_help()


## Window_ShopBuy / Window_ShopSell.updateHelp：说明卡跟着选中行（横向取整个列表窗口）
func _update_help() -> void:
	if help_card == null:
		return
	var row := -1
	match _mode:
		"buy":
			row = _buy_index
		"sell":
			row = _sell_index - _sell_top
	var rec := _current_rec() if row >= 0 else {}
	help_card.show_for(rec)
	if help_card.visible:
		help_card.place_for_row(Rect2(list_win.position + Vector2(0, list_win.padding + row * LH), Vector2(list_win.size.x, LH)))


static func table_of(kind: int) -> String:
	return ["Items", "Weapons", "Armors"][kind]


func _price(g: Array) -> int:
	var rec := XDB.rec(table_of(int(g[0])), int(g[1]))
	return int(g[3]) if int(g[2]) == 1 else int(rec.get("price", 0))


func _buy_data() -> Array:
	var out := []
	for g in goods:
		var rec := XDB.rec(table_of(int(g[0])), int(g[1]))
		if not rec.is_empty():
			out.append({"rec": rec, "kind": int(g[0]), "price": _price(g)})
	return out


## 出售列表：按分类列出持有物（装备是背包实例）；价格为一半（MV Scene_Shop.sellingPrice）。
func _sell_data() -> Array:
	var s := XState.current
	var out := []
	var sym: String = CATEGORIES[_cat][1]
	if sym in ["item", "consumable", "keyItem"]:
		var ids := s.items.keys().map(func(k): return int(k))
		ids.sort()
		for id in ids:
			var rec := XDB.rec("Items", id)
			if rec.is_empty() or s.item_count(id) <= 0:
				continue
			var key := int(rec.get("itypeId", 1)) == 2
			if sym == "keyItem" and not key:
				continue
			if sym == "item" and key:
				continue
			if sym == "consumable" and (key or not bool(rec.get("consumable", false))):
				continue
			out.append({"rec": rec, "kind": 0, "count": s.item_count(id)})
		out = XItemMarks.apply_list(s, out)
	else:
		for e in s.gear:
			if e.kind == sym:
				out.append({"rec": e, "kind": 1 if sym == "weapon" else 2, "count": 1})
	return out


func _current_rec() -> Dictionary:
	match _mode:
		"buy":
			var d := _buy_data()
			return d[_buy_index].rec if _buy_index < d.size() else {}
		"sell":
			var d := _sell_data()
			return d[_sell_index].rec if _sell_index < d.size() else {}
		"number":
			return _number_entry().rec if not _number_entry().is_empty() else {}
	return {}


func _number_entry() -> Dictionary:
	if _number_from == "buy":
		var d := _buy_data()
		return d[_buy_index] if _buy_index < d.size() else {}
	var d := _sell_data()
	return d[_sell_index] if _sell_index < d.size() else {}


func _list_rows() -> int:
	return floori((LIST_RECT.size.y - 28) / LH)


# ---- 绘制 ----
func _paint_cmd(c: XMVCanvas) -> void:
	if _mode in ["category", "sell"] or (_mode == "number" and _number_from == "sell"):
		for i in range(CATEGORIES.size()):
			var y := (i - _cat_top) * LH
			if y < 0 or y >= c.size.y:
				continue
			if i == _cat:
				c.cursor(Rect2(0, y, c.size.x, LH), _mode == "category")
			c.text(CATEGORIES[i][0], 6, y, c.size.x - 12, "center")
		return
	for i in range(COMMANDS.size()):
		if i == _cmd:
			c.cursor(Rect2(0, i * LH, c.size.x, LH), _mode == "command")
		c.text(COMMANDS[i][0], 6, i * LH, c.size.x - 12, "center", XUI.TEXT, XUI.FONT_SIZE, LH, 1.0 if _cmd_enabled(i) else XUI.DIM.a)


func _cmd_enabled(i: int) -> bool:
	match COMMANDS[i][1]:
		"sell":
			return not purchase_only
		"onekey":
			return not purchase_only
	return true


func _paint_onekey(c: XMVCanvas) -> void:
	var rows := XItemMarks.onekey_grades()
	for i in range(rows.size()):
		if i == _onekey:
			c.cursor(Rect2(0, i * LH, c.size.x, LH))
		c.text(rows[i].text, 6, i * LH, c.size.x - 12, "left")


func _paint_info(c: XMVCanvas) -> void:
	XItemStatusPainter.paint(c, _current_rec())


## MV drawItemName：图标 (x+2, y+2)，名字从 x+36 起，品质颜色（ItemQuality）。
func _item_name(c: XMVCanvas, rec: Dictionary, x: float, y: float, w: float, alpha := 1.0) -> void:
	c.icon(int(rec.get("iconIndex", 0)), x + 2, y + 2, alpha)
	c.text(XQuality.list_name(rec), x + 36, y, w - 36, "left", XGear.color(rec), XUI.FONT_SIZE, LH, alpha)


## YEP drawCurrencyValue：字号 20，数值右对齐，金钱图标在最右
func _currency(c: XMVCanvas, value: String, x: float, y: float, w: float, alpha := 1.0) -> void:
	c.text(value, x, y, w - 32 - 4, "right", XUI.TEXT, GOLD_FONT, LH, alpha)
	c.icon(XMenu.GOLD_ICON, x + w - 32, y + 2, alpha)


func _paint_list(c: XMVCanvas) -> void:
	var s := XState.current
	match _mode:
		"buy":
			var d := _buy_data()
			for i in range(d.size()):
				var y := i * LH
				var w := c.size.x - 6
				var ok: bool = s.gold >= int(d[i].price)
				var a := 1.0 if ok else XUI.DIM.a
				if i == _buy_index:
					c.cursor(Rect2(0, y, c.size.x, LH))
				_item_name(c, d[i].rec, 0, y, w, a)
				_currency(c, XMenu._group(int(d[i].price)), 0, y, w, a)
		"sell":
			var d := _sell_data()
			var qty_w := c.text_width("×" + XMenu._group(MAX_ITEMS), QTY_FONT)
			for i in range(d.size()):
				var y := (i - _sell_top) * LH
				if y < 0 or y >= c.size.y:
					continue
				var w := c.size.x - 6
				var a := 1.0 if int(d[i].rec.get("price", 0)) > 0 else XUI.DIM.a
				if i == _sell_index:
					c.cursor(Rect2(0, y, c.size.x, LH))
				_item_name(c, d[i].rec, 0, y, w - qty_w, a)
				if int(d[i].kind) == 0:
					c.text("×" + XMenu._group(int(d[i].count)), 0, y, w, "right", XUI.TEXT, QTY_FONT, LH, a)
		"number":
			_paint_number(c)


## YEP Window_ShopNumber：名字在第 1 行，「× 数量」在第 2 行（数量带光标），第 3 行起是现有金钱、增减、横线与结算。
func _paint_number(c: XMVCanvas) -> void:
	var e := _number_entry()
	if e.is_empty():
		return
	var price := int(e.price) if _number_from == "buy" else int(e.rec.get("price", 0)) / 2
	_item_name(c, e.rec, 0, LH, c.size.x)
	var cw := c.text_width(XMenu._group(MAX_ITEMS)) + 12
	var cx := c.size.x - cw - 6
	var y := LH * 2
	var sign_w := c.text_width("×")
	c.text("×", cx - sign_w * 2, y, sign_w)
	c.cursor(Rect2(cx, y, cw, LH))
	c.text(XMenu._group(_number), cx, y, cw - 6, "right")
	var ww := c.size.x - 6
	var gold := XState.current.gold
	var cost := price * _number
	_line(c, LH * 3)
	_currency(c, XMenu._group(gold), 0, y + LH, ww)
	_currency(c, ("+" + XMenu._group(cost)) if _number_from == "sell" else XMenu._group(-cost), 0, y + LH * 2, ww)
	_line(c, y + LH * 3)
	_currency(c, XMenu._group(gold + (cost if _number_from == "sell" else -cost)), 0, y + LH * 3, ww)


static func _line(c: XMVCanvas, y: float) -> void:
	c.draw_rect(Rect2(0, y, c.size.x, 2), Color(1, 1, 1, 128.0 / 255.0))


func _paint_status(c: XMVCanvas) -> void:
	var rec := _current_rec()
	if rec.is_empty():
		return
	var s := XState.current
	var owned := 0
	if rec.has("itypeId"):
		owned = s.item_count(int(rec.id))
	else:
		var kind: String = rec.get("kind", "weapon" if rec.has("wtypeId") else "armor")
		owned = s.gear_count(kind, int(rec.get("base", rec.id)))
	var w := c.size.x - 12
	c.text("持有数", 6, 0, w, "left", XUI.SYSTEM)
	c.text(XMenu._group(owned), 6, 0, w, "right")
	if rec.has("itypeId") or not rec.has("etypeId"):
		return
	# 「<< 队员 >>」与 8 项能力增减（actor 模式；左右键切换队员）
	var members := s.members()
	_actor_index = clampi(_actor_index, 0, members.size() - 1)
	var a: XActor = members[_actor_index]
	c.text(a.display_name(), 0, LH, c.size.x, "center")
	c.text("<<", 0, LH, c.size.x, "left", XUI.SYSTEM)
	c.text(">>", 0, LH, c.size.x, "right", XUI.SYSTEM)
	var half := floorf(c.size.x / 2.0)
	var item := rec if rec.has("kind") else XGear.template("weapon" if rec.has("wtypeId") else "armor", int(rec.id))
	var slot: int = a.equip_slots().find(int(item.etypeId))
	var cur = a.equips[slot] if slot >= 0 and slot < a.equips.size() else null
	var can := a.can_equip(item)
	for i in range(8):
		var y := LH * 2 + i * LH
		c.draw_rect(Rect2(220 + 1, y + 1, half - 2, LH - 2), Color(XUI.GAUGE_BACK, 160.0 / 255.0))
		c.text(XItemStatusPainter.param_name(i), 220 + 6, y, half - 12, "left", XUI.SYSTEM, 20, LH)
		if not can:
			c.text("-", 220 + 6, y, half - 12, "right", XUI.TEXT, 20, LH, XUI.DIM.a)
			continue
		var change := int(item.params[i]) - (int(cur.params[i]) if cur != null else 0)
		c.text(("+" if change > 0 else "") + XMenu._group(change), 220 + 6, y, half - 12, "right",
			XItemStatusPainter.change_color(change), 20, LH, 1.0 if change != 0 else XUI.DIM.a)


func _paint_gold(c: XMVCanvas) -> void:
	_currency(c, XMenu._group(XState.current.gold), 6, 0, c.size.x - 12)


# ---- 操作 ----
func _unhandled_input(event: InputEvent) -> void:
	var handled := true
	if event.is_action_pressed("ui_cancel"):
		_cancel()
	elif event.is_action_pressed("ui_accept"):
		_ok()
	elif event.is_action_pressed("ui_down", true):
		_move(1 if _mode != "number" else -10, not event.is_echo())
	elif event.is_action_pressed("ui_up", true):
		_move(-1 if _mode != "number" else 10, not event.is_echo())
	elif event.is_action_pressed("ui_right", true):
		if _mode == "number":
			_change_number(1)
		else:
			_actor_index = (_actor_index + 1) % XState.current.members().size()
	elif event.is_action_pressed("ui_left", true):
		if _mode == "number":
			_change_number(-1)
		else:
			_actor_index = (_actor_index - 1 + XState.current.members().size()) % XState.current.members().size()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()
		_refresh()


func _move(d: int, wrap: bool) -> void:
	match _mode:
		"command":
			_cmd = XMenu._move(_cmd, d, COMMANDS.size(), wrap)
		"category":
			_cat = XMenu._move(_cat, d, CATEGORIES.size(), wrap)
			_cat_top = XMenu._scroll_to(_cat, _cat_top, 4)
		"buy":
			var n := _buy_data().size()
			if n > 0:
				_buy_index = XMenu._move(_buy_index, d, n, wrap)
		"sell":
			var n := _sell_data().size()
			if n > 0:
				_sell_index = XMenu._move(_sell_index, d, n, wrap)
				_sell_top = XMenu._scroll_to(_sell_index, _sell_top, _list_rows())
		"number":
			_change_number(d)
		"onekey":
			_onekey = XMenu._move(_onekey, d, XItemMarks.onekey_grades().size(), wrap)


## MV Window_ShopNumber：上下 ±10、左右 ±1，范围 1～最大可买/可卖数
func _change_number(d: int) -> void:
	_number = clampi(_number + d, 1, maxi(1, _max_number()))


func _max_number() -> int:
	var e := _number_entry()
	if e.is_empty():
		return 1
	if _number_from == "sell":
		return int(e.count)
	var price := int(e.price)
	var have := _owned(e)
	var by_gold := MAX_ITEMS if price <= 0 else XState.current.gold / price
	return mini(by_gold, MAX_ITEMS - have)


func _owned(e: Dictionary) -> int:
	if int(e.kind) == 0:
		return XState.current.item_count(int(e.rec.id))
	return XState.current.gear_count("weapon" if int(e.kind) == 1 else "armor", int(e.rec.id))


func _ok() -> void:
	_ok_inner()
	_refresh()


func _ok_inner() -> void:
	var s := XState.current
	match _mode:
		"command":
			if not _cmd_enabled(_cmd):
				return
			match COMMANDS[_cmd][1]:
				"buy":
					_mode = "buy"
					_buy_index = clampi(_buy_index, 0, maxi(0, _buy_data().size() - 1))
				"sell":
					_mode = "category"
				"onekey":
					_mode = "onekey"
				"cancel":
					closed.emit()
		"category":
			_mode = "sell"
			_sell_index = 0
			_sell_top = 0
		"buy":
			var d := _buy_data()
			if _buy_index < d.size() and s.gold >= int(d[_buy_index].price) and _max_number() > 0:
				_number_from = "buy"
				_number = 1
				_mode = "number"
		"sell":
			var d := _sell_data()
			if _sell_index < d.size() and int(d[_sell_index].rec.get("price", 0)) > 0:
				# Star_ShopOnekey onSellOk：名字带「[锁定]」的不能卖
				if str(d[_sell_index].rec.get("name", "")).contains(XItemMarks.LOCK):
					XToast.show_text("已锁定 无法出售", true)
					return
				_number_from = "sell"
				_number = 1
				_mode = "number"
		"number":
			_trade()
		"onekey":
			var rows := XItemMarks.onekey_grades()
			XItemMarks.onekey_sell(s, int(rows[_onekey].grade))
			_mode = "command"


func _trade() -> void:
	var s := XState.current
	var e := _number_entry()
	if _number_from == "buy":
		var cost := int(e.price) * _number
		if s.gold < cost:
			return
		s.gain_gold(-cost)
		match int(e.kind):
			0: s.gain_item(int(e.rec.id), _number)
			1: s.gain_gear("weapon", int(e.rec.id), _number)
			2: s.gain_gear("armor", int(e.rec.id), _number)
		_mode = "buy"
	else:
		var price := XItemMarks.selling_price(e.rec)
		s.gain_gold(price * _number)
		if int(e.kind) == 0:
			s.gain_item(int(e.rec.id), -_number)
		else:
			s.gear.erase(e.rec)
		_mode = "sell"
		var n := _sell_data().size()
		_sell_index = clampi(_sell_index, 0, maxi(0, n - 1))


func _cancel() -> void:
	_cancel_inner()
	_refresh()


func _cancel_inner() -> void:
	match _mode:
		"command":
			closed.emit()
		"buy", "category", "onekey":
			_mode = "command"
		"sell":
			_mode = "category"
		"number":
			_mode = _number_from


## 鼠标：点列表行（与指令行）先选中，再点确定；右键取消。
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel()
		_refresh()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var p: Vector2 = event.position
	var pad := Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
	if _mode == "onekey":
		var r := Rect2(onekey_win.position, onekey_win.size)
		var i := floori((p - r.position - pad).y / LH)
		if r.has_point(p) and i >= 0 and i < XItemMarks.onekey_grades().size():
			if i == _onekey:
				_ok()
			else:
				_onekey = i
	elif CMD_RECT.has_point(p) and _mode in ["command", "category"]:
		var i := floori((p - CMD_RECT.position - pad).y / LH)
		if _mode == "command" and i >= 0 and i < COMMANDS.size():
			if i == _cmd:
				_ok()
			else:
				_cmd = i
		elif _mode == "category" and i + _cat_top >= 0 and i + _cat_top < CATEGORIES.size():
			if i + _cat_top == _cat:
				_ok()
			else:
				_cat = i + _cat_top
	elif LIST_RECT.has_point(p):
		var i := floori((p - LIST_RECT.position - pad).y / LH)
		if _mode == "buy" and i >= 0 and i < _buy_data().size():
			if i == _buy_index:
				_ok()
			else:
				_buy_index = i
		elif _mode == "sell" and i + _sell_top < _sell_data().size() and i >= 0:
			if i + _sell_top == _sell_index:
				_ok()
			else:
				_sell_index = i + _sell_top
		elif _mode == "number":
			_ok()
	elif STATUS_RECT.has_point(p):
		var x := (p - STATUS_RECT.position - pad).x
		var n := XState.current.members().size()
		if x < 60:
			_actor_index = (_actor_index - 1 + n) % n
		elif x > STATUS_RECT.size.x - 88:
			_actor_index = (_actor_index + 1) % n
	_refresh()
