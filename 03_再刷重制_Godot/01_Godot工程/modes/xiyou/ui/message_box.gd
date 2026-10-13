class_name XMessageBox
extends Control
## 对话框，照正式版运行时逐帧复现（参照：04_验证/本地结果/原版参照/02、03、06、30～）：
## - 消息窗 MV Window_Message＋YEP_MessageCore：全宽 1280×172（4 行），位置 上/中/下 = y 0/274/548；
##   背景 窗口/暗底/透明；头像 144×144 画在内容 (0,0)，正文从 x 168 起（无头像从 0）；
##   每帧处理一个字符（XMVText），行高 = 本行最大字号 + 8；放不下自动换行（zidonghuanhang）；
##   满 4 行或 \! 时等待按键（先等 10 帧），底边显示翻页标记；确定/取消/点击都可翻页，打字中按下则本页瞬显；
##   按住 PageDown 快进（YEP Fast Forward）；打字音 Cursor1 音量 50、每 3 帧一次、音高 ±10（YEP_X_ExtMesPack1）。
## - 名字框 YEP Window_NameBox：\n<名字>（\nc<> 居中、\nr<> 靠右等），高 64，宽 = 名字宽 + 28 + 140，
##   名字用 \c[6] 画在 x 70；消息窗在上方时放在消息窗下面，否则在上面；消息结束 4 帧后关闭。
## - 选项窗 MV Window_ChoiceList＋YEP：宽 = max(96, 最宽选项 + 12) + 28，每行 36，最多 6 行（消息窗跨过画面中线时 4 行），
##   超出可滚动；默认靠右，消息窗在下时贴在其上方。默认选项 -1 时不选中。
## - 数值输入 MV Window_NumberInput：每位 32 宽、居中；上下改数位、左右换位；用过鼠标时显示 ButtonSet 按钮。
## - 开合动画：每帧 openness ±32；连续对话且位置/背景不变时窗口不关闭。
## run() 等对话结束后返回：选项序号（取消返回 cancel_type 规则下的值）或输入的数值；纯文字返回 0。

signal _finished(result: int)

const MSG_HEIGHT := 172.0
const SCREEN := Vector2(1280, 720)
const FACE_INDENT := 168.0
const NAME_PAD := 140.0
const NAME_BUFFER_X := -28.0
const CHOICE_MAX_ROWS := 6
const LH := 36.0
const DIGIT_W := 32.0
const LETTER_SE := {"name": "Cursor1", "volume": 50, "pitch": 100, "pitch_var": 10, "interval": 2}

## 自动测试用：auto 为真时文字立即结束，选项/数值依次取 auto_answers（取完后选第一个/保持原值）。
static var auto := false
static var auto_answers: Array = []
static var transcript: Array = []
## 本帧对话框用掉了按键（地图据此不在同一帧再处理取消/确定）
static var _consumed_frame := -1

var win: XMVWindow
var name_win: XMVWindow
var choice_win: XMVWindow
var num_win: XMVWindow
var _num_buttons: Control

var _busy := false
var _queue: Array = []
var _msg := {}
var _pending_start := false
var _state: XMVText
var _page_glyphs: Array = []
var _face := ""
var _face_index := 0
var _wait := 0
var _show_fast := false
var _line_fast := false
var _pause_skip := false
var _sound_count := 0
var _msg_y := SCREEN.y - MSG_HEIGHT
var _settings := []

var _name_glyphs: Array = []
var _name_active := false
var _name_counter := 0

var _input_mode := ""
var _choices: Array = []
var _choice_index := 0
var _choice_top := 0
var _choice_rows := 1
var _cancel_type := -1
var _choice_glyphs: Array = []
var _touching := false
var _number := 0
var _digits := 1
var _digit_index := 0
var _buttons_visible := false
var _button_down := -1

