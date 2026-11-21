class_name XSkinDrag
extends RefCounted
## 【cc·天启篇·未经审查】收口批（TOUCH_V2，小A核 P2-2）：手指拖动滚动的小件，给列表、状态页、装备详情展开、战斗战技列表、战斗结算详单共用。
## 按下 press(位置, 当前滚动值)；移动 motion(位置, 是触屏) 过了死区才算拖，返回「按下时的滚动值＋拖过的像素」该滚到哪（没在拖返回 NAN）；
## 松手 release() 返回这次算不算一次点（没拖过）。
## T339 D3（界面细节规范 5.1）：死区触屏 8／鼠标 5 并扣除（起拖首帧从 0 平滑开始，不再突跳 8～10px）；跨过死区的同一帧就进拖动，没有任何长按延迟；
## 惯性（INERTIA_ENABLED，默认开，Kyo 11-22 定；Motion.OFF 不惯性）：松手按最后 80ms 的平均速度轻惯性滑行，超界最多拉出 24px 再 0.16s 缓出回弹。
## 回退：XUiSkin.DETAIL_V1 = false → 死区回 SLOP（10）、不扣除，也没有惯性。

const SLOP := 10.0   # 旧死区（DETAIL_V1 关时用）
const SLOP_TOUCH := 8.0
const SLOP_MOUSE := 5.0
## 惯性与橡皮筋回弹开关，默认开（Kyo 11-22 定「开」）
static var INERTIA_ENABLED := true
const INERTIA_DECEL := 2200.0
const INERTIA_MAX_T := 0.35
const INERTIA_MIN_V := 60.0
const RUBBER_MAX := 24.0
const RUBBER_BACK_T := 0.16
const SAMPLE_WINDOW := 0.08

var from := Vector2.INF
var base := 0.0
var dragging := false
var _slop_sign := 0.0
var _samples: Array = []   # [秒, 滚动值]
## 最近一次松手的速度（滚动值方向，px/s）
var release_velocity := 0.0
var _iv := 0.0
var _ival := 0.0
var _it := 0.0
var _gliding := false
var _rub := 0.0
var _rub_dir := 0.0
var _rub_edge := 0.0
var _rub_t := -1.0


func active() -> bool:
	return from != Vector2.INF


## 触屏判据：触屏会被引擎模拟成鼠标（device＝DEVICE_ID_EMULATION），或本机是触屏机（同 XUiSkin.note_input）
static func is_touch_event(event: InputEvent) -> bool:
	return (event != null and event.device == InputEvent.DEVICE_ID_EMULATION) or XUiSkin.touch()


static func slop_for(is_touch: bool) -> float:
	if not XUiSkin.detail_on():
		return SLOP
	return SLOP_TOUCH if is_touch else SLOP_MOUSE


func press(p: Vector2, base_value: float) -> void:
	from = p
	base = base_value
	dragging = false
	_slop_sign = 0.0
	_samples.clear()
	release_velocity = 0.0
	stop_inertia()


## 拖着时返回目标滚动值（像素，往上拖为正）；没拖返回 NAN。now＝秒（不给就用系统时钟，测试可传）
func motion(p: Vector2, is_touch := true, now := -1.0) -> float:
	if not active():
		return NAN
	var slop := slop_for(is_touch)
	var dy := from.y - p.y
	if not dragging and absf(dy) >= slop:
		dragging = true
		_slop_sign = signf(dy)
	if not dragging:
		return NAN
	var v := base + dy
	if XUiSkin.detail_on():
		v = base + (dy - _slop_sign * slop)   # 扣除死区：起拖首帧从 0 开始
	var t := now if now >= 0.0 else Time.get_ticks_msec() / 1000.0
	_samples.append([t, v])
	while _samples.size() > 8:
		_samples.pop_front()
	return v


func release() -> bool:
	var tap := active() and not dragging
	release_velocity = _velocity() if dragging else 0.0
	from = Vector2.INF
	dragging = false
	_samples.clear()
	return tap


## 最后 80ms 的平均速度（滚动值方向，px/s）
func _velocity() -> float:
	if _samples.size() < 2:
		return 0.0
	var last: Array = _samples[_samples.size() - 1]
	var first: Array = last
	for s in _samples:
		if float(last[0]) - float(s[0]) <= SAMPLE_WINDOW + 0.0001:
			first = s
			break
	var dt := float(last[0]) - float(first[0])
	return (float(last[1]) - float(first[1])) / dt if dt > 0.0001 else 0.0


# ---- 可选增强：惯性与橡皮筋（INERTIA_ENABLED） ----

static func inertia_on() -> bool:
	return INERTIA_ENABLED and XUiSkin.detail_on() and XUiSkin.motion() != XUiSkin.Motion.OFF


## 松手后开惯性（用 release_velocity）；关着、速度太小返回 false。value＝松手时的滚动值
func begin_inertia(value: float) -> bool:
	stop_inertia()
	if not inertia_on() or absf(release_velocity) < INERTIA_MIN_V:
		return false
	_iv = release_velocity
	_ival = value
	_it = 0.0
	_gliding = true
	return true


func stop_inertia() -> void:
	_gliding = false
	_rub_t = -1.0
	_iv = 0.0


func inertia_active() -> bool:
	return _gliding or _rub_t >= 0.0


## 通用惯性步进：返回这一步的滚动值（范围 [lo, hi]；超界时最多越出 RUBBER_MAX，之后 RUBBER_BACK_T 缓出回边界）；结束后 inertia_active() 为 false
func tick_inertia(delta: float, lo: float, hi: float) -> float:
	if _rub_t >= 0.0:
		_rub_t += delta
		var k := clampf(_rub_t / RUBBER_BACK_T, 0.0, 1.0)
		var e := 1.0 - (1.0 - k) * (1.0 - k)
		_ival = _rub_edge + _rub_dir * _rub * (1.0 - e)
		if k >= 1.0:
			_rub_t = -1.0
			_ival = _rub_edge
		return _ival
	if not _gliding:
		return clampf(_ival, lo, hi)
	_it += delta
	var s := maxf(absf(_iv) - INERTIA_DECEL * delta, 0.0)
	_iv = signf(_iv) * s
	_ival += _iv * delta
	if _ival < lo or _ival > hi:
		_rub_dir = -1.0 if _ival < lo else 1.0
		_rub_edge = lo if _ival < lo else hi
		_rub = minf(absf(_ival - _rub_edge), RUBBER_MAX)
		_ival = _rub_edge + _rub_dir * _rub
		_gliding = false
		_rub_t = 0.0
		return _ival
	if _it >= INERTIA_MAX_T or s <= 0.0:
		_gliding = false
	return _ival
