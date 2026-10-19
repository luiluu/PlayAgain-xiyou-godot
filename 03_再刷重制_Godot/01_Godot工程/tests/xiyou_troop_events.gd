extends Node
## 敌群事件（条件分支／公共事件、强制行动 339、更改状态）与轮回困难 Establish：对照 mv_oracle troop_event_probe（真实 BattleManager 跑两回合）。
## 场景：普通难度、开局队伍 1/8/9/10（1 级）、敌群 4/5/8/28/39/52/53/67/109/110（一至三、五至九、十一至十二层守层者，第 1 回合强制使用 8111 → 状态 1460）、
## 69（十层守层者：第 1 回合强制 500、给自己加状态 44、再强制 8111）、111／118／138／172／173／174／333（十三至十九层守层者：条件分支里调公共事件 1398，再强制 6069／6105／8111）。
## 十三至十九层另测已交见面礼（变量 842＝1）：跳过开场领域与强制行动。
## 三十层敌群 466 另测 HP≤25%（参照 hpRate）：开战即执行第 3 页——101 对话停住、确认后 336 变身 538、公共事件 1399、强制 6070／6105（见 _transform_case）。
## 三十一至三十三层 467／468／469 测 HP≤30%（第 3 页对话＋1397 回满）与 HP≤10%（预置第 3 页已执行，第 4 页对话＋变身 929／929／930＋1399）；
## Map055 引路人 794 测 HP≤20%（第 4 页对话＋变身 922＋1397）。
## 比较：第 1 回合强制行动排在最前且清掉守层者本回合的普通行动、敌方行动者、状态 1460 与第 1 回合加上的其余状态、
## 守层者攻击/魔攻、第 2 回合守层者每次命中的附加伤害（行动者正的攻击/魔攻各一次）。伤害浮动由 Godot 随机，不比 HP。
var results := []
## 已知偏差（登记在交付单，待规则车道改 battle_logic 后删）：{敌群: [第二名及之后的敌人比参照少的状态]}。
## 敌群 462（金角、银角）：强制 8111（全体友方，必中）给银角附加轮回困难 1460。原版 YEP_BattleEngineCore.itemEffectAddNormalState 对必中技能
## 不乘状态抗性与幸运差；Godot battle_logic 的状态效果（effect 21）一律乘幸运差，银角幸运比金角高 1 万，几率被乘成负数而没加上。
const KNOWN_STATE_GAPS := {462: [1460]}
## 三十层敌群 466 HP≤25% 两例的已知偏差（规则侧，battle_logic／XBattler，登记在交付单，修好后删）：
## hp_after_transform：冻结源 336 变身不刷新能力值缓存，紧接着 1399 的 334 完全回复按旧形态（466）的生命上限写 HP（参照 1.8e16），
##   Godot enemy_transform 当场刷新，334 按 538 的上限写（1e17）。下一次 334（第 1 回合）起两边一致。
## permanent_686：MV recoverAll 保留 <Permanent> 状态；Godot XBattler.recover_all 全清。已交礼时第 1 回合 1400 的 334 清掉第 0 回合 1399
##   加的 686 天道*祝福（攻击／魔攻 +1500 等），参照里 686 还在。三十一至三十三层 HP≤10% 例同理：第 0 回合第 4 页 1399 加 686，
##   第 1 回合第 2 页 1397 的 334 在 Godot 里清掉它（未交礼也会遇到）。
const KNOWN_TRANSFORM_GAPS := {"hp_after_transform": true, "permanent_686": true}


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func key(b: XBattler, logic: XBattleLogic) -> String:
	return "a%d" % int((b as XActor).data().id) if b is XActor else "e%d" % logic.enemies.find(b)


func setup(troop: int, paid := false) -> XBattleLogic:
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.set_variable(842, 1 if paid else 0)
	var logic := XBattleLogic.new()
	logic.level_roll = 0.99  # 参照：敌群生成时 Math.random=0.99
	logic.setup(troop, s)
	for a in logic.actors:
		for sk in [6168, 5980, 5548] + ([2571, 2786] if int(a.data().id) in [1, 2, 3, 4, 5, 6, 7, 52] else []):
			a.learn_skill(sk)
		a.refresh_passive()
		a.recover_all()
	return logic


func _run() -> void:
	var ref = XDB.load_json("oracle/troop_events.json")
	if not (ref is Dictionary and ref.has("cases")):
		check("oracle_present", false)
		return finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	# 事件里的随机变量（122 随机）同参照固定 Math.random＝0.5：Map055 引路人 794 第 3 页第 1 回合按随机变量 4 选强制 6063／6064／1393＋6065
	# （参照取 2 → 6064）；其余守层者的随机强制（变量 844）在第 3 回合起，两回合内用不到
	MVInterpreter.fixed_random = 0.5
	for c in ref.cases:
		check("troop%d.oracle_clean" % int(c.troop), c.errors.is_empty(), c.errors)
		if c.has("preset"):
			_preset_case(c)
			continue
		if c.has("hpRate"):
			for round in range(3):
				_transform_case(c, round)
			continue
		for round in range(5):
			_case(c, round)
	_unit_checks()
	finish()