var _in := {}
var _last_touch := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# MV 场景窗口顺序：消息窗、选项窗、数值输入；名字框加在场景上，盖在所有窗口之上
	win = _make_window(_paint_message)
	choice_win = _make_window(_paint_choices)
	num_win = _make_window(_paint_number)
	_num_buttons = Control.new()
	_num_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_num_buttons.draw.connect(_draw_buttons)
	num_win.add_child(_num_buttons)
	name_win = _make_window(_paint_name)
	name_win.size = Vector2(240, LH + 28)


func _make_window(painter: Callable) -> XMVWindow:
	var w := XMVWindow.make(self, Rect2(0, 0, 0, 0), 255, painter)
	w.openness = 0
	return w


static func consumed_input_this_frame() -> bool:
	return _consumed_frame == Engine.get_process_frames()


func is_busy() -> bool:
	return _busy


# ---- 对外接口 ----
func show_text(face_name: String, face_index: int, lines: Array, background := 0, position_type := 2) -> void:
	await run({"face": face_name, "index": face_index, "background": background, "position": position_type, "lines": lines})


func show_text_with_choices(face_name: String, face_index: int, lines: Array, options: Array, cancel_type: int) -> int:
	return await run({"face": face_name, "index": face_index, "lines": lines, "choices": options, "cancel": cancel_type})


func choose(options: Array, cancel_type: int) -> int:
	return await run({"choices": options, "cancel": cancel_type})


## msg：face, index, background(0/1/2), position(0/1/2), lines；
## 选项 choices, cancel（事件参数：-1 不可取消、-2 取消分支、其他为选项序号）, default, choice_position, choice_background；
## 数值输入 number_value（当前变量值）, digits。
func run(msg: Dictionary) -> int:
	while _busy:
		await _finished
	_busy = true
	if auto:
		var r := _auto_result(msg)
		await get_tree().process_frame
		_busy = false
		return r
	_msg = msg
	_pending_start = true
	_try_start()
	var result: int = await _finished
	return result


func _auto_result(msg: Dictionary) -> int:
	var lines: Array = msg.get("lines", [])
	if not lines.is_empty():
		transcript.append(XMVText.plain(_strip_message_codes("\n".join(lines))))
	var choices: Array = msg.get("choices", [])
	if not choices.is_empty():
		var r := int(auto_answers.pop_front()) if not auto_answers.is_empty() else 0
		transcript.append("选择：" + XMVText.plain(str(choices[r])) if r >= 0 and r < choices.size() else "选择：取消")
		return r
	if msg.has("digits"):
		var v := int(auto_answers.pop_front()) if not auto_answers.is_empty() else int(msg.get("number_value", 0))
		transcript.append("输入：%d" % v)
		return v
	return 0


## 测试/记录用：去掉名字框与头像代码
static func _strip_message_codes(s: String) -> String:
	s = RegEx.create_from_string("(?i)\\\\(?:n[1-5cr]?)<[^>]*>").sub(s, "", true)
	return RegEx.create_from_string("(?i)\\\\af\\[\\d+\\]").sub(s, "", true)


# ---- 开始（Window_Message.startMessage / startInput） ----
func _try_start() -> void:
	if not _pending_start:
		return
	var lines: Array = _msg.get("lines", [])
	var settings := [int(_msg.get("background", 0)), int(_msg.get("position", 2))]
	# checkToNotClose：正在关闭但还没合上、设置不变 → 继续开着
	if win.is_closing() and win.is_open() and not lines.is_empty() and settings == _settings:
		win.open()
	if win.is_opening() or win.is_closing():
		return
	_pending_start = false
	if lines.is_empty():
		_start_input()
		return
	_settings = settings
	_start_message()


func _start_message() -> void:
	_name_active = false
	_face = str(_msg.get("face", ""))
	_face_index = int(_msg.get("index", 0))
	var text := XMVText.convert_escapes("\n".join(_msg.get("lines", [])))
	text = _convert_message_codes(text)
	_state = XMVText.new(text, 0, 0, SCREEN.x - XMVWindow.PADDING * 2)
	_new_page()
	_update_placement()
	win.background_type = int(_msg.get("background", 0))
	win.open()
	_refresh_name_placement()


