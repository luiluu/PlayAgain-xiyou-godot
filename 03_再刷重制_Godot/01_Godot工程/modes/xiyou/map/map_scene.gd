class_name XMapScene
extends Node2D
## 西游地图场景：图块（下层/上层）、角色、事件、镜头、遇敌，并为事件解释器提供画面服务。
## 只放切片配置 keepEvents 里列出的事件（"*" 为整张图的事件，开局三张图照原版全放）。
## 自动执行事件照 MV：解释器空闲时每帧找第一个满足条件的自动执行事件运行（场所移动后旧事件剩下的指令照常在新地图执行完）。

signal busy_changed(busy: bool)

const TS := MVTiles.TILE_SIZE

var map_id := 0
var map_data: Dictionary
var lower: MVTilemap
var upper: MVTilemap
var chars: Node2D
var player: MVPlayer
var followers: Array[MVFollower] = []
var events: Array[MVEvent] = []
var camera: Camera2D
var ui: CanvasLayer
var message: XMessageBox
var fader: ColorRect
var bgm: AudioStreamPlayer
var se: AudioStreamPlayer
var bgs: AudioStreamPlayer
var me: AudioStreamPlayer
var hud: Control
var map_hud: XMapHUD
var transfer_page: XMapTransferScene
var hang_overlay: XHangUpOverlay
var difficulty_notice: XDifficultyNoticeCanvas
## O-015：事件、对话、战斗之外才挂机走动与自动存档（原版事件进行中角色也会继续随机走动，存档可能存进半段剧情）。
const SAFE_HANG_UP := true
var busy := false
var encounter_count := 0.0
var skipped_log: Array = []
var toasts: Array = []              # 出现过的提示文字（测试核对用）
var popups: Array = []              # 出现过的获得提示文字（测试核对用）
var _pending_popups: Array = []     # 本帧获得的物品（MOG_TreasurePopup 按帧成批，序号决定错开）
var _bgm_name := ""
var _menu_open := false
var _backup_until := 0
## Game_Temp.reserveCommonEvent：事件进行中点的枫叶，等事件结束后执行
var _reserved_common_event := 0
## Scene_Map.create / update：变量 21（副本）为 0 时建出地图传送按钮，建出后到下次换场景前一直在
var _transfer_shown := false
## O-012：事件/对话期间不开放地图传送（原版事件中也能打开并传送）。设 false 恢复。
const SAFE_TRANSFER_BUTTON := true
var _map_name_tween: Tween
## O-011：事件/消息期间不开放地图备份，避免保存一半剧情（解释器当前不序列化）。
const SAFE_HUD_ACTIONS := true


static func slice() -> Dictionary:
	var d = XDB.load_json("slice.json")
	return d if d is Dictionary else {}


func _ready() -> void:
	# MV 画面底色为黑：比画面小的地图（开局 Map001/002 为 17×13）四周是黑的
	var backdrop := CanvasLayer.new()
	backdrop.layer = -100
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(black)
	add_child(backdrop)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	message = XMessageBox.new()
	ui.add_child(message)
	fader = ColorRect.new()
	fader.color = Color.BLACK
	fader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fader.modulate.a = 0.0
	ui.add_child(fader)
	_build_hud()
	# EnemyNameColorByDifficulty 的提示位于窗口层之上，随地图快照进入战斗背景。
	difficulty_notice = XDifficultyNoticeCanvas.new()
	ui.add_child(difficulty_notice)
	difficulty_notice.clock.can_paint = _difficulty_notice_active
	bgm = AudioStreamPlayer.new()
	XAudio.bind(bgm, "BGM")
	add_child(bgm)
	se = AudioStreamPlayer.new()
	XAudio.bind(se, "SE")
	add_child(se)
	bgs = AudioStreamPlayer.new()
	XAudio.bind(bgs, "BGS")
	add_child(bgs)
	me = AudioStreamPlayer.new()
	XAudio.bind(me, "ME")
	add_child(me)
	me.finished.connect(func(): bgm.stream_paused = false)
	camera = Camera2D.new()
	add_child(camera)
	var s := XState.current
	await load_map(s.map_id, s.x, s.y, s.direction)


func _difficulty_notice_active() -> bool:
	return not _in_battle and not _menu_open and transfer_page == null


