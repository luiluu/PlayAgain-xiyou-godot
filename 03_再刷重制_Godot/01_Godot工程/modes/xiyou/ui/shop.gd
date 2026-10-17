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
## - 出售列表的行同物品页（XItemRow）：画 NEW 但不记看过；装备按背包原序、右侧「序号/9,999」。
## - 限购（KMS_ShopInventory，XShopStock）：stock_group 非空时，售完的商品画名字＋右侧「售完」（宽 96、白字、按不可买半透明）且不可买，
##   数量上限再与库存取小；状态窗第 2 行画「库存 剩余/上限」（插件参数名不符，按默认只画在状态窗，数量窗不画）。
##   装备商品原版这一行与「<< 队员 >>」重叠，改画在能力表下方（O-043，STOCK_GEAR_BELOW 设 false 回到原版）。

signal closed

const CMD_RECT := Rect2(0, 1, 240, 172)
const INFO_RECT := Rect2(240, 1, 1040, 172)
const LIST_RECT := Rect2(0, 173, 768, 547)
const STATUS_RECT := Rect2(768, 173, 512, 483)
const GOLD_RECT := Rect2(768, 656, 512, 64)
const LH := 36.0
const GOLD_FONT := 20
const MAX_ITEMS := 9999
const MC_PADDING := 5          # YEP_X_MoreCurrencies Currency Padding
const COMMANDS := [["购买", "buy"], ["出售", "sell"], ["一键出售", "onekey"], ["取消", "cancel"]]
const ONEKEY_POS := Vector2(350, 150)
const ONEKEY_W := 240.0
const CATEGORIES := [["物品", "item"], ["消耗品", "consumable"], ["武器", "weapon"], ["护甲", "armor"], ["重要物品", "keyItem"]]
const SOLD_OUT := "售完"            # KMS_ShopInventory 参数 Sold out text
const STOCK_CAPTION := "库存"       # Caption for stock
const SOLD_OUT_W := 96.0
## O-043：装备商品的库存行画在能力表下方（第 11 行、26 号字）；false 为原版（第 2 行、沿用能力表的 20 号字，与队员名重叠）
static var STOCK_GEAR_BELOW := true

var goods: Array = []
var purchase_only := false
var stock_group := ""           # KMS_ShopInventory 库存组（XShopStock.open 取得；"" 为不限购）
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
var _gold_item := {}            # 金钱窗跟随的商品（Window_Gold._item）
var _gold_buy := true


func setup(g: Array, only: bool, group := "") -> void:
	goods = g
	purchase_only = only
	stock_group = group


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
	# Window_ShopBuy／Window_ShopSell.updateHelp 设金钱窗的商品；onBuyCancel 清空（出售取消不清）
	if _mode == "buy":
		var d := _buy_data()
		_gold_item = d[_buy_index].item if _buy_index < d.size() else {}
		_gold_buy = true
	elif _mode == "sell":
		var d := _sell_data()
		_gold_item = d[_sell_index].rec if _sell_index < d.size() else {}
		_gold_buy = false
	elif _mode == "command" and _gold_buy:
		_gold_item = {}
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


## 购买列表：商品表先经 Scene_Shop.prepare 的改写（XItemMarks.shop_goods）。rec 是显示用记录（代购时抄上代购件的名字、图标、说明），
## item 是买入各函数用的商品记录（装备带 kind/base），price 是金币价（指定价格优先）。
func _buy_data() -> Array:
	var out := []
	for g in XItemMarks.shop_goods(goods):
		var rec := XDB.rec(table_of(int(g[0])), int(g[1]))
		if not rec.is_empty():
			out.append({"rec": XItemMarks.shop_display(rec), "item": XItemMarks.shop_rec(int(g[0]), int(g[1])), "kind": int(g[0]), "gid": int(g[1]), "price": _price(g)})
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
		# Window_ShopSell 不列身上装备、不走 Codex 排序：按 $gameParty.weapons()/armors() 原序，右侧「序号/9,999」
		var bag := XItemScene.bag_gear(sym)
		for i in range(bag.size()):
			out.append({"rec": bag[i], "kind": 1 if sym == "weapon" else 2, "count": 1, "carry": i + 1})
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


