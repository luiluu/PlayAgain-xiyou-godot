class_name XRift3Anim
extends CanvasLayer
## 【小A·未经审查】二阶到三阶徐凤年回归漫画动画播放器与全套定稿素材合成舞台（T425＋T428＋T429；分镜 v0.6 定稿）。
## - 全片 30.5 秒、7 幕画页、15 格四段状态机：P1 实时入格（0.0–2.6s）→ P2～P9b 动态漫画中段（2.6–19.5s，含 T437 新增
##   P8a 落地对峙／P8b 怪扑侧闪／P9a 刀爪相撞／P9b 斩怪化雾与 M5b 30 帧拔刀寒光序列）→ P10 实时劈页（19.5–21.8s，
##   以第 6 页 P9b 定格尾帧 rift3_mid_end.webp 为纹理源＋镜像 M6 右上→左下破框挥斩）→ P11 破框残格三连对白与碎页收尾（21.8–30.5s）。
## - 5 句审定台词正文直读 XRift.RIFT3_LINES 一字不改，后 4 句时间轴整体顺延 +4.5s，跳过补播阈值同步对齐（1.0s/15.0s/27.5s）。
## - 11 处实时叠字：原 8 处（T426 定稿）不变；新增 3 处（P8b 嗖！／P9a 铿！／P9b 嗤！，2026-11-23 小A·文字审定定稿）保留独立常量。
## - 资源守卫 available()（解决 T430 核 P3-2 门槛：全套 19 项核心 WebP 入仓就绪即返回 true，缺任一项或关开关安全回退 false）。

signal finished

## 回退总开关：false 时 available() 恒为 false
static var ENABLED := true
## 跳过后待事件层补播的句键列表（按 LINE_ORDER 顺序）；每次开播前清空，自然播满 30.5s 为空
static var missed_lines: Array[String] = []
## 专项测试专用：覆盖资源存在性判定（默认空 Callable，走 ResourceLoader.exists）
static var _asset_exists_override: Callable = Callable()

const LAYER := 88                  # 盖过地图黑幕（80），位于 XMoviePlayer（89）／XToast（90）下方
const NODE_NAME := "XRift3Anim"
const STAGE_SIZE := Vector2(1280, 720)

const TOTAL_DURATION := 30.5
const PHASE_P1_END := 2.6
const PHASE_MID_END := 19.5        # v0.6：P2～P9b 共 16.9s（较 v0.5 净增 +4.5s）
const PHASE_P10_END := 21.8        # v0.6：P10 实时劈页 2.3s（19.5–21.8s）
const P11B_START := 24.3
const P11B_PURPLE_FLASH := 25.7    # v0.6：P11b 残格破边单拍微紫闪中心时刻（原 21.2s +4.5s）
const P11C_START := 27.0
const PHASE_P11D_START := 29.2     # v0.6：P11d 碎纸收尾起始（原 24.7s +4.5s）
const SKIP_GUARD_SEC := 0.8
const SKIP_FADE_SEC := 0.25
const END_FADE_SEC := 0.3
const FIRST_FRAME_SPIKE_SEC := 0.105   # P3-2：开播首帧载图若引发 >105ms 卡顿尖峰，夹至 1/30s 防跳过 P1 开头
const FIRST_FRAME_CLAMP_SEC := 1.0 / 30.0

## P1 / P10 / P11 视觉参数与粒子硬上限（P10 96 ＋ P11d 20 = 116 <= 120）
const SHADER_HALFTONE := "res://modes/xiyou/ui/shaders/comic_halftone.gdshader"
const P1_TARGET_RECT := Rect2(48, 56, 560, 440)
const P1_SHRINK_SEC := 0.30
const P10_CUT_TOP_X := 1120.0
const P10_CUT_BOT_X := 160.0
const P10_SHARD_AMOUNT := 96
const P11_SHARD_AMOUNT := 20
const MAX_TOTAL_SHARDS := 120

## M5b 拔刀寒光抽帧图集规格（5 张 × 2×3 格 = 30 帧 @ 12fps，单帧 960×440）
const M5B_FRAME_SIZE := Vector2(960.0, 440.0)
const M5B_COLS := 2
const M5B_FRAMES_PER_SHEET := 6
const M5B_TOTAL_FRAMES := 30
const P9_START := 14.6
const P9_DURATION := 2.5

## 全套定稿素材路径（落盘于 content/rift3/）
const ASSET_DIR := "res://content/rift3/"
const TEX_M1_1 := "res://content/rift3/rift3_m1_1.webp"
const TEX_M1_2 := "res://content/rift3/rift3_m1_2.webp"
const TEX_M1_3 := "res://content/rift3/rift3_m1_3.webp"
const TEX_M1_4 := "res://content/rift3/rift3_m1_4.webp"
const TEX_M2_MOB := "res://content/rift3/rift3_m2_mob.webp"
const TEX_M3_SKY := "res://content/rift3/rift3_m3_sky.webp"
const TEX_M4_DIVE := "res://content/rift3/rift3_m4_dive.webp"
const TEX_M7_P8A := "res://content/rift3/rift3_m7_p8a.webp"
const TEX_M8_P8B := "res://content/rift3/rift3_m8_p8b.webp"
const TEX_M5B_SHEETS: Array[String] = [
	"res://content/rift3/rift3_m5b_sheet_0.webp",
	"res://content/rift3/rift3_m5b_sheet_1.webp",
	"res://content/rift3/rift3_m5b_sheet_2.webp",
	"res://content/rift3/rift3_m5b_sheet_3.webp",
	"res://content/rift3/rift3_m5b_sheet_4.webp",
]
const TEX_M9_P9A := "res://content/rift3/rift3_m9_p9a.webp"
const TEX_M10_P9B := "res://content/rift3/rift3_m10_p9b.webp"
const TEX_MID_END := "res://content/rift3/rift3_mid_end.webp"
const TEX_P9_END := TEX_MID_END   # 兼容旧引用别名（指向第 6 页 P9b 尾帧）
const TEX_M6_SLASH := "res://content/rift3/rift3_m6_slash.webp"
const TEX_M5A_PORTRAIT := "res://content/rift3/rift3_m5a_portrait.webp"
const AUDIO_SFX := "res://content/rift3/rift3_comic_sfx.ogg"
const VIDEO_MID := "res://content/rift3/rift3_comic_mid.ogv"  # 可选外部整段视频覆盖口（默认走实时 WebP 合成舞台）

## 19 项核心视觉素材（全齐 available() 才为真；缺任一项返回 false 安全回退原像素过场）
const REQUIRED_ASSETS: Array[String] = [
	TEX_M1_1,
	TEX_M1_2,
	TEX_M1_3,
	TEX_M1_4,
	TEX_M2_MOB,
	TEX_M3_SKY,
	TEX_M4_DIVE,
	TEX_M7_P8A,
	TEX_M8_P8B,
	"res://content/rift3/rift3_m5b_sheet_0.webp",
	"res://content/rift3/rift3_m5b_sheet_1.webp",
	"res://content/rift3/rift3_m5b_sheet_2.webp",
	"res://content/rift3/rift3_m5b_sheet_3.webp",
	"res://content/rift3/rift3_m5b_sheet_4.webp",
	TEX_M9_P9A,
	TEX_M10_P9B,
	TEX_MID_END,
	TEX_M6_SLASH,
	TEX_M5A_PORTRAIT,
]

## 三色配色规范（黑白线稿网点／幽紫／朱红）＋ v0.5/v0.6 审定 after 浅银白字色
const COLOR_INK := Color("0b0b0e")
const COLOR_PAPER := Color("f4f2ec")
const COLOR_GRAY_DARK := Color("6e6e75")
const COLOR_GRAY_LIGHT := Color("b8b8be")
const COLOR_AFTER_TEXT := Color("dcdce0")       # P11d after 浅银白字色
const COLOR_PURPLE := Color(0.56, 0.36, 0.92)   # #8F5CEB，同 XLobbyCorruption.PURPLE
const COLOR_PURPLE_DARK := Color("341956")
const COLOR_PURPLE_BRIGHT := Color("c29bff")
const COLOR_CRIMSON := Color("c8282e")
const COLOR_CRIMSON_BRIGHT := Color("f04444")

## v0.6 新增斩怪交互格 3 处拟声字（独立常量，2026-11-23 已由小A·文字审定定稿；P8a 留白无字）
const SFX_P8B := "嗖！"
const SFX_P9A := "铿！"
const SFX_P9B := "嗤！"

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

## 5 句定稿台词顺序与漫画内显示时段／已看全阈值（正文直读 XRift.RIFT3_LINES，后 4 句顺延 +4.5s）
const LINE_ORDER: Array[String] = ["whisper", "sense", "hint", "follow", "after"]
const DIALOGUE_CUES: Array[Dictionary] = [
	{"key": "whisper", "start": 0.4,  "end": 2.4,  "seen_at": 2.2,  "style": "narration_p1",  "show_speaker": false},
	{"key": "sense",   "start": 21.9, "end": 24.2, "seen_at": 23.9, "style": "speech_bubble", "show_speaker": true},
	{"key": "hint",    "start": 24.4, "end": 26.9, "seen_at": 26.6, "style": "speech_bubble", "show_speaker": true},
	{"key": "follow",  "start": 27.1, "end": 29.1, "seen_at": 28.8, "style": "speech_bubble", "show_speaker": true},
	{"key": "after",   "start": 29.2, "end": 30.4, "seen_at": 30.2, "style": "narration_end", "show_speaker": false},
]

