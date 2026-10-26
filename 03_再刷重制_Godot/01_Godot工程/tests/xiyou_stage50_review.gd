extends Node
## 50%审查跨批回归：真实状态1712／1779保存往返、154以92反击附522。
## 数值逐项取stage50_review_probe的冻结源实测；夹具只在内存，无玩家存档。
var results := []

class BigEnemy extends XEnemy:
	var max_hp := 1.0e9
	func param(i: int) -> float:
		return max_hp if i == 0 else super(i)

class ProbeLogic extends XBattleLogic:
	func _float(reason: String) -> float:
		return 0.999 if reason in ["evade", "critical"] else 0.0

func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok

func _ready() -> void:
	_run.call_deferred()

func _state() -> XState:
	var s := XState.new_game_blank()
	s.set_switch(2494, true)  # 正式超强者招募／出战门槛，允许154实际在队
	for id in [1, 8, 154]:
		s.add_actor(id)
	XState.current = s
	return s

func _value(s: XState) -> float:
	return XDamage.finish({"value": 100.0}, XDB.rec("Skills", 1), s.actors[1], s.actors[8])

func _save(ref: Dictionary) -> void:
	var s := _state()
	s.actors[1].add_state(1712)
	s.actors[8].add_state(1779)
	for a in s.actors.values():
		a.param_mark_dirty()
		a.param_refresh()
	check("save.before", _value(s) == float(ref.before.value), _value(s))
	# from_dict重建状态快照不应另做资源setter／refresh而夹掉保存的HP／MP。
	s.actors[1].hp = s.actors[1].mhp * 2.0
	s.actors[1].mp = s.actors[1].mmp * 2.0
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded := XState.from_dict(saved)
	check("save.after", _value(loaded) == float(ref.after.value), _value(loaded))
	check("save.state_lists", loaded.actors[1].effect_states("confirm").map(func(x): return int(x.id)) == ref.after.confirmStates.map(func(x): return int(x))
		and loaded.actors[8].effect_states("react").map(func(x): return int(x.id)) == ref.after.reactStates.map(func(x): return int(x)))
	check("save.resources_unclamped", loaded.actors[1].hp == float(saved.actors["1"].hp) and loaded.actors[1].mp == float(saved.actors["1"].mp))

func _counter(ref: Dictionary) -> void:
	var s := _state()
	var a: XActor = s.actors[int(ref.actor)]
	check("counter.party_member", s.members().has(a))
	var e := BigEnemy.new()
	e.max_hp = float(ref.maxHp)
	e.setup(int(XDB.rec("Troops", 2).members[0].enemyId), 3, 100.0)
	a.add_state(92)
	a.param_mark_dirty()
	a.param_refresh()
	var logic := ProbeLogic.new()
	logic.state = s
	logic.actors = [a, s.actors[1]]
	logic.enemies = [e]
	XImportedBalance.set_acting(e)
	var logs := logic._invoke(e, XDB.rec("Skills", int(ref.initialSkill)), a)
	check("counter.real_path", logs.size() == 2 and logs[0].type == "counter" and a.cnt == float(ref.counterRate) and int(ref.counterCalls) == 1, {"types":logs.map(func(x): return x.type), "cnt":a.cnt})
	var origin := XImportedBalance.origin(e, int(ref.state))
	check("counter.origin", e.is_state_affected(int(ref.state)) and origin == e and bool(ref.originIsSelf), e.state_ids)
	check("counter.restores_outer", XImportedBalance.acting_battler() == e)
	e.hp = float(ref.hpBeforeRegen)
	var before := e.hp
	logic._regenerate(e, [])
	check("counter.dot", e.hp - before == float(ref.hpDelta), [e.hp - before, ref.hpDelta])
	XImportedBalance.set_acting(null)

func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string("res://modes/xiyou/generated/oracle/stage50_review.json"))
	if check("native_fixture", ref is Dictionary and ref.get("cases", []).size() == 2):
		for row in ref.cases:
			if row.id == "save.state_effects":
				_save(row.observed)
			elif row.id == "counter.state_origin":
				_counter(row.observed)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
