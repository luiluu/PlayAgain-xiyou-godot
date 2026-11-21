class_name XSkinCard
extends Control
## 【cc·天启篇·未经审查】详情牌：黑面板上从上往下排 图标＋名字（思源宋体，品质色）、一行辅助小字、说明（自动换行）、
## 若干分节（旧金小标题＋左名右值的行，或一段文字）、底部一排按钮（主按钮绯红渐变，焦点按钮带红乙选中条）。
## 内容太长时从下往上裁（说明、分节被按钮挡住的部分不画）；按钮总在底部。
## T288 卡 S（长说明卡分节）：分节多两种写法——cells（两列「名 值」格子）、行的 dim（还没到的分支画暗字），节可带 size（字号，行距 1.6 倍）；
## fold 开时放不下不再硬裁：牌底 56 高渐隐＋「Y 看完整说明 ▾」，按 Y 或点这一条，牌向左展开成 2 倍宽、整高（expand_bounds），
## 再按 Y／点一下／取消收回；展开后还放不下就能滚（手指拖、滚轮、上下键）。fold 关（默认）时画法与之前一样。

signal button_pressed(index: int)
signal expanded_changed(on: bool)

var icon: Texture2D
var title := ""
var title_color := XUiSkin.TEXT
var title_size := XUiSkin.FS_CARD
var subtitle := ""
var notice := ""
var desc := ""
## [{title, lines: [{left, right, color, right_color}]}] 或 [{title, text}] 或 [{title, rows: [{text, color, spans, dim}]}]（每行自动换行、各自颜色；title 可空）
## 或 [{title, cells: [[名, 值], …]}]（T288：两列格子，名次要字、值正文；一格放不下半宽就独占一行）；各节可带 size（rows／cells 的字号）
var sections: Array = []
## 底部按钮之上给别的控件（如「给谁用」目标列表）留的高度：说明、分节画到这里为止
var reserve_bottom := 0.0
## [{text, primary, disabled}]（disabled：变暗、不触发）
var buttons: Array = []
var button_index := -1
var pad := XUiSkin.PAD_LG
## T024 选中放大：焦点按钮的字放大（按钮框不变，字放不下就不放大）
var sel_scale: XSkinSelScale
const BUTTON_H := 46.0
const LINE_H := 30.0
const SECTION_H := 36.0

## ---- T288 长说明卡 ----
## 牌边描边色（透明＝不画；说明卡按品质上色）
var border_color := Color(0, 0, 0, 0)
## 放不下时渐隐＋「看完整说明」可展开；false＝照旧从下面裁
var fold := false
## 展开后牌的上下沿（画布坐标）
var expand_bounds := Vector2(XUiSkin.TOP, XUiSkin.BOTTOM)
## 展开时向左展开成 2 倍宽；false＝宽度不变、只往上下长（战斗详情卡：不盖住战技列表和角色，小A核 P2-1）
var expand_wide := true
var expanded := false
var scroll := 0.0
const FADE_H := 56.0
const STRIP_H := 40.0
const SCROLL_STEP := 54.0
var _overflow := false
var _max_scroll := 0.0
var _content_key := ""
var _sheet: Control
## 画的时候：_top_cut 以上、_cut_y 以下的行不画；_fade_y 往下的行渐淡（牌底渐隐）
var _top_cut := -INF
var _cut_y := INF
var _fade_y := INF
var _drag := XSkinDrag.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	sel_scale = XSkinSelScale.attach(self)
	resized.connect(queue_redraw)


func setup(d: Dictionary) -> XSkinCard:
	for k in d:
		set(k, d[k])
	if not fold:   # fold 由真切假（如技能页切到渡鸦账本说明）：展开的牌收掉，Y／取消回到页面（小A核 P2-2）
		_overflow = false
		if expanded:
			set_expanded(false)
	else:
		var key := str([title, subtitle, desc, sections])
		if key != _content_key:   # 换了一张牌：收起、回到顶
			_content_key = key
			scroll = 0.0
			if expanded:
				set_expanded(false)
	queue_redraw()
	return self


