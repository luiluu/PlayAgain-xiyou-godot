extends Node
## 智能战斗AI（XSmartAI）对照正式版 Codex_SmartBattleAI：generated/oracle/smart_ai.json 由 mv_oracle/smart_ai_probe.cjs 生成
## （普通难度、出战 1/8/9/10、10 级、开局被动与开战状态、药 1/2/137；切片敌群 × 满状态/队友低血/队友阵亡/没蓝/敌人残血）。
## 比较：每个角色选中的技能/药与目标、前 6 名候选的分数，以及 safeDamage 估算；另比 YEP 行动序列段数（转换器 yepEffects）。

var results := []
var mismatches := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		mismatches.append({"name": name, "detail": detail})


func close(a: float, b: float, rel := 1e-4) -> bool:
	return absf(a - b) <= maxf(1.0, absf(b) * rel)


func setup(ref: Dictionary, troop: int, scene: String) -> XBattleLogic:
	XEnemy.force_roll = 100.0
	var party: Array = ref.party
	var s := XState.new_game(int(ref.difficulty), int(party[0]), party.slice(1))
	s.items = {}
	for k in ref.items:
		s.items[int(k)] = int(ref.items[k])
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	logic.turn = 1
	for a in logic.actors:
		for sk in [6168, 5980, 5548] + ([2571, 2786] if int(a.data().id) in [1, 2, 3, 4, 5, 6, 7, 52] else []):
			a.learn_skill(sk)
		a.change_level(int(ref.level))
		a.refresh_passive()
		a.recover_all()
		for st in [995, 1691, 1631]:
			a.add_state(st)
		a.refresh_passive()
		a.tp = 0.0  # 探针没有经过开战 initTp
	match scene:
		"ally_low":
			var a := s.actor(9)
			a.hp = maxf(1.0, floorf(a.mhp * 0.2))
		"ally_dead":
			s.actor(9).add_state(1)
		"no_mp":
			for a in logic.actors:
				a.mp = 0.0
		"foes_low":
			for e in logic.enemies:
				e.hp = maxf(1.0, floorf(e.mhp * 0.1))
	return logic


