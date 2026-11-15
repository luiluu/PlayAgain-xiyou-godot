class_name XSkinTemplatePage
extends Control
## 【cc·天启篇·未经审查】新界面模板页（界面风格提案 v0.7「模板页」：小环分类＋直列表＋详情牌），物品、技能页先用，
## 第 5 期商店、宝珠坊、制作、仓库、图鉴、存读档……都套它。按横屏锚点（XSkinLayout）摆三块：
##   左块：小环分类（XSkinRingNav，环心可写「30 种」这样的大数字＋小字）；不要环时 show_ring = false，左块留给页面自己放。
##   中块：面板＋旧金小标题（list_title）＋直列表（XSkinList，一列／两列、行高可设）＋底下一行小字（footer，默认自动「第 1 / 2 页」）。
##   右块：详情牌（XSkinCard）；要「给谁用」时牌的下半截放目标列表（XSkinTargetList，show_targets）；
##         要操作菜单时在牌底弹出一个小列表（open_menu）。
##   顶上：页名（34 号宋体）＋组页签条（当前组高亮）＋右上货币；右下：按键提示（XSkinKeyHints）。
##
## 两种用法（套用说明见交付单 cc_ui-skin-1b.md「模板页套用要点」）：
## - 自动导航（auto_nav = true，默认）：环 → 确定进列表 → 取消回环 → 环上取消发 back；列表确定发 item_activated、
##   牌上按钮发 card_button。页面只管：喂数据（set_categories／set_items／set_card）、接信号做事。简单页面（商店、图鉴）用这个。
## - 手动（auto_nav = false）：页面有自己的状态机（物品页、技能页），焦点由页面 set_focus，按键照样交给 handle_input，
##   模板只把按键转给当前焦点的组件，确定／取消都发信号（accepted、cancelled），不自己换焦点。
## 按键：页面在自己的 _unhandled_input 里先调 handle_input(event)，返回 true 就 set_input_as_handled。
## 新皮肤关着时不要建这一页（页面自己判断 XUiSkin.on()，关着走旧页）。

signal category_changed(index: int)
signal item_changed(index: int)
signal item_activated(index: int)
signal card_button(index: int)
signal target_changed(index: int)
signal target_activated(index: int)
signal menu_changed(index: int)
signal menu_activated(index: int)
## 确定／取消（focus＝当时的焦点）。自动导航时取消只在环上（顶层）才发 back
signal accepted(focus: String)
signal cancelled(focus: String)
signal back

# ---- 配置（_ready 之前设；之后改了调 relayout()）----
var title := ""
## 页签条高亮哪一组（XUiSkin.GROUPS 的 key）；"" 不画页签条
var group_key := ""
var list_title := ""
## 列表底下一行小字；auto_footer 为真时没写就自动「第 a / b 页」（列表超出一屏才写）
var footer := ""
var auto_footer := true
## 环心：[大字, 小字]（如 ["30", "种"]）；空＝不写
var ring_center: Array = []
## 右上货币：[[名字, 数值字]]；null＝默认只写精魂（XState.current.gold）
var currencies = null
var left_w := 300.0
var right_w := 336.0
var columns := 2
var row_height := XUiSkin.ROW_H_ITEMS
var ring_radius := 108.0
var orb_radius := 28.0
var show_ring := true
var auto_nav := true
## 按键提示 [[键, 说明]]
var hint_list: Array = [["确定", "选择"], ["取消", "返回"]]
## 收口批（TOUCH_V2）：左上页名前的「‹」返回（点＝取消）
var back_button: XSkinBackButton

# ---- 节点 ----
var backdrop: Control
var layout: XSkinLayout
var ring: XSkinRingNav
var list_panel: Panel
var list: XSkinList
var card: XSkinCard
var targets: XSkinTargetList
var menu_panel: Panel
var menu: XSkinList
var tabs: XSkinTabStrip
var hints: XSkinKeyHints
var top_layer: Control

## ring / list / card / targets / menu / none
var focus := "ring"
const LIST_TOP := 56.0          # 面板里列表从哪开始（小标题 16＋行 30＋间 10）
const FOOTER_H := 40.0
const MENU_ROW_H := 40


