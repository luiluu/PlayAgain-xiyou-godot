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
## - 系统音（ui14，原来整页无声）：照 Window_Selectable／Scene_Shop——换行光标音、确定音、不可选蜂鸣、取消音；
##   数量窗确定不响确定音（Window_ShopNumber.playOkSound 为空）、改为商店音（onNumberOk 的 playShop）；
##   数量窗取消响两次取消音（processCancel 一次、onNumberCancel 又一次）；数量变了才响光标音；
##   装备商品左右换队员响光标音（YEP Window_ShopStatus.updateParamSwitch，只对装备）。

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
## 安全出售（XSafeSell，O-293）：一键出售窗宽 680；选档后先弹确认窗（宽 720、4 行、画面居中，默认停在「取消」）
const ONEKEY_SAFE_W := 680.0
const CONFIRM_W := 720.0
const CATEGORIES := [["物品", "item"], ["消耗品", "consumable"], ["武器", "weapon"], ["护甲", "armor"], ["重要物品", "keyItem"]]
const SOLD_OUT := "售完"            # KMS_ShopInventory 参数 Sold out text
const STOCK_CAPTION := "库存"       # Caption for stock
const SOLD_OUT_W := 96.0
## O-043：装备商品的库存行画在能力表下方（第 11 行、26 号字）；false 为原版（第 2 行、沿用能力表的 20 号字，与队员名重叠）
static var STOCK_GEAR_BELOW := true
## 自动测试用（只在测试里设）：XMessageBox.auto 不管商店，事件走到商店会一直等输入。为真时商店一打开就把
## {goods, purchase_only, stock_group} 记进 auto_log 并关闭（closed 延到下一帧发，等 open_shop 接上 await）
static var auto_close := false
static var auto_log: Array = []

var goods: Array = []
var purchase_only := false
var stock_group := ""           # KMS_ShopInventory 库存组（XShopStock.open 取得；"" 为不限购）
var _mode := "command"          # command / buy / category / sell / number / onekey
var _onekey := 0
var _confirm := 3
var _plan := {}
var _plan_grade := -1
var _cmd := 0
var _cat := 0
var _cat_top := 0
var _buy_index := 0
var _buy_top := 0               # Window_ShopBuy 的 topRow（ui9：商品多于一页时滚动）
var _sell_index := 0
var _sell_top := 0
var _number := 1
var _number_from := "buy"
var _actor_index := 0
## YEP_ShopMenuCore Window_ShopStatus 的「默认」显示模式（Tab 切换，开店默认 actor）：逐项属性 + 每个队员一行；
## ←→ 换属性（paramId，初始 2），Shift 翻队员页（每页 4 人）。回退开关 STAT_DEFAULT_MODE = false。
static var STAT_DEFAULT_MODE := true
var _stat_default := false
var _param_id := 2
var _page_index := 0
const PAGE_SIZE := 4
const STAT_FONT := 20
var cmd_win: XMVWindow
var info_win: XMVWindow
var list_win: XMVWindow
var status_win: XMVWindow
var gold_win: XMVWindow
var onekey_win: XMVWindow
var confirm_win: XMVWindow
var help_card: XHelpCard
## 说明卡上次排版的商品（同一件不重排；回退开关 HELP_SAME_SKIP = false 每次重排）
var _help_rec := {}
static var HELP_SAME_SKIP := true
## O-待定·商店列表缓存（玩家反馈 v0.01「所有 NPC 买东西都有轻微卡顿」）：一次按键里买入表、出售表各要重算十来次
## （_refresh、说明卡、状态窗、库存行、列表各算一遍；出售表每次把整个背包按分类筛一遍、套标记），背包大时一按一卡。
## 开着时 _refresh 之后到下一次操作之前（即本次重画）同一份表只算一次；确定、取消、成交一开始就作废，照旧现算。
## 原版每个窗口各自 makeItemList 一次（Window_ShopBuy／ShopSell.refresh），不是每画一处算一次。回退：DATA_CACHE = false。
static var DATA_CACHE := true
var _cache_on := false
var _cache := {}
## 测试用：买入表、出售表实际现算的次数
var data_builds := 0
var _gold_item := {}            # 金钱窗跟随的商品（Window_Gold._item）
var _gold_buy := true


