extends Node
## 【cc·T162】配队器（tests/virtual_player/team_builder.gd）：四个模板的职责构成、档位规则（D265 取消弱者人数下限后，艰险无超强者且不再限制强者数；九死起超强者 ≤ super_cap）、
## 随机队合法且互不相同且种子定住、最强队合法、缺职责时报出来而不静默补。
## 【cc·T328】辅助位先保一名会复活的（最强队、随机队）；虚拟玩家出手层：有人倒下时会复活的人去复活，
## 还轮得到会复活的人时别人不拿道具，没人能救时才用复活道具；开关关掉回原自动战斗。

const TB := preload("res://tests/virtual_player/team_builder.gd")
const VPLogic := preload("res://tests/virtual_player/vp_battle_logic.gd")

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	XTianqiSkills.reload_table()
	XTianqiBase.clear_cache()
	for diff in ["xunchang", "jianxian", "jiusi", "zhengdao"]:
		_difficulty(diff)
	_rules()
	_revive_team()
	_revive_decision()
	_smart_ai_revive_states()
	_swap_out_by_damage()
	var rep := TB.report("jianxian")
	print("TB_REPORT ", JSON.stringify(rep))
	print("TB_STRONGEST ", JSON.stringify(TB.strongest_all("jianxian")))
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _difficulty(diff: String) -> void:
	var cand := TB.candidates(diff)
	_check("%s.candidates_have_all_roles" % diff, not (cand["输出"] as Array).is_empty() and not (cand["坦克"] as Array).is_empty() and not (cand["辅助"] as Array).is_empty(), [diff, cand["输出"].size(), cand["坦克"].size(), cand["辅助"].size()])
	var pool: Dictionary = XTianqi.pool(diff)
	var all := []
	for t in pool:
		all.append_array(pool[t])
	var in_pool := true
	var role_ok := true
	for r in cand:
		for id in cand[r]:
			in_pool = in_pool and all.has(id)
			role_ok = role_ok and TB.role_of(int(id)) == r
	_check("%s.candidates_in_pool_and_role" % diff, in_pool and role_ok)
	for tpl in TB.TEMPLATES:
		var a := TB.random_teams(tpl, 6, 20261118, diff)
		var b := TB.random_teams(tpl, 6, 20261118, diff)
		var c := TB.random_teams(tpl, 6, 99, diff)
		var ok := not a.is_empty()
		var distinct := {}
		for team in a:
			ok = ok and TB.legal(team, diff) and TB.matches(team, tpl)
			var k: Array = team.duplicate()
			k.sort()
			distinct[str(k)] = true
		_check("%s.%s.random_legal_and_matches" % [diff, tpl], ok, a)
		_check("%s.%s.random_distinct" % [diff, tpl], distinct.size() == a.size())
		_check("%s.%s.random_same_seed_same" % [diff, tpl], JSON.stringify(a) == JSON.stringify(b))
		_check("%s.%s.random_other_seed_differs" % [diff, tpl], JSON.stringify(a) != JSON.stringify(c))
		var s := TB.strongest(tpl, diff)
		_check("%s.%s.strongest_legal_and_matches" % [diff, tpl], not s.is_empty() and TB.legal(s, diff) and TB.matches(s, tpl), s)


func _rules() -> void:
	# D265：五档取消弱者人数下限（min_weak=0），艰险不再限制强者人数，只保留不出超强者
	var ok := true
	for tpl in TB.TEMPLATES:
		for team in TB.random_teams(tpl, 12, 5, "jianxian"):
			ok = ok and team.all(func(x): return not XTianqiSkills.is_super(int(x), true))
	_check("jianxian.no_super_d265", ok)
	_check("jianxian.min_weak_field_0_d265", TB.min_weak_field("jianxian") == 0)
	# D265：全强者（4 强）在艰险合法；超强者、重复、人数不对仍拒绝
	var strong_ids: Array = XTianqi.pool("jianxian")[XTier.STRONG]
	var weak_ids: Array = XTianqi.pool("jianxian")[XTier.WEAK]
	var super_ids: Array = XTianqi.pool("jiusi")[XTier.SUPER]
	_check("legal.accepts_4_strong_d265", TB.legal([strong_ids[0], strong_ids[1], strong_ids[2], strong_ids[3]], "jianxian"))
	_check("legal.rejects_super_in_jianxian", not TB.legal([super_ids[0], strong_ids[0], weak_ids[0], weak_ids[1]], "jianxian"))
	_check("legal.rejects_duplicate", not TB.legal([weak_ids[0], weak_ids[0], weak_ids[1], weak_ids[2]], "jianxian"))
	_check("legal.accepts_2_strong_2_weak", TB.legal([strong_ids[0], strong_ids[1], weak_ids[0], weak_ids[1]], "jianxian"))
	_check("legal.rejects_wrong_size", not TB.legal([weak_ids[0], weak_ids[1], weak_ids[2]], "jianxian"))
	# 缺职责不静默补：同一个函数在极端规则下配不出来就返回空（用一个不存在的模板键之外的做法：把候选抽干）
	var rep := TB.report("jianxian")
	_check("report.has_counts_and_notes", rep.has("counts") and rep.has("short") and rep.has("notes"))


