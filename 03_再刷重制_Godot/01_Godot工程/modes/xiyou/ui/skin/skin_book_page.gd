class_name XSkinBookPage
extends Control
## 【cc·天启篇·未经审查】T364 卡 P：图鉴三本（人物 XActorBook、怪物 XEnemyBookPage、镶嵌 XInlayBook）新布局（T254 3.14～3.16）。
## 版型：左目录（宽 336，46 高的行一屏 11 行＋翻页脚；镶嵌多一行页签，10 行）＋右大牌（占满剩下的宽）。
## 状态机、数据、声音、取消层级全在旧页（index／mode／select／ok／cancel 不动）；旧页每次 _refresh 调 sync()，这一页只照旧页的状态画。
## - 人物：右大牌＝法阵上的小人、名字（品质色）、「职业 · 品质 · 最多进阶 N 次」、属性／武器／防具一行、「1 级时的能力」四列八项、
##   「技能」三列（光环角色四列；多了内部滚：滚轮、手指拖）、「备注」；天启篇六维雷达在牌头右边。确定＝技能详情：右大牌换成
##   面包屑「名字 › 技能详情」＋左技能列表（类型小标，没学会的变灰、行尾「未解锁」）＋右长说明卡（卡 S 的 XSkinCard.fold，Y 展开）。
## - 怪物：右大牌左栏＝名字（难度色）、「种族 · 出没于 …」、图（脚下暗红光）、「弱」「抗」两行；右栏「能力」两列（击败数放最后）、
##   「会用的招」（技能名＋行尾条件小字＋「权重 N」15 号 TEXT_3，照旧显示，T254 5AB-4 默认 A）、「备注」。没登记＝「还没遇到过」。
##   确定＝掉落：面包屑＋掉落列表（行尾照旧「掉率%」或「【绝对掉落】」）＋长说明卡。战斗里按 Shift 的「怪物信息」＝同一版式的弹层（压暗 66%）。
## - 镶嵌：目录上方两枚页内页签「武器／防具」（Q／E），进页就在目录上；右大牌＝名字、「能镶在：…」、「镶好后的属性」四列八项（0 变灰）、
##   「镶好后的效果」（\c[n] 过旧颜色对照表）、「镶嵌顺序（从左到右）」一排宝珠带序号。
## 回退：ENABLED＝false（一个开关管三本），旧页一行不变；西游存档、XUiSkin 关时本来就不建。

## 卡 P 开关：false＝三本图鉴都回旧页
static var ENABLED := true

## ---- 玩家可见文字（待小A 审）----
const T_ACTOR := "人物图鉴"
const T_ENEMY := "怪物图鉴"
const T_ENEMY_BATTLE := "怪物信息"
const T_INLAY := "镶嵌图鉴"
const T_INLAY_LIST := "符文之语"
const T_ACTOR_COUNT := "%d 位"
const T_ENEMY_COUNT := "登记 %d / %d"
const T_INLAY_COUNT := "%d 种"
const T_ABILITY := "1 级时的能力"
const T_SKILLS := "技能"
const T_NOTE := "备注"
const T_SKILL_DETAIL := "技能详情"
const T_ADVANCE := "最多进阶 %s 次"
const T_ATTR := "属性"
const T_WEAPON := "武器"
const T_ARMOR := "防具"
const T_LOCKED := "未解锁"
const T_UNKNOWN_ACTOR := "？？？"
const T_NOT_MET := "还没遇到过"
const T_RACE := "种族 %s"
const T_MAPS := "出没于 %s"
const T_NO_MAPS := "出没于 无记录"
const T_POWER := "能力"
const T_DEFEAT := "击败数"
const T_WEAK := "弱"
const T_RESIST := "抗"
const T_MOVES := "会用的招"
const T_WEIGHT := "权重 %s"
const T_DROPS := "掉落"
const T_NO_DROPS := "没有掉落"
const T_SLOTS := "能镶在：%s"
const T_INLAY_PARAMS := "镶好后的属性"
const T_INLAY_EFFECT := "镶好后的效果"
const T_INLAY_ORDER := "镶嵌顺序（从左到右）"
const T_INLAY_EMPTY := "这一类没有符文之语"
const T_NO_SKILLS := "没有技能"

const LEFT_W := 336.0
const LIST_TOP := 48.0
const TABS_H := 40.0
const FOOTER_H := 44.0
const ROWS := 11
const ROWS_INLAY := 10
const AVATAR := 32
const HEAD_H := 168.0
const CIRCLE_R := 72.0
const CELL_H := 28.0
const SKILL_H := 32.0
## 怪物「会用的招」压行距的下限
const MOVE_H_MIN := 26.0

var host: Control
var kind := "actor"          # actor / enemy / inlay
var in_battle := false

var backdrop: Control
var dim: ColorRect
var left_panel: Control
var list: XSkinList
var list_over: Control
var pager: XListPager
var inner_tabs: XSkinInnerTabs
var right_panel: Control
var detail_list: XSkinList
var card: XSkinCard
var top_layer: Control
var group_tabs: XSkinTabStrip
var hints: XSkinKeyHints
var back_button: XSkinBackButton

var _syncing := false
var _list_key := []
var _detail_key := []
var _hint_list: Array = []
## 人物「技能」、怪物「会用的招」一节放不下时的内部滚动（像素）
var skill_scroll := 0.0
var _skill_max := 0.0
var _skill_drag := XSkinDrag.new()
var _skill_rect := Rect2()
## T366（T364 P3）：备注超过 4 行时在备注这一块里滚（滚轮、手指拖），带细滚动条；T366_V1 关＝照旧只画前 4 行
var note_scroll := 0.0
var _note_max := 0.0
var _note_drag := XSkinDrag.new()
var _note_rect := Rect2()
## 测试读：人物牌头底、掌握那几行画到哪；怪物「会用的招」行高
var head_bottom := 0.0
var mastery_end := 0.0
var moves_row_h := 0.0
## 右大牌当前画的内容（测试读）：人物 actor_info／怪物 enemy_info／镶嵌 inlay_info 的结果
var info := {}
static var _avatar_cache := {}
static var _blank_tex: Texture2D


func _init(h: Control, k: String, battle := false) -> void:
	host = h
	kind = k
	in_battle = battle
	name = "SkinBookPage"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS   # 空白处右键＝取消（_on_gui），左键照样往下传


## 旧页 _ready 里问：这一页要不要建
static func wanted() -> bool:
	return ENABLED and XUiSkin.on()


func _ready() -> void:
	add_to_group(XUiSkin.FULLSCREEN_GROUP)
	theme = XUiSkin.theme()
	if in_battle:
		dim = ColorRect.new()
		dim.color = Color(0, 0, 0, 0.66)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dim)
	else:
		backdrop = XUiSkin.menu_backdrop(self)
		XSkinLayout.request_wide(self)
	left_panel = Control.new()
	left_panel.name = "Index"
	left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_panel.draw.connect(_draw_left)
	add_child(left_panel)
	if kind == "inlay":
		inner_tabs = XSkinInnerTabs.new()
		inner_tabs.set_tabs(XInlayBook.TYPES, 0)
		inner_tabs.changed.connect(_on_tab)
		left_panel.add_child(inner_tabs)
	list = XSkinList.new()
	list.columns = 1
	list.row_height = XUiSkin.ROW_H
	list.icon_size = AVATAR
	list.empty_center = true
	list.wrap = true
	list.index_changed.connect(_on_list_index)
	list.activated.connect(_on_list_activated)
	left_panel.add_child(list)
	list_over = Control.new()
	list_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_over.draw.connect(_draw_list_over)
	list.add_child(list_over)
	list.draw.connect(list_over.queue_redraw)
	pager = XListPager.new()
	pager.page_step.connect(_on_pager)
	left_panel.add_child(pager)
	right_panel = Control.new()
	right_panel.name = "Card"
	right_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	right_panel.clip_contents = false
	right_panel.draw.connect(_draw_right)
	right_panel.gui_input.connect(_right_input)
	add_child(right_panel)
	detail_list = XSkinList.new()
	detail_list.columns = 1
	detail_list.row_height = XUiSkin.ROW_H
	detail_list.empty_center = true
	detail_list.visible = false
	detail_list.index_changed.connect(_on_detail_index)
	detail_list.activated.connect(_on_detail_activated)
	right_panel.add_child(detail_list)
	card = XSkinCard.new()
	card.fold = true
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.expanded_changed.connect(_on_card_expanded)
	right_panel.add_child(card)
	top_layer = Control.new()
	top_layer.name = "Top"
	top_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_layer.draw.connect(_draw_top)
	add_child(top_layer)
	if kind != "inlay" and not in_battle:   # 页签条只在从主菜单进的页出现（人物、怪物图鉴是「图鉴」组的子项）
		group_tabs = XSkinTabStrip.new()
		group_tabs.set_groups(XUiSkin.GROUPS, XState.current, "codex")
		group_tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(group_tabs)
	hints = XSkinKeyHints.new()
	add_child(hints)
	back_button = XSkinBackButton.attach(self)
	gui_input.connect(_on_gui)
	resized.connect(relayout)
	get_viewport().size_changed.connect(relayout)
	relayout()


func page_title() -> String:
	match kind:
		"actor":
			return T_ACTOR
		"enemy":
			return T_ENEMY_BATTLE if in_battle else T_ENEMY
	return T_INLAY


## 目录一屏几行（旧页的翻页、滚到可见都按它算）
func list_rows() -> int:
	return ROWS_INLAY if kind == "inlay" else ROWS


func view_size() -> Vector2:
	return size if size.x > 0.0 else Vector2(1280, 720)


