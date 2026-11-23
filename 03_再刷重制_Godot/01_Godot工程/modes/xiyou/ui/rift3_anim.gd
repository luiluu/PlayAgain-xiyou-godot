class_name XRift3Anim
extends CanvasLayer
## 【小A·未经审查】二阶到三阶徐凤年回归漫画动画播放器与实时视觉特效（T425 拆卡 2 ＋ T428 拆卡 3；分镜 v0.5 定稿）。
## - 全片 26.0 秒、四段状态机：P1 实时入格（0.0–2.6s）→ P2～P9 离线 .ogv（2.6–15.0s）→
##   P10 实时劈页（15.0–17.3s）→ P11 破框残格三连对白与碎页收尾（17.3–26.0s）。
## - P1 实时入格：截取当前 Map004 视口经 comic_halftone.gdshader（兼容 gl_compatibility）转黑白半调网点
##   并保留中心漩涡微紫点缀，0.0–0.30s 由全屏微弹收束入左格 (48,56,560×440)，随后 1.00×→1.04× 缓推。
## - P10 实时劈页：两块 Polygon2D 沿右上→左下斜线切开 P9 尾帧画页，0.10s 反色冲击帧＋12px 震屏＋白光与朱红残影，
##   随后两半滑开实时透出真实 Map004，CPUParticles2D（96 片，连同 P11d 20 片共 116 ≤ 120）碎纸飞溅＋M6 透明挥斩掠散紫烟。
## - P11 破框残格与退场：左侧斜切破边漫画残格复用 M5a（1.00×→1.03× 缓推），右侧白底黑粗框尖尾气泡＋左上常驻朱红名签
##   连播三句（P11b 21.2s 仅框边单拍 2px 紫闪，正文绝不变紫），24.7s 残格碎纸（20 片）飘散＋底部 #DCDCE0 旁白条收尾无残留。
## - 资源守卫 available()、抗变速齿轮真实秒计时、0.8s 保护期跳过与 missed_lines 补播均保持 T425 口径不变。

signal finished

## 回退总开关：false 时 available() 恒为 false（兼容拆卡 5 在 XRift 增设 RIFT3_ANIM 开关）
static var ENABLED := true
## 跳过后待事件层补播的句键列表（按 LINE_ORDER 顺序）；每次开播前清空，自然播满 26.0s 为空
static var missed_lines: Array[String] = []
## 专项测试专用：覆盖资源存在性判定（默认空 Callable，走 ResourceLoader.exists）
static var _asset_exists_override: Callable = Callable()

const LAYER := 88                  # 盖过地图黑幕（80），位于 XMoviePlayer（89）／XToast（90）下方
const NODE_NAME := "XRift3Anim"
const STAGE_SIZE := Vector2(1280, 720)

const TOTAL_DURATION := 26.0
const PHASE_P1_END := 2.6
const PHASE_MID_END := 15.0
const PHASE_P10_END := 17.3
const PHASE_P11D_START := 24.7
const SKIP_GUARD_SEC := 0.8
const SKIP_FADE_SEC := 0.25
const END_FADE_SEC := 0.3

## P1 / P10 / P11 视觉参数与粒子硬上限（P10 96 ＋ P11d 20 = 116 <= 120）
const SHADER_HALFTONE := "res://modes/xiyou/ui/shaders/comic_halftone.gdshader"
const P1_TARGET_RECT := Rect2(48, 56, 560, 440)
const P1_SHRINK_SEC := 0.30
const P10_CUT_TOP_X := 1120.0
const P10_CUT_BOT_X := 160.0
const P10_SHARD_AMOUNT := 96
const P11_SHARD_AMOUNT := 20
const MAX_TOTAL_SHARDS := 120

## 4 个必需资源（全齐 available() 才为真）＋ 1 个可选同步音轨
const VIDEO_MID := "res://content/rift/rift3_comic_mid.ogv"
const TEX_M6_SLASH := "res://content/rift/rift3_m6_slash.webp"
const TEX_P9_END := "res://content/rift/rift3_p9_end.webp"
const TEX_M5A_PORTRAIT := "res://content/rift/rift3_m5a_portrait.webp"
const AUDIO_SFX := "res://content/rift/rift3_comic_sfx.ogg"
const REQUIRED_ASSETS: Array[String] = [
	VIDEO_MID,
	TEX_M6_SLASH,
	TEX_P9_END,
	TEX_M5A_PORTRAIT,
]

## 三色配色规范（黑白线稿网点／幽紫／朱红）＋ v0.5 审定 after 浅银白字色
const COLOR_INK := Color("0b0b0e")
const COLOR_PAPER := Color("f4f2ec")
const COLOR_GRAY_DARK := Color("6e6e75")
const COLOR_GRAY_LIGHT := Color("b8b8be")
const COLOR_AFTER_TEXT := Color("dcdce0")       # v0.5 第 7.1 节审定：P11d after 浅银白字色
const COLOR_PURPLE := Color(0.56, 0.36, 0.92)   # #8F5CEB，同 XLobbyCorruption.PURPLE
const COLOR_PURPLE_DARK := Color("341956")
const COLOR_PURPLE_BRIGHT := Color("c29bff")
const COLOR_CRIMSON := Color("c8282e")
const COLOR_CRIMSON_BRIGHT := Color("f04444")

enum Phase {
	P1 = 0,
	MID = 1,
	P10 = 2,
	P11 = 3,
}

const PHASE_NAMES := {
	Phase.P1: "P1",
	Phase.MID: "MID",
	Phase.P10: "P10",
	Phase.P11: "P11",
}

## 5 句定稿台词顺序与漫画内显示时段／已看全阈值（正文直读 XRift.RIFT3_LINES，零重复写死）
const LINE_ORDER: Array[String] = ["whisper", "sense", "hint", "follow", "after"]
const DIALOGUE_CUES: Array[Dictionary] = [
	{"key": "whisper", "start": 0.4,  "end": 2.4,  "seen_at": 2.2,  "style": "narration_p1",  "show_speaker": false},
	{"key": "sense",   "start": 17.4, "end": 19.7, "seen_at": 19.4, "style": "speech_bubble", "show_speaker": true},
	{"key": "hint",    "start": 19.9, "end": 22.4, "seen_at": 22.1, "style": "speech_bubble", "show_speaker": true},
	{"key": "follow",  "start": 22.6, "end": 24.6, "seen_at": 24.3, "style": "speech_bubble", "show_speaker": true},
	{"key": "after",   "start": 24.7, "end": 25.9, "seen_at": 25.7, "style": "narration_end", "show_speaker": false},
]

## 8 处漫画实时叠字时间码（v0.5 第 7.2 节 T426 正式定稿：7 处拟声字＋1 处刀意字「斩」）
const SFX_CUES: Array[Dictionary] = [
	{"id": "p2_hum",    "panel": "P2",  "kind": "sfx",   "text": "嗡——",   "start": 2.8,  "end": 4.3,   "pos": Vector2(920, 130), "size": 46, "color": COLOR_INK,   "outline": COLOR_PURPLE,      "rot_deg": -6.0},
	{"id": "p3_crack",  "panel": "P3",  "kind": "sfx",   "text": "咔嚓！", "start": 4.5,  "end": 6.1,   "pos": Vector2(860, 520), "size": 54, "color": COLOR_PAPER, "outline": COLOR_PURPLE,      "rot_deg": 5.0},
	{"id": "p4_rip",    "panel": "P4",  "kind": "sfx",   "text": "嘶啦！", "start": 6.3,  "end": 7.5,   "pos": Vector2(180, 170), "size": 52, "color": COLOR_PAPER, "outline": COLOR_PURPLE_DARK, "rot_deg": -10.0},
	{"id": "p5_boom",   "panel": "P5",  "kind": "sfx",   "text": "轰——！", "start": 7.7,  "end": 9.5,   "pos": Vector2(840, 470), "size": 64, "color": COLOR_INK,   "outline": COLOR_PAPER,       "rot_deg": -8.0},
	{"id": "p6_whoosh", "panel": "P6",  "kind": "sfx",   "text": "唰！",   "start": 9.65, "end": 10.45, "pos": Vector2(940, 100), "size": 50, "color": COLOR_PAPER, "outline": COLOR_CRIMSON,     "rot_deg": -14.0},
	{"id": "p8_zheng",  "panel": "P8",  "kind": "sfx",   "text": "铮！",   "start": 11.4, "end": 12.45, "pos": Vector2(160, 440), "size": 56, "color": COLOR_PAPER, "outline": COLOR_INK,         "rot_deg": -12.0},
	{"id": "p9_clang",  "panel": "P9",  "kind": "sfx",   "text": "锵——！", "start": 12.7, "end": 14.7,  "pos": Vector2(860, 130), "size": 62, "color": COLOR_PAPER, "outline": COLOR_INK,         "rot_deg": -6.0},
	{"id": "p10_slash", "panel": "P10", "kind": "blade", "text": "斩",     "start": 15.0, "end": 15.45, "pos": Vector2(560, 240), "size": 88, "color": COLOR_PAPER, "outline": COLOR_INK,         "rot_deg": -18.0},
]

## P2～P9 中段分格时间窗（无 .ogv 时的程序占位可视化用）
const MID_PANELS: Array[Dictionary] = [
	{"panel": "P2", "start": 2.6,  "end": 4.4,  "rect": Rect2(632, 56, 600, 440),  "accent": COLOR_PURPLE},
	{"panel": "P3", "start": 4.4,  "end": 6.2,  "rect": Rect2(48, 512, 1184, 168), "accent": COLOR_PURPLE_BRIGHT},
	{"panel": "P4", "start": 6.2,  "end": 7.6,  "rect": Rect2(80, 90, 1120, 540),  "accent": COLOR_PURPLE_DARK},
	{"panel": "P5", "start": 7.6,  "end": 9.6,  "rect": Rect2(260, 72, 760, 576),  "accent": COLOR_PURPLE},
	{"panel": "P6", "start": 9.6,  "end": 10.5, "rect": Rect2(340, 36, 880, 220),  "accent": COLOR_CRIMSON},
	{"panel": "P7", "start": 10.5, "end": 11.3, "rect": Rect2(370, 276, 540, 120), "accent": COLOR_PURPLE_BRIGHT},
	{"panel": "P8", "start": 11.3, "end": 12.5, "rect": Rect2(120, 412, 820, 276), "accent": COLOR_CRIMSON},
	{"panel": "P9", "start": 12.5, "end": 15.0, "rect": Rect2(60, 94, 1160, 532),  "accent": COLOR_CRIMSON_BRIGHT},
]

## P11 左侧破边漫画残格内轮廓（相对 480×440 容器：上/左规整，右侧带斜切撕裂缺口）
const P11_SHARD_INNER: Array[Vector2] = [
	Vector2(14, 14),
	Vector2(452, 10),
	Vector2(428, 126),
	Vector2(444, 152),
	Vector2(398, 294),
	Vector2(412, 322),
	Vector2(370, 426),
	Vector2(16, 422),
]
const P11_SHARD_OUTER: Array[Vector2] = [
	Vector2(7, 7),
	Vector2(461, 3),
	Vector2(436, 124),
	Vector2(453, 152),
	Vector2(406, 292),
	Vector2(421, 323),
	Vector2(376, 434),
	Vector2(9, 430),
]

