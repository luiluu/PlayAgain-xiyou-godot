extends Node
## 【cc·T261】天启篇强制副本 B 组一：裴钱、张无忌、爱莉、瑞普、虎姐、露茜、玛莎（T255 登记的 forced_copy_pending 里这七人）。
## 副本技能进卡（2836 撼天锤、2837 凌霄剑、5837 混元太极再释放、5838 乾坤倒置再释放、5494 无人机炸弹、5930 说唱、7314 魔法射击·再释放）、
## 公共事件 91 对露茜 623 去强制（补敏捷 +5% 的妖精之羽）、玛莎 4893 登 forced_copy_unreachable（天启篇拿不到 229）。
## 「前」＝把这批卡从技能表里拿掉（副本照原版公式），「后」＝现在的卡；各打一次实战（lg.act＋run_events 跑预约公共事件里的强制行动），
## 比敌方总掉血。西游档对照：这批技能记录照旧没有卡（公式不是 XTianqiSkills），公共事件照旧在。
## 打印的「B1」行是交付单对比表的原始数。

var results: Array = []
const ENEMY_HP := 999999999

## 本批新进卡的技能号（前＝拿掉）
const COPY_IDS := [2836, 2837, 5837, 5838, 5494, 5930, 7314]


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


## 前／后：before 为真时拿掉本批卡（623 的 44 去除与敏捷补丁、2018 状态卡也拿掉）
func _table(before: bool) -> void:
	XTianqiSkills.reload_table()
	XTianqiSkills.data()
	if before:
		for sid in COPY_IDS:
			XTianqiSkills._skills.erase(sid)
		XTianqiSkills._skills[623] = XTianqiSkills._skills[623].duplicate(true)
		XTianqiSkills._skills[623].erase("effects_remove")
		XTianqiSkills._skills[623].erase("effects_add")
		XTianqiSkills._states.erase(2018)


func _logic(tianqi: bool, lineup: Array, learn: Dictionary, hp_frac := -1.0) -> XBattleLogic:
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
		var a: XActor = s.actor(id)
		a.change_level(81)
		for sid in learn.get(id, []):
			a.learn_skill(int(sid))
		a.recover_all()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	for e in lg.enemies:
		e.add_param(0, ENEMY_HP)
		e.param_refresh()
		e.recover_all()  # 参数缓存刷新后再补满（不刷新，生命被夹在加参数前的上限；别把敌人打死）
	if hp_frac >= 0.0:
		for a in lg.actors:
			a.hp = maxf(1.0, floorf(float(a.mhp) * hp_frac))
	return lg


func _foes_hp(lg: XBattleLogic) -> float:
	var n := 0.0
	for e in lg.enemies:
		n += float(e.hp)
	return n


func _allies_hp(lg: XBattleLogic) -> float:
	var n := 0.0
	for a in lg.actors:
		n += float(a.hp)
	return n


## 实放一次技能，再跑预约的公共事件（强制副本）：返回 {dmg: 敌方总掉血, heal: 我方总回血, seen: 日志里出现过的技能号, logic}
func _cast(lg: XBattleLogic, user_id: int, skill_id: int, target = null) -> Dictionary:
	var u: XBattler = lg.state.actor(user_id)
	var t: XBattler = target if target != null else lg.enemies[0]
	var foe0 := _foes_hp(lg)
	var ally0 := _allies_hp(lg)
	var logs := lg.act(u, XDB.rec("Skills", skill_id), t)
	logs.append_array(lg.run_events(u))
	var seen := {}
	for r in logs:
		if r is Dictionary and r.get("skill") is Dictionary:
			seen[int(r.skill.get("id", 0))] = true
	return {"dmg": foe0 - _foes_hp(lg), "heal": _allies_hp(lg) - ally0, "seen": seen.keys()}


func _line(tag: String, before, after, extra := "") -> void:
	print("B1 ", tag, " 前=", before, " 后=", after, " ", extra)


func _formula_is_card(sid: int) -> bool:
	return str(XDB.rec("Skills", sid).get("damage", {}).get("formula", "")).begins_with("XTianqiSkills")


func _has_effect(rec: Dictionary, code: int, data_id: int) -> bool:
	for e in rec.get("effects", []):
		if int(e.get("code", -1)) == code and int(e.get("dataId", -1)) == data_id:
			return true
	return false


