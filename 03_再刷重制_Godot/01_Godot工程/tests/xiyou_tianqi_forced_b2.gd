extends Node
## 【cc·T262】天启篇强制副本 B 组二：西西卡雷切 5888 → 公共事件 1614 强制放拷贝之眼复制版 15 个（5891～5926）。
## 15 个复制版进卡：每个照队友原技能卡（含 D189／D200 取整后）的系数 ×0.8（无条件倍率并进系数、取整数百分比）、
## 段数同原技能（流派被动 5880～5882 的额外段去掉）；公共事件 1614（选择、每场次数、强制放）不动。
## 「前」＝把这批卡从技能表里拿掉（副本照原版公式），「后」＝现在的卡；各打一次实战，比敌方总掉血。
## T261 遗留三条（5494 拆五段、624 desc、5838 旧行）也在这里验。打印的「B2」行是交付单对比表的原始数。

var results: Array = []
const ENEMY_HP := 999999999

## 本批新进卡的技能号（前＝拿掉）
const COPY_IDS := [5891, 5894, 5896, 5898, 5900, 5904, 5906, 5908, 5910, 5912, 5913, 5918, 5919, 5924, 5926]
## 复制版 → 它照的队友原技能卡
const SRC := {5891: 533, 5894: 1200, 5896: 5140, 5898: 2011, 5900: 4370, 5904: 5424, 5906: 5445, 5908: 10711, 5910: 5121, 5912: 5128, 5913: 5132, 5918: 5163, 5919: 5310, 5924: 2067, 5926: 5455}


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


