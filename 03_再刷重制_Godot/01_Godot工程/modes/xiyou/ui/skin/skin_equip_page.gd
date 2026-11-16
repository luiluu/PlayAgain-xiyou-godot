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
## 环纹（XTianqiRingStyle，装备环样式 v0.2.1）：上次解析的结果、缓存键（人、换装、出战顺序）、上下文（人＋出战顺序，判是不是「亲手换出来的变化」）
var ring_style: Dictionary = {}
var _ring_style_key := []
var _ring_style_ctx := []
## 环心框画在 ring_top 的最近邻子画布项（ring_top 是线性过滤，96×96 像素框直画会糊）
var _center_ci := RID()
## 演出开始的时刻（毫秒，环下说明前 2 秒是旧金色）；-1＝没在演
var _intro_ms := -1
const RING_FACE_R_FRAMED := 33.0
const CAPTION_GOLD_MS := 2000
## 栏位环一圈最多几颗（样稿 10 颗；天启篇 13 栏分两页 7＋6）——ONE_PAGE 关掉时才用
const RING_MAX := 10
## 13 栏一页（O-520，Kyo 11-15「除了这个装备，我要所有栏位都在一页」）：栏位全部排在一圈上、不翻页、环下不再写「栏位第 a / b 页」。
## 一圈 13 颗：环半径 140、球半径 22（触屏点按半径 26，相邻两球中心隔 68，不会点串）；栏位名写在环内侧（球挨得近，写在球上下会压到邻球），
## 环心头像跟着缩到半径 72。上下左右／Q E 照旧：上、左＝逆时针一格，下、右＝顺时针一格（就是显示顺序），Q／E 换人。
## 4:3 屏：视口照 O-483 锁 1280×720 上下留边，左块宽度不变，和 16:9 同一个摆法。false＝回 7＋6 分两页。
static var ONE_PAGE := true
const ONE_PAGE_RING_R := 140.0
const ONE_PAGE_ORB_R := 22.0
const ONE_PAGE_LABEL_R := 98.0
## 13 栏一页的摆法（O-519，Kyo 11-15 看审图：「一圈 13 个太密，可以扩展一些不规则的分支子类」）：
## 0＝一圈 13 颗（上一版）；1＝A 下垂三枝；2＝B 星座斜出；3＝C 挂主栏（默认；Kyo 11-16 选定 C，A／B 只留作开关）。
## C 第七版（Kyo 11-16 看 v6）：连线默认钝角斜折——从根栏沿径向伸出约 48 拐（小菱形），再斜着接副栏，拐角约 125°；
## LINK_CURVE＝true 换弧线（径向出发平滑弯过去，不画拐点）。项链挪到头部右上 (164, −68)，线比 v6 长一倍多（左块右边只容它径向伸 40）。
## 主栏固定罗盘角（45° 一格）：178 哈基米没有副手，副手位留空、其余栏和拐点不动，法宝改挂武器、直连（小A核 v4 P2-1）。
## 选中的球和名字放大（1.15 倍、0.12 秒过渡）；选中副栏时它那条连线提亮。装备页环上不画七印刻痕。nodes 第 4 项＝拐点（相对环心）。
static var LINK_CURVE := true   # Kyo 11-16 定 S2＋B 弧线（v8）；false＝A 斜折
## 连线样式 v8（Kyo 11-16 看小A三个弧线方向：「我觉得是样式和颜色的问题」）：线从两球边缘起止、根粗梢细；
## 1＝S1 实金锥线、2＝S2 金到透明、3＝S3 骨白细线、4＝S4 暗铜镶金（见 XSkinRingNav.LINK_STYLES）；0＝回 v7 等宽细线。
## 选中副栏时线整根提亮（不变红）、父栏描边转亮金；红只给选中框。Kyo 11-16 定 S2（金到透明）＋B 弧线，其余套留作开关。
static var LINK_STYLE := 2
static var LAYOUT := 3
const BRANCH_R := 112.0
const BRANCH_ORB_R := 24.0
const BRANCH_LABEL_R := 70.0   # 70：130% 字号时主栏名内缘离头像还留几像素（小A核 v4 P3-1）
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
	3: {"name": "C 挂主栏", "shift": Vector2(0, 0), "fixed_angles": true, "branches": [
		{"root": 1, "nodes": [[17, Vector2(-34, -184), "left", Vector2(0, -160)]]},
		{"root": 2, "nodes": [[13, Vector2(106, -154), "right", Vector2(113, -113)]]},
		{"root": 3, "nodes": [[9, Vector2(164, -68), "up", Vector2(152, 0)]]},
		{"root": 6, "nodes": [[10, Vector2(34, 184), "right", Vector2(0, 160)]]},
		{"root": 7, "nodes": [[16, Vector2(-154, -106), "down", Vector2(-113, -113)]]}]},
}
var _plan := {}


