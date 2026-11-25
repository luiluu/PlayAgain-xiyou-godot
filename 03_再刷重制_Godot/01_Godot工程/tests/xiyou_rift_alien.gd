extends Node
## 漩涡五阶段怪物异化专项（XRiftAlien、rift_alien.json；设计稿 重制版_漩涡五阶段怪物异化设计稿_v0.1）。
## 一、数据：数字避开 4；稀有度按【前缀】；阶段表、守层者按楼层分段、难度修正。
## 二、判定：一、二阶不异化；三阶起按表；小怪不异化；一场最多一只、守层者优先；天启篇存档、开关关掉一概不动。
## 三、随机流：二阶、三阶（选中与没选中）开战时规则随机流的取数和一阶逐条相同；没选中的那场敌人数值也逐值相同。
## 四、开战：异化怪名字带「级·」、生命按级加、去掉神话；二阶只有画面标记（守层者一明一暗），名字和数值不变。
## 五、种类：战狂、荒年者、毒腺、丧钟（含化形效果）。
## 六、掉落：倒下按级掉原版异化装备，名字「级·词条·原名」，分解按级给能量；原版异化隐藏时不掉；点亮天启篇异化图鉴。
## 数字避开 4：用例里的层号、敌群号照实写。
## 一～六按旧表（ALIGN_LOBBY＝false，回退后的行为）核；七、阶段对齐大厅稿（ALIGN_LOBBY 默认开，O-468，Kyo 11-15 D8）：
##   二阶就出侵染、三阶蚀骨、四阶化形（新表＝旧表三～五阶整体前移一档），五阶一律化形、几率同旧五阶；二阶选中时规则随机流照样逐条相同。

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
	XRiftAlien.reload_table()
	# 默认开，测试与玩家同一条路（不按显示后端切）
	_check("align_default_on", XRiftAlien.ALIGN_LOBBY and XRiftAlien.aligned() and XRiftAlien.first_alien_stage() == 2)
	_check("stage3_alien_default_on", XRiftAlien.STAGE3_ALIEN)
	_check("release_open_default_on", XRiftAlien.RELEASE_OPEN)
	_stage1_player()
	XConfig.whisper_mark("rift1")
	XConfig.whisper_mark("rift2")
	_default_path()
	_stage3_default()
	XRiftAlien.ALIGN_LOBBY = false
	_data()
	_rules()
	_plan()
	_random()
	_battle_setup()
	_kinds()
	_drops()
	XRiftAlien.ALIGN_LOBBY = true
	_aligned()
	XRiftAlien.STAGE_OVERRIDE = 0
	_stage3_cap()
	_release_path()
	_stand_in_guardians()
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
	var cases := {"【稀有】巨型鱼人": "rare", "【精英】鱼人士兵": "rare", "【首领】捕猎者": "very_rare", "【守层者】里德": "guardian",
		"【被封印者】梅林之影": "abyss", "【古神】曼丝": "abyss", "【罕见】哥布林士兵": "", "火焰哥布林": ""}
	var bad := []
	for n in cases:
		if XRiftAlien.class_of(n) != cases[n]:
			bad.append([n, XRiftAlien.class_of(n)])
	_check("class_of", bad.is_empty(), bad)
	_check("kinds_pool", XRiftAlien.kinds() == ["berserk", "lean", "gland", "knell"], XRiftAlien.kinds())
	# 种类都借自天启篇对应线、种类键与那条线一致（图鉴点亮用）
	var mods := {"war": XTianqiWarAlien, "famine": XTianqiFamineAlien, "plague": XTianqiPlagueAlien, "death": XTianqiDeathAlien}
	_check("kinds_borrowed", XRiftAlien.kinds().all(func(k): return mods[str(XRiftAlien.kind_info(k).from)].kinds().has(k)))
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
	# 发行构建：RELEASE_OPEN 关着不建（回退路）；开着（T455 默认）照建
	ReleaseEntry.simulate_release = true
	XRiftAlien.RELEASE_OPEN = false
	_check("release_none", XRiftAlien.plan(_plain(10), _enemies(69), _const(0.0)).is_empty() and not XRiftAlien.on(_plain(10)))
	XRiftAlien.RELEASE_OPEN = true
	_check("release_open", XRiftAlien.plan(_plain(10), _enemies(69), _const(0.0)).size() == 1)
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
	_check("st4_guard_alien", str(u.get("tier", "")) == "qinran" and e.display_name().begins_with("侵染·"), [u, e.display_name()])
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
	_check("codex_lit", XTianqiAlienCodex.seen("war", "berserk", "huaxing"))
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
	_check("drop_hidden_none", XRiftAlien.grant(lhid).is_empty() and XTianqiAlienCodex.seen("plague", "gland", "huaxing"))
	lhid.end_battle(0)
	XAlienBattle.HIDDEN_V058 = false
	# 活着的不掉
	var la := _forced("knell", "huaxing")
	XRiftAlien.force_drop = 0.0
	_check("drop_alive_none", XRiftAlien.grant(la).is_empty())
	la.end_battle(0)


