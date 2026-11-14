extends Node
## 天启篇战斗布阵／奖励钉住＋装备底子钉住专项（随机门面 R3，XTianqiRandom.BATTLE_FROM_SAVE／GEAR_BASE_FROM_SAVE）。
## 协调批复：战斗键＝敌群号｜本档打这个敌群的第几次；开战布阵掷的算结果一起钉；西游档不钉。全走真实存读（tq_save_kit）。
##   ① 存→打→读→再打：布阵取数、掉落件、词条、底子（整件装备，除 instanceId）全同；回合内 rule 流照旧每次读档不同
##   ② 换击杀顺序：掉落（整件装备）同；③ 少杀一个（逃了＝hidden）只少那一个的掉落
##   ④ 换敌群不同；先打别的敌群再打这个，这个的结果不变（战斗键按敌群计数）
##   ⑤ 关开关回运行时（不钉、不写计数、读档两次布阵不同）；⑥ 西游档：不钉、快照不加键、各取数口就是原来那条流
##   ⑦ 带来源键的装备底子：读档再拿同一来源一样、不动共享预掷池；关开关回运行时装备流
##   ⑧ 回放：钉住的本场快照能还原（种子、布阵流、子流），从开战前的档重放结果相同
##   ⑨ 掉率统计：多种子下钉住与运行时（关开关）每场掉落件数均值落在误差内
##   ⑩ 结算段（grant／end_battle 里的规则取数，co 甲档核查 R3 P2）：不朽之书、谷雨石、心之钢、狂妄、锻造锤逐项触发，
##      钉住后读档同结果、取数在各自的结算子流（回合流在结算期间一次不取）、关开关回到回合流且读档不同；
##      心之钢、狂妄命中时整件装备（底子、词条、孔数）读档相同，先拿别的装备再打也相同；各项命中率分项统计
const Kit := preload("res://tests/lib/tq_save_kit.gd")
var results: Array = []
var kit: Kit


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


## 装备的可比形：去掉 instanceId（按入包先后编号）
static func _sig(g: Dictionary) -> String:
	var d := g.duplicate(true)
	d.erase("instanceId")
	return JSON.stringify(d, "", true)


## 读档后打 troop 一场：order＝击杀顺序（缺省按位次），escape＝逃掉（hidden）的敌人位次；倒下即发掉落（MOG）
func _fight(s: XState, troop: int, order := [], escape := -1) -> Dictionary:
	var before := s.gear.duplicate()
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	lg.advance_loot_on_collapse = true
	var setup_j := JSON.stringify(lg.random.setup.journal) if lg.random.setup != null else ""
	var rule_j := JSON.stringify(lg.random.rule.journal)
	var ids := order if not order.is_empty() else range(lg.enemies.size())
	if escape >= 0 and escape < lg.enemies.size():
		lg.enemies[escape].hidden = true
	var per := {}
	for i in ids:
		var e: XEnemy = lg.enemies[i]
		if e.hidden:
			continue
		e.hp = 0
		e.add_state(1)
		lg.resolve_collapse(e)
		per[lg.stable_id(e)] = JSON.stringify(lg.drop_snapshot(e))
	var rw: Dictionary = lg.rewards()
	lg.grant(rw)
	lg.end_battle(0)
	var got := []
	for g in s.gear:
		if not before.any(func(x): return is_same(x, g)):
			got.append(_sig(g))
	var sorted := got.duplicate()
	sorted.sort()
	var subs := {}  # 各敌人掉落子流的取数记录（取了几次、取到什么），与击杀顺序无关才对
	for k in lg.random._subs:
		if str(k).ends_with("|drop"):
			subs[k] = JSON.stringify(lg.random._subs[k].journal)
	return {"subs": subs, "key": lg.random.battle_key, "pinned": lg.random.pinned(), "setup": setup_j, "rule": rule_j,
		"names": JSON.stringify(lg.enemies.map(func(e): return e.display_name())), "per": per,
		"gear": got, "sorted": sorted, "drops": JSON.stringify(rw.drops), "logic": lg}


