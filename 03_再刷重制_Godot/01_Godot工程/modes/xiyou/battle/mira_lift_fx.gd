class_name XMiraLiftFx
extends Node2D
## 米拉解放·黑龙的升空变身演出（co 出 u7，Kyo 11-15 通过 D35；素材 content/mira/fx/lift_u7/，说明见 content/mira/README.md）。
## - 触发：XBattlerSprite.swap_look 把米拉从人形（|form:MiraHuman…）换成黑龙（|form:MiraDragon）时（2592 加上后外观键变了），
##   在精灵下挂这一层放 2320ms（1× 战斗速度）。只是画面：2592、属性和结算都在 XMira.liberate 里照旧当场做完，战斗流程不等它。
## - 按时间轴拼（不播 116 张帧序列）：人形（Codex_Mira_SV_u2 第 1 行第 1 列格，锚 [32,61]）→ 8 张过渡姿势（340×280，锚 [160,217]）
##   → 黑龙 Final（UserSV_MiraDragon0_0，与 dragon.png 字节相同）。位置、姿势交叉淡化（下一姿势前 120ms，1210ms 起 60ms）、
##   四层火屑（[毫秒, 透明度, 缩放, dx, dy]，区间外隐藏）都照 时间轴.json，相邻关键帧 smoothstep，位置取整。
##   路径（D40，Kyo 11-15）：x 从脚底 0 起、整段向左挪、落地约 −25，再平滑回正到 0（1800ms）；y＝−高度（原点＝最终脚点＝战斗者脚底）。
## - 时钟：elapsed_ms += delta×1000×战斗动画倍速（battleAniSpeed：4＝1×、3＝2×、2＝3×、1＝4×；_process 的 delta 只含变速齿轮，
##   不含这一份，所以这里乘）；战斗暂停（树暂停）时 _process 不走，时钟同停；速度中途变下一帧就按新倍速走。
## - 大小：素材按原尺寸画（人形 64 格、黑龙可见高 159），游戏里两种形态都归一到站姿高 72（人形缩放约 1.24、黑龙约 0.45）。
##   层的缩放从人形当时的身体缩放平滑过渡到黑龙的身体缩放（0→1800ms，smoothstep），开头接人形、1800ms 起与黑龙本体完全重合，
##   两头都不跳；中途黑龙在空中会比站姿大（约 1.9 倍高），落地收回。缩小（<1）时平滑采样，与身体归一缩小一致，其余最近邻。
## - 1800ms 起（姿势已落到 Final）层里的身体收起、显示精灵本体（原样黑龙），只剩火屑收尾；2320ms 钳住、清掉整层、完成回调只调一次。
## - 「显示技能动画」关着（CombatSkillAnimation，默认关）或快速战斗：不建层，直接是黑龙 Final，完成回调立即调。
##   放着中途关掉、阵亡、外观又换回人形、精灵被释放：都立即收尾（恢复本体、清火屑）。
## - 画在本体之后（层插在身体前面，火屑在黑龙之后）；纹理最近邻、无 mipmap；画布空白不裁，按原锚点摆。
## - 开关：XMira.LIFT_ART（false＝回到旧表现：外观键一变直接换成黑龙）。

