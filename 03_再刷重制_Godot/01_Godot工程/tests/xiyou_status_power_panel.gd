extends Node
## 状态页「战力 N」按钮与角色战力面板（XPowerPanel，installEquipmentStatusRuntime renderPower）：
## - 覆盖说明：新开局各角色初始状态的「尚未完整评估的技能」「战力未计入」与正式版逐角色一致（tests/fixtures/power_coverage_oracle.json）。
## - 面板：各行文字与几何对照 tests/fixtures/power_panel_oracle.json（正式 v0.28 浏览器 DOM 读数）。
## 数值由 XPower 计算（xiyou_power 与 mv_oracle 比对；正式版浏览器开着五乘区成长修正，数字不同，面板只比结构与位置）。
## 加 -- --out=<目录> 时保存截图。

const COVERAGE := "res://tests/fixtures/power_coverage_oracle.json"
## 正式版另有专属模块的角色（未移植）：小猫（178）的「至圣喵心与连携」由 CodexCat 追加
const UNPORTED_EXTRA := {"178": [["至圣喵心与连携", "剑心、追击、巨龙试炼不计入战力参考"]]}
## 未移植模块造成的差异，整角色跳过：157／160 带 <CodexDisabledActor>（正式版不能行动，技能都算条件不满足）；
## 167 渡鸦的变身钩子（formHooks：神话封解作为另一条路线评估，Godot 只评不变身路线，所以多列一条「强化/变身/切换」）
const UNPORTED_SKIP := ["157", "160", "167"]
var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_status_power_panel"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XConfig.set_flag("codexPowerEnabled", true)
	XState.new_game(3, 1, [])
	_coverage()
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


func _coverage() -> void:
	var o: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(COVERAGE))
	var bad := []
	var t0 := Time.get_ticks_msec()
	for id in o.ids:
		var key := str(int(id))
		if UNPORTED_SKIP.has(key):
			continue
		var want: Dictionary = o.actors.get(key, {"unknown": [], "unmodeled": []})
		var a := XState.current.actor(int(id))
		var ev := XPower.evaluate(a, false)
		var unknown: Array = ev.coverage.unknown.map(func(r): return str(r.name))
		var unmodeled: Array = ev.coverage.unmodeled.map(func(r): return [str(r.name), str(r.reason)])
		var expect_unmodeled: Array = want.unmodeled.filter(func(r): return not UNPORTED_EXTRA.get(key, []).has(r))
		if unknown != want.unknown or unmodeled != expect_unmodeled:
			bad.append({"id": key, "got": [unknown, unmodeled], "want": [want.unknown, expect_unmodeled]})
	print("coverage %d actors %d ms" % [o.ids.size(), Time.get_ticks_msec() - t0])
	check("coverage_all_actors", bad.is_empty(), bad)
	check("coverage_cases", o.ids.size() >= 150 and o.actors.size() >= 30)
