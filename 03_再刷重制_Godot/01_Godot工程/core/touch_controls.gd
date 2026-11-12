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
## 原版虚拟按钮当默认（Kyo 11-12「把那个没装的虚拟按键定为默认按键」＋实机截图，O-待定-4）：照改版 Codex_AndroidTouchSettings v0.08
## 「操作布局」的「原版虚拟按钮」＝ Mehmet_GhostButtons v1.0.3 的画法——左下头像摇杆（直径 280、中心 (220,540)，外圈白描边、
## 内圈 60% 半透黑，摇杆头半径 84：白底、红芯、正中画队长行走图正面，整体不透明度 150）、右侧灰底绿字圆形 A（确认，中心 (1030,520)）
## 与 B（取消，中心 (1160,410)），直径 120、字号 72、平时不透明度 80、按下 255、松开每帧 −3 淡回；Save 键 80×60 圆角、暗底绿字。
## 设置 style = "original"（默认）／"modern"（改版按键）。
## 改版按键：照同一插件的「改版按键」——
## 右侧布局 A／B 两键（默认，A＝确认在左下、B＝取消／返回在右上，圆形）或「原多键」（Shift、Ctrl、前页、后页、返回、确认 2×3）；
## 移动方式轮盘（默认）或方向键（3×3 十字，大小另调 70～170%）；「显示跑步键」（默认关，开了在移动区旁加圆形「跑」）；
## 「地图点击移动」（默认开）、「战斗点击操作」（默认关＝战斗选项与目标只认屏幕按键，照改版 battleTouch 默认）。
## 旧的「确定／取消／跑步」三键留作 layout = "classic"；回退开关 MODERN_DEFAULT = false：默认回到 v0.01 的样子（改版样式、旧三键、战斗点击开）。

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
	# 改版按键（见文件头）：原多键与方向键；位置由 _style_members 按当前样式算，这里的 rect 不用
	"shift": {"rect": Rect2(), "text": "Shift", "key": KEY_SHIFT},
	"ctrl": {"rect": Rect2(), "text": "Ctrl", "key": KEY_CTRL},
	"pageup": {"rect": Rect2(), "text": "前页", "action": "ui_page_up"},
	"pagedown": {"rect": Rect2(), "text": "后页", "action": "ui_page_down"},
	"up": {"rect": Rect2(), "text": "▲", "dir": "ui_up"},
	"left": {"rect": Rect2(), "text": "◀", "dir": "ui_left"},
	"right": {"rect": Rect2(), "text": "▶", "dir": "ui_right"},
	"down": {"rect": Rect2(), "text": "▼", "dir": "ui_down"},
}
## 改版按键当默认（回退开关见文件头）
static var MODERN_DEFAULT := true
## 改版按键 100% 时各组成员在组内的位置（画面坐标；改版 CSS 尺寸按重制轮盘 144 的比例放大）
const AB_SIZE := Vector2(200, 176)
const AB_BUTTON := 88.0
const FULL_SIZE := Vector2(158, 180)
const PAD_SIZE := 144.0
const PAD_GAP := 3.0
const RUN_SIZE := 56.0
const RUN_GAP := 8.0
const LAYOUTS := ["ab", "full", "classic"]
const STYLES := ["original", "modern"]
## 原版虚拟按钮（Mehmet_GhostButtons）100% 时的外框与组内位置
const GHOST_STICK := Rect2(80, 400, 280, 280)
const GHOST_KNOB := 84.0
const GHOST_ACTIONS := Rect2(970, 350, 250, 230)
const GHOST_BUTTON := 120.0
const GHOST_TOP := Rect2(1086, 8, 190, 62)
const GHOST_IDLE := 80.0 / 255.0
const GHOST_STICK_ALPHA := 150.0 / 255.0
const GHOST_TEXT := Color8(0, 188, 18)
const MODES := ["joystick", "buttons"]
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

