class_name XWarningScreen
extends Control
## 【cc·界面·未经审查】开场声明屏（天启篇改版，O-待定·开场声明屏）：取代 MOG_TitleSplashScreen 的三张开场图（titles2/Splash_0～2）。
## 仿老录像带片头警告的排版：黑底、红底白字警告条、等宽大字写「本游戏免费、禁止倒卖收费」，带一行英文；文字与排版原创，
## 不用任何机构徽章或标志。
## - 帧按 _physics_process 计（变速齿轮下每秒 96 帧）：淡入 FADE 帧 → 停 HOLD 帧（约 5 秒）→ 淡出 FADE 帧 → 进标题。
## - 跳过：显示满 MIN_SKIP 帧后按确定、任意键或点一下 → 直接淡出、淡完进标题（防开机连按误跳）。
## - 放不放沿用 XSplashScreen.wanted()／shown（一次运行一次、测试不放、XIYOU_SPLASH 强制）。
## 回退：XSplashScreen.WARNING_SCREEN = false 回到原版三张开场图。

signal finished

const FADE := 32
const HOLD := 480
const MIN_SKIP := 48

const TITLE := "警　告"
const TITLE_EN := "WARNING"
const LINES := [
	"本游戏为免费游戏，不收取任何费用。",
	"严禁倒卖、收费下载、捆绑销售",
	"或以其他任何方式牟利。",
	"如果你是花钱买到的，你被骗了。",
]
const LINE_EN := "THIS GAME IS FREE. RESALE OR PAID DISTRIBUTION IS PROHIBITED."
const HINT := "按任意键继续"

const RED := Color("b3121b")

var _root: Control             # 整体淡入淡出
var _hint: Label
var _frame := 0                # 已显示帧数（淡入起算）
var _opacity := 0              # 0～255
var _fading_out := false
var _done := false
var _pressed := false


static func play(parent: Control) -> XWarningScreen:
	XSplashScreen.shown = true
	var n := XWarningScreen.new()
	n.name = "XWarningScreen"
	parent.add_child(n)
	return n


static func _mono() -> Font:
	var f := SystemFont.new()
	# 等宽：拉丁字母用等宽，汉字落到系统 CJK 字体（汉字本身等宽）
	f.font_names = PackedStringArray(["Menlo", "Consolas", "Noto Sans Mono CJK SC", "Droid Sans Mono", "monospace"])
	f.font_weight = 700
	return f


static func _label(text: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _mono())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)

	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.size = Vector2(1280, 720)
	add_child(_root)

	# 红底警告条
	var bar := ColorRect.new()
	bar.name = "Bar"
	bar.color = RED
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(140, 96)
	bar.size = Vector2(1000, 112)
	_root.add_child(bar)
	var t := _label(TITLE, 56)
	t.position = Vector2(0, 6)
	t.size = Vector2(1000, 64)
	bar.add_child(t)
	var te := _label(TITLE_EN, 26)
	te.position = Vector2(0, 70)
	te.size = Vector2(1000, 32)
	bar.add_child(te)

	# 正文
	var y := 252.0
	for s in LINES:
		var l := _label(s, 38)
		l.name = "Line"
		l.position = Vector2(0, y)
		l.size = Vector2(1280, 48)
		_root.add_child(l)
		y += 60.0
	var en := _label(LINE_EN, 20, Color(0.85, 0.85, 0.85))
	en.position = Vector2(0, y + 18)
	en.size = Vector2(1280, 28)
	_root.add_child(en)
	_hint = _label(HINT, 18, Color(0.6, 0.6, 0.6))
	_hint.position = Vector2(0, 660)
	_hint.size = Vector2(1280, 26)
	_hint.visible = false
	_root.add_child(_hint)
	_apply()


func _ready() -> void:
	# 录像带感：细扫描线，盖在最上层
	var over := Control.new()
	over.name = "Scanlines"
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over.draw.connect(func():
		var y := 0.0
		while y < 720.0:
			over.draw_line(Vector2(0, y), Vector2(1280, y), Color(0, 0, 0, 0.18), 1.0)
			y += 4.0)
	add_child(over)


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


func _apply() -> void:
	_root.modulate.a = _opacity / 255.0
	if _hint != null:
		_hint.visible = _frame >= MIN_SKIP and not _fading_out


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_pressed = true
	accept_event()


## 显示时按键都吃掉，不漏给底下的标题；任意键都算跳过
func _input(e: InputEvent) -> void:
	if _done:
		return
	if e.is_action_pressed("ui_accept") or (e is InputEventScreenTouch and e.pressed) \
			or (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventJoypadButton and e.pressed):
		_pressed = true
	if e is InputEventKey or e is InputEventJoypadButton or e is InputEventScreenTouch:
		XKeyMap.handled(self)


func _physics_process(_delta: float) -> void:
	step(_pressed)
	_pressed = false


## 走一帧；ok＝这一帧按了键或点了一下
func step(ok := false) -> void:
	if _done:
		return
	_frame += 1
	if ok and _frame > MIN_SKIP:
		_fading_out = true
	if not _fading_out and _frame > FADE + HOLD:
		_fading_out = true
	var stepv := ceili(255.0 / FADE)
	if _fading_out:
		_opacity = maxi(0, _opacity - stepv)
		_apply()
		if _opacity <= 0:
			_finish()
		return
	_opacity = mini(255, _opacity + stepv)
	_apply()


## 测试用
func state() -> Dictionary:
	return {"frame": _frame, "opacity": _opacity, "fading_out": _fading_out, "done": _done}