func _exit_tree() -> void:
	# 地图销毁前解除全局计时器的回调，不能留到下一帧再检测已释放的闭包。
	if is_instance_valid(difficulty_notice) and is_instance_valid(difficulty_notice.clock):
		var clock := difficulty_notice.clock
		if clock.can_paint == _difficulty_notice_active:
			clock.can_paint = Callable()


func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = XUI.theme()
	ui.add_child(hud)
	map_hud = XMapHUD.new()
	hud.add_child(map_hud)
	# XdRs_HangUp 的快捷界面与挂机提示：地图和战斗都显示，放在 ui 最上层（战斗开始时再提到最上）
	hang_overlay = XHangUpOverlay.new()
	ui.add_child(hang_overlay)
	hang_overlay.toggle_requested.connect(toggle_hang_up)
	map_hud.backup_requested.connect(backup_game)
	map_hud.transfer_requested.connect(open_transfer)
	map_hud.return_requested.connect(return_to_hub)
	# 地图名（Olivia_MapDisplayNameCore，正式版改为居中）：窗口宽 1280、高 36，从 y=18 滑到 48 淡入，停留，再滑到 78 淡出（各 60 帧）
	var plate := XMVCanvas.new()
	plate.name = "MapNamePlate"
	plate.size = Vector2(1280, 36)
	plate.position = Vector2(0, 18)
	plate.modulate.a = 0.0
	plate.painter = _paint_map_name
	hud.add_child(plate)


var map_name_text := ""

## 正式版改过的 Window_MapName.refresh：暗底从 640−80×1.5 起、宽＝字宽＋160（左半由透明渐到 0.6 黑、右半渐回透明），
## 文字以 640 为中心
func _paint_map_name(c: XMVCanvas) -> void:
	if map_name_text == "":
		return
	var tw := c.text_width(map_name_text)
	var distance := 80.0
	var w := tw + distance * 2.0
	var bx := 640.0 - distance * 1.5
	var dark := Color(0, 0, 0, 0.6)
	var clear := Color(0, 0, 0, 0)
	c.gradient(Rect2(bx, 0, w / 2.0, 36), clear, dark)
	c.gradient(Rect2(bx + w / 2.0, 0, w / 2.0, 36), dark, clear)
	c.text(map_name_text, 640.0 - w / 2.0 + distance, 0, tw + 2, "left", XUI.TEXT, 26, 34)


func _show_map_name(text: String) -> void:
	# 快速连续场所移动时，上一张地图的 tween 不能继续改新地图名的位置/透明度。
	if _map_name_tween:
		_map_name_tween.kill()
	var plate: XMVCanvas = hud.find_child("MapNamePlate", true, false)
	map_name_text = text
	plate.queue_redraw()
	if text == "":
		plate.modulate.a = 0.0
		return
	plate.position.y = 18
	plate.modulate.a = 0.0
	_map_name_tween = plate.create_tween()
	var t := _map_name_tween
	t.tween_property(plate, "position:y", 48.0, 1.0)
	t.parallel().tween_property(plate, "modulate:a", 1.0, 1.0)
	t.tween_interval(1.0)
	t.tween_property(plate, "position:y", 78.0, 1.0)
	t.parallel().tween_property(plate, "modulate:a", 0.0, 1.0)


