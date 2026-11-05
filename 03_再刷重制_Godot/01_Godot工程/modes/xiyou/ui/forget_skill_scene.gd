class_name XForgetSkillScene
extends Control
## 技能遗忘（Star_ForgetSkills 的 Star_Scene_ForgetSkill；遗忘河之水 → 公共事件 83 Star.RunForgetSkill()），照冻结 v0.28 原版语义：
## - 角色是用物品时选中的那位（原版 Star.ForgetSkills.NewActor，取自物品选人窗）。
## - 打开时列出该角色已学技能（_skills，按编号）里技能类型 1、2、5 的；每行右侧「未遗忘／已遗忘」。
## - 确定：未遗忘的遗忘、已遗忘的重新学会，状态翻转，列表不变；取消关闭。
## 外观（ui14，原来借宽 760 的 XChoiceWindow、名字与状态拼成一行）照 Star_Window_ForgetSkill（Window_Command）：
## - Scene_MenuBase：菜单背景（MOG_MenuBackground＋粒子，同其它菜单页）。
## - 窗宽 400，高 fittingHeight(min(项数, 12))＝行数×36＋内边距×2，在 1280×720 正中；没有技能时只剩内边距那么高。
## - drawItem：itemRectForText（x 6、宽 内容宽−12）里名字左对齐、宽 内容宽−12−120；状态「未遗忘／已遗忘」右对齐，
##   x＝名字宽（原版没加 rect.x，所以比名字列起点少 6）、宽 120；普通色、不透明。
## - processOk 被整段覆写：不响确定音、不 deactivate，按住确定键会连续翻转（isOkTriggered＝isRepeated）。
##   列表空时原版读 GetSkills[0] 抛错；这里不动作。
## - 其余同 Window_Command：换行光标音、按下时首尾回绕、按住不回绕；Q／E（PageUp／PageDown）翻页、滚轮只滚窗口
##   （XMenu.LIST_PAGING）；取消音后关闭；点别的行先选中、点已选中的行＝确定；右键取消。
signal closed

const TYPES := [1, 2, 5]
const WIDTH := 400.0
const LH := 36.0
const MAX_ROWS := 12
const STATUS_W := 120.0
const TEXT_PAD := 6.0

var actor: XActor
var rows: Array = []
var index := 0
var top := 0
var win: XMVWindow


static func listed_skills(a: XActor) -> Array:
	return a.skill_ids.filter(func(id): return TYPES.has(int(XDB.rec("Skills", id).get("stypeId", 0))))


## Star_Window_ForgetSkill.windowHeight：fittingHeight(min(numVisibleRows, 12))
static func window_rect(n: int) -> Rect2:
	var h := mini(n, MAX_ROWS) * LH + XMVWindow.PADDING * 2
	return Rect2((1280.0 - WIDTH) / 2.0, (720.0 - h) / 2.0, WIDTH, h)


func setup(a: XActor) -> XForgetSkillScene:
	actor = a
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	rows = listed_skills(actor).map(func(id): return {"id": id, "kept": true})
	win = XMVWindow.make(self, window_rect(rows.size()), XUI.MENU_WINDOW_OPACITY, _paint)
	win.canvas.blink = true
	_refresh()


func page_rows() -> int:
	return mini(rows.size(), MAX_ROWS)


func _refresh() -> void:
	win.up_arrow = top > 0
	win.down_arrow = top + page_rows() < rows.size()
	win.refresh()


func _paint(c: XMVCanvas) -> void:
	var title_w := c.size.x - TEXT_PAD * 2 - STATUS_W
	for i in range(top, mini(rows.size(), top + page_rows())):
		var y := (i - top) * LH
		if i == index:
			c.cursor(Rect2(0, y, c.size.x, LH))
		var r: Dictionary = rows[i]
		c.text(str(XDB.rec("Skills", r.id).get("name", "")), TEXT_PAD, y, title_w, "left", XUI.TEXT, XUI.FONT_SIZE, LH)
		c.text("未遗忘" if r.kept else "已遗忘", title_w, y, STATUS_W, "right", XUI.TEXT, XUI.FONT_SIZE, LH)


func move(d: int, wrap: bool) -> void:
	if rows.is_empty():
		return
	var old := index
	index = XMenu._move(index, d, rows.size(), wrap)
	top = XMenu._scroll_to(index, top, page_rows())
	if index != old:
		XSound.system(0)
	_refresh()


func page(d: int) -> void:
	if rows.is_empty():
		return
	var old := index
	var r := XMenu.page(top, index, rows.size(), page_rows(), d)
	top = r[0]
	index = r[1]
	if index != old:
		XSound.system(0)
	_refresh()


## Star_Window_ForgetSkill.processOk（无声）
func ok() -> void:
	if index < 0 or index >= rows.size():
		return
	toggle(actor, rows[index])
	_refresh()


func cancel() -> void:
	XSound.system(2)
	closed.emit()


## processOk：未遗忘的遗忘、已遗忘的学会，再翻转
static func toggle(a: XActor, r: Dictionary) -> void:
	if r.kept:
		a.forget_skill(int(r.id))
	else:
		a.learn_skill(int(r.id))
	a.refresh_passive()
	r.kept = not r.kept


func _unhandled_input(event: InputEvent) -> void:
	var handled := true
	if event.is_action_pressed("ui_cancel"):
		cancel()
	elif event.is_action_pressed("ui_accept", true):
		ok()
	elif event.is_action_pressed("ui_down", true):
		move(1, not event.is_echo())
	elif event.is_action_pressed("ui_up", true):
		move(-1, not event.is_echo())
	elif XMenu.page_dir(event) != 0:
		page(XMenu.page_dir(event))
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	accept_event()
	var wd := XMenu.wheel_dir(event)
	if wd != 0:
		top = XMenu.wheel(top, rows.size(), page_rows(), wd)
		_refresh()
		return
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_LEFT:
			var p: Vector2 = event.position - win.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
			if p.x < 0 or p.y < 0 or p.x >= win.size.x - XMVWindow.PADDING * 2:
				return
			var row := floori(p.y / LH)
			var i := top + row
			if row < page_rows() and i < rows.size():
				if i == index:
					ok()
				else:
					index = i
					XSound.system(0)
					_refresh()
