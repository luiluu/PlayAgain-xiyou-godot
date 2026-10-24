class_name XActorWarehouseScene
extends Control
## 角色仓库（Star_ActorWarehouse 的 Star_Scene_ActorWarehouse；方桌大厅仓库管理员 Map4 EV8「角色仓库」）。存取规则在 XActorWarehouse。
## 版面按冻结 v0.28 浏览器参照（tests/fixtures/actor_warehouse_oracle.json，ui_reference/review_system_pages.js 的 actor_warehouse）：
## - 说明窗被 Sprite_ItemHelp 顶替（高 1、不显示），所以下面几个窗口都从 y≈1 起算：
##   标题 (0,6,1280,64)「角色仓库」#FFFF00，x = 640 − 字宽×3/4、宽为内容宽一半；
##   指令 (0,81,1280,64)「存入／取出」两列居中（格宽 620）；名单 (0,145,1280,575) 行高 36、可见 15 行。
## - 名单一行同整队名单（XPartyScene.paint_actor_row）：行走图上半、名字（出战成员 textColor 6，停用角色名字半透明）、Lv、HP/MP/TP。
##   名单跟着指令窗当前项显示（存入＝队伍、取出＝仓库），开场选第 1 行但不活动，光标照画。
## - 操作：指令确定 → 名单选第 1 行；名单确定（确定音）即存入／取出，光标不动（存掉最后一行后停在空行）、名单不退；
##   停用角色蜂鸣；只剩 1 人时存入提示「队伍最少保留一位角色」（原版 alert）；空行确定蜂鸣（O-091）。
##   名单取消 → 去掉光标、回指令窗；指令窗取消关闭。

signal closed

const TITLE_RECT := Rect2(0, 6, 1280, 64)
const CMD_RECT := Rect2(0, 81, 1280, 64)
const LIST_RECT := Rect2(0, 145, 1280, 575)
const LH := 36.0
const CMD_W := 620.0
const TITLE := "角色仓库"
const TITLE_COLOR := Color("#ffff00")
const COMMANDS := ["存入", "取出"]

var mode := "command"        # command / list
var cmd := 0
var index := 0               # Star_Window_PartyList.initialize 的 select(0)
var top := 0
var data: Array[int] = []
var title_win: XMVWindow
var cmd_win: XMVWindow
var list_win: XMVWindow


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(XAchievementPopup.MBACK_GROUP)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var op := XUI.MENU_WINDOW_OPACITY
	title_win = XMVWindow.make(self, TITLE_RECT, op, _paint_title)
	cmd_win = XMVWindow.make(self, CMD_RECT, op, _paint_cmd)
	list_win = XMVWindow.make(self, LIST_RECT, op, _paint_list)
	for w in [cmd_win, list_win]:
		w.canvas.blink = true
	_reload()


func rows() -> int:
	return floori((LIST_RECT.size.y - XMVWindow.PADDING * 2) / LH)


func deposit_mode() -> bool:
	return cmd == 0


func _reload() -> void:
	data = XActorWarehouse.list(XState.current, deposit_mode())
	_refresh()


func _refresh() -> void:
	list_win.up_arrow = top > 0
	list_win.down_arrow = top + rows() < data.size()
	for w in [title_win, cmd_win, list_win]:
		w.refresh()


# ---- 绘制 ----
func _paint_title(c: XMVCanvas) -> void:
	c.text(TITLE, c.size.x / 2.0 + XMVWindow.PADDING - c.text_width(TITLE) * 0.75, 0, c.size.x / 2.0, "left", TITLE_COLOR)


func _paint_cmd(c: XMVCanvas) -> void:
	c.cursor(Rect2(cmd * (CMD_W + 12), 0, CMD_W, LH), mode == "command")
	for i in COMMANDS.size():
		c.text(COMMANDS[i], i * (CMD_W + 12) + 6, 0, CMD_W - 12, "center")


