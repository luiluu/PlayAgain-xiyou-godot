class_name XOTBBar
extends Node2D
## Olivia_BattleSysOTB 的行动顺序条（Window_OTBDisplay＋Sprite_OTBTurnOrder），照正式版参数：
## - 位置 (58, 618)，宽 = 1280 - 58 - 状态宽 200 - 左移 48 - 图标 32×4.5，高 3 行；无窗口底。
## - 左端大菱形是正在行动的人；中间是「当前回合」，右边是「下个回合」，两段各自压缩间距排开。
## - 每人一个菱形底（我方 rgba(128,160,255,0.6)、敌方 rgba(255,100,80,0.6)，白描边），中间是侧视图第一格缩到一行高。
## - 移动 20 帧、透明度每帧 16；选目标时被选中者放大闪烁；选技能时在上方预览自己下个回合的位置。

const LH := 36.0
const ACTOR_BG := Color(128 / 255.0, 160 / 255.0, 1.0, 0.6)
const ENEMY_BG := Color(1.0, 100 / 255.0, 80 / 255.0, 0.6)
const DIM := Color(0, 0, 0, 0.6)          # MV dimColor1
const MOVE_TIME := 20.0 / 60.0
const FADE_TIME := 16.0 / 60.0
const CURRENT_TEXT := "当前回合"
const NEXT_TEXT := "下个回合"

var bar_width := 830.0
var x1 := LH * 2
var x2 := 0.0
var width1 := 0.0
var width2 := 0.0
var _nodes := {}           # 键 → Icon。"s" 行动者；"c|id|k" 当前回合第 k 次；"n|id|k" 下个回合第 k 次
var _preview: Array = []
var _selected: Array = []


class Icon extends Node2D:
	var battler: XBattler
	var big := false
	var selected := false
	var base_scale := 1.0
	var face: Sprite2D
	var _t := 0.0

	func _init(b: XBattler) -> void:
		battler = b
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face = Sprite2D.new()
		add_child(face)
		# 头像取外观的待机第一帧（MV 侧视图左上一格；单图整张；场景外观用登记的 portrait）
		var look := XAppearance.for_battler(b)
		var flip := b is XEnemy and look.sideview
		var tex := look.portrait_tex
		if tex == null:
			return
		face.texture = tex
		var w := float(tex.get_width())
		var h := float(tex.get_height())
		if look.portrait_rect.has_area():
			w = look.portrait_rect.size.x
			h = look.portrait_rect.size.y
			face.region_enabled = true
			face.region_rect = look.portrait_rect
		face.flip_h = flip
		var larger := maxf(w, h)
		base_scale = LH / larger if larger > LH else 1.0
		face.scale = Vector2.ONE * base_scale
		if b is XEnemy and (b as XEnemy).elite:
			var mat := ShaderMaterial.new()
			var sh := Shader.new()
			sh.code = XBattlerSprite.BODY_SHADER
			mat.shader = sh
			mat.set_shader_parameter("hue", (b as XEnemy).elite_hue)
			face.material = mat

	func large_scale() -> float:
		return minf(1.0, 2.0 * base_scale)

	func _process(delta: float) -> void:
		var want := base_scale
		if selected:
			_t += delta
			want = large_scale()
			face.modulate = Color(1.25, 1.25, 1.25) if fmod(_t, 0.5) < 0.25 else Color.WHITE
		else:
			face.modulate = Color.WHITE
			if big:
				want = minf(large_scale(), face.scale.x + 0.05)
		face.scale = Vector2.ONE * want
		queue_redraw()

	func _draw() -> void:
		var s := LH * (2.0 if (big or selected) else 1.0)
		var h := s / 2.0
		var pts := PackedVector2Array([Vector2(0, -h), Vector2(-h, 0), Vector2(0, h), Vector2(h, 0)])
		var fill := ACTOR_BG if battler is XActor else ENEMY_BG
		if has_meta("preview"):
			fill = Color(1, 1, 1, 1)
		draw_colored_polygon(pts, fill)
		pts.append(pts[0])
		draw_polyline(pts, Color.WHITE, 1.0)


