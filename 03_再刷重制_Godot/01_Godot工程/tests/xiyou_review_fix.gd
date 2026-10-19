extends Node
## 2026-10-18 核查第二批（沙僧）修复的回归：与 mv_oracle/review_fix_probe.cjs 逐例比（generated/oracle/review_fix.json）。
## - 回春：治疗被动 passiveHEUP 在浮动与取整前相乘（HP／MP 回复、三个境界、无道法与敌人施法基线）。
##   实战 Game_Action.apply 原版还会在 executeDamage 再乘一次（dsPassiveSkill），重制只乘一次（O-052）：heal.apply.r3 比预览值。
## - 可败战斗全灭：真实 XBattleScene 结束链，canLose 时阵亡出战者复活到 1 HP；不可败时不复活。
##   参照里的部分阵亡（lose.770.partial）不会进全灭分支，原版也不复活，只核参照本身。
class QuickBattle extends XBattleScene:
	func _say(_text: String, _seconds: float) -> void:
		await get_tree().process_frame

const ORACLE := "res://modes/xiyou/generated/oracle/review_fix.json"
var results := []
var s: XState


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _fresh() -> void:
	s = XState.new_game(3, 1, [8, 9, 10])
	XState._become_current(s)


func _clean(a: XActor) -> void:
	a.equips.fill(null)
	a.skill_ids.clear()
	a.state_ids.clear()
	a.refresh_passive()
	a.recover_all()


static func _heal(type: int) -> Dictionary:
	return {"id": 0, "name": "核查固定恢复", "stypeId": 1, "hitType": 0, "scope": 7, "note": "", "meta": {}, "effects": [],
		"damage": {"type": type, "formula": "100", "formulaGd": "100", "formulaProgram": JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/formula_effect_programs.json"))["runtime.constant100"].program, "elementId": 0, "variance": 0, "critical": false}}


func _huichun(a: XActor, realm: int) -> void:
	a.zhenqi = XZhenqi.default_data()
	a.zhenqi.realm = realm
	a.zhenqi.daofa.huichun = 1
	a.learn_skill(XZhenqi.skill_key("daofa:huichun"))
	XZhenqi.refresh_rewards(a)


func _heal_case(id: String, o: Dictionary):
	_fresh()
	var a := s.actor(1)
	var b := s.actor(8)
	_clean(a)
	_clean(b)
	if id == "heal.enemy":
		var e := XEnemy.new().setup(int(XDB.rec("Troops", 770).members[0].enemyId), s.difficulty, 100.0)
		return {"value": XDamage.calculate(_heal(3), e, b, {"variance": false}).value}
	if id == "heal.none":
		return {"value": XDamage.calculate(_heal(3), a, b, {"variance": false}).value}
	_huichun(a, int(o.realm))
	var passive := a.passive_values("passiveHEUP").map(func(v): return str(v))
	if id == "heal.apply.r3":
		var skill := XDB.rec("Skills", int(o.skill))
		var logic := XBattleLogic.new()
		logic.setup(770, s)
		b.hp = 1.0
		var preview: float = XDamage.calculate(skill, a, b, {"variance": false}).value
		var r := logic.apply(a, skill, b)
		return {"preview": preview, "hp": r.hp, "passive": passive}
	return {"passive": passive, "value": XDamage.calculate(_heal(int(o.type)), a, b, {"variance": false}).value}


func _lose(o: Dictionary) -> Dictionary:
	_fresh()
	for x in s.battle_members():
		x.add_state(1)
		x.hp = 0.0
	var scene := QuickBattle.new()
	scene.setup(int(o.troop), false, bool(o.canLose), XDB.map(4))
	get_tree().root.add_child(scene)
	var result: int = await scene.finished
	var out := {"canLose": scene.can_lose, "hp": s.battle_members().map(func(x): return x.hp),
		"mhp": s.battle_members().map(func(x): return x.mhp), "dead": s.battle_members().map(func(x): return x.is_dead()), "result": result}
	scene.bgm.stop()
	scene.se.stop()
	scene.queue_free()
	await get_tree().create_timer(0.5, true, false, true).timeout
	return out


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_review_fix"
	XConfig.path_override = XSave.dir().path_join("options.json")
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if check("oracle_loaded", data is Dictionary, ORACLE):
		for c in data.cases:
			if not c.errors.is_empty():
				check("oracle_" + c.id, false, c.errors)
				continue
			var want: Dictionary = c.observed
			if c.id.begins_with("heal."):
				var got: Dictionary = _heal_case(c.id, c.setup)
				if c.id == "heal.apply.r3":
					# O-052：原版实战再乘一次（hpDamage ≈ 预览 ×(1+p)）；重制实战回复＝预览值
					var p := float(got.passive[0]) * 0.01
					check(c.id + ".preview", got.preview == float(want.preview), [got, want])
					check(c.id + ".mv_double", absf(float(want.hpDamage) - float(want.preview) * (1.0 + p)) <= 1.0, want)
					check(c.id + ".single", got.hp == got.preview, got)
				else:
					check(c.id, JSON.stringify(got) == JSON.stringify(want) or (got.value == float(want.value) and got.get("passive", []) == want.get("passive", [])), [got, want])
			elif c.id == "lose.770.partial":
				check(c.id + ".mv_no_revive", want.dead == [true, false, true, false] and want.hp[0] == 0, want)
			elif c.id.begins_with("lose."):
				var got := await _lose(c.setup)
				check(c.id, got.result == 2 and got.canLose == want.canLose and got.hp == want.hp.map(func(v): return float(v)) and got.dead == want.dead, [got, want])
	for sp in XSound._players:
		if is_instance_valid(sp):
			sp.stop()
	await get_tree().create_timer(0.5, true, false, true).timeout
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_review_fix", "passed": results.size() - failed.size(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit(0 if failed.is_empty() else 1)
