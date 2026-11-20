class_name XSkinWarehousePage
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】T306 卡 N：仓库新布局（T254 3.9；版型一，手动用法，同商店、角色仓库的做法）。
## 存取规则、满仓不能存（蜂鸣）、光标不动、取消逐级退回、系统音全部还是 XWarehouseScene／XWarehouse 原来的代码，
## 这一页只管「怎么摆、怎么画、点了等于按了哪个键」，XWarehouseScene 每次 _refresh 后 sync() 按状态重画。
## 旧页 → 新页（T254 3.9 对应表）：
## - 标题＝仓库名 → 页名（XWarehouse.last_active）。
## - 选项「取出／储存」→ 列表上方两枚页内页签「存进去（背包）」「取出来（仓库）」，Q／E 切换（旧 option；不再有「先进选项窗」这一层，进页就在分类环上）。
## - 分类「物品／武器／护甲／重要物品」→ 环上 4 个球（名字后带该类件数）；环上 ↑↓／←→ 换类，确定进列表，列表上取消回环，环上取消离开。
## - 列表两列、图标、名字（品质色）、行尾数量或「序号/9,999」、没看过的画 NEW → 16:9 一列、20:9 两列（上下键按列数跳）；行尾同样的字；「新」小标。
## - 信息「可用空间: 剩余 / 上限」→ 环下面一条「仓库空间　剩 R / M」＋8px 条（满了条变橙，DOWN）。
## - 确定存取一件、光标不动；仓库满了不能存 → 照旧（蜂鸣）；右牌主按钮变灰写「仓库满了」。
## - 原来没有说明卡 → 右牌用标准详情牌（XSkinItemPage.card_data，多出来的，不算删）；名字下「仓库里 ×N」／「背包里 …」。
## 新皮肤关着、或 ENABLED＝false 时 XWarehouseScene 不建这一页，旧页一行不变。

## T306 回退开关：false＝天启篇新皮肤下仓库、星级仓库、深渊商人三页都回旧页（一个开关管三页）
static var ENABLED := true
## 玩家可见文字（待小A 审）
const T_TABS := ["存进去（背包）", "取出来（仓库）"]
const T_SPACE := "仓库空间"
const T_EMPTY := "这一类没有东西"
const T_FULL := "仓库满了"
const T_DEPOSIT := "存入"
const T_WITHDRAW := "取出"
## 环上四个球的图标（同物品页的分类图标）
const ICONS := ["item", "weapon", "armor", "keyItem"]
const BAR_H := 8.0
## 两列的最小视口宽（16:9 为 1280，20:9 为 1600；中间一档也只排一列）
const WIDE_VIEW_W := 1500.0

var scene: XWarehouseScene
var inner_tabs: XSkinInnerTabs
var _syncing := false
var _list_key := []
var _ring_key := []
var _tab_key := -1


func _init(s: XWarehouseScene) -> void:
	scene = s
	name = "SkinWarehousePage"
	title = XWarehouse.last_active
	group_key = ""            # 从 NPC 进的页不画页签条（T254 3.0）
	columns = 1
	row_height = XUiSkin.ROW_H
	right_w = 352.0
	auto_nav = false
	show_ring = true
	focus = "ring"
	currencies = []
	hint_list = []


func _ready() -> void:
	super()
	list.empty_center = true
	list.right2_w = 0.0
	list.empty_text = T_EMPTY
	ring.changed.connect(_on_ring_changed)
	ring.activated.connect(_on_ring_clicked)
	list.index_changed.connect(_on_list_index)
	list.activated.connect(_on_list_click)
	card_button.connect(_on_card_button)
	card.gui_input.connect(_on_card_gui)
	inner_tabs = XSkinInnerTabs.new()
	inner_tabs.changed.connect(_on_tab)
	list_panel.add_child(inner_tabs)
	layout.left.draw.connect(_draw_space)
	gui_input.connect(_on_gui)
	mouse_filter = Control.MOUSE_FILTER_PASS
	relayout()


## 一屏几列：横屏铺满档（20:9）两列，其余一列（scene 的上下键按它跳）
func cols() -> int:
	if layout == null:
		return 1
	return 2 if layout.view_size().x >= WIDE_VIEW_W else 1


