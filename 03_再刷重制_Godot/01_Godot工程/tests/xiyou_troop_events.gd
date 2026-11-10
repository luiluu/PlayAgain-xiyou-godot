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
## 739 嘤族之光：确有命中且 extra 与参照相符的例数（随机技能可能某轮没打到角色，全套至少要有一例证明附加伤害确实执行）
var _extra_hits := 0
var _seen739 := false
var _strict_random_set_checks := 0
var _strict_random_extra_checks := 0
## rules-gaps8：第 1 回合守层者比参照多出手、改比自身攻击／魔攻的局数（只打印，看换种子后有多少局掷中追加行动）
var _more_slot_cases := 0
## 随机选技能的敌群：军团 676～693（神魔战场）、超级 Boos 嘤族之光 739
const RANDOM_AI_TROOPS := [676, 677, 678, 679, 680, 681, 682, 683, 684, 685, 686, 687, 688, 689, 690, 691, 692, 693, 739,
	# accept4：160 控尸者第 1 回合在 864／865 里随机挑（865 一回合杀光全队时别的敌人轮不到）；
	# 398 蚀世树第 2 回合的技能随机（参照 0.5 挑到打自己的 2565、没命中角色，别的种子会打到角色并带附加伤害）
	160, 398,
	# floor1 新源 Boss：剑道争锋 2001、2022～2025 交了见面礼（不走开场强制）后在几个 rating 5 技能里随机挑，挑到 10472 才有状态 76、
	# 挑到 10549 是 2757 和攻击加成；死神觉醒 2010／2026 的「最后通牒」4354 打没打倒全队决定后面的敌人还轮不轮得到；
	# 2001／2024 附加伤害看守层者打没打到人。固定 0.5 的 xiyou_troop_events_half 这些项全过（规则对得上），五种种子下不比
	2001, 2010, 2022, 2023, 2024, 2025, 2026]
## 已知游戏差异：这几项照原版参照会失败，不计入断言，输出打 KNOWN_DIFF 行（accept4 起）。
## 321 六耳猕猴「模仿」856 的 <After Eval> 强制普通攻击 fix5 已接上（XBattleLogic._after_eval_force），回退支见 _unit_checks
## floor1 新源 Boss 首次对照挂的 12 个敌群（rules-gaps3 清空）：查下来都不是规则缺口，是对照的时点与随机：t1_states 改比回合末
## （turnStarts），剑道争锋／死神觉醒的随机选技能进 RANDOM_AI_TROOPS（固定 0.5 的 _half 照常严比），肉山 2029 事件随机固定 0.5，
## hp_after_transform 按单槽公共事件算 1401 回不回血
## rules-gaps8：木桩 826 HP≤20% 例（开战即第 3 页变身 937）第 1 回合的第二行动位已接上：937 行动次数 2（OTB 当前回合排两格），
## 强制 6068／6055／6064 的 clearActions 只清首位那一格，第 2 格 getNextSubject 重新 makeActions 照常出 8111、加 1460；
## 不变身的黑莲 936 只有一格，所以强制之后没有普通出手（XBattleLogic.take_cleared 只用掉首位那一格）。现在没有已知差异
const KNOWN_DIFF := {}
## 参照用例按序号轮流分 parts 份，一个场景管一份（xiyou_troop_events 是第 0 份，_b／_c／_d 各管一份），免得单场景在并行全量里逼近上限
## （两份时满负载 534／600 秒，_b 被杀，tools30 改四份）；来源指纹与 _unit_checks 只在第 0 份做，断言总数与拆分前相同
@export var part := 0
@export var parts := 4
@export var oracle_half := false
## rules-gaps9：战斗专用公共事件的 skillCE 用例（381 例）单独两个场景跑（_sce／_sce_b，parts＝2），原来五个场景跳过它们，免得单场景逼近上限
@export var skill_ce_only := false
## 敌群 462（金角、银角）：强制 8111（全体友方，必中）给银角附加轮回困难 1460——必中技能附加状态不乘状态有效度与幸运差。
## 三十层起变身例：336 变身后紧接的 334 按变身前的生命上限回满（冻结源能力值缓存）；334 保留 <Permanent> 状态（686 天道*祝福）。


## --coverage=<文件>（cc events13）：另记每例实际执行到的敌群页／公共事件指令（XBattleEventRunner.COVER，「tTpP:下标」或「ceN:下标」），
## 写成 JSON 给 03_转换工具/敌群页覆盖.py；byCase 以参照用例序号为键（五轮随机种子的并集）。不加时 COVER 保持 null，测试行为不变。
var coverage_out := ""
## 本机排查用：环境变量 XIYOU_TROOP_ONLY=2002,2029 只跑这些敌群的用例（断言少了，别拿来交付）
var _only_troops: Array = Array(OS.get_environment("XIYOU_TROOP_ONLY").split(",", false)).map(func(x): return int(x))
var coverage_by_case := {}
## 同上，XIYOU_CE_ONLY=1517,1501 只跑这些战斗专用公共事件的 skillCE 用例（rules-gaps9）
var _only_ce: Array = Array(OS.get_environment("XIYOU_CE_ONLY").split(",", false)).map(func(x): return int(x))


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--coverage="):
			coverage_out = arg.substr(11)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	var parts_ := name.split(".")
	if parts_.size() >= 2 and parts_[0].begins_with("troop") and KNOWN_DIFF.has(int(parts_[0].substr(5))) \
			and KNOWN_DIFF[int(parts_[0].substr(5))].has(parts_[parts_.size() - 1]):
		if not ok:
			print("KNOWN_DIFF ", name, " ", JSON.stringify(detail))
		return
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func key(b: XBattler, logic: XBattleLogic) -> String:
	return "a%d" % int((b as XActor).data().id) if b is XActor else "e%d" % logic.enemies.find(b)


## 参照固定 Math.random＝0.5：战斗不认 MVEventCore.fixed_random（沙僧 dev.099 规定战斗只用本场规则流），
## 本测试对敌群事件的 122 随机变量单独按 0.5 取值，其余规则抽样照常走本场规则流。只用于引路人 794（第 3 页按随机变量 4 选强制）。
## 原版参照把 Math.random 固定为0.5；整数是floor(n*0.5)，不能以uint32%n替代。
## 仅确定性对照场景注入，原五种种子的场景仍走真实本场流。
class OracleHalfStream extends XRandomStream:
	var event_r := 0.5  # rules-gaps5：事件随机变量（reason event_variable）另取的值（参照 eventRandom）
	func next_float(reason: String, event_key := "") -> float:
		journal.append({"domain": domain, "ordinal": draws, "kind": "float", "reason": reason, "event": event_key, "value": 0.5})
		draws += 1
		return 0.5
	func next_index_mod(n: int, reason: String, event_key := "") -> int:
		return floori(n * next_float(reason, event_key))
	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		if reason == "event_variable" and event_r != 0.5:
			next_float(reason, event_key)
			return lo + floori((hi - lo + 1) * event_r)
		return lo + floori((hi - lo + 1) * next_float(reason, event_key))


