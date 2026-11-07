class_name XGearDetail
extends RefCounted
## 【cc·界面·未经审查】装备页／物品页右侧的装备详情（跟到 v0.62.12：installEquipmentDetailV041Runtime 的 CodexEquipment41.Detail，
## 被 installPanelLayoutV043Runtime 改写过 rows41／render41／nav41）。装备页（XEquipScene）和物品页（XItemScene）共用。
## 参照：ui_reference/review_system_pages.js 的 equip_detail／item_detail 两页（新源实跑截图＋读数，tests/fixtures/gear_detail_oracle.json）。
## 三个窗口，都占原来右下那块（装备页 (640,173,640,547)，物品页信息窗 (640,172,640,548)）：
## - 页签条 Window_Help(1)：顶上 58 高，「【装备详情】　属性对比　插槽与镶嵌」（物品页没有属性对比），26 号，x 6。
## - 详情（Window_Base）：页签条下面到翻页条上面（高＝总高−116）。
## - 翻页条 Window_Help(1)：底下 58 高；只有一页时空着，多页时三栏 20 号「▲ 上一页」「p／n」「下一页 ▼」，
##   第一页的「上一页」、最后一页的「下一页」半透明。
## 详情内容（rows41）：
## - 装备详情：XHelpCard.detail_rows（getDescParams＋星级名＋P.view 排版，宽＝内容宽 612）；没选装备时「选择左侧装备，查看完整信息。」（20 号白）。
## - 插槽与镶嵌：星级名（#ffe499）、「宝珠插槽：N个」、每个孔「n．类型：宝珠名／空槽」、「符文镶嵌：剩余 N 孔」、每条镶嵌记录「n．\i[图标]名字」
##   （没有时「尚无符文镶嵌记录。」）、「镶嵌操作可在物品菜单选择这件装备。」（#9cceff），都是 20 号。
## 排版（render43）：每行按自己的字号排，行高＝该行文字高（不另加行距）；先量每行再分页：放不下的行整行挪到下一页顶上，
## 挪到页顶的空白分隔行直接去掉；多页时内容总高＝页数×页高，一页时＝实际高。换装备或换页签回第一页。
## 翻页（turn41）：到第 p 页的顶（不超过最后一屏）；滚动（scroll41：滚轮、拖动）按像素，滚完按位置认当前页（syncPage43：
## 滚到底算最后一页，否则取顶不超过当前位置＋2 的最后一页）。
## 字号沿用说明卡的 O-007（XHelpCard.MIN_FONT，分隔行除外），设 0 回到原版。

const BAR_H := 58.0
const NAV_SIZE := 20
const TAB_SIZE := 26
const HINT := "选择左侧装备，查看完整信息。"
const ROW_SIZE := 20
const STAR_COLOR := "#ffe499"
const NOTE_COLOR := "#9cceff"
## 滚轮一格滚动的像素（MV TouchInput.wheelY 取 wheel 事件的 deltaY，Chrome 一格 100）
const WHEEL_STEP := 100.0
const DRAG_MIN := 6.0

var tabs: XMVWindow
var detail: XMVWindow
var nav: XMVWindow
var labels: Array = ["装备详情", "属性对比", "插槽与镶嵌"]
var modes: Array = [0, 1, 2]       # 页签对应的 mode（物品页 [0, 2]）
var mode := 0
var item: Dictionary = {}
var key := "<未排版>"             # 初值不同于任何内容，第一次 set_item 一定排版
var rows: Array = []
var page := 0
var pages := 1
var tops: Array = []               # 每页的顶（像素）
var full_h := 0.0
var origin_y := 0.0
var _placed: Array = []            # [{glyphs, top, base}]：每行画在哪
var rows_override: Array = []     # 测试用：给定行代替 content_rows()
var _drag_y := NAN
var _drag_moved := false


## area：右下整块（页签条＋详情＋翻页条）
func _init(parent: Control, area: Rect2, opacity: int, tab_labels := ["装备详情", "属性对比", "插槽与镶嵌"], tab_modes := [0, 1, 2]) -> void:
	labels = tab_labels
	modes = tab_modes
	tabs = XMVWindow.make(parent, Rect2(area.position, Vector2(area.size.x, BAR_H)), opacity, _paint_tabs)
	detail = XMVWindow.make(parent, body_rect(area), opacity, _paint_detail)
	nav = XMVWindow.make(parent, Rect2(area.position.x, area.end.y - BAR_H, area.size.x, BAR_H), opacity, _paint_nav)


