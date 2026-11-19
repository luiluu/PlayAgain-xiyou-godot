extends Node
## 【cc·T232·未经审查】七印「击倒」类效果在各类出招上认不认得到击倒（XTianqiQiyinEffects.SEQ_KILLS，O-待定-1）；
## 词条「斩获」同病同法（XTianqiAffixBattle.SEQ_KILLS，O-待定-2）；技能重构击杀成长／击杀回 TP 同病同法（XTianqiSkills.SEQ_KILLS，O-待定-3，R1）。
## 背景：动作序列招（含普攻）开头把目标挂 IMMORTAL，打到 0 血也不倒，序列收尾解除时才倒下；
## after_apply 当场用 is_dead() 认击倒，序列招上永远认不到 → 击倒再动、送行连斩、溢出、击杀叠层都不触发（T230 另查）。
## 修法：after_apply 里「这一击把 IMMORTAL 目标打到 0 血」先记成待定击倒（连同溢出），end_action（序列已收尾、IMMORTAL 已解除）再按 is_dead() 认。
## 一、量清：普攻、动作序列单体招、动作序列群体招、单段招、多段招、派生追加（送行连斩）× 开关开／关，击倒再动、击杀计数、溢出、连斩各认没认到，打印 QIYIN_SEQ_KILL_TABLE。
## 二、边界：一招打倒多个；不死目标（打到 0 血不倒）不算；序列中途被救回（复活／回血）不算；先打到 0 又救回、再打到 0 算一次；
##     派生追加里打倒的不回灌主行动；PER_SEGMENT（XBattleStream 逐段结算）开、关结果相同。
## 四、斩获：普攻、序列群体招（打倒 2 个只回一次）、非序列单段 × 开关开／关、PER_SEGMENT；序列里被救回不回；两个开关各自单独关。
## 三、开关关掉回到旧行为（序列招认不到）；西游档不建七印数据。
## 用天启篇开局建的存档（艰险）打敌群 2；装备直接造实例、打标记（夹具同 xiyou_tianqi_qiyin_effects）。

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
	var slot := 1
	for m in marks:
		var kind := "weapon" if str(m.kind) == "weapon" else "armor"
		var inst := XGear.create(kind, WEAPON_ID if kind == "weapon" else ARMOR_ID, a.state if "state" in a else XState.current)
		if inst.is_empty():
			inst = {"kind": kind, "name": "测试", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 1 if kind == "weapon" else 3}
		XTianqiQiyinEffects.mark(inst, m)
		if kind == "weapon":
			a.equips[0] = inst
		else:
			while slot < a.equips.size() - 1 and a.equips[slot] != null and not a.equips[slot].is_empty() and not XTianqiQiyinEffects.mark_of(a.equips[slot]).is_empty():
				slot += 1
			if slot >= a.equips.size():
				a.equips.append(inst)
			else:
				a.equips[slot] = inst
			slot += 1
	a.param_mark_dirty()
	a.param_refresh()


func _gear_set(seal: String, n: int) -> Array:
	var parts := ["head", "body", "hands", "waist", "legs", "feet"]
	var out := []
	for i in n:
		out.append({"kind": "set", "seal": seal, "part": parts[i], "true_seal": false})
	return out


## 非序列招：同 scope 的序列招去掉 yepSeq、段数换成 repeats（走 execute 的非序列分支：每段 _invoke，收尾只 refresh、不挂 IMMORTAL）
func _plain(scope: int, repeats: int) -> Dictionary:
	var c := _seq_skill(scope)
	if c.is_empty():
		return c
	c.erase("yepSeq")
	c.repeats = repeats
	return c


## 序列招：从库里挑第一个「有 yepSeq、物理或魔法伤害、指定 scope、不耗 TP」的技能，不耗费（只换副本，不动库）
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


## 每场：把其余敌人回满，目标血设 1；挂 IMMORTAL 的序列收尾才倒下
func _prep(lg: XBattleLogic, low: Array) -> void:
	for e in lg.enemies:
		e.recover_all()
		e.shield = 0.0
		e.immortal = false
	for e in low:
		e.hp = 1.0


