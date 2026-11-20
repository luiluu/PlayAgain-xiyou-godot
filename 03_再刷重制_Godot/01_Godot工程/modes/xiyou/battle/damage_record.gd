class_name XDamageRecord
extends Control
## 设置「战斗伤害记录」（Star_CombatDamageRecord v1.1 ＋ Bailong_StarDamageRecord_ExactAction）：战斗右下角统计出战成员造成的伤害。
## - 开战时（Window_BattleLog 建立）设置开着才建出；胜利、逃跑、全灭（BattleManager.endBattle）立即移除。
## - 窗口 Star_Record：宽 248、高 36 + 18×出战人数，放在 (1280−248−12, 720−高−12)；内边距 6、行高 18；
##   窗口皮肤透明，暗底横向渐变（左半 透明→黑 0.6，右半 黑 0.6，上下各留内边距）。
## - 第 0 行：「伤害统计」（字号 15、系统色，宽 80）＋ 合计（右对齐）；第 i 个出战栏位在 y = 24 + 18i（字号 14）：
##   名字（宽 92）、伤害（x 94 右对齐，宽 内容宽 −140）、占比（系统色，右对齐在内容最右 44 宽）。空栏位不画但留出行位。
## - 计数（Bailong 精确版）：角色对敌人的每次 Action.apply，HP 伤害（>0，取整）计入该角色所在的出战栏位；持续伤害等不计。
## - 数字写法 formatDamage：<1 万原样，否则 万/亿/兆/京/垓/秭/穰，保留两位小数（JS 数字写法，末尾的 0 去掉）。
## 原版在手机上会避开虚拟按键（installV019UsabilityRuntime），Mac 没有虚拟按键，不做。

const WIDTH := 248.0
const PADDING := 6.0
const LH := 18.0
const UNITS := [[1e4, 1e8, "万"], [1e8, 1e12, "亿"], [1e12, 1e16, "兆"], [1e16, 1e20, "京"], [1e20, 1e24, "垓"], [1e24, 1e28, "秭"]]

var slots: Array = []        # 出战栏位的角色 ID（0 为空）
var values: Array = [0.0, 0.0, 0.0, 0.0, 0.0]
var canvas: XMVCanvas


