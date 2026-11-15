class_name XSkinMainMenu
extends Control
## 【cc·天启篇·未经审查】新界面第 1A 批：主菜单（盘点清册 #21；界面风格提案 v0.7 样稿 menu、README 第一节「主菜单」）。
## 只在 XUiSkin.on() 时由 XMenu._ready 建（XMenu.skin）；关着时 XMenu 走旧三个窗口，这个文件一行不跑。
## 布局（XSkinLayout 三块，横屏铺满）：
## - 左块：环形导航（XSkinRingNav），一组一个球（XUiSkin.GROUPS 里当前存档看得到的组，天启篇 6 组），环心是当前角色的圆头像；
## - 中块：分组子项列表——没选中的组收成一行（组名＋子项名），选中的组展开：组名（旧金）＋每个子项一行（行高 56、名字＋一句话说明）；
##   只剩一项的组（物品、装备）不展开，组那一行就是子项，确定直接进；
## - 右块：本局条（第几层 · 难度 · 哪条线；七印进度：首通几印）＋队伍条（XSkinPartyStrip）；
## - 顶上：页名「菜单」、货币（精魂；能进七印祭坛的档另显示印屑）；右下：按键提示（给右下角版本号让位）。
## 操作：上下在子项间走（到组头尾跨到上／下一组）；左右或 Q／E 换组；确定进入；取消回地图。
## 技能、装备、状态先到队伍条选人（XMenu._mode＝"actor"），确定进页、取消回列表。
## 打开各页、可不可用都走 XMenu（run_command／open_actor_page／symbol_enabled），和旧菜单是同一套。

const TITLE := "菜单"
const ROW_GROUP := 46.0      # 收起的组一行
const ROW_HEADER := 46.0     # 展开组的组名行
const ROW_ITEM := float(XUiSkin.ROW_H_MENU)   # 子项 56
const LEFT_W := 416.0
const RIGHT_W := 360.0
const RUN_H := 96.0          # 本局条（有七印行）
const RUN_H_SHORT := 60.0    # 本局条（没有七印行）
const SEALS := 7
const ACTOR_CMDS := ["skill", "equip", "status"]

var host: XMenu
var layout: XSkinLayout
var ring: XSkinRingNav
var face: Control
var pane: Panel
var bar: XSkinSelectBar
var text_layer: Control
var run_panel: Control
var party: XSkinPartyStrip
var hints: XSkinKeyHints
var top: Control
var groups: Array = []
## 当前组、组里第几项
var gi := 0
var ii := 0
var party_top := 0
var _rows: Array = []
var _wide_token: Node


func _ready() -> void:
	name = "SkinMainMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = XUiSkin.theme()
	layout = XSkinLayout.new()
	layout.left_w = LEFT_W
	layout.right_w = RIGHT_W
	add_child(layout)
	groups = XUiSkin.visible_groups(XUiSkin.GROUPS, _state())
	# 左块：环
	ring = XSkinRingNav.new()
	ring.radius = 160
	ring.orb_radius = 33
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.set_items(groups.map(func(g): return {"key": g.key, "name": g.name, "icon": int(g.get("icon", 0))}))
	layout.left.add_child(ring)
	face = Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.draw.connect(_draw_face)
	ring.add_child(face)
	ring.changed.connect(_on_ring_changed)
	ring.activated.connect(func(_i):
		if host != null and host._mode == "command":
			activate())
	# 中块：分组子项
	pane = Panel.new()
	pane.name = "Groups"
	pane.mouse_filter = Control.MOUSE_FILTER_STOP
	pane.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.center.add_child(pane)
	bar = XSkinSelectBar.new()
	pane.add_child(bar)
	text_layer = Control.new()   # 文字在选中条上面（选中条的底光不压字）
	text_layer.name = "Text"
	text_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pane.add_child(text_layer)
	text_layer.draw.connect(_draw_pane)
	pane.gui_input.connect(_pane_input)
	pane.resized.connect(func(): _place_bar(true))
	# 右块：本局条＋队伍条
	run_panel = Control.new()
	run_panel.name = "Run"
	run_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	run_panel.draw.connect(_draw_run)
	layout.right.add_child(run_panel)
	party = XSkinPartyStrip.new()
	party.title = "队伍"
	layout.right.add_child(party)
	party.activated.connect(_on_party_activated)
	party.index_changed.connect(_on_party_index)
	# 顶上、右下
	top = Control.new()
	top.name = "Top"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.draw.connect(_draw_top)
	add_child(top)
	hints = XSkinKeyHints.new()
	add_child(hints)
	resized.connect(_place)
	get_viewport().size_changed.connect(_place)
	visibility_changed.connect(_sync_wide)
	_sync_wide()
	refresh()


