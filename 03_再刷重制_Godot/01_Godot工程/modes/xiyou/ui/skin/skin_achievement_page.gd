class_name XSkinAchievementPage
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】T365 卡 Q：成就簿新布局（T254 3.17；版型一）。
## 成就的数据、类型切换、已得判断、天启篇不列宠物成就、142／143 专用徽章、操作状态机全部还是 XAchievementScene／XAchievement 原来的代码；
## 本页只是把它们换成模板页画法，按键（上下、翻页、确定、取消）仍交给 XAchievementScene 处理，它刷新时调 sync()。
## 旧页 → 新页（T254 3.17 对应表）：
## - 类型窗 8 类 → 环上 8 个球（球 52，球里写类名第一个字）。
## - 计数窗「已得/总数」→ 环心「37 / 120 已获得」；这一类的「4 / 7」写在列表标题右边小字。
## - 列表每项 108 高三行 → 行高 64 两行式：图标、名字、条件，行尾「◆ 已获得」金色；奖励、完成时间进右牌。
## - 未得只写「未获得」→ 行变灰：「尚未达成」＋小字「达成后显示名称与条件」（草稿）；名字、条件不露。
## - 列表里确定无反应、取消回类型、类型上取消关闭 → 照旧（scene.ok／cancel）。
## 右牌：一枚金蜡（同结算那枚 XSkin2C.draw_wax）上压着成就图标，名字，「类别 · YYYY-MM-DD 达成」，「达成条件」，「特殊奖励」。
## 新皮肤关着、或 ENABLED＝false 时 XAchievementScene 不建这一页，旧页一行不变。

## T365 回退开关：false＝天启篇新皮肤下成就簿也回旧页
static var ENABLED := true
## 玩家可见文字（待小A 审）
const T_TITLE := "成就簿"
const T_HAVE := "已获得"
const T_ROW_RIGHT := "◆ 已获得"
const T_LOCKED := "尚未达成"
const T_LOCKED_SUB := "达成后显示名称与条件"
const T_HOW := "达成条件"
const T_REWARD := "特殊奖励"
const T_GOT := "达成"
const ROW_H := 64
const WAX := 52.0
const ICON := 32.0

var scene: XAchievementScene
var wax_layer: Control
var list_right := ""
var _syncing := false
var _list_key := []
static var _blank: Texture2D


func _init(s: XAchievementScene) -> void:
	scene = s
	name = "SkinAchievementPage"
	title = T_TITLE
	group_key = "codex"     # 主菜单「图鉴」组里的成就（页签条在）
	columns = 1
	row_height = ROW_H
	left_w = 312.0
	right_w = 312.0
	orb_radius = 26.0       # 球 52（T254 3.17）
	auto_nav = false
	focus = "ring"
	currencies = []
	hint_list = [["确定", "进入列表"], ["取消", "返回"]]


func _ready() -> void:
	super()
	list.empty_center = true
	list.icon_size = 40
	list.index_changed.connect(_on_list_index)
	list.activated.connect(_on_list_click)
	list.gui_input.connect(_list_gui)
	list.draw.connect(_draw_rows)
	ring.changed.connect(_on_ring_changed)
	ring.activated.connect(func(_i): if not _syncing and scene.mode == "type": scene.ok())
	list_panel.draw.connect(_draw_list_right)
	wax_layer = Control.new()
	wax_layer.name = "Wax"
	wax_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wax_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wax_layer.draw.connect(_draw_wax)
	card.add_child(wax_layer)
	gui_input.connect(_on_gui)
	mouse_filter = Control.MOUSE_FILTER_PASS
	relayout()


## 环心大字：数字位数多时（「18 / 263」）缩字到环内放得下（模板固定 44 号，三位数会压到球上）
func _draw_ring_center() -> void:
	if ring_center.is_empty():
		return
	var c := ring.center()
	var num := XUiSkin.font("num")
	var body := XUiSkin.font("body")
	var big := str(ring_center[0])
	var fs := 44
	var maxw := (ring_radius - orb_radius) * 2.0 - 36.0
	while fs > 20 and num.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw:
		fs -= 2
	var bw := num.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	XUiSkin.ds(ring, num, Vector2(c.x - bw / 2.0, c.y + 8.0 - (44 - fs) * 0.1), big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT)
	if ring_center.size() > 1:
		var small := str(ring_center[1])
		var sw := body.get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
		XUiSkin.ds(ring, body, Vector2(c.x - sw / 2.0, c.y + 34.0), small, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, XUiSkin.TEXT_2)


# ---- 数据 ----

## 一行（测试按对应表核）：未得不露名字和条件
func row_for(id: int) -> Dictionary:
	var d := XAchievement.def(id)
	var owned := XAchievement.global_has(id)
	var row := {"text": "", "_id": id, "_owned": owned, "icon": icon_of(id, owned), "disabled": not owned}
	if owned:
		row["_name"] = str(d.name)
		row["_cond"] = str(d.trigger)
		row["right"] = T_ROW_RIGHT
		row["right_color"] = XUiSkin.GOLD
	else:
		row["_name"] = T_LOCKED
		row["_cond"] = T_LOCKED_SUB
	return row


