extends Node
## 天启篇弱者专属词条批 0A 地基（XTianqiWeakAffix）专项：设计稿 v0.3 第二节第 6 条的 11 条断言＋v0.3.1 第二节四条，每条触发、不触发两面。
## 表里一条正式词条都没有，这里用 test_entries／test_guidable／register 注入一条测试条目和测试处理对象。

var results: Array = []
const SEED := "00000000005a0a0a"


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids() -> Array:
	return XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


var _snap := {}

func _state() -> XState:
	if _snap.is_empty():
		var w := _ids()
		var lineup := [w[0], w[1], w[2], w[3], w[5]]
		var s0 := XTianqi.start_new_game(3, "jianxian", lineup)
		XTianqi.take_pending()
		for id in lineup:
			XTianqi._joining = true
			s0.add_actor(int(id))
			XTianqi._joining = false
		s0.map_id = 4
		_snap = s0.to_dict()
	var s := XState.from_dict(_snap.duplicate(true))
	XState.current = s
	for a in s.members():
		a.recover_all()
	return s


func _logic(s: XState = null) -> XBattleLogic:
	if s == null:
		s = _state()
	var lg := XBattleLogic.new()
	lg.setup(2, s, XBattleRandom.create(SEED))
	for a in lg.actors:
		a.recover_all()
	return lg


