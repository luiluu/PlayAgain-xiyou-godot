extends Node
## 【cc·T240·未经审查】追加出手打倒的敌人也算行动者的击倒（D223 乙；XTianqiQiyinEffects.FOLLOW_KILLS，O-待定）。
## 三类追加出手：词条再释放（XTianqiAffixBattle.end_action）、技能重构追加释放（XTianqiSkills._cast，序列与非序列两条路）、
## 七印派生（_derived：送行连斩等）。打倒的触发：击杀叠层（un.kills）、送行连斩、击倒再动、词条斩获（一次行动只一次）。
## 连锁上限：一次行动里追加击倒的结算最多 FOLLOW_KILL_MAX 轮（默认 3）；送行连斩去掉 chain（每轮只斩一刀）、全场 1 血构造连锁，断言停在上限。
## 补刀（队友出手）不记给行动者；开关关回到 T232 时的样子；西游档不建数据。
## R1（小A 核）：原样「送行」（chain 为真）自己连出来的击倒，结算里不再重开连斩（场上留高血目标，断言不白嫖）；
## 反伤反死、连命同步倒下的不算行动者的追加击倒；七印 ENABLED 关着时再释放打倒照样回斩获；词条 begin_action 清 last。
## 行动收尾按 battle_logic.act 的次序手动走（七印 end_action → 词条 end_action → 技能 end_action（只在追加释放场景里用 _cast 代替掷几率）→ followup_settle）。

const ARMOR_ID := 1
const WEAPON_ID := 1
const CHAIN_TROOP := 357  # 怨念之魂×8：连锁上限要 6 个以上敌人（主招 1＋主收尾连斩 1＋3 轮各 1＋剩 1 个站着）

var results: Array = []
var table: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids() -> Array:
	return XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _logic(tianqi := true, troop := 2) -> XBattleLogic:
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
	lg.setup(troop, s)
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



func _prep_all(lg: XBattleLogic, hp: float) -> void:
	for e in lg.enemies:
		e.recover_all()
		e.shield = 0.0
		e.immortal = false
		if hp > 0.0:
			e.hp = hp


## 防具一件上挂天启篇词条（挂在第 1 格七印防具上，或新开一格）
func _affix(a: XActor, affixes: Array) -> void:
	var inst = a.equips[1] if a.equips.size() > 1 and a.equips[1] is Dictionary and not a.equips[1].is_empty() else null
	if inst == null:
		inst = {"kind": "armor", "name": "测试", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 3}
		while a.equips.size() <= 1:
			a.equips.append(null)
		a.equips[1] = inst
	inst.tianqi_affixes = affixes
	a.param_mark_dirty()
	a.param_refresh()


func _x(key: String, tier := 4, grade := "normal") -> Dictionary:
	return {"key": key, "tier": tier, "grade": grade, "extra": {}}


func _setup(marks: Array, affixes: Array, troop := 2) -> Array:
	var lg := _logic(true, troop)
	var u: XActor = lg.actors[0]
	_wear(u, marks)
	if not affixes.is_empty():
		_affix(u, affixes)
	XTianqiAffixBattle.start(lg)
	XTianqiQiyinEffects.start(lg)
	_prep_all(lg, 0.0)
	lg.current_order.clear()
	u.mp = 0.0
	return [lg, u]


func _begin(lg, u, sk) -> void:
	XTianqiQiyinEffects.begin_action(lg, u, sk)
	XTianqiAffixBattle.begin_action(lg, u, sk)


func _row(lg, u, tag: String) -> Dictionary:
	var un: Dictionary = XTianqiQiyinEffects._unit(lg, u)
	var pct := float(XTianqiAffixBattle.view(u).get("p", {}).get("harvest", 0.0))
	var last: Dictionary = lg.get_meta(XTianqiQiyinEffects.FU_LAST_META) if lg.has_meta(XTianqiQiyinEffects.FU_LAST_META) else {}
	return {"tag": tag, "kills": int(un.kills), "again": lg.current_order.any(func(x): return is_same(x, u)),
		"mp": u.mp, "want": floorf(u.mmp * pct / 100.0), "rounds": int(last.get("rounds", -1)), "left": int(last.get("left", -1)), "chain_runs": int(last.get("chain_runs", -1)),
		"dead": lg.enemies.filter(func(e): return e.is_dead()).size(), "enemies": lg.enemies.size()}


