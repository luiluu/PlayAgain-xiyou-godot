extends Node
## 宠物来源（XPetCapture）：对照冻结 v0.28 的 tests/fixtures/pet_capture_oracle.json（mv_oracle/pet_capture_probe.cjs）。
## 全部敌人的 <Capture> 门槛、开战掷可捕捉与「宝宝」名、敌群 1 强制可捕捉与记时间、第 5 回合逃跑、捕捉道具三种结果
## （成功造宠物与 die＋hide、失败、不可捕捉退还）、神秘生物刷新（窗口内外、本窗口已打过、奇兽开关）；再走一遍战斗里用捕获网。
## 随机数用参照记下的序列（脚本流）。

const FIXTURE := "res://tests/fixtures/pet_capture_oracle.json"

var results := []
var ref: Dictionary


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


static func tape(values: Array) -> XRandomStream:
	return XRandomStream.scripted(values.map(func(v): return {"kind": "float", "value": float(v)}), "pet")


func battle(troop: int) -> XBattleLogic:
	var l := XBattleLogic.new()
	l.elite_roll = 100.0
	l.setup(troop, XState.new_game(3, 1, [8, 9, 10]))
	for e in l.enemies:
		e.capture = false
	return l


static func toasts(logs: Array) -> Array:
	return logs.filter(func(x): return x.type == "toast").map(func(x): return x.text)


func _run() -> void:
	ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var manifest = XDB.load_json("manifest.json")
	var sha = manifest.get("runtimeInputs", {}).get(ref.source) if manifest is Dictionary else null
	check("fixture_matches_current_plugin", sha == ref.sha256, [ref.sha256, sha])
	# 1. 门槛
	var bad := []
	for row in ref.capture:
		if XPetCapture.threshold(int(row[0])) != int(row[1]):
			bad.append(row)
	check("thresholds", bad.is_empty() and ref.capture.size() == 324, bad.slice(0, 5))
	# 2. 开战掷可捕捉、名字
	for st in ref.starts:
		var l := battle(int(st.troop))
		if int(st.troop) == 1:
			l.enemies[0].capture = true  # Game_Troop.setup 已强制
		XPetCapture.roll_battle(l, tape(st.rolls))
		var got := l.enemies.map(func(e): return {"id": e.enemy_id, "capture": e.capture, "name": e.display_name()})
		var want: Array = st.enemies.map(func(e): return {"id": int(e.id), "capture": bool(e.capture), "name": str(e.name)})
		check("start_troop_%d" % int(st.troop), got == want and XPetCapture.random(l).draws == st.rolls.size(), [got, want])
	# 3. 第 4／5／6 回合结束
	for tr in ref.turns:
		var l := battle(2)
		for i in l.enemies.size():
			l.enemies[i].capture = i != 1
		l.enemies[2].hp = 0.0  # 已倒下的不逃跑
		l._die(l.enemies[2])
		l.turn = int(tr.turn)
		var logs := XPetCapture.end_turn(l)
		var got := l.enemies.map(func(e): return {"capture": e.capture, "dead": e.is_dead(), "hidden": e.hidden, "hp0": e.hp == 0.0, "states": e.state_ids})
		var want: Array = tr.enemies.map(func(e): return {"capture": bool(e.capture), "dead": bool(e.dead), "hidden": bool(e.hidden), "hp0": int(e.hp) == 0, "states": e.states.map(func(x): return int(x))})
		check("turn_%d" % int(tr.turn), got == want and toasts(logs) == tr.toasts, [got, want, toasts(logs)])
	# 4. 捕捉道具（last_action_wins 是原版全局行动的取法，OTB 下不会出现，见 XPetCapture 文件头）
	for g in ref.gets:
		if str(g.name) == "last_action_wins":
			continue
		var l := battle(2)
		var s := l.state
		var item := XDB.rec("Items", int(g.item))
		s.gain_item(int(g.item), 2)
		for e in l.enemies:
			e.capture = bool(g.capturable)
		var rolls := [float(g.roll)]
		# 参照成功时：成功率 1 次＋造宠物 24 次＋die 里别的插件的 Math.randomInt 1 次（不是宠物规则，重制不抽）
		var create := int(g.draws) - 2 if g.pet != null else 0
		for i in range(create):
			rolls.append(0.5)
		if g.pet != null:
			rolls.append(0.99)  # 学习次数上限：参照在建敌人时掷（setup 的随机 0.99），这里捕到时掷
		l.set_meta("pet_random", tape(rolls))
		var logs := XPetCapture.item_event(l, item, 173, l.enemies[1])
		var tg := l.enemies.map(func(e): return {"dead": e.is_dead(), "hidden": e.hidden, "hp0": e.hp == 0.0})
		var want_t: Array = g.targets.map(func(e): return {"dead": bool(e.dead), "hidden": bool(e.hidden), "hp0": int(e.hp) == 0})
		var ok: bool = toasts(logs) == g.toasts and s.item_count(int(g.item)) == int(g.count) and s.pets.list.size() == int(g.pets) and tg == want_t
		var detail: Array = [toasts(logs), s.item_count(int(g.item)), s.pets.list.size(), tg, want_t]
		if g.pet != null:
			var p: Dictionary = s.pets.list[0]
			var lv := {}
			for i in g.pet.lv.size():
				if g.pet.lv[i] != null:
					lv[str(i)] = int(g.pet.lv[i])
			ok = ok and int(p.enemy) == int(g.pet.enemy) and p.push.map(func(x): return float(x)) == g.pet.push.map(func(x): return float(x)) \
				and p.skills == g.pet.skills.map(func(x): return int(x)) and p.lv_skills == lv and [int(p.ls), int(p.ls_max)] == g.pet.ls.map(func(x): return int(x)) \
				and str(p.letter) == "Ｂ"
			detail.append([p, g.pet])
		ok = ok and XPetCapture.random(l).error == "" and XPetCapture.random(l).draws == rolls.size()
		check("get_" + str(g.name), ok, detail)
	# 5. 神秘生物刷新
	var troop1: Dictionary = XDB.rec("Troops", 1).members[0]
	for rf in ref.refreshes:
		var s := XState.new_game(3, 1, [8, 9, 10])
		XPetCapture.clock = func(): return {"day": 15, "hour": int(rf.hm[0]), "minute": int(rf.hm[1])}
		s.pets.ref_capture = bool(rf.refCapture)
		if rf.last != null:
			s.pets.ref_day = int(rf.last[0])
			s.pets.ref_hour = int(rf.last[1])
			s.pets.ref_minute = int(rf.last[2])
		if str(rf.name).ends_with("_preset"):
			for m in XPetCapture.pet_maps().values():
				for k in 2:
					if m.maps[k] > 0:
						s.set_self_switch(m.maps[k], m.events[k], m.switches[k], true)
		troop1.enemyId = 1
		var draws: Array = rf.draws.duplicate()
		var rnd := func(): return float(draws.pop_front())
		var shown := XPetCapture.check(s, rnd)
		var on := s.self_switches.keys().filter(func(k): return s.self_switches[k])
		on.sort()
		var want_on: Array = rf.on.duplicate()
		want_on.sort()
		check("refresh_" + str(rf.name), on == want_on and int(troop1.enemyId) == int(rf.troop1) and shown == rf.toasts and draws.is_empty(),
			[on, want_on, troop1.enemyId, shown, draws])
	# 6. 敌群 1：用刷新写进去的敌人，强制可捕捉并记下时间
	troop1.enemyId = 290
	XPetCapture.clock = func(): return {"day": 16, "hour": 9, "minute": 31}
	var l1 := XBattleLogic.new()
	l1.elite_roll = 100.0
	l1.setup(1, XState.new_game(3, 1, [8, 9, 10]))
	var p1 := l1.state.pets
	check("troop1_setup", l1.enemies[0].enemy_id == int(ref.troop1.enemy) and l1.enemies[0].capture
		and [p1.get("ref_day"), p1.get("ref_hour"), p1.get("ref_minute")] == ref.troop1.ref.map(func(x): return int(x)), [l1.enemies[0].enemy_id, p1])
	troop1.enemyId = 1
	XPetCapture.clock = Callable()
	_battle_flow()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 战斗里真的用一次：角色对可捕捉的嘤嘤怪用大师级捕获器（成功率 80%，掷 0），被捕的敌人隐藏、不算阵亡，结算不给它的经验
