extends Node
## 【cc·悟空·未经审查】108 奈叶共享击杀（XNanoha）：与 mv_oracle/nanoha_kill_probe.cjs 的参照（newsrc4 起新源 v0.62.12）
## （tests/fixtures/nanoha_kill_oracle.json，真实 Game_Action.apply／BattleManager.endAction）逐例比。
## - learn：新局奈叶 1 级就会并肩适应 10168、适应 5683；
## - kill.*：队伍 [1, 108]（或只有 1）各 10 级、敌群 2 三只（血量按例）、开挑战开关 2494（locked 不开，奈叶去替补）；
##   行动后比奈叶永久加成（生命、魔法）、适应累计次数、各敌死活、出战成员与两项技能：队友每杀一只走 CodexNanohaAdapt(0.5)（软上限前 +5／+15，
##   softcap 例从 3000 次起），打不死、奈叶不在队／阵亡／缺技能不给，
##   奈叶自己的击杀只由状态 1768 Conclude 给（不重复）；twice：已死的敌人第二次行动不再算。
const FIXTURE := "res://tests/fixtures/nanoha_kill_oracle.json"
const BIG_HP := 1e9
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 20:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _new_state() -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	return s


## 同参照 battle()：新局、开关 2494（locked 不开）、队伍 party 各 10 级、敌群 2，敌血 hp[i]；
## 参照不跑 startBattle，开战状态 1768／1708 这里去掉，conclude 例再加 1768
func _battle(setup: Dictionary) -> Array:
	var s := _new_state()
	s.switches[2494] = not bool(setup.get("locked", false))
	s.party.clear()
	s.battle_slots.clear()
	for id in setup.party:
		s.actor(int(id)).change_level_mv(10)
		s.add_actor(int(id))
	var n := s.actor(XNanoha.ACTOR)
	if setup.has("forget"):
		n.forget_skill(int(setup.forget))
	if setup.has("adapt"):
		s.flags[XNanoha.ADAPT_FLAG] = {str(XNanoha.ACTOR): float(setup.adapt)}  # 参照 n._codexNanohaAdapt
	var rand := XBattleRandom.create("0000000000000108")
	rand.rule = FixedMidStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(2, s, rand)
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
	for i in range(logic.enemies.size()):
		logic.enemies[i].hp = float(setup.hp[i])
	for sid in [1768, 1708]:
		n.remove_state(sid)
	if bool(setup.get("nanohaDead", false)):
		n.add_state(1)
	if bool(setup.get("conclude", false)):
		n.add_state(1768)
	return [logic, s, n]


func _snap(logic: XBattleLogic, s: XState, n: XActor) -> Dictionary:
	var row: Array = s.mv_param_plus.get(str(XNanoha.ACTOR), [0, 0])
	return {"members": s.battle_members().map(func(a): return a.actor_id), "plus": [float(row[0]), float(row[1])],
		"dead": logic.enemies.map(func(e): return e.is_dead()),
		"learned": [XNanoha.SHARED, XNanoha.ADAPT].map(func(id): return n.skill_ids.has(id)),
		"count": (s.flags.get(XNanoha.ADAPT_FLAG, {}) as Dictionary).get(str(XNanoha.ACTOR))}


func _same(a: Dictionary, o: Dictionary) -> bool:
	var ints := func(v): return (v as Array).map(func(x): return int(x))
	# plus 按浮点比（适应软上限后是小数）；count 是适应累计次数（参照 _codexNanohaAdapt，旧夹具没有这一项就不比）
	var plus_ok: bool = a.plus.size() == o.plus.size() and range(a.plus.size()).all(func(i): return is_equal_approx(float(a.plus[i]), float(o.plus[i])))
	var count_ok: bool = not o.has("count") or (o.count == null and a.count == null) \
		or (o.count != null and a.count != null and is_equal_approx(float(a.count), float(o.count)))
	return ints.call(a.members) == ints.call(o.members) and plus_ok and count_ok \
		and a.dead == o.dead and a.learned == o.learned


