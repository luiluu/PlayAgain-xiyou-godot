class_name XTouchControls
extends CanvasLayer
## 触屏虚拟按键（跨平台适配二期，cc BH 2026-11-05）：照原版二合一包 android-integration.js 的布局，
## 左下摇杆（中心 16% 内不动；战斗与菜单照原版只取一个轴，地图 MV 是四方向，也只取一个轴）、右下确定／取消／跑步、右上「隐藏按键」。
## 按键都转成 InputEventAction（方向、确定、取消）或 Shift 物理键（跑步，MV updateDashing 看 Shift），按住照 XKeyRepeat 的 24／6 帧连发。
## 按到这些按键的触点（含 Godot 由第一指转出的鼠标事件）在这里吃掉，不再传给地图和界面，也不算两指取消。
## 只在 XPlatform.is_touch() 时由 GameApp 建；切后台、返回键时全部松开。隐藏状态存 user://touch_controls.json。
## 三期（cc BP 2026-11-06）：照原版 Codex_AndroidTouchSettings.js「手机按键设置」，轮盘／右侧按键／顶部按钮大小、透明度、
## 三组位置（movement／actions／top，拖动后存成安全区内的 0～1 比例）可调，存同一文件；默认值与二期一样。
## 按键避开刘海／圆角：默认位置的边距取 max(原边距, 安全区缩进)（原版 max(12px, env(safe-area-inset-*))）；拖过的位置也限制在安全区内。

const REPEAT_WAIT := 24
const REPEAT_INTERVAL := 6
const STICK_RADIUS := 72.0
const DEAD_ZONE := 0.16
## 测试改到临时位置。
static var SETTINGS_PATH := "user://touch_controls.json"
## 按键的位置与大小（1280×720 画面坐标）。
const STICK_CENTER := Vector2(96, 624)
const BUTTONS := {
	"ok": {"rect": Rect2(1150, 560, 110, 72), "text": "确定", "action": "ui_accept"},
	"cancel": {"rect": Rect2(1030, 620, 110, 72), "text": "取消", "action": "ui_cancel"},
	"run": {"rect": Rect2(1150, 640, 110, 64), "text": "跑步", "key": KEY_SHIFT},
	"hide": {"rect": Rect2(1170, 8, 100, 40), "text": "隐藏按键", "toggle": true},
	# Mehmet_GhostButtons 的「Save」键（原版虚拟按键只在手机上有，按下＝键盘 ~，YEP_ButtonCommonEvents 428 一键存档，地图与菜单才有）。
	# 显示在哪见 SAVE_MAP_MENU_ONLY。回退开关 SAVE_BUTTON = false（整个不要存档键）。
	"save": {"rect": Rect2(1050, 8, 100, 40), "text": "存档", "key": KEY_QUOTELEFT},
}
static var SAVE_BUTTON := true
## 存档键照原版只在地图与主菜单显示、才吃触摸（Mehmet_GhostButtons 第 672 行 [Scene_Map, Scene_Menu]；标题页整套虚拟键都不建，
## 战斗、菜单的子页面也没有）。当前场景有 touch_save_visible() 且返回 true 才算（XMapScene：不在战斗、菜单没开或停在主菜单）。
## 审查 50 P2-1：keys3 原先所有页面都显示，标题页「导出存档」被它盖住。回退开关 = false：回到所有页面都显示（cc CJ 2026-11-06，O-211）。
static var SAVE_MAP_MENU_ONLY := true
## 测试用：当成当前场景。
static var scene_override: Node = null
## Codex 审查报告第 13 项（O-225）：按住虚拟键的连发。原先确定、取消、方向按住 24 帧后每 6 帧都再发一次「新按下」，
## 商店、标题这类只认新按下（不认回显）的确认会被连按（按住确定买了一串）。现在：确定、取消按住不连发，松开再按才算第二次；
## 方向的连发改成方向键的回显事件（is_echo() 为 true，节奏不变），页面认得出是连发；按着时换了场景，回显停下，要松开再按。
## 回退开关 HOLD_REPEAT_ECHO = false：回到所有虚拟键按住都发「新按下」。
static var HOLD_REPEAT_ECHO := true
## ui6 查出：Godot 把带 echo 的按键事件也记成该动作在键盘设备上「按着」，只松开 InputEventAction 清不掉，
## 所以摇杆按住满 24 帧（发过回显）再松手，ui_left 等仍是按着——地图上 mv_player 轮询方向，人物会一直走。
## 松开方向时顺带发一次该方向键的松开（_set_dir）。
## 方向回显用的键（XKeyRepeat 看到带这个标记的回显就放行，不当成系统回显吞掉）。
const DIR_KEYS := {"ui_up": KEY_UP, "ui_down": KEY_DOWN, "ui_left": KEY_LEFT, "ui_right": KEY_RIGHT}
const REPEAT_META := &"xiyou_touch_repeat"

