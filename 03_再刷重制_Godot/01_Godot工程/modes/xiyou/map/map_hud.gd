class_name XMapHUD
extends Control
## 正式版地图 HUD：SaveHistory_FullData 的备份按钮、MapTransferPlugin 的「地图传送」按钮、TCLH_levelUP_button 的回城枫叶、
## Star_NewMapXy。传送页本身在 ui/map_transfer.gd。点击区域拦截地图移动，菜单/战斗期间由地图隐藏。

signal backup_requested
signal return_requested
signal transfer_requested

const BACKUP_RECT := Rect2(830, 10, 130, 50)
## Sprite_MapTransferButton：x = 1280 − 120 − 140；圆角 10，底色白 0.2（悬停 0.7、按下 0.8），描边黑 0.3，
## 字号 24「地图传送」春绿色 rgba(0,255,127) 透明度 0.4（悬停/按下 0.7）
const TRANSFER_RECT := Rect2(1020, 10, 120, 48)
const RETURN_RECT := Rect2(5, 650, 46, 43)
const DIFFICULTY_TEXT := ["自由模式", "剧情模式 宝宝", "挑战模式 简单", "挑战模式 普通", "神魔挑战 困难", "神魔挑战 地狱", "神话挑战 天灾", "隐藏挑战 灭世", "隐藏特殊挑战 洪荒"]

var backup_button: Button
var transfer_button: Button
var return_button: TextureButton
var coords: XMVCanvas
var _backup_canvas: XMVCanvas
var _transfer_canvas: XMVCanvas
var _last_coords := ""
## 新界面 4A（XSkin4A.HUD_V2）：三个按钮换成右上一排黑底旧金胶囊（触屏能点），坐标与难度收进按钮下面的一枚胶囊；
## 开着时回城枫叶不画贴图、改画胶囊（_return_face）。关着照旧（原位置、原画法）。
var _skinned := false
var _return_face: Control
var _return_tex: Texture2D
const SKIN_GAP := 8.0
const SKIN_ICON := 18.0
## 触屏时按钮排在虚拟键「隐藏／存档」那一组下面（那组高 40、离顶 8）
const SKIN_TOUCH_Y := 60.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	backup_button = Button.new()
	backup_button.name = "BackupButton"
	backup_button.position = BACKUP_RECT.position
	backup_button.size = BACKUP_RECT.size
	backup_button.focus_mode = Control.FOCUS_NONE
	for key in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		backup_button.add_theme_stylebox_override(key, StyleBoxEmpty.new())
	add_child(backup_button)
	_backup_canvas = XMVCanvas.new()
	_backup_canvas.size = BACKUP_RECT.size
	_backup_canvas.painter = _paint_backup
	backup_button.add_child(_backup_canvas)
	backup_button.button_down.connect(_backup_canvas.queue_redraw)
	backup_button.button_up.connect(_backup_canvas.queue_redraw)
	backup_button.pressed.connect(func(): backup_requested.emit())
	transfer_button = Button.new()
	transfer_button.name = "TransferButton"
	transfer_button.position = TRANSFER_RECT.position
	transfer_button.size = TRANSFER_RECT.size
	transfer_button.focus_mode = Control.FOCUS_NONE
	for key in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		transfer_button.add_theme_stylebox_override(key, StyleBoxEmpty.new())
	add_child(transfer_button)
	var transfer_canvas := XMVCanvas.new()
	transfer_canvas.size = TRANSFER_RECT.size
	transfer_canvas.painter = _paint_transfer
	transfer_button.add_child(transfer_canvas)
	_transfer_canvas = transfer_canvas
	for sig in ["button_down", "button_up", "mouse_entered", "mouse_exited"]:
		transfer_button.connect(sig, transfer_canvas.queue_redraw)
	for sig in ["mouse_entered", "mouse_exited"]:
		backup_button.connect(sig, _backup_canvas.queue_redraw)
	transfer_button.pressed.connect(func(): transfer_requested.emit())
	return_button = TextureButton.new()
	return_button.name = "ReturnButton"
	return_button.position = RETURN_RECT.position
	return_button.focus_mode = Control.FOCUS_NONE
	return_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	var p := XDB.img_path("system", "anjian_level_up")
	if p != "":
		return_button.texture_normal = load(p)
	_return_tex = return_button.texture_normal
	add_child(return_button)
	_return_face = Control.new()
	_return_face.name = "SkinFace"
	_return_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_return_face.visible = false
	_return_face.draw.connect(_draw_return_face)
	return_button.add_child(_return_face)
	for sig in ["button_down", "button_up", "mouse_entered", "mouse_exited"]:
		return_button.connect(sig, _return_face.queue_redraw)
	return_button.pressed.connect(func():
		if XKeyMap.first_press(return_button):  # 触屏一下只算一次（O-378，XKeyMap.ONE_PRESS_PER_TAP）
			return_requested.emit())
	coords = XMVCanvas.new()
	# Star_Inter.move(10,10) + setFrame(-50,-50,...) 的 pivot，实际内容原点 (60,60)。
	coords.position = Vector2(60, 60)
	coords.size = Vector2(200, 660)
	coords.painter = _paint_coords
	add_child(coords)
	refresh()


