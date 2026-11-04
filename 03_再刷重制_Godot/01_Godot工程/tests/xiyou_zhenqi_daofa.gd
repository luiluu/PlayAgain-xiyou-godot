extends Node
## 真气第三批（道法运行时效果、神兵试炼、降服含隐藏成员）：与 mv_oracle/zhenqi_probe.cjs「daofa.*」「weapon.*」「hidden.*」逐例比
##（generated/oracle/zhenqi.json）。闭关菜单的文字、选项与走向借用 tests/xiyou_zhenqi_break 的节点比较。
## 道法：连击／分神／金身的数值，executeHpDamage（护法减伤、元婴护体）、掩护、灵台保留 TP、破甲·真气倍率；另测接线（BattleLogic 里真打一下）。
## 已登记的差异：倒下或不能行动的护法不再掩护（O-048，参照 daofa.subs.dead 原版仍由倒下的护法挨打）。

const ORACLE := "res://modes/xiyou/generated/oracle/zhenqi.json"
const Base := preload("res://tests/xiyou_zhenqi.gd")
const Break := preload("res://tests/xiyou_zhenqi_break.gd")
var results := []
var h = Break.new()   # 借用第二批测试的新局、菜单节点与比较
var s: XState


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 15:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _fresh() -> void:
	h._fresh()
	s = h.s
	XZhenqi.pending_scale = {}
	XZhenqi.pojia_actor = null


func _r6(v: float) -> float:
	return snappedf(v, 0.000001)


## 原版 withDaofa：记上道法，学会对应奖励技能（被动标签来自技能）；extra 是另学的技能（键或编号）
func _daofa(aid: int, realm: int, keys: Array, extra := []) -> XActor:
	var a := s.actor(aid)
	var df := {}
	for k in keys:
		df[str(k)] = 1
	h._set_zq(a, {"realm": realm, "qi": int(XZhenqi.REALMS[realm].need), "daofa": df})
	for k in keys:
		a.learn_skill(XZhenqi.skill_key("daofa:" + str(k)))
	for k in extra:
		a.learn_skill(int(k) if (k is float or k is int) else XZhenqi.skill_key(str(k)))
	XZhenqi.refresh_rewards(a)
	return a


func _qi() -> Dictionary:
	var out := {}
	for a in s.members():
		out[str(a.actor_id)] = int(XZhenqi.data(a).qi)
	return out


func _gains(before: Dictionary) -> Dictionary:
	var out := {}
	for a in s.members():
		out[str(a.actor_id)] = int(XZhenqi.data(a).qi) - int(before[str(a.actor_id)])
	return out


func _spec_full() -> Dictionary:
	var sp := s.zhenqi_spec
	var parts := {}
	for k in [["w", "w"], ["e", "e"], ["t", "weaponTrials"]]:
		var ks: Array = sp.get(k[1], {}).keys()
		ks.sort_custom(func(x, y): return str(x) < str(y))
		parts[k[0]] = ks
	return parts


func _set_spec(sp) -> void:
	if not sp is Dictionary:
		return
	for part in sp:
		for k in sp[part]:
			s.zhenqi_spec[part][str(k)] = 1


# ---- 道法 ----
func _traits(o: Dictionary) -> Dictionary:
	var a := _daofa(1, int(o.realm), o.keys)
	var ps := a.action_plus_set()
	return {"attackTimesAdd": a.attack_times_add(), "actionPlusSet": ps.map(func(p): return _r6(p)),
		"makeActionTimes": 1 + ps.filter(func(p): return 0.5 < p).size(),   # 参照 Math.random 固定 0.5
		"shieldEffectBonus": _r6(XZhenqi.shield_effect_bonus(a)), "hit": _r6(a.xparam(0))}


