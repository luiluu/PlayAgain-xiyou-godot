class_name XSkinShopPage
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】T283 商店新布局（T254 3.1；版型一 XSkinTemplatePage 的手动用法，同物品页 XSkinItemPage 的做法）。
## 只管「怎么摆、怎么画、点了等于按了哪个键」：买卖、库存、多选、一键出售、安全出售这些全部还是 XShop 原来的代码
## （同一套 _mode／_cmd／_cat／_buy_index…），XShop 每次 _refresh 后 sync() 按状态重画。
## 旧页 → 新页（T254 3.1 对应表）：
## - 指令窗「购买／出售／一键出售／取消」→ 左环三个球（_cmd 0～2）；「取消」＝左上「‹」和取消键。
## - 出售的分类窗 → 出售列表上方的页内页签（XSkinInnerTabs，Q／E 换；_cat），不再有「先选分类」这一层（category 态不出现）。
## - 购买列表：图标、名字（品质色）、行尾价格（买不起变橙）、名字后「库存 3 / 5」、售完整行变灰写「售完」。
## - 出售列表：「新」「已锁定」「置顶」小标，名字后持有数／序号小字，行尾卖出价；不能卖的变灰写「不能卖」；
##   多选（XShop.MULTI_SELL）：行首方框（不能标的不画框），列表标题右写「已选 N 件 · 得 M」，主按钮「出售已选 N 件」。
## - 状态窗（持有数、库存、装备的「<< 队员 >>」八项增减）→ 右牌：名字下「持有 N」，装备多一节「换上后 ‹ 队员 ›」
##   只列变了的项、底下「其余 N 项不变」；左右键换人（同旧页）；Tab 换成旧页的「默认」看法（一项属性 × 全队）。
## - 数量窗 → 右牌底常驻数量选择（XSkinStepper）＋「合计」＋主按钮：列表上按确定落到数量条（number 态），
##   ←/→ ±1、↑/↓ ±10、E 最多、Q 回 1、数字键直接敲（都还是 XShop 的键），再按确定成交；取消回列表。触屏在列表态直接点钮、点主按钮。
## - 金钱窗 → 右上货币，跟着选中的商品换计价物（XShop._gold_item 同一套规则）。
## - 一键出售窗 → 列表（每档行尾「N 件 · 能卖多少」，没有的那档变灰写「没有」），右牌读 XSafeSell.plan（XShop._onekey_plan）：
##   会卖掉几件、得多少、自动留住几件和原因；主按钮「卖掉这一档…」→ 统一确认弹窗（XSkinConfirm，橙边、停在「取消」）。确认照旧保留。
## - 安全出售确认窗、多选确认窗 → 统一确认弹窗（钮＝原来能选的行：确认出售／取消；出售已选／清空选择／取消）。
## - 说明卡并进右牌。系统音照旧（全走 XShop 的函数）。
## 新皮肤关着、或 ENABLED＝false 时 XShop 不建这一页，旧页一行不变。

## T283 回退开关：false＝天启篇新皮肤下商店也回旧页
static var ENABLED := true
## 玩家可见文字（待小A 审）
const T_BUY := "购买"
const T_SELL := "出售"
const T_ONEKEY := "一键出售"
const T_EMPTY_BUY := "这家店现在没货"
const T_EMPTY_SELL := "这一类没有东西"
## 环上三个球的占位图标（金币、物品袋、武器；美术出了再换）
const ORB_ICONS := [416, 116, 160]
const FOOT_LINE_H := 30.0

var scene: XShop
var _syncing := false
var _list_key := []
var inner_tabs: XSkinInnerTabs
var stepper: XSkinStepper
## 右牌底：数量条＋合计＋提示（画在牌上面一层，XSkinCard 自己的画会盖掉 draw 信号画的东西）
var foot: Control
var _foot_lines: Array = []   # [[左, 右, 右色]] 或 [[一句, "", 色]]
var _list_right := ""          # 列表标题右边那行小字
var _plans := {}              # 一键出售各档的计划（同一背包只算一次）
var _plan_key := []
var dialog: XSkinConfirm
var _check_press := -1        # 按在行首方框上的行


func _init(s: XShop) -> void:
	scene = s
	name = "SkinShopPage"
	title = "商店"
	group_key = ""            # 从 NPC 进的页不画页签条（T254 3.0）
	columns = 1
	row_height = XUiSkin.ROW_H
	right_w = 352.0
	auto_nav = false
	show_ring = not s.purchase_only
	focus = "ring" if show_ring else "list"
	hint_list = [["确定", "选择"], ["取消", "离开"]]


func _ready() -> void:
	super()
	list.empty_center = true
	list.right2_w = 0.0
	ring.changed.connect(_on_ring_changed)
	ring.activated.connect(_on_ring_clicked)
	list.index_changed.connect(_on_list_index)
	list.activated.connect(_on_list_click)
	list.gui_input.connect(_on_list_gui)
	card_button.connect(_on_card_button)
	inner_tabs = XSkinInnerTabs.new()
	inner_tabs.set_tabs(XShop.CATEGORIES.map(func(c): return c[0]), scene._cat)
	inner_tabs.changed.connect(_on_tab)
	list_panel.add_child(inner_tabs)
	list_panel.draw.connect(_draw_list_right)
	foot = Control.new()
	foot.name = "ShopFoot"
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.draw.connect(_draw_foot)
	card.add_child(foot)
	stepper = XSkinStepper.new()
	stepper.sound = false    # 声音照 XShop 数量窗（变了才响光标音），这边写回时由 XShop 响
	stepper.value_changed.connect(_on_stepper_value)
	stepper.touched.connect(_on_stepper_touched)
	foot.add_child(stepper)
	layout.left.draw.connect(_draw_left_visual)
	gui_input.connect(_on_gui)
	mouse_filter = Control.MOUSE_FILTER_PASS