## 七、阶段对齐大厅稿（ALIGN_LOBBY 开）
func _aligned() -> void:
	XRiftAlien.ALIGN_LOBBY = true
	# 新表二～四阶＝旧表三～五阶：各类、各层、各难度逐项相同
	var diffs := []
	for st in [2, 3, 4]:
		for cls in ["rare", "very_rare", "guardian", "abyss"]:
			for f in [1, 10, 11, 20, 21, 30]:
				for d in [1, 3, 5, 7, 9]:
					XRiftAlien.ALIGN_LOBBY = true
					var now := _r(cls, st, f, d)
					XRiftAlien.ALIGN_LOBBY = false
					var old := _r(cls, st + 1, f, d)
					if st == 3 and cls == "guardian" and XRiftAlien.diff_key(d) == "low":
						continue  # 宝宝、简单守层者低一级：封顶后 21～30 层由蚀骨降成侵染，下面 t455_st3_low_guard 单核
					if st == 3 and not old.is_empty():  # T455：三阶封顶蚀骨，旧表四阶的化形压成蚀骨，几率不动
						for k in [1, 2]:
							if old[k] == "huaxing":
								old[k] = "shigu"
						if old[2] == old[1]:
							old[2] = ""
							old[3] = 0.0
					if now != old:
						diffs.append([st, cls, f, d, now, old])
	XRiftAlien.ALIGN_LOBBY = true
	_check("al_shift_one_stage", diffs.is_empty(), diffs.slice(0, 5))
	_check("al_st1_none", _r("rare", 1, 10).is_empty() and _r("guardian", 1, 30).is_empty())
	_check("al_st2_rare", _r("rare", 2, 10) == [11.0, "qinran", "", 0.0], _r("rare", 2, 10))
	_check("al_st3_shigu", _r("very_rare", 3, 10) == [33.0, "shigu", "", 0.0], _r("very_rare", 3, 10))
	_check("al_st3_cap_shigu", _r("guardian", 3, 30)[1] == "shigu" and _r("abyss", 3, 10) == [50.0, "shigu", "", 0.0], [_r("guardian", 3, 30), _r("abyss", 3, 10)])
	_check("al_st4_huaxing", _r("guardian", 4, 30)[1] == "huaxing" and _r("abyss", 4, 10) == [100.0, "huaxing", "", 0.0])
	# 五阶：怪物端没有终焉，先按「化形且几率最高」（几率同旧五阶，一律化形、不升级）
	var st5 := []
	for cls in ["rare", "very_rare", "guardian", "abyss"]:
		for f in [1, 15, 30]:
			XRiftAlien.ALIGN_LOBBY = false
			var old_rate: float = _r(cls, 5, f)[0]
			XRiftAlien.ALIGN_LOBBY = true
			var r := _r(cls, 5, f)
			if r != [old_rate, "huaxing", "", 0.0]:
				st5.append([cls, f, r, old_rate])
	_check("al_st5_huaxing_max", st5.is_empty(), st5)
	_check("al_st5_rates_ge_st4", ["rare", "very_rare", "guardian", "abyss"].all(func(c): return _r(c, 5, 10)[0] >= _r(c, 4, 10)[0]))
	# 难度修正照旧作用在新表上：宝宝稀有最高侵染、守层者低一级；炼狱 +20
	_check("al_st5_low", _r("rare", 5, 10, 1) == [10.0, "qinran", "", 0.0] and _r("guardian", 5, 10, 2)[1] == "shigu", [_r("rare", 5, 10, 1), _r("guardian", 5, 10, 2)])
	_check("al_st5_top", _r("rare", 5, 10, 9) == [40.0, "huaxing", "", 0.0], _r("rare", 5, 10, 9))
	_check("al_no_zhongyan", not XRiftAlien.data().stages_aligned.values().any(func(row): return JSON.stringify(row).contains("zhongyan")))
	# 判定：二阶就出侵染（守层者 33%），一阶不出
	var s := _plain(10)
	XRiftAlien.STAGE_OVERRIDE = 1
	_check("al_st1_plan_none", XRiftAlien.plan(s, _enemies(69), _const(0.0)).is_empty())
	XRiftAlien.STAGE_OVERRIDE = 2
	var g := XRiftAlien.plan(s, _enemies(69), _const(0.0))
	_check("al_st2_guard_hit", g.size() == 1 and g[0].tier == "qinran" and g[0]["class"] == "guardian", g)
	_check("al_st2_guard_miss", XRiftAlien.plan(s, _enemies(69), _const(0.33)).is_empty())
	_check("al_st2_abyss_none", XRiftAlien.plan(s, _enemies(145), _const(0.0)).is_empty())
	XRiftAlien.STAGE_OVERRIDE = 3
	_check("al_st3_guard_always", XRiftAlien.plan(s, _enemies(69), _const(0.99)).size() == 1)
	XRiftAlien.STAGE_OVERRIDE = 5
	var g5 := XRiftAlien.plan(s, _enemies(69), _const(0.99))
	_check("al_st5_guard_huaxing", g5.size() == 1 and g5[0].tier == "huaxing", g5)
	_check("al_tianqi_none", XRiftAlien.plan(_tianqi(10), _enemies(69), _const(0.0)).is_empty())
	# 回退：关掉开关二阶不出
	XRiftAlien.ALIGN_LOBBY = false
	XRiftAlien.STAGE_OVERRIDE = 2
	_check("al_off_st2_none", XRiftAlien.plan(_plain(10), _enemies(69), _const(0.0)).is_empty())
	XRiftAlien.ALIGN_LOBBY = true
	# 随机流：二阶开战（几率调成 100 必选中）规则随机流取数与一阶逐条相同；几率 0 时敌人数值也逐值相同
	var sb := _plain(10, true)
	var l1 := _battle(37, sb, 1)
	var base := _sig(l1)
	l1.end_battle(0)
	var st2: Dictionary = XRiftAlien.data().stages_aligned["2"]
	var keep: Dictionary = st2.duplicate(true)
	for k in ["rare", "very_rare", "guardian"]:
		st2[k].rate = 0
	var lm := _battle(37, sb, 2)
	_check("al_st2_miss_same", _sig(lm) == base and XRiftAlien.fight(lm).units.is_empty())
	lm.end_battle(0)
	for k in ["rare", "very_rare", "guardian"]:
		st2[k].rate = 100
	var lh := _battle(37, sb, 2)
	_check("al_st2_hit_rule_stream_same", _sig(lh)[0] == base[0] and XRiftAlien.fight(lh).units.size() == 1, _sig(lh)[1])
	var e = XRiftAlien.fight(lh).units.keys()[0] if XRiftAlien.fight(lh).units.size() == 1 else null
	var u2 := XRiftAlien.unit(lh, e) if e != null else {}
	_check("al_st2_named", e != null and ["qinran", "shigu"].has(str(u2.get("tier", ""))) and e.display_name().begins_with(str(XRiftAlien.tier_info(str(u2.tier)).name) + "·"), [u2, e.display_name() if e != null else null])
	lh.end_battle(0)
	XRiftAlien.data().stages_aligned["2"] = keep