static var _re_speaker: RegEx = null
static var _re_mv_code: RegEx = null
static var _invert_shader: Shader = null
static var _cached_shard_tex: Texture2D = null
static var _cached_p1_fallback_tex: Texture2D = null
static var _cached_p9_fallback_tex: Texture2D = null
static var _cached_m6_fallback_tex: Texture2D = null
static var _cached_m5a_fallback_tex: Texture2D = null

var _viewport_tex: Texture2D = null
var _placeholder_mode := false
var _t := 0.0
var _phase := Phase.P1
var _skipping := false
var _skipped := false
var _skip_time := -1.0
var _fade := 0.0
var _done := false
var _pressed := false
var _mid_started := false
var _active_dialogue_key := ""
var _active_dialogue_text := ""
var _active_dialogue_speaker := ""
var _active_panel := "P1"

var _p1_mix_amount := 0.0
var _p1_zoom := 1.0
var _p10_split_gap := 0.0
var _p10_shards_fired := false
var _p11_shards_fired := false
var _p11_last_bubble_key := ""

var _root: Control
var _stage_layer: Control

# P1 实时入格层
var _p1_layer: Control
var _p1_gutter: ColorRect
var _p1_frame: Panel
var _p1_tex_rect: TextureRect
var _p1_mat: ShaderMaterial

# MID 离线中段层
var _mid_layer: Control
var _video_player: VideoStreamPlayer
var _mid_placeholder_box: Panel
var _mid_placeholder_label: Label

# P10 实时劈页碎格层
var _p10_layer: Control
var _p10_end_rect: TextureRect       # 兼容保留资源承载节点（纹理同步至两半 Polygon2D）
var _p10_halves_root: Control
var _p10_half_tl: Polygon2D
var _p10_half_br: Polygon2D
var _p10_cut_tl_edge: Line2D
var _p10_cut_br_edge: Line2D
var _p10_half_mat: ShaderMaterial
var _p10_slash_bar: ColorRect        # 兼容保留，承担主白刀光芯
var _p10_slash_white_poly: Polygon2D
var _p10_slash_red_poly: Polygon2D
var _p10_purple_smoke: Control
var _p10_smoke_wisps: Array[Polygon2D] = []
var _p10_shards: CPUParticles2D
var _p10_slash_rect: TextureRect

# P11 破框残格三连对白与碎页收尾层
var _p11_layer: Control
var _p11_dim: ColorRect
var _p11_portrait_box: Panel         # 兼容保留（斜切破边残格容器，StyleBoxEmpty 无直角框）
var _p11_portrait_rect: TextureRect  # 兼容保留纹理载体（隐藏，实际经破边 Polygon2D 裁切绘制）
var _p11_portrait_poly: Polygon2D
var _p11_border_line: Line2D
var _p11_purple_edge: Line2D
var _p11_wind_lines: Array[Line2D] = []
var _p11_shards: CPUParticles2D

# 拟声字／刀意字叠字层
var _sfx_layer: Control
var _sfx_labels := {}                # cue id -> Label

# 对白气泡／旁白框层
var _dialogue_layer: Control
var _narration_p1_box: PanelContainer
var _narration_p1_label: Label
var _speech_group: Control           # P11a～c 气泡与常驻名签容器
var _speech_nameplate: PanelContainer
var _speech_speaker_label: Label
var _speech_bubble_wrap: Control     # 包裹尖尾与气泡本体，便于轻弹切句
var _speech_tail_white: Polygon2D
var _speech_tail_outline: Line2D
var _speech_bubble_box: PanelContainer
var _speech_purple_corner: Line2D
var _speech_text_label: Label
var _narration_end_box: PanelContainer
var _narration_end_label: Label

var _fade_rect: ColorRect
var _sfx_player: AudioStreamPlayer


## 粒子总预算（P10 ＋ P11d 合计 <= 120）
static func total_shard_budget() -> int:
	return P10_SHARD_AMOUNT + P11_SHARD_AMOUNT


## 资源存在性检查（允许测试临时覆盖，不碰文件系统）
static func _asset_exists(path: String) -> bool:
	if _asset_exists_override.is_valid():
		return bool(_asset_exists_override.call(path))
	return ResourceLoader.exists(path)


## 兼容读取 XRift.RIFT3_ANIM（拆卡 5 加到 rift.gd 后自动生效；未定义时视为 true）
static func _rift_switch_on() -> bool:
	if not XRift.STAGE3:
		return false
	var scr: Script = XRift
	if scr != null:
		var flag = scr.get("RIFT3_ANIM")
		if flag != null and not bool(flag):
			return false
	return true


## 开关全开且 4 个必需资源全部就绪才返回 true；缺任一资源返回 false 不报错
static func available() -> bool:
	if not ENABLED or not _rift_switch_on():
		return false
	for p in REQUIRED_ASSETS:
		if not _asset_exists(p):
			return false
	return true


## 按跳过时刻（秒）计算未看全的句键（严格按 LINE_ORDER 顺序）
static func compute_missed_lines(at_time: float) -> Array[String]:
	var out: Array[String] = []
	for cue in DIALOGUE_CUES:
		if at_time < float(cue.seen_at):
			out.append(str(cue.key))
	return out


## 直读 XRift.RIFT3_LINES[key] 并剥离 MV 控制符与前导换行空白，返回 {"speaker": 名签, "text": 纯正文}
static func parse_rift_line(key: String) -> Dictionary:
	var raw := str(XRift.RIFT3_LINES.get(key, ""))
	if raw == "":
		return {"speaker": "", "text": ""}
	if _re_speaker == null:
		_re_speaker = RegEx.create_from_string("\\\\n<([^>]*)>")
	if _re_mv_code == null:
		_re_mv_code = RegEx.create_from_string("(?i)\\\\(?:[ci]\\[\\d+\\]|[|!.{}<>^$])")
	var speaker := ""
	var s := raw
	var m := _re_speaker.search(s)
	if m != null:
		speaker = m.get_string(1)
		s = s.substr(0, m.get_start()) + s.substr(m.get_end())
	s = _re_mv_code.sub(s, "", true).strip_edges()
	return {"speaker": speaker, "text": s}


## 时间码对应的四段状态枚举
static func phase_at(at_time: float) -> int:
	if at_time < PHASE_P1_END:
		return Phase.P1
	if at_time < PHASE_MID_END:
		return Phase.MID
	if at_time < PHASE_P10_END:
		return Phase.P10
	return Phase.P11


static func phase_name(p: int) -> String:
	return str(PHASE_NAMES.get(p, "P1"))


## 启动播放器：正常模式校验 available()，缺资源返回 null；allow_placeholder=true 时允许程序占位跑通
static func play(parent: Node, viewport_tex: Texture2D = null, allow_placeholder := false) -> XRift3Anim:
	var ready_assets := available()
	if not ready_assets and not allow_placeholder:
		return null
	missed_lines.clear()
	var anim := XRift3Anim.new()
	anim.name = NODE_NAME
	anim._viewport_tex = viewport_tex
	anim._placeholder_mode = not ready_assets
	if parent != null:
		parent.add_child(anim)
	return anim


func _init() -> void:
	layer = LAYER
	_build_tree()


func _ready() -> void:
	if _p1_tex_rect != null:
		if _viewport_tex != null:
			_p1_tex_rect.texture = _viewport_tex
		else:
			_p1_tex_rect.texture = _get_p1_fallback_tex()
	_speech_speaker_label.text = str(parse_rift_line("sense").speaker)
	_load_optional_assets()
	_sync_p10_textures()
	_sync_p11_portrait_texture(1.0)
	_sync_visuals()


func _gui_input(e: InputEvent) -> void:
	if _done:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if not _skipping and _t >= SKIP_GUARD_SEC:
			_pressed = true
	XKeyMap.handled(self)


## 播放期间吃掉下层输入；0.8s 保护期内忽略跳过，0.8s 后任意按键／点击／触屏／手柄按一次跳过
func _input(e: InputEvent) -> void:
	if _done:
		return
	var is_skip_press: bool = e.is_action_pressed("ui_accept") \
		or e.is_action_pressed("ui_cancel") \
		or (e is InputEventKey and e.pressed and not e.echo) \
		or (e is InputEventJoypadButton and e.pressed) \
		or (e is InputEventScreenTouch and e.pressed) \
		or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT)
	if is_skip_press and not _skipping and _t >= SKIP_GUARD_SEC:
		_pressed = true
	if e is InputEventKey or e is InputEventJoypadButton or e is InputEventScreenTouch or e is InputEventMouseButton:
		XKeyMap.handled(self)


func _process(delta: float) -> void:
	if _done:
		return
	var scale := maxf(Engine.time_scale, 0.001)
	if _video_player != null:
		_video_player.speed_scale = 1.0 / scale
	step(delta / scale, _pressed)
	_pressed = false


## 推进 dt 真实秒；skip_pressed=true 表示本帧有跳过按键／点击
func step(dt: float, skip_pressed := false) -> void:
	if _done:
		return
	var real_dt := maxf(dt, 0.0)
	if _skipping:
		_advance_skip_fade(real_dt)
		return
	_t += real_dt
	if _t >= TOTAL_DURATION:
		_t = TOTAL_DURATION
		_sync_visuals()
		_finish()
		return
	if skip_pressed and _t >= SKIP_GUARD_SEC:
		_begin_skip()
		return
	_sync_visuals()


func _begin_skip() -> void:
	if _skipping or _done:
		return
	_skipping = true
	_skipped = true
	_skip_time = _t
	missed_lines = compute_missed_lines(_skip_time)
	_fade = 0.0
	if _fade_rect != null:
		_fade_rect.color.a = 0.0


func _advance_skip_fade(dt: float) -> void:
	_fade = minf(1.0, _fade + dt / SKIP_FADE_SEC)
	if _fade_rect != null:
		_fade_rect.color.a = _fade
	if _fade >= 1.0:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if _video_player != null:
		_video_player.stop()
	if _sfx_player != null:
		_sfx_player.stop()
	if _p10_shards != null:
		_p10_shards.emitting = false
	if _p11_shards != null:
		_p11_shards.emitting = false
	finished.emit()
	queue_free()


