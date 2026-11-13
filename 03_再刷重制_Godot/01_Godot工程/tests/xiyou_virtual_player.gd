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


## 给人看的小结（云端运行页摘要用）
func _summary(rep: Dictionary) -> String:
	var lines := ["## 虚拟玩家（%s，种子 %d）" % ["爬塔" if rep.mode == "climb" else "逛图", int(rep.seed)], ""]
	if rep.mode == "climb":
		lines.append("- 爬到：**第 %d 层**（已通过 %d 层）" % [int(rep.floor), maxi(0, int(rep.floor) - 1)])
		lines.append("- 收工原因：%s" % (str(rep.climb_stop) if rep.climb_stop != "" else "步数用完或达到目标"))
		lines.append("- 全灭 %d 次，挂机练级 %d 场，队伍等级 %s" % [int(rep.defeats), int(rep.grind_battles), str(rep.levels)])
		lines.append("- 去装备页 %d 次，一共换上 %d 件装备" % [int(rep.equip_passes), int(rep.equip_changes)])
		lines.append("- 副本：进了 %d 次，打倒首领 %d 次，在副本里全灭 %d 次" % [int(rep.dungeon_runs), int(rep.dungeon_kills), int(rep.dungeon_defeats)])
		for f in rep.farm_block:
			lines.append("  - 第 %s 层不再刷副本：%s" % [str(f), str(rep.farm_block[f])])
		var g: Dictionary = rep.growth
		if not g.is_empty():
			lines.append("- 养成：真气 %s，境界 %s，抽奖券 %d，肝帝积分 %d" % [str(g.zhenqi), "、".join(g.realms), int(g.tickets), int(g.points)])
		if not rep.growth_log.is_empty():
			lines.append("- 养成动作 %d 次：%s" % [rep.growth_log.size(), "；".join(rep.growth_log.slice(0, 12).map(func(x): return "第 %d 层 %s" % [int(x.floor), str(x.what)]))])
	lines.append("- 用了 %d 步、%d 帧、%.1f 分钟，按键 %d 次，战斗 %d 场，对话 %d 条" % [int(rep.ticks), int(rep.frames), float(rep.msec) / 60000.0, int(rep.keys), rep.battles.size(), int(rep.messages)])
	if rep.aborted != "":
		lines.append("- **卡死放弃**：%s" % str(rep.aborted))
	if not rep.stuck.is_empty():
		lines.append("- 卡住过 %d 次（自救后继续）：%s" % [rep.stuck.size(), "、".join(rep.stuck.slice(0, 6).map(func(st): return "第 %d 步 %s" % [int(st.tick), str(st.screen)]))])
	for v in rep.violations:
		lines.append("- %s：%s 角色 %d 数值 %s（第 %d 步，地图 %d）" % ["**出错**" if v.hard else "存疑", str(v.what), int(v.actor), str(v.value), int(v.tick), int(v.map)])
	if rep.mode == "climb" and not rep.floor_log.is_empty():
		lines.append("")
		lines.append("| 层 | 到达（分钟） | 挑战次数 | 全灭 | 练级场数 | 副本首领（倒／进／灭） | 到达时等级 |")
		lines.append("| --- | --- | --- | --- | --- | --- | --- |")
		for r in rep.floor_log:
			lines.append("| %d | %.1f | %d | %d | %d | %d／%d／%d | %s |" % [int(r.floor), float(r.msec) / 60000.0, int(r.get("challenges", 0)), int(r.defeats), int(r.grind_battles),
				int(r.get("dungeon_kills", 0)), int(r.get("dungeon_runs", 0)), int(r.get("dungeon_defeats", 0)), str(r.levels)])
		# 全灭的那几场差多远：敌人开打时的血、收工时剩的血、打到第几回合
		var fights: Array = rep.battles.filter(func(b): return b.get("result", "") == "全灭" and b.has("hp0"))
		if not fights.is_empty():
			lines.append("")
			lines.append("全灭的战斗（最近 8 场）：")
			for b in fights.slice(-8):
				lines.append("- 第 %d 层 敌群 %d：敌人血量 %s → 剩 %s（打掉 %.1f%%），第 %d 回合" % [int(b.get("floor", 0)), int(b.get("troop", 0)), str(int(b.hp0)), str(int(b.get("hp", b.hp0))),
					100.0 * (1.0 - float(b.get("hp", b.hp0)) / maxf(1.0, float(b.hp0))), int(b.get("turn", 0))])
	return "\n".join(lines) + "\n"