## 本档里能打出装备掉落的敌群：从第 20 层以上的遇敌表里找，多敌人、倒下有装备的优先
func _pick_troop(s: XState) -> Array:
	var out := []
	for m in range(1, 400):
		if XDungeon.map_floor(m) < 20 or not FileAccess.file_exists(XDB.BASE + "maps/Map%03d.json" % m):
			continue
		var info := XDB.map(m)
		for enc in info.get("encounterList", []):
			var t := XDB.rec("Troops", int(enc.troopId))
			if (t.get("members", []) as Array).size() >= 2:
				out.append([m, int(enc.troopId)])
				break
		if out.size() >= 30:
			break
	return out


func _new(orb := 20261114) -> XState:
	var s := Kit.new_game("jianxian", "war", orb)
	s.set_variable(20, 26)  # 25 层：按段异化、通用掉落都开
	return s


## 读档，并把这个敌群的计数拨到 k（第 k 次打它）
func _load_at(map: int, troop: int, k: int) -> XState:
	var st := kit.reload()
	st.map_id = map
	if k > 0:
		if not st.flags.tianqi.get("rng") is Dictionary:
			st.flags.tianqi["rng"] = {}
		st.flags.tianqi.rng["battle|%d" % troop] = k
	return st


func _enemy_gear(per: Dictionary) -> int:
	var n := 0
	for v in per.values():
		for d in JSON.parse_string(str(v)):
			if [2, 3].has(int(d.kind)):
				n += 1
	return n