## 供测试与调试读取内部状态
func state() -> Dictionary:
	var active_sfx: Array[String] = []
	for cue in SFX_CUES:
		var cid := str(cue.id)
		var lbl: Label = _sfx_labels.get(cid)
		if lbl != null and lbl.visible:
			active_sfx.append(cid)
	return {
		"layer": layer,
		"t": _t,
		"phase": _phase,
		"phase_name": phase_name(_phase),
		"active_panel": _active_panel,
		"active_dialogue_key": _active_dialogue_key,
		"active_dialogue_text": _active_dialogue_text,
		"active_dialogue_speaker": _active_dialogue_speaker,
		"nameplate_visible": _speech_group.visible and _speech_nameplate.visible,
		"active_sfx_ids": active_sfx,
		"skipping": _skipping,
		"skipped": _skipped,
		"skip_time": _skip_time,
		"fade": _fade,
		"done": _done,
		"placeholder_mode": _placeholder_mode,
		"missed_lines": missed_lines.duplicate(),
		"p1_shader_ready": _p1_mat != null and _p1_mat.shader != null,
		"p1_mix_amount": _p1_mix_amount,
		"p1_zoom": _p1_zoom,
		"p1_frame_rect": _p1_frame.get_rect() if _p1_frame != null else Rect2(),
		"p10_split_gap": _p10_split_gap,
		"p10_halves_visible": _p10_half_tl != null and _p10_half_tl.visible and _p10_half_br != null and _p10_half_br.visible,
		"p10_shards_amount": _p10_shards.amount if _p10_shards != null else 0,
		"p10_shards_fired": _p10_shards_fired,
		"p11_shards_amount": _p11_shards.amount if _p11_shards != null else 0,
		"p11_shards_fired": _p11_shards_fired,
		"p11_purple_edge_active": _p11_purple_edge != null and _p11_purple_edge.visible,
		"total_shard_particles": (_p10_shards.amount if _p10_shards != null else 0) + (_p11_shards.amount if _p11_shards != null else 0),
	}


func _load_optional_assets() -> void:
	if ResourceLoader.exists(VIDEO_MID):
		var st = load(VIDEO_MID)
		if st is VideoStream and _video_player != null:
			_video_player.stream = st
			_video_player.visible = true
			if _mid_placeholder_box != null:
				_mid_placeholder_box.visible = false
	if ResourceLoader.exists(TEX_P9_END):
		var t1 = load(TEX_P9_END)
		if t1 is Texture2D and _p10_end_rect != null:
			_p10_end_rect.texture = t1
	if ResourceLoader.exists(TEX_M6_SLASH):
		var t2 = load(TEX_M6_SLASH)
		if t2 is Texture2D and _p10_slash_rect != null:
			_p10_slash_rect.texture = t2
	if ResourceLoader.exists(TEX_M5A_PORTRAIT):
		var t3 = load(TEX_M5A_PORTRAIT)
		if t3 is Texture2D and _p11_portrait_rect != null:
			_p11_portrait_rect.texture = t3
	if ResourceLoader.exists(AUDIO_SFX):
		var au = load(AUDIO_SFX)
		if au is AudioStream:
			_sfx_player = AudioStreamPlayer.new()
			_sfx_player.name = "SfxPlayer"
			_sfx_player.stream = au
			add_child(_sfx_player)
			_sfx_player.play()


func _sync_visuals() -> void:
	_phase = phase_at(_t)
	_p1_layer.visible = (_phase == Phase.P1)
	_mid_layer.visible = (_phase == Phase.MID)
	_p10_layer.visible = (_phase == Phase.P10)
	_p11_layer.visible = (_phase == Phase.P11)

	# 中段视频仅在进入 Phase.MID 时启动、离开时停止，避免 P1 阶段偷跑
	if _phase == Phase.MID:
		if _video_player != null and _video_player.stream != null and not _mid_started:
			_mid_started = true
			_video_player.speed_scale = 1.0 / maxf(Engine.time_scale, 0.001)
			_video_player.play()
	elif _mid_started:
		_mid_started = false
		if _video_player != null:
			_video_player.stop()

	_sync_panel_placeholder()
	_update_phase_p1()
	_update_phase_p10()
	_update_phase_p11()
	_sync_sfx_cues()
	_sync_dialogue_cues()


func _update_phase_p1() -> void:
	if _phase != Phase.P1:
		return
	# 0.0–0.30s：实机全屏 (0,0,1280×720) 微弹收束入左格 (48,56,560×440)，同时网点 Shader 从 0→1 显现
	var shrink_u := clampf(_t / P1_SHRINK_SEC, 0.0, 1.0)
	var ease_u := _ease_out_back_subtle(shrink_u)
	var cur_pos := Vector2.ZERO.lerp(P1_TARGET_RECT.position, ease_u)
	var cur_size := STAGE_SIZE.lerp(P1_TARGET_RECT.size, ease_u)
	_p1_frame.position = cur_pos
	_p1_frame.size = cur_size
	var border_w := int(round(lerpf(0.0, 5.0, clampf(shrink_u * 1.4, 0.0, 1.0))))
	var sb := _p1_frame.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.set_border_width_all(border_w)
	_p1_tex_rect.position = Vector2(border_w, border_w)
	_p1_tex_rect.size = Vector2(maxf(cur_size.x - border_w * 2.0, 1.0), maxf(cur_size.y - border_w * 2.0, 1.0))
	_p1_gutter.color.a = clampf(shrink_u * 1.35, 0.0, 1.0)

	# 0.30–2.60s：左格定格，格内缓推 1.00×→1.04×
	_p1_mix_amount = clampf(shrink_u * 1.15, 0.0, 1.0)
	var push_u := clampf((_t - P1_SHRINK_SEC) / (PHASE_P1_END - P1_SHRINK_SEC), 0.0, 1.0)
	_p1_zoom = lerpf(1.0, 1.04, push_u)
	if _p1_mat != null:
		_p1_mat.set_shader_parameter("mix_amount", _p1_mix_amount)
		_p1_mat.set_shader_parameter("zoom", _p1_zoom)
		_p1_mat.set_shader_parameter("panel_size", _p1_tex_rect.size)


func _update_phase_p10() -> void:
	if _phase != Phase.P10:
		if _p10_shards != null and _p10_shards.emitting:
			_p10_shards.emitting = false
		return

	var lt := _t - PHASE_MID_END  # 0.0 .. 2.3s
	# 1) 15.00–15.10s：全屏反色冲击帧＋12px 重震屏（至 15.45s 平滑衰减）
	var invert_amt := 1.0 if lt < 0.10 else clampf(1.0 - (lt - 0.10) / 0.06, 0.0, 1.0)
	if _p10_half_mat != null:
		_p10_half_mat.set_shader_parameter("invert_amount", invert_amt)

	var shake_amp := 0.0
	if lt < 0.45:
		shake_amp = 12.0 * pow(1.0 - lt / 0.45, 1.6)
	_p10_halves_root.position = Vector2(
		sin(lt * 195.0) * shake_amp,
		cos(lt * 235.0) * shake_amp * 0.85
	)

	# 2) 两半画页沿斜线法向裂开→滑出屏幕，实时露出底层 Map004
	var cut_dir := Vector2(P10_CUT_BOT_X - P10_CUT_TOP_X, STAGE_SIZE.y).normalized()
	var cut_normal := Vector2(-cut_dir.y, cut_dir.x)  # 指向左上方 (-0.6, -0.8)
	var gap := 0.0
	var half_rot := 0.0
	var half_alpha := 1.0
	if lt < 0.40:
		# 15.00–15.40s：裂口初开 0 -> 28px，外透刺眼白光
		var u := clampf(lt / 0.40, 0.0, 1.0)
		gap = lerpf(4.0, 28.0, u * u)
		half_rot = lerpf(0.0, 0.015, u)
	elif lt < 1.35:
		# 15.40–16.35s：两半加速滑开出屏，裂口完全洞开透出真实 Map004
		var u := clampf((lt - 0.40) / 0.95, 0.0, 1.0)
		var slide := u * u * (3.0 - 2.0 * u)
		gap = lerpf(28.0, 920.0, slide)
		half_rot = lerpf(0.015, 0.14, u)
		half_alpha = clampf(1.0 - clampf((u - 0.72) / 0.28, 0.0, 1.0), 0.0, 1.0)
	else:
		gap = 960.0
		half_rot = 0.14
		half_alpha = 0.0
	_p10_split_gap = gap

	var halves_on := half_alpha > 0.005
	_p10_half_tl.visible = halves_on
	_p10_half_br.visible = halves_on
	if halves_on:
		var pivot := STAGE_SIZE * 0.5
		_p10_half_tl.position = cut_normal * gap + Vector2(-gap * 0.15, -gap * 0.05)
		_p10_half_tl.rotation = -half_rot
		_p10_half_tl.modulate = Color(1.0, 1.0, 1.0, half_alpha)
		_p10_half_br.position = -cut_normal * gap + Vector2(gap * 0.15, gap * 0.08)
		_p10_half_br.rotation = half_rot
		_p10_half_br.modulate = Color(1.0, 1.0, 1.0, half_alpha)
		# 避免旋转偏心：确保绕画页中轴轻倾（Polygon2D 原点为 (0,0)，以少量位移补偿保持左右对称滑开）
		_p10_half_tl.position += Vector2(pivot.y * sin(half_rot) * 0.12, 0.0)
		_p10_half_br.position -= Vector2(pivot.y * sin(half_rot) * 0.12, 0.0)

	# 3) 对角纯白刀光＋朱红残影（15.00–15.65s，中段宽锐、两端收尖的利刃刀芒）
	var slash_active := lt < 0.65
	_p10_slash_bar.visible = lt < 0.55
	_p10_slash_white_poly.visible = slash_active
	_p10_slash_red_poly.visible = slash_active
	if slash_active:
		var beam_w := 36.0 if lt < 0.12 else lerpf(36.0, 5.0, clampf((lt - 0.12) / 0.53, 0.0, 1.0))
		var beam_a := 1.0 if lt < 0.36 else clampf(1.0 - (lt - 0.36) / 0.29, 0.0, 1.0)
		var p_top := Vector2(P10_CUT_TOP_X, -10.0)
		var p_bot := Vector2(P10_CUT_BOT_X, STAGE_SIZE.y + 10.0)
		_p10_slash_white_poly.polygon = _tapered_slash_poly(p_top, p_bot, cut_normal, beam_w)
		_p10_slash_white_poly.color = Color(COLOR_PAPER.r, COLOR_PAPER.g, COLOR_PAPER.b, beam_a)
		var red_off := cut_normal * (beam_w * 0.45 + 7.0)
		_p10_slash_red_poly.polygon = _tapered_slash_poly(p_top + red_off, p_bot + red_off, cut_normal, maxf(beam_w * 0.36, 3.5))
		_p10_slash_red_poly.color = Color(COLOR_CRIMSON.r, COLOR_CRIMSON.g, COLOR_CRIMSON.b, beam_a * 0.90)
		_p10_slash_bar.color.a = 0.0

	# 4) 碎格粒子 CPUParticles2D（amount = 96 <= 120）：15.32s 一次性爆发飞溅
	if not _p10_shards_fired and lt >= 0.32 and lt < 1.50:
		_p10_shards_fired = true
		_p10_shards.restart()
		_p10_shards.emitting = true

	# 5) 裂口下方残余紫烟（15.40–16.55s 被 M6 挥斩劈散）
	var smoke_on := lt >= 0.35 and lt < 1.65
	_p10_purple_smoke.visible = smoke_on
	if smoke_on:
		var cleave_u := clampf((lt - 0.72) / 0.85, 0.0, 1.0)
		var smoke_a := clampf((lt - 0.35) / 0.18, 0.0, 1.0) * (1.0 - cleave_u)
		for i in _p10_smoke_wisps.size():
			var wisp: Polygon2D = _p10_smoke_wisps[i]
			var side := -1.0 if (i % 2 == 0) else 1.0
			wisp.position = Vector2(side * cleave_u * (140.0 + i * 35.0), -cleave_u * (28.0 + i * 12.0))
			wisp.scale = Vector2.ONE * (1.0 + cleave_u * 0.45)
			wisp.modulate = Color(1.0, 1.0, 1.0, smoke_a * (0.58 if i % 2 == 0 else 0.42))

	# 6) M6 透明挥斩前景冲破裂口（15.38–17.30s；0.82×→1.18× 冲近后收势消隐）
	var m6_on := lt >= 0.38 and lt < 2.25
	_p10_slash_rect.visible = m6_on
	if m6_on:
		var base_size := Vector2(860.0, 680.0)
		var m6_scale := 1.0
		var m6_alpha := 1.0
		var m6_offset := Vector2.ZERO
		if lt < 0.85:
			var u := clampf((lt - 0.38) / 0.47, 0.0, 1.0)
			var eu := 1.0 - pow(1.0 - u, 3.0)
			m6_scale = lerpf(0.82, 1.18, eu)
			m6_alpha = clampf(u * 2.4, 0.0, 1.0)
			m6_offset = Vector2(lerpf(90.0, -18.0, eu), lerpf(-70.0, 10.0, eu))
		elif lt < 1.45:
			var u := clampf((lt - 0.85) / 0.60, 0.0, 1.0)
			m6_scale = lerpf(1.18, 1.04, u)
			m6_offset = Vector2(lerpf(-18.0, -42.0, u), lerpf(10.0, 18.0, u))
		else:
			var u := clampf((lt - 1.45) / 0.80, 0.0, 1.0)
			m6_scale = lerpf(1.04, 0.94, u)
			m6_alpha = clampf(1.0 - u, 0.0, 1.0)
			m6_offset = Vector2(lerpf(-42.0, -78.0, u), lerpf(18.0, 28.0, u))
		var cur_sz := base_size * m6_scale
		_p10_slash_rect.size = cur_sz
		_p10_slash_rect.position = (STAGE_SIZE - cur_sz) * 0.5 + m6_offset
		_p10_slash_rect.modulate = Color(1.0, 1.0, 1.0, m6_alpha)