## 摇杆拖动翻页（ui6，Kyo 11-07「先做吧，然后设置里做开关」；O-待定·摇杆翻页）：照原版 Mehmet_GhostButtons
## Sprite_JoyStick.processTouch——摇杆往左／右推到半径的 65% 以上、按住满 36 帧后，每 24 帧对当前列表翻一页
## （左＝pageup、右＝pagedown，原版调用活动窗口的 pageup／pagedown 处理或 cursorPageup／Pagedown）。
## 重制发 ui_page_up／ui_page_down 动作，各页现有的 Q／E、LB／RB 翻页接住；地图上没有页面认它，不起作用（原版地图上也没有活动列表）。
## 跟原版不同的两处：① 原版还要求手指这一帧在动（TouchInput.isMoved），按稳不动就不翻、得来回晃，这里按稳也翻；
## ② 原版翻页时左右键照样按着，网格列表会同时横走光标，这里一开始翻页就停掉这一下的左右连发（键仍算按着，松手时照常松开）。
## 玩家在「手机按键设置」里可关（settings.stick_page，默认开）；STICK_PAGE = false 整个功能不要、设置里也不列。
static var STICK_PAGE := true
const PAGE_PRESSURE := 0.65
const PAGE_HOLD := 36
const PAGE_INTERVAL := 24
var _stick_offset := Vector2.ZERO
var _page_held := 0
var _page_time := 0
var _paging := false
## 翻页发出的次数（测试读）
var pages_sent := 0

## 原版 limits：大小百分比与透明度的范围，步长 5。
const LIMITS := {"stick": [70, 170], "buttons": [70, 160], "tools": [80, 140], "transparency": [0, 80]}
const STEP := 5
const DEFAULTS := {"hidden": false, "stick": 100, "buttons": 100, "tools": 100, "transparency": 0, "stick_page": true}
## 三组：成员、缩放用哪个大小、100% 时的外框、默认贴哪两条边（与上面常量的位置一致）。
const GROUPS := {
	"movement": {"members": ["stick"], "size": "stick", "rect": Rect2(24, 552, 144, 144), "anchor": [SIDE_LEFT, SIDE_BOTTOM]},
	"actions": {"members": ["ok", "cancel", "run"], "size": "buttons", "rect": Rect2(1030, 560, 230, 144), "anchor": [SIDE_RIGHT, SIDE_BOTTOM]},
	"top": {"members": ["hide", "save"], "size": "tools", "rect": Rect2(1050, 8, 220, 40), "anchor": [SIDE_RIGHT, SIDE_TOP]},  # 存档键（keys3）与隐藏键同组
}
## 拖过的位置的可放范围：安全区再往里留的边（原版 bounds：左右 12、上 6、下 12）。
const DRAG_MARGIN := [12.0, 6.0, 12.0, 12.0]  # 左、上、右、下
const SCREEN := Vector2(1280, 720)
## 当前这一个（设置页找它）。
static var instance: XTouchControls

var hidden := false
var settings := {}
## {"movement": {"x":, "y":} 或 null, ...}
var positions := {}
var layout_editing := false
## 现在实际的位置（按大小、位置、安全区算出来的）
var rects := {}
var stick_center := STICK_CENTER
var stick_radius := STICK_RADIUS
var group_rects := {}
var _insets := [0.0, 0.0, 0.0, 0.0]
var _drag := {}  # 布局编辑：{"index":, "group":, "offset":}
var _layout_bar: Control
var _insets_overridden := false

signal layout_finished
var root: Control
var _stick_base: Panel
var _stick_knob: Panel
var _buttons := {}
## 触点编号 → 按着的东西（"stick" 或按键名）
var _touches := {}
var _dir := ""
var _held := {}  # 动作名 → 按住的帧数
var _held_scene := {}  # 动作名 → 按下时的场景（换了场景就不再连发）
var _catch_label: Label