## 出一招，返回认没认到：再动（current_order 推了自己）、击杀计数、溢出（下一个敌人掉血）、连斩（派生日志）
func _probe(kind: String, seal_marks: Array, skill_of: Callable, low_n: int, per_segment: bool) -> Dictionary:
	var lg := _logic()
	var u: XActor = lg.actors[0]
	_wear(u, seal_marks)
	XTianqiQiyinEffects.start(lg)
	var sk: Dictionary = skill_of.call(u)
	if sk.is_empty():
		lg.end_battle(0)
		return {"kind": kind, "skip": true}
	var low := []
	for i in low_n:
		low.append(lg.enemies[i])
	_prep(lg, low)
	var others := lg.enemies.filter(func(x): return not low.has(x))
	var hp_before := others.map(func(x): return x.hp)
	lg.current_order.clear()
	var logs: Array
	if per_segment:
		var s := XBattleStream.start(lg, u, sk, low[0])
		s.finish()
		logs = s.out
	else:
		logs = lg.act(u, sk, low[0])
	var un: Dictionary = XTianqiQiyinEffects._unit(lg, u)
	var dropped := false
	for i in others.size():
		if others[i].hp < hp_before[i]:
			dropped = true
	var row := {"kind": kind, "seq": XActionSequence.has_sequence(sk), "per_segment": per_segment,
		"dead": low.filter(func(x): return x.is_dead()).size(), "kills": int(un.kills),
		"again": lg.current_order.any(func(x): return is_same(x, u)), "other_dropped": dropped,
		"derived": logs.filter(func(l): return l is Dictionary and l.get("type") == "action" and is_same(l.get("user"), u)).size() - 1}
	lg.end_battle(0)
	return row


func _kinds() -> Array:
	return [
		["普攻", func(u): return u.attack_skill(), 1],
		["序列单体招", func(_u): return _seq_skill(1), 1],
		["序列群体招", func(_u): return _seq_skill(2), 2],
		["单段招", func(_u): return _plain(1, 1), 1],
		["多段招", func(_u): return _plain(1, 3), 1],
		["群体单段招", func(_u): return _plain(2, 1), 2],
	]


func _measure() -> void:
	var hong5 := _gear_set("hong", 5)  # 红印 5 件：击倒后再行动一次；3 件：击杀叠层（kills）
	for on in [false, true]:
		XTianqiQiyinEffects.SEQ_KILLS = on
		for k in _kinds():
			var row := _probe(k[0], hong5, k[1], k[2], false)
			row.switch = on
			table.append(row)
	XTianqiQiyinEffects.SEQ_KILLS = true
	for k in _kinds():
		if k[0] in ["普攻", "序列单体招", "序列群体招", "单段招"]:
			var row := _probe(k[0], hong5, k[1], k[2], true)
			row.switch = true
			table.append(row)
	print("QIYIN_SEQ_KILL_TABLE ", JSON.stringify(table))
	for row in table:
		if bool(row.get("skip", false)):
			_check("probe_skill_found_%s" % row.kind, false, row)
			continue
		var tag := "%s_%s%s" % [row.kind, "on" if row.switch else "off", "_stream" if row.per_segment else ""]
		var n := 2 if str(row.kind).begins_with("序列群体") or str(row.kind).begins_with("群体") else 1
		_check("dead_" + tag, int(row.dead) == n, row)
		if row.switch or not row.seq:
			_check("kill_again_" + tag, bool(row.again) and int(row.kills) == n, row)
		else:
			_check("off_seq_missed_" + tag, not bool(row.again) and int(row.kills) == 0, row)  # 回退：旧行为（序列招认不到）


## 溢出（大刀阔斧）、送行连斩：普攻（序列）打倒 1 血敌人后，溢出落到下一个敌人、连斩出派生一击；开关关时都没有
func _carry_chain() -> void:
	for on in [true, false]:
		XTianqiQiyinEffects.SEQ_KILLS = on
		var tag := "on" if on else "off"
		var over := _probe("普攻", [{"kind": "weapon", "seal": "hong", "key": "dadaokuofu"}], func(u): return u.attack_skill(), 1, false)
		_check("overkill_carry_" + tag, bool(over.other_dropped) == on and int(over.dead) == 1, over)
		var chain := _probe("普攻", [{"kind": "weapon", "seal": "hui", "key": "songxing"}], func(u): return u.attack_skill(), 1, false)
		_check("kill_chain_slash_" + tag, (int(chain.derived) >= 1) == on and bool(chain.other_dropped) == on, chain)
	XTianqiQiyinEffects.SEQ_KILLS = true
	var lg := _logic()
	var u: XActor = lg.actors[0]
	_wear(u, [{"kind": "weapon", "seal": "hui", "key": "songxing"}])
	XTianqiQiyinEffects.start(lg)
	_check("fixture_songxing_has_chain", XTianqiQiyinEffects.effects(lg, u).has("kill_chain_slash"))
	lg.end_battle(0)