## 默认配置（ALIGN_LOBBY 开、不设 STAGE_OVERRIDE、阶段读真的 XRift.stage()）下的整场：玩家路径。
## 西游档、守层者敌群 69（10 层，二阶 33% 侵染），换几个种子开战：有的出异化怪、有的不出；出了的那场打几回合到结束不出错，
## 规则随机流取数与关掉异化的同种子一场逐条相同。
func _default_path() -> void:
	XRiftAlien.STAGE_OVERRIDE = 0
	_check("dp_stage_is_2", XRift.stage() == 2 and XRiftAlien.stage() == 2, XRift.stage())
	var s := _plain(10, true)
	var hit_seed := ""
	var misses := 0
	for i in 24:
		var sd := "%016x" % (0x5a17c0de00000000 + i)
		var lg := XBattleLogic.new()
		lg.setup(69, s, XBattleRandom.create(sd, 1))
		var n: int = XRiftAlien.fight(lg).get("units", {}).size()
		lg.end_battle(0)
		if n == 1 and hit_seed == "":
			hit_seed = sd
		elif n == 0:
			misses += 1
	_check("dp_some_alien_some_not", hit_seed != "" and misses > 0, [hit_seed, misses])
	if hit_seed == "":
		return
	XRiftAlien.ENABLED = false
	var off := XBattleLogic.new()
	off.setup(69, s, XBattleRandom.create(hit_seed, 1))
	var base_j: Array = off.random.rule.journal.map(func(x): return [x.reason, x.event, x.value])
	off.end_battle(0)
	XRiftAlien.ENABLED = true
	var lg2 := XBattleLogic.new()
	lg2.setup(69, s, XBattleRandom.create(hit_seed, 1))
	var e: XEnemy = lg2.enemies[0]
	var u := XRiftAlien.unit(lg2, e)
	_check("dp_alien_named", str(u.get("tier", "")) == "qinran" and e.display_name().begins_with("侵染·"), [u, e.display_name()])
	_check("dp_rule_stream_same", lg2.random.rule.journal.map(func(x): return [x.reason, x.event, x.value]) == base_j)
	var turns := 0
	while not lg2.is_over() and turns < 8:
		lg2.run_turn({})
		turns += 1
	_check("dp_turns_ran", turns > 0, turns)
	lg2.end_battle(0)
	_check("dp_end_clean", not XRiftAlien.active(lg2))


