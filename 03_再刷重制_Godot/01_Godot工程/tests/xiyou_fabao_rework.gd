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
	feed()
	pills()
	guardian()
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


## 吃装备（O-401）：一件经验看品质；门槛按法宝等级；喂到上限就停、剩下的不扣；锁定、不在背包的不喂；预览不改；回退
func _gear_of_grade(g: int, kind := "armor") -> int:
	for r in XDB.table("Armors" if kind == "armor" else "Weapons"):
		if r is Dictionary and str(r.get("name", "")) != "" and not r.get("meta", {}).has("Magic Weapon") and not r.get("meta", {}).has("req_actors"):
			var t := XGear.template(kind, int(r.id))
			if t.has("instanceId") or true:
				if XFabaoFeed.grade_of(t) == g and int(t.get("etypeId", 0)) != 13:
					return int(r.id)
	return 0


func _bag(s: XState, base: int, n: int) -> Array:
	var out := []
	for i in n:
		var it := XGear.create("armor", base, s)
		s.gear.append(it)
		s.register_gear(it)
		out.append(it)
	return out


func feed() -> void:
	var s := _blank()
	s.set_variable(20, 1)   # 上限 12
	var fabao := XGear.template("armor", 125)
	fabao.level = 1.0
	fabao.exp = 0.0
	var common := _gear_of_grade(0)
	var good := _gear_of_grade(2)
	check("feed.grades_found", common > 0 and good > 0, [common, good])
	var bag := _bag(s, common, 60)
	check("feed.exp_common", XFabaoFeed.exp_of(bag[0]) == 18 and XFabaoFeed.min_grade(1) == 0 and XFabaoFeed.min_grade(25) == 1 and XFabaoFeed.min_grade(99) == 4)
	# 预览不改
	var pv := XFabaoFeed.feed(s, fabao, bag, null, true)
	check("feed.preview_pure", s.gear.size() == 60 and XMagicWeapon.level_of(fabao) == 1.0 and pv.capped and int(pv.to) == 12, pv)
	# 真喂：1→12 要 877 经验，普通 18 一件 → 49 件，剩 11 件不扣
	var r := XFabaoFeed.feed(s, fabao, bag)
	check("feed.to_cap", int(r.to) == 12 and r.capped and int(r.used) == 49 and s.gear.size() == 11, [r.used, r.to, s.gear.size()])
	check("feed.preview_matches", int(pv.used) == int(r.used))
	check("feed.full_reason", XFabaoFeed.reason(s, fabao, s.gear[0]) == "法宝已到本层上限")
	# 门槛：法宝 30 级（上限放到 99）时普通装备不能喂，精良能
	s.set_variable(20, 30)
	fabao.level = 30.0
	fabao.exp = 0.0
	check("feed.gate_low", XFabaoFeed.reason(s, fabao, s.gear[0]).begins_with("品质不够"), XFabaoFeed.reason(s, fabao, s.gear[0]))
	var g := _bag(s, good, 1)
	check("feed.gate_ok", XFabaoFeed.reason(s, fabao, g[0]) == "")
	# 锁定的不喂
	XItemMarks.toggle_lock(s, g[0])
	check("feed.locked", XFabaoFeed.reason(s, fabao, g[0]) == "已锁定")
	XItemMarks.toggle_lock(s, g[0])
	# 不在背包里（穿着的、别人的）
	var loose := XGear.create("armor", good)
	s.register_gear(loose)
	s.lose_gear(loose, false)   # 有实例号、但不在背包里
	check("feed.not_in_bag", XFabaoFeed.reason(s, fabao, loose) == "不在背包里", [XFabaoFeed.reason(s, fabao, loose), loose.has("instanceId")])
	# 法宝不能喂法宝
	var other := _bag(s, 3557, 1)
	check("feed.no_fabao", XFabaoFeed.reason(s, fabao, other[0]) == "不能喂")
	# 物品页菜单：法宝 30 级从「优秀」起每档一行；精良那行 1 件可喂；喂完提示、装备扣掉
	var acts := XFabaoFeed.actions(s, fabao)
	check("feed.actions", acts.size() == 6 and int(acts[0].ext) == 1 and acts[1].enabled and str(acts[1].text).contains("精良") and str(acts[1].text).contains("1 件"), acts.map(func(x): return x.text))
	var before := s.gear.size()
	var msg := XFabaoFeed.feed_grade(s, fabao, 2)
	check("feed.grade_msg", msg.begins_with("喂入 1 件，经验 +30") and s.gear.size() == before - 1, msg)
	# 回退
	XFabaoFeed.ENABLED = false
	check("feed.o-off_actions", XFabaoFeed.actions(s, fabao).is_empty())
	check("feed.o-off", XFabaoFeed.reason(s, fabao, g[0]) == "未开放")
	XFabaoFeed.ENABLED = true