class EventHalfStream extends XRandomStream:
	var event_r := 0.5
	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		if reason == "event_variable":
			return lo + floori((hi - lo + 1) * event_r)
		return super(lo, hi, reason, event_key)


static func _half_events(src: XRandomStream, event_r := 0.5) -> XRandomStream:
	var out := EventHalfStream.new()
	out.event_r = event_r
	out.domain = src.domain
	out.draws = src.draws
	out.journal = src.journal
	out.error = src.error
	out._rng.seed = src._rng.seed
	out._rng.state = src._rng.state
	out._tape = src._tape
	out._scripted = src._scripted
	out._seed_hex = src._seed_hex
	return out


func setup(troop: int, paid := false, trial_seed := 1000, party: Array = []) -> XBattleLogic:
	XEnemy.force_roll = 100.0
	# rules-gaps7：参照 party（嘤嘤怪 1 换队伍）时开局队伍照它建，默认 1／8／9／10
	var s := XState.new_game(3, 1, [8, 9, 10]) if party.is_empty() else XState.new_game(3, int(party[0]), party.slice(1).map(func(x): return int(x)))
	s.random_master = XRandomStream.hex64(trial_seed)
	s.set_variable(842, 1 if paid else 0)
	var logic := XBattleLogic.new()
	logic.level_roll = 0.99  # 参照：敌群生成时 Math.random=0.99
	if oracle_half:
		var context := s.reserve_battle_random()
		context.rule = OracleHalfStream.new()
		context.rule.domain = "rule"
		context.rule._seed_hex = "0000000000000000"
		logic.setup(troop, s, context)
	else:
		logic.setup(troop, s)
	# 794 引路人第 3 页、肉山 2029 的 10613 公共事件 9042（随机变量 1339 取 0～10，≥7 再强制 10614 踩地板）：事件里的随机同参照取 0.5，
	# 不然 1／11 的种子多出一次 10614（第 1 回合行动次数、第 2 回合只出手一次对不上，踩地板打倒全队后第 1 回合整段没了）
	# rules-gaps6：木桩 826 第 2 页每回合按随机变量 4 选强制 6063／6064（参照取 2 → 6064），同上
	if troop in [794, 2029, 826] and not oracle_half:
		logic.random.rule = _half_events(logic.random.rule)
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
	var same: bool = ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs
	if (part == 0 and not skill_ce_only) or not same:  # 其他份只在不同源时补一项失败
		check("same_source", same)
	# 事件里的随机变量（122 随机）同参照固定 Math.random＝0.5：Map055 引路人 794 第 3 页第 1 回合按随机变量 4 选强制 6063／6064／1393＋6065
	# （参照取 2 → 6064）；其余守层者的随机强制（变量 844）在第 3 回合起，两回合内用不到
	MVInterpreter.fixed_random = 0.5
	for k in range(part, ref.cases.size(), parts):
		var c: Dictionary = ref.cases[k]
		if c.has("skillCE") != skill_ce_only:
			continue
		if _only_troops != [] and not _only_troops.has(int(c.troop)):
			continue
		if _only_ce != [] and not _only_ce.has(int(c.get("skillCE", 0))):
			continue
		if coverage_out != "":
			XBattleEventRunner.COVER = {}
			_case_dispatch(c)
			coverage_by_case[str(k)] = XBattleEventRunner.COVER.keys()
			XBattleEventRunner.COVER = null
			continue
		_case_dispatch(c)
	if _seen739:
		check("troop739.extra_hit_exists", _extra_hits > 0, _extra_hits)
	if part == 0 and not skill_ce_only:
		_unit_checks()
	if coverage_out != "":
		var all := {}
		for k in coverage_by_case:
			for x in coverage_by_case[k]:
				all[x] = true
		var fc := FileAccess.open(coverage_out, FileAccess.WRITE)
		fc.store_string(JSON.stringify({"note": "xiyou_troop_events --coverage：对照里实际执行到的敌群页／公共事件指令（位置:下标）",
			"part": part, "parts": parts, "executed": all.keys(), "byCase": coverage_by_case}))
		fc.close()
	finish()


func _case_dispatch(c: Dictionary) -> void:
	check("troop%d.oracle_clean" % int(c.troop), c.errors.is_empty(), c.errors)
	if c.has("skillCE"):
		# O-247：CE1365 三咒凝魄默认只额外放一次（EXTRA_ONCE），回退开关设 false 时回到原版的无限连放（靠 CHAIN_LIMIT 截停）；两支各比一遍
		if int(c.skillCE) == 1365:
			var once_default := XBattleCommonEvent.EXTRA_ONCE
			check("troop2.%s.extra_once_default" % str(c.variant), once_default, once_default)  # 默认修好（只额外放一次）
			XBattleCommonEvent.EXTRA_ONCE = false
			_skill_ce_case(c, "off")
			XBattleCommonEvent.EXTRA_ONCE = true
			_skill_ce_case(c)
			XBattleCommonEvent.EXTRA_ONCE = once_default
			return
		_skill_ce_case(c)
		return
	if c.has("party"):
		_party_case(c)
		return
	if c.has("preset"):
		_preset_case(c)
		return
	if c.has("turnPreset"):
		_turn_preset_case(c)
		return
	if c.has("hpRate"):
		for round in range(1 if oracle_half else 3):
			_transform_case(c, round)
		return
	for round in range(1 if oracle_half else 5):
		_case(c, round)


