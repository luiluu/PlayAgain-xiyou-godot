class_name XTianqiStartPage
extends Control
## 【cc·天启篇·未经审查】天启篇开局三页的新界面（T102，开局界面提案 v0.2 第一节，D153～D156）：选存档位、选难度、随机阵容。
## 只管画和焦点；流程（下一步去哪、取消退到哪、开局）仍在 entry.gd 的 _tq_*，由它传 Callable 进来。
## 门：XTianqiTitle.skin_on()（同标题页；设置「界面风格」选原版或发行构建没开放时 entry.gd 照旧画 MV 窗口，本类不建）。
## 共用：黑底火星（XUiSkin.menu_backdrop）、顶栏「新的游戏」＋步骤条（XSkinTabStrip.set_steps）、左上「‹」返回（点＝取消）、
## 底部按键提示（触屏变胶囊；阵容页触屏不挂）。整页进 FULLSCREEN_GROUP（收起虚拟摇杆）；宽屏 request_wide 强开。
## 版面按 1280×720 排在 stage 里，宽屏时 stage 整体水平居中；顶栏、按键提示按真实视口和安全边距摆。
## 交互控件都是真的 Button，节点名照旧：TianqiSlot%d、TianqiDifficulty_<key>、TianqiReroll、TianqiConfirm；
## 存档位牌里的「换一格」叫 WindowBack（同旧确认页），「覆盖它」叫 TianqiOverwrite，空格的「选这一格」叫 TianqiPickSlot（不以 TianqiSlot 开头，免得被当成一格）。
## 证道（XTianqi.locked）不设 disabled：能拿焦点看规则，按确定时抖一下、页面下方正中出提示，不进下一步（meta locked＝true）。
## 动效：卡片上浮、抖动、阵容翻牌、战斗小人待机都看 XUiSkin.motion()（关＝直接到位、不翻牌）；火星由 menu_backdrop 按档出。

const STEPS := ["存档位", "难度", "阵容"]
const ROW_H := 48.0
const ROW_STEP := 52.0
const LIST_RECT := Rect2(24, 72, 624, 584)    # 存档位列表面板（底沿 656，离触屏胶囊 666 留 10）
const CARD_RECT := Rect2(664, 72, 592, 584)   # 存档位详情牌
const DIFF_W := 224.0
const DIFF_H := 432.0    # 底沿 582；规则块最多到卡内 ~420（证道带小注）
const DIFF_GAP := 16.0
const DIFF_TOP := 150.0
const DIFF_RISE := 10.0
const ACTOR_W := 232.0
const ACTOR_H := 372.0
const ACTOR_GAP := 14.0
const HELPER_GAP := 30.0
const ACTOR_TOP := 140.0
const ZHENGDAO_TOAST := "「证道」暂未开放"

var stage: Control
var title_label: Label
var steps: XSkinTabStrip
var info: Control
var hints: XSkinKeyHints
var back_button: XSkinBackButton
var toast: Label
var step := 0
var hint_list: Array = []

# 存档位页
var rows: Array = []            # [Button]
var summaries: Array = []       # [summary_dict]
var card: Panel
var card_mode := false
var cur_slot := 1
var _on_pick := Callable()      # slot → 进难度页
var _on_exit := Callable()      # 列表里按取消：回标题

# 阵容页
var _sprites: Array = []        # [{rect, frames:[AtlasTexture]}]
var _sprite_t := 0.0
var _reroll: Button


func _init() -> void:
	name = "TianqiStartPage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	XSkinLayout.request_wide(self, true)
	get_viewport().size_changed.connect(relayout)
	relayout()


## 取消键（entry.gd 的 _back 指向这里）：存档位牌里＝回列表；其余交给页面登记的去处
var _cancel_fn := Callable()


func cancel() -> void:
	if card_mode:
		_leave_card()
		return
	if _cancel_fn.is_valid():
		_cancel_fn.call()


# ---------------------------------------------------------------- 共用

func _frame(at_step: int, cancel_fn: Callable, hint_arr: Array, show_hints := true) -> void:
	step = at_step
	_cancel_fn = cancel_fn
	add_to_group(XUiSkin.FULLSCREEN_GROUP)
	theme = XUiSkin.theme()
	XUiSkin.menu_backdrop(self)
	stage = Control.new()
	stage.name = "Stage"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size = Vector2(1280, 720)
	add_child(stage)
	# 第一个子节点是页名（测试和 entry.column 的约定：column 第 0 个是标题 Label）
	title_label = _label("新的游戏", "title", XUiSkin.FS_PAGE, XUiSkin.TEXT)
	title_label.name = "PageTitle"
	stage.add_child(title_label)
	steps = XSkinTabStrip.new()
	steps.name = "StepStrip"
	steps.font_size = XUiSkin.fs(17)
	steps.set_steps(STEPS, at_step)
	stage.add_child(steps)
	info = HBoxContainer.new()
	info.name = "TopInfo"
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(info as HBoxContainer).add_theme_constant_override("separation", 8)
	(info as HBoxContainer).alignment = BoxContainer.ALIGNMENT_END
	stage.add_child(info)
	back_button = XSkinBackButton.attach(self)
	hint_list = hint_arr
	if show_hints:
		hints = XSkinKeyHints.new()
		hints.name = "SkinKeyHints"
		hints.font_size = XUiSkin.fs(15)
		hints.set_hints(hint_list)
		add_child(hints)
	toast = _label("", "body", XUiSkin.fs(17), XUiSkin.GOLD_LIGHT)
	toast.name = "TianqiToast"
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.size = Vector2(560, 32)
	toast.position = Vector2(360, 604)
	toast.visible = false
	stage.add_child(toast)


