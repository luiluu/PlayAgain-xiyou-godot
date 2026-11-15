class_name XSkinRingNav
extends Control
## 【cc·天启篇·未经审查】环形导航（主菜单的组、装备栏位、物品分类、战斗指令都用它）：
## - 通用法阵（content/ui_skin/circle_generic.svg）在环里 50% 慢转（全部档 60 秒一圈）、外圈虚线反转（50 秒一圈）；
## - 主环 1.5px 线色 75%＋外侧 10px 绯红 5% 的光带＋一圈 22% 细线；
## - 七道旧金菱形刻痕（七印意象，固定七道，和项数无关），落在项与项之间；
## - 项是环上的圆球（亮面→暗面径向，线色 65% 描边），图标居中，名字在球外（上半圈写在球上方、下半圈写在球下方）；
##   选中的球放大 1.16、朱红 2.5px 描边＋绯红外晕，名字白色加大；
## - 焦点光弧：主环上 9% 周长的朱红弧，转到选中项（0.14 秒冲过 4°、0.2 秒回正；动效关时直接到）。
## 项按 items 排（第一项在正上方，顺时针等分），项数随数据（可见组 6 或 7）变，不用改布局。
## 项带 art_normal／art_selected（组入口 u4，XUiSkin.GROUP_ICONS_U4）时：贴图按原生大小画（64）、最近邻、整数像素位置，选中只换贴图；
## 选中贴图自带朱红圆底，这时选中球不再加绯红外晕、描边改旧金，免得叠成两层红（p1fix 追加）。

signal changed(index: int)
signal activated(index: int)

## [{key, name, icon（图标号或 Texture2D）}]
var items: Array = []
var index := 0
var radius := 180.0
var orb_radius := 33.0
var center_texture: Texture2D
var _label_size := 0
var label_size: int:   # 收口批：没设过时跟 XUiSkin.FS_LIST 现取
	get: return _label_size if _label_size > 0 else XUiSkin.FS_LIST
	set(v): _label_size = v
## >0 时项名写在环内侧、离环心这么远（装备页 13 栏一页用）；0＝照旧写在球的上方／下方
var label_inner := 0.0
## 选中项名字加大几号（装备页 13 栏一页时 1，免得挤）
var label_sel_boost := 3
## 光弧现在的角度（度，0＝正右、顺时针为正）
var arc_deg := -90.0
var _arc_from := -90.0
var _arc_to := -90.0
var _arc_t := 1.0
var _spin := 0.0
const ARC_FRAC := 0.09
const ARC_TIME := 0.2
const ARC_OVERSHOOT := 4.0
const NOTCHES := 7