## 摇杆拖动翻页（ui6，Kyo 11-07「先做吧，然后设置里做开关」；O-238）：照原版 Mehmet_GhostButtons
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
const LIMITS := {"stick": [70, 170], "pad": [70, 170], "buttons": [70, 160], "tools": [80, 140], "transparency": [0, 80]}
const STEP := 5
const DEFAULTS := {"hidden": false, "stick": 100, "pad": 100, "buttons": 100, "tools": 100, "transparency": 0, "stick_page": true,
	"style": "original", "layout": "ab", "mode": "joystick", "show_run": false, "map_touch": true, "battle_touch": false}
## 开关类设置（存成 true／false）
const FLAGS := ["show_run", "map_touch", "battle_touch"]
## 三组：成员、缩放用哪个大小、100% 时的外框（旧三键的位置；默认边距按它算）、默认贴哪两条边。成员与大小随样式变，见 _style_members。
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
## 当前样式下用到的按键（含 hide、save）；hit、显示都只看这些
var active := []
var _uses_stick := true
## 原版虚拟按钮的摇杆（自己画：圆圈、摇杆头、队长行走图）
var _ghost_base: Control
var _ghost_knob: Control
## 原版按钮的不透明度（按下 1，松开每帧 −3/255 淡回 GHOST_IDLE）
var _ghost_alpha := {}
## 测试用：摇杆头画的行走图 [名字, 序号]；空＝取当前地图主角或队长
static var knob_character_override: Array = []


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
	_ghost_base = Control.new()
	_ghost_base.name = "GhostStick"
	_ghost_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost_base.draw.connect(_draw_ghost_base)
	root.add_child(_ghost_base)
	_ghost_knob = Control.new()
	_ghost_knob.name = "GhostKnob"
	_ghost_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost_knob.draw.connect(_draw_ghost_knob)
	root.add_child(_ghost_knob)
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
		l.clip_text = true
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
	if _uses_stick and pos.distance_to(stick_center) <= stick_radius * 1.2:
		return "stick"
	for name in active:
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
			if spec.has("dir"):
				_stick_offset = Vector2.ZERO
				_set_dir(spec.dir)
			elif spec.has("action"):
				_send_action(spec.action, true)
				_hold(spec.action)
			elif spec.has("key"):
				_send_key(spec.key, true)
			if ghost():
				_ghost_alpha[what] = 1.0
				(_buttons[what] as Panel).modulate = Color.WHITE
			else:
				(_buttons[what] as Panel).modulate = Color(1.4, 1.4, 1.4)


