extends Node
## 【cc·悟空·未经审查】179 流萤技能说明按阶生成（XLiuying.skill_lines／text_view，v0.62.12 第 15 节 L.skillLines／refreshText）。
## - rank.*：流萤没建／进阶 0～4，10622、10623 说明副本的备注与 mv_oracle/liuying_text_probe.cjs 的新源参照
##   （tests/fixtures/liuying_text_oracle.json）逐字比；XHelpCard.desc_params 的行（文字、字号、颜色）与 RJO.HE.getDescParams 逐行比；
##   XHelpCard.content 走到了副本（三阶燃烧有「施放后33%概率不进入冷却」、没有「解锁：进阶2阶」）。
## - 开关 TEXT_BY_RANK 关掉：原样返回数据库技能（备注等于 0 阶写法）。
const FIXTURE := "res://tests/fixtures/liuying_text_oracle.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _state(rank) -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	if rank != null:
		s.actor_advance[XLiuying.ACTOR] = int(rank)
	return s


func _texts(rows: Array) -> Array:
	return rows.map(func(r): return str(r[0]))


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("oracle_present", ref is Dictionary and ref.has("cases") and ref.cases.size() == 6):
		return finish()
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		var s := _state(c.setup.rank)
		for id in [XLiuying.TIANHUO, XLiuying.RANSHAO]:
			var o: Dictionary = c.observed[str(id)]
			var v := XLiuying.text_view(XDB.rec("Skills", id), s)
			check("%s.%d.note" % [c.id, id], str(v.note) == str(o.note), [v.note, o.note])
			var rows := XHelpCard.desc_params(v, 3)
			var got := rows.map(func(r): return [str(r[0]), int(r[1]), str(r[2])])
			var want: Array = o.rows.map(func(r): return [str(r[0]), int(r[1]), str(r[2])])
			check("%s.%d.rows" % [c.id, id], got == want, [got, want])
	_state(3)
	var top := _texts(XHelpCard.content(XDB.rec("Skills", XLiuying.RANSHAO)))
	check("content.rank3", top.any(func(t): return t.contains("施放后33%概率不进入冷却")) and not top.any(func(t): return t.contains("解锁：进阶2阶")), top)
	XLiuying.TEXT_BY_RANK = false
	var raw := XDB.rec("Skills", XLiuying.RANSHAO)
	check("switch_off.same", XLiuying.text_view(raw, _state(3)) == raw)
	var off := _texts(XHelpCard.content(raw))
	check("switch_off.content", off.any(func(t): return t.contains("解锁：进阶2阶")), off)
	XLiuying.TEXT_BY_RANK = true
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_liuying_text", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
