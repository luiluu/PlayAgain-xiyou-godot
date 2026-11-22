class_name XSkinCraftingPage
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】T299 卡 K：制作新布局（T254 3.5；版型一 XSkinTemplatePage 的手动用法，同商店 XSkinShopPage 的做法）。
## 只管「怎么摆、怎么画、点了等于按了哪个键」：配方、数量、制作、锻造选原件这些全部还是 XCraftingScene 原来的代码
## （同一套 mode／cat_index／index／amount／picks…），XCraftingScene 每次 _refresh 后 sync() 按状态重画。
## 旧页 → 新页（T254 3.5 对应表）：
## - 类别窗横排 4 格 → 左环 4 个球；类别等级窗 → 环下一条「打造等级 5」＋「340 / 900」＋8px 条，满级写「已满级」。
## - 配方列表「名字＋x可做数」→ 列表行尾「可做 N」（GOLD_LIGHT）；做不了的变灰，行尾写原因（等级不够／材料不够／精魂不够）。
## - 帮助窗（结果说明）→ 右牌名字下的说明；详情（等级需求、材料、费用）→ 右牌「要求」（够 ✓ 绿、不够 ✗ 橙）「材料」（持有 / 需要，不够橙）「费用」。
## - 数量确认窗＋五个按钮 → 右牌底常驻数量选择（XSkinStepper）＋主按钮「制作」：列表上按确定落到数量条（confirm 态），
##   ←/→ ±1、↑/↓ ±10、E 最多、Q 回 1、数字键，再按确定制作；取消回列表、数量复位。触屏在列表态直接点钮、点主按钮。
## - 金币窗 → 右上货币。结果弹窗「N x 名字 制作成功!」→ 提示道（金色），全失败同样走提示道；不再停在弹窗态。
## - 锻造配方：选原件 → 列表换成原件列表（面包屑「锻造 › 选原件」），不能锻的变灰写原因；Shift 或 Y（触屏点提示胶囊）右牌在
##   「锻造后」和「这一件的词条」之间切换（同旧页 source_shown）；锻造多出的几行说明进右牌「锻造后」一节。
## 新皮肤关着、或 XSkinMenuTreePage.ENABLED＝false（卡 K 一个开关）时 XCraftingScene 不建这一页，旧页一行不变。

## 玩家可见文字（待小A 审）
const T_EMPTY := "这一类还没有配方"
const T_FAIL := "制作失败"
const T_PICK := "选原件"
const PICK_CRUMB := ["锻造", "选原件"]
const BAR_H := 8.0
const FOOT_LINE_H := 30.0

var scene: XCraftingScene
var _syncing := false
var _list_key := []
var stepper: XSkinStepper
var foot: Control
var crumb_node: XSkinCrumb
var level_bar: Control


func _init(s: XCraftingScene) -> void:
	scene = s
	name = "SkinCraftingPage"
	title = "制作"
	group_key = "workshop"   # 从主菜单「工坊」进：画页签条（T254 3.0，同卡 J；小A核 P2-4）
	columns = 1
	row_height = XUiSkin.ROW_H
	right_w = 352.0
	auto_nav = false
	focus = "ring"
	hint_list = [["确定", "选择"], ["取消", "离开"]]


func _ready() -> void:
	super()
	list.empty_center = true
	list.right2_w = 0.0
	var cats := []
	for i in XCrafting.CATEGORIES.size():
		cats.append({"key": str(i), "name": XCrafting.CATEGORIES[i], "icon": XCrafting.CATEGORY_ICONS[i]})
	set_categories(cats, scene.cat_index)
	ring.changed.connect(_on_ring_changed)
	ring.activated.connect(_on_ring_clicked)
	list.index_changed.connect(_on_list_index)
	list.activated.connect(_on_list_click)
	card_button.connect(_on_card_button)
	crumb_node = XSkinCrumb.new()
	crumb_node.visible = false
	list_panel.add_child(crumb_node)
	foot = Control.new()
	foot.name = "CraftFoot"
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(foot)
	stepper = XSkinStepper.new()
	stepper.sound = false   # 音由这边照旧页 change_amount（变了才响光标音）
	stepper.value_changed.connect(_on_stepper_value)
	stepper.touched.connect(_on_stepper_touched)
	foot.add_child(stepper)
	level_bar = Control.new()
	level_bar.name = "CraftLevel"
	level_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_bar.draw.connect(_draw_level)
	layout.left.add_child(level_bar)
	gui_input.connect(_on_gui)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_place_extra()


