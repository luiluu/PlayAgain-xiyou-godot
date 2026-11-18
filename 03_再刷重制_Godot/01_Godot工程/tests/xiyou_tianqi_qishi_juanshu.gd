extends Node
const Kit := preload("res://tests/lib/tq_save_kit.gd")
## T177：天启篇「天道眷顾者」→「启示眷属」。
## 一、18 张图的 code=355 $.toaster（各一条）：天启篇档显示「启示眷属」，西游档原样；MVScript.QISHI_RENAME 关掉也原样。
## 二、Skills 6162 劫天运备注：天启篇档换、西游档原样、XTextFix.DICT 关掉回原貌。
## 三、天道加持／补偿等别的「天道」文字不受影响。
const MAPS := [30, 32, 33, 45, 46, 47, 64, 116, 117, 118, 119, 120, 144, 145, 146, 147, 155, 182]
const OLD := "天道眷顾者"
const NEW := "启示眷属"

var results: Array = []


class Host:
	extends RefCounted
	var toasts: Array = []
	func toast(t: String) -> void:
		toasts.append(t)


class Interp:
	extends RefCounted
	var host := Host.new()


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _scripts(map_id: int) -> Array:
	var out := []
	for ev in XDB.map(map_id).events:
		if ev == null or not ev is Dictionary and not ev is Object:
			continue
		for pg in ev.pages:
			for c in pg.list:
				if int(c.code) == 355 and str(c.parameters[0]).contains("天道眷顾"):
					out.append(str(c.parameters[0]))
	return out


func _toast_for(code: String) -> String:
	var it := Interp.new()
	await MVScript.run(code, it)
	return "|".join(it.host.toasts)


func _skill_note() -> String:
	return str(XDB.table("Skills")[6162].note)


func _run() -> void:
	XMessageBox.auto = true
	var kit := Kit.new("xiyou_tianqi_qishi_juanshu")
	_check("defaults", MVScript.QISHI_RENAME and XTextFix.DICT)
	# 西游档（原文）：先取原始脚本，再逐档比
	XState.current = XState.new_game_blank()
	XTextFix.sync_mode()
	var raw := {}
	for m in MAPS:
		raw[m] = _scripts(m)
		_check("map%d_one_script" % m, raw[m].size() == 1, raw[m].size())
	_check("plain_skill_orig", _skill_note().contains(OLD) and not _skill_note().contains(NEW))
	for m in MAPS:
		var t := await _toast_for(raw[m][0])
		_check("plain_map%d" % m, t.contains(OLD) and not t.contains(NEW), t)
	# 天启篇档
	Kit.new_game("jiusi")
	_check("tq_on", XTextFix.tq_on())
	var heaven_ok := true
	for m in MAPS:
		var t2 := await _toast_for(raw[m][0])
		_check("tq_map%d" % m, t2.contains(NEW) and not t2.contains(OLD), t2)
		# 其余文字照旧：除了换词，与西游档一致
		MVScript.QISHI_RENAME = false
		var t3 := await _toast_for(raw[m][0])
		MVScript.QISHI_RENAME = true
		_check("tq_map%d_switch_off" % m, t3.contains(OLD) and t3.replace(OLD, NEW) == t2, [t2, t3])
	_check("tq_skill", _skill_note().contains(NEW) and not _skill_note().contains(OLD))
	XTextFix.DICT = false
	XTextFix.clear_cache()
	_check("tq_skill_dict_off", _skill_note().contains(OLD))
	XTextFix.DICT = true
	XTextFix.clear_cache()
	# 天道加持／补偿维持现状：这些词不在替换范围
	_check("heaven_other_kept", MVScript._qishi_text("天道加持，天道补偿") == "天道加持，天道补偿")
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
