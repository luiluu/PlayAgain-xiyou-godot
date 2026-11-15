class_name XSkinPartyStrip
extends Control
## 【cc·天启篇·未经审查】紧凑角色条（主菜单的队伍、战斗右上角）：黑面板里一人一行、行高 60，
## 圆头像 42、名字（18）＋「Lv 等级 · 职业」辅助小字、右上状态图标（最多 4 个）、下面一行血（玫粉）、蓝、TP 三条细量条＋窄体数字。
## 行间 1px 线色 14% 分隔；选中的人用红乙选中条（selectable＝true 时）。
## 每人一份字典 {name, level, cls, face（Texture2D）, hp, mhp, mp, mmp, tp, mtp, states:[图标号]}；from_actor 从 XActor 取。

signal index_changed(index: int)
signal activated(index: int)

var members: Array = []
var index := -1
var selectable := false
var row_height := XUiSkin.MEMBER_H
var title := ""
var bar: XSkinSelectBar
const HEAD := 42.0
const TITLE_H := 44.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	bar = XSkinSelectBar.new()
	add_child(bar, false, Node.INTERNAL_MODE_FRONT)
	bar.visible = false
	resized.connect(queue_redraw)


static func from_actor(a: XActor) -> Dictionary:
	var d := a.data()
	var states := []
	for st in a.states():
		var ic := int(st.get("iconIndex", 0))
		if ic > 0:
			states.append(ic)
	return {"name": a.display_name(), "level": a.level, "cls": str(a.class_data().get("name", "")),
		"face": XUiSkin.face(str(d.get("faceName", "")), int(d.get("faceIndex", 0))),
		"hp": a.hp, "mhp": a.mhp, "mp": a.mp, "mmp": a.mmp, "tp": a.tp, "mtp": a.max_tp(), "states": states,
		"look": XTianqiSkinShow.look_seal(a)}   # 天启篇七印外观（3A，#81）：头像外圈本印颜色＋小印


func set_members(arr: Array) -> void:
	members = arr
	custom_minimum_size.y = top_y() + members.size() * row_height + 8
	if index >= members.size():
		index = members.size() - 1
	_place_bar(true)
	queue_redraw()


func top_y() -> float:
	return TITLE_H if title != "" else 4.0


func row_rect(i: int) -> Rect2:
	return Rect2(4, top_y() + i * row_height, size.x - 8, row_height)


func select(i: int) -> void:
	if members.is_empty():
		return
	i = clampi(i, 0, members.size() - 1)
	if i == index:
		return
	index = i
	_place_bar(false)
	index_changed.emit(index)


func _place_bar(instant: bool) -> void:
	if bar == null:
		return
	bar.visible = selectable and index >= 0 and index < members.size()
	if bar.visible:
		bar.move_to(row_rect(index).grow(-2), instant)


func handle_input(event: InputEvent) -> bool:
	if not selectable or members.is_empty():
		return false
	if event.is_action_pressed("ui_up", true):
		select(posmod(index - 1, members.size()))
		return true
	if event.is_action_pressed("ui_down", true):
		select(posmod(index + 1, members.size()))
		return true
	if event.is_action_pressed("ui_accept") and index >= 0:
		activated.emit(index)
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	if not selectable:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in members.size():
			if row_rect(i).has_point(event.position):
				if i == index:
					activated.emit(i)
				else:
					select(i)
				accept_event()
				return


