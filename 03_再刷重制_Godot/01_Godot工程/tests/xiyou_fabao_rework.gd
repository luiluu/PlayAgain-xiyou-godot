extends Node
## 法宝与积分重构 v0.2 一期（O-388 法宝上限、O-389 抽奖，Kyo 11-13 通过）：
## - 法宝上限：XMagicWeapon.LEVEL_99／FLOOR_CAP（min(99, 9＋3×最高到达层)），超上限经验作废，天启篇存档也照上限（TIANQI_TOO），三档回退。
## - 抽奖：XLotteryRework.SAVED_STREAM（抽奖随机流进存档：读档后同一抽结果相同，世界随机不影响它）、
##   EV_NOT_POSITIVE（范围与对话框文字换掉；批量模式真跑 1432／1431 各几千抽，平均积分变化不为正），两档回退。
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		print("FAIL ", tag, " ", JSON.stringify(detail).left(800))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XConfig.path_override = "user://test_xiyou_fabao_rework/options.json"
	fabao_cap()
	lottery_ranges()
	lottery_stream()
	lottery_ev()
	XConfig.path_override = ""
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)


func _blank() -> XState:
	var s := XState.new_game_blank()
	XState._become_current(s)
	return s


func _wear(a: XActor, base: int) -> Dictionary:
	var item := XGear.template("armor", base)
	var slot := a.equip_slots().find(int(item.etypeId))
	a.equips[slot] = item
	a.refresh_passive()
	return item


## 法宝「超级赛亚人」（防具 125，数据上限走插件参数 888）与 4001 冥河断罪镰（备注写 888）
func fabao_cap() -> void:
	var s := _blank()
	var a := s.actor(1)
	var plain := XGear.template("armor", 125)
	var noted := XGear.template("armor", 4001)
	check("cap.magic", XMagicWeapon.is_magic(plain) and XMagicWeapon.is_magic(noted))
	var want := {0: 12, 1: 12, 2: 15, 10: 39, 20: 69, 29: 96, 30: 99, 33: 99}
	for f in want:
		s.set_variable(20, f)
		check("cap.floor%d" % f, XMagicWeapon.level_cap(s) == want[f] and XMagicWeapon.max_level(plain) == want[f] and XMagicWeapon.max_level(noted) == want[f], [f, XMagicWeapon.level_cap(s), XMagicWeapon.max_level(plain)])
	# 超上限的经验作废：第 1 层一颗究极丹只到 12 级
	s.set_variable(20, 1)
	var item := _wear(a, 125)
	XMagicWeapon.gain_exp(item, 1000000.0, a)
	check("cap.pill_floor1", XMagicWeapon.level_of(item) == 12.0, XMagicWeapon.level_of(item))
	XMagicWeapon.gain_exp(item, 1000000.0, a)
	check("cap.full_no_exp", XMagicWeapon.level_of(item) == 12.0, XMagicWeapon.level_of(item))
	# 上到 10 层后接着升
	s.set_variable(20, 10)
	XMagicWeapon.gain_exp(item, 1000000.0, a)
	check("cap.floor10_continue", XMagicWeapon.level_of(item) == 39.0, XMagicWeapon.level_of(item))
	# 贝吉特那组数：12 级的超级赛亚人给的生命是 500×12（再 ×200%），远小于原先几百级
	check("cap.param_small", a.mhp < 40000, a.mhp)
	# 只封 99
	XMagicWeapon.FLOOR_CAP = false
	check("cap.o-off-floor", XMagicWeapon.level_cap(s) == 99 and XMagicWeapon.max_level(plain) == 99.0, XMagicWeapon.max_level(plain))
	# 全部回退：照原版 888
	XMagicWeapon.LEVEL_99 = false
	check("cap.o-off-all", XMagicWeapon.level_cap(s) == 0 and XMagicWeapon.max_level(plain) == 888.0 and XMagicWeapon.max_level(noted) == 888.0, XMagicWeapon.max_level(plain))
	XMagicWeapon.LEVEL_99 = true
	XMagicWeapon.FLOOR_CAP = true
	# 天启篇存档也照上限；TIANQI_TOO 关掉时照数据；阶按 top_level（99）
	s.flags["tianqi"] = {"rules": 1}
	check("cap.tianqi", XMagicWeapon.level_cap(s) == 39 and XMagicWeapon.max_level(plain) == 39.0 and XMagicWeapon.top_level(plain) == 99.0, XMagicWeapon.max_level(plain))
	XMagicWeapon.TIANQI_TOO = false
	check("cap.tianqi_o-off", XMagicWeapon.level_cap(s) == 0 and XMagicWeapon.max_level(plain) == 888.0, XMagicWeapon.max_level(plain))
	XMagicWeapon.TIANQI_TOO = true
	s.flags.erase("tianqi")
	# 没有存档对象（工具、预览）照数据
	XState.current = null
	check("cap.no_state", XMagicWeapon.max_level(plain) == 888.0)


