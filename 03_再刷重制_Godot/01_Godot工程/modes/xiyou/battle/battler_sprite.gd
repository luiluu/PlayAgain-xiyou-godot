class_name XBattlerSprite
extends Node2D
## 战斗者图像。角色用 MV 侧视图（9×6 格、每格 64×64、18 种动作）；敌人用 sv_enemies 单图，
## 或 <Sideview Battler: 名> 指定的角色侧视图（如守层者里德）。像素图放大时用最近邻采样保持清晰。

const MOTIONS := {"walk": 0, "wait": 1, "chant": 2, "guard": 3, "damage": 4, "evade": 5, "thrust": 6, "swing": 7,
	"missile": 8, "skill": 9, "spell": 10, "item": 11, "escape": 12, "victory": 13, "dying": 14, "abnormal": 15,
	"sleep": 16, "dead": 17}
const LOOP := ["walk", "wait", "chant", "guard", "dying", "abnormal", "sleep", "dead", "victory"]
## 正式版运行时读数：Sprite_Actor.motionSpeed 6 帧一格，Sprite_Weapon.animationWait 3 帧一格
const MOTION_SPEED := 6
const WEAPON_WAIT := 3

var battler: XBattler
var sprite: Sprite2D
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
	# MV Sprite_Actor.createShadowSprite：Shadow2，中心锚点，y −2（YEP_BattleEngineCore Show Shadows）
	if b is XActor:
		var sp := XDB.img_path("system", "Shadow2")
		if sp != "":
			shadow = Sprite2D.new()
			shadow.texture = load(sp)
			shadow.position.y = -2
			add_child(shadow)
	sprite = Sprite2D.new()
	sprite.centered = true
	add_child(sprite)
	var tex: Texture2D = null
	if b is XActor:
		tex = _load("sv_actors", str((b as XActor).data().battlerName))
		sv = true
	else:
		var e := b as XEnemy
		var side = e.data().get("meta", {}).get("Sideview Battler")
		if side != null:
			tex = _load("sv_actors", str(side).strip_edges())
			sv = true
			facing_left = false
		else:
			tex = _load("sv_enemies", str(e.data().battlerName))
	sprite.texture = tex
	if sv and tex:
		sprite.region_enabled = true
		sprite.flip_h = not facing_left if b is XEnemy else false
	if tex:
		var h := 64.0 if sv else float(tex.get_height())
		sprite.offset.y = -h / 2.0
	body_scale = sprite_scale
	sprite.scale = Vector2.ONE * body_scale
	var cursor_name := str(XDB.plugin("YEP_BattleSelectCursor").get("Ally Cursor" if b is XActor else "Enemy Cursor", ""))
	var cp := XDB.img_path("pictures", cursor_name)
	if cp != "":
		cursor = Sprite2D.new()
		cursor.texture = load(cp)
		cursor.offset.y = -cursor.texture.get_height() / 2.0
		cursor.position.y = -64.0 if sv else -height()
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
	set_motion("walk" if b.is_alive() else "dead")


static func _load(folder: String, name: String) -> Texture2D:
	var p := XDB.img_path(folder, name)
	return load(p) if p != "" else null


func width() -> float:
	if sprite.texture == null:
		return 64.0 * body_scale
	return (64.0 if sv else float(sprite.texture.get_width())) * body_scale


func height() -> float:
	if sprite.texture == null:
		return 64.0 * body_scale
	return (64.0 if sv else float(sprite.texture.get_height())) * body_scale


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
	_tick += 1
	if _tick >= MOTION_SPEED:
		_tick = 0
		if LOOP.has(motion):
			_frame = (_frame + 1) % 4
		elif _frame < 2:
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
	if not sv or sprite.texture == null:
		return
	var idx: int = MOTIONS.get(motion, 0)
	# 循环动作的第 4 格回到中间一格（MV：pattern < 3 ? pattern : 1）
	var cx := floori(idx / 6.0) * 3 + (_frame if _frame < 3 else 1)
	var cy := idx % 6
	sprite.region_rect = Rect2(cx * 64, cy * 64, 64, 64)


func flash(color := Color(1, 1, 1)) -> void:
	var t := create_tween()
	sprite.modulate = color * 2.0
	t.tween_property(sprite, "modulate", Color.WHITE, 0.25)


## MV Sprite_Enemy.updateBlink：20 帧，每 10 帧里前 5 帧显示、后 5 帧隐藏
func blink() -> void:
	for f in range(20, 0, -1):
		sprite.self_modulate.a = 1.0 if f % 10 < 5 else 0.0
		await get_tree().physics_frame
	sprite.self_modulate.a = 1.0


func step(forward: bool) -> void:
	var dir := -1.0 if (battler is XActor) else 1.0
	var t := create_tween()
	t.tween_property(self, "position", home + Vector2(dir * 48.0 if forward else 0.0, 0), 0.15)
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