func relayout() -> void:
	if stage == null or not is_inside_tree():
		return
	var view := get_viewport_rect().size
	var m := XSkinLayout.margin_for(view.x)
	stage.position = Vector2(roundf((view.x - 1280.0) / 2.0), roundf((view.y - 720.0) / 2.0))
	var tx := XSkinBackButton.place(back_button, m)
	var f := XUiSkin.font("title")
	title_label.position = Vector2(tx, 10) - stage.position
	title_label.size = Vector2(f.get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_PAGE).x + 4, 48)
	steps.position = Vector2(title_label.position.x + title_label.size.x + 24, 16 - stage.position.y)
	var iw := info.get_combined_minimum_size().x
	info.size = Vector2(iw, 36)
	info.position = Vector2(view.x - m - iw, 18) - stage.position
	if hints != null:
		hints.set_hints(hint_list)
		hints.place(view)


func _set_hints(arr: Array) -> void:
	hint_list = arr
	if hints != null:
		hints.set_hints(arr)
		relayout()


static func _label(text: String, kind := "body", fs := 17, color := XUiSkin.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", XUiSkin.font(kind))
	l.add_theme_font_size_override("font_size", maxi(fs, XUiSkin.FS_MIN))
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	return l


static func _at(c: Control, pos: Vector2, sz := Vector2.ZERO) -> Control:
	c.position = pos
	if sz != Vector2.ZERO:
		c.size = sz
	return c


static func _fit(l: Label, max_w: float, min_fs: int) -> Label:
	var fs := l.get_theme_font_size("font_size")
	var r := XSkinList.fit_text(l.get_theme_font("font"), l.text, max_w, fs, maxi(min_fs, XUiSkin.FS_MIN))
	l.text = str(r[0])
	l.add_theme_font_size_override("font_size", int(r[1]))
	l.clip_text = true
	l.size.x = max_w
	return l


static func _tex(t: Texture2D, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size = sz
	return r


static func _face(id: int) -> Texture2D:
	var rec := XDB.rec("Actors", id)
	if str(rec.get("faceName", "")) == "":
		return null
	return XUI.face_texture(str(rec.faceName), int(rec.get("faceIndex", 0)))


static func _badge(key: String) -> Texture2D:
	var d := XTianqi.difficulty(key)
	if d.is_empty():
		return null
	var p := XTianqi.badge_path(d)
	return load(p) if ResourceLoader.exists(p) else null


## 空圈（没有头像时）
static func _ring(sz: float) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(sz, sz)
	c.draw.connect(func(): c.draw_arc(Vector2(sz, sz) / 2.0, sz / 2.0 - 2.0, 0, TAU, 40, Color(XUiSkin.TEXT_3, 0.8), 2.0, true))
	return c


static func _panel(rect: Rect2, border := Color(0, 0, 0, 0)) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.position = rect.position
	p.size = rect.size
	if border.a > 0.0:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(XUiSkin.PANEL, 0.92)
		sb.border_color = border
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(XUiSkin.RADIUS)
		p.add_theme_stylebox_override("panel", sb)
	return p


## 小胶囊（「天启篇」「原版存档」「暂未开放」、档位）
static func _chip(text: String, color: Color, fs := 15) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.16)
	sb.border_color = Color(color, 0.75)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(11)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	pc.add_theme_stylebox_override("panel", sb)
	pc.add_child(_label(text, "body", fs, color))
	return pc


## 牌上的按钮：primary＝主按钮（平时深褐金底、焦点才红）
static func _button(text: String, node_name: String, primary := false, fs := 19) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	XSkinButton.apply(b, "primary" if primary else "", XUiSkin.fs(fs))
	if primary and XUiSkin.COMFORT_V2:
		var normal := XSkinButton.style("primary")
		XUiSkin.primary_button_style(normal, false)
		for st in ["normal", "disabled"]:
			b.add_theme_stylebox_override(st, normal)
	return b


func _show_toast(text: String) -> void:
	toast.text = text
	toast.visible = true
	toast.modulate.a = 1.0
	if toast.has_meta("tw"):
		var old = toast.get_meta("tw")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var tw := toast.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(toast, "modulate:a", 0.0, 0.3 if XUiSkin.motion() != XUiSkin.Motion.OFF else 0.0)
	tw.tween_callback(func(): toast.visible = false)
	toast.set_meta("tw", tw)


func _info_text(text: String, kind := "body", color := XUiSkin.TEXT_2, fs := 17) -> void:
	info.add_child(_label(text, kind, XUiSkin.fs(fs), color))


func _process(delta: float) -> void:
	if _sprites.is_empty() or XUiSkin.motion() == XUiSkin.Motion.OFF:
		return
	_sprite_t += delta / maxf(Engine.time_scale, 0.001)
	var k := int(_sprite_t / 0.2) % 4
	for s in _sprites:
		var frames: Array = s.frames
		(s.rect as TextureRect).texture = frames[[0, 1, 2, 1][k]]


func _unhandled_input(event: InputEvent) -> void:
	# 阵容页：Y 键（手柄 Y）＝重新随机
	if _reroll == null or not is_instance_valid(_reroll):
		return
	var hit := false
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_Y:
		hit = true
	elif event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y:
		hit = true
	if hit:
		get_viewport().set_input_as_handled()
		_reroll.pressed.emit()


# ---------------------------------------------------------------- ① 存档位

## focus_slot：光标停哪一格（0＝第一个空格，10 格全有档时 1 号）。on_pick(slot)：空格确定、有档的「覆盖它」；on_exit：列表里取消
func build_slots(focus_slot: int, on_pick: Callable, on_exit: Callable) -> void:
	_on_pick = on_pick
	_on_exit = on_exit
	_frame(0, on_exit, [["↑ / ↓", "换一格"], ["确定", "选这一格"], ["取消", "返回标题"]])
	summaries.clear()
	for slot in range(1, 11):
		summaries.append(XSave.summary_dict(slot))
	var lp := _panel(LIST_RECT)
	lp.name = "SlotListPanel"
	stage.add_child(lp)
	var used := summaries.filter(func(s): return str(s.state) != "empty").size()
	var lt := _label("选择存档位", "title", XUiSkin.fs(22), XUiSkin.GOLD)
	lp.add_child(_at(lt, Vector2(20, 10)))
	var lc := _label("%d 格有存档" % used, "body", XUiSkin.fs(15), XUiSkin.TEXT_2)
	lc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lp.add_child(_at(lc, Vector2(LIST_RECT.size.x - 220, 16), Vector2(200, 24)))
	rows.clear()
	for i in 10:
		var b := _slot_row(summaries[i])
		b.position = Vector2(LIST_RECT.position.x + 8, LIST_RECT.position.y + 50 + i * ROW_STEP)
		b.size = Vector2(LIST_RECT.size.x - 16, ROW_H)
		stage.add_child(b)
		rows.append(b)
	for i in 10:
		var b: Button = rows[i]
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)
		b.focus_neighbor_top = b.get_path_to(rows[posmod(i - 1, 10)])
		b.focus_neighbor_bottom = b.get_path_to(rows[posmod(i + 1, 10)])
		b.focus_previous = b.focus_neighbor_top
		b.focus_next = b.focus_neighbor_bottom
	card = _panel(CARD_RECT)
	card.name = "SlotCard"
	stage.add_child(card)
	if focus_slot < 1 or focus_slot > 10:
		focus_slot = 1
		for i in 10:
			if str(summaries[i].state) == "empty":
				focus_slot = i + 1
				break
	cur_slot = focus_slot
	_fill_card(cur_slot)
	(rows[cur_slot - 1] as Button).grab_focus.call_deferred()
	relayout()


