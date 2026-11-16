class_name XSkinArt
extends RefCounted
## 【cc·天启篇·未经审查】新界面第一期正式美术（小o 交付 phase01_final，提交 ff5a9e92c；Kyo 11-15 看过审图页：正式美术通过）。
## 素材在 content/ui_skin/phase01/：bg/ 五条线×三比例背景（1280×720／1600×720／960×720），parts/ 原生像素组件，safe_areas.json 安全区。
## 只在新皮肤开着时生效（XUiSkin.on()，调用方先问）；四个开关各自回退，全关＝第一期之前的程序画法（cc/ui-skin-close）。
##
## - BG（O-待定，背景）：菜单底换成当前骑士线（死亡／战争／饥荒／瘟疫）的背景；没选线、不在能玩的线上、在大厅（Map004）用通用版。
##   按视口比例选最接近的那张（≤1.56 用 4:3、<2.0 用 16:9、其余 20:9），同高铺满、居中、最近邻；火星照旧叠在上面。
##   注意：4:3 屏现在由 XSkinLayout.NARROW_LETTERBOX（O-483）锁 1280×720 视口、上下留黑边，所以 4:3 屏实际用 16:9 那张；
##   960×720 那张只在视口真是 4:3 时（NARROW_LETTERBOX 关掉、或别的页面不锁视口）用上。
## - PANEL（O-待定，D50 R2 无框烟色面板）：程序画的黑面板（圆角＋细线＋投影）换成 smoke_reading 九宫格（边距 16）；
##   矮的（高 < 80）用 smoke_secondary；投影去掉（烟底自己渐隐，不是描边面板）。
## - SELECT（O-待定，D51 选中条）：整行实心暗红底＋朱红框＋左光标 换成 selection_wash 渐隐暗红底（铺满行）＋左侧外置小箭头
##   （selection_arrow，行高 ≥ 40 用 2×、否则 1×，最近邻；箭头右边离红底 8px 透明间隔，箭头不进红底）；
##   页签选中用 tab_selected_assembly 的同一套几何（箭头＋tab_selected_wash，箭头在页签左外）。
## - HALO（O-待定，环高亮）：主菜单环上当前组的 u4 图标加 ring_selected_halo 外圈（64 图标配 96 圈，32 配 48，中心对齐）。

static var BG := true
static var PANEL := true
static var SELECT := true
static var HALO := true
## READ（O-待定，可读性，Kyo 11-15 看审图：字压在齿轮、塔楼、红裂纹上看不清）：背景开着时
##   1) 背景上加压暗层：整体压 28%、顶栏（页名、页签、货币）从上往下渐隐的黑、底栏（按键提示）从下往上渐隐的黑、左块环区一团径向暗角；
##   2) 直接放在背景上的次要字（页签、货币名、按键提示、环上的项名）从次要灰 #a8aaaf 提到暖骨灰 #d2ccc2；
##   3) 这些字加 3px 深色描边（READ_OUTLINE）。面板里的字不动（烟底本来就够暗）。false＝不压暗、字照旧。
static var READ := true
const READ_DIM := 0.28
const READ_TOP_H := 132.0
const READ_TOP_A := 0.85
const READ_BOTTOM_H := 112.0
const READ_BOTTOM_A := 0.88
const READ_RING_A := 0.62
const READ_TEXT_2 := Color("d2ccc2")
const READ_OUTLINE := 3
const READ_OUTLINE_C := Color(0.0, 0.0, 0.0, 0.85)

const DIR := "res://content/ui_skin/phase01/"
const ROUTES := ["general", "death", "war", "famine", "plague"]
const LOBBY_MAP := 4
## 比例键 → 背景尺寸
const SIZES := {"4x3": Vector2i(960, 720), "16x9": Vector2i(1280, 720), "20x9": Vector2i(1600, 720)}
## 选中条几何（asset_map.json selection_layout，1× 下）：箭头 7×9、离红底至少 8px
const ARROW_SIZE := Vector2(7, 9)
const ARROW_GAP := 8.0
const ARROW_2X_ROW := 40.0     # 行高到这么高用 2× 箭头
const SMOKE_MARGIN := 16
const SMOKE_SHORT := 80.0      # 比这矮的面板用 secondary 烟底
const HOVER_ALPHA := 0.45
const PRESS_DARK := 0.42

