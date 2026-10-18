extends Node
## 特殊角色说明卡验收：XHelpCard.content()（XCharacterHelp）与正式版 Sprite_ItemHelp.setItem 实际画出的行
## （generated/oracle/special_help_cards.json，探针 03_转换工具/mv_oracle/special_help_probe.cjs）逐行一致——
## 文字、字号、颜色、对齐、每行 y 与卡高。范围：渡鸦～哈基米（167～178）的图鉴技能与 10122～10299 全部技能、
## 专属装备，按图鉴预览态（未招募、初始等级、未学会、0 阶）。另核图鉴技能表与转换器导出的原文表。

const ORACLE := "res://modes/xiyou/generated/oracle/special_help_cards.json"
const POWER_PREFIX := "装备战力："

var results := []
var detail_left := 400


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})
	if not ok and detail_left > 0:
		detail_left -= 1
		print("FAIL ", name, " ", JSON.stringify(detail))


static func oracle_measure(t: String, s: int) -> float:
	return t.length() * s * 0.6


func _compare(cat: String, card: Dictionary) -> void:
	var table: String = {"skills": "Skills", "weapons": "Weapons", "armors": "Armors"}[cat]
	var name := "%s_%d_%s" % [cat, int(card.id), card.name]
	var obj := XDB.rec(table, int(card.id))
	var got := XHelpCard.content(obj, {"skills": "skill", "weapons": "weapon", "armors": "armor"}[cat])
	var want: Array = card.rows
	if not want.any(func(r): return str(r[0]).begins_with(POWER_PREFIX)):
		got = got.filter(func(r): return not str(r[0]).begins_with(POWER_PREFIX))
	var lay := XHelpCard.layout(got, 0, XHelpCard.width_for(obj), oracle_measure)
	_check(name + "_width", is_equal_approx(XHelpCard.width_for(obj), float(card.width)), [XHelpCard.width_for(obj), card.width])
	if got.size() != want.size():
		_check(name, false, {"rows": [got.size(), want.size()], "got": got.map(func(r): return r[0]), "want": want.map(func(r): return r[0])})
		return
	for i in range(want.size()):
		var g: Array = got[i]
		var w: Array = want[i]
		var g_align = null if g[4] == null else int(g[4])
		var w_align = null if w[4] == null else int(w[4])
		var row_ok: bool = str(g[0]) == str(w[0]) and int(g[1]) == int(w[1]) and str(g[2]) == str(w[2]) and g_align == w_align
		var y_ok := is_equal_approx(float(lay.lines[i].y), float(w[3]))
		if not (row_ok and y_ok):
			_check(name, false, {"row": i, "got": [g[0], g[1], g[2], g_align, lay.lines[i].y], "want": [w[0], w[1], w[2], w_align, w[3]]})
			return
	var h_ok: bool = is_equal_approx(float(lay.height), float(card.height)) if float(card.height) > 0 else want.is_empty()
	_check(name, h_ok, null if h_ok else {"height": [lay.height, card.height]})


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	_check("oracle_loaded", data is Dictionary and data.has("skills") and data.get("state") == "preview")
	var help := XCharacterHelp.data()
	_check("copies_exported", help.get("copies", {}).size() > 0 and help.get("dyn2Ids", []).size() > 0)
	XHelpCard.REAL_SELL_PRICE = false
	if data is Dictionary:
		for cat in ["skills", "weapons", "armors"]:
			var before := results.size()
			for card in data.get(cat, []):
				_compare(cat, card)
			var cat_results := results.slice(before)
			print("%s %d/%d" % [cat, cat_results.filter(func(r): return r.passed).size(), cat_results.size()])
	XHelpCard.REAL_SELL_PRICE = true
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