func _slot_row(s: Dictionary) -> Button:
	var slot := int(s.slot)
	var b := Button.new()
	b.name = "TianqiSlot%d" % slot
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	b.add_child(_at(_label(str(slot), "num", XUiSkin.fs(19), XUiSkin.TEXT_2), Vector2(14, 11), Vector2(28, 26)))
	var st := str(s.state)
	if st == "empty":
		b.add_child(_at(_ring(36), Vector2(50, 6)))
		b.add_child(_at(_label("空", "body", XUiSkin.fs(18), XUiSkin.TEXT_3), Vector2(100, 11)))
	elif st != "ok":
		b.add_child(_at(_ring(36), Vector2(50, 6)))
		b.add_child(_at(_label(str(s.text), "body", XUiSkin.fs(17), XUiSkin.DOWN), Vector2(100, 12)))
	else:
		var face := _face(int(s.leader_id))
		b.add_child(_at(_tex(face, Vector2(40, 40)), Vector2(48, 4)) if face != null else _at(_ring(36), Vector2(50, 6)))
		b.add_child(_fit(_at(_label(str(s.leader_name), "body", XUiSkin.fs(19), XUiSkin.TEXT), Vector2(100, 10)) as Label, 150, 15))
		b.add_child(_at(_label("Lv %d" % int(s.level), "num", XUiSkin.fs(17), XUiSkin.TEXT_2), Vector2(256, 12)))
		if bool(s.is_tianqi) and str(s.difficulty) != "":
			var bt := _badge(str(s.difficulty))
			if bt != null:
				b.add_child(_at(_tex(bt, Vector2(30, 30)), Vector2(330, 9)))
			b.add_child(_at(_label(str(XTianqi.difficulty(str(s.difficulty)).get("name", "")), "body", XUiSkin.fs(17), XUiSkin.TEXT), Vector2(366, 12)))
		elif not bool(s.is_tianqi):
			b.add_child(_at(_chip("原版存档", XUiSkin.TEXT_2, XUiSkin.fs(15)), Vector2(330, 12)))
		var when := _short_time(str(s.saved_at))
		var tl := _label(when, "num", XUiSkin.fs(16), XUiSkin.TEXT_2)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(_at(tl, Vector2(LIST_RECT.size.x - 16 - 140 - 14, 13), Vector2(140, 24)))
	b.focus_entered.connect(func(): _on_row_focus(slot))
	b.pressed.connect(func(): _on_row_pressed(slot))
	return b


