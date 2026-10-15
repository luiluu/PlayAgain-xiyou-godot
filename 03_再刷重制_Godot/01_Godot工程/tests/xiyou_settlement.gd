extends Node
## 与正式版逐阶段比较 Confirm → 固定减伤 → React；覆盖两种目标减伤叠加与攻击方加成。
func _ready() -> void:
	var ref = XDB.load_json("oracle/settlement.json")
	var passed := 0
	var total := 1
	if ref is Dictionary and ref.get("cases", []).size() == 8:
		passed += 1
		for c in ref.cases:
			var st := XState.new_game(3, 1, [])
			var a := st.actor(1)
			a.equips.fill(null)
			a.skill_ids.clear()
			a.state_ids.clear()
			for id in c.actorStates:
				a.add_state(int(id))
			a.refresh_passive()
			var b := XEnemy.new().setup(int(c.enemy), 3, 100.0)
			b.setup_level(1, 0.99)
			b.state_ids.clear()
			for id in c.enemyStates:
				b.add_state(int(id))
			b.refresh_passive()
			var item := XDB.rec("Skills", 1).duplicate(true)
			item.damage.formula = "1000000"
			item.damage.formulaGd = "1000000"
			item.damage.elementId = 1
			var res := XDamage.calculate(item, a, b, {"variance": false, "critical": false})
			var confirmed := XDamage.apply_fixed_mitigation(XDamage.apply_state_effects(res.value, item, a, b, [], "confirm"), res)
			var got := XDamage.finish(res, item, a, b)
			total += 1
			if got == float(c.final) and confirmed == float(c.confirmed) and res.value == float(c.gross) and b.passive_cache().harmRe.get(1) == float(c.flat):
				passed += 1
			else:
				print("FAIL settlement ", c.actorStates, " ", c.enemyStates, " got=", [res.value, confirmed, got], " want=", [c.gross, c.confirmed, c.final])
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
