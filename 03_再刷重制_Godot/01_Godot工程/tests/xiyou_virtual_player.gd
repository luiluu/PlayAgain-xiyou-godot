extends Node
## 虚拟玩家专项（原型）：让 tests/virtual_player/virtual_player.gd 只靠按键从标题玩起，
## 看它能不能自己开局、进大厅、调查事件、走到别的地图、打完一场战斗，中途不卡死、不变量不破。
## 运行：godot --path <工程> res://tests/xiyou_virtual_player.tscn [-- --vp-seed=<数> --vp-ticks=<步数> --vp-goals=a,b --vp-out=<目录> --vp-verbose --vp-free]
## --vp-free：不设目标、跑满步数、只要没卡死没破不变量就算过（长跑／换种子找问题用）。
## 存档与设置都写在 user://test_virtual_player/<种子>，跑完删除；不读写真实存档。

const VP := preload("res://tests/virtual_player/virtual_player.gd")
## 机器人的养成助手（virtual_player.gd 里用）。选测按「哪个测试引用了它」找场景，这里引用一次，改它时才会选中本专项
const VP_GROWTH := preload("res://tests/virtual_player/vp_growth.gd")
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
		if int(rep.debug_floor) > 0 or not rep.debug_items.is_empty():
			lines.append("- **调试局**：层数直接改成了 %d、开局给了物品 %s，结果不算正常通关" % [int(rep.debug_floor), str(rep.debug_items)])
		lines.append("- 开局阵容：%s%s" % [str(rep.lineup), "" if rep.fixed_random else "（随机没有固定）"])
		lines.append("- 收工原因：%s" % (str(rep.climb_stop) if rep.climb_stop != "" else "步数用完或达到目标"))
		lines.append("- 全灭 %d 次，挂机练级 %d 场，队伍等级 %s" % [int(rep.defeats), int(rep.grind_battles), str(rep.levels)])
		lines.append("- 去装备页 %d 次，一共换上 %d 件装备" % [int(rep.equip_passes), int(rep.equip_changes)])
		lines.append("- 副本：进了 %d 次，打倒首领 %d 次，在副本里全灭或僵局 %d 次" % [int(rep.dungeon_runs), int(rep.dungeon_kills), int(rep.dungeon_defeats)])
		if int(rep.stalemates) > 0:
			lines.append("- **僵局 %d 场**（打了 40 回合以上还分不出胜负，当成打不过放弃）" % int(rep.stalemates))
		for f in rep.farm_block:
			lines.append("  - 第 %s 层不再刷副本：%s" % [str(f), str(rep.farm_block[f])])
		var g: Dictionary = rep.growth
		if not g.is_empty():
			lines.append("- 养成：真气 %s，境界 %s，抽奖券 %d，肝帝积分 %d" % [str(g.zhenqi), "、".join(g.realms), int(g.tickets), int(g.points)])
			var m: Dictionary = g.get("materials", {})
			if not m.is_empty():
				lines.append("- 宝珠：身上镶了 %d 颗，背包里神秘珠 %d、残片 %d；种族阶位 %s，进阶石 %s；抽奖 %d 次" % [int(m.gems), int(m.pearls), int(m.fragments), str(m.race_ranks), str(m.stones), int(g.get("lottery_draws", 0))])
			var fb: Dictionary = g.get("fabao", {})
			if not fb.is_empty():
				lines.append("- 法宝：当层上限 %s；出战的人身上 %s" % [str(int(fb.cap)) if int(fb.cap) > 0 else "不限", "、".join(fb["items"].map(func(x): return "%s %d 级" % [str(x.name), int(x.level)])) if not fb["items"].is_empty() else "没有法宝"])
			lines.append("- 花钱：买了 %d 件，用掉书和丹药 %d 个，喂法宝 %d 次，收工时金币 %d" % [int(g.get("spend_buys", 0)), int(g.get("spend_uses", 0)), int(g.get("fabao_feeds", 0)), int(g.get("gold", 0))])
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
		var fights: Array = rep.battles.filter(func(b): return ["全灭", "僵局"].has(b.get("result", "")) and b.has("hp0"))
		if not fights.is_empty():
			lines.append("")
			lines.append("没打赢的战斗（最近 10 场）：")
			for b in fights.slice(-10):
				lines.append("- 第 %d 层 敌群 %d %s：敌人血量 %s → 剩 %s（打掉 %.1f%%），第 %d 回合" % [int(b.get("floor", 0)), int(b.get("troop", 0)), str(b.result), str(int(b.hp0)), str(int(b.get("hp", b.hp0))),
					100.0 * (1.0 - float(b.get("hp", b.hp0)) / maxf(1.0, float(b.hp0))), int(b.get("turn", 0))])
	return "\n".join(lines) + "\n"


