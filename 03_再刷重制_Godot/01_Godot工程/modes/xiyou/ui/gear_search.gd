class_name XGearSearch
extends XWebPanel
## 装备词条检索面板（正式西游 v0.28 Codex installEquipmentStatusRuntime 的网页覆盖层＋installGamePanelTheme 外观）。
## 正式版是画布上面的 DOM：物品页/装备页右上角「装备检索 / 排序」「清除筛选」两个按钮（toolbar），点开后整页面板；
## 这里用 Godot 控件照运行时读数（参照浏览器 1280×720，04_验证/本地结果/原版参照/bajie_equip_search/）复现：
## - 工具条：右上 (−8, 8)，按钮间距 6，字号 17、内边距 5/9、高 39.2；筛选中时第一个按钮写「词条筛选中 · N件」。
## - 面板 (8,8,1264,704)：底色 #16161f、圆角 8、Window 皮肤边框（96,0,96,96 切 24，画进 12px 边）、内边距 16/20。
##   标题「装备词条检索」23 号粗体 (40,36)，说明 13 号；「关闭 · Esc」靠右；标题区下 1px 分隔线，下距 12。
##   筛选：搜索框整行 (40,116.6,1200,41.2)；其后 分类／部位／品质／位置／指定词条／排序 下拉（标签 13 号系统色、间距 5，
##   下拉高 36、宽按最长项、最多 260）与「清空条件」按钮，间距 8 自动换行。「找到 N / M 件装备」13 号。
##   结果列表占 43%（516）、详情其余（间距 12），高度到底部栏上 9；底部栏左说明、右「应用到装备列表」(1099,642.8,141,41.2)。
##   列表行：内边距 8/12，名字 17 号（行高 27.2）、摘要 12 号（19.2），行高 63.4、行距 5；选中行光标色。
##   详情：名字 23 号、品质与位置、装备战力（金色）与三项、说明，能力胶囊（金色），描述，按分类排列的词条卡（左边 3px 系统色）。
## - 操作：搜索/下拉即时刷新；Esc 或「关闭」关掉；Tab 在控件间移动。打开时游戏窗口不响应输入（页面判断 is_open）。
## - 「应用到装备列表」：保存排序、把条件交给页面（applied 信号），关闭；「清除筛选」由页面清空条件。
## 条件 filter 与选中项在本次运行内保留（正式版是模块变量），读配置时排序回到配置值。

signal applied(filter: Dictionary)

const NOTE_TEXT := "按当前属性、法宝等级和已识别战斗词条估算；品质与刷宝收益不直接加分。"

static var filter := {}
static var selected_key := ""

var source: Array = []            # [{item, owner, key}]
var _results: Array = []
var _search: LineEdit
var _count: Label
var _list_box: VBoxContainer
var _list_scroll: ScrollContainer
var _detail_box: VBoxContainer
var _detail_scroll: ScrollContainer
var _fields: Control
var _sort_select: OptionButton


static func reset_session() -> void:
	filter = XGearQuery.default_view()
	selected_key = ""


