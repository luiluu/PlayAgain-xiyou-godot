class_name XSkinRingNav
extends Control
## 【cc·天启篇·未经审查】环形导航（主菜单的组、装备栏位、物品分类、战斗指令都用它）：
## - 通用法阵（content/ui_skin/circle_generic.svg）在环里 50% 慢转（全部档 60 秒一圈）、外圈虚线反转（50 秒一圈）；
## - 主环 1.5px 线色 75%＋外侧 10px 绯红 5% 的光带＋一圈 22% 细线；
## - 七道旧金菱形刻痕（七印意象，固定七道，和项数无关），落在项与项之间；
## - 项是环上的圆球（亮面→暗面径向，线色 65% 描边），图标居中，名字在球外（上半圈写在球上方、下半圈写在球下方）；
##   选中的球放大 SEL_SCALE（1.15，0.12 秒过渡）、朱红 2.5px 描边＋绯红外晕，名字白色加大；
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
## 选中放大（球、图标、名字一起；倍数和过渡时长在 XUiSkin.SEL_SCALE／SEL_TIME，全界面共用）
const SEL_SCALE := XUiSkin.SEL_SCALE
var _scales := {}   # 项 → 现在的放大倍数（过渡中）


## u4 贴图画在这个子画布项（最近邻；法阵 svg 照旧线性过滤）。_draw 里同步清空重画，不另排一帧
var _art_ci := RID()
## 上次画了哪些 u4 贴图（测试看）：[{i, tex, rect}]
var art_drawn: Array = []

