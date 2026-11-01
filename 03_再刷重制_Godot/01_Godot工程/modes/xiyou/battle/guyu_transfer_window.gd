class_name XGuyuTransferWindow
extends XBattleList
## 谷雨「借一枝春色」的赠春／还春选择窗（installNativeGuyuRuntime 515～562 Window_GuyuTransfer）：普通 Window_Command，
## 宽 320，在画面正中（x＝(1280−320)/2、y＝(720−窗高)/2）；行高 36、字号 26、内边距 14、文字边距 6，靠左只写文字；
## 每种比例「赠春（n%）」「还春（n%）」各一行（XGuyu.transfer_commands），没有能转的目标时灰掉（确定时蜂鸣）。
## 打开时光标在 50% 的赠春，它灰着就第一个能选的。操作同 XBattleList（上下首尾相接、翻页、滚轮、点选、右键取消）。
## 窗高（参照 guyu_ui_probe 的 window 例）：原版在 createAllWindows 建窗，那时 BattleManager.actor() 为空，命令只有 2 行，
## 窗高就定在 2 行（100），之后打开时 refresh 换成 6 行也不变高——10 级起三种比例只露 2 行，要上下滚才看得到其余。

const W := 320.0
const MLH := 36.0
const MTPAD := 6.0
const ORIGINAL_ROWS := 2
## 优化 O-待定：窗高按命令行数（10 级起 6 行全露出来）；false 照原版固定 2 行（建窗时的行数）、其余要滚动
static var FIT_ROWS := true


static func for_actor(parent: Control, a) -> XGuyuTransferWindow:
	var w := XGuyuTransferWindow.new()
	w.entries = XGuyu.transfer_commands(a)
	w.rows = maxi(1, w.entries.size()) if FIT_ROWS else ORIGINAL_ROWS
	w.size = Vector2(W, w.rows * MLH + XMVWindow.PADDING * 2)
	w.position = Vector2((1280.0 - W) / 2.0, (720.0 - w.size.y) / 2.0)
	parent.add_child(w)
	w.canvas.painter = w._paint
	w.canvas.blink = true
	w.select(XGuyu.transfer_default_index(w.entries))
	return w


func _paint(c: XMVCanvas) -> void:
	for i in range(top, mini(top + rows, entries.size())):
		var y := (i - top) * MLH
		if i == index:
			c.cursor(Rect2(0, y, c.size.x, MLH), active)
		var alpha := 1.0 if bool(entries[i].enabled) else XUI.DIM.a
		c.text(str(entries[i].text), MTPAD, y, c.size.x - MTPAD * 2, "left", XUI.TEXT, XUI.FONT_SIZE, MLH, alpha)


func _hit(p: Vector2) -> int:
	var local := p - position - Vector2(padding, padding)
	if local.x < 0 or local.x >= size.x - padding * 2 or local.y < 0 or local.y >= rows * MLH:
		return -1
	var i := top + floori(local.y / MLH)
	return i if i < entries.size() else -1