## 一、词条再释放打倒：主招不倒，收尾前把目标压到 1 血，再释放（17 条完美再释放＝102% 必中）打倒
func _recast(on: bool) -> Dictionary:
	XTianqiQiyinEffects.FOLLOW_KILLS = on
	var rc := []
	for i in 17:
		rc.append(_x("recast", 4, "perfect"))
	rc.append(_x("harvest"))
	var lu := _setup(_gear_set("hong", 5), rc)
	var lg: XBattleLogic = lu[0]
	var u: XActor = lu[1]
	var sk := _seq_skill(1)
	var e: XEnemy = lg.enemies[0]
	_begin(lg, u, sk)
	e.hp = e.mhp
	lg.apply(u, sk, e)
	var main_alive := e.is_alive()
	e.hp = 1.0
	var logs := []
	logs.append_array(XTianqiQiyinEffects.end_action(lg, u, sk))
	logs.append_array(XTianqiAffixBattle.end_action(lg, u, sk))
	logs.append_array(XTianqiQiyinEffects.followup_settle(lg, u, sk))
	var row := _row(lg, u, "recast_" + ("on" if on else "off"))
	row.main_alive = main_alive
	row.recast_logs = logs.size()
	lg.end_battle(0)
	XTianqiQiyinEffects.FOLLOW_KILLS = true
	return row


## 二、技能追加释放打倒：走 XTianqiSkills._cast（序列招：序列里挂 IMMORTAL、跑完才倒；非序列招：当场倒）
func _follow_cast(on: bool, seq: bool) -> Dictionary:
	XTianqiQiyinEffects.FOLLOW_KILLS = on
	var lu := _setup(_gear_set("hong", 5), [_x("harvest")])
	var lg: XBattleLogic = lu[0]
	var u: XActor = lu[1]
	var sk := u.attack_skill()
	var e: XEnemy = lg.enemies[0]
	_begin(lg, u, sk)
	XTianqiQiyinEffects.end_action(lg, u, sk)
	XTianqiAffixBattle.end_action(lg, u, sk)
	e.hp = 1.0
	var cast := _seq_skill(1) if seq else _plain(1, 1)
	XTianqiSkills._cast(lg, u, cast, [e])
	XTianqiQiyinEffects.followup_settle(lg, u, sk)
	var row := _row(lg, u, "follow_%s_%s" % ["seq" if seq else "plain", "on" if on else "off"])
	row.cast_seq = XActionSequence.has_sequence(cast)
	lg.end_battle(0)
	XTianqiQiyinEffects.FOLLOW_KILLS = true
	return row


## 三、七印派生连锁＋上限：红印 5 件＋送行（chain 去掉：每轮只斩一刀，相当于 chain 为假的连斩；原样见 _raw_songxing），全场 1 血；
## 主招打倒 1 个 → 主收尾连斩打倒 1 个（记进窗口）→ 每轮结算再连斩 1 个……停在 cap 轮
func _chain(on: bool, cap: int) -> Dictionary:
	XTianqiQiyinEffects.FOLLOW_KILLS = on
	XTianqiQiyinEffects.FOLLOW_KILL_MAX = cap
	var lu := _setup(_gear_set("hong", 5) + [{"kind": "weapon", "seal": "hui", "key": "songxing"}], [_x("harvest")], CHAIN_TROOP)
	var lg: XBattleLogic = lu[0]
	var u: XActor = lu[1]
	var st: Dictionary = XTianqiQiyinEffects._store(lg)
	XTianqiQiyinEffects.effects(lg, u)
	var fx: Dictionary = st.fx[u].duplicate()
	var cs: Dictionary = fx.get("kill_chain_slash", {}).duplicate()
	var has_chain := not cs.is_empty()
	cs.chain = false
	fx.kill_chain_slash = cs
	st.fx[u] = fx
	_prep_all(lg, 1.0)
	var sk := u.attack_skill()
	var e: XEnemy = lg.enemies[0]
	_begin(lg, u, sk)
	lg.apply(u, sk, e)
	XTianqiQiyinEffects.end_action(lg, u, sk)
	XTianqiAffixBattle.end_action(lg, u, sk)
	XTianqiQiyinEffects.followup_settle(lg, u, sk)
	var row := _row(lg, u, "chain_%s_cap%d" % ["on" if on else "off", cap])
	row.has_chain = has_chain
	lg.end_battle(0)
	XTianqiQiyinEffects.FOLLOW_KILLS = true
	XTianqiQiyinEffects.FOLLOW_KILL_MAX = 3
	return row