func _ready() -> void:
	instance = self
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.name = "TouchRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_stick_base = _panel(Rect2(STICK_CENTER - Vector2.ONE * STICK_RADIUS, Vector2.ONE * STICK_RADIUS * 2), STICK_RADIUS, Color(0.08, 0.15, 0.24, 0.45))
	_stick_knob = _panel(Rect2(STICK_CENTER - Vector2(26, 26), Vector2(52, 52)), 26.0, Color(0.45, 0.62, 0.76, 0.75))
	for name in BUTTONS:
		if name == "save" and not SAVE_BUTTON:
			continue
		var spec: Dictionary = BUTTONS[name]
		var p := _panel(spec.rect, 12.0, Color(0.07, 0.15, 0.24, 0.72))
		var l := Label.new()
		l.text = spec.text
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 20 if name != "hide" else 15)
		l.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		l.name = "Label"
		p.add_child(l)
		_buttons[name] = p
	_catch_label = Label.new()
	_catch_label.position = Vector2(390, 300)
	_catch_label.size = Vector2(500, 60)
	_catch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_catch_label.add_theme_font_size_override("font_size", 22)
	_catch_label.visible = false
	root.add_child(_catch_label)
	var platform := get_parent() as XPlatform
	if platform != null:
		platform.virtual_keys_release_requested.connect(release_all)
	_load()
	_build_layout_bar()
	get_viewport().size_changed.connect(apply_layout)
	apply_layout()
	_apply_hidden()


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _panel(rect: Rect2, radius: float, color: Color) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(int(radius))
	s.border_color = Color(0.68, 0.77, 0.93, 0.47)
	s.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", s)
	root.add_child(p)
	return p


## 某点落在哪个按键上（"stick"、按键名或 ""）。隐藏时只剩「隐藏按键」能点（照原版 compact）。
func hit(pos: Vector2) -> String:
	if (rects.hide as Rect2).has_point(pos):
		return "hide"
	if hidden:
		return ""
	if pos.distance_to(stick_center) <= stick_radius * 1.2:
		return "stick"
	for name in BUTTONS:
		if name == "save" and not save_shown():
			continue
		if rects.has(name) and (rects[name] as Rect2).has_point(pos):
			return name
	return ""


## 存档键现在该不该出现（不看隐藏状态）。
func save_shown() -> bool:
	if not SAVE_BUTTON or not _buttons.has("save"):
		return false
	if not SAVE_MAP_MENU_ONLY:
		return true
	var scene: Node = scene_override if is_instance_valid(scene_override) else (get_tree().current_scene if is_inside_tree() else null)
	return scene != null and scene.has_method("touch_save_visible") and bool(scene.touch_save_visible())


## 布局编辑时某点落在哪一组上。
func group_at(pos: Vector2) -> String:
	for g in GROUPS:
		if (group_rects[g] as Rect2).has_point(pos):
			return g
	return ""


func _layout_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if _layout_bar.get_global_rect().has_point(t.position):
			return  # 交给「恢复位置」「完成」两个按钮
		XKeyMap.handled(self)
		if t.pressed and _drag.is_empty():
			var g := group_at(t.position)
			if g != "":
				_drag = {"index": t.index, "group": g, "offset": t.position - (group_rects[g] as Rect2).position}
		elif not t.pressed and _drag.get("index", -1) == t.index:
			_drag = {}
			_save()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		XKeyMap.handled(self)
		if _drag.get("index", -1) == d.index:
			move_group(_drag.group, d.position - _drag.offset)
	elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		if not _layout_bar.get_global_rect().has_point((event as InputEventMouse).position):
			XKeyMap.handled(self)


func _input(event: InputEvent) -> void:
	if layout_editing:
		_layout_input(event)
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var what := hit(t.position)
			if what == "":
				return
			_touches[t.index] = what
			_press(what, t.position)
			XKeyMap.handled(self)
		elif _touches.has(t.index):
			_release(_touches[t.index])
			_touches.erase(t.index)
			XKeyMap.handled(self)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _touches.get(d.index, "") == "stick":
			_move_stick(d.position)
			XKeyMap.handled(self)
		elif _touches.has(d.index):
			XKeyMap.handled(self)
	elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		# Godot 由第一指转出的鼠标事件（先于触屏事件本身到）：落在按键上、或第一指正按着按键时整段吃掉
		if _touches.has(0) or (event is InputEventMouseButton and hit((event as InputEventMouseButton).position) != ""):
			XKeyMap.handled(self)