## YEP convertNameBox / convertActorFace
func _convert_message_codes(text: String) -> String:
	var re := RegEx.create_from_string("(?i)\u001bAF\\[(\\d+)\\]")
	var m := re.search(text)
	while m:
		var a := XDB.rec("Actors", int(m.get_string(1)))
		var st := XState.current
		if st and st.actors.has(int(m.get_string(1))):
			var d: Dictionary = st.actor(int(m.get_string(1))).data()
			a = d
		if not a.is_empty():
			_face = str(a.get("faceName", ""))
			_face_index = int(a.get("faceIndex", 0))
		text = text.substr(0, m.get_start()) + text.substr(m.get_end())
		m = re.search(text, m.get_start())
	var nre := RegEx.create_from_string("(?i)\u001bN([1-5CR]?)<(.*?)>")
	m = nre.search(text)
	while m:
		var pos: int = {"": 1, "1": 1, "2": 2, "3": 3, "C": 3, "4": 4, "5": 5, "R": 5}.get(m.get_string(1).to_upper(), 1)
		_refresh_name(m.get_string(2), pos)
		text = text.substr(0, m.get_start()) + text.substr(m.get_end())
		m = nre.search(text, m.get_start())
	return text


## Window_Message.newPage：清空、复位字体、载入头像、x = newLineX、y = 0
func _new_page() -> void:
	_state.glyphs = []
	_page_glyphs = _state.glyphs
	_state.size = XUI.FONT_SIZE
	_state.color = XUI.TEXT
	_state.left = FACE_INDENT if _face != "" else 0.0
	_state.x = _state.left
	_state.y = 0
	_state.height = _state.calc_height()
	_show_fast = false
	_line_fast = false
	_pause_skip = false
	_sound_count = 0
	win.refresh()


## Window_Message.updatePlacement：y = 位置 ×（720 − 高）/ 2
func _update_placement() -> void:
	var pos := int(_msg.get("position", 2))
	_msg_y = pos * (SCREEN.y - MSG_HEIGHT) / 2.0
	win.set_rect(Rect2(0, _msg_y, SCREEN.x, MSG_HEIGHT))


# ---- 名字框 ----
func _refresh_name(raw: String, pos: int) -> void:
	var t := XMVText.new("\u001bC[6]" + raw)
	var w := ceilf(t.run() + XMVWindow.PADDING * 2 + NAME_PAD)
	t = XMVText.new("\u001bC[6]" + raw, NAME_PAD / 2.0, 0, w - XMVWindow.PADDING * 2)
	t.run()
	_name_glyphs = t.glyphs
	name_win.size = Vector2(w, LH + XMVWindow.PADDING * 2)
	name_win.set_meta("pos", pos)
	name_win.open()
	_name_active = true
	_name_counter = 4
	name_win.refresh()


func _refresh_name_placement() -> void:
	if not _name_active:
		return
	var pos: int = name_win.get_meta("pos", 1)
	var w := name_win.size.x
	var x := 0.0
	match pos:
		1:
			x = win.position.x + NAME_BUFFER_X
		2:
			x = win.position.x + win.size.x * 3.0 / 10.0 - w / 2.0
		3:
			x = win.position.x + win.size.x / 2.0 - w / 2.0
		4:
			x = win.position.x + win.size.x * 7.0 / 10.0 - w / 2.0
		_:
			x = win.position.x + win.size.x - w + NAME_BUFFER_X
	x = clampf(x, 0, SCREEN.x - w)
	var y := win.position.y - name_win.size.y
	if int(_msg.get("position", 2)) == 0 or y < 0:
		y = win.position.y + win.size.y
	name_win.position = Vector2(x, y)


## Window_NameBox.update：消息结束后 4 帧关闭；消息窗正在关闭时跟着它合上
func _update_name_box() -> void:
	if _name_active or name_win.is_closed() or name_win.is_closing():
		return
	if _name_counter > 0:
		_name_counter -= 1
		return
	if win.is_closing():
		name_win.openness = win.openness
	name_win.close()