## 开战前改敌人 HP（参照 preset），只比开场敌群事件后的敌人 HP 与状态（十五层副本敌群 160：控尸者 HP≤1% 时两只丧尸战斗不能）
func _preset_case(c: Dictionary) -> void:
	var logic := setup(int(c.troop))
	for i in c.preset:
		logic.enemies[int(i)].hp = float(c.preset[i])
	logic.troop_events()
	for k in c.battlers:
		if not str(k).begins_with("e"):
			continue
		var e: XBattler = logic.enemies[int(str(k).substr(1))]
		var want: Dictionary = c.battlers[k]
		check("troop%d.preset.%s" % [int(c.troop), k], int(e.hp) == int(want.hp) and e.state_ids == Array(want.states).map(func(x): return int(x)),
			[e.hp, e.state_ids, want])


## 开战前敌人 0 的 HP 设为上限的 hpRate（向下取整），跑开战检查与两回合。比较：开战时的对话（文字与脸图）、变身后的敌人编号与
## 生命上限（1399 的 334 回满）、各回合守层者的强制行动依次相同（之后的普通行动随机，不比）、第 1 回合后状态与攻击／魔攻。
func _transform_case(c: Dictionary, round: int) -> void:
	var name := "troop%d.paid%s.hp%s.r%d" % [int(c.troop), str(c.get("paid", false)), str(c.hpRate), round]
	seed(2000 + round)
	var logic := setup(int(c.troop), bool(c.get("paid", false)))
	# flags：参照开战前标为已执行的敌群页（三十一至三十三层 HP≤10% 例预置第 3 页，见 troop_event_probe）
	for i in c.get("flags", []):
		logic._event_flags[int(i)] = true
	var e0: XBattler = logic.enemies[0]
	e0.hp = floorf(e0.mhp * float(c.hpRate))
	check(name + ".hp_preset", is_equal_approx(e0.hp, float(c.hpPreset)), [e0.hp, c.hpPreset])
	# 开战检查（第 0 回合）：第 3 页的对话停住规则，run_events 按默认应答续上
	var logs := {0: logic.run_events(), 1: [], 2: []}
	var msgs: Array = logs[0].filter(func(l): return l.type == "message").map(func(l): return [str(l.msg.face), "\n".join(l.msg.lines)])
	var want_msgs: Array = c.messages.map(func(m): return [str(m.faceName), "\n".join(m.texts)])
	check(name + ".messages", msgs == want_msgs, [msgs, want_msgs])
	var want_ids: Array = c.enemyIds.map(func(x): return int(x))
	check(name + ".transformed", logic.enemies.map(func(e): return e.enemy_id) == want_ids, [logic.enemies.map(func(e): return e.enemy_id), want_ids])
	# 开战检查后守层者的 HP：参照记在第 0 回合它第一次出手（6070 以自己为目标）的 hpBefore
	var want_hp0 := -1.0
	for inv in c.invokes:
		if int(inv.turn) == 0 and inv.subject == "e0" and inv.target == "e0":
			want_hp0 = float(inv.hpBefore)
			break
	var gap_hp: bool = KNOWN_TRANSFORM_GAPS.hp_after_transform and is_equal_approx(e0.hp, e0.mhp / (e0 as XEnemy).param_buff_rate(0))   # 新形态不含 buff 的上限
	check(name + ".hp_after_transform", is_equal_approx(e0.hp, want_hp0) or gap_hp, [e0.hp, e0.mhp, want_hp0])
	var t1_states: Array = []
	for t in range(1, 3):
		if logic.is_won() or logic.is_lost():
			break
		var cmds := {}
		for a in logic.actors:
			cmds[a] = [XDB.rec("Skills", 1), e0]
		logs[t] = logic.run_turn(cmds)
		if t == 1:
			t1_states = e0.state_ids.duplicate()
			# 已知偏差 permanent_686：Godot 少了 686 时攻击／魔攻比参照少它的 +1500
			var lost_686: bool = KNOWN_TRANSFORM_GAPS.permanent_686 and not e0.state_ids.has(686) and c.battlers.e0.states.has(686.0)
			var off := 1500 if lost_686 else 0
			check(name + ".atk_mat", int(e0.atk) + off == int(c.battlers.e0.atk) and int(e0.mat) + off == int(c.battlers.e0.mat),
				[e0.atk, e0.mat, c.battlers.e0.atk, c.battlers.e0.mat, lost_686])
	check(name + ".skipped", logic.troop_event_skipped.is_empty(), logic.troop_event_skipped)
	# 生命上限：变身后 538 的上限加 6070／6071 的生命 buff（第 0、1 回合各一级），同参照战斗结束时的值
	check(name + ".mhp", int(e0.mhp) == int(c.battlers.e0.mhp), [e0.mhp, c.battlers.e0.mhp])
	for t in range(3):
		var want: Array = c.actions.filter(func(a): return int(a.turn) == t and a.subject == "e0" and a.forced).map(func(a): return int(a.skill))
		var got: Array = logs[t].filter(func(l): return l.type == "action" and l.user == e0).map(func(l): return int(l.skill.id))
		if t == 2 and logs[2].is_empty():
			continue
		check(name + ".forced_t%d" % t, got.slice(0, want.size()) == want, [got, want])
	var want_states: Array = []
	for inv in c.invokes:
		if int(inv.turn) == 1 and inv.subject == "e0":
			want_states = inv.userStates
	var gap_states: Array = [686] if KNOWN_TRANSFORM_GAPS.permanent_686 else []
	check(name + ".t1_states", want_states.all(func(id): return t1_states.has(int(id)) or gap_states.has(int(id))), [t1_states, want_states])


