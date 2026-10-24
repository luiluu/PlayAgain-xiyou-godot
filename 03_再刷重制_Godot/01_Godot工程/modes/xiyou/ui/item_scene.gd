class_name XItemScene
extends Control
## 物品页（Scene_Item：YEP_ItemCore＋YEP_X_ItemUpgradeSlots＋Galv_NewItemIndication＋HelpExtend＋Codex 装备排序），
## 按正式版运行时逐像素复现（参照截图 04_验证/本地结果/原版参照/70～74，绘制记录见 界面风格.md）。没有顶部说明栏：
## - 分类 (0,0,240,172)：物品／消耗品／武器／护甲／重要物品，居中，可见 4 行；分类阶段列表跟着显示该类物品（无光标）。
## - 状态 (240,1,1040,172)：YEP 物品状态（XItemStatusPainter）。
## - 列表 (0,172,640,548)：XItemRow；武器/护甲含队员身上的装备，按 Codex 装备检索条件筛选排序（XGearQuery；
##   默认品质名次高在前 → 名字拼音 → ID，排序选择存配置）。右上角「装备检索 / 排序」「清除筛选」与检索面板见 XGearSearch。
## - 信息 (640,172,640,548)：图标 (8,2)、名字 x 42（品质色）；装备另画「插槽可用 剩余/总数」（标签右移 215）
##   与「插入n: 材料」（缩小一级）。
## - 操作（占列表位置）：使用 \i[图标]名字、升级（装备）或道具置顶（物品）、出售锁定、取消；不能用的半透明。
## - 升级材料（占列表位置）：XItemRow；不能用的半透明；确定即镶嵌，留在材料列表。取消回到操作。
## - 选人 (0,0,1280,720)：Window_MenuActor，每行 173，头像居中、名字/Lv、HP/MP/TP 量条；使用后留在选人。
## - 说明卡（XHelpCard）跟着列表/材料列表的选中行；操作阶段保留；分类与选人阶段隐藏（v0.10 选人时隐藏）。
## - 道具置顶（Star_ItemTop，只对物品）、出售锁定（Star_ShopOnekey，物品与装备）：见 XItemMarks；做完留在操作菜单。
## - 宝珠镶嵌（YEP_X_AttachAugments＋installNativeOrbRuntime，规则见 XOrbs）：装备的操作菜单在「升级」后每个孔一行
##   「\c[16]孔类型:\c[0] 宝珠／- 空 -」（Augment Slot Format），确定打开宝珠列表（占列表位置，XItemRow；不可选的半透明、
##   确定蜂鸣；孔里有宝珠时首行「取下镶嵌物」，选中它时不显示说明卡）；确定即镶嵌（装备音效），回到操作菜单原行。
##   信息窗在插槽信息之后画「镶嵌物」标题（x −32 居中，系统色）与每个孔一行（x 226）。读数见 tests/fixtures/orb_ui_oracle.json。

signal closed
## 用了带公共事件的物品：关闭后菜单也要关，回地图执行预约（Scene_ItemBase.checkCommonEvent → goto(Scene_Map)）
var to_map := false

const CAT_RECT := Rect2(0, 0, 240, 172)
const STATUS_RECT := Rect2(240, 1, 1040, 172)
const LIST_RECT := Rect2(0, 172, 640, 548)
const INFO_RECT := Rect2(640, 172, 640, 548)
const ACTOR_RECT := Rect2(0, 0, 1280, 720)
const LH := 36.0
const CAT_ROWS := 4
const ACTOR_ROWS := 4
const ACTOR_ROW_H := 173.0          # (720 − 内边距×2) / 4
const SLOT_SHIFT := 215.0           # 正式版把插槽信息右移 215（drawSlotsInfo「居中对齐」改动）

