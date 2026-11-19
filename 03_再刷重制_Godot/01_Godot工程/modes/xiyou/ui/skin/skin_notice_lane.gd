class_name XSkinNoticeLane
extends CanvasLayer
## 【cc·天启篇·未经审查】新界面「提示道」（T254 卡 C，R1；设计稿：私密设计仓 重制设定/界面风格提案_v0.7/T254_剩余页细节设计.md 第二节 R1）。
## 成就、自动存档、战力、至臻、技能升级、XToast 的短提示在新皮肤下都不再各画各的，统一进这一条道：
## - 屏幕上沿正中（y 14～58，和页名同一行高度），一次只出一条，其余排队；每条 2 秒，积压超过 2 条时每条缩到 0.7 秒。
## - 同类同名的合并成一条「×N」（战力、技能升级换成最新的那次，不加 ×N）；正在显示的那条也能并进来。
## - 样式：深色胶囊（PANEL_LOW 92%＋1px 线）＋图标＋名字（旧金）＋小字（次要灰）。XToast 的长句最多折两行，超出用省略号。
## - 菜单页开着时照样在上沿，不碰 y 72 的面板顶；地图上 4 秒难度横幅、战斗里的首领血弧亮着时让到它们下面。
## - 跟真实时间走（不吃战斗变速），菜单暂停时也走；动效「关」时不淡入淡出。
## 地图宝箱拾取浮字（XTreasurePopup）不进这里，留在原地（R4）；4 秒难度横幅也不进（R2）。
## 回退开关（O-待定）：NOTICE_V2 = false 时这条道不用，各提示照 4B 的画法各画各的；同一个开关也管卡 C 的 R2、R4、R14 新画法。

static var NOTICE_V2 := true

const LAYER := 100
const Y := 14.0
const H := 44.0
const HOLD := 2.0
const HOLD_FAST := 0.7
const BACKLOG := 2          # 排队超过这么多条就提速
const FADE := 0.12
const MIN_W := 200.0
const PAD_X := 18.0
const ICON := 24.0
const GAP := 10.0
const MAX_LINES := 2
const LINE_H := 22.0
## 让位：这个组里亮着的东西（4 秒难度横幅）和首领血弧，提示道放到它们下面
const AVOID_GROUP := "skin_notice_avoid"

## 排队的条（没显示的）；出现过的条（测试核对用）
static var queue: Array = []
static var history: Array = []
## 测试用：false 时不按真实时间走，测试自己调 step(dt)
static var auto_tick := true

var cur := {}
var t := 0.0
var chip: Chip
var _last_usec := 0


## 新皮肤开着、开关没关
static func on() -> bool:
	return NOTICE_V2 and XUiSkin.on()


## 放一条进提示道。item：kind（ach／save／power／prestige／skill／toast）、title、sub、icon（图标号）、badge（成就徽章图名）
static func push(item: Dictionary) -> void:
	if XMainThread.defer(XSkinNoticeLane.push.bind(item)):
		return
	var it := item.duplicate()
	it["count"] = 1
	if not it.has("key"):
		it["key"] = str(it.get("kind", "")) + "|" + str(it.get("title", ""))
	var lane := lane_node()
	if lane == null:
		return
	if lane._merge_into(lane.cur, it, true):
		return
	for q in queue:
		if lane._merge_into(q, it, false):
			return
	queue.append(it)
	history.append(it)
	if lane.cur.is_empty():
		lane.step(0.0)


## 同 key 的并进去：换内容的（replace）只换文字，其余 ×N
func _merge_into(dst: Dictionary, it: Dictionary, showing: bool) -> bool:
	if dst.is_empty() or str(dst.get("key", "")) != str(it.key):
		return false
	if showing and t >= _total(dst) - FADE:
		return false   # 正在淡出的不再并，另起一条
	if bool(it.get("replace", false)):
		for k in ["title", "sub", "icon", "badge"]:
			if it.has(k):
				dst[k] = it[k]
		if it.has("merge_sub"):
			dst["sub"] = (it.merge_sub as Callable).call(dst, it)
	else:
		dst["count"] = int(dst.get("count", 1)) + 1
	if showing and chip != null:
		_relayout()
	return true


## 清掉某一类（换局、读档时技能升级清掉）
static func clear_kind(kind: String) -> void:
	queue = queue.filter(func(q): return str(q.get("kind", "")) != kind)
	var l := existing()
	if l != null and str(l.cur.get("kind", "")) == kind:
		l.cur = {}
		l.chip.visible = false


## 全清（测试）
static func reset() -> void:
	queue.clear()
	history.clear()
	var l := existing()
	if l != null:
		l.cur = {}
		l.t = 0.0
		l.chip.visible = false


