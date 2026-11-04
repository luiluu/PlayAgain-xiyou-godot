class_name XMapScene
extends Node2D
## 西游地图场景：图块（下层/上层）、角色、事件、镜头、遇敌，并为事件解释器提供画面服务。
## 只放切片配置 keepEvents 里列出的事件（"*" 为整张图的事件，开局三张图照原版全放）。
## 自动执行事件照 MV：解释器空闲时每帧找第一个满足条件的自动执行事件运行（场所移动后旧事件剩下的指令照常在新地图执行完）。

signal busy_changed(busy: bool)

const TS := MVTiles.TILE_SIZE

var map_id := 0
var map_data: Dictionary
## 283 更改战斗背景（Game_Map.changeBattleback）设的 [背景1, 背景2]，存在 XState.battleback（随存档）；
## 换到别的地图时清掉（Game_Map.setup 重设为地图指定的），同图移动与读档不清（performTransfer 只在换图时 setup）
var battleback_override: Array:
	get:
		return XState.current.battleback if XState.current else []
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
var screen_fx: XScreenFxView
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
var _hotkeys := XMapHotkeys.new()
var _milestone_tick := 0
var _backup_until := 0
## Scene_Map.create / update：变量 21（副本）为 0 时建出地图传送按钮，建出后到下次换场景前一直在
var _transfer_shown := false
## O-012：事件/对话期间不开放地图传送（原版事件中也能打开并传送）。设 false 恢复。
const SAFE_TRANSFER_BUTTON := true
var _map_name_tween: Tween
## O-011：事件/消息期间不开放地图备份，避免保存一半剧情（解释器当前不序列化）。
const SAFE_HUD_ACTIONS := true
## O-036：这些事件页执行完、事件换到别的页时，接着按新页再执行一次（键「地图:事件:页下标」）。
## 大厅传送门（Map004 事件 36）第 3 页（开关 686「前往20层」）在变量 20＝21 时只关掉 686、什么都不显示，
## 二十层通关后第一次按门没有反应，要再按一次才出楼层菜单；这里关掉后直接出楼层菜单。设 {} 恢复原版。
const RERUN_AFTER_PAGE := {"4:36:2": true}
## O-117：乘飞艇时（含升降中）地图传送按钮不可用、不能开始挂机。原版 MapTransferPlugin 与 XdRs_HangUp 都不看载具，
## 飞行中能把飞艇带进楼层地图、越墙降落，挂机还会带着飞艇乱飞。设 false 恢复原版。
static var SAFE_AIRSHIP_MENU := true  # O-117；测试要切回原版，用 static var
## Game_Vehicle.maxAltitude：飞艇升到 48 才能飞（canMove 要 isHighest），降到 0 才算下完
const AIRSHIP_MAX_ALTITUDE := 48
## 飞艇影子（Spriteset_Map.createShadow：system/Shadow1，锚点底边中点，z 6 在飞艇 z 5 之上）；挂在飞艇精灵下跟着它的格子位置，
## 不跟高度（位置里减回去）
const AIRSHIP_SHADOW_Z := MVCharacter.ABOVE_UPPER_Z + 1
## 飞艇（Game_Map.airship）的地图精灵：画面上移 altitude（Game_Vehicle.screenY），驾驶或升降中在上层图块之上
var airship: MVCharacter
var airship_shadow: Sprite2D
## 头顶名牌（Star_Designation）：玩家与飞艇的精灵各一张，见 XDesignationPlate
var player_plate: XDesignationPlate
var airship_plate: XDesignationPlate
## Game_Player._vehicleGettingOn／_vehicleGettingOff 与上下载具时的 gatherFollowers（不随档，读档时按飞艇状态补，见 _place_vehicle）
var _vehicle_getting_on := false
var _vehicle_getting_off := false
var _vehicle_gathering := false
## 正在放的地图 BGM（AudioManager.saveBgm：上飞艇时存成 walking_bgm）
var _bgm_audio = null


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
	ui.child_entered_tree.connect(_on_ui_page)
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
	screen_fx = XScreenFxView.new()
	screen_fx.camera = camera
	add_child(screen_fx)
	var s := XState.current
	await load_map(s.map_id, s.x, s.y, s.direction)
	XItemMarks.deploy_start(XState.current)  # Scene_Map.start 包装：清出战栏里的超强者并提示


## Scene_Map.stop 包装：地图上开了别的画面（战斗、商店、各种页面；输入文字 prompt 与批量抽奖的数量框不算）就不再回物品页
func _on_ui_page(node: Node) -> void:
	if not node is XTextPrompt and not node is XCasinoDialog:
		XItemBagReturn.scene_opened(XState.current)


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
	var s := XState.current
	# Game_Player.performTransfer：新地图 ID 与当前相同时不 $gameMap.setup，事件（位置、朝向、强制路线、页、消除）原样保留，
	# 只重新放置玩家与跟随者（locate：synchronize、makeEncounterCount）；场景本身照常重建（地图名、自动播放、传送按钮）
	if id == map_id and id == s.map_id and chars != null and is_instance_valid(chars):
		XMapTransfer.on_arrive(s, id)
		_reset_transfer_button()
		_clear_treasure_popups()
		camera.reparent(self)
		for c in followers + [player]:
			if c != null and is_instance_valid(c):
				chars.remove_child(c)
				c.queue_free()
		_place_party(x, y, d)
		return
	for n in [lower, upper, chars]:
		if n:
			n.queue_free()
	events.clear()
	if id != s.map_id:
		s.battleback = []
		s.erased_events.clear()
		s.map_events = {}
	map_id = id
	map_data = XDB.map(id)
	XAlienBattle.on_map_setup(s, s.map_id, id)  # Leviathan Game_Map.setup 包装：未知存在记来源地图（异化 Boss 来源用）
	XYunshangOrders.on_map_setup(s, s.map_id, id)  # 云裳 Game_Map.setup 包装：未知战斗记来源地图（不朽天丝用）
	s.map_id = id
	XEnemyBook.on_map_setup(s, map_data)  # AB_EnemyBook Game_Map.setup：记遇敌表敌人的出没地图
	XMapTransfer.on_arrive(s, id)
	_reset_transfer_button()
	lower = MVTilemap.new()
	lower.z_index = -10
	add_child(lower)
	lower.setup(map_data, false)
	lower.open_cells = MVTilemap.open_cells_fix.get(id, [])
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
		if s.erased_events.has(int(ev.id)):
			e.erased = true
			e.page_index = -2   # refresh 照空页设置（透明、可穿过）
		e.setup_event(id, ev)
		events.append(e)
	# 读档：套回存档时的事件状态（只此一次；之后存档由 _snapshot_events 现取）
	if int(s.map_events.get("mapId", 0)) == id:
		var saved: Dictionary = s.map_events.get("events", {})
		for e in events:
			if saved.get(str(e.event_id)) is Dictionary:
				e.restore_state(saved[str(e.event_id)])
	s.map_events = {}
	relocate_race_guide()
	s.map_event_snapshot = _snapshot_events
	lower.tile_events = _tile_events_at
	_clear_treasure_popups()
	_place_party(x, y, d)