## 11 处漫画实时叠字时间码（原 8 处 T426 定稿＋新格 3 处小A·文字审定定稿；10 拟声＋1 唯一刀意字「斩」）
const SFX_CUES: Array[Dictionary] = [
	{"id": "p2_hum",     "panel": "P2",  "kind": "sfx",   "text": "嗡——",  "start": 2.8,   "end": 4.3,   "pos": Vector2(930, 118),  "size": 46, "color": COLOR_INK,   "outline": COLOR_PURPLE,      "rot_deg": -6.0},
	{"id": "p3_crack",   "panel": "P3",  "kind": "sfx",   "text": "咔嚓！", "start": 4.5,   "end": 6.1,   "pos": Vector2(860, 520),  "size": 54, "color": COLOR_PAPER, "outline": COLOR_PURPLE,      "rot_deg": 5.0},
	{"id": "p4_rip",     "panel": "P4",  "kind": "sfx",   "text": "嘶啦！", "start": 6.3,   "end": 7.5,   "pos": Vector2(180, 170),  "size": 52, "color": COLOR_PAPER, "outline": COLOR_PURPLE_DARK, "rot_deg": -10.0},
	{"id": "p5_boom",    "panel": "P5",  "kind": "sfx",   "text": "轰——！", "start": 7.7,   "end": 9.5,   "pos": Vector2(830, 480),  "size": 64, "color": COLOR_INK,   "outline": COLOR_PAPER,       "rot_deg": -8.0},
	{"id": "p6_whoosh",  "panel": "P6",  "kind": "sfx",   "text": "唰！",   "start": 9.65,  "end": 10.45, "pos": Vector2(950, 92),   "size": 50, "color": COLOR_PAPER, "outline": COLOR_CRIMSON,     "rot_deg": -14.0},
	{"id": "p8_zheng",   "panel": "P8",  "kind": "sfx",   "text": "铮！",   "start": 11.4,  "end": 12.45, "pos": Vector2(160, 440),  "size": 56, "color": COLOR_PAPER, "outline": COLOR_INK,         "rot_deg": -12.0},
	{"id": "p8b_dodge",  "panel": "P8b", "kind": "sfx",   "text": SFX_P8B,  "start": 13.7,  "end": 14.55, "pos": Vector2(468, 566),  "size": 54, "color": COLOR_PAPER, "outline": COLOR_CRIMSON,     "rot_deg": -14.0, "sharp": true},
	{"id": "p9_clang",   "panel": "P9",  "kind": "sfx",   "text": "锵——！", "start": 14.8,  "end": 16.8,  "pos": Vector2(880, 126),  "size": 62, "color": COLOR_PAPER, "outline": COLOR_INK,         "rot_deg": -6.0},
	{"id": "p9a_clash",  "panel": "P9a", "kind": "sfx",   "text": SFX_P9A,  "start": 17.15, "end": 18.15, "pos": Vector2(330, 290),  "size": 58, "color": COLOR_PAPER, "outline": COLOR_INK,         "rot_deg": -10.0, "crimson_shadow": true},
	{"id": "p9b_cleave", "panel": "P9b", "kind": "sfx",   "text": SFX_P9B,  "start": 18.3,  "end": 19.45, "pos": Vector2(1030, 352), "size": 56, "color": COLOR_PAPER, "outline": COLOR_PURPLE,      "rot_deg": -8.0},
	{"id": "p10_slash",  "panel": "P10", "kind": "blade", "text": "斩",     "start": 19.5,  "end": 19.95, "pos": Vector2(560, 240),  "size": 88, "color": COLOR_PAPER, "outline": COLOR_INK,         "rot_deg": -18.0},
]