func setup(g: Array, only: bool, group := "") -> void:
	# installBabyAllActorsRuntime（Scene_Shop.prepare 最外层）：宝宝路线的号角店改列全部可用角色、免费
	var baby := XBabyAllActors.prepare(XState.current, g)
	goods = baby[0]
	_baby_free = baby[1]
	if _baby_free:
		XBabyAllActors.free_open = true
	purchase_only = only
	stock_group = group


var _baby_free := false


## Scene_Shop.terminate 包装：免费期间清空的号角货币价还原
func _exit_tree() -> void:
	if _baby_free:
		XBabyAllActors.free_open = false


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
	var n := XItemMarks.onekey_commands(XState.current).size()
	onekey_win = XMVWindow.make(self, Rect2(ONEKEY_POS, Vector2(ONEKEY_SAFE_W if XSafeSell.ENABLED else ONEKEY_W, n * LH + XMVWindow.PADDING * 2)), op, _paint_onekey)
	onekey_win.visible = false
	var ch := 4 * LH + XMVWindow.PADDING * 2
	confirm_win = XMVWindow.make(self, Rect2((1280 - CONFIRM_W) / 2.0, (720 - ch) / 2.0, CONFIRM_W, ch), op, _paint_confirm)
	confirm_win.visible = false
	for w in [cmd_win, list_win, onekey_win, confirm_win]:
		w.canvas.blink = true
	help_card = XHelpCard.new()
	# 卡片不盖状态窗首行（「持有数」）：状态窗 y＋MV 标准内边距 18＋一行＝原版说明窗 y 227，再让出品质框外扩 10，本体 237（O-251，XHelpCard.NEAR_BELOW_HEADER）
	help_card.near_min_y = STATUS_RECT.position.y + 18.0 + LH + 10.0
	add_child(help_card)
	_refresh()
	if auto_close:
		auto_log.append({"goods": goods.duplicate(true), "purchase_only": purchase_only, "stock_group": stock_group})
		closed.emit.call_deferred()


func _refresh() -> void:
	_cache.clear()
	_cache_on = DATA_CACHE
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
	var nb := _buy_data().size() if _mode == "buy" else 0
	list_win.down_arrow = (_mode == "sell" and _sell_top < n - _list_rows()) or (_mode == "buy" and _buy_top < nb - _list_rows())
	list_win.up_arrow = (_mode == "sell" and _sell_top > 0) or (_mode == "buy" and _buy_top > 0)
	onekey_win.visible = _mode == "onekey"
	confirm_win.visible = _mode == "confirm"
	for w in [cmd_win, info_win, list_win, status_win, gold_win, onekey_win, confirm_win]:
		w.refresh()
	_update_help()


## Window_ShopBuy / Window_ShopSell.updateHelp：说明卡跟着选中行（横向取整个列表窗口）
func _update_help() -> void:
	if help_card == null:
		return
	var row := -1
	match _mode:
		"buy":
			row = _buy_index - _buy_top
		"sell":
			row = _sell_index - _sell_top
	var rec := _current_rec() if row >= 0 else {}
	# 安卓商店卡（Kyo 11-12，O-321）：说明卡排版（逐行量字宽折行）每次按键都重做；同一件商品不重排，只挪位置
	if not (HELP_SAME_SKIP and help_card.visible == not rec.is_empty() and rec == _help_rec):
		help_card.show_for(rec)
		_help_rec = rec
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
	if _cache_on and _cache.has("buy"):
		return _cache.buy
	var out := _make_buy_data()
	if _cache_on:
		_cache.buy = out
	return out