func relayout() -> void:
	super()
	_place_tabs()
	_place_foot()


func _place_tabs() -> void:
	if inner_tabs == null or list == null:
		return
	var cs := layout.center.size
	var lx := list.position.x
	var shift := XSkinInnerTabs.H + 4.0 if inner_tabs.visible else 0.0
	inner_tabs.position = Vector2(XUiSkin.PAD + 8, LIST_TOP - 6.0)
	inner_tabs.size = Vector2(cs.x - XUiSkin.PAD * 2 - 8, XSkinInnerTabs.H)
	list.position = Vector2(lx, LIST_TOP + shift)
	var rows := floori((cs.y - LIST_TOP - shift - FOOTER_H) / float(row_height))
	list.size = Vector2(cs.x - lx - 8.0, rows * row_height)


# ---- 按状态重画 ----

func sync() -> void:
	if layout == null:
		return
	_syncing = true
	var sc := scene
	for w in [sc.cmd_win, sc.info_win, sc.list_win, sc.status_win, sc.gold_win, sc.onekey_win, sc.confirm_win]:
		w.visible = false
	sc.help_card.visible = false
	var mode := sc._mode
	_sync_ring(mode)
	_sync_tabs(mode)
	_sync_list(mode)
	_sync_card(mode)
	_sync_currency()
	_sync_dialog(mode)
	match mode:
		"command":
			set_focus("ring" if show_ring else "list")
		"buy", "sell", "onekey", "category":
			set_focus("list")
		"number":
			if stepper.visible:
				set_focus("stepper")
			else:
				set_focus("card")
			list.active = true   # 列表那一行照旧亮着：焦点只是落到右牌底
		"confirm":
			set_focus("none")
	stepper.focused = mode == "number" and stepper.visible
	list.quiet = mode == "number"   # T359 D256：焦点在数量条／右牌钮时列表选中行降静默，同屏只一个强焦点
	if mode != "number":
		stepper.close_editor()   # 离开数量态：手输框收起，别留着吞数字键和回车（小A核 P2-1）
	set_hint_list(_hints(mode))
	_syncing = false
	_place_tabs()
	_place_foot()
	list_panel.queue_redraw()
	layout.left.queue_redraw()
	top_layer.queue_redraw()


## 环上的是哪一页：command 时跟 _cmd，别的态跟当前列表
func _page_of(mode: String) -> int:
	match mode:
		"buy":
			return 0
		"sell", "category":
			return 1
		"onekey":
			return 2
		"number":
			return 0 if scene._number_from == "buy" else 1
		"confirm":
			return 1 if scene._confirm_kind == "multi" else 2
	return clampi(scene._cmd, 0, 2)


func _sync_ring(mode: String) -> void:
	var pg := _page_of(mode)
	if show_ring:
		var items := [{"key": "buy", "name": T_BUY, "icon": ORB_ICONS[0]}, {"key": "sell", "name": T_SELL, "icon": ORB_ICONS[1]},
			{"key": "onekey", "name": T_ONEKEY, "icon": ORB_ICONS[2]}]
		if ring.items.size() != items.size():
			set_categories(items, pg)
		elif ring.index != pg:
			ring.select(pg)
	match pg:
		0:
			ring_center = [str(scene._buy_data().size()), "种"]
		1:
			var sym: String = XShop.CATEGORIES[scene._cat][1]
			ring_center = [str(scene._sell_data().size()), "件" if sym in ["weapon", "armor"] else "种"]
		_:
			ring_center = [str(XState.current.gear.size()), "件"]
	ring.queue_redraw()


func _sync_tabs(mode: String) -> void:
	var vis := _page_of(mode) == 1
	if inner_tabs.visible != vis:
		inner_tabs.visible = vis
	if inner_tabs.index != scene._cat:
		inner_tabs.select(scene._cat, false)


func _sync_list(mode: String) -> void:
	var sc := scene
	var pg := _page_of(mode)
	var rows := []
	var idx := 0
	list.check_column = false
	_list_right = ""
	match pg:
		0:
			list_title = T_BUY
			list.empty_text = T_EMPTY_BUY
			var n_ok := 0
			for e in sc._buy_data():
				var r := buy_row(e)
				if str(r.get("_reason", "")) == "":
					n_ok += 1
				rows.append(r)
			idx = sc._buy_index
			if not rows.is_empty():
				_list_right = "买得起 %d 种" % n_ok
		1:
			list_title = T_SELL
			list.empty_text = T_EMPTY_SELL
			var markable: bool = XShop.MULTI_SELL and (XShop.CATEGORIES[sc._cat][1] in ["weapon", "armor"] or XShop.ITEM_MULTI and XShop.CATEGORIES[sc._cat][1] in ["item", "consumable"])
			list.check_column = markable
			rows = _sell_rows(markable)
			idx = sc._sell_index
			if XShop.MULTI_SELL and sc.has_marks():
				_list_right = "已选 %s · 得 %s" % [sc.marked_label(), XSkinTemplatePage._group(sc.marked_gold())]
		_:
			list_title = T_ONEKEY
			list.empty_text = ""
			rows = onekey_rows()
			idx = sc._onekey
			_list_right = "按品质一次卖掉"
	var key := [pg, sc._cat, list.check_column, rows.map(func(r): return [r.text, r.get("right", ""), r.get("right2", ""), r.get("disabled", false), r.get("tags", []), r.get("check", -1), r.get("sub", ""), r.get("right_color", Color.WHITE)])]
	if key != _list_key:
		_list_key = key
		set_items(rows, clampi(idx, 0, maxi(rows.size() - 1, 0)))
	elif list.index != idx and idx < rows.size():
		list.select(idx)
	list_panel.queue_redraw()


