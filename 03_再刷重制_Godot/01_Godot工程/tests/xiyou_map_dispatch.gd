extends Node
## 地图事件分发（Codex 审查第 11、12 项，八戒 mapev1）：真实 XMapScene 上跑并行事件（触发 4）与自主移动（类型 2 接近玩家、类型 3 自定义路线、
## YEP_EventChasePlayer 逃离脚本）、强制路线与自主路线的暂停／恢复／频率，逐例对照 mv_oracle/map_dispatch_probe.cjs 的夹具
## （tests/fixtures/map_dispatch_oracle.json，冻结正式源真跑 $gameMap.update）。
## - par.*：地图照常逐帧跑（事件 _physics_process → MVEvent._update_parallel → XMapScene.start_parallel），看页、图像、位置、自开关、
##   放过的动画（XMapScene.animations_shown）与并行解释器的起停；Map032 的开关中途关、开，换图后旧图的并行不再放动画。
##   动画按真实长度等（参照里动画立即结束），所以 Map152 只比最终状态与动画次数；Map032 比动画相隔的帧数（允许差 1 帧）。
## - auto*：事件节点进树时就停掉 _physics_process，由本测试逐帧调 update_character（同参照逐帧 $gameMap.update，事件按编号依次更新），
##   逐帧记格子、朝向、页、图像、速度、频率、是否在跳，与参照的「变了才记一行」逐行比（含帧号与这一行之前停了几帧）。
##   参照的随机数固定 0.5，这里设 MVCharacter.fixed_random＝0.5；走路速度用默认值（move_distance_scale＝2，同正式版 distancePerFrame 翻倍），
##   另断言速度 3 走一格 16 帧（参照 Map093 事件 3）。
## - auto3.m149e33.skip：原版强制路线结束后自定义路线跳过一条（O-230，MVCharacter.route_resume_fix）。关掉开关逐行等于参照；
##   开着（默认）时左右来回不偏：强制路线之后仍在 10↔11 两格之间走。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const ORACLE := "res://tests/fixtures/map_dispatch_oracle.json"
const TIMEOUT_MS := 60000
const WaitBudget := preload("res://tests/wait_budget.gd")
const FIELDS := ["x", "y", "d", "page", "img", "imgIndex", "speed", "freq", "jump"]

var results: Array = []
var s: XState
var _freeze := false


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
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


## 手动逐帧的用例：角色一进树就不自己更新（在第一帧物理之前）
func _on_node_added(n: Node) -> void:
	if _freeze and n is MVCharacter:
		n.process_mode = Node.PROCESS_MODE_DISABLED


func _wait_map(map_id: int) -> XMapScene:
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while t0.waiting():
		var m = get_tree().current_scene
		if m is XMapScene and m.map_id == map_id and m.player != null and not m.events.is_empty():
			return m
		await get_tree().process_frame
	return null


func _open(spec: Dictionary) -> XMapScene:
	s = XState.new_game(3, 1, [8, 9, 10])
	for id in spec.get("party", []):
		s.add_actor(int(id))
	for id in spec.get("switches", []):
		s.set_switch(int(id), true)
	s.map_id = int(spec.map)
	s.x = int(spec.x)
	s.y = int(spec.y)
	s.direction = int(spec.get("d", 2))
	get_tree().change_scene_to_file(MAP_SCENE)
	return await _wait_map(int(spec.map))


static func _event(map: XMapScene, id: int) -> MVEvent:
	for e in map.events:
		if is_instance_valid(e) and e.event_id == id:
			return e
	return null


static func _row(e: MVEvent) -> Array:
	return [e.grid.x, e.grid.y, e.direction, e.page_index, e.character_name, e.character_index, e.move_speed, e.move_frequency, 1 if e.is_jumping() else 0]


static func _oracle_rows(track: Array) -> Array:
	var out := []
	for r in track:
		var row := [int(r.f), int(r.idle)]
		for k in FIELDS:
			row.append(r[k] if r[k] is String else int(r[k]))
		out.append(row)
	return out


