extends Node
## 战力（installCombatPowerRuntime v2，XPower）：与 mv_oracle power_probe 的参照（generated/oracle/power.json）逐例比对。
## 装备评分：每件装备的总分、三项与逐行明细（标签与三项数值，差 1e-6 以内），含法宝（初始等级）。

const ORACLE := "res://modes/xiyou/generated/oracle/power.json"
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _close(a: Array, b: Array, eps := 1e-6) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if absf(float(a[i]) - float(b[i])) > eps * maxf(1.0, absf(float(b[i]))):
			return false
	return true


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_power"
	XConfig.path_override = XSave.dir().path_join("options.json")
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if check("power_oracle_loaded", data is Dictionary and data.get("gear", []).size() >= 50, ORACLE):
		_gear(data)
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


func _gear(data: Dictionary) -> void:
	for c in data.gear:
		var rec := XDB.rec("Weapons" if c.kind == "weapon" else "Armors", int(c.id))
		var s := XPower.equipment(rec)
		var got_rows: Array = s.rows.map(func(r): return [r.label, r.parts])
		var want_rows: Array = c.rows.map(func(r): return [r.label, r.parts])
		var ok: bool = int(s.total) == int(c.total) and _close(s.parts, c.parts) and got_rows.size() == want_rows.size()
		for i in range(mini(got_rows.size(), want_rows.size())):
			ok = ok and got_rows[i][0] == want_rows[i][0] and _close(got_rows[i][1], want_rows[i][1])
		check("gear_%s%d" % [c.kind, int(c.id)], ok, {"got": [s.total, s.parts, got_rows], "want": [c.total, c.parts, want_rows], "why": c.why})
	check("gear_magic_covered", data.gear.filter(func(c): return bool(c.magic)).size() >= 5)
	# 关掉「战力显示与估算」时为 0
	XConfig.set_flag("codexPowerEnabled", false)
	XPower._gear_cache.clear()
	check("gear_disabled_zero", int(XPower.equipment(XDB.rec("Weapons", 1)).total) == 0)
	XConfig.set_flag("codexPowerEnabled", true)
