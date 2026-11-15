class_name XSkinOTBBar
extends XOTBBar
## 【cc·天启篇·未经审查】新界面 2B：行动顺序条（盘点清册 #66，界面风格提案 v0.7 样稿 battle 的 .otb）。
## 只换画法和摆法：哪些人、什么顺序、何时前移／淡出／预览，全是 XOTBBar 原来的逻辑（show_orders、on_subject、advance_turn、
## set_preview、set_selected），读的还是 logic.current_order／next_order，不碰行动顺序和随机数。
## - 左下角一排圆头像：最左大圆（62）是正在行动的人，红圈外晕、下面白字写名字；之后是本回合还没行动的，竖排小字「下回合」隔开下个回合。
## - 名字只标当前的人和敌人（v0.7「行动顺序只给当前的人和敌人标名字」）；敌人圆底紫黑、名字淡紫。
## - 被选为目标的放大一点、旧金圈闪；选技能时的预览（自己下个回合的位置）是轨道上方的半透明小圈。
## 位置参数都是 static var（两排站位的位置 Kyo 还没定，定了只改这里）：POS（条左上，1280×720 画面坐标）、WIDTH、各圆半径。

## 条左上（原版坐标；XBattleScene 先摆到 OTB_POS 再 setup，这里改成 POS）。大圆圆心在 POS＋(36, 36)＝(51, 663)，同样稿左 20、底 10
static var POS := Vector2(15, 627)
static var WIDTH := 550.0
static var R_NOW := 31.0
static var R_ROW := 22.0
static var R_SELECTED := 26.0
static var R_PREVIEW := 15.0
## 条占的地方顶边离 POS 多高（目标放大圈、预览小圈都在里面；小A审 P1-3 量的是 y≈627～712，再留 11）
const CLEAR_ABOVE := 11.0
const STEP_MAX := 50.0       # 两个小圆圆心最远隔多少（44 的圆＋6 的缝）
const SEP := 48.0            # 本回合与下回合之间多留的缝（放「下回合」；核查返工 40→48）
const SEP_TEXT := "下回合"
const ENEMY_DARK := Color("1a1226")
const ENEMY_LIGHT := Color("4a3566")
const ENEMY_NAME := Color("d9c8f5")

var step_px := STEP_MAX
var sep_x := -1.0            # 分隔线 x（没有下回合时为 −1，不画）
## 「下回合」画在这个子节点上、z 高一层：头像都是条的子节点，画在条自己 _draw 之上，挤的时候会把竖字盖住（核查返工）
var sep_node: Node2D


## 行动顺序条在 1280×720 画面坐标里占的矩形（战技／物品列表要躲开它，XSkinBattleSkillList.place_for_actor）
static func occupied_rect() -> Rect2:
	var top := POS.y - CLEAR_ABOVE
	return Rect2(POS.x, top, WIDTH, 720.0 - top)


func setup(_width: float) -> void:
	position += POS - XBattleScene.OTB_POS
	bar_width = WIDTH
	x1 = R_NOW * 2.0 + 10.0 + R_ROW + (LH - R_NOW)   # 第一个小圆圆心（大圆圆心在 LH）
	x2 = x1
	width1 = 0.0
	width2 = 0.0
	sep_node = Node2D.new()
	sep_node.z_index = 1
	sep_node.draw.connect(_draw_sep)
	add_child(sep_node)


## 按两段人数摆：圆心间距统一，整条不超过 WIDTH；挤不下就缩间距（会叠，同原版压缩）
func layout_for(n1: int, n2: int) -> void:
	var last := WIDTH - R_ROW
	var total := n1 + n2
	var avail := last - x1 - (SEP if n1 > 0 and n2 > 0 else 0.0)
	step_px = STEP_MAX if total <= 1 else minf(STEP_MAX, floorf(avail / float(total - 1)))
	if n1 > 0 and n2 > 0:
		x2 = x1 + n1 * step_px + SEP
		sep_x = x2 - step_px / 2.0 - SEP / 2.0
	else:
		x2 = x1 + n1 * step_px
		sep_x = -1.0
	width1 = maxf(x2 - x1 - SEP, 0.0)
	width2 = maxf(last - x2, 0.0)
	queue_redraw()


func show_orders(current: Array, next: Array, instant := false) -> void:
	layout_for(current.size(), next.size())
	super.show_orders(current, next, instant)


func _step(_n: int, _row_width: float) -> float:
	return step_px


func _slot_x(row: String, index: int, _n: int) -> float:
	return (x1 if row == "c" else x2) + index * step_px


func _draw() -> void:
	if sep_node != null:
		sep_node.queue_redraw()


func _draw_sep() -> void:
	if sep_x < 0.0:
		return
	var f := XUiSkin.font("body")
	var col_w := 18.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(XUiSkin.BG, 0.82)
	sb.set_corner_radius_all(6)
	sb.draw(sep_node.get_canvas_item(), Rect2(sep_x + 2.0 - col_w / 2.0, LH - 22.0, col_w, 44.0))
	sep_node.draw_line(Vector2(sep_x - 8.0, LH - 20.0), Vector2(sep_x - 8.0, LH + 20.0), Color(XUiSkin.LINE, 0.5), 1.0)
	var fs := 12
	for i in SEP_TEXT.length():
		var ch := SEP_TEXT[i]
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		sep_node.draw_string(f, Vector2(sep_x + 2.0 - w / 2.0, LH - 20.0 + fs + i * (fs + 2)), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_2)


