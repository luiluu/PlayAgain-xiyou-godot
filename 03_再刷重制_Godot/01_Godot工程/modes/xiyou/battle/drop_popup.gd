class_name XDropPopup
extends Node2D
## 设置「开启掉落动画」（MOG_TrPopUpBattle v1.0，参数：死亡后立即掉落 true、掉落方式 0 弹跳、持续时间 10、图标比例 1.0；
## 生效的 createIcon/refreshIcons 是 krz_iconsetimprove 的覆写版）。
## 敌人倒下动画结束时，它的掉落图标从敌人脚下上方 40 处落下弹跳，停稳后依次淡出（SpriteEnemyTrP）。
## - 每个图标：锚点 (0.5, 1)；intY = 敌人图高/3 + randomInt(32) − 32（停稳处在脚下上方 intY）；初速 dy 15；
##   横向每帧 ±(random×0.5 + 序号/8)（只在落地前移动）。每帧 dy += 0.6，ry += dy，ry ≥ 0 时落地 ry = 0、dy ×= −0.7；
##   y = −intY + round(ry)。停在地面那帧开始倒数 wait = 10 + 20×(个数 − 排序位置)，之后每帧不透明度 −15、
##   横向缩放 −0.05、纵向 +0.15。不透明度到 0 后只是看不见：Sprite_Base.update 每帧把 visible 设回 true，
##   所以弹跳/淡出照算（纵向缩放一直变大，影响跟着它的动画高度）。
## - 图标与动画都是 SpriteEnemyTrP 的子节点，建好后按 intY 从大到小 children.sort（V8 短数组＝二分插入排序；
##   动画没有 intY，比较得 NaN 视为「不小于」）。这个顺序就是绘制先后与每帧更新顺序，见 _mv_sort。
## - 物品备注 <dh:N>：N 是动画 ID。建图标时就在图标上 Sprite_Base.startAnimation(动画 N)（不受「显示技能动画」开关影响；
##   帧速同战斗变速）。动画按 Sprite_Animation 原样逐帧：位置取图标「上一帧」的坐标（子节点先更新、弹跳在后），
##   头上/中心按图标高度 32×scale.y 上移；色相、屏幕闪光（盖住它之前的兄弟节点）、播完下一帧移除都在 MVAnimation。
##   图标不是战斗者，没有目标闪光与隐藏；dh 用到的动画只有 flashScope 0/2（测试守着）。
## - 位置每帧跟随敌人精灵；画在战斗者之上（battleField 内 z = 敌人 + 1）。
## - 正式版首次载入动画图要等 2～5 帧（异步加载）；这里图已预载，动画从第一帧就播（不复现加载等待）。
## 掉落的获得与「胜利时不再发放」由 XBattleLogic.drop_lock 负责（见 XBattleScene._enemy_collapsed）。

const ICON := 32.0
const START_Y := -40.0
const FADE_DURATION := 10
const ICON_SCALE := 1.0

var follow: Node2D
var icons: Array = []        # 按 intY 排好（_icons）：[{item, index, x, y, intY, dy, ry, vx, sx, sy, alpha, wait, visible, node, anim}]
var _born_icons: Array = []  # 建立顺序（排序前）
var _born_nodes: Array = []


## 一个掉落图标（SpriteEnemyTrP._icons[i]），画法读它的状态字典
class DropIcon:
	extends Node2D
	var g: Dictionary
	var tex: Texture2D
	var int_y := 0.0     # 排序键

	func _draw() -> void:
		if tex == null or g.alpha <= 0:
			return
		var w := XDropPopup.ICON * float(g.sx)
		var h := XDropPopup.ICON * float(g.sy)
		if w == 0.0 or h <= 0.0:
			return
		# 锚点 (0.5, 1)；横向缩放变负时左右翻转
		draw_texture_rect(tex, Rect2(g.x - w / 2.0, g.y - h, w, h), false, Color(1, 1, 1, g.alpha / 255.0))


## 图标上的 dh 动画：MVAnimation 由 XDropPopup.step 逐帧推进（不自己跑 _physics_process），位置取图标上一帧的坐标
class DhAnimation:
	extends MVAnimation
	var icon: Dictionary

	func _ready() -> void:
		super._ready()
		follow = _icon_position

	func _physics_process(_delta: float) -> void:
		pass

	## updatePosition：图标锚点 (0.5, 1)，头上/中心按图标高度 32×scale.y 上移；画面中央取 parent.width/2（SpriteEnemyTrP 没有位图，为 0）
	func _icon_position() -> Vector2:
		var h := XDropPopup.ICON * absf(icon.sy)
		match int(anim.get("position", 1)):
			0: return Vector2(icon.x, icon.y - h)
			1: return Vector2(icon.x, icon.y - h / 2.0)
			3: return Vector2.ZERO
		return Vector2(icon.x, icon.y)


