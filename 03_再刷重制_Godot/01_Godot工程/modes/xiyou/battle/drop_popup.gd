class_name XDropPopup
extends Node2D
## 设置「开启掉落动画」（MOG_TrPopUpBattle v1.0，参数：死亡后立即掉落 true、掉落方式 0 弹跳、持续时间 10、图标比例 1.0）。
## 敌人倒下动画结束时，它的掉落图标从敌人脚下上方 40 处落下弹跳，停稳后依次淡出（SpriteEnemyTrP）。
## - 每个图标：锚点 (0.5, 1)；intY = 敌人图高/3 + randomInt(32) − 32（停稳处在脚下上方 intY）；初速 dy 15；
##   横向每帧 ±(random×0.5 + 序号/8)（只在落地前移动）。每帧 dy += 0.6，ry += dy，ry ≥ 0 时落地 ry = 0、dy ×= −0.7；
##   y = −intY + round(ry)。停在地面那帧开始倒数 wait = 10 + 20×(个数 − 排序位置)，之后每帧不透明度 −15、
##   横向缩放 −0.05、纵向 +0.15，透明后隐藏。图标按 intY 从大到小排序（决定绘制先后与等待）。
## - 物品备注 <dh:N>：在图标上播放动画 N（Sprite_Base.startAnimation，不受「显示技能动画」开关影响；帧速同战斗变速），动画跟着图标。
## - 位置每帧跟随敌人精灵；画在战斗者之上（battleField 内 z = 敌人 + 1）。
## 掉落的获得与「胜利时不再发放」由 XBattleLogic.drop_lock 负责（见 XBattleScene._enemy_collapsed）。

const ICON := 32.0
const START_Y := -40.0
const FADE_DURATION := 10
const ICON_SCALE := 1.0

var follow: Node2D
var icons: Array = []        # [{item, index, tex, x, y, intY, dy, ry, vx, sx, sy, alpha, wait, visible, anim}]
var _started := false


## sprite_h：敌人精灵高度（Sprite_Enemy.height）；items：掉落记录（XDB 物品/武器/防具）
func setup(target: Node2D, sprite_h: float, items: Array) -> void:
	follow = target
	position = target.position
	visible = false
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var hr := randi_range(0, int(ICON) - 1)
		var int_y := (sprite_h / 3.0 + hr) - ICON
		var randx := randf() * 0.5 + i / 8.0
		icons.append({"item": item, "index": i, "tex": XUI.icon_texture(int(item.get("iconIndex", 0))),
			"x": 0.0, "y": START_Y, "intY": int_y, "dy": 15.0, "ry": START_Y + int_y,
			"vx": randx if randi_range(0, 1) == 0 else -randx, "sx": ICON_SCALE, "sy": ICON_SCALE,
			"alpha": 255, "wait": 0, "visible": true, "anim": null})
	icons.sort_custom(func(a, b): return a.intY > b.intY)
	var n := icons.size()
	for i in range(n):
		icons[i].wait = FADE_DURATION + (n * 20 - 20 * i)
	for g in icons:
		var meta: Dictionary = g.item.get("meta", {})
		if meta.has("dh") and str(meta.dh).strip_edges().is_valid_int():
			g.anim = MVAnimation.play(self, int(str(meta.dh)), Vector2.ZERO, false, XConfig.battle_speed())


func done() -> bool:
	return icons.all(func(g): return not g.visible)


func _physics_process(_delta: float) -> void:
	step()


## SpriteEnemyTrP.update 一帧
func step() -> void:
	if follow and is_instance_valid(follow):
		position = follow.position
	for g in icons:
		if g.visible:
			visible = true
			_bounce(g)
			if g.alpha <= 0:
				g.visible = false
		_place_anim(g)
	queue_redraw()


func _bounce(g: Dictionary) -> void:
	g.dy += 0.6
	g.ry += g.dy
	if g.ry >= 0.0:
		g.ry = 0.0
		g.dy *= -0.7
	g.y = -g.intY + floorf(g.ry + 0.5)      # JS Math.round
	if g.y < -g.intY:
		g.x += g.vx
	if g.y == -g.intY:
		_fade(g)


func _fade(g: Dictionary) -> void:
	g.wait -= 1
	if g.wait > 0:
		return
	g.alpha = maxi(0, g.alpha - 15)
	g.sx -= 0.05
	g.sy += 0.15


## Sprite_Animation.updatePosition：动画放在图标所在处，头上/中心按图标高度上移
func _place_anim(g: Dictionary) -> void:
	var a: MVAnimation = g.anim
	if a == null or not is_instance_valid(a):
		return
	var h := ICON * float(g.sy)
	var at := Vector2(g.x, g.y)
	match int(a.anim.get("position", 1)):
		0: at.y -= h
		1: at.y -= h / 2.0
		3: at = XBattleScene.BOX / 2.0 - position
	a.position = at


func _draw() -> void:
	for g in icons:
		if not g.visible or g.tex == null:
			continue
		var w := ICON * float(g.sx)
		var h := ICON * float(g.sy)
		if w <= 0.0 or h <= 0.0:
			continue
		draw_texture_rect(g.tex, Rect2(g.x - w / 2.0, g.y - h, w, h), false, Color(1, 1, 1, g.alpha / 255.0))
