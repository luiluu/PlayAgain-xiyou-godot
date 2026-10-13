class_name XSideStatus
extends Control
## 右侧角色状态（Olivia_SideBattleUI Window_BattleSideStatus，正式版运行时读数）：
## - 窗口 (1280−200, 序号×121, 296, 121)，不透明度 0，内边距 0；内容是暗底：左 74px 由透明渐变到黑 0.6，其余黑 0.6。
## - 子窗口（缩放 0.6：字号 16、行高 22、文字边距 4）：名字 (0,6)；HP (8,28)、MP (16,50)、TP (24,72)，量条宽 160、高 6；
##   名字按 HP 颜色（濒危黄、死亡红）；HP/MP 为 YEP drawCurrentAndMax「当前/最大」，TP 只显示数值。
## - 状态格（installEquipmentStatusRuntime）：(−36, 20) 36×36，有图标状态时每 1.4 秒轮换显示一个，否则深色方块里写「i」。
## - 轮到输入或正在行动的角色左移 48，被选为目标时左移 24，每帧移动 4px。

const W := 296.0
const H := 121.0
const HOME_X := 1280.0 - 200.0
const MOVE_ACTIVE := 48.0
const MOVE_SELECTED := 24.0
const MOVE_SPEED := 4.0
const LH := 22.0
const FS := 16
const PAD := 4.0
const GAUGE_W := 160.0
const CYCLE_MS := 1400

var actor: XActor
var active := false
var selected := false
var canvas: XMVCanvas
var _cycle := 0
var _cycle_at := 0


func setup(a: XActor, index: int) -> void:
	actor = a
	position = Vector2(HOME_X, index * H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas = XMVCanvas.new()
	canvas.position = Vector2(-36, 0)
	canvas.size = Vector2(W + 36, H)
	canvas.clip_contents = false
	canvas.painter = _paint
	add_child(canvas)


func refresh() -> void:
	canvas.queue_redraw()


func _physics_process(_delta: float) -> void:
	var target := HOME_X - (MOVE_ACTIVE if active else (MOVE_SELECTED if selected else 0.0))
	if position.x < target:
		position.x = minf(position.x + MOVE_SPEED, target)
	elif position.x > target:
		position.x = maxf(position.x - MOVE_SPEED, target)
	var now := Time.get_ticks_msec()
	if now > _cycle_at:
		_cycle_at = now + CYCLE_MS
		_cycle += 1
		refresh()


func _icons() -> Array:
	var out := []
	for st in actor.states():
		if int(st.get("iconIndex", 0)) > 0:
			out.append(int(st.iconIndex))
	return out


func _paint(c: XMVCanvas) -> void:
	if actor == null:
		return
	var ox := 36.0   # 画布向左多出状态格的 36px
	var dark := Color(0, 0, 0, 0.6)
	var w1 := ceilf(W / 4.0)
	c.gradient(Rect2(ox, 0, w1, H), Color(0, 0, 0, 0), dark)
	c.draw_rect(Rect2(ox + w1, 0, W - w1, H), dark)
	# 状态格
	var icons := _icons()
	if icons.is_empty():
		c.draw_rect(Rect2(ox - 36 + 1, 21, 30, 30), Color8(20, 35, 55, 230))
		c.text("i", ox - 36, 20, 32, "center", XUI.TEXT, 22, 36)
	else:
		c.icon(icons[_cycle % icons.size()], ox - 36, 20)
	# 名字
	c.text(actor.display_name(), ox + PAD, 6, 200, "left", _hp_color(), FS, LH)
	# HP / MP / TP
	_param(c, ox + 8 + PAD, 28, "HP", actor.hp, actor.mhp, XUI.GAUGES.hp, _hp_color(), true)
	_param(c, ox + 16 + PAD, 50, "MP", actor.mp, actor.mmp, XUI.GAUGES.mp, XUI.TEXT, true)
	_param(c, ox + 24 + PAD, 72, "TP", actor.tp, 100.0, XUI.GAUGES.tp, XUI.TEXT, false)


func _param(c: XMVCanvas, x: float, y: float, label: String, cur: float, mx: float, colors: Array, color: Color, with_max: bool) -> void:
	c.gauge(x, y, GAUGE_W, cur / mx if mx > 0 else 0.0, colors[0], colors[1], LH)
	c.text(label, x, y, 44, "left", XUI.SYSTEM, FS, LH)
	if not with_max:
		c.text(XMenu._group(cur), x + GAUGE_W - 64, y, 64, "right", color, FS, LH)
		return
	# YEP drawCurrentAndMax
	var vw := c.text_width(XMenu._group(mx), FS)
	var sw := c.text_width("/", FS)
	var x1 := x + GAUGE_W - vw
	var x2 := x1 - sw
	var x3 := x2 - vw
	if x3 >= x + c.text_width("HP", FS):
		c.text(XMenu._group(cur), x3, y, vw, "right", color, FS, LH)
		c.text("/", x2, y, sw, "right", XUI.TEXT, FS, LH)
		c.text(XMenu._group(mx), x1, y, vw, "right", XUI.TEXT, FS, LH)
	else:
		c.text(XMenu._group(cur), x1, y, vw, "right", color, FS, LH)


func _hp_color() -> Color:
	if actor.is_dead():
		return XUI.DEATH
	if actor.hp < actor.mhp / 4.0:
		return XUI.CRISIS
	return XUI.TEXT