# ---- 每帧（Window_Message.update） ----
func _physics_process(_delta: float) -> void:
	_update_name_box()
	if not _busy:
		_in.clear()
		return
	if _pending_start:
		_try_start()
	elif _input_mode == "choice":
		_update_choice()
	elif _input_mode == "number":
		_update_number()
	elif win.is_opening() or win.is_closing():
		pass
	elif _wait > 0:
		_wait -= 1
	elif win.pause:
		if _triggered():
			_consume()
			win.pause = false
			if _state == null:
				_terminate(0)
		elif win.pause and _fast_forward() and _state == null:
			win.pause = false
			_terminate(0)
	elif _state != null:
		_update_message()
	_in.clear()


func _update_message() -> void:
	while not _state.at_end():
		if _needs_new_page():
			_new_page()
		if _triggered() or _fast_forward():
			_consume()
			_show_fast = true
		_process_character()
		if not _show_fast and not _line_fast:
			break
		if win.pause or _wait > 0:
			break
	win.refresh()
	# YEP_X_ExtMesPack1：每次 updateMessage 计数，每 3 帧一次打字音
	_sound_count -= 1
	if _sound_count < 0:
		_sound_count = int(LETTER_SE.interval)
		XSound.play(LETTER_SE.name, LETTER_SE.volume, LETTER_SE.pitch + randi_range(-LETTER_SE.pitch_var, LETTER_SE.pitch_var))
	if _state.at_end():
		_on_end_of_text()


func _needs_new_page() -> bool:
	return not _state.at_end() and _state.y + _state.height > win.size.y - XMVWindow.PADDING * 2


func _process_character() -> void:
	var r := _state.step()
	if r.get("newline", false):
		_line_fast = false
		if _needs_new_page():
			_start_pause()
		elif r.get("wrapped", false):
			# zidonghuanhang 换行后在同一次处理里画出这个字
			_state.step()
		# 优化 O-005：原版自动换行刚好越过第 4 行时，这个字画在页外随翻页丢失；这里留到下一页再画
	elif r.get("newpage", false):
		if not _state.at_end() and _state.text[_state.index] == "\n":
			_state.index += 1
		_state.y = win.size.y
		_start_pause()
	elif r.has("wait"):
		_wait = int(r.wait)
	elif r.get("pause", false):
		_start_pause()
	elif r.has("fast"):
		_line_fast = bool(r.fast)
	elif r.get("pause_skip", false):
		_pause_skip = true


func _start_pause() -> void:
	_wait = 10
	win.pause = true


func _on_end_of_text() -> void:
	_state = null
	if not _start_input():
		if not _pause_skip:
			_start_pause()
		else:
			_terminate(0)


func _start_input() -> bool:
	if _msg.has("choices") and not (_msg.choices as Array).is_empty():
		_start_choice()
		return true
	if _msg.has("digits"):
		_start_number()
		return true
	if _msg.get("lines", []).is_empty():
		_terminate(0)
	return false


## terminateMessage：消息窗开始关闭（下一条同设置的对话会接着用）；名字框 4 帧后关闭
func _terminate(result: int) -> void:
	win.pause = false
	win.close()
	_name_active = false
	_input_mode = ""
	_state = null
	_busy = false
	_finished.emit(result)


