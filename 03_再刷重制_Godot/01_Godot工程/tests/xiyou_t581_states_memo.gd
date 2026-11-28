extends Node
## 【cc·未经审查】T581：状态表记忆（O-390 XBattler.STATES_MEMO）的键带上西游档改写（T576 另报）。
## 读档时 XState.from_dict 在新档变成当前档之前就给角色算了一次状态表（refresh_passive），那时是旧档或没有存档，
## 徐凤年 2539 真·剑九取到的是原版记录（终伤 +500%），西游档改写（XXufeng，+200%）要等身上状态变了才换。
## 这里核：
## 1) 存档→读档（读档前没有当前档）→第一回合：角色、战斗里的 2539 都是西游档改写后的记录（k = ST2539_RATE），READ_VERIFY 下零不一致；
## 2) 离群削弱（XXiyouNerf）的状态 2739 同理；
## 3) 西游档→西游档读档、没存档时取到原版记录；
## 4) 天启篇：读档后 2539 与 XDB.rec 同一份，和开关关（不记忆）结果相同（天启篇零改动）；
## 5) 回退开关 XBattler.STATES_MEMO_XIYOU_KEY = false 回到 T581 之前（读档后仍是原版 +500% 记录）。
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail).left(600))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var was_rel_xf := XImportedBalance.RELEASE_XUFENG
	var was_xf := XXufeng.REWORK
	var was_memo := XBattler.STATES_MEMO
	var was_p4 := XTianqiBase.PHASE4
	XMessageBox.auto = true
	XSave.dir_override = "user://test_xiyou_t581_states_memo"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XImportedBalance.RELEASE_XUFENG = true
	XXufeng.REWORK = true
	XXufeng.clear_cache()
	XBattler.STATES_MEMO = true

	_check_xiyou_load_first_turn()
	_check_nerf_state()
	_check_no_save_original()
	_check_tianqi_untouched()
	_check_switch_off()

	XImportedBalance.RELEASE_XUFENG = was_rel_xf
	XXufeng.REWORK = was_xf
	XXufeng.clear_cache()
	XBattler.STATES_MEMO = was_memo
	XTianqiBase.PHASE4 = was_p4
	XState.current = null
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


func _k(st: Dictionary) -> float:
	return float(st.effects[0].groups[0].steps[0].k)


func _find(list: Array, id: int) -> Dictionary:
	for st in list:
		if int(st.get("id", 0)) == id:
			return st
	return {}


func _xiyou_save(states: Array) -> Dictionary:
	var s := XState.new_game_blank()
	s.random_master = XRandomStream.hex64(20261128)
	s.set_switch(2494, true)  # 同 xiyou_xufeng_rework 的西游测试档：放行超强者入队
	s.set_variable(20, 30)
	XState.current = s
	s.add_actor(152)
	var a: XActor = s.actor(152)
	a.change_level(80)
	a.recover_all()  # 回满会清状态，先回满再挂
	for id in states:
		a.state_ids.append(id)
	a.param_mark_dirty()
	a.refresh_passive()
	return XSaveSlim.as_reloaded(s.to_dict())


func _check_xiyou_load_first_turn() -> void:
	var d := _xiyou_save([XXufeng.ST_TRUE_SWORD9])
	XState.current = null  # 标题画面读档：读档前没有当前档
	var s := XState.from_dict(d)
	check("xy.loaded_is_current", XState.current == s and XXufeng.xiyou_save_on())
	var a: XActor = s.actor(152)
	var st := _find(a.states(), XXufeng.ST_TRUE_SWORD9)
	check("xy.load.2539_rework", not st.is_empty() and is_equal_approx(_k(st), float(XXufeng.ST2539_RATE))
		and is_same(st, XDB.rec("States", XXufeng.ST_TRUE_SWORD9)), [st.get("id"), _k(st) if not st.is_empty() else null])
	# 第一回合：开战、第一轮行动前后战斗者手上的 2539
	var was_verify := XActor.READ_VERIFY
	var was_fatal := XActor.READ_VERIFY_FATAL
	XActor.READ_VERIFY = true
	XActor.READ_VERIFY_FATAL = false
	XActor.read_mismatches.clear()
	var logic := XBattleLogic.new()
	logic.setup(70, s, XBattleRandom.create(str(s.random_master)))
	check("xy.party", s.party.has(152) and s.battle_slots.has(152), [s.party, s.battle_slots])
	var bt: XActor = null
	for m in logic.actors:
		if m is XActor and m.actor_id == 152:
			bt = m
	var st0 := _find(bt.states(), XXufeng.ST_TRUE_SWORD9) if bt else {}
	check("xy.turn1.2539_rework", not st0.is_empty() and is_equal_approx(_k(st0), float(XXufeng.ST2539_RATE)), st0.get("id"))
	# 打完第一回合（自动），READ_VERIFY 下每次命中都现算比对
	logic.auto = true
	logic.start_turn()
	var acts := 0
	while acts < 50:
		var u := logic.next_subject()
		if u == null:
			break
		acts += 1
		var cmd := logic.decide(u)
		logic.act(u, cmd[0], cmd[1])
	logic.end_turn()
	check("xy.turn1.acted", acts > 0, acts)
	var bad := XActor.read_mismatches.filter(func(m): return str(m).contains("states"))
	check("xy.turn1.verify_no_mismatch", bad.is_empty(), bad.slice(0, 3))
	XActor.READ_VERIFY = was_verify
	XActor.READ_VERIFY_FATAL = was_fatal
	logic.end_battle(0)


