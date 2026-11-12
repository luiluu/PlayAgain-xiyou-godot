extends Node
## 漩涡五阶段怪物异化专项（XRiftAlien、rift_alien.json；设计稿 重制版_漩涡五阶段怪物异化设计稿_v0.1）。
## 一、数据：数字避开 4；稀有度按【前缀】；阶段表、守层者按楼层分段、难度修正。
## 二、判定：一、二阶不异化；三阶起按表；小怪不异化；一场最多一只、守层者优先；天启篇存档、开关关掉一概不动。
## 三、随机流：二阶、三阶（选中与没选中）开战时规则随机流的取数和一阶逐条相同；没选中的那场敌人数值也逐值相同。
## 四、开战：异化怪名字带「级·」、生命按级加、去掉神话；二阶只有画面标记（守层者一明一暗），名字和数值不变。
## 五、种类：战狂、荒年者、毒腺、丧钟（含化形效果）。
## 六、掉落：倒下按级掉原版异化装备，名字「级·词条·原名」，分解按级给能量；原版异化隐藏时不掉；点亮天启篇异化图鉴。
## 数字避开 4：用例里的层号、敌群号照实写。

const SEED := "5a17c0de00112233"
const DIR := "user://test_rift_alien"

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


## 西游档；floor_no＝修行进度层（地图号 0 时按它算）
func _plain(floor_no: int, with_actors := false) -> XState:
	var s := XState.new()
	if with_actors:
		for id in _ids(XTier.WEAK).slice(0, 3):
			s.add_actor(int(id))
	s.map_id = 0
	s.set_variable(20, floor_no + 1)
	XState.current = s
	return s


func _tianqi(floor_no: int) -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	s.map_id = 0
	s.set_variable(20, floor_no + 1)
	XState.current = s
	return s


func _const(v: float) -> Callable:
	return func(_r: String, _k: String) -> float: return v


func _enemies(troop: int) -> Array:
	var out := []
	for m in XDB.rec("Troops", troop).get("members", []):
		var e := XEnemy.new().setup(int(m.enemyId), 3, 100.0)
		e.hidden = bool(m.get("hidden", false))
		out.append(e)
	return out


func _battle(troop: int, s: XState, st: int) -> XBattleLogic:
	XRiftAlien.STAGE_OVERRIDE = st
	var lg := XBattleLogic.new()
	lg.setup(troop, s, XBattleRandom.create(SEED, 1))
	return lg


func _run() -> void:
	XMessageBox.auto = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	XConfig.path_override = DIR.path_join("options.json")
	if FileAccess.file_exists(XConfig.path_override):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(XConfig.path_override))
	XRiftAlien.reload()
	_data()
	_rules()
	_plan()
	_random()
	_battle_setup()
	_kinds()
	_drops()
	XRiftAlien.STAGE_OVERRIDE = 0
	XRiftAlien.force_drop = -1.0
	XConfig.path_override = ""
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _data() -> void:
	_check("nice_numbers", XRiftAlien.nice_number_violations().is_empty(), XRiftAlien.nice_number_violations())
	var cases := {"【稀有】巨型鱼人": "rare", "【精英】鱼人士兵": "rare", "【首领】捕猎者": "very_rare", "【守层者】里德": "guardian",
		"【被封印者】梅林之影": "abyss", "【古神】曼丝": "abyss", "【罕见】哥布林士兵": "", "火焰哥布林": ""}
	var bad := []
	for n in cases:
		if XRiftAlien.class_of(n) != cases[n]:
			bad.append([n, XRiftAlien.class_of(n)])
	_check("class_of", bad.is_empty(), bad)
	_check("kinds_pool", XRiftAlien.kinds() == ["berserk", "lean", "gland", "knell"], XRiftAlien.kinds())
	_check("no_zhongyan", not XRiftAlien.data().tiers.has("zhongyan"))
	_check("diff_map", XRiftAlien.diff_key(1) == "low" and XRiftAlien.diff_key(3) == "mid" and XRiftAlien.diff_key(4) == "mid"
		and XRiftAlien.diff_key(6) == "high" and XRiftAlien.diff_key(9) == "top")


func _r(cls: String, st: int, f: int, d := 3) -> Array:
	var r := XRiftAlien.rule(cls, st, f, d)
	return [] if r.is_empty() else [snappedf(float(r.rate), 0.01), str(r.tier), str(r.up), snappedf(float(r.up_rate), 0.01)]