func _state() -> XState:
	return XState.current


## 页面在显示时让窗口横向铺满（XSkinLayout.request_wide）；进子页（旧布局，按 1280×720 排）时还原
func _sync_wide() -> void:
	if is_visible_in_tree() and is_inside_tree():
		if _wide_token == null:
			_wide_token = Node.new()
			_wide_token.name = "WideToken"
			add_child(_wide_token)
			XSkinLayout.request_wide(_wide_token)
	elif _wide_token != null:
		_wide_token.queue_free()
		remove_child(_wide_token)
		_wide_token = null


## ---- 数据 ----

func current_group() -> Dictionary:
	return groups[gi] if gi >= 0 and gi < groups.size() else {}


func group_items(g: Dictionary) -> Array:
	return g.get("items", [])


func current_item() -> Dictionary:
	var items := group_items(current_group())
	return items[ii] if ii >= 0 and ii < items.size() else {}


func item_enabled(it: Dictionary) -> bool:
	return host != null and host.symbol_enabled(str(it.get("cmd", "")))


## 本局条第一行：第几层 · 难度 · 哪条线（天启篇存档才有难度和线；变量 20＝现在要打的层）
static func run_text(s: XState) -> String:
	if s == null:
		return ""
	var parts := ["第 %d 层" % maxi(1, int(s.variable(20)))]
	var d := XTianqi.difficulty_of(s)
	if not d.is_empty():
		parts.append(str(d.name))
	var line := XTianqi.line_info(XTianqi.line_of(s))
	if not line.is_empty():
		parts.append(str(line.name) + "线")
	return " · ".join(parts)


## 七印进度：每印 2＝首通过 Boss、1＝揭开了没打过、0＝没揭开（按祭坛的印序）；不能进祭坛的档返回 []
static func seal_states(s: XState) -> Array:
	if s == null or not XTianqiQiyin.allowed(s):
		return []
	var cleared: Dictionary = XTianqiQiyin.progress(s).drop.get("first_clear", {})
	var out := []
	for k in XTianqiQiyin.seal_keys():
		out.append(2 if bool(cleared.get(k, false)) else (1 if XTianqiQiyin.unlocked(s, k) else 0))
	return out


static func seals_cleared(states: Array) -> int:
	return states.count(2)


## 货币：[[名字, 数值文字]]；精魂一直有，印屑只在能进七印祭坛的档
static func currencies(s: XState) -> Array:
	if s == null:
		return []
	var out := [["精魂", XMenu._group(s.gold)]]
	if XTianqiQiyin.allowed(s):
		out.append([str(XTianqiQiyin.data().get("shards_name", "印屑")), XMenu._group(XTianqiQiyin.shards(s))])
	return out


## ---- 刷新与摆放 ----

func refresh() -> void:
	if host == null:
		return
	gi = clampi(gi, 0, maxi(groups.size() - 1, 0))
	ii = clampi(ii, 0, maxi(group_items(current_group()).size() - 1, 0))
	if ring.index != gi:
		ring.select(gi, false)
	var members := host._members()
	var actor_mode := host._mode == "actor"
	party.selectable = actor_mode
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE if actor_mode else Control.MOUSE_FILTER_STOP
	var rows := party_rows()
	if actor_mode:
		var ai := clampi(host._actor_index, 0, maxi(members.size() - 1, 0))
		if ai < party_top:
			party_top = ai
		elif ai >= party_top + rows:
			party_top = ai - rows + 1
	party_top = clampi(party_top, 0, maxi(members.size() - rows, 0))
	party.set_members(members.slice(party_top, party_top + rows).map(func(a): return XSkinPartyStrip.from_actor(a)))
	party.index = (host._actor_index - party_top) if actor_mode else -1
	party._place_bar(true)
	party.queue_redraw()
	hints.set_hints([["确定", "进入"], ["取消", "返回"]] if actor_mode else [["确定", "进入"], ["取消", "回地图"], ["Q / E", "换组"]])
	_place()
	_place_bar(false)
	text_layer.queue_redraw()
	run_panel.queue_redraw()
	face.queue_redraw()
	top.queue_redraw()