## 说明、分节能画到的最低处（按钮和 reserve_bottom 之上）
func content_bottom() -> float:
	return size.y - pad - (BUTTON_H + XUiSkin.GRID if not buttons.is_empty() else 0.0) - reserve_bottom


func button_rect(i: int) -> Rect2:
	var n := buttons.size()
	if n == 0:
		return Rect2()
	var w := (size.x - pad * 2 - XUiSkin.GRID * (n - 1)) / n
	return Rect2(pad + i * (w + XUiSkin.GRID), size.y - pad - BUTTON_H, w, BUTTON_H)


## 牌宽 width 时内容（不裁）要多高：牌头＋各节＋上下内边距＋按钮
func natural_height(width: float) -> float:
	var y := _body(self, pad, pad, width - pad * 2, INF, true)
	return y + pad + (BUTTON_H + XUiSkin.GRID if not buttons.is_empty() else 0.0) + reserve_bottom


## 收起时牌底「看完整说明」这一条（整条可点）
func strip_rect() -> Rect2:
	var cb := content_bottom()
	return Rect2(0, cb - FADE_H + 8.0, size.x, FADE_H + pad - 8.0)


func can_expand() -> bool:
	return fold and _overflow


func set_expanded(on: bool) -> void:
	if on == expanded:
		return
	expanded = on
	scroll = 0.0
	if on:
		if _sheet == null:
			_sheet = Control.new()
			_sheet.clip_contents = true
			_sheet.z_index = 20
			_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
			_sheet.draw.connect(_draw_sheet)
			_sheet.gui_input.connect(_sheet_input)
			add_child(_sheet)
		var r := expanded_rect()
		_sheet.position = r.position
		_sheet.size = r.size
		_sheet.visible = true
		_sheet.queue_redraw()
	elif _sheet != null:
		_sheet.visible = false
	_drag.release()
	queue_redraw()
	expanded_changed.emit(on)


## 展开后的牌（本牌坐标）：右沿不动向左展开成 2 倍宽（画面放不下就贴左边 16），上下取 expand_bounds
func expanded_rect() -> Rect2:
	var g := get_global_rect().position if is_inside_tree() else position
	var vw := get_viewport_rect().size.x if is_inside_tree() else 1280.0
	var w2 := minf(size.x * (2.0 if expand_wide else 1.0), vw - 32.0)
	var x := clampf(g.x + size.x - w2, 16.0, maxf(16.0, vw - 16.0 - w2))
	return Rect2(Vector2(x, expand_bounds.x) - g, Vector2(w2, maxf(0.0, expand_bounds.y - expand_bounds.x)))


func scroll_by(dy: float) -> void:
	scroll = clampf(scroll + dy, 0.0, _max_scroll)
	if _sheet != null:
		_sheet.queue_redraw()


static func _is_y(event: InputEvent) -> bool:
	if event is InputEventKey:
		var k := event as InputEventKey
		return k.pressed and not k.echo and k.keycode == KEY_Y
	if event is InputEventJoypadButton:
		var j := event as InputEventJoypadButton
		return j.pressed and j.button_index == JOY_BUTTON_Y
	return false


## Y 展开／收起、展开时上下键滚动、取消收回：在页面收键之前先看（只在可展开或已展开时管）
func _input(event: InputEvent) -> void:
	if not fold or not is_visible_in_tree() or not (expanded or _overflow):
		return
	if _is_y(event):   # Y 只管展开／收回这张牌，不放行给页面（战斗里不再顺带关详情，小A核 P2-1）
		set_expanded(not expanded)
		XSound.system(0)
		XKeyMap.handled(self)
		return
	if not expanded:
		return
	if event.is_action_pressed("ui_accept"):   # 展开时确定键不落到下面的列表（防误放技能、误用物品）
		XKeyMap.handled(self)
	elif event.is_action_pressed("ui_cancel"):
		set_expanded(false)
		XKeyMap.handled(self)
	elif event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true):
		scroll_by(-SCROLL_STEP if event.is_action("ui_up") else SCROLL_STEP)
		XKeyMap.handled(self)