# ---- 选项窗 ----
func _start_choice() -> void:
	_input_mode = "choice"
	_choices = _msg.choices
	var n := _choices.size()
	var cancel := int(_msg.get("cancel", -1))
	_cancel_type = -2 if cancel >= n else cancel
	_choice_rows = mini(n, CHOICE_MAX_ROWS)
	if _msg_y < SCREEN.y / 2.0 and _msg_y + MSG_HEIGHT > SCREEN.y / 2.0:
		_choice_rows = mini(n, 4)
	_choice_rows = maxi(1, _choice_rows)
	var max_w := 96.0
	_choice_glyphs = []
	for c in _choices:
		var t := XMVText.new(XMVText.convert_escapes(str(c)), 6)
		max_w = maxf(max_w, t.run() + 12)
		_choice_glyphs.append(t.glyphs)
	var w := minf(max_w + XMVWindow.PADDING * 2, SCREEN.x)
	var h := _choice_rows * LH + XMVWindow.PADDING * 2
	var x := 0.0
	match int(_msg.get("choice_position", 2)):
		0:
			x = 0
		1:
			x = (SCREEN.x - w) / 2.0
		_:
			x = SCREEN.x - w
	var y := _msg_y - h if _msg_y >= SCREEN.y / 2.0 else _msg_y + MSG_HEIGHT
	match int(_msg.get("position", 2)):
		0:
			y = MSG_HEIGHT
		2:
			y = SCREEN.y - MSG_HEIGHT - h
	choice_win.set_rect(Rect2(x, y, w, h))
	choice_win.background_type = int(_msg.get("choice_background", 0))
	_choice_top = 0
	_select(int(_msg.get("default", 0)))
	choice_win.canvas.blink = true
	choice_win.open()
	_touching = false


func _select(i: int) -> void:
	_choice_index = i
	if i >= 0:
		if i < _choice_top:
			_choice_top = i
		elif i >= _choice_top + _choice_rows:
			_choice_top = i - _choice_rows + 1
	_refresh_choice()


func _refresh_choice() -> void:
	choice_win.up_arrow = _choice_top > 0
	choice_win.down_arrow = _choice_top < _choices.size() - _choice_rows
	choice_win.refresh()


func _update_choice() -> void:
	if not choice_win.is_open():
		return
	var last := _choice_index
	var n := _choices.size()
	if _in.get("down", false):
		if _choice_index < n - 1 or _in.get("down_trig", false):
			_select((_choice_index + 1) % n)
	elif _in.get("up", false):
		if _choice_index >= 1 or _in.get("up_trig", false):
			_select((_choice_index - 1 + n) % n)
	elif _in.get("pagedown", false):
		_choice_top = clampi(_choice_top + _choice_rows, 0, maxi(0, n - _choice_rows))
		_select(mini(_choice_index + _choice_rows, n - 1))
	elif _in.get("pageup", false):
		_choice_top = clampi(_choice_top - _choice_rows, 0, maxi(0, n - _choice_rows))
		_select(maxi(_choice_index - _choice_rows, 0))
	if _in.has("wheel"):
		_choice_top = clampi(_choice_top + int(_in.wheel), 0, maxi(0, n - _choice_rows))
		_refresh_choice()
	var ok := false
	if _in.has("touch"):
		var hit := _choice_hit(_in.touch)
		if hit >= 0:
			if hit == _choice_index and _in.get("touch_trig", false):
				ok = true
			else:
				_select(hit)
		if _in.get("touch_trig", false) and Rect2(choice_win.position, choice_win.size).has_point(_in.touch):
			_touching = true
	if _choice_index != last and not ok:
		XSound.system(0)
	if ok or _in.get("ok_trig", false):
		_consume()
		if _choice_index >= 0:
			XSound.system(1)
			_close_choice(_choice_index)
		else:
			XSound.system(3)
	elif _in.get("cancel", false) and _cancel_type != -1:
		_consume()
		XSound.system(2)
		_close_choice(_cancel_type)


func _choice_hit(p: Vector2) -> int:
	var local := p - choice_win.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
	var cw := choice_win.size.x - XMVWindow.PADDING * 2
	if local.x < 0 or local.x >= cw or local.y < 0 or local.y >= _choice_rows * LH:
		return -1
	var i := _choice_top + floori(local.y / LH)
	return i if i < _choices.size() else -1


func _close_choice(result: int) -> void:
	choice_win.canvas.blink = false
	choice_win.close()
	_terminate(result)


