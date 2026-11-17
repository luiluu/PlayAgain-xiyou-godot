class_name XSkinBossStatus
extends XBossStatusPanel
## 【cc·天启篇·未经审查】新界面 2B：首领状态胶囊＋详情（盘点清册 #68，界面风格提案 v0.7 样稿 battle 的 .bst）。
## 只换画法和摆法：哪只是首领（XBossStatus.is_boss）、跟着谁（选中的、上一个掉血的……）、条目内容和排序、点了展开／翻页／看条目，
## 全是 XBossStatusPanel 原来的逻辑；详情框的几何（480×400、页签行、每条 68 高、页脚）也照旧，所以点哪里做什么不变。
## - 折叠行：一排胶囊居中——（首领血弧没在画这只时先放一枚名字胶囊）最多 2 个状态（图标＋「名字 回合」，异常橙边橙字）、
##   多出来的「+N」、最后「详情 ▾」（旧金边、像按钮；小A文字审 #189 建议做成明显的按钮）。天启篇元素牌组（弱／抗／免疫）在下面一行小字。
## - 有血弧时贴在弧下（XSkinBossArc.arc_bottom()＋40），没有时在画面顶上 16。
## - 详情：黑面板、旧金标题、页签用红乙选中条，异常橙、增益绿（提升色）。

const ROW_H := 40.0
const PROFILE_H := 22.0
const CAP_GAP := 8.0
const CAP_FS := 16
const TOP_NO_ARC := 16.0
const PROFILE_COLOR := Color("9be4ff")

## 战斗里的首领血弧（XSkinBattle.boss_panel 设）；它在画同一只首领时胶囊排在弧下、不再放名字胶囊
var arc: XBossHpBar
var _caps: Array = []


func _ready() -> void:
	super._ready()
	bar.clip_contents = false


func arc_shows_boss() -> bool:
	return arc != null and is_instance_valid(arc) and arc.visible and arc.battler == battler and arc.layout_alpha > 0


static func turns_text(row: Dictionary) -> String:
	return spaced(str(row.get("turns", "")))


## 数字和单位之间空一格（小A文字审口径：「冷却 2 回合」）：「4回合」→「4 回合」、「3层」→「3 层」
static func spaced(t: String) -> String:
	if _re_unit == null:
		_re_unit = RegEx.create_from_string("(\\d)(回合|层)")
	return _re_unit.sub(t, "$1 $2", true)


static var _re_unit: RegEx


## 折叠行的胶囊：[{kind: name|state|more|detail, text, icon, w}]
func capsules() -> Array:
	if battler == null:
		return []
	var f := XUiSkin.font("body")
	var out := []
	if not arc_shows_boss():
		var nm := XBossStatus.clean(battler.display_name())
		var tf := XUiSkin.font("title")
		out.append({"kind": "name", "text": nm, "icon": 0, "w": tf.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 28.0})
	var all := XBossStatus.entries(battler)
	for i in range(mini(all.size(), 2)):
		var row: Dictionary = all[i]
		var t := str(row.name)
		var tt := turns_text(row)
		if tt != "":
			t += " " + tt
		t = XSkinOTBBar.fit(f, t, 190.0, CAP_FS)
		var has_icon := int(row.icon) > 0
		out.append({"kind": "state", "bad": row.kind == "Debuff", "text": t, "icon": int(row.icon),
			"w": f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, CAP_FS).x + (40.0 if has_icon else 28.0)})
	if all.size() > 2:
		var more := "+%d" % (all.size() - 2)
		out.append({"kind": "more", "text": more, "icon": 0, "w": f.get_string_size(more, HORIZONTAL_ALIGNMENT_LEFT, -1, CAP_FS).x + 24.0})
	var d := "收起 ▴" if open else "详情 ▾"
	out.append({"kind": "detail", "text": d, "icon": 0, "w": f.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, CAP_FS).x + 28.0})
	return out


func caps_width() -> float:
	var w := 0.0
	for c in _caps:
		w += float(c.w)
	return w + CAP_GAP * maxf(_caps.size() - 1, 0)


func refresh(force := false) -> void:
	_caps = capsules()
	super.refresh(force)


