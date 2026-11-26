extends Node
## T549 天启篇装备自带技能批量改写专项（skill_rework.json 里 _note 以「T549」开头的行，生成脚本 03_转换工具/天启篇装备招改写生成.py）：
## 1) 逐招新旧对照：同角色（3 艾坤 70 级）、同敌（敌群 2，血量抬到 1e9）、同种子，关 XTianqiSkills.ENABLED 测原版、开着测改写；
##    三个种子（原版波动 variance 照留，种子之间是真方差），每招打印 T549_ROW 一行（交付单的逐招表由它出）。
##    断言：改写后走模块公式；实打段数＝改写后序列段数×重复×随机次数（卡面写的段数）；伤害 > 0；费用、冷却同表。
## 2) 995 汲血斩（Kyo 11-26 事项 80）：没穿血月三件套 2 段、穿齐 4 段（额外释放一次恢复），每段回血是 7% 最大生命，不再是固定 500。
## 3) 专属增伤封顶：天眼之冠 SkillPass3624、猫爪 SkillPass3647、墨锐四件 SkillPass2639／0939／0971 在天启篇视图里压到 20%（墨锐 5～20%），西游档原值。
## 4) 复活／治疗：先祖之魂、龙马复活术复活后 30% 生命；风语者祝福 12%；痛饮回 10% 魔法。
## 5) 西游档零改动：关掉改写后每招公式、耗蓝、TP 跟 Skills.json 原记录一致。

const T541 = preload("res://tests/xiyou_t541_equip_skills.gd")
const SEEDS := ["0000000000000001", "0000000000000002", "0000000000000003"]

var passed := 0
var total := 0
var h  # T541 的工具函数（_make_tianqi／_make_dummy_battle／_sum_hits／_equip_*）


func _ready() -> void:
	_run.call_deferred()


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail).left(600))


func _ids() -> Array:
	var out := []
	for k in XTianqiSkills.data().get("skills", {}):
		var row = XTianqiSkills.data().skills[k]
		if row is Dictionary and str(row.get("_note", "")).begins_with("T549") and row.has("damage"):
			out.append(int(k))
	out.sort()
	return out


func _actor(s: XState) -> XActor:
	var a: XActor = s.actor(3)
	a.change_level(70)
	a.refresh_passive()
	a.recover_all()
	a.tp = 100
	return a


var _st := {}  # on → [XState, XActor]：一种口径只开一次新局（每招重开要 10 分钟以上，超时）


func _cast(sid: int, seed_hex: String, on: bool) -> Dictionary:
	if XTianqiSkills.ENABLED != on:
		XTianqiSkills.ENABLED = on
		XTianqiSkills.reload_table()
	if not _st.has(on):
		var s0: XState = h._make_tianqi([3, 1, 2, 4], 25)
		_st[on] = [s0, _actor(s0)]
	var s: XState = _st[on][0]
	var a: XActor = _st[on][1]
	XState.current = s
	a.recover_all()
	a.tp = 100
	a.cooldowns.clear()
	var lg: XBattleLogic = h._make_dummy_battle(s, 2, seed_hex)
	var sk := XDB.rec("Skills", sid)
	var shown_list := lg.enemies.filter(func(e): return not e.hidden and e.is_alive())
	var logs := lg.act(a, sk, shown_list[0] if not shown_list.is_empty() else lg.enemies[0])
	var dmg := 0.0
	var hits := 0
	for r in logs:  # 只算这一招自己的段（艾坤的追加、连锁另算，不进卡面段数）
		if r is Dictionary and r.get("type") == "hit" and int((r.get("skill", {}) as Dictionary).get("id", 0)) in _family(sid):
			hits += 1
			dmg += maxf(0.0, float(r.get("hp", 0.0)))
	var shown := lg.enemies.filter(func(e): return not e.hidden).size()
	return {"dmg": dmg, "hits": hits, "sk": sk, "a": a, "enemies": shown}


## 红牌 3651 按 <ChangeTo> 两成变黄牌 3652、两成变蓝牌 3653：三张牌算同一招
func _family(sid: int) -> Array:
	return [3651, 3652, 3653] if sid in [3651, 3652, 3653] else [sid]


## 改写后序列段数（target＋whole 里的 action effect，大小写都算）×重复×随机次数
func _expected_hits(sk: Dictionary, n_enemies: int) -> int:
	var n := 0
	var seq = sk.get("yepSeq")
	if seq is Dictionary:
		for ph in ["target", "whole"]:
			for c in seq.get(ph, []):
				if c is Array and not c.is_empty() and str(c[0]).strip_edges().to_lower() == "action effect":
					n += 1
	n = maxi(1, n)  # 有动作序列时 repeats 不重放（3557 repeats 2 实测每目标 2 段）
	var scope := int(sk.get("scope", 1))
	if scope >= 3 and scope <= 6:
		n *= scope - 2
	elif scope == 2:
		n *= n_enemies
	return n