## 经验丹下架（O-401）：商店不上、MagicWeaponAllGainExp 不加；回退照原版
func pills() -> void:
	var rows := [[0, 1901, 0, 0], [0, 1987, 0, 0], [0, 1693, 0, 0], [2, 125, 0, 0]]
	check("pills.goods", XFabaoFeed.filter_goods(rows) == [[0, 1693, 0, 0], [2, 125, 0, 0]])
	check("pills.bulk_off", not XBulkPills.supported_ids().has(1987))
	var s := XState.new_game(3, 1, [])
	s.set_variable(20, 30)
	var a := s.actor(1)
	var item := _wear(a, 125)
	XMagicWeapon.plugin_command(s, PackedStringArray(["MagicWeaponAllGainExp", "1000000"]))
	check("pills.no_exp", XMagicWeapon.level_of(item) == 1.0, XMagicWeapon.level_of(item))
	XFabaoFeed.NO_PILLS = false
	XMagicWeapon.plugin_command(s, PackedStringArray(["MagicWeaponAllGainExp", "1000000"]))
	check("pills.o-off_exp", XMagicWeapon.level_of(item) == 99.0, XMagicWeapon.level_of(item))
	check("pills.o-off_goods", XFabaoFeed.filter_goods(rows) == rows and XBulkPills.supported_ids().has(1987))
	XFabaoFeed.NO_PILLS = true


