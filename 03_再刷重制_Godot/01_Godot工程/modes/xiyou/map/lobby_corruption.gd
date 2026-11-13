class_name XLobbyCorruption
extends Node2D
## 方桌大厅「初步异化」叠加层（重制版新增，设计稿：私密仓库 重制设定/重制版_大厅初步异化设计稿_v0.1.md，Kyo 11-11 批）。
## 时空漩涡二阶起大厅进入「侵染」：只在漩涡周围 6 格里出现裂纹、褪色、浮砖、光尘、人物染紫、低鸣与滴水，
## 6 位 NPC 与镜子各追加一句（每存档一次），空地上 3 处可调查，进大厅偶尔飘一行小字。
##
## 只叠不改：不写 Map004 的事件表与图块，不改通行、不改原事件的指令；阶段一（或开关关掉）时整层一个节点都不建。
## 浮砖、粒子、气泡、小字都不进存档、不用战斗随机数（自己的 RandomNumberGenerator）。
## 存档里只多一个 flags 键（FLAG_KEY）：说过的话、查过的裂纹、见过的最高阶；旧档没有这个键时当作都没说过。
##
## 阶段统一从 XRift.stage() 读（漩涡二阶段车道的类，按全局类表动态取，两边谁先合进来都能编译）；
## 没有 XRift 时按 FALLBACK_STAGE。测试用 STAGE_OVERRIDE 指定。
## 回退开关 ENABLED = false（O-311）：即使阶段是 2，大厅也回到阶段一的样子（漩涡本体的二阶不受影响）。

## O-311：大厅初步异化叠加层；false 回到阶段一的大厅。
static var ENABLED := true
## 测试用：> 0 时直接当作这个阶段
static var STAGE_OVERRIDE := 0
## 没有 XRift（漩涡二阶段还没合进来）时的阶段：本次整包定 2
const FALLBACK_STAGE := 2
const MAP_ID := 4
const TS := 48
## 漩涡中心格（EV75 时空漩涡_1；二阶时左右各多一格挡路，见 VORTEX_CELLS）
const CENTER := Vector2i(14, 19)
## 漩涡二阶段车道占用的格子（漩涡与两侧挡路），本层不碰
const VORTEX_CELLS := [Vector2i(13, 19), Vector2i(14, 19), Vector2i(15, 19)]
const RADIUS := 6.0
## 存档 flags 里的键：{"said": [事件号字符串], "crack": 查过裂纹的次数, "maxStage": 见过的最高阶}
const FLAG_KEY := "_remakeLobbyCorruption"
## 漩涡紫
const PURPLE := Color(0.56, 0.36, 0.92)
const CRACK_DARK := Color(0.09, 0.02, 0.13)
## 正式美术（Codex 11-11 原创，content/lobby/）：有图用图，没图（或测试置空）照旧程序画
static var CRACK_TEX := "res://content/lobby/crack_stage2.png"
static var CRACK_GLOW_TEX := "res://content/lobby/crack_stage2_glow.png"
static var SCALE_TEX := "res://content/lobby/canglong_scale.png"