static var _tex := {}
static var _styles := {}
static var _safe := {}
static var _scaled := {}
const SMOKE_ALPHA := 0.85
const SMOKE_ALPHA_SHORT := 0.88
const GRAIN_ALPHA := 0.4
const GRAIN_FADE := 24.0
## 烟底面板左右内容边距（文字离渐隐边再 8：16＋8）
const SMOKE_CONTENT_X := 24
## 正式背景上加法火星减半（背景图里已经烘了余烬，小A核 P2-3②）
const EMBER_ALPHA := 0.55


## ---- 背景 ----

## 当前该用哪条线的背景：天启篇能玩的那条线；没选线、大厅、不是天启篇存档 → general
static func route(s: XState = null) -> String:
	if s == null:
		s = XState.current
	if s == null or s.map_id == LOBBY_MAP:
		return "general"
	var key := XTianqiLine.current(s)
	return key if ROUTES.has(key) else "general"


## 视口大小 → 比例键（取最接近的那张：4:3＝1.333、16:9＝1.778、20:9＝2.222，按中点分界）
static func aspect_key(view: Vector2) -> String:
	if view.y <= 0.0:
		return "16x9"
	var r := view.x / view.y
	if r < (4.0 / 3.0 + 16.0 / 9.0) / 2.0:
		return "4x3"
	if r < (16.0 / 9.0 + 20.0 / 9.0) / 2.0:
		return "16x9"
	return "20x9"


static func bg_path(rt: String, key: String) -> String:
	var sz: Vector2i = SIZES.get(key, SIZES["16x9"])
	return "%sbg/%s_%dx%d.png" % [DIR, rt, sz.x, sz.y]


static func bg_texture(rt: String, view: Vector2) -> Texture2D:
	return _load(bg_path(rt, aspect_key(view)))


## 安全区（safe_areas.json，按比例键）：{central_low_detail_rect: Rect2, side_art_anchors: [Rect2…], eclipse_anchor: Rect2}
static func safe_area(key: String) -> Dictionary:
	if _safe.is_empty():
		var f := FileAccess.open(DIR + "safe_areas.json", FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f != null else null
		_safe = d if d is Dictionary else {}
	var sz: Vector2i = SIZES.get(key, SIZES["16x9"])
	var raw: Dictionary = _safe.get("%dx%d" % [sz.x, sz.y], {})
	if raw.is_empty():
		return {}
	var rr := func(a): return Rect2(a[0], a[1], a[2], a[3])
	return {"central_low_detail_rect": rr.call(raw.central_low_detail_rect),
		"side_art_anchors": (raw.side_art_anchors as Array).map(rr), "eclipse_anchor": rr.call(raw.eclipse_anchor)}


## 菜单底的背景层（XUiSkin.menu_backdrop 在 BG 开着时调）：按线、按视口比例换图；视口改大小时重选
static func add_backdrop(root: Control) -> TextureRect:
	var t := TextureRect.new()
	t.name = "ArtBackground"
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(t)
	var pick := func():   # 铺满父节点：视口改大小 → 这层跟着改大小 → resized 重选
		if not is_instance_valid(t):
			return
		var vs := t.size
		if vs.x <= 0.0 or vs.y <= 0.0:
			vs = t.get_viewport_rect().size if t.is_inside_tree() else Vector2(1280, 720)
		var rt := route()
		t.texture = bg_texture(rt, vs)
		t.set_meta("route", rt)
		t.set_meta("aspect", aspect_key(vs))
	pick.call()
	t.resized.connect(pick)
	if READ:
		_add_scrims(root)
	return t


## 可读性压暗层（READ）：整体压暗＋顶栏、底栏渐隐黑＋左块环区径向暗角；都不收鼠标
static func _add_scrims(root: Control) -> void:
	var dim := ColorRect.new()
	dim.name = "ReadDim"
	dim.color = Color(0, 0, 0, READ_DIM)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var top := _vgrad("ReadTop", READ_TOP_A, 0.0)
	top.anchor_bottom = 0.0
	top.offset_bottom = READ_TOP_H
	root.add_child(top)
	var bot := _vgrad("ReadBottom", 0.0, READ_BOTTOM_A)
	bot.anchor_top = 1.0
	bot.offset_top = -READ_BOTTOM_H
	root.add_child(bot)
	# 环区：左块中心（16:9 约 x=232、y=380）一团椭圆暗角，宽 640、高 600，贴左边跟着安全边距走
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, READ_RING_A), Color(0, 0, 0, READ_RING_A * 0.6), Color(0, 0, 0, 0)])
	var rad := GradientTexture2D.new()
	rad.gradient = g
	rad.width = 128
	rad.height = 128
	rad.fill = GradientTexture2D.FILL_RADIAL
	rad.fill_from = Vector2(0.5, 0.5)
	rad.fill_to = Vector2(1.0, 0.5)
	var ring := TextureRect.new()
	ring.name = "ReadRing"
	ring.texture = rad
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.stretch_mode = TextureRect.STRETCH_SCALE
	ring.anchor_left = 0.0
	ring.anchor_right = 0.0
	ring.anchor_top = 0.5
	ring.anchor_bottom = 0.5
	ring.offset_left = -88.0
	ring.offset_right = 552.0
	ring.offset_top = -280.0
	ring.offset_bottom = 320.0
	root.add_child(ring)


