class_name XEquipScene
extends Control
## 装备页（Scene_Equip：YEP_EquipCore＋YEP_ItemCore 信息窗＋installCombatPowerRuntime 状态＋HelpExtend＋Codex 装备排序），
## 按正式版运行时复现（参照截图 04_验证/本地结果/原版参照/75～78，v0.10；绘制记录见 界面风格.md）。没有顶部说明栏：
## - 指令 (0,1,240,172)：装备／清空／返回，左对齐，可见 4 行（正式版没有「最强装备」）。
## - 状态 (240,1,1040,172)：Window_SkillStatus＝头像 (0,0) 144；名字/Lv/状态图标/「战力」在 x 158、宽 144；
##   称号与 HP/MP/TP 在 x 314、宽 686；行高 36（XMenu.paint_actor_status）。
## - 槽位 (0,173,640,547)：槽位名系统色，列宽 = 最长槽位名＋空格（setSlotNameWidth）；图标在其后 +2、名字 +36（品质色）；
##   空槽画图标 0 半透明；不能换的槽整行半透明。可见 14 行，19 个槽要滚动。
## - 候选（Window_EquipItem，选槽后盖在槽位窗上）：背包里能装进该槽的装备（XItemRow，「序号/9,999」，Codex 品质排序）
##   ＋末行「卸载」（图标 1354，x 36、宽 570）。
## - 右下 (640,173,640,547)：物品信息窗（XItemScene.paint_info）与属性对比（Window_StatCompare）轮换，默认信息窗；
##   →／Tab／点击右下区域换下一个，← 换上一个（各响光标音，任何阶段都可以换）。
## - 属性对比：8 行暗格 (1,y+1,610,34)；能力名前 4 字（系统色）、当前值、「→」（系统色）；选候选时另画新值（增绿减红）。
## - 信息窗与对比的对象：指令阶段为空／只有当前值；槽位阶段为该槽装备／只有当前值；候选阶段为该候选／当前值→装上后的值。
## - 说明卡（XHelpCard）：指令阶段隐藏，槽位/候选跟着选中行。
## - 换角色只在指令阶段：Q/W、PageUp/PageDown（光标音），回到指令窗。装上/清空后 HP、MP 按原比例保留（YEP）。
## 优化 O-009：属性对比的当前值/箭头/新值三列整体左移 45，新值不再超出窗口被截掉（COMPARE_SHIFT = 0 恢复原版）。
## 暂未做：「战力」估算（写「战力 …」，即正式版还没算出时的写法）；同品质装备按中文拼音排序（现按字码）。

signal closed

const CMD_RECT := Rect2(0, 1, 240, 172)
const STATUS_RECT := Rect2(240, 1, 1040, 172)
const LIST_RECT := Rect2(0, 173, 640, 547)
const LOWER_RECT := Rect2(640, 173, 640, 547)
const LH := 36.0
const CMD_ROWS := 4
## Window_StatCompare（正式版改过的 drawItem：名字 +20、当前值与箭头 +60、新值 +45；差值列宽为 0 不显示）。
## 宽度为正式版运行时读数：能力名列 137.21（「最大生命值 」）、数值列 139.75（能力上限的千位格式）、箭头列 33.21（「→ 」）。
const COMPARE_NAME_X := 26.0
const COMPARE_NAME_W := 137.21
const COMPARE_VALUE_W := 139.75
const COMPARE_ARROW_W := 33.21
## 优化 O-009：三列左移 45（新值右端 = 内容宽 − 文字边距）；改为 0 即恢复原版（新值右端超出窗口 39，被截掉）
const COMPARE_SHIFT := 45.0
const POWER_TEXT := "战力 …"

var actor_index := 0
var _mode := "command"              # command / slot / item
var _cmd := 0
var _slot := 0
var _slot_top := 0
var _item_index := 0
var _item_top := 0
var _compare := false               # 右下当前显示属性对比（否则物品信息）
var _pending_seen: Dictionary = {}  # 候选里光标停着的新装备：光标离开或换窗口时才记为看过（Galv）
var cmd_win: XMVWindow
var status_win: XMVWindow
var list_win: XMVWindow
var lower_win: XMVWindow
var help_card: XHelpCard


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var op := XUI.MENU_WINDOW_OPACITY
	cmd_win = XMVWindow.make(self, CMD_RECT, op, _paint_cmd)
	status_win = XMVWindow.make(self, STATUS_RECT, op, _paint_status)
	list_win = XMVWindow.make(self, LIST_RECT, op, _paint_list)
	lower_win = XMVWindow.make(self, LOWER_RECT, op, _paint_lower)
	for w in [cmd_win, list_win]:
		w.canvas.blink = true
	help_card = XHelpCard.new()
	add_child(help_card)
	_refresh()


