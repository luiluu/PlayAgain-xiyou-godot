extends Node
## 战斗规则冒烟测试：普通难度、开局队伍（狗逍遥＋修＋罗琳＋美娜，含开局被动）
## 自动战斗打第一层小怪（敌群 2）应能获胜并拿到奖励；不读写任何存档。

var results: Array = []

func _ready() -> void:
	_run.call_deferred()

func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})

func _run() -> void:
	seed(12345)
	var s := XState.new_game(3, 1, [8, 9, 10])
	for a in s.members():
		# 原版开局（普通难度）实际所学：天道诅咒、难度适应、普通难度；开局可选的角色另有万众一心、SupperStar
		for sid in [6168, 5980, 5548] + ([2571, 2786] if a.actor_id <= 7 else []):
			a.learn_skill(sid)
		a.refresh_passive()
		a.recover_all()
	var logic := XBattleLogic.new()
	logic.auto = true
	logic.elite_roll = 100.0  # 不出神话，奖励按普通敌人核对
	logic.setup(2, s)
	_check("troop2_three_enemies", logic.enemies.size() == 3, logic.enemies.map(func(e): return e.display_name()))
	_check("battle_start_states", logic.actors.all(func(a): return a.is_state_affected(995) and a.is_state_affected(1691) and a.is_state_affected(1631)))
	# 宝宝难度被动 5561：StartPushState1629 给自己、StartAEPushState1055 给全体敌人（dsPassiveSkill 开战标签）
	var baby := XState.new_game(1, 1, [8])
	for a in baby.members():
		a.learn_skill(5561)
		a.refresh_passive()
	var logic1 := XBattleLogic.new()
	logic1.elite_roll = 100.0
	logic1.setup(2, baby)
	_check("start_ae_push_state", logic1.enemies.all(func(e): return e.is_state_affected(1055)) and logic1.actors.all(func(a): return a.is_state_affected(1629)))
	XState.current = s
	var hits := 0
	var turns := 0
	while not logic.is_won() and not logic.is_lost() and turns < 60:
		for l in logic.run_turn({}):
			if l.type == "hit" and not l.user.is_actor():
				pass
			elif l.type == "hit" and l.hp > 0:
				hits += 1
		turns += 1
	_check("troop2_won", logic.is_won(), {"turns": turns, "enemyHp": logic.enemies.map(func(e): return e.hp)})
	_check("reasonable_length", turns >= 2 and turns <= 30, turns)
	var r := logic.rewards()
	_check("rewards_exp_gold", r.exp == roundi(3 * 20 * 4.5) and r.gold > 0, r)
	var ups := logic.grant(r)
	logic.end_battle()
	_check("exp_granted", s.actor(1).exp_total > 0, s.actor(1).exp_total)
	_check("start_states_cleared_or_kept", true)
	var passed := results.filter(func(x): return x.passed).size()
	for x in results:
		if not x.passed:
			print("FAIL ", x.name, " ", JSON.stringify(x.detail))
	print("info: turns=%d playerHits=%d levelups=%s rewards=%s" % [turns, hits, str(ups.map(func(u): return [u.actor.display_name(), u.levels])), JSON.stringify(r)])
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
