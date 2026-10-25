class_name XBattlerSprite
extends Node2D
## 战斗者图像。取图格式由 XAppearance 决定（默认照正式版：角色 MV 侧视图 9×6／Mx_SuperSV 逐帧，
## 敌人 sv_enemies 单图或 <Sideview Battler: 名> 指定的侧视图；appearances.json 可换成任意格子、逐帧或 Godot 场景）。
## 本节点只按动作名与帧号播放。像素图放大时用最近邻采样保持清晰。

const LOOP := XAppearance.LOOP
## 正式版运行时读数：Sprite_Actor.motionSpeed 6 帧一格，Sprite_Weapon.animationWait 3 帧一格
const MOTION_SPEED := 6
const WEAPON_WAIT := 3

var battler: XBattler
## 演出中的读数（XBattleScene.show_views 设、clear_views 清）；空时读实时状态
var view := {}
var look: XAppearance
var _look_key := ""   # 角色外观键（XAppearance.battler_key）：换装卡换图时变
## 身体：格子/逐帧/单图时是 Sprite2D，场景外观时是场景根节点
var sprite: Node2D
var shadow: Sprite2D
var cursor: Sprite2D
## MV Sprite_Weapon：武器挥动图，挂在角色下（不随身体缩放），(−16, 0) 底边居中
var weapon: Sprite2D
var _weapon_id := 0
var _weapon_pattern := 0
var _weapon_count := 0
var selected := false
var _selection_frame := 0
## 图像缩放只作用于身体（MV 缩放 _mainSprite），影子与位置不缩放
var body_scale := 1.0
## 会逐帧播放动作（侧视图、逐帧、场景；敌人单图不播放）
var sv := false
var motion := "walk"
var _frame := 0
var _tick := 0
var home := Vector2.ZERO
var facing_left := true
## YEP_X_AnimatedSVEnemies 呼吸（Breathing Y Rate 0.02）
var breathing := false
var _breath_t := 0.0
## 身体材质：hue 是神话敌人色相（载入时改图，先做），blend 是 Sprite.setBlendColor（技能动画目标闪光：rgb 向 blend.rgb 混合 blend.a）
const BODY_SHADER := """
shader_type canvas_item;
uniform float hue = 0.0;
uniform vec4 blend = vec4(0.0);
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = hue * 6.28318;
	vec3 k = vec3(0.57735);
	float ca = cos(a);
	c.rgb = c.rgb * ca + cross(k, c.rgb) * sin(a) + k * dot(k, c.rgb) * (1.0 - ca);
	c.rgb = mix(c.rgb, blend.rgb, blend.a);
	COLOR = c * tint;
}
"""
static var _body_shader: Shader


func _init() -> void:
	# 呼吸相位只属于画面：不能抽走战斗规则使用的全局随机数。
	var visual_rng := RandomNumberGenerator.new()
	visual_rng.randomize()
	_breath_t = visual_rng.randf() * TAU


func setup(b: XBattler, sprite_scale: float) -> void:
	battler = b
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	look = XAppearance.for_battler(b)
	_look_key = XAppearance.battler_key(b)
	sv = look.animated()
	if b is XEnemy and look.sideview:
		facing_left = false
	# MV Sprite_Actor.createShadowSprite：Shadow2，中心锚点，y −2（YEP_BattleEngineCore Show Shadows）；Mx_SuperSV <YCyy:true> 隐藏
	if b is XActor and not look.hide_shadow:
		var sp := XDB.img_path("system", "Shadow2")
		if sp != "":
			shadow = Sprite2D.new()
			shadow.texture = load(sp)
			shadow.position.y = -2
			add_child(shadow)
	if look.kind == "scene" and look.scene:
		sprite = look.scene.instantiate() as Node2D
		_hook_scene_finished()
	else:
		var body := Sprite2D.new()
		body.centered = true
		body.region_enabled = look.sideview
		sprite = body
	if sprite == null:
		sprite = Sprite2D.new()
	add_child(sprite)
	if b is XEnemy and look.sideview:
		_set_flip(true)
	body_scale = sprite_scale * look.scale
	_apply_scale()
	var cursor_name := str(XDB.plugin("YEP_BattleSelectCursor").get("Ally Cursor" if b is XActor else "Enemy Cursor", ""))
	var cp := XDB.img_path("pictures", cursor_name)
	if cp != "":
		cursor = Sprite2D.new()
		cursor.texture = load(cp)
		cursor.offset.y = -cursor.texture.get_height() / 2.0
		cursor.position.y = -look.cell.y if sv and look.kind != "scene" else -height()
		cursor.visible = false
		add_child(cursor)
	# EliteEnemyPlugins：神话敌人色相偏移（MV loadBitmap 的 hue）
	if b is XEnemy and (b as XEnemy).elite:
		_body_material().set_shader_parameter("hue", (b as XEnemy).elite_hue)
	set_motion("walk" if b.is_alive() else "dead")
	if not sv:
		_show_frame(look.frame("walk", 0))


