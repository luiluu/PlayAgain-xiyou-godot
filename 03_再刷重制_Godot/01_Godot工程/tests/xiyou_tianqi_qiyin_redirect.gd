extends Node
## 【cc·T234·未经审查】战真印「击倒敌人时把剩下的段转给另一个敌人」（overflow_hits_redirect）在动作序列招上接通（XTianqiQiyinEffects.SEQ_REDIRECT）；
## 「0 血挂 IMMORTAL 算不算活着」统一口径（XTianqiQiyinEffects.standing／DOWN_RULE）。
## 背景：转段原来只在 battle_logic.execute 非序列分支调；库里技能全带 yepSeq（普攻也是），序列路 _action_effect 没接，
##   而且序列里目标挂 IMMORTAL，0 血不算 is_dead()，剩下的段照打在 0 血目标上。
## 一、量清：普攻、序列单体招、序列群体招、非序列多段招 × 开关开／关 × PER_SEGMENT（XBattleStream）开／关：
##   低血目标挨了几段（打倒以后还挨的＝浪费）、别的敌人挨了几段，打印 QIYIN_REDIRECT_TABLE。
## 二、口径：standing、_next_enemy（疫满层穿透）、一力降十会名额；DOWN_RULE 关回到只看 is_alive。
## 三、西游档不转；没戴战真印不转；没有别的敌人时照原样打在原目标上。
## 夹具同 xiyou_tianqi_qiyin_seq_kill：天启篇开局存档（艰险）打敌群 2，装备直接造实例、打标记。

const ARMOR_ID := 1
const WEAPON_ID := 1

var results: Array = []
var table: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids() -> Array:
	return XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _logic(tianqi := true) -> XBattleLogic:
	var w := _ids()
	var lineup := [w[0], w[1], w[2], w[3], w[4]]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, "jianxian", lineup)
		XTianqi.take_pending()
	else:
		s = XState.new()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in lineup:
		s.actor(id).recover_all()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	return lg


func _wear(a: XActor, marks: Array) -> void:
	a.keep_unequippable = true
	for m in marks:
		var inst := XGear.create("weapon", WEAPON_ID, XState.current)
		if inst.is_empty():
			inst = {"kind": "weapon", "name": "测试", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 1}
		XTianqiQiyinEffects.mark(inst, m)
		a.equips[0] = inst
	a.param_mark_dirty()
	a.param_refresh()


## 战真印剑：流派印记 攻击次数 +1（extra_hits）＋真印 overflow_hits_redirect
func _true_hong() -> Array:
	return [{"kind": "weapon", "seal": "hong", "wtype": "sword", "true_seal": true}]


func _plain(scope: int, repeats: int) -> Dictionary:
	var c := _seq_skill(scope)
	if c.is_empty():
		return c
	c.erase("yepSeq")
	c.repeats = repeats
	return c


func _seq_skill(scope: int) -> Dictionary:
	for rec in XDB.table("Skills"):
		if rec == null or not (rec is Dictionary) or not XActionSequence.has_sequence(rec):
			continue
		if int(rec.get("scope", 0)) != scope or int(rec.get("damage", {}).get("type", 0)) != 1 or int(rec.get("id", 0)) <= 2:
			continue
		var c: Dictionary = rec.duplicate(true)
		c.mpCost = 0
		c.tpCost = 0
		return c
	return {}


func _prep(lg: XBattleLogic, low: Array) -> void:
	for e in lg.enemies:
		e.recover_all()
		e.shield = 0.0
		e.immortal = false
	for e in low:
		e.hp = 1.0


