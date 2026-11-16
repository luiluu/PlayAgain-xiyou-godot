class_name XSkinPartyStatusPanel
extends XPartyStatusPanel
## 【cc·天启篇·未经审查】新界面 2B：我方状态详情弹窗（盘点清册 #69；原版网页覆盖层 XWebPanel，换成新皮肤的三块排法）。
## 入口、打开时机、关掉后恢复都同 XPartyStatusPanel（XBattleScene._open_status，只在等指令时能开）；状态行的内容、筛选、排序全用
## XPartyStatusPanel.rows_for（同原版 stateRows），属性与元素承伤用 XPowerPanel 的同一份取数，只读。
## - 页名「某某 · 状态详情」＋说明「查看时暂停战斗，关闭后继续。」（原文）；右上「返回战斗」按钮。
## - 左块：队伍紧凑条（XSkinPartyStrip，点谁看谁，Q／E 换人）；中块：页签「异常 N／增益 N／常驻 N／全部 N」（← → 换）＋状态直列表
##   （名字后小字「类别 · 时长 · N层」，异常的名字橙色）；右块：选中状态的详情牌（图标、名字、类别时长层数、说明）＋「人物属性」一节。
## - 原版的搜索框没做（键盘、手柄、触屏都不好输字；状态一般十几条以内，页签够用）。
## - 打开时 request_wide（宽屏横向铺满），关掉自动还原。

const LEFT_W := 300.0
const RIGHT_W := 380.0
const TAB_H := 38.0
const SUBTITLE := "查看时暂停战斗，关闭后继续。"
const BACK_TEXT := "返回战斗"
const SECTION_ATTR := "人物属性"

var party: XSkinPartyStrip
var list: XSkinList
var state_card: XSkinCard
var hints: XSkinKeyHints
var back_btn: Button
var tab_row: Control
var tab_scale: XSkinSelScale
var _rows: Array = []


func _ready() -> void:
	if XUiSkin.on():
		add_to_group(XUiSkin.FULLSCREEN_GROUP)   # 收口批：新皮肤全屏页开着时收起虚拟摇杆／AB 键（小A核 P2-2）
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = XUiSkin.theme()
	XSkinLayout.request_wide(self)
	render()
	get_viewport().size_changed.connect(_relayout)


func view_size() -> Vector2:
	return get_viewport_rect().size


func render() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var a := actor()
	if a == null:
		close.call_deferred()
		return
	party = XSkinPartyStrip.new()
	party.selectable = true
	party.set_members(members.map(member_info))
	party.index = index
	party.index_changed.connect(func(i: int): _pick_actor(i))
	party.activated.connect(func(i: int): _pick_actor(i))
	add_child(party)
	tab_row = Control.new()
	tab_row.mouse_filter = Control.MOUSE_FILTER_STOP
	tab_row.draw.connect(_draw_tabs)
	tab_scale = XSkinSelScale.attach(tab_row)   # T040：分类页签选中放大
	tab_row.gui_input.connect(_tab_input)
	add_child(tab_row)
	list = XSkinList.new()
	list.row_height = XUiSkin.ROW_H
	list.index_changed.connect(func(_i: int): _fill_card())
	add_child(list)
	state_card = XSkinCard.new()
	add_child(state_card)
	hints = XSkinKeyHints.new()
	hints.set_hints([["↑ / ↓", "选状态"], ["← / →", "换分类"], ["Q / E", "换人"], ["取消", BACK_TEXT]])
	add_child(hints)
	back_btn = Button.new()
	back_btn.text = BACK_TEXT
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.add_theme_font_size_override("font_size", 17)
	var edge := StyleBoxFlat.new()
	edge.bg_color = Color(XUiSkin.BG, 0.6)
	edge.border_color = Color(XUiSkin.LINE, 0.55)
	edge.set_border_width_all(1)
	edge.set_corner_radius_all(18)
	edge.content_margin_left = 18
	edge.content_margin_right = 18
	back_btn.add_theme_stylebox_override("normal", edge)
	back_btn.pressed.connect(close)
	add_child(back_btn)
	_fill_list()
	_relayout()
	queue_redraw()


