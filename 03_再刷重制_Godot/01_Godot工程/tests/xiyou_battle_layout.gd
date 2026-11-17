extends Node
## 【cc·天启篇】T126 战斗站位撑开（XBattleLayout）＋小怪血条专项：内存新游戏，不写存档。
## 窗口模式加 -- --out=<目录> [--variants=off,A,B,C] [--touch] 出 800×450 截图（首领战、多只小怪、5 只小怪＋2 人）。

var results := []
var out_dir := ""
var variants := ["off", "A", "B", "C"]
var touch := false
var bar_style := "feet"

const SCENES := [
	{"name": "boss", "troop": 4, "party": [8, 9, 10]},
	{"name": "mob4", "troop": 25, "party": [8, 9, 10]},
	{"name": "mob3_2p", "troop": 2, "party": [8]},
	{"name": "mob8", "troop": 357, "party": [8, 9, 10]},
]


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		if arg.begins_with("--variants="):
			variants = Array(arg.substr(11).split(","))
		if arg == "--touch":
			touch = true
		if arg.begins_with("--bar="):
			bar_style = arg.substr(6)
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


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await _frames(10)
	RenderingServer.force_draw(false)
	_check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


func _run() -> void:
	if out_dir != "" and DisplayServer.get_name() != "headless":
		get_window().size = Vector2i(800, 450)
		await _frames(5)
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	if touch:
		XUiSkin.touch_override = 1
	XSave.dir_override = "user://test_xiyou_battle_layout"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XEnemy.force_roll = 100.0
	XSkinEnemyHp.ENABLED = bar_style != "off"
	XSkinEnemyHp.STYLE = XSkinEnemyHp.Style.HEAD if bar_style == "head" else XSkinEnemyHp.Style.FEET
	for v in variants:
		XBattleLayout.ENABLED = v != "off"
		if v != "off":
			XBattleLayout.VARIANT = v
		for sc in SCENES:
			await _battle(v, sc)
	XBattleLayout.ENABLED = true
	XBattleLayout.VARIANT = "A"
	_finish()


func _battle(v: String, sc: Dictionary) -> void:
	seed(20261117)
	var s := XState.new_game(3, 1, sc.party)
	for a in s.members():
		a.change_level(99)  # 截图要等到我方指令，别开场就被小怪打光
		a.refresh_passive()
		a.param_mark_dirty()
		a.recover_all()
	s.random_master = XRandomStream.hex64(20261117)
	var b := XBattleScene.new()
	b.setup(int(sc.troop), true, false, {})
	add_child(b)
	var ok := await _until(func(): return b.cmd_win != null and b.cmd_win.active)
	_check("command_shown_%s_%s" % [v, sc.name], ok)
	await _secs(0.8)
	# 小怪血条：第一只挨一刀（显示拖尾），截图时还在拖
	var first: XBattler = b.logic.enemies[0]
	if sc.troop != 4:
		first.hp = floorf(first.mhp * 0.55)
		b.update_gauges()
		await _frames(4)
	await _shot("layout_%s_%s%s_%s" % [v, sc.name, "_touch" if touch else "", bar_style])
	b.bgm.stop()
	b.queue_free()
	await _frames(3)


func _finish() -> void:
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XUiSkin.touch_override = -1
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