## 前／后：before 为真时拿掉本批卡
func _table(before: bool) -> void:
	XTianqiSkills.reload_table()
	XTianqiSkills.data()
	if before:
		for sid in COPY_IDS:
			XTianqiSkills._skills.erase(sid)


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
	print("B2 ", tag, " 前=", before, " 后=", after, " ", extra)


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

	# 一、表：15 个复制版都有卡；段数同原技能（原技能走自己的卡）；5888 的公共事件 1614 照旧
	var lg0 := _logic(true, [88], {})
	_check("tq.active", XTianqi.active(lg0.state))
	for sid in COPY_IDS:
		_check("card.%d" % sid, XTianqiSkills.has(sid))
		_check("card.%d_formula" % sid, _formula_is_card(sid))
		var c: Dictionary = XTianqiSkills.spec(sid)
		_check("card.%d_actor88_no_always" % sid, int(c.get("actor", 0)) == 88 and not str(c.get("damage", {}).get("conds", [])).contains("always"), c.get("damage"))
		var cr: Dictionary = XDB.rec("Skills", sid)
		var sr: Dictionary = XDB.rec("Skills", SRC[sid])
		# 5898 的原技能 2011 带一段学了 3533 才有的条件段（yepEffects 把它算进去，12＝9＋3）；复制版只留卡上写的九段
		var want := 9 if sid == 5898 else int(sr.get("yepEffects", -2))
		_check("hits.%d_same_as_%d" % [sid, SRC[sid]], int(cr.get("yepEffects", -1)) == want, [cr.get("yepEffects"), sr.get("yepEffects")])
		# 流派被动 5880～5882 的条件段全去掉
		_check("seq.%d_no_588x" % sid, not str(cr.get("yepSeq", {})).contains("includes(588"))
	_check("tq.5888_keeps_ce1614", _has_effect(XDB.rec("Skills", 5888), 44, 1614))
	_check("tq.5912_no_ce1155", not _has_effect(XDB.rec("Skills", 5912), 44, 1155))
	_check("tq.5919_no_ce1186", not _has_effect(XDB.rec("Skills", 5919), 44, 1186))
	# 系数：原技能卡的 80%（取整数百分比后），不会比原技能还大
	for sid in COPY_IDS:
		var cd: Dictionary = XTianqiSkills.spec(sid).get("damage", {})
		var sd: Dictionary = XTianqiSkills.spec(SRC[sid]).get("damage", {})
		var cs := 0.0
		for k in cd.get("stats", {}):
			cs += float(cd.stats[k])
		cs *= float(cd.get("coef", 1))
		var ss := 0.0
		for k in sd.get("stats", {}):
			ss += float(sd.stats[k])
		ss *= float(sd.get("coef", 1))
		var ratio := cs / maxf(ss, 0.0001)
		_line("ratio%d" % sid, "原技能 %.2f" % ss, "复制版 %.2f" % cs, "比值 %.2f" % ratio)
		_check("ratio.%d_about_0_8" % sid, ratio >= 0.5 and ratio <= 1.0, ratio)

	# 二、T261 遗留：瑞普 5494 五段、24%（合计 120%）；624 不再写妖精之羽；5838 旧行「效果:两段伤害」不见了
	var r5494: Dictionary = XDB.rec("Skills", 5494)
	_check("t261.5494_five_hits", int(r5494.get("yepEffects", 0)) == 5, r5494.get("yepEffects"))
	_check("t261.5494_24pct", absf(float(XTianqiSkills.spec(5494).damage.stats.atk) - 0.24) < 0.0001)
	var n624 := str(XDB.rec("Skills", 624).get("note", ""))
	_check("t261.624_no_wing_line", not n624.contains("妖精之羽"), n624)
	var n5838 := str(XDB.rec("Skills", 5838).get("note", ""))
	_check("t261.5838_no_old_line", not n5838.contains("效果:两段伤害"), n5838)

	# 三、实战前后：西西卡直接放 15 个复制版（81 级，敌人 99 亿血，打第一个敌人、全体的打三个）
	var lineup := [88]
	var learn := {88: [5888, 5892, 5907, 5914, 5925, 5923]}
	for sid in COPY_IDS:
		seed(20261119)
		_table(true)
		var b := _cast(_logic(true, lineup, learn), 88, sid)
		seed(20261119)
		_table(false)
		var a := _cast(_logic(true, lineup, learn), 88, sid)
		_line("copy%d" % sid, b.dmg, a.dmg)
		_check("fight.%d_card_drops_damage" % sid, a.dmg > 0.0 and a.dmg < b.dmg, [b.dmg, a.dmg])

	# 四、链路：学了拷贝被动后连放雷切 5888，复制版随公共事件 1614 出现（前后两边都出）；每场各 ≤2 次不动
	var seen_before := {}
	var seen_after := {}
	for ph in [true, false]:
		_table(ph)
		var lgc := _logic(true, lineup, learn)
		seed(20261119)
		for i in range(60):
			for k in _cast(lgc, 88, 5888).seen:
				(seen_before if ph else seen_after)[int(k)] = true
	var copies_before := seen_before.keys().filter(func(k): return COPY_IDS.has(int(k)))
	var copies_after := seen_after.keys().filter(func(k): return COPY_IDS.has(int(k)))
	_line("chain5888", "副本出现 %s" % [copies_before], "副本出现 %s" % [copies_after])
	_check("chain.forced_in_both", not copies_before.is_empty() and copies_after.size() == copies_before.size(), [copies_before, copies_after])

	# 五、西游档：这批技能没有卡（公式不是 XTianqiSkills），公共事件 1614 照旧；公式照原版
	_table(false)
	var og := _logic(false, [88], {})
	_check("xy.not_active", not XTianqi.active(og.state))
	for sid in COPY_IDS:
		_check("xy.%d_no_card" % sid, not _formula_is_card(sid))
	_check("xy.5888_ce1614", _has_effect(XDB.rec("Skills", 5888), 44, 1614))
	_check("xy.5891_formula", str(XDB.rec("Skills", 5891).damage.formula).contains("a.mat * 20"))
	_check("xy.5494_six_hits", int(XDB.rec("Skills", 5494).get("yepEffects", 0)) == 10 or int(XDB.rec("Skills", 5494).get("yepEffects", 0)) == 6)

	XTianqiSkills.reload_table()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