func _update_phase_p11() -> void:
	if _phase != Phase.P11:
		if _p11_shards != null and _p11_shards.emitting:
			_p11_shards.emitting = false
		if _p11_purple_edge != null:
			_p11_purple_edge.visible = false
		if _speech_purple_corner != null:
			_speech_purple_corner.visible = false
		_dialogue_layer.modulate.a = 1.0
		return

	var in_p11d := _t >= PHASE_P11D_START
	var p11_elapsed := _t - PHASE_P10_END
	var end_alpha := 1.0
	if _t > TOTAL_DURATION - END_FADE_SEC:
		end_alpha = clampf((TOTAL_DURATION - _t) / END_FADE_SEC, 0.0, 1.0)

	# 右侧真实方桌大厅仅带极轻暗角衬字；P11d 平滑退至 0
	if in_p11d:
		var d_u := clampf((_t - PHASE_P11D_START) / (TOTAL_DURATION - PHASE_P11D_START), 0.0, 1.0)
		_p11_dim.color.a = lerpf(0.18, 0.0, d_u)
	else:
		var enter_a := clampf(p11_elapsed / 0.20, 0.0, 1.0)
		_p11_dim.color.a = 0.20 * enter_a
	_dialogue_layer.modulate.a = end_alpha

	# 左侧斜切破边漫画立绘残格
	_p11_portrait_box.visible = not in_p11d
	if not in_p11d:
		# P11a 进场微弹（17.30–17.52s）＋ P11c 轻向右微推蓄势（22.5–24.7s）
		var pop_u := clampf(p11_elapsed / 0.22, 0.0, 1.0)
		var pop_ease := _ease_out_back_subtle(pop_u)
		var base_pos := Vector2(20.0, 150.0).lerp(Vector2(44.0, 132.0), pop_ease)
		if _t >= 22.5:
			var push_right := clampf((_t - 22.5) / 2.2, 0.0, 1.0)
			base_pos.x += lerpf(0.0, 8.0, push_right)
		# P11b 21.2s 单拍 2px 幽紫框边微闪（严格限于框边与气泡外角，正文绝不变紫或抖动）
		var purple_pulse := _t >= 21.12 and _t <= 21.38
		var jitter := Vector2.ZERO
		if purple_pulse:
			var pt := _t - 21.12
			jitter = Vector2(sin(pt * 210.0) * 2.0, cos(pt * 170.0) * 1.5)
		_p11_portrait_box.position = base_pos + jitter
		_p11_portrait_box.modulate.a = clampf(pop_u * 2.0, 0.0, 1.0)

		# 残格内立绘极缓前推 1.00×→1.03×
		var p_zoom := lerpf(1.0, 1.03, clampf(p11_elapsed / (PHASE_P11D_START - PHASE_P10_END), 0.0, 1.0))
		_sync_p11_portrait_texture(p_zoom)

		_p11_purple_edge.visible = purple_pulse
		_speech_purple_corner.visible = purple_pulse and _speech_bubble_box.visible
		if purple_pulse:
			var pulse_a := sin(clampf((_t - 21.12) / 0.26, 0.0, 1.0) * PI)
			_p11_purple_edge.default_color = Color(COLOR_PURPLE_BRIGHT.r, COLOR_PURPLE_BRIGHT.g, COLOR_PURPLE_BRIGHT.b, 0.92 * pulse_a)
			_speech_purple_corner.default_color = Color(COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b, 0.88 * pulse_a)

		# P11c 红带微风飘尘线条（22.5–24.7s 轻盈掠过残格边沿）
		var wind_on := _t >= 22.5
		for i in _p11_wind_lines.size():
			var wl: Line2D = _p11_wind_lines[i]
			wl.visible = wind_on
			if wind_on:
				var wt := fmod((_t - 22.5) * (0.9 + i * 0.25) + i * 0.33, 1.0)
				wl.position = Vector2(lerpf(-30.0, 110.0, wt), lerpf(18.0, -24.0, wt))
				wl.default_color.a = sin(wt * PI) * 0.65
	else:
		_p11_purple_edge.visible = false
		_speech_purple_corner.visible = false
		# 24.7s：残格与气泡碎成最后 20 片黑白网点纸屑随风飘散
		if not _p11_shards_fired:
			_p11_shards_fired = true
			_p11_shards.restart()
			_p11_shards.emitting = true


func _sync_panel_placeholder() -> void:
	if _phase == Phase.P1:
		_active_panel = "P1"
		return
	if _phase == Phase.P10:
		_active_panel = "P10"
		return
	if _phase == Phase.P11:
		if _t < 19.8:
			_active_panel = "P11a"
		elif _t < 22.5:
			_active_panel = "P11b"
		elif _t < PHASE_P11D_START:
			_active_panel = "P11c"
		else:
			_active_panel = "P11d"
		return
	# Phase.MID：按时间码定位 P2～P9
	var matched: Dictionary = MID_PANELS[0]
	for item in MID_PANELS:
		if _t >= float(item.start) and _t < float(item.end):
			matched = item
			break
	_active_panel = str(matched.panel)
	if _mid_placeholder_box != null and _mid_placeholder_box.visible:
		var r: Rect2 = matched.rect
		_mid_placeholder_box.position = r.position
		_mid_placeholder_box.size = r.size
		var sb := _mid_placeholder_box.get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			sb.border_color = matched.accent
		if _mid_placeholder_label != null:
			_mid_placeholder_label.text = _active_panel


func _sync_sfx_cues() -> void:
	for cue in SFX_CUES:
		var cid := str(cue.id)
		var lbl: Label = _sfx_labels.get(cid)
		if lbl == null:
			continue
		var c_start := float(cue.start)
		var c_end := float(cue.end)
		var active := (_t >= c_start and _t < c_end)
		lbl.visible = active
		if not active:
			continue
		var base_pos: Vector2 = cue.pos
		var age := _t - c_start
		var left := c_end - _t
		if str(cue.kind) == "blade":
			# 刀意字「斩」：前 0.08s 凌厉砸入，末 0.14s 随纸页碎散淡出
			var punch := lerpf(1.32, 1.0, clampf(age / 0.08, 0.0, 1.0))
			var scatter := lerpf(1.0, 1.18, clampf(1.0 - left / 0.14, 0.0, 1.0)) if left < 0.14 else 1.0
			lbl.scale = Vector2.ONE * (punch * scatter)
			lbl.modulate.a = clampf(left / 0.14, 0.0, 1.0)
			lbl.position = base_pos + Vector2(sin(age * 160.0) * 2.5, cos(age * 140.0) * 2.0) * clampf(1.0 - age / 0.18, 0.0, 1.0)
		elif cid == "p2_hum":
			# P2「嗡——」：贴涡缘微颤
			lbl.position = base_pos + Vector2(sin(age * 68.0) * 2.0, cos(age * 54.0) * 1.5)
			lbl.scale = Vector2.ONE
			lbl.modulate.a = 1.0
		else:
			var pop := lerpf(1.16, 1.0, clampf(age / 0.08, 0.0, 1.0))
			lbl.scale = Vector2.ONE * pop
			lbl.position = base_pos
			lbl.modulate.a = 1.0


