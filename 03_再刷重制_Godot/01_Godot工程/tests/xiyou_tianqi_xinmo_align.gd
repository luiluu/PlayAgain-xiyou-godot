extends Node
## 【cc·T315】天启篇心魔对齐同层守层者（XGuardianRework.XINMO，D244 甲；Kyo 11-20「甲，不同境界的心魔也要有自己的特点」）：
## 〇、r2：只认闭关开的心魔试炼（25 层 Map147 的 770、公共事件 1600 的 901 照旧）；暴击闪避也清；回血招不借；幻化 zq_ref 清掉。
## 一、通关 10 层，2 号打心魔（敌群 901）：记录借第 10 层守层者（_ref xinmo、_xinmo_floor 10），名字照心魔；血量、双防、出伤倍率、
##     暴击闪避跟同队打第 10 层守层者那只一样；行动表＝守层者的滤掉成长／领域／放逐／高额吸血，没有心魔原招 4118～4121、4239、3823；
##     特性里没有正的闪避、魔闪、每回合回血；敌群页去掉，打 3 回合也不强制 6104（生命上限不涨）。
## 二、1 号打心魔（敌群 770）：第 1 回合不开霸者领域（CE1397／6068 全能力强化），不放逐（状态 264），打 3 回合不茁壮。
## 三、通关 25 层：伤害抵抗＝RESIST_TABLE[25]（跟守层者同），不是 1 亿；通关 5 层：没有伤害抵抗（1～18 层没有 5000 万护盾）。
## 四、通关 31 层：双防跟 31 层守层者（吃 guardian_params.json 重锚）一样。
## 五、开战顺序：守层者重算（XGuardianRework.setup）在幻化之前，心魔战在那里跳过、幻化后由 xinmo_setup 重标（血量不是原版天文数）。
## 六、回退开关关掉：心魔照原版记录（3823、原版天文血量）、敌群页照旧；西游档不动。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	MVInterpreter.fixed_random = 0.5
	XEnemy.force_roll = 100.0
	seed(20261120)
	var was := XGuardianRework.XINMO
	_check("default_on", XGuardianRework.XINMO)
	_f10()
	_f770()
	_resist()
	_f31()
	_skip()
	_heal()
	_floor_map()
	_non_trial()
	_rollback()
	_xiyou()
	XGuardianRework.xinmo_traits(null, null)  # 各境特点钩子在（空实现）
	XGuardianRework.XINMO = was
	XEnemy.force_roll = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _state(passed_floor: int, tianqi := true) -> XState:
	var lineup := [1, 2, 8, 9, 10]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, "jianxian", lineup)
		XTianqi.take_pending()
		for id in lineup:
			XTianqi._joining = true
			s.add_actor(int(id))
			XTianqi._joining = false
	else:
		s = XState.new_game(3, 1, [2, 8, 9, 10])
	s.map_id = 4
	s.set_variable(20, passed_floor + 1)
	XState.current = s
	return s


## 按 XZhenqi._brand_trial 开心魔战
func _xinmo(passed_floor: int, actor_id := 2, tianqi := true) -> XBattleLogic:
	var s := _state(passed_floor, tianqi)
	var troop := int(XZhenqi.HEART_TROOP.get(actor_id, 0))
	if troop == 0:
		troop = int(XZhenqi.TRIAL_TROOP["心魔"])
	XZhenqi.pending_trial = {"actorId": actor_id, "target": 1, "ref": XZhenqi.trial_ref(s, 1), "kind": "心魔", "troopId": troop, "brand": true}
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	return logic


func _guardian(f: int) -> XEnemy:
	var s := _state(f)
	var logic := XBattleLogic.new()
	logic.setup(int(XGuardianRework.TROOPS[f]), s)
	for e in logic.enemies:
		if XGuardianRework.floor_of(e.enemy_id) == f:
			return e
	return null


func _turns(logic: XBattleLogic, n: int) -> void:
	_drain(logic)
	for _i in n:
		var cmds := {}
		for a in logic.actors:
			cmds[a] = [XDB.rec("Skills", 1), logic.enemies[0]]
		logic.run_turn(cmds)
		_drain(logic)
		if logic.is_over():
			return


func _drain(logic: XBattleLogic) -> void:
	var guard := 0
	while logic.is_event_waiting() and guard < 50:
		guard += 1
		logic.resume_event(0, 0)


func _ids(e: XEnemy) -> Array:
	return e.data().get("actions", []).map(func(a): return int(a.skillId))


