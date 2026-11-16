class_name XSkinSelScale
extends Node
## 【cc·天启篇·未经审查】全局选中放大（T024，Kyo 11-16「选中的东西都要稍微放大，不只装备页，其他所有选中都做」）。
## 新界面里会被选中的东西（列表行、页签、角色条、战斗指令球、详情牌按钮、旧 MV 页的光标行……）共用这一份：
## 每个控件挂一个（XSkinSelScale.attach(self)），画的时候 sel(当前选中的键) 告诉它选的是谁，再用 k(键) 取这一项现在的倍数。
## - 新选中的那项 0.12 秒（XUiSkin.SEL_TIME）从 1 长到 peak，刚离开的那项同样缩回 1；界面动效关时直接到位、没有过渡。
## - 页面刚打开时已选中的那项直接是放大的（不从 1 长出来）。
## - 只在动画进行中每帧重画宿主，停住后不占每帧。
## 环形导航（XSkinRingNav）在装备页 v7 时已自带一份同样的过渡（item_scale），那份不动。
## ENABLED＝false：全部回到不放大（可回退）；皮肤关着时宿主本来就不建这个节点。

static var ENABLED := true
## 默认倍数＝XUiSkin.SEL_SCALE（1.15）；挤的地方（战斗指令球、两列列表）宿主自己传小一点的 peak
var peak := XUiSkin.SEL_SCALE
var _cur := {}
var _sel = null
var _primed := false
var _host: CanvasItem


## 挂到宿主下面（内部子节点，不进场景树的子项列表）
static func attach(host: CanvasItem, peak_scale := -1.0) -> XSkinSelScale:
	var s := XSkinSelScale.new()
	s.name = "SelScale"
	s._host = host
	if peak_scale > 0.0:
		s.peak = peak_scale
	host.add_child(s, false, Node.INTERNAL_MODE_BACK)
	return s


func _init() -> void:
	set_process(false)


## 告诉它现在选的是谁（null＝没有选中项，比如列表没焦点）
func sel(key) -> void:
	if not _primed:
		_primed = true
		if key != null:
			_cur[key] = peak   # 刚打开：直接是放大的
	if key == _sel:
		return
	_sel = key
	if key != null and not _cur.has(key):
		_cur[key] = 1.0
	set_process(true)


func selected():
	return _sel


func target(key) -> float:
	return peak if ENABLED and key != null and key == _sel else 1.0


## 这一项现在的倍数
func k(key) -> float:
	if not ENABLED:
		return 1.0
	if XUiSkin.motion() == XUiSkin.Motion.OFF:
		return target(key)
	return float(_cur.get(key, target(key) if key == _sel else 1.0))


## 放大进度 0～1
func frac(key) -> float:
	return clampf((k(key) - 1.0) / maxf(peak - 1.0, 0.001), 0.0, 1.0)


## 推进 delta 秒；有变化返回 true（测试也直接调它）
func advance(delta: float) -> bool:
	var changed := false
	var off := XUiSkin.motion() == XUiSkin.Motion.OFF
	for key in _cur.keys():
		var cur: float = _cur[key]
		var t := target(key)
		var nxt := t if off else move_toward(cur, t, (peak - 1.0) * delta / XUiSkin.SEL_TIME)
		if nxt != cur:
			changed = true
		if nxt == 1.0 and key != _sel:
			_cur.erase(key)
		else:
			_cur[key] = nxt
	return changed


func animating() -> bool:
	for key in _cur.keys():
		if _cur[key] != target(key):
			return true
	return false


func _process(delta: float) -> void:
	if advance(delta) and _host != null:
		_host.queue_redraw()
	if not animating():
		set_process(false)


## ---- 画的时候用的小算式 ----

## 字号放大：base×k，cap>0 时不超过 cap（行高装得下）、也不小于 base
static func fs(base: int, k: float, cap := 0) -> int:
	var v := roundi(base * k)
	if cap > 0:
		v = mini(v, maxi(cap, base))
	return v


## 以中心放大的矩形
static func grow(r: Rect2, k: float) -> Rect2:
	var d := r.size * (k - 1.0) / 2.0
	return Rect2(r.position - d, r.size + d * 2.0)
