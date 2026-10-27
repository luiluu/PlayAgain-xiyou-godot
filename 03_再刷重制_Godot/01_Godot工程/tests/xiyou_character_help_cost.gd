extends Node
var total := 0
var passed := 0
func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ",tag," ",JSON.stringify(detail))
func _ready() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/character_help_cost_oracle.json"))
	check("source",ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	for c in ref.cases:
		var s := XState.new_game_blank()
		var a := s.actor(int(c.setup.actor))
		a.change_level_mv(int(c.setup.level))
		if c.setup.discount: a.learn_skill(9951)
		a.refresh_passive(); a.recover_all()
		var item := XDB.rec("Skills",int(c.setup.skill))
		check(c.id+".native",c.errors.is_empty())
		check(c.id+".mmp",a.mmp == float(c.observed.mmp),[a.mmp,c.observed.mmp])
		check(c.id+".mp",XCharacterHelp._cost(a,item,"MP") == int(c.observed.mp))
		check(c.id+".tp",XCharacterHelp._cost(a,item,"TP") == int(c.observed.tp))
		var got: Array = XHelpCard.content(item).filter(func(r):return str(r[0]).contains("消耗")).map(func(r):return r[0])
		check(c.id+".rows",JSON.stringify(got) == JSON.stringify(c.observed.rows),[got,c.observed.rows])
	print("TEST_RESULT="+JSON.stringify({"passed":passed,"total":total}))
	get_tree().quit(0 if passed == total else 1)
