extends Node
## T181（T086-a；设计仓库《天启篇_发作真换人 v0.2》第三～七节、第十节，D201）：发作真换人逻辑层。
## 一、开关默认关：关着第六种一律断片（同 T086 前）。
## 二、真换：轮到他时这次行动按放弃走完，act 末尾（收尾之后）和助力位对调；留底挂在这场战斗上；锁定 2 回合谁都不能换。
## 三、收尾里倒下不换；轮到他时换不了、收尾后换不了都改成完整断片（2 回合、间隔从断片最后一回合算）。
## 四、退回断片：模块角色、心魔被考的人、锁定中别人再抽到。
## 五、还原：出战栏＋在场名单两样一起，可重复调；多次换人（发作后再手动换）整份还原；胜利结算（rewards／grant）开头就还原。
## 六、心魔判胜认还原前那一刻：被考的人被手动换下歇着，还原后不白捡立境。
## 七、自动换回：自动战斗、挂机现判；手动不换；玩家自己换过就不误换。
## 八、九死临时口子：超强者被发作换下许坐助力位、出战栏清理停手、许照锁定换回；证道助力位超强者场上已满退回断片。
## 九、留底不进存档：回放导出写留底、回放结束不残留；没收口的上一场开新一场先清扫。
## 十、五条悟离场无量空处消散（LEAVE_DOMAIN）；云裳衣魂在助力位到期照结算（HELPER_GHOST，T180 P3-2）。
## 十一、回放器 cmd.automatic 照 decide 的行动执行（复核 P3-3）；真战斗画面发作换人、结算前还原换回图不报错。

var results: Array = []


class FixStream extends XRandomStream:
	var floats := {}
	var mods := {}
	var default_float := 0.99
	func next_float(reason: String, _event_key := "") -> float:
		draws += 1
		return float(floats.get(reason, default_float))
	func next_uint(_reason: String, _event_key := "") -> int:
		draws += 1
		return 0
	func next_index_mod(n: int, reason: String, _event_key := "") -> int:
		draws += 1
		return clampi(int(mods.get(reason, 0)), 0, maxi(0, n - 1))
	func next_int_inclusive(lo: int, _hi: int, _reason: String, _event_key := "") -> int:
		draws += 1
		return lo


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


## 回退开关用字面量赋值（回退开关覆盖.py 只认字面量）
func _real(on: bool) -> void:
	if on:
		XTianqiBrand.REAL_SWAP = true
	else:
		XTianqiBrand.REAL_SWAP = false


func _leave(on: bool) -> void:
	if on:
		XGojo.LEAVE_DOMAIN = true
	else:
		XGojo.LEAVE_DOMAIN = false


func _hghost(on: bool) -> void:
	if on:
		XYunshang.HELPER_GHOST = true
	else:
		XYunshang.HELPER_GHOST = false


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id) and id != XGojo.ACTOR)


func _state(diff := "jianxian", lineup: Array = []) -> XState:
	if lineup.is_empty():
		lineup = _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, diff, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in lineup:
		var a := s.actor(id)
		a.add_param(0, 20000000.0)
		a.recover_all()
	return s


func _setb(a: XActor, brand: int) -> void:
	XZhenqi.data(a)
	var r := 0
	while r < XTianqiBrand.last_realm() and XTianqiBrand.node_of(r) <= brand:
		r += 1
	a.zhenqi["brand"] = brand
	a.zhenqi["brand_realm"] = r
	a.zhenqi["brand_carved"] = 1


func _logic(s: XState, troop := 1) -> XBattleLogic:
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	var fs := FixStream.new()
	fs.domain = "rule"
	fs.floats["brand_fit"] = 0.0
	lg.random.rule = fs
	XTianqiBrand.fight(lg)["ripe"] = false  # 生的：第六种在
	lg.turn = 2
	return lg


## a 抽到第六种（换人）：直接开一次发作（同 start_turn 掷中、花样取最后一种）
func _draw_swap(lg: XBattleLogic, a: XActor) -> void:
	_setb(a, 10000)
	(lg.random.rule as FixStream).mods["brand_fit_kind"] = XTianqiBrand.fit_kinds(lg, a).find("swap")
	XTianqiBrand._start_fit(lg, XTianqiBrand._fc(lg), a, "self")