func relayout() -> void:
	super()
	_place_extra()


func _place_extra() -> void:
	if crumb_node == null or list == null:
		return
	var cs := layout.center.size
	var lx := list.position.x
	var shift := XSkinCrumb.H + 4.0 if crumb_node.visible else 0.0
	crumb_node.position = Vector2(XUiSkin.PAD + 8, LIST_TOP - 6.0)
	crumb_node.size = Vector2(cs.x - XUiSkin.PAD * 2 - 8, XSkinCrumb.H)
	list.position = Vector2(lx, LIST_TOP + shift)
	var n := floori((cs.y - LIST_TOP - shift - FOOTER_H) / float(row_height))
	list.size = Vector2(cs.x - lx - 8.0, n * row_height)
	var lb := layout.left.size
	level_bar.position = Vector2(XUiSkin.PAD, ring.position.y + ring.size.y + 4.0 + maxf(0.0, XUiSkin.fs(XUiSkin.FS_AUX_MAX) - XUiSkin.FS_AUX_MAX))   # 字体调大时环下球名也变高，往下让
	level_bar.size = Vector2(lb.x - XUiSkin.PAD * 2, 56.0)
	_place_foot()


# ---- 按状态重画 ----

func sync() -> void:
	if layout == null:
		return
	_syncing = true
	var sc := scene
	for w in [sc.help_win, sc.cat_win, sc.list_win, sc.detail_win, sc.confirm_win, sc.gold_win, sc.gauge_win, sc.popup_win]:
		w.visible = false
	sc._buttons.visible = false
	sc.source_card.visible = false
	if ring.index != sc.cat_index:
		ring.select(sc.cat_index, false)
	ring_center = [str(sc.list.size()), "种"]
	ring.queue_redraw()
	var picking := sc.mode == "pick"
	crumb_node.visible = picking
	crumb_node.set_parts(PICK_CRUMB)
	_sync_list()
	_sync_card()
	match sc.mode:
		"category":
			set_focus("ring")
		"list", "pick":
			set_focus("list")
		"confirm":
			set_focus("stepper" if stepper.visible else "card")
			list.active = true   # 列表那一行照旧亮着：焦点只是落到右牌底
	stepper.focused = sc.mode == "confirm" and stepper.visible
	list.quiet = sc.mode == "confirm"   # T359 D256：数量态列表选中行降静默
	if sc.mode != "confirm":
		stepper.close_editor()
	set_hint_list(_hints())
	_syncing = false
	_place_extra()
	list_panel.queue_redraw()
	level_bar.queue_redraw()
	top_layer.queue_redraw()


func _sync_list() -> void:
	var sc := scene
	var s := XState.current
	var rows := []
	var idx := 0
	if sc.mode == "pick":
		list_title = str(XCrafting.item_of(sc.current().result).get("name", ""))
		list.empty_text = ""
		for p in sc.picks:
			rows.append(pick_row(s, int(sc.current().id), p))
		idx = sc.pick_index
	else:
		list_title = XCrafting.CATEGORIES[sc.cat_index]
		list.empty_text = T_EMPTY
		for r in sc.list:
			rows.append(recipe_row(s, r))
		idx = maxi(sc.index, 0)
	var key := [sc.mode == "pick", sc.cat_index, rows.map(func(r): return [r.text, r.get("right", ""), r.get("disabled", false), r.get("sub", "")])]
	if key != _list_key:
		_list_key = key
		set_items(rows, clampi(idx, 0, maxi(rows.size() - 1, 0)))
	elif list.index != idx and idx < rows.size():
		list.select(idx)