# ---- 数据 ----
func actor() -> XActor:
	var s := XState.current
	actor_index = posmod(actor_index, s.party.size())
	return s.actor(s.party[actor_index])


func commands() -> Array:
	var terms: Array = XDB.system().get("terms", {}).get("commands", [])
	return [
		{"text": str(terms[15]) if terms.size() > 15 else "装备", "symbol": "equip"},
		{"text": str(terms[17]) if terms.size() > 17 else "清空", "symbol": "clear"},
		{"text": str(XDB.plugin("YEP_EquipCore").get("Finish Command", "返回")), "symbol": "cancel"},
	]


func slot_name(i: int) -> String:
	return str(XDB.system().equipTypes[actor().equip_slots()[i]])


## setSlotNameWidth：各槽位名加一个空格的最大字宽
func slot_name_width(c: XMVCanvas) -> float:
	var w := 0.0
	for i in range(actor().equip_slots().size()):
		w = maxf(w, c.text_width(slot_name(i) + " "))
	return w


## Window_EquipItem.makeItemList：背包里能装进该槽的装备（Codex 默认排序）＋末行「卸载」（{}）
func candidates() -> Array:
	var a := actor()
	var etype := int(a.equip_slots()[_slot])
	var out := []
	for kind in ["weapon", "armor"]:
		var bag := XItemScene.bag_gear(kind)
		for i in range(bag.size()):
			if int(bag[i].get("etypeId", 0)) == etype and a.can_equip(bag[i]):
				out.append({"rec": bag[i], "carry": i + 1})
	out = XItemScene.sort_gear(out)
	out.append({"rec": {}})
	return out


func _candidate() -> Dictionary:
	var d := candidates()
	return d[_item_index].rec if _item_index >= 0 and _item_index < d.size() else {}


func _slot_item() -> Dictionary:
	var e = actor().equips[_slot] if _slot >= 0 and _slot < actor().equips.size() else null
	return e if e is Dictionary else {}


func _rows() -> int:
	return floori((LIST_RECT.size.y - XMVWindow.PADDING * 2) / LH)


## 右下两个窗口的对象：信息窗的物品，属性对比的「装上后」角色（null 表示只画当前值）
func _shown_item() -> Dictionary:
	match _mode:
		"slot":
			return _slot_item()
		"item":
			return _candidate()
	return {}


func _temp_actor() -> XActor:
	if _mode != "item":
		return null
	var e := _candidate()
	return XEquipment.preview(actor(), _slot, e if not e.is_empty() else null)


# ---- 刷新 ----
func _refresh() -> void:
	var n := candidates().size() if _mode == "item" else actor().equip_slots().size()
	var top := _item_top if _mode == "item" else _slot_top
	list_win.up_arrow = top > 0
	list_win.down_arrow = top < n - _rows()
	cmd_win.up_arrow = false
	cmd_win.down_arrow = commands().size() > CMD_ROWS
	for w in [cmd_win, status_win, list_win, lower_win]:
		w.refresh()
	_update_help()


func _update_help() -> void:
	var rec := {}
	var row := -1
	match _mode:
		"slot":
			rec = _slot_item()
			row = _slot - _slot_top
		"item":
			rec = _candidate()
			row = _item_index - _item_top
	if rec != _pending_seen:
		_commit_seen()
		if _mode == "item" and not rec.is_empty() and XState.current.is_new(rec):
			_pending_seen = rec
	help_card.show_for(rec if row >= 0 else {})
	if help_card.visible:
		help_card.place_for_row(Rect2(LIST_RECT.position + Vector2(0, XMVWindow.PADDING + row * LH), Vector2(LIST_RECT.size.x, LH)))


func _commit_seen() -> void:
	if not _pending_seen.is_empty():
		XState.current.mark_seen(_pending_seen)
	_pending_seen = {}


# ---- 绘制 ----
func _paint_cmd(c: XMVCanvas) -> void:
	var list := commands()
	for i in range(mini(list.size(), CMD_ROWS)):
		var y := i * LH
		if i == _cmd:
			c.cursor(Rect2(0, y, c.size.x, LH), _mode == "command")
		c.text(str(list[i].text), 6, y, c.size.x - 12, "left")


func _paint_status(c: XMVCanvas) -> void:
	var a := actor()
	c.face(str(a.data().get("faceName", "")), int(a.data().get("faceIndex", 0)), 0, 0, 144, c.size.y)
	XMenu.paint_actor_status(c, a, 158, 0, c.size.x - 158 - 6, LH, POWER_TEXT)


