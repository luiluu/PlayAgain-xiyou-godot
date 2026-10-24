class_name XPartyScene
extends Control
## 主菜单「整队」：YEP_PartySystem 的 Scene_Party，按正式 v0.22 运行时复现（参照 原版参照/claude_party_01_open～04_swapped）。
## - 背景同主菜单，三个窗口不透明度 30：指令 (0,0,240,172)「整队/离队/还原/完成」居中、可见 4 行；
##   出战栏 (240,0,1040,172) 5 格（内容宽/5），每格内缩 3：头像（MV drawFace 居中、上下各裁 3）、名字（左上，hpColor）、
##   行走图（格中线、底边在内容高×19/20）；空位填 gaugeBackColor 半透明并居中写「- 空 -」；
##   名单 (0,172,1280,548) 行高 36：首尾两行「离队」（图标 976＋文字，x 36），中间是队伍全体（出战成员在前、其余按编号）：
##   行走图上半 32 像素（底边在行底＋16，被下一行盖住）、名字 x 36（出战成员 textColor 6），
##   内容宽六等分：Lv 在第 2 份、HP/MP/TP 在第 3/4/5 份（宽一份−6，只写当前值）。名单开局选第 1 行但不活动。
## - 操作：指令「整队」「离队」→ 出战栏选第 0 格；整队时在出战栏确定 → 名单选人，名单确定播装备音：
##   选「离队」行把该格清空，选角色放进该格（已在别格的两格互换）；离队时在出战栏确定直接清空该格（装备音）。
##   出战栏 Q/E（上一页/下一页）与相邻格互换（光标音＋装备音）。取消逐层返回；「还原」恢复进页时的出战栏；
##   「完成」或在指令窗取消返回主菜单（完成在出战栏全空/全员阵亡时灰显，确定蜂鸣）。

signal closed

const CMD_RECT := Rect2(0, 0, 240, 172)
const SLOT_RECT := Rect2(240, 0, 1040, 172)
const LIST_RECT := Rect2(0, 172, 1280, 548)
const LH := 36.0
const COMMANDS := [["整队", "change"], ["离队", "remove"], ["还原", "revert"], ["完成", "cancel"]]
const REMOVE_ICON := 976
const IN_PARTY_COLOR := 6
const EMPTY_TEXT := "- 空 -"
const TEXT_PADDING := 6.0

var cmd_win: XMVWindow
var slot_win: XMVWindow
var list_win: XMVWindow
var mode := "command"          # command / slot / list
var cmd_index := 0
var slot_index := -1
var list_index := 1
var list_top := 0
var _former: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	XState.current._ensure_slots()
	_former = XState.current.battle_slots.duplicate()
	cmd_win = XMVWindow.make(self, CMD_RECT, XUI.MENU_WINDOW_OPACITY, _paint_cmd)
	slot_win = XMVWindow.make(self, SLOT_RECT, XUI.MENU_WINDOW_OPACITY, _paint_slots)
	list_win = XMVWindow.make(self, LIST_RECT, XUI.MENU_WINDOW_OPACITY, _paint_list)
	for w in [cmd_win, slot_win, list_win]:
		w.canvas.blink = true
	_refresh()


## Window_PartyList._data：0（离队）＋队伍全体＋0
func list_data() -> Array:
	return [0] + Array(XState.current.party) + [0]


func slots() -> Array:
	return XState.current.battle_slots


func _rows() -> int:
	return floori((LIST_RECT.size.y - XMVWindow.PADDING * 2) / LH)


func _refresh() -> void:
	list_win.up_arrow = list_top > 0
	list_win.down_arrow = list_top + _rows() < list_data().size()
	for w in [cmd_win, slot_win, list_win]:
		w.refresh()


## isCancelEnabled：出战栏有人且有活着的队员
func finish_enabled() -> bool:
	var s := XState.current
	return not s.battle_members().is_empty() and s.members().any(func(a): return a.is_alive())


# ---- 绘制 ----
func _paint_cmd(c: XMVCanvas) -> void:
	for i in COMMANDS.size():
		var y := i * LH
		if i == cmd_index:
			c.cursor(Rect2(0, y, c.size.x, LH), mode == "command")
		var enabled: bool = COMMANDS[i][1] != "cancel" or finish_enabled()
		c.text(COMMANDS[i][0], TEXT_PADDING, y, c.size.x - TEXT_PADDING * 2, "center", XUI.TEXT, XUI.FONT_SIZE, LH, 1.0 if enabled else XUI.DIM.a)


func _slot_rect(c: XMVCanvas, i: int) -> Rect2:
	var w := c.size.x / slots().size()
	return Rect2(i * w, 0, w, c.size.y)