## 处理按钮的方向键／确定（页面焦点在牌上时转进来）
func handle_input(event: InputEvent) -> bool:
	if buttons.is_empty():
		return false
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		var d := -1 if event.is_action("ui_left") else 1
		button_index = 0 if button_index < 0 else posmod(button_index + d, buttons.size())   # 第一次按左右先落到第一个按钮
		queue_redraw()
		return true
	if event.is_action_pressed("ui_accept") and button_index >= 0:
		if not bool(buttons[button_index].get("disabled", false)):
			button_pressed.emit(button_index)
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in buttons.size():
			if button_rect(i).has_point(event.position):
				button_index = i
				queue_redraw()
				if not bool(buttons[i].get("disabled", false)):
					button_pressed.emit(i)
				accept_event()
				return
		if can_expand() and not expanded and strip_rect().has_point(event.position):
			set_expanded(true)
			XSound.system(0)
			accept_event()


## 展开的牌：滚轮、手指拖滚动；点一下（没拖）收回
func _sheet_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			scroll_by(-SCROLL_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else SCROLL_STEP)
			_sheet.accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag.press(mb.position, scroll)
			elif _drag.release():
				set_expanded(false)
				XSound.system(0)
			_sheet.accept_event()
	elif event is InputEventMouseMotion and _drag.active():
		var to := _drag.motion((event as InputEventMouseMotion).position)
		if not is_nan(to):
			scroll_by(to - scroll)
		_sheet.accept_event()


func _draw() -> void:
	if expanded:
		return   # 展开时由 _sheet 画整张
	var ci := get_canvas_item()
	var pol := XUiSkin.polish_on()
	XUiSkin.shadow_style().draw(ci, Rect2(Vector2.ZERO, size))
	XUiSkin.panel_style().draw(ci, Rect2(Vector2.ZERO, size))
	_draw_border(ci, Rect2(Vector2.ZERO, size))
	if pol and size.x >= 260.0 and size.y >= 240.0:
		var seal := XSkinArt.part("seven_seal_128x128")
		if seal != null:
			var bottom_y := content_bottom()
			var sr := Rect2(Vector2(size.x - 108.0 - pad * 0.5, maxf(pad, bottom_y - 104.0)).round(), Vector2(108.0, 108.0))
			draw_texture_rect(seal, sr, false, Color(0.95, 0.84, 0.62, 0.055))
	var bottom := content_bottom()
	_overflow = false
	if fold:
		_overflow = natural_height(size.x) > size.y + 0.5
	if _overflow:
		_fade_y = bottom - FADE_H
		_body(self, pad, pad, size.x - pad * 2, bottom - 20.0, false)
		_fade_y = INF
		_draw_strip(self, Rect2(0, bottom - 24.0, size.x, 24.0), _strip_text(false))
	else:
		_body(self, pad, pad, size.x - pad * 2, bottom, false)
	sel_scale.sel(button_index if button_index >= 0 and button_index < buttons.size() else null)
	var body := XUiSkin.font("body")
	for i in buttons.size():
		var r := button_rect(i)
		var b: Dictionary = buttons[i]
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(BUTTON_H / 2))
		if bool(b.get("primary", false)) and not bool(b.get("disabled", false)):
			XUiSkin.primary_button_style(sb, i == button_index)
		else:
			sb.bg_color = Color(0.06, 0.05, 0.048, 0.38) if pol else Color(0, 0, 0, 0)
			sb.border_color = Color(XUiSkin.line_c(), 0.52) if pol else Color(XUiSkin.LINE, 0.55)
			sb.set_border_width_all(1)
		sb.draw(ci, r)
		if i == button_index:
			XUiSkin.draw_select(ci, r.grow(3), XUiSkin.breath_alpha())
		var t := str(b.get("text", ""))
		var bfs := XSkinSelScale.fs(XUiSkin.FS_LIST, sel_scale.k(i), floori(r.size.y * 0.66))
		var tw := body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
		if bfs != XUiSkin.FS_LIST and tw > r.size.x - 12.0:
			bfs = XUiSkin.FS_LIST
			tw = body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
		XUiSkin.ds(self, body, Vector2(r.position.x + (r.size.x - tw) / 2.0, r.position.y + r.size.y / 2.0 + bfs * 0.36), t,
			HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, XUiSkin.TEXT_3 if bool(b.get("disabled", false)) else XUiSkin.TEXT)


