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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	actors = XCostumes.owned_actors(XState.current)
	head_win = XMVWindow.make(self, HEAD_RECT, XUI.MENU_WINDOW_OPACITY, _paint_head)
	list_win = XMVWindow.make(self, LIST_RECT, XUI.MENU_WINDOW_OPACITY, _paint_list)
	list_win.canvas.blink = true
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
	for i in range(top, mini(top + ROWS, actors.size())):
		var y := (i - top) * LH
		if i == index:
			c.cursor(Rect2(0, y, c.size.x, LH))
		var t := row_texts(actors[i])
		c.text(t[0], TEXT_PADDING, y, name_w)
		c.text(t[1], TEXT_PADDING + name_w, y, w - name_w - STATUS_W, "left", XUI.SYSTEM, HINT_SIZE)
		c.text(t[2], TEXT_PADDING + w - STATUS_W, y, STATUS_W, "right", ON_COLOR if t[2] == "启用" else XUI.TEXT)


func _refresh() -> void:
	list_win.up_arrow = top > 0
	list_win.down_arrow = top + ROWS < actors.size()
	list_win.refresh()


func select(i: int) -> void:
	if i == index:
		return
	index = i
	top = XMenu._scroll_to(index, top, ROWS)
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
			var d := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			top = clampi(top + d, 0, maxi(0, actors.size() - ROWS))
			_refresh()
		MOUSE_BUTTON_LEFT:
			var p: Vector2 = event.position - LIST_RECT.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
			if not LIST_RECT.has_point(event.position) or p.y < 0 or p.y >= ROWS * LH:
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
		get_viewport().set_input_as_handled()
		cancel()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		ok()
	elif not actors.is_empty() and (event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true)):
		get_viewport().set_input_as_handled()
		var d := 1 if event.is_action_pressed("ui_down", true) else -1
		select(XMenu._move(index, d, actors.size(), not event.is_echo()))