## 存档时的当前地图事件状态（XState.to_dict 调用）
func _snapshot_events() -> Dictionary:
	var out := {}
	for e in events:
		if is_instance_valid(e):
			out[str(e.event_id)] = e.save_state()
	return {"mapId": map_id, "events": out}


## MOG_TreasurePopup：换地图时上一张图的获得提示不带过来（场所移动之后才执行的获得指令照常出现在新地图）
func _clear_treasure_popups() -> void:
	for n in get_children():
		if n is XTreasurePopup:
			n.queue_free()


## 放玩家与跟随者、镜头、地图名、自动播放、遇敌步数（换图与同图移动共用）
func _place_party(x: int, y: int, d: int) -> void:
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
	player_plate = XDesignationPlate.new()
	player.add_child(player_plate)
	player.locate(x, y)
	player.direction = d if d > 0 else 2
	# 队伍跟随（System 显示队伍跟随）：出战成员第 2～5 人，场所移动后叠在玩家脚下
	if not followers.is_empty():
		player.before_step.connect(_followers_step)
	refresh_party_sprites()
	player.stepped.connect(_on_player_step)
	player.action_pressed.connect(_on_action)
	# 循环方向不限镜头（Game_Map.setDisplayPos／scrollLeft 在循环地图上不夹边）
	const FREE := 10000000
	camera.limit_left = -FREE if lower.loop_x else 0
	camera.limit_top = -FREE if lower.loop_y else 0
	camera.limit_right = FREE if lower.loop_x else lower.width * TS
	camera.limit_bottom = FREE if lower.loop_y else lower.height * TS
	camera.reparent(player)
	camera.position = Vector2(0, -TS / 2.0)
	camera.reset_smoothing()
	_show_map_name(str(map_data.get("displayName", "")))
	_place_vehicle()
	# Game_Map.autoplay：乘载具时只记下地图 BGM（saveWalkingBgm2），继续放载具的
	if bool(map_data.get("autoplayBgm", false)):
		if in_vehicle():
			XState.current.walking_bgm = (map_data.bgm as Dictionary).duplicate() if map_data.get("bgm") is Dictionary else null
		else:
			play_bgm(map_data.get("bgm", {}))
	if bool(map_data.get("autoplayBgs", false)):
		play_bgs(map_data.get("bgs", {}))
	_make_encounter_count()


func _process(delta: float) -> void:
	if XState.current:
		XState.current.play_seconds += delta
		# Star_PetSystem：新游戏／读档后每 5 分钟查一次神秘生物刷新（改事件独立开关，见 XPetCapture）
		var pet_notes = XPetCapture.tick(XState.current)
		if pet_notes != null:
			refresh_events()
			for t in pet_notes:
				XToast.show_text(str(t))
	if player:
		var hanging := XHangUp.is_active(XState.current)
		player.input_enabled = not busy and not _menu_open and not hanging and vehicle_can_move()
		player.auto_step = _hang_up_step if hanging else Callable()
		hang_overlay.visible = not _menu_open and transfer_page == null
		hang_overlay.refresh()
		_update_plates()
		var s := XState.current
		s.x = player.grid.x
		s.y = player.grid.y
		s.direction = player.direction
		# 循环地图：角色画在离玩家最近的那一份上（玩家越过边缘后其他角色跟着换份）
		if lower.loop_x or lower.loop_y:
			lower.view_anchor = player.real
			for c in chars.get_children():
				if c is MVCharacter:
					c._sync_position()
		map_hud.refresh()
		if not _transfer_shown and XState.current.variable(21) == 0:
			_transfer_shown = true
		map_hud.transfer_button.visible = _transfer_shown
		map_hud.set_actions_enabled(not busy and not _menu_open and not player.is_moving(), not _menu_open,
			not _menu_open and not (SAFE_TRANSFER_BUTTON and busy) and not _vehicle_menu_locked())
	if not _pending_popups.is_empty():
		_flush_popups()
	if not busy and not _menu_open and player:
		# Game_Map.setupStartingEvent：预约的公共事件先于自动执行事件
		if XState.current.peek_common_event() > 0:
			run_reserved_common_event(XState.current)
		else:
			_check_autorun()
		# installItemBagContinuationRuntime：物品页预约的公共事件跑完（没有别的预约、事件与文字）就回物品页
		if not busy and transfer_page == null and not XHangUp.is_active(XState.current):
			var back := XItemBagReturn.take(XState.current, false)
			if not back.is_empty():
				open_menu(back)
		if not busy and transfer_page == null:
			_check_milestone()
	if not busy and Input.is_action_just_pressed("ui_cancel") and not XMessageBox.consumed_input_this_frame():
		open_menu()