func _hp(o: Dictionary) -> Dictionary:
	var a := _daofa(1, int(o.realm), o.keys, o.extra)
	var out := []
	var in_battle := false
	for hit in ["setup"] + o.hits:
		if hit is String:
			XZhenqi.battle_setup(s, 1)
			in_battle = not o.get("outside", false)
			out.append("setup")
			continue
		if str(hit.get("hp", "")) == "full":
			a.hp = a.mhp
		elif hit.has("hp"):
			a.hp = float(hit.hp)
		var hp0 := a.hp
		var v: float = hp0 + 50.0 if str(hit.v) == "lethal" else (hp0 if str(hit.v) == "exact" else float(hit.v))
		var val := XZhenqi.hp_damage(a, v) if in_battle else v
		a.hp = clampf(a.hp - val, 0.0, a.mhp)
		out.append({"hp0": hp0, "value": v, "hp": a.hp, "guard": a.zq_guard})
	return {"mhp": a.mhp, "hits": out}


func _subs(o: Dictionary) -> Dictionary:
	for aid in o.get("hufa", []):
		_daofa(int(aid), 3, ["hufa"])
	var logic: XBattleLogic = h._logic(1)
	for aid in o.get("dead", []):
		s.actor(int(aid)).add_state(1)
	var t := s.actor(8)
	t.hp = ceilf(t.mhp / 4.0) - (0.0 if str(o.get("hp", "")) == "quarter" else 1.0)
	var sid := int(o.get("skill", 1))
	var r := logic.substitute_for(XDB.rec("Skills", sid), t)
	return {"skill": sid, "hp": t.hp, "mhp": t.mhp, "dying": t.is_alive() and t.hp < t.mhp / 4.0, "got": r.actor_id,
		"subs": logic.actors.filter(func(x): return x.is_substitute()).map(func(x): return x.actor_id)}


func _tp(o: Dictionary) -> Dictionary:
	var a := _daofa(1, int(o.realm), o.keys, o.extra)
	a.tp = 50.0
	var logic: XBattleLogic = h._logic(1)   # 开战：没有保留 TP 时随机 0～24
	var start := a.tp
	a.tp = 70.0
	logic.end_battle()
	return {"preserve": a.is_preserve_tp(), "maxTp": a.max_tp(), "start": start, "end": a.tp}


## 普攻附加状态的效果（21 号 0）由 BattleLogic.apply 执行：用一个必中、无伤害、只附加普攻状态的技能，固定随机种子
const ATTACK_STATE_SKILL := {"id": 0, "name": "", "scope": 1, "hitType": 0, "repeats": 1, "tpGain": 0, "successRate": 100,
	"damage": {"type": 0, "formula": "0", "elementId": 0, "variance": 0, "critical": false},
	"effects": [{"code": 21, "dataId": 0, "value1": 1.0, "value2": 0.0}], "meta": {}, "note": ""}

func _pojia(o: Dictionary) -> Dictionary:
	var logic: XBattleLogic = h._logic(1)
	var a := _daofa(1, int(o.realm), o.keys)
	var e: XEnemy = logic.enemies[0]
	var rate := func(): return _r6(e.zq_pojia_rate) if e.is_state_affected(XZhenqi.POJIA_STATE) else null
	var traits := func():
		for st in e.states():
			if int(st.id) == XZhenqi.POJIA_STATE:
				return st.traits.filter(func(t): return int(t.code) == 21).map(func(t): return [int(t.dataId), _r6(t.value)])
		return null
	var sa: Array = a.attack_states()
	sa.sort()
	var out := {"attackStates": sa, "statesRate": _r6(a.attack_states_rate(XZhenqi.POJIA_STATE)),
		"chance": _r6(1.0 * logic.state_rate(e, XZhenqi.POJIA_STATE) * a.attack_states_rate(XZhenqi.POJIA_STATE) * maxf(1.0 + (a.luk - e.luk) * 0.001, 0.0)),
		"before": [e.param(3), e.param(5)]}
	if o.get("direct", false):
		e.add_state(XZhenqi.POJIA_STATE)
	else:
		# 附加几率 0.99：固定本场规则流（dev.099 起战斗不认全局 seed），结果不随运行变化
		logic.random = XBattleRandom.create(XRandomStream.hex64(20261018), 0)
		logic.apply(a, ATTACK_STATE_SKILL, e)
	e.refresh_resources()  # 同参照：krz 能力值缓存到 refresh 才放掉加状态前读过的格子
	out.merge({"affected": e.is_state_affected(XZhenqi.POJIA_STATE), "rate": rate.call(), "traits": traits.call(), "after": [e.param(3), e.param(5)]})
	if o.get("erase", false):
		e.remove_state(XZhenqi.POJIA_STATE)
		e.refresh_resources()
		out.erased = rate.call()
		e.add_state(XZhenqi.POJIA_STATE)
		e.refresh_resources()
		out.readd = {"affected": e.is_state_affected(XZhenqi.POJIA_STATE), "rate": rate.call(), "traits": traits.call(), "after": [e.param(3), e.param(5)]}
	return out