func _paint_list(c: XMVCanvas) -> void:
	if _mode == "item":
		var d := candidates()
		for i in range(_item_top, mini(d.size(), _item_top + _rows())):
			var y := (i - _item_top) * LH
			if i == _item_index:
				c.cursor(Rect2(0, y, c.size.x, LH))
			if d[i].rec.is_empty():
				_paint_remove(c, y)
			else:
				XItemRow.paint(c, d[i].rec, y, XItemRow.right_text(d[i]), 1.0, XState.current.is_new(d[i].rec))
		return
	var a := actor()
	var nw := slot_name_width(c)
	for i in range(_slot_top, mini(a.equips.size(), _slot_top + _rows())):
		var y := (i - _slot_top) * LH
		if _mode == "slot" and i == _slot:
			c.cursor(Rect2(0, y, c.size.x, LH))
		_paint_slot(c, a, i, y, nw)


## Window_EquipSlot.drawItem：itemRectForText（x 6、宽 内容宽−12）；槽位名、drawItemName 或 drawEmptySlot
func _paint_slot(c: XMVCanvas, a: XActor, i: int, y: float, nw: float) -> void:
	var alpha := 1.0 if XEquipment.can_change(a, i) else XUI.DIM.a
	var x := 6.0
	var w := c.size.x - 12.0
	c.text(slot_name(i), x, y, nw, "left", XUI.SYSTEM, XUI.FONT_SIZE, LH, alpha)
	var e = a.equips[i]
	if e is Dictionary and not e.is_empty():
		c.icon(int(e.get("iconIndex", 0)), x + nw + 2, y + 2, alpha)
		c.text(str(e.get("name", "")), x + nw + 36, y, w - nw - 36, "left", XGear.color(e), XUI.FONT_SIZE, LH, alpha)
	else:
		c.icon(int(XDB.plugin("YEP_EquipCore").get("Empty Icon", 0)), x + nw + 2, y + 2, XUI.DIM.a)
		c.text(str(XDB.plugin("YEP_EquipCore").get("Empty Text", "")), x + nw + 36, y, w - nw - 36, "left", XUI.TEXT, XUI.FONT_SIZE, LH, XUI.DIM.a)


## drawRemoveEquip：图标 (2, y+2)，文字 x 36、宽 = 行宽 − 文字边距 − 36
func _paint_remove(c: XMVCanvas, y: float) -> void:
	var eq := XDB.plugin("YEP_EquipCore")
	c.icon(int(eq.get("Remove Icon", 1354)), 2, y + 2)
	c.text(str(eq.get("Remove Text", "卸载")), 36, y, c.size.x - 6 - 36, "left")


func _paint_lower(c: XMVCanvas) -> void:
	if _compare:
		paint_compare(c, actor(), _temp_actor())
	else:
		XItemScene.paint_info(c, _shown_item())


## Window_StatCompare.drawItem × 8（正式版位置；COMPARE_SHIFT 为优化 O-009）
static func paint_compare(c: XMVCanvas, a: XActor, temp: XActor) -> void:
	var names: Array = XDB.system().get("terms", {}).get("params", [])
	var right := c.size.x - 6.0
	var cur_x := right - (COMPARE_VALUE_W * 2 + COMPARE_ARROW_W) + 60 - COMPARE_SHIFT
	var arrow_x := right - (COMPARE_VALUE_W + COMPARE_ARROW_W) + 60 - COMPARE_SHIFT
	var new_x := right - COMPARE_VALUE_W + 45 - COMPARE_SHIFT
	for i in range(8):
		var y := i * LH
		c.draw_rect(Rect2(1, y + 1, c.size.x - 2, LH - 2), Color(XUI.GAUGE_BACK, XUI.DIM.a))
		var pname: String = str(names[i]) if i < names.size() else XMenu.PARAM_NAMES[i]
		c.text(pname.substr(0, 4), COMPARE_NAME_X, y, COMPARE_NAME_W, "left", XUI.SYSTEM, XUI.FONT_SIZE, LH)
		var before := a.param(i)
		c.text(XMenu._group(before), cur_x, y, COMPARE_VALUE_W, "right", XUI.TEXT, XUI.FONT_SIZE, LH)
		c.text("→", arrow_x, y, COMPARE_ARROW_W, "center", XUI.SYSTEM, XUI.FONT_SIZE, LH)
		if temp == null:
			continue
		var after := temp.param(i)
		var color := XUI.POWER_UP if after > before else (XUI.POWER_DOWN if after < before else XUI.TEXT)
		c.text(XMenu._group(after), new_x, y, COMPARE_VALUE_W, "right", color, XUI.FONT_SIZE, LH)