static func _vgrad(n: String, a_top: float, a_bottom: float) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, a_top), Color(0, 0, 0, a_bottom)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 4
	gt.height = 64
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var t := TextureRect.new()
	t.name = n
	t.texture = gt
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return t


## 可读性开着（新皮肤开、正式背景开、READ 开）
static func read_on() -> bool:
	return READ and BG and XUiSkin.on()


## 直接放在背景上的次要字的颜色
static func bg_text_2() -> Color:
	return READ_TEXT_2 if read_on() else XUiSkin.TEXT_2


## 直接放在背景上的字：READ 时先描 3px 深色边再写
static func bg_string(ci: CanvasItem, font: Font, pos: Vector2, text: String, fs: int, color: Color, width := -1.0) -> void:
	if read_on():
		ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, fs, READ_OUTLINE, READ_OUTLINE_C)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, fs, color)


## ---- 组件 ----

static func part(name: String) -> Texture2D:
	return _load(DIR + "parts/" + name + ".png")


static func _load(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func panel_on() -> bool:
	return PANEL and part("smoke_reading_128x128") != null


static func select_on() -> bool:
	return SELECT and part("selection_wash_128x24") != null and part("selection_arrow_7x9") != null


## 烟色面板的 StyleBox（XUiSkin.panel_style 在 PANEL 开着时给这个）
static func smoke_style(short := false) -> StyleBox:
	var key := "smoke_short" if short else "smoke"
	if not _styles.has(key):
		var st := SmokeStyle.new()
		st.short = short
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			st.set_content_margin(side, SMOKE_CONTENT_X if side in [SIDE_LEFT, SIDE_RIGHT] else XUiSkin.PAD)
		_styles[key] = st
	return _styles[key]


## 烟色面板的 StyleBox：画法同 draw_smoke（透景、颗粒）；short＝强制用 secondary
class SmokeStyle extends StyleBox:
	var short := false

	func _draw(ci: RID, rect: Rect2) -> void:
		XSkinArt.draw_smoke(ci, rect, 1.0, short)


## 在画布项上画烟色面板；a 是整体透明度。小A核 P2-3：烟底乘 0.85（secondary 0.88）透一点背景；
## 大面板（宽 > 160、高 > 120）内缩 16 叠一层 smoke_grain_tile 颗粒（预先按最近邻铺好的整图，1:1 画，不靠纹理重复）
static func draw_smoke(ci: RID, rect: Rect2, a := 1.0, force_short := false) -> void:
	var short := force_short or rect.size.y < SMOKE_SHORT
	var tex := part("smoke_secondary_128x64" if short else "smoke_reading_128x128")
	var src := Rect2(Vector2.ZERO, tex.get_size())
	var m := float(SMOKE_MARGIN)
	var mx := minf(m, rect.size.x / 2.0)
	var my := minf(m, rect.size.y / 2.0)
	var k := SMOKE_ALPHA_SHORT if short else SMOKE_ALPHA
	RenderingServer.canvas_item_add_nine_patch(ci, rect, src, tex.get_rid(), Vector2(mx, my), Vector2(mx, my),
		RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, Color(1, 1, 1, a * k))
	if not short and rect.size.x > 160.0 and rect.size.y > 120.0:
		var inner := Rect2(rect.position.round() + Vector2(m, m), (rect.size - Vector2(m, m) * 2.0).round())
		var g := grain_texture(Vector2i(inner.size))
		if g != null:
			RenderingServer.canvas_item_add_texture_rect(ci, inner, g.get_rid(), false, Color(1, 1, 1, a * GRAIN_ALPHA))


## 颗粒底纹铺成 size 大的整图（按 32 取整、缓存）
static func grain_texture(size: Vector2i) -> Texture2D:
	var tile := part("smoke_grain_tile_32x32")
	if tile == null or size.x <= 0 or size.y <= 0:
		return null
	var key := "grain_%d_%d" % [size.x, size.y]
	if not _scaled.has(key):
		var src := tile.get_image()
		src.decompress()
		var img := Image.create(size.x, size.y, false, src.get_format())
		for y in range(0, size.y, src.get_height()):
			for x in range(0, size.x, src.get_width()):
				img.blit_rect(src, Rect2i(0, 0, mini(src.get_width(), size.x - x), mini(src.get_height(), size.y - y)), Vector2i(x, y))
		# 四边 GRAIN_FADE 像素内 alpha 渐到 0，颗粒层不出硬边
		img.convert(Image.FORMAT_RGBA8)
		for y in size.y:
			var fy := clampf(minf(y, size.y - 1 - y) / GRAIN_FADE, 0.0, 1.0)
			for x in size.x:
				var f := minf(fy, clampf(minf(x, size.x - 1 - x) / GRAIN_FADE, 0.0, 1.0))
				if f < 1.0:
					var c := img.get_pixel(x, y)
					c.a *= f * f * (3.0 - 2.0 * f)
					img.set_pixel(x, y, c)
		_cache_scaled(key, ImageTexture.create_from_image(img))
	return _scaled[key]


## 像素切图按最近邻预先放大到 size（缓存）。小A核 P2-2：控件本身是线性过滤（字要平滑），像素件预先放大后按 1:1、整数像素画，
## 不论画在哪个画布项上都是硬边（箭头、Bayer 抖动横幅、助力签、七芒印）
static func scaled(name: String, size: Vector2i) -> Texture2D:
	var t := part(name)
	if t == null or size.x <= 0 or size.y <= 0:
		return null
	if Vector2i(t.get_size()) == size:
		return t
	var key := "%s_%d_%d" % [name, size.x, size.y]
	if not _scaled.has(key):
		var src := t.get_image()
		src.decompress()
		_cache_scaled(key, ImageTexture.create_from_image(nearest(src, size)))
	return _scaled[key]


## 最近邻放大：目标像素 (x, y) 取原图 (x·w／W, y·h／H) 向下取整那一格（整数倍时正好是 k×k 的块；Image.resize 的最近邻不保证）
static func nearest(src: Image, size: Vector2i) -> Image:
	var img := Image.create(size.x, size.y, false, src.get_format())
	var sw := src.get_width()
	var sh := src.get_height()
	for y in size.y:
		var sy := mini(y * sh / size.y, sh - 1)
		for x in size.x:
			img.set_pixel(x, y, src.get_pixel(mini(x * sw / size.x, sw - 1), sy))
	return img


static func _cache_scaled(key: String, t: Texture2D) -> void:
	if _scaled.size() >= 96:   # 滑动途中尺寸会变：缓存满了整个清掉重来
		_scaled.clear()
	_scaled[key] = t


## 箭头倍率：行高 ≥ 40 用 2×，否则 1×
static func arrow_scale(row_h: float) -> int:
	return 2 if row_h >= ARROW_2X_ROW else 1


## 外置箭头的矩形：右边离 rect 左边 ARROW_GAP，竖直居中，整数像素
static func arrow_rect(rect: Rect2, k := -1) -> Rect2:
	if k < 1:
		k = arrow_scale(rect.size.y)
	var sz := ARROW_SIZE * k
	return Rect2(Vector2(rect.position.x - ARROW_GAP - sz.x, rect.position.y + (rect.size.y - sz.y) / 2.0).round(), sz)


## 选中条（D51）：渐隐暗红底铺满行＋左外小箭头。state 同 XUiSkin.SelState（悬停减淡、不画箭头；按下压暗、下沉 1px）。
## wash：行用 selection_wash，页签用 tab_selected_wash
static func draw_select(ci: RID, rect: Rect2, alpha := 1.0, state := 0, wash := "selection_wash_128x24") -> void:
	var r := rect
	var a := alpha * (HOVER_ALPHA if state == XUiSkin.SelState.HOVER else 1.0)
	var mod := Color(1, 1, 1, a)
	if state == XUiSkin.SelState.PRESSED:
		r.position.y += 1.0
		mod = Color(1.0 - PRESS_DARK, 1.0 - PRESS_DARK, 1.0 - PRESS_DARK, a)
	r = Rect2(r.position.round(), r.size.round())
	var w := scaled(wash, Vector2i(wash_w(r.size.x), int(r.size.y)))
	RenderingServer.canvas_item_add_texture_rect(ci, r, w.get_rid(), false, mod)
	if state == XUiSkin.SelState.HOVER:
		return
	var ar_r := arrow_rect(r)
	var ar := scaled("selection_arrow_7x9", Vector2i(ar_r.size))
	RenderingServer.canvas_item_add_texture_rect(ci, ar_r, ar.get_rid(), false, Color(1, 1, 1, alpha))


## 横幅预放大的宽：按 4 取整（滑动途中不每帧新建贴图），画时只差 0～2px 的拉伸
static func wash_w(w: float) -> int:
	return maxi(4, int(roundf(w / 4.0)) * 4)


## 页签选中（tab_selected_assembly 的几何：箭头 1×、离页签底 8px）
static func draw_tab(ci: RID, rect: Rect2) -> void:
	var r := Rect2(rect.position.round(), rect.size.round())
	var w := scaled("tab_selected_wash_64x24", Vector2i(wash_w(r.size.x), int(r.size.y)))
	RenderingServer.canvas_item_add_texture_rect(ci, r, w.get_rid(), false)
	RenderingServer.canvas_item_add_texture_rect(ci, arrow_rect(r, 1), part("selection_arrow_7x9").get_rid(), false)


## 助力位卡（小A核 P2-3：去旧金描边）：smoke_secondary 0.72＋七芒暗印（64，原 alpha 最高 28，不再减透明）＋helper_tag 2×（64×24）
static func draw_helper(ci: RID, box: Rect2) -> void:
	draw_smoke(ci, box, 0.72, true)
	var seal := scaled("seven_seal_128x128", Vector2i(64, 64))
	if seal != null:
		var sr := Rect2(Vector2(box.end.x - 64 - 12, box.position.y + (box.size.y - 64) / 2.0).round(), Vector2(64, 64))
		RenderingServer.canvas_item_add_texture_rect(ci, sr, seal.get_rid(), false)
	var tag := scaled("helper_tag_32x12", Vector2i(64, 24))
	if tag != null:
		RenderingServer.canvas_item_add_texture_rect(ci, helper_tag_rect(box), tag.get_rid(), false)


## 助力签的矩形（卡内右上，2× 64×24）
static func helper_tag_rect(box: Rect2) -> Rect2:
	return Rect2(Vector2(box.end.x - 64 - 4, box.position.y + 4).round(), Vector2(64, 24))


## 环高亮：图标边长 px（64 或 32）→ 外圈贴图和它的矩形（中心对齐，整数像素）
static func halo_rect(center: Vector2, icon_px: float) -> Rect2:
	var n := 96.0 if icon_px > 48.0 else 48.0
	return Rect2((center - Vector2(n, n) / 2.0).round(), Vector2(n, n))


static func halo_texture(icon_px: float) -> Texture2D:
	return part("ring_selected_halo_96x96" if icon_px > 48.0 else "ring_selected_halo_48x48")