## ---- 环纹（天启篇装备环样式 v0.2.1 第 5.1 节层序、7.3 节接口；XTianqiRingStyle 出数据，装备页填进来）----
## 从下往上：_band_ci（draw_behind_parent，环身图，最近邻）→ 本节点 _draw（法阵、光带、主圈、虚线、连线、光弧、球＋图标）→
## _orb_ci（球框、套装小点、补画选中红框，最近邻）→ _label_ci（栏位名，线性）→ _art_ci（主菜单 u4）→ 子控件（装备页 ring_top）。
## 三个新子画布项在 _init 里按 _orb_ci → _label_ci → _art_ci 的顺序建、都不设 draw_index（全留默认 0），子画布项按建的顺序排，
## 天然都在 ring_top（之后才 add_child）之前（小A 抽看 8cb0693 第三节第 1 条：别给它们设正的 draw_index，会把 ring_top 反压到下面）。
## 都空着时环和以前逐像素一样：orb_frames／orb_dots 都空时栏位名照旧在 _draw 的球循环里画，第 3、4 层不启用。
var _band_ci := RID()
var _orb_ci := RID()
var _label_ci := RID()
## 建子画布项的顺序（测试看层序）
var layer_order: Array = []
## 环身贴图口子：{band: Texture2D, circle: Texture2D, circle_a: float, circle_tint: Color}；有 band 就画图、不画程序的光带、主圈、外圈细线和虚线；
## 有 circle 就替掉通用法阵，乘 circle_tint、按 circle_a
var style_art: Dictionary = {}
## 环项序号 → {tex: Texture2D, tint: Color}（球框，按 item_scale 放大）
var orb_frames: Dictionary = {}
## 环项序号 → Color（套装小点）
var orb_dots: Dictionary = {}
## 动效参数 {spin, breath, motes, mote_color}；按界面动效档削减（全部才转、呼吸、飘光点）
var motion: Dictionary = {}
## 演出：intro_kind＝burn（0.6 秒从 12 点顺时针铺开，先闪旧金）／fade（0.3 秒淡入）／""；intro_t 0→1
var intro_kind := ""
var intro_t := 1.0
## fade 演出的「旧环」快照 {style, art, motion}：脱下／微亮态进出时旧环按 1-alpha 淡出、新环按 alpha 淡入（4.1 的 0.3 秒淡入淡出）；演完清空
var fade_from: Dictionary = {}
const INTRO_TIME := {"burn": 0.6, "fade": 0.3}
## 测试看：栏位名这一帧画在哪一层（"parent"／"label_ci"）、补画了几次选中红框、多画了几次贴图
var labels_on := "parent"
var ring_draws := 0
## 测试用：不画栏位名（量名字底下的底色对比度）
var hide_labels := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	var me := get_canvas_item()
	_band_ci = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_band_ci, me)
	RenderingServer.canvas_item_set_draw_behind_parent(_band_ci, true)
	RenderingServer.canvas_item_set_default_texture_filter(_band_ci, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	_orb_ci = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_orb_ci, me)
	RenderingServer.canvas_item_set_default_texture_filter(_orb_ci, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	_label_ci = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_label_ci, me)
	RenderingServer.canvas_item_set_default_texture_filter(_label_ci, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR)
	_art_ci = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_art_ci, me)
	RenderingServer.canvas_item_set_default_texture_filter(_art_ci, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	layer_order = ["band_ci(behind)", "parent", "orb_ci", "label_ci", "art_ci", "children"]


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for ci in [_art_ci, _band_ci, _orb_ci, _label_ci]:
			if ci.is_valid():
				RenderingServer.free_rid(ci)


## 这一帧走不走环纹的第 3、4 层（球框／小点在名字下面）
func ring_layers() -> bool:
	return not orb_frames.is_empty() or not orb_dots.is_empty()


## 动效档：2＝全部（转、呼吸、飘光点、演铺开）、1＝简化（只演铺开）、0＝关（全停、直接切换）。「画面特效」关或省电同「关」
static func ring_motion_level() -> int:
	if not XGraphics.fx_on():
		return 0
	match XUiSkin.motion():
		XUiSkin.Motion.FULL:
			return 2
		XUiSkin.Motion.SIMPLE:
			return 1
	return 0


## 演出（不拦输入）。动效关时一帧就结束
func play_intro(kind: String, from := {}) -> void:
	if kind == "" or not INTRO_TIME.has(kind):
		return
	intro_kind = kind
	intro_t = 0.0 if ring_motion_level() > 0 else 1.0
	fade_from = from if kind == "fade" and intro_t < 1.0 else {}
	queue_redraw()


## 切人／换队序：进行中的演出作废，直接是那人的环（不串旧角色的半途铺开）
func cancel_intro() -> void:
	intro_kind = ""
	intro_t = 1.0
	fade_from = {}
	queue_redraw()


func intro_alpha() -> float:
	return 1.0 if intro_kind != "fade" else clampf(intro_t, 0.0, 1.0)


## 小点中心：外侧径向顺时针偏 45°、离球心 0.9 倍球半径（7.3）
func dot_pos(i: int) -> Vector2:
	return item_pos(i) + Vector2.from_angle(deg_to_rad(item_deg(i) + 45.0)) * 0.9 * orb_radius * item_scale(i)


## 小点外框（8×8×item_scale，含 1px 黑边）
func dot_rect(i: int) -> Rect2:
	var s := 8.0 * item_scale(i)
	return Rect2(dot_pos(i) - Vector2(s, s) / 2.0, Vector2(s, s))


## 球框画在哪（56×56×item_scale，静止 1:1 时取整）
func frame_rect(i: int, tex: Texture2D) -> Rect2:
	var k := item_scale(i)
	var ts := tex.get_size() * k
	var pos := item_pos(i) - ts / 2.0
	return Rect2(pos.round() if is_equal_approx(k, 1.0) else pos, ts)


## 一张贴图从 12 点顺时针铺开到 t（0～1）：扇形多边形带 UV（不用着色器）
static func add_sweep(ci: RID, rect: Rect2, tex: Texture2D, t: float, col: Color) -> void:
	if t >= 1.0:
		RenderingServer.canvas_item_add_texture_rect(ci, rect, tex.get_rid(), false, col)
		return
	if t <= 0.0:
		return
	var c := rect.get_center()
	var rad := rect.size.length() / 2.0 + 2.0
	var steps := maxi(3, ceili(48.0 * t))
	var pts := PackedVector2Array([c])
	var uvs := PackedVector2Array([Vector2(0.5, 0.5)])
	for k in steps + 1:
		var a := -PI / 2.0 + TAU * t * k / float(steps)
		var p := c + Vector2.from_angle(a) * rad
		pts.append(p)
		uvs.append((p - rect.position) / rect.size)
	var cols := PackedColorArray()
	cols.resize(pts.size())
	cols.fill(col)
	RenderingServer.canvas_item_add_polygon(ci, pts, cols, uvs, tex.get_rid())


func _draw_band() -> void:
	RenderingServer.canvas_item_clear(_band_ci)
	_add_band(style_art, intro_alpha(), intro_t if intro_kind == "burn" else 1.0)
	if not fade_from.is_empty() and intro_t < 1.0:
		_add_band(fade_from.get("art", {}), 1.0 - intro_alpha(), 1.0)


func _add_band(art: Dictionary, alpha: float, t: float) -> void:
	var tex: Texture2D = art.get("band")
	if tex == null:
		return
	var ts := tex.get_size()
	var r := Rect2((center() - ts / 2.0).round(), ts)
	add_sweep(_band_ci, r, tex, t, Color(1, 1, 1, alpha))
	ring_draws += 1


## 第 3、4 层：球框、小点、补画选中红框（_orb_ci），栏位名（_label_ci）
func _draw_layers() -> void:
	RenderingServer.canvas_item_clear(_orb_ci)
	RenderingServer.canvas_item_clear(_label_ci)
	if not ring_layers():
		labels_on = "parent"
		return
	labels_on = "label_ci"
	for i in items.size():
		var f = orb_frames.get(i)
		if f is Dictionary and f.get("tex") is Texture2D:
			var tex: Texture2D = f.tex
			RenderingServer.canvas_item_add_texture_rect(_orb_ci, frame_rect(i, tex), tex.get_rid(), false, f.get("tint", Color.WHITE))
			ring_draws += 1
		if orb_dots.has(i):
			var dr := dot_rect(i)
			RenderingServer.canvas_item_add_rect(_orb_ci, dr, Color(0, 0, 0, 0.9))
			RenderingServer.canvas_item_add_rect(_orb_ci, dr.grow(-1.0 * item_scale(i)), orb_dots[i])
	# 选中红框补画一遍，永远在框和点之上（2.1 第 3 条）
	if index >= 0 and index < items.size():
		var p := item_pos(index)
		var r := orb_radius * item_scale(index)
		var pts := PackedVector2Array()
		for k in 65:
			pts.append(p + Vector2.from_angle(TAU * k / 64.0) * r)
		var col := Color(XUiSkin.GOLD, 1.0) if has_art(index) else Color(XUiSkin.SEL_LINE, 1.0)
		RenderingServer.canvas_item_add_polyline(_orb_ci, pts, PackedColorArray([col]), 2.5, true)
	var body := XUiSkin.font("body")
	var rd := XSkinArt.read_on()
	for i in (0 if hide_labels else items.size()):
		var lay := label_layout(i)
		body.draw_string_outline(_label_ci, lay.pos, lay.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lay.fs, 5 if rd else 4, Color(0, 0, 0, 0.9 if rd else 0.6))
		body.draw_string(_label_ci, lay.pos, lay.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lay.fs, Color.WHITE if i == index else XSkinArt.bg_text_2())


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
## 分支布局（装备页 13 栏一页·分支，O-519）：非空时每项一条 {pos: 相对环心, deg: 在主环上的角度（不在主环上的没有）, label: ""（写环内侧）／up／down／left／right}
var custom: Array = []
## 枝丫连线（相对环心的折线点列）：[[Vector2, Vector2, …], …]；中间的拐点画小菱形节点
var links: Array = []
## 每条连线上的副栏是第几项（选中时提亮那条线）；links_elbowed＝连线中间点是拐点（弧线模式只认首尾）
var link_items: Array = []
var links_elbowed := false
## 环的样式表（留给「高品质装备改变主环样式」：换一张表就换环的描边、光带、虚线、刻痕、枝丫、球的颜色和线宽；没给的键用 DEFAULT_STYLE）
var style: Dictionary = {}
const DEFAULT_STYLE := {
	"ring_line": Color(0.0, 0.0, 0.0, -1.0), "ring_line_a": 0.75, "ring_w": 1.5,   # ring_line 的 a<0＝用 XUiSkin.LINE
	"band": Color(0.81, 0.165, 0.12, 0.05), "band_w": 10.0, "halo_line_a": 0.22,
	"dash_a": 0.30, "notches": true, "notch": Color(0.89, 0.741, 0.447, 1.0), "notch_size": 5.5,   # notches＝环上七颗刻痕菱形（七印）；项数不是 7 的页（装备页）关掉，免得画面上有没含义的点
	"link": Color(0.89, 0.741, 0.447, 0.55), "link_w": 1.5, "link_curve": false, "link_style": 0,   # link_style＝线样式套号（0＝v7 等宽细线；1～4 见 LINK_STYLES，只管单副栏枝）；link_curve＝枝丫画成弧线（从根栏沿径向出发、平滑弯向副栏，不画拐点菱形）
	 "knot": Color(0.89, 0.741, 0.447, 1.0), "knot_size": 4.0,
	"orb_low": Color(0.071, 0.075, 0.082, 1.0), "orb_hi": Color(0.204, 0.212, 0.231, 0.85), "orb_line_a": 0.65,
}


## 连线样式（v8，Kyo 11-16「是样式和颜色的问题」）：线从两球边缘起止，根粗梢细；正红只给选中框，选中副栏时线整根提亮（不变红）、父栏描边转亮金。
## 键：col 线色、a0／a1 根／梢不透明度、w0／w1 根／梢线宽、edge 深色描边宽（0＝不描）、gap 副栏端气口、
## under／under_w 底层（双层线的暗铜底）、root 根部印（diamond／dot／""）、tip 梢部印、hot 选中时的线色
const LINK_STYLES := {
	1: {"name": "S1 实金锥线", "col": Color("e3bd72"), "a0": 0.85, "a1": 0.85, "w0": 3.0, "w1": 1.2, "edge": 1.0, "gap": 3.0,
		"root": "diamond", "tip": "", "hot": Color("f6dc9c")},
	2: {"name": "S2 金到透明", "col": Color("f0cf86"), "a0": 0.95, "a1": 0.18, "w0": 2.6, "w1": 1.3, "edge": 1.0, "gap": 6.0,
		"root": "dot", "tip": "", "hot": Color("ffe7b0")},
	3: {"name": "S3 骨白细线", "col": Color("d2ccc2"), "a0": 0.78, "a1": 0.62, "w0": 1.6, "w1": 1.2, "edge": 1.0, "gap": 2.0,
		"root": "", "tip": "", "hot": Color("f4efe6")},
	4: {"name": "S4 暗铜镶金", "col": Color("f0d495"), "a0": 0.92, "a1": 0.80, "w0": 1.2, "w1": 0.9, "edge": 0.0, "gap": 3.0,
		"under": Color("7a5a2c"), "under_a": 0.75, "under_w": 2.4, "root": "diamond", "tip": "dot", "hot": Color("fff1cc")},
}


## 样式表取值（style 没给就用 DEFAULT_STYLE）
func sty(key: String):
	return style.get(key, DEFAULT_STYLE[key])


func ring_line_color() -> Color:
	var c: Color = sty("ring_line")
	return Color(XUiSkin.LINE, float(sty("ring_line_a"))) if c.a < 0.0 else c


## 第 i 项现在的放大倍数：选中项过渡到 SEL_SCALE，其余回 1（动效关时直接到）
func item_scale(i: int) -> float:
	if not XSkinSelScale.ENABLED:   # T040：挂上总开关（原先只读 v7 的 XUiSkin.sel_scale_target，总开关关了环导航还放大）
		return 1.0
	if XUiSkin.motion() == XUiSkin.Motion.OFF:
		return XUiSkin.sel_scale_target(i == index)
	return float(_scales.get(i, XUiSkin.sel_scale_target(i == index)))


func _ease_scales(delta: float) -> void:
	if not XSkinSelScale.ENABLED:
		return
	for i in items.size():
		var cur := item_scale(i)
		var nxt := XUiSkin.sel_scale_step(cur, i == index, delta)
		_scales[i] = nxt
		if nxt != cur:
			queue_redraw()


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
	var k := item_scale(i)
	var r := orb_radius * k
	var name := str(items[i].get("name", ""))
	var fs := label_size + roundi(label_sel_boost * XUiSkin.sel_scale_frac(k))
	var tw := body.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var lab := str(custom[i].get("label", "")) if not custom.is_empty() and i < custom.size() else ""
	if XUiSkin.FONT_V2:   # 收口批（小A核 P2-3）：字号放大后标签不越出环的左右边（先缩到 15，再加「…」）
		var room := label_room(p)
		if lab == "right" and size.x > 0.0:   # 写在球一侧的名字：按那一侧到边的距离算（小A核 v4 P3-1）
			room = maxf(24.0, size.x - 4.0 - (p.x + r + 8.0))
		elif lab == "left" and size.x > 0.0:
			room = maxf(24.0, p.x - r - 8.0 - 4.0)
		var fit := XSkinList.fit_text(body, name, room, fs, XUiSkin.FS_MIN)
		name = str(fit[0])
		fs = int(fit[1])
		tw = body.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var above := sin(deg_to_rad(item_deg(i))) < -0.2
	var ly := p.y - r - 10.0 if above else p.y + r + 10.0 + fs * 0.86
	var lx := p.x - tw / 2.0
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
	_ease_scales(delta)
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
	if intro_t < 1.0:
		intro_t = minf(1.0, intro_t + delta / float(INTRO_TIME.get(intro_kind, 0.3))) if ring_motion_level() > 0 else 1.0
		if intro_t >= 1.0:
			fade_from = {}
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


## 弧线枝丫：二次贝塞尔，起点沿根栏径向出发（控制点＝副栏在根栏径向上的垂足），平滑弯到副栏
static func curve_points(c: Vector2, a: Vector2, b: Vector2, steps := 20) -> PackedVector2Array:
	var u := a.normalized()
	var ctrl := u * b.dot(u)
	var pts := PackedVector2Array()
	for k in steps + 1:
		var t := k / float(steps)
		pts.append(c + a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	return pts


func _diamond(p: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)]), col)


