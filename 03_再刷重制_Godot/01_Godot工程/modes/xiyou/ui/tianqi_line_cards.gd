class_name XTianqiLineCards
extends Control
## 【cc·天启篇·未经审查】选线画面：四张竖卡并排（四线剧情与关卡设计稿 v0.4 第 2.2 节）。
## 每张：骑士剪影（本线颜色；打过这条线、或 XTianqiLook.CARD_PORTRAIT 开时画立绘）＋线名·骑士＋一句话＋「传闻」（骑士来历）＋「本线特点」＋卡底「骑士遗物」（打过才点亮）。
## 还没做好的线照列，压暗并标「暂未开放」，仍可选中看说明（小小鱼会说这条路还没修好）。
## 左右键／鼠标选，确认键或点卡定；取消键或「再想想」返回 -1。开关 XTianqiLook.CARDS（O-322）。
## 新界面（ui-skin-3b，盘点清册 #76）：XUiSkin.on() 时同样四张卡、同样的字和选择逻辑，只换外观：黑底＋绯红底光＋火星、
## 卡是黑面板细线（本线颜色留在人像光、分隔线和名字上）、选中的卡朱红描边＋绯红外晕＋顶上一道朱红光标、小标题旧金、
## 字换思源黑体／宋体（最小 14）、「再想想」黑面板按钮、右下按键提示；宽屏 request_wide 横向铺开（卡距放宽，最多 48）。关着照旧。

signal decided(index: int)

const CARD := Vector2(250, 524)  # 11-13 卡底加「骑士遗物」一行，高 500→524、整体上移 4
const GAP := 26.0
const TOP := 126.0
const FIG_H := 250.0
## 卡底「骑士遗物」一行的位置（两段说明走到 481）
const RELIC_Y := 486.0

var lines: Array = []
var playable: Array = []
var index := 0
var _cards: Array = []
var _back: Button
var _t := 0.0
var _done := false
var skin := false        # 进树时 XUiSkin.on() 定，之后不变
var _title: Label
var _sub: Label
var _hints: XSkinKeyHints
const SKIN_GAP_MAX := 48.0


