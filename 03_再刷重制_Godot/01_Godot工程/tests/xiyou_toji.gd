extends Node
## 171 甚尔第一期（XToji）：与 mv_oracle/toji_probe.cjs 的冻结 v0.28 参照（generated/oracle/toji.json）逐例比。
## stats：等级 × 进阶 × 生命满／半（及戴藏兵咒灵一档）的八项能力、暴击、被动缓存终伤／暴伤、技能表、outputGrowth、
## 10216～10223 对敌群 3 第 1 只的结算（与 xiyou_rules 同口径：Godot settled 对 MV value÷growth）。recruit：新招募、再招募、背包已有。
## 反向验证：把关键被动拿掉或换成别的角色，同一条参照必须对不上（证明比对确实咬住了甚尔的包装）。
const ORACLE := "oracle/toji.json"
const TROOP := 3
const DIFFICULTY := 2
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(600))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _close(a: float, b: float, rel := 1e-6) -> bool:
	return absf(a - b) <= maxf(1e-6, absf(b) * rel)


func _close_r6(a: float, b: float, growth := 1.0) -> bool:
	var rel := maxf(1e-6, 6e-7 / maxf(absf(growth), 1e-9))
	return absf(a - b) <= maxf(1e-5, absf(b) * rel)


func _state() -> XState:
	var s := XState.new_game(DIFFICULTY, 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.set_switch(2494, true)  # 同参照：开超强者挑战，甚尔才能入队（XItemMarks.SUPER_SWITCHES）
	return s


func _target() -> XEnemy:
	var troop := XDB.rec("Troops", TROOP)
	var en := XEnemy.new().setup(int(troop.members[0].enemyId), DIFFICULTY, 100.0)  # 参照数据取自非神话（Math.random=0.99）
	en.setup_level(1, 0.99)
	return en


func _toji(s: XState, setup: Dictionary) -> XActor:
	var a := s.actor(XToji.ACTOR)
	a.change_level_mv(int(setup.level))
	if int(setup.get("rank", 0)) > 0:
		s.actor_advance[XToji.ACTOR] = int(setup.rank)
		XToji.repair(a)  # 原版读档 extractSaveContents 包装跑 repair
	if setup.get("armor", false):
		XToji.recruit(s)
	a.recover_all()
	if setup.get("half", false):
		a.hp = floorf(a.mhp / 2)
	a.refresh_passive()
	return a


func _params(a: XActor) -> Array:
	return range(8).map(func(i): return a.param(i))


func _skills(a: XActor) -> Array:
	return a.skill_ids.filter(func(id): return id >= 10203 and id <= 10228)


## 一档 stats：返回不一致的项（空＝全对上）
func _diff(a: XActor, e: XEnemy, o: Dictionary) -> Array:
	var bad := []
	var p := _params(a)
	for i in 8:
		if not _close(p[i], float(o.param[i])):
			bad.append(["param", i, p[i], o.param[i]])
	if not _close(a.xparam(2), float(o.cri)):
		bad.append(["cri", a.xparam(2), o.cri])
	var c := a.passive_cache()
	if not _close(float(c.globalHarmRi), float(o.globalHarmRi)) or not _close(float(c.critHarmRi), float(o.critHarmRi)):
		bad.append(["cache", c.globalHarmRi, c.critHarmRi, o.globalHarmRi, o.critHarmRi])
	if _skills(a) != o.skills.map(func(v): return int(v)):
		bad.append(["skills", _skills(a), o.skills])
	var g := [XToji.output_growth(a, false), XToji.output_growth(a, true)]
	if not _close(g[0], float(o.growth[0]), 1e-5) or not _close(g[1], float(o.growth[1]), 1e-5):
		bad.append(["growth", g, o.growth])
	var zero_vars := []
	zero_vars.resize(5000)
	zero_vars.fill(0)
	for r in o.damage:
		if r.has("error"):
			bad.append(["oracle_error", r])
			continue
		var res: Dictionary = XDamage.calculate(XDB.rec("Skills", int(r.skill)), a, e, {"variance": false, "critical": false, "vars": zero_vars})
		var growth := float(r.breakdown.row.growth)
		var expected := float(r.breakdown.row.value) / growth if growth != 0.0 else 0.0
		if not _close_r6(float(res.settled), expected, growth):
			bad.append(["damage", int(r.skill), res.settled, expected, res.breakdown.get("row")])
	return bad


func _stats(c: Dictionary) -> void:
	var s := _state()
	var a := _toji(s, c.setup)
	var o: Dictionary = c.observed
	var bad := _diff(a, _target(), o)
	check(c.id, bad.is_empty(), bad)
	if c.setup.get("armor", false):
		var base: Array = a.equips.map(func(e): return int(e.get("base", e.get("id", 0))) if e is Dictionary and not e.is_empty() else 0)
		check(c.id + ".armor", base.slice(0, o.armor.size()) == o.armor.map(func(v): return int(v)), [base, o.armor])
	# 反向验证：满级不进阶那档，拿掉大力 10209 后物攻、伤害都应对不上；换成 1 号角色走同一参照也对不上
	if c.id == "stats.r0.lv50":
		a.forget_skill(XToji.POWER)
		a.refresh_passive()
		var rb := _diff(a, _target(), o)
		check("reverse.no_power", rb.any(func(x): return x[0] == "param" and x[1] == 2) and rb.any(func(x): return x[0] == "damage"), rb.size())
		a.learn_skill(XToji.POWER)
		a.forget_skill(XToji.TYRANT)
		a.refresh_passive()
		rb = _diff(a, _target(), o)
		check("reverse.no_tyrant", rb.any(func(x): return x[0] == "cri") and rb.any(func(x): return x[0] == "cache") and rb.any(func(x): return x[0] == "damage"), rb.size())
		check("reverse.other_actor", XToji.damage_ops(XDB.rec("Skills", 10216), s.actor(1)).is_empty() and XToji.formula(s.actor(1), null, XDB.rec("Skills", 10216)) == 0.0 and XToji.param(s.actor(1), 1, 50.0) == 50.0)


func _party(s: XState) -> Dictionary:
	var a := s.actor(XToji.ACTOR)
	var spare := s.gear.filter(func(e): return e.kind == "armor" and int(e.base) == XToji.ARMOR).size()
	return {"inParty": s.party.has(XToji.ACTOR), "equips": a.equips.map(func(e): return int(e.get("base", e.get("id", 0))) if e is Dictionary and not e.is_empty() else 0), "spare": spare}


func _same_party(g: Dictionary, m: Dictionary) -> bool:
	var eq: Array = m.equips.map(func(v): return int(v))
	return g.inParty == m.inParty and g.equips.slice(0, eq.size()) == eq and int(g.spare) == int(m.spare)


func _recruit(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _state()
	if c.id == "recruit.new":
		var first := XToji.recruit(s)
		var after := _party(s)
		var again := XToji.recruit(s)
		check(c.id, (not first.is_empty()) == bool(o.first) and first == o.firstToasts and _same_party(after, o.after)
			and again.is_empty() == not bool(o.again) and again == o.againToasts and _same_party(_party(s), o.final), [first, after, again])
	else:
		s.gain_gear("armor", XToji.ARMOR, 1)
		var before := _party(s)
		var lines := XToji.recruit(s)
		check(c.id, _same_party(before, o.before) and (not lines.is_empty()) == bool(o.ok) and lines == o.toasts and _same_party(_party(s), o.after), [before, lines, _party(s)])


func _run() -> void:
	var ref = XDB.load_json(ORACLE)
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	var seen := 0
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		seen += 1
		if str(c.id).begins_with("stats."):
			_stats(c)
		else:
			_recruit(c)
	check("covers_all", seen == 31, seen)
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_toji", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
