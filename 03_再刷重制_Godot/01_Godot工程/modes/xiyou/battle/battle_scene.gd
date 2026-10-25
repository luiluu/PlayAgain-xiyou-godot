class_name XBattleScene
extends Control
## 侧视战斗画面，照原版界面（用户 2026-10-12 要求「界面风格用原版界面风格」）：
## - 布局按 Olivia_SideBattleUI：我方站位 x = 宽/2+128+序号×64、y = 高-235-(5-序号-1)×48；
##   右侧每人一条状态（缩放 0.6：名字、HP/MP/TP 量条、左侧状态图标，轮到谁谁左移 48）；
##   指令窗（宽 220、缩放 0.8）出现在行动角色身旁，技能/物品列表（宽 450）在其右下；
##   选中技能/物品时在列表左侧显示 HelpExtend 说明卡（XHelpCard；原版没有顶部说明栏）。
## - 敌人在敌群编辑器坐标（原版 1280×720 原样使用），1 倍大小，神话 1.8 倍并偏色；
##   YEP_X_VisualHpGauge：敌人脚下 12px 粗血条（受伤或选目标时显示，带数值）。
## - 伤害数字照 LGP_BetterDamagePopup 文字弹出（XDamagePopup）。
## - Olivia_BattleSysOTB：行动顺序回合制，轮到谁谁当场选指令；画面下方是行动顺序条（XOTBBar），
##   指令窗里有「逃跑」，没有队伍指令窗，取消不能回到上一人。
## 规则在 XBattleLogic；结束时发出 finished(0 胜利 / 1 逃跑 / 2 战败)。

signal finished(result: int)
signal _picked(value)

const BOX := Vector2(1280, 720)           # 原版画面尺寸（坐标基准）
const STATUS_SCALE := 0.6
const STATUS_W := 200.0
const STATUS_MOVE := 48.0
const CMD_W := 220.0
const CMD_SCALE := 0.8
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
var combo: XComboCounter
var record: XDamageRecord
var ui: Control
## 战斗中的消息窗（BattleManager 的逃跑信息等走 $gameMessage，Scene_Battle 的 Window_Message）
var message: XMessageBox
var help_card: XHelpCard
var log_canvas: XMVCanvas
var _log_lines: Array = []        # [{text, simple}]
var otb: XOTBBar
var cmd_win: XBattleList
var list_win: XBattleList
var auto_btn: Button
var speed_btn: Button
var bgm: AudioStreamPlayer
var se: AudioStreamPlayer
var _target_mode := ""            # "enemy" / "ally" / ""
var _target_pool: Array = []
var _target_skill: Dictionary = {}
var _hover = null
var _active: XActor = null
var _origin := Vector2.ZERO       # 原版坐标 → 画面坐标的偏移
var _camera := {}                 # 胜利镜头（见 _victory）
## YEP_X_ActSeqPack3 战斗镜头（行动序列的 CAMERA/ZOOM）；_cam_base 是各画面层的原始位置
var camera := XBattleCamera.new()
var _cam_base := {}
var _cam_applied := false
## 正在演出的行动序列（它自己逐帧推进镜头）
var seq_player: XSequencePlayer
## 自动测试用：强制自动战斗，胜利界面自动关闭。
static var force_auto := false
## 怪物图鉴（AB_EnemyBook ResisterTiming 2）本场出现过的敌人 ID：战斗结束时登记
var book_appeared: Array = []
## 战斗内「怪物信息」（AB_EnemyBook，Shift 打开；见 _open_battle_book）
var book_page: XEnemyBookPage