# ---- 神兵试炼 ----
func _weapon_fight(k: int, o: Dictionary) -> Dictionary:
	h._go({"page": "weapon"})
	h._pick(k)
	var troop := int(XZhenqi.weapon_masters()[k].troopId)
	var wild: bool = o.get("wild", false)
	if wild:
		XZhenqi.pending_scale = {}
	var logic: XBattleLogic = h._logic(troop)
	var b := XZhenqi.battle
	var en := []
	for e in logic.enemies:
		en.append({"enemyId": e.enemy_id, "base": range(8).map(func(i): return e.param_base(i) / float(e._rates[i])), "hp": e.hp,
			"drops": null if wild else logic.drops_of(e).size()})
	for i in range(logic.enemies.size()):
		if not (o.get("masterAlive", false) and i == 0):
			logic.enemies[i].add_state(1)
	var items = null if wild else logic.rewards().drops.size()
	var before := _qi()
	XZhenqi.toasts.clear()
	XZhenqi.on_victory(s, logic.actors, XZhenqi.troop_members(troop, logic.enemies, s.difficulty))
	return {"troop": troop, "battle": {"scaled": not b.scaled.is_empty(), "trial": not b.trial.is_empty(), "guardianFloor": b.guardianFloor, "floor": b.floor,
		"comp": _r6(b.comp), "route": b.route.key}, "enemies": en, "items": items, "spec": _spec_full(), "toasts": XZhenqi.toasts.duplicate(),
		"gains": _gains(before), "cleared": XZhenqi.battle.is_empty() and XZhenqi.pending_scale.is_empty()}


# ---- 隐藏成员 ----
## 原版合成用例：把一个降服用 Boss（非守层者敌群）改成隐藏成员，只打倒其余成员，胜利结算照样降服、照样按 Boss 胜利记真气
func _hidden_unlock() -> Dictionary:
	var tid := 0
	var idx := -1
	for t in XDB.table("Troops"):
		if tid or not t is Dictionary or t.get("members", []).is_empty() or XZhenqi.GUARDIANS.has(int(t.id)):
			continue
		for i in range(t.members.size()):
			var e := XEnemy.new().setup(int(t.members[i].enemyId), s.difficulty, 100.0)
			if XZhenqi.is_boss_enemy(e) and str(e.data().get("note", "")).containsn("<Element Absorb:"):
				tid = int(t.id)
				idx = i
				break
	var m: Dictionary = XDB.rec("Troops", tid).members[idx]
	var was = m.get("hidden", false)
	m.hidden = true
	var before := _qi()
	var logic: XBattleLogic = h._logic(tid)
	for e in logic.enemies:
		e.add_state(1)
	XZhenqi.toasts.clear()
	XZhenqi.on_victory(s, logic.actors, XZhenqi.troop_members(tid, logic.enemies, s.difficulty))
	var hidden: Array = XDB.rec("Troops", tid).members.map(func(x): return bool(x.get("hidden", false)))
	m.hidden = was
	return {"troop": tid, "index": idx, "hidden": hidden, "spec": h._spec(), "toasts": XZhenqi.toasts.duplicate(), "gains": _gains(before)}


