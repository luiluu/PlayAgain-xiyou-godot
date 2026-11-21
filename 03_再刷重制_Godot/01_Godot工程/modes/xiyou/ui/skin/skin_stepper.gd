class_name XSkinStepper
extends Control
## 【cc·天启篇·未经审查】T283 通用小件「数量选择」（T254 3.0）：一排圆钮「－10」「－」数字「＋」「＋10」「最多」，钮 44×44（「最多」64×44），
## 数字 26 号淡金 GOLD_LIGHT 居中；常驻在详情牌底（页面摆位置），商店、制作、赌场框都用。
## - 值只在 min_value～max_value（max 小于 min 时按 min）。改了值发 value_changed(v)；值的「真身」在页面那边时，
##   页面在 value_changed 里写回自己的状态，再 set_value 回来（重复设同一个值不发信号）。
## - 焦点（focused）：键盘／手柄落在数量条上时为真，整条原地高亮（不弹新窗）。这时 handle_input 认
##   ←/→ ±1、↑/↓ ±10、E 到最多、Q 回 1（同商店旧数量窗的键）、数字键直接敲（第一位重新开始、退格删一位）。
##   确定、取消不在这里接：页面自己定「确定＝成交」「取消＝回列表、数量复位」。
## - 触屏：点钮就改（按住 0.4 秒后每 0.08 秒连加一次）；点中间的数字弹数字键盘手输（不自动弹）。
##   这些点击在列表态也能用，不用先进数量条；点了会发 touched()，页面需要时据此把焦点挪到数量条。
## - 禁用（enabled＝false）：钮和数字变暗、不响应（如买不起）。
## 用法：
##   var st := XSkinStepper.new()
##   card.add_child(st); st.position = …; st.size = Vector2(card_w, XSkinStepper.H)
##   st.set_range(1, max_buy, 1)
##   st.value_changed.connect(func(v): shop_number = v)
##   # 页面按键：焦点在数量条时先 if st.handle_input(event): return true
## 声音：钮改值响光标音 XSound.system(0)（值没变不响）；sound＝false 时不响（页面自己响）。

signal value_changed(value: int)
## 被点过（钮、数字）：页面据此把焦点挪到数量条
signal touched

const H := 44.0
const BTN := 44.0
const MAX_W := 64.0
const GAP := 6.0
const NUM_FS := 26
const HOLD_DELAY := 0.4
const HOLD_STEP := 0.08
## 玩家可见文字（待小A 审）：「最多」
const MAX_TEXT := "最多"
## 钮：[字, 步长]；步长 0＝到最多
const BUTTONS := [["－10", -10], ["－", -1], ["＋", 1], ["＋10", 10], [MAX_TEXT, 0]]

var value := 1
var min_value := 1
var max_value := 1
var focused := false:
	set(v):
		focused = v
		queue_redraw()
var enabled := true:
	set(v):
		enabled = v
		if not v:   # 禁用时停掉按住连加、收起手输框（小A核 P2-4）
			_hold = -1
			_press = -1
			close_editor()
		queue_redraw()
## 要不要「最多」钮
var show_max := true
var sound := true
var _num_text := ""
var _hold := -1          # 按住的钮号
var _hold_t := 0.0
var _press := -1         # 按下反馈
var _edit: LineEdit


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, H)
	resized.connect(queue_redraw)


## 一次设好范围和值（不发信号）
func set_range(lo: int, hi: int, v: int) -> void:
	min_value = lo
	max_value = maxi(hi, lo)
	value = clampi(v, min_value, max_value)
	queue_redraw()


## 设值（夹到范围里）；变了发 value_changed（emit＝false 不发）
func set_value(v: int, emit := true) -> bool:
	var nv := clampi(v, min_value, maxi(max_value, min_value))
	if nv == value:
		queue_redraw()
		return false
	value = nv
	queue_redraw()
	if emit:
		value_changed.emit(value)
	return true


func step(d: int) -> bool:
	_num_text = ""
	return _set_with_sound(value + d)


func to_max() -> bool:
	_num_text = ""
	return _set_with_sound(max_value)


func to_min() -> bool:
	_num_text = ""
	return _set_with_sound(min_value)


