extends Node
## 冻结v0.28内存实测：clearStates/recoverAll的Permanent、剩余回合、TP与buff边界。
var total := 0
var passed := 0
func check(label: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", label, " ", JSON.stringify(detail))
func _ready() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/recover_permanent_review.json"))
	check("reference_present", ref is Dictionary and ref.get("cases", []).size() == 4)
	if ref is Dictionary:
		var manifest: Dictionary = XDB.load_json("manifest.json")
		check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
		for row in ref.cases:
			check(str(row.id) + ".oracle_clean", row.errors.is_empty())
			var s := XState.new_game(3, 1, [8, 9, 10])
			var b: XBattler
			if row.setup.kind == "actor":
				b = s.actor(1)
			else:
				var e := XEnemy.new()
				e.setup(int(XDB.rec("Troops", 2).members[0].enemyId), 3, 100.0)
				b = e
			b.state_ids.assign([686, 2])
			b.state_turns = {686: 5, 2: 3}
			b.buffs.assign([0, 0, 1, 0, 0, 0, 0, 0])
			b.buff_turns.assign([0, 0, 4, 0, 0, 0, 0, 0])
			b.param_mark_dirty()
			b.param_refresh()
			b.hp = 1
			b.mp = 2
			b.tp = 37
			if row.setup.operation == "clearStates":
				b.clear_states()
			else:
				b.recover_all()
			var got := {"states": b.state_ids.duplicate(), "turns": b.state_turns.duplicate(),
				"tp": b.tp, "buffs": Array(b.buffs), "buffTurns": Array(b.buff_turns),
				"hpIsMax": b.hp == b.mhp, "mpIsMax": b.mp == b.mmp}
			for key in row.observed:
				check(str(row.id) + "." + str(key), JSON.parse_string(JSON.stringify(got[key])) == row.observed[key], [got[key], row.observed[key]])
	print("TEST_RESULT=", JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
