extends Node
## 转换器翻译的伤害公式（formulaGd）都能被 Godot Expression 解析：解析失败时 XDamage.eval_formula 算 0。
## 原来技能 1065「霸道之刃」的 JS 一元加号（750 +  + a.atk * 38.5）翻不成可解析的表达式，战斗里算 0；
## 转换器去掉一元加号后应得 750 + a.atk * 38.5（正式版 eval 同值）。未翻译（formulaGd 为 null）的另记数量，不在此判。
class Stub:
	var atk := 100.0
	var mat := 0.0

var results := []
func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))
func _ready() -> void:
	var bad := []
	var total := 0
	var untranslated := 0
	for t in ["Skills", "Items"]:
		for r in XDB.table(t):
			if r == null:
				continue
			var src = r.damage.get("formulaGd")
			if src == null:
				untranslated += 1
				continue
			total += 1
			var e := Expression.new()
			if e.parse(str(src), ["a", "b", "v"]) != OK:
				bad.append([t, int(r.id), str(r.damage.formula), str(src)])
	check("all_translated_parse", bad.is_empty() and total > 10000, [total, bad.slice(0, 10)])
	var sk: Dictionary = XDB.rec("Skills", 1065)
	var e := Expression.new()
	var ok: bool = sk.damage.get("formulaGd") is String and e.parse(str(sk.damage.formulaGd), ["a", "b", "v"]) == OK
	var value = e.execute([Stub.new(), Stub.new(), []], null, false) if ok else null
	check("skill_1065_unary_plus", ok and is_equal_approx(float(value), 750.0 + 100.0 * 38.5), [sk.damage.get("formulaGd"), value])
	print("公式 %d 条可解析，未翻译 %d 条" % [total, untranslated])
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