# ---- 碰撞：同层事件挡路 ----
func is_blocked(cell: Vector2i, who: MVCharacter) -> bool:
	for e in events:
		if e != who and e.grid == cell and e.is_normal_priority() and not e.through and not e.page.is_empty():
			return true
	# Game_Event.isCollidedWithPlayerCharacters → Game_Player.isCollided：玩家穿透（乘飞艇）时不挡事件
	if who != player and player and player.grid == cell and not player.through:
		return true
	return false


## Game_Player.showFollowers/hideFollowers（指令 216、设置「队列跟随」）
func set_followers_visible(v: bool) -> void:
	XState.current.followers_visible = v
	refresh_party_sprites()


## 指令 214 暂时消除：本次进图期间该事件不再出现（Game_Event.erase）；记进 XState.erased_events 随档保存
func erase_event(id: int) -> void:
	if not XState.current.erased_events.has(id):
		XState.current.erased_events.append(id)
	for e in events:
		if e.event_id == id:
			e.erased = true
			e.page_index = -2
			e.refresh()


func refresh_events() -> void:
	for e in events:
		e.refresh()
	refresh_party_sprites()


## Game_Player.refresh / Game_Followers.refresh：队首的行走图给玩家，其余出战成员给队伍跟随
func refresh_party_sprites() -> void:
	if player == null:
		return
	var s := XState.current
	var leader: XActor = s.leader() if s else null
	if leader:
		# 更衣的替换形象只换玩家（Star_ChangeClothes 改 Game_Player 的 characterName／characterIndex，见 XChangeClothes）
		var img := XChangeClothes.player_image(s, str(leader.data().characterName), int(leader.data().characterIndex))
		player.set_image(img[0], img[1])
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
## Game_Party.onPlayerWalk（YEP_CoreEngine 包装同）：全队含后备各自 Game_Actor.onPlayerWalk，开头 clearResult。
## 上场结束时去掉的 removeAtBattleEnd 状态留在 removedStates 里，走一步才清，下一场开战标签才能再挂上。
static func on_player_walk(s: XState) -> void:
	for a in s.members():
		if a != null:
			a.runtime_result = XResourceContext.empty_result()

func _on_player_step() -> void:
	# Game_Player.increaseSteps：乘载具时不计队伍步数（isNormal）
	if not in_vehicle():
		XState.current.steps += 1
	on_player_walk(XState.current)
	# 玩家接触：踩上「角色下方/上方」事件，或撞上同层事件时在 _on_bump 处理；乘飞艇时不触发（canStartLocalEvents）
	for e in events:
		if can_start_local_events() and e.grid == player.grid and [1, 2].has(e.trigger()) and not e.is_normal_priority():
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
	# Game_Player.triggerButtonAction：先上下载具；乘飞艇时不触发确认键事件（canStartLocalEvents）
	if get_on_off_vehicle() or not can_start_local_events():
		return
	var front := player.front_cell(player.direction)
	for e in events:
		if e.grid == player.grid and e.trigger() == 0 and not e.is_normal_priority():
			await run_event(e)
			return
	for e in events:
		if e.grid == front and [0, 1, 2].has(e.trigger()) and e.is_normal_priority():
			await run_event(e)
			return


func _physics_process(_delta: float) -> void:
	_update_hotkeys()
	_hang_up_physics()
	_update_shake()
	_update_flash()
	if XState.current and not _menu_open:
		XState.current.screen.update()
		if not _in_battle:
			_update_vehicle()
	_sync_followers_look()
	# 玩家朝同层事件走却被挡住：MV 的 checkEventTriggerTouch（触发 1/2）；挂机中不能手动移动；乘飞艇时不触发
	if busy or player == null or player.is_moving() or XHangUp.is_active(XState.current) or not can_start_local_events():
		return
	var d := player._input_dir()
	if d == 0:
		return
	var front := player.front_cell(d)
	for e in events:
		if e.grid == front and [1, 2].has(e.trigger()) and e.is_normal_priority():
			run_event(e)
			return


## Game_Map.tileEventsXy：该格上当前页图像是图块、优先级「角色下方」的事件的图块编号（通行判定用）
func _tile_events_at(x: int, y: int) -> Array:
	var out := []
	for e in events:
		if e.tile_id > 0 and e.priority_type == 0 and e.grid.x == x and e.grid.y == y:
			out.append(e.tile_id)
	return out


## 修行指引区段里程碑（installNativeGuidanceRuntime 的 Scene_Map.update）：没有事件在跑时每 30 帧查一次，
## 修行进度层所在区段没看过就记看过、显示本段说明（每段一次）
func _check_milestone() -> void:
	_milestone_tick += 1
	if _milestone_tick % 30:
		return
	var s := XState.current
	var seg := XGuide.pending_milestone(s)
	if seg.is_empty():
		return
	XGuide.seen(s, "seg:" + str(seg.key), true)
	_set_busy(true)
	var interp := MVInterpreter.new(self, map_id, 0, XGuide.page_list(XGuide.milestone_texts(seg)))
	await interp.run()
	_set_busy(false)
	refresh_events()


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
	var rerun_key := "%d:%d:%d" % [map_id, ev_id, e.page_index]
	var interp := MVInterpreter.new(self, map_id, ev_id, e.command_list())
	await interp.run()
	# 事件里若有场所移动，旧地图的事件节点已释放，之后不能再访问 e
	if not interp.skipped.is_empty():
		skipped_log.append_array(interp.skipped)
		print("[xiyou] 事件 %d 跳过 %d 条：%s" % [ev_id, interp.skipped.size(), JSON.stringify(interp.skipped.slice(0, 3))])
	_set_busy(false)
	refresh_events()
	if RERUN_AFTER_PAGE.has(rerun_key) and is_instance_valid(e) and "%d:%d:%d" % [map_id, ev_id, e.page_index] != rerun_key:
		await run_event(e)