func _make_buy_data() -> Array:
	data_builds += 1
	var out := []
	for g in XItemMarks.shop_goods(goods, XState.current.map_id if XState.current != null else 0):
		var item := XItemMarks.shop_rec(int(g[0]), int(g[1]))
		if not item.is_empty():
			out.append({"rec": XItemMarks.shop_display(item), "item": item, "kind": int(g[0]), "gid": int(g[1]), "price": _price(g)})
	return out


## 出售列表：按分类列出持有物（装备是背包实例）；价格为一半（MV Scene_Shop.sellingPrice）。
func _sell_data() -> Array:
	var key := "sell:%d" % _cat
	if _cache_on and _cache.has(key):
		return _cache[key]
	var out := _make_sell_data()
	if _cache_on:
		_cache[key] = out
	return out


## 列表缓存作废（会改背包、金钱、库存、商品表的操作开头调）；下一次 _refresh 再开
func _drop_cache() -> void:
	_cache_on = false
	_cache.clear()


func _make_sell_data() -> Array:
	data_builds += 1
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
		if e.is_empty() or not XShopStock.shop_managed(int(e.kind), int(e.gid)):
			return []
		return [int(e.kind), int(e.gid), XShopStock.remaining(s, stock_group, int(e.kind), int(e.gid))]
	if from == "sell":
		var d := _sell_data()
		if _sell_index >= d.size():
			return []
		var e: Dictionary = d[_sell_index]
		var kind := int(e.kind)
		var id := int(e.rec.get("base", e.rec.get("id", 0)))
		if not XShopStock.shop_managed(kind, id):
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
	var rows := XItemMarks.onekey_commands(XState.current)
	for i in range(rows.size()):
		if i == _onekey:
			c.cursor(Rect2(0, i * LH, c.size.x, LH))
		c.text(rows[i].text, 6, i * LH, c.size.x - 12, "left")


## Window_SafeSellConfirm40 的四行：[文字, 能否选]
func confirm_rows() -> Array:
	var p: Dictionary = _plan if not _plan.is_empty() else {"sell": [], "keep": []}
	return [["待出售装备 %d 件；保留装备 %d 件" % [p.sell.size(), p.keep.size()], false], ["保留词条：" + XSafeSell.label(XState.current), false],
		["确认出售", p.sell.size() > 0], ["取消", true]]


func _paint_confirm(c: XMVCanvas) -> void:
	var rows := confirm_rows()
	for i in range(rows.size()):
		if i == _confirm:
			c.cursor(Rect2(0, i * LH, c.size.x, LH))
		var col := XUI.TEXT
		if not rows[i][1]:
			col.a = 160.0 / 255.0   # changePaintOpacity(false)
		c.text(rows[i][0], 6, i * LH, c.size.x - 12, "left", col)


func _paint_info(c: XMVCanvas) -> void:
	XItemStatusPainter.paint(c, _current_rec())


## MV drawItemName：图标 (x+2, y+2)，名字从 x+36 起，品质颜色（ItemQuality）。
func _item_name(c: XMVCanvas, rec: Dictionary, x: float, y: float, w: float, alpha := 1.0) -> void:
	c.icon(int(rec.get("iconIndex", 0)), x + 2, y + 2, alpha)
	c.text(XQuality.list_name(rec), x + 36, y, w - 36, "left", XGear.color(rec), XUI.FONT_SIZE, LH, alpha)


## YEP drawCurrencyValue：字号 20，数值右对齐，金钱图标在最右
func _currency(c: XMVCanvas, value: String, x: float, y: float, w: float, alpha := 1.0) -> void:
	c.text(XMenu.currency_text(c, value, w - 32), x, y, w - 32 - 4, "right", XUI.TEXT, GOLD_FONT, LH, alpha)
	c.icon(XMenu.GOLD_ICON, x + w - 32, y + 2, alpha)


