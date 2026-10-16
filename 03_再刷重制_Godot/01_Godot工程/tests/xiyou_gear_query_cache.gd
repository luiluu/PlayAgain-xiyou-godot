extends Node
## 核查 dev.055：两个名字不同、备注/说明/能力完全相同的装备不能共享检索记录。
## 冻结 v0.28 的 CodexEquipmentQuery.record/matches 对 Armors 10/11 实测：[false,true]。
var results := []
func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))
func _ready() -> void:
	var a := XGear.template("armor", 10)
	var b := XGear.template("armor", 11)
	check("same_attributes_different_names", a.note == b.note and a.description == b.description and a.params == b.params and a.name != b.name)
	for reverse in [false, true]:
		XGearQuery._cache.clear()
		var items := [b, a] if reverse else [a, b]
		for item in items:
			XGearQuery.record(item)
		var f := XGearQuery.defaults()
		f.query = "学徒短靴"
		var got := [XGearQuery.matches(a, f), XGearQuery.matches(b, f)]
		check("independent_search_" + str(reverse), got == [false, true], got)
		f.query = "皮革裤衩子"
		got = [XGearQuery.matches(a, f), XGearQuery.matches(b, f)]
		check("independent_reverse_query_" + str(reverse), got == [true, false], got)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
