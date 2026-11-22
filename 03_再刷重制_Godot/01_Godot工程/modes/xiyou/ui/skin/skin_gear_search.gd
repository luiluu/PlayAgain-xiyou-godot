class_name XSkinGearSearch
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】T368 卡 G（T254 R9）：装备检索新皮肤版，网页表单改成「筛选小块」，套模板页（XSkinTemplatePage，不要分类环）。
## - 左块：筛选小块，点一下就生效（数据与规则照旧在 XGearSearch.filter／XGearQuery，本页只换摆法）：
##     「搜词条」一枚按钮（自画放大镜）（点了才出输入框、才弹键盘；有词时写「搜：…」，右端 ✕ 清掉）；
##     品质七枚色块（可多选，filter.quality 逗号分隔）＋「★」（旧档细分，在挑选框里多选）；部位一排图标（单选，再点取消）；
##     位置两枚「已装备」「背包」（单选，再点回到全部）；排序四枚「品质」「词条数」「名称」「更多 ▾」（更多＝原有顺序、战力、八项能力、单项词条）；
##     「分类 ▾」「指定词条 ▾」各一枚（点开挑选框）；最底「清空条件」。
## - 中块：通用直列表（一列），小标题「符合 a / b 件 · 排序：…」；没有结果时列表正中一句人话。
## - 右块：详情牌（XSkinCard，长了折叠，Y 看完整）：名字（品质色）、品质与位置、能力格子、说明、按分类的词条；牌底主按钮「按此筛选」。
## - 挑选框：盖在中块上的小列表（XSkinList），确定选、取消关；旧档品质那一框可多选（✓）。
## 按键（XGearSearch._input 转进来）：焦点 filters／list／card／picker／typing。筛选区方向键走小块、确定切换、→ 到行尾进列表；
## 列表 ← 回筛选区、确定到牌上的「按此筛选」；X 搜词条；取消：输入框 → 挑选框 → 牌 → 关页。
## 开关：XGearSearch.SKIN_PAGE_R9（false＝回到 T361 的模板版式）。

const CHIP_H := 36.0
const CHIP_GAP := 6.0
const GROUP_GAP := 10.0
const LABEL_H := 26.0
const SORT_MAIN := ["quality", "count", "name"]
const SORT_MAIN_NAMES := {"quality": "品质", "count": "词条数", "name": "名称"}

var host: XGearSearch
## 筛选区（自画，点击在 _filters_input）
var filters: Control
## [{group, key, rect, text, color, icon, on}]
var chips: Array = []
var cursor := 0
var search_edit: LineEdit
var picker_panel: Panel
var picker: XSkinList
var picker_title := ""
var picker_kind := ""
var _picker_keys: Array = []
## 最近一次 refresh_results 喂给列表的行（测试用）
var rows_fed: Array = []


func _init() -> void:
	title = "装备检索"
	show_ring = false
	auto_nav = false
	columns = 1
	row_height = XUiSkin.ROW_H
	currencies = []
	left_w = 300.0
	right_w = 336.0
	hint_list = filter_hints()


