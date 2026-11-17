class_name XSkinGearDetail
extends Control
## 【cc·天启篇·未经审查】装备详情部件新皮肤（盘点清册 #24；旧的是 XGearDetail 三个旧窗口）：装备页按 Y 展开「全部属性与词条」时用，
## 盖在中、右两块上。黑面板里从上往下：图标＋名字（品质色）＋品质 · 类型；三个页签「装备详情／属性对比／插槽与镶嵌」（当前页红乙选中条）；
## 下面是可滚动的内容（超出时右侧细滚动条）：
## - 装备详情：说明卡的全部行（XHelpCard.detail_rows，同旧详情页；去转义码、颜色照说明卡）；
## - 属性对比：八项能力值「当前 → 换上后 ▲差」（没选候选时只写当前值；同旧属性对比页的数）；
## - 插槽与镶嵌：同旧插槽页（XGearDetail.socket_rows）。
## 按键：左右换页签（首尾相接）、上下滚动；鼠标点页签、滚轮滚动。数据只读，不改装备。

signal tab_changed(index: int)

const TABS := ["装备详情", "属性对比", "插槽与镶嵌"]
const HEAD_H := 64.0
const TAB_H := 40.0
const STEP := 48.0
const ROW_H := 36.0

var tab := 0
var item: Dictionary = {}
var actor: XActor
var temp: XActor
var compare := false
var scroll := 0.0
var _key := []
var _rows: Array = []        # [{text, color}]（装备详情、插槽）
var _cmp: Array = []         # [[名, 当前, 换上后（-1＝不写）]]
var body: Control
var _content_h := 0.0
## T024 选中放大：当前页签的字放大（页签宽不变，放不下先缩字）
var tab_scale: XSkinSelScale


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	body = Control.new()
	body.clip_contents = true
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.draw.connect(_draw_body)
	add_child(body)
	tab_scale = XSkinSelScale.attach(self)
	resized.connect(_place)


func _place() -> void:
	var pad := float(XUiSkin.PAD_LG)
	body.position = Vector2(pad, pad + HEAD_H + TAB_H + XUiSkin.GRID)
	body.size = Vector2(maxf(size.x - pad * 2, 1.0), maxf(size.y - body.position.y - pad, 1.0))
	queue_redraw()
	body.queue_redraw()


func reset() -> void:
	tab = 0
	scroll = 0.0


## rec：要看的装备（{}＝卸下）；a：角色；t：换上后的角色（null＝不比）；cmp：是不是在选候选
func set_data(rec: Dictionary, a: XActor, t: XActor, cmp: bool) -> void:
	var key := [rec.get("instanceId", rec.get("id", -1)), rec.hash(), a.get_instance_id() if a != null else 0, t.get_instance_id() if t != null else 0, cmp, tab]
	if key == _key:
		return
	_key = key
	item = rec
	actor = a
	temp = t
	compare = cmp
	_build()


func _build() -> void:
	_rows = []
	_cmp = []
	match tab:
		0:
			if not item.is_empty():
				_rows = XSkinTemplatePage.help_rows(XHelpCard.detail_rows(absorb_view(item), 300.0))
		1:
			var names: Array = XDB.system().get("terms", {}).get("params", [])
			if actor != null:
				if XEquipScene.CACHE_CANDIDATES:
					XActor.read_begin()
				for i in range(8):
					_cmp.append([str(names[i]) if i < names.size() else XMenu.PARAM_NAMES[i], int(actor.param(i)), int(temp.param(i)) if temp != null else -1])
				if XEquipScene.CACHE_CANDIDATES:
					XActor.read_end()
		2:
			if not item.is_empty():
				_rows = XSkinTemplatePage.help_rows(XGearDetail.socket_rows(item), false)
	_content_h = _measure()
	scroll = clampf(scroll, 0.0, max_scroll())
	queue_redraw()
	body.queue_redraw()


