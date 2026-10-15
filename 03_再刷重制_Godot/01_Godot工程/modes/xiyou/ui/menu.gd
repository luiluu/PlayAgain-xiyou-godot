class_name XMenu
extends Control
## 地图主菜单，按正式版运行时逐像素复现（参照截图：04_验证/本地结果/原版参照/11～14）：
## - 指令窗 (0,0,240,568)：行高 36、可见 15 行、左对齐，18 条指令与正式版同序（YEP_MainMenuManager＋各运行模块）。
## - 金钱窗 (0,656,240,64)：字号 20 右对齐数值＋图标 416（YEP_MainMenuManager 金钱图标）。
## - 队伍窗 (240,0,1040,720)：可见 5 行、每行 138（MrTS 出战 5 人）；installCombatPowerRuntime 的行布局：
##   头像 144×136（上下各裁 4px）、名字/等级/状态图标/「战力见状态」在左列（x 158、宽 144），
##   称号与 HP/MP/TP 在右列（x 314、宽 686），行高 33；YEP 描边量条与「当前/最大」数值。
## - 选「技能/装备/状态」后光标移到队伍窗选人（整行高亮），确定进入该角色页面，取消回到指令窗。
## - 窗口整体不透明度 30（MOG_MenuBackground）；底图与粒子 XUI.menu_background。
## 尚未重制的指令（真气、种族祝福等；技能页 dev.030 起可用）暂时灰显，原版均可用；见 界面风格.md。
## - 音效照 Window_Selectable：换行播光标音；确定播确定音（灰显指令蜂鸣）；取消播取消音。
## - 正式 v0.24 已移除菜单底部一键存档；快速存档的后端规则仍保留。

signal closed

const PARAM_NAMES := ["最大生命", "最大魔法", "攻击", "防御", "魔攻", "魔防", "敏捷", "幸运"]
const CMD_RECT := Rect2(0, 0, 240, 568)
const GOLD_RECT := Rect2(0, 656, 240, 64)
const STATUS_RECT := Rect2(240, 0, 1040, 720)
const CMD_LH := 36.0
const STATUS_LH := 33.0
const STATUS_ROWS := 5
const GOLD_ICON := 416
const POWER_COLOR := Color8(255, 211, 115)
## [名称, 符号, 已重制]
const COMMANDS := [["物品", "item", true], ["技能", "skill", true], ["装备", "equip", true], ["状态", "status", true],
	["真气", "zhenqi", false], ["整队", "formation", true], ["种族祝福", "race", false], ["宠物", "pet", false],
	["制作", "crafting", false], ["宝珠坊", "orbs", false], ["异化工坊", "alienation", false], ["人物图鉴", "actorBook", false],
	["怪物图鉴", "monsterBook", false], ["成就", "achievement", false], ["存档", "save", true], ["反馈", "feedback", false],
	["设置", "options", true], ["游戏结束", "gameEnd", true]]
const CMD_VISIBLE := 15

var cmd_win: XMVWindow
var gold_win: XMVWindow
var status_win: XMVWindow
var _cmd_index := 0
var _cmd_top := 0
var _actor_index := 0
var _actor_top := 0
var _mode := "command"          # command / actor / page
var _pending := ""              # 选人后要打开的指令
var _selected_actor := 0
var _overlay: Control
## 打开菜单前的地图截图与玩家画面格（设置 → 挂机设置页的背景与范围图；Scene_Map.terminate 的 snapForHangUp）
var map_shot: Texture2D
var player_tile := Vector2.ZERO
## 关闭菜单后要在地图上执行的公共事件（YEP_MainMenuManager callCommonEvent：reserveCommonEvent 后 popScene）
var reserved_common_event := 0


func command_names() -> Array:
	return COMMANDS.map(func(c): return c[0])


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	cmd_win = XMVWindow.make(self, CMD_RECT, XUI.MENU_WINDOW_OPACITY, _paint_commands)
	cmd_win.canvas.blink = true
	gold_win = XMVWindow.make(self, GOLD_RECT, XUI.MENU_WINDOW_OPACITY, _paint_gold)
	status_win = XMVWindow.make(self, STATUS_RECT, XUI.MENU_WINDOW_OPACITY, _paint_status)
	status_win.canvas.blink = true
	_refresh()


func _members() -> Array:
	return XState.current.members()