## 队伍条一行（读实时值；状态图标用 XSideStatus.cell_rows，同右侧条）
static func member_info(m: XBattler) -> Dictionary:
	var d: Dictionary = m.data() if m is XActor else {}
	var cls := str((m as XActor).class_data().get("name", "")) if m is XActor else ""
	return {"name": m.display_name(), "level": int(m.level) if "level" in m else 1, "cls": cls,
		"face": XUiSkin.face(str(d.get("faceName", "")), int(d.get("faceIndex", 0))) if not d.is_empty() else null,
		"hp": m.hp, "mhp": m.mhp, "mp": m.mp, "mmp": m.mmp, "tp": m.tp, "mtp": m.max_tp(),
		"states": XSideStatus.cell_rows(m).map(func(r): return int(r.icon))}


func _relayout() -> void:
	if party == null or not is_instance_valid(party):
		return
	var view := view_size()
	var d := XSkinLayout.compute(view, LEFT_W, RIGHT_W)
	var l: Rect2 = d.left
	var c: Rect2 = d.center
	var r: Rect2 = d.right
	party.position = l.position
	party.size = Vector2(l.size.x, party.custom_minimum_size.y)
	tab_row.position = c.position
	tab_row.size = Vector2(c.size.x, TAB_H)
	list.position = c.position + Vector2(0, TAB_H + 8.0)
	list.size = Vector2(c.size.x, c.size.y - TAB_H - 8.0)
	state_card.position = r.position
	state_card.size = r.size
	hints.place(view)
	back_btn.size = back_btn.get_combined_minimum_size()
	back_btn.position = Vector2(view.x - float(d.margin) - back_btn.size.x, 20.0)
	queue_redraw()


## 页签：[[类别, 显示的字]]
func tabs() -> Array:
	var out := []
	for t in TABS:
		var n := _rows.size() if t == "全部" else _rows.filter(func(row): return row.kind == t).size()
		out.append([t, "%s %d" % [t, n]])
	return out


func tab_rects() -> Array:
	var f := XUiSkin.font("body")
	var out := []
	var art := XSkinArt.select_on()   # 第一期正式美术：第一个往右 16、页签间 20，外置箭头不压前一个（小A核 P2-1）
	var x := 16.0 if art else 0.0
	for t in tabs():
		var w := f.get_string_size(t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 28.0
		out.append(Rect2(x, 0, w, TAB_H))
		x += w + (20.0 if art else 4.0)
	return out


func _draw_tabs() -> void:
	var f := XUiSkin.font("body")
	var ci := tab_row.get_canvas_item()
	var rects := tab_rects()
	var ts := tabs()
	tab_scale.sel(tab)
	for i in ts.size():
		var r: Rect2 = rects[i]
		var on: bool = ts[i][0] == tab
		if on:
			if XSkinArt.select_on():
				XSkinArt.draw_tab(ci, r)
			else:
				XUiSkin.draw_select(ci, r)
		var col := XUiSkin.TEXT if on else XUiSkin.TEXT_2
		var fit := XSkinList.fit_text(f, str(ts[i][1]), r.size.x - 8, XSkinSelScale.fs(17, tab_scale.k(ts[i][0]), floori(TAB_H * 0.66)), 14)
		var tw := f.get_string_size(fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1]).x
		tab_row.draw_string(f, Vector2(r.position.x + (r.size.x - tw) / 2.0, TAB_H / 2.0 + int(fit[1]) * 0.36), fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1], col)
	tab_row.draw_line(Vector2(0, TAB_H + 3), Vector2(tab_row.size.x, TAB_H + 3), Color(XUiSkin.LINE, 0.18), 1.0)


func _tab_input(event: InputEvent) -> void:
	var m := event as InputEventMouseButton
	if m == null or not m.pressed or m.button_index != MOUSE_BUTTON_LEFT:
		return
	var rects := tab_rects()
	for i in rects.size():
		if (rects[i] as Rect2).has_point(m.position):
			_set_tab(TABS[i])
			tab_row.accept_event()
			return


func _set_tab(t: String) -> void:
	if t == tab:
		return
	tab = t
	_fill_list()


func step_tab(d: int) -> void:
	_set_tab(TABS[posmod(TABS.find(tab) + d, TABS.size())])


func _pick_actor(i: int) -> void:
	if i == index or i < 0 or i >= members.size():
		return
	index = i
	if party.index != i:
		party.select(i)
	_fill_list()


func step_actor(d: int) -> void:
	if members.size() <= 1:
		return
	party.select(posmod(index + d, members.size()))   # 发 index_changed → _pick_actor