func _init() -> void:
	z_index = 8


func setup(width: float) -> void:
	bar_width = roundf(width)
	x2 = ceilf(bar_width / 2.0) + 16.0 + 12.0
	width1 = ceilf(bar_width / 2.0) - roundf(LH * 2.5)
	width2 = bar_width - x2
	var cur := XUI.label(CURRENT_TEXT, 20)
	cur.position = Vector2(LH, LH * 2 - 2)
	add_child(cur)
	var nxt := XUI.label(NEXT_TEXT, 20)
	nxt.position = Vector2(x2, LH * 2 - 2)
	add_child(nxt)


## 背景线（drawBackgroundLines）：左端行动者菱形、当前回合轨道、下个回合轨道、两段之间的双箭头。
func _draw() -> void:
	var lh := LH
	var e1 := x1 + width1
	var e2 := x2 + width2
	_poly([lh, 0, 0, lh, lh, lh * 2, lh * 2, lh])
	_poly([lh * 2 + 8, lh - 8, lh * 2, lh, lh * 2 + 8, lh + 8, lh * 2 + 12, lh + 4, e1 - 8, lh + 4, e1 - 4, lh + 8, e1 + 4, lh, e1 - 4, lh - 8, e1 - 8, lh - 4, lh * 2 + 12, lh - 4])
	_poly([x2 - 4, lh, x2 + 4, lh + 8, x2 + 8, lh + 4, e2 - 12, lh + 4, e2 - 8, lh + 8, e2, lh, e2 - 8, lh - 8, e2 - 12, lh - 4, x2 + 8, lh - 4, x2 + 4, lh - 8])
	_poly([x2 - 12, lh, x2 - 12 + lh, lh * 2, x2 - 20 + lh, lh * 2, x2 - 20, lh, x2 - 20 + lh, 0, x2 - 12 + lh, 0])
	_poly([x2 - 28, lh, x2 - 28 + lh, lh * 2, x2 - 36 + lh, lh * 2, x2 - 36, lh, x2 - 36 + lh, 0, x2 - 28 + lh, 0])


func _poly(p: Array) -> void:
	var pts := PackedVector2Array()
	for i in range(0, p.size(), 2):
		pts.append(Vector2(p[i], p[i + 1]))
	draw_colored_polygon(pts, DIM)
	pts.append(pts[0])
	draw_polyline(pts, Color.WHITE, 1.0)


func _step(n: int, row_width: float) -> float:
	if n <= 1:
		return LH
	return minf(LH, ceilf((row_width - LH) / float(n - 1)))


func _slot_x(row: String, index: int, n: int) -> float:
	if row == "c":
		return x1 + roundf(LH / 2.0) + index * _step(n, width1)
	return x2 + roundf(LH / 2.0) + index * _step(n, width2) - 4.0


## 新回合：上回合的「下个回合」图标整体变成「当前回合」（giveTurnSpritesToNewArray），旧的当前回合淡出。
func advance_turn() -> void:
	for k in _nodes.keys():
		if k.begins_with("c|"):
			_dispose(k)
	for k in _nodes.keys():
		if k.begins_with("n|"):
			var node: Icon = _nodes[k]
			_nodes.erase(k)
			_nodes["c|" + k.substr(2)] = node


## 轮到 b 行动（updateShiftOrder）：他在当前回合的第一个图标移到左端大菱形，其余序号前移。
func on_subject(b: XBattler) -> void:
	if _nodes.has("s"):
		_dispose("s")
	var id := b.get_instance_id()
	var k := 0
	while _nodes.has("c|%d|%d" % [id, k]):
		var node: Icon = _nodes["c|%d|%d" % [id, k]]
		_nodes.erase("c|%d|%d" % [id, k])
		if k == 0:
			node.big = true
			_nodes["s"] = node
			_move(node, Vector2(LH, LH))
		else:
			_nodes["c|%d|%d" % [id, k - 1]] = node
		k += 1


