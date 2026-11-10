extends Node
## 右侧状态格轮换顺序（rules-passive-order1）：原版 installEquipmentStatusRuntime stateRows 最后按类别「异常→增益→常驻」、
## 同类按名字 localeCompare(…,'zh-Hans') 稳定排序，强弱化行一起排。参照 tests/fixtures/zh_collate_names.json
## （07_开发环境/生成中文排序表.cjs 用 Node 的 ICU 排原版全部状态名、原样调用原版 stateKind 算全部状态的类别）。
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var f := FileAccess.open("res://tests/fixtures/zh_collate_names.json", FileAccess.READ)
	var ref = JSON.parse_string(f.get_as_text()) if f != null else null
	check("fixture", ref is Dictionary and ref.has("names") and ref.has("kinds"))
	if not (ref is Dictionary):
		return _finish()
	_collate(ref.names)
	_kinds(ref.kinds)
	_rows()
	_finish()


## 全部状态名＋强弱化名：倒序后用 XZhCollate 排，逐项等于 ICU 的顺序
func _collate(want: Array) -> void:
	var src := want.duplicate()
	src.reverse()
	var got := XZhCollate.stable_sort(src, XZhCollate.compare)
	var bad := -1
	for i in want.size():
		if got[i] != want[i]:
			bad = i
			break
	check("collate_all_%d" % want.size(), bad < 0, [bad, want[bad] if bad >= 0 else "", got[bad] if bad >= 0 else ""])
	# 几处要点：汉字在拉丁字母前，数字逐位比（10 在 2 前），稳定（相等保持原序）
	check("collate_han_before_latin", XZhCollate.compare("中毒", "A1") < 0)
	check("collate_digits", XZhCollate.compare("10", "2") < 0)
	check("collate_pinyin", XZhCollate.compare("难度适应", "破阵——天道诅咒") < 0 and XZhCollate.compare("破阵——天道诅咒", "普通难度·结算伤害") < 0)
	var pairs := [["b", 1], ["a", 2], ["b", 3], ["a", 4]]
	var s := XZhCollate.stable_sort(pairs, func(x, y): return XZhCollate.compare(x[0], y[0]))
	check("stable", s.map(func(x): return x[1]) == [2, 4, 1, 3], s)


## 原版 stateKind(s, false) 对全部状态逐个相同；passive 恒「常驻」
func _kinds(want: Dictionary) -> void:
	var diff := []
	for k in want:
		var st := XDB.rec("States", int(k))
		if st.is_empty():
			continue
		var got := XSideStatus.state_kind(st, false)
		if got != want[k]:
			diff.append([k, want[k], got])
	check("kinds_all_%d" % want.size(), diff.is_empty(), diff.slice(0, 10))
	check("kind_passive", XSideStatus.state_kind(XDB.rec("States", 5), true) == "常驻")
	# 缓存（_kind_cached）：两遍都与直算一致；被动恒「常驻」；换过的视图（破阵·真气倍率）不读缓存
	var cdiff := []
	for k in want:
		var st := XDB.rec("States", int(k))
		if st.is_empty():
			continue
		for i in 2:
			if XSideStatus._kind_cached(int(k), st, false) != want[k]:
				cdiff.append([k, i])
	check("kind_cache_all", cdiff.is_empty(), cdiff.slice(0, 10))
	check("kind_cache_passive", XSideStatus._kind_cached(5, XDB.rec("States", 5), true) == "常驻")
	var base := XDB.rec("States", 5)
	var view := base.duplicate(true)
	view.note = "<BuffType:增益>"
	view.restriction = 0
	view.name = "测试视图"
	view.traits = []
	check("kind_cache_view", XSideStatus._kind_cached(5, view, false) == "增益" and XSideStatus._kind_cached(5, base, false) == XSideStatus.state_kind(base, false),
		[XSideStatus._kind_cached(5, view, false), XSideStatus._kind_cached(5, base, false)])


## 实际轮换内容：破阵——天道诅咒 995（异常）、难度适应 1691、普通难度·结算伤害 1631（常驻），接物攻强化（增益）、敏捷弱化（异常）
func _rows() -> void:
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	XState.current = s
	var l := XBattleLogic.new()
	l.elite_roll = 100.0
	l.setup(2, s)
	var a: XActor = l.actors[0]
	a.state_ids.clear()
	a.buffs.fill(0)
	for id in [1631, 1691, 995]:  # 故意倒着挂
		a.add_state(id)
	var icon := func(id): return int(XDB.rec("States", id).iconIndex)
	var rows := XSideStatus.cell_rows(a)
	var want := [icon.call(995), icon.call(1691), icon.call(1631)]
	check("rows_original_cq", rows.map(func(r): return r.icon) == want, [rows, want])  # 原版读数 995→1691→1631
	a.buffs[2] = 2
	a.buffs[6] = -1
	rows = XSideStatus.cell_rows(a)
	want = [XEnemyStateIcon.buff_icon(-1, 6), icon.call(995), XEnemyStateIcon.buff_icon(2, 2), icon.call(1691), icon.call(1631)]
	check("rows_with_buffs", rows.map(func(r): return r.icon) == want, [rows, want])
	check("rows_stack", rows[0].stack == 1 and rows[2].stack == 2 and rows[0].keys().size() == 2, rows)
	XSideStatus.CELL_FILTER = false
	var raw: Array = XSideStatus.cell_rows(a).map(func(r): return r.icon)
	XSideStatus.CELL_FILTER = true
	check("rollback_unsorted", not raw.has(XEnemyStateIcon.buff_icon(2, 2)) and raw.size() >= 3, raw)


func _finish() -> void:
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