## 四、补刀（队友出手）打倒的不记给行动者
func _budao() -> Dictionary:
	var lu := _setup(_gear_set("hong", 5), [])
	var lg: XBattleLogic = lu[0]
	var u: XActor = lu[1]
	var h: XActor = lg.actors[1]
	_wear(h, [{"kind": "weapon", "seal": "hui", "key": "budao"}])
	XTianqiQiyinEffects.start(lg)
	var sk := u.attack_skill()
	var e: XEnemy = lg.enemies[0]
	_begin(lg, u, sk)
	e.hp = e.mhp
	lg.apply(u, sk, e)
	e.hp = 1.0
	XTianqiQiyinEffects.end_action(lg, u, sk)
	XTianqiAffixBattle.end_action(lg, u, sk)
	XTianqiQiyinEffects.followup_settle(lg, u, sk)
	var row := _row(lg, u, "budao")
	row.has_budao = XTianqiQiyinEffects.effects(lg, h).has("ally_followup_execute")
	row.e_dead = e.is_dead()
	lg.end_battle(0)
	return row


## 五、西游档：不建数据，收尾结算什么都不做
func _legacy() -> void:
	var lg := _logic(false)
	var u: XActor = lg.actors[0]
	_wear(u, _gear_set("hong", 5))
	XTianqiQiyinEffects.start(lg)
	var e: XEnemy = lg.enemies[0]
	e.hp = 1.0
	lg.current_order.clear()
	lg.act(u, u.attack_skill(), e)
	_check("legacy_no_store", not lg.has_meta("xqiyin") and e.is_dead() and lg.current_order.is_empty())
	_check("legacy_settle_noop", XTianqiQiyinEffects.followup_settle(lg, u, u.attack_skill()).is_empty() and not lg.has_meta("xqiyin"))
	lg.end_battle(0)


## 六、整次行动（lg.act）：普攻打倒 1 血目标、送行（原样 chain）连斩，追加击倒有结算、轮数不超上限，窗口用完清掉
func _act_smoke() -> void:
	var lu := _setup(_gear_set("hong", 5) + [{"kind": "weapon", "seal": "hui", "key": "songxing"}], [_x("harvest")])
	var lg: XBattleLogic = lu[0]
	var u: XActor = lu[1]
	_prep_all(lg, 1.0)
	lg.act(u, u.attack_skill(), lg.enemies[0])
	var row := _row(lg, u, "act_smoke")
	var st: Dictionary = XTianqiQiyinEffects._store(lg)
	table.append(row)
	_check("act_smoke_settled", int(row.rounds) >= 1 and int(row.rounds) <= 3 and int(row.kills) == int(row.dead) - int(row.left) and int(row.chain_runs) == 0 and not lg.has_meta(XTianqiQiyinEffects.FU_META), row)
	lg.end_battle(0)


## 七、原样「送行」（chain 为真）：怨念之魂×8，E0 主招打倒，其余 1 血、只有 hi 那个满血；
## 连斩在 _chain_slash 里自己连（砍倒 1 血的就接着砍，砍到满血的停），结算轮不再重开连斩（chain_runs 0、结算日志里没有出手），
## 满血的那个只可能挨主收尾里的一刀
func _raw_songxing(hi: int) -> Dictionary:
	var lu := _setup(_gear_set("hong", 5) + [{"kind": "weapon", "seal": "hui", "key": "songxing"}], [_x("harvest")], CHAIN_TROOP)
	var lg: XBattleLogic = lu[0]
	var u: XActor = lu[1]
	var raw: Dictionary = XTianqiQiyinEffects.effects(lg, u).get("kill_chain_slash", {})
	_prep_all(lg, 1.0)
	var big: XEnemy = lg.enemies[hi]
	big.hp = big.mhp
	var sk := u.attack_skill()
	_begin(lg, u, sk)
	lg.apply(u, sk, lg.enemies[0])
	var l1 := XTianqiQiyinEffects.end_action(lg, u, sk)
	var big_after_main := big.hp
	XTianqiAffixBattle.end_action(lg, u, sk)
	var l2 := XTianqiQiyinEffects.followup_settle(lg, u, sk)
	var row := _row(lg, u, "raw_songxing_hi%d" % hi)
	row.raw_chain = bool(raw.get("chain", false))
	row.slashes_main = l1.filter(func(l): return l is Dictionary and l.get("type") == "action").size()
	row.slashes_settle = l2.filter(func(l): return l is Dictionary and l.get("type") == "action").size()
	row.big_alive = big.is_alive()
	row.big_untouched_by_settle = is_equal_approx(big.hp, big_after_main)
	lg.end_battle(0)
	return row


