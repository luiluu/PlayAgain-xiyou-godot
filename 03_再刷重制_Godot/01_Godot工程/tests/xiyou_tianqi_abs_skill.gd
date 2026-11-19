extends Node
## 【cc·T243】天启篇期四：技能公式里写死的固定回复底数（skill_fixed_heal）、固定吸取量（skill_fixed_drain）换成对象上限的整数百分比
## （abs_rescale.json；XTianqiBase.skill_formula，接在 XFormulaExecution.run_item）。
## 一、表：62＋11 行全是结构化的（{pct_of, pct, base} 或 {mode: raw, reason}），pct 是 1～100 的整数（附则 E），orig 等于库里的公式。
## 二、开着、天启篇存档：屏障术 1301（敌人自疗，3000000）＝ −⌊对象生命上限 × 100%⌋；治愈 8（200＋魔攻）只换 200 那一截；
##     折磨 897（吸生命 5000）、吞魔术 500（吸魔法 10000）按被吸的人的上限；raw 行、公式对不上表、物品同号照原值。
## 三、ABS_SKILL 关、总开关关、西游档：照原公式。同一输入跑两遍结果一样（不取随机数）。
## 四、T240 复核 P3-2：判决（on_attack）、灰镰处决这两下打倒的敌人补记成行动者的致命一击（fu.lethal → fu_note 记进 kills）。

var results: Array = []


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
		s.actor(id).change_level(81)
		s.actor(id).recover_all()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	return lg


func _raw(lg: XBattleLogic, u, id: int, t) -> float:
	return lg._formula_raw(u, XDB.rec("Skills", id), t)


func _run() -> void:
	XMessageBox.auto = true
	seed(20261119)
	XTianqiBase.clear_cache()
	_table()
	_on()
	_off_paths()
	_p3_2()
	XTianqiBase.PHASE4 = true
	XTianqiBase.ABS_SKILL = true
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _table() -> void:
	var rows: Array = XTianqiBase.abs_data().get("entries", []).filter(func(e): return e is Dictionary and str(e.get("kind", "")) in ["skill_fixed_heal", "skill_fixed_drain"])
	_check("table.rows", rows.filter(func(e): return e.kind == "skill_fixed_heal").size() == 62 and rows.filter(func(e): return e.kind == "skill_fixed_drain").size() == 11, rows.size())
	var bad := []
	for e in rows:
		var n = e.get("new")
		var dm: Dictionary = XDB.rec("Skills", int(e.id)).get("damage", {})
		if not n is Dictionary or str(dm.get("formulaGd", dm.get("formula", ""))) != str(e.orig):
			bad.append(e.id)
		elif str(n.get("mode", "")) != "raw" and not (float(n.pct) == floorf(float(n.pct)) and float(n.pct) >= 1.0 and float(n.pct) <= 100.0 and float(n.base) > 0.0 and str(n.pct_of) in ["mhp", "mmp"]):
			bad.append(e.id)
	_check("table.struct_int", bad.is_empty(), bad)
	var e1301 := XTianqiBase.abs_entry("skill_fixed_heal", 1301)
	_check("table.1301", not e1301.is_empty() and int(e1301.new.pct) == 100 and float(e1301.new.base) == 3000000.0 and str(e1301.new.pct_of) == "mhp", e1301)