func _act(logic: XBattleLogic, s: XState, who: int, skill: int) -> void:
	logic.act(s.actor(who), XDB.rec("Skills", skill), logic.enemies[0])


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("oracle_present", ref is Dictionary and ref.has("cases") and ref.cases.size() == 14):
		return finish()
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		var o: Dictionary = c.observed
		if c.id == "learn":
			var n := _new_state().actor(XNanoha.ACTOR)
			var learned := [XNanoha.SHARED, XNanoha.ADAPT].map(func(id): return n.skill_ids.has(id))
			check("learn", learned == o.learned, [learned, o])
		elif c.id == "kill.mate.twice":
			var b := _battle(c.setup)
			var steps := []
			_act(b[0], b[1], 1, 1)
			steps.append(_snap(b[0], b[1], b[2]))
			_act(b[0], b[1], 1, 160)
			steps.append(_snap(b[0], b[1], b[2]))
			check(c.id, _same(steps[0], o.steps[0]) and _same(steps[1], o.steps[1]), [steps, o.steps])
		else:
			var b := _battle(c.setup)
			var before := _snap(b[0], b[1], b[2])
			_act(b[0], b[1], int(c.setup.user), int(c.setup.skill))
			var after := _snap(b[0], b[1], b[2])
			check(c.id + ".before", _same(before, o.before), [before, o.before])
			check(c.id + ".after", _same(after, o.after), [after, o.after])
	_field()
	_domain_live()
	_cast()
	_manual()
	_auto()
	# 本地断言：追击等 execute 之外的 apply 不记（目标表在 execute 结束时关闭）
	var b := _battle({"party": [1, 108], "hp": [1, BIG_HP, BIG_HP]})
	var logic: XBattleLogic = b[0]
	XNanoha.begin(logic)
	XNanoha.end_execute(logic)
	logic.apply(b[1].actor(1), XDB.rec("Skills", 1), logic.enemies[0])
	XNanoha.finish(logic, b[1].actor(1))
	check("local.closed_frame", _snap(logic, b[1], b[2]).plus == [0.0, 0.0], _snap(logic, b[1], b[2]))
	# 回退开关 O-287：ADAPT_V062＝false 回到 v0.28 固定 +10／+30，不计适应次数（AOE 杀两只＝+20／+60）
	XNanoha.ADAPT_V062 = false
	var rb := _battle({"party": [1, 108], "hp": [1, 1, BIG_HP]})
	_act(rb[0], rb[1], 1, 160)
	var rs := _snap(rb[0], rb[1], rb[2])
	XNanoha.ADAPT_V062 = true
	check("rollback.v028_fixed", _same_plus(rs.plus, [20.0, 60.0]) and rs.count == null, rs)
	finish()


func _same_plus(got: Array, want: Array) -> bool:
	return got.size() == want.size() and range(got.size()).all(func(i): return absf(float(got[i]) - float(want[i])) < 1e-6)


## nanoha2_oracle field.flow：真实开战后奈叶带 1708／1768／1774／1780；开战只预约 1320（领域 1774 的 battle 效果在被动状态之前跑过，
## 原版从不预约 2478）；奈叶行动开始预约 2481（身经百战防转换），队友行动、回合结束不预约（1780 的 action_end 2480 在 OTB 下不触发）
func _field() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/nanoha2_oracle.json"))
	if not check("field.oracle_present", ref is Dictionary and ref.cases.size() == 1 and ref.cases[0].errors.is_empty()):
		return
	var o: Array = ref.cases[0].observed.steps
	var s := _new_state()
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	for id in [1, 108]:
		s.actor(id).change_level_mv(10)
		s.add_actor(id)
	var rand := XBattleRandom.create("0000000000000108")
	rand.rule = FixedMidStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	XNanoha.DOMAIN_LIVE = false  # 对原版参照：领域不补跑
	logic.setup(2, s, rand)
	XNanoha.DOMAIN_LIVE = true
	var n := s.actor(108)
	var taken := func() -> Array:
		var id := XBattleCommonEvent.reserved(logic)
		XBattleCommonEvent.take(logic)
		return [] if id <= 0 else [id]
	var ints := func(v): return (v as Array).map(func(x): return int(x))
	var want: Array = ints.call(o[0].states)
	var states: Array = n.state_ids.filter(func(id): return want.has(int(id)))
	states.sort()
	check("field.startBattle", taken.call() == ints.call(o[0].reserved) and states == ints.call(o[0].states), [states, o[0]])
	logic.act(n, XDB.rec("Skills", 1), logic.enemies[0])
	check("field.nanoha.attack", taken.call() == ints.call(o[1].reserved), o[1])
	logic.act(s.actor(1), XDB.rec("Skills", 1), logic.enemies[0])
	check("field.mate.attack", taken.call() == ints.call(o[2].reserved), o[2])
	logic.end_turn()
	check("field.endTurn", taken.call() == ints.call(o[3].reserved), o[3])


