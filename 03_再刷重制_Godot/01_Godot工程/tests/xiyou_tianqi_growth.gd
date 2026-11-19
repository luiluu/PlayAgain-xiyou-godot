extends Node
## 天启篇无限成长底座专项（T256，XTianqiGrowth，表 tianqi_data/growth.json；稿 天启篇_无限成长_v0.4 第二节、3.5 节、第八节卡①③）。
## 层价表边界（12/13、24/25/26）与 next_need；平加两条断言（穿脱带百分比词条的装备、有无能力强化状态，层数带来的面板增量
## 都等于表里的数×层数；另加种族祝福不放大）；计数在基础段以内 param_flat 恒 0；floor_ok（v0.2 卡③那几条＋深渊层号 0）；
## 开关关掉回原数、西游档零变化；存档读写后层数照算。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
const G := preload("res://modes/xiyou/core/tianqi_growth.gd")
var results: Array = []
var kit: Kit


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _join(s: XState, id: int) -> XActor:
	XTianqi._joining = true
	s.add_actor(id)
	XTianqi._joining = false
	return s.actor(id)


func _fresh(a: XActor) -> void:
	a.param_mark_dirty()
	a.param_refresh()


func _wear(a: XActor, affixes: Array) -> void:
	a.keep_unequippable = true
	var inst := {"kind": "armor", "name": "测试", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 3, "tianqi_affixes": affixes}
	var slot := 1
	while slot < a.equips.size() and a.equips[slot] is Dictionary and a.equips[slot].has("tianqi_affixes"):
		slot += 1
	while a.equips.size() <= slot:
		a.equips.append(null)
	a.equips[slot] = inst
	_fresh(a)


func _strip(a: XActor) -> void:
	for k in a.equips.size():
		if a.equips[k] is Dictionary and a.equips[k].has("tianqi_affixes"):
			a.equips[k] = null
	_fresh(a)


func _x(key: String) -> Dictionary:
	return {"key": key, "tier": 4, "grade": "perfect", "extra": {}}


## 同一个人：层数在／不在（set_count 改计数）两次读同一项面板，差多少
func _delta(a: XActor, i: int, set_count: Callable, on_count, off_count) -> float:
	set_count.call(off_count)
	_fresh(a)
	var lo := a.param(i)
	set_count.call(on_count)
	_fresh(a)
	return a.param(i) - lo