## T328：辅助位先保一名会复活的
func _revive_team() -> void:
	var cand := TB.candidates("jianxian")
	var rv: Array = (cand["辅助"] as Array).filter(func(x): return TB.can_revive(int(x)))
	_check("revive.detects_from_data", TB.can_revive(16) and TB.revive_skill_names(16).any(func(x): return str(x).begins_with("4549")) and not TB.can_revive(3), [TB.revive_skill_names(16), TB.revive_skill_names(3)])
	_check("revive.jianxian_has_reviver_supports", rv.size() >= 2, rv)
	# 核查 P2-1：玉兔精沉鱼萝雁要萝卜 1722，不算会复活；P1-1：绯红蔷薇 30 级还没学复活（35 级学圣光救赎）
	_check("revive.item_bound_not_counted", not TB.can_revive(77) and not TB.revive_item_bound(77).is_empty(), [TB.revive_skill_names(77), TB.revive_item_bound(77)])
	_check("revive.by_level", TB.can_revive(117) and not TB.can_revive(117, 30) and TB.can_revive(117, 35), [TB.revive_skill_names(117, 30), TB.revive_skill_names(117, 35)])
	var ok := true
	var rand_ok := true
	for tpl in TB.TEMPLATES:
		if not TB.TEMPLATES[tpl].has("辅助"):
			continue
		ok = ok and TB.strongest(tpl, "jianxian").any(func(x): return TB.can_revive(int(x)))
		for team in TB.random_teams(tpl, 6, 7, "jianxian"):
			rand_ok = rand_ok and (team as Array).any(func(x): return TB.can_revive(int(x)))
	_check("revive.strongest_has_reviver", ok, TB.strongest_all("jianxian"))
	_check("revive.random_has_reviver", rand_ok)
	TB.REVIVE_FIRST = false
	var off_ok := true
	for tpl in TB.TEMPLATES:
		var s := TB.strongest(tpl, "jianxian")
		off_ok = off_ok and not s.is_empty() and TB.legal(s, "jianxian") and TB.matches(s, tpl)
	TB.REVIVE_FIRST = true
	_check("revive.switch_off_still_legal", off_ok)
	var rep := TB.report("jianxian")
	_check("revive.report_lists_revivers", rep.has("revivers") and rep.revivers.has("16") and rep.has("team_revive"), rep.get("team_revive"))