func _set_with_sound(v: int) -> bool:
	var ch := set_value(v)
	if ch and sound:
		XSound.system(0)
	return ch


## 敲一位数字（0～9）或退格（d＜0）：超上限夹到上限，0 或空算下限
func type_digit(d: int) -> bool:
	_num_text = _num_text.left(-1) if d < 0 else (_num_text + str(d)).left(9)
	var n := int(_num_text) if _num_text != "" else 0
	if n > max_value:
		n = max_value
		_num_text = str(max_value)
	return _set_with_sound(maxi(n, min_value))


## 焦点在数量条时页面转进来；用掉了返回 true（确定、取消不接）
func handle_input(event: InputEvent) -> bool:
	if not enabled:
		return false
	if event.is_action_pressed("ui_right", true):
		step(1)
		return true
	if event.is_action_pressed("ui_left", true):
		step(-1)
		return true
	if event.is_action_pressed("ui_up", true):
		step(10)
		return true
	if event.is_action_pressed("ui_down", true):
		step(-10)
		return true
	var pd := XMenu.page_dir(event)
	if pd > 0:
		to_max()
		return true
	if pd < 0:
		to_min()
		return true
	var dg := _digit_of(event)
	if dg >= -1:
		type_digit(dg)
		return true
	return false


static func _digit_of(event: InputEvent) -> int:
	if not (event is InputEventKey and event.pressed):
		return -2
	var k: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if k >= KEY_0 and k <= KEY_9:
		return k - KEY_0
	if k >= KEY_KP_0 and k <= KEY_KP_9:
		return k - KEY_KP_0
	if k == KEY_BACKSPACE:
		return -1
	return -2


# ---- 摆位 ----

## 第 i 个钮的框（0～4 同 BUTTONS；数字在 1 和 2 之间）。宽不够时数字区先缩、钮之间的空再缩
func button_rect(i: int) -> Rect2:
	var r := _layout()
	return r[i] if i < r.size() else Rect2()


func number_rect() -> Rect2:
	return _layout()[5]


func _layout() -> Array:
	var y := (size.y - H) / 2.0
	var mw := MAX_W if show_max else 0.0
	var gap := GAP
	var fixed := BTN * 4 + mw
	var num_w := size.x - fixed - gap * (5 if show_max else 4)
	if num_w < 48.0:
		gap = 3.0
		num_w = maxf(size.x - fixed - gap * (5 if show_max else 4), 24.0)
	var x := 0.0
	var out := []
	for i in 2:
		out.append(Rect2(x, y, BTN, H))
		x += BTN + gap
	var nr := Rect2(x, y, num_w, H)
	x += num_w + gap
	for i in 2:
		out.append(Rect2(x, y, BTN, H))
		x += BTN + gap
	out.append(Rect2(x, y, mw, H) if show_max else Rect2())
	out.append(nr)
	return out


# ---- 点 ----

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	if not event.pressed:
		_hold = -1
		_press = -1
		queue_redraw()
		return
	if not enabled:
		return
	touched.emit()
	if number_rect().has_point(event.position):
		open_editor()
		return
	for i in BUTTONS.size():
		if i == 4 and not show_max:
			continue
		if button_rect(i).has_point(event.position):
			_press = i
			_fire(i)
			_hold = i if int(BUTTONS[i][1]) != 0 else -1
			_hold_t = -HOLD_DELAY
			queue_redraw()
			return


func _fire(i: int) -> void:
	var d := int(BUTTONS[i][1])
	if d == 0:
		to_max()
	else:
		step(d)


func _process(delta: float) -> void:
	if _hold < 0:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_hold = -1
		_press = -1
		queue_redraw()
		return
	_hold_t += delta
	while _hold_t >= HOLD_STEP:
		_hold_t -= HOLD_STEP
		_fire(_hold)


