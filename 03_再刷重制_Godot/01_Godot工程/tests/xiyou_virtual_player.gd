extends Node
## 虚拟玩家专项（原型）：让 tests/virtual_player/virtual_player.gd 只靠按键从标题玩起，
## 看它能不能自己开局、进大厅、调查事件、走到别的地图、打完一场战斗，中途不卡死、不变量不破。
## 运行：godot --path <工程> res://tests/xiyou_virtual_player.tscn [-- --vp-seed=<数> --vp-ticks=<步数> --vp-goals=a,b --vp-out=<目录> --vp-verbose --vp-free]
## --vp-free：不设目标、跑满步数、只要没卡死没破不变量就算过（长跑／换种子找问题用）。
## 存档与设置都写在 user://test_virtual_player/<种子>，跑完删除；不读写真实存档。

const VP := preload("res://tests/virtual_player/virtual_player.gd")
## 默认目标只放每次都走得到的（探索带随机，同一个种子两次跑的路线也不完全一样：开局阵容、游戏自己的随机数没固定）；
## 想看它打没打上战斗：--vp-goals=title,in_game,second_map,battle_finished（走不到就跑满步数判失败）
const DEFAULT_GOALS := ["title", "new_game_pressed", "in_game", "event_tried", "choice_made", "second_map"]

var results: Array = []
var _clock := []


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _arg(name: String, default := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			return a.substr(name.length() + 1)
	return default


func _run() -> void:
	var free := OS.get_cmdline_user_args().has("--vp-free")
	var bot := VP.new()
	bot.rng_seed = int(_arg("--vp-seed", "20261113"))
	bot.max_ticks = int(_arg("--vp-ticks", "6000"))
	bot.out_dir = _arg("--vp-out")
	bot.verbose = OS.get_cmdline_user_args().has("--vp-verbose")
	var goals_arg := _arg("--vp-goals")
	bot.goals = [] if free else (Array(goals_arg.split(",", false)) if goals_arg != "" else DEFAULT_GOALS.duplicate())
	# 独立的存档与设置目录；漩涡过场（约 5000 帧）另有专项，这里标成看过
	XSave.dir_override = "user://test_virtual_player/%d" % bot.rng_seed
	XConfig.path_override = XSave.dir().path_join("options.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(XConfig.path_override))
	XConfig._loaded_path = ""
	XConfig.whisper_mark("rift1")
	XConfig.whisper_mark("rift2")
	XEnemy.force_roll = 100.0
	_clock = [OS.low_processor_usage_mode_sleep_usec, Engine.physics_ticks_per_second, Engine.max_physics_steps_per_frame, Engine.time_scale]
	if DisplayServer.get_name() == "headless":
		OS.low_processor_usage_mode_sleep_usec = 0
		Engine.physics_ticks_per_second = 600
		Engine.max_physics_steps_per_frame = 1   # 一画面帧只走一个逻辑帧：按键按画面帧送达，一帧里跑很多逻辑帧的话按一下方向会走出好几格
		Engine.time_scale = 30.0
	else:
		Engine.time_scale = float(_arg("--vp-speed", "4"))
	seed(bot.rng_seed)
	get_tree().root.add_child(bot)
	_check("enter_xiyou", GameApp.enter_mode("xiyou"))
	var rep: Dictionary = await bot.run()
	_check("not_aborted", rep.aborted == "", rep.aborted)
	# 硬性不变量（金币、生命为负）算失败；「存疑」的只打印出来给人看
	var hard: Array = rep.violations.filter(func(v): return v.hard)
	_check("no_hard_violations", hard.is_empty(), hard.slice(0, 5))
	for v in rep.violations:
		if not v.hard:
			print("VP_SUSPECT=" + JSON.stringify(v))
	for g in bot.goals:
		_check("goal_" + str(g), rep.milestones.has(g), rep.milestones)
	if free:
		_check("ran_all_ticks_or_done", rep.ticks > 0)
	# 报告：给了 --vp-out 就写文件；摘要总是打印
	if bot.out_dir != "":
		var f := FileAccess.open(bot.out_dir.path_join("report.json"), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(rep, "\t"))
			f.close()
	var brief := rep.duplicate()
	brief.erase("timeline")
	brief.erase("event_visits")
	brief.erase("transcript")
	print("VP_REPORT=" + JSON.stringify(brief))
	bot.queue_free()
	for i in range(1, XSave.SLOTS + 1):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(XSave.path(i)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(XConfig.path_override))
	OS.low_processor_usage_mode_sleep_usec = _clock[0]
	Engine.physics_ticks_per_second = _clock[1]
	Engine.max_physics_steps_per_frame = _clock[2]
	Engine.time_scale = _clock[3]
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
