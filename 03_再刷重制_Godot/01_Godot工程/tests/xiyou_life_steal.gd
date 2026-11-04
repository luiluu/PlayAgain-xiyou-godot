extends Node
## 【cc·哪吒·未经审查】YEP_LifeSteal 技能吸血：与 mv_oracle/life_steal_probe.cjs（tests/fixtures/life_steal_oracle.json，正式引擎）86 例逐条比。
## 每例：新局难度 2，角色 1 清技能／装备／状态（mhp 加 50000 免得被夹），敌群 1 第一只当目标（敌人当行动者时反过来打角色 1）；
## 行动技能公式定值、无浮动不暴击，命中固定、闪避固定不中，RecPushState 的掷骰固定成用例的 rnd；比目标、行动者的生命变化与行动者身上被观察的状态。
## 回血溢出被 mhp 夹住的例子（参照行动者回满）只比「也回满」。
const FIXTURE := "res://tests/fixtures/life_steal_oracle.json"
const WATCH := [1561, 1734, 133, 410, 542, 614, 411, 962]
var passed := 0
var total := 0

class FixedLogic extends XBattleLogic:
	var rnd := 0.5
	func _float(reason: String) -> float:
		match reason:
			"hit":
				return 0.0
			"evade", "critical":
				return 0.99
			"life_steal_push", "push_state", "push_self_state":
				return rnd
			"reflection", "counter":
				return 0.0
		return super(reason)

func check(label: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", label, " ", JSON.stringify(detail))

func _ready() -> void:
	_run.call_deferred()

func _states(b: XBattler) -> Array:
	return WATCH.filter(func(id): return b.is_state_affected(id)).map(func(x): return float(x))

func _case(cfg: Dictionary) -> Dictionary:
	var s := XState.new_game(2, 1, [8, 9, 10])
	XState.current = s
	for a in s.members():
		a.equips.clear()
		a.skill_ids.clear()
		a.state_ids.clear()
	s.mv_param_plus["1"] = [float(cfg.get("mhpPlus", 50000)), 0, 0, 0, 0, 0, 0, 0]
	var a: XActor = s.actor(1)
	for sid in cfg.get("skills", []):
		a.learn_skill(int(sid))
	for m in s.members():
		m.param_mark_dirty()
		m.param_refresh()
		m.refresh_passive()
		m.recover_all()
	var logic := FixedLogic.new()
	logic.elite_roll = 100.0
	logic.setup(int(cfg.get("troop", 1)), s)
	logic.rnd = float(cfg.get("rnd", 0.5))
	var foe: XEnemy = logic.enemies[0]
	# 装备：开战整理（setup）会按等级门槛卸掉新局角色 1 穿不上的（参照里也一样，探针另行绕过），所以开战之后再塞进去，吸血只读 equip_list() 的备注
	var slots := a.equip_slots()
	for i in slots.size():
		a.equips.append({})
	for kind in ["weapon", "armor"]:
		if cfg.has(kind):
			var g := XGear.create(kind, int(cfg[kind]), s)
			a.equips[slots.find(1 if kind == "weapon" else int(XDB.rec("Armors", int(cfg[kind])).etypeId))] = g
	a.refresh_passive()
	var enemy_user: bool = str(cfg.get("user", "actor")) == "enemy"
	var user: XBattler = foe if enemy_user else a
	var target: XBattler = a if enemy_user else foe
	for b in [a, foe]:
		b.state_ids.clear()
		b.state_turns.clear()
	for id in cfg.get("userStates", []):
		user.state_ids.append(int(id))
		user.state_turns[int(id)] = 1
	user.hp = 1.0
	var uh = cfg.get("userHp", 1)
	if typeof(uh) == TYPE_STRING:
		user.hp = user.mhp + float(str(uh).substr(3))
	else:
		user.hp = float(uh)
	if cfg.has("targetHp"):
		target.hp = float(cfg.targetHp)
	var sk: Dictionary = XDB.rec("Skills", int(cfg.skill)).duplicate(true)
	sk.damage.formula = str(cfg.get("formula", "1000"))
	sk.damage.formulaProgram = {"version": 1, "status": "pure", "locals": [], "source": {"sha256": "life-steal-constant"}, "result": "completion",
		"steps": [{"op": "expr", "value": {"op": "literal", "value": float(sk.damage.formula)}}]}  # 常数公式（原版 eval 定值），不走技能自己的程序
	sk.damage.variance = 0
	sk.damage.critical = false
	if cfg.has("hitType"):
		sk.hitType = int(cfg.hitType)
	var u_before := user.hp
	var t_before := target.hp
	var second: XBattler = null
	if cfg.get("multi", false) and logic.enemies.size() > 1:
		second = logic.enemies[1]
	if cfg.get("invoke", false):
		logic._invoke(user, sk, target)
	else:
		logic.apply(user, sk, target)
		if second != null:
			logic.apply(user, sk, second)
	return {"u_delta": user.hp - u_before, "t_delta": target.hp - t_before, "u_full": user.hp >= user.mhp, "states": _states(user)}

func _run() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("source", ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("cases", ref.cases.size() == 86, ref.cases.size())
	for c in ref.cases:
		check(c.id + ".native", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var o: Dictionary = c.observed
		var got := _case(c.setup)
		if c.setup.has("weapon") or c.setup.has("armor"):
			# 穿装备后重制的伤害链（装备加成）与参照差一点，不是吸血的事：只比状态，以及吸血量＝自己这一下伤害×30%（技能 182）
			check(c.id + ".states", got.states == o.after.user.states.map(func(x): return float(x)), [got.states, o.after.user.states])
			check(c.id + ".ratio", absf(got.u_delta - floorf(-got.t_delta * 0.3)) <= 1.0, [got.u_delta, got.t_delta])
			continue
		var want_u: float = float(o.userHpDelta)
		var capped: bool = float(o.after.user.hp) >= float(o.after.user.mhp)
		check(c.id + ".user", (got.u_full if capped else is_equal_approx(got.u_delta, want_u)), [got.u_delta, want_u, capped])
		check(c.id + ".target", is_equal_approx(got.t_delta, float(o.targetHpDelta)), [got.t_delta, o.targetHpDelta])
		check(c.id + ".states", got.states == o.after.user.states.map(func(x): return float(x)), [got.states, o.after.user.states])
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