## 夹具：给角色装上一件带特性的装备（第 1 格以后找空位），traits 用 MV 特性写法
func _wear_traits(a: XActor, traits: Array, slot := 3) -> void:
	a.keep_unequippable = true
	while a.equips.size() <= slot:
		a.equips.append(null)
	a.equips[slot] = {"kind": "armor", "base": 1, "name": "测试", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": traits, "etypeId": 4}
	a.param_mark_dirty()
	a.param_refresh()


func _exclusive(a: XActor, key: String, slot := 0) -> void:
	a.keep_unequippable = true
	while a.equips.size() <= slot:
		a.equips.append(null)
	var base = a.equips[slot] if a.equips[slot] is Dictionary else {"kind": "weapon", "base": 1, "etypeId": 1, "name": "测试兵器", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "wtypeId": 1}
	var inst: Dictionary = base.duplicate(true)
	inst[XTianqiWeakAffix.ITEM_KEY] = {"key": key}
	a.equips[slot] = inst
	a.param_mark_dirty()
	a.param_refresh()


func _attack(e: XEnemy, seq := true, repeats := 1) -> Dictionary:
	var sk: Dictionary = XDB.rec("Skills", 1).duplicate(true)  # 普通攻击：魔法命中类型、单体、带行动序列
	if not seq:
		sk.erase("yepSeq")
		sk.repeats = repeats
	elif repeats > 1:
		var tgt: Array = sk.yepSeq.target
		for i in repeats - 1:
			tgt.append(["action effect", []])
	return sk


func _hits(logs: Array) -> Array:
	return logs.filter(func(x): return x is Dictionary and str(x.get("type", "")) == "hit")


func _targets_hit(logs: Array) -> Array:
	return _hits(logs).map(func(x): return x.target)


func _digest(lg: XBattleLogic) -> String:
	var out := []
	for b in lg.actors + lg.enemies:
		out.append("%s:%.3f/%.3f/%.3f/%s" % [b.display_name(), b.hp, b.mp, b.tp, str(b.state_ids)])
	return "|".join(out) + "#" + str(lg.turn)


func _log_digest(logs: Array) -> String:
	var out := []
	for x in logs:
		if x is Dictionary:
			var t = x.get("target")
			out.append("%s>%s>%s" % [str(x.get("type", "")), t.display_name() if t is XBattler else "", str(x.get("hp", ""))])
	return ",".join(out)


func _run() -> void:
	XMessageBox.auto = true
	seed(20261116)
	XTianqiWeakAffix.reload()
	_table()
	_guide_cover_reflect()      # 断言 1
	_multi_segment_fallback()   # 断言 2、3；v0.3.1 一
	_guide_exclusions()         # 断言 4 的前半、不可引导／三层／混乱／强制
	_parity_not_guidable()      # 断言 4 的后半（固定种子逐字节）
	_kinds_and_roots()          # 断言 5、6、7
	_turn_counts()              # 断言 8
	_equip_scope()              # 断言 9
	_switch_save()              # 断言 10
	_parity_idle_entry()        # 断言 11
	_horseman_and_hunzi()       # v0.3.1 二、三
	_segment_root_only()        # T035：segment_target 只管主动根；非序列路不覆写 t、两路对称
	_boss_badges_drop()         # 第 4 条那一句、v0.3.1 四、掉落接口
	XTianqiWeakAffix.test_entries = {}
	XTianqiWeakAffix.test_guidable = []
	XTianqiWeakAffix.ENABLED = true
	XTianqiWeakAffix.COUNTER_NO_HUNZI_MARK = true
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", str(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _table() -> void:
	var d := XTianqiWeakAffix.data()
	_check("table_loads", not d.is_empty() and d.get("entries", null) is Dictionary, d.keys())
	_check("table_no_entries_yet", (d.entries as Dictionary).is_empty())  # 具体词条等基础数值定了再做（D72）
	_check("table_no_guidable_yet", (d.get("guidable_skills", []) as Array).is_empty())  # 默认一个都不可引导（D68）
	_check("table_drop_rate_placeholder", is_equal_approx(float(XTianqiWeakAffix.rules().get("drop_rate", 0)), 0.3))


## 断言 1：引导者、原生掩护者、带反射的人同时在场——反射按引导者判，掩护不换人，实际受击者就是引导者
func _guide_cover_reflect() -> void:
	XTianqiWeakAffix.test_guidable = [1]
	var lg := _logic()
	var e: XEnemy = lg.enemies[0]
	var orig: XActor = lg.actors[0]
	var g: XActor = lg.actors[1]
	var cover: XActor = lg.actors[2]
	_wear_traits(orig, [{"code": 22, "dataId": 5, "value": 1.0}])  # 原目标魔法反射 100%：按原目标判就一定反射
	_wear_traits(cover, [{"code": 62, "dataId": 2, "value": 1.0}])  # 掩护
	g.hp = maxf(1.0, floorf(g.mhp / 5.0))  # 引导者濒死：没被引导时掩护会换人
	lg.start_turn()
	XTianqiWeakAffix.mark_guide(lg, e, g, "test")
	var logs := lg.act(e, _attack(e), orig)
	var hit := _targets_hit(logs)
	_check("guide_hits_guider", hit.size() == 1 and is_same(hit[0], g), [hit.map(func(x): return x.display_name())])
	_check("guide_no_reflect", logs.filter(func(x): return x is Dictionary and x.get("type") == "reflect").is_empty())
	_check("guide_cover_skipped", not hit.has(cover))
	# 反面：同样的场面不引导——掩护换人（证明上面那条真咬得住）
	var lg2 := _logic()
	var e2: XEnemy = lg2.enemies[0]
	var g2: XActor = lg2.actors[1]
	_wear_traits(lg2.actors[2], [{"code": 62, "dataId": 2, "value": 1.0}])
	g2.hp = maxf(1.0, floorf(g2.mhp / 5.0))
	lg2.start_turn()
	var hit2 := _targets_hit(lg2.act(e2, _attack(e2), g2))
	_check("no_guide_cover_swaps", hit2.size() == 1 and is_same(hit2[0], lg2.actors[2]), hit2.map(func(x): return x.display_name()))
	# 反面：引导者自己带反射——按引导者判，反射一次
	var lg3 := _logic()
	var e3: XEnemy = lg3.enemies[0]
	var g3: XActor = lg3.actors[1]
	_wear_traits(g3, [{"code": 22, "dataId": 5, "value": 1.0}])
	lg3.start_turn()
	XTianqiWeakAffix.mark_guide(lg3, e3, g3, "test")
	var logs3 := lg3.act(e3, _attack(e3), lg3.actors[0])
	var refl := logs3.filter(func(x): return x is Dictionary and x.get("type") == "reflect")
	_check("guide_reflect_by_guider", refl.size() == 1 and is_same(refl[0].target, g3), refl.size())
	# 多个引导者：取出战栏靠前的
	var lg4 := _logic()
	var e4: XEnemy = lg4.enemies[0]
	lg4.start_turn()
	XTianqiWeakAffix.mark_guide(lg4, e4, lg4.actors[3], "test")
	XTianqiWeakAffix.mark_guide(lg4, e4, lg4.actors[2], "test")
	var hit4 := _targets_hit(lg4.act(e4, _attack(e4), lg4.actors[0]))
	_check("guide_front_slot_wins", hit4.size() == 1 and is_same(hit4[0], lg4.actors[2]), hit4.map(func(x): return x.display_name()))
	XTianqiWeakAffix.test_guidable = []


## T035：segment_target 只认 ROOT——根执行完的追加（FOLLOW_FULL 打满整招、走序列路）打引导者时，不再拿这一根的引导把它改回原目标
func _segment_root_only() -> void:
	var lg := _logic()
	var e: XEnemy = lg.enemies[0]
	var orig: XActor = lg.actors[0]
	var g: XActor = lg.actors[1]
	lg.start_turn()
	XTianqiWeakAffix.root_begin(lg, e, {"id": 1})
	var f := XTianqiWeakAffix._frame(lg)
	f.guide = {"guider": g, "orig": orig, "active": true, "reverted": false}
	g.hp = 0.0
	g.add_state(1)  # 引导者已倒下：主动根里的下一段会回原目标
	_check("seg_root_reverts", is_same(XTianqiWeakAffix.segment_target(lg, e, {"id": 1}, g), orig))
	f.guide = {"guider": g, "orig": orig, "active": true, "reverted": false}
	f.finish = []
	XTianqiWeakAffix.set_kind(lg, XTianqiWeakAffix.FOLLOW)
	_check("seg_follow_passthrough", is_same(XTianqiWeakAffix.segment_target(lg, e, {"id": 1}, g), g) and bool(f.guide.active) and f.finish.is_empty(), f.guide)
	# 实跑序列路（追加的 FOLLOW_FULL 有序列就走 XActionSequence）：打的是倒下的引导者，跳过；不会回头打原目标
	var hp0 := orig.hp
	var logs := XActionSequence.create(lg, e, _attack(e, true, 2), [g]).run()
	_check("seg_follow_no_reuse_guide", _targets_hit(logs).is_empty() and orig.hp == hp0 and bool(f.guide.active), _targets_hit(logs).map(func(x): return x.display_name()))
	for k in [XTianqiWeakAffix.RECAST, XTianqiWeakAffix.COUNTER, XTianqiWeakAffix.DERIVED]:
		XTianqiWeakAffix.push_kind(lg, k)
		_check("seg_%s_passthrough" % k, is_same(XTianqiWeakAffix.segment_target(lg, e, {"id": 1}, g), g))
		XTianqiWeakAffix.pop_kind(lg)
	XTianqiWeakAffix.root_end(lg)
	# 非序列路与序列路对称（T035：非序列路不再把 segment_target 的结果写回循环变量 t）：同一场面两路打到的人逐段一样
	XTianqiWeakAffix.test_guidable = [1]
	var seen := {}
	for seq in [false, true]:
		var lgs := _logic()
		var es: XEnemy = lgs.enemies[0]
		var os: XActor = lgs.actors[0]
		var gs: XActor = lgs.actors[1]
		gs.hp = 1.0
		lgs.start_turn()
		XTianqiWeakAffix.mark_guide(lgs, es, gs, "test")
		seen[seq] = _targets_hit(lgs.act(es, _attack(es, seq, 4), os)).map(func(x): return lgs.actors.find(x))
	_check("seg_rep_seq_symmetric", seen[false] == seen[true] and seen[false] == [1, 0, 0, 0], seen)
	XTianqiWeakAffix.test_guidable = []


## 断言 2、3 与 v0.3.1 第二节第 1 条：多段技第一段打倒引导者，后面的段回原目标、不换人不重掷；都倒了跳过。两种多段各一遍
func _multi_segment_fallback() -> void:
	XTianqiWeakAffix.test_guidable = [1]
	for seq in [false, true]:
		var tag := "seq" if seq else "rep"
		var lg := _logic()
		var e: XEnemy = lg.enemies[0]
		var orig: XActor = lg.actors[0]
		var g: XActor = lg.actors[1]
		var other: XActor = lg.actors[3]
		_wear_traits(lg.actors[2], [{"code": 62, "dataId": 2, "value": 1.0}])  # 场上另有掩护者
		g.hp = 1.0
		lg.start_turn()
		XTianqiWeakAffix.mark_guide(lg, e, g, "test")
		XTianqiWeakAffix.mark_guide(lg, e, other, "test2")  # 另一位「只打我」排在后面：中途不改找他
		var hit := _targets_hit(lg.act(e, _attack(e, seq, 3), orig))
		var names := hit.map(func(x): return x.display_name())
		_check("fallback_%s_first_guider" % tag, hit.size() == 3 and is_same(hit[0], g), names)
		_check("fallback_%s_rest_orig" % tag, hit.size() == 3 and is_same(hit[1], orig) and is_same(hit[2], orig), names)
		_check("fallback_%s_no_other_guider" % tag, not hit.has(other), names)
		_check("fallback_%s_guider_down" % tag, g.is_dead(), [g.hp, g.state_ids])  # 序列路：暂不倒下到 0 血，收尾时倒下
		# 都倒了：剩下的段跳过
		var lgb := _logic()
		var eb: XEnemy = lgb.enemies[0]
		var ob: XActor = lgb.actors[0]
		var gb: XActor = lgb.actors[1]
		gb.hp = 1.0
		ob.hp = 1.0
		lgb.start_turn()
		XTianqiWeakAffix.mark_guide(lgb, eb, gb, "test")
		var hitb := _targets_hit(lgb.act(eb, _attack(eb, seq, 3), ob))
		_check("both_down_%s_skip" % tag, hitb.size() == 2 and is_same(hitb[0], gb) and is_same(hitb[1], ob), hitb.map(func(x): return x.display_name()))
		_check("both_down_%s_orig_dead" % tag, ob.is_dead() and gb.is_dead(), [ob.hp, gb.hp])
	XTianqiWeakAffix.test_guidable = []


func _guide_exclusions() -> void:
	var lg := _logic()
	var e: XEnemy = lg.enemies[0]
	var orig: XActor = lg.actors[0]
	var g: XActor = lg.actors[1]
	lg.start_turn()
	XTianqiWeakAffix.mark_guide(lg, e, g, "test")
	var hit := _targets_hit(lg.act(e, _attack(e), orig))
	_check("unsigned_not_guided", hit.size() == 1 and is_same(hit[0], orig))  # 没签过的技能（默认）一律不可引导
	XTianqiWeakAffix.test_guidable = [1]
	var sk := _attack(e)
	XTianqiWeakAffix.root_begin(lg, e, sk)
	_check("layers_changed_not_guided", is_same(XTianqiWeakAffix.guide_targets(lg, e, sk, [orig], true)[0], orig))
	_check("forced_not_guided", is_same(XTianqiWeakAffix.guide_targets(lg, e, sk, [orig], false, true)[0], orig))
	var all := sk.duplicate(true)
	all.scope = 2
	_check("scope_all_not_guided", not XTianqiWeakAffix.guidable(all))
	_check("horseman_not_guided", not XTianqiWeakAffix.guidable({"tianqi_horseman": "plague", "scope": 1, "id": 1}))
	_check("guided_ok", is_same(XTianqiWeakAffix.guide_targets(lg, e, sk, [orig])[0], g))
	_check("guide_not_for_other_user", is_same(XTianqiWeakAffix.guide_targets(lg, lg.enemies[1] if lg.enemies.size() > 1 else e, sk, [orig])[0], orig if lg.enemies.size() > 1 else g))
	XTianqiWeakAffix.root_end(lg)
	lg.end_turn()
	_check("marks_cleared_turn_end", XTianqiWeakAffix.guiders_of(lg, e).is_empty())
	XTianqiWeakAffix.test_guidable = []


## 断言 4 后半：不可引导技能下，挂着标签和没挂结果逐字节一样（固定种子）
func _parity_not_guidable() -> void:
	var a := _logic()
	var b := _logic()
	a.start_turn()
	b.start_turn()
	XTianqiWeakAffix.mark_guide(a, a.enemies[0], a.actors[1], "test")
	var la := a.act(a.enemies[0], _attack(a.enemies[0]), a.actors[0])
	var lb := b.act(b.enemies[0], _attack(b.enemies[0]), b.actors[0])
	_check("parity_unguidable_logs", _log_digest(la) == _log_digest(lb), [_log_digest(la), _log_digest(lb)])
	_check("parity_unguidable_state", _digest(a) == _digest(b), [_digest(a), _digest(b)])


class Probe:
	extends RefCounted
	var calls := 0
	var hits_seen := []
	var kinds := []
	var counter_skill: Dictionary = {}
	var owner: XActor = null
	func root_end(logic, frame: Dictionary) -> Array:
		calls += 1
		kinds.append(XTianqiWeakAffix.kind(logic))
		hits_seen.append(frame.hits.size())
		var out := []
		if owner != null and not counter_skill.is_empty():
			for h in frame.hits:
				if is_same(h.target, owner) and XTianqiWeakAffix.take_turn(logic, owner, "probe_counter") and h.user.is_alive():
					out.append_array(XTianqiWeakAffix.derived_invoke(logic, owner, counter_skill, h.user))
		return out
	func badge(_logic, b) -> String:
		return "测试角标" if is_same(b, owner) else ""


func _kinds_and_roots() -> void:
	var lg := _logic()
	var e: XEnemy = lg.enemies[0]
	XTianqiWeakAffix.root_begin(lg, e, {"id": 1})
	_check("kind_root", XTianqiWeakAffix.kind(lg) == XTianqiWeakAffix.ROOT)
	XTianqiWeakAffix.push_kind(lg, XTianqiWeakAffix.COUNTER)
	_check("kind_counter", XTianqiWeakAffix.kind(lg) == XTianqiWeakAffix.COUNTER and XTianqiWeakAffix.not_own_action(lg))
	XTianqiWeakAffix.pop_kind(lg)
	XTianqiWeakAffix.set_kind(lg, XTianqiWeakAffix.FOLLOW)
	_check("kind_follow", XTianqiWeakAffix.kind(lg) == XTianqiWeakAffix.FOLLOW and not XTianqiWeakAffix.not_own_action(lg))
	# 断言 7：一根只消费一次（全体、多段都是一根）
	_check("root_take_once", XTianqiWeakAffix.take_root(lg, lg.actors[0], "k") and not XTianqiWeakAffix.take_root(lg, lg.actors[0], "k"))
	_check("root_take_other_owner", XTianqiWeakAffix.take_root(lg, lg.actors[1], "k"))
	XTianqiWeakAffix.root_end(lg)
	XTianqiWeakAffix.root_begin(lg, e, {"id": 1})
	_check("root_take_new_root", XTianqiWeakAffix.take_root(lg, lg.actors[0], "k"))
	XTianqiWeakAffix.root_end(lg)
	_check("kind_none_outside", XTianqiWeakAffix.kind(lg) == "")
	# 实跑：敌人打我方的直接命中只在主动根里记、追加阶段派生；派生打出去不再记命中、不连锁（断言 5 的「失败不消费」、断言 6）
	var lg2 := _logic()
	var e2: XEnemy = lg2.enemies[0]
	var me: XActor = lg2.actors[0]
	XTianqiWeakAffix.test_entries = {"probe": {"actor": int(me.actor_id), "enabled": true}}
	_exclusive(me, "probe")
	var p := Probe.new()
	p.owner = me
	p.counter_skill = XDB.rec("Skills", 1)
	XTianqiWeakAffix.register("probe", p)
	lg2.start_turn()
	var logs := lg2.act(e2, _attack(e2), me)
	_check("probe_called_once", p.calls == 1, p.calls)
	_check("probe_saw_direct_hit", p.hits_seen == [1], p.hits_seen)
	_check("probe_runs_as_derived", p.kinds == [XTianqiWeakAffix.DERIVED], p.kinds)
	var mine := _hits(logs).filter(func(x): return is_same(x.user, me))
	_check("derived_strike_out", mine.size() == 1 and is_same(mine[0].target, e2), mine.size())
	# 我方打敌人：敌人不是本人的对面目标，probe 只看到自己的主动根（0 条打到本人）、不再派生
	var before := p.calls
	var own := lg2.act(me, XDB.rec("Skills", 1), e2)
	_check("own_root_no_derived", p.calls == before + 1 and _hits(own).filter(func(x): return is_same(x.user, me)).size() == 1, p.hits_seen)
	# 同回合敌人再打：每回合 1 次用完，不再派生（失败不消费：命中没打出来时 take_turn 根本不调）
	var logs2 := lg2.act(e2, _attack(e2), me)
	_check("probe_turn_cap", _hits(logs2).filter(func(x): return is_same(x.user, me)).is_empty())
	# 没打中本人（打别人）：不消费次数
	lg2.end_turn()
	lg2.start_turn()
	lg2.act(e2, _attack(e2), lg2.actors[1])
	_check("miss_owner_not_consumed", XTianqiWeakAffix.turn_count(lg2, me, "probe_counter") == 0)
	XTianqiWeakAffix.register("probe", null)
	XTianqiWeakAffix.test_entries = {}


## 断言 8：多动、强制行动不重置每回合次数；只在回合开始、结束清
func _turn_counts() -> void:
	var lg := _logic()
	var a: XActor = lg.actors[0]
	lg.start_turn()
	_check("turn_take_first", XTianqiWeakAffix.take_turn(lg, a, "x"))
	for i in 3:  # 多动／强制行动：各开一根
		XTianqiWeakAffix.root_begin(lg, a, {"id": 1})
		XTianqiWeakAffix.root_end(lg)
	_check("turn_take_blocked_after_roots", not XTianqiWeakAffix.take_turn(lg, a, "x"))
	_check("turn_cap2", XTianqiWeakAffix.take_turn(lg, a, "y", 2) and XTianqiWeakAffix.take_turn(lg, a, "y", 2) and not XTianqiWeakAffix.take_turn(lg, a, "y", 2))
	lg.end_turn()
	_check("turn_reset_end", XTianqiWeakAffix.turn_count(lg, a, "x") == 0)
	lg.start_turn()
	_check("turn_take_next", XTianqiWeakAffix.take_turn(lg, a, "x"))
	# 上一根没收尾：开新回合时清掉，不带到下一根
	XTianqiWeakAffix.root_begin(lg, a, {"id": 1})
	lg.end_turn()
	lg.start_turn()
	_check("stale_root_cleared", XTianqiWeakAffix.kind(lg) == "")


## 断言 9：本人和别人各装一件、武器副手各一件、战中换装、助力位装着没上场
func _equip_scope() -> void:
	var lg := _logic()
	var me: XActor = lg.actors[0]
	var other: XActor = lg.actors[1]
	XTianqiWeakAffix.test_entries = {"k1": {"actor": int(me.actor_id), "enabled": true}, "k2": {"actor": int(me.actor_id), "enabled": false}}
	_exclusive(me, "k1", 0)
	_exclusive(me, "k1", 1)
	_check("weapon_offhand_once", XTianqiWeakAffix.keys_of(me) == ["k1"], XTianqiWeakAffix.keys_of(me))
	_check("owner_active", XTianqiWeakAffix.active_keys(lg, me) == ["k1"])
	_exclusive(other, "k1", 0)
	_check("other_inactive", XTianqiWeakAffix.active_keys(lg, other).is_empty())
	_check("other_text_gray", bool(XTianqiWeakAffix.text_state(other.equips[0], other, lg.state).gray) and str(XTianqiWeakAffix.text_state(other.equips[0], other, lg.state).reason) == "not_owner")
	_check("owner_text_ok", bool(XTianqiWeakAffix.text_state(me.equips[0], me, lg.state).ok))
	_exclusive(me, "k2", 1)
	_check("switch_off_entry_inactive", XTianqiWeakAffix.active_keys(lg, me) == ["k1"], XTianqiWeakAffix.active_keys(lg, me))
	_check("switch_off_text_gray", str(XTianqiWeakAffix.text_state(me.equips[1], me, lg.state).reason) == "off")
	# 库存：战中换装清零
	XTianqiWeakAffix.stock(lg, me, "k1").n = 3
	_check("stock_kept", int(XTianqiWeakAffix.stock(lg, me, "k1").get("n", 0)) == 3)
	me.equips[0] = null
	me.equips[1] = null
	_check("unequip_inactive", XTianqiWeakAffix.active_keys(lg, me).is_empty())
	XTianqiWeakAffix.root_begin(lg, me, {"id": 1})  # 根的边界上对一次签名
	XTianqiWeakAffix.root_end(lg)
	_exclusive(me, "k1", 0)
	_check("reequip_stock_zero", int(XTianqiWeakAffix.stock(lg, me, "k1").get("n", 0)) == 0)
	# 倒下清零
	XTianqiWeakAffix.stock(lg, me, "k1").n = 2
	me.hp = 0.0
	me.refresh_resources()
	lg._die(me)
	_check("dead_inactive", XTianqiWeakAffix.active_keys(lg, me).is_empty() and int(XTianqiWeakAffix.stock(lg, me, "k1").get("n", 0)) == 0)
	# 助力位：装着没上场不生效
	var h: XActor = lg.state.helper()
	if h != null:
		XTianqiWeakAffix.test_entries["kh"] = {"actor": int(h.actor_id), "enabled": true}
		_exclusive(h, "kh", 0)
		_check("helper_inactive", not lg.actors.has(h) and XTianqiWeakAffix.active_keys(lg, h).is_empty())
	else:
		_check("helper_exists", false, "没有助力位")
	# 战斗结束全清
	XTianqiWeakAffix.finish(lg)
	_check("finish_clears", not lg.has_meta(XTianqiWeakAffix.META))
	XTianqiWeakAffix.test_entries = {}


## 断言 10：开关关着存档、再打开读档：不报错、旧物品照常显示灰字、库存不恢复
func _switch_save() -> void:
	var s := _state()
	var me: XActor = s.members()[0]
	XTianqiWeakAffix.test_entries = {"k1": {"actor": int(me.actor_id), "enabled": false}}
	_exclusive(me, "k1", 0)
	_check("off_text_gray", str(XTianqiWeakAffix.text_state(me.equips[0], me, s).reason) == "off")
	var d := s.to_dict()
	XTianqiWeakAffix.test_entries["k1"].enabled = true
	var s2 := XState.from_dict(d)
	XState.current = s2
	var me2: XActor = s2.actor(int(me.actor_id))
	_check("load_keeps_item_key", XTianqiWeakAffix.item_key(me2.equips[0]) == "k1")
	var item2: Dictionary = me2.equips[0]
	_check("load_reenabled_text_ok", bool(XTianqiWeakAffix.text_state(item2, me2, s2).ok))
	me2.keep_unequippable = true
	var lg := XBattleLogic.new()
	lg.setup(2, s2, XBattleRandom.create(SEED))
	_check("load_stock_empty", XTianqiWeakAffix.stock(lg, me2, "k1").is_empty() if lg.actors.has(me2) else true)
	XTianqiWeakAffix.ENABLED = false
	_check("module_off_gray", str(XTianqiWeakAffix.text_state(item2, me2, s2).reason) == "off")
	_check("module_off_no_keys", XTianqiWeakAffix.active_keys(lg, me2).is_empty())
	XTianqiWeakAffix.ENABLED = true
	XTianqiWeakAffix.test_entries = {}
	# 原版档：一律不生效
	var w := XState.new()
	_check("xiyou_save_off", not XTianqiWeakAffix.on(w))


## 断言 11＋回退开关：固定种子下戴一条不会触发的专属打几回合，和没戴、和模块关掉都一样
func _parity_idle_entry() -> void:
	var digests := []
	for mode in ["none", "idle", "off"]:
		XTianqiWeakAffix.ENABLED = mode != "off"
		var lg := _logic()
		if mode == "idle":
			var me: XActor = lg.actors[0]
			XTianqiWeakAffix.test_entries = {"idle": {"actor": int(me.actor_id), "enabled": true}}
			_exclusive(me, "idle", 0)
			XTianqiWeakAffix.register("idle", RefCounted.new())  # 什么钩子都没有的处理对象
		var trace := []
		for i in 4:
			if lg.is_over():
				break
			var logs := lg.run_turn({})
			trace.append(_log_digest(logs) + "@" + _digest(lg))
		digests.append("\n".join(trace))
		XTianqiWeakAffix.register("idle", null)
		XTianqiWeakAffix.test_entries = {}
	XTianqiWeakAffix.ENABLED = true
	_check("parity_idle_vs_none", digests[0] == digests[1], [digests[0].left(300), digests[1].left(300)])
	_check("parity_off_vs_none", digests[0] == digests[2], [digests[0].left(300), digests[2].left(300)])
	_check("parity_ran_turns", digests[0].length() > 0)


## v0.3.1 第二节第 2、3 条：骑士主动技（horseman_strike）的直接命中也记；派生、原生反击打混子不记「打过混子」
func _horseman_and_hunzi() -> void:
	var lg := _logic()
	var e: XEnemy = lg.enemies[0]
	var me: XActor = lg.actors[0]
	var hs := {"tianqi_horseman": "plague", "key": "test", "coef": 1.0}
	XTianqiWeakAffix.root_begin(lg, e, hs)
	lg.horseman_strike(e, me, hs, 1.0, false)
	_check("horseman_hit_noted", XTianqiWeakAffix.hits_on(XTianqiWeakAffix._frame(lg), me) == 1)
	XTianqiWeakAffix.set_kind(lg, XTianqiWeakAffix.FOLLOW)
	lg.horseman_strike(e, me, hs, 1.0, false)
	_check("follow_hit_not_noted", XTianqiWeakAffix.hits_on(XTianqiWeakAffix._frame(lg), me) == 1)
	XTianqiWeakAffix.root_end(lg)
	# 混子标记：伪造一场瘟疫骑士战的最小数据，只看 hp_damage 记不记 hit_knight
	var f := {"line": "plague", "mode": "body", "knight": e, "hit_knight": {}, "queue": [], "shield_open": false, "broken_turn": -1}
	lg.set_meta(XTianqiHorsemen.META, f)
	var real := XTianqiHorsemen.active(lg)
	_check("hunzi_fixture", real)
	if real:
		XTianqiWeakAffix.root_begin(lg, me, {"id": 1})
		XTianqiHorsemen.hp_damage(lg, me, e, 1.0)
		_check("hunzi_root_marks", bool(XTianqiHorsemen.fight(lg).hit_knight.get(me, false)))
		XTianqiHorsemen.fight(lg).hit_knight.clear()
		XTianqiWeakAffix.push_kind(lg, XTianqiWeakAffix.DERIVED)
		XTianqiHorsemen.hp_damage(lg, me, e, 1.0)
		_check("hunzi_derived_no_mark", not XTianqiHorsemen.fight(lg).hit_knight.has(me))
		XTianqiWeakAffix.pop_kind(lg)
		XTianqiWeakAffix.root_begin(lg, e, {"id": 1})
		XTianqiWeakAffix.push_kind(lg, XTianqiWeakAffix.COUNTER)
		XTianqiHorsemen.hp_damage(lg, me, e, 1.0)
		_check("hunzi_counter_no_mark", not XTianqiHorsemen.fight(lg).hit_knight.has(me))
		XTianqiWeakAffix.COUNTER_NO_HUNZI_MARK = false  # 回退：原生反击打混子照旧记
		XTianqiHorsemen.hp_damage(lg, me, e, 1.0)
		_check("hunzi_counter_rollback_marks", bool(XTianqiHorsemen.fight(lg).hit_knight.get(me, false)))
		XTianqiWeakAffix.COUNTER_NO_HUNZI_MARK = true
		XTianqiWeakAffix.root_end(lg)
		XTianqiWeakAffix.root_end(lg)
	lg.remove_meta(XTianqiHorsemen.META)
	XTianqiWeakAffix.COUNTER_NO_HUNZI_MARK = false
	XTianqiWeakAffix.root_begin(lg, e, {"id": 1})
	XTianqiWeakAffix.push_kind(lg, XTianqiWeakAffix.COUNTER)
	_check("hunzi_counter_rollback", not XTianqiWeakAffix.not_own_action(lg))
	XTianqiWeakAffix.push_kind(lg, XTianqiWeakAffix.DERIVED)
	_check("hunzi_derived_still_unmarked_when_rollback", XTianqiWeakAffix.not_own_action(lg))
	XTianqiWeakAffix.root_end(lg)
	XTianqiWeakAffix.COUNTER_NO_HUNZI_MARK = true


func _boss_badges_drop() -> void:
	var lg := _logic()
	var e: XEnemy = lg.enemies[0]
	var ctl := -1
	var deb := -1
	for id in range(2, 400):
		var st := XDB.rec("States", id)
		if st.is_empty():
			continue
		if ctl < 0 and XEnemy.boss_control_state(id):
			ctl = id
		if deb < 0 and not XEnemy.boss_control_state(id) and XBossStatus.kind_of(st) == "Debuff":
			deb = id
	var was := e.boss_difficulty_boss
	e.boss_difficulty_boss = false
	_check("boss_rule_non_boss", XTianqiWeakAffix.boss_turns(e, deb, 2) == 2 and XTianqiWeakAffix.boss_turns(e, ctl, 3) == 3)
	e.boss_difficulty_boss = true
	_check("boss_debuff_ceil_half", XTianqiWeakAffix.boss_turns(e, deb, 2) == 1 and XTianqiWeakAffix.boss_turns(e, deb, 3) == 2 and XTianqiWeakAffix.boss_turns(e, deb, 1) == 1, [deb])
	_check("boss_control_floor_half", XTianqiWeakAffix.boss_turns(e, ctl, 3) == 1 and XTianqiWeakAffix.boss_turns(e, ctl, 1) == 0, [ctl])
	e.boss_difficulty_boss = was
	# 看得见：角标、日志出口
	var me: XActor = lg.actors[0]
	XTianqiWeakAffix.test_entries = {"probe": {"actor": int(me.actor_id), "enabled": true}}
	_exclusive(me, "probe")
	var p := Probe.new()
	p.owner = me
	XTianqiWeakAffix.register("probe", p)
	_check("badge_owner", XTianqiWeakAffix.badges(lg, me) == ["测试角标"])
	_check("badge_other_none", XTianqiWeakAffix.badges(lg, lg.actors[1]).is_empty())
	_check("say_line", XTianqiWeakAffix.say("x").type == "battle_text")
	XTianqiWeakAffix.register("probe", null)
	# 掉落接口：池空不掷、不写装备；开着的条目且本人能装才进池；同一件装备读档重掷结果一样
	var s := lg.state
	var weapon: Dictionary = {}
	for a in s.members():
		if a.equips.size() > 0 and a.equips[0] is Dictionary and str(a.equips[0].get("kind", "")) == "weapon":
			weapon = a.equips[0].duplicate(true)
			me = a
			break
	XTianqiWeakAffix.test_entries = {}
	if weapon.is_empty():
		_check("drop_weapon_found", false)
		return
	weapon.erase("tq_rng_n")
	var w0 := weapon.duplicate(true)
	_check("drop_pool_empty", XTianqiWeakAffix.drop_candidates(weapon, s).is_empty() and XTianqiWeakAffix.roll_drop(weapon, s) == "" and weapon == w0)
	XTianqiWeakAffix.test_entries = {"dz": {"actor": int(me.actor_id), "enabled": false}}
	_check("drop_off_entry_not_in_pool", XTianqiWeakAffix.drop_candidates(weapon, s).is_empty())
	XTianqiWeakAffix.test_entries.dz.enabled = true
	var weak := XTier.is_weak(int(me.actor_id))
	_check("drop_on_entry_in_pool", XTianqiWeakAffix.drop_candidates(weapon, s) == (["dz"] if weak and me.can_equip(weapon) else []), [weak])
	var r1 := []
	for i in 2:
		var copy := w0.duplicate(true)
		r1.append(XTianqiWeakAffix.roll_drop(copy, s))
	_check("drop_reload_same", r1[0] == r1[1], r1)
	XTianqiWeakAffix.test_entries = {}