static func body_rect(area: Rect2) -> Rect2:
	return Rect2(area.position.x, area.position.y + BAR_H, area.size.x, maxf(120.0, area.size.y - BAR_H * 2))


func set_visible(on: bool) -> void:
	tabs.visible = on
	detail.visible = on and mode != 1
	nav.visible = on and mode != 1


func is_shown() -> bool:
	return tabs.visible


## setEquipment：内容变了才重排（编号、备注、属性、宝珠、镶嵌记录）
func set_item(e: Dictionary) -> void:
	var k := "" if e.is_empty() else "%s:%s:%s:%s:%s:%s" % [str(e.get("instanceId", e.get("id", ""))), str(e.get("note", "")),
		JSON.stringify(e.get("params", [])), JSON.stringify(e.get("augmentSlotItems", [])), JSON.stringify(e.get("upgrades", [])),
		str(e.get("upgradeSlots", ""))]
	if k == key:
		return
	key = k
	item = e
	render()


func set_mode(m: int) -> void:
	mode = m
	render()
	tabs.refresh()
	set_visible(tabs.visible)


## chooseDetail41(n)：n 按页签序号，首尾相接
func choose(index: int) -> void:
	var n := modes.size()
	set_mode(int(modes[((index % n) + n) % n]))


func tab_index() -> int:
	return maxi(0, modes.find(mode))


func tab_text() -> String:
	var parts := []
	for i in labels.size():
		parts.append("【%s】" % labels[i] if int(modes[i]) == mode else str(labels[i]))
	return "　".join(parts)


# ---- 内容 ----
func content_rows() -> Array:
	if not rows_override.is_empty():
		return rows_override
	var cw := detail.canvas.size.x
	if item.is_empty():
		return [[HINT, ROW_SIZE, "#ffffff", false, 0]]
	if mode == 2:
		return socket_rows(item)
	return XHelpCard.detail_rows(item, cw)


## v0.41 rows41 的 mode 2（v0.43 去掉末行「说明较长时，在右侧上下滑动查看。」）
static func socket_rows(e: Dictionary) -> Array:
	var out := [[XGearSearch.star_name(e), ROW_SIZE, STAR_COLOR, false, 0]]
	var slots: Array = e.get("augmentSlots", [])
	out.append(["宝珠插槽：%d个" % slots.size(), ROW_SIZE, "#ffffff", false, 0])
	for n in slots.size():
		var gem := XOrbs.gem_in_slot(e, n)
		out.append(["%d．%s：%s" % [n + 1, str(slots[n]), str(gem.get("name", "")) if not gem.is_empty() else "空槽"], ROW_SIZE, "#ffffff", false, 0])
	out.append(["符文镶嵌：剩余 %d 孔" % maxi(0, int(e.get("upgradeSlots", 0))), ROW_SIZE, "#ffffff", false, 0])
	var history: Array = e.get("upgrades", [])
	for n in history.size():
		var mat := XDB.rec("Items", int(history[n].get("item", 0)))
		out.append(["%d．\\i[%d]%s" % [n + 1, int(mat.get("iconIndex", 0)), str(history[n].get("name", mat.get("name", "")))], ROW_SIZE, "#ffffff", false, 0])
	if history.is_empty():
		out.append(["尚无符文镶嵌记录。", ROW_SIZE, "#ffffff", false, 0])
	out.append(["镶嵌操作可在物品菜单选择这件装备。", ROW_SIZE, NOTE_COLOR, false, 0])
	return out


## render43
func render() -> void:
	rows = content_rows()
	var cw := detail.canvas.size.x
	var view_h := detail.canvas.size.y
	var sized := []
	for r in rows:
		var rr: Array = (r as Array).duplicate()
		if str(rr[0]) != " ":
			rr[1] = maxi(int(rr[1]), XHelpCard.MIN_FONT)
		sized.append(rr)
	var lay := XHelpCard.layout(sized, 0, cw + XHelpCard.PAD * 2)
	_placed = []
	tops = [0.0]
	var y := 0.0
	var pg := 0.0
	for k in lay.lines.size():
		var line: Dictionary = lay.lines[k]
		var h: float = line.h
		if y > pg and y + h > pg + view_h:
			pg += view_h
			y = pg
			tops.append(pg)
			if str(sized[k][0]) == " ":
				continue
		_placed.append({"glyphs": line.glyphs, "top": y, "base": float(line.y)})
		y += h
	pages = tops.size()
	full_h = pages * view_h if pages > 1 else maxf(1.0, y)
	page = 0
	origin_y = 0.0
	detail.refresh()
	nav.refresh()