func _paint_backup(c: XMVCanvas) -> void:
	if _skinned:
		_paint_capsule(c, backup_button, "save", "存档备份")
		return
	c.draw_rect(Rect2(Vector2.ZERO, BACKUP_RECT.size), Color(46.0 / 255, 180.0 / 255, 90.0 / 255, 0.45 if backup_button.is_pressed() else 0.18))
	c.text("存档备份", 0, 0, 130, "center", Color("2e9944"), 26, 50)


func _paint_transfer(c: XMVCanvas) -> void:
	if _skinned:
		_paint_capsule(c, transfer_button, "transfer", "地图传送")
		return
	var b := transfer_button
	var hover := b.is_hovered() and not b.disabled
	var fill := 0.8 if b.is_pressed() else (0.7 if hover else 0.2)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, fill)
	box.set_corner_radius_all(10)
	box.set_border_width_all(1)
	box.border_color = Color(0, 0, 0, 0.15)  # 1px 描边以路径为中线，只有内侧一半落在位图里
	box.anti_aliasing = true
	c.draw_style_box(box, Rect2(Vector2.ZERO, TRANSFER_RECT.size))
	c.text("地图传送", 0, 0, TRANSFER_RECT.size.x, "center", Color(0, 1, 127.0 / 255, 0.7 if hover or b.is_pressed() else 0.4), 24, TRANSFER_RECT.size.y)


func coordinate_text() -> String:
	var s := XState.current
	return ("坐标（%d, %d） " % [s.x, s.y]) + XTianqiElements.hud_floor_line(s) if s else ""


func difficulty_text() -> String:
	var s := XState.current
	var tq := XTianqiTrim.difficulty_name(s)  # 天启篇显示五档档名（O-407）
	if tq != "":
		return tq
	if s:
		for i in range(1, DIFFICULTY_TEXT.size()):
			if bool(s.flags.get("DCultyL%d" % i, false)):
				return DIFFICULTY_TEXT[i]
	return DIFFICULTY_TEXT[0]


func _paint_coords(c: XMVCanvas) -> void:
	if _skinned:
		_paint_coords_skin(c)
		return
	c.text(coordinate_text(), 0, 582, 200, "left", Color.WHITE, 18, 0)
	c.text(difficulty_text(), 0, 610, 200, "left", Color.WHITE, 18, 0)


func refresh() -> void:
	coords.visible = XConfig.map_xy()
	var text := coordinate_text() + difficulty_text()
	var sk := XSkin4A.hud_on()
	if sk != _skinned:
		_set_skinned(sk)
		_last_coords = ""
	if text != _last_coords:
		_last_coords = text
		coords.queue_redraw()
	if _skinned:
		_layout_skin()


# ---- 新界面 4A ----
## 胶囊里的字和图标（图标 18、字 18、左右内边距 14）
static func capsule_width(label: String) -> float:
	return ceilf(14.0 + SKIN_ICON + 6.0 + XUiSkin.font("body").get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, XSkin4A.CAP_FS).x + 16.0)