func lottery_ranges() -> void:
	check("range.1432", XLotteryRework.remap(1432, -400, 600) == [-500, 500] and XLotteryRework.remap(1432, -300, 850) == [-650, 500])
	check("range.other", XLotteryRework.remap(1432, 1, 5) == [1, 5] and XLotteryRework.remap(1200, -400, 600) == [-400, 600])
	check("text.1432", XLotteryRework.text(1432, "(随机获得-400~+600肝帝积分)[二阶段基础门槛400，可减免]") == "(随机获得-500~+500肝帝积分)[二阶段基础门槛400，可减免]")
	# 数据里的每个被换范围、被换文字都真的存在（数据变了这里先报）
	for ce in XLotteryRework.RANGES:
		var have := {}
		var texts := []
		for c in XDB.rec("CommonEvents", ce).list:
			if int(c.code) == 122 and int(c.parameters[3]) == 2:
				have["%d,%d" % [int(c.parameters[4]), int(c.parameters[5])]] = true
			if int(c.code) == 401:
				texts.append(str(c.parameters[0]))
		for k in XLotteryRework.RANGES[ce]:
			check("range.data_%d_%s" % [ce, k], have.has(k), have.keys())
		for k in XLotteryRework.TEXTS.get(ce, {}):
			check("text.data_%d_%s" % [ce, k], texts.any(func(t): return t.contains(k)), texts)
	XLotteryRework.EV_NOT_POSITIVE = false
	check("range.o-off", XLotteryRework.remap(1432, -400, 600) == [-400, 600] and XLotteryRework.text(1432, "-400~+600") == "-400~+600")
	XLotteryRework.EV_NOT_POSITIVE = true


func _rolls(s: XState, n: int) -> Array:
	var core := MVEventCore.new()
	core.lottery_id = 1432
	var out := []
	for i in n:
		out.append(core._variable_random(1, 1000000))
	return out


func lottery_stream() -> void:
	var s := _blank()
	_rolls(s, 7)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	check("stream.saved", saved.get("lotteryRandom", {}).get("draws", 0) == 7.0, saved.get("lotteryRandom"))
	var first := _rolls(s, 20)
	# 读档：同一抽结果相同（SL 无效）
	var back := XState.from_dict(saved)
	XState._become_current(back)
	check("stream.reload_same", _rolls(back, 20) == first)
	# 世界随机推进不影响下一抽
	var back2 := XState.from_dict(saved)
	XState._become_current(back2)
	for i in 50:
		back2.world_random().next_float("test")
	check("stream.world_independent", _rolls(back2, 20) == first)
	# 不是抽奖事件的随机不走它
	var plain := MVEventCore.new()
	var draws_before := int(back2.lottery_random.draws)
	plain._variable_random(1, 100)
	check("stream.non_lottery", int(back2.lottery_random.draws) == draws_before)
	# 新局各自的种子
	var a := _blank()
	var ra := _rolls(a, 5)
	var b := _blank()
	check("stream.fresh_seed", _rolls(b, 5) != ra)
	# 固定随机（参照对照）照旧
	MVEventCore.fixed_random = 0.5
	var before := int(b.lottery_random.draws)
	check("stream.fixed", _rolls(b, 1) == [500001] and int(b.lottery_random.draws) == before)
	MVEventCore.fixed_random = -1.0
	# 回退：走世界随机流，不写存档
	XLotteryRework.SAVED_STREAM = false
	var c := _blank()
	_rolls(c, 3)
	check("stream.o-off", c.lottery_random.is_empty())
	XLotteryRework.SAVED_STREAM = true


## 批量模式（文字跳过、选项选第 0 项「赢下所有」）真跑整条事件 n 次，返回平均积分变化
func _mean(ce: int, n: int) -> float:
	var s := _blank()
	s.set_switch(XCasinoBatch.SWITCH_OPEN, true)
	var total := 0.0
	for i in n:
		s.set_variable(206, 100000)
		var core := MVEventCore.new()
		core.list = XCasinoBatch.native_list(ce)
		core.casino_draw = {"second": false}
		core.casino_root = true
		core.lottery_id = ce
		var steps := 0
		while steps < 5000:
			steps += 1
			var r := core.advance()
			if r.kind == "done":
				break
			if r.kind != "child":
				core.resume(null)
		total += s.variable(206) - 100000
	return total / n


func lottery_ev() -> void:
	var m1432 := _mean(1432, 4000)
	var m1431 := _mean(1431, 6000)
	print("ev 1432 %.1f  1431 %.1f" % [m1432, m1431])
	# 一抽标准差约 300（1432）／约 6000（1431），留 3 个标准误的余量
	check("ev.1432", m1432 < 3.0 * 330.0 / sqrt(4000.0), m1432)
	check("ev.1431", m1431 < 3.0 * 6500.0 / sqrt(6000.0), m1431)
	XLotteryRework.EV_NOT_POSITIVE = false
	var old := _mean(1432, 4000)
	print("ev 1432 原版 %.1f" % old)
	check("ev.1432_o-off_positive", old > 100.0, old)
	XLotteryRework.EV_NOT_POSITIVE = true
