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
## T304 卡 M：新界面开着时的版型三（XSkinSubPage）；关着为 null，旧页一行不变
var skin: XSkinSubPage
var _preview: Control
var _big: Control
var _black: ColorRect

## 卡 M 的开关：false＝挂机设置及四个子页回旧画法（天启篇存档里也回旧窗口）
static var SKIN_M := true
## 右牌范围预览：取以玩家为中心的 15×9 格（T254 3.8）
const PREV_COLS := 15
const PREV_ROWS := 9
const PREV_HEAD := 30.0
const BIG_SIZE := Vector2(854, 480)


static func skin_wanted() -> bool:
	return SKIN_M and XSkinSubPage.wanted()


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
	_black = black
	if skin_wanted():
		black.hide()   # 新版型用设置页的底图，不再垫模糊截图（T254 3.8）
		XUI.menu_background(self)
	elif map_shot:
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
	if skin_wanted():
		for w in [title_win, range_win] + item_wins:
			w.hide()
		skin = XSkinSubPage.attach(self)
		process_priority = 1   # 在 XSkinSubPage.sync 之后再摆预览、对右牌的底部预留
		_preview = Control.new()
		_preview.name = "RangePreview"
		_preview.mouse_filter = Control.MOUSE_FILTER_STOP
		_preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_preview.draw.connect(_draw_preview)
		_preview.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				show_big(true)
				_preview.accept_event())
		skin.card.add_child(_preview)
		_big = Control.new()
		_big.name = "RangeBig"
		_big.mouse_filter = Control.MOUSE_FILTER_STOP
		_big.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_big.draw.connect(_draw_big)
		_big.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed:
				show_big(false)
				_big.accept_event())
		_big.visible = false
		add_child(_big)


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
		return "进入" if XUiSkin.on() else "open"
	var v = settings().get(sym)
	if sym == "range":
		return str(int(v))
	if XUiSkin.on():
		return "是" if v else "否"
	return "YES" if v else "NO"


func _paint_title(c: XMVCanvas) -> void:
	var on := XUiSkin.on()
	c.clean_text = on
	c.font = XUiSkin.font("body") if on else XUI.font()
	c.text(words(SYMS[index])[1], 0, 0, c.size.x, "center", XUiSkin.TEXT if on else XUI.TEXT, XUI.FONT_SIZE, 44)


func _paint_item(c: XMVCanvas, i: int) -> void:
	var on := XUiSkin.on()
	c.clean_text = on
	c.font = XUiSkin.font("body") if on else XUI.font()
	if i == index:
		c.cursor(Rect2(0, 0, c.size.x, ITEM_LH))
	var rect_w := c.size.x - 12.0
	var status_w := c.size.x / 2.0
	var title_w := rect_w - status_w
	c.text(words(SYMS[i])[0], 6, 0, title_w, "left", XUiSkin.TEXT if on else XUI.TEXT, XUI.FONT_SIZE, ITEM_LH)
	c.text(status_text(i), title_w, 0, status_w, "right", XUiSkin.GOLD_LIGHT if on else XUI.TEXT, XUI.FONT_SIZE, ITEM_LH)


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
	if _preview != null:
		_preview.queue_redraw()


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
	_page.page_name = words(SYMS[index])[0]
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
		if skin != null:   # 新版型：旧窗口、大图照旧藏着
			for w in [title_win, range_win] + item_wins:
				w.hide()
			_big.visible = false
			_black.hide()
		_refresh())


func _gui_input(event: InputEvent) -> void:
	if skin != null:
		return   # 新版型的点击由列表自己接（XSkinSubPage）
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
	if skin != null and _skin_input(event):
		XKeyMap.handled(self)
		return
	if event.is_action_pressed("ui_cancel"):
		XKeyMap.handled(self)
		cancel()
	elif event.is_action_pressed("ui_accept"):
		XKeyMap.handled(self)
		ok()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		XKeyMap.handled(self)
		select(posmod(index + (1 if event.is_action_pressed("ui_down") else -1), SYMS.size()))
	elif event.is_action_pressed("ui_right", true):
		XKeyMap.handled(self)
		ok()
	elif event.is_action_pressed("ui_left", true):
		XKeyMap.handled(self)
		left()



# ---- T304 卡 M：新版型（XSkinSubPage 向这里要行和牌）----

func skin_self_hosted() -> bool:
	return skin_wanted()


func skin_name() -> String:
	return "挂机设置"


func skin_cat() -> String:
	return "hangup"


## 一列 13 行，顺序照旧；范围写数字，开关写「开」「关」，四个子页写「设置 ›」
func skin_rows() -> Array:
	var out := []
	for i in SYMS.size():
		var sym: String = SYMS[i]
		var r := {"text": words(sym)[0]}
		if sym in SUBPAGES:
			r["right"] = "设置 ›"
			r["right_color"] = XUiSkin.TEXT_2
		elif sym == "range":
			r["right"] = str(int(settings().range))
			r["right_color"] = XUiSkin.GOLD_LIGHT
		else:
			var on := _on(sym)
			r["right"] = "开" if on else "关"
			r["right_color"] = XSkinSubPage.on_color(on)
		out.append(r)
	return out