# ---- 数值输入 ----
func _start_number() -> void:
	_input_mode = "number"
	_digits = clampi(int(_msg.get("digits", 1)), 1, 8)
	_number = clampi(int(_msg.get("number_value", 0)), 0, int(pow(10, _digits)) - 1)
	var w := _digits * DIGIT_W + XMVWindow.PADDING * 2
	var h := LH + XMVWindow.PADDING * 2
	var y := _msg_y - h - 8 if _msg_y >= SCREEN.y / 2.0 else _msg_y + MSG_HEIGHT + 8
	match int(_msg.get("position", 2)):
		0:
			y = MSG_HEIGHT
		1:
			y = _msg_y - h if _msg_y >= SCREEN.y / 2.0 else _msg_y + MSG_HEIGHT
		2:
			y = SCREEN.y - MSG_HEIGHT - h
	num_win.set_rect(Rect2((SCREEN.x - w) / 2.0, y, w, h))
	num_win.background_type = 0
	_digit_index = 0
	_buttons_visible = _last_touch
	_button_down = -1
	_place_buttons()
	num_win.canvas.blink = true
	num_win.open()
	num_win.refresh()


## ButtonSet.png：下 (48,0,48,48)、上 (96,0,48,48)、确定 (192,0,96,48)；按下时用 y 48 那一排
const BUTTONS := [Rect2(48, 0, 48, 48), Rect2(96, 0, 48, 48), Rect2(192, 0, 96, 48)]

func _button_rects() -> Array:
	var total := -16.0
	for b in BUTTONS:
		total += b.size.x + 16
	var x := (num_win.size.x - total) / 2.0
	var y := -48.0 - 8.0 if _msg_y >= SCREEN.y / 2.0 else num_win.size.y + 8.0
	var out := []
	for b in BUTTONS:
		out.append(Rect2(x, y, b.size.x, 48))
		x += b.size.x + 16
	return out


func _place_buttons() -> void:
	_num_buttons.position = Vector2.ZERO
	_num_buttons.size = num_win.size
	_num_buttons.queue_redraw()


func _draw_buttons() -> void:
	if not _buttons_visible or not num_win.is_open():
		return
	var tex: Texture2D = _button_texture()
	if tex == null:
		return
	var rects := _button_rects()
	for i in range(3):
		var src: Rect2 = BUTTONS[i]
		if i == _button_down:
			src.position.y += 48
		_num_buttons.draw_texture_rect_region(tex, rects[i], src)


static var _button_tex: Texture2D

static func _button_texture() -> Texture2D:
	if _button_tex == null:
		var p := XDB.img_path("system", "ButtonSet")
		_button_tex = load(p) if p != "" else null
	return _button_tex


func _change_digit(up: bool) -> void:
	var place := int(pow(10, _digits - 1 - _digit_index))
	var n := floori(_number / float(place)) % 10
	_number -= n * place
	n = (n + 1) % 10 if up else (n + 9) % 10
	_number += n * place
	num_win.refresh()
	XSound.system(0)


func _update_number() -> void:
	if not num_win.is_open():
		return
	_num_buttons.queue_redraw()
	var last := _digit_index
	# Window_Selectable.cursorRight/Left：横排，按下（非连发）时首尾相接
	if _in.get("right", false) and _digits >= 2 and (_digit_index < _digits - 1 or _in.get("right_trig", false)):
		_digit_index = (_digit_index + 1) % _digits
	elif _in.get("left", false) and _digits >= 2 and (_digit_index > 0 or _in.get("left_trig", false)):
		_digit_index = (_digit_index - 1 + _digits) % _digits
	if _in.get("up", false):
		_change_digit(true)
	elif _in.get("down", false):
		_change_digit(false)
	if _in.has("touch"):
		var p: Vector2 = _in.touch
		if _buttons_visible:
			var rects := _button_rects()
			for i in range(3):
				if Rect2(num_win.position + rects[i].position, rects[i].size).has_point(p):
					if _in.get("touch_trig", false):
						_button_down = i
		var local := p - num_win.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
		if _in.get("touch_trig", false) and local.y >= 0 and local.y < LH and local.x >= 0 and local.x < _digits * DIGIT_W:
			_digit_index = floori(local.x / DIGIT_W)
	if _in.get("touch_release", false) and _button_down >= 0:
		var b := _button_down
		_button_down = -1
		var rects := _button_rects()
		var r: Rect2 = rects[b]
		if Rect2(num_win.position + r.position, r.size).has_point(_in.touch_release_pos):
			match b:
				0:
					_change_digit(false)
				1:
					_change_digit(true)
				2:
					_number_ok()
					return
	if _digit_index != last:
		XSound.system(0)
		num_win.refresh()
	if _in.get("ok_trig", false):
		_consume()
		_number_ok()


