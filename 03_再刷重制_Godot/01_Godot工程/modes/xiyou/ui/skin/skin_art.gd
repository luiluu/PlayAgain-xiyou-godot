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
	return t


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
		var s := StyleBoxTexture.new()
		s.texture = part("smoke_secondary_128x64" if short else "smoke_reading_128x128")
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			s.set_texture_margin(side, SMOKE_MARGIN)
			s.set_content_margin(side, XUiSkin.PAD)
		_styles[key] = s
	return _styles[key]


## 在画布项上画烟色面板（MV 窗口框用）；a 是整体透明度
static func draw_smoke(ci: RID, rect: Rect2, a := 1.0) -> void:
	var short := rect.size.y < SMOKE_SHORT
	var tex := part("smoke_secondary_128x64" if short else "smoke_reading_128x128")
	var src := Rect2(Vector2.ZERO, tex.get_size())
	var m := float(SMOKE_MARGIN)
	var mx := minf(m, rect.size.x / 2.0)
	var my := minf(m, rect.size.y / 2.0)
	RenderingServer.canvas_item_add_nine_patch(ci, rect, src, tex.get_rid(), Vector2(mx, my), Vector2(mx, my),
		RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, Color(1, 1, 1, a))


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
	var w := part(wash)
	RenderingServer.canvas_item_add_texture_rect(ci, r, w.get_rid(), false, mod)
	if state == XUiSkin.SelState.HOVER:
		return
	var ar := part("selection_arrow_7x9")
	RenderingServer.canvas_item_add_texture_rect(ci, arrow_rect(r), ar.get_rid(), false, Color(1, 1, 1, alpha))


## 页签选中（tab_selected_assembly 的几何：箭头 1×、离页签底 8px）
static func draw_tab(ci: RID, rect: Rect2) -> void:
	var w := part("tab_selected_wash_64x24")
	RenderingServer.canvas_item_add_texture_rect(ci, rect, w.get_rid(), false)
	RenderingServer.canvas_item_add_texture_rect(ci, arrow_rect(rect, 1), part("selection_arrow_7x9").get_rid(), false)


## 环高亮：图标边长 px（64 或 32）→ 外圈贴图和它的矩形（中心对齐，整数像素）
static func halo_rect(center: Vector2, icon_px: float) -> Rect2:
	var n := 96.0 if icon_px > 48.0 else 48.0
	return Rect2((center - Vector2(n, n) / 2.0).round(), Vector2(n, n))


static func halo_texture(icon_px: float) -> Texture2D:
	return part("ring_selected_halo_96x96" if icon_px > 48.0 else "ring_selected_halo_48x48")