## T413：STAGE3_ALIEN 默认开（O-641），不设 STAGE_OVERRIDE、读真 XRift.stage()：
## rift3 看过前仍二阶；rift3 看过后三阶蚀骨规则生效（稀有、首领、守层者、深渊怪按阶段表）；
## 天启篇存档零变化；关掉 STAGE3_ALIEN 回到二阶。
func _stage3_default() -> void:
	XRiftAlien.STAGE_OVERRIDE = 0
	var s10 := _plain(10, true)
	var s15 := _plain(15, true)
	var s25 := _plain(25, true)
	var boss_only := func() -> Array: return _enemies(37).slice(2, 3)
	# 一、rift3 未看过：仍按二阶
	_check("s3_before_stage2", not XConfig.whisper_seen("rift3") and XRift.stage() == 2 and XRiftAlien.stage() == 2, [XRift.stage(), XRiftAlien.stage()])
	var g_pre := XRiftAlien.plan(s15, _enemies(69), _const(0.0))
	_check("s3_before_guard_st2", g_pre.size() == 1 and g_pre[0].tier == "qinran" and XRiftAlien.plan(s15, _enemies(69), _const(0.33)).is_empty(), g_pre)
	var b_pre := XRiftAlien.plan(s15, boss_only.call(), _const(0.15))
	_check("s3_before_boss_st2", b_pre.size() == 1 and b_pre[0].tier == "qinran" and XRiftAlien.plan(s15, boss_only.call(), _const(0.22)).is_empty(), b_pre)
	_check("s3_before_abyss_none", XRiftAlien.plan(s15, _enemies(145), _const(0.0)).is_empty())
	# 二、rift3 看过后：三阶蚀骨规则生效（stages_aligned["3"]）
	XConfig.whisper_mark("rift3")
	_check("s3_after_stage3", XRift.stage() == 3 and XRiftAlien.stage() == 3, [XRift.stage(), XRiftAlien.stage()])
	# 稀有：15% 侵染，10% 升蚀骨
	var r_base := XRiftAlien.plan(s15, _enemies(15), _const(0.14))
	var r_up := XRiftAlien.plan(s15, _enemies(15), _const(0.05))
	_check("s3_after_rare", r_base.size() == 1 and r_base[0].tier == "qinran" and r_up.size() == 1 and r_up[0].tier == "shigu"
		and XRiftAlien.plan(s15, _enemies(15), _const(0.15)).is_empty(), [r_base, r_up])
	# 首领：33% 蚀骨
	var b_hit := XRiftAlien.plan(s15, boss_only.call(), _const(0.32))
	_check("s3_after_boss_shigu", b_hit.size() == 1 and b_hit[0].tier == "shigu" and XRiftAlien.plan(s15, boss_only.call(), _const(0.33)).is_empty(), b_hit)
	# 守层者：100% 按层段（1-10 侵染、11-30 蚀骨；T455 三阶封顶蚀骨，21-30 不再化形）
	var g10 := XRiftAlien.plan(s10, _enemies(69), _const(0.99))
	var g15 := XRiftAlien.plan(s15, _enemies(69), _const(0.99))
	var g25 := XRiftAlien.plan(s25, _enemies(69), _const(0.99))
	_check("s3_after_guard_bands", g10.size() == 1 and g10[0].tier == "qinran"
		and g15.size() == 1 and g15[0].tier == "shigu"
		and g25.size() == 1 and g25[0].tier == "shigu", [g10, g15, g25])
	# 深渊怪：50% 蚀骨（T455 由化形改）
	var ab_hit := XRiftAlien.plan(s15, _enemies(145), _const(0.49))
	_check("s3_after_abyss_shigu", ab_hit.size() == 1 and ab_hit[0].tier == "shigu" and XRiftAlien.plan(s15, _enemies(145), _const(0.5)).is_empty(), ab_hit)
	# 真开战（不设 STAGE_OVERRIDE）：15 层守层者必出「蚀骨·」、规则随机流与关异化逐条相同、打几回合到结束不出错
	XRiftAlien.ENABLED = false
	var base_lg := XBattleLogic.new()
	base_lg.setup(69, s15, XBattleRandom.create(SEED, 1))
	var base_j: Array = base_lg.random.rule.journal.map(func(x): return [x.reason, x.event, x.value])
	var plain_hp: float = base_lg.enemies[0].mhp
	base_lg.end_battle(0)
	XRiftAlien.ENABLED = true
	var lg3 := XBattleLogic.new()
	lg3.setup(69, s15, XBattleRandom.create(SEED, 1))
	var e3: XEnemy = lg3.enemies[0]
	var u3 := XRiftAlien.unit(lg3, e3)
	_check("s3_battle_shigu", str(u3.get("tier", "")) == "shigu" and e3.display_name().begins_with("蚀骨·") and XRiftAlien.tint(e3, 0.0).a > 0.0, [u3, e3.display_name()])
	var want3 := 1.5 * (float(XRiftAlien.kind_info("berserk").mult[1]) if str(u3.get("kind", "")) == "berserk" else 1.0)
	_check("s3_battle_hp", absf(e3.mhp / plain_hp - want3) < 0.02 and is_equal_approx(e3.hp, e3.mhp), [e3.mhp / plain_hp, want3])
	_check("s3_battle_rule_stream_same", lg3.random.rule.journal.map(func(x): return [x.reason, x.event, x.value]) == base_j)
	var turns3 := 0
	while not lg3.is_over() and turns3 < 8:
		lg3.run_turn({})
		turns3 += 1
	_check("s3_battle_turns_ran", turns3 > 0, turns3)
	lg3.end_battle(0)
	_check("s3_battle_end_clean", not XRiftAlien.active(lg3) and not e3.has_meta("tianqi_prefix"))
	# 三、天启篇存档零变化（rift3 已看过、STAGE3_ALIEN 开着）
	var ts := _tianqi(15)
	_check("s3_tianqi_off", not XRiftAlien.on(ts) and XRiftAlien.plan(ts, _enemies(69), _const(0.0)).is_empty() and XRiftAlien.plan(ts, _enemies(145), _const(0.0)).is_empty())
	XRiftAlien.STAGE3_ALIEN = false
	var lt_off := XBattleLogic.new()
	lt_off.setup(69, ts, XBattleRandom.create(SEED, 1))
	var sig_off := _sig(lt_off)
	lt_off.end_battle(0)
	XRiftAlien.STAGE3_ALIEN = true
	var lt_on := XBattleLogic.new()
	lt_on.setup(69, ts, XBattleRandom.create(SEED, 1))
	_check("s3_tianqi_zero_diff", not XRiftAlien.active(lt_on) and not lt_on.enemies[0].has_meta(XRiftAlien.LOOK) and _sig(lt_on) == sig_off)
	lt_on.end_battle(0)
	# 四、关掉 STAGE3_ALIEN 回到二阶（rift3 仍在）
	XRiftAlien.STAGE3_ALIEN = false
	_check("s3_off_stage2", XRift.stage() == 3 and XRiftAlien.stage() == 2, [XRift.stage(), XRiftAlien.stage()])
	_check("s3_off_abyss_none", XRiftAlien.plan(s15, _enemies(145), _const(0.0)).is_empty())
	var g_off := XRiftAlien.plan(s15, _enemies(69), _const(0.0))
	_check("s3_off_guard_st2", g_off.size() == 1 and g_off[0].tier == "qinran" and XRiftAlien.plan(s15, _enemies(69), _const(0.33)).is_empty(), g_off)
	var b_off := XRiftAlien.plan(s15, boss_only.call(), _const(0.15))
	_check("s3_off_boss_st2", b_off.size() == 1 and b_off[0].tier == "qinran" and XRiftAlien.plan(s15, boss_only.call(), _const(0.22)).is_empty(), b_off)
	XRiftAlien.STAGE3_ALIEN = true
	(XConfig._values.codexWhisperSeen as Array).erase("rift3")
	_check("s3_cleanup_stage2", XRift.stage() == 2 and XRiftAlien.stage() == 2)


