class_name XSkillScene
extends Control
## 主菜单「技能」：Scene_Skill（YEP_SkillCore＋YEP_X_SkillCooldowns＋HelpExtend 说明卡），按正式 v0.24 运行时复现
## （参照 原版参照/claude_skill_00、claude_skill_01_list）。
## - 背景同主菜单，窗口不透明度 30。技能类型 (0,0,240,172)：角色的技能类型（特性 41，编号升序）居中，可见 4 行；
##   状态 (240,0,1040,172)：Window_SkillStatus（与装备页同一画法 XMenu.paint_actor_status，战力写「战力 …」）；
##   列表 (0,172,1280,548)：两列（宽 602、间距 48）、行高 36；图标＋名字（品质/ici 色）＋右侧 YEP 消耗（字号 20、TP/MP 图标），
##   冷却/预热写「nCD」「nWU」；不能用的（战斗专用、消耗不足）半透明。类型阶段列表只显示、无光标。
## - 说明卡（XHelpCard）跟着列表选中项：Sprite_ItemHelp.updatePos 用不含内边距的行矩形（行右 −4、行底 −4，再 x<900 右移 52、y<220 下移 32）。
## - 操作：类型确定 → 列表；列表确定：能用的打开选人（Window_MenuActor，全体技能全选），不能用蜂鸣；选人确定用技能（付消耗、
##   效果同物品，使用技能音），留在选人；Q/E（上一页/下一页）换角色；取消逐层返回主菜单。

signal closed

const TYPE_RECT := Rect2(0, 0, 240, 172)
const STATUS_RECT := Rect2(240, 0, 1040, 172)
const LIST_RECT := Rect2(0, 172, 1280, 548)
const ACTOR_RECT := Rect2(0, 0, 1280, 720)
const LH := 36.0
const COL_W := 602.0
const SPACING := 48.0
const TYPE_ROWS := 4
const ACTOR_ROWS := 4
const ACTOR_ROW_H := 173.0
const POWER_TEXT := "战力 …"
const COST_SIZE := 20

var actor_index := 0
var mode := "type"            # type / list / actor
var type_index := 0
var type_top := 0
var index := 0
var top := 0
var actor_pick := 0
var actor_top := 0
var type_win: XMVWindow
var status_win: XMVWindow
var list_win: XMVWindow
var actor_win: XMVWindow
var help_card: XHelpCard
var logic: XBattleLogic


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	logic = XBattleLogic.new()
	logic.state = XState.current
	type_win = XMVWindow.make(self, TYPE_RECT, XUI.MENU_WINDOW_OPACITY, _paint_types)
	status_win = XMVWindow.make(self, STATUS_RECT, XUI.MENU_WINDOW_OPACITY, _paint_status)
	list_win = XMVWindow.make(self, LIST_RECT, XUI.MENU_WINDOW_OPACITY, _paint_list)
	actor_win = XMVWindow.make(self, ACTOR_RECT, XUI.MENU_WINDOW_OPACITY, _paint_actors)
	for w in [type_win, list_win, actor_win]:
		w.canvas.blink = true
	help_card = XHelpCard.new()
	add_child(help_card)
	_refresh()


func actor() -> XActor:
	var s := XState.current
	actor_index = clampi(actor_index, 0, s.party.size() - 1)
	return s.actor(s.party[actor_index])


## Window_SkillType.makeCommandList：addedSkillTypes 升序
func types() -> Array:
	var ids := []
	for t in actor().all_traits():
		if int(t.code) == 41 and not ids.has(int(t.dataId)):
			ids.append(int(t.dataId))
	ids.sort()
	return ids


func type_name(id: int) -> String:
	var names: Array = XDB.system().get("skillTypes", [])
	return str(names[id]) if id >= 0 and id < names.size() else ""


func entries() -> Array:
	var list := types()
	if list.is_empty():
		return []
	var st: int = list[clampi(type_index, 0, list.size() - 1)]
	return actor().skills().filter(func(s): return int(s.get("stypeId", 0)) == st)


func current() -> Dictionary:
	var list := entries()
	return list[index] if index >= 0 and index < list.size() else {}


## Game_BattlerBase.canUse（地图上）：场合为「随时」或「菜单」，且满足消耗/武器/冷却
func usable(skill: Dictionary) -> bool:
	return not skill.is_empty() and int(skill.get("occasion", 0)) in [0, 2] and logic.can_use(actor(), skill)


func _list_rows() -> int:
	return floori((LIST_RECT.size.y - XMVWindow.PADDING * 2) / LH)


func _refresh() -> void:
	var n_types := types().size()
	type_win.up_arrow = type_top > 0
	type_win.down_arrow = type_top < n_types - TYPE_ROWS
	var rows_total := ceili(entries().size() / 2.0)
	list_win.up_arrow = top > 0
	list_win.down_arrow = top < rows_total - _list_rows()
	var actor_mode := mode == "actor"
	for w in [type_win, status_win, list_win]:
		w.visible = not actor_mode
	actor_win.visible = actor_mode
	actor_win.up_arrow = actor_top > 0
	actor_win.down_arrow = actor_top + ACTOR_ROWS < XState.current.members().size()
	for w in [type_win, status_win, list_win, actor_win]:
		w.refresh()
	_update_help()