func _draw_border(ci: RID, r: Rect2) -> void:
	if border_color.a <= 0.0:
		return
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = border_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(XUiSkin.RADIUS)
	sb.draw(ci, r)


## 展开的牌：整张面板＋内容（往上滚 scroll）＋牌底「收起」一条；_sheet 自己裁掉出界的部分
func _draw_sheet() -> void:
	var s := _sheet
	var r := Rect2(Vector2.ZERO, s.size)
	var ci := s.get_canvas_item()
	var pol := XUiSkin.polish_on()
	XUiSkin.panel_style().draw(ci, r)
	s.draw_rect(r, Color(XUiSkin.panel_low_c(), 0.62 if pol else 0.55))   # 压在下面的列表上，面板要不透明些
	_draw_border(ci, r)
	var bottom := s.size.y - pad - STRIP_H
	_top_cut = pad
	_cut_y = bottom
	_fade_y = bottom - 28.0 if scroll < _max_scroll - 0.5 else INF
	var end := _body(s, pad, pad - scroll, s.size.x - pad * 2, INF, false)
	_top_cut = -INF
	_cut_y = INF
	_fade_y = INF
	_max_scroll = maxf(0.0, end + scroll - bottom)
	scroll = clampf(scroll, 0.0, _max_scroll)
	if _max_scroll > 0.0:   # 右边一条细滚动条（美化态拓宽至 6px 圆角暖金）
		var track := bottom - pad
		var th := maxf(24.0, track * track / (track + _max_scroll))
		var ty := pad + (track - th) * (scroll / _max_scroll)
		if pol:
			XUiSkin.draw_scrollbar(s, Rect2(s.size.x - 10.0, pad, 6.0, track), ty, th)
		else:
			s.draw_rect(Rect2(s.size.x - 6.0, ty, 3.0, th), Color(XUiSkin.LINE, 0.45))
	XUiSkin.draw_divider(s, pad, s.size.x - pad, bottom + 6.0, false, 1.0)
	_draw_strip(s, Rect2(0, bottom + 6.0, s.size.x, s.size.y - pad * 0.5 - bottom - 6.0), _strip_text(true))


func _strip_text(open: bool) -> String:
	var touch := XSkinKeyHints.touch_mode()
	if open:
		return "收起 ▴" if touch else "Y 收起 ▴"
	return "看完整说明 ▾" if touch else "Y 看完整说明 ▾"