# ---- 行 ----

var _sell_key := []
var _sell_cache := []


## 出售列表的行：每行要判能不能标（XSafeSell.reason，含词条），背包大时一按一卡；背包、标记、门槛没变就用上次的
func _sell_rows(markable: bool) -> Array:
	var sc := scene
	var s := XState.current
	var key := [sc._cat, markable, s.get_instance_id(), s.gear.size(), s.items.hash(), sc._marks.size(), sc._item_marks.hash(), XSafeSell.threshold(s), s.gold]
	if key == _sell_key:
		return _sell_cache
	XAlienation.begin_batch(s)  # 同 XShop.live_marks：整批查吞器供体表
	var rows := []
	for e in sc._sell_data():
		rows.append(sell_row(e, markable))
	XAlienation.end_batch()
	_sell_key = key
	_sell_cache = rows
	return rows


## 购买一行：_reason＝买不了的原因（""＝能买）；售完整行变灰，买不起只把价格变橙
func buy_row(e: Dictionary) -> Dictionary:
	var sc := scene
	var s := XState.current
	var rec: Dictionary = e.rec
	var reason := buy_block_reason(e)
	var r := {"text": XQuality.list_name(rec), "icon": int(rec.get("iconIndex", 0)), "color": XGear.color(rec), "_reason": reason}
	var stock := []
	if sc.stock_group != "" and XShopStock.shop_managed(int(e.kind), int(e.gid)):
		stock = [XShopStock.remaining(s, sc.stock_group, int(e.kind), int(e.gid)), XShopStock.stock_max(int(e.kind), int(e.gid))]
		r.sub = "%s %d / %d" % [XShop.STOCK_CAPTION, int(stock[0]), int(stock[1])]
	if not XShopStock.available(s, sc.stock_group, int(e.kind), int(e.gid)):
		r.right = XShop.SOLD_OUT
		r.disabled = true
		return r
	r.right = price_text(buy_prices(e))
	r.right_color = XUiSkin.GOLD_LIGHT if reason == "" else XUiSkin.DOWN
	if reason != "" and not reason.ends_with("不够"):
		r.disabled = true   # 不是钱的原因（拿满了、没解锁……）整行变灰
	return r


## 出售一行：名字去掉「[锁定]」「[置顶]」换成小标；行尾卖出价；名字后持有数（物品）或背包序号（装备）
func sell_row(e: Dictionary, markable: bool) -> Dictionary:
	var sc := scene
	var s := XState.current
	var rec: Dictionary = e.rec
	var name := XQuality.list_name(rec).replace(XItemMarks.LOCK, "").replace(XItemMarks.TOP, "").strip_edges()
	var tags := []
	var locked := str(rec.get("name", "")).contains(XItemMarks.LOCK)
	if XItemRow.shows_new(s, rec):
		tags.append("新")
	if locked:
		tags.append("已锁定")
	if str(rec.get("name", "")).contains(XItemMarks.TOP):
		tags.append("置顶")
	var r := {"text": name, "icon": int(rec.get("iconIndex", 0)), "color": XGear.color(rec), "sub": XItemRow.right_text(e)}
	if not tags.is_empty():
		r.tags = tags
	if locked or not XItemMarks.can_sell(rec):
		r.right = "不能卖"
		r.disabled = true
	else:
		r.right = price_text(sell_prices(rec))
		r.right_color = XUiSkin.GOLD_LIGHT
	if markable:
		if sc.is_marked(rec):
			r.check = 1
		elif XShop.can_mark(rec) if XItemMarks.is_gear(rec) else XShop.can_mark_item(rec):
			r.check = 0
	return r


## 一键出售的行：XShop._onekey_rows（保留词条、七档、出售类别），七档行尾「N 件 · 能卖多少」
func onekey_rows() -> Array:
	var out := []
	for row in scene._onekey_rows():
		var g := int(row.grade)
		var r := {"text": str(row.text), "icon": 0}
		if g >= 0:
			var p := plan_of(g)
			if (p.sell as Array).is_empty():
				r.right = "没有"
				r.disabled = (p.keep as Array).is_empty()
				if not r.disabled:
					r.right = "全留住"
			else:
				r.right = "%d 件" % (p.sell as Array).size()
				r.right_color = XUiSkin.TEXT_2
				r.right2 = XSkinTemplatePage._group(plan_gold(p))
				r.right2_color = XUiSkin.GOLD_LIGHT
			r.color = _grade_color(g)
		else:
			r.color = XUiSkin.TEXT_2
		out.append(r)
	list.right2_w = 96.0 if out.any(func(x): return x.has("right2")) else 0.0
	return out


## 一键出售第 g 档（XQuality.config().names 的序号，0 普通 … 6 神话）的品质色
func _grade_color(g: int) -> Color:
	return XUiSkin.quality_color(g)