func _xparam_pos(e: XEnemy, ids: Array) -> bool:
	return e.data().get("traits", []).any(func(t): return int(t.code) == 22 and ids.has(int(t.dataId)) and float(t.value) > 0.0)


func _f10() -> void:
	# 先开守层者对照，再开心魔：开战会换掉 XZhenqi.battle（游戏里同一时间只有一场）
	var g := _guardian(10)
	var lgg := XBattleLogic.new()
	lgg.setup(int(XGuardianRework.TROOPS[10]), _state(10))
	var gg: XEnemy = lgg.enemies.filter(func(x): return XGuardianRework.floor_of(x.enemy_id) == 10)[0]
	var lg := _xinmo(10)
	var e: XEnemy = lg.enemies[0]
	_check("f10.troop", int(lg.troop_id) == 901 and XGuardianRework.xinmo_on(lg), lg.troop_id)
	_check("f10.rec", XGuardianRework.xinmo_floor(e) == 10 and str(e.data().get("name", "")) == "心魔" and int(e.data().get("_xinmo_guardian", 0)) == 72, [XGuardianRework.xinmo_floor(e), e.data().get("name"), e.data().get("_xinmo_guardian")])
	_check("f10.hp_eq_guardian", g != null and is_equal_approx(float(e.mhp), float(g.mhp)), [e.mhp, g.mhp if g else -1])
	_check("f10.hp_not_huge", float(e.mhp) < 1.0e8, e.mhp)
	_check("f10.def_eq", g != null and int(e.param(3)) == int(g.param(3)) and int(e.param(5)) == int(g.param(5)), [e.param(3), e.param(5), g.param(3) if g else -1])
	_check("f10.atk_eq", g != null and int(e.param(2)) == int(g.param(2)) and int(e.param(4)) == int(g.param(4)), [e.param(2), g.param(2) if g else -1])
	_check("f10.output_eq", g != null and is_equal_approx(e.output_scale, g.output_scale) and is_equal_approx(e.output_scale, float(XTianqiBase.guardian_table("atk_scale", XGuardianRework.ATK_SCALE).get(10, XGuardianRework.ATK_SCALE[10]))), [e.output_scale, g.output_scale if g else -1])
	_check("f10.no_cev", not _xparam_pos(e, [3]) and e.xparam(3) <= 0.0 and g != null and g.xparam(3) > 0.0, [e.xparam(3), g.xparam(3) if g else -1])
	_check("f10.zq_ref_cleared", e.zq_ref.is_empty() and e.zq_trial_loot, e.zq_ref)
	var ids := _ids(e)
	var want := _ids(g).filter(func(id): return not XGuardianRework.XINMO_SKIP_SKILLS.has(id) and not XGuardianRework.DOMAIN_SKILLS.has(id)) if g else []
	_check("f10.actions_from_guardian", ids == want and not ids.is_empty(), [ids, want])
	_check("f10.no_xinmo_skills", not ids.any(func(id): return [3823, 4118, 4119, 4120, 4121, 4239].has(id)), ids)
	_check("f10.no_evasion_regen", not _xparam_pos(e, [1, 3, 4, 7]) and e.xparam(1) <= 0.0 and e.xparam(4) <= 0.0 and e.xparam(7) <= 0.0, [e.xparam(1), e.xparam(4), e.xparam(7)])
	_check("f10.no_harm_re", (e.passive_cache().harmRe as Dictionary).values().all(func(v): return float(v) < 1.0e6), e.passive_cache().harmRe)
	_check("f10.boss_like_guardian", g != null and e.boss_difficulty_boss == g.boss_difficulty_boss, [e.boss_difficulty_boss, g.boss_difficulty_boss if g else null])
	_check("f10.sear_tier_eq_guardian", XTianqiBrand.enemy_tier(lg, e) == XTianqiBrand.enemy_tier(lgg, gg) and XTianqiBrand.sear_per_hit(lg, e) == XTianqiBrand.sear_per_hit(lgg, gg), [XTianqiBrand.enemy_tier(lg, e), XTianqiBrand.enemy_tier(lgg, gg), XTianqiBrand.sear_per_hit(lg, e)])
	_check("f10.pages_off", (XDB.rec("Troops", 901).get("pages", []) as Array).is_empty())
	var mhp0 := float(e.mhp)
	_turns(lg, 3)
	_check("f10.no_growth_t3", e.buffs[0] <= 0 and float(e.mhp) <= mhp0, [e.buffs, e.mhp, mhp0])


