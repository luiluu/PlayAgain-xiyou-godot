class_name XRavenFx
extends Node2D
## 渡鸦的低开销战斗特效（installNativeRavenRuntime R.Fx）：战场层里 4 个图形轮流用，触发时画一次，之后每帧只改透明度与缩放。
## - 位置：目标精灵脚下往上 48（Sprite_Battler 的 x, y−48）。
## - ring（神话封解施放，CodexRavenMyth 进入神话形态）：5px #8c4dff 0.9 半径 72 的圆＋2px #35a8ff 0.8 半径 92 的圆，28 帧。
## - slash（CodexRavenDamage 技能每次 apply）：6px #a84dff 0.9 的弧（(−92,55) 经控制点 (0,−78) 到 (92,55) 的二次曲线），16 帧。
## - harvest（冥界收割）：同弧 10px #a84dff；echo（回响）：同弧 6px #356dff；都 16 帧。
## - 每帧（Scene_Battle.update）：帧数减一、透明度 ×0.88、缩放 +0.025，帧数到 0 隐藏。挑第一个没在放的，都在放就用第一个。

const RING := [[5.0, Color("#8c4dff", 0.9), 72.0], [2.0, Color("#35a8ff", 0.8), 92.0]]
const ARC := {"slash": [6.0, Color("#a84dff", 0.9)], "harvest": [10.0, Color("#a84dff", 0.9)], "echo": [6.0, Color("#356dff", 0.9)]}

## installRavenSkillEffectsRuntime：这几个技能不放原动画，换成矢量施放特效（羽毛绕目标旋转，每组最多 12 片），只留一个音效
const STYLES := {
	10122: {"life": 32, "count": 3, "radius": 48.0, "slash": 1, "color": Color8(0x89, 0xd8, 0xe2)},
	10123: {"life": 40, "count": 7, "radius": 74.0, "slash": 3, "color": Color8(0x93, 0x88, 0xe8)},
	10124: {"life": 44, "count": 8, "radius": 88.0, "slash": 0, "color": Color8(0x67, 0xbf, 0xc8)},
	10125: {"life": 42, "count": 6, "radius": 96.0, "slash": 2, "color": Color8(0xa2, 0x87, 0xed)},
	10126: {"life": 50, "count": 12, "radius": 116.0, "slash": 0, "color": Color8(0x8a, 0xdf, 0xd7)},
	10127: {"life": 48, "count": 12, "radius": 105.0, "slash": 0, "color": Color8(0xba, 0x9c, 0xf7)},
}
const MAX_CASTS := 6

var pool: Array = []
## 测试用：放过的特效 [{type, target}]
var played: Array = []
## 正在放的施放特效（V.active）
var casts: Array = []


class Shape:
	extends Node2D
	var kind := ""
	var frames := 0

	func _draw() -> void:
		if kind == "ring":
			for r in XRavenFx.RING:
				draw_arc(Vector2.ZERO, r[2], 0.0, TAU, 64, r[1], r[0], true)
			return
		var spec: Array = XRavenFx.ARC.get(kind, XRavenFx.ARC.slash)
		var pts := PackedVector2Array()
		for i in 33:
			var t := i / 32.0
			pts.append((1 - t) * (1 - t) * Vector2(-92, 55) + 2 * (1 - t) * t * Vector2(0, -78) + t * t * Vector2(92, 55))
		draw_polyline(pts, spec[1], spec[0], true)


