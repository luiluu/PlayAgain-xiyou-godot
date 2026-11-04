extends Node
## 多属性技能结算与属性反弹：与 mv_oracle multi_element_probe（generated/oracle/multi_element.json）逐例比。
## 16 个带 <Multi-Element Rule> 的技能：标签本身无效（rule.* 改五种规则数值不变），installDamageElementRuntime 取各属性候选里最有利的一个；
## 每个属性轮流当最优、吸收、免疫、全低抗、单属性增幅、原公式对真实敌人都比 makeDamageValue。
## 反弹：防具 4998 的属性反弹（itemMrf）不看命中类型，含属性 8 的行动必反弹，走 _invoke 的反弹支。

const ORACLE := "res://modes/xiyou/generated/oracle/multi_element.json"
const WATCH_RULE_SKILLS := ["rule.7006", "rule.9956", "rule.10007"]
var passed := 0
var total := 0
var _program := {}


class RatedEnemy extends XEnemy:
	var table = null
	func element_rate(e: int) -> float:
		if table == null:
			return super(e)
		return float(table.get(str(e), 1.0))


class FixedLogic extends XBattleLogic:
	func _float(reason: String) -> float:
		return 0.5 if reason in ["reflection", "counter"] else super(reason)


func check(label: String, ok: bool, detail = null) -> bool:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", label, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


## 用新局默认等级（参照 observed.actor 记了等级与攻防，比对前先核）
func _actor(st: XState, id: int, states := []) -> XActor:
	var a: XActor = st.actor(id)
	a.skill_ids.clear()
	a.state_ids.clear()
	for i in range(a.equips.size()):
		a.equips[i] = null
	a.param_mark_dirty()
	a.refresh_passive()
	a.recover_all()
	for s in states:  # recover_all 会清状态，放在它后面
		a.state_ids.append(int(s))
		a.state_turns[int(s)] = 1
	a.param_mark_dirty()
	a.refresh_passive()
	return a


func _enemy(id: int, level: int, table = null) -> XEnemy:
	var b := RatedEnemy.new()
	b.table = table
	b.setup(id, 2, 100.0)
	b.enemy_level = level
	b.state_ids.clear()
	b.param_mark_dirty()
	b.refresh_passive()
	b.recover_all()
	return b


func _value(id: int, a: XBattler, b: XBattler, fixed: bool) -> float:
	var item := XDB.rec("Skills", id).duplicate(true)
	item.damage.variance = 0
	item.damage.critical = false
	var options := {"variance": false, "critical": false, "vars": XState.current.variable_array()}
	if fixed:  # 参照把公式改成 1000：物理／魔法权重也按新公式算（没有攻防项，各 0.5）
		item.damage.formula = "1000"
		item.damage.formulaGd = "1000"
		item.damage.formulaProgram = _constant_program()
	return XDamage.finish(XDamage.calculate(item, a, b, options), item, a, b)


## tests/fixtures 的常量公式程序，把常量改成 1000
func _constant_program() -> Dictionary:
	if _program.is_empty():
		_program = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/formula_effect_programs.json"))["runtime.constant1000000"].program
		_program.steps[0].value.value = 1000.0
	return _program


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if not check("oracle_loaded", data is Dictionary and data.get("cases", []).size() >= 228, ORACLE):
		_finish()
		return
	check("source", data.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	var default_enemy := int(XDB.rec("Troops", 1).members[0].enemyId)
	for c in data.cases:
		if not check(c.id + ".native_ok", c.errors.is_empty(), c.errors):
			continue
		var o: Dictionary = c.observed
		var id := str(c.id)
		var st := XState.new_game(int(data.difficulty), 1, [])
		XState.current = st
		if o.has("actor"):
			var who := _actor(st, 1, [c.setup.state] if c.setup.has("state") else [])
			check(id + ".actor", who.level == int(o.actor.level) and who.atk == float(o.actor.atk) and who.mat == float(o.actor.mat), [who.level, who.atk, who.mat, o.actor])
		if id.begins_with("elements."):
			var a := _actor(st, 1)
			var got := XDamage.action_elements(XDB.rec("Skills", int(c.setup.skill)), a)
			check(id, got == _ints(o.elements), [got, o.elements])
		elif id.begins_with("multi."):
			var got := _value(int(c.setup.skill), _actor(st, 1), _enemy(default_enemy, int(o.enemyLevel), c.setup.table), true)
			check(id, got == float(o.value), [got, o.value])
		elif id.begins_with("amp."):
			var a := _actor(st, 1, [c.setup.state])
			var got := _value(int(c.setup.skill), a, _enemy(default_enemy, int(o.enemyLevel), {}), true)
			check(id, got == float(o.value), [got, o.value])
		elif id.begins_with("native."):
			var a := _actor(st, 1)
			var got := _value(int(c.setup.skill), a, _enemy(int(c.setup.enemy), int(o.enemyLevel)), false)
			check(id, got == float(o.value), [got, o.value])
		elif id.begins_with("rule."):
			var first = o.values["0"]
			check(id + ".no_effect", o.values.values().all(func(v): return v == first), o.values)
		elif id == "reflect.item_data":
			var yep: Dictionary = XDB.rec("Armors", 4998).get("yep", {})
			check(id, yep.get("elementReflect", {}) == o.elementReflect, [yep, o.elementReflect])
		elif id.begins_with("reflect."):
			_reflect_case(id, c, o, st, int(data.wearer))
	# 参照要真的覆盖：规则改了不变、最优能换成每个属性、含属性 8 的物理／必中都反弹
	check("rule_cases", WATCH_RULE_SKILLS.all(func(r): return data.cases.any(func(c): return c.id == r)))
	check("best_covered", data.cases.filter(func(c): return str(c.id).begins_with("multi.7006.best")).size() == 3)
	_finish()


func _reflect_case(id: String, c: Dictionary, o: Dictionary, st: XState, wearer: int) -> void:
	var a := _actor(st, wearer)
	if id != "reflect.unworn":
		var slots := a.equip_slots()
		var g := XGear.create("armor", 4998, st)
		a.equips[slots.find(int(XDB.rec("Armors", 4998).etypeId))] = g
		a.param_mark_dirty()
		a.refresh_passive()
		check(id + ".worn", a.equip_list().any(func(e): return int(e.get("id", 0)) == 4998 or int(e.get("baseItemId", 0)) == 4998), a.equip_list().size())
	var logic := FixedLogic.new()
	logic.elite_roll = 100.0
	logic.setup(1, st)
	var foe: XEnemy = logic.enemies[0]
	foe.state_ids.clear()
	foe.refresh_passive()
	var skill := XDB.rec("Skills", int(c.setup.skill)).duplicate(true)
	var rate := XDamage.element_reflect_rate(skill, foe, a)
	check(id + ".rate", rate == float(o.itemMrf), [rate, o.itemMrf])
	var rs: Array = logic._invoke(foe, skill, a)
	var reflected: bool = rs.size() > 0 and str(rs[0].get("type", "")) == "reflect"
	check(id + ".branch", reflected == (str(o.branch) == "invokeMagicReflection"), [rs.size(), o.branch])


func _ints(xs: Array) -> Array:
	return xs.map(func(v): return int(v))


func _finish() -> void:
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
