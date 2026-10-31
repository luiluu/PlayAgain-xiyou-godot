extends Node
## 米拉 168 解放·黑龙与黑龙形态（XMira 第二期：meets／cost／pay／pay_hp／liberate／resists／blocks_debuff／after_apply／end_turn／turn_end／
## end_battle）：与 mv_oracle/mira_battle_probe.cjs 的冻结 v0.28 参照（generated/oracle/mira_battle.json）逐例比。
## - meets.*：各进阶／等级／形态下技能能不能用（含技能同步后的已学列表）；
## - cost.*：进阶 1／2 时主动技 MP／TP 费用（禁忌 ×0.75）；
## - act.*：敌群 3（每只生命加 1e12）、随机数全取 0.5 的真实行动：逐段比目标与伤害，再比行动后生命、MP、TP、状态、减益、劫火累计、
##   各敌人状态，跑一次回合结束后比各人生命变化（劫火追加、不灭龙血回血、中毒）。act.liberate.end.debuff 原版抛错（O-123），
##   重制默认清掉减益，另以 DEBUFF_FIX 关掉核对其余部分与原版一致；
## - immune.*：黑龙形态有无终焉时附加名单状态与减益；incoming.*：敌人普通攻击（攻击加 1e6）对米拉的伤害（不灭龙血 ×0.8）；
## - end：战斗结束删 2592／2597～2599。
## 原版参照的 BattleManager.setup 不走 startBattle，没有开战预热：比技能条件前清掉重制开战设的预热（10151 <Warmup: 2>）。
const ORACLE := "oracle/mira_battle.json"
const BIG_HP := 1e12
var results := []
var _ratios := []
var _incoming_values := {}


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 20:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


class HalfStream extends XRandomStream:
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return 0.5 if kind == "float" else 2147483648


## 同参照 battle()：新局、开挑战开关 2494、米拉进阶 rank、队伍 [168, 1] 各 level 级、技能同步后忘掉 drop；
## 敌群 3 每只生命加 1e12；规则流全取 0.5
func _battle(setup: Dictionary) -> Array:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.set_switch(2494, true)
	s.actor_max_level = 99
	s.party.clear()
	s.battle_slots.clear()
	s.actor_advance[XMira.ACTOR] = int(setup.rank)
	for id in [XMira.ACTOR, 1]:
		var b := s.actor(id)
		b.change_level_mv(int(setup.level))
	var a := s.actor(XMira.ACTOR)
	XSkillProgression.sync(a)
	for id in setup.get("drop", []):
		a.skill_ids.erase(int(id))
	s.add_actor(XMira.ACTOR)
	s.add_actor(1)
	a.refresh_passive()
	var rand := XBattleRandom.create("0000000000000168")
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(3, s, rand)
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += BIG_HP
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
		b.warmups.clear()
	a.tp = a.max_tp()
	return [logic, a]


func _key(logic: XBattleLogic, b) -> String:
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)


func _ints(v: Array) -> Array:
	return v.map(func(x): return int(x))


func _sorted(ids: Array) -> Array:
	var out := ids.duplicate()
	out.sort()
	return out


func _debuffs(b: XBattler) -> Array:
	return range(8).filter(func(i): return b.buffs[i] < 0)


func _flame(logic: XBattleLogic) -> Array:
	return XMira._flame.map(func(e): return {"target": _key(logic, e[0]), "amount": float(e[1])})


func _same_flame(got: Array, want: Array) -> bool:
	return got.size() == want.size() and range(got.size()).all(func(i): return got[i].target == str(want[i].target) and is_equal_approx(got[i].amount, float(want[i].amount)))


