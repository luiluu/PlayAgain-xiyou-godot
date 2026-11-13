extends Node
## 【cc·未经审查】战斗出招前停顿（Kyo 11-13 v0.01.07 反馈「每个角色行动完之后卡 0.5 秒左右」，接 cc/battle-lag）。两项记忆各带回退开关，这里核「开和关结果一样」：
## - O-390 状态表记忆（XBattler.STATES_MEMO）：身上状态、破甲·真气倍率、套装状态没变就用上次的表；就地改 state_ids、换倍率、
##   换套装状态都当场重算；给出去的是副本，调用方改了不影响下一次；
## - O-391 侧栏格子记忆（XSideStatus.CELL_MEMO）：状态表、层数、强化弱化没变就用上次排好的格子；
## - 同一种子的同一场自动战斗（敌人挂满状态），开关两态的整份日志（含每条命中的画面快照）、随机流、收场资源逐项相同；
##   READ_VERIFY 打开时每次命中都重算比对，一次不一致都不许有。
## 末尾打印行动结算耗时（PERF 行，只看不判）。
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail).left(600))


func _switches(on: bool) -> void:
	XBattler.STATES_MEMO = on
	XSideStatus.CELL_MEMO = on


func _plain(v, logic: XBattleLogic):
	if v is XBattler:
		return logic.stable_id(v)
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(_plain(k, logic))] = _plain(v[k], logic)
		return out
	if v is Array:
		return v.map(func(x): return _plain(x, logic))
	if v is Object:
		return "<%s>" % v.get_class()
	if v is Callable:
		return "<callable>"
	return v


func _new_state(lv: int) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.actor_max_level = 99
	s.random_master = XRandomStream.hex64(20261113)
	for id in s.party:
		var a := s.actor(id)
		a.change_level_mv(lv)
		a.refresh_passive()
		a.recover_all()
	return s


## 带图标、不限制行动、有特性或会自动解除的状态（挂满敌人、角色，同玩家反馈的木桩）
func _icon_states(n: int) -> Array:
	var out := []
	for id in range(10, 4000):
		var r := XDB.rec("States", id)
		if r.is_empty() or int(r.get("iconIndex", 0)) <= 0 or int(r.get("restriction", 0)) != 0:
			continue
		if int(r.get("autoRemovalTiming", 0)) == 0 and r.get("traits", []).is_empty():
			continue
		out.append(id)
		if out.size() >= n:
			break
	return out


## 一场三回合的自动战斗：返回日志摘要与行动结算耗时（微秒）
func _battle(troop: int, nstates: int) -> Dictionary:
	var s := _new_state(99)
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	var ids := _icon_states(nstates)
	for e in logic.enemies:
		e._rates[0] *= 1000
		e.recover_all()
		for id in ids:
			e.add_state(id)
	for a in logic.actors:
		for id in ids.slice(0, 11):
			a.add_state(id)
	logic.auto = true
	var journal := [_plain(logic.views(), logic)]
	var out := {"act": 0, "acts": 0}
	for round_index in 3:
		logic.start_turn()
		journal.append(_plain(logic.take_turn_start_logs(), logic))
		var count := 0
		while count < 50:
			var u := logic.next_subject()
			if u == null:
				break
			count += 1
			var cmd := logic.decide(u)
			var t0 := Time.get_ticks_usec()
			var logs := logic.act(u, cmd[0], cmd[1])
			out.act += Time.get_ticks_usec() - t0
			out.acts += 1
			journal.append([logic.stable_id(u), int(cmd[0].id) if cmd[0] != null else 0, _plain(logs, logic), _plain(logic.move_flags(), logic)])
		journal.append(_plain(logic.end_turn(), logic))
		if logic.is_over():
			break
	journal.append([logic.random.snapshot(), logic.actors.map(func(a): return [a.hp, a.mp, a.tp, a.state_ids.duplicate(), XSideStatus.cell_rows(a)]),
		logic.enemies.map(func(e): return [e.hp, e.mp, e.tp, e.state_ids.duplicate(), XSideStatus.cell_rows(e)])])
	out.sig = JSON.stringify(journal).sha256_text()
	out.size = JSON.stringify(journal).length()
	return out


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_act_stat_memo"
	XConfig.path_override = XSave.dir().path_join("options.json")
	_states_rules()
	_cell_rules()
	_battles()
	_switches(true)
	XActor.READ_VERIFY = false
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _fresh_states(b: XBattler) -> Array:
	XBattler.STATES_MEMO = false
	var v := b.states()
	XBattler.STATES_MEMO = true
	return v