## Effect：spots 是各目标的落点，origin 是施法者位置（带刀光的技能羽毛从这里飞向目标）
class Cast:
	extends Node2D
	var skill_id := 0
	var style := {}
	var age := 0
	var spots: Array = []
	var origin := Vector2.ZERO

	func _quad(a: Vector2, c: Vector2, b: Vector2) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 13:
			var t := i / 12.0
			pts.append((1 - t) * (1 - t) * a + 2 * (1 - t) * t * c + t * t * b)
		return pts

	func _feather(at: Vector2, rot: float, size: float, alpha: float) -> void:
		var color: Color = style.color
		draw_set_transform(at, rot, Vector2(size, size))
		var body := _quad(Vector2(0, -19), Vector2(13, -8), Vector2(6, 5))
		body.append_array(_quad(Vector2(0, 16), Vector2(-12, 1), Vector2(0, -19)))
		draw_colored_polygon(body, Color8(0x17, 0x12, 0x27, int(245 * alpha)))
		draw_polyline(body, Color(color, 0.85 * alpha), 1.2, true)
		draw_line(Vector2(0, -14), Vector2(0, 12), Color8(0xd5, 0xf2, 0xef, int(166 * alpha)), 0.8, true)
		draw_set_transform(Vector2.ZERO)

	func _draw() -> void:
		var life := float(style.life)
		var t := minf(1.0, age / life)
		var fade := sin(PI * t)
		var angle := t * PI * 1.9
		var color: Color = style.color
		var slash := int(style.slash)
		var radius := float(style.radius) * (0.32 + 0.68 * t)
		var opacity := fade * 0.54
		for p: Vector2 in spots:
			draw_set_transform(p, 0.0, Vector2(1.0, 0.58))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color, opacity), 2.0, true)
			draw_set_transform(p, 0.0, Vector2(0.8, 0.82))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(Color8(0x66, 0x50, 0x94), opacity * 0.75), 1.0, true)
			draw_set_transform(Vector2.ZERO)
			for k in slash:
				var local := (t - k * 0.10) * 1.7
				if local < 0.0 or local > 1.0:
					continue
				var a := Vector2(p.x - radius * 0.9, p.y + radius * 0.45 - k * 17)
				var b := Vector2(p.x + radius * 0.9, p.y - radius * 0.55 - k * 17)
				draw_polyline(_quad(a, Vector2(p.x, p.y - radius * 0.2), b), Color(color, sin(local * PI) * 0.9), 5.0 if slash == 2 else 3.0, true)
			if slash == 0:
				for k in 3:
					var a2 := angle + k * TAU / 3.0
					var s := p + Vector2(cos(a2) * radius, sin(a2) * radius * 0.58)
					var c := p + Vector2(cos(a2 + 0.9) * radius * 0.4, sin(a2 + 0.9) * radius * 0.5)
					draw_polyline(_quad(s, c, p), Color(color, opacity), 1.5, true)
		var count := int(style.count)
		var size := 1.3 if skill_id == 10125 else 0.8
		for i in count:
			var p: Vector2 = spots[i % spots.size()]
			var a3 := angle + i * TAU / count
			var r := float(style.radius) * (0.95 - 0.55 * t if slash > 0 else 1.1 - 0.92 * t)
			var start := maxf(0.0, 1.0 - t * 2.0) if slash > 0 else 0.0
			var at := p + Vector2(cos(a3) * r, sin(a3) * r * 0.7) + (origin - p) * start
			_feather(at, a3 + 0.5, size, fade)


func _ready() -> void:
	for i in 4:
		var g := Shape.new()
		g.visible = false
		add_child(g)
		pool.append(g)


## R.Fx.play(subject, target, type)：at 是目标精灵的位置（脚下）
func play(type: String, at: Vector2, target = null) -> void:
	played.append({"type": type, "target": target})
	var free := pool.filter(func(g): return not g.visible)
	var g: Shape = free[0] if not free.is_empty() else pool[0]
	g.kind = type
	g.position = at - Vector2(0, 48)
	g.modulate.a = 1.0
	g.scale = Vector2.ONE
	g.visible = true
	g.frames = 28 if type == "ring" else 16
	g.queue_redraw()


## V.play：放一组施放特效，返回节点；超过 6 组挤掉最早的
func play_cast(skill_id: int, spots: Array, origin: Vector2) -> Cast:
	while casts.size() >= MAX_CASTS:
		_end_cast(casts[0])
	var c := Cast.new()
	c.skill_id = skill_id
	c.style = STYLES[skill_id]
	c.spots = spots
	c.origin = origin
	add_child(c)
	casts.append(c)
	played.append({"type": "cast", "skill": skill_id, "spots": spots.size()})
	return c


func _end_cast(c: Cast) -> void:
	casts.erase(c)
	c.queue_free()


## isAnimationPlaying 包装：有施放特效时算动画没放完
func busy() -> bool:
	return not casts.is_empty()


func _physics_process(_delta: float) -> void:
	for c: Cast in casts.duplicate():
		c.age += 1
		if c.age >= int(c.style.life):
			_end_cast(c)
		else:
			c.queue_redraw()
	for g in pool:
		if not g.visible:
			continue
		g.frames -= 1
		g.modulate.a *= 0.88
		g.scale += Vector2(0.025, 0.025)
		if g.frames <= 0:
			g.visible = false
