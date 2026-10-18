class_name XOptionsScene
extends Control
## 主菜单「设置」：MV Scene_Options，按正式 v0.16 运行时复现（参照 04_验证/本地结果/原版参照/claude_options_00）。
## - 背景同主菜单（MOG_MenuBackground 底图＋粒子），窗口不透明度 30、背景 192。
## - Window_Options (440,130,400,460)：行高 36、字号 26、可见 12 行；名字左对齐在 itemRectForText (6,宽 360) 的前 240，
##   状态右对齐在内容 x 240、宽 120（statusWidth）。33 项与正式版同序；「挂机设置」只在挂机未禁用时出现（needAddHangUp）。
## - 已重制：坐标、智能AI、始终跑步、记住指令、Battle Camera（YEP_X_ActSeqPack3，行动序列镜头）、伤害数字、技能动画、掉落动画、战斗伤害记录开关，挂机设置，四路音量与四档战斗变速，
##   战力显示与估算（ON/OFF，确定取反、右开左关；切换时清掉战力缓存，XPower），
##   消息提醒（状态「全部显示」/「N项关闭」，确定音后打开 XNoticeOptionsScene，左右无作用），
##   核心杂项开关（只遇稀有/罕见/极其稀有、穿墙、三条宣传行、对话跳过、禁用遇敌、步步遇敌）：确定取反、右开左关；
##   除穿墙外不存配置，开局未设置时状态空白（正式版 statusText 返回 undefined）。
##   队列跟随：变量 24 为 0 时 ON；切换写变量 24（开 0、关 1）并显示/隐藏跟随（重制版只能在游戏中打开设置，不会是「进入游戏」）。
##   屏蔽掉落：状态恒空白，确定无音效直接打开 XPingbiScene，左右只改无作用的 pingbiDrop（值变了播光标音）。
##   其余选项的机制还没做，暂时灰显、不显示状态，确定时蜂鸣；原版都可用（见 界面风格.md）。
## - 上下键：按住连续移动、首按可首尾循环，换行播光标音；取消（Esc/右键）播取消音返回主菜单。

signal closed

const RECT := Rect2(440, 130, 400, 460)
const LH := 36.0
const ROWS := 12
const STATUS_W := 120.0
## O-024：从挂机设置/消息提醒子页返回时保留光标位置（原版 Scene_Options 重建，回到第 0 项）
const KEEP_INDEX_AFTER_PAGE := true
## [名字, 符号, 已重制]（正式 v0.19 Window_Options._list 顺序：v0.19 加「消息提醒」、去掉「技能升级通告」）
const OPTIONS := [["坐标显示", "MapXy", true], ["挂机设置", "HangUp", true], ["始终跑步", "alwaysDash", true],
	["记住指令", "commandRemember", true], ["Battle Camera", "battleCamera", true], ["开启掉落动画", "MOG_TrPopUpBattle_Key", true],
	["战斗伤害记录", "CombatDamageRecordKey", true], ["显示伤害数字", "CombatDamageShow", true], ["显示技能动画", "CombatSkillAnimation", true],
	["屏蔽掉落", "pingbiDrop", true], ["智能战斗AI（自动战斗）", "codexSmartAI", true], ["BGM 音量", "bgmVolume", true],
	["BGS 音量", "bgsVolume", true], ["ME 音量", "meVolume", true], ["SE 音量", "seVolume", true], ["只遇稀有", "Boss", true],
	["只遇罕见", "BOSS", true], ["极其稀有", "boss", true], ["穿墙开关", "cq", true], ["此游戏为免费游戏！", "wxxonoff", true],
	["总群请加906327865！", "wxlonoff", true], ["不要在闲鱼买到这个版本！", "wxtonoff", true], ["战斗变速", "battleAniSpeed", true],
	["对话跳过", "dhtg", true], ["禁用遇敌", "ydgb", true], ["步步遇敌", "yd100", true], ["消息提醒", "codexNotices", true],
	["队列跟随", "codexFollow", true],
	["战力显示与估算", "codexPowerEnabled", true], ["测试模式", "codexTestMode", false], ["GM 工具", "codexGM", false],
	["角色换装", "codexCostumes", false], ["待提交反馈", "codexFeedbackPending", false]]