## slot_ids：XState.battle_slots；members：出战人数（battleMembers().length）
func setup(slot_ids: Array, members: int) -> void:
	slots = slot_ids.duplicate()
	skin = XSkin2C.record_on()
	collapsed = _load_collapsed() if skin else false
	var h := 36.0 + LH * members
	size = Vector2(WIDTH, h)
	position = Vector2(1280.0 - WIDTH - 12.0, 720.0 - h - 12.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas = XMVCanvas.new()
	canvas.position = Vector2(PADDING, PADDING)
	canvas.size = size - Vector2(PADDING, PADDING) * 2.0
	canvas.painter = _paint
	add_child(canvas)
	_old_rect = Rect2(position, size)


func total() -> float:
	var t := 0.0
	for v in values:
		t += v
	return t


## 一次 Action.apply 的结果：使用者是出战角色、目标是敌人时计入
func record(user: XBattler, target: XBattler, hp_damage: float) -> void:
	if not (user is XActor and target is XEnemy):
		return
	var i := slots.find(user.actor_id)
	var dmg := floorf(maxf(0.0, hp_damage))
	if i < 0 or i >= values.size() or dmg <= 0.0:
		return
	values[i] += dmg
	if canvas != null:
		canvas.queue_redraw()


static func format_damage(d: float) -> String:
	if d < 1e4:
		return _js_number(d)
	for u in UNITS:
		if d < u[1]:
			return _js_number(roundf(d / u[0] * 100.0) / 100.0) + u[2]
	return _js_number(roundf(d / 1e28 * 100.0) / 100.0) + "穰"


## JS Number → 字符串（整数不带小数点，小数去掉末尾 0）
static func _js_number(v: float) -> String:
	if v == floorf(v) and absf(v) < 1e21:
		return "%d" % int(v) if absf(v) < 9.2e18 else String.num(v, 0)
	return String.num(v, 2)


func _draw() -> void:
	if _skin_now():
		_draw_skin()
		return
	# Star_Record.refreshDimmerBitmap：左半 dimColor2→dimColor1 横向渐变，右半实心 dimColor1，上下各留内边距
	var c1 := Color(0, 0, 0, 0.6)
	var c2 := Color(0, 0, 0, 0)
	var w1 := ceilf(size.x / 2.0)
	var h1 := size.y - PADDING * 2.0
	draw_polygon(PackedVector2Array([Vector2(0, PADDING), Vector2(w1, PADDING), Vector2(w1, PADDING + h1), Vector2(0, PADDING + h1)]),
		PackedColorArray([c2, c1, c1, c2]))
	draw_rect(Rect2(w1, PADDING, w1, h1), c1)


func _paint(c: XMVCanvas) -> void:
	var t := total()
	var w := c.size.x
	var sys := XUI.text_color(16)
	c.text("伤害统计", 0, 0, 80, "left", sys, 15, LH)
	c.text(format_damage(t), 80, 0, w - 80, "right", XUI.TEXT, 15, LH)
	for i in range(mini(5, slots.size())):
		var id := int(slots[i])
		if id <= 0:
			continue
		var a: XActor = XState.current.actor(id) if XState.current else null
		if a == null:
			continue
		var y := 24.0 + i * LH
		var pct := roundi(values[i] / t * 100.0) if t > 0 else 0
		c.text(a.display_name(), 0, y, 92, "left", XUI.TEXT, 14, LH)
		c.text(format_damage(values[i]), 94, y, w - 140, "right", XUI.TEXT, 14, LH)
		c.text("%d%%" % pct, w - 44, y, 44, "right", sys, 14, LH)


## ======== T267 新界面 2C 卡 B（T254 1.5，Kyo D232「甲 常开」）：脚线以下一条矮带、两列 ========
## 硬规矩：任何状态、任何位置，上沿都不高于 y 616（我方最低脚底 600＋16）。
## 平时展开（64 高、两列、按伤害高低排）；当前打开的战斗窗口和矮带相交 → 让成一行（24 高）；一行仍相交 → 整条 0.12 秒淡出；
## 窗口全关 0.15 秒后恢复。玩家点一下暗带收成一行、再点展开（记在本机，默认展开）。指令环、列表一行不动，只统计自己让。
## 计数、values、slots、record()、format_damage 一行不动；排序只改显示顺序。

const TOP_MIN := 616.0
const BAND_Y := 628.0
const BAND_H := 64.0
const LINE_Y := 670.0
const LINE_H := 24.0
const CELL_W := 196.0
const CELL_H := 24.0
const COL_GAP := 24.0
const PAD_R := 24.0
const FADE_W := 22.0
const OTB_RIGHT := 580.0        # 左端碰到行动顺序条就改一行
const RESTORE := 0.15
const HIDE_FADE := 0.12
const SWAP := 0.2
const SWEEP := 0.3
const UI_FILE := "damage_record_ui.cfg"   # T267 时的旧文件，只迁移用（见 _load_collapsed）

var skin := false
var origin := Vector2.ZERO           # 战斗画面原点（屏幕坐标）
var members_source: Callable         # → 当前在场的角色（logic.actors）
var windows_source: Callable         # → 当前打开的战斗窗口矩形（战斗画面坐标）
var collapsed := false               # 玩家点了收成一行
var avoid := 0                       # 0 不让、1 让成一行、2 淡出
var touch_level := 0                 # 触屏按键挤：0 不挤、1 改一行、2 放不下
var _shift := 0.0                    # 触屏按键挤时整条左挪
var _clear_t := 0.0
var _alpha := 1.0
var _now := 0.0
var _cell_pos := {}                  # 栏位 → 现在画的格位置（换位动画）
var _cell_fade := {}                 # 栏位 → 交叉淡入进度
var _leader := -1
var _sweep_at := -9.0
## 测试读：上一帧的状态
var last := {}


var _old_rect := Rect2()


## 新画法：开局时新皮肤开着才是（skin），XSkin2C.RECORD 中途关掉回旧画法（对照截图、回退用）
func _skin_now() -> bool:
	return skin and XSkin2C.record_on()


func _ready() -> void:
	origin = position - _old_rect.position   # 战斗场景在 setup 之后加上 _origin
	_old_rect.position = position


## T273（T267 核查 P3-4）：收／展并进设置 XConfig（CONFIG_KEY，默认展开）；T267 时记在 damage_record_ui.cfg，读到旧文件迁一次再删
const CONFIG_KEY := "codexRecordCollapsed"


static func _ui_path() -> String:
	var base := XConfig.path()
	if base == "":   # T291（T273 核查 P3-3）：没有设置文件路径（截图模式等）时不拼相对路径
		return ""
	return base.get_base_dir().path_join(UI_FILE)


static func _load_collapsed() -> bool:
	var cf := ConfigFile.new()
	if _ui_path() != "" and FileAccess.file_exists(_ui_path()) and cf.load(_ui_path()) == OK:
		XConfig.set_flag(CONFIG_KEY, bool(cf.get_value("record", "collapsed", false)))
		DirAccess.remove_absolute(_ui_path())
	return XConfig.flag(CONFIG_KEY)


static func save_collapsed(on: bool) -> void:
	XConfig.set_flag(CONFIG_KEY, on)


## 谁占格：在场的人 ∪ 有伤害的栏位（没上过场的 0 伤助力位不占格，换下场的人有伤害照样留格）；按伤害高低、并列按栏位
func occupants() -> Array:
	var here := []
	if members_source.is_valid():
		for a in members_source.call():
			if a is XActor:
				here.append(a.actor_id)
	var out := []
	for i in range(mini(slots.size(), values.size())):
		var id := int(slots[i])
		if id <= 0:
			continue
		if float(values[i]) > 0.0 or here.has(id) or not members_source.is_valid():
			out.append(i)
	out.sort_custom(func(a, b): return values[a] > values[b] or (values[a] == values[b] and a < b))
	return out


## 矮带上画哪几格（前 4 名）
func shown_cells() -> Array:
	return occupants().slice(0, 4)


func cell_w() -> float:
	return CELL_W + clampf((XUiSkin.font_mult() - 1.0) / 0.3, 0.0, 1.0) * 32.0


func _name_w() -> float:
	return 64.0 + clampf((XUiSkin.font_mult() - 1.0) / 0.3, 0.0, 1.0) * 16.0


## 矮带右端（战斗画面坐标）：16:9 到屏幕右边；20:9 对齐队伍栏右缘（战场右缘往里 XSkinSideStatus.RIGHT）
func right_edge() -> float:
	if origin.x > 1.0:
		return 1280.0 - XSkinSideStatus.RIGHT
	var vw := get_viewport_rect().size.x if is_inside_tree() else 1280.0
	return vw - origin.x


func _left_block_w() -> float:
	var t := format_damage(total())
	return maxf(XSkin2C._tw("伤害统计", XUiSkin.fs(15)), XSkin2C._tw(t, XUiSkin.fs(21)))


## 展开时的矩形（不含触屏挪位；战斗画面坐标）
func band_rect() -> Rect2:
	var n := shown_cells().size()
	var cols := 1 if n <= 2 else 2
	var r := right_edge() - _shift
	var content := PAD_R + cols * cell_w() + (cols - 1) * COL_GAP + 16.0 + 1.0 + 16.0 + _left_block_w() + 8.0
	return Rect2(r - content - FADE_W, BAND_Y, content + FADE_W, BAND_H)


func line_rect() -> Rect2:
	var r := right_edge() - _shift
	var w := 16.0 + XSkin2C._tw("伤害统计", XUiSkin.fs(15)) + 8.0 + XSkin2C._tw(format_damage(total()), XUiSkin.fs(17)) + 9.0 + 18.0
	var lead := shown_cells()
	if not lead.is_empty() and total() > 0.0:
		w += _name_w() + 6.0 + 42.0
	w += PAD_R + FADE_W + 40.0
	return Rect2(r - w, LINE_Y, w, LINE_H)


## 现在画的是哪一档：0 展开、1 一行、2 不画（窗口压着、触屏放不下）
func level() -> int:
	return maxi(maxi(avoid, touch_level), 1 if collapsed else 0)


func current_rect() -> Rect2:
	return line_rect() if level() >= 1 else band_rect()


func _touch_rect() -> Rect2:
	var t = XTouchControls.instance
	if t == null or not is_instance_valid(t) or not t.is_visible_in_tree():
		return Rect2()
	var gr = t.get("group_rects")
	if not gr is Dictionary or not gr.has("actions"):
		return Rect2()
	var r: Rect2 = gr["actions"]
	return Rect2(r.position - origin, r.size)


func _process(dt: float) -> void:
	if not skin:
		return
	if canvas != null:
		canvas.visible = not _skin_now()
	if not _skin_now():
		position = _old_rect.position
		size = _old_rect.size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = true
		queue_redraw()
		return
	_now += dt
	# 触屏按键挤：整条往左挪到按键左缘再往左 12；左端碰到行动顺序条改一行；一行也放不下不画
	_shift = 0.0
	touch_level = 0
	var tr := _touch_rect()
	if tr.has_area():
		var full := band_rect()
		if full.intersects(tr):
			_shift = maxf(0.0, right_edge() - (tr.position.x - 12.0))
			if band_rect().position.x + FADE_W < OTB_RIGHT:
				touch_level = 1
				if line_rect().position.x + FADE_W < OTB_RIGHT:
					touch_level = 2
	# 让战斗窗口：相交让成一行，一行仍相交淡出；窗口全关 0.15 秒后恢复
	var wins: Array = windows_source.call() if windows_source.is_valid() else []
	if wins.is_empty():
		_clear_t += dt
		if _clear_t >= RESTORE:
			avoid = 0
	else:
		_clear_t = 0.0
		var want := 0
		var b := band_rect()
		var l := line_rect()
		for w: Rect2 in wins:
			if w.intersects(b):
				want = maxi(want, 1)
			if w.intersects(l):
				want = 2
		if want == 1 and level() == 0:
			want = 1
		avoid = maxi(avoid, want)
	var target := 0.0 if level() >= 2 else 1.0
	if XUiSkin.motion() == XUiSkin.Motion.OFF:
		_alpha = target
	else:
		_alpha = move_toward(_alpha, target, dt / HIDE_FADE)
	visible = _alpha > 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP if level() < 2 else Control.MOUSE_FILTER_IGNORE
	_layout()
	_animate(dt)
	queue_redraw()


func _layout() -> void:
	var r := current_rect()
	assert(r.position.y >= TOP_MIN, "伤害统计上沿不能高于 y 616")
	position = origin + r.position
	size = r.size


## 点一下暗带：收成一行／展开（键盘手柄不给键）
func _gui_input(event: InputEvent) -> void:
	if not _skin_now():
		return
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if tap and level() < 2 and avoid == 0 and touch_level == 0:
		collapsed = not collapsed
		save_collapsed(collapsed)
		accept_event()


## 每格的目标位置（展开、相对矮带左上）：第一名左上、第二名左下、第三名右上、第四名右下
func cell_slot_pos(k: int, n: int) -> Vector2:
	var cols := 1 if n <= 2 else 2
	var col := k / 2
	var row := k % 2
	var w := size.x
	var x0 := w - PAD_R - cols * cell_w() - (cols - 1) * COL_GAP
	return Vector2(x0 + col * (cell_w() + COL_GAP), 8.0 + row * (CELL_H + 4.0))


func _animate(dt: float) -> void:
	var cells := shown_cells()
	var off := XUiSkin.motion() == XUiSkin.Motion.OFF
	for k in cells.size():
		var i: int = cells[k]
		var tgt := cell_slot_pos(k, cells.size())
		if not _cell_pos.has(i) or off:
			_cell_pos[i] = tgt
			continue
		var cur: Vector2 = _cell_pos[i]
		if absf(cur.x - tgt.x) > 1.0:   # 跨列：直接交叉淡入，不走斜线
			_cell_pos[i] = tgt
			_cell_fade[i] = 0.0
		else:
			_cell_pos[i] = Vector2(tgt.x, move_toward(cur.y, tgt.y, (CELL_H + 4.0) * dt / SWAP))
		if _cell_fade.has(i):
			_cell_fade[i] = float(_cell_fade[i]) + dt / SWAP
			if float(_cell_fade[i]) >= 1.0:
				_cell_fade.erase(i)
	var lead: int = cells[0] if not cells.is_empty() and total() > 0.0 else -1
	if lead != _leader:
		if _leader >= 0 and lead >= 0 and XUiSkin.motion() == XUiSkin.Motion.FULL:
			_sweep_at = _now
		_leader = lead


func _line_key() -> String:
	return XTianqiLine.current(XState.current) if XState.current != null else ""


func _lead_color() -> Color:
	var k := _line_key()
	return XSkin2C.line_bright(k) if k != "" else XUiSkin.GOLD_LIGHT


func _main_color() -> Color:
	var k := _line_key()
	return XTianqiLook.main_color(k) if k != "" else XUiSkin.GOLD


## 暗带：从右往左 黑 92% → 86%（七成处）→ 0；右端一道 3px 本线主色竖线（上下淡出）
func _draw_band(w: float, h: float, a: float) -> void:
	var bg := XUiSkin.BG
	var x7 := w * 0.3
	var c0 := Color(bg, 0.0)
	var c1 := Color(bg, 0.86 * a)
	var c2 := Color(bg, 0.92 * a)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(x7, 0), Vector2(x7, h), Vector2(0, h)]), PackedColorArray([c0, c1, c1, c0]))
	draw_polygon(PackedVector2Array([Vector2(x7, 0), Vector2(w, 0), Vector2(w, h), Vector2(x7, h)]), PackedColorArray([c1, c2, c2, c1]))
	var m := _main_color()
	var ys := [0.0, h * 0.25, h * 0.75, h]
	var al := [0.0, 1.0, 1.0, 0.0]
	for i in 3:
		var ca := Color(m, a * al[i])
		var cb := Color(m, a * al[i + 1])
		draw_polygon(PackedVector2Array([Vector2(w - 3, ys[i]), Vector2(w, ys[i]), Vector2(w, ys[i + 1]), Vector2(w - 3, ys[i + 1])]), PackedColorArray([ca, ca, cb, cb]))