## sprite_h：敌人精灵高度（Sprite_Enemy.height）；items：掉落记录（XDB 物品/武器/防具）
func setup(target: Node2D, sprite_h: float, items: Array) -> void:
	follow = target
	position = target.position
	visible = false
	var made: Array = []
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var hr := randi_range(0, int(ICON) - 1)
		var int_y := (sprite_h / 3.0 + hr) - ICON
		var randx := randf() * 0.5 + i / 8.0
		var g := {"item": item, "index": i, "x": 0.0, "y": START_Y, "intY": int_y, "dy": 15.0, "ry": START_Y + int_y,
			"vx": randx if randi_range(0, 1) == 0 else -randx, "sx": ICON_SCALE, "sy": ICON_SCALE,
			"alpha": 255, "wait": 0, "visible": true, "anim": null}
		var node := DropIcon.new()
		node.g = g
		node.tex = XUI.icon_texture(int(item.get("iconIndex", 0)))
		g.node = node
		add_child(node)
		var meta: Dictionary = item.get("meta", {})
		if meta.has("dh") and str(meta.dh).strip_edges().is_valid_int():
			var a := _start_animation(int(str(meta.dh)))
			if a:
				a.icon = g
				g.anim = a
		made.append(g)
	icons = made
	_born_icons = made.duplicate()
	_born_nodes = get_children()
	arrange()


## Sprite_Base.startAnimation：建在图标的父节点（本节点）里，紧跟在图标之后
func _start_animation(anim_id: int) -> DhAnimation:
	var data := XDB.rec("Animations", anim_id)
	if not MVAnimation.usable(data):
		return null
	var a := DhAnimation.new()
	a.anim = data
	a.rate = clampi(XConfig.battle_speed(), 1, 4)
	add_child(a)
	return a


## createIcon 末尾：_icons 与 children 各按 intY 从大到小排序，再按 _icons 顺序定 wait。
## 总是从建立顺序排起，改了 intY 后可再调（测试按正式版读数重排）。
func arrange() -> void:
	for g in _born_icons:
		g.node.int_y = g.intY
	icons = _mv_sort(_born_icons, func(g): return float(g.intY))
	var kids := _mv_sort(_born_nodes.filter(func(c): return is_instance_valid(c) and c.get_parent() == self),
		func(c): return c.int_y if c is DropIcon else NAN)
	for i in range(kids.size()):
		move_child(kids[i], i)
	var n := icons.size()
	for i in range(n):
		icons[i].wait = FADE_DURATION + (n * 20 - 20 * i)


## V8 Array.prototype.sort（短数组＝二分插入排序，稳定）配比较函数 (a, b) => b.intY − a.intY；
## 比较结果 NaN 时「< 0」为假，等同不小于。
static func _mv_sort(list: Array, key: Callable) -> Array:
	var a := list.duplicate()
	for start in range(1, a.size()):
		var pivot = a[start]
		var kp: float = key.call(pivot)
		var left := 0
		var right := start
		while left < right:
			var mid := left + ((right - left) >> 1)
			if key.call(a[mid]) - kp < 0.0:     # NaN < 0 为假
				right = mid
			else:
				left = mid + 1
		for p in range(start, left, -1):
			a[p] = a[p - 1]
		a[left] = pivot
	return a


func done() -> bool:
	return icons.all(func(g): return not g.visible) and not get_children().any(func(c): return c is DhAnimation)


func _physics_process(_delta: float) -> void:
	step()


## SpriteEnemyTrP.update 一帧：先按子节点顺序更新（图标移除播完的动画、动画推进），再跟随敌人、弹跳各图标
func step() -> void:
	for c in get_children():
		if c is DropIcon:
			var a: DhAnimation = c.g.anim
			if a != null and is_instance_valid(a) and not a.playing():
				c.g.anim = null
				a.finish()
		elif c is DhAnimation and c.get_parent() == self:
			c.advance()
	if follow and is_instance_valid(follow):
		position = follow.position
	for g in icons:
		visible = true
		_bounce(g)
		g.visible = g.alpha > 0
		g.node.queue_redraw()


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