## 挂机设置页用：打开菜单前的地图截图与玩家所在的画面格（由地图经主菜单传入）
var map_shot: Texture2D
var player_tile := Vector2.ZERO
var index := 0
var top := 0
var win: XMVWindow
var _list: Array = []
var _page: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_list = OPTIONS.filter(func(o): return o[1] != "HangUp" or XHangUp.enabled(XState.current))
	XUI.menu_background(self)
	win = XMVWindow.make(self, RECT, XUI.MENU_WINDOW_OPACITY, _paint)
	win.canvas.blink = true
	_refresh()


func symbols() -> Array:
	return _list.map(func(o): return o[1])


func status_text(i: int) -> String:
	match str(_list[i][1]):
		"MapXy", "codexSmartAI", "alwaysDash", "commandRemember", "battleCamera", "CombatDamageShow", "CombatSkillAnimation", "cq",\
		"MOG_TrPopUpBattle_Key", "CombatDamageRecordKey", "codexPowerEnabled":
			return "ON" if XConfig.flag(str(_list[i][1])) else "OFF"
		"Boss", "BOSS", "boss", "wxxonoff", "wxlonoff", "wxtonoff", "dhtg", "ydgb", "yd100":
			var v = XConfig.session_value(str(_list[i][1]))
			return "" if v == null else ("ON" if v else "OFF")
		"battleAniSpeed":
			return XConfig.battle_speed_text()
		"bgmVolume", "bgsVolume", "meVolume", "seVolume":
			return str(XConfig.volume(str(_list[i][1])))
		"codexNotices":
			return XConfig.notices_text()
		"codexFollow":
			return "ON" if _follow_on() else "OFF"
	return ""


func _refresh() -> void:
	win.up_arrow = top > 0
	win.down_arrow = top < _list.size() - ROWS
	win.refresh()


func _paint(c: XMVCanvas) -> void:
	for i in range(top, mini(top + ROWS, _list.size())):
		var y := (i - top) * LH
		if i == index:
			c.cursor(Rect2(0, y, c.size.x, LH))
		var alpha := 1.0 if _list[i][2] else XUI.DIM.a
		var title_w := c.size.x - 12.0 - STATUS_W
		c.text(_list[i][0], 6, y, title_w, "left", XUI.TEXT, XUI.FONT_SIZE, LH, alpha)
		c.text(status_text(i), title_w, y, STATUS_W, "right", XUI.TEXT, XUI.FONT_SIZE, LH, alpha)


# ---- 操作 ----
func _select(i: int) -> void:
	if i == index:
		return
	index = i
	if index < top:
		top = index
	elif index >= top + ROWS:
		top = index - ROWS + 1
	XSound.system(0)
	_refresh()


func ok() -> void:
	var o: Array = _list[index]
	if not o[2]:
		XSound.system(3)
		return
	match str(o[1]):
		"MapXy", "codexSmartAI", "alwaysDash", "commandRemember", "battleCamera", "CombatDamageShow", "CombatSkillAnimation", "cq",\
		"MOG_TrPopUpBattle_Key", "CombatDamageRecordKey", "codexPowerEnabled":
			_set_flag(str(o[1]), not XConfig.flag(str(o[1])))
		"Boss", "BOSS", "boss", "wxxonoff", "wxlonoff", "wxtonoff", "dhtg", "ydgb", "yd100":
			_set_session(str(o[1]), not XConfig.flag(str(o[1])))
		"battleAniSpeed":
			_set_speed(XConfig.battle_speed() % 4 + 1)
		"bgmVolume", "bgsVolume", "meVolume", "seVolume":
			var value := XConfig.volume(str(o[1])) + 20
			_set_volume(str(o[1]), 0 if value > 100 else value)
		"HangUp":
			XSound.system(1)
			_open_hang_up()
		"pingbiDrop":
			_open_page(XPingbiScene.new())
		"codexFollow":
			_set_follow(not _follow_on())
		"codexNotices":
			XSound.system(1)
			_open_page(XNoticeOptionsScene.new())