## 一键出售某档的计划（XShop._onekey_plan；背包、门槛、类别没变就不重算）
func plan_of(g: int) -> Dictionary:
	var s := XState.current
	var key := [s.gear.size(), s.gold, XSafeSell.threshold(s), scene._onekey_kind, XSafeSell.ENABLED]
	if key != _plan_key:
		_plan_key = key
		_plans = {}
	if not _plans.has(g):
		_plans[g] = scene._onekey_plan(s, g) if XSafeSell.ENABLED else {"sell": XItemMarks.sellable_gear(s, XItemMarks.onekey_members(g), true), "keep": []}
	return _plans[g]


static func plan_gold(p: Dictionary) -> int:
	var g := 0
	for e in p.sell:
		g += XItemMarks.selling_price(e)
	return g


# ---- 价钱 ----

## 买入价：[[数, 单位名]]，金币在前（有数据库价格时），再按旧页从左到右的顺序：物品、变量（旧页从右往左画、插件 unshift 倒序）
func buy_prices(e: Dictionary) -> Array:
	var out := []
	var r := XItemMarks.sell_rewards(e.item)
	for id in r.buy_items:
		out.append([int(r.buy_items[id]), str(XDB.rec("Items", int(id)).get("name", ""))])
	for v in r.buy_vars:
		out.append([int(r.buy_vars[v]), var_name(int(v))])
	if int(e.rec.get("price", 0)) > 0 or out.is_empty():
		out.push_front([int(e.price), ""])
	return out


## 卖出所得：金币（卖价 >0 时）＋报酬变量、物品
static func sell_prices(rec: Dictionary) -> Array:
	var out := []
	var gold := XItemMarks.selling_price(rec)
	var r := XItemMarks.sell_rewards(rec)
	for id in r.items:
		out.append([int(r.items[id]), str(XDB.rec("Items", int(id)).get("name", ""))])
	for v in r.vars:
		out.append([int(r.vars[v]), var_name(int(v))])
	if gold > 0 or out.is_empty():
		out.push_front([gold, ""])
	return out


## 「5,200」或「3 号角」，几种并列用「＋」；单位空＝精魂（右上写着，不重复写）
static func price_text(prices: Array, times := 1) -> String:
	var parts := []
	for p in prices:
		var v := XSkinTemplatePage._group(int(p[0]) * times)
		parts.append(v if str(p[1]) == "" else "%s %s" % [v, str(p[1])])
	return " ＋ ".join(parts)


static func var_name(v: int) -> String:
	var u := XShop._var_unit(v)
	return str(u[0]).strip_edges() if str(u[0]).strip_edges() != "" else "货币"


## 买不了的原因：""＝能买；「售完」；「XX不够」（XX＝缺的那样计价物）；「拿满了」；别的「买不了」。玩家可见文字（待小A 审）
func buy_block_reason(e: Dictionary) -> String:
	var s := XState.current
	var sc := scene
	if not XShopStock.available(s, sc.stock_group, int(e.kind), int(e.gid)):
		return XShop.SOLD_OUT
	if sc._buy_enabled(e) and sc._max_buy(e) > 0:
		return ""
	var item: Dictionary = e.item
	var r := XItemMarks.sell_rewards(item)
	for id in r.buy_items:
		if s.item_count(int(id)) < int(r.buy_items[id]):
			return str(XDB.rec("Items", int(id)).get("name", "")) + "不够"
	for v in r.buy_vars:
		if s.variable(int(v)) < int(r.buy_vars[v]):
			return var_name(int(v)) + "不够"
	if XItemMarks.is_gear(item):
		var kind := str(item.get("kind", "weapon"))
		if s.gear.filter(func(x): return x.kind == kind).size() >= XItemMarks.MAX_ITEMS:
			return "拿满了"
	elif s.item_count(int(item.get("id", 0))) >= XItemMarks.MAX_ITEMS:
		return "拿满了"
	if int(e.price) > s.gold:
		return "精魂不够"
	return "买不了"


# ---- 右上货币：跟着选中的商品（XShop._paint_gold 同一套：有别的计价物且数据库价为 0 时不写精魂）----

func _sync_currency() -> void:
	var s := XState.current
	var item := scene._gold_item
	var r := XItemMarks.sell_rewards(item) if not item.is_empty() else {}
	var vars: Dictionary = r.get("buy_vars" if scene._gold_buy else "vars", {})
	var items: Dictionary = r.get("buy_items" if scene._gold_buy else "items", {})
	var out := []
	for id in items:
		out.append([str(XDB.rec("Items", int(id)).get("name", "")), XSkinTemplatePage._group(s.item_count(int(id)))])
	for v in vars:
		out.append([var_name(int(v)), XSkinTemplatePage._group(int(s.variable(int(v))))])
	if vars.is_empty() and items.is_empty() or int(item.get("price", 0)) > 0:
		out.append(["精魂", XSkinTemplatePage._group(s.gold)])
	currencies = out


# ---- 右牌 ----