var _mode := "category"             # category / list / action / upgrade / augment / actor
var _cat := 0
var _cat_top := 0
var _index := 0
var _top := 0
var _act := 0
var _actions: Array = []            # [{text, symbol, enabled}]
var _item: Dictionary = {}          # 操作中的物品/装备
var _up_index := 0
var _up_top := 0
var _aug_slot := -1                 # 宝珠列表对应的孔（操作行的 ext）
var _aug_index := 0
var _aug_top := 0
var _actor := 0
var _actor_top := 0
var _pending_seen: Dictionary = {}  # 光标停在上面的新物品：光标离开或换窗口时才记为看过（Galv 只重画前一行）
var cat_win: XMVWindow
var status_win: XMVWindow
var list_win: XMVWindow
var info_win: XMVWindow
var actor_win: XMVWindow
var help_card: XHelpCard
## 「应用到装备列表」的检索条件（Window_ItemList._cqFilter；空为未筛选），换分类仍保留，「清除筛选」清空
var gear_filter := {}
var toolbar: HBoxContainer
var search_panel: XGearSearch


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var op := XUI.MENU_WINDOW_OPACITY
	cat_win = XMVWindow.make(self, CAT_RECT, op, _paint_cat)
	status_win = XMVWindow.make(self, STATUS_RECT, op, _paint_status)
	list_win = XMVWindow.make(self, LIST_RECT, op, _paint_list)
	info_win = XMVWindow.make(self, INFO_RECT, op, _paint_info)
	actor_win = XMVWindow.make(self, ACTOR_RECT, op, _paint_actors)
	for w in [cat_win, list_win, actor_win]:
		w.canvas.blink = true
	help_card = XHelpCard.new()
	add_child(help_card)
	toolbar = XGearSearch.make_toolbar(open_search, clear_filter)
	add_child(toolbar)
	_refresh()


# ---- 装备检索（Codex 网页覆盖层）----
func open_search() -> void:
	if search_panel != null:
		return
	toolbar.visible = false
	help_card.visible = false
	search_panel = XGearSearch.open(self, XGearQuery.collection(XState.current))
	search_panel.applied.connect(_apply_filter)
	search_panel.closed.connect(_search_closed)


func _search_closed() -> void:
	search_panel = null
	toolbar.visible = true
	_refresh()


## applyFilter：换上新条件后选回原来那件，没有就选第一行
func _apply_filter(f: Dictionary) -> void:
	var old := _current()
	gear_filter = f
	var d := entries()
	_index = maxi(0, d.find_custom(func(e): return is_same(e.rec, old)))
	_top = XMenu._scroll_to(_index, _top, _rows())
	_refresh()


func clear_filter() -> void:
	gear_filter = {}
	XGearSearch.filter = XGearQuery.default_view()
	_index = 0
	_top = 0
	_refresh()


# ---- 数据 ----
func _symbol() -> String:
	return XShop.CATEGORIES[_cat][1]


## Window_ItemList.makeItemList：物品按 ID；装备 = 背包（按实例先后）＋队员身上（YEP List Equipped Items），再按 Codex 默认排序。
## 每项 {rec, count | carry | owner}
func entries() -> Array:
	var s := XState.current
	var sym := _symbol()
	var out := []
	if sym in ["item", "consumable", "keyItem"]:
		var ids := s.items.keys().map(func(k): return int(k))
		ids.sort()
		for id in ids:
			var rec := XDB.rec("Items", id)
			if rec.is_empty() or s.item_count(id) <= 0:
				continue
			var itype := int(rec.get("itypeId", 1))
			if (sym == "item" and itype == 1) or (sym == "keyItem" and itype == 2) or (sym == "consumable" and bool(rec.get("consumable", false))):
				out.append({"rec": rec, "count": s.item_count(id)})
		return XItemMarks.apply_list(s, out)
	var bag := bag_gear(sym)
	for i in range(bag.size()):
		out.append({"rec": bag[i], "carry": i + 1})
	for a in s.members():
		for e in a.equip_list():
			if e.kind == sym and not out.any(func(x): return is_same(x.rec, e)):
				out.append({"rec": e, "owner": a})
	return filter_gear(out)


static func instance_no(e: Dictionary) -> int:
	return int(str(e.get("instanceId", "xg:0")).get_slice(":", 1))


## $gameParty.weapons()/armors()：YEP independentItemSort 按基础 ID 排，同基础保持实例先后（正式版运行时读数）；
## 「序号/9,999」的序号即在这里的位置，物品页、装备页、商店出售共用，筛选与排序后不重编
static func bag_gear(kind: String) -> Array:
	var list := XState.current.gear.filter(func(e): return e.kind == kind)
	list.sort_custom(func(a, b): return [int(a.base), instance_no(a)] < [int(b.base), instance_no(b)])
	return list


## Codex installEquipmentStatusRuntime 的 makeItemList：装备按检索条件（gear_filter，没有时用默认条件）筛选并排序，
## 排序选择取配置；「位置」只在物品页生效（仅背包＝carry、仅已装备＝owner）。
func filter_gear(list: Array) -> Array:
	var f: Dictionary = (gear_filter if not gear_filter.is_empty() else XGearQuery.default_view()).duplicate()
	var stored := XGearQuery.sort_settings(XConfig.equipment_sort())
	f.sort = stored.sort
	f.sortTerm = stored.term
	var out := XGearQuery.filter_entries(list, f)
	match str(f.scope):
		"bag":
			out = out.filter(func(e): return e.has("carry"))
		"worn":
			out = out.filter(func(e): return e.has("owner"))
	return out


