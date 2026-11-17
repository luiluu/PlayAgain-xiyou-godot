class_name XSkinSideStatus
extends XSideStatus
## 【cc·天启篇·未经审查】新界面 2B：战斗右上的队伍紧凑条（盘点清册 #65，界面风格提案 v0.7 样稿 battle 的 .party）。
## 一人一行（行高 58、宽 290）：圆头像、名字、「Lv 等级 · 职业」、右上状态图标（最多 3 个，带层数）、血（玫粉）蓝 TP 三条细量条＋窄体数字。
## 轮到输入的人那一行是红乙选中条（原版是整行左移 48），被选为目标的行旧金细框（原版左移 24）；整行可点，点了打开状态详情（原版只有左边 32×32 的状态格能点）。
## 读数全照 XSideStatus：演出中读 view（XBattleScene.show_views 的画面快照）、平时读实时值；状态图标用 cell_rows（有记忆，同原状态格的筛选和排序）；
## 护盾在血条上叠一段浅蓝、Lv 行后写「盾 1.2万」；谷雨的状态字也写在 Lv 行。不调任何会触发能力值重算的接口（头像取数据库的 faceName）。
## 位置参数是 static var（两排站位的指令环位置 Kyo 还没定；队伍条跟着要不要挪也留在这几个数）：RIGHT（离 1280 右边）、TOP、ROW_W、ROW_H。

static var RIGHT := 16.0
static var TOP := 12.0
static var ROW_W := 290.0
static var ROW_H := 58.0
const PAD_Y := 2.0           # 面板上下各留 2（样稿 .party padding 2px 0）
const HEAD := 40.0
const MAX_ICONS := 3
const SHIELD_FILL := Color(0.53, 0.8, 1.0, 0.75)

var face_tex: Texture2D
var _drawn_flags := -1


static func panel_x() -> float:
	return 1280.0 - RIGHT - ROW_W


## 第 i 行的位置（原版坐标）
static func row_pos(i: int) -> Vector2:
	return Vector2(panel_x(), TOP + PAD_Y + i * ROW_H)


func setup(a: XActor, index: int) -> void:
	super.setup(a, index)
	position = row_pos(index)
	size = Vector2(ROW_W, ROW_H)
	canvas.position = Vector2.ZERO
	canvas.size = size
	cell_button.position = Vector2.ZERO
	cell_button.size = size
	var d := a.data()
	face_tex = XUiSkin.face(str(d.get("faceName", "")), int(d.get("faceIndex", 0)))


## 不左移；状态图标不轮换（一次画 3 个），保留原来每 1.4 秒重画一次（实时读数跟上）；轮到／被选变了马上重画
func _physics_process(_delta: float) -> void:
	var flags := (1 if active else 0) + (2 if selected else 0)
	if flags != _drawn_flags:
		_drawn_flags = flags
		refresh()
	var now := Time.get_ticks_msec()
	if now > _cycle_at:
		_cycle_at = now + CYCLE_MS
		_cycle += 1
		refresh()