## 「2026-11-16 21:05:33」→「11-16 21:05」
static func _short_time(t: String) -> String:
	if t.length() < 16:
		return t
	return t.substr(5, 11)


func _on_row_focus(slot: int) -> void:
	if card_mode:
		return
	if slot != cur_slot:
		cur_slot = slot
		_fill_card(slot)


func _on_row_pressed(slot: int) -> void:
	if card_mode and slot != cur_slot:
		_leave_card()
	cur_slot = slot
	if str(summaries[slot - 1].state) == "empty":
		_on_pick.call(slot)
		return
	_fill_card(slot)
	_enter_card()


func _enter_card() -> void:
	var over := card.find_child("TianqiOverwrite", true, false) as Button
	if over == null:
		return
	card_mode = true
	var row: Button = rows[cur_slot - 1]
	row.add_theme_stylebox_override("normal", XUiSkin.select_style_for(XUiSkin.SelState.HOVER))   # 牌里时列表这一格留个记号
	over.grab_focus()
	_set_hints([["← / →", "换一个"], ["确定", "确认"], ["取消", "换一格"]])


func _leave_card() -> void:
	card_mode = false
	var row: Button = rows[cur_slot - 1]
	row.remove_theme_stylebox_override("normal")
	row.grab_focus()
	_set_hints([["↑ / ↓", "换一格"], ["确定", "选这一格"], ["取消", "返回标题"]])


