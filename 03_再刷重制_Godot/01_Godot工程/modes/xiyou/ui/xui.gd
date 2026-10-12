class_name XUI
extends RefCounted
## 西游模式共用的界面样式：深青底、金边，与入口菜单一致；按钮高度照顾触屏。

const BG := Color(0.055, 0.11, 0.125, 0.94)
const BG_SOFT := Color(0.09, 0.17, 0.19, 0.96)
const GOLD := Color("b69d6c")
const TEXT := Color("f0e5cc")
const DIM := Color("93a8a8")
const HP := Color("d8664f")
const MP := Color("4f8fd8")


static func theme() -> Theme:
	var t: Theme = load("res://core/menu_ui.gd").make_theme()
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var b := StyleBoxFlat.new()
		b.bg_color = {"normal": Color("1b3439"), "hover": Color("27494e"), "pressed": Color("12282c"), "focus": Color("27494e"), "disabled": Color("142427")}[state]
		b.border_color = GOLD if state != "disabled" else Color("3b4b4b")
		b.set_border_width_all(2 if state == "focus" else 1)
		b.set_corner_radius_all(6)
		b.content_margin_left = 14
		b.content_margin_right = 14
		b.content_margin_top = 8
		b.content_margin_bottom = 8
		t.set_stylebox(state, "Button", b)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color("6f8486"))
	t.set_font_size("font_size", "Button", 22)
	return t


static func panel(soft := false) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = BG_SOFT if soft else BG
	b.border_color = GOLD.darkened(0.25)
	b.set_border_width_all(1)
	b.set_corner_radius_all(10)
	b.content_margin_left = 18
	b.content_margin_right = 18
	b.content_margin_top = 14
	b.content_margin_bottom = 14
	return b


static func label(text: String, size := 20, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, min_h := 56) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = min_h
	return b


## 头像：faces 图每张 4×2 个，144×144。
static func face_texture(face_name: String, index: int) -> AtlasTexture:
	var p := XDB.img_path("faces", face_name) if face_name != "" else ""
	if p == "":
		return null
	var a := AtlasTexture.new()
	a.atlas = load(p)
	var w: float = a.atlas.get_width() / 4.0
	var h: float = a.atlas.get_height() / 2.0
	a.region = Rect2((index % 4) * w, floori(index / 4.0) * h, w, h)
	return a


## 图标：正式版 IconSet 由 krz_iconsetimprove 拆成 IconSet_1..4（每张 512×3200、16 列 32×32，即 1600 个）。
## 用分图而不是 512×12800 的整图，避免手机 GPU 纹理尺寸上限。
static func icon_texture(index: int) -> AtlasTexture:
	if index <= 0:
		return null
	var sheet := floori(index / 1600.0)
	var p := XDB.img_path("system", "IconSet_%d" % (sheet + 1))
	if p == "":
		return null
	var local := index % 1600
	var a := AtlasTexture.new()
	a.atlas = load(p)
	a.region = Rect2((local % 16) * 32, floori(local / 16.0) * 32, 32, 32)
	return a


static func gauge(value: float, max_value: float, color: Color, w := 160.0, h := 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.draw.connect(func():
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0, 0, 0, 0.45))
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(c.size.x * clampf(value / maxf(max_value, 1.0), 0.0, 1.0), c.size.y)), color))
	return c