func _rules() -> void:
	_check("st2_none", _r("rare", 2, 10).is_empty() and _r("guardian", 2, 10).is_empty())
	_check("st3_rare", _r("rare", 3, 10) == [11.0, "qinran", "", 0.0], _r("rare", 3, 10))
	_check("st3_boss", _r("very_rare", 3, 10) == [22.0, "qinran", "shigu", 10.0], _r("very_rare", 3, 10))
	_check("st3_guard", _r("guardian", 3, 20) == [33.0, "qinran", "", 0.0] and _r("guardian", 3, 21)[1] == "shigu")
	_check("st3_abyss_none", _r("abyss", 3, 10).is_empty())
	_check("st4", _r("rare", 4, 10) == [15.0, "qinran", "shigu", 10.0] and _r("very_rare", 4, 10) == [33.0, "shigu", "", 0.0]
		and _r("abyss", 4, 10) == [50.0, "huaxing", "", 0.0], [_r("rare", 4, 10), _r("very_rare", 4, 10)])
	_check("st4_guard_bands", _r("guardian", 4, 10) == [100.0, "qinran", "", 0.0] and _r("guardian", 4, 11)[1] == "shigu" and _r("guardian", 4, 30)[1] == "huaxing")
	_check("st5", _r("rare", 5, 10) == [20.0, "qinran", "shigu", 10.0] and _r("very_rare", 5, 10) == [50.0, "shigu", "huaxing", 10.0]
		and _r("abyss", 5, 10) == [100.0, "huaxing", "", 0.0])
	# 宝宝、简单：稀有几率减半、最高侵染、守层者低一级（最低侵染）
	_check("low_rare", _r("rare", 5, 10, 2) == [10.0, "qinran", "", 0.0], _r("rare", 5, 10, 2))
	_check("low_boss", _r("very_rare", 3, 10, 1) == [11.0, "qinran", "shigu", 10.0], _r("very_rare", 3, 10, 1))
	_check("low_guard", _r("guardian", 5, 30, 2)[1] == "shigu" and _r("guardian", 5, 10, 2)[1] == "qinran" and _r("guardian", 5, 30, 2)[0] == 100.0)
	# 地狱 +10、灭世起 +20，稀有级上限高一级
	_check("high", _r("rare", 3, 10, 5)[0] == 21.0 and _r("very_rare", 5, 10, 6)[0] == 60.0)
	_check("top", _r("rare", 3, 10, 7) == [31.0, "qinran", "shigu", 10.0] and _r("rare", 5, 10, 9) == [40.0, "qinran", "huaxing", 10.0], [_r("rare", 3, 10, 7), _r("rare", 5, 10, 9)])
	_check("top_guard_same", _r("guardian", 5, 15, 8) == _r("guardian", 5, 15))


func _plan() -> void:
	var s := _plain(10)
	XRiftAlien.STAGE_OVERRIDE = 2
	_check("st2_plan_none", XRiftAlien.plan(s, _enemies(69), _const(0.0)).is_empty())
	XRiftAlien.STAGE_OVERRIDE = 3
	var g := XRiftAlien.plan(s, _enemies(69), _const(0.0))
	_check("st3_guard_hit", g.size() == 1 and g[0].tier == "qinran" and g[0]["class"] == "guardian" and g[0].kind == "berserk", g)
	_check("st3_guard_miss", XRiftAlien.plan(s, _enemies(69), _const(0.33)).is_empty())
	_check("kind_last", XRiftAlien.plan(s, _enemies(69), _const(0.32))[0].kind == "lean")
	var hi := func(r: String, _k: String) -> float: return 0.99 if r == "rift_alien.kind" else 0.0
	_check("kind_knell", XRiftAlien.plan(s, _enemies(69), hi)[0].kind == "knell")
	_check("mobs_none", XRiftAlien.plan(s, _enemies(30), _const(0.0)).is_empty())
	var mixed := _enemies(37)
	var p1 := XRiftAlien.plan(s, mixed, _const(0.0))
	_check("one_unit_boss_first", p1.size() == 1 and p1[0].enemy == mixed[2], p1)
	XRiftAlien.STAGE_OVERRIDE = 4
	_check("st4_guard_always", XRiftAlien.plan(s, _enemies(69), _const(0.99)).size() == 1)
	_check("st4_abyss", XRiftAlien.plan(s, _enemies(145), _const(0.49)).size() == 1 and XRiftAlien.plan(s, _enemies(145), _const(0.5)).is_empty())
	XRiftAlien.STAGE_OVERRIDE = 3
	_check("st3_abyss_none", XRiftAlien.plan(s, _enemies(145), _const(0.0)).is_empty())
	# 天启篇存档、开关关掉：不动
	_check("tianqi_none", XRiftAlien.plan(_tianqi(10), _enemies(69), _const(0.0)).is_empty())
	XRiftAlien.ENABLED = false
	_check("switch_off_none", XRiftAlien.plan(_plain(10), _enemies(69), _const(0.0)).is_empty())
	XRiftAlien.ENABLED = true
	# 发行构建：RELEASE_OPEN 关着不建
	ReleaseEntry.simulate_release = true
	_check("release_none", XRiftAlien.plan(_plain(10), _enemies(69), _const(0.0)).is_empty() and not XRiftAlien.on(_plain(10)))
	XRiftAlien.RELEASE_OPEN = true
	_check("release_open", XRiftAlien.plan(_plain(10), _enemies(69), _const(0.0)).size() == 1)
	XRiftAlien.RELEASE_OPEN = false
	ReleaseEntry.simulate_release = false
	_check("floor_fallback", XRiftAlien.floor_of(_plain(10)) == 10)


