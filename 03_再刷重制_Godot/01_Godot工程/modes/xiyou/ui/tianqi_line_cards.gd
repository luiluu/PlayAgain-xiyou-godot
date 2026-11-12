class_name XTianqiLineCards
extends Control
## 【cc·天启篇·未经审查】选线画面：四张竖卡并排（四线剧情与关卡设计稿 v0.4 第 2.2 节）。
## 每张：骑士剪影（本线颜色；XTianqiLook.CARD_PORTRAIT 开时画立绘）＋线名·骑士＋一句话＋「本线特点」＋「怎么打」。
## 还没做好的线照列，压暗并标「还没修好」，仍可选中看说明（小小鱼会说这条路还没修好）。
## 左右键／鼠标选，确认键或点卡定；取消键或「再想想」返回 -1。开关 XTianqiLook.CARDS（O-322）。

signal decided(index: int)

const CARD := Vector2(250, 500)
const GAP := 26.0
const TOP := 130.0
const FIG_H := 250.0

var lines: Array = []
var playable: Array = []
var index := 0
var _cards: Array = []
var _back: Button
var _t := 0.0
var _done := false


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
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
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
	_highlight()
	grab_focus.call_deferred()


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
	if not XTianqiLook.CARD_PORTRAIT:
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
	for row in [["本线特点", str(l.change)], ["怎么打", str(l.test)]]:
		var cap := XUI.label(str(row[0]), 15, XTianqiLook.accent_color(key).lightened(0.1))
		cap.position = Vector2(16, y)
		cap.size = Vector2(CARD.x - 32, 20)
		card.add_child(cap)
		y += 20.0
		var body := XUI.label(str(row[1]), 15, Color(0.88, 0.87, 0.9))
		body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		body.position = Vector2(16, y)
		body.size = Vector2(CARD.x - 32, 50)
		card.add_child(body)
		y += 52.0
	if XTianqiRewards.badges().has(key):  # 跨存档（Kyo 11-11 选乙）：通关过这条线的，卡上点亮「已通关」
		var done := XUI.label("★ 已通关", 18, main.lightened(0.35))
		done.position = Vector2(0, 18)
		done.size = Vector2(CARD.x, 26)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(done)
		card.done_tag = done
	if not ok:
		var tag := XUI.label("还没修好", 18, Color(0.85, 0.82, 0.86))
		tag.position = Vector2(0, FIG_H / 2.0)
		tag.size = Vector2(CARD.x, 30)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(tag)
	return card


func _highlight() -> void:
	for i in _cards.size():
		var c: _Card = _cards[i]
		c.selected = i == index
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
	var done_tag: Label   # 跨存档通关过这条线：「★ 已通关」

	func _draw() -> void:
		var main := XTianqiLook.main_color(key)
		var dark := XTianqiLook.dark_color(key)
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(dark.darkened(0.4), 0.92))
		# 人像框底下一道本线颜色的光（裂纹里透出来的）
		var glow := Rect2(0, 210, size.x, 60)
		for k in 6:
			draw_rect(Rect2(glow.position.x, glow.position.y + k * 10, glow.size.x, 10), Color(main, (0.03 + k * 0.02) * (1.6 if selected else 1.0)))
		var edge := main if selected else main.darkened(0.45)
		var w := 3.0 if selected else 1.5
		draw_rect(r.grow(-w / 2.0), Color(edge, 0.6 + 0.4 * pulse if selected else 0.85), false, w)
		if not ok:
			draw_rect(r, Color(0, 0, 0, 0.45))
		if mark_rect != null:
			mark_rect.modulate.a = 1.0 if selected else 0.55
		if fig != null:
			fig.modulate = Color(1, 1, 1, 1.0 if selected or not ok else 0.82)
