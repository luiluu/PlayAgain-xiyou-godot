extends Node
## 先制／偷袭（XPreempt，BattleManager.onEncounter）对照 tests/fixtures/preempt_oracle.json（mv_oracle/preempt_probe.cjs，75 例）：
## ① 先制率／偷袭率公式（敏捷对比、队伍能力 2／3、passivePREE／passiveASUP、倒下与后备成员、夹值）；
## ② 两次掷骰（总是各取一次、互斥、严格小于）；③ 开战第一回合的行动顺序（偷袭只排敌人、先制只排我方、「下个回合」仍是全员）与开场文字；
## ④ 先制逃跑必成功（不掷随机数）、endTurn 清标志。参照只量公式与结构，没有概率采样。
const FIXTURE := "res://tests/fixtures/preempt_oracle.json"
var results := []


## 按给定序列循环取值的随机流（同 xiyou_confusion）：每次取 1 个
class SeqStream extends XRandomStream:
	var seq: Array = [0.5]
	var pos := 0
	func _next() -> float:
		var v := float(seq[pos % seq.size()])
		pos += 1
		draws += 1
		return v
	func next_float(_reason: String, _event_key := "") -> float:
		return _next()
	func next_uint(_reason: String, _event_key := "") -> int:
		return floori(_next() * 4294967296.0)
	func next_index_mod(n: int, _reason: String, _event_key := "") -> int:
		return floori(n * _next()) if n > 0 else 0
	func next_int_inclusive(lo: int, hi: int, _reason: String, _event_key := "") -> int:
		return lo + floori((hi - lo + 1) * _next())


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail).left(600))


func _ready() -> void:
	_run.call_deferred()


## cfg：party 名册、skills {角色: [技能]}、armors {角色: [护甲号]}（队伍能力 2／3）、dead [角色]、troop
func _battle(cfg: Dictionary) -> XBattleLogic:
	var s := XState.new_game_blank()
	XState.current = s
	s.switches[2494] = true
	s.actor_max_level = 99
	var party: Array = cfg.get("party", [1, 8, 9, 10])
	for m in party:
		s.add_actor(int(m))
	s.battle_slots = [1, 8, 9, 10, 0]
	for id in party:
		var a: XActor = s.actor(int(id))
		a.change_level(60)
		a.skill_ids.clear()
		for sk in cfg.get("skills", {}).get(int(id), cfg.get("skills", {}).get(str(id), [])):
			a.learn_skill(int(sk))
		for armor in cfg.get("armors", {}).get(int(id), []):
			var item := XGear.template("armor", int(armor))
			a.equips[a.equip_slots().find(int(item.etypeId))] = item
		a.refresh_passive()
		a.recover_all()
	for id in cfg.get("dead", []):
		s.actor(int(id)).hp = 0.0
	var l := XBattleLogic.new()
	var rand := XBattleRandom.create("0000000000000042")
	rand.rule = SeqStream.new()
	rand.rule.domain = "rule"
	l.setup(int(cfg.get("troop", 3)), s, rand)
	return l


func _stream(l: XBattleLogic, seq: Array) -> SeqStream:
	var r: SeqStream = l.random.rule
	r.seq = seq
	r.pos = 0
	r.draws = 0
	return r


## 参照用例号 → 配置
func _rate_cfg(id: String) -> Dictionary:
	var sk := {"rate.skill.preStack": {1: [1110, 1113]}, "rate.skill.preTwoActors": {1: [1110], 8: [1113]}, "rate.skill.pre100plus": {1: [7849, 1110]},
		"rate.skill.asupStack": {1: [1053], 8: [1084]}, "rate.skill.preAndAsup": {1: [2782]}, "rate.skill.preWithAbility3": {1: [1110]},
		"rate.skill.asupWithBaseLowAgi": {1: [1053]}, "rate.skill.asupWithAbility2": {1: [1053]}, "rate.skill.reserveMember": {11: [7849, 1053]},
		"rate.skill.deadMember": {8: [7849]}, "rate.gap.troopHigh.pre": {1: [1110]}, "rate.gap.troopHigh.asup": {1: [1053]}}
	# asupWithAbility2：参照给 8 号穿 163；8 号在重制里穿不上头部的 163，队伍能力看任一出战成员，换 10 号一样
	var ab := {"rate.ability.cancelSurprise": {1: [163]}, "rate.ability.raisePre": {1: [316]}, "rate.ability.both": {1: [3796]}, "rate.ability.onOneActor": {10: [316]},
		"rate.skill.preWithAbility3": {8: [316]}, "rate.skill.asupWithAbility2": {10: [163]}, "rate.gap.troopHigh.ab3": {1: [316]}, "rate.gap.troopHigh.ab2": {1: [163]}}
	var cfg := {"skills": sk.get(id, {}), "armors": ab.get(id, {})}
	if id.begins_with("rate.skill.") and ["1110", "7849", "2782", "5937", "8017", "1053", "1084", "1897"].has(id.get_slice(".", 2)):
		cfg.skills = {1: [int(id.get_slice(".", 2))]}
	if id.begins_with("rate.troop."):
		cfg.troop = int(id.get_slice(".", 2))
	if id == "rate.skill.reserveMember" or id.begins_with("rate.reserveAgi"):
		cfg.party = [1, 8, 9, 10, 11]
	if id == "rate.skill.deadMember":
		cfg.dead = [8]
	return cfg


