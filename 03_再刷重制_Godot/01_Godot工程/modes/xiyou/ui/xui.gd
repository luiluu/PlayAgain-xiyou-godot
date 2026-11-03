class_name XUI
extends RefCounted
## 西游模式共用界面样式，照原版（用户 2026-10-12 要求「界面风格用原版界面风格」）：
## - 窗口：img/system/Window.png 皮肤（XWindowStyle），背景不透明度 192（YEP_CoreEngine Window Opacity）。
## - 菜单场景：img/menus/Background.png 铺底，窗口整体不透明度 30（MOG_MenuBackground），上浮粒子（MOG_MenuParticles）。
## - 字体：当前西游 installDisplayPreferencesRuntime 指定 FZLanTYJW_ZhongCu.TTF（方正兰亭圆简体中粗）；
##   字号 26、行高 36，细黑描边（正式版限制 0.75px；Godot 用 1px）。
## - 颜色：Window.png 右下色板 textColor(n)；下面常量就是该色板的值。
## 按钮照 MV 指令窗口：平时只有文字，选中/悬停时画皮肤里的光标框。

const FONT_SIZE := 26
const LINE_HEIGHT := 36
const MENU_WINDOW_OPACITY := 30

## Window.png textColor(0..31)
const PALETTE := ["ffffff", "20a0d6", "ff784c", "66cc40", "99ccff", "ccc0ff", "ffffa0", "808080",
	"c0c0c0", "2080cc", "ff3810", "00a010", "3e9ade", "a098ff", "ffcc20", "000000",
	"84aaff", "ffff40", "ff2020", "202040", "e08040", "f0c040", "4080c0", "40c0f0",
	"80ff80", "c08080", "8080ff", "ff80ff", "00a040", "00e060", "a060e0", "c080ff"]
const TEXT := Color("ffffff")          # normalColor 0
const SYSTEM := Color("84aaff")        # systemColor 16
const CRISIS := Color("ffff40")        # crisisColor 17
const DEATH := Color("ff2020")         # deathColor 18
const GAUGE_BACK := Color("202040")    # 19
const POWER_UP := Color("80ff80")      # 24
const POWER_DOWN := Color("c08080")    # 25
const MP_COST := Color("40c0f0")       # 23
const TP_COST := Color("00e060")       # 29
const DIM := Color(1, 1, 1, 160.0 / 255.0)   # MV translucentOpacity
const GAUGES := {"hp": [Color("e08040"), Color("f0c040")], "mp": [Color("4080c0"), Color("40c0f0")], "tp": [Color("00a040"), Color("00e060")], "xp": [Color("a060e0"), Color("c080ff")]}

static var _skin: Texture2D


static func text_color(n: int) -> Color:
	return Color(PALETTE[clampi(n, 0, 31)])


static func skin() -> Texture2D:
	if _skin == null:
		var p := XDB.img_path("system", "Window")
		_skin = load(p) if p != "" else null
	return _skin


static func font() -> Font:
	return GameFont.current()


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = FONT_SIZE
	var outline := Color(0, 0, 0, 0.45)
	for type in ["Label", "Button", "RichTextLabel"]:
		t.set_constant("outline_size", type, 1)
		t.set_color("font_outline_color", type, outline)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 6
	empty.content_margin_right = 6
	empty.content_margin_top = 0
	empty.content_margin_bottom = 0
	for state in ["normal", "disabled"]:
		t.set_stylebox(state, "Button", empty)
	for state in ["hover", "pressed", "focus", "hover_pressed"]:
		var c := cursor_style(1.0 if state != "hover" else 0.7)
		t.set_stylebox(state, "Button", c)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, "Button", TEXT)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_font_size("font_size", "Button", FONT_SIZE)
	t.set_constant("h_separation", "Button", 8)
	# 滚动条：细条，颜色取皮肤色板
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(1, 1, 1, 0.45)
	grab.set_corner_radius_all(3)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	var track := StyleBoxEmpty.new()
	for s in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(s, "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", track)
	return t


