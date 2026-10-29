class_name XAlienMimicWindow
extends XBattleList
## 异化百相切换仿形的选择窗（installAlienationWorkshop:30-34 Window_AlienMimic）：普通 Window_Command，不吃 Olivia 的 0.8 缩放。
## - 宽 380、x＝(画面宽 − 380)/2、y＝100；行数＝仿形记录数（行高 36、字号 26、内边距 14、文字边距 6），每行只写技能名、左对齐。
## - 当前仿形不可选（半透明，确定时蜂鸣）；打开时光标在第一项（select(0)，即使第一项是当前仿形）。
## 操作同 XBattleList（上下首尾相接、确定、取消、点选、右键取消）。

const W := 380.0
const MLH := 36.0
const MTPAD := 6.0

## 各行的技能号（仿形记录的顺序）
var ids: Array = []


static func for_records(parent: Control, observed: Array, selected: int) -> XAlienMimicWindow:
	var w := XAlienMimicWindow.new()
	w.ids = observed.map(func(id): return int(id))
	w.entries = w.ids.map(func(id): return {"text": str(XDB.rec("Skills", id).get("name", "")), "enabled": id != selected})
	w.rows = w.entries.size()
	w.size = Vector2(W, w.rows * MLH + XMVWindow.PADDING * 2)
	w.position = Vector2((1280.0 - W) / 2.0, 100.0)
	parent.add_child(w)
	w.canvas.painter = w._paint
	w.canvas.blink = true
	w.select(0)
	return w


func _paint(c: XMVCanvas) -> void:
	for i in entries.size():
		var y := i * MLH
		if i == index:
			c.cursor(Rect2(0, y, c.size.x, MLH), active)
		var alpha := 1.0 if bool(entries[i].enabled) else XUI.DIM.a
		c.text(str(entries[i].text), MTPAD, y, c.size.x - MTPAD * 2, "left", XUI.TEXT, XUI.FONT_SIZE, MLH, alpha)


func _hit(p: Vector2) -> int:
	var local := p - position - Vector2(padding, padding)
	if local.x < 0 or local.x >= size.x - padding * 2 or local.y < 0 or local.y >= rows * MLH:
		return -1
	var i := floori(local.y / MLH)
	return i if i < entries.size() else -1