## 队伍条最多放几行（右块高减本局条）
func party_rows() -> int:
	var h: float = (layout.rects().right as Rect2).size.y - run_height() - XUiSkin.PANEL_GAP - XSkinPartyStrip.TITLE_H - 8
	return maxi(1, floori(h / party.row_height))


func run_height() -> float:
	return RUN_H if not seal_states(_state()).is_empty() else RUN_H_SHORT


func _place() -> void:
	if layout == null:
		return
	layout.relayout()
	var rh := run_height()
	run_panel.position = Vector2.ZERO
	run_panel.size = Vector2(RIGHT_W, rh)
	party.position = Vector2(0, rh + XUiSkin.PANEL_GAP)
	party.size = Vector2(RIGHT_W, party.custom_minimum_size.y)
	var view := layout.view_size()
	hints.position = Vector2(hint_right(view) - hints.total_width(), view.y - XUiSkin.HINT_BOTTOM - XSkinKeyHints.H)
	_layout_rows()
	_place_bar(true)
	top.queue_redraw()


## 按键提示的右边：安全边距，且让出右下角版本号（XVersionLabel，全局一直显示，字号 14）
static func hint_right(view: Vector2) -> float:
	var right := view.x - XSkinLayout.margin_for(view.x)
	if XVersionLabel.SHOW:
		var vw := GameFont.current().get_string_size(XVersionLabel.version_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, XVersionLabel.FONT_SIZE).x
		right = minf(right, view.x - XVersionLabel.MARGIN.x - vw - 16.0)
	return right


## 中块各行：[{kind: group／header／item, g, i, rect}]
func _layout_rows() -> void:
	_rows = []
	var h := pane.size.y - XUiSkin.PAD * 2
	var fixed := 0.0
	var collapsed := 0
	for k in groups.size():
		var n := group_items(groups[k]).size()
		if k != gi:
			collapsed += 1
		elif n <= 1:
			fixed += ROW_ITEM
		else:
			fixed += ROW_HEADER + ROW_ITEM * n
	var gh := ROW_GROUP
	if collapsed > 0:
		gh = clampf((h - fixed) / collapsed, 30.0, ROW_GROUP)
	var y := float(XUiSkin.PAD)
	var w := pane.size.x - 20.0
	for k in groups.size():
		var n := group_items(groups[k]).size()
		if k != gi:
			_rows.append({"kind": "group", "g": k, "i": 0, "rect": Rect2(10, y, w, gh)})
			y += gh
		elif n <= 1:
			_rows.append({"kind": "item", "g": k, "i": 0, "rect": Rect2(10, y, w, ROW_ITEM)})
			y += ROW_ITEM
		else:
			_rows.append({"kind": "header", "g": k, "i": -1, "rect": Rect2(10, y, w, ROW_HEADER)})
			y += ROW_HEADER
			for i in n:
				_rows.append({"kind": "item", "g": k, "i": i, "rect": Rect2(10, y, w, ROW_ITEM)})
				y += ROW_ITEM


func rows() -> Array:
	return _rows


func selected_row_rect() -> Rect2:
	for r in _rows:
		if r.kind == "item" and r.g == gi and r.i == ii:
			return r.rect
	return Rect2()


func _place_bar(instant: bool) -> void:
	if bar == null:
		return
	var r := selected_row_rect()
	bar.visible = r.size != Vector2.ZERO
	if bar.visible:
		bar.move_to(r, instant)


## ---- 操作 ----

## 换组（环、列表同步）；d＝±1，到头循环
func step_group(d: int) -> void:
	if groups.size() <= 1:
		return
	_set_group(posmod(gi + d, groups.size()), 0)


func _set_group(g: int, i: int) -> void:
	var changed := g != gi or i != ii
	gi = g
	ii = i
	if ring.index != gi:
		ring.select(gi)
	if changed:
		XSound.system(0)
	_layout_rows()
	_place_bar(false)
	text_layer.queue_redraw()


## 上下走一项；到组头尾跨到上／下一组（上一组落在最后一项）；wrap＝false 时（按住连发）到整个列表头尾停住
func move_item(d: int, wrap := true) -> void:
	var n := group_items(current_group()).size()
	var i := ii + d
	if i >= 0 and i < n:
		_set_group(gi, i)
		return
	var g := gi + d
	if g < 0 or g >= groups.size():
		if not wrap:
			return
		g = posmod(g, groups.size())
	_set_group(g, 0 if d > 0 else group_items(groups[g]).size() - 1)


