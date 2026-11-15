class_name XSkinSelectBar
extends Control
## 【cc·天启篇·未经审查】红乙选中条（会动的那条；静态画法在 XUiSkin.draw_select）。
## - 行间滑动 0.09 秒（缓出）；动效关时直接跳。
## - 连按不排队：新目标从「现在画到哪」出发、重新计时，不等上一段走完，也不把几次按键排成几段。
## - 左侧光标 1.6 秒轻呼吸（简化档、动效关时不呼吸，恒亮）。
## 用法：放在列表等容器里（坐标同父节点），move_to(行的矩形)。

var target := Rect2()
var _from := Rect2()
var _t := 1.0
var _dur := XUiSkin.SLIDE_TIME
## 发出过几次滑动（测试看连按）
var slides := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "SelectBar"


## 移到 r；instant 或动效关时直接到
func move_to(r: Rect2, instant := false) -> void:
	if r == target and _t >= 1.0:
		return
	var dur := XUiSkin.slide_time()
	if instant or dur <= 0.0 or target.size == Vector2.ZERO:
		_from = r
		target = r
		_t = 1.0
	else:
		_from = current_rect()
		target = r
		_t = 0.0
		_dur = dur
		slides += 1
	_apply()


## 现在画在哪（滑动途中按缓出插值）
func current_rect() -> Rect2:
	if _t >= 1.0:
		return target
	var k := 1.0 - pow(1.0 - _t, 3.0)
	return Rect2(_from.position.lerp(target.position, k), _from.size.lerp(target.size, k))


func moving() -> bool:
	return _t < 1.0


## 走 delta 秒（_process 每帧调；测试直接调）
func advance(delta: float) -> void:
	if _t < 1.0:
		_t = minf(1.0, _t + delta / maxf(_dur, 0.001))
		_apply()
	elif XUiSkin.breathing():
		queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


func _apply() -> void:
	var r := current_rect()
	position = r.position
	size = r.size
	queue_redraw()


func _draw() -> void:
	XUiSkin.draw_select(get_canvas_item(), Rect2(Vector2.ZERO, size), XUiSkin.breath_alpha())
