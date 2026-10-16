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
##   头上/中心按图标高度 32×scale.y 上移；动画图按 animation1Hue/animation2Hue 转色相（Bitmap.rotateHue，见 HUE_SHADER）；
##   屏幕闪光（flashScope 2）是动画的子节点，画满整个画面、盖住它之前的兄弟节点，不透明度每帧 ×(d−1)/d；
##   播完（_duration 到 0）的下一帧由图标移除。dh 用到的动画只有 flashScope 0/2（测试守着）。
## - 位置每帧跟随敌人精灵；画在战斗者之上（battleField 内 z = 敌人 + 1）。
## - 正式版首次载入动画图要等 2～5 帧（异步加载）；这里图已预载，动画从第一帧就播（不复现加载等待）。
## 掉落的获得与「胜利时不再发放」由 XBattleLogic.drop_lock 负责（见 XBattleScene._enemy_collapsed）。

const ICON := 32.0
const START_Y := -40.0
const FADE_DURATION := 10
const ICON_SCALE := 1.0

## Bitmap.rotateHue 逐像素：RGB→HSL、色相加 hue、再转回，写回 Uint8ClampedArray（四舍五入到偶数）。
## 正式版在载入时改图，这里在取样后改；格子缩放时边缘插值次序不同，差别只在半透明边缘。
const HUE_SHADER := """
shader_type canvas_item;
render_mode %s;
uniform float hue;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 p = floor(t.rgb * 255.0 + 0.5);
	float cmin = min(p.r, min(p.g, p.b));
	float cmax = max(p.r, max(p.g, p.b));
	float h = 0.0;
	float s = 0.0;
	float l = (cmin + cmax) / 2.0;
	float d = cmax - cmin;
	if (d > 0.0) {
		if (p.r == cmax) { h = 60.0 * mod((p.g - p.b) / d + 6.0, 6.0); }
		else if (p.g == cmax) { h = 60.0 * ((p.b - p.r) / d + 2.0); }
		else { h = 60.0 * ((p.r - p.g) / d + 4.0); }
		s = d / (255.0 - abs(2.0 * l - 255.0));
	}
	h = mod(h + hue, 360.0);
	float c = (255.0 - abs(2.0 * l - 255.0)) * s;
	float x = c * (1.0 - abs(mod(h / 60.0, 2.0) - 1.0));
	float m = l - c / 2.0;
	float cm = c + m;
	float xm = x + m;
	vec3 o;
	if (h < 60.0) { o = vec3(cm, xm, m); }
	else if (h < 120.0) { o = vec3(xm, cm, m); }
	else if (h < 180.0) { o = vec3(m, cm, xm); }
	else if (h < 240.0) { o = vec3(m, xm, cm); }
	else if (h < 300.0) { o = vec3(xm, m, cm); }
	else { o = vec3(cm, m, xm); }
	COLOR = vec4(clamp(roundEven(o), 0.0, 255.0) / 255.0, t.a) * tint;
}
"""

static var _hue_shaders := {}
static var _hue_materials := {}

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


## 图标上的 dh 动画（Sprite_Animation）：由 XDropPopup.step 逐帧推进，不自己跑 _physics_process
class DhAnimation:
	extends MVAnimation
	var target: Dictionary
	var duration := 0
	var wait := 0            # Sprite_Animation._delay（startAnimation 给 0；测试用它对齐正式版的加载等待）
	var flash_color := Color(0, 0, 0, 0)
	var flash_duration := 0
	var flash: Node2D

	func _ready() -> void:
		super._ready()
		duration = anim.frames.size() * rate + 1
		flash = Node2D.new()
		flash.visible = false
		flash.draw.connect(_draw_flash)
		add_child(flash)

	func _physics_process(_delta: float) -> void:
		pass

	func playing() -> bool:
		return duration > 0

	## Sprite_Animation.currentFrameIndex
	func frame_index() -> int:
		return anim.frames.size() - floori(float(duration + rate - 1) / rate)

	## Sprite_Animation.update：updateMain（_delay、_duration−1、updatePosition、换帧与时间点）后 updateScreenFlash
	func advance(icon_pos: Vector2, icon_h: float) -> void:
		if duration > 0:
			if wait > 0:
				wait -= 1
			else:
				duration -= 1
				position = icon_pos
				match int(anim.get("position", 1)):
					0: position.y -= icon_h
					1: position.y -= icon_h / 2.0
					3: position = Vector2.ZERO    # parent.width/2：SpriteEnemyTrP 没有位图，宽高都是 0
				if duration % rate == 0 and duration > 0:
					frame = frame_index()
					_show_frame()
		if flash_duration > 0:
			var d := flash_duration
			flash_duration -= 1
			flash_color.a *= float(d - 1) / d
			flash.visible = flash_duration > 0
			flash.queue_redraw()

	func _show_frame() -> void:
		super._show_frame()
		for t in anim.get("timings", []):
			if int(t.frame) == frame and int(t.get("flashScope", 0)) == 2:
				var c: Array = t.flashColor
				flash_color = Color(c[0] / 255.0, c[1] / 255.0, c[2] / 255.0, c[3] / 255.0)
				flash_duration = int(t.flashDuration) * rate
		var cells: Array = anim.frames[frame]
		for i in range(mini(cells.size(), _sprites.size())):
			var s := _sprites[i]
			if not s.visible:
				continue
			var cell: Array = cells[i]
			var hue := int(anim.get("animation1Hue" if int(cell[0]) < 100 else "animation2Hue", 0))
			var add := cell.size() > 7 and int(cell[7]) == 1
			if hue != 0:
				s.material = XDropPopup.hue_material(hue, add)
			elif add and not s.material is CanvasItemMaterial:
				var m := CanvasItemMaterial.new()      # 上一帧这格可能还是转色相的材质
				m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				s.material = m
		if flash.get_index() != get_child_count() - 1:
			move_child(flash, -1)     # 屏幕闪光在格子之后（盖住本动画的格子）

	## ScreenSprite：(−5W, −5H) 起 10 倍画面大小的纯色矩形，跟着画面原点
	func _draw_flash() -> void:
		var o := -flash.get_global_transform().origin
		var box := XBattleScene.BOX
		flash.draw_rect(Rect2(o - box * 5.0, box * 10.0), flash_color)

	func flash_opacity() -> float:
		return flash_color.a * 255.0


static func hue_material(hue: int, add: bool) -> ShaderMaterial:
	var key := "%d:%s" % [hue, add]
	if not _hue_materials.has(key):
		var mode := "blend_add" if add else "blend_mix"
		if not _hue_shaders.has(mode):
			var sh := Shader.new()
			sh.code = HUE_SHADER % mode
			_hue_shaders[mode] = sh
		var m := ShaderMaterial.new()
		m.shader = _hue_shaders[mode]
		m.set_shader_parameter("hue", float(((hue % 360) + 360) % 360))
		_hue_materials[key] = m
	return _hue_materials[key]


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
				a.target = g
				g.anim = a
		made.append(g)
	icons = made
	_born_icons = made.duplicate()
	_born_nodes = get_children()
	arrange()


## Sprite_Base.startAnimation：建在图标的父节点（本节点）里，紧跟在图标之后
func _start_animation(anim_id: int) -> DhAnimation:
	var data := XDB.rec("Animations", anim_id)
	if data.is_empty():
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
				remove_child(a)
				a.queue_free()
		elif c is DhAnimation and c.get_parent() == self:
			var g: Dictionary = c.target
			c.advance(Vector2(g.x, g.y), ICON * absf(g.sy))
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