func _ready() -> void:
	add_to_group(XUiSkin.FULLSCREEN_GROUP)   # 收口批：开着时收起虚拟摇杆／AB 键
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = XUiSkin.theme()
	backdrop = XUiSkin.menu_backdrop(self)
	layout = XSkinLayout.new()
	layout.left_w = left_w
	layout.right_w = right_w
	add_child(layout)
	XSkinLayout.request_wide(self)
	# 左：小环
	ring = XSkinRingNav.new()
	ring.radius = ring_radius
	ring.orb_radius = orb_radius
	ring.label_size = XUiSkin.FS_AUX_MAX
	ring.visible = show_ring
	ring.draw.connect(_draw_ring_center)
	ring.changed.connect(func(i): category_changed.emit(i))
	ring.activated.connect(_on_ring_activated)
	layout.left.add_child(ring)
	# 中：面板＋列表
	list_panel = Panel.new()
	list_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	list_panel.draw.connect(_draw_list_panel)
	layout.center.add_child(list_panel)
	list = XSkinList.new()
	list.columns = columns
	list.row_height = row_height
	list.index_changed.connect(func(i):
		list_panel.queue_redraw()
		if auto_nav and focus == "ring":
			set_focus("list")   # 自动导航：环上时鼠标点列表行＝进列表
		item_changed.emit(i))
	list.activated.connect(_on_list_activated)
	list_panel.add_child(list)
	# 右：详情牌＋目标列表＋操作菜单
	card = XSkinCard.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.button_pressed.connect(func(i):
		card_button.emit(i))
	layout.right.add_child(card)
	targets = XSkinTargetList.new()
	targets.visible = false
	targets.index_changed.connect(func(i): target_changed.emit(i))
	targets.activated.connect(func(i): target_activated.emit(i))
	card.add_child(targets)
	menu_panel = Panel.new()
	menu_panel.visible = false
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layout.right.add_child(menu_panel)
	menu = XSkinList.new()
	menu.row_height = MENU_ROW_H
	menu.icon_size = 24
	menu.index_changed.connect(func(i): menu_changed.emit(i))
	menu.activated.connect(func(i): menu_activated.emit(i))
	menu_panel.add_child(menu)
	# 顶：页名、页签、货币；右下按键提示
	top_layer = Control.new()
	top_layer.name = "Top"
	top_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_layer.draw.connect(_draw_top)
	add_child(top_layer)
	if group_key != "":
		tabs = XSkinTabStrip.new()
		tabs.set_groups(XUiSkin.GROUPS, XState.current, group_key)
		tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 跨页签跳转由主菜单（1A）接；这里只显示当前组
		add_child(tabs)
	hints = XSkinKeyHints.new()
	hints.set_hints(hint_list)
	add_child(hints)
	back_button = XSkinBackButton.attach(self)
	resized.connect(relayout)
	get_viewport().size_changed.connect(relayout)
	relayout()
	if not show_ring and focus == "ring":
		focus = "list"   # 没有分类环时默认焦点在列表（不然方向键空打、取消直接退）
	set_focus(focus)


func relayout() -> void:
	if layout == null:
		return
	layout.left_w = left_w
	layout.right_w = right_w
	layout.relayout()
	var lb := layout.left.size
	var d := ring_radius * 2.0 + 120.0
	ring.size = Vector2(lb.x, d)
	ring.position = Vector2(0, maxf((lb.y - d) / 2.0 - 24.0, 0.0))
	var cs := layout.center.size
	var lx := 28.0 if XSkinArt.select_on() else 8.0   # 第一期正式美术：外置箭头（左探 22）收在烟底里（小A核 P2-1）
	list.position = Vector2(lx, LIST_TOP)
	var rows := floori((cs.y - LIST_TOP - FOOTER_H) / float(row_height))
	list.size = Vector2(cs.x - lx - 8.0, rows * row_height)
	_place_targets()
	_place_menu()
	var view := layout.view_size()
	if tabs != null:
		var f := XUiSkin.font("title")
		tabs.position = Vector2(XSkinLayout.margin_for(view.x) + (XSkinBackButton.W if back_button != null else 0.0) + f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_PAGE).x + 24, 14)
		tabs.size = Vector2(tabs.total_width(), XSkinTabStrip.TAB_H)
	hints.set_hints(hint_list)
	hints.place(view)   # 右边让出右下角版本号（XSkinKeyHints.right_edge）
	top_layer.queue_redraw()
	list_panel.queue_redraw()


