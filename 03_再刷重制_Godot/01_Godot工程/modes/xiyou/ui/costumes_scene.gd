class_name XCostumesScene
extends Control
## 设置「角色换装」：installCostumePreferencesRuntime 的 Scene_CodexCostumes（冻结 v0.28，按代码复现；开关规则见 XCostumes）。
## - 背景同主菜单，窗口不透明度同其他设置子页。
## - 标题窗 Window_Base (24,18,1232,120)：第 0 行字号 24「角色换装 · 点击角色切换启用／关闭」，y 36、66 两行字号 20 说明。
## - 列表 Window_CodexCostumes（Window_Command）：宽 min(980, 1232)，x 居中 150、y 150、高 720−174；可见 floor((720−210)/36)＝14 行。
##   每行（itemRectForText，左右内缩 6）：名字宽 min(240, 行宽×0.3)；学会的换装卡名用「、」连起来（没有写「未使用换装卡」），
##   systemColor、字号 20；最后 110 右对齐「启用」#a9dfb7／「关闭」normalColor。
## - 确定：确定音，切换该角色并重画该行；上下首按循环（Window_Command）；取消播取消音返回设置。

signal closed

const HEAD_RECT := Rect2(24, 18, 1232, 120)
const LIST_W := 980.0
const LIST_RECT := Rect2((1280 - LIST_W) / 2.0, 150, LIST_W, 720 - 174)
const LH := 36.0
const ROWS := 14                     # floor((720 - 210) / 36)
const TEXT_PADDING := 6.0
const STATUS_W := 110.0
const HINT_SIZE := 20
const ON_COLOR := Color("a9dfb7")
const TITLE := "角色换装 · 点击角色切换启用／关闭"
const NOTES := ["控制战斗中的换装卡外观；关闭后显示角色自身形态。", "卡片与属性加成保留，开关随当前存档保存。"]
const NO_CARD := "未使用换装卡"

var index := 0
var top := 0
var actors: Array = []
var head_win: XMVWindow
var list_win: XMVWindow
var list_pager: XListPager   # T050 翻页件（新界面关着时为 null）
## T300 卡 L：新界面开着时的设置子页版型（XSkinSubPage）；关着为 null，旧页一行不变
var skin: XSkinSubPage


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	actors = XCostumes.owned_actors(XState.current)
	head_win = XMVWindow.make(self, HEAD_RECT, XUI.MENU_WINDOW_OPACITY, _paint_head)
	list_win = XMVWindow.make(self, LIST_RECT, XUI.MENU_WINDOW_OPACITY, _paint_list)
	list_win.canvas.blink = true
	list_pager = XListPager.attach(list_win, page)
	if XSkinSubPage.wanted():
		head_win.hide()
		list_win.hide()
		skin = XSkinSubPage.attach(self)
	_refresh()


func _paint_head(c: XMVCanvas) -> void:
	c.text(TITLE, 0, 0, c.size.x, "left", XUI.TEXT, 24)
	c.text(NOTES[0], 0, 36, c.size.x, "left", XUI.TEXT, HINT_SIZE)
	c.text(NOTES[1], 0, 66, c.size.x, "left", XUI.TEXT, HINT_SIZE)


## drawItem 一行的文字（测试核对用）：[名字, 换装卡, 状态]
static func row_texts(a: XActor) -> Array:
	var names := XCostumes.cards(a).map(func(card): return str(card.name))
	var on := XCostumes.enabled(XState.current, a.actor_id)
	return [a.display_name(), "、".join(names) if not names.is_empty() else NO_CARD, "启用" if on else "关闭"]


func _paint_list(c: XMVCanvas) -> void:
	var w := c.size.x - TEXT_PADDING * 2
	var name_w := minf(240.0, w * 0.3)
	for i in range(top, mini(top + list_rows(), actors.size())):
		var y := (i - top) * LH
		if i == index:
			c.cursor(Rect2(0, y, c.size.x, LH))
		var t := row_texts(actors[i])
		c.text(t[0], TEXT_PADDING, y, name_w)
		c.text(t[1], TEXT_PADDING + name_w, y, w - name_w - STATUS_W, "left", XUI.SYSTEM, HINT_SIZE)
		c.text(t[2], TEXT_PADDING + w - STATUS_W, y, STATUS_W, "right", ON_COLOR if t[2] == "启用" else XUI.TEXT)