func _refresh() -> void:
	cmd_win.up_arrow = _cmd_top > 0
	cmd_win.down_arrow = _cmd_top < COMMANDS.size() - CMD_VISIBLE
	status_win.up_arrow = _actor_top > 0
	status_win.down_arrow = _actor_top < _members().size() - STATUS_ROWS
	for w in [cmd_win, gold_win, status_win]:
		w.refresh()


# ---- 绘制 ----
func _paint_commands(c: XMVCanvas) -> void:
	for i in range(COMMANDS.size()):
		var y := (i - _cmd_top) * CMD_LH
		if y < -CMD_LH or y > c.size.y:
			continue
		if i == _cmd_index:
			c.cursor(Rect2(0, y, c.size.x, CMD_LH), _mode == "command")
		c.text(COMMANDS[i][0], 6, y, c.size.x - 12, "left", XUI.TEXT, XUI.FONT_SIZE, CMD_LH, 1.0 if COMMANDS[i][2] else XUI.DIM.a)


func _paint_gold(c: XMVCanvas) -> void:
	var ww := c.size.x - 12
	c.text(str(XState.current.gold), 6, 0, ww - 32 - 4, "right", XUI.TEXT, 20, CMD_LH)
	c.icon(GOLD_ICON, 6 + ww - 32, 2)


func _row_height(c: XMVCanvas) -> float:
	return floorf(c.size.y / STATUS_ROWS)


func _paint_status(c: XMVCanvas) -> void:
	var rh := _row_height(c)
	var members := _members()
	var battle := XState.current.battle_members()
	for i in range(members.size()):
		var ry := (i - _actor_top) * rh
		if ry < -rh or ry > c.size.y:
			continue
		var a: XActor = members[i]
		if _mode == "actor" and i == _actor_index:
			c.cursor(Rect2(0, ry, c.size.x, rh))
		c.face(str(a.data().faceName), int(a.data().faceIndex), 1, ry + 1, 144, rh - 2, 1.0 if battle.has(a) else XUI.DIM.a)
		_paint_actor(c, a, 158.0, ry, c.size.x - 158.0 - 6.0)


## installCombatPowerRuntime 的 drawActorSimpleStatus：主菜单行（行高 33、「战力见状态」）与
## 技能/装备页的 Window_SkillStatus（行高 36、「战力 N」，没有估算时写「战力 …」）共用。
func _paint_actor(c: XMVCanvas, a: XActor, x: float, y: float, width: float) -> void:
	paint_actor_status(c, a, x, y, width, STATUS_LH, XPower.menu_text(a))


static func paint_actor_status(c: XMVCanvas, a: XActor, x: float, y: float, width: float, lh := STATUS_LH, power := "战力见状态") -> void:
	var gap := 144.0 + 12.0
	var x2 := x + gap
	var left_w := gap - 12.0
	var right_w := maxf(0.0, minf(width - gap - 6.0, c.size.x - x2))
	var name := a.display_name()
	var code := str(a.nickname).strip_edges()
	if code == "" or code == name:
		var cls := str(a.class_data().get("name", "")).strip_edges()
		code = cls if cls != name else ""
	c.text(name, x, y, left_w, "left", _hp_color(a), XUI.FONT_SIZE, lh)
	c.text(code, x2, y, right_w, "left", XUI.TEXT, XUI.FONT_SIZE, lh)
	# 等级：「Lv」系统色，数值在最大等级位数宽度内右对齐
	var lv_w := c.text_width("Lv")
	c.text("Lv", x, y + lh, lv_w, "left", XUI.SYSTEM, XUI.FONT_SIZE, lh)
	c.text(_group(a.level), x + lv_w, y + lh, c.text_width(_group(a.max_level())), "right", XUI.TEXT, XUI.FONT_SIZE, lh)
	var n := 0
	for st in a.states():
		if int(st.get("iconIndex", 0)) > 0 and n < floori(left_w / 32.0):
			c.icon(int(st.iconIndex), x + n * 32, y + lh * 2 + 2)
			n += 1
	c.text(power, x, y + lh * 3, left_w, "left", POWER_COLOR, 21, lh)
	_param(c, "HP", a.hp, a.mhp, x2, y + lh, right_w, "hp", _hp_color(a), lh)
	_param(c, "MP", a.mp, a.mmp, x2, y + lh * 2, right_w, "mp", XUI.TEXT, lh)
	var tp_cols: Array = XUI.GAUGES.tp
	c.gauge(x2, y + lh * 3, right_w, a.tp / a.max_tp(), tp_cols[0], tp_cols[1], lh)
	c.text("TP", x2, y + lh * 3, 44, "left", XUI.SYSTEM, XUI.FONT_SIZE, lh)
	c.text(str(int(a.tp)), x2 + right_w - 64, y + lh * 3, 64, "right", XUI.TEXT, XUI.FONT_SIZE, lh)


