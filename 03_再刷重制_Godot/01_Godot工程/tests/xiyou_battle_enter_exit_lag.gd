extends Node
## 【cc·未经审查】进出战斗卡顿（Kyo 11-13 v0.01.08 反馈＋玩家存档：电脑开战停 4～5 秒、打完停约 6 秒）。
## 出战角色开战各挂二十来个状态，每加减一个状态就整套 refresh（查每件装备能不能穿、重建被动缓存、读三项上限），一场一百七十多次。
## 五个开关，开与关结果逐项相同：
## - XActor.SCAN_MEMO：备注正则扫描按（正则，备注）记结果，给副本；
## - XActor.PASSIVE_MEMO：装备、技能、状态的备注与标签都没变时用上次的被动缓存（给副本），变了就重建；
## - XActor.RELEASE_WINDOW：逐件判断能不能穿包进一个只读窗口；
## - XResourceContext.REFRESH_WINDOW：一次 refresh 包进一个只读窗口，值没变的 HP／MP／TP 不重写；
## - XSmartAI.CHOOSE_WINDOW：智能选招整段包进一个只读窗口。
## 整场对比：三回合自动战斗＋胜利收场，开关两态整份日志（每次行动的记录、画面读数、收场后的上限与被动缓存）相同；
## 开着全程比对（XActor.READ_VERIFY）零不一致。
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))


func _switches(on: bool) -> void:
	XActor.SCAN_MEMO = on
	XActor.PASSIVE_MEMO = on
	XActor.RELEASE_WINDOW = on
	XResourceContext.REFRESH_WINDOW = on
	XSmartAI.CHOOSE_WINDOW = on


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


## 四人 99 级，各自穿上能穿的装备（从武器、防具表里按固定次序挑），返回穿上的件数
var _equipped := 0

func _new_state() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.actor_max_level = 99
	s.random_master = XRandomStream.hex64(20261113)
	_equipped = 0
	for id in s.party:
		var a := s.actor(id)
		a.change_level_mv(99)
		for pick in [["weapon", 37], ["armor", 53], ["armor", 71], ["armor", 113], ["armor", 157], ["armor", 211]]:
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
					_equipped += 1
					break
		a.refresh_passive()
		a.recover_all()
	return s


## 带回合、会在战斗结束时解除的状态（开战挂上、收场拿掉，模拟装备给的开战状态）
func _battle_states(n: int) -> Array:
	var out := []
	for id in range(10, 4000):
		var r := XDB.rec("States", id)
		if r.is_empty() or int(r.get("restriction", 0)) != 0 or not bool(r.get("removeAtBattleEnd", false)):
			continue
		out.append(id)
		if out.size() >= n:
			break
	return out


func _actor_sig(a: XActor) -> Array:
	return [a.hp, a.mp, a.tp, a.mhp, a.mmp, a.max_tp(), a.state_ids.duplicate(), a.passive_cache().duplicate(true), a.equip_list().size()]


## 一场三回合自动战斗＋胜利收场：返回整份日志的摘要
func _battle(troop: int) -> Dictionary:
	var s := _new_state()
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	var ids := _battle_states(14)
	for e in logic.enemies:
		e._rates[0] *= 1000
		e.recover_all()
	for a in logic.actors:
		for id in ids:
			logic._state_add(a, id)
	logic.auto = true
	var journal := [_plain(logic.views(), logic), logic.actors.map(_actor_sig)]
	var out := {"acts": 0, "states": 0}
	for a in logic.actors:
		out.states += a.state_ids.size()
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
			var logs := logic.act(u, cmd[0], cmd[1])
			out.acts += 1
			journal.append([logic.stable_id(u), int(cmd[0].id) if cmd[0] != null else 0, _plain(logs, logic), _plain(logic.move_flags(), logic)])
		journal.append(_plain(logic.end_turn(), logic))
		if logic.is_over():
			break
	journal.append(logic.actors.map(_actor_sig))
	logic.end_battle(0)
	journal.append([logic.random.snapshot(), s.members().map(_actor_sig), s.gear.size()])
	out.sig = JSON.stringify(journal).sha256_text()
	out.size = JSON.stringify(journal).length()
	return out


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_battle_enter_exit_lag"
	XConfig.path_override = XSave.dir().path_join("options.json")
	_scan_rules()
	_passive_rules()
	_release_rules()
	_battles()
	_switches(true)
	XActor.READ_VERIFY = false
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _scan_rules() -> void:
	var note := "<passiveHarmRe3: 12.5>\n<DepassiveHarmRe2: +30%>\n<PushState0742: 20%>\n<SkillCriPushZj: 15%>\n<passiveHarmRe7: 4>"
	var patterns: Array = XActor.PASSIVE_SCAN_PATTERNS
	XActor.SCAN_MEMO = false
	var plain := patterns.map(func(p): return XActor._scan(note, p))
	XActor.SCAN_MEMO = true
	XActor._scan_memo.clear()
	var first := patterns.map(func(p): return XActor._scan(note, p))
	var second := patterns.map(func(p): return XActor._scan(note, p))
	check("scan_same", plain == first and plain == second and plain[0].size() == 2 and plain[7].size() == 1, plain)
	(second[0] as Array).append(["x", "y"])
	check("scan_gives_copy", XActor._scan(note, patterns[0]) == plain[0])
	check("scan_empty", XActor._scan("没有标签", patterns[0]) == [] and XActor._scan("", patterns[0]) == [])
	XActor._note_scan_memo.clear()
	var all_fresh := XActor._note_scans(note).duplicate(true)
	check("note_scans_same", all_fresh == plain and XActor._note_scans(note) == plain, all_fresh)
	XActor.SCAN_MEMO = false
	check("note_scans_rollback", XActor._note_scans(note) == plain and not is_same(XActor._note_scans(note), XActor._note_scans(note)))
	XActor.SCAN_MEMO = true
	check("note_scans_memo_hit", is_same(XActor._note_scans(note), XActor._note_scans(note)))