func _kind(lg: XBattleLogic, a: XActor) -> String:
	var f = XTianqiBrand.fight(lg).get("fit_now", {}).get(a)
	return str(f.kind) if f != null else ""


func _slots(s: XState) -> Array:
	return s.battle_slots.map(func(v): return int(v))


func _swap_rec(logs: Array) -> Array:
	return logs.filter(func(l): return str(l.get("type", "")) == "tianqi_swap")


func _texts(logs: Array) -> Array:
	return logs.filter(func(l): return str(l.get("type", "")) == "battle_text").map(func(l): return str(l.text))


func _kill(a: XBattler) -> void:
	a.hp = 0.0
	if not a.state_ids.has(1):
		a.add_state(1)


func _run() -> void:
	XMessageBox.auto = true
	seed(20261118)
	_check("default_off", not XTianqiBrand.REAL_SWAP and XGojo.LEAVE_DOMAIN and XYunshang.HELPER_GHOST)
	XTianqiBrand.ENABLED = true
	_off()
	_real(true)
	_basic()
	_died_in_wrapup()
	_fallbacks()
	_restore()
	_trial()
	_auto_back()
	_super_gap()
	_zhengdao_full()
	_no_save()
	_replay()
	_gojo(true)
	_gojo(false)
	_ghost(true)
	_ghost(false)
	await _scene()
	_real(false)
	_leave(true)
	_hghost(true)
	XTianqiBrand.ENABLED = false
	XZhenqi.battle = {}
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 一、开关关着：抽到换人一律断片 2 回合，人在场上
func _off() -> void:
	_real(false)
	var s := _state()
	var lg := _logic(s)
	var a: XActor = lg.actors[0]
	var before := _slots(s)
	_draw_swap(lg, a)
	var cmd := lg.brand_forced(a)
	var logs := lg.act(a, cmd[0], cmd[1])
	_check("off_blackout", _kind(lg, a) == "blackout" and int(XTianqiBrand.fight(lg).fit_now[a].to) == 3 and lg.actors.has(a) and _slots(s) == before and _swap_rec(logs).is_empty(), [_kind(lg, a), _slots(s)])
	lg.end_battle()


## 二、真换：收尾之后对调，留底、锁定
func _basic() -> void:
	var s := _state()
	var lg := _logic(s)
	var a: XActor = lg.actors[0]
	var b: XActor = lg.actors[1]
	var h := s.helper()
	var before := _slots(s)
	_draw_swap(lg, a)
	_check("swap_kind", _kind(lg, a) == "swap" and XTianqiBrand.snap_of(lg).is_empty(), _kind(lg, a))
	var cmd := lg.brand_forced(a)
	_check("swap_cmd", not cmd.is_empty() and str(cmd[0].get(XTianqiBrand.FIT_KEY, "")) == "swap", cmd)
	var logs := lg.act(a, cmd[0], cmd[1])
	var recs := _swap_rec(logs)
	_check("swap_done", recs.size() == 1 and is_same(recs[0].out, a) and is_same(recs[0]["in"], h) and recs[0].get("forced", false)
		and lg.actors[0] == h and not lg.actors.has(a) and s.helper() == a, [_slots(s)])
	_check("swap_record_last", str(logs[logs.size() - 1].type) == "tianqi_swap" and _texts(logs).any(func(t): return t.contains("换人")), _texts(logs))
	_check("swap_slots", _slots(s) == [before[4], before[1], before[2], before[3], before[0]], _slots(s))
	_check("swap_snap", XTianqiBrand.snap_of(lg) == before and XTianqiBrand.swap_hold(s), XTianqiBrand.snap_of(lg))
	_check("swap_no_save_key", not JSON.stringify(s.to_dict()).contains("lock_until"))
	# 锁定：换下那回合算第 1 回合，第 2、3 回合谁都不能换，第 4 回合起能换回
	_check("lock_t2", not lg.can_tianqi_swap(h) and not lg.can_tianqi_swap(b))
	lg.turn = 3
	_check("lock_t3", not lg.can_tianqi_swap(h) and not lg.can_tianqi_swap(b))
	lg.turn = 4
	_check("lock_t4_open", lg.can_tianqi_swap(h) and lg.can_tianqi_swap(b))
	# 发作算一次：间隔从这一回合算
	_check("swap_gap", int(XTianqiBrand.fight(lg).fit_last[a]) == 2 and XTianqiBrand.fight(lg).fit_log.any(func(r): return int(r.actor) == a.actor_id and str(r.kind) == "swap"))
	lg.end_battle(1)
	_check("end_restores", _slots(s) == before and not XTianqiBrand.swap_hold(s), _slots(s))


