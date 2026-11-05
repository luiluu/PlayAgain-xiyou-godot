class_name XSceneFade
extends ColorRect
## MV 场景黑幕（Scene_Base.createFadeSprite／startFadeIn／startFadeOut／updateFade）：盖满画面的黑色 ScreenSprite。
## 由所在场景每帧调用 step()（原版在 Scene_Base.update 里 updateFade），不自己跑 _physics_process，免得和场景的帧序差一帧。
## 淡出：不透明度 += (255 − 不透明度) ÷ 剩余帧；淡入：不透明度 −= 不透明度 ÷ 剩余帧（两者都是线性，第 k 帧 255·k／N）。
## 参照 tests/fixtures/battle_transition_oracle.json（battlefx1）。

var opacity := 0.0    # 0～255，同 Sprite.opacity
var _left := 0
var _sign := 0        # 1 淡入（变透明），-1 淡出（变黑）


func _init() -> void:
	color = Color(0, 0, 0, 0)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Scene_Base.startFadeIn：黑幕 255，duration 帧淡到 0
func start_in(frames: int) -> void:
	_sign = 1
	_left = maxi(frames, 0)
	_set_opacity(255.0)


## Scene_Base.startFadeOut：黑幕 0，duration 帧淡到 255
func start_out(frames: int) -> void:
	_sign = -1
	_left = maxi(frames, 0)
	_set_opacity(0.0)


## Scene_Base.updateFade（一帧）
func step() -> void:
	if _left <= 0:
		return
	var d := float(_left)
	if _sign > 0:
		_set_opacity(opacity - opacity / d)
	else:
		_set_opacity(opacity + (255.0 - opacity) / d)
	_left -= 1


## Scene_Base.isBusy 里的 _fadeDuration > 0
func busy() -> bool:
	return _left > 0


func _set_opacity(v: float) -> void:
	opacity = clampf(v, 0.0, 255.0)
	color.a = opacity / 255.0
