extends Node
## 天启篇「七首之龙」（XTianqiQiyinDragon，tianqi_data/qiyin_dragon.json）的规则自检：
## 一、表齐全：七印顺序 bai→mo、五档难度、五件神器、出现率 3%／5%／6%／8%／10%、保底 30、最多存 1 次。
## 二、出现：连空 30 次下一次必出；存着（或刚出、在打）时不判定、不抽随机数、保底不涨；输了合上。
## 三、奖励：首杀只给一次 extra_recruit；每次必给自选印的真印套装件（部位在六件防具里）和 1 瓶龙血；神器五件都可能出。
## 四、龙血：每人最多 3 瓶，第 4 瓶拒绝、不消耗；加成 0／3%／6%／9%。
## 五、战斗数据：艰险 250 万，其他难度乘敌人血量倍率，七段加起来等于总血。
## 六、统计（固定种子）：艰险 20000 次判定的出现率贴着算上保底的理论值；武器 33%、神器 3%。
## 七、数值好看：表里设计数值不含 4（豁免键写在表头）。
## 不用转换产物，不建存档。

const EPS := 1e-9

var results: Array = []


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XTianqiQiyinDragon.reload()
	XTianqiBalance.reload()
	_table()
	_rift()
	_reward()
	_blood()
	_fight()
	_stats()
	_nice()
	var passed := 0
	for r in results:
		if r.passed:
			passed += 1
		else:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _floats(values: Array) -> XRandomStream:
	var tape := []
	for v in values:
		tape.append({"kind": "float" if v is float else "uint32", "value": v})
	return XRandomStream.scripted(tape)


## 先把状态推到「在打」：出现（用保底以外的低随机数）→ 进
func _fighting(state: Dictionary) -> Dictionary:
	var s: Dictionary = XTianqiQiyinDragon.roll_rift(state, "zhengdao", _floats([0.0])).state
	return XTianqiQiyinDragon.enter_rift(s).state


func _table() -> void:
	var d := XTianqiQiyinDragon.data()
	_check("表能读", not d.is_empty())
	_check("表头 draft／_note 写来源", d.get("draft") == true and str(d.get("_note", "")).contains("七印祭坛方案 v0.4") and str(d.get("_note", "")).contains("Kyo 11-12 定稿"))
	var want_seals := ["bai", "hong", "hei", "hui", "xun", "zhen", "mo"]
	_check("七印与顺序", XTianqiQiyinDragon.seals() == want_seals, XTianqiQiyinDragon.seals())
	_check("揭印顺序同七印", d.fight.reveal_order == want_seals, d.fight.reveal_order)
	_check("难度键同 XTianqiBalance", d.difficulties == XTianqiBalance.difficulty_keys(), [d.difficulties, XTianqiBalance.difficulty_keys()])
	var want := {"xunchang": 0.03, "jianxian": 0.05, "jiusi": 0.06, "lianyu": 0.08, "zhengdao": 0.1}
	for k in want:
		_check("出现率：" + k, absf(XTianqiQiyinDragon.rift_chance(k) - want[k]) < EPS, XTianqiQiyinDragon.rift_chance(k))
	_check("没有的难度出现率 0", XTianqiQiyinDragon.rift_chance("nope") == 0.0)
	_check("暗保底 30", XTianqiQiyinDragon.pity_after() == 30)
	_check("最多存 1 次", int(d.rift.max_stored) == 1)
	_check("神器五件", d.reward.artifacts == ["bow_crown", "great_sword", "scales", "grey_scythe", "seven_seal_scroll"], d.reward.artifacts)
	_check("武器 33%、神器 3%", absf(float(d.reward.weapon_chance) - 0.33) < EPS and absf(float(d.reward.artifact_chance) - 0.03) < EPS)
	_check("龙血 3% 一瓶、每人 3 瓶", absf(float(d.dragon_blood.per_bottle) - 0.03) < EPS and XTianqiQiyinDragon.max_blood_per_actor() == 3)
	_check("首杀招募照 30 层", int(d.reward.recruit_floor) == 30)