## O-183 魔法领域做活：开战补跑领域开战块，1320 先跑、2478 排在其后；跑完事件后全队（含队友）带领域加成
## （1782／1784 照 CE2478 原样，1783 只给奈叶），变量 1121 起按奈叶等级算；DOMAIN_LIVE 关掉时同原版，只有 1320
func _domain_live() -> void:
	var atk := {}
	for live in [true, false]:
		var s := _new_state()
		s.switches[2494] = true
		s.party.clear()
		s.battle_slots.clear()
		for id in [1, 108]:
			s.actor(id).change_level_mv(10)
			s.add_actor(id)
		var rand := XBattleRandom.create("0000000000000108")
		rand.rule = FixedMidStream.new()
		rand.rule.domain = "rule"
		var logic := XBattleLogic.new()
		XNanoha.DOMAIN_LIVE = live
		XDeadContent.DOMAIN_ALL_MATK = false  # 这里照 CE2478 原样（魔攻只给奈叶）；全队见 _domain_all_matk
		XDeadContent.clear_cache()
		logic.setup(2, s, rand)
		XNanoha.DOMAIN_LIVE = true
		var tag := "domain.%s" % ("live" if live else "off")
		check(tag + ".has1774", s.actor(108).state_ids.has(XNanoha.DOMAIN_STATE), s.actor(108).state_ids)
		check(tag + ".first1320", XBattleCommonEvent.reserved(logic) == XBattleCommonEvent.START_EVENT, XBattleCommonEvent.reserved(logic))
		logic.troop_events()
		# CE2478 照原版：先全队去掉 1792～1799，再加 1792／1793／1794／1782／1784／1799／1798（全队）与 1783（只奈叶）
		var buffs := [1782, 1783, 1784, 1792, 1793, 1794, 1795, 1796, 1797, 1798, 1799]
		for id in [1, 108]:
			var a := s.actor(id)
			var have: Array = buffs.filter(func(x): return a.state_ids.has(x))
			var want: Array = ([1782, 1784, 1792, 1793, 1794, 1798, 1799] + ([1783] if id == 108 else [])) if live else []
			want.sort()
			check(tag + ".buffs.%d" % id, have == want, [have, want])
		check(tag + ".var1121", (int(s.variables.get(1121, 0)) > 0) == live, s.variables.get(1121))
		check(tag + ".drained", XBattleCommonEvent.reserved(logic) == 0, XBattleCommonEvent.reserved(logic))
		s.actor(1).param_mark_dirty()
		atk[live] = [s.actor(1).atk, s.actor(1).mhp]
	# 队友的物攻／血量真被加上（G_ShuXing 按层数×1%，层数＝变量 1123／1120 起）
	check("domain.mate_stronger", float(atk[true][0]) > float(atk[false][0]) and float(atk[true][1]) > float(atk[false][1]), atk)
	_domain_all_matk()


## O-185 魔法领域魔攻全队（XDeadContent.DOMAIN_ALL_MATK）：CE2478 的 1783 改给全队，队友也带魔攻加成
func _domain_all_matk() -> void:
	XDeadContent.DOMAIN_ALL_MATK = true
	XDeadContent.clear_cache()
	var s := _new_state()
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	for id in [1, 108]:
		s.actor(id).change_level_mv(10)
		s.add_actor(id)
	var rand := XBattleRandom.create("0000000000000108")
	rand.rule = FixedMidStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(2, s, rand)
	logic.troop_events()
	check("domain.all_matk", s.actor(1).state_ids.has(1783) and s.actor(108).state_ids.has(1783), [s.actor(1).state_ids, s.actor(108).state_ids])