func _sync_dialogue_cues() -> void:
	_narration_p1_box.visible = false
	_speech_bubble_box.visible = false
	_speech_bubble_wrap.visible = false
	_narration_end_box.visible = false
	_active_dialogue_key = ""
	_active_dialogue_text = ""
	_active_dialogue_speaker = ""

	# v0.5 第 7.1 节：P11a～c（17.3–24.7s）期间名签「徐凤年」常驻不动、跨句间隙不闪烁
	var in_p11_talk := (_t >= PHASE_P10_END and _t < PHASE_P11D_START)
	_speech_group.visible = in_p11_talk
	_speech_nameplate.visible = in_p11_talk

	for cue in DIALOGUE_CUES:
		var c_start := float(cue.start)
		var c_end := float(cue.end)
		if _t >= c_start and _t < c_end:
			var key := str(cue.key)
			var parsed := parse_rift_line(key)
			var text := str(parsed.text)
			var speaker := str(parsed.speaker) if bool(cue.show_speaker) else ""
			_active_dialogue_key = key
			_active_dialogue_text = text
			_active_dialogue_speaker = speaker
			var style := str(cue.style)
			if style == "narration_p1":
				# v0.5：0.15s 整句淡入，单行居中，禁逐字打字机
				_narration_p1_label.text = text
				_narration_p1_label.visible_ratio = 1.0
				_narration_p1_box.modulate.a = clampf((_t - c_start) / 0.15, 0.0, 1.0)
				_narration_p1_box.visible = true
			elif style == "speech_bubble":
				# v0.5：名签常驻，正文整句即显（≤0.12s 轻弹入，禁逐字打字机；正文恒为深墨不变紫）
				if speaker != "":
					_speech_speaker_label.text = speaker
				if _p11_last_bubble_key != key:
					_p11_last_bubble_key = key
				_speech_text_label.text = text
				_speech_text_label.visible_ratio = 1.0
				_speech_text_label.add_theme_color_override("font_color", COLOR_INK)
				var pop_u := clampf((_t - c_start) / 0.12, 0.0, 1.0)
				var pop_s := lerpf(0.94, 1.0, _ease_out_back_subtle(pop_u))
				_speech_bubble_wrap.scale = Vector2(pop_s, pop_s)
				_speech_bubble_wrap.modulate.a = pop_u
				_speech_bubble_box.modulate.a = 1.0
				_speech_bubble_wrap.visible = true
				_speech_bubble_box.visible = true
			elif style == "narration_end":
				# v0.5：0.15s 快淡入 → 0.85s 稳停 → 0.20s 柔淡出
				_narration_end_label.text = text
				_narration_end_label.visible_ratio = 1.0
				var fade_in := clampf((_t - c_start) / 0.15, 0.0, 1.0)
				var fade_out := clampf((c_end - _t) / 0.20, 0.0, 1.0)
				_narration_end_box.modulate.a = minf(fade_in, fade_out)
				_narration_end_box.visible = true
			break


func _build_tree() -> void:
	var font := XUI.font()
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.custom_minimum_size = STAGE_SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_gui_input)
	add_child(_root)

	_stage_layer = Control.new()
	_stage_layer.name = "StageLayer"
	_stage_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stage_layer)

	_build_phase_p1()
	_build_phase_mid(font)
	_build_phase_p10()
	_build_phase_p11(font)
	_build_sfx_layer(font)
	_build_dialogue_layer(font)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade_rect)


func _build_phase_p1() -> void:
	_p1_layer = Control.new()
	_p1_layer.name = "PhaseP1"
	_p1_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_p1_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_layer.add_child(_p1_layer)

	_p1_gutter = ColorRect.new()
	_p1_gutter.name = "Gutter"
	_p1_gutter.color = COLOR_INK
	_p1_gutter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_p1_gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p1_layer.add_child(_p1_gutter)

	_p1_frame = Panel.new()
	_p1_frame.name = "LeftPanel"
	_p1_frame.position = P1_TARGET_RECT.position
	_p1_frame.size = P1_TARGET_RECT.size
	_p1_frame.clip_contents = true
	_p1_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p1_frame.add_theme_stylebox_override("panel", _panel_box(COLOR_INK, COLOR_PAPER, 5))
	_p1_layer.add_child(_p1_frame)

	_p1_tex_rect = TextureRect.new()
	_p1_tex_rect.name = "ViewportTex"
	_p1_tex_rect.position = Vector2(5, 5)
	_p1_tex_rect.size = Vector2(550, 430)
	_p1_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_p1_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_p1_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(SHADER_HALFTONE):
		var sh = load(SHADER_HALFTONE)
		if sh is Shader:
			_p1_mat = ShaderMaterial.new()
			_p1_mat.shader = sh
			_p1_mat.set_shader_parameter("mix_amount", 1.0)
			_p1_mat.set_shader_parameter("zoom", 1.0)
			_p1_mat.set_shader_parameter("panel_size", Vector2(550.0, 430.0))
			_p1_tex_rect.material = _p1_mat
	_p1_frame.add_child(_p1_tex_rect)


func _build_phase_mid(font: Font) -> void:
	_mid_layer = Control.new()
	_mid_layer.name = "PhaseMid"
	_mid_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mid_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mid_layer.visible = false
	_stage_layer.add_child(_mid_layer)

	var bg := ColorRect.new()
	bg.name = "MidGutter"
	bg.color = COLOR_INK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mid_layer.add_child(bg)

	_video_player = VideoStreamPlayer.new()
	_video_player.name = "Video"
	_video_player.expand = true
	_video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video_player.visible = false
	_mid_layer.add_child(_video_player)

	_mid_placeholder_box = Panel.new()
	_mid_placeholder_box.name = "MidPlaceholder"
	_mid_placeholder_box.position = Vector2(632, 56)
	_mid_placeholder_box.size = Vector2(600, 440)
	_mid_placeholder_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mid_placeholder_box.add_theme_stylebox_override("panel", _panel_box(Color(0.11, 0.10, 0.14, 1.0), COLOR_PURPLE, 5))
	_mid_layer.add_child(_mid_placeholder_box)

	_mid_placeholder_label = Label.new()
	_mid_placeholder_label.name = "MidPanelTag"
	_mid_placeholder_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mid_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mid_placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mid_placeholder_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mid_placeholder_label.add_theme_font_override("font", font)
	_mid_placeholder_label.add_theme_font_size_override("font_size", 40)
	_mid_placeholder_label.add_theme_color_override("font_color", COLOR_GRAY_LIGHT)
	_mid_placeholder_box.add_child(_mid_placeholder_label)


func _build_phase_p10() -> void:
	# 重要：PhaseP10 不放任何全屏不透明底板，确保两半画页滑开后裂口实时透出下方真实 Map004
	_p10_layer = Control.new()
	_p10_layer.name = "PhaseP10"
	_p10_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_p10_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p10_layer.visible = false
	_stage_layer.add_child(_p10_layer)

	# 兼容 T425 纹理承载节点（隐藏，实际渲染走下方两块斜切 Polygon2D）
	_p10_end_rect = TextureRect.new()
	_p10_end_rect.name = "P9EndTex"
	_p10_end_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_p10_end_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_p10_end_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_p10_end_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p10_end_rect.visible = false
	_p10_layer.add_child(_p10_end_rect)

	# 裂口后残余紫烟（位处最底，M6 挥斩一刀劈散）
	_p10_purple_smoke = Control.new()
	_p10_purple_smoke.name = "PurpleSmoke"
	_p10_purple_smoke.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_p10_purple_smoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p10_purple_smoke.visible = false
	_p10_layer.add_child(_p10_purple_smoke)
	var smoke_specs: Array = [
		[Vector2(540, 495), Vector2(125, 48), 0.18, COLOR_PURPLE],
		[Vector2(735, 470), Vector2(138, 44), -0.15, COLOR_PURPLE_DARK],
		[Vector2(635, 535), Vector2(150, 52), 0.06, COLOR_PURPLE],
		[Vector2(665, 442), Vector2(96, 36), -0.22, COLOR_PURPLE_BRIGHT],
	]
	for i in smoke_specs.size():
		var spec: Array = smoke_specs[i]
		var wisp := Polygon2D.new()
		wisp.name = "SmokeWisp_%d" % i
		wisp.polygon = _soft_cloud_poly(spec[0], spec[1], float(spec[2]), i)
		wisp.color = spec[3]
		_p10_purple_smoke.add_child(wisp)
		_p10_smoke_wisps.append(wisp)

	# 两半斜切 P9 画页（挂在可震屏容器下，带轻量反色冲击材质）
	_p10_halves_root = Control.new()
	_p10_halves_root.name = "SplitHalvesRoot"
	_p10_halves_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_p10_halves_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p10_layer.add_child(_p10_halves_root)

	_p10_half_mat = ShaderMaterial.new()
	_p10_half_mat.shader = _get_invert_shader()
	_p10_half_mat.set_shader_parameter("invert_amount", 0.0)

	var tl_poly := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(P10_CUT_TOP_X, 0.0),
		Vector2(P10_CUT_BOT_X, STAGE_SIZE.y),
		Vector2(0.0, STAGE_SIZE.y),
	])
	var br_poly := PackedVector2Array([
		Vector2(P10_CUT_TOP_X, 0.0),
		Vector2(STAGE_SIZE.x, 0.0),
		Vector2(STAGE_SIZE.x, STAGE_SIZE.y),
		Vector2(P10_CUT_BOT_X, STAGE_SIZE.y),
	])

	_p10_half_tl = Polygon2D.new()
	_p10_half_tl.name = "P10HalfTopLeft"
	_p10_half_tl.polygon = tl_poly
	_p10_half_tl.material = _p10_half_mat
	_p10_halves_root.add_child(_p10_half_tl)

	_p10_cut_tl_edge = Line2D.new()
	_p10_cut_tl_edge.name = "CutEdgeTL"
	_p10_cut_tl_edge.points = PackedVector2Array([Vector2(P10_CUT_TOP_X, 0.0), Vector2(P10_CUT_BOT_X, STAGE_SIZE.y)])
	_p10_cut_tl_edge.width = 6.0
	_p10_cut_tl_edge.default_color = COLOR_PAPER
	_p10_half_tl.add_child(_p10_cut_tl_edge)

	_p10_half_br = Polygon2D.new()
	_p10_half_br.name = "P10HalfBottomRight"
	_p10_half_br.polygon = br_poly
	_p10_half_br.material = _p10_half_mat
	_p10_halves_root.add_child(_p10_half_br)

	_p10_cut_br_edge = Line2D.new()
	_p10_cut_br_edge.name = "CutEdgeBR"
	_p10_cut_br_edge.points = PackedVector2Array([Vector2(P10_CUT_TOP_X, 0.0), Vector2(P10_CUT_BOT_X, STAGE_SIZE.y)])
	_p10_cut_br_edge.width = 6.0
	_p10_cut_br_edge.default_color = COLOR_PAPER
	_p10_half_br.add_child(_p10_cut_br_edge)

	# 对角斩光（朱红残影＋纯白光带＋兼容 SlashGlow 节点）
	_p10_slash_red_poly = Polygon2D.new()
	_p10_slash_red_poly.name = "SlashCrimsonTrail"
	_p10_slash_red_poly.color = COLOR_CRIMSON
	_p10_layer.add_child(_p10_slash_red_poly)

	_p10_slash_white_poly = Polygon2D.new()
	_p10_slash_white_poly.name = "SlashWhiteBeam"
	_p10_slash_white_poly.color = COLOR_PAPER
	_p10_layer.add_child(_p10_slash_white_poly)

	_p10_slash_bar = ColorRect.new()
	_p10_slash_bar.name = "SlashGlow"
	_p10_slash_bar.color = COLOR_PAPER
	_p10_slash_bar.position = Vector2(1180, -30)
	_p10_slash_bar.size = Vector2(1380, 10)
	_p10_slash_bar.rotation_degrees = 143.13
	_p10_slash_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p10_layer.add_child(_p10_slash_bar)

	# 碎格粒子（96 片，连同 P11d 20 片共 116 <= 120）
	_p10_shards = CPUParticles2D.new()
	_p10_shards.name = "P10ShardParticles"
	_p10_shards.position = STAGE_SIZE * 0.5
	_p10_shards.emitting = false
	_p10_shards.one_shot = true
	_p10_shards.explosiveness = 0.86
	_p10_shards.amount = P10_SHARD_AMOUNT
	_p10_shards.lifetime = 1.45
	_p10_shards.texture = _get_shard_particle_tex()
	_p10_shards.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_p10_shards.emission_rect_extents = Vector2(360.0, 210.0)
	_p10_shards.direction = Vector2(0.0, -0.35)
	_p10_shards.spread = 180.0
	_p10_shards.gravity = Vector2(0.0, 420.0)
	_p10_shards.initial_velocity_min = 240.0
	_p10_shards.initial_velocity_max = 640.0
	_p10_shards.angular_velocity_min = -360.0
	_p10_shards.angular_velocity_max = 360.0
	_p10_shards.scale_amount_min = 0.65
	_p10_shards.scale_amount_max = 1.65
	_p10_shards.color_ramp = _shard_color_ramp()
	_p10_layer.add_child(_p10_shards)

	# M6 透明挥斩前景
	_p10_slash_rect = TextureRect.new()
	_p10_slash_rect.name = "M6SlashTex"
	_p10_slash_rect.position = Vector2(210, 20)
	_p10_slash_rect.size = Vector2(860, 680)
	_p10_slash_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_p10_slash_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_p10_slash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p10_slash_rect.visible = false
	_p10_layer.add_child(_p10_slash_rect)


