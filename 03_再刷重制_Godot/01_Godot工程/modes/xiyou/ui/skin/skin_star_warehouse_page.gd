class_name XSkinStarWarehousePage
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】T306 卡 N：星级仓库新布局（T254 3.9；版型一，手动用法）。
## 存放／取出规则、不可存放提示、声音（只有普通确定音，不蜂鸣——与仓库页不同，别统一）、取空了光标停在原格全部还是 XStarWarehouseScene／XStarWarehouse 原来的代码。
## 旧页 → 新页（T254 3.9 对应表）：
## - 存放／取出是 NPC 那里分的两个入口 → 页名写成「星级仓库 · 存放」／「星级仓库 · 取出」（scene.save_mode 定，页内不切换）。
## - 分类「装备／宠物」→ 环上两个球；天启篇宠物隐藏时（XTianqiPetHide.active）只剩装备一类：不画环，左块留给仓库的主视觉，进页直接在列表上（取消直接离开）。
## - 列表：装备图标＋名字（品质色），不画数量、不画 NEW；宠物只写名字（存放列 XPets.pet_name，出战的带「[出战]」）→ 照旧；16:9 一列、20:9 两列。
## - 说明卡：装备有、宠物没有 → 右牌：装备用标准详情牌（XSkinItemPage.card_data）、宠物只写名字。旧页那张浮在列表上的说明卡（XHelpCard）不再画。
## - 确定存放／取出一件、光标不动 → 照旧；右牌主按钮「存放」／「取出」。
## 新皮肤关着、或 XSkinWarehousePage.ENABLED＝false（T306 一个开关管三页）时 XStarWarehouseScene 不建这一页，旧页一行不变。

## 玩家可见文字（待小A 审）
const T_TITLE := "星级仓库"
const T_SAVE := "存放"
const T_TAKE := "取出"
const T_EMPTY_SAVE := "背包里没有可存放的"
const T_EMPTY_TAKE := "仓库里没有东西"
const T_CATS := ["装备", "宠物"]
const CAT_ICONS := [160, 116]

var scene: XStarWarehouseScene
var _syncing := false
var _list_key := []
var _ring_key := []


func _init(s: XStarWarehouseScene) -> void:
	scene = s
	name = "SkinStarWarehousePage"
	title = "%s · %s" % [T_TITLE, T_SAVE if s.save_mode else T_TAKE]
	group_key = ""
	columns = 1
	row_height = XUiSkin.ROW_H
	right_w = 352.0
	auto_nav = false
	show_ring = not XTianqiPetHide.active()
	focus = "ring" if show_ring else "list"
	currencies = []
	hint_list = []


func _ready() -> void:
	super()
	list.empty_center = true
	list.right2_w = 0.0
	if show_ring:
		ring.changed.connect(_on_ring_changed)
		ring.activated.connect(_on_ring_clicked)
	list.index_changed.connect(_on_list_index)
	list.activated.connect(_on_list_click)
	card_button.connect(_on_card_button)
	card.gui_input.connect(_on_card_gui)
	layout.left.draw.connect(_draw_left_visual)
	gui_input.connect(_on_gui)
	mouse_filter = Control.MOUSE_FILTER_PASS
	relayout()


func cols() -> int:
	if layout == null:
		return 1
	return 2 if layout.view_size().x >= XSkinWarehousePage.WIDE_VIEW_W else 1


func relayout() -> void:
	super()
	if list != null:
		list.columns = cols()


func is_equip() -> bool:
	return scene.category == 0


func sync() -> void:
	if layout == null:
		return
	_syncing = true
	var sc := scene
	for w in [sc.cat_win, sc.list_win]:
		w.visible = false
	sc.help_card.show_for({})   # 旧页的浮动说明卡不再画（右牌代替）
	if show_ring:
		var ck := [sc.save_mode, sc.category]
		if ck != _ring_key:
			_ring_key = ck
			set_categories([0, 1].map(func(i): return {"key": XStarWarehouseScene.CATS[i], "name": T_CATS[i], "icon": CAT_ICONS[i]}), sc.category)
		elif ring.index != sc.category:
			ring.select(sc.category, false)
	list_title = T_CATS[sc.category]
	list.empty_text = T_EMPTY_SAVE if sc.save_mode else T_EMPTY_TAKE
	var rows := []
	for e in sc.data:
		rows.append(row_for(e))
	var idx := sc.index
	if sc.mode == "list" and not rows.is_empty() and idx >= rows.size():
		idx = rows.size() - 1   # 取空末尾一格后旧页光标停在空格；新页夹回最后一格（同仓库）
		sc.index = idx
	var key := [sc.save_mode, sc.category, cols(), rows.map(func(r): return [r.text, r.get("color", null)])]
	if key != _list_key:
		_list_key = key
		set_items(rows, maxi(idx, 0))
	elif list.index != maxi(idx, 0) and not rows.is_empty():
		list.select(maxi(idx, 0))
	set_focus("ring" if sc.mode == "category" else "list")
	_sync_card()
	set_hint_list(_hints())
	_syncing = false
	layout.left.queue_redraw()
	list_panel.queue_redraw()