func _set_busy(b: bool) -> void:
	busy = b
	busy_changed.emit(b)


# ---- 遇敌（MV Game_Player.makeEncounterCount / makeEncounterTroopId）----
func _make_encounter_count() -> void:
	var n := int(map_data.get("encounterStep", 30))
	var stream := XState.current.world_random()
	encounter_count = stream.next_int_inclusive(0, n - 1, "encounter_steps") + stream.next_int_inclusive(0, n - 1, "encounter_steps") + 1

func _encounter() -> void:
	_make_encounter_count()
	var region := lower.region(player.grid.x, player.grid.y)
	var list: Array = map_data.encounterList.filter(func(en): return en.regionSet.is_empty() or en.regionSet.has(float(region)) or en.regionSet.has(region))
	var total := 0
	for en in list:
		total += int(en.weight)
	if total <= 0:
		return
	var troop := encounter_troop(list, XState.current.world_random().next_int_inclusive(0, total - 1, "encounter_troop"))
	# 设置「禁用遇敌」：仍重置步数并抽敌群，只是不进战斗（executeEncounter 返回 false）
	if troop <= 0 or XConfig.flag("ydgb"):
		return
	_set_busy(true)
	await start_battle(troop, true, false, true)  # 随机遇敌：BattleManager.onEncounter 掷先制／偷袭
	_set_busy(false)


## Game_Player.canEncounter：没有「无遇敌」队伍能力、遇敌未被指令 136 禁止、不乘飞艇、不在强制移动路线中
func can_encounter() -> bool:
	var s := XState.current
	return not s.party_ability(1) and s.encounter_enabled and not in_airship() and not player.is_route_forcing()


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


# ---- 飞艇（Game_Player／Game_Vehicle 的载具部分；全工程只有飞艇在用，小船、大船原版没放出来）----
func in_vehicle() -> bool:
	return XState.current != null and XState.current.vehicle_type != "walk"


## 头顶名牌：玩家精灵透明时随精灵隐藏；飞艇的那张只在玩家坐着它、位置重合时显示（Star_Designation updateOther）
func _update_plates() -> void:
	var s := XState.current
	if player_plate != null:
		player_plate.place(0.0 if player.is_object() else 6.0)
		player_plate.visible = not player.transparent
		player_plate.refresh(s)
	if airship_plate != null and is_instance_valid(airship):
		airship_plate.place(0.0 if airship.is_object() else 6.0)
		airship_plate.visible = in_airship() and airship.real == player.real
		airship_plate.refresh(s)


func in_airship() -> bool:
	return XState.current != null and XState.current.vehicle_type == "airship"


## Game_Player.canStartLocalEvents：乘飞艇时确认键、接触都不触发地图事件（自动执行、并行照常）
func can_start_local_events() -> bool:
	return not in_airship()


## Game_Player.canMove 的载具部分：收拢跟随、上下过程中不能动；飞艇升到最高才能飞（Game_Vehicle.canMove）
func vehicle_can_move() -> bool:
	if _vehicle_gathering or _vehicle_getting_on or _vehicle_getting_off:
		return false
	return not in_airship() or int(XState.current.vehicle("airship").altitude) >= AIRSHIP_MAX_ALTITUDE


## O-117：乘飞艇时（vehicle_type 不是走路，含升降中）锁地图传送与挂机
func _vehicle_menu_locked() -> bool:
	return SAFE_AIRSHIP_MENU and in_vehicle()


## Game_Player.getOnOffVehicle
func get_on_off_vehicle() -> bool:
	return get_off_vehicle() if in_vehicle() else get_on_vehicle()


## Game_Player.getOnVehicle：飞艇要站在同一格（Game_Vehicle.pos 只认停在本图的）；收拢跟随后在 _update_vehicle 里上
func get_on_vehicle() -> bool:
	var s := XState.current
	var v := s.vehicle("airship")
	if int(v.mapId) == map_id and int(v.x) == player.grid.x and int(v.y) == player.grid.y:
		s.vehicle_type = "airship"
		_vehicle_getting_on = true
		_vehicle_gathering = true
	return _vehicle_getting_on


## Game_Player.getOffVehicle：能降落时朝下、跟随叠到脚下、熄火放回地图 BGM、速度 4、取消穿透、重算遇敌步数；降到最低才变回走路
func get_off_vehicle() -> bool:
	if not airship_land_ok(player.grid):
		return false
	var s := XState.current
	var v := s.vehicle(s.vehicle_type)
	player.set_direction(2)
	for f in followers:
		f.synchronize(player.grid, player.direction)
	# Game_Vehicle.getOff：resetDirection、replayWalkingBgm
	v.driving = false
	v.direction = 4
	if s.walking_bgm is Dictionary:
		play_bgm(s.walking_bgm)
	_vehicle_getting_off = true
	player.vehicle_speed = 0
	player.move_speed = 4
	s.player_move_speed = 4   # Game_Player.getOffVehicle：setMoveSpeed(4)
	player.through = false
	_make_encounter_count()
	_vehicle_gathering = true
	return true


## Game_Vehicle.isLandOk（飞艇）：Game_Map.isAirshipLandOk 且该格没有事件。Game_Map.eventsXy 含暂时消除的事件；
## 切片没放的事件按原位置算（原版它们都在图上）
func airship_land_ok(c: Vector2i) -> bool:
	if not lower.is_airship_land_ok(c.x, c.y):
		return false
	var placed := {}
	for e in events:
		placed[e.event_id] = true
		if e.grid == c:
			return false
	for ev in map_data.get("events", []):
		if ev != null and not placed.has(int(ev.id)) and int(ev.x) == c.x and int(ev.y) == c.y:
			return false
	return true


