class_name XSkinRuleStrip
extends Control
## 【cc·天启篇·未经审查】战中「本场规则」条（T386 / K1b；设计稿 T254_战中规则条.md，Kyo 11-22 五问按推荐）。
## 左上自动／变速圆钮正右侧常驻折叠条（1 条＝单条英雄态，≥2 条＝双行阶梯＋「+N」溢出），R／LB／轻点展开贴左下拉的「本场规则」详卡。
## 只读 XTianqiBattleRules.collect（0.1 秒轮询），不改战斗、不耗随机数、不加停顿。
## 不建的情况（零像素）：XTianqiBattleRules.ENABLED 关、新界面皮肤关、不是天启篇存档。本场没有规则时整条隐藏、不吃输入。
## 玩家可见文字照小A 文字审定稿（T387）。

const POLL := 0.1
const GAP_TOGGLES := 16.0       # 圆钮右缘到规则条
const ROW1_Y := 61.0            # 双行：上行 y 61～93，下行 y 101～133（130% 字号 y 58～96、102～140）
const ROW_H := 32.0
const ROW_GAP := 8.0
const HERO_CY := 97.0           # 单条英雄态竖直居中于圆钮（y 79～115）
const HERO_H := 36.0
const NO_ARC_W := 420.0         # 无血弧时单行最宽
const ARC_LIMIT1 := 432.0       # 有血弧：上行右界（16:9；20:9 加 origin.x）。稿面写 416，Kyo 定稿样稿上行画到 432（血弧外晕圆角处），照样稿
const ARC_LIMIT2 := 472.0       # 有血弧：下行右界
const CHIP_NAME_MAX := 118.0    # 短签名最宽，超出省略号
const DRAWER_Y := 142.0
const DRAWER_W := 368.0
const DRAWER_W_BIG := 420.0
const DRAWER_BOTTOM := 618.0
const TOP_H := 28.0
const FOOT_H := 24.0
const PAD := 12.0

var logic
var toggles: Control
var origin := Vector2.ZERO
## 有首领血弧（顶上）时返回 true（battle_scene 传）；没传当没有
var arc_source: Callable
## 技能／物品列表等手头操作窗口的矩形（屏幕坐标；没打开为空）：与详卡相交时详卡自动收起
var blocker_source: Callable

var rules: Array = []
var source := ""
var open := false
var scroll := 0.0
var _poll := 0.0
var _now := 0.0
var _flash := {}                # id → 开始轻闪的时刻
var _sig := {}                  # id → 上次的 counter（变了就闪一下）
var _open_t := -9.0
var _close_t := -9.0
var _drag_y := -1.0
var _content_h := 0.0
var _hit: Control
var _catcher: Control
var _drawer: Control
var _list: Control
## 测试读：上一帧折叠态画了哪些短签（屏幕矩形）、溢出几条、详卡矩形
var last := {}


## 天启篇档＋新界面＋总开关都开才建；否则 null（西游档、开关关＝零变化）
static func make(lg, toggle_box: Control, org: Vector2) -> XSkinRuleStrip:
	if not XTianqiBattleRules.ENABLED or not XUiSkin.on() or lg == null or not XTianqiCombat.on(lg.state):
		return null
	var s := XSkinRuleStrip.new()
	s.logic = lg
	s.toggles = toggle_box
	s.origin = org
	return s


func _ready() -> void:
	name = "RuleStrip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher = Control.new()
	_catcher.name = "RuleCatcher"
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.visible = false
	_catcher.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			set_open(false)
			_catcher.accept_event())
	add_child(_catcher)
	_hit = Control.new()
	_hit.name = "RuleHit"
	_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_hit.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			toggle()
			_hit.accept_event())
	add_child(_hit)
	_drawer = Control.new()
	_drawer.name = "RuleDrawer"
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer.visible = false
	_drawer.draw.connect(_draw_drawer)
	_drawer.gui_input.connect(_drawer_input)
	add_child(_drawer)
	_list = Control.new()
	_list.name = "RuleList"
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.clip_contents = true
	_list.draw.connect(_draw_list)
	_drawer.add_child(_list)
	refresh()


