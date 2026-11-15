class_name XSkinStatusPage
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】状态页新布局（盘点清册 #27；手工排，借 XSkinTemplatePage 的骨架：页名、页签、三块、按键提示，不用环、列表、牌）。
## 只管「怎么摆、怎么画」：页、滚动、换人还是 XStatusPage 原来的状态（page／tops／actor_index），这一页每次变了 sync() 重画。
## - 左块：角色牌——圆头像、名字（昵称跟在后面）、Lv · 职业、状态图标、生命／魔法／TP 三条量条（当前 / 上限）、经验条（距下一级）。
## - 中＋右合成一块：顶上页签（状态／加成与抗性／掌握／修行／修行·详细，当前页红乙选中条），下面是这一页的内容：
##   内容就是旧页 XStatusPage.page_ops 的那些字（去掉表头，表头的东西在左边角色牌里），按面板宽缩放摆，字换新字体、
##   旧的系统蓝换成次要字色、「【…】」小标题换旧金，元素色、抗性档位色、品质色照旧；超出一屏可上下滚，右侧细滚动条。
## - 战力（#28）照旧先藏（Kyo 定）：新布局不放战力条和战力按钮。
## 按键：左右换页、上下滚动、Q / E 换人、取消返回（都是旧页的处理）；鼠标点页签换页、滚轮滚动、右键返回。

var scene: XStatusPage
var actor_panel: Control
var page_panel: Control
var page_body: Control
const TAB_H := 40.0
const ROW := 36.0
const OLD_W := 1252.0
const BODY_TOP := 16.0 + 40.0 + 16.0


func _init(s: XStatusPage) -> void:
	scene = s
	name = "SkinStatusPage"
	title = "状态"
	group_key = "actor"
	show_ring = false
	auto_nav = false
	left_w = 300.0
	right_w = 336.0
	currencies = []
	focus = "none"
	hint_list = status_hints()


static func status_hints() -> Array:
	return [["左右", "换页"], ["上下", "滚动"], ["Q / E", "换人"], ["取消", "返回"]]


func _ready() -> void:
	super()
	list_panel.visible = false
	card.visible = false
	actor_panel = Control.new()
	actor_panel.name = "ActorPanel"
	actor_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor_panel.draw.connect(_draw_actor)
	layout.left.add_child(actor_panel)
	page_panel = Control.new()
	page_panel.name = "PagePanel"
	page_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	page_panel.draw.connect(_draw_page_frame)
	page_panel.gui_input.connect(_on_page_gui)
	layout.add_child(page_panel)
	page_body = Control.new()
	page_body.clip_contents = true
	page_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_body.draw.connect(_draw_page_body)
	page_panel.add_child(page_body)
	gui_input.connect(_on_gui)
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_focus("none")
	relayout()


func relayout() -> void:
	super()
	if page_panel == null:
		return
	actor_panel.position = Vector2.ZERO
	actor_panel.size = layout.left.size
	var c := layout.center.position
	var r := layout.right.position + layout.right.size
	page_panel.position = c
	page_panel.size = r - c
	page_body.position = Vector2(XUiSkin.PAD_LG, BODY_TOP)
	page_body.size = Vector2(page_panel.size.x - XUiSkin.PAD_LG * 2, maxf(page_panel.size.y - BODY_TOP - XUiSkin.PAD, ROW))
	actor_panel.queue_redraw()
	page_panel.queue_redraw()
	page_body.queue_redraw()


## 一屏几行
func visible_rows() -> int:
	if page_body == null:
		return 13
	return maxi(1, floori(page_body.size.y / ROW))


## 当前页内容行数（去掉旧页的 6 行表头）
static func content_rows(a: XActor, p: int) -> int:
	return maxi(0, XStatusPage.line_count(a, p) - XStatusPage.HEADER_LINES)


func max_top() -> int:
	return maxi(0, content_rows(scene.actor(), scene.page) - visible_rows())


func sync() -> void:
	if layout == null:
		return
	visible = scene.power_panel == null or not is_instance_valid(scene.power_panel)
	actor_panel.queue_redraw()
	page_panel.queue_redraw()
	page_body.queue_redraw()


