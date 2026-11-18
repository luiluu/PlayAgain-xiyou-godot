extends Node
## 【cc·T162】丙档标尺工具（tests/virtual_player/c_tier.gd）的纯函数和小场景：取中位、抽队（3 强者＋1 弱者、种子定住）、掷装备堆（种子定住、等级不越层、守层者固定掉落进堆）、
## 分装备（一件只给一个人、都穿得上、得分合计对）、木桩敌群（多敌不含守层者／首领）、建档（等级、法宝、天平酒）、一场木桩战（免暴击木桩伤害更低、每回合有数）。
## 不量数：量数在 c_tier.tscn（单独跑）。工具只在测试目录、不碰游戏代码，没有开关要回退。

const C := preload("res://tests/virtual_player/c_tier.gd")

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	seed(20261118)
	XTianqiBase.PHASE4 = true
	XTianqiSkills.MASTERY = true
	XTianqiSkills.reload_table()
	XTianqiBase.clear_cache()
	_median()
	var teams := _teams()
	_pile_and_assign(teams[0])
	_dummy()
	_state_and_fight(teams[0])
	XTianqiBase.PHASE4 = false
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _median() -> void:
	_check("median.odd", C.median([5.0, 1.0, 3.0]) == 3.0)
	_check("median.even", C.median([4.0, 1.0, 3.0, 2.0]) == 2.5)
	_check("median.empty", C.median([]) == 0.0)
	_check("median_index.odd", C.median_index([30.0, 10.0, 20.0]) == 2)
	_check("median_index.even_takes_lower", C.median_index([40.0, 10.0, 30.0, 20.0]) == 3)
	_check("median_index.ties_stable", C.median_index([5.0, 5.0, 5.0]) == 1)
	_check("median_index.empty", C.median_index([]) == -1)


func _teams() -> Array:
	var t1 := C.pick_teams(6, 20261118)
	var t2 := C.pick_teams(6, 20261118)
	var t3 := C.pick_teams(6, 777)
	var pool: Dictionary = XTianqi.pool(C.DIFFICULTY)
	_check("teams.count", t1.size() == 6)
	_check("teams.same_seed_same", JSON.stringify(t1) == JSON.stringify(t2))
	_check("teams.other_seed_differs", JSON.stringify(t1) != JSON.stringify(t3))
	var shape := true
	var distinct := true
	for t in t1:
		var strong := (t as Array).slice(0, 3).filter(func(x): return (pool[XTier.STRONG] as Array).has(x)).size()
		shape = shape and t.size() == 4 and strong == 3 and (pool[XTier.WEAK] as Array).has(t[3])
		var seen := {}
		for x in t:
			seen[x] = true
		distinct = distinct and seen.size() == 4
	_check("teams.3strong_1weak", shape, t1)
	_check("teams.members_distinct", distinct)
	return t1