func _case(c: Dictionary, round: int) -> void:
	var target: int = int(c.get("target", 0))   # 玩家普通攻击的敌人序号（敌群 462 有两名守层者，另测集火敌人 1）
	var name := "troop%d.paid%s.r%d" % [int(c.troop), str(c.get("paid", false)), round]
	if target != 0:
		name = "troop%d.paid%s.target%d.r%d" % [int(c.troop), str(c.get("paid", false)), target, round]
	seed(1000 + round)
	var logic := setup(int(c.troop), bool(c.get("paid", false)))
	var e0: XBattler = logic.enemies[0]
	var logs := []
	var t1_states: Array = []
	# 每回合单独记录 [行动者, 技能]（多敌人的敌群里角色可能在行动前被打倒，行动者集合随随机数变，只比敌方）
	var got := {1: [], 2: []}
	var first_cleared := false
	for t in range(2):
		if logic.is_won() or logic.is_lost():
			break
		var cmds := {}
		for a in logic.actors:
			cmds[a] = [XDB.rec("Skills", 1), logic.enemies[target]]
		var turn_logs := logic.run_turn(cmds)
		logs.append_array(turn_logs)
		for l in turn_logs:
			if l.type == "action":
				got[t + 1].append([key(l.user, logic), int(l.skill.id)])
		if t == 0:
			first_cleared = logic.cleared_action(e0)
			t1_states = e0.state_ids.duplicate()
			check(name + ".state1460", e0.state_ids.has(1460) == c.battlers.e0.states.has(1460.0), e0.state_ids)
			check(name + ".atk_mat", int(e0.atk) == int(c.battlers.e0.atk) and int(e0.mat) == int(c.battlers.e0.mat),
				[e0.atk, e0.mat, c.battlers.e0.atk, c.battlers.e0.mat])
	check(name + ".skipped", logic.troop_event_skipped.is_empty(), logic.troop_event_skipped)
	# 其余敌人（敌群 462 的第二名守层者）：回合结束时没有被打倒的，攻击／魔攻与状态应同参照
	for k in c.battlers:
		if not str(k).begins_with("e") or str(k) == "e0":
			continue
		var ex: XBattler = logic.enemies[int(str(k).substr(1))]
		var want_b: Dictionary = c.battlers[k]
		if ex.hp > 0.0 and float(want_b.hp) > 0.0:
			var gap: Array = KNOWN_STATE_GAPS.get(int(c.troop), [])
			check(name + ".other_" + str(k), int(ex.atk) == int(want_b.atk) and int(ex.mat) == int(want_b.mat) and Array(want_b.states).all(func(id): return ex.state_ids.has(int(id)) or gap.has(int(id))),
				[ex.atk, ex.mat, ex.state_ids, want_b])
	var want := {1: [], 2: []}
	var forced := 0
	for a in c.actions:
		want[int(a.turn)].append([a.subject, int(a.skill)])
		if int(a.turn) == 1 and a.subject == "e0" and a.forced:
			forced += 1
	# 第 1 回合守层者最后一次行动后的状态（参照记在 invoke 的 userStates）：Godot 第 1 回合结束时都应还在
	var want_states: Array = []
	for inv in c.invokes:
		if int(inv.turn) == 1 and inv.subject == "e0":
			want_states = inv.userStates
	check(name + ".t1_states", want_states.all(func(id): return t1_states.has(int(id))), [t1_states, want_states])
	var enemies_of := func(list: Array) -> Array:
		var keys := {}
		for x in list:
			if str(x[0]).begins_with("e"):
				keys[x[0]] = true
		var out := keys.keys()
		out.sort()
		return out
	# 第 1 回合：强制行动最先；守层者是回合首位时本回合的普通行动被清掉（参照即此情形），
	# 不是首位时轮到它还会再行动一次（OTB 轮到时才 makeActions）。敌方行动者一致
	check(name + ".t1_forced_first", (not first_cleared) if forced == 0 else (not got[1].is_empty() and got[1][0] == want[1][0]), [got[1], want[1]])
	# 守层者本回合的普通行动：全队已被打倒（敌群 462 的银角一回合内杀光）时轮不到，此时只要强制行动做完
	var e0_times: int = got[1].filter(func(x): return x[0] == "e0").size()
	check(name + ".t1_enemy_actions", e0_times == forced + (0 if first_cleared else 1) or (logic.is_lost() and e0_times == forced), [forced, first_cleared, got[1]])
	check(name + ".t1_enemy_set", enemies_of.call(got[1]) == enemies_of.call(want[1]), [got[1], want[1]])
	# 第 2 回合（战斗没结束时）：守层者照常行动一次（技能随机，不比）；有追加行动特性（61，几率）的敌人，每条特性最多再多一次（怨毒集合体 10%）
	if not got[2].is_empty():
		var plus := 0
		for tr in (e0 as XEnemy).data().get("traits", []):
			if int(tr.code) == 61 and float(tr.value) > 0.0:
				plus += 1
		var times: int = got[2].filter(func(x): return x[0] == "e0").size()
		check(name + ".t2_enemy_once", times >= 1 and times <= 1 + plus, got[2])
	# 附加伤害：守层者用过 8111（加上 1460）之后，每次命中活着的目标都按 [攻击, 魔攻] 附加
	# （十层守层者第 1 回合先强制 500，那时还没有 1460，不附加）
	var extras := []
	var established := false
	for l in logs:
		if l.type == "action" and l.user == e0 and int(l.skill.id) == 8111:
			established = true
		if established and l.type == "hit" and l.user == e0 and not l.missed and not l.evaded and l.target != e0:
			extras.append(l.get("extra", []))
	var want_extra := []
	for inv in c.invokes:
		if inv.subject == "e0" and inv.target != "e0" and float(inv.hpBefore) > 0.0 and inv.userStates.has(1460.0):
			want_extra = [float(inv.userAtk), float(inv.userMat)]
	check(name + ".extra", extras.is_empty() if want_extra.is_empty() else (not extras.is_empty() and extras.all(func(x): return x == want_extra)), [extras, want_extra])