## 边界（直接调 begin_action／before_apply／after_apply／end_action，模拟序列里 IMMORTAL 的时序）
func _edges() -> void:
	var lg := _logic()
	var u: XActor = lg.actors[0]
	_wear(u, _gear_set("hong", 5) + [{"kind": "weapon", "seal": "hong", "key": "dadaokuofu"}])
	XTianqiQiyinEffects.start(lg)
	var sk := u.attack_skill()
	var e: XEnemy = lg.enemies[0]
	var nx: XEnemy = lg.enemies[1]
	var un: Dictionary = XTianqiQiyinEffects._unit(lg, u)
	# 1 序列里被救回（复活／回血）：0 血时挂着 IMMORTAL，收尾前回到 50 血 → 不算击倒
	_prep(lg, [])
	lg.current_order.clear()
	XTianqiQiyinEffects.begin_action(lg, u, sk)
	_hit_to_zero(lg, u, sk, e, 30.0)
	e.immortal = false
	e.hp = 50.0
	XTianqiQiyinEffects.end_action(lg, u, sk)
	_check("edge_rescued_not_kill", int(un.kills) == 0 and lg.current_order.is_empty(), [un.kills, lg.current_order.size()])
	# 2 不死（0 血不倒：resource_death_blocked 同 IMMORTAL 外的免死）→ 不算
	_prep(lg, [])
	XTianqiQiyinEffects.begin_action(lg, u, sk)
	_hit_to_zero(lg, u, sk, e, 30.0)
	e.immortal = false
	e.resource_death_blocked = true
	var undying := not e.is_dead()
	XTianqiQiyinEffects.end_action(lg, u, sk)
	e.resource_death_blocked = false
	_check("edge_undying_not_kill", undying and int(un.kills) == 0 and lg.current_order.is_empty(), [undying, un.kills])
	# 3 打到 0 → 救回 → 再打到 0，收尾倒下：算一次，溢出按最后一次；0 血上再挨的段不改溢出
	_prep(lg, [])
	var nx0 := nx.hp
	XTianqiQiyinEffects.begin_action(lg, u, sk)
	_hit_to_zero(lg, u, sk, e, 30.0)
	e.hp = 20.0
	_hit_to_zero(lg, u, sk, e, 70.0)
	_hit_to_zero(lg, u, sk, e, 900.0)  # 0 血上的段
	e.immortal = false
	lg._die(e)
	XTianqiQiyinEffects.end_action(lg, u, sk)
	_check("edge_twice_one_kill", int(un.kills) == 1 and lg.current_order.size() == 1, [un.kills, lg.current_order.size()])
	_check("edge_overflow_last_lethal", is_equal_approx(nx0 - nx.hp, 50.0), [nx0, nx.hp])
	# 4 一招打倒多个（含一个当场倒下的非 IMMORTAL、一个序列收尾倒下的）：都算
	_prep(lg, [])
	un.kills = 0
	un.extra_used = 0
	var e2: XEnemy = lg.enemies[2] if lg.enemies.size() > 2 else lg.enemies[1]
	XTianqiQiyinEffects.begin_action(lg, u, sk)
	_hit_to_zero(lg, u, sk, e, 30.0)
	XTianqiQiyinEffects.before_apply(lg, u, sk, e2)
	e2.hp = 0.0
	lg._die(e2)
	XTianqiQiyinEffects.after_apply(lg, u, sk, e2, {"hp": 10.0, "state_value": 10.0 + 0.0})
	e.immortal = false
	lg._die(e)
	XTianqiQiyinEffects.end_action(lg, u, sk)  # R1 P3-2：不再手动 confirm_pending，看 end_action 自己认的结果
	_check("edge_multi_kill", int(un.kills) == 2 and lg.current_order.size() >= 1, [un.kills, lg.current_order.size()])
	# 4b 不死（状态抗死 TRAIT_STATE_RESIST 1）：序列收尾 0 血不倒 → 不算（R1 P3-2）
	_prep(lg, [])
	un.kills = 0
	un.extra_used = 0
	lg.current_order.clear()
	XTianqiQiyinEffects.begin_action(lg, u, sk)
	_hit_to_zero(lg, u, sk, e, 30.0)
	e.immortal = false
	var resists := _add_resist(e)
	var undying2 := resists and not e.is_dead()
	XTianqiQiyinEffects.end_action(lg, u, sk)
	_drop_resist(e)
	_check("edge_state_resist_not_kill", undying2 and int(un.kills) == 0 and lg.current_order.is_empty(), [resists, undying2, un.kills])
	# 4c 救回后不经 after_apply 再倒（序列 HP＋救回、HP－打回 0、收尾倒下）：击倒照算，旧溢出作废（R1 P3-1）
	_prep(lg, [])
	un.kills = 0
	un.extra_used = 0
	lg.current_order.clear()
	var nx1 := nx.hp
	XTianqiQiyinEffects.begin_action(lg, u, sk)
	_hit_to_zero(lg, u, sk, e, 500.0)
	e.hp = 40.0  # 序列 HP＋（不经 apply）
	e.hp = 0.0  # 序列 HP－（不经 apply）
	e.immortal = false
	lg._die(e)
	XTianqiQiyinEffects.end_action(lg, u, sk)
	_check("edge_rescued_then_dead_no_stale_overflow", int(un.kills) == 1 and is_equal_approx(nx.hp, nx1), [un.kills, nx1, nx.hp])
	# 5 开关关：0 血 IMMORTAL 不记待定
	XTianqiQiyinEffects.SEQ_KILLS = false
	_prep(lg, [])
	XTianqiQiyinEffects.begin_action(lg, u, sk)
	_hit_to_zero(lg, u, sk, e, 30.0)
	_check("edge_off_no_pending", (XTianqiQiyinEffects._store(lg).act.get("pending", []) as Array).is_empty())
	XTianqiQiyinEffects.end_action(lg, u, sk)
	XTianqiQiyinEffects.SEQ_KILLS = true
	lg.end_battle(0)