const DIR := "res://content/mira/fx/lift_u7/"
const DRAGON_TEX := "res://content/mira/img/sv_actors/sv/UserSV_MiraDragon/UserSV_MiraDragon0_0.png"
const HUMAN_CELL := Rect2(64, 64, 64, 64)
const DURATION := 2320.0
## 层缩放从人形过渡到黑龙所用的时长（姿势 1800ms 落到 Final）
const SETTLE_MS := 1800.0
const HUMAN_ANCHOR := Vector2(32, 61)
const POSE_ANCHOR := Vector2(160, 217)
const FX_ANCHOR := Vector2(128, 128)
## [毫秒, 姿势, 高度, x]（时间轴.json keyframes；x＝相对最终脚点的水平位置，D40：起点在脚下、整段轨迹左挪、落地后回正）
const KEYS := [
	[0, "human", 0, 0], [140, "MiraLift", 1, 0], [260, "MiraHover", 24, 0], [480, "MiraWingHuman", 89, -4],
	[600, "MiraWingHuman", 107, -6], [680, "MiraHybrid", 112, -8], [800, "MiraAir", 115, -11], [920, "MiraAir", 116, -16],
	[1050, "MiraAir", 113, -23], [1210, "MiraDescend", 84, -28], [1380, "MiraDescend", 38, -27], [1460, "MiraTouchdown", 14, -26],
	[1530, "MiraTouchdown", 0, -25], [1660, "MiraSettle", 0, -12], [1800, "dragon", 0, 0], [2320, "dragon", 0, 0],
]
const POSE_FADE_MS := 120.0
const DRAGON_FADE_MS := 60.0
const DRAGON_FADE_FROM := 1210
## 火屑四层（时间轴.json flame_layers）：[图, 跟随, [[毫秒, 透明度, 缩放, dx, dy], …]]；ground＝x 跟身体、y 在地面
const FLAMES := [
	["MiraEmberLift", "body", [[135, 0.0, 1.04, -3.0, 3.9], [240, 1.0, 1.326, -2.0, 8.4], [400, 0.8855, 1.534, 2.5, 13.5], [600, 0.0, 1.69, 4.0, 19.5]]],
	["MiraEmberArc", "body", [[490, 0.0, 0.975, 4.0, -23.0], [655, 0.9545, 1.326, 6.5, -46.0], [815, 1.0, 1.664, 11.5, -64.0], [1030, 0.0, 2.028, 19.0, -77.0]]],
	["MiraEmberScatter", "body", [[780, 0.0, 0.91, 0.0, -25.0], [900, 0.9775, 1.43, 3.0, -52.0], [1040, 0.8395, 1.794, 6.0, -64.0], [1260, 0.0, 2.171, 8.0, -74.0]]],
	["MiraEmberLanding", "ground", [[1500, 0.0, 0.91, 0.0, 4.0], [1570, 0.874, 1.3, -1.0, 4.0], [1710, 0.6785, 1.534, -2.0, 3.0], [1940, 0.0, 1.95, -3.0, 3.0]]],
]

var elapsed := 0.0
var done := false
var from_scale := 1.0
var _on_done := Callable()
var _a: Sprite2D
var _b: Sprite2D
var _fx := []
static var _tex_cache := {}


## 战斗动画倍速（YEP_BattleAniSpeedOpt battleAniSpeed：1 四倍……4 OFF＝1×）
static func speed_mult() -> float:
	return float(5 - clampi(XConfig.battle_speed(), 1, 4))


## 这次换外观是不是米拉人形 → 黑龙
static func is_lift(sp: XBattlerSprite, old_key: String, new_key: String) -> bool:
	return XMira.LIFT_ART and XMira.DRAGON_ART and sp != null and XMira.own(sp.battler) \
		and old_key.contains("|form:MiraHuman") and new_key.contains("|form:MiraDragon")


## 要放完整演出（否则直接是黑龙）：「显示技能动画」开着、不在快速战斗
static func animate_on() -> bool:
	return XConfig.flag("CombatSkillAnimation") and not (XState.current != null and XHangUp.fast_fighting(XState.current))


static func layer_of(sp: XBattlerSprite) -> XMiraLiftFx:
	return sp.get_node_or_null("MiraLiftFx") as XMiraLiftFx if sp != null else null


## XBattlerSprite.swap_look 末尾调：人形→黑龙开演；黑龙→别的（换回人形）时把在放的收掉
static func on_swap(sp: XBattlerSprite, old_key: String, new_key: String, old_scale: float, on_done := Callable()) -> XMiraLiftFx:
	if not new_key.contains("|form:MiraDragon"):
		cancel(sp)
		return null
	if not is_lift(sp, old_key, new_key):
		return null
	return begin(sp, old_scale, on_done)


