class_name XSkinRingNav
extends Control
## 【cc·天启篇·未经审查】环形导航（主菜单的组、装备栏位、物品分类、战斗指令都用它）：
## - 通用法阵（content/ui_skin/circle_generic.svg）在环里 50% 慢转（全部档 60 秒一圈）、外圈虚线反转（50 秒一圈）；
## - 主环 1.5px 线色 75%＋外侧 10px 绯红 5% 的光带＋一圈 22% 细线；
## - 七道旧金菱形刻痕（七印意象，固定七道，和项数无关），落在项与项之间；
## - 项是环上的圆球（亮面→暗面径向，线色 65% 描边），图标居中，名字在球外（上半圈写在球上方、下半圈写在球下方）；
##   选中的球放大 1.16、朱红 2.5px 描边＋绯红外晕，名字白色加大；
## - 焦点光弧：主环上 9% 周长的朱红弧，转到选中项（0.14 秒冲过 4°、0.2 秒回正；动效关时直接到）。
## 项按 items 排（第一项在正上方，顺时针等分），项数随数据（可见组 6 或 7）变，不用改布局。
## 项带 art_normal／art_selected（组入口 u4，XUiSkin.GROUP_ICONS_U4）时：贴图按原生大小画（64）、最近邻、整数像素位置，选中只换贴图；
## 选中贴图自带朱红圆底，这时选中球不再加绯红外晕、描边改旧金，免得叠成两层红（p1fix 追加）。

signal changed(index: int)
signal activated(index: int)

## [{key, name, icon（图标号或 Texture2D）}]
var items: Array = []
var index := 0
var radius := 180.0
var orb_radius := 33.0
var center_texture: Texture2D
var label_size := XUiSkin.FS_LIST
## 光弧现在的角度（度，0＝正右、顺时针为正）
var arc_deg := -90.0
var _arc_from := -90.0
var _arc_to := -90.0
var _arc_t := 1.0
var _spin := 0.0
const ARC_FRAC := 0.09
const ARC_TIME := 0.2
const ARC_OVERSHOOT := 4.0
const NOTCHES := 7


