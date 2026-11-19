extends Node
## 天启篇弱者专属词条批 2B（T231：42 布兰德瓦登「掷矛邀战」、86 张三丰「护犊」）专项。
## 设计稿 v0.3 第四节 42、86 ＋ v0.3.1 第二节第 2、3 条、第三节 42（整表替换）、86；协调 11-19：可引导只签 1 号普攻、扣 1162 的 30%、受邀只留最近一个、护犊要 GUARD 开着。

var results: Array = []
const BRAND := 42
const ZHANG := 86
const STUN := 29
const PHYS := 1153  # 物理单体（敌人放；不在可引导名单里）
const AOE := 636  # 物理全体「攻击」
const CNT_TXT := " 反击 "  # 「掷矛邀战：他 反击 甲！」（受邀那行没有这几个字）
const BARRIER := 92  # 屏障术：反击率＋100%（叠加别的反击来源）


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	seed(20261119)
	_table()
	_brand()
	_brand_off()
	_zhang()
	_zhang_off()
	_xiyou_save()
	XTianqiWeakAffix.test_entries.clear()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		print(("PASS " if r.passed else "FAIL "), r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 夹具（同 xiyou_tianqi_weak_b2） ----

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
		a.add_param(0, 1e12)
		a.param_refresh()
	for e in lg.enemies:
		e.add_param(0, 1e12)
	_fresh(lg)
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
		if b is XEnemy:
			b.hidden = false
		b.hp = b.mhp
	for a in lg.actors:
		a.mp = a.mmp
		a.tp = 100


func _next_turn(lg: XBattleLogic) -> void:
	XTianqiWeakAffix.turn_end(lg)
	lg.turn += 1
	XTianqiWeakAffix.turn_begin(lg)


func _act(lg: XBattleLogic, u, sk, t = null) -> Array:
	u.mp = u.mmp
	u.tp = 100
	return lg.act(u, sk if sk is Dictionary else XDB.rec("Skills", int(sk)), t)


func _hits(logs: Array, u, t) -> int:
	return logs.filter(func(l): return l is Dictionary and l.get("type") == "hit" and is_same(l.get("user"), u) and is_same(l.get("target"), t)).size()


func _texts(logs: Array) -> Array:
	return logs.filter(func(l): return l is Dictionary and l.get("type") == "battle_text").map(func(l): return str(l.text))


func _has_text(logs: Array, part: String) -> bool:
	return _texts(logs).any(func(x): return x.contains(part))


func _idx_text(logs: Array, part: String) -> int:
	for i in logs.size():
		if logs[i] is Dictionary and logs[i].get("type") == "battle_text" and str(logs[i].text).contains(part):
			return i
	return -1


func _last_hit_idx(logs: Array, u, t) -> int:
	var n := -1
	for i in logs.size():
		var l = logs[i]
		if l is Dictionary and l.get("type") == "hit" and is_same(l.get("user"), u) and is_same(l.get("target"), t):
			n = i
	return n


## 手工开一根：u 用 sk，记一笔直接有效命中 t（不真打），收尾拿派生
func _frame_hit(lg: XBattleLogic, u, sk: Dictionary, t) -> Array:
	XTianqiWeakAffix.root_begin(lg, u, sk)
	XTianqiWeakAffix._frame(lg).hits.append({"user": u, "target": t, "hp": 1.0})
	return XTianqiWeakAffix.root_end(lg)


## 敌人一次行动（不走 act）：begin → 段数次 _invoke → end（同 xiyou_tianqi_skill_debt，测原生反击率）
func _counter_stats(lg: XBattleLogic, b, e, n: int) -> Dictionary:
	var phys := XDB.rec("Skills", PHYS)
	var st := {"with_counter": 0, "swallowed": 0}
	for i in range(n):
		lg.turn = 100 + i
		XTianqiSkills.begin_action(lg, e, phys)
		var logs := lg._invoke(e, phys, b)
		logs.append_array(XTianqiSkills.end_action(lg, e, phys))
		if logs.any(func(l): return l is Dictionary and l.get("type") == "counter"):
			st.with_counter += 1
		if not logs.any(func(l): return l is Dictionary and l.get("type") == "hit" and is_same(l.get("target"), b) and not l.get("counter", false)):
			st.swallowed += 1
		_fresh(lg)
	return st


func _table() -> void:
	var d := XTianqiWeakAffix.data()
	var ents: Dictionary = d.get("entries", {})
	_check("table_two_entries_off", ents.has("w42") and ents.has("w86") and not bool(ents.w42.enabled) and not bool(ents.w86.enabled))
	_check("table_guidable_has_attack", (d.get("guidable_skills", []) as Array).has(1.0), d.get("guidable_skills"))
	_guidable_audit()
	_check("table_int_pct", typeof(ents.w42.invite.pct) == TYPE_FLOAT and float(ents.w42.invite.pct) == 50.0 and float(ents.w86.ward.pct) == 50.0 and float(ents.w42.invite.cnt_pct) == 30.0)


## T233：敌方单体伤害技签表抽查（5 签、5 不签，每类不签理由各取一个；判据见交付单 luiluu_t233）
func _guidable_audit() -> void:
	var list: Array = XTianqiWeakAffix.data().get("guidable_skills", [])
	_check("guidable_count", list.size() == 234, list.size())
	for id in [1, 112, 113, 119, 305]:  # 普攻、英勇打击、恶毒咒语、跳斩、屠灭：常规单体
		_check("guidable_signed_%d" % id, XTianqiWeakAffix.guidable({"id": id, "scope": 1}))
	for pair in [[182, "吸血"], [1303, "自定义选两个目标"], [948, "公共事件追加"], [2599, "必中放逐"], [75, "按目标血量变化"]]:
		_check("guidable_unsigned_%d_%s" % [pair[0], pair[1]], not XTianqiWeakAffix.guidable({"id": pair[0], "scope": 1}))
	_check("guidable_unsigned_group_effect_4101", not XTianqiWeakAffix.guidable({"id": 4101, "scope": 1}))


# ---- 42 布兰德瓦登「掷矛邀战」 ----

func _brand() -> void:
	var lg := _logic([BRAND, 1, 2])
	var b: XActor = lg.state.actor(BRAND)
	var ally: XActor = lg.state.actor(1)
	var other: XActor = lg.state.actor(2)
	_learn(b, [1159, 1162, 3710])
	var e0: XEnemy = lg.enemies[0]
	var e1: XEnemy = lg.enemies[1] if lg.enemies.size() > 1 else e0
	# 关着：1162 照给 30% 反击
	var raw := b.cnt
	_check("brand_off_cut_zero", XTianqiWeakB2.counter_cut(lg, b) == 0.0 and raw >= 0.3, raw)
	var native := _counter_stats(lg, b, e0, 200)
	_check("brand_off_native_counter", native.with_counter >= 30, native)
	_on("w42")
	_exclusive(b, "w42")
	_check("brand_cut_30", is_equal_approx(XTianqiWeakB2.counter_cut(lg, b), 0.3) and is_equal_approx(b.cnt, raw), [XTianqiWeakB2.counter_cut(lg, b), b.cnt])
	# ⑨ 戴着、没投掷：被打 100 次 0 次反击，每次照常挨打
	var st := _counter_stats(lg, b, e0, 100)
	_check("brand_no_throw_no_counter", st.with_counter == 0 and st.swallowed == 0, st)
	# 别人装上不生效
	_exclusive(b, "")
	_exclusive(ally, "w42")
	_check("brand_not_owner", XTianqiWeakB2.counter_cut(lg, b) == 0.0 and XTianqiWeakAffix.active_keys(lg, ally).is_empty())
	_exclusive(ally, "")
	_exclusive(b, "w42")
	# 投掷命中 → 受邀（日志一行、角标「受邀」）
	_next_turn(lg)
	_fresh(lg)
	var logs := _act(lg, b, 1159, e0)
	_check("brand_throw_invites", XTianqiWeakAffix.guiders_of(lg, e0).has(b) and _has_text(logs, "掷矛邀战：%s 受邀，本回合攻击将引向 %s" % [e0.display_name(), b.display_name()]), _texts(logs))
	_check("brand_badge_invited", XTianqiWeakAffix.badges(lg, e0) == ["受邀"] and XTianqiWeakAffix.badges(lg, b).is_empty(), XTianqiWeakAffix.badges(lg, e0))
	# 同回合再投另一个：只留最近一个
	if not is_same(e0, e1):
		_act(lg, b, 1159, e1)
		_check("brand_latest_only", XTianqiWeakAffix.guiders_of(lg, e1).has(b) and not XTianqiWeakAffix.guiders_of(lg, e0).has(b))
		_act(lg, b, 1159, e0)
	# ② 甲用可引导的普攻打队友：改打他，打完反击一次
	_fresh(lg)
	XTianqiSkills.clear_marks([b])  # 前面原生反击挂过、投掷时用掉了牛马之魂（同回合不再挂）：清掉再看这次反击挂不挂
	logs = _act(lg, e0, 1, ally)
	_check("brand_guided_hits_him", _hits(logs, e0, b) >= 1 and _hits(logs, e0, ally) == 0, [_hits(logs, e0, b), _hits(logs, e0, ally)])
	var ci := _idx_text(logs, CNT_TXT)
	_check("brand_counter_once", ci >= 0 and _hits(logs, b, e0) == 1 and ci > _last_hit_idx(logs, e0, b), [ci, _hits(logs, b, e0), _texts(logs)])
	_check("brand_counter_arms_next", b.has_meta("xtq_cnext"))
	var bh := logs.filter(func(l): return l is Dictionary and l.get("type") == "hit" and is_same(l.get("user"), b))
	_check("brand_counter_views", bh.size() == 1 and bh[0].has("views") and (bh[0].views as Dictionary).has(e0), bh.map(func(l): return l.keys()))
	_check("brand_counter_text", _has_text(logs, "掷矛邀战：%s 反击 %s！" % [b.display_name(), e0.display_name()]), _texts(logs))  # 进阶 4 牛马之魂认这次反击
	# 同回合甲再打：不再反击（每自然回合 1 次）
	_fresh(lg)
	logs = _act(lg, e0, 1, ally)
	_check("brand_once_per_turn", _hits(logs, e0, b) >= 1 and not _has_text(logs, CNT_TXT), _texts(logs))
	# ③ 不可引导的技能：目标不改；打的不是他就不反击
	_next_turn(lg)
	_act(lg, b, 1159, e0)
	_fresh(lg)
	logs = _act(lg, e0, PHYS, ally)
	_check("brand_unguidable_no_redirect", _hits(logs, e0, ally) >= 1 and _hits(logs, e0, b) == 0 and not _has_text(logs, CNT_TXT), _texts(logs))
	# 受邀者用不可引导的技能本来就打中他：也反击
	_fresh(lg)
	logs = _act(lg, e0, PHYS, b)
	_check("brand_direct_hit_counters", _hits(logs, e0, b) >= 1 and _has_text(logs, CNT_TXT), _texts(logs))
	# ⑤ 全体技打到他：反击 1 次，目标没被改（队友照样挨打）
	_next_turn(lg)
	_act(lg, b, 1159, e0)
	_fresh(lg)
	logs = _act(lg, e0, AOE, null)
	_check("brand_aoe_counters", _hits(logs, e0, b) >= 1 and _hits(logs, e0, ally) >= 1 and _hits(logs, e0, other) >= 1 and _hits(logs, b, e0) == 1, [_hits(logs, e0, b), _hits(logs, e0, ally), _hits(logs, b, e0)])
	# ⑥ 五段技：五段全部打完才反击
	_next_turn(lg)
	_act(lg, b, 1159, e0)
	_fresh(lg)
	var five: Dictionary = XDB.rec("Skills", AOE).duplicate(true)
	five.scope = 1
	five.repeats = 5
	five.erase("yepSeq")  # 不走动作序列，按重复次数打五段
	logs = _act(lg, e0, five, b)
	ci = _idx_text(logs, CNT_TXT)
	_check("brand_after_all_segments", _hits(logs, e0, b) == 5 and ci > _last_hit_idx(logs, e0, b) and _hits(logs, b, e0) == 1, [_hits(logs, e0, b), ci, _last_hit_idx(logs, e0, b)])
	# ⑧ 反击不回 TP（手工一根，他身上不挨真打）
	_next_turn(lg)
	XTianqiWeakAffix.mark_guide(lg, e0, b, "w42")
	b.tp = 0.0
	logs = _frame_hit(lg, e0, XDB.rec("Skills", 1), b)
	_check("brand_counter_no_tp", _has_text(logs, CNT_TXT) and b.tp == 0.0, b.tp)
	# 四骑士主动技（horseman_strike）的直接命中也算
	_next_turn(lg)
	XTianqiWeakAffix.mark_guide(lg, e0, b, "w42")
	var hs := {"tianqi_horseman": "war", "key": "test", "name": "测试骑士技"}
	XTianqiWeakAffix.root_begin(lg, e0, hs)
	lg.horseman_strike(e0, b, hs, 10.0, false)
	logs = XTianqiWeakAffix.root_end(lg)
	_check("brand_horseman_strike_counters", _has_text(logs, CNT_TXT), _texts(logs))
	# ⑦ 被眩晕：不反、不扣次数；同回合解控后再被打中：反击
	_next_turn(lg)
	XTianqiWeakAffix.mark_guide(lg, e0, b, "w42")
	b.add_state(STUN)
	logs = _frame_hit(lg, e0, XDB.rec("Skills", 1), b)
	var stunned_ok := b.is_state_affected(STUN) and not _has_text(logs, CNT_TXT) and XTianqiWeakAffix.turn_count(lg, b, "w42") == 0
	b.remove_state(STUN)
	logs = _frame_hit(lg, e0, XDB.rec("Skills", 1), b)
	_check("brand_stunned_no_counter_no_charge", stunned_ok and _has_text(logs, CNT_TXT), _texts(logs))
	# 甲已倒：不反、不扣
	_next_turn(lg)
	XTianqiWeakAffix.mark_guide(lg, e0, b, "w42")
	e0.add_state(1)
	logs = _frame_hit(lg, e0, XDB.rec("Skills", 1), b)
	_check("brand_foe_dead_no_counter", not _has_text(logs, CNT_TXT) and XTianqiWeakAffix.turn_count(lg, b, "w42") == 0)
	_fresh(lg)
	# 回合结束摘掉受邀
	XTianqiWeakAffix.mark_guide(lg, e0, b, "w42")
	_next_turn(lg)
	_check("brand_invite_turn_end", not XTianqiWeakAffix.guiders_of(lg, e0).has(b) and XTianqiWeakAffix.badges(lg, e0).is_empty())
	# 半伤：反击伤害和他自己放凌空斩比约一半
	var full := 0.0
	var half := 0.0
	for i in range(30):
		_fresh(lg)
		full += float(lg.apply(b, XDB.rec("Skills", 1153), e0).hp)
		_fresh(lg)
		_next_turn(lg)
		XTianqiWeakAffix.mark_guide(lg, e0, b, "w42")
		for l in _frame_hit(lg, e0, XDB.rec("Skills", 1), b):
			if l is Dictionary and l.get("type") == "hit" and is_same(l.get("user"), b):
				half += float(l.hp)
	var ratio := half / maxf(1.0, full)
	_check("brand_counter_half", ratio > 0.38 and ratio < 0.62, [ratio, half, full])
	# 打混子：反击是专属派生，盾照扣，不记他「打过混子」
	_next_turn(lg)
	var f := {"line": "plague", "mode": "body", "knight": e0, "hit_knight": {}, "queue": [], "shield_open": true, "shield_acc": 0.0, "phase": 1, "broken_turn": -1}
	lg.set_meta(XTianqiHorsemen.META, f)
	if XTianqiHorsemen.active(lg):
		XTianqiWeakAffix.mark_guide(lg, e0, b, "w42")
		logs = _frame_hit(lg, e0, XDB.rec("Skills", 1), b)
		_check("brand_counter_hunzi_no_mark", _has_text(logs, CNT_TXT) and not XTianqiHorsemen.fight(lg).hit_knight.has(b), XTianqiHorsemen.fight(lg).hit_knight.size())
		_check("brand_counter_hunzi_shield", float(f.shield_acc) > 0.0 or int(f.broken_turn) >= 0, [f.shield_acc, f.broken_turn])
	else:
		_check("brand_counter_hunzi_no_mark", false, "混子夹具没起来")
	lg.remove_meta(XTianqiHorsemen.META)
	# 他倒下：受邀作废；同回合拉起来，旧受邀不再引导、不反击
	_next_turn(lg)
	_fresh(lg)
	_act(lg, b, 1159, e0)
	var invited := XTianqiWeakAffix.guiders_of(lg, e0).has(b)
	b.add_state(1)
	_act(lg, e0, 1, ally)
	var dropped := not XTianqiWeakAffix.guiders_of(lg, e0).has(b)
	b.remove_state(1)
	b.hp = b.mhp
	_fresh(lg)
	logs = _act(lg, e0, 1, ally)
	_check("brand_down_invite_void", invited and dropped and _hits(logs, e0, ally) >= 1 and _hits(logs, e0, b) == 0 and not _has_text(logs, CNT_TXT) and XTianqiWeakAffix.badges(lg, e0).is_empty(), [invited, dropped, _texts(logs)])
	# 叠别的反击来源（屏障术 +100%）：在没夹的反击率上扣 30% 还满，每次都走重构半伤凌空斩、不吞攻击
	_fresh(lg)
	b.add_state(BARRIER)
	var raw6 := b.xparam(6)
	var stk := _counter_stats(lg, b, e0, 40)
	_check("brand_stacked_cut_before_clamp", raw6 >= 1.3 and b.is_state_affected(BARRIER) and stk.with_counter == 40 and stk.swallowed == 0, [raw6, stk])
	XTianqiSkills.begin_action(lg, e0, XDB.rec("Skills", PHYS))
	logs = lg._invoke(e0, XDB.rec("Skills", PHYS), b)
	logs.append_array(XTianqiSkills.end_action(lg, e0, XDB.rec("Skills", PHYS)))
	var ch := logs.filter(func(l): return l is Dictionary and l.get("type") == "hit" and is_same(l.get("user"), b))
	_check("brand_stacked_rework_cast", ch.size() >= 1 and int(ch[0].get("skill", {}).get("id", 0)) == 1153 and _hits(logs, e0, b) >= 1, ch.map(func(l): return l.get("skill", {}).get("id")))
	b.remove_state(BARRIER)
	lg.end_battle(0)


## 开关关：投掷不邀、可引导普攻照原生打原目标、30% 反击照原生
func _brand_off() -> void:
	_off("w42")
	var lg := _logic([BRAND, 1, 2])
	var b: XActor = lg.state.actor(BRAND)
	var ally: XActor = lg.state.actor(1)
	_learn(b, [1159, 1162])
	_exclusive(b, "w42")
	var e0: XEnemy = lg.enemies[0]
	_next_turn(lg)
	var logs := _act(lg, b, 1159, e0)
	_fresh(lg)
	logs.append_array(_act(lg, e0, 1, ally))
	_check("brand_switch_off_native", XTianqiWeakAffix.guiders_of(lg, e0).is_empty() and _hits(logs, e0, ally) >= 1 and _hits(logs, e0, b) == 0 and not _has_text(logs, "受邀") and XTianqiWeakB2.counter_cut(lg, b) == 0.0, _texts(logs))
	lg.end_battle(0)


# ---- 86 张三丰「护犊」 ----

func _zhang_logic() -> XBattleLogic:
	var lg := _logic([ZHANG, 1, 2])
	var z: XActor = lg.state.actor(ZHANG)
	_learn(z, [5863, 5860, 5866])
	lg._battle_start_states()
	_fresh(lg)
	return lg


func _guard_fired(logs: Array) -> int:
	return logs.filter(func(l): return l is Dictionary and l.get("type") == "action" and l.get("guard", false)).size()


func _zhang() -> void:
	var lg := _zhang_logic()
	var z: XActor = lg.state.actor(ZHANG)
	var a1: XActor = lg.state.actor(1)
	var a2: XActor = lg.state.actor(2)
	var e0: XEnemy = lg.enemies[0]
	_on("w86")
	_exclusive(z, "w86")
	_check("zhang_masks_native", XTianqiWeakB2.masks_guard(lg, z))
	# 选被护者：生命比例最低；平局取出战栏靠前的
	_next_turn(lg)
	_check("zhang_ward_tie_front", is_same(XTianqiWeakB2.ward_of(lg, z), a1), XTianqiWeakB2._name(XTianqiWeakB2.ward_of(lg, z)))
	a2.hp = a2.mhp * 0.3
	a1.hp = a1.mhp * 0.5
	z.hp = z.mhp * 0.1  # 他自己不算
	_next_turn(lg)
	_check("zhang_ward_lowest_ratio", is_same(XTianqiWeakB2.ward_of(lg, z), a2))
	_check("zhang_badge_ward", XTianqiWeakAffix.badges(lg, a2) == ["受护"] and XTianqiWeakAffix.badges(lg, a1).is_empty() and XTianqiWeakAffix.badges(lg, z).is_empty(), XTianqiWeakAffix.badges(lg, a2))
	# ① 被护者被打：追 1 次半伤太极拳（四段），太极之力不变，不带效果 44；日志有「守护」一行
	_fresh(lg)
	var v1204 := float(lg.state.variable(1204))
	var logs := _act(lg, e0, PHYS, a2)
	var chase := logs.filter(func(l): return l is Dictionary and l.get("type") == "action" and l.get("w86", false))
	_check("zhang_chase_text", _has_text(logs, "护犊：%s 追击 %s！" % [z.display_name(), e0.display_name()]) and _has_text(logs, "护犊：本回合守护 %s" % a2.display_name()), _texts(logs))
	_check("zhang_chase_on_ward", _has_text(logs, "护犊：") and chase.size() == 1 and _hits(logs, z, e0) >= 4, [_texts(logs), _hits(logs, z, e0)])
	_check("zhang_chase_taiji_only", chase.size() == 1 and int(chase[0].skill.id) == 5860 and not (chase[0].skill.get("effects", []) as Array).any(func(x): return int(x.get("code", 0)) == 44))
	_check("zhang_no_taiji_power", float(lg.state.variable(1204)) == v1204, [v1204, lg.state.variable(1204)])
	_check("zhang_announce_ward", _has_text(logs, "本回合守护"), _texts(logs))
	_check("zhang_chase_after_root", _idx_text(logs, "追击") > _last_hit_idx(logs, e0, a2))
	# ② 同回合再被打：不追
	_fresh(lg)
	logs = _act(lg, e0, PHYS, a2)
	_check("zhang_once_per_turn", _hits(logs, e0, a2) >= 1 and not _has_text(logs, "追击"), _texts(logs))
	# ③ 别的队友被打：不追，原生护短也关了（60 回合）
	var native := 0
	var chased := 0
	for i in range(60):
		_next_turn(lg)
		XTianqiWeakB2.ward_of(lg, z)
		XTianqiWeakAffix.stock(lg, z, "w86").ward = a2
		_fresh(lg)
		logs = _act(lg, e0, PHYS, a1)
		native += _guard_fired(logs)
		chased += 1 if _has_text(logs, "追击") else 0
	_check("zhang_other_ally_no_chase_native_off", native == 0 and chased == 0, [native, chased])
	# ⑤ 五段技全中被护者：五段打完追 1 次
	_next_turn(lg)
	XTianqiWeakAffix.stock(lg, z, "w86").ward = a2
	_fresh(lg)
	var five: Dictionary = XDB.rec("Skills", AOE).duplicate(true)
	five.scope = 1
	five.repeats = 5
	five.erase("yepSeq")  # 不走动作序列，按重复次数打五段
	logs = _act(lg, e0, five, a2)
	_check("zhang_five_segments_once", _hits(logs, e0, a2) == 5 and _texts(logs).filter(func(x): return x.contains("追击")).size() == 1 and _idx_text(logs, "追击") > _last_hit_idx(logs, e0, a2), [_hits(logs, e0, a2), _texts(logs)])
	# ⑥ 全体技同时打中被护者和别人：追 1 次
	_next_turn(lg)
	XTianqiWeakAffix.stock(lg, z, "w86").ward = a2
	_fresh(lg)
	logs = _act(lg, e0, AOE, null)
	_check("zhang_aoe_once", _hits(logs, e0, a2) >= 1 and _hits(logs, e0, a1) >= 1 and _texts(logs).filter(func(x): return x.contains("追击")).size() == 1, _texts(logs))
	# 骑士主动技（horseman_strike）打中被护者：追
	_next_turn(lg)
	XTianqiWeakAffix.stock(lg, z, "w86").ward = a2
	_fresh(lg)
	var hs := {"tianqi_horseman": "plague", "key": "test", "name": "测试骑士技"}
	XTianqiWeakAffix.root_begin(lg, e0, hs)
	lg.horseman_strike(e0, a2, hs, 10.0, false)
	logs = XTianqiWeakAffix.root_end(lg)
	_check("zhang_horseman_strike_chases", _has_text(logs, "追击"), _texts(logs))
	# ⑧ 他被控：不追、不扣；同回合解控后再打：追
	_next_turn(lg)
	XTianqiWeakAffix.stock(lg, z, "w86").ward = a2
	_fresh(lg)
	z.add_state(STUN)
	logs = _frame_hit(lg, e0, XDB.rec("Skills", PHYS), a2)
	var stun_ok := z.is_state_affected(STUN) and not _has_text(logs, "追击") and XTianqiWeakAffix.turn_count(lg, z, "w86") == 0
	z.remove_state(STUN)
	logs = _frame_hit(lg, e0, XDB.rec("Skills", PHYS), a2)
	_check("zhang_stunned_no_chase_no_charge", stun_ok and _has_text(logs, "追击"), _texts(logs))
	# ④ 回合中被护者倒下：本回合不重选，谁被打都不追
	_next_turn(lg)
	XTianqiWeakAffix.stock(lg, z, "w86").ward = a2
	_fresh(lg)
	a2.add_state(1)
	logs = _act(lg, e0, PHYS, a1)
	_check("zhang_ward_down_no_reselect", not _has_text(logs, "追击") and is_same(XTianqiWeakB2.ward_of(lg, z), a2))
	_fresh(lg)
	# 出手的敌人已倒：不追、不扣
	_next_turn(lg)
	XTianqiWeakAffix.stock(lg, z, "w86").ward = a2
	e0.add_state(1)
	logs = _frame_hit(lg, e0, XDB.rec("Skills", PHYS), a2)
	_check("zhang_foe_dead_no_chase", not _has_text(logs, "追击") and XTianqiWeakAffix.turn_count(lg, z, "w86") == 0)
	_fresh(lg)
	# 半伤：追击伤害和他自己放整招太极拳（同一份去 44 的招、打满段）比约一半
	var full := 0.0
	var half := 0.0
	var cast: Dictionary = XDB.rec("Skills", 5860).duplicate(true)
	cast.effects = (cast.effects as Array).filter(func(x): return int(x.get("code", 0)) != 44)
	for i in range(20):
		_fresh(lg)
		for l in XTianqiSkills._cast(lg, z, cast, [e0]):
			if l is Dictionary and l.get("type") == "hit":
				full += float(l.hp)
		_fresh(lg)
		_next_turn(lg)
		XTianqiWeakAffix.stock(lg, z, "w86").ward = a2
		for l in _frame_hit(lg, e0, XDB.rec("Skills", PHYS), a2):
			if l is Dictionary and l.get("type") == "hit" and is_same(l.get("user"), z):
				half += float(l.hp)
	var ratio := half / maxf(1.0, full)
	_check("zhang_chase_half", ratio > 0.38 and ratio < 0.62, [ratio, half, full])
	# 打混子：追击是专属派生，盾照扣，不记他「打过混子」
	_next_turn(lg)
	XTianqiWeakAffix.stock(lg, z, "w86").ward = a2
	var f := {"line": "plague", "mode": "body", "knight": e0, "hit_knight": {}, "queue": [], "shield_open": true, "shield_acc": 0.0, "phase": 1, "broken_turn": -1}
	lg.set_meta(XTianqiHorsemen.META, f)
	if XTianqiHorsemen.active(lg):
		logs = _frame_hit(lg, e0, XDB.rec("Skills", PHYS), a2)
		_check("zhang_chase_hunzi_no_mark", _has_text(logs, "追击") and not XTianqiHorsemen.fight(lg).hit_knight.has(z), XTianqiHorsemen.fight(lg).hit_knight.size())
		_check("zhang_chase_hunzi_shield", float(f.shield_acc) > 0.0 or int(f.broken_turn) >= 0, [f.shield_acc, f.broken_turn])
	else:
		_check("zhang_chase_hunzi_no_mark", false, "混子夹具没起来")
	lg.remove_meta(XTianqiHorsemen.META)
	# 没学原生护短 5863：护犊不生效（不遮、不选、不追）
	z.forget_skill(5863)
	_next_turn(lg)
	XTianqiWeakAffix.stock(lg, z, "w86").ward = a2
	logs = _frame_hit(lg, e0, XDB.rec("Skills", PHYS), a2)
	_check("zhang_needs_5863", not XTianqiWeakB2.masks_guard(lg, z) and not _has_text(logs, "追击") and XTianqiWeakAffix.badges(lg, a2).is_empty(), _texts(logs))
	_learn(z, [5863])
	# GUARD 关（回原版 2007）：专属不生效
	XTianqiSkills.GUARD = false
	_next_turn(lg)
	XTianqiWeakAffix.stock(lg, z, "w86").ward = a2
	logs = _frame_hit(lg, e0, XDB.rec("Skills", PHYS), a2)
	_check("zhang_guard_off_inert", not XTianqiWeakB2.masks_guard(lg, z) and not _has_text(logs, "追击") and XTianqiWeakAffix.badges(lg, a2).is_empty())
	XTianqiSkills.GUARD = true
	lg.end_battle(0)


## 开关关：原生护短照旧（别的队友被打约 30% 追、每回合 ≤2）
func _zhang_off() -> void:
	_off("w86")
	var lg := _zhang_logic()
	var z: XActor = lg.state.actor(ZHANG)
	var a1: XActor = lg.state.actor(1)
	_exclusive(z, "w86")
	var e0: XEnemy = lg.enemies[0]
	var native := 0
	var chased := false
	for i in range(80):
		_next_turn(lg)
		_fresh(lg)
		var logs := _act(lg, e0, PHYS, a1)
		native += _guard_fired(logs)
		chased = chased or _has_text(logs, "追击")
	_check("zhang_switch_off_native_guard", native >= 8 and not chased and not XTianqiWeakB2.masks_guard(lg, z), native)
	lg.end_battle(0)


# ---- 西游档：条目开着、本人装着也不生效 ----
func _xiyou_save() -> void:
	_on("w42")
	_on("w86")
	var lg := _logic([BRAND, ZHANG, 1])
	var b: XActor = lg.state.actor(BRAND)
	var z: XActor = lg.state.actor(ZHANG)
	_learn(b, [1162])
	_exclusive(b, "w42")
	_exclusive(z, "w86")
	var tq = lg.state.flags.get("tianqi")
	lg.state.flags.erase("tianqi")
	_check("xiyou_save_off", XTianqiWeakAffix.active_keys(lg, b).is_empty() and XTianqiWeakB2.counter_cut(lg, b) == 0.0 and not XTianqiWeakB2.masks_guard(lg, z))
	lg.state.flags["tianqi"] = tq
	lg.end_battle(0)
	_off("w42")
	_off("w86")
