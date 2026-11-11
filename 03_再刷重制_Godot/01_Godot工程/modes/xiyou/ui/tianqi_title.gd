class_name XTianqiTitle
extends Control
## 【cc·Pro·未经审查】天启篇标题页（O-306）：底图 T1、Logo T2、五个两态菜单字效 T3、光标 T4（素材来历见 content/title/README.md）。
## - 接住启动动画 v8（合眼收尾）：play_entrance() 照 v8 成片后段的时间线——全黑 → 1.2 秒亮起（眼睛闭着，贴 eye_0）
##   → 淡入开始后第 26 帧起每帧换下一张睁眼帧，7 帧睁完、去掉贴片 → 睁眼开始后第 10～30 帧 Logo 从下方 8 像素上浮淡入
##   → 菜单 0.3 秒淡入。时间按真实秒计（除掉 Engine.time_scale，同 XIntroAnim）。进场中任意键、点一下直接跳到最终画面。
## - 不调 play_entrance()（从游戏回标题、读档页取消、没放启动动画）：一建好就是最终画面。
## - 五项（新的游戏、旧的回忆、游戏设置、游戏成就、检查更新）的功能由 setup(actions) 传进来，本类不引用 entry.gd；
##   没传或列在 disabled 里的项灰掉，按确定不执行、上下键跳过。另有开发构建用的「返回版本选择」（传 back_to_menu 才有）。
## - 选中：键盘上下（首尾循环）、手柄十字键、鼠标悬停、触屏点按；确定键／点击执行。选中项用两态图上半并放大到 1.1 倍，
##   未选中用下半、0.9 倍（照菜单动效 v2 样张量的），0.12 秒过渡；光标 T4 缩到 0.4 倍放在选中项左侧，切换时从左 4 像素 0.2 秒减速滑入。
## - extras：给 entry.gd 放版本号、导入／导出存档、「继续」的层，跟菜单一起淡入。
## 回退：ENABLED = false（available() 为假）时 entry.gd 照旧走原版标题；XIntroAnim.ENABLED = false 时 play_entrance() 不做进场。

signal entrance_finished

static var ENABLED := true

const DIR := "res://content/title/"
const BG := DIR + "bg.png"
const LOGO := DIR + "logo.png"
const CURSOR := DIR + "cursor.png"
const EYE_COUNT := 7
## 五项顺序照菜单动效 v2 样张
const COMMANDS := [
	{"key": "new_game", "text": "新的游戏", "image": "cmd_new_game.png"},
	{"key": "load", "text": "旧的回忆", "image": "cmd_load.png"},
	{"key": "options", "text": "游戏设置", "image": "cmd_options.png"},
	{"key": "achievements", "text": "游戏成就", "image": "cmd_achievements.png"},
	{"key": "check_update", "text": "检查更新", "image": "cmd_check_update.png"},
]

## 1280×720 画面里的位置（v8 合成脚本与睁眼帧 位置.txt）
const EYE_RECT := Rect2(611, 132, 307, 297)
const LOGO_POS := Vector2(335, 7)
const LOGO_WIDTH := 610.0
const LOGO_RISE := 8.0
## 菜单（菜单动效 v2 第 2 秒样张量的）：五项竖排，横向中心 640，第一项中心 y 390，行距 50
const MENU_CENTER_X := 640.0
const MENU_TOP_Y := 390.0
const MENU_GAP := 50.0
const SCALE_ON := 1.1
const SCALE_OFF := 0.9
const SCALE_TIME := 0.12
const DISABLED_ALPHA := 0.45
## 光标：缩到 0.4 倍，三角形右缘离选中字左缘 7 像素；切换时从左 4 像素处 0.2 秒减速滑入
const CURSOR_SCALE := 0.4
const CURSOR_GAP := 7.0
const CURSOR_SLIDE := 4.0
const CURSOR_TIME := 0.2
## 光标图里三角形的范围（36×50 图，不透明部分）
const CURSOR_ART := Rect2(9, 14, 20, 22)
## 按钮图里字的左缘（200 宽，字在 20～179）
const TEXT_LEFT := 20.0

## 进场时间线（v8 成片 30 帧／秒，帧号从标题开始淡入算）
const FPS := 30.0
const FADE_FRAMES := 36.0       # T_IN：1.2 秒从黑里亮起
const OPEN0 := 26               # 睁眼开始
const LOGO0 := 36.0             # OPEN0 + 10
const LOGO1 := 56.0             # OPEN0 + 30
const MENU_FADE := 0.3          # Logo 到位后菜单淡入（秒）