## 确定当前子项
func activate() -> void:
	var it := current_item()
	if it.is_empty() or host == null:
		return
	if not item_enabled(it):
		XSound.system(3)
		return
	XSound.system(1)
	host.run_command(str(it.cmd))


func _on_ring_changed(i: int) -> void:
	if host != null and host._mode != "command":  # 选人时环不收鼠标（refresh 里关了），这里再兜一次：转回当前组
		ring.select(gi, false)
		return
	if i != gi:
		_set_group(i, 0)


## 收起的组那一行右边：多项组列子项名；只一项的组写那一项的说明（不重复组名，小A核查 P2）
static func collapsed_text(g: Dictionary) -> String:
	var items: Array = g.get("items", [])
	if items.size() == 1:
		return str(items[0].get("desc", ""))
	return "　".join(items.map(func(it): return str(it.name)))


func _on_party_index(i: int) -> void:
	if host != null and host._mode == "actor":
		host._actor_index = party_top + i
		XSound.system(0)
		face.queue_redraw()


func _on_party_activated(i: int) -> void:
	if host == null or host._mode != "actor":
		return
	host._actor_index = party_top + i
	XSound.system(1)
	host.open_actor_page(host._pending, host._actor_index)


func _pane_input(event: InputEvent) -> void:
	if host == null or host._mode != "command":
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			move_item(1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1, false)
			pane.accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		for r in _rows:
			if (r.rect as Rect2).has_point(mb.position):
				if r.kind == "group" or r.kind == "header":
					if r.g != gi:
						_set_group(r.g, 0)
				elif r.g == gi and r.i == ii:
					activate()
				else:
					_set_group(r.g, r.i)
				pane.accept_event()
				return


func _unhandled_input(event: InputEvent) -> void:
	if host == null or host._mode == "page" or not is_visible_in_tree():
		return
	if host._mode == "actor":
		_actor_input(event)
		return
	if event.is_action_pressed("ui_cancel"):
		XKeyMap.handled(self)
		host._cancel()
	elif event.is_action_pressed("ui_accept"):
		XKeyMap.handled(self)
		activate()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		XKeyMap.handled(self)
		move_item(1 if event.is_action_pressed("ui_down", true) else -1, not event.is_echo())
	elif event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		XKeyMap.handled(self)
		step_group(1 if event.is_action_pressed("ui_right", true) else -1)
	elif XMenu.page_dir(event) != 0:
		XKeyMap.handled(self)
		step_group(XMenu.page_dir(event))


func _actor_input(event: InputEvent) -> void:
	var members := host._members()
	if event.is_action_pressed("ui_cancel"):
		XKeyMap.handled(self)
		XSound.system(2)
		host._mode = "command"
		refresh()
	elif event.is_action_pressed("ui_accept"):
		XKeyMap.handled(self)
		XSound.system(1)
		host.open_actor_page(host._pending, host._actor_index)
	elif (event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true)) and not members.is_empty():
		XKeyMap.handled(self)
		var d := 1 if event.is_action_pressed("ui_down", true) else -1
		var before := host._actor_index
		host._actor_index = XMenu._move(host._actor_index, d, members.size(), not event.is_echo())
		if before != host._actor_index:
			XSound.system(0)
		refresh()


## ---- 画 ----