## 法阵＋程序光带／主圈／细线／虚线，整体乘 alpha（淡入淡出用）
func _draw_body(c: Vector2, R: float, line: Color, alpha: float) -> void:
	# 法阵（环纹给了本印法阵就换掉通用的：乘 circle_tint、按 circle_a，全部档时轻微呼吸）
	var circ := XUiSkin.circle_texture()
	var circ_col := Color(1, 1, 1, 0.5 * alpha)
	var spin_k := 1.0
	if style_art.get("circle") is Texture2D:
		circ = style_art.circle
		var lv := ring_motion_level()
		spin_k = float(motion.get("spin", 1.0)) if lv >= 2 else 0.0
		var breath := float(motion.get("breath", 0.0)) * (0.5 + 0.5 * sin(_spin * TAU / 4.0)) if lv >= 2 else 0.0
		circ_col = Color(style_art.get("circle_tint", Color.WHITE), (float(style_art.get("circle_a", 0.28)) + breath) * alpha)
		ring_draws += 1
	if circ != null:
		var d := R * 2.0 - 60.0
		draw_set_transform(c, deg_to_rad(_spin * 6.0 * spin_k), Vector2.ONE)
		draw_texture_rect(circ, Rect2(-d / 2.0, -d / 2.0, d, d), false, circ_col)
		draw_set_transform(Vector2.ZERO)
	if not (style_art.get("band") is Texture2D):
		# 光带与细线
		draw_arc(c, R + 5.5, 0, TAU, 96, _a(sty("band"), alpha), float(sty("band_w")), true)
		draw_arc(c, R + 10.5, 0, TAU, 96, Color(line, float(sty("halo_line_a")) * alpha), 1.0, true)
		draw_arc(c, R, 0, TAU, 128, _a(ring_line_color(), alpha), float(sty("ring_w")), true)
		# 外圈虚线（反转）
		var dash_r := R + 22.0
		var dashes := 72
		var off := -_spin * TAU / 50.0
		for k in dashes:
			var a0 := off + k * TAU / dashes
			draw_arc(c, dash_r, a0, a0 + TAU / dashes * 0.5, 4, Color(line, float(sty("dash_a")) * alpha), 1.5, true)