func _run() -> void:
	GameApp.fast_forward()
	XSave.dir_override = "user://test_xiyou_map_dispatch"
	XConfig.path_override = XSave.dir().path_join("options.json")
	# 新源大厅首次进入的漩涡过场（Map4 EV76 自动执行，CodexWhisper.seen('rift1') 为假时播，占住地图约 5000 帧）：
	# par.m32e10.transfer 换到大厅后，过场里 EV75／EV77 的动画 136／678 会被当成「换图后旧图并行还在放动画」。过场由 xiyou_opening_branches c_rift_cutscene 单测，这里删旧配置、标成看过（同 xiyou_actor_p0／xiyou_flow，八戒 DD³）
	DirAccess.remove_absolute(ProjectSettings.globalize_path(XConfig.path_override))
	XConfig._loaded_path = ""
	XConfig.whisper_mark("rift1")
	XConfig.whisper_mark("rift2")   # 漩涡二阶段过场（XRift，Map4 EV203：rift1 看过就播）同样占住大厅，一并记成看过
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	get_tree().node_added.connect(_on_node_added)
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	_check("oracle_loaded", oracle != null and oracle.get("cases", []).size() >= 10)
	var old_random := MVCharacter.fixed_random
	var old_fix := MVCharacter.route_resume_fix
	MVCharacter.fixed_random = 0.5
	_tile_frames()
	for c in oracle.get("cases", []):
		_check(c.id + ":oracle_ok", c.errors.is_empty(), c.errors)
		if str(c.id).begins_with("par."):
			await _parallel_case(c)
		elif str(c.id) == "auto3.m149e33.forced":
			# 强制路线结束后原版跳过一条（这里跳过的是走不通的随机移动，开着修复时晚一帧起跳），逐行对照按原版比
			MVCharacter.route_resume_fix = false
			await _auto_case(c, c.id)
			MVCharacter.route_resume_fix = true
		elif str(c.id) == "auto3.m149e33.skip":
			MVCharacter.route_resume_fix = false
			await _auto_case(c, c.id + "#original")
			MVCharacter.route_resume_fix = true
			await _skip_fixed(c)
		else:
			await _auto_case(c, c.id)
	MVCharacter.fixed_random = old_random
	MVCharacter.route_resume_fix = old_fix
	await _finish()


## 默认速度下走一格的帧数：正式版速度 3 走一格 16 帧（参照 auto2.m93e3：开步那帧起 16 次更新走完），MV 默认是 32 帧
func _tile_frames() -> void:
	var ch := MVCharacter.new()
	ch.move_speed = 3
	ch.grid = Vector2i(1, 0)
	var n := 0
	while ch.is_moving() and n < 100:
		ch.update_character()
		n += 1
	_check("tile_frames_speed3", n == 16, n)
	ch.free()


# ---- 自主移动：逐帧手动更新，逐行对照 ----
func _auto_steps(c: Dictionary, label: String) -> Dictionary:
	var spec: Dictionary = c.setup
	var map_data := XDB.map(int(spec.map))
	var saved_route = null
	if spec.has("pageRoute"):
		var ev: Dictionary = map_data.events[int(spec.pageRoute.event)]
		saved_route = ev.pages[0].moveRoute
		ev.pages[0].moveRoute = spec.pageRoute.route.duplicate(true)
	_freeze = true
	var map := await _open(spec)
	_freeze = false
	if saved_route != null:
		map_data.events[int(spec.pageRoute.event)].pages[0].moveRoute = saved_route
	if not _check(label + ":map", map != null):
		return {}
	var tracks := {}
	var last := {}
	var idle := {}
	for id in spec.watch:
		tracks[str(int(id))] = []
		last[str(int(id))] = null
		idle[str(int(id))] = 0
	var record := func(f: int) -> void:
		for id in spec.watch:
			var k := str(int(id))
			var e := _event(map, int(id))
			var row := _row(e)
			if row != last[k]:
				last[k] = row
				tracks[k].append([f, idle[k]] + row)
			idle[k] = idle[k] + 1 if not e.is_moving() and not e.is_jumping() else 0
	record.call(0)
	for f in range(1, int(spec.frames) + 1):
		for a in spec.get("actions", []):
			if int(a.at) != f:
				continue
			if a.do == "route":
				_event(map, int(a.event)).force_move_route(a.route.duplicate(true))
		for e in map.events:
			e.update_character()
		record.call(f)
	return tracks


func _auto_case(c: Dictionary, label: String) -> void:
	var tracks := await _auto_steps(c, label)
	if tracks.is_empty():
		return
	for k in c.observed.tracks:
		var want := _oracle_rows(c.observed.tracks[k])
		var got: Array = tracks.get(k, [])
		var first := -1
		for i in range(maxi(want.size(), got.size())):
			if i >= want.size() or i >= got.size() or want[i] != got[i]:
				first = i
				break
		_check("%s:ev%s" % [label, k], first < 0, {"firstDiff": first, "want": want.slice(maxi(first - 1, 0), first + 2), "got": got.slice(maxi(first - 1, 0), first + 2), "wantRows": want.size(), "gotRows": got.size()})


