class_name XSkinEquipPage
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】装备页新布局（界面风格提案 v0.7「装备」样稿 equip；手工排，借 XSkinTemplatePage 的骨架：页名、页签、三块、按键提示）。
## 只管「怎么摆、怎么画」：换装、清空、检索筛选、候选缓存（O-374）、HP/MP 按比例保留、看过新装备这些全部还是 XEquipScene 原来的代码
## （同一套 _mode／_slot／_item_index），这一页每次 _refresh 后 sync() 按状态重画，按键和点击翻译成同样的状态变化。
## - 左：上面一条角色条（头像、名字、Lv · 职业、血蓝 TP、状态图标）；下面栏位环（天启篇 13 栏，一圈放不下就分两页：
##   7＋6，环下写「身上 n 件 · 栏位第 a / b 页」；ONE_PAGE 开着时 13 栏一圈、不翻页），球里是身上那件的图标，空的写「空」，不能换的栏变暗；环心是角色圆头像。
## - 中：当前栏位的候选（旧金小标题＝栏位名，右边「可选 n 件」）；第一行「卸下」，其余每行 图标、名字（品质色）、主属性「+35」、
##   和身上那件比「▲23／▼2」（同一项能力值相减，只是显示）；一屏 10 行、行高 46，多了底下写「第 a / b 页」。
##   栏位环有焦点时列表只显示（没有选中条），确定后焦点进列表。
## - 右：详情牌——图标、名字（品质色）、品质 · 类型、「换上后」只列变了的能力值（「47 → 70 ▲23」，底下「其余 n 项不变」）、
##   再往下是说明卡的行（自带属性、词条、套装……放不下的从下往上裁）；选候选时牌底「装备」（卸下时「卸下」）按钮。
## - Y：全部属性与词条（XSkinGearDetail 盖在中、右两块上：装备详情／属性对比／插槽与镶嵌三页，左右换页、上下滚动；再按 Y 或取消收起）。
## - X：检索排序（XGearSearch，第 0 期起跟着换皮）；C：清空（旧页指令窗的「清空」）；Q / E：换人（回到栏位环）。
## 没有旧页的指令窗：开页就在栏位环上，取消直接关页。新皮肤关着时 XEquipScene 不建这一页，旧页一行不变。
## 卡顿（O-374 那次）：列表行只在候选数组换了（候选缓存重算）时才重建；「换上后」的预览角色只在选中的候选换了才算一次。