var stage: Control              # 1280×720 美术层（底图、睁眼贴片、Logo），按 cover 缩放铺满
var bg: TextureRect
var eye: TextureRect
var logo: TextureRect
var menu: Control               # 五项和光标
var extras: Control             # entry.gd 往这里加版本号、导入导出、继续
var cursor: TextureRect
var back_button: Button
var black: ColorRect

var _items: Array = []          # [{key, node, rect, top, bottom, enabled, fn, k}]
var _sel := 0
var _cursor_t := CURSOR_TIME
var _eye_tex: Array = []
var _entering := false
var _t := 0.0
var _skip := false


## 开关开着、天启篇开着、素材都在
static func available() -> bool:
	if not (ENABLED and XTianqi.ENABLED):
		return false
	for p in files():
		if not ResourceLoader.exists(p):
			return false
	return true


static func files() -> Array:
	var out := [BG, LOGO, CURSOR]
	for c in COMMANDS:
		out.append(DIR + c.image)
	for i in EYE_COUNT:
		out.append(DIR + "eye_%d.png" % i)
	return out


func _init() -> void:
	name = "XTianqiTitle"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## actions：键 new_game、load、options、achievements、check_update、back_to_menu → Callable。
## disabled：要灰掉的键（如没有存档时的 "load"）。没传的项也灰掉。
func setup(actions: Dictionary, disabled: Array = []) -> XTianqiTitle:
	for c in get_children():
		c.free()
	_items.clear()
	stage = Control.new()
	stage.name = "Stage"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size = Vector2(1280, 720)
	add_child(stage)
	bg = _tex_rect("Background", load(BG))
	bg.size = Vector2(1280, 720)
	stage.add_child(bg)
	_eye_tex.clear()
	for i in EYE_COUNT:
		_eye_tex.append(load(DIR + "eye_%d.png" % i))
	eye = _tex_rect("EyeLid", _eye_tex[0])
	eye.position = EYE_RECT.position
	eye.size = EYE_RECT.size
	eye.visible = false
	stage.add_child(eye)
	var lt: Texture2D = load(LOGO)
	logo = _tex_rect("Logo", lt)
	logo.size = Vector2(LOGO_WIDTH, LOGO_WIDTH * lt.get_height() / lt.get_width())
	logo.position = LOGO_POS
	stage.add_child(logo)

	menu = Control.new()
	menu.name = "Menu"
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	for i in COMMANDS.size():
		var c: Dictionary = COMMANDS[i]
		var fn = actions.get(c.key)
		_add_item(i, c, fn if fn is Callable else Callable(), fn is Callable and not disabled.has(c.key))
	cursor = _tex_rect("Cursor", load(CURSOR))
	cursor.size = cursor.texture.get_size()
	cursor.scale = Vector2.ONE * CURSOR_SCALE
	menu.add_child(cursor)

	extras = Control.new()
	extras.name = "Extras"
	extras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	extras.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(extras)
	back_button = null
	if actions.get("back_to_menu") is Callable:
		back_button = Button.new()
		back_button.name = "ReturnToMenu"
		back_button.text = "返回版本选择"
		back_button.focus_mode = Control.FOCUS_NONE
		back_button.add_theme_font_size_override("font_size", 16)
		back_button.position = Vector2(12, 720 - 52)
		back_button.size = Vector2(150, 40)
		back_button.pressed.connect(actions.back_to_menu)
		extras.add_child(back_button)

	black = ColorRect.new()
	black.name = "EntranceBlack"
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.visible = false
	add_child(black)

	_sel = 0
	while _sel < _items.size() - 1 and not _items[_sel].enabled:
		_sel += 1
	for j in _items.size():
		_items[j].k = 1.0 if j == _sel else 0.0
	_layout()
	_show_final()
	return self