func load_map(id: int, x: int, y: int, d: int) -> void:
	for n in [lower, upper, chars]:
		if n:
			n.queue_free()
	events.clear()
	map_id = id
	map_data = XDB.map(id)
	var s := XState.current
	s.map_id = id
	XMapTransfer.on_arrive(s, id)
	_reset_transfer_button()
	lower = MVTilemap.new()
	lower.z_index = -10
	add_child(lower)
	lower.setup(map_data, false)
	chars = Node2D.new()
	chars.y_sort_enabled = true
	add_child(chars)
	upper = MVTilemap.new()
	upper.z_index = 10
	add_child(upper)
	upper.setup(map_data, true)
	var keep_cfg = slice().get("keepEvents", {}).get(str(id), [])
	var keep: Array = keep_cfg.map(func(v): return int(v)) if keep_cfg is Array else []
	for ev in map_data.events:
		if ev == null or (keep_cfg is Array and not keep.has(int(ev.id))):
			continue
		var e := MVEvent.new()
		e.tilemap = lower
		chars.add_child(e)
		e.setup_event(id, ev)
		events.append(e)
	# MOG_TreasurePopup：换地图时上一张图的获得提示不带过来（场所移动之后才执行的获得指令照常出现在新地图）
	for n in get_children():
		if n is XTreasurePopup:
			n.queue_free()
	# 队伍跟随在玩家之前加入（Spriteset_Map 先倒序放跟随、最后放玩家；同一行时玩家画在最上面）。
	# MV 的跟随者总是存在，显示与否看 Game_Followers._visible（XState.followers_visible，refresh_party_sprites 里套用）。
	followers.clear()
	for i in range(XState.MAX_BATTLE_MEMBERS - 1, 0, -1):
		var f := MVFollower.new()
		f.member_index = i
		f.tilemap = lower
		chars.add_child(f)
		f.synchronize(Vector2i(x, y), d if d > 0 else 2)
		followers.push_front(f)
	player = MVPlayer.new()
	player.dash = not bool(map_data.get("disableDashing", false))
	player.tilemap = lower
	chars.add_child(player)
	player.locate(x, y)
	player.direction = d if d > 0 else 2
	# 队伍跟随（System 显示队伍跟随）：出战成员第 2～5 人，场所移动后叠在玩家脚下
	if not followers.is_empty():
		player.before_step.connect(_followers_step)
	refresh_party_sprites()
	player.stepped.connect(_on_player_step)
	player.action_pressed.connect(_on_action)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = lower.width * TS
	camera.limit_bottom = lower.height * TS
	camera.reparent(player)
	camera.position = Vector2(0, -TS / 2.0)
	camera.reset_smoothing()
	_show_map_name(str(map_data.get("displayName", "")))
	if bool(map_data.get("autoplayBgm", false)):
		play_bgm(map_data.get("bgm", {}))
	if bool(map_data.get("autoplayBgs", false)):
		play_bgs(map_data.get("bgs", {}))
	_make_encounter_count()


func _process(delta: float) -> void:
	if XState.current:
		XState.current.play_seconds += delta
	if player:
		var hanging := XHangUp.is_active(XState.current)
		player.input_enabled = not busy and not _menu_open and not hanging
		player.auto_step = _hang_up_step if hanging else Callable()
		hang_overlay.visible = not _menu_open and transfer_page == null
		hang_overlay.refresh()
		var s := XState.current
		s.x = player.grid.x
		s.y = player.grid.y
		s.direction = player.direction
		# Game_Follower.update：透明、不透明度跟着玩家
		for f in followers:
			if f.transparent != player.transparent or f.opacity != player.opacity:
				f.transparent = player.transparent
				f.opacity = player.opacity
				f.queue_redraw()
		map_hud.refresh()
		if not _transfer_shown and XState.current.variable(21) == 0:
			_transfer_shown = true
		map_hud.transfer_button.visible = _transfer_shown
		map_hud.set_actions_enabled(not busy and not _menu_open and not player.is_moving(), not _menu_open,
			not _menu_open and not (SAFE_TRANSFER_BUTTON and busy))
	if not _pending_popups.is_empty():
		_flush_popups()
	if not busy and not _menu_open and player:
		# Game_Map.setupStartingEvent：预约的公共事件先于自动执行事件
		if _reserved_common_event > 0:
			var id := _reserved_common_event
			_reserved_common_event = 0
			run_common_event(id)
		else:
			_check_autorun()
	if not busy and Input.is_action_just_pressed("ui_cancel") and not XMessageBox.consumed_input_this_frame():
		open_menu()


# ---- 碰撞：同层事件挡路 ----
func is_blocked(cell: Vector2i, who: MVCharacter) -> bool:
	for e in events:
		if e != who and e.grid == cell and e.is_normal_priority() and not e.through and not e.page.is_empty():
			return true
	if who != player and player and player.grid == cell:
		return true
	return false


## Game_Player.showFollowers/hideFollowers（指令 216、设置「队列跟随」）
func set_followers_visible(v: bool) -> void:
	XState.current.followers_visible = v
	refresh_party_sprites()


func refresh_events() -> void:
	for e in events:
		e.refresh()
	refresh_party_sprites()


## Game_Player.refresh / Game_Followers.refresh：队首的行走图给玩家，其余出战成员给队伍跟随
func refresh_party_sprites() -> void:
	if player == null:
		return
	var s := XState.current
	var leader: XActor = s.members()[0] if s and not s.party.is_empty() else null
	if leader:
		player.set_image(str(leader.data().characterName), int(leader.data().characterIndex))
	else:
		player.set_image("", 0)
	for f in followers:
		f.refresh_image()
		f.visible = s == null or s.followers_visible


