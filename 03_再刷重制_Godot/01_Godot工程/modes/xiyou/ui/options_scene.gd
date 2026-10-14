class_name XOptionsScene
extends Control
## 主菜单「设置」：MV Scene_Options，按正式 v0.16 运行时复现（参照 04_验证/本地结果/原版参照/claude_options_00）。
## - 背景同主菜单（MOG_MenuBackground 底图＋粒子），窗口不透明度 30、背景 192。
## - Window_Options (440,130,400,460)：行高 36、字号 26、可见 12 行；名字左对齐在 itemRectForText (6,宽 360) 的前 240，
##   状态右对齐在内容 x 240、宽 120（statusWidth）。33 项与正式版同序；「挂机设置」只在挂机未禁用时出现（needAddHangUp）。
## - 已重制：坐标显示（MapXy，确定切换、右开左关）、挂机设置（确定音后打开 XHangUpOptionsScene）。
##   其余选项的机制还没做，暂时灰显、不显示状态，确定时蜂鸣；原版都可用（见 界面风格.md）。
## - 上下键：按住连续移动、首按可首尾循环，换行播光标音；取消（Esc/右键）播取消音返回主菜单。

signal closed

const RECT := Rect2(440, 130, 400, 460)
const LH := 36.0
const ROWS := 12
const STATUS_W := 120.0
## [名字, 符号, 已重制]（正式 v0.16 Window_Options._list 顺序）
const OPTIONS := [["坐标显示", "MapXy", true], ["挂机设置", "HangUp", true], ["始终跑步", "alwaysDash", false],
	["记住指令", "commandRemember", false], ["Battle Camera", "battleCamera", false], ["开启掉落动画", "MOG_TrPopUpBattle_Key", false],
	["战斗伤害记录", "CombatDamageRecordKey", false], ["显示伤害数字", "CombatDamageShow", false], ["显示技能动画", "CombatSkillAnimation", false],
	["屏蔽掉落", "pingbiDrop", false], ["智能战斗AI（自动战斗）", "codexSmartAI", false], ["BGM 音量", "bgmVolume", false],
	["BGS 音量", "bgsVolume", false], ["ME 音量", "meVolume", false], ["SE 音量", "seVolume", false], ["只遇稀有", "Boss", false],
	["只遇罕见", "BOSS", false], ["极其稀有", "boss", false], ["穿墙开关", "cq", false], ["此游戏为免费游戏！", "wxxonoff", false],
	["总群请加906327865！", "wxlonoff", false], ["不要在闲鱼买到这个版本！", "wxtonoff", false], ["战斗变速", "battleAniSpeed", false],
	["对话跳过", "dhtg", false], ["禁用遇敌", "ydgb", false], ["步步遇敌", "yd100", false], ["队列跟随", "codexFollow", false],
	["战力显示与估算", "codexPowerEnabled", false], ["测试模式", "codexTestMode", false], ["GM 工具", "codexGM", false],
	["角色换装", "codexCostumes", false], ["技能升级通告", "codexSkillLevelNotice", false], ["待提交反馈", "codexFeedbackPending", false]]

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
		"MapXy":
			return "ON" if XConfig.map_xy() else "OFF"
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
		"MapXy":
			_set_map_xy(not XConfig.map_xy())
		"HangUp":
			XSound.system(1)
			_open_hang_up()


## Window_Options.changeValue：值变了才存、重画并播光标音；HangUp 不改值
func _side(right: bool) -> void:
	if str(_list[index][1]) == "MapXy":
		_set_map_xy(right)


func _set_map_xy(v: bool) -> void:
	if XConfig.map_xy() == v:
		return
	XConfig.set_map_xy(v)
	XSound.system(0)
	_refresh()


func cancel() -> void:
	XSound.system(2)
	closed.emit()


func _open_hang_up() -> void:
	var page := XHangUpOptionsScene.new()
	page.map_shot = map_shot
	page.player_tile = player_tile
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