func _paint_list(c: XMVCanvas) -> void:
	var s := XState.current
	match _mode:
		"buy":
			var d := _buy_data()
			for i in range(d.size()):
				var y := (i - _buy_top) * LH
				if y < 0 or y >= c.size.y:
					continue
				var w := c.size.x - 6
				var a := 1.0 if _buy_enabled(d[i]) else XUI.DIM.a
				if i == _buy_index:
					c.cursor(Rect2(0, y, c.size.x, LH))
				# KMS Window_ShopBuy.drawItem：售完的画名字（宽减 96）与右侧「售完」，不画价格
				if not XShopStock.available(s, stock_group, int(d[i].kind), int(d[i].gid)):
					_item_name(c, d[i].rec, 0, y, w - SOLD_OUT_W, a)
					if XItemRow.paint_magic_level(c, d[i].rec, 0, y):
						a = 1.0
					c.text(SOLD_OUT, w - SOLD_OUT_W, y, SOLD_OUT_W, "right", XUI.TEXT, XUI.FONT_SIZE, LH, a)
					continue
				_item_name(c, d[i].rec, 0, y, w, a)
				if XItemRow.paint_magic_level(c, d[i].rec, 0, y):
					a = 1.0
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
	var members := s.members()
	var item := rec if rec.has("kind") else XGear.template("weapon" if rec.has("wtypeId") else "armor", int(rec.id))
	if _stat_default and STAT_DEFAULT_MODE:
		_paint_status_default(c, members, item)
		return
	# 「<< 队员 >>」与 8 项能力增减（actor 模式；左右键切换队员）
	_actor_index = clampi(_actor_index, 0, members.size() - 1)
	var a: XActor = members[_actor_index]
	c.text(a.display_name(), 0, LH, c.size.x, "center")
	c.text("<<", 0, LH, c.size.x, "left", XUI.SYSTEM)
	c.text(">>", 0, LH, c.size.x, "right", XUI.SYSTEM)
	var half := floorf(c.size.x / 2.0)
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
## 默认模式（drawDefaultData）：第 2 行属性名居中并带 <<、>>；第 3 行起每个队员一行（Window_ShopStatus.drawEquipInfo，YEP 版）：
## 名字在 x+220（x＝textPadding 6）、装得了写属性增减（20 号、右对齐、涨绿降红）、装不了写「Can't Equip」（20 号、半透明）。
func _paint_status_default(c: XMVCanvas, members: Array, item: Dictionary) -> void:
	c.text(XItemStatusPainter.param_name(_param_id), 0, LH, c.size.x, "center")
	c.text("<<", 0, LH, c.size.x, "left", XUI.SYSTEM)
	c.text(">>", 0, LH, c.size.x, "right", XUI.SYSTEM)
	var pages := maxi(1, ceili(float(members.size()) / PAGE_SIZE))
	_page_index = clampi(_page_index, 0, pages - 1)
	var start := _page_index * PAGE_SIZE
	var pad := 6.0
	for i in range(mini(PAGE_SIZE, members.size() - start)):
		var a: XActor = members[start + i]
		var y := LH * 2 + i * LH
		var can := a.can_equip(item)
		var alpha := 1.0 if can else XUI.DIM.a
		c.text(a.display_name(), pad + 220, y, c.size.x - pad, "left", XUI.TEXT, XUI.FONT_SIZE, LH, alpha)
		if can:
			var change := int(item.params[_param_id]) - _worst_equipped_param(a, int(item.etypeId), _param_id)
			c.text(("+" if change > 0 else "") + XMenu._group(change), pad, y, c.size.x - pad * 2, "right",
				XItemStatusPainter.change_color(change), STAT_FONT, LH)
		else:
			c.text("Can't Equip", pad, y, c.size.x - pad, "right", XUI.TEXT, STAT_FONT, LH, alpha)


## currentEquippedItem：同类型装备栏里该属性最低的那件（没有为 0）
static func _worst_equipped_param(a: XActor, etype: int, param_id: int) -> int:
	var worst := 0
	var found := false
	var slots: Array = a.equip_slots()
	for i in range(slots.size()):
		if int(slots[i]) != etype or i >= a.equips.size() or a.equips[i] == null:
			continue
		var v := int(a.equips[i].params[param_id])
		if not found or v < worst:
			worst = v
			found = true
	return worst