## 状态表：写入（含就地改）当场重算、给副本、回退
func _states_rules() -> void:
	_switches(true)
	var s := _new_state(60)
	var a := s.actor(1)
	var ids := _icon_states(6)
	a.add_state(ids[0])
	var first := a.states()
	check("states_same", first == _fresh_states(a) and not first.is_empty())
	var stamp := a.states_stamp()
	check("states_stamp_stable", a.states_stamp() == stamp and a.states() == first)
	# 给出去的是副本：调用方改了不影响下一次
	first.clear()
	check("states_copy", a.states() == _fresh_states(a) and not a.states().is_empty())
	# 正常加状态
	a.add_state(ids[1])
	check("states_add", a.states() == _fresh_states(a) and a.states_stamp() != stamp and a.states().size() == 2)
	# 就地改 state_ids（不经 add_state／remove_state）也跟上
	a.state_ids.append(ids[2])
	check("states_inplace_append", a.states() == _fresh_states(a) and a.states().size() == 3)
	a.state_ids.erase(ids[0])
	check("states_inplace_erase", a.states() == _fresh_states(a) and a.states().size() == 2)
	# 破甲·真气倍率变了：换视图
	a.add_state(XZhenqi.POJIA_STATE)
	a.zq_pojia_rate = 0.3
	var pojia = a.states().filter(func(st): return int(st.id) == XZhenqi.POJIA_STATE)
	check("states_pojia_rate", a.states() == _fresh_states(a) and pojia.size() == 1 and not is_same(pojia[0], XDB.rec("States", XZhenqi.POJIA_STATE)), pojia.size())
	a.zq_pojia_rate = 0.5
	check("states_pojia_back", a.states() == _fresh_states(a))
	# 隐月 2521 修正开关（静态开关也在键里；新源数据本身已是 +2%，两态记录内容相同，这里核切换后重算）
	a.state_ids.append(2521)
	a.states()
	var ver := a._states_ver
	XBattler.FIX_YINYUE_2521 = not XBattler.FIX_YINYUE_2521
	check("states_2521_switch", a.states() == _fresh_states(a) and a._states_ver == ver + 1, [ver, a._states_ver])
	XBattler.FIX_YINYUE_2521 = not XBattler.FIX_YINYUE_2521
	# 敌人
	var logic := XBattleLogic.new()
	logic.setup(2, s)
	var e: XEnemy = logic.enemies[0]
	for id in ids:
		e.add_state(id)
	check("enemy_states", e.states() == _fresh_states(e) and e.states().size() == ids.size())
	e.remove_state(ids[3])
	check("enemy_remove", e.states() == _fresh_states(e) and e.states().size() == ids.size() - 1)
	# 影子克隆：各算各的
	var clone := XFormulaContext.clone_battler(a)
	clone.state_ids.clear()
	check("clone_own", clone.states().is_empty() and not a.states().is_empty() and a.states() == _fresh_states(a))
	# 回退：每次现查，不碰记忆
	XBattler.STATES_MEMO = false
	var before_ver := e._states_ver
	e.states()
	check("rollback_no_memo", e._states_ver == before_ver)
	XBattler.STATES_MEMO = true


func _fresh_cells(b: XBattler) -> Array:
	XSideStatus.CELL_MEMO = false
	var v := XSideStatus.cell_rows(b)
	XSideStatus.CELL_MEMO = true
	return v