func _release(what: String) -> void:
	match what:
		"stick":
			_set_dir("")
			_stick_knob.position = stick_center - _stick_knob.size / 2
			_ghost_knob.position = stick_center - _ghost_knob.size / 2
		"hide":
			pass
		_:
			var spec: Dictionary = BUTTONS[what]
			if spec.has("dir"):
				if _dir == spec.dir:
					_set_dir("")
			elif spec.has("action"):
				_send_action(spec.action, false)
				_held.erase(spec.action)
			elif spec.has("key"):
				_send_key(spec.key, false)
			if not ghost():
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
	var travel := stick_radius - (_ghost_knob.size.x if ghost() else _stick_knob.size.x) / 2
	_stick_offset = offset
	var shown := offset.limit_length(travel)
	_stick_knob.position = stick_center + shown - _stick_knob.size / 2
	_ghost_knob.position = stick_center + shown - _ghost_knob.size / 2
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
	if ghost():
		var pressed := _touches.values()
		for name in _ghost_alpha.keys():
			var a: float = _ghost_alpha[name]
			if not pressed.has(name) and a > GHOST_IDLE:
				a = maxf(GHOST_IDLE, a - 3.0 / 255.0)
				_ghost_alpha[name] = a
			if _buttons.has(name):
				(_buttons[name] as Panel).modulate.a = a
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
	if ghost() and _ghost_knob.visible:
		var ch := knob_character()
		if ch != _knob_drawn:
			_knob_drawn = ch
			_ghost_knob.queue_redraw()
	if _buttons.has("save"):
		var want := active.has("save") and (not hidden or layout_editing) and (layout_editing or save_shown())
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
		(_buttons[name] as Panel).visible = name == "hide" or (shown and active.has(name) and (name != "save" or layout_editing or save_shown()))
	_stick_base.visible = shown and _uses_stick and not ghost()
	_stick_knob.visible = shown and _uses_stick and not ghost()
	_ghost_base.visible = shown and _uses_stick and ghost()
	_ghost_knob.visible = shown and _uses_stick and ghost()
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
	active = []
	_uses_stick = false
	for g in GROUPS:
		var st := _style_members(g)
		var s := float(settings[st.size_key]) / 100.0
		var size: Vector2 = st.size * s
		var pos := default_position(g, size)
		var saved = positions.get(g)
		if saved is Dictionary:
			var box := drag_bounds(size)
			pos = box.position + Vector2(clampf(float(saved.x), 0, 1) * box.size.x, clampf(float(saved.y), 0, 1) * box.size.y)
		group_rects[g] = Rect2(pos, size)
		var members: Dictionary = st.members
		for name in members:
			var local: Rect2 = members[name]
			if name == "stick":
				_uses_stick = true
				stick_center = pos + local.get_center() * s
				stick_radius = local.size.x / 2.0 * s
				_place(_stick_base, Rect2(stick_center - Vector2.ONE * stick_radius, Vector2.ONE * stick_radius * 2), stick_radius)
				var knob := 26.0 * s
				_place(_stick_knob, Rect2(stick_center - Vector2.ONE * knob, Vector2.ONE * knob * 2), knob)
				_ghost_base.position = stick_center - Vector2.ONE * stick_radius
				_ghost_base.size = Vector2.ONE * stick_radius * 2
				_ghost_base.queue_redraw()
				var gk := GHOST_KNOB * s
				_ghost_knob.position = stick_center - Vector2.ONE * gk
				_ghost_knob.size = Vector2.ONE * gk * 2
				_ghost_knob.queue_redraw()
			elif _buttons.has(name):
				active.append(name)
				rects[name] = Rect2(pos + local.position * s, local.size * s)
				var round_key := (name in ["ok", "cancel"] and (layout() == "ab" or ghost())) or (name == "run" and layout() != "classic")
				_place(_buttons[name], rects[name], rects[name].size.x / 2.0 if round_key else (8.0 if BUTTONS[name].has("dir") else 12.0) * s)
				_style_button(name)
				var label := (_buttons[name] as Panel).get_node("Label") as Label
				label.text = button_text(name)
				label.add_theme_font_size_override("font_size", maxi(10, roundi(_font_base(name) * s)))
				label.add_theme_color_override("font_color", _font_color(name))
	_apply_hidden()


## 当前右侧布局（ab／full／classic）与移动方式（joystick／buttons）
func layout() -> String:
	return str(settings.get("layout", "ab"))


func move_mode() -> String:
	return str(settings.get("mode", "joystick"))


