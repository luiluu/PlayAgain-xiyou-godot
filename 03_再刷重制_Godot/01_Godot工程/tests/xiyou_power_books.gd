extends Node
## Canonical native learn/apply/plain-forget/paid-forget and static attributes.
var checks := 0
var failures: Array = []
var s: XState

func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 15:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1000))

func compare(tag: String, got, want) -> void:
	if want is Array:
		check(tag+".size",got is Array and got.size() == want.size(),[got,want])
		if got is Array:
			for i in mini(got.size(),want.size()):
				compare(tag+".%d" % i,got[i],want[i])
	elif want is Dictionary:
		for key in want:
			compare(tag+"."+key,got.get(key),want[key])
	elif want is bool or want is String or want == null:
		check(tag,got == want,[got,want])
	else:
		check(tag,got != null and absf(float(got)-float(want)) <= 1e-8,[got,want])

func snapshot(a: XActor) -> Dictionary:
	return {"skills":a.skill_ids.duplicate(),"powers":XPowerBooks.learned(a),"class":XPowerBooks.actor_class(a),"limit":XPowerBooks.limit(a),
		"param":range(8).map(func(i): return a.param(i)),"xparam":range(10).map(func(i): return a.xparam(i)),
		"sparam":range(10).map(func(i): return a.sparam(i)),"elements":range(1,16).map(func(i): return XDamage.element_bonus(a,i)),
		"maxTp":a.max_tp(),"preserveTp":a.is_preserve_tp(),"actionPlus":a.action_plus_set(),"forgetTokens":s.item_count(3044)}

func fresh(actor_id: int) -> XActor:
	s = XState.new_game_blank()
	s.set_variable(9,999)
	s.party.assign([actor_id])
	s.battle_slots = [actor_id,0,0,0,0]
	var a := s.actor(actor_id)
	a._lv = 37
	a.equips.fill(null)
	a.state_ids.clear()
	a.refresh_passive()
	a.recover_all()
	return a

func run_case(c: Dictionary) -> void:
	var a := fresh(int(c.setup.actor))
	compare(c.id+".before",snapshot(a),c.observed.before)
	compare(c.id+".registry",XPowerBooks.skills(),c.observed.registry)
	var battle := XBattleLogic.new()
	battle.state = s
	battle.actors = [a]
	for row in c.observed.rows:
		var id := int(row.skill)
		compare(c.id+".pre",snapshot(a),row.pre)
		compare(c.id+".allowed",XPowerBooks.can_learn(a,id),row.allowed)
		compare(c.id+".reason",XPowerBooks.learn_reason(a,id),row.reason)
		battle.apply(a,XDB.rec("Items",int(row.item)),a)
		a.refresh_passive()
		a.recover_all()
		compare(c.id+".learned",snapshot(a),row.learned)
		compare(c.id+".repeat_allowed",XPowerBooks.can_learn(a,id),row.repeatAllowed)
		compare(c.id+".repeat_reason",XPowerBooks.learn_reason(a,id),row.repeatReason)
		a.learn_skill(id)
		a.refresh_passive()
		compare(c.id+".repeat",snapshot(a),row.repeat)
		if row.ordinary != null:
			a.forget_skill(id)
			a.refresh_passive()
			compare(c.id+".ordinary",snapshot(a),row.ordinary)
			compare(c.id+".missing_token",XPowerBooks.forget_paid(s,a,id),row.missingToken)
			s.gain_item(3044,1)
			compare(c.id+".paid",XPowerBooks.forget_paid(s,a,id),row.paid)
			a.refresh_passive()
			a.recover_all()
		compare(c.id+".after_row",snapshot(a),row.after)
	compare(c.id+".after",snapshot(a),c.observed.after)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/power_books_oracle.json"))
	check("source",fixture.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("fixture.complete",fixture.cases.size() == 8)
	var ids := {}
	for c in fixture.cases:
		check(c.id+".unique",not ids.has(c.id))
		ids[c.id] = true
		check(c.id+".native",c.errors.is_empty())
		if c.errors.is_empty():
			run_case(c)
	print("TEST_RESULT="+JSON.stringify({"passed":checks-failures.size(),"total":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