## 三、收尾里倒下不换
func _died_in_wrapup() -> void:
	var s := _state()
	var lg := _logic(s)
	var a: XActor = lg.actors[0]
	var before := _slots(s)
	_draw_swap(lg, a)
	var cmd := lg.brand_forced(a)
	XTianqiBrand.perform(lg, a, cmd[0], null)
	_kill(a)
	var logs := XTianqiBrand.after_act(lg, a)
	_check("dead_no_swap", logs.is_empty() and lg.actors.has(a) and _slots(s) == before and XTianqiBrand.snap_of(lg).is_empty(), [_slots(s)])
	lg.end_battle()


## 三、换不了改完整断片：轮到他时助力位倒下；收尾里助力位倒下
func _fallbacks() -> void:
	var s := _state()
	var lg := _logic(s)
	var a: XActor = lg.actors[0]
	var h := s.helper()
	_draw_swap(lg, a)
	_kill(h)
	var cmd := lg.brand_forced(a)
	var f: Dictionary = XTianqiBrand.fight(lg).fit_now[a]
	_check("fallback_at_turn", str(cmd[0].get(XTianqiBrand.FIT_KEY, "")) == "blackout" and str(f.kind) == "blackout" and int(f.from) == 2 and int(f.to) == 3
		and int(XTianqiBrand.fight(lg).fit_last[a]) == 3, [cmd, f])
	_check("fallback_log", XTianqiBrand.fight(lg).fit_log.any(func(r): return int(r.actor) == a.actor_id and str(r.kind) == "blackout" and r.get("fallback", false)))
	lg.act(a, cmd[0], cmd[1])
	lg.turn = 3
	var c3 := lg.brand_forced(a)
	_check("fallback_two_rounds", not c3.is_empty() and str(c3[0].get(XTianqiBrand.FIT_KEY, "")) == "blackout" and lg.actors.has(a), c3)
	lg.end_battle()
	h.remove_state(1)
	h.hp = h.mhp
	# 收尾之后换不了
	s = _state()
	lg = _logic(s)
	a = lg.actors[0]
	h = s.helper()
	_draw_swap(lg, a)
	cmd = lg.brand_forced(a)
	XTianqiBrand.perform(lg, a, cmd[0], null)
	_kill(h)
	var logs := XTianqiBrand.after_act(lg, a)
	f = XTianqiBrand.fight(lg).fit_now[a]
	_check("fallback_after_wrapup", _swap_rec(logs).is_empty() and _texts(logs).size() == 1 and str(f.kind) == "blackout" and int(f.to) == 3 and lg.actors.has(a), [_texts(logs), f])
	lg.end_battle()
	# 模块角色：发作的人是模块角色（只做断片的名单读数据）
	_check("blackout_only_data", XTianqiBrand.blackout_only(174) and XTianqiBrand.blackout_only(179) and not XTianqiBrand.blackout_only(178) and not XTianqiBrand.blackout_only(180))
	# 锁定中别人再抽到：断片
	s = _state()
	lg = _logic(s)
	a = lg.actors[0]
	var b: XActor = lg.actors[1]
	_draw_swap(lg, a)
	cmd = lg.brand_forced(a)
	lg.act(a, cmd[0], cmd[1])
	_draw_swap(lg, b)
	_check("locked_other_blackout", _kind(lg, b) == "blackout" and int(XTianqiBrand.fight(lg).fit_now[b].to) == 3, _kind(lg, b))
	lg.end_battle()