var scene: XEquipScene
var actor_strip: XSkinPartyStrip
var ring_top: Control
var detail: XSkinGearDetail
var _syncing := false
var _rows_src = null          # 上次建列表行用的候选数组（同一个数组＝没变）
var _rows_key := []
var _ring_key := []
var _strip_key := []
var _preview_key := []
var _preview: XActor = null
var expanded := false
## 栏位环一圈最多几颗（样稿 10 颗；天启篇 13 栏分两页 7＋6）——ONE_PAGE 关掉时才用
const RING_MAX := 10
## 13 栏一页（O-待定，Kyo 11-15「除了这个装备，我要所有栏位都在一页」）：栏位全部排在一圈上、不翻页、环下不再写「栏位第 a / b 页」。
## 一圈 13 颗：环半径 140、球半径 22（触屏点按半径 26，相邻两球中心隔 68，不会点串）；栏位名写在环内侧（球挨得近，写在球上下会压到邻球），
## 环心头像跟着缩到半径 78。上下左右／Q E 照旧：上、左＝逆时针一格，下、右＝顺时针一格（就是显示顺序），Q／E 换人。
## 4:3 屏：视口照 O-483 锁 1280×720 上下留边，左块宽度不变，和 16:9 同一个摆法。false＝回 7＋6 分两页。
static var ONE_PAGE := true
const ONE_PAGE_RING_R := 140.0
const ONE_PAGE_ORB_R := 22.0
const ONE_PAGE_LABEL_R := 98.0
## 13 栏一页的摆法（O-待定，Kyo 11-15 看审图：「一圈 13 个太密，可以扩展一些不规则的分支子类」）：
## 0＝一圈 13 颗（上一版）；1＝A 下垂三枝；2＝B 星座斜出；3＝C 挂主栏（默认，Kyo 挑定前先放 cc 推荐的）。
## 1～3：主环只放 8 个穿在身上的核心栏（武器 副手 头部 盔甲 护手 腰带 裤子 鞋子），其余 5 栏（项链 戒指 法宝 坐骑 神器）
## 从环上某一栏分叉伸出去，旧金细线连成枝丫；仍然一页全显示。键盘：上、左＝前一个，下、右＝后一个，顺序是绕主环走、
## 走到有枝丫的那栏就先顺着枝丫走完再回主环（深度优先）；Q／E 换人。主环 8 颗：半径 112、球半径 24（点按半径 28.8）。
static var LAYOUT := 3
const BRANCH_R := 112.0
const BRANCH_ORB_R := 24.0
const BRANCH_LABEL_R := 68.0
## 主环上的装备类型（显示顺序）；枝丫里的类型 9 项链 10 戒指 13 法宝 16 坐骑 17 神器
const CORE_TYPES := [1, 2, 3, 4, 6, 8, 5, 7]
## 每种摆法：shift＝环心相对环区中心的偏移；branches＝[{root: 根上的装备类型, nodes: [[类型, 相对环心的位置, 名字写哪边], …]}]
const LAYOUTS := {
	1: {"name": "A 下垂三枝", "shift": Vector2(0, -58), "branches": [
		{"root": 4, "nodes": [[13, Vector2(128, 160), "down"], [17, Vector2(100, 238), "down"]]},
		{"root": 6, "nodes": [[16, Vector2(0, 196), "down"]]},
		{"root": 8, "nodes": [[9, Vector2(-128, 160), "down"], [10, Vector2(-100, 238), "down"]]}]},
	2: {"name": "B 星座斜出", "shift": Vector2(0, 22), "branches": [
		{"root": 2, "nodes": [[13, Vector2(140, -150), "down"], [17, Vector2(90, -215), "up"]]},
		{"root": 6, "nodes": [[16, Vector2(100, 190), "right"]]},
		{"root": 7, "nodes": [[9, Vector2(-140, -150), "down"], [10, Vector2(-90, -215), "up"]]}]},
	3: {"name": "C 挂主栏", "shift": Vector2(0, 2), "branches": [
		{"root": 1, "nodes": [[17, Vector2(-44, -200), "right"]]},
		{"root": 2, "nodes": [[13, Vector2(124, -168), "right"]]},
		{"root": 3, "nodes": [[9, Vector2(150, -64), "down"]]},
		{"root": 6, "nodes": [[10, Vector2(64, 198), "right"]]},
		{"root": 7, "nodes": [[16, Vector2(-134, -160), "left"]]}]},
}
var _plan := {}


## 当前用不用分支摆法
static func branched() -> bool:
	return ONE_PAGE and LAYOUTS.has(LAYOUT)