## 左目录、右大牌的矩形（本页坐标）
func rects() -> Dictionary:
	var v := view_size()
	var m := XSkinLayout.margin_for(v.x)
	var top := float(XUiSkin.TOP)
	var h := v.y - (720.0 - XUiSkin.BOTTOM) - top
	var l := Rect2(m, top, LEFT_W, h)
	var rx := l.end.x + XUiSkin.PANEL_GAP
	return {"margin": m, "left": l, "right": Rect2(rx, top, v.x - m - rx, h)}


func relayout() -> void:
	if list == null:
		return
	var d := rects()
	left_panel.position = (d.left as Rect2).position
	left_panel.size = (d.left as Rect2).size
	right_panel.position = (d.right as Rect2).position
	right_panel.size = (d.right as Rect2).size
	var lx := 28.0 if XSkinArt.select_on() else 8.0
	var ly := LIST_TOP
	if inner_tabs != null:
		inner_tabs.position = Vector2(XUiSkin.PAD + 8, LIST_TOP - 6.0)
		inner_tabs.size = Vector2(LEFT_W - XUiSkin.PAD * 2 - 8, TABS_H - 6.0)
		ly += TABS_H
	list.position = Vector2(lx, ly)
	list.size = Vector2(LEFT_W - lx - 8.0, list_rows() * XUiSkin.ROW_H)
	list_over.position = Vector2.ZERO
	list_over.size = list.size
	pager.size = Vector2(minf(XListPager.DEFAULT_SIZE.x, LEFT_W - 16.0), FOOTER_H)
	pager.position = Vector2((LEFT_W - pager.size.x) / 2.0, left_panel.size.y - FOOTER_H)
	_place_detail()
	var view := view_size()
	if group_tabs != null:
		var f := XUiSkin.font("title")
		group_tabs.position = Vector2(XSkinLayout.margin_for(view.x) + (XSkinBackButton.W if back_button != null else 0.0) + f.get_string_size(page_title(), HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_PAGE).x + 24, 14)
		group_tabs.size = Vector2(group_tabs.total_width(), XSkinTabStrip.TAB_H)
	hints.set_hints(_hint_list)
	hints.place(view)
	top_layer.queue_redraw()
	left_panel.queue_redraw()
	right_panel.queue_redraw()


## 详情态（人物技能、怪物掉落）：右大牌里左列表、右长说明卡
func _place_detail() -> void:
	var rs := right_panel.size
	var p := float(XUiSkin.PAD_LG)
	var cw := clampf(rs.x * 0.48, 312.0, 460.0)
	var top := p + 32.0
	detail_list.position = Vector2(p, top)
	var rows := floori((rs.y - top - p) / float(XUiSkin.ROW_H))
	detail_list.size = Vector2(maxf(rs.x - p * 2 - cw - XUiSkin.PANEL_GAP, 120.0), rows * XUiSkin.ROW_H)
	card.position = Vector2(rs.x - p - cw, p)
	card.size = Vector2(cw, rs.y - p * 2)
	var g := right_panel.position
	card.expand_bounds = Vector2(g.y + card.position.y, g.y + card.position.y + card.size.y) if in_battle else Vector2(XUiSkin.TOP, XUiSkin.BOTTOM)


# ---- 同步旧页状态 ----

func sync() -> void:
	if list == null:
		return
	_syncing = true
	match kind:
		"actor":
			_sync_actor()
		"enemy":
			_sync_enemy()
		"inlay":
			_sync_inlay()
	_syncing = false
	_set_hints(_hints())
	left_panel.queue_redraw()
	right_panel.queue_redraw()
	list_over.queue_redraw()


func _set_list(rows: Array, idx: int, key: Array) -> void:
	if key != _list_key:
		_list_key = key
		list.set_items(rows, true)
	if not rows.is_empty() and idx >= 0 and list.index != idx:
		list.select(idx, false)
	elif not rows.is_empty() and idx >= 0:
		list.select(idx, false)


func _set_detail(rows: Array, idx: int, key: Array) -> void:
	if key != _detail_key:
		_detail_key = key
		detail_list.set_items(rows, true)
	if not rows.is_empty() and idx >= 0:
		detail_list.select(idx, false)


func _sync_actor() -> void:
	var h: XActorBook = host
	for w in [h.index_win, h.status_win, h.header_win, h.list_win]:
		w.visible = false
	h.help_card.show_for({})
	var ids := XActorBook.index_ids()
	var rows := []
	for i in ids.size():
		rows.append(actor_row(int(ids[i]), i))
	_set_list(rows, h.index, ["actor", ids])
	list.active = h.mode == "index"
	var id := h.actor_id()
	var detail := h.mode == "skills"
	detail_list.visible = detail
	card.visible = detail and h.skill_index >= 0 and h.skill_index < h.skill_list.size()
	if detail:
		var srows := []
		var known := XActorBook.known_skill_ids(id)
		for s in h.skill_list:
			srows.append(skill_row(id, s, known))
		_set_detail(srows, h.skill_index, ["skills", id, h.skill_list.map(func(s): return int(s.id))])
		detail_list.active = true
		if card.visible:
			var s: Dictionary = h.skill_list[h.skill_index].duplicate()
			s.note = RegEx.create_from_string("(?i)<HelpWidth:\\s*\\d+>").sub(str(s.get("note", "")), "", true)
			card.setup(help_card_data(s, "skill", true, card.size.x))
	else:
		_detail_key = []
		if card.expanded:
			card.set_expanded(false)
	var ninfo := actor_info(id)
	if ninfo.get("id", -1) != info.get("id", -2):
		skill_scroll = 0.0
		note_scroll = 0.0
	info = ninfo


func _sync_enemy() -> void:
	var h: XEnemyBookPage = host
	for w in [h.index_win, h.status_win, h.drop_win]:
		w.visible = false
	h.help_card.show_for({})
	var rows := []
	for i in h.ids.size():
		rows.append(enemy_row(h, i))
	var reg_key := h.ids.map(func(id): return XEnemyBook.registered(XState.current, int(id)))
	_set_list(rows, h.index, ["enemy", h.ids, reg_key])
	list.active = h.mode == "index"
	var detail := h.mode == "drops"
	detail_list.visible = detail
	card.visible = detail and h.drop_index >= 0 and h.drop_index < h.drop_list.size()
	if detail:
		var drows := []
		for r in h.drop_list:
			drows.append(drop_row(r))
		_set_detail(drows, h.drop_index, ["drops", h.index, drows.map(func(r): return r.text)])
		detail_list.active = true
		if card.visible:
			var row: Dictionary = h.drop_list[h.drop_index]
			card.setup(help_card_data(row.base, str(row.kind), false, card.size.x))
	else:
		_detail_key = []
		if card.expanded:
			card.set_expanded(false)
	var ninfo := enemy_info(h.enemy(int(h.ids[h.index])) if not h.ids.is_empty() else null, not in_battle)
	if ninfo.get("id", -1) != info.get("id", -2):
		skill_scroll = 0.0
		note_scroll = 0.0
	info = ninfo


func _sync_inlay() -> void:
	var h: XInlayBook = host
	for w in [h.type_win, h.index_win, h.status_win]:
		w.visible = false
	if inner_tabs.index != h.type_index:
		inner_tabs.select(h.type_index, false)
	var rows := []
	for r in h.list:
		rows.append(inlay_row(r, h.type_index))
	list.empty_text = T_INLAY_EMPTY
	_set_list(rows, h.index, ["inlay", h.type_index, h.list.size()])
	list.active = h.mode == "index"
	detail_list.visible = false
	card.visible = false
	info = inlay_info(h.list[h.index], h.type_index) if h.index >= 0 and h.index < h.list.size() else {}


# ---- 目录行 ----

## 人物目录一行：头像（圆）、名字、行尾编号；「？？？」槽变灰
static func actor_row(id: int, slot: int) -> Dictionary:
	if id <= 0:
		return {"text": T_UNKNOWN_ACTOR, "color": XUiSkin.TEXT_3, "icon": blank_icon(), "right": "%03d" % (slot + 1), "right_color": XUiSkin.TEXT_3, "unknown": true}
	var d := XDB.rec("Actors", id)
	var a := XActorBook._live(id)
	var face_name := str(a.data().get("faceName", "")) if a != null else str(d.get("faceName", ""))
	var face_index := int(a.data().get("faceIndex", 0)) if a != null else int(d.get("faceIndex", 0))
	var tex := round_avatar(face_name, face_index)
	return {"text": XActorBook.actor_name(id), "color": XUiSkin.TEXT, "icon": tex if tex != null else blank_icon(), "right": "%03d" % (slot + 1), "right_color": XUiSkin.TEXT_2, "unknown": tex == null}


## 怪物目录一行：序号（行首小字，战斗里不写）＋名字（难度色）；没登记的「？？？？？？」变灰
static func enemy_row(h: XEnemyBookPage, i: int) -> Dictionary:
	var name := h.index_name(i)
	var unknown := name == XEnemyBookPage.UNKNOWN_ENEMY
	var col := XUiSkin.TEXT_3 if unknown else name_color(name)
	var row := {"text": name, "color": col}
	if not h.in_battle:
		row["icon"] = blank_icon()
		row["num"] = "%03d" % (i + 1)
	return row


static func inlay_row(r: Dictionary, kind: int) -> Dictionary:
	var tpl := XDB.rec("Weapons" if kind == 0 else "Armors", int(r.get("weapon" if kind == 0 else "armor", 0)))
	var icon := int(tpl.get("iconIndex", 0))
	return {"text": str(r.get("name", "")), "icon": icon if icon > 0 else blank_icon(), "color": XQuality.list_color(tpl) if not tpl.is_empty() else XUiSkin.TEXT}


