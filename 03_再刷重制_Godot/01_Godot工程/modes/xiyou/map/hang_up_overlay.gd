class_name XHangUpOverlay
extends Control
## XdRs_HangUp 的两块画面（地图与战斗场景都显示，盖在窗口与淡出之上），图都来自 pictures/Ui_HangUpTCLH（546×147）：
## - 快捷界面 HangUp_Inter（快捷界面设置开着时）：位置 (20,10)、大小 240×74；底板取图 (64,88,200,44) 放在 (10,28)；
##   按钮取图 (0,88,64,64)，图只剩 59 行，实际 64×59、以中心对齐到 (32,42)，点中后缩到 0.9 倍 8 帧；
##   字号 18「开启/关闭挂机:G」rgb(0,200,0) 在 (64,28) 宽 136 行高 44；字号 14「挂机时间:」同色右对齐到 (0,12,120)、
##   时长白色在 (126,12) 宽 120 行高 18（不在挂机时「---」）。点击范围：按钮中心 ±27 的开区间。
## - 挂机提示 HangUp_Tip（挂机中）：取图 (0,0,560,88)，实际 546×88，放在 ((1280−560)/2, 100)，不透明度 160。
##   原版 drawWord 把「摆烂中.....」（huWord，颜色 huColor）画进图的离屏画布，精灵贴图仍是原图，文字从不显示。
##   原版缺陷，修好（O-227，rules-bugfix1 照搬清单第 1 条）：照 drawWord 把字画在提示上（0,30 宽 560 行高 30 居中，Bitmap 默认 28 号），
##   跟提示一起 160 不透明度。回退开关 TIP_WORD = false：照原版不显示字。
## drawHMPU：240×222 画布，药品 (5,80) 宽120/行高18，每行下移20；卖出标题宽200，
## 七档摘要 (10,y) 宽190/行高18，按测量宽度换行。O-022：状态变化先清画布，避免原版旧字残留。

signal toggle_requested

const INTER_POS := Vector2(20, 10)
const PANEL_SRC := Rect2(64, 88, 200, 44)
const BUTTON_SRC := Rect2(0, 88, 64, 59)
const BUTTON_CENTER := Vector2(32, 42)
const TIP_SRC := Rect2(0, 0, 546, 88)
const TIP_POS := Vector2(360, 100)
const TEXT_COLOR := Color8(0, 200, 0)
## O-022：摘要随状态清除。false 按状态保留并叠画旧文字，恢复原版残留。
static var CLEAR_SUMMARY := true
static var TIP_WORD := true
## O-460：挂机中黑幕盖住按钮也能点停（v0.01.09 玩家反馈：安卓前台挂了一小时，关挂机关不掉，狂按回城才回去）。
## 遇敌演出（60 帧）和战斗收场淡出（24 帧）的黑幕 XSceneFade 是挡鼠标的，加在挂机界面之后、盖在按钮上，这两段里点按钮
## 整个被吞掉（xiyou_hangup_stop 实测按钮一次按下都没收到，挂机照跑、接着又遇敌）；手机上进出战斗本来就卡几秒，
## 卡顿正落在这两段里，频繁遇敌时按钮大半时间点不到。原版按钮看的是 TouchInput（HangUp_Inter.updateTouch，Scene_Base.update 里
## 地图和战斗场景都跑），这两段照样能点。这里挂机中在 _input 先看点没点在按钮上（鼠标左键、触屏第一指），点中就停，不再经过界面层。
## 不在挂机时（开始挂机）仍走按钮本身。设 false 恢复（黑幕下点不到）。
static var TAP_THROUGH_FADE := true
## O-461：点停之后这么久（毫秒，真实时间）里再点按钮不重新开始（同上反馈：按钮没反应时玩家连点，点中一下停了、
## 下一下又开回来，看上去「关不掉」；手机卡顿时攒着的几下会在卡完后连着送到）。G 键不受影响。设 0 恢复（每下都切换）。
static var RESTART_GUARD_MSEC := 500

var inter: Control
var tip: TextureRect
var tip_text: XMVCanvas
var button: Button
var _button_sprite: TextureRect
var _text: XMVCanvas
var _press := 0
var _time := ""
var _summary: XMVCanvas
var _lines := {}
var _summary_history: Array = []
## 上一次点按钮停挂机的时刻（Time.get_ticks_msec）
var _stopped_msec := -1000000


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := XDB.img_path("pictures", "Ui_HangUpTCLH")
	var img: Texture2D = load(p) if p != "" else null
	tip = _atlas(img, TIP_SRC)
	tip.position = TIP_POS
	tip.modulate.a = 160.0 / 255.0
	tip.visible = false
	add_child(tip)
	tip_text = XMVCanvas.new()
	tip_text.size = Vector2(560, 88)
	tip_text.painter = paint_tip
	tip.add_child(tip_text)
	inter = Control.new()
	inter.position = INTER_POS
	inter.size = Vector2(240, 74)
	inter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inter)
	var panel := _atlas(img, PANEL_SRC)
	panel.position = Vector2(10, 28)
	inter.add_child(panel)
	_button_sprite = _atlas(img, BUTTON_SRC)
	_button_sprite.pivot_offset = BUTTON_SRC.size / 2.0
	_button_sprite.position = BUTTON_CENTER - BUTTON_SRC.size / 2.0
	inter.add_child(_button_sprite)
	_text = XMVCanvas.new()
	_text.size = Vector2(240, 74)
	_text.painter = _paint
	inter.add_child(_text)
	_summary = XMVCanvas.new()
	_summary.size = Vector2(240, 222)
	_summary.clip_contents = true
	_summary.painter = _paint_summary
	inter.add_child(_summary)
	button = Button.new()
	button.name = "HangUpButton"
	button.position = BUTTON_CENTER - Vector2(27, 27)
	button.size = Vector2(54, 54)
	button.focus_mode = Control.FOCUS_NONE
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	for key in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		button.add_theme_stylebox_override(key, StyleBoxEmpty.new())
	inter.add_child(button)
	button.pressed.connect(_tap)
	refresh()


