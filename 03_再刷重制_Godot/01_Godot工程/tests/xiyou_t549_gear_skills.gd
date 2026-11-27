extends Node
## T549 天启篇装备自带技能批量改写专项（skill_rework.json 里 _note 以「T549」开头的行，生成脚本 03_转换工具/天启篇装备招改写生成.py）：
## 1) 逐招新旧对照：同角色（3 艾坤 70 级）、同敌（敌群 2，血量抬到 1e9）、同种子，关 XTianqiSkills.ENABLED 测原版、开着测改写；
##    三个种子（原版波动 variance 照留，种子之间是真方差），每招打印 T549_ROW 一行（交付单的逐招表由它出）。
##    断言：改写后走模块公式；实打段数＝改写后序列段数×重复×随机次数（卡面写的段数）；伤害 > 0；费用、冷却同表。
## 2) 995 汲血斩（Kyo 11-26 事项 80）：没穿血月三件套 2 段、穿齐 4 段（额外释放一次恢复），每段回血是 7% 最大生命，不再是固定 500。
## 3) 专属增伤封顶：天眼之冠 SkillPass3624、猫爪 SkillPass3647、墨锐四件 SkillPass2639／0939／0971 在天启篇视图里压到 20%（墨锐 5～20%），西游档原值。
## 4) 复活／治疗：先祖之魂、龙马复活术复活后 30% 生命；风语者祝福 12%；痛饮回 10% 魔法。
## 5) 西游档零改动：关掉改写后每招公式、耗蓝、TP 跟 Skills.json 原记录一致。
## 6) T549 R1 P1-1 敌方共用招：敌方行动表引用本单技能的 42 个敌人，敌方视角（XDB.foe_skill）拿到的是关掉技能重构时的原记录；
##    同一天启篇存档里实际敌方选招（XTianqiEnemyAI.enemy_action）拿原记录、出手伤害跟关改写时逐种子相同；
##    同存档我方装备者的替换普攻（捕猎长枪 179）、武器触发（狼神爪 259）、装备授予主动（徘徊 雷行 3650）照样是改写记录。
## 7) T549 R1 P2-4 汲血斩只在命中时回血（目标闪避满时 0 回血）；P2-3／P2-4 卡面：技能卡逐行进备注、无开发用语，
##    装备面板描述替换普攻／武器触发的特效行全部换成改写后的说明（skill_rework.gear 与 gear_elem_amp 两路）。
## 8) T549 R2 P2-5：替换普攻保留原公式全部伤害属性、原权重（赤羽三项、法轮四项、红牌／潮汐斩按原比例），普通档每目标 1.0、
##    招牌 1.5，全体不再减半（彻地钉等 5 招每目标 1.0）；P2-6：凌厉长鞭 2602 天启篇打队友固定 100（FLAT_FINAL 回退开关），西游档原公式。

const T541 = preload("res://tests/xiyou_t541_equip_skills.gd")
const SEEDS := ["0000000000000001", "0000000000000002", "0000000000000003"]

## 测试用：命中率恒 0（汲血斩落空不回血）
class MissLogic extends XBattleLogic:
	func item_hit(_u: XBattler, _skill: Dictionary, _t: XBattler) -> float:
		return 0.0


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
			var armor_depth := 0  # T565：穿齐装备才放的条件段（3647 血月额外释放）测试角色没穿，不算段数
			for c in seq.get(ph, []):
				if not (c is Array) or c.is_empty():
					continue
				var nm := str(c[0]).strip_edges()
				if nm.begins_with("if "):
					if armor_depth > 0 or nm.contains("hasArmor"):
						armor_depth += 1
				elif nm == "end":
					armor_depth = maxi(0, armor_depth - 1)
				elif armor_depth == 0 and nm.to_lower() == "action effect":
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
	check("t549.995.card", desc.contains("每段挥击命中后恢复自身 7% 最大生命") and desc.contains("血月披风、血月护手和血月腰带") and desc.contains("两段合计物理攻击×100%"), desc)
	# 未命中不回血（R1 P2-4）：目标挂银鳞盾（闪避 +1000%），两段都闪掉
	var s2: XState = h._make_tianqi([3, 1, 2, 4], 25)
	var a2 := _actor(s2)
	h._equip_weapon(a2, 1105)
	a2.refresh_passive()
	a2.recover_all()
	a2.hp = floorf(a2.mhp * 0.2)
	var hp1 := a2.hp
	var lg2 := MissLogic.new()  # 命中率压成 0：两段都落空
	lg2.elite_roll = 100.0
	lg2.setup(2, s2, XBattleRandom.create(SEEDS[0]))
	for e in lg2.enemies:
		e.add_param(0, 1e9)
		e.param_refresh()
		e.hp = e.mhp
	lg2.start_turn()
	var logs2 := lg2.act(a2, XDB.rec("Skills", 995), lg2.enemies[0])
	var landed := logs2.filter(func(r): return r is Dictionary and r.get("type") == "hit" and is_same(r.get("user"), a2) and not r.missed and not r.evaded).size()
	check("t549.995.miss_all", landed == 0, landed)
	check("t549.995.no_heal_on_miss", is_equal_approx(a2.hp, hp1), {"hp": a2.hp, "hp0": hp1})