## 某组在当前样式下：{size_key: 用哪个大小, size: 100% 外框大小, members: {名字: 组内 Rect2}}（"stick" 为摇杆的外框）
func _style_members(g: String) -> Dictionary:
	if ghost():
		match g:
			"movement":
				return {"size_key": "stick", "size": GHOST_STICK.size, "base": GHOST_STICK, "members": {"stick": Rect2(Vector2.ZERO, GHOST_STICK.size)}}
			"actions":
				return {"size_key": "buttons", "size": GHOST_ACTIONS.size, "base": GHOST_ACTIONS, "members": {
					"ok": Rect2(0, GHOST_ACTIONS.size.y - GHOST_BUTTON, GHOST_BUTTON, GHOST_BUTTON),
					"cancel": Rect2(GHOST_ACTIONS.size.x - GHOST_BUTTON, 0, GHOST_BUTTON, GHOST_BUTTON)}}
			_:
				var m := {"hide": Rect2(0, 0, 100, 40)}
				if SAVE_BUTTON:
					m["save"] = Rect2(110, 2, 80, 60)
				return {"size_key": "tools", "size": GHOST_TOP.size, "base": GHOST_TOP, "members": m}
	var classic := layout() == "classic"
	match g:
		"movement":
			var pad := move_mode() == "buttons"
			var m := {}
			if pad:
				var cell := (PAD_SIZE - PAD_GAP * 2) / 3.0
				var step := cell + PAD_GAP
				m = {"up": Rect2(step, 0, cell, cell), "left": Rect2(0, step, cell, cell), "right": Rect2(step * 2, step, cell, cell), "down": Rect2(step, step * 2, cell, cell)}
			else:
				m = {"stick": Rect2(0, 0, STICK_RADIUS * 2, STICK_RADIUS * 2)}
			var size := Vector2(PAD_SIZE, PAD_SIZE)
			if not classic and bool(settings.get("show_run", false)):
				# 改版：方向键时「跑」在右上，轮盘时在右下
				m["run"] = Rect2(PAD_SIZE + RUN_GAP, 0.0 if pad else PAD_SIZE - RUN_SIZE, RUN_SIZE, RUN_SIZE)
				size.x += RUN_GAP + RUN_SIZE
			return {"size_key": "pad" if pad else "stick", "size": size, "members": m}
		"actions":
			if classic:
				var base: Rect2 = GROUPS.actions.rect
				var m := {}
				for name in GROUPS.actions.members:
					m[name] = Rect2((BUTTONS[name].rect as Rect2).position - base.position, (BUTTONS[name].rect as Rect2).size)
				return {"size_key": "buttons", "size": base.size, "members": m}
			if layout() == "full":
				var w := (FULL_SIZE.x - 6) / 2.0
				return {"size_key": "buttons", "size": FULL_SIZE, "members": {
					"shift": Rect2(0, 0, w, 54), "ctrl": Rect2(w + 6, 0, w, 54),
					"pageup": Rect2(0, 60, w, 54), "pagedown": Rect2(w + 6, 60, w, 54),
					"cancel": Rect2(0, 120, w, 60), "ok": Rect2(w + 6, 120, w, 60)}}
			return {"size_key": "buttons", "size": AB_SIZE, "members": {
				"ok": Rect2(0, AB_SIZE.y - AB_BUTTON, AB_BUTTON, AB_BUTTON), "cancel": Rect2(AB_SIZE.x - AB_BUTTON, 0, AB_BUTTON, AB_BUTTON)}}
		_:
			var base: Rect2 = GROUPS.top.rect
			var m := {}
			for name in GROUPS.top.members:
				if name == "save" and not SAVE_BUTTON:
					continue
				m[name] = Rect2((BUTTONS[name].rect as Rect2).position - base.position, (BUTTONS[name].rect as Rect2).size)
			return {"size_key": "tools", "size": base.size, "members": m}


## 按键上的字：A／B 两键写 A、B，原多键写「确认」「返回」，改版跑步键写「跑」
func button_text(name: String) -> String:
	if ghost() and name in ["ok", "cancel", "save"]:
		return {"ok": "A", "cancel": "B", "save": "Save"}[name]
	match name:
		"ok":
			return {"ab": "A", "full": "确认"}.get(layout(), BUTTONS.ok.text)
		"cancel":
			return {"ab": "B", "full": "返回"}.get(layout(), BUTTONS.cancel.text)
		"run":
			return "跑" if layout() != "classic" else BUTTONS.run.text
	return BUTTONS[name].text


func _font_base(name: String) -> int:
	if ghost() and name in ["ok", "cancel", "save"]:
		return 72 if name != "save" else 24
	if name == "hide" or name == "save":
		return 15 if name == "hide" else 20
	if name in ["ok", "cancel"] and layout() == "ab":
		return 34
	if BUTTONS[name].has("dir"):
		return 18
	if layout() == "full" and name in ["shift", "ctrl", "pageup", "pagedown", "ok", "cancel"]:
		return 17
	return 20