## 五、还原：两样一起、可重复调、整份还原（发作之后玩家又手动换人）
func _restore() -> void:
	var s := _state()
	var lg := _logic(s)
	var before := _slots(s)
	var order_before := lg.actors.duplicate()
	var a: XActor = lg.actors[0]
	var b: XActor = lg.actors[1]
	var e := s.helper()
	_draw_swap(lg, a)
	var cmd := lg.brand_forced(a)
	lg.act(a, cmd[0], cmd[1])
	lg.turn = 4
	var h2 := lg.tianqi_swap(b)  # 玩家手动把乙换下、甲换上
	_check("manual_after", h2 == a and _slots(s) == [e.actor_id, a.actor_id, before[2], before[3], b.actor_id], _slots(s))
	var pairs := lg.tianqi_restore()
	_check("restore_slots", _slots(s) == before, _slots(s))
	_check("restore_actors", lg.actors == order_before, lg.actors.map(func(x): return x.actor_id))
	_check("restore_pairs", pairs.size() == 2 and is_same(pairs[0][0], e) and is_same(pairs[0][1], a) and is_same(pairs[1][0], a) and is_same(pairs[1][1], b), pairs.map(func(p): return [p[0].actor_id, p[1].actor_id]))
	_check("restore_twice_empty", lg.tianqi_restore().is_empty() and not XTianqiBrand.swap_hold(s) and _slots(s) == before)
	lg.end_battle(0)
	# 胜利结算开头就还原：rewards（金钱率读 actors）、grant（法宝经验、烙印读 actors）
	s = _state()
	lg = _logic(s)
	before = _slots(s)
	a = lg.actors[0]
	_draw_swap(lg, a)
	cmd = lg.brand_forced(a)
	lg.act(a, cmd[0], cmd[1])
	for x in lg.enemies:
		_kill(x)
	lg.rewards()
	_check("rewards_restores", lg.actors.has(a) and _slots(s) == before)
	lg.end_battle(0)
	s = _state()
	lg = _logic(s)
	a = lg.actors[0]
	_draw_swap(lg, a)
	cmd = lg.brand_forced(a)
	lg.act(a, cmd[0], cmd[1])
	lg.grant({"exp": 0, "gold": 0, "drops": []})
	_check("grant_restores", lg.actors.has(a) and lg.actors[0] == a)
	lg.end_battle(0)
	# 留底和出战栏不是同一批：不还原
	s = _state()
	lg = _logic(s)
	a = lg.actors[0]
	_draw_swap(lg, a)
	cmd = lg.brand_forced(a)
	lg.act(a, cmd[0], cmd[1])
	var odd: int = _ids(XTier.WEAK)[6]
	s.add_actor(odd)
	var cur := _slots(s)
	s.battle_slots[2] = odd
	cur[2] = odd
	_check("restore_mismatch_skip", lg.tianqi_restore().is_empty() and _slots(s) == cur, _slots(s))
	lg.end_battle()


## 六、心魔战：被考的人抽到换人只断片；还原前记在不在场
func _trial() -> void:
	var s := _state()
	var lg := _logic(s)
	var t: XActor = lg.actors[0]
	var b: XActor = lg.actors[1]
	XZhenqi.battle = {"trial": {"actorId": t.actor_id, "kind": "心魔"}, "scaled": {}}
	_draw_swap(lg, t)
	_check("trial_actor_blackout", _kind(lg, t) == "blackout")
	# 队友照常能换；之后玩家把被考的人手动换下歇着：还原后他回到在场名单，心魔仍判没赢
	_draw_swap(lg, b)
	_check("trial_mate_swaps", _kind(lg, b) == "swap")
	var cmd := lg.brand_forced(b)
	lg.act(b, cmd[0], cmd[1])
	lg.turn = 4
	lg.tianqi_swap(t)
	_check("trial_benched", not lg.actors.has(t) and s.helper() == t)
	for x in lg.enemies:
		_kill(x)
	XZhenqi.trial_done = {}
	lg.grant({"exp": 0, "gold": 0, "drops": []})
	_check("trial_restored_but_lost", lg.actors.has(t) and not bool(XZhenqi.trial_done.get("won", true)), XZhenqi.trial_done)
	lg.end_battle(0)
	# 对照：被考的人一直在场，照常判赢
	s = _state()
	lg = _logic(s)
	t = lg.actors[0]
	b = lg.actors[1]
	XZhenqi.battle = {"trial": {"actorId": t.actor_id, "kind": "心魔"}, "scaled": {}}
	_draw_swap(lg, b)
	cmd = lg.brand_forced(b)
	lg.act(b, cmd[0], cmd[1])
	for x in lg.enemies:
		_kill(x)
	XZhenqi.trial_done = {}
	lg.grant({"exp": 0, "gold": 0, "drops": []})
	_check("trial_stayed_won", bool(XZhenqi.trial_done.get("won", false)), XZhenqi.trial_done)
	lg.end_battle(0)
	XZhenqi.trial_done = {}
	XZhenqi.battle = {}