## T565（D296，Kyo 11-27 事项 87）：3647 汲血连环斩恢复血月额外释放——没穿齐 6 段、穿齐 12 段；每三段后命中回 2% 最大生命（6 段合计 4%、12 段合计 8%）
func _test_3647() -> void:
	XTianqiSkills.ENABLED = true
	XTianqiSkills.reload_table()
	for with_set in [false, true]:
		var s: XState = h._make_tianqi([3, 1, 2, 4], 25)
		var a := _actor(s)
		h._equip_weapon(a, 1609)
		if with_set:
			for id in [1568, 1569, 1570]:
				h._equip_armor(a, id)
		a.refresh_passive()
		a.recover_all()
		a.tp = 100
		a.hp = floorf(a.mhp * 0.2)
		var hp0 := a.hp
		var lg: XBattleLogic = h._make_dummy_battle(s, 2, SEEDS[0])
		var logs := lg.act(a, XDB.rec("Skills", 3647), lg.enemies[0])
		var hits := logs.filter(func(r): return r is Dictionary and r.get("type") == "hit" and int((r.get("skill", {}) as Dictionary).get("id", 0)) == 3647).size()
		var tag := "set" if with_set else "noset"
		var n := 12 if with_set else 6
		var per := floorf(a.mhp * 0.02)
		check("t565.3647.hits_%s" % tag, hits == n, hits)
		check("t565.3647.heal_%s" % tag, absf((a.hp - hp0) - per * (n / 3)) <= float(n / 3) + 1.0, {"heal": a.hp - hp0, "expect": per * (n / 3), "mhp": a.mhp})
		print("T565_3647 %s hits=%d heal=%d mhp=%d pct=%.2f" % [tag, hits, int(a.hp - hp0), int(a.mhp), (a.hp - hp0) * 100.0 / a.mhp])
	var desc := str(XTianqiSkills.spec(3647).get("desc", []))
	check("t565.3647.card", desc.contains("若第 3 段命中，恢复自身最大生命的 2%") and desc.contains("穿齐血月三件套合计 8%") and desc.contains("12 段合计物理攻击×600%") and not desc.contains("消耗："), desc)
	# 文字审：表头「命中类型」写必中（卡上显示「命中：必中」），TP 消耗只留数据库那一行
	var note := str(XDB.rec("Skills", 3647).get("note", ""))
	check("t565.3647.header", note.contains("命中类型:必中") and not note.contains("命中类型:物理") and int(XDB.rec("Skills", 3647).get("tpCost", 0)) == 35, note.substr(0, 400))
	# 西游档零改动：关改写时是原记录（1855 底数、Hp +1500）
	XTianqiSkills.ENABLED = false
	XTianqiSkills.reload_table()
	var raw := XDB.rec("Skills", 3647)
	check("t565.3647.xiyou_raw", str(raw.damage.formula) == "1855 + a.atk * 25 - (0 * 4)" and str(raw.note).contains("Hp +1500"), raw.damage.formula)
	XTianqiSkills.ENABLED = true
	XTianqiSkills.reload_table()


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