func _number_ok() -> void:
	XSound.system(1)
	_buttons_visible = false
	num_win.canvas.blink = false
	num_win.close()
	_terminate(_number)


# ---- 绘制 ----
func _paint_message(c: XMVCanvas) -> void:
	if _face != "":
		c.face(_face, _face_index, 0, 0)
	XMVText.paint(c, _page_glyphs)


func _paint_name(c: XMVCanvas) -> void:
	XMVText.paint(c, _name_glyphs)


func _paint_choices(c: XMVCanvas) -> void:
	for i in range(_choices.size()):
		var y := (i - _choice_top) * LH
		if y < 0 or y >= _choice_rows * LH:
			continue
		if i == _choice_index:
			c.cursor(Rect2(0, y, c.size.x, LH), _input_mode == "choice")
		XMVText.paint(c, _choice_glyphs[i], 0, y)


func _paint_number(c: XMVCanvas) -> void:
	c.cursor(Rect2(_digit_index * DIGIT_W, 0, DIGIT_W, LH), _input_mode == "number")
	var s := str(_number).pad_zeros(_digits)
	for i in range(_digits):
		c.text(s[i], i * DIGIT_W, 0, DIGIT_W, "center")


# ---- 输入（MV Input：确定/取消/方向，鼠标左键即触摸，右键取消，滚轮） ----
func _unhandled_input(event: InputEvent) -> void:
	if not _busy:
		return
	var handled := true
	if event.is_action_pressed("ui_accept", true):
		_in.ok = true
		if not event.is_echo():
			_in.ok_trig = true
		_last_touch = false
	elif event.is_action_pressed("ui_cancel", true):
		_in.cancel = true
		_last_touch = false
	elif event.is_action_pressed("ui_down", true):
		_in.down = true
		_in.down_trig = not event.is_echo()
		_last_touch = false
	elif event.is_action_pressed("ui_up", true):
		_in.up = true
		_in.up_trig = not event.is_echo()
		_last_touch = false
	elif event.is_action_pressed("ui_left", true):
		_in.left = true
		_in.left_trig = not event.is_echo()
		_last_touch = false
	elif event.is_action_pressed("ui_right", true):
		_in.right = true
		_in.right_trig = not event.is_echo()
		_last_touch = false
	elif event.is_action_pressed("ui_page_down"):
		_in.pagedown = true
	elif event.is_action_pressed("ui_page_up"):
		_in.pageup = true
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_in.touch = mb.position
			_in.touch_trig = true
			_in.ok = true
			_last_touch = true
		elif not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_touching = false
			_in.touch_release = true
			_in.touch_release_pos = mb.position
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			# TouchInput.isCancelled：只对选项窗（Window_Selectable）有效，消息翻页不认右键
			if _input_mode == "choice":
				_in.cancel = true
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_in.wheel = int(_in.get("wheel", 0)) + 1
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_in.wheel = int(_in.get("wheel", 0)) - 1
		else:
			handled = false
	elif event is InputEventMouseMotion and _touching and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_in.touch = (event as InputEventMouseMotion).position
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


## Window_Message.isTriggered：确定/取消（含连发）或点击
func _triggered() -> bool:
	return _in.get("ok", false) or _in.get("cancel", false)


func _fast_forward() -> bool:
	return Input.is_action_pressed("ui_page_down")


func _consume() -> void:
	_consumed_frame = Engine.get_process_frames()