## 出一招：数每个敌人挨的段（hit 记录，没打空的）
func _probe(kind: String, skill_of: Callable, low_n: int, per_segment: bool, tianqi := true, marks = null) -> Dictionary:
	var lg := _logic(tianqi)
	var u: XActor = lg.actors[0]
	_wear(u, _true_hong() if marks == null else marks)
	XTianqiQiyinEffects.start(lg)
	var sk: Dictionary = skill_of.call(u)
	if sk.is_empty() or lg.enemies.size() < low_n + 1:
		lg.end_battle(0)
		return {"kind": kind, "skip": true}
	var low := []
	for i in low_n:
		low.append(lg.enemies[i])
	_prep(lg, low)
	var logs: Array
	if per_segment:
		var s := XBattleStream.start(lg, u, sk, low[0])
		s.finish()
		logs = s.out
	else:
		logs = lg.act(u, sk, low[0])
	var hits_low := 0
	var hits_other := 0
	for l in logs:
		if not (l is Dictionary) or l.get("type") != "hit" or not is_same(l.get("user"), u):
			continue
		if bool(l.get("missed", false)) or bool(l.get("evaded", false)):
			continue
		if low.has(l.get("target")):
			hits_low += 1
		elif lg.enemies.has(l.get("target")):
			hits_other += 1
	var row := {"kind": kind, "seq": XActionSequence.has_sequence(sk), "per_segment": per_segment, "switch": XTianqiQiyinEffects.SEQ_REDIRECT,
		"tianqi": tianqi, "enemies": lg.enemies.size(), "dead_low": low.filter(func(x): return x.is_dead()).size(),
		"hits_low": hits_low, "hits_other": hits_other}
	lg.end_battle(0)
	return row


func _kinds() -> Array:
	return [
		["普攻", func(u): return u.attack_skill(), 1],
		["序列单体招", func(_u): return _seq_skill(1), 1],
		["序列群体招", func(_u): return _seq_skill(2), 2],
		["非序列多段招", func(_u): return _plain(1, 2), 1],
	]


func _measure() -> void:
	var by := {}
	for on in [false, true]:
		XTianqiQiyinEffects.SEQ_REDIRECT = on
		for ps in [false, true]:
			for k in _kinds():
				var row := _probe(k[0], k[1], k[2], ps)
				table.append(row)
				by["%s|%s|%s" % [k[0], on, ps]] = row
	XTianqiQiyinEffects.SEQ_REDIRECT = true
	print("QIYIN_REDIRECT_TABLE ", JSON.stringify(table))
	for row in table:
		if bool(row.get("skip", false)):
			_check("probe_skill_found_%s" % row.kind, false, row)
			continue
		var tag := "%s_%s%s" % [row.kind, "on" if row.switch else "off", "_stream" if row.per_segment else ""]
		var n := 2 if str(row.kind).begins_with("序列群体") else 1
		_check("dead_" + tag, int(row.dead_low) == n, row)
		if row.switch or not row.seq:
			# 每个低血目标只挨致命那一段，剩下的都转给别人
			_check("redirect_" + tag, int(row.hits_low) == n and int(row.hits_other) >= 1, row)
		else:
			_check("off_wasted_" + tag, int(row.hits_low) > n, row)  # 回退：序列招剩下的段照打在 0 血目标上
	# 段数守恒：开、关总段数一样（只换了目标）；PER_SEGMENT 开、关结果一样
	for k in _kinds():
		var a: Dictionary = by.get("%s|%s|%s" % [k[0], true, false], {})
		var b: Dictionary = by.get("%s|%s|%s" % [k[0], false, false], {})
		var c: Dictionary = by.get("%s|%s|%s" % [k[0], true, true], {})
		if a.has("skip") or b.has("skip") or c.has("skip"):
			continue
		if bool(a.seq):
			_check("hits_conserved_" + k[0], int(a.hits_low) + int(a.hits_other) == int(b.hits_low) + int(b.hits_other), [a, b])
		_check("stream_same_" + k[0], a.hits_low == c.hits_low and a.hits_other == c.hits_other and a.dead_low == c.dead_low, [a, c])


func _edges() -> void:
	# 西游档：七印不生效，序列普攻照旧打在 0 血目标上
	var leg := _probe("西游档普攻", func(u): return u.attack_skill(), 1, false, false)
	_check("legacy_no_redirect", not leg.has("skip") and int(leg.hits_other) == 0, leg)
	# 没戴战真印（同流派武器但不是真印）：普攻 2 段，第二段照打 0 血目标
	var plain := _probe("非真印普攻", func(u): return u.attack_skill(), 1, false, true, [{"kind": "weapon", "seal": "hong", "wtype": "sword", "true_seal": false}])
	_check("no_true_seal_no_redirect", int(plain.hits_other) == 0 and int(plain.hits_low) == 2, plain)
	# 只剩一个敌人：没得转，照原样打在原目标上（不丢段）
	var lg := _logic()
	var u: XActor = lg.actors[0]
	_wear(u, _true_hong())
	XTianqiQiyinEffects.start(lg)
	_prep(lg, [lg.enemies[0]])
	for i in range(1, lg.enemies.size()):
		lg.enemies[i].hp = 0.0
		lg._die(lg.enemies[i])
	var logs := lg.act(u, u.attack_skill(), lg.enemies[0])
	var n := logs.filter(func(l): return l is Dictionary and l.get("type") == "hit" and is_same(l.get("user"), u) and is_same(l.get("target"), lg.enemies[0])).size()
	_check("last_enemy_keeps_hits", n == 2 and lg.enemies[0].is_dead(), n)
	lg.end_battle(0)


