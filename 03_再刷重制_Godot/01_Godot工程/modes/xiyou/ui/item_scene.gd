class_name XItemScene
extends Control
## 物品页（Scene_Item：YEP_ItemCore＋YEP_X_ItemUpgradeSlots＋Galv_NewItemIndication＋HelpExtend＋Codex 装备排序），
## 按正式版运行时逐像素复现（参照截图 04_验证/本地结果/原版参照/70～74，绘制记录见 界面风格.md）。没有顶部说明栏：
## - 分类 (0,0,240,172)：物品／消耗品／武器／护甲／重要物品，居中，可见 4 行；分类阶段列表跟着显示该类物品（无光标）。
## - 状态 (240,1,1040,172)：YEP 物品状态（XItemStatusPainter）。
## - 列表 (0,172,640,548)：XItemRow；武器/护甲含队员身上的装备，按 Codex 装备排序（品质高在前 → 名字 → ID）。
## - 信息 (640,172,640,548)：图标 (8,2)、名字 x 42（品质色）；装备另画「插槽可用 剩余/总数」（标签右移 215）
##   与「插入n: 材料」（缩小一级）。
## - 操作（占列表位置）：使用 \i[图标]名字、升级（装备）或道具置顶（物品）、出售锁定、取消；不能用的半透明。
## - 升级材料（占列表位置）：XItemRow；不能用的半透明；确定即镶嵌，留在材料列表。取消回到操作。
## - 选人 (0,0,1280,720)：Window_MenuActor，每行 173，头像居中、名字/Lv、HP/MP/TP 量条；使用后留在选人。
## - 说明卡（XHelpCard）跟着列表/材料列表的选中行；操作阶段保留；分类与选人阶段隐藏（v0.10 选人时隐藏）。
## 暂未做（灰显或不画）：宝珠镶嵌（Codex 宝珠模块按实例随机插槽数：信息窗「镶嵌物」与操作菜单宝珠行）、道具置顶（Star_ItemTop）、
##   出售锁定（随一键出售）、Codex「装备检索 / 排序」网页面板（只做默认排序）；同品质装备的名字排序暂按字码（正式版按中文拼音）。

signal closed

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

var _mode := "category"             # category / list / action / upgrade / actor
var _cat := 0
var _cat_top := 0
var _index := 0
var _top := 0
var _act := 0
var _actions: Array = []            # [{text, symbol, enabled}]
var _item: Dictionary = {}          # 操作中的物品/装备
var _up_index := 0
var _up_top := 0
var _actor := 0
var _actor_top := 0
var _pending_seen: Dictionary = {}  # 光标停在上面的新物品：光标离开或换窗口时才记为看过（Galv 只重画前一行）
var cat_win: XMVWindow
var status_win: XMVWindow
var list_win: XMVWindow
var info_win: XMVWindow
var actor_win: XMVWindow
var help_card: XHelpCard


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
		return out
	var bag := bag_gear(sym)
	for i in range(bag.size()):
		out.append({"rec": bag[i], "carry": i + 1})
	for a in s.members():
		for e in a.equip_list():
			if e.kind == sym and not out.any(func(x): return is_same(x.rec, e)):
				out.append({"rec": e, "owner": a})
	return sort_gear(out)


static func instance_no(e: Dictionary) -> int:
	return int(str(e.get("instanceId", "xg:0")).get_slice(":", 1))


## $gameParty.weapons()/armors()：独立装备按 ID（这里是实例先后）排列；「序号/9,999」的序号即在这里的位置
static func bag_gear(kind: String) -> Array:
	var list := XState.current.gear.filter(func(e): return e.kind == kind)
	list.sort_custom(func(a, b): return instance_no(a) < instance_no(b))
	return list


## Codex installEquipmentStatusRuntime 默认排序「品质」：品质高在前 → 名字 → ID → 原顺序
static func sort_gear(list: Array) -> Array:
	var keyed := []
	for i in range(list.size()):
		keyed.append([list[i], i])
	keyed.sort_custom(func(a, b):
		var qa := XGear.quality(a[0].rec)
		var qb := XGear.quality(b[0].rec)
		if qa != qb:
			return qa > qb
		var na := XHelpCard.plain(str(a[0].rec.get("name", "")))
		var nb := XHelpCard.plain(str(b[0].rec.get("name", "")))
		if na != nb:
			return na < nb
		if instance_no(a[0].rec) != instance_no(b[0].rec):
			return instance_no(a[0].rec) < instance_no(b[0].rec)
		return a[1] < b[1])
	return keyed.map(func(x): return x[0])


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


func _usable(item: Dictionary) -> bool:
	return not item.has("instanceId") and [0, 2].has(int(item.get("occasion", 0))) and [7, 8, 9, 10, 11].has(int(item.get("scope", 0))) \
		and XState.current.item_count(int(item.get("id", 0))) > 0


