class_name XBossStatusPanel
extends Control
## Boss 状态面板（Codex_BossStatusSummary v0.4.0，installGamePanelTheme 的 drawFrame）。只显示，不参与结算。
## - 只在有活着且已现身的 Boss 时出现。折叠栏 440×96，点它展开或收起；详情 480×400，异常／增益／全部三个标签，
##   点条目看完整说明，页脚翻页、回列表，× 或 Esc 关；点到面板的点击不会穿给战斗。
## - 位置（原版夹具读数）：折叠栏 (105,131.5)，紧贴原版 Boss 血条下方（血条框 (105,45.5) 高 78，再隔 8）；详情在折叠栏下 6 格，
##   画面底部留 12 格。说明卡挡住折叠栏时折叠栏上移，挡住详情时详情藏起。
## - 多个 Boss：选目标时选中的、上一个掉血的、之前显示的、第一个。原版「上一个被打的」连没掉血的命中也算，这里只看掉血。
## - 和原版的差别：没有「战力」（Kyo 定不做敌人战力，折叠栏与详情都不画）；详情标题右边的「敌人属性」照做。

const BAR_HEIGHT := 96.0
const CARD_HEIGHT := 68.0
const BODY_Y := 82.0
const FOOTER_HEIGHT := 34.0
const WIDTH := 440.0
const DETAIL_W := 480.0
const DETAIL_H := 400.0
const BOX := Vector2(1280, 720)
const BAR_X := 105.0
const BAR_Y := 131.5
const INK := Color("#ffffff")
const MUTED := Color("#c9ced8")
const EDGE := Color(1, 1, 1, 0.28)
const BLUE := Color("#84aaff")
const BAD := Color("#ff8f86")
const GOOD := Color("#98e598")
const DIM := Color(1, 1, 1, 0.3)
const FRAME_BACK := Color8(24, 24, 34, 230)

var enemies_source: Callable  # -> Array：本场敌人
var target_source: Callable  # -> 选目标时选中的战斗者，没在选为空
var help_source: Callable  # -> Rect2：正在显示的说明卡，没有时大小为 0
var battler = null
var open := false
var page := 0
var selected = null
var filter := "Debuff"
var description_page := 0
var bar: XMVCanvas
var detail: XMVCanvas
var _last_hit = null
var _hp := {}
var _stamp := ""
var _frame := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = BOX
	z_index = 11  # 原版是场景最后一个子节点，盖在说明卡（z 10）上
	bar = _canvas(Vector2(WIDTH, BAR_HEIGHT), _paint_bar, _on_bar_input)
	detail = _canvas(Vector2(DETAIL_W, DETAIL_H), _paint_detail, _on_detail_input)
	detail.visible = false
	visible = false


func _canvas(s: Vector2, painter: Callable, input: Callable) -> XMVCanvas:
	var c := XMVCanvas.new()
	c.size = s
	c.painter = painter
	c.clip_contents = false
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.gui_input.connect(input)
	add_child(c)
	return c


func bosses() -> Array:
	return enemies_source.call().filter(XBossStatus.is_boss) if enemies_source.is_valid() else []


## locateBoss
func locate():
	var list := bosses()
	_track_hits(list)
	if list.is_empty():
		return null
	var target = target_source.call() if target_source.is_valid() else null
	for b in [target, _last_hit, battler]:
		if list.has(b):
			return b
	return list[0]


func _track_hits(list: Array) -> void:
	for b in list:
		var id := b.get_instance_id()
		if _hp.has(id) and b.hp < _hp[id]:
			_last_hit = b
		_hp[id] = b.hp


func page_size() -> int:
	return maxi(1, floori((DETAIL_H - BODY_Y - FOOTER_HEIGHT) / CARD_HEIGHT))


func rows() -> Array:
	return XBossStatus.entries(battler).filter(func(r): return filter == "All" or r.kind == filter)


func _process(_delta: float) -> void:
	_frame += 1
	var found = locate()
	var changed: bool = found != battler
	battler = found
	visible = battler != null
	if battler == null:
		open = false
		selected = null
		detail.visible = false
		return
	if changed:
		page = 0
		open = false
		filter = "Debuff"
		selected = null
		description_page = 0
	if changed or _frame % 8 == 0:
		refresh(changed)
	_layout()