func _fill_card(slot: int) -> void:
	for c in card.get_children():
		card.remove_child(c)
		c.queue_free()
	var s: Dictionary = summaries[slot - 1]
	var st := str(s.state)
	var w := CARD_RECT.size.x
	card.add_child(_at(_label("存档 %d" % slot, "title", XUiSkin.fs(26), XUiSkin.TEXT), Vector2(24, 16)))
	var tag := ""
	if st == "ok":
		tag = "天启篇" if bool(s.is_tianqi) else "原版存档"
	if tag != "":
		var chip := _chip(tag, XUiSkin.GOLD if bool(s.is_tianqi) else XUiSkin.TEXT_2, XUiSkin.fs(15))
		card.add_child(chip)
		chip.position = Vector2(w - 24 - chip.get_combined_minimum_size().x, 24)
	if st == "empty":
		card.add_child(_at(_ring(120), Vector2((w - 120) / 2.0, 120)))
		var e := _label("空", "title", XUiSkin.fs(30), XUiSkin.TEXT_3)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(_at(e, Vector2(0, 160), Vector2(w, 44)))
		var tip := _label("新局将绑定这一格。\n开局后所有存档都会保存在此。", "body", XUiSkin.fs(17), XUiSkin.TEXT_2)
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(_at(tip, Vector2(24, 280), Vector2(w - 48, 60)))
		var pick := _button("选这一格", "TianqiPickSlot", true)
		pick.focus_mode = Control.FOCUS_CLICK
		card.add_child(_at(pick, Vector2(24, CARD_RECT.size.y - 24 - 52), Vector2(w - 48, 52)))
		pick.pressed.connect(func(): _on_pick.call(slot))
		return
	if st != "ok":
		var bad := _label(str(s.text), "body", XUiSkin.fs(19), XUiSkin.DOWN)
		bad.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(_at(bad, Vector2(24, 80), Vector2(w - 48, 60)))
	else:
		var face := _face(int(s.leader_id))
		card.add_child(_at(_tex(face, Vector2(96, 96)), Vector2(24, 64)) if face != null else _at(_ring(92), Vector2(26, 66)))
		card.add_child(_fit(_at(_label(str(s.leader_name), "title", XUiSkin.fs(26), XUiSkin.TEXT), Vector2(136, 68)) as Label, w - 160, 18))
		card.add_child(_at(_label("Lv %d · 1 号位" % int(s.level), "body", XUiSkin.fs(17), XUiSkin.TEXT_2), Vector2(136, 108)))
		if bool(s.is_tianqi) and str(s.difficulty) != "":
			var bt := _badge(str(s.difficulty))
			if bt != null:
				card.add_child(_at(_tex(bt, Vector2(30, 30)), Vector2(136, 132)))
			card.add_child(_at(_label(str(XTianqi.difficulty(str(s.difficulty)).get("name", "")), "body", XUiSkin.fs(18), XUiSkin.TEXT), Vector2(172, 135)))
		var y := 178.0
		card.add_child(_at(_label("所在", "body", XUiSkin.fs(15), XUiSkin.TEXT_2), Vector2(24, y + 2)))
		card.add_child(_fit(_at(_label(str(s.map_name), "body", XUiSkin.fs(18), XUiSkin.TEXT), Vector2(80, y)) as Label, w - 104, 15))
		y += 34.0
		card.add_child(_at(_label("游戏时间", "body", XUiSkin.fs(15), XUiSkin.TEXT_2), Vector2(24, y + 2)))
		card.add_child(_at(_label(XSaveScene.playtime(float(s.play_seconds)), "num", XUiSkin.fs(18), XUiSkin.TEXT), Vector2(100, y)))
		card.add_child(_at(_label("存档时间", "body", XUiSkin.fs(15), XUiSkin.TEXT_2), Vector2(w / 2.0 - 10, y + 2)))
		card.add_child(_at(_label(str(s.saved_at).substr(0, 16), "num", XUiSkin.fs(18), XUiSkin.TEXT), Vector2(w / 2.0 + 66, y)))
		y += 40.0
		var party: Array = s.party_ids
		if bool(s.is_tianqi) and not party.is_empty():
			card.add_child(_at(_label("阵容", "body", XUiSkin.fs(15), XUiSkin.GOLD), Vector2(24, y)))
			y += 28.0
			for i in party.size():
				var x := 24.0 + i * 84.0
				var ft := _face(int(party[i]))
				card.add_child(_at(_tex(ft, Vector2(56, 56)), Vector2(x + 8, y)) if ft != null else _at(_ring(52), Vector2(x + 10, y + 2)))
				var nl := _label(str(XDB.rec("Actors", int(party[i])).get("name", "")), "body", XUiSkin.fs(15), XUiSkin.TEXT)
				nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				nl.clip_text = true
				card.add_child(_at(nl, Vector2(x, y + 60), Vector2(72, 24)))
			y += 96.0
	var warn := _label("这一格已有存档。选它开新局，第一次到达方桌大厅时会覆盖原存档。", "body", XUiSkin.fs(17), XUiSkin.DOWN)
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(_at(warn, Vector2(24, CARD_RECT.size.y - 24 - 52 - 16 - 54), Vector2(w - 48, 54)))
	var bw := (w - 48 - 16) / 2.0
	var over := _button("覆盖它", "TianqiOverwrite", true)
	var back := _button("换一格", "WindowBack")
	card.add_child(_at(over, Vector2(24, CARD_RECT.size.y - 24 - 52), Vector2(bw, 52)))
	card.add_child(_at(back, Vector2(24 + bw + 16, CARD_RECT.size.y - 24 - 52), Vector2(bw, 52)))
	for pair in [[over, back], [back, over]]:
		var a: Button = pair[0]
		var o: Button = pair[1]
		a.focus_neighbor_left = a.get_path_to(o)
		a.focus_neighbor_right = a.get_path_to(o)
		a.focus_neighbor_top = a.get_path_to(a)
		a.focus_neighbor_bottom = a.get_path_to(a)
		a.focus_next = a.get_path_to(o)
		a.focus_previous = a.get_path_to(o)
		# 列表里时牌上的按钮不接键盘焦点（只能点）；进牌才放开
		a.focus_mode = Control.FOCUS_ALL
	over.pressed.connect(func(): _on_pick.call(slot))
	back.pressed.connect(func():
		if card_mode:
			_leave_card()
		else:
			(rows[slot - 1] as Button).grab_focus())


# ---------------------------------------------------------------- ② 难度