func _f770() -> void:
	var lg := _xinmo(10, 1)
	var e: XEnemy = lg.enemies[0]
	_check("f770.troop", int(lg.troop_id) == 770 and XGuardianRework.xinmo_floor(e) == 10 and str(e.data().get("name", "")) == "狗逍遥·心魔", [lg.troop_id, e.data().get("name")])
	_check("f770.pages_off", (XDB.rec("Troops", 770).get("pages", []) as Array).is_empty())
	_turns(lg, 3)
	var buffs := range(8).map(func(i): return e.buffs[i])
	_check("f770.no_domain_buff", buffs.all(func(b): return int(b) <= 0), buffs)
	_check("f770.no_banish", not lg.actors.any(func(a): return a.is_state_affected(264)))


func _resist() -> void:
	var lg := _xinmo(25)
	var e: XEnemy = lg.enemies[0]
	var g := _guardian(25)
	var want := float(XTianqiBase.guardian_table("resist", XGuardianRework.RESIST_TABLE).get(25, XGuardianRework.RESIST_TABLE[25]))
	var hr: Dictionary = e.passive_cache().harmRe
	_check("f25.resist_table", not hr.is_empty() and hr.values().all(func(v): return is_equal_approx(float(v), want)), [hr, want])
	_check("f25.resist_eq_guardian", g != null and hr == g.passive_cache().harmRe, [hr, g.passive_cache().harmRe if g else null])
	_check("f25.hp_eq_guardian", g != null and is_equal_approx(float(e.mhp), float(g.mhp)), [e.mhp, g.mhp if g else -1])
	var lg5 := _xinmo(5)
	var e5: XEnemy = lg5.enemies[0]
	_check("f5.no_shield", (e5.passive_cache().harmRe as Dictionary).values().all(func(v): return float(v) < 1.0e6), e5.passive_cache().harmRe)
	_check("f5.floor", XGuardianRework.xinmo_floor(e5) == 5 and is_equal_approx(e5.output_scale, float(XTianqiBase.guardian_table("atk_scale", XGuardianRework.ATK_SCALE).get(5, XGuardianRework.ATK_SCALE[5]))), [XGuardianRework.xinmo_floor(e5), e5.output_scale])


func _f31() -> void:
	var lg := _xinmo(31)
	var e: XEnemy = lg.enemies[0]
	var g := _guardian(31)
	_check("f31.floor", XGuardianRework.xinmo_floor(e) == 31 and XGuardianRework.params_floor(e) == 31)
	_check("f31.def_eq_rescaled", g != null and int(e.param(3)) == int(g.param(3)) and int(e.param(5)) == int(g.param(5)), [e.param(3), e.param(5), g.param(3) if g else -1, g.param(5) if g else -1])
	_check("f31.def_rescaled", int(e.param(3)) < int(XDB.rec("Enemies", 535).params[3]) * 2, [e.param(3), XDB.rec("Enemies", 535).params[3]])
	_check("f31.hp_eq_guardian", g != null and is_equal_approx(float(e.mhp), float(g.mhp)), [e.mhp, g.mhp if g else -1])


## 滤招：18 层守层者带放逐 2599、吞魂术 915（吸血 10000%）不借；合成记录直接滤成长 6104、领域 6068，滤空补「攻击」
func _skip() -> void:
	var lg := _xinmo(18)
	var ids := _ids(lg.enemies[0])
	_check("f18.no_banish_lifesteal", not ids.has(2599) and not ids.has(915) and ids.has(907), ids)
	var g := {"id": 72, "params": [1, 1, 1, 1, 1, 1, 1, 1], "traits": [], "actions": [{"skillId": 6104, "rating": 5, "conditionType": 0}, {"skillId": 6068, "rating": 5, "conditionType": 0}, {"skillId": 6057, "rating": 5, "conditionType": 0}]}
	var rec := XGuardianRework.xinmo_rec(XDB.rec("Enemies", 927), g, 10)
	var rids: Array = rec.actions.map(func(a): return int(a.skillId))
	_check("rec.skip_growth_domain", rids == [1], rids)


