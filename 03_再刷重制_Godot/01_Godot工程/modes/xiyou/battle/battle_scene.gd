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
var ui: Control
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
## 自动测试用：强制自动战斗，胜利界面自动关闭。
static var force_auto := false


func setup(troop: int, escape: bool, lose: bool, map: Dictionary, background: Texture2D = null) -> void:
	troop_id = troop
	snapshot = background
	can_lose = lose
	map_data = map
	logic.can_escape = escape
	logic.setup(troop, XState.current)
	logic.auto = force_auto


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
	_place_battlers()
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	_build_ui(vs)
	bgm = AudioStreamPlayer.new()
	XAudio.bind(bgm, "BGM")
	add_child(bgm)
	se = AudioStreamPlayer.new()
	XAudio.bind(se, "SE")
	add_child(se)
	var music: Dictionary = XDB.system().battleBgm
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
		var s := XBattlerSprite.new()
		field.add_child(s)
		s.setup(e, 1.8 if e.elite else 1.0)
		s.breathing = true
		# YEP_CoreEngine Reposition Battlers：侧视时敌人 y 加 (画面高 − 624) / 2
		s.home = Vector2(float(e.get_meta("x")), float(e.get_meta("y")) + floorf((BOX.y - 624.0) / 2.0))
		s.position = s.home
		sprites[e] = s
		_make_enemy_gauge(e)
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
func _make_enemy_gauge(e: XEnemy) -> void:
	var c := XMVCanvas.new()
	c.size = Vector2(640, 100)
	c.clip_contents = false
	c.z_index = 5
	field.add_child(c)
	gauges[e] = {"box": c, "timer": 0.0, "name_timer": 3.0}
	c.painter = func(canvas): _paint_enemy(canvas, e)


## Olivia WeaknessDisplay 名字与 YEP VisualHpGauge 是两个独立窗口。
## 名字居中在 (敌人 x, y−27) 的 640×72 内容位图；HP 内容 (x−90,y−16)，字号 26、居中、12px 粗条。
func _paint_enemy(c: XMVCanvas, e: XEnemy) -> void:
	var g: Dictionary = gauges[e]
	if e.is_alive() and (g.name_timer > 0.0 or e == _hover):
		var color := _enemy_name_color(e) if e.hp_rate() > 0.5 else XUI.text_color(2 if e.hp_rate() > 0.25 else 10)
		c.text(e.display_name(), 0, 0, 640, "center", color, 18, 36)
	if g.timer <= 0.0 and not (_target_mode == "enemy" and e == _hover):
		return
	var w := maxf(ENEMY_GAUGE_W, sprites[e].width())
	var x := 320.0 - w / 2.0
	var y := 11.0
	var gy := y + 36 - 12 - 2
	c.draw_rect(Rect2(x, gy, w, 12), Color(XUI.text_color(19), 160.0 / 255.0))
	var fill := maxf(0, floorf(w * e.hp_rate()) - 4)
	if fill > 0:
		c.gradient(Rect2(x + 2, gy + 2, fill, 8), XUI.text_color(20), XUI.text_color(21))
	c.text(XMenu._group(e.hp), x, y, w, "center", XUI.TEXT, 26, 36)


## EnemyNameColorByDifficulty 只为与数据库原名完全相同的文字上色。
func _enemy_name_color(e: XEnemy) -> Color:
	return XEnemy.name_color(e.display_name(), e.difficulty_id)


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


func _refresh_status() -> void:
	for row in status_rows.values():
		row.refresh()
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
func _physics_process(_delta: float) -> void:
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
		while not logic.is_won() and not logic.is_lost():
			var u := logic.next_subject()
			if u == null:
				break
			otb.on_subject(u)
			otb.show_orders(logic.current_order, logic.next_order)
			var cmd = await _command(u)
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
			# 快速战斗只跳过失败信息（见 XHangUp）
			if not XHangUp.fast_fighting(XState.current):
				await _say("全军覆没……", 1.2)
			logic.end_battle()
			finished.emit(2)
			return
		await _play(logic.end_turn())
		otb.show_orders(logic.current_order, logic.next_order)
		_refresh_status()
		# 全员不能行动时也交还一帧，保留自动/速度按钮与窗口响应。
		await get_tree().process_frame


## BattleManager.processEscape 成功：逃跑音效、提示，结束战斗（结果 1）
func _escape_success() -> void:
	_close_windows()
	otb.hide_bar()
	logic.escaped = true
	XSound.system(8)
	await _say("成功逃跑了。", 0.8)
	logic.end_battle()
	finished.emit(1)


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
			await _say("没能逃掉！", 0.8)
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
				var action = await _pick_action_list(a, logic.battle_items(), true)
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


## 技能/物品列表的一行：技能右侧照 YEP 消耗（TP 图标 1268 色 29、MP 图标 1269 色 23，字号 20）；
## 冷却「nCD」色 6、预热「nWU」色 4（图标 1045）；物品右侧「×数量」字号 20。
func _list_entry(a: XActor, e: Dictionary, items: bool) -> Dictionary:
	var row := {"text": str(e.name), "icon": int(e.get("iconIndex", 0)), "enabled": logic.can_use(a, e), "costs": []}
	if items:
		row.costs = [{"text": "×%d" % int(XState.current.items.get(int(e.id), 0)), "size": 20}]
		return row
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
	for l in logs:
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
				if float(l.hp) != 0.0:
					_popup(l.target, -float(l.hp), false)
			"skip":
				pass
		_refresh_status()
	if acting:
		await _finish_action(started)
	_banner("")
	_set_active(null)
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
		s.set_motion("spell" if XDamage.is_magical(skill) else "skill")


