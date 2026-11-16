class_name XListPager
extends Control
## 【cc·天启篇·T049·未经审查】通用翻页件：「‹  第 a / b 页  ›」，两个触屏拇指够得着的按钮（56×本件高，默认 40），超过一页才显示。
## 只管「画＋点」，不管列表怎么滚：owner 每次列表变了调 set_state(top, per, total)（单位随便：行或项，三个数同单位即可），
## 点按钮发 page_step(-1 或 +1)，由 owner 自己翻（新皮肤列表见 XSkinList.page()，旧 MV 画布页见各页的 _page(d)）。
## 页码口径：第 a 页＝top 所在页（末页 top 被夹到 total−per，所以到了底一定算末页）。
## 点击只认鼠标左键（触屏被引擎模拟成鼠标）；按下在钮上、松手还在同一个钮上才翻（同 XSkinBackButton）。键盘不经过它。

signal page_step(d: int)

const BW := 56.0
const DEFAULT_SIZE := Vector2(240, 40)

var page := 1
var pages := 1
var _down := 0   # 按着哪个钮：-1 左、1 右、0 没有


func _init() -> void:
	name = "ListPager"
	size = DEFAULT_SIZE
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


static func pages_of(total: int, per: int) -> int:
	return maxi(ceili(total / float(maxi(per, 1))), 1)


static func page_of(top: int, per: int, total: int) -> int:
	var n := pages_of(total, per)
	if top + per >= total:
		return n
	return mini(ceili(top / float(maxi(per, 1))) + 1, n)


## 第 page 页该把 top 放哪（末页夹到 total−per，不留空行）
static func top_of(p: int, per: int, total: int) -> int:
	return clampi((p - 1) * per, 0, maxi(total - per, 0))


## ---- 旧 MV 画布页（图鉴等）接法 ----
## 这些页的窗口排满整屏、行数是按原版版面算死的，底边没有空地。天启篇新界面开着、列表又超过一页时，
## 列表少放一行（rows_for），腾出底边一条给翻页件；列表不超一页或新界面关着（西游档）时行数、版面一行不变。
static func rows_for(base: int, total: int) -> int:
	return base - 1 if XUiSkin.on() and total > base else base


## 挂到窗口 win 的底边中间（窗口本地坐标），点按钮发 step.call(d)；新界面关着返回 null（页面判空）。
static func attach(win: Control, step: Callable) -> XListPager:
	if not XUiSkin.on():
		return null
	var p := XListPager.new()
	p.size = Vector2(minf(DEFAULT_SIZE.x, win.size.x - 16.0), DEFAULT_SIZE.y)
	p.position = Vector2((win.size.x - p.size.x) / 2.0, win.size.y - XMVWindow.PADDING - 32.0)
	win.add_child(p)
	p.page_step.connect(step)
	return p


## 重新进页时选中项在 index：把它所在那页翻出来（页首对齐；末页夹到不留空行）
static func top_for_index(index: int, per: int, total: int) -> int:
	return top_of(floori(maxi(index, 0) / float(maxi(per, 1))) + 1, per, total)


func set_state(top: int, per: int, total: int) -> void:
	var np := pages_of(total, per)
	var cp := page_of(top, per, total)
	if np == pages and cp == page and visible == (np > 1):
		return
	pages = np
	page = cp
	visible = pages > 1
	queue_redraw()


## 左钮、右钮的矩形（测试和 owner 摆位都用）
func button_rect(side: int) -> Rect2:
	return Rect2(0 if side < 0 else size.x - BW, 0, BW, size.y)


func _side_at(p: Vector2) -> int:
	if button_rect(-1).has_point(p):
		return -1
	if button_rect(1).has_point(p):
		return 1
	return 0


func _enabled(side: int) -> bool:
	return page > 1 if side < 0 else page < pages


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	var side := _side_at(event.position)
	if event.pressed:
		_down = side if side != 0 and _enabled(side) else 0
	else:
		var d := _down
		_down = 0
		if d != 0 and d == side:
			page_step.emit(d)
	queue_redraw()


func _draw() -> void:
	var body := XUiSkin.font("body")
	var label := "第 %d / %d 页" % [page, pages]
	var fs := XUiSkin.FS_AUX
	var lw := body.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(body, Vector2((size.x - lw) / 2.0, size.y / 2.0 + fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_2)
	for side in [-1, 1]:
		var r := button_rect(side).grow(-3)
		var on := _enabled(side)
		var pressed: bool = _down == side
		draw_rect(r, Color(XUiSkin.SEL_LINE, 0.25) if pressed else Color(1, 1, 1, 0.06 if on else 0.02))
		draw_rect(r, Color(XUiSkin.GOLD, 0.7) if on else Color(XUiSkin.LINE, 0.35), false, 1.5)
		var c := r.get_center()
		var k := float(side)
		var col := Color(XUiSkin.SEL_LINE) if pressed else (Color(XUiSkin.GOLD, 0.95) if on else Color(XUiSkin.TEXT_3, 0.6))
		draw_polyline(PackedVector2Array([Vector2(c.x - 5 * k, c.y - 10), Vector2(c.x + 5 * k, c.y), Vector2(c.x - 5 * k, c.y + 10)]), col, 3.0, true)