## 给敌人挂一个带「抗死」特性的状态；返回 traits_set 认没认到
func _add_resist(e: XEnemy) -> bool:
	e.add_state(_resist_state())
	e.param_mark_dirty()
	return e.traits_set(XBattler.TRAIT_STATE_RESIST).has(1)


func _drop_resist(e: XEnemy) -> void:
	e.remove_state(_resist_state())
	e.param_mark_dirty()


## 库里第一个带「抗死（状态抗性 1）」特性的状态
func _resist_state() -> int:
	for rec in XDB.table("States"):
		if rec is Dictionary and int(rec.get("id", 0)) > 1:
			for tr in rec.get("traits", []):
				if int(tr.get("code", 0)) == XBattler.TRAIT_STATE_RESIST and int(tr.get("dataId", 0)) == 1:
					return int(rec.id)
	return 0


## 一段：挂 IMMORTAL，从当前血打到 0，伤害 dmg（state_value）
func _hit_to_zero(lg: XBattleLogic, u, sk: Dictionary, t: XEnemy, dmg: float) -> void:
	t.immortal = true
	XTianqiQiyinEffects.before_apply(lg, u, sk, t)
	t.hp = 0.0
	XTianqiQiyinEffects.after_apply(lg, u, sk, t, {"hp": dmg, "state_value": dmg})


## 西游档：不建七印数据，序列普攻照常
func _legacy() -> void:
	var lg := _logic(false)
	var u: XActor = lg.actors[0]
	_wear(u, _gear_set("hong", 5))
	XTianqiQiyinEffects.start(lg)
	var e: XEnemy = lg.enemies[0]
	_prep(lg, [e])
	lg.current_order.clear()
	lg.act(u, u.attack_skill(), e)
	_check("legacy_no_store", not lg.has_meta("xqiyin") and e.is_dead() and lg.current_order.is_empty())
	lg.end_battle(0)


## 斩获：穿一件带斩获的防具（同 xiyou_tianqi_affix_battle 的夹具）
func _wear_harvest(a: XActor) -> void:
	a.keep_unequippable = true
	var inst := {"kind": "armor", "name": "测试", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 3, "tianqi_affixes": [{"key": "harvest", "tier": 4, "grade": "normal", "extra": {}}]}
	var slot := 1
	while a.equips.size() <= slot:
		a.equips.append(null)
	a.equips[slot] = inst
	a.param_mark_dirty()
	a.param_refresh()


