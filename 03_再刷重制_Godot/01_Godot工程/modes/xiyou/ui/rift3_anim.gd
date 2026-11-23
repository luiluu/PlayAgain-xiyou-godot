class_name XRift3Anim
extends CanvasLayer
## 【小A·未经审查】二阶到三阶徐凤年回归漫画动画播放器骨架（T425；分镜 v0.5 拆卡 2，文字按 v0.5 第 7 节 T426 定稿）。
## - 全片 26.0 秒、四段状态机：P1 实时入格（0.0–2.6s）→ P2～P9 离线 .ogv（2.6–15.0s）→
##   P10 实时劈页（15.0–17.3s）→ P11 破框残格三连对白与碎页收尾（17.3–26.0s）。
## - 资源守卫 available()：同时校验开关、XRift.STAGE3（并兼容读取 XRift.RIFT3_ANIM）及 4 个必需文件；
##   缺任一资源时返回 false 不报错，由上层事件回退原像素过场。
## - 抗变速齿轮：时间推进与视频播放速度均除掉 maxf(Engine.time_scale, 0.001)，按真实秒计时。
## - 跳过与补播：0.0–0.8s 保护期吃掉输入不跳过；0.8s 后任意按键／点击／触屏／手柄按一次即触发 0.25s 压黑退出，
##   并按跳过瞬间的时间码把未看全的句键按序写入静态 missed_lines；自然播满 26.0s 时 missed_lines 为空。
## - 5 句台词正文与名签运行时直读 XRift.RIFT3_LINES（零重复写死）；7 处拟声字＋1 处刀意字「斩」按 v0.5 时间码叠字。
## - 本单先提供程序占位可视化跑通整条 26.0s 链路，P1 网点 Shader／P10 劈页粒子／P11 残格美术由后续拆卡 3 接续增强。

signal finished

## 回退总开关：false 时 available() 恒为 false（兼容后续拆卡 5 在 XRift 增设 RIFT3_ANIM 开关）
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
	{"id": "p10_slash", "panel": "P10", "kind": "blade", "text": "斩",     "start": 15.0, "end": 15.45, "pos": Vector2(560, 240), "size": 84, "color": COLOR_PAPER, "outline": COLOR_INK,         "rot_deg": -18.0},
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

static var _re_speaker: RegEx = null
static var _re_mv_code: RegEx = null

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

var _root: Control
var _stage_layer: Control
var _p1_layer: Control
var _p1_tex_rect: TextureRect
var _mid_layer: Control
var _video_player: VideoStreamPlayer
var _mid_placeholder_box: Panel
var _mid_placeholder_label: Label
var _p10_layer: Control
var _p10_end_rect: TextureRect
var _p10_slash_rect: TextureRect
var _p10_slash_bar: ColorRect
var _p11_layer: Control
var _p11_dim: ColorRect
var _p11_portrait_box: Panel
var _p11_portrait_rect: TextureRect
var _sfx_layer: Control
var _sfx_labels := {}              # cue id -> Label
var _dialogue_layer: Control
var _narration_p1_box: PanelContainer
var _narration_p1_label: Label
var _speech_group: Control         # P11a～c 气泡与常驻名签容器
var _speech_nameplate: PanelContainer  # 左上外缘名签（P11a～c 常驻不闪烁）
var _speech_speaker_label: Label
var _speech_bubble_box: PanelContainer
var _speech_text_label: Label
var _narration_end_box: PanelContainer
var _narration_end_label: Label
var _fade_rect: ColorRect
var _sfx_player: AudioStreamPlayer


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
	if _viewport_tex != null and _p1_tex_rect != null:
		_p1_tex_rect.texture = _viewport_tex
	_speech_speaker_label.text = str(parse_rift_line("sense").speaker)
	_load_optional_assets()
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
	_sync_sfx_cues()
	_sync_dialogue_cues()

	# P11d（24.7s 起）左侧破边立绘残格退场，末 0.3s 平滑收尾淡出
	if _phase == Phase.P11:
		var in_p11d := _t >= PHASE_P11D_START
		_p11_portrait_box.visible = not in_p11d
		var end_alpha := 1.0
		if _t > TOTAL_DURATION - END_FADE_SEC:
			end_alpha = clampf((TOTAL_DURATION - _t) / END_FADE_SEC, 0.0, 1.0)
		_p11_dim.color.a = (0.12 if in_p11d else 0.24) * end_alpha
		_dialogue_layer.modulate.a = end_alpha
	else:
		_dialogue_layer.modulate.a = 1.0