func setup(troop: int, escape: bool, lose: bool, map: Dictionary, background: Texture2D = null) -> void:
	troop_id = troop
	snapshot = background
	can_lose = lose
	map_data = map
	logic.can_escape = escape
	logic.setup(troop, XState.current)
	XPetCapture.roll_battle(logic)  # Star_PetSystem 的 Scene_Battle.start 包装：掷可捕捉（名字加「宝宝」）
	logic.auto = force_auto
	book_appeared = XEnemyBook.on_battle_start(XState.current, troop, map, logic.enemies)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vs := get_viewport_rect().size
	_origin = Vector2((vs.x - BOX.x) / 2.0, (vs.y - BOX.y) / 2.0)
	_build_background()
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
		if visual != ui and visual != record and (visual is Control or visual is Node2D):
			_cam_base[visual] = visual.position
	bgm = AudioStreamPlayer.new()
	XAudio.bind(bgm, "BGM")
	add_child(bgm)
	se = AudioStreamPlayer.new()
	XAudio.bind(se, "SE")
	add_child(se)
	var music: Dictionary = XDB.system().battleBgm
	if XState.current and not XState.current.battle_bgm.is_empty():
		music = XState.current.battle_bgm    # 指令 132（深渊封印战斗前后换歌）
	var p := XDB.audio_path("bgm", str(music.name))
	if p != "":
		bgm.stream = load(p)
		bgm.volume_db = linear_to_db(float(music.volume) / 100.0)
		bgm.play()
	_main.call_deferred()


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
		t.texture = load(p)
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(t)


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
	s.setup(e, 1.8 if e.elite else 1.0)
	s.breathing = true
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
	gauges[e] = {"box": c, "timer": 0.0, "name_timer": 3.0, "cur": e.hp, "disp": e.hp, "drop": 0.0}
	c.painter = func(canvas): _paint_enemy(canvas, e)


## Olivia WeaknessDisplay 名字与 YEP VisualHpGauge 是两个独立窗口。
## 名字居中在 (敌人 x, y−27) 的 640×72 内容位图；HP 内容 (x−90,y−16)，字号 26、居中、12px 粗条。
func _paint_enemy(c: XMVCanvas, e: XEnemy) -> void:
	var g: Dictionary = gauges[e]
	var v := view(e)
	var rate: float = v.hp / maxf(v.mhp, 1.0)
	if not v.dead and (g.name_timer > 0.0 or e == _hover):
		var color := _enemy_name_color(e) if rate > 0.5 else XUI.text_color(2 if rate > 0.25 else 10)
		c.text(e.display_name(), 0, 0, 640, "center", color, 18, 36)
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
	_refresh_status()
	# 自动/加速：左上角小窗，避免挡住 OTB（优化 O-006）；让出左上 (20,10,240,74) 给挂机快捷界面。
	var side := HBoxContainer.new()
	side.position = _origin + Vector2(272, 12)
	side.add_theme_constant_override("separation", 8)
	ui.add_child(side)
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


