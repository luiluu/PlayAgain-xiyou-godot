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
var look: XAppearance
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
var _breath_t := randf() * TAU
const HUE_SHADER := """
shader_type canvas_item;
uniform float hue = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float a = hue * 6.28318;
	vec3 k = vec3(0.57735);
	float ca = cos(a);
	c.rgb = c.rgb * ca + cross(k, c.rgb) * sin(a) + k * dot(k, c.rgb) * (1.0 - ca);
	COLOR = c;
}
"""


func setup(b: XBattler, sprite_scale: float) -> void:
	battler = b
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	look = XAppearance.for_battler(b)
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
		var mat := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = HUE_SHADER
		mat.shader = sh
		mat.set_shader_parameter("hue", (b as XEnemy).elite_hue)
		sprite.material = mat
		for n in sprite.find_children("*", "CanvasItem", true, false):
			(n as CanvasItem).use_parent_material = true
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


## MV Sprite_Actor.updateMotionCount / Sprite_Weapon.updatePattern：按帧计数（60 帧/秒）
func _physics_process(_delta: float) -> void:
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
	if cursor:
		cursor.visible = selected
	if selected:
		_selection_frame += 1
		sprite.modulate = Color(1.5, 1.5, 1.5) if _selection_frame % 30 < 15 else Color.WHITE
	else:
		_selection_frame = 0
	if breathing and battler.is_alive():
		_breath_t += delta * TAU / 2.4
		sprite.scale.y = body_scale * (1.0 + sin(_breath_t) * 0.02)
		sprite.position.y = 0.0


func _idle_motion() -> String:
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


func flash(color := Color(1, 1, 1)) -> void:
	var t := create_tween()
	sprite.modulate = color * 2.0
	t.tween_property(sprite, "modulate", Color.WHITE, 0.25)


## MV Sprite_Enemy.updateBlink：20 帧，每 10 帧里前 5 帧显示、后 5 帧隐藏
func blink() -> void:
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
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color(1, 0.3, 0.3, 0.0), 0.5)
	await t.finished


func revive_visual() -> void:
	sprite.modulate = Color.WHITE
	set_motion(_idle_motion())