## Window_ShopBuy.isEnabled：原链（XItemMarks.can_buy）且有库存
func _buy_enabled(e: Dictionary) -> bool:
	return XItemMarks.can_buy(XState.current, e.item, int(e.price)) and XShopStock.available(XState.current, stock_group, int(e.kind), int(e.gid))


## 状态窗库存行的 [类型, ID, 剩余]：购买（含数量窗）按商品表；出售按持有物——物品照该组库存，
## 装备实例原版另记在实例 ID 上（从未扣过）恒为上限。不画时返回 []
func _stock_row() -> Array:
	if stock_group == "":
		return []
	var from := _number_from if _mode == "number" else _mode
	var s := XState.current
	if from == "buy":
		var e := _number_entry() if _mode == "number" else {}
		var d := _buy_data()
		if e.is_empty() and _buy_index < d.size():
			e = d[_buy_index]
		if e.is_empty() or not XShopStock.managed(int(e.kind), int(e.gid)):
			return []
		return [int(e.kind), int(e.gid), XShopStock.remaining(s, stock_group, int(e.kind), int(e.gid))]
	if from == "sell":
		var d := _sell_data()
		if _sell_index >= d.size():
			return []
		var e: Dictionary = d[_sell_index]
		var kind := int(e.kind)
		var id := int(e.rec.get("base", e.rec.get("id", 0)))
		if not XShopStock.managed(kind, id):
			return []
		return [kind, id, XShopStock.remaining(s, stock_group, kind, id) if kind == 0 else XShopStock.stock_max(kind, id)]
	return []


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
				var a := 1.0 if _buy_enabled(d[i]) else XUI.DIM.a
				if i == _buy_index:
					c.cursor(Rect2(0, y, c.size.x, LH))
				# KMS Window_ShopBuy.drawItem：售完的画名字（宽减 96）与右侧「售完」，不画价格
				if not XShopStock.available(s, stock_group, int(d[i].kind), int(d[i].gid)):
					_item_name(c, d[i].rec, 0, y, w - SOLD_OUT_W, a)
					c.text(SOLD_OUT, w - SOLD_OUT_W, y, SOLD_OUT_W, "right", XUI.TEXT, XUI.FONT_SIZE, LH, a)
					continue
				_item_name(c, d[i].rec, 0, y, w, a)
				_paint_buy_price(c, d[i], y, w, a)
		"sell":
			# Window_ShopSell 继承 Window_ItemList：同物品页一行（XItemRow：NEW、物品「×数量」、装备「序号/9,999」），
			# 但 NEW 只画不记看过（正式版选中、移动、取消都不调 Galv 的 updateHelp）
			var d := _sell_data()
			for i in range(d.size()):
				var y := (i - _sell_top) * LH
				if y < 0 or y >= c.size.y:
					continue
				var a := 1.0 if XItemMarks.can_sell(d[i].rec) else XUI.DIM.a
				if i == _sell_index:
					c.cursor(Rect2(0, y, c.size.x, LH))
				XItemRow.paint(c, d[i].rec, y, XItemRow.right_text(d[i]), a, XItemRow.shows_new(s, d[i].rec))
		"number":
			_paint_number(c)


## YEP_X_MoreCurrencies Window_ShopBuy.drawBuyPrice：数据库价格 > 0 时画金币价（指定价格优先），
## 再从金币价左边（隔 Currency Padding 5）起从右往左画变量、物品买入价（插件 unshift 的顺序，即备注行倒序）。
func _paint_buy_price(c: XMVCanvas, e: Dictionary, y: float, w: float, a: float) -> void:
	var ww := w
	var base_price := int(e.rec.get("price", 0))
	if base_price > 0:
		_currency(c, XMenu._group(int(e.price)), 0, y, w, a)
		ww -= _gold_width(c, base_price) + MC_PADDING
	var r := XItemMarks.sell_rewards(e.item)
	for v in _reversed(r.buy_vars.keys()):
		var u := _var_unit(int(v))
		ww = _alt_currency(c, XMenu._group(int(r.buy_vars[v])), u[0], u[1], y, ww, a) - MC_PADDING
	for id in _reversed(r.buy_items.keys()):
		ww = _alt_currency(c, XMenu._group(int(r.buy_items[id])), "", int(XDB.rec("Items", int(id)).get("iconIndex", 0)), y, ww, a) - MC_PADDING