## 七、自动换回：现判
func _auto_back() -> void:
	var s := _state()
	var lg := _logic(s)
	lg.auto = true
	var a: XActor = lg.actors[0]
	var e := s.helper()
	var before := _slots(s)
	_draw_swap(lg, a)
	var cmd := lg.brand_forced(a)
	lg.act(a, cmd[0], cmd[1])
	lg.turn = 3
	_check("auto_locked", lg.brand_forced(e).is_empty())
	lg.turn = 4
	var back := lg.brand_forced(e)
	_check("auto_cmd", not back.is_empty() and str(back[0].get(XTianqiBrand.FIT_KEY, "")) == "swap_back", back)
	_check("auto_others_none", lg.brand_forced(lg.actors[1]).is_empty())
	var logs := lg.act(e, back[0], back[1])
	var recs := _swap_rec(logs)
	_check("auto_back_done", recs.size() == 1 and recs[0].get("auto", false) and lg.actors[0] == a and s.helper() == e and _slots(s) == before
		and not _texts(logs).any(func(t): return t.contains("发作")), [_slots(s), _texts(logs)])
	_check("auto_back_once", lg.brand_forced(a).is_empty())
	lg.end_battle()
	# 手动：不自动换回
	s = _state()
	lg = _logic(s)
	a = lg.actors[0]
	e = s.helper()
	_draw_swap(lg, a)
	cmd = lg.brand_forced(a)
	lg.act(a, cmd[0], cmd[1])
	lg.turn = 4
	_check("manual_no_auto", lg.brand_forced(e).is_empty())
	# 玩家自己换过（助力位已是别人）：切自动也不误换
	lg.tianqi_swap(lg.actors[1])
	lg.auto = true
	_check("auto_after_manual_none", lg.brand_forced(e).is_empty() and lg.actors.all(func(x): return lg.brand_forced(x).is_empty()))
	lg.end_battle()


func _super_lineup(n_front_super: int, helper_super: bool) -> Array:
	var sup := XTianqiSkills.ids(XTier.SUPER, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id) and id != XGojo.ACTOR)
	var weak := _ids(XTier.WEAK).filter(func(id): return not XTianqiSkills.is_super(id, true))
	var out := []
	for i in 4:
		out.append(sup[i] if i < n_front_super else weak[i])
	out.append(sup[3] if helper_super else weak[4])
	return out


## 八、九死：超强者被发作换下许坐助力位（临时口子），出战栏清理停手，锁定过了许换回；收口还原
func _super_gap() -> void:
	var s := _state("jiusi", _super_lineup(1, false))
	var lg := _logic(s)
	var a: XActor = lg.actors[0]
	var before := _slots(s)
	_check("gap_fixture", XTianqiSkills.is_super(a.actor_id, true) and not XTianqi.helper_super_ok(s) and _slots(s)[0] == a.actor_id, [_slots(s), XTianqi.super_cap(s), XTianqiSkills.is_super(a.actor_id, true), XTianqi.helper_super_ok(s), XTier.ids(XTier.SUPER).slice(0, 6)])
	_check("gap_manual_blocked", not lg.can_tianqi_swap(a) and lg.can_tianqi_swap(a, true))
	_draw_swap(lg, a)
	_check("gap_kind", _kind(lg, a) == "swap", _kind(lg, a))
	var cmd := lg.brand_forced(a)
	lg.act(a, cmd[0], cmd[1])
	_check("gap_helper_super", s.helper() == a and not lg.actors.has(a))
	s.battle_members()  # 出战栏超强者清理（XItemMarks.enforce_party）：留底在时停手
	_check("gap_enforce_paused", s.helper() == a and int(s.battle_slots[4]) == a.actor_id, _slots(s))
	lg.turn = 4
	var b: XActor = lg.actors[1]
	_check("gap_back_open", lg.can_tianqi_swap(b), [_slots(s)])
	lg.end_battle(0)
	_check("gap_restored", _slots(s) == before and not XTianqiBrand.swap_hold(s), _slots(s))
	s.battle_members()
	_check("gap_after_clean_ok", _slots(s) == before, _slots(s))