static func _a(c: Color, k: float) -> Color:
	return Color(c, c.a * k)


func _draw() -> void:
	_draw_art()
	ring_draws = 0
	_draw_band()
	var c := center()
	var R := radius
	var line := XUiSkin.LINE
	_draw_body(c, R, line, intro_alpha())
	if not fade_from.is_empty() and intro_t < 1.0:   # 旧环淡出（脱下／微亮态进出）
		var keep := [style, style_art, motion, ring_draws]
		style = fade_from.get("style", style)
		style_art = fade_from.get("art", {})
		motion = fade_from.get("motion", {})
		_draw_body(c, R, line, 1.0 - intro_alpha())
		style = keep[0]
		style_art = keep[1]
		motion = keep[2]
		ring_draws = keep[3]
	# 铺开演出：先闪一下旧金（前三分之一）
	if intro_kind == "burn" and intro_t < 1.0:
		var fl := clampf(1.0 - intro_t * 3.0, 0.0, 1.0)
		if fl > 0.0:
			draw_arc(c, R, 0, TAU, 128, Color(XUiSkin.GOLD, 0.8 * fl), 3.0, true)
	# 沿主圈飘的光点（≤ 8 颗，只在全部档）
	var motes := mini(int(motion.get("motes", 0)), 8)
	if motes > 0 and ring_motion_level() >= 2 and style_art.get("band") is Texture2D:
		var mc: Color = motion.get("mote_color", XUiSkin.GOLD_LIGHT)
		for k in motes:
			var a := _spin * TAU / 30.0 + k * TAU / motes
			var p := c + Vector2.from_angle(a) * (R + 3.0 * sin(_spin * 2.0 + k))
			draw_circle(p, 1.5, Color(mc, (0.35 + 0.3 * (0.5 + 0.5 * sin(_spin * 3.0 + k * 1.7))) * intro_alpha()))
	# 刻痕
	for k in (NOTCHES if bool(sty("notches")) else 0):
		var p := c + Vector2.from_angle(deg_to_rad(notch_deg(k))) * (R + 11.0)
		_diamond(p, float(sty("notch_size")), sty("notch"))
	# 中心图
	if center_texture != null:
		var ts := center_texture.get_size()
		var k := minf((R - 50.0) * 2.0 / maxf(ts.x, ts.y), 4.0)
		draw_texture_rect(center_texture, Rect2(c - ts * k / 2.0, ts * k), false)
	# 枝丫连线：旧金细线＋节点小菱形（星座连线）；v8 线样式（link_style≠0）只管单副栏枝（C 摆法），A／B 摆法串两颗的照旧
	var ls := int(sty("link_style"))
	var hot_roots := {}
	for li in links.size():
		var path: Array = links[li]
		var hot := li < link_items.size() and (link_items[li] as Array).has(index)   # 选中的是这条线上的副栏：线提亮加粗（小A核 v4 P3-2）
		if LINK_STYLES.has(ls) and links_elbowed and path.size() <= 3:
			var ri := _item_at_pos(path[0])
			var si: int = (link_items[li] as Array)[0] if li < link_items.size() and not (link_items[li] as Array).is_empty() else -1
			if hot and ri >= 0:
				hot_roots[ri] = true
			_draw_styled_link(c, path, ri, si, LINK_STYLES[ls], hot, li)
			continue
		var lc: Color = sty("link")
		if hot:
			lc = Color(lc, minf(1.0, lc.a + 0.4))
		var lw := float(sty("link_w")) + (0.75 if hot else 0.0)
		if bool(sty("link_curve")) and links_elbowed and path.size() == 3:   # 弧线只给「根→拐点→副栏」这种单副栏枝（一枝串两颗的 A／B 摆法、哈基米直连照旧直线）
			draw_polyline(curve_points(c, path[0], path[-1]), lc, lw, true)
			continue
		for k in range(path.size() - 1):
			draw_line(c + path[k], c + path[k + 1], lc, lw, true)
		if links_elbowed:   # 拐点：小菱形节点（七印环刻痕同款）；A／B 摆法中间点是副栏本身，不画
			for k in range(1, path.size() - 1):
				_diamond(c + path[k], float(sty("knot_size")), sty("knot"))
	# 焦点光弧
	if not items.is_empty() and on_ring(index):
		var half := PI * ARC_FRAC
		var a := deg_to_rad(arc_deg)
		draw_arc(c, R, a - half, a + half, 24, Color(XUiSkin.SEL_FILL, 0.35), 11.0, true)
		draw_arc(c, R, a - half, a + half, 24, XUiSkin.SEL_LINE, 5.0, true)
	# 球
	var body := XUiSkin.font("body")
	var layers := ring_layers()
	for i in items.size():
		var p := item_pos(i)
		var on := i == index
		var r := orb_radius * item_scale(i)
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
		var parent_hint := not on and hot_roots.has(i)   # 选中副栏时它的父栏：描边转亮金（不红，红只给选中）
		if parent_hint:
			ring_col = Color(XUiSkin.GOLD, 0.95)
		draw_circle(p, r, ring_col, false, 2.5 if on else (2.0 if parent_hint else 1.5), true)
		var icon = items[i].get("icon")
		var tex: Texture2D = icon if icon is Texture2D else (XUiSkin.icon(int(icon)) if (icon is int or icon is float) and int(icon) > 0 else null)
		if tex != null and not art:
			var s := 40.0 * item_scale(i)
			draw_texture_rect(tex, Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), false)
		if layers or hide_labels:   # 环纹第 3、4 层开着：名字挪到 _label_ci，画在球框、小点上面
			continue
		var lay := label_layout(i)
		var name: String = lay.text
		var fs: int = lay.fs
		var lx: float = lay.pos.x
		var ly: float = lay.pos.y
		var rd := XSkinArt.read_on()   # 可读性：描边加粗加深、未选中的名字提亮
		draw_string_outline(body, Vector2(lx, ly), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5 if rd else 4, Color(0, 0, 0, 0.9 if rd else 0.6))
		draw_string(body, Vector2(lx, ly), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if on else XSkinArt.bg_text_2())
	_draw_layers()


