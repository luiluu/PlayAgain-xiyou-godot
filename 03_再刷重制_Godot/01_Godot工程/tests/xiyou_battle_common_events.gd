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


## 技能替换（rule 流 changeto）的取数固定 0.5，同探针的 Math.random；别的取数照常
class ChangeToHalf:
	extends XRandomStream

	func next_float(reason: String, event_key := "") -> float:
		return 0.5 if reason == "changeto" else super(reason, event_key)


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
	l.random.rule = ChangeToHalf.new()
	l.act(a, XDB.rec("Skills", 217), t)
	check(id + ".reserved", XBattleCommonEvent.reserved(l) == 84, XBattleCommonEvent.reserved(l))
	var ev := l.run_events()
	var forced: Array = actions(ev)
	var want: Array = c.observed.actions.filter(func(x): return bool(x.forcing))
	var got := forced.map(func(x): return {"subject": ("a%d" % x[0].actor_id) if x[0] is XActor else "?", "skill": x[1]})
	# 探针在最外层 startAction 记技能，SkillChangeTo 在它里面：参照记的是换前的（533 雷动九天，ChangeTo 几率 0.6…）。
	# 探针 Math.random 恒 0.5，原版同样会换；期望按同样的 0.5 再过一次 change_to（换法本身由 xiyou_skill_change_to 对照）。
	var want_g := want.map(func(x): return {"subject": x.subject, "skill": int(l.change_to(a, XDB.rec("Skills", int(x.item[1]))).id)})
	check(id + ".forced", JSON.stringify(got) == JSON.stringify(want_g), [got, want_g])
	if not forced.is_empty() and not kill:
		var hits := ev.filter(func(x): return x.type == "hit")
		var tgt := l.enemies.find(hits[0].target) if not hits.is_empty() else -1
		check(id + ".forced_target", tgt == int(want[0].target), [tgt, want[0].target])
	check(id + ".event_cleared", XBattleCommonEvent.reserved(l) == 0)
	if kill:
		check(id + ".won_after_event", l.is_won() and int(c.observed.get("victory", -1)) == c.observed.actions.size(), [l.is_won(), c.observed.get("victory")])


## 「套装再放一次」一族（events3c）：技能动作序列给自己加 345 → 公共事件找带 345 且穿着套装（拿着武器、学会某技能）的人强制再放一次。
## 比：预约的公共事件、开跑时谁带着 345、事件后强制行动的行动者与技能、最后 345 还在不在（628 的追加技能自己又加 345）。目标随机不比。
func _recast(id: String) -> void:
	var c := _case(id)
	var st: Dictionary = c.setup
	var l := battle(st.party)
	var s := l.state
	var a := s.actor(int(st.user))
	a.keep_unequippable = true   # 同探针在实例上停掉 releaseUnequippableItems（8 号穿不了这几件）
	a.learn_skill(int(st.use[0]))
	for k in st.get("learn", []):
		a.learn_skill(int(k))
	for k in st.get("forget", []):
		a.forget_skill(int(k))
	for wv in st.get("wear", []):
		s.gain_gear(str(wv[0]), int(wv[1]), 1)
		var item: Dictionary = s.gear.pop_back()
		var etype := 1 if str(wv[0]) == "weapon" else int(XDB.rec("Armors", int(wv[1])).get("etypeId", 0))
		a.equips[a.equip_slots().find(etype)] = item
	a.refresh_passive()
	a.mp = a.mmp
	a.tp = 100
	l.act(a, XDB.rec("Skills", int(st.use[0])), l.enemies[int(st.use[2])])
	var ce: Dictionary = (c.observed.events as Array).filter(func(x): return int(x.commonEvent) != 1320)[0]
	check(id + ".reserved", XBattleCommonEvent.reserved(l) == int(ce.commonEvent), [XBattleCommonEvent.reserved(l), ce.commonEvent])
	check(id + ".marked", a.is_state_affected(345) == (ce.marked as Array).map(func(x): return int(x)).has(int(st.user)), [a.state_ids, ce.marked])
	var ev := l.run_events()
	var got := actions(ev).map(func(x): return [("a%d" % x[0].actor_id) if x[0] is XActor else "?", x[1]])
	var want: Array = c.observed.actions.filter(func(x): return bool(x.forcing)).map(func(x): return [x.subject, int(x.item[1])])
	check(id + ".forced", JSON.stringify(got) == JSON.stringify(want), [got, want])
	check(id + ".state345", a.is_state_affected(345) == bool(c.observed.state345), [a.state_ids, c.observed.state345])
	check(id + ".no_pending", l.pending_force.is_empty())


## CE1327 三千烦恼风再释放（百八烦恼风 6181）：原版角色取 $gameParty._targetActorId（重制 item_target_actor_id）。
## 回退（O_RECAST_CASTER＝false）逐例比参照；默认按放 6181 的人（8 号）：8 号会 6184 就再放，与 target 无关。
## other_holder：原版 9 号还没行动，forceAction 让它先做自己的防御、6182 留在队尾没放；重制回退支直接给 9 号强制 6182（已知差异，只在回退支）。
func _recast_target(id: String, default_forced: bool) -> void:
	var c := _case(id)
	var st: Dictionary = c.setup
	for caster in [false, true]:
		XBattleEventRunner.O_RECAST_CASTER = false if not caster else true
		var tag := id + (".caster" if caster else ".rollback")
		var l := battle(st.party)
		var s := l.state
		var a := s.actor(int(st.user))
		a.learn_skill(6181)
		s.actor(int(st.holder)).learn_skill(6184)
		if int(st.holder) != int(st.user):
			a.forget_skill(6184)
		s.item_target_actor_id = int(st.target)
		a.mp = a.mmp
		a.tp = 100
		l.act(a, XDB.rec("Skills", 6181), l.enemies[0])
		check(tag + ".reserved", XBattleCommonEvent.reserved(l) == 1327, XBattleCommonEvent.reserved(l))
		var got := actions(l.run_events()).map(func(x): return [("a%d" % x[0].actor_id) if x[0] is XActor else "?", x[1]])
		var want: Array = c.observed.actions.filter(func(x): return bool(x.forcing)).map(func(x): return [x.subject, int(x.item[1])])
		if caster:
			want = [["a8", 6182]] if default_forced else []
		elif id == "recast_target_other_holder":
			want = [["a9", 6182]]
		check(tag + ".forced", JSON.stringify(got) == JSON.stringify(want), [got, want])
		check(tag + ".no_pending", l.pending_force.is_empty())
	XBattleEventRunner.O_RECAST_CASTER = true


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
	# 公共事件 46（一掷千金，战斗场合）里的 250 播放音效：记一条 se 给画面层放，不算没翻译（悟空 dmg1）
	var se := XBattleEventRunner.new(l, [(XDB.rec("CommonEvents", 46).list as Array)[6], {"code": 0, "indent": 0, "parameters": []}])
	se.advance()
	var se_logs := se.take_logs().filter(func(x): return x.get("type") == "se")
	check("se_in_battle", not se_logs.is_empty() and str(se_logs[0].se.name) == "Absorb1" and not se.skipped.any(func(x): return str(x).contains("250")), [se_logs, se.skipped])


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
	for id in ["recast_armor_worn", "recast_armor_half", "recast_weapon", "recast_skill_learned", "recast_skill_not"]:
		_recast(id)
	_recast_target("recast_target_caster", true)
	_recast_target("recast_target_other", true)
	_recast_target("recast_target_zero", true)
	_recast_target("recast_target_other_holder", false)
	_net()
	_slot()
	_inventory()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
