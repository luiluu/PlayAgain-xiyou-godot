class_name XSkinKeyHints
extends Control
## 【cc·天启篇·未经审查】底部按键提示：右对齐一排「[键] 说明」，键名套圆角胶囊框（小A文字审：按键提示统一套框）。
## 放在页面右下，离底 10（XUiSkin.HINT_BOTTOM）；place(view) 按视口和安全边距摆。

## [[键, 说明], …]，如 [["确定", "进入"], ["取消", "返回"], ["Q / E", "换组"]]
var hints: Array = []
var font_size := 15
const H := 22.0
## 收口批（TOUCH_V2）触屏时：每条提示是一颗能点的胶囊（高 TOUCH_H，不写键名只写说明；「Q / E」这类两向键写「‹ 说明 ›」，点左半／右半）
const TOUCH_H := 44.0
const TOUCH_FS := 18
var _press := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_hints(arr: Array) -> void:
	hints = arr
	mouse_filter = Control.MOUSE_FILTER_STOP if touch_mode() else Control.MOUSE_FILTER_IGNORE
	size = Vector2(total_width(), height())
	queue_redraw()


## 触屏样式：TOUCH_V2 开着且是触屏设备（或测试强制）
static func touch_mode() -> bool:
	if not XUiSkin.TOUCH_V2:
		return false
	return XUiSkin.touch()


func height() -> float:
	return TOUCH_H if touch_mode() else H


## 两向键（「Q / E」「← / →」「↑ / ↓」「左右」「上下」）：点左半是前一个，右半是后一个。
## 别的带「/」的是同一件事的几个键（如「Y / 取消」），是单键，不画 ‹ ›（小A核 P1-2）
const PAIR_KEYS := ["Q/E", "←/→", "↑/↓", "左右", "上下"]


static func is_pair(key: String) -> bool:
	return PAIR_KEYS.has(key.replace(" ", ""))


## 键名→点了要发的输入：[[动作或键码, 是不是动作], …]（两向键两个；「Y / 取消」这类几选一的取第一个认得的，动作优先）
static func key_events(key: String) -> Array:
	var k := key.replace(" ", "").replace("键盘", "")
	match k:
		"确定":
			return [["ui_accept", true]]
		"取消":
			return [["ui_cancel", true]]
		"Q/E":
			return [[KEY_Q, false], [KEY_E, false]]
		"←/→", "左右":
			return [["ui_left", true], ["ui_right", true]]
		"↑/↓", "上下":
			return [["ui_up", true], ["ui_down", true]]
	if k.contains("/"):
		var alts := Array(k.split("/", false)).map(func(x): return key_events(str(x)))
		for want_action in [true, false]:
			for ev in alts:
				if not (ev as Array).is_empty() and bool(ev[0][1]) == want_action:
					return ev
		return []
	if k.length() == 1:
		var code := OS.find_keycode_from_string(k)
		if code != KEY_NONE:
			return [[code, false]]
	return []


func _chip_text(h: Array) -> String:
	return ("‹ %s ›" % str(h[1])) if is_pair(str(h[0])) else str(h[1])


func _chip_w(h: Array) -> float:
	return XUiSkin.font("body").get_string_size(_chip_text(h), HORIZONTAL_ALIGNMENT_LEFT, -1, TOUCH_FS).x + 36.0


## 触屏样式下第 i 条胶囊的位置（本控件坐标）
func chip_rect(i: int) -> Rect2:
	var x := 0.0
	for j in i:
		x += _chip_w(hints[j]) + 10.0
	return Rect2(x, 0, _chip_w(hints[i]), TOUCH_H)


## 点到哪条：返回 [条号, 0/1（两向键的左右半）]；没点到 [-1, 0]
func hit(p: Vector2) -> Array:
	for i in hints.size():
		var r := chip_rect(i)
		if r.has_point(p):
			return [i, 1 if p.x > r.get_center().x else 0]
	return [-1, 0]