## 换按键提示（随焦点变时用）；内容没变不重排
func set_hint_list(arr: Array) -> void:
	if arr == hint_list:
		return
	hint_list = arr
	if hints != null:
		relayout()


# ---- 喂数据 ----

## arr：[{key, name, icon, count}]；名字后自动带数量（「消耗品 15」）
func set_categories(arr: Array, index := 0) -> void:
	var items := arr.map(func(c):
		var n := str(c.get("name", ""))
		if c.has("count"):
			n += " %d" % int(c.count)
		return {"key": c.get("key", ""), "name": n, "icon": c.get("icon", 0)})
	ring.set_items(items, true)
	ring.select(clampi(index, 0, maxi(items.size() - 1, 0)), false)


func set_items(arr: Array, index := -1) -> void:
	list.set_items(arr, index >= 0)
	if index >= 0 and not arr.is_empty():
		list.select(index, false)
	list_panel.queue_redraw()


func set_card(d: Dictionary) -> void:
	var base := {"icon": null, "title": "", "title_color": XUiSkin.TEXT, "subtitle": "", "notice": "", "desc": "", "sections": [], "buttons": [], "button_index": -1}
	base.merge(d, true)
	if focus == "card" and not d.has("button_index") and not (base.buttons as Array).is_empty():
		base.button_index = 0   # 焦点在牌上时换了牌内容，仍落在第一个按钮
	card.setup(base)
	_place_targets()


## 「给谁用」：rows 见 XSkinTargetList；rows 空＝收起。selectable：现在在选人；all：全体对象
func show_targets(rows: Array, selectable := false, all := false, index := -1) -> void:
	targets.visible = not rows.is_empty()
	targets.set_rows(rows)
	targets.all = all
	targets.selectable = selectable
	if index >= 0:
		targets.select(index, false)
	_place_targets()


func _place_targets() -> void:
	if card == null or targets == null:
		return
	var h := XSkinTargetList.height_for(targets.rows.size()) if targets.visible else 0.0
	card.reserve_bottom = h + (XUiSkin.GRID if h > 0 else 0.0)
	var bottom := card.size.y - card.pad - (XSkinCard.BUTTON_H + XUiSkin.GRID if not card.buttons.is_empty() else 0.0)
	targets.position = Vector2(card.pad, bottom - h)
	targets.size = Vector2(card.size.x - card.pad * 2, h)
	card.queue_redraw()


## 操作菜单：在详情牌底部弹出的小列表。items 同 XSkinList；打开后焦点在菜单
func open_menu(items: Array, index := 0) -> void:
	menu.set_items(items)
	menu.select(clampi(index, 0, maxi(items.size() - 1, 0)), false)
	menu_panel.visible = true
	_place_menu()
	set_focus("menu")


func close_menu() -> void:
	menu_panel.visible = false


func _place_menu() -> void:
	if menu_panel == null or not menu_panel.visible:
		return
	var rs := layout.right.size
	var n := mini(menu.items.size(), 8)
	var h := n * MENU_ROW_H + XUiSkin.PAD * 2
	menu_panel.position = Vector2(XUiSkin.PAD, rs.y - XUiSkin.PAD - h)
	menu_panel.size = Vector2(rs.x - XUiSkin.PAD * 2, h)
	menu.position = Vector2(XUiSkin.GRID, XUiSkin.PAD)
	menu.size = Vector2(menu_panel.size.x - XUiSkin.GRID * 2, n * MENU_ROW_H)


# ---- 焦点与按键 ----