## 页签在列表标题那一行，列表整体下移（同商店 _place_tabs）
func relayout() -> void:
	super()
	if inner_tabs == null or list == null:
		return
	list.columns = cols()
	var cs := layout.center.size
	var lx := list.position.x
	inner_tabs.position = Vector2(XUiSkin.PAD + 8, LIST_TOP - 6.0)
	inner_tabs.size = Vector2(cs.x - XUiSkin.PAD * 2 - 8, XSkinInnerTabs.H)
	var shift := XSkinInnerTabs.H + 4.0
	list.position = Vector2(lx, LIST_TOP + shift)
	var rows := floori((cs.y - LIST_TOP - shift - FOOTER_H) / float(row_height))
	list.size = Vector2(cs.x - lx - 8.0, rows * row_height)


# ---- 按状态重画 ----

func sync() -> void:
	if layout == null:
		return
	_syncing = true
	var sc := scene
	for w in [sc.title_win, sc.option_win, sc.cat_win, sc.list_win, sc.info_win]:
		w.visible = false
	var s := XState.current
	var withdraw := sc.option == 0
	# 环：四类，名字后带件数（当前存／取方向）
	var names := XWarehouseScene.cat_names()
	var cats := []
	var counts := []
	for i in 4:
		var sym: String = XWarehouse.CATEGORIES[i]
		var n := (XWarehouse.stored(s, sym) if withdraw else XWarehouse.carried(s, sym)).size()
		counts.append(n)
		cats.append({"key": sym, "name": names[i], "icon": XSkinItemPage.CAT_ICONS.get(sym, 0), "count": n})
	var ck := [sc.option, cats.map(func(c): return [c.name, c.count])]
	if ck != _ring_key:
		_ring_key = ck
		set_categories(cats, maxi(sc.category, 0))
	elif ring.index != maxi(sc.category, 0):
		ring.select(maxi(sc.category, 0), false)
	if _tab_key != sc.option:
		_tab_key = sc.option
		inner_tabs.set_tabs(T_TABS, 1 - sc.option)
	elif inner_tabs.index != 1 - sc.option:
		inner_tabs.select(1 - sc.option, false)
	list_title = str(names[maxi(sc.category, 0)])
	# 列表：分类态也显示该类内容（旧页开场就这样），只是没光标
	var rows := []
	for e in sc.data:
		rows.append(row_for(e, withdraw))
	var idx := sc.index
	if sc.mode == "list" and not rows.is_empty() and idx >= rows.size():
		idx = rows.size() - 1   # 取空末尾一格后旧页光标停在空格；新页没有空格，夹回最后一格（同角色仓库）
		sc.index = idx
	var key := [sc.option, sc.category, cols(), rows.map(func(r): return [r.text, r.right, r.get("tags", [])])]
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


## 一行：图标、名字（品质色）、行尾数量或「序号/9,999」、「新」小标（旧 NEW，从不记看过）
func row_for(e: Dictionary, withdraw: bool) -> Dictionary:
	var rec: Dictionary = e.rec
	var right := "×" + XMenu._group(int(e.qty)) if withdraw else XItemRow.right_text(e)
	var r := {"text": XQuality.list_name(rec), "icon": int(rec.get("iconIndex", 0)), "color": XGear.color(rec), "right": right}
	if XItemRow.shows_new(XState.current, rec):
		r["tags"] = ["新"]
	return r


func current_entry() -> Dictionary:
	var sc := scene
	var i := maxi(sc.index, 0)
	return sc.data[i] if i < sc.data.size() else {}


## 「仓库空间　剩 R / M」（测试按对应表核：R、M 同 XWarehouse.info_text 的两个数）
func space_line() -> String:
	var s := XState.current
	return "%s　剩 %d / %d" % [T_SPACE, XWarehouse.max_capacity(s) - XWarehouse.used(s), XWarehouse.max_capacity(s)]