## 吸取过特效的专武：照说明卡（XHelpCard.show_for）用效果视图，详情里带上吸取的特效行（小A核查 P3-3）
static func absorb_view(rec: Dictionary) -> Dictionary:
	return XAffixAbsorb.view(rec) if rec.has(XAffixAbsorb.KEY) else rec


func choose(i: int) -> void:
	var n := TABS.size()
	tab = posmod(i, n)
	scroll = 0.0
	_key = []
	_build()
	tab_changed.emit(tab)


func max_scroll() -> float:
	return maxf(0.0, _content_h - body.size.y)


func scroll_by(d: float) -> void:
	scroll = clampf(scroll + d, 0.0, max_scroll())
	body.queue_redraw()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		XSound.system(0)
		choose(tab + (-1 if event.is_action("ui_left") else 1))
		return true
	if event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true):
		scroll_by(STEP * (-1.0 if event.is_action("ui_up") else 1.0))
		return true
	if event.is_action_pressed("ui_accept"):
		return true
	return false


func tab_rect(i: int) -> Rect2:
	var pad := float(XUiSkin.PAD_LG)
	var w := minf(160.0, (size.x - pad * 2) / TABS.size())
	if XSkinArt.select_on():   # 第一期正式美术：页签间留 20、第一个往右 16，外置箭头（1×，左探 15）不压前一个页签（小A核 P2-1）
		return Rect2(pad + 16.0 + i * w, pad + HEAD_H, w - 20.0, TAB_H)
	return Rect2(pad + i * w, pad + HEAD_H, w - XUiSkin.GRID, TAB_H)


var _drag := XSkinDrag.new()


func _gui_input(event: InputEvent) -> void:
	if XUiSkin.TOUCH_V2 and _drag_input(event):
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scroll_by(STEP * (-1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0))
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		for i in TABS.size():
			if tab_rect(i).has_point(mb.position):
				XSound.system(0)
				choose(i)
				accept_event()
				return


## 收口批（TOUCH_V2）：正文区手指上下拖＝像素滚动；拖过了就不再当点（页签点击照旧在按下时）
func _drag_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag.press(event.position, scroll)
			return false
		var was_drag := _drag.dragging
		_drag.release()
		if was_drag:
			accept_event()
		return was_drag
	if event is InputEventMouseMotion:
		var to := _drag.motion(event.position)
		if not is_nan(to):
			scroll_by(clampf(to, 0.0, max_scroll()) - scroll)
			accept_event()
			return true
	return false


# ---- 画 ----

func _draw() -> void:
	var ci := get_canvas_item()
	XUiSkin.shadow_style().draw(ci, Rect2(Vector2.ZERO, size))
	XUiSkin.panel_style().draw(ci, Rect2(Vector2.ZERO, size))
	var pad := float(XUiSkin.PAD_LG)
	var head := XUiSkin.font("title")
	var font := XUiSkin.font("body")
	var x := pad
	if item.is_empty():
		XUiSkin.ds(self, head, Vector2(x, pad + 34), XSkinEquipPage.remove_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_CARD, XUiSkin.TEXT)
	else:
		var d := XSkinItemPage.card_data(item)
		var tex: Texture2D = d.get("icon")
		if tex != null:
			draw_texture_rect(tex, Rect2(x, pad, 48, 48), false)
			x += 60
		var fit := XSkinList.fit_text(head, str(d.title), size.x - pad - x, XUiSkin.FS_CARD, 20)
		XUiSkin.ds(self, head, Vector2(x, pad + 26), fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1], d.title_color)
		XUiSkin.ds(self, font, Vector2(x, pad + 50), str(d.subtitle), HORIZONTAL_ALIGNMENT_LEFT, size.x - pad - x, XUiSkin.FS_AUX, XUiSkin.TEXT_2)
	tab_scale.sel(tab)
	for i in TABS.size():
		var r := tab_rect(i)
		if i == tab:
			if XSkinArt.select_on():
				XSkinArt.draw_tab(ci, r)
			else:
				XUiSkin.draw_select(ci, r, XUiSkin.breath_alpha())
		var fit := XSkinList.fit_text(font, TABS[i], r.size.x - 12, XSkinSelScale.fs(XUiSkin.FS_AUX_MAX, tab_scale.k(i), floori(r.size.y * 0.66)), XUiSkin.FS_AUX)
		var t: String = fit[0]
		var tfs: int = fit[1]
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
		XUiSkin.ds(self, font, Vector2(r.position.x + (r.size.x - tw) / 2.0, r.position.y + r.size.y / 2.0 + tfs * 0.36), t,
			HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, XUiSkin.TEXT if i == tab else XUiSkin.TEXT_2)
	var ly := pad + HEAD_H + TAB_H + 3
	draw_line(Vector2(pad, ly), Vector2(size.x - pad, ly), Color(XUiSkin.LINE, 0.14), 1.0)


