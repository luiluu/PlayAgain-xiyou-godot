class_name XPartyFold
extends Control
## 【cc·天启篇·未经审查】T196 战斗右上队伍栏展开／收起（Kyo 11-18：「把队伍栏做成可以展开收缩，跟我们的团队看板一样，要有动效……
## 缩小的队伍栏只显示目前行动的角色」）。只在新界面（XUiSkin.on()）里有；旧界面照原版一行 121 高、没有栏头，不加。
## - 栏头（这个控件本身，在队伍面板最上面 HEAD_H 高）：左边旧金箭头（展开朝下、收起朝右，转 90°）＋「队伍」；点栏头（触屏点）、
##   键盘 Tab、手柄 Back（View／Select）都切换。
## - 动效照团队看板的折叠：0.25 秒，缓动 cubic-bezier(.16,1,.3,1)；箭头一起转。界面动效「关」时直接到位。
## - 收起时只露「焦点角色」一行：焦点＝最近一次轮到行动（XBattleScene._set_active）的我方角色；敌人行动时 _active 为空，焦点不变（不来回跳）。
##   各行放进一个裁剪框：收起＝裁剪框高度从全部行缩到一行，同时所有行往上滚 焦点序号×行高，焦点那一行停在第一格；
##   收起时换焦点＝接着滚到新的那一行（0.25 秒滑过去），旧行淡出、新行淡入。展开时换焦点什么也不动。
## - 展开／收起记在设置 codexPartyExpanded（默认展开，跨战斗、跨存档都记住）。
## - 只是画面：不改战斗流程、顺序、随机数；队伍行照旧由 XBattleScene.status_rows 管（换人时新行加进同一个父节点，这里每帧按序号重排）。
## 回退：ENABLED = false 回到 T196 之前（没有栏头、不裁剪，各行原位）。

static var ENABLED := true

const HEAD_H := 26.0
const TIME := 0.25
const CONFIG_KEY := "codexPartyExpanded"
const TITLE := "队伍"
## 裁剪框左右多留的宽（选中条外晕、行左边的东西不被裁掉）
const CLIP_PAD := 64.0

signal changed

## 每帧取当前队伍行（按出战顺序）：Array[XSideStatus]
var rows_source: Callable
var back: Control
var clip: Control
var inner: Control
var expanded := true
var focus: XBattler = null
## 动画中的量：展开度 k（0 收起～1 展开）、滚动量（行高的倍数）、箭头（0 朝右～1 朝下）
var k := 1.0
var scroll := 0.0
var _k_from := 1.0
var _k_to := 1.0
var _k_t := 1.0
var _s_from := 0.0
var _s_to := 0.0
var _s_t := 1.0
## 各行「是焦点」的权重（收起时决定透明度）：行 → [from, to, t]
var _w := {}
var _hover := false


static func on() -> bool:
	return ENABLED and XUiSkin.on()


## 栏头高：折叠开着才有
static func head_h() -> float:
	return HEAD_H if on() else 0.0


## 设置里记的（默认展开）
static func saved_expanded() -> bool:
	return XConfig.flag(CONFIG_KEY)


## XBattleScene 建完队伍行后调：开着新界面时把各行搬进裁剪框、加栏头；关着返回 null（什么也不动）
static func attach(holder: Control, backdrop: Control, rows: Callable) -> XPartyFold:
	if not on():
		return null
	var f := XPartyFold.new()
	f.rows_source = rows
	f.back = backdrop
	f.clip = Control.new()
	f.clip.name = "PartyFoldClip"
	f.clip.clip_contents = true
	f.clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.inner = Control.new()
	f.inner.name = "PartyFoldRows"
	f.inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.clip.add_child(f.inner)
	var list: Array = rows.call()
	var at := holder.get_child_count()
	for r in list:
		if r is Control and (r as Control).get_parent() == holder:
			at = mini(at, (r as Control).get_index())
	holder.add_child(f.clip)
	holder.move_child(f.clip, at)
	for r in list:
		if r is Control:
			(r as Control).reparent(f.inner, false)
	holder.add_child(f)
	f.expanded = saved_expanded()
	f.k = 1.0 if f.expanded else 0.0
	f._k_from = f.k
	f._k_to = f.k
	for r in list:
		if r is XSideStatus and f.focus == null:
			f.focus = (r as XSideStatus).actor
	f._s_to = float(f.focus_index())
	f._s_from = f._s_to
	f.scroll = f._s_to
	f._apply()
	return f


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	name = "PartyFold"


