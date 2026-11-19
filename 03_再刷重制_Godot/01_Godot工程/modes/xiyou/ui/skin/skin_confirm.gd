class_name XSkinConfirm
extends Control
## 【cc·天启篇·未经审查】T283 通用小件「统一确认弹窗」（T254 3.0「弹窗」「统一确认弹窗」）：
## 整屏压暗 66%，正中一块弹窗面板（宽 480，比普通面板亮一档：#26252c→#16151a），标题 26 号一句、后果一句 17 号 TEXT_2、底下一排按钮。
## - danger＝找不回来的操作（卖掉、覆盖、删除、分解…）：橙色 1.5px 边（DOWN），光标默认停在「取消」（最后一枚）；
##   普通确认：灰边，光标默认停在第一枚（「确定」）。
## - 按钮 2～3 枚：[{text, disabled}]（或直接给字）；约定最后一枚是「取消」。
## - 按键：左右（上下也认）换钮，确定＝chosen(序号)（禁用的钮蜂鸣、不发），取消＝cancelled。
##   点钮：点非当前钮＝选中，点当前钮＝确定（同列表）；点弹窗外不算取消（免得误触）。
## - 本件不响音：音由页面照原来的逻辑响（商店确认窗的确定／取消音照旧）。
## 两种用法：
##   1) 自己管：var dlg := XSkinConfirm.open(page, {"title": "卖掉这一档？", "body": "会卖掉 14 件，得 4,200", "buttons": ["确认出售", "取消"], "danger": true})
##      dlg.chosen.connect(func(i): …; dlg.close())；dlg.cancelled.connect(dlg.close)；页面按键先 if dlg.handle_input(event): return
##   2) 页面有自己的状态（商店 _confirm）：每次重画 setup(同样的字典＋"index": 现在的钮)，chosen／index_changed 里写回状态。

signal chosen(index: int)
signal index_changed(index: int)
signal cancelled

const W := 480.0
const DIM := 0.66
const DLG_TOP := Color("26252c")
const DLG_LOW := Color("16151a")
const TITLE_FS := 26
const BODY_FS := 17
const BTN_H := 46.0
const PAD := 24.0

var title := ""
var body := ""
## [{text, disabled}]
var buttons: Array = []
var danger := false
var index := 0
var width := W
var _press := -1


## 建在 parent 上（铺满）并 setup；返回本件
static func open(parent: Control, d: Dictionary) -> XSkinConfirm:
	var c := XSkinConfirm.new()
	parent.add_child(c)
	c.setup(d)
	return c


func _init() -> void:
	name = "SkinConfirm"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## d：{title, body, buttons, danger, index（不给按 danger 定：危险停最后一枚，否则第一枚）, width}
func setup(d: Dictionary) -> XSkinConfirm:
	title = str(d.get("title", ""))
	body = str(d.get("body", ""))
	danger = bool(d.get("danger", false))
	width = float(d.get("width", W))
	buttons = (d.get("buttons", []) as Array).map(func(b): return b if b is Dictionary else {"text": str(b)})
	index = clampi(int(d.get("index", default_index())), 0, maxi(buttons.size() - 1, 0))
	queue_redraw()
	return self


## 默认停哪一枚：危险操作停「取消」（最后一枚），普通停第一枚
func default_index() -> int:
	return maxi(buttons.size() - 1, 0) if danger else 0


func close() -> void:
	queue_free()


func select(i: int) -> void:
	i = clampi(i, 0, maxi(buttons.size() - 1, 0))
	if i != index:
		index = i
		index_changed.emit(i)
	queue_redraw()


