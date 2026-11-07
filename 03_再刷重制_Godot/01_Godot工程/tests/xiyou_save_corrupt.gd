extends Node
## 读档校验（审计第 10 项）：存档文件里 from_dict 及其调用的各 from_save 实际读取的字段类型损坏时，
## 读档（存档页 load_slot、切后台自动存档 load_auto）要整个退回：返回失败、XState.current 与当前档位不变、
## 不出脚本错误。每例都真写盘（save_N.json），走 XSave 的读档入口。另测完好的档照常读回。

var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(2000))
	return ok


func _ready() -> void:
	_run.call_deferred()


## 按路径改字段：keys 最后一个是要设的键；中间缺的层不建（样例都改已有结构或顶层）
static func _patch(d: Dictionary, keys: Array, v) -> void:
	var node = d
	for i in keys.size() - 1:
		node = node[keys[i]]
	node[keys[-1]] = v


static func _cases(aid: String) -> Array:
	return [
		["orbState_array", ["orbState"], []],
		["orbState_n_array", ["orbState", "n"], [1, 2]],
		["orbState_recent_dict", ["orbState", "recent"], {"a": 1}],
		["items_value_array", ["items", "7"], [1]],
		["switch_value_array", ["switches", "5"], [true]],
		["lastItem_array", ["lastItem"], [3]],
		["nextGearId_dict", ["nextGearId"], {}],
		["orbSeed_array", ["orbSeed"], [1]],
		["actor_skills_nested", ["actors", aid, "skills"], [[1]]],
		["actor_states_null", ["actors", aid, "states"], [null]],
		["actor_stateTurns_value", ["actors", aid, "stateTurns"], {"2": [4]}],
		["actor_cooldowns_value", ["actors", aid, "cooldowns"], {"3": {}}],
		["actor_classExp_value", ["actors", aid, "classExp"], {"1": [5]}],
		["actor_buffs_value", ["actors", aid, "buffs"], [[], 0, 0, 0, 0, 0, 0, 0]],
		["actor_lastBattleSkill", ["actors", aid, "lastBattleSkill"], []],
		["actor_mastery_value", ["actors", aid, "masteryLevels"], {"1": []}],
		["actor_zhenqi_pending", ["actors", aid, "zhenqi"], {"qi": 1, "pending": 3}],
		["actor_zhenqi_daofa", ["actors", aid, "zhenqi"], {"qi": 1, "daofa": [1]}],
		["rom_x_number", ["rom"], {"x": 5}],
		["designation_no_icon", ["designation"], {"name": "x"}],
		["actorOps_no_skill", ["actorOps"], [{"op": "add"}]],
		["actorOps_not_dict", ["actorOps"], [3]],
		["unlockedMaps_nested", ["unlockedMaps"], [[4]]],
		["dungeon_array", ["dungeon"], []],
		["bossMastery_array", ["bossMastery"], []],
		["raceSupply_number", ["raceSupply"], 3],
		["ecoFrac_array", ["ecoFrac"], []],
		["unknownOrigin_array", ["unknownOrigin"], []],
		["hangUpTotal_array", ["hangUpTotal"], []],
		["pingbiQuality_dict", ["pingbiQuality"], {}],
		["followersVisible_string", ["followersVisible"], "yes"],
		["playerMoveSpeed_array", ["playerMoveSpeed"], []],
		["vehicles_mapId_array", ["vehicles"], [{"mapId": []}]],
		["erasedEvents_number", ["erasedEvents"], 5],
		["encounterEnabled_dict", ["encounterEnabled"], {}],
		["actorMaxLevel_array", ["actorMaxLevel"], []],
		["screen_tone_value", ["screen"], {"tone": [[], 0, 0, 0]}],
		["phwarehouse_items_array", ["phwarehouse"], {"仓库": {"items": []}}],
		["phwarehouse_bad_gear", ["phwarehouse"], {"仓库": {"items": {"item": [{"kind": "weapon"}]}}}],
		["saveactors_array", ["saveactors"], [[2]]],
		["costumeOff_dict", ["costumeOff"], [{}]],
		["playerCostume_index", ["playerCostume"], {"characterName": "a", "characterIndex": []}],
		["codexRaven_soul", ["codexRaven"], {"soul": []}],
		["codexGarou_catalyst", ["codexGarou"], {"catalyst": "x"}],
		["shopStock_stock_number", ["shopStock"], {"inv": {"g": {"stock": {"1": 5}}}}],
		["shopStock_schedules_bool", ["shopStock"], {"inv": {}, "schedules": true}],
		["pets_list_number", ["pets"], {"list": [3], "war": 0, "team_a": 0}],
		["pets_push_number", ["pets"], {"list": [{"push": 3, "skills": []}], "war": 0, "team_a": 0}],
		["selfSwitches_array", ["selfSwitches"], []],
	]


func _run() -> void:
	XSave.dir_override = OS.get_user_data_dir().path_join("test_save_corrupt_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(XSave.dir_override)
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.gold = 4321
	s.items[7] = 2
	s.set_switch(5, true)
	check("good_save_written", XSave.save(1))
	check("good_save_loads", XSave.load_slot(1) and XState.current.gold == 4321 and XSave.current_slot == 1)
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(1)))
	var aid := str(int(good.party[0]))
	for c in _cases(aid):
		var d: Dictionary = good.duplicate(true)
		_patch(d, c[1], c[2])
		var f := FileAccess.open(XSave.path(2), FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
		var before := XState.current
		var ok := XSave.load_slot(2)
		check("rejects_" + c[0], not ok and is_same(XState.current, before) and XSave.current_slot == 1 \
			and XState.current.gold == 4321 and XSave.summary(2) == "存档 2：无法读取", c[0])
	# 切后台自动存档走另一个入口（load_auto），同样不能半途换掉当前局
	var auto: Dictionary = good.duplicate(true)
	auto.orbState = []
	auto.autoFromSlot = 1
	var fa := FileAccess.open(XSave.auto_path(), FileAccess.WRITE)
	fa.store_string(JSON.stringify(auto))
	fa.close()
	var keep := XState.current
	check("auto_rejects_orbState_array", not XSave.load_auto() and is_same(XState.current, keep) and XSave.auto_summary() == "")
	# 坏档拒掉之后，完好的档照常能读
	check("good_save_still_loads", XSave.load_slot(1) and not is_same(XState.current, keep) and XState.current.gold == 4321)
	XSave.remove_auto()
	for i in range(1, XSave.SLOTS + 1):
		XSave.remove(i)
	for fname in DirAccess.get_files_at(XSave.dir_override):
		DirAccess.remove_absolute(XSave.dir_override.path_join(fname))
	DirAccess.remove_absolute(XSave.dir_override)
	XSave.dir_override = ""
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