## focus_key：光标停哪一档（""＝第一档）。on_pick(key)：选了没锁的一档；on_back：取消（回存档位）
func build_difficulty(slot: int, focus_key: String, on_pick: Callable, on_back: Callable) -> void:
	_frame(1, on_back, [["← / →", "换一档"], ["确定", "选这一档"], ["取消", "换存档位"]])
	_info_text("存档", "body", XUiSkin.TEXT_2)
	_info_text(str(slot), "num", XUiSkin.TEXT, 19)
	var n := XTianqi.DIFFICULTIES.size()
	var x0 := (1280.0 - (n * DIFF_W + (n - 1) * DIFF_GAP)) / 2.0
	var cards: Array = []
	var focus_btn: Button = null
	for i in n:
		var d: Dictionary = XTianqi.difficulty(str(XTianqi.DIFFICULTIES[i].key))
		var b := _difficulty_card(d)
		b.position = Vector2(x0 + i * (DIFF_W + DIFF_GAP), DIFF_TOP)
		b.size = Vector2(DIFF_W, DIFF_H)
		stage.add_child(b)
		cards.append(b)
		var key := str(d.key)
		var locked := XTianqi.locked(key)
		b.pressed.connect(func():
			if locked:
				_shake(b)
				_show_toast(ZHENGDAO_TOAST)
				return
			on_pick.call(key))
		if key == focus_key or (focus_btn == null and focus_key == "" and not locked):
			focus_btn = b
	for i in n:
		var b: Button = cards[i]
		var prev: Button = cards[posmod(i - 1, n)]
		var next: Button = cards[posmod(i + 1, n)]
		b.focus_neighbor_left = b.get_path_to(prev)
		b.focus_neighbor_right = b.get_path_to(next)
		b.focus_neighbor_top = b.get_path_to(prev)      # 上下也换档（手柄十字键、旧测试按下键）
		b.focus_neighbor_bottom = b.get_path_to(next)
		b.focus_previous = b.focus_neighbor_left
		b.focus_next = b.focus_neighbor_right
	if focus_btn == null:
		focus_btn = cards[0]
	focus_btn.grab_focus.call_deferred()
	relayout()


func _difficulty_card(d: Dictionary) -> Button:
	var key := str(d.key)
	var locked := XTianqi.locked(key)
	var b := Button.new()
	b.name = "TianqiDifficulty_" + key
	b.focus_mode = Control.FOCUS_ALL
	b.set_meta("locked", locked)
	b.set_meta("base_y", DIFF_TOP)
	var w := DIFF_W
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(XUiSkin.PANEL, 0.9)
	normal.border_color = Color(XUiSkin.LINE, 0.42)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(XUiSkin.RADIUS)
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, normal)
	var badge := _badge(key)
	var bt := _tex(badge, Vector2(112, 112))
	bt.name = "Badge"
	b.add_child(_at(bt, Vector2((w - 112) / 2.0, 22)))
	var nm := _label(str(d.name), "title", XUiSkin.fs(28), XUiSkin.TEXT)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(_at(nm, Vector2(0, 142), Vector2(w, 40)))
	var desc := _label(str(d.desc), "body", XUiSkin.fs(15), XUiSkin.TEXT_2)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(_at(desc, Vector2(16, 186), Vector2(w - 32, 48)))
	var line := ColorRect.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.color = Color(XUiSkin.LINE, 0.42)
	b.add_child(_at(line, Vector2(16, 244), Vector2(w - 32, 1)))
	b.add_child(_at(_label("随机阵容", "body", XUiSkin.fs(15), XUiSkin.GOLD), Vector2(16, 254)))
	# 每行：小字名＋一行值（值都短，不换行）；证道「超强者最多上阵」下面再加一行小注（助力位），整块不出卡底（T102 截图修：原来长值换行压到下一行、出卡底）
	var y := 280.0
	for row in _rule_rows(d):
		b.add_child(_at(_label(str(row[0]), "body", XUiSkin.fs(15), XUiSkin.TEXT_2), Vector2(16, y)))
		b.add_child(_fit(_at(_label(str(row[1]), "body", XUiSkin.fs(16), XUiSkin.TEXT), Vector2(16, y + 20)) as Label, w - 32, 13))
		y += 44.0
		if row.size() > 2:
			b.add_child(_fit(_at(_label(str(row[2]), "body", XUiSkin.fs(14), XUiSkin.TEXT_3), Vector2(16, y - 4)) as Label, w - 32, 12))
			y += 20.0
	if locked:
		var chip := _chip("暂未开放", XUiSkin.TEXT_2, XUiSkin.fs(15))
		b.add_child(chip)
		chip.position = Vector2(w - 12 - chip.get_combined_minimum_size().x, 10)
	b.focus_entered.connect(func(): _lift(b, true))
	b.focus_exited.connect(func(): _lift(b, false))
	b.modulate = _card_tint(locked, false)
	return b


## 「随机阵容」小节三行：[名, 值]或[名, 值, 小注]（数值表 roster；规则那几行都带「名」；证道的助力位规则作小注）
static func _rule_rows(d: Dictionary) -> Array:
	var tiers: Array = []
	for t in [XTier.WEAK, XTier.STRONG, XTier.SUPER]:
		if (d.get("pool", []) as Array).has(t):
			tiers.append(t)
	var cap: Array = ["超强者最多上阵", "%d 名" % int(d.get("super_cap", 0))]
	if XTianqi.HELPER_RULES and bool(d.get("helper_super", false)):
		cap.append("助力位可再放 1 名超强者")
	return [["能抽到", " · ".join(tiers)], cap, ["弱者至少", "%d 名" % int(d.get("min_weak", 0))]]


static func _card_tint(locked: bool, focused: bool) -> Color:
	var c := Color(0.62, 0.62, 0.62) if locked else Color.WHITE
	return c if focused else Color(c.r * 0.72, c.g * 0.72, c.b * 0.72)