func _same_fight() -> void:
	# 招牌掉落关掉、通用掉落关掉（敌人留着整张掉落表）：敌人掉落表走奖励子流（招牌掉落另有掉落账，本来就钉住）
	XTianqiDrop.SIGNATURE = false
	XTianqiDrop.GENERIC = false
	var s := _new()
	var picks := _pick_troop(s)
	_check("troops_found", not picks.is_empty(), picks.size())
	kit.save()
	# 找一个敌人倒下掉了装备的多敌人敌群（各试战斗键 0～39；天启篇敌人掉落稀，两只都掉装备的很难碰到，
	# 击杀顺序另用各敌人掉落子流的取数记录比，不靠碰运气）
	var chosen := []
	var first := {}
	var key_k := 0
	for p in picks:
		for k in 40:
			var r := _fight(_load_at(int(p[0]), int(p[1]), k), int(p[1]))
			var droppers := (r.per as Dictionary).values().filter(func(v): return v != "[]").size()
			if _enemy_gear(r.per) >= 1 and droppers >= 1:
				chosen = p
				first = r
				key_k = k
				break
		if not chosen.is_empty():
			break
	_check("drop_troop_found", not chosen.is_empty(), picks.slice(0, 5))
	if chosen.is_empty():
		XTianqiDrop.SIGNATURE = true
		XTianqiDrop.GENERIC = true
		return
	var map := int(chosen[0])
	var troop := int(chosen[1])
	_check("pinned_key", first.pinned and str(first.key) == "%d|%d" % [troop, key_k], first.key)
	# ① 读档再打：整件装备、布阵、名字（异化挂谁）全同；rule 流（回合内）照旧每次不同
	var st2 := _load_at(map, troop, key_k)
	var again := _fight(st2, troop)
	_check("reload_same_gear", again.gear == first.gear, [first.gear, again.gear])
	_check("reload_same_setup", again.setup == first.setup and again.setup != "[]", [first.setup, again.setup])
	_check("reload_same_names", again.names == first.names, [first.names, again.names])
	_check("reload_same_drops", again.drops == first.drops)
	_check("reload_rule_not_used_in_setup", str(first.rule) == "[]", first.rule)
	var counter = st2.flags.tianqi.get("rng", {}).get("battle|%d" % troop)
	_check("counter_saved", int(counter) == key_k + 1, counter)
	# 同一个档接着再打一次同一敌群：战斗键第 1 次，掉落一般不同（新的掉落机会）
	var third := _fight(st2, troop)
	_check("next_key", str(third.key) == "%d|%d" % [troop, key_k + 1], third.key)
	_check("next_differs", third.setup != first.setup, [first.setup, third.setup])
	# ② 换击杀顺序：整件装备同（按来源键，顺序只影响 instanceId）
	var st3 := _load_at(map, troop, key_k)
	var n := (first.logic as XBattleLogic).enemies.size()
	var rev := range(n)
	rev.reverse()
	var swapped := _fight(st3, troop, rev)
	_check("kill_order_same", swapped.sorted == first.sorted, [first.sorted, swapped.sorted])
	_check("kill_order_same_per_enemy", swapped.per == first.per)
	_check("kill_order_same_sub_journals", swapped.subs == first.subs and (first.subs as Dictionary).size() == n, [first.subs.keys(), swapped.subs.keys()])
	# ③ 少杀一个（逃掉）：只少它那一份
	var victim := ""
	var victim_i := -1
	for i in n:
		var sid: String = (first.logic as XBattleLogic).stable_id((first.logic as XBattleLogic).enemies[i])
		if first.per.get(sid, "[]") != "[]":
			victim = sid
			victim_i = i
			break
	var st4 := _load_at(map, troop, key_k)
	var fewer := _fight(st4, troop, [], victim_i)
	var expect_per: Dictionary = (first.per as Dictionary).duplicate()
	expect_per.erase(victim)
	_check("fewer_others_same", fewer.per == expect_per, [expect_per, fewer.per])
	var expect_subs: Dictionary = (first.subs as Dictionary).duplicate()
	expect_subs.erase(victim + "|drop")
	_check("fewer_others_same_journals", fewer.subs == expect_subs, [expect_subs.keys(), fewer.subs.keys()])
	var lost := JSON.parse_string(str(first.per[victim])) as Array
	var lost_gear := lost.filter(func(d): return [2, 3].has(int(d.kind))).size()
	_check("fewer_only_that_one", (fewer.gear as Array).size() == (first.gear as Array).size() - lost_gear \
		and (fewer.sorted as Array).all(func(x): return (first.sorted as Array).has(x)), [lost_gear, first.sorted, fewer.sorted])
	# ④ 换敌群：键不同、结果不同；先打别的敌群再打这个，这个不变
	var other := 0
	for p in picks:
		if int(p[1]) != troop:
			other = int(p[1])
			break
	var st5 := _load_at(map, troop, key_k)
	var o := _fight(st5, other)
	_check("other_troop_key", str(o.key) == "%d|0" % other, o.key)
	_check("other_troop_differs", o.setup != first.setup, [o.setup, first.setup])
	var after_other := _fight(st5, troop)
	_check("other_first_keeps_this", after_other.sorted == first.sorted and after_other.setup == first.setup and after_other.key == first.key, [first.sorted, after_other.sorted])
	# ⑤ 关开关：回到运行时（不钉、不写计数，读两次布阵取数不同）
	XTianqiRandom.BATTLE_FROM_SAVE = false
	var off1 := _fight(_load_at(map, troop, key_k), troop)
	var off2 := _fight(_load_at(map, troop, key_k), troop)
	_check("off_unpinned", not off1.pinned and not off2.pinned and str(off1.setup) == "" and str(off1.rule) != "[]")
	_check("off_rule_differs", off1.rule != off2.rule, [off1.rule, off2.rule])
	_check("off_no_counter", not (XState.current.flags.tianqi.get("rng", {}) as Dictionary).has("battle|%d" % troop))
	XTianqiRandom.BATTLE_FROM_SAVE = true
	XTianqiDrop.SIGNATURE = true
	XTianqiDrop.GENERIC = true
	# 默认（招牌掉落、通用掉落开）也一样
	var d1 := _fight(_load_at(map, troop, key_k), troop)
	var d2 := _fight(_load_at(map, troop, key_k), troop)
	_check("default_reload_same", d1.gear == d2.gear and d1.drops == d2.drops and d1.setup == d2.setup, [d1.gear, d2.gear])


## ⑥ 西游档：不钉；快照不加键；各取数口就是原流
func _plain() -> void:
	var plain := XState.new_game(3, 1, [8, 9, 10])
	XState.current = plain
	plain.random_master = "00112233445566aa"
	var lg := XBattleLogic.new()
	lg.setup(69, plain)
	var r := lg.random
	_check("plain_unpinned", not r.pinned() and r.setup == null and r.battle_key == "")
	_check("plain_snapshot_keys", r.snapshot().keys() == ["version", "engine", "serial", "masterSeed", "rule", "reward", "pet"], r.snapshot().keys())
	_check("plain_reward_for_is_reward", is_same(r.reward_for("enemy:0:72|drop"), r.reward) and is_same(r.reward_for("tianqi_generic"), r.reward))
	var same := true
	for ph in ["", "setup", "grant", "end|guyu", "end"]:
		r.phase = ph
		same = same and is_same(r.rule_now(), r.rule)
	r.phase = ""
	_check("plain_rule_now_is_rule", same)
	_check("plain_setup_on_rule", r.rule.journal.any(func(j): return str(j.reason) == "enemy_elite"))
	_check("plain_no_counter", not plain.flags.has("tianqi"))