func _on(sym: String) -> bool:
	return true if settings().get(sym) else false


## 右牌：名字、现在的值、说明（旧顶上说明窗那一句）、可选、操作；「挂机范围」那一行底下多一块范围预览
func skin_card(i: int) -> Dictionary:
	var sym: String = SYMS[i]
	var w: Array = words(sym)
	var d := {"title": w[0], "desc": w[1]}
	if sym in SUBPAGES:
		d["subtitle"] = "子页"
		d["sections"] = [{"title": "操作", "text": "确定进入设置。"}]
	elif sym == "range":
		d["subtitle"] = "现在 %d 格" % int(settings().range)
		d["sections"] = [{"title": "操作", "text": "确定或 → 加一格，← 减一格（1～%d 循环）。按 Y 或点预览看整张图。" % max_range()}]
	else:
		var on := _on(sym)
		d["subtitle"] = "开" if on else "关"
		d["sections"] = [XSkinSubPage.choices_section(["开", "关"], 0 if on else 1),
			{"title": "操作", "text": "确定或左右切换。"}]
	return d


func skin_hints() -> Array:
	if _big != null and _big.visible:
		return [["取消", "收起"]]
	var sym: String = SYMS[index]
	if sym in SUBPAGES:
		return [["确定", "进入"], ["取消", "返回"]]
	if sym == "range":
		return [["确定", "加一格"], ["左右", "调整"], ["Y", "看大图"], ["取消", "返回"]]
	return [["确定", "切换"], ["左右", "开／关"], ["取消", "返回"]]


## 新版型多出来的键：大图开着时只认取消／Y（收起）；选中「挂机范围」时 Y 展开大图
func _skin_input(event: InputEvent) -> bool:
	if _big.visible:
		if event.is_action_pressed("ui_cancel") or XSkinCard._is_y(event) or event.is_action_pressed("ui_accept"):
			show_big(false)
			return true
		return not event is InputEventMouse   # 大图开着时别的键不穿到列表
	if SYMS[index] == "range" and XSkinCard._is_y(event):
		show_big(true)
		return true
	return false


func show_big(on: bool) -> void:
	if _big == null or _big.visible == on:
		return
	_big.visible = on
	if on:
		XSound.system(0)
		_big.queue_redraw()
	else:
		XSound.system(2)


func _process(_delta: float) -> void:
	if _preview == null:
		return
	var show_prev: bool = SYMS[index] == "range" and skin.card.visible
	_preview.visible = show_prev
	# 右牌给预览让出底部（模板页换牌时 _place_targets 会把它写回 0，所以本页排在子节点之后、每帧对一次）
	var want := preview_height() if show_prev else 0.0
	if not is_equal_approx(skin.card.reserve_bottom, want):
		skin.card.reserve_bottom = want
		skin.card.queue_redraw()
	if not show_prev:
		return
	var c := skin.card
	var w := c.size.x - c.pad * 2.0
	var r := Rect2(c.pad, c.size.y - c.pad - preview_height() + 8.0, w, preview_height() - 8.0)
	if _preview.position != r.position or _preview.size != r.size:
		_preview.position = r.position
		_preview.size = r.size
		_preview.queue_redraw()


## 预览块（含「范围预览」小标题）的高：右牌内宽按 15×9 方格铺满
func preview_height() -> float:
	if skin == null:
		return 0.0
	var w := skin.card.size.x - skin.card.pad * 2.0
	return PREV_HEAD + w / PREV_COLS * PREV_ROWS + 8.0


## 截图上一格多大（截图按打开菜单时的画面 1280×720 截，格子 48）
func _shot_tile() -> Vector2:
	if map_shot == null:
		return Vector2(TILE, TILE)
	return Vector2(TILE, TILE) * map_shot.get_size() / Vector2(1280, 720)


## 预览框（相对 _preview）
func preview_box() -> Rect2:
	return Rect2(0, PREV_HEAD, _preview.size.x, _preview.size.y - PREV_HEAD)


