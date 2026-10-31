extends Node
## 【Claude·悟空·未经审查】战斗核心缺口：与 battle_gaps_probe（tests/fixtures/battle_gaps_oracle.json，正式引擎）逐例比对。
## ① 百分比 MP 消耗：43 个带 <MP Cost: x%> 的技能 × 基础／大 MP／消耗率 0.63／减耗 30／加耗 600（比例部分下限 −100%），
##    另核备注边界 7225（7.5% 原版不认）与 9944（<TP Cost: 200> 改基础 TP）；比实扣 XBattleLogic.skill_cost 与说明卡 XCharacterHelp._cost。
## ② 角色能力上限：8 项都夹 99999999（加值超、比率叠满后超），饿狼 173 夹 999999999999；比 param、mhp／mmp。
## ③ 技能 HP 费用：15 个带 <HP Cost: n>／<HP Cost: n%> 的技能，比费用、生命为满／等于费用／费用＋1 时能否付（can_use 的费用部分）、付费后的生命。
## ④ 战斗奖励：6 个难度 × 3 个敌群，另有 passiveGRUP 连乘、神话、金钱双倍；比 XBattleLogic.rewards 的经验与金钱（×8／×5，难度倍率不生效）。
const FIXTURE := "res://tests/fixtures/battle_gaps_oracle.json"
var passed := 0
var total := 0

class CostActor extends XActor:
	var forced_mcr := -1.0
	func sparam(i: int) -> float:
		return forced_mcr if i == 4 and forced_mcr >= 0.0 else super(i)

func check(label: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	elif total - passed <= 30:
		print("FAIL ", label, " ", JSON.stringify(detail))

func _ready() -> void:
	_run.call_deferred()

func _state(note: String, traits: Array) -> int:
	var states: Array = XDB.table("States")
	var id := states.size()
	var meta := {}
	for m in RegEx.create_from_string("<([^<>:]+):([^<>]*)>").search_all(note):
		meta[m.get_string(1)] = m.get_string(2)
	states.append({"id": id, "name": "战斗缺口参照", "note": note, "meta": meta, "traits": traits, "effects": [],
		"restriction": 0, "priority": 50, "minTurns": 1, "maxTurns": 1})
	return id

## 探针 bare()：清技能、状态、装备与永久加值，再按用例写加值与状态
func _actor(id: int, plus: Array, state_ids: Array) -> CostActor:
	var s := XState.new_game_blank()
	s.mv_param_plus[str(id)] = plus
	var a := CostActor.new()
	a.setup(id)
	s.actors[id] = a
	a.equips.clear()
	a.skill_ids.clear()
	a.state_ids.clear()
	a.state_ids.append_array(state_ids)
	a.param_mark_dirty()
	a.param_refresh()
	a.refresh_passive()
	return a

## 探针 ④：开局四人清技能、装备、状态，按用例学被动；敌人全部计入（全灭后结算）
func _reward(cfg: Dictionary) -> Array:
	var s := XState.new_game(int(cfg.difficulty), 1, [8, 9, 10])
	var skills: Dictionary = cfg.get("skills", {})
	for a in s.members():
		a.equips.clear()
		a.skill_ids.clear()
		a.state_ids.clear()
		for sid in skills.get(str(a.actor_id), []):
			a.learn_skill(int(sid))
		a.param_mark_dirty()
		a.refresh_passive()
	var logic := XBattleLogic.new()
	logic.elite_roll = 100.0
	logic.setup(int(cfg.troop), s)
	for i in cfg.get("elite", []):
		logic.enemies[int(i)].elite = true
	if cfg.get("goldDouble", false):
		logic.actors[0].state_ids.append(_state("", [{"code": 64, "dataId": 4, "value": 1}]))
	var r := logic.rewards()
	return [int(r.exp), int(r.gold)]

func _run() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("source", ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("percent_skills", ref.percentSkills.size() == 43 and not ref.percentSkills.has(7225.0), ref.percentSkills.size())
	var logic := XBattleLogic.new()
	var count := {"cost": 0, "cap": 0, "hp": 0, "reward": 0}
	for c in ref.cases:
		check(c.id + ".native", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var o: Dictionary = c.observed
		if str(c.id).begins_with("cost."):
			count.cost += 1
			var plus := [0, float(c.setup.mmpPlus), 0, 0, 0, 0, 0, 0]
			var a := _actor(1, plus, c.setup.notes.map(func(n): return _state(n, [])))
			if c.setup.has("mcr"):
				a.forced_mcr = float(c.setup.mcr)
			var sk := XDB.rec("Skills", int(c.setup.skill))
			check(c.id + ".mmp", a.mmp == float(o.mmp), [a.mmp, o.mmp])
			var got := logic.skill_cost(a, sk)
			check(c.id + ".cost", int(got.mp) == int(o.mp) and int(got.tp) == int(o.tp), [got, o.mp, o.tp])
			check(c.id + ".help", XCharacterHelp._cost(a, sk, "MP") == int(o.mp) and XCharacterHelp._cost(a, sk, "TP") == int(o.tp))
		elif str(c.id).begins_with("hp."):
			count.hp += 1
			var a := _actor(1, [float(c.setup.mhpPlus), 0, 0, 0, 0, 0, 0, 0], [])
			a.recover_all()
			a.tp = 100.0
			var sk := XDB.rec("Skills", int(c.setup.skill))
			var cost := XBattleLogic.skill_hp_cost(a, sk)
			check(c.id + ".cost", cost == int(o.cost) and a.mhp == float(o.mhp), [cost, o.cost, a.mhp, o.mhp])
			var pay := {}
			for k in ["full", "equal", "plus1"]:
				a.hp = a.mhp if k == "full" else float(cost) + (1.0 if k == "plus1" else 0.0)
				var mc := logic.skill_cost(a, sk)
				pay[k] = XBattleLogic.can_pay_hp(a, sk) and a.mp >= mc.mp and a.tp >= mc.tp  # canPaySkillCost：HP、MP、TP
			check(c.id + ".canPay", pay == o.canPay, [pay, o.canPay])
			a.hp = a.mhp
			logic.pay_hp(a, sk)
			check(c.id + ".afterPay", a.hp == float(o.afterPay), [a.hp, o.afterPay])
		elif str(c.id).begins_with("reward."):
			count.reward += 1
			var got := _reward(c.setup)
			check(c.id + ".reward", got == [int(o.exp), int(o.gold)], [got, o.exp, o.gold, o.grup])
		elif str(c.id).begins_with("cap."):
			count.cap += 1
			var p := float(c.setup.plus)
			var st := []
			if float(c.setup.rate) != 1.0:
				var traits := []
				for i in 8:
					traits.append({"code": XBattler.TRAIT_PARAM, "dataId": i, "value": float(c.setup.rate)})
				st.append(_state("", traits))
			var a := _actor(int(c.setup.actor), [p, p, p, p, p, p, p, p], st)
			var params := []
			for i in 8:
				params.append(a.param(i))
			check(c.id + ".param", params == o.param.map(func(v): return float(v)), [params, o.param])
			check(c.id + ".max", a.param_max(0) == float(o.max[0]), [a.param_max(0), o.max[0]])
			check(c.id + ".res", [a.mhp, a.mmp] == [float(o.mhp), float(o.mmp)], [a.mhp, a.mmp, o])
	check("hp_skills", ref.hpSkills.size() == 15, ref.get("hpSkills"))
	check("counts", count.cost == 43 * 5 + 2 and count.cap == 5 and count.hp == 15 and count.reward == 21, count)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