## 人物技能详情一行：图标＋名字（品质色）、类型小标；没学会的（特殊角色）变灰、行尾「未解锁」
static func skill_row(id: int, s: Dictionary, known: Array) -> Dictionary:
	var row := {"text": str(s.get("name", "")), "icon": int(s.get("iconIndex", 0)), "color": XQuality.list_color(s), "tags": [{"text": skill_type(id, s), "color": XUiSkin.TEXT_2}]}
	if id in XActorBook.PREVIEW_ACTORS and not known.has(int(s.id)):   # 同旧页 list_row_ops 的 preview
		row["disabled"] = true
		row["right"] = T_LOCKED
		row["right_color"] = XUiSkin.TEXT_3
	return row


## 旧技能详情的「【类型】」（去掉方括号）：光环、被动、战技等（skillTypes）、其他；米拉黑龙段带「黑龙·」
static func skill_type(id: int, s: Dictionary) -> String:
	var sid := int(s.id)
	var dragon := id == 168 and ((sid >= 10148 and sid <= 10154) or (sid >= 10161 and sid <= 10164) or sid == 10167)
	var t := int(s.stypeId)
	var types: Array = XDB.system().get("skillTypes", [])
	var tn := "光环" if XActorBook.is_aura_note(s) else "被动" if t == 4 else str(types[t]) if t < types.size() and str(types[t]) != "" else "其他"
	return ("黑龙·" if dragon else "") + tn


## 怪物掉落一行：图标、名字（品质色）、行尾照旧「掉率%」或「【绝对掉落】」；天启篇连续没出的次数进小字；法宝等级进小标
static func drop_row(r: Dictionary) -> Dictionary:
	var base: Dictionary = r.base
	var full := str(r.item.name)
	var rest := full.substr(str(base.get("name", "")).length()).strip_edges()
	var rate := rest
	var sub := ""
	var k := rest.find("（")
	if k > 0:
		rate = rest.substr(0, k).strip_edges()
		sub = rest.substr(k)
	var row := {"text": str(base.get("name", "")), "icon": int(base.get("iconIndex", 0)), "color": XQuality.list_color(base), "right": rate, "right_color": XUiSkin.GOLD_LIGHT}
	if sub != "":
		row["sub"] = sub
	var lv = XEquipmentView.level(base)
	if lv is float and lv >= 0.0:
		row["tags"] = ["Lv %s" % XEnemyBookPage.js_num(lv)]
	return row


## 长说明卡（卡 S）：说明行照 XHelpCard.content 给（不改字、不改次序），按节画；放不下 Y 展开
static func help_card_data(obj: Dictionary, k: String, skill_copy: bool, width: float) -> Dictionary:
	if obj.has(XAffixAbsorb.KEY):
		obj = XAffixAbsorb.view(obj)
	var rows := XHelpCard.content(obj, k, skill_copy, XHelpCard.note_width(obj, width) - XHelpCard.PAD * 2)
	var d := {}
	if XHelpCard.SECTIONS:
		d = XHelpCard.skin_card_data(rows, obj)
	else:
		var hr := XSkinTemplatePage.help_rows(rows)
		d = {"title": str(obj.get("name", "")), "title_color": XQuality.list_color(obj), "icon": XUiSkin.icon(int(obj.get("iconIndex", 0))) if int(obj.get("iconIndex", 0)) > 0 else null,
			"subtitle": "", "desc": "", "sections": XSkinTemplatePage.help_sections(hr)}
	var q := XHelpCard._quality(obj)
	if q > 0:
		q = XQuality.show_legacy(obj)
	d["border_color"] = Color(XUiSkin.quality_color(clampi(XQuality.grade_of(q), 0, 6)), 0.58) if q > 0 else Color(XUiSkin.LINE, 0.38)
	d.merge({"notice": "", "buttons": [], "button_index": -1, "reserve_bottom": 0.0, "icon": null, "title_color": XUiSkin.TEXT}, false)
	return d


static func name_color(text: String) -> Color:
	# 难度色照旧（§3.15）：不过旧颜色对照表（legacy_color 只给说明行用，会把绿／蓝／紫洗成骨白／灰）
	return XEnemy.name_color(text, XEnemyBookPage._difficulty(), XUiSkin.TEXT)