static func _load(folder: String, name: String) -> Texture2D:
	var p := XDB.img_path(folder, name)
	return load(p) if p != "" else null


func width() -> float:
	return (look.cell.x if look.cell.x > 0 else 64.0) * body_scale


func height() -> float:
	return (look.cell.y if look.cell.y > 0 else 64.0) * body_scale


func _set_flip(f: bool) -> void:
	if sprite is Sprite2D:
		(sprite as Sprite2D).flip_h = f
	else:
		sprite.set_meta("flip", f)
		_apply_scale()


## 身体缩放（场景外观用负的 x 表示翻转）
func _apply_scale() -> void:
	var fx := -1.0 if sprite.get_meta("flip", false) else 1.0
	sprite.scale = Vector2(body_scale * fx, body_scale)


func set_motion(m: String) -> void:
	motion = m
	_frame = 0
	_tick = 0
	_apply()


## MV Sprite_Weapon.setup：第 id 张武器图在 Weapons{(id−1)/12+1}，每格 96×64，3 格。
func start_weapon(id: int) -> void:
	_weapon_id = id
	_weapon_pattern = 0
	_weapon_count = 0
	if weapon == null:
		weapon = Sprite2D.new()
		weapon.centered = true
		weapon.region_enabled = true
		weapon.position = Vector2(-16, 0)
		weapon.offset = Vector2(0, -32)
		add_child(weapon)
	var tex := _load("system", "Weapons%d" % (floori((id - 1) / 12.0) + 1)) if id > 0 else null
	weapon.texture = tex
	weapon.visible = tex != null
	_weapon_frame()


func _weapon_frame() -> void:
	if weapon == null or not weapon.visible:
		return
	var index := (_weapon_id - 1) % 12
	weapon.region_rect = Rect2((floori(index / 6.0) * 3 + _weapon_pattern) * 96, (index % 6) * 64, 96, 64)


## MV Sprite_Actor.updateMotionCount / Sprite_Weapon.updatePattern：按帧计数（60 帧/秒）。
## 行动序列演出时由 XSequencePlayer 在每帧固定位置调用（seq_driven），保证与正式版同一帧换动作。
func _physics_process(_delta: float) -> void:
	if not seq_driven:
		motion_tick()


func motion_tick() -> void:
	if weapon and weapon.visible:
		_weapon_count += 1
		if _weapon_count >= WEAPON_WAIT:
			_weapon_count = 0
			_weapon_pattern += 1
			if _weapon_pattern >= 3:
				weapon.visible = false
			else:
				_weapon_frame()
	if not sv:
		return
	if look.kind == "scene":
		return
	_tick += 1
	var w := look.wait_of(motion)
	if _tick >= (w if w > 0 else MOTION_SPEED):
		_tick = 0
		var n := look.frame_count(motion)
		if look.is_loop(motion):
			_frame = (_frame + 1) % maxi(n, 1)
		elif _frame < n - 1:
			_frame += 1
		else:
			set_motion(_idle_motion())
			return
		_apply()