func _keys(l: XBattleLogic, list: Array) -> Array:
	var out := []
	for b in list:
		out.append("A%d" % b.actor_id if b is XActor else "E%d" % l.enemies.find(b))
	out.sort()
	return out


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_preempt"
	XConfig.path_override = XSave.dir().path_join("options.json")
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var cases := {}
	for c in oracle.cases:
		cases[c.id] = c.observed
	check("fixture_cases_75", cases.size() == 75, cases.size())
	# ① 公式：敏捷两边用参照的值（压住两边能力值取整的差异），能力、被动来自真实角色数据
	for id: String in cases:
		if not id.begins_with("rate."):
			continue
		var o: Dictionary = cases[id]
		var l := _battle(_rate_cfg(id))
		var r := XPreempt.rates(l.state, l.enemies, float(o.partyAgi), float(o.troopAgi))
		check(id + ".pre", is_equal_approx(float(r.pre), float(o.ratePreemptive)) and float(r.pre) == float(o.ratePreemptive), [r.pre, o.ratePreemptive])
		check(id + ".sur", float(r.sur) == float(o.rateSurprise), [r.sur, o.rateSurprise])
		check(id + ".ability", [l.state.party_ability(2), l.state.party_ability(3)] == [o.ability["2"], o.ability["3"]], [o.ability])
	# 本机算出的敏捷与参照一致时（默认队伍对 3 号敌群），不压敏捷再比一次
	var base := _battle({})
	var rb := XPreempt.rates(base.state, base.enemies)
	check("rate.base_native", float(rb.pre) == 0.05 and float(rb.sur) == 0.03, rb)
	var big := _battle({"troop": 165})
	var rbig := XPreempt.rates(big.state, big.enemies)
	check("rate.troop165_native_troop_faster", float(rbig.pre) == 0.03 and float(rbig.sur) == 0.05, rbig)
	# ② 掷骰
	for id: String in cases:
		if not id.begins_with("roll."):
			continue
		var o: Dictionary = cases[id]
		var s: Array = oracle.cases.filter(func(c): return c.id == id)[0].setup.s
		var got := XPreempt.roll(float(s[0]), float(s[1]), {"pre": o.ratePre, "sur": o.rateSur})
		check(id + ".flags", got == [o.preemptive, o.surprise], [got, o])
		check(id + ".draws_two", int(o.draws) == 2, o.draws)
	for id: String in ["roll.preYes", "roll.preYesSurYes", "roll.sur", "roll.neither", "roll.preEdge", "roll.surEdge", "roll.zero", "roll.one"]:
		var s: Array = oracle.cases.filter(func(c): return c.id == id)[0].setup.s
		var l := _battle({})
		var stream := _stream(l, s)
		l.roll_encounter()
		check(id + ".logic", [l.preemptive, l.surprise] == [cases[id].preemptive, cases[id].surprise] and stream.draws == 2, [l.preemptive, l.surprise, stream.draws])
		check(id + ".encounter_flag", l.encounter)
	# ③ 开战第一回合
	for flag in ["none", "pre", "sur"]:
		for variant in ["", ".bigTroop", ".deadMember"]:
			var id: String = "flow." + flag + variant
			if not cases.has(id):
				continue
			var o: Dictionary = cases[id]
			var cfg := {"troop": 824} if variant == ".bigTroop" else ({"dead": [8]} if variant == ".deadMember" else {})
			var l := _battle(cfg)
			l.preemptive = flag == "pre"
			l.surprise = flag == "sur"
			l.start_turn()
			var subject := l.next_subject()
			var now := l.current_order.duplicate()
			now.append(subject)
			var want: Array = (o.current as Array).duplicate()
			want.append(o.subject)
			want.sort()
			check(id + ".current", _keys(l, now) == want, [_keys(l, now), want])
			check(id + ".next", _keys(l, l.next_order) == _sorted(o.next), [_keys(l, l.next_order), o.next])
			check(id + ".message", (XPreempt.start_text(l) if flag != "none" else "") == (str(o.messages[0]) if not (o.messages as Array).is_empty() else ""), [XPreempt.start_text(l), o.messages])
	# ④ 逃跑、endTurn
	for flag in ["none", "pre", "sur"]:
		for rnd in [0.05, 0.99]:
			var id: String = "escape.%s.r%s" % [flag, rnd]
			var l := _battle({})
			l.preemptive = flag == "pre"
			l.surprise = flag == "sur"
			l._escape_ratio = 0.1
			var stream := _stream(l, [rnd])
			var ok := l.try_escape()
			check(id + ".escaped", ok == bool(cases[id].escaped), [ok, cases[id].escaped])
			check(id + ".draws", stream.draws == (0 if flag == "pre" else 1), stream.draws)
	for flag in ["pre", "sur"]:
		var l := _battle({})
		l.preemptive = flag == "pre"
		l.surprise = flag == "sur"
		l.start_turn()
		l.end_turn()
		check("endTurn." + flag, [l.preemptive, l.surprise] == cases["endTurn." + flag].after, [l.preemptive, l.surprise])
	# 非随机遇敌（事件战斗）两个标志都是 false，且不掷
	var ev := _battle({})
	check("event_battle_no_flags", [ev.preemptive, ev.surprise, ev.encounter] == [false, false, false])
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


func _sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b
