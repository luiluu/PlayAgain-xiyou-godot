class_name XPowerNotice
extends CanvasLayer
## 装备变更后的战力提示（installCombatPowerRuntime notify，正式 v0.28 运行时读数；外观经 installGamePanelTheme 覆盖）：
## - 触发：装备页「装备」（候选确定，含卸载）与「清空」，身上装备确实变了才弹（wornKey 比较）；关掉「战力显示与估算」时不弹。
##   变化前取缓存战力，变化后强制重算（actorPower(a, true)）。
## - 文字两行：「名字 · 战力提升 +N」（下降「战力下降 -N」、相等「战力变化 0」）／「当前总战力：N」，数值用 XPower.format。
## - 网页层浮框，盖在一切之上、换场景不消失：贴画面右 24、下 36；1 像素边 rgba(255,255,255,0.55)、圆角 8、底色 #16161f、
##   内边距上下 14 左右 22；金字 #ffd373、20 号 sans-serif（不是游戏字体），行高 28，四向 1 像素黑描边；阴影 (0,4) 模糊 24 rgba(0,0,0,0.53)。
##   正式版读数：「狗逍遥 · 战力下降 -97 / 当前总战力：368」框 (1004.98, 598, 251.02, 86)，首行文字 (1027.98, 613)。
## - 再次触发时换文字、重新计时；显示 3.5 秒后直接消失（没有淡出）。

const RIGHT := 24.0
const BOTTOM := 36.0
const PAD := Vector2(22, 14)
const BORDER := 1
const LINE_H := 28.0
const FONT_SIZE := 20
const GOLD := Color("#ffd373")
const BACK := Color("#16161f")
const EDGE := Color(1, 1, 1, 0.55)
const SHADOW := Color(0, 0, 0, 0x88 / 255.0)
const TIMEOUT := 3.5

## 最近一次变化 {actorId, before, after, delta}（CodexCombatPower.lastChange，测试核对用）
static var last_change := {}
var box: NoticeBox
var timer: SceneTreeTimer


static func delta(v: float) -> String:
	return ("+" if v > 0 else "") + XPower.format(v)


static func message(a: XActor, before: float, after: float) -> String:
	var change := after - before
	var verb := "战力提升 " if change > 0 else ("战力下降 " if change < 0 else "战力变化 ")
	return a.display_name() + " · " + verb + delta(change) + "\n当前总战力：" + XPower.format(after)


## 装备页换装：change 前后身上装备不同才提示
static func around(a: XActor, change: Callable) -> void:
	if not XPower.ui_enabled():
		change.call()
		return
	var worn := a.equips.duplicate()
	var before := float(XPower.actor(a).total)
	change.call()
	if _same(worn, a.equips):
		return
	notify(a, before, float(XPower.actor(a, true).total))


static func _same(x: Array, y: Array) -> bool:
	if x.size() != y.size():
		return false
	for i in range(x.size()):
		if not is_same(x[i], y[i]):
			return false
	return true


static func notify(a: XActor, before: float, after: float) -> void:
	if not XPower.ui_enabled():
		return
	last_change = {"actorId": a.actor_id, "before": before, "after": after, "delta": after - before}
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var layer := tree.root.get_node_or_null("XPowerNotice") as XPowerNotice
	if layer == null:
		layer = XPowerNotice.new()
		layer.name = "XPowerNotice"
		tree.root.add_child(layer)
	layer.show_text(message(a, before, after))


## 当前显示的提示（没有显示时为空）
static func current() -> XPowerNotice:
	var tree := Engine.get_main_loop() as SceneTree
	var layer := tree.root.get_node_or_null("XPowerNotice") as XPowerNotice if tree else null
	return layer if layer != null and layer.box.visible else null


static func font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["sans-serif"])
	return f


func _init() -> void:
	layer = 100
	box = NoticeBox.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.visible = false
	add_child(box)