func _paint_slots(c: XMVCanvas) -> void:
	for i in slots().size():
		var r := _slot_rect(c, i)
		if i == slot_index:
			c.cursor(r, mode == "slot")
		var inner := Rect2(r.position + Vector2(TEXT_PADDING / 2, TEXT_PADDING / 2), r.size - Vector2(TEXT_PADDING, TEXT_PADDING))
		var id := int(slots()[i])
		if id <= 0:
			c.draw_rect(inner, Color(XUI.GAUGE_BACK, XUI.DIM.a))
			c.text(EMPTY_TEXT, inner.position.x, inner.position.y, inner.size.x, "center", XUI.TEXT, XUI.FONT_SIZE, inner.size.y)
			continue
		var a := XState.current.actor(id)
		c.face(str(a.data().faceName), int(a.data().faceIndex), inner.position.x, inner.position.y, inner.size.x, inner.size.y)
		c.character(str(a.data().characterName), int(a.data().characterIndex), inner.position.x + inner.size.x / 2.0, inner.size.y * 19.0 / 20.0)
		c.text(a.display_name(), inner.position.x, inner.position.y, inner.size.x, "left", XMenu._hp_color(a))


func _paint_list(c: XMVCanvas) -> void:
	var data := list_data()
	var battle := XState.current.battle_members()
	for i in range(list_top, mini(list_top + _rows(), data.size())):
		var y := (i - list_top) * LH
		if i == list_index:
			c.cursor(Rect2(0, y, c.size.x, LH), mode == "list")
		var id := int(data[i])
		if id <= 0:
			c.icon(REMOVE_ICON, 2, y + 2)
			c.text("离队", 36, y, c.size.x - TEXT_PADDING - 36)
			continue
		var a := XState.current.actor(id)
		paint_actor_row(c, a, y, battle.has(a))


## Window_PartyList.drawBasic／drawExtra 的一行（角色仓库 XActorWarehouseScene 共用）：行走图上半、名字（出战成员 textColor 6；
## 不可用时只有名字半透明，同 changePaintOpacity 只包住 drawText）、Lv、HP/MP/TP
static func paint_actor_row(c: XMVCanvas, a: XActor, y: float, in_battle: bool, enabled := true) -> void:
	var section := c.size.x / 6.0
	c.character(str(a.data().characterName), int(a.data().characterIndex), 32.0 / 2.0 + TEXT_PADDING / 2.0, y + LH + 16.0, LH - 4.0)
	c.text(a.display_name(), 36, y, c.size.x - 36, "left", XUI.text_color(IN_PARTY_COLOR) if in_battle else XUI.TEXT, XUI.FONT_SIZE, LH, 1.0 if enabled else XUI.DIM.a)
	var lv_w := c.text_width("Lv")
	c.text("Lv", section * 2, y, lv_w, "left", XUI.SYSTEM)
	c.text(XMenu._group(a.level), section * 2 + lv_w, y, c.text_width(XMenu._group(a.max_level())), "right")
	_value(c, "HP", a.hp, a.mhp, section * 3, y, section - 6, "hp", XMenu._hp_color(a))
	_value(c, "MP", a.mp, a.mmp, section * 4, y, section - 6, "mp", XUI.TEXT)
	var tp: Array = XUI.GAUGES.tp
	c.gauge(section * 5, y, section - 6, a.tp / a.max_tp(), tp[0], tp[1])
	c.text("TP", section * 5, y, 44, "left", XUI.SYSTEM)
	c.text(str(int(a.tp)), section * 5 + section - 6 - 64, y, 64, "right")


## Window_PartyList.drawCurrentAndMax：只写当前值，右对齐在最大值宽度内
static func _value(c: XMVCanvas, label: String, cur: float, mx: float, x: float, y: float, w: float, kind: String, color: Color) -> void:
	var cols: Array = XUI.GAUGES[kind]
	c.gauge(x, y, w, cur / maxf(mx, 1.0), cols[0], cols[1])
	c.text(label, x, y, 44, "left", XUI.SYSTEM)
	var vw := c.text_width(XMenu._group(mx))
	c.text(XMenu._group(cur), x + w - vw, y, vw, "right", color)


# ---- 操作 ----
func ok() -> void:
	match mode:
		"command":
			var sym: String = COMMANDS[cmd_index][1]
			if sym == "cancel" and not finish_enabled():
				XSound.system(3)
				return
			XSound.system(1)
			match sym:
				"change", "remove":
					mode = "slot"
					slot_index = 0
				"revert":
					XState.current.battle_slots = _former.duplicate()
					XState.current.rearrange_actors()
				"cancel":
					closed.emit()
					return
		"slot":
			XSound.system(1)
			if COMMANDS[cmd_index][1] == "change":
				mode = "list"
			else:
				XSound.system(4)
				XState.current.battle_slots[slot_index] = 0
				XState.current.rearrange_actors()
		"list":
			XSound.system(1)
			XSound.system(4)
			var id := int(list_data()[list_index])
			var s := XState.current
			if id <= 0:
				s.battle_slots[slot_index] = 0
			else:
				var at := s.battle_slots.find(id)
				if at >= 0:
					s.battle_slots[at] = s.battle_slots[slot_index]
				s.battle_slots[slot_index] = id
			s.rearrange_actors()
			mode = "slot"
	_refresh()


