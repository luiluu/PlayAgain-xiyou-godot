extends Node
## dev.064 全局 traits_pi 核查：冻结版完整引擎的角色／敌人读数，覆盖非宝珠特性叠加与承伤下限。
## 参照采集脚本与完整来源身份在 04_验证/本地结果/20261017_Codex合并与核查/。

var results := []

class StackActor extends XActor:
	var measured_traits := []
	func all_traits() -> Array:
		return measured_traits

class StackEnemy extends XEnemy:
	var measured_traits := []
	func all_traits() -> Array:
		return measured_traits

func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))

func _ready() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/trait_stack_oracle.json"))
	check("frozen_reference", d is Dictionary and d.get("releaseVersion") == "v0.28" and d.get("stateAddedType") == true and d.get("rows", []).size() == 106)
	check("state_added_type", str(XDB.plugin("CP_StateFloor").get("State Added Type", "")) == "true")
	for i in range(d.rows.size()):
		var row: Dictionary = d.rows[i]
		var b: XBattler = StackActor.new() if row.kind == "actor" else StackEnemy.new()
		if b is XActor:
			b.actor_id = 1
			b.class_id = int(XDB.rec("Actors", 1).classId)
		else:
			b.enemy_id = 1
		b.set("measured_traits", row.values.map(func(v): return {"code": row.code, "dataId": row.id, "value": v}))
		var code := int(row.code)
		var id := int(row.id)
		var pi := b.traits_pi(code, id)
		check("pi_%d_%s" % [i, row.kind], is_equal_approx(pi, float(row.pi)), [row, pi])
		var rate := pi
		match code:
			11: rate = b.element_rate(id)
			21:
				# 正式 Vitsuno 在 paramRate 乘难度，Godot 在 param_base 乘；比较等价的总倍率。
				rate = b.param_rate(id) * float(row.get("difficultyRate", 1.0))
			23: rate = b.sparam(id)
		check("rate_%d_%s" % [i, row.kind], is_equal_approx(rate, float(row.rate)), [row, rate])
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
