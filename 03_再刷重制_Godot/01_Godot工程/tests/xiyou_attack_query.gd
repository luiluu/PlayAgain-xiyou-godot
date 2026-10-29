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
		if str(c.id).begins_with("skip."):
			_skip(c)
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
	# 挂机 makeAction（关智能AI）：没排表退回 attackSkillId；排表写 1 也换成 attackSkillId
	XConfig.ensure_loaded()
	var smart = XConfig._values.get("codexSmartAI")
	XConfig._values["codexSmartAI"] = false
	logic.turn = 0
	out.hangUpAction = int(logic.auto_battle_action(a)[0].id)
	XHangUpAuto.data(s, "ActSkill")[a.display_name() + XHangUpAuto.three(logic.turn)] = 1
	out.hangUpScheduled = int(logic.auto_battle_action(a)[0].id)
	XConfig._values["codexSmartAI"] = smart
	out.ready = {}
	for k in ["prayer", "inversebone"]:
		out.ready[k] = XAlienation.ready(s, a, XAlienation.create(s, "w", 1044, "boss", k).ok)
	return out


## skip 组：敌人行动无效（列表空、行动时不能用）整次跳过；角色（OTB）不看 isValid 照原样执行；禁用号角的 useItem 被挡（不扣），
## 菜单动作窗「使用」灰、战斗物品窗不列。比：行动记录里的技能（enemy started／actor used）、MP、物品数、canUse 与两个窗。
func _skip(c: Dictionary) -> void:
	var spec: Dictionary = c.setup
	var want: Dictionary = norm(c.observed)
	var got := {}
	var s := XState.new_game(3, 1, [8, 9, 10])
	if str(c.id) == "skip.item1-menu-control":
		s.gain_item(1, 1)
		got.menuEnabled = _menu_usable(s, XDB.rec("Items", 1))
		got.partyCanUse = got.menuEnabled
	else:
		var logic := XBattleLogic.new()
		logic.setup(int(spec.troop), s)
		var a: XActor = logic.actors[0]
		var e: XEnemy = logic.enemies[0]
		var cid := str(c.id)
		if cid.begins_with("skip.enemy"):
			var cmd := []
			if cid.begins_with("skip.enemy73"):
				XConfig.ensure_loaded()
				var smart = XConfig._values.get("codexSmartAI")
				XConfig._values["codexSmartAI"] = bool(spec.smartAI)
				cmd = logic.decide(e)
				XConfig._values["codexSmartAI"] = smart
				got.enemyId = int(e.enemy_id)
				got.made = [0 if cmd[0] == null else int(cmd[0].id)]
			elif cid == "skip.enemy1-mp-short":
				var sk := XDB.rec("Skills", int(spec.skill))
				e.mp = float(want.mpCost) - 1.0
				cmd = [sk, a]
			else:
				cmd = [e.attack_skill(), a]
			var mp := e.mp
			var tp := e.tp
			got.started = _acted(logic.act(e, cmd[0], cmd[1]))
			got.mp = [mp, e.mp]
			got.tp = [tp, e.tp]
		else:
			var item := {}
			var skill := a.attack_skill()
			if cid == "skip.actor1-item-gone":
				s.items.erase(1)
				item = XDB.rec("Items", 1)
				skill = item
			elif cid == "skip.actor1-mp-short":
				skill = XDB.rec("Skills", int(spec.skill))
				a.mp = float(want.mpCost) - 1.0
				got.canUse = logic.can_use(a, skill)
			elif cid.begins_with("skip.horn"):
				item = XDB.rec("Items", int(spec.item))
				s.items[int(spec.item)] = 1
				skill = item
				got.actorCanUse = logic.can_use(a, item)
				got.battleListed = logic.battle_items().any(func(x): return int(x.id) == int(spec.item))
				got.menuEnabled = _menu_usable(s, item)
				got.partyCanUse = got.menuEnabled
			var mp := a.mp
			var count := s.item_count(int(item.id)) if not item.is_empty() else 0
			var logs := logic.act(a, skill, e)
			got.used = _acted(logs)
			got.mp = [mp, a.mp]
			if cid == "skip.actor1-mp-short":
				# 付费后立即 refresh（YEP useItem）：行动记录的快照里 MP 已截到 0（沙僧第六期 P1：原先记 -1）
				var act: Array = logs.filter(func(r): return r.get("type") == "action")
				var snap = act[0].views.get(a, {}).get("mp") if not act.is_empty() else null
				check(cid + ".actionSnapshotMp", snap != null and float(snap) == float(want.mp[1]), {"got": snap, "want": want.mp[1]})
			got.count = [count, s.item_count(int(item.id))] if not item.is_empty() else null
	for k in ["otb", "phase", "left", "valid", "forcedValid", "occasion", "actionList", "mpCost"]:
		want.erase(k)
	# MP／TP 只比这次行动的付费（前减后）：开战初值两边摆法不同；对照例原版只记 startAction 没往下打，只比 started
	for k in ["mp", "tp"]:
		if want.has(k):
			if str(c.id) == "skip.enemy1-attack-control":
				want.erase(k)
				continue
			want[k] = want[k][0] - want[k][1]
			got[k] = got[k][0] - got[k][1]
	for k in want:
		check(str(c.id) + "." + str(k), norm(got.get(k)) == want[k], {"got": got.get(k), "want": want[k]})


## act 记录里真正开始的行动（startAction／useItem）：type action 的技能编号
static func _acted(logs: Array) -> Array:
	return logs.filter(func(r): return r.get("type") == "action").map(func(r): return int(r.skill.id))


## 菜单物品动作窗「使用」（Window_ItemActionCommand.isEnabled＝$gameParty.canUse）
static func _menu_usable(s: XState, item: Dictionary) -> bool:
	var before := XState.current
	XState.current = s
	var scene := XItemScene.new()
	var ok: bool = scene._usable(item)
	scene.free()
	XState.current = before
	return ok


func _common(logic: XBattleLogic, b: XBattler) -> Dictionary:
	var id := b.attack_skill_id()
	var actions := []
	for sid in ([id] if id == 1 else [id, 1]):
		var sk := XDB.rec("Skills", sid)
		actions.append({"skill": sid, "isAttack": b.is_attack(sk), "mvRepeats": XBattleLogic.attack_repeats(b, sk, int(sk.repeats))})
	# setAttack（反击 invokeCounterAttack、手动「攻击」、不能用时退回）：角色走 decide 的非自动分支，敌人是反击者的 attack_skill
	var set_attack := int(logic.decide(b)[0].id) if b is XActor else int(b.attack_skill().id)
	return {"attackSkillId": id, "setAttack": set_attack, "canAttack": logic.can_use(b, b.attack_skill()), "attackTimesAdd": b.attack_times_add(), "actions": actions}


func _finish() -> void:
	XAlienation.force_roll = -1.0
	XGear.force_roll = -1.0
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