func _run() -> void:
	var free: bool = OS.get_cmdline_user_args().has("--vp-free")
	var bot := VP.new()
	bot.rng_seed = int(_arg("--vp-seed", "20261113"))
	bot.max_ticks = int(_arg("--vp-ticks", "6000"))
	bot.out_dir = _arg("--vp-out")
	bot.verbose = OS.get_cmdline_user_args().has("--vp-verbose")
	bot.equip_enabled = not OS.get_cmdline_user_args().has("--vp-no-equip")
	bot.farm_enabled = not OS.get_cmdline_user_args().has("--vp-no-farm")
	bot.farm_first = int(_arg("--vp-farm-first", "0"))
	bot.fixed_random = not OS.get_cmdline_user_args().has("--vp-loose-random")
	bot.debug_floor = int(_arg("--vp-debug-floor", "0"))
	bot.zhenqi_enabled = not OS.get_cmdline_user_args().has("--vp-no-zhenqi")
	var goals_arg := _arg("--vp-goals")
	bot.mode = _arg("--vp-mode", "explore")
	var climb := bot.mode == "climb"
	var floors := int(_arg("--vp-floors", "0"))      # 爬塔：通过这么多层就收工（0＝爬到步数或时间用完）
	if climb:
		free = true
		bot.max_ticks = int(_arg("--vp-ticks", "400000"))
		bot.max_msec = int(float(_arg("--vp-minutes", "0")) * 60000.0)
		bot.max_frames = int(_arg("--vp-frames", "0"))
		bot.settle_ticks = 6000          # 收工时多半在自动战斗里，一场打完要几千步
		bot.goals = ["floor_%d_cleared" % floors] if floors > 0 else []
	else:
		bot.goals = [] if free else (Array(goals_arg.split(",", false)) if goals_arg != "" else DEFAULT_GOALS.duplicate())
	# 独立的存档与设置目录；漩涡过场（约 5000 帧）另有专项，这里标成看过
	# --vp-tag：同一个种子同时跑两局（对比用）时给存档目录加个后缀，免得两局互相读到对方的存档
	XSave.dir_override = "user://test_virtual_player/%d%s" % [bot.rng_seed, _arg("--vp-tag")]
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
	_check("settled", rep.settled, rep.final)
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
	if climb:
		# 爬不动（打不过、找不到守层者）算失败，让人来看；只是步数或时间用完不算
		_check("climb_not_blocked", rep.climb_stop == "" or rep.climb_stop == "时间用完", rep.climb_stop)
		if floors > 0:
			_check("climb_floors_cleared", rep.milestones.has("floor_%d_cleared" % floors), [rep.floor, rep.climb_stop])
		print("VP_CLIMB=" + JSON.stringify({"floor": rep.floor, "stop": rep.climb_stop, "defeats": rep.defeats, "grind_battles": rep.grind_battles, "levels": rep.levels, "floor_log": rep.floor_log,
			"dungeon": [rep.dungeon_runs, rep.dungeon_kills, rep.dungeon_defeats], "farm_block": rep.farm_block, "growth": rep.growth, "frames": rep.frames}))
	# 报告：给了 --vp-out 就写文件；摘要总是打印
	if bot.out_dir != "":
		var f := FileAccess.open(bot.out_dir.path_join("report.json"), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(rep, "\t"))
			f.close()
		var md := FileAccess.open(bot.out_dir.path_join("summary.md"), FileAccess.WRITE)
		if md != null:
			md.store_string(_summary(rep))
			md.close()
	var brief := rep.duplicate()
	brief.erase("timeline")
	brief.erase("event_visits")
	brief.erase("transcript")
	print("VP_REPORT=" + JSON.stringify(brief))
	bot.queue_free()
	await get_tree().process_frame
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