## 条件与目标的细项（不依赖参照数据）
func _unit_checks() -> void:
	var logic := setup(4)
	var page := {"conditions": {"turnEnding": false, "turnValid": true, "turnA": 1, "turnB": 0, "enemyValid": false,
		"actorValid": false, "switchValid": false}, "span": 0, "list": []}
	logic.turn = 0
	check("cond.turn_a_only_miss", not logic._page_meets(page, false))
	logic.turn = 1
	check("cond.turn_a_only_hit", logic._page_meets(page, false))
	page.conditions.turnA = 0
	page.conditions.turnB = 2
	logic.turn = 0
	check("cond.turn_ab_zero", not logic._page_meets(page, false))
	logic.turn = 4
	check("cond.turn_ab_every2", logic._page_meets(page, false))
	logic.turn = 3
	check("cond.turn_ab_odd", not logic._page_meets(page, false))
	page.conditions.turnEnding = true
	logic.turn = 4
	check("cond.turn_ending", not logic._page_meets(page, false) and logic._page_meets(page, true))
	var empty := {"conditions": {}, "span": 0, "list": []}
	check("cond.no_condition_never", not logic._page_meets(empty, false))
	# 强制行动的目标：序号阵亡时取第一个活着的
	var skill := XDB.rec("Skills", 1)
	var e0: XBattler = logic.enemies[0]
	logic.actors[0].hp = 0
	check("target.smooth", logic._forced_target(e0, skill, 0) == logic.actors[1])
	check("target.random", logic._forced_target(e0, skill, -1) == null)
	# Establish：负能力值不附加
	var t: XBattler = logic.actors[1]
	e0.add_state(1460)
	var r := {}
	var hp0 := t.hp
	logic._establish(e0, t, r)
	check("establish.hp", is_equal_approx(t.hp, maxf(0.0, hp0 - e0.atk - e0.mat)), [hp0, t.hp, e0.atk, e0.mat])
	check("establish.extra", r.get("extra", []) == [float(e0.atk), float(e0.mat)], r)


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