func cancel() -> void:
	# Window_PartyMenuCommand.isCancelEnabled 同时限制取消键与鼠标右键；不能退出时不发取消音。
	if mode == "command" and not finish_enabled():
		return
	XSound.system(2)
	match mode:
		"command":
			closed.emit()
			return
		"slot":
			mode = "command"
			slot_index = -1
		"list":
			mode = "slot"
	_refresh()


## Scene_Party.onPartyPageUp/PageDown：与相邻格互换（首尾循环）
func page(d: int) -> void:
	if mode == "list":
		var before := list_index
		if (d < 0 and list_top > 0) or (d > 0 and list_top + _rows() < list_data().size()):
			list_top = clampi(list_top + d * _rows(), 0, maxi(0, list_data().size() - _rows()))
			list_index = clampi(list_index + d * _rows(), 0, list_data().size() - 1)
			list_top = XMenu._scroll_to(list_index, list_top, _rows())
		if list_index != before:
			XSound.system(0)
		_refresh()
		return
	if mode != "slot":
		return
	XSound.system(0)
	XSound.system(4)
	var n := slots().size()
	var other := (slot_index + d + n) % n
	var s := XState.current
	var a = s.battle_slots[slot_index]
	s.battle_slots[slot_index] = s.battle_slots[other]
	s.battle_slots[other] = a
	s.rearrange_actors()
	slot_index = other
	_refresh()


func _move(d: int, wrap: bool) -> void:
	var before := [cmd_index, slot_index, list_index]
	match mode:
		"command":
			cmd_index = XMenu._move(cmd_index, d, COMMANDS.size(), wrap)
		"slot":
			slot_index = XMenu._move(slot_index, d, slots().size(), wrap)
		"list":
			list_index = XMenu._move(list_index, d, list_data().size(), wrap)
			list_top = XMenu._scroll_to(list_index, list_top, _rows())
	if before != [cmd_index, slot_index, list_index]:
		XSound.system(0)
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			if mode == "list" and LIST_RECT.has_point(event.position):
				var d := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
				list_top = clampi(list_top + d, 0, maxi(0, list_data().size() - _rows()))
				_refresh()
		MOUSE_BUTTON_LEFT:
			_click(event.position)


## Window_Selectable.processTouch：只认活动窗口，点当前项＝确定，点别的项＝选中
func _click(p: Vector2) -> void:
	var pad := Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
	match mode:
		"command":
			if CMD_RECT.grow(-XMVWindow.PADDING).has_point(p):
				var i := floori((p - CMD_RECT.position - pad).y / LH)
				_pick(i, COMMANDS.size(), "cmd_index")
		"slot":
			if SLOT_RECT.grow(-XMVWindow.PADDING).has_point(p):
				var w := (SLOT_RECT.size.x - XMVWindow.PADDING * 2) / slots().size()
				var i := floori((p - SLOT_RECT.position - pad).x / w)
				_pick(i, slots().size(), "slot_index")
		"list":
			if LIST_RECT.grow(-XMVWindow.PADDING).has_point(p):
				var i := list_top + floori((p - LIST_RECT.position - pad).y / LH)
				_pick(i, list_data().size(), "list_index")


func _pick(i: int, n: int, field: String) -> void:
	if i < 0 or i >= n:
		return
	if i == int(get(field)):
		ok()
	else:
		set(field, i)
		XSound.system(0)
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var pressed := key != null and key.pressed
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true) or (pressed and key.physical_keycode in [KEY_W, KEY_S]):
		# 出战栏是一行 5 列：上下不动（Window_Selectable.cursorDown/Up 需要多行）
		get_viewport().set_input_as_handled()
		if mode != "slot":
			_move(1 if event.is_action_pressed("ui_down", true) or (pressed and key.physical_keycode == KEY_S) else -1, not event.is_echo())
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_left", true) or (pressed and key.physical_keycode in [KEY_A, KEY_D]):
		# 只有出战栏横向移动（isHorizontal 时首按可首尾循环）；指令窗与名单单列不动
		get_viewport().set_input_as_handled()
		if mode == "slot":
			_move(1 if event.is_action_pressed("ui_right", true) or (pressed and key.physical_keycode == KEY_D) else -1, not event.is_echo())
	elif event.is_action_pressed("ui_page_up", true) or event.is_action_pressed("ui_page_down", true) or (pressed and key.physical_keycode in [KEY_Q, KEY_E]):
		get_viewport().set_input_as_handled()
		page(-1 if event.is_action_pressed("ui_page_up", true) or (pressed and key.physical_keycode == KEY_Q) else 1)
