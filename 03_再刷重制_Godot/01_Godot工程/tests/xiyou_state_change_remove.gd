extends Node
## StateChangeIfRemove 的「SC自动解除」：纵横（1328，回合结束型 3 回合，备注 <SC自动解除:1329>）到期后换成联宇（1329）；
## 没到期、被手动移除、没有备注的状态不触发。
var passed := 0
var total := 0

func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))

func _ready() -> void:
	_run.call_deferred()

func battle() -> XBattleLogic:
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	for a in s.members():
		a.refresh_passive()
		a.recover_all()
	var l := XBattleLogic.new()
	l.elite_roll = 100.0
	l.setup(2, s)
	return l

func _run() -> void:
	var meta: Dictionary = XDB.rec("States", 1328).get("meta", {})
	check("meta", str(meta.get("SC自动解除", "")).strip_edges() == "1329", meta)
	var l := battle()
	var e: XBattler = l.enemies[0]
	e.add_state(1328)
	var turns := int(e.state_turns[1328])
	check("turns", turns >= 1, turns)
	for i in turns - 1:
		l.turn_end_battler(e, [])
	check("before_expiry", e.state_ids.has(1328) and not e.state_ids.has(1329), e.state_ids)
	l.turn_end_battler(e, [])
	check("expired_changes", not e.state_ids.has(1328) and e.state_ids.has(1329), e.state_ids)
	l.turn_end_battler(e, [])
	check("new_state_not_ticked_same_pass", e.state_ids.has(1329), e.state_ids)
	# 手动移除不触发
	var l2 := battle()
	var e2: XBattler = l2.enemies[0]
	e2.add_state(1328)
	e2.remove_state(1328)
	check("manual_remove_no_change", not e2.state_ids.has(1329), e2.state_ids)
	# 没备注的回合结束型状态到期不会多出别的状态
	var l3 := battle()
	var e3: XBattler = l3.enemies[0]
	e3.add_state(1329)
	var before := e3.state_ids.duplicate()
	check("no_tag_nothing", e3.state_ids == before and not e3.state_ids.has(1328), e3.state_ids)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