## 一行：装备＝图标＋名字（品质色）；宠物＝只写名字
func row_for(e: Dictionary) -> Dictionary:
	if is_equip():
		return {"text": XQuality.list_name(e), "icon": int(e.get("iconIndex", 0)), "color": XGear.color(e)}
	return {"text": scene.pet_label(e)}


func current_entry() -> Dictionary:
	var sc := scene
	var i := maxi(sc.index, 0)
	return sc.data[i] if i < sc.data.size() else {}


## 右牌：装备＝标准详情牌；宠物＝只写名字（原版宠物没有说明）
func card_data() -> Dictionary:
	var sc := scene
	var e := current_entry()
	if e.is_empty():
		return {"title": "", "sections": [], "buttons": []}
	var d := {}
	if is_equip():
		d = XSkinItemPage.card_data(e)
		d.title = str(d.title).replace(XItemMarks.LOCK, "").replace(XItemMarks.TOP, "").strip_edges()
		d.subtitle = " · ".join(Array(str(d.subtitle).split(" · ", false)).filter(func(x): return not str(x).begins_with("持有")))
	else:
		d = {"title": sc.pet_label(e), "sections": []}
	d.buttons = [{"text": T_SAVE if sc.save_mode else T_TAKE, "primary": true}] if sc.mode == "list" else []
	return d


func _sync_card() -> void:
	var d := card_data()
	card.visible = not current_entry().is_empty()
	d.button_index = -1
	set_card(d)


func _hints() -> Array:
	var sc := scene
	if sc.mode == "category":
		return [["确定", "进入列表"], ["取消", "离开"]]
	return [["确定", T_SAVE if sc.save_mode else T_TAKE], ["取消", "回分类" if show_ring else "离开"]]


# ---- 按键：列表上 Q／E 整页翻（按列数×可见行数跳）；其余照旧走 XStarWarehouseScene ----

func input(event: InputEvent) -> bool:
	var sc := scene
	var d := XMenu.page_dir(event)
	if d != 0 and sc.mode == "list" and not sc.data.is_empty():
		var step := maxi(list.visible_rows() * cols(), 1)
		var i := clampi(sc.index + d * step, 0, sc.data.size() - 1)
		if i != sc.index:
			XSound.system(0)
			sc._select(i)
		return true
	return false


func _on_ring_changed(i: int) -> void:
	if _syncing:
		return
	var sc := scene
	if sc.mode == "list":
		sc.cancel()
	sc._set_category(i)


func _on_ring_clicked(i: int) -> void:
	if _syncing:
		return
	if scene.mode == "category" and i == scene.category:
		scene.ok()


func _on_list_index(i: int) -> void:
	if _syncing:
		return
	var sc := scene
	if sc.mode == "category":
		sc.ok()
	if sc.mode == "list" and i != sc.index:
		XSound.system(0)
		sc._select(i)


func _on_list_click(i: int) -> void:
	if _syncing:
		return
	var sc := scene
	if sc.mode == "category":
		sc.ok()
		if sc.mode == "list" and i != sc.index:
			sc._select(i)
		return
	if i == sc.index:
		sc.ok()


func _on_card_button(_i: int) -> void:
	if scene.mode == "list":
		scene.ok()


func _on_card_gui(_event: InputEvent) -> void:
	pass   # 星级仓库的主按钮不会变灰（存放不行的另弹提示、取出恒可点），没有灰按钮要处理


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		scene.cancel()
		accept_event()


# ---- 没有环时左块的主视觉：箱子图标＋「存放」／「取出」＋这一类的件数 ----

func _draw_left_visual() -> void:
	if show_ring:
		return
	var lb := layout.left.size
	var tex := XUiSkin.icon(CAT_ICONS[0])
	var c := Vector2(lb.x / 2.0, lb.y / 2.0 - 40.0)
	if tex != null:
		layout.left.draw_texture_rect(tex, Rect2(c - Vector2(48, 48), Vector2(96, 96)), false)
	var f := XUiSkin.font("title")
	var t := T_SAVE if scene.save_mode else T_TAKE
	var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_CARD).x
	XUiSkin.ds(layout.left, f, Vector2(c.x - tw / 2.0, c.y + 90.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_CARD, XUiSkin.GOLD)
	var body := XUiSkin.font("body")
	var n := "%d 件" % scene.data.size()
	var nw := body.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
	XUiSkin.ds(layout.left, body, Vector2(c.x - nw / 2.0, c.y + 122.0), n, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, XUiSkin.TEXT_2)