## 牌底居中一行提示（「看完整说明 ▾」「收起 ▴」），r 是这一条
func _draw_strip(t: Control, r: Rect2, text: String) -> void:
	var body := XUiSkin.font("body")
	var fs := XUiSkin.FS_AUX
	var tw := body.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	XUiSkin.ds(t, body, Vector2(r.position.x + (r.size.x - tw) / 2.0, r.position.y + r.size.y / 2.0 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_2)


## 这一行（y 起、高 lh）画多亮：0＝不画（在 _top_cut 之上或 _cut_y 之下）；_fade_y 往下渐淡
func _vis(y: float, lh: float) -> float:
	if y < _top_cut - 2.0 or y + lh > _cut_y + 0.5:
		return 0.0
	if y + lh > _fade_y:
		return clampf(1.0 - (y + lh - _fade_y) / FADE_H, 0.12, 1.0)
	return 1.0


func _fa(c: Color, a: float) -> Color:
	return Color(c, c.a * a) if a < 1.0 else c


## 牌头＋各节，从 (x0, y) 往下排，宽 w；画在 t 上（dry：只量不画）。bottom 以下的不画（行、节放不下就停）；
## 展开滚动、渐隐时按 _vis 定每行画不画、多亮。返回排完的 y。
func _body(t: Control, x0: float, y: float, w: float, bottom: float, dry: bool) -> float:
	var body := XUiSkin.font("body")
	var head := XUiSkin.font("title")
	var num := XUiSkin.font("num")
	var pol := XUiSkin.polish_on()
	var x := x0
	if icon != null:
		if not dry and _vis(y, 48.0) > 0.0:
			t.draw_texture_rect(icon, XUiSkin.inline_icon_rect(x, y + 24.0, 48.0, title_size) if XUiSkin.detail_on() else Rect2(x, y, 48, 48), false)
		x += 48 + 12
	if title != "":
		if not dry and _vis(y, 48.0) > 0.0:
			var ty := y + (48 - title_size) / 2.0 + title_size * 0.86 if icon != null else y + title_size * 0.86
			var fit := XSkinList.fit_text(head, title, x0 + w - x, title_size, 20)   # 长名字先缩到 20 号，再放不下加省略号
			XUiSkin.ds(t, head, Vector2(x, ty), fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1], title_color)
		y += maxf(48.0 if icon != null else 0.0, title_size * 1.25)
	if subtitle != "":
		y += 4
		if not dry and _vis(y, XUiSkin.FS_AUX_MAX) > 0.0:
			XUiSkin.ds(t, body, Vector2(x0, y + XUiSkin.FS_AUX_MAX * 0.86), subtitle, HORIZONTAL_ALIGNMENT_LEFT, w, XUiSkin.FS_AUX, XUiSkin.TEXT_2)
		y += XUiSkin.FS_AUX_MAX + 6
	if notice != "":
		y += 6
		var nranges := XSkinText.wrap_ranges(notice, body, XUiSkin.FS_AUX, w - 20.0)   # T338 D2：避头尾＋防孤字
		var nlh := roundf(XUiSkin.FS_AUX * 1.45)
		var ncnt := maxi(1, nranges.size())
		var nh := float(ncnt) * nlh + 10.0
		if y + nh <= bottom:
			if not dry and _vis(y, nh) > 0.0:
				var nsb := StyleBoxFlat.new()
				nsb.bg_color = Color(0.14, 0.105, 0.068, 0.72) if pol else Color(XUiSkin.GOLD, 0.14)
				nsb.border_color = Color(XUiSkin.GOLD, 0.55)
				nsb.set_border_width_all(1)
				nsb.set_corner_radius_all(XUiSkin.ROW_RADIUS)
				nsb.draw(t.get_canvas_item(), Rect2(x0, y, w, nh))
				if pol:
					t.draw_rect(Rect2(x0 + 1.0, y + 4.0, 2.5, maxf(4.0, nh - 8.0)), Color(XUiSkin.GOLD, 0.85))
				for li in nranges.size():
					var r := nranges[li]
					XUiSkin.ds(t, body, Vector2(x0 + 10.0, y + 5.0 + float(li) * nlh + XUiSkin.FS_AUX * 0.96), notice.substr(r.x, r.y - r.x), HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, XUiSkin.FS_AUX, XUiSkin.GOLD_LIGHT)
			y += nh + 4
	if desc != "":
		y += 8
		for part in (desc.split("\n", false) if fold else PackedStringArray([desc])):
			y = _paragraph(t, body, part, y, x0, w, XUiSkin.FS_AUX_MAX, XUiSkin.TEXT_2 if fold else XUiSkin.TEXT, bottom, [], dry)
	for sec in sections:
		if y + SECTION_H > bottom:
			break
		var big: bool = sec.has("size")
		var fs := int(sec.get("size", XUiSkin.FS_AUX))
		var lh := roundf(fs * 1.6) if big else -1.0
		y += 6
		var va := _vis(y, SECTION_H)
		if not dry and va > 0.0:
			XUiSkin.draw_divider(t, x0, x0 + w, y, false, va)
		y += 4
		if str(sec.get("title", "")) != "":
			if not dry and va > 0.0:
				var sx := x0
				if pol:
					t.draw_rect(Rect2(x0, y + XUiSkin.FS_AUX_MAX * 1.1 - 12.0, 2.0, 12.0), _fa(Color(XUiSkin.GOLD, 0.88), va))
					sx += 7.0
				XUiSkin.ds(t, body, Vector2(sx, y + XUiSkin.FS_AUX_MAX * 1.1), str(sec.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, w - (sx - x0), XUiSkin.FS_AUX_MAX, _fa(XUiSkin.GOLD, va))
			y += SECTION_H - 10
		for row in sec.get("rows", []):
			var col: Color = XUiSkin.TEXT_3 if bool(row.get("dim", false)) else row.get("color", XUiSkin.TEXT_2)
			y = _paragraph(t, body, str(row.get("text", "")), y, x0, w, fs, col, bottom, row.get("spans", []), dry, lh)
		if sec.has("cells"):
			y = _cells(t, body, sec.cells, y, x0, w, fs, roundf(fs * 1.6), bottom, dry)
		if sec.has("text"):
			y = _paragraph(t, body, str(sec.text), y, x0, w, XUiSkin.FS_AUX, XUiSkin.TEXT_2, bottom, [], dry)
		var lfs := XUiSkin.FS_AUX if LINES_V2 else 15
		var nfs := XUiSkin.fs(21) if LINES_V2 else 21
		var llh := line_h()
		for ln in sec.get("lines", []):
			if y + llh > bottom:
				break
			if not dry and _vis(y, llh) > 0.0:
				var base := y + llh / 2.0
				XUiSkin.ds(t, body, Vector2(x0, base + lfs * 0.36), str(ln.get("left", "")), HORIZONTAL_ALIGNMENT_LEFT, w * 0.6, lfs, ln.get("color", XUiSkin.TEXT_2))
				var rt := str(ln.get("right", ""))
				if rt != "":
					# 右标签：带汉字（「现在」「默认」）走正文字、同左边字号（T300 小A核 P2-4）；数字和符号（→▲▼✓✗）照旧窄体数字字（T304 小A核 P2-1）
					var rf: Font = body if LINES_V2 and _has_cjk(rt) else num
					var rfs := lfs if rf == body and LINES_V2 else nfs
					var rw := rf.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs).x
					XUiSkin.ds(t, rf, Vector2(x0 + w - rw, base + rfs * 0.36), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, ln.get("right_color", XUiSkin.TEXT))
			y += llh
	return y