func _test_rows() -> void:
	var ids := _ids()
	check("t549.row_count", ids.size() >= 160, ids.size())
	for sid in ids:
		var sp := XTianqiSkills.spec(sid)
		var olds := []
		var news := []
		var hits_ok := true
		var detail := {}
		var os := SEEDS.map(func(sd): return _cast(sid, sd, false))
		var ns := SEEDS.map(func(sd): return _cast(sid, sd, true))
		for i in SEEDS.size():
			var sd: String = SEEDS[i]
			var o: Dictionary = os[i]
			var n: Dictionary = ns[i]
			olds.append(o.dmg)
			news.append(n.dmg)
			var exps: Array = _family(sid).map(func(f): return _expected_hits(XDB.rec("Skills", f), int(n.enemies)))
			var exp: int = exps[_family(sid).find(sid)]
			if not exps.has(int(n.hits)):  # 红牌一家：变成黄牌／蓝牌时按变出来那张的段数
				hits_ok = false
				detail = {"seed": sd, "hits": n.hits, "expected": exps}
			if sd == SEEDS[0]:
				check("t549.%d.module" % sid, str(n.sk.get("damage", {}).get("formula", "")) == "XTianqiSkills.formula(a,b,%d)" % sid, n.sk.get("damage", {}).get("formula"))
				check("t549.%d.tp" % sid, int(n.sk.get("tpCost", -1)) == int(sp.get("tp", 0)), [n.sk.get("tpCost"), sp.get("tp")])
				if sp.has("mp_pct"):
					check("t549.%d.mp_pct" % sid, int(n.sk.get("mpCost", -1)) == 0 and str(n.sk.note).contains("<MP Cost: %d%%>" % int(sp.mp_pct)), n.sk.get("mpCost"))
				else:
					check("t549.%d.mp0" % sid, int(n.sk.get("mpCost", -1)) == 0, n.sk.get("mpCost"))
				if sp.has("cooldown"):
					check("t549.%d.cd" % sid, int(n.sk.get("meta", {}).get("Cooldown", "0").strip_edges()) == int(sp.cooldown), n.sk.get("meta", {}).get("Cooldown"))
				elif str(sp.get("kind", "")) == "普攻":
					check("t549.%d.no_cd" % sid, not n.sk.get("meta", {}).has("Cooldown"), n.sk.get("meta", {}).get("Cooldown"))
				# 西游档零改动：关改写时就是 Skills.json 原记录
				var raw: Dictionary = XDB.table("Skills")[sid]
				check("t549.%d.xiyou_raw" % sid, str(o.sk.damage.formula) == str(raw.damage.formula) and int(o.sk.mpCost) == int(raw.mpCost) and int(o.sk.tpCost) == int(raw.tpCost), [o.sk.damage.formula, raw.damage.formula])
		check("t549.%d.hits_match_card" % sid, hits_ok, detail)
		check("t549.%d.dmg_positive" % sid, news.all(func(v): return float(v) > 0.0), news)
		print("T549_ROW %d|%s|%s|old=%s|new=%s|hits=%d" % [sid, str(sp.get("name", "")), str(sp.get("kind", "")),
			",".join(olds.map(func(v): return str(int(v)))), ",".join(news.map(func(v): return str(int(v)))), _expected_hits(XDB.rec("Skills", sid), 1)])


func _test_995() -> void:
	XTianqiSkills.ENABLED = true
	XTianqiSkills.reload_table()
	for with_set in [false, true]:
		var s: XState = h._make_tianqi([3, 1, 2, 4], 25)
		var a := _actor(s)
		h._equip_weapon(a, 1105)
		if with_set:
			for id in [1568, 1569, 1570]:
				h._equip_armor(a, id)
		a.refresh_passive()
		a.recover_all()
		a.hp = floorf(a.mhp * 0.2)
		var hp0 := a.hp
		var lg: XBattleLogic = h._make_dummy_battle(s, 2, SEEDS[0])
		var logs := lg.act(a, XDB.rec("Skills", 995), lg.enemies[0])
		var r: Dictionary = h._sum_hits(logs, lg.enemies[0])
		var n := 4 if with_set else 2
		var per := floorf(a.mhp * 0.07)
		check("t549.995.hits_%s" % ("set" if with_set else "noset"), int(r.hits) == n, r.hits)
		# 每段回 7%：总回血在 n×7% 附近（取整误差和吸血之类留 1 点余量）
		check("t549.995.heal_%s" % ("set" if with_set else "noset"), absf((a.hp - hp0) - per * n) <= float(n) + 1.0, {"heal": a.hp - hp0, "expect": per * n, "mhp": a.mhp})
	var desc := str(XTianqiSkills.spec(995).get("desc", []))
	check("t549.995.card", desc.contains("7%") and desc.contains("额外释放一次") and desc.contains("2 段合计×100%"), desc)


