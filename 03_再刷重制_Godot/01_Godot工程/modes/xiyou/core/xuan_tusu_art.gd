class_name XXuanTusuArt
extends RefCounted
## 【cc·悟空·未经审查】璇与屠苏的美术（Codex_XuanTusuArtPack、Codex_XuanTusuExtraArt）：只管画面，不碰结算。
## - 身体：Codex_Xuan_SV_v1／Codex_Tusu_SV_v1 用逐帧图 Codex_Xuan_v1／Codex_Tusu_v1（18 个动作，待机 1 帧，其余 3 帧）。
## - 绑定中：璇的身体藏起（透明形态）；屠苏变成手里那件武具的悬浮形态，站到宿主脚下（y＋1）。
## - 宿主身后的星魂（projectionFor）：璇的宿主 primary；列星受益者 shadow 淡色。循环 6 帧，放回光、璃壁、棱光、列星时 3 帧施法。
## - 持武（updateWeapon）：屠苏附在谁身上，谁的身体旁边画那件武具，放对应动作时换帧、剑和锤转角度；藏原武器。
## - 图标：转换器按备注把 iconIndex 换成 240000＋、240100＋（applyDatabase），这里从 128 的 HD 图集切；未竟环按开刃数换图。
## 画面状态都写在 battler_key 里（|art:形态、|xt:primary／shadow、|held:武具），和显示中的读数同步，不抢在演出之前。
## 参照 mv_oracle/xuan_tusu_art_probe.cjs，专项 tests/xiyou_xuan_tusu_art。

const TUSU_ICON := 240000
const XUAN_ICON := 240100
const TUSU_COUNT := 30
const XUAN_COUNT := 26
const TUSU_RELIC_SLOT := 26
const CELL := 128
const SHEETS := {"Codex_Xuan_SV_v1": ["Codex_Xuan_v1", "true"], "Codex_Tusu_SV_v1": ["Codex_Tusu_v1", "false"]}
const XUAN := 177
const TRANSPARENT := "Codex_Bound_Transparent_v1"

## HELD：pivot、displayHeight、bounds 的高、换帧的动作（MOTIONS 序号）；x、y 是可见身体框比例；scale 是 heldScales；angle 是平时角度
const HELD := {
	"sword": {"pivot": Vector2(64, 96), "height": 52.0, "bh": 109.0, "motions": [6, 7, 9], "x": 0.12, "y": 0.64, "scale": 1.2, "angle": -0.35},
	"bow": {"pivot": Vector2(64, 64), "height": 46.0, "bh": 104.0, "motions": [8, 9], "x": 0.08, "y": 0.64, "scale": 1.0, "angle": 0.0},
	"shield": {"pivot": Vector2(64, 64), "height": 42.0, "bh": 102.0, "motions": [3, 9], "x": 0.08, "y": 0.64, "scale": 1.0, "angle": 0.0},
	"book": {"pivot": Vector2(64, 87), "height": 32.0, "bh": 74.0, "motions": [2, 9, 10], "x": 0.45, "y": 0.76, "scale": 0.9, "angle": 0.0},
	"hammer": {"pivot": Vector2(64, 69), "height": 54.0, "bh": 101.0, "motions": [7, 9], "x": 0.10, "y": 0.64, "scale": 1.1, "angle": -0.20},
}
## POSSESSION
const P_FRAME := 160.0
const P_HEAD := Vector2(80, 20)
const P_IDLE_FRAMES := 6
const P_IDLE_SPEED := 12
const P_CAST_FRAMES := 3
const P_CAST_SPEED := 8
const P_HEIGHT := 64.0
const P_REFERENCE := 92.0
const P_OFFSET := Vector2(22, -22)
const P_OPACITY := {"primary": 208.0, "shadow": 94.0}
const P_FADE := 28.0
const CAST_KEYS := ["huiguang", "libi", "lengguang", "liexing"]
const HELD_SHADER := """
shader_type canvas_item;
uniform vec2 rim = vec2(0.008);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			a = max(a, texture(TEXTURE, UV + vec2(float(x), float(y)) * rim).a);
		}
	}
	vec3 rgb = c.rgb * 1.3;
	rgb = (rgb - 0.5) * 1.15 + 0.5;
	float l = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	rgb = mix(vec3(l), rgb, 1.1);
	vec4 edge = vec4(226.0 / 255.0, 234.0 / 255.0, 252.0 / 255.0, a * 0.85);
	COLOR = mix(edge, vec4(rgb, 1.0), c.a) * vec4(1.0, 1.0, 1.0, max(c.a, edge.a));
	COLOR.a = max(c.a, edge.a);
}
"""
## 动作（performAction 包装）：技能键 → 动作
const BODY_MOTIONS := {"body.phys": "swing", "body.mag": "spell", "body.guard": "guard", "return": "wait"}
const ARM_MOTIONS := {"arm.zhanfeng": "swing", "arm.hengsao": "swing", "arm.dianshe": "missile", "arm.guanri": "missile",
	"arm.huzhen": "guard", "arm.chiling": "spell", "arm.zhenji": "swing"}
