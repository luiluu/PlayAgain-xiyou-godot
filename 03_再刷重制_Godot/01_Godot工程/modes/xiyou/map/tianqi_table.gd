class_name XTianqiTable
extends Node2D
## 【cc·天启篇·未经审查】方桌大厅那张方桌上的裂纹（四线剧情与关卡设计稿 v0.4 第 2.1 节）：
## - 1～5 层（还没到选线）：桌面一道细裂纹，调查时小小鱼说「别碰，还没到时候」；
## - 通关 5 层、还没选线：裂成四块，每块透出一位骑士的颜色和剪影；调查方桌再进选线（XTianqi.run_line_choice）；
## - 选定：另外三块合上（留一道暗疤）、剪影隐去，选中的那道裂纹变成本线颜色、一直留在桌上。
## 只叠不改：不写 Map004 的事件和图块；画在下层图块之上、人物之下。开关 XTianqiLook.TABLE（O-323）。
## 新界面（ui-skin-3b，盘点清册 #77）：XUiSkin.on() 时，玩家面朝方桌、地图没在跑事件时，桌子上方浮一枚提示胶囊
## （黑面板细线，「[确定] 调查」／「[确定] 选一条路」／本线名；触屏不画键名框）。只显示，不改调查逻辑；关着时没有这枚提示。

const MAP_ID := 4
const TS := 48
## 方桌占的格（Map004 讨债人那张红桌：x 13～15、y 11～12）；桌面在格子里的像素范围
const TABLE_CELLS := [Vector2i(13, 11), Vector2i(14, 11), Vector2i(15, 11), Vector2i(13, 12), Vector2i(14, 12), Vector2i(15, 12)]
const SURFACE := Rect2(13 * TS + 4, 11 * TS + 6, 3 * TS - 8, 38)
## 调查：站在桌子下面一行（y 13）或两侧、面朝桌子按确认键
const TOO_EARLY := "别碰。……还没到时候。"

var state := ""          # hint / split / chosen
var line := ""
var _t := 0.0
var _cracks: Array = []  # 四道裂纹（折线），按 XTianqi.LINES 的顺序
var _hint: PackedVector2Array
var _figs: Array = []    # 四个小剪影（Sprite2D）
var chip: _Chip          # 新界面的调查提示（XUiSkin.on() 时才建）


static func wanted(s: XState) -> String:
	if not XTianqiLook.TABLE or not XTianqiLook.shown(s):
		return ""
	var key := XTianqi.line_of(s)
	if key != "":
		return "chosen"
	if XTianqi.LINE_EVENT_OPEN and XTianqi.cleared_floors(s) >= XTianqi.LINE_FLOOR:
		return "split"
	return "hint"


func setup() -> void:
	name = "TianqiTable"
	z_index = -9   # 下层图块（-10）之上、人物（0）之下
	_build_cracks()
	var n := XTianqi.LINES.size()
	for i in n:
		var key := str(XTianqi.LINES[i].key)
		var sp := Sprite2D.new()
		sp.texture = XTianqiLook.portrait(key)
		sp.material = XTianqiLook.silhouette_material(key)
		sp.scale = Vector2.ONE * (30.0 / 768.0)
		sp.position = Vector2(SURFACE.position.x + SURFACE.size.x * (i + 0.5) / n, SURFACE.position.y + SURFACE.size.y * 0.5)
		sp.visible = false
		add_child(sp)
		_figs.append(sp)
	chip = _Chip.new()
	chip.position = Vector2(SURFACE.get_center().x, SURFACE.position.y - 14)
	add_child(chip)
	refresh()


## 四道裂纹：从桌面中心向四个方向（左上、左下、右上、右下）各一道，固定种子
func _build_cracks() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 0x7A61
	var c := SURFACE.get_center()
	_hint = _jag(r, c + Vector2(-26, -4), c + Vector2(22, 5), 5)
	var ends := [Vector2(SURFACE.position.x + 6, SURFACE.position.y + 4), Vector2(SURFACE.position.x + 30, SURFACE.end.y - 3),
		Vector2(SURFACE.end.x - 30, SURFACE.position.y + 3), Vector2(SURFACE.end.x - 6, SURFACE.end.y - 4)]
	for e in ends:
		_cracks.append(_jag(r, c, e, 6))