## 八、反伤反死、连命同步倒下：窗口里行动者这一击没把目标打到 0 的，之后被别的路子弄倒不算；只有挨了致命一击的那个算
func _not_mine() -> Dictionary:
	var lu := _setup(_gear_set("hong", 5), [])
	var lg: XBattleLogic = lu[0]
	var u: XActor = lu[1]
	var sk := u.attack_skill()
	var e0: XEnemy = lg.enemies[0]
	var e1: XEnemy = lg.enemies[1]
	var e2: XEnemy = lg.enemies[2]
	_begin(lg, u, sk)
	XTianqiQiyinEffects.end_action(lg, u, sk)
	XTianqiAffixBattle.end_action(lg, u, sk)
	var before := XTianqiQiyinEffects.fu_snap(lg, u)
	e0.hp = e0.mhp
	lg.apply(u, sk, e0)  # 挨打没死
	var e0_alive_after_hit := e0.is_alive()
	lg._die(e0)  # 反击时被反伤反死（出手者不是行动者）
	e1.hp = 1.0
	lg.apply(u, sk, e1)  # 致命一击
	lg._die(e2)  # 连命同步倒下（没挨这一击）
	XTianqiQiyinEffects.fu_note(lg, u, before)
	XTianqiQiyinEffects.followup_settle(lg, u, sk)
	var row := _row(lg, u, "not_mine")
	row.e0_alive_after_hit = e0_alive_after_hit
	row.e1_dead = e1.is_dead()
	lg.end_battle(0)
	return row


## 九、七印 ENABLED 关着：再释放打倒照样回词条斩获（窗口由词条 end_action 开）；词条 begin_action 清上一动的 last
func _qiyin_off_harvest() -> void:
	XTianqiQiyinEffects.ENABLED = false
	var rc := []
	for i in 17:
		rc.append(_x("recast", 4, "perfect"))
	rc.append(_x("harvest"))
	var lu := _setup(_gear_set("hong", 5), rc)
	var lg: XBattleLogic = lu[0]
	var u: XActor = lu[1]
	var sk := _seq_skill(1)
	var e: XEnemy = lg.enemies[0]
	_begin(lg, u, sk)
	e.hp = e.mhp
	lg.apply(u, sk, e)
	e.hp = 1.0
	XTianqiQiyinEffects.end_action(lg, u, sk)
	XTianqiAffixBattle.end_action(lg, u, sk)
	XTianqiQiyinEffects.followup_settle(lg, u, sk)
	var pct := float(XTianqiAffixBattle.view(u).get("p", {}).get("harvest", 0.0))
	var want := floorf(u.mmp * pct / 100.0)
	_check("qiyin_off_no_store", not lg.has_meta("xqiyin"))
	_check("qiyin_off_recast_harvest", e.is_dead() and want > 0.0 and is_equal_approx(u.mp, want), [e.is_dead(), u.mp, want])
	XTianqiAffixBattle.begin_action(lg, u, sk)
	_check("affix_begin_clears_last", (XTianqiAffixBattle._store(lg).get("last", {}) as Dictionary).is_empty())
	lg.end_battle(0)
	XTianqiQiyinEffects.ENABLED = true