## 分支摆法：显示行号的导航顺序（nav）、环上每项的摆法（custom，和 nav 一一对应）、枝丫连线（links）。
## 按装备类型摆（槽位号＋1）：没有副手栏的角色（猫）主环 7 颗，根不在时挂到主环第一颗上。
static func ring_plan(view: Array, layout_id: int = -1) -> Dictionary:
	var lay: Dictionary = LAYOUTS.get(LAYOUT if layout_id < 0 else layout_id, {})
	var rows := range(view.size())
	if lay.is_empty():
		return {"nav": rows, "custom": [], "links": [], "shift": Vector2.ZERO}
	var type_row := {}
	for k in view.size():
		type_row[int(view[k]) + 1] = k
	var core := []
	for t in CORE_TYPES:
		if type_row.has(t):
			core.append(type_row[t])
	var n := core.size()
	var nav := []
	var custom := []
	var links := []
	var placed := {}
	for j in n:
		var row: int = core[j]
		var deg := -90.0 + j * 360.0 / n
		var rp := Vector2.from_angle(deg_to_rad(deg)) * BRANCH_R
		nav.append(row)
		custom.append({"pos": rp, "deg": deg, "label": ""})
		placed[row] = true
		for b in lay.branches:
			if int(type_row.get(int(b.root), core[0])) != row:
				continue
			var path := [rp]
			for nd in b.nodes:
				if not type_row.has(int(nd[0])) or placed.has(type_row[int(nd[0])]):
					continue
				var r2: int = type_row[int(nd[0])]
				nav.append(r2)
				custom.append({"pos": nd[1], "label": nd[2]})
				placed[r2] = true
				path.append(nd[1])
			if path.size() > 1:
				links.append(path)
	var spare := 0
	for k in view.size():   # 没摆上的（正常没有）：底下一排
		if not placed.has(k):
			nav.append(k)
			custom.append({"pos": Vector2(-120 + spare * 60, 200), "label": "down"})
			spare += 1
	return {"nav": nav, "custom": custom, "links": links, "shift": lay.shift}
const STRIP_H := 72.0
const CAPTION_H := 28.0
const COUNT_W := 96.0


func _init(s: XEquipScene) -> void:
	scene = s
	name = "SkinEquipPage"
	title = "装备"
	group_key = "equip"
	columns = 1
	row_height = XUiSkin.ROW_H
	left_w = 384.0
	right_w = 476.0
	ring_radius = (BRANCH_R if branched() else ONE_PAGE_RING_R) if ONE_PAGE else 132.0
	orb_radius = (BRANCH_ORB_R if branched() else ONE_PAGE_ORB_R) if ONE_PAGE else 26.0
	auto_nav = false
	currencies = []
	hint_list = slot_hints()


func _ready() -> void:
	super()
	actor_strip = XSkinPartyStrip.new()
	actor_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.left.add_child(actor_strip)
	ring_top = Control.new()   # 环自己的球画在 draw 信号之后，「空」字、变暗、环心头像放在上面一层
	ring_top.name = "RingTop"
	ring_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring_top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring_top.draw.connect(_draw_ring_extra)
	ring.add_child(ring_top)
	if ONE_PAGE:
		ring.label_inner = BRANCH_LABEL_R if branched() else ONE_PAGE_LABEL_R
		ring.label_sel_boost = 1
	ring.changed.connect(_on_ring_changed)
	ring.activated.connect(_equip_ring_activated)
	list.right2_w = 58.0
	list.empty_text = ""
	list.index_changed.connect(_on_list_index)
	list.activated.connect(_equip_list_activated)
	list_panel.draw.connect(_draw_list_count)
	card.button_pressed.connect(func(_i): _confirm_from_card())
	card.gui_input.connect(_on_card_gui)
	detail = XSkinGearDetail.new()
	detail.visible = false
	layout.add_child(detail)
	gui_input.connect(_on_gui)
	mouse_filter = Control.MOUSE_FILTER_PASS
	relayout()


func relayout() -> void:
	super()
	if actor_strip == null:
		return
	var lb := layout.left.size
	actor_strip.position = Vector2.ZERO
	actor_strip.size = Vector2(lb.x, STRIP_H)
	var d := ring_radius * 2.0 + 120.0
	if branched():   # 分支摆法：环区占满角色条和环下说明之间，枝丫往上下伸
		d = maxf(lb.y - STRIP_H - CAPTION_H, d)
	ring.size = Vector2(lb.x, d)
	ring.position = Vector2(0, STRIP_H + maxf((lb.y - STRIP_H - CAPTION_H - d) / 2.0, 0.0))
	if detail != null:
		var c := layout.center.position
		var r := layout.right.position + layout.right.size
		detail.position = c
		detail.size = r - c


