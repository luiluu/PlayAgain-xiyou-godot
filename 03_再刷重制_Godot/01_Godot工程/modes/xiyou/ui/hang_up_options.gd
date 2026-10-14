class_name XHangUpOptionsScene
extends Control
## 挂机设置：XdRs_HangUp 的 Scene_HangUpOptions，按正式 v0.16 运行时复现（参照 原版参照/claude_hangup_options_00）。
## - 背景：打开菜单时的地图截图按 MV Bitmap.blur 模糊（SceneManager.backgroundBitmap）；窗口为普通不透明度（背景 192）。
## - 说明窗 Window_HuTitle (0,0,1280,64)：内边距 10、行高 44，当前项说明白字居中。
## - 13 个 Window_HuList（每项一个窗口，宽 1280/3、显示宽 427，高 68 = 行高 48＋内边距 10×2）：
##   第 0～7 项在左列 y = 64＋68i；技能次数/技能顺序在第 7 行的中/右列，自动吃药/自动卖出/屏蔽掉落占第 8 行三列。
##   名字左对齐在 (6, 宽 191.5)，状态右对齐在 x 191.5、宽 203.5（内容宽一半）：范围写数字，开关 YES/NO，四个子页写 open。
## - 范围图 Window_HuRange (426⅔,64,853⅓→854,480)：内边距 10，把截图与范围格位图一起缩放到 834×460；
##   范围格：画面 26×15 格中与玩家所在格曼哈顿距离 ≤ 范围的格（玩家格除外），各画 46×46 的 rgba(255,0,200,0.5)。
##   O-018：原版 snapForHangUp 排在 Scene_Map.terminate 移除地图精灵之后，截到的只有 HUD 小图（其余透明），
##   范围图实际是窗口底色上的格子；这里画打开菜单时的地图截图（未模糊）。RANGE_MAP_PREVIEW 设 false 只画格子。
## - 操作（HuList＋活动窗口）：上下键只认首按、首尾循环，换项播光标音；确定/右键头＝范围 +1（20 后回 1）或开关取反，
##   左键头＝范围 −1（1 后到 20）或开关取反；值变了播光标音。点非活动窗口即选中它，点活动窗口的项＝确定；
##   取消（Esc/右键）播取消音返回设置。
## - 四个子页在 XHangUpSubPage；打开时先切换同名字段并播光标音（原版 processOk）。
## - 「自动储存」说明里的档位按 O-017 写开局选的存档位（原版写参数 saveId，空时为 1）。

signal closed

const SYMS := ["range", "showInter", "fastFt", "deathStop", "autoSave", "RareEscape", "UnprecedentedEscape",
	"CommonEscape", "SetSkilllist", "SetSkillNum", "AutomaticMedication", "AutomaticSellWeapon", "DropShield"]
const SUBPAGES := ["SetSkilllist", "SetSkillNum", "AutomaticMedication", "AutomaticSellWeapon"]
const TITLE_RECT := Rect2(0, 0, 1280, 64)
const ITEM_LH := 48.0
const ITEM_H := 68.0                  # ITEM_LH + 内边距 10×2
const PAD := 10.0
const LIST_W := 1280.0 / 3.0
const RANGE_RECT := Rect2(1280.0 / 3.0, 64, 854, 480)
const TILE := 48.0
const RANGE_COLOR := Color(1.0, 0.0, 200.0 / 255.0, 0.5)
## O-018：范围图垫地图截图（原版截图时地图已移除，只剩 HUD）
const RANGE_MAP_PREVIEW := true

var map_shot: Texture2D
var player_tile := Vector2.ZERO
var index := 0
var title_win: XMVWindow
var range_win: XMVWindow
var item_wins: Array = []
var _page: XHangUpSubPage


## HuList.createAllList 的窗口位置
static func item_rect(i: int) -> Rect2:
	var p := Vector2(0, i * ITEM_H + 64)
	match i:
		8: p = Vector2(LIST_W, 7 * ITEM_H + 64)
		9: p = Vector2(LIST_W * 2, 7 * ITEM_H + 64)
		10: p = Vector2(0, 8 * ITEM_H + 64)
		11: p = Vector2(LIST_W, 8 * ITEM_H + 64)
		12: p = Vector2(LIST_W * 2, 8 * ITEM_H + 64)
	return Rect2(p, Vector2(427, ITEM_H))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	if map_shot:
		add_child(XUI.blurred_background(map_shot))
	title_win = XMVWindow.make(self, TITLE_RECT, 255, _paint_title)
	title_win.padding = PAD
	for i in SYMS.size():
		var w := XMVWindow.make(self, item_rect(i), 255, _paint_item.bind(i))
		w.padding = PAD
		w.canvas.blink = true
		item_wins.append(w)
	range_win = XMVWindow.make(self, RANGE_RECT, 255, _paint_range)
	range_win.padding = PAD
	range_win.canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func settings() -> Dictionary:
	return XHangUp.settings(XState.current)


