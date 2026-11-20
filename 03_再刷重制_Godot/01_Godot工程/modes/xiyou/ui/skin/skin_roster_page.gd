class_name XSkinRosterPage
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】T307 卡 O：版型二「名单页」通用件（T254 3.0 版型二；进阶、修炼场用，技能遗忘借它的左块小人）。
## 摆法：左名单（宽 360，头像、名字、Lv、行尾一句）、中块（列表，或页面自画 center_draw）、右详情牌（宽 336）；20:9 左贴左、右贴右、中间居中不拉宽
## （XSkinLayout 的 CENTER_MAX）。从 NPC 进的页：不画页签条、不画环。
## 用法（同 T292 角色仓库：旧页的状态机不动，只把旧窗藏起，本件按旧页的状态重画）：
##   - 页面建好后 set_roster(行, 光标)；名单换行发 roster_changed，点当前行发 roster_activated；
##   - 中块要列表就 set_items（模板页那一套）；要自画就 center_draw = func(ctrl: Control)，再 show_center_list(false)；
##   - 左块不要名单（技能遗忘）：show_roster = false（_ready 前设），left_draw = func(ctrl: Control) 自画；
##   - 右牌底「展开 ▾」条：strip_text 非空就显示，整条可点，Y 键同样切换，发 strip_toggled(open)；
##   - 统一确认弹窗：ask({title, body, buttons, danger, index}) → XSkinConfirm（chosen／index_changed／cancelled 由页面接），close_dialog() 收掉；
##   - 按键：页面在自己的 _unhandled_input 里先调 input(event)，返回 true 就算用掉（Y 键、弹窗开着时的全部按键）。
## 画像素小人、战斗图的静态函数（walker_tex／draw_walker／draw_battler）把载入的纹理留在 _tex_keep 里，免得画完就被释放成白块（T304 卡 M 踩过）。

## T307 卡 O 回退开关：false＝进阶、修炼场、技能遗忘三页都回旧页（西游存档、XUiSkin 关着时本来就是旧页）
static var ENABLED := true

signal roster_changed(index: int)
signal roster_activated(index: int)
signal strip_toggled(open: bool)

const ROSTER_W := 360.0
const CARD_W := 336.0
const STRIP_H := 36.0

var show_roster := true
## 名单面板标题（旧金小字）；空＝不写
var roster_title := ""
var roster_panel: Panel
var roster: XSkinList
## 中块自画层：show_center_list(false) 时显示，画 center_draw
var center_view: Control
var center_draw: Callable
var left_draw: Callable
## 右牌底「展开」条
var strip: Control
var strip_text := ""
var strip_open := false
var dialog: XSkinConfirm
var _syncing_roster := false


func _init() -> void:
	group_key = ""            # 从 NPC 进的页不画页签条（T254 3.0）
	columns = 1
	row_height = XUiSkin.ROW_H
	left_w = ROSTER_W
	right_w = CARD_W
	show_ring = false
	auto_nav = false
	focus = "roster"
	currencies = null
	hint_list = []


func _ready() -> void:
	super()
	list.empty_center = true
	list.right2_w = 0.0
	roster_panel = Panel.new()
	roster_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roster_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	roster_panel.visible = show_roster
	roster_panel.draw.connect(_draw_roster_panel)
	layout.left.add_child(roster_panel)
	roster = XSkinList.new()
	roster.icon_size = 36
	roster.right2_w = 104.0
	roster.empty_center = true
	roster.index_changed.connect(func(i):
		if not _syncing_roster:
			roster_changed.emit(i))
	roster.activated.connect(func(i): roster_activated.emit(i))
	roster_panel.add_child(roster)
	center_view = Control.new()
	center_view.name = "CenterView"
	center_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_view.visible = false
	center_view.draw.connect(func():
		if center_draw.is_valid():
			center_draw.call(center_view))
	layout.center.add_child(center_view)
	layout.left.draw.connect(func():
		if not show_roster and left_draw.is_valid():
			left_draw.call(layout.left))
	strip = Control.new()
	strip.name = "Strip"
	strip.visible = false
	strip.mouse_filter = Control.MOUSE_FILTER_STOP
	strip.draw.connect(_draw_strip)
	strip.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			strip.accept_event()
			toggle_strip())
	card.add_child(strip)
	relayout()
	set_focus(focus)