## Window_Base.drawActorHp/Mp＋YEP drawCurrentAndMax
static func _param(c: XMVCanvas, label: String, cur: float, mx: float, x: float, y: float, w: float, kind: String, color: Color, lh := STATUS_LH) -> void:
	var cols: Array = XUI.GAUGES[kind]
	c.gauge(x, y, w, cur / maxf(mx, 1.0), cols[0], cols[1], lh)
	c.text(label, x, y, 44, "left", XUI.SYSTEM, XUI.FONT_SIZE, lh)
	var vw := c.text_width(_group(mx))
	var sw := c.text_width("/")
	var x1 := x + w - vw
	var xs := x1 - sw
	var x3 := xs - vw
	if x3 >= x + c.text_width("HP"):
		c.text(_group(cur), x3, y, vw, "right", color, XUI.FONT_SIZE, lh)
		c.text("/", xs, y, sw, "right", XUI.TEXT, XUI.FONT_SIZE, lh)
		c.text(_group(mx), x1, y, vw, "right", XUI.TEXT, XUI.FONT_SIZE, lh)
	else:
		c.text(_group(cur), x1, y, vw, "right", color, XUI.FONT_SIZE, lh)


static func _hp_color(a: XActor) -> Color:
	if a.is_dead():
		return XUI.DEATH
	if a.hp < a.mhp / 4.0:
		return XUI.CRISIS
	return XUI.TEXT


## Yanfly.Util.toGroup：千位逗号
static func _group(v: float) -> String:
	var s := str(int(v))
	var neg := s.begins_with("-")
	if neg:
		s = s.substr(1)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out


# ---- 操作 ----
func _gui_input(event: InputEvent) -> void:
	if _mode == "page":
		return
	if event is InputEventMouseButton and event.pressed:
		var p: Vector2 = event.position
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var d := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			if CMD_RECT.has_point(p):
				_cmd_top = clampi(_cmd_top + d, 0, maxi(0, COMMANDS.size() - CMD_VISIBLE))
			elif STATUS_RECT.has_point(p):
				_actor_top = clampi(_actor_top + d, 0, maxi(0, _members().size() - STATUS_ROWS))
			_refresh()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_click(p)


## MV processTouch：点到当前选中的行即确定，点到别的行先选中。
func _click(p: Vector2) -> void:
	var cp := p - CMD_RECT.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
	if _mode == "command" and CMD_RECT.has_point(p):
		var i := _cmd_top + floori(cp.y / CMD_LH)
		if i >= 0 and i < COMMANDS.size():
			if i == _cmd_index:
				_ok()
			else:
				_cmd_index = i
				XSound.system(0)
				_refresh()
		return
	var sp := p - STATUS_RECT.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
	if _mode == "actor" and STATUS_RECT.has_point(p):
		var i := _actor_top + floori(sp.y / _row_height(status_win.canvas))
		if i >= 0 and i < _members().size():
			if i == _actor_index:
				_ok()
			else:
				_actor_index = i
				XSound.system(0)
				_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _mode == "page":
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		var d := 1 if event.is_action_pressed("ui_down", true) else -1
		var wrap := not event.is_echo()
		var before := [_cmd_index, _actor_index]
		if _mode == "command":
			_cmd_index = _move(_cmd_index, d, COMMANDS.size(), wrap)
			_cmd_top = _scroll_to(_cmd_index, _cmd_top, CMD_VISIBLE)
		elif _mode == "actor":
			_actor_index = _move(_actor_index, d, _members().size(), wrap)
			_actor_top = _scroll_to(_actor_index, _actor_top, STATUS_ROWS)
		if before != [_cmd_index, _actor_index]:
			XSound.system(0)
		_refresh()


static func _move(i: int, d: int, n: int, wrap: bool) -> int:
	var j := i + d
	if j < 0:
		return n - 1 if wrap else 0
	if j >= n:
		return 0 if wrap else n - 1
	return j