func _make_actions() -> void:
	var label := "\\i[%d]\\c[0]%s" % [int(_item.get("iconIndex", 0)), str(_item.get("name", ""))]
	_actions = [{"text": str(XDB.plugin("YEP_ItemCore").get("Use Command", "使用 %1")).replace("%1", label), "symbol": "use", "enabled": _usable(_item)}]
	if _item.has("instanceId"):
		_actions.append({"text": str(XDB.plugin("YEP_X_ItemUpgradeSlots").get("Upgrade Command", "升级 %1")).replace("%1", label), "symbol": "upgrade", "enabled": true})
	else:
		_actions.append({"text": "道具置顶", "symbol": "top", "enabled": false})
	_actions.append({"text": "出售锁定", "symbol": "lock", "enabled": false})
	_actions.append({"text": "取消", "symbol": "cancel", "enabled": true})


# ---- 刷新 ----
func _refresh() -> void:
	var n_cat: int = XShop.CATEGORIES.size()
	cat_win.up_arrow = _cat_top > 0
	cat_win.down_arrow = _cat_top < n_cat - CAT_ROWS
	var n := entries().size() if _mode in ["category", "list"] else (materials().size() if _mode == "upgrade" else 0)
	var top := _up_top if _mode == "upgrade" else _top
	list_win.up_arrow = _mode in ["list", "category", "upgrade"] and top > 0
	list_win.down_arrow = _mode in ["list", "category", "upgrade"] and top < n - _rows()
	var actor_mode := _mode == "actor"
	for w in [cat_win, status_win, list_win, info_win]:
		w.visible = not actor_mode
	actor_win.visible = actor_mode
	for w in [cat_win, status_win, list_win, info_win, actor_win]:
		w.refresh()
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
		"action":
			return
	if rec != _pending_seen:
		_commit_seen()
		if _mode in ["list", "upgrade"] and XState.current.is_new(rec):
			_pending_seen = rec
	help_card.show_for(rec if row >= 0 else {})
	if help_card.visible:
		help_card.place_for_row(Rect2(LIST_RECT.position + Vector2(0, XMVWindow.PADDING + row * LH), Vector2(LIST_RECT.size.x, LH)))


func _commit_seen() -> void:
	if not _pending_seen.is_empty():
		XState.current.mark_seen(_pending_seen)
	_pending_seen = {}


func _is_new_drawn(rec: Dictionary) -> bool:
	return XState.current.is_new(rec)


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
		"action", "upgrade", "actor":
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


func _paint_info(c: XMVCanvas) -> void:
	var item := _current() if _mode == "list" else (_item if _mode in ["action", "upgrade"] else {})
	paint_info(c, item)


## Window_ItemInfo（YEP_ItemCore＋YEP_X_ItemUpgradeSlots，正式版把插槽行右移 215）
static func paint_info(c: XMVCanvas, item: Dictionary) -> void:
	if item.is_empty():
		return
	var dx := 6.0
	var dw := c.size.x - dx * 2
	c.icon(int(item.get("iconIndex", 0)), dx + 2, 2)
	c.text(str(item.get("name", "")), dx + 36, 0, dw - 36, "left", XGear.color(item), XUI.FONT_SIZE, LH)
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
		c.gauge(gx, y + LH * 3, gw, a.tp / 100.0, tp[0], tp[1], LH)
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
					_open_actor()
				"upgrade":
					_mode = "upgrade"
					_up_index = 0
					_up_top = 0
				"cancel":
					_mode = "list"
		"upgrade":
			var rec := _material()
			if rec.is_empty() or not XGearUpgrade.apply(XState.current, _item, int(rec.id)):
				XSound.system(3)
				return
			XSound.system(1)
			_up_index = clampi(_up_index, 0, maxi(0, materials().size() - 1))
		"actor":
			_use()


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
				if t.hp < t.mhp:
					return true
			12:
				if t.mp < t.mmp:
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
			13:
				if t.tp < 100.0:
					return true
			31, 32:
				if t.buffs[int(e.dataId)] != (2 if int(e.code) == 31 else -2):
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
	# Scene_Item.user：全队中药物知识 pha 最大者；与战斗共用效果栏实现（含取整、状态与复活）。
	var user: XActor = s.members()[0]
	for a in s.members():
		if a.pha > user.pha:
			user = a
	var logic := XBattleLogic.new()
	logic.state = s
	for t in targets:
		if t.is_dead() != (_scope() in [9, 10]):
			continue
		for e in _item.get("effects", []):
			logic._effect(user, t, e, {"skill": _item, "hp": 0.0, "mp": 0.0, "added": [], "removed": []})
	if bool(_item.get("consumable", true)):
		s.gain_item(int(_item.id), -1)


# ---- 鼠标：先选中再点确定；右键取消；滚轮滚动 ----
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
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
