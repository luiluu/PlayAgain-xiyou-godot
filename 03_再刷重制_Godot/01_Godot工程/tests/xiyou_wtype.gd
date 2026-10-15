extends Node
## 技能武器类型要求（XBattleLogic.wtype_ok，MV Game_Actor.isSkillWtypeOk＋dsPassiveSkill isWtypeEquipped）：
## 与 mv_oracle wtype_probe 的参照（generated/oracle/wtype.json）逐例比对——切片角色 10 级 × 默认装备／裸装／各武器类型第一件
## × 技能，比 isSkillWtypeOk 与战斗中 canUse（满 MP/TP）。

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
		var mmp_diff := {}
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
				var got := [XBattleLogic.wtype_ok(a, sk), logic.can_use(a, sk), a.mmp, a.mp]
				# MP 上限与正式版不同的角色（2、9 号 10 级，另案）只比武器类型，canUse 受费用影响不比
				if float(a.mmp) != float(c.mmp):
					mmp_diff[str(first.actor)] = [a.mmp, c.mmp]
					check("%s_%d" % [key, int(c.skill)], got[0] == bool(c.wtypeOk), [got, c.wtypeOk])
				else:
					check("%s_%d" % [key, int(c.skill)], got.slice(0, 2) == [bool(c.wtypeOk), bool(c.canUse)], [got, c.wtypeOk, c.canUse])
		check("wtype_blocked_covered", data.cases.filter(func(c): return not c.wtypeOk).size() >= 50)
		print("MMP_DIFF ", JSON.stringify(mmp_diff))
	XGear.force_roll = -1.0
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