func _rows() -> int:
	return floori((LIST_RECT.size.y - XMVWindow.PADDING * 2) / LH)


func _current() -> Dictionary:
	var d := entries()
	return d[_index].rec if _index >= 0 and _index < d.size() else {}


## 升级材料：持有的、带升级效果且适用于这类装备的物品（Window_UpgradeItemList）
func materials() -> Array:
	var s := XState.current
	var out := []
	var ids := s.items.keys().map(func(k): return int(k))
	ids.sort()
	for id in ids:
		var rec := XDB.rec("Items", id)
		var data := XGearUpgrade.rule(rec)
		if data.is_empty() or data.get(str(_item.get("kind", "")), []).is_empty():
			continue
		var types: Array = data.get(str(_item.kind) + "Types", []).map(func(v): return int(v))
		if not types.has(0) and not types.has(int(_item.get("wtypeId" if _item.kind == "weapon" else "atypeId", 0))):
			continue
		out.append({"rec": rec, "count": s.item_count(id)})
	return out


func _material() -> Dictionary:
	var d := materials()
	return d[_up_index].rec if _up_index >= 0 and _up_index < d.size() else {}


## 宝珠列表（Window_AugmentItemList）：[{rec（取下行为 {}）, count, enabled}]
func augments() -> Array:
	return XOrbs.list(_item, _aug_slot, XState.current)


func _augment_row() -> Dictionary:
	var d := augments()
	return d[_aug_index] if _aug_index >= 0 and _aug_index < d.size() else {}


## $gameParty.canUse：菜单里能用（occasion 0／2）且持有；不看效果范围——没有目标的（范围 0 等）在 determineItem 里直接用
func _usable(item: Dictionary) -> bool:
	return not item.has("instanceId") and [0, 2].has(int(item.get("occasion", 0))) \
		and XState.current.item_count(int(item.get("id", 0))) > 0 and XItemMarks.can_acquire_item(XState.current, item)


func _make_actions() -> void:
	var label := "\\i[%d]\\c[0]%s" % [int(_item.get("iconIndex", 0)), str(_item.get("name", ""))]
	_actions = [{"text": str(XDB.plugin("YEP_ItemCore").get("Use Command", "使用 %1")).replace("%1", label), "symbol": "use", "enabled": _usable(_item)}]
	if _item.has("instanceId"):
		_actions.append({"text": str(XDB.plugin("YEP_X_ItemUpgradeSlots").get("Upgrade Command", "升级 %1")).replace("%1", label), "symbol": "upgrade", "enabled": true})
		_actions.append_array(augment_actions(_item))
	else:
		_actions.append({"text": "道具置顶", "symbol": "top", "enabled": true})
	_actions.append({"text": "出售锁定", "symbol": "lock", "enabled": true})
	_actions.append({"text": "取消", "symbol": "cancel", "enabled": true})


## Window_ItemActionCommand.addAugmentSlots：每个孔一行（ext＝孔号；不能卸下的孔 augmentSlotEnable 为假时灰显）
static func augment_actions(item: Dictionary) -> Array:
	var out := []
	if str(XDB.plugin("YEP_X_AttachAugments").get("Enable Augments", "true")) != "true":
		return out
	XOrbs.ensure(item)
	var fmt := str(XDB.plugin("YEP_X_AttachAugments").get("Augment Slot Format", "\\c[16]%1:\\c[0] %2"))
	for i in range(item.augmentSlots.size()):
		var text := fmt.replace("%1", str(item.augmentSlots[i])).replace("%2", augment_name(item, i))
		out.append({"text": text, "symbol": "augment", "enabled": item.augmentSlotEnable[i] != false, "ext": i})
	return out


## getAugmentSlotItemName／drawAugmentData：\\i[图标]名字，空孔（或宝珠已不存在）为 No Augment Text
static func augment_name(item: Dictionary, slot: int) -> String:
	var gem := XOrbs.gem_in_slot(item, slot)
	if gem.is_empty():
		return str(XDB.plugin("YEP_X_AttachAugments").get("No Augment Text", "\\c[7]- 空 -"))
	return "\\i[%d]%s" % [int(gem.get("iconIndex", 0)), str(gem.get("name", ""))]