## T455：一阶玩家（漩涡二阶过场 rift2 没看过）：XRift.stage() 恒为 2 也不出任何异化、不挂画面标记（开发、发行都一样）
func _stage1_player() -> void:
	XRiftAlien.STAGE_OVERRIDE = 0
	var bad := []
	for rel in [false, true]:
		ReleaseEntry.simulate_release = rel
		var s := _plain(25, true)
		if XConfig.whisper_seen("rift2") or XRiftAlien.stage() != 1 or XRiftAlien.on(s):
			bad.append([rel, XRift.stage(), XRiftAlien.stage()])
		for troop in [69, 145, 37]:
			var lg := XBattleLogic.new()
			lg.setup(troop, s, XBattleRandom.create(SEED, 1))
			if XRiftAlien.active(lg) or lg.enemies.any(func(e): return e.has_meta(XRiftAlien.LOOK)):
				bad.append([rel, troop])
			lg.end_battle(0)
	ReleaseEntry.simulate_release = false
	_check("t455_stage1_player_none", bad.is_empty(), bad)


## T455：三阶封顶蚀骨（stages_aligned["3"].max_tier）：各类、各层、九档难度都不出化形；几率与旧四阶（对齐前的同一行）相同
func _stage3_cap() -> void:
	XRiftAlien.ALIGN_LOBBY = true
	var over := []
	var rate_diff := []
	for cls in ["rare", "very_rare", "guardian", "abyss"]:
		for f in [1, 10, 11, 20, 21, 25, 30]:
			for d in range(1, 10):
				var r := _r(cls, 3, f, d)
				if r.is_empty():
					continue
				if r[1] == "huaxing" or r[2] == "huaxing":
					over.append([cls, f, d, r])
				XRiftAlien.ALIGN_LOBBY = false
				var old := _r(cls, 4, f, d)
				XRiftAlien.ALIGN_LOBBY = true
				if old.is_empty() or old[0] != r[0]:
					rate_diff.append([cls, f, d, r, old])
	_check("t455_st3_no_huaxing", over.is_empty(), over.slice(0, 5))
	_check("t455_st3_rates_same", rate_diff.is_empty(), rate_diff.slice(0, 5))
	_check("t455_st3_low_guard", _r("guardian", 3, 25, 1)[1] == "qinran" and _r("guardian", 3, 25, 9)[1] == "shigu", [_r("guardian", 3, 25, 1), _r("guardian", 3, 25, 9)])
	_check("t455_st4_still_huaxing", _r("guardian", 4, 25)[1] == "huaxing" and _r("abyss", 4, 10)[1] == "huaxing")


