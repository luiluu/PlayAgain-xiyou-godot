extends Node
## T546 战斗读数复量（不是回归测试，没有 .tscn，不进检查.sh）：
## 全队 99 级、各学 N 个被动，打敌群 2：量开战（setup）、每次行动（decide＋act）、收场；另量只读窗口外单读能力值。
## 同时记整场日志的 sha256，--xcall=0（关 XActor.SKILLS_XCALL＝修复前）与默认两态应完全相同。
## 跑法：复制进 01_Godot工程/tests/，临时建一个挂它的 .tscn，
##   godot --headless --audio-driver Dummy --path . res://tests/<临时>.tscn [-- --xcall=0 --tiers=20,120,400]；量完删掉复制件
var TIERS := [20, 120, 400]


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--xcall=0":
			XActor.SKILLS_XCALL = false
		if arg.begins_with("--tiers="):
			TIERS = Array(arg.substr(8).split(",")).map(func(x): return int(x))
	_run.call_deferred()


func timed(f: Callable, n := 20) -> float:
	var t := Time.get_ticks_usec()
	for i in n:
		f.call()
	return float(Time.get_ticks_usec() - t) / n / 1000.0


var _logic: XBattleLogic


## 日志转成可比的纯数据：对象（含字典键里的对象）一律换成 stable_id，不带实例号（实例号随分配次数变，不能进摘要）
func _plain(v):
	if v is Array:
		return v.map(func(x): return _plain(x))
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(_plain(k)) if k is Object else str(k)] = _plain(v[k])
		return out
	if v is Object:
		return str(_logic.stable_id(v)) if v is XBattler else str(v.get_class())
	return v


func _state(n: int, pool: Array) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.actor_max_level = 99
	s.random_master = XRandomStream.hex64(20261126)
	for id in s.party:
		var a := s.actor(id)
		a.change_level_mv(99)
		var picked := 0
		var k := id
		while picked < n:
			var sid: int = pool[(k * 7919) % pool.size()]
			k += 1
			if not a.skill_ids.has(sid):
				a.learn_skill(sid)
				picked += 1
		a.refresh_passive()
		a.recover_all()
	return s


func _run() -> void:
	XSave.dir_override = "user://t546_battle_probe"
	var pool := []
	var rows: Array = XDB.table("Skills")
	for i in range(1, rows.size()):
		var r = rows[i]
		if r is Dictionary and int(r.get("stypeId", 0)) == 4 and str(r.get("name", "")) != "" and not XTianqiSkills.is_shell(i):
			pool.append(i)
	for n in TIERS:
		var s := _state(n, pool)
		var a := s.actor(s.party[0])
		var row := {"n": n, "xcall": XActor.SKILLS_XCALL}
		# 只读窗口外单读（地图、菜单、事件条件里的读法）
		row.read_mmp_ms = timed(func(): a.mmp)
		row.read_param_base_ms = timed(func(): a.param_base(2))
		row.read_skills_ms = timed(func(): a.skills())
		# 每次新开一个只读窗口读一遍（战斗里每次计算各开各的窗口）
		row.window_read_ms = timed(func():
			XActor.read_begin()
			a.mmp
			a.mcr
			a.max_tp()
			a.param(2)
			XActor.read_end())
		var journal := []
		var logic := XBattleLogic.new()
		_logic = logic
		var t0 := Time.get_ticks_usec()
		logic.setup(2, s)
		row.setup_ms = float(Time.get_ticks_usec() - t0) / 1000.0
		for e in logic.enemies:
			e._rates[0] *= 1000
			e.recover_all()
		logic.auto = true
		var acts := 0
		var act_us := 0
		for round_index in 3:
			logic.start_turn()
			journal.append(_plain(logic.take_turn_start_logs()))
			var count := 0
			while count < 40:
				var u := logic.next_subject()
				if u == null:
					break
				count += 1
				var t1 := Time.get_ticks_usec()
				var cmd := logic.decide(u)
				var logs := logic.act(u, cmd[0], cmd[1])
				act_us += Time.get_ticks_usec() - t1
				acts += 1
				journal.append([logic.stable_id(u), int(cmd[0].id) if cmd[0] != null else 0, _plain(logs)])
			journal.append(_plain(logic.end_turn()))
			if logic.is_over():
				break
		var t2 := Time.get_ticks_usec()
		logic.end_battle(0)
		row.end_ms = float(Time.get_ticks_usec() - t2) / 1000.0
		row.acts = acts
		row.act_avg_ms = float(act_us) / max(1, acts) / 1000.0
		journal.append([logic.random.snapshot(), s.members().map(func(m): return [m.hp, m.mp, m.tp, m.state_ids.duplicate()])])
		row.sha = JSON.stringify(journal).sha256_text().left(16)
		row.builds = XActor.skills_xcall_builds
		row.hits = XActor.skills_xcall_hits
		print("BATTLE=" + JSON.stringify(row))
	print("DONE")
	get_tree().quit.call_deferred(0)