func _sig(lg: XBattleLogic) -> Array:
	var j: Array = lg.random.rule.journal.map(func(x): return [x.reason, x.event, x.value])
	var es: Array = lg.enemies.map(func(e): return [e.enemy_id, e.elite, e.mhp, e.hp, e.atk, e.def, e.display_name()])
	return [j, es]


func _random() -> void:
	var s := _plain(10, true)
	XRiftAlien.ENABLED = false
	var off := _battle(37, s, 1)
	var base := _sig(off)
	off.end_battle(0)
	XRiftAlien.ENABLED = true
	var l1 := _battle(37, s, 1)
	_check("st1_same", _sig(l1) == base and not XRiftAlien.active(l1))
	l1.end_battle(0)
	var l2 := _battle(37, s, 2)
	_check("st2_same", _sig(l2) == base and XRiftAlien.active(l2) and XRiftAlien.fight(l2).units.is_empty(), [_sig(l2)[1], base[1]])
	l2.end_battle(0)
	# 三阶没选中（把几率调成 0）：逐值相同
	var st3: Dictionary = XRiftAlien.data().stages["3"]
	var keep: Dictionary = st3.duplicate(true)
	for k in ["rare", "very_rare", "guardian"]:
		st3[k].rate = 0
	var l3 := _battle(37, s, 3)
	_check("st3_miss_same", _sig(l3) == base and XRiftAlien.fight(l3).units.is_empty())
	l3.end_battle(0)
	# 三阶选中（几率 100）：规则随机流取数照样逐条相同（异化只用自己的流）
	for k in ["rare", "very_rare", "guardian"]:
		st3[k].rate = 100
	var l4 := _battle(37, s, 3)
	_check("st3_hit_rule_stream_same", _sig(l4)[0] == base[0] and XRiftAlien.fight(l4).units.size() == 1, _sig(l4)[1])
	l4.end_battle(0)
	XRiftAlien.data().stages["3"] = keep
	# 天启篇存档：二阶也不建画面标记
	var lt := _battle(69, _tianqi(10), 2)
	_check("tianqi_no_meta", not XRiftAlien.active(lt) and not lt.enemies[0].has_meta(XRiftAlien.LOOK))
	lt.end_battle(0)