## T455：发行模式（simulate_release）走玩家路径：rift3 前二阶（守层者 25 层出侵染～蚀骨按二阶表），rift3 后守层者 25 层出蚀骨不出化形；
## 整场打到底不出错；赢了图鉴点亮、不掉异化装备（XAlienBattle 发行隐藏）
func _release_path() -> void:
	XRiftAlien.STAGE_OVERRIDE = 0
	XRiftAlien.ALIGN_LOBBY = true
	ReleaseEntry.simulate_release = true
	(XConfig._values.codexWhisperSeen as Array).erase("rift3")
	var s := _plain(25, true)
	_check("rel_on_stage2", XRiftAlien.on(s) and XRiftAlien.stage() == 2, XRiftAlien.stage())
	var pre := XRiftAlien.plan(s, _enemies(69), _const(0.0))
	_check("rel_pre_rift3_guard_st2", pre.size() == 1 and pre[0].tier == "shigu" and XRiftAlien.plan(s, _enemies(69), _const(0.33)).is_empty(), pre)
	var lg_pre := XBattleLogic.new()
	lg_pre.setup(69, s, XBattleRandom.create(SEED, 1))
	var turns := 0
	while not lg_pre.is_over() and turns < 8:
		lg_pre.run_turn({})
		turns += 1
	_check("rel_pre_rift3_battle_ran", turns > 0 and XRiftAlien.active(lg_pre), turns)
	lg_pre.end_battle(0)
	XConfig.whisper_mark("rift3")
	_check("rel_after_stage3", XRiftAlien.stage() == 3)
	var tiers := {}
	for i in 12:
		var lg := XBattleLogic.new()
		lg.setup(69, s, XBattleRandom.create("%016x" % (0x5a17c0de00000100 + i), 1))
		for e in XRiftAlien.fight(lg).get("units", {}):
			tiers[str(XRiftAlien.fight(lg).units[e].tier)] = true
		lg.end_battle(0)
	_check("rel_after_guard25_shigu", tiers.keys() == ["shigu"], tiers.keys())
	s = _plain(25, true)  # 上一场打过的队伍血量留在档里，换一份新档
	var lg3 := XBattleLogic.new()
	lg3.setup(69, s, XBattleRandom.create(SEED, 1))
	var e3: XEnemy = lg3.enemies[0]
	_check("rel_after_named_shigu", e3.display_name().begins_with("蚀骨·"), e3.display_name())
	var t3 := 0
	while not lg3.is_over() and t3 < 8:
		lg3.run_turn({})
		t3 += 1
	_check("rel_after_battle_ran", t3 > 0, t3)
	# 赢了：图鉴点亮（键在 XRiftAlien 里拼，不靠 XTianqiAlienCodex）、发行隐藏下不掉装备
	e3.hp = 0.0
	e3.add_new_state(1)
	var gear_before := s.gear.size()
	XRiftAlien.force_drop = 0.0
	var got := XRiftAlien.grant(lg3)
	XRiftAlien.force_drop = -1.0
	var u3: Dictionary = XRiftAlien.unit(lg3, e3)
	var key := "%s:%s:%s" % [str(XRiftAlien.kind_info(str(u3.kind)).from), str(u3.kind), str(u3.tier)]
	_check("rel_codex_lit", (XConfig._values.codexTianqiAliens as Array).has(key), key)
	_check("rel_no_drop_hidden", XAlienBattle.hidden() and got.is_empty() and s.gear.size() == gear_before, got)
	lg3.end_battle(0)
	ReleaseEntry.simulate_release = false
	(XConfig._values.codexWhisperSeen as Array).erase("rift3")