## 原事件跑完后追加的一句：事件号 → [脸图, 脸号, 名字, 文字]（名字空＝旁白）
const AFTER_LINES := {
	50: ["", 0, "讨债人", "地上那个？不归我管。它不欠账，它是来收账的。"],
	51: ["", 0, "小讨债人", "呜……那个圈圈，刚才是不是变大了……"],
	52: ["", 0, "小讨债人", "不要看它……看久了，它也看你……"],
	7: ["People12", 6, "大工匠", "先说好，地砖不是我弄裂的。我补过了，第二天又裂回原样。"],
	43: ["", 4, "动保协会成员", "最近的奇珍异兽都不肯靠近大厅中间。我也不肯。"],
	24: ["Nature", 1, "猫哥", "……\n（它没醒，耳朵却一直朝着大厅中间。）"],
	21: ["", 0, "", "……镜子里的你，好像慢了半拍。"],
}
## 偶尔冒气泡的人：讨债人两个小弟、猫哥。气泡号：6 汗滴、8 省略号
const BUBBLE_EVENTS := [51, 52, 24]
const BUBBLE_IDS := [6, 8]
## 可调查格（踩在上面按确认键）
const CRACK_CELL := Vector2i(14, 22)
const FIXED_FLOAT := Vector2i(11, 17)
const CRACK_TEXTS := ["地砖裂了一道缝。缝里不是土，是很深的颜色。", "你把手伸过去。缝里是凉的，有风。"]
const FLOAT_TEXT := "这块地砖浮起来一指高。按下去，它又慢慢浮回来。"
const SCALE_TEXT := "一片青色的鳞，还是温的。"
## 苍龙破晓落点（XRift.canglong_drop_cell 没给时）：漩涡正南两格
const FALLBACK_DROP := Vector2i(14, 21)
## 进大厅时飘的小字（两成概率、两次至少隔 10 分钟、轮着出）
const AMBIENT_LINES := ["地面轻轻震了一下。", "远处有水声。大厅里没有水。", "你的影子比你先停下。",
	"有人在数数。数得很慢。", "灯没有灭，只是暗了一点。", "背包里的东西，好像挪过位置。"]
const AMBIENT_CHANCE := 0.2
const AMBIENT_GAP_MS := 10 * 60 * 1000
const AMBIENT_SECONDS := 2.5
const MAX_MOTES := 28
const HUM_FAR := 9.0
const HUM_NEAR := 2.0
const HUM_MAX := 0.3

static var _rift_script: Variant = false   # false 未查；null 没有 XRift；否则脚本
static var _ambient_last_ms := -AMBIENT_GAP_MS
static var _ambient_index := 0

var host: XMapScene
var rng := RandomNumberGenerator.new()
var floats: Array[Vector2i] = []
var _float_lift := {}        # 格 → 当前抬起像素
var _t := 0.0
var _cracks: Array = []      # [PackedVector2Array]
var _crack_base: Node2D
var _crack_glow: Node2D
var _desat: Sprite2D
var _floats_node: Node2D
var _motes_node: Node2D
var _motes: Array = []       # {p: Vector2, v: Vector2, a: float, r: float, bright: bool, life: float}
var _next_bright := 0.0
var _scale_node: Node2D
var _scale_cell := Vector2i(-1, -1)
var _scale_tex: Texture2D
var _hum: AudioStreamPlayer
var _drip: AudioStreamPlayer2D
var _thud: AudioStreamPlayer
var _next_drip := 0.0
var _next_bubble := 0.0
var _ambient: Label
var _tinted: Array = []


## 当前阶段（1 或 2…）：开关关掉时当作 1
static func stage() -> int:
	if STAGE_OVERRIDE > 0:
		return STAGE_OVERRIDE
	var scr = _rift()
	if scr != null:
		return int(scr.call("stage"))
	return FALLBACK_STAGE


## 大厅要不要叠这一层
static func active() -> bool:
	return ENABLED and stage() >= 2


static func _rift() -> Variant:
	if _rift_script is bool:
		_rift_script = null
		for c in ProjectSettings.get_global_class_list():
			if str(c.get("class", "")) == "XRift":
				var scr = load(str(c.path))
				if scr != null and scr.get_script_method_list().any(func(m): return m.name == "stage"):
					_rift_script = scr
				break
	return _rift_script


## 苍龙破晓被甩出的落点（青色的鳞放这里）
static func drop_cell() -> Vector2i:
	var scr = _rift()
	if scr != null and scr.get_script_method_list().any(func(m): return m.name == "canglong_drop_cell"):
		return scr.call("canglong_drop_cell")
	return FALLBACK_DROP


## 苍龙破晓过场播过没有（rift2，跨存档记在配置）
static func canglong_dropped() -> bool:
	return XConfig.whisper_seen("rift2")


## 存档里本层的记录（没有就建）
static func record(s: XState) -> Dictionary:
	if not s.flags.get(FLAG_KEY) is Dictionary:
		s.flags[FLAG_KEY] = {"said": [], "crack": 0, "maxStage": 1}
	var r: Dictionary = s.flags[FLAG_KEY]
	if not r.get("said") is Array:
		r["said"] = []
	return r