## 行动结束后行动者图标淡出。
func clear_subject() -> void:
	if _nodes.has("s"):
		_dispose("s")


## 按两条顺序摆放图标；新出现的从右端淡入（下个回合）或从轨道末端回来（复活/醒来）。
func show_orders(current: Array, next: Array, instant := false) -> void:
	var want := {}
	for row in ["c", "n"]:
		var order: Array = current if row == "c" else next
		var count := {}
		for i in range(order.size()):
			var b: XBattler = order[i]
			var id := b.get_instance_id()
			var k: int = count.get(id, 0)
			count[id] = k + 1
			want["%s|%d|%d" % [row, id, k]] = [b, Vector2(_slot_x(row, i, order.size()), LH)]
	for k in _nodes.keys():
		if k != "s" and not want.has(k):
			_dispose(k)
	for k in want:
		var b: XBattler = want[k][0]
		var pos: Vector2 = want[k][1]
		var node: Icon = _nodes.get(k)
		if node == null:
			node = Icon.new(b)
			add_child(node)
			_nodes[k] = node
			node.position = pos if instant else Vector2(bar_width if k.begins_with("n|") else x1 + width1, LH)
			node.modulate.a = 1.0 if instant else 0.0
			create_tween().tween_property(node, "modulate:a", 1.0, FADE_TIME * 2.0)
		node.selected = _selected.has(b)
		if instant:
			node.position = pos
		else:
			_move(node, pos)
	# 画面上按目标 x 排序（右边的盖住左边），行动者最上层
	var nodes := _nodes.values()
	nodes.sort_custom(func(a, b): return a.get_meta("tx", a.position.x) < b.get_meta("tx", b.position.x))
	for n in nodes:
		move_child(n, -1)
	if _nodes.has("s"):
		move_child(_nodes["s"], -1)


func set_selected(list: Array) -> void:
	_selected = list.duplicate()
	for n in _nodes.values():
		n.selected = _selected.has(n.battler)


## 预览（createPreviewSprite）：entries = [[battler, "c"/"n", 顺序, 位移]]。图标画在轨道上方，白底。
func set_preview(entries: Array) -> void:
	clear_preview()
	for e in entries:
		var b: XBattler = e[0]
		var row: String = e[1]
		var order: Array = e[2]
		var change: int = e[3]
		if change == 0 or not order.has(b):
			continue
		change += 0 if change > 0 else -1
		var minimum := XOTBBar.infinity_clamp(order, e[4] if e.size() > 4 else {})
		var k := 0
		for i in range(order.size()):
			if order[i] != b:
				continue
			var index := clampi(i - change, minimum, order.size())
			var node := Icon.new(b)
			node.set_meta("preview", true)
			var w := _step(order.size(), width1 if row == "c" else width2)
			node.position = Vector2(_slot_x(row, index, order.size()) - roundf(w / 2.0), 0)
			add_child(node)
			_preview.append(node)
			k += 1


func clear_preview() -> void:
	for n in _preview:
		n.queue_free()
	_preview.clear()


static func infinity_clamp(order: Array, speeds: Dictionary) -> int:
	for i in range(order.size()):
		if speeds.get(order[i], 0.0) != INF:
			return i
	return order.size()


## 战斗结束：整条淡出（_hideOTBTurnDisplay）。
func hide_bar() -> void:
	clear_preview()
	create_tween().tween_property(self, "modulate:a", 0.0, FADE_TIME)


func _move(node: Icon, pos: Vector2) -> void:
	node.set_meta("tx", pos.x)
	if node.has_meta("tw"):
		var old: Tween = node.get_meta("tw")
		if old and old.is_valid():
			old.kill()
	var tw := create_tween()
	tw.tween_property(node, "position", pos, MOVE_TIME)
	node.set_meta("tw", tw)


func _dispose(key: String) -> void:
	var node: Icon = _nodes.get(key)
	_nodes.erase(key)
	if node == null:
		return
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(node.queue_free)