func _build_phase_p11(_font: Font) -> void:
	_p11_layer = Control.new()
	_p11_layer.name = "PhaseP11"
	_p11_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_p11_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p11_layer.visible = false
	_stage_layer.add_child(_p11_layer)

	_p11_dim = ColorRect.new()
	_p11_dim.name = "LobbyDim"
	_p11_dim.color = Color(0.043, 0.043, 0.055, 0.20)
	_p11_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_p11_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p11_layer.add_child(_p11_dim)

	# 左侧斜切破边漫画立绘残格（外容器仍名 PortraitShard，透明底，内嵌破边多边形）
	_p11_portrait_box = Panel.new()
	_p11_portrait_box.name = "PortraitShard"
	_p11_portrait_box.position = Vector2(44, 132)
	_p11_portrait_box.size = Vector2(480, 440)
	_p11_portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p11_portrait_box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_p11_layer.add_child(_p11_portrait_box)

	var shadow_pts := PackedVector2Array()
	for p in P11_SHARD_OUTER:
		shadow_pts.append(p + Vector2(10.0, 12.0))
	var shadow_poly := Polygon2D.new()
	shadow_poly.name = "ShardShadow"
	shadow_poly.polygon = shadow_pts
	shadow_poly.color = Color(COLOR_INK.r, COLOR_INK.g, COLOR_INK.b, 0.56)
	_p11_portrait_box.add_child(shadow_poly)

	var outer_poly := Polygon2D.new()
	outer_poly.name = "ShardWhiteFrame"
	outer_poly.polygon = PackedVector2Array(P11_SHARD_OUTER)
	outer_poly.color = COLOR_PAPER
	_p11_portrait_box.add_child(outer_poly)

	var bg_poly := Polygon2D.new()
	bg_poly.name = "ShardInkBg"
	bg_poly.polygon = PackedVector2Array(P11_SHARD_INNER)
	bg_poly.color = COLOR_INK
	_p11_portrait_box.add_child(bg_poly)

	_p11_portrait_poly = Polygon2D.new()
	_p11_portrait_poly.name = "M5aPortraitShard"
	_p11_portrait_poly.polygon = PackedVector2Array(P11_SHARD_INNER)
	_p11_portrait_box.add_child(_p11_portrait_poly)

	# 左内缘朱红竖条点缀（呼应三色体系）
	var crimson_bar := Polygon2D.new()
	crimson_bar.name = "CrimsonAccent"
	crimson_bar.polygon = PackedVector2Array([Vector2(18, 18), Vector2(26, 18), Vector2(27, 418), Vector2(19, 418)])
	crimson_bar.color = COLOR_CRIMSON
	_p11_portrait_box.add_child(crimson_bar)

	# 内描墨黑线（突出撕裂锯齿边与焦痕）
	var closed_inner := PackedVector2Array(P11_SHARD_INNER)
	closed_inner.append(P11_SHARD_INNER[0])
	_p11_border_line = Line2D.new()
	_p11_border_line.name = "ShardInkEdge"
	_p11_border_line.points = closed_inner
	_p11_border_line.width = 3.0
	_p11_border_line.default_color = COLOR_INK
	_p11_portrait_box.add_child(_p11_border_line)

	# P11b 21.2s 专用单拍幽紫电纹框边（仅沿右侧撕裂破边亮 0.26s，绝不入正文）
	_p11_purple_edge = Line2D.new()
	_p11_purple_edge.name = "ShardPurpleEdge"
	_p11_purple_edge.points = PackedVector2Array([
		Vector2(461, 3),
		Vector2(436, 124),
		Vector2(453, 152),
		Vector2(406, 292),
		Vector2(421, 323),
		Vector2(376, 434),
	])
	_p11_purple_edge.width = 4.0
	_p11_purple_edge.default_color = COLOR_PURPLE_BRIGHT
	_p11_purple_edge.visible = false
	_p11_portrait_box.add_child(_p11_purple_edge)

	# P11c 红带微风飘尘细线（3 缕）
	for i in range(3):
		var wl := Line2D.new()
		wl.name = "WindRibbon_%d" % i
		wl.points = PackedVector2Array([Vector2(290 + i * 28, 330 - i * 85), Vector2(365 + i * 24, 305 - i * 85), Vector2(418 + i * 18, 286 - i * 85)])
		wl.width = 2.5 if i == 1 else 1.8
		wl.default_color = COLOR_CRIMSON if i == 1 else COLOR_PAPER
		wl.visible = false
		_p11_portrait_box.add_child(wl)
		_p11_wind_lines.append(wl)

	# 兼容 T425 纹理承载节点（隐藏，避免方形贴图盖住破边剪裁）
	_p11_portrait_rect = TextureRect.new()
	_p11_portrait_rect.name = "M5aPortraitTex"
	_p11_portrait_rect.position = Vector2(18, 14)
	_p11_portrait_rect.size = Vector2(430, 412)
	_p11_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_p11_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_p11_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p11_portrait_rect.visible = false
	_p11_portrait_box.add_child(_p11_portrait_rect)

	# P11d 末段残格碎纸粒子（20 片，连同 P10 96 片共 116 <= 120）
	_p11_shards = CPUParticles2D.new()
	_p11_shards.name = "P11ShardParticles"
	_p11_shards.position = Vector2(280.0, 340.0)
	_p11_shards.emitting = false
	_p11_shards.one_shot = true
	_p11_shards.explosiveness = 0.85
	_p11_shards.amount = P11_SHARD_AMOUNT
	_p11_shards.lifetime = 1.05
	_p11_shards.texture = _get_shard_particle_tex()
	_p11_shards.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_p11_shards.emission_rect_extents = Vector2(220.0, 190.0)
	_p11_shards.direction = Vector2(0.82, -0.56)
	_p11_shards.spread = 46.0
	_p11_shards.gravity = Vector2(40.0, -35.0)
	_p11_shards.initial_velocity_min = 140.0
	_p11_shards.initial_velocity_max = 340.0
	_p11_shards.angular_velocity_min = -260.0
	_p11_shards.angular_velocity_max = 260.0
	_p11_shards.scale_amount_min = 0.55
	_p11_shards.scale_amount_max = 1.25
	_p11_shards.color_ramp = _shard_color_ramp()
	_p11_layer.add_child(_p11_shards)


func _build_sfx_layer(font: Font) -> void:
	_sfx_layer = Control.new()
	_sfx_layer.name = "SfxLayer"
	_sfx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sfx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_sfx_layer)

	for cue in SFX_CUES:
		var lbl := Label.new()
		lbl.name = "Sfx_" + str(cue.id)
		lbl.text = str(cue.text)
		lbl.position = cue.pos
		lbl.rotation_degrees = float(cue.rot_deg)
		lbl.visible = false
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", int(cue.size))
		lbl.add_theme_color_override("font_color", cue.color)
		lbl.add_theme_color_override("font_outline_color", cue.outline)
		var is_blade := str(cue.kind) == "blade"
		lbl.add_theme_constant_override("outline_size", 14 if is_blade else 8)
		if is_blade:
			lbl.add_theme_color_override("font_shadow_color", COLOR_CRIMSON)
			lbl.add_theme_constant_override("shadow_offset_x", 6)
			lbl.add_theme_constant_override("shadow_offset_y", 6)
		_sfx_layer.add_child(lbl)
		_sfx_labels[str(cue.id)] = lbl