func _ready() -> void:
	super._ready()
	card.fold = true
	filters = Control.new()
	filters.name = "GearFilters"
	filters.mouse_filter = Control.MOUSE_FILTER_STOP
	filters.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	filters.draw.connect(_draw_filters)
	filters.gui_input.connect(_filters_input)
	filters.resized.connect(rebuild_chips)
	layout.left.add_child(filters)
	search_edit = LineEdit.new()
	search_edit.visible = false
	search_edit.placeholder_text = "搜装备名或词条，空格隔开"
	search_edit.add_theme_font_override("font", XUiSkin.font("body"))
	search_edit.add_theme_font_size_override("font_size", XUiSkin.FS_AUX_MAX)
	search_edit.add_theme_color_override("font_color", XUiSkin.TEXT)
	search_edit.add_theme_color_override("font_placeholder_color", XUiSkin.TEXT_3)
	search_edit.add_theme_color_override("caret_color", XUiSkin.GOLD)
	search_edit.add_theme_stylebox_override("normal", _edit_box(Color(XUiSkin.GOLD, 0.7)))
	search_edit.add_theme_stylebox_override("focus", _edit_box(Color(XUiSkin.GOLD, 0.7)))
	search_edit.text_changed.connect(func(t): host._on_field(t, "query"))
	search_edit.text_submitted.connect(func(_t): close_search())
	search_edit.focus_exited.connect(func():
		if search_edit.visible:
			close_search.call_deferred())
	filters.add_child(search_edit)
	picker_panel = Panel.new()
	picker_panel.visible = false
	picker_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	picker_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ps := StyleBoxFlat.new()   # 盖在列表上：实心暖炭底（规范 8 U-03 ≥ 94%），1px 旧金细线
	ps.bg_color = Color(XSkinConfirm.DLG_LOW, 0.97)
	ps.border_color = Color(XUiSkin.GOLD, 0.4)
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(XUiSkin.RADIUS)
	ps.anti_aliasing = true
	picker_panel.add_theme_stylebox_override("panel", ps)
	picker_panel.draw.connect(_draw_picker)
	layout.center.add_child(picker_panel)
	picker = XSkinList.new()
	picker.row_height = 40
	picker.icon_size = 24
	picker.activated.connect(_picker_pick)
	picker_panel.add_child(picker)
	picker_panel.resized.connect(_place_picker)
	card_button.connect(func(_i): host.apply_filter())
	list.index_changed.connect(_on_list_index)
	list.gui_input.connect(_list_tapped)   # R1 P2-3：点列表行＝焦点回到列表
	list.empty_center = true
	list.empty_text = "没有符合的装备，放宽条件再找找。"
	set_focus("list")
	rebuild_chips()


static func _edit_box(edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.55)
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(XUiSkin.ROW_RADIUS)
	s.content_margin_left = 12
	s.content_margin_right = 12
	return s


# ---- 筛选条件读写（都落到 XGearSearch.filter）----

static func quality_set(f: Dictionary) -> Array:
	return Array(str(f.get("quality", "")).split(",", false))


static func toggle_quality(f: Dictionary, key: String) -> void:
	var s := quality_set(f)
	if s.has(key):
		s.erase(key)
	else:
		s.append(key)
	f.quality = ",".join(s)


## 小块被点：改条件，返回 true＝条件变了（要重算结果）
func press_chip(i: int) -> void:
	if i < 0 or i >= chips.size():
		return
	cursor = i
	var c: Dictionary = chips[i]
	var f := XGearSearch.filter
	match str(c.group):
		"search":
			if bool(c.get("clear", false)):
				host._on_field("", "query")
			else:
				open_search()
		"search_clear":
			host._on_field("", "query")
		"quality":
			toggle_quality(f, str(c.key))
			host._render_results()
		"legacy":
			open_picker("legacy")
		"type":
			host._on_field("" if str(f.type) == str(c.key) else str(c.key), "type")
		"scope":
			host._on_field("all" if str(f.scope) == str(c.key) else str(c.key), "scope")
		"sort":
			if str(c.key) == "more":
				open_picker("sort")
			else:
				host._on_sort(str(c.key))
		"category":
			open_picker("category")
		"term":
			open_picker("term")
		"reset":
			host._on_reset()
	rebuild_chips()