func _tex_rect(n: String, tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.name = n
	r.texture = tex
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	return r


func _add_item(i: int, c: Dictionary, fn: Callable, enabled: bool) -> void:
	var tex: Texture2D = load(DIR + c.image)
	var w := float(tex.get_width())
	var h := tex.get_height() / 2.0
	var b := Button.new()
	b.name = "TitleCommand_" + str(c.key)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.size = Vector2(w, h)
	b.pivot_offset = b.size / 2.0
	b.tooltip_text = ""
	b.modulate.a = 1.0 if enabled else DISABLED_ALPHA
	var item := {"key": c.key, "node": b, "enabled": enabled, "fn": fn, "k": 0.0,
		"top": _atlas(tex, Rect2(0, 0, w, h)), "bottom": _atlas(tex, Rect2(0, h, w, h))}
	var r := TextureRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture = item.bottom
	r.size = b.size
	b.add_child(r)
	item.rect = r
	b.mouse_entered.connect(func(): if not _entering and enabled and _sel != i: select(i))
	b.pressed.connect(func(): if not _entering: activate(i))
	menu.add_child(b)
	_items.append(item)


func _atlas(tex: Texture2D, r: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = r
	return a


## 1280×720 坐标换算（同 entry.gd 的 _pos：横向居中，纵向按比例）
func _pos(p: Vector2) -> Vector2:
	var vs := _view_size()
	return Vector2(p.x + (vs.x - 1280.0) / 2.0, p.y * vs.y / 720.0)


func _view_size() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)


func _layout() -> void:
	if stage == null:
		return
	var vs := _view_size()
	var s := maxf(vs.x / 1280.0, vs.y / 720.0)
	stage.scale = Vector2(s, s)
	stage.position = (vs - Vector2(1280, 720) * s) / 2.0
	for i in _items.size():
		var b: Button = _items[i].node
		b.position = _pos(Vector2(MENU_CENTER_X, MENU_TOP_Y + MENU_GAP * i)) - b.size / 2.0
	if back_button:
		back_button.position = Vector2(12, vs.y - 52)
	_apply_items()
	_place_cursor()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_RESIZED:
		_layout.call_deferred()


# ---- 选中与执行 ----

## 正在新标题页（没被别的页面盖住）：entry.gd 的 is_title_page() 接上它，安卓返回键靠它判断顶层
func is_title_page() -> bool:
	return is_inside_tree() and visible and not is_queued_for_deletion() and not _items.is_empty()


func selected() -> int:
	return _sel


func item_enabled(i: int) -> bool:
	return i >= 0 and i < _items.size() and _items[i].enabled


func select(i: int) -> void:
	if i < 0 or i >= _items.size():
		return
	if i != _sel:
		_cursor_t = 0.0
	_sel = i
	_apply_items()
	_place_cursor()


## 上下移动，跳过灰掉的项，首尾循环
func move(step: int) -> void:
	var n := _items.size()
	var i := _sel
	for k in n:
		i = (i + step + n) % n
		if _items[i].enabled:
			break
	select(i)


func activate(i := -1) -> bool:
	if i < 0:
		i = _sel
	if i < 0 or i >= _items.size() or not _items[i].enabled:
		return false
	if i != _sel:
		select(i)
	var fn: Callable = _items[i].fn
	fn.call()
	return true


func _apply_items() -> void:
	for j in _items.size():
		var it: Dictionary = _items[j]
		it.rect.texture = it.top if j == _sel else it.bottom
		var e := 1.0 - pow(1.0 - float(it.k), 2.0)
		it.node.scale = Vector2.ONE * lerpf(SCALE_OFF, SCALE_ON, e)


func cursor_target() -> Vector2:
	var b: Button = _items[_sel].node
	var center := b.position + b.size / 2.0
	var text_left := center.x - (b.size.x / 2.0 - TEXT_LEFT) * SCALE_ON
	var art_right := (CURSOR_ART.position.x + CURSOR_ART.size.x) * CURSOR_SCALE
	var art_mid := (CURSOR_ART.position.y + CURSOR_ART.size.y / 2.0) * CURSOR_SCALE
	return Vector2(text_left - CURSOR_GAP - art_right, center.y - art_mid)


func _place_cursor() -> void:
	if cursor == null or _items.is_empty():
		return
	var u := clampf(_cursor_t / CURSOR_TIME, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - u, 3.0)
	cursor.position = cursor_target() - Vector2(CURSOR_SLIDE * (1.0 - e), 0)


# ---- 进场 ----

## 只在启动动画放完、声明屏结束后调一次。XIntroAnim.ENABLED = false 时不做进场。
func play_entrance() -> void:
	if not XIntroAnim.ENABLED or _items.is_empty():
		return
	_entering = true
	_t = 0.0
	_skip = false
	black.visible = true
	eye.visible = true
	_apply_entrance()


func entering() -> bool:
	return _entering


func skip_entrance() -> void:
	if _entering:
		_show_final()


func _show_final() -> void:
	var was := _entering
	_entering = false
	if black:
		black.visible = false
		black.color.a = 0.0
	if eye:
		eye.visible = false
	if logo:
		logo.modulate.a = 1.0
		logo.position = LOGO_POS
	if menu:
		menu.modulate.a = 1.0
		extras.modulate.a = 1.0
	if was:
		entrance_finished.emit()


static func _sstep(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## 睁眼贴片：-1＝不贴（已睁开）
static func eye_frame_at(f: float) -> int:
	var n := int(floor(f + 0.001))  # 累加误差：第 26 帧可能算成 25.9999
	if n < OPEN0:
		return 0
	var k := n - OPEN0 + 1
	return k if k < EYE_COUNT else -1


static func entrance_length() -> float:
	return LOGO1 / FPS + MENU_FADE


func _apply_entrance() -> void:
	var f := _t * FPS
	black.color.a = 1.0 - pow(_sstep(0.0, FADE_FRAMES, f), 1.2)
	var ef := eye_frame_at(f)
	eye.visible = ef >= 0
	if ef >= 0:
		eye.texture = _eye_tex[ef]
	var lk := _sstep(LOGO0, LOGO1, f)
	logo.modulate.a = lk
	logo.position = LOGO_POS + Vector2(0, LOGO_RISE * (1.0 - lk))
	var mk := clampf((_t - LOGO1 / FPS) / MENU_FADE, 0.0, 1.0)
	menu.modulate.a = mk
	extras.modulate.a = mk


## 走 dt 真实秒（测试直接调）
func step(dt: float) -> void:
	if _entering:
		_t += dt
		if _skip or _t >= entrance_length():
			_show_final()
		else:
			_apply_entrance()
	var moved := false
	for j in _items.size():
		var target := 1.0 if j == _sel else 0.0
		var k: float = _items[j].k
		if k != target:
			_items[j].k = move_toward(k, target, dt / SCALE_TIME)
			moved = true
	if moved:
		_apply_items()
	if _cursor_t < CURSOR_TIME:
		_cursor_t = minf(CURSOR_TIME, _cursor_t + dt)
	_place_cursor()


func _process(delta: float) -> void:
	step(delta / maxf(Engine.time_scale, 0.001))


## 进场中：任意键、手柄键、点一下都跳到最终画面，并吃掉这一下（不漏给菜单）
func _input(e: InputEvent) -> void:
	if not _entering:
		return
	var press: bool = (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventJoypadButton and e.pressed) \
		or (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if press:
		_skip = true
		_show_final()
	if press or e is InputEventMouseButton or e is InputEventScreenTouch:
		XKeyMap.handled(self)


func _unhandled_input(e: InputEvent) -> void:
	if _entering or not is_title_page():
		return
	if e.is_action_pressed("ui_down") or e.is_action_pressed("ui_up"):
		move(1 if e.is_action_pressed("ui_down") else -1)
		XKeyMap.handled(self)
	elif e.is_action_pressed("ui_accept"):
		activate()
		XKeyMap.handled(self)


## 测试用
func state() -> Dictionary:
	return {"entering": _entering, "t": _t, "eye_visible": eye.visible, "eye_frame": _eye_tex.find(eye.texture) if eye.visible else -1,
		"logo_alpha": logo.modulate.a, "logo_y": logo.position.y, "menu_alpha": menu.modulate.a, "black": black.color.a if black.visible else 0.0,
		"sel": _sel, "cursor": cursor.position, "cursor_target": cursor_target()}


func item(i: int) -> Dictionary:
	return _items[i]


func item_count() -> int:
	return _items.size()


## 按钮右上角红点（「检查更新」查到新版时 entry.gd 点亮）；没有这一项就什么都不做。返回红点节点（关着时为 null）。
func set_badge(key: String, on: bool) -> Control:
	for it in _items:
		if str(it.key) != key:
			continue
		var b: Button = it.node
		var dot := b.get_node_or_null("Badge") as Panel
		if not on:
			if dot != null:
				dot.queue_free()
				b.remove_child(dot)
			return null
		if dot == null:
			dot = Panel.new()
			dot.name = "Badge"
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.9, 0.15, 0.15)
			sb.set_corner_radius_all(8)
			dot.add_theme_stylebox_override("panel", sb)
			dot.size = Vector2(16, 16)
			dot.position = Vector2(b.size.x - 22, 6)
			b.add_child(dot)
		return dot
	return null
