class_name XBattleIndicators
extends RefCounted
## 角色形象 CodexBattleIndicators（installNativeCharacterVisualRuntime 后半，Sprite_Actor.update 包装，跟着实际显示的那一帧）：
## - 宿傩 172 领域展开中：脚下红色法阵（XBattleIndicators.DomainCircle），放在战斗者最底层（addChildAt 0，影子之下）。
## - 黑闪觉醒：身体外两层 8 方向剪影描边（暗红 3.5px、亮红 2px），插在身体之下，跟身体同帧同变换。
## - 只在战斗中、活着、身体看得见且有图时显示；换战斗者时藏起两者（XBattlerSprite 一只精灵只对一个战斗者，不用另做）。
## 画面只读状态：原版只在临时数据已存在时才调状态访问器（不为渲染开机制），这里同样先查 _temp 再判。

## 描边颜色（OUTLINE_COLORS：层 0 暗红、层 1 亮红）与每层偏移距离；setBlendColor 不透明度 255＝整色换掉、保留原透明度
const OUTLINE_COLORS := [Color8(25, 5, 11), Color8(255, 41, 71)]
const OUTLINE_DISTANCE := [3.5, 2.0]

const SILHOUETTE_SHADER := """
shader_type canvas_item;
uniform vec4 fill : source_color;
void fragment() {
	COLOR = vec4(fill.rgb, texture(TEXTURE, UV).a * COLOR.a);
}
"""
static var _silhouette: Shader
static var _materials := {}


## 宿傩领域法阵是否显示（CodexSukuna.activeDomain；_codexSukuna 不存在时不调）
static func domain_shown(b) -> bool:
	return b is XActor and int(b.actor_id) == XSukuna.ACTOR and XSukuna._temp.has(b) and XSukuna.active_domain(b)


## 黑闪觉醒描边是否显示（CodexBlackFlash.status(a).awake；_codexBlackFlashTemp 不存在时不调）
static func outline_shown(b) -> bool:
	return b is XActor and XBlackFlash._temp.has(b) and XBlackFlash.awake(b)


static func silhouette_material(layer: int) -> ShaderMaterial:
	if not _materials.has(layer):
		if _silhouette == null:
			_silhouette = Shader.new()
			_silhouette.code = SILHOUETTE_SHADER
		var m := ShaderMaterial.new()
		m.shader = _silhouette
		m.set_shader_parameter("fill", OUTLINE_COLORS[layer])
		_materials[layer] = m
	return _materials[layer]


## awakeningOutline：2 层 × 8 个方向的剪影，层 0 在下
static func make_outline() -> Node2D:
	var root := Node2D.new()
	root.name = "BlackFlashOutline"
	for layer in 2:
		for i in 8:
			var clone := Sprite2D.new()
			var angle := i * PI / 4.0
			clone.set_meta("offset", Vector2(cos(angle), sin(angle)) * float(OUTLINE_DISTANCE[layer]))
			clone.material = silhouette_material(layer)
			root.add_child(clone)
	return root


## syncOutline：每个剪影取身体当前帧（图、区域、锚点偏移、翻转、缩放、旋转、斜切），位置＝身体位置＋偏移（战斗者坐标，不随身体缩放），透明度同身体
static func sync_outline(root: Node2D, body: Sprite2D) -> void:
	for clone: Sprite2D in root.get_children():
		clone.texture = body.texture
		clone.centered = body.centered
		clone.offset = body.offset
		clone.region_enabled = body.region_enabled
		clone.region_rect = body.region_rect
		clone.flip_h = body.flip_h
		clone.flip_v = body.flip_v
		clone.scale = body.scale
		clone.rotation = body.rotation
		clone.skew = body.skew
		clone.position = body.position + (clone.get_meta("offset") as Vector2)
		clone.modulate = Color(1, 1, 1, body.modulate.a)


## domainCircle：PIXI.Graphics 画的法阵，y 压扁 0.34；透明度 0.82±0.08 呼吸（每帧 tick+1、cos(tick×0.04)），图形每帧转 0.003。
## 线不抗锯齿（原版渲染器 antialias 关）：与原版 pixi.js 同帧截图比，红色掩码交并比 0.98（03_转换工具/ui_reference/domain_circle_ref.py）
class DomainCircle extends Node2D:
	const RED := Color8(243, 43, 64)
	const DARK := Color8(36, 3, 11)
	var drawing := Node2D.new()
	var tick := 0

	func _init() -> void:
		name = "DomainCircle"
		scale.y = 0.34
		drawing.draw.connect(_paint)
		add_child(drawing)

	## 每帧（Sprite_Actor.update）推进一次
	func step() -> void:
		tick += 1
		modulate.a = 0.82 + cos(tick * 0.04) * 0.08
		drawing.rotation += 0.003

	func _ring(r: float, width: float, c: Color) -> void:
		drawing.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, c, width, false)

	func _paint() -> void:
		drawing.draw_circle(Vector2.ZERO, 88.0, Color(RED, 0.07))
		_ring(88.0, 7.0, Color(DARK, 0.8))
		_ring(73.0, 7.0, Color(DARK, 0.8))
		_ring(88.0, 2.5, Color(RED, 0.95))
		var thin := Color(RED, 0.85)
		_ring(73.0, 1.5, thin)
		_ring(49.0, 1.5, thin)
		# 两个三角（尖朝上、尖朝下），半径 59
		for triangle in 2:
			var pts := PackedVector2Array()
			for point in 4:
				var angle := -PI / 2.0 + triangle * PI + point * TAU / 3.0
				pts.append(Vector2(cos(angle), sin(angle)) * 59.0)
			drawing.draw_polyline(pts, thin, 1.5, false)
		# 12 个符：折线 3 点＋一道横
		for glyph in 12:
			var a := glyph * PI / 6.0
			var c := cos(a)
			var s := sin(a)
			drawing.draw_polyline(PackedVector2Array([Vector2(c * 77 - s * 3, s * 77 + c * 3), Vector2(c * 84 - s * 3, s * 84 + c * 3),
				Vector2(c * 84 + s * 3, s * 84 - c * 3)]), thin, 1.5, false)
			drawing.draw_line(Vector2(c * 80 - s * 5, s * 80 + c * 5), Vector2(c * 80 + s * 5, s * 80 - c * 5), thin, 1.5, false)