func _battle_flow() -> void:
	var l := battle(2)
	var s := l.state
	s.gain_item(317, 1)
	for e in l.enemies:
		e.capture = true
	l.set_meta("pet_random", tape([0.0] + range(40).map(func(_i): return 0.5)))
	var exp_before := int(l.rewards().exp)
	var logs := l.execute(l.actors[0], XDB.rec("Items", 317), l.enemies[0])
	var hit: Array = logs.filter(func(x): return x.type == "hit")
	var events: Array = hit[0].get("events", []) if not hit.is_empty() else []
	check("battle_capture", s.pets.list.size() == 1 and l.enemies[0].hidden and not l.enemies[0].is_dead() and not l.enemies[0].is_alive()
		and s.item_count(317) == 0 and toasts(events) == ["捕捉成功"] and events.any(func(x): return x.type == "enemy_change" and x.kind == "vanish"),
		[s.pets.list.size(), l.enemies[0].hidden, s.item_count(317), events.map(func(x): return x.type)])
	check("battle_capture_no_reward", int(l.rewards().exp) < exp_before, [exp_before, l.rewards().exp])
	check("battle_capture_not_in_orders", not l.current_order.has(l.enemies[0]) and not l.next_order.has(l.enemies[0]))
	l.turn = 5
	var end := l.end_turn()
	# O-098：已被捕走的不再「逃跑」，只有另外两只提示
	check("battle_flee_turn5", l.enemies.all(func(e): return e.hidden) and toasts(end).size() == 2 and l.alive(l.enemies).is_empty(), toasts(end))