## nanoha3_oracle cast.*：奈叶单人、敌群 2、最大 MP 加 mmp、当前 MP 设 mp 后放大招；比实扣 MP（⌊mp×比例⌋×mcr）、付费后 _costmp（⌊付前 MP×比例/2000⌋）、
## 各敌行动后血量与死活（每个目标 max(1, _costmp) 段同值伤害）；extreme 超 512 段走 ACS 快速结算（96 段弹字＋合并尾段）
func _cast() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/nanoha3_oracle.json"))
	if not check("cast.oracle_present", ref is Dictionary and ref.cases.size() == 41):
		return
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		var o: Dictionary = c.observed
		if c.id.begins_with("ai."):
			_ai(c)
			continue
		if c.id.begins_with("atk."):
			_atk(c)
			continue
		if c.id.begins_with("sched."):
			_sched(c)
			continue
		var b := _battle({"party": [108], "hp": o.hp0})
		var logic: XBattleLogic = b[0]
		var n: XActor = b[2]
		n.add_param(1, float(o.before.mmp) - n.mmp)  # 参照 _paramPlus[1]＝mmp（extreme 例 200 万）
		n.param_mark_dirty()
		n.param_refresh()
		n.mp = float(c.setup.mp)
		var skill := XDB.rec("Skills", int(c.setup.skill))
		var before := {"mp": n.mp, "mmp": n.mmp, "cost": logic.skill_cost(n, skill).mp}  # mmp 由上一行对齐
		check(c.id + ".before", int(before.mp) == int(o.before.mp) and int(before.mmp) == int(o.before.mmp) and int(before.cost) == int(o.before.cost), [before, o.before])
		var hp0: Array = logic.enemies.map(func(e): return e.hp)
		var logs := logic.act(n, skill, logic.enemies[0])
		check(c.id + ".mp", int(n.mp) == int(o.mpAfter) and int(n.get_meta("costmp", -1)) == int(o.get("costmpAfter", -1)),
			[n.mp, n.get_meta("costmp", -1), o.mpAfter, o.get("costmpAfter")])
		# 段数：参照每个目标掉血＝value×段数（value 取 applyPostDamageEval 收到的值），重制取日志本体＋extra；死活照比。
		# 单段伤害照比绝对值（参照探针关了五乘区，见 dmg1b 交付单）
		var want := {}
		var want_value := {}
		for p in o.post:
			want[int(p.t)] = int(round((float(o.hp0[int(p.t)]) - float(o.hp1[int(p.t)])) / float(p.value)))
			want_value[int(p.t)] = int(p.value)
		var got := {}
		var got_value := {}
		var pops := 0
		for l in logs:
			if l is Dictionary and l.has("target") and l.get("skill", {}).get("id", 0) == int(c.setup.skill):
				var i := logic.enemies.find(l.target)
				got_value[i] = int(l.hp)
				var extra: Array = l.get("extra", [])
				var hits := int(round((float(hp0[i]) - logic.enemies[i].hp) / float(l.hp))) if float(l.hp) > 0.0 else 0
				got[i] = hits
				pops += 1 + extra.size()
				check(c.id + ".same_value.%d" % i, extra.all(func(v): return float(v) == float(l.hp)), [l.hp, extra.slice(0, 3)])
		check(c.id + ".value", got_value == want_value, [got_value, want_value])
		var dead: Array = logic.enemies.map(func(e): return e.is_dead())
		if c.id.ends_with(".kill") or c.id.ends_with(".extreme"):
			check(c.id + ".hits", dead == o.dead, [dead, o.dead])
		else:
			check(c.id + ".hits", got == want and dead == o.dead, [got, want, dead, o.dead])
		check(c.id + ".popups", pops == int(o.pops), [pops, o.pops])