## 回血招不借：17 层妖精公主的 906 治愈之歌（回 40%）、5 层幽灵公主的 135 次级治疗术
func _heal() -> void:
	for f in [17, 5, 13, 26]:
		var ids := _ids(_xinmo(f).enemies[0])
		var heals := ids.filter(func(id): return XGuardianRework._heal_skill(XDB.rec("Skills", id)))
		_check("f%d.no_heal_skill" % f, heals.is_empty() and not ids.is_empty(), [ids, heals])
	_check("f17.no_906", not _ids(_xinmo(17).enemies[0]).has(906))
	_check("f5.no_135", not _ids(_xinmo(5).enemies[0]).has(135))


## 不是闭关开的 901／770（25 层上行天 Map147 打完嫦娥开 770、公共事件 1600 开 901）：照旧按楼层缩放、敌群页照跑
func _non_trial() -> void:
	var s := _state(25)
	s.map_id = 147
	XZhenqi.pending_trial = {}
	var lg := XBattleLogic.new()
	lg.setup(770, s)
	var e: XEnemy = lg.enemies[0]
	_check("nontrial.map147_floor25", XDungeon.map_floor(147) == 25, XDungeon.map_floor(147))
	_check("nontrial.770_not_xinmo", not XGuardianRework.xinmo_on(lg) and e.horseman.is_empty() and XGuardianRework.xinmo_floor(e) == 0)
	_check("nontrial.770_world", int(e.get_meta(XGuardianRework.META_FLOOR, 0)) == 25 and float(e.mhp) < 1.0e8, [e.get_meta(XGuardianRework.META_FLOOR, 0), e.mhp])
	_check("nontrial.770_pages", (XDB.rec("Troops", 770).get("pages", []) as Array).size() == 2)
	var s2 := _state(10)
	XZhenqi.pending_trial = {}
	var lg2 := XBattleLogic.new()
	lg2.setup(901, s2)
	_check("nontrial.901_pages", not XGuardianRework.xinmo_on(lg2) and lg2.enemies[0].horseman.is_empty() and (XDB.rec("Troops", 901).get("pages", []) as Array).size() == 1)


## 楼层地图上开心魔（XGuardianRework.setup 早于幻化，心魔战在那里跳过，不按楼层小怪缩、不挂楼层标记）
func _floor_map() -> void:
	var map := 0
	for id in range(1, 500):
		if XDungeon.map_floor(id) == 10:
			map = id
			break
	var s := _state(10)
	s.map_id = map
	XZhenqi.pending_trial = {"actorId": 2, "target": 1, "ref": XZhenqi.trial_ref(s, 1), "kind": "心魔", "troopId": 901, "brand": true}
	var lg := XBattleLogic.new()
	lg.setup(901, s)
	var e: XEnemy = lg.enemies[0]
	var g := _guardian(10)
	_check("floor_map.no_world", map > 0 and not e.has_meta(XGuardianRework.META_FLOOR), [map, e.get_meta(XGuardianRework.META_FLOOR, 0)])
	_check("floor_map.hp_eq", g != null and is_equal_approx(float(e.mhp), float(g.mhp)), [e.mhp, g.mhp if g else -1])


func _rollback() -> void:
	XGuardianRework.XINMO = false
	var lg := _xinmo(10)
	var e: XEnemy = lg.enemies[0]
	_check("off.original_rec", e.horseman.is_empty() and _ids(e).has(3823) and _ids(e).has(4239), _ids(e))
	_check("off.huge_hp", float(e.mhp) > 1.0e8, e.mhp)
	_check("off.shield", (e.passive_cache().harmRe as Dictionary).values().any(func(v): return float(v) >= 5.0e7), e.passive_cache().harmRe)
	_check("off.pages", (XDB.rec("Troops", 901).get("pages", []) as Array).size() == 1 and (XDB.rec("Troops", 770).get("pages", []) as Array).size() == 2)
	var lg7 := _xinmo(10, 1)
	var e7: XEnemy = lg7.enemies[0]
	_turns(lg7, 1)
	var buffs := range(8).map(func(i): return e7.buffs[i])
	_check("off.770_domain", buffs.any(func(b): return int(b) > 0) or lg7.actors.any(func(a): return a.is_state_affected(264)), buffs)
	XGuardianRework.XINMO = true


func _xiyou() -> void:
	var lg := _xinmo(10, 2, false)
	var e: XEnemy = lg.enemies[0]
	_check("xiyou.untouched", e.horseman.is_empty() and not XGuardianRework.xinmo_on(lg) and _ids(e).has(3823), _ids(e))
	_check("xiyou.pages", (XDB.rec("Troops", 901).get("pages", []) as Array).size() == 1)