const XUAN_MOTIONS := {"jixing.possess": "spell", "jixing": "spell", "huiguang": "spell", "libi": "spell", "lengguang": "spell",
	"liexing": "skill", "gongsu": "skill", "return": "wait"}

static var _icons := {}
static var _atlases := {}
static var _cast_ticks := {}
static var _held_shader: Shader


static func _own(a) -> String:
	if not a is XActor:
		return ""
	return "Tusu" if int(a.actor_id) == XTusu.ACTOR else ("Xuan" if int(a.actor_id) == XUAN else "")


static func _bound(a) -> bool:
	return XBinding.in_battle() and XBinding.is_bound(a)


## Mx.SuperSVMetaProvider 里那层的形态：绑定中屠苏的武具（boundMode 只有 visible）、璇透明
static func form_name(a) -> String:
	var k := _own(a)
	if k == "" or not _bound(a):
		return ""
	if k == "Xuan":
		return TRANSPARENT
	var w = XTusu.weapon(a)
	return "Codex_Tusu_%s_v1" % (w if w != null and HELD.has(w) else "sword")


## A.projectionFor：璇活着且附身在 target 上 primary；列星受益者（列星没到期）shadow；target 自己绑定着没有
static func projection_for(target) -> String:
	if not target is XActor or not XBinding.in_battle() or not target.is_alive() or _bound(target):
		return ""
	var x = XXuanBattle.xuan()
	if x == null or not x.is_alive():
		return ""
	if _bound(x) and is_same(XBinding.host(x), target):
		return "primary"
	var d: Dictionary = XXuanBattle.data
	if not d.is_empty() and int(d.get("liexingUntil", -1)) >= XBinding.current_round() and (d.get("shadows", []) as Array).has(int(target.actor_id)):
		return "shadow"
	return ""


## battler_key 的尾巴（卡图生效时不走到这）
static func key_parts(a) -> String:
	if not XBinding.in_battle():
		return ""
	var out := ""
	var f := form_name(a)
	if f != "":
		out += "|art:" + f
	var p := projection_for(a)
	if p != "":
		out += "|xt:" + p
	var h = XTusu.weapon_of_host(a)
	if a.is_alive() and h != null and HELD.has(h):
		out += "|held:" + str(h)
	return out


## ArtPack 的逐帧图标签，绑定形态盖在上面（已有状态换图等显式 sv 优先：base.sv 不同就不动）
static func meta(name: String, base: Dictionary, art: String) -> Dictionary:
	var rec = SHEETS.get(name)
	if rec == null or (str(base.get("sv", "")) != "" and str(base.get("sv", "")) != rec[0]):
		return base
	var out := base.duplicate()
	for i in range(18):
		out.erase("Cfdz%d" % i)
		out["SVzs%d" % i] = "1" if art == TRANSPARENT or (art == "" and i == 1) else "3"
	out.sv = art if art != "" else rec[0]
	out.SVspeed = "14" if art != "" else "12"
	out.YCyy = "true" if art != "" else rec[1]
	return out


## ArtPack ownBody：自身图（没开卡图时 refreshMotion 把走路改待机；绑定形态照循环）
static func planted(a, look_key: String) -> bool:
	return _own(a) != "" and not look_key.contains("|card") and not look_key.contains("|art:")


## performAction 包装的动作（屠苏键看是不是持武，别的只对自身图）；空＝不改
static func motion_for(a: XActor, skill: Dictionary) -> String:
	if a.is_attack(skill) and _own(a) != "" and not XCostumes.active(XState.current, a):  # performAttack 包装
		return "swing" if _own(a) == "Tusu" else "missile"
	var id := int(skill.get("id", 0))
	var tk := str(XTusuXuan.keys(XTusu.ACTOR).get(id, ""))
	var xk := str(XTusuXuan.keys(XUAN).get(id, ""))
	if tk != "" and ARM_MOTIONS.has(tk) and XTusu.weapon_of_host(a) != null:
		return ARM_MOTIONS[tk]
	if _own(a) == "":
		return ""
	if tk != "":
		return BODY_MOTIONS.get(tk, "skill" if tk.begins_with("huawu.") or tk.begins_with("yiwu.") else "")
	return XUAN_MOTIONS.get(xk, "")


