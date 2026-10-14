class_name XHangUpSubPage
extends Control
## 挂机设置的子页（XdRs_HangUp 的 Star_Scene_* 八个 Scene_MenuBase），按正式 v0.17 运行时复现
## （参照 原版参照/claude_hu_actor_00、_counts_00、_order_00、_med_00、_hpitems_00、_sell_00）。数据与规则在 XHangUpAuto。
## - 底图同主菜单，一个 Window_Command：宽 400、高按行数（最多 12 行）fittingHeight、画面居中，不透明度 30、行高 36；
##   名字左对齐在 (6, 宽 240)，状态右对齐在 (240, 宽 120)；选人页只写名字。
## - kind：actors_count/actors_order（出战成员）→ counts（技能次数）/ order（技能顺序）；medication（自动吃药）→ hp/mp（药品开关）；sell（自动卖出）。
## - 确定都是各页自己的处理，不播确定音（原版覆盖了 processOk）；只有卖出页的七档切换播确定音。上下移动播光标音，取消播取消音。
##   技能次数页 →/← 加减（0～20 循环），顺序页 → 与确定一样把该项提前一位；没有内容的页一打开就退回（药品页另提示「没药了」）。

signal closed

const W := 400.0
const LH := 36.0
const MAX_ROWS := 12
const STATUS_W := 120.0

var kind := ""
var actor: XActor
var index := 0
var top := 0
var win: XMVWindow
var _logic: XBattleLogic
var _skills: Array = []
var _order := {}
var _potions: Array = []
var _child: Control


func setup(k: String, a: XActor = null) -> XHangUpSubPage:
	kind = k
	actor = a
	return self


func _s() -> XState:
	return XState.current


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_logic = XBattleLogic.new()
	_logic.state = _s()
	_load()
	XUI.menu_background(self)
	var n := mini(rows().size(), MAX_ROWS)
	var h := n * LH + XMVWindow.PADDING * 2
	win = XMVWindow.make(self, Rect2((1280 - W) / 2.0, (720 - h) / 2.0, W, h), XUI.MENU_WINDOW_OPACITY, _paint)
	win.canvas.blink = true
	_refresh()
	if rows().is_empty():
		if kind in ["hp", "mp"]:
			XToast.show_text("没药了")
		closed.emit.call_deferred()


func _load() -> void:
	var s := _s()
	match kind:
		"counts":
			_skills = XHangUpAuto.bet_skills(_logic, actor)
			XHangUpAuto.counts(s, actor, _skills)
		"order":
			_order = XHangUpAuto.order_list(s, actor, XHangUpAuto.bet_skills(_logic, actor))
		"medication":
			XHangUpAuto.open_medication(s)
		"hp", "mp":
			_potions = XHangUpAuto.potion_list(s, kind == "mp")
			XHangUpAuto.rebuild_potions(s, kind == "mp", _potions)
		"sell":
			XHangUpAuto.sell_config(s)


## [名字, 状态] 各行
func rows() -> Array:
	var s := _s()
	match kind:
		"actors_count", "actors_order":
			return XHangUpAuto.actors(s).map(func(a): return [a.display_name(), ""])
		"counts":
			var n := XHangUpAuto.counts(s, actor, _skills)
			var out := []
			for i in _skills.size():
				out.append([str(_skills[i].name), str(n[i])])
			return out
		"order":
			var out := []
			for i in _order.skills.size():
				out.append([str(_order.skills[i].skill.name), str(_order.order[i])])
			return out
		"medication":
			var r := XHangUpAuto.recovery(s)
			return [["Hp恢复开关", "Open"], ["Mp恢复开关", "Open"], ["Hp恢复比例", str(r.HpV)], ["Mp恢复比例", str(r.MpV)]]
		"hp", "mp":
			return _potions.map(func(e): return ["%s 剩余:%d" % [XDB.rec("Items", int(e.id)).get("name", ""), int(e.num)],
				"ON" if XHangUpAuto.potion_on(s, kind == "mp", int(e.id)) else "OFF"])
		"sell":
			var out := [["卖出的回合(为0不卖出)", str(int(XHangUpAuto.sell_config(s).SellQuality))]]
			var names: Array = XQuality.config().names
			for g in names.size():
				out.append([str(names[g]), {"none": "不卖", "all": "卖", "partial": "部分"}[XHangUpAuto.grade_state(s, g)]])
			return out
	return []


