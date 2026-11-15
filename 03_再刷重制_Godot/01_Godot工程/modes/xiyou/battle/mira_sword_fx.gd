class_name XMiraSwordFx
extends Node2D
## 米拉黑龙头顶召剑特效（独立层，不嵌进龙体贴图；co 出 Sword_FX_u2，Kyo 11-15 通过，素材在 content/mira/fx/sword_u2/）。
## - 无剑龙体（XMira.DRAGON_ART）下，原版 UserSV_MiraDragon 带剑图里的剑改由这一层按需召出：出现 3 帧（每帧 100ms）→ 悬停 3 帧
##   （140ms 循环）→ 消散 3 帧＋clear（每帧 100ms）→ 隐藏。
## - 摆位：特效 128×128、中心锚点 [64,64]，相对龙图底锚 [160,217] 偏移 [-40,-200]（OFFSET）；层挂在 XBattlerSprite 下（原点＝脚底），
##   位置与缩放都乘身体缩放（sprite.body_scale），所以与龙体的相对关系不随归一缩放变。
## - 技能名单（Kyo 11-15 定，D34）：只有 10151 黑日焚界召剑，平时不挂剑；on_skill 只在技能号在 SKILLS 里时才出现，
##   行动结束 vanish_all 让已出现的剑消散。
## - 开关：XMira.DRAGON_ART（false＝回原版带剑龙图，也不再建这一层）。

const DIR := "res://content/mira/fx/sword_u2/"
const OFFSET := Vector2(-40, -200)
const APPEAR := ["appear_0", "appear_1", "appear_2"]
const HOVER := ["hover_0", "hover_1", "hover_2"]
const DISAPPEAR := ["disappear_0", "disappear_1", "disappear_2", "clear"]
const APPEAR_MS := 100
const HOVER_MS := 140
const DISAPPEAR_MS := 100
## 触发召剑的技能号（Kyo 11-15 定：只有 10151 黑日焚界）
static var SKILLS: Array = [10151]

var state := "hidden"  # hidden／appear／hover／disappear
var _t := 0.0  # 当前段已过毫秒
var _spr: Sprite2D
static var _tex_cache := {}


static func wants(skill_id: int) -> bool:
	return XMira.DRAGON_ART and SKILLS.has(skill_id)


## 这个战斗者精灵现在是不是无剑黑龙
static func dragon_sprite(sp: XBattlerSprite) -> bool:
	return XMira.DRAGON_ART and sp != null and sp.battler is XActor and XMira.own(sp.battler) and str(sp._look_key).contains("|form:MiraDragon")


static func layer_of(sp: XBattlerSprite) -> XMiraSwordFx:
	return sp.get_node_or_null("MiraSwordFx") as XMiraSwordFx


## 取（没有就建）这个精灵的召剑层
static func ensure_layer(sp: XBattlerSprite) -> XMiraSwordFx:
	var l := layer_of(sp)
	if l == null:
		l = XMiraSwordFx.new()
		l.name = "MiraSwordFx"
		sp.add_child(l)
	return l


## 行动开始（battle_scene._perform_action）：技能在 SKILLS 里且是无剑黑龙才召剑
static func on_skill(sp: XBattlerSprite, skill_id: int) -> void:
	if wants(skill_id) and dragon_sprite(sp):
		ensure_layer(sp).appear()


## 行动结束：所有已出现的剑消散
static func vanish_all(sprites: Array) -> void:
	for sp in sprites:
		var l := layer_of(sp)
		if l != null:
			l.vanish()


static func _tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		var p := DIR + name + ".png"
		_tex_cache[name] = XAppearance.kept_load(p) if ResourceLoader.exists(p) else null
	return _tex_cache[name]


func _init() -> void:
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr = Sprite2D.new()
	_spr.centered = true
	_spr.visible = false
	add_child(_spr)


func appear() -> void:
	if state == "appear" or state == "hover":
		return
	state = "appear"
	_t = 0.0
	_show()


func vanish() -> void:
	if state == "hidden" or state == "disappear":
		return
	state = "disappear"
	_t = 0.0
	_show()


## 此刻该画哪张（段名、已过毫秒）；hidden 返回空串
static func frame_name(st: String, ms: float) -> String:
	match st:
		"appear":
			return APPEAR[mini(int(ms / APPEAR_MS), APPEAR.size() - 1)]
		"hover":
			return HOVER[int(ms / HOVER_MS) % HOVER.size()]
		"disappear":
			return DISAPPEAR[mini(int(ms / DISAPPEAR_MS), DISAPPEAR.size() - 1)]
	return ""


## 层中心相对精灵原点（脚底）的位置：OFFSET × 身体缩放
static func center_for(body_scale: float) -> Vector2:
	return OFFSET * body_scale


func advance(delta_ms: float) -> void:
	_t += delta_ms
	if state == "appear" and _t >= APPEAR_MS * APPEAR.size():
		state = "hover"
		_t -= APPEAR_MS * APPEAR.size()
	elif state == "disappear" and _t >= DISAPPEAR_MS * DISAPPEAR.size():
		state = "hidden"
	_show()


func _process(delta: float) -> void:
	if state != "hidden":
		advance(delta * 1000.0)


func _show() -> void:
	var sp := get_parent() as XBattlerSprite
	var n := frame_name(state, _t)
	_spr.visible = n != "" and n != "clear"
	if n == "":
		return
	var s := maxf(sp.body_scale if sp != null else 1.0, 0.0001)
	position = center_for(s)
	scale = Vector2(s, s)
	_spr.texture = _tex(n)
	# 缩小时平滑采样（与龙体归一缩小一致），放大或原尺寸最近邻
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if s < 1.0 else CanvasItem.TEXTURE_FILTER_NEAREST