func _press(what: String, pos: Vector2) -> void:
	match what:
		"stick":
			_move_stick(pos)
		"hide":
			hidden = not hidden
			release_all()
			_apply_hidden()
			_save()
		_:
			var spec: Dictionary = BUTTONS[what]
			if spec.has("action"):
				_send_action(spec.action, true)
				_hold(spec.action)
			elif spec.has("key"):
				_send_key(spec.key, true)
			(_buttons[what] as Panel).modulate = Color(1.4, 1.4, 1.4)


func _release(what: String) -> void:
	match what:
		"stick":
			_set_dir("")
			_stick_knob.position = stick_center - _stick_knob.size / 2
		"hide":
			pass
		_:
			var spec: Dictionary = BUTTONS[what]
			if spec.has("action"):
				_send_action(spec.action, false)
				_held.erase(spec.action)
			elif spec.has("key"):
				_send_key(spec.key, false)
			(_buttons[what] as Panel).modulate = Color.WHITE


## 摇杆：只取一个轴（横竖哪个大取哪个），中心 16% 内不动。
static func stick_direction(offset: Vector2, radius := STICK_RADIUS) -> String:
	if offset.length() <= radius * DEAD_ZONE:
		return ""
	if absf(offset.x) > absf(offset.y):
		return "ui_left" if offset.x < 0 else "ui_right"
	return "ui_up" if offset.y < 0 else "ui_down"


func _move_stick(pos: Vector2) -> void:
	var offset := pos - stick_center
	var travel := stick_radius - _stick_knob.size.x / 2
	_stick_offset = offset
	var shown := offset.limit_length(travel)
	_stick_knob.position = stick_center + shown - _stick_knob.size / 2
	_set_dir(stick_direction(offset, stick_radius))


func _set_dir(action: String) -> void:
	if action == _dir:
		return
	_page_held = 0
	_page_time = 0
	_paging = false
	if _dir != "":
		_send_action(_dir, false)
		if HOLD_REPEAT_ECHO and DIR_KEYS.has(_dir):
			_send_key(DIR_KEYS[_dir], false)  # 回显按下的方向键也要松开（见 DIR_KEYS 上方说明）
		_held.erase(_dir)
	_dir = action
	if action != "":
		_send_action(action, true)
		_hold(action)


func _hold(action: String) -> void:
	_held[action] = 0
	_held_scene[action] = _current_scene()


func _current_scene() -> Node:
	if is_instance_valid(scene_override):
		return scene_override
	return get_tree().current_scene if is_inside_tree() else null


