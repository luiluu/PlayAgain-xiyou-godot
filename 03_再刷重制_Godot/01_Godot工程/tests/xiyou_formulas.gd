extends Node
## 转换器翻译的伤害公式（formulaGd）都能被 Godot Expression 解析：解析失败时 XDamage.eval_formula 算 0。
## 原来技能 1065「霸道之刃」的 JS 一元加号（750 +  + a.atk * 38.5）翻不成可解析的表达式，战斗里算 0；
## 转换器去掉一元加号后应得 750 + a.atk * 38.5（正式版 eval 同值）。未翻译（formulaGd 为 null）的另记数量，不在此判。
class Stub:
	var atk := 100.0
	var mat := 0.0
	var hp := 100.0
	var mhp := 1000.0

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
	# 三元式 c ? x : y 译成 [y, x][int(bool(c))]（进度审查 25%）：按条件取一支，未取的一支不参与运算
	for row in [[75, 100.0, 1800.0 + 100.0 * 14], [75, 900.0, 900.0 + 100.0 * 7], [10020, 100.0, 1000.0 * 1000000], [10020, 900.0, 100.0 * 0.2]]:
		var tb := Stub.new()
		tb.hp = row[1]
		var tsk: Dictionary = XDB.rec("Skills", row[0])
		var te := Expression.new()
		var tok: bool = tsk.damage.get("formulaGd") is String and te.parse(str(tsk.damage.formulaGd), ["a", "b", "v"]) == OK
		var tv = te.execute([Stub.new(), tb, []], null, false) if tok else null
		check("ternary_%d_hp%d" % [row[0], int(row[1])], tok and tv != null and is_equal_approx(float(tv), row[2]), [tsk.damage.get("formulaGd"), tv])
	# 条件为数字时照 JS 真值（非零为真），不能乘成倍数；未取的一支为 NaN 也不影响结果
	var ne := Expression.new()
	ne.parse("[(2.0), (sqrt(-1.0))][int(bool(0))]", [])
	var nv = ne.execute([], null, false)
	var me := Expression.new()
	me.parse("[(2.0), (1.0)][int(bool(5))]", [])
	check("ternary_numeric_and_nan_branch", float(nv) == 2.0 and float(me.execute([], null, false)) == 1.0, [nv])
	print("公式 %d 条可解析，未翻译 %d 条" % [total, untranslated])
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