func _update_help() -> void:
	if mode != "list" or current().is_empty():
		help_card.show_for({})
		return
	help_card.show_for(current())
	var row := index / 2 - top
	var col := index % 2
	# 两列列表：O-008 的贴边放法会盖住另一列，这里一律用正式位置
	help_card.place_original(Rect2(LIST_RECT.position.x + col * (COL_W + SPACING), LIST_RECT.position.y + row * LH, COL_W, LH))


# ---- 绘制 ----
func _paint_types(c: XMVCanvas) -> void:
	var list := types()
	for i in range(type_top, mini(type_top + TYPE_ROWS, list.size())):
		var y := (i - type_top) * LH
		if i == type_index:
			c.cursor(Rect2(0, y, c.size.x, LH), mode == "type")
		c.text(type_name(list[i]), 6, y, c.size.x - 12, "center")


func _paint_status(c: XMVCanvas) -> void:
	var a := actor()
	c.face(str(a.data().get("faceName", "")), int(a.data().get("faceIndex", 0)), 0, 0, 144, c.size.y)
	XMenu.paint_actor_status(c, a, 158, 0, c.size.x - 158 - 6, LH, POWER_TEXT)


func _paint_list(c: XMVCanvas) -> void:
	var list := entries()
	var a := actor()
	for i in range(top * 2, mini((top + _list_rows()) * 2, list.size())):
		var x := (i % 2) * (COL_W + SPACING)
		var y := (i / 2 - top) * LH
		if mode == "list" and i == index:
			c.cursor(Rect2(x, y, COL_W, LH))
		var s: Dictionary = list[i]
		var alpha := 1.0 if usable(s) else XUI.DIM.a
		var w := COL_W - 6.0
		var name_w := w - c.text_width("000")
		if int(s.get("iconIndex", 0)) > 0:
			c.icon(int(s.iconIndex), x + 2, y + 2, alpha)
		c.text(str(s.name), x + 36, y, name_w - 36, "left", XQuality.list_color(s), XUI.FONT_SIZE, LH, alpha)
		var dw := w
		for cost in _costs(a, s):
			if int(cost.get("icon", 0)) > 0:
				c.icon(int(cost.icon), x + dw - 32, y + 2, alpha)
				dw -= 34
			c.text(str(cost.text), x, y, dw, "right", cost.color, COST_SIZE, LH, alpha)
			dw -= c.text_width(str(cost.text), COST_SIZE) + 5


## YEP_SkillCore drawSkillCost / YEP_X_SkillCooldowns：预热、冷却优先，否则 TP、MP 由右往左
func _costs(a: XActor, s: Dictionary) -> Array:
	var wu := int(ceilf(float(a.warmups.get(int(s.id), 0))))
	var cd := int(ceilf(float(a.cooldowns.get(int(s.id), 0))))
	if wu > 0:
		return [{"text": "%dWU" % wu, "color": XUI.text_color(4), "icon": 1045}]
	if cd > 0:
		return [{"text": "%dCD" % cd, "color": XUI.text_color(6), "icon": 1045}]
	var out := []
	var c := logic.skill_cost(a, s)
	if c.tp > 0:
		out.append({"text": "%sTP" % XMenu._group(c.tp), "color": XUI.text_color(29), "icon": 1268})
	if c.mp > 0:
		out.append({"text": "%sMP" % XMenu._group(c.mp), "color": XUI.text_color(23), "icon": 1269})
	return out


func _paint_actors(c: XMVCanvas) -> void:
	var members := XState.current.members()
	var all := int(current().get("scope", 0)) in [8, 10]
	for i in range(actor_top, mini(actor_top + ACTOR_ROWS, members.size())):
		var y := (i - actor_top) * ACTOR_ROW_H
		if all or i == actor_pick:
			c.cursor(Rect2(0, y, c.size.x, ACTOR_ROW_H))
		var m: XActor = members[i]
		c.face(str(m.data().get("faceName", "")), int(m.data().get("faceIndex", 0)), 1, y + floorf((ACTOR_ROW_H - 144.0) / 2.0))
		c.text(m.display_name(), 158, y, 168)
		var lv_w := c.text_width("Lv")
		c.text("Lv", 158, y + LH, lv_w, "left", XUI.SYSTEM)
		c.text(XMenu._group(m.level), 158 + lv_w, y + LH, c.text_width(XMenu._group(m.max_level())), "right")
		var gx := 314.0
		var gw := c.size.x - gx - 12.0
		XItemScene._current_max(c, "HP", m.hp, m.mhp, gx, y + LH, gw, "hp")
		XItemScene._current_max(c, "MP", m.mp, m.mmp, gx, y + LH * 2, gw, "mp")