## Window_Options.changeValue：值变了才存、重画并播光标音；HangUp 不改值
func _side(right: bool) -> void:
	match str(_list[index][1]):
		"MapXy", "codexSmartAI", "alwaysDash", "commandRemember", "battleCamera", "CombatDamageShow", "CombatSkillAnimation", "cq",\
		"MOG_TrPopUpBattle_Key", "CombatDamageRecordKey", "codexPowerEnabled":
			_set_flag(str(_list[index][1]), right)
		"Boss", "BOSS", "boss", "wxxonoff", "wxlonoff", "wxtonoff", "dhtg", "ydgb", "yd100", "pingbiDrop":
			_set_session(str(_list[index][1]), right)
		"codexFollow":
			_set_follow(right)
		"battleAniSpeed":
			_set_speed(clampi(XConfig.battle_speed() + (1 if right else -1), 1, 4))
		"bgmVolume", "bgsVolume", "meVolume", "seVolume":
			var symbol := str(_list[index][1])
			_set_volume(symbol, clampi(XConfig.volume(symbol) + (20 if right else -20), 0, 100))


func _set_map_xy(v: bool) -> void:
	_set_flag("MapXy", v)


func _set_flag(sym: String, v: bool) -> void:
	if XConfig.flag(sym) == v:
		return
	XConfig.set_flag(sym, v)
	if sym == "codexPowerEnabled":
		XPower.clear_cache()  # installCombatPowerRuntime changeValue：开关变了清缓存
	XSound.system(0)
	_refresh()


## 未设置（null）也算不同：原版 changeValue 用 !== 比较
func _set_session(sym: String, v: bool) -> void:
	if XConfig.session_value(sym) == v:
		return
	XConfig.set_session(sym, v)
	XSound.system(0)
	_refresh()


func _follow_on() -> bool:
	return XState.current != null and XState.current.variable(24) == 0


func _set_follow(v: bool) -> void:
	if _follow_on() == v or XState.current == null:
		return
	XState.current.set_variable(24, 0 if v else 1)
	XState.current.followers_visible = v
	XSound.system(0)
	_refresh()


func _set_volume(sym: String, v: int) -> void:
	if XConfig.volume(sym) == v:
		return
	XConfig.set_volume(sym, v)
	XSound.system(0)
	_refresh()


func _set_speed(v: int) -> void:
	if XConfig.battle_speed() == v:
		return
	XConfig.set_battle_speed(v)
	XSound.system(0)
	_refresh()


func cancel() -> void:
	XSound.system(2)
	closed.emit()


func _open_hang_up() -> void:
	var page := XHangUpOptionsScene.new()
	page.map_shot = map_shot
	page.player_tile = player_tile
	_open_page(page)


func _open_page(page: Control) -> void:
	_page = page
	for node in get_children():
		if node is CanvasItem:
			node.hide()
	add_child(page)
	page.closed.connect(func():
		page.queue_free()
		_page = null
		for node in get_children():
			if node is CanvasItem and node != page:
				node.show()
		if not KEEP_INDEX_AFTER_PAGE:
			index = 0
			top = 0
		_refresh())


func _gui_input(event: InputEvent) -> void:
	if _page or not (event is InputEventMouseButton and event.pressed):
		return
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			var d := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			top = clampi(top + d, 0, maxi(0, _list.size() - ROWS))
			_refresh()
		MOUSE_BUTTON_LEFT:
			var p: Vector2 = event.position - RECT.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
			if not RECT.has_point(event.position) or p.y < 0 or p.y >= ROWS * LH:
				return
			var i := top + floori(p.y / LH)
			if i >= _list.size():
				return
			if i == index:
				ok()
			else:
				_select(i)


func _unhandled_input(event: InputEvent) -> void:
	if _page:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		var d := 1 if event.is_action_pressed("ui_down", true) else -1
		_select(XMenu._move(index, d, _list.size(), not event.is_echo()))
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_left", true):
		get_viewport().set_input_as_handled()
		_side(event.is_action_pressed("ui_right", true))
