class_name XDifficultyNotice
extends Node
## EnemyNameColorByDifficulty：跨场景的墙钟计时器。默认难度 2；改变时提示 240×30ms。
## 60ms 读配色、30ms 查改变/倒数、32ms 绘制，独立于游戏加速。战斗本身不重新触发提示。

signal painted
static var instance: XDifficultyNotice
const NAMES := ["", "宝宝", "简单", "普通", "困难", "地狱", "天灾", "灭世", "洪荒", "混沌"]
var difficulty := 2
var last_difficulty := 2
var remaining := 0
var showing := false
var opacity := 0
var bounce_y := 10.0
var text := ""
var color := Color.WHITE
var can_paint: Callable
var _ms := 0.0
var _read_at := 60.0
var _tick_at := 30.0
var _paint_at := 32.0
var _last_usec := 0


static func ensure(tree: SceneTree) -> XDifficultyNotice:
	if not is_instance_valid(instance):
		instance = XDifficultyNotice.new()
		instance.name = "XiyouDifficultyNotice"
		tree.root.add_child.call_deferred(instance)
	return instance


func _ready() -> void:
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := (now - _last_usec) / 1000.0
	_last_usec = now
	var current := XState.current.difficulty if XState.current else 2
	advance(elapsed, current, can_paint.is_valid() and can_paint.call(), Engine.get_process_frames())


## 可直接喂真实插件定帧读数；同一时间的回调按原插件注册顺序执行。
func advance(ms: float, current: int, render := true, frame := 0) -> void:
	current = current if current != 0 else 2
	var until := _ms + maxf(0.0, ms)
	while minf(_read_at, minf(_tick_at, _paint_at)) <= until:
		_ms = minf(_read_at, minf(_tick_at, _paint_at))
		if _read_at == _ms:
			difficulty = current
			_read_at += 60.0
		if _tick_at == _ms:
			if current != last_difficulty:
				last_difficulty = current
				remaining = 240
			if remaining > 0:
				remaining -= 1
			_tick_at += 30.0
		if _paint_at == _ms:
			if render:
				paint(frame)
			_paint_at += 32.0
	_ms = until


func paint(frame := 0) -> void:
	showing = remaining > 0
	if showing:
		text = "当前难度：" + (str(NAMES[difficulty]) if difficulty >= 0 and difficulty < NAMES.size() else "undefined")
		color = difficulty_color(difficulty, frame)
		bounce_y = 10.0 + sin((240 - remaining) * 0.1) * 3.0
		opacity = clampi((240 - remaining) * 10 if remaining > 210 else remaining * 6 if remaining < 40 else 255, 0, 255)
	painted.emit()


static func difficulty_color(id: int, frame := 0) -> Color:
	if id != 9:
		return Color(XEnemy.NAME_COLORS.get(id, "#ffffff"))
	# 原插件 HSL(帧数×4,92%,65%)，每个 RGB 分量向下取整。
	var h := float((frame * 4) % 360)
	var c := (1.0 - absf(2.0 * 0.65 - 1.0)) * 0.92
	var x := c * (1.0 - absf(fmod(h / 60.0, 2.0) - 1.0))
	var m := 0.65 - c / 2.0
	var rgb := Vector3(c, x, 0) if h < 60 else Vector3(x, c, 0) if h < 120 else Vector3(0, c, x) if h < 180 else Vector3(0, x, c) if h < 240 else Vector3(x, 0, c) if h < 300 else Vector3(c, 0, x)
	return Color(floorf((rgb.x + m) * 255) / 255, floorf((rgb.y + m) * 255) / 255, floorf((rgb.z + m) * 255) / 255)