func _process(delta: float) -> void:
	if battler is XActor:
		var k := str(view.get("look", _look_key)) if not view.is_empty() else XAppearance.battler_key(battler)
		if k != _look_key:
			swap_look(k)
	if cursor:
		cursor.visible = selected
	if selected:
		_selection_frame += 1
		sprite.modulate = Color(1.5, 1.5, 1.5) if _selection_frame % 30 < 15 else Color.WHITE
	else:
		_selection_frame = 0
	if breathing and not (view.dead if not view.is_empty() else battler.is_dead()):
		_breath_t += delta * TAU / 2.4
		sprite.scale.y = body_scale * (1.0 + sin(_breath_t) * 0.02)
		sprite.position.y = -_lift_px


## 换装卡（卡状态 Custom Apply／Remove Effect 的 setBattlerImage）：按外观键换图，动作与帧接着播。
## 只换 Sprite2D 身体；场景外观（appearances.json 的 scene）不换（目前没有角色登记场景外观）。
func swap_look(key: String) -> void:
	_look_key = key
	if look.kind == "scene" or not sprite is Sprite2D:
		return
	var next := XAppearance.for_look(battler as XActor, key)
	if next.kind == "scene":
		return
	body_scale = body_scale / maxf(look.scale, 0.0001) * next.scale
	look = next
	sv = look.animated()
	(sprite as Sprite2D).region_enabled = look.sideview
	_apply_scale()
	_frame = mini(_frame, maxi(look.frame_count(motion) - 1, 0))
	if sv:
		_apply()
	else:
		_show_frame(look.frame("walk", 0))


func _idle_motion() -> String:
	if not view.is_empty():
		if view.dead:
			return "dead"
		if view.hp / maxf(view.mhp, 1.0) < 0.25:
			return "dying"
		return "guard" if view.guarding else "walk"
	if battler.is_dead():
		return "dead"
	if battler.hp_rate() < 0.25:
		return "dying"
	if battler.guarding:
		return "guard"
	return "walk"


func refresh_idle() -> void:
	if LOOP.has(motion) and motion != _idle_motion():
		set_motion(_idle_motion())


func _apply() -> void:
	if not sv:
		return
	if look.kind == "scene":
		_play_scene(look.resolve(motion) if not look.motions.is_empty() else motion)
		return
	_show_frame(look.frame(motion, _frame))


## 显示一帧（MV 侧视图的循环动作已在外观里展开成 0,1,2,1）；身体以脚底为原点
func _show_frame(f: Dictionary) -> void:
	var body := sprite as Sprite2D
	if body == null or f.is_empty():
		return
	body.texture = f.tex
	var r: Rect2 = f.get("rect", Rect2())
	body.region_enabled = r.has_area()
	if r.has_area():
		body.region_rect = r
	var h := r.size.y if r.has_area() else float((f.tex as Texture2D).get_height())
	body.offset.y = -h / 2.0


# ---- 场景外观：根节点有 play_motion(名) 就调用，否则找 AnimationPlayer / AnimatedSprite2D 播同名动画 ----
func _play_scene(m: String) -> void:
	if sprite.has_method("play_motion"):
		sprite.call("play_motion", m)
		return
	var aps := sprite.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		var ap := aps[0] as AnimationPlayer
		var name := _scene_anim(m, func(n): return ap.has_animation(n))
		if name != "":
			ap.play(name)
		return
	var list := sprite.find_children("*", "AnimatedSprite2D", true, false)
	if sprite is AnimatedSprite2D:
		list.insert(0, sprite)
	if not list.is_empty():
		var a := list[0] as AnimatedSprite2D
		var name := _scene_anim(m, func(n): return a.sprite_frames != null and a.sprite_frames.has_animation(n))
		if name != "":
			a.play(name)


static func _scene_anim(m: String, has: Callable) -> String:
	var seen := {}
	var cur := m
	while cur != "" and not seen.has(cur):
		if has.call(cur):
			return cur
		seen[cur] = true
		cur = XAppearance.FALLBACK.get(cur, "")
	return "walk" if has.call("walk") else ""


## 场景播完非循环动作时回到待机（根节点发 motion_finished，或 AnimationPlayer/AnimatedSprite2D 播完）
func _hook_scene_finished() -> void:
	if sprite == null:
		return
	var done := func(_a = null):
		if not LOOP.has(motion):
			set_motion(_idle_motion())
	if sprite.has_signal("motion_finished"):
		sprite.connect("motion_finished", done)
	for ap in sprite.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).animation_finished.connect(done)
	for a in sprite.find_children("*", "AnimatedSprite2D", true, false) + ([sprite] if sprite is AnimatedSprite2D else []):
		(a as AnimatedSprite2D).animation_finished.connect(done)


