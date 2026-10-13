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
var events: Array[MVEvent] = []
var camera: Camera2D
var ui: CanvasLayer
var message: XMessageBox
var fader: ColorRect
var bgm: AudioStreamPlayer
var se: AudioStreamPlayer
var hud: Control
var busy := false
var encounter_count := 0
var skipped_log: Array = []
var toasts: Array = []              # 出现过的提示文字（测试核对用）
var popups: Array = []              # 出现过的获得提示文字（测试核对用）
var _pending_popups: Array = []     # 本帧获得的物品（MOG_TreasurePopup 按帧成批，序号决定错开）
var _bgm_name := ""
var _menu_open := false


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
	bgm = AudioStreamPlayer.new()
	add_child(bgm)
	se = AudioStreamPlayer.new()
	add_child(se)
	camera = Camera2D.new()
	add_child(camera)
	var s := XState.current
	await load_map(s.map_id, s.x, s.y, s.direction)


func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = XUI.theme()
	ui.add_child(hud)
	# 触屏用菜单入口（原版靠右键/双指点开菜单）；做成小号 MV 窗口
	var menu_btn := XUI.button("菜单", 48)
	menu_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_btn.add_theme_stylebox_override("normal", XUI.panel())
	menu_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_btn.offset_left = -120
	menu_btn.offset_top = 12
	menu_btn.offset_right = -12
	menu_btn.pressed.connect(open_menu)
	hud.add_child(menu_btn)
	# 地图名（Olivia_MapDisplayNameCore）：暗底条，从 y=18 滑到 48 淡入，停留，再滑到 78 淡出（各 60 帧）
	var plate := XUI.dimmer(false, true)
	plate.name = "MapNamePlate"
	plate.size = Vector2(420, 36)
	plate.position = Vector2(0, 18)
	plate.modulate.a = 0.0
	hud.add_child(plate)
	var map_name := XUI.label("", XUI.FONT_SIZE)
	map_name.name = "MapName"
	map_name.position = Vector2(80, -2)
	plate.add_child(map_name)


func _show_map_name(text: String) -> void:
	var plate: Control = hud.find_child("MapNamePlate", true, false)
	var label: Label = plate.find_child("MapName", true, false)
	label.text = text
	if text == "":
		plate.modulate.a = 0.0
		return
	plate.size.x = 80 + label.get_minimum_size().x + 200
	plate.position.y = 18
	plate.modulate.a = 0.0
	var t := plate.create_tween()
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
	player = MVPlayer.new()
	player.tilemap = lower
	chars.add_child(player)
	var leader: XActor = s.members()[0] if not s.party.is_empty() else null
	if leader:
		player.set_image(str(leader.data().characterName), int(leader.data().characterIndex))
	player.locate(x, y)
	player.direction = d if d > 0 else 2
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
	play_bgm(map_data.get("bgm", {}))
	_make_encounter_count()


func _process(delta: float) -> void:
	if XState.current:
		XState.current.play_seconds += delta
	if player:
		player.input_enabled = not busy and not _menu_open
		var s := XState.current
		s.x = player.grid.x
		s.y = player.grid.y
		s.direction = player.direction
	if not _pending_popups.is_empty():
		_flush_popups()
	if not busy and not _menu_open and player:
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


func refresh_events() -> void:
	for e in events:
		e.refresh()


# ---- 触发 ----
func _on_player_step() -> void:
	XState.current.steps += 1
	# 玩家接触：踩上「角色下方/上方」事件，或撞上同层事件时在 _on_bump 处理
	for e in events:
		if e.grid == player.grid and [1, 2].has(e.trigger()) and not e.is_normal_priority():
			await run_event(e)
			return
	if not map_data.encounterList.is_empty():
		encounter_count -= 1
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
	# 玩家朝同层事件走却被挡住：MV 的 checkEventTriggerTouch（触发 1/2）
	if busy or player == null or player.is_moving():
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
	if list.is_empty():
		return
	var total := 0
	for en in list:
		total += int(en.weight)
	var r := randi_range(0, total - 1)
	for en in list:
		r -= int(en.weight)
		if r < 0:
			_set_busy(true)
			await start_battle(int(en.troopId), true, false)
			_set_busy(false)
			return


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

## 战斗：返回 0 胜利 1 逃跑 2 战败（MV 语义）
func start_battle(troop_id: int, can_escape: bool, can_lose: bool) -> int:
	var prev := _bgm_name
	hud.visible = false
	var shot := await _snapshot()
	var battle := XBattleScene.new()
	battle.setup(troop_id, can_escape, can_lose, map_data, shot)
	ui.add_child(battle)
	var result: int = await battle.finished
	battle.queue_free()
	hud.visible = true
	_bgm_name = ""
	play_bgm({"name": prev, "volume": 90})
	refresh_events()
	return result

## Scene_Map.snapForBattleBackground：隐藏窗口层（对话框、地图名、菜单按钮）后截取地图画面，
## 裁成 1280×720 画布范围。无画面（测试）时返回 null。
func _snapshot() -> Texture2D:
	if DisplayServer.get_name() == "headless":
		return null
	var was := message.visible
	message.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	message.visible = was
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


## jQuery toaster：右上角提示框，几秒后淡出
func toast(text: String) -> void:
	toasts.append(text)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", XUI.panel())
	box.add_child(XUI.label(text, 22))
	var stack: VBoxContainer = hud.get_node_or_null("Toasts")
	if stack == null:
		stack = VBoxContainer.new()
		stack.name = "Toasts"
		stack.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		stack.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		stack.offset_top = 72
		stack.offset_right = -12
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(stack)
	stack.add_child(box)
	var tw := box.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(box, "modulate:a", 0.0, 0.6)
	tw.tween_callback(box.queue_free)


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
	if busy or _menu_open:
		return
	_menu_open = true
	var menu := XMenu.new()
	ui.add_child(menu)
	await menu.closed
	menu.queue_free()
	_menu_open = false
	if player:
		var leader: XActor = XState.current.members()[0]
		player.set_image(str(leader.data().characterName), int(leader.data().characterIndex))