## t1（cc events13，敌群页覆盖.py 的「页条件：回合 3+3·X」簇）：回合计数预置 N，先跑开战检查（第 N 回合）再跑第 N+1 回合。
## 只比两段各自的对话与强制行动［行动者, 技能］（强制行动排在该段行动最前）；守层者第 1 页按随机变量 844 选强制技能，
## 事件里的随机同参照取 0.5（_half_events），伤害与目标随机不比。
## rules-gaps5：参照 eventRandom 例（变量 844 的其余各支）事件随机改取该值。
func _turn_page_case(c: Dictionary, name: String, logic: XBattleLogic) -> void:
	var event_r := float(c.get("eventRandom", 0.5))
	if oracle_half:
		(logic.random.rule as OracleHalfStream).event_r = event_r
	else:
		logic.random.rule = _half_events(logic.random.rule, event_r)
	var n := int(c.turnPreset)
	logic.turn = n
	# rules-gaps6：参照 flags（同回合排在前面的页预置成本回合已执行，见 troop_event_probe LATE_GAPS6／PAGE2_844）
	for i in c.get("flags", []):
		logic._event_flags[int(i)] = true
	var phases := {n: logic.run_events(), n + 1: []}
	if not (logic.is_won() or logic.is_lost()):
		var cmds := {}
		for a in logic.actors:
			cmds[a] = [XDB.rec("Skills", 1), logic.enemies[0]]
		phases[n + 1] = logic.run_turn(cmds)
	for t in phases:
		var tag := "start" if t == n else "turn"
		var msgs: Array = phases[t].filter(func(l): return l.type == "message").map(func(l): return [str(l.msg.face), "\n".join(l.msg.lines)])
		var want_msgs: Array = c.messages.filter(func(m): return int(m.turn) == t).map(func(m): return [str(m.faceName), "\n".join(m.texts)])
		check(name + ".t1_%s_messages" % tag, msgs == want_msgs, [msgs, want_msgs])
		var want: Array = c.actions.filter(func(a): return int(a.turn) == t and bool(a.forced)).map(func(a): return [str(a.subject), int(a.skill)])
		var got: Array = phases[t].filter(func(l): return l.type == "action").map(func(l): return [key(l.user, logic), int(l.skill.id)])
		check(name + ".t1_%s_forced" % tag, got.slice(0, want.size()) == want, [got, want])
	# 审查 69 P3-2：参照 sceneChange＝Scene_Gameover（353 游戏结束，圣劫使 825 第 30 回合）时 game_over 置位、按全灭收场，
	# 且 353 之后的指令（同页 222 淡入）不再执行；没有 sceneChange 的例子 game_over 不该置位
	var over := str(c.get("sceneChange", "")) == "Scene_Gameover"
	var start_logs: Array = phases[n]
	var at := start_logs.find_custom(func(l): return l.type == "game_over")
	var after_in := at >= 0 and start_logs.slice(at).any(func(l): return l.type == "event_view" and l.fade == "in")
	check(name + ".t1_game_over", logic.game_over == over and (not over or (logic.is_lost() and at >= 0 and not after_in)),
		[logic.game_over, over, logic.is_lost(), at, after_in])
	check(name + ".t1_skipped", logic.troop_event_skipped.is_empty(), logic.troop_event_skipped)


## rules-gaps9：只在战斗里跑的公共事件（参照 skillCE，troop_event_probe SKILL_CE）：敌群 2、队伍照参照建（被拦的高号角色直接写进队伍），
## 学会／忘掉参照 actorSkills，使用者用起点技能（或物品）打敌人 0，再跑行动后的事件。规则流全取 0.5（同参照 Math.random）。
## 比：行动后预约的公共事件、事件里的强制行动［行动者, 技能］（参照记换前的技能，按同样的 0.5 过一次 change_to）、
## 事件之后 CE 里 313／333 提到的状态在谁身上（参照 snap）、没有跳过的指令。切片里没有起点或公共事件的例子跳过（_skill_ce_missing 计数）。
var _skill_ce_missing := 0

func _skill_ce_case(c: Dictionary, tag := "") -> void:
	var name := "troop2.%s%s" % [str(c.variant), "" if tag == "" else "." + tag]
	if _only_ce != []:
		print("CASE ", name, " ", Time.get_ticks_msec())
	var use: Array = c.use
	var item := XDB.rec("Items" if str(use[0]) == "item" else "Skills", int(use[1]))
	if item.is_empty() or XDB.rec("CommonEvents", int(c.skillCE)).is_empty():
		_skill_ce_missing += 1
		return
	var party: Array = Array(c.party).map(func(x): return int(x))
	var s := XState.new_game(3, party[0], party.slice(1))
	s.random_master = XRandomStream.hex64(1000)
	s.party.assign(party)
	s.battle_slots = party + [0]
	for id in party:
		s.actor(id)
	var logic := XBattleLogic.new()
	logic.level_roll = 0.99
	var context := s.reserve_battle_random()
	context.rule = OracleHalfStream.new()
	context.rule.domain = "rule"
	context.rule._seed_hex = "0000000000000000"
	logic.setup(2, s, context)
	var user: XActor = s.actor(int(use[2]))
	for id in c.actorSkills:
		for k in c.actorSkills[id]:
			if int(k) > 0:
				s.actor(int(id)).learn_skill(int(k))
			else:
				s.actor(int(id)).forget_skill(-int(k))
	if str(use[0]) == "item":
		s.gain_item(int(use[1]), 5)
	for a in logic.actors:
		a.refresh_passive()
		a.recover_all()
		a.tp = 100
	for e in logic.enemies:
		e.capture = false
		e.added_params[0] = 999999999.0  # 同参照：敌人 HP 加 999999999 打不死（不然事件里「敌人 N 战斗不能」等条件与强制目标跟着变）
		e.param_cells = []
		e.hp = e.mhp
	var acts: Array = c.actions
	var ui := -1
	for i in acts.size():
		var x: Dictionary = acts[i]
		if x.item != null and str(x.subject) == "a%d" % int(use[2]) and int(x.item[1]) == int(use[1]) and not bool(x.forced):
			ui = i
			break
	if ui < 0:
		# 参照里使用者没出手（用不了这个技能），事件当然没跑；这里不比，只计数
		_skill_ce_missing += 1
		return
	var want_ce := 0
	for e in c.events:
		if int(e.afterActions) == ui + 1 and int(e.commonEvent) != XBattleCommonEvent.START_EVENT:
			want_ce = int(e.commonEvent)
			break
	# 同参照：有选项的选最后一项（多是「否」／「再想想」；CE1627 流派选择菜单选别的会跳回菜单无限循环）
	logic.message_responder = func(msg): return msg.get("choices", []).size() - 1 if not msg.get("choices", []).is_empty() else null
	logic.act(user, item, logic.enemies[0])
	check(name + ".reserved", XBattleCommonEvent.reserved(logic) == want_ce, [XBattleCommonEvent.reserved(logic), want_ce])
	logic.common_event_skipped.clear()
	var ev := logic.run_events()
	var got: Array = ev.filter(func(x): return x.type == "action").map(func(x): return [key(x.user, logic), int(x.skill.id)])
	var want := []
	for i in range(ui + 1, acts.size()):
		if not bool(acts[i].forced):
			break
		var subj := str(acts[i].subject)
		var sk := int(acts[i].item[1])
		if subj.begins_with("a") and str(acts[i].item[0]) == "skill":
			sk = int(logic.change_to(s.actor(int(subj.substr(1))), XDB.rec("Skills", sk)).id)
		want.append([subj, sk])
	# CE1365 三咒凝魄：强制的 6930 自己又带效果 44 → 1365，原版无限连放（参照 2 万帧里放了 700 多次还没完）；
	# 默认（XBattleCommonEvent.EXTRA_ONCE）只额外放一次＝参照的第一个强制行动；回退开关关掉时 CHAIN_LIMIT 截停，参照比上限长时只比前 CHAIN_LIMIT 个
	var cap := XBattleCommonEvent.CHAIN_LIMIT
	if int(c.skillCE) == 1365 and XBattleCommonEvent.EXTRA_ONCE:
		cap = 1
		check(name + ".once_len", got.size() == mini(want.size(), 1), [got.size(), want.size()])
	if want.size() > cap:
		want = want.slice(0, cap)
		got = got.slice(0, cap)
	check(name + ".forced", JSON.stringify(got) == JSON.stringify(want), [got, want])
	var watch: Array = Array(c.watch).map(func(x): return int(x))
	for b in logic.actors + logic.enemies:
		var k := key(b, logic)
		if not c.snap.has(k):
			continue
		var w: Array = Array(c.snap[k]).map(func(x): return int(x))
		var g: Array = b.state_ids.map(func(x): return int(x)).filter(func(x): return watch.has(x))
		w.sort()
		g.sort()
		check(name + ".states_" + k, g == w, [g, w])
	check(name + ".skipped", logic.common_event_skipped.is_empty(), logic.common_event_skipped)