func _rift() -> void:
	var s := XTianqiQiyinDragon.new_state()
	# 高随机数（0.99）在任何难度都不出
	for i in 30:
		var r := XTianqiQiyinDragon.roll_rift(s, "zhengdao", _floats([0.99]))
		if r.appeared:
			_check("前 30 次高随机数不出", false, i)
			return
		s = r.state
	_check("连空 30 次计数 30", int(s.misses) == 30, s.misses)
	var r31 := XTianqiQiyinDragon.roll_rift(s, "zhengdao", _floats([0.99]))
	_check("第 31 次必出（暗保底）", r31.appeared and r31.pity and r31.state.rift == "offered", r31)
	_check("出了保底归零", int(r31.state.misses) == 0)
	_check("传进去的状态不改", int(s.misses) == 30 and s.rift == "none")
	# 低随机数正常出、不算保底
	var low := XTianqiQiyinDragon.roll_rift(XTianqiQiyinDragon.new_state(), "xunchang", _floats([0.02]))
	_check("寻常 0.02 出", low.appeared and not low.pity)
	var miss := XTianqiQiyinDragon.roll_rift(XTianqiQiyinDragon.new_state(), "xunchang", _floats([0.03]))
	_check("寻常 0.03 不出（左闭右开）", not miss.appeared and int(miss.state.misses) == 1)
	_check("错难度返回 error", XTianqiQiyinDragon.roll_rift(s, "nope", _floats([])).has("error"))
	# 存着
	var st := XTianqiQiyinDragon.store_rift(r31.state)
	_check("能存", not st.has("error") and st.state.rift == "stored")
	var stored: Dictionary = st.state
	stored.misses = 7  # 人为放个数，看存着时不涨
	var empty_tape := _floats([])
	var again := XTianqiQiyinDragon.roll_rift(stored, "zhengdao", empty_tape)
	_check("存着时不判定", not again.rolled and not again.appeared and again.state.rift == "stored")
	_check("存着时保底不涨", int(again.state.misses) == 7)
	_check("存着时不抽随机数", empty_tape.draws == 0 and empty_tape.error.is_empty(), empty_tape.error)
	_check("存着时不能再存（最多 1 次）", XTianqiQiyinDragon.store_rift(stored).has("error"))
	var offered_roll := XTianqiQiyinDragon.roll_rift(r31.state, "zhengdao", _floats([]))
	_check("刚出现还没回答时也不判定", not offered_roll.rolled)
	# 进、输
	var en := XTianqiQiyinDragon.enter_rift(stored)
	_check("存着的能进", not en.has("error") and en.state.rift == "fighting")
	_check("当场也能直接进", XTianqiQiyinDragon.enter_rift(r31.state).state.rift == "fighting")
	_check("没有龙隙进不去", XTianqiQiyinDragon.enter_rift(XTianqiQiyinDragon.new_state()).has("error"))
	var fight_roll := XTianqiQiyinDragon.roll_rift(en.state, "zhengdao", _floats([]))
	_check("在打时也不判定", not fight_roll.rolled)
	var lost := XTianqiQiyinDragon.lose_rift(en.state)
	_check("输了龙隙合上", not lost.has("error") and lost.state.rift == "none")
	_check("合上后不能再进（存的那次没了）", XTianqiQiyinDragon.enter_rift(lost.state).has("error"))
	_check("合上后重新判定", XTianqiQiyinDragon.roll_rift(lost.state, "jianxian", _floats([0.99])).rolled)
	_check("不在打不能算输", XTianqiQiyinDragon.lose_rift(stored).has("error"))


