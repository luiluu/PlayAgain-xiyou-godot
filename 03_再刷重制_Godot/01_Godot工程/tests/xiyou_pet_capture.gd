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
	# 3b. 先后：逃跑先于各成员回合结束（毒伤）：完整 end_turn
	var lo := battle(2)
	for i in lo.enemies.size():
		lo.enemies[i].capture = i != 1
		if i < 2:
			lo.enemies[i].add_state(4)
	lo.turn = 5
	var olog := lo.end_turn()
	var og := lo.enemies.map(func(e): return {"capture": e.capture, "hidden": e.hidden, "hpRate": snappedf(e.hp / e.mhp, 0.0001), "states": e.state_ids})
	var ow: Array = ref.order.enemies.map(func(e): return {"capture": bool(e.capture), "hidden": bool(e.hidden), "hpRate": snappedf(float(e.hpRate), 0.0001), "states": e.states.map(func(x): return int(x))})
	check("turn_5_before_regen", og == ow and toasts(olog) == ref.order.toasts, [og, ow, toasts(olog)])
	# 只建 logic 不掷（Scene_Battle.start 才掷）；pet 流不动 rule／reward 的取数
	var seed := XRandomStream.hex64(12345)
	var la := XBattleLogic.new()
	la.elite_roll = 100.0
	la.setup(2, XState.new_game(3, 1, [8, 9, 10]), XBattleRandom.create(seed))
	var lb := XBattleLogic.new()
	lb.elite_roll = 100.0
	lb.setup(2, XState.new_game(3, 1, [8, 9, 10]), XBattleRandom.create(seed))
	var plain_names := la.enemies.map(func(e): return e.display_name())
	XPetCapture.roll_battle(lb)
	check("setup_does_not_roll", plain_names == ["嘤嘤怪Ａ", "嘤嘤怪Ｂ", "嘤嘤怪Ｃ"] and not la.enemies.any(func(e): return e.capture), plain_names)
	check("pet_stream_separate", la.random.rule.snapshot() == lb.random.rule.snapshot() and la.random.reward.snapshot() == lb.random.reward.snapshot()
		and lb.random.pet.draws == 3 and la.random.pet.draws == 0)
	var restored := XBattleRandom.restore(JSON.parse_string(JSON.stringify(lb.random.snapshot())))
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(la.random.snapshot()))
	legacy.erase("pet")
	var old := XBattleRandom.restore(legacy)
	check("pet_stream_snapshot", restored != null and restored.pet.draws == 3 and old != null and old.pet.snapshot() == la.random.pet.snapshot())
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
		var logs := XPetCapture.capture(l, item, l.enemies[1])
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
	XPetCapture.roll_battle(l1)  # 战斗画面开场时掷（Scene_Battle.start）
	var p1 := l1.state.pets
	check("troop1_setup", l1.enemies[0].enemy_id == int(ref.troop1.enemy) and l1.enemies[0].capture
		and [p1.get("ref_day"), p1.get("ref_hour"), p1.get("ref_minute")] == ref.troop1.ref.map(func(x): return int(x)), [l1.enemies[0].enemy_id, p1])
	troop1.enemyId = 1
	XPetCapture.clock = Callable()
	_refresh_original()
	_turns_original()
	_books()
	_battle_flow()
	_battle_flow_original()
	_defeat_count(true)
	_defeat_count(false)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 魔兽要诀（XPets.learn_book）对照参照；再查 O-103 的 372 改学 1672
func _books() -> void:
	for b in ref.books:
		var s := XState.new_game(3, 1, [8, 9, 10])
		s.last_item = 343
		var pet := {"enemy": 1, "elite": false, "letter": "", "push": range(14).map(func(_i): return 0), "skills": [1365, 1374], "lv_skills": {},
			"exp": 0, "ls": int(b.lsBefore[0]), "ls_max": int(b.lsBefore[1])}
		s.pets.list = [pet]
		s.pets.war = 0 if bool(b.war) else -1
		var shown := XPets.learn_book(s, int(b.skill))
		check("book_" + str(b.name), [shown] == b.toasts and pet.skills == b.skills.map(func(x): return int(x))
			and [pet.ls, pet.ls_max] == b.ls.map(func(x): return int(x)) and s.item_count(343) == int(b.refund), [shown, pet, s.item_count(343)])
	var s2 := XState.new_game(3, 1, [8, 9, 10])
	s2.last_item = 372
	s2.pets.list = [{"enemy": 1, "push": range(14).map(func(_i): return 0), "skills": [], "lv_skills": {}, "exp": 0, "ls": 0, "ls_max": 3}]
	s2.pets.war = 0
	check("book_372_fix", XPets.learn_book(s2, 1673) == "高级灵根 学习成功" and s2.pets.list[0].skills == [1672], s2.pets.list[0])
	# 回退（BOOK_FIX_372 = false）：照原版 372 走公共事件 218，学的是 1673 高级灵甲术
	XPets.BOOK_FIX_372 = false
	var s3 := XState.new_game(3, 1, [8, 9, 10])
	s3.last_item = 372
	s3.pets.list = [{"enemy": 1, "push": range(14).map(func(_i): return 0), "skills": [], "lv_skills": {}, "exp": 0, "ls": 0, "ls_max": 3}]
	s3.pets.war = 0
	var shown3 := XPets.learn_book(s3, 1673)
	XPets.BOOK_FIX_372 = true
	check("book_372_original", shown3 == str(XDB.rec("Skills", 1673).name) + " 学习成功" and s3.pets.list[0].skills == [1673], [shown3, s3.pets.list[0]])