## rules-gaps7：换队伍（参照 party／actorSkills，嘤嘤怪 1：页按角色 4／20／29 在队、会不会技能 23／509／201／575 给全队或自己加状态 11／45／34／51）。
## 开局队伍照参照建，开战后学会／忘掉技能（负数＝忘掉），eventRandom 时事件随机（变量 53）改取该值，turnPreset 时回合计数从 N 起；
## 跑到参照的回合数（或分出胜负），比各角色身上这几个由事件加的状态。伤害与行动随机不比。
const PARTY_EVENT_STATES := [11, 34, 45, 51]

func _party_case(c: Dictionary) -> void:
	var name := "troop%d.%s" % [int(c.troop), str(c.variant)]
	var logic := setup(int(c.troop), bool(c.get("paid", false)), 1000, Array(c.party))
	for id in c.get("actorSkills", {}):
		var a: XActor = logic.state.actor(int(id))
		for k in c.actorSkills[id]:
			if int(k) > 0:
				a.learn_skill(int(k))
			else:
				a.forget_skill(-int(k))
	if c.has("eventRandom"):
		logic.random.rule = _half_events(logic.random.rule, float(c.eventRandom))
	var n := int(c.get("turnPreset", 0))
	logic.turn = n
	var last := n + 1 if n else 2  # 同探针：跑到第 N+1 回合（预置时）或前两回合
	while logic.turn < last and not (logic.is_won() or logic.is_lost()):
		var cmds := {}
		for a in logic.actors:
			cmds[a] = [XDB.rec("Skills", 1), logic.enemies[0]]
		logic.run_turn(cmds)
	for a in logic.actors:
		var k := key(a, logic)
		var want: Array = Array(c.battlers[k].states).map(func(x): return int(x)).filter(func(x): return PARTY_EVENT_STATES.has(x))
		var got: Array = a.state_ids.filter(func(x): return PARTY_EVENT_STATES.has(int(x)))
		want.sort()
		got.sort()
		check(name + ".states_" + k, got == want, [got, want])
	check(name + ".skipped", logic.troop_event_skipped.is_empty(), logic.troop_event_skipped)


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


## 回合预置（参照 turnPreset）：回合计数从 N 开始跑下一回合（金之巨人 830 第 20 回合第 4 页：101 对话＋强制 8203「毁灭」，
## 伤害公式 b.mhp * 2、无浮动、必中，每人 HP 清零）。比较：该回合的对话、强制行动、每名角色的首击伤害与 HP。
func _turn_preset_case(c: Dictionary) -> void:
	var name := "troop%d.turn%d" % [int(c.troop), int(c.turnPreset) + 1]
	if c.has("eventRandom"):
		name += ".r%d" % roundi(float(c.eventRandom) * 100)
	if c.has("flags"):
		name += ".f" + ",".join(Array(c.flags).map(func(x): return str(int(x))))
	var logic := setup(int(c.troop), bool(c.get("paid", false)), 3000)
	if str(c.get("variant", "")) == "t1":
		_turn_page_case(c, name, logic)
		return
	var mhp := {}
	for a in logic.actors:
		mhp[key(a, logic)] = a.mhp
	logic.turn = int(c.turnPreset)
	var cmds := {}
	for a in logic.actors:
		cmds[a] = [XDB.rec("Skills", 1), logic.enemies[0]]
	var logs := logic.run_turn(cmds)
	var msgs: Array = logs.filter(func(l): return l.type == "message").map(func(l): return [str(l.msg.face), "\n".join(l.msg.lines)])
	var want_msgs: Array = c.messages.map(func(m): return [str(m.faceName), "\n".join(m.texts)])
	check(name + ".messages", msgs == want_msgs, [msgs, want_msgs])
	var want_forced: Array = c.actions.filter(func(a): return a.subject == "e0" and a.forced).map(func(a): return int(a.skill))
	var got_forced: Array = logs.filter(func(l): return l.type == "action" and l.user == logic.enemies[0]).map(func(l): return int(l.skill.id))
	check(name + ".forced", got_forced.slice(0, want_forced.size()) == want_forced, [got_forced, want_forced])
	for inv in c.invokes:
		if inv.subject != "e0" or not str(inv.target).begins_with("a"):
			continue
		var k := str(inv.target)
		check(name + ".before_" + k, is_equal_approx(float(mhp[k]), float(inv.hpBefore)), [mhp[k], inv.hpBefore])
		var hits: Array = logs.filter(func(l): return l.type == "hit" and l.user == logic.enemies[0] and key(l.target, logic) == k)
		# 「action effect: actors」写了两遍：目标 HP 已空但还没倒下（60% 附加阵亡的掷骰没中）时第二遍再扣一次，
		# 参照掷骰固定 0.5 必中、只一遍；Godot 掷骰随机，所以只比第一击的伤害与「HP 清零」
		var want_dealt := 0.0
		for p in inv.popups:
			if p.target == k:
				want_dealt += float(p.hpDamage)
		check(name + ".damage_" + k, not hits.is_empty() and is_equal_approx(absf(float(hits[0].hp)), want_dealt), [hits.map(func(h): return h.hp), want_dealt])
		var who: XBattler = null
		for a in logic.actors:
			if key(a, logic) == k:
				who = a
		check(name + ".after_" + k, who != null and who.hp == float(inv.hpAfter), [who.hp if who else null, inv.hpAfter])
	check(name + ".skipped", logic.troop_event_skipped.is_empty(), logic.troop_event_skipped)