func show_text(text: String) -> void:
	var on := XUiSkin.on()
	box.skinned = on
	box.text = text
	var bf := XUiSkin.font("body") if on else box.font
	var nf := XUiSkin.font("num") if on else box.font
	var lines := text.split("\n")
	var pad := Vector2(20, 14) if on else PAD
	var lh := 26.0 if on else LINE_H
	var w := 0.0
	if on:
		for i in lines.size():
			var ln := lines[i]
			if i == 0:
				var idx := maxi(ln.rfind(" "), -1)
				if idx > 0:
					w = maxf(w, bf.get_string_size(ln.substr(0, idx + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + nf.get_string_size(ln.substr(idx + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x)
					continue
			elif i == 1:
				var cidx := ln.find("：")
				if cidx >= 0:
					w = maxf(w, bf.get_string_size(ln.substr(0, cidx + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + nf.get_string_size(ln.substr(cidx + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x)
					continue
			w = maxf(w, bf.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x)
	else:
		for line in lines:
			w = maxf(w, box.font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	var bdr := 0.0 if on else float(BORDER)
	var outer := Vector2(ceilf(w) + pad.x * 2 + bdr * 2, lh * lines.size() + pad.y * 2 + bdr * 2)
	var vs := get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280, 720)
	box.size = outer
	var right_m := XSkinLayout.margin_for(vs.x) if on else RIGHT
	var bottom_m := 44.0 if on else BOTTOM
	box.position = Vector2(vs.x - right_m - outer.x, vs.y - bottom_m - outer.y)
	box.visible = true
	box.queue_redraw()
	var t := get_tree().create_timer(TIMEOUT)
	timer = t
	t.timeout.connect(func(): if timer == t: box.visible = false)


## 浮框本体：自己画字，每行固定 28 高（CSS line-height；Label 会被中文后备字体撑高）
class NoticeBox extends Control:
	var text := ""
	var skinned := false
	var font: Font = XPowerNotice.font()
	var style := StyleBoxFlat.new()

	func _init() -> void:
		style.bg_color = BACK
		style.border_color = EDGE
		style.set_border_width_all(BORDER)
		style.set_corner_radius_all(8)
		style.shadow_color = SHADOW
		style.shadow_size = 12
		style.shadow_offset = Vector2(0, 4)

	func _draw() -> void:
		if skinned:
			draw_style_box(XUiSkin.shadow_style(), Rect2(Vector2.ZERO, size))
			draw_style_box(XUiSkin.panel_style(), Rect2(Vector2.ZERO, size))
			var bf := XUiSkin.font("body")
			var nf := XUiSkin.font("num")
			var pad := Vector2(20, 14)
			var lh := 26.0
			var lines := text.split("\n")
			for i in range(lines.size()):
				var ln := lines[i]
				var cy := roundf(pad.y + lh * i + lh / 2.0)
				if i == 0:
					var sp := ln.rfind(" ")
					if sp > 0:
						var left_s := ln.substr(0, sp + 1)
						var right_s := ln.substr(sp + 1)
						var col := XUiSkin.UP if right_s.begins_with("+") else (XUiSkin.DOWN if right_s.begins_with("-") else XUiSkin.TEXT_2)
						XUiSkin.ds(self, bf, Vector2(pad.x, cy + 18 * 0.36), left_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, XUiSkin.TEXT)
						var lx := bf.get_string_size(left_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
						XUiSkin.ds(self, nf, Vector2(pad.x + lx, cy + 20 * 0.36), right_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
						continue
				elif i == 1:
					var cidx := ln.find("：")
					if cidx >= 0:
						var left_s := ln.substr(0, cidx + 1)
						var right_s := ln.substr(cidx + 1)
						XUiSkin.ds(self, bf, Vector2(pad.x, cy + 16 * 0.36), left_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, XUiSkin.TEXT_2)
						var lx := bf.get_string_size(left_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
						XUiSkin.ds(self, nf, Vector2(pad.x + lx, cy + 20 * 0.36), right_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, XUiSkin.GOLD_LIGHT)
						continue
				XUiSkin.ds(self, bf, Vector2(pad.x, cy + 18 * 0.36), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, XUiSkin.TEXT)
			return
		draw_style_box(style, Rect2(Vector2.ZERO, size))
		var asc := font.get_ascent(FONT_SIZE)
		var half := (LINE_H - (asc + font.get_descent(FONT_SIZE))) / 2.0
		var lines := text.split("\n")
		for i in range(lines.size()):
			var at := Vector2(BORDER + PAD.x, roundf(BORDER + PAD.y + LINE_H * i + half + asc))
			draw_string_outline(font, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 2, Color.BLACK)
			draw_string(font, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, GOLD)