## ⑦ 带来源键的装备底子
func _gear_base() -> void:
	var wid := 0
	for row in XDB.table("Weapons"):
		if row is Dictionary and str(row.get("name", "")) != "":
			var tpl := XGear.template("weapon", int(row.id))
			if XQuality.grade(tpl) >= 5 and not XEquipment.is_exclusive(tpl):
				wid = int(row.id)
				break
	_check("gear_weapon", wid > 0)
	var s := _new(11)
	kit.save()
	var take := func(st: XState, src: String) -> Array:
		var x0 = JSON.stringify([st.rom.get("x"), st.rom.get("xn")])
		var before := st.gear.size()
		st.gain_gear("weapon", wid, 2, src)
		var out := []
		for g in st.gear.slice(before):
			out.append(_sig(g))
		out.append(x0 == JSON.stringify([st.rom.get("x"), st.rom.get("xn")]))
		return out
	var a: Array = take.call(kit.reload(), "shop|test")
	var b: Array = take.call(kit.reload(), "shop|test")
	_check("base_reload_same", a == b and a.size() == 3, [a, b])
	_check("base_two_differ", a[0] != a[1], a)
	_check("base_pool_untouched", bool(a[2]))
	# 先拿别的来源的装备不影响这个来源
	var st := kit.reload()
	take.call(st, "event|other")
	var c: Array = take.call(st, "shop|test")
	_check("base_other_source_no_shift", c.slice(0, 2) == a.slice(0, 2), [a, c])
	# 共享预掷池里是什么都不影响（换一池别的数再拿，同一来源一样）
	var stp := kit.reload()
	var pool := []
	for i in 20:
		pool.append(0.05 * i)
	stp.rom.x = pool
	stp.rom.xn = 0
	var p2: Array = take.call(stp, "shop|test")
	_check("base_pool_independent", p2.slice(0, 2) == a.slice(0, 2), [a, p2])
	# 没有来源键的照旧走共享预掷池
	var st2 := kit.reload()
	var x0 = JSON.stringify([st2.rom.get("x"), st2.rom.get("xn")])
	st2.gain_gear("weapon", wid, 1)
	_check("base_no_source_uses_pool", x0 != JSON.stringify([st2.rom.get("x"), st2.rom.get("xn")]))
	# 关开关：回运行时装备流（读两次不同；词条仍按来源键）
	XTianqiRandom.GEAR_BASE_FROM_SAVE = false
	var o1: Array = take.call(kit.reload(), "shop|test")
	var o2: Array = take.call(kit.reload(), "shop|test")
	var o3: Array = take.call(kit.reload(), "shop|test")
	XTianqiRandom.GEAR_BASE_FROM_SAVE = true
	_check("base_off_varies", not (o1[0] == o2[0] and o2[0] == o3[0]), [o1, o2, o3])
	_check("base_off_pool_used", not bool(o1[2]))
	# 深渊商人等自己设了 roll_fn 的照旧优先
	var st3 := kit.reload()
	XGear.roll_fn = func(): return 0.5
	st3.gain_gear("weapon", wid, 1, "shop|test")
	var m1 := _sig(st3.gear[-1])
	XGear.roll_fn = Callable()
	var st4 := kit.reload()
	XGear.roll_fn = func(): return 0.5
	st4.gain_gear("weapon", wid, 1, "shop|test")
	var m2 := _sig(st4.gear[-1])
	XGear.roll_fn = Callable()
	_check("base_roll_fn_first", m1 == m2 and not XTianqiRandom.gear_binding)