func _skill_pass_of(kind: String, id: int, sid: int) -> String:
	var item := XGear.template(kind, id)
	var v = XTianqiGear.stat_list([item])[0]
	return str(v.get("meta", {}).get("SkillPass%04d" % sid, v.get("meta", {}).get("SkillPass%d" % sid, "")))


func _test_skill_pass() -> void:
	var cases := [["armor", 3774, 3624, "20%", "325%"], ["armor", 3775, 3625, "20%", "325%"], ["armor", 3776, 3626, "20%", "325%"],
		["weapon", 1609, 3647, "20%", "500%"], ["armor", 3663, 2639, "5%", "130%"], ["armor", 4253, 2639, "20%", "720%"], ["armor", 4253, 939, "20%", "720%"]]
	XTianqiSkills.ENABLED = true
	XTianqiSkills.reload_table()
	XState.current = h._make_tianqi([3, 1, 2, 4], 25)
	for c in cases:
		check("t549.skillpass.tq.%s%d.%d" % [c[0], c[1], c[2]], _skill_pass_of(c[0], c[1], c[2]).replace(" ", "") == c[3], _skill_pass_of(c[0], c[1], c[2]))
	var note := str(XTianqiGear.stat_list([XGear.template("weapon", 1371)])[0].get("note", ""))
	check("t549.1371.card_no_false_claim", not note.contains("伤害提高65%") and note.contains("一段寒冰伤害"), note.left(300))
	XState.current = h._make_xiyou([3])
	for c in cases:
		check("t549.skillpass.xiyou.%s%d.%d" % [c[0], c[1], c[2]], _skill_pass_of(c[0], c[1], c[2]).replace(" ", "") == c[4], _skill_pass_of(c[0], c[1], c[2]))


func _test_support() -> void:
	XTianqiSkills.ENABLED = true
	XTianqiSkills.reload_table()
	for sid in [499, 6240]:
		var s: XState = h._make_tianqi([3, 1, 2, 4], 25)
		var a := _actor(s)
		var lg: XBattleLogic = h._make_dummy_battle(s, 2, SEEDS[0])
		var ally: XActor = null
		for m in lg.actors:
			if m != a:
				ally = m
				break
		ally.hp = 0
		ally.add_state(1)
		lg.act(a, XDB.rec("Skills", sid), ally)
		var pct := ally.hp / maxf(1.0, ally.mhp)
		check("t549.%d.revive_30" % sid, not ally.is_dead() and pct >= 0.29 and pct <= 0.31, {"hp": ally.hp, "mhp": ally.mhp, "dead": ally.is_dead()})
	var s2: XState = h._make_tianqi([3, 1, 2, 4], 25)
	var a2 := _actor(s2)
	var lg2: XBattleLogic = h._make_dummy_battle(s2, 2, SEEDS[0])
	var tgt: XActor = lg2.actors[1] if lg2.actors[0] == a2 else lg2.actors[0]
	tgt.hp = floorf(tgt.mhp * 0.3)
	var hp0 := tgt.hp
	lg2.act(a2, XDB.rec("Skills", 861), tgt)
	var gain := (tgt.hp - hp0) / tgt.mhp
	check("t549.861.heal_12", gain >= 0.11 and gain <= 0.14, gain)
	a2.mp = 0
	lg2.act(a2, XDB.rec("Skills", 306), a2)
	var mg := a2.mp / maxf(1.0, a2.mmp)
	check("t549.306.mp_10", mg >= 0.09 and mg <= 0.12, mg)


func _run() -> void:
	h = T541.new()
	var was_en := XTianqiSkills.ENABLED
	var was_force := XEnemy.force_roll
	var was_auto := XMessageBox.auto
	XEnemy.force_roll = 100.0
	XMessageBox.auto = true
	_test_rows()
	_test_995()
	_test_skill_pass()
	_test_support()
	XTianqiSkills.ENABLED = was_en
	XTianqiSkills.reload_table()
	XEnemy.force_roll = was_force
	XMessageBox.auto = was_auto
	XState.current = null
	h.free()
	print("TEST_RESULT=" + JSON.stringify({"test": "xiyou_t549_gear_skills", "passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
