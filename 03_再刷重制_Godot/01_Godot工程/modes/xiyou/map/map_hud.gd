class_name XMapHUD
extends Control
## 正式版地图 HUD：SaveHistory_FullData 的备份按钮、TCLH_levelUP_button 的回城枫叶、Star_NewMapXy。
## 地图传送及其敌人/掉落页单独接入。点击区域拦截地图移动，菜单/战斗期间由地图隐藏。

signal backup_requested
signal return_requested

const BACKUP_RECT := Rect2(830, 10, 130, 50)
const RETURN_RECT := Rect2(5, 650, 46, 43)
const DIFFICULTY_TEXT := ["自由模式", "剧情模式 宝宝", "挑战模式 简单", "挑战模式 普通", "神魔挑战 困难", "神魔挑战 地狱", "神话挑战 天灾", "隐藏挑战 灭世", "隐藏特殊挑战 洪荒"]

var backup_button: Button
var return_button: TextureButton
var coords: XMVCanvas
var _backup_canvas: XMVCanvas
var _last_coords := ""


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
	return_button = TextureButton.new()
	return_button.name = "ReturnButton"
	return_button.position = RETURN_RECT.position
	return_button.focus_mode = Control.FOCUS_NONE
	return_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	var p := XDB.img_path("system", "anjian_level_up")
	if p != "":
		return_button.texture_normal = load(p)
	add_child(return_button)
	return_button.pressed.connect(func(): return_requested.emit())
	coords = XMVCanvas.new()
	# Star_Inter.move(10,10) + setFrame(-50,-50,...) 的 pivot，实际内容原点 (60,60)。
	coords.position = Vector2(60, 60)
	coords.size = Vector2(200, 660)
	coords.painter = _paint_coords
	add_child(coords)
	refresh()


func _paint_backup(c: XMVCanvas) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, BACKUP_RECT.size), Color(46.0 / 255, 180.0 / 255, 90.0 / 255, 0.45 if backup_button.is_pressed() else 0.18))
	c.text("存档备份", 0, 0, 130, "center", Color("2e9944"), 26, 50)


func coordinate_text() -> String:
	var s := XState.current
	return "坐标<%d,%d> " % [s.x, s.y] if s else ""


func difficulty_text() -> String:
	var s := XState.current
	if s:
		for i in range(1, DIFFICULTY_TEXT.size()):
			if bool(s.flags.get("DCultyL%d" % i, false)):
				return DIFFICULTY_TEXT[i]
	return DIFFICULTY_TEXT[0]


func _paint_coords(c: XMVCanvas) -> void:
	c.text(coordinate_text(), 0, 582, 200, "left", Color.WHITE, 18, 0)
	c.text(difficulty_text(), 0, 610, 200, "left", Color.WHITE, 18, 0)


func refresh() -> void:
	coords.visible = XConfig.map_xy()
	var text := coordinate_text() + difficulty_text()
	if text != _last_coords:
		_last_coords = text
		coords.queue_redraw()


func set_actions_enabled(backup: bool, return_hub: bool) -> void:
	backup_button.disabled = not backup
	return_button.disabled = not return_hub
