extends Node
## 天启篇按段异化专项（XTianqiSegAlien、seg_alien.json；接战争线 XTianqiWarAlien.apply）。
## 一、数据：数字避开 4；稀有度类按【前缀】分。
## 二、段表与难度：几率、基础级、升级；寻常、九死、炼狱的修正；31～36 层守层者终焉不受难度影响。
## 三、种类：每段多教一种，深渊怪全出，没做好的种类（连击兵）不出。
## 四、判定：1～5 层不异化、小怪不异化、一场最多一只、守层者优先、几率掷不中不异化。
## 五、开战：守层者在 10 层变侵染、本线预设（使徒）和四骑士战不被覆盖；没选线、别的线、开关关掉、原版档一处都不动。
## 数字避开 4（Kyo 11-11）：用例里的层号、敌群号照实写。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


## 天启篇存档、5 个弱者；floor_no＝修行进度层（地图号 0 时按它算）
func _state(floor_no: int, line := "war", diff := "jianxian") -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, diff, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 0
	s.set_variable(20, floor_no + 1)
	XState.current = s
	if line != "":
		s.flags.tianqi["line"] = line
		if line == "war":
			XTianqiWarLine.progress(s)["stage"] = XTianqiWarLine.STAGE_DONE
	return s


func _const(v: float) -> Callable:
	return func(_r: String, _k: String) -> float: return v


func _enemies(troop: int) -> Array:
	var out := []
	for m in XDB.rec("Troops", troop).get("members", []):
		var e := XEnemy.new().setup(int(m.enemyId), 0, 100.0)
		e.hidden = bool(m.get("hidden", false))
		out.append(e)
	return out


func _run() -> void:
	XMessageBox.auto = true
	XTianqiSegAlien.reload()
	XTianqiWarLine.reload()
	_data()
	_rules()
	_kinds()
	_plan()
	_battle()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _data() -> void:
	_check("nice_numbers", XTianqiSegAlien.nice_number_violations().is_empty(), XTianqiSegAlien.nice_number_violations())
	var cases := {"【稀有】巨型鱼人": "rare", "【精英】鱼人士兵": "rare", "【首领】捕猎者": "very_rare", "【前所未见】苍白之影": "very_rare",
		"【亘古未有】牛马王": "very_rare", "【守层者】里德": "guardian", "【被封印者】梅林之影": "abyss", "【未知存在】暗悟空": "abyss",
		"【古神】曼丝": "abyss", "【罕见】哥布林士兵": "", "【十分罕见】蠢萌怪": "", "火焰哥布林": "", "【传承者】炎龙守护者": ""}
	var bad := []
	for n in cases:
		if XTianqiSegAlien.class_of(n) != cases[n]:
			bad.append([n, XTianqiSegAlien.class_of(n)])
	_check("class_of", bad.is_empty(), bad)
	# 敌人数据本身：守层者 36 只都算守层者
	var guards := 0
	for rec in XDB.table("Enemies"):
		if rec is Dictionary and str(rec.get("name", "")).begins_with("【守层者】"):
			guards += 1
	_check("guardian_count", guards == 36, guards)
	_check("segments_cover", range(1, 37).all(func(f): return not XTianqiSegAlien.segment(f).is_empty()) and XTianqiSegAlien.segment(37).is_empty())


func _r(cls: String, f: int, d := "jianxian") -> Array:
	var r := XTianqiSegAlien.rule(cls, f, d)
	return [] if r.is_empty() else [snappedf(float(r.rate), 0.01), str(r.tier), str(r.up), snappedf(float(r.up_rate), 0.01)]