## 配方一行：图标、名字（品质色）、行尾「可做 N」；做不了的变灰写原因
static func recipe_row(s: XState, r: Dictionary) -> Dictionary:
	var it := XCrafting.item_of(r.result)
	var row := {"text": str(it.get("name", "")), "icon": int(it.get("iconIndex", 0)), "color": XQuality.list_color(it)}
	if XCrafting.craftable(s, r):
		row.right = "可做 %d" % XCrafting.amount_craftable(s, r)
		row.right_color = XUiSkin.GOLD_LIGHT
	else:
		row.right = block_reason(s, r)
		row.disabled = true
	return row


## 做不了的原因（行尾）：等级 → 材料 → 费用
static func block_reason(s: XState, r: Dictionary) -> String:
	if not XCrafting.has_level(s, r):
		return "等级不够"
	if XGrowthForge.is_forge_recipe(int(r.id)):
		return "材料不够"
	if not XCrafting.has_materials(s, r):
		return "材料不够"
	if not XCrafting.has_gold(s, r):
		return currency_unit() + "不够"
	return "做不了"


static func currency_unit() -> String:
	var u := str(XDB.system().get("currencyUnit", ""))
	return u if u != "" else "精魂"


## 原件一行：名字（品质色）＋小字「品质 · 层数 · 已装备／背包」；不能锻的变灰写原因
static func pick_row(s: XState, id: int, item: Dictionary) -> Dictionary:
	var row := {"text": str(item.get("name", "")), "icon": int(item.get("iconIndex", 0)), "color": XQuality.list_color(item), "sub": XGrowthForge.source_row(s, id, item)}
	if not XGrowthForge.can_forge(s, id, item):
		row.disabled = true
		row.right = "材料不够" if s.item_count(XGrowthForge.FRAGMENT) < XGrowthForge.FRAGMENT_COST or s.item_count(XGrowthForge.HAMMER) < XGrowthForge.HAMMER_COST else "不能锻造"
	return row


# ---- 右牌 ----

func _sync_card() -> void:
	var sc := scene
	var s := XState.current
	stepper.visible = false
	if sc.mode == "category":
		var n_ok := sc.list.filter(func(r): return XCrafting.craftable(s, r)).size()
		set_card({"title": XCrafting.CATEGORIES[sc.cat_index], "icon": XUiSkin.icon(XCrafting.CATEGORY_ICONS[sc.cat_index]),
			"subtitle": level_text(s, sc.cat_index), "sections": [{"title": "", "lines": [{"left": "配方", "right": str(sc.list.size())},
				{"left": "现在能做", "right": str(n_ok), "right_color": XUiSkin.GOLD_LIGHT}]}], "buttons": []})
		card.visible = true
		_place_foot()
		return
	var r := sc.current()
	if sc.mode != "pick" and r.is_empty() or sc.mode == "list" and sc.list.is_empty():
		set_card({"title": "", "sections": [], "buttons": []})   # 空列表右牌不画
		card.visible = false
		_place_foot()
		return
	card.visible = true
	if sc.mode == "pick" and sc.source_shown and not sc.forge_shown().is_empty():
		var d := XSkinItemPage.card_data(sc.forge_shown())   # Y／Shift：这一件的词条
		d.buttons = [{"text": "选这件", "primary": true, "disabled": not XGrowthForge.can_forge(s, int(r.id), sc.forge_shown())}]
		set_card(d)
		_place_foot()
		return
	set_card(recipe_card(r))
	_place_foot()