func _sync_panel_placeholder() -> void:
	if _phase == Phase.P1:
		_active_panel = "P1"
		return
	if _phase == Phase.P10:
		_active_panel = "P10"
		if _p10_slash_bar != null:
			_p10_slash_bar.visible = (_t < 15.55)
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
		lbl.visible = (_t >= float(cue.start) and _t < float(cue.end))


func _sync_dialogue_cues() -> void:
	_narration_p1_box.visible = false
	_speech_bubble_box.visible = false
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
				# v0.5：名签常驻，正文整句即显（≤0.12s 弹入，禁逐字打字机）
				if speaker != "":
					_speech_speaker_label.text = speaker
				_speech_text_label.text = text
				_speech_text_label.visible_ratio = 1.0
				_speech_bubble_box.modulate.a = clampf((_t - c_start) / 0.12, 0.0, 1.0)
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

	var gutter := ColorRect.new()
	gutter.name = "Gutter"
	gutter.color = COLOR_INK
	gutter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p1_layer.add_child(gutter)

	var frame := Panel.new()
	frame.name = "LeftPanel"
	frame.position = Vector2(48, 56)
	frame.size = Vector2(560, 440)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _panel_box(Color(0.14, 0.14, 0.16, 1.0), COLOR_PAPER, 5))
	_p1_layer.add_child(frame)

	_p1_tex_rect = TextureRect.new()
	_p1_tex_rect.name = "ViewportTex"
	_p1_tex_rect.position = Vector2(5, 5)
	_p1_tex_rect.size = Vector2(550, 430)
	_p1_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_p1_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_p1_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_p1_tex_rect)


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
	_p10_layer = Control.new()
	_p10_layer.name = "PhaseP10"
	_p10_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_p10_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p10_layer.visible = false
	_stage_layer.add_child(_p10_layer)

	_p10_end_rect = TextureRect.new()
	_p10_end_rect.name = "P9EndTex"
	_p10_end_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_p10_end_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_p10_end_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_p10_end_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p10_layer.add_child(_p10_end_rect)

	_p10_slash_rect = TextureRect.new()
	_p10_slash_rect.name = "M6SlashTex"
	_p10_slash_rect.position = Vector2(210, 20)
	_p10_slash_rect.size = Vector2(860, 680)
	_p10_slash_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_p10_slash_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_p10_slash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p10_layer.add_child(_p10_slash_rect)

	_p10_slash_bar = ColorRect.new()
	_p10_slash_bar.name = "SlashGlow"
	_p10_slash_bar.color = COLOR_PAPER
	_p10_slash_bar.position = Vector2(0, 350)
	_p10_slash_bar.size = Vector2(1500, 14)
	_p10_slash_bar.rotation_degrees = -28.0
	_p10_slash_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p10_layer.add_child(_p10_slash_bar)


