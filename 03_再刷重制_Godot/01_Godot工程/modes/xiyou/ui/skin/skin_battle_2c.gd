class_name XSkin2C
extends RefCounted
## 【cc·天启篇·未经审查】新界面 2C（v0.7 实装清单第 2 期）：胜利结算、全灭画面、战斗本线计量条、伤害统计、连击、掉落图标换新皮。
## 只换画法：奖励发放、经验动画节奏、升级音效、关页时机、计数规则、掉落弹跳轨迹与随机数、全灭淡入淡出与回标题全照旧。
## 只在 XUiSkin.on()（天启篇存档且设置「界面风格」选新）时走新画法；西游存档、开关关着时六个文件的旧画法一行不变。
## 回退：ENABLED＝false 全部回旧画法；各页单独的开关见下。
##
## 胜利结算、全灭没有设计图（v0.7 只列了名），各出两版让 Kyo 选（VICTORY_STYLE／GAMEOVER_STYLE，默认 A 版）：
## - 胜利 A「左右两栏」：沿用原版的位置关系（左：奖励＋队员经验，右：获得物品列表），换成黑面板、旧金标题、品质色名字。
## - 胜利 B「居中一张牌」：一列居中，队员压成一行一人，获得物品改成图标格（每行 12 格，超出的收进「＋N」格）。
## - 全灭 A：保留 Kyo 11-08 定的「NULL」字图，四周压暗＋底部一行提示。
## - 全灭 B：整页换成新皮肤的黑底：裂纹、宋体「NULL」朱红外晕、下面一行小字，图换掉（要 Kyo 点头才可默认，见交付单）。
## 计量条照 v0.7 样稿 battle（左上「战争线　火花 3 / 10」＋细金条），摆在自动／变速两颗圆钮下面。

static var ENABLED := true
static var VICTORY := true
static var GAMEOVER := true
static var METER := true
static var RECORD := true
static var COMBO := true
static var DROPS := true

enum Style { A, B }
static var VICTORY_STYLE := Style.A
static var GAMEOVER_STYLE := Style.A

const LINE_NAMES := {"war": "战争线", "death": "死亡线", "famine": "饥荒线", "plague": "瘟疫线"}


static func on() -> bool:
	return ENABLED and XUiSkin.on()


static func victory_on() -> bool:
	return VICTORY and on()


static func gameover_on() -> bool:
	return GAMEOVER and on()


static func meter_on() -> bool:
	return METER and on()


static func record_on() -> bool:
	return RECORD and on()


static func combo_on() -> bool:
	return COMBO and on()


static func drops_on() -> bool:
	return DROPS and on()


## ---- 公用画法 ----

static func _f(kind := "body") -> Font:
	return XUiSkin.font(kind)


static func _text(ci: CanvasItem, pos: Vector2, s: String, fs: int, color: Color, kind := "body", align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	XUiSkin.ds(ci, _f(kind), pos, s, align, width, fs, color)


static func _tw(s: String, fs: int, kind := "body") -> float:
	return _f(kind).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


static func _round_rect(ci: CanvasItem, r: Rect2, fill: Color, border := Color(0, 0, 0, 0), radius := -1) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(r.size.y / 2.0) if radius < 0 else radius)
	if border.a > 0.0:
		sb.set_border_width_all(1)
		sb.border_color = border
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


## 细量条：底槽＋渐变填充（左 c1 → 右 c2），圆头
static func _bar(ci: CanvasItem, r: Rect2, k: float, c1: Color, c2: Color) -> void:
	_round_rect(ci, r, Color(1, 1, 1, 0.08))
	k = clampf(k, 0.0, 1.0)
	if k <= 0.0:
		return
	var w := maxf(r.size.y, r.size.x * k)
	var fr := Rect2(r.position, Vector2(w, r.size.y))
	var sb := StyleBoxFlat.new()
	sb.bg_color = c1.lerp(c2, k)
	sb.set_corner_radius_all(int(r.size.y / 2.0))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, fr)


