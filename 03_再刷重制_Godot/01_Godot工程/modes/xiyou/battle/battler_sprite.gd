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
## 优化 O-112（全体技能选目标全亮）：同组一起闪的是 selected＋show_cursor=false（不画箭头，箭头只在光标那只）；
## prey＝妖族群攻手选的猎物，闪红。
var show_cursor := true
var prey := false
var _selection_frame := 0
## 图像缩放只作用于身体（MV 缩放 _mainSprite），影子与位置不缩放
var body_scale := 1.0
## setup 给的缩放（旧式角色 0.75、敌人 1／精英 1.8）；新增角色有归一档时改用档里的缩放（_show_frame）
var _base_scale := 1.0
## Codex_MiraRavenMultiFrame 站姿归一档（XAppearance.profile，角色 ID ≥ 167 才有）：此刻这一帧的
var _profile := {}
## 渡鸦神话浮空（applyVisual 的 float：−14＋sin((帧＋角色 ID)／22)×1.5，阵亡时 0），加在身体的脚底位置上
var _float_px := 0.0
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
	if b is XActor and not look.hide_shadow:
		_make_shadow()
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
	_base_scale = sprite_scale
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


## MV Sprite_Actor.createShadowSprite：Shadow2，中心锚点，y −2（YEP_BattleEngineCore Show Shadows）；Mx_SuperSV <YCyy:true> 隐藏
func _make_shadow() -> void:
	var sp := XDB.img_path("system", "Shadow2")
	if sp != "":
		shadow = Sprite2D.new()
		shadow.texture = load(sp)
		shadow.position.y = -2
		add_child(shadow)
		move_child(shadow, 0)


static func _load(folder: String, name: String) -> Texture2D:
	var p := XDB.img_path(folder, name)
	return load(p) if p != "" else null


## Game_Actor.spriteWidth／spriteHeight：有归一档时按可见范围（选择光标、状态图标跟着看得见的身体），浮空另加高
func width() -> float:
	if not _profile.is_empty():
		return _profile.bounds.size.x * _profile.scale
	return (look.cell.x if look.cell.x > 0 else 64.0) * body_scale


func height() -> float:
	if not _profile.is_empty():
		return _profile.bounds.size.y * _profile.scale + maxf(0.0, -_float_px)
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
	if m == "walk" and _guyu_planted():
		m = "wait"
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
	weapon.visible = tex != null and not _profile.get("multi", false)  # applyVisual：新增角色在逐帧图时藏武器
	_weapon_frame()


func _weapon_frame() -> void:
	if weapon == null or not weapon.visible:
		return
	var index := (_weapon_id - 1) % 12
	weapon.region_rect = Rect2((floori(index / 6.0) * 3 + _weapon_pattern) * 96, (index % 6) * 64, 96, 64)


## MV Sprite_Actor.updateMotionCount / Sprite_Weapon.updatePattern：按帧计数（60 帧/秒）。
## 行动序列演出时由 XSequencePlayer 在每帧固定位置调用（seq_driven），保证与正式版同一帧换动作。
func _physics_process(_delta: float) -> void:
	_moving = move_left > 0 or (_last_pos != Vector2.INF and position != _last_pos)
	_last_pos = position
	if not seq_driven:
		motion_tick()
	if _fx != null:
		_fx_tick()
	if _domain_circle != null and _domain_circle.visible:
		_domain_circle.step()


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
	if _guyu_planted():
		# 谷雨、小猫剑圣 planted（updateFrame／updateMotionCount 包装）：不在移动时「走」改「待机」，待机停在第 0 帧
		if motion == "walk":
			set_motion("wait")
		if motion == "wait":
			_tick = 0
			if _frame != 0:
				_frame = 0
				_apply()
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
		cursor.visible = selected and show_cursor
	if selected:
		_selection_frame += 1
		var lit := Color(1.7, 0.7, 0.7) if prey else Color(1.5, 1.5, 1.5)
		sprite.modulate = lit if _selection_frame % 30 < 15 else (Color(1.3, 0.85, 0.85) if prey else Color.WHITE)
	else:
		_selection_frame = 0
	if not _profile.is_empty():
		var raven := _look_key.contains("|form:RavenMythic")
		var f := -14.0 + sin((Engine.get_process_frames() + int((battler as XActor).actor_id)) / 22.0) * 1.5 \
			if raven and not (view.dead if not view.is_empty() else battler.is_dead()) else 0.0
		if f != _float_px:
			_float_px = f
			_place_body()
	if breathing and not (view.dead if not view.is_empty() else battler.is_dead()):
		_breath_t += delta * TAU / 2.4
		sprite.scale.y = body_scale * (1.0 + sin(_breath_t) * 0.02)
		sprite.position.y = -_lift_px
	_update_indicators()


# ---- 角色形象 CodexBattleIndicators：宿傩领域法阵、黑闪觉醒描边（XBattleIndicators） ----
var _domain_circle: XBattleIndicators.DomainCircle
var _outline: Node2D