## nanoha3_oracle atk.*：同宿主别的角色（1、9 号）单人普攻 1 号敌，比单段伤害（dmg1b：关五乘区后不只奈叶一致）
func _atk(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var b := _battle({"party": [int(c.setup.actor)], "hp": o.hp1.map(func(_v): return BIG_HP)})
	var logic: XBattleLogic = b[0]
	var a := logic.actors[0] as XActor
	var hp0: float = logic.enemies[0].hp
	logic.act(a, XDB.rec("Skills", 1), logic.enemies[0])
	check(c.id + ".atk", int(a.atk) == int(o.atk) and int(logic.enemies[0].def) == int(o.def), [a.atk, logic.enemies[0].def, o.atk, o.def])
	check(c.id + ".damage", int(hp0 - logic.enemies[0].hp) == -int(o.gains[0].d), [hp0 - logic.enemies[0].hp, o.gains])


## nanoha3_oracle ai.*：智能 AI 选的技能（会 5692 时六档魔炮替掉 5703～5709，估伤按付费后 MP ×段数；不会 5692 照常）
func _ai(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var hp: Array = [BIG_HP, BIG_HP, BIG_HP] if not c.id.ends_with("lowfoe") else [5000, BIG_HP, BIG_HP]
	var b := _battle({"party": [108], "hp": hp})
	var n: XActor = b[2]
	n.add_param(1, 50000.0)
	n.param_mark_dirty()
	n.param_refresh()
	if bool(c.setup.get("noCannon", false)):
		n.forget_skill(5692)
	elif not n.skill_ids.has(5692):
		n.learn_skill(5692)
	n.mp = float(c.setup.mp)
	var keep := XSmartAI.o_seq_if_hits
	XSmartAI.o_seq_if_hits = false  # 原版对照：星光 5710 按 7 段估（O-待定-1 关）
	var best := XSmartAI.choose(b[0], n)
	XSmartAI.o_seq_if_hits = keep
	var id := int(best.get("skill", {}).get("id", 0))
	check(c.id, id == int(o.skill) and n.skill_ids.has(5692) == o.learned5692 and not n.has_meta("costmp"), [id, best.get("candidates"), o])


## nanoha3_oracle sched.*：挂机顺序表预定 5692 时只在六档魔炮里挑（Codex_SmartBattleAI makeAction），不能用或没学会算没预定；智能 AI 关着照表放 5692
func _sched(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var mate := bool(c.setup.get("mate", false))
	var b := _battle({"party": [108, 1] if mate else [108], "hp": c.setup.hp})
	var logic: XBattleLogic = b[0]
	var s: XState = b[1]
	var n: XActor = b[2]
	n.add_param(1, 50000.0)
	n.param_mark_dirty()
	n.param_refresh()
	if bool(c.setup.get("noCannon", false)):
		n.forget_skill(5692)
	elif not n.skill_ids.has(5692):
		n.learn_skill(5692)
	if mate:
		n.learn_skill(8)
		logic.actors[1].hp = 1.0
	n.mp = float(c.setup.mp)
	var was_smart := XConfig.smart_ai()
	XConfig._values.codexSmartAI = not bool(c.setup.get("smartOff", false))  # 不落盘
	logic.turn = 1
	var table := XHangUpAuto.data(s, "ActSkill")
	table.clear()
	if int(c.setup.id) > 0:
		table[n.display_name() + XHangUpAuto.three(1)] = int(c.setup.id)
	var keep := [XSmartAI.o_seq_if_hits, XNanoha.AUTO_CANNON]
	XSmartAI.o_seq_if_hits = false  # 原版对照（O-待定-1、O-待定-2 关）：智能 AI 关着照表放 5692 本身
	XNanoha.AUTO_CANNON = false
	var r := logic.auto_battle_action(n)
	XSmartAI.o_seq_if_hits = keep[0]
	XNanoha.AUTO_CANNON = keep[1]
	var id := int(r[0].get("id", 0))
	table.clear()
	XConfig._values.codexSmartAI = was_smart
	check(c.id, id == int(o.skill) and n.mp == float(o.mp), [id, r[1], o])
	var who: int = logic.actors.find(r[1]) if r[1] != null else -1
	if int(o.target) >= 1:  # 参照 target 是目标序号；全体／自动是 -1。这里只有治愈队友这一例带序号
		check(c.id + ".target", who == int(o.target), [who, o])


## 手动战斗：小魔炮 5692 的效果 44 预约 CE2483「魔炮选择」，102 六选一 → 339 强制奈叶放所选大招（目标 -2 上次目标）。
## 本地断言（通用事件流程，无原版逐例参照）：选第 i 项就强制放第 i 档，MP 先扣 5692 的 1 点、再扣 ⌊MP×比例⌋，_costmp 按付前 MP
func _manual() -> void:
	var ids := [5703, 5704, 5705, 5706, 5708, 5709]
	var rates := [0.3, 0.6, 0.9, 0.3, 0.6, 0.9]
	for i in ids.size():
		var b := _battle({"party": [108], "hp": [BIG_HP, BIG_HP, BIG_HP]})
		var logic: XBattleLogic = b[0]
		var n: XActor = b[2]
		XBattleCommonEvent.take(logic)  # 开战预约的 1320 不跑
		n.add_param(1, 50000.0)
		n.param_mark_dirty()
		n.param_refresh()
		n.mp = 23000.0
		var asked := []
		logic.message_responder = func(msg):
			asked.append(msg.get("choices", []).size())
			return i
		var logs := logic.act(n, XDB.rec("Skills", 5692), n)
		check("manual.%d.reserved" % ids[i], XBattleCommonEvent.reserved(logic) == 2483, XBattleCommonEvent.reserved(logic))
		logs.append_array(logic.run_events())
		var used := logs.filter(func(l): return l is Dictionary and l.has("target") and int(l.get("skill", {}).get("id", 0)) == ids[i])
		var mp1 := 23000.0 - 1.0
		var want_mp := mp1 - floorf(mp1 * rates[i])
		check("manual.%d" % ids[i], asked == [6] and not used.is_empty() and n.mp == want_mp
			and int(n.get_meta("costmp", -1)) == floori(mp1 * rates[i] / 2000.0) and logic.enemies.any(func(e): return e.hp < BIG_HP),
			[asked, used.size(), n.mp, want_mp, n.get_meta("costmp", -1), logic.common_event_skipped])


## 自动战斗／挂机放小魔炮（玩家 11-16 报：自动战斗只放星光，挂机按顺序也放不出小魔炮）。本地断言，西游档、天启篇各一遍：
## - auto.*.seq_hits：O-待定-1 开时星光 5710 没学魔力强化 5702 按 2 段估（原版 7 段），学了 7 段；关时 7 段；
## - auto.*.smart：智能 AI 开、没排表、魔法足（最大魔法加 5 万、当前一半）时自动战斗选六档魔炮之一；O-待定-1 关时照原版选星光；
## - auto.*.sched_smart／sched_off：挂机顺序表排 5692，智能 AI 开时在六档里挑、关时放凰霞风暴 30%（O-待定-2）；放出去不预约 2483 选单、真打出伤害；
## - auto.*.sched_off_orig：O-待定-2 关时照原版放 5692 本身（会预约选单）；
## - auto.*.no_mp：魔法 0 时不卡：智能 AI 开关两种都不放 5692、不预约选单、动作照常结算。
func _auto() -> void:
	for tq in [false, true]:
		var tag := "auto.tq" if tq else "auto.xy"
		var was_smart := XConfig.smart_ai()
		# 段数
		var b := _auto_battle(tq)
		var logic: XBattleLogic = b[0]
		var n: XActor = b[2]
		var star := XDB.rec("Skills", 5710)
		var ai := XSmartAI.new(logic, n)
		var keep := [XSmartAI.o_seq_if_hits, XNanoha.AUTO_CANNON]
		var h_on := ai.seq_hits(n, star)
		XSmartAI.o_seq_if_hits = false
		var h_off := XSmartAI.new(logic, n).seq_hits(n, star)
		XSmartAI.o_seq_if_hits = keep[0]
		n.learn_skill(5702)
		var h_learned := XSmartAI.new(logic, n).seq_hits(n, star)
		n.forget_skill(5702)
		check(tag + ".seq_hits", h_on == 2.0 and h_off == 7.0 and h_learned == 7.0, [h_on, h_off, h_learned])
		# 智能 AI、没排表
		XConfig._values.codexSmartAI = true
		var pick := int(logic.auto_battle_action(n)[0].get("id", 0))
		XSmartAI.o_seq_if_hits = false
		var pick_orig := int(logic.auto_battle_action(n)[0].get("id", 0))
		XSmartAI.o_seq_if_hits = keep[0]
		check(tag + ".smart", XSmartAI.CANNON_POWER.has(pick) and pick_orig == 5710, [pick, pick_orig])
		# 挂机表排 5692：智能 AI 开／关
		for smart in [true, false]:
			b = _auto_battle(tq)
			logic = b[0]
			n = b[2]
			XConfig._values.codexSmartAI = smart
			_schedule(b[1], n, 5692)
			var r := logic.auto_battle_action(n)
			var id := int(r[0].get("id", 0))
			var mp0 := n.mp
			var hp0: float = logic.enemies.reduce(func(acc, e): return acc + e.hp, 0.0)
			var logs := logic.act(n, r[0], r[1] if r[1] != null else logic.enemies[0])
			var reserved := XBattleCommonEvent.reserved(logic)
			logs.append_array(logic.run_events())
			var hp1: float = logic.enemies.reduce(func(acc, e): return acc + e.hp, 0.0)
			var used := logs.any(func(l): return l is Dictionary and l.has("target") and int(l.get("skill", {}).get("id", 0)) == id)
			var ok_id := XSmartAI.CANNON_POWER.has(id) if smart else id == 5703
			var ok_mp := n.mp < mp0 if smart else n.mp == mp0 - floorf(mp0 * 0.3)
			check(tag + (".sched_smart" if smart else ".sched_off"), ok_id and ok_mp and used and reserved != 2483 and hp1 < hp0,
				[id, mp0, n.mp, reserved, used, hp0 - hp1])
		# O-待定-2 关：照原版放 5692（预约选单）
		b = _auto_battle(tq)
		XConfig._values.codexSmartAI = false
		_schedule(b[1], b[2], 5692)
		XNanoha.AUTO_CANNON = false
		var orig := int(b[0].auto_battle_action(b[2])[0].get("id", 0))
		XNanoha.AUTO_CANNON = keep[1]
		check(tag + ".sched_off_orig", orig == 5692, orig)
		# 魔法 0：不放 5692、不卡选单
		for smart in [true, false]:
			b = _auto_battle(tq)
			logic = b[0]
			n = b[2]
			n.mp = 0.0
			XConfig._values.codexSmartAI = smart
			_schedule(b[1], n, 5692)
			var r := logic.auto_battle_action(n)
			var id := int(r[0].get("id", 0))
			logic.act(n, r[0], r[1] if r[1] != null else logic.enemies[0])
			var reserved := XBattleCommonEvent.reserved(logic)
			check(tag + ".no_mp." + ("smart" if smart else "off"), id != 5692 and id > 0 and reserved != 2483 and not logic.is_event_waiting(), [id, reserved])
		XHangUpAuto.data(b[1], "ActSkill").clear()
		XConfig._values.codexSmartAI = was_smart


## 奈叶单人、10 级会 5692、最大魔法加 5 万、当前魔法一半；敌群 2 血量很厚。tq＝天启篇存档（九死档，奈叶是超强者，上限 1 才能上场）
func _auto_battle(tq: bool) -> Array:
	var s: XState
	if tq:
		s = XTianqi.start_new_game(3, "jiusi", [108])  # 九死起超强者能上场（super_cap 1）
		XTianqi.take_pending()
		s.party.clear()
		s.battle_slots.clear()
		XTianqi._joining = true
		s.add_actor(108)
		XTianqi._joining = false
		s.map_id = 4
		XState.current = s
		s.actor(108).change_level_mv(10)
	else:
		s = _new_state()
		s.switches[2494] = true  # 同 _battle：开挑战开关，奈叶才能上场
		s.party.clear()
		s.battle_slots.clear()
		s.actor(108).change_level_mv(10)
		s.add_actor(108)
	var n := s.actor(108)
	if not n.skill_ids.has(5692):
		n.learn_skill(5692)
	var logic := XBattleLogic.new()
	var rand := XBattleRandom.create("0000000000000108")
	rand.rule = FixedMidStream.new()
	rand.rule.domain = "rule"
	logic.setup(2, s, rand)
	XBattleCommonEvent.take(logic)  # 开战预约的 1320 不跑
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += BIG_HP
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	n.add_param(1, 50000.0)
	n.param_mark_dirty()
	n.param_refresh()
	n.recover_all()
	n.mp = floorf(n.mmp * 0.5)
	logic.turn = 1
	return [logic, s, n]


func _schedule(s: XState, n: XActor, id: int) -> void:
	var table := XHangUpAuto.data(s, "ActSkill")
	table.clear()
	table[n.display_name() + XHangUpAuto.three(1)] = id


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_nanoha", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