func _reflect_animation() -> int:
	return int(XDB.plugin("YEP_BattleEngineCore").get("Reflect Animation", "0"))


func _center(b: XBattler) -> Vector2:
	var s: XBattlerSprite = sprites[b]
	return s.position + Vector2(0, -s.height() / 2.0)


func _show_hit(l: Dictionary) -> void:
	var t: XBattler = l.target
	var ts: XBattlerSprite = sprites[t]
	var anim_id := int(l.skill.animationId)
	if anim_id < 0:
		anim_id = _attack_animation(l.user)
	var animation := _start_animation(anim_id, t)
	if animation:
		await animation.done
	var hit: bool = not (l.missed or l.evaded)
	combo.applied(l.user, t, hit, int(l.skill.get("damage", {}).get("type", 0)), float(l.hp) if float(l.hp) != 0.0 else float(l.mp))
	if not hit:
		_popup(t, 0, false, "miss")
		ts.set_motion("evade")
	else:
		if float(l.hp) != 0.0:
			_popup(t, float(l.hp), l.critical)
			# MV performDamage：敌人闪烁（requestEffect blink），角色做受伤动作
			if float(l.hp) > 0.0:
				if t is XEnemy:
					ts.blink()
				else:
					ts.set_motion("damage")
		if float(l.mp) != 0.0:
			_popup(t, float(l.mp), false, "", true)
		if t is XEnemy:
			_show_enemy_gauge(t)
	if l.died:
		if gauges.has(t):
			gauges[t].box.visible = false
			gauges[t].timer = 0.0
		await ts.collapse()
	await _wait_frames(13)


## 关闭时连动画音效也跳过（正式版 Game_Battler.startAnimation 直接返回）。地图动画不受这个开关影响。
func _start_animation(id: int, target: XBattler) -> MVAnimation:
	if id <= 0 or not XConfig.flag("CombatSkillAnimation"):
		return null
	var data := XDB.rec("Animations", id)
	if data.is_empty():
		return null
	var at := _center(target)
	match int(data.get("position", 1)):
		0: at = sprites[target].position - Vector2(0, sprites[target].height())
		2: at = sprites[target].position
		3: at = BOX / 2.0
	return MVAnimation.play(fx, id, at, false, XConfig.battle_speed())


func _attack_animation(u: XBattler) -> int:
	if u is XActor:
		for e in (u as XActor).equip_list():
			if e.kind == "weapon":
				return int(e.animationId)
		return 1
	return int(XDB.plugin("YEP_BattleEngineCore").get("Enemy Attack Animation", "1"))


## 伤害数字（XDamagePopup，LGP_BetterDamagePopup）。位置：敌人 = 脚底 + (0, −图高/2 + 16)（MOG Center Y-Axis），
## 角色 = 脚底；同一目标已有的弹出数决定叠加高度。text: "miss" 显示 Miss。
var _popups := {}          # XBattler -> Array[XDamagePopup]


func _popup(b: XBattler, value: float, critical: bool, text := "", is_mp := false) -> void:
	if not XConfig.flag("CombatDamageShow"):
		return
	var s: XBattlerSprite = sprites[b]
	var live: Array = _popups.get(b, []).filter(func(x): return is_instance_valid(x))
	var p := XDamagePopup.new()
	p.position = s.position + (Vector2.ZERO if b is XActor else Vector2(0, -s.height() / s.body_scale / 2.0 + 16))
	p.z_index = 20
	p.setup(value, is_mp, critical, text == "miss", b is XActor, live.size())
	fx.add_child(p)
	live.append(p)
	_popups[b] = live


func _say(text: String, seconds: float) -> void:
	_banner(text)
	await get_tree().create_timer(seconds).timeout
	_banner("")


## 胜利：先发放一次奖励，再放大胜利镜头，最后显示 Olivia 的结算布局。
func _victory() -> void:
	_close_windows()
	for a in logic.alive(logic.actors):
		sprites[a].set_motion("victory")
	var before := {}
	for a in logic.actors:
		before[a] = {"exp": a.exp_total, "level": a.level}
	var r := logic.rewards()
	logic.grant(r)
	logic.end_battle()
	var params := XDB.plugin("Olivia_VictorySequenceUI")
	bgm.stop()
	var music := XDB.audio_path("bgm", str(params.get("Victory Screen BGM", "Ship3")))
	if music != "":
		bgm.stream = load(music)
		bgm.volume_db = linear_to_db(float(params.get("Victory Screen BGM Volume", 90)) / 100)
		bgm.play()
	# 胜利镜头（YEP_X_ActSeqPack3 战斗镜头）：镜头点从画面中心 (640,360) 移到 (700,460)、放大 1→2，
	# 都在 300 帧内线性完成；场景层位置 = −镜头点×放大 + 画面中心，并夹在放大后的画面内。结算文字不缩放。
	if str(params.get("Victory Screen Zoom", "true")) == "true":
		_camera = {"from": BOX / 2.0, "to": Vector2(float(params.get("Victory Screen Zoom X", 700)), float(params.get("Victory Screen Zoom Y", 460))),
			"scale": float(params.get("Victory Screen Zoom Scale", 2)), "frames": int(params.get("Victory Screen Zoom Duration", 300)), "t": 0, "base": {}}
		for visual in get_children():
			if visual != ui and (visual is Control or visual is Node2D):
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