## Game_Followers.updateMove：从最后一个开始各追前一个人
func _followers_step() -> void:
	for i in range(followers.size() - 1, -1, -1):
		var target: MVCharacter = followers[i - 1] if i > 0 else player
		followers[i].chase(target, player.move_speed)


## Game_Followers.gather（指令 217）：收拢后才开始回城动画。
func gather_followers() -> void:
	while is_instance_valid(player) and player.is_moving():
		await get_tree().physics_frame
	# Game_Followers.areGathered 只看显示中的跟随者
	while followers.any(func(f): return f.visible and f.character_name != "" and (f.is_moving() or f.grid != player.grid)):
		if not followers.any(func(f): return f.is_moving()):
			_followers_step()
		await get_tree().physics_frame


# ---- 触发 ----
func _on_player_step() -> void:
	XState.current.steps += 1
	# 玩家接触：踩上「角色下方/上方」事件，或撞上同层事件时在 _on_bump 处理
	for e in events:
		if e.grid == player.grid and [1, 2].has(e.trigger()) and not e.is_normal_priority():
			await run_event(e)
			return
	if not map_data.encounterList.is_empty():
		if can_encounter():
			encounter_count -= encounter_progress_value(lower.is_bush(player.grid.x, player.grid.y), XState.current.party_ability(0))
		if encounter_count <= 0:
			await _encounter()


func _on_action() -> void:
	if busy:
		return
	var front := player.grid + MVCharacter.dir_offset(player.direction)
	for e in events:
		if e.grid == player.grid and e.trigger() == 0 and not e.is_normal_priority():
			await run_event(e)
			return
	for e in events:
		if e.grid == front and [0, 1, 2].has(e.trigger()) and e.is_normal_priority():
			await run_event(e)
			return


func _physics_process(_delta: float) -> void:
	_hang_up_physics()
	# 玩家朝同层事件走却被挡住：MV 的 checkEventTriggerTouch（触发 1/2）；挂机中不能手动移动
	if busy or player == null or player.is_moving() or XHangUp.is_active(XState.current):
		return
	var d := player._input_dir()
	if d == 0:
		return
	var front := player.grid + MVCharacter.dir_offset(d)
	for e in events:
		if e.grid == front and [1, 2].has(e.trigger()) and e.is_normal_priority():
			run_event(e)
			return


## Game_Map.setupAutorunEvent / Game_Event.checkEventTriggerAuto：列表多于一条（末尾结束指令之外还有内容）才启动
func _check_autorun() -> void:
	for e in events:
		if e.trigger() == 3 and e.command_list().size() > 1:
			run_event(e)
			return


func run_event(e: MVEvent) -> void:
	if busy or e.command_list().is_empty():
		return
	_set_busy(true)
	if not e.direction_fix and e.trigger() == 0:
		e.set_direction(MVCharacter.reverse_dir(player.direction))
	var ev_id := e.event_id
	var interp := MVInterpreter.new(self, map_id, ev_id, e.command_list())
	await interp.run()
	# 事件里若有场所移动，旧地图的事件节点已释放，之后不能再访问 e
	if not interp.skipped.is_empty():
		skipped_log.append_array(interp.skipped)
		print("[xiyou] 事件 %d 跳过 %d 条：%s" % [ev_id, interp.skipped.size(), JSON.stringify(interp.skipped.slice(0, 3))])
	_set_busy(false)
	refresh_events()


func _set_busy(b: bool) -> void:
	busy = b
	busy_changed.emit(b)


# ---- 遇敌（MV Game_Player.makeEncounterCount / makeEncounterTroopId）----
func _make_encounter_count() -> void:
	var n := int(map_data.get("encounterStep", 30))
	encounter_count = randi_range(0, n - 1) + randi_range(0, n - 1) + 1

func _encounter() -> void:
	_make_encounter_count()
	var region := lower.region(player.grid.x, player.grid.y)
	var list: Array = map_data.encounterList.filter(func(en): return en.regionSet.is_empty() or en.regionSet.has(float(region)) or en.regionSet.has(region))
	var total := 0
	for en in list:
		total += int(en.weight)
	if total <= 0:
		return
	var troop := encounter_troop(list, randi_range(0, total - 1))
	# 设置「禁用遇敌」：仍重置步数并抽敌群，只是不进战斗（executeEncounter 返回 false）
	if troop <= 0 or XConfig.flag("ydgb"):
		return
	_set_busy(true)
	await start_battle(troop, true, false)
	_set_busy(false)


