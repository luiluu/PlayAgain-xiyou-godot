extends Node
## 卖装卡顿（v0.01.09 玩家反馈「卖装卡、黑几秒」，O-待定-1 XAlienation.FAST_RESERVED）：
## - 等价：同一背包（几百件真模板装备，含吞器异化装备与被借的供体、身上的吞器）在开关开／关下，
##   挂机自动卖出（安全出售与旧筛法）、一键出售卖掉的件、所得金钱、剩下的背包完全一样；reserved 逐件（批内、批外、带 except）一致。
## - 提速：同一背包整批自动卖出，开着比关着快 3 倍以上（关着是 v0.01.09 的写法，背包每多一倍耗时约翻四倍）。
var results := []
const N := 800


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


## 一份固定的背包：真模板装备（掷过词缀），第 3、7 件武器改成吞器异化、借第 10、20 件武器当供体，身上再挂一件借第 30 件的吞器
func proto() -> Dictionary:
	var s := XState.new_game(3, 8, [10, 9])
	XState.current = s
	s.gear.clear()
	var pool := []
	for t in ["Weapons", "Armors"]:
		var rows: Array = XDB.table(t)
		for i in range(1, rows.size()):
			if rows[i] is Dictionary and str(rows[i].get("name", "")) != "" and rows[i].get("meta", {}).has("quality"):
				pool.append(["weapon" if t == "Weapons" else "armor", i])
	var k := 0
	while s.gear.size() < N:
		var p = pool[(k * 7919) % pool.size()]
		k += 1
		var e := XGear.create(p[0], p[1], s)
		if e.is_empty():
			continue
		s.register_gear(e)
		s.gear.append(e)
	var ws := s.gear.filter(func(e): return str(e.kind) == "weapon")
	for pair in [[3, 10], [7, 20]]:
		ws[pair[0]]["alien"] = {"affix": "swallow", "origin": "mob", "config": {"donorId": str(ws[pair[1]].instanceId)}}
	var worn: Dictionary = ws[40].duplicate(true)
	worn["instanceId"] = "xg:%d" % (s.next_gear_id + 1000)
	worn["alien"] = {"affix": "swallow", "origin": "boss", "config": {"donorId": str(ws[30].instanceId)}}
	return {"gear": s.gear, "worn": worn, "donors": [str(ws[10].instanceId), str(ws[20].instanceId), str(ws[30].instanceId)],
		"next": s.next_gear_id}


func fresh(p: Dictionary) -> XState:
	var s := XState.new_game(3, 8, [10, 9])
	XState.current = s
	s.gear = p.gear.duplicate(true)
	s.next_gear_id = int(p.next)
	var a := s.actor(8)
	a.equips[0] = p.worn.duplicate(true)   # 身上的吞器（_equipped 里能看到）
	s.gold = 0
	s.hang_up["SellWeapon"] = {"SellQuality": 1}
	var c := XHangUpAuto.sell_config(s)
	for q in 16:
		c["quality%d" % q] = true
	return s


func ids(s: XState) -> Array:
	return s.gear.map(func(e): return str(e.instanceId))


## 一种卖法在开关开／关下各跑一次（同一背包），比件数、金额、剩下的背包与吞器供体
func compare(name: String, p: Dictionary, sell: Callable) -> Array:
	var out := []
	for fast in [true, false]:
		XAlienation.FAST_RESERVED = fast
		XSafeSell.ONE_PASS = fast
		var s := fresh(p)
		var t0 := Time.get_ticks_usec()
		var n = sell.call(s)
		var us := Time.get_ticks_usec() - t0
		out.append({"n": n, "gold": s.gold, "left": ids(s), "us": us})
	XAlienation.FAST_RESERVED = true
	XSafeSell.ONE_PASS = true
	check(name + "_same_count", out[0].n == out[1].n, [out[0].n, out[1].n])
	check(name + "_same_gold", out[0].gold == out[1].gold and out[0].gold > 0, [out[0].gold, out[1].gold])
	check(name + "_same_left", out[0].left == out[1].left, [out[0].left.size(), out[1].left.size()])
	check(name + "_sold_some", out[0].left.size() < N and out[0].left.size() > 0, out[0].left.size())
	for d in p.donors:
		check(name + "_donor_kept_" + d, out[0].left.has(d))
	print("%s：N=%d 开 %.1fms 关 %.1fms 卖 %s 件" % [name, N, out[0].us / 1000.0, out[1].us / 1000.0, str(out[0].n)])
	return out