static func existing() -> XSkinNoticeLane:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("XSkinNoticeLane") as XSkinNoticeLane if tree and tree.root else null


static func lane_node() -> XSkinNoticeLane:
	var l := existing()
	if l == null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null or tree.root == null:
			return null
		l = XSkinNoticeLane.new()
		l.name = "XSkinNoticeLane"
		tree.root.add_child(l)
	return l


## 当前显示的那条（没有为空）
static func showing() -> Dictionary:
	var l := existing()
	return l.cur if l != null else {}


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	chip = Chip.new()
	chip.lane = self
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.visible = false
	add_child(chip)
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := (now - _last_usec) / 1000000.0
	_last_usec = now
	if auto_tick:
		step(minf(dt, 0.25))
	elif chip.visible:
		_place()


## 这一条该停多久：积压超过 BACKLOG 条时提速；折了两行的多给 0.8 秒
func _total(it: Dictionary) -> float:
	if queue.size() > BACKLOG:
		return HOLD_FAST
	return HOLD + (0.8 if int(it.get("_lines", 1)) > 1 else 0.0)


## 走 dt 秒
func step(dt: float) -> void:
	if cur.is_empty():
		if queue.is_empty():
			chip.visible = false
			return
		cur = queue.pop_front()
		t = 0.0
		_relayout()
		chip.visible = true
	else:
		t += dt
	var total := _total(cur)
	if t >= total:
		cur = {}
		t = 0.0
		step(0.0)
		return
	var fade := FADE if XUiSkin.motion() != XUiSkin.Motion.OFF else 0.0
	chip.modulate.a = clampf(minf(t / fade, (total - t) / fade), 0.0, 1.0) if fade > 0.0 else 1.0
	_place()


func _view() -> Vector2:
	return get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280, 720)


func _relayout() -> void:
	chip.layout_for(cur, _view())
	cur["_lines"] = chip.lines.size()
	_place()
	chip.queue_redraw()


## 上沿正中；和让位组、首领血弧相交就挪到它们下面
func _place() -> void:
	var vs := _view()
	var x := roundf((vs.x - chip.size.x) / 2.0)
	var y := Y
	var span := Vector2(x, x + chip.size.x)
	var tree := get_tree()
	if tree != null:
		for n in tree.get_nodes_in_group(AVOID_GROUP):
			if n is Control and (n as Control).is_visible_in_tree() and (n as Control).modulate.a > 0.01:
				var r := (n as Control).get_global_rect()
				if r.position.x < span.y and r.end.x > span.x and r.position.y < y + chip.size.y:
					y = maxf(y, r.end.y + 8.0)
		var arc := _boss_arc_bottom(tree)
		if arc > 0.0:
			y = maxf(y, arc)
	chip.position = Vector2(x, y)


## 首领血弧亮着时它的下沿（同 XDifficultyNoticeCanvas 的让位，+48 让开名字和血量数字）
static func _boss_arc_bottom(tree: SceneTree) -> float:
	var cs := tree.current_scene
	if cs == null:
		return 0.0
	var nodes: Array = [cs]
	nodes.append_array(cs.get_children())
	for n in nodes:
		if n is XBattleScene and n.visible and n.get("boss_hp") is XSkinBossArc:
			var arc: XSkinBossArc = n.boss_hp
			if arc != null and arc.visible and arc.battler != null and arc.layout_alpha > 0:
				return XSkinBossArc.arc_bottom() + 48.0
	return 0.0