## P2～P9b 中段 12 格时间窗与主矩形（严格对齐分镜 v0.6 第 2.2/2.3 节）
const MID_PANELS: Array[Dictionary] = [
	{"panel": "P2",  "start": 2.6,  "end": 4.4,  "rect": Rect2(632, 56, 600, 440),  "accent": COLOR_PURPLE},
	{"panel": "P3",  "start": 4.4,  "end": 6.2,  "rect": Rect2(48, 512, 1184, 168), "accent": COLOR_PURPLE_BRIGHT},
	{"panel": "P4",  "start": 6.2,  "end": 7.6,  "rect": Rect2(80, 90, 1120, 540),  "accent": COLOR_PURPLE_DARK},
	{"panel": "P5",  "start": 7.6,  "end": 9.6,  "rect": Rect2(260, 72, 760, 576),  "accent": COLOR_PURPLE},
	{"panel": "P6",  "start": 9.6,  "end": 10.5, "rect": Rect2(340, 36, 880, 220),  "accent": COLOR_CRIMSON},
	{"panel": "P7",  "start": 10.5, "end": 11.3, "rect": Rect2(370, 276, 540, 120), "accent": COLOR_PURPLE_BRIGHT},
	{"panel": "P8",  "start": 11.3, "end": 12.5, "rect": Rect2(120, 412, 820, 276), "accent": COLOR_CRIMSON},
	{"panel": "P8a", "start": 12.5, "end": 13.6, "rect": Rect2(48, 44, 780, 340),   "accent": COLOR_CRIMSON},
	{"panel": "P8b", "start": 13.6, "end": 14.6, "rect": Rect2(440, 344, 792, 340), "accent": COLOR_CRIMSON_BRIGHT},
	{"panel": "P9",  "start": 14.6, "end": 17.1, "rect": Rect2(60, 94, 1160, 532),  "accent": COLOR_CRIMSON_BRIGHT},
	{"panel": "P9a", "start": 17.1, "end": 18.2, "rect": Rect2(48, 40, 760, 348),   "accent": COLOR_CRIMSON_BRIGHT},
	{"panel": "P9b", "start": 18.2, "end": 19.5, "rect": Rect2(340, 326, 892, 358), "accent": COLOR_PURPLE_BRIGHT},
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
var _mid_assets_ready := false
var _t := 0.0
var _phase := Phase.P1
var _skipping := false
var _skipped := false
var _skip_time := -1.0
var _fade := 0.0
var _done := false
var _pressed := false
var _first_frame := true
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
var _m5b_last_frame := -1

# 加载的定稿纹理缓存（实例级，退出自动释放，不常驻污染启动内存）
var _tex_m1: Array[Texture2D] = []
var _tex_m2: Texture2D = null
var _tex_m3: Texture2D = null
var _tex_m4: Texture2D = null
var _tex_m7: Texture2D = null
var _tex_m8: Texture2D = null
var _tex_m5b_sheets: Array[Texture2D] = []
var _tex_m9: Texture2D = null
var _tex_m10: Texture2D = null
var _m5b_atlas: AtlasTexture = null
var _p7_eye_atlas: AtlasTexture = null

var _root: Control
var _stage_layer: Control

# P1 实时入格层
var _p1_layer: Control
var _p1_gutter: ColorRect
var _p1_frame: Panel
var _p1_tex_rect: TextureRect
var _p1_mat: ShaderMaterial

# MID 动态漫画中段层（6 页完整舞台 + 兼容 _video_player / _mid_placeholder_box）
var _mid_layer: Control
var _video_player: VideoStreamPlayer
var _mid_placeholder_box: Panel
var _mid_placeholder_label: Label
var _mid_stage: Control
# 第 1 页（P1 左格留驻 + P2 右上漩涡 + P3 下方通栏 + 幽紫蚀框裂脉）
var _page1: Control
var _pg1_left_frame: Panel
var _pg1_left_tex: TextureRect
var _pg1_p2_frame: Panel
var _pg1_p2_img_a: TextureRect
var _pg1_p2_img_b: TextureRect
var _pg1_p3_frame: Panel
var _pg1_p3_img_a: TextureRect
var _pg1_p3_img_b: TextureRect
var _pg1_cracks: Control
var _pg1_crack_lines: Array[Line2D] = []
# 第 2 页（P4 3 块撕裂残格 + P5 破框集中线 + M2 透明前景出格）
var _page2: Control
var _pg2_p4_root: Control
var _pg2_p4_shards: Array[Node2D] = []
var _pg2_p5_root: Control
var _pg2_p5_frame: Panel
var _pg2_p5_rays: Control
var _pg2_p5_mob: TextureRect
# 第 3 页（P6 高空掠影 + P7 眼部反打 + P8 俯冲追杀）
var _page3: Control
var _pg3_p6_frame: Panel
var _pg3_p6_img: TextureRect
var _pg3_p6_ribbon: Polygon2D
var _pg3_p7_frame: Panel
var _pg3_p7_img: TextureRect
var _pg3_p7_mat: ShaderMaterial
var _pg3_p8_frame: Panel
var _pg3_p8_img: TextureRect
var _pg3_p8_ribbon: Polygon2D
# 第 4 页（新：P8a 落地对峙 + P8b 怪扑侧闪）
var _page4: Control
var _pg4_p8a_frame: Panel
var _pg4_p8a_img: TextureRect
var _pg4_p8b_gutter: ColorRect
var _pg4_p8b_frame: Panel
var _pg4_p8b_img: TextureRect
var _pg4_p8b_speed: Control
# 第 5 页（P9 拔刀特写大格：M5b 30 帧 12fps 图集序列＋尾段程序纯白刀锋寒光束与锐利十字星芒）
var _page5: Control
var _pg5_p9_frame: Panel
var _pg5_p9_img: TextureRect
var _pg5_glint_root: Control
var _pg5_glint_beam: Polygon2D
var _pg5_glint_glow: TextureRect
var _pg5_glint_star: Polygon2D
# 第 6 页（新：P9a 刀爪相撞 + P9b 斩怪化雾，末 0.15s 定格像素级对齐 rift3_mid_end.webp）
var _page6: Control
var _pg6_p9a_frame: Panel
var _pg6_p9a_img: TextureRect
var _pg6_p9a_mat: ShaderMaterial
var _pg6_p9b_gutter: ColorRect
var _pg6_p9b_frame: Panel
var _pg6_p9b_img: TextureRect
var _pg6_p9b_slash_white: Polygon2D
var _pg6_p9b_slash_red: Polygon2D

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


## 开关守卫：XRift.STAGE3 与 XRift.RIFT3_ANIM 均开启才为真
static func _rift_switch_on() -> bool:
	if not XRift.STAGE3:
		return false
	if not XRift.RIFT3_ANIM:
		return false
	return true


## 开关全开且全部 19 项核心定稿视觉资产就绪才返回 true；缺任一项返回 false 不报错（T430 核 P3-2）
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
	var raw := XRift.rift3_line(key)
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
	var p1_tex: Texture2D = _viewport_tex if _viewport_tex != null else _get_p1_fallback_tex()
	if _p1_tex_rect != null:
		_p1_tex_rect.texture = p1_tex
	if _pg1_left_tex != null:
		_pg1_left_tex.texture = p1_tex
	_bind_p4_shard_textures(p1_tex)
	_speech_speaker_label.text = str(parse_rift_line("sense").speaker)
	_load_assets()
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
	var real_dt := delta / scale
	if _first_frame:
		_first_frame = false
		if real_dt > FIRST_FRAME_SPIKE_SEC:
			real_dt = minf(real_dt, FIRST_FRAME_CLAMP_SEC)
	step(real_dt, _pressed)
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
		"mid_assets_ready": _mid_assets_ready,
		"m5b_frame": _m5b_last_frame,
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


func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	return res as Texture2D if res is Texture2D else null


func _load_assets() -> void:
	# 1) 中段全部定稿 WebP 贴图（M1×4, M2, M3, M4, M7, M8, M5b×5, M9_v2, M10）
	_tex_m1.clear()
	for p in [TEX_M1_1, TEX_M1_2, TEX_M1_3, TEX_M1_4]:
		var tm := _load_tex(p)
		if tm != null:
			_tex_m1.append(tm)
	_tex_m2 = _load_tex(TEX_M2_MOB)
	_tex_m3 = _load_tex(TEX_M3_SKY)
	_tex_m4 = _load_tex(TEX_M4_DIVE)
	_tex_m7 = _load_tex(TEX_M7_P8A)
	_tex_m8 = _load_tex(TEX_M8_P8B)
	_tex_m5b_sheets.clear()
	for sp in TEX_M5B_SHEETS:
		var ts := _load_tex(sp)
		if ts != null:
			_tex_m5b_sheets.append(ts)
	_tex_m9 = _load_tex(TEX_M9_P9A)
	_tex_m10 = _load_tex(TEX_M10_P9B)

	_mid_assets_ready = (_tex_m1.size() == 4
		and _tex_m2 != null and _tex_m3 != null and _tex_m4 != null
		and _tex_m7 != null and _tex_m8 != null
		and _tex_m5b_sheets.size() == TEX_M5B_SHEETS.size()
		and _tex_m9 != null and _tex_m10 != null)

	if _mid_assets_ready:
		_pg1_p2_img_a.texture = _tex_m1[0]
		_pg1_p2_img_b.texture = _tex_m1[1]
		_pg1_p3_img_a.texture = _tex_m1[2]
		_pg1_p3_img_b.texture = _tex_m1[3]
		_pg2_p5_mob.texture = _tex_m2
		_pg3_p6_img.texture = _tex_m3
		# P7 裁切复用 M2 怪物亮紫双目横带（对齐 T427 实测 M2 眼部位置 y=20%~39%）
		var m2_sz := _tex_m2.get_size()
		_p7_eye_atlas = AtlasTexture.new()
		_p7_eye_atlas.atlas = _tex_m2
		_p7_eye_atlas.region = Rect2(m2_sz.x * 0.22, m2_sz.y * 0.19, m2_sz.x * 0.44, m2_sz.y * 0.19)
		_pg3_p7_img.texture = _p7_eye_atlas
		_pg3_p8_img.texture = _tex_m4
		_pg4_p8a_img.texture = _tex_m7
		_pg4_p8b_img.texture = _tex_m8
		_m5b_atlas = AtlasTexture.new()
		_m5b_atlas.atlas = _tex_m5b_sheets[0]
		_m5b_atlas.region = Rect2(Vector2.ZERO, M5B_FRAME_SIZE)
		_pg5_p9_img.texture = _m5b_atlas
		_pg6_p9a_img.texture = _tex_m9
		_pg6_p9b_img.texture = _tex_m10
		if _mid_stage != null:
			_mid_stage.visible = true
		if _mid_placeholder_box != null:
			_mid_placeholder_box.visible = false
	elif ResourceLoader.exists(VIDEO_MID):
		# 兼容可选整段 .ogv 覆盖口
		var st = load(VIDEO_MID)
		if st is VideoStream and _video_player != null:
			_video_player.stream = st
			_video_player.visible = true
			if _mid_placeholder_box != null:
				_mid_placeholder_box.visible = false

	# 2) P10 尾帧（第 6 页 P9b 斩怪定格）＋ M6 水平镜像透明挥斩 ＋ P11 M5a 立绘
	var t_end := _load_tex(TEX_MID_END)
	if t_end != null and _p10_end_rect != null:
		_p10_end_rect.texture = t_end
	var t_m6 := _load_tex(TEX_M6_SLASH)
	if t_m6 != null and _p10_slash_rect != null:
		_p10_slash_rect.texture = t_m6
	var t_m5a := _load_tex(TEX_M5A_PORTRAIT)
	if t_m5a != null and _p11_portrait_rect != null:
		_p11_portrait_rect.texture = t_m5a

	# 3) 可选同步音效轨（30.5s 混音）
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

	# 若启用外部 .ogv 覆盖口，仅在进入 Phase.MID 时启动、离开时停止
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
	_update_phase_mid()
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


## 中段动态漫画 6 页完整调度（2.6–19.5s，使用全部定稿 WebP＋M5b 30 帧拔刀图集）
func _update_phase_mid() -> void:
	if _phase != Phase.MID or not _mid_assets_ready or _mid_stage == null:
		return
	var show_p1 := _t < 6.2
	var show_p2 := _t >= 6.2 and _t < 9.6
	var show_p3 := _t >= 9.6 and _t < 12.5
	var show_p4 := _t >= 12.5 and _t < 14.6
	var show_p5 := _t >= 14.6 and _t < 17.1
	var show_p6 := _t >= 17.1

	_page1.visible = show_p1
	_page2.visible = show_p2
	_page3.visible = show_p3
	_page4.visible = show_p4
	_page5.visible = show_p5
	_page6.visible = show_p6

	if show_p1:
		_update_mid_page1()
	elif show_p2:
		_update_mid_page2()
	elif show_p3:
		_update_mid_page3()
	elif show_p4:
		_update_mid_page4()
	elif show_p5:
		_update_mid_page5()
	elif show_p6:
		_update_mid_page6()


func _update_mid_page1() -> void:
	# 第 1 页：P2 (2.6–4.4s) 右上漩涡弹出 → P3 (4.4–6.2s) 下方通栏暴走＋整页白框遭幽紫侵蚀开裂、右格错位滑坠
	var in_p3 := _t >= 4.4
	var p2_u := clampf((_t - 2.6) / 1.8, 0.0, 1.0)
	var slide_u := _ease_out_back_subtle(clampf((_t - 2.6) / 0.14, 0.0, 1.0))
	var p2_base := Vector2(lerpf(760.0, 632.0, slide_u), 56.0)

	# P2 内部 M1-1 → M1-2 图接图叠化＋加速微推
	var blend_12 := clampf((_t - 3.35) / 0.45, 0.0, 1.0)
	_pg1_p2_img_b.modulate.a = blend_12
	var z2 := lerpf(1.0, 1.10, p2_u)
	_set_zoom_rect(_pg1_p2_img_a, Vector2(590, 430), z2)
	_set_zoom_rect(_pg1_p2_img_b, Vector2(590, 430), z2)

	if not in_p3:
		_page1.position = Vector2.ZERO
		_pg1_p2_frame.position = p2_base
		_pg1_p2_frame.rotation_degrees = 0.0
		_pg1_p3_frame.visible = false
		_pg1_cracks.visible = false
		_set_frame_border_color(_pg1_left_frame, COLOR_PAPER)
		_set_frame_border_color(_pg1_p2_frame, COLOR_PAPER)
	else:
		var p3_lt := _t - 4.4  # 0.0 .. 1.8s
		var p3_u := clampf(p3_lt / 1.8, 0.0, 1.0)
		var pop3 := _ease_out_back_subtle(clampf(p3_lt / 0.12, 0.0, 1.0))
		_pg1_p3_frame.visible = true
		_pg1_p3_frame.position = Vector2(48.0, lerpf(560.0, 512.0, pop3))
		# M1-3 → M1-4 暴走裂开
		_pg1_p3_img_b.modulate.a = clampf((p3_lt - 0.65) / 0.45, 0.0, 1.0)
		var z3 := lerpf(1.0, 1.08, p3_u)
		_set_zoom_rect(_pg1_p3_img_a, Vector2(1174, 158), z3)
		_set_zoom_rect(_pg1_p3_img_b, Vector2(1174, 158), z3)

		# 主题①起爆：4px 高频微震 + 幽紫蚀骨裂脉沿白框爬裂 + 右格错位滑坠 12px
		var amp := lerpf(4.5, 2.2, p3_u)
		_page1.position = Vector2(sin(p3_lt * 165.0) * amp, cos(p3_lt * 195.0) * amp * 0.75)
		var slip := clampf((p3_lt - 0.25) / 0.55, 0.0, 1.0)
		_pg1_p2_frame.position = Vector2(632.0 + slip * 4.0, 56.0 + slip * 12.0)
		_pg1_p2_frame.rotation_degrees = slip * 1.6
		var crack_col := COLOR_PAPER.lerp(COLOR_PURPLE_BRIGHT, clampf(p3_u * 1.1, 0.0, 0.85))
		_set_frame_border_color(_pg1_left_frame, crack_col)
		_set_frame_border_color(_pg1_p2_frame, crack_col)
		_set_frame_border_color(_pg1_p3_frame, COLOR_PURPLE_BRIGHT)

		_pg1_cracks.visible = true
		for i in _pg1_crack_lines.size():
			var ln: Line2D = _pg1_crack_lines[i]
			var thresh := float(i) * 0.08
			var a := clampf((p3_u - thresh) / 0.22, 0.0, 1.0)
			ln.modulate.a = a


func _update_mid_page2() -> void:
	# 第 2 页：P4 (6.2–7.6s) 3 块斜切残格撕裂 → P5 (7.6–9.6s) 斜切格框＋集中线＋M2 透明怪破框出格急放
	var in_p5 := _t >= 7.6
	var p4_lt := clampf(_t - 6.2, 0.0, 1.4)
	var p4_u := clampf(p4_lt / 1.4, 0.0, 1.0)
	_pg2_p4_root.visible = true
	var dirs := [Vector2(-46.0, -26.0), Vector2(36.0, -18.0), Vector2(-12.0, 42.0)]
	var rots := [-4.2, 3.8, -2.5]
	for i in _pg2_p4_shards.size():
		var sh: Node2D = _pg2_p4_shards[i]
		var jitter := Vector2(sin(p4_lt * 130.0 + i * 2.1), cos(p4_lt * 155.0 - i)) * (3.0 if not in_p5 else 0.0)
		sh.position = dirs[i] * p4_u + jitter
		sh.rotation_degrees = rots[i] * p4_u
	_pg2_p4_root.modulate.a = 1.0 if not in_p5 else 0.45

	_pg2_p5_root.visible = in_p5
	if not in_p5:
		_page2.position = Vector2.ZERO
		return

	var p5_lt := _t - 7.6  # 0.0 .. 2.0s
	# 前 1.7s 急放 0.88x -> 1.16x，末 0.3s 顿压定格
	var rush_u := clampf(p5_lt / 1.7, 0.0, 1.0)
	var ease_rush := 1.0 - pow(1.0 - rush_u, 2.4)
	var m2_scale := lerpf(0.88, 1.16, ease_rush)
	var base_sz := Vector2(720.0, 560.0)
	var cur_sz := base_sz * m2_scale
	_pg2_p5_mob.size = cur_sz
	_pg2_p5_mob.position = (STAGE_SIZE - cur_sz) * 0.5 + Vector2(0.0, lerpf(16.0, -12.0, ease_rush))

	var shake_amp := 8.0 * pow(clampf(1.0 - p5_lt / 1.5, 0.0, 1.0), 1.4)
	_page2.position = Vector2(sin(p5_lt * 185.0) * shake_amp, cos(p5_lt * 215.0) * shake_amp * 0.85)
	_pg2_p5_rays.rotation_degrees = p5_lt * 8.0


func _update_mid_page3() -> void:
	# 第 3 页：P6 (9.6–10.5s) 高空掠影 → P7 (10.5–11.3s) 怪物眼部反打 → P8 (11.3–12.5s) 俯冲追杀
	var in_p7 := _t >= 10.5
	var in_p8 := _t >= 11.3

	# P6 (9.6–10.5s)
	var p6_lt := clampf(_t - 9.6, 0.0, 0.9)
	var pop6 := _ease_out_back_subtle(clampf(p6_lt / 0.12, 0.0, 1.0))
	_pg3_p6_frame.visible = true
	_pg3_p6_frame.position = Vector2(lerpf(560.0, 340.0, pop6), 36.0)
	_pg3_p6_ribbon.visible = true
	_pg3_p6_ribbon.position = Vector2(lerpf(180.0, 0.0, pop6), 0.0)
	_set_zoom_rect(_pg3_p6_img, Vector2(870, 210), lerpf(1.0, 1.07, p6_lt / 0.9), Vector2(lerpf(18.0, -18.0, p6_lt / 0.9), 0.0))

	# P7 (10.5–11.3s)：眼部横条格＋首 2 帧反色闪
	_pg3_p7_frame.visible = in_p7
	if in_p7:
		var p7_lt := clampf(_t - 10.5, 0.0, 0.8)
		var pop7 := _ease_out_back_subtle(clampf(p7_lt / 0.10, 0.0, 1.0))
		_pg3_p7_frame.position = Vector2(lerpf(180.0, 370.0, pop7), 276.0)
		_set_zoom_rect(_pg3_p7_img, Vector2(530, 110), lerpf(1.0, 1.12, p7_lt / 0.8))
		if _pg3_p7_mat != null:
			_pg3_p7_mat.set_shader_parameter("invert_amount", 1.0 if p7_lt < 0.07 else 0.0)

	# P8 (11.3–12.5s)：俯冲追杀大格＋急推 1.00×→1.12×
	_pg3_p8_frame.visible = in_p8
	_pg3_p8_ribbon.visible = in_p8
	if in_p8:
		var p8_lt := clampf(_t - 11.3, 0.0, 1.2)
		var pop8 := _ease_out_back_subtle(clampf(p8_lt / 0.12, 0.0, 1.0))
		var shake8 := 5.0 * clampf(1.0 - p8_lt / 0.35, 0.0, 1.0)
		_pg3_p8_frame.position = Vector2(120.0 + sin(p8_lt * 190.0) * shake8, lerpf(510.0, 412.0, pop8) + cos(p8_lt * 210.0) * shake8 * 0.7)
		_set_zoom_rect(_pg3_p8_img, Vector2(810, 266), lerpf(1.0, 1.12, p8_lt / 1.2))


func _update_mid_page4() -> void:
	# 第 4 页（新·近身周旋）：P8a (12.5–13.6s) 左上落地对峙 → P8b (13.6–14.6s) 右下怪扑侧闪压叠
	var in_p8b := _t >= 13.6
	var p8a_lt := clampf(_t - 12.5, 0.0, 1.1)
	var pop8a := _ease_out_back_subtle(clampf(p8a_lt / 0.10, 0.0, 1.0))
	_pg4_p8a_frame.position = Vector2(lerpf(12.0, 48.0, pop8a), 44.0)
	_set_zoom_rect(_pg4_p8a_img, Vector2(770, 330), lerpf(1.0, 1.05, p8a_lt / 1.1))

	_pg4_p8b_gutter.visible = in_p8b
	_pg4_p8b_frame.visible = in_p8b
	_pg4_p8b_speed.visible = in_p8b
	if not in_p8b:
		_page4.position = Vector2.ZERO
		return

	var p8b_lt := clampf(_t - 13.6, 0.0, 1.0)
	var pop8b := _ease_out_back_subtle(clampf(p8b_lt / 0.11, 0.0, 1.0))
	var slide_off := Vector2(lerpf(130.0, 0.0, pop8b), lerpf(42.0, 0.0, pop8b))
	_pg4_p8b_gutter.position = Vector2(430.0, 334.0) + slide_off
	_pg4_p8b_frame.position = Vector2(440.0, 344.0) + slide_off
	_set_zoom_rect(_pg4_p8b_img, Vector2(782, 330), lerpf(1.0, 1.08, p8b_lt / 1.0))
	var shake := 5.0 * clampf(1.0 - p8b_lt / 0.42, 0.0, 1.0)
	_page4.position = Vector2(sin(p8b_lt * 175.0) * shake, cos(p8b_lt * 205.0) * shake * 0.8)


func _update_mid_page5() -> void:
	# 第 5 页（P9 拔刀特写大格，14.6–17.1s，2.5s）：M5b 0.00s～4.98s 物理连贯 30 帧 12fps 精准同步 _t，
	# 尾段（lt 1.65~2.25s）叠加程序纯白刀锋掠光束＋纯白十字寒光星芒，末 0.25s 稳帧蓄力
	var lt := clampf(_t - P9_START, 0.0, P9_DURATION)
	var pop := _ease_out_back_subtle(clampf(lt / 0.10, 0.0, 1.0))
	var shake := 6.0 * clampf(1.0 - lt / 0.28, 0.0, 1.0)
	_pg5_p9_frame.position = Vector2(60.0 + sin(lt * 195.0) * shake, lerpf(132.0, 94.0, pop) + cos(lt * 210.0) * shake * 0.7)

	# 0.0~2.25s 均匀推进 0..29 帧（严格 0.00s~4.98s 零穿帮段）；末 0.25s 稳住终帧蓄力
	var anim_u := clampf(lt / 2.25, 0.0, 1.0)
	var f_idx := clampi(int(floor(anim_u * float(M5B_TOTAL_FRAMES - 1) + 0.001)), 0, M5B_TOTAL_FRAMES - 1)
	if f_idx != _m5b_last_frame and _m5b_atlas != null and not _tex_m5b_sheets.is_empty():
		_m5b_last_frame = f_idx
		var sheet_idx := clampi(f_idx / M5B_FRAMES_PER_SHEET, 0, _tex_m5b_sheets.size() - 1)
		var local_idx := f_idx % M5B_FRAMES_PER_SHEET
		var col := local_idx % M5B_COLS
		var row := local_idx / M5B_COLS
		_m5b_atlas.atlas = _tex_m5b_sheets[sheet_idx]
		_m5b_atlas.region = Rect2(Vector2(col * M5B_FRAME_SIZE.x, row * M5B_FRAME_SIZE.y), M5B_FRAME_SIZE)
	var zoom := lerpf(1.0, 1.035, clampf(lt / P9_DURATION, 0.0, 1.0))
	_set_zoom_rect(_pg5_p9_img, Vector2(1150, 522), zoom)

	# 尾段程序刀锋纯白寒光束＋锐利十字星芒（沿刀锋右段贴刃掠向刀锷，避开人物面部）
	var glint_on := lt >= 1.62 and lt <= 2.28
	_pg5_glint_root.visible = glint_on
	if glint_on:
		var gu := clampf((lt - 1.62) / 0.66, 0.0, 1.0)
		var env := sin(gu * PI)
		var blade_a := Vector2(470.0, 442.0)
		var blade_b := Vector2(890.0, 222.0)
		var dir := (blade_b - blade_a).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		# 星芒沿刀刃右半段高速掠向刀锷（(640,352) -> (848,244)，全程离面部安全距离）
		var sweep_pos := Vector2(640.0, 352.0).lerp(Vector2(848.0, 244.0), clampf(gu * 1.15, 0.0, 1.0))
		var half_w := lerpf(2.0, 6.5, env)
		_pg5_glint_beam.polygon = _tapered_slash_poly(blade_a, blade_b, nrm, half_w)
		_pg5_glint_beam.color = Color(1.0, 1.0, 1.0, env * 0.78)
		var glow_sz := Vector2.ONE * lerpf(80.0, 190.0, env)
		_pg5_glint_glow.size = glow_sz
		_pg5_glint_glow.position = sweep_pos - glow_sz * 0.5
		_pg5_glint_glow.modulate = Color(1.0, 1.0, 1.0, env * 0.88)
		_pg5_glint_star.position = sweep_pos
		_pg5_glint_star.scale = Vector2.ONE * lerpf(0.40, 1.12, env)
		_pg5_glint_star.rotation_degrees = -28.0 + gu * 12.0
		_pg5_glint_star.color = Color(1.0, 1.0, 1.0, minf(env * 1.35, 1.0))


func _update_mid_page6() -> void:
	# 第 6 页（新·硬撼斩怪）：P9a (17.1–18.2s) 刀爪相撞 → P9b (18.2–19.5s) 斩怪化紫雾
	# 末 0.15s (19.35–19.50s) 震屏归零、斜光收净，像素级 1:1 锁定对齐 rift3_mid_end.webp 无缝衔接 P10 劈页！
	var in_p9b := _t >= 18.2
	var p9a_lt := clampf(_t - 17.1, 0.0, 1.1)
	# 首帧反色冲击闪 1 帧（0.05s）＋急速缩放回弹 1.06×→1.00×
	if _pg6_p9a_mat != null:
		_pg6_p9a_mat.set_shader_parameter("invert_amount", 1.0 if (not in_p9b and p9a_lt < 0.05) else 0.0)
	var z9a := lerpf(1.06, 1.0, clampf(p9a_lt / 0.25, 0.0, 1.0)) if not in_p9b else 1.0
	_pg6_p9a_frame.position = Vector2(48.0, 40.0)
	_set_zoom_rect(_pg6_p9a_img, Vector2(750, 338), z9a)

	_pg6_p9b_gutter.visible = in_p9b
	_pg6_p9b_frame.visible = in_p9b
	if not in_p9b:
		var shake_a := 8.0 * pow(clampf(1.0 - p9a_lt / 0.45, 0.0, 1.0), 1.5)
		_page6.position = Vector2(sin(p9a_lt * 210.0) * shake_a, cos(p9a_lt * 235.0) * shake_a * 0.85)
		_pg6_p9b_slash_white.visible = false
		_pg6_p9b_slash_red.visible = false
		return

	var p9b_lt := clampf(_t - 18.2, 0.0, 1.3)
	var settle := p9b_lt >= 1.15  # 末 0.15s 定格对齐 rift3_mid_end.webp
	var pop9b := 1.0 if settle else _ease_out_back_subtle(clampf(p9b_lt / 0.11, 0.0, 1.0))
	var slide := Vector2(lerpf(80.0, 0.0, pop9b), lerpf(-32.0, 0.0, pop9b))
	_pg6_p9b_gutter.position = Vector2(330.0, 316.0) + slide
	_pg6_p9b_frame.position = Vector2(340.0, 326.0) + slide
	var z9b := 1.0 if settle else lerpf(1.06, 1.0, clampf(p9b_lt / 0.40, 0.0, 1.0))
	_set_zoom_rect(_pg6_p9b_img, Vector2(882, 348), z9b)

	if settle:
		_page6.position = Vector2.ZERO
	else:
		var shake_b := 9.0 * pow(clampf(1.0 - p9b_lt / 0.55, 0.0, 1.0), 1.5)
		_page6.position = Vector2(sin(p9b_lt * 200.0) * shake_b, cos(p9b_lt * 240.0) * shake_b * 0.85)

	# P9b 右上→左下纯白带朱红残影斜斩光掠过（0.0–0.42s），与 P10 斜斩刀势一脉相承
	var slash_on := p9b_lt < 0.42
	_pg6_p9b_slash_white.visible = slash_on
	_pg6_p9b_slash_red.visible = slash_on
	if slash_on:
		var su := clampf(p9b_lt / 0.42, 0.0, 1.0)
		var sa := 1.0 if su < 0.35 else clampf(1.0 - (su - 0.35) / 0.65, 0.0, 1.0)
		_pg6_p9b_slash_white.color = Color(COLOR_PAPER.r, COLOR_PAPER.g, COLOR_PAPER.b, sa * 0.92)
		_pg6_p9b_slash_red.color = Color(COLOR_CRIMSON.r, COLOR_CRIMSON.g, COLOR_CRIMSON.b, sa * 0.85)


func _update_phase_p10() -> void:
	if _phase != Phase.P10:
		if _p10_shards != null and _p10_shards.emitting:
			_p10_shards.emitting = false
		return

	var lt := _t - PHASE_MID_END  # 0.0 .. 2.3s（19.50–21.80s）
	# 1) 19.50–19.60s：全屏反色冲击帧＋12px 重震屏（至 19.95s 平滑衰减）
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

	# 2) 两半第 6 页画页沿斜线法向裂开→滑出屏幕，实时露出底层 Map004
	var cut_dir := Vector2(P10_CUT_BOT_X - P10_CUT_TOP_X, STAGE_SIZE.y).normalized()
	var cut_normal := Vector2(-cut_dir.y, cut_dir.x)
	var gap := 0.0
	var half_rot := 0.0
	var half_alpha := 1.0
	if lt < 0.40:
		var u := clampf(lt / 0.40, 0.0, 1.0)
		gap = lerpf(4.0, 28.0, u * u)
		half_rot = lerpf(0.0, 0.015, u)
	elif lt < 1.35:
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
		_p10_half_tl.position += Vector2(pivot.y * sin(half_rot) * 0.12, 0.0)
		_p10_half_br.position -= Vector2(pivot.y * sin(half_rot) * 0.12, 0.0)

	# 3) 对角纯白刀光＋朱红残影（19.50–20.15s）
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

	# 4) 碎格粒子 CPUParticles2D（amount = 96 <= 120）：19.82s 一次性爆发飞溅
	if not _p10_shards_fired and lt >= 0.32 and lt < 1.50:
		_p10_shards_fired = true
		_p10_shards.restart()
		_p10_shards.emitting = true

	# 5) 裂口下方残余紫烟（19.85–21.15s 被镜像 M6 挥斩劈散）
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

	# 6) M6 镜像透明挥斩前景冲破裂口（19.88–21.75s；右上→左下挥斩冲近后收势消隐）
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
		# P11a 进场微弹（21.80–22.02s）＋ P11c 轻向右微推蓄势（27.0–29.2s）
		var pop_u := clampf(p11_elapsed / 0.22, 0.0, 1.0)
		var pop_ease := _ease_out_back_subtle(pop_u)
		var base_pos := Vector2(20.0, 150.0).lerp(Vector2(44.0, 132.0), pop_ease)
		if _t >= P11C_START:
			var push_right := clampf((_t - P11C_START) / (PHASE_P11D_START - P11C_START), 0.0, 1.0)
			base_pos.x += lerpf(0.0, 8.0, push_right)
		# P11b 25.7s 单拍 2px 幽紫框边微闪（严格限于框边与气泡外角，正文绝不变紫或抖动）
		var flash_start := P11B_PURPLE_FLASH - 0.08
		var flash_end := P11B_PURPLE_FLASH + 0.18
		var purple_pulse := _t >= flash_start and _t <= flash_end
		var jitter := Vector2.ZERO
		if purple_pulse:
			var pt := _t - flash_start
			jitter = Vector2(sin(pt * 210.0) * 2.0, cos(pt * 170.0) * 1.5)
		_p11_portrait_box.position = base_pos + jitter
		_p11_portrait_box.modulate.a = clampf(pop_u * 2.0, 0.0, 1.0)

		# 残格内立绘极缓前推 1.00×→1.03×
		var p_zoom := lerpf(1.0, 1.03, clampf(p11_elapsed / (PHASE_P11D_START - PHASE_P10_END), 0.0, 1.0))
		_sync_p11_portrait_texture(p_zoom)

		_p11_purple_edge.visible = purple_pulse
		_speech_purple_corner.visible = purple_pulse and _speech_bubble_box.visible
		if purple_pulse:
			var pulse_a := sin(clampf((_t - flash_start) / (flash_end - flash_start), 0.0, 1.0) * PI)
			_p11_purple_edge.default_color = Color(COLOR_PURPLE_BRIGHT.r, COLOR_PURPLE_BRIGHT.g, COLOR_PURPLE_BRIGHT.b, 0.92 * pulse_a)
			_speech_purple_corner.default_color = Color(COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b, 0.88 * pulse_a)

		# P11c 红带微风飘尘线条（27.0–29.2s 轻盈掠过残格边沿）
		var wind_on := _t >= P11C_START
		for i in _p11_wind_lines.size():
			var wl: Line2D = _p11_wind_lines[i]
			wl.visible = wind_on
			if wind_on:
				var wt := fmod((_t - P11C_START) * (0.9 + i * 0.25) + i * 0.33, 1.0)
				wl.position = Vector2(lerpf(-30.0, 110.0, wt), lerpf(18.0, -24.0, wt))
				wl.default_color.a = sin(wt * PI) * 0.65
	else:
		_p11_purple_edge.visible = false
		_speech_purple_corner.visible = false
		# 29.2s：残格与气泡碎成最后 20 片黑白网点纸屑随风飘散
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
		if _t < P11B_START:
			_active_panel = "P11a"
		elif _t < P11C_START:
			_active_panel = "P11b"
		elif _t < PHASE_P11D_START:
			_active_panel = "P11c"
		else:
			_active_panel = "P11d"
		return
	# Phase.MID：按时间码定位 P2～P9b（12 格）
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
		elif cid == "p8b_dodge":
			# P8b「嗖！」：小A·文字排版提示——硬朗瘦劲斜掠刀笔感，轻盈横掠淡稳
			var pop := lerpf(1.18, 1.0, clampf(age / 0.07, 0.0, 1.0))
			lbl.scale = Vector2(0.88 * pop, 1.08 * pop)
			lbl.position = base_pos + Vector2(lerpf(18.0, 0.0, clampf(age / 0.12, 0.0, 1.0)), 0.0)
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

	# P11a～c（21.8–29.2s）期间名签「徐凤年」常驻不动、跨句间隙不闪烁
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
				_narration_p1_label.text = text
				_narration_p1_label.visible_ratio = 1.0
				_narration_p1_box.modulate.a = clampf((_t - c_start) / 0.15, 0.0, 1.0)
				_narration_p1_box.visible = true
			elif style == "speech_bubble":
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

	# 兼容可选整段 .ogv 播放节点与旧测试 speed_scale 校验
	_video_player = VideoStreamPlayer.new()
	_video_player.name = "Video"
	_video_player.expand = true
	_video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video_player.visible = false
	_mid_layer.add_child(_video_player)

	# 动态漫画 6 页主舞台（当全套定稿 WebP 就绪时启用）
	_mid_stage = Control.new()
	_mid_stage.name = "MidComicStage"
	_mid_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mid_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mid_stage.visible = false
	_mid_layer.add_child(_mid_stage)

	_build_mid_page1()
	_build_mid_page2()
	_build_mid_page3()
	_build_mid_page4()
	_build_mid_page5()
	_build_mid_page6()

	# 占位盒子（仅在 allow_placeholder 且缺定稿资产时可见）
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


func _make_comic_panel(parent: Node, tag: String, rect: Rect2, border_col := COLOR_PAPER) -> Dictionary:
	var frame := Panel.new()
	frame.name = tag
	frame.position = rect.position
	frame.size = rect.size
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _panel_box(COLOR_INK, border_col, 5))
	parent.add_child(frame)

	var inner := Control.new()
	inner.name = "InnerClip"
	inner.position = Vector2(5, 5)
	inner.size = Vector2(maxf(rect.size.x - 10.0, 1.0), maxf(rect.size.y - 10.0, 1.0))
	inner.clip_contents = true
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(inner)

	var tr := TextureRect.new()
	tr.name = "Img"
	tr.position = Vector2.ZERO
	tr.size = inner.size
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(tr)
	return {"frame": frame, "inner": inner, "img": tr}