## 当前角色、当前页签的状态行（不用搜索框，query 恒空）
func _fill_list() -> void:
	var a := actor()
	_rows = rows_for(a) if a != null else []
	var shown := filtered()
	var items := []
	for row in shown:
		items.append({"text": str(row.name), "icon": int(row.icon), "sub": meta_text(row),
			"color": XUiSkin.DOWN if row.kind == "异常" else XUiSkin.TEXT})
	list.empty_text = "当前没有%s状态" % ("" if tab == "全部" else tab)   # 同首领详情的「当前没有异常状态」（核查文字必改）
	list.set_items(items)
	tab_row.queue_redraw()
	_fill_card()
	queue_redraw()


## 「类别 · 时长 · N 层」（同原卡片的说明行，数字和单位间空一格）
static func meta_text(row: Dictionary) -> String:
	return XSkinBossStatus.spaced("%s · %s" % [row.kind, row.duration] + (" · %d 层" % int(row.stack) if int(row.stack) > 1 else ""))


func _fill_card() -> void:
	var a := actor()
	if a == null:
		return
	var shown := filtered()
	var sections := []
	if a is XActor:
		sections.append({"title": SECTION_ATTR, "text": attr_text(a as XActor)})
	if shown.is_empty() or list.index < 0 or list.index >= shown.size():
		state_card.setup({"icon": null, "title": a.display_name(), "title_color": XUiSkin.TEXT, "subtitle": "", "desc": "", "sections": sections})
		return
	var row: Dictionary = shown[list.index]
	state_card.setup({"icon": XUiSkin.icon(int(row.icon)), "title": str(row.name), "title_color": XUiSkin.DOWN if row.kind == "异常" else XUiSkin.TEXT,
		"subtitle": meta_text(row), "desc": str(row.description), "sections": sections})


## 人物属性一节：元素属性＋各元素承伤（XPowerPanel 同一份取数，去掉开头「人物属性：」）。
## 承伤一项（「火焰承伤 90%」）不拆开：按牌的文字宽自己排行、行间用换行，免得在词中间折（核查返工）
static func attr_text(a: XActor, width := RIGHT_W - XUiSkin.PAD_LG * 2.0) -> String:
	var parts := XPowerPanel.attribute_parts(a).map(func(p): return str(p[0]))
	if not parts.is_empty() and str(parts[0]).begins_with("人物属性"):
		parts.remove_at(0)
	var res := XPowerPanel.resistance_parts(a).map(func(p): return str(p[0]))
	return "".join(PackedStringArray(parts)) + "\n" + "\n".join(PackedStringArray(pack_lines(res, width)))


## 一组组字排成行：放得下就用全角空格接在本行后面，放不下另起一行（字号同详情牌分节正文）
static func pack_lines(groups: Array, width: float, fs := XUiSkin.FS_AUX) -> Array:
	var f := XUiSkin.font("body")
	var lines := []
	var line := ""
	for g in groups:
		var t := str(g) if line == "" else line + "　" + str(g)
		if line != "" and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width - 2.0:
			lines.append(line)
			line = str(g)
		else:
			line = t
	if line != "":
		lines.append(line)
	return lines


func _draw() -> void:
	var view := view_size()
	draw_rect(Rect2(Vector2.ZERO, view), Color(XUiSkin.BG, 0.86))
	var a := actor()
	if a == null:
		return
	var m := XSkinLayout.margin_for(view.x)
	var tf := XUiSkin.font("title")
	draw_string(tf, Vector2(m, 14 + XUiSkin.FS_PAGE * 0.92), a.display_name() + " · 状态详情", HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_PAGE, XUiSkin.TEXT)
	var tw := tf.get_string_size(a.display_name() + " · 状态详情", HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_PAGE).x
	draw_string(XUiSkin.font("body"), Vector2(m + tw + 16, 14 + XUiSkin.FS_PAGE * 0.92), SUBTITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, XUiSkin.TEXT_2)
	XUiSkin.draw_panel(get_canvas_item(), Rect2(list.position - Vector2(8, TAB_H + 16), list.size + Vector2(16, TAB_H + 24)))


func _input(event: InputEvent) -> void:
	if XKeyMap.popup_cancel(event, self):
		XKeyMap.handled(self)
		close()
		return
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		step_tab(1 if event.is_action_pressed("ui_right", true) else -1)
		XKeyMap.handled(self)
		return
	var pd := XMenu.page_dir(event)
	if pd != 0:
		step_actor(pd)
		XKeyMap.handled(self)
		return
	if event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true):
		list.handle_input(event)
		XKeyMap.handled(self)
