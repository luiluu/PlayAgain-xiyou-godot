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
## 大厅三阶「蚀骨」总开关（设计稿 重制设定/重制版_大厅三阶异化设计稿_v0.2.md；false 完整退回二阶）。
static var STAGE3_ENABLED := true
## 三阶子开关骨架（15 个，默认全 true；任一置 false 精确退回二阶对应表现）
static var STAGE3_GROUND := true          # 3.1 褪色 10 格、裂纹成片、浮砖 5～7 块离地
static var STAGE3_FOUR_COLORS := true     # 3.2 主厅四角四线渗色与 50 粒光尘
static var STAGE3_WALL_VEINS := true      # 3.3 塔门与墙面蚀骨纹
static var STAGE3_DECAY := true           # 3.8 大厅腐烂破败（家具朽坏、盆栽枯死、墙角地缝霉斑、灯光变暗闪烁；Kyo 11-23）
static var STAGE3_BGM_DETUNE := true      # 3.4 BGM 近距微变调（拆卡 2 挂接）
static var STAGE3_BGM_DROP := true        # 3.4 BGM 偶发安全掉拍（拆卡 2 挂接）
static var STAGE3_HUM_DEEP := true        # 3.4 低鸣外扩至 12 格（拆卡 2 挂接）
static var STAGE3_WHISPER := true         # 3.4 低鸣偶发远处低语（拆卡 2 挂接）
static var STAGE3_NPC_FX := true          # 3.5 玩家 5 格染紫、圈内 NPC 浅染/微偏/重影、气泡扩充
static var STAGE3_NPC_LINES := true       # 3.5 5 位 NPC 三阶追加句
static var STAGE3_MIRROR := true          # 3.6 A 镜子三阶升级句＋镜面剪影
static var STAGE3_STUMP := true           # 3.6 B 练功木桩错向影＋追加句
static var STAGE3_INVESTIGATIONS := true  # 3.7 A 裂纹三段＋新调查点
static var STAGE3_NAME_GLITCH := true     # 3.7 B 地图名牌偶发闪字（拆卡 2 挂接）
static var STAGE3_AMBIENT := true         # 3.7 C 三阶新小字与频次微调（拆卡 2 挂接）
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
## 要整只染幽紫的过场事件备注（＝XRift.MOB_NOTE；按字面写，不依赖 XRift 先合）
const MOB_TINT_NOTE := "<codex_rift_alien_mob>"
const CRACK_DARK := Color(0.09, 0.02, 0.13)
## 正式美术（Codex 11-11 原创，content/lobby/）：有图用图，没图（或测试置空）照旧程序画
static var CRACK_TEX := "res://content/lobby/crack_stage2.png"
static var CRACK_GLOW_TEX := "res://content/lobby/crack_stage2_glow.png"
static var SCALE_TEX := "res://content/lobby/canglong_scale.png"
## 三阶贴花热替换口（拆卡 4 就位后零代码替换；无图或测试置空自动走程序占位）
static var CRACK3_TEX := "res://content/lobby/crack_stage3.png"
static var CRACK3_GLOW_TEX := "res://content/lobby/crack_stage3_glow.png"
static var WALL_VEIN_TEX := "res://content/lobby/wall_vein_stage3.png"
static var WALL_VEIN_H_TEX := "res://content/lobby/wall_vein_h_stage3.png"
static var GATE_VEIN_TEX := "res://content/lobby/gate_vein_stage3.png"
## 三阶腐烂破败热替换口（Kyo 11-23；正式图并进 T419 交小o；无图自动走程序占位）
static var DECAY_FURNITURE_TEX := "res://content/lobby/decay_furniture_stage3.png"
static var DECAY_PLANT_TEX := "res://content/lobby/decay_plant_stage3.png"
static var DECAY_MOLD_TEX := "res://content/lobby/decay_mold_stage3.png"
static var DECAY_LAMP_TEX := "res://content/lobby/decay_lamp_stage3.png"

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
## T420 v0.3 文字审定稿
const STAGE3_AFTER_LINES := {
	1: ["Evil1", 6, "奥尔夫尼", "这大厅本该与神魔之塔各不相干。最近进塔，你没觉得门框比从前凉？"],
	7: ["People12", 6, "大工匠", "这回真不关我的事！连墙根都裂出细纹了，刚才拿锤子敲了两下，里头全是空的。"],
	40: ["", 4, "魂灯商人", "灯火明明没风，火苗却总往墙角偏……那几个角落泛起的光，别盯着看太久。"],
	14: ["People14", 2, "阿伯特", "最近练战技，出招收势总差着半口气——好端端的，像是周遭平白断了一瞬。"],
	17: ["People5_mvt", 4, "衣橱管理员", "衣裳一件没少，可架子底下的影子，怎么数都多出一道……要换形象，麻利些吧。"],
	21: ["", 0, "", "……镜子里站着两个人。另一个就在你肩后半步。回过头，身后什么也没有。"],
	25: ["", 0, "", "……木桩上那道旧刀痕，像是自己合上了。它底下的影子斜着，一直指着大厅中间。"],
}
const MIRROR_EVENT := 21
const MIRROR_CELL := Vector2i(9, 26)
const STUMP_EVENT := 25
const STAGE3_GHOST_EVENTS := [40, 17]
const STAGE3_NPC_RADIUS := 10.5
const STAGE3_NPC_REFRESH := 0.05
## 偶尔冒气泡的人：讨债人两个小弟、猫哥。气泡号：6 汗滴、8 省略号
const BUBBLE_EVENTS := [51, 52, 24]
const STAGE3_BUBBLE_EVENTS := [51, 52, 24, 7, 14]
const BUBBLE_IDS := [6, 8]
## 可调查格（踩在上面按确认键）
const CRACK_CELL := Vector2i(14, 22)
const FIXED_FLOAT := Vector2i(11, 17)
const CRACK_TEXTS := ["地砖裂了一道缝。缝里不是土，是很深的颜色。", "你把手伸过去。缝里是凉的，有风。"]
const FLOAT_TEXT := "这块地砖浮起来一指高。按下去，它又慢慢浮回来。"
const SCALE_TEXT := "一片青色的鳞，还是温的。"
const STAGE3_CRACK_TEXT := "缝口边多了一道齐整的焦痕，像是被谁一刀斩过。底下的风，比上次更冷了。"
const STAGE3_WALL_TEXT := "石墙里渗出细密的暗纹，摸上去冰凉发硬。顺着往北看，纹路一路延向高塔门那边。"
const STAGE3_FLOAT_TEXT := "这块地砖离地快有半掌高了。往缝里看，底下不再是白石，暗沉沉地泛着别的颜色。"
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

## 三阶「蚀骨」视觉常量（数值避开 4；客观坐标与既有名称除外）
const STAGE3_RADIUS := 10.0
const STAGE3_FLOAT_MAX_DIST := 9.2
const STAGE3_FLOAT_NEAR_DIST := 5.0
const FIXED_FLOAT_S3 := Vector2i(18, 16)
const STAGE3_INVEST_CELL := Vector2i(12, 9)   # 北隔墙调查点，浮砖避开
const STAGE3_CRACK_SEED := 0x53B9
const STAGE3_CRACK_BREATH := 5.0
const STAGE3_WALL_BREATH := 5.5
const STAGE3_WALL_ALPHA_MAX := 0.65
const STAGE3_CORNER_BREATH := 7.0
const STAGE3_CORNER_RADIUS := 3.0
const STAGE3_CORNER_ALPHA := 0.18
const STAGE3_CORNER_ALPHA_STATIC := 0.08
const STAGE3_MOTE_RADIUS := 9.0
const STAGE3_CENTRAL_MOTES := 36
const STAGE3_CORNER_MOTES_EACH := 3
const STAGE3_MAX_MOTES := 50
const STAGE3_BRIGHT_CAP := 2
const STAGE3_BRIGHT_MIN := 18.0
const STAGE3_BRIGHT_MAX := 28.0
## 主厅四角四线渗色（西北死亡、东北战争、西南饥荒、东南瘟疫；暂定色值见设计稿 3.2）
const STAGE3_CORNERS := [
	{"id": "death", "cell": Vector2i(5, 10), "base": Color("#DCE6F2"), "mote": Color("#5B8FC5"), "accent": Color("#5B8FC5")},
	{"id": "war", "cell": Vector2i(23, 10), "base": Color("#E85D2A"), "mote": Color("#F2B85B"), "accent": Color("#E85D2A")},
	{"id": "famine", "cell": Vector2i(5, 23), "base": Color("#C8B57C"), "mote": Color("#2A2520"), "accent": Color("#B83B3B")},
	{"id": "plague", "cell": Vector2i(23, 23), "base": Color("#6FA856"), "mote": Color("#5E3A73"), "accent": Color("#6FA856")},
]
## 墙面与高塔之门蚀骨纹位置（Map004 实测墙格；北隔墙横贴 2×1 限 y=8，东西墙竖贴 1×2 避开 y=16 通道）
const STAGE3_GATE_CELL := Vector2i(13, 3)     # 3×2 跨 (13..15, 3..4)，中空留 (14, 3..4) 门洞
const STAGE3_NORTH_WALLS := [Vector2i(10, 8), Vector2i(17, 8)]
const STAGE3_WEST_WALLS := [Vector2i(3, 12), Vector2i(3, 20)]
const STAGE3_EAST_WALLS := [Vector2i(25, 12), Vector2i(25, 20)]
## 三阶腐烂破败层（STAGE3_DECAY，Kyo 11-23）选点与参数（均按 Map004 实测坐标，不改图块与通行）
const STAGE3_DECAY_DIM_BASE := 0.11           # 全厅基础压暗（原雪亮大理石沉下来）
const STAGE3_DECAY_DIM_FLICKER := 0.13        # 偶发闪烁时额外压暗峰值
const STAGE3_DECAY_FLICKER_MIN := 7.0
const STAGE3_DECAY_FLICKER_MAX := 15.0
const STAGE3_DECAY_FLICKER_DUR := 0.35
## 家具朽坏（发灰发黑＋缺角裂木；fest_hide=true 在庆典清桌/奖杯占位期自动隐藏；avoid_mirror=true 避开镜面中央）
const STAGE3_DECAY_FURNITURE := [
	{"id": "center_table", "cell": Vector2i(13, 11), "size": Vector2i(3, 1), "fest_hide": true, "avoid_mirror": false},
	{"id": "center_chair", "cell": Vector2i(14, 10), "size": Vector2i(1, 1), "fest_hide": true, "avoid_mirror": false},
	{"id": "wardrobe", "cell": Vector2i(8, 26), "size": Vector2i(1, 2), "fest_hide": false, "avoid_mirror": false},
	{"id": "vanity", "cell": Vector2i(9, 26), "size": Vector2i(1, 2), "fest_hide": false, "avoid_mirror": true},
	{"id": "north_table_w", "cell": Vector2i(10, 9), "size": Vector2i(1, 1), "fest_hide": false, "avoid_mirror": false},
	{"id": "north_table_e", "cell": Vector2i(18, 9), "size": Vector2i(1, 1), "fest_hide": false, "avoid_mirror": false},
	{"id": "south_rail_e", "cell": Vector2i(18, 26), "size": Vector2i(3, 1), "fest_hide": false, "avoid_mirror": false},
	{"id": "north_rail_w", "cell": Vector2i(6, 7), "size": Vector2i(5, 1), "fest_hide": false, "avoid_mirror": false},
	{"id": "north_rail_e", "cell": Vector2i(18, 7), "size": Vector2i(5, 1), "fest_hide": false, "avoid_mirror": false},
]
## 枯死盆栽（墙脚装饰位，均实测无事件、不压栏杆柱、不改通行）
const STAGE3_DECAY_PLANTS := [
	Vector2i(5, 9), Vector2i(23, 9),
	Vector2i(7, 24), Vector2i(21, 24),
	Vector2i(10, 25), Vector2i(16, 25),
]
## 墙角与地缝霉斑（贴墙根与瓷砖缝）
const STAGE3_DECAY_MOLDS := [
	Vector2i(4, 10), Vector2i(24, 10), Vector2i(4, 23), Vector2i(24, 23),
	Vector2i(4, 14), Vector2i(4, 20), Vector2i(24, 14), Vector2i(24, 20),
	Vector2i(7, 9), Vector2i(21, 9),
	Vector2i(8, 25), Vector2i(10, 27), Vector2i(17, 25), Vector2i(20, 27),
	Vector2i(11, 15), Vector2i(17, 21),
]
## 真实灯具（变暗昏黄＋偶发闪烁；中央红桌双烛台在庆典清桌时自动隐藏）
const STAGE3_DECAY_LAMPS := [
	{"id": "table_candle_w", "cell": Vector2i(13, 11), "fest_hide": true},
	{"id": "table_candle_e", "cell": Vector2i(15, 11), "fest_hide": true},
	{"id": "north_candle_w", "cell": Vector2i(10, 8), "fest_hide": false},
	{"id": "north_candle_e", "cell": Vector2i(18, 8), "fest_hide": false},
	{"id": "floor_lamp_se", "cell": Vector2i(17, 26), "fest_hide": false},
]