func _draw_skin() -> void:
	last = {"level": level(), "rect": Rect2(position - origin, size), "cells": []}
	if _alpha <= 0.0:
		return
	var a := _alpha
	var t := total()
	if level() >= 1:
		_draw_line_mode(a, t)
		return
	_draw_band(size.x, size.y, a)
	var f15 := XUiSkin.fs(15)
	var f21 := XUiSkin.fs(21)
	var cells := shown_cells()
	var n := cells.size()
	var cols := 1 if n <= 2 else 2
	var grid_x := size.x - PAD_R - cols * cell_w() - (cols - 1) * COL_GAP
	var lx := grid_x - 16.0 - 1.0
	draw_rect(Rect2(lx, (size.y - 44.0) / 2.0, 1, 44), Color(XUiSkin.LINE, 0.9 * a))
	var bw := _left_block_w()
	XSkin2C._text(self, lx - 16.0 - bw, 8.0, "伤害统计", f15, Color(XUiSkin.GOLD, a), HORIZONTAL_ALIGNMENT_RIGHT, bw)
	XSkin2C._text(self, lx - 16.0 - bw, 8.0 + f15 * 1.25, format_damage(t), f21, Color(XUiSkin.GOLD_LIGHT, a), HORIZONTAL_ALIGNMENT_RIGHT, bw)
	for k in n:
		var i: int = cells[k]
		var p: Vector2 = _cell_pos.get(i, cell_slot_pos(k, n))
		var ca := a * clampf(float(_cell_fade.get(i, 1.0)), 0.0, 1.0)
		_draw_cell(i, p, k == 0 and t > 0.0, t, ca)