func _build_mid_page1() -> void:
	_page1 = Control.new()
	_page1.name = "Page1_VortexCrack"
	_page1.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mid_stage.add_child(_page1)

	# 保留左侧实时 Map004 网点格（无缝承接 P1）
	var p1_left := _make_comic_panel(_page1, "Pg1LeftLobby", P1_TARGET_RECT)
	_pg1_left_frame = p1_left.frame
	_pg1_left_tex = p1_left.img
	if _p1_mat != null:
		var mat_copy := _p1_mat.duplicate() as ShaderMaterial
		mat_copy.set_shader_parameter("mix_amount", 1.0)
		mat_copy.set_shader_parameter("zoom", 1.04)
		mat_copy.set_shader_parameter("panel_size", Vector2(550.0, 430.0))
		_pg1_left_tex.material = mat_copy

	# 右上 P2 漩涡格（M1-1 → M1-2 图接图）
	var p2 := _make_comic_panel(_page1, "Pg1P2Vortex", Rect2(632, 56, 600, 440))
	_pg1_p2_frame = p2.frame
	_pg1_p2_img_a = p2.img
	_pg1_p2_img_b = TextureRect.new()
	_pg1_p2_img_b.name = "ImgB"
	_pg1_p2_img_b.size = (p2.inner as Control).size
	_pg1_p2_img_b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pg1_p2_img_b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_pg1_p2_img_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pg1_p2_img_b.modulate.a = 0.0
	(p2.inner as Control).add_child(_pg1_p2_img_b)

	# 下方通栏 P3 暴走裂开格（M1-3 → M1-4 图接图）
	var p3 := _make_comic_panel(_page1, "Pg1P3Burst", Rect2(48, 512, 1184, 168))
	_pg1_p3_frame = p3.frame
	_pg1_p3_img_a = p3.img
	_pg1_p3_img_b = TextureRect.new()
	_pg1_p3_img_b.name = "ImgB"
	_pg1_p3_img_b.size = (p3.inner as Control).size
	_pg1_p3_img_b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pg1_p3_img_b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_pg1_p3_img_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pg1_p3_img_b.modulate.a = 0.0
	(p3.inner as Control).add_child(_pg1_p3_img_b)
	_pg1_p3_frame.visible = false

	# 主题①：幽紫锯齿蚀骨裂脉沿 P1～P3 纯白边框爬裂
	_pg1_cracks = Control.new()
	_pg1_cracks.name = "PurpleFrameCracks"
	_pg1_cracks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pg1_cracks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pg1_cracks.visible = false
	_page1.add_child(_pg1_cracks)
	var crack_paths: Array = [
		[Vector2(632, 512), Vector2(616, 468), Vector2(634, 412), Vector2(608, 355), Vector2(628, 290), Vector2(604, 210)],
		[Vector2(640, 512), Vector2(720, 492), Vector2(812, 518), Vector2(932, 488), Vector2(1070, 512), Vector2(1232, 496)],
		[Vector2(610, 512), Vector2(510, 494), Vector2(418, 516), Vector2(310, 492), Vector2(180, 514), Vector2(48, 494)],
		[Vector2(1232, 340), Vector2(1188, 368), Vector2(1224, 424), Vector2(1196, 498)],
		[Vector2(48, 280), Vector2(78, 312), Vector2(52, 368), Vector2(84, 430), Vector2(48, 496)],
	]
	for idx in crack_paths.size():
		var pts := PackedVector2Array(crack_paths[idx])
		var glow := Line2D.new()
		glow.name = "CrackGlow_%d" % idx
		glow.points = pts
		glow.width = 7.0
		glow.default_color = Color(COLOR_PURPLE.r, COLOR_PURPLE.g, COLOR_PURPLE.b, 0.78)
		_pg1_cracks.add_child(glow)
		var core := Line2D.new()
		core.name = "CrackCore_%d" % idx
		core.points = pts
		core.width = 2.6
		core.default_color = COLOR_PURPLE_BRIGHT
		glow.add_child(core)
		_pg1_crack_lines.append(glow)


