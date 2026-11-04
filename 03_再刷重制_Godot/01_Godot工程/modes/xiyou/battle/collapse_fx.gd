class_name XCollapseFx
extends Node2D
## MOG_CollapseEffects 默认死亡效果 0（粉碎，方向 Left）：敌人倒下时身体碎成方块向左上飘散、逐块淡出。
## 全库没有 Collapse Effect／Collapse Animation 备注，所有敌人都走这一条；参照 mv_oracle/collapse_probe.cjs（oracle/collapse.json）。
## 规则（插件 setupColShatterPoint／updateCollapseShatterPoint）：
##  - 碎块边长 floor((宽+高)/40)；每行 32 列，行起点 y＝−高＋边长，逐行向下加到 y>0 为止：y≤0 的行满 32 列，
##    第一条 y>0 的行只放 1 块（循环在这块之后结束）。块取自位图 (列×边长, 行×边长) 的方块，超出位图的不画。
##  - 每块随机 sx∈[1,1.5)、op∈[2.5,4.5)；每帧 x −= sx（Left；Right 则 +=）、y −= sx、不透明度 −= op；全部 ≤0 时结束。
##  - 全部透明最久 ceil(255/2.5)＝102 帧内结束；碎块挂在身体上，随身体缩放／镜像（敌人整体镜像时向右上飘）。
## 随机只用自己的生成器，不动战斗规则的全局随机数。

signal finished

const COLUMNS := 32
const LIMIT := 2000

## 总帧数（最大 ceil(255/op)），用来给 WAIT FOR EFFECT 的 effect_left
var frames := 0
var _frags: Array = []   # {sp: Sprite2D, sx: float, op: float, a: float}
var _dir := -1.0         # Left＝−1，Right＝＋1
var _acc := 0.0
var _done := false


## 插件参数「粉碎方向」（正式版 plugins.js：Left）
static func shatter_left() -> bool:
	return str(XDB.plugin("MOG_CollapseEffects").get("粉碎方向", "Left")) != "Right"


## 纯规则：碎块网格。返回 [{col, row, x, y}]（x、y＝取图左上角像素；px、py＝插件里的碎块坐标，已含起点），不含随机。
static func grid(w: int, h: int) -> Array:
	var out := []
	var frag := floori((h + w) / 40.0)
	if frag <= 0:
		return out
	var xi := floori(-w / 2.0) + floori(frag / 2.0)
	var yi := floori(-h + float(frag))
	var i := 0
	while i < LIMIT:
		var x := (i % COLUMNS) * frag
		var y := floori(i / float(COLUMNS)) * frag
		var py := yi + y
		out.append({"x": x, "y": y, "px": xi + x, "py": py})
		if py > 0:
			break
		i += 1
	return out


## 在 host（战斗者节点）里建一个粉碎效果；body 是身体 Sprite2D（取图、材质、缩放、镜像照它）。图不可用时返回 null。
static func start(host: Node2D, body: Sprite2D, rng: RandomNumberGenerator, left := true) -> XCollapseFx:
	var tex := body.texture
	if tex == null:
		return null
	var w := int(body.region_rect.size.x) if body.region_enabled else tex.get_width()
	var h := int(body.region_rect.size.y) if body.region_enabled else tex.get_height()
	var fx := XCollapseFx.new()
	fx._dir = -1.0 if left else 1.0
	fx.position = body.position
	fx.scale = Vector2(body.scale.x * (-1.0 if body.flip_h else 1.0), body.scale.y)
	var frag := floori((h + w) / 40.0)
	var tw := tex.get_width()
	var th := tex.get_height()
	for g in grid(w, h):
		if g.x >= tw or g.y >= th or g.x >= w or g.y >= h:
			continue
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.region_enabled = true
		sp.region_rect = Rect2(g.x, g.y, mini(frag, tw - g.x), mini(frag, th - g.y))
		sp.offset = Vector2(-frag / 2.0, -frag)   # 锚点 (0.5, 1)
		sp.position = Vector2(g.px, g.py)
		sp.material = body.material
		fx.add_child(sp)
		var op := rng.randf() * 2.0 + 2.5
		fx._frags.append({"sp": sp, "sx": rng.randf() * 0.5 + 1.0, "op": op, "a": 255.0})
		fx.frames = maxi(fx.frames, ceili(255.0 / op))
	host.add_child(fx)
	return fx


## 插件每帧的一步
func step() -> void:
	if _done:
		return
	var alive := false
	for f in _frags:
		var sp: Sprite2D = f.sp
		sp.position.x += _dir * f.sx
		sp.position.y -= f.sx
		f.a = maxf(0.0, f.a - f.op)
		sp.modulate.a = f.a / 255.0
		if f.a > 0.0:
			alive = true
	if not alive:
		_done = true
		finished.emit()
		queue_free()


func _process(delta: float) -> void:
	_acc += delta * 60.0
	while _acc >= 1.0 and not _done:
		_acc -= 1.0
		step()


func is_done() -> bool:
	return _done


## 立刻收掉（复活／重新出现时）
func clear() -> void:
	_done = true
	queue_free()