## T300 小A核 P2-4：「可选」这类 lines 节的字号跟字体大小设置（左 FS_AUX、右数字 fs(21)），行高随字号撑开（130% 时 30→34）。
## false＝写死 15／21、行高 30（旧）
static var LINES_V2 := true


## lines 节的行高：不小于 LINE_H，字号放大时按数字字号×1.25 撑开
static func line_h() -> float:
	return maxf(LINE_H, roundf(XUiSkin.fs(21) * 1.25)) if LINES_V2 else LINE_H


static func _has_cjk(t: String) -> bool:
	for k in t.length():
		var c := t.unicode_at(k)
		if (c >= 0x4e00 and c <= 0x9fff) or (c >= 0x3400 and c <= 0x4dbf) or (c >= 0xf900 and c <= 0xfaff):
			return true
	return false


## 两列「名 值」格子：名次要字、值正文，两格一行；一格比半宽还宽就独占一行（再长自动换行）
func _cells(t: Control, f: Font, cells: Array, y: float, x0: float, w: float, fs: int, lh: float, bottom: float, dry: bool) -> float:
	var half := w / 2.0
	var col := 0
	for c in cells:
		var nm := str(c[0])
		var val := str(c[1]) if c.size() > 1 else ""
		var nw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cw := nw + (8.0 + f.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if val != "" else 0.0)
		if cw > half - 8.0:
			if col == 1:
				y += lh
				col = 0
			var spans := [[nm + ("　" if val != "" else ""), XUiSkin.TEXT_2], [val, XUiSkin.TEXT]]
			y = _paragraph(t, f, nm + ("　" if val != "" else "") + val, y, x0, w, fs, XUiSkin.TEXT, bottom, spans, dry, lh)
			continue
		if col == 0 and y + lh > bottom:
			return y
		var a := _vis(y, lh)
		if not dry and a > 0.0:
			var cx := x0 + half * col
			var by := y + fs * 1.1 + (lh - roundf(fs * 1.5)) / 2.0
			XUiSkin.ds(t, f, Vector2(cx, by), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _fa(XUiSkin.TEXT_2, a))
			if val != "":
				XUiSkin.ds(t, f, Vector2(cx + nw + 8.0, by), val, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _fa(XUiSkin.TEXT, a))
		col += 1
		if col == 2:
			col = 0
			y += lh
	if col == 1:
		y += lh
	return y