func recipe_card(r: Dictionary) -> Dictionary:
	var sc := scene
	var s := XState.current
	var it := XCrafting.item_of(r.result)
	var forge := XGrowthForge.is_forge_recipe(int(r.id))
	var desc := str(it.get("description", ""))
	if forge:
		desc = XGrowthForge.help_text(int(r.id), sc.forge_shown(), false, false)
	desc = _plain(desc)
	var picking := sc.mode == "pick"
	if picking:
		desc = ""   # 选原件时：选的是哪件列表上已亮着，「品质、词条…保留」锻造后第一行也有；省下高度给「锻造后」（小A核 P2-3）
	var secs := []
	var cat := XCrafting.category_id(r)
	var lv_ok := int(r.level) <= XCrafting.highest_level(s)
	var cl_ok := XCrafting.has_craft_level(s, r)
	if not (picking and lv_ok and cl_ok):   # 选原件时已满足的「要求」省掉（能进选原件就是都满足了）
		secs.append({"title": "要求", "lines": [
		{"left": "角色等级 %d" % int(r.level), "right": "✓" if lv_ok else "✗", "right_color": XUiSkin.UP if lv_ok else XUiSkin.DOWN},
		{"left": "%s等级 %d" % [XCrafting.CATEGORIES[cat] if cat >= 0 else "", int(r.craftLevel)], "right": "✓" if cl_ok else "✗", "right_color": XUiSkin.UP if cl_ok else XUiSkin.DOWN}]})
	var mats := []
	for m in r.materials:
		var have := XCrafting.material_count(s, m, r)
		var enough := have >= int(m.amount)
		mats.append({"left": str(XCrafting.item_of(m).get("name", "")), "right": "%d / %d" % [have, int(m.amount)],
			"right_color": XUiSkin.TEXT if enough else XUiSkin.DOWN, "color": XUiSkin.TEXT if enough else XUiSkin.DOWN})
	if not mats.is_empty():
		secs.append({"title": "材料", "lines": mats})
	if int(r.goldCost) > 0:
		secs.append({"title": "费用", "lines": [{"left": currency_unit(), "right": XSkinTemplatePage._group(int(r.goldCost)),
			"right_color": XUiSkin.GOLD_LIGHT if XCrafting.has_gold(s, r) else XUiSkin.DOWN}]})
	if forge:
		secs.append({"title": "锻造后", "rows": XGrowthForge.detail_lines(int(r.id), sc.forge_shown()).map(func(t): return {"text": str(t), "color": XUiSkin.TEXT_2})})
	var ok := XCrafting.craftable(s, r)
	var btn := {"text": XCraftingScene.CRAFT_TEXT, "primary": true, "disabled": not ok}
	if forge and sc.mode == "list":
		btn.text = T_PICK
	elif sc.mode == "pick":
		btn = {"text": "选这件", "primary": true, "disabled": not XGrowthForge.can_forge(s, int(r.id), sc.forge_shown())}
	if not forge and ok and bool(r.get("craftMultiple", true)) and sc.mode in ["list", "confirm"]:
		stepper.visible = true
		stepper.enabled = true
		stepper.set_range(1, maxi(1, XCrafting.amount_craftable(s, r)), sc.amount if sc.mode == "confirm" else 1)
	var sub: String = XCrafting.CATEGORIES[cat] if cat >= 0 else ""
	return {"icon": XUiSkin.icon(int(it.get("iconIndex", 0))), "title": str(it.get("name", "")), "title_color": XQuality.list_color(it),
		"subtitle": sub, "desc": desc, "sections": secs, "buttons": [btn], "button_index": 0 if sc.mode == "confirm" and not stepper.visible else -1}


## 说明里的转义码（\c[n]、\i[n]…）去掉，只留字
static func _plain(t: String) -> String:
	var esc := RegEx.create_from_string("(?i)(?:\\\\|\u001b)(?:[a-z]+\\[[^\\]]*\\]|[{}.|!><^$])")
	return esc.sub(XMVText.convert_escapes(t), "", true).strip_edges()


