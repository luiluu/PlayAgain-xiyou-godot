class_name XBattleScene
extends Control
## 侧视战斗画面，照原版界面（用户 2026-10-12 要求「界面风格用原版界面风格」）：
## - 布局按 Olivia_SideBattleUI：我方站位 x = 宽/2+128+序号×64、y = 高-235-(5-序号-1)×48；
##   右侧每人一条状态（缩放 0.6：名字、HP/MP/TP 量条、左侧状态图标，轮到谁谁左移 48）；
##   指令窗（宽 220、缩放 0.8）出现在行动角色身旁，技能/物品列表（宽 450）在其右下；
##   选中技能/物品时在列表左侧显示 HelpExtend 说明卡（XHelpCard；原版没有顶部说明栏）。
## - 敌人在敌群编辑器坐标（原版 1280×720 原样使用），1 倍大小；神话偏色、画面上也是 1 倍（ELITE_SCALE，见下）；
##   YEP_X_VisualHpGauge：敌人脚下 12px 粗血条（受伤或选目标时显示，带数值）。
## - 伤害数字照 LGP_BetterDamagePopup 文字弹出（XDamagePopup）。
## - Olivia_BattleSysOTB：行动顺序回合制，轮到谁谁当场选指令；画面下方是行动顺序条（XOTBBar），
##   指令窗里有「逃跑」，没有队伍指令窗，取消不能回到上一人。
## 规则在 XBattleLogic；结束时发出 finished(0 胜利 / 1 逃跑 / 2 战败)。

signal finished(result: int)
## 逃跑成功、消息窗出来之前发（ESCAPE_MAP_AUDIO_EARLY）：地图收掉战斗曲、换回地图曲
signal escape_audio
signal _picked(value)

const BOX := Vector2(1280, 720)           # 原版画面尺寸（坐标基准）
## 神话敌人画面倍数。EliteEnemyPlugins（EliteEnemySize=true）在 updateBitmap→updateScale 里设 1.8 倍，但同一帧稍后
## YEP_X_AnimatedSVEnemies 的 Sprite_Enemy.update 末尾无条件调 updateBreathing，把 scale 改回 spriteScaleX()＋呼吸量
## （本源敌人没有 <Sprite Scale> 备注，即 1），画到屏幕上的神话敌人仍是 1 倍。重制原先照 updateScale 画 1.8 倍，
## 玩家反馈 v0.01「怪物太大了」。回退：ELITE_SCALE = 1.8。
static var ELITE_SCALE := 1.0
const STATUS_SCALE := 0.6
const STATUS_W := 200.0
const STATUS_MOVE := 48.0
const CMD_W := 220.0
const CMD_SCALE := 0.8
const CMD_FADE_FRAMES := 16.0       # Olivia_SideBattleUI updateFadeOut：每帧 −16，255 → 0
const LIST_W := 450.0
const LIST_MAX := 16
const ENEMY_GAUGE_W := 180.0
const OTB_POS := Vector2(58, 618)
const LOG_Y := 92.0                # OTB Log Window Y
const STATES_MAX := 4
## Codex_MiraRavenMultiFrame：旧式侧视角色（ID < 167）战斗中身体缩放 0.75、最近邻
const ACTOR_SCALE := 0.75

var logic := XBattleLogic.new()
var map_data: Dictionary
## 地图快照（MV Scene_Map.snapForBattleBackground；YEP_MainMenuManager 关闭模糊）
var snapshot: Texture2D
var troop_id := 0
var can_lose := false
var sprites := {}                 # XBattler -> XBattlerSprite
var gauges := {}                  # XEnemy -> {box, timer}
var status_rows := {}             # XActor -> XSideStatus
var field: Node2D
var fx: Node2D
## 渡鸦特效层（XRavenFx，战场里），第一次放时才建
var raven_fx: XRavenFx
var _raven_action_serial := 0
var _raven_cast_key := []
## 这次行动里同技能的命中记录（施放特效画一组用）
var _raven_hits: Array = []
var combo: XComboCounter
var record: XDamageRecord
var ui: Control
## 战斗中的消息窗（BattleManager 的逃跑信息等走 $gameMessage，Scene_Battle 的 Window_Message）
var message: XMessageBox
var help_card: XHelpCard
var boss_panel: XBossStatusPanel
var boss_hp: XBossHpBar
var log_canvas: XMVCanvas
var _log_lines: Array = []        # [{text, simple}]
var otb: XOTBBar
## 正在等玩家选指令（_command 里 await _command_for 期间）；状态详情只在这时能打开
var inputting := false
var status_panel: XPartyStatusPanel
var cmd_win: XBattleList
var list_win: XBattleList
## 异化百相切换仿形的选择窗（开着时）
var mimic_win: XAlienMimicWindow
## 云裳的选择窗（赠行选人、裁身、七曜元素、收针选人、换锦选状态）
var yun_win: XYunChoicesWindow
## 谷雨赠春／还春选择窗（开着时）
var transfer_win: XGuyuTransferWindow
## 自动／变速两个按钮的容器（O-006 重制新增）。不放 ui：放在画面层与 screen_fx 之间，事件淡出（221）的黑幕盖住它，
## 跟原版画面上的东西一样（ui-zorder1）；不随镜头，胜利时同窗口一起藏。
var low_ui: Control
var auto_btn: Button
var speed_btn: Button
var bgm: AudioStreamPlayer
var se: AudioStreamPlayer
## 战斗 ME（BattleManager.playVictoryMe／playDefeatMe → AudioManager.playMe）。战斗结束时还没放完的由地图接过去接着放
## （原版 ME 不随场景切换停，见 XMapScene.take_battle_me）
var me: AudioStreamPlayer
## ME 放完（AudioManager.stopMe）要不要把 bgm 接着放／从头放、0.5 秒淡入。全灭时原版 stopBgm（不可败）或换回地图曲（可败，
## 由地图接），战斗曲都不再响，所以是 false
var _bgm_after_me := false
var _target_mode := ""            # "enemy" / "ally" / ""
var _target_pool: Array = []
var _target_skill: Dictionary = {}
var _hover = null
## O-112：这次选目标要一起亮的整组（全体／随机范围）；空＝只亮光标那只（原版）
var _target_group: Array = []
## 妖族群攻手选猎物：光标那只标成猎物
var _target_prey := false
var _active: XActor = null
var _origin := Vector2.ZERO       # 原版坐标 → 画面坐标的偏移
var _camera := {}                 # 胜利镜头（见 _victory）
## YEP_X_ActSeqPack3 战斗镜头（行动序列的 CAMERA/ZOOM）；_cam_base 是各画面层的原始位置
var camera := XBattleCamera.new()
var _cam_base := {}
var _cam_applied := false
## 正在演出的行动序列（它自己逐帧推进镜头）
var seq_player: XSequencePlayer
## 开战转场（XBattleTransition，battlefx1）：地图在转场开着时设 fade_in，开战 24 帧黑幕淡入；
## prestarted_bgm 是地图在遇敌演出第 30 帧放起的战斗 BGM（节点归地图，战斗结束由地图收掉）
var fade_in := false
var prestarted_bgm: AudioStreamPlayer = null
var _fade: XSceneFade
## 事件指令 221／222 淡出淡入、224 闪烁画面的画面层（XBattleScreen，rules-gaps11）
var screen_fx: XBattleScreen
## 自动测试用：强制自动战斗，胜利界面自动关闭。
static var force_auto := false
## O-待定-1：设置「进战斗默认自动」开着时，每场战斗开局自动按钮就是开（玩家反馈：想让自动一直开着，不用每场点）。
## 设置默认关＝照原来开局为关；回退＝设 false（设置页不列这一项，开局恒为关）。挂机另走 XHangUp，不受影响。
static var AUTO_DEFAULT := true
## 怪物图鉴（AB_EnemyBook ResisterTiming 2）本场出现过的敌人 ID：战斗结束时登记
var book_appeared: Array = []
## 战斗内「怪物信息」（AB_EnemyBook，Shift 打开；见 _open_battle_book）
var book_page: XEnemyBookPage


func setup(troop: int, escape: bool, lose: bool, map: Dictionary, background: Texture2D = null, random_encounter := false) -> void:
	troop_id = troop
	snapshot = background
	can_lose = lose
	map_data = map
	logic.can_escape = escape
	logic.setup(troop, XState.current)
	if random_encounter:
		logic.roll_encounter()  # Game_Player.executeEncounter：BattleManager.setup 之后 onEncounter 掷先制／偷袭
	XPetCapture.roll_battle(logic)  # Star_PetSystem 的 Scene_Battle.start 包装：掷可捕捉（名字加「宝宝」）
	logic.auto = force_auto or start_auto()
	book_appeared = XEnemyBook.on_battle_start(XState.current, troop, map, logic.enemies)


## 开局自动按钮的状态（O-待定-1）：开关开着且设置「进战斗默认自动」为 ON
static func start_auto() -> bool:
	return AUTO_DEFAULT and XConfig.flag("codexBattleAutoDefault")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vs := get_viewport_rect().size
	_origin = Vector2((vs.x - BOX.x) / 2.0, (vs.y - BOX.y) / 2.0)
	_build_background()
	_build_sukuna_domain()
	field = Node2D.new()
	field.position = _origin
	add_child(field)
	fx = Node2D.new()
	fx.position = _origin
	add_child(fx)
	# MOG_ComboCounter：在战斗者与伤害数字之上、窗口之下
	combo = XComboCounter.new()
	combo.position = _origin
	add_child(combo)
	# $gameScreen 的闪烁与淡出淡入（Spriteset_Base 的 _flashSprite／_fadeSprite，rules-gaps11）：在战斗画面之上、伤害记录与窗口之下，不随镜头动
	screen_fx = XBattleScreen.new()
	add_child(screen_fx)
	# 设置「战斗伤害记录」：开战时开着才建（Star_CombatDamageRecord），在战斗画面之上、窗口之下，不随胜利镜头缩放
	if XConfig.flag("CombatDamageRecordKey"):
		record = XDamageRecord.new()
		var members := logic.actors.size()
		record.setup(XState.current.battle_slots if XState.current else [], members)
		record.position += _origin
		add_child(record)
	_place_battlers()
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	_build_ui(vs)
	message = XMessageBox.new()
	message.position = _origin
	# 原版窗口层里 Window_Message 排在 Window_OTBDisplay 之后：消息窗底色压在行动顺序条上、头像盖住条的左端（八戒_45 截图对照）。
	# 行动顺序条是 z 8（要在敌人血条 z 5 之上），消息窗同 z、树序在后
	message.z_index = 8
	ui.add_child(message)
	camera.sprites = sprites
	for visual in get_children():
		if visual != ui and visual != low_ui and visual != record and visual != screen_fx and (visual is Control or visual is Node2D):
			_cam_base[visual] = visual.position
	se = AudioStreamPlayer.new()
	XAudio.bind(se, "SE")
	add_child(se)
	me = AudioStreamPlayer.new()
	XAudio.bind(me, "ME")
	add_child(me)
	me.finished.connect(_me_finished)
	if prestarted_bgm != null:
		bgm = prestarted_bgm   # 开战转场第 30 帧已由地图放起（Scene_Map.updateEncounterEffect → BattleManager.playBattleBgm），接着放
	else:
		bgm = new_bgm_player(battle_music())
		add_child(bgm)
		if bgm.stream != null:
			bgm.play()
	# Scene_Battle.start → startFadeIn(fadeSpeed)：黑幕盖在所有东西（含窗口）之上，淡入期间战斗流程等着（isBusy）
	if fade_in:
		_fade = XSceneFade.new()
		_fade.z_index = 100
		add_child(_fade)
		_fade.start_in(XBattleTransition.FADE_FRAMES)
	_main.call_deferred()


## BattleManager.playBattleBgm 放的 $gameSystem.battleBgm()（指令 132 深渊封印战斗前后换歌时用换的）
static func battle_music() -> Dictionary:
	var music: Dictionary = XDB.system().battleBgm
	if XState.current and not XState.current.battle_bgm.is_empty():
		music = XState.current.battle_bgm
	return music


## 战斗 BGM 播放器（还没进树、没开始放；stream 为空表示没有这首）
## 敌群事件 241 播放 BGM（原版 AudioManager.playBgm）：换掉当前战斗曲；空名＝停（同 MV 的 name 为空即 stopBgm）。
## 正在放的就是同名曲（AudioManager.isCurrentBgm 只比名字）时不重放，只更新参数（updateBgmParameters，审查 59 P3-1）
func _change_bgm(music) -> void:
	if not (music is Dictionary):
		return
	var name := str(music.get("name", ""))
	if bgm != null and name != "" and bgm.playing and str(bgm.get_meta("bgm_name", "")) == name:
		XAudio.stop_fade(bgm)
		bgm.volume_db = bgm_volume_db(music)
		return
	if bgm != null:
		XAudio.stop_fade(bgm)
		bgm.stop()
		if bgm != prestarted_bgm:
			bgm.queue_free()
	bgm = new_bgm_player(music)
	add_child(bgm)
	# AudioManager.playBgm：ME 在放（!this._meBuffer 不成立）只换上、不开始，ME 放完 stopMe 再放
	if bgm.stream != null:
		if me != null and me.playing:
			_bgm_after_me = true
		else:
			bgm.play()


## 战斗收场 replayBgmAndBgs 换回地图曲：战斗曲／胜利曲停掉（地图 start_battle 调）。ME 不在这里停，由地图接过去
func stop_bgm() -> void:
	_bgm_after_me = false
	if bgm != null and is_instance_valid(bgm):
		XAudio.stop_fade(bgm)
		bgm.stop()
		bgm.stream_paused = false


static func new_bgm_player(music: Dictionary) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	XAudio.bind(player, "BGM")
	var p := XDB.audio_path("bgm", str(music.get("name", "")))
	if p != "":
		player.stream = XAppearance.kept_load(p)
		player.volume_db = bgm_volume_db(music)
		player.set_meta("bgm_name", str(music.get("name", "")))
	return player


static func bgm_volume_db(music: Dictionary) -> float:
	return linear_to_db(float(music.get("volume", 90)) / 100.0)


## AudioManager.playMe：先停上一首 ME；有这首就把 BGM 停在原位置（_currentBgm.pos，这里用暂停）、放 ME。
## 放完由 _me_finished（stopMe）把 BGM 接上。没有这首（名字空或缺文件）什么都不动，BGM 照放
func play_me(audio) -> void:
	if me == null:
		return
	me.stop()
	var path := XDB.audio_path("me", str(audio.get("name", ""))) if audio is Dictionary else ""
	if path == "":
		return
	# 停掉的 BGM（stopBgm 清了 _bgmBuffer）ME 放完也不会响；在放的才记位置、放完接上
	_bgm_after_me = bgm != null and (bgm.playing or bgm.stream_paused)
	if _bgm_after_me:
		bgm.stream_paused = true
	me.stream = load(path)
	me.volume_db = linear_to_db(float(audio.get("volume", 90)) / 100.0)
	me.pitch_scale = float(audio.get("pitch", 100)) / 100.0
	me.play()


## AudioManager.stopMe（ME 播完的 stopListener）：BGM 没在放就从记下的位置接着放（暂停的接着放；ME 期间换上、还没开始的
## 从头放），_replayFadeTime 0.5 秒淡入
func _me_finished() -> void:
	if not _bgm_after_me or bgm == null or not is_instance_valid(bgm) or bgm.stream == null:
		return
	if bgm.stream_paused:
		bgm.stream_paused = false
	elif not bgm.playing:
		bgm.play()
	else:
		return
	XAudio.fade_in(bgm)