# ---- 刷新 ----
func _refresh() -> void:
	var n_cat: int = XShop.CATEGORIES.size()
	cat_win.up_arrow = _cat_top > 0
	cat_win.down_arrow = _cat_top < n_cat - CAT_ROWS
	var n := entries().size() if _mode in ["category", "list"] else (materials().size() if _mode == "upgrade" else (augments().size() if _mode == "augment" else 0))
	var top := _up_top if _mode == "upgrade" else (_aug_top if _mode == "augment" else _top)
	list_win.up_arrow = _mode in ["list", "category", "upgrade", "augment"] and top > 0
	list_win.down_arrow = _mode in ["list", "category", "upgrade", "augment"] and top < n - _rows()
	var actor_mode := _mode == "actor"
	for w in [cat_win, status_win, list_win, info_win]:
		w.visible = not actor_mode
	actor_win.visible = actor_mode
	for w in [cat_win, status_win, list_win, info_win, actor_win]:
		w.refresh()
	if toolbar != null:
		var gear := entries().filter(func(e): return XItemMarks.is_gear(e.rec)).size()
		(toolbar.get_child(0) as Button).text = XGearSearch.toolbar_label(not gear_filter.is_empty(), gear)
	_update_help()


## updateHelp：列表/材料列表的选中行；新物品停上去即记为看过（光标离开后不再画 NEW）
func _update_help() -> void:
	var rec := {}
	var row := -1
	match _mode:
		"list":
			rec = _current()
			row = _index - _top
		"upgrade":
			rec = _material()
			row = _up_index - _up_top
		"augment":
			rec = _augment_row().get("rec", {})
			row = _aug_index - _aug_top
		"action":
			return
	if rec != _pending_seen:
		_commit_seen()
		if _mode in ["list", "upgrade", "augment"] and XItemRow.shows_new(XState.current, rec):
			_pending_seen = rec
	help_card.show_for(rec if row >= 0 else {})
	if help_card.visible:
		help_card.place_for_row(Rect2(LIST_RECT.position + Vector2(0, XMVWindow.PADDING + row * LH), Vector2(LIST_RECT.size.x, LH)))


func _commit_seen() -> void:
	if not _pending_seen.is_empty():
		XState.current.mark_seen(_pending_seen)
	_pending_seen = {}


func _is_new_drawn(rec: Dictionary) -> bool:
	return XItemRow.shows_new(XState.current, rec)


# ---- 绘制 ----
func _paint_cat(c: XMVCanvas) -> void:
	for i in range(XShop.CATEGORIES.size()):
		var y := (i - _cat_top) * LH
		if y < 0 or y >= c.size.y:
			continue
		if i == _cat:
			c.cursor(Rect2(0, y, c.size.x, LH), _mode == "category")
		c.text(XShop.CATEGORIES[i][0], 6, y, c.size.x - 12, "center")


func _paint_status(c: XMVCanvas) -> void:
	var item := {}
	match _mode:
		"list":
			item = _current()
		"action", "upgrade", "augment", "actor":
			item = _item
	XItemStatusPainter.paint(c, item)


func _paint_list(c: XMVCanvas) -> void:
	match _mode:
		"category", "list":
			var d := entries()
			for i in range(_top, mini(d.size(), _top + _rows())):
				var y := (i - _top) * LH
				if _mode == "list" and i == _index:
					c.cursor(Rect2(0, y, c.size.x, LH))
				XItemRow.paint(c, d[i].rec, y, XItemRow.right_text(d[i]), 1.0, _is_new_drawn(d[i].rec))
		"action":
			for i in range(_actions.size()):
				var y := i * LH
				if i == _act:
					c.cursor(Rect2(0, y, c.size.x, LH))
				var t := XMVText.new(XMVText.convert_escapes(str(_actions[i].text)), 6, y, c.size.x - 12)
				t.run()
				XMVText.paint(c, t.glyphs, 0, 0, 1.0 if _actions[i].enabled else XUI.DIM.a)
		"upgrade":
			var d := materials()
			for i in range(_up_top, mini(d.size(), _up_top + _rows())):
				var y := (i - _up_top) * LH
				if i == _up_index:
					c.cursor(Rect2(0, y, c.size.x, LH))
				var ok := XGearUpgrade.reason(_item, d[i].rec, int(d[i].count)) == ""
				XItemRow.paint(c, d[i].rec, y, XItemRow.right_text(d[i]), 1.0 if ok else XUI.DIM.a, _is_new_drawn(d[i].rec))
		"augment":
			var d := augments()
			for i in range(_aug_top, mini(d.size(), _aug_top + _rows())):
				var y := (i - _aug_top) * LH
				if i == _aug_index:
					c.cursor(Rect2(0, y, c.size.x, LH))
				if d[i].rec.is_empty():
					# drawEmptyIcon：Remove Augment 文字从行首画（图标 x 2、文字 x 36）
					var t := XMVText.new(XMVText.convert_escapes(str(XDB.plugin("YEP_X_AttachAugments").get("Remove Augment", "\\i[1348]取下镶嵌物"))), 0, y, c.size.x)
					t.run()
					XMVText.paint(c, t.glyphs)
				else:
					XItemRow.paint(c, d[i].rec, y, XItemRow.right_text(d[i]), 1.0 if d[i].enabled else XUI.DIM.a, _is_new_drawn(d[i].rec))