static var _rift_script: Variant = false   # false 未查；null 没有 XRift；否则脚本
static var _ambient_last_ms := -AMBIENT_GAP_MS
static var _ambient_index := 0
## 天启篇会话内去重（T415：不写存档 _remakeLobbyCorruption／maxStage，也不改 flags.tianqi；按 XState 实例 ID 隔离）
static var _tq_said_session := {}
static var _tq_crack_session := {}

var host: XMapScene
var rng := RandomNumberGenerator.new()
var floats: Array[Vector2i] = []
var _float_lift := {}        # 格 → 当前抬起像素
var _t := 0.0
var _s3 := false             # 建层时是否处于三阶激活态（非天启篇、总闸开、stage >= 3）
var _cracks: Array = []      # [PackedVector2Array]
var _crack_base: Node2D
var _crack_glow: Node2D
var _cracks3: Array = []     # 三阶次生裂纹主缝 [PackedVector2Array]
var _cracks3_sub: Array = [] # 三阶次生裂纹支网 [PackedVector2Array]
var _crack3_base: Node2D
var _crack3_glow: Node2D
var _crack3_is_tex := false
var _desat: Sprite2D
var _corners_node: Node2D
var _corner_sprites: Array[Sprite2D] = []
var _wall_veins_node: Node2D
var _gate_vein_node: Node2D
var _wall_vein_items: Array[Node2D] = []
var _wall_veins_is_tex := false
var _gate_vein_is_tex := false
var _decay_molds_node: Node2D
var _decay_mold_items: Array[Node2D] = []
var _decay_furniture_node: Node2D
var _decay_furniture_items: Array = []   # [{node: Node2D, fest_hide: bool}]
var _decay_plants_node: Node2D
var _decay_plant_items: Array[Node2D] = []
var _decay_light_node: Node2D
var _decay_dim_node: Node2D
var _decay_lamp_items: Array = []        # [{node: Node2D, fest_hide: bool, phase: float}]
var _decay_dim_alpha := 0.0
var _decay_next_flicker := 0.0
var _decay_flicker_left := 0.0
var _decay_last_fest := -1               # -1 未初始化，0/1 缓存上帧庆典态，避免每帧反复刷可见性
var _decay_tex_used := {"furniture": false, "plant": false, "mold": false, "lamp": false}
var _floats_node: Node2D
var _motes_node: Node2D
var _motes: Array = []       # {p: Vector2, v: Vector2, a: float, r: float, bright: bool, life: float, corner: int, col: Color}
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
var _s3_npc_fx := false
var _s3_npc_lines := false
var _s3_mirror := false
var _s3_stump := false
var _s3_investigations := false
var _npc_fx: Dictionary[MVEvent, Sprite2D] = {}
var _npc_y_offsets: Dictionary[MVEvent, Vector2] = {}  # 原生 Y、叠加后的 Y
var _shadow_texture: GradientTexture2D
var _stump_shadow: Sprite2D
var _crack_scorch: Node2D
var _next_npc_refresh := 0.0
var _next_wall_tremor := 0.0
var _wall_tremor_until := 0.0
var _dialogue_ghost: Sprite2D
var _ghost_speaker_id := 0
var _ghost_started := 0.0
var _mirror_ghost: Sprite2D
var _mirror_pending := false


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


## 大厅三阶「蚀骨」要不要激活（显式排除天启篇存档；不传参读 XState.current，传 null 返回 false）
static func stage3_active(s: Variant = false) -> bool:
	var st: Variant = XState.current if s is bool else s
	return ENABLED and STAGE3_ENABLED and stage() >= 3 and st is XState and not XTianqi.active(st)


func _s3_ground() -> bool:
	return _s3 and STAGE3_ENABLED and STAGE3_GROUND


func _s3_four_colors() -> bool:
	return _s3 and STAGE3_ENABLED and STAGE3_FOUR_COLORS


func _s3_wall_veins() -> bool:
	return _s3 and STAGE3_ENABLED and STAGE3_WALL_VEINS


func _s3_decay() -> bool:
	return _s3 and STAGE3_ENABLED and STAGE3_DECAY


func stage3_on() -> bool:
	return _s3 and STAGE3_ENABLED


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
	if s and not XTianqi.active(s):
		var r := record(s)
		r["maxStage"] = maxi(int(r.get("maxStage", 1)), stage())
	_s3 = stage3_active(s)
	# 这五个子开关随地图初始化，演出中途不重挂节点。
	_s3_npc_fx = _s3 and STAGE3_NPC_FX
	_s3_npc_lines = _s3 and STAGE3_NPC_LINES
	_s3_mirror = _s3 and STAGE3_MIRROR
	_s3_stump = _s3 and STAGE3_STUMP
	_s3_investigations = _s3 and STAGE3_INVESTIGATIONS
	_build_desat()
	_build_corners()
	_build_decay_molds()
	_build_cracks()
	_pick_floats()
	_floats_node = _layer(_draw_floats)
	_scale_node = _layer(_draw_scale)
	if SCALE_TEX != "" and ResourceLoader.exists(SCALE_TEX):
		_scale_tex = load(SCALE_TEX)
	_motes_node = _layer(_draw_motes)
	_build_wall_veins()
	_build_decay_props()
	if _s3_stump:
		_build_stump_shadow()
	if _s3_investigations and XConfig.whisper_seen("rift3"):
		_crack_scorch = _layer(_draw_crack_scorch)
	_build_audio()
	_next_drip = rng.randf_range(60.0, 90.0)
	_next_bubble = rng.randf_range(50.0, 95.0) if _s3_npc_fx else rng.randf_range(20.0, 60.0)
	if _s3_npc_fx:
		_next_wall_tremor = rng.randf_range(5.0, 8.0)
	_next_bright = rng.randf_range(STAGE3_BRIGHT_MIN, STAGE3_BRIGHT_MAX) if _s3_four_colors() else rng.randf_range(20.0, 30.0)
	_decay_next_flicker = rng.randf_range(STAGE3_DECAY_FLICKER_MIN, STAGE3_DECAY_FLICKER_MAX)
	_maybe_ambient.call_deferred()


func _exit_tree() -> void:
	for e in _npc_fx.keys():
		_clear_npc_fx(e)
	if is_instance_valid(_stump_shadow) and not _stump_shadow.is_queued_for_deletion():
		_stump_shadow.hide()
		_stump_shadow.queue_free()
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


# ---- 地面：褪色、四角渗色、裂纹、浮砖 ----

func _build_desat() -> void:
	var s3 := _s3_ground()
	var rad := STAGE3_RADIUS if s3 else RADIUS
	var g := Gradient.new()
	if s3:
		g.set_color(0, Color(0.78, 0.76, 0.83))
		g.set_color(1, Color.WHITE)
		g.add_point(0.5, Color(0.89, 0.88, 0.92))
	else:
		g.set_color(0, Color(0.88, 0.87, 0.9))
		g.set_color(1, Color.WHITE)
		g.add_point(0.5, Color(0.94, 0.935, 0.95))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = int(rad * 2 * TS)
	tex.height = int(rad * 2 * TS)
	_desat = Sprite2D.new()
	_desat.texture = tex
	_desat.position = cell_px(CENTER)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_desat.material = m
	add_child(_desat)


## 主厅四角四线贴地渗色（仅三阶且 STAGE3_FOUR_COLORS 开着时构建；最大不透明度 0.18，7.0 秒错相呼吸）
func _build_corners() -> void:
	_corner_sprites.clear()
	if not _s3_four_colors():
		return
	_corners_node = Node2D.new()
	_corners_node.name = "Stage3Corners"
	add_child(_corners_node)
	var sz := int(STAGE3_CORNER_RADIUS * 2 * TS)
	for cfg in STAGE3_CORNERS:
		var base: Color = cfg.base
		var mote: Color = cfg.mote
		var core := base.lerp(mote, 0.45)
		var g := Gradient.new()
		g.set_color(0, Color(core.r, core.g, core.b, 1.0))
		g.set_color(1, Color(mote.r, mote.g, mote.b, 0.0))
		g.add_point(0.5, Color(mote.r, mote.g, mote.b, 0.55))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = sz
		tex.height = sz
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.position = cell_px(cfg.cell)
		sp.modulate.a = STAGE3_CORNER_ALPHA_STATIC if not fx_on() else STAGE3_CORNER_ALPHA * 0.8
		_corners_node.add_child(sp)
		_corner_sprites.append(sp)