func relayout() -> void:
	super()
	if roster_panel == null:
		return
	var lb := layout.left.size
	var top := XUiSkin.PAD + (36.0 if roster_title != "" else 0.0)
	roster.position = Vector2(28.0 if XSkinArt.select_on() else 8.0, top)
	var n := floori((lb.y - top - XUiSkin.PAD) / float(roster.row_height))
	roster.size = Vector2(lb.x - roster.position.x - 8.0, n * roster.row_height)
	center_view.position = Vector2.ZERO
	center_view.size = layout.center.size
	_place_targets()


func set_focus(f: String) -> void:
	super(f)
	if roster != null:
		roster.active = f == "roster"


# ---- 名单 ----

## 一行：头像、名字、小字「Lv N」、行尾一句（right：字；right_color：颜色）。到顶、做不了的用 TEXT_3
static func roster_row(a: XActor, right := "", right_color := XUiSkin.TEXT_2) -> Dictionary:
	return {"text": a.display_name(), "icon": XUiSkin.face(str(a.data().get("faceName", "")), int(a.data().get("faceIndex", 0))),
		"sub": "Lv %s" % XMenu._group(a.level), "right2": right, "right2_color": right_color}


func set_roster(rows: Array, index: int) -> void:
	_syncing_roster = true
	var key := rows.map(func(r): return [r.get("text", ""), r.get("sub", ""), r.get("right2", ""), r.get("right2_color", Color.WHITE)])
	if key != _roster_key:
		_roster_key = key
		roster.set_items(rows, true)
	if not rows.is_empty() and roster.index != index:
		roster.select(clampi(index, 0, rows.size() - 1), false)
	_syncing_roster = false
	roster_panel.queue_redraw()


var _roster_key := []


func show_center_list(on: bool) -> void:
	list.visible = on
	pager.visible = on and pager.visible
	center_view.visible = not on
	center_view.queue_redraw()
	list_panel.queue_redraw()


func _draw_roster_panel() -> void:
	if roster_title == "":
		return
	var body := XUiSkin.font("body")
	XUiSkin.ds(roster_panel, body, Vector2(XUiSkin.PAD + 8, XUiSkin.PAD + 20), roster_title, HORIZONTAL_ALIGNMENT_LEFT, roster_panel.size.x - 48, 20, XUiSkin.GOLD)


# ---- 右牌底「展开」条 ----

func set_strip(text: String, open: bool) -> void:
	strip_text = text
	strip_open = open
	strip.visible = text != ""
	_place_targets()
	strip.queue_redraw()


func toggle_strip() -> void:
	if strip_text == "":
		return
	XSound.system(0)
	strip_toggled.emit(not strip_open)


func _place_targets() -> void:
	super()
	if strip == null or card == null:
		return
	var h := STRIP_H if strip.visible else 0.0
	card.reserve_bottom += h
	var bottom := card.size.y - card.pad - (XSkinCard.BUTTON_H + XUiSkin.GRID if not card.buttons.is_empty() else 0.0)
	strip.position = Vector2(0, bottom - h)
	strip.size = Vector2(card.size.x, h)