## T498：13～30 层求道者／教派替身守层战按守层者类异化（三阶 100%、二阶 33%，层段同常规守层者）；
## 只认守层战里的替身（XZhenqi.STAND_IN_GUARDIANS），不误伤其他带【求道者】标签的敌人；带回退开关 STAND_IN_GUARDIAN；天启篇零改动。
func _stand_in_guardians() -> void:
	XRiftAlien.STAGE_OVERRIDE = 0
	XRiftAlien.ALIGN_LOBBY = true
	_check("t498_default_on", XRiftAlien.STAND_IN_GUARDIAN)
	# 1. 分类上下文：仅替身守层战里的【求道者】算 guardian；无敌群号或非替身敌群 787／766 不误伤
	_check("t498_class_context", XRiftAlien.class_of("【求道者】关羽") == ""
		and XRiftAlien.class_of("【求道者】关羽", 756) == "guardian"
		and XRiftAlien.class_of("【求道者】狗逍遥", 748) == "guardian"
		and XRiftAlien.class_of("【求道者】智甚", 765) == "guardian"
		and XRiftAlien.class_of("【求道者】斯盖", 787) == ""
		and XRiftAlien.class_of("【求道者】齐格鲁德", 787) == ""
		and XRiftAlien.class_of("求道者", 766) == "")
	# 35 场替身守层战（13～30 层纯替身 748～765、联合战 798～814）逐场核对：
	# 纯替身无原生守层者 -> 三阶异化【求道者】；联合战已有原生【守层者】 -> 不提升【求道者】，固定异化真【守层者】
	XConfig.whisper_mark("rift3")
	var pure_bad := []
	var joint_bad := []
	for tid_v in XZhenqi.STAND_IN_GUARDIANS:
		var tid := int(tid_v)
		var fl := int(XZhenqi.STAND_IN_GUARDIANS[tid])
		var es := _enemies(tid)
		var has_native := es.any(func(e): return XRiftAlien.class_of(e) == "guardian")
		var got := XRiftAlien.plan(_plain(fl, true), es, _const(0.99), tid)
		if has_native:
			if got.size() != 1 or not str(got[0].enemy.original_name()).begins_with("【守层者】"):
				joint_bad.append([tid, got])
		else:
			if got.size() != 1 or not str(got[0].enemy.original_name()).begins_with("【求道者】"):
				pure_bad.append([tid, got])
	_check("t498_all_stand_in_classified", pure_bad.is_empty() and joint_bad.is_empty(), [pure_bad, joint_bad])
	# 2. 同层对照（二阶 33%、三阶 100%，层段同常规守层者）：13 层（Map 64：常规 111 vs 替身 748）与 21 层（Map 117：常规 457 vs 替身 756 vs 联合战 806）
	(XConfig._values.codexWhisperSeen as Array).erase("rift3")
	var s13 := _plain(13, true)
	s13.map_id = 64
	s13.set_switch(2302, true)
	var s21 := _plain(21, true)
	s21.map_id = 117
	s21.set_switch(2302, true)
	var r13_st2 := XRiftAlien.plan(s13, _enemies(111), _const(0.32), 111)
	var si13_st2 := XRiftAlien.plan(s13, _enemies(748), _const(0.32), 748)
	_check("t498_st2_f13_same", r13_st2.size() == 1 and si13_st2.size() == 1
		and r13_st2[0].tier == "qinran" and si13_st2[0].tier == "qinran" and si13_st2[0]["class"] == "guardian"
		and XRiftAlien.plan(s13, _enemies(748), _const(0.33), 748).is_empty(), [r13_st2, si13_st2])
	var r21_st2 := XRiftAlien.plan(s21, _enemies(457), _const(0.32), 457)
	var si21_st2 := XRiftAlien.plan(s21, _enemies(756), _const(0.32), 756)
	_check("t498_st2_f21_same", r21_st2.size() == 1 and si21_st2.size() == 1
		and r21_st2[0].tier == "shigu" and si21_st2[0].tier == "shigu" and si21_st2[0]["class"] == "guardian"
		and XRiftAlien.plan(s21, _enemies(756), _const(0.33), 756).is_empty(), [r21_st2, si21_st2])
	# 联合战 806（【求道者】关羽＋【守层者】六道魔君）二阶用顺序掷点验证：首掷 0.5 没中后不会去掷【求道者】，整场不出异化（几率仍 33% 非 55.6%）；首掷 0.32 中时异化真守层者
	var miss_rates := [0]
	var miss_roll := func(reason: String, _key: String) -> float:
		if reason == "rift_alien.rate":
			miss_rates[0] += 1
			return 0.5 if miss_rates[0] == 1 else 0.0
		return 0.0
	var lh21_st2_miss := XRiftAlien.plan(s21, _enemies(806), miss_roll, 806)
	var hit_rates := [0]
	var hit_roll := func(reason: String, _key: String) -> float:
		if reason == "rift_alien.rate":
			hit_rates[0] += 1
			return 0.32 if hit_rates[0] == 1 else 0.99
		return 0.0
	var lh21_st2_hit := XRiftAlien.plan(s21, _enemies(806), hit_roll, 806)
	_check("t498_st2_joint_806_rate_33pct", lh21_st2_miss.is_empty() and miss_rates[0] == 1
		and lh21_st2_hit.size() == 1 and hit_rates[0] == 1
		and lh21_st2_hit[0].tier == "shigu" and lh21_st2_hit[0].enemy.original_name() == "【守层者】六道魔君",
		[lh21_st2_miss, miss_rates, lh21_st2_hit, hit_rates])
	# 三阶（rift3 看过）：13 层与 21 层常规／替身都 100% 蚀骨；26 层双替身 761 最多异化 1 只；联合战 806 固定异化真守层者【守层者】六道魔君
	XConfig.whisper_mark("rift3")
	var r13_st3 := XRiftAlien.plan(s13, _enemies(111), _const(0.99), 111)
	var si13_st3 := XRiftAlien.plan(s13, _enemies(748), _const(0.99), 748)
	var r21_st3 := XRiftAlien.plan(s21, _enemies(457), _const(0.99), 457)
	var si21_st3 := XRiftAlien.plan(s21, _enemies(756), _const(0.99), 756)
	var si26_st3 := XRiftAlien.plan(_plain(26, true), _enemies(761), _const(0.99), 761)
	var lh21_st3 := XRiftAlien.plan(s21, _enemies(806), _const(0.99), 806)
	_check("t498_st3_100pct_same_band", r13_st3.size() == 1 and si13_st3.size() == 1 and r13_st3[0].tier == "shigu" and si13_st3[0].tier == "shigu"
		and r21_st3.size() == 1 and si21_st3.size() == 1 and r21_st3[0].tier == "shigu" and si21_st3[0].tier == "shigu"
		and si26_st3.size() == 1 and si26_st3[0].tier == "shigu"
		and lh21_st3.size() == 1 and lh21_st3[0].tier == "shigu" and lh21_st3[0].enemy.original_name() == "【守层者】六道魔君",
		[r13_st3, si13_st3, r21_st3, si21_st3, si26_st3, lh21_st3])
	# 3. 真实开战：21 层常规守层（457）与替身守层（756 【求道者】关羽）都异化为蚀骨、挂幽紫偏色、规则随机流不受影响
	XRiftAlien.ENABLED = false
	var base_si := XBattleLogic.new()
	base_si.setup(756, s21, XBattleRandom.create(SEED, 1))
	var base_si_j: Array = base_si.random.rule.journal.map(func(x): return [x.reason, x.event, x.value])
	var base_si_hp: float = base_si.enemies[0].mhp
	base_si.end_battle(0)
	XRiftAlien.ENABLED = true
	var lg_reg := XBattleLogic.new()
	lg_reg.setup(457, s21, XBattleRandom.create(SEED, 1))
	var e_reg: XEnemy = lg_reg.enemies[0]
	var lg_si := XBattleLogic.new()
	lg_si.setup(756, s21, XBattleRandom.create(SEED, 1))
	var e_si: XEnemy = lg_si.enemies[0]
	var u_si := XRiftAlien.unit(lg_si, e_si)
	var look_si: Dictionary = e_si.get_meta(XRiftAlien.LOOK, {})
	_check("t498_battle_both_alien", e_reg.display_name().begins_with("蚀骨·") and e_si.display_name().begins_with("蚀骨·【求道者】关羽")
		and str(u_si.get("tier", "")) == "shigu" and str(u_si.get("class", "")) == "guardian"
		and bool(look_si.get("pulse", false)) and XRiftAlien.tint(e_si, 0.0).a > 0.0
		and e_si.mhp > base_si_hp * 1.4
		and lg_si.turn_start_logs.any(func(x): return str(x.get("text", "")).contains("漩涡的颜色渗进了【求道者】关羽：蚀骨·")),
		[e_reg.display_name(), e_si.display_name(), u_si, look_si])
	_check("t498_battle_rule_stream_same", lg_si.random.rule.journal.map(func(x): return [x.reason, x.event, x.value]) == base_si_j)
	lg_reg.end_battle(0)
	lg_si.end_battle(0)
	# 轮回归来联合战 806（【求道者】关羽＋【守层者】六道魔君）：真守层者异化并挂脉动，【求道者】按原分类不异化、不挂脉动
	var lg_lh := XBattleLogic.new()
	lg_lh.setup(806, s21, XBattleRandom.create(SEED, 1))
	var e_lh_qdz: XEnemy = lg_lh.enemies[0]
	var e_lh_gd: XEnemy = lg_lh.enemies[1]
	_check("t498_lunhui_806_real_guardian_only", XRiftAlien.fight(lg_lh).units.size() == 1
		and e_lh_qdz.original_name() == "【求道者】关羽"
		and not XRiftAlien.is_alien(lg_lh, e_lh_qdz) and not e_lh_qdz.has_meta("tianqi_prefix") and not e_lh_qdz.has_meta(XRiftAlien.LOOK)
		and e_lh_gd.original_name() == "【守层者】六道魔君"
		and XRiftAlien.is_alien(lg_lh, e_lh_gd) and e_lh_gd.display_name().begins_with("蚀骨·【守层者】六道魔君")
		and bool(e_lh_gd.get_meta(XRiftAlien.LOOK, {}).get("pulse", false)),
		[e_lh_qdz.display_name(), e_lh_qdz.get_meta(XRiftAlien.LOOK, {}), e_lh_gd.display_name(), e_lh_gd.get_meta(XRiftAlien.LOOK, {})])
	lg_lh.end_battle(0)
	# 4. 非守层战带【求道者】标签的敌人（敌群 787：斯盖＋齐格鲁德）不误伤
	var lg_other := XBattleLogic.new()
	lg_other.setup(787, s21, XBattleRandom.create(SEED, 1))
	_check("t498_non_stand_in_untouched", XRiftAlien.fight(lg_other).units.is_empty()
		and lg_other.enemies.all(func(e): return not e.has_meta("tianqi_prefix") and not e.has_meta(XRiftAlien.LOOK)))
	lg_other.end_battle(0)
	# 5. 回退开关 STAND_IN_GUARDIAN = false：替身 756 恢复不异化，常规 457 不受影响
	XRiftAlien.STAND_IN_GUARDIAN = false
	_check("t498_rollback_class_empty", XRiftAlien.class_of("【求道者】关羽", 756) == ""
		and XRiftAlien.plan(s21, _enemies(756), _const(0.0), 756).is_empty())
	var lg_off := XBattleLogic.new()
	lg_off.setup(756, s21, XBattleRandom.create(SEED, 1))
	var lg_reg_off := XBattleLogic.new()
	lg_reg_off.setup(457, s21, XBattleRandom.create(SEED, 1))
	_check("t498_rollback_battle", XRiftAlien.fight(lg_off).units.is_empty()
		and not lg_off.enemies[0].has_meta("tianqi_prefix") and not lg_off.enemies[0].has_meta(XRiftAlien.LOOK)
		and lg_reg_off.enemies[0].display_name().begins_with("蚀骨·"))
	lg_off.end_battle(0)
	lg_reg_off.end_battle(0)
	XRiftAlien.STAND_IN_GUARDIAN = true
	# 6. 天启篇存档零改动（756 不激活、不挂标记）
	var ts := _tianqi(21)
	ts.map_id = 117
	var lg_tq := XBattleLogic.new()
	lg_tq.setup(756, ts, XBattleRandom.create(SEED, 1))
	_check("t498_tianqi_zero_diff", not XRiftAlien.on(ts) and not XRiftAlien.active(lg_tq)
		and not lg_tq.enemies[0].has_meta(XRiftAlien.LOOK) and not lg_tq.enemies[0].has_meta("tianqi_prefix"))
	lg_tq.end_battle(0)
	(XConfig._values.codexWhisperSeen as Array).erase("rift3")