func set_focus(f: String) -> void:
	focus = f
	if list == null:
		return
	list.active = f == "list"
	if f != "menu":
		close_menu()
	if f != "card":
		card.button_index = -1
		card.queue_redraw()
	elif card.button_index < 0 and not card.buttons.is_empty():
		card.button_index = 0   # 焦点到牌上时先落在第一个按钮
		card.queue_redraw()
	hints.queue_redraw()


## 页面在 _unhandled_input 里转进来；返回 true＝用掉了
func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		cancelled.emit(focus)
		if auto_nav:
			_auto_cancel()
		return true
	var handled := false
	match focus:
		"ring":
			handled = ring.handle_input(event)
		"list":
			handled = list.handle_input(event)
		"card":
			handled = card.handle_input(event)
		"targets":
			handled = targets.handle_input(event)
		"menu":
			handled = menu.handle_input(event)
	if event.is_action_pressed("ui_accept"):
		accepted.emit(focus)
		handled = true
	return handled


func _on_ring_activated(_i: int) -> void:
	if auto_nav and focus == "ring":
		set_focus("list")


func _on_list_activated(i: int) -> void:
	item_activated.emit(i)


func _auto_cancel() -> void:
	match focus:
		"ring":
			back.emit()
		"list":
			set_focus("ring" if show_ring else "list")
			if not show_ring:
				back.emit()
		"menu", "card", "targets":
			set_focus("list")


# ---- 画 ----

func _draw_ring_center() -> void:
	if ring_center.is_empty():
		return
	var c := ring.center()
	var num := XUiSkin.font("num")
	var body := XUiSkin.font("body")
	var big := str(ring_center[0])
	var bw := num.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
	ring.draw_string(num, Vector2(c.x - bw / 2.0, c.y + 8), big, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, XUiSkin.TEXT)
	if ring_center.size() > 1:
		var small := str(ring_center[1])
		var sw := body.get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
		ring.draw_string(body, Vector2(c.x - sw / 2.0, c.y + 34), small, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, XUiSkin.TEXT_2)


func footer_text() -> String:
	if footer != "" or not auto_footer or list == null or not list.scrollable():
		return footer
	var vis := list.visible_rows()
	var pages := ceili(list.rows_total() / float(vis))
	var page := mini(ceili(list.top_row / float(vis)) + 1, pages)
	if list.top_row + vis >= list.rows_total():
		page = pages
	return "第 %d / %d 页" % [page, pages]


