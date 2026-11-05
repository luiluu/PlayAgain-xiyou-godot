extends Node
## 进出战斗转场（battlefx1，XBattleTransition）：对照原版逐帧读数 tests/fixtures/battle_transition_oracle.json
## （冻结 v0.28 一层地图夹具，地图 5、玩家 11,13，ui_reference/battle_transition_ref.cjs）。
## - 公式：60 帧镜头缩放、地图层偏移（Spriteset_Base.updatePosition 取整）、黑幕淡出／淡入（Scene_Base.updateFade）。
## - 实战：同一地图同一位置 start_battle，逐帧记录（XBattleTransition.trace）遇敌演出的缩放与黑幕、第 30 帧放战斗 BGM、
##   开战系统音效 7、战斗淡入 24 帧且淡完才出指令窗、打完淡出 24 帧、回地图暗一帧；拉近时真实画面变换（Camera2D）对上原版的「shift＋q·s」。
## - 回退：XBattleTransition.ENABLED = false 时不放音效、不演出、不淡入淡出（原来的直接切）；无画面默认也不走（IN_HEADLESS）。
## 内存新游戏，不写存档。窗口模式加 -- --out=<目录> 截遇敌演出第 10、40 帧（battle_transition_n10／n40.png，对原版 enc_n10／n40）。

const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const FIXTURE := "res://tests/fixtures/battle_transition_oracle.json"
var results := []
var ref: Dictionary
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _until(cond: Callable, n := 3000) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _battle(map: XMapScene) -> XBattleScene:
	for c in map.ui.get_children():
		if c is XBattleScene and not c.is_queued_for_deletion():
			return c
	return null


func _near(a: float, b: float, eps := 0.001) -> bool:
	return absf(a - b) <= eps


func _run() -> void:
	ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	_formula()
	XMessageBox.auto = true
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.random_master = "2026110500000001"
	s.map_id = 5
	s.x = 11
	s.y = 13
	s.direction = 2
	get_tree().change_scene_to_file(MAP_SCENE)
	var ok := await _until(func(): return get_tree().current_scene is XMapScene and get_tree().current_scene.player != null and not get_tree().current_scene.busy)
	_check("map5_loaded", ok)
	var map: XMapScene = get_tree().current_scene
	await _frames(10)
	XMessageBox.auto = false
	map._set_busy(true)
	await _camera_math(map)
	await _live(map)
	await _rollback(map)
	XBattleTransition.IN_HEADLESS = false
	XBattleTransition.ENABLED = true
	XBattleTransition.trace = null
	_finish()


## 公式对原版：缩放、地图层偏移、黑幕
func _formula() -> void:
	var enc: Array = ref.encounter
	var at := Vector2(float(ref.zoomPoint[0]), float(ref.zoomPoint[1]))
	var bad := []
	for i in enc.size():
		var row: Array = enc[i]
		var n := i + 1
		var q := XBattleTransition.zoom_at(n)
		var sh := XBattleTransition.zoom_shift(at, q)
		if int(row[0]) != XBattleTransition.ENCOUNTER_FRAMES - n or not _near(q, float(row[1]), 0.0002) or sh != Vector2(float(row[3]), float(row[4])):
			bad.append([n, q, sh, row])
	_check("zoom_curve_and_shift_60", enc.size() == 60 and bad.is_empty(), bad)
	# 黑幕淡出：第 30 帧开始，24 帧到 255（原版第 30～53 帧）
	var f := XSceneFade.new()
	var got := []
	for n in range(1, 61):
		if n == XBattleTransition.BGM_FRAME:
			f.start_out(XBattleTransition.FADE_FRAMES)
		f.step()
		got.append(snappedf(f.opacity, 0.0001))
	var want: Array = enc.map(func(r): return snappedf(float(r[2]), 0.0001))
	_check("encounter_fade_out", got == want, {"got": got, "want": want})
	f.start_in(XBattleTransition.FADE_FRAMES)
	got = []
	var busy_until := -1
	for i in range(26):
		f.step()
		got.append(snappedf(f.opacity, 0.0001))
		if busy_until < 0 and not f.busy():
			busy_until = i
	want = ref.battleIn.map(func(v): return snappedf(float(v), 0.0001))
	_check("battle_fade_in", got == want and busy_until == int(ref.battleInBusyUntil), {"got": got, "want": want, "busy_until": busy_until})
	f.start_out(XBattleTransition.FADE_FRAMES)
	got = []
	while f.busy():
		f.step()
		got.append(snappedf(f.opacity, 0.0001))
	want = ref.battleOut.map(func(v): return snappedf(float(v), 0.0001))
	_check("battle_fade_out", got == want, {"got": got, "want": want})
	f.start_in(XBattleTransition.FADE_FRAMES)
	f.step()
	_check("back_to_map_one_dark_frame", _near(f.opacity, float(ref.backToMap[0])) and _near(XBattleTransition.BACK_DARK, float(ref.backToMap[0])) and float(ref.backToMap[1]) == 0.0, [f.opacity, ref.backToMap])
	f.free()