## 把卡片加到 host（地图场景）的界面层上，等玩家选；返回 0～3 或 -1
static func pick(host: Node, line_list: Array, playable_list: Array, start := 0) -> int:
	if XMessageBox.auto:   # 自动测试：同对话框选项，依次取 auto_answers（取完选「再想想」）
		await host.get_tree().process_frame
		return int(XMessageBox.auto_answers.pop_front()) if not XMessageBox.auto_answers.is_empty() else -1
	var c := XTianqiLineCards.new()
	c.lines = line_list
	c.playable = playable_list
	c.index = clampi(start, 0, maxi(0, line_list.size() - 1))
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.name = "TianqiLineCards"
	host.add_child(layer)
	layer.add_child(c)
	var i: int = await c.decided
	layer.queue_free()
	return i


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skin = XUiSkin.on()
	theme = XUiSkin.theme() if skin else XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	if skin:
		XUiSkin.menu_backdrop(self)
	else:
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.01, 0.04, 0.82)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
	var title := XUI.label("方桌的裂纹裂成了四块，每一块里都映着一位骑士。", 26)
	title.position = Vector2(0, 50)
	title.size = Vector2(1280, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var sub := XUI.label("选定后这个存档不能再换。", 18, Color(0.75, 0.72, 0.8))
	sub.position = Vector2(0, 90)
	sub.size = Vector2(1280, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	_title = title
	_sub = sub
	var n := lines.size()
	var x0 := (1280.0 - n * CARD.x - (n - 1) * GAP) / 2.0
	for i in n:
		var card := _make_card(i)
		card.position = Vector2(x0 + i * (CARD.x + GAP), TOP)
		add_child(card)
		_cards.append(card)
	_back = XUI.button("再想想", 50)
	_back.custom_minimum_size = Vector2(180, 50)
	_back.position = Vector2(550, 652)
	_back.size = Vector2(180, 50)
	_back.focus_mode = Control.FOCUS_NONE
	_back.pressed.connect(func(): _finish(-1))
	add_child(_back)
	if skin:
		_skin_dress()
	_highlight()
	grab_focus.call_deferred()


## ---- 新界面 ----

## 换外观：标题宋体、小字次要色、卡里的字换样式、「再想想」黑面板按钮、按键提示；宽屏铺开
func _skin_dress() -> void:
	_title.add_theme_font_override("font", XUiSkin.font("title"))
	_title.add_theme_font_size_override("font_size", XUiSkin.FS_CARD)
	_title.add_theme_color_override("font_color", XUiSkin.TEXT)
	_sub.add_theme_font_size_override("font_size", XUiSkin.FS_AUX_MAX - 2)
	_sub.add_theme_color_override("font_color", XUiSkin.TEXT_2)
	_title.position.y = 44
	_sub.position.y = 86
	for c in _cards:
		(c as _Card).skin = true
		if c.mark_rect != null:   # 纹路缩进一点，不露出面板圆角外
			c.mark_rect.position = Vector2(4, 4)
			c.mark_rect.size = CARD - Vector2(8, 8)
		for l in c.get_children():
			if l is Label:
				_skin_label(c, l)
	XSkinButton.apply(_back, "", XUiSkin.FS_LIST)
	_back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back.custom_minimum_size = Vector2(180, 40)
	_back.size = Vector2(180, 40)
	_hints = XSkinKeyHints.new()
	_hints.name = "SkinKeyHints"
	_hints.set_hints([["← / →", "选择"], ["确定", "选定"], ["取消", "再想想"]])
	add_child(_hints)
	XSkinLayout.request_wide(self)
	resized.connect(_skin_layout)
	_skin_layout()


## 卡里的字：线名·骑士用宋体（本线颜色）；小标题旧金；正文白、次要灰；最小 14
func _skin_label(c: _Card, l: Label) -> void:
	var fs := l.get_theme_font_size("font_size")
	l.add_theme_font_size_override("font_size", maxi(fs, XUiSkin.FS_MIN))
	var t := l.text
	if l.position.y == FIG_H + 22.0:   # 线名·骑士
		l.add_theme_font_override("font", XUiSkin.font("title"))
		l.add_theme_font_size_override("font_size", XUiSkin.FS_CARD - 2)
	elif t in ["传闻", "本线特点", "骑士遗物"]:
		l.add_theme_color_override("font_color", XUiSkin.GOLD)
		if t == "骑士遗物":
			l.position.y -= 1
	elif l == c.done_tag:
		l.add_theme_color_override("font_color", XUiSkin.GOLD_LIGHT)
	elif l == c.relic_label:
		l.add_theme_color_override("font_color", XUiSkin.TEXT if c.relic_lit else XUiSkin.TEXT_3)
	elif l.autowrap_mode != TextServer.AUTOWRAP_OFF:
		l.add_theme_color_override("font_color", XUiSkin.TEXT_2)
	else:
		l.add_theme_color_override("font_color", XUiSkin.TEXT)


## 宽屏：卡组在安全边距里居中，卡距从 26 放宽到最多 48；标题、按钮、按键提示跟着视口宽
func _skin_layout() -> void:
	var vw := size.x if size.x > 0 else 1280.0
	var vh := size.y if size.y > 0 else 720.0
	var n := _cards.size()
	var m := XSkinLayout.margin_for(vw)
	var gap := GAP
	if n > 1:
		gap = clampf((vw - m * 2.0 - n * CARD.x) / (n - 1), GAP, SKIN_GAP_MAX)
	var x0 := roundf((vw - n * CARD.x - (n - 1) * gap) / 2.0)
	for i in n:
		_cards[i].position.x = x0 + i * (CARD.x + gap)
	_title.size.x = vw
	_sub.size.x = vw
	_back.position = Vector2(roundf((vw - _back.size.x) / 2.0), vh - XUiSkin.HINT_BOTTOM - _back.size.y)
	_hints.place(Vector2(vw, vh))
	if XPlatform.is_touch():
		_hints.visible = false


func _make_card(i: int) -> Control:
	var l: Dictionary = lines[i]
	var key := str(l.key)
	var ok := bool(playable[i]) if i < playable.size() else true
	var main := XTianqiLook.main_color(key)
	var card := _Card.new()
	card.size = CARD
	card.key = key
	card.ok = ok
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_entered.connect(func():
		if index != i:
			index = i
			XSound.system(0)
			_highlight())
	card.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			index = i
			_finish(i))
	# 底下透出本线的纹路（O12 纹路贴图染成本线颜色）
	var mk := TextureRect.new()
	mk.texture = XTianqiLook.mark(key)
	mk.stretch_mode = TextureRect.STRETCH_TILE
	mk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mk.size = CARD
	mk.material = XTianqiLook.mark_material(key, 0.16)
	mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(mk)
	card.mark_rect = mk
	# 骑士：剪影（默认）或立绘，脚底贴在人像框底
	var fig := TextureRect.new()
	fig.texture = XTianqiLook.portrait(key)
	fig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fig.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fig.position = Vector2(0, 16)
	fig.size = Vector2(CARD.x, FIG_H)
	fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 剪影还是立绘：打过这条线的骑士（跨存档的骑士徽记）才露出立绘（Kyo 11-13「打过了再开立绘」）；CARD_PORTRAIT 开时全画立绘
	card.portrait = XTianqiLook.CARD_PORTRAIT or XTianqiRewards.badges().has(key)
	if not card.portrait:
		fig.material = XTianqiLook.silhouette_material(key)
	card.add_child(fig)
	card.fig = fig
	var y := FIG_H + 22.0
	var name := XUI.label("%s·%s" % [l.name, l.knight], 24, main.lightened(0.2))
	name.position = Vector2(0, y)
	name.size = Vector2(CARD.x, 32)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name)
	y += 33.0
	var pick := XUI.label(str(l.pick), 17, Color(0.96, 0.94, 0.9))
	pick.position = Vector2(10, y)
	pick.size = Vector2(CARD.x - 20, 26)
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(pick)
	y += 32.0
	for row in [["传闻", str(l.test)], ["本线特点", str(l.change)]]:  # Kyo 11-13：先传闻，再特点
		var cap := XUI.label(str(row[0]), 15, XTianqiLook.accent_color(key).lightened(0.3))  # 小标题提亮：瘟疫的暗紫、死亡的冷蓝压在深底上看不清
		cap.position = Vector2(16, y)
		cap.size = Vector2(CARD.x - 32, 20)
		card.add_child(cap)
		y += 20.0
		var body := XUI.label(str(row[1]), 15, Color(0.88, 0.87, 0.9))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # 按中文断行规则折行：逗号、句号、引号不落在行首
		body.position = Vector2(16, y)
		body.size = Vector2(CARD.x - 32, 50)
		card.add_child(body)
		y += 52.0
	# 骑士遗物（Kyo 11-13 选的加项）：本线遗物的图标和名字；打过这条线的骑士（完整遗物和骑士徽记是同一战给的）才点亮，没打过是暗的「？？？」
	var relic_name := XTianqiRewards.relic_name(key, false)
	if relic_name != "":
		var got := XTianqiRewards.badges().has(key)
		card.relic_lit = got
		var icon := TextureRect.new()
		icon.texture = XUI.icon_texture(XTianqiQiyinArt.small_icon("relic_" + key))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position = Vector2(16, RELIC_Y)
		icon.size = Vector2(32, 32)
		icon.modulate = Color.WHITE if got else Color(0.16, 0.16, 0.2)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		# 文字审 1-013：小标题 13→15 号（原 13 号在手机上看不清），名字下移 2 格让开；名字底到 521，仍在卡高 524 内
		var rcap := XUI.label("骑士遗物", 15, XTianqiLook.accent_color(key).lightened(0.3))
		rcap.position = Vector2(56, RELIC_Y - 3)
		rcap.size = Vector2(CARD.x - 72, 18)
		card.add_child(rcap)
		var rname := XUI.label(relic_name if got else "？？？", 15, Color(0.96, 0.94, 0.9) if got else Color(0.55, 0.54, 0.6))
		rname.position = Vector2(56, RELIC_Y + 15)
		rname.size = Vector2(CARD.x - 72, 20)
		card.add_child(rname)
		card.relic_label = rname
	if XTianqiRewards.badges().has(key):  # 跨存档（Kyo 11-11 选乙）：通关过这条线的，卡上点亮「已清除异化」（Kyo 11-14 由「已通关」改名）
		var done := XUI.label("★ 已清除异化", 18, main.lightened(0.35))
		done.position = Vector2(0, 18)
		done.size = Vector2(CARD.x, 26)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(done)
		card.done_tag = done
		var badge_tex := XTianqiQiyinArt.badge_texture(key)  # 美术 O3 骑士徽记
		if badge_tex != null:
			var badge := TextureRect.new()
			badge.texture = badge_tex
			badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			badge.size = Vector2(64, 64)
			badge.position = Vector2(CARD.x - 72, 8)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(badge)
	if not ok:
		var tag := XUI.label("暂未开放", 18, Color(0.85, 0.82, 0.86))
		tag.position = Vector2(0, FIG_H / 2.0)
		tag.size = Vector2(CARD.x, 30)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(tag)
	return card