func _draw_list_panel() -> void:
	var body := XUiSkin.font("body")
	var s := list_panel.size
	if list_title != "":
		list_panel.draw_string(body, Vector2(XUiSkin.PAD + 8, XUiSkin.PAD + 20), list_title, HORIZONTAL_ALIGNMENT_LEFT, s.x - 48, 20, XUiSkin.GOLD)
	var ft := footer_text()
	if ft != "":
		var fw := body.get_string_size(ft, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
		list_panel.draw_string(body, Vector2((s.x - fw) / 2.0, s.y - XUiSkin.PAD), ft, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, XUiSkin.TEXT_2)


func _process(_delta: float) -> void:
	# 列表滚动时底下的页码跟着变（列表不发滚动信号，这里按帧比一下，变了才重画）
	if list != null and list.top_row != _last_top:
		_last_top = list.top_row
		list_panel.queue_redraw()


var _last_top := -1


func currency_pairs() -> Array:
	if currencies is Array:
		return currencies
	var s := XState.current
	return [["精魂", _group(s.gold if s != null else 0)]]


static func _group(v: int) -> String:
	var t := str(absi(v))
	var out := ""
	while t.length() > 3:
		out = "," + t.substr(t.length() - 3) + out
		t = t.substr(0, t.length() - 3)
	return ("-" if v < 0 else "") + t + out


func _draw_top() -> void:
	var view := layout.view_size()
	var m := XSkinLayout.margin_for(view.x)
	var tx := XSkinBackButton.place(back_button, m)   # 只挪页名，右上货币仍按页边距（小A核 P2-1）
	XSkinArt.bg_string(top_layer, XUiSkin.font("title"), Vector2(tx, 14 + 34 * 0.92), title, XUiSkin.FS_PAGE, XUiSkin.TEXT)
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var x := view.x - m
	for pair in currency_pairs():
		var v := str(pair[1])
		var vw := num.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		x -= vw
		XSkinArt.bg_string(top_layer, num, Vector2(x, 42), v, 26, XUiSkin.GOLD_LIGHT)
		var nw := body.get_string_size(str(pair[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		x -= nw + 6
		XSkinArt.bg_string(top_layer, body, Vector2(x, 42), str(pair[0]), 15, XSkinArt.bg_text_2())
		x -= 18


## 帮助：把说明卡的行（XHelpCard.content／detail_rows 的结果）转成详情牌的 rows 分节：去掉转义码、空行，颜色照说明卡（太暗的提到次要字）。
## skip_first：第一行是名字（牌上已有）时跳过
static func help_rows(rows: Array, skip_first := true) -> Array:
	var out := []
	var col := RegEx.create_from_string("(?i)(?:\\\\|\u001b)col\\[\\d+\\]")   # 说明卡一行两项（\col[50] 分到右半）：这里用两个全角空格隔开
	var esc := RegEx.create_from_string("(?i)(?:\\\\|\u001b)(?:[a-z]+\\[[^\\]]*\\]|[{}.|!><^$])")
	for k in rows.size():
		if skip_first and k == 0:
			continue
		var r: Array = rows[k]
		var t := esc.sub(col.sub(XMVText.convert_escapes(str(r[0])), "　　", true), "", true).strip_edges()
		if t == "":
			continue
		var c := XHelpCard._css(str(r[2])) if r.size() > 2 else XUiSkin.TEXT_2
		if c.get_luminance() < 0.35:
			c = XUiSkin.TEXT_2
		if not XUiSkin.CORE_V2:
			out.append({"text": t, "color": c})
			continue
		# 收口批：一格里换行连着的几句（如「武器种类:书」＋说明）拆开逐句判，别整格丢掉
		for line in t.split("\n", false):
			var lt := str(line).strip_edges()
			if lt != "" and not drop_help_row(lt):
				out.append({"text": lt, "color": XUiSkin.legacy_color(c)})
	return out


## 收口批（CORE_V2）：牌上不再列的说明行——品质（名字颜色和小字已有）、武器／防具种类（小字已有）、买卖价格（只在商店看）
static func drop_help_row(t: String) -> bool:
	return RegEx.create_from_string("^(?:品质|武器种类|防具种类|装备类型|类别)\\s*[：:]|^(?:购买价格|出售价格|无法出售)").search(t) != null


## 收口批（CORE_V2）：装备说明按样稿分节——自带（「名：数」的基础属性）、词条（特效／效果／成长／异化等）、套装、说明（其余）。
## rows 是 help_rows 的结果。CORE_V2 关时原样一节无标题（同旧）。
static func help_sections(rows: Array) -> Array:
	if not XUiSkin.CORE_V2:
		return [{"title": "", "rows": rows}]
	var base_re := RegEx.create_from_string("^[^：:，。]{1,10}[：:]\\s*[+\\-]?\\d[\\d.,%％]*(?:\\s|　|$)|^[^：:，。\\s]{2,8}[+\\-]\\d[\\d.%％]*$")
	var affix_re := RegEx.create_from_string("^(?:特效|效果|词条|成长|异化|吸取|专武|被动|◆|●|★|【)")
	var set_re := RegEx.create_from_string("套装|^\\d\\s*件[：:]|\\(\\d/\\d\\)|（\\d/\\d）")
	var buckets := {"自带": [], "词条": [], "套装": [], "说明": []}
	for r in rows:
		var t := str(r.get("text", ""))
		if set_re.search(t) != null:
			buckets["套装"].append(r)
		elif affix_re.search(t) != null:
			buckets["词条"].append(r)
		elif base_re.search(t) != null:
			buckets["自带"].append(r)
		else:
			buckets["说明"].append(r)
	var out := []
	for k in ["自带", "词条", "套装", "说明"]:
		if not (buckets[k] as Array).is_empty():
			out.append({"title": k, "rows": buckets[k]})
	return out
