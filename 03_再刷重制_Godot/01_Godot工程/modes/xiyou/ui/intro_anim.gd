class_name XIntroAnim
extends Control
## 【cc·界面·未经审查】天启篇启动动画（O-待定，Kyo 2026-11-11 定稿 v8_cc）：开场声明屏之前先放一段 4.47 秒的动画——
## 指尖撑裂画面、裂口撑满后定住、天启之眼睁开，再用自己的眼睑合上。合眼后 0.1 秒压黑，接 XWarningScreen，
## 声明屏结束后标题从黑里用 1.2 秒淡入（fade_in_title）。
## - 视频 content/intro/tianqi_intro_v8.ogv（来历见同目录 README）。成片后段的警告屏和标题是预览，游戏里用真的，所以只剪到合眼。
## - 时间按真实秒计：变速齿轮把 Engine.time_scale 调到 1.6，视频播放和淡出都除掉它，不跟着变快。
## - 跳过：任意键、确定、点一下 → 直接 0.1 秒压黑、接声明屏（声明屏自己有 0.5 秒防连按）。
## - 放不放跟声明屏同一套：XSplashScreen.wanted() 且 WARNING_SCREEN；只在西游（天启篇）标题，入口菜单和「新版」不放。
## 回退：ENABLED = false 不放动画、标题也不淡入（回到声明屏结束直接出标题）。

signal finished

static var ENABLED := true

const VIDEO := "res://content/intro/tianqi_intro_v8.ogv"
## 片长（134 帧／30）：取不到视频自身长度时用
const LENGTH := 134.0 / 30.0
## 合眼后压黑（成片里 3 帧）
const FADE_OUT := 0.1
## 标题从黑里亮起（成片里 36 帧）
const TITLE_FADE_IN := 1.2

var _player: VideoStreamPlayer
var _black: ColorRect           # 盖在视频上，压黑用
var _length := LENGTH
var _t := 0.0                   # 已放的真实秒数
var _ending := false
var _fade := 0.0                # 0～1
var _done := false
var _pressed := false


## 有开关、有视频才放
static func available() -> bool:
	return ENABLED and ResourceLoader.exists(VIDEO)


## 盖在 parent 上放一遍；放不了返回 null
static func play(parent: Control) -> XIntroAnim:
	if not available():
		return null
	var stream = load(VIDEO)
	if not (stream is VideoStream):
		return null
	XSplashScreen.shown = true
	var n := XIntroAnim.new()
	n.name = "XIntroAnim"
	n._player.stream = stream
	parent.add_child(n)
	return n


## 标题从黑里淡入：在 parent 最上面盖一层黑，按真实时间 TITLE_FADE_IN 秒褪掉；不挡点击和按键
static func fade_in_title(parent: Control) -> ColorRect:
	var c := ColorRect.new()
	c.name = "XIntroTitleFade"
	c.color = Color.BLACK
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	var tw := c.create_tween()
	tw.set_speed_scale(1.0 / maxf(Engine.time_scale, 0.001))
	tw.tween_property(c, "modulate:a", 0.0, TITLE_FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(c.queue_free)
	return c


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_player = VideoStreamPlayer.new()
	_player.name = "Video"
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.expand = true
	_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_player)
	_black = ColorRect.new()
	_black.name = "FadeOut"
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_black)


func _ready() -> void:
	var l := _player.get_stream_length()
	if l > 0.0:
		_length = l
	_player.speed_scale = 1.0 / maxf(Engine.time_scale, 0.001)
	_player.play()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_pressed = true
	accept_event()


## 放动画时按键都吃掉，不漏给底下的标题；任意键都算跳过
func _input(e: InputEvent) -> void:
	if _done:
		return
	if e.is_action_pressed("ui_accept") or (e is InputEventScreenTouch and e.pressed) \
			or (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventJoypadButton and e.pressed):
		_pressed = true
	if e is InputEventKey or e is InputEventJoypadButton or e is InputEventScreenTouch:
		XKeyMap.handled(self)


func _process(delta: float) -> void:
	step(delta / maxf(Engine.time_scale, 0.001), _pressed)
	_pressed = false


## 走 dt 真实秒；ok＝这一帧按了键或点了一下
func step(dt: float, ok := false) -> void:
	if _done:
		return
	_t += dt
	if ok:
		_ending = true
	# 放到最后一帧（合眼）就开始压黑（视频放完停在最后一帧，不会闪回黑）
	if not _ending and _t >= _length:
		_ending = true
	if not _ending:
		return
	_fade = minf(1.0, _fade + dt / FADE_OUT)
	_black.color.a = _fade
	if _fade >= 1.0:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	_player.stop()
	finished.emit()
	queue_free()


## 测试用
func state() -> Dictionary:
	return {"t": _t, "length": _length, "ending": _ending, "fade": _fade, "done": _done}