## 当前用不用分支摆法
static func branched() -> bool:
	return ONE_PAGE and LAYOUTS.has(LAYOUT) and XTianqiGear.on()   # 只给天启篇 13 栏；19 栏（非天启篇、XTianqiGear 关）回分页（小A核 P2-4）


## 分支摆法：显示行号的导航顺序（nav）、环上每项的摆法（custom，和 nav 一一对应）、枝丫连线（links）。
## 按装备类型摆（槽位号＋1）：没有副手栏的角色（猫）主环 7 颗，根不在时挂到主环第一颗上。
## types：槽位序号 → 原装备类型（XTianqiGear.base_types）；不给时按 槽位＋1（19 槽常规角色）。
static func ring_plan(view: Array, layout_id: int = -1, types: Array = []) -> Dictionary:
	var lay: Dictionary = LAYOUTS.get(LAYOUT if layout_id < 0 else layout_id, {})
	var rows := range(view.size())
	if lay.is_empty():
		return {"nav": rows, "custom": [], "links": [], "link_items": [], "elbows": false, "shift": Vector2.ZERO}
	var type_row := {}
	var row_type := {}
	for k in view.size():
		var sl := int(view[k])
		row_type[k] = int(types[sl]) if sl < types.size() else sl + 1
		type_row[row_type[k]] = k
	var core := []
	for t in CORE_TYPES:
		if type_row.has(t):
			core.append(type_row[t])
	var n := core.size()
	var fixed := lay.has("fixed_angles")   # C：主栏固定罗盘角（45° 一格），缺的栏（哈基米没副手）留空位，拐点不乱
	var nav := []
	var custom := []
	var links := []
	var link_items := []   # 每条连线上的副栏是环上第几项（选中副栏时提亮它那条线）
	var placed := {}
	for j in n:
		var row: int = core[j]
		var deg := -90.0 + (CORE_TYPES.find(row_type[row]) * 45.0 if fixed else j * 360.0 / n)
		var rp := Vector2.from_angle(deg_to_rad(deg)) * BRANCH_R
		nav.append(row)
		custom.append({"pos": rp, "deg": deg, "label": ""})
		placed[row] = true
		for b in lay.branches:
			var own_root := type_row.has(int(b.root))
			if int(type_row.get(int(b.root), core[0])) != row:
				continue
			var path := [rp]
			var its := []
			for nd in b.nodes:
				if not type_row.has(int(nd[0])) or placed.has(type_row[int(nd[0])]):
					continue
				var r2: int = type_row[int(nd[0])]
				its.append(nav.size())
				nav.append(r2)
				custom.append({"pos": nd[1], "label": nd[2]})
				placed[r2] = true
				if (nd as Array).size() > 3 and own_root:   # 折线拐点（在根栏径向上，画小菱形）；根栏不在、改挂第一颗时直连
					path.append(nd[3])
				path.append(nd[1])
			if path.size() > 1:
				links.append(path)
				link_items.append(its)
	var spare := 0
	for k in view.size():   # 没摆上的（正常没有）：底下一排
		if not placed.has(k):
			nav.append(k)
			custom.append({"pos": Vector2(-120 + spare * 60, 200), "label": "down"})
			spare += 1
	return {"nav": nav, "custom": custom, "links": links, "link_items": link_items, "elbows": fixed, "shift": lay.shift}
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
	var one := ONE_PAGE and XTianqiGear.on()
	ring_radius = (BRANCH_R if branched() else ONE_PAGE_RING_R) if one else 132.0
	orb_radius = (BRANCH_ORB_R if branched() else ONE_PAGE_ORB_R) if one else 26.0
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
	_center_ci = RenderingServer.canvas_item_create()   # 环心框：ring_top 的子画布项，在头像之后（5.1 第 7 层）
	RenderingServer.canvas_item_set_parent(_center_ci, ring_top.get_canvas_item())
	RenderingServer.canvas_item_set_default_texture_filter(_center_ci, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	ring.style = base_style()   # 栏位环不画七印刻痕（Kyo 11-16：画面上每个点都要有含义）
	if ONE_PAGE and XTianqiGear.on():
		ring.label_inner = BRANCH_LABEL_R if branched() else ONE_PAGE_LABEL_R
		ring.label_sel_boost = 3 if branched() else 1   # 分支摆法：选中的名字跟球一起放大（Kyo 11-16 v7）
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _center_ci.is_valid():
		RenderingServer.free_rid(_center_ci)


static func base_style() -> Dictionary:
	return {"notches": false, "link_curve": LINK_CURVE, "link_style": LINK_STYLE}


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
	if ONE_PAGE and n <= 13:   # 13 栏一页；19 栏一圈太挤，照旧分页（小A核 P2-4）
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
		_plan = ring_plan(view, -1, XTianqiGear.base_types(a))
		ring.custom = _plan.custom
		ring.links = _plan.links
		ring.link_items = _plan.link_items
		ring.links_elbowed = _plan.elbows
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
	_sync_ring_style(a)
	if ring.index != idx:
		ring.select(idx)
	ring.queue_redraw()
	ring_top.queue_redraw()


## 出战顺序（换队伍顺序会改七印神器归属）；没有存档时空
static func battle_order() -> Array:
	return XState.current.battle_members() if XState.current != null else []


## 环纹：只在换人、换装、换出战顺序时重算（挪光标不算）。槽位号 → 环项序号按 items[i].key 换，不拿槽位号直接当序号
## （C 摆法里第 1 项是神器、第 2 项才是副手）。开页、换人、换队伍顺序时直接是那人的环；只有这一页亲手换装换出来的变化才演
func _sync_ring_style(a: XActor) -> void:
	var order := battle_order()
	var ids := order.map(func(m): return m.get_instance_id())
	var key := [a.get_instance_id(), scene._cand_rev, ids, XTianqiRingStyle.ENABLED, XTianqiRingStyle.GLINT, XConfig.flag(XTianqiRingStyle.SETTING), ring.items.size()]
	if key == _ring_style_key:
		return
	_ring_style_key = key
	var res := XTianqiRingStyle.resolve(a, order)
	if res.is_empty():   # 发行空壳给空字典
		res = {}
	var ctx := [a.get_instance_id(), ids]
	var kind := ""
	if ctx == _ring_style_ctx and str(res.get("sig", "")) != str(ring_style.get("sig", "")):
		kind = XTianqiRingStyle.intro_kind(ring_style, res)
	_ring_style_ctx = ctx
	ring_style = res
	apply_ring_style(res)
	if kind != "":
		ring.play_intro(kind)
		_intro_ms = Time.get_ticks_msec() if kind == "burn" and XSkinRingNav.ring_motion_level() > 0 else -1   # 动效「关」：直接切换，说明也不闪旧金


## 把解析结果填进环（空结果＝回默认环）
func apply_ring_style(res: Dictionary) -> void:
	var st := base_style()
	var art := {}
	var mo := {}
	var band := str(res.get("band", ""))
	if band != "":
		var bs := XTianqiRingStyle.style(band)
		for k in (bs.get("style", {}) as Dictionary):
			var v = bs.style[k]
			st[k] = Color.html(v) if v is String else v
		var ba: Dictionary = bs.get("art", {})
		if ba.has("band"):
			art["band"] = XTianqiRingStyle.texture(str(ba.band), "band")
		if ba.has("circle"):
			var ct := XTianqiRingStyle.texture(str(ba.circle), "circle")
			if ct != null:
				art["circle"] = ct
				art["circle_a"] = float(ba.get("circle_a", 0.28))
				art["circle_tint"] = Color.html(str(ba.get("circle_tint", "#ffffff")))
		mo = (bs.get("motion", {}) as Dictionary).duplicate()
		if mo.has("mote_color"):
			mo["mote_color"] = Color.html(str(mo.mote_color))
	ring.style = st
	ring.style_art = art
	ring.motion = mo
	var frames := {}
	var dots := {}
	var orbs: Dictionary = res.get("orbs", {})
	var dd: Dictionary = res.get("dots", {})
	for i in ring.items.size():
		var slot := int(ring.items[i].get("key", -1))
		if orbs.has(slot):
			var ob: Dictionary = orbs[slot]
			var fa: Dictionary = XTianqiRingStyle.style(str(ob.get("style", ""))).get("art", {})
			var tex := XTianqiRingStyle.texture(str(fa.get("frame", "")), "orb")
			if tex != null:
				frames[i] = {"tex": tex, "tint": ob.get("tint", Color.WHITE)}
		if dd.has(slot):
			dots[i] = dd[slot]
	ring.orb_frames = frames
	ring.orb_dots = dots
	ring.queue_redraw()
	if ring_top != null:
		ring_top.queue_redraw()


## 环心框贴图（没有为 null）
func center_frame() -> Texture2D:
	var ck := str(ring_style.get("center", ""))
	if ck == "":
		return null
	var fa: Dictionary = XTianqiRingStyle.style(ck).get("art", {})
	return XTianqiRingStyle.texture(str(fa.get("frame", "")), "center")


## 环心框画在哪（96×96，1:1 居中在环心；起点取整，免得半像素时最近邻采样抖动——小A 抽看第三节第 2 条）
func center_frame_rect(tex: Texture2D) -> Rect2:
	var ts := tex.get_size()
	return Rect2((ring.center() - ts / 2.0).round(), ts)


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
		return "身上 %d 件" % n + XTianqiRingStyle.caption_suffix(ring_style)
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
		var r := ring_radius - (68.0 if ring.label_inner > 0.0 else 62.0)   # 一页 13 栏：头像 72，给环内侧的栏位名让出位置
		if branched():
			r = ring_radius - BRANCH_LABEL_R - 2.0   # 分支摆法：头像半径 42，给环内侧的栏位名让地方
		if center_frame() != null:
			r = RING_FACE_R_FRAMED   # 有环心框：头像裁到 33，框外沿 ≤ 38（不新增占地）
		ring_top.draw_circle(c, r + 2.0, XUiSkin.ORB_LOW)
		XSkinPartyStrip.draw_round_texture(ring_top, face, c, r)
		ring_top.draw_circle(c, r + 1.0, Color(XUiSkin.LINE, 0.55), false, 1.5, true)
	var body := XUiSkin.font("body")
	for i in ring.items.size():
		var it: Dictionary = ring.items[i]
		var p := ring.item_pos(i)
		var on := i == ring.index
		var r := ring.orb_radius * ring.item_scale(i)
		if bool(it.get("empty", false)):
			var t := "空"
			var tw := body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
			ring_top.draw_string(body, Vector2(p.x - tw / 2.0, p.y + XUiSkin.FS_AUX * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, XUiSkin.TEXT_3)
		if bool(it.get("locked", false)):
			ring_top.draw_circle(p, r, Color(0, 0, 0, 0.55))
	_draw_center_frame()
	var cap := caption()
	var fs := XUiSkin.FS_AUX
	if not ring_style.is_empty() and str(ring_style.get("sig", "")) != "":   # 环纹说明可能变长：过 fit_text 防大字号溢出（4.1）
		var fit := XSkinList.fit_text(body, cap, left_w - 16.0, fs, XUiSkin.FS_MIN)
		cap = str(fit[0])
		fs = int(fit[1])
	var cw := body.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var cy := layout.left.size.y - ring.position.y - 6.0
	var cap_col := XSkinArt.bg_text_2()
	if _intro_ms >= 0:
		if Time.get_ticks_msec() - _intro_ms < CAPTION_GOLD_MS:
			cap_col = XUiSkin.GOLD   # 穿上那一刻：环下说明前 2 秒旧金
			ring_top.queue_redraw()
		else:
			_intro_ms = -1
	XSkinArt.bg_string(ring_top, body, Vector2(c.x - cw / 2.0, cy), cap, fs, cap_col)   # 直接在背景上（小A核 P3-3）


## 环心框（最近邻子画布 _center_ci；残缺遗物整张乘亮度）
func _draw_center_frame() -> void:
	if not _center_ci.is_valid():
		return
	RenderingServer.canvas_item_clear(_center_ci)
	var tex := center_frame()
	if tex == null:
		return
	var dim := float(ring_style.get("center_dim", 1.0))
	var col := Color(dim, dim, dim, ring.intro_alpha())
	var t := ring.intro_t if ring.intro_kind == "burn" and dim >= 1.0 else 1.0
	XSkinRingNav.add_sweep(_center_ci, center_frame_rect(tex), tex, t, col)
	if ring.intro_t < 1.0:
		ring_top.queue_redraw()


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
