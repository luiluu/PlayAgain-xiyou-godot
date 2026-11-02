extends Node
## 【cc·白龙_13·未经审查】178 哈基米的守誓巨龙试炼与进阶小项（XCat「守誓巨龙试炼」节，installImportedBalanceRuntime 第 247～263、118、122 行）：
## 照参照 cat_trial_probe（tests/fixtures/cat_trial_oracle.json）——条件不够不换队、够时只留 178、开战回满、巨龙 12 回合出招、
## 蓄息日志、数据库原值参数、试炼中挡 22 个难度状态、还原与首胜给石（第二次不给、输了留 1 血）、速剑多一次行动、178 在队号角不能用；
## 再走一遍事件脚本 CodexCat.startTrial(this)（假宿主记开战敌群与还原后的提示）。
const FIXTURE := "res://tests/fixtures/cat_trial_oracle.json"
var checks := 0
var failures: Array = []
var obs := {}


class FakeHost extends Node:
	var battles := []
	var toasts := []
	var party_during := []
	var result := 0
	func start_battle(troop: int, can_escape: bool, can_lose: bool) -> int:
		battles.append([troop, can_escape, can_lose])
		party_during = XState.current.party.duplicate()
		await get_tree().process_frame
		return result
	func toast(text: String) -> void:
		toasts.append(text)
	func refresh_party_sprites() -> void:
		pass
	var refreshed := []  # 每次刷新事件时的队伍
	func refresh_events() -> void:
		refreshed.append(XState.current.party.duplicate())


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		print("FAIL ", tag, " ", JSON.stringify(detail).left(400))


func ints(a) -> Array:
	return (a as Array).map(func(v): return int(v))


## 参照的新游戏：队伍 1、8、9、10，招 178（练习剑），设等级；sword=false 卸下武器
func fresh(level := 35, sword := true, recruit := true) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.actor_max_level = 99
	if recruit:
		XCat.recruit(s)
	var a := s.actor(XCat.ACTOR)
	a.change_level_mv(level)
	if not sword:
		a.equips[0] = {}
	a.refresh_passive()
	return s


func _ready() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("oracle", ref.cases.size() == 12)
	for c in ref.cases:
		obs[str(c.id)] = c.observed
	_run.call_deferred()