## 画面特效（设置页「画面特效」）：关掉时不放粒子、不飘小字
static func fx_on() -> bool:
	return XGraphics.fx_on()  # 「画面特效」开着且没开省电模式


func setup(map: XMapScene) -> void:
	host = map
	name = "LobbyCorruption"
	z_index = -9   # 在下层图块（-10）之上、人物（0）之下
	rng.randomize()
	var s := XState.current
	if s:
		var r := record(s)
		r["maxStage"] = maxi(int(r.get("maxStage", 1)), stage())
	_build_desat()
	_build_cracks()
	_pick_floats()
	_floats_node = _layer(_draw_floats)
	_scale_node = _layer(_draw_scale)
	if SCALE_TEX != "" and ResourceLoader.exists(SCALE_TEX):
		_scale_tex = load(SCALE_TEX)
	_motes_node = _layer(_draw_motes)
	_build_audio()
	_next_drip = rng.randf_range(60.0, 90.0)
	_next_bubble = rng.randf_range(20.0, 60.0)
	_next_bright = rng.randf_range(20.0, 30.0)
	_maybe_ambient.call_deferred()


func _exit_tree() -> void:
	for c in _tinted:
		if is_instance_valid(c):
			c.self_modulate = Color.WHITE
	_tinted.clear()
	if is_instance_valid(_ambient):
		_ambient.queue_free()


static func cell_px(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * TS, (c.y + 0.5) * TS)


func _layer(cb: Callable) -> Node2D:
	var n := Node2D.new()
	n.draw.connect(cb)
	add_child(n)
	return n


# ---- 地面：褪色、裂纹、浮砖 ----

func _build_desat() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.88, 0.87, 0.9))
	g.set_color(1, Color.WHITE)
	g.add_point(0.5, Color(0.94, 0.935, 0.95))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = int(RADIUS * 2 * TS)
	tex.height = int(RADIUS * 2 * TS)
	_desat = Sprite2D.new()
	_desat.texture = tex
	_desat.position = cell_px(CENTER)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_desat.material = m
	add_child(_desat)


## 裂纹：固定种子，从漩涡边缘向外辐射，最长 3 格；正南那条固定通到可调查的裂缝格
func _build_cracks() -> void:
	# 正式贴花：336×336（7×7 格），图心对准漩涡中心；微光层单独一张，跟程序画法一样 6 秒呼吸
	if CRACK_TEX != "" and ResourceLoader.exists(CRACK_TEX):
		_crack_glow = Node2D.new()
		if CRACK_GLOW_TEX != "" and ResourceLoader.exists(CRACK_GLOW_TEX):
			var g := Sprite2D.new()
			g.texture = load(CRACK_GLOW_TEX)
			g.position = cell_px(CENTER)
			_crack_glow.add_child(g)
		add_child(_crack_glow)
		_crack_base = Node2D.new()
		var b := Sprite2D.new()
		b.texture = load(CRACK_TEX)
		b.position = cell_px(CENTER)
		_crack_base.add_child(b)
		add_child(_crack_base)
		return
	var r := RandomNumberGenerator.new()
	r.seed = 0x51A7
	var c := cell_px(CENTER)
	var n := 11
	for i in n:
		var ang := TAU * i / n + r.randf_range(-0.2, 0.2)
		var length := r.randf_range(1.2, 2.6) * TS
		var line := _crack_line(r, c, ang, 1.15 * TS, length)
		_cracks.append(line)
		# 一半的裂纹中途分一小叉
		if r.randf() < 0.5 and line.size() > 4:
			var at := line[line.size() / 2]
			_cracks.append(_crack_line(r, at, ang + r.randf_range(0.5, 0.9) * (1 if r.randf() < 0.5 else -1), 0.0, r.randf_range(0.3, 0.6) * TS))
	# 最长的一道：正南到 (14,22)
	_cracks.append(_crack_line(r, c, PI / 2, 1.1 * TS, (CRACK_CELL.y - CENTER.y) * TS - 0.6 * TS))
	_crack_glow = _layer(_draw_cracks.bind(true))
	_crack_base = _layer(_draw_cracks.bind(false))