## 开关开着：强制路线之后不跳条，事件一直在 10↔11 之间来回（原版会偏到 9↔10）
func _skip_fixed(c: Dictionary) -> void:
	var tracks := await _auto_steps(c, c.id + "#fixed")
	if tracks.is_empty():
		return
	var xs := {}
	for r in tracks["33"]:
		if int(r[0]) > 100:
			xs[int(r[2])] = true
	_check(c.id + "#fixed:no_drift", xs.keys().all(func(x): return x == 10 or x == 11) and xs.size() == 2, xs.keys())


# ---- 并行事件：地图照常逐帧跑 ----
func _parallel_case(c: Dictionary) -> void:
	var spec: Dictionary = c.setup
	var map := await _open(spec)
	if not _check(c.id + ":map", map != null):
		return
	var f0 := Engine.get_physics_frames()
	var oracle_anims: Array = c.observed.anims
	match str(c.id):
		"par.m152e8":
			var t := WaitBudget.new(TIMEOUT_MS)
			var e := _event(map, 8)
			while t.waiting() and is_instance_valid(e) and e.page_index != 2:
				await get_tree().physics_frame
			for i in 5:
				await get_tree().physics_frame
			var want: Dictionary = c.observed.tracks["8"][-1]
			_check(c.id + ":final", e.page_index == int(want.page) and e.grid == Vector2i(int(want.x), int(want.y)) and e.direction == int(want.d)
				and e.character_name == str(want.img) and e.character_index == int(want.imgIndex),
				{"got": _row(e), "want": want})
			_check(c.id + ":self_switch", s.self_switch(152, 8, "A") == c.observed.selfSwitches.has("8A"))
			_check(c.id + ":anims", map.animations_shown.map(func(a): return [a.target, a.anim]) == oracle_anims.map(func(a): return [int(a.target), int(a.anim)]), map.animations_shown)
			_check(c.id + ":parallel_stopped", e.parallel_interp == null and e.trigger() != 4)
			_check(c.id + ":not_busy", not map.busy)
		"par.m32e10.toggle":
			await _until(map, f0, 1)
			var first := _anim_frames(map)
			if not _check(c.id + ":started", first.size() >= 1 and not map.busy, {"anims": map.animations_shown, "busy": map.busy}):
				return
			var base: int = first[0]   # 参照第 1 帧放第一次动画
			var ev := _event(map, 10)
			for a in spec.actions:
				await _until(map, base - 1 + int(a.at) - 1, 0)
				s.set_switch(int(a.id), bool(a.value))
				map.refresh_events()
				if not bool(a.value):
					_check(c.id + ":stopped_on_page_change", ev.parallel_interp == null and ev.page_index == -1, {"page": ev.page_index})
			await _until(map, base - 1 + int(spec.frames), 0)
			var got := _anim_frames(map).map(func(f): return f - base + 1)
			var want := oracle_anims.map(func(a): return int(a.f))
			var ok := got.size() == want.size()
			for i in range(mini(got.size(), want.size())):
				ok = ok and absi(got[i] - want[i]) <= 1
			_check(c.id + ":anim_frames", ok, {"got": got, "want": want})
		"par.m32e10.transfer":
			await _until(map, f0, 1)
			var first := _anim_frames(map)
			if not _check(c.id + ":started", first.size() >= 1, map.animations_shown):
				return
			var ev := _event(map, 10)
			var interp := ev.parallel_interp
			await _until(map, first[0] + 98, 0)
			map.transfer(4, 12, 18, 2)
			var hub := await _wait_map(4)
			if not _check(c.id + ":arrived", hub != null):
				return
			# 淡出期间旧图还在更新（原版 Scene_Map 淡出时 $gameMap 照常 update），只看到达之后
			var arrived := Engine.get_physics_frames()
			_check(c.id + ":old_interp_cancelled", interp != null and interp.is_cancelled())
			var t0 := Engine.get_physics_frames()
			while Engine.get_physics_frames() < t0 + 400:
				await get_tree().physics_frame
			var after := hub.animations_shown.filter(func(a): return int(a.frame) >= arrived)
			_check(c.id + ":no_anim_after", after.is_empty() and hub.map_id == int(c.observed.mapNow), after)


func _anim_frames(map: XMapScene) -> Array:
	return map.animations_shown.filter(func(a): return a.anim == 76).map(func(a): return int(a.frame))


## 等到物理帧号 ≥ frame（min_anims > 0 时改为等到放过那么多次动画）
func _until(map: XMapScene, frame: int, min_anims: int) -> void:
	var t := WaitBudget.new(TIMEOUT_MS)
	while t.waiting():
		if min_anims > 0 and map.animations_shown.size() >= min_anims:
			return
		if min_anims == 0 and Engine.get_physics_frames() >= frame:
			return
		await get_tree().physics_frame


func _finish() -> void:
	for player in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await get_tree().create_timer(0.3, true, false, true).timeout
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_map_dispatch", "passed": results.size() - failed.size(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