## 按现在的条件重排小块（位置、文字、开没开）
func rebuild_chips() -> void:
	if filters == null or host == null:
		return
	var f := XGearSearch.filter
	var w := filters.size.x
	if w <= 0:
		return
	var out := []
	var y := 0.0
	# 搜词条
	var q := str(f.get("query", ""))
	if q == "":
		out.append({"group": "search", "key": "", "rect": Rect2(0, y, w, CHIP_H + 4), "text": "搜词条", "on": false, "magnifier": true})
	else:
		out.append({"group": "search", "key": "", "rect": Rect2(0, y, w - CHIP_H - 4 - CHIP_GAP, CHIP_H + 4), "text": "搜：" + q, "on": true})
		out.append({"group": "search_clear", "key": "", "rect": Rect2(w - CHIP_H - 4, y, CHIP_H + 4, CHIP_H + 4), "text": "✕", "on": false})
	y += CHIP_H + 4 + GROUP_GAP
	# 品质：七档色块＋旧档细分
	var qs := quality_set(f)
	var cfg := XQuality.config()
	var legacy: Array = cfg.get("starMarks", {}).keys()
	var n := mini(cfg.names.size(), 7)
	var qw := floorf((w - CHIP_GAP * (n + (1 if not legacy.is_empty() else 0) - 1)) / float(n + (1 if not legacy.is_empty() else 0)))
	qw = minf(qw, CHIP_H)
	y += LABEL_H
	for i in n:
		out.append({"group": "quality", "key": str(i), "rect": Rect2(i * (qw + CHIP_GAP), y, qw, CHIP_H), "text": str(cfg.names[i]),
			"color": XUiSkin.quality_color(i), "on": qs.has(str(i))})
	if not legacy.is_empty():
		var lon := qs.any(func(k): return str(k).begins_with("L"))
		out.append({"group": "legacy", "key": "", "rect": Rect2(n * (qw + CHIP_GAP), y, qw, CHIP_H), "text": "★", "on": lon})
	y += CHIP_H + GROUP_GAP
	# 部位：一排图标（放不下折行；行数多到左块放不下时图标收小，R1 P2-4：后期 30 种部位 5 行会掉出底边）
	y += LABEL_H
	var types := type_icons()
	var ts := type_chip_size(types.size(), w, filters.size.y)
	var tx := 0.0
	for t in types:
		if tx > 0 and tx + ts > w + 0.5:
			tx = 0.0
			y += ts + CHIP_GAP
		out.append({"group": "type", "key": str(t.key), "rect": Rect2(tx, y, ts, ts), "text": str(t.name), "icon": int(t.icon),
			"on": str(f.type) == str(t.key)})
		tx += ts + CHIP_GAP
	y += ts + GROUP_GAP
	# 位置：两枚
	y += LABEL_H
	var half := floorf((w - CHIP_GAP) / 2.0)
	for k in 2:
		var key: String = ["worn", "bag"][k]
		out.append({"group": "scope", "key": key, "rect": Rect2(k * (half + CHIP_GAP), y, half, CHIP_H), "text": ["已装备", "背包"][k],
			"on": str(f.scope) == key})
	y += CHIP_H + GROUP_GAP
	# 排序：四枚
	y += LABEL_H
	var sw := floorf((w - CHIP_GAP * 3) / 4.0)
	var sort := str(f.sort)
	for k in 4:
		var key: String = SORT_MAIN[k] if k < 3 else "more"
		var text: String = SORT_MAIN_NAMES[key] if k < 3 else (sort_short(sort) + " ▾" if sort not in SORT_MAIN else "更多 ▾")
		out.append({"group": "sort", "key": key, "rect": Rect2(k * (sw + CHIP_GAP), y, sw, CHIP_H), "text": text,
			"on": sort == key or (key == "more" and sort not in SORT_MAIN)})
	y += CHIP_H + GROUP_GAP
	# 分类、指定词条：各一枚，点开挑选框
	out.append({"group": "category", "key": "", "rect": Rect2(0, y, w, CHIP_H), "text": "分类：" + (str(f.category) if str(f.category) != "" else "全部") + " ▾",
		"on": str(f.category) != ""})
	y += CHIP_H + CHIP_GAP
	out.append({"group": "term", "key": "", "rect": Rect2(0, y, w, CHIP_H), "text": "指定词条：" + term_text(str(f.term)) + " ▾",
		"on": str(f.term) != ""})
	y += CHIP_H + GROUP_GAP
	out.append({"group": "reset", "key": "", "rect": Rect2(0, y, w, CHIP_H), "text": "清空条件", "on": false})
	chips = out
	cursor = clampi(cursor, 0, chips.size() - 1)
	if search_edit != null:
		search_edit.position = chips[0].rect.position
		search_edit.size = Vector2(w, CHIP_H + 4)
	filters.queue_redraw()