## 开战前敌人 0 的 HP 设为上限的 hpRate（向下取整），跑开战检查与两回合。比较：开战时的对话（文字与脸图）、变身后的敌人编号与
## rules-gaps5：参照 hpEnemy（敌人 1 的血线页，805～807、814 第 5 页）时预置并比较的是那名敌人（下面的 e0 换成它，玩家照旧打敌人 0）。
## 生命上限（1399 的 334 回满）、各回合守层者的强制行动依次相同（之后的普通行动随机，不比）、第 1 回合后状态与攻击／魔攻。
func _transform_case(c: Dictionary, round: int) -> void:
	var hi := int(c.get("hpEnemy", 0))
	var ek := "e%d" % hi
	var name := "troop%d.paid%s.hp%s.r%d" % [int(c.troop), str(c.get("paid", false)), str(c.hpRate), round]
	if hi != 0:
		name = "troop%d.paid%s.hp%s.%s.r%d" % [int(c.troop), str(c.get("paid", false)), str(c.hpRate), ek, round]
	var logic := setup(int(c.troop), bool(c.get("paid", false)), 2000 + round)
	# rules-gaps5：参照 vars（血线页里「变量 853／1567 == 1」才走的分支）开战前同样设上
	for v in c.get("vars", {}):
		logic.state.set_variable(int(v), int(c.vars[v]))
	if c.has("vars"):
		name += ".v" + ",".join(c.vars.keys())
	# flags：参照开战前标为已执行的敌群页（三十一至三十三层 HP≤10% 例预置第 3 页，见 troop_event_probe）
	for i in c.get("flags", []):
		logic._event_flags[int(i)] = true
	var e0: XBattler = logic.enemies[hi]
	var target0: XBattler = logic.enemies[0]
	e0.hp = floorf(e0.mhp * float(c.hpRate))
	check(name + ".hp_preset", is_equal_approx(e0.hp, float(c.hpPreset)), [e0.hp, c.hpPreset])
	# 开战检查（第 0 回合）：第 3 页的对话停住规则，run_events 按默认应答续上
	var logs := {0: logic.run_events(), 1: [], 2: []}
	var msgs: Array = logs[0].filter(func(l): return l.type == "message").map(func(l): return [str(l.msg.face), "\n".join(l.msg.lines)])
	var want_msgs: Array = c.messages.filter(func(m): return int(m.turn) == 0).map(func(m): return [str(m.faceName), "\n".join(m.texts)])
	check(name + ".messages", msgs == want_msgs, [msgs, want_msgs])
	var want_ids: Array = c.enemyIds.map(func(x): return int(x))
	check(name + ".transformed", logic.enemies.map(func(e): return e.enemy_id) == want_ids, [logic.enemies.map(func(e): return e.enemy_id), want_ids])
	# 开战检查后守层者的 HP：参照第 0 回合它最后一次以自己为目标出手后的 hpAfter（死神觉醒 2013 第 3 页 6067 之后还有 10524 自疗 20%）。
	# 6067～6070 领域技能带公共事件 1401「敌人恢复所有血量」（八戒_71 期四起执行）：行动结束后变量 40 = 9999999999999999
	#（JS 读成 1e16），331 全体敌人 HP + 变量 40。战斗里技能的公共事件是单槽预约（XBattleCommonEvent，后一个盖前一个），
	# 敌群页跑完才轮到它，所以只有第 0 回合守层者最后一个带公共事件的出手是 1401 时才加这一下（到上限为止）；
	# 肉山 2029 第 2 页 6068 之后的 10613 预约 9042，把 1401 盖掉了，第 0 回合末不回血（第 1 回合开场 1396 的 334 才回满）
	var want_hp0 := -1.0
	for inv in c.invokes:
		if int(inv.turn) == 0 and inv.subject == ek and inv.target == ek:
			want_hp0 = float(inv.hpAfter)
	var last_ce := 0
	for act in c.actions:
		if int(act.turn) == 0 and act.subject == ek:
			for eff in XDB.rec("Skills", int(act.skill)).get("effects", []):
				if int(eff.code) == 44:
					last_ce = int(eff.dataId)
	if want_hp0 >= 0.0 and last_ce == 1401:
		want_hp0 = minf(want_hp0 + 1e16, e0.mhp)
	# floor1：参照第 0 回合没有「e0 以自己为目标」的出手（v0.62 死神觉醒 2015 等血线页只对话／强制打玩家）时没有这个时点可比，跳过
	if want_hp0 >= 0.0:
		check(name + ".hp_after_transform", is_equal_approx(e0.hp, want_hp0), [e0.hp, e0.mhp, want_hp0])
	var t1_states: Array = []
	for t in range(1, 3):
		if logic.is_won() or logic.is_lost():
			break
		var cmds := {}
		for a in logic.actors:
			cmds[a] = [XDB.rec("Skills", 1), target0]
		logs[t] = logic.run_turn(cmds)
		# 第 1、2 回合的敌群事件对话（三十一层可选首领 830／831 第 2 页的提示）也按回合比
		var turn_msgs: Array = logs[t].filter(func(l): return l.type == "message").map(func(l): return [str(l.msg.face), "\n".join(l.msg.lines)])
		var want_turn: Array = c.messages.filter(func(m): return int(m.turn) == t).map(func(m): return [str(m.faceName), "\n".join(m.texts)])
		check(name + ".messages_t%d" % t, turn_msgs == want_turn, [turn_msgs, want_turn])
		if t == 1:
			t1_states = e0.state_ids.duplicate()
			check(name + ".atk_mat", int(e0.atk) == int(c.battlers[ek].atk) and int(e0.mat) == int(c.battlers[ek].mat),
				[e0.atk, e0.mat, c.battlers[ek].atk, c.battlers[ek].mat])
	check(name + ".skipped", logic.troop_event_skipped.is_empty(), logic.troop_event_skipped)
	# 生命上限：变身后 538 的上限加 6070／6071 的生命 buff（第 0、1 回合各一级），同参照战斗结束时的值
	check(name + ".mhp", int(e0.mhp) == int(c.battlers[ek].mhp), [e0.mhp, c.battlers[ek].mhp])
	for t in range(3):
		var want: Array = c.actions.filter(func(a): return int(a.turn) == t and a.subject == ek and a.forced).map(func(a): return int(a.skill))
		var got: Array = logs[t].filter(func(l): return l.type == "action" and l.user == e0).map(func(l): return int(l.skill.id))
		if t == 2 and logs[2].is_empty():
			continue
		check(name + ".forced_t%d" % t, got.slice(0, want.size()) == want, [got, want])
	var want_states: Array = _t1_end_states(c, ek)
	check(name + ".t1_states", want_states.all(func(id): return t1_states.has(int(id))), [t1_states, want_states])


## 参照第 1 回合末 e0 的状态（见 _case 里 t1_states 的说明）
static func _t1_end_states(c: Dictionary, ek := "e0") -> Array:
	var ts1: Array = c.get("turnStarts", []).filter(func(x): return int(x.after) == 1)
	if not ts1.is_empty() and ts1[0].enemies.has(ek):
		return Array(ts1[0].enemies[ek].states)
	var out: Array = []
	for inv in c.invokes:
		if int(inv.turn) == 1 and inv.subject == ek:
			out = inv.userStates
	return out