## 口径：standing／_next_enemy／一力降十会，DOWN_RULE 开关两边
func _rule() -> void:
	var lg := _logic()
	var u: XActor = lg.actors[0]
	_wear(u, _true_hong())
	XTianqiQiyinEffects.start(lg)
	_prep(lg, [])
	var e0: XEnemy = lg.enemies[0]
	var e1: XEnemy = lg.enemies[1]
	e1.immortal = true
	e1.hp = 0.0
	_check("standing_immortal_zero", not XTianqiQiyinEffects.standing(e1) and e1.is_alive(), [e1.hp, e1.is_alive()])
	_check("standing_alive", XTianqiQiyinEffects.standing(e0))
	XTianqiQiyinEffects.DOWN_RULE = true
	var nx = XTianqiQiyinEffects._next_enemy(lg, e0)
	_check("next_enemy_skips_down", nx != null and not is_same(nx, e1), nx)
	_check("redirect_skips_down", not is_same(XTianqiQiyinEffects.redirect(lg, u, u.attack_skill(), e0), e1))
	XTianqiQiyinEffects.DOWN_RULE = false
	_check("next_enemy_off_old", is_same(XTianqiQiyinEffects._next_enemy(lg, e0), e1))
	# seq_redirect 不归 DOWN_RULE 管（T234 P3-1）：关着时也越过 0 血挂 IMMORTAL 的 e1、转给后面站着的
	e0.immortal = true
	e0.hp = 0.0
	if lg.enemies.size() >= 3:
		var nt2 = XTianqiQiyinEffects.seq_redirect(lg, u, u.attack_skill(), e0)
		_check("seq_redirect_off_skips_down", nt2 != null and XTianqiQiyinEffects.standing(nt2) and not is_same(nt2, e1), nt2)
	else:
		_check("seq_redirect_off_skips_down_need3", false, lg.enemies.size())
	var only_down := lg.enemies.filter(func(x): return not is_same(x, e0) and not is_same(x, e1))
	for x in only_down:
		x.hp = 0.0
		lg._die(x)
	_check("seq_redirect_off_only_down_left", XTianqiQiyinEffects.seq_redirect(lg, u, u.attack_skill(), e0) == null)
	XTianqiQiyinEffects.DOWN_RULE = true
	_check("seq_redirect_none_left", XTianqiQiyinEffects.seq_redirect(lg, u, u.attack_skill(), e0) == null)
	lg.end_battle(0)
	# 一力降十会：蓄势这一击打在 0 血挂 IMMORTAL 的目标上不占名额（直接调 after_apply）
	for on in [true, false]:
		XTianqiQiyinEffects.DOWN_RULE = on
		var lg2 := _logic()
		var a: XActor = lg2.actors[0]
		XTianqiQiyinEffects.start(lg2)
		_prep(lg2, [])
		var t: XEnemy = lg2.enemies[0]
		var sk := a.attack_skill()
		XTianqiQiyinEffects.begin_action(lg2, a, sk)
		var st: Dictionary = XTianqiQiyinEffects._store(lg2)
		st.act.idle = true
		st.fx[a] = {"target_lose_action": {"code": "target_lose_action", "count": 1}}
		t.immortal = true
		t.hp = 0.0
		XTianqiQiyinEffects.after_apply(lg2, a, sk, t, {"hp": 10.0})
		var used := bool(XTianqiQiyinEffects._unit(lg2, t).lose_used)
		_check("lose_action_%s" % ("on" if on else "off"), used != on, used)
		lg2.end_battle(0)
	XTianqiQiyinEffects.DOWN_RULE = true


func _run() -> void:
	XTianqiQiyinEffects.ENABLED = true
	_measure()
	_edges()
	_rule()
	XTianqiQiyinEffects.SEQ_REDIRECT = true
	XTianqiQiyinEffects.DOWN_RULE = true
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