## 除部位图标那几行外，左块别的小块与小标题占的高（搜词条、品质、位置、排序各一行带小标题，分类、指定词条、清空三行）
const FIXED_H := (CHIP_H + 4 + GROUP_GAP) + (LABEL_H + CHIP_H + GROUP_GAP) * 3 + (LABEL_H + GROUP_GAP) \
		+ (CHIP_H + CHIP_GAP) + (CHIP_H + GROUP_GAP) + CHIP_H
const TYPE_MIN := 24.0


## 部位图标边长：n 枚按行排进宽 w，整列高 h 放得下就用 CHIP_H，放不下逐像素收小（最小 TYPE_MIN）
static func type_chip_size(n: int, w: float, h: float) -> float:
	if n <= 0 or h <= 0:
		return CHIP_H
	var avail := h - FIXED_H
	var s := CHIP_H
	while s > TYPE_MIN:
		var per := maxi(1, floori((w + CHIP_GAP) / (s + CHIP_GAP)))
		var rows := ceili(n / float(per))
		if rows * (s + CHIP_GAP) - CHIP_GAP <= avail:
			break
		s -= 1.0
	return s


## 部位图标：检索源里每种部位取第一件的图标（没有图标的用空框写首字）
func type_icons() -> Array:
	var out := []
	var opts := XGearSearch.type_options(host.source)
	for o in opts:
		if str(o[0]) == "":
			continue
		var ic := 0
		for r in host.source:
			if XGearQuery.type_key(r.item) == str(o[0]):
				ic = int(r.item.get("iconIndex", 0))
				if ic > 0:
					break
		out.append({"key": str(o[0]), "name": str(o[1]), "icon": ic})
	return out


func sort_short(sort: String) -> String:
	if sort.begins_with("param"):
		return XGearQuery.PARAMS[int(sort.substr(5))]
	match sort:
		"original":
			return "默认"
		"power":
			return "战力"
		"term":
			return "词条"
	return str(SORT_MAIN_NAMES.get(sort, sort))


func term_text(key: String) -> String:
	if key == "":
		return "不限"
	for o in XGearSearch.term_options(host.source):
		if str(o[0]) == key:
			return str(o[1])
	return key


## 选中的部位、品质的名字（小标题后写一句，图标认不出时看字）
func group_note(group: String) -> String:
	var f := XGearSearch.filter
	match group:
		"quality":
			var names := []
			for o in XGearSearch.quality_options():
				if str(o[0]) != "" and quality_set(f).has(str(o[0])):
					names.append(str(o[1]))
			return "、".join(names) if not names.is_empty() else "全部"
		"type":
			if focus == "filters" and cursor >= 0 and cursor < chips.size() and str(chips[cursor].group) == "type":
				return "› " + str(chips[cursor].text)   # R1 P3-2：光标停在部位图标上先预览名字
			for o in XGearSearch.type_options(host.source):
				if str(o[0]) == str(f.type):
					return str(o[1]) if str(o[0]) != "" else "全部"
			return "全部"
		"scope":
			for o in XGearQuery.SCOPES:
				if str(o[0]) == str(f.scope):
					return str(o[1])
	return ""


# ---- 画筛选区 ----