func _reward() -> void:
	var s := _fighting(XTianqiQiyinDragon.new_state())
	# 部位 uint 2→waist；武器 0.5 不中；神器 0.5 不中
	var r1 := XTianqiQiyinDragon.reward(s, "hei", _floats([3, 0.5, 0.5]))
	_check("奖励没出错", not r1.has("error"), r1.get("error"))
	_check("首杀给 extra_recruit", r1.extra_recruit == true and int(r1.recruit_floor) == 30)
	_check("必给自选印的真印件", r1.true_set_piece.seal == "hei" and r1.true_set_piece.true_seal == true and r1.true_set_piece.part == "waist", r1.true_set_piece)
	_check("必给龙血 1 瓶", int(r1.dragon_blood) == 1 and int(r1.state.blood_stock) == 1)
	_check("没中武器、神器为空", r1.weapon == null and r1.artifact == null)
	_check("打完龙隙关上、记首杀", r1.state.rift == "none" and r1.state.first_kill == true)
	# 第二次：武器中（0.1）印 uint 6→mo；神器中（0.01）pick 3→grey_scythe
	var r2 := XTianqiQiyinDragon.reward(_fighting(r1.state), "bai", _floats([0, 0.1, 6, 0.01, 3]))
	_check("第二次不再给 extra_recruit", r2.extra_recruit == false)
	_check("第二次照样必给", r2.true_set_piece.seal == "bai" and r2.true_set_piece.part == "head" and int(r2.dragon_blood) == 1 and int(r2.state.blood_stock) == 2)
	_check("中了真印毕业武器（流派随机）", r2.weapon is Dictionary and r2.weapon.seal == "mo" and r2.weapon.true_seal == true, r2.weapon)
	_check("中了神器", r2.artifact == "grey_scythe", r2.artifact)
	_check("33% 边界不中", XTianqiQiyinDragon.reward(_fighting(r1.state), "bai", _floats([0, 0.33, 0.99])).weapon == null)
	_check("不在打不给奖励", XTianqiQiyinDragon.reward(XTianqiQiyinDragon.new_state(), "bai", _floats([])).has("error"))
	_check("错的印不给奖励", XTianqiQiyinDragon.reward(s, "lv", _floats([])).has("error"))
	# 每个印都能自选；部位都在六件防具里
	var parts := ["head", "body", "hands", "waist", "legs", "feet"]
	var rng := XRandomStream.create(XRandomStream.derive("0123456789abcdef", "qiyin_dragon_parts"), "reward")
	var seen_parts := {}
	var all_ok := true
	for i in 300:
		var seal: String = XTianqiQiyinDragon.seals()[i % 7]
		var r := XTianqiQiyinDragon.reward(s, seal, rng)
		all_ok = all_ok and r.true_set_piece.seal == seal and parts.has(r.true_set_piece.part)
		seen_parts[r.true_set_piece.part] = true
	_check("七印都能自选、部位在六件防具里", all_ok)
	_check("六个部位都会出", seen_parts.size() == 6, seen_parts.keys())
	# 神器五件都可能出：pick 0..4
	var arts := {}
	for i in 5:
		var r := XTianqiQiyinDragon.reward(s, "bai", _floats([0, 0.99, 0.0, i]))
		arts[r.artifact] = true
	_check("神器五件都可能出", arts.size() == 5 and not arts.has(null), arts.keys())


func _blood() -> void:
	var s := XTianqiQiyinDragon.new_state()
	_check("没有龙血不能喝", not XTianqiQiyinDragon.can_drink(s, "a") and XTianqiQiyinDragon.drink(s, "a").reason == "no_blood")
	s.blood_stock = 5
	var want := [0.0, 0.03, 0.06, 0.09]
	_check("没喝加成 0", absf(XTianqiQiyinDragon.bonus(s, "a") - want[0]) < EPS)
	for i in 3:
		_check("第 %d 瓶能喝" % (i + 1), XTianqiQiyinDragon.can_drink(s, "a"))
		var d := XTianqiQiyinDragon.drink(s, "a")
		_check("第 %d 瓶喝下" % (i + 1), d.ok and int(d.state.blood_stock) == 5 - i - 1)
		s = d.state
		_check("加成 %d%%" % ((i + 1) * 3), absf(XTianqiQiyinDragon.bonus(s, "a") - want[i + 1]) < EPS, XTianqiQiyinDragon.bonus(s, "a"))
	_check("第 4 瓶不能喝", not XTianqiQiyinDragon.can_drink(s, "a"))
	var d4 := XTianqiQiyinDragon.drink(s, "a")
	_check("第 4 瓶拒绝、不消耗", not d4.ok and d4.reason == "full" and int(d4.state.blood_stock) == 2 and int(d4.state.blood.a) == 3)
	_check("加成封顶 9%", absf(XTianqiQiyinDragon.bonus(d4.state, "a") - 0.09) < EPS)
	_check("别的角色另算", XTianqiQiyinDragon.can_drink(s, "b") and XTianqiQiyinDragon.bonus(s, "b") == 0.0)