func _paint_info(c: XMVCanvas) -> void:
	var item := _current() if _mode == "list" else (_item if _mode in ["action", "upgrade", "augment"] else {})
	paint_info(c, item)


## Window_ItemInfo（YEP_ItemCore＋YEP_X_ItemUpgradeSlots，正式版把插槽行右移 215）
static func paint_info(c: XMVCanvas, item: Dictionary) -> void:
	if item.is_empty():
		return
	var dx := 6.0
	var dw := c.size.x - dx * 2
	c.icon(int(item.get("iconIndex", 0)), dx + 2, 2)
	c.text(XQuality.list_name(item), dx + 36, 0, dw - 36, "left", XGear.color(item), XUI.FONT_SIZE, LH)
	XItemRow.paint_magic_level(c, item, dx, 0)
	if not item.has("instanceId"):
		return
	var dy := LH
	var base := XGear.template(str(item.kind), int(item.base))
	if int(base.get("upgradeSlots", 0)) >= 0:
		c.text(str(XDB.plugin("YEP_X_ItemUpgradeSlots").get("Slots Available", "插槽可用")), dx + SLOT_SHIFT, dy, dw, "left", XUI.SYSTEM, XUI.FONT_SIZE, LH)
		var total := "/" + XMenu._group(int(item.get("originalUpgradeSlots", base.get("upgradeSlots", 0))))
		c.text(total, dx, dy, dw, "right", XUI.TEXT, XUI.FONT_SIZE, LH)
		var left := int(item.get("upgradeSlots", 0))
		c.text(XMenu._group(left), dx, dy, dw - c.text_width(total), "right", XUI.POWER_DOWN if left <= 0 else XUI.TEXT, XUI.FONT_SIZE, LH)
		dy += LH
	if int(base.get("upgradeSlots", 0)) > 0:
		var fmt := str(XDB.plugin("YEP_X_ItemUpgradeSlots").get("Slot Format", "\\}插入%1: %2\\{"))
		var history: Array = item.get("upgrades", [])
		for i in range(history.size()):
			var mat := XDB.rec("Items", int(history[i].get("item", 0)))
			var applied := "\\i[%d]%s" % [int(mat.get("iconIndex", 0)), str(history[i].get("name", mat.get("name", "")))]
			var t := XMVText.new(XMVText.convert_escapes(fmt.replace("%1", str(i + 1)).replace("%2", applied)), dx + SLOT_SHIFT, dy, dw)
			t.run()
			XMVText.paint(c, t.glyphs)
			dy += LH
	# YEP_X_AttachAugments drawAugmentInfo（正式版标题左移 38、宝珠行右移 220）
	var aug := XDB.plugin("YEP_X_AttachAugments")
	if str(aug.get("Show Augment Info", "true")) != "true":
		return
	var title := str(aug.get("Info Title", "镶嵌物"))
	if title != "":
		c.text(title, dx - 38, dy, dw, str(aug.get("Title Alignment", "center")), XUI.SYSTEM, XUI.FONT_SIZE, LH)
		dy += LH
	XOrbs.ensure(item)
	for i in range(item.augmentSlots.size()):
		var t := XMVText.new(XMVText.convert_escapes(augment_name(item, i)), dx + 220, dy, dw)
		t.run()
		XMVText.paint(c, t.glyphs)
		dy += LH