# ---- 操作 ----
func _unhandled_input(event: InputEvent) -> void:
	var handled := true
	var key := event as InputEventKey
	if event.is_action_pressed("ui_cancel"):
		_cancel()
	elif event.is_action_pressed("ui_accept"):
		_ok()
	elif event.is_action_pressed("ui_down", true):
		_move(1, not event.is_echo())
	elif event.is_action_pressed("ui_up", true):
		_move(-1, not event.is_echo())
	elif event.is_action_pressed("ui_right", true) or (key and key.pressed and key.keycode == KEY_TAB):
		shift_lower()
	elif event.is_action_pressed("ui_left", true):
		shift_lower()
	elif _mode == "command" and (event.is_action_pressed("ui_page_up") or (key and key.pressed and not key.echo and key.keycode == KEY_Q)):
		switch_actor(-1)
	elif _mode == "command" and (event.is_action_pressed("ui_page_down") or (key and key.pressed and not key.echo and key.keycode == KEY_W)):
		switch_actor(1)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


## shiftLowerRightWindows / unshiftLowerRightWindows：两个窗口时前后换都是对调
func shift_lower() -> void:
	_compare = not _compare
	XSound.system(0)
	lower_win.refresh()


## Scene_Equip.nextActor/previousActor → onActorChange：回到指令窗，右下两个窗口清空对象
func switch_actor(d: int) -> void:
	XSound.system(0)
	_commit_seen()
	actor_index += d
	actor()
	_mode = "command"
	_slot = 0
	_slot_top = 0
	_refresh()


func _move(d: int, wrap: bool) -> void:
	var before := [_cmd, _slot, _item_index]
	match _mode:
		"command":
			_cmd = XMenu._move(_cmd, d, commands().size(), wrap)
		"slot":
			_slot = XMenu._move(_slot, d, actor().equip_slots().size(), wrap)
			_slot_top = XMenu._scroll_to(_slot, _slot_top, _rows())
		"item":
			_item_index = XMenu._move(_item_index, d, candidates().size(), wrap)
			_item_top = XMenu._scroll_to(_item_index, _item_top, _rows())
	if before != [_cmd, _slot, _item_index]:
		XSound.system(0)
	_refresh()


func _ok() -> void:
	match _mode:
		"command":
			XSound.system(1)
			match str(commands()[_cmd].symbol):
				"equip":
					_mode = "slot"
					_slot = 0
					_slot_top = 0
				"clear":
					XSound.system(4)
					_keep_rates(func(): XEquipment.clear(XState.current, actor()))
				"cancel":
					closed.emit()
					return
		"slot":
			if not XEquipment.can_change(actor(), _slot):
				XSound.system(3)
				return
			XSound.system(1)
			_mode = "item"
			_item_index = 0
			_item_top = 0
		"item":
			var e := _candidate()
			XSound.system(1)
			XSound.system(4)
			_commit_seen()
			_keep_rates(func(): XEquipment.change(XState.current, actor(), _slot, e if not e.is_empty() else null))
			_mode = "slot"
	_refresh()


func _cancel() -> void:
	XSound.system(2)
	match _mode:
		"command":
			closed.emit()
			return
		"slot":
			_mode = "command"
		"item":
			_commit_seen()
			_mode = "slot"
	_refresh()


## YEP onItemOk / commandClear：换装后 HP、MP 按换装前的比例（活着至少 1）
func _keep_rates(change: Callable) -> void:
	var a := actor()
	var hp_rate := a.hp / maxf(1.0, a.mhp)
	var mp_rate := a.mp / maxf(1.0, a.mmp)
	change.call()
	a.hp = maxf(0.0 if a.is_dead() else 1.0, floorf(a.mhp * hp_rate))
	a.mp = floorf(a.mmp * mp_rate)


# ---- 鼠标：只有活动窗口响应（选中行再点＝确定）；右键取消；滚轮滚动活动列表；点右下区域换窗口 ----
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var p: Vector2 = event.position
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			_cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			var d := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			if _mode == "slot":
				_slot_top = clampi(_slot_top + d, 0, maxi(0, actor().equip_slots().size() - _rows()))
			elif _mode == "item":
				_item_top = clampi(_item_top + d, 0, maxi(0, candidates().size() - _rows()))
			_refresh()
		MOUSE_BUTTON_LEFT:
			if LOWER_RECT.has_point(p):
				shift_lower()
			else:
				_click(p)


func _click(p: Vector2) -> void:
	var pad := Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
	match _mode:
		"command":
			if CMD_RECT.has_point(p):
				_click_row(floori((p - CMD_RECT.position - pad).y / LH), commands().size(), "_cmd")
		"slot":
			if LIST_RECT.has_point(p):
				_click_row(_slot_top + floori((p - LIST_RECT.position - pad).y / LH), actor().equip_slots().size(), "_slot")
		"item":
			if LIST_RECT.has_point(p):
				_click_row(_item_top + floori((p - LIST_RECT.position - pad).y / LH), candidates().size(), "_item_index")


func _click_row(i: int, n: int, field: String) -> void:
	if i < 0 or i >= n:
		return
	if i == int(get(field)):
		_ok()
	else:
		XSound.system(0)
		set(field, i)
		_refresh()