## Window_HuList.initWord：参数 WD<符号>「选项名:说明」
static func words(sym: String) -> Array:
	var parts := str(XHangUp.params().get("WD" + sym, "")).split(":")
	var name := parts[0] if parts.size() > 0 else ""
	var desc := parts[1] if parts.size() > 1 else ""
	if sym == "autoSave":
		desc = desc.replace("\\f", str(XHangUp.auto_save_slot(XState.current)))
	return [name, desc]


func status_text(i: int) -> String:
	var sym: String = SYMS[i]
	if sym in SUBPAGES:
		return "open"
	var v = settings().get(sym)
	return str(int(v)) if sym == "range" else ("YES" if v else "NO")


func _paint_title(c: XMVCanvas) -> void:
	c.text(words(SYMS[index])[1], 0, 0, c.size.x, "center", XUI.TEXT, XUI.FONT_SIZE, 44)


func _paint_item(c: XMVCanvas, i: int) -> void:
	if i == index:
		c.cursor(Rect2(0, 0, c.size.x, ITEM_LH))
	var rect_w := c.size.x - 12.0
	var status_w := c.size.x / 2.0
	var title_w := rect_w - status_w
	c.text(words(SYMS[i])[0], 6, 0, title_w, "left", XUI.TEXT, XUI.FONT_SIZE, ITEM_LH)
	c.text(status_text(i), title_w, 0, status_w, "right", XUI.TEXT, XUI.FONT_SIZE, ITEM_LH)


## 范围格（XdRsData.hangUp.drawLattice）：画面格坐标，玩家格除外
func lattice() -> Array:
	var out := []
	var r := int(settings().range)
	for i in range(floori(1280 / TILE)):
		for j in range(floori(720 / TILE)):
			if Vector2(i, j) == player_tile:
				continue
			if absf(i - player_tile.x) + absf(j - player_tile.y) <= r:
				out.append(Vector2i(i, j))
	return out


func _paint_range(c: XMVCanvas) -> void:
	var k := c.size / Vector2(1280, 720)
	if map_shot and RANGE_MAP_PREVIEW:
		c.draw_texture_rect(map_shot, Rect2(Vector2.ZERO, c.size), false)
	for t in lattice():
		c.draw_rect(Rect2(Vector2(t) * TILE * k, Vector2(TILE - 2, TILE - 2) * k), RANGE_COLOR)


func _refresh() -> void:
	for w in [title_win, range_win] + item_wins:
		w.refresh()


# ---- 操作 ----
func select(i: int) -> void:
	if i == index:
		return
	index = i
	XSound.system(0)
	_refresh()


func _change(sym: String, v) -> void:
	var s := settings()
	if s.get(sym) == v:
		return
	s[sym] = v
	XSound.system(0)
	_refresh()


## Window_HuList.processOk / cursorRight
func ok() -> void:
	var sym: String = SYMS[index]
	if sym in SUBPAGES:
		_change(sym, not bool(settings().get(sym, false)))
		_open_subpage({"SetSkilllist": "actors_count", "SetSkillNum": "actors_order",
			"AutomaticMedication": "medication", "AutomaticSellWeapon": "sell"}[sym])
	elif sym == "range":
		_change(sym, posmod(int(settings().range), max_range()) + 1)
	else:
		_change(sym, not bool(settings()[sym]))


## Window_HuList.cursorLeft
func left() -> void:
	var sym: String = SYMS[index]
	if sym in SUBPAGES:
		_change(sym, not bool(settings().get(sym, false)))
	elif sym == "range":
		_change(sym, posmod(int(settings().range) - 2, max_range()) + 1)
	else:
		_change(sym, not bool(settings()[sym]))


static func max_range() -> int:
	var v := str(XHangUp.params().get("maxRange", ""))
	return int(v) if v.is_valid_int() and int(v) > 0 else 20


func cancel() -> void:
	XSound.system(2)
	closed.emit()


func _open_subpage(kind: String) -> void:
	_page = XHangUpSubPage.new().setup(kind)
	for node in get_children():
		if node is CanvasItem:
			node.hide()
	add_child(_page)
	_page.closed.connect(func():
		var page := _page
		_page = null
		page.queue_free()
		for node in get_children():
			if node is CanvasItem and node != page:
				node.show()
		_refresh())


func _gui_input(event: InputEvent) -> void:
	if _page or not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		# 先由活动窗口处理（点中项＝确定），再由 HuList 按窗口框换选中项
		var inner := item_rect(index).grow(-PAD)
		inner.size.y = ITEM_LH
		if inner.has_point(p):
			ok()
			return
		for i in SYMS.size():
			if item_rect(i).has_point(p):
				select(i)
				return


func _unhandled_input(event: InputEvent) -> void:
	if _page:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		ok()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		select(posmod(index + (1 if event.is_action_pressed("ui_down") else -1), SYMS.size()))
	elif event.is_action_pressed("ui_right", true):
		get_viewport().set_input_as_handled()
		ok()
	elif event.is_action_pressed("ui_left", true):
		get_viewport().set_input_as_handled()
		left()