static func level_text(s: XState, cat: int) -> String:
	return "%s等级 %d" % [XCrafting.CATEGORIES[cat], XCrafting.craft_level(s, cat)]


# ---- 牌底：数量条 ----

func _place_foot() -> void:
	if foot == null or card == null:
		return
	var h := XSkinStepper.H if stepper.visible else 0.0
	card.reserve_bottom = h + (XUiSkin.GRID if h > 0 else 0.0)
	var bottom := card.size.y - card.pad - (XSkinCard.BUTTON_H + XUiSkin.GRID if not card.buttons.is_empty() else 0.0)
	foot.position = Vector2(card.pad, bottom - h)
	foot.size = Vector2(card.size.x - card.pad * 2, h)
	if stepper.visible:
		stepper.position = Vector2.ZERO
		stepper.size = Vector2(foot.size.x, XSkinStepper.H)
	card.queue_redraw()


# ---- 环下一条：类别等级＋经验条 ----

## 环下一条的三样：[左「打造等级 5」, 右「340 / 900」或「已满级」, 条的比例]
static func level_parts(s: XState, cat: int) -> Array:
	var lv := XCrafting.craft_level(s, cat)
	if lv >= XCrafting.MAX_LEVEL:
		return [level_text(s, cat), "已满级", 1.0]
	var e := XCrafting.craft_exp(s, cat)
	var nx := XCrafting.exp_next(s, cat)
	return [level_text(s, cat), "%s / %s" % [XSkinTemplatePage._group(e), XSkinTemplatePage._group(nx)], clampf(float(e) / maxf(1.0, float(nx)), 0.0, 1.0)]