## 守层者重算（O-402）：天启篇存档里按层的出伤倍率、伤害抵抗；原版档、关开关照旧
func guardian() -> void:
	var s := _blank()
	check("guardian.elem", is_equal_approx(XGuardianRework.elem_factor(20), 0.5) and is_equal_approx(XGuardianRework.elem_factor(33), 0.05) and XGuardianRework.elem_factor(5) == 1.0,
		[XGuardianRework.elem_factor(20), XGuardianRework.elem_factor(33), XGuardianRework.elem_factor(5)])
	check("guardian.floor_of", XGuardianRework.floor_of(527) == 24 and XGuardianRework.floor_of(537) == 33 and XGuardianRework.floor_of(1) == 0,
		[XGuardianRework.floor_of(527), XGuardianRework.floor_of(537)])
	var plain := XEnemy.new().setup(527, 3, 100.0)
	check("guardian.plain_save_untouched", plain.output_scale == 1.0 and float(plain.passive_cache().harmRe.get(1, 0.0)) == 50000000.0,
		[plain.output_scale, plain.passive_cache().harmRe])
	s.flags["tianqi"] = {"rules": 1}
	var e := XEnemy.new().setup(527, 3, 100.0)
	check("guardian.atk", is_equal_approx(e.output_scale, 0.0243), e.output_scale)
	var hr: Dictionary = e.passive_cache().harmRe
	check("guardian.resist", not hr.is_empty() and hr.values().all(func(v): return float(v) == 7300.0), hr)
	var f1 := XEnemy.new().setup(int(XDB.rec("Troops", 4).members[0].enemyId), 3, 100.0)
	check("guardian.floor1_not_raised", f1.output_scale == 1.0, f1.output_scale)
	var normal := XEnemy.new().setup(1, 3, 100.0)
	check("guardian.normal_enemy", normal.output_scale == 1.0, normal.output_scale)
	# 实际出伤：同一下，开关开着是关掉的 0.0243 倍
	var a := s.actor(1)
	var skill := XDB.rec("Skills", 3562)
	var calc := XDamage.calculate(skill, e, a, {"critical": false, "variance": false})
	var on := XDamage.finish(calc.duplicate(true), skill, e, a)
	XGuardianRework.ATK = false
	XGuardianRework.RESIST = false
	var e2 := XEnemy.new().setup(527, 3, 100.0)
	var off := XDamage.finish(calc.duplicate(true), skill, e2, a)
	check("guardian.atk_damage", off > 0.0 and absf(on - roundf(off * 0.0243)) <= 1.0, [on, off])
	check("guardian.o-off", e2.output_scale == 1.0 and float(e2.passive_cache().harmRe.get(1, 0.0)) == 50000000.0, [e2.output_scale, e2.passive_cache().harmRe])
	XGuardianRework.ATK = true
	XGuardianRework.RESIST = true
	# 34 层鸿钧、七印里副本（按鸿蒙老祖重标）各按自己那一档；骑士不归这里
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "jianxian", "line": "war"}
	XTianqiSummit.prepare_hongjun(s)
	var hl := XBattleLogic.new()
	hl.setup(int(XTianqiSummit.data().hongjun.troop), s)
	var hj: Array = hl.enemies.filter(func(x): return not x.horseman.is_empty())
	check("guardian.hongjun_hp", absf(hl.enemies.reduce(func(t, x): return t + x.mhp, 0.0) - 6110000.0 * 8 * 0.05) < 10.0, hl.enemies.map(func(x): return x.mhp))
	check("guardian.hongjun", hj.size() == 1 and is_equal_approx(hj[0].output_scale, XGuardianRework.HONGJUN_SCALE), hl.enemies.map(func(x): return x.output_scale))
	XTianqiQiyinRule.prepare("bai", true)
	var ql := XBattleLogic.new()
	ql.setup(int(XTianqiQiyin.seal_info("bai").troops[-1]), s)
	check("guardian.qiyin_ref", not ql.enemies.is_empty() and ql.enemies.all(func(x): return is_equal_approx(x.output_scale, XGuardianRework.REF_SCALE)),
		ql.enemies.map(func(x): return x.output_scale))
	var boss_hp: float = ql.enemies.reduce(func(t, x): return maxf(t, x.mhp), 0.0)
	check("guardian.qiyin_hp", boss_hp > 0.0 and boss_hp < 5690000.0 * 8 * 0.05, boss_hp)
	var gl := XBattleLogic.new()
	gl.setup(XGuardianRework.TROOPS[24], s)
	check("guardian.hp", absf(gl.enemies.reduce(func(t, x): return t + x.mhp, 0.0) - 3000000.0 * 8 * 0.5) < 10.0 and gl.enemies.all(func(x): return x.hp == x.mhp),
		gl.enemies.map(func(x): return [x.hp, x.mhp]))
	XGuardianRework.HP = false
	var gl2 := XBattleLogic.new()
	gl2.setup(XGuardianRework.TROOPS[24], s)
	check("guardian.hp_o-off", gl2.enemies.reduce(func(t, x): return t + x.mhp, 0.0) > 1.0e13, gl2.enemies.map(func(x): return x.mhp))
	XGuardianRework.HP = true
	# 楼层里别的敌群（WORLD）：20 层地图上的普通敌群按本层守层者同比缩
	var m20 := -1
	for i in range(1, 400):
		if not XDB.rec("MapInfos", i).is_empty() and XDungeon.map_floor(i) == 20:
			m20 = i
			break
	s.map_id = m20
	var wl := XBattleLogic.new()
	wl.setup(453, s)
	var raw453 := 0.0
	for mm in XDB.rec("Troops", 453).members:
		raw453 += float(XDB.rec("Enemies", int(mm.enemyId)).params[0])
	var want := raw453 / XGuardianRework.old_total(20) * 2250000.0 * 8 * 0.5
	var got: float = wl.enemies.reduce(func(t, x): return t + x.mhp, 0.0)
	check("guardian.world_hp", m20 > 0 and absf(got - want) / want < 0.01, [m20, got, want])
	check("guardian.world_atk", wl.enemies.all(func(x): return is_equal_approx(x.output_scale, 0.074)), wl.enemies.map(func(x): return x.output_scale))
	XGuardianRework.WORLD = false
	var wl2 := XBattleLogic.new()
	wl2.setup(453, s)
	check("guardian.world_o-off", wl2.enemies.reduce(func(t, x): return t + x.mhp, 0.0) > got * 100.0 and wl2.enemies.all(func(x): return x.output_scale == 1.0))
	XGuardianRework.WORLD = true
	s.map_id = 0
	XTianqiHorsemen.prepare("war", s, "body")
	var kl := XBattleLogic.new()
	kl.setup(int(XTianqiLine.data("war").shell_troop), s)
	check("guardian.knight_untouched", not kl.enemies.is_empty() and kl.enemies.all(func(x): return x.output_scale == 1.0), kl.enemies.map(func(x): return x.output_scale))
	s.flags.erase("tianqi")