## 图标：142／143 用专用徽章图（XAchievementBadge.file_of），其余用图标集；未得的普通成就不画图标（143 照旧淡淡露徽章）
static func icon_of(id: int, owned: bool):
	var d := XAchievement.def(id)
	var file := XAchievementBadge.file_of(int(d.icon))
	if file != "":
		var p := XDB.img_path("codex_achievements", file)
		var tex: Texture2D = load(p) if p != "" else null
		return tex if owned or id == XAchievementBadge.KYO_ID else null
	return int(d.icon) if owned else null


func current_id() -> int:
	var sc := scene
	if sc.list.is_empty():
		return 0
	var i := sc.index if sc.index >= 0 and sc.index < sc.list.size() else 0   # 还在选类型时右牌先预览这一类第一项
	return int(sc.list[i])


## 「2026年11月22日 …」「2026-11-22 …」统一成 YYYY-MM-DD
static func _short_date(t: String) -> String:
	var d := t.split(" ")[0]
	var m := RegEx.create_from_string("^(\\d+)年(\\d+)月(\\d+)日")
	var r := m.search(d)
	if r != null:
		return "%04d-%02d-%02d" % [int(r.get_string(1)), int(r.get_string(2)), int(r.get_string(3))]
	return d


## 右牌内容（测试按对应表核）
func card_data() -> Dictionary:
	var id := current_id()
	if id <= 0:
		return {"title": "", "sections": [], "buttons": []}
	var d := XAchievement.def(id)
	if not XAchievement.global_has(id):
		return {"icon": blank(), "title": T_LOCKED, "title_color": XUiSkin.TEXT_3, "subtitle": str(d.type),
			"sections": [{"title": "", "rows": [{"text": T_LOCKED_SUB, "color": XUiSkin.TEXT_3}]}], "buttons": []}
	var t := XAchievement.global_time(id)
	var sub := str(d.type) + (" · %s %s" % [_short_date(t), T_GOT] if t != "" else "")
	var sections := [{"title": T_HOW, "rows": [{"text": str(d.trigger), "color": XUiSkin.TEXT}]}]
	if str(d.evalText) != "":
		sections.append({"title": T_REWARD, "rows": [{"text": str(d.evalText), "color": XUiSkin.GOLD_LIGHT}]})
	return {"icon": blank(), "title": str(d.name), "title_color": XUiSkin.TEXT_HI, "subtitle": sub, "sections": sections, "buttons": []}


## 牌头留 48 的图标位，图标本身由蜡层画（空白贴图占位）
static func blank() -> Texture2D:
	if _blank == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		_blank = ImageTexture.create_from_image(img)
	return _blank


# ---- 按状态重画 ----

func sync() -> void:
	if layout == null:
		return
	_syncing = true
	var sc := scene
	for w in [sc.type_win, sc.list_win, sc.count_win]:
		w.visible = false
	var types := sc.types()
	var cats := []
	for t in types:
		cats.append({"key": str(t), "name": str(t), "icon": 0, "glyph": str(t).left(1)})
	var cat_key := cats.map(func(c): return c.name)
	if ring.items.map(func(c): return c.name) != cat_key:
		set_categories(cats, sc.type_index)
		for k in cats.size():   # set_categories 只带 key／name／icon，球里的字这里补（同设置页 R5）
			ring.items[k]["glyph"] = str(cats[k].glyph)
	elif ring.index != sc.type_index:
		ring.select(sc.type_index, false)
	var n: Array = XAchievement.count(XState.current)
	ring_center = ["%d / %d" % n, T_HAVE]
	var have := 0
	for id in sc.list:
		if XAchievement.global_has(int(id)):
			have += 1
	list_title = str(types[sc.type_index]) if sc.type_index < types.size() else ""
	list_right = "%d / %d" % [have, sc.list.size()]
	list.empty_text = "这一类没有成就"
	var rows := []
	for id in sc.list:
		rows.append(row_for(int(id)))
	var key := [sc.type_index, rows.map(func(r): return [r._id, r._owned])]
	var idx := clampi(sc.index, 0, maxi(rows.size() - 1, 0))
	if key != _list_key:
		_list_key = key
		set_items(rows, idx)
	elif list.index != idx and not rows.is_empty() and sc.mode == "list":
		list.select(idx, false)
	set_focus(sc.mode if sc.mode == "list" else "ring")
	list.active = sc.mode == "list"
	_sync_card()
	if sc.mode == "list":
		set_hint_list([["Q / E", "翻页"], ["取消", "回到分类"]])
	else:
		set_hint_list([["确定", "进入列表"], ["取消", "返回"]])
	_syncing = false
	ring.queue_redraw()
	list.queue_redraw()
	list_panel.queue_redraw()
	wax_layer.queue_redraw()


func _sync_card() -> void:
	var d := card_data()
	card.visible = not scene.list.is_empty()   # 空类型右牌不画（T254 3.0「空列表」）
	d.button_index = -1
	set_card(d)
	if wax_layer != null:
		wax_layer.queue_redraw()