static func slot_hints() -> Array:
	return [["确定", "更换"], ["取消", "返回"], ["Y", "全部属性与词条"], ["X", "检索排序"], ["键盘 C", "清空"], ["Q / E", "换人"]]


static func item_hints() -> Array:
	return [["确定", "装备"], ["取消", "回栏位"], ["Y", "全部属性与词条"], ["X", "检索排序"], ["Q / E", "换人"]]


static func detail_hints() -> Array:
	return [["左右", "换页"], ["上下", "滚动"], ["Y / 取消", "收起"]]


# ---- 显示顺序：「卸下」放第一行（候选数据里它在最后） ----

static func to_display(data_i: int, n: int) -> int:
	return 0 if data_i == n - 1 else data_i + 1


static func to_data(disp_i: int, n: int) -> int:
	return n - 1 if disp_i == 0 else disp_i - 1


# ---- 按状态重画 ----

func sync() -> void:
	if layout == null:
		return
	_syncing = true
	var sc := scene
	for w in [sc.cmd_win, sc.status_win, sc.list_win, sc.lower_win]:
		w.visible = false
	if sc.gear_detail != null:
		sc.gear_detail.set_visible(false)
	if sc.toolbar != null:
		sc.toolbar.visible = false
	sc.help_card.visible = false
	visible = sc.search_panel == null
	var a := sc.actor()
	var strip_key := [a.get_instance_id(), sc._cand_rev, a.hp, a.mp, a.tp]
	if strip_key != _strip_key:   # 角色条只在换人、换装后重取（每挪一格都取要 0.7 毫秒）
		_strip_key = strip_key
		actor_strip.set_members([XSkinPartyStrip.from_actor(a)])
	_sync_ring(a)
	_sync_list(a)
	_sync_card(a)
	if expanded:
		_sync_detail(a)
		set_focus("none")
		set_hint_list(detail_hints())
	else:
		set_focus("list" if sc._mode == "item" else "ring")
		set_hint_list(item_hints() if sc._mode == "item" else slot_hints())
	# 展开时详情盖住中、右两块，左边栏位环不收点击（触屏点到会换栏位，小A核查 P2-3）
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE if expanded else Control.MOUSE_FILTER_STOP
	list_panel.visible = not expanded
	card.visible = not expanded
	detail.visible = expanded
	_syncing = false


## 栏位分页：一圈放不下时平均分（13 → 7＋6）
static func ring_pages(n: int) -> Array:
	if ONE_PAGE:
		return [1, maxi(n, 1)]
	var pages := maxi(1, ceili(n / float(RING_MAX)))
	var per := ceili(n / float(pages))
	return [pages, per]


func _sync_ring(a: XActor) -> void:
	if branched():
		_sync_ring_branched(a)
		return
	var view := scene.slot_view()
	var row := scene._slot_row()
	var pp := ring_pages(view.size())
	var per: int = pp[1]
	var pg := floori(row / float(per))
	var idx := row - pg * per
	var cheap := [a.get_instance_id(), pg, scene._cand_rev, view.size()]
	if not _ring_key.is_empty() and _ring_key[0] == cheap:   # 同一人、同一页、没换装：只挪选中
		if ring.index != idx:
			ring.select(idx)
		ring.queue_redraw()
		ring_top.queue_redraw()
		return
	var items := []
	var icons := []
	for k in range(pg * per, mini(view.size(), (pg + 1) * per)):
		var slot: int = view[k]
		var e = a.equips[slot] if slot < a.equips.size() else null
		var ic := int(e.get("iconIndex", 0)) if e is Dictionary and not e.is_empty() else 0
		items.append({"key": slot, "name": scene.slot_name(slot), "icon": ic, "empty": ic == 0, "locked": not XEquipment.can_change(a, slot)})
		icons.append([slot, ic, items[-1].locked])
	var key := [cheap, icons]
	if key != _ring_key:
		_ring_key = key
		ring.set_items(items, true)
	if ring.index != idx:
		ring.select(idx)
	ring.queue_redraw()
	ring_top.queue_redraw()