## 旧金分隔线：中间一颗菱形（标题下）
static func _divider(ci: CanvasItem, x0: float, x1: float, y: float, a := 1.0) -> void:
	ci.draw_line(Vector2(x0, y), Vector2(x1, y), Color(XUiSkin.GOLD, 0.45 * a), 1.0)
	var c := Vector2(x0 + 10.0, y)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4), c + Vector2(-4, 0)]), Color(XUiSkin.GOLD, 0.9 * a))


static func _panel(ci: CanvasItem, r: Rect2, a := 1.0) -> void:
	XUiSkin.draw_panel(ci.get_canvas_item(), r, a * 30.0 / 255.0 if a < 1.0 else 1.0)


## ==== 胜利结算 ====

## 胜利页开着新皮肤时：整屏压暗（盖住战斗画面，宽屏两边也盖），旧的提示窗不用（提示画在页内）
static func victory_setup(v: XVictoryScreen) -> void:
	var dim := ColorRect.new()
	dim.name = "Skin2CDim"
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(XUiSkin.BG, 0.80)
	v.add_child(dim)
	v.move_child(dim, 0)
	v.canvas.painter = func(c): paint_victory(v, c)


## 每屏能看到几项（滚动用）：A 是 11 行，B 是两行图标格（12×2，满了最后一格写「＋N」）
const B_COLS := 12
static func drop_page(v: XVictoryScreen) -> int:
	return B_COLS * 2 if VICTORY_STYLE == Style.B else 11


## 滚动上限：A 一次一行；B 一次一整行（12 项）
static func drop_scroll_max(v: XVictoryScreen) -> int:
	if VICTORY_STYLE == Style.B:
		return maxi(0, ceili(v._drops.size() / float(B_COLS)) - 2)
	return maxi(0, v._drops.size() - 11)


static func drop_rec(d: Dictionary) -> Dictionary:
	return XDB.rec({1: "Items", 2: "Weapons", 3: "Armors"}[int(d.kind)], int(d.id))


static func paint_victory(v: XVictoryScreen, c: XMVCanvas) -> void:
	if VICTORY_STYLE == Style.B:
		_victory_b(v, c)
	else:
		_victory_a(v, c)
	_victory_hint(v, c)


static func _title(c: CanvasItem, x: float, y: float, center := false) -> void:
	var s := "战斗胜利"
	var fs := 40
	var w := _tw(s, fs, "title")
	var px := x - w / 2.0 if center else x
	c.draw_texture_rect(XUiSkin.glow_texture(), Rect2(px - 40, y - 62, w + 80, 84), false, Color(XUiSkin.GOLD, 0.16))
	c.draw_string_outline(_f("title"), Vector2(px, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7))
	_text(c, Vector2(px, y), s, fs, XUiSkin.GOLD, "title")


## 金钱、经验两枚胶囊：小字名＋淡金大数
static func _rewards(v: XVictoryScreen, c: CanvasItem, x: float, y: float, w: float) -> void:
	var items := [[str(XDB.system().currencyUnit), int(v.rewards.get("gold", 0))], [str(XDB.system().terms.basic[8]), int(v.rewards.get("exp", 0))]]
	var gap := 12.0
	var cw := (w - gap) / 2.0
	for i in 2:
		var r := Rect2(x + i * (cw + gap), y, cw, 44)
		XSkin4A.draw_capsule(c, r)
		_text(c, Vector2(r.position.x + 22, y + 28), str(items[i][0]), 16, XUiSkin.TEXT_2)
		_text(c, Vector2(r.position.x, y + 31), XMenu._group(int(items[i][1])), 26, XUiSkin.GOLD_LIGHT, "num", HORIZONTAL_ALIGNMENT_RIGHT, cw - 22)


## 经验数字：「当前 / 下一级」（满级写「已满级」）
static func _exp_text(row: Dictionary) -> String:
	var a: XActor = row.actor
	var lv := int(row.display_level)
	if lv >= a.max_level():
		return "已满级"
	var base := a.exp_for_level(lv)
	return "%s / %s" % [XMenu._group(int(row.exp) - base), XMenu._group(a.exp_for_level(lv + 1) - base)]