func _paint_now(c: XMVCanvas) -> void:
	var ci := c.get_canvas_item()
	var v := _v()
	var dead := bool(v.get("dead", false))
	var r := Rect2(Vector2.ZERO, size)
	if active:
		XUiSkin.draw_select(ci, r.grow_individual(-4, -2, -4, -2))
	elif selected:
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = Color(XUiSkin.GOLD, 0.8)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(XUiSkin.ROW_RADIUS)
		sb.draw(ci, r.grow_individual(-4, -2, -4, -2))
	var alpha := 0.5 if dead else 1.0
	# 头像
	var hc := Vector2(12 + HEAD / 2.0, ROW_H / 2.0)
	c.draw_circle(hc, HEAD / 2.0, XUiSkin.ORB_LOW)
	if face_tex != null:
		XSkinPartyStrip.draw_round_texture(c, face_tex, hc, HEAD / 2.0 - 2.0)
	if dead:
		c.draw_circle(hc, HEAD / 2.0 - 2.0, Color(0, 0, 0, 0.55))
	c.draw_circle(hc, HEAD / 2.0, Color(XUiSkin.LINE, 0.65), false, 1.5, true)
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var x := 12 + HEAD + 10
	var right := ROW_W - 12
	# 右上状态图标（cell_rows：原状态格的筛选、排序、层数）
	var rows := _rows()
	var sx := right
	for k in range(mini(rows.size(), MAX_ICONS)):
		var row: Dictionary = rows[k]
		var tex := XUiSkin.icon(int(row.icon))
		sx -= 22
		if tex != null:
			c.draw_texture_rect(tex, Rect2(sx, 5, 22, 22), false, Color(1, 1, 1, alpha))
		if int(row.get("stack", 1)) > 1:
			var st := str(row.stack)
			var sw := num.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			c.draw_string_outline(num, Vector2(sx + 22 - sw, 5 + 22), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.85))
			c.draw_string(num, Vector2(sx + 22 - sw, 5 + 22), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, XUiSkin.TEXT)
	if rows.size() > MAX_ICONS:
		sx -= 4
	# 名字＋Lv 行
	var name_col := XUiSkin.TEXT_3 if dead else (XUiSkin.DOWN if float(v.hp) < float(v.mhp) / 4.0 else XUiSkin.TEXT)
	var nm := actor.display_name()
	var name_w := maxf(sx - x - 6, 20)
	nm = XSkinOTBBar.fit(body, nm, name_w, 18)
	var y1 := 6 + 18.0
	c.draw_string(body, Vector2(x, y1), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, name_col)
	var nw := body.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var info := info_text()
	var ix := x + nw + 8
	if ix < sx - 12:
		info = XSkinOTBBar.fit(body, info, sx - 6 - ix, XUiSkin.FS_AUX)
		c.draw_string(body, Vector2(ix, y1), info, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, Color(XUiSkin.TEXT_2, alpha))
	# 三条量条：血、蓝各 1 份，TP 0.6 份（同 XSkinPartyStrip）
	var y2 := 6 + 24 + 12.0
	var avail := right - x
	var unit := (avail - 16) / 2.6
	var bx := float(x)
	var specs := [["hp", 1.0, XUiSkin.HP, XUiSkin.HP_TEXT], ["mp", 1.0, XUiSkin.MP, XUiSkin.MP_TEXT], ["tp", 0.6, XUiSkin.TP, XUiSkin.TP_TEXT]]
	for spec in specs:
		var w: float = unit * spec[1]
		var cur := float(v.get(spec[0], 0))
		var mx := float(v.get("m" + spec[0], 0))
		var txt := XMenu._group(floorf(cur))
		var tw := maxf(num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, 24)
		var bw := maxf(w - tw - 4, 6)
		var track := Rect2(bx, y2 + 2 - XUiSkin.bar_h(spec[0]), bw, XUiSkin.bar_h(spec[0]))
		_pill(ci, track, Color(1, 1, 1, 0.12))
		if mx > 0 and cur > 0:
			_pill(ci, Rect2(track.position, Vector2(track.size.x * clampf(cur / mx, 0, 1), track.size.y)), Color(spec[2], alpha))
		if spec[0] == "hp":
			_shield_seg(ci, track, v)
		c.draw_string(num, Vector2(bx + w - num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, y2 + 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(spec[3], alpha))
		bx += w + 8


## Lv 行：「Lv 等级 · 职业」，有护盾加「盾 数值」，谷雨在队加状态字
func info_text() -> String:
	var v := _v()
	var parts := ["Lv %d" % actor.level]
	var cls := str(actor.class_data().get("name", ""))
	if cls != "":
		parts.append(cls)
	var s := float(v.get("shield", 0.0)) + float(v.get("guyu_shield", 0.0))
	if s > 0.0:
		parts.append("盾 " + shield_text(s))
	var g := str(v.get("guyu_text", ""))
	if g != "":
		parts.append(g)
	return " · ".join(parts)


## 护盾：血条上从现血量到血量＋护盾叠一段浅蓝（折算同原版 shield_segment：按 max(上限, 血＋盾)）
func _shield_seg(ci: RID, track: Rect2, v: Dictionary) -> void:
	var s := float(v.get("shield", 0.0)) + float(v.get("guyu_shield", 0.0))
	if s <= 0.0:
		return
	var mx := maxf(maxf(float(v.mhp), float(v.hp) + s), 1.0)
	var a := track.size.x * minf(float(v.hp) / mx, 1.0)
	var b := track.size.x * minf((float(v.hp) + s) / mx, 1.0)
	if b > a:
		_pill(ci, Rect2(track.position.x + a, track.position.y, b - a, track.size.y), SHIELD_FILL)


static func _pill(ci: RID, r: Rect2, col: Color) -> void:
	if r.size.x <= 0.0:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(3)
	sb.draw(ci, r)


## 整块队伍条的面板底（行在它上面）：默认左 66%→右 46% 暖炭半透烟纱（SMOKE_BACK=false 回到 T096 实心黑面板）
class Back extends Control:
	static var SMOKE_BACK := true
	var _last_smoke_drawn := true
	var count := 4:
		set(v):
			count = v
			_place()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _place() -> void:
		position = Vector2(XSkinSideStatus.panel_x(), XSkinSideStatus.TOP)
		size = Vector2(XSkinSideStatus.ROW_W, count * XSkinSideStatus.ROW_H + PAD_Y * 2.0)
		queue_redraw()

	func _draw() -> void:
		if count <= 0:
			return
		_last_smoke_drawn = SMOKE_BACK
		if not SMOKE_BACK:
			XUiSkin.draw_panel(get_canvas_item(), Rect2(Vector2.ZERO, size))
			for i in range(1, count):
				var y := PAD_Y + i * XSkinSideStatus.ROW_H
				draw_line(Vector2(10, y), Vector2(size.x - 10, y), Color(XUiSkin.LINE, 0.14), 1.0)
			return
		var w := size.x
		var h := size.y
		var cut := 8.0
		var c_l := Color(0.068, 0.052, 0.048, 0.66)
		var c_r := Color(0.052, 0.042, 0.040, 0.46)
		var poly := PackedVector2Array([
			Vector2(cut, 0), Vector2(w - cut, 0), Vector2(w, cut), Vector2(w, h - cut),
			Vector2(w - cut, h), Vector2(cut, h), Vector2(0, h - cut), Vector2(0, cut),
		])
		var cols := PackedColorArray([c_l, c_r, c_r, c_r, c_r, c_l, c_l, c_l])
		draw_polygon(poly, cols)
		# 左侧旧金游丝脊线（上下渐隐）＋上下轻烟细边
		draw_polyline_colors(
			PackedVector2Array([Vector2(0.5, cut), Vector2(0.5, h * 0.5), Vector2(0.5, h - cut)]),
			PackedColorArray([Color(XUiSkin.GOLD, 0.0), Color(XUiSkin.GOLD, 0.50), Color(XUiSkin.GOLD, 0.0)]),
			1.2, true)
		for y_edge in [0.5, h - 0.5]:
			draw_polyline_colors(
				PackedVector2Array([Vector2(cut, y_edge), Vector2(w - cut, y_edge)]),
				PackedColorArray([Color(XUiSkin.GOLD, 0.34), Color(XUiSkin.GOLD, 0.06)]),
				1.0, true)
		for i in range(1, count):
			var y := PAD_Y + i * XSkinSideStatus.ROW_H
			draw_polyline_colors(
				PackedVector2Array([Vector2(10, y), Vector2(w - 10, y)]),
				PackedColorArray([Color(XUiSkin.LINE, 0.16), Color(XUiSkin.LINE, 0.06)]),
				1.0, true)
