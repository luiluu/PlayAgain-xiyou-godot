extends Node
## 种族祝福的能力值与战斗效果（XRaceBattle）：逐例对照 mv_oracle/race_battle_probe.cjs（generated/oracle/race_battle.json）。
## - params.*：角色 1（练习剑）30 级，七族 × 1／4／7 阶与无祝福，比种族数据、种族技能、q、八项 param／paramPlus、
##   技能 8／9／10／72／101 的 MP／TP 消耗、武器本体值。
## - battle.*：角色 1＋8 出战，敌群 2／6（敌人生命加 1e12），随机数全取 0.5（同参照 Math.random）；每步按回合号行动（行动前 TP 100、
##   法力回满），回合末直接调 XRaceBattle.round_end；比各敌人生命与毒鸡汤状态、角色生命／法力／TP、队友生命、角色的本场种族数据、提示。
## - power.*：角色 1／8 30 级各族战力（XPower.actor 强制重算）：总分、三项、爆发／持续／有效生命／辅助、行动表、未计入。
## - supply：依次打各层 Boss 的种族补给（XDungeon.race_supply）；learn：学会种族技能改种族（XRace.learn）；
##   poisonInfo：选敌帮助的毒鸡汤说明（XRaceBattle.poison_info）。
## - needsSelection：妖族全体伤害技能也要选敌（XRaceBattle.needs_prey_selection＋原本的单体 1／7／9）；battle.demon_manual：手选猎物。
## - blood_command（只在重制）：魔族指令「血契：关／开」与切换。
## - human_toast（只在重制）：九九六插队提示在排行动顺序时暂存、下一个行动补出。
const ORACLE := "oracle/race_battle.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(900))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _close(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if absf(float(a[i]) - float(b[i])) > maxf(1e-6, absf(float(b[i])) * 1e-9):
			return false
	return true


func _run() -> void:
	# 战力开关读设置：用测试自己的设置文件（同 xiyou_power），不读本机玩家设置
	XSave.dir_override = "user://test_xiyou_race_battle"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XConfig.set_flag("codexPowerEnabled", true)
	var ref = XDB.load_json(ORACLE)
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		get_tree().quit.call_deferred(1)
		return
	for c in ref.cases:
		if not check(str(c.id) + ".oracle_clean", (c.errors as Array).is_empty(), c.errors):
			continue
		if str(c.id).begins_with("params."):
			_params(c)
		elif str(c.id).begins_with("power."):
			_power(c)
		elif str(c.id) == "supply":
			_supply(c)
		elif str(c.id) == "learn":
			_learn(c)
		elif str(c.id) == "poisonInfo":
			_poison_info(c)
		elif str(c.id) == "needsSelection":
			_needs_selection(c)
		else:
			_battle(c)
	_human_toast()
	_blood_command()
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


static func _set_race(s: XState, a: XActor, race: int, rank: int, blood := false) -> void:
	XRace.data(s, a)
	s.race.actors[str(a.actor_id)] = {"race": race, "rank": rank, "free": race < 0, "blood": blood, "legacy": []}
	XRace.sync(s, a)


static func _race_skills(a: XActor) -> Array:
	return a.skill_ids.filter(func(id): return not XRace.skill_info(id).is_empty())