func _build_phase_p11(font: Font) -> void:
	_p11_layer = Control.new()
	_p11_layer.name = "PhaseP11"
	_p11_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_p11_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p11_layer.visible = false
	_stage_layer.add_child(_p11_layer)

	_p11_dim = ColorRect.new()
	_p11_dim.name = "LobbyDim"
	_p11_dim.color = Color(0.04, 0.04, 0.06, 0.24)
	_p11_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_p11_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p11_layer.add_child(_p11_dim)

	_p11_portrait_box = Panel.new()
	_p11_portrait_box.name = "PortraitShard"
	_p11_portrait_box.position = Vector2(44, 132)
	_p11_portrait_box.size = Vector2(480, 440)
	_p11_portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p11_portrait_box.add_theme_stylebox_override("panel", _panel_box(COLOR_INK, COLOR_PAPER, 6))
	_p11_layer.add_child(_p11_portrait_box)

	var red_stripe := ColorRect.new()
	red_stripe.name = "CrimsonAccent"
	red_stripe.color = COLOR_CRIMSON
	red_stripe.position = Vector2(8, 8)
	red_stripe.size = Vector2(8, 424)
	red_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p11_portrait_box.add_child(red_stripe)

	_p11_portrait_rect = TextureRect.new()
	_p11_portrait_rect.name = "M5aPortraitTex"
	_p11_portrait_rect.position = Vector2(18, 6)
	_p11_portrait_rect.size = Vector2(456, 428)
	_p11_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_p11_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_p11_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p11_portrait_box.add_child(_p11_portrait_rect)

	var tag := Label.new()
	tag.name = "PortraitPlaceholderTag"
	tag.text = "P11"
	tag.position = Vector2(24, 14)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_font_override("font", font)
	tag.add_theme_font_size_override("font_size", 20)
	tag.add_theme_color_override("font_color", COLOR_GRAY_DARK)
	_p11_portrait_box.add_child(tag)


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
		lbl.add_theme_constant_override("outline_size", 12 if is_blade else 8)
		if is_blade:
			lbl.add_theme_color_override("font_shadow_color", COLOR_CRIMSON)
			lbl.add_theme_constant_override("shadow_offset_x", 5)
			lbl.add_theme_constant_override("shadow_offset_y", 5)
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

	# 2) P11a~c 右侧白底黑粗框漫画对白气泡＋左上外缘常驻朱红名签
	_speech_group = Control.new()
	_speech_group.name = "SpeechGroup"
	_speech_group.position = Vector2(556, 200)
	_speech_group.size = Vector2(668, 280)
	_speech_group.visible = false
	_speech_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_layer.add_child(_speech_group)

	_speech_bubble_box = PanelContainer.new()
	_speech_bubble_box.name = "SpeechBubble"
	_speech_bubble_box.position = Vector2(0, 26)
	_speech_bubble_box.size = Vector2(668, 224)
	_speech_bubble_box.visible = false
	_speech_bubble_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb_bubble := _panel_box(COLOR_PAPER, COLOR_INK, 5)
	sb_bubble.set_corner_radius_all(6)
	sb_bubble.content_margin_left = 26
	sb_bubble.content_margin_right = 26
	sb_bubble.content_margin_top = 34
	sb_bubble.content_margin_bottom = 22
	_speech_bubble_box.add_theme_stylebox_override("panel", sb_bubble)
	_speech_group.add_child(_speech_bubble_box)

	_speech_text_label = Label.new()
	_speech_text_label.name = "Text"
	_speech_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech_text_label.custom_minimum_size = Vector2(606, 0)
	_speech_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech_text_label.add_theme_font_override("font", font)
	_speech_text_label.add_theme_font_size_override("font_size", 28)
	_speech_text_label.add_theme_color_override("font_color", COLOR_INK)
	_speech_text_label.add_theme_constant_override("outline_size", 0)
	_speech_bubble_box.add_child(_speech_text_label)

	# 名签压贴气泡左上外缘，P11a～c 三句连播期间常驻不动
	_speech_nameplate = PanelContainer.new()
	_speech_nameplate.name = "SpeechNameplate"
	_speech_nameplate.position = Vector2(18, 0)
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
	_narration_end_box.position = Vector2(300, 608)
	_narration_end_box.size = Vector2(680, 68)
	_narration_end_box.visible = false
	_narration_end_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var end_sb := _panel_box(Color(0.043, 0.043, 0.055, 0.84), Color(0, 0, 0, 0), 0)
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


static func _panel_box(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	return sb
