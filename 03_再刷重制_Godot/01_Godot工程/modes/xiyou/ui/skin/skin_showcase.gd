class_name XSkinShowcase
extends Control
## 【cc·天启篇·未经审查】新界面组件陈列页（第 0 期验收用；不是游戏里的页面，玩家进不来）：所有通用组件摆一屏，
## 按横屏锚点（XSkinLayout）放：左块环形导航＋三个弧形量条，中块直列表（一列、两列带滚动条），右块紧凑角色条＋详情牌，
## 顶上页名、组页签条、货币，右下按键提示。数据：XState.current 有队伍就取前四人，没有就用演示数据。
## 按键：Q／E 换组（环和页签同步）、上下选列表、左右在两列表里走、Tab 切到两列表。

var layout: XSkinLayout
var ring: XSkinRingNav
var tabs: XSkinTabStrip
var list1: XSkinList
var list2: XSkinList
var party: XSkinPartyStrip
var card: XSkinCard
var gauges: Array = []
var hints: XSkinKeyHints
var _focus: XSkinList
var top: Control
const TITLE := "组件陈列"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUiSkin.theme()
	XUiSkin.menu_backdrop(self)
	layout = XSkinLayout.new()
	add_child(layout)
	XSkinLayout.request_wide(self)
	var s := XState.current
	var groups := XUiSkin.visible_groups(XUiSkin.GROUPS, s)
	# 左块：环（中心放队首头像）＋三个弧形量条
	ring = XSkinRingNav.new()
	ring.radius = 150
	ring.orb_radius = 30
	ring.size = Vector2(416, 416)
	ring.set_items(groups.map(func(g): return XSkinRingNav.group_item(g)))
	ring.select(mini(2, groups.size() - 1), false)
	layout.left.add_child(ring)
	var kinds := [["hp", "生命", 1840.0, 2400.0], ["mp", "魔法", 160.0, 420.0], ["boss", "首领", 3.6e6, 5e6]]
	for k in kinds.size():
		var g := XSkinArcGauge.new()
		g.kind = kinds[k][0]
		g.thickness = 8.0 if kinds[k][0] == "boss" else 6.0
		g.position = Vector2(k * 136, 432)
		g.size = Vector2(120, 120)
		g.set_value(kinds[k][2], kinds[k][3], true)
		layout.left.add_child(g)
		gauges.append(g)
		var cap: Array = kinds[k]
		g.draw.connect(func():
			var f := XUiSkin.font("body")
			var nf := XUiSkin.font("num")
			var v := _short(cap[2])
			var vw := nf.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
			XUiSkin.ds(g, nf, Vector2(60 - vw / 2.0, 66), v, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, XSkinArcGauge.color_of(cap[0]).lightened(0.55))
			var cw := f.get_string_size(cap[1], HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
			XUiSkin.ds(g, f, Vector2(60 - cw / 2.0, 90), cap[1], HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, XUiSkin.TEXT_2))
	# 中块：一列直列表＋两列直列表（有滚动条）
	var pane := Panel.new()
	pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pane.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.center.add_child(pane)
	list1 = XSkinList.new()
	list1.position = Vector2(8, 52)
	list1.size = Vector2(408, XUiSkin.ROW_H * 5)
	list1.set_items(_demo_rows())
	list1.select(1, false)
	pane.add_child(list1)
	list2 = XSkinList.new()
	list2.columns = 2
	list2.row_height = XUiSkin.ROW_H_ITEMS
	list2.position = Vector2(8, 52 + XUiSkin.ROW_H * 5 + 60)
	list2.size = Vector2(408, XUiSkin.ROW_H_ITEMS * 4)
	list2.set_items(_demo_items())
	pane.add_child(list2)
	pane.resized.connect(func():
		list1.size.x = pane.size.x - 16
		list2.size.x = pane.size.x - 16)
	pane.draw.connect(func():
		var f := XUiSkin.font("body")
		XUiSkin.ds(pane, f, Vector2(XUiSkin.PAD, 10 + 21 * 0.9), "直列表 · 一列", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, XUiSkin.GOLD)
		XUiSkin.ds(pane, f, Vector2(XUiSkin.PAD, list2.position.y - 50 + 10 + 21 * 0.9), "直列表 · 两列", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, XUiSkin.GOLD)
		pane.draw_line(Vector2(XUiSkin.PAD, list2.position.y - 50), Vector2(pane.size.x - XUiSkin.PAD, list2.position.y - 50), Color(XUiSkin.LINE, 0.14), 1.0))
	_focus = list1
	# 右块：紧凑角色条＋详情牌
	party = XSkinPartyStrip.new()
	party.title = "队伍"
	party.selectable = true
	party.size = Vector2(360, 292)
	party.set_members(_members(s))
	party.select(mini(3, party.members.size() - 1))
	layout.right.add_child(party)
	card = XSkinCard.new()
	card.position = Vector2(0, 308)
	card.size = Vector2(360, 288)
	card.setup({"icon": XUiSkin.icon(160), "title": "彼亥汀,斩首刀", "title_color": XUiSkin.quality_color(4),
		"subtitle": "传说 · 刀/剑 · 等级需求 13", "desc": "血腥的味道，让人瑟瑟发抖。",
		"sections": [{"title": "自带", "lines": [{"left": "攻击力", "right": "+35", "right_color": XUiSkin.UP}, {"left": "暴击率", "right": "+5%", "right_color": XUiSkin.UP}]}],
		"buttons": [{"text": "装备", "primary": true}, {"text": "取消"}], "button_index": 0})
	layout.right.add_child(card)
	# 顶上页签条、右下按键提示
	tabs = XSkinTabStrip.new()
	tabs.set_groups(XUiSkin.GROUPS, s)
	tabs.select(ring.index)
	add_child(tabs)
	ring.changed.connect(func(i): tabs.select(i))
	tabs.changed.connect(func(i): ring.select(i))
	top = Control.new()
	top.name = "Top"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.draw.connect(_draw_top)
	add_child(top)
	move_child(top, 1)   # 黑底之上、组件之下
	hints = XSkinKeyHints.new()
	hints.set_hints([["确定", "进入"], ["取消", "返回"], ["Q / E", "换组"]])
	add_child(hints)
	resized.connect(_place_top)
	get_viewport().size_changed.connect(_place_top)
	_place_top()


func _place_top() -> void:
	if layout == null:
		return
	layout.relayout()
	var view := layout.view_size()
	var m := XSkinLayout.margin_for(view.x)
	var f := XUiSkin.font("title")
	tabs.position = Vector2(m + f.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_PAGE).x + 24, 14)
	tabs.size = Vector2(tabs.total_width(), XSkinTabStrip.TAB_H)
	hints.place(view)
	top.queue_redraw()


