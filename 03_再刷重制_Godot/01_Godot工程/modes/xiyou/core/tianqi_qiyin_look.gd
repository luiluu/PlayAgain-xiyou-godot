class_name XTianqiQiyinLook
extends RefCounted
## 【cc·天启篇·未经审查】七印外观：头像框（美术 P7）和战斗法阵（P8）（七印祭坛方案 v0.4 第 6.5 节第 6 条，Kyo 11-11 23:47「战斗中再给个特效」）。
##
## - 解锁：一印的套装六件都揭到过，就解锁这一印的外观，跨存档保留（配置 codexTianqiQiyinParts 记「印:部位」，同骑士徽记的做法）。
##   印库揭开时记（XTianqiQiyin.reveal）；开祭坛时把本档印库里已经揭开的补记一遍（这个功能之前揭的也算）。
## - 佩戴：祭坛菜单「外观」给出战的人挑一印（或不戴），记在本档（七印进度 looks {角色号: 印}）。不影响数值。
## - 头像框：主菜单这一行的头像缩进框里的窗口（x34 y38 宽高 60，128 格），框盖在上面（XMenu._paint_status）。
## - 战斗法阵：戴着的角色脚下一圈本印法阵（俯视正圆压成椭圆）。开场亮起转一圈，之后常驻一圈淡光、慢慢转、呼吸闪烁，
##   飘几颗本印颜色的光点；倒下时熄掉（XBattlerSprite._process 调 update_sprite）。
## - 七套都解锁：七印的称号还没有称号系统接，先不做（交付单）。
##
## 回退开关 ENABLED（O-待定）：false＝不解锁、菜单不出、头像不加框、战斗不画法阵（已经记下的解锁和佩戴留着）。

static var ENABLED := true

const DIR := "res://content/tianqi/qiyin/"
## 头像框里放头像的窗口（美术 P7 说明：128 格里 x34 y38 宽高 60）
const WINDOW := Rect2(34, 38, 60, 60)
const FRAME_CELL := 128.0
## 法阵：脚下宽多少逻辑像素、压扁比例（美术预览 42%）、开场转一圈多久、常驻亮度
const CIRCLE_W := 112.0
const CIRCLE_FLAT := 0.42
const OPEN_SEC := 1.0
const IDLE_ALPHA := 0.55
const SPIN_SEC := 12.0
const NODE := "qiyin_circle"

## 刚解锁的（run_reveal 说完揭开的话之后取走报一句）
static var _new: Array = []
static var _tex := {}


static func _seals() -> Array:
	return XTianqiQiyinArt.SEALS


static func on(s: XState = null) -> bool:
	return ENABLED and XTianqiQiyin.allowed(s if s != null else XState.current)


# ---- 解锁（跨存档） ----

## 揭到一件：套装件记「印:部位」，凑齐六件的那一印进 _new
static func note(item: Dictionary) -> void:
	if not ENABLED or str(item.get("kind", "")) != "set":
		return
	var seal := str(item.get("seal", ""))
	var part := str(item.get("part", ""))
	if not _seals().has(seal) or not XTianqiQiyinArt.PARTS.has(part):
		return
	var had := unlocked(seal)
	XConfig.tianqi_qiyin_part_mark("%s:%s" % [seal, part])
	if not had and unlocked(seal) and not _new.has(seal):
		_new.append(seal)


## 开祭坛时补记本档印库里已经揭开的（功能上线前揭的）
static func catch_up(s: XState) -> void:
	if not on(s):
		return
	for it in XTianqiQiyin.progress(s).bag:
		if bool(it.get("revealed", false)):
			note(it)


static func take_new() -> Array:
	var out := _new
	_new = []
	return out


static func parts_of(seal: String) -> Array:
	return XConfig.tianqi_qiyin_parts().filter(func(k): return str(k).begins_with(seal + ":")).map(func(k): return str(k).get_slice(":", 1))


static func unlocked(seal: String) -> bool:
	var got := parts_of(seal)
	return XTianqiQiyinArt.PARTS.all(func(p): return got.has(p))


static func unlocked_list() -> Array:
	return _seals().filter(func(k): return unlocked(str(k)))


# ---- 佩戴（本档） ----

static func _looks(s: XState) -> Dictionary:
	var p := XTianqiQiyin.progress(s)
	if not p.get("looks") is Dictionary:
		p["looks"] = {}
	return p.looks


## 这个角色戴着哪一印（没戴、开关关、不是天启篇、那印没解锁＝""）
static func worn(a, s: XState = null) -> String:
	if a == null or not a is XActor:
		return ""
	s = s if s != null else XState.current
	if s == null or not on(s):
		return ""
	var k := str(_looks(s).get(str((a as XActor).actor_id), ""))
	return k if unlocked(k) else ""


static func wear(s: XState, actor_id: int, seal: String) -> bool:
	if not on(s):
		return false
	if seal == "":
		_looks(s).erase(str(actor_id))
		return true
	if not unlocked(seal):
		return false
	_looks(s)[str(actor_id)] = seal
	return true


## 祭坛菜单项（有解锁的才出）
static func altar_options(s: XState) -> Array:
	if not on(s) or unlocked_list().is_empty():
		return []
	return [{"id": "look", "label": "外观（七印头像框）"}]


static func seal_name(seal: String) -> String:
	return str(XTianqiQiyin.seal_info(seal).get("seal", seal))