func _build_dialogue_layer(font: Font) -> void:
	_dialogue_layer = Control.new()
	_dialogue_layer.name = "DialogueLayer"
	_dialogue_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialogue_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dialogue_layer)

	# 1) P1 下沿黑底细白边（2px）漫画旁白框（whisper，无名签，单行居中）
	_narration_p1_box = PanelContainer.new()
	_narration_p1_box.name = "NarrationP1"
	_narration_p1_box.position = Vector2(48, 524)
	_narration_p1_box.size = Vector2(560, 76)
	_narration_p1_box.visible = false
	_narration_p1_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p1_sb := _panel_box(COLOR_INK, COLOR_PAPER, 2)
	p1_sb.set_content_margin_all(14)
	_narration_p1_box.add_theme_stylebox_override("panel", p1_sb)
	_dialogue_layer.add_child(_narration_p1_box)

	_narration_p1_label = Label.new()
	_narration_p1_label.name = "Text"
	_narration_p1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narration_p1_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_narration_p1_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narration_p1_label.add_theme_font_override("font", font)
	_narration_p1_label.add_theme_font_size_override("font_size", 26)
	_narration_p1_label.add_theme_color_override("font_color", COLOR_PAPER)
	_narration_p1_box.add_child(_narration_p1_label)

	# 2) P11a~c 右侧白底黑粗框尖尾漫画对白气泡＋左上外缘常驻朱红名签
	_speech_group = Control.new()
	_speech_group.name = "SpeechGroup"
	_speech_group.position = Vector2(548, 212)
	_speech_group.size = Vector2(684, 224)
	_speech_group.visible = false
	_speech_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_layer.add_child(_speech_group)

	_speech_bubble_wrap = Control.new()
	_speech_bubble_wrap.name = "SpeechBubbleWrap"
	_speech_bubble_wrap.position = Vector2(0, 0)
	_speech_bubble_wrap.size = Vector2(684, 224)
	_speech_bubble_wrap.pivot_offset = Vector2(342, 112)
	_speech_bubble_wrap.visible = false
	_speech_bubble_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech_group.add_child(_speech_bubble_wrap)

	_speech_bubble_box = PanelContainer.new()
	_speech_bubble_box.name = "SpeechBubble"
	_speech_bubble_box.position = Vector2(20, 28)
	_speech_bubble_box.size = Vector2(664, 168)
	_speech_bubble_box.visible = false
	_speech_bubble_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb_bubble := _panel_box(COLOR_PAPER, COLOR_INK, 5)
	sb_bubble.set_corner_radius_all(6)
	sb_bubble.shadow_color = Color(COLOR_INK.r, COLOR_INK.g, COLOR_INK.b, 0.36)
	sb_bubble.shadow_size = 6
	sb_bubble.shadow_offset = Vector2(6, 7)
	sb_bubble.content_margin_left = 30
	sb_bubble.content_margin_right = 28
	sb_bubble.content_margin_top = 30
	sb_bubble.content_margin_bottom = 22
	_speech_bubble_box.add_theme_stylebox_override("panel", sb_bubble)
	_speech_bubble_wrap.add_child(_speech_bubble_box)

	# 指向左侧破边立绘残格的漫画气泡尖尾（白底盖缝＋5px 黑粗外描边）
	_speech_tail_white = Polygon2D.new()
	_speech_tail_white.name = "SpeechTailFill"
	_speech_tail_white.polygon = PackedVector2Array([
		Vector2(-24, 108),
		Vector2(28, 84),
		Vector2(28, 128),
	])
	_speech_tail_white.color = COLOR_PAPER
	_speech_bubble_wrap.add_child(_speech_tail_white)

	_speech_tail_outline = Line2D.new()
	_speech_tail_outline.name = "SpeechTailOutline"
	_speech_tail_outline.points = PackedVector2Array([
		Vector2(24, 85),
		Vector2(-24, 108),
		Vector2(24, 127),
	])
	_speech_tail_outline.width = 5.0
	_speech_tail_outline.joint_mode = Line2D.LINE_JOINT_SHARP
	_speech_tail_outline.default_color = COLOR_INK
	_speech_bubble_wrap.add_child(_speech_tail_outline)

	# P11b 21.2s 气泡外框右下角单拍幽紫细角（严格在框外，绝不染正文）
	_speech_purple_corner = Line2D.new()
	_speech_purple_corner.name = "BubblePurpleCorner"
	_speech_purple_corner.points = PackedVector2Array([
		Vector2(636, 196),
		Vector2(684, 196),
		Vector2(684, 148),
	])
	_speech_purple_corner.width = 4.0
	_speech_purple_corner.default_color = COLOR_PURPLE
	_speech_purple_corner.visible = false
	_speech_bubble_wrap.add_child(_speech_purple_corner)

	_speech_text_label = Label.new()
	_speech_text_label.name = "Text"
	_speech_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speech_text_label.custom_minimum_size = Vector2(604, 108)
	_speech_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech_text_label.add_theme_font_override("font", font)
	_speech_text_label.add_theme_font_size_override("font_size", 28)
	_speech_text_label.add_theme_color_override("font_color", COLOR_INK)
	_speech_text_label.add_theme_constant_override("outline_size", 0)
	_speech_text_label.add_theme_constant_override("line_spacing", 8)
	_speech_bubble_box.add_child(_speech_text_label)

	# 名签压贴气泡左上外缘，P11a～c 三句连播期间常驻不动
	_speech_nameplate = PanelContainer.new()
	_speech_nameplate.name = "SpeechNameplate"
	_speech_nameplate.position = Vector2(38, 2)
	_speech_nameplate.size = Vector2(148, 42)
	_speech_nameplate.visible = false
	_speech_nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var np_sb := _panel_box(COLOR_INK, COLOR_INK, 2)
	np_sb.content_margin_left = 10
	np_sb.content_margin_right = 14
	np_sb.content_margin_top = 4
	np_sb.content_margin_bottom = 4
	_speech_nameplate.add_theme_stylebox_override("panel", np_sb)
	_speech_group.add_child(_speech_nameplate)

	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_theme_constant_override("separation", 8)
	_speech_nameplate.add_child(name_row)

	var red_bar := ColorRect.new()
	red_bar.name = "SpeakerBar"
	red_bar.color = COLOR_CRIMSON
	red_bar.custom_minimum_size = Vector2(6, 26)
	red_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(red_bar)

	_speech_speaker_label = Label.new()
	_speech_speaker_label.name = "Speaker"
	_speech_speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech_speaker_label.add_theme_font_override("font", font)
	_speech_speaker_label.add_theme_font_size_override("font_size", 22)
	_speech_speaker_label.add_theme_color_override("font_color", COLOR_PAPER)
	name_row.add_child(_speech_speaker_label)

	# 3) P11d 底部居中半透明墨黑底浅银白字（#DCDCE0）漫画收尾旁白条（after，无粗白框、无名签）
	_narration_end_box = PanelContainer.new()
	_narration_end_box.name = "NarrationEnd"
	_narration_end_box.position = Vector2(300, 612)
	_narration_end_box.size = Vector2(680, 64)
	_narration_end_box.visible = false
	_narration_end_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var end_sb := _panel_box(Color(0.043, 0.043, 0.055, 0.86), Color(0, 0, 0, 0), 0)
	end_sb.set_content_margin_all(14)
	_narration_end_box.add_theme_stylebox_override("panel", end_sb)
	_dialogue_layer.add_child(_narration_end_box)

	_narration_end_label = Label.new()
	_narration_end_label.name = "Text"
	_narration_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narration_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_narration_end_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narration_end_label.add_theme_font_override("font", font)
	_narration_end_label.add_theme_font_size_override("font_size", 24)
	_narration_end_label.add_theme_color_override("font_color", COLOR_AFTER_TEXT)
	_narration_end_box.add_child(_narration_end_label)


func _sync_p10_textures() -> void:
	var p9_tex: Texture2D = _p10_end_rect.texture if (_p10_end_rect != null and _p10_end_rect.texture != null) else _get_p9_fallback_tex()
	if _p10_half_tl != null and _p10_half_br != null and p9_tex != null:
		var ts := p9_tex.get_size()
		_p10_half_tl.texture = p9_tex
		_p10_half_tl.uv = _covered_uvs(_p10_half_tl.polygon, STAGE_SIZE, ts, 1.0)
		_p10_half_br.texture = p9_tex
		_p10_half_br.uv = _covered_uvs(_p10_half_br.polygon, STAGE_SIZE, ts, 1.0)
	if _p10_slash_rect != null and _p10_slash_rect.texture == null:
		_p10_slash_rect.texture = _get_m6_fallback_tex()


func _sync_p11_portrait_texture(zoom: float) -> void:
	if _p11_portrait_poly == null:
		return
	var tex: Texture2D = _p11_portrait_rect.texture if (_p11_portrait_rect != null and _p11_portrait_rect.texture != null) else _get_m5a_fallback_tex()
	if tex != null:
		_p11_portrait_poly.texture = tex
		_p11_portrait_poly.uv = _covered_uvs(_p11_portrait_poly.polygon, Vector2(480.0, 440.0), tex.get_size(), zoom)


static func _covered_uvs(pts: PackedVector2Array, box_size: Vector2, tex_size: Vector2, zoom := 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0 or box_size.x <= 0.0 or box_size.y <= 0.0:
		return pts
	var scale_factor := maxf(box_size.x / tex_size.x, box_size.y / tex_size.y) * maxf(zoom, 1.0)
	var shown := box_size / scale_factor
	var origin := (tex_size - shown) * 0.5
	for p in pts:
		var norm := Vector2(p.x / box_size.x, p.y / box_size.y)
		out.append(origin + norm * shown)
	return out


static func _tapered_slash_poly(a: Vector2, b: Vector2, normal: Vector2, mid_half_w: float) -> PackedVector2Array:
	var p1 := a.lerp(b, 0.22)
	var p2 := a.lerp(b, 0.50)
	var p3 := a.lerp(b, 0.78)
	var w1 := mid_half_w * 0.62
	var w2 := mid_half_w
	var w3 := mid_half_w * 0.58
	return PackedVector2Array([
		a,
		p1 + normal * w1,
		p2 + normal * w2,
		p3 + normal * w3,
		b,
		p3 - normal * w3,
		p2 - normal * w2,
		p1 - normal * w1,
	])


static func _soft_cloud_poly(center: Vector2, radii: Vector2, rot: float, seed_idx: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 16
	for k in range(steps):
		var ang := float(k) * TAU / float(steps)
		var lobe := 0.84 + 0.16 * sin(ang * 3.0 + float(seed_idx) * 1.4) + 0.08 * cos(ang * 5.0 - float(seed_idx))
		var local := Vector2(cos(ang) * radii.x * lobe, sin(ang) * radii.y * lobe).rotated(rot)
		pts.append(center + local)
	return pts


static func _ease_out_back_subtle(u: float) -> float:
	var t := clampf(u, 0.0, 1.0)
	var c1 := 1.15
	var c3 := c1 + 1.0
	var x := t - 1.0
	return 1.0 + c3 * x * x * x + c1 * x * x


static func _panel_box(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	return sb


static func _shard_color_ramp() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.72, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(0.86, 0.86, 0.88, 0.92),
		Color(0.80, 0.80, 0.84, 0.0),
	])
	return g


## P10 0.10s 反色冲击帧轻量着色器（兼容 gl_compatibility，仅作用于两半 P9 多边形，不遮挡真实 Map004）
static func _get_invert_shader() -> Shader:
	if _invert_shader == null:
		_invert_shader = Shader.new()
		_invert_shader.code = """shader_type canvas_item;
uniform float invert_amount : hint_range(0.0, 1.0) = 0.0;
varying vec4 v_mod;
void vertex() {
	v_mod = COLOR;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 inv = vec3(1.0) - c.rgb;
	COLOR = vec4(mix(c.rgb, inv, invert_amount) * v_mod.rgb, c.a * v_mod.a);
}
"""
	return _invert_shader


## 黑白网点斜切碎纸片粒子纹理（28×22，供 P10 与 P11d 共享）
static func _get_shard_particle_tex() -> Texture2D:
	if _cached_shard_tex != null:
		return _cached_shard_tex
	var w := 28
	var h := 22
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(h):
		var x0 := int(round(lerpf(4.0, 1.0, float(y) / float(h))))
		var x1 := int(round(lerpf(25.0, 20.0, float(y) / float(h))))
		for x in range(x0, x1):
			var on_edge := (y <= 1 or y >= h - 2 or x <= x0 + 1 or x >= x1 - 2)
			if on_edge:
				img.set_pixel(x, y, COLOR_INK)
			elif ((x + y) % 4 == 0 and (x - y) % 4 == 0):
				img.set_pixel(x, y, COLOR_GRAY_DARK)
			else:
				img.set_pixel(x, y, COLOR_PAPER)
	_cached_shard_tex = ImageTexture.create_from_image(img)
	return _cached_shard_tex


## P1 无视口传入时的程序占位方桌大厅底图（含中心二阶幽紫漩涡，验证网点与中心微紫留色）
static func _get_p1_fallback_tex() -> Texture2D:
	if _cached_p1_fallback_tex != null:
		return _cached_p1_fallback_tex
	var w := 320
	var h := 180
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.68, 0.66, 0.62, 1.0))
	# 石砖网格
	for x in range(0, w, 24):
		img.fill_rect(Rect2i(x, 0, 2, h), Color(0.36, 0.35, 0.34, 1.0))
	for y in range(0, h, 24):
		img.fill_rect(Rect2i(0, y, w, 2), Color(0.36, 0.35, 0.34, 1.0))
	# 方桌与围栏轮廓
	img.fill_rect(Rect2i(110, 56, 100, 68), Color(0.42, 0.30, 0.20, 1.0))
	img.fill_rect(Rect2i(116, 62, 88, 56), Color(0.76, 0.64, 0.48, 1.0))
	# 中心二阶幽紫漩涡
	var center := Vector2(160.0, 88.0)
	for y in range(60, 116):
		for x in range(132, 188):
			var d := Vector2(x, y).distance_to(center)
			if d < 24.0:
				var a := atan2(float(y) - center.y, float(x) - center.x)
				var spiral := sin(d * 0.45 + a * 3.0)
				img.set_pixel(x, y, COLOR_PURPLE_BRIGHT if spiral > 0.25 else COLOR_PURPLE)
	_cached_p1_fallback_tex = ImageTexture.create_from_image(img)
	return _cached_p1_fallback_tex