func _pile_and_assign(team: Array) -> void:
	var s := XState.new_game(XTianqi.legacy_of(C.DIFFICULTY), int(team[0]), team.slice(1))
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": C.DIFFICULTY, "lineup": team.duplicate()}
	XState.current = s
	s.actor_max_level = C.LEVEL
	var members: Array = s.battle_members()
	for a in members:
		a.change_level_mv(C.LEVEL)
	var r1 := RandomNumberGenerator.new()
	r1.seed = 11
	var r2 := RandomNumberGenerator.new()
	r2.seed = 11
	var p1 := C.roll_pile(s, members, 3, r1)
	var p2 := C.roll_pile(s, members, 3, r2)
	_check("pile.nonempty", p1.size() > 30, p1.size())
	_check("pile.same_seed_same", JSON.stringify(p1) == JSON.stringify(p2))
	var more := C.roll_pile(s, members, 12, r1)
	_check("pile.more_battles_more_items", more.size() > p1.size(), [p1.size(), more.size()])
	var kinds_ok := true
	var lv_ok := true
	var cap := XTianqiDrop.level_of(30)
	for d in p1:
		kinds_ok = kinds_ok and (int(d.kind) == 2 or int(d.kind) == 3)
		var rec := XDB.rec("Weapons" if int(d.kind) == 2 else "Armors", int(d.id))
		lv_ok = lv_ok and int(rec.get("meta", {}).get("req_level", 0)) <= cap
	_check("pile.kinds", kinds_ok)
	_check("pile.level_within_floor30_cap", lv_ok, cap)
	# 守层者首杀固定掉落进堆：0 场通用掉落时堆里仍有守层者给的件数（30 层 × (first[0]+first[1]) 件上限）
	var only_guardian := C.roll_pile(s, members, 0, r1)
	var gd: Array = XTianqiDrop.table().get("guardian", {}).get("first", [1, 3])
	_check("pile.guardian_first_kill", only_guardian.size() > 0 and only_guardian.size() <= 30 * (int(gd[0]) + int(gd[1])), only_guardian.size())
	# 分装备
	var asg := C.assign(members, p1)
	var used := {}
	var dup := false
	var wear := true
	var total := 0.0
	for a in members:
		for r in asg[int(a.actor_id)]:
			var key := "%d:%d" % [int(r.kind), int(r.id)]
			used[key] = int(used.get(key, 0)) + 1
			var item := C.item_of(r, "t")
			wear = wear and a.can_equip(item) and int(a.equip_slots()[int(r.slot)]) == int(item.etypeId)
			total += C.K._wscore(XTianqiGear.effective_params(item), C.K.main_weights(a))
	var avail := {}
	for d in p1:
		var key := "%d:%d" % [int(d.kind), int(d.id)]
		avail[key] = int(avail.get(key, 0)) + 1
	for key in used:
		dup = dup or int(used[key]) > int(avail.get(key, 0))
	_check("assign.no_item_used_twice", not dup)
	_check("assign.wearable_in_slot", wear)
	_check("assign.score_sum", absf(total - float(asg.score)) < 0.01, [total, asg.score])
	_check("assign.something_equipped", used.size() >= 8, [used.size(), p1.size(), members.map(func(a): return [int(a.actor_id), (asg[int(a.actor_id)] as Array).size(), (a.equip_slots() as Array)])])
	var empty := C.assign(members, [])
	_check("assign.empty_pile", float(empty.score) == 0.0 and (empty[int(members[0].actor_id)] as Array).is_empty())


func _dummy() -> void:
	var t1 := C.dummy_troop(1)
	var t3 := C.dummy_troop(3)
	var ms: Array = XDB.rec("Troops", t3).get("members", [])
	var clean := true
	for m in ms:
		var eid := int(m.get("enemyId", 0))
		clean = clean and eid > 0 and XGuardianRework.floor_of(eid) == 0 and not XEnemy.boss_id(eid)
	_check("dummy.single_troop", t1 > 0)
	_check("dummy.multi_has_3_plain", ms.size() >= 3 and clean, [t3, ms.size()])


func _state_and_fight(team: Array) -> void:
	var c = C.new()
	c.turns = 1
	c.seed_v = 20261118
	var s: XState = c._state(team, {})
	_check("state.level_81", int(s.actor(int(team[0])).level) == 81)
	_check("state.floor_36", int(s.variable(20)) == 36)
	_check("state.wine_on", XTianqiMoney.has_good(s, "wine") or XTianqiMoney.money(s).get("scale", {}).get("goods", []).has("wine"))
	var a: XActor = s.actor(int(team[0]))
	var fid: int = C.K._own_fabao(int(team[0]))
	var has_fabao := false
	for e in a.equips:
		if e is Dictionary and e.get("meta", {}).has("Magic Weapon"):
			has_fabao = true
			_check("state.fabao_level_99", int(e.get("level", 0)) == 99 or int(e.get("level", 0)) == int(XMagicWeapon.max_level(e)), e.get("level"))
	_check("state.has_fabao", has_fabao, fid)
	var c2 = C.new()
	c2.wine = false
	var s2: XState = c2._state(team, {})
	_check("state.no_wine_flag", not XTianqiMoney.money(s2).get("scale", {}).get("goods", []).has("wine"))
	var normal: Dictionary = c._fight(c._state(team, {}), 1, false)
	var immune: Dictionary = c._fight(c._state(team, {}), 1, true)
	_check("fight.has_damage", (normal.per_turn as Array).size() == 1 and float(normal.per_turn[0]) > 0.0, normal.per_turn)
	_check("fight.no_crit_dummy_lower", float(immune.per_turn[0]) < float(normal.per_turn[0]), [immune.per_turn, normal.per_turn])
	_check("fight.hits_recorded", not (normal.hits as Array).is_empty())
	# 免暴击特性用完要撤掉，不留在敌人数据里
	var leftover := false
	for e in XDB.table("Enemies"):
		if e is Dictionary and (e.get("traits", []) as Array).has(C.NO_CRIT_TRAIT):
			leftover = true
	_check("fight.no_crit_trait_removed", not leftover)
	c.free()
	c2.free()
