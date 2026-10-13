class_name XHangUpOverlay
extends Control
## XdRs_HangUp 的两块画面（地图与战斗场景都显示，盖在窗口与淡出之上），图都来自 pictures/Ui_HangUpTCLH（546×147）：
## - 快捷界面 HangUp_Inter（快捷界面设置开着时）：位置 (20,10)、大小 240×74；底板取图 (64,88,200,44) 放在 (10,28)；
##   按钮取图 (0,88,64,64)，图只剩 59 行，实际 64×59、以中心对齐到 (32,42)，点中后缩到 0.9 倍 8 帧；
##   字号 18「开启/关闭挂机:G」rgb(0,200,0) 在 (64,28) 宽 136 行高 44；字号 14「挂机时间:」同色右对齐到 (0,12,120)、
##   时长白色在 (126,12) 宽 120 行高 18（不在挂机时「---」）。点击范围：按钮中心 ±27 的开区间。
## - 挂机提示 HangUp_Tip（挂机中）：取图 (0,0,560,88)，实际 546×88，放在 ((1280−560)/2, 100)，不透明度 160。
##   原版 drawWord 把「摆烂中.....」画进图的离屏画布，精灵贴图仍是原图，文字从不显示，照做。
## 吃药/卖装备的剩余数量列表（drawHMPU）随第二批设置页做。

signal toggle_requested

const INTER_POS := Vector2(20, 10)
const PANEL_SRC := Rect2(64, 88, 200, 44)
const BUTTON_SRC := Rect2(0, 88, 64, 59)
const BUTTON_CENTER := Vector2(32, 42)
const TIP_SRC := Rect2(0, 0, 546, 88)
const TIP_POS := Vector2(360, 100)
const TEXT_COLOR := Color8(0, 200, 0)

var inter: Control
var tip: TextureRect
var button: Button
var _button_sprite: TextureRect
var _text: XMVCanvas
var _press := 0
var _time := ""


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
	button = Button.new()
	button.name = "HangUpButton"
	button.position = BUTTON_CENTER - Vector2(27, 27)
	button.size = Vector2(54, 54)
	button.focus_mode = Control.FOCUS_NONE
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	for key in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		button.add_theme_stylebox_override(key, StyleBoxEmpty.new())
	inter.add_child(button)
	button.pressed.connect(func():
		press()
		toggle_requested.emit())
	refresh()


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


func press() -> void:
	_button_sprite.scale = Vector2(0.9, 0.9)
	_press = 8


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