func _sync_card(mode: String) -> void:
	var sc := scene
	var pg := _page_of(mode)
	_foot_lines = []
	stepper.visible = false
	if pg == 2:
		_sync_onekey_card()
		return
	var e := {}
	if mode == "number":
		e = sc._number_entry()
	elif pg == 0:
		var d := sc._buy_data()
		e = d[sc._buy_index] if sc._buy_index < d.size() else {}
	else:
		var d := sc._sell_data()
		e = d[sc._sell_index] if sc._sell_index < d.size() else {}
	if e.is_empty():
		set_card({"title": "", "desc": "", "sections": [], "buttons": []})   # 空列表右牌不画（T254 3.0「空列表」）
		card.visible = false
		_place_foot()
		return
	card.visible = true
	var rec: Dictionary = e.rec
	var crec := rec
	if rec.has("etypeId") and not rec.has("itypeId") and not XItemMarks.is_gear(rec):
		crec = rec.duplicate()   # 购买列表的装备是模板记录（没有 kind）：按装备排牌（自带、词条），不当物品
		crec["kind"] = "weapon" if rec.has("wtypeId") else "armor"
		crec["base"] = int(rec.get("id", 0))
	var d := XSkinItemPage.card_data(crec)
	d.title = str(d.title).replace(XItemMarks.LOCK, "").replace(XItemMarks.TOP, "").strip_edges()
	var sub := Array(str(d.subtitle).split(" · ", false))
	sub = sub.filter(func(x): return not str(x).begins_with("持有"))
	if pg == 0:
		sub.append("持有 %d" % owned(rec))
	elif XItemMarks.is_gear(rec):
		sub.append("背包里第 %d 件" % int(e.get("carry", 0)))
	else:
		sub.append("持有 %d" % int(e.get("count", 0)))
	d.subtitle = " · ".join(sub)
	if rec.has("etypeId") and not rec.has("itypeId"):   # 同旧状态窗：装备才有「换上后」
		d.sections = (d.sections as Array) + [equip_section(rec)]
	var buying := pg == 0
	var in_number := mode == "number"
	var buttons := []
	if buying:
		var reason := buy_block_reason(e)
		stepper.visible = true
		stepper.enabled = reason == ""
		var mx := maxi(1, sc._max_buy(e)) if reason == "" else 1
		stepper.set_range(1, mx, sc._number if in_number else 1)
		var n := stepper.value
		_foot_lines.append(["合计", price_text(buy_prices(e), n), XUiSkin.GOLD_LIGHT if reason == "" else XUiSkin.DOWN])
		buttons.append({"text": T_BUY if reason == "" else reason, "primary": true, "disabled": reason != ""})
	else:
		var locked := str(rec.get("name", "")).contains(XItemMarks.LOCK)
		var sellable := not locked and XItemMarks.can_sell(rec)
		var count := int(e.get("count", 1))
		var stack := not XItemMarks.is_gear(rec) and count > 1
		if stack and sellable:
			stepper.visible = true
			stepper.enabled = true
			stepper.set_range(1, count, sc._number if in_number else 1)
		var n2 := stepper.value if stepper.visible else 1
		if sellable:
			_foot_lines.append(["出售可得" if not stack else "合计", price_text(sell_prices(rec), n2), XUiSkin.GOLD_LIGHT])
		if XShop.MULTI_SELL and sc.has_marks() and (sc._gear_sell_list() or sc._mode == "confirm") and not in_number:
			_foot_lines.append(["按确定会先弹出确认。", "", XUiSkin.TEXT_2])
			buttons.append({"text": multi_button_text(), "primary": true})
		elif in_number and sc._number_mark:
			buttons.append({"text": "加入已选", "primary": true})
		elif sellable:
			buttons.append({"text": T_SELL, "primary": true})
		else:
			buttons.append({"text": "不能卖", "primary": true, "disabled": true})
	d.buttons = buttons
	if mode == "number" and not stepper.visible:
		d.button_index = 0
	set_card(d)
	_place_foot()


## 一键出售右牌：直接读 XSafeSell.plan（XShop._onekey_plan）
func _sync_onekey_card() -> void:
	card.visible = true
	var sc := scene
	var s := XState.current
	var rows := sc._onekey_rows()
	if rows.is_empty():
		set_card({"title": T_ONEKEY, "desc": "", "sections": [], "buttons": []})
		return
	var row: Dictionary = rows[clampi(sc._onekey, 0, rows.size() - 1)]
	var g := int(row.grade)
	if g == XShop.ONEKEY_KIND_ROW:
		set_card({"title": "出售类别", "subtitle": "当前：" + str(XShop.ONEKEY_KINDS[sc._onekey_kind][0]),
			"desc": "按确定在「全部」「只卖武器」「只卖护甲」之间切换。", "sections": [], "buttons": [{"text": "切换类别", "primary": true}]})
		return
	if g < 0:
		set_card({"title": "保留词条", "subtitle": "当前：" + XSafeSell.label(s), "desc": XSafeSell.HELP, "sections": [],
			"buttons": [{"text": "切换门槛", "primary": true}]})
		return
	var p := plan_of(g)
	var sections := []
	sections.append({"title": "会卖掉", "lines": [{"left": "件数", "right": str((p.sell as Array).size())},
		{"left": "出售可得", "right": XSkinTemplatePage._group(plan_gold(p)), "right_color": XUiSkin.GOLD_LIGHT}]})
	var keep: Array = p.keep
	if not keep.is_empty():
		var counts := {}
		for k in keep:
			counts[str(k.reason)] = int(counts.get(str(k.reason), 0)) + 1
		var lines := []
		for why in counts:
			lines.append({"left": why, "right": str(counts[why])})
		sections.append({"title": "自动留住 %d 件" % keep.size(), "lines": lines})
	var desc := "按确定会先弹出确认，光标停在「取消」。" if XSafeSell.ENABLED else ""
	set_card({"title": str(row.text), "subtitle": "保留词条：" + XSafeSell.label(s) if XSafeSell.ENABLED else "", "desc": desc, "sections": sections,
		"buttons": [{"text": "卖掉这一档…", "primary": true, "disabled": (p.sell as Array).is_empty()}]})


