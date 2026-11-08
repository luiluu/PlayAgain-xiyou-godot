class_name XSplashScreen
extends Control
## 【cc·界面·未经审查】启动开场图（MOG_TitleSplashScreen 的 Scene_Splash_Screen；Scene_Boot.start 之后、标题之前）。
## 原版参数：画面持续时间 90、淡入淡出速度 5、画面-1～3＝titles2/Splash_0、Splash_1、Splash_2（画面-4 起空）。
## - 每张：精灵锚点居中放在 (640,360)（图 1280×740，上下各出界 10），不透明度从 0 起每帧 +5，到 255 后再停 90 帧，然后每帧 −5，
##   到 0 换下一张；放完进标题。底下是黑屏（Scene_Base 没有背景）。
## - 跳过：淡入／停留时不透明度 > 60 按确定或点一下 → 直接开始淡出、淡完进标题；淡出时按 → 淡完进标题。
## - 原版 bug（O-239）：create 里 for (i = 0; …) 从 0 数，title_list 的键是 1～10，第 0 项 undefined 不等于 ""，
##   于是先压进一张 loadTitle2(undefined)＝空图，开场先黑屏一整轮（51＋90＋51 帧）才出 Splash_0。重制默认去掉这张空图；
##   BLANK_FIRST_V028 = true 回到原版（先黑一轮）。
## - 一次运行只放一次（原版 Scene_Boot 才进；从游戏回标题不再放）；测试（headless 或命令行带场景／脚本）不放，
##   环境变量 XIYOU_SPLASH=1／0 强制放／不放。图缺时直接进标题。回退：ENABLED = false 不放开场图。
## 天启篇改版起默认不放这三张图，改放 XWarningScreen（见 WARNING_SCREEN）；本类仍管 wanted()／shown。
## 帧按 _physics_process 计（变速齿轮 1.6 倍时同原版按 updateScene 计）。

signal finished

static var ENABLED := true
## 天启篇改版（O-待定·开场声明屏）：true＝放开场声明屏 XWarningScreen 取代下面三张图；false 回到原版三张开场图
static var WARNING_SCREEN := true
static var BLANK_FIRST_V028 := false
static var shown := false

const IMAGES := ["Splash_0", "Splash_1", "Splash_2"]
const DURATION := 90
const FADE := 5

var _tex: Array = []          # 每项 Texture2D 或 null（空图）
var _index := 0               # _splash_data[0]：下一张的序号
var _hold := 0                # _splash_data[1]
var _opacity := 0
var _sprite: TextureRect
var _done := false


## 这次该不该放
static func wanted() -> bool:
	var env := OS.get_environment("XIYOU_SPLASH")
	if env == "1":
		return not shown
	if env == "0" or not ENABLED or shown:
		return false
	if DisplayServer.get_name() == "headless":
		return false
	for a in OS.get_cmdline_args():
		if a.ends_with(".tscn") or a.ends_with(".gd") or a == "-s" or a == "--script":
			return false
	return true


## 盖在 parent 上放一轮；放不了返回 null
static func play(parent: Control) -> XSplashScreen:
	shown = true
	var n := XSplashScreen.new()
	if n._tex.is_empty():
		n.free()
		return null
	n.name = "XSplashScreen"
	parent.add_child(n)
	return n


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	_sprite = TextureRect.new()
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP
	add_child(_sprite)
	var found := false
	for img in IMAGES:
		var p := XDB.img_path("titles2", img)
		if p != "":
			_tex.append(load(p))
			found = true
	if not found:
		_tex = []
		return
	if BLANK_FIRST_V028:
		_tex.push_front(null)
	_next()


## refresh_splash_screen
func _next() -> void:
	if _index >= _tex.size():
		_finish()
		return
	var t = _tex[_index]
	_sprite.texture = t
	if t != null:
		var sz: Vector2 = t.get_size()
		_sprite.size = sz
		_sprite.position = (Vector2(1280, 720) - sz) / 2.0
	_opacity = 0
	_index += 1
	_hold = DURATION
	_apply()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


func _apply() -> void:
	_sprite.modulate.a = _opacity / 255.0


var _pressed := false

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_pressed = true
	accept_event()


## 放开场图时按键都吃掉，不漏给底下的标题
func _input(e: InputEvent) -> void:
	if _done:
		return
	if e.is_action_pressed("ui_accept") or (e is InputEventScreenTouch and e.pressed):
		_pressed = true
	if e is InputEventKey or e is InputEventJoypadButton or e is InputEventScreenTouch:
		XKeyMap.handled(self)


func _physics_process(_delta: float) -> void:
	step(_pressed)
	_pressed = false


## Scene_Splash_Screen.update 一次；ok＝这一帧按了确定或点了一下
func step(ok := false) -> void:
	if _done:
		return
	if _hold <= 0:
		_opacity = maxi(0, _opacity - FADE)
		if ok:
			_index = _tex.size()
		if _opacity <= 0:
			_next()
	else:
		_opacity = mini(255, _opacity + FADE)
		if ok and _opacity > 60:
			_hold = 0
			_index = _tex.size()
		if _opacity >= 255:
			_hold -= 1
	_apply()


## 测试用：现在显示第几张（0 起）、不透明度
func state() -> Dictionary:
	return {"index": _index - 1, "opacity": _opacity, "blank": _sprite.texture == null, "done": _done}