## 裂纹：固定种子，从漩涡边缘向外辐射，最长 3 格；正南那条固定通到可调查的裂缝格；三阶先在底下叠 11×11 次生网
func _build_cracks() -> void:
	if _s3_ground():
		_build_stage3_cracks()
	# 正式贴花：336×336（7×7 格），图心对准漩涡中心；微光层单独一张，跟程序画法一样 6 秒呼吸（三阶加快到 5 秒）
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


## 三阶 11×11 格（528×528，最远 5.5 格）网状次生裂纹：有正式图用图，没图按固定种子 0x53B9 程序续画
func _build_stage3_cracks() -> void:
	_cracks3.clear()
	_cracks3_sub.clear()
	_crack3_is_tex = false
	if CRACK3_TEX != "" and ResourceLoader.exists(CRACK3_TEX):
		_crack3_glow = Node2D.new()
		if CRACK3_GLOW_TEX != "" and ResourceLoader.exists(CRACK3_GLOW_TEX):
			var g := Sprite2D.new()
			g.texture = load(CRACK3_GLOW_TEX)
			g.position = cell_px(CENTER)
			_crack3_glow.add_child(g)
		add_child(_crack3_glow)
		_crack3_base = Node2D.new()
		var b := Sprite2D.new()
		b.texture = load(CRACK3_TEX)
		b.position = cell_px(CENTER)
		_crack3_base.add_child(b)
		add_child(_crack3_base)
		_crack3_is_tex = true
		return
	var r := RandomNumberGenerator.new()
	r.seed = STAGE3_CRACK_SEED
	var c := cell_px(CENTER)
	var max_r := 5.35 * TS   # 严守 11×11 格（528×528，半宽 5.5 格）边界
	var spokes := 15
	var mids: Array[Vector2] = []
	for i in spokes:
		var ang := TAU * i / spokes + r.randf_range(-0.16, 0.16)
		var start := r.randf_range(1.75, 2.35) * TS
		var length := minf(r.randf_range(1.8, 3.0) * TS, max_r - start)
		var main_line := _crack_line_clamped(r, c, ang, start, length, c, max_r)
		_cracks3.append(main_line)
		if main_line.size() > 3:
			var mid_idx := mini(main_line.size() - 2, maxi(2, int(main_line.size() * 0.55)))
			var mid_pt: Vector2 = main_line[mid_idx]
			mids.append(mid_pt)
			# 主次生裂纹生出 1～2 条交错斜支
			var branches := 2 if r.randf() < 0.65 else 1
			for bi in branches:
				var sign := 1.0 if (bi % 2 == 0) else -1.0
				var b_ang := ang + sign * r.randf_range(0.55, 1.05)
				var b_pt: Vector2 = main_line[mini(main_line.size() - 2, maxi(1, mid_idx + (bi * 2 - 1)))]
				_cracks3_sub.append(_crack_line_clamped(r, b_pt, b_ang, 0.0, r.randf_range(0.7, 1.35) * TS, c, max_r))
	# 相邻次生主缝之间连几道交错桥接细纹，形成成片裂网
	for i in mids.size():
		if i % 2 == 0 and mids.size() > 2:
			var a: Vector2 = mids[i]
			var b: Vector2 = mids[(i + 1) % mids.size()]
			if a.distance_to(b) < 2.9 * TS:
				_cracks3_sub.append(_bridge_line(r, a, b))
	# 正南裂纹 (14,22) 附近顺延两道斜向细支，衔接二阶最长主缝
	var south_tip := cell_px(CRACK_CELL) - Vector2(0, 0.2 * TS)
	_cracks3.append(_crack_line_clamped(r, south_tip, PI / 2 + 0.55, 0.0, 1.15 * TS, c, max_r))
	_cracks3.append(_crack_line_clamped(r, south_tip, PI / 2 - 0.52, 0.0, 1.05 * TS, c, max_r))
	_crack3_glow = _layer(_draw_cracks3.bind(true))
	_crack3_base = _layer(_draw_cracks3.bind(false))


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


func _crack_line_clamped(r: RandomNumberGenerator, origin: Vector2, ang: float, start: float, length: float, center: Vector2, max_r: float) -> PackedVector2Array:
	var raw := _crack_line(r, origin, ang, start, length)
	var out := PackedVector2Array()
	for pt in raw:
		var rel := pt - center
		if rel.length() > max_r:
			pt = center + rel.normalized() * max_r
		out.append(pt)
	return out