## 「等级提升！」：同旧页的放大和闪烁（lv_scale、lv_opacity 照旧逐帧推进），换成淡金字＋外晕
static func _level_up(c: CanvasItem, row: Dictionary, center: Vector2) -> void:
	if not row.notified or float(row.lv_scale) <= 0.0:
		return
	var a := float(row.lv_opacity) / 255.0
	var k := float(row.lv_scale)
	var s := "等级提升！"
	var fs := 26
	var w := _tw(s, fs, "title")
	c.draw_set_transform(center, 0.0, Vector2(k, k))
	c.draw_texture_rect(XUiSkin.glow_texture(), Rect2(-w / 2.0 - 30, -30, w + 60, 60), false, Color(XUiSkin.GOLD, 0.30 * a))
	c.draw_string_outline(_f("title"), Vector2(-w / 2.0, 9), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8 * a))
	_text(c, Vector2(-w / 2.0, 9), s, fs, Color(XUiSkin.GOLD_LIGHT, a), "title")
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _leveled(row: Dictionary) -> bool:
	return bool(row.notified)


## A：左栏 x 96 宽 496（标题、奖励、队员），右栏 x 688 宽 496（获得物品）
const A_LEFT := 96.0
const A_W := 496.0
const A_RIGHT := 688.0
const A_TOP := 150.0
const A_ROW_Y := 214.0
const A_ROW_STEP := 80.0
const A_ROW_H := 70.0
const A_DROP_ROW := 36.0


static func _victory_a(v: XVictoryScreen, c: XMVCanvas) -> void:
	_title(c, A_LEFT, 112)
	_divider(c, A_LEFT, A_LEFT + A_W, 128)
	_rewards(v, c, A_LEFT, A_TOP, A_W)
	for i in v.rows.size():
		_row_a(c, v.rows[i], Rect2(A_LEFT, A_ROW_Y + A_ROW_STEP * i, A_W, A_ROW_H))
	if v._drops.is_empty():
		return
	var n := mini(11, v._drops.size())
	var r := Rect2(A_RIGHT, A_TOP - 56, A_W, 60 + 11 * A_DROP_ROW + 14)
	_panel(c, r)
	_text(c, Vector2(r.position.x + 22, r.position.y + 36), "获得物品", 22, XUiSkin.GOLD, "title")
	_text(c, Vector2(r.position.x, r.position.y + 35), "%d 样" % v._drops.size(), 16, XUiSkin.TEXT_2, "body", HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 22)
	c.draw_line(Vector2(r.position.x + 18, r.position.y + 52), Vector2(r.end.x - 18, r.position.y + 52), Color(XUiSkin.LINE, 0.25), 1.0)
	for k in range(n):
		var i := v._drop_top + k
		if i >= v._drops.size():
			break
		var d: Dictionary = v._drops[i]
		var rec := drop_rec(d)
		var y := r.position.y + 60 + k * A_DROP_ROW
		var x := r.position.x + 20
		if k % 2 == 1:
			c.draw_rect(Rect2(r.position.x + 12, y, r.size.x - 24, A_DROP_ROW), Color(1, 1, 1, 0.025))
		c.icon(int(rec.get("iconIndex", 0)), x, y + 2)
		var name := XQuality.list_name(rec) if rec.has("name") else "?"
		_text(c, Vector2(x + 42, y + 25), name, 19, XGear.color(rec), "body", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 150)
		_text(c, Vector2(x, y + 26), "×%s" % XMenu._group(d.count), 20, XUiSkin.GOLD_LIGHT, "num", HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 40)
	_scrollbar(c, Rect2(r.end.x - 8, r.position.y + 60, 3, 11 * A_DROP_ROW), v._drop_top, 11, v._drops.size())


static func _scrollbar(c: CanvasItem, track: Rect2, top: int, page: int, total: int) -> void:
	if total <= page:
		return
	_round_rect(c, track, Color(1, 1, 1, 0.06))
	var h := maxf(18.0, track.size.y * page / float(total))
	var y := track.position.y + (track.size.y - h) * top / float(maxi(1, total - page))
	_round_rect(c, Rect2(track.position.x, y, track.size.x, h), Color(XUiSkin.GOLD, 0.7))


