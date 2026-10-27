extends Node
## 原版最小反例：等级不够的武器必须卸下，足级才保留；修测试前提不能放宽装备规则。
func _ready() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/equipment_admission_oracle.json"))
	var total := 1
	var passed := int(ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	for c in ref.cases:
		var s := XState.new_game_blank()
		var a := s.actor(int(c.setup.aid))
		a.change_level_mv(int(c.setup.level))
		a.equips[0] = XGear.template("weapon", int(c.setup.wid))
		a.refresh_resources()
		var retained: bool = a.equips[0] != null
		var ok: bool = c.errors.is_empty() and retained == c.observed.after and a.can_equip(XGear.template("weapon",int(c.setup.wid))) == c.observed.canEquip
		total += 1
		if ok: passed += 1
		else: print("FAIL equip_admission ", c.id, " ", retained)
		if int(c.setup.aid) == 10:
			a.tp = 9
			var logic := XBattleLogic.new()
			logic.state = s
			ok = logic.can_use(a, XDB.rec("Skills",3644)) == c.observed.canUseCold
			total += 1
			if ok: passed += 1
			else: print("FAIL cold_admission ", c.id)
	print("TEST_RESULT=" + JSON.stringify({"passed":passed,"total":total}))
	get_tree().quit(0 if passed == total else 1)