## 右牌：标准详情牌；分类态（环上）只预览第 1 件、不带按钮
func card_data() -> Dictionary:
	var sc := scene
	var e := current_entry()
	if e.is_empty():
		return {"title": "", "sections": [], "buttons": []}
	var rec: Dictionary = e.rec
	var d := XSkinItemPage.card_data(rec)
	d.title = str(d.title).replace(XItemMarks.LOCK, "").replace(XItemMarks.TOP, "").strip_edges()
	var sub := Array(str(d.subtitle).split(" · ", false)).filter(func(x): return not str(x).begins_with("持有"))
	var withdraw := sc.option == 0
	if withdraw:
		sub.append("仓库里 ×%s" % XMenu._group(int(e.qty)))
	elif XItemMarks.is_gear(rec):
		sub.append("背包里第 %d 件" % int(e.get("carry", 0)))
	else:
		sub.append("背包里 ×%s" % XMenu._group(int(e.get("count", 0))))
	d.subtitle = " · ".join(sub)
	var full := not withdraw and not XWarehouse.has_space(XState.current)
	if sc.mode == "list":
		d.buttons = [{"text": T_FULL if full else (T_WITHDRAW if withdraw else T_DEPOSIT), "primary": true, "disabled": full}]
	else:
		d.buttons = []
	return d


func _sync_card() -> void:
	var d := card_data()
	card.visible = not current_entry().is_empty()   # 空列表右牌不画（T254 3.0「空列表」）
	d.button_index = -1
	set_card(d)


func _hints() -> Array:
	var sc := scene
	if sc.mode == "category":
		return [["确定", "进入列表"], ["Q / E", "存／取"], ["取消", "离开"]]
	return [["确定", T_WITHDRAW if sc.option == 0 else T_DEPOSIT], ["Q / E", "存／取"], ["取消", "回分类"]]


# ---- 按键：Q／E 换页签；环上 ↑↓ 也换类；其余（上下左右、确定、取消）照旧走 XWarehouseScene ----

func input(event: InputEvent) -> bool:
	var sc := scene
	if XMenu.page_dir(event) != 0:
		switch_tab(posmod(1 - sc.option + XMenu.page_dir(event), 2))
		return true
	return false


## 页签下标（0＝存进去，1＝取出来）换成 scene.option（0 取出、1 储存）
func switch_tab(i: int) -> void:
	scene.switch_option(1 - i)


func _on_tab(i: int) -> void:
	if _syncing:
		return
	switch_tab(i)


func _on_ring_changed(i: int) -> void:
	if _syncing:
		return
	var sc := scene
	if sc.mode == "list":
		sc.cancel()   # 列表态点别的球：先回到环上（同取消），再换类
	sc.set_category(i)


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
		sc.ok()   # 环上点列表行＝进列表，再落到点的那一行
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


## 点到灰掉的主按钮：蜂鸣（同按确定），焦点框不留在灰按钮上（同角色仓库）
func _on_card_gui(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for i in card.buttons.size():
		if card.button_rect(i).has_point(event.position) and bool(card.buttons[i].get("disabled", false)):
			XSound.system(3)
			_clear_card_focus.call_deferred()
			return


func _clear_card_focus() -> void:
	card.button_index = -1
	card.queue_redraw()


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		scene.cancel()
		accept_event()


# ---- 左块：环下面「仓库空间　剩 R / M」＋ 8px 条 ----

func _draw_space() -> void:
	var s := XState.current
	var lb := layout.left.size
	var mx := maxi(XWarehouse.max_capacity(s), 1)
	var used := XWarehouse.used(s)
	var full := used >= XWarehouse.max_capacity(s)
	var body := XUiSkin.font("body")
	var fs := XUiSkin.fs(XUiSkin.FS_AUX)
	var y := lb.y - 96.0   # 抬高一截，免得压到左下角的背景花饰
	var t := space_line()
	var tw := body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	XUiSkin.ds(layout.left, body, Vector2((lb.x - tw) / 2.0, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.DOWN if full else XUiSkin.TEXT_2)
	var bw := minf(lb.x - 32.0, 240.0)
	var bx := (lb.x - bw) / 2.0
	layout.left.draw_rect(Rect2(bx, y + 14.0, bw, BAR_H), Color(1, 1, 1, 0.22))
	var fw := bw * clampf(float(used) / float(mx), 0.0, 1.0)
	if fw > 0.0:
		layout.left.draw_rect(Rect2(bx, y + 14.0, fw, BAR_H), XUiSkin.DOWN if full else XUiSkin.GOLD)