func _bridge_line(r: RandomNumberGenerator, a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var segs := 5
	var dir := (b - a).normalized()
	var perp := Vector2(-dir.y, dir.x)
	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var jitter := 0.0 if (i == 0 or i == segs) else r.randf_range(-5.5, 5.5)
		pts.append(a.lerp(b, t) + perp * jitter)
	return pts


func _draw_cracks(glow: bool) -> void:
	var n := _crack_glow if glow else _crack_base
	for pts in _cracks:
		if glow:
			n.draw_polyline(pts, Color(PURPLE, 0.3), 3.5, true)
		else:
			n.draw_polyline(pts, Color(CRACK_DARK, 0.85), 1.5, true)


func _draw_cracks3(glow: bool) -> void:
	var n := _crack3_glow if glow else _crack3_base
	for pts in _cracks3:
		if glow:
			n.draw_polyline(pts, Color(PURPLE, 0.36), 5.0, true)
		else:
			n.draw_polyline(pts, Color(CRACK_DARK, 0.9), 2.1, true)
	for pts in _cracks3_sub:
		if glow:
			n.draw_polyline(pts, Color(PURPLE, 0.22), 3.0, true)
		else:
			n.draw_polyline(pts, Color(CRACK_DARK, 0.72), 1.2, true)


# ---- 墙面与高塔之门蚀骨纹（仅三阶且 STAGE3_WALL_VEINS 开着时构建）----

func _build_wall_veins() -> void:
	_wall_vein_items.clear()
	_gate_vein_node = null
	_wall_veins_is_tex = false
	_gate_vein_is_tex = false
	if not _s3_wall_veins():
		return
	_wall_veins_node = Node2D.new()
	_wall_veins_node.name = "Stage3WallVeins"
	_wall_veins_node.z_as_relative = false
	_wall_veins_node.z_index = -8   # 在下层墙面（-10）之上、人物（0）与上层图块（10）之下
	_wall_veins_node.modulate.a = 0.55
	add_child(_wall_veins_node)

	# 1. 正北高塔之门左右门框（3×2 格 144×96，中空留门洞；庆典横幅期间自动隐藏）
	_gate_vein_node = Node2D.new()
	_gate_vein_node.name = "GateVeins"
	_gate_vein_node.position = Vector2(STAGE3_GATE_CELL * TS)
	if GATE_VEIN_TEX != "" and ResourceLoader.exists(GATE_VEIN_TEX):
		var sp := Sprite2D.new()
		sp.texture = load(GATE_VEIN_TEX)
		sp.position = Vector2(1.5 * TS, 1.0 * TS)
		_gate_vein_node.add_child(sp)
		_gate_vein_is_tex = true
	else:
		var lines := _gen_gate_veins(0x6A7E)
		_gate_vein_node.draw.connect(_draw_vein_lines.bind(_gate_vein_node, lines))
	_gate_vein_node.visible = not XFestLobby.decor()
	_wall_veins_node.add_child(_gate_vein_node)
	_wall_vein_items.append(_gate_vein_node)

	# 2. 主厅北隔墙横纹（2×1 格 96×48，严格限 y=8 单行）
	var has_h := WALL_VEIN_H_TEX != "" and ResourceLoader.exists(WALL_VEIN_H_TEX)
	var h_tex: Texture2D = load(WALL_VEIN_H_TEX) if has_h else null
	for i in STAGE3_NORTH_WALLS.size():
		var cell: Vector2i = STAGE3_NORTH_WALLS[i]
		var n := Node2D.new()
		n.position = Vector2(cell * TS)
		if h_tex != null:
			var sp := Sprite2D.new()
			sp.texture = h_tex
			sp.position = Vector2(TS, TS * 0.5)
			sp.flip_h = (i == 1)
			n.add_child(sp)
		else:
			var lines := _gen_horiz_veins(0x7101 + i * 19, i == 0)
			n.draw.connect(_draw_vein_lines.bind(n, lines))
		_wall_veins_node.add_child(n)
		_wall_vein_items.append(n)

	# 3. 主厅东西墙竖纹（1×2 格 48×96，避开 y=16 通道；东西墙不同种子避免机械镜像）
	var has_v := WALL_VEIN_TEX != "" and ResourceLoader.exists(WALL_VEIN_TEX)
	var v_tex: Texture2D = load(WALL_VEIN_TEX) if has_v else null
	for i in STAGE3_WEST_WALLS.size():
		var cell: Vector2i = STAGE3_WEST_WALLS[i]
		var n := Node2D.new()
		n.position = Vector2(cell * TS)
		if v_tex != null:
			var sp := Sprite2D.new()
			sp.texture = v_tex
			sp.position = Vector2(TS * 0.5, TS)
			n.add_child(sp)
		else:
			var lines := _gen_vert_veins(0x7201 + i * 29, true)
			n.draw.connect(_draw_vein_lines.bind(n, lines))
		_wall_veins_node.add_child(n)
		_wall_vein_items.append(n)
	for i in STAGE3_EAST_WALLS.size():
		var cell: Vector2i = STAGE3_EAST_WALLS[i]
		var n := Node2D.new()
		n.position = Vector2(cell * TS)
		if v_tex != null:
			var sp := Sprite2D.new()
			sp.texture = v_tex
			sp.position = Vector2(TS * 0.5, TS)
			sp.flip_h = true
			n.add_child(sp)
		else:
			var lines := _gen_vert_veins(0x7307 + i * 31, false)
			n.draw.connect(_draw_vein_lines.bind(n, lines))
		_wall_veins_node.add_child(n)
		_wall_vein_items.append(n)
	_wall_veins_is_tex = has_v and has_h and _gate_vein_is_tex


func _gen_gate_veins(seed_val: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	var main_lines: Array = []
	var sub_lines: Array = []
	# 左右门柱各自在 [6..43] 与 [101..138] 攀爬，中空 [48..96] 严留门洞
	for side in [0, 1]:
		var x_min := 6.0 if side == 0 else 101.0
		var x_max := 43.0 if side == 0 else 138.0
		var inner_x := 38.0 if side == 0 else 106.0
		var dir_x := 1.0 if side == 0 else -1.0
		for k in 2:
			var pts := PackedVector2Array()
			var x := clampf(inner_x - dir_x * (6.0 + k * 13.0) + r.randf_range(-2.0, 2.0), x_min, x_max)
			var y := 92.0
			pts.append(Vector2(x, y))
			var top_y := 16.0 if k == 0 else 32.0
			while y > top_y:
				y = maxf(top_y, y - r.randf_range(7.0, 11.0))
				x = clampf(x + dir_x * r.randf_range(-3.0, 4.5), x_min, x_max)
				pts.append(Vector2(x, y))
				if y < 82.0 and y > top_y + 10.0 and r.randf() < 0.5:
					var b := PackedVector2Array()
					b.append(Vector2(x, y))
					var bx := clampf(x + dir_x * r.randf_range(5.0, 11.0), x_min, x_max)
					var by := clampf(y - r.randf_range(6.0, 12.0), 10.0, 90.0)
					b.append(Vector2(lerpf(x, bx, 0.5) + r.randf_range(-2.0, 2.0), lerpf(y, by, 0.5)))
					b.append(Vector2(bx, by))
					sub_lines.append(b)
			main_lines.append(pts)
	return {"main": main_lines, "sub": sub_lines}


func _gen_horiz_veins(seed_val: int, toward_right: bool) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	var main_lines: Array = []
	var sub_lines: Array = []
	var dx := 1.0 if toward_right else -1.0
	# 横贴 96×48，所有点严格限制在白石护墙板正中 x:[6..90], y:[10..38]，绝不盖到 y=7 或 y=9 地砖
	for k in 2:
		var pts := PackedVector2Array()
		var x := (10.0 if toward_right else 86.0) + dx * k * 12.0
		var y := 36.0 - k * 5.0
		pts.append(Vector2(x, y))
		for _step in 8:
			x = clampf(x + dx * r.randf_range(8.0, 11.5), 6.0, 90.0)
			y = clampf(y - r.randf_range(1.6, 3.8) + r.randf_range(-1.2, 1.2), 10.0, 38.0)
			pts.append(Vector2(x, y))
			if r.randf() < 0.45:
				var b := PackedVector2Array()
				b.append(Vector2(x, y))
				b.append(Vector2(clampf(x + dx * r.randf_range(4.0, 10.0), 6.0, 90.0), clampf(y + r.randf_range(-6.0, 5.0), 10.0, 38.0)))
				sub_lines.append(b)
		main_lines.append(pts)
	return {"main": main_lines, "sub": sub_lines}


func _gen_vert_veins(seed_val: int, west_side: bool) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	var main_lines: Array = []
	var sub_lines: Array = []
	# Map004 东西墙白石内壁分别贴在 x=3 右缘（30..46）与 x=25 左缘（2..18），贴白石面画，绝不漂到墙外黑边
	var x_min := 30.0 if west_side else 2.0
	var x_max := 46.0 if west_side else 18.0
	var dir_in := 1.0 if west_side else -1.0
	for k in 2:
		var pts := PackedVector2Array()
		var x := clampf((42.0 if west_side else 6.0) - dir_in * k * 6.0, x_min, x_max)
		var y := 89.0 - k * 8.0
		pts.append(Vector2(x, y))
		while y > 10.0 + k * 12.0:
			y = maxf(6.0, y - r.randf_range(7.0, 11.0))
			x = clampf(x + r.randf_range(-3.0, 3.0), x_min, x_max)
			pts.append(Vector2(x, y))
			if y < 80.0 and y > 18.0 and r.randf() < 0.5:
				var b := PackedVector2Array()
				b.append(Vector2(x, y))
				b.append(Vector2(clampf(x - dir_in * r.randf_range(4.0, 9.0), x_min, x_max), clampf(y - r.randf_range(5.0, 11.0), 6.0, 90.0)))
				sub_lines.append(b)
		main_lines.append(pts)
	return {"main": main_lines, "sub": sub_lines}


func _draw_vein_lines(n: Node2D, data: Dictionary) -> void:
	for pts in data.main:
		n.draw_polyline(pts, Color(PURPLE, 0.42), 4.5, true)
		n.draw_polyline(pts, Color(CRACK_DARK, 0.92), 2.0, true)
	for pts in data.sub:
		n.draw_polyline(pts, Color(PURPLE, 0.28), 2.8, true)
		n.draw_polyline(pts, Color(CRACK_DARK, 0.78), 1.2, true)


# ---- 大厅腐烂破败层（STAGE3_DECAY，Kyo 11-23：墙角地缝霉斑、家具朽坏、枯死盆栽、灯光变暗闪烁）----

func _build_decay_molds() -> void:
	_decay_mold_items.clear()
	_decay_tex_used["mold"] = false
	if not _s3_decay():
		return
	_decay_molds_node = Node2D.new()
	_decay_molds_node.name = "Stage3DecayMolds"
	add_child(_decay_molds_node)   # z_index 继承 -9，贴在地面之上、裂纹与浮砖之下
	var has_tex := DECAY_MOLD_TEX != "" and ResourceLoader.exists(DECAY_MOLD_TEX)
	var tex: Texture2D = load(DECAY_MOLD_TEX) if has_tex else null
	_decay_tex_used["mold"] = has_tex
	for i in STAGE3_DECAY_MOLDS.size():
		var cell: Vector2i = STAGE3_DECAY_MOLDS[i]
		var n := Node2D.new()
		n.position = Vector2(cell * TS)
		if tex != null:
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.position = Vector2(TS * 0.5, TS * 0.5)
			sp.modulate.a = 0.75
			n.add_child(sp)
		else:
			var blobs := _gen_mold_cluster(0x5D17 + i * 37)
			n.draw.connect(_draw_mold_cluster.bind(n, blobs))
		_decay_molds_node.add_child(n)
		_decay_mold_items.append(n)


func _gen_mold_cluster(seed_val: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	var outer: Array = []
	var mid: Array = []
	var specks: Array = []
	var cx := r.randf_range(16.0, 32.0)
	var cy := r.randf_range(16.0, 32.0)
	for _i in 3:
		outer.append([Vector2(cx + r.randf_range(-11.0, 11.0), cy + r.randf_range(-11.0, 11.0)), r.randf_range(9.0, 16.0), Vector2(r.randf_range(0.7, 1.3), r.randf_range(0.6, 1.1)), r.randf_range(-0.8, 0.8)])
	for _i in 5:
		mid.append([Vector2(cx + r.randf_range(-10.0, 10.0), cy + r.randf_range(-10.0, 10.0)), r.randf_range(5.0, 9.5), Vector2(r.randf_range(0.7, 1.2), r.randf_range(0.6, 1.1)), r.randf_range(-1.0, 1.0)])
	for _i in 9:
		specks.append([Vector2(cx + r.randf_range(-15.0, 15.0), cy + r.randf_range(-15.0, 15.0)), r.randf_range(1.6, 3.6)])
	return {"outer": outer, "mid": mid, "specks": specks}


func _draw_mold_cluster(n: Node2D, data: Dictionary) -> void:
	for b in data.outer:
		n.draw_set_transform(b[0], b[3], b[2])
		n.draw_circle(Vector2.ZERO, b[1], Color(0.24, 0.23, 0.14, 0.26))
	for b in data.mid:
		n.draw_set_transform(b[0], b[3], b[2])
		n.draw_circle(Vector2.ZERO, b[1], Color(0.16, 0.23, 0.15, 0.42))
	n.draw_set_transform(Vector2.ZERO)
	for s in data.specks:
		n.draw_circle(s[0], s[1], Color(0.08, 0.10, 0.07, 0.56))


func _build_decay_props() -> void:
	_decay_furniture_items.clear()
	_decay_plant_items.clear()
	_decay_lamp_items.clear()
	_decay_tex_used["furniture"] = false
	_decay_tex_used["plant"] = false
	_decay_tex_used["lamp"] = false
	_decay_dim_alpha = 0.0
	if not _s3_decay():
		return
	var fest := XFestLobby.decor()

	# 1) 家具朽坏（发灰发黑＋缺角裂木；z=-8 在下层家具之上、人物之下）
	_decay_furniture_node = Node2D.new()
	_decay_furniture_node.name = "Stage3DecayFurniture"
	_decay_furniture_node.z_as_relative = false
	_decay_furniture_node.z_index = -8
	add_child(_decay_furniture_node)
	var has_ftex := DECAY_FURNITURE_TEX != "" and ResourceLoader.exists(DECAY_FURNITURE_TEX)
	var ftex: Texture2D = load(DECAY_FURNITURE_TEX) if has_ftex else null
	_decay_tex_used["furniture"] = has_ftex
	for i in STAGE3_DECAY_FURNITURE.size():
		var cfg: Dictionary = STAGE3_DECAY_FURNITURE[i]
		var n := Node2D.new()
		n.position = Vector2(cfg.cell * TS)
		var sz := Vector2(cfg.size * TS)
		if ftex != null:
			var sp := Sprite2D.new()
			sp.texture = ftex
			sp.position = sz * 0.5
			var tw := maxf(1.0, float(ftex.get_width()))
			var th := maxf(1.0, float(ftex.get_height()))
			sp.scale = Vector2(sz.x / tw, sz.y / th)
			n.add_child(sp)
		else:
			var geom := _gen_furniture_decay(0x5F21 + i * 53, sz, bool(cfg.avoid_mirror))
			n.draw.connect(_draw_furniture_decay.bind(n, geom))
		var fh := bool(cfg.fest_hide)
		n.visible = not (fh and fest)
		_decay_furniture_node.add_child(n)
		_decay_furniture_items.append({"node": n, "fest_hide": fh})

	# 2) 盆栽／植物枯死（墙脚与栏柱脚装饰位，均无事件、不改通行；z=-8）
	_decay_plants_node = Node2D.new()
	_decay_plants_node.name = "Stage3DecayPlants"
	_decay_plants_node.z_as_relative = false
	_decay_plants_node.z_index = -8
	add_child(_decay_plants_node)
	var has_ptex := DECAY_PLANT_TEX != "" and ResourceLoader.exists(DECAY_PLANT_TEX)
	var ptex: Texture2D = load(DECAY_PLANT_TEX) if has_ptex else null
	_decay_tex_used["plant"] = has_ptex
	for i in STAGE3_DECAY_PLANTS.size():
		var cell: Vector2i = STAGE3_DECAY_PLANTS[i]
		var n := Node2D.new()
		n.position = Vector2(cell * TS)
		if ptex != null:
			var sp := Sprite2D.new()
			sp.texture = ptex
			sp.position = Vector2(TS * 0.5, TS * 0.5)
			n.add_child(sp)
		else:
			var pdata := _gen_withered_plant(0x5B33 + i * 29)
			n.draw.connect(_draw_withered_plant.bind(n, pdata))
		_decay_plants_node.add_child(n)
		_decay_plant_items.append(n)

	# 3) 灯光变暗与偶发闪烁（z=15 在上层图块之上，不影响 CanvasLayer UI）
	_decay_light_node = Node2D.new()
	_decay_light_node.name = "Stage3DecayLights"
	_decay_light_node.z_as_relative = false
	_decay_light_node.z_index = 15
	add_child(_decay_light_node)
	_decay_dim_alpha = STAGE3_DECAY_DIM_BASE
	_decay_dim_node = Node2D.new()
	var map_w := float(host.lower.width * TS) if (host != null and host.lower != null) else float(29 * TS)
	var map_h := float(host.lower.height * TS) if (host != null and host.lower != null) else float(33 * TS)
	_decay_dim_node.draw.connect(_draw_decay_dim.bind(_decay_dim_node, Rect2(Vector2.ZERO, Vector2(map_w, map_h))))
	_decay_dim_node.modulate.a = _decay_dim_alpha
	_decay_light_node.add_child(_decay_dim_node)

	var has_ltex := DECAY_LAMP_TEX != "" and ResourceLoader.exists(DECAY_LAMP_TEX)
	var ltex: Texture2D = load(DECAY_LAMP_TEX) if has_ltex else _make_lamp_dim_tex()
	_decay_tex_used["lamp"] = has_ltex
	for i in STAGE3_DECAY_LAMPS.size():
		var cfg: Dictionary = STAGE3_DECAY_LAMPS[i]
		var sp := Sprite2D.new()
		sp.texture = ltex
		sp.position = cell_px(cfg.cell)
		sp.modulate.a = 0.62
		var fh := bool(cfg.fest_hide)
		sp.visible = not (fh and fest)
		_decay_light_node.add_child(sp)
		_decay_lamp_items.append({"node": sp, "fest_hide": fh, "phase": i * 1.37})


func _gen_furniture_decay(seed_val: int, sz: Vector2, avoid_mirror: bool) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	var top_y := 32.0 if avoid_mirror else 3.0
	var body := Rect2(Vector2(3.0, top_y), Vector2(maxf(8.0, sz.x - 6.0), maxf(8.0, sz.y - top_y - 3.0)))
	var chips: Array = []
	# 缺角三角形：放在家具边角处模拟朽烂崩缺
	var corners := [
		[Vector2(body.position.x, body.position.y), Vector2(1.0, 0.0), Vector2(0.0, 1.0)],
		[Vector2(body.end.x, body.position.y), Vector2(-1.0, 0.0), Vector2(0.0, 1.0)],
		[Vector2(body.position.x, body.end.y), Vector2(1.0, 0.0), Vector2(0.0, -1.0)],
		[Vector2(body.end.x, body.end.y), Vector2(-1.0, 0.0), Vector2(0.0, -1.0)],
	]
	for idx in [0, 3] if r.randf() < 0.5 else [1, 2]:
		var c = corners[idx]
		var p0: Vector2 = c[0]
		var w := r.randf_range(7.0, 13.0)
		var h := r.randf_range(6.0, 11.0)
		var poly := PackedVector2Array([p0, p0 + c[1] * w, p0 + c[1] * (w * 0.55) + c[2] * (h * 0.55), p0 + c[2] * h])
		chips.append(poly)
	var cracks: Array = []
	var crack_n := clampi(int(sz.x / TS) + 1, 2, 5)
	for _i in crack_n:
		var sx := r.randf_range(body.position.x + 5.0, body.end.x - 5.0)
		var sy := r.randf_range(body.position.y + 5.0, body.end.y - 5.0)
		var pts := PackedVector2Array([Vector2(sx, sy)])
		for _s in 3:
			sx = clampf(sx + r.randf_range(-9.0, 9.0), body.position.x + 2.0, body.end.x - 2.0)
			sy = clampf(sy + r.randf_range(-7.0, 7.0), body.position.y + 2.0, body.end.y - 2.0)
			pts.append(Vector2(sx, sy))
		cracks.append(pts)
	var stains: Array = []
	for _i in clampi(int(sz.x / TS) + 2, 3, 6):
		stains.append([Vector2(r.randf_range(body.position.x + 6.0, body.end.x - 6.0), r.randf_range(body.position.y + 6.0, body.end.y - 6.0)), r.randf_range(5.0, 11.0)])
	return {"body": body, "chips": chips, "cracks": cracks, "stains": stains}


func _draw_furniture_decay(n: Node2D, g: Dictionary) -> void:
	# 整体发灰发黑去色层
	n.draw_rect(g.body, Color(0.09, 0.09, 0.10, 0.42), true)
	for st in g.stains:
		n.draw_circle(st[0], st[1], Color(0.06, 0.07, 0.06, 0.34))
	# 木板裂纹
	for pts in g.cracks:
		n.draw_polyline(pts, Color(0.05, 0.04, 0.04, 0.85), 1.6, true)
	# 边角朽烂缺角＋浅灰断茬边
	for poly in g.chips:
		n.draw_colored_polygon(poly, Color(0.04, 0.03, 0.04, 0.90))
		n.draw_polyline(poly, Color(0.35, 0.33, 0.30, 0.65), 1.2, true)


func _gen_withered_plant(seed_val: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	var stems: Array = []
	var leaves: Array = []
	var fallen: Array = []
	var base := Vector2(24.0, 26.0)
	for i in 5:
		var ang := -PI * 0.85 + float(i) * (PI * 0.7 / 4.0) + r.randf_range(-0.12, 0.12)
		var mid := base + Vector2(cos(ang) * r.randf_range(7.0, 11.0), sin(ang) * r.randf_range(8.0, 13.0))
		# 枯枝前端向下垂萎
		var tip := mid + Vector2(cos(ang) * r.randf_range(5.0, 9.0), r.randf_range(3.0, 9.0))
		stems.append(PackedVector2Array([base, mid, tip]))
		leaves.append([tip, r.randf_range(2.8, 4.2), Color(0.46, 0.37, 0.16, 0.92) if i % 2 == 0 else Color(0.32, 0.25, 0.12, 0.92)])
		leaves.append([mid.lerp(tip, 0.55), r.randf_range(2.2, 3.2), Color(0.38, 0.31, 0.14, 0.88)])
	for _i in 3:
		fallen.append([Vector2(r.randf_range(8.0, 40.0), r.randf_range(38.0, 45.0)), r.randf_range(1.8, 2.8), r.randf_range(-1.0, 1.0)])
	return {"stems": stems, "leaves": leaves, "fallen": fallen}


func _draw_withered_plant(n: Node2D, d: Dictionary) -> void:
	# 底座阴影
	n.draw_set_transform(Vector2(24.0, 41.0), 0.0, Vector2(1.0, 0.35))
	n.draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.32))
	n.draw_set_transform(Vector2.ZERO)
	# 灰褐裂纹陶盆
	var pot := PackedVector2Array([Vector2(15.0, 27.0), Vector2(33.0, 27.0), Vector2(30.0, 41.0), Vector2(18.0, 41.0)])
	n.draw_colored_polygon(pot, Color(0.30, 0.25, 0.22, 0.95))
	n.draw_polyline(pot, Color(0.12, 0.10, 0.09, 0.9), 1.4, true)
	n.draw_rect(Rect2(Vector2(13.0, 24.0), Vector2(22.0, 4.5)), Color(0.36, 0.30, 0.26, 0.96), true)
	# 陶盆裂纹
	n.draw_polyline(PackedVector2Array([Vector2(22.0, 28.0), Vector2(24.0, 33.0), Vector2(21.0, 39.0)]), Color(0.08, 0.06, 0.06, 0.92), 1.3, true)
	# 枯萎下垂枝条与枯黄叶片
	for pts in d.stems:
		n.draw_polyline(pts, Color(0.24, 0.19, 0.12, 0.95), 2.0, true)
	for lf in d.leaves:
		n.draw_set_transform(lf[0], 0.4, Vector2(1.3, 0.65))
		n.draw_circle(Vector2.ZERO, lf[1], lf[2])
	# 散落枯叶
	for fl in d.fallen:
		n.draw_set_transform(fl[0], fl[2], Vector2(1.4, 0.55))
		n.draw_circle(Vector2.ZERO, fl[1], Color(0.40, 0.31, 0.15, 0.82))
	n.draw_set_transform(Vector2.ZERO)


func _draw_decay_dim(n: Node2D, rect: Rect2) -> void:
	n.draw_rect(rect, Color(0.05, 0.04, 0.08, 1.0), true)


func _make_lamp_dim_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.36, 0.28, 0.13, 0.45))   # 中心病态昏黄暗火
	g.set_color(1, Color(0.05, 0.04, 0.08, 0.0))    # 必须在 add_point 之前改末点，确保外缘平滑归零透明
	g.add_point(0.38, Color(0.08, 0.07, 0.11, 0.36)) # 中圈烟熏压暗阴影
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = int(2.6 * TS)
	tex.height = int(2.6 * TS)
	return tex


