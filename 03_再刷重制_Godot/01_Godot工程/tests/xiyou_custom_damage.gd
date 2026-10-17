extends Node
## 真实冻结源 evalDamageFormula 的 48 个资源／阵亡／不死边界；不用预设胜负替代伤害。
class ProbeBattler extends XBattler:
	var params: Array = []
	var tp_max := 200.0
	func param(i: int) -> float:
		return float(params[i])
	func max_tp() -> float:
		return tp_max

var results := []

func _ready() -> void:
	var oracle = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/custom_damage_oracle.json"))
	check("frozen_oracle", oracle is Dictionary and oracle.cases.size() == 48)
	for c in oracle.cases:
		var a := ProbeBattler.new()
		var b := ProbeBattler.new()
		a.params = c.setup.subjectParams
		b.params = c.setup.targetParams
		a.tp_max = c.setup.maxTp
		b.tp_max = c.setup.maxTp
		b.hp = c.setup.resources[0]
		b.mp = c.setup.resources[1]
		b.tp = c.setup.resources[2]
		b.immortal = c.setup.immortal
		var skill := XDB.rec("Skills", int(c.setup.skill))
		check(c.id + ".source", str(skill.damage.formula).sha256_text() == c.observed.formulaSHA256)
		var value := XDamage.eval_formula(skill, a, b, [])
		check(c.id, value == float(c.observed.value) and [b.hp, b.mp, b.tp] == c.observed.resources
			and b.is_state_affected(1) == bool(c.observed.deathState), [value, b.hp, b.mp, b.tp, b.state_ids])
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)

func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", detail)
