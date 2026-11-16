class_name XSkinBattleSkillList
extends XBattleList
## 【cc·天启篇·未经审查】新界面 2A：战斗里的战技／物品列表（样稿 battle：黑面板、标题＋右上现有 MP／TP、
## 每行图标＋名字＋右对齐消耗，能用是常态不写；用不了才在消耗左边写原因（橙）并变暗；底下说明栏写「目标 · 用完剩多少」）。
## 选中、确定、上下循环、翻页、滚轮、点选、右键都继承 XBattleList，XBattleScene 用法不变（rows／top／index 意思相同）。
## 摆放：列表右边贴在行动者左边 37（样稿 452～782 对角色 819），上下以角色为中心、收在画面里。
## 行：{text, icon, enabled, reason, skin_costs: [{text, color, icon}], target, left}（XSkinBattle.decorate 补）

const W := 330.0
const ROW_H := float(XUiSkin.ROW_H_SKILL)   # 44
const VISIBLE := 8                         # 一屏最多 8 行（样稿 8 招）
const HEAD_H := 40.0
const FOOT_H := 52.0
const PAD_X := 8.0
## 列表右边离角色多远（样稿 819−782）
static var GAP_TO_ACTOR := 37.0
## 躲开左下行动顺序条（cc/ui-skin-p1fix，O-484，小A审 v0.7 P1-3：8 行满屏时说明栏被第 7、8 颗圆头像盖住）：
## true（默认）＝列表和行动条横向有重叠时，底边收到条顶上方 OTB_GAP；false＝照旧只收在画面里（可回退）。
static var AVOID_OTB := true
const OTB_GAP := 4.0

var title := ""
var header := ""
var bar: XSkinSelectBar
var back: Control
## T024 选中放大：选中行的图标、名字放大（行高、消耗列不变）
var sel_scale: XSkinSelScale


static func create_list(parent: Control, list: Array, list_title: String, header_text := "") -> XSkinBattleSkillList:
	var w := XSkinBattleSkillList.new()
	w.entries = list
	w.align = "left"
	w.title = list_title
	w.header = header_text
	w.rows = clampi(list.size(), 1, VISIBLE)
	w.padding = 0.0
	w.canvas.visible = false
	w.size = Vector2(W, HEAD_H + w.rows * ROW_H + FOOT_H + 8.0)
	# 面板和选中条都画在字的后面：面板先、选中条后
	w.back = Control.new()
	w.back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.back.show_behind_parent = true
	w.back.size = w.size
	w.back.draw.connect(func(): XUiSkin.draw_panel(w.back.get_canvas_item(), Rect2(Vector2.ZERO, w.back.size)))
	w.add_child(w.back, false, Node.INTERNAL_MODE_FRONT)
	w.bar = XSkinSelectBar.new()
	w.bar.show_behind_parent = true
	w.add_child(w.bar, false, Node.INTERNAL_MODE_FRONT)
	w.sel_scale = XSkinSelScale.attach(w)
	parent.add_child(w)
	w.select(0)
	return w


## 第 i 行在本节点里的矩形
func row_local(i: int) -> Rect2:
	return Rect2(PAD_X, HEAD_H + (i - top) * ROW_H, size.x - PAD_X * 2, ROW_H)


## 选中行在父节点里的矩形（说明卡贴它）
func row_rect(i := -1) -> Rect2:
	if i < 0:
		i = index
	var r := row_local(i)
	r.position += position
	return r


## 说明栏的两段：目标、用完剩多少（用不了时只写原因）
func foot_text(i := -1) -> String:
	if i < 0:
		i = index
	if i < 0 or i >= entries.size():
		return ""
	var e: Dictionary = entries[i]
	if not bool(e.get("enabled", true)):
		return str(e.get("reason", ""))
	var parts := []
	for k in ["target", "left"]:
		if str(e.get(k, "")) != "":
			parts.append(str(e[k]))
	return " · ".join(parts)


## XBattleScene._place_near_actor 转来
func place_for_actor(feet: Vector2, box: Vector2) -> void:
	var x := feet.x - GAP_TO_ACTOR - size.x
	var y := feet.y - 32.0 - size.y / 2.0
	x = clampf(x, 8.0, maxf(8.0, box.x - size.x - 8.0))
	y = clampf(y, 8.0, maxf(8.0, box.y - size.y - 8.0))
	if AVOID_OTB and XSkinBattle.on():
		var otb := XSkinOTBBar.occupied_rect()
		if Rect2(x, y, size.x, size.y).intersects(otb):
			y = maxf(8.0, otb.position.y - OTB_GAP - size.y)
	position = Vector2(x, y)


func refresh() -> void:
	if bar != null and index >= 0 and index < entries.size():
		bar.visible = true
		bar.move_to(row_local(index), not is_inside_tree())
	elif bar != null:
		bar.visible = false
	queue_redraw()


func _paint(_c: XMVCanvas) -> void:
	pass


## 收口批（TOUCH_V2，小A核 P2-2）：按下不立刻选中／确定，上下拖过 SLOP 按行滚；松手没拖过才照旧当一次点（同 XBattleList）
var _drag := XSkinDrag.new()
var _press_event: InputEventMouseButton


