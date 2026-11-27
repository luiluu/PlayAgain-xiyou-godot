extends Node
## T566：天启篇改写表里写了 state_note 的状态，说明都要进运行时记录。原版记录没有 <StateNote> 块的（含 10801 起的新状态）
## 以前整句被丢掉，状态窗看不到。查三处：记录备注、队员状态窗（XPartyStatusPanel.description）、首领状态窗用的备注块；西游档逐条原样。
const Kit := preload("res://tests/lib/tq_save_kit.gd")

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


## 表里写了非空 state_note 的状态号
func _noted_ids() -> Array:
	var out := []
	var states: Dictionary = XTianqiSkills.data().get("states", {})
	for k in states:
		if str(states[k].get("state_note", "")) != "":
			out.append(int(k))
	out.sort()
	return out


func _run() -> void:
	XMessageBox.auto = true
	var kit := Kit.new("xiyou_tianqi_t566")
	XTianqiSkills.reload_table()

	var s := XTianqi.start_new_game(3, "jianxian", [1])
	XTianqi.take_pending()
	XState.current = s
	var ids := _noted_ids()
	_check("noted_states_found", ids.size() >= 290, ids.size())
	var states: Dictionary = XTianqiSkills.data().get("states", {})
	var no_block := []
	var wrong_panel := []
	var wrong_boss := []
	var new_ids := 0
	for id in ids:
		var want := str(states[str(id)].state_note)
		var st := XDB.rec("States", id)
		if XTianqiSkills.has_new_state(id):
			new_ids += 1
		var note := str(st.get("note", ""))
		if note.count("<StateNote>") != 1 or not note.contains("<StateNote>\n%s\n</StateNote>" % want):
			no_block.append(id)
		if XPartyStatusPanel.description(st) != XGearQuery.text(want):
			wrong_panel.append([id, XPartyStatusPanel.description(st), want])
		if XBossStatus.note_block(note, "StateNote") == "":
			wrong_boss.append(id)
	_check("new_states_covered", new_ids > 0, new_ids)
	_check("note_has_single_block_%d" % ids.size(), no_block.is_empty(), [no_block.size(), no_block.slice(0, 20)])
	_check("party_panel_text_%d" % ids.size(), wrong_panel.is_empty(), [wrong_panel.size(), wrong_panel.slice(0, 5)])
	_check("boss_panel_block_%d" % ids.size(), wrong_boss.is_empty(), [wrong_boss.size(), wrong_boss.slice(0, 20)])

	# 协调追加（T528 复核遗留）：三招目标栏
	var targets := {5635: "敌方全体", 5636: "敌方全体", 1181: "随机攻击四次，可重复命中同一敌人"}
	for sid in targets:
		var sk_note := str(XDB.rec("Skills", sid).get("note", ""))
		_check("target_header_%d" % sid, sk_note.contains("对象:%s size=" % targets[sid]), sk_note)

	# 西游档：库内状态逐条是原表那一条（不换视图、不补说明）
	var xy := XState.new_game(3, 1, [8])
	XState.current = xy
	var table: Array = XDB.table("States")
	var changed := []
	var seen := 0
	for id in ids:
		if id >= table.size():
			continue
		seen += 1
		if str(XDB.rec("States", id).get("note", "")) != str((table[id] as Dictionary).get("note", "")):
			changed.append(id)
	_check("xiyou_untouched_%d" % seen, seen > 0 and changed.is_empty(), changed.slice(0, 20))

	# 同一次开游戏里天启篇、西游档来回读：状态格「可见／类别」缓存不能串（560 痔群原版没有任何能写出的说明，状态格不显示；天启篇有说明后显示）
	var seq := []
	for save in [s, xy, s, xy]:
		XState.current = save
		seq.append(XSideStatus._visible_cached(560, XDB.rec("States", 560)))
	_check("side_cell_cache_per_mode", seq == [true, false, true, false], seq)

	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