func _update_decay(dt: float, fest: bool) -> void:
	var on := _s3_decay()
	if _decay_molds_node != null:
		_decay_molds_node.visible = on
	if _decay_furniture_node != null:
		_decay_furniture_node.visible = on
	if _decay_plants_node != null:
		_decay_plants_node.visible = on
	if _decay_light_node != null:
		_decay_light_node.visible = on
	if not on:
		_decay_dim_alpha = 0.0
		return
	var fest_i := 1 if fest else 0
	if fest_i != _decay_last_fest:
		_decay_last_fest = fest_i
		for row in _decay_furniture_items:
			var n: Node2D = row.node
			if is_instance_valid(n):
				n.visible = not (bool(row.fest_hide) and fest)
		for row in _decay_lamp_items:
			var sp: Node2D = row.node
			if is_instance_valid(sp):
				sp.visible = not (bool(row.fest_hide) and fest)
	# 偶发灯光闪烁（关「画面特效」时仅保持静态压暗，不闪烁）
	var fx := fx_on()
	var flicker_add := 0.0
	if fx:
		if _decay_flicker_left > 0.0:
			_decay_flicker_left = maxf(0.0, _decay_flicker_left - dt)
			var u := 1.0 - _decay_flicker_left / STAGE3_DECAY_FLICKER_DUR
			# 双闪脉冲（0.15 与 0.65 两波急暗回弹）
			var wave := absf(sin(u * PI * 2.0))
			flicker_add = STAGE3_DECAY_DIM_FLICKER * wave
		else:
			_decay_next_flicker -= dt
			if _decay_next_flicker <= 0.0:
				_decay_flicker_left = STAGE3_DECAY_FLICKER_DUR
				_decay_next_flicker = rng.randf_range(STAGE3_DECAY_FLICKER_MIN, STAGE3_DECAY_FLICKER_MAX)
	else:
		_decay_flicker_left = 0.0
	_decay_dim_alpha = STAGE3_DECAY_DIM_BASE + flicker_add
	if _decay_dim_node != null:
		_decay_dim_node.modulate.a = _decay_dim_alpha
	var lamp_wave := (0.35 if flicker_add > 0.03 else 0.0)
	for row in _decay_lamp_items:
		var sp: Node2D = row.node
		if is_instance_valid(sp) and sp.visible:
			var sway := 0.06 * sin(_t * 3.1 + float(row.phase)) if fx else 0.0
			sp.modulate.a = clampf(0.62 + sway + lamp_wave, 0.25, 0.95)