func _draw_filters() -> void:
	var body := XUiSkin.font("body")
	var labels := {"quality": "品质", "type": "部位", "scope": "位置", "sort": "排序"}
	var seen := {}
	for i in chips.size():
		var c: Dictionary = chips[i]
		var g := str(c.group)
		var lg := "quality" if g == "legacy" else g
		if labels.has(lg) and not seen.has(lg):
			seen[lg] = true
			var ly: float = c.rect.position.y - 9
			var lab := str(labels[lg])
			XUiSkin.ds(filters, body, Vector2(0, ly), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.fs(15), XUiSkin.TEXT_2)
			var note := group_note(lg)
			if note != "":
				var lw := body.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.fs(15)).x
				XUiSkin.ds(filters, body, Vector2(lw + 10, ly), note, HORIZONTAL_ALIGNMENT_LEFT, filters.size.x - lw - 10, XUiSkin.fs(15), XUiSkin.TEXT)
		_draw_chip(c, i == cursor and focus == "filters")


func _draw_chip(c: Dictionary, cur: bool) -> void:
	var r: Rect2 = c.rect
	var on := bool(c.on)
	var g := str(c.group)
	if g == "search" and search_edit != null and search_edit.visible:
		return
	var body := XUiSkin.font("body")
	if g == "quality":
		var col: Color = c.color
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col, 0.95 if on else 0.32)
		sb.set_corner_radius_all(XUiSkin.ROW_RADIUS)
		sb.anti_aliasing = true
		sb.border_color = Color(XUiSkin.GOLD) if on else Color(col, 0.6)
		sb.set_border_width_all(2 if on else 1)
		filters.draw_style_box(sb, r)
		if on:
			var m := r.get_center()
			filters.draw_polyline(PackedVector2Array([m + Vector2(-7, 0), m + Vector2(-2, 5), m + Vector2(7, -5)]), Color(0.06, 0.05, 0.05), 2.5, true)
	elif g == "type":
		var sb := _chip_box(on)
		filters.draw_style_box(sb, r)
		var tex := XUiSkin.icon(int(c.get("icon", 0)))
		if tex != null:
			filters.draw_texture_rect(tex, r.grow(-3), false, Color(1, 1, 1, 1.0 if on else 0.62))
		else:
			var t := str(c.text).left(1)
			XUiSkin.ds(filters, body, Vector2(r.position.x, r.get_center().y + 6), t, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, XUiSkin.fs(16), XUiSkin.TEXT)
	else:
		filters.draw_style_box(_chip_box(on), r)
		var fs := XUiSkin.fs(16)
		var col := XUiSkin.GOLD_LIGHT if on else XUiSkin.TEXT
		if g == "reset" or g == "search_clear":
			col = XUiSkin.TEXT_2
		var align := HORIZONTAL_ALIGNMENT_LEFT if g in ["search", "category", "term"] else HORIZONTAL_ALIGNMENT_CENTER
		var px := 12.0 if align == HORIZONTAL_ALIGNMENT_LEFT else 2.0
		if bool(c.get("magnifier", false)):   # R1 P3-1：「⌕」在玩家版字体里糊成小点，改自画放大镜
			var mc := Vector2(r.position.x + 12 + 7, r.get_center().y - 2)
			filters.draw_arc(mc, 6.0, 0, TAU, 24, col, 1.8, true)
			filters.draw_line(mc + Vector2(4.5, 4.5), mc + Vector2(9, 9), col, 2.2, true)
			px += 24.0
		XUiSkin.ds(filters, body, Vector2(r.position.x + px, r.get_center().y + fs * 0.36), str(c.text), align, r.size.x - px * 2, fs, col)
	if cur:
		var cs := StyleBoxFlat.new()
		cs.draw_center = false
		cs.border_color = XUiSkin.SEL_LINE
		cs.set_border_width_all(2)
		cs.set_corner_radius_all(XUiSkin.ROW_RADIUS + 2)
		cs.anti_aliasing = true
		filters.draw_style_box(cs, r.grow(3))