func _case(id: String, o: Dictionary):
	_fresh()
	h._setup(o)
	_set_spec(o.get("spec"))
	if id.begins_with("daofa.traits."):
		return _traits(o)
	if id.begins_with("daofa.hp."):
		return _hp(o)
	if id.begins_with("daofa.subs."):
		return _subs(o)
	if id.begins_with("daofa.tp."):
		return _tp(o)
	if id.begins_with("daofa.pojia."):
		return _pojia(o)
	if id.begins_with("weapon.menu."):
		var v = h._go({"page": "weapon"})
		var n: int = h.cur.options.size()
		var leave: bool = h.cur.options[n - 1].next == null
		return {"view": v, "leaveIsNull": leave, "back": h._pick(n - 2)}
	if id.begins_with("weapon.start.k"):
		h._go({"page": "weapon"})
		var v = h._pick(int(id.substr(14)))
		var p := XZhenqi.pending_scale
		return {"view": v, "pending": {"ref": p.ref, "master": p.master, "wtype": p.wtype, "troopId": p.troopId} if not p.is_empty() else null}
	if id.begins_with("weapon.fight.") and id != "weapon.fight.twice":
		var k: int = {"k0": 0, "k3.hard": 3, "f0": 6, "masterAlive": 1, "preW": 2, "wild": 0}[id.substr(13)]
		return _weapon_fight(k, o)
	match id:
		"weapon.masters":
			return XZhenqi.weapon_masters()
		"weapon.fromRetreat":
			h._go({"page": "retreat"})
			return h._pick(h.cur.options.size() - 2)
		"weapon.fight.twice":
			var first := _weapon_fight(0, {})
			XZhenqi.toasts.clear()
			return {"first": first, "second": _weapon_fight(0, {})}
		"hidden.bosses":
			var out := []
			for t in XDB.table("Troops"):
				if not t is Dictionary or not t.get("members", []).any(func(x): return bool(x.get("hidden", false))):
					continue
				var hid := []
				for x in t.members:
					if bool(x.get("hidden", false)) and XZhenqi.is_boss_enemy(XEnemy.new().setup(int(x.enemyId), s.difficulty, 100.0)):
						hid.append(int(x.enemyId))
				if not hid.is_empty():
					out.append([int(t.id), hid])
			return out
		"hidden.unlock":
			return _hidden_unlock()
	return null


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	var n := 0
	if check("zhenqi_oracle_loaded", data is Dictionary, ORACLE):
		for c in data.cases:
			if not Base.THIRD.any(func(p): return c.id.begins_with(p)):
				continue
			n += 1
			if not c.errors.is_empty():
				check("oracle_" + c.id, false, c.errors)
				continue
			var got = _case(c.id, c.setup)
			var want = c.observed
			if c.id.begins_with("daofa.tp.") and want is Dictionary and not want.preserve and got is Dictionary:
				check(c.id + ".random_start", got.start >= 0.0 and got.start < 25.0, got)   # 没有保留 TP：开战随机 0～24
				got.start = want.start
			if c.id == "daofa.subs.dead" and want is Dictionary:
				want = want.duplicate(true)
				want.got = 8   # O-048：倒下的护法不再掩护（原版仍由它挨打）
			check(c.id, (got != null or want == null) and h._same(got, want), [got, want])
	check("third_batch_cases", n >= 50, n)
	_wiring()
	_extra()
	await _flow()
	var failed := results.filter(func(r): return not r.passed)
	h._cmp.free()
	h.free()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_zhenqi_daofa", "passed": results.size() - failed.size(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit(0 if failed.is_empty() else 1)