## ⑧ 回放：钉住的快照能还原；从开战前的档 setup（带快照）结果相同、计数推到同一个数
func _replay() -> void:
	var s := _new(777777)
	kit.save()
	var st := kit.reload()
	var initial := st.to_dict().duplicate(true)
	var lg := XBattleLogic.new()
	lg.setup(69, st)
	var snap: Dictionary = lg.replay_battle_start
	_check("snap_pinned_keys", snap.has("pinSeed") and snap.has("battleKey") and snap.has("setup") and snap.has("subs"), snap.keys())
	var back := XBattleRandom.restore(JSON.parse_string(JSON.stringify(snap)))
	_check("snap_restore", back != null and back.pinned() and back.battle_key == lg.random.battle_key and back.pin_seed == lg.random.pin_seed)
	# 子流在结算后也能存还原
	lg.enemies[0].hp = 0
	lg.enemies[0].add_state(1)
	lg.resolve_collapse(lg.enemies[0])
	lg.rewards()
	var end_snap := lg.random.snapshot()
	var back2 := XBattleRandom.restore(JSON.parse_string(JSON.stringify(end_snap)))
	_check("snap_subs_restore", back2 != null and back2._subs.size() == lg.random._subs.size() and JSON.stringify(back2.snapshot()) == JSON.stringify(end_snap), [end_snap.get("subs", {}).keys()])
	var bad := snap.duplicate(true)
	bad["pinSeed"] = "zz"
	_check("snap_bad_rejected", XBattleRandom.restore(bad) == null)
	# 从开战前的档带快照重来一遍：布阵取数、名字、计数相同
	var st2 := XState.from_dict(initial.duplicate(true))
	XState.current = st2
	var lg2 := XBattleLogic.new()
	lg2.setup(69, st2, XBattleRandom.restore(JSON.parse_string(JSON.stringify(snap))))
	_check("replay_setup_same", JSON.stringify(lg2.random.setup.journal) == JSON.stringify(lg.random.setup.journal) \
		and JSON.stringify(lg2.enemies.map(func(e): return e.display_name())) == JSON.stringify(lg.enemies.map(func(e): return e.display_name())))
	_check("replay_counter_same", JSON.stringify(st2.flags.tianqi.get("rng")) == JSON.stringify(st.flags.tianqi.get("rng")), [st.flags.tianqi.get("rng"), st2.flags.tianqi.get("rng")])
	# 真回放（XBattleReplay）：开两回合自动战斗
	var st3 := kit.reload()
	var init3 := st3.to_dict().duplicate(true)
	var lg3 := XBattleLogic.new()
	lg3.setup(69, st3)
	lg3.auto = true
	var commands := []
	var logs := []
	lg3.start_turn()
	for i in 2:
		var user := lg3.next_subject()
		if user == null:
			break
		var cmd := lg3.decide(user)
		if cmd[0] == null:
			break
		commands.append({"turn": lg3.turn, "user": lg3.stable_id(user), "skill": int(cmd[0].id), "target": "", "automatic": true})
		logs.append_array(lg3.act(user, cmd[0], cmd[1]))
	var artifact := XBattleReplay.record(lg3, init3, commands, logs)
	_check("replay_journal_has_setup", (artifact.journal as Dictionary).has("setup") and (artifact.journal as Dictionary).has("subs"))
	var replayed := XBattleReplay.replay(JSON.parse_string(JSON.stringify(artifact)))
	XState.current = st3
	# 天启篇档的整场回放在本单之前就对不上（关开关同样报 logs 不符，见交付单「可优化」）：这里只断言钉住没有带来新的不符
	XTianqiRandom.BATTLE_FROM_SAVE = false
	var off := _auto_replay(kit.reload())
	XTianqiRandom.BATTLE_FROM_SAVE = true
	print("INFO tianqi_replay on=", JSON.stringify(replayed), " off=", JSON.stringify(off))
	_check("replay_no_new_mismatch", replayed.available == off.available and str(replayed.get("diagnostic", "")) == str(off.get("diagnostic", "")), [replayed, off])