## 省略号截断（不缩字）
static func ellipsize(s: String, f: Font, fs: int, max_w: float) -> String:
	if max_w <= 0.0:
		return ""
	if f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
		return s
	var lo := 0
	var hi := s.length()
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if f.get_string_size(s.substr(0, mid) + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
			lo = mid
		else:
			hi = mid - 1
	return s.substr(0, lo) + "…"


## 按宽度折行（中文逐字、英文按词），最多 max_lines 行，多出的末行加省略号
static func wrap(s: String, f: Font, fs: int, max_w: float, max_lines: int) -> Array:
	var out: Array = []
	for para in s.split("\n"):
		var p := para.strip_edges()
		if p == "":
			continue
		var tp := TextParagraph.new()
		tp.add_string(p, f, fs)
		tp.width = max_w
		tp.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND | TextServer.BREAK_ADAPTIVE
		for i in tp.get_line_count():
			var r := tp.get_line_range(i)
			out.append(p.substr(r.x, r.y - r.x).strip_edges())
	if out.size() > max_lines:
		var rest := " ".join(out.slice(max_lines - 1))
		out = out.slice(0, max_lines - 1)
		out.append(ellipsize(rest, f, fs, max_w) if f.get_string_size(rest, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w else rest)
	return out


## 一条提示的胶囊
class Chip extends Control:
	var lane: XSkinNoticeLane
	var item := {}
	## 排好的文字：[[字, x, 基线 y, 字号, 颜色, 字体]]
	var lines: Array = []
	var runs: Array = []
	var icon_tex: Texture2D
	var badge_tex: Texture2D

	func title_fs() -> int:
		return mini(XUiSkin.fs(18), 23)

	func sub_fs() -> int:
		return mini(XUiSkin.FS_AUX, 19)

	func layout_for(it: Dictionary, vs: Vector2) -> void:
		item = it
		runs.clear()
		lines.clear()
		var bf := XUiSkin.font("body")
		var nf := XUiSkin.font("num")
		var tfs := title_fs()
		var sfs := sub_fs()
		var max_w := minf(float(XUiSkin.CENTER_MAX), vs.x - XSkinLayout.margin_for(vs.x) * 2.0)
		icon_tex = null
		badge_tex = null
		var ic := int(it.get("icon", 0))
		if ic > 0:
			icon_tex = XUI.icon_texture(ic)
		var bd := str(it.get("badge", ""))
		if bd != "":
			var p := XDB.img_path("codex_achievements", bd)
			if p != "":
				badge_tex = load(p)
		var has_pic := icon_tex != null or badge_tex != null
		var x0 := PAD_X + (ICON + GAP if has_pic else 0.0)
		var inner := max_w - x0 - PAD_X
		var title := str(it.get("title", ""))
		var sub := str(it.get("sub", ""))
		var n := int(it.get("count", 1))
		var cnt := ("×%d" % n) if n > 1 else ""
		var cw := nf.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x + 6.0 if cnt != "" else 0.0
		var tcol: Color = it.get("color", XUiSkin.GOLD)
		var h := H
		if str(it.get("kind", "")) == "toast":
			# 提示句：可能长、可能多行，按宽度折行，最多两行
			var wl := XSkinNoticeLane.wrap(title, bf, tfs, inner - cw, MAX_LINES)
			lines = wl
			var w := 0.0
			for l in wl:
				w = maxf(w, bf.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x)
			h = maxf(H, LINE_H * wl.size() + 22.0)
			var top := roundf((h - LINE_H * wl.size()) / 2.0)
			for i in wl.size():
				runs.append([wl[i], x0, top + LINE_H * i + LINE_H / 2.0 + tfs * 0.36, tfs, tcol, bf])
			if cnt != "":
				runs.append([cnt, x0 + w + 6.0, top + LINE_H / 2.0 + tfs * 0.36, tfs, XUiSkin.GOLD_LIGHT, nf])
			size = Vector2(maxf(MIN_W, ceilf(x0 + w + cw + PAD_X)), h)
			return
		lines = [title]
		var base := roundf(h / 2.0 + tfs * 0.36)
		var sbase := roundf(h / 2.0 + sfs * 0.36)
		var tw := bf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
		if tw + cw > inner:
			title = XSkinNoticeLane.ellipsize(title, bf, tfs, inner - cw)
			tw = bf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
		var x := x0
		if title != "":
			runs.append([title, x, base, tfs, tcol, bf])
			x += tw
		if cnt != "":
			runs.append([cnt, x + 6.0, base, tfs, XUiSkin.GOLD_LIGHT, nf])
			x += cw
		if sub != "":
			var room := max_w - PAD_X - x - 12.0
			if room >= 48.0:
				var s := XSkinNoticeLane.ellipsize(sub, bf, sfs, room)
				runs.append([s, x + 12.0, sbase, sfs, it.get("sub_color", XUiSkin.TEXT_2), bf])
				x += 12.0 + bf.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
		var min_w := MIN_W if title != "" or sub != "" else H + 16.0
		size = Vector2(maxf(min_w, ceilf(x + PAD_X)), h)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(XUiSkin.PANEL_LOW, 0.92)
		sb.border_color = Color(XUiSkin.LINE, 0.45)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(int(minf(size.y / 2.0, 22.0)))
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 3)
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		var iy := roundf((size.y - ICON) / 2.0)
		if badge_tex != null:
			draw_texture_rect(badge_tex, Rect2(PAD_X - 2.0, iy - 4.0, ICON + 8.0, ICON + 8.0), false)
		elif icon_tex != null:
			draw_texture_rect(icon_tex, Rect2(PAD_X, iy, ICON, ICON), false)
		for run in runs:
			XUiSkin.ds(self, run[5], Vector2(run[1], run[2]), str(run[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(run[3]), run[4])