func _draw_top() -> void:
	var view := layout.view_size()
	var m := XSkinLayout.margin_for(view.x)
	XUiSkin.ds(top, XUiSkin.font("title"), Vector2(m, 14 + 34 * 0.92), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_PAGE, XUiSkin.TEXT)
	# 货币：名字次要字 15、数值淡金窄体 26，右对齐
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var x := view.x - m
	for pair in [["印屑", "126"], ["精魂", "12,480"]]:
		var vw := num.get_string_size(pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		x -= vw
		XUiSkin.ds(top, num, Vector2(x, 42), pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, XUiSkin.GOLD_LIGHT)
		var nw := body.get_string_size(pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		x -= nw + 6
		XUiSkin.ds(top, body, Vector2(x, 42), pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, XUiSkin.TEXT_2)
		x -= 18
	# 安全边距参考线（只在比 16:9 宽时画，验收截图看锚点用）
	if view.x > 1280.0:
		for lx in [m, view.x - m]:
			for y in range(0, int(view.y), 12):
				top.draw_line(Vector2(lx, y), Vector2(lx, y + 6), Color(XUiSkin.LINE, 0.35), 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_Q or event.keycode == KEY_E):
		ring.step(-1 if event.keycode == KEY_Q else 1)
		XKeyMap.handled(self)
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_focus = list2 if _focus == list1 else list1
		XKeyMap.handled(self)
		return
	if _focus.handle_input(event):
		XKeyMap.handled(self)


static func _short(v: float) -> String:
	return "%d万" % roundi(v / 10000.0) if v >= 100000.0 else str(int(v))


func _demo_rows() -> Array:
	return [{"text": "治疗药水(小)", "icon": 100, "sub": "回复生命", "right": "×12"},
		{"text": "练习剑", "icon": 160, "sub": "已装备", "right": "+12", "right_color": XUiSkin.UP},
		{"text": "敏锐斧", "icon": 193, "color": XUiSkin.quality_color(3), "right": "▲ 46", "right_color": XUiSkin.UP},
		{"text": "短矛", "icon": 176, "right": "▼ 4", "right_color": XUiSkin.DOWN},
		{"text": "木杖", "icon": 240, "sub": "等级不够", "right": "+18", "disabled": true}]


func _demo_items() -> Array:
	var out := []
	var names := [["治疗药水(小)", 100], ["魔力药水(小)", 99], ["活力药水(小)", 101], ["魔力药水(中)", 99], ["治疗药水(中)", 100],
		["水果刀", 224], ["练习剑", 160], ["砍柴斧", 193], ["短矛", 176], ["短弓", 208]]
	for k in names.size():
		out.append({"text": names[k][0], "icon": names[k][1], "right": "×%d" % (k * 3 + 2)})
	return out


func _members(s: XState) -> Array:
	if s != null and not s.members().is_empty():
		return s.members().slice(0, 4).map(func(a): return XSkinPartyStrip.from_actor(a))
	return [{"name": "狗逍遥", "level": 1, "cls": "断腿狗", "face": XUiSkin.face("gxyface2", 0), "hp": 485, "mhp": 485, "mp": 200, "mmp": 200, "tp": 12, "mtp": 100},
		{"name": "修", "level": 1, "cls": "医师", "face": XUiSkin.face("Actor2", 2), "hp": 312, "mhp": 450, "mp": 220, "mmp": 220, "tp": 12, "mtp": 100},
		{"name": "罗琳", "level": 1, "cls": "见习骑士", "face": XUiSkin.face("Actor1", 1), "hp": 525, "mhp": 525, "mp": 96, "mmp": 150, "tp": 12, "mtp": 100},
		{"name": "美娜", "level": 1, "cls": "小贼猫", "face": XUiSkin.face("mn", 0), "hp": 480, "mhp": 480, "mp": 200, "mmp": 200, "tp": 12, "mtp": 100}]