func _ready() -> void:
	mouse_entered.connect(func():
		_hover = true
		queue_redraw())
	mouse_exited.connect(func():
		_hover = false
		queue_redraw())


func _rows() -> Array:
	return rows_source.call() if rows_source.is_valid() else []


func focus_index() -> int:
	var list := _rows()
	for i in list.size():
		if list[i] is XSideStatus and (list[i] as XSideStatus).actor == focus:
			return i
	return 0


## 轮到谁行动（XBattleScene._set_active）：null（敌人行动、行动之间）不换焦点
func set_focus(a: XBattler) -> void:
	if a == null or a == focus:
		return
	focus = a
	var i := float(focus_index())
	if is_equal_approx(i, _s_to):
		return
	if not _animate():
		scroll = i
		_s_from = i
		_s_to = i
		_s_t = 1.0
	else:
		_s_from = scroll
		_s_to = i
		_s_t = 0.0
	for r in _rows():
		if r is XSideStatus:
			var x := r as XSideStatus
			var on_focus := 1.0 if x.actor == focus else 0.0
			var cur := _weight(x)
			_w[x] = [cur, on_focus, 0.0 if _animate() else 1.0]
	_apply()


## 换人（XBattleScene._swap_sprite_from）：被换下的人是焦点时由换上的人接替；新行按现在的折叠状态摆
func replaced(old: XBattler, h: XBattler) -> void:
	if focus == old:
		focus = h
	for key in _w.keys():
		if not is_instance_valid(key) or (key as XSideStatus).actor == old:
			_w.erase(key)
	_apply()


func toggle() -> void:
	set_expanded(not expanded)


func set_expanded(v: bool, save := true) -> void:
	if v == expanded:
		return
	expanded = v
	if save:
		XConfig.set_flag(CONFIG_KEY, v)
	_k_from = k
	_k_to = 1.0 if v else 0.0
	_k_t = 0.0 if _animate() else 1.0
	if not _animate():
		k = _k_to
	XSound.system(0)
	_apply()


## 界面动效「关」时直接到位
static func _animate() -> bool:
	return XUiSkin.motion() != XUiSkin.Motion.OFF


## 团队看板的缓动 cubic-bezier(.16,1,.3,1)：给时间比例 x，求曲线上的进度
static func ease_board(x: float) -> float:
	return cubic_bezier(clampf(x, 0.0, 1.0), 0.16, 1.0, 0.3, 1.0)


static func cubic_bezier(x: float, x1: float, y1: float, x2: float, y2: float) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	# 先由 x 解出参数 t（牛顿法，退回二分），再算 y
	var t := x
	for i in 8:
		var cx := _bz(t, x1, x2) - x
		var d := _bz_d(t, x1, x2)
		if absf(cx) < 1e-5:
			break
		if absf(d) < 1e-6:
			break
		t = clampf(t - cx / d, 0.0, 1.0)
	if absf(_bz(t, x1, x2) - x) > 1e-4:
		var lo := 0.0
		var hi := 1.0
		for i in 30:
			t = (lo + hi) / 2.0
			if _bz(t, x1, x2) < x:
				lo = t
			else:
				hi = t
	return _bz(t, y1, y2)


static func _bz(t: float, p1: float, p2: float) -> float:
	var u := 1.0 - t
	return 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t


static func _bz_d(t: float, p1: float, p2: float) -> float:
	var u := 1.0 - t
	return 3.0 * u * u * p1 + 6.0 * u * t * (p2 - p1) + 3.0 * t * t * (1.0 - p2)


func _weight(r: XSideStatus) -> float:
	if not _w.has(r):
		return 1.0 if r.actor == focus else 0.0
	var w: Array = _w[r]
	return lerpf(float(w[0]), float(w[1]), ease_board(float(w[2])))


func busy() -> bool:
	if _k_t < 1.0 or _s_t < 1.0:
		return true
	for w in _w.values():
		if float(w[2]) < 1.0:
			return true
	return false


func _process(delta: float) -> void:
	if not busy():
		return
	var step := delta / TIME
	if _k_t < 1.0:
		_k_t = minf(1.0, _k_t + step)
		k = lerpf(_k_from, _k_to, ease_board(_k_t))
	if _s_t < 1.0:
		_s_t = minf(1.0, _s_t + step)
		scroll = lerpf(_s_from, _s_to, ease_board(_s_t))
	for key in _w.keys():
		var w: Array = _w[key]
		if not is_instance_valid(key):
			_w.erase(key)
			continue
		if float(w[2]) < 1.0:
			w[2] = minf(1.0, float(w[2]) + step)
	_apply()


