class_name XSkinTag
extends RefCounted
## 【cc·天启篇·未经审查】T283 通用小件：小标（T254 3.0「小标」）＋空列表一句（「空列表」）。只是画法，不是节点，
## 列表行（XSkinList 行键 tags）、详情牌、别的页的 _draw 里直接调。
## - 小标：高 22、15 号字、1px 描边圆角胶囊，没有底色。「新」「穿着」「出战 N」「领队」用旧金 GOLD；「助力」「已锁定」等用 TEXT_2。
##   颜色可以自己给；不给按 color_for(字) 认（认不出的一律 TEXT_2）。
## - 空列表：列表区正中一句 19 号 TEXT_3 的人话；右牌不画（页面自己别给牌内容）。
## 用法：
##   var w := XSkinTag.draw(self, Vector2(x, center_y), "新")          # 返回画了多宽（含描边），接着往右排就加 w + XSkinTag.GAP
##   XSkinTag.draw_empty(self, Rect2(Vector2.ZERO, size), "仓库是空的")
##   列表行：{"text": "敏锐斧", "tags": ["新"]} 或 {"tags": [{"text": "已锁定", "color": XUiSkin.TEXT_2}]}

const H := 22.0
const FS := 15
const PAD_X := 7.0
## 两个小标、名字和小标之间的空
const GAP := 6.0
const EMPTY_FS := 19
## 用旧金的小标（开头认：「出战 1」「出战 2」都算）
const GOLD_TAGS := ["新", "穿着", "出战", "领队"]


static func color_for(text: String) -> Color:
	for t in GOLD_TAGS:
		if text.begins_with(t):
			return XUiSkin.GOLD
	return XUiSkin.TEXT_2


## 小标的宽（字号跟字体设置走，最小 15）
static func width(text: String) -> float:
	return XUiSkin.font("body").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.fs(FS)).x + PAD_X * 2.0


## 小标的高（字号放大时跟着高，最少 22）
static func height() -> float:
	return maxf(H, XUiSkin.fs(FS) + 7.0)


## 在 ci 上画一个小标，pos＝左缘、竖直中线；color 不给（透明）按 color_for。返回宽
static func draw(ci: CanvasItem, pos: Vector2, text: String, color := Color(0, 0, 0, 0)) -> float:
	if text == "":
		return 0.0
	var raw_c := color if color.a > 0.0 else color_for(text)
	var pol := XUiSkin.polish_on()
	var c := XUiSkin.paint_color(raw_c) if pol else raw_c
	var fs := XUiSkin.fs(FS)
	var w := width(text)
	var h := height()
	var sb := StyleBoxFlat.new()
	if pol:
		sb.draw_center = true
		sb.bg_color = Color(0.05, 0.04, 0.04, 0.68).lerp(Color(c.r, c.g, c.b, 0.68), 0.14)
	else:
		sb.draw_center = false
	sb.border_color = Color(c, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(h / 2.0))
	sb.anti_aliasing = true
	sb.draw(ci.get_canvas_item(), Rect2(pos.x, pos.y - h / 2.0, w, h))
	XUiSkin.ds(ci, XUiSkin.font("body"), Vector2(pos.x + PAD_X, pos.y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	return w


## 行键 tags 的一项（字或 {text, color}）→ [字, 颜色]
static func parse(t) -> Array:
	if t is Dictionary:
		var tx := str(t.get("text", ""))
		return [tx, t.get("color", color_for(tx))]
	return [str(t), color_for(str(t))]


## 一排小标总宽（含之间的空，不含最前面的空）
static func row_width(tags: Array) -> float:
	var w := 0.0
	for t in tags:
		var p := parse(t)
		if str(p[0]) != "":
			w += width(str(p[0])) + (GAP if w > 0.0 else 0.0)
	return w


## 空列表：rect 正中一句（美化态叠加淡七芒暗印与渐隐短线）
static func draw_empty(ci: CanvasItem, rect: Rect2, text: String) -> void:
	if text == "":
		return
	var f := XUiSkin.font("body")
	var fs := XUiSkin.fs(EMPTY_FS)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var cx := rect.position.x + rect.size.x * 0.5
	var cy := rect.position.y + rect.size.y * 0.5
	if XUiSkin.polish_on():
		var seal := XSkinArt.part("seven_seal_128x128")
		if seal != null and rect.size.x >= 96.0 and rect.size.y >= 96.0:
			var sr := Rect2(Vector2(cx - 38.0, cy - 42.0).round(), Vector2(76.0, 76.0))
			ci.draw_texture_rect(seal, sr, false, Color(0.95, 0.84, 0.62, 0.085))
		XUiSkin.draw_divider(ci, cx - 64.0, cx + 64.0, cy + fs * 0.88, true, 0.65)
	XUiSkin.ds(ci, f, Vector2(rect.position.x + (rect.size.x - tw) / 2.0, cy + fs * 0.36), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_3)