## u4 贴图画在这个子画布项（最近邻；法阵 svg 照旧线性过滤）。_draw 里同步清空重画，不另排一帧
var _art_ci := RID()
## 上次画了哪些 u4 贴图（测试看）：[{i, tex, rect}]
var art_drawn: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	_art_ci = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_art_ci, get_canvas_item())
	RenderingServer.canvas_item_set_default_texture_filter(_art_ci, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _art_ci.is_valid():
		RenderingServer.free_rid(_art_ci)


## 主菜单组 → 环上的项（有 u4 贴图时带 art_normal／art_selected）
static func group_item(g: Dictionary) -> Dictionary:
	var it := {"key": g.key, "name": g.name, "icon": int(g.get("icon", 0))}
	var n := XUiSkin.group_icon(str(g.get("art", "")), false)
	var sel := XUiSkin.group_icon(str(g.get("art", "")), true)
	if n != null and sel != null:
		it["art_normal"] = n
		it["art_selected"] = sel
	return it


func has_art(i: int) -> bool:
	return i >= 0 and i < items.size() and items[i].get("art_normal") is Texture2D


## 以 p.x 为中心的标签最多能多宽：不越出本控件左右边（各留 4）
func label_room(p: Vector2) -> float:
	if size.x <= 0.0:
		return INF
	return maxf(24.0, minf(p.x - 4.0, size.x - 4.0 - p.x) * 2.0)


## 第 i 项 u4 贴图画在哪（本节点坐标，整数像素、原生大小）
func art_rect(i: int) -> Rect2:
	var tex: Texture2D = items[i].get("art_selected" if i == index else "art_normal")
	var ts := tex.get_size()
	return Rect2((item_pos(i) - ts / 2.0).round(), ts)


## 上次画的环高亮外圈在哪（测试看；没画是空矩形）
var halo_rect := Rect2()


func _draw_art() -> void:
	RenderingServer.canvas_item_clear(_art_ci)
	art_drawn.clear()
	halo_rect = Rect2()
	for i in items.size():
		if has_art(i):
			var tex: Texture2D = items[i].get("art_selected" if i == index else "art_normal")
			var r := art_rect(i)
			if i == index and XUiSkin.COMFORT_V2 and items[i].get("art_normal") is Texture2D:
				# 收口批：选中不用烤死亮红盘的贴图，程序画暗红圆底（#7a1a14，和选中条一个色）＋常态贴图，红药瓶不再红压红（Fable 审 u4-3）
				tex = items[i].art_normal
				r = Rect2((item_pos(i) - tex.get_size() / 2.0).round(), tex.get_size())
				RenderingServer.canvas_item_add_circle(_art_ci, item_pos(i), r.size.x * 0.47, XUiSkin.U4_SEL_DISC, true)
			RenderingServer.canvas_item_add_texture_rect(_art_ci, r, tex.get_rid())
			art_drawn.append({"i": i, "tex": tex, "rect": r})
			if i == index and XSkinArt.HALO and XUiSkin.on():   # 第一期正式美术：当前组图标加像素外圈（中心对齐）
				var ht := XSkinArt.halo_texture(r.size.x)
				if ht != null:
					halo_rect = XSkinArt.halo_rect(item_pos(i), r.size.x)
					RenderingServer.canvas_item_add_texture_rect(_art_ci, halo_rect, ht.get_rid())


func set_items(arr: Array, keep := false) -> void:
	items = arr
	if not keep:
		index = 0
	index = clampi(index, 0, maxi(items.size() - 1, 0))
	arc_deg = item_deg(index)
	_arc_from = arc_deg
	_arc_to = arc_deg
	_arc_t = 1.0
	queue_redraw()


## 环心离控件中心的偏移（装备页分支布局把环往上／下挪，给枝丫让地方）
var center_shift := Vector2.ZERO
## 分支布局（装备页 13 栏一页·分支，O-待定）：非空时每项一条 {pos: 相对环心, deg: 在主环上的角度（不在主环上的没有）, label: ""（写环内侧）／up／down／left／right}
var custom: Array = []
## 枝丫连线（相对环心的折线点列）：[[Vector2, Vector2, …], …]；中间的拐点画小菱形节点
var links: Array = []
## 环的样式表（留给「高品质装备改变主环样式」：换一张表就换环的描边、光带、虚线、刻痕、枝丫、球的颜色和线宽；没给的键用 DEFAULT_STYLE）
var style: Dictionary = {}
const DEFAULT_STYLE := {
	"ring_line": Color(0.0, 0.0, 0.0, -1.0), "ring_line_a": 0.75, "ring_w": 1.5,   # ring_line 的 a<0＝用 XUiSkin.LINE
	"band": Color(0.81, 0.165, 0.12, 0.05), "band_w": 10.0, "halo_line_a": 0.22,
	"dash_a": 0.30, "notch": Color(0.89, 0.741, 0.447, 1.0), "notch_size": 5.5,
	"link": Color(0.89, 0.741, 0.447, 0.55), "link_w": 1.5, "knot": Color(0.89, 0.741, 0.447, 1.0), "knot_size": 4.0,
	"orb_low": Color(0.071, 0.075, 0.082, 1.0), "orb_hi": Color(0.204, 0.212, 0.231, 0.85), "orb_line_a": 0.65,
}


## 样式表取值（style 没给就用 DEFAULT_STYLE）
func sty(key: String):
	return style.get(key, DEFAULT_STYLE[key])


func ring_line_color() -> Color:
	var c: Color = sty("ring_line")
	return Color(XUiSkin.LINE, float(sty("ring_line_a"))) if c.a < 0.0 else c


func center() -> Vector2:
	return size / 2.0 + center_shift


## 第 i 项的角度：第一项在正上方（-90°），顺时针等分；分支布局里不在主环上的项取它相对环心的方向
func item_deg(i: int) -> float:
	if not custom.is_empty() and i < custom.size():
		var c: Dictionary = custom[i]
		return float(c.deg) if c.has("deg") else rad_to_deg((c.pos as Vector2).angle())
	return -90.0 + i * 360.0 / maxf(items.size(), 1.0)


func item_pos(i: int) -> Vector2:
	if not custom.is_empty() and i < custom.size():
		return center() + (custom[i].pos as Vector2)
	return center() + Vector2.from_angle(deg_to_rad(item_deg(i))) * radius


## 这一项在主环上（光弧只在主环上的项画）
func on_ring(i: int) -> bool:
	return custom.is_empty() or (i < custom.size() and (custom[i] as Dictionary).has("deg"))


## 第 i 项名字怎么写：{text, fs, pos（基线起点）, rect（字的外框，测试查互压）}
func label_layout(i: int) -> Dictionary:
	var body := XUiSkin.font("body")
	var p := item_pos(i)
	var on := i == index
	var r := orb_radius * (1.16 if on else 1.0)
	var name := str(items[i].get("name", ""))
	var fs := label_size + (label_sel_boost if on else 0)
	var tw := body.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if XUiSkin.FONT_V2:   # 收口批（小A核 P2-3）：字号放大后标签不越出环的左右边（先缩到 15，再加「…」）
		var fit := XSkinList.fit_text(body, name, label_room(p), fs, XUiSkin.FS_MIN)
		name = str(fit[0])
		fs = int(fit[1])
		tw = body.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var above := sin(deg_to_rad(item_deg(i))) < -0.2
	var ly := p.y - r - 10.0 if above else p.y + r + 10.0 + fs * 0.86
	var lx := p.x - tw / 2.0
	var lab := str(custom[i].get("label", "")) if not custom.is_empty() and i < custom.size() else ""
	if lab != "":   # 分支布局：枝丫上的球名字写在指定一侧
		match lab:
			"up":
				ly = p.y - r - 8.0
			"down":
				ly = p.y + r + 8.0 + fs * 0.86
			"left":
				lx = p.x - r - 8.0 - tw
				ly = p.y + fs * 0.36
			"right":
				lx = p.x + r + 8.0
				ly = p.y + fs * 0.36
	elif label_inner > 0.0:   # 名字写在环内侧（装备 13 栏一页：球挨得近，上下写会压到邻球）
		var lp := center() + Vector2.from_angle(deg_to_rad(item_deg(i))) * label_inner
		lx = lp.x - tw / 2.0
		ly = lp.y + fs * 0.36
	return {"text": name, "fs": fs, "pos": Vector2(lx, ly), "rect": Rect2(lx, ly - fs * 0.86, tw, fs * 1.1)}


func notch_deg(k: int) -> float:
	return -90.0 + k * 360.0 / NOTCHES + 360.0 / (NOTCHES * 2)


func select(i: int, animate := true) -> void:
	if items.is_empty():
		return
	i = posmod(i, items.size())
	if i == index and _arc_t >= 1.0:
		return
	index = i
	var to := item_deg(i)
	# 走近路：目标角度挪到离现在最近的那一圈
	while to - arc_deg > 180.0:
		to -= 360.0
	while to - arc_deg < -180.0:
		to += 360.0
	if not animate or XUiSkin.motion() == XUiSkin.Motion.OFF:
		arc_deg = to
		_arc_from = to
		_arc_to = to
		_arc_t = 1.0
	else:
		_arc_from = arc_deg
		_arc_to = to
		_arc_t = 0.0
	queue_redraw()
	changed.emit(index)


func step(d: int) -> void:
	select(index + d)


func advance(delta: float) -> void:
	if _arc_t < 1.0:
		_arc_t = minf(1.0, _arc_t + delta / ARC_TIME)
		var over := ARC_OVERSHOOT * signf(_arc_to - _arc_from)
		var k1 := 0.14 / ARC_TIME
		if _arc_t < k1:
			var e := 1.0 - pow(1.0 - _arc_t / k1, 2.0)
			arc_deg = lerpf(_arc_from, _arc_to + over, e)
		else:
			arc_deg = lerpf(_arc_to + over, _arc_to, (_arc_t - k1) / (1.0 - k1))
		if _arc_t >= 1.0:
			arc_deg = _arc_to
		queue_redraw()
	if XUiSkin.breathing():
		_spin += delta
		queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


func item_at(p: Vector2) -> int:
	for i in items.size():
		if p.distance_to(item_pos(i)) <= orb_radius * 1.2:
			return i
	return -1


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_up", true):
		step(-1)
		return true
	if event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_down", true):
		step(1)
		return true
	if event.is_action_pressed("ui_accept"):
		if not items.is_empty():
			activated.emit(index)
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := item_at(event.position)
		if i < 0:
			return
		if i == index:
			activated.emit(i)
		else:
			select(i)
		accept_event()


func _diamond(p: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)]), col)


