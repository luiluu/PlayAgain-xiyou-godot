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


## 天启篇要进「异常」页签的状态：持续火伤、承伤上升、输出下降（这里单列，不从表里读，表里漏标就红）
const ABNORMAL_IDS := [1819,
	189, 233, 946, 856, 907, 916, 869, 706, 1409, 2023, 1086, 1752, 1093, 1139, 1145, 1824, 1826, 1827, 1158, 1172, 1596, 2776, 10819,
	190, 191, 969, 972, 966, 10812, 10816, 1821, 1664, 10827, 10828, 1832, 1134, 1157, 1539]
## 说明照当前实战写的（逐字）
const EXACT_NOTES := {
	2561: "受到的伤害 −10%",  # T570：Kyo 11-27 天启篇改成设计稿 −10%（西游档仍是贝吉特调整的 −50%）
	2562: "受到伤害时，用魔法值抵消 30% 的伤害（向下取整）",  # T570 改成设计值
	2560: "下次倒下时回复 1 点生命，触发一次",  # T570 R1：每次施放给一次
	2554: "倒下时复活并回复 30% 生命，随后解除此状态",
	902: "双防 +10%，每回合回复5%生命，另回复施加者魔法攻击×10的生命（浮动±20%）",
	2564: "普通攻击额外命中一次",
	1317: "物攻、物防、魔攻、魔防、敏捷、幸运 +5%",
	10818: "物攻、物防、魔攻、魔防、敏捷、幸运 +5%",
	1099: "被随机选为攻击目标的权重减半；死后30%概率复活，回复30%生命（每场一次）",
	1539: "被随机选为攻击目标的权重变为 3 倍，造成的伤害 −10%",
	1178: "被随机选为攻击目标的权重变为 10 倍；死后30%概率复活，回复30%生命（每场一次）",
	2785: "免疫愤怒、混乱、魅惑、睡眠",
}
const EXACT_NAMES := {2499: "人问", 1519: "封弊", 1583: "神话领域", 1584: "神话领域", 2561: "吃瘪之力", 2564: "普通攻击追加"}


## 走队员状态窗的列表入口（XPartyStatusPanel.rows_for，会过 visible_state）：逐个挂上，列表里要有这一行，名字、说明照改写表
func _panel_list(s: XState, ids: Array, states: Dictionary) -> void:
	XTianqi._joining = true
	s.add_actor(1)
	XTianqi._joining = false
	var a: XActor = s.actor(1)
	a.recover_all()
	var missing := []
	var wrong := []
	var not_abnormal := []
	var rows_of := {}
	for id in ids:
		a.state_ids.clear()
		a.buffs.fill(0)
		a.state_ids.append(id)
		var hit := XPartyStatusPanel.rows_for(a).filter(func(r): return r.id is int and r.id == id)
		if hit.is_empty():
			missing.append(id)
			continue
		rows_of[id] = hit[0]
		var spec: Dictionary = states[str(id)]
		var want_name := str(spec.get("name", XDB.rec("States", id).get("name", "")))
		if str(hit[0].name) == "" or str(hit[0].name) != want_name or str(hit[0].description) != XGearQuery.text(str(spec.state_note)):
			wrong.append([id, hit[0].name, hit[0].description])
	_check("panel_list_has_%d" % ids.size(), missing.is_empty(), [missing.size(), missing.slice(0, 20)])
	_check("panel_list_name_and_text", wrong.is_empty(), [wrong.size(), wrong.slice(0, 10)])
	# 表里没写说明的也要查页签（856、907、916、869 靠特性写说明）
	for id in ABNORMAL_IDS:
		a.state_ids.clear()
		a.state_ids.append(id)
		var hit := XPartyStatusPanel.rows_for(a).filter(func(r): return r.id is int and r.id == id)
		# 被动来源（不在 state_ids 里）也走同一标记
		var kinds := [str(hit[0].kind) if not hit.is_empty() else "（没进列表）",
			XSideStatus.state_kind(XDB.rec("States", id), true), XSideStatus._kind_cached(id, XDB.rec("States", id), true)]
		if kinds != ["异常", "异常", "异常"]:
			not_abnormal.append([id, kinds])
	_check("abnormal_tab_%d" % ABNORMAL_IDS.size(), not_abnormal.is_empty(), [not_abnormal.size(), not_abnormal.slice(0, 20)])
	# 说明里写承伤上升、输出下降、持续火伤的，以后新增也得进「异常」
	var re := RegEx.create_from_string("受到的.{0,6}(伤害|暴击的概率) *(\\+|提高)|承受伤害 *\\+|造成的伤害 *[−-]|(^|，)伤害 *[−-]|每回合受到.*火焰伤害")
	var leaked := ids.filter(func(id): return re.search(str(states[str(id)].state_note)) != null and str(rows_of.get(id, {}).get("kind", "")) != "异常")
	_check("abnormal_by_wording", leaked.is_empty(), leaked)
	var bad_notes := EXACT_NOTES.keys().filter(func(id): return str(rows_of.get(id, {}).get("description", "")) != EXACT_NOTES[id])
	_check("exact_notes", bad_notes.is_empty(), bad_notes.map(func(id): return [id, rows_of.get(id, {}).get("description", "")]))
	var bad_names := EXACT_NAMES.keys().filter(func(id): return str(rows_of.get(id, {}).get("name", "")) != EXACT_NAMES[id])
	_check("exact_names", bad_names.is_empty(), bad_names.map(func(id): return [id, rows_of.get(id, {}).get("name", "")]))
	var old_names := []
	for id in ids:
		var n := str(rows_of.get(id, {}).get("name", ""))
		for bad in ["终伤", "爆伤500", "元素伤害+", "追加次数", "追加攻击次数", "减伤90"]:
			if n.contains(bad):
				old_names.append([id, n])
	_check("no_stale_numeric_names", old_names.is_empty(), old_names)
	a.state_ids.clear()


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

	_panel_list(s, ids, states)

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
	# 西游档名字照原表、不带天启篇页签；分类走原版规则
	var xy_changed := []
	for id in states.keys().map(func(k): return int(k)):
		if id >= table.size() or not table[id] is Dictionary:
			continue
		var st := XDB.rec("States", id)
		if st.has("tianqiKind") or str(st.get("name", "")) != str((table[id] as Dictionary).get("name", "")):
			xy_changed.append(id)
	_check("xiyou_name_kind_untouched", xy_changed.is_empty(), xy_changed.slice(0, 20))
	var xy_kinds := [[2023, "常驻"], [1409, "增益"], [1086, "增益"], [1819, "异常"]].filter(func(e): return XSideStatus.state_kind(XDB.rec("States", e[0]), false) != e[1])
	_check("xiyou_kind_rule_unchanged", xy_kinds.is_empty(), xy_kinds.map(func(e): return [e[0], XSideStatus.state_kind(XDB.rec("States", e[0]), false)]))

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