func _icon(b: XBattler) -> Icon:
	var node := Icon.new(b)
	node.painter = _paint_icon
	node.face.visible = false
	var disk := Disk.new()
	disk.icon = node
	disk.material = node.face.material
	node.add_child(disk)
	return node


static func radius_of(node: Icon) -> float:
	if node.has_meta("preview"):
		return R_PREVIEW
	if node.big:
		return R_NOW
	return R_SELECTED if node.selected else R_ROW


## 名字只给当前的人（大圆）和敌人；人多挤得圆叠起来时（间距小于一个小圆）敌人名字会互相压住，只给被选为目标的敌人标
static func name_of(node: Icon) -> String:
	if node.has_meta("preview") or node.battler == null:
		return ""
	if node.big:
		return node.battler.display_name()
	if node.battler is XEnemy:
		var bar := node.get_parent() as XSkinOTBBar
		if bar == null or bar.step_px >= R_ROW * 2.0 or node.selected:
			return node.battler.display_name()
	return ""


func _paint_icon(node: Icon) -> void:
	var r := radius_of(node)
	var enemy := node.battler is XEnemy
	if node.has_meta("preview"):
		node.draw_circle(Vector2.ZERO, r, Color(XUiSkin.TEXT, 0.18))
	else:
		if node.big:
			node.draw_circle(Vector2.ZERO, r + 7.0, Color(XUiSkin.SEL_FILL, 0.22))
			node.draw_circle(Vector2.ZERO, r + 3.5, Color(XUiSkin.SEL_FILL, 0.30))
		node.draw_circle(Vector2.ZERO, r, ENEMY_DARK if enemy else XUiSkin.ORB_LOW)
		node.draw_circle(Vector2(-0.15, -0.2) * r, r * 0.6, Color(ENEMY_LIGHT if enemy else XUiSkin.ORB_HI, 0.75))
	var nm := name_of(node)
	if nm != "":
		var f := XUiSkin.font("body")
		var fs := 14 if node.big else 13
		var maxw := maxf(step_px + 8.0, 52.0) if not node.big else 90.0
		nm = fit(f, nm, maxw, fs)
		var w := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var col := XUiSkin.TEXT if node.big else ENEMY_NAME
		node.draw_string_outline(f, Vector2(-w / 2.0, r + 4.0 + fs), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.7))
		node.draw_string(f, Vector2(-w / 2.0, r + 4.0 + fs), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	for c in node.get_children():
		if c is Disk:
			c.queue_redraw()


static func fit(f: Font, text: String, width: float, fs: int) -> String:
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
		return text
	while text.length() > 1 and f.get_string_size(text + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		text = text.left(-1)
	return text + "…"


## 头像圆片（父节点画完底之后画，所以描边压在头像上）：角色取侧视图第一格的头部（样稿 head()：64 格里 (10,8) 起 44×44），
## 敌人整张按比例放进圆里
class Disk extends Node2D:
	var icon: XOTBBar.Icon
	var _atlas: AtlasTexture

	func _region() -> Rect2:
		var tex := icon.face.texture
		var full := Rect2(Vector2.ZERO, tex.get_size())
		return icon.face.region_rect if icon.face.region_enabled else full

	func _draw() -> void:
		var r := XSkinOTBBar.radius_of(icon)
		var tex := icon.face.texture
		var alpha := 0.55 if icon.has_meta("preview") else 1.0
		if tex != null:
			var reg := _region()
			if icon.battler is XActor:
				var k := reg.size / 64.0
				var head := Rect2(reg.position + Vector2(10, 8) * k, Vector2(44, 44) * k)
				if _atlas == null:
					_atlas = AtlasTexture.new()
				if tex is AtlasTexture and (tex as AtlasTexture).atlas != null:   # 图本身是图集里的一块：换到整张图的坐标
					_atlas.atlas = (tex as AtlasTexture).atlas
					head.position += (tex as AtlasTexture).region.position
				else:
					_atlas.atlas = tex
				_atlas.region = head
				XSkinPartyStrip.draw_round_texture(self, _atlas, Vector2.ZERO, r - 2.0)
				if alpha < 1.0:
					draw_circle(Vector2.ZERO, r - 2.0, Color(0, 0, 0, 1.0 - alpha))
			else:
				var s := minf((r * 1.7) / maxf(reg.size.x, reg.size.y), 2.0)
				var sz := reg.size * s
				var dst := Rect2(-sz / 2.0 + Vector2(0, 2), sz)
				if icon.face.flip_h:
					dst = Rect2(dst.position + Vector2(sz.x, 0), Vector2(-sz.x, sz.y))
				draw_texture_rect_region(tex, dst, reg, Color(1, 1, 1, alpha))
		var ring := Color(XUiSkin.LINE, 0.6)
		var w := 1.5
		if icon.has_meta("preview"):
			ring = Color(XUiSkin.TEXT, 0.8)
		elif icon.big:
			ring = XUiSkin.SEL_LINE
			w = 2.5
		elif icon.selected:
			ring = Color(XUiSkin.GOLD, 0.6 + 0.4 * absf(sin(icon._t * TAU)))
			w = 2.5
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, ring, w, true)