func _layout() -> void:
	var help: Rect2 = help_source.call() if help_source.is_valid() else Rect2()
	var y := BAR_Y
	var bar_rect := Rect2(BAR_X, y, WIDTH, BAR_HEIGHT)
	if help.has_area() and bar_rect.intersects(help):
		y = maxf(12.0, minf(y, help.position.y - BAR_HEIGHT - 8.0))
	bar.position = Vector2(BAR_X, y)
	var dx := maxf(12.0, minf(BAR_X, BOX.x - DETAIL_W - 12.0))
	var dy := maxf(12.0, minf(y + BAR_HEIGHT + 6.0, BOX.y - DETAIL_H - 12.0))
	detail.position = Vector2(dx, dy)
	detail.visible = open and not (help.has_area() and Rect2(dx, dy, DETAIL_W, DETAIL_H).intersects(help))


func refresh(force := false) -> void:
	var list := rows()
	var pages := maxi(1, ceili(list.size() / float(page_size())))
	page = clampi(page, 0, pages - 1)
	if selected != null and not list.any(func(r): return str(r.id) == str(selected)):
		selected = null
	var stamp := JSON.stringify([XBossStatus.clean(battler.display_name()) if battler else "", XBossStatus.entries(battler), page, filter, open, selected, description_page])
	if not force and stamp == _stamp:
		return
	_stamp = stamp
	bar.queue_redraw()
	detail.queue_redraw()


# ---- 输入 ----
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_ESCAPE and visible and open:
		open = false
		detail.visible = false
		refresh(true)
		get_viewport().set_input_as_handled()


func _on_bar_input(event: InputEvent) -> void:
	if _left_press(event):
		bar.accept_event()
		click_bar()


func _on_detail_input(event: InputEvent) -> void:
	if _left_press(event):
		detail.accept_event()
		click_detail(event.position)


func _left_press(event: InputEvent) -> bool:
	var m := event as InputEventMouseButton
	return m != null and m.pressed and m.button_index == MOUSE_BUTTON_LEFT


func click_bar() -> void:
	open = not open
	refresh(true)
	_layout()


func click_detail(p: Vector2) -> void:
	var x := p.x
	var y := p.y
	var w := DETAIL_W
	if y < 37.0 and x > w - 48.0:
		open = false
		refresh(true)
		_layout()
		return
	if y >= 43.0 and y < 73.0:
		filter = ["Debuff", "Buff", "All"][clampi(floori((x - 12.0) / ((w - 24.0) / 3.0)), 0, 2)]
		selected = null
		page = 0
		refresh(true)
		return
	if y >= DETAIL_H - FOOTER_HEIGHT:
		if selected != null:
			if x >= w * 0.3 and x <= w * 0.7:
				selected = null
			else:
				description_page += -1 if x < w * 0.3 else 1
		else:
			page += -1 if x < w * 0.3 else (1 if x > w * 0.7 else 0)
		refresh(true)
		return
	var item := floori((y - BODY_Y) / CARD_HEIGHT)
	var list := rows()
	var at := page * page_size() + item
	if selected == null and y >= BODY_Y and item >= 0 and item < page_size() and at < list.size():
		selected = list[at].id
		description_page = 0
		refresh(true)


# ---- 绘制 ----
static func _round(c: XMVCanvas, r: Rect2, color: Color, radius := 8) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	c.draw_style_box(s, r)


## CodexGamePanels.drawFrame：深灰半透明底＋Window 皮肤边框压成细框
static func _frame_box(c: XMVCanvas, w: float, h: float, compact: bool) -> void:
	c.draw_rect(Rect2(2, 2, w - 4, h - 4), FRAME_BACK)
	var skin := XUI.skin()
	if skin == null:
		return
	var corner := 10.0 if compact else 14.0
	for ix in 3:
		for iy in 3:
			if ix == 1 and iy == 1:
				continue
			var sx: float = 96.0 + [0.0, 24.0, 72.0][ix]
			var sy: float = [0.0, 24.0, 72.0][iy]
			var dx: float = [0.0, corner, w - corner][ix]
			var dy: float = [0.0, corner, h - corner][iy]
			var dw: float = w - corner * 2.0 if ix == 1 else corner
			var dh: float = h - corner * 2.0 if iy == 1 else corner
			c.draw_texture_rect_region(skin, Rect2(dx, dy, dw, dh), Rect2(sx, sy, 48.0 if ix == 1 else 24.0, 48.0 if iy == 1 else 24.0))


static func fit(c: XMVCanvas, text: String, width: float, size: int) -> String:
	if c.text_width(text, size) <= width:
		return text
	while text != "" and c.text_width(text + "…", size) > width:
		text = text.left(-1)
	return text + "…"