## 浮砖：二阶固定 (11,17)＋随机 1～2 块；三阶固定 (11,17) 与 (18,16)＋10 格内随机 3～5 块（总 5～7 块）
func _pick_floats() -> void:
	floats.clear()
	_float_lift.clear()
	var s3 := _s3_ground()
	var fixed: Array[Vector2i] = [FIXED_FLOAT]
	if s3:
		fixed.append(FIXED_FLOAT_S3)
	for fc in fixed:
		if float_ok(fc):
			floats.append(fc)
	var span := 10 if s3 else 6
	var cand: Array[Vector2i] = []
	for y in range(CENTER.y - span, CENTER.y + span + 1):
		for x in range(CENTER.x - span, CENTER.x + span + 1):
			var c := Vector2i(x, y)
			if not floats.has(c) and float_ok(c):
				cand.append(c)
	var want := rng.randi_range(3, 5) if s3 else rng.randi_range(1, 2)
	while want > 0 and not cand.is_empty():
		var c: Vector2i = cand.pop_at(rng.randi_range(0, cand.size() - 1))
		if floats.all(func(f): return absi(f.x - c.x) + absi(f.y - c.y) > 2):
			floats.append(c)
			want -= 1
	for f in floats:
		_float_lift[f] = _float_rest_lift(f)


func _float_rest_lift(c: Vector2i) -> float:
	if not _s3_ground():
		return 6.0
	return 11.0 if Vector2(c - CENTER).length() <= STAGE3_FLOAT_NEAR_DIST + 0.001 else 7.0


func float_ok(c: Vector2i) -> bool:
	var s3 := _s3_ground()
	var d := Vector2(c - CENTER).length()
	var max_d := STAGE3_FLOAT_MAX_DIST if s3 else (RADIUS - 0.8)
	if d < 2.0 or d > max_d:
		return false
	# 漩涡上下左右的弹回路线与苍龙走位（竖 x 12～16、横 y 18～20，天然避开庆典事件格 (12/14/15/16,10)）
	if (c.x >= CENTER.x - 2 and c.x <= CENTER.x + 2) or (c.y >= CENTER.y - 1 and c.y <= CENTER.y + 1):
		return false
	if c == CRACK_CELL or c == drop_cell() or (s3 and c == STAGE3_INVEST_CELL):
		return false
	if host == null or host.lower == null or not host.lower.is_valid(c):
		return false
	if s3:
		if not [2, 4, 6, 8].all(func(dir): return host.lower.is_passable(c.x, c.y, dir)):
			return false
	else:
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
	var s3 := _s3_ground()
	var prev := tm._canvas
	tm._canvas = _floats_node
	for f in floats:
		var lift: float = _float_lift.get(f, 0.0)
		var p := Vector2(f * TS)
		if s3 and lift > 0.5:
			# 三阶近圈离地更明显：原格位露出一圈极窄暗紫地缝，底影加浓
			var k := clampf(lift / 11.0, 0.0, 1.0)
			var pit := Rect2(p + Vector2(2.0, 2.0), Vector2(TS - 4.0, TS - 4.0))
			_floats_node.draw_rect(pit, Color(CRACK_DARK, 0.45 * k), true)
			_floats_node.draw_rect(pit, Color(PURPLE, 0.32 * k), false, 1.5)
		# 底下一小圈影子
		_floats_node.draw_set_transform(p + Vector2(TS / 2.0, TS - 6), 0.0, Vector2(1.0, 0.32 if s3 else 0.3))
		var shadow_a := (0.16 + lift * 0.028) if s3 else (0.12 + lift * 0.03)
		_floats_node.draw_circle(Vector2.ZERO, TS * (0.44 if s3 else 0.42), Color(0, 0, 0, clampf(shadow_a, 0.0, 0.55)))
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


## 测试看：三阶视觉各层状态与热替换口
func desat_radius_cells() -> float:
	if _desat == null or _desat.texture == null:
		return 0.0
	return _desat.texture.get_width() / (2.0 * TS)


func has_stage3_cracks() -> bool:
	return _crack3_base != null and _crack3_base.visible


func crack3_textured() -> bool:
	return _crack3_is_tex


func corner_count() -> int:
	if _corners_node == null or not _corners_node.visible:
		return 0
	return _corner_sprites.size()


func wall_vein_count() -> int:
	if _wall_veins_node == null or not _wall_veins_node.visible:
		return 0
	var n := 0
	for item in _wall_vein_items:
		if is_instance_valid(item) and item.visible:
			n += 1
	return n


func gate_vein_visible() -> bool:
	return _wall_veins_node != null and _wall_veins_node.visible and _gate_vein_node != null and _gate_vein_node.visible


func wall_veins_textured() -> bool:
	return _wall_veins_is_tex


func gate_vein_textured() -> bool:
	return _gate_vein_is_tex


func decay_furniture_count() -> int:
	if _decay_furniture_node == null or not _decay_furniture_node.visible:
		return 0
	var n := 0
	for row in _decay_furniture_items:
		if is_instance_valid(row.node) and row.node.visible:
			n += 1
	return n


func decay_plant_count() -> int:
	if _decay_plants_node == null or not _decay_plants_node.visible:
		return 0
	return _decay_plant_items.size()


func decay_mold_count() -> int:
	if _decay_molds_node == null or not _decay_molds_node.visible:
		return 0
	return _decay_mold_items.size()


func decay_lamp_count() -> int:
	if _decay_light_node == null or not _decay_light_node.visible:
		return 0
	var n := 0
	for row in _decay_lamp_items:
		if is_instance_valid(row.node) and row.node.visible:
			n += 1
	return n


func decay_dim_alpha() -> float:
	return _decay_dim_alpha


func decay_textured() -> Dictionary:
	return _decay_tex_used.duplicate()


## 测试用：立即触发一次腐烂灯光闪烁（正常游戏由独立 rng 定时触发）
func trigger_decay_flicker() -> void:
	if _s3_decay() and fx_on():
		_decay_flicker_left = STAGE3_DECAY_FLICKER_DUR


func scale_cell() -> Vector2i:
	return _scale_cell


# ---- 光尘 ----

func _spawn_mote(bright := false, max_rad := RADIUS) -> Dictionary:
	var c := cell_px(CENTER)
	if bright:
		var a := rng.randf() * TAU
		return {"p": c, "v": Vector2.from_angle(a) * 22.0, "a": 0.9, "r": 2.6, "bright": true, "life": 2.0 * TS / 22.0, "corner": -1, "col": Color(0.85, 0.75, 1.0)}
	var ang := rng.randf() * TAU
	var dist := rng.randf_range(1.6, max_rad) * TS
	return {"p": c + Vector2.from_angle(ang) * dist, "v": Vector2.ZERO, "a": rng.randf_range(0.3, 0.55),
		"r": rng.randf_range(1.5, 2.6), "bright": false, "life": 0.0, "corner": -1, "col": PURPLE.darkened(0.15)}


func _spawn_corner_mote(ci: int) -> Dictionary:
	var cfg: Dictionary = STAGE3_CORNERS[ci]
	var origin := cell_px(cfg.cell)
	var ang := rng.randf() * TAU
	var dist := rng.randf_range(0.25, STAGE3_CORNER_RADIUS - 0.35) * TS
	var col: Color = cfg.accent if (ci == 2 and rng.randf() < 0.3) else cfg.mote
	var speed := Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-9.0, -3.5))
	return {"p": origin + Vector2.from_angle(ang) * dist, "v": speed, "a": rng.randf_range(0.35, 0.62),
		"r": rng.randf_range(1.6, 2.5), "bright": false, "life": rng.randf_range(3.0, 6.0), "corner": ci, "col": col}


