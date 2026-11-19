class_name XGameOverScreen
extends Control
## 【cc·悟空·未经审查】游戏结束画面（Scene_Gameover，O-244，Kyo 2026-11-08 定：全灭回标题，同原版）。
## 原版：停 BGM／BGS、播 System.gameoverMe（Gameover1）、背景是 img/system/GameOver.png（「菜」字，YEP「Scale Game Over」=true
## 拉伸到整屏）、startFadeIn(slowFadeSpeed)；淡入完按确定或点一下 → 淡出 → 回标题（Scene_Title）。没有任何文字。
## 【Kyo 2026-11-08 定】默认把「菜」字图换成「NULL」字图（modes/xiyou/ui/game_over_null.png：照原图的尺寸 816×624、底色渐变与蓝色扫描线、
## 暗红渐变字色、居中位置，用 Trattatello 字体画成，不用外部素材）；音乐、点一下回标题不变。回退：NULL_IMAGE = false 用原版「菜」字图。
## 帧按 _physics_process 计（slowFadeSpeed＝淡入淡出各 24 帧）。

signal finished

const FADE_FRAMES := 24
const NULL_IMAGE_PATH := "res://modes/xiyou/ui/game_over_null.png"

static var NULL_IMAGE := true

var _tex: TextureRect
var _frame := 0
var _fading_out := false
var _pressed := false
var _done := false
var _image_name := ""
## 新界面 2C（T265，XSkin2C 灭印）：建页前由地图填。battle_shot＝全灭那场战斗最后一帧（没有就取建页时的画面）；
## summary＝全灭 B 版两行（GAMEOVER_SUMMARY 关着为空）
var battle_shot: Texture2D = null
var summary: Array = []
var _skin = null   # XSkin2C.GameOverView；旧画法为 null


func _init() -> void:
	name = "XGameOverScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	_tex = TextureRect.new()
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if NULL_IMAGE:
		_tex.texture = _load_null_image()
		if _tex.texture != null:
			_image_name = "NULL"
	if _tex.texture == null:
		var p := XDB.img_path("system", "GameOver")
		if p != "":
			_tex.texture = load(p)
			_image_name = "GameOver"
	add_child(_tex)
	_apply()


func _ready() -> void:
	if not XSkin2C.gameover_on():
		return
	var shot := battle_shot
	if shot == null and DisplayServer.get_name() != "headless":
		var img := get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			shot = ImageTexture.create_from_image(img)
	_skin = XSkin2C.gameover_view(self, shot, summary)
	add_child(_skin)
	_tex.visible = false   # 字图由新画法画（烧开遮罩、20:9 不拉扁）；_tex 留着给 state() 和旧画法
	_apply()


## 已导入就走资源加载；还没导入（本地刚加图、没跑 godot --import）时直接读 png 文件，不至于缺图
func _load_null_image() -> Texture2D:
	if ResourceLoader.exists(NULL_IMAGE_PATH):
		return load(NULL_IMAGE_PATH)
	var img := Image.load_from_file(ProjectSettings.globalize_path(NULL_IMAGE_PATH))
	if img == null:
		return null
	var t := ImageTexture.create_from_image(img)
	return t


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_pressed = true
	accept_event()


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


## Scene_Gameover.update 一次；ok＝这一帧按了确定或点了一下
func step(ok := false) -> void:
	if _done:
		return
	if _fading_out:
		_frame -= 1
		if _frame <= 0:
			_done = true
			finished.emit()
			queue_free()
	elif _skin != null:
		# 新画法：灭印（1.0 秒；简化 0.4 秒淡入；关直接显示）代替 24 帧淡入，中途按确定直接到 NULL 全显；全显后再按才淡出回标题
		if ok and not _skin.shown():
			_skin.skip()
		else:
			_skin.advance()
			_skin.tick_after_shown()
			if ok:
				_fading_out = true
		_frame = FADE_FRAMES if _skin.shown() else 0
	else:
		_frame = mini(FADE_FRAMES, _frame + 1)
		if ok and _frame >= FADE_FRAMES:
			_fading_out = true
	_apply()


func _apply() -> void:
	_tex.modulate.a = float(_frame) / FADE_FRAMES
	if _skin != null:
		_skin.modulate.a = float(_frame) / FADE_FRAMES if _fading_out else 1.0


## 测试用
func state() -> Dictionary:
	return {"frame": _frame, "fading_out": _fading_out, "done": _done, "has_image": _tex.texture != null, "image": _image_name,
		"skin": _skin != null, "intro": _skin.frame if _skin != null else -1, "shown": _skin == null or _skin.shown(), "hint": _skin.hint_alpha() if _skin != null else 0.0}