func _font_color(name: String) -> Color:
	if ghost() and name in ["ok", "cancel", "save"]:
		return GHOST_TEXT
	if layout() == "ab" and name == "ok":
		return Color(0.8, 0.965, 0.847)
	if layout() == "ab" and name == "cancel":
		return Color(0.773, 0.898, 1.0)
	return Color(0.9, 0.95, 1.0)


## 操作布局：原版虚拟按钮（Mehmet_GhostButtons）／改版按键
func style() -> String:
	return str(settings.get("style", "original"))


func ghost() -> bool:
	return style() == "original"


## 按键底色：原版 A／B 灰底（gradientFillRect 207,217,223 → 226,235,240，0.8）、Save 再叠一层暗色；其余照旧深蓝
func _style_button(name: String) -> void:
	var sb := (_buttons[name] as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	if ghost() and name in ["ok", "cancel", "save"]:
		sb.bg_color = Color8(216, 226, 231, 204) if name != "save" else Color8(130, 136, 139, 220)
		sb.set_border_width_all(0)
		if not _ghost_alpha.has(name):
			_ghost_alpha[name] = GHOST_IDLE
		(_buttons[name] as Panel).modulate = Color(1, 1, 1, _ghost_alpha[name])
	else:
		sb.bg_color = Color(0.07, 0.15, 0.24, 0.72)
		sb.set_border_width_all(1)
		_ghost_alpha.erase(name)
		(_buttons[name] as Panel).modulate = Color.WHITE


## Bitmap.drawJoyStickOutside：外圈白描边（线宽 10、被圆裁掉一半）、内 60% 半透黑；整体不透明度 150
func _draw_ghost_base() -> void:
	var r := _ghost_base.size.x / 2.0
	if r <= 0:
		return
	var c := Vector2(r, r)
	var k := r / 140.0
	_ghost_base.draw_circle(c, roundf(r * 0.6), Color(0, 0, 0, 0.6 * GHOST_STICK_ALPHA))
	_ghost_base.draw_arc(c, r - 2.5 * k, 0, TAU, 64, Color(1, 1, 1, GHOST_STICK_ALPHA), 5.0 * k, true)


## Bitmap.drawJoyStickInside：白底（0.8）、红芯（半径一半，242,12,0,0.8，黑描边 2）、黑外描边 5（裁掉一半），正中画主角行走图正面中间那格
func _draw_ghost_knob() -> void:
	var r := _ghost_knob.size.x / 2.0
	if r <= 0:
		return
	var c := Vector2(r, r)
	var k := r / GHOST_KNOB
	var a := GHOST_STICK_ALPHA
	_ghost_knob.draw_circle(c, r, Color(1, 1, 1, 0.8 * a))
	_ghost_knob.draw_circle(c, r / 2.0, Color(242 / 255.0, 12 / 255.0, 0, 0.8 * a))
	_ghost_knob.draw_arc(c, r / 2.0, 0, TAU, 48, Color(0, 0, 0, a), 2.0 * k, true)
	_ghost_knob.draw_arc(c, r - 1.25 * k, 0, TAU, 64, Color(0, 0, 0, 0.8 * a), 2.5 * k, true)
	var ch := knob_character()
	if ch.is_empty() or str(ch[0]) == "":
		return
	var p := XDB.img_path("characters", str(ch[0]))
	var tex: Texture2D = load(p) if p != "" else null
	if tex == null:
		return
	# ImageManager.isBigCharacter：开头的 !／$ 里有 $
	var prefix := ""
	for ch2 in str(ch[0]):
		if ch2 != "!" and ch2 != "$":
			break
		prefix += ch2
	var big := prefix.contains("$")
	var pw := tex.get_width() / (3.0 if big else 12.0)
	var ph := tex.get_height() / (4.0 if big else 8.0)
	var n := int(ch[1])
	var src := Rect2((n % 4 * 3 + 1) * pw, floorf(n / 4.0) * 4 * ph, pw, ph)
	# 原版画在摇杆头的 Bitmap（2r 见方）上，超出部分裁掉
	var full := Rect2(c - Vector2(pw, ph) * k / 2.0, Vector2(pw, ph) * k)
	var dst := full.intersection(Rect2(Vector2.ZERO, _ghost_knob.size))
	if dst.size.x <= 0 or dst.size.y <= 0:
		return
	var cut := Rect2(src.position + (dst.position - full.position) / k, dst.size / k)
	_ghost_knob.draw_texture_rect_region(tex, dst, cut, Color(1, 1, 1, a))


## 摇杆头上的行走图（$gamePlayer._characterName／_characterIndex）：地图主角，没有地图时取队长
func knob_character() -> Array:
	if not knob_character_override.is_empty():
		return knob_character_override
	var scene := _current_scene()
	var pl = scene.get("player") if scene != null else null
	if pl is Node and pl.get("character_name") != null:
		return [str(pl.character_name), int(pl.character_index)]
	var s := XState.current
	if s != null and not s.members().is_empty():
		var d: Dictionary = (s.members()[0] as XActor).data()
		return [str(d.get("characterName", "")), int(d.get("characterIndex", 0))]
	return []


## 摇杆头上次画的行走图（换了就重画）
var _knob_drawn := []


## 设置页用：改样式（操作布局、右侧布局、移动方式），立即生效并保存
func set_choice(key: String, value: String) -> void:
	var allowed: Array = {"style": STYLES, "layout": LAYOUTS}.get(key, MODES)
	if not allowed.has(value):
		return
	release_all()
	settings[key] = value
	apply_layout()
	_save()


## 设置页用：开关类（显示跑步键、地图点击移动、战斗点击操作）
func set_flag(key: String, value: bool) -> void:
	if not FLAGS.has(key):
		return
	release_all()
	settings[key] = value
	# 改版：战斗点击关掉时顺带显示屏幕按键（不然战斗里没法操作）
	if key == "battle_touch" and not value and hidden:
		hidden = false
	apply_layout()
	_save()


## 地图点按移动、战斗里点选项和目标是否放行（没有虚拟按键层＝桌面，一律放行）
static func map_tap_allowed() -> bool:
	return instance == null or bool(instance.settings.get("map_touch", true))


static func battle_tap_allowed() -> bool:
	return instance == null or bool(instance.settings.get("battle_touch", true))


## 改版默认值（回退开关 MODERN_DEFAULT = false：旧三键、战斗点击开）
static func default_settings() -> Dictionary:
	var d := DEFAULTS.duplicate()
	if not MODERN_DEFAULT:
		d["style"] = "modern"
		d["layout"] = "classic"
		d["battle_touch"] = true
	return d



func _place(p: Panel, r: Rect2, radius: float) -> void:
	p.position = r.position
	p.size = r.size
	(p.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(int(radius))


## 没拖过时：贴原来那两条边，边距取 max(原边距, 安全区缩进)。
func default_position(g: String, size: Vector2) -> Vector2:
	var spec: Dictionary = GROUPS[g]
	var base: Rect2 = _style_members(g).get("base", spec.rect)
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
	settings = default_settings()
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
	settings = default_settings()
	if data.get("stick_page") is bool:
		settings["stick_page"] = data.stick_page
	if STYLES.has(data.get("style")):
		settings["style"] = data.style
	if LAYOUTS.has(data.get("layout")):
		settings["layout"] = data.layout
	if MODES.has(data.get("mode")):
		settings["mode"] = data.mode
	for key in FLAGS:
		if data.get(key) is bool:
			settings[key] = data[key]
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
	var data := {"hidden": hidden, "positions": positions, "stick_page": bool(settings.get("stick_page", true)),
		"style": style(), "layout": layout(), "mode": move_mode()}
	for key in FLAGS:
		data[key] = bool(settings[key])
	for key in LIMITS:
		data[key] = settings[key]
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