## 接线：BattleLogic 里真打——元婴护体挡下致命一击、分神多一次行动、连击多一段普攻、掩护换目标
func _wiring() -> void:
	_fresh()
	var a := _daofa(1, 3, ["lianji", "fenshen"], ["fixed:yuanying"])
	var logic: XBattleLogic = h._logic(456)   # 二十层守层者：一击必定超过 2 点
	var e: XEnemy = logic.enemies[0]
	var attack := XDB.rec("Skills", 1)
	a.hp = 2.0
	var hit := {}
	for i in range(20):
		hit = logic.apply(e, attack, a)
		if not hit.missed and not hit.evaded:
			break
	check("wire_yuanying", a.hp == 1.0 and a.zq_guard, [a.hp, a.zq_guard, hit.get("hp")])
	check("wire_action_times", logic.make_action_times(a) == 2, a.action_plus_set())
	check("wire_attack_times", a.attack_times_add() == 1.0)
	_fresh()
	_daofa(9, 3, ["hufa"])
	logic = h._logic(1)
	var t := s.actor(8)
	t.hp = 1.0
	var r: Array = logic._invoke(logic.enemies[0], XDB.rec("Skills", 1), t)
	check("wire_substitute", r.size() == 1 and r[0].target == s.actor(9), r.map(func(x): return str(x.get("target"))))


## 存档：神兵试炼记录往返；读档清掉进行中的神兵试炼
func _extra() -> void:
	_fresh()
	s.zhenqi_spec.w["3"] = 1
	s.zhenqi_spec.weaponTrials["3"] = 1
	XZhenqi.pending_scale = {"troopId": 904}
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check("save_weapon_trials", back.zhenqi_spec.w.has("3") and back.zhenqi_spec.weaponTrials.has("3"), back.zhenqi_spec)
	XState._become_current(back)
	check("load_clears_weapon_trial", XZhenqi.pending_scale.is_empty())


## 固定应答宿主：开战时打倒全部敌人再按胜利结算
class WinHost:
	var picks: Array = []
	var trace: Array = []

	func show_message(m: Dictionary) -> int:
		trace.append({"lines": m.lines, "choices": m.get("choices")})
		if m.has("choices"):
			return int(picks.pop_front()) if not picks.is_empty() else m.choices.size() - 1
		return 0

	func start_battle(troop: int, can_escape: bool, can_lose: bool, _random_encounter := false) -> int:
		trace.append({"battle": troop, "escape": can_escape, "lose": can_lose})
		var logic := XBattleLogic.new()
		logic.setup(troop, XState.current)
		for e in logic.enemies:
			e.add_state(1)
		XZhenqi.on_victory(XState.current, logic.actors, XZhenqi.troop_members(troop, logic.enemies, XState.current.difficulty))
		logic.end_battle()
		return 0


## XZhenqiRetreat：闭关首页→神兵试炼→刺仙（903，不能逃、可以输）→打赢后本命兵可指定匕首、试炼完成，打完不回菜单
func _flow() -> void:
	_fresh()
	XState._become_current(s)
	s.set_variable(20, 13)
	var w := WinHost.new()
	w.picks = [4, 0]
	await XZhenqiRetreat.run(w)
	var battles := w.trace.filter(func(x): return x.has("battle"))
	check("flow_weapon_battle", battles.size() == 1 and int(battles[0].battle) == 903 and not battles[0].escape and battles[0].lose, w.trace)
	check("flow_weapon_done", s.zhenqi_spec.w.has("1") and s.zhenqi_spec.weaponTrials.has("1") and XZhenqi.toasts.any(func(x): return str(x).contains("神兵试炼完成")), [s.zhenqi_spec, XZhenqi.toasts])
	check("flow_weapon_ends", w.trace[-1].has("battle"), w.trace[-1])