## updateIndicators：回放行动时按命中记录的读数（view），平时按当前状态；第一次要显示时才建
func _update_indicators() -> void:
	if not battler is XActor:
		return
	var body := sprite as Sprite2D
	var shown: bool = not (view.dead if not view.is_empty() else battler.is_dead()) and sprite.visible and sprite.modulate.a > 0.0 \
		and (body == null or body.texture != null)
	var domain: bool = shown and (bool(view.get("domain", false)) if not view.is_empty() else XBattleIndicators.domain_shown(battler))
	var awake: bool = shown and body != null and (bool(view.get("flash_awake", false)) if not view.is_empty() else XBattleIndicators.outline_shown(battler))
	if domain:
		if _domain_circle == null:
			_domain_circle = XBattleIndicators.DomainCircle.new()
			add_child(_domain_circle)
			move_child(_domain_circle, 0)  # addChildAt(root, 0)：影子之下
		# 可见脚底：身体以脚底为原点（有归一档时是可见范围的底边中点），跟着身体的位置
		_domain_circle.position = sprite.position
	if _domain_circle != null:
		_domain_circle.visible = domain
	if awake:
		if _outline == null:
			_outline = XBattleIndicators.make_outline()
			add_child(_outline)
			move_child(_outline, sprite.get_index())  # 插在身体之下：身体盖住剪影内部，只露出边
		XBattleIndicators.sync_outline(_outline, body)
	if _outline != null:
		_outline.visible = awake


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
	if shadow == null and not look.hide_shadow:
		_make_shadow()
	if shadow:
		shadow.visible = not look.hide_shadow  # Mx_SuperSV updateShadow：<YCyy:true> 每帧藏影子（渡鸦神话那套带它）
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
	_frame_h = r.size.y if r.has_area() else float((f.tex as Texture2D).get_height())
	_profile = XAppearance.profile(f, motion) if battler is XActor and int((battler as XActor).actor_id) >= 167 else {}
	body_scale = (_profile.scale if not _profile.is_empty() else _base_scale) * look.scale
	_apply_scale()
	if weapon and _profile.get("multi", false):
		weapon.visible = false
	_place_body()


var _frame_h := 0.0


## 身体以脚底为原点；有归一档时可见范围的底边中点落在原点（anchor 0.5,1 再挪 ((宽／2−可见中线), (高−可见底边))×缩放），浮空往上
func _place_body() -> void:
	var body := sprite as Sprite2D
	if body == null:
		return
	if _profile.is_empty():
		body.offset = Vector2(0, -_frame_h / 2.0)
		return
	var size: Vector2 = _profile.size
	var b: Rect2 = _profile.bounds
	body.offset = Vector2(size.x / 2.0 - b.get_center().x, size.y / 2.0 - b.end.y) + Vector2(0, _float_px / maxf(body_scale, 0.0001))


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


# ---- 谷雨（installNativeGuyuRuntime 565～680 installVisualHooks，v0.28 谷雨原素材待机稳定修复）----
## OTB 等输入时用「走」，谷雨本人的素材（battlerName Guyu、没有换装卡）走与待机帧都带步子：不在移动时改「待机」并定在第 0 帧。
var _moving := false
var _last_pos := Vector2.INF


## 谷雨（installNativeGuyuRuntime）与小猫剑圣（installNativeCharacterVisualRuntime planted）同一套：不在移动时「走」改「待机」，待机停在第 0 帧
func _guyu_planted() -> bool:
	if _moving or not battler is XActor:
		return false
	return (XGuyu.own(battler) and _look_key == "Guyu") or XAppearance.cat_visual(battler)


## queueVisual 的画面反馈（只属于精灵，不进存档、不用战斗随机数）：归根 root 48 帧——脚下落八片金边瓷片、五片枯叶，
## 透明度 sin(π×进度)。原版另画了「再生」的抽芽开花（64 帧），但只排过 root，那段画不到，没移植。
var _fx: Node2D
var _fx_kind := ""
var _fx_time := 0
const FX_ROOT_FRAMES := 48


func guyu_visual(kind: String) -> void:
	if not (battler is XActor and XGuyu.own(battler)):
		return
	if _fx == null:
		_fx = Node2D.new()
		_fx.draw.connect(_fx_draw)
		add_child(_fx)
	_fx_kind = kind
	_fx_time = 0
	_fx.visible = true
	# 原版画在可见的脚底中点（按 CodexSV 档）：站姿归一后正是身体原点（_place_body），没有档时是图底边中点，也是原点
	_fx.position = Vector2.ZERO


func _fx_tick() -> void:
	if _fx_kind == "":
		return
	_fx_time += 1
	if _fx_time > FX_ROOT_FRAMES or not XGuyu.active_battle:
		_fx_kind = ""
		_fx_time = 0
		_fx.visible = false
	_fx.queue_redraw()


func _fx_draw() -> void:
	if _fx_kind != "root":
		return
	var life := float(_fx_time) / FX_ROOT_FRAMES
	var alpha := sin(PI * life)
	var edge := Color8(0xe1, 0xb8, 0x58)
	edge.a = alpha * 0.8
	var chip := Color8(0xe7, 0xdc, 0xc1)
	chip.a = alpha * 0.85
	for i in 8:
		var side := 1.0 if i % 2 else -1.0
		var x := side * (7.0 + i * 2.4 + life * 13.0)
		var y := -22.0 + life * 26.0 + sin(i * 2.1) * 7.0
		var pts := PackedVector2Array([Vector2(x - 2, y - 2), Vector2(x + 3, y - 1), Vector2(x + 1, y + 3), Vector2(x - 3, y + 1)])
		_fx.draw_colored_polygon(pts, chip)
		var ring := pts.duplicate()
		ring.append(pts[0])
		_fx.draw_polyline(ring, edge, 1.0)
	var leaf := Color8(0x89, 0x9a, 0x56)
	leaf.a = alpha * 0.7
	for j in 5:
		_fx_petal(Vector2(cos(j * 2.1) * (8.0 + life * 20.0), -34.0 + life * 36.0 + j * 3.0), 2.4, leaf)


## drawPetal：横向椭圆（半径 r×1.6、r×0.65）
func _fx_petal(c: Vector2, r: float, color: Color) -> void:
	_fx.draw_set_transform(c, 0.0, Vector2(r * 1.6, r * 0.65))
	_fx.draw_circle(Vector2.ZERO, 1.0, color)
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