## Window_ShopStatus.updateParamSwitch：装备商品时 Tab／点窗口上沿中间换模式、默认模式下左右换属性（响光标音）
func _toggle_stat_mode() -> void:
	if not STAT_DEFAULT_MODE:
		return
	var rec := _current_rec()
	if rec.is_empty() or rec.has("itypeId"):
		return
	_stat_default = not _stat_default
	XSound.system(0)


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
			_switch_actor(1)
	elif event.is_action_pressed("ui_left", true):
		if _mode == "number":
			_change_number(-1)
		else:
			_switch_actor(-1)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_toggle_stat_mode()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SHIFT:
		_change_stat_page()
	elif XMenu.page_dir(event) != 0 and _mode in ["buy", "sell", "category"]:
		_page(XMenu.page_dir(event))
	else:
		handled = false
	if handled:
		XKeyMap.handled(self)
		_refresh()


## YEP Window_ShopStatus.updateParamSwitch：装备商品时左右换队员并响光标音（物品不响）
func _switch_actor(d: int) -> void:
	var rec := _current_rec()
	var gear := not rec.is_empty() and not rec.has("itypeId")
	if _stat_default and STAT_DEFAULT_MODE:
		_param_id = (_param_id + d + 8) % 8
		if gear:
			XSound.system(0)
		return
	var n := XState.current.members().size()
	_actor_index = (_actor_index + d + n) % n
	if gear:
		XSound.system(0)


## Window_ShopStatus.updatePage：队员多于 4 人时 Shift 翻页（两种模式都翻，默认模式才看得到），响光标音
func _change_stat_page() -> void:
	var n := XState.current.members().size()
	var pages := ceili(float(n) / PAGE_SIZE)
	if pages < 2:
		return
	_page_index = (_page_index + 1) % pages
	XSound.system(0)


## 同一窗口里光标换了行才响光标音（Window_Selectable.processCursorMove／onTouch）
var _clicked_ok := false


func _cursor_state() -> Array:
	return [_mode, _cmd, _cat, _buy_index, _sell_index, _onekey, _confirm]


func _cursor_se(before: Array) -> void:
	if before[0] == _mode and before != _cursor_state():
		XSound.system(0)


func _move(d: int, wrap: bool) -> void:
	var before := _cursor_state()
	_move_inner(d, wrap)
	_cursor_se(before)


func _move_inner(d: int, wrap: bool) -> void:
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
				_buy_top = XMenu._scroll_to(_buy_index, _buy_top, _list_rows())
		"sell":
			var n := _sell_data().size()
			if n > 0:
				_sell_index = XMenu._move(_sell_index, d, n, wrap)
				_sell_top = XMenu._scroll_to(_sell_index, _sell_top, _list_rows())
		"number":
			_change_number(d)
		"onekey":
			_onekey = XMenu._move(_onekey, d, XItemMarks.onekey_commands(XState.current).size(), wrap)
		"confirm":
			_confirm = XMenu._move(_confirm, d, 4, wrap)


## 通用翻页（Window_Selectable.cursorPagedown／cursorPageup）：买入、出售、分类三个列表
func _page(d: int) -> void:
	var before := _cursor_state()
	_page_inner(d)
	_cursor_se(before)


func _page_inner(d: int) -> void:
	match _mode:
		"buy":
			var r := XMenu.page(_buy_top, _buy_index, _buy_data().size(), _list_rows(), d)
			_buy_top = r[0]
			_buy_index = r[1]
		"sell":
			var r := XMenu.page(_sell_top, _sell_index, _sell_data().size(), _list_rows(), d)
			_sell_top = r[0]
			_sell_index = r[1]
		"category":
			var r := XMenu.page(_cat_top, _cat, CATEGORIES.size(), 4, d)
			_cat_top = r[0]
			_cat = r[1]