## 窗口框。opacity 为 MV 的 0~255；菜单场景用 MENU_WINDOW_OPACITY。
static func panel(opacity := 255) -> XWindowStyle:
	var b := XWindowStyle.new()
	b.skin = skin()
	b.opacity = opacity / 255.0
	b.content_margin_left = 14
	b.content_margin_right = 14
	b.content_margin_top = 14
	b.content_margin_bottom = 14
	return b


## 选中光标（Window.png 的光标框）。
static func cursor_style(alpha := 1.0) -> XWindowStyle:
	var c := XWindowStyle.new()
	c.skin = skin()
	c.cursor = true
	c.cursor_alpha = alpha
	c.content_margin_left = 6
	c.content_margin_right = 6
	c.content_margin_top = 0
	c.content_margin_bottom = 0
	return c


## MV Window_Help 等的「暗底」：左右渐隐的半透明黑条（dimColor1 rgba(0,0,0,0.6) → dimColor2 透明）。
static func dimmer(fade_left := true, fade_right := true) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var w := c.size.x
		var h := c.size.y
		var edge := minf(w / 4.0, 160.0)
		var dark := Color(0, 0, 0, 0.6)
		var clear := Color(0, 0, 0, 0)
		var x0 := edge if fade_left else 0.0
		var x1 := w - edge if fade_right else w
		c.draw_rect(Rect2(x0, 0, x1 - x0, h), dark)
		if fade_left:
			c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(edge, 0), Vector2(edge, h), Vector2(0, h)]), PackedColorArray([clear, dark, dark, clear]))
		if fade_right:
			c.draw_polygon(PackedVector2Array([Vector2(x1, 0), Vector2(w, 0), Vector2(w, h), Vector2(x1, h)]), PackedColorArray([dark, clear, clear, dark])))
	c.resized.connect(c.queue_redraw)
	return c


const BLUR_SHADER := """
shader_type canvas_item;
// MV Bitmap.blur：两遍 3×3 平均（边缘复制）＝ 一遍 5×5，权重 [1,2,3,2,1]²/81
void fragment() {
	float w[5] = float[](1.0, 2.0, 3.0, 2.0, 1.0);
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 acc = vec4(0.0);
	for (int i = 0; i < 5; i++) {
		for (int j = 0; j < 5; j++) {
			vec2 uv = clamp(UV + vec2(float(i - 2), float(j - 2)) * px, px * 0.5, vec2(1.0) - px * 0.5);
			acc += texture(TEXTURE, uv) * w[i] * w[j];
		}
	}
	COLOR = vec4(acc.rgb / 81.0, 1.0);
}
"""

## MV SceneManager.snapForBackground 的底图：地图截图按 Bitmap.blur 模糊后铺满 1280×720（传送页、挂机设置页）。
static func blurred_background(tex: Texture2D) -> TextureRect:
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.texture = tex
	bg.size = Vector2(1280, 720)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = BLUR_SHADER
	bg.material = mat
	return bg

## 菜单底图（MOG_MenuBackground：Background.png 铺满）＋上浮粒子（MOG_MenuParticles：15 个，向上飘、加算混合）。
static func menu_background(parent: Control) -> void:
	var p := XDB.img_path("menus", "Background")
	if p != "":
		var t := TextureRect.new()
		t.texture = load(p)
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(t)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.05, 0.05, 0.07)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		parent.add_child(bg)
	var pp := XDB.img_path("menus", "Particles")
	if pp != "":
		var vs := parent.get_viewport_rect().size if parent.is_inside_tree() else Vector2(1280, 720)
		var parts := CPUParticles2D.new()
		parts.texture = load(pp)
		parts.amount = 15
		parts.lifetime = 9.0
		parts.preprocess = 9.0
		parts.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		parts.emission_rect_extents = Vector2(vs.x / 2.0, 10)
		parts.position = Vector2(vs.x / 2.0, vs.y + 20)
		parts.direction = Vector2(0, -1)
		parts.spread = 8.0
		parts.gravity = Vector2.ZERO
		parts.initial_velocity_min = 60.0
		parts.initial_velocity_max = 110.0
		parts.angular_velocity_min = -60.0
		parts.angular_velocity_max = 60.0
		parts.scale_amount_min = 0.6
		parts.scale_amount_max = 1.2
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		parts.material = mat
		parent.add_child(parts)