## 页签矩形（page_panel 坐标）
func tab_rect(i: int) -> Rect2:
	var names := XStatusPage.page_names()
	var w := (page_panel.size.x - XUiSkin.PAD_LG * 2) / names.size()
	return Rect2(XUiSkin.PAD_LG + i * w, XUiSkin.PAD, w - XUiSkin.GRID, TAB_H)


# ---- 画：左边角色牌 ----

func _draw_actor() -> void:
	var a := scene.actor()
	var ci := actor_panel.get_canvas_item()
	var sz := actor_panel.size
	XUiSkin.shadow_style().draw(ci, Rect2(Vector2.ZERO, sz))
	XUiSkin.panel_style().draw(ci, Rect2(Vector2.ZERO, sz))
	var pad := float(XUiSkin.PAD_LG)
	var head := XUiSkin.font("title")
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var w := sz.x - pad * 2
	# 头像
	var fc := Vector2(sz.x / 2.0, pad + 60)
	actor_panel.draw_circle(fc, 62, XUiSkin.ORB_LOW)
	var face := XUiSkin.face(str(a.data().get("faceName", "")), int(a.data().get("faceIndex", 0)))
	if face != null:
		XSkinPartyStrip.draw_round_texture(actor_panel, face, fc, 58)
	actor_panel.draw_circle(fc, 60, Color(XUiSkin.LINE, 0.55), false, 1.5, true)
	var y := pad + 130.0
	var name := a.display_name()
	var fit := XSkinList.fit_text(head, name, w, XUiSkin.FS_CARD, 18)
	var nw := head.get_string_size(fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1]).x
	actor_panel.draw_string(head, Vector2((sz.x - nw) / 2.0, y + 24), fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1], XUiSkin.TEXT)
	y += 34
	if str(a.nickname) != "":
		var nick := "「%s」" % a.nickname
		var kw := body.get_string_size(nick, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
		actor_panel.draw_string(body, Vector2((sz.x - kw) / 2.0, y + 16), nick, HORIZONTAL_ALIGNMENT_LEFT, w, XUiSkin.FS_AUX, XUiSkin.GOLD)
		y += 22
	var info := "Lv %s" % XMenu._group(a.level)
	var cls := str(a.class_data().get("name", ""))
	if cls != "":
		info += " · " + cls
	var iw := body.get_string_size(info, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX_MAX).x
	actor_panel.draw_string(body, Vector2((sz.x - iw) / 2.0, y + 18), info, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX_MAX, XUiSkin.TEXT_2)
	y += 30
	# 状态图标（最多 6 个，居中）
	var icons := []
	for st in a.states():
		if int(st.get("iconIndex", 0)) > 0 and icons.size() < 6:
			icons.append(int(st.iconIndex))
	if not icons.is_empty():
		var sx := (sz.x - icons.size() * 28.0) / 2.0
		for k in icons.size():
			var tex := XUiSkin.icon(icons[k])
			if tex != null:
				actor_panel.draw_texture_rect(tex, Rect2(sx + k * 28.0, y, 24, 24), false)
		y += 32
	y += 8
	# 量条：生命、魔法、TP、经验
	var terms: Dictionary = XDB.system().get("terms", {})
	var basic: Array = terms.get("basic", [])
	var t := func(i: int, d: String) -> String: return str(basic[i]) if i < basic.size() else d
	var max_lv := a.level >= a.max_level()
	var v1 := float(a.exp_total - a.exp_for_level(a.level))
	var need := float(a.exp_for_level(a.level + 1) - a.exp_total)
	var exp_rate := 1.0 if max_lv else (v1 / (need + v1) if need + v1 > 0 else 0.0)
	var next := str(terms.get("messages", {}).get("expNext", "")).replace("%1", t.call(1, "Lv"))
	var bars := [
		[t.call(3, "HP"), a.hp, a.mhp, XUiSkin.HP, XUiSkin.HP_TEXT, "%s / %s" % [XMenu._group(int(a.hp)), XMenu._group(int(a.mhp))]],
		[t.call(5, "MP"), a.mp, a.mmp, XUiSkin.MP, XUiSkin.MP_TEXT, "%s / %s" % [XMenu._group(int(a.mp)), XMenu._group(int(a.mmp))]],
		[t.call(7, "TP"), a.tp, a.max_tp(), XUiSkin.TP, XUiSkin.TP_TEXT, "%s / %s" % [XMenu._group(int(a.tp)), XMenu._group(int(a.max_tp()))]],
		[next if next != "" else t.call(9, "EXP"), exp_rate, 1.0, XUiSkin.GOLD, XUiSkin.GOLD_LIGHT, "-------" if max_lv else XMenu._group(int(need))],
	]
	for b in bars:
		if y + 46 > sz.y - pad:
			break
		actor_panel.draw_string(body, Vector2(pad, y + 16), str(b[0]), HORIZONTAL_ALIGNMENT_LEFT, w * 0.5, XUiSkin.FS_AUX, XUiSkin.TEXT_2)
		var vt := str(b[5])
		var vw := num.get_string_size(vt, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		actor_panel.draw_string(num, Vector2(pad + w - vw, y + 17), vt, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, b[4])
		var track := Rect2(pad, y + 26, w, 6)
		_pill(ci, track, Color(1, 1, 1, 0.12))
		var mx := float(b[2])
		var rate := clampf(float(b[1]) / mx, 0.0, 1.0) if mx > 0 else 0.0
		if rate > 0:
			_pill(ci, Rect2(track.position, Vector2(track.size.x * rate, track.size.y)), b[3])
		y += 46


static func _pill(ci: RID, r: Rect2, c: Color) -> void:
	if r.size.x <= 0.0:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(3)
	sb.draw(ci, r)


# ---- 画：右边页 ----

func _draw_page_frame() -> void:
	var ci := page_panel.get_canvas_item()
	var sz := page_panel.size
	XUiSkin.shadow_style().draw(ci, Rect2(Vector2.ZERO, sz))
	XUiSkin.panel_style().draw(ci, Rect2(Vector2.ZERO, sz))
	var body := XUiSkin.font("body")
	var names := XStatusPage.page_names()
	for i in names.size():
		var r := tab_rect(i)
		if i == scene.page:
			XUiSkin.draw_select(ci, r, XUiSkin.breath_alpha())
		var t := str(names[i])
		var fit := XSkinList.fit_text(body, t, r.size.x - 12, XUiSkin.FS_AUX_MAX, XUiSkin.FS_AUX)
		var tw := body.get_string_size(fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1]).x
		page_panel.draw_string(body, Vector2(r.position.x + (r.size.x - tw) / 2.0, r.position.y + r.size.y / 2.0 + int(fit[1]) * 0.36), fit[0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1], XUiSkin.TEXT if i == scene.page else XUiSkin.TEXT_2)
	var ly := XUiSkin.PAD + TAB_H + 8
	page_panel.draw_line(Vector2(XUiSkin.PAD_LG, ly), Vector2(sz.x - XUiSkin.PAD_LG, ly), Color(XUiSkin.LINE, 0.14), 1.0)


## 旧页的字色换成新皮肤的：系统蓝→次要字，白→正文；其余（元素、抗性档位、品质、警告红）照旧
static func skin_color(html: String) -> Color:
	var c := Color(html)
	if c.is_equal_approx(XUI.SYSTEM):
		return XUiSkin.TEXT_2
	if c.is_equal_approx(XUI.TEXT):
		return XUiSkin.TEXT
	return c


## 这一页要画的（旧页 page_ops 去掉表头；y 换成内容行号）
static func body_ops(a: XActor, p: int) -> Array:
	var y0 := XStatusPage.LH * XStatusPage.HEADER_LINES
	var out := []
	for op in XStatusPage.page_ops(a, p, 612.0):
		match str(op[0]):
			"text", "icon":
				if float(op[3]) >= y0:
					out.append(op)
			"gauge", "line":
				if float(op[2]) >= y0:
					out.append(op)
			"face":
				pass
	return out


func _draw_page_body() -> void:
	var a := scene.actor()
	var p := scene.page
	var sz := page_body.size
	var sx := (sz.x - 8.0) / OLD_W
	var fs := clampi(roundi(XUI.FONT_SIZE * sx), XUiSkin.FS_MIN, mini(XUiSkin.fs(20), 24) if XUiSkin.FONT_V2 else 20)   # 收口批：上限跟字号设置（行高 36 封 24）
	var body := XUiSkin.font("body")
	var y0 := XStatusPage.LH * XStatusPage.HEADER_LINES
	var top: int = scene.tops[p] if p < scene.tops.size() else 0
	for op in body_ops(a, p):
		match str(op[0]):
			"text":
				var row := (float(op[3]) - y0) / XStatusPage.LH - top
				if row < 0 or (row + 1) * ROW > sz.y + 0.5:
					continue
				var s := str(op[1])
				var col := skin_color(str(op[8]))
				if s.begins_with("【"):
					col = XUiSkin.GOLD
				var x := float(op[2]) * sx
				var w := maxf(float(op[4]) * sx, 1.0)
				var align := HORIZONTAL_ALIGNMENT_LEFT
				match str(op[6]):
					"right":
						align = HORIZONTAL_ALIGNMENT_RIGHT
					"center":
						align = HORIZONTAL_ALIGNMENT_CENTER
				var f2 := fs
				if align == HORIZONTAL_ALIGNMENT_LEFT:
					# 左对齐的名字放不下先缩字（到 14），不压到右边的数
					f2 = int(XSkinList.fit_text(body, s, w, fs, XUiSkin.FS_MIN)[1])
				var tw := body.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, f2).x
				if align != HORIZONTAL_ALIGNMENT_LEFT and tw > w:
					# 放不下时右对齐／居中的往左让（不压到别的列，宁可超出列宽也不截字）
					x -= (tw - w) if align == HORIZONTAL_ALIGNMENT_RIGHT else (tw - w) / 2.0
					w = tw
				page_body.draw_string(body, Vector2(x, row * ROW + ROW / 2.0 + f2 * 0.36), s, align, w if align != HORIZONTAL_ALIGNMENT_LEFT else -1.0, f2, col)
			"icon":
				var row2 := (float(op[3]) - 2.0 - y0) / XStatusPage.LH - top
				if row2 < 0 or (row2 + 1) * ROW > sz.y + 0.5:
					continue
				var tex := XUiSkin.icon(int(op[1]))
				if tex != null:
					page_body.draw_texture_rect(tex, Rect2(float(op[2]) * sx, row2 * ROW + (ROW - 26) / 2.0, 26, 26), false)
	# 行间细线（同列表分隔）与滚动条
	var total := content_rows(a, p)
	var vis := visible_rows()
	if total > vis:
		var sw := 8.0 if XUiSkin.TOUCH_V2 else 4.0   # 收口批：滚动条手指找得到
		var track := Rect2(sz.x - sw, 0, sw, vis * ROW)
		page_body.draw_rect(track, Color(1, 1, 1, 0.06))
		var h := maxf(track.size.y * vis / float(total), 16.0)
		page_body.draw_rect(Rect2(track.position.x, (track.size.y - h) * top / float(maxi(total - vis, 1)), sw, h), Color(XUiSkin.LINE, 0.55))


# ---- 点击 ----

var _drag := XSkinDrag.new()


func _on_page_gui(event: InputEvent) -> void:
	if XUiSkin.TOUCH_V2 and _drag_input(event):
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scene._scroll(-1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		page_panel.accept_event()
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		for i in XStatusPage.page_names().size():
			if tab_rect(i).has_point(mb.position):
				scene.set_page(i)
				page_panel.accept_event()
				return


## 收口批（TOUCH_V2，小A核 P2-2）：属性区手指上下拖＝按行滚（一行 XStatusPage.LH）
func _drag_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag.press(event.position, float(scene.tops[scene.page]) * XStatusPage.LH)
			return false
		var was_drag := _drag.dragging
		_drag.release()
		if was_drag:
			page_panel.accept_event()
		return was_drag
	if event is InputEventMouseMotion:
		var to := _drag.motion(event.position)
		if not is_nan(to):
			var want := roundi(to / XStatusPage.LH)
			if want != int(scene.tops[scene.page]):
				scene._scroll(want - int(scene.tops[scene.page]))
			page_panel.accept_event()
			return true
	return false


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		scene.cancel()