## 商店一键出售七档逐档卖一遍（件数相加）
func onekey_all(st: XState) -> int:
	var n := 0
	for g in 7:
		n += int(XItemMarks.onekey_sell(st, g)[0])
	return n


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_sell_lag"
	check("default_on", XAlienation.FAST_RESERVED and XSafeSell.ONE_PASS)
	var p := proto()
	# reserved 逐件一致：批外、批内、带 except（排除借第 10 件的那件吞器后，第 10 件不算被借）
	var s := fresh(p)
	var holder: Dictionary = s.gear.filter(func(e): return str(e.kind) == "weapon")[3]
	var slow := []
	var slow_except := []
	XAlienation.FAST_RESERVED = false   # 回退支：v0.01.09 的逐件现算
	for e in s.gear:
		slow.append(XAlienation.reserved(s, e))
		slow_except.append(XAlienation.reserved(s, e, holder))
	XAlienation.FAST_RESERVED = true
	var fast := []
	var fast_except := []
	for e in s.gear:
		fast.append(XAlienation.reserved(s, e))
		fast_except.append(XAlienation.reserved(s, e, holder))
	XAlienation.begin_batch(s)
	var batch := []
	var batch_except := []
	for e in s.gear:
		batch.append(XAlienation.reserved(s, e))
		batch_except.append(XAlienation.reserved(s, e, holder))
	XAlienation.end_batch()
	check("reserved_count", slow.count(true) == 3, slow.count(true))
	check("reserved_fast_same", fast == slow)
	check("reserved_batch_same", batch == slow)
	check("reserved_except_same", fast_except == slow_except and batch_except == slow_except and slow_except.count(true) == 2)
	check("batch_closed", XAlienation._batch_depth == 0 and XAlienation._batch_donors.is_empty())
	# 换了存档的批：别的 XState 不读这张表
	var other := fresh(p)
	XAlienation.begin_batch(s)
	other.gear = other.gear.filter(func(e): return not e.has("alien"))
	check("batch_other_state", not XAlienation.reserved(other, other.gear.filter(func(e): return str(e.instanceId) == p.donors[0])[0]))
	XAlienation.end_batch()

	# O-待定-2：跨帧的旧计划照原版每件再判（期间锁定的那件不卖）；同一帧的计划只查还在不在背包
	var sp := fresh(p)
	var plan := XSafeSell.plan(sp)
	check("plan_has_frame", int(plan.frame) == Engine.get_process_frames())
	var locked: Dictionary = plan.sell[0]
	plan.frame = int(plan.frame) - 1
	locked.name = XItemMarks.LOCK + str(locked.name)
	var gone: Dictionary = plan.sell[1]
	sp.lose_gear(gone)
	var r := XSafeSell.sell_plan(sp, plan)
	check("stale_plan_rechecks", sp.gear.has(locked) and int(r[0]) == plan.sell.size() - 2, [r, plan.sell.size()])
	sp = fresh(p)
	plan = XSafeSell.plan(sp)
	gone = plan.sell[1]
	sp.lose_gear(gone)
	r = XSafeSell.sell_plan(sp, plan)
	check("fresh_plan_skips_missing", int(r[0]) == plan.sell.size() - 1, [r, plan.sell.size()])

	# 挂机自动卖出（安全出售，v0.01.09 默认）、旧筛法、一键出售
	compare("hangup_safe", p, func(st: XState):
		XHangUpAuto.better_frequency = 0
		return XHangUpAuto.after_battle_sell(st))
	XSafeSell.ENABLED = false
	compare("hangup_legacy", p, func(st: XState):
		XHangUpAuto.better_frequency = 0
		return XHangUpAuto.after_battle_sell(st))
	compare("onekey_legacy", p, onekey_all)
	XSafeSell.ENABLED = true
	var warm := compare("onekey_safe", p, onekey_all)
	# 提速看第二轮以后（第一次卖某种底子要解析它的卖出报酬备注，开着的那次先跑、替关着的那次热了缓存）
	check("speedup_3x", warm[1].us > 3 * warm[0].us, [warm[0].us, warm[1].us])
	# 发行模式（ReleaseEntry.is_release，天启篇空壳那一路）：同样开着、同样一致
	ReleaseEntry.simulate_release = true
	check("release_mode_on", ReleaseEntry.is_release() and XAlienation.FAST_RESERVED)
	compare("release_hangup_safe", p, func(st: XState):
		XHangUpAuto.better_frequency = 0
		return XHangUpAuto.after_battle_sell(st))
	ReleaseEntry.simulate_release = false

	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