## T549 改写行（actor_only）
func _actor_only_ids() -> Array:
	var out := []
	for k in XTianqiSkills.data().get("skills", {}):
		if XTianqiSkills.actor_only(int(k)):
			out.append(int(k))
	return out


func _test_foe() -> void:
	XTianqiSkills.ENABLED = true
	XTianqiSkills.reload_table()
	var s: XState = h._make_tianqi([3, 1, 2, 4], 25)
	XState.current = s
	var ids := _actor_only_ids()
	check("t549.foe.actor_only_count", ids.size() == 170, ids.size())
	var pairs := []  # [敌人号, 技能号]
	var enemies := {}
	var et: Array = XDB.table("Enemies")
	for i in range(1, et.size()):
		var e = XDB.rec("Enemies", i)
		if not e is Dictionary or e.is_empty():
			continue
		for act in e.get("actions", []):
			if int(act.skillId) in ids:
				pairs.append([i, int(act.skillId)])
				enemies[i] = true
	check("t549.foe.enemy_refs_42", enemies.size() == 42, enemies.size())
	var foe := {}
	var mine := {}
	for p in pairs:
		foe[p[1]] = JSON.stringify(XDB.foe_skill(p[1]))
		mine[p[1]] = XDB.rec("Skills", p[1])
	XTianqiSkills.ENABLED = false
	XTianqiSkills.reload_table()
	var orig := {}
	for sid in foe:
		orig[sid] = JSON.stringify(XDB.rec("Skills", sid))
	XTianqiSkills.ENABLED = true
	XTianqiSkills.reload_table()
	for p in pairs:
		check("t549.foe.e%d.s%d.original" % [p[0], p[1]], foe[p[1]] == orig[p[1]], [p, str(foe[p[1]]).left(200)])
	for sid in mine:
		check("t549.foe.s%d.actor_still_rewritten" % sid, str(mine[sid].damage.formula) == "XTianqiSkills.formula(a,b,%d)" % sid, mine[sid].damage.formula)
	# 实际敌方选招与出手：首领捕猎者（敌群 20／捕猎冲锋 179）、铠甲狼卡诺斯（26／大杀四方 259）、守层者诺萨（109／炎鬼 616）
	for c in [[20, 19, 179], [26, 26, 259], [109, 112, 616]]:
		var got := {}
		for on in [true, false]:
			# on＝本单（敌方视角）；false＝基线：同样开着技能重构，只把这招的 T549 改写行拿掉（＝T549 之前敌人看到的记录）
			XTianqiSkills.ENABLED = true
			XTianqiSkills.reload_table()
			if not on:
				XTianqiSkills._skills.erase(c[2])
				XTianqiSkills._recs.clear()
			for i in 60:
				var seed := "%016x" % (5490 + i)
				for m in s.members():
					m.recover_all()
				var lg: XBattleLogic = h._make_dummy_battle(s, c[0], seed)
				var e: XEnemy = null
				for x in lg.enemies:
					if int(x.enemy_id) == c[1]:
						e = x
				if e == null:
					break
				var rec := XTianqiEnemyAI.enemy_action(lg, e)
				if int(rec.get("id", 0)) != c[2]:
					continue
				var tgt: XActor = lg.alive(lg.actors)[0]
				var dmg := 0.0
				for r in lg.act(e, rec, tgt):
					if r is Dictionary and r.get("type") == "hit" and is_same(r.get("user"), e):
						dmg += maxf(0.0, float(r.get("hp", 0.0)))
				if on:
					check("t549.foe.ai.%d.formula_original" % c[2], not str(rec.damage.formula).begins_with("XTianqiSkills.formula"), rec.damage.formula)
				got["%s:%s" % [on, seed]] = dmg
		var same := 0
		var n := 0
		for k in got:
			if str(k).begins_with("true:"):
				n += 1
				var k2 := "false:" + str(k).substr(5)
				if got.has(k2) and is_equal_approx(float(got[k]), float(got[k2])):
					same += 1
		check("t549.foe.ai.%d.picked" % c[2], n > 0, got)
		check("t549.foe.ai.%d.dmg_same_as_original" % c[2], n > 0 and same == n, got)
		# 修前行为（敌我同读改写记录）对照：伤害确实不一样，证明上面这条断言管得住
		XTianqiSkills.ENABLED = true
		XTianqiSkills.reload_table()
		XTianqiSkills.ACTOR_ONLY = false
		var diff := false
		for k in got:
			if not str(k).begins_with("true:"):
				continue
			for m in s.members():
				m.recover_all()
			var lg5: XBattleLogic = h._make_dummy_battle(s, c[0], str(k).substr(5))
			var e5: XEnemy = null
			for x in lg5.enemies:
				if int(x.enemy_id) == c[1]:
					e5 = x
			var rec5 := XTianqiEnemyAI.enemy_action(lg5, e5)
			if int(rec5.get("id", 0)) != c[2]:
				continue
			var tgt5: XActor = lg5.alive(lg5.actors)[0]
			var d5 := 0.0
			for r in lg5.act(e5, rec5, tgt5):
				if r is Dictionary and r.get("type") == "hit" and is_same(r.get("user"), e5):
					d5 += maxf(0.0, float(r.get("hp", 0.0)))
			if not is_equal_approx(d5, float(got[k])):
				diff = true
			break
		XTianqiSkills.ACTOR_ONLY = true
		check("t549.foe.ai.%d.prefix_differs" % c[2], diff, got)
	XTianqiSkills.ENABLED = true
	XTianqiSkills.reload_table()
	# 同一存档里我方装备者照样走改写：替换普攻、武器触发、装备授予主动
	# 我方用敌人共用的这些招（替换普攻 179／616／682／308、武器触发 259、装备授予 3650）：同一存档、同一场战斗里实打，走改写公式
	var mine_hit := []
	var a0 := _actor(s)
	for sid in [179, 616, 682, 308, 259, 3650]:
		a0.recover_all()
		a0.tp = 100
		a0.cooldowns.clear()
		var lg3: XBattleLogic = h._make_dummy_battle(s, 2, SEEDS[0])
		for r in lg3.act(a0, XDB.skill_for(a0, sid), lg3.enemies[0]):
			if r is Dictionary and r.get("type") == "hit" and int((r.get("skill", {}) as Dictionary).get("id", 0)) == sid:
				mine_hit.append([sid, str(r.skill.damage.formula)])
				break
	check("t549.mine.shared_ids_module_hit", mine_hit.size() == 6 and mine_hit.all(func(x): return str(x[1]) == "XTianqiSkills.formula(a,b,%d)" % int(x[0])), mine_hit)
	var a := _actor(s)
	h._equip_weapon(a, 393)
	a.refresh_passive()
	var un: Dictionary = {}
	for i in 30:
		var lg4: XBattleLogic = h._make_dummy_battle(s, 2, "%016x" % (7000 + i))
		var sk := lg4.weapon_unleash(a, XDB.rec("Skills", a.attack_skill_id()))
		if int(sk.get("id", 0)) == 259:
			un = sk
			break
	check("t549.mine.unleash_259", not un.is_empty() and str(un.damage.formula) == "XTianqiSkills.formula(a,b,259)", un.get("damage", {}).get("formula"))
	h._equip_weapon(a, 1613)
	a.refresh_passive()
	check("t549.mine.trait_3650", a.skills().any(func(x): return int(x.id) == 3650) and str(XDB.skill_for(a, 3650).damage.formula) == "XTianqiSkills.formula(a,b,3650)", XDB.skill_for(a, 3650).damage.formula)
	# 回退开关：ACTOR_ONLY 关掉时敌方视角也是改写记录（回到 T549 交付时的行为）
	XTianqiSkills.ACTOR_ONLY = false
	check("t549.foe.rollback", str(XDB.foe_skill(616).damage.formula) == "XTianqiSkills.formula(a,b,616)", XDB.foe_skill(616).damage.formula)
	XTianqiSkills.ACTOR_ONLY = true