func _build_mid_page2() -> void:
	_page2 = Control.new()
	_page2.name = "Page2_RipAndMob"
	_page2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page2.visible = false
	_mid_stage.add_child(_page2)

	# P4：3 块斜切撕裂残格（底图复用实时 Map004 视口＋网点 shader，缝隙带亮紫边光）
	_pg2_p4_root = Control.new()
	_pg2_p4_root.name = "P4TornShards"
	_pg2_p4_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pg2_p4_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page2.add_child(_pg2_p4_root)
	var shard_polys: Array = [
		[Vector2(56, 54), Vector2(680, 42), Vector2(520, 380), Vector2(44, 420)],
		[Vector2(704, 48), Vector2(1232, 64), Vector2(1218, 444), Vector2(548, 388)],
		[Vector2(66, 444), Vector2(540, 404), Vector2(1208, 468), Vector2(1180, 672), Vector2(90, 666)],
	]
	for idx in shard_polys.size():
		var holder := Node2D.new()
		holder.name = "TornShard_%d" % idx
		_pg2_p4_root.add_child(holder)
		var pts := PackedVector2Array(shard_polys[idx])
		var poly := Polygon2D.new()
		poly.name = "ShardPoly"
		poly.polygon = pts
		if _p1_mat != null:
			var m := _p1_mat.duplicate() as ShaderMaterial
			m.set_shader_parameter("mix_amount", 1.0)
			m.set_shader_parameter("zoom", 1.0)
			m.set_shader_parameter("panel_size", STAGE_SIZE)
			poly.material = m
		holder.add_child(poly)
		var closed := PackedVector2Array(pts)
		closed.append(pts[0])
		var edge_p := Line2D.new()
		edge_p.name = "PurpleEdge"
		edge_p.points = closed
		edge_p.width = 7.0
		edge_p.default_color = COLOR_PURPLE
		holder.add_child(edge_p)
		var edge_w := Line2D.new()
		edge_w.name = "WhiteEdge"
		edge_w.points = closed
		edge_w.width = 3.0
		edge_w.default_color = COLOR_PAPER
		holder.add_child(edge_w)
		_pg2_p4_shards.append(holder)

	# P5：中央斜切格框＋黑白幽紫集中线＋M2 透明染紫怪破框出格层
	_pg2_p5_root = Control.new()
	_pg2_p5_root.name = "P5MobBreakout"
	_pg2_p5_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pg2_p5_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pg2_p5_root.visible = false
	_page2.add_child(_pg2_p5_root)

	_pg2_p5_frame = Panel.new()
	_pg2_p5_frame.name = "P5Frame"
	_pg2_p5_frame.position = Vector2(260, 72)
	_pg2_p5_frame.size = Vector2(760, 576)
	_pg2_p5_frame.clip_contents = true
	_pg2_p5_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pg2_p5_frame.add_theme_stylebox_override("panel", _panel_box(COLOR_INK, COLOR_PAPER, 6))
	_pg2_p5_root.add_child(_pg2_p5_frame)

	# 放射黑白＋幽紫集中线（置于格框内部）
	_pg2_p5_rays = Control.new()
	_pg2_p5_rays.name = "FocusLines"
	_pg2_p5_rays.position = Vector2(380, 288)
	_pg2_p5_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pg2_p5_frame.add_child(_pg2_p5_rays)
	for k in range(44):
		var ang := float(k) * TAU / 44.0
		var r0 := 110.0 + float(k % 4) * 24.0
		var r1 := 520.0
		var perp := Vector2(-sin(ang), cos(ang))
		var half_w := 5.0 if k % 3 == 0 else 2.6
		var ray := Polygon2D.new()
		ray.polygon = PackedVector2Array([
			Vector2(cos(ang), sin(ang)) * r0,
			Vector2(cos(ang), sin(ang)) * r1 + perp * half_w,
			Vector2(cos(ang), sin(ang)) * r1 - perp * half_w,
		])
		ray.color = COLOR_PURPLE if (k % 3 == 0) else (COLOR_PAPER if k % 2 == 0 else COLOR_GRAY_DARK)
		_pg2_p5_rays.add_child(ray)

	# M2 透明前景（放在 _pg2_p5_frame 之外的同级上层，真正冲破上下白边框「出格」）
	_pg2_p5_mob = TextureRect.new()
	_pg2_p5_mob.name = "M2OutOfFrame"
	_pg2_p5_mob.position = Vector2(280, 80)
	_pg2_p5_mob.size = Vector2(720, 560)
	_pg2_p5_mob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pg2_p5_mob.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pg2_p5_mob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pg2_p5_root.add_child(_pg2_p5_mob)