func _draw() -> void:
	_draw_art()
	var c := center()
	var R := radius
	var line := XUiSkin.LINE
	# 法阵
	var circ := XUiSkin.circle_texture()
	if circ != null:
		var d := R * 2.0 - 60.0
		draw_set_transform(c, deg_to_rad(_spin * 6.0), Vector2.ONE)
		draw_texture_rect(circ, Rect2(-d / 2.0, -d / 2.0, d, d), false, Color(1, 1, 1, 0.5))
		draw_set_transform(Vector2.ZERO)
	# 光带与细线
	draw_arc(c, R + 5.5, 0, TAU, 96, sty("band"), float(sty("band_w")), true)
	draw_arc(c, R + 10.5, 0, TAU, 96, Color(line, float(sty("halo_line_a"))), 1.0, true)
	draw_arc(c, R, 0, TAU, 128, ring_line_color(), float(sty("ring_w")), true)
	# 外圈虚线（反转）
	var dash_r := R + 22.0
	var dashes := 72
	var off := -_spin * TAU / 50.0
	for k in dashes:
		var a0 := off + k * TAU / dashes
		draw_arc(c, dash_r, a0, a0 + TAU / dashes * 0.5, 4, Color(line, float(sty("dash_a"))), 1.5, true)
	# 刻痕
	for k in NOTCHES:
		var p := c + Vector2.from_angle(deg_to_rad(notch_deg(k))) * (R + 11.0)
		_diamond(p, float(sty("notch_size")), sty("notch"))
	# 中心图
	if center_texture != null:
		var ts := center_texture.get_size()
		var k := minf((R - 50.0) * 2.0 / maxf(ts.x, ts.y), 4.0)
		draw_texture_rect(center_texture, Rect2(c - ts * k / 2.0, ts * k), false)
	# 枝丫连线：旧金细线＋节点小菱形（星座连线）
	for path in links:
		for k in range((path as Array).size() - 1):
			draw_line(c + path[k], c + path[k + 1], sty("link"), float(sty("link_w")), true)
		for k in range(1, (path as Array).size() - 1):   # 拐点：小菱形节点（七印环刻痕同款）
			_diamond(c + path[k], float(sty("knot_size")), sty("knot"))
	# 焦点光弧
	if not items.is_empty() and on_ring(index):
		var half := PI * ARC_FRAC
		var a := deg_to_rad(arc_deg)
		draw_arc(c, R, a - half, a + half, 24, Color(XUiSkin.SEL_FILL, 0.35), 11.0, true)
		draw_arc(c, R, a - half, a + half, 24, XUiSkin.SEL_LINE, 5.0, true)
	# 球
	var body := XUiSkin.font("body")
	for i in items.size():
		var p := item_pos(i)
		var on := i == index
		var r := orb_radius * (1.16 if on else 1.0)
		var art := has_art(i)
		if on:
			var g := XUiSkin.glow_texture()
			# u4 选中贴图自带朱红底：外晕减成淡旧金，不叠第二层红
			draw_texture_rect(g, Rect2(p - Vector2(r + 24, r + 24), Vector2(r + 24, r + 24) * 2), false,
				Color(XUiSkin.GOLD, 0.30) if art else Color(XUiSkin.SEL_FILL, 0.85))
		draw_circle(p + Vector2(0, 3), r + 2, Color(0, 0, 0, 0.45))
		draw_circle(p, r, sty("orb_low"))
		draw_circle(p + Vector2(-r * 0.15, -r * 0.2), r * 0.72, sty("orb_hi"))
		var ring_col := (Color(XUiSkin.GOLD, 1.0) if art else Color(XUiSkin.SEL_LINE, 1.0)) if on else Color(line, float(sty("orb_line_a")))
		draw_circle(p, r, ring_col, false, 2.5 if on else 1.5, true)
		var icon = items[i].get("icon")
		var tex: Texture2D = icon if icon is Texture2D else (XUiSkin.icon(int(icon)) if (icon is int or icon is float) and int(icon) > 0 else null)
		if tex != null and not art:
			var s := 40.0 * (1.16 if on else 1.0)
			draw_texture_rect(tex, Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), false)
		var lay := label_layout(i)
		var name: String = lay.text
		var fs: int = lay.fs
		var lx: float = lay.pos.x
		var ly: float = lay.pos.y
		var rd := XSkinArt.read_on()   # 可读性：描边加粗加深、未选中的名字提亮
		draw_string_outline(body, Vector2(lx, ly), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5 if rd else 4, Color(0, 0, 0, 0.9 if rd else 0.6))
		draw_string(body, Vector2(lx, ly), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if on else XSkinArt.bg_text_2())