## 透明占位图标（没有头像的行、怪物序号那一格）：行文字照样从图标后起
static func blank_icon() -> Texture2D:
	if _blank_tex == null:
		var img := Image.create(AVATAR, AVATAR, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		_blank_tex = ImageTexture.create_from_image(img)
	return _blank_tex


## 圆头像：脸图裁成圆（外圈 1px 淡线），按脸图缓存
static func round_avatar(face_name: String, index: int) -> Texture2D:
	if face_name == "":
		return null
	var k := "%s#%d" % [face_name, index]
	if _avatar_cache.has(k):
		return _avatar_cache[k]
	var tex := XUiSkin.face(face_name, index)
	var out: Texture2D = null
	if tex != null:
		var img := tex.get_image()
		if img != null and not img.is_empty():
			img = img.duplicate()
			img.convert(Image.FORMAT_RGBA8)
			var n := 64
			img.resize(n, n, Image.INTERPOLATE_BILINEAR)
			var c := Vector2(n / 2.0 - 0.5, n / 2.0 - 0.5)
			var r := n / 2.0 - 1.0
			var ring := Color(XUiSkin.LINE, 0.9)
			for y in n:
				for x in n:
					var dd := Vector2(x, y).distance_to(c)
					if dd > r:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
					elif dd > r - 2.0:
						img.set_pixel(x, y, img.get_pixel(x, y).lerp(ring, 0.7))
			out = ImageTexture.create_from_image(img)
	_avatar_cache[k] = out
	return out


# ---- 右大牌的内容（纯数据；测试按 T254 对应表逐行核）----

## 人物：{id, known, name, name_color, line, attrs:[[字, 色]], weapons, armors, params:[[名, 值]]×8, cols:[{title, skills}], note, six}
static func actor_info(id: int) -> Dictionary:
	if id <= 0 or not XActorBook.named(id):
		return {"id": id, "known": false}
	var d := XDB.rec("Actors", id)
	var cid := XActorBook.class_id(id)
	var cls := XDB.rec("Classes", cid)
	var params: Array = cls.get("params", [])
	var pv := []
	for k in 8:
		pv.append([XActorBook.PARAM_LABELS[k], str(int(params[k][1])) if k < params.size() and params[k].size() > 1 else "0"])
	var q = d.get("meta", {}).get("Actorquality", 0)
	var raw := int(float(str(q).strip_edges())) if str(q).strip_edges().is_valid_float() else 0
	if raw == 12:
		raw = 10
	var g := XActorBook.quality_grade(raw)
	var qname := str(XQuality.config().names[g]) if raw != 0 else "无"
	var probe := XActor.new()
	probe.actor_id = id
	var parts := XPowerStrip.attribute_parts(probe)
	var attrs := []
	for i in range(1, parts.size()):
		attrs.append([str(parts[i][0]).replace("／", " · "), XUiSkin.TEXT_3 if str(parts[i][0]) == "／" else parts[i][1]])   # 元素属性色照旧（黑暗、神圣…）
	var sys: Dictionary = XDB.system()
	var masteries := [[], []]
	for kk in 2:
		var ids := []
		for t in cls.get("traits", []):
			if int(t.code) == 51 + kk:
				ids.append(int(t.dataId))
		ids.sort()
		var names: Array = sys.get("weaponTypes" if kk == 0 else "armorTypes", [])
		for i in ids:
			if i < names.size() and str(names[i]) != "":
				masteries[kk].append(str(names[i]))
	var skills := XActorBook.book_skills(id, true)
	var aura := skills.any(XActorBook.is_aura_note)
	var groups := [[], [], [], []]   # 主动、被动、光环、其他
	for s in skills:
		var t := int(s.stypeId)
		if aura and XActorBook.is_aura_note(s):
			groups[2].append(s)
		elif t >= 1 and t <= 3:
			groups[0].append(s)
		elif t == 4:
			groups[1].append(s)
		elif t == 5:
			groups[3].append(s)
	var cols := [{"title": "主动", "skills": groups[0]}, {"title": "被动", "skills": groups[1]}]
	if aura:
		cols.append({"title": "光环", "skills": groups[2]})
	cols.append({"title": "其他", "skills": groups[3]})
	var note := []
	var showing := false
	for line in RegEx.create_from_string("[\\r\\n]+").sub(str(d.get("note", "")), "\n", true).split("\n"):
		if line == "<ActorNote>":
			showing = true
		elif line == "</ActorNote>":
			showing = false
		elif showing and line != "":
			note.append(line)
	var head := []
	if str(cls.get("name", "")) != "":
		head.append(str(cls.get("name", "")))
	head.append(qname)
	head.append(T_ADVANCE % XActorBook.advance_max(id))
	return {"id": id, "known": true, "name": XActorBook.actor_name(id), "name_color": XUiSkin.quality_color(clampi(g, 0, 6)) if raw != 0 else XUiSkin.TEXT,
		"quality": qname, "advance": XActorBook.advance_max(id), "line": " · ".join(head), "attrs": attrs,
		"weapons": masteries[0], "armors": masteries[1], "params": pv, "cols": cols, "note": note,
		"six": XTianqiSixDim.of_actor(id) if XTianqiSixDim.active() else {}}


## 怪物：{known, hide, name, name_color, race, maps, defeat, params, xparams, weak, resist, moves, note, six}
static func enemy_info(e: XEnemy, all := true) -> Dictionary:
	var s := XState.current
	if e == null:
		return {"known": false}
	var reg := XEnemyBook.registered(s, e.enemy_id)
	if all and not reg:
		return {"known": false, "id": e.enemy_id}
	var hide := not reg and (all or not XEnemyBookPage.BATTLE_SHOW_UNREGISTERED)
	var d := e.data()
	var tags := XEnemyBookPage.notetags(str(d.get("note", "")))
	var race := ""
	var race_re := RegEx.create_from_string("(?i)<ENEMYRACE: (\\d+)>")
	for line in tags:
		var m := race_re.search(line)
		if m != null:
			race = XEnemyBookPage.race_name(int(m.get_string(1)))
	var maps := XEnemyBook.record_maps(s, e.enemy_id).filter(func(x): return str(x) != "").map(func(x): return str(x))
	var terms: Array = XDB.system().get("terms", {}).get("params", [])
	var params := []
	for i in 8:
		params.append([str(terms[i]) if i < terms.size() else "", XEnemyBookPage.UNKNOWN_DATA if hide else XEnemyBookPage.js_num(e.param(i))])
	var xparams := []
	for r in XEnemyBookPage.XPARAM_ROWS:
		xparams.append([str(r[0]), XEnemyBookPage.UNKNOWN_DATA if hide else XEnemyBookPage.js_num(floorf(e.xparam(r[1]) * 100.0)) + "%"])
	var weak := []
	var resist := []
	var n: int = (XDB.system().get("elements", []) as Array).size()
	for i in range(1, n):
		var rate := e.element_rate(i)
		var icon := XEnemyBookPage.element_icon(i)
		if icon <= 0:
			continue
		if rate > 1.0:
			weak.append({"icon": icon, "pct": XEnemyBookPage.js_num(rate * 100.0 - 100.0) + "%", "rate": rate})
		elif rate < 1.0:
			resist.append({"icon": icon, "pct": XEnemyBookPage.js_num(100.0 - rate * 100.0) + "%", "rate": rate})
	var buckets := []
	for b in 14:
		buckets.append([])
	var actions: Array = d.get("actions", [])
	for i in mini(10, actions.size()):
		var sk := XDB.rec("Skills", int(actions[i].skillId))
		var qs := str(sk.get("meta", {}).get("quality", ""))
		var q := int(qs) if qs.is_valid_int() else 0
		var full := XEnemyBookPage.action_text(actions[i])
		var wk := full.rfind("  权重:")
		buckets[clampi(q, 0, 13)].append({"name": str(sk.get("name", "")), "icon": int(sk.get("iconIndex", 0)), "color": XQuality.list_color(sk),
			"cond": full.substr(0, wk) if wk >= 0 else full, "weight": XEnemyBookPage.js_num(float(actions[i].get("rating", 0)))})
	var moves := []
	for b in buckets:
		moves += b
	var note := []
	var in_note := false
	for line in tags:
		if line == "<EnemyNote>":
			in_note = true
		elif line == "</EnemyNote>":
			in_note = false
		elif in_note and line != "":
			note.append(line)
	var sm := XBossStatus.six_summary(e)
	return {"known": true, "id": e.enemy_id, "hide": hide, "name": e.display_name(), "name_color": name_color(e.display_name()),
		"race": race, "maps": maps, "where": T_MAPS % "、".join(maps) if not maps.is_empty() else T_NO_MAPS, "defeat": str(XEnemyBook.defeat_number(s, e.enemy_id)), "params": params, "xparams": xparams,
		"weak": weak, "resist": resist, "moves": moves, "note": note, "six": sm if not hide else {}}


## 镶嵌：{name, color, types, params:[[名, 值, 是 0]], effects:[[[字, 色]…]…], orbs:[{icon, name, color}], gem_note}
static func inlay_info(r: Dictionary, k: int) -> Dictionary:
	if r.is_empty():
		return {}
	var weapon := k == 0
	var tpl_id := int(r.get("weapon" if weapon else "armor", 0))
	var tpl := XDB.rec("Weapons" if weapon else "Armors", tpl_id) if tpl_id > 0 else {}
	var params := []
	var raw: Array = tpl.get("params", [0, 0, 0, 0, 0, 0, 0, 0])
	var full := XTianqiBase.on()
	for i in 8:
		var v := roundf(XTianqiGemPower.full_value(float(raw[i]), i)) if full else float(raw[i])
		params.append([XInlayBook.ATTRS[i], XEnemyBookPage.js_num(v), v == 0.0])
	var effects := []
	for text in XInlayBook.pos_texts(str(tpl.get("note", ""))):
		effects.append(color_spans(str(text)))
	var names: Array = XDB.system().get("weaponTypes" if weapon else "equipTypes", [])
	var types := []
	for t in r.get("weaponTypes" if weapon else "armorSlots", []):
		types.append(str(names[int(t)]) if int(t) >= 0 and int(t) < names.size() else XUI.undef_text("未知类型"))
	var orbs := []
	for m in r.get("materials", []):
		var item := XDB.rec("Items", int(m))
		if not item.is_empty():
			orbs.append({"icon": int(item.get("iconIndex", 0)), "name": str(item.get("name", "")), "color": XQuality.list_color(item)})
	return {"name": str(r.get("name", "")), "color": XQuality.list_color(tpl) if not tpl.is_empty() else XUiSkin.TEXT, "has_tpl": tpl_id > 0,
		"types": types, "params": params, "effects": effects, "orbs": orbs, "gem_note": XTianqiGemPower.NOTE if XTianqiBase.on() else ""}


## 带 \c[n] 的一段字 → [[字, 色]…]（色过旧颜色对照表）；「全伤」照旧写成「全属性伤害」（XHelpCard._terms）
static func color_spans(raw: String) -> Array:
	var s := XMVText.convert_escapes(XHelpCard._terms(raw))
	var out := []
	var col := XUiSkin.TEXT
	var buf := ""
	var code := RegEx.create_from_string("^\u001b[cC]\\[(\\d+)\\]")
	var i := 0
	while i < s.length():
		var m := code.search(s.substr(i))
		if m != null:
			if buf != "":
				out.append([buf, col])
				buf = ""
			var n := int(m.get_string(1))
			col = XUiSkin.TEXT if n == 0 else XUiSkin.legacy_color(XUI.text_color(n))
			i += m.get_string(0).length()
			continue
		if s[i] != "\u001b":
			buf += s[i]
		i += 1
	if buf != "":
		out.append([buf, col])
	return out


# ---- 按键 ----

## 旧页 _unhandled_input 先问这里；返回 true＝用掉了
func input(event: InputEvent) -> bool:
	if kind == "inlay":
		var h: XInlayBook = host
		var q := qe_dir(event)
		if q != 0:   # 页签只认 Q／E；PageUp／PageDown、左右留给目录翻页（武器、防具各十几页）
			switch_type(posmod(h.type_index + q, XInlayBook.TYPES.size()))
			return true
		var pd := XMenu.page_dir(event)
		if pd == 0 and (event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_left", true)):
			pd = 1 if event.is_action_pressed("ui_right", true) else -1
		if pd != 0:
			if list.page(pd, true):
				XSound.system(0)
			return true
	if kind == "actor":
		var d2 := XMenu.page_dir(event)
		if d2 != 0:   # 旧页只认 PageUp／PageDown；新页按键提示写「Q / E 翻页」，Q／E 也翻目录
			if (host as XActorBook).mode == "index":
				(host as XActorBook)._page(d2)
			elif detail_list.page(d2, true):   # 技能详情：照旧页按页翻技能列表（按新列表一屏行数）
				XSound.system(0)
			return true
	return false


## 只认 Q／E 键（XMenu.page_dir 还认 PageUp／PageDown）
static func qe_dir(event: InputEvent) -> int:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if k == KEY_E:
			return 1
		if k == KEY_Q:
			return -1
	return 0


## 镶嵌：换武器／防具页签（XInlayBook.switch_type：旧页「回类型窗→换类型→确定」一步做完）
func switch_type(t: int) -> void:
	(host as XInlayBook).switch_type(t)


func _on_tab(i: int) -> void:
	if _syncing:
		return
	switch_type(i)


func _on_list_index(i: int) -> void:
	if _syncing:
		return
	match kind:
		"actor":
			var h: XActorBook = host
			if h.mode == "skills":
				h.cancel()
			h.select(i)
		"enemy":
			var h: XEnemyBookPage = host
			if h.mode == "drops":
				h._close_drops()
			h.select(i)
		"inlay":
			var h: XInlayBook = host
			if i != h.index:
				XSound.system(0)
				h._select(i)


func _on_list_activated(i: int) -> void:
	if _syncing:
		return
	match kind:
		"actor":
			var h: XActorBook = host
			if h.mode == "index" and i == h.index:
				h.ok()
		"enemy":
			var h: XEnemyBookPage = host
			if h.mode == "index" and i == h.index:
				h.ok()


func _on_detail_index(i: int) -> void:
	if _syncing:
		return
	if kind == "actor":
		(host as XActorBook).select_skill(i)
	elif kind == "enemy":
		(host as XEnemyBookPage).select_drop(i)


func _on_detail_activated(_i: int) -> void:
	if _syncing:
		return
	if kind == "enemy":
		(host as XEnemyBookPage).ok()   # 掉落列表：确定或取消都回目录（照旧）


## 长说明卡展开时，左边技能／掉落列表的红选中条（带左侧光标三角）藏起来，不从展开卡边上露出
func _on_card_expanded(on: bool) -> void:
	if detail_list != null and detail_list.bar != null:
		detail_list.bar.modulate.a = 0.0 if on else 1.0


func _on_pager(d: int) -> void:
	list.page(d, list.active)


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		host.call("cancel")
		accept_event()


## 人物「技能」、怪物「会用的招」一节：滚轮、手指拖滚动
func _right_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		host.call("cancel")
		right_panel.accept_event()
		return
	if kind == "inlay" or str(host.get("mode")) != "index" or (_skill_max <= 0.0 and _note_max <= 0.0):
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var wheel := mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN)
		if wheel and _note_max > 0.0 and _note_rect.has_point(mb.position):
			scroll_note(-_note_lh() if mb.button_index == MOUSE_BUTTON_WHEEL_UP else _note_lh())
			right_panel.accept_event()
		elif wheel and _skill_max > 0.0 and _skill_rect.has_point(mb.position):
			scroll_skills(-SKILL_H if mb.button_index == MOUSE_BUTTON_WHEEL_UP else SKILL_H)
			right_panel.accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _note_max > 0.0 and _note_rect.has_point(mb.position):
				_note_drag.press(mb.position, note_scroll)
			elif mb.pressed and _skill_max > 0.0 and _skill_rect.has_point(mb.position):
				_skill_drag.press(mb.position, skill_scroll)
			elif not mb.pressed:
				_skill_drag.release()
				_note_drag.release()
	elif event is InputEventMouseMotion and _note_drag.active():
		var to2 := _note_drag.motion((event as InputEventMouseMotion).position, XSkinDrag.is_touch_event(event))
		if not is_nan(to2):
			note_scroll = clampf(to2, 0.0, _note_max)
			right_panel.queue_redraw()
	elif event is InputEventMouseMotion and _skill_drag.active():
		var to := _skill_drag.motion((event as InputEventMouseMotion).position, XSkinDrag.is_touch_event(event))
		if not is_nan(to):
			skill_scroll = clampf(to, 0.0, _skill_max)
			right_panel.queue_redraw()


## 备注一行的高（和画的时候同一个算法）
static func _note_lh() -> float:
	return XUiSkin.FS_AUX_MAX * 1.6


func scroll_note(dy: float) -> void:
	note_scroll = clampf(note_scroll + dy, 0.0, _note_max)
	right_panel.queue_redraw()


func scroll_skills(dy: float) -> void:
	skill_scroll = clampf(skill_scroll + dy, 0.0, _skill_max)
	right_panel.queue_redraw()


# ---- 按键提示 ----

func _hints() -> Array:
	match kind:
		"actor":
			if (host as XActorBook).mode == "skills":
				return [["上下", "选技能"], ["取消", "回目录"]]
			return [["确定", "看技能详情"], ["Q / E", "翻页"], ["取消", "返回"]]
		"enemy":
			var h: XEnemyBookPage = host
			if h.in_battle:
				return [["上下", "选敌人"], ["取消", "返回"]]
			if h.mode == "drops":
				return [["上下", "选掉落"], ["取消", "回目录"]]
			return [["确定", "看掉落"], ["左右", "翻页"], ["取消", "返回"]]
	return [["Q / E", "武器 / 防具"], ["左右", "翻页"], ["取消", "返回"]]


func _set_hints(arr: Array) -> void:
	if arr == _hint_list:
		return
	_hint_list = arr
	if hints != null:
		hints.set_hints(arr)
		hints.place(view_size())


# ---- 画：顶栏 ----

func _draw_top() -> void:
	var view := view_size()
	var m := XSkinLayout.margin_for(view.x)
	var tx := XSkinBackButton.place(back_button, m)
	XSkinArt.bg_string(top_layer, XUiSkin.font("title"), Vector2(tx, 14 + 34 * 0.92), page_title(), XUiSkin.FS_PAGE, XUiSkin.TEXT)


# ---- 画：左目录 ----

func _draw_left() -> void:
	var ci := left_panel
	var s := ci.size
	XUiSkin.panel_style().draw(ci.get_canvas_item(), Rect2(Vector2.ZERO, s))
	var body := XUiSkin.font("body")
	var title := page_title()
	var count := ""
	match kind:
		"actor":
			title = T_ACTOR
			count = T_ACTOR_COUNT % XActorBook.index_ids().filter(func(i): return int(i) > 0).size()
		"enemy":
			var h: XEnemyBookPage = host
			if not h.in_battle:
				var n := h.ids.filter(func(id): return XEnemyBook.registered(XState.current, int(id))).size()
				count = T_ENEMY_COUNT % [n, h.ids.size()]
		"inlay":
			title = T_INLAY_LIST
			count = T_INLAY_COUNT % (host as XInlayBook).list.size()
	XUiSkin.ds(ci, body, Vector2(XUiSkin.PAD + 8, XUiSkin.PAD + 20), title, HORIZONTAL_ALIGNMENT_LEFT, s.x - 48, 20, XUiSkin.GOLD)
	XUiSkin.draw_title_accent(ci, XUiSkin.PAD + 8, XUiSkin.PAD + 25.5, 56.0)
	if count != "":
		var fs := XUiSkin.FS_AUX
		var cw := body.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		XUiSkin.ds(ci, body, Vector2(s.x - XUiSkin.PAD - 8 - cw, XUiSkin.PAD + 20), count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_2)
	pager.set_state(list.top_row, list.visible_rows(), list.rows_total())
	if pager.visible and XUiSkin.polish_on():
		XUiSkin.draw_divider(ci, XUiSkin.PAD + 8, s.x - XUiSkin.PAD - 8, s.y - FOOTER_H + 2.0, false, 0.65)


## 目录上叠的：怪物序号（行首小字）、人物「？」头像
func _draw_list_over() -> void:
	if list.items.is_empty():
		return
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var first := list.top_row
	var last := mini(list.items.size(), list.top_row + list.visible_rows() + 1)
	for i in range(first, last):
		var it: Dictionary = list.items[i]
		var r := list.cell_rect(i)
		if r.end.y <= 0.5 or r.position.y >= list.size.y - 0.5 or (list._sub == 0.0 and r.end.y > list.size.y + 0.5):
			continue   # 只画列表里看得见的行（手指拖出半行时列表自己裁）
		var x := r.position.x + 14.0 + (XSkinList.CHECK_W if list.check_column else 0.0)
		var cy := r.position.y + r.size.y / 2.0
		# 跟列表画占位图标的格子一样算（含选中放大），序号／「？」头像跟着选中行一起放大
		var ir0 := Rect2(x, cy - list.icon_size / 2.0, list.icon_size, list.icon_size)
		if XUiSkin.detail_on():
			ir0 = XUiSkin.inline_icon_rect(x, cy, list.icon_size, list.font_size)
		var sk := list.sel_scale.k(i)
		var ir := XSkinSelScale.grow(ir0, sk)
		if it.has("num"):
			var fs := int(roundf(XUiSkin.FS_AUX * sk))
			var t := str(it.num)
			while fs > 11 and num.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > ir.size.x + 2.0:
				fs -= 1   # 130% 字号时「001」比格子宽：缩到格子里，不贴名字
			XUiSkin.ds(list_over, num, Vector2(ir.position.x, ir.get_center().y + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_3 if it.get("color") == XUiSkin.TEXT_3 else XUiSkin.TEXT_2)
		elif bool(it.get("unknown", false)) and kind == "actor":
			var c := ir.get_center()
			var rad := ir.size.x / 2.0 - 1.0
			list_over.draw_circle(c, rad, Color(XUiSkin.panel_low_c(), 0.95))
			list_over.draw_arc(c, rad, 0, TAU, 32, Color(XUiSkin.LINE, 0.55), 1.0, true)
			var fs2 := int(roundf(XUiSkin.FS_AUX * sk))
			var qw := body.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
			XUiSkin.ds(list_over, body, Vector2(c.x - qw / 2.0, c.y + fs2 * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, XUiSkin.TEXT_3)


# ---- 画：右大牌 ----

func _draw_right() -> void:
	var ci := right_panel
	var s := ci.size
	if kind == "inlay" and info.is_empty():
		return   # 空页签：右牌不画（T254 3.0「空列表：右牌不画」）
	XUiSkin.panel_style().draw(ci.get_canvas_item(), Rect2(Vector2.ZERO, s))
	var p := float(XUiSkin.PAD_LG)
	var area := Rect2(p, p, s.x - p * 2, s.y - p * 2)
	match kind:
		"actor":
			var h: XActorBook = host
			if h.mode == "skills":
				XSkinCrumb.draw_parts(ci, Vector2(p, p + XUiSkin.fs(XSkinCrumb.FS) * 0.9), [str(info.get("name", "")), T_SKILL_DETAIL], detail_list.size.x)
				if h.skill_list.is_empty():
					XSkinTag.draw_empty(ci, Rect2(detail_list.position, detail_list.size), T_NO_SKILLS)
				return
			if not bool(info.get("known", false)):
				XSkinTag.draw_empty(ci, area, T_UNKNOWN_ACTOR)
				return
			_draw_actor(area)
		"enemy":
			var h: XEnemyBookPage = host
			if h.mode == "drops":
				XSkinCrumb.draw_parts(ci, Vector2(p, p + XUiSkin.fs(XSkinCrumb.FS) * 0.9), [str(info.get("name", "")), T_DROPS], detail_list.size.x)
				if h.drop_list.is_empty():
					XSkinTag.draw_empty(ci, Rect2(detail_list.position, detail_list.size), T_NO_DROPS)
				return
			if h.ids.is_empty():
				return
			if not bool(info.get("known", false)):
				XSkinTag.draw_empty(ci, area, T_NOT_MET)
				return
			_draw_enemy(area)
		"inlay":
			if info.is_empty():
				return
			_draw_inlay(area)


## 一节的小标题（旧金）＋下面一条细线之上的分隔；返回下一行的顶
func _section(ci: CanvasItem, x: float, y: float, w: float, text: String, divider := true) -> float:
	if divider:
		XUiSkin.draw_divider(ci, x, x + w, y, false, 0.65)
		y += 12.0
	var fs := XUiSkin.fs(17)
	XUiSkin.ds(ci, XUiSkin.font("body"), Vector2(x, y + fs * 0.9), text, HORIZONTAL_ALIGNMENT_LEFT, w, fs, XUiSkin.GOLD)
	return y + fs * 1.5


## 「名 值」格子（名 TEXT_2 左、值右对齐）
func _cell(ci: CanvasItem, r: Rect2, label: String, value: String, vcol := XUiSkin.TEXT) -> void:
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var fs := XUiSkin.FS_LIST
	var base := r.position.y + r.size.y / 2.0 + fs * 0.36
	var vw := num.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	XUiSkin.ds(ci, num, Vector2(r.end.x - vw, base), value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, vcol)
	XUiSkin.ds(ci, body, Vector2(r.position.x, base), label, HORIZONTAL_ALIGNMENT_LEFT, maxf(r.size.x - vw - 8.0, 8.0), fs, XUiSkin.TEXT_2)


## 自动折行画一串 [[字, 色]…]（折行走 XSkinText：避头尾、英文数字不腰斩；DETAIL_V1 关时它自己回旧折行）；
## 超过 bottom 的行不画；返回全部行画完后的 y（下一行顶，不管有没有被 bottom 裁）
static func draw_spans(ci: CanvasItem, spans: Array, x: float, y: float, w: float, fs: int, lh: float, bottom := INF, scroll := 0.0) -> float:
	var f := XUiSkin.font("body")
	var text := ""
	var owner := PackedInt32Array()   # 每个字属于第几段
	for k in spans.size():
		var t := str(spans[k][0])
		text += t
		for _c in t.length():
			owner.append(k)
	var ranges := XSkinText.wrap_ranges(text, f, fs, w) if text != "" else ([] as Array[Vector2i])
	for li in ranges.size():
		var line_y := y + li * lh - scroll
		if line_y < y - 0.5:
			continue   # T366：滚上去的行不画（备注滚动；scroll 默认 0 不影响别处）
		if line_y + lh > bottom + 0.5:
			break
		var rg: Vector2i = ranges[li]
		var cx := x
		var a := rg.x
		while a < rg.y:
			var b := a
			while b < rg.y and owner[b] == owner[a]:
				b += 1
			var seg := text.substr(a, b - a).replace("\n", "")
			if seg != "":
				XUiSkin.ds(ci, f, Vector2(cx, line_y + lh / 2.0 + fs * 0.36), seg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, spans[owner[a]][1])
				cx += f.get_string_size(seg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			a = b
	return y + maxi(ranges.size(), 1) * lh


## 要几行（同 draw_spans 的折行）
static func span_lines(spans: Array, w: float, fs: int) -> int:
	var text := ""
	for sp in spans:
		text += str(sp[0])
	if text == "":
		return 1
	return maxi(XSkinText.line_count(text, XUiSkin.font("body"), fs, w), 1)


## 备注：放不下（折行后超过这一块能放的行数，最多 4 行）时内部滚，右侧细滚动条；T366_V1 关＝照旧只画放得下的前几行
func _draw_note(ci: CanvasItem, spans: Array, x: float, y: float, w: float, fs: int, lh: float, bottom: float) -> void:
	if not XSkinList.T366_V1:
		_note_max = 0.0
		draw_spans(ci, spans, x, y, w, fs, lh, bottom)
		return
	var total := span_lines(spans, w - 10.0, fs)
	var shown := maxi(floori((bottom - y + 0.5) / lh), 1)
	if total <= shown:
		_note_max = 0.0
		note_scroll = 0.0
		draw_spans(ci, spans, x, y, w, fs, lh, bottom)
		return
	var view_h := shown * lh
	_note_max = (total - shown) * lh
	note_scroll = clampf(note_scroll, 0.0, _note_max)
	_note_rect = Rect2(x, y, w, view_h)
	draw_spans(ci, spans, x, y, w - 10.0, fs, lh, y + view_h, note_scroll)
	var track := Rect2(x + w - 4.0, y, 4.0, view_h)
	var th := maxf(view_h * shown / float(total), 16.0)
	XUiSkin.draw_scrollbar(ci, track, y + (view_h - th) * note_scroll / _note_max, th, Color(1, 1, 1, 0.06), Color(XUiSkin.LINE, 0.55))


## 「名 值」格子行高：130% 字号时跟着加高（100% 仍 28）
static func cell_h() -> float:
	return maxf(CELL_H, roundf(XUiSkin.FS_LIST * 1.3))


func _draw_actor(a: Rect2) -> void:
	var ci := right_panel
	var h: XActorBook = host
	var body := XUiSkin.font("body")
	var x := a.position.x
	var w := a.size.x
	var y := a.position.y
	# 牌头：法阵＋小人
	var cc := Vector2(x + CIRCLE_R + 4.0, y + CIRCLE_R + 4.0)
	_draw_circle_seal(ci, cc, CIRCLE_R)
	if h._sprite_tex != null:
		var id := h.actor_id()
		var pattern: int = [0, 1, 2, 1][floori(h._frame / 12.0) % 4]
		var rr: Array = XActorBook.sprite_rect(id, h._sprite_spec, Vector2(h._sprite_tex.get_size()), pattern)
		var dst: Rect2 = rr[0]
		var old_c := XActorBook.SPRITE_CENTER - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
		var k := 1.5
		var pos := cc + (dst.position - old_c) * k + Vector2(0, 6)
		ci.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ci.draw_texture_rect_region(h._sprite_tex, Rect2(pos, dst.size * k), rr[1])
	var tx := x + CIRCLE_R * 2 + 32.0
	var tw := w - (tx - x)
	var six: Dictionary = info.get("six", {})
	var radar_w := 0.0
	if not six.is_empty():
		radar_w = 200.0
		var rc := Vector2(a.end.x - radar_w / 2.0, y + HEAD_H / 2.0 - 4.0)
		XSkinSixDimRadar.paint(ci, rc, 54.0, six, {"compact": true, "fs": XUiSkin.FS_AUX})
		tw -= radar_w
	var fsn := XUiSkin.fs(XUiSkin.FS_CARD)
	var ny := y + 28.0
	XUiSkin.ds(ci, XUiSkin.font("title"), Vector2(tx, ny + fsn * 0.4), str(info.name), HORIZONTAL_ALIGNMENT_LEFT, tw, fsn, info.name_color)
	var fa := XUiSkin.FS_AUX
	ny += fsn * 0.5 + 18.0
	XUiSkin.ds(ci, body, Vector2(tx, ny + fa * 0.36), str(info.line), HORIZONTAL_ALIGNMENT_LEFT, tw, fa, XUiSkin.TEXT_2)
	ny += 30.0
	# 属性 · 武器 · 防具（放不下自动折到下一行）
	var spans := [[T_ATTR + "  ", XUiSkin.TEXT_2]]
	for part in info.attrs:
		spans.append(part)
	spans.append(["    " + T_WEAPON + "  ", XUiSkin.TEXT_2])
	spans.append(["、".join(info.weapons) if not (info.weapons as Array).is_empty() else "—", XUiSkin.TEXT])
	spans.append(["    " + T_ARMOR + "  ", XUiSkin.TEXT_2])
	spans.append(["、".join(info.armors) if not (info.armors as Array).is_empty() else "—", XUiSkin.TEXT])
	# 牌头高按内容算：掌握多（渡鸦）或 130% 字号折成三四行时往下推，不裁字
	var span_end := draw_spans(ci, spans, tx, ny, tw, XUiSkin.FS_AUX, XUiSkin.FS_AUX * 1.55)
	y = maxf(y + HEAD_H, span_end + 8.0)
	mastery_end = span_end
	head_bottom = y
	# 1 级时的能力：四列两行
	y = _section(ci, x, y, w, T_ABILITY)
	var colw := (w - 3 * 32.0) / 4.0
	for k2 in 8:
		var col := k2 % 4
		var row := floori(k2 / 4.0)
		var pr: Array = info.params[k2]
		_cell(ci, Rect2(x + col * (colw + 32.0), y + row * cell_h(), colw, cell_h()), str(pr[0]), str(pr[1]))
	y += cell_h() * 2 + 10.0
	# 备注先量（排在牌底），技能占中间
	var note_spans := []
	for i in (info.note as Array).size():
		note_spans.append([str(info.note[i]) + ("\n" if i < (info.note as Array).size() - 1 else ""), XUiSkin.TEXT])
	var nfs := XUiSkin.FS_AUX_MAX
	var nlh := nfs * 1.6
	var note_h := 0.0
	if not note_spans.is_empty():   # 备注最多 4 行，但技能一节至少留两行（130% 字号、掌握多时备注让行）
		var sec := 12.0 + XUiSkin.fs(17) * 1.5
		var room := floori((a.end.y - y - sec - XUiSkin.FS_AUX * 1.5 - SKILL_H * 2 - 6.0 - 12.0 - nfs * 1.5) / nlh)
		note_h = 12.0 + nfs * 1.5 + clampi(mini(span_lines(note_spans, w, nfs), room), 1, 4) * nlh
	var skills_bottom := a.end.y - note_h
	y = _section(ci, x, y, w, T_SKILLS)
	_draw_skill_cols(ci, Rect2(x, y, w, maxf(skills_bottom - y - 6.0, SKILL_H)))
	if not note_spans.is_empty():
		var ny2 := _section(ci, x, skills_bottom, w, T_NOTE)
		_draw_note(ci, note_spans, x, ny2, w, nfs, nlh, a.end.y)
	else:
		_note_max = 0.0


## 技能三列（或光环四列）：各带小标题；行多了在这一块里滚
func _draw_skill_cols(ci: CanvasItem, r: Rect2) -> void:
	var cols: Array = info.cols
	var n := cols.size()
	var colw := r.size.x / n
	var fs := XUiSkin.FS_AUX
	var body := XUiSkin.font("body")
	var head := fs * 1.5
	var longest := 0
	for c in cols:
		longest = maxi(longest, (c.skills as Array).size())
	var content_h := longest * SKILL_H
	var view_h := r.size.y - head
	_skill_max = maxf(content_h - view_h, 0.0)
	skill_scroll = clampf(skill_scroll, 0.0, _skill_max)
	_skill_rect = r
	var lfs := XUiSkin.FS_LIST
	for k in n:
		var cx := r.position.x + k * colw
		XUiSkin.ds(ci, body, Vector2(cx, r.position.y + fs * 0.9), str(cols[k].title), HORIZONTAL_ALIGNMENT_LEFT, colw, fs, XUiSkin.GOLD)
		var list_s: Array = cols[k].skills
		for i in list_s.size():
			var sy := r.position.y + head + i * SKILL_H - skill_scroll
			if sy < r.position.y + head - 0.5 or sy + SKILL_H > r.end.y + 0.5:
				continue
			var sk: Dictionary = list_s[i]
			var ic := int(sk.get("iconIndex", 0))
			var tex := XUiSkin.icon(ic) if ic > 0 else null
			if tex != null:
				ci.draw_texture_rect(tex, Rect2(cx, sy + (SKILL_H - 24.0) / 2.0, 24, 24), false)
			var fit := XSkinList.fit_text(body, str(sk.get("name", "")), colw - 40.0, lfs, XUiSkin.FS_MIN)
			XUiSkin.ds(ci, body, Vector2(cx + 30.0, sy + SKILL_H / 2.0 + int(fit[1]) * 0.36), str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1]), XQuality.list_color(sk))
	if _skill_max > 0.0:
		var track := Rect2(r.end.x - 4.0, r.position.y + head, 4.0, view_h)
		var th := maxf(track.size.y * view_h / content_h, 16.0)
		var ty := track.position.y + (track.size.y - th) * skill_scroll / _skill_max   # 拇指的 y 是画布坐标
		XUiSkin.draw_scrollbar(ci, track, ty, th, Color(1, 1, 1, 0.06), Color(XUiSkin.LINE, 0.55))


## 法阵：两圈细金线＋六芒
func _draw_circle_seal(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, Color(0, 0, 0, 0.35))
	var g := Color(XUiSkin.GOLD, 0.45)
	ci.draw_arc(c, r, 0, TAU, 64, g, 1.5, true)
	ci.draw_arc(c, r - 8.0, 0, TAU, 64, Color(XUiSkin.GOLD, 0.25), 1.0, true)
	for t in 2:
		var pts := PackedVector2Array()
		for k in 4:
			var ang := -PI / 2.0 + t * PI / 3.0 + k * TAU / 3.0
			pts.append(c + Vector2.from_angle(ang) * (r - 8.0))
		ci.draw_polyline(pts, Color(XUiSkin.GOLD, 0.2), 1.0, true)


func _draw_enemy(a: Rect2) -> void:
	var ci := right_panel
	var h: XEnemyBookPage = host
	var body := XUiSkin.font("body")
	var lw := clampf(a.size.x * 0.4, 280.0, 400.0)
	var x := a.position.x
	var y := a.position.y
	# 左栏：名字、种族·出没于、图、弱、抗
	var fsn := XUiSkin.fs(XUiSkin.FS_CARD)
	XUiSkin.ds(ci, XUiSkin.font("title"), Vector2(x, y + fsn * 0.95), str(info.name), HORIZONTAL_ALIGNMENT_LEFT, lw, fsn, info.name_color)
	y += fsn * 1.4
	var sub := []
	if str(info.race) != "":
		sub.append(T_RACE % info.race)
	sub.append(str(info.where))
	var fa := XUiSkin.FS_AUX
	y = draw_spans(ci, [[" · ".join(sub), XUiSkin.TEXT_2]], x, y, lw, fa, fa * 1.5, y + fa * 1.5 * 3)
	var six: Dictionary = info.get("six", {})
	# 图的高按下面弱／抗要占的高让出来（出没地图多、弱抗图标多行、130% 字号时图变矮，最矮 80），不画出面板
	var sec_h := 12.0 + XUiSkin.fs(17) * 1.5
	var below := 4.0 + (fa * 1.6 if not six.is_empty() else 0.0) + 4.0 + sec_h + (36.0 if bool(info.hide) else _icons_h(info.weak, lw)) + 4.0 + sec_h + (36.0 if bool(info.hide) else _icons_h(info.resist, lw))
	var box := Rect2(x, y + 4.0, lw, clampf(a.end.y - y - 4.0 - below, 80.0, 168.0))
	var spr_box := box
	if not six.is_empty():   # 天启篇六维：图靠左、雷达靠右，战商档和控制抗性一行写在图下面
		spr_box = Rect2(x, box.position.y, lw * 0.52, box.size.y)
		var rc := Vector2(x + lw * 0.76, box.position.y + box.size.y / 2.0)
		XSkinSixDimRadar.paint(ci, rc, 38.0, six.six, {"compact": true, "fs": XUiSkin.FS_MIN})
	_draw_enemy_sprite(ci, h, spr_box)
	y = box.end.y + 4.0
	if not six.is_empty():
		var sl := "%s · %s" % [six.tier_line, six.resist_line]
		XUiSkin.ds(ci, body, Vector2(x, y + fa * 0.9), sl, HORIZONTAL_ALIGNMENT_LEFT, lw, fa, XUiSkin.TEXT_2)
		y += fa * 1.6
	y += 4.0
	y = _section(ci, x, y, lw, T_WEAK)
	y = _element_icons(ci, x, y, lw, info.weak, true, a.end.y)
	if y + 4.0 + sec_h < a.end.y:
		y = _section(ci, x, y + 4.0, lw, T_RESIST)
		_element_icons(ci, x, y, lw, info.resist, false, a.end.y)
	# 右栏：能力两列（击败数放最后）、会用的招、备注
	var rx := x + lw + 32.0
	var rw := a.end.x - rx
	ci.draw_line(Vector2(x + lw + 16.0, a.position.y), Vector2(x + lw + 16.0, a.end.y), Color(XUiSkin.LINE, 0.18), 1.0)
	var ry := _section(ci, rx, a.position.y, rw, T_POWER, false)
	var cells: Array = (info.params as Array) + (info.xparams as Array) + [[T_DEFEAT, str(info.defeat)]]
	var cw := (rw - 32.0) / 2.0
	var ch := cell_h() if XSkinList.T366_V1 else CELL_H   # T366（T364 P3）：怪物「能力」格行高也随 130% 字号加高（人物页早已如此）
	for i in cells.size():
		var col := i % 2
		var row := floori(i / 2.0)
		_cell(ci, Rect2(rx + col * (cw + 32.0), ry + row * ch, cw, ch), str(cells[i][0]), str(cells[i][1]))
	ry += ceili(cells.size() / 2.0) * ch + 8.0
	ry = _section(ci, rx, ry, rw, T_MOVES)
	var note: Array = info.note
	var note_spans := []
	for i in note.size():
		note_spans.append([str(note[i]) + ("\n" if i < note.size() - 1 else ""), XUiSkin.TEXT])
	var nfs := XUiSkin.FS_AUX_MAX
	var nlh := nfs * 1.6
	var note_h := 0.0
	if not note.is_empty():   # 备注按折行后的真实行数算高（最多 4 行，再多的裁掉；招式至少留 3 行）
		var want := mini(span_lines(note_spans, rw, nfs), 4)
		var room := floori((a.end.y - ry - MOVE_H_MIN * 3 - 12.0 - XUiSkin.fs(17) * 1.5) / nlh)
		note_h = 12.0 + XUiSkin.fs(17) * 1.5 + clampi(mini(want, room), 1, 4) * nlh
	var bottom := a.end.y - note_h
	_draw_moves(ci, Rect2(rx, ry, rw, maxf(bottom - ry - 4.0, MOVE_H_MIN)))
	if not note.is_empty():
		var ny := _section(ci, rx, bottom, rw, T_NOTE)
		_draw_note(ci, note_spans, rx, ny, rw, nfs, nlh, a.end.y)
	else:
		_note_max = 0.0


## 「会用的招」（旧页列前 10 条）：行距在 MOVE_H_MIN～SKILL_H 之间压到能全放下；还放不下就在这一块里滚（滚轮、手指拖，带细滚动条）
func _draw_moves(ci: CanvasItem, r: Rect2) -> void:
	var body := XUiSkin.font("body")
	var moves: Array = info.moves
	var lfs := XUiSkin.FS_LIST
	var mh := clampf(floorf(r.size.y / maxf(moves.size(), 1.0)), MOVE_H_MIN, SKILL_H)
	var content_h := moves.size() * mh
	moves_row_h = mh
	_skill_max = maxf(content_h - r.size.y, 0.0)
	skill_scroll = clampf(skill_scroll, 0.0, _skill_max)
	_skill_rect = r
	var rw := r.size.x - (10.0 if _skill_max > 0.0 else 0.0)
	var rx := r.position.x
	for i in moves.size():
		var mv: Dictionary = moves[i]
		var top := r.position.y + i * mh - skill_scroll
		if top < r.position.y - 0.5 or top + mh > r.end.y + 0.5:
			continue
		var base := top + mh / 2.0
		if bool(info.hide):
			XUiSkin.ds(ci, body, Vector2(rx, base + lfs * 0.36), XEnemyBookPage.UNKNOWN_DATA, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, XUiSkin.TEXT_3)
			continue
		var wt := T_WEIGHT % mv.weight
		var wfs := XUiSkin.FS_AUX
		var ww := body.get_string_size(wt, HORIZONTAL_ALIGNMENT_LEFT, -1, wfs).x
		XUiSkin.ds(ci, body, Vector2(rx + rw - ww, base + wfs * 0.36), wt, HORIZONTAL_ALIGNMENT_LEFT, -1, wfs, XUiSkin.TEXT_3)
		var cond := str(mv.cond)
		var cfs := XUiSkin.FS_AUX
		var nw := body.get_string_size(str(mv.name), HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
		var cmax := maxf(rw - ww - 12.0 - minf(nw, rw * 0.4) - 16.0, 40.0)
		var cfit := XSkinList.fit_text(body, cond, cmax, cfs, XUiSkin.FS_MIN)
		var cww := body.get_string_size(str(cfit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(cfit[1])).x
		XUiSkin.ds(ci, body, Vector2(rx + rw - ww - 12.0 - cww, base + int(cfit[1]) * 0.36), str(cfit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(cfit[1]), XUiSkin.TEXT_2)
		var nfit := XSkinList.fit_text(body, str(mv.name), rw - ww - cww - 28.0, lfs, XUiSkin.FS_MIN)
		XUiSkin.ds(ci, body, Vector2(rx, base + int(nfit[1]) * 0.36), str(nfit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(nfit[1]), mv.color)
	if _skill_max > 0.0:
		var track := Rect2(r.end.x - 4.0, r.position.y, 4.0, r.size.y)
		var th := maxf(track.size.y * r.size.y / content_h, 16.0)
		var ty := track.position.y + (track.size.y - th) * skill_scroll / _skill_max
		XUiSkin.draw_scrollbar(ci, track, ty, th, Color(1, 1, 1, 0.06), Color(XUiSkin.LINE, 0.55))


## 弱／抗一行图标＋百分比：弱 UP 绿、抗 DOWN 橙、无效（倍率 0）灰；返回下一行顶
func _element_icons(ci: CanvasItem, x: float, y: float, w: float, arr: Array, weak: bool, bottom := INF) -> float:
	var body := XUiSkin.font("body")
	var fs := XUiSkin.FS_AUX
	if bool(info.hide):
		XUiSkin.ds(ci, body, Vector2(x, y + 16 + fs * 0.36), XEnemyBookPage.UNKNOWN_DATA, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_3)
		return y + 36.0
	if arr.is_empty():
		XUiSkin.ds(ci, body, Vector2(x, y + 16 + fs * 0.36), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_3)
		return y + 36.0
	var step := clampf(w / arr.size(), 36.0, 56.0)
	var cx := x
	var line_y := y
	for e in arr:
		if cx + 36.0 > x + w + 0.5:
			cx = x
			line_y += 54.0
		if line_y + 34.0 + fs * 1.1 > bottom + 0.5:
			break   # 面板底放不下的那一行不画（图已经让到最矮）
		var tex := XUiSkin.icon(int(e.icon))
		if tex != null:
			ci.draw_texture_rect(tex, Rect2(cx + (step - 32.0) / 2.0 if step > 32.0 else cx, line_y, 32, 32), false)
		var col := XUiSkin.UP if weak else (XUiSkin.TEXT_3 if float(e.rate) <= 0.0 else XUiSkin.DOWN)
		var pw := body.get_string_size(str(e.pct), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		XUiSkin.ds(ci, body, Vector2(cx + (step - pw) / 2.0, line_y + 34.0 + fs * 0.9), str(e.pct), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		cx += step
	return line_y + 58.0


## _element_icons 占的高（同它的折行）
static func _icons_h(arr: Array, w: float) -> float:
	if arr.is_empty():
		return 36.0
	var step := clampf(w / arr.size(), 36.0, 56.0)
	var per := maxi(1, floori((w + 0.5 - 36.0) / step) + 1)
	return (ceili(arr.size() / float(per)) - 1) * 54.0 + 58.0


func _draw_enemy_sprite(ci: CanvasItem, h: XEnemyBookPage, box: Rect2) -> void:
	var feet := Vector2(box.get_center().x, box.end.y - 14.0)
	# 脚下一圈暗红光
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for k in 32:
		pts.append(feet + Vector2(cos(TAU * k / 32.0) * box.size.x * 0.36, sin(TAU * k / 32.0) * 14.0))
		cols.append(Color(0.55, 0.08, 0.06, 0.32))
	ci.draw_polygon(pts, cols)
	if h._sprite_tex == null:
		return
	var src := Rect2(Vector2.ZERO, h._sprite_tex.get_size())
	if h._sprite_sv:
		var cw := h._sprite_tex.get_width() / 9.0
		var chh := h._sprite_tex.get_height() / 6.0
		var pattern: int = [0, 1, 2, 1][floori(h._frame / 12.0) % 4]
		src = Rect2(pattern * cw, 0, cw, chh)
	var k := minf(1.0, minf((box.size.x - 16.0) / src.size.x, (box.size.y - 8.0) / src.size.y))
	if h._sprite_sv:
		k = minf(1.5, minf((box.size.x - 16.0) / src.size.x, (box.size.y - 8.0) / src.size.y))
	var sz := src.size * k
	ci.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ci.draw_texture_rect_region(h._sprite_tex, Rect2(Vector2(feet.x - sz.x / 2.0, feet.y + 6.0 - sz.y), sz), src)


func _draw_inlay(a: Rect2) -> void:
	var ci := right_panel
	var body := XUiSkin.font("body")
	var x := a.position.x
	var w := a.size.x
	var y := a.position.y
	var fsn := XUiSkin.fs(XUiSkin.FS_CARD)
	XUiSkin.ds(ci, XUiSkin.font("title"), Vector2(x, y + fsn * 0.95), str(info.name), HORIZONTAL_ALIGNMENT_LEFT, w, fsn, info.color)
	y += fsn * 1.4
	var fa := XUiSkin.FS_AUX
	XUiSkin.ds(ci, body, Vector2(x, y + fa * 0.9), T_SLOTS % "、".join(info.types), HORIZONTAL_ALIGNMENT_LEFT, w, fa, XUiSkin.TEXT_2)
	y += fa * 1.8
	if bool(info.has_tpl):
		y = _section(ci, x, y, w, T_INLAY_PARAMS)
		var colw := (w - 3 * 32.0) / 4.0
		for k in 8:
			var pr: Array = info.params[k]
			var zero := bool(pr[2])
			_cell(ci, Rect2(x + (k % 4) * (colw + 32.0), y + floori(k / 4.0) * cell_h(), colw, cell_h()), str(pr[0]), str(pr[1]), XUiSkin.TEXT_3 if zero else XUiSkin.GOLD_LIGHT)
		y += cell_h() * 2 + 10.0
		y = _section(ci, x, y, w, T_INLAY_EFFECT)
		var efs := XUiSkin.FS_AUX_MAX
		for sp in info.effects:
			y = draw_spans(ci, sp, x, y, w, efs, efs * 1.6, a.end.y - 120.0)
		y += 8.0
	var orbs: Array = info.orbs
	if not orbs.is_empty():
		y = _section(ci, x, y, w, T_INLAY_ORDER)
		var cx := x
		var lfs := XUiSkin.FS_LIST
		var num := XUiSkin.font("num")
		for i in orbs.size():
			var o: Dictionary = orbs[i]
			var label := str(i + 1)
			var lw := num.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
			var nw := body.get_string_size(str(o.name), HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
			var item_w := lw + 8.0 + 32.0 + 8.0 + nw
			if cx + item_w > x + w and cx > x:
				cx = x
				y += 44.0
			var base := y + 20.0
			XUiSkin.ds(ci, num, Vector2(cx, base + XUiSkin.FS_AUX * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX, XUiSkin.TEXT_3)
			cx += lw + 8.0
			var tex := XUiSkin.icon(int(o.icon)) if int(o.icon) > 0 else null
			if tex != null:
				ci.draw_texture_rect(tex, Rect2(cx, base - 16.0, 32, 32), false)
			cx += 40.0
			XUiSkin.ds(ci, body, Vector2(cx, base + lfs * 0.36), str(o.name), HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, o.color)
			cx += nw
			if i < orbs.size() - 1:
				var sep := "›"
				XUiSkin.ds(ci, body, Vector2(cx + 14.0, base + lfs * 0.36), sep, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, XUiSkin.TEXT_3)
				cx += 40.0
		y += 48.0
	if str(info.gem_note) != "":
		var nfs := XUiSkin.FS_AUX
		draw_spans(ci, [[str(info.gem_note), XUiSkin.TEXT_3]], x, maxf(y, a.end.y - nfs * 1.6 * 2), w, nfs, nfs * 1.6, a.end.y)


func _process(_delta: float) -> void:
	# 战斗里旧页被收在 16:9 中间（XBattleScene._open_battle_book 设了 offset）：压暗层要盖满整个战斗画面
	if in_battle and host != null and (offset_left != -host.offset_left or offset_right != -host.offset_right):
		offset_left = -host.offset_left
		offset_right = -host.offset_right
	# 人物小人、怪物侧视图 0-1-2-1 每 12 帧换一格（旧页自己数帧）；动效关时也照动（是待机动作，不是界面动效）
	if kind == "inlay" or host == null:
		return
	var f: int = host.get("_frame")
	if f % 12 == 0 and right_panel != null:
		right_panel.queue_redraw()
	if pager != null and list != null and pager.visible != (list.rows_total() > list.visible_rows()):
		left_panel.queue_redraw()