func _send_action(action: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	Input.parse_input_event(e)


func _send_key(key: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = key
	e.physical_keycode = key
	e.pressed = pressed
	Input.parse_input_event(e)


## 松开所有按着的虚拟键（切后台、返回键、隐藏时）。
func release_all() -> void:
	for index in _touches.keys():
		_release(_touches[index])
	_touches.clear()
	_set_dir("")
	for action in _held.keys():
		_send_action(action, false)
	_held.clear()
	_held_scene.clear()


func _physics_process(_delta: float) -> void:
	_stick_page_tick()
	# 按住连发：24 帧后每 6 帧再按一次（XKeyRepeat 只管实体键）
	for action in _held.keys():
		var n: int = _held[action] + 1
		_held[action] = n
		if n >= REPEAT_WAIT and (n - REPEAT_WAIT) % REPEAT_INTERVAL == 0:
			if not HOLD_REPEAT_ECHO:
				_send_action(action, true)
			elif DIR_KEYS.has(action) and _held_scene.get(action) == _current_scene():
				_send_echo(DIR_KEYS[action])


## 摇杆翻页是否开着（代码开关＋玩家设置）
func stick_page_on() -> bool:
	return STICK_PAGE and bool(settings.get("stick_page", true))


func set_stick_page(value: bool) -> void:
	settings["stick_page"] = value
	_page_held = 0
	_page_time = 0
	_paging = false
	_save()


## 每帧：摇杆左右推深、按满 PAGE_HOLD 帧后每 PAGE_INTERVAL 帧翻一页（原版两个计数都从按下那帧起算，所以第一页在第 36 帧）
func _stick_page_tick() -> void:
	if not stick_page_on() or (_dir != "ui_left" and _dir != "ui_right"):
		return
	_page_held += 1
	_page_time += 1
	if _stick_offset.length() < stick_radius * PAGE_PRESSURE:
		return
	if _page_held < PAGE_HOLD or _page_time < PAGE_INTERVAL:
		return
	_page_time = 0
	if not _paging:
		_paging = true
		_held.erase(_dir)  # 停掉这一下的左右连发
	var action := "ui_page_up" if _dir == "ui_left" else "ui_page_down"
	_send_action(action, true)
	_send_action(action, false)
	pages_sent += 1


## 方向连发：方向键的回显（不改按键状态，is_action_pressed(动作, true) 认得到、is_echo() 为 true）
func _send_echo(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	e.echo = true
	e.set_meta(REPEAT_META, true)
	Input.parse_input_event(e)


func _process(_delta: float) -> void:
	if _buttons.has("save"):
		var want := (not hidden or layout_editing) and (layout_editing or save_shown())
		if (_buttons.save as Panel).visible != want:
			(_buttons.save as Panel).visible = want
	var platform := get_parent() as XPlatform
	var catching := platform != null and platform.is_catching_up()
	_catch_label.visible = catching
	if catching:
		var left := int(platform.catch_up_left())
		_catch_label.text = "后台挂机补跑中（×%d），还剩 %d:%02d\n点屏幕停止" % [XPlatform.CATCH_UP_SPEED, left / 60, left % 60]


func _apply_hidden() -> void:
	var shown := not hidden or layout_editing
	for name in _buttons:
		(_buttons[name] as Panel).visible = name == "hide" or (shown and (name != "save" or layout_editing or save_shown()))
	_stick_base.visible = shown
	_stick_knob.visible = shown
	var label := (_buttons.hide as Panel).get_node("Label") as Label
	label.text = "显示按键" if hidden else "隐藏按键"
	# 原版 node.style.opacity = 1 - 透明度/100，调位置时不透明
	root.modulate.a = 1.0 if layout_editing else 1.0 - float(settings.transparency) / 100.0


## 安全区缩进（画面坐标，左上右下）：测试可以直接给。
func set_insets(insets: Array) -> void:
	_insets_overridden = true
	_insets = insets.duplicate()
	apply_layout()


## 按大小、位置、安全区把三组摆好。
func apply_layout() -> void:
	if root == null:
		return
	if is_inside_tree() and not _insets_overridden:
		_insets = XPlatform.safe_insets(get_viewport())
	for g in GROUPS:
		var spec: Dictionary = GROUPS[g]
		var base: Rect2 = spec.rect
		var s := float(settings[spec.size]) / 100.0
		var size := base.size * s
		var pos := default_position(g, size)
		var saved = positions.get(g)
		if saved is Dictionary:
			var box := drag_bounds(size)
			pos = box.position + Vector2(clampf(float(saved.x), 0, 1) * box.size.x, clampf(float(saved.y), 0, 1) * box.size.y)
		group_rects[g] = Rect2(pos, size)
		for name in spec.members:
			if name == "stick":
				stick_center = pos + (STICK_CENTER - base.position) * s
				stick_radius = STICK_RADIUS * s
				_place(_stick_base, Rect2(stick_center - Vector2.ONE * stick_radius, Vector2.ONE * stick_radius * 2), stick_radius)
				var knob := 26.0 * s
				_place(_stick_knob, Rect2(stick_center - Vector2.ONE * knob, Vector2.ONE * knob * 2), knob)
			elif _buttons.has(name):
				var r: Rect2 = BUTTONS[name].rect
				rects[name] = Rect2(pos + (r.position - base.position) * s, r.size * s)
				_place(_buttons[name], rects[name], 12.0 * s)
				var label := (_buttons[name] as Panel).get_node("Label") as Label
				label.add_theme_font_size_override("font_size", maxi(10, roundi((15 if name == "hide" else 20) * s)))
	_apply_hidden()



func _place(p: Panel, r: Rect2, radius: float) -> void:
	p.position = r.position
	p.size = r.size
	(p.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(int(radius))


## 没拖过时：贴原来那两条边，边距取 max(原边距, 安全区缩进)。
func default_position(g: String, size: Vector2) -> Vector2:
	var spec: Dictionary = GROUPS[g]
	var base: Rect2 = spec.rect
	var margin := [base.position.x, base.position.y, SCREEN.x - base.end.x, SCREEN.y - base.end.y]
	var pos := Vector2.ZERO
	pos.x = maxf(margin[0], _insets[0]) if spec.anchor.has(SIDE_LEFT) else SCREEN.x - maxf(margin[2], _insets[2]) - size.x
	pos.y = maxf(margin[1], _insets[1]) if spec.anchor.has(SIDE_TOP) else SCREEN.y - maxf(margin[3], _insets[3]) - size.y
	return pos


## 拖过的位置的放置范围（左上角能落的矩形）。
func drag_bounds(size: Vector2) -> Rect2:
	var left: float = DRAG_MARGIN[0] + _insets[0]
	var top: float = DRAG_MARGIN[1] + _insets[1]
	var w := maxf(0, SCREEN.x - left - DRAG_MARGIN[2] - _insets[2] - size.x)
	var h := maxf(0, SCREEN.y - top - DRAG_MARGIN[3] - _insets[3] - size.y)
	return Rect2(left, top, w, h)


## 把一组的左上角移到 pos（限制在安全区内），记成比例。
func move_group(g: String, pos: Vector2) -> void:
	var box := drag_bounds((group_rects[g] as Rect2).size)
	positions[g] = {"x": 0.0 if box.size.x <= 0 else clampf((pos.x - box.position.x) / box.size.x, 0, 1),
		"y": 0.0 if box.size.y <= 0 else clampf((pos.y - box.position.y) / box.size.y, 0, 1)}
	apply_layout()


## 设置页用：改大小或透明度（夹在原版范围内、对齐 5），立即生效并保存。
func set_value(key: String, value: int) -> void:
	var lim: Array = LIMITS[key]
	settings[key] = clampi(roundi(value / float(STEP)) * STEP, lim[0], lim[1])
	apply_layout()
	_save()


func set_hidden(value: bool) -> void:
	if hidden == value:
		return
	hidden = value
	release_all()
	_apply_hidden()
	_save()


## 原版「恢复默认」：大小、透明度回默认、显示按键，位置清掉。
func reset_defaults() -> void:
	settings = DEFAULTS.duplicate()
	hidden = false
	positions = {}
	apply_layout()
	_save()


## 原版「调整UI位置」：拖三组按键，上方「恢复位置」「完成」；返回键也算完成。
func start_layout() -> void:
	release_all()
	layout_editing = true
	_drag = {}
	_layout_bar.visible = true
	_apply_hidden()


func finish_layout() -> void:
	if not layout_editing:
		return
	layout_editing = false
	_drag = {}
	_layout_bar.visible = false
	_apply_hidden()
	_save()
	layout_finished.emit()



func _build_layout_bar() -> void:
	_layout_bar = HBoxContainer.new()
	_layout_bar.name = "LayoutBar"
	_layout_bar.position = Vector2(470, 300)
	_layout_bar.size = Vector2(340, 56)
	_layout_bar.add_theme_constant_override("separation", 20)
	_layout_bar.visible = false
	root.add_child(_layout_bar)
	for spec in [["恢复位置", func():
			positions = {}
			apply_layout()
			_save()], ["完成", finish_layout]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(160, 56)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(spec[1])
		_layout_bar.add_child(b)


func _load() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH)) if FileAccess.file_exists(SETTINGS_PATH) else null
	if not (data is Dictionary):
		data = {}
	hidden = bool(data.get("hidden", false))
	settings = DEFAULTS.duplicate()
	if data.get("stick_page") is bool:
		settings["stick_page"] = data.stick_page
	for key in LIMITS:
		var v = data.get(key)
		if v is float or v is int:
			settings[key] = clampi(int(v), LIMITS[key][0], LIMITS[key][1])
	positions = {}
	var saved = data.get("positions")
	if saved is Dictionary:
		for g in GROUPS:
			var p = saved.get(g)
			if p is Dictionary and (p.get("x") is float or p.get("x") is int) and (p.get("y") is float or p.get("y") is int):
				positions[g] = {"x": clampf(float(p.x), 0, 1), "y": clampf(float(p.y), 0, 1)}


func _save() -> void:
	var data := {"hidden": hidden, "positions": positions, "stick_page": bool(settings.get("stick_page", true))}
	for key in LIMITS:
		data[key] = settings[key]
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