func _harvest_probe(kind: String, skill_of: Callable, low_n: int, per_segment: bool) -> Dictionary:
	var lg := _logic()
	var u: XActor = lg.actors[0]
	_wear_harvest(u)
	XTianqiAffixBattle.start(lg)
	XTianqiQiyinEffects.start(lg)
	var sk: Dictionary = skill_of.call(u)
	var low := []
	for i in low_n:
		low.append(lg.enemies[i])
	_prep(lg, low)
	u.mp = 0.0
	var pct := float(XTianqiAffixBattle.view(u).get("p", {}).get("harvest", 0.0))
	if per_segment:
		XBattleStream.start(lg, u, sk, low[0]).finish()
	else:
		lg.act(u, sk, low[0])
	var row := {"kind": kind, "seq": XActionSequence.has_sequence(sk), "per_segment": per_segment, "pct": pct,
		"dead": low.filter(func(x): return x.is_dead()).size(), "mp": u.mp, "want": floorf(u.mmp * pct / 100.0)}
	lg.end_battle(0)
	return row


func _harvest() -> void:
	var rows := []
	var kinds := [["普攻", func(u): return u.attack_skill(), 1], ["序列群体招", func(_u): return _seq_skill(2), 2], ["单段招", func(_u): return _plain(1, 1), 1]]
	for on in [false, true]:
		XTianqiAffixBattle.SEQ_KILLS = on
		for k in kinds:
			var row := _harvest_probe(k[0], k[1], k[2], false)
			row.switch = on
			rows.append(row)
	XTianqiAffixBattle.SEQ_KILLS = true
	for k in kinds:
		var row := _harvest_probe(k[0], k[1], k[2], true)
		row.switch = true
		rows.append(row)
	# 两个开关各自单独关：只关七印的，斩获照认
	XTianqiQiyinEffects.SEQ_KILLS = false
	var solo := _harvest_probe("普攻", func(u): return u.attack_skill(), 1, false)
	solo.switch = true
	solo.qiyin_off = true
	rows.append(solo)
	XTianqiQiyinEffects.SEQ_KILLS = true
	print("AFFIX_HARVEST_TABLE ", JSON.stringify(rows))
	for row in rows:
		var tag := "harvest_%s_%s%s%s" % [row.kind, "on" if row.switch else "off", "_stream" if row.per_segment else "", "_qiyin_off" if row.has("qiyin_off") else ""]
		var ok_pct := float(row.pct) > 0.0 and float(row.want) > 0.0
		if row.switch or not row.seq:
			_check(tag, ok_pct and int(row.dead) >= 1 and is_equal_approx(float(row.mp), float(row.want)), row)  # 打倒多个也只回一次
		else:
			_check(tag + "_missed", ok_pct and int(row.dead) >= 1 and is_equal_approx(float(row.mp), 0.0), row)  # 回退：旧行为
	# 只关斩获的，七印照认
	XTianqiAffixBattle.SEQ_KILLS = false
	var q := _probe("普攻", _gear_set("hong", 5), func(u): return u.attack_skill(), 1, false)
	_check("qiyin_on_when_affix_off", bool(q.again) and int(q.kills) == 1, q)
	XTianqiAffixBattle.SEQ_KILLS = true
	# 序列里被救回：不回
	var lg := _logic()
	var u: XActor = lg.actors[0]
	_wear_harvest(u)
	XTianqiAffixBattle.start(lg)
	var sk := u.attack_skill()
	var e: XEnemy = lg.enemies[0]
	_prep(lg, [])
	u.mp = 0.0
	XTianqiAffixBattle.begin_action(lg, u, sk)
	XTianqiAffixBattle.before_apply(lg, u, sk, e)
	e.immortal = true
	e.hp = 0.0
	XTianqiAffixBattle.after_apply(lg, u, sk, e, {"hp": 30.0})
	e.immortal = false
	e.hp = 50.0
	XTianqiAffixBattle.end_action(lg, u, sk)
	_check("harvest_rescued_none", is_equal_approx(u.mp, 0.0), u.mp)
	# 同样时序、收尾真倒下：回一次
	XTianqiAffixBattle.begin_action(lg, u, sk)
	XTianqiAffixBattle.before_apply(lg, u, sk, e)
	e.immortal = true
	e.hp = 0.0
	XTianqiAffixBattle.after_apply(lg, u, sk, e, {"hp": 30.0})
	e.immortal = false
	lg._die(e)
	XTianqiAffixBattle.end_action(lg, u, sk)
	var pct := float(XTianqiAffixBattle.view(u).get("p", {}).get("harvest", 0.0))
	_check("harvest_confirmed_end", pct > 0.0 and is_equal_approx(u.mp, floorf(u.mmp * pct / 100.0)), [u.mp, u.mmp, pct])
	lg.end_battle(0)


