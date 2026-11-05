extends Node
## 小猫剑圣一族（备注含 <CodexCat:）说明卡：XHelpCard.content() 与正式版 characterHelpView→CodexCat.helpItem 实际画出的行
## （fixtures/cat_help_oracle.json，探针 mv_oracle/cat_help_probe.cjs）逐行一致，分「没有 178（预览）」「178 在、10 级」两种；
## 17 个：技能 10437～10450、物品 2899／2900、法宝 7999。文字、字号、颜色、对齐、行 y、卡高都比。

const ORACLE := "res://tests/fixtures/cat_help_oracle.json"
var total := 0
var passed := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail))


static func oracle_measure(t: String, s: int) -> float:
	return t.length() * s * 0.6


func _obj(card: Dictionary) -> Dictionary:
	return XDB.rec({"skills": "Skills", "items": "Items", "armors": "Armors"}[str(card.cat)], int(card.id))


func _compare(state: String, card: Dictionary) -> void:
	var tag := "%s_%s_%d_%s" % [state, card.cat, int(card.id), card.name]
	var obj := _obj(card)
	var got := XHelpCard.content(obj)
	var want: Array = card.rows
	var lay := XHelpCard.layout(got, 0, XHelpCard.note_width(obj), oracle_measure)
	if got.size() != want.size():
		check(tag, false, {"rows": [got.size(), want.size()], "got": got.map(func(r): return r[0]), "want": want.map(func(r): return r[0])})
		return
	for i in range(want.size()):
		var g: Array = got[i]
		var w: Array = want[i]
		var g_align = null if g[4] == null else int(g[4])
		var w_align = null if w[4] == null else int(w[4])
		var ok: bool = str(g[0]) == str(w[0]) and int(g[1]) == int(w[1]) and str(g[2]) == str(w[2]) and g_align == w_align and is_equal_approx(float(lay.lines[i].y), float(w[3]))
		if not ok:
			check(tag, false, {"row": i, "got": [g[0], g[1], g[2], g_align, lay.lines[i].y], "want": [w[0], w[1], w[2], w_align, w[3]]})
			return
	check(tag, is_equal_approx(float(lay.height), float(card.height)), [lay.height, card.height])


func _ready() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	check("source", ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	XHelpCard.REAL_SELL_PRICE = false
	var prior := XState.current
	var empty := XState.new()
	XState.current = empty
	for card in ref.states.preview:
		_compare("preview", card)
	var s10 := XState.new()
	s10.actor(XCat.ACTOR).change_level(10)
	XState.current = s10
	for card in ref.states.level10:
		_compare("level10", card)
	XState.current = prior
	XHelpCard.REAL_SELL_PRICE = true
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