## Game_Player.canEncounter：没有「无遇敌」队伍能力、遇敌未被指令 136 禁止、不在强制移动路线中
func can_encounter() -> bool:
	var s := XState.current
	return not s.party_ability(1) and s.encounter_enabled and not player.is_route_forcing()


## Game_Player.encounterProgressValue：草丛 2、否则 1，「遇敌减半」队伍能力 ×0.5；设置「步步遇敌」时 100（每步必遇）。
static func encounter_progress_value(bush: bool, half := false) -> float:
	if XConfig.flag("yd100"):
		return 100.0
	return (2.0 if bush else 1.0) * (0.5 if half else 1.0)


## Game_Player.makeEncounterTroopId（正式核心改动版）：r 为 0～权重和−1 的随机数。
## 「极其稀有」boss 取权重和−1、「只遇稀有」Boss 取权重和−2 作为抽签值；「只遇罕见」BOSS 时每项都减权重和−1。
static func encounter_troop(list: Array, r: int) -> int:
	var total := 0
	for en in list:
		total += int(en.weight)
	if total <= 0:
		return 0
	var value := total - 1 if XConfig.flag("boss") else (total - 2 if XConfig.flag("Boss") else r)
	for en in list:
		value -= total - 1 if XConfig.flag("BOSS") else int(en.weight)
		if value < 0:
			return int(en.troopId)
	return 0


# ---- 解释器服务 ----
func show_text(face: String, idx: int, lines: Array) -> void:
	await message.show_text(face, idx, lines)

func show_text_with_choices(face: String, idx: int, lines: Array, options: Array, cancel_type: int) -> int:
	return await message.show_text_with_choices(face, idx, lines, options, cancel_type)

## 文字/选项/数值输入（XMessageBox.run 的参数）
func show_message(msg: Dictionary) -> int:
	return await message.run(msg)

func fade(out: bool) -> void:
	var t := create_tween()
	t.tween_property(fader, "modulate:a", 1.0 if out else 0.0, 0.3)
	await t.finished

func transfer(id: int, x: int, y: int, d: int) -> void:
	if XDB.map(id).is_empty() or not slice().get("maps", []).map(func(v): return int(v)).has(id):
		await message.show_text("", 0, ["\\c[2]（首期尚未开放这张地图：Map%03d）" % id])
		return
	await fade(true)
	await load_map(id, x, y, d if d > 0 else player.direction)
	await fade(false)

func play_bgm(audio) -> void:
	var name := str(audio.get("name", "")) if audio is Dictionary else ""
	if name == _bgm_name:
		return
	_bgm_name = name
	var p := XDB.audio_path("bgm", name) if name != "" else ""
	bgm.stop()
	if p != "":
		bgm.stream = load(p)
		bgm.volume_db = linear_to_db(float(audio.get("volume", 90)) / 100.0)
		bgm.play()

func play_se(audio) -> void:
	var p := XDB.audio_path("se", str(audio.get("name", ""))) if audio is Dictionary else ""
	if p != "":
		se.stream = load(p)
		se.play()


func play_bgs(audio: Dictionary) -> void:
	var path := XDB.audio_path("bgs", str(audio.get("name", "")))
	bgs.stop()
	if path != "":
		bgs.stream = load(path)
		bgs.volume_db = linear_to_db(float(audio.get("volume", 90)) / 100.0)
		bgs.pitch_scale = float(audio.get("pitch", 100)) / 100.0
		bgs.play()


func play_me(audio: Dictionary) -> void:
	me.stop()
	var path := XDB.audio_path("me", str(audio.get("name", "")))
	bgm.stream_paused = path != ""
	if path != "":
		me.stream = load(path)
		me.volume_db = linear_to_db(float(audio.get("volume", 90)) / 100.0)
		me.pitch_scale = float(audio.get("pitch", 100)) / 100.0
		me.play()