func _params(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var st: Dictionary = c.setup
	var s := XState.new_game_blank()
	s.actor_max_level = 99
	XState.current = s
	var a := s.actor(1)
	a.change_level_mv(int(st.level))
	_set_race(s, a, int(st.race), int(st.rank))
	a.param_mark_dirty()
	a.refresh_passive()
	var tag := str(c.id)
	check(tag + ".race", _race_skills(a) == (o.raceSkills as Array).map(func(v): return int(v)) and is_equal_approx(XRaceBattle.rate_of(a), float(o.rate)),
		[_race_skills(a), XRaceBattle.rate_of(a), o.raceSkills, o.rate])
	var got := range(8).map(func(i): return a.param(i))
	check(tag + ".param", _close(got, o.param), [got, o.param])
	got = range(8).map(func(i): return a.param_plus(i))
	check(tag + ".paramPlus", _close(got, o.paramPlus), [got, o.paramPlus])
	var w = a.equips[0] if a.equips.size() > 0 and a.equips[0] is Dictionary else {}
	got = range(8).map(func(i): return XRaceBattle.weapon_body(w, i))
	check(tag + ".weaponBody", _close(got, o.weaponBody), [got, o.weaponBody])
	var logic := XBattleLogic.new()
	var mp := []
	var tp := []
	for id in st.skills:
		var cost := logic.skill_cost(a, XDB.rec("Skills", int(id)))
		mp.append(cost.mp)
		tp.append(cost.tp)
	check(tag + ".cost", _close(mp, o.mpCost) and _close(tp, o.tpCost), [mp, tp, o.mpCost, o.tpCost])


class HalfStream extends XRandomStream:
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return 0.5 if kind == "float" else 2147483648


func _label(x, a, b, enemies: Array):
	if x == null:
		return null
	var i := enemies.find(x)
	if i >= 0:
		return "e%d" % i
	if x == a:
		return "a"
	if x == b:
		return "b"
	return "?"


func _race_state(logic, a, b, enemies: Array) -> Dictionary:
	var s: Dictionary = XRaceBattle.state(logic, a)
	var out := {}
	for k in ["godTurn", "bloodTurn", "capTurn", "gainTurn", "spendTurn", "echoTurn"]:
		out[k] = int(s[k])
	out.humanExtra = bool(s.humanExtra)
	for k in ["ghostPrevious", "ghostCurrent"]:
		out[k] = {"group": int(s[k].group), "turn": int(s[k].turn)} if s[k] != null else null
	out.counter = {"target": _label(s.counter.target, a, b, enemies), "until": int(s.counter.until)} if s.counter != null else null
	out.cap = {"spent": float(s.cap.spent)} if s.cap != null else null
	out.poison = (s.poison as Array).map(func(p): return {"target": _label(p.target, a, b, enemies), "id": int(p.id), "amount": snappedf(float(p.amount), 1e-6), "turn": int(p.turn)})
	out.lastPrey = _label(s.lastPrey, a, b, enemies)
	return out


static func _norm(v):
	if v is Dictionary:
		var o := {}
		for k in v:
			o[str(k)] = _norm(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is float or v is int:
		return snappedf(float(v), 1e-6)
	return v


func _battle(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var st: Dictionary = c.setup
	var s := XState.new_game_blank()
	s.actor_max_level = 99
	XState.current = s
	var a := s.actor(1)
	var b := s.actor(8)
	a.change_level_mv(30)
	b.change_level_mv(30)
	_set_race(s, a, int(st.race), int(st.rank), bool(st.get("blood", false)))
	s.party.clear()
	s.battle_slots.clear()
	s.add_actor(1)
	s.add_actor(8)
	var rand := XBattleRandom.create("0000000000000176")
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(int(st.troop), s, rand)
	var enemies: Array = logic.enemies
	for e in enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		p[2] += float(st.get("enemyAtkPlus", 0))
		e.zq_ref = {"p": p, "k": 1.0}
	for x in [a, b] + enemies:
		x.param_mark_dirty()
		x.param_refresh()
		x.recover_all()
	XRaceBattle.start(logic)  # 参照在调好敌人与回满之后才建本场数据（startBattle 的最后一步）
	var tag := str(c.id)
	check(tag + ".actor", a.atk == float(o.atk) and a.mat == float(o.mat) and a.mhp == float(o.mhp), [a.atk, a.mat, a.mhp, o.atk, o.mat, o.mhp])
	var ep := []
	for i in enemies.size():
		ep.append(_close(range(8).map(func(k): return enemies[i].param(k)), o.enemies[i].params))
	check(tag + ".enemies", ep.all(func(x): return x), [range(8).map(func(k): return enemies[0].param(k)), o.enemies[0].params])
	var poisons: Array = XRace.config().poisons
	for i in o.rows.size():
		var row: Dictionary = o.rows[i]
		var step := "%s.%d" % [tag, i]
		var toasts := []
		if row.has("roundEnd"):
			logic.turn = int(row.roundEnd)
			for l in XRaceBattle.round_end(logic):
				if l.type == "toast":
					toasts.append(l.text)
		elif row.has("set"):
			var set: Dictionary = row.set
			if set.has("blood"):
				s.race.actors["1"].blood = bool(set.blood)
			if set.has("enemyHpRate"):
				var e: XEnemy = enemies[int(set.get("enemy", 0))]
				e.hp = floorf(e.mhp * float(set.enemyHpRate))
			if set.has("allyHpRate"):
				b.hp = floorf(b.mhp * float(set.allyHpRate))
			if set.has("kill"):
				var k: XEnemy = enemies[int(set.kill)]
				k.hp = 0.0
				k.refresh_resources()
			continue
		else:
			var sp: Dictionary = row.step
			logic.turn = int(sp.round)
			var user: XBattler = a
			var who := str(sp.get("user", "a"))
			if who == "b":
				user = b
			elif who.begins_with("e"):
				user = enemies[int(who.substr(1))]
			user.tp = 100.0
			user.mp = user.mmp
			var skill := XDB.rec("Skills", int(sp.skill))
			var ti := int(sp.get("target", 0))
			var target: XBattler
			if int(skill.scope) in [7, 8, 9, 10, 11]:
				target = (logic.actors if user is XActor else enemies)[ti]
			else:
				target = (enemies if user is XActor else logic.actors)[ti]
			if sp.has("prey"):
				XRaceBattle.set_manual_prey(logic, user, skill, enemies[int(sp.prey)])  # 选敌窗手选的猎物（onEnemyOk 包装）
			for l in logic.act(user, skill, target):
				if l.type == "toast":
					toasts.append(l.text)
		var hp := enemies.map(func(e): return e.hp)
		var want_hp: Array = (row.enemies as Array).map(func(e): return float(e.hp))
		check(step + ".enemy_hp", _close(hp, want_hp), [hp, want_hp, row.get("step")])
		var pz := enemies.map(func(e): return poisons.filter(func(id): return e.state_ids.has(int(id))).map(func(id): return int(id)))
		var want_pz: Array = (row.enemies as Array).map(func(e): return (e.poisons as Array).map(func(v): return int(v)))
		check(step + ".poisons", pz == want_pz, [pz, want_pz])
		check(step + ".actor", _close([a.hp, a.mp, b.hp], [row.a.hp, row.a.mp, row.b.hp]), [[a.hp, a.mp, b.hp], [row.a.hp, row.a.mp, row.b.hp]])
		check(step + ".tp", _close([a.tp], [row.a.tp]), [a.tp, row.a.tp])
		var rs = _norm(_race_state(logic, a, b, enemies))
		var want_rs = _norm(row.race)
		check(step + ".race_state", rs == want_rs, [rs, want_rs])
		check(step + ".toasts", toasts == row.toasts, [toasts, row.toasts])
	XState.current = null


func _power(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var st: Dictionary = c.setup
	XGear.force_roll = 0.5
	var s := XState.new_game_blank()
	s.actor_max_level = 99
	XState.current = s
	var a := s.actor(int(st.actor))
	a.change_level_mv(int(st.level))
	_set_race(s, a, int(st.race), int(st.rank), bool(st.blood))
	a.param_mark_dirty()
	a.refresh_passive()
	a.recover_all()
	var p := XPower.actor(a, true)
	var tag := str(c.id)
	check(tag + ".total", int(p.total) == int(o.total) and int(p.self) == int(o.self) and _close(p.parts, o.parts) and _close(p.selfParts, o.selfParts),
		[p.total, p.self, p.parts, p.selfParts, o.total, o.self, o.parts, o.selfParts])
	for k in ["full", "own"]:
		var e: Dictionary = p.evaluation if k == "full" else p.ownEvaluation
		var w: Dictionary = o[k]
		check(tag + "." + k, _close([e.burst, e.sustained, e.effectiveHp, e.auxiliary], [w.burst, w.sustained, w.effectiveHp, w.auxiliary]),
			[[e.burst, e.sustained, e.effectiveHp, e.auxiliary], [w.burst, w.sustained, w.effectiveHp, w.auxiliary]])
		var got: Array = e.schedule.map(func(x): return [int(x.turn), int(x.id), snappedf(float(x.damage), 1e-6)])
		var want: Array = (w.schedule as Array).map(func(x): return [int(x[0]), int(x[1]), snappedf(float(x[2]), 1e-6)])
		check(tag + "." + k + ".schedule", _norm(got) == _norm(want), [got.slice(0, 6), want.slice(0, 6)])
		var um: Array = e.coverage.unmodeled.map(func(u): return [int(u.id), str(u.name), str(u.reason)])
		var wm: Array = (w.unmodeled as Array).map(func(u): return [int(u[0]), str(u[1]), str(u[2])])
		check(tag + "." + k + ".unmodeled", um == wm, [um, wm])
	XState.current = null


func _supply(c: Dictionary) -> void:
	var s := XState.new_game_blank()
	XState.current = s
	s.race_supply = {"counts": {}, "first": {}}
	var stones: Array = XRace.config().stones
	for i in c.observed.rows.size():
		var row: Dictionary = c.observed.rows[i]
		if (c.setup.floors[i] as Array).size() > 2:  # 背包已满
			s.gain_item(int(stones[2]), 9999)
		XDungeon.battle = {"troop": 2, "floor": int(row.floor), "won": int(row.result) == 0, "orb": false, "supply": false}
		var text := XDungeon.race_supply(s)
		var tag := "supply.%d" % i
		check(tag + ".toast", ([text] if text != "" else []) == row.toasts, [text, row.toasts])
		# 重制建档时就补空 inbox（原版背包满才建），内容相同
		var sup: Dictionary = s.race_supply.duplicate(true)
		if sup.get("inbox", {}).is_empty():
			sup.erase("inbox")
		check(tag + ".supply", _norm(sup) == _norm(row.supply), [s.race_supply, row.supply])
		var got := stones.map(func(id): return s.item_count(int(id)))
		check(tag + ".stones", _close(got, row.stones), [got, row.stones])
	XDungeon.battle = {}
	XState.current = null


func _learn(c: Dictionary) -> void:
	var s := XState.new_game_blank()
	XState.current = s
	var a := s.actor(1)
	var sk: Array = XRace.config().skills
	var steps := {
		"set-human-3": func():
			s.race.actors["1"] = {"race": 2, "rank": 3, "free": false, "blood": false, "legacy": []}
			a.learn_skill(int(sk[2][2])),
		"same-up-6": func(): a.learn_skill(int(sk[2][5])),
		"same-down-2": func(): a.learn_skill(int(sk[2][1])),
		"other-ghost-7": func(): a.learn_skill(int(sk[4][6])),
		"nodata-spirit-4": func():
			s.race.actors.erase("1")
			a.learn_skill(int(sk[5][3])),
		"plain-8": func(): a.learn_skill(8),
	}
	for row in c.observed.rows:
		var tag := "learn." + str(row.tag)
		if steps.has(str(row.tag)):
			steps[str(row.tag)].call()
		var d = s.race.actors.get("1", null)
		check(tag, _norm(d) == _norm(row.race) and _race_skills(a) == (row.raceSkills as Array).map(func(v): return int(v)),
			[d, _race_skills(a), row.race, row.raceSkills])
	check("learn.plain", a.skill_ids.has(8) == bool(c.observed.plain))
	XState.current = null


func _setup_battle(st: Dictionary) -> Dictionary:
	var s := XState.new_game_blank()
	s.actor_max_level = 99
	XState.current = s
	var a := s.actor(1)
	var b := s.actor(8)
	a.change_level_mv(30)
	b.change_level_mv(30)
	_set_race(s, a, int(st.race), int(st.rank), bool(st.get("blood", false)))
	s.party.clear()
	s.battle_slots.clear()
	s.add_actor(1)
	s.add_actor(8)
	var rand := XBattleRandom.create("0000000000000176")
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(int(st.troop), s, rand)
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		p[2] += float(st.get("enemyAtkPlus", 0))
		e.zq_ref = {"p": p, "k": 1.0}
	for x in [a, b] + logic.enemies:
		x.param_mark_dirty()
		x.param_refresh()
		x.recover_all()
	XRaceBattle.start(logic)
	return {"s": s, "a": a, "b": b, "logic": logic, "enemies": logic.enemies}


func _poison_info(c: Dictionary) -> void:
	var ctx := _setup_battle(c.setup)
	var logic: XBattleLogic = ctx.logic
	var enemies: Array = ctx.enemies
	var info := func(): return enemies.map(func(e): return XRaceBattle.poison_info(logic, e))
	var rows := []
	logic.turn = 1
	rows.append(info.call())
	logic.act(ctx.a, XDB.rec("Skills", 3), enemies[0])
	rows.append(info.call())
	ctx.s.race.actors["8"] = {"race": 2, "rank": 4, "free": false, "blood": false, "legacy": []}
	XRace.sync(ctx.s, ctx.b)
	logic.act(ctx.b, XDB.rec("Skills", 3), enemies[0])
	rows.append(info.call())
	logic.act(ctx.a, XDB.rec("Skills", 3), enemies[1])
	rows.append(info.call())
	logic.turn = 2
	rows.append(info.call())
	for i in rows.size():
		check("poisonInfo.%d" % i, rows[i] == c.observed.rows[i], [rows[i], c.observed.rows[i]])
	XState.current = null


## 九九六：排行动顺序（_make_action_orders 不带提示列表）时中了就暂存，下一个行动根开始时补出，只补一次
func _human_toast() -> void:
	var ctx := _setup_battle({"race": 2, "rank": 7, "troop": 2})
	var logic: XBattleLogic = ctx.logic
	logic.turn = 1
	var s: Dictionary = XRaceBattle.state(logic, ctx.a)
	s.humanTurn = 1
	s.humanExtra = true
	var order := [ctx.a, ctx.b]
	XRaceBattle.insert_human(logic, order)
	check("human_toast.order", order == [ctx.a, ctx.a, ctx.b], order)
	var first := logic.act(ctx.a, XDB.rec("Skills", 3), ctx.enemies[0]).filter(func(l): return l.type == "toast").map(func(l): return l.text)
	var second := logic.act(ctx.a, XDB.rec("Skills", 3), ctx.enemies[0]).filter(func(l): return l.type == "toast").map(func(l): return l.text)
	var want := str(ctx.a.display_name()) + "九九六：额外行动"
	check("human_toast.flush", first.count(want) == 1 and not second.has(want), [first, second])
	XState.current = null


func _needs_selection(c: Dictionary) -> void:
	var s := XState.new_game_blank()
	XState.current = s
	var a := s.actor(1)
	for race in c.observed.keys():
		_set_race(s, a, int(race), 7)
		for row in c.observed[race]:
			var sk := XDB.rec("Skills", int(row[0]))
			var got := int(sk.scope) in [1, 7, 9] or XRaceBattle.needs_prey_selection(a, sk)
			check("needsSelection.%s.%d" % [race, int(row[0])], got == bool(row[3]), [got, row])
	XState.current = null


## 魔族战斗指令（原版截图 race_blood_cmd_off／on：逃跑之后一行「血契：关」，确定后变「血契：开」）
func _blood_command() -> void:
	var s := XState.new_game_blank()
	XState.current = s
	var a := s.actor(1)
	_set_race(s, a, 3, 7)
	check("blood_command.off", XRaceBattle.blood_command_text(a) == "血契：关", XRaceBattle.blood_command_text(a))
	XRace.toggle_blood(s, a)
	check("blood_command.on", XRaceBattle.blood_command_text(a) == "血契：开" and bool(XRace.data(s, a).blood), XRaceBattle.blood_command_text(a))
	_set_race(s, a, 1, 7)
	check("blood_command.other_race", XRaceBattle.blood_command_text(a) == "")
	XState.current = null