func _build_mid_page3() -> void:
	_page3 = Control.new()
	_page3.name = "Page3_RedRibbonChase"
	_page3.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page3.visible = false
	_mid_stage.add_child(_page3)

	# P6：顶部右上窄格 (340, 36, 880×220) + 甩出格框右下角的朱红飘带
	var p6 := _make_comic_panel(_page3, "Pg3P6Sky", Rect2(340, 36, 880, 220))
	_pg3_p6_frame = p6.frame
	_pg3_p6_img = p6.img
	_pg3_p6_ribbon = Polygon2D.new()
	_pg3_p6_ribbon.name = "P6CrimsonOutRibbon"
	_pg3_p6_ribbon.polygon = PackedVector2Array([
		Vector2(1020, 210), Vector2(1248, 256), Vector2(1264, 272), Vector2(1010, 232),
	])
	_pg3_p6_ribbon.color = COLOR_CRIMSON
	_page3.add_child(_pg3_p6_ribbon)

	# P7：中部收窄眼部横条格 (370, 276, 540×120) + 反色闪材质
	var p7 := _make_comic_panel(_page3, "Pg3P7Eyes", Rect2(370, 276, 540, 120), COLOR_PURPLE_BRIGHT)
	_pg3_p7_frame = p7.frame
	_pg3_p7_img = p7.img
	_pg3_p7_mat = ShaderMaterial.new()
	_pg3_p7_mat.shader = _get_invert_shader()
	_pg3_p7_mat.set_shader_parameter("invert_amount", 0.0)
	_pg3_p7_img.material = _pg3_p7_mat
	_pg3_p7_frame.visible = false

	# P8：中下部大斜切俯冲追杀格 (120, 412, 820×276) + 越格朱红飘带
	var p8 := _make_comic_panel(_page3, "Pg3P8Dive", Rect2(120, 412, 820, 276))
	_pg3_p8_frame = p8.frame
	_pg3_p8_img = p8.img
	_pg3_p8_frame.visible = false
	_pg3_p8_ribbon = Polygon2D.new()
	_pg3_p8_ribbon.name = "P8CrimsonOutRibbon"
	_pg3_p8_ribbon.polygon = PackedVector2Array([
		Vector2(860, 492), Vector2(1140, 444), Vector2(1156, 464), Vector2(866, 514),
	])
	_pg3_p8_ribbon.color = COLOR_CRIMSON
	_pg3_p8_ribbon.visible = false
	_page3.add_child(_pg3_p8_ribbon)


