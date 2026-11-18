extends Node
## 【cc·T190】真实战斗里的 7 项指令环：天启篇存档、助力位有人（指令多「换人」），首领战（敌群 88）、小怪战（敌群 37）。
## 核：指令环 7 项、末两项（逃跑、换人所在的弦位）竖向间距 ≥ MIN_GAP_B。窗口模式加 -- --out=<目录> 出 1280×720 原尺寸截图。
## 用法：Godot --audio-driver Dummy --path . res://tests/xiyou_ring_seven_battle.tscn [-- --out=<目录>]

var results := []
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


func _secs(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _until(cond: Callable, n := 900) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _state() -> XState:
	var ids: Array = XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))
	var lineup := ids.slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in lineup:
		var a := s.actor(id)
		a.change_level(99)
		a.recover_all()
	return s


func _run() -> void:
	var windowed := out_dir != "" and DisplayServer.get_name() != "headless"
	if windowed:
		get_window().size = Vector2i(1280, 720)
		await _frames(5)
		DirAccess.make_dir_recursive_absolute(out_dir)
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	XSave.dir_override = "user://test_xiyou_ring_seven_battle"
	XConfig.path_override = ProjectSettings.globalize_path(XSave.dir().path_join("options.json"))
	XConfig._loaded_path = "<unloaded>"
	XEnemy.force_roll = 100.0
	seed(20261118)
	for troop in [88, 37]:
		var s := _state()
		_check("helper_present_%d" % troop, s.helper() != null)
		var b := XBattleScene.new()
		b.setup(troop, true, false, {})
		add_child(b)
		var ok := await _until(func(): return b.cmd_win != null and b.cmd_win.active)
		_check("command_shown_%d" % troop, ok)
		await _secs(1.0)
		var ring := b.cmd_win as XSkinBattleRing
		_check("ring_7_items_%d" % troop, ring != null and ring.entries.size() == 7, ring.entries.map(func(e): return e.text) if ring != null else null)
		if ring != null and ring.entries.size() == 7:
			var m := INF
			for i in range(1, 7):
				m = minf(m, absf(ring.orb_pos(i).y - ring.orb_pos(i - 1).y))
			_check("ring_7_gap_%d" % troop, m >= XSkinBattleRing.MIN_GAP_B - 0.5, m)
			ring.select(ring.entries.size() - 3)   # 选到「换人」那一行（倒数第 3 项：…换人、逃跑、?）以便图里看到两项相邻
		if windowed:
			await _frames(12)
			RenderingServer.force_draw(false)
			var nm := "首领战_7项" if troop == 88 else "小怪战_7项"
			_check("screenshot_" + nm, get_viewport().get_texture().get_image().save_png(out_dir.path_join(nm + ".png")) == OK)
		b.bgm.stop()
		b.queue_free()
		await _frames(3)
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XEnemy.force_roll = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