## 滚轮（Window_Selectable.processWheel）：只滚当前活动列表，光标不动
func _wheel(d: int) -> void:
	match _mode:
		"buy":
			_buy_top = XMenu.wheel(_buy_top, _buy_data().size(), _list_rows(), d)
		"sell":
			_sell_top = XMenu.wheel(_sell_top, _sell_data().size(), _list_rows(), d)
		"category":
			_cat_top = XMenu.wheel(_cat_top, CATEGORIES.size(), 4, d)


## MV Window_ShopNumber：上下 ±10、左右 ±1，范围 1～最大可买/可卖数
func _change_number(d: int) -> void:
	var before := _number
	_number = clampi(_number + d, 1, maxi(1, _max_number()))
	if _number != before:
		XSound.system(0)


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
	_drop_cache()
	_ok_inner()
	_refresh()


func _ok_inner() -> void:
	var s := XState.current
	match _mode:
		"command":
			if not _cmd_enabled(_cmd):
				XSound.system(3)
				return
			XSound.system(1)
			match COMMANDS[_cmd][1]:
				"buy":
					_mode = "buy"
					_buy_index = clampi(_buy_index, 0, maxi(0, _buy_data().size() - 1))
					_buy_top = XMenu._scroll_to(_buy_index, _buy_top, _list_rows())
				"sell":
					_mode = "category"
				"onekey":
					_mode = "onekey"
				"cancel":
					closed.emit()
		"category":
			XSound.system(1)
			_mode = "sell"
			_sell_index = 0
			_sell_top = 0
		"buy":
			var d := _buy_data()
			if not (_buy_index < d.size() and _buy_enabled(d[_buy_index]) and _max_number() > 0):
				XSound.system(3)
			else:
				XSound.system(1)
				_number_from = "buy"
				_number = 1
				_mode = "number"
		"sell":
			var d := _sell_data()
			if not (_sell_index < d.size() and XItemMarks.can_sell(d[_sell_index].rec)):
				XSound.system(3)
			else:
				XSound.system(1)
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
			XSound.system(1)
			var rows := XItemMarks.onekey_commands(s)
			var g := int(rows[_onekey].grade)
			if g < 0:
				XSafeSell.cycle(s, 1)   # 「保留词条」行：门槛往后一档，留在一键出售窗
			elif XSafeSell.ENABLED:
				_plan_grade = g
				_plan = XSafeSell.plan(s, g)
				_confirm = 3
				_mode = "confirm"
			else:
				XItemMarks.onekey_sell(s, g)
				_mode = "command"
		"confirm":
			if not confirm_rows()[_confirm][1]:
				XSound.system(3)
				return
			XSound.system(1)
			if _confirm == 3:
				_mode = "onekey"
				return
			# 确认前重算：和弹窗时的计划不同（期间背包变了）就刷新计划、停在「取消」，不卖
			var now := XSafeSell.plan(s, _plan_grade)
			if now.sell.size() != _plan.sell.size() or range(now.sell.size()).any(func(i): return not is_same(now.sell[i], _plan.sell[i])):
				_plan = now
				_confirm = 3
				return
			XSafeSell.sell_plan(s, now)
			_plan = {}
			_mode = "command"