## 战斗里真的用一次：角色对可捕捉的嘤嘤怪用大师级捕获器（成功率 80%，掷 0）：行动只预约公共事件 173，事件检查时才捕到；
## 被捕的敌人隐藏、不算阵亡，结算不给它的经验
func _battle_flow() -> void:
	var l := battle(2)
	var s := l.state
	s.gain_item(317, 1)
	XPetCapture.roll_battle(l)
	for e in l.enemies:
		e.capture = true
	l.set_meta("pet_random", tape([0.0] + range(40).map(func(_i): return 0.5)))
	var exp_before := int(l.rewards().exp)
	var logs := l.execute(l.actors[0], XDB.rec("Items", 317), l.enemies[0])
	# 道具的 44 效果在收尾序列 ACTION COMMON EVENT 预约公共事件 173，行动结束后的事件检查才执行 PetGet
	check("battle_capture_reserved", XBattleCommonEvent.reserved(l) == 173 and s.pets.list.is_empty() and not l.enemies[0].hidden, XBattleCommonEvent.reserved(l))
	var events := l.run_events()
	check("battle_capture", s.pets.list.size() == 1 and l.enemies[0].hidden and not l.enemies[0].is_dead() and not l.enemies[0].is_alive()
		and s.item_count(317) == 0 and toasts(events) == ["捕捉成功"] and events.any(func(x): return x.type == "enemy_change" and x.kind == "vanish"),
		[s.pets.list.size(), l.enemies[0].hidden, s.item_count(317), events.map(func(x): return x.type)])
	check("battle_capture_no_reward", int(l.rewards().exp) < exp_before, [exp_before, l.rewards().exp])
	check("battle_capture_not_in_orders", not l.current_order.has(l.enemies[0]) and not l.next_order.has(l.enemies[0]))
	l.turn = 5
	var end := l.end_turn()
	# O-102：已被捕走的不再「逃跑」，只有另外两只提示
	check("battle_flee_turn5", l.enemies.all(func(e): return e.hidden) and toasts(end).size() == 2 and l.alive(l.enemies).is_empty(), toasts(end))


## O-105：捕捉成功与第 5 回合逃跑的图鉴击败数。原版 die() 记一次、refresh 补阵亡再 die() 一次，每只 +2（参照 gets.success、
## turns 第 5 回合的 defeats，逃跑那场只有一只逃）；重制默认只记 1
func _defeat_count(single: bool) -> void:
	XPetCapture.SINGLE_DEFEAT_COUNT = single
	var mv_flee: Array = ref.turns.filter(func(t): return int(t.turn) == 5)
	var mv_per := int(ref.gets[0].defeats)
	if not single:
		check("defeat_oracle", ref.gets[0].name == "success" and mv_per == 2 and int(mv_flee[0].defeats) == mv_per, [mv_per, mv_flee[0].defeats])
	var per := 1 if single else mv_per
	var tag := "single" if single else "mv"
	var l := battle(2)
	var s := l.state
	XEnemyBook.bind_battle(s, l.enemies)
	var total := func() -> int:
		var n := 0
		for v in s.enemy_book.get("defeat", {}).values():
			n += int(v)
		return n
	s.gain_item(317, 1)
	for e in l.enemies:
		e.capture = true
	l.set_meta("pet_random", tape([0.0] + range(40).map(func(_i): return 0.5)))
	var id0 := int(l.enemies[0].enemy_id)
	var before0 := XEnemyBook.defeat_number(s, id0)
	l.execute(l.actors[0], XDB.rec("Items", 317), l.enemies[0])
	l.run_events()
	check("defeat_capture_%s" % tag, l.enemies[0].hidden and XEnemyBook.defeat_number(s, id0) - before0 == per and total.call() == per,
		[XEnemyBook.defeat_number(s, id0) - before0, total.call()])
	l.turn = 5
	l.end_turn()
	# 另外两只逃跑，也是 die＋hide
	check("defeat_flee_%s" % tag, l.enemies.all(func(e): return e.hidden) and total.call() == per * 3, total.call())
	XPetCapture.SINGLE_DEFEAT_COUNT = true


