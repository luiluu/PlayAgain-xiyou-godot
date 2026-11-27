extends Node
## T568 专项：skill_rework.json、actor_notes.json 里的角色名写成「{角色号}」，读表时按 actor_names.json 展开。
## 一、两张表读进来没有没展开的占位；二、只改 actor_names.json 的几个名字（改内存里那份命名表），卡面、技能记录、
## 状态、装备说明、图鉴备注全跟着变；登记过的同字原文（154 故事里的食物）不跟着变；三、西游档记录与原表一致。
## 末尾打一行展开耗时（交付单用，不算断言）。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _reload() -> void:
	XTextFix.clear_cache()  # 数据库表上的定向改名（actor_names.json 的 tables）也要按改后的名字重读
	XTianqiSkills.reload_table()
	XTianqiActorNotes.reload_table()


## 没展开的 {数字}（前面带 $ 的是 note_sub 的正则回填，不算）；_ 开头的注释键不看
func _unexpanded(value, path: String, out: Array, ref: RegEx) -> void:
	if value is Dictionary:
		for k in value:
			if not str(k).begins_with("_"):
				_unexpanded(value[k], path + "/" + str(k), out, ref)
	elif value is Array:
		for i in value.size():
			_unexpanded(value[i], path + "/" + str(i), out, ref)
	elif value is String and ref.search(value) != null:
		out.append([path, value])


func _snapshot() -> Dictionary:
	var sk := XTianqiSkills.data()
	var notes := XTianqiActorNotes.table()
	return {
		"card": str(sk.actors["25"].name),
		"skill": str(sk.skills["1770"].name),
		"tuned_desc": str(sk.skills["10642"].desc[2]),
		"state": str(sk.states["10822"].name),
		"gear_desc": str(sk.gear["armor:3559"].desc[0]),
		"short_name": str(sk.skills["2774"].name),
		"literal_skill": str(sk.skills["7235"].name),
		"note_name": str(notes.actors["25"].name),
		"food_name": str(notes.actors["154"].name),
		"food_story": str(notes.actors["154"].story),
	}


func _run() -> void:
	var ref := RegEx.create_from_string("(?<!\\$)\\{\\d+\\}")
	XDB.json_cache = false  # 文字修正的磁盘缓存按 actor_names.json 的文件内容算签名；这里只改内存里的命名表，不能吃缓存
	XTextFix.set_all(true)
	_reload()
	var left := []
	_unexpanded(XTianqiSkills.data(), "skill_rework", left, ref)
	_unexpanded(XTianqiActorNotes.table(), "actor_notes", left, ref)
	_check("tables_loaded", not XTianqiSkills.data().is_empty() and not XTianqiActorNotes.table().is_empty())
	_check("no_unexpanded_ref", left.is_empty(), left.slice(0, 5))

	var names: Dictionary = XTextFix.actor_names().names
	var mismatch := []
	for k in XTianqiSkills.data().actors:
		if names.has(k) and XTianqiSkills.data().actors[k].has("name") and str(XTianqiSkills.data().actors[k].name) != str(names[k]):
			mismatch.append(["skill_rework", k])
	for k in names:
		if str(XTianqiActorNotes.table().actors.get(k, {}).get("name", "")) != str(names[k]):
			mismatch.append(["actor_notes", k])
	_check("card_names_equal_catalog", mismatch.is_empty(), mismatch.slice(0, 5))

	var before := _snapshot()
	_check("backref_kept", str(XTianqiSkills.data().gear["armor:4147"].note_sub[0][1]).contains("${1}"), XTianqiSkills.data().gear["armor:4147"].note_sub)

	# 只改命名表：25 老狗、42、47、70、127、154、180
	var old := {}
	for id in ["25", "42", "70", "127", "154", "180"]:
		old[id] = str(names[id])
		names[id] = "改名样例" + id
	_reload()
	var after := _snapshot()
	_check("rename_card", after.card == "改名样例25" and after.note_name == "改名样例25", after)
	_check("rename_skill", after.skill == "觉醒:改名样例25", after.skill)
	_check("rename_tuned_desc", after.tuned_desc.contains("改名样例180") and not after.tuned_desc.contains(old["180"]), after.tuned_desc)
	_check("rename_state", after.state == "改名样例127不灭", after.state)
	_check("rename_gear_desc", after.gear_desc.contains("改名样例42"), after.gear_desc)
	_check("rename_composed_name", after.short_name == "改名样例70剑气", after.short_name)
	_check("rename_keeps_same_word_original", after.literal_skill == before.literal_skill, after.literal_skill)
	_check("rename_note_keeps_food", after.food_name == "改名样例154" and after.food_story == before.food_story and after.food_story.contains(old["154"]), [after.food_name, after.food_story])

	# 运行时记录（天启篇卡面实际走的口）
	var s := XState.new()
	s.flags["tianqi"] = {"rules": 1}
	XState._become_current(s)
	_check("tianqi_active", XTianqi.active(XState.current))
	_check("rename_runtime_skill_rec", str(XDB.rec("Skills", 1770).get("name", "")) == "觉醒:改名样例25", XDB.rec("Skills", 1770).get("name"))
	_check("rename_runtime_state_rec", str(XDB.rec("States", 10822).get("name", "")) == "改名样例127不灭", XDB.rec("States", 10822).get("name"))
	_check("rename_runtime_book_note", XTianqiActorNotes.lines_of(154).size() == 2 and str(XTianqiActorNotes.lines_of(154)[1]) == str(XTianqiActorNotes.table().actors["154"].trait))

	for id in old:
		names[id] = old[id]
	_reload()
	_check("restore", _snapshot() == before, _snapshot())

	# 西游档：技能记录就是原表那一条
	XState._become_current(XState.new())
	var raw: Array = XDB.table("Skills")
	_check("legacy_skill_untouched", XDB.rec("Skills", 1770) == raw[1770] and not str(raw[1770].name).contains(old["25"]), XDB.rec("Skills", 1770).get("name"))
	_check("legacy_notes_off", XTianqiActorNotes.lines_of(154).is_empty())

	# 耗时：只量展开这一步（游戏里每张表首次读时做一次）
	for path in [XTianqiSkills.PATH, XTianqiActorNotes.PATH]:
		var text := FileAccess.get_file_as_string(path)
		var spent := []
		for i in 7:
			var parsed = JSON.parse_string(text)
			var t0 := Time.get_ticks_usec()
			XTextFix.expand_actor_refs(parsed)
			spent.append((Time.get_ticks_usec() - t0) / 1000.0)
		spent.sort()
		var t1 := Time.get_ticks_usec()
		JSON.parse_string(text)
		print("T568_COST ", path.get_file(), " expand_ms_median=", spent[3], " json_parse_ms=", (Time.get_ticks_usec() - t1) / 1000.0)

	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