func _run() -> void:
	kit = Kit.new("xiyou_tianqi_growth")
	G.reload_table()
	var d := G.data()
	_check("table", not d.is_empty() and d.actors.has("raven") and d.actors.has("nanoha") and d.actors.has("liuying"))
	_price()
	_floor_facts()
	var s := Kit.new_game()
	_check("on", G.on(s))
	var nanoha := _join(s, XNanoha.ACTOR)
	var raven := _join(s, XRaven.ACTOR)
	var nrow := G.actor_row("nanoha")
	var rrow := G.actor_row("raven")
	var n_hp := float(nrow.flat["0"])
	var n_mp := float(nrow.flat["1"])
	var r_mat := float(rrow.flat["4"])
	var set_adapt := func(n): s.flags[XNanoha.ADAPT_FLAG] = {str(XNanoha.ACTOR): float(n)}
	var set_soul := func(n): s.raven["soul"] = float(n)
	# T258：「一份」按 growth.json 读（T260 回填后不再写死 150／10000），基础段也读表
	var n_base := int(nrow.base)
	var n_share := int(nrow.share)
	var r_base := int(rrow.base)
	var r_share := int(rrow.share)
	var n24 := n_base + 36 * n_share  # 拐点 24 层
	var r24 := r_base + 36 * r_share
	# ---- 基础段以内恒 0（本卡不接计数，T220 现数不变）----
	set_adapt.call(n_base)
	_check("nanoha_base_zero", G.param_flat(nanoha, 0) == 0.0 and G.param_flat(nanoha, 1) == 0.0 and G.layers_of("nanoha", nanoha) == 0)
	set_adapt.call(n_base + n_share - 0.5)
	_check("nanoha_half_short", G.layers_of("nanoha", nanoha) == 0 and is_equal_approx(G.next_need_of("nanoha", nanoha), 0.5), G.next_need_of("nanoha", nanoha))
	set_adapt.call(n_base + n_share)
	_check("nanoha_first_layer", G.layers_of("nanoha", nanoha) == 1 and G.param_flat(nanoha, 1) == n_mp)
	set_soul.call(0)
	_check("raven_zero", G.param_flat(raven, 4) == 0.0)
	set_soul.call(r24)
	_check("raven_no_10136", not XRaven.has(raven, 10136) and G.param_flat(raven, 4) == 0.0)  # 没学至尊鸦皇不成层
	raven.change_level(60)
	s.actor_advance[XRaven.ACTOR] = 5
	raven.learn_skill(10136)
	set_soul.call(r24)  # T257：没学 10136 时升级 sync 会把灵魂压回 15 万，学会以后再灌
	_check("raven_learned", XRaven.has(raven, 10136) and G.layers_of("raven", raven) == 24, G.layers_of("raven", raven))
	_check("raven_only_mat", G.param_flat(raven, 4) == 24.0 * r_mat and G.param_flat(raven, 0) == 0.0 and G.param_flat(raven, 2) == 0.0)
	_check("nanoha_not_mat", G.param_flat(nanoha, 4) == 0.0)
	# ---- 平加断言①：穿脱带百分比词条的装备 ----
	var bare_hp := _delta(nanoha, 0, set_adapt, n24, n_base)
	var bare_mp := _delta(nanoha, 1, set_adapt, n24, n_base)
	var bare_mat := _delta(raven, 4, set_soul, r24, r_base)
	_check("flat_bare", bare_hp == 24.0 * n_hp and bare_mp == 24.0 * n_mp and bare_mat == 24.0 * r_mat, [bare_hp, bare_mp, bare_mat])
	_wear(nanoha, [_x("mhp"), _x("mmp")])
	_wear(raven, [_x("mat")])
	var rate_ok := XTianqiAffixBattle.param_rate(nanoha, 1) > 1.0 and XTianqiAffixBattle.param_rate(raven, 4) > 1.0
	var g_hp := _delta(nanoha, 0, set_adapt, n24, n_base)
	var g_mp := _delta(nanoha, 1, set_adapt, n24, n_base)
	var g_mat := _delta(raven, 4, set_soul, r24, r_base)
	_check("flat_gear", rate_ok and g_hp == 24.0 * n_hp and g_mp == 24.0 * n_mp and g_mat == 24.0 * r_mat, [rate_ok, g_hp, g_mp, g_mat])
	# ---- 平加断言②：能力强化状态 ----
	nanoha.buffs[0] = 2
	nanoha.buffs[1] = 2
	raven.buffs[4] = 2
	var b_hp := _delta(nanoha, 0, set_adapt, n24, n_base)
	var b_mp := _delta(nanoha, 1, set_adapt, n24, n_base)
	var b_mat := _delta(raven, 4, set_soul, r24, r_base)
	_check("flat_buff", b_hp == 24.0 * n_hp and b_mp == 24.0 * n_mp and b_mat == 24.0 * r_mat, [b_hp, b_mp, b_mat])
	nanoha.buffs[0] = 0
	nanoha.buffs[1] = 0
	raven.buffs[4] = 0
	# ---- 种族祝福（外层包装）不放大平加：鬼族最大魔法、蛮族最大生命、人族八项 ----
	var races: Dictionary = XRace.state(s).actors
	for r in [[4, 1], [6, 0], [2, 1]]:
		races[str(XNanoha.ACTOR)] = {"race": r[0], "rank": 7}
		var rd := _delta(nanoha, r[1], set_adapt, n24, n_base)
		_check("flat_race_%d" % r[0], rd == 24.0 * (n_mp if r[1] == 1 else n_hp), [r, rd])
	races[str(XRaven.ACTOR)] = {"race": 2, "rank": 7}
	var rm := _delta(raven, 4, set_soul, r24, r_base)
	_check("flat_race_human_mat", rm == 24.0 * r_mat, rm)
	G.RACE_FLAT = false  # 回退支：种族照旧放大平加
	var rm_off := _delta(raven, 4, set_soul, r24, r_base)
	_check("race_flat_off", rm_off > 24.0 * r_mat, rm_off)
	G.RACE_FLAT = true
	races.erase(str(XNanoha.ACTOR))
	races.erase(str(XRaven.ACTOR))
	_strip(nanoha)
	_strip(raven)
	# ---- 第 25、26 层（层价表拐点后）----
	set_adapt.call(n_base + 40 * n_share)
	_check("nanoha_l25", G.layers_of("nanoha", nanoha) == 25)
	set_adapt.call(n_base + 48 * n_share - 1)
	_check("nanoha_l25_edge", G.layers_of("nanoha", nanoha) == 25 and G.next_need_of("nanoha", nanoha) == 1.0)
	# ---- 存档读写：层数从原有计数现算，不加存档字段 ----
	set_adapt.call(n24)
	_fresh(nanoha)
	var mp24 := nanoha.mmp
	var back := kit.roundtrip()
	var nb: XActor = back.actor(XNanoha.ACTOR) if back != null else null
	_check("roundtrip", nb != null and G.layers_of("nanoha", nb) == 24 and nb.mmp == mp24, [nb.mmp if nb != null else null, mp24])
	var tq_keys := (back.flags.tianqi as Dictionary).keys() if back != null else []
	_check("no_save_field", not tq_keys.has("growth"), tq_keys)
	s = back
	nanoha = nb
	# ---- 回退开关：整个关掉回原数 ----
	G.ENABLED = false
	_fresh(nanoha)
	var mp_off := nanoha.mmp
	_check("off_flat", G.param_flat(nanoha, 1) == 0.0 and mp_off == mp24 - 24.0 * n_mp and G.layers(9999999.0, 0.0, 1.0) == 0, [mp_off, mp24])
	_check("off_floor_ok", G.floor_ok_facts({"progress": 33, "map_floor": 1}))
	G.ENABLED = true
	_fresh(nanoha)
	# ---- floor_ok 真存档：主塔进度 33（变量 20＝34）----
	s.set_variable(20, 34)
	s.map_id = _map_of_floor(28, false)
	_check("floor_real_28", G.floor_ok(s), s.map_id)
	s.map_id = _map_of_floor(27, false)
	_check("floor_real_27", not G.floor_ok(s), s.map_id)
	s.map_id = 216  # 深渊:无为深渊（29）
	_check("floor_real_abyss29", G.facts(s).abyss and G.floor_ok(s), G.facts(s))
	s.map_id = 37  # 深渊:无垠虚空（13）
	_check("floor_real_abyss13", G.facts(s).abyss and not G.floor_ok(s), G.facts(s))
	s.map_id = 107  # 深渊:魔王之渊（天之上，层号 0）
	_check("floor_real_abyss0", not G.floor_ok(s), G.facts(s))
	s.set_variable(XDungeon.VAR_INSIDE, 1)
	s.set_variable(XDungeon.VAR_TIER, 4)
	_check("floor_real_king", G.floor_ok(s), G.facts(s))
	s.set_variable(XDungeon.VAR_TIER, 3)
	_check("floor_real_not_king", not G.floor_ok(s))
	s.set_variable(XDungeon.VAR_INSIDE, 0)
	# ---- 西游档零变化 ----
	var plain := XState.new_game(3, 1, [XNanoha.ACTOR])
	XState.current = plain
	var pn: XActor = plain.actor(XNanoha.ACTOR)
	plain.flags[XNanoha.ADAPT_FLAG] = {str(XNanoha.ACTOR): float(n24)}
	_check("plain_off", not G.on(plain) and pn != null and G.param_flat(pn, 1) == 0.0 and G.layers_of("nanoha", pn) == 0)
	XState.current = s
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _price() -> void:
	var want := {1: 1, 12: 1, 13: 2, 24: 2, 25: 4, 26: 8, 27: 16, 30: 128}
	var bad := []
	for n in want:
		if G.price(n) != float(want[n]):
			bad.append([n, G.price(n)])
	_check("price", bad.is_empty(), bad)
	var cum := {12: 12, 13: 14, 24: 36, 25: 40, 26: 48, 27: 64, 28: 96, 29: 160, 30: 288, 32: 1056}
	bad = []
	for n in cum:
		if G.cumulative(n) != float(cum[n]):
			bad.append([n, G.cumulative(n)])
	_check("cumulative", bad.is_empty(), bad)
	# 份数直接当计数（base 0、share 1）：12/13、24/25/26 的边界
	var lay := {0: 0, 1: 1, 12: 12, 13: 12, 14: 13, 35: 23, 36: 24, 39: 24, 40: 25, 47: 25, 48: 26, 63: 26, 64: 27}
	bad = []
	for c in lay:
		if G.layers(float(c), 0.0, 1.0) != int(lay[c]):
			bad.append([c, G.layers(float(c), 0.0, 1.0)])
	_check("layers_edges", bad.is_empty(), bad)
	# 渡鸦的一份 1 万、基础 20 万
	_check("layers_raven", G.layers(200000.0, 200000.0, 10000.0) == 0 and G.layers(209999.0, 200000.0, 10000.0) == 0 and G.layers(210000.0, 200000.0, 10000.0) == 1 and G.layers(560000.0, 200000.0, 10000.0) == 24 and G.layers(150000.0, 200000.0, 10000.0) == 0)
	_check("next_need", G.next_need(200000.0, 200000.0, 10000.0) == 10000.0 and G.next_need(0.0, 200000.0, 10000.0) == 210000.0 and G.next_need(560000.0, 200000.0, 10000.0) == 40000.0 and G.next_need(205000.0, 200000.0, 10000.0) == 5000.0)
	_check("huge_count_finite", G.layers(1e15, 0.0, 1.0) > 30 and G.layers(1e15, 0.0, 1.0) < 80, G.layers(1e15, 0.0, 1.0))
	_check("liuying_helpers", G.ember_bonus(24) == 12000 and G.dmg_pct_of(24) == 24 and G.dmg_pct_of(0) == 0 and G.ember_bonus(-1) == 0)


