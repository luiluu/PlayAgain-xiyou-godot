class_name XHonghuangMonumentView
extends Node2D
## 【小A·未经审查】T460：西游大厅洪荒碑的地图视觉绘制层（只在 Map004 且西游档＋开关开启时由 XMapScene 创建）。
## 节点本身挂在 XMapScene 下，实际绘制子节点挂入 host.chars 并以碑脚底 y 坐标参与 y_sort，
## 玩家走到碑后时被碑身自然遮挡，走到碑前时位于底座之前。
## 按 Kyo 11-25 要求（绝不做小块圆顶灰碑，要高大、庄严有威压感的丰碑／镇界石）：
## 现有素材中无合适的镇界丰碑图（!$fsm_Statue03 偏圆顶灰碑已排除），当前以程序绘制三层坛座＋飞檐护翼＋方尖赤金冠顶的
## 高大玄金暗赤镇界丰碑（约 72×138px）占位，并预留 TEX_PATH 供后续小o 美术卡替换。

const TS := 48
## 预留正式美术贴图路径（脚底居中锚点）；存在时优先使用，不存在时走程序绘制
static var TEX_PATH := "res://content/lobby/honghuang_monument.png"

var host: XMapScene
var _stele_node: Node2D
var _tex: Texture2D
var _t := 0.0


func setup(map: XMapScene) -> void:
	host = map
	name = "HonghuangMonumentView"
	_tex = load(TEX_PATH) if TEX_PATH != "" and ResourceLoader.exists(TEX_PATH) else null
	var foot_y := (XHonghuangMonument.CELL.y + 1) * TS
	_stele_node = Node2D.new()
	_stele_node.name = "HonghuangMonumentStele"
	_stele_node.position = Vector2(0.0, float(foot_y))
	_stele_node.draw.connect(_draw_stele)
	host.chars.add_child(_stele_node)


func _exit_tree() -> void:
	if is_instance_valid(_stele_node):
		_stele_node.queue_free()


func _process(delta: float) -> void:
	if not is_instance_valid(_stele_node):
		return
	if XGraphics.fx_on():
		_t += delta
		_stele_node.queue_redraw()


