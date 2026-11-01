extends Node
## 【cc·悟空·未经审查】伤害／治疗时挂状态（dsPassiveSkill PushState／RecPushState／PushsubState，正式版由 installDamageElementRuntime
## 在结算时按 makeDamageValue 正负挂）：与 mv_oracle/pushstate_probe.cjs（tests/fixtures/pushstate_oracle.json，正式引擎）23 例逐条比（含装备上的标签：武器 1706、防具 4966；order.1580 记原版挂状态在 React 之前；invoke.reflect／counter／cover 走 _invoke：反射回自己时挂给自己、反击由反击者挂、掩护挂给代受者）。
## void.*（审查 17 P2）：归墟角色的攻击伤害原版照挂（排除写错），O-待定开关 VOID_PUSH_EXCLUDE 两支都跑；plain.1580.apply 是整条 apply 的对照。
## 每例：新局难度 2，角色 1 清技能／装备／状态后学被动，角色 8 生命 1 当友方目标，敌群 1 第一只当敌方目标；行动技能公式定 1000、无浮动不暴击，
## 命中、闪避固定成命中，挂状态的掷骰固定成用例的 rnd；比缓存三类条数、正负、前后状态与回合数（已有不重挂＝回合不被重置）。
const FIXTURE := "res://tests/fixtures/pushstate_oracle.json"
const WATCH := [161, 42, 309, 742, 1561, 521, 1734]
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
	# 装备用例：给角色 1 穿上一件带标签的武器／防具实例（参照里 gainItem 后 changeEquip）
	var slots := a.equip_slots()
	for i in slots.size():
		a.equips.append({})
	for kind in ["weapon", "armor"]:
		if cfg.has(kind):
			var g := XGear.create(kind, int(cfg[kind]), s)
			a.equips[slots.find(1 if kind == "weapon" else int(XDB.rec("Armors", int(cfg[kind])).etypeId))] = g
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
	if cfg.get("void", false):
		XAlienBattle._store(logic).party[a] = {"affix": "void", "config": {}}  # 归墟（战斗中锁定的词条）
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
	return {"sign": signf(logic._push_sign), "void": XAlienBattle.has(a, "void"), "before": before, "after": {"user": _snap(a), "target": _snap(t)},
		"cache": {"push": float(c.pushStates.size()), "rec": float(c.recPushStates.size()), "self": float(c.pushSelfStates.size())}}

func _trait_state(code: int, data_id: int) -> int:
	var states: Array = XDB.table("States")
	var id := states.size()
	states.append({"id": id, "name": "挂状态参照", "note": "", "meta": {}, "traits": [{"code": code, "dataId": data_id, "value": 1.0}], "effects": [],
		"restriction": 0, "priority": 50, "minTurns": 1, "maxTurns": 1})
	return id

## 探针 invoke.*：reflect 角色 1（1580，生命加厚）对魔法反射 100% 的敌人用魔法版技能 1；counter 敌人打反击率 100% 的角色 1
func _invoke_case(cfg: Dictionary) -> Dictionary:
	var s := XState.new_game(2, 1, [8, 9, 10])
	XState.current = s
	for m in s.members():
		m.equips.clear()
		m.skill_ids.clear()
		m.state_ids.clear()
	s.mv_param_plus["1"] = [100000, 0, 0, 0, 0, 0, 0, 0]
	var a: XActor = s.actor(1)
	a.learn_skill(1580)
	for m in s.members():
		m.param_mark_dirty()
		m.param_refresh()
		m.refresh_passive()
		m.recover_all()
	var logic := FixedLogic.new()
	logic.elite_roll = 100.0
	logic.setup(2 if str(cfg.kind) == "cover" else 1, s)
	logic.rnd = float(cfg.rnd)
	var foe: XEnemy = logic.enemies[0]
	var guard: XEnemy = logic.enemies[1] if logic.enemies.size() > 1 else null
	for b in [a, foe] + ([guard] if guard else []):
		b.state_ids.clear()
		b.state_turns.clear()
	var sk: Dictionary = XDB.rec("Skills", 1).duplicate(true)
	sk.damage.formula = "1000"
	sk.damage.variance = 0
	sk.damage.critical = false
	if str(cfg.kind) == "reflect":
		foe.state_ids.append(_trait_state(22, 5))
		sk.hitType = 2
		logic._invoke(a, sk, foe)
	elif str(cfg.kind) == "cover":
		guard.state_ids.append(_trait_state(62, 2))  # 特殊旗标：掩护
		foe.hp = 1.0
		sk.hitType = 1
		logic._invoke(a, sk, foe)
	else:
		a.state_ids.append(_trait_state(22, 6))
		sk.hitType = 1
		logic._invoke(foe, sk, a)
	return {"actor": _snap(a), "foe": _snap(foe), "guard": _snap(guard) if guard else null}

func _run() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("source", ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("cases", ref.cases.size() == 23, ref.cases.size())
	for c in ref.cases:
		check(c.id + ".native", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var o: Dictionary = c.observed
		if str(c.id).begins_with("invoke."):
			var inv := _invoke_case(c.setup)
			check(c.id + ".states", inv.actor.states == o.actor.states and inv.foe.states == o.foe.states
				and (o.guard == null or inv.guard.states == o.guard.states), [inv, o.actor, o.foe, o.guard])
			continue
		if str(c.id).begins_with("void."):
			# O-待定（审查 17 P2）：关掉开关照原版（归墟攻击照挂），再开着看攻击伤害不挂、治疗照挂
			XBattleLogic.VOID_PUSH_EXCLUDE = false
			var native := _case(c.setup)
			XBattleLogic.VOID_PUSH_EXCLUDE = true
			check(c.id + ".void", native.void and bool(o.voidActive), [native.void, o.voidActive])
			check(c.id + ".native", native.after.user.states == o.after.user.states and native.after.target.states == o.after.target.states, [native.after, o.after])
			var fixed := _case(c.setup)
			var attack: bool = int(XDB.rec("Skills", int(c.setup.skill)).damage.type) in [1, 2, 5, 6]
			var want: Dictionary = o.before if attack else o.after
			check(c.id + ".o-void", fixed.after.user.states == want.user.states and fixed.after.target.states == want.target.states, [fixed.after, want])
			continue
		var got := _case(c.setup)
		if str(c.id).begins_with("order."):
			# 原版 addState 在 React 之前（log：add → react）；重制由 XDamage.finish 在 React 前调，这里只比结果
			check(c.id + ".log", o.log == ["add:161", "react", "pre-done"], o.log)
			check(c.id + ".after", got.after.target.states == o.out.target.states, [got.after, o.out])
			continue
		check(c.id + ".cache", got.cache == o.cache, [got.cache, o.cache])
		check(c.id + ".sign", got.sign == signf(float(o.value)), [got.sign, o.value])
		check(c.id + ".after", got.after.user.states == o.after.user.states and got.after.target.states == o.after.target.states, [got.after, o.after])
		if not c.setup.get("pre", []).is_empty():
			check(c.id + ".no_reapply", got.after.target.turns == o.after.target.turns, [got.after.target.turns, o.after.target.turns])
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
