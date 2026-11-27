extends Node
## 【cc·未经审查】T572 西游档四倍速点技能前卡顿、菜单栏滑动卡（玩家玄及 11-27 反馈＋存档）。读能力值时技能表重建三处：
## - XTianqiWeakAffix.XIYOU_SKIP（O-678）：西游档先判档，不建弱者词条投影号表；
## - XActor.SKILLS_ENTRY_HELD（O-679）：passive_values 的技能表缓存项记进只读窗口／跨步保留，不再每次现算 id 表；
## - XSideStatus.LIVE_WINDOW（O-680）：侧栏没有快照时实时读的上限值包进只读窗口。
## 断言：开关两态结果逐项相同（技能表、被动值、侧栏读数、整场战斗日志摘要），西游档和天启篇各一场；开着时现算次数确实少了；
## 天启篇弱者词条投影照旧生效、两态相同；开着时全程比对（XActor.READ_VERIFY）零不一致。
var results := []
const TAGS := ["passivePBST", "passivePBSTEX", "passiveELUP1", "passiveEXTTP"]
const MARSHA := 21


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail).left(800))


func _switches(on: bool) -> void:
	if on:
		XTianqiWeakAffix.XIYOU_SKIP = true
		XActor.SKILLS_ENTRY_HELD = true
		XSideStatus.LIVE_WINDOW = true
	else:  # 回退支（回退开关覆盖.py 认字面量）
		XTianqiWeakAffix.XIYOU_SKIP = false
		XActor.SKILLS_ENTRY_HELD = false
		XSideStatus.LIVE_WINDOW = false
	XActor.skills_touch()


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


## 西游档：四人 99 级，各自穿上能穿的装备、学一批被动
func _xiyou_state() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.actor_max_level = 99
	s.random_master = XRandomStream.hex64(20261127)
	var passives := _passives(40)
	for id in s.party:
		var a := s.actor(id)
		a.change_level_mv(99)
		for pick in [["weapon", 37], ["armor", 53], ["armor", 71], ["armor", 113]]:
			var table: Array = XDB.table("Weapons" if pick[0] == "weapon" else "Armors")
			for step in 40:
				var gid := 1 + (int(pick[1]) * (step + 1) + id * 7) % (table.size() - 1)
				if table[gid] == null or str(table[gid].get("name", "")) == "":
					continue
				var before := s.gear.size()
				s.gain_gear(str(pick[0]), gid, 1)
				if s.gear.size() == before:
					continue
				var item: Dictionary = s.gear[-1]
				var slot := a.equip_slots().find(1 if pick[0] == "weapon" else int(item.etypeId))
				if slot >= 0 and a.equips[slot] == null and a.can_equip(item) and XEquipment.change(s, a, slot, item):
					break
		for k in passives.size():
			if (k + id) % 2 == 0 and not a.skill_ids.has(passives[k]):
				a.learn_skill(passives[k])
		a.refresh_passive()
		a.recover_all()
	return s


## 天启篇档：玛莎戴着弱者专属词条（御风术投影 4507／10707）
func _tianqi_state() -> XState:
	var e: Dictionary = XTianqiWeakAffix.data().get("entries", {}).get("w21", {}).duplicate(true)
	e.enabled = true
	XTianqiWeakAffix.test_entries["w21"] = e
	var lineup := [MARSHA, 23, 3, 1, 2]
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.random_master = XRandomStream.hex64(20261127)
	XState.current = s
	var a := s.actor(MARSHA)
	a.change_level(99)
	for id in [4507, 10707]:
		if not a.skill_ids.has(id):
			a.learn_skill(id)
	a.keep_unequippable = true
	while a.equips.size() < 1:
		a.equips.append(null)
	var base = a.equips[0] if a.equips[0] is Dictionary else {"kind": "weapon", "base": 1, "etypeId": 1, "name": "测试兵器", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "wtypeId": 1}
	var inst: Dictionary = base.duplicate(true)
	inst[XTianqiWeakAffix.ITEM_KEY] = {"key": "w21"}
	a.equips[0] = inst
	a.param_mark_dirty()
	a.param_refresh()
	return s


func _passives(n: int) -> Array:
	var out := []
	var rows: Array = XDB.table("Skills")
	for i in range(1, rows.size()):
		var r = rows[i]
		if r is Dictionary and int(r.get("stypeId", 0)) == 4 and str(r.get("name", "")) != "" and not XTianqiSkills.is_shell(i):
			out.append(i)
			if out.size() >= n:
				break
	return out