## 每帧（地图 update，战斗与菜单中不跑）：Game_Vehicle.updateAirshipAltitude、Game_Followers 收拢、Game_Player.updateVehicle
func _update_vehicle() -> void:
	var s := XState.current
	if player == null or not is_instance_valid(player):
		return
	var v := s.vehicle("airship")
	if bool(v.driving) and int(v.altitude) < AIRSHIP_MAX_ALTITUDE:
		v.altitude = int(v.altitude) + 1
	elif not bool(v.driving) and int(v.altitude) > 0:
		v.altitude = int(v.altitude) - 1
	if _vehicle_gathering:
		if not followers.any(func(f): return f.is_moving()):
			_followers_step()
		if _followers_gathered():
			_vehicle_gathering = false
	if in_vehicle() and not _vehicle_gathering:
		if _vehicle_getting_on:
			if not player.is_moving():
				_finish_get_on(v)
		elif _vehicle_getting_off:
			if int(v.altitude) <= 0:
				# Game_Player.updateVehicleGetOff
				_vehicle_getting_off = false
				s.vehicle_type = "walk"
				player.transparent = false
				player.queue_redraw()
		elif bool(v.driving):
			# 原版不在上下过程中就是驾驶中；这里多判一次 driving，测试直接改 vehicle_type 时不把停着的飞艇拖走
			_sync_vehicle(v)
	_refresh_airship_sprite(v)


## Game_Followers.areGathered：显示中的跟随都停下、站在玩家格上
func _followers_gathered() -> bool:
	return not followers.any(func(f): return f.visible and f.character_name != "" and (f.is_moving() or f.grid != player.grid))


## Game_Player.updateVehicleGetOn＋Game_Vehicle.getOn：朝向取飞艇的、速度 6、透明、穿透；存下地图 BGM 放飞艇的
func _finish_get_on(v: Dictionary) -> void:
	player.set_direction(int(v.direction))
	player.vehicle_speed = 6
	_vehicle_getting_on = false
	player.transparent = true
	player.through = true
	player.queue_redraw()
	v.driving = true
	XState.current.walking_bgm = _bgm_audio.duplicate() if _bgm_audio is Dictionary else null
	_play_vehicle_bgm(v)


## Game_Vehicle.playBgm：140 改过的，否则 System 的飞艇 BGM
func _play_vehicle_bgm(v: Dictionary) -> void:
	play_bgm(v.bgm if v.bgm is Dictionary else XDB.system().get("airship", {}).get("bgm", {}))


## Game_Vehicle.syncWithPlayer
func _sync_vehicle(v: Dictionary) -> void:
	v.mapId = map_id
	v.x = player.grid.x
	v.y = player.grid.y
	v.direction = player.direction


## Game_Follower.update（每个逻辑帧；进图放好飞艇后也跑一次）：透明、不透明度跟着玩家（上下飞艇时与玩家同帧变透明）
func _sync_followers_look() -> void:
	if player == null or not is_instance_valid(player):
		return
	for f in followers:
		if f.transparent != player.transparent or f.opacity != player.opacity:
			f.transparent = player.transparent
			f.opacity = player.opacity
			f.queue_redraw()


## 进图与同图移动（Game_Player.locate → Game_Vehicle.refresh）：驾驶中的飞艇跟到当前图玩家处，玩家照飞行状态；建飞艇精灵。
## 读档时不在存档里的上下过程按高度补：在载具上但没驾驶、高度为 0＝正在上，高度大于 0＝正在下
func _place_vehicle() -> void:
	var s := XState.current
	var v := s.vehicle("airship")
	if in_airship():
		if bool(v.driving):
			_vehicle_getting_on = false
			_vehicle_getting_off = false
			player.transparent = true
			player.through = true
			player.vehicle_speed = 6
			_sync_vehicle(v)
			_play_vehicle_bgm(v)
		elif not _vehicle_getting_on and not _vehicle_getting_off:
			if int(v.altitude) > 0:
				_vehicle_getting_off = true
				player.transparent = true
			else:
				_vehicle_getting_on = true
		elif _vehicle_getting_off:
			player.transparent = true
	if airship != null and is_instance_valid(airship):
		airship.queue_free()
	airship = MVCharacter.new()
	airship.name = "Airship"
	airship.tilemap = lower
	# Game_Vehicle.initMoveSpeed：飞艇 6。驾驶中每帧先抄玩家上一帧的位置、再按自己的速度走一帧，与玩家同速才正好重合（行走动画也按 6）
	airship.move_speed = 6
	chars.add_child(airship)
	airship.locate(int(v.x), int(v.y))
	airship_plate = XDesignationPlate.new()
	airship.add_child(airship_plate)
	airship_shadow = Sprite2D.new()
	airship_shadow.name = "AirshipShadow"
	var shadow_path := XDB.img_path("system", "Shadow1")
	airship_shadow.texture = load(shadow_path) if shadow_path != "" else null
	airship_shadow.centered = false
	if airship_shadow.texture != null:
		airship_shadow.offset = -Vector2(airship_shadow.texture.get_width() / 2.0, airship_shadow.texture.get_height())
	airship_shadow.z_index = AIRSHIP_SHADOW_Z
	airship_shadow.z_as_relative = false
	airship.add_child(airship_shadow)
	_refresh_airship_sprite(v)
	_sync_followers_look()