func _sync_ring_branched(a: XActor) -> void:
	var view := scene.slot_view()
	var row := scene._slot_row()
	var cheap := [a.get_instance_id(), LAYOUT, scene._cand_rev, view.size()]
	if _ring_key.is_empty() or _ring_key[0] != cheap:
		_plan = ring_plan(view)
		ring.custom = _plan.custom
		ring.links = _plan.links
		ring.center_shift = _plan.shift
	var nav: Array = _plan.nav
	var idx := maxi(nav.find(row), 0)
	var items := []
	var icons := []
	for k in nav:
		var slot: int = view[k]
		var e = a.equips[slot] if slot < a.equips.size() else null
		var ic := int(e.get("iconIndex", 0)) if e is Dictionary and not e.is_empty() else 0
		items.append({"key": slot, "name": scene.slot_name(slot), "icon": ic, "empty": ic == 0, "locked": not XEquipment.can_change(a, slot)})
		icons.append([slot, ic, items[-1].locked])
	var key := [cheap, icons]
	if key != _ring_key:
		_ring_key = key
		ring.set_items(items, true)
	if ring.index != idx:
		ring.select(idx)
	ring.queue_redraw()
	ring_top.queue_redraw()


## 分支摆法下环上第 i 项是第几行（显示行号）
func nav_row(i: int) -> int:
	return int(_plan.nav[i]) if branched() and i < (_plan.get("nav", []) as Array).size() else i


func caption() -> String:
	var a := scene.actor()
	var n := 0
	for slot in scene.slot_view():
		var e = a.equips[slot] if slot < a.equips.size() else null
		if e is Dictionary and not e.is_empty():
			n += 1
	var pp := ring_pages(scene.slot_view().size())
	if int(pp[0]) <= 1:
		return "身上 %d 件" % n
	return "身上 %d 件 · 栏位第 %d / %d 页" % [n, floori(scene._slot_row() / float(pp[1])) + 1, pp[0]]


## 候选一行的主属性：武器看攻击；别的看八项里绝对值最大的那项（一样大取靠前的）
static func main_param(rec: Dictionary) -> int:
	var p: Array = rec.get("params", [])
	if p.size() < 8:
		return -1
	if str(rec.get("kind", "")) == "weapon" or rec.has("wtypeId"):
		if int(p[2]) != 0:
			return 2
	var best := -1
	for i in range(8):
		if int(p[i]) != 0 and (best < 0 or absi(int(p[i])) > absi(int(p[best]))):
			best = i
	return best


static func param_of(rec, i: int) -> int:
	if not (rec is Dictionary) or i < 0:
		return 0
	var p: Array = (rec as Dictionary).get("params", [])
	return int(p[i]) if i < p.size() else 0


static func signed(v: int) -> String:
	return ("+" if v >= 0 else "") + str(v)


## 一行候选 → 列表项（cur：身上这一栏现在的那件，可能是 null）
static func candidate_row(a: XActor, slot: int, rec: Dictionary, cur, seen_new := false) -> Dictionary:
	var row := {"text": XQuality.list_name(rec), "icon": int(rec.get("iconIndex", 0)), "color": XGear.color(rec), "right": "", "right2": "",
		"disabled": XEquipment.dual_blocked(a, slot, rec)}
	var mp := main_param(rec)
	if mp >= 0:
		var v := param_of(rec, mp)
		row.right = signed(v)
		var diff := v - param_of(cur, mp)
		if diff > 0:
			row.right2 = "▲%d" % diff
			row.right2_color = XUiSkin.UP
		elif diff < 0:
			row.right2 = "▼%d" % -diff
			row.right2_color = XUiSkin.DOWN
	if seen_new:
		var tex := XItemRow.new_icon()
		if tex != null:
			row.badge = tex
	return row