## 开两回合自动战斗、记回放、重放
func _auto_replay(st: XState) -> Dictionary:
	var init := st.to_dict().duplicate(true)
	var lg := XBattleLogic.new()
	lg.setup(69, st)
	lg.auto = true
	var commands := []
	var logs := []
	lg.start_turn()
	for i in 2:
		var user := lg.next_subject()
		if user == null:
			break
		var cmd := lg.decide(user)
		if cmd[0] == null:
			break
		commands.append({"turn": lg.turn, "user": lg.stable_id(user), "skill": int(cmd[0].id), "target": "", "automatic": true})
		logs.append_array(lg.act(user, cmd[0], cmd[1]))
	var out := XBattleReplay.replay(JSON.parse_string(JSON.stringify(XBattleReplay.record(lg, init, commands, logs))))
	XState.current = st
	return out


## ⑨ 掉率统计：同一批种子各打若干场，钉住（开）与运行时（关）每场掉落件数的均值差在 4 个标准误之内
func _stats() -> void:
	XTianqiDrop.SIGNATURE = false
	var per_mode := {}
	for on in [true, false]:
		XTianqiRandom.BATTLE_FROM_SAVE = on
		var counts := []
		for sd in range(40):
			var s := _new(1000 + sd)
			s.map_id = 0
			for k in 4:  # 每个档同一敌群连打 4 场（钉住时战斗键 0～3）
				for troop in [69, 30]:
					var lg := XBattleLogic.new()
					lg.setup(troop, s)
					for e in lg.enemies:
						e.hp = 0
						e.add_state(1)
					var rw: Dictionary = lg.rewards()
					counts.append((rw.drops as Array).size())
					lg.end_battle(-1)
		per_mode[on] = counts
	XTianqiRandom.BATTLE_FROM_SAVE = true
	XTianqiDrop.SIGNATURE = true
	var m := {}
	var v := {}
	for on in per_mode:
		var c: Array = per_mode[on]
		var mean := 0.0
		for x in c:
			mean += float(x)
		mean /= float(c.size())
		var var_ := 0.0
		for x in c:
			var_ += (float(x) - mean) * (float(x) - mean)
		m[on] = mean
		v[on] = var_ / float(maxi(1, c.size() - 1)) / float(c.size())
	var se := sqrt(float(v[true]) + float(v[false]))
	print("INFO drop_count_mean pinned=%.4f runtime=%.4f se=%.4f n=%d" % [m[true], m[false], se, (per_mode[true] as Array).size()])
	_check("stats_has_drops", float(m[true]) > 0.0 and float(m[false]) > 0.0, m)
	_check("stats_mean_within_error", absf(float(m[true]) - float(m[false])) <= 4.0 * maxf(se, 0.01), [m, se])


# ---- ⑩ 结算段 ----
const END_KEYS := ["grant", "end|guyu", "end", "end|heartsteel", "end|forge", "end|hubris"]
const GUYU := 175


## 打赢一场（rewards → grant → end_battle(0)），返回各结算子流的取数、回合流在结算期间的取数、新得的装备与关注的物品数
func _win(st: XState, map: int, origin: int, troop: int) -> Dictionary:
	st.map_id = map
	st.unknown_origin = origin
	var before := st.gear.duplicate()
	var watch := [XGuyu.STONE, XGrowthForge.HAMMER, XStarburstBooks.IMMORTAL_BOOK]
	var items0 := watch.map(func(i): return st.item_count(i))
	var lg := XBattleLogic.new()
	lg.setup(troop, st)
	var r := lg.random
	for e in lg.enemies:
		e.hp = 0
		e.add_state(1)
	var n0 := r.rule.draws
	lg.grant(lg.rewards())
	lg.end_battle(0)
	var subs := {}
	for k in END_KEYS:
		if r._subs.has(k):
			subs[k] = (r._subs[k] as XRandomStream).journal.map(func(j): return [str(j.reason), j.value])
	var rule_end: Array = r.rule.journal.slice(n0).map(func(j): return [str(j.reason), j.value])
	var got := {}
	for g in st.gear:
		if not before.any(func(x): return is_same(x, g)):
			got[int(g.base)] = _sig(g)
	var items := []
	for i in watch.size():
		items.append(st.item_count(watch[i]) - int(items0[i]))
	return {"key": r.battle_key, "pinned": r.pinned(), "seed": r.pin_seed, "subs": subs, "rule_end": rule_end, "gear": got, "items": items}


func _reasons(rows: Array) -> Array:
	return rows.map(func(x): return x[0])