func _process(dt: float) -> void:
	_now += dt
	_poll += dt
	if _poll >= POLL:
		_poll = 0.0
		refresh()
	if open and blocker_source.is_valid():
		var br = blocker_source.call()
		if br is Rect2 and br.has_area() and br.intersects(drawer_rect()):
			set_open(false)
	_update_drawer_anim()
	queue_redraw()
	if _drawer.visible:
		_drawer.queue_redraw()
		_list.queue_redraw()


## 读一次数据源（只读）
func refresh() -> void:
	rules = XTianqiBattleRules.collect(logic)
	source = XTianqiBattleRules.source_label(logic)
	var seen := {}
	for r in rules:
		var id := str(r.id)
		seen[id] = true
		var c := str(r.counter)
		if not _sig.has(id) or str(_sig[id]) != c:
			if _sig.has(id) or _now > 0.5:   # 开场那一批不闪
				_flash[id] = _now
			_sig[id] = c
	for id in _sig.keys():
		if not seen.has(id):
			_sig.erase(id)
	if rules.is_empty() and open:
		set_open(false)


func has_rules() -> bool:
	return not rules.is_empty()


func toggle() -> void:
	set_open(not open)


func set_open(v: bool) -> void:
	if v and rules.is_empty():
		return
	if v == open:
		return
	open = v
	if v:
		scroll = 0.0
		_open_t = _now
		_drawer.visible = true
	else:
		_close_t = _now
	_catcher.visible = v
	XSound.system(0 if v else 2)


## battle_scene._unhandled_input 最前面调：R／手柄 LB 开关，详卡开着时 Esc／B 收起、↑↓ 内滚（内容放不下时）。收了返回 true
func try_toggle_input(event: InputEvent) -> bool:
	if not is_visible_in_tree() or rules.is_empty():
		return false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		toggle()
		return true
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_LEFT_SHOULDER:
		toggle()
		return true
	if not open:
		return false
	if event.is_action_pressed("ui_cancel"):
		set_open(false)
		return true
	if _max_scroll() > 0.0:
		if event.is_action_pressed("ui_down", true):
			_scroll_by(36.0)
			return true
		if event.is_action_pressed("ui_up", true):
			_scroll_by(-36.0)
			return true
	return false


