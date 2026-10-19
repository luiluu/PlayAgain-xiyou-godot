extends Node
## 跨存档变量（XGlobalVars ← Drill_VariablesAcrossArchive）：与 mv_oracle global_vars_probe（generated/oracle/global_vars.json）
## 逐步比对——改值、新开局、读旧档、公共事件 1322／1328、设回 0、运算指令；另测参照量不到的写盘：重启读回、
## 损坏文件、XSave 存读档、路径跟随存档目录（测试用临时目录，不碰真实存档）。

const ORACLE := "res://modes/xiyou/generated/oracle/global_vars.json"
const DIR := "user://test_xiyou_global_vars"
const VARS := [899, 900, 901, 1000, 1476]
const SWS := [2280, 2281]

var results := []
var oracle := {}


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


## 解释器的 host（公共事件 1322／1328 只用到脚本里的学技能循环）
func toast(_text: String) -> void:
	pass

func refresh_events() -> void:
	pass


func run_list(list: Array) -> MVInterpreter:
	var interp := MVInterpreter.new(self, 0, 0, list)
	await interp.run()
	return interp


## 参照的 null（_data 里没有这一格）对应 Godot 字典里没有这个键；数值按数比
func _same(mv, gd_has: bool, gd_value) -> bool:
	if mv == null:
		return not gd_has
	if mv is bool:
		return gd_has and gd_value is bool and gd_value == mv
	return gd_has and (gd_value is float or gd_value is int) and is_equal_approx(float(gd_value), float(mv))


func _same_map(mv: Dictionary, gd: Dictionary) -> bool:
	if mv.size() != gd.size():
		return false
	for k in mv:
		if not _same(mv[k], gd.has(int(k)), gd.get(int(k))):
			return false
	return true


func _file() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(XGlobalVars.path())) if FileAccess.file_exists(XGlobalVars.path()) else null
	if not d is Dictionary:
		return {}
	var out := {"switches": {}, "variables": {}}
	for part in out:
		for k in d.get(part, {}):
			out[part][int(k)] = d[part][k]
	return out


func _compare(label: String, s: XState, learned := {}) -> void:
	var step: Dictionary = oracle.steps.filter(func(x): return x.label == label)[0]
	var bad := []
	for id in VARS:
		if not _same(step.variables[str(id)], s.variables.has(id), s.variables.get(id)):
			bad.append(["v", id, step.variables[str(id)], s.variables.get(id)])
	for id in SWS:
		if not _same(step.switches[str(id)], s.switches.has(id), s.switches.get(id)):
			bad.append(["s", id, step.switches[str(id)], s.switches.get(id)])
	var st := XGlobalVars.stored()
	if not _same_map(step.tankVariables, st.variables) or not _same_map(step.tankSwitches, st.switches):
		bad.append(["tank", step.tankVariables, step.tankSwitches, st])
	var f := _file()
	if step.fileVariables == null:
		if not f.is_empty():
			bad.append(["file_should_be_absent", f])
	elif f.is_empty() or not _same_map(step.fileVariables, f.variables) or not _same_map(step.fileSwitches, f.switches):
		bad.append(["file", step.fileVariables, step.fileSwitches, f])
	for skill in learned:
		var mv: Array = step.learned[str(skill)]
		var gd: Array = [1, 2, 3].map(func(a): return s.actor(a).skill_ids.has(int(skill)))
		if mv != gd:
			bad.append(["learned", skill, mv, gd])
	check(label, bad.is_empty(), bad)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XSave.dir_override = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	DirAccess.remove_absolute(DIR.path_join("global.json"))
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if not parsed is Dictionary:
		check("oracle_present", false, ORACLE + "（先跑 同步正式西游.py）")
		print("TEST_RESULT=" + JSON.stringify({"passed": 0, "total": 1}))
		get_tree().quit(1)
		return
	oracle = parsed
	check("params", XGlobalVars.switch_ids() == oracle.params.switchIds.map(func(v): return int(v))
		and XGlobalVars.variable_ids() == oracle.params.variableIds.map(func(v): return int(v)), [XGlobalVars.switch_ids(), XGlobalVars.variable_ids(), oracle.params])
	check("path_follows_save_dir", XGlobalVars.path() == DIR.path_join("global.json"), XGlobalVars.path())

	var s := XState.new_game_blank()
	_compare("boot_new_game", s)
	s.set_variable(900, 1)
	s.set_variable(899, 2.7)
	s.set_variable(901, 5)
	s.set_switch(2281, true)
	s.set_switch(2280, true)
	_compare("after_set", s)
	s = XState.new_game_blank()
	_compare("new_game", s)
	# 旧档：直接写字典（不经 set_variable），存成档再读
	s.variables[900] = 5.0
	s.variables[899] = 0.0
	s.switches[2281] = false
	s.variables[1476] = 3.0
	s = XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	_compare("load_save", s)
	s = XState.new_game_blank()
	await run_list(XDB.rec("CommonEvents", 1322).list)
	await run_list(XDB.rec("CommonEvents", 1328).list)
	_compare("ce_after_new_game", s, {6176: true, 6205: true})
	s.set_variable(899, 1)
	s = XState.new_game_blank()
	await run_list(XDB.rec("CommonEvents", 1328).list)
	_compare("ce1328_after_set_1", s, {6176: true, 6205: true})
	s.set_variable(900, 0)
	s.set_switch(2281, false)
	s = XState.new_game_blank()
	_compare("reset_zero_new_game", s)
	await run_list([{"code": 122, "indent": 0, "parameters": [1476, 1476, 1, 0, 4]}, {"code": 0, "indent": 0, "parameters": []}])
	s = XState.new_game_blank()
	_compare("operate_add_new_game", s)

	# ---- 参照量不到的写盘 ----
	# 重启：丢掉内存里的存储，从文件读回
	XGlobalVars._loaded_path = "<unloaded>"
	XGlobalVars._variables = {}
	s = XState.new_game_blank()
	check("restart_reads_file", s.variable(899) == 1 and s.variables.has(900) and s.variable(900) == 0 and s.variable(1476) == 4 and s.switches.get(2281) == false,
		[s.variables, s.switches])
	# XSave 存读档：档里存的是旧值，读档后仍取全局值
	s.set_variable(900, 1)
	s.variables[900] = 7.0
	check("xsave_save", XSave.save(3))
	check("xsave_load_overlays", XSave.load_slot(3) and XState.current.variable(900) == 1, XState.current.variables)
	# 不跨存档的变量照常只在本档
	XState.current.set_variable(901, 9)
	XState.new_game_blank()
	check("untracked_not_carried", not XState.current.variables.has(901), XState.current.variables)
	# 损坏的文件按空处理，改值时整份重写
	var f := FileAccess.open(XGlobalVars.path(), FileAccess.WRITE)
	f.store_string("{坏")
	f.close()
	XGlobalVars._loaded_path = "<unloaded>"
	s = XState.new_game_blank()
	check("corrupt_file_empty", not s.variables.has(900) and XGlobalVars.stored().variables.is_empty(), s.variables)
	s.set_variable(1000, 2)
	check("corrupt_file_rewritten", _file().get("variables", {}).get(1000) == 2.0 and _file().variables.size() == 1, _file())
	# 换存档目录（另一套存档）就是另一份全局存储
	XSave.dir_override = DIR.path_join("other")
	s = XState.new_game_blank()
	check("other_dir_separate", not s.variables.has(1000) and XGlobalVars.path() == DIR.path_join("other/global.json"), [s.variables, XGlobalVars.path()])

	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