## 读档后把敌群计数拨到 k
func _at(troop: int, k: int) -> XState:
	var st := kit.reload()
	if not st.flags.tianqi.get("rng") is Dictionary:
		st.flags.tianqi["rng"] = {}
	st.flags.tianqi.rng["battle|%d" % troop] = k
	return st


func _end_phase() -> void:
	XStarburstBooks.IMMORTAL_CLEAR_TEST = 1  # 不朽存在通关判定直接算过（真判定要云裳订单的路线记录）
	var s := _new(424242)
	XTianqi._joining = true
	s.add_actor(GUYU)  # 谷雨在队：谷种金缮石才掷
	XTianqi._joining = false
	_check("end_guyu_in_party", s.party.has(GUYU), s.party)
	kit.save()
	var T := XHeartsteel.REWARD_TROOPS[0]
	var M := XHeartsteel.REWARD_MAP
	var O := XHeartsteel.REWARD_ORIGIN
	# 触发：各项落在自己的结算子流；回合流在结算期间一次不取
	var a := _win(_at(T, 0), M, O, T)
	_check("end_pinned", a.pinned)
	_check("end_starburst_in_grant", _reasons(a.subs.get("grant", [])).has("starburst.immortal"), a.subs)
	_check("end_guyu_in_sub", _reasons(a.subs.get("end|guyu", [])) == ["guyu_stone"], a.subs)
	_check("end_heartsteel_in_sub", _reasons(a.subs.get("end|heartsteel", [])) == ["heartsteel.reward"], a.subs)
	_check("end_hubris_in_sub", _reasons(a.subs.get("end|hubris", [])) == ["hubris.reward"], a.subs)
	_check("end_rule_untouched", (a.rule_end as Array).is_empty(), a.rule_end)
	# 子流取到的数就是 derive(本场种子, "reward|段") 的第一个数（算式钉住，分项统计用同一算式）
	_check("end_formula", float(a.subs["end|heartsteel"][0][1]) == _first(str(a.seed), "end|heartsteel") \
		and float(a.subs["end|hubris"][0][1]) == _first(str(a.seed), "end|hubris"), [a.subs["end|heartsteel"], a.seed])
	# 读档再打：取数、物品、装备全同
	var b := _win(_at(T, 0), M, O, T)
	_check("end_reload_same", JSON.stringify(a.subs) == JSON.stringify(b.subs) and a.items == b.items and a.gear == b.gear, [a, b])
	# 锻造锤：Map176、来源 165、敌群 570～575
	var FT := XGrowthForge.CORE_TROOPS[0]
	var f1 := _win(_at(FT, 0), XGrowthForge.CORE_MAP, 165, FT)
	var f2 := _win(_at(FT, 0), XGrowthForge.CORE_MAP, 165, FT)
	_check("end_forge_in_sub", _reasons(f1.subs.get("end|forge", [])) == ["growth_forge.core"] and (f1.rule_end as Array).is_empty(), f1.subs)
	_check("end_forge_reload_same", JSON.stringify(f1.subs) == JSON.stringify(f2.subs) and f1.items == f2.items, [f1.items, f2.items])
	# 关开关：回到回合流（结算期间在 rule 上取），两次读档取到的数不同
	XTianqiRandom.BATTLE_FROM_SAVE = false
	var o1 := _win(_at(T, 0), M, O, T)
	var o2 := _win(_at(T, 0), M, O, T)
	var of1 := _win(_at(FT, 0), XGrowthForge.CORE_MAP, 165, FT)
	XTianqiRandom.BATTLE_FROM_SAVE = true
	var want := ["starburst.immortal", "guyu_stone", "heartsteel.reward", "hubris.reward"]
	_check("end_off_on_rule", not o1.pinned and (o1.subs as Dictionary).is_empty() and want.all(func(w): return _reasons(o1.rule_end).has(w)) \
		and _reasons(of1.rule_end).has("growth_forge.core"), [o1.rule_end, of1.rule_end])
	_check("end_off_differs", JSON.stringify(o1.rule_end) != JSON.stringify(o2.rule_end), [o1.rule_end, o2.rule_end])
	# 心之钢、狂妄命中：找到命中的战斗键，读档再打整件相同；先拿一件别的装备（挪了实例编号、全档词条计数、共享预掷池）再打也相同
	for pair in [["heartsteel", XHeartsteel.ARMOR], ["hubris", XHubris.ARMOR]]:
		var who: String = pair[0]
		var armor: int = pair[1]
		var hit := -1
		for k in 300:
			if _first(XRandomStream.derive(XRandomStream.hex64(424242), "battle|%d|%d" % [T, k]), "end|" + who) < 0.10:
				hit = k
				break
		_check("end_%s_hit_found" % who, hit >= 0)
		if hit < 0:
			continue
		var h1 := _win(_at(T, hit), M, O, T)
		var h2 := _win(_at(T, hit), M, O, T)
		var st3 := _at(T, hit)
		st3.gain_gear("weapon", _any_weapon(), 1)  # 先拿一件没来源键的装备
		var h3 := _win(st3, M, O, T)
		_check("end_%s_dropped" % who, (h1.gear as Dictionary).has(armor), h1.gear.keys())
		_check("end_%s_whole_same" % who, h1.gear.get(armor, "a") == h2.gear.get(armor, "b"), [h1.gear.get(armor), h2.gear.get(armor)])
		_check("end_%s_after_other_same" % who, h1.gear.get(armor, "a") == h3.gear.get(armor, "c"), [h1.gear.get(armor), h3.gear.get(armor)])
	XStarburstBooks.IMMORTAL_CLEAR_TEST = -1
	# 分项统计：钉住的各段第一个数（=该项掷的数）在 2000 个战斗键上的命中率，对名义几率 4 个标准误之内；运行时同样 2000 次
	var n := 2000
	for item in [["end|heartsteel", XHeartsteel.REWARD_RATE], ["end|hubris", XHubris.REWARD_RATE], ["end|forge", XGrowthForge.CORE_RATE],
			["end|guyu", 1.0 / float(XGuyu.STONE_ONE_IN)], ["grant", 1.0 / 66.0]]:
		var p: float = item[1]
		var hits := 0
		var hits_rt := 0
		for k in n:
			if _first(XRandomStream.derive(XRandomStream.hex64(424242), "battle|%d|%d" % [T, k]), str(item[0])) < p:
				hits += 1
			if XRandomStream.create(XRandomStream.fresh_seed(), "rule").next_float("x") < p:  # 随机守卫：运行时对照
				hits_rt += 1
		var se := sqrt(p * (1.0 - p) / float(n))
		print("INFO end_rate %s nominal=%.4f pinned=%.4f runtime=%.4f se=%.4f" % [item[0], p, float(hits) / n, float(hits_rt) / n, se])
		_check("end_rate_%s" % item[0], absf(float(hits) / n - p) <= 4.0 * se and absf(float(hits_rt) / n - p) <= 4.0 * se, [hits, hits_rt, n])


