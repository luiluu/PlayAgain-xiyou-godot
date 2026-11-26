extends Node
## T544 量数探针（只量不改）：_costs 里各环节单次耗时，按被动数分档。跑法同 t544_skill_lag_probe.gd。
func timed(f: Callable, n := 20) -> float:
	var t := Time.get_ticks_usec()
	for i in n:
		f.call()
	return float(Time.get_ticks_usec() - t) / n / 1000.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XSave.dir_override = "user://t544_probe"
	var pool := []
	var rows: Array = XDB.table("Skills")
	for i in range(1, rows.size()):
		var r = rows[i]
		if r is Dictionary and int(r.get("stypeId", 0)) == 4 and str(r.get("name", "")) != "" and not XTianqiSkills.is_shell(i):
			pool.append(i)
	for n in [20, 400]:
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		var a := s.actor(1)
		var picked := []
		var k := 0
		while picked.size() < n:
			var id: int = pool[(k * 7919) % pool.size()]
			k += 1
			if not picked.has(id):
				picked.append(id)
		for id in picked:
			a.learn_skill(id)
		a.change_level(80)
		a.refresh_passive()
		a.recover_all()
		var logic := XBattleLogic.new()
		logic.state = s
		var sk := XDB.rec("Skills", picked[0])
		var r := {"n": n}
		r.all_traits = timed(func(): a.all_traits())
		r.n_traits = a.all_traits().size()
		r.states = timed(func(): a.states())
		r.mmp = timed(func(): a.mmp)
		r.mhp = timed(func(): a.mhp)
		r.mcr = timed(func(): a.mcr)
		r.max_tp = timed(func(): a.max_tp())
		r.passive_cache = timed(func(): a.passive_cache())
		r.note_costs = timed(func(): XBattleLogic.note_costs(sk))
		r.skill_cost = timed(func(): logic.skill_cost(a, sk))
		r.hp_cost = timed(func(): XBattleLogic.skill_hp_cost(a, sk))
		r.item_rows = timed(func(): XBattleLogic.item_cost_rows(sk))
		r.mastery_cost = timed(func(): XSkillMastery.cost(a, sk, "mp", 10))
		r.consume_reduce = timed(func(): XBattleLogic.consume_reduce(a, sk))
		r.famine = timed(func(): XTianqiFamineAlien.cost(logic, a, sk, {"mp": 1, "tp": 1}, false))
		r.can_use = timed(func(): logic.can_use(a, sk))
		r.costs_row = timed(func(): XSkillScene.custom_cost_row(sk, 28))
		r.p_native = timed(func(): a.param_native(0))
		r.p_before_alien = timed(func(): a.param_before_alien(0))
		r.p_now = timed(func(): a._param_now(0))
		var v0 := a.param_native(0)
		r.w_pills = timed(func(): XPercentPills.param(a, 0, v0))
		r.w_modules = timed(func(): XActorModules.param(a, 0, v0))
		r.w_heartsteel = timed(func(): XHeartsteel.param(a, 0, v0))
		r.w_hubris = timed(func(): XHubris.param(a, 0, v0))
		r.w_cat = timed(func(): XCat.param(a, 0, v0))
		r.w_tqgear = timed(func(): XTianqiGear.param(a, 0, v0))
		r.w_yun = timed(func(): XYunshang.battle_param(a, 0, XYunshang.param(a, 0, v0)))
		r.w_growth_flat = timed(func(): XTianqiGrowth.param_flat(a, 0))
		r.w_alien = timed(func(): XAlienBattle.param(a, 0, v0))
		r.w_liuying = timed(func(): XLiuying.param(a, 0, v0))
		r.w_guyu = timed(func(): XGuyu.param(a, 0, v0))
		r.w_xuan = timed(func(): XXuanBattle.param(a, 0, v0))
		r.w_tusu = timed(func(): XTusu.param(a, 0, v0))
		r.w_race = timed(func(): XRaceBattle.param(a, 0, v0))
		r.w_famine = timed(func(): XTianqiFamineAlien.actor_param(a, 0, v0))
		r.w_horse = timed(func(): XTianqiHorsemen.actor_param(a, 0, v0))
		r.w_rewards = timed(func(): XTianqiRewards.actor_param(a, 0, v0))
		r.w_plague = timed(func(): XTianqiPlagueAlien.actor_param(a, 0, v0))
		r.w_unrace = timed(func(): XTianqiGrowth.unrace(a, 0, v0, v0))
		r.w_hubris_f = timed(func(): XHubris.formula_param(a, 0, v0))
		r.b_base = timed(func(): a.param_base(0))
		r.b_plus = timed(func(): a.param_plus(0))
		r.b_rate = timed(func(): a.param_rate(0))
		r.b_buff = timed(func(): a.param_buff_rate(0))
		r.b_state = timed(func(): a.param_state(0, 100.0))
		r.b_state_ids = a.state_ids.size()
		r.b_pi_sparam = timed(func(): a.traits_pi(23, 4))
		print("MICRO=" + JSON.stringify(r))
	get_tree().quit.call_deferred(0)