## 用掉了返回 true（弹窗开着时什么键都吞，免得穿到底下的页面）
func handle_input(event: InputEvent) -> bool:
	if not (event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return false
	if event.is_action_pressed("ui_cancel"):
		cancelled.emit()
		return true
	if event.is_action_pressed("ui_accept"):
		activate(index)
		return true
	var d := 0
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_up", true):
		d = -1
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_down", true):
		d = 1
	if d != 0 and not buttons.is_empty():
		select(posmod(index + d, buttons.size()))
	return event.is_pressed()


## 按下第 i 枚：禁用的不发（页面自己蜂鸣）
func activate(i: int) -> void:
	if i < 0 or i >= buttons.size():
		return
	chosen.emit(i)


func is_disabled(i: int) -> bool:
	return i >= 0 and i < buttons.size() and bool(buttons[i].get("disabled", false))


# ---- 摆位 ----

func panel_rect() -> Rect2:
	var f := XUiSkin.font("body")
	var w := minf(width, size.x - 32.0)
	var inner := w - PAD * 2
	var h := PAD
	h += _lines(XUiSkin.font("title"), title, inner, XUiSkin.fs(TITLE_FS)) * roundf(XUiSkin.fs(TITLE_FS) * 1.3)
	if body != "":
		h += 10.0 + _lines(f, body, inner, XUiSkin.fs(BODY_FS)) * roundf(XUiSkin.fs(BODY_FS) * 1.5)
	h += 24.0 + BTN_H + PAD
	return Rect2((size.x - w) / 2.0, (size.y - h) / 2.0, w, h)


func button_rect(i: int) -> Rect2:
	var p := panel_rect()
	var n := maxi(buttons.size(), 1)
	var bw := (p.size.x - PAD * 2 - XUiSkin.GRID * (n - 1)) / n
	return Rect2(p.position.x + PAD + i * (bw + XUiSkin.GRID), p.end.y - PAD - BTN_H, bw, BTN_H)


static func _lines(f: Font, text: String, w: float, fs: int) -> int:
	if text == "":
		return 0
	var para := TextParagraph.new()
	para.width = w
	para.add_string(text, f, fs)
	return maxi(1, para.get_line_count())


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	if event.pressed:
		_press = -1
		for i in buttons.size():
			if button_rect(i).has_point(event.position):
				_press = i
		queue_redraw()
		return
	var hit := -1
	for i in buttons.size():
		if button_rect(i).has_point(event.position):
			hit = i
	var was := _press
	_press = -1
	queue_redraw()
	if hit < 0 or hit != was:
		return
	if hit == index:
		activate(hit)
	else:
		select(hit)


# ---- 画 ----

func _draw() -> void:
	var ci := get_canvas_item()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, DIM))
	var p := panel_rect()
	XUiSkin.shadow_style().draw(ci, p)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(XUiSkin.RADIUS)
	sb.anti_aliasing = true
	sb.bg_color = DLG_LOW
	sb.draw(ci, p)
	# 上亮下暗：上半再叠一层渐亮（StyleBoxFlat 没有渐变）
	var g := StyleBoxFlat.new()
	g.set_corner_radius_all(XUiSkin.RADIUS)
	g.corner_radius_bottom_left = 0
	g.corner_radius_bottom_right = 0
	g.bg_color = Color(DLG_TOP, 0.85)
	g.draw(ci, Rect2(p.position, Vector2(p.size.x, p.size.y * 0.45)))
	var edge := StyleBoxFlat.new()
	edge.draw_center = false
	edge.set_corner_radius_all(XUiSkin.RADIUS)
	edge.anti_aliasing = true
	edge.border_color = Color(XUiSkin.DOWN, 0.8) if danger else Color(XUiSkin.LINE, 0.55)
	edge.set_border_width_all(2 if danger else 1)   # 1.5px：整数线宽里取 2、略压透明度
	edge.draw(ci, p)
	var head := XUiSkin.font("title")
	var f := XUiSkin.font("body")
	var inner := p.size.x - PAD * 2
	var y := p.position.y + PAD
	var tfs := XUiSkin.fs(TITLE_FS)
	y = _para(head, title, Vector2(p.position.x + PAD, y), inner, tfs, roundf(tfs * 1.3), XUiSkin.TEXT)
	if body != "":
		y += 10.0
		var bfs := XUiSkin.fs(BODY_FS)
		_para(f, body, Vector2(p.position.x + PAD, y), inner, bfs, roundf(bfs * 1.5), XUiSkin.TEXT_2)
	for i in buttons.size():
		var r := button_rect(i)
		var b: Dictionary = buttons[i]
		var dis := bool(b.get("disabled", false))
		var bs := StyleBoxFlat.new()
		bs.set_corner_radius_all(int(BTN_H / 2.0))
		bs.anti_aliasing = true
		if i == index and not dis:
			XUiSkin.primary_button_style(bs, true)
		else:
			bs.bg_color = Color(0, 0, 0, 0.25 if _press != i else 0.5)
			bs.border_color = Color(XUiSkin.LINE, 0.55)
			bs.set_border_width_all(1)
		bs.draw(ci, r)
		if i == index:
			XUiSkin.draw_select(ci, r.grow(3), XUiSkin.breath_alpha())
		var t := str(b.get("text", ""))
		var fs := XUiSkin.FS_LIST
		var fit := XSkinList.fit_text(f, t, r.size.x - 16.0, fs, 15)
		var tw := f.get_string_size(str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1])).x
		XUiSkin.ds(self, f, Vector2(r.position.x + (r.size.x - tw) / 2.0, r.position.y + r.size.y / 2.0 + int(fit[1]) * 0.36), str(fit[0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1]), XUiSkin.TEXT_3 if dis else XUiSkin.TEXT)


func _para(f: Font, text: String, at: Vector2, w: float, fs: int, lh: float, col: Color) -> float:
	if text == "":
		return at.y
	var para := TextParagraph.new()
	para.width = w
	para.add_string(text, f, fs)
	var y := at.y
	for li in para.get_line_count():
		var rg := para.get_line_range(li)
		XUiSkin.ds(self, f, Vector2(at.x, y + fs * 1.0), text.substr(rg.x, rg.y - rg.x), HORIZONTAL_ALIGNMENT_LEFT, w, fs, col)
		y += lh
	return y
