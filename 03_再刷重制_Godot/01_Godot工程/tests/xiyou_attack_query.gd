extends Node
## 普攻技能查询（attack_query_probe.cjs）：XBattler.attack_skill_id／is_attack 按原版 YEP_WeaponUnleash 与甚尔、宿傩运行时。
## 每例照参照摆好角色或敌人（卸下全部装备、装上、学技能、加状态，再卸下不能装备的），逐项比：
## attackSkillId、canAttack、普攻追加次数、拿替换后的技能与技能 1 各问 isAttack 与次数（Game_Action.numRepeats 的 MV 本体）、
## 指令窗「攻击」的名字与可用、异化祈祷／逆骨的就绪（沙僧 P2-1：154 装武器 77 时攻击是 5769，逆骨未就绪）。

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


static func norm(v):
	if v is int or v is float:
		return float(v)
	if v is Array:
		return v.map(func(x): return norm(x))
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(k)] = norm(v[k])
		return out
	return v


func _run() -> void:
	var ref = XDB.load_json("oracle/attack_query.json")
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return _finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	check("oracle_clean", ref.cases.all(func(c): return c.errors.is_empty()), ref.cases.filter(func(c): return not c.errors.is_empty()).map(func(c): return c.id))
	XAlienation.force_roll = 0.5
	XGear.force_roll = 0.5
	for c in ref.cases:
		if c.observed == null:
			continue
		var got := _measure(c)
		var want: Dictionary = norm(c.observed)
		# numRepeats 含 dsPassiveSkill 等改写（被动 atkk／再动几率），本专项只比 MV 本体 mvRepeats
		for act in want.actions:
			act.erase("numRepeats")
		for k in want:
			check(str(c.id) + "." + str(k), norm(got.get(k)) == want[k], {"got": got.get(k), "want": want[k]})
	_finish()


func _measure(c: Dictionary) -> Dictionary:
	var spec: Dictionary = c.setup
	var s := XState.new_game_blank()
	var logic := XBattleLogic.new()
	logic.state = s
	if str(c.id).begins_with("enemy."):
		var e := XEnemy.new().setup(int(spec.enemy), s.difficulty)
		for id in spec.get("states", []):
			e.add_state(int(id))
		var out := _common(logic, e)
		out.states = e.states().map(func(x): return int(x.id))
		out.equips = []
		return out
	s.add_actor(int(spec.actor))
	var a := s.actor(int(spec.actor))
	for n in a.equips.size():
		a.equips[n] = null
	a.refresh_passive()
	a.recover_all()  # 原版新局入队时回满，卸下装备后封顶到空手上限；之后装备、加状态都不补（MV recoverAll 也会清状态）
	for id in spec.get("skills", []):
		a.learn_skill(int(id))
	for eq in spec.get("equips", []):
		var kind := "weapon" if str(eq[0]) == "w" else "armor"
		var item := XGear.create(kind, int(eq[1]), s)
		var slot := 0 if kind == "weapon" else a.equip_slots().find(int(item.etypeId))
		a.equips[slot] = item
	for id in spec.get("states", []):
		a.add_state(int(id))
	a.release_unequippable()  # Game_Actor.refresh：卸下不能装备的
	a.refresh_passive()
	var out := _common(logic, a)
	out.states = a.states().map(func(x): return int(x.id))
	out.equips = a.equips.map(func(e): return 0 if e == null or e.is_empty() else int(e.base))
	out.command = {"name": a.attack_command_text(), "symbol": "attack", "enabled": logic.can_use(a, a.attack_skill())}
	out.ready = {}
	for k in ["prayer", "inversebone"]:
		out.ready[k] = XAlienation.ready(s, a, XAlienation.create(s, "w", 1044, "boss", k).ok)
	return out


func _common(logic: XBattleLogic, b: XBattler) -> Dictionary:
	var id := b.attack_skill_id()
	var actions := []
	for sid in ([id] if id == 1 else [id, 1]):
		var sk := XDB.rec("Skills", sid)
		actions.append({"skill": sid, "isAttack": b.is_attack(sk), "mvRepeats": XBattleLogic.attack_repeats(b, sk, int(sk.repeats))})
	return {"attackSkillId": id, "canAttack": logic.can_use(b, b.attack_skill()), "attackTimesAdd": b.attack_times_add(), "actions": actions}


func _finish() -> void:
	XAlienation.force_roll = -1.0
	XGear.force_roll = -1.0
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
