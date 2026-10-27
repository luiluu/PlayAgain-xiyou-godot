extends Node
## YEP_X_Autosave 的允许开关（八戒 2026-10-27，沙僧第三期 G1／P2）：照冻结源 Game_System.setAutosave／canAutosave——
## Enable→Autosave→Disable→Autosave 只保存 1 次，再 Enable 后才第 2 次；公共事件 5（Enable→Autosave→Disable）之后
## Map178 EV5 出民宅时的 Autosave 不再写档；开关随存档，新局与缺键旧档默认允许。只写测试目录，不碰真实存档。
## 宿主用事件对照的记录替身（tests/xiyou_event_compare.gd 的 EventHost）。

const EC := preload("res://tests/xiyou_event_compare.gd")
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _cmd(code: int, params: Array, indent := 0) -> Dictionary:
	return {"code": code, "indent": indent, "parameters": params}


func _plugin(list: Array) -> Array:
	var out := list.map(func(n): return _cmd(356, [n]))
	out.append(_cmd(0, []))
	return out


func _exec(host, list: Array) -> void:
	var interp := MVInterpreter.new(host, 4, 0, list)
	await interp.run()


func _run() -> void:
	GameApp.fast_headless_frames()
	XSave.dir_override = "user://test_xiyou_autosave"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	var host = EC.EventHost.new()
	add_child(host)
	var s := XState.new_game_blank()
	s.add_actor(1)
	s.map_id = 4
	XState.current = s
	_check("new_game_allows", s.allow_autosave)
	XSave.current_slot = 0
	await _exec(host, _plugin(["Autosave"]))
	_check("no_slot_no_save", s.save_count == 0, s.save_count)
	XSave.save(7)
	XSave.current_slot = 7
	var base := s.save_count
	await _exec(host, _plugin(["EnableAutosave", "Autosave", "DisableAutosave", "Autosave"]))
	_check("disable_blocks", s.save_count == base + 1 and not s.allow_autosave, [s.save_count - base, s.allow_autosave])
	await _exec(host, _plugin(["Autosave"]))
	_check("still_disabled", s.save_count == base + 1, s.save_count - base)
	await _exec(host, _plugin(["EnableAutosave", "Autosave"]))
	_check("reenable_saves", s.save_count == base + 2 and s.allow_autosave, s.save_count - base)
	# 公共事件 5（变量 21＝0 时 Enable→Autosave→Disable），然后出民宅（Map178 EV5）的 Autosave
	s.set_variable(21, 0)
	var ce5: Array = XDB.rec("CommonEvents", 5).get("list", []).duplicate(true)
	await _exec(host, ce5)
	_check("ce5_saves_once", s.save_count == base + 3 and not s.allow_autosave, [s.save_count - base, s.allow_autosave])
	await _exec(host, _plugin(["Autosave"]))
	_check("house_exit_no_save", s.save_count == base + 3, s.save_count - base)
	# 随存档：关着存、读回仍关；缺键（旧档）为允许
	var d := s.to_dict()
	_check("saved_flag", d.get("allowAutosave") == false)
	_check("load_keeps_flag", XState.from_dict(d).allow_autosave == false)
	d.erase("allowAutosave")
	_check("old_save_default", XState.from_dict(d).allow_autosave == true)
	_finish()


func _finish() -> void:
	for f in DirAccess.get_files_at(XSave.dir()):
		DirAccess.remove_absolute(XSave.dir().path_join(f))
	DirAccess.remove_absolute(XSave.dir())
	XSave.dir_override = ""
	XSave.current_slot = 0
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