## Game_Vehicle.refresh／updateAirship：只在停在本图时显示；驾驶中跟着玩家、在角色上方并播放行走动画，停着时在角色下方
func _refresh_airship_sprite(v: Dictionary) -> void:
	if airship == null or not is_instance_valid(airship):
		return
	if airship.character_name != str(v.characterName) or airship.character_index != int(v.characterIndex):
		airship.set_image(str(v.characterName), int(v.characterIndex))
	airship.transparent = int(v.mapId) != map_id
	if bool(v.driving):
		airship.grid = player.grid
		airship.real = player.real
	elif airship.grid != Vector2i(int(v.x), int(v.y)):
		airship.locate(int(v.x), int(v.y))
	airship.direction = int(v.direction)
	airship.walk_anime = bool(v.driving)
	airship.step_anime = int(v.altitude) >= AIRSHIP_MAX_ALTITUDE
	airship.priority_type = 0 if int(v.altitude) <= 0 else 2
	airship.altitude = int(v.altitude)
	airship._sync_position()
	_update_airship_shadow()


## Spriteset_Map.updateShadow：shadowX／Y＝飞艇不算高度的 screenX／Y（含行走图上移 6），透明度 255×高度÷48（不看飞艇是否透明）
func _update_airship_shadow() -> void:
	if airship_shadow == null or not is_instance_valid(airship_shadow):
		return
	airship_shadow.position = Vector2(0, airship.altitude - (0.0 if airship.is_object() else 6.0))
	airship_shadow.modulate.a = float(airship.altitude) / AIRSHIP_MAX_ALTITUDE


# ---- 解释器服务 ----
func show_text(face: String, idx: int, lines: Array) -> void:
	await message.show_text(face, idx, lines)

func show_text_with_choices(face: String, idx: int, lines: Array, options: Array, cancel_type: int) -> int:
	return await message.show_text_with_choices(face, idx, lines, options, cancel_type)

## 文字/选项/数值输入（XMessageBox.run 的参数）
func show_message(msg: Dictionary) -> int:
	return await message.run(msg)

## 指令 225 画面震动（Game_Screen.startShake／updateShake，每帧一次；Spriteset_Base 只横向偏移）
## Game_Screen.startFlash／updateFlash：颜色 [r, g, b, 强度]，每帧强度 ×(d−1)/d 直到 d 为 0；盖在地图上、窗口下
var _flash := {"color": Color(0, 0, 0, 0), "duration": 0}
var _flash_rect: ColorRect

func flash_screen(color: Array, duration: int) -> void:
	if _flash_rect == null:
		var layer := CanvasLayer.new()
		layer.layer = 5
		add_child(layer)
		_flash_rect = ColorRect.new()
		_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_flash_rect)
	_flash.color = Color(float(color[0]) / 255.0, float(color[1]) / 255.0, float(color[2]) / 255.0, float(color[3]) / 255.0)
	_flash.duration = duration
	_flash_rect.color = _flash.color

func _update_flash() -> void:
	if _flash.duration <= 0:
		return
	var d: int = _flash.duration
	_flash.color.a *= float(d - 1) / float(d)
	_flash.duration = d - 1
	if _flash_rect != null:
		_flash_rect.color = _flash.color

var _shake := {"power": 0.0, "speed": 0.0, "duration": 0, "dir": 1, "value": 0.0}

func shake_screen(power: int, speed: int, duration: int) -> void:
	_shake.power = float(power)
	_shake.speed = float(speed)
	_shake.duration = duration

func _update_shake() -> void:
	var k: Dictionary = _shake
	if k.duration > 0 or k.value != 0.0:
		var delta: float = k.power * k.speed * k.dir / 10.0
		if k.duration <= 1 and k.value * (k.value + delta) < 0:
			k.value = 0.0
		else:
			k.value += delta
		if k.value > k.power * 2:
			k.dir = -1
		if k.value < -k.power * 2:
			k.dir = 1
		k.duration -= 1
	if camera:
		camera.offset.x = roundf(k.value)

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
	_bgm_audio = (audio as Dictionary).duplicate() if audio is Dictionary and name != "" else null
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
func start_battle(troop_id: int, can_escape: bool, can_lose: bool, random_encounter := false) -> int:
	# BattleManager.saveBgmAndBgs/playBattleBgm：地图音乐不能和战斗音乐叠播，返回保留播放位置。
	me.stop()
	bgm.stream_paused = true
	bgs.stream_paused = true
	hud.visible = false
	var shot := await _snapshot()
	# 原版战斗没有 _tipSpr；只保留快照里的那一帧，活提示在后台继续倒数。
	difficulty_notice.hide()
	XPartySkills.battle_start(XState.current)  # BattleManager.startBattle 包装：装备学技能变了刷共享、成员变了刷羁绊
	var battle := XBattleScene.new()
	battle.setup(troop_id, can_escape, can_lose, battle_map(), shot, random_encounter)
	ui.add_child(battle)
	ui.move_child(hang_overlay, -1)
	_in_battle = true
	# 战斗期间 Scene_Map 不更新（$gameMap／$gamePlayer.update 都不跑）：地图上的玩家、事件、跟随者不走动、不取随机数。
	# 挂机计时在本场景 _physics_process，照常走。
	chars.process_mode = Node.PROCESS_MODE_DISABLED
	var result: int = await battle.finished
	if is_instance_valid(chars):
		chars.process_mode = Node.PROCESS_MODE_INHERIT
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
	XItemMarks.deploy_start(XState.current)  # 战后回地图＝Scene_Map.start
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


## 主菜单「真气」：Game_Map.setupStartingEvent 里由地图解释器执行 CodexZhenqi.retreat（事件 ID 为 0）
func run_zhenqi_retreat() -> void:
	if busy:
		return
	_set_busy(true)
	await XZhenqiRetreat.run(self)
	_set_busy(false)
	refresh_events()


## Consume the captured session's shared slot; an old menu cannot drain a new game.
func run_reserved_common_event(owner: XState) -> void:
	if owner == null or owner != XState.current or busy or _menu_open or owner.peek_common_event() <= 0:
		return
	await run_common_event(owner.peek_common_event(), owner)