## 技能重构 kill_grow／kill_tp（T232 R1，P1-1）：16 张卡全是动作序列招；各挑代表一个——
## 击杀成长：关羽 14「青龙乱舞」521（需 4526）；击杀回 TP：「射虎」2586（需 5119，+30）。开关开／关、逐段结算
func _skill_logic(extra: int) -> XBattleLogic:
	var w := _ids()
	var lineup := [extra, w[0], w[1], w[2], w[3]]
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
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


func _skill_probe(kind: String, actor_id: int, skill_id: int, need: int, per_segment: bool) -> Dictionary:
	var lg := _skill_logic(actor_id)
	var u: XActor = null
	for a in lg.actors:
		if int(a.actor_id) == actor_id:
			u = a
	if u == null:
		lg.end_battle(0)
		return {"kind": kind, "skip": "no_actor"}
	if not u.skill_ids.has(need):
		u.skill_ids.append(need)
	var sk: Dictionary = XDB.rec("Skills", skill_id).duplicate(true)
	sk.mpCost = 0
	sk.tpCost = 0
	_prep(lg, lg.enemies)  # 全部敌人 1 血：单体、群体、随机目标都打得倒
	u.tp = 0.0
	var g0 := XTianqiSkills.grow_count("guanyu")
	if per_segment:
		XBattleStream.start(lg, u, sk, lg.enemies[0]).finish()
	else:
		lg.act(u, sk, lg.enemies[0])
	var row := {"kind": kind, "seq": XActionSequence.has_sequence(sk), "per_segment": per_segment, "switch": XTianqiSkills.SEQ_KILLS,
		"dead": lg.enemies.filter(func(x): return x.is_dead()).size(), "grow": XTianqiSkills.grow_count("guanyu") - g0, "tp": u.tp,
		"spec": XTianqiSkills.spec(skill_id).has("kill_grow") or XTianqiSkills.spec(skill_id).has("kill_tp")}
	lg.end_battle(0)
	return row


func _skill_kills() -> void:
	var rows := []
	for on in [false, true]:
		XTianqiSkills.SEQ_KILLS = on
		rows.append(_skill_probe("击杀成长", 14, 521, 4526, false))
		rows.append(_skill_probe("击杀回TP", 14, 2586, 5119, false))
	XTianqiSkills.SEQ_KILLS = true
	rows.append(_skill_probe("击杀成长", 14, 521, 4526, true))
	rows.append(_skill_probe("击杀回TP", 14, 2586, 5119, true))
	print("SKILL_SEQ_KILL_TABLE ", JSON.stringify(rows))
	var tp_off := -1.0
	for r in rows:
		if r.has("skip"):
			_check("skill_probe_" + str(r.kind), false, r)
			continue
		var tag := "skill_%s_%s%s" % [r.kind, "on" if r.switch else "off", "_stream" if r.per_segment else ""]
		_check(tag + "_fixture", bool(r.seq) and bool(r.spec) and int(r.dead) >= 1, r)
		if r.kind == "击杀成长":
			_check(tag, (int(r.grow) >= 1) == bool(r.switch) and (r.switch or int(r.grow) == 0), r)
		elif not r.switch:
			tp_off = float(r.tp)
		else:
			_check(tag, tp_off >= 0.0 and is_equal_approx(float(r.tp) - tp_off, 30.0), [r, tp_off])
	# 序列里被救回：不算（直接调 begin_action／after_apply／end_action）
	var lg := _skill_logic(14)
	var u: XActor = lg.actors.filter(func(a): return int(a.actor_id) == 14)[0]
	if not u.skill_ids.has(5119):
		u.skill_ids.append(5119)
	var sk: Dictionary = XDB.rec("Skills", 2586)
	var e: XEnemy = lg.enemies[0]
	_prep(lg, [])
	u.tp = 0.0
	XTianqiSkills.begin_action(lg, u, sk)
	e.immortal = true
	e.hp = 0.0
	XTianqiSkills.after_apply(lg, u, sk, e, {"hp": 30.0})
	e.immortal = false
	e.hp = 50.0
	XTianqiSkills.end_action(lg, u, sk)
	_check("skill_tp_rescued_none", is_equal_approx(u.tp, 0.0), u.tp)
	lg.end_battle(0)


func _run() -> void:
	XTianqiQiyinEffects.ENABLED = true
	_measure()
	_carry_chain()
	_edges()
	_legacy()
	_harvest()
	_skill_kills()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