## 八、证道：助力位是超强者、场上超强者已满 2 个，弱者发作退回断片
func _zhengdao_full() -> void:
	var s := _state("zhengdao", _super_lineup(2, true))
	var lg := _logic(s)
	var w: XActor = lg.actors[2]
	_check("zd_fixture", XTianqi.super_cap(s) == 2 and XTianqiSkills.is_super(s.helper().actor_id, true) and not XTianqiSkills.is_super(w.actor_id, true), [_slots(s), XTianqi.super_cap(s), s.helper() != null and XTianqiSkills.is_super(s.helper().actor_id, true)])
	_draw_swap(lg, w)
	_check("zd_full_blackout", _kind(lg, w) == "blackout", _kind(lg, w))
	lg.end_battle()


## 九、留底不进存档：没收口的上一场留在这份存档上，开新一场先清扫
func _no_save() -> void:
	var s := _state()
	var lg := _logic(s)
	var before := _slots(s)
	var a: XActor = lg.actors[0]
	_draw_swap(lg, a)
	var cmd := lg.brand_forced(a)
	lg.act(a, cmd[0], cmd[1])
	var d := s.to_dict()
	XTianqiBrand.patch_save(lg, d)
	_check("patch_save_snap", Array(d.battleSlots).map(func(v): return int(v)) == before and _slots(s) != before)
	lg = null  # 战斗对象丢了，没走收口
	var lg2 := XBattleLogic.new()
	lg2.setup(1, s)
	_check("sweep_on_new_battle", _slots(s) == before and not XTianqiBrand.swap_hold(s) and lg2.actors.has(a), _slots(s))
	lg2.end_battle()


## 九、回放：带强制换人的战斗，录制末态出战栏是留底；回放结果和不带换人时一样（天启篇档整场回放本单之前就有既有不符，只比诊断相同）；
## 回放结束留底不残留；回放器自动出招照 decide 的行动（P3-3）
func _replay() -> void:
	var r_on := _record(true)
	var r_off := _record(false)
	_check("replay_final_is_snap", r_on.final_ok, r_on)
	_check("replay_same_as_noswap", r_on.result.available == r_off.result.available and str(r_on.result.get("diagnostic", "")) == str(r_off.result.get("diagnostic", "")), [r_on.result, r_off.result])
	_check("replay_no_residue", XTianqiBrand._holds.filter(func(x): return x.state.get_ref() != null and x.logic.get_ref() == null).is_empty(), XTianqiBrand._holds.size())
	print("INFO replay on=", JSON.stringify(r_on.result), " off=", JSON.stringify(r_off.result))


func _record(swap: bool) -> Dictionary:
	var s := _state()
	var init := s.to_dict().duplicate(true)
	var lg := XBattleLogic.new()
	lg.setup(1, s)
	lg.auto = true
	var a: XActor = lg.actors[0]
	var before := _slots(s)
	var commands := []
	var logs := []
	XTianqiBrand.TEST_FIT = {}
	if swap:
		for x in lg.actors:
			XTianqiBrand.TEST_FIT[x.actor_id] = [1, "swap"]  # 全员点名：谁先轮到谁换（敌人可能两下就倒，别等指定的人），后面的锁定改断片
	lg.start_turn()
	for i in 12:
		var user := lg.next_subject()
		if user == null:
			break
		var fit := lg.brand_forced(user)
		var cmd := fit if not fit.is_empty() else lg.decide(user)
		commands.append({"turn": lg.turn, "user": lg.stable_id(user), "skill": 0 if cmd[0] == null else int(cmd[0].id), "target": "", "automatic": true})
		logs.append_array(lg.act(user, cmd[0], cmd[1]))
	var art := XBattleReplay.record(lg, init, commands, logs)
	var swapped := not _swap_rec(logs).is_empty()
	var final_ok: bool = Array(art.final.battleSlots).map(func(v): return int(v)) == before and swapped == swap and (not swap or _slots(s) != before)
	var out := XBattleReplay.replay(JSON.parse_string(JSON.stringify(art)))
	XTianqiBrand.TEST_FIT = {}
	XState.current = s
	XTianqiBrand.release(lg)
	return {"result": out, "final_ok": final_ok, "swapped": swapped, "slots": _slots(s), "before": before, "final": art.final.battleSlots, "fits": XTianqiBrand.fight(lg).get("fit_log", []), "on": XTianqiBrand.on(s), "turn": lg.turn}


