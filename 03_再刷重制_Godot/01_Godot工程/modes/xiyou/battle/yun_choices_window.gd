class_name XYunChoicesWindow
extends XBattleList
## 【cc·白龙_11·未经审查】云裳的选择窗（installNativeYunshangRuntime.js 第 508～518 行 Window_YunChoices）：普通 Window_Command，不吃 Olivia 的 0.8 缩放。
## - 宽 min(760, 画面宽)，可见行数 min(12, max(3, 行数))（行高 36、字号 26、内边距 14、文字边距 6），每行只写名字、左对齐；
##   上方可带说明行（info：第一行系统色、第三行起半透明，下面一条 2px 分隔线；战斗里的选择都不带，天衣铺用）。
## - 窗口在画面正中；打开时光标在第一项；enabled 为假的行半透明，确定时蜂鸣。
## 操作同 XBattleList（上下首尾相接、翻页、确定、取消、点选、右键取消）。

const W := 760.0
const MLH := 36.0
const MTPAD := 6.0
const MAX_VISIBLE := 12

var info: Array = []


## rows：[{text, enabled}]
static func for_rows(parent: Control, list: Array, info_lines := []) -> XYunChoicesWindow:
	var w := XYunChoicesWindow.new()
	w.entries = list
	w.info = info_lines
	w.rows = mini(MAX_VISIBLE, maxi(3, list.size()))
	w.size = Vector2(minf(W, 1280.0), w.rows * MLH + w._info_height() + XMVWindow.PADDING * 2)
	w.position = Vector2((1280.0 - w.size.x) / 2.0, (720.0 - w.size.y) / 2.0)
	parent.add_child(w)
	w.canvas.painter = w._paint
	w.canvas.blink = true
	w.select(0)
	return w


func _info_height() -> float:
	return info.size() * MLH + 12.0 if not info.is_empty() else 0.0


func _paint(c: XMVCanvas) -> void:
	var cw := c.size.x
	for i in info.size():
		c.text(str(info[i]), 0, i * MLH, cw, "left", XUI.SYSTEM if i == 0 else XUI.TEXT, XUI.FONT_SIZE, MLH, 1.0 if i < 2 else XUI.DIM.a)
	if not info.is_empty():
		c.fill_rect(Rect2(0, info.size() * MLH + 5, cw, 2), Color(XUI.TEXT, 72.0 / 255.0))
	var oy := _info_height()
	for i in range(top, mini(top + rows, entries.size())):
		var y := oy + (i - top) * MLH
		if i == index:
			c.cursor(Rect2(0, y, cw, MLH), active)
		var alpha := 1.0 if bool(entries[i].get("enabled", true)) else XUI.DIM.a
		c.text(str(entries[i].text), MTPAD, y, cw - MTPAD * 2, "left", XUI.TEXT, XUI.FONT_SIZE, MLH, alpha)


func _hit(p: Vector2) -> int:
	var local := p - position - Vector2(padding, padding + _info_height())
	if local.x < 0 or local.x >= size.x - padding * 2 or local.y < 0 or local.y >= rows * MLH:
		return -1
	var i := top + floori(local.y / MLH)
	return i if i < entries.size() else -1