static func wrap(c: XMVCanvas, text: String, width: float, size: int) -> Array:
	var lines := []
	var line := ""
	for ch in text:
		if ch == "\n":
			lines.append(line)
			line = ""
			continue
		if line != "" and c.text_width(line + ch, size) > width:
			lines.append(line)
			line = ""
		line += ch
	if line != "":
		lines.append(line)
	return lines


static func _meta(row: Dictionary) -> String:
	return " · ".join([row.stack, row.turns].filter(func(s): return s != ""))


func _paint_bar(c: XMVCanvas) -> void:
	if battler == null:
		return
	var all := XBossStatus.entries(battler)
	_frame_box(c, WIDTH, BAR_HEIGHT, true)
	c.text("BOSS", 12, 3, 44, "left", BLUE, 14, 24)
	var name_text := XBossStatus.clean(battler.display_name())
	c.text(fit(c, name_text, WIDTH - 148.0, 14), 63, 3, WIDTH - 148.0, "left", INK, 14, 24)
	c.text("收起 ▴" if open else "详情 ▾", WIDTH - 76.0, 3, 62, "right", BLUE, 13, 24)
	c.draw_rect(Rect2(12, 28, WIDTH - 24.0, 1), EDGE)
	_preview(c, all.filter(func(r): return r.kind == "Debuff"), "Debuff", 32.0)
	_preview(c, all.filter(func(r): return r.kind == "Buff"), "Buff", 64.0)


func _preview(c: XMVCanvas, list: Array, kind: String, y: float) -> void:
	var color := BAD if kind == "Debuff" else GOOD
	var label := "异常" if kind == "Debuff" else "增益"
	c.text("%s %d" % [label, list.size()], 12, y + 3, 58, "left", color, 14, 26)
	if list.is_empty():
		c.text("无", 78, y + 3, WIDTH - 90.0, "left", MUTED, 14, 26)
		return
	var count := mini(list.size(), 2)
	var more := list.size() - count
	var area := WIDTH - 82.0 - (34.0 if more > 0 else 0.0)
	var cw := floorf(area / count)
	for i in count:
		var x := 76.0 + i * cw
		var row: Dictionary = list[i]
		var has_icon: bool = row.icon != 0
		var name_x := x + (28.0 if has_icon else 7.0)
		var text_w := cw - (36.0 if has_icon else 15.0)
		_round(c, Rect2(x, y, cw - 5.0, 29), Color(1, 1, 1, 0.07), 5)
		if has_icon:
			c.icon(row.icon, x + 4.0, y + 3.0, 1.0, 23.0)
		c.text(fit(c, row.name, text_w, 13), name_x, y - 2.0, text_w, "left", INK, 13, 19)
		c.text(fit(c, _meta(row), text_w, 11), name_x, y + 13.0, text_w, "left", color, 11, 15)
	if more > 0:
		c.text("+%d" % more, WIDTH - 37.0, y + 3.0, 28, "right", color, 13, 24)


func _paint_detail(c: XMVCanvas) -> void:
	if battler == null:
		return
	var w := DETAIL_W
	var all := XBossStatus.entries(battler)
	var bad := all.filter(func(r): return r.kind == "Debuff").size()
	var good := all.filter(func(r): return r.kind == "Buff").size()
	_frame_box(c, w, DETAIL_H, false)
	var title_w := maxf(80.0, w - 256.0)
	c.text(fit(c, XBossStatus.clean(battler.display_name()), title_w, 18), 16, 7, title_w, "left", INK, 18, 28)
	_attributes(c, w - 231.0, 7.0, 178.0, 28.0)
	c.text("×", w - 42.0, 7, 27, "center", BLUE, 17, 28)
	var tabs := [["Debuff", "异常 %d" % bad, BAD], ["Buff", "增益 %d" % good, GOOD], ["All", "全部 %d" % all.size(), BLUE]]
	var tw := (w - 24.0) / 3.0
	for i in 3:
		var x := 12.0 + i * tw
		var on: bool = filter == tabs[i][0]
		if on:
			_round(c, Rect2(x, 43, tw - 4.0, 28), Color(160 / 255.0, 230 / 255.0, 235 / 255.0, 0.25), 5)
		c.text(tabs[i][1], x, 43, tw - 4.0, "center", tabs[i][2] if on else MUTED, 14, 28)
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
		c.text(tip, 16, BODY_Y + 28.0, w - 32.0, "center", MUTED, 16, 28)
	var start := page * page_size()
	for i in page_size():
		if start + i >= list.size():
			break
		var row: Dictionary = list[start + i]
		var y := BODY_Y + i * CARD_HEIGHT
		var color := BAD if row.kind == "Debuff" else GOOD
		_round(c, Rect2(12, y, w - 24.0, CARD_HEIGHT - 6.0), Color(1, 1, 1, 0.05), 7)
		c.draw_rect(Rect2(12, y + 8.0, 2, CARD_HEIGHT - 22.0), color)
		if row.icon != 0:
			c.icon(row.icon, 22, y + 9.0, 1.0, 27.0)
		var x := 58.0 if row.icon != 0 else 24.0
		c.text(fit(c, row.name, w - x - 122.0, 16), x, y + 2.0, w - x - 122.0, "left", INK, 16, 26)
		c.text(fit(c, _meta(row), 110.0, 12), w - 125.0, y + 2.0, 109, "right", color, 12, 22)
		c.text(fit(c, str(row.description).replace("\n", " "), w - 48.0, 14), 24, y + 29.0, w - 48.0, "left", MUTED, 14, 25)
	_footer(c, page, maxi(1, ceili(list.size() / float(page_size()))), "")


