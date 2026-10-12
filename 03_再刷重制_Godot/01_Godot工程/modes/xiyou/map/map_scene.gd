class_name XMapScene
extends Node2D
## 西游地图场景：图块（下层/上层）、角色、事件、镜头、遇敌，并为事件解释器提供画面服务。
## 只放切片配置 keepEvents 里列出的事件（首期精简）。

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
var _bgm_name := ""
var _menu_open := false


static func slice() -> Dictionary:
	var d = XDB.load_json("slice.json")
	return d if d is Dictionary else {}


func _ready() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	message = XMessageBox.new()
	ui.add_child(message)
	fader = ColorRect.new()
	fader.color = Color.BLACK
	fader.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = XUI.theme()
	ui.add_child(hud)
	var menu_btn := XUI.button("菜单", 52)
	menu_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_btn.offset_left = -130
	menu_btn.offset_top = 16
	menu_btn.offset_right = -16
	menu_btn.pressed.connect(open_menu)
	hud.add_child(menu_btn)
	var map_name := XUI.label("", 20, XUI.GOLD)
	map_name.name = "MapName"
	map_name.position = Vector2(20, 18)
	hud.add_child(map_name)


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
	var keep: Array = slice().get("keepEvents", {}).get(str(id), [])
	for ev in map_data.events:
		if ev == null or not keep.has(int(ev.id)):
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
	(hud.get_node("MapName") as Label).text = str(map_data.get("displayName", ""))
	play_bgm(map_data.get("bgm", {}))
	_make_encounter_count()
	await _run_autorun()


func _process(delta: float) -> void:
	if XState.current:
		XState.current.play_seconds += delta
	if player:
		player.input_enabled = not busy and not _menu_open
		var s := XState.current
		s.x = player.grid.x
		s.y = player.grid.y
		s.direction = player.direction
	if not busy and Input.is_action_just_pressed("ui_cancel"):
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


func _run_autorun() -> void:
	for e in events:
		if e.trigger() == 3:
			await run_event(e)


func run_event(e: MVEvent) -> void:
	if busy or e.command_list().is_empty():
		return
	_set_busy(true)
	if not e.direction_fix and e.trigger() == 0:
		e.set_direction(MVCharacter.reverse_dir(player.direction))
	var interp := MVInterpreter.new(self, map_id, e.event_id, e.command_list())
	await interp.run()
	if not interp.skipped.is_empty():
		skipped_log.append_array(interp.skipped)
		print("[xiyou] 事件 %d 跳过 %d 条：%s" % [e.event_id, interp.skipped.size(), JSON.stringify(interp.skipped.slice(0, 3))])
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

func fade(out: bool) -> void:
	var t := create_tween()
	t.tween_property(fader, "modulate:a", 1.0 if out else 0.0, 0.3)
	await t.finished

func transfer(id: int, x: int, y: int, d: int) -> void:
	if XDB.map(id).is_empty() or not slice().get("maps", []).has(id):
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
	var battle := XBattleScene.new()
	battle.setup(troop_id, can_escape, can_lose, map_data)
	ui.add_child(battle)
	hud.visible = false
	var result: int = await battle.finished
	battle.queue_free()
	hud.visible = true
	_bgm_name = ""
	play_bgm({"name": prev, "volume": 90})
	refresh_events()
	return result

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