func _case(c: Dictionary, round: int) -> void:
	var target: int = int(c.get("target", 0))   # 玩家普通攻击的敌人序号（敌群 462 有两名守层者，另测集火敌人 1）
	var name := "troop%d.paid%s.r%d" % [int(c.troop), str(c.get("paid", false)), round]
	if target != 0:
		name = "troop%d.paid%s.target%d.r%d" % [int(c.troop), str(c.get("paid", false)), target, round]
	var logic := setup(int(c.troop), bool(c.get("paid", false)), 1000 + round)
	# rules-gaps6：参照 vars／switches（神劫使 824 的变量 1178、木桩抵抗档开关 174～177、S3西游模式 682）开战前同样设上
	for v in c.get("vars", {}):
		logic.state.set_variable(int(v), int(c.vars[v]))
	for sw in c.get("switches", []):
		logic.state.set_switch(int(sw), true)
	if c.has("vars") or c.has("switches"):
		name += "." + str(c.variant)
	var e0: XBattler = logic.enemies[0]
	var logs := []
	var t1_states: Array = []
	# 每回合单独记录 [行动者, 技能]（多敌人的敌群里角色可能在行动前被打倒，行动者集合随随机数变，只比敌方）
	var got := {1: [], 2: []}
	var first_cleared := false
	var more_slots := false   # 第 1 回合守层者出手次数多于参照（掷中了参照没掷中的追加行动，见下）
	var t1_others := {}   # 第 1 回合末各非首敌：{有无 44, 44 剩余回合}
	var t2_finished := false
	var t2_usable := true   # 第 2 回合开始时守层者有没有无条件可用的行动
	var t2_tp := -1.0
	# 第 1 回合守层者有没有无条件可用的行动（木桩 70～75／352～355 没有行动表，原版整场不出手）
	var t1_usable: bool = (e0 as XEnemy).data().get("actions", []).any(func(act): return int(act.conditionType) == 0 and logic.can_use(e0, XDB.rec("Skills", int(act.skillId))))
	for t in range(2):
		if logic.is_won() or logic.is_lost():
			break
		if t == 1:
			# 没有可用行动时原版不行动（Game_Enemy.makeActions 列表空，attack_query_probe skip 组）：开战 TP 是随机的 0～24，
			# 抽到不够 TP 技能（如 204／207 的 4161 要 10）且条件技能未到回合时第 2 回合本就不出手（参照固定 0.5 开战 TP 12，出手）
			t2_tp = e0.tp
			t2_usable = (e0 as XEnemy).data().get("actions", []).any(func(act): return int(act.conditionType) == 0 and logic.can_use(e0, XDB.rec("Skills", int(act.skillId))))
		var cmds := {}
		for a in logic.actors:
			cmds[a] = [XDB.rec("Skills", 1), logic.enemies[target]]
		var turn_logs := logic.run_turn(cmds)
		logs.append_array(turn_logs)
		for l in turn_logs:
			if l.type == "action":
				got[t + 1].append([key(l.user, logic), int(l.skill.id)])
		if t == 1:
			t2_finished = not (logic.is_won() or logic.is_lost())
		if t == 0:
			first_cleared = logic.cleared_action(e0)
			t1_states = e0.state_ids.duplicate()
			for i in range(1, logic.enemies.size()):
				var en: XBattler = logic.enemies[i]
				# ended：Godot 这一回合走到了回合末（run_turn 分出胜负就不跑 end_turn，剩余回合还没减）
				t1_others["e%d" % i] = {"alive": en.hp > 0.0, "has44": en.state_ids.has(44), "turns44": int(en.state_turns.get(44, -1)),
					"ended": not (logic.is_won() or logic.is_lost())}
			check(name + ".state1460", e0.state_ids.has(1460) == c.battlers.e0.states.has(1460.0), e0.state_ids)
			var want_am := [c.battlers.e0.atk, c.battlers.e0.mat]
			# 参照第 2 回合守层者给自己加了状态（397 吞海巨鲲 2450 加 114，攻击 1890→2390）：末态不是第 1 回合末的值，
			# 改比第 1 回合它最后一次出手时的攻击／魔攻（第 1 回合末的状态由 turnStarts 记，和末态一样时照旧比末态）
			var ts1: Array = c.get("turnStarts", []).filter(func(x): return int(x.after) == 1)
			if not ts1.is_empty() and ts1[0].enemies.has("e0") and Array(ts1[0].enemies.e0.states) != Array(c.battlers.e0.states):
				for inv in c.invokes:
					if int(inv.turn) == 1 and inv.subject == "e0":
						want_am = [inv.userAtk, inv.userMat]
			# rules-gaps8：这一局第 1 回合守层者比参照多出手（换种子后掷中了追加行动，参照固定 0.5 没掷中）：多出的那格照常出手、
			# 会给自己加状态（被封印者 379／383 的 4218 攻击 +500，原版强制两格实测同样 1830／1970），攻击／魔攻与附加伤害不比参照值
			# （参照第 1 回合停在强制行动之后、没轮到任何角色的例子（830／831 首位是角色 a10）不算：参照没走完这一回合，照旧比）
			var ref_t1: Array = c.actions.filter(func(a): return int(a.turn) == 1)
			# 审查 71 P3-1：_half 份的规则随机跟参照一样固定 0.5，正常不会多出格，多出来就是重制错了，不放宽
			more_slots = not oracle_half and ref_t1.any(func(a): return str(a.subject).begins_with("a")) \
				and got[1].filter(func(x): return x[0] == "e0").size() > ref_t1.filter(func(a): return a.subject == "e0").size()
			if more_slots:
				_more_slot_cases += 1
			if (oracle_half or not RANDOM_AI_TROOPS.has(int(c.troop))) and not more_slots:  # 随机选技能的敌群：自加的状态随挑到的技能变
				check(name + ".atk_mat", int(e0.atk) == int(want_am[0]) and int(e0.mat) == int(want_am[1]),
					[e0.atk, e0.mat, want_am])
	check(name + ".skipped", logic.troop_event_skipped.is_empty(), logic.troop_event_skipped)
	# 其余敌人（敌群 462 的第二名守层者）：回合结束时没有被打倒的，攻击／魔攻与状态应同参照
	for k in c.battlers:
		if not str(k).begins_with("e") or str(k) == "e0":
			continue
		var ex: XBattler = logic.enemies[int(str(k).substr(1))]
		var want_b: Dictionary = c.battlers[k]
		# 状态 44「再次行动」（trait 61，2 回合）由领域公共事件 1396／1397 用 333 [-1,0,44] 给全体敌人确定附加（沙僧50 内容批 P2-C1）。
		# 参照记了下一回合开始时（回合末事件已跑完，turnStarts）各敌人的状态与剩余回合，与 Godot run_turn 跑完一回合同一时点：
		# 第 1 回合末非首敌的 44 有无要对上；Godot 也走到了回合末（没在第 1 回合内分出胜负）时剩余回合也要对上（参照 2→1）
		var t1o: Dictionary = t1_others.get(str(k), {})
		var end1: Array = c.get("turnStarts", []).filter(func(x): return int(x.after) == 1)
		var ref1: Dictionary = end1[0].enemies.get(str(k), {}) if not end1.is_empty() else {}
		if not t1o.is_empty() and bool(t1o.alive):
			if not ref1.is_empty() and float(ref1.hp) > 0.0:
				var want44: bool = Array(ref1.states).has(44.0)
				check(name + ".t1_44_" + str(k), bool(t1o.has44) == want44, [t1o, ref1])
				if want44 and bool(t1o.ended):
					check(name + ".t1_44_turns_" + str(k), int(t1o.turns44) == int(ref1.turns.get("44", -1)), [t1o, ref1.turns])
			elif end1.is_empty() and float(want_b.hp) > 0.0:
				# 参照第 1 回合内就分出胜负（没有第 1 回合末）：末态就是当时的，只比 44 有无
				check(name + ".t1_44_" + str(k), bool(t1o.has44) == Array(want_b.states).has(44.0), [t1o, want_b.states])
		if ex.hp > 0.0 and float(want_b.hp) > 0.0:
			# 末态：Godot 走完第 2 回合末时 44 照规则到期，只有这时才允许缺 44
			check(name + ".other_" + str(k), int(ex.atk) == int(want_b.atk) and int(ex.mat) == int(want_b.mat)
				and Array(want_b.states).all(func(id): return ex.state_ids.has(int(id)) or (int(id) == 44 and t2_finished)),
				[ex.atk, ex.mat, ex.state_ids, want_b, t2_finished])
	var want := {1: [], 2: []}
	var forced := 0
	for a in c.actions:
		want[int(a.turn)].append([a.subject, int(a.skill)])
		if int(a.turn) == 1 and a.subject == "e0" and a.forced:
			forced += 1
	# 第 1 回合末守层者的状态：参照 turnStarts（after＝1，回合末事件已跑完）与 Godot run_turn 跑完第 1 回合同一时点。
	# 没有 turnStarts（第 1 回合内分出胜负）时退回守层者第 1 回合最后一次出手的 userStates。
	# floor1 剑道争锋 2002 等：开场页先 1396 加 44／1107／1109，强制行动后 334 回满（recoverAll 清掉非 Permanent 的 44、1107），
	# 出手时的 userStates 还带着、回合末已没了，以前按出手时比成了假差异
	var want_states: Array = _t1_end_states(c)
	if oracle_half or not RANDOM_AI_TROOPS.has(int(c.troop)):
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
	# Native action-plus traits apply to the first turn as well as the second.
	var plus := 0
	for tr in (e0 as XEnemy).data().get("traits", []):
		if int(tr.code) == 61 and float(tr.value) > 0.0:
			plus += 1
	var t1_times: int = got[1].filter(func(x): return x[0] == "e0").size()
	var normal := 0 if first_cleared or not t1_usable else 1
	# 守层者本回合的普通行动：全队已被打倒（敌群 462 的银角一回合内杀光）时轮不到，此时只要强制行动做完
	# rules-gaps8：首位被清掉时只清那一格，追加行动的格子照常出手（木桩 937），上限不再按 first_cleared 去掉 plus
	check(name + ".t1_enemy_actions", (t1_times >= forced + normal and t1_times <= forced + normal + plus) or (logic.is_lost() and t1_times == forced), [forced, first_cleared, got[1]])
	# 神魔战场的军团敌群（676～693，三四名杂兵）与嘤族之光 739：行动者集合取决于随机的技能选择和谁先被打倒，参照固定掷骰 0.5，不比这一项
	if oracle_half or not RANDOM_AI_TROOPS.has(int(c.troop)):
		if oracle_half and RANDOM_AI_TROOPS.has(int(c.troop)):
			_strict_random_set_checks += 1
		check(name + ".t1_enemy_set", enemies_of.call(got[1]) == enemies_of.call(want[1]), [got[1], want[1]])
	# 事件强制行动（339）逐条比 [行动者, 技能]：都在第 1 回合最先，含非首敌（军团 676 第 1 回合 e3 强制 3813，沙僧50 内容批 P2-C2）
	var want_forced: Array = c.actions.filter(func(a): return int(a.turn) == 1 and bool(a.forced)).map(func(a): return [str(a.subject), int(a.skill)])
	# 强制行动不在回合开头、而是某次行动里排的（六耳猕猴 321「模仿」856 的 After Eval：856 之后紧接强制 1）：
	# 比参照第 1 回合从头到最后一次强制行动为止的整段
	var t1_ref: Array = c.actions.filter(func(a): return int(a.turn) == 1)
	var last_forced := -1
	for i in range(t1_ref.size()):
		if bool(t1_ref[i].forced):
			last_forced = i
	if last_forced >= 0 and t1_ref.slice(0, last_forced + 1).any(func(a): return not bool(a.forced)):
		want_forced = t1_ref.slice(0, last_forced + 1).map(func(a): return [str(a.subject), int(a.skill)])
	if not want_forced.is_empty():
		check(name + ".t1_forced_all", got[1].slice(0, want_forced.size()) == want_forced, [got[1], want_forced])
	# 第 2 回合（战斗没结束时）：守层者照常行动一次（技能随机，不比）；有追加行动特性（61，几率）的敌人，每条特性最多再多一次（怨毒集合体 10%）
	if not got[2].is_empty():
		var times: int = got[2].filter(func(x): return x[0] == "e0").size()
		# 「模仿」856 这类 After Eval 每用一次带出一次强制行动，不算守层者自己的行动
		times -= got[2].filter(func(x): return x[0] == "e0" and not XBattleLogic.after_eval_force_of(XDB.rec("Skills", int(x[1]))).is_empty()).size() if XBattleLogic.SKILL_AFTER_EVAL_FORCE else 0
		# Another enemy can kill the party before e0 acts; e0 can also die first.
		var must_act := e0.is_alive() and not logic.is_lost() and t2_usable
		check(name + ".t2_enemy_once", times >= (1 if must_act else 0) and times <= 1 + plus, [got[2], e0.is_alive(), logic.is_lost(), t2_usable, t2_tp])
	# 附加伤害：守层者用过 8111（加上 1460）之后，每次命中活着的目标都按 [攻击, 魔攻] 附加
	# （十层守层者第 1 回合先强制 500，那时还没有 1460，不附加）
	var extras := []
	var established := false
	for l in logs:
		if l.type == "action" and l.user == e0 and int(l.skill.id) == 8111:
			established = true
		# 没有 HP 伤害的技能（540 等第 1 回合强制 3813 只加状态）两边都不附加，不算命中
		if established and l.type == "hit" and l.user == e0 and not l.missed and not l.evaded and l.target != e0 \
				and int(l.skill.get("damage", {}).get("type", 0)) != 0:
			extras.append(l.get("extra", []))
	var want_extra := []
	for inv in c.invokes:
		if inv.subject == "e0" and inv.target != "e0" and float(inv.hpBefore) > 0.0 and inv.userStates.has(1460.0) \
				and int(XDB.rec("Skills", int(inv.skill)).get("damage", {}).get("type", 0)) != 0:
			want_extra = [float(inv.userAtk), float(inv.userMat)]
	var e0_idle2: bool = not t2_usable and not got[2].any(func(x): return x[0] == "e0")
	if e0_idle2 and (oracle_half or not RANDOM_AI_TROOPS.has(int(c.troop))):
		# 第 2 回合没有可用行动、没出手：这一局没有命中，也就没有附加伤害（参照那局出手了，不比参照值）
		check(name + ".extra_idle", extras.is_empty(), [extras, t2_tp])
	elif (oracle_half or not RANDOM_AI_TROOPS.has(int(c.troop))) and not more_slots:
		if oracle_half and RANDOM_AI_TROOPS.has(int(c.troop)):
			_strict_random_extra_checks += 1
		check(name + ".extra", extras.is_empty() if want_extra.is_empty() else (not extras.is_empty() and extras.all(func(x): return x == want_extra)), [extras, want_extra])
	else:
		# 随机技能的敌群（军团、嘤族之光 739）：命中次数随技能与谁先倒下而变，但每一次实际命中都要带精确的 [攻击, 魔攻]
		# （参照有命中时就是参照值；参照没命中时是守层者自己的攻击／魔攻）。没有命中时记下来，全套另要求 739 至少有一例确有命中（_extra_hits）
		var own := [float(int(e0.atk)), float(int(e0.mat))]
		var expect: Array = want_extra if not want_extra.is_empty() and not more_slots else own
		check(name + ".extra_value", extras.all(func(x): return x == expect), [extras, want_extra, own])
		if int(c.troop) == 739:
			_seen739 = true
			if not extras.is_empty() and not want_extra.is_empty():
				_extra_hits += 1