## 公共事件（事件 ID 为 0）。预约消费按原版先 setup 游标，再 clear，再执行。
func run_common_event(id: int, reservation: XState = null) -> void:
	var ce := XDB.rec("CommonEvents", id)
	if busy:
		return
	if ce.is_empty():
		# 预约了不存在的公共事件：清槽，免得 _process 每帧看到预约而永远不查自动执行事件（原版此处直接报错）
		if reservation != null:
			reservation.clear_common_event()
		return
	_set_busy(true)
	var interp := MVInterpreter.new(self, map_id, 0, ce.list)
	if reservation != null:
		reservation.clear_common_event()
		XItemBagReturn.event_started(reservation, id)
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
		anim.target = ch    # Sprite_Animation._target 是这个角色：flashScope 1 闪光、3 隐藏作用在它身上
	return anim


func return_to_title() -> void:
	get_tree().change_scene_to_file.call_deferred("res://modes/xiyou/entry.tscn")


## $.toaster 提示（AXY_Toast 样式，见 XToast）
func toast(text: String) -> void:
	if XCasinoBatch.drawing:  # 批量抽奖每抽静音 $.toaster（installCasinoBatchRuntime）
		return
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
	# KMS_ShopInventory 在 Scene_Shop.prepare 补货并取走 apply 的库存组（先于宝珠商店的 start 关店）
	var stock_group := XShopStock.open(XState.current)
	# 宝珠运行时：只卖宝珠的商店（如二十一层神秘使者）一打开就提示并关闭（Scene_Shop.start → popScene）
	if XItemMarks.shop_orb_only(goods):
		toast(XItemMarks.ORB_SHOP_TEXT)
		return
	var shop := XShop.new()
	shop.setup(goods, purchase_only, stock_group)
	ui.add_child(shop)
	await shop.closed
	shop.queue_free()

func game_over() -> void:
	await message.show_text("", 0, ["全军覆没……将在方桌大厅复活。"])
	for a in XState.current.members():
		a.recover_all()
	await transfer(4, 14, 23, 8)

## 事件「打开存档画面」352：SceneManager.push(Scene_Save)（YEP 存档页，存档模式），关闭后回到地图
func open_save() -> void:
	hud.visible = false
	var page := XSaveScene.new()
	page.mode = "save"
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true


## 公共事件 431「成就」：SceneManager.push(Scene_AchievementBook)，关闭后回到地图（事件接着往下执行）
func open_achievements() -> void:
	hud.visible = false
	var page := XAchievementScene.new()
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true


## 公共事件 3「人物图鉴」：SceneManager.push(Scene_ActorBook)，关闭后回到地图
func open_actor_book() -> void:
	hud.visible = false
	var page := XActorBook.new()
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true


## 公共事件 2「怪物图鉴」：插件指令 EnemyBook open（SceneManager.push(Scene_EnemyBook)），关闭后回到地图
func open_enemy_book() -> void:
	hud.visible = false
	var page := XEnemyBookPage.new()
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true


## 仓库（PHWarehouse show <名字> → Scene_Warehouse）：仓库管理员「装备道具仓库」，关闭后回到地图
func open_warehouse() -> void:
	hud.visible = false
	var page := XWarehouseScene.new()
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true


## 角色仓库（SceneManager.push(Star_Scene_ActorWarehouse)）：仓库管理员「角色仓库」，关闭后回到地图；
## 存取时原版 $gamePlayer.refresh／$gameMap.requestRefresh，所以回地图后刷新队首行走图与事件页
func open_actor_warehouse() -> void:
	hud.visible = false
	var page := XActorWarehouseScene.new()
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true
	refresh_events()


## 星级仓库（SceneManager.push(Scene_StarSaveWarehouse／Scene_StarWarehouse)）：通用仓库管理员「存放」「取出」，关闭后回到地图
func open_star_warehouse(save_mode: bool) -> void:
	hud.visible = false
	var page := XStarWarehouseScene.new()
	page.save_mode = save_mode
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true


## 更衣（SceneManager.push(Scene_ChangeClothes)）：衣橱管理员「查看衣橱」，关闭后回到地图；
## 替换／还原形象改的是玩家行走图（原版 characterName 每帧现取），回地图后刷新队首行走图
func open_change_clothes() -> void:
	hud.visible = false
	var page := XChangeClothesScene.new()
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true
	refresh_party_sprites()


## 屏蔽掉落（SiShiTan-PingBi「pingbizhuangbei」→ SceneManager.push(Scene_PingbiMenu)）：公共事件 486、P 键，关闭回到地图
func open_pingbi() -> void:
	hud.visible = false
	var page := XPingbiScene.new()
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true


## 角色进阶（SceneManager.push(Scene_ActorAdvanced)）：奉神老妪「进阶」，关闭后回到地图
func open_actor_advanced() -> void:
	hud.visible = false
	var page := XActorAdvancedScene.new()
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true


## 技能遗忘（Star.RunForgetSkill，遗忘河之水 → 公共事件 83）：物品选中的角色，关闭后回到地图；没有选中角色时原版读 null 出错，不打开
func open_forget_skill(actor_id: int) -> void:
	if actor_id <= 0 or XDB.rec("Actors", actor_id).is_empty():
		return
	hud.visible = false
	var page := XForgetSkillScene.new().setup(XState.current.actor(actor_id))
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true


## 装备镶嵌图鉴（SceneManager.push(Scene_EquipInlayBook)）：魂灯商人「查看图鉴」，关闭后回到地图
func open_inlay_book() -> void:
	hud.visible = false
	var page := XInlayBook.new()
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true


## 公共事件 9011「天衣铺」：CodexYunshang.openCrafting() → SceneManager.push(Scene_Yunshang)，关闭后回到地图
func open_yunshang_shop() -> void:
	hud.visible = false
	var page := XYunshangShop.new()
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true


