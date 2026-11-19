extends Node
## 天启篇弱者专属词条批 2 前四人（T230：31 露茜「催花」、23 魔雷老人「蓄雷」、103 波风水门「黄色闪光」、3 艾坤「一坤年之威」）专项。
## 设计稿 v0.3 第四节＋v0.3.1 第三节；张三丰、布兰德瓦登归批 2B。

var results: Array = []
const LUCY := 31
const MOLEI := 23
const MINATO := 103
const AIKUN := 3


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	seed(20261119)
	_lucy()
	_molei()
	_minato()
	_aikun()
	_badges_view()
	_xiyou_save()
	_qiyin_seq_probe()
	XTianqiWeakAffix.test_entries.clear()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		print(("PASS " if r.passed else "FAIL "), r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 夹具 ----

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


func _logic(lineup: Array) -> XBattleLogic:
	var s := _state(lineup)
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	for a in lg.actors:
		a.change_level(99)
		a.param_refresh()
	for e in lg.enemies:
		e.add_param(0, 1e12)
		e.hp = e.mhp
	return lg


func _on(key: String) -> void:
	var e: Dictionary = XTianqiWeakAffix.data().get("entries", {}).get(key, {}).duplicate(true)
	e.enabled = true
	XTianqiWeakAffix.test_entries[key] = e


func _off(key: String) -> void:
	XTianqiWeakAffix.test_entries.erase(key)


func _exclusive(a: XActor, key: String, slot := 0) -> void:
	a.keep_unequippable = true
	while a.equips.size() <= slot:
		a.equips.append(null)
	var base = a.equips[slot] if a.equips[slot] is Dictionary else {"kind": "weapon", "base": 1, "etypeId": 1, "name": "测试兵器", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "wtypeId": 1}
	var inst: Dictionary = base.duplicate(true)
	if key == "":
		inst.erase(XTianqiWeakAffix.ITEM_KEY)
	else:
		inst[XTianqiWeakAffix.ITEM_KEY] = {"key": key}
	a.equips[slot] = inst
	a.param_mark_dirty()
	a.param_refresh()


func _learn(a: XActor, ids: Array) -> void:
	for id in ids:
		if not a.skill_ids.has(int(id)):
			a.learn_skill(int(id))
	a.param_mark_dirty()
	a.param_refresh()


func _fresh(lg: XBattleLogic) -> void:
	for b in lg.actors + lg.enemies:
		if b.is_state_affected(1):
			b.remove_state(1)
		b.hp = b.mhp
	for a in lg.actors:
		a.mp = a.mmp
		a.tp = 100


## 自然回合边界（不跑整套回合流程，只推进回合号、清每回合次数）
func _next_turn(lg: XBattleLogic) -> void:
	XTianqiWeakAffix.turn_end(lg)
	lg.turn += 1
	XTianqiWeakAffix.turn_begin(lg)


## 出手前把敌人救满（等级 99 打低级敌人，两根就全倒、战斗结束 act 就不跑了）；keep 里的人不动（要看他被打倒的）
func _act(lg: XBattleLogic, u, id: int, t = null, keep := []) -> Array:
	_fresh_mp(u)
	for e in lg.enemies:
		if keep.has(e):
			continue
		if e.is_state_affected(1):
			e.remove_state(1)
		e.hidden = false
		e.hp = e.mhp
	return lg.act(u, XDB.rec("Skills", id), t)


func _fresh_mp(u) -> void:
	if u is XActor:
		u.mp = u.mmp
		u.tp = 100


func _actions(logs: Array, u, id: int) -> int:
	return logs.filter(func(l): return l is Dictionary and l.get("type") == "action" and is_same(l.get("user"), u) and int(l.get("skill", {}).get("id", 0)) == id).size()


func _hits(logs: Array, u, t) -> int:
	return logs.filter(func(l): return l is Dictionary and l.get("type") == "hit" and is_same(l.get("user"), u) and is_same(l.get("target"), t) and not l.get("counter", false)).size()


func _texts(logs: Array) -> Array:
	return logs.filter(func(l): return l is Dictionary and l.get("type") == "battle_text").map(func(l): return str(l.text))


func _has_text(logs: Array, part: String) -> bool:
	return _texts(logs).any(func(x): return x.contains(part))


## 天启篇通用词条挂身上（同 xiyou_tianqi_affix_battle 的 _wear；空表＝摘掉）
func _wear_affix(a: XActor, affixes: Array) -> void:
	a.keep_unequippable = true
	while a.equips.size() <= 1:
		a.equips.append(null)
	a.equips[1] = {"kind": "armor", "name": "测试", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 3, "tianqi_affixes": affixes} if not affixes.is_empty() else null
	a.param_mark_dirty()
	a.param_refresh()


## 露茜结清直接调（不走整套行动）：目标挂她上的 55（3 回合），开新回合、开主动根，settle 后收尾拿日志
func _lucy_direct(lg: XBattleLogic, lucy: XActor, t: XActor, before := Callable()) -> Dictionary:
	if not t.state_ids.has(55):
		t.add_state(55)
	t.state_turns[55] = 3
	XTianqiWeakAffix._store(lg).regen_src[t] = lucy
	_next_turn(lg)
	var sk := XDB.rec("Skills", 623)
	XTianqiWeakAffix.root_begin(lg, lucy, sk)
	if before.is_valid():
		before.call()
	var r := {"skill": sk, "removed": []}
	var ok := XTianqiWeakB2.settle(lg, lucy, t, 55, r)
	var logs := XTianqiWeakAffix.root_end(lg)
	return {"ok": ok, "r": r, "logs": logs}


# ---- 31 露茜「催花」 ----
func _lucy() -> void:
	var lg := _logic([LUCY, 1, 2])
	var lucy: XActor = lg.state.actor(LUCY)
	var ally: XActor = lg.state.actor(1)
	var other: XActor = lg.state.actor(2)
	_learn(lucy, [623])
	_on("w31")
	_exclusive(lucy, "w31")
	_fresh(lg)
	var logs := _act(lg, lucy, 623)
	_check("lucy_first_cast_gives_regen", ally.state_ids.has(55) and is_same(XTianqiWeakB2.regen_src(lg, ally), lucy), [ally.state_ids])
	# ①② 结清：旧的剩余回合一次回完、旧状态移除、这一次不拿新的
	ally.hp = 1.0
	var left := int(ally.state_turns.get(55, 0))
	var want := floorf(ally.mhp * XTianqiWeakB2.tick_rate(55) * left * ally.rec)
	logs = _act(lg, lucy, 623)
	var line := _texts(logs).filter(func(x): return x.contains("催花"))
	_check("lucy_settle_removes_old", not ally.state_ids.has(55) and left > 0, [left, ally.state_ids])
	_check("lucy_settle_amount", line.size() >= 1 and line.any(func(x): return x.contains("回复 %d）" % int(want))) and ally.hp >= 1.0 + want, [want, line, ally.hp])
	_check("lucy_settle_log_once_per_target", line.filter(func(x): return x.contains(ally.display_name())).size() == 1, line)
	# ③ 同回合再放：目标身上又挂上她的新持续回复（上一放没给，这一放原生给），再放一次照原生刷新、不结清
	logs = _act(lg, lucy, 623)
	var had := ally.state_ids.has(55)
	logs = _act(lg, lucy, 623)
	_check("lucy_same_turn_second_refreshes", had and ally.state_ids.has(55) and not _texts(logs).any(func(x): return x.contains("催花") and x.contains(ally.display_name())), _texts(logs))
	# ⑥ 别人上的同名状态不结清
	_next_turn(lg)
	XTianqiWeakAffix._store(lg).regen_src[ally] = other
	logs = _act(lg, lucy, 623)
	_check("lucy_other_source_untouched", ally.state_ids.has(55) and not _texts(logs).any(func(x): return x.contains("催花") and x.contains(ally.display_name())))
	# ④ 受治疗修正只过一次：挂坏死（受到的治疗 −30%）后结清量 ×0.7
	_next_turn(lg)
	XTianqiWeakAffix._store(lg).regen_src[ally] = lucy
	ally.add_state(10806)
	ally.param_refresh()
	ally.hp = 1.0
	left = int(ally.state_turns.get(55, 0))
	var want_rec := floorf(ally.mhp * XTianqiWeakB2.tick_rate(55) * left * ally.rec)
	logs = _act(lg, lucy, 623)
	_check("lucy_heal_rate_once", ally.rec < 1.0 and _texts(logs).any(func(x): return x.contains("回复 %d）" % int(want_rec))), [ally.rec, want_rec, _texts(logs)])
	ally.remove_state(10806)
	# ⑤ 满血结清：全部浪费，不超过上限
	_next_turn(lg)
	_act(lg, lucy, 623)  # 无 55 的人拿到新的
	_next_turn(lg)
	ally.hp = ally.mhp
	logs = _act(lg, lucy, 623)
	_check("lucy_full_hp_wasted", ally.hp <= ally.mhp and _has_text(logs, "催花"))
	# R1 P1-1：结清不写这一根的 r.hp／record_hp、不盖结果槽弹字 → 回春不把溢出转盾
	_wear_affix(lucy, [{"key": "rejuvenate", "tier": 4, "grade": "normal", "extra": {}}])
	ally.hp = ally.mhp
	ally.shield = 0.0
	var sk623 := XDB.rec("Skills", 623)
	var d := _lucy_direct(lg, lucy, ally, func():
		XTianqiAffixBattle.begin_action(lg, lucy, sk623)
		XTianqiAffixBattle.before_apply(lg, lucy, sk623, ally)
		lg._action_resources = lg._new_lifecycle_resources()  # 当作在这一根的行动里（结果槽里是 10% 即时治疗的弹字）
		lg._action_resources.result(ally).hpDamage = -123.0)
	var slot_hp := float(lg._action_resources.result(ally).hpDamage)
	lg._action_resources = null
	XTianqiAffixBattle.after_apply(lg, lucy, sk623, ally, d.r)
	XTianqiAffixBattle.end_action(lg, lucy, sk623)
	_check("lucy_settle_no_rejuvenate_shield", d.ok and ally.shield == 0.0 and float(d.r.get("hp", 0.0)) == 0.0 and not d.r.has("record_hp") and slot_hp == -123.0, [d.ok, ally.shield, d.r.get("hp"), slot_hp])
	_check("lucy_settle_full_hp_logs_zero", _texts(d.logs).any(func(x): return x.contains("回复 0）")), _texts(d.logs))
	_wear_affix(lucy, [])
	# R1 P1-1：四骑士疫病（受到的治疗 −50%）只减一次，日志报实际回复
	lg.set_meta(XTianqiHorsemen.META, {"line": "plague", "mode": "body", "knight": lg.enemies[0], "hit_knight": {}, "queue": [], "shield_open": false, "broken_turn": -1, "marks": {ally: {"plague": true}}})
	ally.hp = 1.0
	var hp0 := ally.hp
	d = _lucy_direct(lg, lucy, ally)
	var full_v := floorf(ally.mhp * XTianqiWeakB2.tick_rate(55) * 3 * ally.rec)
	var want_pl := floorf(full_v * (1.0 - float(XTianqiHorsemen.knight("plague").plague.heal_down)))
	lg.remove_meta(XTianqiHorsemen.META)
	_check("lucy_settle_plague_halved_once", d.ok and want_pl > 0.0 and want_pl < full_v and int(ally.hp - hp0) == int(want_pl) and _texts(d.logs).any(func(x): return x.contains("回复 %d）" % int(want_pl))), [want_pl, full_v, ally.hp - hp0, _texts(d.logs)])
	# R1 P1-1：只在 gain 里的修正（宿傩裂伤，天启篇 −30%）也算，日志＝实际回复
	ally.add_state(XSukuna.WOUND)
	ally.hp = 1.0
	hp0 = ally.hp
	d = _lucy_direct(lg, lucy, ally)
	ally.remove_state(XSukuna.WOUND)
	var got := int(ally.hp - hp0)
	_check("lucy_settle_gain_mods_logged", d.ok and got > 0 and got < int(full_v) and _texts(d.logs).any(func(x): return x.contains("回复 %d）" % got)), [got, full_v, _texts(d.logs)])
	# R1 P3-1：不在主动根里（词条再释放、追加、派生）不结清
	ally.add_state(55)
	ally.state_turns[55] = 3
	XTianqiWeakAffix._store(lg).regen_src[ally] = lucy
	_next_turn(lg)
	_check("lucy_settle_root_only", not XTianqiWeakB2.settle(lg, lucy, ally, 55, {"skill": sk623, "removed": []}) and ally.state_ids.has(55))
	# 开关关：照原生刷新
	_next_turn(lg)
	_act(lg, lucy, 623)
	_next_turn(lg)
	_off("w31")
	logs = _act(lg, lucy, 623)
	_check("lucy_switch_off_native", ally.state_ids.has(55) and not _has_text(logs, "催花"))
	# 别人戴：不生效
	_on("w31")
	_exclusive(lucy, "")
	_exclusive(other, "w31")
	_next_turn(lg)
	logs = _act(lg, lucy, 623)
	_check("lucy_not_owner_native", ally.state_ids.has(55) and not _has_text(logs, "催花"))
	lg.end_battle(0)


# ---- 23 魔雷老人「蓄雷」 ----
func _molei() -> void:
	var lg := _logic([MOLEI, 1, 2])
	var m: XActor = lg.state.actor(MOLEI)
	_learn(m, [5083, 327])
	_on("w23")
	_exclusive(m, "w23")
	var e0: XEnemy = lg.enemies[0]
	# ⑥ 四档满格数与伤害百分比（p×满格数）
	var tiers := []
	for p in [0.3, 0.4, 0.5, 0.6]:
		tiers.append([XTianqiWeakB2.thunder_full(p), roundi(p * 100.0) * XTianqiWeakB2.thunder_full(p)])
	_check("molei_tiers", tiers == [[3, 90], [3, 120], [2, 100], [2, 120]], tiers)
	# ① 原生几率不掷：把五雷几率拨到 1，戴着时第一根也不出五雷
	var sp: Dictionary = XTianqiSkills._skills[327]
	var keep = sp.follow
	var rows: Array = keep.duplicate(true)
	_fresh(lg)
	var turns := []
	var falls := []
	for i in range(4):
		var logs := _act(lg, m, 327, e0)
		turns.append(_texts(logs))
		falls.append(_actions(logs, m, 533))
		if i == 2:
			var at := logs.filter(func(l): return l is Dictionary and l.get("type") == "action" and int(l.get("skill", {}).get("id", 0)) == 533)
			_check("molei_fall_hits_main", not at.is_empty() and _hits(logs.slice(logs.find(at[0])), m, e0) == 5, _texts(logs))
		_next_turn(lg)
	# ② 基础 30% 档：第 3 根落，③ 落雷那根不计格（第 4 根是 1/3）
	_check("molei_third_root_falls", falls == [0, 0, 1, 0], [falls, turns])
	_check("molei_fall_root_no_gauge", int(XTianqiWeakAffix.stock(lg, m, "w23").get("n", -1)) == 1 and turns[0].has("蓄雷 1/3") and turns[3].has("蓄雷 1/3"), turns)
	# ④ 一回合两次都满格：只落 1 次，满格留到下回合第一根落、那一根不加格
	XTianqiWeakAffix.stock(lg, m, "w23").n = 2
	var a1 := _act(lg, m, 327, e0)
	var c1 := _actions(a1, m, 533)
	XTianqiWeakAffix.stock(lg, m, "w23").n = 2
	var a2 := _act(lg, m, 327, e0)
	var c2 := _actions(a2, m, 533)
	var kept := int(XTianqiWeakAffix.stock(lg, m, "w23").get("n", 0))
	_next_turn(lg)
	var a3 := _act(lg, m, 327, e0)
	_check("molei_one_fall_per_turn", c1 == 1 and c2 == 0 and kept == 3 and _actions(a3, m, 533) == 1 and int(XTianqiWeakAffix.stock(lg, m, "w23").get("n", 0)) == 0, [c1, c2, kept, _texts(a3)])
	# ⑤ 防御不蓄格
	_next_turn(lg)
	var g0 := int(XTianqiWeakAffix.stock(lg, m, "w23").get("n", 0))
	lg.act(m, XDB.rec("Skills", 2), null)
	_check("molei_guard_no_gauge", int(XTianqiWeakAffix.stock(lg, m, "w23").get("n", 0)) == g0)
	# ⑦ 主目标已倒：不落、格数保留（直接调 thunder，主目标设成倒下）
	var cands := XTianqiSkills._follow_of(m, XDB.rec("Skills", 327))
	XTianqiWeakAffix.stock(lg, m, "w23").n = 2
	XTianqiWeakAffix.root_begin(lg, m, XDB.rec("Skills", 327))
	XTianqiWeakAffix._frame(lg).main = e0
	e0.hp = 0.0
	e0.add_state(1)
	var wb := XTianqiWeakB2.thunder(lg, m, cands, false)
	_check("molei_dead_target_keeps", (wb.fall as Array).is_empty() and int(XTianqiWeakAffix.stock(lg, m, "w23").get("n", 0)) == 3, [wb.logs])
	XTianqiWeakAffix.root_end(lg)
	_fresh(lg)
	# 落雷伤害按百分比：直接比 follow_scale 下 formula
	_check("molei_fall_pct_carried", (func():
		XTianqiWeakAffix.stock(lg, m, "w23").n = 2
		XTianqiWeakAffix.root_begin(lg, m, XDB.rec("Skills", 327))
		XTianqiWeakAffix._frame(lg).main = e0
		var w := XTianqiWeakB2.thunder(lg, m, cands, false)
		XTianqiWeakAffix.root_end(lg)
		return not (w.fall as Array).is_empty() and int(w.fall[1]) == 90 and is_same(w.fall[2], e0)).call())
	# 开关关：原生照掷（几率拨到 1 时第一根就出五雷）
	_off("w23")
	_next_turn(lg)
	for r in sp.follow:
		r.rate = 1.0
		r.erase("rate_with")
	var nat := _act(lg, m, 327, e0)
	sp.follow = keep
	_check("molei_switch_off_native", _actions(nat, m, 533) == 1, _texts(nat))
	# 戴着、几率拨到 1：第一根不出（原生几率不再掷），只蓄格
	_on("w23")
	_next_turn(lg)
	XTianqiWeakAffix.stock(lg, m, "w23").n = 0
	sp.follow = rows.duplicate(true)
	for r in sp.follow:
		r.rate = 1.0
		r.erase("rate_with")
	var on1 := _act(lg, m, 327, e0)
	sp.follow = keep
	_check("molei_native_roll_gone", _actions(on1, m, 533) == 0 and int(XTianqiWeakAffix.stock(lg, m, "w23").get("n", 0)) == 1, _texts(on1))
	lg.end_battle(0)


# ---- 103 波风水门「黄色闪光」 ----
func _minato() -> void:
	var lg := _logic([MINATO, 1, 2])
	var u: XActor = lg.state.actor(MINATO)
	_learn(u, [7089])
	var e0: XEnemy = lg.enemies[0]
	var base := XTianqiSkills.formula(u, e0, XDB.rec("Skills", 7089))
	XTianqiWeakAffix.cut = {"user": u, "skill": 7089, "pct": 70}
	var cut := XTianqiSkills.formula(u, e0, XDB.rec("Skills", 7089))
	XTianqiWeakAffix.cut = {}
	_check("minato_cut_70pct", base > 0.0 and absf(cut - base * 0.7) <= maxf(1.0, base * 1e-6), [base, cut])
	_on("w103")
	_exclusive(u, "w103")
	_fresh(lg)
	var foes: Array = lg.alive(lg.enemies)
	var others: Array = lg.actors.filter(func(a): return not is_same(a, u))
	# 排一张已知的顺序表：本回合、下回合
	lg.current_order = [others[0]] + foes + [others[1]]
	lg.next_order = foes + others + [u]
	var cur_before := lg.current_order.duplicate()
	var nxt_before := lg.next_order.duplicate()
	var logs := _act(lg, u, 7089)
	_check("minato_first_cast_marked", XTianqiWeakAffix.turn_count(lg, u, "w103") == 1 and XTianqiWeakAffix.cut.is_empty(), XTianqiWeakAffix.cut)
	_check("minato_current_order_same", lg.current_order == cur_before, [lg.current_order.size(), cur_before.size()])
	var moved := foes.filter(func(e): return lg.next_order.find(e) > nxt_before.find(e))
	_check("minato_next_order_pushed", moved.size() == foes.size(), [foes.map(func(e): return [nxt_before.find(e), lg.next_order.find(e)])])
	var st_ok := foes.all(func(e): return e.state_ids.has(10830) and int(e.state_turns.get(10830, 0)) == 2)
	_check("minato_slow_state", st_ok, foes.map(func(e): return [e.state_ids.has(10830), e.state_turns.get(10830)]))
	_check("minato_log", _has_text(logs, "名敌人下回合行动后推 1 格"), _texts(logs))
	# R1 P2-3：刻印的类型、右下小字（去掉底号 26 冰冷的残留）
	var mk := XDB.rec("States", 10830)
	_check("minato_mark_note", str(mk.get("meta", {}).get("BuffType", "")) == "减益" and str(mk.get("note", "")).contains("被飞雷神刻印标记，身形变慢。") and not str(mk.get("note", "")).contains("好冷") and not str(mk.get("note", "")).contains("冰冷"), mk.get("note"))
	# ⑥ 同回合第二次：全额、不推
	var nxt2 := lg.next_order.duplicate()
	logs = _act(lg, u, 7089)
	_check("minato_second_cast_plain", lg.next_order == nxt2 and not _has_text(logs, "黄色闪光") and XTianqiWeakAffix.turn_count(lg, u, "w103") == 1)
	# 伤害：第一次这一根里 dmg_pct 是 70（root_skill 之后、root_end 之前），第二次 100
	_next_turn(lg)
	XTianqiWeakAffix.root_begin(lg, u, XDB.rec("Skills", 7089))
	XTianqiWeakAffix.root_skill(lg, XDB.rec("Skills", 7089))
	var p1 := XTianqiWeakAffix.dmg_pct(u, 7089)
	XTianqiWeakAffix.root_end(lg)
	XTianqiWeakAffix.root_begin(lg, u, XDB.rec("Skills", 7089))
	XTianqiWeakAffix.root_skill(lg, XDB.rec("Skills", 7089))
	var p2 := XTianqiWeakAffix.dmg_pct(u, 7089)
	XTianqiWeakAffix.root_end(lg)
	_check("minato_pct_first_only", p1 == 70 and p2 == 100, [p1, p2])
	# ⑤ 首领：刻印 1 回合（普通减益向上取半）
	_next_turn(lg)
	for e in foes:
		e.remove_state(10830)
	e0.boss_difficulty_boss = true
	_act(lg, u, 7089)
	_check("minato_boss_one_turn", int(e0.state_turns.get(10830, 0)) == 1, e0.state_turns.get(10830))
	e0.boss_difficulty_boss = false
	# ⑦ 连用：每回合只推 1 格（下回合顺序表每回合重排，这里看「每敌每回合 1 次」的次数）
	_check("minato_push_once_per_turn", XTianqiWeakAffix.turn_count(lg, e0, "w103_push") == 1)
	# R1 P2-2：刻印没挂上（目标隐身＝挂不上）就不写回合
	_next_turn(lg)
	e0.remove_state(10830)
	e0.state_turns.erase(10830)
	XTianqiWeakAffix.root_begin(lg, u, XDB.rec("Skills", 7089))
	XTianqiWeakAffix.root_skill(lg, XDB.rec("Skills", 7089))
	XTianqiWeakAffix._frame(lg).hits.append({"user": u, "target": e0, "hp": 1.0})
	e0.hidden = true
	XTianqiWeakAffix.root_end(lg)
	e0.hidden = false
	_check("minato_resisted_no_turns", not e0.state_ids.has(10830) and not e0.state_turns.has(10830), [e0.state_ids.has(10830), e0.state_turns.get(10830)])
	# 开关关：不扣、不推
	_off("w103")
	_next_turn(lg)
	var nx := lg.next_order.duplicate()
	logs = _act(lg, u, 7089)
	_check("minato_switch_off_native", lg.next_order == nx and not _has_text(logs, "黄色闪光"))
	lg.end_battle(0)


# ---- 3 艾坤「一坤年之威」 ----
func _aikun() -> void:
	var lg := _logic([AIKUN, 1, 2])
	var k: XActor = lg.state.actor(AIKUN)
	var mate: XActor = lg.state.actor(1)
	var mate2: XActor = lg.state.actor(2)
	_learn(k, [506])
	for x in [mate, mate2]:
		x.change_level(1)  # 队友普攻别一下打死主目标（要看传球打它）
		x.param_refresh()
	_on("w3")
	_exclusive(k, "w3")
	var e0: XEnemy = lg.enemies[0]
	var e1: XEnemy = lg.enemies[1] if lg.enemies.size() > 1 else e0
	# ① 没学篮球之神：不入库
	_fresh(lg)
	var logs := _act(lg, k, 506, e0)
	_check("aikun_no_skill_no_stock", int(XTianqiWeakAffix.stock(lg, k, "w3").get("n", 0)) == 0 and _actions(logs, k, 4370) == 0)
	# ② 学了且必定（鲲稚啸天）：球来不结算、入库 3
	_learn(k, [1235, 3514])
	_next_turn(lg)
	logs = _act(lg, k, 506, e0)
	_check("aikun_intercept_stock3", _actions(logs, k, 4370) == 0 and int(XTianqiWeakAffix.stock(lg, k, "w3").get("n", 0)) == 3 and _has_text(logs, "球来蓄势"), _texts(logs))
	# ⑥ 艾坤自己出手不传
	_check("aikun_own_root_no_pass", not _has_text(logs, "传球！"))
	# ④ 队友出手命中：对主目标打一次传球（球来五段），库存 −1
	logs = _act(lg, mate, 1, e1)
	var pass_hits := _hits(logs, k, e1)
	_check("aikun_pass_on_mate_root", _has_text(logs, "艾坤传球！") and _actions(logs, k, 4370) == 1 and pass_hits >= 5 and int(XTianqiWeakAffix.stock(lg, k, "w3").get("n", 0)) == 2, [pass_hits, _texts(logs)])
	# R1 P1-2：多敌场上传球只打主目标（原序列 action effect: enemies 会打全体）
	var side := lg.enemies.filter(func(e): return not is_same(e, e1)).map(func(e): return _hits(logs, k, e))
	_check("aikun_pass_main_only", lg.enemies.size() >= 2 and side.all(func(n): return n == 0), [lg.enemies.size(), side, pass_hits])
	# ⑤ 同回合第二个队友：不打
	logs = _act(lg, mate2, 1, e1)
	_check("aikun_once_per_turn", not _has_text(logs, "传球！") and int(XTianqiWeakAffix.stock(lg, k, "w3").get("n", 0)) == 2)
	# ⑦ 主目标被队友这一根打倒：不打、不扣
	_next_turn(lg)
	e1.hp = 1.0
	logs = _act(lg, mate, 1, e1, [e1])
	_check("aikun_main_dead_no_pass", e1.is_dead() and not _has_text(logs, "传球！") and int(XTianqiWeakAffix.stock(lg, k, "w3").get("n", 0)) == 2, _texts(logs))
	# R1 P3-2：大灌篮打倒目标（场上另有敌人）：球来过不了检查，不入库
	_next_turn(lg)
	XTianqiWeakAffix.stock(lg, k, "w3").n = 0
	e0.hp = 1.0
	logs = _act(lg, k, 506, e0, [e0])
	_check("aikun_slam_kill_no_stock", e0.is_dead() and lg.alive(lg.enemies).size() >= 1 and int(XTianqiWeakAffix.stock(lg, k, "w3").get("n", 0)) == 0 and not _has_text(logs, "球来蓄势"), [e0.is_dead(), _texts(logs)])
	e0.remove_state(1)
	e0.hp = e0.mhp
	XTianqiWeakAffix.stock(lg, k, "w3").n = 2
	# 传球的伤害是球来 ×33%：formula 比
	var base := XTianqiSkills.formula(k, e0, XDB.rec("Skills", 4370))
	XTianqiSkills.follow_scale = 0.33
	var part := XTianqiSkills.formula(k, e0, XDB.rec("Skills", 4370))
	XTianqiSkills.follow_scale = 1.0
	_check("aikun_pass_33pct", base > 0.0 and absf(part - base * 0.33) <= maxf(1.0, base * 1e-6), [base, part])
	# ③ 库存 1 时再入库：补到 3 不是 4
	_next_turn(lg)
	XTianqiWeakAffix.stock(lg, k, "w3").n = 1
	logs = _act(lg, k, 506, e0)
	_check("aikun_refill_to_cap", int(XTianqiWeakAffix.stock(lg, k, "w3").get("n", 0)) == 3, _texts(logs))
	# 打混子：传球是专属派生，盾照扣，不记艾坤「打过混子」
	_next_turn(lg)
	var f := {"line": "plague", "mode": "body", "knight": e0, "hit_knight": {}, "queue": [], "shield_open": false, "broken_turn": -1}
	lg.set_meta(XTianqiHorsemen.META, f)
	if XTianqiHorsemen.active(lg):
		XTianqiWeakAffix.root_begin(lg, mate, XDB.rec("Skills", 1))
		XTianqiWeakAffix._frame(lg).main = e0
		XTianqiWeakAffix._frame(lg).hits.append({"user": mate, "target": e0, "hp": 1.0})
		var plogs := XTianqiWeakAffix.root_end(lg)
		_check("aikun_pass_hunzi_no_mark", _has_text(plogs, "艾坤传球！") and not XTianqiHorsemen.fight(lg).hit_knight.has(k), XTianqiHorsemen.fight(lg).hit_knight.keys().map(func(x): return x.display_name()))
	else:
		_check("aikun_pass_hunzi_no_mark", false, "混子夹具没起来")
	lg.remove_meta(XTianqiHorsemen.META)
	# 开关关：球来照原生出
	_off("w3")
	_next_turn(lg)
	_fresh(lg)
	logs = _act(lg, k, 506, e0)
	_check("aikun_switch_off_native", _actions(logs, k, 4370) == 1, _texts(logs))
	_on("w3")
	# 换装清库存
	XTianqiWeakAffix.stock(lg, k, "w3").n = 2
	_exclusive(k, "")
	XTianqiWeakAffix.root_begin(lg, mate, XDB.rec("Skills", 1))  # 根与根之间对签名（地基：换装从零起）
	XTianqiWeakAffix.root_end(lg)
	_exclusive(k, "w3")
	_check("aikun_reequip_clears", int(XTianqiWeakAffix.stock(lg, k, "w3").get("n", 0)) == 0)
	lg.end_battle(0)


# ---- 角标：只写状态 ----
func _badges_view() -> void:
	var lg := _logic([MOLEI, AIKUN, 1])
	var m: XActor = lg.state.actor(MOLEI)
	var k: XActor = lg.state.actor(AIKUN)
	_on("w23")
	_on("w3")
	_exclusive(m, "w23")
	_exclusive(k, "w3")
	XTianqiWeakAffix.stock(lg, m, "w23").n = 2
	XTianqiWeakAffix.stock(lg, k, "w3").n = 2
	# R1 P2-1：没学天师真言术 5083 不挂
	if m.skill_ids.has(5083):
		m.forget_skill(5083)
	_check("badge_molei_needs_5083", not m.skill_ids.has(5083) and XTianqiWeakAffix.badges(lg, m).is_empty(), XTianqiWeakAffix.badges(lg, m))
	_learn(m, [5083])
	XTianqiWeakAffix.stock(lg, k, "w3").n = 2
	var bm := XTianqiWeakAffix.badges(lg, m)
	var bk := XTianqiWeakAffix.badges(lg, k)
	_check("badge_state_only", bm == ["蓄雷 2/3"] and bk == ["传球 ×2"], [bm, bk])
	var view := XTianqiWeakBadges.make(lg, func(): return {})
	_check("badge_node_built", view != null)
	if view != null:
		view.poll()
		_check("badge_node_reads", view.shown.get(m, "") == "蓄雷 2/3" and view.shown.get(k, "") == "传球 ×2", view.shown.values())
		view.free()
	# R1 P2-1：几率档位变了（学雷动九天 534 → 50%），满格数实时跟着变
	_learn(m, [534])
	_check("badge_molei_full_live", XTianqiWeakAffix.badges(lg, m) == ["蓄雷 2/2"], XTianqiWeakAffix.badges(lg, m))
	XTianqiWeakAffix.stock(lg, k, "w3").n = 0
	_check("badge_empty_stock_hidden", XTianqiWeakAffix.badges(lg, k).is_empty())
	_off("w23")
	_check("badge_switch_off", XTianqiWeakAffix.badges(lg, m).is_empty())
	_on("w23")
	# R1 P2-4：战斗结束（本场数据已清）后角标不显示、不重建本场数据
	lg.end_battle(0)
	var after_end := XTianqiWeakAffix.badges(lg, m)
	_check("badge_hidden_after_end", after_end.is_empty() and not lg.has_meta(XTianqiWeakAffix.META), [after_end, lg.has_meta(XTianqiWeakAffix.META)])
	_off("w23")


# ---- 西游档：条目开着、本人装着也不生效 ----
func _xiyou_save() -> void:
	_on("w3")
	var lg := _logic([AIKUN, 1, 2])
	var k: XActor = lg.state.actor(AIKUN)
	_learn(k, [506, 1235, 3514])
	_exclusive(k, "w3")
	var tq = lg.state.flags.get("tianqi")
	lg.state.flags.erase("tianqi")
	_check("xiyou_save_off", XTianqiWeakAffix.active_keys(lg, k).is_empty() and XTianqiWeakBadges.make(lg, func(): return {}) == null)
	lg.state.flags["tianqi"] = tq
	lg.end_battle(0)


# ---- 另查（派单附带，不算断言）：七印击倒类在动作序列招上认不认得到击倒 ----
## 魔雷老人群体魔雷术 327（动作序列招）、普攻 1（非序列）各打一个 1 血敌人，看七印行动帧 killed 记没记、目标此刻死没死。只打印 QIYIN_SEQ_KILL
func _qiyin_seq_probe() -> void:
	var rows := []
	for id in [327, 1]:
		var lg := _logic([MOLEI, 1, 2])
		var m: XActor = lg.state.actor(MOLEI)
		_learn(m, [327])
		_fresh_mp(m)
		XTianqiQiyinEffects._store(lg)  # 七印模块当作开着（只要本场数据在）
		var e0: XEnemy = lg.enemies[0]
		e0.hp = 1.0
		var sk := XDB.rec("Skills", id)
		var seq := XActionSequence.has_sequence(sk)
		lg.execute(m, sk, e0)
		var act: Dictionary = XTianqiQiyinEffects._store(lg).get("act", {})
		rows.append({"skill": id, "seq": seq, "dead_after_execute": e0.is_dead(), "immortal": e0.immortal, "killed_noted": (act.get("killed", []) as Array).has(e0), "frame_hits": act.get("hits", -1)})
		lg.end_battle(0)
	print("QIYIN_SEQ_KILL ", JSON.stringify(rows))