# ---- 操作 ----
func ok() -> void:
	match mode:
		"type":
			if types().is_empty():
				XSound.system(3)
				return
			XSound.system(1)
			mode = "list"
			index = clampi(index, 0, maxi(0, entries().size() - 1))
		"list":
			if not usable(current()):
				XSound.system(3)
				return
			XSound.system(1)
			mode = "actor"
			actor_pick = 0
			actor_top = 0
		"actor":
			use_skill()
	_refresh()


func cancel() -> void:
	XSound.system(2)
	match mode:
		"type":
			help_card.show_for({})
			closed.emit()
			return
		"list":
			mode = "type"
		"actor":
			mode = "list"
	_refresh()


## Scene_Skill.useItem：付消耗、使用技能音，效果同物品（Game_Action.apply 的效果栏）；对象无效时蜂鸣
func use_skill() -> void:
	var s := current()
	var a := actor()
	var members := XState.current.members()
	var targets: Array = members if int(s.get("scope", 0)) in [8, 10] else ([a] if int(s.get("scope", 0)) == 11 else [members[clampi(actor_pick, 0, members.size() - 1)]])
	var dead_ok := int(s.get("scope", 0)) in [9, 10]
	targets = targets.filter(func(t): return t.is_dead() == dead_ok)
	if not usable(s) or targets.is_empty():
		XSound.system(3)
		return
	XSound.system(23)
	var c := logic.skill_cost(a, s)
	a.mp -= c.mp
	a.tp -= c.tp
	for t in targets:
		for e in s.get("effects", []):
			logic._effect(a, t, e, {"skill": s, "hp": 0.0, "mp": 0.0, "added": [], "removed": []})


## Scene_MenuBase.nextActor/previousActor：换角色后回到类型窗
func change_actor(d: int) -> void:
	if mode == "actor":
		return
	var n := XState.current.party.size()
	actor_index = (actor_index + d + n) % n
	XSound.system(0)
	mode = "type"
	type_index = 0
	type_top = 0
	index = 0
	top = 0
	_refresh()


func _move(d: int, horizontal: bool, wrap: bool) -> void:
	var before := [type_index, index, actor_pick]
	match mode:
		"type":
			if horizontal:
				return
			type_index = XMenu._move(type_index, d, types().size(), wrap)
			type_top = XMenu._scroll_to(type_index, type_top, TYPE_ROWS)
			index = 0
			top = 0
		"list":
			var n := entries().size()
			if n == 0:
				return
			if horizontal:
				# Window_Selectable.cursorRight/Left：两列时左右各移一格（首按可在行尾/行首换行）
				if d > 0 and (index < n - 1 or wrap):
					index = (index + 1) % n
				elif d < 0 and (index > 0 or wrap):
					index = (index - 1 + n) % n
			else:
				var j := index + d * 2
				if j < 0 or j >= n:
					if wrap:
						j = (j + n * 2) % (ceili(n / 2.0) * 2)
						if j >= n:
							j = n - 1
					else:
						j = index
				index = j
			top = XMenu._scroll_to(index / 2, top, _list_rows())
		"actor":
			if horizontal or int(current().get("scope", 0)) in [8, 10]:
				return
			actor_pick = XMenu._move(actor_pick, d, XState.current.members().size(), wrap)
			actor_top = XMenu._scroll_to(actor_pick, actor_top, ACTOR_ROWS)
	if before != [type_index, index, actor_pick]:
		XSound.system(0)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var pressed := key != null and key.pressed and not key.echo
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		_move(1 if event.is_action_pressed("ui_down", true) else -1, false, not event.is_echo())
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_left", true):
		get_viewport().set_input_as_handled()
		_move(1 if event.is_action_pressed("ui_right", true) else -1, true, not event.is_echo())
	elif event.is_action_pressed("ui_page_up") or event.is_action_pressed("ui_page_down") or (pressed and key.physical_keycode in [KEY_Q, KEY_E]):
		get_viewport().set_input_as_handled()
		change_actor(-1 if event.is_action_pressed("ui_page_up") or (pressed and key.physical_keycode == KEY_Q) else 1)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var p: Vector2 = event.position
	var pad := Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
	match mode:
		"type":
			if TYPE_RECT.grow(-XMVWindow.PADDING).has_point(p):
				var i := type_top + floori((p - TYPE_RECT.position - pad).y / LH)
				if i < types().size():
					if i == type_index:
						ok()
					else:
						type_index = i
						index = 0
						top = 0
						XSound.system(0)
						_refresh()
		"list":
			if LIST_RECT.grow(-XMVWindow.PADDING).has_point(p):
				var q: Vector2 = p - LIST_RECT.position - pad
				var col := 1 if q.x >= COL_W + SPACING / 2.0 else 0
				var i := (top + floori(q.y / LH)) * 2 + col
				if i < entries().size():
					if i == index:
						ok()
					else:
						index = i
						XSound.system(0)
						_refresh()
		"actor":
			if not ACTOR_RECT.grow(-XMVWindow.PADDING).has_point(p):
				return
			var row := floori((p - pad).y / ACTOR_ROW_H)
			var i := actor_top + row
			if row < ACTOR_ROWS and i < XState.current.members().size():
				if i == actor_pick:
					ok()
				else:
					actor_pick = i
					XSound.system(0)
					_refresh()