func _test_cards() -> void:
	XTianqiSkills.ENABLED = true
	XTianqiSkills.reload_table()
	XState.current = h._make_tianqi([3, 1, 2, 4], 25)
	var bad := ["标准线", "折算", "物攻×1", "各×", "命中后，"]
	for sid in _actor_only_ids() + [995, 3549, 3624]:
		var sp := XTianqiSkills.spec(sid)
		var note := str(XDB.rec("Skills", sid).get("note", ""))
		var ok := true
		for line in sp.get("desc", []):
			if not note.contains("\\c[1]" + str(line)):
				ok = false
			for w in bad:
				if str(line).contains(w):
					ok = false
		check("t549.card.%d.desc" % sid, ok, sp.get("desc"))
		for key in sp.get("header", {}):
			check("t549.card.%d.header.%s" % [sid, key], note.contains("<pos=APs text=%s:%s " % [key, sp.header[key]]), sp.header)
		if note.contains("<pos=APs text=TP消耗:"):
			check("t549.card.%d.tp_header" % sid, note.contains("<pos=APs text=TP消耗:%s " % (str(int(sp.get("tp", 0))) if int(sp.get("tp", 0)) > 0 else "无")), sp.get("tp"))
	# 指名：嘤嘤嘤顶栏随机三次、龙马补满 TP、风语者自然之风、红牌变牌、武器触发写「有几率」、搏命不写折算
	check("t549.card.2797.target", str(XDB.rec("Skills", 2797).note).contains("<pos=APs text=对象:随机敌人3次 "), str(XDB.rec("Skills", 2797).note).left(400))
	check("t549.card.6240.tp", str(XTianqiSkills.spec(6240).desc).contains("补满 TP"), XTianqiSkills.spec(6240).desc)
	check("t549.card.861.state", str(XTianqiSkills.spec(861).desc).contains("「自然之风」"), XTianqiSkills.spec(861).desc)
	check("t549.card.3651.change", str(XTianqiSkills.spec(3651).desc).contains("20% 几率改为黄牌") and str(XTianqiSkills.spec(3651).desc).contains("另有 20% 几率改为蓝牌"), XTianqiSkills.spec(3651).desc)
	for sid in [127, 258, 259, 2802, 2806, 638]:
		check("t549.card.%d.unleash_wording" % sid, str(XTianqiSkills.spec(sid).desc[0]).begins_with("效果：普通攻击时有几率"), XTianqiSkills.spec(sid).desc)
	check("t549.card.3913.hp", str(XTianqiSkills.spec(3913).desc).contains("自身最大生命的 12%"), XTianqiSkills.spec(3913).desc)
	check("t549.card.3549.dual", str(XTianqiSkills.spec(3549).desc).contains("每段物理攻击×25%＋敏捷×25%，6 段合计物理攻击×150%＋敏捷×150%"), XTianqiSkills.spec(3549).desc)
	# 装备面板：skill_rework.gear 里 R1 的行，替换串都进了视图备注
	var n_gear := 0
	for key in XTianqiSkills.data().get("gear", {}):
		var row: Dictionary = XTianqiSkills.data().gear[key]
		if not str(row.get("_note", "")).begins_with("T549 R1"):
			continue
		n_gear += 1
		var kind := "weapon" if str(key).begins_with("weapon") else "armor"
		var item := XGear.template(kind, int(str(key).split(":")[1]))
		var raw := str(item.get("note", ""))
		var view := str(XTianqiGear.stat_list([item])[0].get("note", ""))
		var ok := view != raw
		for pr in row.note_sub:
			var rep := str(pr[1]).replace("${1}", "")
			if rep != "" and not view.contains(rep):
				ok = false
		check("t549.gearcard.%s" % key, ok, view.left(500))
	# gear_elem_amp 路：旧整行不在、新整行在
	var ea = JSON.parse_string(FileAccess.get_file_as_string("res://modes/xiyou/tianqi_data/gear_elem_amp.json"))
	var n_ea := 0
	for sec in ["weapons", "armors"]:
		for gid in ea.get(sec, {}):
			for pr in ea[sec][gid].get("subs", []):
				if not (pr.size() >= 3 and str(pr[2]) == "re"):
					continue
				n_ea += 1
				var item2 := XGear.template("weapon" if sec == "weapons" else "armor", int(gid))
				var view2 := str(XTianqiGear.stat_list([item2])[0].get("note", ""))
				var rep2 := str(pr[1]).replace("${1}", "")
				check("t549.gearcard.ea.%s.%s.%d" % [sec, gid, n_ea], RegEx.create_from_string("(?s)" + str(pr[0])).search(str(item2.get("note", ""))) != null and (rep2 == "" or view2.contains(rep2)), view2.left(500))
	check("t549.gearcard.count", n_gear + n_ea >= 100, [n_gear, n_ea])
	# 指名：决斗者、灵魂收割者、一粒尘旧说法不在
	for c in [[675, "敏捷高于对方则攻击3次"], [965, "5倍伤害"], [745, "提高3倍"], [1176, "666666"]]:
		var v := str(XTianqiGear.stat_list([XGear.template("weapon", c[0])])[0].get("note", ""))
		check("t549.gearcard.named.%d" % c[0], not v.contains(c[1]), v.left(400))
	check("t549.gearcard.1176_prefix", str(XTianqiGear.stat_list([XGear.template("weapon", 1176)])[0].note).contains("\\c[13]符石:破晓(普通攻击变为"), "")
	# 西游档：装备面板原样
	XState.current = h._make_xiyou([3])
	check("t549.gearcard.xiyou_raw", str(XTianqiGear.stat_list([XGear.template("weapon", 675)])[0].get("note", "")).contains("敏捷高于对方则攻击3次"), "")


