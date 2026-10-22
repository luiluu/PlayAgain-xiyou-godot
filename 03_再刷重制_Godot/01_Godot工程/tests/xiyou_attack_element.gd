extends Node
## 普通攻击的攻击属性（XActor.attack_elements／XDamage.action_elements）：与 mv_oracle attack_element_probe 的参照
## （generated/oracle/attack_elements.json）逐例比对。角色没装武器时另加空手物理，154 夏娜（火）、158 炮姐（雷）空手是「本属性＋物理」；
## 无特性 31 的敌人普攻无属性。普攻公式固定 1000000、去浮动，比 makeDamageValue。

const ORACLE := "res://modes/xiyou/generated/oracle/attack_elements.json"
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ints(xs: Array) -> Array:
	return xs.map(func(v): return int(v))


func _enemy(id: int, level: int) -> XEnemy:
	var b := XEnemy.new().setup(id, 3, 100.0)
	b.enemy_level = level
	b.state_ids.clear()
	b.refresh_passive()
	b.recover_all()
	return b


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if check("oracle_loaded", data is Dictionary and data.get("cases", []).size() >= 13, ORACLE):
		var item := XDB.rec("Skills", 1).duplicate(true)
		item.damage.formula = "1000000"
		item.damage.formulaGd = "1000000"
		item.damage.formulaProgram = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/formula_effect_programs.json"))["runtime.constant1000000"].program
		item.damage.variance = 0
		for c in data.cases:
			var o: Dictionary = c.observed
			if c.setup.has("enemy"):
				var e := _enemy(int(c.setup.enemy), 1)
				check(c.id + "_attack", _ints(e.attack_elements()) == _ints(o.attackElements), [e.attack_elements(), o.attackElements])
				check(c.id + "_item", XDamage.action_elements(item, e) == _ints(o.itemElements), [XDamage.action_elements(item, e), o.itemElements])
				continue
			var st := XState.new_game(3, 1, [])
			var a := st.actor(int(c.setup.actor))
			a.change_level(int(o.level))
			a.skill_ids.clear()
			a.state_ids.clear()
			for i in range(a.equips.size()):
				a.equips[i] = XActor.make_equip("weapon", int(c.setup.weapon)) if i == 0 and int(c.setup.weapon) > 0 else null
			a.refresh_passive()
			a.recover_all()
			var es := XDamage.action_elements(item, a)
			check(c.id + "_attack", _ints(a.attack_elements()) == _ints(o.attackElements).reduce(func(s, v): return s if s.has(v) else s + [v], []), [a.attack_elements(), o.attackElements])
			check(c.id + "_item", es == _ints(o.itemElements), [es, o.itemElements])
			check(c.id + "_no_weapon", a.first_weapon().is_empty() == bool(o.hasNoWeapons))
			for d in o.damage:
				var b := _enemy(int(d.enemy), int(d.level))
				var got: float = XDamage.calculate(item, a, b, {"variance": false, "critical": false}).value
				check("%s_vs%d" % [c.id, int(d.enemy)], got == float(d.value), [got, d.value])
		# 参照要真的覆盖「空手另加物理」与「有武器不加」两边，以及无属性敌人
		check("bare_hand_covered", data.cases.any(func(c): return c.id == "a154-naked" and c.observed.itemElements == [2.0, 1.0]))
		check("weapon_covered", data.cases.any(func(c): return c.id == "a158-noElement" and c.observed.itemElements == [5.0]))
		check("enemy_empty_covered", data.cases.any(func(c): return c.id.begins_with("e") and c.observed.itemElements.is_empty()))
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