# ---- 工具条（物品页、装备页右上角） ----
## 返回 HBox，第一个按钮是「装备检索 / 排序」
static func make_toolbar(on_open: Callable, on_clear: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for spec in [["装备检索 / 排序", on_open], ["清除筛选", on_clear]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		style_button(b, Vector2(9, 5))
		b.custom_minimum_size.y = 39.2
		b.pressed.connect(spec[1])
		h.add_child(b)
	h.resized.connect(func(): h.position = Vector2(1280 - 8 - h.size.x, 8))
	h.position = Vector2(1280 - 8 - h.get_combined_minimum_size().x, 8)
	return h


static func toolbar_label(active: bool, count: int) -> String:
	return "词条筛选中 · %d件" % count if active else "装备检索 / 排序"


# ---- 数据 ----
static func grade_text(q: int) -> String:
	return str(XQuality.config().names[XQuality.grade_of(q)])


static func star_name(item: Dictionary) -> String:
	return XQuality.stars(item) + XGearQuery.text(str(item.get("name", "")))


## 列表行的摘要（cq-row small）
static func row_small(r: Dictionary) -> String:
	var rec := XGearQuery.record(r.item)
	var power := " · 战力 " + XPower.format(float(XPower.equipment(r.item).get("total", 0.0))) if XPower.enabled() else ""
	return "%s%s · %d条 · %s · %s" % [grade_text(rec.quality), power, rec.rows.size(),
		"已装备：" + str(r.owner) if str(r.owner) != "" else "背包", " / ".join(rec.categories)]


## 详情各块：{tag: h2/meta/h3/power/note/pills/effect/empty, text, small, pills}
static func detail_blocks(r: Dictionary) -> Array:
	var item: Dictionary = r.item
	var out := [{"tag": "h2", "text": star_name(item)},
		{"tag": "meta", "text": grade_text(XGearQuery.quality(item)) + " · " + ("已装备：" + str(r.owner) if str(r.owner) != "" else "背包")}]
	if XPower.enabled():
		var score := XPower.equipment(item)
		out.append({"tag": "power", "text": "装备战力 " + XPower.format(float(score.get("total", 0.0)))})
		var parts: Array = score.get("parts", [0, 0, 0])
		var lines := []
		for i in range(XPower.LABELS.size()):
			lines.append(XPower.LABELS[i] + " " + XPower.format(float(parts[i]) if i < parts.size() else 0.0))
		out.append({"tag": "note", "text": " · ".join(lines)})
		out.append({"tag": "note", "text": NOTE_TEXT})
	var pills := []
	var params: Array = item.get("params", [])
	for i in range(mini(8, params.size())):
		if float(params[i]) != 0.0:
			pills.append(XGearQuery.PARAMS[i] + " " + _num(float(params[i])))
	out.append({"tag": "pills", "pills": pills})
	var rec := XGearQuery.record(item)
	if rec.description != "":
		out.append({"tag": "note", "text": rec.description})
	for cat in XGearQuery.CATEGORIES:
		var rows: Array = rec.rows.filter(func(row): return row.categories[0] == cat)
		if rows.is_empty():
			continue
		out.append({"tag": "h3", "text": cat})
		rows.sort_custom(func(a, b):
			var c := XZhCollation.compare(a.key, b.key)
			if c != 0:
				return c < 0
			return float(a.number if a.number != null else 0.0) > float(b.number if b.number != null else 0.0))
		for row in rows:
			out.append({"tag": "effect", "text": row.text, "small": row.source + " · " + " / ".join(row.categories)})
	if rec.rows.is_empty():
		out.append({"tag": "empty", "text": "无附加词条。基础属性见上方。"})
	return out


static func _num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else str(v)


## 与参照相同的写法（测试用）：H2|… DIV|… H3|… DIV|词条|摘要
static func oracle_lines(blocks: Array) -> Array:
	return blocks.map(_oracle_line)


static func _oracle_line(b: Dictionary) -> String:
	match str(b.tag):
		"h2":
			return "H2|" + b.text
		"h3", "power":
			return "H3|" + b.text
		"pills":
			return "DIV|" + "".join(b.pills)
		"effect":
			return "DIV|" + b.text + "|" + b.small
	return "DIV|" + b.text


static func results(src: Array, f: Dictionary) -> Array:
	var scope := str(f.get("scope", "all"))
	var data := src.filter(func(r): return XGearQuery.matches(r.item, f) and (scope == "all" or (r.owner != "" if scope == "worn" else r.owner == "")))
	var keyed := []
	for i in range(data.size()):
		keyed.append([data[i], i])
	keyed.sort_custom(func(a, b):
		var c := XGearQuery.compare(a[0].item, b[0].item, f)
		return c < 0 if c != 0 else a[1] < b[1])
	return keyed.map(func(x): return x[0])


## 下拉选项 [[值, 文字]]
static func type_options(src: Array) -> Array:
	var out := [["", "全部装备"]]
	var seen := {}
	var sys := XDB.system()
	for r in src:
		var i: Dictionary = r.item
		var key := XGearQuery.type_key(i)
		if seen.has(key):
			continue
		seen[key] = true
		if str(i.get("kind", "")) == "weapon":
			var id := int(i.get("wtypeId", 0))
			var n := str(sys.weaponTypes[id]) if id >= 0 and id < sys.weaponTypes.size() else ""
			out.append([key, "武器 · " + (n if n != "" else str(id))])
		else:
			var id := int(i.get("etypeId", 0))
			var n := str(sys.equipTypes[id]) if id >= 0 and id < sys.equipTypes.size() else ""
			out.append([key, n if n != "" else "防具"])
	return out


static func quality_options() -> Array:
	var cfg := XQuality.config()
	var out := [["", "全部品质"]]
	for i in range(cfg.names.size()):
		out.append([str(i), str(cfg.names[i])])
	var legacy: Array = cfg.get("starMarks", {}).keys().map(func(k): return int(k))
	legacy.sort()
	for q in legacy:
		out.append(["L%d" % q, "%s：%s%s" % [cfg.names[XQuality.grade_of(q)], cfg.starMarks[str(q)], cfg.gearTags.get(str(q), "")]])
	return out


static func term_options(src: Array) -> Array:
	var terms := {}
	for r in src:
		for row in XGearQuery.record(r.item).rows:
			if not terms.has(row.key):
				terms[row.key] = XGearQuery._rx("[+\\-＋－]?\\d+(?:\\.\\d+)?").sub(row.text, "…", true)
	var keys := terms.keys()
	keys.sort_custom(func(a, b): return XZhCollation.compare(terms[a], terms[b]) < 0)
	return [["", "不限词条"]] + keys.map(func(k): return [k, terms[k]])


static func _has_number_term(src: Array, key: String) -> bool:
	return src.any(func(r): return XGearQuery.record(r.item).rows.any(func(row): return row.key == key and row.number != null))


static func sort_options(src: Array, f: Dictionary) -> Array:
	var out := []
	for k in ["original", "power", "quality", "count", "name"]:
		out.append([k, XGearQuery.SORT_NAMES[k]])
	for i in range(8):
		out.append(["param%d" % i, XGearQuery.PARAMS[i] + "数值高 → 低"])
	var t := str(f.term) if str(f.term) != "" else str(f.get("sortTerm", ""))
	if t != "" and _has_number_term(src, t):
		out.append(["term", XGearQuery.SORT_NAMES.term])
	return out


# ---- 面板 ----
static func open(parent: Control, src: Array) -> XGearSearch:
	if filter.is_empty():
		reset_session()
	var p := XGearSearch.new()
	p.source = src
	parent.add_child(p)
	return p


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_render_gear()


func _draw() -> void:
	draw_frame()


func _render_gear() -> void:
	for c in get_children():
		c.queue_free()
	var head := _fixed(_label("装备词条检索", 23, TEXT, true), 36.8)
	head.position = Vector2(CONTENT_X, 36)
	add_child(head)
	var sub := _fixed(_label("多个关键词用空格分开，将同时匹配；读取当前装备的真实效果。", 13, MUTED), 20.8)
	sub.position = Vector2(CONTENT_X, 72.8)
	add_child(sub)
	var close_b := _button("关闭 · Esc", close)
	add_child(close_b)
	_right_align(close_b, CONTENT_X + CONTENT_W, 44.2)
	# 搜索框
	_search = LineEdit.new()
	_search.placeholder_text = "搜索装备 / 词条，例如：暴击 掉宝"
	_search.text = str(filter.query)
	_search.add_theme_font_override("font", XUI.font())
	_search.add_theme_font_size_override("font_size", 17)
	_search.add_theme_color_override("font_color", TEXT)
	_search.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.5))
	_search.add_theme_stylebox_override("normal", _box(FIELD_BG, BUTTON_EDGE))
	var sf := _box(FIELD_BG, CURSOR_EDGE, 6, 2)
	_search.add_theme_stylebox_override("focus", sf)
	_search.position = Vector2(CONTENT_X, 116.6)
	_search.size = Vector2(CONTENT_W, 41.2)
	_search.text_changed.connect(_on_field.bind("query"))
	add_child(_search)
	# 下拉与按钮：间距 8 换行
	var items := []
	items.append(_select("分类", [["", "全部分类"]] + XGearQuery.CATEGORIES.map(func(c): return [c, c]), str(filter.category),
		_on_field.bind("category")))
	items.append(_select("部位", type_options(source), str(filter.type), _on_field.bind("type")))
	items.append(_select("品质", quality_options(), str(filter.quality), _on_field.bind("quality")))
	items.append(_select("位置", XGearQuery.SCOPES, str(filter.scope), _on_field.bind("scope")))
	items.append(_select("指定词条", term_options(source), str(filter.term), _on_term))
	var sort_field := _select("排序", sort_options(source, filter), str(filter.sort), _on_sort)
	_sort_select = sort_field.get_child(1)
	items.append(sort_field)
	items.append(_button("清空条件", _on_reset))
	var y := 165.8
	var x := CONTENT_X
	var row: Array = []
	var bottom := y
	for it in items:
		var c: Control = it
		if x > CONTENT_X and x + c.size.x > CONTENT_X + CONTENT_W:
			y = _place_row(row, y) + 8
			x = CONTENT_X
			row = []
		c.position.x = x
		row.append(c)
		add_child(c)
		x += c.size.x + 8
	bottom = _place_row(row, y)
	_count = _fixed(_label("", 13, MUTED), 20.8)
	_count.position = Vector2(CONTENT_X, bottom + 8)
	add_child(_count)
	# 结果与详情
	var body_y := bottom + 8 + 20.8 + 6
	var footer_y := PANEL.end.y - BORDER - PAD.y - 41.2
	var body_h := footer_y - 9 - body_y
	var list_w := floorf(CONTENT_W * 0.43)
	_list_scroll = _panel_scroll(Rect2(CONTENT_X, body_y, list_w, body_h), 5)
	_list_box = _list_scroll.get_child(0)
	_list_box.add_theme_constant_override("separation", 5)
	_detail_scroll = _panel_scroll(Rect2(CONTENT_X + list_w + 12, body_y, CONTENT_W - list_w - 12, body_h), 13)
	_detail_box = _detail_scroll.get_child(0)
	_detail_box.add_theme_constant_override("separation", 0)
	# 底部栏
	var note := _fixed(_label("详情按分类排列；数值排序读取装备当前属性，不改变装备。", 13, MUTED), 20.8)
	note.position = Vector2(CONTENT_X, footer_y + (41.2 - 20.8) / 2)
	add_child(note)
	var apply_b := _button("应用到装备列表", apply_filter)
	add_child(apply_b)
	_right_align(apply_b, CONTENT_X + CONTENT_W, footer_y)
	queue_redraw()
	_render_results()
	_search.grab_focus.call_deferred()