func _draw_stele() -> void:
	var n := _stele_node
	var cx := (XHonghuangMonument.CELL.x + 0.5) * TS
	if _tex != null:
		var sz := _tex.get_size()
		n.draw_texture(_tex, Vector2(cx - sz.x * 0.5, -sz.y))
		return

	var fx := XGraphics.fx_on()
	var pulse := (0.5 + 0.5 * sin(_t * 1.8)) if fx else 0.45

	# 厚重玄铁黑曜 + 鎏金 + 暗赤朱砂配色（庄严镇界丰碑）
	var obsidian_deep := Color(0.09, 0.08, 0.12)
	var obsidian_mid := Color(0.16, 0.14, 0.21)
	var obsidian_hi := Color(0.26, 0.23, 0.33)
	var crimson_dark := Color(0.38, 0.09, 0.11)
	var crimson_glow := Color(0.88, 0.26, 0.16, 0.55 + 0.30 * pulse)
	var gold_dark := Color(0.62, 0.45, 0.17)
	var gold := Color(0.92, 0.74, 0.32)
	var gold_bright := Color(1.0, 0.89, 0.54)
	var ink := Color(0.04, 0.03, 0.06)

	# 1. 底座厚重投影 + 暗金镇界地纹
	n.draw_colored_polygon(_ellipse_pts(Vector2(cx, -3.0), 38.0, 12.0, 20), Color(0.03, 0.02, 0.05, 0.42))
	n.draw_polyline(_oct_ring(Vector2(cx, -4.0), 34.0, 10.0), Color(gold, 0.28 + 0.14 * pulse), 1.2, true)

	# 2. 背后庄严神光竖晕（暗金赤微芒，增强威压气场）
	n.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 28.0, -24.0),
		Vector2(cx + 28.0, -24.0),
		Vector2(cx + 22.0, -112.0),
		Vector2(cx, -142.0),
		Vector2(cx - 22.0, -112.0),
	]), Color(0.95, 0.62, 0.22, 0.08 + 0.09 * pulse))

	# 3. 三层阶梯玄武石坛底座（稳重宽阔）
	# 一层基坛（宽 68）
	var s1 := Rect2(cx - 34.0, -11.0, 68.0, 9.0)
	n.draw_rect(s1, obsidian_deep)
	n.draw_rect(Rect2(cx - 33.0, -11.0, 66.0, 2.5), obsidian_hi)
	n.draw_rect(s1, ink, false, 1.8)
	# 二层束腰（宽 58，暗赤镶边 + 鎏金托线）
	var s2 := Rect2(cx - 29.0, -19.0, 58.0, 8.0)
	n.draw_rect(s2, obsidian_mid)
	n.draw_rect(Rect2(cx - 27.0, -16.5, 54.0, 3.0), crimson_dark)
	n.draw_line(Vector2(cx - 28.0, -11.5), Vector2(cx + 28.0, -11.5), Color(gold_dark, 0.85), 1.4)
	n.draw_rect(s2, ink, false, 1.6)
	# 三层承台（宽 48，鎏金压檐）
	var s3 := Rect2(cx - 24.0, -27.0, 48.0, 8.0)
	n.draw_rect(s3, obsidian_mid)
	n.draw_rect(Rect2(cx - 24.0, -27.0, 48.0, 2.5), gold_dark)
	n.draw_line(Vector2(cx - 23.0, -26.5), Vector2(cx + 23.0, -26.5), gold, 1.2)
	n.draw_rect(s3, ink, false, 1.6)
	# 底座左右微型护碑金柱（破开单调轮廓）
	for dir: float in [-1.0, 1.0]:
		var px: float = cx + dir * 28.0
		var pillar := Rect2(px - 3.5, -31.0, 7.0, 22.0)
		n.draw_rect(pillar, obsidian_deep)
		n.draw_rect(Rect2(px - 2.5, -31.0, 5.0, 3.0), gold)
		n.draw_rect(pillar, ink, false, 1.2)
		n.draw_circle(Vector2(px, -33.0), 2.4, Color(gold_bright, 0.72 + 0.25 * pulse))

	# 4. 碑腰双侧镇界玄金翼棱（硬朗折角，彻底区分墓碑）
	for dir: float in [-1.0, 1.0]:
		var wing := PackedVector2Array([
			Vector2(cx + dir * 18.0, -34.0),
			Vector2(cx + dir * 27.0, -40.0),
			Vector2(cx + dir * 24.0, -76.0),
			Vector2(cx + dir * 17.0, -82.0),
		])
		n.draw_colored_polygon(wing, obsidian_deep)
		var wing_line := PackedVector2Array([
			Vector2(cx + dir * 18.5, -35.5),
			Vector2(cx + dir * 25.0, -41.0),
			Vector2(cx + dir * 22.5, -75.0),
			Vector2(cx + dir * 17.5, -80.5),
		])
		n.draw_polyline(wing_line, Color(gold_dark, 0.9), 1.5, false)
		var wing_out := wing.duplicate()
		wing_out.append(wing[0])
		n.draw_polyline(wing_out, ink, 1.4, true)

	# 5. 挺拔棱柱碑身（硬朗梯形削切，高耸挺拔）
	var body := PackedVector2Array([
		Vector2(cx - 20.0, -27.0),
		Vector2(cx + 20.0, -27.0),
		Vector2(cx + 16.5, -104.0),
		Vector2(cx - 16.5, -104.0),
	])
	n.draw_colored_polygon(body, obsidian_mid)
	# 左亮切面 & 右暗切面（立体石柱棱感）
	n.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 20.0, -27.0),
		Vector2(cx - 12.0, -27.0),
		Vector2(cx - 10.5, -104.0),
		Vector2(cx - 16.5, -104.0),
	]), Color(obsidian_hi, 0.72))
	n.draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 11.0, -27.0),
		Vector2(cx + 20.0, -27.0),
		Vector2(cx + 16.5, -104.0),
		Vector2(cx + 10.0, -104.0),
	]), Color(0.05, 0.04, 0.08, 0.58))
	var body_out := body.duplicate()
	body_out.append(body[0])
	n.draw_polyline(body_out, ink, 2.0, true)

	# 6. 内凹墨赤碑心 + 双层鎏金回纹框
	var core := PackedVector2Array([
		Vector2(cx - 12.5, -33.0),
		Vector2(cx + 12.5, -33.0),
		Vector2(cx + 10.5, -97.0),
		Vector2(cx - 10.5, -97.0),
	])
	n.draw_colored_polygon(core, Color(0.11, 0.06, 0.09))
	var core_out := core.duplicate()
	core_out.append(core[0])
	n.draw_polyline(core_out, gold_dark, 1.8, true)
	# 细内金线与四角折饰
	var inner := PackedVector2Array([
		Vector2(cx - 10.0, -35.5),
		Vector2(cx + 10.0, -35.5),
		Vector2(cx + 8.5, -94.5),
		Vector2(cx - 8.5, -94.5),
		Vector2(cx - 10.0, -35.5),
	])
	n.draw_polyline(inner, Color(gold, 0.65 + 0.25 * pulse), 1.0, true)

	# 碑身下部暗赤镇界能量脉纹
	n.draw_line(Vector2(cx, -38.0), Vector2(cx, -50.0), crimson_glow, 2.0)
	n.draw_line(Vector2(cx - 5.5, -43.0), Vector2(cx + 5.5, -43.0), Color(gold, 0.72), 1.2)
	n.draw_colored_polygon(PackedVector2Array([
		Vector2(cx, -47.0), Vector2(cx + 3.5, -43.0),
		Vector2(cx, -39.0), Vector2(cx - 3.5, -43.0),
	]), Color(gold_bright, 0.8 + 0.2 * pulse))

	# 7. 御碑飞檐叠额 + 凌厉方尖冠顶（绝不圆顶！）
	# 飞檐挑翼
	var eave := PackedVector2Array([
		Vector2(cx - 26.0, -104.0),
		Vector2(cx + 26.0, -104.0),
		Vector2(cx + 21.0, -112.0),
		Vector2(cx - 21.0, -112.0),
	])
	n.draw_colored_polygon(eave, obsidian_deep)
	n.draw_line(Vector2(cx - 25.0, -104.5), Vector2(cx + 25.0, -104.5), gold, 2.0)
	n.draw_line(Vector2(cx - 20.5, -111.5), Vector2(cx + 20.5, -111.5), gold_dark, 1.5)
	var eave_out := eave.duplicate()
	eave_out.append(eave[0])
	n.draw_polyline(eave_out, ink, 1.8, true)

	# 尖锐方尖冠峰（直指天穹的镇界峰顶）
	var spire := PackedVector2Array([
		Vector2(cx - 14.0, -112.0),
		Vector2(cx + 14.0, -112.0),
		Vector2(cx + 7.5, -124.0),
		Vector2(cx, -138.0),
		Vector2(cx - 7.5, -124.0),
	])
	n.draw_colored_polygon(spire, obsidian_mid)
	n.draw_colored_polygon(PackedVector2Array([
		Vector2(cx, -138.0),
		Vector2(cx + 7.5, -124.0),
		Vector2(cx + 14.0, -112.0),
		Vector2(cx, -112.0),
	]), Color(0.05, 0.04, 0.08, 0.48))
	var spire_out := spire.duplicate()
	spire_out.append(spire[0])
	n.draw_polyline(spire_out, ink, 1.8, true)
	n.draw_line(Vector2(cx, -136.0), Vector2(cx, -113.0), Color(gold, 0.85), 1.4)

	# 冠峰核心赤金神印（菱形灵晶，随特效呼吸明灭）
	var crown_gem := PackedVector2Array([
		Vector2(cx, -127.0),
		Vector2(cx + 4.5, -119.5),
		Vector2(cx, -112.0),
		Vector2(cx - 4.5, -119.5),
	])
	n.draw_colored_polygon(crown_gem, crimson_glow)
	n.draw_polyline(PackedVector2Array([crown_gem[0], crown_gem[1], crown_gem[2], crown_gem[3], crown_gem[0]]), gold_bright, 1.2, true)

	# 8. 碑心竖刻鎏金「洪荒」二字（威严厚重）
	var font := XUI.font()
	var fs := 15
	var glyphs := ["洪", "荒"]
	for i in glyphs.size():
		var ch: String = glyphs[i]
		var tw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(cx - tw * 0.5, -75.0 + i * 20.0)
		n.draw_string_outline(font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0.05, 0.02, 0.04, 0.96))
		n.draw_string(font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(gold_bright, 0.88 + 0.12 * pulse))

	# 9. 底座正中鎏金铭牌（点题丰碑气质）
	var plaque := Rect2(cx - 15.0, -24.5, 30.0, 5.0)
	n.draw_rect(plaque, gold_dark)
	n.draw_rect(Rect2(cx - 14.0, -24.0, 28.0, 2.0), Color(gold_bright, 0.8))
	n.draw_rect(plaque, ink, false, 1.0)

	# 10. 开特效时微弱上浮的金赤光尘（庄严克制）
	if fx:
		for i in 4:
			var phase := fmod(_t * 0.38 + float(i) * 0.25, 1.0)
			var side := -1.0 if i % 2 == 0 else 1.0
			var mx := cx + side * (16.0 + 9.0 * sin(_t * 1.1 + float(i) * 1.7))
			var my := -24.0 - phase * 106.0
			var ma := sin(phase * PI) * 0.65
			n.draw_circle(Vector2(mx, my), 1.7, Color(gold_bright, ma))


static func _ellipse_pts(center: Vector2, rx: float, ry: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segs:
		var a := TAU * float(i) / float(segs)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _oct_ring(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 9:
		var a := TAU * float(i % 8) / 8.0 + PI / 8.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