## O-101 回退（SHOW_REFRESH_TEXT = false）：开关、敌群 1 照参照，提示只在存档 pets.show_text（$gameParty.PetShowTextT）为真时弹。
## 参照是把 PetShowTextT 打开录的（pet_capture_probe.cjs），所以 show_text 为真时提示与参照相同，为假时一条也没有
func _refresh_original() -> void:
	XPetCapture.SHOW_REFRESH_TEXT = false
	var troop1: Dictionary = XDB.rec("Troops", 1).members[0]
	for rf in ref.refreshes.filter(func(r): return r.last == null and not str(r.name).ends_with("_preset")):
		for flag in [false, true]:
			var s := XState.new_game(3, 1, [8, 9, 10])
			XPetCapture.clock = func(): return {"day": 15, "hour": int(rf.hm[0]), "minute": int(rf.hm[1])}
			s.pets.ref_capture = bool(rf.refCapture)
			if flag:
				s.pets.show_text = true
			troop1.enemyId = 1
			var draws: Array = rf.draws.duplicate()
			var shown := XPetCapture.check(s, func(): return float(draws.pop_front()))
			var on := s.self_switches.keys().filter(func(k): return s.self_switches[k])
			on.sort()
			var want_on: Array = rf.on.duplicate()
			want_on.sort()
			check("refresh_original_%s_%s" % [rf.name, "shown" if flag else "silent"],
				on == want_on and int(troop1.enemyId) == int(rf.troop1) and shown == (rf.toasts if flag else []) and draws.is_empty(), [on, want_on, shown])
	troop1.enemyId = 1
	XPetCapture.clock = Callable()
	XPetCapture.SHOW_REFRESH_TEXT = true


## O-102 回退（FLEE_ALIVE_ONLY = false）：判「不算阵亡」。参照的回合场景里倒下的那只本来就不逃，结果应与参照逐项相同
func _turns_original() -> void:
	XPetCapture.FLEE_ALIVE_ONLY = false
	for tr in ref.turns:
		var l := battle(2)
		for i in l.enemies.size():
			l.enemies[i].capture = i != 1
		l.enemies[2].hp = 0.0
		l._die(l.enemies[2])
		l.turn = int(tr.turn)
		var logs := XPetCapture.end_turn(l)
		var got := l.enemies.map(func(e): return {"capture": e.capture, "dead": e.is_dead(), "hidden": e.hidden, "hp0": e.hp == 0.0, "states": e.state_ids})
		var want: Array = tr.enemies.map(func(e): return {"capture": bool(e.capture), "dead": bool(e.dead), "hidden": bool(e.hidden), "hp0": int(e.hp) == 0, "states": e.states.map(func(x): return int(x))})
		check("turn_%d_original" % int(tr.turn), got == want and toasts(logs) == tr.toasts, [got, want, toasts(logs)])
	XPetCapture.FLEE_ALIVE_ONLY = true


## O-102 回退：已被捕走（die＋hide，不算阵亡）的那只在第 5 回合再提示一次「敌人逃跑」，三只都提示
func _battle_flow_original() -> void:
	XPetCapture.FLEE_ALIVE_ONLY = false
	var l := battle(2)
	var s := l.state
	s.gain_item(317, 1)
	XPetCapture.roll_battle(l)
	for e in l.enemies:
		e.capture = true
	l.set_meta("pet_random", tape([0.0] + range(40).map(func(_i): return 0.5)))
	l.execute(l.actors[0], XDB.rec("Items", 317), l.enemies[0])
	l.run_events()
	var captured := l.enemies[0].hidden and s.pets.list.size() == 1
	l.turn = 5
	var end := l.end_turn()
	XPetCapture.FLEE_ALIVE_ONLY = true
	check("battle_flee_turn5_original", captured and l.enemies.all(func(e): return e.hidden) and toasts(end) == ["敌人逃跑", "敌人逃跑", "敌人逃跑"], toasts(end))