static func _row_a(c: CanvasItem, row: Dictionary, r: Rect2) -> void:
	_panel(c, r)
	if _leveled(row):
		c.draw_rect(Rect2(r.position.x + 2, r.position.y + 12, 3, r.size.y - 24), XUiSkin.GOLD)
	var a: XActor = row.actor
	var x := r.position.x + 20
	var iw := r.size.x - 40
	_text(c, Vector2(x, r.position.y + 28), a.display_name(), 20, XUiSkin.TEXT, "body", HORIZONTAL_ALIGNMENT_LEFT, iw - 120)
	var lv := "Lv %s" % XMenu._group(int(row.display_level))
	_text(c, Vector2(x, r.position.y + 29), lv, 22, XUiSkin.GOLD_LIGHT if _leveled(row) else XUiSkin.TEXT, "num", HORIZONTAL_ALIGNMENT_RIGHT, iw)
	_bar(c, Rect2(x, r.position.y + 40, iw, 7), float(row.rate), Color("8a6a2c"), XUiSkin.GOLD_LIGHT)
	_text(c, Vector2(x, r.position.y + 63), str(XDB.system().terms.basic[8]), 14, XUiSkin.TEXT_3)
	_text(c, Vector2(x, r.position.y + 63), _exp_text(row), 15, XUiSkin.TEXT_2, "num", HORIZONTAL_ALIGNMENT_RIGHT, iw)
	_level_up(c, row, Vector2(r.position.x + r.size.x / 2.0, r.position.y + 20))


## B：一张居中的牌（宽 680），上面标题、奖励，中间一人一行，下面获得物品图标格
const B_W := 680.0
const B_X := (1280.0 - B_W) / 2.0
const B_ROW_STEP := 54.0
const B_TILE := 48.0
const B_TILE_STEP := 52.0


static func _victory_b(v: XVictoryScreen, c: XMVCanvas) -> void:
	_title(c, 640, 82, true)
	_divider(c, B_X + 60, B_X + B_W - 60, 100)
	var card := Rect2(B_X, 116, B_W, 0)
	var rows_h := v.rows.size() * B_ROW_STEP
	var drops_h := 0.0
	if not v._drops.is_empty():
		drops_h = 44 + B_TILE_STEP * mini(2, ceili(v._drops.size() / float(B_COLS)))
	card.size.y = 24 + 44 + 16 + rows_h + drops_h + 12
	_panel(c, card)
	var x := B_X + 24
	var w := B_W - 48
	_rewards(v, c, x, card.position.y + 20, w)
	var y := card.position.y + 20 + 44 + 16
	for i in v.rows.size():
		_row_b(c, v.rows[i], Rect2(x, y + i * B_ROW_STEP, w, B_ROW_STEP - 6), i)
	y += rows_h
	if v._drops.is_empty():
		return
	c.draw_line(Vector2(x, y + 4), Vector2(x + w, y + 4), Color(XUiSkin.LINE, 0.25), 1.0)
	_text(c, Vector2(x, y + 32), "获得物品", 20, XUiSkin.GOLD, "title")
	_text(c, Vector2(x, y + 31), "%d 样" % v._drops.size(), 15, XUiSkin.TEXT_2, "body", HORIZONTAL_ALIGNMENT_RIGHT, w)
	var start := v._drop_top * B_COLS
	var page := B_COLS * 2
	var rest := v._drops.size() - start
	var shown := mini(page, rest)
	var more := rest - page   # 还有几样没摆下（最后一格改写「＋N」）
	if more > 0:
		shown = page - 1
		more += 1
	var gx := x + (w - (B_COLS * B_TILE_STEP - (B_TILE_STEP - B_TILE))) / 2.0
	for k in shown:
		var d: Dictionary = v._drops[start + k]
		var rec := drop_rec(d)
		var tr := Rect2(gx + (k % B_COLS) * B_TILE_STEP, y + 44 + (k / B_COLS) * B_TILE_STEP, B_TILE, B_TILE)
		var qc := XGear.color(rec)
		_round_rect(c, tr, Color(0, 0, 0, 0.45), Color(qc, 0.55), 6)
		c.icon(int(rec.get("iconIndex", 0)), tr.position.x + 8, tr.position.y + 8)
		if int(d.count) > 1:
			var t := "×%s" % XMenu._group(d.count)
			c.draw_string_outline(_f("num"), Vector2(tr.position.x, tr.end.y - 3), t, HORIZONTAL_ALIGNMENT_RIGHT, tr.size.x - 3, 14, 3, Color(0, 0, 0, 0.9))
			_text(c, Vector2(tr.position.x, tr.end.y - 3), t, 14, XUiSkin.GOLD_LIGHT, "num", HORIZONTAL_ALIGNMENT_RIGHT, tr.size.x - 3)
	if more > 0:
		var k := shown
		var tr := Rect2(gx + (k % B_COLS) * B_TILE_STEP, y + 44 + (k / B_COLS) * B_TILE_STEP, B_TILE, B_TILE)
		_round_rect(c, tr, Color(0, 0, 0, 0.45), Color(XUiSkin.GOLD, 0.5), 6)
		_text(c, Vector2(tr.position.x, tr.position.y + 31), "＋%d" % more, 17, XUiSkin.GOLD_LIGHT, "num", HORIZONTAL_ALIGNMENT_CENTER, tr.size.x)