## CodexElements.drawAttributes：「敌人属性：」＋元素名，总宽超出时字号按比例缩
func _attributes(c: XMVCanvas, x: float, y: float, width: float, height: float) -> void:
	var names: Array = XDamage.elements_data().get("names", [])
	var parts := [["敌人属性：", INK]]
	var ids := XDamage.affinity(battler)
	if ids.is_empty():
		parts.append(["无属性", Color(XPowerStrip.ELEMENT_COLORS[0])])
	for i in ids.size():
		if i > 0:
			parts.append(["／", INK])
		var e: int = ids[i]
		parts.append([str(names[e]) if e < names.size() else "无属性", Color(XPowerStrip.ELEMENT_COLORS[e] if e < XPowerStrip.ELEMENT_COLORS.size() else XPowerStrip.ELEMENT_COLORS[0])])
	var total := 0.0
	for p in parts:
		total += c.text_width(p[0], 14)
	var fs := 14 if total <= width else int(roundf(14.0 * width / total))
	for p in parts:
		var pw := c.text_width(p[0], fs)
		c.text(p[0], x, y, pw + 1.0, "left", p[1], fs, height)
		x += pw


func _paint_selected(c: XMVCanvas, row: Dictionary) -> void:
	var w := DETAIL_W
	var color := BAD if row.kind == "Debuff" else GOOD
	_round(c, Rect2(12, BODY_Y, w - 24.0, 58), Color(1, 1, 1, 0.07), 7)
	if row.icon != 0:
		c.icon(row.icon, 22, BODY_Y + 12.0, 1.0, 30.0)
	var x := 63.0 if row.icon != 0 else 23.0
	var names := wrap(c, row.name, w - x - 20.0, 18)
	for i in mini(names.size(), 2):
		c.text(names[i], x, BODY_Y + 3.0 + i * 22.0, w - x - 20.0, "left", INK, 18, 23)
	c.text(_meta(row), 23, BODY_Y + 62.0, w - 46.0, "left", color, 13, 22)
	var lines := wrap(c, str(row.description), w - 44.0, 16)
	var start := BODY_Y + 94.0
	var per := maxi(1, floori((DETAIL_H - FOOTER_HEIGHT - start - 8.0) / 24.0))
	var pages := maxi(1, ceili(lines.size() / float(per)))
	description_page = clampi(description_page, 0, pages - 1)
	for i in per:
		var at := description_page * per + i
		if at >= lines.size():
			break
		c.text(lines[at], 22, start + i * 24.0, w - 44.0, "left", INK, 16, 24)
	_footer(c, description_page, pages, "返回列表")


func _footer(c: XMVCanvas, at: int, pages: int, middle: String) -> void:
	var w := DETAIL_W
	var y := DETAIL_H - FOOTER_HEIGHT
	c.draw_rect(Rect2(13, y, w - 26.0, 1), EDGE)
	c.text("‹ 上一页", 15, y + 3.0, 82, "left", BLUE if at > 0 else DIM, 13, 28)
	c.text(("%s  " % middle if middle != "" else "") + "%d / %d" % [at + 1, pages], 98, y + 3.0, w - 196.0, "center", MUTED, 13, 28)
	c.text("下一页 ›", w - 97.0, y + 3.0, 82, "right", BLUE if at < pages - 1 else DIM, 13, 28)