static func _scroll_to(i: int, top: int, visible: int) -> int:
	if i < top:
		return i
	if i >= top + visible:
		return i - visible + 1
	return top


func _ok() -> void:
	if _mode == "command":
		var cmd: Array = COMMANDS[_cmd_index]
		if not cmd[2]:
			XSound.system(3)
			return
		XSound.system(1)
		match cmd[1]:
			"item":
				_show_items()
			"skill", "equip", "status":
				_pending = cmd[1]
				_mode = "actor"
				_actor_index = clampi(_selected_actor, 0, _members().size() - 1)
				_actor_top = _scroll_to(_actor_index, _actor_top, STATUS_ROWS)
				_refresh()
			"save":
				# 正式版「存档」是公共事件 1（Menu 84 Ext）：回到地图后存到开局选的固定存档位
				reserved_common_event = int(str(XDB.plugin("YEP_MainMenuManager").get("Menu 84 Ext", "1")))
				closed.emit()
			"options":
				var page := XOptionsScene.new()
				page.map_shot = map_shot
				page.player_tile = player_tile
				_open_detail(page)
			"formation":
				# Scene_Menu.commandFormation → YEP_PartySystem 的 Scene_Party
				_open_detail(XPartyScene.new())
			"gameEnd":
				_show_game_end()
	elif _mode == "actor":
		XSound.system(1)
		_selected_actor = _actor_index
		match _pending:
			"skill":
				_open_detail(XSkillScene.new())
			"status":
				_show_status()
			"equip":
				_show_equip()


func _cancel() -> void:
	if _mode in ["actor", "command"]:
		XSound.system(2)
	if _mode == "actor":
		_mode = "command"
		_refresh()
	elif _mode == "command":
		closed.emit()


func _cur() -> XActor:
	var s := XState.current
	_selected_actor = clampi(_selected_actor, 0, s.party.size() - 1)
	return s.actor(s.party[_selected_actor])


func _show_status() -> void:
	_open_detail(XStatusPage.new())

func _show_equip() -> void:
	_open_detail(XEquipScene.new())

## 子页面盖在菜单上；关闭后回到指令窗（MV 返回 Scene_Menu 时指令窗活动、选中上次指令）。
func _open_detail(page: Control) -> void:
	_mode = "page"
	for node in get_children():
		if node is CanvasItem:
			node.hide()
	if "actor_index" in page:
		page.actor_index = _selected_actor
	add_child(page)
	page.closed.connect(func():
		if "actor_index" in page:
			_selected_actor = page.actor_index
		page.queue_free()
		for node in get_children():
			if node is CanvasItem and node != page:
				node.show()
		_mode = "command"
		_refresh())


func _show_items() -> void:
	_open_detail(XItemScene.new())


## v0.10 一键存档（installV010UsabilityRuntime CodexQuickSave.run）：存到最近一次存/读档的格，成功提示「已保存到存档 N。」，
## 失败蜂鸣并提示；新游戏后还没存过档时改为打开选格的存档页（Scene_Save）。菜单留在指令窗。
func _quick_save() -> void:
	var slot := XSave.current_slot
	if slot < 1 or slot > XSave.SLOTS:
		_show_save()
		return
	if XSave.save(slot):
		XSound.system(5)
		XToast.show_text("已保存到存档 %d。" % slot, true)
	else:
		XSound.system(3)
		XToast.show_text("存档失败，请通过存档菜单重试。", true)


## 选格存档页（YEP 的 Scene_Save；只在一键存档还没有存档格时打开），盖在队伍窗位置。
func _show_save() -> void:
	var page := XSavePanel.new()
	page.position = STATUS_RECT.position
	page.size = STATUS_RECT.size
	_open_detail(page)
	for node in get_children():
		if node == cmd_win or node == gold_win or (node is TextureRect) or (node is CPUParticles2D):
			node.show()


## Scene_GameEnd：背景不透明度 128，窗口 (520,310,240,100)，「回到标题 / 取消」。
func _show_game_end() -> void:
	var page := XGameEndPanel.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_open_detail(page)
	for node in get_children():
		if (node is TextureRect) or (node is CPUParticles2D):
			node.show()
	page.to_title.connect(_to_title)


func _to_title() -> void:
	get_tree().change_scene_to_file("res://modes/xiyou/entry.tscn")