static func _row_b(c: CanvasItem, row: Dictionary, r: Rect2, i: int) -> void:
	if i % 2 == 1:
		c.draw_rect(r, Color(1, 1, 1, 0.025))
	if _leveled(row):
		c.draw_rect(Rect2(r.position.x, r.position.y + 8, 3, r.size.y - 16), XUiSkin.GOLD)
	var a: XActor = row.actor
	var cy := r.position.y + r.size.y / 2.0
	_text(c, Vector2(r.position.x + 14, cy + 7), a.display_name(), 19, XUiSkin.TEXT, "body", HORIZONTAL_ALIGNMENT_LEFT, 150)
	_text(c, Vector2(r.position.x + 170, cy + 8), "Lv %s" % XMenu._group(int(row.display_level)), 20, XUiSkin.GOLD_LIGHT if _leveled(row) else XUiSkin.TEXT, "num")
	var bx := r.position.x + 260
	var bw := r.size.x - 260 - 170
	_bar(c, Rect2(bx, cy - 3, bw, 7), float(row.rate), Color("8a6a2c"), XUiSkin.GOLD_LIGHT)
	_text(c, Vector2(r.position.x, cy + 7), _exp_text(row), 15, XUiSkin.TEXT_2, "num", HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 10)
	_level_up(c, row, Vector2(bx + bw / 2.0, cy))


## 关页提示：原版插件那句（「ESC 或者 点击屏幕 退出界面」，去掉颜色码）放在右下一枚胶囊里；能关了才出现（同旧页）
static func _victory_hint(v: XVictoryScreen, c: XMVCanvas) -> void:
	if not v._ready_to_close:
		return
	var raw := str(XDB.plugin("Olivia_VictorySequenceUI").get("Victory Screen Continue Text", "\\c[27]ESC\\c[0] 或者 \\c[27]点击屏幕\\c[0] 退出界面"))
	var s := XMVText.plain(raw).strip_edges()
	var fs := 16
	var w := _tw(s, fs) + 36
	var r := Rect2(1280 - 96 - w, 664, w, 34)
	XSkin4A.draw_capsule(c, r)
	_text(c, Vector2(r.position.x + 18, r.position.y + 23), s, fs, XUiSkin.TEXT_2)


## ==== 全灭画面 ====

## 开着新皮肤时：在 NULL 图上（A）或代替它（B）加一层，透明度跟着原来的淡入淡出走
static func gameover_overlay(g: XGameOverScreen) -> Control:
	var o := Control.new()
	o.name = "Skin2COverlay"
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.draw.connect(func(): _paint_gameover(o))
	return o


const GAMEOVER_HINT := "按确定或点一下　回到标题"