func _set_skinned(v: bool) -> void:
	_skinned = v
	_return_face.visible = v
	return_button.texture_normal = null if v else _return_tex
	if not v:
		backup_button.position = BACKUP_RECT.position
		backup_button.size = BACKUP_RECT.size
		_backup_canvas.size = BACKUP_RECT.size
		transfer_button.position = TRANSFER_RECT.position
		transfer_button.size = TRANSFER_RECT.size
		_transfer_canvas.size = TRANSFER_RECT.size
		return_button.position = RETURN_RECT.position
		return_button.size = _return_tex.get_size() if _return_tex != null else Vector2.ZERO
		coords.position = Vector2(60, 60)
		coords.size = Vector2(200, 660)
	_backup_canvas.queue_redraw()
	_transfer_canvas.queue_redraw()
	coords.queue_redraw()


## 右上一排：回城、存档备份、地图传送（看得见的才排），右边贴安全边距；下面一枚坐标胶囊右对齐
func _layout_skin() -> void:
	var safe := XSkin4A.safe_rect(self)
	var y := safe.position.y + 4.0
	if XUiSkin.touch() and XTouchControls.instance != null:
		y = maxf(y, SKIN_TOUCH_Y)
		# 小A核查 P2-1：排在虚拟键顶上那一组（隐藏／存档）实际底边下面 8——原版虚拟按键的 Save 键高 60，底边到 70
		var top = XTouchControls.instance.group_rects.get("top")
		if top is Rect2 and (top as Rect2).size.y > 0:
			y = maxf(y, (top as Rect2).end.y + 8.0)
	var x := safe.end.x
	var h := XSkin4A.CAP_H
	for pair in [[transfer_button, "地图传送", _transfer_canvas], [backup_button, "存档备份", _backup_canvas], [return_button, "回城", null]]:
		var b: Control = pair[0]
		if not b.visible:
			continue
		var w := capsule_width(pair[1])
		x -= w
		var r := Rect2(x, y, w, h)
		if b.position != r.position or b.size != r.size:
			b.position = r.position
			b.size = r.size
			if pair[2] != null:
				(pair[2] as Control).size = r.size
				(pair[2] as Control).queue_redraw()
			else:
				_return_face.size = r.size
				_return_face.queue_redraw()
		x -= SKIN_GAP
	var cw := _coords_skin_width()
	var cr := Rect2(safe.end.x - cw, y + h + SKIN_GAP, cw, 32.0)
	if coords.position != cr.position or coords.size != cr.size:
		coords.position = cr.position
		coords.size = cr.size
		coords.queue_redraw()


func _paint_capsule(c: CanvasItem, b: BaseButton, icon: String, label: String) -> void:
	var r := Rect2(Vector2.ZERO, b.size)
	var hot := b.is_pressed() or (b.is_hovered() and not b.disabled)
	XSkin4A.draw_capsule(c, r.grow(-0.5), hot, b.disabled)
	var al := 0.45 if b.disabled else 1.0
	XSkin4A.draw_hud_icon(c, icon, Vector2(14.0 + SKIN_ICON / 2.0, r.size.y / 2.0), SKIN_ICON, al)
	var f := XUiSkin.font("body")
	var fs := XSkin4A.CAP_FS
	c.draw_string(f, Vector2(14.0 + SKIN_ICON + 6.0, roundf(r.size.y / 2.0 + fs * 0.36)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(XUiSkin.GOLD, al))


func _draw_return_face() -> void:
	_paint_capsule(_return_face, return_button, "return", "回城")


func _coords_skin_width() -> float:
	var f := XUiSkin.font("body")
	var t := coordinate_text().strip_edges()
	var d := difficulty_text()
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + f.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	return ceilf(w + 14.0 * 2.0 + 20.0)


## 坐标胶囊：次要灰的坐标（含楼层）＋ 旧金的难度
func _paint_coords_skin(c: XMVCanvas) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	XSkin4A.draw_capsule(c, r.grow(-0.5))
	var f := XUiSkin.font("body")
	var t := coordinate_text().strip_edges()
	var base := roundf(r.size.y / 2.0 + 15 * 0.36)
	c.draw_string(f, Vector2(14, base), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, XUiSkin.TEXT_2)
	var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	c.draw_circle(Vector2(14 + tw + 10, r.size.y / 2.0), 1.5, Color(XUiSkin.GOLD, 0.6))
	c.draw_string(f, Vector2(14 + tw + 20, base), difficulty_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, XUiSkin.GOLD)


func set_actions_enabled(backup: bool, return_hub: bool, transfer: bool) -> void:
	backup_button.disabled = not backup
	return_button.disabled = not return_hub
	transfer_button.disabled = not transfer
