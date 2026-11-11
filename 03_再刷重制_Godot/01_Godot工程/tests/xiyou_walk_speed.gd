extends Node
## 走 10 格的真实耗时（八戒 walk1，总装 11-07 复量请求）：入口照原版设好变速齿轮（XSpeedGear，每秒 96 帧），真实地图场景里按住方向键，
## 量玩家走完 10 格用的物理帧数与墙钟秒数，对原版。
## 原版（冻结 v0.28／v0.62.12 都一样，jsdom 参照 newGame 后实测）：玩家 moveSpeed 4，ConfigManager.alwaysDash 默认 true（不按 Shift 就跑），
## 跑时 realMoveSpeed 5；rpg_οbjects.js 的 distancePerFrame＝2×2^速度÷256 → 跑一格 4 帧、按住 Shift 走一格 8 帧；
## Drill_SpeedGear 1.6 使 SceneManager._deltaTime＝1/96，每真实秒 96 帧 → 跑 10 格 40 帧≈0.417 秒，走 10 格 80 帧≈0.833 秒。
## 只按物理帧数断言（重制每物理帧走一次角色更新，同原版每次 updateScene）：跑一格 4 帧、走一格 8 帧，整段 10 格允许多 1 帧（起步那帧）；
## 加上入口设好每秒 96 个物理帧，秒数＝帧数÷96 就和原版一样。墙钟受机器负载与 CI 快进影响，不断言（11-07 云端墙钟比 0.83 挂过），只打印。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const WaitBudget := preload("res://tests/wait_budget.gd")
const TILES := 10
const ORIGINAL := {"run": {"frames": 40, "seconds": 40.0 / 96.0}, "walk": {"frames": 80, "seconds": 80.0 / 96.0}}

var results: Array = []
var map: XMapScene


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	print(("PASS " if ok else "FAIL ") + name + " " + JSON.stringify(detail))
	return ok


## 一段向右 TILES＋1 格都能走、没有事件的横排（通行按地图图块）
func _find_row(m: XMapScene) -> Vector2i:
	var t := m.lower
	var busy := {}
	for e in m.events:
		busy[e.grid] = true
	for y in range(1, t.height - 1):
		for x in range(1, t.width - TILES - 2):
			var ok := true
			for i in range(TILES + 1):
				var c := Vector2i(x + i, y)
				if busy.has(c) or (i < TILES + 1 and not (t.is_passable(c.x, c.y, 6) and t.is_passable(c.x + 1, c.y, 4))):
					ok = false
					break
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _open(at: Vector2i) -> XMapScene:
	var s := XState.current
	s.map_id = 4
	s.x = at.x
	s.y = at.y
	s.direction = 6
	get_tree().change_scene_to_file(MAP_SCENE)
	var t := WaitBudget.new(60000)
	while t.waiting():
		var m = get_tree().current_scene
		if m is XMapScene and m.map_id == 4 and m.player != null and not m.busy:
			return m
		await get_tree().process_frame
	return null


func _measure(mode: String) -> Dictionary:
	var start := map.player.grid
	var shift := mode == "walk"
	if shift:
		Input.action_press("mv_dash")
	Input.action_press("ui_right")
	# 从起步那一帧起算（格子一变就是开步）
	var t := WaitBudget.new(20000)
	while t.waiting() and map.player.grid == start:
		await get_tree().physics_frame
	var f0 := Engine.get_physics_frames() - 1
	var ms0 := Time.get_ticks_usec() - 1000000 / Engine.physics_ticks_per_second
	while t.waiting() and (map.player.grid.x < start.x + TILES or map.player.is_moving()):
		if map.player.grid.x >= start.x + TILES:
			Input.action_release("ui_right")
		await get_tree().physics_frame
	var frames := Engine.get_physics_frames() - f0
	var seconds := (Time.get_ticks_usec() - ms0) / 1000000.0
	Input.action_release("ui_right")
	Input.action_release("mv_dash")
	return {"frames": frames, "seconds": seconds, "end": map.player.grid.x - start.x}


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_walk_speed"
	XConfig.path_override = XSave.dir().path_join("options.json")
	# 新源大厅首次进入的漩涡过场（Map4 EV76 自动执行，CodexWhisper.seen('rift1') 为假时播，占住地图约 5000 帧）：
	# 跑步计时在大厅 Map004：过场占着地图时玩家不动，run.frames 成了 331。过场由 xiyou_opening_branches c_rift_cutscene 单测，这里删旧配置、标成看过（同 xiyou_actor_p0／xiyou_flow，八戒 DD³）
	DirAccess.remove_absolute(ProjectSettings.globalize_path(XConfig.path_override))
	XConfig._loaded_path = ""
	XConfig.whisper_mark("rift1")
	XConfig.whisper_mark("rift2")   # 漩涡二阶段过场（XRift，Map4 EV203：rift1 看过就播）同样占住大厅，一并记成看过
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	XSpeedGear.HEADLESS_APPLY = true
	XSpeedGear.apply()
	_check("gear_96fps", Engine.physics_ticks_per_second == 96, Engine.physics_ticks_per_second)
	XState.new_game(3, 1, [8, 9, 10])
	XState.current.followers_visible = false
	map = await _open(Vector2i(10, 10))
	if not _check("map_loaded", map != null):
		return _finish()
	var row := _find_row(map)
	if not _check("row_found", row.x >= 0, row):
		return _finish()
	for mode in ["run", "walk"]:
		map = await _open(row)
		for i in 5:
			await get_tree().physics_frame
		var got := await _measure(mode)
		var want: Dictionary = ORIGINAL[mode]
		_check(mode + ".tiles", got.end == TILES, got)
		# 帧数：整段按住时每格同原版；第一格起步那帧计入，允许差 1 帧
		_check(mode + ".frames", absi(int(got.frames) - int(want.frames)) <= 1, [got, want])
		var per_tile := 4 if mode == "run" else 8
		_check(mode + ".frames_per_tile", int(want.frames) == per_tile * TILES and (int(got.frames) - 1) / TILES == per_tile, [got.frames, per_tile])
		print("%s 10 格：重制 %d 帧＝游戏时间 %.3f 秒（墙钟 %.3f 秒，仅供参考），原版 %d 帧＝%.3f 秒" % [mode, got.frames, float(got.frames) / Engine.physics_ticks_per_second, got.seconds, want.frames, want.seconds])
	_finish()


func _finish() -> void:
	XSpeedGear.reset()
	XSpeedGear.HEADLESS_APPLY = false
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_walk_speed", "passed": results.size() - failed.size(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