static func _paint_gameover(o: Control) -> void:
	var vs := o.size
	if vs.x <= 0.0:
		vs = Vector2(1280, 720)
	var center := vs / 2.0
	if GAMEOVER_STYLE == Style.B:
		o.draw_rect(Rect2(Vector2.ZERO, vs), XUiSkin.BG)
		o.draw_texture_rect(XUiSkin.glow_texture(), Rect2(center - Vector2(520, 300), Vector2(1040, 600)), false, Color(XUiSkin.SEL_FILL, 0.16))
		var crack := _crack_texture()
		if crack != null:
			var cs := crack.get_size()
			var k := minf(vs.x / cs.x, vs.y / cs.y) * 0.9
			o.draw_texture_rect(crack, Rect2(center - cs * k / 2.0, cs * k), false, Color(1, 1, 1, 0.35))
		var s := "NULL"
		var fs := 120
		var w := _tw(s, fs, "title")
		var p := Vector2(center.x - w / 2.0, center.y + 20)
		o.draw_texture_rect(XUiSkin.glow_texture(), Rect2(p + Vector2(-60, -fs - 10), Vector2(w + 120, fs + 60)), false, Color(XUiSkin.SEL_FILL, 0.30))
		o.draw_string_outline(_f("title"), p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.9))
		_text(o, p, s, fs, Color("9e1f17"), "title")
		_divider(o, center.x - 180, center.x + 180, center.y + 60, 0.8)
		var sub := "全军覆没"
		_text(o, Vector2(center.x - _tw(sub, 22) / 2.0, center.y + 100), sub, 22, XUiSkin.TEXT_2)
	else:
		# A：NULL 图不动，四边压暗成暗角，底部留出提示的位置
		var edge := Color(0, 0, 0, 0.0)
		var dark := Color(0, 0, 0, 0.75)
		o.draw_polygon(PackedVector2Array([Vector2(0, vs.y - 160), Vector2(vs.x, vs.y - 160), vs, Vector2(0, vs.y)]),
			PackedColorArray([edge, edge, dark, dark]))
		o.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), Vector2(vs.x, 90), Vector2(0, 90)]),
			PackedColorArray([Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.5), edge, edge]))
		o.draw_line(Vector2(center.x - 260, vs.y - 92), Vector2(center.x + 260, vs.y - 92), Color(XUiSkin.SEL_LINE, 0.45), 1.0)
	var hint := GAMEOVER_HINT
	var fs2 := 16
	var hw := _tw(hint, fs2) + 40
	var hr := Rect2(center.x - hw / 2.0, vs.y - 74, hw, 34)
	XSkin4A.draw_capsule(o, hr)
	_text(o, Vector2(hr.position.x + 20, hr.position.y + 23), hint, fs2, XUiSkin.TEXT_2)


static var _crack: Texture2D = null
static var _crack_tried := false


## 大厅异化的裂纹（content/lobby）；没有就不画
static func _crack_texture() -> Texture2D:
	if not _crack_tried:
		_crack_tried = true
		for p in ["res://content/lobby/crack_stage2.png"]:
			if ResourceLoader.exists(p):
				_crack = load(p)
				break
	return _crack


## ==== 本线计量条（v0.7 样稿：左上一张小牌「战争线　火花 3 / 10」＋细金条）====

const METER_W := 200.0
const METER_ROW_H := 50.0
const METER_TEXT_ROW_H := 50.0
const METER_GAP := 6.0


## 摆位：开着新皮肤时贴安全边距，放在自动／变速两颗圆钮下面（XSkinBattle.TOGGLE_POS／ROUND_TOGGLE_Y）
static func meter_pos(m: Control, origin: Vector2) -> Vector2:
	var x := XSkinBattle.TOGGLE_POS.x
	var top := XSkinBattle.ROUND_TOGGLE_Y + XSkinBattle.ROUND_TOGGLE_SIZE.y if (XSkinBattle.ROUND_TOGGLES and XSkin4A.hud_on()) else XSkinBattle.TOGGLE_POS.y + 46.0
	if XSkin4A.hud_on() and m.is_inside_tree():
		x = XSkin4A.safe_rect(m).position.x
		return Vector2(x, origin.y + top + 12.0)
	return origin + Vector2(x, top + 12.0)


static func meter_height(rows: Array) -> float:
	return rows.size() * (METER_ROW_H + METER_GAP)