func _draw_pane() -> void:
	var body := XUiSkin.font("body")
	var head := XUiSkin.font("title")
	for r in _rows:
		var rect: Rect2 = r.rect
		var g: Dictionary = groups[r.g]
		var base := rect.position.y + rect.size.y / 2.0
		var x := rect.position.x + 16.0
		match str(r.kind):
			"group":
				var nm := str(g.name)
				text_layer.draw_string(body, Vector2(x, base + XUiSkin.FS_LIST * 0.36), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_LIST, XUiSkin.TEXT)
				var sx := x + maxf(60.0, body.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_LIST).x + 16.0)
				text_layer.draw_string(body, Vector2(sx, base + 15 * 0.36), collapsed_text(g), HORIZONTAL_ALIGNMENT_LEFT, rect.end.x - sx - 8.0, 15, XUiSkin.TEXT_2)
			"header":
				text_layer.draw_string(head, Vector2(x, base + 21 * 0.36), str(g.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, XUiSkin.GOLD)
			"item":
				var it: Dictionary = group_items(g)[r.i]
				var on: bool = r.g == gi and r.i == ii
				var ok := item_enabled(it)
				var ix := x + (8.0 if group_items(g).size() > 1 else 0.0)
				var fs := XUiSkin.FS_LIST_MAX
				var nm := str(it.name)
				text_layer.draw_string(head if on else body, Vector2(ix, base + fs * 0.36), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
					XUiSkin.TEXT_3 if not ok else (Color.WHITE if on else XUiSkin.TEXT))
				var nw := (head if on else body).get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var desc := str(it.get("desc", ""))
				if desc != "":
					var dx := ix + nw + 14.0
					text_layer.draw_string(body, Vector2(dx, base + 15 * 0.36), desc, HORIZONTAL_ALIGNMENT_LEFT, maxf(rect.end.x - dx - 12.0, 10.0), 15,
						XUiSkin.TEXT_3 if not ok else XUiSkin.TEXT_2)


func _draw_run() -> void:
	var ci := run_panel.get_canvas_item()
	var rect := Rect2(Vector2.ZERO, run_panel.size)
	XUiSkin.shadow_style().draw(ci, rect)
	XUiSkin.panel_style().draw(ci, rect)
	var s := _state()
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	run_panel.draw_string(body, Vector2(XUiSkin.PAD + 4, 18 + 20 * 0.86), run_text(s), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - XUiSkin.PAD * 2, 20, XUiSkin.TEXT)
	var st := seal_states(s)
	if st.is_empty():
		return
	var y := 66.0
	run_panel.draw_string(body, Vector2(XUiSkin.PAD + 4, y + 15 * 0.36), "七印", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, XUiSkin.TEXT_2)
	var x := XUiSkin.PAD + 4 + body.get_string_size("七印", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 12.0
	for k in SEALS:
		var v := int(st[k]) if k < st.size() else 0
		var c := Vector2(x + 6, y)
		var pts := PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)])
		if v == 2:
			run_panel.draw_colored_polygon(pts, XUiSkin.GOLD)
		elif v == 1:
			pts.append(pts[0])
			run_panel.draw_polyline(pts, XUiSkin.GOLD, 1.5, true)
		else:
			run_panel.draw_colored_polygon(pts, Color(XUiSkin.LINE, 0.3))
		x += 15.0
	var t := "%d / %d" % [seals_cleared(st), SEALS]
	var tw := num.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	run_panel.draw_string(num, Vector2(rect.size.x - XUiSkin.PAD - 4 - tw, y + 21 * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, XUiSkin.GOLD_LIGHT)


## 环心：当前角色（选人时跟着队伍条）的圆头像
func _draw_face() -> void:
	if host == null:
		return
	var members := host._members()
	if members.is_empty():
		return
	var idx := host._actor_index if host._mode == "actor" else host._selected_actor
	var a: XActor = members[clampi(idx, 0, members.size() - 1)]
	var tex := XUiSkin.face(str(a.data().get("faceName", "")), int(a.data().get("faceIndex", 0)))
	if tex == null:
		return
	var c := ring.center()
	var rad := ring.radius - 62.0
	face.draw_circle(c, rad + 3.0, Color(0, 0, 0, 0.45))
	XSkinPartyStrip.draw_round_texture(face, tex, c, rad)
	face.draw_circle(c, rad, Color(XUiSkin.LINE, 0.5), false, 1.5, true)


func _draw_top() -> void:
	var view := layout.view_size()
	var m := XSkinLayout.margin_for(view.x)
	top.draw_string(XUiSkin.font("title"), Vector2(m, 14 + 34 * 0.92), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_PAGE, XUiSkin.TEXT)
	# 货币：名字次要字 15、数值淡金窄体 26，右对齐（样稿：精魂在左、印屑在右）
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var x := view.x - m
	var cur := currencies(_state())
	cur.reverse()
	for pair in cur:
		var vw := num.get_string_size(pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		x -= vw
		top.draw_string(num, Vector2(x, 42), pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, XUiSkin.GOLD_LIGHT)
		var nw := body.get_string_size(pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		x -= nw + 6
		top.draw_string(body, Vector2(x, 42), pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, XUiSkin.TEXT_2)
		x -= 18