func _fight() -> void:
	_check("艰险 250 万", XTianqiQiyinDragon.max_hp("jianxian") == 2500000)
	for k in XTianqiBalance.difficulty_keys():
		var f := XTianqiQiyinDragon.fight_data(k)
		var want := int(round(2500000.0 * float(XTianqiBalance.difficulty(k).enemy_hp)))
		_check("血量乘敌人倍率：" + k, int(f.max_hp) == want, [f.max_hp, want])
		var sum := 0
		for v in f.segment_hp:
			sum += int(v)
		_check("七段加起来等于总血：" + k, f.segment_hp.size() == 7 and sum == int(f.max_hp))
	var f0 := XTianqiQiyinDragon.fight_data("jianxian")
	_check("每回合 3 次行动", f0.actions_per_turn == 3)
	_check("攻防照 36 层普通首领、一击约 8.5 万", int(f0.stats_ref.floor) == 36 and int(f0.stats_ref.single_hit) == 85000)
	_check("灰印缓期 2 回合", f0.grey_reprieve.seal == "hui" and int(f0.grey_reprieve.turns) == 2 and f0.reveal_order.find("hui") == 3)
	_check("没有的难度战斗表为空", XTianqiQiyinDragon.fight_data("nope").is_empty())


func _stats() -> void:
	# 艰险 20000 次判定：有龙隙就当场进、马上打赢（龙隙关上），再接着判定
	var rng := XRandomStream.create(XRandomStream.derive("0123456789abcdef", "qiyin_dragon_rift"), "rule")
	var s := XTianqiQiyinDragon.new_state()
	var n := 20000
	var hit := 0
	var pity := 0
	for i in n:
		var r := XTianqiQiyinDragon.roll_rift(s, "jianxian", rng)
		s = r.state
		if r.appeared:
			hit += 1
			if r.pity:
				pity += 1
			s.rift = "none"
	var p := 0.05
	var cycle := 0.0
	for k in 31:
		cycle += pow(1.0 - p, k)
	var expect := 1.0 / cycle  # 算上保底的长期出现率，约 6.28%
	var rate := float(hit) / n
	print("STAT rift jianxian n=%d hit=%d rate=%.4f expect=%.4f pity=%d" % [n, hit, rate, expect, pity])
	_check("艰险出现率贴着理论值（±0.6%）", absf(rate - expect) < 0.006, [rate, expect])
	_check("艰险出现率高于 5%（保底抬高）", rate > 0.05, rate)
	# 武器 33%、神器 3%：20000 次奖励
	var rr := XRandomStream.create(XRandomStream.derive("0123456789abcdef", "qiyin_dragon_reward"), "reward")
	var fight := _fighting(XTianqiQiyinDragon.new_state())
	var w := 0
	var a := 0
	var w_seals := {}
	var arts := {}
	for i in n:
		var r := XTianqiQiyinDragon.reward(fight, "bai", rr)
		if r.weapon != null:
			w += 1
			w_seals[r.weapon.seal] = true
		if r.artifact != null:
			a += 1
			arts[r.artifact] = true
	var wr := float(w) / n
	var ar := float(a) / n
	print("STAT reward n=%d weapon=%.4f artifact=%.4f" % [n, wr, ar])
	_check("武器约 33%（±1.5%）", absf(wr - 0.33) < 0.015, wr)
	_check("神器约 3%（±0.6%）", absf(ar - 0.03) < 0.006, ar)
	_check("武器七个流派都出过", w_seals.size() == 7, w_seals.keys())
	_check("统计里神器五件都出过", arts.size() == 5, arts.keys())
	_check("随机流没出错", rng.error.is_empty() and rr.error.is_empty())


func _nice() -> void:
	var bad := XTianqiQiyinDragon.nice_number_violations()
	_check("设计数值不含 4", bad.is_empty(), bad)