func max_scroll() -> float:
	return maxf(0.0, full_h - detail.canvas.size.y)


func _sync_page() -> void:
	var p := 0
	if origin_y >= max_scroll() - 1.0:
		p = tops.size() - 1
	else:
		for i in tops.size():
			if float(tops[i]) <= origin_y + 2.0:
				p = i
	page = p


func scroll(d: float) -> void:
	origin_y = clampf(origin_y + d, 0.0, max_scroll())
	_sync_page()
	detail.refresh()
	nav.refresh()


func turn(d: int) -> void:
	page = clampi(page + d, 0, tops.size() - 1)
	origin_y = minf(max_scroll(), float(tops[page]))
	detail.refresh()
	nav.refresh()


# ---- 绘制 ----
func _paint_tabs(c: XMVCanvas) -> void:
	c.text(tab_text(), 6, 0, c.size.x - 6, "left", XUI.TEXT, TAB_SIZE, XUI.LINE_HEIGHT)


func _paint_detail(c: XMVCanvas) -> void:
	var ch := c.size.y
	for p in _placed:
		var dy: float = p.top - p.base - origin_y
		for g in p.glyphs:
			var y: float = g.y + dy
			if y > ch or y + 48.0 < 0.0:
				continue
			if g.has("icon"):
				c.icon(int(g.icon), g.x - XHelpCard.PAD, y)
			else:
				c.text(g.t, g.x - XHelpCard.PAD, y, g.w * 2.0 if g.lh != 36.0 else g.w + 2, "left", g.color, g.size, g.lh)


## nav41（v0.43）：一页时空着
func _paint_nav(c: XMVCanvas) -> void:
	if pages <= 1:
		return
	var w := c.size.x
	var h := c.size.y
	var dim := 160.0 / 255.0
	c.text("▲ 上一页", 0, 0, w / 3.0, "left", XUI.TEXT, NAV_SIZE, h, 1.0 if page > 0 else dim)
	c.text("%d／%d" % [page + 1, pages], w / 3.0, 0, w / 3.0, "center", XUI.TEXT, NAV_SIZE, h)
	c.text("下一页 ▼", w * 2.0 / 3.0, 0, w / 3.0, "right", XUI.TEXT, NAV_SIZE, h, 1.0 if page < pages - 1 else dim)


# ---- 鼠标 ----
## 处理落在右侧三块上的鼠标事件，处理了返回 true。
## 页签条：按横坐标选页签；翻页条：左半上一页、右半下一页；详情：滚轮滚动、按下拖动（只动显示位置，不改选中）。
func mouse(event: InputEvent) -> bool:
	if not is_shown():
		return false
	if event is InputEventMouseMotion:
		if is_nan(_drag_y):
			return false
		var dy: float = event.position.y - _drag_y
		if not _drag_moved and absf(dy) < DRAG_MIN:
			return true
		_drag_moved = true
		scroll(-dy)
		_drag_y = event.position.y
		return true
	var b := event as InputEventMouseButton
	if b == null:
		return false
	var p := b.position
	if b.button_index == MOUSE_BUTTON_LEFT and not b.pressed:
		var had := not is_nan(_drag_y)
		_drag_y = NAN
		return had
	if not b.pressed:
		return false
	var tr := Rect2(tabs.position, tabs.size)
	if b.button_index == MOUSE_BUTTON_LEFT and tr.has_point(p):
		choose(mini(modes.size() - 1, floori((p.x - tr.position.x) * modes.size() / tr.size.x)))
		return true
	if mode == 1:
		return false
	var nr := Rect2(nav.position, nav.size)
	var dr := Rect2(detail.position, detail.size)
	if b.button_index == MOUSE_BUTTON_LEFT and nr.has_point(p):
		turn(-1 if p.x < nr.position.x + nr.size.x / 2.0 else 1)
		return true
	if dr.has_point(p):
		if b.button_index == MOUSE_BUTTON_WHEEL_DOWN or b.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll(WHEEL_STEP * (b.factor if b.factor > 0.0 else 1.0) * (1.0 if b.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0))
			return true
		if b.button_index == MOUSE_BUTTON_LEFT:
			_drag_y = p.y
			_drag_moved = false
			return true
	return false