# ---- 布局 ----
## MV Spriteset_Battle：地图指定了战斗背景才用战斗背景图（YEP_ImprovedBattlebacks 缩放铺满）；
## 否则（世界图块以外）背景图为空，露出进入战斗前的地图快照。
func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var names := ["", ""]
	if bool(map_data.get("specifyBattleback", false)):
		names = [str(map_data.get("battleback1Name", "")), str(map_data.get("battleback2Name", ""))]
	elif snapshot == null:
		# 没有快照（无画面测试）时用系统默认战斗背景
		names = [str(XDB.system().battleback1Name), str(XDB.system().battleback2Name)]
	if snapshot and names == ["", ""]:
		var t := TextureRect.new()
		t.texture = snapshot
		t.position = _origin
		t.size = BOX
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(t)
		return
	for i in range(2):
		var p := XDB.img_path("battlebacks%d" % (i + 1), names[i]) if names[i] != "" else ""
		if p == "":
			continue
		var t := TextureRect.new()
		t.texture = XAppearance.kept_load(p)
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(t)


## 宿傩伏魔御厨子（XSukunaFx）：展开动画放完起铺领域背景，我方宿傩都没有领域了就淡出
var _sukuna_domain: TextureRect = null
var _sukuna_domain_on := false


func _build_sukuna_domain() -> void:
	if not XSukunaFx.FX or not ResourceLoader.exists(XSukunaFx.SHRINE_BG):
		return
	_sukuna_domain = TextureRect.new()
	_sukuna_domain.texture = load(XSukunaFx.SHRINE_BG)
	_sukuna_domain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sukuna_domain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sukuna_domain.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_sukuna_domain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sukuna_domain.modulate.a = 0.0
	_sukuna_domain.visible = false
	add_child(_sukuna_domain)


func _tick_sukuna_domain(delta: float) -> void:
	if _sukuna_domain == null:
		return
	if _sukuna_domain_on and not XSukunaFx.domain_active(logic):
		_sukuna_domain_on = false
	var target := 1.0 if _sukuna_domain_on else 0.0
	_sukuna_domain.modulate.a = move_toward(_sukuna_domain.modulate.a, target, delta * 2.0)
	_sukuna_domain.visible = _sukuna_domain.modulate.a > 0.0


## 宿傩特效：伏魔御厨子展开（画面中央，放完铺领域背景）、神灶：开（敌群中间）。「显示技能动画」关着时只铺背景
func _sukuna_fx(kind: String) -> void:
	if XConfig.flag("CombatSkillAnimation"):
		var at := BOX / 2.0 - Vector2(0, 40)
		if kind == "flame":
			var foes := logic.enemies.filter(func(e): return sprites.has(e) and e.is_alive())
			if not foes.is_empty():
				at = Vector2.ZERO
				for e in foes:
					at += sprites[e].position - Vector2(0, sprites[e].height() / 2.0)
				at /= foes.size()
		var hold := XConfig.battle_speed()
		if XSukunaFx.play(fx, kind, at, hold) != null:
			await _wait_frames(XSukunaFx.wait_frames(hold))
	if kind == "shrine":
		_sukuna_domain_on = true


## Codex_MiraRavenMultiFrame partyLayout：中线 x = 宽×0.64；1～4 人竖排一列（上 max(高+36, 高×0.32)、下 高×0.73，
## 1 人在 高×0.525）；5 人前后两列交错（x ∓ 50，上 max(高+36, 高×0.30)、下 高×0.75）。
## 角色图高按 72 计（旧式 64×64 侧视图缩放 0.75 后不超过 72）。
static func party_layout(n: int, sprite_h := 72.0, sprite_w := 72.0) -> Array:
	var pts := []
	var cx := roundf(BOX.x * 0.64)
	if n == 5:
		var dx := roundf(maxf(100.0, minf(BOX.x * 0.105, sprite_w + 24.0)) / 2.0)
		var top5 := maxf(sprite_h + 36.0, BOX.y * 0.30)
		var step5 := (BOX.y * 0.75 - top5) / 4.0
		for k in range(5):
			pts.append(Vector2(cx + (dx if k % 2 == 1 else -dx), roundf(top5 + k * step5)))
	else:
		var top := maxf(sprite_h + 36.0, BOX.y * 0.32)
		var step := (BOX.y * 0.73 - top) / (n - 1) if n > 1 else 0.0
		for j in range(n):
			pts.append(Vector2(cx, roundf(BOX.y * 0.525) if n == 1 else roundf(top + j * step)))
	return pts


func _place_battlers() -> void:
	for e in logic.enemies:
		_make_enemy_sprite(e)
		_make_enemy_gauge(e)
		_set_enemy_shown(e)
	var points := party_layout(logic.actors.size())
	for i in range(logic.actors.size()):
		var a: XActor = logic.actors[i]
		var s := XBattlerSprite.new()
		field.add_child(s)
		s.setup(a, ACTOR_SCALE)
		s.home = points[i]
		s.position = s.home + Vector2(300, 0)
		sprites[a] = s



## YEP_X_VisualHpGauge：宽 max(180, 图宽)、高 12，底色 19、渐变 20→21，显示当前 HP 数值。
func _make_enemy_sprite(e: XEnemy) -> void:
	var s := XBattlerSprite.new()
	field.add_child(s)
	s.setup(e, ELITE_SCALE if e.elite else 1.0)
	var br := XSvEnemy.breathing(e)  # 呼吸只给该给的敌人：非 SV 默认呼吸，SV 默认不呼吸；周期读备注（见 XSvEnemy）
	s.breathing = br.on
	s.breath_speed = br.speed
	s.breath_rx = br.rx
	s.breath_ry = br.ry
	# YEP_CoreEngine Reposition Battlers：侧视时敌人 y 加 (画面高 − 624) / 2
	s.home = Vector2(float(e.get_meta("x")), float(e.get_meta("y")) + floorf((BOX.y - 624.0) / 2.0))
	s.position = s.home
	s.appeared = e.is_alive()  # Sprite_Enemy.initVisibility
	sprites[e] = s


## 隐藏成员（没出现）不画本体与血条（Sprite_Enemy.updateVisibility）
func _set_enemy_shown(e: XEnemy) -> void:
	sprites[e].visible = not e.hidden
	if gauges.has(e):
		gauges[e].box.visible = not e.hidden


func _make_enemy_gauge(e: XEnemy) -> void:
	var c := XMVCanvas.new()
	c.size = Vector2(640, 100)
	c.clip_contents = false
	c.z_index = 5
	field.add_child(c)
	gauges[e] = {"box": c, "timer": 0.0, "name_timer": 3.0, "cur": e.hp, "disp": e.hp, "drop": 0.0, "icons": {}, "name_alpha": 255.0}
	c.painter = func(canvas): _paint_enemy(canvas, e)


## Window_WeaknessDisplay.updateOpacity（ui12）：隐藏或死了每帧 −16；选中或还在 Weakness Hide Duration（180 帧＝name_timer 3 秒）内直接 255；
## 否则每帧 −16 淡出（原来重制是到点直接消失）。名字与名字旁的状态图标共用这个不透明度。NAME_FADE = false 回到直接消失。
static var NAME_FADE := true


static func name_alpha_step(a: float, gone: bool, showing: bool, frames: float) -> float:
	if not gone and showing:
		return 255.0
	return maxf(0.0, a - 16.0 * frames)


## Olivia WeaknessDisplay 名字与 YEP VisualHpGauge 是两个独立窗口。
## 名字居中在 (敌人 x, y−27) 的 640×72 内容位图；HP 内容 (x−90,y−16)，字号 26、居中、12px 粗条。
func _paint_enemy(c: XMVCanvas, e: XEnemy) -> void:
	var g: Dictionary = gauges[e]
	var v := view_lite(e)
	var rate: float = v.hp / maxf(v.mhp, 1.0)
	var name_alpha: float = g.name_alpha / 255.0 if NAME_FADE else (1.0 if not v.dead and (g.name_timer > 0.0 or e == _hover) else 0.0)
	if name_alpha > 0.0:
		var color := _enemy_name_color(e) if rate > 0.5 else XUI.text_color(2 if rate > 0.25 else 10)
		c.text(e.display_name(), 0, 0, 640, "center", color, 18, 36, name_alpha)
		XEnemyStateIcon.paint(c, g.icons, c.text_width(e.display_name(), XEnemyStateIcon.NAME_SIZE), name_alpha)  # 名字右边的状态图标（ui12）
	if not XBossHpBar.small_gauge_visible(e):  # YEP_X_VisualHpGauge：<HIDE HP GAUGE> 的敌人血条一直不出现（选中也不出）
		return
	if g.timer <= 0.0 and g.disp == g.cur and not (_target_mode == "enemy" and e == _hover):
		return
	var w := maxf(ENEMY_GAUGE_W, sprites[e].width())
	var x := 320.0 - w / 2.0
	var y := 11.0
	var gy := y + 36 - 12 - 2
	c.draw_rect(Rect2(x, gy, w, 12), Color(XUI.text_color(19), 160.0 / 255.0))
	# 血条与数字都画显示值（drawActorHp 的 rate = _displayedValue / mhp）
	var fill := maxf(0, floorf(w * g.disp / maxf(v.mhp, 1.0)) - 4)
	if fill > 0:
		c.gradient(Rect2(x + 2, gy + 2, fill, 8), XUI.text_color(20), XUI.text_color(21))
	c.text(XMenu._group(g.disp), x, y, w, "center", XUI.TEXT, 26, 36)


## EnemyNameColorByDifficulty 只为与数据库原名完全相同的文字上色。
func _enemy_name_color(e: XEnemy) -> Color:
	return XEnemy.name_color(e.display_name(), e.difficulty_id)


# ---- 画面读数 ----
## 演出中显示的战斗者读数：日志里记下的结算后值（XBattleLogic.view_of）。整次行动先结算完才演出，
## 实时状态已是最终值，多段攻击若读实时值第一下就显示最后的血量。不在演出中（或日志没有记）时读实时状态。
var shown := {}            # XBattler -> view

func view(b: XBattler) -> Dictionary:
	return shown[b] if shown.has(b) else logic.view_of(b)


## 只要血量、上限、倒没倒的读数（敌人血条、名字淡入淡出、Boss 血条，每帧都读）。不在演出中时直接读实时状态，
## 不再每帧整份算 view_of（状态格排序、能否行动、指示器……）：敌人身上状态多时（玩家反馈 v0.01.07 敌方异常 22 层）一次要
## 1 毫秒以上，每帧四五次，行动之间整个画面变卡。三项与 view_of 里的取法相同（b.hp、b.mhp、b.is_dead()）。
## 回退：VIEW_LITE = false 回到每次整份 view_of（O-待定）。
static var VIEW_LITE := true


func view_lite(b: XBattler) -> Dictionary:
	if shown.has(b) or not VIEW_LITE:
		return view(b)
	return {"hp": b.hp, "mhp": b.mhp, "dead": b.is_dead()}


func show_views(v: Dictionary) -> void:
	for b in v:
		shown[b] = v[b]
		if status_rows.has(b):
			status_rows[b].view = v[b]
			status_rows[b].refresh()
		if sprites.has(b):
			sprites[b].view = v[b]
		if gauges.has(b):
			_refresh_enemy_gauge(b)


func clear_views() -> void:
	shown.clear()
	for row in status_rows.values():
		row.view = {}
	for sp in sprites.values():
		sp.view = {}
	for e in gauges:
		_refresh_enemy_gauge(e)


func _refresh_enemy_gauge(e: XEnemy) -> void:
	gauges[e].box.queue_redraw()


func _show_enemy_gauge(e: XBattler, seconds := 0.5) -> void:
	if not gauges.has(e):
		return
	_refresh_enemy_gauge(e)
	gauges[e].timer = seconds
	gauges[e].name_timer = 3.0


func _build_ui(vs: Vector2) -> void:
	# Boss 血条（MOG_BossHP）：最先加，窗口在它上面（原版 hudField 在窗口层下）
	boss_hp = XBossHpBar.new()
	boss_hp.hp_source = func(e): return view_lite(e)
	boss_hp.busy_source = func(): return message._busy
	var hp_holder := Node2D.new()
	hp_holder.position = _origin
	ui.add_child(hp_holder)
	hp_holder.add_child(boss_hp)
	boss_hp.setup(logic.enemies)
	# 战斗日志 Window_BattleLog (0,92,1280,388)：每行底下一条黑色 64/255 的带子（x 0、宽 1280、行高 36），
	# <SIMPLE> 行（YEP 行动名：图标＋名字）居中，其余靠左。
	log_canvas = XMVCanvas.new()
	log_canvas.position = _origin + Vector2(0, LOG_Y)
	log_canvas.size = Vector2(1280, 388)
	log_canvas.clip_contents = false
	log_canvas.painter = _paint_log
	ui.add_child(log_canvas)
	# 右侧状态（XSideStatus，按正式版队伍顺序）
	var holder := Control.new()
	holder.position = _origin
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(holder)
	for i in range(logic.actors.size()):
		var row := XSideStatus.new()
		row.setup(logic.actors[i], i)
		holder.add_child(row)
		status_rows[logic.actors[i]] = row
		row.cell_pressed.connect(_open_status)
	_refresh_status()
	# 自动/加速：左上角小窗，避免挡住 OTB（优化 O-006）；让出左上 (20,10,240,74) 给挂机快捷界面。
	# 层次（ui-zorder1）：在 screen_fx 之下（221 淡出的黑幕盖住按钮；原版没有这两个按钮，画面上只剩窗口），
	# 开战淡入黑幕（_fade，z 100）本来就盖住全部
	low_ui = Control.new()
	low_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	low_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(low_ui)
	move_child(low_ui, screen_fx.get_index())
	var side := HBoxContainer.new()
	side.position = _origin + Vector2(272, 12)
	side.add_theme_constant_override("separation", 8)
	low_ui.add_child(side)
	auto_btn = _small_button("自动：关")
	auto_btn.pressed.connect(func():
		logic.auto = not logic.auto
		_refresh_auto()
		if logic.auto:
			_picked.emit("auto"))
	side.add_child(auto_btn)
	speed_btn = _small_button("变速 " + XConfig.battle_speed_text())
	speed_btn.pressed.connect(func():
		XConfig.set_battle_speed(XConfig.battle_speed() % 4 + 1)
		XSound.system(0)
		speed_btn.text = "变速 " + XConfig.battle_speed_text())
	side.add_child(speed_btn)
	_refresh_auto()
	# 行动顺序条：宽 = 画面宽 - x - 状态宽 - 左移量 - 状态图标 4.5 个
	otb = XOTBBar.new()
	otb.position = _origin + OTB_POS
	ui.add_child(otb)
	otb.setup(BOX.x - OTB_POS.x - STATUS_W - STATUS_MOVE - 32 * (STATES_MAX + 0.5))
	# Boss 状态面板（Codex_BossStatusSummary）：只显示，不参与结算；最后加，盖在说明卡上
	boss_panel = XBossStatusPanel.new()
	boss_panel.position = _origin
	boss_panel.enemies_source = func(): return logic.enemies
	boss_panel.target_source = func(): return _hover if _target_mode == "enemy" else null
	boss_panel.help_source = _boss_panel_help_rect
	ui.add_child(boss_panel)


## 说明卡（选技能／物品时右侧的详情）显示时的矩形（减 _origin，原版坐标）；没显示为空
func _boss_panel_help_rect() -> Rect2:
	if help_card == null or not is_instance_valid(help_card) or not help_card.visible:
		return Rect2()
	if list_win == null or not is_instance_valid(list_win) or not list_win.visible:
		return Rect2()
	return Rect2(help_card.position - _origin, help_card.size)