func _battle_setup() -> void:
	var s := _plain(10, true)
	# 二阶：守层者只有画面标记，名字与数值照旧
	var l2 := _battle(69, s, 2)
	var g: XEnemy = l2.enemies[0]
	var look: Dictionary = g.get_meta(XRiftAlien.LOOK, {})
	_check("st2_guard_pulse", bool(look.get("pulse", false)) and str(look.get("tier", "")) == "" and not g.display_name().contains("·"), look)
	_check("st2_tint", XRiftAlien.tint(g, 3.0).a > 0.0 and is_zero_approx(XRiftAlien.tint(g, 0.0).a), [XRiftAlien.tint(g, 3.0), XRiftAlien.tint(g, 0.0)])
	var plain_hp := g.mhp
	l2.end_battle(0)
	_check("end_clears_look", not g.has_meta(XRiftAlien.LOOK))
	# 四阶：守层者一定异化（10 层侵染），名字带前缀、生命按级、去神话
	XEnemy.force_roll = 0.0
	var l4 := _battle(69, s, 4)
	XEnemy.force_roll = -1.0
	var e: XEnemy = l4.enemies[0]
	var u := XRiftAlien.unit(l4, e)
	# v0.01 补丁线：底包 XEnemy.display_name 不认 tianqi_prefix（天启篇才有），名字前缀不显示；三阶起发行版走不到，这里只核级和前缀标记
	_check("st4_guard_alien", str(u.get("tier", "")) == "qinran" and str(e.get_meta("tianqi_prefix", "")) == "侵染·", [u, e.get_meta("tianqi_prefix", "")])
	_check("st4_no_myth", not e.elite and not e.display_name().contains("神话"), e.display_name())
	var ratio := e.mhp / plain_hp
	var want := 1.25 * (float(XRiftAlien.kind_info("berserk").mult[0]) if str(u.kind) == "berserk" else 1.0)
	_check("st4_hp", absf(ratio - want) < 0.02 and is_equal_approx(e.hp, e.mhp), [ratio, want])
	_check("st4_tint_glow", XRiftAlien.tint(e, 0.0).a > 0.0)
	_check("st4_logs", l4.turn_start_logs.any(func(x): return str(x.get("text", "")).contains("漩涡的颜色")))
	l4.end_battle(0)
	_check("st4_end", not XRiftAlien.active(l4) and not e.has_meta("tianqi_prefix"))


## 二阶开一场（不出异化、有本场记录），再手动把第一只敌人变成某种异化
func _forced(kind: String, tier: String) -> XBattleLogic:
	var s := _plain(10, true)
	var lg := _battle(69, s, 2)
	XRiftAlien.apply(lg, [{"enemy": lg.enemies[0], "tier": tier, "kind": kind, "class": "guardian"}])
	return lg


func _kinds() -> void:
	# 战狂：八项 ×倍率；化形受伤叠攻
	var s := _plain(10, true)
	var l0 := _battle(69, s, 2)
	var atk0: float = l0.enemies[0].atk
	var hp0: float = l0.enemies[0].mhp
	l0.end_battle(0)
	var lb := _forced("berserk", "huaxing")
	var e: XEnemy = lb.enemies[0]
	_check("berserk_atk", absf(e.atk / atk0 - 3.0) < 0.02, [e.atk, atk0])
	_check("berserk_hp", absf(e.mhp / hp0 - 6.0) < 0.02, [e.mhp, hp0])
	var a0 = lb.actors[0]
	var atk1 := e.atk
	XRiftAlien.hp_damage(lb, a0, e, 10.0)
	e.param_refresh()  # krz 缓存：下一次 refresh 才读到（同原版 addParam）
	_check("berserk_rage", e.atk > atk1, [e.atk, atk1])
	lb.end_battle(0)
	# 荒年者：回复打折；化形再生失效
	var lf := _forced("lean", "shigu")
	var a = lf.actors[0]
	_check("lean_gain", is_equal_approx(XRiftAlien.gain(a, "hp", 100.0), 70.0) and is_equal_approx(XRiftAlien.gain(a, "tp", 100.0), 100.0))
	_check("lean_regen", XRiftAlien.regen(lf, a, 100.0, 10.0) == [70.0, 7.0], XRiftAlien.regen(lf, a, 100.0, 10.0))
	_check("lean_enemy_untouched", is_equal_approx(XRiftAlien.gain(lf.enemies[0], "hp", 100.0), 100.0))
	lf.end_battle(0)
	_check("lean_after_end", is_equal_approx(XRiftAlien.gain(a, "hp", 100.0), 100.0))
	var lh := _forced("lean", "huaxing")
	_check("lean_huaxing_regen_off", XRiftAlien.regen(lh, lh.actors[0], 100.0, 10.0) == [0.0, 0.0])
	lh.end_battle(0)
	# 毒腺：命中附加中毒（侵染只一层、刷新），回合末扣血、3 回合消失；化形叠 3 层
	var lg := _forced("gland", "qinran")
	var t = lg.actors[0]
	XRiftAlien.hp_damage(lg, lg.enemies[0], t, 10.0)
	XRiftAlien.hp_damage(lg, lg.enemies[0], t, 10.0)
	_check("gland_one_stack", XRiftAlien.poison_of(lg, t) == [3], XRiftAlien.poison_of(lg, t))
	t.hp = t.mhp
	var before: float = t.hp
	XRiftAlien.end_turn(lg)
	_check("gland_tick", is_equal_approx(before - t.hp, floorf(t.mhp * 0.03)), [before - t.hp, t.mhp])
	XRiftAlien.end_turn(lg)
	XRiftAlien.end_turn(lg)
	_check("gland_expire", XRiftAlien.poison_of(lg, t).is_empty())
	lg.end_battle(0)
	var lg3 := _forced("gland", "huaxing")
	var t3 = lg3.actors[0]
	for i in 3:
		XRiftAlien.hp_damage(lg3, lg3.enemies[0], t3, 10.0)
	XRiftAlien.hp_damage(lg3, lg3.enemies[0], t3, 10.0)
	_check("gland_huaxing_stack", XRiftAlien.poison_of(lg3, t3).size() == 3)
	lg3.end_battle(0)
	# 丧钟：侵染倒数 5，归零时生命比例最低的倒下、重新倒数
	var lk := _forced("knell", "qinran")
	var low = lk.actors[1]
	for x in lk.actors:
		x.hp = x.mhp
	low.hp = floorf(low.mhp * 0.5)
	for i in 4:
		XRiftAlien.end_turn(lk)
	var alive_mid: bool = low.is_alive()
	XRiftAlien.end_turn(lk)
	var resists: bool = low.traits_set(XBattler.TRAIT_STATE_RESIST).has(1)
	_check("knell_qinran", alive_mid and (resists or low.is_dead()) and int(XRiftAlien.unit(lk, lk.enemies[0]).count) == 5, [alive_mid, low.is_dead(), resists])
	lk.end_battle(0)
	# 化形：倒数 2，归零时全体再损失 20%
	var lk2 := _forced("knell", "huaxing")
	for x in lk2.actors:
		x.hp = x.mhp
	lk2.actors[0].hp = 1.0
	XRiftAlien.end_turn(lk2)
	XRiftAlien.end_turn(lk2)
	var other = lk2.actors[1]
	_check("knell_huaxing", lk2.actors[0].is_dead() and is_equal_approx(other.hp, other.mhp - floorf(other.mhp * 0.2)), [lk2.actors[0].hp, other.hp, other.mhp])
	lk2.end_battle(0)


