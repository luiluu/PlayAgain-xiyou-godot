class_name XSkinPartyStrip
extends Control
## 【cc·天启篇·未经审查】紧凑角色条（主菜单的队伍、战斗右上角）：黑面板里一人一行、行高 60，
## 圆头像 42、名字（18）＋「Lv 等级 · 职业」辅助小字、右上状态图标（最多 4 个）、下面一行血（玫粉）、蓝、TP 三条细量条＋窄体数字。
## 行间 1px 线色 14% 分隔；选中的人用红乙选中条（selectable＝true 时）。
## 每人一份字典 {name, level, cls, face（Texture2D）, hp, mhp, mp, mmp, tp, mtp, states:[图标号]}；from_actor 从 XActor 取。
## p1fix 追加：helper＝天启篇助力位卡（略暗底＋旧金细边＋右上「助力」角标）；placeholder＝空的助力位（只写 name，如「助力位 · 空」）。
## 行比 60 高时（主菜单把队伍框填到中间栏底边），内容在行里竖直居中。

signal index_changed(index: int)
signal activated(index: int)

var members: Array = []
var index := -1
var selectable := false
var row_height := XUiSkin.MEMBER_H
var title := ""
var bar: XSkinSelectBar
## T024 选中放大（selectable 时）：选中那人的圆头像和名字放大，行高不变
var sel_scale: XSkinSelScale
## R15（T287 卡 E）：主菜单、装备页的队伍条不显示 TP（不在战斗里永远是 0），血条蓝条各加宽。默认 true（别处照旧，如战斗里的我方状态详情）；
## 主菜单的由 _enter_tree 认出祖先是 XSkinMainMenu 自动关（skin_main_menu.gd 不在卡 E 范围），装备页自己设 false。XSkinRingNav.INNER_V2＝false 时一律照旧三条
var show_tp := true
## D1c 测试用：最近一次 _draw 每条量条的 [成员号, 键, 量条右缘 x, 数值左缘 x, 数值字号]（旧画法不记）
var last_bars: Array = []
const HEAD := 42.0
## D1c：数值字号基准（跟字号设置缩放）、血／蓝默认预留 5 位、TP 默认 3 位（队里有更大的数就按更大的位数）
const NUM_FS := 17
const HP_DIGITS := 5
const TP_DIGITS := 3
## D1c r1：量条保底宽、数字字号回缩下限（窄栏：数字让量条，不让量条被压到没）
const MIN_BAR := 16.0
const MIN_NUM_FS := 11
const TITLE_H := 44.0
## 助力卡上状态图标从右边让出多少（角标约 42 宽，从行右缘 2 起，右边距 12）
const HELPER_TAG_ROOM := 36.0


func _enter_tree() -> void:
	var n := get_parent()
	while n != null:
		if n is XSkinMainMenu:
			show_tp = false
			return
		n = n.get_parent()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	bar = XSkinSelectBar.new()
	add_child(bar, false, Node.INTERNAL_MODE_FRONT)
	bar.visible = false
	sel_scale = XSkinSelScale.attach(self)
	resized.connect(queue_redraw)


static func from_actor(a: XActor) -> Dictionary:
	var d := a.data()
	var states := []
	for st in a.states():
		var ic := int(st.get("iconIndex", 0))
		if ic > 0:
			states.append(ic)
	return {"name": a.display_name(), "level": a.level, "cls": str(a.class_data().get("name", "")),
		"face": XUiSkin.face(str(d.get("faceName", "")), int(d.get("faceIndex", 0))),
		"hp": a.hp, "mhp": a.mhp, "mp": a.mp, "mmp": a.mmp, "tp": a.tp, "mtp": a.max_tp(), "states": states,
		"look": XTianqiSkinShow.look_seal(a)}   # 天启篇七印外观（3A，#81）：头像外圈本印颜色＋小印


func set_members(arr: Array) -> void:
	members = arr
	custom_minimum_size.y = top_y() + members.size() * row_height + 8
	if index >= members.size():
		index = members.size() - 1
	_place_bar(true)
	queue_redraw()


func top_y() -> float:
	return TITLE_H if title != "" else 4.0


func row_rect(i: int) -> Rect2:
	return Rect2(4, top_y() + i * row_height, size.x - 8, row_height)


