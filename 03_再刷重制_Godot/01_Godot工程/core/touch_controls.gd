class_name XTouchControls
extends CanvasLayer
## 触屏虚拟按键（跨平台适配二期，cc BH 2026-11-05）：照原版二合一包 android-integration.js 的布局，
## 左下摇杆（中心 16% 内不动；战斗与菜单照原版只取一个轴，地图 MV 是四方向，也只取一个轴）、右下确定／取消／跑步、右上「隐藏按键」。
## 按键都转成 InputEventAction（方向、确定、取消）或 Shift 物理键（跑步，MV updateDashing 看 Shift），按住照 XKeyRepeat 的 24／6 帧连发。
## 按到这些按键的触点（含 Godot 由第一指转出的鼠标事件）在这里吃掉，不再传给地图和界面，也不算两指取消。
## 只在 XPlatform.is_touch() 时由 GameApp 建；切后台、返回键时全部松开。隐藏状态存 user://touch_controls.json。

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
}

var hidden := false
var root: Control
var _stick_base: Panel
var _stick_knob: Panel
var _buttons := {}
## 触点编号 → 按着的东西（"stick" 或按键名）
var _touches := {}
var _dir := ""
var _held := {}  # 动作名 → 按住的帧数
var _catch_label: Label


func _ready() -> void:
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
		var spec: Dictionary = BUTTONS[name]
		var p := _panel(spec.rect, 12.0, Color(0.07, 0.15, 0.24, 0.72))
		var l := Label.new()
		l.text = spec.text
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 20 if name != "hide" else 15)
		l.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
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
	_apply_hidden()


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
	if (BUTTONS.hide.rect as Rect2).has_point(pos):
		return "hide"
	if hidden:
		return ""
	if pos.distance_to(STICK_CENTER) <= STICK_RADIUS * 1.2:
		return "stick"
	for name in BUTTONS:
		if (BUTTONS[name].rect as Rect2).has_point(pos):
			return name
	return ""


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var what := hit(t.position)
			if what == "":
				return
			_touches[t.index] = what
			_press(what, t.position)
			get_viewport().set_input_as_handled()
		elif _touches.has(t.index):
			_release(_touches[t.index])
			_touches.erase(t.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _touches.get(d.index, "") == "stick":
			_move_stick(d.position)
			get_viewport().set_input_as_handled()
		elif _touches.has(d.index):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		# Godot 由第一指转出的鼠标事件（先于触屏事件本身到）：落在按键上、或第一指正按着按键时整段吃掉
		if _touches.has(0) or (event is InputEventMouseButton and hit((event as InputEventMouseButton).position) != ""):
			get_viewport().set_input_as_handled()


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
				_held[spec.action] = 0
			elif spec.has("key"):
				_send_key(spec.key, true)
			(_buttons[what] as Panel).modulate = Color(1.4, 1.4, 1.4)


func _release(what: String) -> void:
	match what:
		"stick":
			_set_dir("")
			_stick_knob.position = STICK_CENTER - _stick_knob.size / 2
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
static func stick_direction(offset: Vector2) -> String:
	if offset.length() <= STICK_RADIUS * DEAD_ZONE:
		return ""
	if absf(offset.x) > absf(offset.y):
		return "ui_left" if offset.x < 0 else "ui_right"
	return "ui_up" if offset.y < 0 else "ui_down"


func _move_stick(pos: Vector2) -> void:
	var offset := pos - STICK_CENTER
	var travel := STICK_RADIUS - 26.0
	var shown := offset.limit_length(travel)
	_stick_knob.position = STICK_CENTER + shown - _stick_knob.size / 2
	_set_dir(stick_direction(offset))


func _set_dir(action: String) -> void:
	if action == _dir:
		return
	if _dir != "":
		_send_action(_dir, false)
		_held.erase(_dir)
	_dir = action
	if action != "":
		_send_action(action, true)
		_held[action] = 0


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


func _physics_process(_delta: float) -> void:
	# 按住连发：24 帧后每 6 帧再按一次（XKeyRepeat 只管实体键）
	for action in _held.keys():
		var n: int = _held[action] + 1
		_held[action] = n
		if n >= REPEAT_WAIT and (n - REPEAT_WAIT) % REPEAT_INTERVAL == 0:
			_send_action(action, true)


func _process(_delta: float) -> void:
	var platform := get_parent() as XPlatform
	var catching := platform != null and platform.is_catching_up()
	_catch_label.visible = catching
	if catching:
		var left := int(platform.catch_up_left())
		_catch_label.text = "后台挂机补跑中（×%d），还剩 %d:%02d\n点屏幕停止" % [XPlatform.CATCH_UP_SPEED, left / 60, left % 60]


func _apply_hidden() -> void:
	for name in _buttons:
		(_buttons[name] as Panel).visible = name == "hide" or not hidden
	_stick_base.visible = not hidden
	_stick_knob.visible = not hidden
	var label := (_buttons.hide as Panel).get_child(0) as Label
	label.text = "显示按键" if hidden else "隐藏按键"


func _load() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH)) if FileAccess.file_exists(SETTINGS_PATH) else null
	hidden = data is Dictionary and bool(data.get("hidden", false))


func _save() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"hidden": hidden}))
