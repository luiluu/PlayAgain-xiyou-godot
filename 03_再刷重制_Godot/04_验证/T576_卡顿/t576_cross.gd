extends Node
## T576 量数探针（不入库）：整场日志摘要，跨版本比（T574 头 vs 本单开关开／关）
const DORIA := 96
const CE_ZHULANG := 1222
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	XSave.dir_override = "user://t576_cross"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hold="):
			var sc = load("res://modes/xiyou/core/actor.gd")
			if sc.get("SKILLS_HOLD") != null:
				sc.set("SKILLS_HOLD", a.substr(7) == "1")
				print("HOLD ", sc.get("SKILLS_HOLD"))
			else:
				print("HOLD missing")
	var mk_tq := func() -> XState:
		var lineup := [21, 23, 3, 1, 2]
		var tq := XTianqi.start_new_game(3, "jianxian", lineup)
		XTianqi.take_pending()
		for id in lineup:
			XTianqi._joining = true
			tq.add_actor(int(id))
			XTianqi._joining = false
		tq.map_id = 4
		XState.current = tq
		tq.random_master = XRandomStream.hex64(20261176)
		for a in tq.members():
			a.change_level(60)
			a.refresh_passive()
			a.recover_all()
		return tq
	var verify := "--verify" in OS.get_cmdline_user_args()
	if verify:
		XActor.READ_VERIFY = true
		XActor.READ_VERIFY_FATAL = false
	var save := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--save="): save = a.substr(7)
	if save != "":
		var mk_p := func() -> XState:
			var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save))
			XSave._load_data(d, 1, JSON.stringify(d))
			var ps := XState.current
			ps.random_master = XRandomStream.hex64(20261127)
			ps.battle_serial = 0
			return ps
		var rounds := 15
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--rounds="): rounds = int(a.substr(9))
		var rp := _battle(mk_p, 454, rounds, 0)
		print("CROSS player454 sig=%s size=%d acts=%d won=%s" % [rp.sig, rp.size, rp.acts, str(rp.won)])
		if verify:
			var by := {}
			for m in XActor.read_mismatches:
				var k := "%s/%s" % [str(m[0]), str(m[1])]
				by[k] = by.get(k, 0) + 1
			print("VERIFY hits=%d mismatches=%d by=%s hold_hits=%d" % [XActor.read_hits, XActor.read_mismatches.size(), JSON.stringify(by), int(load("res://modes/xiyou/core/actor.gd").get("skills_hold_hits") if load("res://modes/xiyou/core/actor.gd").get("skills_hold_hits") != null else -1)])
		get_tree().quit(0)
		return
	for c in [["battle2", _new_state.bind(20261102), 2, 3, 0], ["battle70", _new_state.bind(20261170), 70, 3, 0], ["ce1222", _doria_state, 2, 2, CE_ZHULANG], ["tianqi", mk_tq, 2, 3, 0], ["battle454", _new_state.bind(20261127), 454, 4, 0]]:
		var r := _battle(c[1], c[2], c[3], c[4])
		print("CROSS %s sig=%s size=%d acts=%d won=%s" % [c[0], r.sig, r.size, r.acts, str(r.won)])
	get_tree().quit(0)

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



func _sig(l: XBattleLogic) -> String:
	var out := []
	for b in l.actors + l.enemies:
		out.append([l.stable_id(b), b.hp, b.mp, b.tp, b.state_ids.duplicate(), b.buffs.duplicate()])
	out.append(l.random.snapshot())
	out.append([l.is_won(), l.is_lost(), l.turn])
	return JSON.stringify(out)



func _doria_state() -> XState:
	var s := XState.new_game(3, 1, [8, 9])
	XState.current = s
	s.random_master = XRandomStream.hex64(20261127)
	s.set_switch(int(XItemMarks.SUPER_SWITCHES[0]), true)  # 开放超强者（高难度下没开放时 add_actor 会被拦、出战栏会被清）
	s.add_actor(DORIA)
	for id in s.party:
		var a := s.actor(id)
		a.change_level_mv(60)
		a.refresh_passive()
		a.recover_all()
	var d := s.actor(DORIA)
	if not d.skill_ids.has(8152):
		d.learn_skill(8152)
	return s


## 一个只带特性、不加技能、没有挂上／拿掉效果的状态（STATE_TRAITS）

func _new_state(seed_no: int) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.random_master = XRandomStream.hex64(seed_no)
	for a in s.members():
		a.change_level_mv(80)
		a.refresh_passive()
		a.recover_all()
	return s



func _battle(make: Callable, troop: int, rounds: int, reserve := 0) -> Dictionary:
	seed(20261127)
	var s: XState = make.call()
	var logic := XBattleLogic.new()
	logic.setup(troop, s, XBattleRandom.create("0000000000576576"))
	logic.auto = true
	var journal := []
	var builds := XActor.skill_ids_builds
	if reserve > 0:
		XBattleCommonEvent.reserve(logic, reserve, s.actor(DORIA))
		journal.append(_plain(logic.run_events(null), logic))
	var acts := 0
	for r in rounds:
		logic.start_turn()
		journal.append(_plain(logic.take_turn_start_logs(), logic))
		journal.append(_plain(logic.run_events(null), logic))
		var count := 0
		while count < 40 and not logic.is_over():
			var u := logic.next_subject()
			if u == null:
				break
			count += 1
			var cmd := logic.decide(u)
			journal.append([logic.stable_id(u), int(cmd[0].id) if cmd[0] != null else 0, _plain(logic.act(u, cmd[0], cmd[1]), logic)])
			journal.append(_plain(logic.run_events(u), logic))
			acts += 1
		if logic.is_over():
			break
		journal.append(_plain(logic.end_turn(), logic))
	journal.append(_sig(logic))
	var won := logic.is_won()
	logic.end_battle(0 if won else -1)
	journal.append([s.members().map(func(a): return [a.actor_id, a.level, a.hp, a.mp, a.tp, a.state_ids.duplicate(), a.exp_total]), s.gear.size()])
	var text := JSON.stringify(journal)
	XState.current = null
	return {"sig": text.sha256_text(), "size": text.length(), "acts": acts, "builds": XActor.skill_ids_builds - builds, "won": won}


## 两态各跑一遍（开着那遍带 READ_VERIFY：每次命中都现算比对）