func _build_mid_page4() -> void:
	_page4 = Control.new()
	_page4.name = "Page4_StandoffAndDodge"
	_page4.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page4.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page4.visible = false
	_mid_stage.add_child(_page4)

	# P8a (新)：左上落地对峙格 (48, 44, 780×340)
	var p8a := _make_comic_panel(_page4, "Pg4P8aStandoff", Rect2(48, 44, 780, 340))
	_pg4_p8a_frame = p8a.frame
	_pg4_p8a_img = p8a.img

	# P8b (新)：右下压盖黑槽 + 怪扑侧闪格 (440, 344, 792×340) + 斜向速度线
	_pg4_p8b_gutter = ColorRect.new()
	_pg4_p8b_gutter.name = "Pg4P8bGutter"
	_pg4_p8b_gutter.position = Vector2(430, 334)
	_pg4_p8b_gutter.size = Vector2(812, 360)
	_pg4_p8b_gutter.color = COLOR_INK
	_pg4_p8b_gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pg4_p8b_gutter.visible = false
	_page4.add_child(_pg4_p8b_gutter)

	var p8b := _make_comic_panel(_page4, "Pg4P8bDodge", Rect2(440, 344, 792, 340))
	_pg4_p8b_frame = p8b.frame
	_pg4_p8b_img = p8b.img
	_pg4_p8b_frame.visible = false

	_pg4_p8b_speed = Control.new()
	_pg4_p8b_speed.name = "P8bSpeedLines"
	_pg4_p8b_speed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pg4_p8b_speed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pg4_p8b_speed.visible = false
	_pg4_p8b_frame.add_child(_pg4_p8b_speed)
	for k in range(10):
		var ln := Line2D.new()
		var y0 := 28.0 + float(k) * 30.0
		ln.points = PackedVector2Array([Vector2(790.0, y0 - 24.0), Vector2(540.0 + float(k % 3) * 45.0, y0 + 18.0)])
		ln.width = 2.4 if k % 2 == 0 else 1.5
		ln.default_color = Color(COLOR_PAPER.r, COLOR_PAPER.g, COLOR_PAPER.b, 0.42)
		_pg4_p8b_speed.add_child(ln)


func _build_mid_page5() -> void:
	_page5 = Control.new()
	_page5.name = "Page5_DrawBlade"
	_page5.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page5.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page5.visible = false
	_mid_stage.add_child(_page5)

	# P9 拔刀特写大格 (60, 94, 1160×532)：承载 M5b 0.00s～4.98s 物理连贯 30 帧图集＋尾段程序纯白寒光束
	var p9 := _make_comic_panel(_page5, "Pg5P9Draw", Rect2(60, 94, 1160, 532))
	_pg5_p9_frame = p9.frame
	_pg5_p9_img = p9.img

	_pg5_glint_root = Control.new()
	_pg5_glint_root.name = "P9BladeGlint"
	_pg5_glint_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pg5_glint_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pg5_glint_root.visible = false
	(p9.inner as Control).add_child(_pg5_glint_root)

	_pg5_glint_beam = Polygon2D.new()
	_pg5_glint_beam.name = "GlintBeam"
	_pg5_glint_beam.color = Color(1.0, 1.0, 1.0, 0.0)
	_pg5_glint_root.add_child(_pg5_glint_beam)

	# 柔和径向纯白光晕贴图（替代生硬实心圆心，呈现自然刀锋辉光）
	_pg5_glint_glow = TextureRect.new()
	_pg5_glint_glow.name = "GlintGlow"
	_pg5_glint_glow.texture = _get_glint_glow_tex()
	_pg5_glint_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pg5_glint_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_pg5_glint_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pg5_glint_root.add_child(_pg5_glint_glow)

	# 纤细锐利纯白四芒十字寒光针芒（细针感，不挡人物五官）
	_pg5_glint_star = Polygon2D.new()
	_pg5_glint_star.name = "GlintStar"
	_pg5_glint_star.polygon = PackedVector2Array([
		Vector2(0, -108), Vector2(4, -7),
		Vector2(28, -26), Vector2(7, -4),
		Vector2(158, 0),  Vector2(7, 4),
		Vector2(28, 26),  Vector2(4, 7),
		Vector2(0, 108),  Vector2(-4, 7),
		Vector2(-28, 26), Vector2(-7, 4),
		Vector2(-158, 0), Vector2(-7, -4),
		Vector2(-28, -26), Vector2(-4, -7),
	])
	_pg5_glint_star.color = Color(1.0, 1.0, 1.0, 0.0)
	_pg5_glint_root.add_child(_pg5_glint_star)


func _build_mid_page6() -> void:
	_page6 = Control.new()
	_page6.name = "Page6_ClashAndCleave"
	_page6.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page6.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page6.visible = false
	_mid_stage.add_child(_page6)

	# P9a (新)：左上刀爪相撞格 (48, 40, 760×348) —— 坐标像素级 1:1 对齐 rift3_mid_end.webp
	var p9a := _make_comic_panel(_page6, "Pg6P9aClash", Rect2(48, 40, 760, 348))
	_pg6_p9a_frame = p9a.frame
	_pg6_p9a_img = p9a.img
	_pg6_p9a_mat = ShaderMaterial.new()
	_pg6_p9a_mat.shader = _get_invert_shader()
	_pg6_p9a_mat.set_shader_parameter("invert_amount", 0.0)
	_pg6_p9a_img.material = _pg6_p9a_mat

	# P9b (新)：右下压盖黑槽 (330, 316, 912×378) + 斩怪化雾格 (340, 326, 892×358)
	_pg6_p9b_gutter = ColorRect.new()
	_pg6_p9b_gutter.name = "Pg6P9bGutter"
	_pg6_p9b_gutter.position = Vector2(330, 316)
	_pg6_p9b_gutter.size = Vector2(912, 378)
	_pg6_p9b_gutter.color = COLOR_INK
	_pg6_p9b_gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pg6_p9b_gutter.visible = false
	_page6.add_child(_pg6_p9b_gutter)

	var p9b := _make_comic_panel(_page6, "Pg6P9bCleave", Rect2(340, 326, 892, 358))
	_pg6_p9b_frame = p9b.frame
	_pg6_p9b_img = p9b.img
	_pg6_p9b_frame.visible = false

	# P9b 右上→左下斜斩瞬闪刀光（末 0.15s 收净，无缝移交 P10）
	var cut_dir := Vector2(P10_CUT_BOT_X - P10_CUT_TOP_X, STAGE_SIZE.y).normalized()
	var cut_n := Vector2(-cut_dir.y, cut_dir.x)
	_pg6_p9b_slash_red = Polygon2D.new()
	_pg6_p9b_slash_red.name = "P9bSlashRed"
	_pg6_p9b_slash_red.polygon = _tapered_slash_poly(Vector2(1180, 300) + cut_n * 10.0, Vector2(360, 690) + cut_n * 10.0, cut_n, 14.0)
	_pg6_p9b_slash_red.color = COLOR_CRIMSON
	_pg6_p9b_slash_red.visible = false
	_page6.add_child(_pg6_p9b_slash_red)

	_pg6_p9b_slash_white = Polygon2D.new()
	_pg6_p9b_slash_white.name = "P9bSlashWhite"
	_pg6_p9b_slash_white.polygon = _tapered_slash_poly(Vector2(1190, 294), Vector2(350, 696), cut_n, 18.0)
	_pg6_p9b_slash_white.color = COLOR_PAPER
	_pg6_p9b_slash_white.visible = false
	_page6.add_child(_pg6_p9b_slash_white)


func _bind_p4_shard_textures(tex: Texture2D) -> void:
	if tex == null:
		return
	var ts := tex.get_size()
	for holder in _pg2_p4_shards:
		var poly := holder.get_node_or_null("ShardPoly") as Polygon2D
		if poly != null:
			poly.texture = tex
			poly.uv = _covered_uvs(poly.polygon, STAGE_SIZE, ts, 1.0)