func _para(text: String, w: float, fs: int) -> TextParagraph:
	var p := TextParagraph.new()
	p.width = w
	p.add_string(text, XUiSkin.font("body"), fs)
	return p


func _measure() -> float:
	var w := maxf(body.size.x - 12.0, 10.0)
	if tab == 1:
		return _cmp.size() * ROW_H
	var h := 0.0
	for r in _rows:
		h += _para(str(r.text), w, XUiSkin.FS_AUX_MAX).get_line_count() * roundf(XUiSkin.FS_AUX_MAX * 1.6)
	return h


func _draw_body() -> void:
	var font := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var w := maxf(body.size.x - 12.0, 10.0)
	var y := -scroll
	if tab == 1:
		for r in _cmp:
			if y + ROW_H >= 0 and y <= body.size.y:
				body.draw_rect(Rect2(0, y + 2, w, ROW_H - 4), Color(1, 1, 1, 0.04))
				var base := y + ROW_H / 2.0
				XUiSkin.ds(body, font, Vector2(12, base + 17 * 0.36), str(r[0]), HORIZONTAL_ALIGNMENT_LEFT, w * 0.4, 17, XUiSkin.TEXT_2)
				var before: int = r[1]
				var after: int = r[2]
				var t := XMenu._group(before)
				var col := XUiSkin.TEXT
				if compare and after >= 0 and after != before:
					var d := after - before
					t += " → %s %s%s" % [XMenu._group(after), "▲" if d > 0 else "▼", XMenu._group(absi(d))]
					col = XUiSkin.UP if d > 0 else XUiSkin.DOWN
				var tw := num.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
				XUiSkin.ds(body, num, Vector2(w - 12 - tw, base + 21 * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, col)
			y += ROW_H
	else:
		var fs := XUiSkin.FS_AUX_MAX
		var lh := roundf(fs * 1.6)
		for r in _rows:
			var text := str(r.text)
			var p := _para(text, w, fs)
			for li in p.get_line_count():
				if y + lh >= 0 and y <= body.size.y:
					var rg := p.get_line_range(li)
					XUiSkin.ds(body, font, Vector2(0, y + fs * 1.15), text.substr(rg.x, rg.y - rg.x), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, r.get("color", XUiSkin.TEXT_2))
				y += lh
		if _rows.is_empty():
			XUiSkin.ds(body, font, Vector2(0, fs * 1.15), "空" if tab == 2 or item.is_empty() else "", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_3)
	if max_scroll() > 0.0:
		var sw := 8.0 if XUiSkin.TOUCH_V2 else 4.0   # 收口批：滚动条手指找得到
		var track := Rect2(body.size.x - sw, 0, sw, body.size.y)
		body.draw_rect(track, Color(1, 1, 1, 0.06))
		var h := maxf(track.size.y * body.size.y / maxf(_content_h, 1.0), 16.0)
		body.draw_rect(Rect2(track.position.x, (track.size.y - h) * scroll / max_scroll(), sw, h), Color(XUiSkin.LINE, 0.55))