func select(i: int) -> void:
	if members.is_empty():
		return
	i = clampi(i, 0, members.size() - 1)
	if i == index:
		return
	index = i
	_place_bar(false)
	index_changed.emit(index)


func _place_bar(instant: bool) -> void:
	if bar == null:
		return
	bar.visible = selectable and index >= 0 and index < members.size()
	if bar.visible:
		bar.move_to(row_rect(index).grow(-2), instant)


func handle_input(event: InputEvent) -> bool:
	if not selectable or members.is_empty():
		return false
	if event.is_action_pressed("ui_up", true):
		select(posmod(index - 1, members.size()))
		return true
	if event.is_action_pressed("ui_down", true):
		select(posmod(index + 1, members.size()))
		return true
	if event.is_action_pressed("ui_accept") and index >= 0:
		activated.emit(index)
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	if not selectable:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in members.size():
			if row_rect(i).has_point(event.position):
				bar.press()
				if i == index:
					activated.emit(i)
				else:
					select(i)
				accept_event()
				return


func _draw() -> void:
	var ci := get_canvas_item()
	XUiSkin.shadow_style().draw(ci, Rect2(Vector2.ZERO, size))
	XUiSkin.panel_style().draw(ci, Rect2(Vector2.ZERO, size))
	var head := XUiSkin.font("title")
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	if title != "":
		XUiSkin.ds(self, head, Vector2(16, 10 + 21 * 0.9), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, XUiSkin.GOLD)
	sel_scale.sel(index if selectable and index >= 0 else null)
	last_bars = []
	for i in members.size():
		var m: Dictionary = members[i]
		var r := row_rect(i)
		var sk := sel_scale.k(i)
		if i > 0:
			XUiSkin.draw_divider(self, r.position.x + 10, r.end.x - 10, r.position.y)
		if bool(m.get("helper", false)):
			_draw_helper_frame(ci, r, head)
			if bool(m.get("placeholder", false)):
				var hc0 := Vector2(r.position.x + 14 + HEAD / 2.0, r.position.y + r.size.y / 2.0)
				draw_circle(hc0, HEAD / 2.0, Color(XUiSkin.line_c(), 0.4), false, 1.5, true)
				XUiSkin.ds(self, body, Vector2(hc0.x - 6, hc0.y + 8), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, XUiSkin.TEXT_3)
				XUiSkin.ds(self, body, Vector2(r.position.x + 14 + HEAD + 12, hc0.y + 18 * 0.36), str(m.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, XUiSkin.TEXT_2)
				continue
		# 行比 60 高：内容竖直居中
		r = Rect2(r.position.x, r.position.y + floorf((r.size.y - XUiSkin.MEMBER_H) / 2.0), r.size.x, XUiSkin.MEMBER_H)
		var hc := Vector2(r.position.x + 14 + HEAD / 2.0, r.position.y + r.size.y / 2.0)
		var hr := HEAD / 2.0 * sk
		draw_circle(hc, hr, XUiSkin.orb_low_c())
		var face: Texture2D = m.get("face")
		if face != null:
			XSkinPartyStrip.draw_round_texture(self, face, hc, hr - 2.0)
		draw_circle(hc, hr, Color(XUiSkin.line_c(), 0.65), false, 1.5, true)
		XTianqiSkinShow.draw_look(self, str(m.get("look", "")), hc, hr)
		var x := r.position.x + 14 + HEAD + 12
		var right := r.end.x - 12
		var y1 := r.position.y + 6 + 18
		var fit := name_fit(body, str(m.get("name", "")), int(m.get("level", 1)), right - x - 80)
		if sk > 1.0:   # 放大后还放得下才放大（放不下照旧）
			var bfs := XSkinSelScale.fs(int(fit[1]), sk, 22)
			if body.get_string_size(fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x <= right - x - 80:
				fit = [fit[0], bfs]
		XUiSkin.ds(self, body, Vector2(x, y1), fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1], XUiSkin.TEXT)
		var nw := body.get_string_size(fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1]).x
		var info := "Lv %d" % int(m.get("level", 1))
		if str(m.get("cls", "")) != "":
			info += " · " + str(m.cls)
		XUiSkin.ds(self, body, Vector2(x + nw + 8, y1), info, HORIZONTAL_ALIGNMENT_LEFT, maxf(right - x - nw - 8 - 80, 10), XUiSkin.FS_AUX, XUiSkin.TEXT_2)
		var states: Array = m.get("states", [])
		var sx := right - (HELPER_TAG_ROOM if bool(m.get("helper", false)) else 0.0)   # 助力卡：状态图标让开右上角标（小A核 P3-2）
		for k in range(mini(states.size(), 4)):
			var tex := XUiSkin.icon(int(states[k]))
			sx -= 22
			if tex != null:
				draw_texture_rect(tex, XUiSkin.inline_icon_rect(sx, r.position.y + 17.0, 22.0, XUiSkin.FS_AUX) if XUiSkin.detail_on() else Rect2(sx, r.position.y + 6, 22, 22), false)   # T338 D2：去 y+6 写死
		# 三条量条：血、蓝各 1 份，TP 0.6 份；R15：不在战斗里只画血、蓝两条（各 1 份、加宽）
		var y2 := r.position.y + 6 + 24 + 10
		var avail := right - x
		var specs := [["hp", 1.0, XUiSkin.HP, XUiSkin.HP_TEXT], ["mp", 1.0, XUiSkin.MP, XUiSkin.MP_TEXT]]
		if show_tp or not XSkinRingNav.INNER_V2:
			specs.append(["tp", 0.6, XUiSkin.TP, XUiSkin.TP_TEXT])
		var unit := (avail - 8.0 * (specs.size() - 1)) / (2.6 if specs.size() == 3 else 2.0)
		var bx := x
		var nfs := XUiSkin.fs(NUM_FS)
		if XUiSkin.detail_on():   # D1c r1：窄栏（如 300px 状态页）里数字字号回缩，保住量条保底宽；一行三块用同一字号
			for spec in specs:
				nfs = mini(nfs, fit_fs(num, spec[0], unit * spec[1], members, XUiSkin.fs(NUM_FS)))
		for spec in specs:
			var w: float = unit * spec[1]
			var v := float(m.get(spec[0], 0))
			var mx := float(m.get("m" + spec[0], 0))
			var txt := str(int(v))
			if XUiSkin.detail_on():   # D1c：按当前字号预留定宽数字栏，量条右缘整队齐平，数值右对齐在块右缘
				var col_w := value_col_w(num, nfs, spec[0], members)
				var tk := Rect2(bx, y2 + 2 - XUiSkin.bar_h(spec[0]), maxf(w - col_w - 4, MIN_BAR), XUiSkin.bar_h(spec[0]))
				var rt := clampf(v / mx, 0.0, 1.0) if mx > 0.0 and v > 0.0 else 0.0
				XUiSkin.draw_gauge(ci, tk, rt, spec[2])
				last_bars.append([i, spec[0], tk.end.x, bx + w - num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x, nfs])
				XUiSkin.draw_num_right(self, num, bx + w, y2 + 6, txt, nfs, spec[3])
				bx += w + 8
				continue
			var tw := maxf(num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x, 26)
			var bw := w - tw - 4
			var track := Rect2(bx, y2 + 2 - XUiSkin.bar_h(spec[0]), bw, XUiSkin.bar_h(spec[0]))
			var ratio := clampf(v / mx, 0.0, 1.0) if mx > 0.0 and v > 0.0 else 0.0
			XUiSkin.draw_gauge(ci, track, ratio, spec[2])
			XUiSkin.ds(self, num, Vector2(bx + w - num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x, y2 + 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, spec[3])
			bx += w + 8


## D1c：数值栏宽＝逐位定宽的格宽 × 位数（血蓝至少 5 位、TP 至少 3 位；队里最大值位数更多就取更多）。同一队、同一字号下每人每条同宽，量条右缘因此对齐
static func value_col_w(num: Font, fs: int, key: String, mems: Array) -> float:
	var digits := TP_DIGITS if key == "tp" else HP_DIGITS
	for m in mems:
		digits = maxi(digits, maxi(str(int(m.get("m" + key, 0))).length(), str(int(m.get(key, 0))).length()))
	return XUiSkin.mono_digit_cell(num, fs) * digits


## D1c r1：块宽 w 里数值栏＋4 间距＋量条保底宽放不下时，数字字号从 start 逐级缩到 MIN_NUM_FS（缩到底仍放不下则量条取保底、数字不再缩）
static func fit_fs(num: Font, key: String, w: float, mems: Array, start: int) -> int:
	var fs := start
	while fs > MIN_NUM_FS and value_col_w(num, fs, key, mems) + 4.0 + MIN_BAR > w:
		fs -= 1
	return fs


## 「助力」角标的矩形（行矩形 r 里，右上角）
static func helper_tag_rect(r: Rect2, head: Font) -> Rect2:
	var box := r.grow_individual(-2, -3, -2, -3)
	var tw := head.get_string_size("助力", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	return Rect2(box.end.x - tw - 14, box.position.y, tw + 14, 20)


## 第 k 个状态图标的矩形（行矩形 r 里；_draw 同一算法，测试用）
func state_icon_rect(r: Rect2, k: int, helper: bool) -> Rect2:
	var c := Rect2(r.position.x, r.position.y + floorf((r.size.y - XUiSkin.MEMBER_H) / 2.0), r.size.x, XUiSkin.MEMBER_H)
	var right := c.end.x - 12 - (HELPER_TAG_ROOM if helper else 0.0)
	return Rect2(right - 22 * (k + 1), c.position.y + 6, 22, 22)


## 助力位卡：略暗底＋旧金细边＋右上「助力」角标
func _draw_helper_frame(ci: RID, r: Rect2, head: Font) -> void:
	var box := r.grow_individual(-2, -3, -2, -3)
	if XSkinArt.panel_on():   # 第一期正式美术（小A核 P2-3）：烟底＋七芒暗印＋助力签，不要旧金描边
		XSkinArt.draw_helper(ci, box)
		var tr2 := XSkinArt.helper_tag_rect(box)
		var tw := head.get_string_size("助力", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		XUiSkin.ds(self, head, Vector2(tr2.position.x + (tr2.size.x - tw) / 2.0, tr2.position.y + 17), "助力", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, XUiSkin.TEXT)
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.28)
	sb.border_color = Color(XUiSkin.GOLD, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(XUiSkin.ROW_RADIUS)
	sb.draw(ci, box)
	var tag := "助力"
	var tr := helper_tag_rect(r, head)
	var tb := StyleBoxFlat.new()
	tb.bg_color = Color(XUiSkin.GOLD, 0.9)
	tb.corner_radius_bottom_left = 6
	tb.corner_radius_top_right = XUiSkin.ROW_RADIUS
	tb.draw(ci, tr)
	XUiSkin.ds(self, head, Vector2(tr.position.x + 7, tr.position.y + 15), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, XUiSkin.BG)


## 圆形裁切画图（头像）：圆多边形＋UV；AtlasTexture 换算到整张图的 UV
## 名字放不下时先缩字（≥14）再加省略号，保住后面「Lv 数字」的宽度（小A核查 3A 顺带：「窃格瓦拉·周 Lv」把等级挤掉）。
## avail：名字＋等级能占的宽度。返回 [名字, 字号]
static func name_fit(f: Font, name: String, level: int, avail: float) -> Array:
	var lv := f.get_string_size("Lv %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
	return XSkinList.fit_text(f, name, maxf(avail - lv - 8, 24.0), 18, 14)


static func draw_round_texture(ci: CanvasItem, tex: Texture2D, c: Vector2, r: float, segments := 32, flip_h := false) -> void:
	var src := Rect2(Vector2.ZERO, tex.get_size())
	var base: Texture2D = tex
	if tex is AtlasTexture and (tex as AtlasTexture).atlas != null:
		base = (tex as AtlasTexture).atlas
		src = (tex as AtlasTexture).region
	var full := base.get_size()
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for k in segments:
		var d := Vector2.from_angle(TAU * k / segments)
		pts.append(c + d * r)
		var u := Vector2(-d.x, d.y) if flip_h else d   # T096：朝右的敌人（侧视图翻转）头像也翻过来
		uvs.append((src.position + src.size * (Vector2(0.5, 0.5) + u * 0.5)) / full)
	ci.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, base)