## P9 尾帧缺图时的黑白漫画拔刀特写程序占位画页（320×180：墨黑页边＋粗白斜框＋放射集中线＋寒刃白锋＋朱红飘带）
static func _get_p9_fallback_tex() -> Texture2D:
	if _cached_p9_fallback_tex != null:
		return _cached_p9_fallback_tex
	var w := 320
	var h := 180
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(COLOR_INK)
	var clip := Rect2i(19, 28, 282, 124)
	# 居中 P9 粗白大格 (15, 24, 290×132)
	img.fill_rect(Rect2i(15, 24, 290, 132), COLOR_PAPER)
	img.fill_rect(Rect2i(18, 27, 284, 126), Color(0.08, 0.08, 0.10, 1.0))
	# 放射集中线（向出鞘刀锋中心汇聚）
	var center := Vector2(188.0, 92.0)
	for i in range(52):
		var ang := float(i) * TAU / 52.0
		var r0 := 30.0 + float(i % 5) * 8.0
		var col := COLOR_PAPER if (i % 3 != 0) else COLOR_GRAY_DARK
		_draw_img_line(img, center + Vector2(cos(ang), sin(ang)) * r0, center + Vector2(cos(ang), sin(ang)) * 195.0, col, clip)
	# 左侧斜肩白衣剪影与飘扬墨发（流线轮廓，非方盒）
	_fill_img_disc(img, Vector2(96, 148), 58.0, 44.0, COLOR_PAPER, clip)
	_fill_img_disc(img, Vector2(104, 82), 26.0, 30.0, COLOR_PAPER, clip)
	_fill_img_disc(img, Vector2(96, 68), 28.0, 22.0, COLOR_INK, clip)
	_draw_img_ribbon(img, Vector2(114, 58), Vector2(36, 42), 5.0, COLOR_CRIMSON, clip)
	_draw_img_ribbon(img, Vector2(114, 62), Vector2(24, 72), 3.5, COLOR_CRIMSON, clip)
	# 凌厉斜出鞘寒刃＋刀锷＋红绳刀柄
	for k in range(-3, 4):
		var col := COLOR_PAPER if abs(k) <= 1 else COLOR_GRAY_LIGHT
		_draw_img_line(img, Vector2(138, 126 + k), Vector2(294, 58 + k), col, clip)
	_draw_img_line(img, Vector2(134, 114), Vector2(146, 138), COLOR_INK, clip)
	_draw_img_line(img, Vector2(135, 114), Vector2(147, 138), COLOR_PAPER, clip)
	_draw_img_ribbon(img, Vector2(84, 144), Vector2(138, 126), 4.0, COLOR_CRIMSON, clip)
	_cached_p9_fallback_tex = ImageTexture.create_from_image(img)
	return _cached_p9_fallback_tex


## M6 透明挥斩缺图时的程序占位（256×200，纯透明底＋飞白大弧刀光＋炽烈朱红飘带残影）
static func _get_m6_fallback_tex() -> Texture2D:
	if _cached_m6_fallback_tex != null:
		return _cached_m6_fallback_tex
	var w := 256
	var h := 200
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bounds := Rect2i(0, 0, w, h)
	# 凌厉飞白弯月大刀弧（右上→左下，首尾收尖）
	for step_i in range(180):
		var u := float(step_i) / 179.0
		var bell := sin(u * PI)
		var p := Vector2(lerpf(238.0, 18.0, u), lerpf(16.0, 184.0, u))
		var arc := Vector2(-bell * 40.0, -bell * 22.0)
		var q := p + arc
		var r_w := maxf(bell * 12.0, 1.2)
		_fill_img_disc(img, q + Vector2(6.0, 8.0), r_w * 0.9, r_w * 0.55, COLOR_CRIMSON, bounds)
		_fill_img_disc(img, q, r_w, r_w * 0.52, COLOR_PAPER, bounds)
		if bell > 0.35:
			_fill_img_disc(img, q - Vector2(3.0, 4.0), r_w * 0.32, r_w * 0.2, COLOR_INK, bounds)
	# 一缕穿弧而过的朱红长飘带
	_draw_img_ribbon(img, Vector2(216, 26), Vector2(72, 168), 3.6, COLOR_CRIMSON, bounds)
	_draw_img_ribbon(img, Vector2(186, 48), Vector2(118, 128), 2.2, COLOR_INK, bounds)
	_cached_m6_fallback_tex = ImageTexture.create_from_image(img)
	return _cached_m6_fallback_tex


## M5a 定妆图缺图时的程序占位（240×220，硬派黑白漫画侧影＋高束墨发＋朱红发带与斜掠红带＋寒刃高光）
static func _get_m5a_fallback_tex() -> Texture2D:
	if _cached_m5a_fallback_tex != null:
		return _cached_m5a_fallback_tex
	var w := 240
	var h := 220
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(COLOR_INK)
	var bounds := Rect2i(0, 0, w, h)
	# 背景放射黑白集中线＋半调微点
	var center := Vector2(118.0, 88.0)
	for i in range(40):
		var ang := float(i) * TAU / 40.0
		var col := COLOR_GRAY_DARK if (i % 2 == 0) else COLOR_GRAY_LIGHT
		_draw_img_line(img, center + Vector2(cos(ang), sin(ang)) * 38.0, center + Vector2(cos(ang), sin(ang)) * 175.0, col, bounds)
	# 飘扬长发与高束发冠轮廓
	_fill_img_disc(img, Vector2(96, 62), 34.0, 32.0, COLOR_INK, bounds)
	_fill_img_disc(img, Vector2(72, 92), 28.0, 42.0, COLOR_INK, bounds)
	_fill_img_disc(img, Vector2(102, 26), 14.0, 12.0, COLOR_INK, bounds)
	# 素白宽肩侠袍（流线斜肩＋墨线衣褶）
	_fill_img_disc(img, Vector2(112, 194), 76.0, 74.0, COLOR_PAPER, bounds)
	_fill_img_disc(img, Vector2(112, 124), 46.0, 34.0, COLOR_PAPER, bounds)
	# 俊朗侧颜剪影（白面＋锐利眉眼与高领阴影）
	_fill_img_disc(img, Vector2(116, 68), 22.0, 26.0, COLOR_PAPER, bounds)
	_fill_img_disc(img, Vector2(96, 56), 24.0, 18.0, COLOR_INK, bounds)
	_draw_img_line(img, Vector2(118, 66), Vector2(133, 63), COLOR_INK, bounds)
	_draw_img_line(img, Vector2(119, 67), Vector2(132, 65), COLOR_INK, bounds)
	_draw_img_line(img, Vector2(104, 92), Vector2(128, 122), COLOR_INK, bounds)
	_draw_img_line(img, Vector2(126, 94), Vector2(108, 124), COLOR_INK, bounds)
	# 绯红领缘＋飞扬朱红发带＋前景斜掠长红带
	_draw_img_ribbon(img, Vector2(96, 102), Vector2(134, 106), 3.6, COLOR_CRIMSON, bounds)
	_draw_img_ribbon(img, Vector2(104, 34), Vector2(224, 18), 4.2, COLOR_CRIMSON, bounds)
	_draw_img_ribbon(img, Vector2(102, 40), Vector2(204, 52), 2.8, COLOR_CRIMSON, bounds)
	_draw_img_ribbon(img, Vector2(28, 188), Vector2(208, 122), 4.5, COLOR_CRIMSON, bounds)
	# 佩刀出鞘雪白寒锋一闪
	for k in range(-2, 3):
		_draw_img_line(img, Vector2(112, 178 + k), Vector2(220, 140 + k), COLOR_PAPER if abs(k) <= 1 else COLOR_GRAY_LIGHT, bounds)
	_cached_m5a_fallback_tex = ImageTexture.create_from_image(img)
	return _cached_m5a_fallback_tex


static func _fill_img_disc(img: Image, center: Vector2, rx: float, ry: float, col: Color, clip: Rect2i) -> void:
	var x0 := clampi(int(floor(center.x - rx)), clip.position.x, clip.end.x - 1)
	var x1 := clampi(int(ceil(center.x + rx)), clip.position.x, clip.end.x - 1)
	var y0 := clampi(int(floor(center.y - ry)), clip.position.y, clip.end.y - 1)
	var y1 := clampi(int(ceil(center.y + ry)), clip.position.y, clip.end.y - 1)
	var inv_rx := 1.0 / maxf(rx, 1.0)
	var inv_ry := 1.0 / maxf(ry, 1.0)
	for y in range(y0, y1 + 1):
		var dy := (float(y) - center.y) * inv_ry
		var dy2 := dy * dy
		if dy2 > 1.0:
			continue
		for x in range(x0, x1 + 1):
			var dx := (float(x) - center.x) * inv_rx
			if dx * dx + dy2 <= 1.0:
				img.set_pixel(x, y, col)


static func _draw_img_ribbon(img: Image, a: Vector2, b: Vector2, half_w: float, col: Color, clip: Rect2i) -> void:
	var steps: int = maxi(int(ceil(a.distance_to(b))), 1)
	for s in range(steps + 1):
		var u := float(s) / float(steps)
		var wave := sin(u * PI * 1.5) * 6.0
		var p := a.lerp(b, u) + Vector2(0.0, wave)
		var r := maxf(half_w * (1.0 - 0.45 * u), 1.0)
		_fill_img_disc(img, p, r, r, col, clip)


static func _draw_img_line(img: Image, a: Vector2, b: Vector2, col: Color, clip: Rect2i) -> void:
	var dist := int(ceil(a.distance_to(b)))
	if dist <= 0:
		return
	for s in range(dist + 1):
		var p := a.lerp(b, float(s) / float(dist))
		var xi := int(round(p.x))
		var yi := int(round(p.y))
		if clip.has_point(Vector2i(xi, yi)):
			img.set_pixel(xi, yi, col)