static func draw_meter(m: XTianqiMeter) -> void:
	var y := 0.0
	for r in m.rows:
		var key := str(r.key)
		var main := XTianqiLook.main_color(key)
		var fl := clampf(float(m._flash.get(key, 0.0)) / 0.6, 0.0, 1.0)
		var w := METER_W
		var text := str(r.text).replace("／", " / ")
		if int(r.full) <= 0:
			w = maxf(METER_W, 26.0 + _tw(str(r.label), 15) + 10 + _tw(text, 15))
		var box := Rect2(0, y, w, METER_ROW_H)
		_round_rect(m, box, Color(XUiSkin.BG, 0.72), Color(XUiSkin.LINE, 0.35), 12)
		# 本线色的小点（哪条线一眼认得）
		m.draw_circle(Vector2(14, y + 17), 3.5, main)
		_text(m, Vector2(24, y + 22), str(LINE_NAMES.get(key, "")), 15, XUiSkin.TEXT_2)
		var lx := 24.0 + _tw(str(LINE_NAMES.get(key, "")), 15) + 12.0
		if int(r.full) > 0:
			_text(m, Vector2(lx, y + 22), str(r.label), 15, XUiSkin.TEXT_2)
			var nx := lx + _tw(str(r.label), 15) + 8.0
			_text(m, Vector2(nx, y + 23), "%d" % int(r.value), 18, XUiSkin.GOLD_LIGHT, "num")
			var vx := nx + _tw("%d" % int(r.value), 18, "num")
			_text(m, Vector2(vx, y + 23), " / %d" % int(r.full), 15, XUiSkin.TEXT_2, "num")
			var k := clampf(float(r.value) / float(r.full), 0.0, 1.0)
			_bar(m, Rect2(14, y + 33, w - 28, 6), k, Color(XUiSkin.GOLD, 0.85), XUiSkin.GOLD_LIGHT)
		else:
			_text(m, Vector2(lx, y + 22), str(r.label), 15, XUiSkin.TEXT_2)
			_text(m, Vector2(14, y + 42), text, 15, XUiSkin.GOLD_LIGHT, "body", HORIZONTAL_ALIGNMENT_LEFT, w - 24)
		if fl > 0.0:
			m.draw_texture_rect(XUiSkin.glow_texture(), box.grow(14), false, Color(XUiSkin.GOLD, 0.5 * fl))
			_round_rect(m, box, Color(0, 0, 0, 0), Color(XUiSkin.SEL_LINE, fl), 12)
		y += METER_ROW_H + METER_GAP


## 死期小钟：同旧画法的位置，换成黑底细线＋骨白钟面
static func draw_doom_mark(m: CanvasItem, c: Vector2, pulse: float) -> void:
	var bone := XTianqiLook.main_color("death")
	var blue := XTianqiLook.accent_color("death")
	m.draw_circle(c, 15, Color(XUiSkin.BG, 0.85))
	m.draw_arc(c, 15, 0, TAU, 32, Color(XUiSkin.LINE, 0.5), 1.0, true)
	m.draw_circle(c, 11, Color(bone, 0.85 * pulse))
	m.draw_arc(c, 11, 0, TAU, 24, Color(blue, pulse), 1.5, true)
	m.draw_line(c, c + Vector2(0, -7), Color(blue.darkened(0.3), pulse), 2.0, true)
	m.draw_line(c, c + Vector2(5, 2), Color(blue.darkened(0.3), pulse), 2.0, true)


## ==== 伤害统计（右下）====

## 底：烟色面板（同其它新皮肤面板），盖住旧的横向渐变
static func record_back(r: XDamageRecord) -> void:
	XUiSkin.draw_panel(r.get_canvas_item(), Rect2(Vector2.ZERO, r.size))


static func record_paint(r: XDamageRecord, c: XMVCanvas) -> void:
	var t := r.total()
	var w := c.size.x
	_text(c, Vector2(4, 15), "伤害统计", 15, XUiSkin.GOLD, "title")
	_text(c, Vector2(80, 15), XDamageRecord.format_damage(t), 15, XUiSkin.GOLD_LIGHT, "num", HORIZONTAL_ALIGNMENT_RIGHT, w - 84)
	for i in range(mini(5, r.slots.size())):
		var id := int(r.slots[i])
		if id <= 0:
			continue
		var a: XActor = XState.current.actor(id) if XState.current else null
		if a == null:
			continue
		var y := 24.0 + i * XDamageRecord.LH
		var share: float = r.values[i] / t if t > 0 else 0.0
		var pct := roundi(share * 100.0)
		# 占比细条（贴在这一行底下，旧金淡色）
		if share > 0.0:
			_round_rect(c, Rect2(4, y + 15, maxf(2.0, (w - 8) * share), 2), Color(XUiSkin.GOLD, 0.45), Color(0, 0, 0, 0), 1)
		_text(c, Vector2(4, y + 13), a.display_name(), 14, XUiSkin.TEXT, "body", HORIZONTAL_ALIGNMENT_LEFT, 88)
		_text(c, Vector2(94, y + 13), XDamageRecord.format_damage(r.values[i]), 14, XUiSkin.TEXT, "num", HORIZONTAL_ALIGNMENT_RIGHT, w - 140)
		_text(c, Vector2(w - 44, y + 13), "%d%%" % pct, 14, XUiSkin.TEXT_2, "num", HORIZONTAL_ALIGNMENT_RIGHT, 40)


