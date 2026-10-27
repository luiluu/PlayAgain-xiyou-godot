extends "res://tests/xiyou_power_books.gd"
## 45 fresh native cases: all three learning hosts, five real cyclic orders and clone/paid boundaries.
func learn(a: XActor, row: Dictionary, mode: String, tag: String) -> void:
	var id := int(row.skill)
	compare(tag+".pre",snapshot(a),row.pre)
	compare(tag+".allowed",XPowerBooks.can_learn(a,id),row.allowed)
	compare(tag+".reason",XPowerBooks.learn_reason(a,id),row.reason)
	var logic := XBattleLogic.new()
	logic.state = s
	logic.actors = [a]
	var item := XDB.rec("Items",int(row.item))
	match mode:
		"apply": logic.apply(a,item,a)
		"effect":
			var effect: Dictionary = item.effects.filter(func(e): return int(e.code) == 43)[0]
			logic._effect(a,a,effect,{"skill":item,"hp":0.0,"mp":0.0,"added":[],"removed":[]})
		"direct": a.learn_skill(id)
	a.refresh_passive()
	a.recover_all()
	compare(tag+".after",snapshot(a),row.after)

func boundary(c: Dictionary) -> void:
	var a := fresh(int(c.setup.actor))
	var o: Dictionary = c.observed
	compare(c.id+".before",snapshot(a),o.before)
	for i in o.rows.size():
		learn(a,o.rows[i],str(c.setup.mode),c.id+".row%d" % i)
	var first := int(o.rows[0].skill)
	compare(c.id+".ordinaryBefore",snapshot(a),o.ordinaryBefore)
	a.forget_skill(first)
	a.refresh_passive()
	compare(c.id+".ordinaryAfter",snapshot(a),o.ordinaryAfter)
	var clone := XFormulaContext.clone_battler(a) as XActor
	check(c.id+".clone",clone != null)
	if clone != null:
		clone.forget_skill(first)
		clone.refresh_passive()
		compare(c.id+".cloneAfter",snapshot(clone),o.cloneAfter)
		compare(c.id+".canonicalUnchanged",snapshot(a),o.ordinaryAfter)
	compare(c.id+".missing",XPowerBooks.forget_paid(s,a,first),o.missing)
	s.gain_item(3044,2)
	compare(c.id+".paid",XPowerBooks.forget_paid(s,a,first),o.paid)
	a.refresh_passive()
	a.recover_all()
	compare(c.id+".paidAfter",snapshot(a),o.paidAfter)
	compare(c.id+".again",XPowerBooks.forget_paid(s,a,first),o.again)
	compare(c.id+".againAfter",snapshot(a),o.againAfter)
	learn(a,o.relearn,str(c.setup.mode),c.id+".relearn")
	compare(c.id+".after",snapshot(a),o.after)

func _run() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/power_books_boundary_oracle.json"))
	check("source",d.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("fixture.complete",d.cases.size() == 45)
	var ids := {}
	for c in d.cases:
		check(c.id+".unique",not ids.has(c.id))
		ids[c.id] = true
		check(c.id+".native",c.errors.is_empty())
		if c.errors.is_empty(): boundary(c)
	print("TEST_RESULT="+JSON.stringify({"passed":checks-failures.size(),"total":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