func _small_button(text: String) -> Button:
	var b := XUI.button(text, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", XUI.panel())
	b.custom_minimum_size.x = 120
	# 只认鼠标：不拿键盘焦点。点过之后焦点留在按钮上，空格／J（ui_accept）会先按到它，选技能时又切一次倍速／自动（Kyo 11-06 实机）
	b.focus_mode = Control.FOCUS_NONE
	return b


func _refresh_auto() -> void:
	auto_btn.text = "自动：开" if logic.auto else "自动：关"


func _refresh_status(idle := true) -> void:
	for row in status_rows.values():
		row.refresh()
	if not idle:
		return
	for s in sprites.values():
		s.refresh_idle()


## 轮到输入指令的角色：状态条左移 48。正式版输入中角色不前进（运行时读数：输入中的角色仍在原位）。
func _set_active(a: XActor) -> void:
	_active = a
	for b in status_rows:
		status_rows[b].active = b == a


## HelpExtend：Window_BattleSkill/BattleItem.updateHelp 让说明卡跟着选中行（列表左侧，见 XHelpCard.place_for_row）。
func _help(entry = null) -> void:
	if help_card == null:
		help_card = XHelpCard.new()
		# 原版说明卡是场景直属精灵，在窗口层（含 OTB 行动顺序条，z 8）之上
		help_card.z_index = 10
		ui.add_child(help_card)
	if not (entry is Dictionary) or list_win == null or not is_instance_valid(list_win) or list_win.index < 0:
		help_card.visible = false
		return
	XHelpCard.scene_actor = _active  # 黑闪说明卡读 scene._skillWindow._actor
	# 心钢 Window_BattleSkill.updateHelp 包装：巨人吞噬换成 H.skillHelpView（带就绪／冷却状态行）
	help_card.show_for(XGrowthHelp.skill_view(entry, _active) if XHelpCard.kind_of(entry) == "skill" else entry)
	ui.move_child(help_card, -1)
	# 选中行：纵向取该行，横向取整个列表窗口（卡片外发光不压到窗口边框）
	var row := Rect2(list_win.position - _origin + Vector2(0, list_win.padding + (list_win.index - list_win.top) * XBattleList.LH),
		Vector2(list_win.size.x, XBattleList.LH))
	help_card.place_for_row(row, true)
	help_card.position += _origin


## Window_BattleLog.addText：在日志里再加一行（最多 10 行，多了挤掉最早的）
func _log_add(text: String) -> void:
	_log_lines.append({"text": text, "simple": false})
	if _log_lines.size() > 10:
		_log_lines.pop_front()
	log_canvas.queue_redraw()


## YEP displayAction 不清日志时（饿狼追击／反击直接 apply）：再加一行「<SIMPLE>\i[图标]名字」
func _log_add_action(skill: Dictionary) -> void:
	_log_lines.append({"text": "\\i[%d]%s" % [int(skill.get("iconIndex", 0)), str(skill.get("name", ""))], "simple": true})
	if _log_lines.size() > 10:
		_log_lines.pop_front()
	log_canvas.queue_redraw()


func _banner(text: String) -> void:
	_log_lines = [] if text == "" else [{"text": text, "simple": false}]
	log_canvas.queue_redraw()


## YEP_BattleEngineCore displayAction：日志一行「<SIMPLE>\i[图标]名字」居中
func _log_action(skill: Dictionary) -> void:
	_log_lines = [{"text": "\\i[%d]%s" % [int(skill.get("iconIndex", 0)), str(skill.get("name", ""))], "simple": true}]
	log_canvas.queue_redraw()


func _paint_log(c: XMVCanvas) -> void:
	for i in range(_log_lines.size()):
		var y := 14.0 + i * 36.0
		c.draw_rect(Rect2(0, y, 1280, 36), Color(0, 0, 0, 64.0 / 255.0))
		var t := XMVText.new(XMVText.convert_escapes(str(_log_lines[i].text)), 0, 0)
		var w := t.run()
		var x := 14.0 + ((1252.0 - w) / 2.0 if _log_lines[i].simple else 0.0)
		XMVText.paint(c, t.glyphs, x, y)


## 每帧推进胜利镜头（MV Game_Screen：zoomScale 与镜头点按剩余帧数线性逼近目标）。
## YEP_X_VisualHpGauge updateHpPosition：HP（画面读数）变了就按 Gauge Duration 定每帧滑动量 ceil(差/时长)，
## 显示值逐帧靠近，到达为止；滑动中血条保持显示。
func update_gauges() -> void:
	var dur := maxf(1.0, float(XDB.plugin("YEP_X_VisualHpGauge").get("Gauge Duration", "30")))
	for e in gauges:
		var g: Dictionary = gauges[e]
		var hp: float = view_lite(e).hp
		if hp != g.cur:
			g.cur = hp
			g.drop = ceilf(absf(g.disp - hp) / dur)
		if g.disp > g.cur:
			g.disp = maxf(g.disp - g.drop, g.cur)
		elif g.disp < g.cur:
			g.disp = minf(g.disp + g.drop, g.cur)


func _physics_process(_delta: float) -> void:
	if _fade != null and _fade.busy():
		_fade.step()
		XBattleTransition.note({"phase": "in", "fade": _fade.opacity})
	if screen_fx != null:
		screen_fx.step()   # Scene_Battle.update → $gameScreen.update（每帧，先于事件）
	_update_state_animations()
	if seq_player == null:
		flush_popups()       # 行动序列演出中由 XSequencePlayer 每帧在结算之后出
		update_gauges()      # 行动序列演出中由 XSequencePlayer 每帧在精灵之后更新
	if _camera.is_empty() and seq_player == null:
		camera.update()
		apply_camera()
	if _camera.is_empty() or _camera.t >= _camera.frames:
		return
	_camera.t += 1
	var k: float = float(_camera.t) / float(_camera.frames)
	var zoom: float = lerpf(1.0, float(_camera.scale), k)
	var cam: Vector2 = (_camera.from as Vector2).lerp(_camera.to, k)
	var screen := (BOX / 2.0 - cam * zoom).clamp(BOX - BOX * zoom, Vector2.ZERO).round()
	for visual in _camera.base:
		var b: Vector2 = _camera.base[visual]
		visual.scale = Vector2.ONE * zoom
		visual.position = _origin + screen + (b - _origin) * zoom


## Spriteset_Battle.updatePosition：场景层（背景、战斗者、动画、伤害数字）按镜头缩放与平移；窗口层不动。
func apply_camera() -> void:
	if not _camera.is_empty():
		return
	if not camera.active() and not _cam_applied:
		return
	var zoom := camera.scale
	var screen := camera.screen_offset()
	for visual in _cam_base:
		if not is_instance_valid(visual):
			continue
		var b: Vector2 = _cam_base[visual]
		visual.scale = Vector2.ONE * zoom
		visual.position = _origin + screen + (b - _origin) * zoom
	_cam_applied = camera.active()


func _process(delta: float) -> void:
	_tick_sukuna_domain(delta)
	for e in gauges:
		var g: Dictionary = gauges[e]
		g.box.position = sprites[e].position + Vector2(-320, -27)
		g.timer = maxf(0, g.timer - delta)
		g.name_timer = maxf(0, g.name_timer - delta)
		XEnemyStateIcon.tick(g.icons, e, delta * 60.0)  # Sprite_StateIcon 每帧计数（按 60 帧／秒折算）
		g.name_alpha = name_alpha_step(g.name_alpha, bool(view_lite(e).dead) or e.hidden, g.name_timer > 0.0 or e == _hover, delta * 60.0)
		g.box.queue_redraw()


# ---- 主循环（OTB）----
func _main() -> void:
	# YEP_BattleEngineCore Show Emerge Text = false：开战不显示「出现了」；
	# MV Sprite_Actor.startEntryMotion：从右侧 300px 处 30 帧线性走到原位（全员同时）；
	# 入场移动结束前不开始（Spriteset_Battle.isBusy）
	var entry_frames := XBattleTiming.move_frames(ENTRY_FRAMES)
	for f in range(1, entry_frames + 1):
		for a in logic.actors:
			var sp: XBattlerSprite = sprites[a]
			sp.position = sp.home + Vector2(300.0 * (entry_frames - f) / entry_frames, 0)
		await get_tree().physics_frame
	# 开战淡入没走完时战斗流程照原版等着（Scene_Battle.update：isBusy 时不 updateBattleProcess）；入场移动和淡入同时走
	while _fade != null and _fade.busy():
		await get_tree().physics_frame
	# BattleManager.displayStartMessages：先制「%1先发制人！」／偷袭「%1被偷袭了！」（YEP Show Pre-Emptive／Surprise Text 开；
	# 快速战斗的 XdRs_HangUp 包装跳过开场文字）。原版文字与入场移动同时进行，这里入场后再显示
	var start_text := XPreempt.start_text(logic)
	if start_text != "" and not XHangUp.fast_fighting(XState.current):
		await message.run({"lines": [start_text]})
	var first := true
	# 敌群事件：开战（第 0 回合）检查一次
	await _play_troop_events(logic.troop_events())
	while true:
		logic.start_turn()
		if PACE_GAPS:
			# Window_BattleLog.startTurn：push('wait')，等 messageSpeed 16（SSEP 每帧减 2＝8 帧）；下一帧 updateTurn 才取第一位，
			# 原版再过 2 帧行动序列才出第一条（角色 actionList 一帧＋DISPLAY ACTION 一帧，敌人 phaseChange 两帧）。
			# 重制 act 当帧就开序列，这 2 帧在重制里算在每次行动的尾巴上（行动之间两边总帧数一样）；回合交界的等待
			# 从「伤害数字飘完」算起，不经过上一次行动的尾巴，所以在这里补上
			await _pace_frames(int(16.0 / XSequencePlayer.LOG_WAIT_STEP) + 3)
		await _play(logic.take_turn_start_logs())
		if not first:
			otb.advance_turn()
		otb.show_orders(logic.current_order, logic.next_order, first)
		first = false
		# XdRs_HangUp 的 updateTurn：挂机逃跑条件成立就 processEscape（逃跑率 1）
		if XHangUp.should_escape(XState.current, logic.enemies):
			await _escape_success()
			return
		var turn_first := true
		while not logic.is_over():
			var u := logic.next_subject()
			# 每位行动之前（及最后一人之后）检查敌群事件；回合首位已在 OTB startTurn 取出
			await _play_troop_events(logic.troop_events(u if turn_first else null))
			turn_first = false
			if u == null or logic.is_over():
				break
			otb.on_subject(u)
			otb.show_orders(logic.current_order, logic.next_order)
			var cmd = [null, null] if logic.take_cleared(u) else await _command(u)
			if cmd is String and cmd == "escaped":
				return
			_close_windows()
			_set_active(null)
			var logs := logic.act(u, cmd[0], cmd[1])
			await _play(logs)
			if _tianqi_swap_out != null:
				await _tianqi_swap(_tianqi_swap_out)
			if PACE_GAPS:
				await _pace_frames(1)  # endAction 之后那一帧阶段是 turn，下一帧 updateTurn 才取下一位（逐次行动起点间隔与原版一样，见 battle_pace）
			if (logic.is_won() or logic.is_lost()) and XBattleCommonEvent.reserved(logic) > 0: await _play_troop_events(logic.troop_events())  # 打完最后一击，预约的公共事件照样跑（YEP checkBattleEnd）
			otb.clear_subject()
			otb.show_orders(logic.current_order, logic.next_order)
			_refresh_status()
		# 事件 340 中止战斗（BattleManager.checkAbort 在全灭、全歼之前）：逃跑音效、不出消息，结果 1，算逃跑（预约 1308）
		if logic.aborted and not logic.game_over:  # 340 之后又 353：原版切到结束画面，按全灭收场（下面）
			await _abort_battle()
			return
		# BattleManager.checkBattleEnd（rpg_managers.js 2614）先判 $gameParty.isAllDead 再判 $gameTroop.isAllDead：
		# 反伤、自爆同时打死最后一个敌人和最后一个我方时算输（审查第 75 期 P2-1，原来先判赢）
		if logic.is_lost():
			await _defeat()
			XEnemyBook.on_battle_end(XState.current, book_appeared, logic.enemies)
			logic.end_battle(2)
			# MV updateBattleEnd：允许失败时，只将阵亡出战成员复活到 1 HP。事件 353 游戏结束不看可不可输（原版直接 goto Scene_Gameover，
			# 不走 updateBattleEnd，不复活；地图那边见 XMapScene.last_battle_game_over，审查第 75 期 P3-1）
			if can_lose and not logic.game_over:
				for member in XState.current.battle_members():
					if member.is_dead():
						member.hp = 1.0
						member.refresh_resources()
			finished.emit(2)
			return
		if logic.is_won():
			otb.hide_bar()
			await _victory()
			reserve_battle_end_event(XState.current, 0)
			finished.emit(0)
			return
		if PACE_GAPS:
			# YEP endTurn：场上还有伤害数字（isPopupPlaying）就先不结束回合，每帧再试
			while popups_pending() or _popups.values().any(func(l): return l.any(func(p): return is_instance_valid(p) and not p.is_queued_for_deletion())):
				await get_tree().physics_frame
		await _play(logic.end_turn())
		if PACE_GAPS:
			# MV endTurn 给每个战斗成员（我方＋敌群全员）push 一条 popupDamage，日志窗一帧执行一条；之后一帧 updateTurnEnd → startTurn
			await _pace_frames(logic.actors.size() + logic.enemies.size())
		await _play_troop_events(logic.troop_events(null, true))
		otb.show_orders(logic.current_order, logic.next_order)
		_refresh_status()
		# 全员不能行动时也交还一帧，保留自动/速度按钮与窗口响应。
		await get_tree().process_frame


## 原版战斗流程里行动之间、回合交界的空帧（ui_reference/battle_pace_ref.cjs 逐帧：行动之间 1 帧、轮到角色再 1 帧；回合末
## 等伤害数字飘完，再按战斗成员数逐帧执行 popupDamage，回合开始日志窗等 8 帧）。复现原版，不登 O 号；
## PACE_GAPS = false 回到不留空帧（tests/xiyou_battle_pace 两支都测）
static var PACE_GAPS := true


func _pace_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## 敌群事件的记录：强制行动（同普通行动）、敌人回复／出现／变身；101 文字停住规则，消息窗确认后续上游标再播后面的记录。
## 自动／挂机时消息窗按已有设置自动翻页；快速战斗也照样执行规则。
func _play_troop_events(logs: Array) -> void:
	while true:
		var rest := logs.filter(func(l): return l.type != "message")
		for l in rest:
			if l.type == "enemy_change":
				_apply_enemy_change(l)
		if not rest.is_empty():
			await _play(rest)
			_sync_appeared()
			otb.show_orders(logic.current_order, logic.next_order)
			_refresh_status()
		if not logic.is_event_waiting():
			return
		var w := logic.event_waiting()
		var response = await message.run(w.msg)
		logs = logic.resume_event(int(w.token), response)


## 敌人变化：出现时显示本体与血条，变身时换战斗图（同一个成员，按记录刷新，不再执行规则）；
## 没出现（隐藏或已倒下）的成员此刻活着就淡入（Sprite_Enemy.setupEffect → startAppear：335 出现、334 复活）
func _apply_enemy_change(l: Dictionary) -> void:
	var e: XEnemy = l.target
	if l.kind == "appear" or l.kind == "transform":
		book_appeared.append(e.enemy_id)
	if not sprites.has(e):
		return
	if l.kind == "transform" and int(l.before.enemy_id) != int(l.after.enemy_id):
		var old: XBattlerSprite = sprites[e]
		_make_enemy_sprite(e)
		sprites[e].appeared = old.appeared
		field.move_child(sprites[e], old.get_index())
		old.queue_free()
	_set_enemy_shown(e)
	if not sprites[e].appeared and not bool(l.after.hidden) and not bool(l.get("views", {}).get(e, {}).get("dead", true)):
		sprites[e].appear()
	if l.has("views"):
		show_views(l.views)


## 记录播完后再对一次 Sprite_Enemy.setupEffect（同一页里先被强制行动打倒、后被 334 复活的成员，倒下演出在复活记录之后才播）
func _sync_appeared() -> void:
	for e in logic.enemies:
		if sprites.has(e) and not sprites[e].appeared and e.is_alive():
			sprites[e].appear()


## BattleManager.processEscape 成功：逃跑音效，消息窗「<队名>开始逃跑了！」（等按键；挂机中按 messageCount 自动翻页），结束战斗（结果 1）
## 开关（O-254，Kyo 2026-11-11「按你设计优化一下」）：true＝照原版 processEscape，逃跑消息一出来就停战斗曲、换回地图曲淡入
## （displayEscapeSuccessMessage 只排文字，紧接 processAbort → replayBgmAndBgs）；false＝等消息窗关掉、战斗发 finished 后才换（原重制）
static var ESCAPE_MAP_AUDIO_EARLY := true

func _escape_success() -> void:
	boss_hp.ended()
	_close_windows()
	_end_record()
	otb.hide_bar()
	logic.escaped = true
	XSound.system(8)
	if ESCAPE_MAP_AUDIO_EARLY:
		escape_audio.emit()
	await message.run({"lines": [escape_text()]})
	XEnemyBook.on_battle_end(XState.current, book_appeared, logic.enemies)
	logic.end_battle(1)
	reserve_battle_end_event(XState.current, 1)
	finished.emit(1)


## BattleManager.processDefeat → displayDefeatMessage：消息窗「<队名>被击败了。」（TextManager.defeat，等按键；挂机中按已有设置
## 自动翻页）；快速战斗跳过失败信息（XdRs_HangUp，见 XHangUp）。rules-battle-pixel2 对照 v0.62.12 截图 bp2_defeat_f30 改：
## 重制原来在战斗日志行显示「全军覆没……」1.2 秒，原版是底部整宽消息窗（与逃跑同一个窗）。
func _defeat() -> void:
	boss_hp.ended()
	otb.hide_bar()
	_close_windows()
	_end_record()
	_defeat_me()
	if not XHangUp.fast_fighting(XState.current):
		await _defeat_message()


## BattleManager.processDefeat：displayDefeatMessage 只是把文字排进消息窗，紧接着 playDefeatMe（Defeat2），所以 ME 和
## 「被击败了」同时出来；快速战斗跳过消息也照放（XdRs_HangUp 只包了 displayDefeatMessage）。战斗曲停掉、ME 放完也不再响
## （可败 replayBgmAndBgs 换回地图曲，由地图接；不可败 stopBgm）
func _defeat_me() -> void:
	play_me(XDB.system().get("defeatMe", {}))
	_bgm_after_me = false
	if bgm != null:
		XAudio.stop_fade(bgm)
		bgm.stop()
		bgm.stream_paused = false


## 失败信息（测试里的快速战斗子类覆写成只等一帧）
func _defeat_message() -> void:
	await message.run({"lines": [defeat_text()]})


## TextManager.defeat.format($gameParty.name())
func defeat_text() -> String:
	return str(XDB.system().terms.messages.get("defeat", "%1被击败了。")).replace("%1", XPreempt.party_name(logic.actors))


## 事件 340 中止战斗：BattleManager.checkAbort → playEscape、_escaped＝true → processAbort（removeBattleStates、endBattle(1)），
## updateBattleEnd 走「逃跑」那支预约 1308。没有消息窗（不同于逃跑成功的「开始逃跑了」）
## 340 所在页同一帧跑完（logic.abort_checks_end）时，原版 checkBattleEnd 里 checkAbort 恒返回 false，processAbort 之后接着判：
## - 我方全灭 → processDefeat（被击败消息、endBattle(2)）：301 分支结果改写成 2；但 _escaped 已置，updateBattleEnd 走「逃跑」那支，
##   预约 1308、不复活、不去结束画面（XMapScene.last_battle_escaped）
## - 敌群全灭 → processVictory（结算、奖励、endBattle(0)），结果 0
## 原版这两种 endBattle 要跑两遍（先 1 后 2／0，各模块的 endBattle 包装也跑两遍）；重制只按最后的结果跑一遍（O-257，
## ABORT_DOUBLE_END 打开时先补跑一遍 end_battle(1)）
static var ABORT_DOUBLE_END := false

func _abort_battle() -> void:
	logic.escaped = true
	XSound.system(8)
	if logic.abort_checks_end() and logic.is_lost():
		if ABORT_DOUBLE_END:
			logic.end_battle(1)
		await _defeat()
		XEnemyBook.on_battle_end(XState.current, book_appeared, logic.enemies)
		logic.end_battle(2)
		reserve_battle_end_event(XState.current, 1)  # 逃跑那支：预约 1308
		finished.emit(2)
		return
	if logic.abort_checks_end() and logic.is_won():
		if ABORT_DOUBLE_END:
			logic.end_battle(1)
		otb.hide_bar()
		await _victory()
		reserve_battle_end_event(XState.current, 0)
		finished.emit(0)
		return
	boss_hp.ended()
	_close_windows()
	_end_record()
	otb.hide_bar()
	XEnemyBook.on_battle_end(XState.current, book_appeared, logic.enemies)
	logic.end_battle(1)
	reserve_battle_end_event(XState.current, 1)
	finished.emit(1)


## MV BattleManager.updateBattleEnd（rpg_managers.js 2696）：没逃跑且全灭时，可输就复活到 1 血、不可输去游戏结束，两种都不预约；
## 其余（胜利、逃跑）预约公共事件 1308「战斗结束变量清除」（清太极之力、查克拉、命运连锁、一护技能号等战斗变量，町甄纯真值回初值，
## 欠债减一）。单槽，覆盖战斗里留下的预约（同 $gameTemp.reserveCommonEvent）；回地图后 XMapScene 照常跑（地图事件跑完才轮到它）。
## 参照 tests/fixtures/battle_end_ce_oracle.json（GD5）。设 0 关掉＝重制原来不预约的样子
static var BATTLE_END_COMMON_EVENT := 1308

static func reserve_battle_end_event(s: XState, result: int) -> void:
	if BATTLE_END_COMMON_EVENT > 0 and s != null and result != 2:
		s.reserve_common_event(BATTLE_END_COMMON_EVENT)


## 逃跑失败：逃跑音效，消息窗两行「<队名>开始逃跑了！」「\.但是没有逃跑成功！」，等按键后这次行动结束（OTB endAction）
func _escape_failure() -> void:
	XSound.system(8)
	await message.run({"lines": [escape_text(), "\\." + str(XDB.system().terms.messages.escapeFailure)]})


## TextManager.escapeStart.format($gameParty.name())：出战 1 人时为其名字，否则 partyName「%1的队伍」
func escape_text() -> String:
	return str(XDB.system().terms.messages.escapeStart).replace("%1", XPreempt.party_name(logic.actors))


## 轮到 u：敌人/自动/不能行动时直接决定；角色由玩家选。逃跑在这里处理，成功时结束战斗并返回 "escaped"。
func _command(u: XBattler):
	# 挂机中队员按自动战斗行动（Game_BattlerBase.isAutoBattle）
	if u is XActor and logic.can_move(u) and XHangUp.is_active(XState.current):
		# 技能顺序表／智能战斗AI（XBattleLogic.auto_battle_action）
		return logic.auto_battle_action(u)
	if not (u is XActor) or logic.auto or not logic.can_move(u) or XConfusion.confused(u):  # 混乱类状态：canInput 假，没有指令窗，直接普通攻击（自动战斗在上面先走）
		return logic.decide(u)
	_set_active(u)
	while true:
		inputting = true
		var r = await _command_for(u)
		inputting = false
		if logic.auto or (r is String and r == "auto"):
			_close_windows()
			return logic.decide(u)
		if r is Array:
			return r
		if r is String and r == "tianqiSwap":
			_tianqi_swap_out = u  # 这次行动放弃，演出完再换（XBattleLogic.tianqi_swap）
			return [null, null]
		if r is String and r == "escape":
			_close_windows()
			if logic.try_escape():
				await _escape_success()
				return "escaped"
			await _escape_failure()
			return [null, null]
		# "back"：OTB 没有队伍指令窗，取消不回到上一人，重新显示指令
	return null


## 天启篇换人：换下的角色图与右侧状态行原地换成助力位的；换不了（这期间助力位倒下等）就什么也不做
var _tianqi_swap_out: XActor = null

func _tianqi_swap(out: XActor) -> void:
	_tianqi_swap_out = null
	var h := logic.tianqi_swap(out)
	if h == null:
		return
	var old: XBattlerSprite = sprites[out]
	var s := XBattlerSprite.new()
	field.add_child(s)
	s.setup(h, ACTOR_SCALE)
	s.home = old.home
	s.position = old.home
	sprites.erase(out)
	old.queue_free()
	sprites[h] = s
	var row: XSideStatus = status_rows[out]
	var nr := XSideStatus.new()
	nr.setup(h, logic.actors.find(h))
	row.get_parent().add_child(nr)
	row.get_parent().move_child(nr, row.get_index())
	nr.cell_pressed.connect(_open_status)
	status_rows.erase(out)
	row.queue_free()
	status_rows[h] = nr
	_refresh_status()
	await message.run({"lines": ["%s退下，%s上场了！" % [out.display_name(), h.display_name()]]})


## 状态详情（installEquipmentStatusRuntime open('status')）：点右侧状态格打开。正式版打开时 BattleManager.update 整个停住、
## 激活的窗口失活，关掉再激活；重制的战斗由协程推进，只在等指令（inputting）时能打开，打开期间指令窗收不到按键与点击
## （面板吃掉输入），关掉后照旧。演出中点状态格不响应。
func _open_status(a: XActor) -> void:
	if not inputting or (status_panel != null and is_instance_valid(status_panel)):
		return
	var saved := []
	for w in [cmd_win, list_win]:
		if w != null and is_instance_valid(w) and w.active:
			w.active = false
			w.canvas.queue_redraw()
			saved.append(w)
	# 网页覆盖层在画布之上：单独一层 95，盖住地图的挂机图标、行动顺序条和提示（90），触屏按键（120）仍在上面
	var top := CanvasLayer.new()
	top.layer = 95
	add_child(top)
	status_panel = XPartyStatusPanel.open(top, logic.actors.filter(func(m): return m is XActor), a)
	status_panel.closed.connect(func():
		status_panel = null
		top.queue_free()
		for w in saved:
			if is_instance_valid(w):
				w.active = true
				w.canvas.queue_redraw())


func _close_windows() -> void:
	for w in [cmd_win, list_win, mimic_win, yun_win, transfer_win]:
		if w and is_instance_valid(w):
			w.queue_free()
	cmd_win = null
	list_win = null
	mimic_win = null
	yun_win = null
	transfer_win = null
	_help()
	otb.clear_preview()


## 选指令时预览：自己下个回合的位置（技能速度＋OTB User Next Turn），以及选中目标的位移。
func _preview(a: XBattler, skill, targets: Array = []) -> void:
	if skill == null:
		otb.clear_preview()
		return
	var entries := []
	if not XBattleLogic.is_item(skill):
		entries.append([a, "n", logic.next_order, int(skill.get("speed", 0)) + XBattleLogic._note_int(skill, "OTB User Next Turn") + XXuanBattle.manual_first_shift(logic, a, skill), logic._speed])
	var cur := XBattleLogic._note_int(skill, "OTB Target Current Turn")
	var nxt := XBattleLogic._note_int(skill, "OTB Target Next Turn")
	nxt += XBattleLogic.agi_convert_shift(skill)  # 敏捷增益 +1、减益 −1（O-219）
	var follow := XBattleLogic._note_int(skill, "OTB Target Follow Turn")
	for t in targets:
		if logic._speed.get(t, 0.0) == INF:
			continue
		var c := cur + (follow if logic.current_order.has(t) else 0)
		var n := nxt + (0 if logic.current_order.has(t) else follow)
		entries.append([t, "c", logic.current_order, c, logic._speed])
		entries.append([t, "n", logic.next_order, n, logic._speed])
	otb.set_preview(entries)


## 指令（Window_ActorCommand＋OTB）：攻击（YEP_WeaponUnleash：替换后的技能与名字）、加入的技能类型（按编号；CP_MagicWeapon 不列 3～6，没有该类技能也列出；
## 渡鸦／宿傩／饿狼照 XActorModules.battle_skill_types 固定几栏）、
## 防御、物品、逃跑（OTB Escape Actor Window：总是列出，不能逃时灰显）；云裳的天衣指令（XYunshang.command_entries）；魔族再加「血契：开／关」。
func _command_entries(a: XActor) -> Array:
	var terms: Array = XDB.system().terms.commands
	var atk := a.attack_skill()
	var grd := XDB.rec("Skills", XBattleLogic.GUARD_SKILL)
	var opts := [{"text": a.attack_command_text(), "key": "attack", "enabled": logic.can_use(a, atk), "preview": atk}]
	var stypes: Array = XDB.system().skillTypes
	var forced = XActorModules.battle_skill_types(a)  # 渡鸦／宿傩／饿狼 addSkillCommands 包装：固定几栏、照次序
	if XTusu.bound_tusu(a):
		forced = []  # 屠苏 addSkillCommands 包装：武具态只有一栏「易武」（技能类型 1）
		opts.append({"text": "易武", "key": "stype:1"})
	if forced != null:
		for t in forced:
			opts.append({"text": str(stypes[int(t)]), "key": "stype:%d" % int(t)})
	var added := a.traits_set(XBattler.TRAIT_STYPE_ADD) if forced == null else []
	added.sort()
	for t in added:
		if not [3, 4, 5, 6].has(int(t)) and int(t) < stypes.size():
			opts.append({"text": str(stypes[int(t)]), "key": "stype:%d" % int(t)})
	opts.append({"text": str(terms[3]), "key": "guard", "enabled": logic.can_use(a, grd), "preview": grd})
	opts.append({"text": str(terms[4]), "key": "item"})
	if logic.can_tianqi_swap(a):
		opts.append({"text": "换人", "key": "tianqiSwap"})  # 天启篇：和助力位换（用掉这次行动）
	opts.append({"text": str(terms[1]), "key": "escape", "enabled": logic.can_escape})
	opts = XTusu.command_entries(logic, a, opts)  # 屠苏 makeCommandList 包装：持武者技能栏去重；武具态插「武相支援」、防御改「待命」
	opts.append_array(XXuanBattle.command_entries(logic, a))  # 璇 makeCommandList 包装：附身时「回身」
	opts.append_array(XYunshang.command_entries(a))  # 云裳 makeCommandList 包装（种族之前装）：赠行、放行、裁身、收袖、七曜元素
	# installNativeRaceRuntime makeCommandList 包装：魔族在最后加「血契：开／关」
	var blood := XRaceBattle.blood_command_text(a)
	if blood != "":
		opts.append({"text": blood, "key": "raceBlood"})
	return opts


## Olivia updatePosition：x = 角色 x + 图宽/2（64/2），y = 角色 y − 图高（64）；再收在画面内。列表另加 (16, 16)。
func _place_near_actor(w: XBattleList, a: XActor, offset := Vector2.ZERO) -> void:
	var s: XBattlerSprite = sprites[a]
	var p := s.position + Vector2(32, -64)
	w.place(minf(BOX.x - w.size.x, p.x) + offset.x, minf(BOX.y - w.size.y, p.y) + offset.y)
	w.position += _origin


func _command_for(a: XActor):
	var opts := _command_entries(a)
	var last_index := initial_command_index(a, opts)
	while true:
		_close_windows()
		cmd_win = XBattleList.create(ui, opts, CMD_W, "center")
		cmd_win.cancel_enabled = false
		cmd_win.index_changed.connect(func(i): _preview(a, opts[i].get("preview") if i >= 0 else null))
		cmd_win.chosen.connect(func(i): _picked.emit(opts[i].key))
		cmd_win.select(last_index)
		_place_near_actor(cmd_win, a)
		var pick = await _picked
		last_index = cmd_win.index if cmd_win else 0
		if pick is String and pick == "auto":
			return "auto"
		if pick is String and pick not in ["back", "cancel"]:
			a.last_command = pick if XConfig.flag("commandRemember") else ""
		if pick is String and pick.begins_with("stype:"):
			cmd_win.active = false
			var action = await _pick_action_list(a, logic.battle_skills(a).filter(func(x): return XTusu.battle_listed(a, x, int(pick.substr(6)))), false)  # 屠苏 Window_BattleSkill.includes 包装
			if logic.auto:
				return "auto"
			if action is Array:
				return action
			continue
		match pick:
			"attack":
				var atk := a.attack_skill()  # YEP_WeaponUnleash commandAttack：attackSkillId
				var t = await _pick_target(atk, a, false)
				if logic.auto:
					return "auto"
				if t != null:
					return [atk, t]
			"guard":
				return [XDB.rec("Skills", XBattleLogic.GUARD_SKILL), null]
			"xuanReturn":
				return [XDB.rec("Skills", XTusuXuan.skill_id(XXuanBattle.XUAN, "return")), a]
			"tusuSupport":
				# 屠苏 codexTusuSupport 处理器：用当前武相的支援（不能用时重画指令窗）；选目标取消回指令窗（onEnemyCancel／onActorCancel 包装）
				var sk := XTusu.support_skill(a)
				if sk.is_empty() or not logic.can_use(a, sk):
					opts = _command_entries(a)
					continue
				a.last_battle_skill = int(sk.id)
				cmd_win.active = false
				var t = await _pick_target(sk, a)
				if logic.auto:
					return "auto"
				if t != null:
					return [sk, t]
			"raceBlood":
				# 原版处理器：切换后 setup(actor) 重画指令窗再激活（光标照 selectLast：记忆指令开时停在血契，否则回第一项）
				XRace.toggle_blood(logic.state, a)
				opts = _command_entries(a)
				last_index = initial_command_index(a, opts)
			"yunSleeve", "yunRelease":
				# 原版处理器：切换收袖／放行后 setup(actor) 重画指令窗（光标照 selectLast）
				if pick == "yunSleeve":
					XYunshang.sleeve[a] = not bool(XYunshang.sleeve.get(a, false))
				else:
					XYunshang.release(logic, a)
				opts = _command_entries(a)
				last_index = initial_command_index(a, opts)
			"yunGift", "yunCut", "yunElement":
				cmd_win.active = false
				if await _yun_command(a, pick):
					opts = _command_entries(a)
					last_index = initial_command_index(a, opts)
				if logic.auto:
					return "auto"
			"escape":
				return "escape"
			"tianqiSwap":
				return "tianqiSwap"
			"item":
				cmd_win.active = false
				var action = await _pick_action_list(a, battle_item_order(logic.state, logic.battle_items()), true)
				if logic.auto:
					return "auto"
				if action is Array:
					return action
			"back", "cancel":
				return "back"
	return null


## 目标取消后返回刚才的技能/物品列表；再次取消才回指令（MV onEnemyCancel/onActorCancel）。
func _pick_action_list(a: XActor, entries: Array, items: bool):
	var index := initial_action_index(a, entries, items)
	while not logic.auto:
		var entry = await _pick_from_list(a, entries, items, index)
		if not entry is Dictionary or logic.auto:
			return null
		index = entries.find(entry)
		# 异化百相 onSkillOk 包装（Workshop:34）：切换仿形先开选仿形窗，取消回技能列表（不记选择）；选定后照原 onSkillOk 继续
		var mimic := not items and int(entry.id) == XAlienBattle.switch_id()
		if mimic:
			var pick = await _pick_mimic(a)
			if logic.auto:
				return null
			if pick == null:
				continue
			XAlienBattle.choose_mimic(a, pick)
		# 云裳 onSkillOk 包装（异化之内）：收针先选觉醒者，没醒的换锦先选自己的状态；取消回技能列表
		var yun := {}
		if not items and int(entry.id) == XYunshang.GATHER:
			var t = await _yun_pick(XYunshang.gather_rows(logic))
			if logic.auto:
				return null
			if t == null:
				continue
			yun.gather = t.target
		if not items and XYunshang.exchange_needs_pick(a, entry):
			var m = await _yun_pick(XYunshang.exchange_rows(a, false))
			if logic.auto:
				return null
			if m == null:
				continue
			yun.mine = int(m.id)
		# Scene_Battle.onSkillOk/onItemOk：先记选择，再选目标；取消目标也保留。
		if items:
			logic.state.last_item = int(entry.id)
		else:
			a.last_battle_skill = int(entry.id)
		var target = await _pick_target(entry, a)
		while target is XEnemy and yun.has("mine"):
			# 云裳 onEnemyOk 包装：选完敌人再选它的状态；取消回选敌
			var th = await _yun_pick(XYunshang.exchange_rows(target, true))
			if logic.auto:
				return null
			if th != null:
				yun.theirs = int(th.id)
				break
			target = await _pick_target(entry, a)
		if target != null:
			if yun.has("gather"):
				XYunshang.wake_target = yun.gather  # action._yunWakeTarget
			if yun.has("mine"):
				XYunshang.exchange_pick = [yun.mine, int(yun.get("theirs", 0))]  # action._yunExchangeSelf／_yunExchangeEnemy
			return [entry, target]
		XGuyu.transfer_mode = "give"  # 谷雨 onActorCancel 包装：回技能列表（原版选择记在这次输入的行动上，下次选转移重新开窗）
		XGuyu.transfer_ratio = 0.5
		if mimic:
			XAlienBattle.choose_mimic(a, 0)  # 原版选择记在这次输入的行动上，取消后不会带到别的回合
	return null


## 云裳指令窗的三项选择（第 535 行处理器）：赠行选人→免费赠 2 次；裁身选一项（觉醒选两项）→Y.cut；七曜选元素。
## 选完返回真（原版 setup(actor) 重画指令窗）；任何一步取消返回假（只把指令窗激活回来，选过的作废）
func _yun_command(a: XActor, key: String) -> bool:
	match key:
		"yunGift":
			var r = await _yun_pick(XYunshang.gift_rows(logic, a))
			if r == null:
				return false
			XYunshang.free_gift(logic, a, r.target)
		"yunCut":
			var chosen := []
			while true:
				var r = await _yun_pick(XYunshang.cut_rows(chosen))
				if r == null:
					return false
				chosen.append(int(r.id))
				if not (XYunshang.awake(a) and chosen.size() < 2):
					break
			XYunshang.cut(a, chosen)
		"yunElement":
			var r = await _yun_pick(XYunshang.element_rows(a))
			if r == null:
				return false
			XYunshang.setting(a).element = int(r.id)
			XYunshang.element_round[a] = XYunshang.round
	return true


## 开一个云裳选择窗（XYunChoicesWindow），返回选中的那一行（Dictionary）；取消返回 null
func _yun_pick(rows: Array):
	yun_win = XYunChoicesWindow.for_rows(ui, rows)
	yun_win.position += _origin
	var w := yun_win
	w.chosen.connect(func(i): _picked.emit(w.entries[i]))
	w.cancelled.connect(func(): _picked.emit("cancel"))
	var r = await _picked
	if is_instance_valid(w):
		w.queue_free()
	if yun_win == w:
		yun_win = null
	return r if r is Dictionary else null


## 异化百相的选仿形窗（Window_AlienMimic）：列出仿形记录，当前仿形不可选。返回选中的技能号，取消返回 null
func _pick_mimic(a: XActor):
	var d = XAlienBattle.locked(a)
	if d == null:
		return null
	mimic_win = XAlienMimicWindow.for_records(ui, d.get("observed", []), int(d.get("selected", 0)))
	mimic_win.position += _origin
	var w := mimic_win
	w.chosen.connect(func(i): _picked.emit(int(w.ids[i])))
	w.cancelled.connect(func(): _picked.emit("cancel"))
	var r = await _picked
	if is_instance_valid(w):
		w.queue_free()
	mimic_win = null
	return r if r is int else null


func initial_command_index(a: XActor, entries: Array) -> int:
	if not XConfig.flag("commandRemember"):
		return 0
	var key := a.last_command
	if key.begins_with("stype:"):
		var skill := XDB.rec("Skills", a.last_battle_skill)
		if not skill.is_empty():
			key = "stype:%d" % int(skill.stypeId)
	var i := entries.find_custom(func(e): return str(e.key) == key)
	if i < 0 and a.last_command.begins_with("stype:"):
		i = entries.find_custom(func(e): return str(e.key).begins_with("stype:"))
	return maxi(0, i)


func initial_action_index(a: XActor, entries: Array, items: bool) -> int:
	var id := logic.state.last_item if items else a.last_battle_skill
	return maxi(0, entries.find_custom(func(e): return int(e.id) == id))


## Window_BattleItem 的列表：$gameParty.canUse 的物品（battle_items，按 ID）再经 Window_ItemList.makeItemList 的
## Star_ItemTop／Star_ShopOnekey 改写——与物品页共用 XItemMarks.apply_list（置顶的逐个移到最前）。
## 不走 Codex 装备检索排序（只在物品页、装备页），不画 NEW、不记看过（见 XItemRow）。返回原记录（行动与战斗记录用原名）。
static func battle_item_order(s: XState, items: Array) -> Array:
	return XItemMarks.apply_list(s, items.map(func(r): return {"rec": r, "item": r})).map(func(d): return d.item)


## 技能/物品列表的一行：技能右侧照 YEP 消耗（TP 图标 1268 色 29、MP 图标 1269 色 23，字号 20）；
## 冷却「nCD」色 6、预热「nWU」色 4（图标 1045）。
## 物品：名字带「[锁定]」「[置顶]」标记（XItemMarks.decorate，O-030 只画在列表里），名字宽扣「×0,000」（YEP numberWidth），
## 右侧「×数量」千分位、字号 20（YEP_CoreEngine drawItemNumber）。
func _list_entry(a: XActor, e: Dictionary, items: bool) -> Dictionary:
	if items:
		return item_list_row(logic.state, e, logic.can_use(a, e))
	var row := {"text": str(e.name), "icon": int(e.get("iconIndex", 0)), "enabled": logic.can_use(a, e), "costs": []}
	var wu := int(ceilf(float(a.warmups.get(int(e.id), 0))))
	var cd := int(ceilf(float(a.cooldowns.get(int(e.id), 0))))
	if wu > 0:
		row.costs = [{"text": "%dWU" % wu, "color": XUI.text_color(4), "icon": 1045}]
	elif cd > 0:
		row.costs = [{"text": "%dCD" % cd, "color": XUI.text_color(6), "icon": 1045}]
	else:
		row.costs = XBattleLogic.item_cost_rows(e)
		var c := logic.skill_cost(a, e)
		if c.tp > 0:
			row.costs.append({"text": "%sTP" % XMenu._group(c.tp), "color": XUI.text_color(29), "icon": 1268})
		if c.mp > 0:
			row.costs.append({"text": "%sMP" % XMenu._group(c.mp), "color": XUI.text_color(23), "icon": 1269})
		var hp := XBattleLogic.skill_hp_cost(a, e)
		if hp > 0:
			row.costs.append({"text": "%sHP" % XMenu._group(hp), "color": XUI.text_color(18), "icon": 1266})  # YEP drawHpCost
		var custom := XSkillScene.custom_cost_row(e, XBattleList.FS)  # YEP drawCustomDisplayCost（Olivia 缩放后的标准字号）
		if not custom.is_empty():
			row.costs.append(custom)
	return row


static func item_list_row(s: XState, e: Dictionary, enabled: bool) -> Dictionary:
	return {"text": str(XItemMarks.decorate(s, e).name), "icon": int(e.get("iconIndex", 0)), "enabled": enabled, "reserve": "×0,000",
		"costs": [{"text": "×" + XMenu._group(s.item_count(int(e.id))), "size": 20}]}


## Window_BattleSkill / Window_BattleItem（宽 450、最多 16 行），贴在角色旁 (+16, +16)。
func _pick_from_list(a: XActor, entries: Array, items: bool, initial_index := 0):
	_close_list()
	XActor.read_begin()  # 只读窗口缓存（O-待定-1）：逐行算能不能用、费用都是只读
	var rows := entries.map(func(e): return _list_entry(a, e, items))
	XActor.read_end()
	list_win = XBattleList.create(ui, rows, LIST_W)
	list_win.index_changed.connect(func(i):
		if i >= 0 and i < entries.size():
			_help(entries[i])
			_preview(a, null if items else entries[i]))
	list_win.chosen.connect(func(i): _picked.emit(entries[i]))
	list_win.cancelled.connect(func(): _picked.emit("cancel"))
	list_win.select(initial_index)
	_place_near_actor(list_win, a, Vector2(16, 16))
	_help(entries[list_win.index] if list_win.index >= 0 and list_win.index < entries.size() else null)
	while true:
		var r = await _picked
		if r is Dictionary and not items and XGuyu.key(r) == "transfer":
			var t = await _pick_transfer(a)
			if t is String and t == "cancel":
				# returnToSkills：技能窗重新可操作，说明卡回到选中行
				list_win.active = true
				_help(entries[list_win.index] if list_win.index >= 0 and list_win.index < entries.size() else null)
				continue
			if not t is bool:
				r = t
		if r is Dictionary:
			_close_list()
			return r
		if r is String and (r == "cancel" or r == "back" or r == "auto"):
			_close_list()
			if cmd_win:
				cmd_win.active = true
			return null


## 谷雨 onSkillOk 包装（installNativeGuyuRuntime 530～562）：选了「借一枝春色」先开赠春／还春选择窗——技能窗留着但不可操作、
## 说明卡收起；选定把方向与比例写进这次行动（XGuyu.transfer_mode／transfer_ratio，行动结束设回）再选目标，取消回技能列表。
## 选定时再校一次（choose 处理器）：没有能转的目标就重画、留在窗里。返回 true（选定）、"cancel" 或别的 _picked（自动、退回）。
func _pick_transfer(a: XActor):
	list_win.active = false
	_help()
	transfer_win = XGuyuTransferWindow.for_actor(ui, a)
	transfer_win.position += _origin
	var w := transfer_win
	w.chosen.connect(func(i): _picked.emit({"guyu_transfer": i}))
	w.cancelled.connect(func(): _picked.emit("cancel"))
	var out = null
	while true:
		var r = await _picked
		if r is Dictionary and r.has("guyu_transfer"):
			var e: Dictionary = w.entries[int(r.guyu_transfer)]
			if not XGuyu.can_transfer(a, str(e.mode), float(e.ratio)):
				w.entries = XGuyu.transfer_commands(a)
				w.refresh()
				continue
			XGuyu.transfer_mode = str(e.mode)
			XGuyu.transfer_ratio = float(e.ratio)
			out = true
		else:
			out = r
		break
	if is_instance_valid(w):
		w.queue_free()
	transfer_win = null
	return out


func _close_list() -> void:
	if list_win and is_instance_valid(list_win):
		list_win.queue_free()
	list_win = null
	_help()


## 选目标：单体点敌人（或我方）；全体／随机／自身也先进一步确认（YEP Select Help Window），确认后返回占位目标。
## forced：YEP onSelectAction 的 forceSelection（技能、物品列表确定后）；攻击指令（YEP_WeaponUnleash commandAttack）先判 needsSelection，不强制。
func _pick_target(skill: Dictionary, a: XActor, forced := true):
	# 异化行动道具投影（原版换掉 Game_Action.item）：选目标读投影后的技能（祸祝选敌人、逆祷攻击选友方），
	# 下面的 scope、forceSelection、妖族猎物、行动顺序预览都用它；说明卡读技能窗的原技能，选目标时不显示，不受影响
	skill = XAlienBattle.project(a, skill)
	if XAlienBattle.prayer_random_count(skill) > 0:
		return a  # 逆祷 needsSelection 包装（Aff:48）：原 scope 3～6 改随机友方，不选（在 forceSelection 之外）
	var scope := int(skill.get("scope", 1))
	# 种族 needsSelection 包装：妖族的全体伤害也选一名敌人，选中的记作猎物（onEnemyOk 包装），行动对象仍是全体
	var prey_pick := XRaceBattle.needs_prey_selection(a, skill)
	# 原版 Game_Action.needsSelection 包装：scope 0 永不选；forceSelection 时其余都选。帮助窗是 HelpExtend 的说明卡，
	# 没有 setBattler（YEP 在 updateHelp 里调用时抛错被吞），所以「All Enemies」之类的范围文字和全体高亮（startAllSelection）原版都不出现。
	var confirm := forced and scope != 0
	if not [1, 7, 9].has(scope) and not prey_pick and not confirm:
		return a
	var foe := (scope >= 1 and scope <= 6) or prey_pick
	var pool: Array
	if foe:
		pool = XSukuna.selectable_enemies(a, skill, logic.alive(logic.enemies))  # 宿傩 Window_BattleEnemy.refresh 包装：神灶只列蓄力的敌人
	elif scope == 7:
		pool = XXuanBattle.filter_pick(a, skill, logic.alive(logic.actors))  # 璇 Window_BattleActor 包装：寄星只能选合法宿主
	elif scope == 9:
		pool = logic.actors.filter(func(x): return x.is_dead())
	elif scope == 11:
		# Window_BattleActor.autoSelect：自身锁定在行动者
		pool = [a]
	else:
		# 全体我方（8／10）：cursorAll＋锁定，但 startAllSelection 没跑到，只有第 1 位亮光标
		pool = [logic.actors[0]] if not logic.actors.is_empty() else []
	if pool.is_empty():
		return null
	_target_mode = "enemy" if foe else "ally"
	_target_pool = pool
	_target_group = _select_all_group(scope, prey_pick)
	_target_prey = prey_pick and SELECT_ALL_HIGHLIGHT
	# Olivia_SideBattleUI 选敌／选我方窗激活时每帧 updateFadeOut：指令窗不透明度每帧 −16，16 帧淡到 0（不先 hide）；
	# 技能／物品窗 onSelectAction 时已 hide。取消回来 updatePosition→updateFadeIn 立刻 255。
	var cmd_was_active := false
	var cmd_fade: Tween = null
	if cmd_win and is_instance_valid(cmd_win):
		cmd_was_active = cmd_win.active
		cmd_win.active = false
		cmd_fade = cmd_win.create_tween()
		cmd_fade.tween_property(cmd_win, "modulate:a", 0.0, CMD_FADE_FRAMES / 60.0)
	_help()
	_target_skill = skill
	# YEP Enemy Auto Select = furthestRight（敌方范围都一样，含全体与随机）；我方默认第一人。
	var initial = pool[0]
	if foe:
		for b in pool:
			if sprites[b].home.x > sprites[initial].home.x:
				initial = b
	_select_target(initial)
	var r = await _picked
	while true:
		if r is XBattler and pool.has(r) and XYunshang.rejects_target(a, skill, r):
			XSound.system(3)  # 云裳 onActorOk 包装：敕衣点神选没穿天衣的、赠行选自己——蜂鸣，留在选人
		elif r is XActor and XGuyu.key(skill) == "transfer" and not bool(XGuyu.transfer_preview(a, r, XGuyu.transfer_mode, XGuyu.transfer_ratio).valid):
			# 谷雨 onActorOk 包装：转移的预览不合法（自己、归根的、储备不足或已满）时蜂鸣、留在选目标，说明卡再写一次
			XSound.system(3)
			_select_target(r)
		else:
			break
		r = await _picked
	_target_mode = ""
	_target_pool = []
	_target_group = []
	_target_prey = false
	_target_skill = {}
	_select_target(null)
	otb.clear_preview()
	_help()
	if cmd_fade:
		cmd_fade.kill()
	if cmd_win and is_instance_valid(cmd_win):
		cmd_win.modulate.a = 1.0
		cmd_win.active = cmd_was_active
	if r is XBattler and pool.has(r):
		if prey_pick:
			XRaceBattle.set_manual_prey(logic, a, skill, r)
			return a
		# 全体／随机／自身：选的那一位只是确认（makeTargets 不看序号），行动对象照旧
		return r if [1, 7, 9].has(scope) else a
	return null


func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.INF
	if event is InputEventMouseMotion and _target_mode != "":
		if not XTouchControls.battle_tap_allowed() and event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		# 鼠标指向的候选目标视为「被选中」：顺序条上放大闪烁，并预览位移
		var h = _nearest_target(event.position)
		if h != null and h != _hover:
			_select_target(h)
		return
	if event is InputEventMouseButton and message != null and message.is_visible_in_tree() and message.is_busy():
		# 战斗里的 101 消息：左键翻页／关闭、右键、滚轮交给消息窗（它在 _unhandled_input 里收；本场景 STOP 会先收下，
		# 真实分发时到不了消息窗——battlefix2 用真实事件测出来的）
		message._unhandled_input(event)
		accept_event()
		return
	# 手机按键设置「战斗点击操作：仅屏幕按键」（改版 battleTouch 默认关，Window_BattleXxx.processTouch 不处理）：
	# 触屏点按（含 Godot 由第一指转出的鼠标）不选战斗选项与目标；消息窗翻页照旧（上面先处理）
	if not XTouchControls.battle_tap_allowed() and (event is InputEventScreenTouch or (event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION)):
		return
	if event is InputEventMouseButton and event.pressed:
		# 不在选目标时，左键／滚轮交给开着的技能（物品）列表或指令窗（Window_Selectable.processTouch／processWheel）：
		# 本场景铺满全屏、MOUSE_FILTER_STOP，点击在这里就被收下，到不了列表的 _unhandled_input（Kyo 11-06 实机：鼠标选不了战技）
		if _target_mode == "" and event.button_index != MOUSE_BUTTON_RIGHT and _mouse_to_window(event):
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_picked.emit("cancel" if _target_mode != "" or list_win != null else "back")
			return
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	if pos == Vector2.INF or _target_mode == "":
		return
	var best = _nearest_target(pos)
	if best != null:
		_picked.emit(best)


## 鼠标键转给开着、可操作的列表（先技能／物品列表，再指令窗）；坐标换成窗口父节点里的坐标（XBattleList._hit 按 position 算）
func _mouse_to_window(event: InputEventMouseButton) -> bool:
	for w in [list_win, cmd_win]:
		if w == null or not is_instance_valid(w) or not w.active or not w.is_visible_in_tree():
			continue
		var e := event.duplicate() as InputEventMouseButton
		e.position = (w.get_parent() as CanvasItem).get_global_transform().affine_inverse() * event.global_position
		w._unhandled_input(e)
		return true
	return false


func _nearest_target(pos: Vector2):
	var best = null
	var best_d := 1e9
	for b in _target_pool:
		var s: XBattlerSprite = sprites[b]
		var c := _origin + s.position + Vector2(0, -s.height() / 2.0)
		var d := c.distance_to(pos)
		if d < best_d and d < maxf(90.0, s.height()):
			best_d = d
			best = b
	return best


## 优化 O-112（用户 2026-10-29 定）：全体／随机范围的技能选目标时，这次会打到的整组一起亮（YEP 本意 startAllSelection，
## 原版因 HelpExtend 说明卡缺 setBattler 没跑到）；箭头光标仍只在光标那只、可移动、默认最右。妖族群攻手选猎物时整组亮、
## 光标那只闪红当猎物。false 照原版：只亮光标那只（全体我方只亮第 1 位）。
static var SELECT_ALL_HIGHLIGHT := true


## 要一起亮的整组：敌方全体（2）／随机（3～6）＝活着的敌人；我方全体（8）＝活着的队友，（10）＝倒下的队友；
## 妖族手选猎物（全体伤害）＝活着的敌人。单体、自身、开关关掉时为空。
func _select_all_group(scope: int, prey_pick: bool) -> Array:
	if not SELECT_ALL_HIGHLIGHT:
		return []
	if prey_pick or (scope >= 2 and scope <= 6):
		return logic.alive(logic.enemies)
	if scope == 8:
		return logic.alive(logic.actors)
	if scope == 10:
		return logic.actors.filter(func(x): return x.is_dead())
	return []


func _select_target(b) -> void:
	_hover = b
	var group: Array = _target_group if b != null else []
	for actor in status_rows:
		status_rows[actor].selected = actor == b or group.has(actor)
	for who in sprites:
		var s: XBattlerSprite = sprites[who]
		if s.selected and who.is_alive():
			s.sprite.modulate = Color.WHITE
		s.selected = who == b or group.has(who)
		s.show_cursor = who == b
		s.prey = _target_prey and who == b
	otb.set_selected(group if not group.is_empty() else ([b] if b != null else []))
	if b != null:
		_preview(_active, _target_skill, [b])
	if b is XEnemy and _target_mode == "enemy":
		_poison_help(b)
	elif b is XActor and _target_mode == "ally" and XGuyu.key(_target_skill) == "transfer":
		_transfer_help(b)


## 优化 O-107：选敌时的毒鸡汤说明卡贴在该敌人旁边，选到没有毒鸡汤的敌人就收起。
## false 照原版：卡片位置从上一张卡的位置再按 setItem 修正（每次都会再挪一次），选到没有毒鸡汤的敌人时上一段文字留着。
static var POISON_HELP_NEAR := true

## Window_BattleEnemy.updateHelp 的种族包装：本回合有人在该敌人身上记了毒鸡汤时，说明卡（Sprite_ItemHelp.setText）写「敌人名＋说明」；
## YEP 的 setBattler 说明卡上没有（异常被吞），所以没有毒鸡汤时原版什么也不画。
func _poison_help(e: XEnemy) -> void:
	var info := XRaceBattle.poison_info(logic, e)
	if info == "":
		if POISON_HELP_NEAR and help_card != null:
			help_card.visible = false
		return
	_text_help(e.display_name() + "\n" + info, e, "right", POISON_HELP_NEAR)


## 优化 O-140：转移选目标时的说明卡贴在该队员左侧。false 照原版：每次换目标（Window_BattleActor.select）都 setText，
## 卡片从上一张卡的位置再按 setItem 修正一次（同 O-107 关掉时的毒鸡汤卡）。
static var TRANSFER_HELP_NEAR := true

## 谷雨 guyuUpdateTransferHelp（Window_BattleActor.select 包装）：选队友时说明卡写 G.transferText（方向、比例、去向、储备量；不合法时是原因）
func _transfer_help(t: XActor) -> void:
	_text_help(XGuyu.transfer_text(_active, t, XGuyu.transfer_mode, XGuyu.transfer_ratio), t, "left", TRANSFER_HELP_NEAR)


## Sprite_ItemHelp.setText 的说明卡：near 时贴在战斗者图（连同脚下约 40px）的 side 一侧；否则照原版从上一张卡的位置再修正
func _text_help(text: String, b: XBattler, side: String, near: bool) -> void:
	if help_card == null:
		_help()
	help_card.show_text(text)
	ui.move_child(help_card, -1)
	var p := help_card.position - _origin  # 画布坐标（1280×720）
	if near:
		# 战斗者图（脚底居中）连同脚下的名字与血条（约 176 宽）的一侧，放不下就放另一侧
		var sp: XBattlerSprite = sprites[b]
		var w := maxf(sp.width(), 180.0)
		help_card.place_near(Rect2(sp.position - Vector2(w / 2.0, sp.height()), Vector2(w, sp.height() + 40.0)), side)
	else:
		# Sprite_ItemHelp.setItem：在上一张卡的位置上再修正一次
		var sz := help_card.size
		p.x += 52 if p.x < 900 else -10
		if p.y < 220:
			p.y += 32
		if p.y > 400:
			p.y -= 100
		if p.y > 500:
			p.y -= 250
		if p.x + sz.x > 1280:
			p.x = 1280 - sz.x - 30
		if p.y + sz.y > 720:
			p.y = 720 - sz.y - 30
		help_card.position = p
	help_card.position += _origin


## 玩家反馈（v0.01.06，O-待定）：原版选敌／选我方窗也是 Window_Selectable，确定、取消认 Input.isRepeated（按住 24 帧后每 6 帧一次），
## 按住确定能从技能列表一路确认到目标、连续出招。重制的选目标原先只认新按下，按住确定会停在选目标。现在确定、取消也认回显（连发）。
## 回退开关 HOLD_OK_TARGET = false：选目标只认新按下。
static var HOLD_OK_TARGET := true


func _unhandled_input(event: InputEvent) -> void:
	if book_page != null:
		return
	# AB_EnemyBook v1.28：角色指令窗、技能／物品列表开着且可操作时按 Shift（ShortCutButtonName）打开「怪物信息」
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SHIFT and _target_mode == "" and not logic.auto:
		var w: XBattleList = list_win if list_win != null and list_win.active else (cmd_win if cmd_win != null and cmd_win.active else null)
		if w != null and w.is_visible_in_tree():
			XKeyMap.handled(self)
			_open_battle_book(w)
			return
	if _target_mode != "":
		var i := _target_pool.find(_hover)
		if event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_down", true):
			_select_target(_target_pool[(i + 1) % _target_pool.size()])
		elif event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_up", true):
			_select_target(_target_pool[posmod(i - 1, _target_pool.size())])
		elif event.is_action_pressed("ui_accept", HOLD_OK_TARGET):
			_picked.emit(_hover)
		elif event.is_action_pressed("ui_cancel", HOLD_OK_TARGET):
			_picked.emit("cancel")
		else:
			return
		XKeyMap.handled(self)
	elif event.is_action_pressed("ui_cancel"):
		_picked.emit("cancel" if list_win != null else "back")


## Scene_Battle.battleEnemyBook：发出窗口先停（播确定音），图鉴关掉（取消）后回到它
func _open_battle_book(w: XBattleList) -> void:
	XSound.system(1)
	w.active = false
	book_page = XEnemyBookPage.new()
	book_page.setup_battle(logic.enemies)
	ui.add_child(book_page)
	await book_page.closed
	book_page.queue_free()
	book_page = null
	if is_instance_valid(w):
		w.active = true


# ---- 播放行动记录 ----
## 正式版运行时逐帧读数（地图 5 普通攻击）：行动开始即在日志显示行动名；第 12 帧角色做动作（不前进），
## 再 2 帧出伤害数字；第 41 帧日志清空，第 52 帧轮到下一位（OFF 档）。技能动画由局外配置控制。
const ENTRY_FRAMES := 30
const ACT_MOTION_FRAMES := 12
const ACT_HIT_FRAMES := 2
const ACT_LOG_FRAMES := 41
const ACT_END_FRAMES := 52


## 敌群事件／战斗里的公共事件的画面指令（XBattleEventRunner 记的 event_view）：
## 221／222 Game_Interpreter.command221／222：startFadeOut／startFadeIn(fadeSpeed 24)，事件等 24 帧；
## 224 command224：startFlash(颜色, 帧数)，勾了等待才等。battleback 卷动只是记录，不演。
## 原版 wait(n) 把 _waitCount 设 n，之后 n 帧都在 updateWaitCount 里空转，第 n＋1 帧才跑下一条
## （参照 battle_screen_fx_oracle：221 在 k=1，101 在 k=26；222 在 k=119，224 在 k=144），所以这里等 n＋1 帧。
func _event_view(l: Dictionary) -> void:
	if l.has("fade"):
		screen_fx.start_fade(str(l.fade) == "out", XBattleScreen.FADE_SPEED)
		await _wait_frames(XBattleScreen.FADE_SPEED + 1)
	elif l.has("flash"):
		screen_fx.start_flash(l.flash, int(l.duration))
		if bool(l.get("wait", false)):
			await _wait_frames(int(l.duration) + 1)


func _wait_frames(n: int) -> void:
	for i in range(maxi(n, 0)):
		await get_tree().physics_frame


func _play(logs: Array) -> void:
	var started := Engine.get_physics_frames()
	var acting := false
	var i := 0
	while i < logs.size():
		var l: Dictionary = logs[i]
		i += 1
		if l.type in ["action", "regen", "collapse"] and l.has("views"):
			show_views(l.views)
		# YEP 行动序列：行动记录后面跟着 seq_* 条目时交给 XSequencePlayer 逐帧演出（到 seq_end 为止）
		# 行动记录与序列之间可能夹着专属模块 startAction 包装的日志行（宿傩终式），先加进日志再交给序列
		var k := i
		while l.type == "action" and k < logs.size() and str(logs[k].type) == "battle_text":
			k += 1
		if l.type == "action" and k < logs.size() and str(logs[k].type) == "seq_phase":
			for t in logs.slice(i, k):
				_log_add(str(t.text))
			i = k
			if acting:
				await _finish_action(started)
				acting = false
			var j := i
			while j < logs.size() and logs[j].type != "seq_end":
				j += 1
			combo.action_started()
			if l.user is XActor:
				_set_active(l.user)
			if XSukunaFx.shrine_action(l):
				await _sukuna_fx("shrine")
			await XSequencePlayer.create(self, l, logs.slice(i, j + 1)).play()
			combo.action_ended()
			_banner("")
			_set_active(null)
			_refresh_status()
			i = j + 1
			continue
		match l.type:
			"action":
				if acting:
					await _finish_action(started)
				started = Engine.get_physics_frames()
				_raven_action_serial += 1
				_raven_hits = logs.slice(i).filter(func(x): return x.type == "hit" and is_same(x.get("user"), l.user) and int(x.skill.get("id", 0)) == int(l.skill.get("id", 0)))
				acting = true
				combo.action_started()
				var s: XBattlerSprite = sprites[l.user]
				_log_action(l.skill)
				if l.user is XActor:
					_set_active(l.user)
				if XSukunaFx.shrine_action(l):
					await _sukuna_fx("shrine")
					started = Engine.get_physics_frames()
				await _wait_frames(ACT_MOTION_FRAMES)
				if l.user is XActor:
					_perform_action(l.user, l.skill)
				else:
					# MV Game_Enemy.performAction：白色闪一下
					s.flash(Color(1, 1, 1))
				await _wait_frames(ACT_HIT_FRAMES)
			"hit":
				if l.has("garou_trigger"):
					_log_add_action(l.skill)  # 饿狼 G.trigger 追击／反击：displayAction 加一行技能名，再放动画、弹伤害
				await _show_hit(l)
			"toast":
				XToast.show_text(str(l.text))
			"mastery_up":
				_start_animation(int(l.animation), l.target)  # YEP_SkillMasteryLevels onAllActionsEnd：升级动画（不镜像，不等）
			"se":
				play_se(l.se)
			"bgm":
				_change_bgm(l.bgm)
			"event_view":
				await _event_view(l)
			"movie":
				var movie := XMoviePlayer.start(str(l.name))   # 事件指令 261：放完再往下演（原版解释器等 video）
				if movie != null:
					await movie.finished
			"battle_text":
				_log_add(str(l.text))  # BattleManager._logWindow.push('addText')（宿傩「发动了神灶：开！」等）
				if l.has("sukuna_fx"):
					await _sukuna_fx(str(l.sukuna_fx))
			"enemy_change":
				if l.kind == "vanish":
					_apply_enemy_change(l)  # die＋hide（XPetCapture：逃跑；被捕的在公共事件 173 里，由 _play_troop_events 处理）
			"counter":
				# YEP Show Counter Text：日志「%1的反击！」
				_banner(str(XDB.system().terms.messages.counterAttack).replace("%1", l.user.display_name()))
				await _wait_frames(18)
			"reflect":
				# YEP Show Reflect Text：日志「%1反射了魔法！」
				_banner(str(XDB.system().terms.messages.magicReflection).replace("%1", l.target.display_name()))
				_start_animation(_reflect_animation(), l.target)
				await _wait_frames(12)
			"guard":
				sprites[l.user].set_motion("guard")
			"regen":
				if l.has("animation"):  # 状态 Regenerate 脚本（叠毒）的 target.startAnimation
					_start_animation(int(l.animation), l.target)
				if float(l.hp) != 0.0:
					_popup(l.target, float(l.hp), false)  # regen 记录与 hpDamage 同号：正伤害、负回复
				if float(l.get("mp", 0.0)) != 0.0:
					_popup(l.target, float(l.mp), false, "", true)
				if l.has("raven"):
					# 渡鸦 directDamage：startDamagePopup＋performDamage（敌人闪烁、角色受伤动作），再放收割／回响特效
					_perform_damage(l.target)
					_raven_fx(str(l.raven), l.target)
			"collapse":
				# 行动序列 IMMORTAL 解除时 HP 为 0 的倒下
				var cs: XBattlerSprite = sprites[l.target]
				if gauges.has(l.target):
					gauges[l.target].box.visible = false
					gauges[l.target].timer = 0.0
				await cs.collapse()
				if l.target is XEnemy:
					_enemy_collapsed(l.target)
			"guyu_visual":
				sprites[l.target].guyu_visual(str(l.kind))
			"skip":
				pass
		_refresh_status()
	if acting:
		await _finish_action(started)
	_banner("")
	_set_active(null)
	clear_views()
	for s in sprites.values():
		s.position = s.home


## 行动收尾：到第 41 帧清日志、第 52 帧结束（已超过就不再等）。
func _finish_action(started: int) -> void:
	await _wait_frames(started + ACT_LOG_FRAMES - Engine.get_physics_frames())
	_banner("")
	await _wait_frames(started + ACT_END_FRAMES - Engine.get_physics_frames())
	combo.action_ended()


## MV Game_Actor.performAction：物品 item、普通攻击按武器（YEP_WeaponAnimation）、防御 guard、魔法 spell、其余 skill。
func _perform_action(a: XActor, skill: Dictionary) -> void:
	var s: XBattlerSprite = sprites[a]
	if XBattleLogic.is_item(skill):
		s.set_motion("item")
	elif a.is_attack(skill):  # action.isAttack()：替换后的技能也按武器动作
		var v := a.attack_visual()
		s.set_motion("swing" if XAppearance.cat_visual(a) else v.motion)  # installNativeCharacterVisualRuntime performAttack：小猫剑圣原动作之后再要挥舞
		if int(v.image) > 0:
			s.start_weapon(int(v.image))
	elif int(skill.id) == XBattleLogic.GUARD_SKILL:
		s.set_motion("guard")
	else:
		# Game_Action.isMagicSkill：技能类型在 System.magicSkills 里
		var magic: Array = XDB.system().get("magicSkills", [])
		s.set_motion("spell" if magic.has(int(skill.get("stypeId", 0))) or magic.has(float(skill.get("stypeId", 0))) else "skill")
	var xt := XXuanTusuArt.motion_for(a, skill)  # ArtPack performAction 包装：专属技能绑定动作（盖在上面）
	if xt != "":
		s.set_motion(xt)
	XXuanTusuArt.note_cast(a, skill)
	# 谷雨 performAction 包装（原 performAction 之后）：五个主动技换自己的动作（治疗 spell、花期 chant、转移 item、花荫 guard、终结 skill）
	var own := XGuyu.action_motion(a, skill)
	if own != "":
		s.set_motion(own)


func _reflect_animation() -> int:
	return int(XDB.plugin("YEP_BattleEngineCore").get("Reflect Animation", "0"))


func _show_hit(l: Dictionary) -> void:
	var t: XBattler = l.target
	var ts: XBattlerSprite = sprites[t]
	var anim_id := int(l.skill.animationId)
	# 普通攻击动画（-1）照 showAttackAnimation：双持角色两把武器的动画同时放
	var pairs := _attack_animations(l.user) if anim_id < 0 else [[anim_id, false]]
	var started := []
	if _raven_cast(l):  # 渡鸦 V.play：这几个技能换成矢量施放特效，同一次行动的其余目标画在同一组里
		pairs = []
		while raven_fx.busy():
			await get_tree().physics_frame
	for p in pairs:
		var a := _start_animation(p[0], t)
		if a:
			if p[1]:
				a.scale.x = -1.0
			started.append(a)
	for a in started:
		if is_instance_valid(a) and not a.is_queued_for_deletion():
			await a.done
	if _hit_visual(l):
		await ts.collapse()
		if t is XEnemy:
			_enemy_collapsed(t)
	await _wait_frames(13)


## 一次命中的画面（连击计数、伤害记录、伤害数字、闪烁/受伤/闪避动作、敌人血条）；倒下时返回 true（由调用方演倒下）
func _hit_visual(l: Dictionary) -> bool:
	var t: XBattler = l.target
	var ts: XBattlerSprite = sprites[t]
	var hit: bool = not (l.missed or l.evaded)
	show_views(l.get("views", {}))
	for p in l.get("toji_anims", []):
		var a := _start_animation(int(p[0]), t)  # 角色形象 apply 包装：甚尔武器库／反弹／游云追加段命中时 target.startAnimation(动画, false, 延迟)
		if a:
			a.wait = int(p[1])
	for p in l.get("state_anims", []):
		if sprites.has(p[1]):
			_start_animation(int(p[0]), p[1])  # 护盾 React：target.startAnimation（破盾动画，在本次弹字之前）
	for c in l.get("custom_popups", []):
		_custom_popup(c.target, str(c.text), int(c.format))  # 黑闪 announce：customPopup(label, 2)
		_log_add(str(c.log))  # _logWindow.push('addText', 名字＋打出了＋label)
	if t is XEnemy:
		boss_hp.applied(t, float(view(t).hp))  # MOG_BossHP：Game_Action.apply 记命中的 Boss
	combo.applied(l.user, t, hit, int(l.skill.get("damage", {}).get("type", 0)), float(l.hp) if float(l.hp) != 0.0 else float(l.mp))
	if record and hit:
		record.record(l.user, t, float(l.get("record_hp", l.hp)))
	if not hit:
		_popup(t, 0, false, "miss")
		ts.set_motion("evade")
	else:
		# 行动中途 startDamagePopup 拷下的弹字（死而复燃的回血、回蓝、TP），先于本次结果
		var started: Array = l.get("started_popups", [])
		var split: int = l.get("started_split", started.size())
		_show_result_popups(t, started.slice(0, split))
		# 轮回困难 Establish 的附加伤害：先于本次伤害各弹一次（gainHp＋startDamagePopup）
		for v in l.get("extra", []):
			_popup(t, float(v), false)
		# 弹的是 deselect 之前的结果（复活块清了结果槽，这一击的数字照弹），复活块自己的弹字跟在后面
		var shown: Dictionary = l.get("shown", {"hp": l.hp, "mp": l.mp, "tp": l.get("tp", 0.0)})
		# 本次结果的弹字行（popupQueue 中段，前后是行动中途拷下的弹字）
		var q: Array = l.get("popupQueue", [])
		var mid: Array = q.slice(split, q.size() - (started.size() - split))
		# hpAffected 时伤害为 0 也弹「0」（LGP startDamagePopup 按 hpAffected 拷 HP 行；正式版读数 s10250）
		if float(shown.hp) != 0.0 or l.has("popup_hp") or mid.any(func(row): return bool(row.get("hpAffected", false))):
			_popup(t, float(l.get("popup_hp", shown.hp)), l.critical)
			# MV performDamage：敌人闪烁（requestEffect blink），角色做受伤动作
			if float(shown.hp) > 0.0:
				_perform_damage(t)
		if float(shown.mp) != 0.0:
			_popup(t, float(shown.mp), false, "", true)
		if float(shown.tp) != 0.0:
			_popup(t, float(shown.tp), false, "", false, true)
		# 本次结果的状态行：不画，但占一帧队列
		for row in mid:
			if _is_status_row(row):
				_popup(t, 0, false, "state")
		_show_result_popups(t, started.slice(split))
		if t is XEnemy:
			_show_enemy_gauge(t)
	if sprites.has(l.user):
		_show_result_popups(l.user, l.get("user_popups", []))
		if l.get("user_died", false):
			_collapse_visual(l.user)
	for kind in l.get("raven_fx", []):
		# 渡鸦 Game_Action.apply 包装：神话封解 ring、伤害技能每次 slash；有施放特效的技能不再画（legacyFx 包装）
		if not (str(kind) in ["slash", "ring"] and _raven_styled(l)):
			_raven_fx(str(kind), t)
	if l.died:
		if gauges.has(t):
			gauges[t].box.visible = false
			gauges[t].timer = 0.0
		return true
	return false


## startDamagePopup 拷下的结果逐行弹（血、蓝、TP；状态行建一个不画的占位，见 XDamagePopup.setup_state）
func _show_result_popups(t: XBattler, rows: Array) -> void:
	for p in rows:
		if p.hpAffected:
			_popup(t, float(p.hpDamage), false)
		if float(p.mpDamage) != 0.0:
			_popup(t, float(p.mpDamage), false, "", true)
		if float(p.tpDamage) != 0.0:
			_popup(t, float(p.tpDamage), false, "", false, true)
		if _is_status_row(p):
			_popup(t, 0, false, "state")


## 弹数在原版 children 那次更新里被摘掉：紧跟其后加入的下一个弹数这一帧少更新一次（见 XDamagePopup.skip）
func _popup_removed(p: XDamagePopup) -> void:
	for i in range(p.get_index() + 1, fx.get_child_count()):
		var q := fx.get_child(i)
		if q is XDamagePopup and not q.is_queued_for_deletion():
			q.skip = 1
			return


static func _is_status_row(p: Dictionary) -> bool:
	return not (p.get("addedStates", []) as Array).is_empty() or not (p.get("removedStates", []) as Array).is_empty()


## MV Game_Battler.performDamage：敌人闪烁（requestEffect blink），角色做受伤动作
func _perform_damage(t: XBattler) -> void:
	if t is XEnemy:
		sprites[t].blink()
	else:
		sprites[t].set_motion("damage")


## 渡鸦 R.Fx.play：特效层在战场里、战斗者之上，第一次用时才建
func _raven_layer() -> XRavenFx:
	if raven_fx == null:
		raven_fx = XRavenFx.new()
		field.add_child(raven_fx)
	return raven_fx


func _raven_fx(kind: String, t: XBattler) -> void:
	_raven_layer().play(kind, sprites[t].position, t)


func _raven_styled(l: Dictionary) -> bool:
	return l.user is XActor and int(l.user.actor_id) == XRaven.ACTOR and XRavenFx.STYLES.has(int(l.skill.get("id", 0)))


## 这次行动的所有目标画一组（Window_BattleLog.showNormalAnimation 收到整个目标表），只留动画的第一个音效；放过返回真，其余目标返回真但不再放
func _raven_cast(l: Dictionary) -> bool:
	if not _raven_styled(l):  # 不看「显示技能动画」：开关在里层 startAnimation，V.play 在外层
		return false
	var key := [l.user, int(l.skill.id), _raven_action_serial]
	if _raven_cast_key == key:
		return true
	_raven_cast_key = key
	return raven_cast(l.user, l.skill, (_raven_hits if not _raven_hits.is_empty() else [l]).map(func(r): return r.target))


## CodexRavenEffects.play（installRavenSkillEffectsRuntime）：渡鸦放 10122～10127 时换成矢量施放特效，一次调用一组（目标去重、
## 每个目标脚下往上 clamp(高×0.45, 40, 100)），从施放者头上 48 处飞出；只留动画的第一个音效。不是渡鸦、技能没有样式、没有目标精灵返回假
## （照原动画）。行动序列的 showNormalAnimation（XSequencePlayer._normal_animation）与非序列的命中显示都走这里
func raven_cast(user, skill: Dictionary, targets: Array) -> bool:
	if not (user is XActor and int(user.actor_id) == XRaven.ACTOR and XRavenFx.STYLES.has(int(skill.get("id", 0)))):
		return false
	var spots := []
	var seen := []
	for t in targets:
		if seen.has(t) or not sprites.has(t):
			continue
		seen.append(t)
		var s: XBattlerSprite = sprites[t]
		spots.append(s.position - Vector2(0, clampf(s.height() * 0.45, 40.0, 100.0)))
	if spots.is_empty():
		return false
	var origin: Vector2 = sprites[user].position - Vector2(0, 48) if sprites.has(user) else Vector2(1280 * 0.67, 720 * 0.45)
	_raven_layer().play_cast(int(skill.id), spots, origin)
	for timing in XDB.rec("Animations", int(skill.animationId)).get("timings", []):
		var cue = timing.get("se")
		if cue is Dictionary and str(cue.get("name", "")) != "":
			play_se(cue)
			break
	return true


## 行动序列里的倒下：不等倒下演完（正式版 performCollapse 只启动效果，WAIT FOR EFFECT 才等）
func _collapse_visual(t: XBattler) -> void:
	if gauges.has(t):
		gauges[t].box.visible = false
		gauges[t].timer = 0.0
	var cs: XBattlerSprite = sprites[t]
	var finish := func():
		await cs.collapse()
		if t is XEnemy:
			_enemy_collapsed(t)
	finish.call()


## YEP_X_VisualStateFX：每个战斗者按当前状态的 <State Animation> 循环放动画（见 XVisualStateFx）。
## 号变了才换（含变 0 清掉）；播完同一帧接着播（updateLoop）；不透明度与可见跟着战斗者。不受"战斗技能动画"开关管（那是 Game_Battler.startAnimation 的开关，状态动画走 Sprite_Battler.startStateAnimation）。
var _state_anims := {}   # XBattler -> {"id": int, "node": MVAnimation}


func _update_state_animations() -> void:
	for b in sprites.keys():
		var s: XBattlerSprite = sprites[b]
		if not is_instance_valid(s):
			continue
		var want := XVisualStateFx.animation_id(b)
		var cur: Dictionary = _state_anims.get(b, {"id": 0, "node": null})
		if int(cur.id) != want:
			if cur.node != null and is_instance_valid(cur.node):
				(cur.node as MVAnimation).finish()
			cur = {"id": want, "node": null}
			if want > 0:
				var a := _start_animation(want, b, true)
				if a:
					a.external = true
					cur.node = a
			_state_anims[b] = cur
		var n = cur.node
		if n != null and is_instance_valid(n):
			var node := n as MVAnimation
			node.tick()
			if not node.playing():  # Sprite_StateAnimation.updateLoop → setupDuration：同一帧接着重播
				node.duration = node.anim.frames.size() * node.rate + 1
				node.frame = 0
			node.visible = s.visible and s.appeared
			node.modulate.a = s.seq_opacity / 255.0


## 关闭时连动画音效也跳过（正式版 Game_Battler.startAnimation 直接返回）。地图动画不受这个开关影响。
## state_ani＝状态循环动画（Sprite_Battler.startStateAnimation），不看这个开关
func _start_animation(id: int, target: XBattler, state_ani := false) -> MVAnimation:
	if id <= 0 or (not state_ani and not XConfig.flag("CombatSkillAnimation")):
		return null
	var data := XDB.rec("Animations", id)
	if not MVAnimation.usable(data):
		return null
	var ts: XBattlerSprite = sprites[target]
	# Sprite_Animation.updatePosition 用目标的帧高（_mainSprite／Sprite_Enemy.height，不含身体缩放）
	var place := func() -> Vector2:
		var h := ts.height() / ts.body_scale
		match int(data.get("position", 1)):
			0: return ts.position - Vector2(0, h)
			1: return ts.position - Vector2(0, h / 2.0)
			3: return BOX / 2.0
		return ts.position
	var a := MVAnimation.play(fx, id, place.call(), false, XConfig.battle_speed())
	if a:
		a.target = ts            # 目标闪光、隐藏作用在被打的战斗者上
		# updatePosition：每帧跟随目标；头上／中心的再随目标浮空、跳跃抬高（YEP_X_ActSeqPack2，见 XBattlerSprite.anim_lift）
		var pos := int(data.get("position", 1))
		a.follow = func() -> Vector2: return place.call() - Vector2(0, ts.anim_lift() if pos in [0, 1] else 0.0)
	return a


## Game_Actor.attackAnimationId1／2：weapons()[0] 的动画（空手 bareHandsAnimationId 1）与 weapons()[1] 的动画（没有为 0，不放）。
## YEP_WeaponAnimation 的 <Weapon Animation: x> 冻结数据里没有用到，不处理。敌人两个都是同一个攻击动画。
func _attack_animation_ids(u: XBattler) -> Array:
	if u is XActor:
		var weapons := (u as XActor).equip_list().filter(func(e): return e.kind == "weapon")
		if weapons.is_empty():
			return [1, 0]
		return [int(weapons[0].animationId), int(weapons[1].animationId) if weapons.size() > 1 else 0]
	var id := int(XDB.plugin("YEP_BattleEngineCore").get("Enemy Attack Animation", "1"))
	return [id, id]


## 普通攻击动画的 [[动画, 镜像]…]。角色：MV showActorAttackAnimation 武器 1 不镜像＋武器 2 镜像；
## MIRROR 时 YEP showActorAtkAniMirror 武器 1 镜像＋武器 2 不镜像（YEP_BattleEngineCore.js:5617）。
## 敌人只放 id1（侧视 showEnemyAttackAnimation 不镜像，MIRROR 时镜像）。
func _attack_animations(u: XBattler, mirror := false) -> Array:
	var ids := _attack_animation_ids(u)
	if u is XActor:
		return [[ids[0], mirror], [ids[1], not mirror]]
	return [[ids[0], mirror]]


func _attack_animation(u: XBattler) -> int:
	return _attack_animation_ids(u)[0]


## 伤害数字（XDamagePopup，LGP_BetterDamagePopup）。位置：敌人 = 脚底 + (0, −图高/2 + 16)（MOG Center Y-Axis），
## 角色 = 脚底；同一目标仍存活的回复弹数决定纵向锚点（XDamagePopup.anchor_y）。text: "miss" 显示 Miss。
const POPUP_Z := 7
var _popups := {}          # XBattler -> Array[XDamagePopup]


## 原版 Sprite_Battler.setupDamagePopup 每帧每个战斗者只取一个弹数（LGP popupQueue），同一次结算的几个弹数隔帧出、
## 多段技能各段按各自 ACTION EFFECT 当帧出；重制原来同帧全建、叠在一个位置（Kyo 11-06 实机 2）。POPUP_QUEUE = false 回到同帧全建。
static var POPUP_QUEUE := true
var _popup_queue := {}     # XBattler -> Array[参数]
var _popup_frame := {}     # XBattler -> 上次出弹数的物理帧


func _popup(b: XBattler, value: float, critical: bool, text := "", is_mp := false, is_tp := false) -> void:
	if not XConfig.flag("CombatDamageShow"):
		return
	if not sprites.has(b):
		return
	var args := [value, critical, text, is_mp, is_tp]
	if not POPUP_QUEUE:
		_spawn_popup(b, args)
		return
	var q: Array = _popup_queue.get(b, [])
	q.append(args)
	_popup_queue[b] = q
	if seq_player == null:
		flush_popups()  # 不在行动序列里（回合末再生、敌群事件等）：当场出，同一战斗者本帧已出过的排到下一帧


## 每物理帧在本帧结算之后（行动序列里由 XSequencePlayer 在 _step 后调；其它时候在 _physics_process）每个战斗者出一个
## 排队的弹数。先后照原版 Spriteset 里战斗者精灵的更新顺序（YEP 按画面 y 排，同 y 敌人在前），新弹数加进 Spriteset
## 的先后决定了谁被「摘掉后跳一次更新」影响（XDamagePopup.skip）。
func flush_popups() -> void:
	if not XConfig.flag("CombatDamageShow"):
		return  # LGP setupDamagePopup：伤害数字关着时不出，队列留着
	var now := Engine.get_physics_frames()
	var due := []
	for b in _popup_queue.keys():
		var q: Array = _popup_queue[b]
		if q.is_empty() or not sprites.has(b):
			_popup_queue.erase(b)
		elif _popup_frame.get(b, -1) != now:
			due.append(b)
	due.sort_custom(_sprite_order)
	for b in due:
		var q: Array = _popup_queue[b]
		_spawn_popup(b, q.pop_front())
		if q.is_empty():
			_popup_queue.erase(b)


func _sprite_order(a: XBattler, b: XBattler) -> bool:
	var ya: float = sprites[a].position.y
	var yb: float = sprites[b].position.y
	if ya != yb:
		return ya < yb
	if (a is XEnemy) != (b is XEnemy):
		return a is XEnemy
	var la: Array = logic.enemies if a is XEnemy else logic.actors
	return la.find(a) < la.find(b)


## 把排队的弹数全部出完（测试与战斗收尾用）
func drain_popups() -> void:
	for b in _popup_queue.keys():
		for args in _popup_queue[b]:
			if sprites.has(b):
				_spawn_popup(b, args)
	_popup_queue.clear()


func popups_pending() -> bool:
	return _popup_queue.values().any(func(q): return not q.is_empty())


func _spawn_popup(b: XBattler, args: Array) -> void:
	var value: float = args[0]
	var critical: bool = args[1]
	var text: String = args[2]
	var is_mp: bool = args[3]
	var is_tp: bool = args[4]
	_popup_frame[b] = Engine.get_physics_frames()
	var s: XBattlerSprite = sprites[b]
	var live: Array = _popups.get(b, []).filter(func(x): return is_instance_valid(x))
	var p := XDamagePopup.new()
	p.position = s.position + (Vector2.ZERO if b is XActor else Vector2(0, -s.height() / s.body_scale / 2.0 + 16))
	# 原版弹出数加在 Spriteset_Battle 里（LGP_BetterDamagePopup 第 665 行），在窗口层之下：在敌人血条（z 5）之上、行动顺序条／消息窗（z 8）与帮助卡（z 10）之下
	p.z_index = POPUP_Z
	if text == "state":
		p.setup_state()
	else:
		p.setup(value, is_mp, critical, text == "miss", b is XActor, live.filter(func(x): return x.is_heal()).size(), is_tp)
	fx.add_child(p)
	p.on_removed = _popup_removed
	# 原版 setupDamagePopup 建出的 Sprite_Damage 当帧就随父层更新一次（正式版读数首帧 [89, −0.3, 0.7]），之后每帧两次
	p._update()
	live.append(p)
	_popups[b] = live


## LGP customPopup(文字, 格式)：格式 2 伤害色、1 回复色，原地不动，最后 10 次淡出（设置「战斗伤害显示」关掉时不弹）
func _custom_popup(b: XBattler, text: String, format: int) -> void:
	if not XConfig.flag("CombatDamageShow"):
		return
	var s: XBattlerSprite = sprites[b]
	var p := XDamagePopup.new()
	p.position = s.position + (Vector2.ZERO if b is XActor else Vector2(0, -s.height() / s.body_scale / 2.0 + 16))
	p.z_index = POPUP_Z
	p.setup_custom(text, format)
	p.on_removed = _popup_removed
	fx.add_child(p)
	p._update()  # 同 _spawn_popup：建出当帧更新一次


## MOG_TrPopUpBattle：敌人倒下动画结束时抽定它的掉落（不论设置）；开着「掉落动画」就立即获得、弹出图标，
## 并锁住胜利时的物品发放（结算画面照样列出）。所以开着时，逃跑前打倒的敌人的掉落也会留下（同原版）。
func _enemy_collapsed(e: XEnemy) -> void:
	var drops := logic.drop_snapshot(e)
	if drops.is_empty() or not XConfig.flag("MOG_TrPopUpBattle_Key"):
		return
	var p := XDropPopup.new()
	p.setup(sprites[e], sprites[e].height(), drops.map(func(d): return XDB.rec(["", "Items", "Weapons", "Armors"][int(d.kind)], int(d.id))))
	field.add_child(p)


## BattleManager.endBattle：伤害记录随即移除（胜利时在结算镜头之前）
func _end_record() -> void:
	if record:
		remove_child(record)      # 先移出，胜利镜头收集子节点时不会收到待释放的记录窗
		record.queue_free()
		record = null


## 胜利：先发放一次奖励，再放大胜利镜头，最后显示 Olivia 的结算布局。
func _victory() -> void:
	boss_hp.ended()
	_close_windows()
	_end_record()
	for a in logic.alive(logic.actors):
		sprites[a].set_motion("victory")
	var before := {}
	for a in logic.actors:
		before[a] = {"exp": a.exp_total, "level": a.level}
	var r := logic.rewards()
	logic.grant(r)
	XEnemyBook.on_battle_end(XState.current, book_appeared, logic.enemies)
	logic.end_battle(0)
	var params := XDB.plugin("Olivia_VictorySequenceUI")
	# Olivia BattleManager.processVictory：playVictoryMe（Victory2）再 playVictoryBgm（Ship3）。ME 在放时 AudioManager.playBgm
	# 只换上新曲、不开始放（!this._meBuffer），等 ME 放完 stopMe 从头放、0.5 秒淡入；没有 ME 时直接放
	play_me(XDB.system().get("victoryMe", {}))
	XAudio.stop_fade(bgm)
	bgm.stop()
	bgm.stream_paused = false
	var music := XDB.audio_path("bgm", str(params.get("Victory Screen BGM", "Ship3")))
	if music != "":
		bgm.stream = XAppearance.kept_load(music)
		bgm.volume_db = linear_to_db(float(params.get("Victory Screen BGM Volume", 90)) / 100)
		bgm.set_meta("bgm_name", str(params.get("Victory Screen BGM", "Ship3")))
		_bgm_after_me = true
		if not me.playing:
			bgm.play()
	else:
		bgm.stream = null
	# 胜利镜头（YEP_X_ActSeqPack3 战斗镜头）：镜头点从画面中心 (640,360) 移到 (700,460)、放大 1→2，
	# 都在 300 帧内线性完成；场景层位置 = −镜头点×放大 + 画面中心，并夹在放大后的画面内。结算文字不缩放。
	# 行动序列镜头还没复位完时先归位，胜利镜头从原始画面开始
	for visual in _cam_base:
		if is_instance_valid(visual):
			visual.position = _cam_base[visual]
			visual.scale = Vector2.ONE
	camera = XBattleCamera.new()
	camera.sprites = sprites
	if str(params.get("Victory Screen Zoom", "true")) == "true":
		_camera = {"from": BOX / 2.0, "to": Vector2(float(params.get("Victory Screen Zoom X", 700)), float(params.get("Victory Screen Zoom Y", 460))),
			"scale": float(params.get("Victory Screen Zoom Scale", 2)), "frames": int(params.get("Victory Screen Zoom Duration", 300)), "t": 0, "base": {}}
		for visual in get_children():
			if visual != ui and visual != low_ui and visual != record and (visual is Control or visual is Node2D):
				_camera.base[visual] = visual.position
	await get_tree().create_timer(float(params.get("Victory Screen Hide Window Delay", 500)) / 1000).timeout
	for node in ui.get_children():
		if node is CanvasItem:
			node.hide()
	low_ui.hide()
	await get_tree().create_timer(maxf(0, float(params.get("Victory Screen Display Delay", 1000)) / 1000 - float(params.get("Victory Screen Hide Window Delay", 500)) / 1000)).timeout
	# 挂机中：Window_BattleVictoryActorSub 一建出就把 _victoryPhase 设回 false，结算画面不出现、直接回地图
	if XHangUp.is_active(XState.current):
		return
	var screen := XVictoryScreen.new()
	screen.setup(r, before, logic.actors, logic.auto)
	ui.add_child(screen)
	await screen.continued
	await victory_messages()


## 胜利后要提示的文字（饿狼「获得神之触媒」等，logic.victory_texts）。优化 O-190（ui11）：原版在结算画面期间塞进
## 战斗日志，只露约半秒、还吞掉一次确定（battlelog2）；这里改成结算画面关掉后用消息窗正常显示一次，按确定关。
## VICTORY_TEXT_MESSAGE = false 回到重制原来的样子（不显示）。挂机直接回地图时不弹（不打断挂机）。
static var VICTORY_TEXT_MESSAGE := true


func victory_messages() -> void:
	if not VICTORY_TEXT_MESSAGE or logic.victory_texts.is_empty():
		return
	message.visible = true
	for t in logic.victory_texts:
		await message.run({"lines": [str(t)]})


## 事件指令 250 播放音效（战斗里的公共事件）：同地图 XMapScene.play_se，音量／音调不读
func play_se(audio) -> void:
	var p := XDB.audio_path("se", str(audio.get("name", ""))) if audio is Dictionary else ""
	if p != "" and se:
		se.stream = load(p)
		se.play()