## 条件与目标的细项（不依赖参照数据）
func _unit_checks() -> void:
	# fix5：六耳猕猴 321「模仿」856 的 After Eval 强制普通攻击。开（默认）：第 1 回合 856 之后紧接强制 1 打同一目标；
	# 回退（SKILL_AFTER_EVAL_FORCE = false）：只有 856，没有强制行动
	for on in [true, false]:
		if on:
			XBattleLogic.SKILL_AFTER_EVAL_FORCE = true
		else:
			XBattleLogic.SKILL_AFTER_EVAL_FORCE = false
		var lg := setup(321)
		var cmds := {}
		for a in lg.actors:
			cmds[a] = [XDB.rec("Skills", 1), lg.enemies[0]]
		var acts: Array = lg.run_turn(cmds).filter(func(l): return l.type == "action" and l.user == lg.enemies[0]).map(func(l): return int(l.skill.id))
		check("mimic856.after_eval_%s" % ("on" if on else "off"), (acts.slice(0, 2) == [856, 1]) if on else (acts == [856]), acts)
	XBattleLogic.SKILL_AFTER_EVAL_FORCE = true
	var logic := setup(4)
	_extra_once_scope_checks(logic)
	# rules-gaps8：强制行动清掉首位时只用掉一格（take_cleared 第二次返回 false，cleared_action 照旧可查）；
	# 回退（CLEAR_ALL_SLOTS = true）：同一人每个行动位都放弃
	for all_slots in [false, true]:
		if all_slots:
			XBattleLogic.CLEAR_ALL_SLOTS = true
		else:
			XBattleLogic.CLEAR_ALL_SLOTS = false
		var e0: XBattler = logic.enemies[0]
		logic._cleared = {e0: true}
		logic._cleared_used = {}
		var takes := [logic.take_cleared(e0), logic.take_cleared(e0), logic.take_cleared(logic.actors[0])]
		check("cleared_slot.%s" % ("all" if all_slots else "one"), takes == ([true, true, false] if all_slots else [true, false, false])
			and logic.cleared_action(e0), takes)
	XBattleLogic.CLEAR_ALL_SLOTS = false
	logic._cleared = {}
	logic._cleared_used = {}
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
	# 与 drop_record_probe 的有效调用链一致：KRZ 已热身列表到 refresh 才更新。
	e0.param_refresh()
	var hp0 := t.hp
	# Exercise the public action owner with a genuine compiled zero formula.
	var probe := XDB.rec("Skills", 2).duplicate(true)
	probe.damage.type = 1
	probe.effects = []
	var r := logic.apply(e0, probe, t)
	check("establish.hp", is_equal_approx(t.hp, maxf(0.0, hp0 - e0.atk - e0.mat)), [hp0, t.hp, e0.atk, e0.mat])
	check("establish.extra", r.get("extra", []) == [float(e0.atk), float(e0.mat)], r)