static func _reversed(a: Array) -> Array:
	var out := a.duplicate()
	out.reverse()
	return out


## drawAltCurrency 的变量单位：变量名去掉 \I[n] 与 <<…>> 后的文字、\I[n] 的图标
static func _var_unit(v: int) -> Array:
	var names: Array = XDB.system().get("variables", [])
	var raw := str(names[v]) if v < names.size() and names[v] != null else ""
	var m := RegEx.create_from_string("(?i)\\\\I\\[(\\d+)\\]").search(raw)
	var unit := RegEx.create_from_string("<<(.*?)>>").sub(RegEx.create_from_string("(?i)\\\\I\\[(\\d+)\\]").sub(raw, "", true), "", true)
	return [unit, int(m.get_string(1)) if m else 0]


## YEP Window_ShopNumber：名字在第 1 行，「× 数量」在第 2 行（数量带光标），第 3 行起是现有金钱、增减、横线与结算。
## YEP_X_MoreCurrencies 在金币列左边接着画变量、物品列（现有、增减、结算三行），见 _paint_currency_columns；
## 有变量/物品买入价且数据库价格为 0 时不画金币三行（isDrawGoldCurrency，买、卖都按买入价判断）。
func _paint_number(c: XMVCanvas) -> void:
	var e := _number_entry()
	if e.is_empty():
		return
	var price := int(e.price) if _number_from == "buy" else XItemMarks.selling_price(e.rec)
	_item_name(c, e.rec, 0, LH, c.size.x)
	# YEP cursorWidth：maxItems(物品) 的字宽＋12；本 MOD 装备是独立物品，maxItems 为 1（运行时读数：装备 27.5、物品 81.9）
	var cw := c.text_width(XMenu._group(1 if int(e.kind) != 0 else MAX_ITEMS)) + 12
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
	_line(c, y + LH * 3)
	var item: Dictionary = e.get("item", e.rec)
	var gold_on := XItemMarks.draws_gold(item)
	if gold_on:
		_currency(c, XMenu._group(gold), 0, y + LH, ww)
		_currency(c, ("+" + XMenu._group(cost)) if _number_from == "sell" else XMenu._group(-cost), 0, y + LH * 2, ww)
		_currency(c, XMenu._group(gold + (cost if _number_from == "sell" else -cost)), 0, y + LH * 3, ww)
		ww -= _gold_width(c, maxi(gold, cost + gold) * 100)
	_paint_currency_columns(c, item, ww, y)


## YEP_X_MoreCurrencies drawTotalPrice：从金币列左边起，变量、物品各一列，每列从右往左排、列间隔 Currency Padding 5。
## 卖出画卖出报酬、买入画买入价；插件 unshift 收集，所以按备注行倒序画；没有武器/防具（独立装备，插件跳过）。
func _paint_currency_columns(c: XMVCanvas, item: Dictionary, ww: float, wy: float) -> void:
	var s := XState.current
	var r := XItemMarks.sell_rewards(item)
	var sell := _number_from == "sell"
	var vars: Dictionary = r.vars if sell else r.buy_vars
	var items: Dictionary = r.items if sell else r.buy_items
	for v in _reversed(vars.keys()):
		var u := _var_unit(int(v))
		ww = _currency_column(c, ww, wy, u[0], u[1], s.variable(int(v)), int(vars[v])) - MC_PADDING
	for id in _reversed(items.keys()):
		ww = _currency_column(c, ww, wy, "", int(XDB.rec("Items", int(id)).get("iconIndex", 0)), s.item_count(int(id)), int(items[id])) - MC_PADDING