func _trade() -> void:
	_drop_cache()
	var s := XState.current
	var e := _number_entry()
	if _number_from == "buy":
		if _number < 1 or _number > _max_buy(e):
			return
	XSound.system(21)   # Scene_Shop.onNumberOk：SoundManager.playShop（数量窗本身不响确定音）
	if _number_from == "buy":
		# Scene_Shop.doBuy：先付款得物（XItemMarks.buy），再扣库存、登记补货（KMS）
		XItemMarks.buy(s, e.item, int(e.price), _number)
		XShopStock.record_purchase(s, stock_group, int(e.kind), int(e.gid), _number)
		if _baby_free and XBabyAllActors.is_horn(e.item):
			goods = XBabyAllActors.bought(s, e.item, goods)  # 领过的记下、从列表拿掉
			_buy_index = clampi(_buy_index, 0, maxi(0, _buy_data().size() - 1))
		_mode = "buy"
	else:
		# 装备的 e.rec 就是背包实例；物品的 e.rec 可能是加了标记名的副本，按 ID 卖
		XItemMarks.sell(s, e.rec if int(e.kind) != 0 else XDB.rec("Items", int(e.rec.id)), _number)
		XShopStock.record_sale(s, stock_group, int(e.kind), int(e.rec.get("id", 0)), _number)
		_mode = "sell"
		var n := _sell_data().size()
		_sell_index = clampi(_sell_index, 0, maxi(0, n - 1))


func _cancel() -> void:
	_drop_cache()
	_cancel_inner()
	_refresh()


func _cancel_inner() -> void:
	XSound.system(2)
	if _mode == "number":
		XSound.system(2)   # onNumberCancel 再响一次
	match _mode:
		"command":
			closed.emit()
		"buy", "category", "onekey":
			_mode = "command"
		"confirm":
			_mode = "onekey"
		"sell":
			_mode = "category"
		"number":
			_mode = _number_from


## 鼠标：点列表行（与指令行）先选中，再点确定；右键取消。
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var wd := XMenu.wheel_dir(event)
	if wd != 0:
		_wheel(wd)
		accept_event()
		_refresh()
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel()
		_refresh()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var before := _cursor_state()
	_clicked_ok = false
	var p: Vector2 = event.position
	var pad := Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
	if _mode == "onekey":
		var r := Rect2(onekey_win.position, onekey_win.size)
		var i := floori((p - r.position - pad).y / LH)
		if r.has_point(p) and i >= 0 and i < XItemMarks.onekey_commands(XState.current).size():
			if i == _onekey:
				_click_ok()
			else:
				_onekey = i
	elif _mode == "confirm":
		var r := Rect2(confirm_win.position, confirm_win.size)
		var i := floori((p - r.position - pad).y / LH)
		if r.has_point(p) and i >= 0 and i < 4:
			if i == _confirm:
				_click_ok()
			else:
				_confirm = i
	elif CMD_RECT.has_point(p) and _mode in ["command", "category"]:
		var i := floori((p - CMD_RECT.position - pad).y / LH)
		if _mode == "command" and i >= 0 and i < COMMANDS.size():
			if i == _cmd:
				_click_ok()
			else:
				_cmd = i
		elif _mode == "category" and i + _cat_top >= 0 and i + _cat_top < CATEGORIES.size():
			if i + _cat_top == _cat:
				_click_ok()
			else:
				_cat = i + _cat_top
	elif LIST_RECT.has_point(p):
		var i := floori((p - LIST_RECT.position - pad).y / LH)
		if _mode == "buy" and i >= 0 and i < _list_rows() and i + _buy_top < _buy_data().size():
			if i + _buy_top == _buy_index:
				_click_ok()
			else:
				_buy_index = i + _buy_top
		elif _mode == "sell" and i + _sell_top < _sell_data().size() and i >= 0:
			if i + _sell_top == _sell_index:
				_click_ok()
			else:
				_sell_index = i + _sell_top
		elif _mode == "number":
			_click_ok()
	elif STATUS_RECT.has_point(p):
		var x := (p - STATUS_RECT.position - pad).x
		if x < 60:
			_switch_actor(-1)
		elif x > STATUS_RECT.size.x - 88:
			_switch_actor(1)
		elif (p - STATUS_RECT.position).y <= 12 + LH * 2:
			_toggle_stat_mode()  # isTouched(0)：上沿两行内不在 << >> 上的点按＝换模式
	if not _clicked_ok:
		_cursor_se(before)
	_refresh()


## 点已选中的行＝确定（响确定音，不再算光标移动）
func _click_ok() -> void:
	_clicked_ok = true
	_ok()