func target_index(logic: XBattleLogic, t) -> int:
	if t == null:
		return -1
	var i := logic.enemies.find(t)
	return i if i >= 0 else logic.actors.find(t)


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string("res://modes/xiyou/generated/oracle/smart_ai.json"))
	if not ref is Dictionary:
		check("oracle_present", false, "先运行 mv_oracle/smart_ai_probe.cjs")
		return finish()
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(XDB.BASE + "manifest.json"))
	check("source_identity", ref.sourceIdentity.get("releaseVersion") == manifest.releaseVersion
		and ref.sourceIdentity.get("runtimeInputs") == manifest.runtimeInputs, [ref.sourceIdentity.get("releaseVersion"), manifest.releaseVersion])
	for row in ref.sequence:
		check("seq.%d" % int(row.skill), int(XDB.rec("Skills", int(row.skill)).get("yepEffects", 0)) == int(row.hits), [row.skill, row.hits])
	for row in ref.damage:
		var logic := setup(ref, int(row.troop), "full")
		var a: XActor = logic.state.actor(int(row.actor))
		var ai := XSmartAI.new(logic, a)
		var v := ai.safe_damage(a, logic.enemies[int(row.target)], XDB.rec("Skills", int(row.skill)))
		check("safe.t%d.a%d.s%d.e%d" % [int(row.troop), int(row.actor), int(row.skill), int(row.target)], close(v, float(row.safe)), {"godot": v, "mv": row.safe})
		var e: XBattler = logic.enemies[int(row.target)]
		var cri := clampf(a.cri * (1.0 - e.cev), 0.0, 1.0) if bool(XDB.rec("Skills", int(row.skill)).damage.critical) else 0.0
		var sk := XDB.rec("Skills", int(row.skill))
		check("hit.t%d.a%d.s%d.e%d" % [int(row.troop), int(row.actor), int(row.skill), int(row.target)],
			absf(logic.item_hit(a, sk, e) - float(row.hit)) < 1e-4 and absf(logic.item_eva(a, sk, e) - float(row.eva)) < 1e-4,
			{"godot": [logic.item_hit(a, sk, e), logic.item_eva(a, sk, e)], "mv": [row.hit, row.eva]})
		check("cri.t%d.a%d.s%d.e%d" % [int(row.troop), int(row.actor), int(row.skill), int(row.target)], absf(cri - float(row.cri)) < 1e-4, {"godot": cri, "mv": row.cri, "a.cri": a.cri, "e.cev": e.cev})
	for c in ref.cases:
		var tag: String = "case.t%d.%s.a%d" % [int(c.troop), c.scene, int(c.actor)]
		if c.get("skipped", false):
			continue
		var logic := setup(ref, int(c.troop), c.scene)
		var a: XActor = logic.state.actor(int(c.actor))
		var r := XSmartAI.choose(logic, a)
		var mine = {"id": int(r.skill.id), "item": XSmartAI.is_item(r.skill), "target": target_index(logic, r.target)} if r.has("skill") else null
		var theirs = {"id": int(c.chosen.id), "item": bool(c.chosen.item), "target": int(c.chosen.target)} if c.chosen else null
		check(tag + ".choice", mine == theirs, {"godot": mine, "mv": theirs, "godot_rank": r.get("candidates", []).map(func(x): return [x.id, x.item, x.score]), "mv_rank": c.candidates})
		for cand in c.candidates:
			var m = r.candidates.filter(func(x): return x.id == int(cand.id) and x.item == bool(cand.item))
			check(tag + ".score.%s%d" % ["i" if cand.item else "s", int(cand.id)], not m.is_empty() and close(float(m[0].score), float(cand.score), 2e-3),
				{"godot": m[0].score if not m.is_empty() else null, "mv": cand.score})
	routing(ref)
	var edge_logic := setup(ref, int(ref.cases[0].troop), "full")
	var edge_actor := edge_logic.state.actor(1)
	var edge_ai := XSmartAI.new(edge_logic, edge_actor)
	for row in ref.get("edgeDamage", []):
		var rec := XDB.rec("Skills", 160).duplicate(true)
		rec.damage.type = int(row.type)
		rec.damage.formula = row.formula
		rec.damage.formulaGd = "a.atk * randf()" if int(row.type) == 1 else "a.mat * 2"
		seed(20261014)
		var first := randf()
		seed(20261014)
		var value := edge_ai.safe_damage(edge_actor, edge_logic.enemies[0], rec)
		check("edge_damage_%d" % int(row.type), close(value, float(row.value)), [value, row.value])
		check("preview_preserves_rng_%d" % int(row.type), randf() == first)
	finish()


## 自动战斗的分派（auto_battle_action）与设置项
func routing(ref: Dictionary) -> void:
	XSave.dir_override = "user://test_xiyou_smart_ai"
	XConfig.path_override = XSave.dir().path_join("options.json")
	check("smart_default_on", XConfig.smart_ai())
	var logic := setup(ref, 2, "full")
	var a: XActor = logic.state.actor(1)
	check("auto_uses_smart", int(logic.auto_battle_action(a)[0].id) == 160)
	XConfig.set_smart_ai(false)
	check("auto_off_attacks", int(logic.auto_battle_action(a)[0].id) == XBattleLogic.ATTACK_SKILL)
	XConfig.set_smart_ai(true)
	logic.state.hang_up["ActSkill"] = {a.display_name() + "001": XBattleLogic.GUARD_SKILL}
	check("schedule_first", int(logic.auto_battle_action(a)[0].id) == XBattleLogic.GUARD_SKILL)
	var opt := XOptionsScene.new()
	add_child(opt)
	var i := opt.symbols().find("codexSmartAI")
	check("option_row", i >= 0 and opt.status_text(i) == "ON")
	opt.index = i
	opt.ok()
	check("option_toggle", not XConfig.smart_ai() and opt.status_text(i) == "OFF")
	opt._side(true)
	check("option_right_on", XConfig.smart_ai())
	opt.queue_free()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	for m in mismatches.slice(0, 40):
		print("MISMATCH ", m.name, " ", JSON.stringify(m.detail).left(700))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