## T328：出手层（克莱德 16 会次级复活术；艾坤 3 倒下；涅斐莉 32 不会复活）
func _revive_decision() -> void:
	var s := XState.new_game(XTianqi.legacy_of("jianxian"), 16, [3, 32])
	s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian"}   # 核查 P1-3：天启篇档（不设＝西游档规则）
	XState._become_current(s)
	s.actor_max_level = 81
	for id in [16, 3, 32]:
		s.actor(id).change_level_mv(81)
		s.actor(id).recover_all()
	s.items[183] = 2
	var l = VPLogic.new()
	l.setup(4, s, XBattleRandom.create("0000000000007328"))
	l.auto = true
	l.start_turn()
	var by := {}
	for b in l.actors:
		by[int(b.actor_id)] = b
	_check("decision.setup_has_three", by.has(16) and by.has(3) and by.has(32), by.keys())
	if not (by.has(16) and by.has(3) and by.has(32)):
		return
	var victim: XBattler = by[3]
	victim.add_state(1)
	_check("decision.victim_dead", victim.is_dead())
	# 1. 不会复活的人、会复活的还轮得到：不拿道具
	var c32: Array = l.decide(by[32])
	_check("decision.no_item_while_reviver_waits", not VPLogic.revives(c32[0] if c32[0] is Dictionary else {}), [c32[0].get("id") if c32[0] is Dictionary else null])
	# 2. 会复活的人：放复活技能，对准倒下的人
	var c16: Array = l.decide(by[16])
	_check("decision.reviver_revives", c16[0] is Dictionary and VPLogic.revives(c16[0]) and (c16[1] == victim or c16[1] == null), [c16[0].get("id") if c16[0] is Dictionary else null])
	# 3. 同一回合这个人已安排复活：别人不再排队
	l.current_order.erase(by[16])
	var c32b: Array = l.decide(by[32])
	_check("decision.no_double_revive", not (c32b[0] is Dictionary and VPLogic.revives(c32b[0])), [c32b[0].get("id") if c32b[0] is Dictionary else null])
	# 4. 下一回合没人会救（复活的人不在本回合顺序里）：不会复活的人用复活道具
	l._planned_turn = -1
	l.turn += 1
	var c32c: Array = l.decide(by[32])
	_check("decision.item_when_no_reviver", c32c[0] is Dictionary and int(c32c[0].get("id", 0)) == 183 and c32c[1] == victim, [c32c[0].get("id") if c32c[0] is Dictionary else null])
	# 4b. 会复活的人被控住（不能动）：不算「还轮得到的复活者」，别人可以用道具（核查 P2-2）
	l._planned_turn = -1
	l._item_turn = -1
	l.turn += 1
	l.current_order.append(by[16])
	by[16].add_state(29)   # 29 眩晕（限制 4）
	var stunned: bool = not VPLogic.can_act(by[16])
	var c32d: Array = l.decide(by[32])
	_check("decision.stunned_reviver_not_waited", stunned and c32d[0] is Dictionary and int(c32d[0].get("id", 0)) == 183, [stunned, c32d[0].get("id") if c32d[0] is Dictionary else null])
	var casts_before: int = l.revive_casts
	l.decide(by[16])
	_check("decision.stunned_no_count", l.revive_casts == casts_before)
	# 5. 开关关掉：会复活的人交回原自动战斗（这里只看不走复活层的计数）
	VPLogic.REVIVE = false
	var before: int = l.revive_casts
	l.decide(by[16])
	VPLogic.REVIVE = true
	_check("decision.switch_off_no_vp_revive", l.revive_casts == before)


## 核查 P1-3：带公共事件的 6 个复活技，玩家的智能 AI 放不放——天启篇档放（重构卡去掉了公共事件或 tq_ce_ok 放行），西游档不放（原版 legalCandidate 只放伤害类公共事件技）
func _smart_ai_revive_states() -> void:
	var ids := {4549: 16, 622: 31, 825: 31, 4829: 81, 5782: 117}
	var tq := {}
	var xy := {}
	for flag in [true, false]:
		for sid in ids:
			var aid: int = ids[sid]
			var s := XState.new_game(XTianqi.legacy_of("jianxian"), aid, [3])
			if flag:
				s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian"}
			XState._become_current(s)
			s.actor_max_level = 81
			s.actor(aid).change_level_mv(81)
			s.actor(aid).recover_all()
			var l := XBattleLogic.new()
			l.setup(4, s, XBattleRandom.create("0000000000007329"))
			var me: XActor = null
			for b in l.actors:
				if int(b.actor_id) == aid:
					me = b
			var rec := {}
			for sk in me.skills():
				if int(sk.id) == sid:
					rec = sk
			var ok := not rec.is_empty() and XSmartAI.new(l, me).legal(rec, false)
			(tq if flag else xy)[sid] = ok
	print("T328_SMART_AI_REVIVE 天启篇 ", tq, " 西游档 ", xy)
	_check("smart_ai.tianqi_allows_ce_revives", tq.values().all(func(v): return v), tq)


## 【T343】换人挑被换下的：有实测出伤按出伤从低到高、出伤第一排最后；没实测按定位（非输出位先）
func _swap_out_by_damage() -> void:
	var field := [11, 22, 33, 44]
	var dmg := {11: 900.0, 22: 5000.0, 33: 100.0, 44: 700.0}
	var order: Array = TB.swap_out_order(field, dmg)
	_check("swap_out.measured_lowest_first", order == [33, 44, 11, 22], order)
	_check("swap_out.never_top_damage_first", int(order[0]) != 22 and int(order[-1]) == 22, order)
	# 带了没出伤的人（0）：他排最前；全是 0 或空＝没实测，退回按定位，结果只含原来那几个人且稳定
	var none: Array = TB.swap_out_order(field, {})
	_check("swap_out.fallback_same_members", none.size() == 4 and none.all(func(x): return field.has(x)), none)
	var roles: Array = none.map(func(x): return TB.role_of(int(x)))
	var seen_out := false
	var ok := true
	for r in roles:
		if r == "输出":
			seen_out = true
		elif seen_out:
			ok = false
	_check("swap_out.fallback_non_output_first", ok, roles)