## 点数字：弹数字键盘（藏起来的 LineEdit 拿焦点；桌面上也能直接打字，回车或点别处收起）
func open_editor() -> void:
	if _edit == null:
		_edit = LineEdit.new()
		_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		_edit.modulate.a = 0.0
		_edit.size = Vector2(4, 4)
		_edit.text_changed.connect(func(tx: String) -> void:
			var digits := ""
			for ch in tx:
				if ch >= "0" and ch <= "9":
					digits += ch
			_num_text = ""
			if digits == "":
				_set_with_sound(min_value)   # 删空＝回下限（同键盘退格删到空，小A核 P2-4）
			for ch in digits.left(9):
				type_digit(int(ch))
			if _edit.text != _num_text:
				_edit.text = _num_text
				_edit.caret_column = _num_text.length())
		_edit.text_submitted.connect(func(_tx: String) -> void: close_editor())
		_edit.focus_exited.connect(close_editor)
		add_child(_edit)
	_edit.position = number_rect().position
	_num_text = ""
	_edit.text = ""
	_edit.visible = true
	_edit.grab_focus()


func close_editor() -> void:
	if _edit != null and _edit.visible:
		_edit.visible = false
		_edit.release_focus()
	_num_text = ""


func editing() -> bool:
	return _edit != null and _edit.visible


# ---- 画 ----

func _draw() -> void:
	var ci := get_canvas_item()
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var dim := not enabled
	var pol := XUiSkin.polish_on()
	if pol:
		var cradle := StyleBoxFlat.new()
		cradle.bg_color = Color(0.05, 0.042, 0.04, 0.58)
		cradle.border_color = Color(XUiSkin.GOLD, 0.48) if (focused and enabled) else Color(XUiSkin.line_c(), 0.24)
		cradle.set_border_width_all(1)
		cradle.set_corner_radius_all(int((H + 6.0) / 2.0))
		cradle.anti_aliasing = true
		cradle.draw(ci, Rect2(Vector2(-4, (size.y - H) / 2.0 - 3), Vector2(size.x + 8, H + 6)))
	if focused and enabled:
		var all := Rect2(Vector2(-6, (size.y - H) / 2.0 - 4), Vector2(size.x + 12, H + 8))
		XUiSkin.draw_select(ci, all, XUiSkin.breath_alpha(), 0.55)
	for i in BUTTONS.size():
		if i == 4 and not show_max:
			continue
		var r := button_rect(i)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(H / 2.0))
		sb.anti_aliasing = true
		sb.bg_color = (Color(0.11, 0.095, 0.09, 0.72) if pol else Color(0, 0, 0, 0.35)) if _press != i else Color(XUiSkin.SEL_FILL, 0.5)
		sb.border_color = Color(XUiSkin.line_c(), 0.25 if dim else 0.55) if pol else Color(XUiSkin.LINE, 0.25 if dim else 0.6)
		sb.set_border_width_all(1)
		sb.bg_color = XSkinButton.press_color(sb.bg_color, _press == i)
		r = XSkinButton.press_rect(r, _press == i)
		sb.draw(ci, r)
		var t := str(BUTTONS[i][0])
		var fs := XUiSkin.FS_AUX_MAX if i != 4 else XUiSkin.fs(16)
		var fit := XSkinList.fit_text(body, t, r.size.x - 6.0, fs, 12)
		var tw := body.get_string_size(str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1])).x
		XUiSkin.ds(self, body, Vector2(r.position.x + (r.size.x - tw) / 2.0, r.position.y + r.size.y / 2.0 + int(fit[1]) * 0.36), str(fit[0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1]), XUiSkin.TEXT_3 if dim else XUiSkin.TEXT)
	var nr := number_rect()
	var vt := XSkinStepper.group(value)
	var nfit := XSkinList.fit_text(num, vt, nr.size.x, XUiSkin.fs(NUM_FS), 15)
	var vw := num.get_string_size(str(nfit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(nfit[1])).x
	XUiSkin.ds(self, num, Vector2(nr.position.x + (nr.size.x - vw) / 2.0, nr.position.y + nr.size.y / 2.0 + int(nfit[1]) * 0.36), str(nfit[0]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(nfit[1]), XUiSkin.TEXT_3 if dim else XUiSkin.GOLD_LIGHT)


## 千分位（同 XSkinTemplatePage._group）
static func group(v: int) -> String:
	return XSkinTemplatePage._group(v)