## 公共事件 9014「屠苏器谱」：CodexTusu.openForge() → B.openMenu → Scene_CodexBindMenu（XTusuForge），关闭后回到地图
func open_tusu_forge() -> void:
	hud.visible = false
	var page := XTusuForge.new()
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true


## 公共事件 9015「璇的星谱」：CodexXuan.openStarchart() → B.openMenu → Scene_CodexBindMenu（XXuanChartPage），关闭后回到地图
func open_xuan_chart() -> void:
	hud.visible = false
	var page := XXuanChartPage.new()
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true


## 公共事件 169「宠物」：SceneManager.push(Scene_PetSystem)，关闭后回到地图
func open_pets() -> void:
	hud.visible = false
	var page := XPetScene.new()
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true


## 修炼（SceneManager.push(Scene_ActorAttributePlusPoints)）：魔塔教师、二十六层小萝莉等，关闭后回到地图
func open_training() -> void:
	hud.visible = false
	var page := XTrainingScene.new()
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true


## 种族祝福（CodexRaces.openMenu → Scene_CodexBindMenu）：种族向导与进阶石公共事件，关闭后回到地图
func open_race_menu(rank := 0) -> void:
	hud.visible = false
	var page := XRaceMenu.new()
	page.rank = rank
	ui.add_child(page)
	await page.closed
	page.queue_free()
	hud.visible = true
	relocate_race_guide()


## R.relocateGuide（installNativeRaceRuntime）：大厅种族向导（EV22，备注 <CodexRaceGuide>）开局站在入塔门口，
## 选过族后挪到赌场 EV47 右边一格、面朝下，把门口让出来。进大厅（Game_Map.setup）与选族后各摆一次。
func relocate_race_guide() -> void:
	if map_id != 4:
		return
	var guide: MVEvent = null
	var gambler: Dictionary = {}
	for e in events:
		if e.event_id == 22 and str(e.data.get("note", "")) == "<CodexRaceGuide>":
			guide = e
	for ev in map_data.events:
		if ev is Dictionary and int(ev.id) == 47:
			gambler = ev
	if guide == null or gambler.is_empty():
		return
	var to := Vector2i(int(gambler.x) + 1, int(gambler.y)) if XRace.guide_chosen(XState.current) else Vector2i(int(guide.data.x), int(guide.data.y))
	if guide.grid != to:
		guide.locate(to.x, to.y)
		guide.set_direction(2)


func open_menu(resume_items: Dictionary = {}) -> void:
	# 挂机中不能呼叫菜单（Scene_Map.isMenuCalled）
	if busy or _menu_open or XHangUp.is_active(XState.current):
		return
	_menu_open = true
	var owner := XState.current
	XSound.system(1)  # Scene_Map.callMenu：SoundManager.playOk
	# Scene_Map.terminate：snapForBackground／snapForHangUp（含地图 HUD），挂机设置页的背景与范围图
	var shot := await _snapshot()
	hud.visible = false
	var menu := XMenu.new()
	menu.event_state = owner
	menu.map_shot = shot
	menu.player_tile = player_screen_tile()
	ui.add_child(menu)
	if not resume_items.is_empty():
		XItemScene.restore_return(menu,resume_items)
	await menu.closed
	var zhenqi := menu.zhenqi_requested
	menu.queue_free()
	_menu_open = false
	XItemMarks.deploy_start(XState.current)  # 回地图＝Scene_Map.start
	hud.visible = true
	_reset_transfer_button()
	await run_reserved_common_event(owner)
	if zhenqi:
		await run_zhenqi_retreat()
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
	if _vehicle_menu_locked():
		XSound.system(3)
		return
	var tip := XHangUp.ready_start(s, not map_data.get("encounterList", []).is_empty(), player.grid)
	if tip != "" and not busy:
		_set_busy(true)
		await message.show_text("", 0, [tip], 0, 1)
		_set_busy(false)


## YEP_ButtonCommonEvents（见 XMapHotkeys）：地图页面、没有事件和文字时按键预约公共事件；走动、挂机、载具都不挡
func hotkeys_open() -> bool:
	return XState.current != null and player != null and not busy and not _menu_open and transfer_page == null and can_start_local_events()


func _update_hotkeys() -> void:
	var id := _hotkeys.step(Input.is_physical_key_pressed)
	if id > 0 and hotkeys_open():
		XState.current.reserve_common_event(id)


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
	player.move_speed = player.walk_speed()
	# 回原点照 moveTowardPosition 的 deltaXFrom：循环地图上朝较近的一边走
	var back_to: Vector2i = player.grid + lower.delta(s.hang_up_origin, player.grid)
	if map_data.get("encounterList", []).is_empty():
		return XHangUp.toward(player.grid, back_to)
	return XHangUp.next_dirs(s, player.grid, back_to)


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
	if _menu_open or (SAFE_TRANSFER_BUTTON and busy) or _vehicle_menu_locked():
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
	var owner := XState.current
	owner.reserve_common_event(10)
	await run_reserved_common_event(owner)


## 开战时交给 XBattleScene 的地图数据：283 改过战斗背景就当作「地图指定」这两张（Spriteset_Battle.battleback1Name 先看 $gameMap）
func battle_map() -> Dictionary:
	if battleback_override.is_empty():
		return map_data
	var bmap := map_data.duplicate()
	bmap.specifyBattleback = true
	bmap.battleback1Name = battleback_override[0]
	bmap.battleback2Name = battleback_override[1]
	return bmap


## 283 更改战斗背景：之后在本图开的战斗用这两张图（三十一层可选首领、Map055 引路人前的公共事件 1387）
func change_battleback(name1: String, name2: String) -> void:
	XState.current.battleback = [name1, name2]