static func run(host, s: XState) -> void:
	var members: Array = s.battle_members()
	if members.is_empty():
		return
	while true:
		var labels: Array = members.map(func(a):
			var w := worn(a, s)
			return "%s　%s" % [a.display_name(), "（%s）" % seal_name(w) if w != "" else "（不戴）"])
		labels.append("返回")
		var i: int = await XTianqiQiyin.ask(host, "look_actor", labels, [unlocked_list().size()])
		if i < 0 or i >= members.size():
			return
		var list := unlocked_list()
		var opts: Array = list.map(func(k): return "\\I[%d]%s" % [XTianqiQiyinArt.set_icon(str(k), "head"), seal_name(str(k))])
		opts.append("不戴")
		opts.append("返回")
		var c: int = await XTianqiQiyin.ask(host, "look_seal", opts, [members[i].display_name()])
		if c < 0 or c == opts.size() - 1:
			continue
		var pick := str(list[c]) if c < list.size() else ""
		wear(s, int(members[i].actor_id), pick)
		await XTianqiQiyin.say(host, "look_done", [members[i].display_name(), seal_name(pick) if pick != "" else "不戴"])


# ---- 头像框 ----

static func _load(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func frame_texture(seal: String) -> Texture2D:
	return _load(DIR + "frames/%s.png" % seal)


static func circle_texture(seal: String) -> Texture2D:
	return _load(DIR + "circles/%s.png" % seal)


## 主菜单这一格（x, y, w, h 是原来画头像的格子）：戴着框就把头像缩进框的窗口、框盖上，返回 true；没戴返回 false（照原样画）
static func paint_face(c, a, x: float, y: float, w: float, h: float, alpha := 1.0) -> bool:
	var seal := worn(a)
	var frame := frame_texture(seal) if seal != "" else null
	if frame == null:
		return false
	var side := minf(minf(w, h), 144.0)
	var k := side / FRAME_CELL
	var origin := Vector2(floorf(x + (w - side) / 2.0), floorf(y + (h - side) / 2.0))
	var win := Rect2(origin + WINDOW.position * k, WINDOW.size * k)
	var data: Dictionary = (a as XActor).data()
	var fkey := "face:%s:%d" % [str(data.get("faceName", "")), int(data.get("faceIndex", 0))]
	if not _tex.has(fkey):  # 留着：_draw 里现取的贴图画完就被释放，画成白块
		_tex[fkey] = XUI.face_texture(str(data.get("faceName", "")), int(data.get("faceIndex", 0)))
	var face: Texture2D = _tex[fkey]
	if face != null:
		c.draw_texture_rect(face, win, false, Color(1, 1, 1, alpha))
	c.draw_texture_rect(frame, Rect2(origin, Vector2(side, side)), false, Color(1, 1, 1, alpha))
	return true


# ---- 战斗法阵 ----

## XBattlerSprite._process（角色）：戴着外观的脚下挂一圈法阵；开场亮起转一圈，之后常驻淡光；倒下熄掉
static func update_sprite(sp) -> void:
	var a = sp.battler
	var seal := worn(a)
	var node: Node2D = sp.get_node_or_null(NODE)
	if seal == "":
		if node != null:
			node.queue_free()
		return
	if node == null or str(node.get_meta("seal", "")) != seal:
		if node != null:
			node.free()
		node = _make_circle(seal)
		if node == null:
			return
		sp.add_child(node)
		sp.move_child(node, 0)  # 压在影子、身体下面
	var dead: bool = sp.view.dead if not sp.view.is_empty() else a.is_dead()
	var t := float(Time.get_ticks_msec() - int(node.get_meta("born", 0))) / 1000.0
	var ring := node.get_node("ring") as Sprite2D
	var open := clampf(t / OPEN_SEC, 0.0, 1.0)
	ring.rotation = open * TAU + maxf(0.0, t - OPEN_SEC) * TAU / SPIN_SEC
	var glow := 1.0 - open * (1.0 - IDLE_ALPHA) if open < 1.0 else IDLE_ALPHA * (0.8 + 0.2 * sin(t * 2.0))
	node.modulate.a = 0.0 if dead else glow
	var dots := node.get_node_or_null("dots") as CPUParticles2D
	if dots != null:
		dots.emitting = not dead


static func _make_circle(seal: String) -> Node2D:
	var tex := circle_texture(seal)
	if tex == null:
		return null
	var root := Node2D.new()
	root.name = NODE
	root.set_meta("seal", seal)
	root.set_meta("born", Time.get_ticks_msec())
	root.scale = Vector2(1.0, CIRCLE_FLAT)  # 俯视正圆压成椭圆：转起来也贴着地
	var ring := Sprite2D.new()
	ring.name = "ring"
	ring.texture = tex
	ring.scale = Vector2.ONE * (CIRCLE_W / tex.get_width())
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD  # 发光法阵（美术用纯黑底出图）
	ring.material = mat
	root.add_child(ring)
	var dots := CPUParticles2D.new()
	dots.name = "dots"
	dots.amount = 10
	dots.lifetime = 1.6
	dots.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dots.emission_rect_extents = Vector2(CIRCLE_W * 0.4, 6.0)
	dots.direction = Vector2(0, -1)
	dots.spread = 10.0
	dots.gravity = Vector2.ZERO
	dots.initial_velocity_min = 30.0
	dots.initial_velocity_max = 60.0
	dots.scale_amount_min = 1.5
	dots.scale_amount_max = 3.0
	dots.color = Color(XTianqiQiyinShow.seal_accent(seal), 0.9)
	dots.scale = Vector2(1.0, 1.0 / CIRCLE_FLAT)  # 光点不跟着压扁
	dots.material = mat
	root.add_child(dots)
	return root