func _lift(b: Button, on: bool) -> void:
	var to := float(b.get_meta("base_y", DIFF_TOP)) - (DIFF_RISE if on else 0.0)
	b.modulate = _card_tint(bool(b.get_meta("locked", false)), on)
	_tween_prop(b, "position:y", to, 0.12)


func _shake(b: Button) -> void:
	if XUiSkin.motion() == XUiSkin.Motion.OFF:
		return
	var x := b.position.x
	var tw := b.create_tween()
	for dx in [8.0, -8.0, 5.0, -3.0, 0.0]:
		tw.tween_property(b, "position:x", x + dx, 0.05)


func _tween_prop(n: Node, prop: String, to, t: float) -> void:
	var meta := "tw_" + prop.replace(":", "_")
	if n.has_meta(meta):
		var old = n.get_meta(meta)
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	if XUiSkin.motion() == XUiSkin.Motion.OFF or not n.is_inside_tree():
		n.set_indexed(prop, to)
		return
	var tw := n.create_tween()
	tw.tween_property(n, prop, to, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	n.set_meta(meta, tw)


# ---------------------------------------------------------------- ③ 随机阵容

## 五张角色卡（前 4 上场位、第 5 助力位）＋计数、规则句＋三个按钮。按钮由 entry.gd 接（TianqiConfirm 的 pressed 要绑 slot、key、lineup）。
## 返回 {reroll, confirm, back}
func build_lineup(slot: int, key: String, lineup: Array, on_back: Callable) -> Dictionary:
	var touch := XSkinKeyHints.touch_mode()
	_frame(2, on_back, [["Y", "重新随机"], ["确定", "确认"], ["取消", "换难度"]], not touch)   # 触屏不挂（三个大按钮自己能点）
	var d := XTianqi.difficulty(key)
	_info_text("存档", "body", XUiSkin.TEXT_2)
	_info_text(str(slot), "num", XUiSkin.TEXT, 19)
	_info_text("　难度", "body", XUiSkin.TEXT_2)
	var bt := _badge(key)
	if bt != null:
		var r := _tex(bt, Vector2(28, 28))
		r.custom_minimum_size = Vector2(28, 28)
		info.add_child(r)
	_info_text(str(d.get("name", "")), "body", XUiSkin.TEXT, 17)
	# 组头
	var front_w := XTianqi.FIGHTERS * ACTOR_W + (XTianqi.FIGHTERS - 1) * ACTOR_GAP
	var x0 := (1280.0 - (front_w + HELPER_GAP + ACTOR_W)) / 2.0
	_group_head("上场位", "4 人直接参战", Vector2(x0, ACTOR_TOP - 34))
	_group_head("助力位", "战斗中可换上", Vector2(x0 + front_w + HELPER_GAP, ACTOR_TOP - 34))
	_sprites.clear()
	var cards: Array = []
	for i in lineup.size():
		var x := x0 + i * (ACTOR_W + ACTOR_GAP) + (HELPER_GAP - ACTOR_GAP if i >= XTianqi.FIGHTERS else 0.0)
		var c := _actor_card(int(lineup[i]), i)
		c.position = Vector2(x, ACTOR_TOP)
		stage.add_child(c)
		cards.append(c)
	_flip_in(cards)
	# 底部左：计数＋规则句（右边界 ≤ 596）
	var n_super := lineup.filter(func(id): return XTianqiSkills.tier_of(int(id), true) == XTier.SUPER).size()
	var n_strong := lineup.filter(func(id): return XTianqiSkills.tier_of(int(id), true) == XTier.STRONG).size()
	var n_weak := lineup.filter(func(id): return XTianqiSkills.tier_of(int(id), true) == XTier.WEAK).size()
	var cap := XTianqi.lineup_super_max(key)
	var cnt := _label("超强者 %d / %d　强者 %d　弱者 %d" % [n_super, cap, n_strong, n_weak], "body", XUiSkin.fs(18), XUiSkin.TEXT)
	cnt.name = "LineupCount"
	stage.add_child(_at(cnt, Vector2(x0, 540)))
	var rule := "%s：同一场最多上阵 %d 名超强者，至少 %d 名弱者" % [str(d.get("name", "")), int(d.get("super_cap", 0)), int(d.get("min_weak", 0))]
	if XTianqi.HELPER_RULES and bool(d.get("helper_super", false)):
		rule += "；助力位可再放 1 名超强者"
	var rl := _label(rule, "body", XUiSkin.fs(15), XUiSkin.TEXT_2)
	rl.name = "LineupRule"
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage.add_child(_at(rl, Vector2(x0, 574), Vector2(596 - x0, 48)))
	# 底部右：三个按钮
	var roll := _button("重新随机", "TianqiReroll")
	var ok := _button("就是他们了", "TianqiConfirm", true)
	var back := _button("返回", "WindowBack")
	var right := 1280.0 - x0
	var specs := [[roll, 172.0], [ok, 212.0], [back, 132.0]]
	var x := right
	for i in range(specs.size() - 1, -1, -1):
		var bw: float = specs[i][1]
		x -= bw
		var b: Button = specs[i][0]
		stage.add_child(_at(b, Vector2(x, 548), Vector2(bw, 56)))
		x -= 12.0
	var btns := [roll, ok, back]
	for i in 3:
		var b: Button = btns[i]
		var prev: Button = btns[posmod(i - 1, 3)]
		var next: Button = btns[posmod(i + 1, 3)]
		b.focus_neighbor_left = b.get_path_to(prev)
		b.focus_neighbor_top = b.get_path_to(prev)
		b.focus_neighbor_right = b.get_path_to(next)
		b.focus_neighbor_bottom = b.get_path_to(next)
		b.focus_previous = b.focus_neighbor_left
		b.focus_next = b.focus_neighbor_right
	_reroll = roll
	roll.grab_focus.call_deferred()
	relayout()
	return {"reroll": roll, "confirm": ok, "back": back}


func _group_head(title: String, sub: String, pos: Vector2) -> void:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 10)
	h.add_child(_label(title, "title", XUiSkin.fs(19), XUiSkin.GOLD))
	var s := _label(sub, "body", XUiSkin.fs(15), XUiSkin.TEXT_2)
	s.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(s)
	stage.add_child(_at(h, pos))


