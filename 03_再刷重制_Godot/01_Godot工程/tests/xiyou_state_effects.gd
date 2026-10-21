extends Node
## 状态效果阶段钩子第一期（XStateEffects）：分发次序逐例对照 mv_oracle/state_effects_probe.cjs（generated/oracle/state_effects.json）。
## 参照往冻结版注入测试状态 T（每个 Custom Effect 槽只记录），在真实 BattleManager 流程里记 phase、状态、持有者与 a／b；
## 这里注入同形的测试状态（每个 phase 一个 js 块），用 XStateEffects.observer 记 Godot 的分发，按同一用例比序列：
## - 只比第一期接上的 phase（battle、turn_start、regenerate、turn_end、action_start、initiate／select／deselect／conclude、胜逃败）；
##   参照里 confirm／react／respond／establish、apply／remove／leave 属后续期，比前先滤掉。
## - action_end：参照里 OTB 行动结束从不触发，Godot 也不分发（逐例确认参照没有、Godot 也没有）。
## - KRZ 热缓存（回合末到期移除后再生／回合结束仍对它触发；加状态不 refresh 仍按旧列表）：Godot 第一期按当前状态分发，
##   这类行单列为「热缓存差异」逐条核对，不算通过也不算失败（要 battler.gd 的 dirty 跟踪，见交付单）。
## - 开战：参照的敌人在 setup 之后才加 T；Godot 的敌人在 setup 内才建，只比我方部分，另查开战标签加的状态不跑本次 battle。
## - 未翻译诊断：分发到 js 块时记进 XStateEffects.diagnostics（不静默跳过）。
var results := []
var trace := []
const PHASES := {"battle": "battle", "turnStartState": "turn_start", "turnEndState": "turn_end", "regenerateState": "regenerate",
	"actionStartState": "action_start", "initiateState": "initiate", "selectState": "select", "deselectState": "deselect",
	"concludeState": "conclude", "victory": "victory", "escape": "escape", "defeat": "defeat", "actionEndState": "action_end"}
var T := 0
var EXPIRE := 0
var MRF := 0
var CNT := 0
var EVA := 0
## 参照测试状态编号 → Godot 测试状态编号（按参照 fixture 的名字对应）
var ids := {}


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(900))


func _ready() -> void:
	_run.call_deferred()


func _state(name: String, phases: Array, extra := {}) -> int:
	var t: Array = XDB.table("States")
	var id := t.size()
	var rec := {"id": id, "name": name, "traits": [], "note": "", "meta": {}, "iconIndex": 0, "restriction": 0, "priority": 50,
		"autoRemovalTiming": 0, "minTurns": 1, "maxTurns": 1, "removeAtBattleEnd": false,
		"effects": phases.map(func(p): return {"phase": p, "op": "js", "code": "// 记录"})}
	rec.merge(extra, true)
	t.append(rec)
	return id


func _key(b: XBattler, logic: XBattleLogic) -> String:
	return "a%d" % (b as XActor).actor_id if b is XActor else "e%d" % logic.enemies.find(b)


func _observe(logic: XBattleLogic) -> void:
	trace.clear()
	XStateEffects.observer = func(phase: String, sid: int, holder: XBattler, ctx: Dictionary) -> void:
		var row := [phase, sid, _key(holder, logic)]
		if ctx.has("attacker"):
			row.append_array([_key(ctx.attacker, logic), _key(ctx.defender, logic)])
		trace.append(row)


## 参照序列：只留第一期 phase 的 fx 行，换成 Godot 名；Action 版带 [a, b]。热缓存行（该持有者已 remove 该状态后又触发）单列
func _want(o: Dictionary) -> Dictionary:
	var rows := []
	var stale := []
	var removed := {}
	for r in o.log:
		if r[0] != "fx":
			continue
		var phase := str(r[1])
		var sid := int(ids.get(int(r[2]), int(r[2])))
		var holder := str(r[3])
		if phase == "removeState":
			removed["%d|%s" % [sid, holder]] = true
		elif phase == "addState":
			removed.erase("%d|%s" % [sid, holder])
		if not PHASES.has(phase):
			continue
		var g: String = PHASES[phase]
		var row := [g, sid]
		if g in XStateEffects.ACTION_PHASES:
			# Action 版持有者：initiate／conclude 是行动者 a，select／deselect 是目标 b
			row.append(str(r[3]) if g in ["initiate", "conclude"] else str(r[4]))
			row.append_array([str(r[3]), str(r[4])])
		else:
			row.append(holder)
		if removed.has("%d|%s" % [sid, row[2]]):
			stale.append(row)
		else:
			rows.append(row)
	return {"rows": rows, "stale": stale}


func _new_logic(ref_seed: int) -> XBattleLogic:
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	s.random_master = XRandomStream.hex64(ref_seed)
	for a in s.members():
		a.refresh_passive()
		a.recover_all()
	var logic := XBattleLogic.new()
	logic.elite_roll = 100.0
	logic.setup(2, s)
	return logic


