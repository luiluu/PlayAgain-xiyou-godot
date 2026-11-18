extends Node
## 【cc·T190】真实战斗里的 7 项指令环：天启篇存档、助力位有人（指令多「换人」），首领战（敌群 88）、小怪战（敌群 37）。
## 核：指令环 7 项、末两项（逃跑、换人所在的弦位）竖向间距 ≥ MIN_GAP_B。窗口模式加 -- --out=<目录> 出 1280×720 原尺寸截图。
## 用法：Godot --audio-driver Dummy --path . res://tests/xiyou_ring_seven_battle.tscn [-- --out=<目录>]

var results := []
var out_dir := ""
var six := false   # --six：关掉战斗中换人，指令 6 项（T190 起 6 项同样不压首领信息区）


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		if arg == "--six":
			six = true
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
		for sk in XDB.table("Skills"):  # T215：天启篇某类技能一个都没有就不列指令——补一个战技，指令才凑满 7 项
			if sk != null and int(sk.get("stypeId", 0)) == 1 and int(sk.id) > XBattleLogic.GUARD_SKILL and not sk.get("meta", {}).has("Hide in Battle"):
				a.learn_skill(int(sk.id))
				break
	return s


## 关掉现有指令窗，给 a 新建指令环并按真实战斗的摆法放好（_place_near_actor）
func _ring_for(b: XBattleScene, a: XActor) -> Control:
	b._close_windows()
	var opts := b._command_entries(a)
	var w = XSkinBattle.command(b.ui, opts, b.CMD_W, a)
	b.cmd_win = w
	b._place_near_actor(w, a)
	await _secs(1.0)   # 铺开动效走完再截
	return w


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
	if six:
		XTianqi.SWAP_IN_BATTLE = false
	for troop in [88, 37]:
		var s := _state()
		_check("helper_present_%d" % troop, s.helper() != null)
		var b := XBattleScene.new()
		b.setup(troop, true, false, {})
		add_child(b)
		var ok := await _until(func(): return b.cmd_win != null and b.cmd_win.active)
		_check("command_shown_%d" % troop, ok)
		await _secs(1.0)
		# 每个行动者（含第一排、最后一排）各摆一次指令环：每项矩形与行动提示都不压首领信息区
		var shot_actor: XActor = b.logic.actors[0]
		for a in b.logic.actors:
			var w := await _ring_for(b, a)
			var ring := w as XSkinBattleRing
			var want := 6 if six else 7
			_check("ring_items_%d_%d" % [troop, a.actor_id], ring != null and ring.entries.size() == want, ring.entries.map(func(e): return e.text) if ring != null else null)
			if ring == null:
				continue
			var zone := b.boss_info_rect()
			var hit := []
			for r: Rect2 in ring.item_rects():
				if Rect2(ring.position + r.position, r.size).intersects(zone):
					hit.append(r)
			_check("ring_clear_of_boss_info_%d_%d" % [troop, a.actor_id], hit.is_empty(), [zone, ring.position, hit])
			if want == 6:   # 旧排法（开关关）不压的行动者，位置必须和旧排法逐像素一样；压的才被挪
				var fixed_pos := ring.position
				XSkinBattleRing.SEVEN_FIX = false
				var old := await _ring_for(b, a) as XSkinBattleRing
				XSkinBattleRing.SEVEN_FIX = true
				var old_hit := old.item_rects().any(func(r): return Rect2(old.position + r.position, r.size).intersects(zone))
				_check("ring_untouched_when_clear_%d_%d" % [troop, a.actor_id], old_hit or old.position.is_equal_approx(fixed_pos), [old.position, fixed_pos])
				_check("ring_moved_down_only_%d_%d" % [troop, a.actor_id], not old_hit or (is_equal_approx(old.position.x, fixed_pos.x) and fixed_pos.y >= old.position.y), [old.position, fixed_pos])
				ring = await _ring_for(b, a) as XSkinBattleRing
			if want == 7:
				var m := INF
				for i in range(1, 7):
					m = minf(m, absf(ring.orb_pos(i).y - ring.orb_pos(i - 1).y))
				_check("ring_gap_%d_%d" % [troop, a.actor_id], m >= XSkinBattleRing.MIN_GAP_B - 0.5, m)
				_check("ring_inside_screen_%d_%d" % [troop, a.actor_id], Rect2(Vector2.ZERO, b.BOX + b._origin).grow(2.0).encloses(Rect2(ring.position, ring.size)), [ring.position, ring.size])
			if a == shot_actor and windowed:
				ring.select(ring.entries.size() - 3 if want == 7 else 0)
				await _frames(12)
				RenderingServer.force_draw(false)
				var nm := ("首领战" if troop == 88 else "小怪战") + ("_6项" if six else "_7项")
				_check("screenshot_" + nm, get_viewport().get_texture().get_image().save_png(out_dir.path_join(nm + ".png")) == OK)
		b.bgm.stop()
		b.queue_free()
		await _frames(3)
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XEnemy.force_roll = -1.0
	XTianqi.SWAP_IN_BATTLE = true
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