func _actor_card(id: int, i: int) -> Panel:
	var rec := XDB.rec("Actors", id)
	var tier := XTianqiSkills.tier_of(id, true)
	var p := _panel(Rect2(0, 0, ACTOR_W, ACTOR_H), XUiSkin.GOLD if tier == XTier.SUPER else Color(0, 0, 0, 0))
	p.name = "TianqiActor%d" % i
	var nm := str(rec.get("name", ""))
	p.set_meta("actor_id", id)
	p.set_meta("actor_name", nm)
	p.pivot_offset = Vector2(ACTOR_W, ACTOR_H) / 2.0
	var w := ACTOR_W
	var face := _face(id)
	p.add_child(_at(_tex(face, Vector2(120, 120)), Vector2((w - 120) / 2.0, 20)) if face != null else _at(_ring(116), Vector2((w - 116) / 2.0, 22)))
	if i == 0:
		p.add_child(_at(_chip("1 号位", XUiSkin.SEL_LINE, XUiSkin.fs(15)), Vector2(10, 10)))
	var nl := _label(nm, "title", XUiSkin.fs(24), XUiSkin.TEXT)
	nl.name = "Name"
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(_fit(_at(nl, Vector2(12, 150)) as Label, w - 24, 22))
	nl.size.y = 36
	var nick := str(rec.get("nickname", ""))
	if nick != "" and nick != nm:   # 称号和名字一样时不画（白起、要乐奈）
		var kl := _label(nick, "body", XUiSkin.fs(15), XUiSkin.TEXT_2)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		kl.clip_text = true
		p.add_child(_at(kl, Vector2(12, 188), Vector2(w - 24, 24)))
	var tc := XUiSkin.TEXT_2 if tier == XTier.WEAK else XUiSkin.MP if tier == XTier.STRONG else XUiSkin.GOLD
	var chip := _chip(tier, tc, XUiSkin.fs(15))
	p.add_child(chip)
	chip.position = Vector2((w - chip.get_combined_minimum_size().x) / 2.0, 220)
	var frames := _sv_frames(rec)
	if not frames.is_empty():
		var r := _tex(frames[1], Vector2(112, 112))
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p.add_child(_at(r, Vector2((w - 112) / 2.0, 252)))
		_sprites.append({"rect": r, "frames": frames})
	return p


## 战斗侧视图（9×6）第 0 行前 3 格：待机 0-1-2-1
static func _sv_frames(rec: Dictionary) -> Array:
	var path := XDB.img_path("sv_actors", str(rec.get("battlerName", "")))
	if path == "" or not ResourceLoader.exists(path):
		return []
	var sheet := load(path) as Texture2D
	if sheet == null:
		return []
	var out := []
	var cw := sheet.get_width() / 9.0
	var ch := sheet.get_height() / 6.0
	for col in 3:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(cw * col, 0, cw, ch)
		out.append(at)
	return out


## 新卡依次翻进来（约 0.4 秒）：全部＝横向翻开，简化＝只淡入，关＝直接换
func _flip_in(cards: Array) -> void:
	var m := XUiSkin.motion()
	if m == XUiSkin.Motion.OFF:
		return
	for i in cards.size():
		var c: Control = cards[i]
		var tw := c.create_tween()
		if m == XUiSkin.Motion.FULL:
			c.scale = Vector2(0.0, 1.0)
			tw.tween_interval(i * 0.06)
			tw.tween_property(c, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			c.modulate.a = 0.0
			tw.tween_property(c, "modulate:a", 1.0, 0.2)