## 状态窗「持有数」：代购商品看代购件；装备按模板数
static func owned(rec: Dictionary) -> int:
	var s := XState.current
	if rec.has("itypeId"):
		var pid := XItemMarks.proxy_buy(rec)
		return s.item_count(pid if pid > 0 else int(rec.id))
	var kind: String = rec.get("kind", "weapon" if rec.has("wtypeId") else "armor")
	return s.gear_count(kind, int(rec.get("base", rec.id)))


## 「换上后」一节：旧页状态窗的八项（actor 看法：一个队员 × 八项，只列变了的）；Tab 切到旧页「默认」看法：一项属性 × 全队
func equip_section(rec: Dictionary) -> Dictionary:
	var sc := scene
	var s := XState.current
	var members := s.members()
	if members.is_empty():
		return {"title": "换上后", "lines": []}
	var item := rec if rec.has("kind") else XGear.template("weapon" if rec.has("wtypeId") else "armor", int(rec.id))
	if sc._stat_default and XShop.STAT_DEFAULT_MODE:
		var lines := []
		var pages := maxi(1, ceili(float(members.size()) / XShop.PAGE_SIZE))
		var start := clampi(sc._page_index, 0, pages - 1) * XShop.PAGE_SIZE
		for i in range(start, mini(start + XShop.PAGE_SIZE, members.size())):
			var a: XActor = members[i]
			if not a.can_equip(item):
				lines.append({"left": a.display_name(), "right": "装不上", "right_color": XUiSkin.TEXT_3})
				continue
			var ch := int(XTianqiGear.param_of(item, sc._param_id)) - XShop._worst_equipped_param(a, int(item.etypeId), sc._param_id)
			lines.append({"left": a.display_name(), "right": _delta(ch), "right_color": _delta_color(ch)})
		return {"title": "换上后　‹ %s ›" % XItemStatusPainter.param_name(sc._param_id), "lines": lines}
	var idx := clampi(sc._actor_index, 0, members.size() - 1)
	var a2: XActor = members[idx]
	var head := "换上后　‹ %s ›" % a2.display_name()
	if not a2.can_equip(item):
		return {"title": head, "lines": [{"left": "装不上", "color": XUiSkin.TEXT_3}]}
	var slot: int = a2.equip_slots().find(int(item.etypeId))
	var cur = a2.equips[slot] if slot >= 0 and slot < a2.equips.size() else null
	var out := []
	var same := 0
	for i in range(8):
		var ch2 := int(XTianqiGear.param_of(item, i)) - (int(XTianqiGear.param_of(cur, i)) if cur != null else 0)
		if ch2 == 0:
			same += 1
			continue
		out.append({"left": XItemStatusPainter.param_name(i), "right": _delta(ch2), "right_color": _delta_color(ch2), "color": XUiSkin.TEXT})
	if same > 0:
		out.append({"left": "其余 %d 项不变" % same if not out.is_empty() else "八项都不变", "color": XUiSkin.TEXT_3})
	return {"title": head, "lines": out}


static func _delta(v: int) -> String:
	return ("▲" if v > 0 else ("▼" if v < 0 else "")) + XSkinTemplatePage._group(absi(v))


static func _delta_color(v: int) -> Color:
	return XUiSkin.UP if v > 0 else (XUiSkin.DOWN if v < 0 else XUiSkin.TEXT_3)


# ---- 牌底：数量条＋合计 ----

func _foot_h() -> float:
	var h := 0.0
	if stepper != null and stepper.visible:
		h += XSkinStepper.H + XUiSkin.GRID
	h += _foot_lines.size() * FOOT_LINE_H
	return h


func _place_foot() -> void:
	if foot == null or card == null:
		return
	var h := _foot_h()
	card.reserve_bottom = h + (XUiSkin.GRID if h > 0 else 0.0)
	var bottom := card.size.y - card.pad - (XSkinCard.BUTTON_H + XUiSkin.GRID if not card.buttons.is_empty() else 0.0)
	foot.position = Vector2(card.pad, bottom - h)
	foot.size = Vector2(card.size.x - card.pad * 2, h)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if stepper.visible:
		stepper.position = Vector2.ZERO
		stepper.size = Vector2(foot.size.x, XSkinStepper.H)
	foot.queue_redraw()
	card.queue_redraw()


func _draw_foot() -> void:
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var y := (XSkinStepper.H + XUiSkin.GRID) if stepper.visible else 0.0
	var w := foot.size.x
	for ln in _foot_lines:
		var base := y + FOOT_LINE_H / 2.0
		var right := str(ln[1])
		if right == "":
			XUiSkin.ds(foot, body, Vector2(0, base + XUiSkin.FS_AUX * 0.36), str(ln[0]), HORIZONTAL_ALIGNMENT_LEFT, w, XUiSkin.FS_AUX, ln[2])
		else:
			XUiSkin.ds(foot, body, Vector2(0, base + XUiSkin.FS_AUX_MAX * 0.36), str(ln[0]), HORIZONTAL_ALIGNMENT_LEFT, w * 0.4, XUiSkin.FS_AUX_MAX, XUiSkin.TEXT_2)
			var fit := XSkinList.fit_text(num, right, w * 0.6, 21, 15)
			var rw := num.get_string_size(str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1])).x
			XUiSkin.ds(foot, num, Vector2(w - rw, base + int(fit[1]) * 0.36), str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1]), ln[2])
		y += FOOT_LINE_H


# ---- 确认弹窗 ----