func _small_button(text: String) -> Button:
	var b := XUI.button(text, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", XUI.panel())
	b.custom_minimum_size.x = 120
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
	help_card.show_for(entry)
	ui.move_child(help_card, -1)
	# 选中行：纵向取该行，横向取整个列表窗口（卡片外发光不压到窗口边框）
	var row := Rect2(list_win.position - _origin + Vector2(0, list_win.padding + (list_win.index - list_win.top) * XBattleList.LH),
		Vector2(list_win.size.x, XBattleList.LH))
	help_card.place_for_row(row, true)
	help_card.position += _origin


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
		var hp: float = view(e).hp
		if hp != g.cur:
			g.cur = hp
			g.drop = ceilf(absf(g.disp - hp) / dur)
		if g.disp > g.cur:
			g.disp = maxf(g.disp - g.drop, g.cur)
		elif g.disp < g.cur:
			g.disp = minf(g.disp + g.drop, g.cur)


func _physics_process(_delta: float) -> void:
	if seq_player == null:
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
	for e in gauges:
		var g: Dictionary = gauges[e]
		g.box.position = sprites[e].position + Vector2(-320, -27)
		g.timer = maxf(0, g.timer - delta)
		g.name_timer = maxf(0, g.name_timer - delta)
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
	var first := true
	# 敌群事件：开战（第 0 回合）检查一次
	await _play_troop_events(logic.troop_events())
	while true:
		logic.start_turn()
		if not first:
			otb.advance_turn()
		otb.show_orders(logic.current_order, logic.next_order, first)
		first = false
		# XdRs_HangUp 的 updateTurn：挂机逃跑条件成立就 processEscape（逃跑率 1）
		if XHangUp.should_escape(XState.current, logic.enemies):
			await _escape_success()
			return
		var turn_first := true
		while not logic.is_won() and not logic.is_lost():
			var u := logic.next_subject()
			# 每位行动之前（及最后一人之后）检查敌群事件；回合首位已在 OTB startTurn 取出
			await _play_troop_events(logic.troop_events(u if turn_first else null))
			turn_first = false
			if u == null or logic.is_won() or logic.is_lost():
				break
			otb.on_subject(u)
			otb.show_orders(logic.current_order, logic.next_order)
			var cmd = [null, null] if logic.cleared_action(u) else await _command(u)
			if cmd is String and cmd == "escaped":
				return
			_close_windows()
			_set_active(null)
			var logs := logic.act(u, cmd[0], cmd[1])
			await _play(logs)
			otb.clear_subject()
			otb.show_orders(logic.current_order, logic.next_order)
			_refresh_status()
		if logic.is_won():
			otb.hide_bar()
			await _victory()
			finished.emit(0)
			return
		if logic.is_lost():
			otb.hide_bar()
			_end_record()
			# 快速战斗只跳过失败信息（见 XHangUp）
			if not XHangUp.fast_fighting(XState.current):
				await _say("全军覆没……", 1.2)
			XEnemyBook.on_battle_end(XState.current, book_appeared, logic.enemies)
			logic.end_battle(2)
			# MV updateBattleEnd：允许失败时，只将阵亡出战成员复活到 1 HP。
			if can_lose:
				for member in XState.current.battle_members():
					if member.is_dead():
						member.hp = 1.0
						member.refresh_resources()
			finished.emit(2)
			return
		await _play(logic.end_turn())
		await _play_troop_events(logic.troop_events(null, true))
		otb.show_orders(logic.current_order, logic.next_order)
		_refresh_status()
		# 全员不能行动时也交还一帧，保留自动/速度按钮与窗口响应。
		await get_tree().process_frame


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
func _escape_success() -> void:
	_close_windows()
	_end_record()
	otb.hide_bar()
	logic.escaped = true
	XSound.system(8)
	await message.run({"lines": [escape_text()]})
	XEnemyBook.on_battle_end(XState.current, book_appeared, logic.enemies)
	logic.end_battle(1)
	finished.emit(1)


## 逃跑失败：逃跑音效，消息窗两行「<队名>开始逃跑了！」「\.但是没有逃跑成功！」，等按键后这次行动结束（OTB endAction）
func _escape_failure() -> void:
	XSound.system(8)
	await message.run({"lines": [escape_text(), "\\." + str(XDB.system().terms.messages.escapeFailure)]})


## TextManager.escapeStart.format($gameParty.name())：出战 1 人时为其名字，否则 partyName「%1的队伍」
func escape_text() -> String:
	var leader: XActor = logic.actors[0] if not logic.actors.is_empty() else null
	var name := "" if leader == null else (leader.display_name() if logic.actors.size() == 1 else str(XDB.system().terms.messages.get("partyName", "%1的队伍")).replace("%1", leader.display_name()))
	return str(XDB.system().terms.messages.escapeStart).replace("%1", name)


## 轮到 u：敌人/自动/不能行动时直接决定；角色由玩家选。逃跑在这里处理，成功时结束战斗并返回 "escaped"。
func _command(u: XBattler):
	# 挂机中队员按自动战斗行动（Game_BattlerBase.isAutoBattle）
	if u is XActor and logic.can_move(u) and XHangUp.is_active(XState.current):
		# 技能顺序表／智能战斗AI（XBattleLogic.auto_battle_action）
		return logic.auto_battle_action(u)
	if not (u is XActor) or logic.auto or not logic.can_move(u):
		return logic.decide(u)
	_set_active(u)
	while true:
		var r = await _command_for(u)
		if logic.auto or (r is String and r == "auto"):
			_close_windows()
			return logic.decide(u)
		if r is Array:
			return r
		if r is String and r == "escape":
			_close_windows()
			if logic.try_escape():
				await _escape_success()
				return "escaped"
			await _escape_failure()
			return [null, null]
		# "back"：OTB 没有队伍指令窗，取消不回到上一人，重新显示指令
	return null


func _close_windows() -> void:
	for w in [cmd_win, list_win]:
		if w and is_instance_valid(w):
			w.queue_free()
	cmd_win = null
	list_win = null
	_help()
	otb.clear_preview()


## 选指令时预览：自己下个回合的位置（技能速度＋OTB User Next Turn），以及选中目标的位移。
func _preview(a: XBattler, skill, targets: Array = []) -> void:
	if skill == null:
		otb.clear_preview()
		return
	var entries := []
	if not XBattleLogic.is_item(skill):
		entries.append([a, "n", logic.next_order, int(skill.get("speed", 0)) + XBattleLogic._note_int(skill, "OTB User Next Turn"), logic._speed])
	var cur := XBattleLogic._note_int(skill, "OTB Target Current Turn")
	var nxt := XBattleLogic._note_int(skill, "OTB Target Next Turn")
	if not str(skill.get("note", "")).contains("<OTB Target Next Turn:"):
		for eff in skill.get("effects", []):
			if int(eff.code) == 31 and int(eff.dataId) == XBattleLogic.AGI_PARAM:
				nxt += 1
				break
	var follow := XBattleLogic._note_int(skill, "OTB Target Follow Turn")
	for t in targets:
		if logic._speed.get(t, 0.0) == INF:
			continue
		var c := cur + (follow if logic.current_order.has(t) else 0)
		var n := nxt + (0 if logic.current_order.has(t) else follow)
		entries.append([t, "c", logic.current_order, c, logic._speed])
		entries.append([t, "n", logic.next_order, n, logic._speed])
	otb.set_preview(entries)


## 指令（Window_ActorCommand＋OTB）：攻击、加入的技能类型（按编号；CP_MagicWeapon 不列 3～6，没有该类技能也列出）、
## 防御、物品、逃跑（OTB Escape Actor Window：总是列出，不能逃时灰显）。
func _command_entries(a: XActor) -> Array:
	var terms: Array = XDB.system().terms.commands
	var atk := XDB.rec("Skills", XBattleLogic.ATTACK_SKILL)
	var grd := XDB.rec("Skills", XBattleLogic.GUARD_SKILL)
	var opts := [{"text": str(terms[2]), "key": "attack", "enabled": logic.can_use(a, atk), "preview": atk}]
	var stypes: Array = XDB.system().skillTypes
	var added := a.traits_set(XBattler.TRAIT_STYPE_ADD)
	added.sort()
	for t in added:
		if not [3, 4, 5, 6].has(int(t)) and int(t) < stypes.size():
			opts.append({"text": str(stypes[int(t)]), "key": "stype:%d" % int(t)})
	opts.append({"text": str(terms[3]), "key": "guard", "enabled": logic.can_use(a, grd), "preview": grd})
	opts.append({"text": str(terms[4]), "key": "item"})
	opts.append({"text": str(terms[1]), "key": "escape", "enabled": logic.can_escape})
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
			var action = await _pick_action_list(a, logic.battle_skills(a).filter(func(x): return int(x.stypeId) == int(pick.substr(6))), false)
			if logic.auto:
				return "auto"
			if action is Array:
				return action
			continue
		match pick:
			"attack":
				var atk := XDB.rec("Skills", XBattleLogic.ATTACK_SKILL)
				var t = await _pick_target(atk, a)
				if logic.auto:
					return "auto"
				if t != null:
					return [atk, t]
			"guard":
				return [XDB.rec("Skills", XBattleLogic.GUARD_SKILL), null]
			"escape":
				return "escape"
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
		# Scene_Battle.onSkillOk/onItemOk：先记选择，再选目标；取消目标也保留。
		if items:
			logic.state.last_item = int(entry.id)
		else:
			a.last_battle_skill = int(entry.id)
		var target = await _pick_target(entry, a)
		if target != null:
			return [entry, target]
	return null


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
		var c := logic.skill_cost(a, e)
		if c.tp > 0:
			row.costs.append({"text": "%sTP" % XMenu._group(c.tp), "color": XUI.text_color(29), "icon": 1268})
		if c.mp > 0:
			row.costs.append({"text": "%sMP" % XMenu._group(c.mp), "color": XUI.text_color(23), "icon": 1269})
	return row


static func item_list_row(s: XState, e: Dictionary, enabled: bool) -> Dictionary:
	return {"text": str(XItemMarks.decorate(s, e).name), "icon": int(e.get("iconIndex", 0)), "enabled": enabled, "reserve": "×0,000",
		"costs": [{"text": "×" + XMenu._group(s.item_count(int(e.id))), "size": 20}]}


## Window_BattleSkill / Window_BattleItem（宽 450、最多 16 行），贴在角色旁 (+16, +16)。
func _pick_from_list(a: XActor, entries: Array, items: bool, initial_index := 0):
	_close_list()
	var rows := entries.map(func(e): return _list_entry(a, e, items))
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
		if r is Dictionary:
			_close_list()
			return r
		if r is String and (r == "cancel" or r == "back" or r == "auto"):
			_close_list()
			if cmd_win:
				cmd_win.active = true
			return null


func _close_list() -> void:
	if list_win and is_instance_valid(list_win):
		list_win.queue_free()
	list_win = null
	_help()


## 单体技能：点敌人（或我方）选目标；全体/自身直接返回占位目标。
func _pick_target(skill: Dictionary, a: XActor):
	var scope := int(skill.get("scope", 1))
	if not [1, 7, 9].has(scope):
		return a
	var pool := logic.alive(logic.enemies) if scope == 1 else (logic.alive(logic.actors) if scope == 7 else logic.actors.filter(func(x): return x.is_dead()))
	if pool.is_empty():
		return null
	_target_mode = "enemy" if scope == 1 else "ally"
	_target_pool = pool
	if cmd_win and is_instance_valid(cmd_win):
		cmd_win.visible = false
	_help()
	_target_skill = skill
	# YEP Enemy Auto Select = furthestRight；我方默认第一人。
	var initial = pool[0]
	if scope == 1:
		for b in pool:
			if sprites[b].home.x > sprites[initial].home.x:
				initial = b
	_select_target(initial)
	var r = await _picked
	_target_mode = ""
	_target_pool = []
	_target_skill = {}
	_select_target(null)
	otb.clear_preview()
	_help()
	if cmd_win and is_instance_valid(cmd_win):
		cmd_win.visible = true
	if r is XBattler and pool.has(r):
		return r
	return null


func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.INF
	if event is InputEventMouseMotion and _target_mode != "":
		# 鼠标指向的候选目标视为「被选中」：顺序条上放大闪烁，并预览位移
		var h = _nearest_target(event.position)
		if h != null and h != _hover:
			_select_target(h)
		return
	if event is InputEventMouseButton and event.pressed:
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


func _select_target(b) -> void:
	_hover = b
	for actor in status_rows:
		status_rows[actor].selected = actor == b
	for who in sprites:
		var s: XBattlerSprite = sprites[who]
		if s.selected and who.is_alive():
			s.sprite.modulate = Color.WHITE
		s.selected = who == b
	otb.set_selected([b] if b != null else [])
	if b != null:
		_preview(_active, _target_skill, [b])


func _unhandled_input(event: InputEvent) -> void:
	if book_page != null:
		return
	# AB_EnemyBook v1.28：角色指令窗、技能／物品列表开着且可操作时按 Shift（ShortCutButtonName）打开「怪物信息」
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SHIFT and _target_mode == "" and not logic.auto:
		var w: XBattleList = list_win if list_win != null and list_win.active else (cmd_win if cmd_win != null and cmd_win.active else null)
		if w != null and w.is_visible_in_tree():
			get_viewport().set_input_as_handled()
			_open_battle_book(w)
			return
	if _target_mode != "":
		var i := _target_pool.find(_hover)
		if event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_down", true):
			_select_target(_target_pool[(i + 1) % _target_pool.size()])
		elif event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_up", true):
			_select_target(_target_pool[posmod(i - 1, _target_pool.size())])
		elif event.is_action_pressed("ui_accept"):
			_picked.emit(_hover)
		elif event.is_action_pressed("ui_cancel"):
			_picked.emit("cancel")
		else:
			return
		get_viewport().set_input_as_handled()
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
		if l.type == "action" and i < logs.size() and str(logs[i].type) == "seq_phase":
			if acting:
				await _finish_action(started)
				acting = false
			var j := i
			while j < logs.size() and logs[j].type != "seq_end":
				j += 1
			combo.action_started()
			if l.user is XActor:
				_set_active(l.user)
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
				acting = true
				combo.action_started()
				var s: XBattlerSprite = sprites[l.user]
				_log_action(l.skill)
				if l.user is XActor:
					_set_active(l.user)
				await _wait_frames(ACT_MOTION_FRAMES)
				if l.user is XActor:
					_perform_action(l.user, l.skill)
				else:
					# MV Game_Enemy.performAction：白色闪一下
					s.flash(Color(1, 1, 1))
				await _wait_frames(ACT_HIT_FRAMES)
			"hit":
				await _show_hit(l)
				if l.has("events"):
					await _play(l.events)  # 捕捉道具的公共事件 173（XPetCapture）：提示与被捕的敌人隐藏
			"toast":
				XToast.show_text(str(l.text))
			"enemy_change":
				if l.kind == "vanish":
					_apply_enemy_change(l)  # die＋hide（XPetCapture：被捕或逃跑）；335／336 由 _play_troop_events 先处理
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
					_popup(l.target, -float(l.hp), false)
			"collapse":
				# 行动序列 IMMORTAL 解除时 HP 为 0 的倒下
				var cs: XBattlerSprite = sprites[l.target]
				if gauges.has(l.target):
					gauges[l.target].box.visible = false
					gauges[l.target].timer = 0.0
				await cs.collapse()
				if l.target is XEnemy:
					_enemy_collapsed(l.target)
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
	elif int(skill.id) == XBattleLogic.ATTACK_SKILL:
		var v := a.attack_visual()
		s.set_motion(v.motion)
		if int(v.image) > 0:
			s.start_weapon(int(v.image))
	elif int(skill.id) == XBattleLogic.GUARD_SKILL:
		s.set_motion("guard")
	else:
		# Game_Action.isMagicSkill：技能类型在 System.magicSkills 里
		var magic: Array = XDB.system().get("magicSkills", [])
		s.set_motion("spell" if magic.has(int(skill.get("stypeId", 0))) or magic.has(float(skill.get("stypeId", 0))) else "skill")


func _reflect_animation() -> int:
	return int(XDB.plugin("YEP_BattleEngineCore").get("Reflect Animation", "0"))


func _show_hit(l: Dictionary) -> void:
	var t: XBattler = l.target
	var ts: XBattlerSprite = sprites[t]
	var anim_id := int(l.skill.animationId)
	# 普通攻击动画（-1）照 showAttackAnimation：双持角色两把武器的动画同时放
	var pairs := _attack_animations(l.user) if anim_id < 0 else [[anim_id, false]]
	var started := []
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
	combo.applied(l.user, t, hit, int(l.skill.get("damage", {}).get("type", 0)), float(l.hp) if float(l.hp) != 0.0 else float(l.mp))
	if record and hit:
		record.record(l.user, t, float(l.get("record_hp", l.hp)))
	if not hit:
		_popup(t, 0, false, "miss")
		ts.set_motion("evade")
	else:
		# 轮回困难 Establish 的附加伤害：先于本次伤害各弹一次（gainHp＋startDamagePopup）
		for v in l.get("extra", []):
			_popup(t, float(v), false)
		if float(l.hp) != 0.0 or l.has("popup_hp"):
			_popup(t, float(l.get("popup_hp", l.hp)), l.critical)
			# MV performDamage：敌人闪烁（requestEffect blink），角色做受伤动作
			if float(l.hp) > 0.0:
				if t is XEnemy:
					ts.blink()
				else:
					ts.set_motion("damage")
		if float(l.mp) != 0.0:
			_popup(t, float(l.mp), false, "", true)
		if float(l.get("tp", 0.0)) != 0.0:
			_popup(t, float(l.tp), false, "", false, true)
		if t is XEnemy:
			_show_enemy_gauge(t)
	if l.died:
		if gauges.has(t):
			gauges[t].box.visible = false
			gauges[t].timer = 0.0
		return true
	return false


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


## 关闭时连动画音效也跳过（正式版 Game_Battler.startAnimation 直接返回）。地图动画不受这个开关影响。
func _start_animation(id: int, target: XBattler) -> MVAnimation:
	if id <= 0 or not XConfig.flag("CombatSkillAnimation"):
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


func _popup(b: XBattler, value: float, critical: bool, text := "", is_mp := false, is_tp := false) -> void:
	if not XConfig.flag("CombatDamageShow"):
		return
	var s: XBattlerSprite = sprites[b]
	var live: Array = _popups.get(b, []).filter(func(x): return is_instance_valid(x))
	var p := XDamagePopup.new()
	p.position = s.position + (Vector2.ZERO if b is XActor else Vector2(0, -s.height() / s.body_scale / 2.0 + 16))
	# 原版弹出数加在 Spriteset_Battle 里（LGP_BetterDamagePopup 第 665 行），在窗口层之下：在敌人血条（z 5）之上、行动顺序条／消息窗（z 8）与帮助卡（z 10）之下
	p.z_index = POPUP_Z
	p.setup(value, is_mp, critical, text == "miss", b is XActor, live.filter(func(x): return x.is_heal()).size(), is_tp)
	fx.add_child(p)
	live.append(p)
	_popups[b] = live


func _say(text: String, seconds: float) -> void:
	_banner(text)
	await get_tree().create_timer(seconds).timeout
	_banner("")


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
	bgm.stop()
	var music := XDB.audio_path("bgm", str(params.get("Victory Screen BGM", "Ship3")))
	if music != "":
		bgm.stream = load(music)
		bgm.volume_db = linear_to_db(float(params.get("Victory Screen BGM Volume", 90)) / 100)
		bgm.play()
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
			if visual != ui and visual != record and (visual is Control or visual is Node2D):
				_camera.base[visual] = visual.position
	await get_tree().create_timer(float(params.get("Victory Screen Hide Window Delay", 500)) / 1000).timeout
	for node in ui.get_children():
		if node is CanvasItem:
			node.hide()
	await get_tree().create_timer(maxf(0, float(params.get("Victory Screen Display Delay", 1000)) / 1000 - float(params.get("Victory Screen Hide Window Delay", 500)) / 1000)).timeout
	# 挂机中：Window_BattleVictoryActorSub 一建出就把 _victoryPhase 设回 false，结算画面不出现、直接回地图
	if XHangUp.is_active(XState.current):
		return
	var screen := XVictoryScreen.new()
	screen.setup(r, before, logic.actors, logic.auto)
	ui.add_child(screen)
	await screen.continued