static func _chip_box(on: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(XUiSkin.panel_c(), 0.92)
	sb.border_color = Color(XUiSkin.GOLD, 0.85) if on else Color(XUiSkin.line_c(), 0.42)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(XUiSkin.ROW_RADIUS)
	sb.anti_aliasing = true
	return sb


func chip_at(p: Vector2) -> int:
	for i in chips.size():
		if (chips[i].rect as Rect2).has_point(p):
			return i
	return -1


var _press_chip := -1


func _filters_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		pressed = event.pressed
	elif event is InputEventScreenTouch:
		pos = event.position
		pressed = event.pressed
	else:
		return
	filters.accept_event()
	var i := chip_at(pos)
	if pressed:
		_press_chip = i
		return
	if i >= 0 and i == _press_chip:
		set_focus("filters")
		press_chip(i)
	_press_chip = -1


# ---- 搜词条：点了才出输入框 ----

func open_search() -> void:
	if picker_panel.visible:
		close_picker()
	if card.expanded:
		card.set_expanded(false)
	card.set_process_input(false)   # R1 P2-1：输入时 Y 不给详情牌拦走（牌的 _input 先于页面收键）
	search_edit.text = str(XGearSearch.filter.get("query", ""))
	search_edit.visible = true
	set_focus("typing")
	search_edit.grab_focus()
	search_edit.caret_column = search_edit.text.length()
	filters.queue_redraw()


func close_search() -> void:
	if not search_edit.visible:
		return
	search_edit.visible = false
	search_edit.release_focus()
	card.set_process_input(true)
	set_focus("filters")
	rebuild_chips()


func typing() -> bool:
	return search_edit != null and search_edit.visible


## 输入时这一下点在输入框外面（R1 P2-1：点别的小块／列表／牌先收起输入框，不然 typing 卡住、键盘失灵）
func tap_outside_edit(event: InputEvent) -> bool:
	var pos := Vector2.INF
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	if pos == Vector2.INF:
		return false
	return not search_edit.get_global_rect().has_point(pos)


# ---- 挑选框（分类、指定词条、更多排序、旧档品质）----

func open_picker(kind: String) -> void:
	if typing():
		close_search()
	picker_kind = kind
	var f := XGearSearch.filter
	var opts := []
	var cur := ""
	var multi := false
	match kind:
		"category":
			picker_title = "分类"
			opts = [["", "全部分类"]] + XGearQuery.CATEGORIES.map(func(c): return [c, c])
			cur = str(f.category)
		"term":
			picker_title = "指定词条"
			opts = XGearSearch.term_options(host.source)
			cur = str(f.term)
		"sort":
			picker_title = "排序"
			opts = XGearSearch.sort_options(host.source, f).filter(func(o): return str(o[0]) not in SORT_MAIN)
			cur = str(f.sort)
		"legacy":
			picker_title = "品质细分（可多选）"
			opts = XGearSearch.quality_options().filter(func(o): return str(o[0]).begins_with("L"))
			multi = true
	_picker_keys = opts.map(func(o): return str(o[0]))
	var qs := quality_set(f)
	var items := []
	var sel := 0
	for k in opts.size():
		var it := {"text": str(opts[k][1]).replace("\n", " ")}
		if multi:
			it.check = 1 if qs.has(str(opts[k][0])) else 0
		elif str(opts[k][0]) == cur:
			sel = k
			it.color = XUiSkin.GOLD_LIGHT
		items.append(it)
	picker.check_column = multi
	picker.set_items(items)
	picker.select(sel, false)
	picker_panel.visible = true
	_place_picker()
	set_focus("picker")


func close_picker() -> void:
	picker_panel.visible = false
	set_focus("filters")
	rebuild_chips()


func _place_picker() -> void:
	if picker == null:
		return
	var s := picker_panel.size
	var rows := floori((s.y - LIST_TOP - XUiSkin.PAD) / float(picker.row_height))
	var lx := 28.0 if XSkinArt.select_on() else 8.0   # R1 P2-2：外置选中箭头左探 22，同模板页列表留 28
	picker.position = Vector2(lx, LIST_TOP)
	picker.size = Vector2(s.x - lx - 8.0, maxi(rows, 1) * picker.row_height)


func _draw_picker() -> void:
	var body := XUiSkin.font("body")
	XUiSkin.ds(picker_panel, body, Vector2(XUiSkin.PAD + 8, XUiSkin.PAD + 20), picker_title, HORIZONTAL_ALIGNMENT_LEFT, picker_panel.size.x - 48, XUiSkin.fs(20), XUiSkin.GOLD)


func _picker_pick(i: int) -> void:
	if i < 0 or i >= _picker_keys.size():
		return
	var key := str(_picker_keys[i])
	match picker_kind:
		"category":
			host._on_field(key, "category")
		"term":
			host._on_term(key)
		"sort":
			host._on_sort(key)
		"legacy":
			toggle_quality(XGearSearch.filter, key)
			host._render_results()
			var items := picker.items.duplicate(true)
			items[i].check = 1 if quality_set(XGearSearch.filter).has(key) else 0
			picker.set_items(items, true)
			rebuild_chips()
			return
	close_picker()


# ---- 结果 ----

## 结果变了：列表、小标题、详情牌
func refresh_results() -> void:
	var res: Array = host._results
	list_title = "符合 %d / %d 件 · 排序：%s" % [res.size(), host.source.size(), sort_name(str(XGearSearch.filter.sort))]
	rows_fed = res.map(row_of)
	var idx := maxi(0, res.find_custom(func(r): return r.key == XGearSearch.selected_key))
	set_items(rows_fed, idx)
	_update_card()
	rebuild_chips()
	if hints != null:
		set_hint_list(_hints_for(focus))


func sort_name(sort: String) -> String:
	for o in XGearSearch.sort_options(host.source, XGearSearch.filter):
		if str(o[0]) == sort:
			return str(o[1]).replace("\n", " ")
	return str(XGearQuery.SORT_NAMES.get(sort, sort))


static func row_of(r: Dictionary) -> Dictionary:
	var item: Dictionary = r.item
	var rec := XGearQuery.record(item)
	var row := {"text": XGearSearch.star_name(item), "icon": int(item.get("iconIndex", 0)), "color": XQuality.color(item),
		"right": "%d条" % rec.rows.size(), "right_color": XUiSkin.TEXT_2}
	if str(r.owner) != "":
		row.tags = ["穿着"]
	return row


func _list_tapped(event: InputEvent) -> void:
	var press: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)
	if press and focus in ["filters", "card"]:
		set_focus("list")