func _paint_list(c: XMVCanvas) -> void:
	if index >= top and index < top + rows():
		c.cursor(Rect2(0, (index - top) * LH, c.size.x, LH), mode == "list")
	var s := XState.current
	var battle := s.battle_members()
	for i in range(top, mini(top + rows(), data.size())):
		var a := s.actor(data[i])
		XPartyScene.paint_actor_row(c, a, (i - top) * LH, battle.has(a), XActorWarehouse.enabled(data[i]))


# ---- 操作 ----
func ok() -> void:
	match mode:
		"command":
			XSound.system(1)
			mode = "list"
			_select(0)
		"list":
			# Window_Selectable.processOk：不可确定（停用角色）蜂鸣；空行原版可确定（O-091 改为蜂鸣）
			var id := data[index] if index >= 0 and index < data.size() else 0
			if id != 0 and not XActorWarehouse.enabled(id):
				XSound.system(3)
				return
			var s := XState.current
			var r := XActorWarehouse.deposit(s, index) if deposit_mode() else XActorWarehouse.withdraw(s, index)
			match r:
				"empty":
					XSound.system(3)
					return
				"last":
					XSound.system(1)
					XToast.show_text(XActorWarehouse.LAST_ACTOR_TEXT, true)
				_:
					XSound.system(1)
			_reload()


func cancel() -> void:
	XSound.system(2)
	match mode:
		"list":
			mode = "command"
			index = -1
			_refresh()
		"command":
			closed.emit()


func _select(i: int) -> void:
	index = i
	top = XMenu._scroll_to(i, top, rows())
	_refresh()


## 指令窗是横排两格：左右移动（首按首尾循环）；切换时名单跟着刷新、回到顶端（setCategory → refresh＋resetScroll），光标不动
func _move_cmd(d: int, wrap: bool) -> void:
	var i := XMenu._move(cmd, d, COMMANDS.size(), wrap)
	if i == cmd:
		return
	cmd = i
	XSound.system(0)
	top = 0
	_reload()


func _move_list(d: int, wrap: bool) -> void:
	if data.is_empty():
		return
	var i := XMenu._move(index, d, data.size(), wrap)
	if i != index:
		XSound.system(0)
		_select(i)


func page(d: int) -> void:
	if mode != "list" or data.is_empty():
		return
	var before := index
	if (d < 0 and top > 0) or (d > 0 and top + rows() < data.size()):
		top = clampi(top + d * rows(), 0, maxi(0, data.size() - rows()))
		index = clampi(index + d * rows(), 0, data.size() - 1)
		top = XMenu._scroll_to(index, top, rows())
	if index != before:
		XSound.system(0)
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var p: Vector2 = event.position
	var pad := XMVWindow.PADDING
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			if mode == "list" and LIST_RECT.has_point(p):
				top = clampi(top + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, data.size() - rows()))
				_refresh()
		MOUSE_BUTTON_LEFT:
			if mode == "command" and CMD_RECT.grow(-pad).has_point(p):
				var i := clampi(floori((p.x - pad) / (CMD_W + 12)), 0, 1)
				if i == cmd:
					ok()
				else:
					_move_cmd(i - cmd, false)
			elif mode == "list" and LIST_RECT.grow(-pad).has_point(p):
				var i := top + floori((p.y - LIST_RECT.position.y - pad) / LH)
				if i >= 0 and i < data.size():
					if i == index:
						ok()
					else:
						XSound.system(0)
						_select(i)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		if mode == "list":
			_move_list(1 if event.is_action_pressed("ui_down", true) else -1, not event.is_echo())
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_left", true):
		get_viewport().set_input_as_handled()
		if mode == "command":
			_move_cmd(1 if event.is_action_pressed("ui_right", true) else -1, not event.is_echo())
	elif event.is_action_pressed("ui_page_up", true) or event.is_action_pressed("ui_page_down", true):
		get_viewport().set_input_as_handled()
		page(-1 if event.is_action_pressed("ui_page_up", true) else 1)