func _actor_sig(a: XActor) -> Array:
	return [a.hp, a.mp, a.tp, a.mhp, a.mmp, a.max_tp(), a.atk, a.def, a.mat, a.mdf, a.agi, a.luk, a.state_ids.duplicate(),
		a.skills().map(func(x): return [int(x.id), str(x.get("note", "")).length(), str(x.get(XTianqiWeakAffix.VIEW_MARK, ""))]),
		TAGS.map(func(t): return a.passive_values(t))]


## 两回合自动战斗：整份日志摘要
func _battle(make: Callable, troop: int) -> Dictionary:
	seed(20261127)
	var s: XState = make.call()
	var logic := XBattleLogic.new()
	logic.setup(troop, s, XBattleRandom.create("0000000000572572"))
	for e in logic.enemies:
		e._rates[0] *= 1000
		e.recover_all()
	logic.auto = true
	var journal := [_plain(logic.views(), logic), logic.actors.map(_actor_sig)]
	var acts := 0
	for round_index in 2:
		logic.start_turn()
		journal.append(_plain(logic.take_turn_start_logs(), logic))
		var count := 0
		while count < 30:
			var u := logic.next_subject()
			if u == null:
				break
			count += 1
			var cmd := logic.decide(u)
			var logs := logic.act(u, cmd[0], cmd[1])
			acts += 1
			journal.append([logic.stable_id(u), int(cmd[0].id) if cmd[0] != null else 0, _plain(logs, logic)])
		journal.append(_plain(logic.end_turn(), logic))
		if logic.is_over():
			break
	journal.append(logic.actors.map(_actor_sig))
	journal.append(logic.random.snapshot())
	var text := JSON.stringify(journal)
	return {"sig": text.sha256_text(), "size": text.length(), "acts": acts}


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_t572_lag"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XActor.read_mismatches.clear()
	_weak_affix()
	_entry_held()
	_side_status()
	_battles()
	XTianqiWeakAffix.test_entries.clear()
	_switches(true)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- O-678：弱者词条投影 ----
func _weak_affix() -> void:
	# 西游档：开着不建投影号表；两态技能表相同
	var s := _xiyou_state()
	var e: Dictionary = XTianqiWeakAffix.data().get("entries", {}).get("w21", {}).duplicate(true)
	e.enabled = true
	XTianqiWeakAffix.test_entries["w21"] = e  # 有开着的条目，原写法会把号表建出来
	var a := s.actor(s.party[0])
	var res := {}
	for on in [true, false]:
		_switches(on)
		var b0 := XTianqiWeakAffix.proj_ids_builds
		var recs := a.skills()
		res[on] = [recs.map(func(x): return [int(x.id), x.get(XTianqiWeakAffix.VIEW_MARK, "")]), XTianqiWeakAffix.proj_of(a, 4507), XTianqiWeakAffix.proj_ids_builds - b0]
	check("weak.xiyou_same", res[true][0] == res[false][0] and res[true][1] == res[false][1] and res[true][1].is_empty(), [res[true][1], res[false][1]])
	check("weak.xiyou_no_table", int(res[true][2]) == 0 and int(res[false][2]) > 0, [res[true][2], res[false][2]])
	XTianqiWeakAffix.test_entries.clear()
	# 天启篇：投影照旧生效，两态相同
	var tq := {}
	for on in [true, false]:
		_switches(on)
		var ts := _tianqi_state()
		var m := ts.actor(MARSHA)
		var p := XTianqiWeakAffix.proj_of(m, 4507)
		var view := {}
		for sk in m.skills():
			if int(sk.id) == 4507:
				view = sk
		tq[on] = [p, str(view.get(XTianqiWeakAffix.VIEW_MARK, "")), str(view.get("note", "")), TAGS.map(func(t): return m.passive_values(t))]
	check("weak.tianqi_projects", not (tq[true][0] as Dictionary).is_empty() and tq[true][1] == "w21", tq[true].slice(0, 2))
	check("weak.tianqi_same", tq[true] == tq[false], [tq[true].slice(0, 2), tq[false].slice(0, 2)])
	XTianqiWeakAffix.test_entries.clear()