func _bar_height() -> float:
	return ROW_H + (PROFILE_H if not _tq_profile().is_empty() else 0.0)


func _layout() -> void:
	if _caps.is_empty() or (_caps[0].kind == "name") == arc_shows_boss():   # 弧出现／消失时名字胶囊跟着变
		_caps = capsules()
		bar.queue_redraw()
	var bh := _bar_height()
	var w := maxf(caps_width(), 160.0)
	var prof := _tq_profile()
	if not prof.is_empty():
		var line := _profile_line(prof)
		w = maxf(w, XUiSkin.font("body").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 8.0)
	var y := (XSkinBossArc.arc_bottom() + 40.0) if arc_shows_boss() else TOP_NO_ARC
	bar.size = Vector2(w, bh)
	bar.position = Vector2(roundf(BOX.x / 2.0 - w / 2.0), y)
	var help: Rect2 = help_source.call() if help_source.is_valid() else Rect2()
	var dx := roundf(BOX.x / 2.0 - DETAIL_W / 2.0)
	var dy := maxf(12.0, minf(y + bh + 8.0, BOX.y - DETAIL_H - 12.0))
	detail.position = Vector2(dx, dy)
	detail.visible = open and not (help.has_area() and Rect2(dx, dy, DETAIL_W, DETAIL_H).intersects(help))


func _profile_line(prof: Dictionary) -> String:
	var head := "[P%d] " % int(prof.phase) if str(prof.get("source", "")) == "knight" and int(prof.get("phase", 0)) > 0 else ""
	return head + XTianqiElements.format_profile_line(prof)