## spans（可选）：[[字, 颜色], …] 拼起来＝text，逐段上色（装备「自带」属性分色，T095）
## lh：行距（<0＝字号×1.5，同旧；美化态 100% 字号下略舒展至 1.56，130% 保持 1.5 防溢出）；展开滚动、渐隐按 _vis
func _paragraph(t: Control, f: Font, text: String, y: float, x0: float, w: float, fs: int, col: Color, bottom: float, spans := [], dry := false, lh := -1.0) -> float:
	if lh < 0.0:
		var mult := 1.56 if XUiSkin.polish_on() and XUiSkin.font_mult() <= 1.05 else 1.5
		lh = roundf(fs * mult)
	var ranges := XSkinText.wrap_ranges(text, f, fs, w)   # T338 D2：避头尾＋防孤字（返回字符区间，spans 分色照用）
	var off := (lh - roundf(fs * 1.5)) / 2.0
	for li in ranges.size():
		if y + lh > bottom:
			break
		var a := _vis(y, lh)
		if not dry and a > 0.0:
			var line_text_range := ranges[li]
			if spans.is_empty():
				XUiSkin.ds(t, f, Vector2(x0, y + off + fs * 1.1), text.substr(line_text_range.x, line_text_range.y - line_text_range.x), HORIZONTAL_ALIGNMENT_LEFT, w, fs, _fa(col, a))
			else:
				_span_line(t, f, spans, line_text_range.x, line_text_range.y, Vector2(x0, y + off + fs * 1.1), fs, a)
		y += lh
	return y


## 画一行里 [from, to) 这段字，按 spans 换色
func _span_line(t: Control, f: Font, spans: Array, from: int, to: int, at: Vector2, fs: int, alpha := 1.0) -> void:
	var off := 0
	var x := at.x
	for sp in spans:
		var s := str(sp[0])
		var a := maxi(from, off)
		var b := mini(to, off + s.length())
		if b > a:
			var piece := s.substr(a - off, b - a)
			XUiSkin.ds(t, f, Vector2(x, at.y), piece, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _fa(sp[1], alpha))
			x += f.get_string_size(piece, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		off += s.length()