## ==== 连击 ====
## 原版是 Combo_A（「击中」底图）＋Combo_D（数字图）。新皮肤改成程序画：淡金窄体大数＋「连击」小字＋一道旧金细线；
## 位置挪到左侧计量条下面（原位置被自动／变速圆钮占了），计时、淡出、右滑、数字 2 倍缩回全照旧（读 XComboCounter 的同一组状态）。
const COMBO_POS := Vector2(36, 340)


static func combo_pos() -> Vector2:
	return COMBO_POS


static func draw_combo(cc: XComboCounter) -> void:
	if cc.layout_alpha <= 0 and cc.digits.is_empty():
		return
	var p := combo_pos() + Vector2(cc.slide, 0)
	var la := cc.layout_alpha / 255.0
	var da := 0.0
	var k := 1.0
	if not cc.digits.is_empty():
		da = float(cc.digits[0].alpha) / 255.0
		k = float(cc.digits[0].scale)
	# 显示的数是上次重建时的击中数（归零后 hits 已清，数字还在淡出），从 digits 拼回来
	var n := "".join(PackedStringArray(cc.digits.map(func(g): return str(int(g.n)))))
	if n == "":
		n = str(cc.hits)
	var fs := 52
	var nw := _tw(n, fs, "num")
	if da > 0.0:
		var pivot := p + Vector2(nw / 2.0, -fs * 0.35)
		cc.draw_set_transform(pivot, 0.0, Vector2(k, k))
		var o := p - pivot
		cc.draw_texture_rect(XUiSkin.glow_texture(), Rect2(o + Vector2(-24, -fs - 6), Vector2(nw + 48, fs + 24)), false, Color(XUiSkin.GOLD, 0.22 * da))
		cc.draw_string_outline(_f("num"), o, n, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.14, 0.10, 0.0, 0.95 * da))
		_text(cc, o, n, fs, Color(XUiSkin.GOLD_LIGHT, da), "num")
		cc.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if la > 0.0:
		var lp := p + Vector2(nw + 8, -6)
		cc.draw_string_outline(_f("title"), lp, "连击", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color(0, 0, 0, 0.8 * la))
		_text(cc, lp, "连击", 20, Color(XUiSkin.GOLD, la), "title")
		var y := p.y + 10
		cc.draw_line(Vector2(p.x, y), Vector2(p.x + nw + 56, y), Color(XUiSkin.GOLD, 0.55 * la), 1.0)


## ==== 掉落图标 ====
## 图标底下垫一枚暗色圆片＋品质色细圈（物品没有品质的用普通色），弹跳、淡出、缩放全照旧
static func draw_drop_back(ci: CanvasItem, g: Dictionary, w: float, h: float) -> void:
	var a := float(g.alpha) / 255.0
	if a <= 0.0:
		return
	var c := Vector2(float(g.x), float(g.y) - h / 2.0)
	var r := 19.0 * absf(w) / XDropPopup.ICON
	var item: Dictionary = g.get("item", {})
	var qc := XGear.color(item) if not item.is_empty() else XUiSkin.TEXT
	ci.draw_texture_rect(XUiSkin.glow_texture(), Rect2(c - Vector2(r, r) * 1.7, Vector2(r, r) * 3.4), false, Color(qc, 0.28 * a))
	ci.draw_circle(c, r, Color(XUiSkin.BG, 0.72 * a))
	ci.draw_arc(c, r, 0, TAU, 32, Color(qc, 0.8 * a), 1.5, true)
