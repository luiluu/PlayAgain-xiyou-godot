class_name XBattleList
extends XMVWindow
## 战斗中的指令窗与技能/物品列表（Olivia_SideBattleUI 缩放 0.8：行高 29、字号 21、内边距 11、文字边距 5、图标 26）。
## - 指令窗 Window_ActorCommand：宽 220，行数 = 指令数（最多 16），文字居中（YEP Command Alignment center）。
## - 技能/物品 Window_BattleSkill / Window_BattleItem：宽 450，单列，行数 = 项数（最多 16）。
##   每行：itemRect 宽减文字边距；图标 (2,2) 26px、名字从 30 起（宽减 reserve 的字宽：技能「000」，物品「×0,000」）；右侧按 YEP 画消耗：
##   每段先在最右画 26px 图标（x = 宽 − 32）、再在剩余宽度里右对齐写字（字号 20），段间留 5。
##   不能用的行半透明（160/255）。
## 操作照 Window_Selectable：上下（按下时首尾相接）、PageUp/Down（还有下一页／上一页才翻，全部放得下时不动）、确定/取消；
## 点选中行确定、点别的行先选中；滚轮；右键取消。
## entries：[{text, enabled, icon, reserve, costs: [{text, color, icon, size}]}]

signal chosen(index: int)
signal cancelled
signal index_changed(index: int)

const LH := 29.0
const FS := 21
const PAD := 11.0
const TPAD := 5.0
const ICON := 26.0
const MAX_ROWS := 16

var entries: Array = []
var index := 0
var top := 0
var rows := 1
var align := "left"
var active := true
var cancel_enabled := true


static func create(parent: Control, list: Array, width: float, text_align := "left") -> XBattleList:
	var w := XBattleList.new()
	w.entries = list
	w.align = text_align
	w.rows = clampi(list.size(), 0, MAX_ROWS)
	w.padding = PAD
	w.size = Vector2(width, w.rows * LH + PAD * 2)
	parent.add_child(w)
	w.canvas.painter = w._paint
	w.canvas.blink = true
	w.select(0)
	return w


func select(i: int) -> void:
	index = clampi(i, -1, entries.size() - 1)
	if index >= 0:
		if index < top:
			top = index
		elif index >= top + rows:
			top = index - rows + 1
	up_arrow = top > 0
	down_arrow = top < entries.size() - rows
	refresh()
	index_changed.emit(index)


## Olivia correctScreenPosition：不超出画面右/下边
func place(x: float, y: float, screen := Vector2(1280, 720)) -> void:
	position = Vector2(minf(screen.x - size.x, x), minf(screen.y - size.y, y))


func current_enabled() -> bool:
	return index >= 0 and index < entries.size() and bool(entries[index].get("enabled", true))


func _paint(c: XMVCanvas) -> void:
	var cw := c.size.x
	for i in range(top, mini(top + rows, entries.size())):
		var y := (i - top) * LH
		if i == index:
			c.cursor(Rect2(0, y, cw, LH), active)
		var e: Dictionary = entries[i]
		var alpha := 1.0 if bool(e.get("enabled", true)) else XUI.DIM.a
		if align == "center":
			c.text(str(e.text), TPAD, y, cw - TPAD * 2, "center", XUI.TEXT, FS, LH, alpha)
			continue
		var w := cw - TPAD
		var name_w := w - c.text_width(str(e.get("reserve", "000")), FS)
		var x := 0.0
		if int(e.get("icon", 0)) > 0:
			c.icon(int(e.icon), x + 2, y + 2, alpha, ICON)
		var ibox := ICON + 4
		c.text(str(e.text), x + ibox, y, name_w - ibox, "left", e.get("color", XUI.TEXT), FS, LH, alpha)
		var dw := w
		for cost in e.get("costs", []):
			if int(cost.get("icon", 0)) > 0:
				c.icon(int(cost.icon), x + dw - 32, y + 2, alpha, ICON)
				dw -= 32 + 2
			var fs := int(cost.get("size", 20))
			c.text(str(cost.text), x, y, dw, "right", cost.get("color", XUI.TEXT), fs, LH, alpha)
			dw -= c.text_width(str(cost.text), fs) + 5


## Window_Selectable.cursorPagedown／cursorPageup：顶行 + 页行数 < 总行数（上翻：顶行 > 0）才翻一页，
## 顶行收在 0～最大顶行，光标跟着移一页（收在首末项）；否则什么都不做
func page(d: int) -> void:
	var n := entries.size()
	if d > 0 and top + rows < n:
		top = mini(top + rows, maxi(0, n - rows))
		select(mini(index + rows, n - 1))
	elif d < 0 and top > 0:
		top = maxi(top - rows, 0)
		select(maxi(index - rows, 0))


## Window_Selectable.processWheel：只滚动显示，不移动光标
func _scroll(d: int) -> void:
	top = clampi(top + d, 0, maxi(0, entries.size() - rows))
	up_arrow = top > 0
	down_arrow = top < entries.size() - rows
	refresh()


func _hit(p: Vector2) -> int:
	var local := p - position - Vector2(padding, padding)
	if local.x < 0 or local.x >= size.x - padding * 2 or local.y < 0 or local.y >= rows * LH:
		return -1
	var i := top + floori(local.y / LH)
	return i if i < entries.size() else -1


func _ok() -> void:
	if current_enabled():
		XSound.system(1)
		chosen.emit(index)
	else:
		XSound.system(3)


func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	var n := entries.size()
	var handled := true
	var last := index
	if event.is_action_pressed("ui_down", true) and n > 0:
		if index < n - 1 or not event.is_echo():
			select((index + 1) % n)
	elif event.is_action_pressed("ui_up", true) and n > 0:
		if index > 0 or not event.is_echo():
			select((index - 1 + n) % n)
	elif event.is_action_pressed("ui_page_down") and n > 0:
		page(1)
	elif event.is_action_pressed("ui_page_up") and n > 0:
		page(-1)
	elif event.is_action_pressed("ui_accept", true):
		_ok()
	elif event.is_action_pressed("ui_cancel", true):
		if cancel_enabled:
			XSound.system(2)
			cancelled.emit()
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				var hit := _hit(mb.position)
				if hit < 0:
					handled = false
				elif hit == index:
					_ok()
				else:
					select(hit)
			MOUSE_BUTTON_RIGHT:
				if cancel_enabled:
					XSound.system(2)
					cancelled.emit()
			MOUSE_BUTTON_WHEEL_DOWN:
				_scroll(1)
			MOUSE_BUTTON_WHEEL_UP:
				_scroll(-1)
			_:
				handled = false
	else:
		handled = false
	if index != last:
		XSound.system(0)
	if handled:
		get_viewport().set_input_as_handled()
