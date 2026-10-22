extends Node
## 琦玉专属模块（XQiyu）：逐例对照 mv_oracle/qiyu_probe.cjs（generated/oracle/qiyu.json）。
## - rates.*：行动者 50 级、目标为敌群 2 第一个敌人（带参照同形的测试状态），比 itemHit／itemEva，以及 _invoke 实际用的
##   反击率（物理且不必中时取目标 cnt）、反射率（魔法且不必中时取目标 mrf）；163 的技能必中，物品照常，164／162 作对照。
## - invoke.*：真实 _invoke 打带反射或反击测试状态的敌人（比率为 1，必然触发），比有没有被反射／反击。
## - state2626.*：163 加不上 2626，别人加得上。
## - relic124：新生成的法宝 124 实例特性、每级成长、SkillPass 与参照一致，装给 163（30 级）后法宝 1／5 级的能力值。
const ORACLE := "oracle/qiyu.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(600))
	return ok


func _ready() -> void:
	_run.call_deferred()


## 参照 setup.fake 的测试状态（只有给定特性）在 Godot 建一份同形的，同名复用（同 xiyou_imported_balance）
var fakes := {}
func _fake_state(name: String, fake: Dictionary) -> int:
	if not fakes.has(name):
		var t: Array = XDB.table("States")
		fakes[name] = t.size()
		t.append({"id": t.size(), "name": "测试·" + name, "traits": fake[name].traits, "note": "", "meta": {}, "iconIndex": 0,
			"restriction": 0, "priority": 50, "autoRemovalTiming": 0, "minTurns": 1, "maxTurns": 1, "removeAtBattleEnd": false})
	return fakes[name]


func _actor(id: int, level: int) -> XActor:
	var a := XActor.new().setup(id)
	a.change_level_mv(level)
	a.refresh_passive()
	return a


func _enemy(c: Dictionary) -> XEnemy:
	var e := XEnemy.new().setup(int(XDB.rec("Troops", 2).members[0].enemyId), 3, 100.0)
	for n in c.setup.get("states", []):
		e.add_state(_fake_state(str(n), c.setup.fake))
	return e


func _item(c: Dictionary) -> Dictionary:
	if str(c.setup.kind) == "skill":
		return XDB.rec("Skills", int(c.setup.item))
	var d: Dictionary = c.setup.itemData
	return {"id": int(c.setup.item), "itypeId": 1, "name": "测试·物理物品", "scope": int(d.scope), "hitType": int(d.hitType),
		"successRate": 100, "repeats": 1, "speed": 0, "occasion": 0, "effects": [], "note": "", "meta": {}, "damage": d.damage}


func _rates(c: Dictionary, logic: XBattleLogic) -> void:
	var o: Dictionary = c.observed
	var a := _actor(int(c.setup.actor), 50)
	var t := _enemy(c)
	var item := _item(c)
	var sure := XBattleLogic.certain_hit(a, item)
	var got := {"hit": logic.item_hit(a, item, t), "eva": logic.item_eva(a, item, t),
		"cnt": t.cnt if XDamage.is_physical(item) and not sure else 0.0,
		"mrf": t.mrf if XDamage.is_magical(item) and not sure else 0.0}
	for k in got:
		check(c.id + "." + k, absf(float(got[k]) - float(o[k])) < 1e-9, [got[k], o[k]])
	check(c.id + ".kind", XDamage.is_physical(item) == bool(o.isPhysical) and XDamage.is_magical(item) == bool(o.isMagical),
		[XDamage.is_physical(item), o.isPhysical, XDamage.is_magical(item), o.isMagical])


func _invoke(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	s.random_master = XRandomStream.hex64(163)
	var logic := XBattleLogic.new()
	logic.setup(2, s)
	var a := _actor(int(c.setup.actor), 50)
	var t := _enemy(c)
	var logs := logic._invoke(a, XDB.rec("Skills", int(c.setup.skill)), t)
	var types: Array = logs.map(func(l): return str(l.get("type", "")))
	check(c.id + ".reflected", types.has("reflect") == bool(o.reflected), [types, o.reflected])
	check(c.id + ".countered", types.has("counter") == bool(o.countered), [types, o.countered])


func _state2626(c: Dictionary) -> void:
	var a := XActor.new().setup(int(c.setup.actor))
	a.add_state(2626)
	check(c.id, a.state_ids.has(2626) == bool(c.observed.affected), [a.state_ids, c.observed])


func _relic(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var inst := XGear.create("armor", 124)
	check("relic124.traits", inst.traits == o.inst.traits, [inst.traits, o.inst.traits])
	check("relic124.params", (inst.params as Array).map(func(v): return float(v)) == (o.inst.params as Array).map(func(v): return float(v)),
		[inst.params, o.inst.params])
	var growth := range(8).map(func(i): return XActor.magic_param(inst, i) / maxf(1.0, float(XEquipmentView.level(inst))))
	check("relic124.per_level", growth == (o.inst.perLevel as Array).map(func(v): return float(v)), [growth, o.inst.perLevel])
	check("relic124.same_as_db", bool(o.inst.noteSameAsDb) and o.inst.traits == o.db.traits and o.inst.perLevel == o.db.perLevel
		and o.inst.skillPass == o.db.skillPass, o)
	var a := _actor(163, 30)
	a.equips[int(o.slot)] = inst
	a.refresh_passive()
	var skill_pass: Dictionary = a.passive_cache().skillPass
	for kv in o.inst.skillPass:
		var sid := int(str(kv[0]).substr(9))
		check("relic124.skill_pass_%d" % sid, absf(float(skill_pass.get(sid, {}).get("rate", 0.0)) - float(str(kv[1]).trim_suffix("%")) / 100.0) < 1e-9,
			[skill_pass.get(sid), kv])
	for r in o.rows:
		if r.setLevel != null:
			inst.level = float(r.setLevel)
		var tag := "relic124.lv%d" % int(r.level)
		var plus := range(8).map(func(i): return XActor.magic_param(inst, i))
		check(tag + ".magic_plus", plus == (r.paramPlus as Array).map(func(v): return float(v)), [plus, r.paramPlus])
		var params := range(8).map(func(i): return a.param(i))
		check(tag + ".params", params == (r.params as Array).map(func(v): return float(v)), [params, r.params])


func _run() -> void:
	var ref = XDB.load_json(ORACLE)
	if not (ref is Dictionary and ref.has("cases")):
		check("oracle_present", false)
		return finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	var logic := XBattleLogic.new()
	var seen := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var kind := str(c.id).get_slice(".", 0)
		seen[kind] = true
		match kind:
			"module":
				check("module", int(c.observed.actorId) == XQiyu.ACTOR_ID and int(c.observed.revision) == 25, c.observed)
			"rates":
				_rates(c, logic)
			"invoke":
				_invoke(c)
			"state2626":
				_state2626(c)
			"relic124":
				_relic(c)
	check("covers_all", seen.keys().size() == 5, seen.keys())
	# 对照组确有差别：164 的普攻会被反射、9934 会被反击，163 都不会
	var by_id := {}
	for c in ref.cases:
		by_id[c.id] = c
	check("contrast", by_id["invoke.a164.s1.mrf"].observed.reflected and by_id["invoke.a164.s9934.cnt"].observed.countered
		and not by_id["invoke.a163.s1.mrf"].observed.reflected and not by_id["invoke.a163.s9934.cnt"].observed.countered)
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