func _set_zoom_rect(tr: TextureRect, base_size: Vector2, zoom: float, offset := Vector2.ZERO) -> void:
	var z := maxf(zoom, 1.0)
	var cur := base_size * z
	tr.size = cur
	tr.position = (base_size - cur) * 0.5 + offset


func _set_frame_border_color(frame: Panel, col: Color) -> void:
	var sb := frame.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.border_color = col


func _build_phase_p10() -> void:
	# 重要：PhaseP10 不放任何全屏不透明底板，确保两半画页滑开后裂口实时透出下方真实 Map004
	_p10_layer = Control.new()
	_p10_layer.name = "PhaseP10"
	_p10_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_p10_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p10_layer.visible = false
	_stage_layer.add_child(_p10_layer)

	# 兼容纹理承载节点（隐藏，实际渲染走下方两块斜切 Polygon2D）
	_p10_end_rect = TextureRect.new()
	_p10_end_rect.name = "P9EndTex"
	_p10_end_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_p10_end_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_p10_end_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_p10_end_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p10_end_rect.visible = false
	_p10_layer.add_child(_p10_end_rect)

	# 裂口后残余紫烟（位处最底，镜像 M6 挥斩一刀劈散）
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

	# 两半斜切第 6 页（P9b 斩怪定格）画页
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

	# M6 透明挥斩前景（已水平镜像为右上→左下）
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

	# 左侧斜切破边漫画立绘残格
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

	var crimson_bar := Polygon2D.new()
	crimson_bar.name = "CrimsonAccent"
	crimson_bar.polygon = PackedVector2Array([Vector2(18, 18), Vector2(26, 18), Vector2(27, 418), Vector2(19, 418)])
	crimson_bar.color = COLOR_CRIMSON
	_p11_portrait_box.add_child(crimson_bar)

	var closed_inner := PackedVector2Array(P11_SHARD_INNER)
	closed_inner.append(P11_SHARD_INNER[0])
	_p11_border_line = Line2D.new()
	_p11_border_line.name = "ShardInkEdge"
	_p11_border_line.points = closed_inner
	_p11_border_line.width = 3.0
	_p11_border_line.default_color = COLOR_INK
	_p11_portrait_box.add_child(_p11_border_line)

	# P11b 25.7s 专用单拍幽紫电纹框边（仅沿右侧撕裂破边亮 0.26s，绝不入正文）
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

	# 兼容纹理承载节点（隐藏，实际经破边 Polygon2D 裁切绘制）
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

	# 为「嗖！」构造基于 XUI.font() 的硬朗瘦劲斜切刀笔 FontVariation（响应小A·文字排版建议）
	var sharp_font: Font = font
	if font != null:
		var fv := FontVariation.new()
		fv.base_font = font
		fv.variation_transform = Transform2D(Vector2(0.90, 0.0), Vector2(-0.20, 1.05), Vector2.ZERO)
		fv.spacing_glyph = 2
		sharp_font = fv

	for cue in SFX_CUES:
		var lbl := Label.new()
		lbl.name = "Sfx_" + str(cue.id)
		lbl.text = str(cue.text)
		lbl.position = cue.pos
		lbl.rotation_degrees = float(cue.rot_deg)
		lbl.visible = false
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_override("font", sharp_font if bool(cue.get("sharp", false)) else font)
		lbl.add_theme_font_size_override("font_size", int(cue.size))
		lbl.add_theme_color_override("font_color", cue.color)
		lbl.add_theme_color_override("font_outline_color", cue.outline)
		var is_blade := str(cue.kind) == "blade"
		lbl.add_theme_constant_override("outline_size", 14 if is_blade else 8)
		if is_blade:
			lbl.add_theme_color_override("font_shadow_color", COLOR_CRIMSON)
			lbl.add_theme_constant_override("shadow_offset_x", 6)
			lbl.add_theme_constant_override("shadow_offset_y", 6)
		elif bool(cue.get("crimson_shadow", false)):
			lbl.add_theme_color_override("font_shadow_color", COLOR_CRIMSON)
			lbl.add_theme_constant_override("shadow_offset_x", 4)
			lbl.add_theme_constant_override("shadow_offset_y", 4)
		elif bool(cue.get("sharp", false)):
			lbl.add_theme_color_override("font_shadow_color", COLOR_INK)
			lbl.add_theme_constant_override("shadow_offset_x", 4)
			lbl.add_theme_constant_override("shadow_offset_y", 3)
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

	# P11b 25.7s 气泡外框右下角单拍幽紫细角（严格在框外，绝不染正文）
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
	var end_tex: Texture2D = _p10_end_rect.texture if (_p10_end_rect != null and _p10_end_rect.texture != null) else _get_p9_fallback_tex()
	if _p10_half_tl != null and _p10_half_br != null and end_tex != null:
		var ts := end_tex.get_size()
		_p10_half_tl.texture = end_tex
		_p10_half_tl.uv = _covered_uvs(_p10_half_tl.polygon, STAGE_SIZE, ts, 1.0)
		_p10_half_br.texture = end_tex
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


## P10 / P7 / P9a 反色冲击帧轻量着色器（兼容 gl_compatibility）
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


## P9 刀锋寒光柔和径向纯白光晕贴图（64×64，中心高光、外缘二次衰减至 0，随实例自动释放）
static func _get_glint_glow_tex() -> Texture2D:
	var sz := 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var half := float(sz) * 0.5
	for y in range(sz):
		for x in range(sz):
			var d := Vector2(float(x) + 0.5 - half, float(y) + 0.5 - half).length() / half
			var a := pow(clampf(1.0 - d, 0.0, 1.0), 2.8)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


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


## P1 无视口传入时的程序占位方桌大厅底图
static func _get_p1_fallback_tex() -> Texture2D:
	if _cached_p1_fallback_tex != null:
		return _cached_p1_fallback_tex
	var w := 320
	var h := 180
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.68, 0.66, 0.62, 1.0))
	for x in range(0, w, 24):
		img.fill_rect(Rect2i(x, 0, 2, h), Color(0.36, 0.35, 0.34, 1.0))
	for y in range(0, h, 24):
		img.fill_rect(Rect2i(0, y, w, 2), Color(0.36, 0.35, 0.34, 1.0))
	img.fill_rect(Rect2i(110, 56, 100, 68), Color(0.42, 0.30, 0.20, 1.0))
	img.fill_rect(Rect2i(116, 62, 88, 56), Color(0.76, 0.64, 0.48, 1.0))
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


## P10 尾帧缺图时的程序占位画页
static func _get_p9_fallback_tex() -> Texture2D:
	if _cached_p9_fallback_tex != null:
		return _cached_p9_fallback_tex
	var w := 320
	var h := 180
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(COLOR_INK)
	var clip := Rect2i(19, 28, 282, 124)
	img.fill_rect(Rect2i(15, 24, 290, 132), COLOR_PAPER)
	img.fill_rect(Rect2i(18, 27, 284, 126), Color(0.08, 0.08, 0.10, 1.0))
	var center := Vector2(188.0, 92.0)
	for i in range(52):
		var ang := float(i) * TAU / 52.0
		var r0 := 30.0 + float(i % 5) * 8.0
		var col := COLOR_PAPER if (i % 3 != 0) else COLOR_GRAY_DARK
		_draw_img_line(img, center + Vector2(cos(ang), sin(ang)) * r0, center + Vector2(cos(ang), sin(ang)) * 195.0, col, clip)
	_fill_img_disc(img, Vector2(96, 148), 58.0, 44.0, COLOR_PAPER, clip)
	_fill_img_disc(img, Vector2(104, 82), 26.0, 30.0, COLOR_PAPER, clip)
	_fill_img_disc(img, Vector2(96, 68), 28.0, 22.0, COLOR_INK, clip)
	_draw_img_ribbon(img, Vector2(114, 58), Vector2(36, 42), 5.0, COLOR_CRIMSON, clip)
	for k in range(-3, 4):
		var col := COLOR_PAPER if abs(k) <= 1 else COLOR_GRAY_LIGHT
		_draw_img_line(img, Vector2(138, 126 + k), Vector2(294, 58 + k), col, clip)
	_cached_p9_fallback_tex = ImageTexture.create_from_image(img)
	return _cached_p9_fallback_tex


## M6 透明挥斩缺图时的程序占位（右上→左下）
static func _get_m6_fallback_tex() -> Texture2D:
	if _cached_m6_fallback_tex != null:
		return _cached_m6_fallback_tex
	var w := 256
	var h := 200
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bounds := Rect2i(0, 0, w, h)
	for step_i in range(180):
		var u := float(step_i) / 179.0
		var bell := sin(u * PI)
		var p := Vector2(lerpf(238.0, 18.0, u), lerpf(16.0, 184.0, u))
		var arc := Vector2(-bell * 40.0, -bell * 22.0)
		var q := p + arc
		var r_w := maxf(bell * 12.0, 1.2)
		_fill_img_disc(img, q + Vector2(6.0, 8.0), r_w * 0.9, r_w * 0.55, COLOR_CRIMSON, bounds)
		_fill_img_disc(img, q, r_w, r_w * 0.52, COLOR_PAPER, bounds)
	_draw_img_ribbon(img, Vector2(216, 26), Vector2(72, 168), 3.6, COLOR_CRIMSON, bounds)
	_cached_m6_fallback_tex = ImageTexture.create_from_image(img)
	return _cached_m6_fallback_tex


## M5a 定妆图缺图时的程序占位
static func _get_m5a_fallback_tex() -> Texture2D:
	if _cached_m5a_fallback_tex != null:
		return _cached_m5a_fallback_tex
	var w := 240
	var h := 220
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(COLOR_INK)
	var bounds := Rect2i(0, 0, w, h)
	_fill_img_disc(img, Vector2(112, 194), 76.0, 74.0, COLOR_PAPER, bounds)
	_fill_img_disc(img, Vector2(116, 68), 22.0, 26.0, COLOR_PAPER, bounds)
	_draw_img_ribbon(img, Vector2(104, 34), Vector2(224, 18), 4.2, COLOR_CRIMSON, bounds)
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