func _refresh() -> void:
	var n := rows().size()
	win.up_arrow = top > 0
	win.down_arrow = top < n - MAX_ROWS
	win.refresh()


func _paint(c: XMVCanvas) -> void:
	var list := rows()
	var title_w := c.size.x - 12.0 - STATUS_W
	for i in range(top, mini(top + MAX_ROWS, list.size())):
		var y := (i - top) * LH
		if i == index:
			c.cursor(Rect2(0, y, c.size.x, LH))
		c.text(list[i][0], 6, y, title_w, "left", XUI.TEXT, XUI.FONT_SIZE, LH)
		c.text(list[i][1], title_w, y, STATUS_W, "right", XUI.TEXT, XUI.FONT_SIZE, LH)


# ---- 操作 ----
func select(i: int) -> void:
	if i == index:
		return
	index = i
	if index < top:
		top = index
	elif index >= top + MAX_ROWS:
		top = index - MAX_ROWS + 1
	XSound.system(0)
	_refresh()


func ok() -> void:
	var s := _s()
	if index < 0 or index >= rows().size():
		return
	match kind:
		"actors_count", "actors_order":
			_open(XHangUpSubPage.new().setup("counts" if kind == "actors_count" else "order", XHangUpAuto.actors(s)[index]))
		"counts":
			XHangUpAuto.change_count(s, actor, _skills[index], true)
		"order":
			XHangUpAuto.move_earlier(s, _order, index)
		"medication":
			match index:
				0: _open(XHangUpSubPage.new().setup("hp"))
				1: _open(XHangUpSubPage.new().setup("mp"))
				2: XHangUpAuto.change_rate(s, "HpV")
				3: XHangUpAuto.change_rate(s, "MpV")
		"hp", "mp":
			XHangUpAuto.toggle_potion(s, kind == "mp", _potions, index)
		"sell":
			if index == 0:
				XHangUpAuto.change_sell_every(s)
			else:
				XHangUpAuto.toggle_grade(s, index - 1)
				XSound.system(1)
	_refresh()


## Star_Window_AutomaticCombatSkills/Skill.update：→ 与 ← 按住连续（只有这两页）
func side(right: bool) -> void:
	if rows().is_empty():
		return
	match kind:
		"counts":
			XHangUpAuto.change_count(_s(), actor, _skills[index], right)
		"order":
			if right:
				XHangUpAuto.move_earlier(_s(), _order, index)
		_:
			return
	_refresh()


func cancel() -> void:
	XSound.system(2)
	closed.emit()


func _open(page: XHangUpSubPage) -> void:
	_child = page
	for node in get_children():
		if node is CanvasItem:
			node.hide()
	add_child(page)
	page.closed.connect(func():
		page.queue_free()
		_child = null
		_load()
		for node in get_children():
			if node is CanvasItem and node != page:
				node.show()
		_refresh())


func _gui_input(event: InputEvent) -> void:
	if _child or not (event is InputEventMouseButton and event.pressed):
		return
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			top = clampi(top + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, rows().size() - MAX_ROWS))
			_refresh()
		MOUSE_BUTTON_LEFT:
			var p: Vector2 = event.position - win.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
			if not Rect2(win.position, win.size).has_point(event.position) or p.y < 0 or p.y >= MAX_ROWS * LH:
				return
			var i := top + floori(p.y / LH)
			if i >= rows().size():
				return
			if i == index:
				ok()
			else:
				select(i)


func _unhandled_input(event: InputEvent) -> void:
	if _child:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		var n := rows().size()
		if n > 0:
			select(XMenu._move(index, 1 if event.is_action_pressed("ui_down", true) else -1, n, not event.is_echo()))
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_left", true):
		get_viewport().set_input_as_handled()
		side(event.is_action_pressed("ui_right", true))