func _rules() -> void:
	_check("seg1_none", _r("rare", 3).is_empty() and _r("guardian", 5).is_empty() and _r("abyss", 5).is_empty())
	_check("seg2_rare", _r("rare", 6) == [11.0, "qinran", "", 0.0], _r("rare", 6))
	_check("seg2_boss", _r("very_rare", 10) == [33.0, "qinran", "", 0.0], _r("very_rare", 10))
	_check("seg2_guard", _r("guardian", 10) == [100.0, "qinran", "", 0.0])
	_check("seg2_abyss", _r("abyss", 8) == [100.0, "huaxing", "", 0.0])
	_check("seg3", _r("very_rare", 12) == [50.0, "shigu", "", 0.0] and _r("guardian", 15)[1] == "shigu")
	_check("seg4_rare_up", _r("rare", 18) == [20.0, "qinran", "shigu", 10.0], _r("rare", 18))
	_check("seg5", _r("very_rare", 23) == [70.0, "shigu", "huaxing", 20.0] and _r("guardian", 25)[1] == "huaxing")
	_check("seg6", _r("rare", 28) == [30.0, "shigu", "huaxing", 10.0] and _r("very_rare", 30) == [80.0, "shigu", "huaxing", 33.0]
		and _r("guardian", 30)[1] == "huaxing", [_r("rare", 28), _r("very_rare", 30)])
	_check("seg7", _r("very_rare", 33) == [88.0, "huaxing", "", 0.0] and _r("guardian", 36)[1] == "zhongyan")
	# 寻常：几率减半、稀有最高侵染、守层者低一级（最低侵染）、终焉不变；守层者、深渊几率不变
	_check("xun_rare", _r("rare", 28, "xunchang") == [15.0, "qinran", "", 0.0], _r("rare", 28, "xunchang"))
	_check("xun_boss", _r("very_rare", 10, "xunchang") == [16.5, "qinran", "", 0.0], _r("very_rare", 10, "xunchang"))
	_check("xun_guard", _r("guardian", 12, "xunchang")[1] == "qinran" and _r("guardian", 8, "xunchang")[1] == "qinran"
		and _r("guardian", 28, "xunchang")[1] == "shigu" and _r("guardian", 33, "xunchang")[1] == "zhongyan" and _r("guardian", 8, "xunchang")[0] == 100.0)
	_check("xun_abyss", _r("abyss", 12, "xunchang") == [100.0, "huaxing", "", 0.0])
	# 九死 +10、炼狱 +20（封顶 100）
	_check("jiusi", _r("rare", 6, "jiusi")[0] == 21.0 and _r("very_rare", 33, "jiusi")[0] == 98.0 and _r("rare", 6, "jiusi")[1] == "qinran")
	_check("lianyu_rate", _r("rare", 6, "lianyu")[0] == 31.0 and _r("very_rare", 33, "lianyu")[0] == 100.0)
	# 炼狱：稀有的级上限高一级（最高化形）；首领、守层者不变
	_check("lianyu_rare_up", _r("rare", 6, "lianyu") == [31.0, "qinran", "shigu", 10.0], _r("rare", 6, "lianyu"))
	_check("lianyu_rare_up2", _r("rare", 18, "lianyu") == [40.0, "qinran", "huaxing", 10.0], _r("rare", 18, "lianyu"))
	_check("lianyu_rare_cap", _r("rare", 28, "lianyu") == [50.0, "shigu", "huaxing", 10.0], _r("rare", 28, "lianyu"))
	_check("lianyu_guard_same", _r("guardian", 12, "lianyu") == _r("guardian", 12))
	_check("zhengdao_like_lianyu", _r("rare", 18, "zhengdao") == _r("rare", 18, "lianyu"))


func _kinds() -> void:
	_check("war_module_kinds", not XTianqiWarAlien.kinds().has("combo") and XTianqiWarAlien.kinds().size() == 4, XTianqiWarAlien.kinds())
	_check("kinds_6", XTianqiSegAlien.kinds_for("war", 6, "rare") == ["berserk", "fervor"], XTianqiSegAlien.kinds_for("war", 6, "rare"))
	_check("kinds_11_no_combo", XTianqiSegAlien.kinds_for("war", 13, "rare") == ["berserk", "fervor"])
	_check("kinds_16", XTianqiSegAlien.kinds_for("war", 16, "guardian") == ["berserk", "fervor", "commander"])
	_check("kinds_21", XTianqiSegAlien.kinds_for("war", 21, "rare") == ["berserk", "fervor", "commander", "pyro"])
	_check("kinds_abyss_all", XTianqiSegAlien.kinds_for("war", 6, "abyss") == ["berserk", "fervor", "commander", "pyro"])
	_check("kinds_other_line_none", XTianqiSegAlien.kinds_for("famine", 21, "rare").is_empty())