static func _txt(c: CanvasItem, f: Font, text: String, x: float, y: float, w: float, align: String, col: Color, fs: int, lh: float) -> void:
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var dx := x
	if align == "center":
		dx = x + (w - tw) / 2.0
	elif align == "right":
		dx = x + w - tw
	XUiSkin.ds(c, f, Vector2(dx, y + lh / 2.0 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


static func _capsule(ci: RID, r: Rect2, edge: Color, fill := Color(XUiSkin.BG, 0.88)) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(r.size.y / 2.0))
	sb.anti_aliasing = true
	sb.draw(ci, r)


func _paint_bar(c: XMVCanvas) -> void:
	if battler == null:
		return
	var ci := c.get_canvas_item()
	var f := XUiSkin.font("body")
	var x := 0.0
	for cap in _caps:
		var r := Rect2(x, 0, float(cap.w), ROW_H)
		match str(cap.kind):
			"name":
				_capsule(ci, r, Color(XUiSkin.GOLD, 0.6))
				_txt(c, XUiSkin.font("title"), str(cap.text), r.position.x, 0, r.size.x, "center", name_ink(str(cap.text)), 18, ROW_H)
			"state":
				var bad := bool(cap.bad)
				_capsule(ci, r, XUiSkin.DOWN if bad else Color(XUiSkin.LINE, 0.5))
				var tx := x + 14.0
				if int(cap.icon) > 0:
					var tex := XUiSkin.icon(int(cap.icon))
					if tex != null:
						c.draw_texture_rect(tex, Rect2(x + 7.0, 8.0, 24.0, 24.0), false)
					tx = x + 36.0
				_txt(c, f, str(cap.text), tx, 0, r.end.x - tx, "left", XUiSkin.DOWN if bad else XUiSkin.TEXT, CAP_FS, ROW_H)
			"more":
				_capsule(ci, r, Color(XUiSkin.LINE, 0.5))
				_txt(c, f, str(cap.text), r.position.x, 0, r.size.x, "center", XUiSkin.TEXT_2, CAP_FS, ROW_H)
			"detail":
				_capsule(ci, r, XUiSkin.GOLD, Color(XUiSkin.BG.lerp(XUiSkin.GOLD, 0.16), 0.92))
				_txt(c, f, str(cap.text), r.position.x, 0, r.size.x, "center", XUiSkin.GOLD, CAP_FS, ROW_H)
		x += float(cap.w) + CAP_GAP
	var prof := _tq_profile()
	if not prof.is_empty():
		var line := _profile_line(prof)
		_txt(c, f, line, 0, ROW_H, c.size.x, "center", PROFILE_COLOR, 14, PROFILE_H)


# ---- 详情（几何同 XBossStatusPanel，点击照旧） ----
func _paint_detail(c: XMVCanvas) -> void:
	if battler == null:
		return
	var ci := c.get_canvas_item()
	var w := DETAIL_W
	var f := XUiSkin.font("body")
	var all := XBossStatus.entries(battler)
	var bad := all.filter(func(r): return r.kind == "Debuff").size()
	var good := all.filter(func(r): return r.kind == "Buff").size()
	XUiSkin.draw_panel(ci, Rect2(0, 0, w, DETAIL_H))
	var title_w := maxf(80.0, w - 256.0)
	var tf := XUiSkin.font("title")
	var title := XSkinOTBBar.fit(tf, XBossStatus.clean(battler.display_name()), title_w, 20)
	_txt(c, tf, title, 16, 6, title_w, "left", name_ink(title), 20, 30)
	_attr_line(c, w - 231.0, 7.0, 178.0, 28.0)
	_txt(c, f, "×", w - 42.0, 6, 27, "center", XUiSkin.TEXT_2, 22, 30)
	var tabs := [["Debuff", "异常 %d" % bad, XUiSkin.DOWN], ["Buff", "增益 %d" % good, XUiSkin.UP], ["All", "全部 %d" % all.size(), XUiSkin.GOLD]]
	var tw := (w - 24.0) / 3.0
	for i in 3:
		var x := 12.0 + i * tw
		var on: bool = filter == tabs[i][0]
		if on:
			XUiSkin.draw_select(ci, Rect2(x, 43, tw - 4.0, 28))
		_txt(c, f, tabs[i][1], x, 43, tw - 4.0, "center", tabs[i][2] if on else XUiSkin.TEXT_2, 15, 28)
	var list := rows()
	var picked = null
	for r in list:
		if selected != null and str(r.id) == str(selected):
			picked = r
	if picked != null:
		_paint_selected(c, picked)
		return
	if list.is_empty():
		var tip := "当前没有异常状态" if filter == "Debuff" else ("当前没有增益状态" if filter == "Buff" else "当前没有状态")
		_txt(c, f, tip, 16, BODY_Y + 28.0, w - 32.0, "center", XUiSkin.TEXT_3, 16, 28)
	var start := page * page_size()
	for i in page_size():
		if start + i >= list.size():
			break
		var row: Dictionary = list[start + i]
		var y := BODY_Y + i * CARD_HEIGHT
		var col := XUiSkin.DOWN if row.kind == "Debuff" else XUiSkin.UP
		_round(c, Rect2(12, y, w - 24.0, CARD_HEIGHT - 6.0), Color(1, 1, 1, 0.04), XUiSkin.ROW_RADIUS)
		c.draw_rect(Rect2(12, y + 8.0, 2, CARD_HEIGHT - 22.0), col)
		if row.icon != 0:
			var tex := XUiSkin.icon(int(row.icon))
			if tex != null:
				c.draw_texture_rect(tex, Rect2(22, y + 9.0, 27, 27), false)
		var x := 58.0 if row.icon != 0 else 24.0
		_txt(c, f, XSkinOTBBar.fit(f, str(row.name), w - x - 122.0, 17), x, y + 2.0, w - x - 122.0, "left", XUiSkin.TEXT, 17, 26)
		_txt(c, f, XSkinOTBBar.fit(f, spaced(_meta(row)), 110.0, 14), w - 125.0, y + 2.0, 109, "right", col, 14, 26)
		_txt(c, f, XSkinOTBBar.fit(f, str(row.description).replace("\n", " "), w - 48.0, 14), 24, y + 29.0, w - 48.0, "left", XUiSkin.TEXT_2, 14, 25)
	_footer(c, page, maxi(1, ceili(list.size() / float(page_size()))), "")


## 标题右边的元素行：天启篇元素牌组照旧（XTianqiElements）；其余是「敌人属性：」＋元素名（同 XBossStatusPanel._attributes 取数，换皮肤字）
func _attr_line(c: XMVCanvas, x: float, y: float, width: float, height: float) -> void:
	var f := XUiSkin.font("body")
	var prof := _tq_profile()
	if not prof.is_empty():
		_txt(c, f, XSkinOTBBar.fit(f, _profile_line(prof), width, 14), x, y, width, "left", PROFILE_COLOR, 14, height)
		return
	var names: Array = XDamage.elements_data().get("names", [])
	var parts := [["敌人属性：", XUiSkin.TEXT_2]]
	var ids := XDamage.affinity(battler)
	if ids.is_empty():
		parts.append(["无属性", Color(XPowerStrip.ELEMENT_COLORS[0])])
	for i in ids.size():
		if i > 0:
			parts.append(["／", XUiSkin.TEXT_2])
		var e: int = ids[i]
		parts.append([str(names[e]) if e < names.size() else "无属性", Color(XPowerStrip.ELEMENT_COLORS[e] if e < XPowerStrip.ELEMENT_COLORS.size() else XPowerStrip.ELEMENT_COLORS[0])])
	var total := 0.0
	for p in parts:
		total += f.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var fs := 14 if total <= width else maxi(int(roundf(14.0 * width / total)), 9)
	for p in parts:
		var pw := f.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_txt(c, f, p[0], x, y, pw + 1.0, "left", p[1], fs, height)
		x += pw


func _paint_selected(c: XMVCanvas, row: Dictionary) -> void:
	var w := DETAIL_W
	var f := XUiSkin.font("body")
	var col := XUiSkin.DOWN if row.kind == "Debuff" else XUiSkin.UP
	_round(c, Rect2(12, BODY_Y, w - 24.0, 58), Color(1, 1, 1, 0.06), XUiSkin.ROW_RADIUS)
	if row.icon != 0:
		var tex := XUiSkin.icon(int(row.icon))
		if tex != null:
			c.draw_texture_rect(tex, Rect2(22, BODY_Y + 12.0, 30, 30), false)
	var x := 63.0 if row.icon != 0 else 23.0
	var tf := XUiSkin.font("title")
	var names := wrap_lines(tf, str(row.name), w - x - 20.0, 19)
	for i in mini(names.size(), 2):
		_txt(c, tf, names[i], x, BODY_Y + 3.0 + i * 24.0, w - x - 20.0, "left", XUiSkin.TEXT, 19, 25)
	_txt(c, f, spaced(_meta(row)), 23, BODY_Y + 62.0, w - 46.0, "left", col, 14, 22)
	var lines := wrap_lines(f, str(row.description), w - 44.0, 16)
	var start := BODY_Y + 94.0
	var per := maxi(1, floori((DETAIL_H - FOOTER_HEIGHT - start - 8.0) / 24.0))
	var pages := maxi(1, ceili(lines.size() / float(per)))
	description_page = clampi(description_page, 0, pages - 1)
	for i in per:
		var at := description_page * per + i
		if at >= lines.size():
			break
		_txt(c, f, lines[at], 22, start + i * 24.0, w - 44.0, "left", XUiSkin.TEXT, 16, 24)
	_footer(c, description_page, pages, "返回列表")


func _footer(c: XMVCanvas, at: int, pages: int, middle: String) -> void:
	var w := DETAIL_W
	var f := XUiSkin.font("body")
	var y := DETAIL_H - FOOTER_HEIGHT
	c.draw_rect(Rect2(13, y, w - 26.0, 1), Color(XUiSkin.LINE, 0.3))
	_txt(c, f, "‹ 上一页", 15, y + 3.0, 82, "left", XUiSkin.GOLD if at > 0 else XUiSkin.TEXT_3, 14, 28)
	_txt(c, f, ("%s  " % middle if middle != "" else "") + "%d / %d" % [at + 1, pages], 98, y + 3.0, w - 196.0, "center", XUiSkin.TEXT_2, 14, 28)
	_txt(c, f, "下一页 ›", w - 97.0, y + 3.0, 82, "right", XUiSkin.GOLD if at < pages - 1 else XUiSkin.TEXT_3, 14, 28)


static func wrap_lines(f: Font, text: String, width: float, fs: int) -> Array:
	var lines := []
	var line := ""
	for ch in text:
		if ch == "\n":
			lines.append(line)
			line = ""
			continue
		if line != "" and f.get_string_size(line + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			lines.append(line)
			line = ""
		line += ch
	if line != "":
		lines.append(line)
	return lines