## 战斗：返回 0 胜利 1 逃跑 2 战败（MV 语义）
func start_battle(troop_id: int, can_escape: bool, can_lose: bool) -> int:
	# BattleManager.saveBgmAndBgs/playBattleBgm：地图音乐不能和战斗音乐叠播，返回保留播放位置。
	me.stop()
	bgm.stream_paused = true
	bgs.stream_paused = true
	hud.visible = false
	var shot := await _snapshot()
	# 原版战斗没有 _tipSpr；只保留快照里的那一帧，活提示在后台继续倒数。
	difficulty_notice.hide()
	var battle := XBattleScene.new()
	battle.setup(troop_id, can_escape, can_lose, map_data, shot)
	ui.add_child(battle)
	ui.move_child(hang_overlay, -1)
	_in_battle = true
	var result: int = await battle.finished
	_in_battle = false
	battle.queue_free()
	difficulty_notice.clock.paint()
	# Scene_Battle.terminate → refrishHangUp：死亡停止；仍在挂机就自动吃药、按场数自动卖出
	XHangUp.after_battle(XState.current)
	if XHangUp.is_active(XState.current):
		var logic := XBattleLogic.new()
		logic.state = XState.current
		XHangUpAuto.after_battle_recovery(XState.current, logic)
		if XHangUpAuto.after_battle_sell(XState.current) >= 0:
			XToast.show_text("装备出售完成")
	hud.visible = true
	_reset_transfer_button()
	bgm.stream_paused = false
	bgs.stream_paused = false
	refresh_events()
	return result