func _run() -> void:
	var ids: Dictionary = obs.ids
	check("ids", int(ids.troop) == XCat.TROOP and int(ids.enemy) == XCat.DRAGON and int(ids.stone) == XCat.STONE and int(ids.horn) == XCat.HORN \
		and ints(ids.skills) == XCat.DRAGON_SKILLS.filter(func(v): return v != 0) and ints(ids.difficulty) == XCat.TRIAL_DIFFICULTY_STATES, ids)
	# ① 条件
	for k in [["level34", 34, true, true], ["nosword", 35, false, true], ["absent", 35, true, false]]:
		var o: Dictionary = obs["start.fail." + k[0]]
		var s := fresh(k[1], k[2], k[3])
		var before := s.party.duplicate()
		var ok := XCat.start_trial(s)
		check("fail.%s" % k[0], ok == bool(o.ok) and s.party == before and s.party == ints(o.party.actors) and not XCat.in_trial(s), [ok, s.party, o])
		check("fail.%s.text" % k[0], XCat.TRIAL_NOT_READY == str(o.notes[0]))
	var o: Dictionary = obs["start.ok"]
	var s := fresh()
	s.add_actor(5)
	s.add_actor(9)
	check("ok.before", s.party == ints(o.before.actors) and s.battle_slots == ints(o.before.members), [s.party, s.battle_slots, o.before])
	check("ok.start", XCat.start_trial(s) == bool(o.ok))
	check("ok.party", s.party == ints(o.party.actors) and s.battle_slots == ints(o.party.members), [s.party, s.battle_slots, o.party])
	var d: Dictionary = s.flags.get("_codexCatTrial", {})
	check("ok.saved", ints(d.get("actors", [])) == ints(o.trial.actors) and ints(d.get("slots", [])) == ints(o.trial.members), [d, o.trial])
	# ② 开战回满（setup 里跑 startBattle）
	s = fresh()
	XCat.start_trial(s)
	var a := s.actor(XCat.ACTOR)
	a.hp = 1.0
	a.tp = 0.0
	var logic := XBattleLogic.new()
	logic.setup(XCat.TROOP, s)
	o = obs["start.recover"]
	check("recover", a.hp == a.mhp and a.tp == a.max_tp() and a.tp == float(o.tp) and logic.actors == [a], [a.hp, a.mhp, a.tp, o])
	check("troop", logic.enemies.size() == 1 and int(logic.enemies[0].enemy_id) == XCat.DRAGON)
	var e: XEnemy = logic.enemies[0]
	# ③ 出招：经 decide（不掷敌人行动随机数）
	for row in obs.actions.out:
		logic.turn = int(row.turn)
		var r := logic.decide(e)
		var id := 0 if r[0] == null else int(r[0].id)
		check("action.t%d" % int(row.turn), id == int(row.skill) and (id == 0 or r[1] == a), [r, row])
	logic.turn = 2
	var logs := logic.act(e, XDB.rec("Skills", XCat.SKILL_CHARGE), a)
	var texts := logs.filter(func(l): return str(l.type) == "battle_text").map(func(l): return str(l.text))
	check("charge.text", texts == obs["charge.text"].charge.texts, [texts, obs["charge.text"]])
	logic.turn = 1
	logs = logic.act(e, XDB.rec("Skills", 10447), a)
	check("claw.text", logs.filter(func(l): return str(l.type) == "battle_text").is_empty())
	# ④ 参数与状态
	o = obs["dragon.param"]
	check("param", range(8).map(func(i): return e.param(i)) == (o.param as Array).map(func(v): return float(v)), [range(8).map(func(i): return e.param(i)), o.param])
	o = obs["dragon.states"]
	var in_trial := []
	for id in o.ids:
		e.add_state(int(id))
		in_trial.append(1 if e.is_state_affected(int(id)) else 0)
	for id in o.ids:
		e.remove_state(int(id))
	XCat.restore_trial(s, -1)
	var after := []
	for id in XCat.TRIAL_DIFFICULTY_STATES:
		e.add_state(id)
		after.append(1 if e.is_state_affected(id) else 0)
	check("states.trial", in_trial == ints(o.inTrial), [in_trial, o.inTrial])
	check("states.after", after == ints(o.after).slice(0, XCat.TRIAL_DIFFICULTY_STATES.size()), [after, o.after])
	# ⑤ 还原
	s = fresh()
	s.add_actor(5)
	var before := [s.party.duplicate(), s.battle_slots.duplicate()]
	a = s.actor(XCat.ACTOR)
	var k := 0
	for row in obs.restore:
		XCat.start_trial(s)
		a.hp = 0.0 if bool(row.dead) else a.mhp
		var note := XCat.restore_trial(s, int(row.result))
		var notes := [] if note == "" else [note]
		check("restore.%d" % k, s.item_count(XCat.STONE) == int(row.stone) and bool(s.flags.get("_codexCatTrialWon", false)) == bool(row.won) \
			and notes == Array(row.notes) and [s.party, s.battle_slots] == before and not XCat.in_trial(s), [s.item_count(XCat.STONE), notes, s.party, row])
		check("restore.%d.hp" % k, (a.hp == 1.0 and a.is_alive()) if bool(row.dead) else a.hp == a.mhp, a.hp)
		k += 1
	# 存档里留着试炼（读档时 XSave 调 restore_trial(-1)）：存档往返后还原
	XCat.start_trial(s)
	var loaded := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	XCat.restore_trial(loaded, -1)
	check("load.restore", [loaded.party, loaded.battle_slots] == before and not XCat.in_trial(loaded), [loaded.party, loaded.battle_slots])
	XState.current = s
	XCat.restore_trial(s, -1)
	# ⑥ 进阶小项
	o = obs.extras
	s = fresh()
	a = s.actor(XCat.ACTOR)
	var horn := XDB.rec("Items", XCat.HORN)
	check("horn.in", XCat.horn_blocked(s, horn) == not bool(o.hornIn))
	logic = XBattleLogic.new()
	logic.setup(1, s)
	var i := 0
	for row in o.times:
		s.actor_advance[XCat.ACTOR] = int(row.adv)
		for pair in [[XCat.SKILL_ADVANCED, int(row.adv)], [XCat.SKILL_SPEED, int(row.speed)]]:
			if pair[1]:
				a.learn_skill(pair[0])
			else:
				a.forget_skill(pair[0])
		check("times.%d" % i, logic.make_action_times(a) == int(row.n), [row, logic.make_action_times(a)])
		i += 1
	s.remove_actor(XCat.ACTOR)
	check("horn.out", XCat.horn_blocked(s, horn) == not bool(o.hornOut))
	# 终技品质 10 不做：七档品质里 9、10 同档（名字色、边框、品质行一样）
	check("holy.grade", XQuality.grade_of(9) == XQuality.grade_of(10) and XQuality.window_skin(9) == XQuality.window_skin(10) and str(o.advanced.desc[0][0]) == "品质：" + str(XQuality.config().names[XQuality.grade_of(10)]))
	# 事件脚本：条件够时换队开战（敌群 1999、不能逃、可以输），打完还原、首胜提示
	s = fresh()
	s.add_actor(5)
	before = [s.party.duplicate(), s.battle_slots.duplicate()]
	var host := FakeHost.new()
	add_child(host)
	var interp := MVInterpreter.new(host, 4, 1, [], 0)
	var unknown: Array = await MVScript.run("CodexCat.startTrial(this);", interp)
	check("script.battle", unknown.is_empty() and host.battles == [[XCat.TROOP, false, true]] and host.party_during == [XCat.ACTOR], [unknown, host.battles, host.party_during])
	check("script.restore", [s.party, s.battle_slots] == before and host.toasts == [XCat.TRIAL_WON] and s.item_count(XCat.STONE) == 1, [s.party, host.toasts])
	check("script.refresh", not host.refreshed.is_empty() and host.refreshed.back() == s.party, [host.refreshed, s.party])  # 审查第 21 期 P3③：还原后再刷事件
	host.result = 2
	await MVScript.run("CodexCat.startTrial(this);", interp)
	check("script.lose", host.toasts.back() == XCat.TRIAL_LOST and s.item_count(XCat.STONE) == 1 and [s.party, s.battle_slots] == before, host.toasts)
	s.actor(XCat.ACTOR).change_level_mv(34)
	await MVScript.run("CodexCat.startTrial(this);", interp)
	check("script.not_ready", host.battles.size() == 2 and host.toasts.back() == XCat.TRIAL_NOT_READY, [host.battles, host.toasts])
	host.queue_free()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_cat_trial", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
