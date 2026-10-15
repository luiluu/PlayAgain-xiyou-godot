extends Node
## 技能武器类型要求（XBattleLogic.wtype_ok，MV Game_Actor.isSkillWtypeOk＋dsPassiveSkill isWtypeEquipped）：
## 与 mv_oracle wtype_probe 的参照（generated/oracle/wtype.json）逐例比对——切片角色 10 级 × 默认装备／裸装／各武器类型第一件
## × 技能，比 isSkillWtypeOk、战斗中 canUse（满 MP/TP 与清零时）与 MP 上限。

const ORACLE := "res://modes/xiyou/generated/oracle/wtype.json"
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 12:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _run() -> void:
	XGear.force_roll = 0.5
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if check("wtype_oracle_loaded", data is Dictionary and data.get("cases", []).size() >= 500, ORACLE):
		var groups := {}
		for c in data.cases:
			var key := "%d|%s" % [int(c.actor), str(c.variant)]
			if not groups.has(key):
				groups[key] = []
			groups[key].append(c)
		for key in groups:
			var first: Dictionary = groups[key][0]
			var st := XState.new_game_blank()
			var a := st.actor(int(first.actor))
			a.change_level_mv(10)
			if str(first.variant) != "default":
				for i in range(a.equips.size()):
					a.equips[i] = XGear.create("weapon", int(first.weapon)) if i == 0 and first.weapon != null and int(first.weapon) > 0 else null
				a.refresh_passive()
				a.release_unequippable()  # Game_Actor.refresh 的 releaseUnequippableItems
				a.refresh_passive()
			a.refresh_passive()
			a.recover_all()
			a.tp = a.max_tp()
			var logic := XBattleLogic.new()
			logic.state = st
			for c in groups[key]:
				var sk := XDB.rec("Skills", int(c.skill))
				var full := logic.can_use(a, sk)
				a.mp = 0.0
				a.tp = 0.0
				var empty := logic.can_use(a, sk)
				a.recover_all()
				a.tp = a.max_tp()
				var got := [XBattleLogic.wtype_ok(a, sk), full, empty, a.mmp]
				var want := [bool(c.wtypeOk), bool(c.canUse), bool(c.canUseEmpty), float(c.mmp)]
				check("%s_%d" % [key, int(c.skill)], got == want, [got, want])
		check("wtype_blocked_covered", data.cases.filter(func(c): return not c.wtypeOk).size() >= 50)
		# MP/TP 清零时有因费用被拦的例子，canUse 比对才不只是武器判断的重复
		check("cost_blocked_covered", data.cases.filter(func(c): return c.canUse and not c.canUseEmpty).size() >= 20)
	XGear.force_roll = -1.0
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