## Scene_Map.snapForBattleBackground：隐藏窗口层（对话框、地图名、菜单按钮）后截取地图画面，
## 裁成 1280×720 画布范围。无画面（测试）时返回 null。
func _snapshot() -> Texture2D:
	if DisplayServer.get_name() == "headless":
		return null
	# 窗口层（对话框、地图名）不进截图：snapForBattleBackground 隐藏窗口层，Scene_Map.terminate 先隐藏地图名
	var plate: CanvasItem = hud.find_child("MapNamePlate", true, false)
	var was := message.visible
	var plate_was := plate.visible if plate else false
	message.visible = false
	if plate:
		plate.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	message.visible = was
	if plate:
		plate.visible = plate_was
	if img == null or img.is_empty():
		return null
	var ft := get_viewport().get_final_transform()
	var r := Rect2i(Rect2(ft.origin, ft.get_scale() * get_viewport().get_visible_rect().size)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x <= 0 or r.size.y <= 0:
		return null
	img = img.get_region(r)
	# MV 快照是 1280×720 位图；高分屏截到的大图缩回画布尺寸，放大镜头时才会和原版一样柔化
	if img.get_size() != Vector2i(1280, 720):
		img.resize(1280, 720, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(img)


## Game_Map.adjustX/Y($gamePlayer.x/y)：玩家所在格减去画面左上角（以格计，镜头未对齐格时有小数）
func player_screen_tile() -> Vector2:
	if player == null or camera == null:
		return Vector2.ZERO
	var origin := camera.get_screen_center_position() - Vector2(1280, 720) / 2.0
	return Vector2(player.grid) - origin / TS


## Game_Temp.reserveCommonEvent：回到地图后执行的公共事件（事件 ID 为 0）
func run_common_event(id: int) -> void:
	var ce := XDB.rec("CommonEvents", id)
	if ce.is_empty() or busy:
		return
	_set_busy(true)
	var interp := MVInterpreter.new(self, map_id, 0, ce.list)
	await interp.run()
	if not interp.skipped.is_empty():
		skipped_log.append_array(interp.skipped)
	_set_busy(false)
	refresh_events()


# ---- 角色、动画、提示、输入、存档 ----
## Game_Interpreter.character：-1 玩家，0 本事件，N 为该事件（不在本图则为空）
func character(id: int, this_event: int) -> MVCharacter:
	if id < 0:
		return player
	var want := this_event if id == 0 else id
	for e in events:
		if e.event_id == want:
			return e
	return null


## 在角色身上播 MV 动画（Sprite_Animation：0 头上 1 中心 2 脚下 3 画面中央）
func show_animation(ch: MVCharacter, anim_id: int) -> MVAnimation:
	var a := XDB.rec("Animations", anim_id)
	if a.is_empty():
		return null
	var at := ch.position - Vector2(0, 0.0 if ch.is_object() else 6.0)
	match int(a.get("position", 1)):
		0:
			at.y -= ch.sprite_height()
		1:
			at.y -= ch.sprite_height() / 2.0
		3:
			at = camera.get_screen_center_position()
	var anim := MVAnimation.play(self, anim_id, at)
	if anim:
		anim.z_index = 50
	return anim


func return_to_title() -> void:
	get_tree().change_scene_to_file.call_deferred("res://modes/xiyou/entry.tscn")


## $.toaster 提示（AXY_Toast 样式，见 XToast）
func toast(text: String) -> void:
	toasts.append(XToast.plain(text))
	XToast.show_text(text, _menu_open)


## 原版的 prompt(提示, 默认)：输入一行文字，取消返回空。自动测试时取 auto_answers 里排在最前的字符串。
## 优化 O-010：原版是 NW.js 浏览器自带的输入框（与游戏画面风格无关），这里默认用 MV 窗口皮肤的 XTextPrompt；
## NATIVE_PROMPT 设 true 改用系统输入框（DisplayServer.dialog_input_text，最接近原版的浏览器对话框）。
const NATIVE_PROMPT := false

func input_text(prompt: String, default := "") -> String:
	if XMessageBox.auto:
		if not XMessageBox.auto_answers.is_empty() and XMessageBox.auto_answers[0] is String:
			return str(XMessageBox.auto_answers.pop_front())
		return default
	if NATIVE_PROMPT and DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_INPUT):
		var box := [null]
		DisplayServer.dialog_input_text("", prompt, default, func(t: String): box[0] = t)
		while box[0] == null:
			await get_tree().process_frame
		return str(box[0])
	var dlg := XTextPrompt.new()
	dlg.setup(prompt, default)
	ui.add_child(dlg)
	var text: String = await dlg.closed
	dlg.queue_free()
	return text


## MOG_TreasurePopup：在 ID 为 event_id 的事件处浮出「图标 名字 x 数量」。事件按 ID 在当前地图上找（场所移动后旧事件的
## 后续指令也照此找新地图上同 ID 的事件，与原版相同）；该事件未放到地图上时用地图数据里的初始格子。
func treasure_popup(rec: Dictionary, amount: int, event_id: int) -> void:
	_pending_popups.append([rec, amount, event_id])


func _flush_popups() -> void:
	var list := _pending_popups
	_pending_popups = []
	for i in range(list.size()):
		var at = _event_screen_pos(int(list[i][2]))
		if at == null:
			continue
		var pop := XTreasurePopup.new()
		pop.z_index = 60
		pop.setup(list[i][0], int(list[i][1]), at, i, list.size())
		add_child(pop)
		popups.append(pop.text())


## Game_CharacterBase.screenX/screenY 的世界坐标：格子中心、脚下减行走图偏移 6（物件不减）
func _event_screen_pos(id: int):
	for e in events:
		if e.event_id == id:
			return e.position - Vector2(0, 0.0 if e.is_object() else 6.0)
	for ev in map_data.get("events", []):
		if ev is Dictionary and int(ev.id) == id:
			return Vector2((float(ev.x) + 0.5) * TS, (float(ev.y) + 1.0) * TS - 6.0)
	return null


## DataManager.saveGame(固定存档位)
func save_game(slot: int) -> bool:
	return slot > 0 and XSave.save(slot)


func open_shop(goods: Array, purchase_only: bool) -> void:
	var shop := XShop.new()
	shop.setup(goods, purchase_only)
	ui.add_child(shop)
	await shop.closed
	shop.queue_free()

func game_over() -> void:
	await message.show_text("", 0, ["全军覆没……将在方桌大厅复活。"])
	for a in XState.current.members():
		a.recover_all()
	await transfer(4, 14, 23, 8)

func open_menu() -> void:
	# 挂机中不能呼叫菜单（Scene_Map.isMenuCalled）
	if busy or _menu_open or XHangUp.is_active(XState.current):
		return
	_menu_open = true
	XSound.system(1)  # Scene_Map.callMenu：SoundManager.playOk
	# Scene_Map.terminate：snapForBackground／snapForHangUp（含地图 HUD），挂机设置页的背景与范围图
	var shot := await _snapshot()
	hud.visible = false
	var menu := XMenu.new()
	menu.map_shot = shot
	menu.player_tile = player_screen_tile()
	ui.add_child(menu)
	await menu.closed
	var reserved := menu.reserved_common_event
	menu.queue_free()
	_menu_open = false
	hud.visible = true
	_reset_transfer_button()
	if reserved > 0:
		await run_common_event(reserved)
	# 整队/换人后队首与跟随的行走图
	refresh_party_sprites()


func backup_game() -> void:
	if _menu_open or (SAFE_HUD_ACTIONS and busy) or Time.get_ticks_msec() < _backup_until:
		return
	if player and player.is_moving():
		return
	busy = true
	busy_changed.emit(true)
	var slot := XSave.backup()
	if slot > 0:
		_backup_until = Time.get_ticks_msec() + 2000
		XSound.system(5)
		await message.show_text("", 0, ["✅ 备份完成", "存入【%d】号存档" % slot])
	else:
		if slot < 0:
			XSound.system(3)  # 原版备份已满时不放音效；写入失败是 O-011 新增的提示
		await message.show_text("", 0, ["⚠️ 备份已满，请清理旧存档" if slot == 0 else "备份失败，请重试。"])
	busy = false
	busy_changed.emit(false)


# ---- 挂机（XdRs_HangUp，数据与规则见 XHangUp）----
var _in_battle := false


## G 键与快捷界面按钮（XdRsData.hangUp.set）；菜单与传送页不是挂机场景，不响应
func toggle_hang_up() -> void:
	var s := XState.current
	if s == null or _menu_open or transfer_page != null:
		return
	if XHangUp.is_active(s):
		XHangUp.stop(s)
		return
	var tip := XHangUp.ready_start(s, not map_data.get("encounterList", []).is_empty(), player.grid)
	if tip != "" and not busy:
		_set_busy(true)
		await message.show_text("", 0, [tip], 0, 1)
		_set_busy(false)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_G:
		toggle_hang_up()
		get_viewport().set_input_as_handled()


## Game_Player.updateHangUp：有遇敌表时在范围内随机走、出范围往回走；没有遇敌表时回原点
func _hang_up_step() -> Array:
	var s := XState.current
	if (SAFE_HANG_UP and busy) or _menu_open or transfer_page != null:
		return []
	player.move_speed = 5 if player.is_dashing() else 4
	if map_data.get("encounterList", []).is_empty():
		return XHangUp.toward(player.grid, s.hang_up_origin)
	return XHangUp.next_dirs(s, player.grid)


## 挂机计时（地图与战斗场景每帧）；满存档间隔后回到地图时存到开局固定存档位
func _hang_up_physics() -> void:
	var s := XState.current
	if s == null or _menu_open or transfer_page != null:
		return
	XHangUp.tick(s)
	if s.hang_up_save_pending and not _in_battle and not (SAFE_HANG_UP and busy):
		s.hang_up_save_pending = false
		var slot := int(s.flags.get("SaveGameId", 0))
		if slot > 0 and XSave.save(slot):
			XSound.system(5)
			_set_busy(true)
			await message.show_text("", 0, [str(XHangUp.params().get("saveWord", ""))], 0, 1)
			_set_busy(false)


## 换场景（场所移动、菜单/战斗返回）后重新按变量 21 决定是否有地图传送按钮
func _reset_transfer_button() -> void:
	_transfer_shown = XState.current != null and XState.current.variable(21) == 0
	if map_hud:
		map_hud.transfer_button.visible = _transfer_shown


## Sprite_MapTransferButton → Scene_MapTransfer：截图（不含地图名）作背景；确认传送后从黑场淡入新地图（Laser1 已在页内播放）。
func open_transfer() -> void:
	if _menu_open or (SAFE_TRANSFER_BUTTON and busy):
		return
	XSound.system(1)
	_set_busy(true)
	var shot := await _snapshot()
	hud.visible = false
	var page := XMapTransferScene.new()
	page.background = shot
	ui.add_child(page)
	transfer_page = page
	var target: Dictionary = await page.closed
	page.queue_free()
	transfer_page = null
	hud.visible = true
	if not target.is_empty():
		fader.modulate.a = 1.0
		await load_map(int(target.map), int(target.x), int(target.y), 8)
		await fade(false)
	else:
		_reset_transfer_button()
	_set_busy(false)
	refresh_events()


## TCLH_levelUP_button：枫叶只预约公共事件 10（带副本限制），不能直接绕过事件传送。
## 原版在事件或移动中点击也会预约，等当前事件结束后执行。
func return_to_hub() -> void:
	if _menu_open:
		return
	play_se({"name": "Coin"})
	if busy:
		_reserved_common_event = 10
		return
	await run_common_event(10)