func _plan() -> void:
	var s := _state(10)
	# 10 层守层者：一定异化、侵染、种类从战狂／战意里出
	var g := XTianqiSegAlien.plan(s, _enemies(69), _const(0.99))
	_check("guard10", g.size() == 1 and g[0].tier == "qinran" and g[0]["class"] == "guardian" and g[0].kind == "fervor", g)
	_check("guard10_kind_low", XTianqiSegAlien.plan(s, _enemies(69), _const(0.0))[0].kind == "berserk")
	# 小怪不异化
	_check("mobs_none", XTianqiSegAlien.plan(s, _enemies(30), _const(0.0)).is_empty())
	# 稀有：掷中才异化（10 层 11%）
	_check("rare_hit", XTianqiSegAlien.plan(s, _enemies(33), _const(0.1)).size() == 1)
	_check("rare_miss", XTianqiSegAlien.plan(s, _enemies(33), _const(0.11)).is_empty())
	var rare := XTianqiSegAlien.plan(s, _enemies(33), _const(0.0))
	_check("rare_is_first", rare.size() == 1 and str(rare[0].enemy.data().name).begins_with("【稀有】"), rare)
	# 一场最多一只，首领先掷：首领掷中就只有它；首领没中再轮到精英
	var mixed := _enemies(37)
	var p1 := XTianqiSegAlien.plan(s, mixed, _const(0.0))
	_check("one_unit_boss_first", p1.size() == 1 and p1[0].enemy == mixed[2], p1)
	var miss_boss := func(r: String, k: String) -> float: return 0.99 if (r == "tianqi_seg.rate" and k.begins_with("2:")) else 0.0
	var p2 := XTianqiSegAlien.plan(s, mixed, miss_boss)
	_check("boss_miss_then_elite", p2.size() == 1 and p2[0].enemy == mixed[0] and p2[0]["class"] == "rare", p2)
	# 升级：18 层稀有 10% 升蚀骨
	var s18 := _state(18)
	var up := func(r: String, _k: String) -> float: return 0.05 if r == "tianqi_seg.up" else 0.0
	_check("rare_up_shigu", XTianqiSegAlien.plan(s18, _enemies(33), up)[0].tier == "shigu")
	_check("rare_no_up", XTianqiSegAlien.plan(s18, _enemies(33), _const(0.1))[0].tier == "qinran")
	# 深渊怪：6 层起一定化形，种类全出
	var ab := XTianqiSegAlien.plan(_state(7), _enemies(145), _const(0.99))
	_check("abyss", ab.size() == 1 and ab[0].tier == "huaxing" and ab[0].kind == "pyro", ab)
	# 1～5 层不异化（守层者也不）
	_check("floor5_none", XTianqiSegAlien.plan(_state(5), _enemies(69), _const(0.0)).is_empty())
	# 没选线、别的线、开关关、原版档
	_check("no_line_none", XTianqiSegAlien.plan(_state(10, ""), _enemies(69), _const(0.0)).is_empty())
	_check("famine_none", XTianqiSegAlien.plan(_state(10, "famine"), _enemies(69), _const(0.0)).is_empty())
	XTianqiSegAlien.ENABLED = false
	_check("switch_off_none", XTianqiSegAlien.plan(s, _enemies(69), _const(0.0)).is_empty())
	XTianqiSegAlien.ENABLED = true
	XTianqiWarLine.ENABLED = false
	_check("war_off_none", XTianqiSegAlien.plan(s, _enemies(69), _const(0.0)).is_empty())
	XTianqiWarLine.ENABLED = true
	var plain := XState.new()
	plain.set_variable(20, 11)
	_check("plain_save_none", XTianqiSegAlien.plan(plain, _enemies(69), _const(0.0)).is_empty())
	# 楼层：有地图时按地图所在层；地图号 0 按修行进度层
	_check("floor_fallback", XTianqiSegAlien.floor_of(s) == 10)
	var sm := _state(30)
	sm.map_id = 17
	var f17 := XDungeon.map_floor(17)
	_check("floor_by_map", f17 <= 0 or XTianqiSegAlien.floor_of(sm) == f17, [f17, XTianqiSegAlien.floor_of(sm)])


func _battle() -> void:
	# 开战：10 层守层者变侵染，名字带前缀，生命按级加
	var s := _state(10)
	var lg := XBattleLogic.new()
	lg.setup(69, s)
	var g: XEnemy = lg.enemies[0]
	var u := XTianqiWarAlien.unit(lg, g)
	_check("battle_guard_alien", XTianqiWarAlien.is_alien(lg, g) and str(XTianqiWarAlien.fight(lg).preset) == "segment" and str(u.tier) == "qinran", u)
	_check("battle_guard_name", g.display_name().begins_with("侵染·") and g.display_name().contains("灵狼祭祀"), g.display_name())
	_check("battle_guard_hp", g.mhp > g.param_base(0) * 1.2 and is_equal_approx(g.hp, g.mhp), [g.mhp, g.param_base(0)])
	lg.end_battle(0)
	_check("battle_end_clears", not XTianqiWarAlien.active(lg) and not g.has_meta("tianqi_prefix"))
	# 本线预设（10 层使徒）不被按段覆盖
	XTianqiWarAlien.prepare("apostle10", s)
	var lp := XBattleLogic.new()
	lp.setup(69, s)
	_check("preset_kept", str(XTianqiWarAlien.fight(lp).get("preset", "")) == "apostle10" and str(XTianqiWarAlien.unit(lp, lp.enemies[0]).kind) == "fervor")
	lp.end_battle(0)
	# 四骑士战不动
	if XTianqiHorsemen.prepare("war", s, "body"):
		var lk := XBattleLogic.new()
		lk.setup(int(XTianqiWarLine.data().shell_troop), s)
		_check("horsemen_untouched", XTianqiHorsemen.active(lk) and not XTianqiWarAlien.active(lk))
		lk.end_battle(0)
	# 小怪一场：不异化
	var lm := XBattleLogic.new()
	lm.setup(30, s)
	_check("battle_mobs_plain", not XTianqiWarAlien.active(lm))
	lm.end_battle(0)
	# 5 层守层者：不异化
	var s5 := _state(5)
	var l5 := XBattleLogic.new()
	l5.setup(69, s5)
	_check("battle_floor5_plain", not XTianqiWarAlien.active(l5) and not l5.enemies[0].display_name().contains("·"))
	l5.end_battle(0)
	# 原版档：不异化
	var plain := XState.new()
	plain.set_variable(20, 11)
	XState.current = plain
	var lo := XBattleLogic.new()
	lo.setup(69, plain)
	_check("battle_plain_save", not XTianqiWarAlien.active(lo))
	lo.end_battle(0)
