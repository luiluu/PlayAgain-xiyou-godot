extends Node
## 贝吉特形态图兜底（XCostumes.vegetto_form，installVegettoFormRuntime）：图被还原成本体或留空时，按剩下的最高形态（2774＞2773＞2772＞2771）补图；
## 图名已不是数据库原图的保留；没有形态时退回原图。原版 26 行逐条对照（无随机、无探针）。
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _run() -> void:
	var s := XState.new_game_blank()
	var keep := XState.current
	XState.current = s
	var a := s.actor(164)
	var original := str(XDB.rec("Actors", 164).battlerName)
	check("original_name", original == "逼王", original)
	for c in [[[], "", original], [[], original, original], [[2772], original, "cjbjt2"], [[2771, 2773], original, "cjbjt3"],
			[[2774, 2771], "", "clbjt"], [[2771], "", "bjtc1"], [[2773], "cjbjt2", "cjbjt2"], [[2772], "Raven_Normal_SV", "Raven_Normal_SV"]]:
		a.state_ids.assign(c[0])
		a.set_looks({"battlerName": c[1]})
		var got := XCostumes.battler_name(s, a)
		check("form_%s_%s" % [str(c[0]), str(c[1])], got == str(c[2]), [got, c[2]])
		check("menu_%s_%s" % [str(c[0]), str(c[1])], XCostumes.battler_name(s, a, false) == str(c[2]), XCostumes.battler_name(s, a, false))
	XState.current = keep
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
