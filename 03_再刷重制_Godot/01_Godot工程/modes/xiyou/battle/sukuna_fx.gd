class_name XSukunaFx
extends RefCounted
## 宿傩特效包（Kyo 2026-11-13 审过，content/sukuna/art_optional/，Codex 的 Sukuna_Art_Godot.zip）的游戏内接线：
## - 状态图标：伏魔御厨子 2636、裂伤 2637、魔虚罗·适应 2638、黑闪觉醒 2639、看破·一～三 2640～2642 换成 32×32 新图标。
##   开表时（XDB.table("States")）把这几条的 iconIndex 改成 ICON_BASE＋序号，XUI.icon_texture 分流到 icon_texture。
##   看破三层共用一张，层数照旧看状态名。
## - 伏魔御厨子展开：宿傩放 10231 的行动开演时，在画面中央放一次展开动画（15 帧），放完铺持续领域背景（battle_scene）。
## - 领域背景：展开动画放完起铺满战斗画面，我方宿傩都没有领域了就淡出。
## - 神灶：开：XSukuna.open 的「发动了神灶：开！」那行带 sukuna_fx＝"flame"，播到这行时在敌群中间放一次（火矢朝左，翻转）。
## 两段动画都跟设置「战斗动画速度」（battleAniSpeed：每张停 1～4 帧，4＝原速 15 FPS），「显示技能动画」关着时不放动画、背景照铺。
## 回退：FX = false（图标、动画、背景都不用，照原样）。
static var FX := true

const DIR := "res://content/sukuna/art_optional/"
const FLAME := DIR + "sukuna_divine_flame_frames.tres"
const SHRINE := DIR + "sukuna_malevolent_shrine_frames.tres"
const SHRINE_BG := DIR + "sukuna_malevolent_shrine_background.png"
const FRAMES := 15  # 两段动画都是 15 帧单次
const ICON_BASE := 330000
## 序号 → 图名；状态号 → 序号
const ICON_FILES := {1: "domain", 2: "wound", 3: "adaptation", 4: "awake", 5: "read"}
const STATE_ICONS := {2636: 1, 2637: 2, 2638: 3, 2639: 4, 2640: 5, 2641: 5, 2642: 5}
const FLAME_SCALE := 2.0
const SHRINE_SCALE := 3.0
## 神灶：开 起爆点在帧内中心偏右（约 +38 像素，192 宽），翻转后在中心偏左；放的位置往右挪回来，让起爆落在敌群中间
const FLAME_BURST_X := 38.0
static var _icons := {}


static func patch_states(t: Array) -> void:
	if not FX:
		return
	for id in STATE_ICONS:
		if id < t.size() and t[id] is Dictionary:
			t[id].iconIndex = ICON_BASE + int(STATE_ICONS[id])


static func is_icon(index: int) -> bool:
	return ICON_FILES.has(index - ICON_BASE)


static func icon_texture(index: int) -> AtlasTexture:
	if _icons.has(index):
		return _icons[index]
	var p := DIR + "sukuna_state_%s.png" % str(ICON_FILES.get(index - ICON_BASE, ""))
	if not ResourceLoader.exists(p):
		return null
	var tex: Texture2D = load(p)
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(Vector2.ZERO, tex.get_size())
	_icons[index] = a
	return a


## 这次行动要不要放伏魔御厨子展开（宿傩放 10231）
static func shrine_action(l: Dictionary) -> bool:
	return FX and l.get("user") is XActor and XSukuna.own(l.user) and int((l.get("skill", {}) as Dictionary).get("id", 0)) == 10231


## 战斗中我方有宿傩的领域开着
static func domain_active(logic) -> bool:
	if not FX or logic == null:
		return false
	for a in logic.actors:
		if XSukuna.own(a) and XSukuna.active_domain(a):
			return true
	return false


## 放一段动画（kind："flame"／"shrine"）到 parent 的 at 处；每张停 hold 帧（物理帧，60 FPS）。返回节点（放完自己删），素材缺时 null
static func play(parent: Node, kind: String, at: Vector2, hold: int) -> AnimatedSprite2D:
	var path := FLAME if kind == "flame" else SHRINE
	if not FX or not ResourceLoader.exists(path):
		return null
	var s := AnimatedSprite2D.new()
	s.sprite_frames = load(path)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if kind == "flame":
		s.flip_h = true  # 火矢朝右画的，宿傩在右、敌人在左
		s.scale = Vector2.ONE * FLAME_SCALE
		s.position = at + Vector2(FLAME_BURST_X * FLAME_SCALE, 0)
	else:
		s.scale = Vector2.ONE * SHRINE_SCALE
		s.position = at
	s.speed_scale = 4.0 / float(clampi(hold, 1, 4))  # 原速 15 FPS＝每张 4 帧
	parent.add_child(s)
	s.play("cast")
	s.animation_finished.connect(s.queue_free)
	return s


## 放完要等几个物理帧
static func wait_frames(hold: int) -> int:
	return FRAMES * clampi(hold, 1, 4)