## u4 贴图画在这个子画布项（最近邻；法阵 svg 照旧线性过滤）。_draw 里同步清空重画，不另排一帧
var _art_ci := RID()
## 上次画了哪些 u4 贴图（测试看）：[{i, tex, rect}]
var art_drawn: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	_art_ci = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_art_ci, get_canvas_item())
	RenderingServer.canvas_item_set_default_texture_filter(_art_ci, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _art_ci.is_valid():
		RenderingServer.free_rid(_art_ci)


## 主菜单组 → 环上的项（有 u4 贴图时带 art_normal／art_selected）
static func group_item(g: Dictionary) -> Dictionary:
	var it := {"key": g.key, "name": g.name, "icon": int(g.get("icon", 0))}
	var n := XUiSkin.group_icon(str(g.get("art", "")), false)
	var sel := XUiSkin.group_icon(str(g.get("art", "")), true)
	if n != null and sel != null:
		it["art_normal"] = n
		it["art_selected"] = sel
	return it


func has_art(i: int) -> bool:
	return i >= 0 and i < items.size() and items[i].get("art_normal") is Texture2D


## 第 i 项 u4 贴图画在哪（本节点坐标，整数像素、原生大小）
func art_rect(i: int) -> Rect2:
	var tex: Texture2D = items[i].get("art_selected" if i == index else "art_normal")
	var ts := tex.get_size()
	return Rect2((item_pos(i) - ts / 2.0).round(), ts)


func _draw_art() -> void:
	RenderingServer.canvas_item_clear(_art_ci)
	art_drawn.clear()
	for i in items.size():
		if has_art(i):
			var tex: Texture2D = items[i].get("art_selected" if i == index else "art_normal")
			var r := art_rect(i)
			RenderingServer.canvas_item_add_texture_rect(_art_ci, r, tex.get_rid())
			art_drawn.append({"i": i, "tex": tex, "rect": r})


func set_items(arr: Array, keep := false) -> void:
	items = arr
	if not keep:
		index = 0
	index = clampi(index, 0, maxi(items.size() - 1, 0))
	arc_deg = item_deg(index)
	_arc_from = arc_deg
	_arc_to = arc_deg
	_arc_t = 1.0
	queue_redraw()


func center() -> Vector2:
	return size / 2.0


## 第 i 项的角度：第一项在正上方（-90°），顺时针等分
func item_deg(i: int) -> float:
	return -90.0 + i * 360.0 / maxf(items.size(), 1.0)


func item_pos(i: int) -> Vector2:
	return center() + Vector2.from_angle(deg_to_rad(item_deg(i))) * radius


func notch_deg(k: int) -> float:
	return -90.0 + k * 360.0 / NOTCHES + 360.0 / (NOTCHES * 2)


func select(i: int, animate := true) -> void:
	if items.is_empty():
		return
	i = posmod(i, items.size())
	if i == index and _arc_t >= 1.0:
		return
	index = i
	var to := item_deg(i)
	# 走近路：目标角度挪到离现在最近的那一圈
	while to - arc_deg > 180.0:
		to -= 360.0
	while to - arc_deg < -180.0:
		to += 360.0
	if not animate or XUiSkin.motion() == XUiSkin.Motion.OFF:
		arc_deg = to
		_arc_from = to
		_arc_to = to
		_arc_t = 1.0
	else:
		_arc_from = arc_deg
		_arc_to = to
		_arc_t = 0.0
	queue_redraw()
	changed.emit(index)


func step(d: int) -> void:
	select(index + d)


func advance(delta: float) -> void:
	if _arc_t < 1.0:
		_arc_t = minf(1.0, _arc_t + delta / ARC_TIME)
		var over := ARC_OVERSHOOT * signf(_arc_to - _arc_from)
		var k1 := 0.14 / ARC_TIME
		if _arc_t < k1:
			var e := 1.0 - pow(1.0 - _arc_t / k1, 2.0)
			arc_deg = lerpf(_arc_from, _arc_to + over, e)
		else:
			arc_deg = lerpf(_arc_to + over, _arc_to, (_arc_t - k1) / (1.0 - k1))
		if _arc_t >= 1.0:
			arc_deg = _arc_to
		queue_redraw()
	if XUiSkin.breathing():
		_spin += delta
		queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


func item_at(p: Vector2) -> int:
	for i in items.size():
		if p.distance_to(item_pos(i)) <= orb_radius * 1.2:
			return i
	return -1


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_up", true):
		step(-1)
		return true
	if event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_down", true):
		step(1)
		return true
	if event.is_action_pressed("ui_accept"):
		if not items.is_empty():
			activated.emit(index)
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := item_at(event.position)
		if i < 0:
			return
		if i == index:
			activated.emit(i)
		else:
			select(i)
		accept_event()


func _draw() -> void:
	_draw_art()
	var c := center()
	var R := radius
	var line := XUiSkin.LINE
	# 法阵
	var circ := XUiSkin.circle_texture()
	if circ != null:
		var d := R * 2.0 - 60.0
		draw_set_transform(c, deg_to_rad(_spin * 6.0), Vector2.ONE)
		draw_texture_rect(circ, Rect2(-d / 2.0, -d / 2.0, d, d), false, Color(1, 1, 1, 0.5))
		draw_set_transform(Vector2.ZERO)
	# 光带与细线
	draw_arc(c, R + 5.5, 0, TAU, 96, Color(XUiSkin.SEL_FILL, 0.05), 10.0, true)
	draw_arc(c, R + 10.5, 0, TAU, 96, Color(line, 0.22), 1.0, true)
	draw_arc(c, R, 0, TAU, 128, Color(line, 0.75), 1.5, true)
	# 外圈虚线（反转）
	var dash_r := R + 22.0
	var dashes := 72
	var off := -_spin * TAU / 50.0
	for k in dashes:
		var a0 := off + k * TAU / dashes
		draw_arc(c, dash_r, a0, a0 + TAU / dashes * 0.5, 4, Color(line, 0.30), 1.5, true)
	# 刻痕
	for k in NOTCHES:
		var p := c + Vector2.from_angle(deg_to_rad(notch_deg(k))) * (R + 11.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5.5), p + Vector2(5.5, 0), p + Vector2(0, 5.5), p + Vector2(-5.5, 0)]), XUiSkin.GOLD)
	# 中心图
	if center_texture != null:
		var ts := center_texture.get_size()
		var k := minf((R - 50.0) * 2.0 / maxf(ts.x, ts.y), 4.0)
		draw_texture_rect(center_texture, Rect2(c - ts * k / 2.0, ts * k), false)
	# 焦点光弧
	if not items.is_empty():
		var half := PI * ARC_FRAC
		var a := deg_to_rad(arc_deg)
		draw_arc(c, R, a - half, a + half, 24, Color(XUiSkin.SEL_FILL, 0.35), 11.0, true)
		draw_arc(c, R, a - half, a + half, 24, XUiSkin.SEL_LINE, 5.0, true)
	# 球
	var body := XUiSkin.font("body")
	for i in items.size():
		var p := item_pos(i)
		var on := i == index
		var r := orb_radius * (1.16 if on else 1.0)
		var art := has_art(i)
		if on:
			var g := XUiSkin.glow_texture()
			# u4 选中贴图自带朱红底：外晕减成淡旧金，不叠第二层红
			draw_texture_rect(g, Rect2(p - Vector2(r + 24, r + 24), Vector2(r + 24, r + 24) * 2), false,
				Color(XUiSkin.GOLD, 0.30) if art else Color(XUiSkin.SEL_FILL, 0.85))
		draw_circle(p + Vector2(0, 3), r + 2, Color(0, 0, 0, 0.45))
		draw_circle(p, r, XUiSkin.ORB_LOW)
		draw_circle(p + Vector2(-r * 0.15, -r * 0.2), r * 0.72, Color(XUiSkin.ORB_HI, 0.85))
		var ring_col := (Color(XUiSkin.GOLD, 1.0) if art else Color(XUiSkin.SEL_LINE, 1.0)) if on else Color(line, 0.65)
		draw_circle(p, r, ring_col, false, 2.5 if on else 1.5, true)
		var icon = items[i].get("icon")
		var tex: Texture2D = icon if icon is Texture2D else (XUiSkin.icon(int(icon)) if (icon is int or icon is float) and int(icon) > 0 else null)
		if tex != null and not art:
			var s := 40.0 * (1.16 if on else 1.0)
			draw_texture_rect(tex, Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), false)
		var name := str(items[i].get("name", ""))
		var fs := label_size + (3 if on else 0)
		var tw := body.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var above := sin(deg_to_rad(item_deg(i))) < -0.2
		var ly := p.y - r - 10.0 if above else p.y + r + 10.0 + fs * 0.86
		draw_string_outline(body, Vector2(p.x - tw / 2.0, ly), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6))
		draw_string(body, Vector2(p.x - tw / 2.0, ly), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if on else XUiSkin.TEXT_2)