func _crack_line(r: RandomNumberGenerator, c: Vector2, ang: float, start: float, length: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var d := start
	var a := ang
	pts.append(c + Vector2.from_angle(a) * d)
	while d < start + length:
		d += r.randf_range(6.0, 11.0)
		a = ang + r.randf_range(-0.09, 0.09)
		pts.append(c + Vector2.from_angle(a) * minf(d, start + length) + Vector2(r.randf_range(-1.2, 1.2), r.randf_range(-1.2, 1.2)))
	return pts


func _draw_cracks(glow: bool) -> void:
	var n := _crack_glow if glow else _crack_base
	for pts in _cracks:
		if glow:
			n.draw_polyline(pts, Color(PURPLE, 0.3), 3.5, true)
		else:
			n.draw_polyline(pts, Color(CRACK_DARK, 0.85), 1.5, true)


## 浮砖：固定一块 (11,17)，另随机 1～2 块；避开漩涡、弹回落点那条十字、可调查格、苍龙落点、有事件的格和走不了的格
func _pick_floats() -> void:
	floats.clear()
	if float_ok(FIXED_FLOAT):
		floats.append(FIXED_FLOAT)
	var cand: Array[Vector2i] = []
	for y in range(CENTER.y - 6, CENTER.y + 7):
		for x in range(CENTER.x - 6, CENTER.x + 7):
			var c := Vector2i(x, y)
			if c != FIXED_FLOAT and float_ok(c):
				cand.append(c)
	var want := rng.randi_range(1, 2)
	while want > 0 and not cand.is_empty():
		var c: Vector2i = cand.pop_at(rng.randi_range(0, cand.size() - 1))
		if floats.all(func(f): return absi(f.x - c.x) + absi(f.y - c.y) > 2):
			floats.append(c)
			want -= 1
	for f in floats:
		_float_lift[f] = 6.0


func float_ok(c: Vector2i) -> bool:
	var d := Vector2(c - CENTER).length()
	if d < 2.0 or d > RADIUS - 0.8:
		return false
	# 漩涡上下左右的弹回路线与苍龙走位（竖 x 12～16、横 y 18～20）
	if (c.x >= CENTER.x - 2 and c.x <= CENTER.x + 2) or (c.y >= CENTER.y - 1 and c.y <= CENTER.y + 1):
		return false
	if c == CRACK_CELL or c == drop_cell():
		return false
	if host == null or host.lower == null or not host.lower.is_valid(c):
		return false
	if not [2, 4, 6, 8].any(func(dir): return host.lower.is_passable(c.x, c.y, dir)):
		return false
	return not host.events.any(func(e): return is_instance_valid(e) and e.grid == c)


func _occupied(c: Vector2i) -> bool:
	if host.player and host.player.grid == c:
		return true
	return host.followers.any(func(f): return is_instance_valid(f) and f.visible and f.grid == c)


func _draw_floats() -> void:
	var tm := host.lower
	if tm == null:
		return
	var prev := tm._canvas
	tm._canvas = _floats_node
	for f in floats:
		var lift: float = _float_lift.get(f, 0.0)
		var p := Vector2(f * TS)
		# 底下一小圈影子
		_floats_node.draw_set_transform(p + Vector2(TS / 2.0, TS - 6), 0.0, Vector2(1.0, 0.3))
		_floats_node.draw_circle(Vector2.ZERO, TS * 0.42, Color(0, 0, 0, 0.12 + lift * 0.03))
		_floats_node.draw_set_transform(Vector2.ZERO)
		for id in tm._tiles_at(f.x, f.y):
			if id > 0:
				tm._draw_id(id, int(p.x), int(p.y - roundf(lift)))
	tm._canvas = prev


# ---- 青色的鳞 ----

func _draw_scale() -> void:
	if _scale_cell.x < 0:
		return
	var p := cell_px(_scale_cell) + Vector2(0, 8)
	if _scale_tex != null:
		_scale_node.draw_texture(_scale_tex, p - _scale_tex.get_size() / 2.0)
		return
	var shine := 0.5 + 0.5 * sin(_t * 2.0)
	_scale_node.draw_set_transform(p, -0.5, Vector2(1.0, 0.62))
	_scale_node.draw_circle(Vector2.ZERO, 7.0, Color(0.18, 0.66, 0.68))
	_scale_node.draw_circle(Vector2(-2, -2), 3.5, Color(0.55, 0.92, 0.88, 0.5 + 0.4 * shine))
	_scale_node.draw_set_transform(Vector2.ZERO)


## 测试看：裂纹用的是不是正式贴花
func crack_textured() -> bool:
	return _crack_base != null and _crack_base.get_child_count() > 0


func scale_cell() -> Vector2i:
	return _scale_cell


# ---- 光尘 ----

func _spawn_mote(bright := false) -> Dictionary:
	var c := cell_px(CENTER)
	if bright:
		var a := rng.randf() * TAU
		return {"p": c, "v": Vector2.from_angle(a) * 22.0, "a": 0.9, "r": 2.6, "bright": true, "life": 2.0 * TS / 22.0}
	var ang := rng.randf() * TAU
	var dist := rng.randf_range(1.6, RADIUS) * TS
	return {"p": c + Vector2.from_angle(ang) * dist, "v": Vector2.ZERO, "a": rng.randf_range(0.3, 0.55),
		"r": rng.randf_range(1.5, 2.6), "bright": false, "life": 0.0}


func _update_motes(dt: float) -> void:
	if not fx_on():
		_motes.clear()
		return
	while _motes.size() < MAX_MOTES - 1:
		_motes.append(_spawn_mote())
	var c := cell_px(CENTER)
	for i in range(_motes.size() - 1, -1, -1):
		var m: Dictionary = _motes[i]
		if m.bright:
			m.p += m.v * dt
			m.life -= dt
			m.a = clampf(m.life, 0.0, 0.9)
			if m.life <= 0.0:
				_motes.remove_at(i)
			continue
		var to: Vector2 = c - m.p
		var d: float = to.length()
		if d < 0.8 * TS:
			_motes[i] = _spawn_mote()
			continue
		m.v = m.v.lerp(to.normalized() * lerpf(10.0, 26.0, 1.0 - d / (RADIUS * TS)) + Vector2(0, -3), clampf(dt * 2.0, 0.0, 1.0))
		m.p += m.v * dt
	_next_bright -= dt
	if _next_bright <= 0.0:
		_next_bright = rng.randf_range(20.0, 30.0)
		_motes.append(_spawn_mote(true))


func _draw_motes() -> void:
	var c := cell_px(CENTER)
	for m in _motes:
		var fade := 1.0 if m.bright else clampf((Vector2(m.p).distance_to(c) - 0.8 * TS) / TS, 0.0, 1.0)
		var col := Color(0.85, 0.75, 1.0) if m.bright else PURPLE.darkened(0.15)   # 白色大理石上浅紫看不见，用深一点的紫
		if m.bright:
			_motes_node.draw_circle(m.p, m.r * 2.4, Color(PURPLE, m.a * 0.25))
		_motes_node.draw_circle(m.p, m.r, Color(col, m.a * fade))


func mote_count() -> int:
	return _motes.size()


# ---- 声音 ----

func _build_audio() -> void:
	_hum = AudioStreamPlayer.new()
	XAudio.bind(_hum, "BGS")
	var hp := XDB.audio_path("bgs", "Darkness")
	if hp != "":
		var st = load(hp)
		if st is AudioStreamOggVorbis:
			st = st.duplicate()
			st.loop = true
		_hum.stream = st
	_hum.pitch_scale = 0.7
	_hum.volume_db = -80.0
	add_child(_hum)
	_drip = AudioStreamPlayer2D.new()
	_drip.bus = XAudio.bus("BGS")
	var dp := XDB.audio_path("bgs", "Drips")
	if dp != "":
		_drip.stream = load(dp)
	_drip.position = cell_px(CENTER)
	_drip.volume_db = linear_to_db(0.18)
	_drip.max_distance = 1600.0
	add_child(_drip)
	_thud = AudioStreamPlayer.new()
	XAudio.bind(_thud, "SE")
	var tp := XDB.audio_path("se", "Earth2")
	if tp != "":
		_thud.stream = load(tp)
	_thud.pitch_scale = 0.7
	_thud.volume_db = linear_to_db(0.5)
	add_child(_thud)
	if host.has_signal("screen_shaken"):
		host.screen_shaken.connect(_on_shake)


## 漩涡低鸣的音量（线性，0～HUM_MAX）：9 格外 0，2 格内最大；漩涡过场、战斗中让路
func hum_level() -> float:
	if host.player == null or host._in_battle or rift_event_running():
		return 0.0
	var d := (host.player.real + Vector2(0.5, 0.5)).distance_to(Vector2(CENTER) + Vector2(0.5, 0.5))
	return HUM_MAX * clampf((HUM_FAR - d) / (HUM_FAR - HUM_NEAR), 0.0, 1.0)


func rift_event_running() -> bool:
	if not host.busy or host.running_event_id <= 0:
		return false
	for ev in host.map_data.get("events", []):
		if ev is Dictionary and int(ev.id) == host.running_event_id:
			return str(ev.get("name", "")).begins_with("时空漩涡_")
	return false


func _update_audio(dt: float) -> void:
	var lv := hum_level()
	if _hum.stream != null:
		if lv <= 0.001:
			if _hum.playing:
				_hum.stop()
		else:
			if not _hum.playing:
				_hum.play()
			_hum.volume_db = lerpf(_hum.volume_db, linear_to_db(lv), clampf(dt * 3.0, 0.0, 1.0))
	_next_drip -= dt
	if _next_drip <= 0.0:
		_next_drip = rng.randf_range(60.0, 90.0)
		if _drip.stream != null and not host._in_battle and not rift_event_running():
			_drip.play(rng.randf_range(0.0, maxf(0.0, _drip.stream.get_length() - 1.0)))
			get_tree().create_timer(0.6).timeout.connect(_stop_drip)


func _stop_drip() -> void:
	if is_instance_valid(_drip):
		_drip.stop()


## 调查漩涡被弹回时（EV75 的震屏）多垫一声闷响
func _on_shake() -> void:
	if _thud.stream != null and rift_event_running():
		_thud.play()


# ---- 人物染紫、气泡 ----

func _update_tint() -> void:
	var chars: Array = [host.player] + host.followers
	for c in chars:
		if not is_instance_valid(c):
			continue
		var d: float = (c.real + Vector2(0.5, 0.5)).distance_to(Vector2(CENTER) + Vector2(0.5, 0.5))
		var k := clampf((2.5 - d) / 1.5, 0.0, 1.0) * 0.15
		var col := Color.WHITE.lerp(PURPLE, k)
		if c.self_modulate != col:
			c.self_modulate = col
			if not _tinted.has(c):
				_tinted.append(c)


func _update_bubbles(dt: float) -> void:
	_next_bubble -= dt
	if _next_bubble > 0.0:
		return
	_next_bubble = rng.randf_range(60.0, 120.0)
	if not quiet():
		return
	var id: int = BUBBLE_EVENTS[rng.randi_range(0, BUBBLE_EVENTS.size() - 1)]
	for e in host.events:
		if is_instance_valid(e) and e.event_id == id and not e.erased and e.character_name != "" and host.near_screen(e):
			e.start_balloon(BUBBLE_IDS[rng.randi_range(0, BUBBLE_IDS.size() - 1)])


## 地图上没有事件、窗口、菜单、战斗、别的页面
func quiet() -> bool:
	return not host.busy and not host._menu_open and not host._in_battle and host.transfer_page == null and not host.scene_page_open()


# ---- 氛围小字 ----

func _maybe_ambient() -> void:
	if not fx_on() or Time.get_ticks_msec() - _ambient_last_ms < AMBIENT_GAP_MS:
		return
	if rng.randf() >= AMBIENT_CHANCE:
		return
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree() or not quiet():
		return
	show_ambient()


func show_ambient() -> Label:
	_ambient_last_ms = Time.get_ticks_msec()
	var text: String = AMBIENT_LINES[_ambient_index % AMBIENT_LINES.size()]
	_ambient_index += 1
	if is_instance_valid(_ambient):
		_ambient.queue_free()
	_ambient = Label.new()
	_ambient.text = text
	_ambient.add_theme_font_override("font", XUI.font())
	_ambient.add_theme_font_size_override("font_size", 22)
	_ambient.add_theme_color_override("font_color", Color(0.72, 0.72, 0.76))
	_ambient.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_ambient.add_theme_constant_override("outline_size", 4)
	_ambient.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ambient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ambient.position = Vector2(0, 640)
	_ambient.size = Vector2(1280, 40)
	_ambient.modulate.a = 0.0
	host.ui.add_child(_ambient)
	var tw := _ambient.create_tween()
	tw.tween_property(_ambient, "modulate:a", 1.0, 0.4)
	tw.tween_interval(AMBIENT_SECONDS - 0.8)
	tw.tween_property(_ambient, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_ambient.queue_free)
	return _ambient


# ---- 每帧 ----

func _process(dt: float) -> void:
	if host == null or not is_instance_valid(host):
		return
	_t += dt
	_crack_glow.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * TAU / 6.0))
	var moved := false
	for f in floats:
		var target := 0.0 if _occupied(f) else 6.0 + 1.5 * sin(_t * TAU / 4.0 + f.x)
		var cur: float = _float_lift[f]
		var nv := move_toward(cur, target, dt * (40.0 if target < cur - 2.0 else 3.0))
		if absf(nv - cur) > 0.01:
			_float_lift[f] = nv
			moved = true
	if moved:
		_floats_node.queue_redraw()
	var want_scale := drop_cell() if canglong_dropped() else Vector2i(-1, -1)
	if want_scale != _scale_cell:
		_scale_cell = want_scale
	if _scale_cell.x >= 0:
		_scale_node.queue_redraw()
	_update_motes(dt)
	_motes_node.queue_redraw()
	_update_audio(dt)
	_update_tint()
	_update_bubbles(dt)