static func _jag(r: RandomNumberGenerator, a: Vector2, b: Vector2, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var nrm := (b - a).orthogonal().normalized()
	for i in range(1, n):
		pts.append(a.lerp(b, float(i) / n) + nrm * r.randf_range(-2.5, 2.5))
	pts.append(b)
	return pts


func refresh() -> void:
	var s := XState.current
	var st := wanted(s)
	var key := XTianqi.line_of(s) if s != null else ""
	if st == state and key == line:
		return
	state = st
	line = key
	visible = st != ""
	for i in _figs.size():
		_figs[i].visible = st == "split"
	queue_redraw()


func _process(dt: float) -> void:
	_t += dt
	if Engine.get_process_frames() % 30 == 0:
		refresh()
	if state != "hint" and visible:
		queue_redraw()
		var p := 0.75 + 0.25 * sin(_t * 2.2)
		for f in _figs:
			f.modulate.a = p
	_update_chip()


## 提示胶囊的字：还没到选线「调查」、该选线「选一条路」、选过了「本线名之路」；空串＝不显示
static func chip_text(st: String, key: String) -> String:
	match st:
		"hint":
			return "调查"
		"split":
			return "选一条路"
		"chosen":
			var nm := str(XTianqi.line_info(key).get("name", ""))
			return nm + "之路" if nm != "" else "调查"
	return ""


## 玩家面朝方桌、没在跑事件、新界面开着才显示（host 是地图场景：有 player、busy）
func _update_chip() -> void:
	if chip == null:
		return
	var host := get_parent()
	var show := visible and XUiSkin.on() and host != null and "player" in host and host.player != null \
		and not bool(host.get("busy")) and is_table(host.player.front_cell(host.player.direction))
	var text := chip_text(state, line) if show else ""
	chip.set_text(text, not XPlatform.is_touch())


## 调查提示：一枚黑面板细线胶囊，左边键名框「确定」，右边一句；画在人物和上层图块之上
class _Chip extends Node2D:
	var text := ""
	var keycap := true
	const FS := 15
	const H := 28.0

	func _init() -> void:
		z_as_relative = false
		z_index = 200
		visible = false

	func set_text(t: String, with_key: bool) -> void:
		if t == text and with_key == keycap and visible == (t != ""):
			return
		text = t
		keycap = with_key
		visible = t != ""
		queue_redraw()

	func _draw() -> void:
		if text == "":
			return
		var f := XUiSkin.font("body")
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
		var kw := f.get_string_size("确定", HORIZONTAL_ALIGNMENT_LEFT, -1, FS - 1).x + 16 if keycap else 0.0
		var w := tw + 24 + (kw + 8 if keycap else 0.0)
		var r := Rect2(-w / 2.0, -H, w, H)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(XUiSkin.PANEL, 0.94)
		sb.border_color = Color(XUiSkin.LINE, 0.42)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(int(H / 2))
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = 6
		sb.draw(get_canvas_item(), r)
		var x := r.position.x + 12
		var base := -H / 2.0 + FS * 0.36
		if keycap:
			var kb := StyleBoxFlat.new()
			kb.draw_center = false
			kb.border_color = XUiSkin.TEXT_2
			kb.set_border_width_all(1)
			kb.set_corner_radius_all(9)
			kb.draw(get_canvas_item(), Rect2(x - 4, -H + 5, kw, H - 10))
			draw_string(f, Vector2(x + 4, base), "确定", HORIZONTAL_ALIGNMENT_LEFT, -1, FS - 1, XUiSkin.TEXT)
			x += kw + 4
		draw_string(f, Vector2(x, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, XUiSkin.GOLD)


func _draw() -> void:
	match state:
		"hint":
			draw_polyline(_hint, Color(0.08, 0.02, 0.1, 0.9), 1.5, true)
			draw_polyline(_hint, Color(0.62, 0.45, 0.9, 0.18), 3.0, true)
		"split":
			for i in _cracks.size():
				var col := XTianqiLook.main_color(str(XTianqi.LINES[i].key))
				_glow_crack(_cracks[i], col, 0.7 + 0.3 * sin(_t * 2.0 + i))
		"chosen":
			for i in _cracks.size():
				var key := str(XTianqi.LINES[i].key)
				if key == line:
					_glow_crack(_cracks[i], XTianqiLook.main_color(key), 0.85 + 0.15 * sin(_t * 1.6))
				else:
					draw_polyline(_cracks[i], Color(0.12, 0.05, 0.08, 0.55), 1.0, true)   # 合上的疤


func _glow_crack(pts: PackedVector2Array, col: Color, k: float) -> void:
	draw_polyline(pts, Color(col, 0.22 * k), 6.0, true)
	draw_polyline(pts, Color(col, 0.55 * k), 3.0, true)
	draw_polyline(pts, Color(col.lightened(0.5), k), 1.2, true)


## 玩家面前这一格是不是方桌（地图场景的确认键：没有事件时才轮到）
static func is_table(cell: Vector2i) -> bool:
	return TABLE_CELLS.has(cell)


## 调查方桌：还没到选线时小小鱼拦一句；该选线时进选线（选了接着跑本线开场）；选过了说一句本线
func on_action(host) -> void:
	var s := XState.current
	host._set_busy(true)
	match wanted(s):
		"hint":
			await host.show_text("", 0, XTianqi._line(TOO_EARLY))
		"split":
			if XTianqi.line_ready(s):
				await XTianqi.run_line_choice(host, s)
			else:
				await host.show_text("", 0, XTianqi._line(TOO_EARLY))
		"chosen":
			var l := XTianqi.line_info(XTianqi.line_of(s))
			await host.show_text("", 0, ["桌上只剩%s之路的那一道裂纹，还亮着。" % str(l.get("name", ""))])
	host._set_busy(false)
	host.refresh_events()
	refresh()