## 侧栏格子：状态、层数、强化弱化变了当场重排；给副本
func _cell_rules() -> void:
	_switches(true)
	var s := _new_state(60)
	var logic := XBattleLogic.new()
	logic.setup(2, s)
	var e: XEnemy = logic.enemies[0]
	for id in _icon_states(22):
		e.add_state(id)
	var rows := XSideStatus.cell_rows(e)
	check("cell_same", rows == _fresh_cells(e) and rows.size() >= 5, rows.size())
	var n0 := rows.size()
	rows[0].stack = 99
	rows.clear()
	check("cell_copy", XSideStatus.cell_rows(e) == _fresh_cells(e) and not XSideStatus.cell_rows(e).is_empty())
	e.buffs[2] = 1
	check("cell_buff", XSideStatus.cell_rows(e) == _fresh_cells(e) and XSideStatus.cell_rows(e).size() == n0 + 1, [n0, XSideStatus.cell_rows(e).size()])
	e.buffs[3] = -2
	check("cell_debuff", XSideStatus.cell_rows(e) == _fresh_cells(e))
	var fid := -1
	for id in XBattler.FLOOR_STATES:
		if not XDB.rec("States", id).is_empty() and int(XDB.rec("States", id).get("iconIndex", 0)) > 0:
			fid = id
			break
	if fid > 0:
		e.add_state(fid)
		var c1 := XSideStatus.cell_rows(e)
		e.state_floors[fid] = 3
		check("cell_floor", XSideStatus.cell_rows(e) == _fresh_cells(e) and XSideStatus.cell_rows(e) != c1)
	e.state_ids.remove_at(0)
	check("cell_state_inplace", XSideStatus.cell_rows(e) == _fresh_cells(e))
	var a := s.actor(1)
	a.add_state(_icon_states(3)[2])
	check("cell_actor", XSideStatus.cell_rows(a) == _fresh_cells(a))
	XSideStatus.CELL_FILTER = false
	check("cell_filter_switch", XSideStatus.cell_rows(e) == _fresh_cells(e))
	XSideStatus.CELL_FILTER = true
	# 状态表记忆关着时格子也不记（要读状态表版本号）
	XBattler.STATES_MEMO = false
	var memo := e._cell_memo
	XSideStatus.cell_rows(e)
	check("cell_needs_states_memo", is_same(e._cell_memo, memo))
	XBattler.STATES_MEMO = true


func _battles() -> void:
	for troop in [2, 70]:
		_switches(false)
		var off := _battle(troop, 22)
		_switches(true)
		var on := _battle(troop, 22)
		check("battle_same:%d" % troop, off.sig == on.sig and int(off.acts) >= 4 and int(off.size) > 2000, [off.sig, on.sig, off.acts, off.size])
		XActor.READ_VERIFY = true
		XActor.read_hits = 0
		XActor.read_mismatches.clear()
		var verified := _battle(troop, 22)
		XActor.READ_VERIFY = false
		check("battle_verify:%d" % troop, XActor.read_mismatches.is_empty() and XActor.read_hits > 1000 and verified.sig == off.sig, [XActor.read_hits, XActor.read_mismatches.slice(0, 3)])
		# 只开状态表记忆
		_switches(false)
		XBattler.STATES_MEMO = true
		check("battle_states_only:%d" % troop, _battle(troop, 22).sig == off.sig)
		_switches(false)
		var bare_off := _battle(troop, 0)
		_switches(true)
		check("battle_no_states:%d" % troop, _battle(troop, 0).sig == bare_off.sig)
		var best := {}
		for pass_on in [false, true]:
			_switches(pass_on)
			for k in 3:
				var r := _battle(troop, 22)
				best[pass_on] = mini(int(best.get(pass_on, 1 << 60)), int(r.act))
		print("PERF 敌群 %d 挂 22 层状态（%d 次行动）关→开：行动结算合计 %.1f→%.1f ms" % [troop, off.acts, best[false] / 1000.0, best[true] / 1000.0])