# ---- O-679：技能表缓存项进只读窗口 ----
func _entry_held() -> void:
	var s := _xiyou_state()
	var a := s.actor(s.party[0])
	var res := {}
	for on in [true, false]:
		_switches(on)
		a.skills()  # 先暖一次跨调用缓存
		var b0 := XActor.skill_ids_builds
		XActor.read_begin()
		var vals := []
		for i in 3:
			vals.append(TAGS.map(func(t): return a.passive_values(t)))
			vals.append([a.mhp, a.mmp, a.max_tp(), a.atk, a.mat, a.agi])
		XActor.read_end()
		var in_window := XActor.skill_ids_builds - b0
		b0 = XActor.skill_ids_builds
		XActor.batch_begin()
		var batch_vals := [TAGS.map(func(t): return a.passive_values(t)), TAGS.map(func(t): return a.passive_values(t)), a.mhp]
		XActor.batch_end()
		res[on] = [vals, batch_vals, in_window, XActor.skill_ids_builds - b0]
	check("held.same_values", res[true][0] == res[false][0] and res[true][1] == res[false][1], [res[true][0][0], res[false][0][0]])
	check("held.window_builds_once", int(res[true][2]) <= 1 and int(res[false][2]) > int(res[true][2]), [res[true][2], res[false][2]])
	check("held.batch_fewer", int(res[true][3]) < int(res[false][3]), [res[true][3], res[false][3]])
	# 窗口里有写入（学会新被动）：窗口换代后要重算，结果与关掉时相同
	var after := {}
	for on in [true, false]:
		_switches(on)
		var s2 := _xiyou_state()
		var b := s2.actor(s2.party[1])
		XActor.read_begin()
		var v0 := b.passive_values("passivePBST")
		XActor.read_end()
		var extra := _passives(80).filter(func(id): return not b.skill_ids.has(id))
		b.learn_skill(int(extra[0]))
		XActor.read_begin()
		var v1 := b.passive_values("passivePBST")
		var ids := b.skills().map(func(x): return int(x.id))
		XActor.read_end()
		after[on] = [v0, v1, ids.has(int(extra[0]))]
	check("held.write_invalidates", after[true] == after[false] and bool(after[true][2]), [after[true], after[false]])


# ---- O-680：侧栏实时读数 ----
func _side_status() -> void:
	var s := _xiyou_state()
	var a := s.actor(s.party[0])
	var res := {}
	for on in [true, false]:
		_switches(on)
		var row := XSideStatus.new()
		row.actor = a
		row.view = {}
		add_child(row)
		a.skills()
		var b0 := XActor.skill_ids_builds
		var v := row._v()
		res[on] = [v, XActor.skill_ids_builds - b0]
		row.queue_free()
	check("side.same_values", JSON.stringify(res[true][0]) == JSON.stringify(res[false][0]), [res[true][0], res[false][0]])
	check("side.fewer_builds", int(res[true][1]) < int(res[false][1]), [res[true][1], res[false][1]])
	# 有快照时照旧读快照
	_switches(true)
	var row2 := XSideStatus.new()
	row2.actor = a
	row2.view = {"hp": 7.0, "mhp": 9.0}
	check("side.view_first", row2._v().hp == 7.0 and row2._v().mhp == 9.0)
	row2.free()


# ---- 整场：西游档、天启篇各一场，开关两态日志相同；开着带全程比对 ----
func _battles() -> void:
	for kind in ["xiyou", "tianqi"]:
		var make: Callable = _xiyou_state if kind == "xiyou" else _tianqi_state
		var troop := 2
		_switches(false)
		var off := _battle(make, troop)
		XTianqiWeakAffix.test_entries.clear()
		_switches(true)
		var verify0 := XActor.READ_VERIFY
		XActor.READ_VERIFY = true
		XActor.read_mismatches.clear()
		var b0 := XActor.skill_ids_builds
		var on := _battle(make, troop)
		var on_builds := XActor.skill_ids_builds - b0
		XActor.READ_VERIFY = verify0
		XTianqiWeakAffix.test_entries.clear()
		check(kind + ".battle_same", on.sig == off.sig and int(on.acts) > 0, [on, off])
		check(kind + ".verify_clean", XActor.read_mismatches.is_empty(), XActor.read_mismatches.slice(0, 3))
		print("T572 %s acts=%d ids_builds_on=%d" % [kind, int(on.acts), on_builds])
