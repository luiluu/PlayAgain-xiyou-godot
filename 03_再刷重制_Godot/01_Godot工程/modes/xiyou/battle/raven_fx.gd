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

var pool: Array = []
## 测试用：放过的特效 [{type, target}]
var played: Array = []


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


func _physics_process(_delta: float) -> void:
	for g in pool:
		if not g.visible:
			continue
		g.frames -= 1
		g.modulate.a *= 0.88
		g.scale += Vector2(0.025, 0.025)
		if g.frames <= 0:
			g.visible = false