func _draw_preview() -> void:
	var body := XUiSkin.font("body")
	XUiSkin.ds(_preview, body, Vector2(0, XUiSkin.FS_AUX_MAX * 1.1), "范围预览", HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX_MAX, XUiSkin.GOLD)
	var box := preview_box()
	var t := box.size.x / PREV_COLS
	var org := Vector2(player_tile) - Vector2(floorf(PREV_COLS / 2.0), floorf(PREV_ROWS / 2.0))   # 窗口左上角是哪一格
	_preview.draw_rect(box, Color.BLACK)
	if map_shot != null:
		# 只取截图里落在窗口内的那一块（画面边上的格子外面留黑）
		var st := _shot_tile()
		var src := Rect2(org * st, Vector2(PREV_COLS, PREV_ROWS) * st).intersection(Rect2(Vector2.ZERO, map_shot.get_size()))
		if src.size.x > 0 and src.size.y > 0:
			var dst := Rect2(box.position + (src.position / st - org) * t, src.size / st * t)
			_preview.draw_texture_rect_region(map_shot, dst, src)
	_preview.draw_rect(box, Color(0, 0, 0, 0.45))
	var cells := {}
	for c in lattice():
		cells[c] = true
	var beyond := [false, false, false, false]   # 左右上下有超出窗口的范围格
	for c in cells:
		var g: Vector2 = Vector2(c) - org
		if g.x < 0:
			beyond[0] = true
		elif g.x >= PREV_COLS:
			beyond[1] = true
		if g.y < 0:
			beyond[2] = true
		elif g.y >= PREV_ROWS:
			beyond[3] = true
		if g.x < 0 or g.y < 0 or g.x >= PREV_COLS or g.y >= PREV_ROWS:
			continue
		var r := Rect2(box.position + g * t, Vector2(t, t)).grow(-1.0)
		_preview.draw_rect(r, Color(XUiSkin.GOLD, 0.22))
		_preview.draw_rect(r, Color(XUiSkin.GOLD, 0.9), false, 1.0)
	var pc := box.position + (Vector2(player_tile) - org + Vector2(0.5, 0.5)) * t
	_preview.draw_circle(pc, maxf(t * 0.22, 2.5), Color.WHITE)
	_draw_beyond(_preview, box, beyond)
	_preview.draw_rect(box, Color(XUiSkin.LINE, 0.3), false, 1.0)


## 范围超出窗口的那一边画一道「›」（朝外）
func _draw_beyond(ci: CanvasItem, box: Rect2, beyond: Array) -> void:
	var a := 7.0
	var col := XUiSkin.GOLD_LIGHT
	var mid := box.get_center()
	if beyond[0]:
		ci.draw_polyline([Vector2(box.position.x + 4 + a, mid.y - a), Vector2(box.position.x + 4, mid.y), Vector2(box.position.x + 4 + a, mid.y + a)], col, 2.0)
	if beyond[1]:
		ci.draw_polyline([Vector2(box.end.x - 4 - a, mid.y - a), Vector2(box.end.x - 4, mid.y), Vector2(box.end.x - 4 - a, mid.y + a)], col, 2.0)
	if beyond[2]:
		ci.draw_polyline([Vector2(mid.x - a, box.position.y + 4 + a), Vector2(mid.x, box.position.y + 4), Vector2(mid.x + a, box.position.y + 4 + a)], col, 2.0)
	if beyond[3]:
		ci.draw_polyline([Vector2(mid.x - a, box.end.y - 4 - a), Vector2(mid.x, box.end.y - 4), Vector2(mid.x + a, box.end.y - 4 - a)], col, 2.0)


## 大图的框（同旧版 854×480，画面比它小时等比缩）
func big_rect() -> Rect2:
	var vs := size
	var k := minf(1.0, minf((vs.x - 32.0) / BIG_SIZE.x, (vs.y - 32.0) / BIG_SIZE.y))
	var sz := BIG_SIZE * k
	return Rect2((vs - sz) / 2.0, sz)


## 大图：整屏压暗 66%，居中一张整幅地图（同旧版 854×480），范围格同预览的画法
func _draw_big() -> void:
	_big.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.66))
	var r := big_rect()
	var ci := _big.get_canvas_item()
	XUiSkin.panel_style().draw(ci, r)
	var inner := r.grow(-10.0)
	var k := inner.size / Vector2(1280, 720)
	if map_shot != null:
		_big.draw_texture_rect(map_shot, inner, false)
	_big.draw_rect(inner, Color(0, 0, 0, 0.45))
	for c in lattice():
		var cr := Rect2(inner.position + Vector2(c) * TILE * k, Vector2(TILE, TILE) * k).grow(-1.0)
		_big.draw_rect(cr, Color(XUiSkin.GOLD, 0.22))
		_big.draw_rect(cr, Color(XUiSkin.GOLD, 0.9), false, 1.0)
	_big.draw_circle(inner.position + (Vector2(player_tile) + Vector2(0.5, 0.5)) * TILE * k, maxf(TILE * k.x * 0.22, 2.5), Color.WHITE)
	var body := XUiSkin.font("body")
	var cap := "挂机范围 %d 格" % int(settings().range)
	var fs := XUiSkin.FS_AUX_MAX
	var cw := body.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pill := Rect2(inner.position + Vector2(10, 10), Vector2(cw + 24.0, fs + 14.0))
	_big.draw_rect(pill, Color(0, 0, 0, 0.72))   # 地图上的字垫深色底（底下可能是雪地）
	XUiSkin.ds(_big, body, Vector2(pill.position.x + 12.0, pill.position.y + 7.0 + fs * 0.86), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.GOLD)