func _draw_cell(i: int, p: Vector2, lead: bool, t: float, a: float) -> void:
	var a_id := int(slots[i])
	var actor: XActor = XState.current.actor(a_id) if XState.current else null
	var nm := actor.display_name() if actor != null else ""
	var f15 := XUiSkin.fs(15)
	var cw := cell_w()
	var nw := _name_w()
	var pct := roundi(values[i] / t * 100.0) if t > 0 else 0
	var dc := p + Vector2(4.0, CELL_H / 2.0 - 1.0)
	var lc := _lead_color()
	if lead:
		XSkin2C._glow(self, dc, 12.0, Color(_main_color(), 0.6 * a))
		XSkin2C._diamond(self, dc, 4.0, Color(lc, a))
		last.lead_dot = dc   # T273 卡 U：第一名那颗菱形（本节点坐标），胜利那一刻衔接层要拍它
	else:
		XSkin2C._diamond_line(self, dc, 4.0, Color(XUiSkin.TEXT_2, a), 1.0)
	var x := p.x + 18.0
	var top := p.y + (CELL_H - 2.0 - f15 * 1.25) / 2.0
	if lead:
		XSkin2C._glow(self, Vector2(x + nw * 0.4, p.y + CELL_H / 2.0), 26.0, Color(_main_color(), 0.22 * a))
	XSkin2C._text(self, x, top, XSkin2C.fit(nm, f15, nw), f15, Color(lc if lead else XUiSkin.TEXT, a))
	var dw := cw - 18.0 - nw - 42.0
	XSkin2C._text(self, x + nw, top, format_damage(values[i]), f15, Color(XUiSkin.GOLD_LIGHT if lead else XUiSkin.TEXT, a), HORIZONTAL_ALIGNMENT_RIGHT, dw)
	XSkin2C._text(self, p.x + cw - 42.0, top, "%d%%" % pct, f15, Color(XUiSkin.TEXT_2, a), HORIZONTAL_ALIGNMENT_RIGHT, 42.0)
	if t > 0.0 and pct > 0:
		var lw: float = (cw - 18.0) * values[i] / t
		draw_rect(Rect2(x, p.y + CELL_H - 2.0, lw, 2.0), Color(_main_color() if lead else XUiSkin.GOLD, (1.0 if lead else 0.7) * a))
	var sk := (_now - _sweep_at) / SWEEP
	if lead and sk >= 0.0 and sk < 1.0:
		var sx := p.x + cw * sk
		XSkin2C._glow(self, Vector2(sx, p.y + CELL_H / 2.0), 22.0, Color(1, 1, 1, 0.5 * (1.0 - sk) * a))
	last.cells.append({"slot": i, "name": nm, "pos": p, "lead": lead, "pct": pct})