func _fresh_passive(a: XActor) -> Dictionary:
	var keep := XActor.PASSIVE_MEMO
	XActor.PASSIVE_MEMO = false
	a.refresh_passive()
	XActor.PASSIVE_MEMO = keep
	return a._passive_cache.duplicate(true)


func _passive_rules() -> void:
	_switches(true)
	var s := _new_state()
	check("fixture_equipped", _equipped >= 8, _equipped)
	var same := true
	for a in s.members():
		var fresh := _fresh_passive(a)
		a.refresh_passive()   # 第一次：记下
		var one: Dictionary = a._passive_cache
		a.refresh_passive()   # 第二次：命中
		same = same and one == fresh and a._passive_cache == fresh and not is_same(a._passive_cache, a._pm_base)
	check("passive_memo_same", same)
	var a: XActor = s.members()[0]
	# 给出去的是副本：改了不影响下一次
	a._passive_cache["globalHarmRi"] = 999.0
	a.refresh_passive()
	check("passive_memo_copy", a._passive_cache == _fresh_passive(a) and float(a._passive_cache.globalHarmRi) != 999.0)
	# 加状态、学技能、就地改装备备注与标签都重建
	var st := -1
	for id in range(10, 4000):
		if str(XDB.rec("States", id).get("note", "")).contains("<passiveHarmRi"):
			st = id
			break
	if st > 0:
		a.refresh_passive()
		var before: Dictionary = a._passive_cache.duplicate(true)
		a.state_ids.append(st)
		a.refresh_passive()
		check("passive_memo_state", a._passive_cache == _fresh_passive(a) and a._passive_cache != before, st)
		a.state_ids.erase(st)
	var gear: Dictionary = a.equip_list()[0]
	a.refresh_passive()
	var base: Dictionary = a._passive_cache.duplicate(true)
	gear["note"] = str(gear.get("note", "")) + "\n<passiveHarmRi:7%>"
	a.refresh_passive()
	check("passive_memo_note_edit", a._passive_cache == _fresh_passive(a) and float(a._passive_cache.globalHarmRi) > float(base.globalHarmRi), [a._passive_cache.globalHarmRi, base.globalHarmRi])
	var meta: Dictionary = gear.get("meta", {})
	meta["passiveIRUP"] = "5"
	gear["meta"] = meta
	a.refresh_passive()
	check("passive_memo_meta_edit", a._passive_cache == _fresh_passive(a) and float(a._passive_cache.itemRateUp) >= float(base.itemRateUp) + 5.0, a._passive_cache.itemRateUp)
	# 回退：不记
	XActor.PASSIVE_MEMO = false
	a._pm_base = {}
	a.refresh_passive()
	check("passive_memo_rollback", a._pm_base.is_empty())
	XActor.PASSIVE_MEMO = true


func _release_rules() -> void:
	var got := {}
	for on in [false, true]:
		_switches(on)
		var s := _new_state()
		var a: XActor = s.members()[0]
		var kept := a.equip_list().size()
		a.release_to_party()
		var unchanged := a.equip_list().size() == kept
		# 塞一件等级不够的：要被卸回背包
		var slot := -1
		for i in a.equips.size():
			if a.equips[i] != null:
				slot = i
				break
		var item: Dictionary = a.equips[slot]
		var meta: Dictionary = item.get("meta", {}).duplicate()
		meta["req_level"] = "999"
		item["meta"] = meta
		var bag := s.gear.size()
		a.release_to_party()
		got[on] = [unchanged, a.equips[slot] == null, s.gear.size() - bag, a.equip_list().size(), a._passive_cache.duplicate(true), XActor._read_depth]
	check("release_same", got[false] == got[true] and got[true][0] and got[true][1] and int(got[true][2]) == 1 and int(got[true][5]) == 0, [got[false].slice(0, 4), got[true].slice(0, 4)])


func _battles() -> void:
	for troop in [2, 70]:
		_switches(false)
		var off := _battle(troop)
		_switches(true)
		var on := _battle(troop)
		check("battle_same:%d" % troop, off.sig == on.sig and int(off.acts) >= 4 and int(off.states) >= 20 and int(off.size) > 2000, [off.sig, on.sig, off.acts, off.states, off.size])
		XActor.READ_VERIFY = true
		XActor.read_hits = 0
		XActor.read_mismatches.clear()
		var verified := _battle(troop)
		XActor.READ_VERIFY = false
		check("battle_verify:%d" % troop, XActor.read_mismatches.is_empty() and XActor.read_hits > 1000 and verified.sig == off.sig, [XActor.read_hits, XActor.read_mismatches.slice(0, 3)])
		check("window_closed:%d" % troop, XActor._read_depth == 0)
		for only in ["SCAN_MEMO", "PASSIVE_MEMO", "RELEASE_WINDOW", "REFRESH_WINDOW", "CHOOSE_WINDOW"]:
			_switches(false)
			match only:
				"SCAN_MEMO": XActor.SCAN_MEMO = true
				"PASSIVE_MEMO": XActor.PASSIVE_MEMO = true
				"RELEASE_WINDOW": XActor.RELEASE_WINDOW = true
				"REFRESH_WINDOW": XResourceContext.REFRESH_WINDOW = true
				"CHOOSE_WINDOW": XSmartAI.CHOOSE_WINDOW = true
			check("battle_only_%s:%d" % [only, troop], _battle(troop).sig == off.sig)