## 现在面板露出几行（小数，动画中途）
func shown_rows() -> float:
	var n := float(_rows().size())
	return lerpf(minf(1.0, n), n, k)


## 按 k、scroll、各行权重摆行、裁剪框、面板底、栏头
func _apply() -> void:
	var list := _rows()
	var n := list.size()
	var top := XSkinSideStatus.TOP
	var x := XSkinSideStatus.panel_x()
	var w := XSkinSideStatus.ROW_W
	position = Vector2(x, top)
	size = Vector2(w, HEAD_H)
	var body_y := top + HEAD_H
	var shown := shown_rows()
	if clip != null:
		clip.position = Vector2(x - CLIP_PAD, body_y)
		clip.size = Vector2(w + CLIP_PAD * 2.0, shown * XSkinSideStatus.ROW_H + XSkinSideStatus.PAD_Y * 2.0)
		inner.position = -clip.position
	var lift := scroll * XSkinSideStatus.ROW_H * (1.0 - k)
	for i in n:
		var r = list[i]
		if not (r is XSideStatus) or not is_instance_valid(r):
			continue
		var row := r as XSideStatus
		if inner != null and row.get_parent() != inner and row.get_parent() != null and row.get_parent() == clip.get_parent():
			row.reparent(inner, false)   # 换人后新行加在旧行原来的父节点（已经是 inner），保险起见
		var home := XSkinSideStatus.row_pos(i)
		row.position = Vector2(home.x, home.y - lift)
		var a := maxf(k, _weight(row))
		row.modulate.a = a
		row.visible = a > 0.02
	if back != null and is_instance_valid(back) and back is XSkinSideStatus.Back:
		var bk := back as XSkinSideStatus.Back
		bk.head = HEAD_H
		bk.rows_shown = shown
		bk.sep_alpha = k
		bk.place()
	queue_redraw()
	changed.emit()


## 整块队伍面板（栏头＋露出的行）的全局矩形（XBattleScene.party_rect 用：指令环、助力位锁定条让开它）
func panel_global_rect() -> Rect2:
	var h := HEAD_H + shown_rows() * XSkinSideStatus.ROW_H + XSkinSideStatus.PAD_Y * 2.0
	return Rect2(global_position, Vector2(size.x, h))


func _gui_input(event: InputEvent) -> void:
	var m := event as InputEventMouseButton
	if m != null and m.pressed and m.button_index == MOUSE_BUTTON_LEFT:
		toggle()
		accept_event()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var key := event as InputEventKey
	var pad := event as InputEventJoypadButton
	var hit := (key != null and key.pressed and not key.echo and key.keycode == KEY_TAB) \
		or (pad != null and pad.pressed and pad.button_index == JOY_BUTTON_BACK)
	if not hit:
		return
	# 状态详情、图鉴等全屏页开着时不切（那时队伍栏被盖住）
	for n in get_tree().get_nodes_in_group(XUiSkin.FULLSCREEN_GROUP):
		if n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
			return
	toggle()
	get_viewport().set_input_as_handled()


## 栏头：旧金箭头（转 90°）＋「队伍」；悬停时字提亮
func _draw() -> void:
	var c := Vector2(16.0, HEAD_H / 2.0 + 1.0)
	var ang := lerpf(0.0, PI / 2.0, k)   # 0 朝右（收起），90° 朝下（展开）
	var s := 4.5
	var pts := PackedVector2Array([Vector2(-s * 0.55, -s), Vector2(s * 0.55, 0), Vector2(-s * 0.55, s)])
	for i in pts.size():
		pts[i] = c + pts[i].rotated(ang)
	var col := Color(XUiSkin.GOLD, 1.0 if _hover else 0.85)
	draw_polyline(pts, col, 1.8, true)
	var f := XUiSkin.font("body")
	var fs := 15
	XUiSkin.ds(self, f, Vector2(30.0, HEAD_H / 2.0 + fs * 0.36 + 1.0), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		XUiSkin.TEXT if _hover else XUiSkin.TEXT_2)
	# 收起时右边写「1 / 全队人数」，看得出还有人没露出来
	var n := _rows().size()
	if n > 1 and k < 0.999:
		var t := "%d / %d" % [focus_index() + 1, n]
		var num := XUiSkin.font("num")
		var tw := num.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		XUiSkin.ds(self, num, Vector2(size.x - 12.0 - tw, HEAD_H / 2.0 + 14 * 0.36 + 1.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(XUiSkin.TEXT_2, 1.0 - k))