func _sync_list(a: XActor) -> void:
	var sc := scene
	var cands := sc.candidates()
	var n := cands.size()
	var key := [a.actor_id, sc._slot, sc._cand_rev, sc.gear_filter.hash(), sc._pending_seen.get("instanceId", -1)]
	if not is_same(cands, _rows_src) or key != _rows_key:
		_rows_src = cands
		_rows_key = key
		var cur := sc._slot_item()
		var rows := [{"text": remove_text(), "icon": 0, "right": "", "right2": ""}]
		for k in range(n - 1):
			var rec: Dictionary = cands[k].rec
			rows.append(candidate_row(a, sc._slot, rec, cur if not cur.is_empty() else null,
				XItemRow.shows_new(XState.current, rec) and not is_same(rec, sc._pending_seen)))
		set_items(rows, to_display(sc._item_index, n) if sc._mode == "item" else 1 if n > 1 else 0)
	var want := to_display(sc._item_index, n) if sc._mode == "item" else (1 if n > 1 else 0)
	if list.index != want and want < list.items.size():
		list.select(want, sc._mode == "item")
	list_title = sc.slot_name(sc._slot) + ("（已筛选）" if not sc.gear_filter.is_empty() else "")
	list_panel.queue_redraw()


static func remove_text() -> String:
	return "卸下"


## 「换上后」：只列变了的能力值
static func change_lines(a: XActor, temp: XActor) -> Dictionary:
	var names: Array = XDB.system().get("terms", {}).get("params", [])
	var lines := []
	if temp == null:
		return {"lines": lines, "same": 8}
	for i in range(8):
		var before := int(a.param(i))
		var after := int(temp.param(i))
		if before == after:
			continue
		var d := after - before
		lines.append({"left": str(names[i]) if i < names.size() else XMenu.PARAM_NAMES[i],
			"right": "%s → %s %s%s" % [XMenu._group(before), XMenu._group(after), "▲" if d > 0 else "▼", XMenu._group(absi(d))],
			"color": XUiSkin.TEXT, "right_color": XUiSkin.UP if d > 0 else XUiSkin.DOWN})
	return {"lines": lines, "same": 8 - lines.size()}


## 选中候选换上后的角色（同一件只算一次）
func preview_actor(a: XActor) -> XActor:
	var sc := scene
	if sc._mode != "item":
		return null
	var e := sc._candidate()
	var key := [a.get_instance_id(), sc._slot, sc._cand_rev, sc._item_index, e.get("instanceId", e.get("id", -1)), e.is_empty()]
	if key != _preview_key:
		_preview_key = key
		if XEquipScene.CACHE_CANDIDATES:
			XActor.read_begin()
		_preview = sc._temp_actor()
		if XEquipScene.CACHE_CANDIDATES:
			XActor.read_end()
	return _preview


func _sync_card(a: XActor) -> void:
	var sc := scene
	var rec := sc._shown_item()
	var item_mode := sc._mode == "item"
	var d := {}
	if rec.is_empty():
		d = {"icon": null, "title": remove_text() if item_mode else sc.slot_name(sc._slot), "title_color": XUiSkin.TEXT,
			"subtitle": "" if item_mode else "空", "desc": "", "sections": []}
	else:
		d = XSkinItemPage.card_data(XSkinGearDetail.absorb_view(rec))
	if item_mode:
		var temp := preview_actor(a)
		_cache_compare(a, temp)
		var ch: Dictionary = _compare
		var lines: Array = ch.lines.duplicate()
		lines.append({"left": "能力值不变" if ch.lines.is_empty() else "其余 %d 项不变" % int(ch.same), "color": XUiSkin.TEXT_3})
		var sec := {"title": "换上后", "lines": lines}
		d.sections = [sec] + d.get("sections", [])
		var dis := XEquipment.dual_blocked(a, sc._slot, rec) if not rec.is_empty() else false
		d.buttons = [{"text": "卸下" if rec.is_empty() else "装备", "primary": true, "disabled": dis or not XEquipment.can_change(a, sc._slot)}]
	else:
		d.buttons = []
	set_card(d)