## 审查第 75 期 P1-1：O-247 的 EXTRA_ONCE 只认 CE1365。数据里「强制出的技能效果 44 又指回自己」的公共事件逐个造一次
## 「正在跑该公共事件时，强制出来的行动收尾预约」：1365 开关打开时不预约、关掉时预约；其余（CE28 风怒、CE1154 雪岭舞、
## 堕天一击等概率连发）开关开着也照原版预约，每次再放都重掷
func _extra_once_scope_checks(logic: XBattleLogic) -> void:
	var self_ces := {}
	var ces: Array = XDB.table("CommonEvents")
	for id in range(1, ces.size()):
		var ce := XDB.rec("CommonEvents", id)
		if ce.is_empty():
			continue
		for cmd in ce.get("list", []):
			if int(cmd.get("code", 0)) != 339:
				continue
			var sk := XDB.rec("Skills", int(cmd.parameters[2]))
			for e in sk.get("effects", []):
				if int(e.code) == 44 and int(e.dataId) == id:
					self_ces[id] = sk
	check("extra_once.self_ce_found", self_ces.has(1365) and self_ces.has(28) and self_ces.has(1154) and self_ces.size() >= 11, self_ces.keys())
	var saved_runner = logic._runner
	var default_once := XBattleCommonEvent.EXTRA_ONCE
	for once in [true, false]:
		XBattleCommonEvent.EXTRA_ONCE = once
		var got := {}
		for id in self_ces:
			var r := XBattleEventRunner.new(logic, [], null)
			r.set_meta("common_event", id)
			logic._runner = r
			if logic.has_meta("battle_ce"):
				logic.remove_meta("battle_ce")
			XBattleCommonEvent.reserve_action(logic, logic.enemies[0], self_ces[id], [logic.actors[0]])
			got[id] = int(logic.get_meta("battle_ce", 0)) == id
		var bad := got.keys().filter(func(id): return got[id] != (not once or id != 1365))
		check("extra_once.only_1365_%s" % ("on" if once else "off"), bad.is_empty(), {"bad": bad, "got": got})
	XBattleCommonEvent.EXTRA_ONCE = default_once
	logic._runner = saved_runner
	if logic.has_meta("battle_ce"):
		logic.remove_meta("battle_ce")
	if logic.has_meta("battle_ce_user"):
		logic.remove_meta("battle_ce_user")


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("MORE_SLOT_CASES=", _more_slot_cases)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "oracleHalf": oracle_half, "strictRandomSetChecks": _strict_random_set_checks, "strictRandomExtraChecks": _strict_random_extra_checks}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
