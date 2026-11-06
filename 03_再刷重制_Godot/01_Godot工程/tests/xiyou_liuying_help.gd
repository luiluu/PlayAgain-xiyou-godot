extends Node
## 【cc·界面·未经审查】流萤技能卡（总装追加，流萤运行时清单 13、15）：照 liuying_help_probe（tests/fixtures/liuying_help_oracle.json，v0.62.12）比——
## 15：10622／10623 的说明卡按流萤进阶 0～3 阶（再回 0）逐行比文字、字号、颜色、对齐、y 与卡高（XLiuyingHelp.view 接在 XHelpCard._content 开头）；
## 13：10622～10632 与带 <CodexLiuyingPassive: 的技能名颜色＝列表名字色 XQuality.list_color（drawItemName 包装的 QualitiesColor[品质]）。
const FIXTURE := "res://tests/fixtures/liuying_help_oracle.json"
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 20:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1500))


func _texts(rows: Array) -> Array:
	return rows.map(func(r): return str(r[0]))


func _card(tag: String, obj: Dictionary, c: Dictionary) -> void:
	var got := XHelpCard.content(obj)
	var want: Array = c.rows
	var lay := XHelpCard.layout(got, 0, XHelpCard.note_width(obj), func(t: String, sz: int): return t.length() * sz * 0.6)
	var ok := got.size() == want.size()
	var bad = null
	for i in range(mini(got.size(), want.size())):
		var g: Array = got[i]
		var w: Array = want[i]
		if not (str(g[0]) == str(w[0]) and int(g[1]) == int(w[1]) and str(g[2]) == str(w[2]) \
				and (null if g[4] == null else int(g[4])) == (null if w[4] == null else int(w[4])) and is_equal_approx(float(lay.lines[i].y), float(w[3]))):
			ok = false
			bad = {"row": i, "got": [g[0], g[1], g[2], g[4], lay.lines[i].y], "want": w}
			break
	check(tag, ok, bad if bad != null else {"got": _texts(got), "want": _texts(want)})
	check(tag + ".height", is_equal_approx(float(lay.height), float(c.height)), [lay.height, c.height])


func _color_text(c: Color) -> String:
	return "rgba(%d,%d,%d,%s)" % [roundi(c.r8), roundi(c.g8), roundi(c.b8), XGrowthHelp.number(snappedf(c.a, 0.001))]


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var s := XState.new_game(2, 1, [8, 9, 10])
	XState.current = s
	var n := 0
	for one in data.ranks:
		s.actor_advance[XLiuying.ACTOR] = int(one.rank)
		for c in one.cards:
			var tag := "card.r%d.%d.%d" % [int(one.rank), int(c.id), n]
			_card(tag, XDB.rec("Skills", int(c.id)), c)
			# 备注：保留行＋APs 行与原版改写后的一致
			check(tag + ".note", XLiuyingHelp.view(XDB.rec("Skills", int(c.id))).note == str(c.note), [XLiuyingHelp.view(XDB.rec("Skills", int(c.id))).note, c.note])
		n += 1
	check("card.count", n == 5)
	# 数据库记录不被改：出卡只用拷贝
	var raw := XDB.rec("Skills", XLiuying.RANSHAO)
	s.actor_advance[XLiuying.ACTOR] = 3
	XHelpCard.content(raw)
	check("db_untouched", str(raw.note).contains("解锁：进阶2阶"))
	# 别的技能原样
	var other := XDB.rec("Skills", XLiuying.PIAN_SHI)
	check("other_same", is_same(XLiuyingHelp.view(other), other))
	s.actor_advance.erase(XLiuying.ACTOR)
	# 13 技能名颜色
	var bad := []
	for c in data.names:
		var got := _color_text(XQuality.list_color(XDB.rec("Skills", int(c.id))))
		if got != str(c.color):
			bad.append([c.id, got, c.color])
	check("name_color_%d" % data.names.size(), bad.is_empty() and data.names.size() >= 12, bad)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_liuying_help", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