## 位置（相对环心）对得上的那一项（连线首点＝根栏）
func _item_at_pos(rel: Vector2) -> int:
	for i in custom.size():
		if ((custom[i] as Dictionary).pos as Vector2).distance_to(rel) < 0.5:
			return i
	return -1


## 连线走向（相对环心的密点列）：A 斜折＝根→拐点→副栏；B 弧线＝以拐点为控制点的二次贝塞尔（径向出发、和 A 同一形制，
## 项链那根不再鼓肚子）；两点（哈基米法宝直连武器）一律直线
func link_route(path: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if path.size() == 3 and bool(sty("link_curve")):
		var a: Vector2 = path[0]
		var m: Vector2 = path[1]
		var b: Vector2 = path[2]
		for k in 33:
			var t := k / 32.0
			pts.append(a.lerp(m, t).lerp(m.lerp(b, t), t))
		return pts
	for k in range(path.size() - 1):
		var a: Vector2 = path[k]
		var b: Vector2 = path[k + 1]
		var n := maxi(2, int(a.distance_to(b) / 3.0))
		for j in n:
			pts.append(a.lerp(b, j / float(n)))
	pts.append(path[-1])
	return pts


## 把点列裁到两球外：起点离 a 至少 ra、终点离 b 至少 rb（交点线性插值）
static func clip_route(pts: PackedVector2Array, a: Vector2, ra: float, b: Vector2, rb: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var started := false
	for k in pts.size():
		var p := pts[k]
		var inside_a := p.distance_to(a) < ra
		var inside_b := p.distance_to(b) < rb
		if not started:
			if inside_a:
				continue
			started = true
			if k > 0:
				var q := pts[k - 1]
				out.append(q.lerp(p, _cross_t(q, p, a, ra)))
		if inside_b:
			if k > 0 and not out.is_empty():
				var q := pts[k - 1]
				out.append(q.lerp(p, _cross_t(q, p, b, rb)))
			break
		out.append(p)
	return out


## 线段 q→p 和圆（中心 o、半径 r）的交点在第几成（q、p 一里一外；二分够用）
static func _cross_t(q: Vector2, p: Vector2, o: Vector2, r: float) -> float:
	var lo := 0.0
	var hi := 1.0
	var q_in := q.distance_to(o) < r
	for i in 12:
		var mid := (lo + hi) * 0.5
		if (q.lerp(p, mid).distance_to(o) < r) == q_in:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


## 一条变宽变色的带子：逐段四边形（顶点法线取相邻两段平均、斜接补长），两边再描 1px 抗锯齿边
func _ribbon(pts: PackedVector2Array, widths: PackedFloat32Array, cols: PackedColorArray) -> void:
	_ribbon_draw(_ribbon_build(pts, widths, cols))


## 带子的几何（左右边点列＋颜色）：只在连线几何变了才重算（T034 稳态缓存）
static func _ribbon_build(pts: PackedVector2Array, widths: PackedFloat32Array, cols: PackedColorArray) -> Dictionary:
	var n := pts.size()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in n:
		var d0 := (pts[k] - pts[maxi(k - 1, 0)]).normalized() if k > 0 else (pts[1] - pts[0]).normalized()
		var d1 := (pts[mini(k + 1, n - 1)] - pts[k]).normalized() if k < n - 1 else d0
		var dir := (d0 + d1).normalized()
		if dir == Vector2.ZERO:
			dir = d1
		var nrm := Vector2(-dir.y, dir.x)
		var miter := clampf(1.0 / maxf(absf(nrm.dot(Vector2(-d1.y, d1.x))), 0.5), 1.0, 2.0)
		var h := widths[k] * 0.5 * miter
		left.append(pts[k] + nrm * h)
		right.append(pts[k] - nrm * h)
	return {"left": left, "right": right, "cols": cols}


func _ribbon_draw(rb: Dictionary) -> void:
	var left: PackedVector2Array = rb.left
	var right: PackedVector2Array = rb.right
	var cols: PackedColorArray = rb.cols
	for k in left.size() - 1:
		draw_polygon(PackedVector2Array([left[k], left[k + 1], right[k + 1], right[k]]),
			PackedColorArray([cols[k], cols[k + 1], cols[k + 1], cols[k]]))
	draw_polyline_colors(left, cols, 1.0, true)
	draw_polyline_colors(right, cols, 1.0, true)


## 连线缓存（T034）：几何只跟 path／两球缩放／半径／样式／hot／环心有关，不跟呼吸（_spin）；呼吸每帧重画时直接复用
var _link_cache := {}
## 连线几何重建次数（专项断言：稳态为 0）
var link_rebuilds := 0


## 按样式画一条单副栏枝（ri／si＝根栏／副栏是第几项，取放大后的半径算边缘）
func _draw_styled_link(c: Vector2, path: Array, ri: int, si: int, st: Dictionary, hot: bool, li := 0) -> void:
	var data := link_data(c, path, ri, si, st, hot, li)
	if data.has("abs"):
		_paint_styled_link(data, st)


## 取这条枝的几何（命中缓存就直接返回，几何变了才重建；专项直接调这个，不用在 _draw 里）
func link_data(c: Vector2, path: Array, ri: int, si: int, st: Dictionary, hot: bool, li := 0) -> Dictionary:
	var sr := item_scale(ri) if ri >= 0 else 1.0
	var ss := item_scale(si) if si >= 0 else 1.0
	var key := [c, hash(path), ri, si, sr, ss, orb_radius, hot, st.hash()]
	var data: Dictionary = _link_cache.get(li, {})
	if data.is_empty() or data.key != key:
		data = _build_styled_link(c, path, sr, ss, st, hot)
		data["key"] = key
		_link_cache[li] = data
		link_rebuilds += 1
	return data


func _build_styled_link(c: Vector2, path: Array, sr: float, ss: float, st: Dictionary, hot: bool) -> Dictionary:
	var a: Vector2 = path[0]
	var b: Vector2 = path[-1]
	var ra := orb_radius * sr + 4.5   # +4.5：躲开球的投影（r+2、下移 3），根部印才露得出来
	var rb := orb_radius * ss + float(st.gap)
	var pts := clip_route(link_route(path), a, ra, b, rb)
	if pts.size() < 2:
		return {}
	var total := 0.0
	var acc := PackedFloat32Array([0.0])
	for k in range(1, pts.size()):
		total += pts[k].distance_to(pts[k - 1])
		acc.append(total)
	var col: Color = st.hot if hot else st.col
	var boost := 1.0 if hot else 0.0
	var wadd := 0.6 if hot else 0.0
	var ws := PackedFloat32Array()
	var cs := PackedColorArray()
	var us := PackedFloat32Array()
	var ucs := PackedColorArray()
	var es := PackedFloat32Array()
	var ecs := PackedColorArray()
	var abs_pts := PackedVector2Array()
	for k in pts.size():
		var t := acc[k] / maxf(total, 0.001)
		abs_pts.append(c + pts[k])
		var w := lerpf(float(st.w0), float(st.w1), t) + wadd
		var al := lerpf(float(st.a0), float(st.a1), t)
		al = lerpf(al, 1.0, 0.55 * boost) if float(st.a1) > 0.3 else lerpf(al, al * 1.6 + 0.1, boost)
		ws.append(w)
		cs.append(Color(col, clampf(al, 0.0, 1.0)))
		if st.has("under"):
			var uw := lerpf(float(st.under_w), float(st.under_w) * 0.75, t) + wadd
			us.append(uw)
			ucs.append(Color(XUiSkin.GOLD if hot else st.under, float(st.under_a) * (1.0 if hot else 1.0)))
		if float(st.edge) > 0.0:
			es.append(w + float(st.edge) * 2.0)
			ecs.append(Color(0, 0, 0, 0.55 * clampf(al / maxf(float(st.a0), 0.01), 0.0, 1.0)))
	var out := {"abs": abs_pts, "col": col, "wadd": wadd, "boost": boost}
	if not es.is_empty():
		out["edge"] = _ribbon_build(abs_pts, es, ecs)
	if not us.is_empty():
		out["under"] = _ribbon_build(abs_pts, us, ucs)
	out["main"] = _ribbon_build(abs_pts, ws, cs)
	return out


func _paint_styled_link(data: Dictionary, st: Dictionary) -> void:
	var abs_pts: PackedVector2Array = data.abs
	var col: Color = data.col
	var wadd: float = data.wadd
	var boost: float = data.boost
	if data.has("edge"):
		_ribbon_draw(data.edge)
	if data.has("under"):
		_ribbon_draw(data.under)
	_ribbon_draw(data.main)
	var head := Color(col, minf(1.0, float(st.a0) + 0.1 * boost + 0.05))
	var d0 := (abs_pts[1] - abs_pts[0]).normalized()
	match String(st.root):
		"diamond":   # 根部小菱印：沿出发方向拉长一点
			var p0 := abs_pts[0] + d0 * 1.0
			var s := 3.2 + wadd * 0.5
			var nn := Vector2(-d0.y, d0.x)
			if float(st.edge) > 0.0 or st.has("under"):
				draw_colored_polygon(PackedVector2Array([p0 - d0 * (s + 1.4), p0 + nn * (s * 0.62 + 1.2), p0 + d0 * (s + 1.4), p0 - nn * (s * 0.62 + 1.2)]), Color(0, 0, 0, 0.55))
			draw_colored_polygon(PackedVector2Array([p0 - d0 * s, p0 + nn * s * 0.62, p0 + d0 * s, p0 - nn * s * 0.62]), head)
		"dot":
			draw_circle(abs_pts[0], 2.6, Color(0, 0, 0, 0.5), true, -1.0, true)
			draw_circle(abs_pts[0], 1.8 + wadd * 0.3, head, true, -1.0, true)
	if String(st.tip) == "dot":
		draw_circle(abs_pts[-1], 1.9 + wadd * 0.3, Color(col, minf(1.0, float(st.a1) + 0.1)), true, -1.0, true)