func _on_list_index(i: int) -> void:
	if i < 0 or i >= host._results.size():
		return
	XGearSearch.selected_key = str(host._results[i].key)
	_update_card()


func _update_card() -> void:
	var cur: Array = host._results.filter(func(x): return x.key == XGearSearch.selected_key)
	if cur.is_empty():
		set_card({})
		return
	set_card(card_of(cur[0]))


## 详情牌内容：照 XGearSearch.detail_blocks 一块不落地换成牌的写法
static func card_of(r: Dictionary) -> Dictionary:
	var item: Dictionary = r.item
	var d := {"icon": XUiSkin.icon(int(item.get("iconIndex", 0))), "title_color": XQuality.color(item),
		"buttons": [{"text": "按此筛选", "primary": true}]}
	var sections := []
	var descs := []
	var pills_seen := false
	var sec: Dictionary = {}
	for b in XGearSearch.detail_blocks(r):
		match str(b.tag):
			"h2":
				d.title = str(b.text)
			"meta":
				d.subtitle = str(b.text)
			"power":
				sec = {"title": str(b.text), "rows": []}
				sections.append(sec)
			"note":
				if not pills_seen and not sec.is_empty():
					(sec.rows as Array).append({"text": str(b.text), "color": XUiSkin.TEXT_2})
				else:
					descs.append(str(b.text))
			"pills":
				pills_seen = true
				var cells := []
				for p in b.pills:
					var s := str(p)
					var k := s.rfind(" ")
					cells.append([s.left(k), s.substr(k + 1)] if k > 0 else [s, ""])
				if not cells.is_empty():
					sections.append({"title": "能力", "cells": cells})
				sec = {}
			"h3":
				sec = {"title": str(b.text), "rows": []}
				sections.append(sec)
			"effect":
				(sec.rows as Array).append({"text": str(b.text), "color": XUiSkin.TEXT})
				(sec.rows as Array).append({"text": str(b.small), "color": XUiSkin.TEXT_2})
			_:
				descs.append(str(b.text))
	d.desc = "\n".join(descs)
	d.sections = sections
	return d