## A.noteXuanCast：璇放回光、璃壁、棱光、列星时星魂切施法帧
static func note_cast(owner, skill: Dictionary) -> void:
	if _own(owner) == "Xuan" and str(XTusuXuan.keys(XUAN).get(int(skill.get("id", 0)), "")) in CAST_KEYS:
		_cast_ticks[int(owner.actor_id)] = Engine.get_physics_frames()


static func clear_casts() -> void:
	_cast_ticks.clear()


# ---- 图标 ----
static func icon_slot(index: int) -> Array:
	if index >= TUSU_ICON and index < TUSU_ICON + TUSU_COUNT:
		var slot := index - TUSU_ICON
		return ["Tusu_Icons_HD", slot + relic_stage(XTusu.kairen().size()) if slot == TUSU_RELIC_SLOT else slot]
	if index >= XUAN_ICON and index < XUAN_ICON + XUAN_COUNT:
		return ["Xuan_Icons_HD", index - XUAN_ICON]
	return []


static func relic_stage(n: int) -> int:
	return 0 if n <= 0 else (1 if n <= 2 else (2 if n <= 4 else 3))


## 按 size 平滑缩好的图标（同 XYunshang.icon_texture）
static func icon_texture(index: int, size := 32) -> AtlasTexture:
	var slot := icon_slot(index)
	if slot.is_empty():
		return null
	var key := "%s:%d:%d" % [slot[0], slot[1], size]
	if not _icons.has(key):
		if not _atlases.has(slot[0]):
			var p := XDB.img_path("system", str(slot[0]))
			if p == "":
				return null
			var src: Image = (load(p) as Texture2D).get_image()
			if src.is_compressed():
				src.decompress()
			src.convert(Image.FORMAT_RGBA8)
			_atlases[slot[0]] = src
		var part: Image = (_atlases[slot[0]] as Image).get_region(Rect2i(int(slot[1]) * CELL, 0, CELL, CELL))
		if size != CELL:
			part.resize(size, size, Image.INTERPOLATE_LANCZOS)
		var a := AtlasTexture.new()
		a.atlas = ImageTexture.create_from_image(part)
		a.region = Rect2(0, 0, size, size)
		_icons[key] = a
	return _icons[key]


# ---- 战斗画面（Sprite_Actor.update 包装）----
static func _part(key: String, tag: String) -> String:
	for p in key.split("|"):
		if p.begins_with(tag):
			return p.substr(tag.length())
	return ""


## A.bodyRect：可见身体框（精灵本地坐标，脚底为原点）
static func body_rect(s) -> Rect2:
	if not s._profile.is_empty():
		var b: Rect2 = s._profile.bounds
		var k := float(s._profile.scale)
		return Rect2(-b.size.x * k / 2.0, -b.size.y * k, b.size.x * k, b.size.y * k)
	var h: float = s.height()
	return Rect2(-h / 3.0, -h, h * 2.0 / 3.0, h)


static func update(s) -> void:
	if not s.battler is XActor:
		return
	var key: String = s._look_key
	_update_bound(s, _part(key, "art:"))
	_update_held(s, _part(key, "held:"))
	_update_projection(s, _part(key, "xt:"))


static func _update_bound(s, art: String) -> void:
	if art == "":
		if s.has_meta("xt_hidden"):
			s.remove_meta("xt_hidden")
			s.sprite.visible = true
		if s.has_meta("xt_attached"):
			s.remove_meta("xt_attached")
			s.position = s.home
		return
	if art == TRANSPARENT:
		s.sprite.visible = false
		s.set_meta("xt_hidden", true)
	elif s.has_meta("xt_hidden"):
		s.remove_meta("xt_hidden")
		s.sprite.visible = true
	if _own(s.battler) == "Tusu":  # A.attach：屠苏站到宿主脚下；璇的星魂画在宿主身后，自己留在原位藏着
		var hs = _host_sprite(s)
		if hs != null:
			s.position = hs.position + Vector2(0, 1)
			s.set_meta("xt_attached", true)