## 开演；动画关着时不建层、立即调完成回调，返回 null
static func begin(sp: XBattlerSprite, old_scale: float, on_done := Callable()) -> XMiraLiftFx:
	cancel(sp)
	if not animate_on():
		if on_done.is_valid():
			on_done.call()
		return null
	var l := XMiraLiftFx.new()
	l.name = "MiraLiftFx"
	l.from_scale = old_scale
	l._on_done = on_done
	sp.add_child(l)
	sp.move_child(l, sp.sprite.get_index())  # 插在身体前面：整层画在本体之后
	l.tick(0.0)
	return l


## 跳过／取消：立即收尾
static func cancel(sp: XBattlerSprite) -> void:
	var l := layer_of(sp)
	if l != null:
		l.finish()


static func _tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		var t: Texture2D = null
		if name == "human":
			var p := XDB.img_path("sv_actors", "Codex_Mira_SV_u2")
			if p != "" and ResourceLoader.exists(p):
				var at := AtlasTexture.new()
				at.atlas = XAppearance.kept_load(p)
				at.region = HUMAN_CELL
				t = at
		else:
			var p := DRAGON_TEX if name == "dragon" else DIR + name + ".png"
			t = XAppearance.kept_load(p) if ResourceLoader.exists(p) else null
		_tex_cache[name] = t
	return _tex_cache[name]


static func smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## 相邻关键帧 smoothstep 插值；rows 每行 [毫秒, 值…]，cols 是要取的列。区间外取端点
static func interp(t: float, rows: Array, cols: Array) -> Array:
	var pick := func(r: Array) -> Array: return cols.map(func(c): return float(r[c]))
	if t <= float(rows[0][0]):
		return pick.call(rows[0])
	for i in range(rows.size() - 1):
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		if t <= float(b[0]):
			var f := smooth((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001))
			var out := []
			for c in cols:
				out.append(float(a[c]) + (float(b[c]) - float(a[c])) * f)
			return out
	return pick.call(rows[rows.size() - 1])


## 此刻的身体：[姿势, 下一姿势（不淡化时空串）, 下一姿势的权重 0～1]
static func pose_at(t: float) -> Array:
	var idx := 0
	for i in KEYS.size():
		if float(KEYS[i][0]) <= t:
			idx = i
	var name: String = KEYS[idx][1]
	if idx + 1 < KEYS.size() and KEYS[idx + 1][1] != name:
		var nxt: float = float(KEYS[idx + 1][0])
		var left := maxf(float(KEYS[idx][0]), nxt - (DRAGON_FADE_MS if nxt >= DRAGON_FADE_FROM else POSE_FADE_MS))
		if t >= left:
			return [name, KEYS[idx + 1][1], smooth((t - left) / maxf(nxt - left, 0.0001))]
	return [name, "", 0.0]


## 此刻的身体脚点（素材像素，原点＝最终脚点；取整）
static func body_point(t: float) -> Vector2:
	var v := interp(t, KEYS, [2, 3])
	return Vector2(roundf(v[1]), roundf(-v[0]))


## 第 i 层火屑此刻 [显示, 透明度, 缩放, 位置]
static func flame_at(i: int, t: float) -> Array:
	var keys: Array = FLAMES[i][2]
	if t < float(keys[0][0]) or t > float(keys[keys.size() - 1][0]):
		return [false, 0.0, 1.0, Vector2.ZERO]
	var v := interp(t, keys, [1, 2, 3, 4])
	var p := body_point(t)
	if FLAMES[i][1] == "ground":
		p.y = 0.0
	return [true, v[0], v[1], p + Vector2(v[2], v[3])]