func _check_nerf_state() -> void:
	if not XXiyouNerf.ENABLED:
		check("nerf.skip_disabled", true)
		return
	var sid := XXiyouNerf.FEITIAN_ST_2739
	var d := _xiyou_save([sid])
	XState.current = null
	var s := XState.from_dict(d)
	var st := _find(s.actor(152).states(), sid)
	var want := XDB.rec("States", sid)
	check("nerf.load.2739_rework", not st.is_empty() and is_same(st, want) and not is_same(want, XDB.table("States")[sid]),
		[st.get("id"), is_same(want, XDB.table("States")[sid])])


func _check_no_save_original() -> void:
	var d := _xiyou_save([XXufeng.ST_TRUE_SWORD9])
	var s := XState.from_dict(d)  # 西游档读西游档：读档前当前档已是西游档
	check("xy_to_xy.2539_rework", is_equal_approx(_k(_find(s.actor(152).states(), XXufeng.ST_TRUE_SWORD9)), float(XXufeng.ST2539_RATE)))
	var a: XActor = s.actor(152)
	XState.current = null  # 没有存档：回原版
	check("no_save.2539_original", is_equal_approx(_k(_find(a.states(), XXufeng.ST_TRUE_SWORD9)), 5.0))
	XState.current = s
	check("back_to_xy.2539_rework", is_equal_approx(_k(_find(a.states(), XXufeng.ST_TRUE_SWORD9)), float(XXufeng.ST2539_RATE)))


func _tianqi_save() -> Dictionary:
	XTianqiBase.PHASE4 = true
	XTianqiSkills.reload_table()
	var s := XState.new_game(XTianqi.legacy_of("zhengdao"), 152, [])
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "zhengdao", "lineup": [152]}
	s.random_master = XRandomStream.hex64(20261128)
	XState.current = s
	if not s.party.has(152):
		XTianqi._joining = true
		s.add_actor(152)
		XTianqi._joining = false
	var a: XActor = s.actor(152)
	a.change_level_mv(80)
	a.state_ids.append(XXufeng.ST_TRUE_SWORD9)
	a.param_mark_dirty()
	a.refresh_passive()
	return XSaveSlim.as_reloaded(s.to_dict())


func _check_tianqi_untouched() -> void:
	var d := _tianqi_save()
	var got := []
	for memo in [true, false]:
		XBattler.STATES_MEMO = memo
		XState.current = null
		var s := XState.from_dict(d)
		check("tq.memo_%s.active" % memo, XTianqi.active(XState.current) and not XXufeng.xiyou_save_on())
		var st := _find(s.actor(152).states(), XXufeng.ST_TRUE_SWORD9)
		check("tq.memo_%s.2539_same_as_rec" % memo, not st.is_empty() and is_same(st, XDB.rec("States", XXufeng.ST_TRUE_SWORD9)), st.get("id"))
		got.append(_k(st) if not st.is_empty() else null)
	XBattler.STATES_MEMO = true
	check("tq.memo_on_off_equal", got[0] == got[1], got)


func _check_switch_off() -> void:
	var d := _xiyou_save([XXufeng.ST_TRUE_SWORD9])
	XBattler.STATES_MEMO_XIYOU_KEY = false
	XState.current = null
	var s := XState.from_dict(d)
	var st := _find(s.actor(152).states(), XXufeng.ST_TRUE_SWORD9)
	check("off.load.2539_old_behavior", not st.is_empty() and is_equal_approx(_k(st), 5.0), st.get("id"))
	XBattler.STATES_MEMO_XIYOU_KEY = true
	var st2 := _find(s.actor(152).states(), XXufeng.ST_TRUE_SWORD9)
	check("on_again.2539_rework", not st2.is_empty() and is_equal_approx(_k(st2), float(XXufeng.ST2539_RATE)))