## T549 R2（小o 核 P2-5／P2-6）：替换普攻保留原公式全部伤害属性、原权重；普通档每目标合计 1.0、招牌 1.5，全体不再减半；
## 凌厉长鞭（2602）打队友固定 100 点真实伤害（西游档仍是原公式）
func _total(sid: int) -> float:
	var d: Dictionary = XTianqiSkills.spec(sid).damage
	var w := 0.0
	for k in d.get("stats", {}):
		w += float(d.stats[k]) * (25.0 if str(k) == "mhp" else 1.0)
	if d.has("max_of"):
		w += 1.0
	var sk := XDB.rec("Skills", sid)
	var n := _expected_hits(sk, 1)  # 全体按每个目标算（scope 2 n_enemies＝1）
	return snappedf(w * float(d.coef) * n, 0.0001)


func _test_r2() -> void:
	XTianqiSkills.ENABLED = true
	XTianqiSkills.reload_table()
	XState.current = h._make_tianqi([3, 1, 2, 4], 25)
	# 赤羽：物攻、敏捷、幸运三项等权（原公式各 ×18）；尊胜法轮（法轮 4708）：物攻、魔攻、敏捷、幸运四项等权
	for c in [[3575, ["atk", "agi", "luk"]], [4708, ["atk", "mat", "agi", "luk"]]]:
		var st: Dictionary = XTianqiSkills.spec(c[0]).damage.stats
		var ks := st.keys()
		ks.sort()
		var want: Array = c[1].duplicate()
		want.sort()
		check("t549.r2.%d.all_stats" % c[0], ks == want and st.values().all(func(v): return float(v) == float(st.values()[0])), st)
	check("t549.r2.3575.card", str(XTianqiSkills.spec(3575).desc).contains("幸运") and str(XTianqiSkills.spec(3575).desc).contains("敏捷"), XTianqiSkills.spec(3575).desc)
	check("t549.r2.4708.card", str(XTianqiSkills.spec(4708).desc).contains("魔法攻击") and str(XTianqiSkills.spec(4708).desc).contains("敏捷") and str(XTianqiSkills.spec(4708).desc).contains("幸运"), XTianqiSkills.spec(4708).desc)
	# 原权重不等的照原比例：红牌幸运 25：物攻 10、潮汐斩魔攻 4：敏捷 2
	var rp: Dictionary = XTianqiSkills.spec(3651).damage.stats
	check("t549.r2.3651.ratio", rp.has("luk") and rp.has("atk") and absf(float(rp.luk) / float(rp.atk) - 2.5) < 0.15, rp)
	var cx: Dictionary = XTianqiSkills.spec(4444).damage.stats
	check("t549.r2.4444.ratio", absf(float(cx.mat) / float(cx.agi) - 2.0) < 0.1, cx)
	# 全体替换普攻普通档：彻地钉等 5 招每目标合计 1.0（不再 0.50）
	for sid in [494, 636, 658, 860, 1970]:
		check("t549.r2.%d.area_1_0" % sid, int(XDB.rec("Skills", sid).scope) == 2 and _total(sid) == 1.0, _total(sid))
		check("t549.r2.%d.card_no_half" % sid, not str(XTianqiSkills.spec(sid).desc).contains("×50%") and not str(XTianqiSkills.spec(sid).get("_note", "")).contains("全体减半"), XTianqiSkills.spec(sid).desc)
	# 所有替换普攻／武器触发：普通档合计 0.9～1.0、招牌 1.35～1.5（整数百分比向下取整，不超）
	for sid in _ids():
		var sp := XTianqiSkills.spec(sid)
		if str(sp.get("kind", "")) != "普攻" or not str(sp.get("_note", "")).contains("装备招批 2（替换普攻") or sid in [995, 1968]:
			continue
		var tt := _total(sid)
		check("t549.r2.%d.total" % sid, (tt >= 0.9 and tt <= 1.0) or (tt >= 1.35 and tt <= 1.5), tt)
	# 凌厉长鞭：天启篇打队友固定 100（三种子、暴击种子也一样），附加狂热斗志；西游档原公式不动
	for sd in SEEDS:
		var s: XState = h._make_tianqi([3, 1, 2, 4], 25)
		var a := _actor(s)
		var lg: XBattleLogic = h._make_dummy_battle(s, 2, sd)
		var ally: XActor = lg.actors[1] if lg.actors[0] == a else lg.actors[0]
		ally.recover_all()
		var hp0 := ally.hp
		lg.act(a, XDB.rec("Skills", 2602), ally)
		check("t549.r2.2602.ally_100.%s" % sd, hp0 - ally.hp == 100.0 and ally.is_state_affected(265), {"loss": hp0 - ally.hp, "hp0": hp0})
	check("t549.r2.2602.card", str(XTianqiSkills.spec(2602).desc[0]).contains("对一名队友造成 100 点真实伤害"), XTianqiSkills.spec(2602).desc)
	check("t549.r2.2602.gearcard", str(XTianqiGear.stat_list([XGear.template("weapon", 201)])[0].get("note", "")).contains("对一名队友造成 100 点真实伤害"), "")
	XTianqiSkills.FLAT_FINAL = false  # 回退开关：只在公式里给 100，结算倍率照吃（不再恰好 100）
	var s2: XState = h._make_tianqi([3, 1, 2, 4], 25)
	var a2 := _actor(s2)
	var lg2: XBattleLogic = h._make_dummy_battle(s2, 2, SEEDS[1])
	var al2: XActor = lg2.actors[1] if lg2.actors[0] == a2 else lg2.actors[0]
	al2.recover_all()
	var h2 := al2.hp
	lg2.act(a2, XDB.rec("Skills", 2602), al2)
	check("t549.r2.2602.flat_final_rollback", h2 - al2.hp != 100.0 and h2 - al2.hp > 0.0, h2 - al2.hp)
	XTianqiSkills.FLAT_FINAL = true
	XTianqiSkills.ENABLED = false
	XTianqiSkills.reload_table()
	check("t549.r2.2602.xiyou_raw", str(XDB.rec("Skills", 2602).damage.formula) == "100000+a.atk*1000", XDB.rec("Skills", 2602).damage.formula)
	XTianqiSkills.ENABLED = true
	XTianqiSkills.reload_table()


func _run() -> void:
	h = T541.new()
	var was_en := XTianqiSkills.ENABLED
	var was_force := XEnemy.force_roll
	var was_auto := XMessageBox.auto
	XEnemy.force_roll = 100.0
	XMessageBox.auto = true
	if OS.get_environment("T549_QUICK") != "1":  # 本地调试新断言时跳过逐招三种子对照（约 10 分钟）
		_test_rows()
	_test_995()
	_test_3647()
	_test_skill_pass()
	_test_support()
	_test_foe()
	_test_cards()
	_test_r2()
	XTianqiSkills.ENABLED = was_en
	XTianqiSkills.reload_table()
	XEnemy.force_roll = was_force
	XMessageBox.auto = was_auto
	XState.current = null
	h.free()
	print("TEST_RESULT=" + JSON.stringify({"test": "xiyou_t549_gear_skills", "passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