## 本场种子派生的结算子流（段 key）的第一个数
static func _first(pin_seed: String, key: String) -> float:
	return XRandomStream.create(XRandomStream.derive(pin_seed, "reward|" + key), "reward").next_float("x")


static func _any_weapon() -> int:
	for row in XDB.table("Weapons"):
		if row is Dictionary and str(row.get("name", "")) != "" and not XEquipment.is_exclusive(XGear.template("weapon", int(row.id))):
			return int(row.id)
	return 1


func _run() -> void:
	XMessageBox.auto = true
	kit = Kit.new("xiyou_tianqi_battle_seed")
	var only := OS.get_environment("TQ_BS_ONLY")
	if only in ["", "fight"]:
		_same_fight()
	if only in ["", "plain"]:
		_plain()
	if only in ["", "base"]:
		_gear_base()
	if only in ["", "replay"]:
		_replay()
	if only in ["", "stats"]:
		_stats()
	if only in ["", "end"]:
		_end_phase()
	XTianqiRandom.BATTLE_FROM_SAVE = true
	XTianqiRandom.GEAR_BASE_FROM_SAVE = true
	XTianqiDrop.SIGNATURE = true
	XStarburstBooks.IMMORTAL_CLEAR_TEST = -1
	kit.teardown()
	var passed := results.filter(func(x): return x.passed).size()
	for x in results:
		if not x.passed:
			print("FAIL ", x.name, " ", JSON.stringify(x.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