## 这一层此刻的缩放：人形身体缩放 → 黑龙身体缩放（实时取精灵的，落地后与本体一致）
func scale_at(t: float, to_scale: float) -> float:
	return lerpf(from_scale, to_scale, smooth(t / SETTLE_MS))


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for f in FLAMES:
		var s := Sprite2D.new()
		s.centered = true
		s.visible = false
		s.texture = _tex(f[0])
		add_child(s)
		_fx.append(s)
	_a = Sprite2D.new()
	_b = Sprite2D.new()
	for s in [_a, _b]:
		s.centered = false
		s.visible = false
		add_child(s)


func _process(delta: float) -> void:
	if not done:
		tick(delta * 1000.0 * speed_mult())


func _notification(what: int) -> void:
	# 精灵或战斗画面被释放（挪父节点不算）：回调照样调一次；本体跟着一起释放，不用恢复
	if what == NOTIFICATION_PREDELETE and not done:
		done = true
		elapsed = DURATION
		if _on_done.is_valid():
			_on_done.call()


## 推进 ms 毫秒（已乘战斗动画倍速）
func tick(ms: float) -> void:
	if done:
		return
	var sp := get_parent() as XBattlerSprite
	if sp == null or not animate_on() or not XMira.LIFT_ART or bool(sp.view.get("dead", sp.battler.is_dead())) \
			or not sp._look_key.contains("|form:MiraDragon"):
		finish()
		return
	elapsed = minf(elapsed + maxf(ms, 0.0), DURATION)
	if elapsed >= DURATION:
		finish()
		return
	_draw_at(sp, elapsed)


func _draw_at(sp: XBattlerSprite, t: float) -> void:
	var s := scale_at(t, sp.body_scale)
	scale = Vector2(s, s)
	position = sp.sprite.position  # 本体的位置（平时 0；浮空等改的是它）
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if XBattlerSprite.SV_NORM_SMOOTH and s < 1.0 else CanvasItem.TEXTURE_FILTER_NEAREST
	for i in _fx.size():
		var f := flame_at(i, t)
		var spr: Sprite2D = _fx[i]
		spr.visible = f[0] and f[1] > 0.0
		if spr.visible:
			spr.modulate.a = f[1]
			spr.scale = Vector2(f[2], f[2])
			spr.position = f[3]
	var body_on := t < SETTLE_MS
	sp.sprite.visible = not body_on and not sp.anim_hidden  # 与 set_anim_hidden 不互相覆盖（P3）
	visible = not sp.anim_hidden
	_a.visible = body_on
	_b.visible = false
	if body_on:
		var pose := pose_at(t)
		var at := body_point(t)
		_put(_a, pose[0], at, 1.0 - float(pose[2]) if pose[1] != "" else 1.0)
		if pose[1] != "":
			_b.visible = true
			_put(_b, pose[1], at, float(pose[2]))


## 变身层此刻是否自己在画身体（是的话本体该藏）
func body_shown() -> bool:
	return not done and elapsed < SETTLE_MS


func _put(s: Sprite2D, pose: String, at: Vector2, alpha: float) -> void:
	s.texture = _tex(pose)
	s.offset = -(HUMAN_ANCHOR if pose == "human" else POSE_ANCHOR)
	s.position = at
	s.modulate.a = alpha


## 收尾（放完、跳过、取消、释放都走这里）：钳到 2320、清掉整层、本体显示原样黑龙、完成回调只调一次
func finish(free_now := true) -> void:
	if done:
		return
	done = true
	elapsed = DURATION
	for c in get_children():
		(c as CanvasItem).visible = false
	var sp := get_parent() as XBattlerSprite
	if sp != null and is_instance_valid(sp.sprite):
		sp.sprite.visible = not sp.anim_hidden
	if free_now:
		name = "MiraLiftFx_done"  # layer_of 不再找到它
		queue_free()
	if _on_done.is_valid():
		_on_done.call()