## 选中的那张抬起 LIFT、原亮度，其余压暗一点（原来只有边框变亮，四张看着差不多）
const LIFT := 10.0
const UNSELECTED := Color(0.8, 0.8, 0.82)

func _highlight() -> void:
	for i in _cards.size():
		var c: _Card = _cards[i]
		c.selected = i == index
		var y := TOP - (LIFT if c.selected else 0.0)
		var tint := Color.WHITE if c.selected else UNSELECTED
		if is_inside_tree() and (not is_equal_approx(c.position.y, y) or c.modulate != tint):
			var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "position:y", y, 0.12)
			tw.tween_property(c, "modulate", tint, 0.12)
		else:
			c.position.y = y
			c.modulate = tint
		c.queue_redraw()


func _process(dt: float) -> void:
	_t += dt
	for c in _cards:
		c.pulse = 0.5 + 0.5 * sin(_t * 3.0)
		if c.selected:
			c.queue_redraw()


func _finish(i: int) -> void:
	if _done:
		return
	_done = true
	if i >= 0:
		XSound.system(1)
	else:
		XSound.system(2)
	decided.emit(i)


func _gui_input(event: InputEvent) -> void:
	_handle(event)


func _unhandled_input(event: InputEvent) -> void:
	_handle(event)


func _handle(event: InputEvent) -> void:
	if _done or not event.is_pressed() or event.is_echo() and not (event.is_action("ui_left") or event.is_action("ui_right")):
		return
	if event.is_action("ui_left"):
		index = (index - 1 + _cards.size()) % _cards.size()
		XSound.system(0)
		_highlight()
	elif event.is_action("ui_right"):
		index = (index + 1) % _cards.size()
		XSound.system(0)
		_highlight()
	elif event.is_action("ui_accept"):
		_finish(index)
	elif event.is_action("ui_cancel"):
		_finish(-1)
	else:
		return
	XKeyMap.handled(self)


