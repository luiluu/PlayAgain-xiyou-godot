extends Node
## 状态详情面板（XPartyStatusPanel，原版 installEquipmentStatusRuntime renderStatus／stateRows）：
## - 全部状态的「能不能进详情」和说明文字逐个等于原版（tests/fixtures/state_detail_oracle.json，07_开发环境/生成状态详情参照.cjs
##   从原版运行时原样取 stateDescription／visibleState 算出）；
## - 行内容：类别、时长（回合／本回合／常驻／被动常驻／本场战斗／持续生效）、层数、强弱化行；排序同状态格；
## - 面板：标题、四个页签的计数、默认「全部」、切页签、搜索、异常卡红边、关闭。
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_oracle()
	await _panel()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit.call_deferred(0 if passed == total else 1)


func _oracle() -> void:
	var f := FileAccess.open("res://tests/fixtures/state_detail_oracle.json", FileAccess.READ)
	var ref = JSON.parse_string(f.get_as_text()) if f != null else null
	check("fixture", ref is Dictionary and ref.has("states"))
	if not (ref is Dictionary):
		return
	var vis_diff := []
	var desc_diff := []
	for k in ref.states:
		var st := XDB.rec("States", int(k))
		if st.is_empty():
			continue
		var want: Array = ref.states[k]
		if XSideStatus.visible_state(st) != bool(want[0]):
			vis_diff.append([k, want[0]])
		if bool(want[0]) and XPartyStatusPanel.description(st) != str(want[1]):
			desc_diff.append([k, want[1], XPartyStatusPanel.description(st)])
	check("visible_all_%d" % ref.states.size(), vis_diff.is_empty(), vis_diff.slice(0, 10))
	check("description_all", desc_diff.is_empty(), [desc_diff.size(), desc_diff.slice(0, 5)])


func _panel() -> void:
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	XState.current = s
	var l := XBattleLogic.new()
	l.elite_roll = 100.0
	l.setup(2, s)
	var a: XActor = l.actors[0]
	a.state_ids.clear()
	a.buffs.fill(0)
	for id in [1631, 1691, 995]:
		a.add_state(id)
	a.buffs[2] = 2
	a.buff_turns[2] = 3
	a.buffs[6] = -1
	a.buff_turns[6] = 1
	var rows := XPartyStatusPanel.rows_for(a)
	var names: Array = rows.map(func(r): return r.name)
	check("rows_order", names.slice(0, 2) == ["敏捷弱化", str(XDB.rec("States", 995).name)] and names.has("物攻强化"), names)
	var buff: Dictionary = rows.filter(func(r): return r.name == "物攻强化")[0]
	check("buff_row", buff.kind == "增益" and buff.stack == 2 and buff.duration == "3回合" and buff.description == "物攻" + XPartyStatusPanel.pct(a.param_buff_rate(2) - 1.0), buff)
	var deb: Dictionary = rows[0]
	check("debuff_row", deb.kind == "异常" and deb.stack == 1 and deb.duration == "1回合", deb)
	check("pct_js", XPartyStatusPanel.pct(0.5) == "+50%" and XPartyStatusPanel.pct(-0.25) == "-25%" and XPartyStatusPanel.pct(0.1234) == "+12.3%" and XPartyStatusPanel.pct(0.0) == "0%")
	for r in rows:
		if r.id is int:
			var st := XDB.rec("States", r.id)
			var want := "常驻" if str(st.get("note", "")).to_lower().contains("<permanent>") else ("本场战斗" if bool(st.get("removeAtBattleEnd", false)) else "持续生效")
			if int(st.get("autoRemovalTiming", 0)) > 0:
				want = "%d回合" % ceili(float(a.state_turns[r.id])) if float(a.state_turns.get(r.id, 0)) > 0 else "本回合"
			check("duration_%d" % r.id, r.duration == want, [r.duration, want])
	# 面板
	var root := Control.new()
	root.size = Vector2(1280, 720)
	add_child(root)
	var p := XPartyStatusPanel.open(root, [a, l.actors[1]], a)
	await get_tree().process_frame
	var labels := _texts(p)
	check("title", labels.has(a.display_name() + " · 状态详情") and labels.has("查看时暂停战斗，关闭后继续。") and labels.has("显示实际效果、剩余回合和层数。"), labels)
	var abn := rows.filter(func(r): return r.kind == "异常").size()
	var tabs := _tabs(p)
	check("tabs", tabs == ["异常 %d" % abn, "增益 %d" % rows.filter(func(r): return r.kind == "增益").size(),
		"常驻 %d" % rows.filter(func(r): return r.kind == "常驻").size(), "全部 %d" % rows.size()], tabs)
	check("pills", labels.has("HP %d / %d" % [int(a.hp), int(a.mhp)]) and labels.has("TP %d" % int(a.tp)), labels)
	check("cards_all", _cards(p) == rows.size(), _cards(p))
	await _shot("status_detail_all")
	p._pick_tab("异常")
	await get_tree().process_frame
	await _shot("status_detail_abnormal")
	check("cards_abnormal", _cards(p) == abn and p.tab == "异常", _cards(p))
	var red := false
	for c in _card_nodes(p):
		var st := (c.get_child(0) as Panel).get_theme_stylebox("panel") as StyleBoxFlat
		red = st.border_color == XPartyStatusPanel.BAD
	check("abnormal_red_edge", red)
	p._pick_tab("全部")
	p._search.text = "敏捷"
	p._search.text_changed.emit("敏捷")
	await get_tree().process_frame
	check("search", p.filtered().all(func(r): return XGearQuery.alias(r.name + " " + r.description).contains("敏捷")) and _cards(p) == p.filtered().size() and _cards(p) >= 1, _cards(p))
	p._search.text_changed.emit("不存在的字")
	await get_tree().process_frame
	check("search_empty", _texts(p).has("没有状态符合当前条件。"))
	var closed := [false]
	p.closed.connect(func(): closed[0] = true)
	p.close()
	check("close", closed[0])
	root.queue_free()


## 窗口模式加 -- --out=<目录> 存截图
func _shot(name: String) -> void:
	var dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			dir = arg.substr(6)
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))


func _texts(n: Node) -> Array:
	var out := []
	for c in n.find_children("*", "Label", true, false):
		out.append(c.text)
	return out


func _tabs(p: Node) -> Array:
	return p.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("tab")).map(func(b): return b.text)


func _card_nodes(p: XPartyStatusPanel) -> Array:
	return p._cards.find_children("*", "Control", true, false).filter(func(c): return c.has_meta("state"))


func _cards(p: XPartyStatusPanel) -> int:
	return _card_nodes(p).size()