static func _host_sprite(s):
	var host = XBinding.host(s.battler)
	for x in s.get_parent().get_children():
		if x != s and x.get("battler") != null and is_same(x.battler, host):
			return x
	return null


static func _update_held(s, w: String) -> void:
	var held = s.get_meta("xt_held") if s.has_meta("xt_held") else null
	if w == "" or not HELD.has(w) or s.battler.is_dead():
		if held != null:
			held.visible = false
		if s.has_meta("xt_weapon") and s.weapon != null:
			s.weapon.visible = bool(s.get_meta("xt_weapon"))
			s.remove_meta("xt_weapon")
		return
	if held == null:
		held = Sprite2D.new()
		held.centered = false
		held.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if _held_shader == null:
			_held_shader = Shader.new()
			_held_shader.code = HELD_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = _held_shader
		held.material = mat
		s.add_child(held)
		s.move_child(held, s.sprite.get_index() + 1)
		s.set_meta("xt_held", held)
	var c: Dictionary = HELD[w]
	var m: int = XAppearance.MOTIONS.find(s.motion)
	var f: int = mini(2, int(s._frame))
	var moving: bool = (c.motions as Array).has(m)
	var p := XDB.img_path("tusu_weapons", "%s_%d" % [w, f if moving else 0])
	if p == "":
		held.visible = false
		return
	held.texture = load(p)
	var body := body_rect(s)
	var scale: float = float(c.height) / float(c.bh) * clampf(absf(body.size.y) / 72.0, 0.4, 1.6) * float(c.scale)
	held.offset = -(c.pivot as Vector2)
	held.scale = Vector2(scale, scale)
	held.position = body.position + Vector2(body.size.x * float(c.x), body.size.y * float(c.y))
	(held.material as ShaderMaterial).set_shader_parameter("rim", Vector2.ONE / (float(CELL) * scale))
	var angle: float = c.angle
	if moving and (w == "sword" or w == "hammer"):  # 出招时转起来；刺（6）另外往回收
		angle = -PI / 2.0 if m == 6 else [0.4, -1.2, -2.2][f]
		if m == 6:
			held.position.x -= [0.0, 8.0, 12.0][f]
	held.rotation = angle
	held.visible = true
	if s.weapon != null:
		if not s.has_meta("xt_weapon"):
			s.set_meta("xt_weapon", s.weapon.visible)
		s.weapon.visible = false


static func _update_projection(s, role: String) -> void:
	var spr = s.get_meta("xt_proj") if s.has_meta("xt_proj") else null
	if role == "":
		if spr != null:
			spr.modulate.a = maxf(0.0, spr.modulate.a - P_FADE / 255.0)
			spr.visible = spr.modulate.a > 0.0
		return
	if spr == null:
		spr = Sprite2D.new()
		spr.centered = false
		spr.offset = -P_HEAD
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		spr.modulate.a = 0.0
		s.add_child(spr)
		s.move_child(spr, s.sprite.get_index())
		s.set_meta("xt_proj", spr)
	var x = XXuanBattle.xuan()
	var t := Engine.get_physics_frames()
	var started = _cast_ticks.get(int(x.actor_id) if x != null else 0)
	var elapsed: int = -1 if started == null else int(t - started)
	var cast := elapsed >= 0 and elapsed < P_CAST_FRAMES * P_CAST_SPEED
	var frame := floori(elapsed / float(P_CAST_SPEED)) if cast else floori(t / float(P_IDLE_SPEED)) % P_IDLE_FRAMES
	var p := XDB.img_path("xuan_possession", "XuanPossession_%s_%d" % ["cast" if cast else "idle", frame])
	if p == "":
		spr.visible = false
		return
	spr.texture = load(p)
	var body := body_rect(s)
	var ratio := clampf(absf(body.size.y) / 72.0, 0.4, 1.6)
	var facing := -1.0 if s.sprite is Sprite2D and s.sprite.flip_h else 1.0
	var scale := P_HEIGHT / P_REFERENCE * ratio
	spr.scale = Vector2(scale * facing, scale)
	spr.position = Vector2(body.get_center().x + P_OFFSET.x * ratio * facing, body.position.y + P_OFFSET.y * ratio)
	var want: float = float(P_OPACITY[role]) / 255.0
	spr.modulate.a += clampf(want - spr.modulate.a, -P_FADE / 255.0, P_FADE / 255.0)
	spr.visible = spr.modulate.a > 0.0