## Window_MenuActor：每行 173；头像 144 竖直居中 (x+1)；名字 (158,0)、Lv (158,36)；HP/MP/TP 在 x 314、宽 = 内容宽 − 326
func _paint_actors(c: XMVCanvas) -> void:
	var members := XState.current.members()
	var all := _for_all()
	for i in range(_actor_top, mini(members.size(), _actor_top + ACTOR_ROWS)):
		var y := (i - _actor_top) * ACTOR_ROW_H
		if all or i == _actor:
			c.cursor(Rect2(0, y, c.size.x, ACTOR_ROW_H))
		var a: XActor = members[i]
		c.face(str(a.data().get("faceName", "")), int(a.data().get("faceIndex", 0)), 1, y + floorf((ACTOR_ROW_H - 144.0) / 2.0))
		c.text(a.display_name(), 158, y, 168, "left", XUI.TEXT, XUI.FONT_SIZE, LH)
		var lv_w := c.text_width("Lv")
		c.text("Lv", 158, y + LH, lv_w, "left", XUI.SYSTEM, XUI.FONT_SIZE, LH)
		c.text(XMenu._group(a.level), 158 + lv_w, y + LH, c.text_width(XMenu._group(a.max_level())), "right", XUI.TEXT, XUI.FONT_SIZE, LH)
		var gx := 314.0
		var gw := c.size.x - gx - 12.0
		_current_max(c, "HP", a.hp, a.mhp, gx, y + LH, gw, "hp")
		_current_max(c, "MP", a.mp, a.mmp, gx, y + LH * 2, gw, "mp")
		var tp: Array = XUI.GAUGES.tp
		c.gauge(gx, y + LH * 3, gw, a.tp / a.max_tp(), tp[0], tp[1], LH)
		c.text("TP", gx, y + LH * 3, 44, "left", XUI.SYSTEM, XUI.FONT_SIZE, LH)
		c.text(str(int(a.tp)), gx + gw - 64, y + LH * 3, 64, "right", XUI.TEXT, XUI.FONT_SIZE, LH)


static func _current_max(c: XMVCanvas, label: String, cur: float, mx: float, x: float, y: float, w: float, kind: String) -> void:
	var cols: Array = XUI.GAUGES[kind]
	c.gauge(x, y, w, cur / maxf(mx, 1.0), cols[0], cols[1], LH)
	c.text(label, x, y, 44, "left", XUI.SYSTEM, XUI.FONT_SIZE, LH)
	var vw := c.text_width(XMenu._group(mx))
	var sw := c.text_width("/")
	c.text(XMenu._group(cur), x + w - vw * 2 - sw, y, vw, "right", XUI.TEXT, XUI.FONT_SIZE, LH)
	c.text("/", x + w - vw - sw, y, sw, "right", XUI.TEXT, XUI.FONT_SIZE, LH)
	c.text(XMenu._group(mx), x + w - vw, y, vw, "right", XUI.TEXT, XUI.FONT_SIZE, LH)


# ---- 操作 ----
func _unhandled_input(event: InputEvent) -> void:
	if search_panel != null:
		return
	var handled := true
	if event.is_action_pressed("ui_cancel"):
		_cancel()
	elif event.is_action_pressed("ui_accept"):
		_ok()
	elif event.is_action_pressed("ui_down", true):
		_move(1, not event.is_echo())
		_refresh()
	elif event.is_action_pressed("ui_up", true):
		_move(-1, not event.is_echo())
		_refresh()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _move(d: int, wrap: bool) -> void:
	match _mode:
		"category":
			_cat = XMenu._move(_cat, d, XShop.CATEGORIES.size(), wrap)
			_cat_top = XMenu._scroll_to(_cat, _cat_top, CAT_ROWS)
			_top = 0
		"list":
			var n := entries().size()
			if n > 0:
				_index = XMenu._move(_index, d, n, wrap)
				_top = XMenu._scroll_to(_index, _top, _rows())
		"action":
			_act = XMenu._move(_act, d, _actions.size(), wrap)
		"upgrade":
			var n := materials().size()
			if n > 0:
				_up_index = XMenu._move(_up_index, d, n, wrap)
				_up_top = XMenu._scroll_to(_up_index, _up_top, _rows())
		"augment":
			var n := augments().size()
			if n > 0:
				_aug_index = XMenu._move(_aug_index, d, n, wrap)
				_aug_top = XMenu._scroll_to(_aug_index, _aug_top, _rows())
		"actor":
			if not _for_all() and _scope() != 11:
				_actor = XMenu._move(_actor, d, XState.current.members().size(), wrap)
				_actor_top = XMenu._scroll_to(_actor, _actor_top, ACTOR_ROWS)


func _ok() -> void:
	_ok_inner()
	_refresh()