## confirm 态：安全出售（钮＝确认出售／取消 → _confirm 2／3）、多选（出售已选／清空选择／取消 → 1／2／3）
func _sync_dialog(mode: String) -> void:
	if mode != "confirm":
		if dialog != null:
			dialog.queue_free()
			dialog = null
		return
	var sc := scene
	var d := confirm_data()
	if dialog == null:
		dialog = XSkinConfirm.new()
		dialog.chosen.connect(_on_dialog_chosen)
		dialog.index_changed.connect(_on_dialog_index)
		dialog.cancelled.connect(func(): scene._cancel())
		add_child(dialog)
	d.index = sc._confirm - confirm_base()
	dialog.setup(d)


## 弹窗第一枚钮对应 XShop._confirm 的第几行
func confirm_base() -> int:
	return 1 if scene._confirm_kind == "multi" else 2


func confirm_data() -> Dictionary:
	var sc := scene
	var rows := sc.confirm_rows()
	var base := confirm_base()
	var buttons := []
	for i in range(base, rows.size()):
		buttons.append({"text": str(rows[i][0]), "disabled": not bool(rows[i][1])})
	if sc._confirm_kind == "multi":
		# 正文不借 XShop.multi_rows 的「金币」（西游旧页的字，旧专项按它核）：天启篇货币叫精魂（小A核 P2-3）
		var body := "已选%s，共得 %s 精魂" % [sc.marked_label(), XSkinTemplatePage._group(sc.marked_gold())]
		return {"title": "出售已选物品？", "body": body, "buttons": buttons, "danger": true}
	return {"title": "卖掉这一档？", "body": "%s。%s" % [str(rows[0][0]), str(rows[1][0])], "buttons": buttons, "danger": true}


func _on_dialog_index(i: int) -> void:
	if _syncing:
		return
	var before := scene._cursor_state()
	scene._confirm = i + confirm_base()
	scene._cursor_se(before)
	scene._refresh()


func _on_dialog_chosen(i: int) -> void:
	scene._confirm = i + confirm_base()
	scene._ok()


# ---- 按键提示 ----

func _hints(mode: String) -> Array:
	var sc := scene
	match mode:
		"command":
			return [["确定", "选择"], ["取消", "离开"]]
		"buy":
			var h := [["确定", "定数量"]]
			if _cur_gear():
				h.append(["← / →", "换人"])
			h.append(["Q / E", "翻页"])
			h.append(["取消", "返回"])
			return h
		"sell":
			var h2 := [["确定", "出售已选" if XShop.MULTI_SELL and sc.has_marks() and sc._gear_sell_list() else "出售"]]
			if sc._gear_sell_list():
				h2.append(["C", "选 / 不选"])
			h2.append(["Q / E", "换分类"])
			h2.append(["取消", "返回"])
			return h2
		"number":
			var verb := "加入已选" if sc._number_mark else (T_BUY if sc._number_from == "buy" else T_SELL)
			if stepper.visible:
				return [["← / →", "±1"], ["↑ / ↓", "±10"], ["Q / E", "1 / 最多"], ["确定", verb], ["取消", "返回"]]
			return [["确定", verb], ["取消", "返回"]]
		"onekey":
			return [["确定", "选择"], ["取消", "返回"]]
		"confirm":
			return [["← / →", "切换"], ["确定", "选择"], ["取消", "返回"]]
	return [["确定", "选择"], ["取消", "返回"]]


## 多选主按钮：只有装备写「件」；勾了能叠的物品时按勾了几项写「项」（数量不一定是件数，小A文字审 W-4）
func multi_button_text() -> String:
	var sc := scene
	var ni := sc.live_item_marks().size()
	if ni == 0:
		return "出售已选 %d 件" % sc.live_marks().size()
	return "出售已选 %d 项" % (sc.live_marks().size() + ni)


func _cur_gear() -> bool:
	var rec := scene._current_rec()
	return not rec.is_empty() and rec.has("etypeId") and not rec.has("itypeId")


# ---- 按键：环、页签走新布局；其余（列表上下、翻页、数量、C、Tab、确定、取消）交回 XShop 原来的代码 ----

## 用掉了返回 true（XShop._unhandled_input 开头调）
func input(event: InputEvent) -> bool:
	var sc := scene
	if sc._mode == "confirm" and dialog != null:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			return false   # 确定、取消照旧页走（_ok／_cancel：音、重算计划、回到哪）
		return dialog.handle_input(event)
	if sc._mode == "command" and show_ring:
		var d := 0
		if event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_left", true):
			d = -1
		elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_right", true):
			d = 1
		if d != 0:
			var before := sc._cursor_state()
			sc._cmd = posmod(sc._cmd + d, 3)
			sc._cursor_se(before)
			sc._refresh()
			return true
		if XMenu.page_dir(event) != 0:
			return true
		return false
	if sc._mode == "sell" and inner_tabs.visible and XMenu.page_dir(event) != 0:
		_switch_tab(scene._cat + XMenu.page_dir(event))
		return true
	return false


func _switch_tab(i: int) -> void:
	var sc := scene
	i = posmod(i, XShop.CATEGORIES.size())
	if i == sc._cat:
		return
	sc._drop_cache()
	sc._cat = i
	sc._sell_index = 0
	sc._sell_top = 0
	XSound.system(0)
	if sc._mode == "command":
		sc._cmd = 1
	sc._refresh()


# ---- 点击 → 同样的状态变化 ----