## 一张卡：底板、本线颜色的边，选中时边亮起、底下透出本线的纹路
class _Card extends Control:
	var key := ""
	var ok := true
	var selected := false
	var pulse := 0.0
	var fig: TextureRect
	var mark_rect: TextureRect
	var done_tag: Label   # 跨存档通关过这条线：「★ 已清除异化」
	var portrait := false  # 画的是立绘（打过这条线）还是剪影
	var relic_lit := false  # 卡底骑士遗物点亮了没有
	var relic_label: Label
	var skin := false       # 新界面画法（XTianqiLineCards.skin）
	const RELIC_LINE_Y := 481.5
	const DIVIDER_Y := 333.5  # FIG_H＋名字＋台词之后（_make_card 里 y 走到 337）

	func _draw() -> void:
		if skin:
			_draw_skin()
			return
		var main := XTianqiLook.main_color(key)
		var dark := XTianqiLook.dark_color(key)
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(dark.darkened(0.4), 0.92))
		# 人像框底下一道本线颜色的光（裂纹里透出来的）
		# 一像素一条，渐变是平的（原来六条十像素的色带，看得出台阶）
		var glow := Rect2(0, 210, size.x, 60)
		for k in int(glow.size.y):
			draw_rect(Rect2(glow.position.x, glow.position.y + k, glow.size.x, 1), Color(main, (0.02 + 0.11 * k / glow.size.y) * (1.6 if selected else 1.0)))
		# 名字、台词和下面两段说明之间一道本线颜色的细线
		draw_line(Vector2(16, DIVIDER_Y), Vector2(size.x - 16, DIVIDER_Y), Color(main, 0.4), 1.0)
		if relic_label != null:
			draw_line(Vector2(16, RELIC_LINE_Y), Vector2(size.x - 16, RELIC_LINE_Y), Color(main, 0.25), 1.0)
		var edge := main if selected else main.darkened(0.45)
		var w := 3.0 if selected else 1.5
		draw_rect(r.grow(-w / 2.0), Color(edge, 0.6 + 0.4 * pulse if selected else 0.85), false, w)
		if not ok:
			draw_rect(r, Color(0, 0, 0, 0.45))
		if mark_rect != null:
			mark_rect.modulate.a = 1.0 if selected else 0.55
		if fig != null:
			fig.modulate = Color(1, 1, 1, 1.0 if selected or not ok else 0.82)

	## 新界面：黑面板细线；人像光、分隔线留本线颜色；选中朱红描边（随脉动）＋绯红外晕＋顶上一道朱红光标
	func _draw_skin() -> void:
		var main := XTianqiLook.main_color(key)
		var r := Rect2(Vector2.ZERO, size)
		var ci := get_canvas_item()
		if selected:
			var halo := StyleBoxFlat.new()
			halo.draw_center = false
			halo.shadow_color = Color(XUiSkin.SEL_FILL, 0.30 + 0.15 * pulse)
			halo.shadow_size = 12
			halo.set_corner_radius_all(XUiSkin.RADIUS)
			halo.draw(ci, r)
		XUiSkin.draw_panel(ci, r)
		var glow := Rect2(1, 210, size.x - 2, 60)
		for k in int(glow.size.y):
			draw_rect(Rect2(glow.position.x, glow.position.y + k, glow.size.x, 1), Color(main, (0.02 + 0.11 * k / glow.size.y) * (1.6 if selected else 1.0)))
		draw_line(Vector2(16, DIVIDER_Y), Vector2(size.x - 16, DIVIDER_Y), Color(main, 0.4), 1.0)
		if relic_label != null:
			draw_line(Vector2(16, RELIC_LINE_Y), Vector2(size.x - 16, RELIC_LINE_Y), Color(XUiSkin.LINE, 0.25), 1.0)
		if selected:
			var edge := StyleBoxFlat.new()
			edge.draw_center = false
			edge.border_color = Color(XUiSkin.SEL_LINE, 0.55 + 0.35 * pulse)
			edge.set_border_width_all(2)
			edge.set_corner_radius_all(XUiSkin.RADIUS)
			edge.draw(ci, r)
			var bar := StyleBoxFlat.new()
			bar.bg_color = Color(XUiSkin.SEL_LINE, XUiSkin.breath_alpha())
			bar.set_corner_radius_all(2)
			bar.draw(ci, Rect2(XUiSkin.RADIUS + 8, 0, size.x - (XUiSkin.RADIUS + 8) * 2, XUiSkin.BAR_W))
		if not ok:
			var dim := StyleBoxFlat.new()
			dim.bg_color = Color(0, 0, 0, 0.45)
			dim.set_corner_radius_all(XUiSkin.RADIUS)
			dim.draw(ci, r)
		if mark_rect != null:
			mark_rect.modulate.a = 1.0 if selected else 0.55
		if fig != null:
			fig.modulate = Color(1, 1, 1, 1.0 if selected or not ok else 0.82)