# ---- 按键：上下、确定、取消照旧走 XAchievementScene；Q／E 翻页、左右在环上换类 ----

func input(event: InputEvent) -> bool:
	var sc := scene
	if XMenu.page_dir(event) != 0 and sc.mode == "list":
		list.page(XMenu.page_dir(event), true)
		return true
	if sc.mode == "type" and (event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true)):
		sc._move(1 if event.is_action_pressed("ui_right", true) else -1, not event.is_echo())
		return true
	return false


func _on_ring_changed(i: int) -> void:
	if _syncing or i == scene.type_index:
		return
	if scene.mode == "list":
		scene.cancel()   # 在列表里点环上别的球：先回类型再换（旧页只有类型窗能换类）
	scene.select_type(i)


func _on_list_index(i: int) -> void:
	if _syncing or i == scene.index:
		return
	if scene.mode == "type":
		scene.ok()    # 点列表行＝进列表（旧页点类型窗里当前类也是确定）
	scene.select(i)


func _on_list_click(_i: int) -> void:
	if scene.mode == "type":
		scene.ok()   # 分类态点中当前（第 0）行：_tap 不发 index_changed，只发 activated，这里进列表；列表里确定仍无反应（旧页照旧）


## 未得的第 0 行 disabled，_tap 连 activated 都不发：分类态里在这里补一次「进列表」
var _press_pos := Vector2.INF


func _list_gui(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var mb := event as InputEventMouseButton
	if mb.pressed:
		_press_pos = mb.position
	if XUiSkin.TOUCH_V2:   # 触屏按下只记位置、松手没拖过才算点
		if mb.pressed:
			return
		var from := _press_pos
		_press_pos = Vector2.INF
		if from == Vector2.INF or from.distance_to(mb.position) > 10.0:
			return
	elif not mb.pressed:
		return
	if _syncing or scene.mode != "type":
		return
	var i := list.item_at(mb.position)
	if i >= 0 and i == list.index and bool(list.items[i].get("disabled", false)):
		scene.ok()


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		scene.cancel()
		accept_event()


# ---- 画：两行式行（名字＋条件）、列表标题右小字、右牌金蜡 ----

func _draw_rows() -> void:
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var first := list.top_row
	var last := mini(list.items.size(), list.top_row + list.visible_rows() + (1 if list._sub != 0.0 else 0))
	for i in range(first, last):
		var it: Dictionary = list.items[i]
		var r := list.cell_rect(i)
		var owned := bool(it.get("_owned", false))
		var x := r.position.x + 14.0 + float(list.icon_size) + 10.0
		var end_x := r.end.x - 14.0
		var rw := 0.0
		var right := str(it.get("right", ""))
		if right != "":
			rw = num.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, list.right_size).x + 12.0
		var sel: bool = i == list.index and list.active
		var c1: Color = XUiSkin.TEXT if owned else XUiSkin.TEXT_3
		if sel:
			c1 = XUiSkin.sel_text(c1) if owned else Color("c9cbd0")
		var cy := r.position.y + r.size.y / 2.0
		var fs1 := list.font_size
		var fit1 := XSkinList.fit_text(body, str(it._name), end_x - rw - x, fs1, 16)
		XUiSkin.ds(list, body, Vector2(x, cy - 6.0), str(fit1[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit1[1]), c1)
		var fs2 := list.sub_size
		var fit2 := XSkinList.fit_text(body, str(it._cond), end_x - x, fs2, 15)
		XUiSkin.ds(list, body, Vector2(x, cy + 6.0 + int(fit2[1]) * 0.86), str(fit2[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit2[1]), XUiSkin.TEXT_2 if owned else XUiSkin.TEXT_3)
		if not owned and it.get("icon") == null:
			var ic := Vector2(r.position.x + 14.0 + float(list.icon_size) / 2.0, cy)   # 未得：空心圆占位，不露图标
			list.draw_arc(ic, 13.0, 0, TAU, 32, Color(XUiSkin.TEXT_3, 0.7), 1.5, true)


func _draw_list_right() -> void:
	if list_right == "":
		return
	var body := XUiSkin.font("body")
	var fs := XUiSkin.FS_AUX
	var tw := body.get_string_size(list_right, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	XUiSkin.ds(list_panel, body, Vector2(list_panel.size.x - XUiSkin.PAD - 8 - tw, XUiSkin.PAD + 20), list_right, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.GOLD_LIGHT)


## 右牌牌头：金蜡（未得时压暗）＋图标
func _draw_wax() -> void:
	var id := current_id()
	if id <= 0 or not card.visible:
		return
	var owned := XAchievement.global_has(id)
	var c := Vector2(card.pad + 24.0, card.pad + 24.0)
	XSkin2C.draw_wax(wax_layer, c, WAX, 1.0 if owned else 0.28)
	var icon = icon_of(id, owned)
	var tex: Texture2D = icon if icon is Texture2D else (XUiSkin.icon(int(icon)) if icon != null else null)
	if tex != null:
		wax_layer.draw_texture_rect(tex, Rect2(c - Vector2(ICON, ICON) / 2.0, Vector2(ICON, ICON)), false)