static func body_shader() -> Shader:
	if _body_shader == null:
		_body_shader = Shader.new()
		_body_shader.code = BODY_SHADER
	return _body_shader


## 身体的 BODY_SHADER 材质（用到时才建）。场景外观里没有自己材质的子节点跟着用；
## 自带材质的子节点（外观作者的特效、描边等）保留自己的材质，不被色相/闪光盖掉。
func _body_material() -> ShaderMaterial:
	if not sprite.material is ShaderMaterial:
		var mat := ShaderMaterial.new()
		mat.shader = body_shader()
		sprite.material = mat
		for n in sprite.find_children("*", "CanvasItem", true, false):
			if (n as CanvasItem).material == null:
				(n as CanvasItem).use_parent_material = true
	return sprite.material


## 技能动画目标（Sprite_Animation._target）：角色是 _mainSprite、敌人是 Sprite_Enemy，这里都作用在身体上
func set_anim_blend(c: Color) -> void:
	if c.a <= 0.0 and not sprite.material is ShaderMaterial:
		return
	_body_material().set_shader_parameter("blend", c)


func anim_blend() -> Color:
	return sprite.material.get_shader_parameter("blend") if sprite.material is ShaderMaterial else Color(0, 0, 0, 0)


## Sprite_Base.hide/show（技能动画 flashScope 3）
func set_anim_hidden(h: bool) -> void:
	sprite.visible = not h


func flash(color := Color(1, 1, 1)) -> void:
	var t := create_tween()
	sprite.modulate = color * 2.0
	t.tween_property(sprite, "modulate", Color.WHITE, 0.25)


## MV Sprite_Enemy.updateBlink：20 帧，每 10 帧里前 5 帧显示、后 5 帧隐藏
func blink() -> void:
	effect_left = maxi(effect_left, 20)
	for f in range(20, 0, -1):
		sprite.visible = f % 10 < 5
		await get_tree().physics_frame
	sprite.visible = true


func step(forward: bool) -> void:
	var dir := -1.0 if (battler is XActor) else 1.0
	var t := create_tween()
	t.tween_property(self, "position", home + Vector2(dir * 48.0 if forward else 0.0, 0), XBattleTiming.move_frames(12) / 60.0)
	await t.finished


func collapse() -> void:
	if battler is XActor:
		set_motion("dead")
		return
	appeared = false
	effect_left = maxi(effect_left, 32)  # MV Sprite_Enemy.startCollapse：32 帧
	_fade = create_tween()
	_fade.tween_property(sprite, "modulate", Color(1, 0.3, 0.3, 0.0), 0.5)
	await _fade.finished


## MV Sprite_Enemy._appeared：开战时没出现的隐藏成员（initVisibility）与倒下后（startCollapse）为 false
var appeared := true
var _fade: Tween

## MV Sprite_Enemy.startAppear：没出现的敌人又活着时（335 出现、334 复活倒下的成员）恢复正常色后 16 帧淡入；
## 不等淡入（原版事件照常往下走，行动序列等效果时看 effect_left）
func appear() -> void:
	appeared = true
	effect_left = maxi(effect_left, 16)
	if _fade and _fade.is_running():
		_fade.custom_step(3600.0)  # 收掉还在播的倒下淡出（照样发 finished，等它的演出不会卡住）
	sprite.modulate = Color(1, 1, 1, 0)
	_fade = create_tween()
	_fade.tween_property(sprite, "modulate", Color.WHITE, 16 / 60.0)


func revive_visual() -> void:
	sprite.modulate = Color.WHITE
	set_motion(_idle_motion())


