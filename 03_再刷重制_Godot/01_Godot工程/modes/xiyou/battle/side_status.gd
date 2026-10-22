class_name XSideStatus
extends Control
## 右侧角色状态（Olivia_SideBattleUI Window_BattleSideStatus，正式版运行时读数）：
## - 窗口 (1280−200, 序号×121, 296, 121)，不透明度 0，内边距 0；内容是暗底：左 74px 由透明渐变到黑 0.6，其余黑 0.6。
## - 子窗口（缩放 0.6：字号 16、行高 22、文字边距 4）：名字 (0,6)；HP (8,28)、MP (16,50)、TP (24,72)，量条宽 160、高 6；
##   名字按 HP 颜色（濒危黄、死亡红）；HP/MP 为 YEP drawCurrentAndMax「当前/最大」，TP 只显示数值。
## - 护盾（ShieldSystem 钩 Window_BattleSideHP.refresh）：护盾大于 0 时，在 HP 条上按 max(生命上限, HP＋护盾) 折算，
##   从 HP 位置到 HP＋护盾位置叠一段蓝色 rgba(0,136,255,0.7)（高 6，贴行底）；HP 字样右侧 6px 写「盾＋数值」（12 号、#88ccff、描边黑 0.7，万／亿／兆…一位小数）。
##   画面对照（八戒_50，原版参照 battle_shield_side）：蓝段四种情形逐像素一致。
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
const SHIELD_SEG := Color8(0, 136, 255, 179)
const SHIELD_COLOR := Color("#88ccff")
## ShieldSystem 设 outlineColor rgba(0,0,0,0.7)、outlineWidth 2；宽度被正式版封顶 0.75px（同通用细描边），颜色照设
const SHIELD_OUTLINE := Color(0, 0, 0, 0.7)

var actor: XActor
## 演出中的读数（XBattleScene.show_views 设、clear_views 清）；空时读实时状态
var view := {}
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
	if not view.is_empty():
		return view.icons
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
	var v := _v()
	_param(c, ox + 8 + PAD, 28, "HP", v.hp, v.mhp, XUI.GAUGES.hp, _hp_color(), true)
	_shield(c, ox + 8 + PAD, 28, v)
	_param(c, ox + 16 + PAD, 50, "MP", v.mp, v.mmp, XUI.GAUGES.mp, XUI.TEXT, true)
	_param(c, ox + 24 + PAD, 72, "TP", v.tp, v.mtp, XUI.GAUGES.tp, XUI.TEXT, false)


func _v() -> Dictionary:
	if not view.is_empty():
		return view
	return {"hp": actor.hp, "mhp": actor.mhp, "mp": actor.mp, "mmp": actor.mmp, "tp": actor.tp, "mtp": actor.max_tp(), "dead": actor.is_dead(),
		"shield": actor.shield}


func _shield(c: XMVCanvas, x: float, y: float, v: Dictionary) -> void:
	var s := float(v.get("shield", 0.0))
	if s <= 0.0:
		return
	var seg := shield_segment(v.hp, v.mhp, s, x)
	if seg.y > seg.x:
		c.draw_rect(Rect2(seg.x, y + LH - 6.0, seg.y - seg.x, 6.0), SHIELD_SEG)
	var label := "盾" + shield_text(s)
	c.text(label, x + c.text_width("HP", FS) + 6.0, y, c.text_width(label, 12) + 4.0, "left", SHIELD_COLOR, 12, LH, 1.0, 1.0, Vector2.ZERO, SHIELD_OUTLINE)


## 蓝段的起止 x（HP 位置到 HP＋护盾位置，按 max(生命上限, HP＋护盾, 1) 折算，取整同原版 Math.floor）
static func shield_segment(hp: float, mhp: float, s: float, x: float) -> Vector2i:
	var mx := maxf(maxf(mhp, hp + s), 1.0)
	return Vector2i(int(floorf(x + GAUGE_W * minf(hp / mx, 1.0))), int(floorf(x + GAUGE_W * minf((hp + s) / mx, 1.0))))


## formatShieldText：一万起按 万／亿／兆／京／垓／秭／穰／沟／涧／正／载 取一位小数，以下取整
static func shield_text(value: float) -> String:
	const UNITS := [[1e44, "载"], [1e40, "正"], [1e36, "涧"], [1e32, "沟"], [1e28, "穰"], [1e24, "秭"], [1e20, "垓"],
		[1e16, "京"], [1e12, "兆"], [1e8, "亿"], [1e4, "万"]]
	for u in UNITS:
		if value >= u[0]:
			return "%.1f%s" % [value / u[0], u[1]]
	return str(int(floorf(value)))


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
	var v := _v()
	if v.dead:
		return XUI.DEATH
	if v.hp < v.mhp / 4.0:
		return XUI.CRISIS
	return XUI.TEXT
