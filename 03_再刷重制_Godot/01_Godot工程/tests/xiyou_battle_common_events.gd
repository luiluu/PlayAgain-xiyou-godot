extends Node
## 战斗中技能／物品的公共事件（效果 44，XBattleCommonEvent）：对照冻结 v0.28 参照 tests/fixtures/battle_common_event_oracle.json
## （mv_oracle/battle_common_event_probe.cjs，真实 BattleManager）。各例只比规则结果：行动后才跑哪个公共事件、事件里强制行动的
## 行动者／技能／目标、捕到的宠物与提示；行动顺序（OTB 速度）不比。另跑一遍切片里所有战斗可用的 44 公共事件，统计没翻译的指令
## （只打印，不判失败）。

const FIXTURE := "res://tests/fixtures/battle_common_event_oracle.json"
var results := []
var ref: Dictionary


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func _case(id: String) -> Dictionary:
	for c in ref.cases:
		if c.id == id:
			return c
	return {}


func battle(party: Array, troop := 2) -> XBattleLogic:
	var s := XState.new_game(3, party[0], party.slice(1))
	XState.current = s
	var l := XBattleLogic.new()
	l.elite_roll = 100.0
	l.setup(troop, s)
	for e in l.enemies:
		e.capture = false
	return l


## 记录里的行动（act／强制行动的 execute）：[行动者, 技能或物品 ID]
static func actions(logs: Array) -> Array:
	return logs.filter(func(x): return x.type == "action").map(func(x): return [x.user, int(x.skill.id)])


func _thunder(id: String, learn_5083: bool, kill: bool) -> void:
	var c := _case(id)
	var l := battle([23, 8, 9, 10])
	var a := l.state.actor(23)
	a.learn_skill(217)
	if learn_5083:
		a.learn_skill(5083)
	else:
		a.forget_skill(5083)
	a.mp = a.mmp
	var t: XEnemy = l.enemies[int(c.setup.use[2])]
	if kill:
		for i in l.enemies.size():
			if i > 0:
				l.enemies[i].hidden = true
		t.hp = 1.0
	l.act(a, XDB.rec("Skills", 217), t)
	check(id + ".reserved", XBattleCommonEvent.reserved(l) == 84, XBattleCommonEvent.reserved(l))
	var ev := l.run_events()
	var forced: Array = actions(ev)
	var want: Array = c.observed.actions.filter(func(x): return bool(x.forcing))
	var got := forced.map(func(x): return {"subject": ("a%d" % x[0].actor_id) if x[0] is XActor else "?", "skill": x[1]})
	var want_g := want.map(func(x): return {"subject": x.subject, "skill": int(x.item[1])})
	check(id + ".forced", JSON.stringify(got) == JSON.stringify(want_g), [got, want_g])
	if not forced.is_empty() and not kill:
		var hits := ev.filter(func(x): return x.type == "hit")
		var tgt := l.enemies.find(hits[0].target) if not hits.is_empty() else -1
		check(id + ".forced_target", tgt == int(want[0].target), [tgt, want[0].target])
	check(id + ".event_cleared", XBattleCommonEvent.reserved(l) == 0)
	if kill:
		check(id + ".won_after_event", l.is_won() and int(c.observed.get("victory", -1)) == c.observed.actions.size(), [l.is_won(), c.observed.get("victory")])


func _net() -> void:
	var c := _case("net_after_action")
	var l := battle([1, 8, 9, 10])
	var s := l.state
	s.gain_item(317, 1)
	for e in l.enemies:
		e.capture = true
	l.set_meta("pet_random", XRandomStream.scripted(range(40).map(func(_i): return {"kind": "float", "value": 0.5}), "pet"))
	l.act(s.actor(8), XDB.rec("Items", 317), l.enemies[0])
	check("net.after_action_only", s.pets.list.is_empty() and XBattleCommonEvent.reserved(l) == 173)
	var ev := l.run_events()
	var shown := ev.filter(func(x): return x.type == "toast").map(func(x): return x.text)
	check("net.captured", s.pets.list.size() == int(c.observed.pets) and shown == c.observed.toasts and l.enemies[0].hidden
		and not c.observed.actions.any(func(x): return x.subject == "e0"), [s.pets.list.size(), shown])


## 单槽：同一次行动有两个 44 效果时后一个盖前一个；COMMON EVENT: X 同样预约
func _slot() -> void:
	var l := battle([1, 8, 9, 10])
	var fake := {"id": 1, "effects": [{"code": 44, "dataId": 84}, {"code": 44, "dataId": 91}], "occasion": 1}
	XBattleCommonEvent.reserve_action(l, l.actors[0], fake, [])
	check("slot.last_wins", XBattleCommonEvent.reserved(l) == 91)
	var seq := XActionSequence.create(l, l.actors[0], XDB.rec("Skills", 292), [l.enemies[0]])
	seq._command("COMMON EVENT", ["375"])
	check("slot.common_event_cmd", XBattleCommonEvent.reserved(l) == 375)
	# 公共事件 1406（天虎令剑思）里的 $.toaster 拼变量：战斗中记成提示
	l.state.set_variable(1, 0)
	var r := XBattleEventRunner.new(l, [{"code": 355, "indent": 0, "parameters": ["$.toaster({ message : '天虎令当前剑思为 '+$gameVariables.value(5)});"]}, {"code": 0, "indent": 0, "parameters": []}])
	l.state.set_variable(5, 3)
	r.advance()
	check("toaster_in_battle", r.take_logs().map(func(x): return x.get("text")) == ["天虎令当前剑思为 3"] and r.skipped.is_empty())


## 盘点：切片里战斗中能用（occasion 0／1）的技能、物品带的 44 公共事件，逐个在战斗里跑一遍，统计没翻译的指令
func _inventory() -> void:
	var ids := {}
	for tab in ["Skills", "Items"]:
		for r in XDB.table(tab):
			if r is Dictionary and int(r.get("occasion", 3)) in [0, 1]:
				for e in r.get("effects", []):
					if int(e.code) == 44:
						ids[int(e.dataId)] = true
	var skipped := {}
	var with_skip := []
	for id in ids.keys():
		var l := battle([1, 8, 9, 10])
		l.message_responder = func(_m): return null
		XBattleCommonEvent.reserve(l, id)
		l.common_event_skipped.clear()
		l.run_events()
		if not l.common_event_skipped.is_empty():
			with_skip.append(id)
		for sk in l.common_event_skipped:
			var k := str(sk).split(" ")[0]
			skipped[k] = int(skipped.get(k, 0)) + 1
	print("INVENTORY battle CE=%d, with skipped=%d %s, skipped codes=%s" % [ids.size(), with_skip.size(), JSON.stringify(with_skip), JSON.stringify(skipped)])
	check("inventory.ran", ids.size() > 200, ids.size())


func _run() -> void:
	ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var manifest = XDB.load_json("manifest.json")
	var sha = manifest.get("runtimeInputs", {}).get(ref.source) if manifest is Dictionary else null
	check("fixture_matches_current_plugin", sha == ref.sha256, [ref.sha256, sha])
	for c in ref.cases:
		check("oracle_ok." + str(c.id), c.errors.is_empty(), c.errors)
	_thunder("thunder_learned", true, false)
	_thunder("thunder_not_learned", false, false)
	_thunder("thunder_battle_end", true, true)
	_net()
	_slot()
	_inventory()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