# ---- YEP 行动序列的画面状态（XSequencePlayer 每帧调 seq_update；YEP_X_ActSeqPack2 Sprite_Battler） ----
## 正式版 WY 插件在输入阶段后把战斗者坐标锁死，移动指令只剩计时（_movementDuration 照样倒数）；这里只记剩余帧。
var move_left := 0
var float_height := 0.0
var _float_target := 0.0
var _float_dur := 0
var _float_rate := 0.0
var _jump_height := 0.0
var _jump_dur := 0
var _jump_full := 0
var seq_opacity := 255.0
var _opacity_target := 255.0
var _opacity_dur := 0
var _opacity_rate := 0.0
var _opacity_changing := false
## 精灵效果（Sprite_Enemy._effectDuration：闪烁、变白、倒下），WAIT FOR EFFECT 等它
var effect_left := 0
var mirrored := false
var _lift_px := 0.0
var seq_driven := false


## spriteWidth/spriteHeight：未缩放的帧大小（角色 _mainSprite 一格，敌人整图）
func frame_size() -> Vector2:
	var body := sprite as Sprite2D
	if body and body.texture:
		return body.region_rect.size if body.region_enabled else Vector2(body.texture.get_size())
	return Vector2(width(), height()) / maxf(body_scale, 0.0001)


func setup_float(h: float, dur: int) -> void:
	dur = maxi(1, dur)
	_float_target = h
	_float_dur = dur
	_float_rate = absf(float_height - h) / dur


func setup_jump(h: float, dur: int) -> void:
	_jump_height = h
	_jump_dur = dur
	_jump_full = dur


func setup_opacity(target: float, dur: int) -> void:
	dur = maxi(1, dur)
	_opacity_target = target
	_opacity_dur = dur
	_opacity_rate = absf(seq_opacity - target) / dur
	_opacity_changing = true


## getFloatHeight：每取一次就向目标走一步（正式版每帧至少取两次）
func float_step() -> float:
	if _float_dur <= 0:
		float_height = _float_target
	elif float_height >= _float_target:
		float_height = maxf(_float_target, float_height - _float_rate)
	else:
		float_height = minf(_float_target, float_height + _float_rate)
	return float_height


func jump_height() -> float:
	if _jump_dur <= 0:
		return 0.0
	var x := float(_jump_full - _jump_dur)
	var h := _jump_full / 2.0
	return -_jump_height / (h * h) * (x - h) * (x - h) + _jump_height


## YEP_X_ActSeqPack2 Sprite_Animation.updateBattlerPosition：头上／中心的动画每帧再抬高（浮空率＋跳跃率）× 战斗者精灵的图高
## （敌人：单图是原图，侧视是取整后的一格；角色：YEP_BattleEngineCore updateFrame 给 Sprite_Actor 建的一格大小 Bitmap）。
## 原版这里取浮空率（getFloatHeight）也会让浮空再向目标走一步，所以身上有动画时浮空变快，照原样。
func anim_lift() -> float:
	return (float_step() + jump_height()) * floorf(look.cell.y if look.cell.y > 0 else 64.0)


func is_floating() -> bool:
	return _float_dur > 0


func is_jumping() -> bool:
	return _jump_dur > 0


func is_changing_opacity() -> bool:
	return _opacity_dur > 0


func set_mirror(m: bool) -> void:
	mirrored = m
	scale.x = -absf(scale.x) if m else absf(scale.x)


## Sprite_Battler.update 里与序列有关的部分（updateMove 的计时、updateFloat、updateStateSprites、updateOpacity），
## 再加 Sprite_Enemy.updateEffect 的计时
func seq_update() -> void:
	if move_left > 0:
		move_left -= 1
	if _float_dur > 0:
		_float_dur -= 1
	if _jump_dur > 0:
		_jump_dur -= 1
	_lift_px = (float_step() + jump_height()) * frame_size().y * body_scale
	sprite.position.y = -_lift_px
	if weapon:
		weapon.position.y = -_lift_px
	float_step()
	if _opacity_changing:
		_opacity_dur -= 1
		if _opacity_dur <= 0:
			seq_opacity = _opacity_target
			_opacity_changing = false
		elif seq_opacity >= _opacity_target:
			seq_opacity = maxf(_opacity_target, seq_opacity - _opacity_rate)
		else:
			seq_opacity = minf(_opacity_target, seq_opacity + _opacity_rate)
	modulate.a = seq_opacity / 255.0
	if effect_left > 0:
		effect_left -= 1
	motion_tick()
