class_name XBattleTransition
extends RefCounted
## 进出战斗的转场（battlefx1）。原版 Scene_Map.stop → launchBattle：停地图 BGM／BGS、放系统音效 7（Battle1）、
## startEncounterEffect（YEP_CoreEngine「Show Events Transition」开：不藏角色），之后 60 帧遇敌演出（updateEncounterEffect）：
##   第 n 帧镜头以玩家（screenX, screenY − 24）为中心缩放 q＝((p−1)·20·p＋5)·p＋1（p＝n／60，先拉近到约 1.37、第 30 帧回到 1、再冲到 6）；
##   第 2 帧截战斗背景、第 30 帧放战斗 BGM 并 startFadeOut(24)。闪白两次被 MOG_BattleTransitions「遇敌闪烁 false」关掉，
##   它的转场图案默认 -1（不用），所以就是 MV 默认演出。
## Scene_Battle.start → startFadeIn(24)，淡完才开始战斗流程；Scene_Battle.stop → startFadeOut(24)（下一场景是标题或全灭画面时 48）。
## 回到地图：Scene_Map.start 照样 startFadeIn(24)，但 Codex_MapSceneRecovery 在第 2 帧把黑幕清掉，所以只暗一帧（244）就亮。
## 逐帧读数：tests/fixtures/battle_transition_oracle.json（03_转换工具/ui_reference/battle_transition_ref.cjs）。
## 重制原来没有这一层：进战斗直接切画面、没有开战音效。
## 回退开关：ENABLED = false 回到原来（直接切、不放 Battle1）。O-197
static var ENABLED := true
## 无画面（headless 测试）时不走转场：地图快照本来就是空的，每场多 100 多帧会拖慢几十场战斗的楼层测试。
## 专项 xiyou_battle_transition 打开它在无画面下核逐帧读数。
static var IN_HEADLESS := false

const ENCOUNTER_FRAMES := 60   # Scene_Map.encounterEffectSpeed
const BGM_FRAME := 30          # floor(speed / 2)：放战斗 BGM、开始淡出
const FADE_FRAMES := 24        # Scene_Base.fadeSpeed
const SLOW_FADE_FRAMES := 48   # Scene_Base.slowFadeSpeed（Scene_Battle.needsSlowFadeOut：去全灭画面）
const ZOOM_LIFT := 24.0        # zoomY＝$gamePlayer.screenY() − 24
const BACK_DARK := 244.375     # 回地图第一帧的黑幕（startFadeIn(24) 走了一帧），第二帧被 Codex_MapSceneRecovery 清成 0


## 测试用逐帧记录：非 null 时各段每帧追加一条（地图遇敌演出、战斗淡入、战斗淡出、回地图）
static var trace = null


static func note(row: Dictionary) -> void:
	if trace is Array:
		trace.append(row)


static func enabled() -> bool:
	return ENABLED and (IN_HEADLESS or DisplayServer.get_name() != "headless")


## Scene_Map.updateEncounterEffect 第 n 帧（1～60）的镜头缩放
static func zoom_at(n: int) -> float:
	var p := float(n) / ENCOUNTER_FRAMES
	return ((p - 1.0) * 20.0 * p + 5.0) * p + 1.0


## Spriteset_Base.updatePosition：以画面点 at 为中心缩放 q 时，地图层的画面偏移（x、y 各自取整）
static func zoom_shift(at: Vector2, q: float) -> Vector2:
	return Vector2(floorf(-at.x * (q - 1.0) + 0.5), floorf(-at.y * (q - 1.0) + 0.5))  # JS Math.round