## T050：天启篇新界面开着且角色超一页时少放一行，给翻页件腾地方（见 XListPager.rows_for）
func list_rows() -> int:
	return XListPager.rows_for(ROWS, actors.size())


# ---- T300 新版型（XSkinSubPage 向这里要行和牌）----

func skin_self_hosted() -> bool:
	return XSkinSubPage.wanted()


func skin_name() -> String:
	return "角色换装"


func skin_cat() -> String:
	return "general"


func skin_empty() -> String:
	return "还没有可以换装的角色"


## 行：头像、名字、小字是换装卡名（放不下省略号，完整的在右牌里折行写全）、行尾启用（绿）／关闭
func skin_rows() -> Array:
	var out := []
	for a in actors:
		var t := row_texts(a)
		var d: Dictionary = a.data()
		out.append({"text": t[0], "sub": t[1], "right": t[2], "icon": XUiSkin.face(str(d.get("faceName", "")), int(d.get("faceIndex", 0))),
			"right_color": XUiSkin.UP if t[2] == "启用" else XUiSkin.TEXT_2})
	return out


func skin_card(i: int) -> Dictionary:
	var t := row_texts(actors[i])
	var on: bool = t[2] == "启用"
	return {"title": t[0], "subtitle": t[2], "desc": "学会的换装卡：%s" % t[1],
		"sections": [XSkinSubPage.choices_section(["启用", "关闭"], 0 if on else 1, -1),
			{"title": "说明", "text": "%s%s" % [NOTES[0], NOTES[1]]},
			{"title": "操作", "text": "确定切换启用／关闭。"}]}


func skin_hints() -> Array:
	return [["确定", "启用／关闭"], ["Q / E", "翻页"], ["取消", "返回"]]


func _refresh() -> void:
	list_win.up_arrow = top > 0
	list_win.down_arrow = top + list_rows() < actors.size()
	if list_pager != null:   # 有翻页件时它自己画页码，底边的下箭头不要
		list_pager.set_state(top, list_rows(), actors.size())
		list_win.down_arrow = list_win.down_arrow and not list_pager.visible
	list_win.refresh()


func select(i: int) -> void:
	if i == index:
		return
	index = i
	top = XMenu._scroll_to(index, top, list_rows())
	XSound.system(0)
	_refresh()


## Window_CodexCostumes（Window_Command）不接管 pageup／pagedown：照 cursorPagedown／cursorPageup 整页翻（ui11）
func page(d: int) -> void:
	var r := XMenu.page(top, index, actors.size(), list_rows(), d)
	top = r[0]
	if r[1] != index:
		index = r[1]
		XSound.system(0)
	_refresh()


## Scene_CodexCostumes.toggle
func ok() -> void:
	if actors.is_empty():
		return
	XSound.system(1)
	var a: XActor = actors[index]
	XCostumes.set_enabled(XState.current, a.actor_id, not XCostumes.enabled(XState.current, a.actor_id))
	_refresh()


func cancel() -> void:
	XSound.system(2)
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			if skin != null:
				return   # 新版型的滚动由列表自己接（XSkinSubPage）
			var d := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			top = clampi(top + d, 0, maxi(0, actors.size() - list_rows()))
			_refresh()
		MOUSE_BUTTON_LEFT:
			if skin != null:
				return   # 新版型的点击由列表自己接（XSkinSubPage）
			var p: Vector2 = event.position - LIST_RECT.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
			if not LIST_RECT.has_point(event.position) or p.y < 0 or p.y >= list_rows() * LH:
				return
			var i := top + floori(p.y / LH)
			if i >= actors.size():
				return
			if i == index:
				ok()
			else:
				select(i)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		XKeyMap.handled(self)
		cancel()
	elif event.is_action_pressed("ui_accept"):
		XKeyMap.handled(self)
		ok()
	elif not actors.is_empty() and (event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true)):
		XKeyMap.handled(self)
		var d := 1 if event.is_action_pressed("ui_down", true) else -1
		select(XMenu._move(index, d, actors.size(), not event.is_echo()))
	elif not actors.is_empty() and XMenu.page_dir(event) != 0:
		XKeyMap.handled(self)
		page(XMenu.page_dir(event))