func _drops() -> void:
	var lg := _forced("berserk", "huaxing")
	var s: XState = lg.state
	var e: XEnemy = lg.enemies[0]
	e.hp = 0.0
	e.add_new_state(1)
	XRiftAlien.force_drop = 0.19
	var got := XRiftAlien.grant(lg)
	_check("drop_got", got.size() == 1 and str(got[0]).begins_with("化形·"), got)
	var item = s.gear.filter(func(i): return XRiftAlien.gear_tier(i) == "huaxing")
	_check("drop_in_bag", item.size() == 1 and lg.victory_texts.has("获得 " + str(got[0])) if got.size() == 1 else false)
	if item.size() == 1:
		var i: Dictionary = item[0]
		XAlienation.relabel(i)
		_check("relabel_stable", str(i.name) == str(got[0]), [i.name, got[0]])
		var before := s.item_count(XAlienation.energy_id())
		var r := XAlienation.dismantle(s, i)
		_check("dismantle_energy", r.get("ok", 0) == 3 and s.item_count(XAlienation.energy_id()) - before == 3, r)
	lg.end_battle(0)
	# 掷不中不掉
	var lm := _forced("lean", "qinran")
	lm.enemies[0].hp = 0.0
	lm.enemies[0].add_new_state(1)
	XRiftAlien.force_drop = 0.03
	_check("drop_miss", XRiftAlien.grant(lm).is_empty())
	lm.end_battle(0)
	# 原版异化隐藏时不掉（图鉴照点）
	XAlienBattle.HIDDEN_V058 = true
	var lhid := _forced("gland", "huaxing")
	lhid.enemies[0].hp = 0.0
	lhid.enemies[0].add_new_state(1)
	XRiftAlien.force_drop = 0.0
	_check("drop_hidden_none", XRiftAlien.grant(lhid).is_empty())
	lhid.end_battle(0)
	XAlienBattle.HIDDEN_V058 = false
	# 活着的不掉
	var la := _forced("knell", "huaxing")
	XRiftAlien.force_drop = 0.0
	_check("drop_alive_none", XRiftAlien.grant(la).is_empty())
	la.end_battle(0)