func _unhandled_input(event: InputEvent) -> void:
	if XUiSkin.TOUCH_V2 and active and is_visible_in_tree():
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := event as InputEventMouseButton
			if mb.pressed:
				if _hit(mb.position) < 0:
					super._unhandled_input(event)
					return
				_press_event = mb.duplicate() as InputEventMouseButton
				_drag.press(mb.position, float(top) * ROW_H)
				XKeyMap.handled(self)
				return
			if _drag.active():
				var tap := _drag.release()
				XKeyMap.handled(self)
				if tap and _press_event != null:
					super._unhandled_input(_press_event)
				_press_event = null
				return
		elif event is InputEventMouseMotion and _drag.active():
			var to := _drag.motion((event as InputEventMouseMotion).position)
			if not is_nan(to):
				var want := clampi(roundi(to / ROW_H), 0, maxi(entries.size() - rows, 0))
				if want != top:
					_scroll(want - top)
				XKeyMap.handled(self)
			return
	super._unhandled_input(event)


func _hit(p: Vector2) -> int:
	var local := p - position
	if local.x < PAD_X or local.x >= size.x - PAD_X or local.y < HEAD_H or local.y >= HEAD_H + rows * ROW_H:
		return -1
	var i := top + floori((local.y - HEAD_H) / ROW_H)
	return i if i < entries.size() else -1


func _draw() -> void:
	var title_font := XUiSkin.font("title")
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	# 标题＋右上
	draw_string(title_font, Vector2(16, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, XUiSkin.GOLD)
	if header != "":
		draw_string(num, Vector2(16, 28), header, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 32, 16, XUiSkin.TEXT_2)
	# 行
	if entries.is_empty():
		draw_string(body, Vector2(16, HEAD_H + ROW_H * 0.64), "空", HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_LIST, XUiSkin.TEXT_3)
	if sel_scale != null:
		sel_scale.sel(index if index >= 0 else null)
	for i in range(top, mini(top + rows, entries.size())):
		_draw_row(i, body, num)
	# 滚动条
	if entries.size() > rows:
		var bw := 6.0 if XUiSkin.TOUCH_V2 else 2.0   # 收口批：滚动条手指找得到
		var track := Rect2(size.x - bw - 3.0, HEAD_H + 4, bw, rows * ROW_H - 8)
		draw_rect(track, Color(XUiSkin.LINE, 0.18))
		var h := maxf(16.0, track.size.y * rows / entries.size())
		var y := track.position.y + (track.size.y - h) * top / maxf(1.0, entries.size() - rows)
		draw_rect(Rect2(track.position.x, y, track.size.x, h), Color(XUiSkin.LINE, 0.7))
	# 说明栏
	var fy := HEAD_H + rows * ROW_H + 4.0
	draw_line(Vector2(16, fy), Vector2(size.x - 16, fy), Color(XUiSkin.LINE, 0.3), 1.0)
	var ft := foot_text()
	if ft != "":
		var en := index >= 0 and index < entries.size() and bool(entries[index].get("enabled", true))
		draw_multiline_string(body, Vector2(16, fy + 21), ft, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 15, 2,
			XUiSkin.TEXT_2 if en else XUiSkin.DOWN)


func _draw_row(i: int, body: Font, num: Font) -> void:
	var e: Dictionary = entries[i]
	var r := row_local(i)
	var en := bool(e.get("enabled", true))
	var a := 1.0 if en else 0.5
	var cy := r.position.y + r.size.y / 2.0
	var sk := sel_scale.k(i) if sel_scale != null else 1.0
	var tex := XSkinBattle.icon(int(e.get("icon", 0)))
	if tex != null:
		draw_texture_rect(tex, XSkinSelScale.grow(Rect2(r.position.x + 8, cy - 16, 32, 32), sk), false, Color(1, 1, 1, a))
	# 右侧消耗（从右往左）
	var x := r.end.x - 10.0
	for k in range((e.get("skin_costs", []) as Array).size() - 1, -1, -1):
		var c: Dictionary = e.skin_costs[k]
		var t := str(c.get("text", ""))
		var col: Color = c.get("color", XUiSkin.TEXT)
		col.a = a
		var tw := num.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(num, Vector2(x - tw, cy + 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
		x -= tw
		var ic := XSkinBattle.icon(int(c.get("icon", 0)))
		if ic != null:
			x -= 26
			draw_texture_rect(ic, Rect2(x, cy - 12, 24, 24), false, Color(1, 1, 1, a))
		x -= 10
	# 用不了的原因（橙、小字）
	var reason := str(e.get("reason", "")) if not en else ""
	if reason != "":
		var rw := body.get_string_size(reason, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
		draw_string(body, Vector2(x - rw, cy + 5), reason, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, Color(XUiSkin.DOWN, 0.9))
		x -= rw + 10
	# 名字（放不下就截短）
	var nx := r.position.x + 50 + 16.0 * (sk - 1.0)
	var nfs := XSkinSelScale.fs(XUiSkin.FS_LIST, sk, floori(ROW_H * 0.6))
	var name_col: Color = e.get("color", XUiSkin.TEXT) if e.get("color") is Color else XUiSkin.TEXT
	if i == index:
		name_col = Color.WHITE
	name_col.a = a
	if XUiSkin.FONT_V2:   # 收口批（小A核 P2-3）：大字号时先缩字到 15，还放不下加「…」，不再硬裁
		var fit := XSkinList.fit_text(body, str(e.get("text", "")), maxf(20.0, x - nx), nfs, XUiSkin.FS_MIN)
		draw_string(body, Vector2(nx, cy + int(fit[1]) * 0.36), str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1]), name_col)
	else:
		draw_string(body, Vector2(nx, cy + 7), str(e.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, maxf(20.0, x - nx), XUiSkin.FS_LIST, name_col,
			TextServer.JUSTIFICATION_NONE)