var _compare := {"lines": [], "same": 8}
var _compare_key := []


func _cache_compare(a: XActor, temp: XActor) -> void:
	var key := [_preview_key, a.get_instance_id(), temp != null]
	if key == _compare_key:
		return
	_compare_key = key
	if XEquipScene.CACHE_CANDIDATES:
		XActor.read_begin()  # 只读窗口（O-348）：两名角色各读 8 项能力值
	_compare = change_lines(a, temp)
	if XEquipScene.CACHE_CANDIDATES:
		XActor.read_end()


func _sync_detail(a: XActor) -> void:
	var rec := scene._shown_item()
	detail.set_data(rec, a, preview_actor(a), scene._mode == "item")


# ---- 画 ----

func _draw_ring_extra() -> void:
	var c := ring.center()
	var a := scene.actor()
	var face := XUiSkin.face(str(a.data().get("faceName", "")), int(a.data().get("faceIndex", 0)))
	if face != null:
		var r := ring_radius - (68.0 if ONE_PAGE else 62.0)   # 一页 13 栏：头像 72，给环内侧的栏位名让出位置
		if branched():
			r = ring_radius - BRANCH_LABEL_R - 2.0   # 分支摆法：头像半径 42，给环内侧的栏位名让地方
		ring_top.draw_circle(c, r + 2.0, XUiSkin.ORB_LOW)
		XSkinPartyStrip.draw_round_texture(ring_top, face, c, r)
		ring_top.draw_circle(c, r + 1.0, Color(XUiSkin.LINE, 0.55), false, 1.5, true)
	var body := XUiSkin.font("body")
	for i in ring.items.size():
		var it: Dictionary = ring.items[i]
		var p := ring.item_pos(i)
		var on := i == ring.index
		var r := ring.orb_radius * (1.16 if on else 1.0)
		if bool(it.get("empty", false)):
			var t := "空"
			var tw := body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
			ring_top.draw_string(body, Vector2(p.x - tw / 2.0, p.y + XUiSkin.FS_AUX * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, XUiSkin.TEXT_3)
		if bool(it.get("locked", false)):
			ring_top.draw_circle(p, r, Color(0, 0, 0, 0.55))
	var cap := caption()
	var cw := body.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
	var cy := layout.left.size.y - ring.position.y - 6.0
	ring_top.draw_string(body, Vector2(c.x - cw / 2.0, cy), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, XUiSkin.TEXT_2)


func _draw_list_count() -> void:
	var n := maxi(scene.candidates().size() - 1, 0)
	var t := "可选 %d 件" % n
	var body := XUiSkin.font("body")
	var tw := body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
	list_panel.draw_string(body, Vector2(list_panel.size.x - XUiSkin.PAD - 8 - tw, XUiSkin.PAD + 19), t, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, XUiSkin.TEXT_2)


# ---- 按键：用掉了返回 true（新布局下旧页的按键处理都不走） ----

func input(event: InputEvent) -> bool:
	var sc := scene
	var key := event as InputEventKey
	var fresh := key != null and key.pressed and not key.echo
	var code := (key.physical_keycode if key.physical_keycode != 0 else key.keycode) if key != null else KEY_NONE
	if expanded:
		if event.is_action_pressed("ui_cancel") or (fresh and code == KEY_Y):
			toggle_detail()
			return true
		return detail.handle_input(event)
	if fresh and code == KEY_Y:
		toggle_detail()
		return true
	if fresh and code == KEY_X:
		sc.open_search()
		visible = sc.search_panel == null
		return true
	if fresh and code == KEY_C and sc._mode == "slot":
		clear_all()
		return true
	if event.is_action_pressed("ui_page_up") or XMenu.actor_key(key, KEY_Q):
		sc.switch_actor(-1)
		return true
	if event.is_action_pressed("ui_page_down") or XMenu.actor_key(key, KEY_E):
		sc.switch_actor(1)
		return true
	if event.is_action_pressed("ui_cancel"):
		sc._cancel()
		return true
	if event.is_action_pressed("ui_accept"):
		sc._ok()
		return true
	var d := 0
	if event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_left", true):
		d = -1
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_right", true):
		d = 1
	if d == 0:
		return false
	var wrap := not event.is_echo()
	if sc._mode == "slot":
		if branched():   # 分支摆法：按导航顺序（绕主环、遇枝丫先走完枝丫）走
			var nav: Array = _plan.get("nav", [])
			var pos := maxi(nav.find(sc._slot_row()), 0)
			var np := XMenu._move(pos, d, nav.size(), wrap)
			if np != pos:
				sc._commit_seen()
				sc._slot = int(sc.slot_view()[int(nav[np])])
				XSound.system(0)
			sc._refresh()
			return true
		sc._move(d, wrap)
		return true
	if sc._mode == "item":
		if event.is_action("ui_left") or event.is_action("ui_right"):
			return true   # 列表一列：左右不动
		var n := sc.candidates().size()
		var disp := to_display(sc._item_index, n)
		var nd := XMenu._move(disp, d, n, wrap)
		if nd != disp:
			XSound.system(0)
		sc._item_index = to_data(nd, n)
		sc._refresh()
		return true
	return false


func toggle_detail() -> void:
	expanded = not expanded
	XSound.system(0 if expanded else 2)
	if expanded:
		detail.reset()
	scene._refresh()


## 旧页指令窗的「清空」：全部卸下（HP、MP 按比例保留，同 XEquipScene._ok 的 clear）
func clear_all() -> void:
	XSound.system(1)
	XSound.system(4)
	scene._keep_rates(func(): XEquipment.clear(XState.current, scene.actor()))
	scene._refresh()


# ---- 点击 → 同样的状态变化 ----

func _on_ring_changed(i: int) -> void:
	if _syncing or expanded:
		return
	var view := scene.slot_view()
	var per: int = ring_pages(view.size())[1]
	var pg := floori(scene._slot_row() / float(per))
	var row := nav_row(i) if branched() else pg * per + i
	if row >= view.size() or int(view[row]) == scene._slot:
		return
	scene._commit_seen()
	scene._mode = "slot"
	scene._slot = int(view[row])
	XSound.system(0)
	scene._refresh()


func _equip_ring_activated(_i: int) -> void:
	if _syncing or expanded:
		return
	if scene._mode == "item":
		scene._cancel()
	else:
		scene._ok()


func _on_list_index(i: int) -> void:
	if _syncing:
		return
	var sc := scene
	if not XEquipment.can_change(sc.actor(), sc._slot):
		return
	var n := sc.candidates().size()
	if sc._mode == "slot":
		XSound.system(1)
		sc._mode = "item"
	else:
		XSound.system(0)
	sc._item_index = to_data(i, n)
	sc._refresh()


func _equip_list_activated(i: int) -> void:
	if _syncing:
		return
	var sc := scene
	var n := sc.candidates().size()
	if sc._mode == "slot":
		_on_list_index(i)
		return
	if to_data(i, n) == sc._item_index:
		sc._ok()


func _confirm_from_card() -> void:
	if scene._mode == "item":
		scene._ok()


func _on_card_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not expanded:
		if not card.buttons.is_empty() and card.button_rect(0).has_point(event.position):
			return
		toggle_detail()


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if expanded:
			toggle_detail()
		else:
			scene._cancel()
		accept_event()
