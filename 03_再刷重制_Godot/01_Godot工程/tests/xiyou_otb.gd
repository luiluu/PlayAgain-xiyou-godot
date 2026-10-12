extends Node
## 从正式 OTB 插件取得的小型期望夹具；不依赖截图、存档或界面。
var results := []
var expected: Dictionary

class FixedLogic extends XBattleLogic:
	var repeats := {}
	func _sorted_by_speed(list: Array) -> Array:
		for i in range(list.size()):
			_speed[list[i]] = 100 - (actors + enemies).find(list[i]) * 10
		return list.duplicate()
	func make_action_times(b: XBattler) -> int:
		return int(repeats.get(b, 1))

func _ready() -> void:
	_run.call_deferred()

func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name":name,"passed":ok,"detail":detail})

func _key(b: XBattler, logic: XBattleLogic) -> String:
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)

func _orders(logic: XBattleLogic, row: String) -> void:
	var actual := {"current":logic.current_order.map(func(b): return _key(b,logic)), "next":logic.next_order.map(func(b): return _key(b,logic))}
	_check(row + "_oracle", actual == expected[row], actual)

func _stun() -> int:
	var states: Array = XDB.table("States")
	var id := states.size()
	states.append({"id":id,"name":"OTB stun test","restriction":4,"autoRemovalTiming":2,"minTurns":1,"maxTurns":1,"traits":[],"meta":{},"note":"","removeAtBattleEnd":true})
	return id

func _run() -> void:
	expected = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/otb.json")).rows
	var s := XState.new_game(3, 1, [8,9,10])
	var l := FixedLogic.new()
	l.elite_roll = 100.0
	l.setup(2,s)
	var a: XActor = l.actors[0]
	var b: XActor = l.actors[1]
	l.start_turn(); _orders(l,"first")
	l._shift(l.actors[3],2,false); _orders(l,"shift_plus")
	l._shift(a,-2,false); _orders(l,"shift_minus")
	l.current_order.clear(); l.start_turn(); _orders(l,"carry")
	l.repeats[a]=8; l._orders_made=false; l.start_turn(); _orders(l,"cap")
	l._shift(a,-2,false); _orders(l,"shift_repeats")
	l.repeats.clear()
	var stun := _stun()
	b.add_state(stun); b.state_turns[stun]=1
	l._orders_made=false; l.start_turn(); _orders(l,"stun_one")
	b.state_turns[stun]=2; l._clear_unable(); _orders(l,"stun_two")
	var before := l._movable_snapshot()
	b.remove_state(stun); l._sync_orders(before,true); _orders(l,"wakeup")
	l._orders_made=false; l.start_turn();
	l._otb_user_shift(a,XDB.rec("Skills",2)); _orders(l,"guard")
	l._orders_made=false; l.start_turn();
	l._otb_target_shift({"note":"<OTB Target Current Turn: +2>\n<OTB Target Next Turn: -1>"}, l.actors[3]); _orders(l,"target")
	# 队伍轮到才选指令；每次 next_subject 只取走一个席位，行动之后才累计。
	l._orders_made=false; l.start_turn()
	var subject := l.next_subject()
	_check("subject_pops_one", subject == a and not l.current_order.has(a))
	l.act(a, XDB.rec("Skills",2),null)
	_check("action_counted", int(l._acted.get(a,0)) == 1)
	l.end_turn(); _check("turn_count_reset", l._acted.is_empty())
	# 死亡移除、复活补回；回合结束醒来不补进已经结束的当前回合。
	before=l._movable_snapshot(); b.hp=0; l._sync_orders(before,true)
	_check("dead_removed", not l.current_order.has(b) and not l.next_order.has(b))
	before=l._movable_snapshot(); b.recover_all(); l._sync_orders(before,true)
	_check("revived_appended", l.current_order.back() == b and l.next_order.back() == b)
	b.add_state(stun); b.state_turns[stun]=1; l._clear_unable(); l.current_order.clear(); l.end_turn()
	_check("turn_end_wakeup", l.can_move(b) and l.current_order.is_empty() and l.next_order.has(b))
	# 敏捷增益换位；物品使用不触发使用者技能速度换位。
	l.next_order = [a,b,l.actors[2],l.actors[3]]
	l._otb_target_shift({"note":"","effects":[{"code":31,"dataId":6}]},l.actors[3])
	_check("agi_buff_shift", l.next_order == [a,b,l.actors[3],l.actors[2]])
	l.state.gain_item(1,1)
	var order_before := l.next_order.duplicate()
	l.execute(a,XDB.rec("Items",1),a)
	_check("item_no_user_shift", l.next_order == order_before)
	# 正式插件复活插入未再钳制次数；Godot 保持每回合五次上限，不让复活绕过。
	l.repeats[b] = 8
	l._acted[b] = 5
	before = l._movable_snapshot(); b.hp = 0; l._sync_orders(before,true)
	before = l._movable_snapshot(); b.recover_all(); l._sync_orders(before,true)
	_check("revive_cannot_exceed_five", not l.current_order.has(b))
	l.current_order.clear(); l.next_order.clear(); l._acted.clear()
	l._insert_orders(b,l.current_order)
	_check("revive_insert_cap", l.current_order.count(b) == 5)
	l.end_battle()
	var passed := results.filter(func(r):return r.passed).size()
	for r in results:
		if not r.passed: print("FAIL ",r.name," ",JSON.stringify(r.detail))
	print("TEST_RESULT="+JSON.stringify({"passed":passed,"total":results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
