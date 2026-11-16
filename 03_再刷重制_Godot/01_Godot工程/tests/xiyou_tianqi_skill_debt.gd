extends Node
## 天启篇技能重构欠账（T016）专项（角色卡 CARDS 默认关，这里打开测）：
## 一、追加打满整招（FOLLOW_FULL）：追加出来的招逐个目标的段数＝正常施放的段数；关掉时复现「只打一段」。
## 二、布兰德瓦登原生反击（NATIVE_COUNTER）：挨物理打后半伤凌空斩反击、不吞这一下；同一次敌人行动最多反一次（COUNTER_ONCE，项目经理cc 定）；
##     被眩晕不反；牛马之魂反击后下一招 ×1.2、用掉就清、每回合最多 1 次；关掉时复现「反击吞掉挨打、用 1 号普攻」。
## 三、张三丰护短（GUARD）：开局不再给全队挂原版 2007；敌人一次行动打中他以外的队友后 30% 半伤太极拳打满段数、每回合最多 2 次、一次行动只判一次；
##     只打他本人不判；他被眩晕不判；不带太极再释放（效果 44）；关掉时复现原版 2007。

const BRAND := 42
const ZHANG := 86
const STUN := 29
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _state(lineup: Array) -> XState:
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	return s


func _run() -> void:
	XMessageBox.auto = true
	seed(20261116)
	_reload()
	XGojo.unlock_override = 0
	_check("switch_defaults", XTianqiSkills.FOLLOW_FULL and XTianqiSkills.NATIVE_COUNTER and XTianqiSkills.COUNTER_ONCE and XTianqiSkills.GUARD and not XTianqiSkills.CARDS)
	XTianqiSkills.CARDS = true
	_follow()
	_counter()
	_counter_off()
	_guard()
	_guard_off()
	_cards_off()
	XTianqiSkills.CARDS = false
	_reload()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		print(("PASS " if r.passed else "FAIL "), r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## XTianqiSkills.reload() 会把 CARDS 等静态开关清回默认（main 上就这样），重读表后把当前开关补回去
func _reload() -> void:
	var keep := [XTianqiSkills.CARDS, XTianqiSkills.FOLLOW_FULL, XTianqiSkills.NATIVE_COUNTER, XTianqiSkills.COUNTER_ONCE, XTianqiSkills.GUARD]
	XTianqiSkills.reload()
	XTianqiSkills.CARDS = keep[0]
	XTianqiSkills.FOLLOW_FULL = keep[1]
	XTianqiSkills.NATIVE_COUNTER = keep[2]
	XTianqiSkills.COUNTER_ONCE = keep[3]
	XTianqiSkills.GUARD = keep[4]


func _fresh(lg: XBattleLogic) -> void:
	for e in lg.enemies:
		if e.is_state_affected(1):
			e.remove_state(1)
		e.hp = e.mhp
	for a in lg.actors:
		if a.is_state_affected(1):
			a.remove_state(1)
		a.hp = a.mhp
		a.mp = a.mmp


func _per_target(logs: Array, lg: XBattleLogic, u) -> Array:
	var out := []
	for e in lg.enemies:
		out.append(logs.filter(func(l): return l is Dictionary and l.get("type") == "hit" and is_same(l.get("user"), u) and is_same(l.get("target"), e) and not l.get("counter", false)).size())
	return out


func _sum(a: Array) -> int:
	var n := 0
	for x in a:
		n += int(x)
	return n


# ---- 一、追加打满整招 ----

func _follow_once(lg: XBattleLogic, u: XActor, cast_id: int, t) -> Array:
	XTianqiSkills._skills[506] = XTianqiSkills._skills[506].duplicate(true)
	XTianqiSkills._skills[506].follow = [{"cast": cast_id, "rate": 1.0}]
	var dunk := XDB.rec("Skills", 506)
	XTianqiSkills.begin_action(lg, u, dunk)
	XTianqiSkills.after_apply(lg, u, dunk, t)
	var logs := XTianqiSkills.end_action(lg, u, dunk)
	XTianqiSkills._fstore(lg).used.erase(u)
	return logs


func _follow() -> void:
	var s := _state([3, 23, 1, 2, 64])
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var u: XActor = s.actor(3)
	u.change_level(99)
	for e in lg.enemies:
		e.add_param(0, 1e12)
	_fresh(lg)
	var t = lg.enemies[0]
	_follow_once(lg, u, 533, t)  # 预热（第一次建表缓存）
	_fresh(lg)
	# 天罡五雷（魔雷老人）、球来（艾坤，序列打全体活着的敌人）、青龙乱舞（关羽）、凌空三式（全体三段）、霸者连环斩（随机三段）、流沙乱舞、
	# 大威天龙·佛怒（全体九段）、爆踢、巨剑术（一段）
	var rows := []
	var ok := true
	var old_short := 0
	for c in [533, 4370, 1799, 3713, 1073, 1114, 2011, 5424, 1205]:
		var cast := XDB.rec("Skills", c)
		_fresh(lg)
		XTianqiSkills._fstore(lg).used[u] = int(lg.turn)  # 正常施放：不让它自己再触发追加
		var full := _per_target(lg.execute(u, cast, t, true), lg, u)
		XTianqiSkills._fstore(lg).used.erase(u)
		_fresh(lg)
		XTianqiSkills.FOLLOW_FULL = false
		var old := _per_target(_follow_once(lg, u, c, t), lg, u)
		XTianqiSkills.FOLLOW_FULL = true
		_fresh(lg)
		var now := _per_target(_follow_once(lg, u, c, t), lg, u)
		var random_scope := int(cast.get("scope", 1)) in [3, 4, 5, 6]
		var same := (_sum(now) == _sum(full)) if random_scope else (now == full)
		ok = ok and same
		if _sum(old) < _sum(full):
			old_short += 1
		rows.append({"id": c, "name": str(cast.get("name", "")), "full": full, "old": old, "now": now})
	print("FOLLOW_ROWS ", JSON.stringify(rows))
	_check("follow_old_one_hit", old_short == 8, rows)  # 修前：除了本来就一段的巨剑术，8 招都少打
	_check("follow_full_matches", ok, rows)
	_check("follow_wulei_5", _sum(rows[0].now) == 5 and _sum(rows[0].old) == 1, rows[0])
	_fresh(lg)
	_reload()
	lg.end_battle(0)


# ---- 二、布兰德瓦登原生反击 ----

func _brand() -> Array:
	var s := _state([BRAND, 1, 2, 3, 23])
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var b: XActor = s.actor(BRAND)
	b.change_level(99)
	for id in [1162, 3710]:
		if not b.skill_ids.has(id):
			b.learn_skill(id)
	b.param_mark_dirty()
	b.add_param(0, 1e12)
	for e in lg.enemies:
		e.add_param(0, 1e12)
	_fresh(lg)
	return [s, lg, b, lg.enemies[0]]


## 敌人一次行动：begin → 段数次 _invoke → end（同 XBattleLogic.execute 的接法）
func _enemy_action(lg: XBattleLogic, e, sk: Dictionary, t, segs: int) -> Array:
	var logs := []
	XTianqiSkills.begin_action(lg, e, sk)
	for i in range(segs):
		logs.append_array(lg._invoke(e, sk, t))
	logs.append_array(XTianqiSkills.end_action(lg, e, sk))
	return logs


func _counter_stats(lg: XBattleLogic, b, e, n: int, segs: int) -> Dictionary:
	var phys := XDB.rec("Skills", 1153)  # 物理单体（敌群 2 的普攻是魔法，不吃原生反击）
	var st := {"actions": 0, "with_counter": 0, "max_per_action": 0, "counters": 0, "swallowed": 0, "cast": {}, "dmg": 0.0, "tp_ok": true}
	for i in range(n):
		lg.turn = i + 1
		b.tp = 0.0
		var logs := _enemy_action(lg, e, phys, b, segs)
		var hits_on_b := logs.filter(func(l): return l is Dictionary and l.get("type") == "hit" and is_same(l.get("target"), b)).size()
		var cs := logs.filter(func(l): return l is Dictionary and l.get("type") == "hit" and l.get("counter", false))
		st.actions += 1
		st.counters += cs.size()
		st.max_per_action = maxi(st.max_per_action, cs.size())
		if not cs.is_empty():
			st.with_counter += 1
			st.cast[str(int(cs[0].skill.id))] = int(st.cast.get(str(int(cs[0].skill.id)), 0)) + 1
			st.dmg += float(cs[0].hp)
			if b.tp < 10.0:
				st.tp_ok = false
		st.swallowed += maxi(0, segs - hits_on_b)
		_fresh(lg)
		for k in ["xtq_cnext", "xtq_cnext_on", "xtq_cnext_turn"]:
			if b.has_meta(k):
				b.remove_meta(k)
	return st


func _counter() -> void:
	var x := _brand()
	var lg: XBattleLogic = x[1]
	var b: XActor = x[2]
	var e = x[3]
	var one := _counter_stats(lg, b, e, 300, 1)
	_check("counter_rate", one.with_counter >= 60 and one.with_counter <= 140, one)  # 约 33%
	_check("counter_after_hit", one.swallowed == 0 and one.cast.keys() == ["1153"], one)
	_check("counter_tp", one.tp_ok, one)
	# 伤害：半伤凌空斩（和他自己正常放凌空斩比，均值约一半）
	var direct := 0.0
	for i in range(100):
		direct += float(lg.apply(b, XDB.rec("Skills", 1153), e).hp)
		_fresh(lg)
	var ratio: float = (one.dmg / maxf(1.0, one.with_counter)) / maxf(1.0, direct / 100.0)
	_check("counter_half", ratio > 0.38 and ratio < 0.62, [ratio, one.dmg / maxf(1.0, one.with_counter), direct / 100.0])
	# 多段攻击同一次行动只反一次（五段：至少有一段中的几率约 86%）
	var five := _counter_stats(lg, b, e, 200, 5)
	_check("counter_once_per_action", five.max_per_action == 1 and five.with_counter >= 140 and five.swallowed == 0, five)
	XTianqiSkills.COUNTER_ONCE = false
	var many := _counter_stats(lg, b, e, 200, 5)
	XTianqiSkills.COUNTER_ONCE = true
	_check("counter_once_off", many.max_per_action >= 2, many)
	# 眩晕：不反
	b.add_state(STUN)
	var stunned := _counter_stats(lg, b, e, 60, 1)
	b.remove_state(STUN)
	_check("counter_stunned", stunned.counters == 0 and stunned.swallowed == 0, stunned)
	# 牛马之魂：反击后下一招 ×1.2，用掉就清，同回合不再挂
	var sk := XDB.rec("Skills", 1159)
	var base := XTianqiSkills.formula(b, e, sk)
	var armed := false
	lg.turn = 1000
	for i in range(80):
		_enemy_action(lg, e, XDB.rec("Skills", 1153), b, 1)
		_fresh(lg)
		if b.has_meta("xtq_cnext"):
			armed = true
			break
	XTianqiSkills.begin_action(lg, b, sk)
	var boosted := XTianqiSkills.formula(b, e, sk)
	XTianqiSkills.end_action(lg, b, sk)
	var after := XTianqiSkills.formula(b, e, sk)
	var rearm := false
	for i in range(40):
		_enemy_action(lg, e, XDB.rec("Skills", 1153), b, 1)
		_fresh(lg)
		rearm = rearm or b.has_meta("xtq_cnext")
	_check("counter_next_bonus", armed and is_equal_approx(boosted, base * 1.2) and is_equal_approx(after, base), [armed, base, boosted, after])
	_check("counter_next_once_per_turn", not rearm)
	lg.turn = 1001
	var rearm2 := false
	for i in range(40):
		_enemy_action(lg, e, XDB.rec("Skills", 1153), b, 1)
		_fresh(lg)
		rearm2 = rearm2 or b.has_meta("xtq_cnext")
	_check("counter_next_next_turn", rearm2)
	lg.end_battle(0)


## 关掉 NATIVE_COUNTER：回到原版（反击代替挨打、用 1 号普攻）——也就是修前的复现
func _counter_off() -> void:
	XTianqiSkills.NATIVE_COUNTER = false
	var x := _brand()
	var lg: XBattleLogic = x[1]
	var old := _counter_stats(lg, x[2], x[3], 300, 1)
	XTianqiSkills.NATIVE_COUNTER = true
	print("COUNTER_OLD ", JSON.stringify(old))
	_check("counter_off_swallows", old.with_counter >= 60 and old.swallowed == old.with_counter and old.cast.keys() == ["1"], old)
	lg.end_battle(0)


# ---- 三、张三丰护短 ----

func _zhang() -> Array:
	var s := _state([ZHANG, 1, 2, 3, 23])
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var z: XActor = s.actor(ZHANG)
	z.change_level(99)
	for id in [5863, 5866]:  # 护短、以武入道（太极拳四段）
		if not z.skill_ids.has(id):
			z.learn_skill(id)
	z.param_mark_dirty()
	for a in lg.actors:
		a.add_param(0, 1e12)
	for e in lg.enemies:
		e.add_param(0, 1e12)
	_fresh(lg)
	lg._battle_start_states()
	return [s, lg, z, s.actor(1), lg.enemies[0]]


func _guard_stats(lg: XBattleLogic, z, victim, e, n: int, segs: int, new_turn := true) -> Dictionary:
	var phys := XDB.rec("Skills", 1153)
	var st := {"actions": 0, "fired": 0, "max_per_action": 0, "cast": {}, "segs": {}, "target_ok": true, "no_44": true, "reserves": 0}
	for i in range(n):
		if new_turn:
			lg.turn = i + 1
		XStateEffects.take_reserves()
		var logs := _enemy_action(lg, e, phys, victim, segs)
		st.reserves += XStateEffects.take_reserves().filter(func(r): return int(r) == 1605).size()
		var acts := logs.filter(func(l): return l is Dictionary and l.get("type") == "action" and l.get("guard", false))
		st.actions += 1
		st.fired += acts.size()
		st.max_per_action = maxi(st.max_per_action, acts.size())
		if not acts.is_empty():
			var sid := int(acts[0].skill.id)
			st.cast[str(sid)] = int(st.cast.get(str(sid), 0)) + 1
			st.no_44 = st.no_44 and not (acts[0].skill.get("effects", []) as Array).any(func(x): return int(x.get("code", 0)) == 44)
			var zh := logs.filter(func(l): return l is Dictionary and l.get("type") == "hit" and is_same(l.get("user"), z))
			st.segs[str(zh.size())] = int(st.segs.get(str(zh.size()), 0)) + 1
			st.target_ok = st.target_ok and zh.all(func(l): return is_same(l.target, e))
		_fresh(lg)
	return st


func _guard() -> void:
	var x := _zhang()
	var lg: XBattleLogic = x[1]
	var z: XActor = x[2]
	var ally: XActor = x[3]
	var e = x[4]
	_check("guard_no_2007", lg.actors.all(func(a): return not a.is_state_affected(2007)), lg.actors.map(func(a): return [a.actor_id, a.is_state_affected(2007)]))
	var one := _guard_stats(lg, z, ally, e, 300, 1)
	_check("guard_rate", one.fired >= 60 and one.fired <= 130 and one.max_per_action == 1, one)  # 约 30%
	_check("guard_cast", one.cast.keys() == ["5860"] and one.segs.keys() == ["4"] and one.target_ok and one.no_44 and one.reserves == 0, one)
	var five := _guard_stats(lg, z, ally, e, 200, 5)
	_check("guard_once_per_action", five.max_per_action == 1 and five.fired >= 30 and five.fired <= 95, five)  # 五段也只判一次 30%
	lg.turn = 5000
	var capped := _guard_stats(lg, z, ally, e, 60, 1, false)
	_check("guard_per_turn_2", capped.fired == 2, capped)
	var self_hit := _guard_stats(lg, z, z, e, 100, 1)
	_check("guard_not_self", self_hit.fired == 0, self_hit)
	z.add_state(STUN)
	var stunned := _guard_stats(lg, z, ally, e, 100, 1)
	z.remove_state(STUN)
	_check("guard_stunned", stunned.fired == 0, stunned)
	lg.end_battle(0)


## 关掉 GUARD：回到原版（开局全队挂 2007，挨打预约公共事件 1605）——修前的复现
func _guard_off() -> void:
	XTianqiSkills.GUARD = false
	_reload()
	var x := _zhang()
	var lg: XBattleLogic = x[1]
	var st := _guard_stats(lg, x[2], x[3], x[4], 20, 1)
	_check("guard_off_2007", lg.actors.all(func(a): return a.is_state_affected(2007)) and st.fired == 0 and st.reserves >= 15, st)  # 偶有没打中（命中率）
	XTianqiSkills.GUARD = true
	_reload()
	lg.end_battle(0)


## 角色卡关（默认）：两套都不接，原版照旧
func _cards_off() -> void:
	XTianqiSkills.CARDS = false
	_reload()
	var x := _brand()
	var old := _counter_stats(x[1], x[2], x[3], 200, 1)
	x[1].end_battle(0)
	var y := _zhang()
	var lg: XBattleLogic = y[1]
	_check("cards_off_original", old.swallowed == old.with_counter and old.with_counter > 0 and lg.actors.all(func(a): return a.is_state_affected(2007)), old)
	lg.end_battle(0)
	XTianqiSkills.CARDS = true
	_reload()