func _draw_strip() -> void:
	var touch := XSkinKeyHints.touch_mode()
	var t := ("" if touch else "Y ") + strip_text + (" ▴" if strip_open else " ▾")
	var body := XUiSkin.font("body")
	var fs := XUiSkin.fs(XUiSkin.FS_AUX)
	var tw := body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	strip.draw_line(Vector2(card.pad, 1), Vector2(strip.size.x - card.pad, 1), Color(XUiSkin.LINE, 0.5), 1.0)
	XUiSkin.ds(strip, body, Vector2((strip.size.x - tw) / 2.0, strip.size.y / 2.0 + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_2)


# ---- 统一确认弹窗 ----

func ask(d: Dictionary) -> XSkinConfirm:
	if dialog == null:
		dialog = XSkinConfirm.new()
		add_child(dialog)
	dialog.setup(d)
	return dialog


func close_dialog() -> void:
	if dialog != null:
		dialog.queue_free()
		dialog = null


# ---- 按键 ----

## Y 切展开条；弹窗开着时按键全交给弹窗。返回 true＝用掉了
func input(event: InputEvent) -> bool:
	if dialog != null:
		dialog.handle_input(event)
		return true
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Y and strip_text != "":
		toggle_strip()
		return true
	return false


# ---- 像素小人、战斗图（纹理留引用，不画成白块）----

static var _tex_keep := {}


static func keep_tex(path: String) -> Texture2D:
	if path == "":
		return null
	if not _tex_keep.has(path):
		_tex_keep[path] = load(path) as Texture2D
	return _tex_keep[path]


## 行走图（characters）一格；foot：脚底中点；k：整数倍（像素不糊）。返回画出来的矩形
static func draw_walker(ci: CanvasItem, cname: String, index: int, foot: Vector2, k: float, pattern := 1, dir := 0) -> Rect2:
	var tex := keep_tex(XDB.img_path("characters", cname) if cname != "" else "")
	if tex == null:
		return Rect2()
	var big := cname.begins_with("$") or cname.begins_with("!$")
	var pw := tex.get_width() / (3.0 if big else 12.0)
	var ph := tex.get_height() / (4.0 if big else 8.0)
	var sx := ((0 if big else (index % 4) * 3) + pattern) * pw
	var sy := ((0.0 if big else floorf(index / 4.0) * 4.0) + dir) * ph
	var dst := Rect2(foot.x - pw * k / 2.0, foot.y - ph * k, pw * k, ph * k)
	RenderingServer.canvas_item_set_default_texture_filter(ci.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	ci.draw_texture_rect_region(tex, dst, Rect2(sx, sy, pw, ph))
	return dst


## 侧视战斗图（sv_actors，9×6 格）第 pattern 格（0,1,2,1 轮换由页面数）；按格高缩到 max_h 以内：整数倍放大、超高就缩小。返回画出来的矩形
static func draw_battler(ci: CanvasItem, battler: String, pattern: int, foot: Vector2, max_h: float) -> Rect2:
	var tex := keep_tex(XDB.img_path("sv_actors", battler) if battler != "" else "")
	if tex == null:
		return Rect2()
	var cw := tex.get_width() / 9.0
	var ch := tex.get_height() / 6.0
	var k := floorf(max_h / ch) if ch <= max_h else max_h / ch
	k = maxf(k, 0.01)
	var dst := Rect2(foot.x - cw * k / 2.0, foot.y - ch * k, cw * k, ch * k)
	RenderingServer.canvas_item_set_default_texture_filter(ci.get_canvas_item(),
		RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST if k >= 1.0 else RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR)
	ci.draw_texture_rect_region(tex, dst, Rect2(pattern * cw, 0, cw, ch))
	return dst


## 小人脚下的法阵：两道金色椭圆环＋淡金底（压扁成透视）
static func draw_seal(ci: CanvasItem, c: Vector2, r: float) -> void:
	var squash := Transform2D(0.0, Vector2(1.0, 0.32), 0.0, c)
	ci.draw_set_transform_matrix(squash)
	ci.draw_circle(Vector2.ZERO, r, Color(XUiSkin.GOLD, 0.10))
	ci.draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(XUiSkin.GOLD, 0.55), 2.0, true)
	ci.draw_arc(Vector2.ZERO, r * 0.72, 0, TAU, 64, Color(XUiSkin.GOLD, 0.35), 1.5, true)
	for i in 7:
		var a := TAU * i / 7.0 - PI / 2.0
		ci.draw_circle(Vector2(cos(a), sin(a)) * r * 0.86, 4.0, Color(XUiSkin.GOLD, 0.6))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