func _floor_facts() -> void:
	# v0.2 卡③：主塔 33 层时打 28 层涨、27 层不涨；通四骑士后刷妄语／无为深渊照涨、刷 13 层深渊不涨；王者副本照涨
	var F := func(f: Dictionary) -> bool: return G.floor_ok_facts(f)
	_check("fo_main_28", F.call({"progress": 33, "map_floor": 28}))
	_check("fo_main_27", not F.call({"progress": 33, "map_floor": 27}))
	_check("fo_abyss_28", F.call({"progress": 33, "map_floor": 28, "abyss": true}))
	_check("fo_abyss_29", F.call({"progress": 33, "map_floor": 29, "abyss": true}))
	_check("fo_abyss_24", F.call({"progress": 33, "map_floor": 24, "abyss": true}))  # min(33,29)−5＝24：痛苦深渊照算
	_check("fo_abyss_22", not F.call({"progress": 33, "map_floor": 22, "abyss": true}))
	_check("fo_abyss_13", not F.call({"progress": 33, "map_floor": 13, "abyss": true}))
	_check("fo_abyss_0", not F.call({"progress": 3, "map_floor": 0, "abyss": true}))  # 天之上那几张深渊层号 0，不算
	_check("fo_abyss_low_progress", F.call({"progress": 15, "map_floor": 13, "abyss": true}))
	_check("fo_king", F.call({"progress": 33, "map_floor": 1, "king": true}))
	_check("fo_qiyin", F.call({"progress": 33, "map_floor": 0, "qiyin": true}))
	_check("fo_finale", F.call({"progress": 33, "map_floor": 0, "finale": true}))
	_check("fo_early", F.call({"progress": 3, "map_floor": 0}))  # 进度 5 层以内哪儿都算


func _map_of_floor(f: int, abyss: bool) -> int:
	for i in range(1, 1000):
		var info := XDB.rec("MapInfos", i)
		if info.is_empty() or str(info.get("name", "")).begins_with("深渊") != abyss:
			continue
		if XDungeon.map_floor(i) == f:
			return i
	return 0