func _ok_inner() -> void:
	match _mode:
		"category":
			XSound.system(1)
			_mode = "list"
			_index = clampi(_index, 0, maxi(0, entries().size() - 1))
			_top = XMenu._scroll_to(_index, _top, _rows())
		"list":
			var rec := _current()
			if rec.is_empty():
				XSound.system(3)
				return
			XSound.system(1)
			_commit_seen()
			_item = rec
			_make_actions()
			_act = 0
			_mode = "action"
		"action":
			var a: Dictionary = _actions[_act]
			if not a.enabled:
				XSound.system(3)
				return
			XSound.system(1)
			match str(a.symbol):
				"use":
					# Scene_ItemBase.determineItem：对队友的先选人，否则直接用
					if _scope() in [7, 8, 9, 10, 11]:
						_open_actor()
					else:
						_use_direct()
				"upgrade":
					_mode = "upgrade"
					_up_index = 0
					_up_top = 0
				"augment":
					_open_augment(int(a.ext))
				"top", "lock":
					# 物品的 _item 是列表里加了标记名的副本，改的是原记录；做完换成新的显示副本，操作菜单随之重画
					var s := XState.current
					var orig := _item if XItemMarks.is_gear(_item) else XDB.rec("Items", int(_item.id))
					var msg := XItemMarks.toggle_top(s, orig) if a.symbol == "top" else XItemMarks.toggle_lock(s, orig)
					if msg != "":
						XToast.show_text(msg, true)
					_item = XItemMarks.decorate(s, orig)
					_make_actions()
				"cancel":
					_mode = "list"
		"upgrade":
			var rec := _material()
			if rec.is_empty() or not XGearUpgrade.apply(XState.current, _item, int(rec.id)):
				XSound.system(3)
				return
			XSound.system(1)
			_up_index = clampi(_up_index, 0, maxi(0, materials().size() - 1))
		"augment":
			var row := _augment_row()
			if row.is_empty() or not row.enabled:
				XSound.system(3)
				return
			# onAugmentListOk：镶嵌（Codex 外层不通过时蜂鸣并提示），刷新后回到操作菜单原行；确定音是装备音效
			XSound.system(4)
			var reason := XOrbs.apply(_item, row.rec, _aug_slot, XState.current)
			if reason != "":
				XSound.system(3)
				XToast.show_text(reason, true)
			_close_augment()
		"actor":
			_use()


## onActionAugment：孔已失效时（孔位变化）提示并留在操作菜单
func _open_augment(slot: int) -> void:
	XOrbs.ensure(_item)
	if not XOrbs.valid_slot(_item, slot):
		XSound.system(3)
		XToast.show_text(XOrbs.TOAST_SLOT, true)
		_make_actions()
		return
	_mode = "augment"
	_aug_slot = slot
	_aug_index = 0
	_aug_top = 0


## onAugmentListCancel：回到操作菜单（停在原行），下次打开列表从第一行起
func _close_augment() -> void:
	_commit_seen()
	_make_actions()
	_act = clampi(_act, 0, _actions.size() - 1)
	_mode = "action"
	_aug_index = 0
	_aug_top = 0


func _cancel() -> void:
	_cancel_inner()
	_refresh()


func _cancel_inner() -> void:
	XSound.system(2)
	match _mode:
		"category":
			_commit_seen()
			closed.emit()
		"list":
			_commit_seen()
			_mode = "category"
		"action":
			_mode = "list"
		"upgrade":
			_commit_seen()
			_mode = "action"
		"augment":
			_close_augment()
		"actor":
			_mode = "list"


# ---- 使用物品（Scene_ItemBase）----
func _scope() -> int:
	return int(_item.get("scope", 0))


func _for_all() -> bool:
	return _scope() in [8, 10]


## determineItem：对队友的物品打开选人窗（全体时光标全选，对使用者时固定在使用者）
func _open_actor() -> void:
	_mode = "actor"
	_actor = 0
	_actor_top = 0


func _targets() -> Array:
	var members := XState.current.members()
	if _for_all():
		return members
	return [members[clampi(_actor, 0, members.size() - 1)]]


## Game_Action.testApply：至少一个对象有效才能用，否则蜂鸣
func _effective(t: XActor) -> bool:
	if t.is_dead() != (_scope() in [9, 10]):
		return false
	for e in _item.get("effects", []):
		match int(e.code):
			11:
				if t.hp < t.mhp or float(e.value1) < 0.0 or float(e.value2) < 0.0:
					return true
			12:
				if t.mp < t.mmp or float(e.value1) < 0.0 or float(e.value2) < 0.0:
					return true
			21:
				if not t.is_state_affected(int(e.dataId)):
					return true
			22:
				if t.state_ids.has(int(e.dataId)):
					return true
			43:
				if not t.skill_ids.has(int(e.dataId)):
					return true
			31, 32:
				if t.buffs[int(e.dataId)] != t.buff_limit(int(e.dataId), int(e.code) == 31):
					return true
			33, 34:
				if (int(e.code) == 33 and t.buffs[int(e.dataId)] > 0) or (int(e.code) == 34 and t.buffs[int(e.dataId)] < 0):
					return true
			_:
				return true
	return false