## 点了第 i 条（half 是两向键的左右半）：发对应的按下＋松开
static func fire(key: String, half := 0) -> bool:
	var evs := key_events(key)
	if evs.is_empty():
		return false
	var ev: Array = evs[clampi(half, 0, evs.size() - 1)]
	for pressed in [true, false]:
		if bool(ev[1]):
			var a := InputEventAction.new()
			a.action = str(ev[0])
			a.pressed = pressed
			Input.parse_input_event(a)
		else:
			var e := InputEventKey.new()
			e.physical_keycode = int(ev[0])
			e.keycode = int(ev[0])
			e.pressed = pressed
			Input.parse_input_event(e)
	return true


func _gui_input(event: InputEvent) -> void:
	if not touch_mode():
		return
	var p := Vector2.INF
	var down := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		p = event.position
		down = event.pressed
	elif event is InputEventScreenTouch:
		p = event.position
		down = event.pressed
	if p == Vector2.INF:
		return
	accept_event()
	var h := hit(p)
	if down:
		_press = int(h[0])
		queue_redraw()
		return
	var i := _press
	_press = -1
	queue_redraw()
	if i >= 0 and i == int(h[0]):
		fire.call_deferred(str(hints[i][0]), int(h[1]))


func total_width() -> float:
	var f := XUiSkin.font("body")
	if touch_mode():
		return 0.0 if hints.is_empty() else chip_rect(hints.size() - 1).end.x
	var w := 0.0
	for i in hints.size():
		var h: Array = hints[i]
		w += f.get_string_size(str(h[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 20 + 6
		w += f.get_string_size(str(h[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if i < hints.size() - 1:
			w += 16
	return w


## 摆到视口右下：右边对齐安全边距（16:9 为 24），并让出右下角版本号（right_edge）
func place(view: Vector2) -> void:
	position = Vector2(right_edge(view) - total_width(), view.y - XUiSkin.HINT_BOTTOM - height())


## 按键提示的右边：安全边距，且让出右下角版本号（XVersionLabel，全局一直显示，字号 14）。
## 原在 1A 主菜单（XSkinMainMenu.hint_right），ui-skin-3b 收进这里，用 place() 的页都让位（小A 3B 核查 P2）。
static func right_edge(view: Vector2) -> float:
	var right := view.x - XSkinLayout.margin_for(view.x)
	if XVersionLabel.SHOW:
		var vw := GameFont.current().get_string_size(XVersionLabel.version_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, XVersionLabel.FONT_SIZE).x
		right = minf(right, view.x - XVersionLabel.MARGIN.x - vw - 16.0)
	return right


func _draw() -> void:
	var f := XUiSkin.font("body")
	var ci := get_canvas_item()
	if touch_mode():
		for i in hints.size():
			var r := chip_rect(i)
			var cb := StyleBoxFlat.new()
			cb.bg_color = Color(XUiSkin.BG, 0.85) if i != _press else Color(XUiSkin.SEL2_FILL_R, 0.9)
			cb.border_color = Color(XUiSkin.GOLD, 0.6)
			cb.set_border_width_all(1)
			cb.set_corner_radius_all(int(TOUCH_H / 2.0))
			cb.draw(ci, r)
			var t := _chip_text(hints[i])
			var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, TOUCH_FS).x
			draw_string(f, Vector2(r.position.x + (r.size.x - tw) / 2.0, r.size.y / 2.0 + TOUCH_FS * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, TOUCH_FS, XUiSkin.TEXT)
		return
	var x := 0.0
	for h in hints:
		var kw := f.get_string_size(str(h[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 20
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = XSkinArt.bg_text_2()
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(11)
		if XSkinArt.read_on():   # 可读性：键帽垫深底
			sb.draw_center = true
			sb.bg_color = Color(0, 0, 0, 0.55)
		sb.draw(ci, Rect2(x, 0, kw, H))
		XSkinArt.bg_string(self, f, Vector2(x + 10, H / 2.0 + font_size * 0.36), str(h[0]), font_size, XUiSkin.TEXT)
		x += kw + 6
		XSkinArt.bg_string(self, f, Vector2(x, H / 2.0 + font_size * 0.36), str(h[1]), font_size, XSkinArt.bg_text_2())
		x += f.get_string_size(str(h[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 16