func _on_ring_changed(i: int) -> void:
	if _syncing:
		return
	var sc := scene
	if sc._mode == "command":
		if i != sc._cmd:
			sc._cmd = i
			XSound.system(0)
			sc._refresh()
		return
	if sc._mode in ["buy", "sell", "onekey"]:
		# 列表态点别的球：先回到环上（同取消），再换到那个球
		sc._cancel()
		if sc._mode == "category":
			sc._mode = "command"
		sc._cmd = i
		sc._refresh()
		return
	ring.select(_page_of(sc._mode), false)


func _on_ring_clicked(i: int) -> void:
	if _syncing:
		return
	if scene._mode == "command" and i == scene._cmd:
		scene._click_ok()


func _on_tab(i: int) -> void:
	if _syncing:
		return
	if scene._mode in ["sell", "command"]:
		_switch_tab(i)
	else:
		inner_tabs.select(scene._cat, false)


func _on_list_index(i: int) -> void:
	if _syncing:
		return
	var sc := scene
	var before := sc._cursor_state()
	match sc._mode:
		"command":
			sc._ok()   # 环上时点列表行＝进这个列表，再落到点的那一行
			if sc._mode in ["buy", "sell", "onekey"]:
				_set_index(i)
			return
		"buy", "sell", "onekey":
			_set_index(i)
		"number":
			sc._cancel()   # 数量条上时点了别的行：回列表、换行（数量复位）
			_set_index(i)
			return
		_:
			return
	sc._cursor_se(before)
	sc._refresh()


func _set_index(i: int) -> void:
	var sc := scene
	match sc._mode:
		"buy":
			sc._buy_index = i
			sc._buy_top = XMenu._scroll_to(i, sc._buy_top, sc._list_rows())
		"sell":
			sc._sell_index = i
			sc._sell_top = XMenu._scroll_to(i, sc._sell_top, sc._list_rows())
		"onekey":
			sc._onekey = i
	sc._refresh()


func _on_list_click(i: int) -> void:
	var sc := scene
	if sc._mode == "command":
		# 环上时点列表里正亮着的那一行（第 1 行）：XSkinList 发的是 activated 不是 index_changed，同样进列表（小A核 P2-2）
		sc._ok()
		if sc._mode in ["buy", "sell", "onekey"]:
			_set_index(i)
		return
	if sc._mode in ["buy", "sell", "onekey"]:
		var cur: int = sc._buy_index if sc._mode == "buy" else (sc._sell_index if sc._mode == "sell" else sc._onekey)
		if i == cur:
			sc._click_ok()


## 行首方框（多选）：按下记行、松手还在同一个框上才算一次标记（不选中、不确定）
func _on_list_gui(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not (list.check_column and scene._mode == "sell"):
		return
	var p: Vector2 = event.position
	var row := list.item_at(p)
	var in_box: bool = row >= 0 and p.x - list.cell_rect(row).position.x < 14.0 + XSkinList.CHECK_W and list.items[row].has("check")   # 不能标的行照常选中（小A核 P3-2）
	if event.pressed:
		_check_press = row if in_box else -1
		if in_box:
			list.accept_event()
		return
	if _check_press >= 0:
		list.accept_event()
		if in_box and row == _check_press and list.items[row].has("check"):
			scene._sell_index = row
			scene._clicked_ok = true
			scene.toggle_mark()
			scene._refresh()
		_check_press = -1


func _on_card_button(_i: int) -> void:
	var sc := scene
	match sc._mode:
		"buy", "sell":
			sc._click_ok()
			if sc._mode == "number":
				sc._click_ok()   # 列表态点主按钮＝确定、确定（数量 1）；多选有标记时第一下就开确认弹窗，不再按第二下
		"number", "onekey":
			sc._click_ok()


func _on_stepper_touched() -> void:
	var sc := scene
	if sc._mode in ["buy", "sell"]:
		sc._ok()   # 列表态点数量钮：先落到数量条（同按确定），钮接着改数
		stepper.set_range(1, maxi(1, sc._max_number()) if sc._mode == "number" else 1, sc._number)


func _on_stepper_value(v: int) -> void:
	if _syncing:
		return
	var sc := scene
	if sc._mode != "number":
		stepper.set_value(1, false)
		return
	var before := sc._number
	sc._num_text = ""
	sc._number = clampi(v, 1, maxi(1, sc._max_number()))
	if sc._number != before:
		XSound.system(0)
	sc._refresh()


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		scene._cancel()
		accept_event()


# ---- 画：列表标题右边一行小字；没有环时左块的主视觉 ----

func _draw_list_right() -> void:
	if _list_right == "":
		return
	var body := XUiSkin.font("body")
	var fs := XUiSkin.FS_AUX
	var tw := body.get_string_size(_list_right, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	XUiSkin.ds(list_panel, body, Vector2(list_panel.size.x - XUiSkin.PAD - 8 - tw, XUiSkin.PAD + 20), _list_right, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_2)


## 只买不卖的店（purchase_only）：不画环，左块正中放「购买」的大图标和字
func _draw_left_visual() -> void:
	if show_ring:
		return
	var lb := layout.left.size
	var tex := XUiSkin.icon(ORB_ICONS[0])
	var c := Vector2(lb.x / 2.0, lb.y / 2.0 - 40.0)
	if tex != null:
		layout.left.draw_texture_rect(tex, Rect2(c - Vector2(48, 48), Vector2(96, 96)), false)
	var f := XUiSkin.font("title")
	var tw := f.get_string_size(T_BUY, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_CARD).x
	XUiSkin.ds(layout.left, f, Vector2(c.x - tw / 2.0, c.y + 90.0), T_BUY, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_CARD, XUiSkin.GOLD)