## 真实画面变换：拉近时世界点的画面位置＝shift＋q·（拉近前的画面位置）
func _camera_math(map: XMapScene) -> void:
	await _frames(2)
	var ct0 := get_viewport().get_canvas_transform()
	var base := map.encounter_zoom_base()
	_check("zoom_point_like_original", base.at == Vector2(float(ref.zoomPoint[0]), float(ref.zoomPoint[1])), [base.at, ref.zoomPoint])
	var bad := []
	for n in [1, 10, 30, 45, 60]:
		var q := XBattleTransition.zoom_at(n)
		map.apply_encounter_zoom(base, q)
		await _frames(2)
		var ct := get_viewport().get_canvas_transform()
		var sh := XBattleTransition.zoom_shift(base.at, q)
		for w in [map.player.global_position, Vector2(0, 0), Vector2(48 * 20, 48 * 3)]:
			var want: Vector2 = sh + (ct0 * w) * q
			var got: Vector2 = ct * w
			if got.distance_to(want) > 0.01:
				bad.append([n, w, got, want])
	_check("camera_matches_spriteset_zoom", bad.is_empty(), bad)
	map.reset_encounter_zoom(base)
	await _frames(2)
	var ct1 := get_viewport().get_canvas_transform()
	_check("camera_restored", ct1 == ct0 and map.camera.zoom == Vector2.ONE and map.camera.limit_right == base.limits[2], [ct0, ct1])


func _live(map: XMapScene) -> void:
	XBattleTransition.IN_HEADLESS = true
	XBattleTransition.trace = []
	var ct0 := get_viewport().get_canvas_transform()
	XSound.system_log.clear()
	var res := {"value": -1}
	var go := func(): res.value = await map.start_battle(2, true, false)
	go.call()
	_check("battle_start_se_7", XSound.system_log.has(7), XSound.system_log)
	if out_dir != "" and DisplayServer.get_name() != "headless":
		for n in [10, 40]:
			await _until(func(): return (XBattleTransition.trace as Array).size() >= n)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out_dir.path_join("battle_transition_n%d.png" % n))
	var ok := await _until(func(): return _battle(map) != null)
	var tr: Array = XBattleTransition.trace
	var enc: Array = tr.filter(func(r): return r.phase == "encounter")
	var zooms := enc.map(func(r): return snappedf(r.zoom, 0.0001))
	var fades := enc.map(func(r): return snappedf(r.fade, 0.0001))
	_check("live_encounter_60_frames", ok and enc.size() == 60 and zooms == ref.encounter.map(func(r): return snappedf(float(r[1]), 0.0001)) \
		and fades == ref.encounter.map(func(r): return snappedf(float(r[2]), 0.0001)), {"zooms": zooms, "fades": fades})
	var bgm_from := -1
	for i in enc.size():
		if enc[i].bgm and bgm_from < 0:
			bgm_from = i + 1
	var b := _battle(map)
	_check("battle_bgm_from_frame_30", bgm_from == XBattleTransition.BGM_FRAME and b != null and b.bgm == b.prestarted_bgm and b.bgm != null, bgm_from)
	_check("hud_shown_during_effect_hidden_in_battle", not map.hud.visible)
	ok = await _until(func(): return b.cmd_win != null and b.cmd_win.visible)
	var ins: Array = XBattleTransition.trace.filter(func(r): return r.phase == "in").map(func(r): return snappedf(r.fade, 0.0001))
	var want_in: Array = (ref.battleIn as Array).slice(0, int(ref.battleInBusyUntil) + 1).map(func(v): return snappedf(float(v), 0.0001))
	_check("live_battle_fade_in_then_command", ok and ins == want_in and not b._fade.busy(), {"got": ins, "want": want_in})
	_check("camera_back_to_normal_in_battle", map.camera.zoom == Vector2.ONE and get_viewport().get_canvas_transform() == ct0)
	# 收尾：直接当逃跑结束（只看转场），淡出 24 帧、回地图暗一帧
	b.logic.escaped = true
	b.finished.emit(1)
	ok = await _until(func(): return res.value == 1)
	var outs: Array = XBattleTransition.trace.filter(func(r): return r.phase == "out").map(func(r): return snappedf(r.fade, 0.0001))
	var backs: Array = XBattleTransition.trace.filter(func(r): return r.phase == "back").map(func(r): return snappedf(r.fade, 0.0001))
	_check("live_battle_fade_out_and_back", ok and outs == (ref.battleOut as Array).map(func(v): return snappedf(float(v), 0.0001)) and backs == [snappedf(XBattleTransition.BACK_DARK, 0.0001)], {"out": outs, "back": backs})
	await _frames(3)
	var leftovers := map.ui.get_children().filter(func(c): return c is XSceneFade and not c.is_queued_for_deletion())
	_check("no_fade_left_and_bgm_freed", leftovers.is_empty() and map._battle_bgm == null and map.hud.visible, leftovers.size())


func _rollback(map: XMapScene) -> void:
	XBattleTransition.ENABLED = false
	XBattleTransition.trace = []
	XSound.system_log.clear()
	var res := {"value": -1}
	var go := func(): res.value = await map.start_battle(2, true, false)
	go.call()
	await _until(func(): return _battle(map) != null)  # 有画面时先截地图快照（等一帧画完）
	var b := _battle(map)
	_check("rollback_direct_cut", b != null and b.fade_in == false and b._fade == null and b.prestarted_bgm == null and not XSound.system_log.has(7), XSound.system_log)
	if b != null:
		await _until(func(): return b.cmd_win != null and b.cmd_win.visible)
		b.finished.emit(1)
		await _until(func(): return res.value == 1)
	_check("rollback_no_trace", (XBattleTransition.trace as Array).is_empty(), XBattleTransition.trace)
	# 无画面默认不走（IN_HEADLESS 关）
	XBattleTransition.ENABLED = true
	XBattleTransition.IN_HEADLESS = false
	_check("headless_default_off", XBattleTransition.enabled() == (DisplayServer.get_name() != "headless"))


func _finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
