class_name XBattleScreen
extends Node2D
## 战斗里的 $gameScreen 闪烁与淡出淡入（rules-gaps11）：Spriteset_Base.createScreenSprites 的 _flashSprite、_fadeSprite。
## 层次同原版：盖在战斗背景、战斗者、动画、伤害数字、连击数之上（Spriteset_Battle 里），压在 Boss 血条（MOG hudField）、
## 伤害记录（Star_Record，插在窗口层前）和全部窗口（消息、日志、状态、行动顺序条）之下。先画闪烁、再画黑幕（addChild 次序）。
## 色调（223，ToneFilter 在 _baseSprite 上，比这两层都低）：战斗里能碰到的数据全是 0（只有大厅 CE10 的复原 0 色调；
## 地图上唯一的非零色调 Map004 事件 76 演完就复原，中间不开战），这里不画。
## 逐帧推进同 Game_Screen.updateFadeOut／updateFadeIn／updateFlash；Game_Screen.onBattleStart 清淡出和闪烁，所以每场新建、从亮起。
## 原版 Scene_Battle.update 先 $gameScreen.update 再跑事件，事件这一帧开始的淡出要下一帧才开始变暗：start_* 记下当帧，当帧不推进。

## Game_Interpreter.fadeSpeed
const FADE_SPEED := 24

var brightness := 255.0
var fade_out_duration := 0
var fade_in_duration := 0
var flash_color := [0.0, 0.0, 0.0, 0.0]
var flash_duration := 0
var _started_frame := -1
## 对照测试用（默认 null＝不记）：设成数组后每帧 step 记 [距开始的帧数, 亮度, 闪烁强度]
var trace = null


## Game_Screen.startFadeOut／startFadeIn
func start_fade(out: bool, duration: int = FADE_SPEED) -> void:
	if out:
		fade_out_duration = duration
		fade_in_duration = 0
	else:
		fade_in_duration = duration
		fade_out_duration = 0
	_started_frame = Engine.get_physics_frames()
	queue_redraw()


## Game_Screen.startFlash（颜色 [r, g, b, 强度]）
func start_flash(color: Array, duration: int) -> void:
	flash_color = [float(color[0]), float(color[1]), float(color[2]), float(color[3])]
	flash_duration = duration
	_started_frame = Engine.get_physics_frames()
	queue_redraw()


## 每物理帧一次（XBattleScene._physics_process）
func step() -> void:
	if _started_frame == Engine.get_physics_frames():
		return
	var changed := false
	if fade_out_duration > 0:
		var d := float(fade_out_duration)
		brightness = (brightness * (d - 1.0)) / d
		fade_out_duration -= 1
		changed = true
	if fade_in_duration > 0:
		var d := float(fade_in_duration)
		brightness = (brightness * (d - 1.0) + 255.0) / d
		fade_in_duration -= 1
		changed = true
	if flash_duration > 0:
		var d := float(flash_duration)
		flash_color[3] *= (d - 1.0) / d
		flash_duration -= 1
		changed = true
	if changed:
		queue_redraw()
	if trace != null and (changed or busy()):
		trace.append([Engine.get_physics_frames() - _started_frame, brightness, float(flash_color[3])])


## _fadeSprite.opacity = 255 - brightness（ScreenSprite：alpha = clamp(值, 0, 255) / 255）
func fade_opacity() -> float:
	return clampf(255.0 - brightness, 0.0, 255.0)


func busy() -> bool:
	return fade_out_duration > 0 or fade_in_duration > 0 or flash_duration > 0


func _draw() -> void:
	# ScreenSprite 画 Graphics 宽高 10 倍的整块（不随镜头缩放露边）；这里节点不跟镜头，盖住整个视口即可
	var r := Rect2(Vector2(-640, -360), Vector2(2560, 1440))
	var fa := clampf(float(flash_color[3]), 0.0, 255.0)
	if fa > 0.0:
		var c := Color8(clampi(roundi(flash_color[0]), 0, 255), clampi(roundi(flash_color[1]), 0, 255), clampi(roundi(flash_color[2]), 0, 255))
		c.a = fa / 255.0
		draw_rect(r, c)
	var o := fade_opacity()
	if o > 0.0:
		draw_rect(r, Color(0, 0, 0, o / 255.0))
