extends Node
## 事件脚本翻译（MVScript）与开局用到的解释器指令：直接拿正式版的公共事件当输入。
## 所有角色学技能的几种循环（839/1319/1345/1443/1435）、固定存档位存档（公共事件 1，成功与失败）、
## prompt 输入名字、DCultyL 标记、随机伙伴魂灯（1344：变量取物品＋标签跳转＋提示）、插件指令设难度、增减技能（318）。

var results := []
var saved: Array = []
var toasts: Array = []
var save_ok := true


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


## 解释器的 host：只提供脚本与这些指令用到的服务
func save_game(slot: int) -> bool:
	saved.append(slot)
	return save_ok


func toast(text: String) -> void:
	toasts.append(text)


func input_text(_prompt: String, _default := "") -> String:
	return "测试名"


func refresh_events() -> void:
	pass


func run_list(list: Array) -> MVInterpreter:
	var interp := MVInterpreter.new(self, 0, 0, list)
	await interp.run()
	return interp


func script(code: String) -> Array:
	return await MVScript.run(code, MVInterpreter.new(self, 0, 0, []))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_script"  # ConfigManager 的测试仅改内存
	var s := XState.new_game_blank()
	check("blank_start", s.party.is_empty() and s.map_id == 1 and Vector2i(s.x, s.y) == Vector2i(7, 10) and s.difficulty == 2, [s.party, s.map_id, s.x, s.y, s.difficulty])
	# 1319 天道诅咒：有名字的角色学 6168（条件是变量 14＝1）
	s.set_variable(14, 1)
	var it := await run_list(XDB.rec("CommonEvents", 1319).list)
	check("ce1319_named_learn", it.skipped.is_empty() and s.actor_ops.size() == 1 and s.actor_ops[0].skill == 6168 and s.actor_ops[0].named, s.actor_ops)
	check("ce1319_applies_on_create", s.actor(1).skill_ids.has(6168) and not s.actor(116).skill_ids.has(6168))
	# 839 暴爽：j < 999、不查名字
	it = await run_list(XDB.rec("CommonEvents", 839).list)
	check("ce839_all_learn", it.skipped.is_empty() and s.actor(116).skill_ids.has(2747) and s.actor(1).skill_ids.has(2747))
	# 1345 强者/弱者压制：名单内忘 6235 学 6216，名单外有名字的学 6235
	it = await run_list(XDB.rec("CommonEvents", 1345).list)
	check("ce1345_lists", it.skipped.is_empty() and s.actor(1).skill_ids.has(6216) and not s.actor(1).skill_ids.has(6235) and s.actor(2).skill_ids.has(6235) and not s.actor(2).skill_ids.has(6216), [s.actor(1).skill_ids, s.actor(2).skill_ids])
	# 1443 天灾补强（开关 2461）：名单内忘 5968 学 5969，其余（`!== ''`）学 5968
	s.set_switch(2461, true)
	it = await run_list(XDB.rec("CommonEvents", 1443).list)
	check("ce1443_lists", it.skipped.is_empty() and s.actor(1).skill_ids.has(5969) and s.actor(2).skill_ids.has(5968) and not s.actor(116).skill_ids.has(5968), [s.actor(1).skill_ids, s.actor(2).skill_ids])
	# 1435 轮回模式里的 $gameActors.length+1 循环：原版一次也不执行
	var before := s.actor_ops.size()
	check("length_plus_one_noop", (await script("for (var j = 1; j < $gameActors.length+1; j++) {\nvar actor = $gameActors.actor(j);\nactor.learnSkill(8105);\n}")).is_empty() and s.actor_ops.size() == before)
	# 存档（公共事件 1）：变量 21＝0 时按开关 161 存到 1 号位，成功提示；失败时蜂鸣并提示「存档失败」
	s.set_switch(161, true)
	it = await run_list(XDB.rec("CommonEvents", 1).list)
	check("ce1_save_slot1", it.skipped.is_empty() and saved == [1] and toasts == ["存档成功，储存到了1号存档！"] and s.fixed_save_slot() == 1, [it.skipped, saved, toasts])
	save_ok = false
	toasts.clear()
	it = await run_list(XDB.rec("CommonEvents", 1).list)
	check("ce1_save_fail", toasts == ["存档失败"], toasts)
	save_ok = true
	# Map001 的 prompt、DCultyL、ConfigManager
	check("prompt_name", (await script("$gamePlayer.SaveActorName = prompt(\"请输入您的名字\",\"\");")).is_empty() and s.actor_name == "测试名")
	check("flags", (await script("ConfigManager.MapXy=false;\n$gameParty.DCultyL3 = true;")).is_empty() and s.flags.get("DCultyL3") == true)
	# 1344 随机伙伴：随机魂灯（2701～2819）互不相同，靠标签跳转重掷；每个都提示「获得了：名字！」
	toasts.clear()
	it = await run_list(XDB.rec("CommonEvents", 1344).list)
	var lamps := s.items.keys().filter(func(id): return int(id) >= 2701 and int(id) <= 2819)
	check("ce1344_random_lamps", it.skipped.is_empty() and lamps.size() >= 3 and toasts.size() == lamps.size() and toasts.all(func(t): return str(t).begins_with("获得了：")), [it.skipped, lamps, toasts])
	# 行注释去掉，但引号里的 // 保留
	toasts.clear()
	check("comment_strip_keeps_quoted", (await script("$.toaster({ message : '见 http://a.b'}); // 注释")).is_empty() and toasts == ["见 http://a.b"], toasts)
	# 认不出的脚本原样报告
	check("unknown_reported", (await script("Star.AchievementSystem.GetAcReward(84)")) == ["Star.AchievementSystem.GetAcReward(84)"])
	# 插件指令设难度；增减技能（角色 0 为全队）
	s.add_actor(1)
	s.add_actor(8)
	it = await run_list([{"code": 356, "indent": 0, "parameters": ["Difficulty SetID 5"]}, {"code": 318, "indent": 0, "parameters": [0, 0, 0, 2571]}, {"code": 318, "indent": 0, "parameters": [0, 8, 1, 2571]}, {"code": 0, "indent": 0, "parameters": []}])
	check("plugin_difficulty_and_skills", s.difficulty == 5 and s.actor(1).skill_ids.has(2571) and not s.actor(8).skill_ids.has(2571) and it.skipped.is_empty())
	# YEP_X_ExtMesPack1 连续选项合并：Map001 两组 5 个存档位并成 10 项，分支续编号 0～9，默认第 1 项
	var map1: Dictionary = XDB.map(1)
	var ev_list: Array = map1.events[1].pages[0].list.duplicate(true)
	var ci := ev_list.find_custom(func(c): return int(c.code) == 102)
	var merger := MVInterpreter.new(self, 1, 1, ev_list)
	merger._merge_choices(ci)
	var branches := []
	for c in ev_list:
		if int(c.code) == 402 and int(c.indent) == int(ev_list[ci].indent) and ev_list.find(c) < ev_list.find_custom(func(x): return int(x.code) == 404 and int(x.indent) == int(ev_list[ci].indent)):
			branches.append(int(c.parameters[0]))
	check("merge_save_choices", ev_list[ci].parameters[0].size() == 10 and str(ev_list[ci].parameters[0][9]) == "10号存档" and branches == range(10) and int(ev_list[ci].parameters[2]) == 0, [ev_list[ci].parameters, branches])
	# 存读档保留 actor_ops、名字、标记；读档后新建的角色照样补上
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var r := XState.from_dict(d)
	check("save_roundtrip_ops", r.actor_ops.size() == s.actor_ops.size() and r.actor_name == "测试名" and r.flags.get("DCultyL3") == true and r.actor(30).skill_ids.has(6168))
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