func _use() -> void:
	var s := XState.current
	var targets := _targets()
	if s.item_count(int(_item.get("id", 0))) <= 0 or not targets.any(func(t): return _effective(t)):
		XSound.system(3)
		return
	XSound.system(22)   # SoundManager.playUseItem
	# Scene_Item.user：可行动角色中药物知识 pha 最大者；与战斗共用效果栏实现。
	var logic := XBattleLogic.new()
	logic.state = s
	var movable := s.members().filter(func(a): return logic.can_move(a))
	if movable.is_empty():
		XSound.system(3)
		return
	var user: XActor = movable[0]
	for a in movable:
		if a.pha > user.pha:
			user = a
	for t in targets:
		if t.is_dead() != (_scope() in [9, 10]):
			continue
		for e in _item.get("effects", []):
			logic._effect(user, t, e, {"skill": _item, "hp": 0.0, "mp": 0.0, "added": [], "removed": []})
	if bool(_item.get("consumable", true)):
		s.gain_item(int(_item.id), -1)
	_after_use()


## 不对队友的物品（determineItem 的 else）：useItem 不经选人、没有对象，消耗后只做全局效果
func _use_direct() -> void:
	var s := XState.current
	if s.item_count(int(_item.get("id", 0))) <= 0:
		XSound.system(3)
		return
	XSound.system(22)   # SoundManager.playUseItem
	if bool(_item.get("consumable", true)):
		s.gain_item(int(_item.id), -1)
	_after_use()


## Game_Action.applyGlobal：效果里的公共事件（44）逐条 reserveCommonEvent（单槽，后一条盖前一条）；
## Scene_ItemBase.checkCommonEvent：有预约就回地图执行——物品页与菜单一起关掉（to_map 由菜单接着关）
func _after_use() -> void:
	var s := XState.current
	s.last_item = int(_item.get("id", 0))  # Scene_Item.useItem：$gameParty.setLastItem（魔兽要诀失败时按它退还）
	var reserved := false
	for e in _item.get("effects", []):
		if int(e.code) == 44:
			s.reserve_common_event(int(e.dataId))
			reserved = true
	if reserved:
		to_map = true
		closed.emit()


# ---- 鼠标：先选中再点确定；右键取消；滚轮滚动 ----
func _gui_input(event: InputEvent) -> void:
	if search_panel != null or not (event is InputEventMouseButton and event.pressed):
		return
	var p: Vector2 = event.position
	var pad := Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			_cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			var d := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			if LIST_RECT.has_point(p) and _mode in ["category", "list"]:
				_top = clampi(_top + d, 0, maxi(0, entries().size() - _rows()))
			elif LIST_RECT.has_point(p) and _mode == "upgrade":
				_up_top = clampi(_up_top + d, 0, maxi(0, materials().size() - _rows()))
			elif LIST_RECT.has_point(p) and _mode == "augment":
				_aug_top = clampi(_aug_top + d, 0, maxi(0, augments().size() - _rows()))
			elif CAT_RECT.has_point(p):
				_cat_top = clampi(_cat_top + d, 0, maxi(0, XShop.CATEGORIES.size() - CAT_ROWS))
		MOUSE_BUTTON_LEFT:
			_click(p, pad)
		_:
			return
	_refresh()


func _click(p: Vector2, pad: Vector2) -> void:
	if _mode == "actor":
		if ACTOR_RECT.has_point(p):
			var i := _actor_top + floori((p - ACTOR_RECT.position - pad).y / ACTOR_ROW_H)
			if i == _actor or _for_all():
				_ok()
			elif i >= 0 and i < XState.current.members().size():
				_actor = i
		return
	if CAT_RECT.has_point(p) and _mode in ["category", "list"]:
		var i := _cat_top + floori((p - CAT_RECT.position - pad).y / LH)
		if i >= 0 and i < XShop.CATEGORIES.size():
			if _mode == "category" and i == _cat:
				_ok()
			else:
				_commit_seen()
				_cat = i
				_mode = "category"
				_top = 0
		return
	if not LIST_RECT.has_point(p):
		return
	var row := floori((p - LIST_RECT.position - pad).y / LH)
	match _mode:
		"category", "list":
			var i := _top + row
			if i >= 0 and i < entries().size():
				if _mode == "list" and i == _index:
					_ok()
				else:
					_mode = "list"
					_index = i
		"action":
			if row >= 0 and row < _actions.size():
				if row == _act:
					_ok()
				else:
					_act = row
		"upgrade":
			var i := _up_top + row
			if i >= 0 and i < materials().size():
				if i == _up_index:
					_ok()
				else:
					_up_index = i
		"augment":
			var i := _aug_top + row
			if i >= 0 and i < augments().size():
				if i == _aug_index:
					_ok()
				else:
					_aug_index = i