## 十、五条悟离场：无量空处消散（手动换人也算）；关掉回到停住
func _gojo(on: bool) -> void:
	_leave(on)
	var tag := "on" if on else "off"
	XGojo.unlock_override = 1
	var s := _state("zhengdao", [XGojo.ACTOR] + _ids(XTier.WEAK).slice(0, 4))
	XGojo.unlock_override = -1
	var lg := _logic(s)
	var g := s.actor(XGojo.ACTOR)
	_check("gojo_fixture_%s" % tag, lg.actors.has(g), _slots(s))
	XGojo.temp(g).domain = 2
	g.add_state(XGojo.ST_DOMAIN)
	var h := lg.tianqi_swap(g)
	var logs := lg.take_swap_logs()
	if on:
		_check("gojo_domain_gone", h != null and int(XGojo.temp(g).domain) == 0 and not g.state_ids.has(XGojo.ST_DOMAIN) and _texts(logs).any(func(t): return t.contains("无量空处消散")), [_texts(logs)])
	else:
		_check("gojo_domain_kept_off", h != null and int(XGojo.temp(g).domain) == 2 and logs.is_empty())
	lg.end_battle()
	_leave(true)


## 十、云裳衣魂在助力位：回合末到期照结算（T180 P3-2）
func _ghost(on: bool) -> void:
	_hghost(on)
	var tag := "on" if on else "off"
	var s := _state()
	s.flags.tianqi["line"] = "death"
	XTianqiDeathAlien.prepare("omen", s)
	var t: XActor = s.battle_members()[1]
	s.gain_gear("armor", XYunshang.ROBE_FIRST + 3, 1)
	t.keep_unequippable = true
	t.equips[t.equip_slots().find(4)] = s.gear[s.gear.size() - 1]
	s.gear.remove_at(s.gear.size() - 1)
	var lg := XBattleLogic.new()
	lg.setup(291, s)
	lg.tianqi_swap(t)
	_check("ghost_fixture_%s" % tag, XYunshang.key(t) == 3 and s.helper() == t, XYunshang.key(t))
	XTianqiDeathAlien._kill(lg, t, false, "死期")
	_check("ghost_started_%s" % tag, XYunshang.ghost(t) and t.is_alive(), [t.hp, t.state_ids])
	XYunshang.round = int(XYunshang.data(t).ghost_expires)
	XYunshang.end_turn(lg)
	if on:
		_check("ghost_helper_ends", t.is_dead() and not XYunshang.ghost(t), [t.hp, t.state_ids])
	else:
		_check("ghost_helper_stuck_off", t.is_alive() and XYunshang.ghost(t), [t.hp, t.state_ids])
	lg.end_battle(1)
	_hghost(true)


## 十一、真战斗画面：发作换人照记录换图；打赢时结算前还原换回图，胜利姿势、升级对照不报错
func _scene() -> void:
	var s := _state()
	var before := _slots(s)
	var scene := XBattleScene.new()
	scene.setup(1, true, false, XDB.map(5))
	add_child(scene)
	for i in 30:
		await get_tree().physics_frame
	var lg: XBattleLogic = scene.logic
	var fs := FixStream.new()
	fs.domain = "rule"
	fs.floats["brand_fit"] = 0.0
	lg.random.rule = fs
	XTianqiBrand.fight(lg)["ripe"] = false
	lg.turn = 2
	var a: XActor = lg.actors[0]
	var h := s.helper()
	_draw_swap(lg, a)
	var cmd := lg.brand_forced(a)
	var logs := lg.act(a, cmd[0], cmd[1])
	var done := [false]
	var play := func():
		await scene._play(logs)
		for l in logs:
			if str(l.get("type", "")) == "tianqi_swap":
				await scene._tianqi_swap_view(l.out, l["in"])
		done[0] = true
	play.call()
	for i in 900:
		if done[0]:
			break
		await get_tree().physics_frame
	_check("scene_play_done", done[0])
	_check("scene_swapped_view", scene.sprites.has(h) and not scene.sprites.has(a) and scene.status_rows.has(h) and not scene.status_rows.has(a))
	scene._tianqi_restore_view()
	_check("scene_restore_view", scene.sprites.has(a) and not scene.sprites.has(h) and scene.status_rows.has(a) and _slots(s) == before and lg.actors.has(a))
	lg.end_battle(1)
	scene.queue_free()
	for i in 3:
		await get_tree().physics_frame