# ---- 焦点与按键 ----

func filter_hints() -> Array:
	return [["确定", "切换"], ["X", "搜词条"], ["取消", "返回"]]


func _hints_for(f: String) -> Array:
	match f:
		"list":
			return [["确定", "选择"], ["X", "搜词条"], ["取消", "返回"]]
		"card":
			return [["确定", "按此筛选"], ["取消", "返回列表"]]
		"picker":
			return [["确定", "选择"], ["取消", "关闭"]]
		"typing":
			return [["取消", "收起"]]   # R1 P3-1：「回车」不是可点的键，触屏点不了；「取消」点了收起输入框
	return filter_hints()


func set_focus(f: String) -> void:
	super.set_focus(f)
	if picker != null:
		picker.active = f == "picker"
	if filters != null:
		filters.queue_redraw()
	if hints != null:
		set_hint_list(_hints_for(f))


## 取消：输入框 → 挑选框 → 牌 → 关页；返回 true＝页内用掉了（不关页）
func cancel_step() -> bool:
	if typing():
		close_search()
		return true
	if picker_panel.visible:
		close_picker()
		return true
	if focus == "card":
		set_focus("list")
		return true
	return false


## 方向键、确定（XGearSearch._input 转进来；取消另走 cancel_step）
func handle_key(event: InputEvent) -> bool:
	if typing():
		return false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_X:
		open_search()
		return true
	match focus:
		"picker":
			return picker.handle_input(event)
		"filters":
			return _filters_key(event)
		"list":
			if event.is_action_pressed("ui_left", true):
				set_focus("filters")
				return true
			if event.is_action_pressed("ui_accept"):
				if not host._results.is_empty():
					set_focus("card")
				return true
			return list.handle_input(event)
		"card":
			if event.is_action_pressed("ui_accept"):
				host.apply_filter()
				return true
			if event.is_action_pressed("ui_left", true):
				set_focus("list")
				return true
			return card.handle_input(event)
	return false


func _filters_key(event: InputEvent) -> bool:
	if chips.is_empty():
		return false
	if event.is_action_pressed("ui_accept"):
		press_chip(cursor)
		return true
	var c: Rect2 = chips[cursor].rect
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		var dx := -1 if event.is_action_pressed("ui_left", true) else 1
		var j := cursor + dx
		if j >= 0 and j < chips.size() and absf((chips[j].rect as Rect2).position.y - c.position.y) < 1.0:
			cursor = j
		elif dx > 0:
			set_focus("list")
			return true
		filters.queue_redraw()
		return true
	if event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true):
		var dy := -1 if event.is_action_pressed("ui_up", true) else 1
		var best := -1
		var best_d := INF
		var row_y := INF if dy > 0 else -INF
		for j in chips.size():   # 上一行／下一行：先找最近的那一行，再挑 x 最近的
			var y := (chips[j].rect as Rect2).position.y
			if (dy > 0 and y > c.position.y + 1 and y < row_y) or (dy < 0 and y < c.position.y - 1 and y > row_y):
				row_y = y
		for j in chips.size():
			var r: Rect2 = chips[j].rect
			if absf(r.position.y - row_y) < 1.0:
				var d := absf(r.get_center().x - c.get_center().x)
				if d < best_d:
					best_d = d
					best = j
		if best >= 0:
			cursor = best
		filters.queue_redraw()
		return true
	return false