func _update_motes(dt: float) -> void:
	if not fx_on():
		_motes.clear()
		return
	var s3c := _s3_four_colors()
	var c := cell_px(CENTER)
	if not s3c:
		# 退回二阶（28 粒上限、纯幽紫、6 格吸附）
		for i in range(_motes.size() - 1, -1, -1):
			if int(_motes[i].get("corner", -1)) >= 0:
				_motes.remove_at(i)
		while _motes.size() > MAX_MOTES:
			_motes.pop_back()
		while _motes.size() < MAX_MOTES - 1:
			_motes.append(_spawn_mote(false, RADIUS))
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
				_motes[i] = _spawn_mote(false, RADIUS)
				continue
			m.v = m.v.lerp(to.normalized() * lerpf(10.0, 26.0, 1.0 - d / (RADIUS * TS)) + Vector2(0, -3), clampf(dt * 2.0, 0.0, 1.0))
			m.p += m.v * dt
		_next_bright -= dt
		if _next_bright <= 0.0:
			_next_bright = rng.randf_range(20.0, 30.0)
			if _motes.size() < MAX_MOTES:
				_motes.append(_spawn_mote(true, RADIUS))
		return

	# 三阶：36 中央幽紫（9 格吸附）＋ 四角各 3 粒本线色微尘（12 粒，仅在各自 3 格内缓飘）＋ 最多 2 粒逆向亮尘 ＝ 50 上限
	var central_n := 0
	var bright_n := 0
	var corner_n := [0, 0, 0, 0]
	var max_dist_px := STAGE3_MOTE_RADIUS * TS
	var corner_rad_px := STAGE3_CORNER_RADIUS * TS
	for i in range(_motes.size() - 1, -1, -1):
		var m: Dictionary = _motes[i]
		var ci: int = int(m.get("corner", -1))
		if m.bright:
			m.p += m.v * dt
			m.life -= dt
			m.a = clampf(m.life, 0.0, 0.9)
			if m.life <= 0.0:
				_motes.remove_at(i)
			else:
				bright_n += 1
			continue
		if ci >= 0:
			var origin := cell_px(STAGE3_CORNERS[ci].cell)
			m.life -= dt
			m.p += m.v * dt
			if m.life <= 0.0 or Vector2(m.p).distance_to(origin) > corner_rad_px:
				_motes[i] = _spawn_corner_mote(ci)
			corner_n[ci] += 1
			continue
		var to: Vector2 = c - m.p
		var d: float = to.length()
		if d < 0.8 * TS:
			_motes[i] = _spawn_mote(false, STAGE3_MOTE_RADIUS)
		else:
			m.v = m.v.lerp(to.normalized() * lerpf(10.0, 26.0, clampf(1.0 - d / max_dist_px, 0.0, 1.0)) + Vector2(0, -3), clampf(dt * 2.0, 0.0, 1.0))
			m.p += m.v * dt
		central_n += 1
	while central_n < STAGE3_CENTRAL_MOTES and _motes.size() < STAGE3_MAX_MOTES:
		_motes.append(_spawn_mote(false, STAGE3_MOTE_RADIUS))
		central_n += 1
	for ci in STAGE3_CORNERS.size():
		while corner_n[ci] < STAGE3_CORNER_MOTES_EACH and _motes.size() < STAGE3_MAX_MOTES:
			_motes.append(_spawn_corner_mote(ci))
			corner_n[ci] += 1
	_next_bright -= dt
	if _next_bright <= 0.0:
		_next_bright = rng.randf_range(STAGE3_BRIGHT_MIN, STAGE3_BRIGHT_MAX)
		if bright_n < STAGE3_BRIGHT_CAP and _motes.size() < STAGE3_MAX_MOTES:
			_motes.append(_spawn_mote(true, STAGE3_MOTE_RADIUS))


func _draw_motes() -> void:
	var c := cell_px(CENTER)
	var corner_rad_px := STAGE3_CORNER_RADIUS * TS
	for m in _motes:
		var ci: int = int(m.get("corner", -1))
		if ci >= 0:
			var origin := cell_px(STAGE3_CORNERS[ci].cell)
			var edge_fade := clampf((corner_rad_px - Vector2(m.p).distance_to(origin)) / (0.8 * TS), 0.0, 1.0)
			var col: Color = m.col
			_motes_node.draw_circle(m.p, m.r * 1.9, Color(col, m.a * edge_fade * 0.22))
			_motes_node.draw_circle(m.p, m.r, Color(col, m.a * edge_fade))
			continue
		var fade := 1.0 if m.bright else clampf((Vector2(m.p).distance_to(c) - 0.8 * TS) / TS, 0.0, 1.0)
		var col := Color(0.85, 0.75, 1.0) if m.bright else PURPLE.darkened(0.15)   # 白色大理石上浅紫看不见，用深一点的紫
		if m.bright:
			_motes_node.draw_circle(m.p, m.r * 2.4, Color(PURPLE, m.a * 0.25))
		_motes_node.draw_circle(m.p, m.r, Color(col, m.a * fade))


func mote_count() -> int:
	return _motes.size()


func corner_mote_count() -> int:
	var n := 0
	for m in _motes:
		if int(m.get("corner", -1)) >= 0:
			n += 1
	return n


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
	var npc_fx := _s3_npc_fx and stage3_on()
	var refresh_npcs := npc_fx and _t >= _next_npc_refresh
	if refresh_npcs:
		_next_npc_refresh = _t + STAGE3_NPC_REFRESH
		if _t >= _next_wall_tremor:
			_wall_tremor_until = _t + 0.16
			_next_wall_tremor = _t + rng.randf_range(5.0, 8.0)
	for e in host.events:
		if not is_instance_valid(e):
			continue
		# XRift EV207 保留专用的整只染紫。
		if str(e.data.get("note", "")) == MOB_TINT_NOTE:
			if e.self_modulate != PURPLE:
				e.self_modulate = PURPLE
				if not _tinted.has(e):
					_tinted.append(e)
		elif refresh_npcs:
			_update_npc_fx(e)
	if not _npc_fx.is_empty() and (refresh_npcs or not npc_fx):
		for e in _npc_fx.keys():
			if not npc_fx or not is_instance_valid(e) or e.is_queued_for_deletion():
				_clear_npc_fx(e)
	var chars: Array = [host.player] + host.followers
	for c in chars:
		if not is_instance_valid(c):
			continue
		var d: float = c.real.distance_to(Vector2(CENTER))
		var k := clampf((5.0 - d) / 3.0, 0.0, 1.0) * 0.25 if npc_fx else clampf((2.5 - d) / 1.5, 0.0, 1.0) * 0.15
		var col := Color.WHITE.lerp(PURPLE, k)
		if c.self_modulate != col:
			c.self_modulate = col
			if not _tinted.has(c):
				_tinted.append(c)


func _update_npc_fx(e: MVEvent) -> void:
	var id := e.event_id
	var d2 := (e.grid - CENTER).length_squared()
	if e.erased or not _has_walk_sprite(e) or id == 67 or (id >= 75 and id <= 81) \
			or (id >= 201 and id <= 207) or d2 > STAGE3_NPC_RADIUS * STAGE3_NPC_RADIUS:
		if _npc_fx.has(e):
			_clear_npc_fx(e)
		return
	var col := Color.WHITE.lerp(PURPLE, lerpf(0.18, 0.12, sqrt(d2) / STAGE3_NPC_RADIUS))
	if e.self_modulate != col:
		e.self_modulate = col
	if not _npc_fx.has(e):
		_npc_fx[e] = _add_shadow(e, Vector2(0.0, -3.0), 0.24)
	var offset := 0.0
	if id >= 50 and id <= 52:
		offset = -5.0
	elif (e.grid.x == 4 or e.grid.x == 24) and _t < _wall_tremor_until:
		# 沿墙竖向微颤，避免横移进墙。
		offset = -1.0 if _wall_tremor_until - _t > 0.08 else 1.0
	_apply_npc_y(e, offset)


func _apply_npc_y(e: MVEvent, offset: float) -> void:
	var current := e.frames_offset.y
	var prior: Vector2 = _npc_y_offsets.get(e, Vector2(current, current))
	# 原生换页或换图可以重设 frames_offset，清除效果时保留新值。
	var base := prior.x if current == prior.y else current
	if current != base + offset:
		e.frames_offset.y = base + offset
		e.queue_redraw()
	if offset == 0.0:
		_npc_y_offsets.erase(e)
	else:
		_npc_y_offsets[e] = Vector2(base, base + offset)


func _clear_npc_fx(e: Variant) -> void:
	var shadow: Sprite2D = _npc_fx[e]
	if is_instance_valid(shadow) and not shadow.is_queued_for_deletion():
		shadow.hide()
		shadow.queue_free()
	if is_instance_valid(e):
		e.self_modulate = Color.WHITE
		_apply_npc_y(e, 0.0)
	else:
		_npc_y_offsets.erase(e)
	_npc_fx.erase(e)


func _add_shadow(anchor: Node2D, offset: Vector2, alpha: float) -> Sprite2D:
	if _shadow_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.12, 0.035, 0.17))
		gradient.set_color(1, Color(0.12, 0.035, 0.17, 0.0))
		_shadow_texture = GradientTexture2D.new()
		_shadow_texture.gradient = gradient
		_shadow_texture.width = 36
		_shadow_texture.height = 12
		_shadow_texture.fill = GradientTexture2D.FILL_RADIAL
		_shadow_texture.fill_from = Vector2(0.5, 0.5)
		_shadow_texture.fill_to = Vector2(1.0, 0.5)
	var shadow := Sprite2D.new()
	shadow.texture = _shadow_texture
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shadow.z_as_relative = false
	shadow.z_index = -8
	shadow.position = offset
	shadow.self_modulate.a = alpha
	anchor.add_child(shadow)
	return shadow


func _build_stump_shadow() -> void:
	var stump := _event_by_id(STUMP_EVENT)
	if stump == null:
		return
	var toward := Vector2(CENTER - stump.grid).normalized()
	_stump_shadow = _add_shadow(stump, toward * 11.0 - Vector2(0.0, 3.0), 0.28)
	_stump_shadow.rotation = toward.angle()
	_stump_shadow.scale.y = 0.65


func _draw_crack_scorch() -> void:
	var center := cell_px(CRACK_CELL)
	_crack_scorch.draw_polyline(PackedVector2Array([center + Vector2(-8, 3), center, center + Vector2(6, -4)]), Color(0.23, 0.08, 0.29, 0.82), 2.0, true)


func _event_by_id(id: int) -> MVEvent:
	for e in host.events:
		if is_instance_valid(e) and e.event_id == id and not e.erased:
			return e
	return null


static func _has_walk_sprite(c: MVCharacter) -> bool:
	return c.visible and not c.transparent and not c._anim_hidden and c.opacity > 0 and c.character_name != "" and c._tex != null


func _make_ghost(source: MVCharacter, ink: Color, alpha: float) -> Sprite2D:
	var ghost := Sprite2D.new()
	ghost.name = "CorruptionGhost"
	var mat := ShaderMaterial.new()
	mat.shader = XBattlerSprite.body_shader()
	mat.set_shader_parameter("blend", ink)
	ghost.material = mat
	ghost.region_enabled = true
	ghost.region_filter_clip_enabled = true
	ghost.centered = false
	ghost.z_as_relative = false
	ghost.z_index = 1
	ghost.modulate.a = alpha
	_sample_ghost(ghost, source)
	return ghost