func _run() -> void:
	XTianqiQiyinEffects.ENABLED = true
	var r_on := _recast(true)
	var r_off := _recast(false)
	table.append_array([r_on, r_off])
	_check("recast_fixture_main_not_kill", bool(r_on.main_alive) and bool(r_off.main_alive), [r_on, r_off])
	_check("recast_kill_counts_on", int(r_on.dead) == 1 and int(r_on.kills) == 1 and int(r_on.rounds) == 1, r_on)
	_check("recast_harvest_on", float(r_on.want) > 0.0 and is_equal_approx(float(r_on.mp), float(r_on.want)), r_on)
	_check("recast_off_old", int(r_off.dead) == 1 and int(r_off.kills) == 0 and is_equal_approx(float(r_off.mp), 0.0) and not bool(r_off.again), r_off)
	for seq in [true, false]:
		var on := _follow_cast(true, seq)
		var off := _follow_cast(false, seq)
		table.append_array([on, off])
		var t := "seq" if seq else "plain"
		_check("follow_fixture_%s" % t, bool(on.cast_seq) == seq, on)
		_check("follow_%s_on_kill_again_harvest" % t, int(on.dead) == 1 and int(on.kills) == 1 and bool(on.again) and float(on.want) > 0.0 and is_equal_approx(float(on.mp), float(on.want)), on)
		_check("follow_%s_off_old" % t, int(off.dead) == 1 and int(off.kills) == 0 and not bool(off.again) and is_equal_approx(float(off.mp), 0.0), off)
	var c3 := _chain(true, 3)
	var c1 := _chain(true, 1)
	var c0 := _chain(false, 3)
	table.append_array([c3, c1, c0])
	_check("chain_fixture", bool(c3.has_chain) and int(c3.enemies) >= 6, c3)
	# 主招 1＋主收尾连斩 1＋每轮再斩 1：cap 轮后还剩 1 个没结算的击倒；叠层＝主招 1＋每轮 1
	_check("chain_cap3_stops", int(c3.rounds) == 3 and int(c3.left) == 1 and int(c3.dead) == 5 and int(c3.kills) == 4 and int(c3.dead) < int(c3.enemies), c3)
	_check("chain_cap1_stops", int(c1.rounds) == 1 and int(c1.left) == 1 and int(c1.dead) == 3 and int(c1.kills) == 2, c1)
	_check("chain_cap_harvest_once", is_equal_approx(float(c3.mp), float(c3.want)) and float(c3.want) > 0.0, c3)
	_check("chain_off_old", int(c0.rounds) == -1 and int(c0.dead) == 2 and int(c0.kills) == 1, c0)
	var b := _budao()
	table.append(b)
	_check("budao_not_actor_kill", bool(b.has_budao) and bool(b.e_dead) and int(b.kills) == 0 and int(b.rounds) == 0, b)
	_legacy()
	_act_smoke()
	var picked_low := false
	for hi in [7, 3]:
		var r := _raw_songxing(hi)
		table.append(r)
		var chained := int(r.dead) - 1  # 主收尾连斩砍倒的 1 血敌人
		picked_low = picked_low or chained > 0
		_check("raw_songxing_chain_true_hi%d" % hi, bool(r.raw_chain), r)
		_check("raw_songxing_no_resettle_hi%d" % hi, int(r.chain_runs) == 0 and int(r.slashes_settle) == 0 and bool(r.big_untouched_by_settle) and bool(r.big_alive) and int(r.dead) < int(r.enemies), r)
		# 主收尾里：每砍倒一个 1 血的就接着砍，砍到满血的那一刀停：刀数＝连斩砍倒数＋1。叠层＝倒下数（主招 1＋连斩砍倒的，结算轮照数）
		_check("raw_songxing_slashes_hi%d" % hi, int(r.slashes_main) == chained + 1 and int(r.kills) == int(r.dead) and int(r.rounds) == (1 if chained > 0 else 0), r)
	_check("raw_songxing_covers_chained_kill", picked_low)
	var nm := _not_mine()
	table.append(nm)
	_check("not_mine_reflect_linked", bool(nm.e0_alive_after_hit) and bool(nm.e1_dead) and int(nm.dead) == 3 and int(nm.kills) == 1 and int(nm.rounds) == 1, nm)
	_qiyin_off_harvest()
	print("FOLLOW_KILL_TABLE ", JSON.stringify(table.map(func(r): return r)))
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