func _draw() -> void:
	var ci := get_canvas_item()
	XUiSkin.shadow_style().draw(ci, Rect2(Vector2.ZERO, size))
	XUiSkin.panel_style().draw(ci, Rect2(Vector2.ZERO, size))
	var head := XUiSkin.font("title")
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	if title != "":
		draw_string(head, Vector2(16, 10 + 21 * 0.9), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, XUiSkin.GOLD)
	for i in members.size():
		var m: Dictionary = members[i]
		var r := row_rect(i)
		if i > 0:
			draw_line(Vector2(r.position.x + 10, r.position.y), Vector2(r.end.x - 10, r.position.y), Color(XUiSkin.LINE, 0.14), 1.0)
		var hc := Vector2(r.position.x + 14 + HEAD / 2.0, r.position.y + r.size.y / 2.0)
		draw_circle(hc, HEAD / 2.0, XUiSkin.ORB_LOW)
		var face: Texture2D = m.get("face")
		if face != null:
			XSkinPartyStrip.draw_round_texture(self, face, hc, HEAD / 2.0 - 2.0)
		draw_circle(hc, HEAD / 2.0, Color(XUiSkin.LINE, 0.65), false, 1.5, true)
		XTianqiSkinShow.draw_look(self, str(m.get("look", "")), hc, HEAD / 2.0)
		var x := r.position.x + 14 + HEAD + 12
		var right := r.end.x - 12
		var y1 := r.position.y + 6 + 18
		var fit := name_fit(body, str(m.get("name", "")), int(m.get("level", 1)), right - x - 80)
		draw_string(body, Vector2(x, y1), fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1], XUiSkin.TEXT)
		var nw := body.get_string_size(fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1]).x
		var info := "Lv %d" % int(m.get("level", 1))
		if str(m.get("cls", "")) != "":
			info += " · " + str(m.cls)
		draw_string(body, Vector2(x + nw + 8, y1), info, HORIZONTAL_ALIGNMENT_LEFT, maxf(right - x - nw - 8 - 80, 10), XUiSkin.FS_AUX, XUiSkin.TEXT_2)
		var states: Array = m.get("states", [])
		var sx := right
		for k in range(mini(states.size(), 4)):
			var tex := XUiSkin.icon(int(states[k]))
			sx -= 22
			if tex != null:
				draw_texture_rect(tex, Rect2(sx, r.position.y + 6, 22, 22), false)
		# 三条量条：血、蓝各 1 份，TP 0.6 份
		var y2 := r.position.y + 6 + 24 + 10
		var avail := right - x
		var unit := (avail - 16) / 2.6
		var bx := x
		for spec in [["hp", 1.0, XUiSkin.HP, XUiSkin.HP_TEXT], ["mp", 1.0, XUiSkin.MP, XUiSkin.MP_TEXT], ["tp", 0.6, XUiSkin.TP, XUiSkin.TP_TEXT]]:
			var w: float = unit * spec[1]
			var v := float(m.get(spec[0], 0))
			var mx := float(m.get("m" + spec[0], 0))
			var txt := str(int(v))
			var tw := maxf(num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x, 26)
			var bw := w - tw - 4
			var track := Rect2(bx, y2 - 3, bw, 5)
			_pill(ci, track, Color(1, 1, 1, 0.12))
			if mx > 0 and v > 0:
				_pill(ci, Rect2(track.position, Vector2(track.size.x * clampf(v / mx, 0, 1), 5)), spec[2])
			draw_string(num, Vector2(bx + w - num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x, y2 + 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, spec[3])
			bx += w + 8


func _pill(ci: RID, r: Rect2, c: Color) -> void:
	if r.size.x <= 0.0:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(3)
	sb.draw(ci, r)


## 圆形裁切画图（头像）：圆多边形＋UV；AtlasTexture 换算到整张图的 UV
## 名字放不下时先缩字（≥14）再加省略号，保住后面「Lv 数字」的宽度（小A核查 3A 顺带：「窃格瓦拉·周 Lv」把等级挤掉）。
## avail：名字＋等级能占的宽度。返回 [名字, 字号]
static func name_fit(f: Font, name: String, level: int, avail: float) -> Array:
	var lv := f.get_string_size("Lv %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
	return XSkinList.fit_text(f, name, maxf(avail - lv - 8, 24.0), 18, 14)


static func draw_round_texture(ci: CanvasItem, tex: Texture2D, c: Vector2, r: float, segments := 32) -> void:
	var src := Rect2(Vector2.ZERO, tex.get_size())
	var base: Texture2D = tex
	if tex is AtlasTexture and (tex as AtlasTexture).atlas != null:
		base = (tex as AtlasTexture).atlas
		src = (tex as AtlasTexture).region
	var full := base.get_size()
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for k in segments:
		var d := Vector2.from_angle(TAU * k / segments)
		pts.append(c + d * r)
		uvs.append((src.position + src.size * (Vector2(0.5, 0.5) + d * 0.5)) / full)
	ci.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, base)
