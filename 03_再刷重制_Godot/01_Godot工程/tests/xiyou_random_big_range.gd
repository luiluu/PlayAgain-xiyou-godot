extends Node
## 随机流范围出界不作废（v0.01.08 玩家反馈：十三层深渊心之钢、狂妄、天顶剑几乎每轮都掉）。
## 原先伤害超过约 2.1e10 时浮动幅度超 2^32，流写上 error，之后 next_float 恒 0、next_int_inclusive 恒为下限，
## 10% 的心之钢／狂妄（XHeartsteel／XHubris 用 rule 流）与 1/300 的天顶剑（CE1439 变量 1463）次次命中。
## 这里查：大幅度浮动之后流还在、取数不再卡在 0／下限；出界范围照原版 Math.randomInt；磁带模式照旧报错；
## 心之钢掉落率在「先打出大伤害」之后仍约 10%。
var checks := 0
var failed := []


func check(label: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failed.append(label)
		print("FAIL ", label, " ", detail)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# 1. 大伤害浮动不让流作废
	var r := XRandomStream.create("0123456789abcdef", "rule")
	var dmg := XDamage.apply_variance(3.0e10, 20, r)
	check("variance_big.no_error", r.error == "", r.error)
	check("variance_big.in_range", dmg >= 3.0e10 * 0.8 - 1.0 and dmg <= 3.0e10 * 1.2 + 1.0, dmg)
	check("variance_big.draws", r.draws == 2, r.draws)
	var huge := XDamage.apply_variance(-5.0e20, 20, r)
	check("variance_huge.no_error", r.error == "" and huge <= -5.0e20 * 0.8 and huge >= -5.0e20 * 1.2, [r.error, huge])
	# 之后的取数正常：100 次 next_float 不会全是 0，1～300 不会全是 1
	var zeros := 0
	var ones := 0
	for i in 300:
		if r.next_float("after") == 0.0:
			zeros += 1
		if r.next_int_inclusive(1, 300, "after_int") == 1:
			ones += 1
	check("after.float_not_stuck", zeros < 5, zeros)
	check("after.int_not_stuck", ones < 10, ones)
	# 小幅度照旧走整数路径（取数和原先一致）
	var a := XRandomStream.create("fedcba9876543210", "rule")
	var b := XRandomStream.create("fedcba9876543210", "rule")
	for i in 32:
		var amp := 1000 + i * 37
		var va := a.next_int_inclusive(0, amp, "variance_a") + a.next_int_inclusive(0, amp, "variance_b") - amp
		check("variance_small.same:" + str(i), XDamage.apply_variance(float(amp) * 5.0, 20, b) == float(amp) * 5.0 + va, i)

	# 2. 出界范围照原版：上限 < 下限、模数 ≤ 0 得下限／0，流照常
	var c := XRandomStream.create("1111111111111111", "world")
	check("inverted.lo", c.next_int_inclusive(0, -1, "inv") == 0 and c.error == "", c.error)
	check("modulus0", c.next_index_mod(0, "mod") == 0 and c.error == "", c.error)
	var big := c.next_int_inclusive(5, 5 + 100000000000, "big")
	check("big_range", big >= 5 and big <= 5 + 100000000000 and c.error == "", [big, c.error])
	check("draws_counted", c.draws == 3, c.draws)

	# 3. 磁带模式照旧报错（参照对照要发现越界）
	var t := XRandomStream.scripted([{"kind": "uint32", "value": 1}])
	t.next_int_inclusive(0, -1, "inv")
	check("scripted.still_errors", t.error == "invalid_random_range", t.error)

	# 4. 心之钢：先打出大伤害再掷掉落，掉率约 10%（原先恒中）
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.map_id = XHeartsteel.REWARD_MAP
	s.unknown_origin = XHeartsteel.REWARD_ORIGIN
	var got := 0
	var n := 2000
	for i in n:
		var logic := XBattleLogic.new()
		logic.state = s
		logic.troop_id = 454
		XDamage.apply_variance(4.0e10, 20, logic._rule())
		XHeartsteel._reward_rolled = false
		if XHeartsteel.clear_reward(logic, 0):
			got += 1
	check("heartsteel.rate_about_10pct", got > n * 0.07 and got < n * 0.13, got)
	XState.current = null
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failed.size(), "total": checks}))
	get_tree().quit(0 if failed.is_empty() else 1)