func _meets(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _battle(c.setup)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	if c.setup.dragon:
		logic._state_add(a, XMira.DRAGON)
	a.mp = a.mmp
	a.tp = a.max_tp()
	check(c.id + ".members", logic.actors.map(func(b): return b.actor_id) == _ints(o.members), [logic.actors.map(func(b): return b.actor_id), o.members])
	var skills := _sorted(a.skill_ids.filter(func(i): return i >= 10140 and i <= 10167))
	check(c.id + ".skills", skills == _ints(o.skills), [skills, o.skills])
	check(c.id + ".battler", XCostumes.battler_name(XState.current, a) == str(o.battlerName))
	for k in o.keys():
		if str(k).begins_with("s1"):
			var got := logic.can_use(a, XDB.rec("Skills", str(k).substr(1).to_int()))
			check(c.id + "." + k, got == bool(o[k]), [got, o[k]])
	XMira.end_battle(XState.current)


## MP 按 XCharacterHelp._cost 比：它在 skill_cost 之前补上 YEP_SkillCore 的 <MP Cost: x%>（最大 MP 百分比），战斗里的 skill_cost
## 目前不补（与米拉无关的既有缺口，见交付单「发现」）；TP 直接比 skill_cost。
func _cost(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _battle(c.setup)
	for k in o.keys():
		var skill := XDB.rec("Skills", str(k).substr(1).to_int())
		var got := [XCharacterHelp._cost(r[1], skill, "MP"), int(r[0].skill_cost(r[1], skill).tp)]
		check(c.id + "." + k, got == _ints(o[k]), [got, o[k]])


func _act(c: Dictionary, debuff_fix := true) -> void:
	var o: Dictionary = c.observed
	var setup: Dictionary = c.setup
	XMira.DEBUFF_FIX = debuff_fix
	var r := _battle(setup)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	logic.start_turn()
	if setup.get("dragon", false):
		logic._state_add(a, XMira.DRAGON)
	for id in setup.get("preStates", []):
		logic._state_add(a, int(id))
	for pid in setup.get("preDebuffs", []):
		logic.sequence_buff(a, int(pid), true, false, 3)
	a.mp = a.mmp
	a.tp = a.max_tp()
	if setup.has("hpRate"):
		a.hp = floorf(a.mhp * float(setup.hpRate))
	if setup.has("hp"):
		a.hp = float(setup.hp)
	var hp0 := a.hp
	var logs := logic.act(a, XDB.rec("Skills", int(setup.skill)), logic.enemies[0])
	var hits := logs.filter(func(l): return l.get("type") == "hit" and l.get("user") == a and l.get("target") is XEnemy)
	# 伤害绝对值另有与本期无关的固定差：55 级专属角色技能在干净目标上重制比原版低约 3.9%（黄泉期二已记，米拉同一比值 0.96079），
	# 留给伤害链核查；这里比各段目标，劫火与回合结束追加按重制自己的伤害核对，比值只打印
	var got := hits.map(func(l): return _key(logic, l.target))
	var values := hits.map(func(l): return floorf(float(l.hp)))
	var want: Array = o.log.map(func(l): return str(l.target))
	check(c.id + ".targets", got == want, [got, want])
	if not values.is_empty() and float(o.log[0].value) > 0.0:
		_ratios.append(values[0] / float(o.log[0].value))
	var tag: String = c.id + ("" if debuff_fix else ".original")
	if o.has("threw"):
		# 原版在解放收尾抛错：已加黑龙形态、减益未清。重制默认清掉（O-123），关掉时与原版留下的一样
		check(tag + ".states", _sorted(a.state_ids) == _ints(o.states), [a.state_ids, o.states])
		check(tag + ".debuffs", _debuffs(a) == ([] if debuff_fix else _ints(o.debuffs)), [_debuffs(a), o.debuffs])
		XMira.DEBUFF_FIX = true
		logic.end_battle(0)
		return
	check(c.id + ".hp", [hp0, a.hp] == [float(o.hpBefore), float(o.hpAfterAction)], [[hp0, a.hp], [o.hpBefore, o.hpAfterAction]])
	# MP 技能的费用另有百分比缺口（见 _cost），只比 TP 技能的 MP
	var percent := str(XDB.rec("Skills", int(setup.skill)).get("note", "")).contains("<MP Cost:")
	check(c.id + ".mp_tp", (percent or a.mp == float(o.mp)) and a.tp == float(o.tp), [[a.mp, a.tp], [o.mp, o.tp]])
	check(c.id + ".states", _sorted(a.state_ids) == _ints(o.states), [a.state_ids, o.states])
	check(c.id + ".debuffs", _debuffs(a) == _ints(o.debuffs), [_debuffs(a), o.debuffs])
	# 劫火累计＝本行动对各敌人命中的生命伤害（参照里两者也相等）；有没有累计、累计到谁与参照一致
	var own_flame := []
	for k in got.size():
		if not o.flame.is_empty():
			own_flame.append({"target": got[k], "amount": values[k]})
	check(c.id + ".flame", _same_flame(_flame(logic), own_flame) and o.flame.size() == own_flame.size(), [_flame(logic), o.flame])
	var flame_now := _flame(logic)
	var foe_states := logic.enemies.map(func(e): return _sorted(e.state_ids))
	check(c.id + ".foe_states", foe_states == o.foeStates.map(func(x): return _ints(x)), [foe_states, o.foeStates])
	var who := [a] + logic.enemies
	var before := who.map(func(b): return b.hp)
	logic.end_turn()
	var delta := range(who.size()).map(func(i): return who[i].hp - before[i])
	# 米拉自己的变化（不灭龙血、中毒）逐个比；敌人的劫火追加：参照为 0 的重制也为 0，否则＝−floor(累计×30%)（累计用重制自己的）
	var want_delta: Array = o.turnEndDelta.map(func(v): return float(v))
	var foe_ok := range(logic.enemies.size()).all(func(i):
		var f = flame_now.filter(func(e): return e.target == "e%d" % i)
		var expect := 0.0 if want_delta[i + 1] == 0.0 or f.is_empty() else -floorf(float(f[0].amount) * 0.3)
		return delta[i + 1] == expect and (want_delta[i + 1] == 0.0) == (expect == 0.0))
	check(c.id + ".turn_end", delta[0] == want_delta[0] and foe_ok, [delta, o.turnEndDelta])
	check(c.id + ".flame_after", _same_flame(_flame(logic), o.flameAfterTurn), [_flame(logic), o.flameAfterTurn])
	XMira.DEBUFF_FIX = true
	logic.end_battle(0)


func _immune(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _battle(c.setup)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	logic._state_add(a, XMira.DRAGON)
	var resist := {"s4": XMira.resists(a, 4), "s6": XMira.resists(a, 6), "s5": XMira.resists(a, 5)}
	for k in resist:
		check(c.id + ".resist_" + k, resist[k] == bool(o.resist[k]))
	logic._state_add(a, 4)
	logic._state_add(a, 5)
	logic.sequence_buff(a, 2, true, false, 3)
	check(c.id + ".states", _sorted(a.state_ids) == _ints(o.states), [a.state_ids, o.states])
	check(c.id + ".debuffs", _debuffs(a) == _ints(o.debuffs), [_debuffs(a), o.debuffs])
	logic.end_battle(0)


func _incoming(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _battle(c.setup)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	if c.setup.dragon:
		logic._state_add(a, XMira.DRAGON)
	var e: XEnemy = logic.enemies[0]
	e.zq_ref.p[2] += float(c.setup.foeAtkPlus)
	e.param_mark_dirty()
	e.param_refresh()
	a.param_mark_dirty()
	a.param_refresh()
	var value := logic._damage_value(e, e.attack_skill(), a, false)
	check(c.id + ".def", [a.def, a.mdf] == [float(o.def), float(o.mdf)], [[a.def, a.mdf], [o.def, o.mdf]])
	# 敌人攻击加值在两边的放大倍率不同（重制直接改敌人基础值，原版 _paramPlus 另吃敌人能力值倍率），绝对值差固定 ×1.5；
	# 比各例对人形（incoming.human.b）的比值：黑龙 10154 ×0.8、黑龙没学 10154 只差防御
	_incoming_values[c.id] = [value, float(o.value)]
	logic.end_battle(0)


func _run() -> void:
	var ref = XDB.load_json(ORACLE)
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	var seen := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var kind := str(c.id).get_slice(".", 0)
		seen[kind] = true
		match kind:
			"module":
				check("module", int(c.observed.dragon) == XMira.DRAGON and _ints(c.observed.immune) == XMira.END_OF_ALL_IMMUNE)
			"meets":
				_meets(c)
			"cost":
				_cost(c)
			"act":
				_act(c)
				if c.observed.has("threw"):
					_act(c, false)
			"immune":
				_immune(c)
			"incoming":
				_incoming(c)
			"end":
				var r := _battle(c.setup)
				for id in XMira.BATTLE_STATES:
					r[0]._state_add(r[1], id)
				check("end.before", _sorted(r[1].state_ids) == _ints(c.observed.before), r[1].state_ids)
				XMira._flame.append([r[0].enemies[0], 1.0])
				r[0].end_battle(0)
				check("end.after", _sorted(r[1].state_ids) == _ints(c.observed.after) and XMira._flame.is_empty(), r[1].state_ids)
	check("covers_all", seen.keys().size() == 7, seen.keys())
	print("伤害 重制/原版 比值：", _ratios)
	var base: Array = _incoming_values.get("incoming.human.b", [0.0, 0.0])
	for k in _incoming_values:
		var v: Array = _incoming_values[k]
		check(k + ".ratio", base[0] > 0.0 and absf(v[0] / base[0] - v[1] / base[1]) < 1e-6, [v, base])
	check("incoming.cases", _incoming_values.size() == 3, _incoming_values.keys())
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_mira_battle", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