## 一行控件纵向居中（行高取最高者），返回行底
func _place_row(row: Array, y: float) -> float:
	var h := 0.0
	for c in row:
		h = maxf(h, c.size.y)
	for c in row:
		c.position.y = y + (h - c.size.y) / 2
	return y + h


## label.cq-field：标签 13 号系统色、间距 5、下拉 36 高，宽按最长项（最多 260）
func _select(label: String, values: Array, value: String, cb: Callable) -> Control:
	var box := Control.new()
	var l := _fixed(_label(label, 13, SYSTEM), 20.8)
	box.add_child(l)
	var s := OptionButton.new()
	s.add_theme_font_override("font", XUI.font())
	s.add_theme_font_size_override("font_size", 17)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		s.add_theme_color_override(k, TEXT)
	_outline(s)
	s.add_theme_stylebox_override("normal", _box(FIELD_BG, BUTTON_EDGE))
	s.add_theme_stylebox_override("hover", _box(CURSOR, CURSOR_EDGE))
	s.add_theme_stylebox_override("pressed", _box(CURSOR, CURSOR_EDGE))
	var focus := _box(Color(0, 0, 0, 0), CURSOR_EDGE, 7, 2, Vector2.ZERO)
	focus.set_expand_margin_all(3)
	s.add_theme_stylebox_override("focus", focus)
	s.clip_text = true
	s.fit_to_longest_item = false
	var widest := 0.0
	var font := XUI.font()
	for i in range(values.size()):
		var t := str(values[i][1])
		s.add_item(t.replace("\n", " "), i)
		s.set_item_metadata(i, str(values[i][0]))
		widest = maxf(widest, font.get_string_size(t.get_slice("\n", 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x)
		if str(values[i][0]) == value:
			s.select(i)
	if not values.any(func(v): return str(v[0]) == value):
		s.select(-1)
	var popup := s.get_popup()
	popup.add_theme_font_override("font", XUI.font())
	popup.add_theme_font_size_override("font_size", 17)
	popup.add_theme_stylebox_override("panel", _box(Color("#1e1f2a"), BUTTON_EDGE, 4, 1, Vector2(4, 4)))
	s.item_selected.connect(func(i): cb.call(str(s.get_item_metadata(i))))
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	s.size = Vector2(minf(260.0, ceilf(widest) + 42.0), 36)
	s.position = Vector2(ceilf(lw) + 5, 0)
	l.position = Vector2(0, (36 - 20.8) / 2)
	box.add_child(s)
	box.size = Vector2(s.position.x + s.size.x, 36)
	return box


func _on_field(v: String, key: String) -> void:
	filter[key] = v
	_render_results()


func _on_sort(v: String) -> void:
	XGearQuery.set_sort(filter, v, str(filter.term) if str(filter.term) != "" else str(filter.sortTerm))
	_render_results()


func _on_reset() -> void:
	filter = XGearQuery.default_view()
	selected_key = ""
	_render_gear()


func _on_term(v: String) -> void:
	filter.term = v
	if filter.sort == "term":
		XGearQuery.set_sort(filter, "term", v)
	if filter.sort == "term" and not _has_number_term(source, v):
		filter.sort = "quality"
	_render_gear()


func _render_results() -> void:
	_results = results(source, filter)
	_count.text = "找到 %d / %d 件装备" % [_results.size(), source.size()]
	if not _results.any(func(r): return r.key == selected_key):
		selected_key = _results[0].key if not _results.is_empty() else ""
	for c in _list_box.get_children():
		c.queue_free()
	for c in _detail_box.get_children():
		c.queue_free()
	if _results.is_empty():
		_list_box.add_child(_empty("没有匹配装备。清空部分条件后重试。"))
	for r in _results:
		_list_box.add_child(_row(r))
	var cur: Array = _results.filter(func(x): return x.key == selected_key)
	if cur.is_empty():
		return
	for b in detail_blocks(cur[0]):
		_detail_box.add_child(_block(b))


## 列表行（button.cq-row）：内边距 8/12、底边 1px；选中为光标色
func _row(r: Dictionary) -> Button:
	var b := Button.new()
	var active: bool = r.key == selected_key
	var normal := _box(CURSOR if active else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, Vector2(12, 8))
	normal.border_width_bottom = 1
	normal.border_color = CURSOR_EDGE if active else Color(1, 1, 1, 0.1)
	var hover := normal.duplicate()
	hover.bg_color = CURSOR
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("hover_pressed", hover)
	var focus := _box(Color(0, 0, 0, 0), CURSOR_EDGE, 0, 2, Vector2.ZERO)
	b.add_theme_stylebox_override("focus", focus)
	b.custom_minimum_size = Vector2(0, 63.4)
	var name := _fixed(_label(star_name(r.item), 17, TEXT), 27.2)
	name.position = Vector2(12, 8)
	name.clip_text = true
	var small := _fixed(_label(row_small(r), 12, MUTED), 19.2)
	small.position = Vector2(12, 8 + 27.2)
	small.clip_text = true
	b.add_child(name)
	b.add_child(small)
	b.resized.connect(_fit_row.bind(b, name, small))
	b.pressed.connect(_pick.bind(str(r.key)))
	return b


func _fit_row(b: Button, name: Label, small: Label) -> void:
	name.size.x = b.size.x - 24
	small.size.x = b.size.x - 24


func _pick(key: String) -> void:
	selected_key = key
	_render_results()


func _block(b: Dictionary) -> Control:
	match str(b.tag):
		"h2":
			return _para(b.text, 23, TEXT, 36.8, true)
		"meta", "note":
			return _para(b.text, 13, MUTED, 20.8)
		"h3", "power":
			return h3(b.text, GOLD if b.tag == "power" else SYSTEM)
		"pills":
			return pills(b.pills)
		"effect":
			return card([[b.text, 18, TEXT, 28.8], [b.small, 12, MUTED, 19.2]])
		_:
			return _empty(b.text)


## applyFilter：保存排序，把条件交给页面，关闭
func apply_filter() -> void:
	XGearQuery.set_sort(filter, str(filter.sort), str(filter.term) if str(filter.term) != "" else str(filter.sortTerm))
	applied.emit(filter.duplicate())
	close()