static func _sample_ghost(ghost: Sprite2D, source: MVCharacter) -> void:
	ghost.texture = source._tex
	var walk := source._walk
	var size: Vector2 = walk.cell
	var seq: Array = walk.sequence
	var pattern: int = seq[source.pattern % seq.size()]
	var row: int = walk.rows.get(source.direction, 0)
	ghost.region_rect = Rect2(Vector2(walk.origin) + Vector2(pattern * size.x, row * size.y), size)
	ghost.offset = source.frames_shift() - Vector2(size.x / 2.0, size.y + (0.0 if source.is_object() else 6.0))


func _start_dialogue_ghost(id: int) -> void:
	var speaker := _event_by_id(id)
	if speaker == null or not _has_walk_sprite(speaker):
		return
	_dialogue_ghost = _make_ghost(speaker, Color(0.40, 0.23, 0.65), 0.32)
	add_child(_dialogue_ghost)
	_ghost_speaker_id = id
	_ghost_started = _t
	_update_dialogue_ghost()


func _update_dialogue_ghost() -> void:
	var speaker := _event_by_id(_ghost_speaker_id)
	if speaker == null or not _has_walk_sprite(speaker) or not stage3_on():
		_dialogue_ghost.hide()
		return
	_dialogue_ghost.show()
	_sample_ghost(_dialogue_ghost, speaker)
	_dialogue_ghost.position = speaker.position + Vector2(3.0 + sin((_t - _ghost_started) * TAU / 0.25), 0.0)


func _start_mirror_ghost() -> void:
	var source := host.player
	if not is_instance_valid(source) or not _has_walk_sprite(source):
		return
	var mirror := _event_by_id(MIRROR_EVENT)
	if mirror == null or mirror.grid != MIRROR_CELL:
		return
	var ghost := _make_ghost(source, Color(0.26, 0.12, 0.37), 0.44)
	_mirror_ghost = ghost
	add_child(ghost)
	var size := ghost.region_rect.size
	ghost.scale = Vector2.ONE * minf(1.0, minf(30.0 / size.x, 34.0 / size.y))
	ghost.offset = Vector2(-size.x / 2.0, -size.y / 2.0)
	ghost.position = cell_px(MIRROR_CELL) - Vector2(0.0, 3.0)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.6)
	tw.tween_callback(ghost.queue_free)


func _update_bubbles(dt: float) -> void:
	_next_bubble -= dt
	if _next_bubble > 0.0:
		return
	var s3 := _s3_npc_fx and stage3_on()
	_next_bubble = rng.randf_range(50.0, 95.0) if s3 else rng.randf_range(60.0, 120.0)
	if not quiet():
		return
	var pool := STAGE3_BUBBLE_EVENTS if s3 else BUBBLE_EVENTS
	var id: int = pool[rng.randi_range(0, pool.size() - 1)]
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
	_ambient.size = Vector2(XSkin4A.view_size(host).x, 40)  # 新界面 4A：铺满时按可见宽度居中（关着 1280）
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
	var s3g := _s3_ground()
	var crack_period := STAGE3_CRACK_BREATH if s3g else 6.0
	var crack_alpha := 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * TAU / crack_period))
	_crack_glow.modulate.a = crack_alpha
	if _crack3_base != null:
		_crack3_base.visible = s3g
	if _crack3_glow != null:
		_crack3_glow.visible = s3g
		if s3g:
			_crack3_glow.modulate.a = crack_alpha
	if _corners_node != null:
		var s3c := _s3_four_colors()
		_corners_node.visible = s3c
		if s3c:
			var fx := fx_on()
			for i in _corner_sprites.size():
				var sp := _corner_sprites[i]
				if not fx:
					sp.modulate.a = STAGE3_CORNER_ALPHA_STATIC
				else:
					sp.modulate.a = 0.10 + (STAGE3_CORNER_ALPHA - 0.10) * (0.5 + 0.5 * sin(_t * TAU / STAGE3_CORNER_BREATH + i * TAU / float(STAGE3_CORNERS.size())))
	var fest := XFestLobby.decor() if (_wall_veins_node != null or _decay_light_node != null) else false
	if _wall_veins_node != null:
		var s3w := _s3_wall_veins()
		_wall_veins_node.visible = s3w
		if s3w:
			_wall_veins_node.modulate.a = 0.38 + (STAGE3_WALL_ALPHA_MAX - 0.38) * (0.5 + 0.5 * sin(_t * TAU / STAGE3_WALL_BREATH))
			if _gate_vein_node != null:
				_gate_vein_node.visible = not fest
	_update_decay(dt, fest)
	var moved := false
	for f in floats:
		var target := 0.0
		if not _occupied(f):
			if s3g:
				var near := Vector2(f - CENTER).length() <= STAGE3_FLOAT_NEAR_DIST + 0.001
				target = (11.0 + 2.0 * sin(_t * TAU / STAGE3_CRACK_BREATH + f.x)) if near else (7.0 + 1.5 * sin(_t * TAU / STAGE3_CRACK_BREATH + f.x))
			else:
				target = 6.0 + 1.5 * sin(_t * TAU / 4.0 + f.x)
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
	if is_instance_valid(_stump_shadow):
		var stump := _stump_shadow.get_parent() as MVEvent
		_stump_shadow.visible = stage3_on() and not stump.erased and _has_walk_sprite(stump)
	if is_instance_valid(_crack_scorch):
		_crack_scorch.visible = stage3_on()
	if is_instance_valid(_dialogue_ghost):
		_update_dialogue_ghost()
	_update_bubbles(dt)


# ---- 追加台词与调查 ----

## 天启篇会话内已说追记表（不写存档）
static func _tq_said(s: XState) -> Array:
	var key := s.get_instance_id()
	if _tq_said_session.size() > 16:
		for k in _tq_said_session.keys():
			if not is_instance_id_valid(k):
				_tq_said_session.erase(k)
	if not _tq_said_session.has(key):
		_tq_said_session[key] = []
	return _tq_said_session[key]


## 这次确认键启动的事件跑完后要不要追加一句（启动前判定：事件在表里、当前页有内容、本存档还没说过；天启篇走会话内去重、不写存档）
func wants_after(e: MVEvent) -> bool:
	var s := XState.current
	if s == null:
		return false
	if not AFTER_LINES.has(e.event_id) and not (_s3 and STAGE3_AFTER_LINES.has(e.event_id)):
		return false
	return e.command_list().size() > 1 and _after_key(e.event_id, _said(s), _s3 and stage3_active(s)) != ""


func after_event(event_id: int) -> void:
	var s := XState.current
	if s == null or not is_instance_valid(host) or host.map_id != MAP_ID:
		return
	var s3 := _s3 and stage3_active(s)
	if not AFTER_LINES.has(event_id) and (not s3 or not STAGE3_AFTER_LINES.has(event_id)):
		return
	var said := _said(s)
	var key := _after_key(event_id, said, s3)
	if key == "":
		return
	var row: Array
	if key.begins_with("s3:"):
		row = STAGE3_AFTER_LINES[event_id]
		if event_id == MIRROR_EVENT:
			_mirror_pending = true
			_start_mirror_ghost()
			await get_tree().create_timer(0.3).timeout
			_mirror_pending = false
			# 剪影期间仍可走动；转场、换档或另开窗口时不抢占新事件。
			if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(host) \
					or host.map_id != MAP_ID or XState.current != s or not stage3_active(s) or not quiet():
				if is_instance_valid(_mirror_ghost):
					_mirror_ghost.hide()
					_mirror_ghost.queue_free()
				return
		elif _s3_npc_fx and STAGE3_GHOST_EVENTS.has(event_id):
			_start_dialogue_ghost(event_id)
	else:
		var custom := XTianqiHallText.corruption_after(s, event_id)
		row = custom if not custom.is_empty() else AFTER_LINES[event_id]
	said.append(key)
	await host.run_command_list(text_list(row[0], row[1], row[2], row[3]))
	if is_instance_valid(_dialogue_ghost):
		_dialogue_ghost.hide()
		_dialogue_ghost.queue_free()
		_dialogue_ghost = null


static func _said(s: XState) -> Array:
	return _tq_said(s) if XTianqi.active(s) else (record(s).said as Array)


func _after_key(id: int, said: Array, s3: bool) -> String:
	var key := str(id)
	var old_line := AFTER_LINES.has(id) and not said.has(key)
	var s3_key := "s3:" + key
	if s3:
		if id == MIRROR_EVENT and _s3_mirror and not old_line:
			return s3_key if not _mirror_pending and not said.has(s3_key) else ""
		if (id == STUMP_EVENT and _s3_stump) or (_s3_npc_lines and STAGE3_AFTER_LINES.has(id) and id != MIRROR_EVENT and id != STUMP_EVENT):
			return s3_key if not said.has(s3_key) else ""
	return key if old_line else ""


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
		var s := XState.current
		if s != null and not XTianqi.active(s):
			var r := record(s)
			var count := int(r.get("crack", 0))
			if _investigations_on() and XConfig.whisper_seen("rift3") and count >= 2 and not bool(r.get("s3_crack", false)):
				text = STAGE3_CRACK_TEXT
				r["s3_crack"] = true
			else:
				text = CRACK_TEXTS[mini(count, 1)]
				r["crack"] = count + 1
		elif s != null:
			var key := s.get_instance_id()
			if _tq_crack_session.size() > 16:
				for k in _tq_crack_session.keys():
					if not is_instance_id_valid(k):
						_tq_crack_session.erase(k)
			var n := int(_tq_crack_session.get(key, 0))
			text = CRACK_TEXTS[mini(n, 1)]
			_tq_crack_session[key] = n + 1
		else:
			text = CRACK_TEXTS[0]
	elif cell == FIXED_FLOAT and floats.has(FIXED_FLOAT):
		text = FLOAT_TEXT
	elif _scale_cell.x >= 0 and cell == _scale_cell:
		text = SCALE_TEXT
	elif _investigations_on():
		if cell == STAGE3_INVEST_CELL:
			text = STAGE3_WALL_TEXT
		elif cell == FIXED_FLOAT_S3 and floats.has(FIXED_FLOAT_S3):
			text = STAGE3_FLOAT_TEXT
	if text == "":
		return false
	await host.run_command_list(text_list("", 0, "", text))
	return true


func is_investigation(cell: Vector2i) -> bool:
	return cell == CRACK_CELL or (cell == FIXED_FLOAT and floats.has(FIXED_FLOAT)) or (_scale_cell.x >= 0 and cell == _scale_cell) \
		or (_investigations_on() and (cell == STAGE3_INVEST_CELL or (cell == FIXED_FLOAT_S3 and floats.has(FIXED_FLOAT_S3))))


func _investigations_on() -> bool:
	return _s3_investigations and stage3_active()
