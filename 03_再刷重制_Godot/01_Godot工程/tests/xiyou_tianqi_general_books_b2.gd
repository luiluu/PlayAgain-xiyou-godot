extends Node
## T445 通用书第二批专项。运行时检查主动、被动、CE 精通、秘籍总账及西游档隔离。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
var passed := 0
var total := 0


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", label, " ", JSON.stringify(detail))


func _run() -> void:
	var kit := Kit.new("xiyou_tianqi_general_books_b2")
	var s := Kit.new_game("zhengdao")
	var actor := s.actor(s.party[0])
	actor.change_level_mv(81)
	var bow := XDB.rec("Skills", 115)
	_check("A1_formula_and_tp", int(bow.tpCost) == 10 and bow.damage.formulaProgram.module == XTianqiGeneralBooks.MODULE)
	var random_shot := XDB.rec("Skills", 118)
	_check("A2_two_targets", int(random_shot.scope) == 4 and int(random_shot.repeats) == 1 and int(random_shot.tpCost) == 15)
	var backstab := XTianqiGeneralBooks.spec(124)
	_check("A3_single_burst", int(backstab.damage.coef) == 3 and int(backstab.cooldown) == 3)
	var charge := XDB.rec("Skills", 449)
	_check("A4_control", int(charge.tpCost) == 10 and charge.effects.any(func(e): return int(e.code) == 21 and int(e.dataId) != 0))
	for case in [[125, "B1", 2, 5], [148, "B2", 1, 8], [282, "B3", 3, 10], [642, "B4", 2, 15]]:
		var sp := XTianqiGeneralBooks.spec(case[0])
		var sk := XDB.rec("Skills", case[0])
		_check(case[1], sp.template == case[1] and int(sp.damage.coef) == case[2]
			and int(str(sk.meta["MP Cost"]).strip_edges().trim_suffix("%")) == case[3] and int(sk.yepEffects) == 1)
	_check("B3_old_cast_removed", XDB.rec("Skills", 282).effects.is_empty())

	for case in [[488, "CodexParamRate", "0:8"], [2471, "passiveELUP01", "10%"],
			[2472, "passiveELUP02", "10%"], [2480, "passiveHarmRi", "8"], [2480, "passiveCrHarmRi", "12"],
			[2666, "SkillTypesDvupA", "10%"], [5189, "SkillPass0457", "8%"],
			[5190, "SkillPass0457", "12%"], [5191, "SkillPass0457", "15%"], [5193, "SkillPass0457", "15%"],
			[3687, "SkillPass3688", "12%"]]:
		var meta: Dictionary = XDB.rec("Skills", case[0]).meta
		_check(str(case[0]) + "_" + case[1], str(meta.get(case[1], "")).strip_edges() == case[2])
	_check("D2_no_flat_stat", not XDB.rec("Skills", 3687).meta.has("passivePBST2"))
	_check("no_extra_actions", not XDB.rec("Skills", 2821).meta.has("StartPushState1037")
		and not XDB.rec("Skills", 4746).meta.has("passiveAPLUS"))
	_check("healing_wording", str(XDB.rec("States", 1011).note).contains("受到的治疗效果 −20%"))

	for sid in [2471, 2480, 2822, 6139, 6308, 6328, 6530]:
		actor.learn_skill(sid)
	actor.param_mark_dirty()
	actor.refresh_passive()
	XTianqiLedger.violations.clear()
	var logic := XBattleLogic.new()
	logic.setup(4, s)
	var enemy: XEnemy = logic.enemies[0]
	var out := XTianqiLedger.live_confirm_add(actor, enemy)
	_check("formal_slots_keep_trigger_book", XTianqiSecrets.used_slots(actor) == 4
		and is_equal_approx(float(out.books.get("#2822", 0)), 0.15)
		and is_equal_approx(float(out.books.get("#6139", 0)), 0.10), out)
	var hit := XDamage.calculate(XDB.rec("Skills", 115), actor, enemy, {"critical": true, "variance": false})
	_check("damage_ledger_guard", float(hit.value) > 0 and XTianqiLedger.violations.is_empty(), XTianqiLedger.violations)
	logic.end_battle(0)

	var back := kit.roundtrip()
	_check("save_load_slots", back != null and XTianqiSecrets.active_ids(back.actor(actor.actor_id), back) == [2471, 2480, 2822, 6139])
	XTianqiGeneralBooks.ENABLED = false
	_check("general_books_off_restores_unmodified_skill", int(XDB.rec("Skills", 115).tpCost) == 10
		and not str(XDB.rec("Skills", 115).damage.formula).contains("XTianqiGeneralBooks"))
	_check("general_books_off_preserves_legacy_status", XDB.rec("Skills", 6328).meta.has("StartPushState1248"))
	XTianqiGeneralBooks.ENABLED = true
	XState.current = XState.new()
	_check("xiyou_keeps_original_damage", not str(XDB.rec("Skills", 115).damage.formula).contains("XTianqiGeneralBooks"))
	_check("xiyou_keeps_original_passive", str(XDB.rec("Skills", 2471).meta.passiveELUP01).strip_edges() == "30%")
	kit.teardown()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