func _drawer_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_by(36.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_by(-36.0)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			_drag_y = e.position.y
	elif e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_drag_y = -1.0
	elif e is InputEventMouseMotion and _drag_y >= 0.0:
		_scroll_by(_drag_y - e.position.y)
		_drag_y = e.position.y
	elif e is InputEventScreenDrag:
		_scroll_by(-e.relative.y)
	_drawer.accept_event()


func _scroll_by(d: float) -> void:
	scroll = clampf(scroll + d, 0.0, _max_scroll())


func _max_scroll() -> float:
	return maxf(0.0, _content_h - _list.size.y)


## 战斗结算：0.12 秒淡出（动效关直接藏）
func fade_out() -> void:
	set_open(false)
	set_process(false)
	_hit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if XUiSkin.motion() == XUiSkin.Motion.OFF:
		hide()
		return
	create_tween().tween_property(self, "modulate:a", 0.0, 0.12)


# ---- 尺寸 ----

func _fm() -> float:
	return XUiSkin.font_mult()


func _fs(base: int) -> int:
	return XUiSkin.fs(base)


func _row_h() -> float:
	return roundf(ROW_H + (_fm() - 1.0) * 20.0)


func _x0() -> float:
	if toggles != null and is_instance_valid(toggles):
		# 按圆钮（容器里可见的子节点）的实际右缘算：HBox 自己的 size 会被旧横条胶囊的最小宽撑大
		var right := 0.0
		for c in toggles.get_children():
			if c is Control and c.visible:
				right = maxf(right, c.position.x + c.size.x)
		if right <= 0.0:
			right = toggles.size.x
		return toggles.position.x + right + GAP_TOGGLES
	return origin.x + 202.0


func _arc() -> bool:
	return arc_source.is_valid() and bool(arc_source.call())


func _right_limit(row: int) -> float:
	var x0 := _x0()
	if not _arc():
		return x0 + NO_ARC_W
	var lim := ARC_LIMIT1 if row == 0 else ARC_LIMIT2
	# 20:9（origin.x>0）的血弧跟着往右挪；左安全边距让圆钮也右移了，界限照样跟 origin
	return maxf(x0 + 120.0, origin.x + lim)


func drawer_rect() -> Rect2:
	var x := toggles.position.x if toggles != null and is_instance_valid(toggles) else origin.x + 20.0
	var w := DRAWER_W_BIG if _fm() >= 1.2 else DRAWER_W
	var top := origin.y + DRAWER_Y
	var inner := _content_h
	var h := minf(TOP_H + 8.0 + inner + FOOT_H + PAD * 2.0, DRAWER_BOTTOM - DRAWER_Y)
	return Rect2(x, top, w, h)


# ---- 颜色 ----

func tone_color(r: Dictionary) -> Color:
	match str(r.get("tone", "gold")):
		"warn":
			return XUiSkin.down_c()
		"buff":
			return XUiSkin.UP
		"line":
			return XTianqiLook.main_color(str(r.get("line", "")), XUiSkin.GOLD)
	return XUiSkin.GOLD


func _counter_color(r: Dictionary) -> Color:
	match str(r.get("tone", "gold")):
		"warn":
			return XUiSkin.down_c()
		"buff":
			return XUiSkin.UP
	return XUiSkin.GOLD_LIGHT


func _breath() -> float:
	if XUiSkin.motion() != XUiSkin.Motion.FULL:
		return 1.0
	return 0.7 + 0.3 * (0.5 + 0.5 * cos(_now * TAU / XUiSkin.TARGET_PULSE))


func _flash_k(id: String) -> float:
	if XUiSkin.motion() != XUiSkin.Motion.FULL or not _flash.has(id):
		return 0.0
	var t := _now - float(_flash[id])
	return clampf(1.0 - t / 0.2, 0.0, 1.0)


func _key_label() -> String:
	match XUiSkin.current_input_mode():
		XUiSkin.InputMode.GAMEPAD:
			return "LB"
		XUiSkin.InputMode.TOUCH:
			return ""
	return "R"


func _tw(text: String, fs: int) -> float:
	return XUiSkin.font("body").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


# ---- 画折叠态 ----

func _pill(rect: Rect2, fill: Color, border: Color, bw := 1.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(int(bw))
	sb.set_corner_radius_all(int(rect.size.y / 2.0))
	sb.anti_aliasing = true
	draw_style_box(sb, rect)


## 折叠态排版（纯计算，测试直接读）：{hero, head, chips:[{i, id, rect}], plus, overflow, bbox}
func plan() -> Dictionary:
	var out := {"hero": false, "head": Rect2(), "chips": [], "plus": Rect2(), "overflow": 0, "bbox": Rect2()}
	if rules.is_empty():
		return out
	var fs := _fs(15)
	if rules.size() == 1:
		var r: Dictionary = rules[0]
		var font := XUiSkin.font("body")
		var nf := XUiSkin.font("num")
		var h := roundf(HERO_H + (_fm() - 1.0) * 20.0)
		var icon: Texture2D = XUiSkin.icon(int(r.icon)) if int(r.icon) > 0 else null
		var name := XSkinNoticeLane.ellipsize(str(r.name), font, fs, CHIP_NAME_MAX)
		var key := _key_label()
		var w := 14.0 + (28.0 if icon != null else 0.0) + _tw(name, fs) + 6.0
		if str(r.counter) != "":
			w += 7.0 + nf.get_string_size(str(r.counter), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 6.0
		w += 7.0 + (_tw(key, _fs(12)) + 12.0 + 4.0 if key != "" else 0.0) + 12.0 + 12.0
		var rect := Rect2(_x0(), origin.y + HERO_CY - h / 2.0, w, h)
		out.hero = true
		out.chips = [{"i": 0, "id": str(r.id), "rect": rect}]
		out.bbox = rect
		return out
	var rh := _row_h()
	var y1 := origin.y + ROW1_Y - (rh - ROW_H) / 2.0
	var y2 := y1 + rh + roundf(ROW_GAP - (_fm() - 1.0) * 6.67)
	var gap := 8.0
	var x0 := _x0()
	var plus_w := 38.0 + (_fm() - 1.0) * 10.0
	var head_w := _head_w(fs)
	out.head = Rect2(x0, y1, head_w, rh)
	# 上行引导头＋按优先级往后排，放不下折到下行；下行还有剩的时末端留 +N 的位子（不回填，保持优先级顺序）
	var cx := x0 + head_w + gap
	var row := 0
	var placed := 0
	var stop := false
	for i in rules.size():
		var w := _chip_w(rules[i], fs)
		var remain_after := rules.size() - i - 1
		while true:
			var reserve := (gap + plus_w) if (row == 1 and remain_after > 0) else 0.0
			if cx + w + reserve <= _right_limit(row):
				out.chips.append({"i": i, "id": str(rules[i].id), "rect": Rect2(cx, y1 if row == 0 else y2, w, rh)})
				placed += 1
				cx += w + gap
				break
			if row == 0:
				row = 1
				cx = x0
				continue
			stop = true
			break
		if stop:
			break
	out.overflow = rules.size() - placed
	var bbox: Rect2 = out.head
	for c in out.chips:
		bbox = bbox.merge(c.rect)
	if int(out.overflow) > 0:
		out.plus = Rect2(cx if row == 1 else x0, y2, plus_w, rh)
		bbox = bbox.merge(out.plus)
	out.bbox = bbox
	return out


func _draw() -> void:
	var p := plan()
	last = p.duplicate()
	last["drawer"] = Rect2()
	if rules.is_empty():
		_hit.visible = false
		return
	_hit.visible = true
	var fs := _fs(15)
	if bool(p.hero):
		_draw_hero(rules[0], p.chips[0].rect, fs)
	else:
		_draw_head(p.head, fs)
		for c in p.chips:
			_draw_chip(rules[int(c.i)], c.rect, fs)
		if int(p.overflow) > 0:
			var pr: Rect2 = p.plus
			_pill(pr, Color(XUiSkin.panel_low_c(), 0.92), Color(XUiSkin.line_c(), 0.45))
			XUiSkin.ds(self, XUiSkin.font("num"), Vector2(pr.position.x, XUiSkin.text_baseline_y(pr.get_center().y, fs)), "+%d" % int(p.overflow), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, fs, XUiSkin.GOLD_LIGHT)
	# 触控热区：高 ≥ 44，向下扩 6
	var bbox: Rect2 = p.bbox.grow_individual(0, 0, 0, 6)
	if bbox.size.y < 44.0:
		bbox = bbox.grow_individual(0, 0, 0, 44.0 - bbox.size.y)
	_hit.position = bbox.position
	_hit.size = bbox.size
	if _drawer.visible:
		last.drawer = drawer_rect()


func _draw_hero(r: Dictionary, rect: Rect2, fs: int) -> void:
	var font := XUiSkin.font("body")
	var nf := XUiSkin.font("num")
	var icon: Texture2D = XUiSkin.icon(int(r.icon)) if int(r.icon) > 0 else null
	var name := XSkinNoticeLane.ellipsize(str(r.name), font, fs, CHIP_NAME_MAX)
	var counter := str(r.counter)
	var key := _key_label()
	var tone := tone_color(r)
	var fill := Color(XUiSkin.panel_low_c(), 0.92)
	var border := Color(XUiSkin.GOLD, 0.65)
	if str(r.tone) in ["warn", "buff"]:
		fill = fill.lerp(tone, 0.12)
		border = Color(tone, 0.88 * (_breath() if str(r.tone) == "warn" else 1.0))
	border = border.lerp(XUiSkin.GOLD_LIGHT, _flash_k(str(r.id)))
	_pill(rect, fill, border, 1.0)
	var cy := rect.get_center().y
	var cx := rect.position.x + 14.0
	if icon != null:
		draw_texture_rect(icon, Rect2(cx, cy - 11.0, 22.0, 22.0), false)
		cx += 28.0
	var base := XUiSkin.text_baseline_y(cy, fs)
	XUiSkin.ds(self, font, Vector2(cx, base), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_HI)
	cx += _tw(name, fs) + 6.0
	if counter != "":
		draw_rect(Rect2(cx, cy - 6.0, 1.0, 12.0), Color(XUiSkin.line_c(), 0.45))
		cx += 7.0
		XUiSkin.ds(self, nf, Vector2(cx, base), counter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _counter_color(r))
		cx += nf.get_string_size(counter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 6.0
	draw_rect(Rect2(cx, cy - 6.0, 1.0, 12.0), Color(XUiSkin.line_c(), 0.45))
	cx += 7.0
	_draw_key_and_arrow(cx, cy, key)


func _draw_key_and_arrow(cx: float, cy: float, key: String) -> float:
	if key != "":
		var kfs := _fs(12)
		var kw := _tw(key, kfs) + 12.0
		var kr := Rect2(cx, cy - 9.0, kw, 18.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(XUiSkin.panel_c(), 0.9)
		sb.border_color = Color(XUiSkin.line_c(), 0.55)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		draw_style_box(sb, kr)
		XUiSkin.ds(self, XUiSkin.font("body"), Vector2(cx, XUiSkin.text_baseline_y(cy, kfs)), key, HORIZONTAL_ALIGNMENT_CENTER, kw, kfs, XUiSkin.text2_c())
		cx += kw + 4.0
	_draw_arrow(Vector2(cx + 6.0, cy), open)
	return cx + 12.0


func _draw_arrow(c: Vector2, up: bool) -> void:
	var s := 4.0
	var pts := PackedVector2Array([c + Vector2(-s, -s * 0.5), c + Vector2(s, -s * 0.5), c + Vector2(0, s * 0.6)]) if not up else \
		PackedVector2Array([c + Vector2(-s, s * 0.5), c + Vector2(s, s * 0.5), c + Vector2(0, -s * 0.6)])
	draw_colored_polygon(pts, XUiSkin.GOLD)


func _chip_w(r: Dictionary, fs: int) -> float:
	var font := XUiSkin.font("body")
	var nf := XUiSkin.font("num")
	var name := XSkinNoticeLane.ellipsize(str(r.name), font, fs, CHIP_NAME_MAX)
	var w := 12.0 + _tw(name, fs) + 12.0
	if int(r.icon) > 0 and XUiSkin.icon(int(r.icon)) != null:
		w += 24.0
	if str(r.counter) != "":
		w += 6.0 + nf.get_string_size(str(r.counter), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return w


func _head_w(fs: int) -> float:
	var key := _key_label()
	return 10.0 + 10.0 + _tw("规则", fs) + 6.0 + (_tw(key, _fs(12)) + 16.0 if key != "" else 0.0) + 12.0 + 6.0


func _draw_head(head: Rect2, fs: int) -> void:
	var hfill := Color(XUiSkin.panel_low_c(), 0.92)
	var hborder := Color(XUiSkin.GOLD, 0.65)
	if open:
		hfill = Color(XUiSkin.BTN_IDLE_FILL, 0.96)
		hborder = XUiSkin.GOLD_LIGHT
	_pill(head, hfill, hborder)
	var cy := head.get_center().y
	var hx := head.position.x + 11.0
	draw_colored_polygon(PackedVector2Array([Vector2(hx, cy - 4), Vector2(hx + 4, cy), Vector2(hx, cy + 4), Vector2(hx - 4, cy)]), XUiSkin.GOLD)
	hx += 10.0
	XUiSkin.ds(self, XUiSkin.font("body"), Vector2(hx, XUiSkin.text_baseline_y(cy, fs)), "规则", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.GOLD_LIGHT)
	hx += _tw("规则", fs) + 6.0
	_draw_key_and_arrow(hx, cy, _key_label())


func _draw_chip(r: Dictionary, rect: Rect2, fs: int) -> void:
	var font := XUiSkin.font("body")
	var nf := XUiSkin.font("num")
	var tone := tone_color(r)
	var t := str(r.tone)
	var fill := Color(XUiSkin.panel_low_c(), 0.92)
	var border := Color(XUiSkin.line_c(), 0.45)
	if t == "warn":
		fill = fill.lerp(tone, 0.12)
		border = Color(tone, 0.88 * _breath())
	elif t == "buff":
		border = Color(tone, 0.70)
	border = border.lerp(XUiSkin.GOLD_LIGHT, _flash_k(str(r.id)))
	_pill(rect, fill, border)
	var cy := rect.position.y + rect.size.y / 2.0
	# 左侧 3px 语义竖棱
	draw_rect(Rect2(rect.position.x + 5.0, cy - rect.size.y * 0.28, 3.0, rect.size.y * 0.56), tone)
	var cx := rect.position.x + 12.0
	var icon: Texture2D = XUiSkin.icon(int(r.icon)) if int(r.icon) > 0 else null
	if icon != null:
		draw_texture_rect(icon, Rect2(cx, cy - 10.0, 20.0, 20.0), false)
		cx += 24.0
	var base := XUiSkin.text_baseline_y(cy, fs)
	var name := XSkinNoticeLane.ellipsize(str(r.name), font, fs, CHIP_NAME_MAX)
	XUiSkin.ds(self, font, Vector2(cx, base), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_HI)
	cx += _tw(name, fs) + 6.0
	if str(r.counter) != "":
		XUiSkin.ds(self, nf, Vector2(cx, base), str(r.counter), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _counter_color(r))


# ---- 详卡 ----

func _update_drawer_anim() -> void:
	if not _drawer.visible:
		return
	var m := XUiSkin.motion()
	_layout_items(DRAWER_W_BIG if _fm() >= 1.2 else DRAWER_W)
	var r := drawer_rect()
	var a := 1.0
	var dy := 0.0
	if open:
		var t := _now - _open_t
		if m == XUiSkin.Motion.FULL:
			var k := clampf(t / 0.18, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - k, 4.0)
			a = e
			dy = -8.0 * (1.0 - e)
		elif m == XUiSkin.Motion.SIMPLE:
			a = clampf(t / 0.12, 0.0, 1.0)
	else:
		var t2 := _now - _close_t
		a = 0.0 if m == XUiSkin.Motion.OFF else clampf(1.0 - t2 / 0.12, 0.0, 1.0)
		if a <= 0.0:
			_drawer.visible = false
			return
	_drawer.position = r.position + Vector2(0, dy)
	_drawer.size = r.size
	_drawer.modulate.a = a
	_list.position = Vector2(0, PAD + TOP_H + 8.0)
	_list.size = Vector2(r.size.x, r.size.y - (PAD + TOP_H + 8.0) - (FOOT_H + PAD))
	_layout_items(r.size.x)
	scroll = clampf(scroll, 0.0, _max_scroll())


## 每条的高度（顺带算总高）
func _layout_items(w: float) -> Array:
	var out := []
	var font := XUiSkin.font("body")
	var tw := w - PAD * 2.0 - 14.0 - 8.0
	var y := 0.0
	for r in rules:
		var h := 8.0 + _fs(17) * 1.5
		var sum_lines: Array = XSkinText.wrap_lines(str(r.summary), font, _fs(15), tw)
		if sum_lines.size() > 3:
			sum_lines = sum_lines.slice(0, 3)
			sum_lines[2] = XSkinNoticeLane.ellipsize(str(sum_lines[2]) + "……", font, _fs(15), tw)
		h += sum_lines.size() * _fs(15) * 1.5
		var ex_lines: Array = []
		if str(r.detail_extra) != "":
			ex_lines = XSkinText.wrap_lines(str(r.detail_extra), font, _fs(14), tw)
			h += ex_lines.size() * _fs(14) * 1.5
		if float(r.max_value) > 0.0:
			h += 10.0
		h += 8.0
		out.append({"y": y, "h": h, "sum": sum_lines, "extra": ex_lines})
		y += h + 4.0
	_content_h = maxf(0.0, y - 4.0)
	return out


func _draw_drawer() -> void:
	var c := _drawer
	var sz := c.size
	var r := Rect2(Vector2.ZERO, sz)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(XUiSkin.panel_c(), 0.95)
	sb.border_color = Color(XUiSkin.line_c(), 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	c.draw_style_box(sb, r)
	var font := XUiSkin.font("body")
	# 顶栏
	var ty := PAD + TOP_H / 2.0
	var x := PAD
	c.draw_colored_polygon(PackedVector2Array([Vector2(x + 4, ty - 5), Vector2(x + 9, ty), Vector2(x + 4, ty + 5), Vector2(x - 1, ty)]), XUiSkin.GOLD)
	x += 14.0
	var tfs := _fs(18)
	XUiSkin.ds(c, font, Vector2(x, XUiSkin.text_baseline_y(ty, tfs)), "本场规则", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, XUiSkin.GOLD_LIGHT)
	x += _tw("本场规则", tfs) + 10.0
	var cnt := "%d 条" % rules.size()
	var cfs := _fs(14)
	var cw := XUiSkin.font("num").get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
	if source != "":
		var sfs := _fs(13)
		var label := XSkinNoticeLane.ellipsize(source, font, sfs, sz.x - x - PAD - cw - 24.0)
		var sw := _tw(label, sfs) + 16.0
		var pr := Rect2(x, ty - 10.0, sw, 20.0)
		var psb := StyleBoxFlat.new()
		psb.bg_color = Color(XUiSkin.panel_low_c(), 0.9)
		psb.border_color = Color(XUiSkin.line_c(), 0.35)
		psb.set_border_width_all(1)
		psb.set_corner_radius_all(10)
		c.draw_style_box(psb, pr)
		XUiSkin.ds(c, font, Vector2(x, XUiSkin.text_baseline_y(ty, sfs)), label, HORIZONTAL_ALIGNMENT_CENTER, sw, sfs, XUiSkin.text2_c())
	XUiSkin.ds(c, XUiSkin.font("num"), Vector2(sz.x - PAD - cw, XUiSkin.text_baseline_y(ty, cfs)), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, XUiSkin.text2_c())
	XUiSkin.draw_title_accent(c, PAD, PAD + TOP_H + 2.0)
	# 底脚
	var fy := sz.y - PAD - FOOT_H / 2.0
	XUiSkin.draw_divider(c, PAD, sz.x - PAD, sz.y - PAD - FOOT_H)
	var ffs := _fs(13)
	var left := ""
	var right := ""
	var over := _max_scroll() > 0.0
	match XUiSkin.current_input_mode():
		XUiSkin.InputMode.GAMEPAD:
			left = ("↑↓ 浏览 · " if over else "") + "LB / B 收起"
		XUiSkin.InputMode.TOUCH:
			left = "拖动浏览 · 点外侧收起" if over else "点规则条／外侧收起"
		_:
			left = ("↑↓ 浏览 · " if over else "") + "R / Esc 收起"
			right = "点外侧收起"
	XUiSkin.ds(c, font, Vector2(PAD, XUiSkin.text_baseline_y(fy, ffs)), left, HORIZONTAL_ALIGNMENT_LEFT, -1, ffs, XUiSkin.text2_c())
	if right != "":
		XUiSkin.ds(c, font, Vector2(sz.x - PAD - _tw(right, ffs), XUiSkin.text_baseline_y(fy, ffs)), right, HORIZONTAL_ALIGNMENT_LEFT, -1, ffs, XUiSkin.TEXT_3)


func _draw_list() -> void:
	var c := _list
	var w := c.size.x
	var items := _layout_items(_drawer.size.x)
	var font := XUiSkin.font("body")
	var nf := XUiSkin.font("num")
	for i in rules.size():
		var r: Dictionary = rules[i]
		var it: Dictionary = items[i]
		var top := float(it.y) - scroll
		var h := float(it.h)
		if top + h < 0.0 or top > c.size.y:
			continue
		var x0 := PAD
		var tone := tone_color(r)
		var card := Rect2(x0, top, w - PAD * 2.0 - 8.0, h)
		if str(r.tone) == "warn":
			var bg := Color(tone, 0.11)
			c.draw_polygon(PackedVector2Array([card.position, card.position + Vector2(card.size.x, 0), card.end, card.position + Vector2(0, card.size.y)]),
				PackedColorArray([bg, Color(tone, 0.0), Color(tone, 0.0), bg]))
		c.draw_rect(Rect2(x0, top + 4.0, 3.0, h - 8.0), tone)
		var tx := x0 + 14.0
		var nfs := _fs(17)
		var row_cy := top + 8.0 + nfs * 0.75
		var icon: Texture2D = XUiSkin.icon(int(r.icon)) if int(r.icon) > 0 else null
		if icon != null:
			c.draw_texture_rect(icon, Rect2(tx, row_cy - 12.0, 24.0, 24.0), false)
			tx += 30.0
		var cnt := str(r.counter)
		var cfs := _fs(16)
		var cw := nf.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x if cnt != "" else 0.0
		var name_max := card.end.x - tx - cw - 16.0
		var badge := str(r.badge)
		var bfs := _fs(12)
		var bw := _tw(badge, bfs) + 12.0 if badge != "" else 0.0
		var name := XSkinNoticeLane.ellipsize(str(r.name), font, nfs, maxf(40.0, name_max - (bw + 6.0 if badge != "" else 0.0)))
		XUiSkin.ds(c, font, Vector2(tx, XUiSkin.text_baseline_y(row_cy, nfs)), name, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, XUiSkin.TEXT_HI)
		var bx := tx + _tw(name, nfs) + 6.0
		if badge != "":
			var br := Rect2(bx, row_cy - 9.0, bw, 18.0)
			var bsb := StyleBoxFlat.new()
			bsb.bg_color = Color(XUiSkin.GOLD, 0.10)
			bsb.border_color = Color(XUiSkin.GOLD, 0.55)
			bsb.set_border_width_all(1)
			bsb.set_corner_radius_all(9)
			c.draw_style_box(bsb, br)
			XUiSkin.ds(c, font, Vector2(bx, XUiSkin.text_baseline_y(row_cy, bfs)), badge, HORIZONTAL_ALIGNMENT_CENTER, bw, bfs, XUiSkin.GOLD)
		if cnt != "":
			XUiSkin.ds(c, nf, Vector2(card.end.x - cw - 4.0, XUiSkin.text_baseline_y(row_cy, cfs)), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, _counter_color(r))
		var ly := top + 8.0 + nfs * 1.5
		var sfs := _fs(15)
		for line in it.sum:
			XUiSkin.ds(c, font, Vector2(x0 + 14.0, XUiSkin.text_baseline_y(ly + sfs * 0.75, sfs)), str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, XUiSkin.TEXT)
			ly += sfs * 1.5
		var efs := _fs(14)
		var ec := XUiSkin.down_c() if str(r.tone) == "warn" else XUiSkin.text2_c()
		for line in it.extra:
			XUiSkin.ds(c, font, Vector2(x0 + 14.0, XUiSkin.text_baseline_y(ly + efs * 0.75, efs)), str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, efs, ec)
			ly += efs * 1.5
		if float(r.max_value) > 0.0:
			var ratio := clampf(float(r.value) / float(r.max_value), 0.0, 1.0)
			XUiSkin.draw_gauge(c.get_canvas_item(), Rect2(x0 + 14.0, ly + 3.0, card.size.x - 18.0, 4.0), ratio, tone)
		if i < rules.size() - 1:
			XUiSkin.draw_divider(c, x0, card.end.x, top + h + 2.0, false, 0.6)
	# 底缘渐隐＋滚动条
	if _max_scroll() > 0.0:
		var fade_h := 24.0
		var bot := c.size.y
		var col := Color(XUiSkin.panel_c(), 0.95)
		c.draw_polygon(PackedVector2Array([Vector2(0, bot - fade_h), Vector2(w, bot - fade_h), Vector2(w, bot), Vector2(0, bot)]),
			PackedColorArray([Color(col, 0.0), Color(col, 0.0), col, col]))
		var track := Rect2(w - PAD - 5.0, 0, 5.0, c.size.y)
		var th := maxf(24.0, c.size.y * c.size.y / maxf(1.0, _content_h))
		var ty := (c.size.y - th) * (scroll / _max_scroll())
		XUiSkin.draw_scrollbar(c, track, ty, th)