## 花钱的规矩（法宝与积分重构后）：法宝经验丹认得出来，摆在店里也不买；有人用得上的装备会买。
## 用一家临时的店（法宝经验丹·究极＋新手戒指），钱和积分给足，买完看背包。
func _check_spend_rules(climb: bool) -> void:
	var st := XState.current
	var map := get_tree().current_scene
	if st == null or not map is XMapScene:
		return
	const PILL := 1987
	_check("spend_knows_fabao_exp_pill", VP_GROWTH.is_fabao_exp_pill(XDB.rec("Items", PILL)) and not VP_GROWTH.is_fabao_exp_pill(XDB.rec("Items", 1685)))
	st.gain_gold(100000)
	st.set_variable(XCasinoBatch.VAR_POINTS, 99999)
	var pills0 := st.item_count(PILL)
	var shop := XShop.new()
	shop.setup([[0, PILL, 0, 0], [2, 3793, 0, 0]], true)
	map.ui.add_child(shop)
	await get_tree().process_frame
	var listed: bool = shop._buy_data().any(func(e): return int(e.kind) == 0 and int(e.gid) == PILL)
	var res: Dictionary = VP_GROWTH.shop(shop, st)
	# 经验丹下架（XFabaoFeed.NO_PILLS）以后店里可能根本不列它：列不列都不能买到
	_check("spend_skips_fabao_exp_pill", st.item_count(PILL) == pills0, [listed, st.item_count(PILL), res.lines])
	if not climb:                        # 爬塔局收工时可能早就戴上了，只在逛图局（新开局的队伍）查
		_check("spend_buys_useful_gear", int(res.bought) >= 1, res.lines)
	# 喂法宝：给第一位出战的人一件 1 级法宝、背包里放几件普通装备，喂完法宝要升级、装备要少（XFabaoFeed 还没合进来时跳过）
	if VP_GROWTH.feed_script() != null:
		var fabao := {}
		var owner: XActor = null
		st.gain_gear("armor", 13, 1)   # 大罗剑胎（法宝）
		var bag: Array = st.gear.filter(func(g): return XMagicWeapon.is_magic(g))
		owner = st.battle_members()[0]
		var slot: int = owner.equip_slots().find(int(bag[0].get("etypeId", 0))) if not bag.is_empty() else -1
		if slot >= 0:                    # 测试摆放：直接放进法宝格（这位角色平时能不能戴不在这里查）
			fabao = bag[0]
			st.lose_gear(fabao, false)
			owner.equips[slot] = fabao
		if not fabao.is_empty() and XMagicWeapon.level_of(fabao) < XMagicWeapon.max_level(fabao):
			st.gain_gear("armor", 3793, 6)
			var lv0 := XMagicWeapon.level_of(fabao)
			var bag0 := st.gear.size()
			var fed: Array = VP_GROWTH.feed_fabao(st)
			_check("feed_fabao_levels_up", not fed.is_empty() and st.gear.size() < bag0 and XMagicWeapon.level_of(fabao) > lv0, [fed, lv0, owner.actor_id])
	shop.queue_free()
	await get_tree().process_frame


func _run() -> void:
	var free: bool = OS.get_cmdline_user_args().has("--vp-free")
	var bot := VP.new()
	bot.rng_seed = int(_arg("--vp-seed", "20261113"))
	bot.max_ticks = int(_arg("--vp-ticks", "6000"))
	bot.out_dir = _arg("--vp-out")
	bot.snapshot_dir = _arg("--vp-snapshot-dir")
	if bot.out_dir != "":
		DirAccess.make_dir_recursive_absolute(bot.out_dir)
	bot.verbose = OS.get_cmdline_user_args().has("--vp-verbose")
	bot.equip_enabled = not OS.get_cmdline_user_args().has("--vp-no-equip")
	bot.farm_enabled = not OS.get_cmdline_user_args().has("--vp-no-farm")
	bot.farm_first = int(_arg("--vp-farm-first", "0"))
	bot.fixed_random = not OS.get_cmdline_user_args().has("--vp-loose-random")
	bot.debug_floor = int(_arg("--vp-debug-floor", "0"))
	for pair in _arg("--vp-debug-items").split(",", false):
		bot.debug_items[int(pair.get_slice(":", 0))] = int(pair.get_slice(":", 1))
	bot.zhenqi_enabled = not OS.get_cmdline_user_args().has("--vp-no-zhenqi")
	bot.orbs_enabled = not OS.get_cmdline_user_args().has("--vp-no-orbs")
	bot.race_enabled = not OS.get_cmdline_user_args().has("--vp-no-race")
	bot.lottery_enabled = not OS.get_cmdline_user_args().has("--vp-no-lottery")
	bot.spend_enabled = not OS.get_cmdline_user_args().has("--vp-no-spend")
	bot.feed_enabled = not OS.get_cmdline_user_args().has("--vp-no-feed")
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
	# 上一局被中途杀掉时存档会留在测试目录里，机器人在标题看到存档会去读它：开局前先清掉（只清这个测试目录）
	for i in range(1, XSave.SLOTS + 1):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(XSave.path(i)))
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
	await _check_spend_rules(climb)
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