func _draw_level() -> void:
	var s := XState.current
	if s == null:
		return
	var parts := level_parts(s, scene.cat_index)
	var maxed := str(parts[1]) == "已满级"
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var w := level_bar.size.x
	var fs := XUiSkin.fs(XUiSkin.FS_AUX_MAX)
	var f := body if maxed else num
	var rfs := XUiSkin.fs(XUiSkin.FS_AUX)
	var rw := f.get_string_size(str(parts[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, rfs).x
	var fit := XSkinList.fit_text(body, str(parts[0]), maxf(w - rw - 12.0, 40.0), fs, 15)   # 字体调大时先缩字，不压右边的经验数
	XUiSkin.ds(level_bar, body, Vector2(0, fs), str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1]), XUiSkin.TEXT)
	XUiSkin.ds(level_bar, f, Vector2(w - rw, fs), str(parts[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, XUiSkin.GOLD_LIGHT if maxed else XUiSkin.TEXT_2)
	var y := fs + 10.0
	level_bar.draw_rect(Rect2(0, y, w, BAR_H), Color(XUiSkin.LINE, 0.18))
	if float(parts[2]) > 0.0:
		level_bar.draw_rect(Rect2(0, y, w * float(parts[2]), BAR_H), XUiSkin.GOLD)


# ---- 提示道 ----

## 做完：成功金色、全失败照常走提示道（新皮肤下 XSkinNoticeLane，关着时 XToast）
static func notify(text: String, success: bool) -> void:
	if XSkinNoticeLane.on():
		XToast.shown.append(text)
		XSkinNoticeLane.push({"kind": "toast", "title": text, "color": XUiSkin.GOLD if success else XUiSkin.TEXT})
	else:
		XToast.show_text(text, true)


# ---- 按键提示 ----

func _hints() -> Array:
	var sc := scene
	match sc.mode:
		"category":
			return [["← / →", "换类别"], ["确定", "选择"], ["取消", "离开"]]
		"list":
			var r := sc.current()
			var verb := T_PICK if not r.is_empty() and XGrowthForge.is_forge_recipe(int(r.id)) else "定数量"
			return [["确定", verb], ["Q / E", "翻页"], ["取消", "返回"]]
		"pick":
			return [["确定", "选这件"], ["Y", "返回升级预览" if sc.source_shown else "看词条"], ["取消", "返回"]]
		"confirm":
			if stepper.visible:
				return [["← / →", "±1"], ["↑ / ↓", "±10"], ["Q / E", "1 / 最多"], ["确定", XCraftingScene.CRAFT_TEXT], ["取消", "返回"]]
			return [["确定", XCraftingScene.CRAFT_TEXT], ["取消", "返回"]]
	return [["确定", "选择"], ["取消", "返回"]]


# ---- 按键：环走新布局、数量条走 XSkinStepper、Y 看词条；其余（列表上下、翻页、确定、取消、Shift）交回旧代码 ----

## 用掉了返回 true（XCraftingScene._unhandled_input 开头调）
func input(event: InputEvent) -> bool:
	var sc := scene
	match sc.mode:
		"category":
			var d := 0
			if event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_left", true):
				d = -1
			elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_right", true):
				d = 1
			if d != 0:
				sc.select_category(posmod(sc.cat_index + d, XCrafting.CATEGORIES.size()))
				return true
			return XMenu.page_dir(event) != 0
		"pick":
			if XSkinCard._is_y(event):
				sc.toggle_source()
				return true
		"confirm":
			if stepper.visible and not event.is_action_pressed("ui_accept") and not event.is_action_pressed("ui_cancel"):
				return stepper.handle_input(event)
	return false


# ---- 点击 → 同样的状态变化 ----

func _on_ring_changed(i: int) -> void:
	if _syncing:
		return
	var sc := scene
	while sc.mode != "category":   # 列表、选原件、数量条上点了别的球：先一层层退回类别（同取消）
		sc.cancel()
	sc.select_category(i)


func _on_ring_clicked(i: int) -> void:
	if _syncing:
		return
	if scene.mode == "category" and i == scene.cat_index:
		scene.ok()


func _on_list_index(i: int) -> void:
	if _syncing:
		return
	var sc := scene
	match sc.mode:
		"category":
			if sc.list.is_empty():
				return
			sc.ok()   # 类别态点列表行＝进列表，再落到点的那一行
			sc.select(i)
		"list":
			sc.select(i)
		"pick":
			if i != sc.pick_index and i < sc.picks.size():
				sc.pick_index = i
				XSound.system(0)
				sc._refresh()
		"confirm":
			sc.cancel()   # 数量条上点了别的行：回列表、换行（数量复位）
			sc.select(i)


func _on_list_click(i: int) -> void:
	var sc := scene
	match sc.mode:
		"category":
			if not sc.list.is_empty():
				sc.ok()
				sc.select(i)
		"list":
			if i == sc.index:
				sc.ok()
		"pick":
			if i == sc.pick_index:
				sc.ok()


func _on_card_button(_i: int) -> void:
	var sc := scene
	match sc.mode:
		"list":
			sc.ok()
			if sc.mode == "confirm":
				sc.ok()   # 列表态点主按钮＝确定、确定（数量 1）
		"pick", "confirm":
			sc.ok()


func _on_stepper_touched() -> void:
	var sc := scene
	if sc.mode == "list":
		var r := sc.current()
		if not r.is_empty() and not XGrowthForge.is_forge_recipe(int(r.id)) and XCrafting.craftable(XState.current, r):
			sc.ok()   # 列表态点数量钮：先落到数量条（同按确定），钮接着改数


func _on_stepper_value(v: int) -> void:
	if _syncing:
		return
	var sc := scene
	if sc.mode != "confirm":
		stepper.set_value(1, false)
		return
	var mx := maxi(1, XCrafting.amount_craftable(XState.current, sc.current()))
	var nv := clampi(v, 1, mx)
	if nv != sc.amount:
		sc.amount = nv
		XSound.system(0)
	sc._refresh()


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		scene.cancel()
		accept_event()
