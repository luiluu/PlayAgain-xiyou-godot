extends Node
## 【cc·悟空·未经审查】伤害／治疗时挂状态（dsPassiveSkill PushState／RecPushState／PushsubState，正式版由 installDamageElementRuntime
## 在结算时按 makeDamageValue 正负挂）：与 mv_oracle/pushstate_probe.cjs（tests/fixtures/pushstate_oracle.json，正式引擎）12 例逐条比。
## 每例：新局难度 2，角色 1 清技能／装备／状态后学被动，角色 8 生命 1 当友方目标，敌群 1 第一只当敌方目标；行动技能公式定 1000、无浮动不暴击，
## 命中、闪避固定成命中，挂状态的掷骰固定成用例的 rnd；比缓存三类条数、正负、前后状态与回合数（已有不重挂＝回合不被重置）。
const FIXTURE := "res://tests/fixtures/pushstate_oracle.json"
const WATCH := [161, 42, 309, 742, 1561]
var passed := 0
var total := 0

## 命中、闪避、挂状态的掷骰固定（其余照本场规则流）
class FixedLogic extends XBattleLogic:
	var rnd := 0.5
	func _float(reason: String) -> float:
		match reason:
			"hit":
				return 0.0
			"evade":
				return 0.99
			"push_state", "push_self_state":
				return rnd
		return super(reason)

func check(label: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", label, " ", JSON.stringify(detail))

func _ready() -> void:
	_run.call_deferred()

func _snap(b: XBattler) -> Dictionary:
	var st := WATCH.filter(func(id): return b.is_state_affected(id))
	var turns := {}
	for id in st:
		turns[str(id)] = float(b.state_turns.get(id, 0))
	return {"states": st.map(func(x): return float(x)), "turns": turns}

func _case(cfg: Dictionary) -> Dictionary:
	var s := XState.new_game(2, 1, [8, 9, 10])
	XState.current = s
	for a in s.members():
		a.equips.clear()
		a.skill_ids.clear()
		a.state_ids.clear()
	var a: XActor = s.actor(1)
	for sid in cfg.get("skills", []):
		a.learn_skill(int(sid))
	for m in s.members():
		m.param_mark_dirty()
		m.refresh_passive()
		m.recover_all()
	var logic := FixedLogic.new()
	logic.elite_roll = 100.0
	logic.setup(1, s)
	logic.rnd = float(cfg.rnd)
	a.refresh_passive()
	var ally: XActor = s.actor(8)
	ally.hp = 1.0
	var foe: XEnemy = logic.enemies[0]
	var t: XBattler = ally if str(cfg.target) == "ally" else foe
	for b in [a, t]:
		b.state_ids.clear()
		b.state_turns.clear()
	for id in cfg.get("pre", []):
		t.state_ids.append(int(id))
		t.state_turns[int(id)] = 1
	var sk: Dictionary = XDB.rec("Skills", int(cfg.skill)).duplicate(true)
	sk.damage.formula = "1000"
	sk.damage.variance = 0
	sk.damage.critical = false
	var c := a.passive_cache()
	var before := {"user": _snap(a), "target": _snap(t)}
	logic.apply(a, sk, t)
	return {"sign": signf(logic._push_sign), "before": before, "after": {"user": _snap(a), "target": _snap(t)},
		"cache": {"push": float(c.pushStates.size()), "rec": float(c.recPushStates.size()), "self": float(c.pushSelfStates.size())}}

func _run() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("source", ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("cases", ref.cases.size() == 12, ref.cases.size())
	for c in ref.cases:
		check(c.id + ".native", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var o: Dictionary = c.observed
		var got := _case(c.setup)
		check(c.id + ".cache", got.cache == o.cache, [got.cache, o.cache])
		check(c.id + ".sign", got.sign == signf(float(o.value)), [got.sign, o.value])
		check(c.id + ".after", got.after.user.states == o.after.user.states and got.after.target.states == o.after.target.states, [got.after, o.after])
		if not c.setup.get("pre", []).is_empty():
			check(c.id + ".no_reapply", got.after.target.turns == o.after.target.turns, [got.after.target.turns, o.after.target.turns])
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