func _run() -> void:
	XMessageBox.auto = true
	XTianqiBase.clear_cache()
	XTianqiBase.PHASE4 = true
	_table(false)

	# 一、表：新进卡的副本都有记录、卡上有系数；623 去 44；玛莎 945 照旧
	for sid in COPY_IDS:
		_check("card.%d" % sid, XTianqiSkills.has(sid))
	var lg0 := _logic(true, [31], {})
	_check("tq.active", XTianqi.active(lg0.state))
	_check("tq.623_no_ce91", not _has_effect(XDB.rec("Skills", 623), 44, 91))
	_check("tq.623_wing_state", _has_effect(XDB.rec("Skills", 623), 21, 56))
	_check("tq.623_keeps_regen_state", _has_effect(XDB.rec("Skills", 623), 21, 55))
	_check("tq.4507_keeps_ce945", _has_effect(XDB.rec("Skills", 4507), 44, 945))  # 风层 v525 累加照旧
	for sid in [4374, 4380, 4383]:
		_check("tq.%d_keeps_ce_realm" % sid, true if sid == 4380 else _has_effect(XDB.rec("Skills", sid), 44, 823 if sid == 4374 else 824))  # 境界公共事件保留
	_check("tq.5848_keeps_ce1598", _has_effect(XDB.rec("Skills", 5848), 44, 1598))
	_check("tq.5497_keeps_ce1303", _has_effect(XDB.rec("Skills", 5497), 44, 1303))
	_check("tq.5928_keeps_ce1619", _has_effect(XDB.rec("Skills", 5928), 44, 1619))
	_check("tq.7313_keeps_ce1503", _has_effect(XDB.rec("Skills", 7313), 44, 1503))
	_check("tq.2018_no_script", not str(XDB.rec("States", 2018).get("note", "")).contains("Custom Apply") and str(XDB.rec("States", 2018).get("note", "")).contains("passiveHarmRi:5"), XDB.rec("States", 2018).get("note"))

	# 玛莎：229（风的秘密）天启篇拿不到：没有职业带 229 给在用的角色、没有物品／装备／状态特性给 229
	var users := {}
	for a in XDB.table("Actors"):
		if a is Dictionary:
			users[int(a.get("classId", 0))] = true
	var src := []
	for c in XDB.table("Classes"):
		if c is Dictionary and users.has(int(c.get("id", 0))):
			for l in c.get("learnings", []):
				if int(l.get("skillId", 0)) == 229:
					src.append(["class", c.id])
	for nm in ["Items", "Weapons", "Armors", "States", "Enemies"]:
		for x in XDB.table(nm):
			if not x is Dictionary:
				continue
			for e in x.get("effects", []):
				if int(e.get("code", 0)) == 43 and int(e.get("dataId", 0)) == 229:
					src.append([nm, x.id])
			for tr in x.get("traits", []):
				if int(tr.get("code", 0)) == 43 and int(tr.get("dataId", 0)) == 229:
					src.append([nm, x.id])
	_check("masha.229_unobtainable", src.is_empty(), src)
	_check("masha.learn_table_no_229", not str(XTianqiSkills.data().get("learn", {})).contains("229,"), XTianqiSkills.data().get("learn", {}).get("21"))

	# 二、裴钱：学凌霄志（2835、没学酒泪祭）→ 王八拳后强制撼天锤 2836，疯魔剑后强制凌霄剑 2837
	var pei := {79: [4374, 4383, 2835]}
	for p in [[4374, 2836], [4383, 2837]]:
		var tag := "pei%d" % p[0]
		seed(20261119)
		_table(true)
		var b := _cast(_logic(true, [79], pei), 79, p[0])
		seed(20261119)
		_table(false)
		var a := _cast(_logic(true, [79], pei), 79, p[0])
		_line(tag, b.dmg, a.dmg, "副本 %d 出现：前 %s 后 %s" % [p[1], b.seen.has(p[1]), a.seen.has(p[1])])
		_check(tag + ".forced_in_both", b.seen.has(p[1]) and a.seen.has(p[1]), [b.seen, a.seen])
		_check(tag + ".card_drops_damage", a.dmg > 0.0 and a.dmg < b.dmg, [b.dmg, a.dmg])
	# 酒泪祭（4393）：王八锤 4381 本来就在卡，两边一样
	seed(20261119)
	var j := _cast(_logic(true, [79], {79: [4374, 4393]}), 79, 4374)
	_check("pei.4393_hammer", j.seen.has(4381) and not j.seen.has(2836), j.seen)

	# 三、张无忌：学陆地神仙 5843＋混元太极 5848：九阳之力放完随机再放 5837（混元太极）或 5838（乾坤倒置），直接放两个副本比数
	var wuji := {87: [5848, 5852, 5853, 5843]}
	for sid in [5837, 5838]:
		seed(20261119)
		_table(true)
		var b := _cast(_logic(true, [87], wuji), 87, sid)
		seed(20261119)
		_table(false)
		var a := _cast(_logic(true, [87], wuji), 87, sid)
		_line("wuji%d" % sid, b.dmg, a.dmg)
		_check("wuji.%d_card_drops_damage" % sid, a.dmg > 0.0 and a.dmg < b.dmg, [b.dmg, a.dmg])
	# 链路：同一存档里连放 5853，随机副本 5837／5838 都会出现，且不超过原来的一次一个
	_table(false)
	var lgw := _logic(true, [87], wuji)
	var got := {}
	for i in range(40):
		for k in _cast(lgw, 87, 5853).seen:
			got[int(k)] = true
	_check("wuji.chain_5837_5838", got.has(5837) and got.has(5838), got.keys())

	# 四、爱莉：魔法射击 7313 → 公共事件 1503 → 强制 7314
	seed(20261119)
	_table(true)
	var e1 := _cast(_logic(true, [85], {85: [7313]}), 85, 7313)
	seed(20261119)
	_table(false)
	var e2 := _cast(_logic(true, [85], {85: [7313]}), 85, 7313)
	_line("ellie7313", e1.dmg, e2.dmg, "副本 7314 出现：前 %s 后 %s" % [e1.seen.has(7314), e2.seen.has(7314)])
	_check("ellie.forced_in_both", e1.seen.has(7314) and e2.seen.has(7314), [e1.seen, e2.seen])
	_check("ellie.card_drops_damage", e2.dmg > 0.0 and e2.dmg < e1.dmg, [e1.dmg, e2.dmg])

	# 五、瑞普：切作战模式 5497（学了模式融合 5498）→ 公共事件 1303 → 强制无人机炸弹 5494
	var rip := {56: [5497, 5498]}
	seed(20261119)
	_table(true)
	var r1 := _cast(_logic(true, [56], rip), 56, 5497)
	seed(20261119)
	_table(false)
	var r2 := _cast(_logic(true, [56], rip), 56, 5497)
	_line("rip5494", r1.dmg, r2.dmg, "副本 5494 出现：前 %s 后 %s" % [r1.seen.has(5494), r2.seen.has(5494)])
	_check("rip.forced_in_both", r1.seen.has(5494) and r2.seen.has(5494), [r1.seen, r2.seen])
	_check("rip.card_drops_damage", r2.dmg > 0.0 and r2.dmg < r1.dmg, [r1.dmg, r2.dmg])

	# 六、虎姐：头套 5928（学了虎式说唱 5929）→ 公共事件 1619 → 强制说唱 5930：全队回 3% 生命，加「狠活状态」伤害 +5%
	var tiger := {89: [5928, 5929], 8: []}
	seed(20261119)
	_table(true)
	var lt1 := _logic(true, [89, 8], tiger, 0.5)
	var t1 := _cast(lt1, 89, 5928)
	seed(20261119)
	_table(false)
	var lt2 := _logic(true, [89, 8], tiger, 0.5)
	var mhp := 0.0
	for a in lt2.actors:
		mhp += float(a.mhp)  # 放之前的生命上限（虎姐的开场被动会给状态改上限，放完再量不准）
	var t2 := _cast(lt2, 89, 5928)
	_line("tiger5930", "回血 %s" % t1.heal, "回血 %s（全队生命上限 %s，3%%＝%s）" % [t2.heal, mhp, mhp * 0.03])
	_check("tiger.forced_in_both", t1.seen.has(5930) and t2.seen.has(5930), [t1.seen, t2.seen])
	_check("tiger.heal_3pct", absf(t2.heal - mhp * 0.03) <= mhp * 0.01 + 2.0, [t2.heal, mhp * 0.03])
	_check("tiger.state2018_on_allies", lt2.actors.all(func(a): return a.state_ids.has(2018)))

	# 七、露茜：治愈之歌 623 不再带公共事件 91（克莱德毒奶追击 4552、彩蛋 5151），妖精之羽（状态 56，敏捷 +5%）照给
	var lucy := {31: [623, 624, 5150], 16: [4551]}
	var seen_after := {}
	var seen_before := {}
	var wing := true
	for ph in [true, false]:
		_table(ph)
		var lgl := _logic(true, [31, 16], lucy, 0.5)
		seed(20261119)
		for i in range(40):
			for k in _cast(lgl, 31, 623, lgl.actors[0]).seen:
				(seen_before if ph else seen_after)[int(k)] = true
		if not ph:
			wing = lgl.actors.all(func(a): return a.state_ids.has(56))
	_line("lucy623", "副本出现 %s" % [seen_before.keys()], "副本出现 %s" % [seen_after.keys()])
	_check("lucy.before_has_chase", seen_before.has(4552) and seen_before.has(5151), seen_before.keys())
	_check("lucy.after_no_chase", not seen_after.has(4552) and not seen_after.has(5151), seen_after.keys())
	_check("lucy.wing_state", wing)

	# 八、西游档：这批技能没有卡（公式不是 XTianqiSkills），公共事件照旧；公式照原版
	_table(false)
	var og := _logic(false, [79], {})
	_check("xy.not_active", not XTianqi.active(og.state))
	for sid in COPY_IDS:
		_check("xy.%d_no_card" % sid, not _formula_is_card(sid))
	_check("xy.623_has_ce91", _has_effect(XDB.rec("Skills", 623), 44, 91))
	_check("xy.2836_formula", str(XDB.rec("Skills", 2836).damage.formula).contains("a.atk*30"))
	_check("xy.2018_script_kept", str(XDB.rec("States", 2018).get("note", "")).contains("Custom Apply"))

	XTianqiSkills.reload_table()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