# ---- 追加台词与调查 ----

## 这次确认键启动的事件跑完后要不要追加一句（启动前判定：事件在表里、当前页有内容、本存档还没说过）
func wants_after(e: MVEvent) -> bool:
	if not AFTER_LINES.has(e.event_id) or e.command_list().size() <= 1:
		return false
	var s := XState.current
	return s != null and not (record(s).said as Array).has(str(e.event_id))


func after_event(event_id: int) -> void:
	var s := XState.current
	if s == null or not AFTER_LINES.has(event_id):
		return
	var said: Array = record(s).said
	if said.has(str(event_id)):
		return
	said.append(str(event_id))
	var row: Array = AFTER_LINES[event_id]
	await host.run_command_list(text_list(row[0], row[1], row[2], row[3]))


static func text_list(face: String, idx: int, who: String, text: String) -> Array:
	var list := [{"code": 101, "indent": 0, "parameters": [face, idx, 0, 2, ""]}]
	var lines := text.split("\n")
	for i in lines.size():
		var line := lines[i]
		if i == 0 and who != "":
			line = "\\n<%s>%s" % [who, line]
		list.append({"code": 401, "indent": 0, "parameters": [line]})
	list.append({"code": 0, "indent": 0, "parameters": []})
	return list


## 确认键：玩家脚下是可调查格就显示文字，返回是否处理了
func on_action(cell: Vector2i) -> bool:
	var text := ""
	if cell == CRACK_CELL:
		var r := record(XState.current)
		text = CRACK_TEXTS[mini(int(r.get("crack", 0)), 1)]
		r["crack"] = int(r.get("crack", 0)) + 1
	elif cell == FIXED_FLOAT and floats.has(FIXED_FLOAT):
		text = FLOAT_TEXT
	elif _scale_cell.x >= 0 and cell == _scale_cell:
		text = SCALE_TEXT
	if text == "":
		return false
	await host.run_command_list(text_list("", 0, "", text))
	return true


func is_investigation(cell: Vector2i) -> bool:
	return cell == CRACK_CELL or (cell == FIXED_FLOAT and floats.has(FIXED_FLOAT)) or (_scale_cell.x >= 0 and cell == _scale_cell)