## 一行：「伤害统计」、合计、竖线、亮菱形、第一名的名字、他的占比；底边 3px 分段占比线（每人一段，段间隔 2）
func _draw_line_mode(a: float, t: float) -> void:
	var w := size.x
	var h := size.y
	_draw_band(w, h, a)
	var f15 := XUiSkin.fs(15)
	var f17 := XUiSkin.fs(17)
	var x := FADE_W + 16.0
	var top := (h - f15 * 1.25) / 2.0 - 1.0
	XSkin2C._text(self, x, top, "伤害统计", f15, Color(XUiSkin.GOLD, a))
	x += XSkin2C._tw("伤害统计", f15) + 8.0
	var tot := format_damage(t)
	XSkin2C._text(self, x, (h - f17 * 1.25) / 2.0 - 1.0, tot, f17, Color(XUiSkin.GOLD_LIGHT, a))
	x += XSkin2C._tw(tot, f17) + 8.0
	draw_rect(Rect2(x, 4, 1, h - 8), Color(XUiSkin.LINE, 0.9 * a))
	x += 9.0
	var occ := occupants()
	if not occ.is_empty() and t > 0.0:
		var i: int = occ[0]
		var actor: XActor = XState.current.actor(int(slots[i])) if XState.current else null
		var dc := Vector2(x + 4.0, h / 2.0 - 1.0)
		XSkin2C._glow(self, dc, 12.0, Color(_main_color(), 0.6 * a))
		XSkin2C._diamond(self, dc, 4.0, Color(_lead_color(), a))
		last.lead_dot = dc
		x += 18.0
		XSkin2C._text(self, x, top, XSkin2C.fit(actor.display_name() if actor else "", f15, _name_w()), f15, Color(_lead_color(), a))
		x += minf(_name_w(), XSkin2C._tw(actor.display_name() if actor else "", f15)) + 6.0
		XSkin2C._text(self, x, top, "%d%%" % roundi(values[i] / t * 100.0), f15, Color(XUiSkin.TEXT_2, a))
		# 分段占比线（按全部有伤害的人，最多 5 段）
		var segs := occ.filter(func(j): return values[j] > 0.0)
		var bx := FADE_W + 16.0
		var bw := w - bx - PAD_R
		var gap := 2.0
		var avail := bw - gap * (segs.size() - 1)
		var sx := bx
		var fades := [1.0, 0.8, 0.55, 0.4, 0.4]
		for k in segs.size():
			var sw: float = avail * values[segs[k]] / t
			var col := _main_color() if k == 0 else Color(XUiSkin.GOLD, fades[k])
			draw_rect(Rect2(sx, h - 3.0, sw, 3.0), Color(col, col.a * a))
			sx += sw + gap
		last.segments = segs.size()