## drawVariablePrice／drawItemCostPrice：现有（分组）、增减（卖出「+」数量×单价不分组，买入 −数量×单价分组）、结算（分组）三行，
## 返回三行中最靠左的左缘
func _currency_column(c: XMVCanvas, ww: float, wy: float, unit: String, icon: int, have: float, price: int) -> float:
	var add := price * _number * (1 if _number_from == "sell" else -1)
	var fw := _alt_currency(c, XMenu._group(have), unit, icon, wy + LH, ww)
	fw = minf(fw, _alt_currency(c, ("+" + str(add)) if add >= 0 and _number_from == "sell" else XMenu._group(add), unit, icon, wy + LH * 2, ww))
	return minf(fw, _alt_currency(c, XMenu._group(have + add), unit, icon, wy + LH * 3, ww))


## Window_Base.drawAltCurrency：字号 20；变量名（去掉 \I[n] 与 <<…>>）系统色右对齐，再往左 6 像素放图标，再往左是数值；返回剩余宽度
func _alt_currency(c: XMVCanvas, value: String, unit: String, icon: int, wy: float, ww: float, alpha := 1.0) -> float:
	if unit != "":
		c.text(unit, 0, wy, ww, "right", XUI.SYSTEM, GOLD_FONT, LH, alpha)
		ww -= c.text_width(unit, GOLD_FONT)
	if icon > 0:
		if unit != "":
			ww -= 6
		ww -= 32
		c.icon(icon, ww, wy + 2, alpha)
	c.text(value, 0, wy, ww, "right", XUI.TEXT, GOLD_FONT, LH, alpha)
	return ww - c.text_width(value, GOLD_FONT)


## getCoreGoldWidth：金钱图标 32＋数值宽＋4＋2（字号 Gold Font Size 20）
static func _gold_width(c: XMVCanvas, value: int) -> float:
	return 32 + c.text_width(XMenu._group(value), GOLD_FONT) + 4 + 2


static func _line(c: XMVCanvas, y: float) -> void:
	c.draw_rect(Rect2(0, y, c.size.x, 2), Color(1, 1, 1, 128.0 / 255.0))


func _paint_status(c: XMVCanvas) -> void:
	var rec := _current_rec()
	if rec.is_empty():
		return
	var s := XState.current
	var owned := 0
	if rec.has("itypeId"):
		# 代购商品显示代购件的持有数（MoreCurrencies Window_ShopStatus.setItem）
		var pid := XItemMarks.proxy_buy(rec)
		owned = s.item_count(pid if pid > 0 else int(rec.id))
	else:
		var kind: String = rec.get("kind", "weapon" if rec.has("wtypeId") else "armor")
		owned = s.gear_count(kind, int(rec.get("base", rec.id)))
	var w := c.size.x - 12
	c.text("持有数", 6, 0, w, "left", XUI.SYSTEM)
	c.text(XMenu._group(owned), 6, 0, w, "right")
	var gear := rec.has("etypeId") and not rec.has("itypeId")
	var row := _stock_row()
	if not row.is_empty():
		# KMS Window_ShopStatus.refresh 在原内容之后画第 2 行；装备时字号沿用能力表的 20（O-043 改到能力表下方、26 号）
		var below := gear and STOCK_GEAR_BELOW
		_paint_stock(c, 6, LH * 10 if below else LH, w, 20 if gear and not below else XUI.FONT_SIZE, int(row[2]), XShopStock.stock_max(row[0], row[1]))
	if not gear:
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


## Window_Base.drawShopStockNumber：系统色「库存」左对齐（宽为字宽＋8），右端三格「剩余」「/」「上限」右对齐（数字格宽＝「000」字宽）
func _paint_stock(c: XMVCanvas, x: float, y: float, w: float, size: int, stock: int, mx: int) -> void:
	var vw := c.text_width("000", size)
	var sw := c.text_width("/", size)
	c.text(STOCK_CAPTION, x, y, c.text_width(STOCK_CAPTION, size) + 8, "left", XUI.SYSTEM, size)
	var nx := x + w - (vw * 2 + sw)
	c.text(str(stock), nx, y, vw, "right", XUI.TEXT, size)
	c.text("/", nx + vw, y, sw, "right", XUI.TEXT, size)
	c.text(str(mx), nx + vw + sw, y, vw, "right", XUI.TEXT, size)


