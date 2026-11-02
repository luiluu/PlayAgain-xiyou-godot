extends Node
## 175 谷雨第一期（XGuyu）：与 mv_oracle/guyu_probe.cjs 的冻结 v0.28 参照（generated/oracle/guyu.json）逐例比。
## stats：等级 × 进阶 0／5 的已学谷雨技能、技能表、五个主动技 MP 消耗、最大 MP、治疗比例、对自己的泽苍生公式值与结算值，
## 战斗中谷雨五个主动技能不能用（can_use：条件＋付得起）、1 号主角用这些技能不能用。recruit：新招募、再招募、背包已有、离队再招募。
## 另有本地断言：减耗按 applyConsumeReduce、反向（不走谷雨包装时 MP 与治疗都对不上）。
const ORACLE := "oracle/guyu.json"
const DIFFICULTY := 2
const ACTIVE := [10288, 10289, 10290, 10291, 10292]
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(600))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _state() -> XState:
	var s := XState.new_game(DIFFICULTY, 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.set_switch(2494, true)
	return s


func _own(ids: Array) -> Array:
	var out := ids.filter(func(id): return int(id) >= 10288 and int(id) <= 10299).map(func(id): return int(id))
	return out


func _guyu(s: XState, setup: Dictionary) -> XActor:
	var a := s.actor(XGuyu.ACTOR)
	a.change_level_mv(int(setup.level))
	if int(setup.get("stage", 0)) > 0:
		s.actor_advance[XGuyu.ACTOR] = int(setup.stage)
		XGuyu.after_load(s)  # 原版读档 extractSaveContents 包装 syncAll
	a.recover_all()
	return a


func _zero_vars() -> Array:
	var v := []
	v.resize(5000)
	v.fill(0)
	return v


func _diff(s: XState, a: XActor, o: Dictionary) -> Array:
	var bad := []
	var learned := _own(a.skill_ids)
	learned.sort()
	if learned != _own(o.learned):
		bad.append(["learned", learned, o.learned])
	var listed := _own(a.skills().map(func(x): return int(x.id)))
	if listed != _own(o.listed):
		bad.append(["listed", listed, o.listed])
	if a.mmp != float(o.mmp):
		bad.append(["mmp", a.mmp, o.mmp])
	var logic := XBattleLogic.new()
	var mp := ACTIVE.map(func(id): return int(logic.skill_cost(a, XDB.rec("Skills", id)).mp))
	if mp != o.mp.map(func(v): return int(v)):
		bad.append(["mp", mp, o.mp])
	if absf(XGuyu.heal_ratio(a) - float(o.healRatio)) > 1e-6:
		bad.append(["healRatio", XGuyu.heal_ratio(a), o.healRatio])
	var heal := XDB.rec("Skills", 10288)
	var f := XDamage.eval_formula(heal, a, a, _zero_vars())
	if absf(f - float(o.heal.formula)) > 1e-5:
		bad.append(["healFormula", f, o.heal.formula])
	var res: Dictionary = XDamage.calculate(heal, a, a, {"variance": false, "critical": false, "vars": _zero_vars()})
	if float(res.value) != float(o.heal.value):
		bad.append(["healValue", res.value, o.heal.value])
	# 战斗中：谷雨入队出战后在战斗里量 can_use；1 号主角同场
	if not s.party.has(XGuyu.ACTOR):
		s.add_actor(XGuyu.ACTOR)
	var battle := XBattleLogic.new()
	battle.setup(3, s)
	var can := ACTIVE.map(func(id): return battle.can_use(a, XDB.rec("Skills", id)))
	if can != o.battle.canUse.map(func(v): return bool(v)):
		bad.append(["canUse", can, o.battle.canUse])
	var hero := ACTIVE.map(func(id): return battle.can_use(s.actor(1), XDB.rec("Skills", id)))
	if hero != o.battle.hero.map(func(v): return bool(v)):
		bad.append(["hero", hero, o.battle.hero])
	battle.end_battle(0)
	return bad


func _stats(c: Dictionary) -> void:
	var s := _state()
	var a := _guyu(s, c.setup)
	var bad := _diff(s, a, c.observed)
	check(c.id, bad.is_empty(), bad)
	if c.id == "stats.s0.lv40":
		_local(s, a, c.observed)


## 本地断言：减耗 20% 时 MP 按 floor(ceil(最大MP×比例×mcr)×0.8)；反向——不认谷雨（换成 1 号）时不按比例收费、治疗公式为 0
func _local(s: XState, a: XActor, o: Dictionary) -> void:
	var logic := XBattleLogic.new()
	var heal := XDB.rec("Skills", 10288)
	var raw := ceili(a.mmp * 0.06 * a.mcr)
	check("local.mp_formula", int(logic.skill_cost(a, heal).mp) == floori(raw * 1.0) and raw == int(o.mp[0]), [logic.skill_cost(a, heal), raw])
	check("local.mp_reduce", XGuyu.mp_cost(a, heal, a.mcr, 20.0) == floori(raw * 0.8), XGuyu.mp_cost(a, heal, a.mcr, 20.0))
	var hero := s.actor(1)
	var bloom: Array[int] = [10299]
	check("reverse.other_actor", XGuyu.mp_cost(hero, heal, 1.0, 0.0) == -1 and XGuyu.formula(heal, hero, hero, true) == null
		and not XGuyu.skip_heal_rate(heal, hero) and XGuyu.skill_ids(hero, bloom) == bloom)
	check("reverse.no_bloom_listed", not a.skills().any(func(x): return int(x.id) == 10299) and XGuyu.skill_ids(a, bloom).is_empty())


func _party(s: XState) -> Dictionary:
	var a := s.actor(XGuyu.ACTOR)
	var spare := s.gear.filter(func(e): return e.kind == "armor" and int(e.base) == XGuyu.RELIC).size()
	var learned := _own(a.skill_ids)
	learned.sort()
	return {"inParty": s.party.has(XGuyu.ACTOR), "equips": a.equips.map(func(e): return int(e.get("base", e.get("id", 0))) if e is Dictionary and not e.is_empty() else 0),
		"spare": spare, "granted": bool(s.flags.get("guyu_relic_granted", false)), "learned": learned}


func _same_party(g: Dictionary, m: Dictionary) -> bool:
	var eq: Array = m.equips.map(func(v): return int(v))
	return g.inParty == m.inParty and g.equips.slice(0, eq.size()) == eq and int(g.spare) == int(m.spare) and g.granted == bool(m.granted) \
		and g.learned == _own(m.learned)


func _recruit(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _state()
	XGuyu._notified_relic = false
	match str(c.id):
		"recruit.new":
			var first := XGuyu.recruit(s)
			check(c.id + ".first", (first != "") == bool(o.first) and [first] == o.firstToasts and _same_party(_party(s), o.after), [first, _party(s), o.after])
			var again := XGuyu.recruit(s)
			check(c.id + ".again", (again != "") == bool(o.again) and o.againToasts.is_empty() and _same_party(_party(s), o.final), [again, _party(s)])
		"recruit.owned":
			s.gain_gear("armor", XGuyu.RELIC, 1)
			check(c.id + ".before", _same_party(_party(s), o.before), [_party(s), o.before])
			var text := XGuyu.recruit(s)
			check(c.id + ".after", (text != "") == bool(o.ok) and [text] == o.toasts and _same_party(_party(s), o.after), [text, _party(s), o.after])
		"recruit.again":
			XGuyu.recruit(s)
			s.remove_actor(XGuyu.ACTOR)
			var text := XGuyu.recruit(s)
			check(c.id, (text != "") == bool(o.ok) and [text] == o.toasts and _same_party(_party(s), o.after), [text, _party(s), o.after])


## 内存读档（沙僧二审 S2-2-01）：真走 to_dict→JSON→from_dict，读档前的当前局与新档进阶次数不同。
## 原版 extractSaveContents 包装在原函数之后 syncAll，看的是新档（guyu_probe stats.s5.lv60 经 encode／restore 后含 10297）。
## 读后不进战斗查技能账本、技能表、被动缓存，再进战斗 setup 后、结束后各查一次；全程与「新档存档前」的同一角色比。
func _load_cases() -> void:
	for pair in [[5, 0], [0, 5]]:
		var saved_stage: int = pair[0]
		var old_stage: int = pair[1]
		var tag := "load.s%d_over_s%d" % [saved_stage, old_stage]
		var src := _state()
		var g := _guyu(src, {"level": 60, "stage": saved_stage})
		if not src.party.has(XGuyu.ACTOR):
			src.add_actor(XGuyu.ACTOR)
		var want := _own(g.skill_ids)
		want.sort()
		var want_listed := _own(g.skills().map(func(x): return int(x.id)))
		var want_cache := JSON.stringify(g.passive_cache())
		check(tag + ".source", want.has(XGuyu.SKILL.spring) == (saved_stage >= 5), want)
		var blob := JSON.stringify(src.to_dict())
		var old := _state()  # 读档前的当前局：同等级、另一进阶次数
		_guyu(old, {"level": 60, "stage": old_stage})
		check(tag + ".old_current", XState.current == old and XGuyu.stage(old.actor(XGuyu.ACTOR)) == old_stage)
		var s := XState.from_dict(JSON.parse_string(blob))
		var a := s.actor(XGuyu.ACTOR)
		var phases := {}
		phases["menu"] = [XState.current == s, XGuyu.stage(a)]
		_load_same(tag + ".menu", a, want, want_listed, want_cache)
		var battle := XBattleLogic.new()
		battle.setup(3, s)
		_load_same(tag + ".battle", a, want, want_listed, want_cache)
		battle.end_battle(0)
		_load_same(tag + ".after_battle", a, want, want_listed, want_cache)
		check(tag + ".current_stage", phases.menu == [true, saved_stage], phases)


func _load_same(name: String, a: XActor, want: Array, want_listed: Array, want_cache: String) -> void:
	var learned := _own(a.skill_ids)
	learned.sort()
	var listed := _own(a.skills().map(func(x): return int(x.id)))
	check(name, learned == want and listed == want_listed and JSON.stringify(a.passive_cache()) == want_cache,
		[learned, want, listed, want_listed])


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
	check("covers_all", seen == 29, seen)
	_load_cases()
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_guyu", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