func _compare(name: String, o: Dictionary, extra_check := Callable()) -> void:
	var w := _want(o)
	check(name + ".sequence", trace == w.rows, {"godot": trace, "mv": w.rows})
	# 热缓存行 Godot 必须一条都没有（按当前状态分发）；参照里有几条照记
	for row in w.stale:
		check(name + ".stale_absent.%s" % JSON.stringify(row), not trace.has(row), row)
	if not w.stale.is_empty():
		print("热缓存差异 ", name, " ", JSON.stringify(w.stale))
	if extra_check.is_valid():
		extra_check.call()


func _run() -> void:
	var ref = XDB.load_json("oracle/state_effects.json")
	if not (ref is Dictionary and ref.has("cases")):
		check("oracle_present", false)
		return finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	var cases := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		cases[c.id] = c
	var all_phases: Array = PHASES.values()
	T = _state("测试·阶段记录", all_phases)
	EXPIRE = _state("测试·一回合到期", all_phases, {"autoRemovalTiming": 2})
	MRF = _state("测试·魔法反射", [], {"traits": [{"code": 22, "dataId": 5, "value": 1.0}]})
	CNT = _state("测试·反击", [], {"traits": [{"code": 22, "dataId": 6, "value": 1.0}]})
	EVA = _state("测试·魔法回避", [], {"traits": [{"code": 22, "dataId": 4, "value": 1.0}]})
	for st in cases["fixture"].observed.states:
		var mine := {"测试·阶段记录": T, "测试·一回合到期": EXPIRE, "测试·魔法反射": MRF, "测试·反击": CNT, "测试·魔法回避": EVA}
		if mine.has(str(st.name)):
			ids[int(st.id)] = mine[str(st.name)]
	var o: Dictionary
	var logic: XBattleLogic
	# ---- 开战：我方 a1、a8 带 T；Godot 敌人在 setup 内才建，只比我方部分 ----
	o = cases["battle.start"].observed
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	s.random_master = XRandomStream.hex64(4301)
	for a in s.members():
		a.learn_skill(6168)  # 天道诅咒：开战标签加 995
		a.refresh_passive()
		a.add_state(T)
	logic = XBattleLogic.new()
	trace.clear()
	XStateEffects.observer = func(phase, sid, holder, ctx): trace.append([phase, sid, "a%d" % holder.actor_id if holder is XActor else "e"])
	logic.setup(2, s)
	var party_want: Array = _want(o).rows.filter(func(r): return str(r[2]).begins_with("a"))
	check("battle.start.party", trace.filter(func(r): return str(r[2]).begins_with("a")) == party_want, {"godot": trace, "mv": party_want})
	check("battle.start.ds_after", logic.actors[0].state_ids.has(995) and not trace.any(func(r): return int(r[1]) == 995), trace)
	# ---- 行动链 ----
	for id in ["action.attack", "action.miss", "action.reflect", "action.guard", "action.forced", "action.counter"]:
		o = cases[id].observed
		logic = _new_logic(4302)
		var a: XBattler = logic.actors[0]
		var e: XBattler = logic.enemies[0]
		a.add_state(T)
		e.add_state(T)
		var skill := XDB.rec("Skills", 1)
		match id:
			"action.miss":
				e.add_state(EVA)
			"action.reflect":
				e.add_state(MRF)
			"action.counter":
				e.add_state(CNT)
				skill = skill.duplicate(true)
				skill.hitType = 1
			"action.guard":
				skill = XDB.rec("Skills", 2)
		_observe(logic)
		if id == "action.forced":
			logic.execute(a, skill, e, true)
		else:
			logic.act(a, skill, e)
		_compare(id, o)
		check(id + ".no_action_end", not trace.any(func(r): return r[0] == "action_end")
			and not o.log.any(func(r): return r[0] == "fx" and r[1] == "actionEndState"), trace)
	# ---- 回合开始／结束（含一回合到期的 EXPIRE）----
	o = cases["turn.start_end"].observed
	logic = _new_logic(4303)
	logic.actors[0].add_state(T)
	logic.enemies[0].add_state(T)
	logic.enemies[0].add_state(EXPIRE)
	_observe(logic)
	logic.start_turn()
	logic.end_turn()
	_compare("turn.start_end", o, func(): check("turn.expired", not logic.enemies[0].state_ids.has(EXPIRE), logic.enemies[0].state_ids))
	# ---- 胜／逃／败：只我方，原 endBattle 之前 ----
	for pair in [["end.victory", 0], ["end.escape", 1], ["end.defeat", 2]]:
		o = cases[pair[0]].observed
		logic = _new_logic(4304)
		for a in logic.actors:
			a.add_state(T)
		logic.enemies[0].add_state(T)
		_observe(logic)
		logic.end_battle(int(pair[1]))
		_compare(pair[0], o)
	# ---- 未翻译诊断：上面分发到的 js 块都已登记 ----
	check("diagnostics.recorded", XStateEffects.diagnostics.any(func(d): return int(d.state) == T and d.kind == "untranslated"), XStateEffects.diagnostics.slice(0, 5))
	check("never_fired_listed", XStateEffects.NEVER_FIRED.has("action_end") and XStateEffects.NEVER_FIRED.has("crit"))
	XStateEffects.observer = Callable()
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