func _on() -> void:
	XTianqiBase.PHASE4 = true
	XTianqiBase.ABS_SKILL = true
	XTianqiBase.clear_cache()
	var lg := _logic(true)
	_check("on.on", XTianqiBase.on())
	var e: XEnemy = lg.enemies[0]
	var a: XActor = lg.actors[0]
	var b: XActor = lg.actors[1]
	# 验收 3：屏障术 1301 敌人自疗，回量＝对象生命上限 × 表里百分比（100%）
	var pct := float(XTianqiBase.abs_entry("skill_fixed_heal", 1301).new.pct)
	var v1301 := _raw(lg, e, 1301, e)
	_check("on.1301", v1301 == -floorf(float(e.mhp) * pct / 100.0) and e.mhp > 0.0, [v1301, e.mhp, pct])
	_check("on.1301_not_orig", v1301 != -3000000.0 or e.mhp == 3000000.0, v1301)
	_check("on.1301_twice", _raw(lg, e, 1301, e) == v1301)
	# 治愈 8：200＋魔攻 → ⌊生命上限×3%⌋＋魔攻（只换底数）
	var on8 := _raw(lg, a, 8, b)
	XTianqiBase.ABS_SKILL = false
	var off8 := _raw(lg, a, 8, b)
	XTianqiBase.ABS_SKILL = true
	var e8 := XTianqiBase.abs_entry("skill_fixed_heal", 8)
	var nb := floorf(float(b.mhp) * float(e8.new.pct) / 100.0)
	_check("on.8_only_base", on8 < 0.0 and off8 < 0.0 and on8 - off8 == -(nb - 200.0), [on8, off8, nb, b.mhp])
	# 吸取：897 吸生命 5000 → 被吸的人生命上限 × pct；500 吸魔法 10000 → 魔法上限 × pct
	var e897 := XTianqiBase.abs_entry("skill_fixed_drain", 897)
	var v897 := _raw(lg, e, 897, b)
	_check("on.drain_hp_897", str(e897.new.pct_of) == "mhp" and v897 == floorf(float(b.mhp) * float(e897.new.pct) / 100.0), [v897, b.mhp, e897.new])
	var e500 := XTianqiBase.abs_entry("skill_fixed_drain", 500)
	var v500 := _raw(lg, e, 500, b)
	_check("on.drain_mp_500", str(e500.new.pct_of) == "mmp" and v500 == floorf(float(b.mmp) * float(e500.new.pct) / 100.0), [v500, b.mmp, e500.new])
	# raw 行（普度众生 8021：b.mhp×0.5）照原值
	var on8021 := _raw(lg, a, 8021, b)
	XTianqiBase.ABS_SKILL = false
	var off8021 := _raw(lg, a, 8021, b)
	XTianqiBase.ABS_SKILL = true
	_check("on.raw_8021", on8021 == off8021 and on8021 == -float(b.mhp) * 0.5, [on8021, off8021])
	# 公式被改写、对不上 orig：照原值（警告一次）
	var sk: Dictionary = XDB.rec("Skills", 8).duplicate(true)
	sk.damage.formulaGd = "201 + a.mat"
	_check("on.mismatch", lg._formula_raw(a, sk, b) == off8 and XTianqiBase._warned.has("skill:8"), lg._formula_raw(a, sk, b))
	# 物品同号（没有 stypeId）不算
	var it := {"id": 8, "damage": {"type": 3, "formula": "200 + a.mat"}}
	_check("on.item_same_id", XTianqiBase.skill_formula(it, b, -1234.0) == -1234.0)
	lg.end_battle(0)


func _off_paths() -> void:
	# 总开关关
	XTianqiBase.PHASE4 = false
	XTianqiBase.clear_cache()
	var lg := _logic(true)
	var e: XEnemy = lg.enemies[0]
	_check("off.phase4", _raw(lg, e, 1301, e) == -3000000.0, _raw(lg, e, 1301, e))
	lg.end_battle(0)
	# ABS_SKILL 关
	XTianqiBase.PHASE4 = true
	XTianqiBase.ABS_SKILL = false
	lg = _logic(true)
	e = lg.enemies[0]
	_check("off.switch", _raw(lg, e, 1301, e) == -3000000.0, _raw(lg, e, 1301, e))
	lg.end_battle(0)
	XTianqiBase.ABS_SKILL = true
	# 西游档
	lg = _logic(false)
	e = lg.enemies[0]
	var b: XActor = lg.actors[1]
	_check("off.xiyou", not XTianqiBase.on() and _raw(lg, e, 1301, e) == -3000000.0 and _raw(lg, e, 897, b) == 5000.0, [_raw(lg, e, 1301, e), _raw(lg, e, 897, b)])
	lg.end_battle(0)


## T240 复核 P3-2：after_apply 里判决、灰镰的 _lose_hp 打倒的敌人要进 fu.lethal（开头的 fu_mark 在扣血之前，原来漏记）
func _p3_2() -> void:
	XTianqiBase.PHASE4 = true
	XTianqiQiyinEffects.ENABLED = true
	for code in ["execute_normal", "judgment:on_attack"]:
		var lg := _logic(true)
		XTianqiQiyinEffects.start(lg)
		var u: XActor = lg.actors[0]
		var sk := u.attack_skill()
		var e: XEnemy = null
		for x in lg.enemies:
			if not XBossStatus.is_boss(x):
				e = x
				break
		var st: Dictionary = XTianqiQiyinEffects._store(lg)
		if st.is_empty() or e == null:
			_check("p3_2.fixture_" + code, false, [st.is_empty(), e])
			continue
		st.fx[u] = {"execute_normal": {"below_pct": 15}} if code == "execute_normal" else {"judgment:on_attack": {"max_hp_pct": 5}}
		XTianqiQiyinEffects.begin_action(lg, u, sk)
		XTianqiQiyinEffects.fu_open(lg, u)
		var before := XTianqiQiyinEffects.fu_snap(lg, u)
		e.immortal = false
		e.shield = 0.0
		e.hp = 1.0
		XTianqiQiyinEffects.after_apply(lg, u, sk, e, {"hp": 1.0})
		var lethal: bool = XTianqiQiyinEffects._fu(lg).get("lethal", []).has(e)
		XTianqiQiyinEffects.fu_note(lg, u, before)
		var kills: Array = XTianqiQiyinEffects._fu(lg).get("kills", [])
		_check("p3_2." + code, e.is_dead() and before.has(e) and lethal and kills.has(e), [e.is_dead(), before.has(e), lethal, kills.size()])
		XTianqiQiyinEffects.fu_clear(lg)
		lg.end_battle(0)