## YEP_X_MoreCurrencies Window_Gold.refresh：购买／出售列表选中的商品（setItemBuy／setItemSell，购买取消时清空）有变量/物品价时，
## 金币左边（隔 Currency Padding 5）从右往左画这些变量的值与物品持有数（变量、物品顺序同价格列）；
## 有这类价格且数据库价格为 0 时不画金币（isDrawGoldCurrency：购买看买入价，出售看卖出报酬）。
func _paint_gold(c: XMVCanvas) -> void:
	var s := XState.current
	var ww := c.size.x - 12
	var item := _gold_item
	var r := XItemMarks.sell_rewards(item) if not item.is_empty() else {}
	var vars: Dictionary = r.get("buy_vars" if _gold_buy else "vars", {})
	var items: Dictionary = r.get("buy_items" if _gold_buy else "items", {})
	if vars.is_empty() and items.is_empty() or int(item.get("price", 0)) > 0:
		_currency(c, XMenu._group(s.gold), 6, 0, ww)
		ww -= _gold_width(c, s.gold) + MC_PADDING
	for v in _reversed(vars.keys()):
		var u := _var_unit(int(v))
		ww = _alt_currency_at(c, 6, XMenu._group(s.variable(int(v))), u[0], u[1], ww) - MC_PADDING
	for id in _reversed(items.keys()):
		ww = _alt_currency_at(c, 6, XMenu._group(s.item_count(int(id))), "", int(XDB.rec("Items", int(id)).get("iconIndex", 0)), ww) - MC_PADDING


## 金钱窗的 drawAltCurrency：从 x 起宽 ww 的右对齐（同 _alt_currency，左边留 textPadding）
func _alt_currency_at(c: XMVCanvas, x: float, value: String, unit: String, icon: int, ww: float) -> float:
	if unit != "":
		c.text(unit, x, 0, ww, "right", XUI.SYSTEM, GOLD_FONT, LH)
		ww -= c.text_width(unit, GOLD_FONT)
	if icon > 0:
		if unit != "":
			ww -= 6
		ww -= 32
		c.icon(icon, x + ww, 2)
	c.text(value, x, 0, ww, "right", XUI.TEXT, GOLD_FONT, LH)
	return ww - c.text_width(value, GOLD_FONT)


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
	return _max_buy(e)


## Scene_Shop.maxBuy（KMS 再与库存取小）
func _max_buy(e: Dictionary) -> int:
	return XShopStock.max_buy(XState.current, stock_group, int(e.kind), int(e.gid), XItemMarks.max_buy(XState.current, e.item, int(e.price)))


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
			if _buy_index < d.size() and _buy_enabled(d[_buy_index]) and _max_number() > 0:
				_number_from = "buy"
				_number = 1
				_mode = "number"
		"sell":
			var d := _sell_data()
			if _sell_index < d.size() and XItemMarks.can_sell(d[_sell_index].rec):
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
		if _number < 1 or _number > _max_buy(e):
			return
		# Scene_Shop.doBuy：先付款得物（XItemMarks.buy），再扣库存、登记补货（KMS）
		XItemMarks.buy(s, e.item, int(e.price), _number)
		XShopStock.record_purchase(s, stock_group, int(e.kind), int(e.gid), _number)
		_mode = "buy"
	else:
		# 装备的 e.rec 就是背包实例；物品的 e.rec 可能是加了标记名的副本，按 ID 卖
		XItemMarks.sell(s, e.rec if int(e.kind) != 0 else XDB.rec("Items", int(e.rec.id)), _number)
		XShopStock.record_sale(s, stock_group, int(e.kind), int(e.rec.get("id", 0)), _number)
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