## 点中按钮（按钮本身的 pressed，或挂机中 _input 先接住的点按）
func _tap() -> void:
	if not XKeyMap.first_press(button):  # 触屏一下的第二份按下（O-378，XKeyMap.ONE_PRESS_PER_TAP）
		return
	var now := Time.get_ticks_msec()
	var was_active := XHangUp.current_active()
	if not was_active and RESTART_GUARD_MSEC > 0 and now - _stopped_msec < RESTART_GUARD_MSEC:
		return  # 刚点停又点：不重新开始（O-461）
	press()
	toggle_requested.emit()
	if was_active and not XHangUp.current_active():
		_stopped_msec = now


## 挂机中黑幕盖住按钮时也能点停（O-460，TAP_THROUGH_FADE）：鼠标左键、触屏第一指按下落在按钮上就当点了按钮
func _input(event: InputEvent) -> void:
	if not TAP_THROUGH_FADE or button == null or not button.is_visible_in_tree() or not XHangUp.current_active():
		return
	var at = null
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		at = event.position
	elif event is InputEventScreenTouch and event.pressed and event.index == 0:
		at = event.position
	if at == null or not button.get_global_rect().has_point(at):
		return
	XKeyMap.handled(self)
	_tap()


func _atlas(img: Texture2D, r: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if img:
		var a := AtlasTexture.new()
		a.atlas = img
		a.region = r
		t.texture = a
	t.size = r.size
	return t


func _paint(c: XMVCanvas) -> void:
	c.text(str(XHangUp.params().get("tipWord", "")), 64, 28, 136, "left", TEXT_COLOR, 18, 44)
	c.text("挂机时间:", 0, 12, 120, "right", TEXT_COLOR, 14, 16)
	c.text(_time, 126, 12, 120, "left", XUI.TEXT, 14, 18)


## HangUp_Tip.drawWord
func paint_tip(c: XMVCanvas) -> void:
	if not TIP_WORD:
		return
	var p := XHangUp.params()
	var rgb := str(p.get("huColor", "255,255,255")).split(",")
	var color := Color8(int(rgb[0]), int(rgb[1]), int(rgb[2])) if rgb.size() >= 3 else Color.WHITE
	c.text(str(p.get("huWord", "")), 0, 30, 560, "center", color, 28, 30)


func press() -> void:
	_button_sprite.scale = Vector2(0.9, 0.9)
	_press = 8


func _paint_summary(c: XMVCanvas) -> void:
	if not CLEAR_SUMMARY:
		for lines in _summary_history:
			_paint_lines(c, lines)
	_paint_lines(c, _lines)


func _paint_lines(c: XMVCanvas, lines: Dictionary) -> void:
	var y := 80.0
	for line in lines.get("potions", []):
		c.text(line, 5, y, 120, "left", XUI.TEXT, 14, 18)
		y += 20
	var grades: Array = lines.get("grades", [])
	if grades.is_empty():
		return
	c.text("每 %d 次战斗后卖出的装备品质:" % int(lines.every), 5, y, 200, "left", XUI.TEXT, 14, 18)
	y += 20
	var line := ""
	for grade in grades:
		var candidate := str(grade) if line == "" else line + "、" + str(grade)
		if XUI.font().get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > 190 and line != "":
			c.text(line, 10, y, 190, "left", XUI.TEXT, 14, 18)
			y += 18
			line = str(grade)
		else:
			line = candidate
	if line != "":
		c.text(line, 10, y, 190, "left", XUI.TEXT, 14, 18)


func _physics_process(_delta: float) -> void:
	if _press > 0:
		_press -= 1
		if _press == 0:
			_button_sprite.scale = Vector2.ONE


## 每帧按状态显示/隐藏，时长变化时重画
func refresh() -> void:
	var s := XState.current
	inter.visible = XHangUp.inter_show(s)
	tip.visible = XHangUp.is_active(s)
	var t := XHangUp.time_text(s) if s else "---"
	if t != _time:
		_time = t
		_text.queue_redraw()
	var lines := XHangUpAuto.panel_lines(s) if s and XHangUp.is_active(s) else {}
	if lines != _lines:
		if not CLEAR_SUMMARY and not _lines.is_empty():
			_summary_history.append(_lines)
		_lines = lines
		_summary.queue_redraw()