static func label(text: String, size := FONT_SIZE, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, min_h := 44) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = min_h
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


## 头像：faces 图按 4 列排列，每格 144×144。
static func face_texture(face_name: String, index: int) -> AtlasTexture:
	var p := XDB.img_path("faces", face_name) if face_name != "" else ""
	if p == "":
		return null
	var a := AtlasTexture.new()
	a.atlas = load(p)
	# MV 头像每格固定 144×144（ImageManager.faceWidth），图可能只有一两格
	a.region = Rect2((index % 4) * 144, floori(index / 4.0) * 144, 144, 144)
	return a


## 图标：正式版 IconSet 由 krz_iconsetimprove 拆成 IconSet_1..4（每张 512×3200、16 列 32×32，即 1600 个）。
## 用分图而不是 512×12800 的整图，避免手机 GPU 纹理尺寸上限。
static func icon_texture(index: int) -> AtlasTexture:
	if index <= 0:
		return null
	if index >= XCat.ICON and index < XCat.ICON + 9:  # 小猫剑圣自带的图标条（CatSwordSaint_Icons，9 格横排）
		return XCat.icon_texture(index)
	if XYunshang.icon_slot(index) >= 0:  # 云裳的 HD 图集（技能、天衣、织神天梭、号角、天丝）
		return XYunshang.icon_texture(index)
	if index == XDemonCrown.ICON:  # 魔冠自带的大图（CodexQualityIcons demonCrownArt）
		return XDemonCrown.icon_texture()
	var sheet := floori(index / 1600.0)
	var p := XDB.img_path("system", "IconSet_%d" % (sheet + 1))
	if p == "":
		return null
	var local := index % 1600
	var a := AtlasTexture.new()
	a.atlas = load(p)
	a.region = Rect2((local % 16) * 32, floori(local / 16.0) * 32, 32, 32)
	return a


## MV 量条：底色 gaugeBackColor，填充从 color1 到 color2 横向渐变；kind = "hp" / "mp" / "tp"。
## YEP Gauge Outline：底条比填充多 1px 边。
static func gauge(value: float, max_value: float, kind := "hp", w := 160.0, h := 6.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h + 2)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cols: Array = GAUGES.get(kind, GAUGES.hp)
	c.draw.connect(func():
		c.draw_rect(Rect2(Vector2.ZERO, c.size), GAUGE_BACK)
		var fw := (c.size.x - 2.0) * clampf(value / maxf(max_value, 1.0), 0.0, 1.0)
		if fw > 0.0:
			var r := Rect2(1, 1, fw, c.size.y - 2.0)
			c.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
				PackedColorArray([cols[0], cols[1], cols[1], cols[0]])))
	return c


## MV drawActorHp 的样式：左侧系统色「HP」，右侧数值（濒危黄、死亡红），下方量条。
static func param_gauge(caption: String, value: float, max_value: float, kind: String, w := 180.0, size := 20) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(w, size + 10)
	var g := gauge(value, max_value, kind, w, 6)
	g.position = Vector2(0, size + 2)
	g.size = Vector2(w, 8)
	box.add_child(g)
	var cap := label(caption, size, SYSTEM)
	cap.position = Vector2(0, -4)
	box.add_child(cap)
	var col := TEXT
	if kind == "hp":
		col = DEATH if value <= 0.0 else (CRISIS if value < max_value / 4.0 else TEXT)
	var num := label("%d / %d" % [value, max_value] if w >= 150 else "%d" % value, size, col)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.position = Vector2(0, -4)
	num.size = Vector2(w, size + 4)
	box.add_child(num)
	return box
