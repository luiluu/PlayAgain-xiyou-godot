extends Node
## 天启篇无限成长三人计数接线专项（T257；稿 天启篇_无限成长_v0.4 3.1～3.3、第八节卡②；Kyo D216 Q5 甲、Q6 乙）。
## 渡鸦：没学 10136 灵魂停 15 万、sync 压回；学了不戴镰刀层数魔攻照给；20 万以上过 floor_ok。
## 奈叶：1999.5 跨 2000 拆半次（前半次 +5／+15，后半次过 floor_ok）；过 2000 不再 add_param；改次数后面板自己刷新。
## 流萤：不戴 4004 胜场照记；300 胜以上过 floor_ok；有效余烬＝min(3000,余烬)＋500×层；0～299 胜不白拿；伤害 ×(100＋层)/100 普攻也吃；无 ×1.2。
## T256 核查：P2-1 内层减益下 unrace 不过退；P2-2 人族渡鸦平加逐层正好；P3-1 四骑士开场生存战不算终局。开关关掉回现状；存档读写。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
const G := preload("res://modes/xiyou/core/tianqi_growth.gd")
var results: Array = []
var kit: Kit


class FakeLogic extends RefCounted:
	var enemies := []
	var troop_id := 0


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


func _map_of_floor(f: int) -> int:
	for i in range(1, 1000):
		var info := XDB.rec("MapInfos", i)
		if info.is_empty() or str(info.get("name", "")).begins_with("深渊"):
			continue
		if XDungeon.map_floor(i) == f:
			return i
	return 0


func _mul(ops: Array) -> Array:
	return ops.filter(func(o): return str(o.get("field", "")) == "finalMultiplier").map(func(o): return float(o.value))


func _run() -> void:
	kit = Kit.new("xiyou_tianqi_growth_count")
	G.reload_table()
	var s := Kit.new_game()
	_check("on", G.on(s) and XTianqiSkills.cards_on())
	s.set_variable(20, 34)  # 已通主塔 33 层
	var ok_map := _map_of_floor(28)
	var bad_map := _map_of_floor(1)
	var set_ok := func(ok: bool): s.map_id = ok_map if ok else bad_map
	set_ok.call(false)
	_check("floor_maps", ok_map > 0 and bad_map > 0 and not G.floor_ok(s), [ok_map, bad_map])
	_raven(s, set_ok)
	_nanoha(s, set_ok)
	_liuying(s, set_ok)
	_unrace(s)
	_finale(s)
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _raven(s: XState, set_ok: Callable) -> void:
	var r := _join(s, XRaven.ACTOR)
	var N := float(G.actor_row("raven").flat["4"])
	r.change_level(50)
	s.actor_advance[XRaven.ACTOR] = 5
	XRaven.sync(r)
	_check("raven_no10136", not XRaven.has(r, 10136))
	s.raven["soul"] = 149990.0
	_check("raven_cap_gain", XRaven.growth_gain(s, r, 50.0) == 10.0 and XRaven.growth_gain(s, r, 5.0) == 5.0)
	s.raven["soul"] = 150000.0
	_check("raven_cap_full", XRaven.growth_gain(s, r, 50.0) == 0.0)
	s.raven["soul"] = 180000.0  # 旧档预攒
	XRaven.sync(r)
	_check("raven_sync_clamp", XRaven.soul(r) == 150000.0, XRaven.soul(r))
	G.ENABLED = false
	_check("raven_off_gain", XRaven.growth_gain(s, r, 50.0) == 50.0)
	s.raven["soul"] = 180000.0
	XRaven.sync(r)
	_check("raven_off_noclamp", XRaven.soul(r) == 180000.0)
	G.ENABLED = true
	s.raven["soul"] = 150000.0
	r.change_level(60)
	XRaven.sync(r)
	_check("raven_learn_10136", XRaven.has(r, 10136) and XRaven.soul(r) == 150000.0)
	# 学了 10136：20 万以内哪儿都算，超出过 floor_ok
	set_ok.call(false)
	s.raven["soul"] = 199990.0
	_check("raven_base_free", XRaven.growth_gain(s, r, 50.0) == 10.0)
	s.raven["soul"] = 150000.0
	_check("raven_base_all", XRaven.growth_gain(s, r, 50.0) == 50.0)
	set_ok.call(true)
	s.raven["soul"] = 199990.0
	_check("raven_floor_ok", XRaven.growth_gain(s, r, 50.0) == 50.0)
	# 不戴镰刀照涨
	_check("raven_no_scythe", not XRaven.artifact_equipped(r))
	s.raven["soul"] = 200000.0
	_fresh(r)
	var lo := r.param(4)
	s.raven["soul"] = 560000.0
	_fresh(r)
	_check("raven_flat_no_scythe", r.param(4) - lo == 24.0 * N, [r.param(4) - lo, N])
	# P2-2：人族 ×1.03 逐层平加正好 L×N（不差 ±1）
	var races: Dictionary = XRace.state(s).actors
	races[str(XRaven.ACTOR)] = {"race": 2, "rank": 7}
	s.raven["soul"] = 200000.0
	_fresh(r)
	var base := r.param(4)
	var bad := []
	for L in range(1, 31):
		s.raven["soul"] = 200000.0 + G.cumulative(L) * 10000.0
		_fresh(r)
		if r.param(4) - base != float(L) * N:
			bad.append([L, r.param(4) - base])
	_check("raven_human_exact", bad.is_empty(), bad)
	races.erase(str(XRaven.ACTOR))
	s.raven["soul"] = 0.0
	_fresh(r)


func _nanoha(s: XState, set_ok: Callable) -> void:
	var n := _join(s, XNanoha.ACTOR)
	var row := G.actor_row("nanoha")
	var Y := float(row.flat["1"])
	var key := str(XNanoha.ACTOR)
	var set_n := func(v): s.flags[XNanoha.ADAPT_FLAG] = {key: float(v)}
	var cnt := func() -> float: return float(s.flags[XNanoha.ADAPT_FLAG][key])
	# 跨 2000 拆半次：后半次 floor 不过就不记
	set_ok.call(false)
	set_n.call(1999.5)
	var hp0 := XParamPlus.bonus(n, 0)
	var mp0 := XParamPlus.bonus(n, 1)
	XNanoha.adapt(n, 1.0)
	_check("nanoha_split_bad", cnt.call() == 2000.0 and XParamPlus.bonus(n, 0) - hp0 == 5.0 and XParamPlus.bonus(n, 1) - mp0 == 15.0,
		[cnt.call(), XParamPlus.bonus(n, 0) - hp0, XParamPlus.bonus(n, 1) - mp0])
	set_ok.call(true)
	set_n.call(1999.5)
	hp0 = XParamPlus.bonus(n, 0)
	mp0 = XParamPlus.bonus(n, 1)
	XNanoha.adapt(n, 1.0)
	_check("nanoha_split_ok", cnt.call() == 2000.5 and XParamPlus.bonus(n, 0) - hp0 == 5.0 and XParamPlus.bonus(n, 1) - mp0 == 15.0, cnt.call())
	# 过 2000 不再 add_param；队友半次
	mp0 = XParamPlus.bonus(n, 1)
	set_n.call(2100)
	XNanoha.adapt(n, 0.5)
	_check("nanoha_no_addparam", cnt.call() == 2100.5 and XParamPlus.bonus(n, 1) == mp0)
	set_ok.call(false)
	XNanoha.adapt(n, 1.0)
	_check("nanoha_floor_bad", cnt.call() == 2100.5)
	# 基础段内照原版
	set_n.call(100)
	mp0 = XParamPlus.bonus(n, 1)
	XNanoha.adapt(n, 1.0)
	_check("nanoha_base", cnt.call() == 101.0 and XParamPlus.bonus(n, 1) - mp0 == 30.0)
	# 跨层自己刷新面板（不手动 mark_dirty）
	set_ok.call(true)
	set_n.call(2149)
	_fresh(n)
	var mmp0 := n.mmp
	XNanoha.adapt(n, 1.0)
	_check("nanoha_dirty", G.layers_of("nanoha", n) == 1 and n.mmp - mmp0 == Y, [n.mmp - mmp0, Y])
	# 开关关掉回原版逐次公式
	G.ENABLED = false
	set_n.call(2100)
	mp0 = XParamPlus.bonus(n, 1)
	XNanoha.adapt(n, 1.0)
	_check("nanoha_off", cnt.call() == 2101.0 and is_equal_approx(XParamPlus.bonus(n, 1) - mp0, 30.0 * 2000.0 / 2100.0), XParamPlus.bonus(n, 1) - mp0)
	G.ENABLED = true
	# 存档读写
	set_n.call(2000 + 36 * 150)
	_fresh(n)
	var mmp24 := n.mmp
	var back := kit.roundtrip()
	var nb: XActor = back.actor(XNanoha.ACTOR) if back != null else null
	_check("nanoha_roundtrip", nb != null and G.layers_of("nanoha", nb) == 24 and nb.mmp == mmp24, [nb.mmp if nb != null else null, mmp24])
	XState.current = s
	set_n.call(0)
	_fresh(n)


func _liuying(s: XState, set_ok: Callable) -> void:
	var a := _join(s, XLiuying.ACTOR)
	var sd := a.state_data
	_check("ly_no_4004", not a.has_base_equip("weapon", XLiuying.WEAPON))
	set_ok.call(false)
	sd["_codexLbEmber"] = 2990.0
	sd["_codexLbEmberWins"] = 299.0
	XLiuying.gain_rewards([a])
	_check("ly_win_no_weapon", float(sd._codexLbEmberWins) == 300.0 and float(sd._codexLbEmber) == 3000.0, [sd._codexLbEmberWins, sd._codexLbEmber])
	XLiuying.gain_rewards([a])
	_check("ly_floor_bad", float(sd._codexLbEmberWins) == 300.0 and float(sd._codexLbEmber) == 3000.0)
	set_ok.call(true)
	XLiuying.gain_rewards([a])
	_check("ly_floor_ok", float(sd._codexLbEmberWins) == 301.0 and float(sd._codexLbEmber) == 3000.0)
	# 有效余烬
	sd["_codexLbEmberWins"] = 100.0
	sd["_codexLbEmber"] = 1000.0
	_check("ly_ember_low", XLiuying.param_plus(a, 0, 0.0) == 1000.0)
	sd["_codexLbEmberWins"] = 350.0
	sd["_codexLbEmber"] = 3000.0
	_check("ly_ember_l1", XLiuying.param_plus(a, 0, 0.0) == 3500.0, XLiuying.param_plus(a, 0, 0.0))
	sd["_codexLbEmberWins"] = 2100.0
	_check("ly_ember_l24", XLiuying.param_plus(a, 0, 0.0) == 15000.0 and XLiuying.growth_dmg_pct(a) == 24)
	# 伤害：普攻也吃 ×(100＋层)/100
	var atk := XDB.rec("Skills", 1)
	var enemy = null
	_check("ly_dmg_attack", _mul(XLiuying.tq_ops(atk, a, enemy)) == [1.24], _mul(XLiuying.tq_ops(atk, a, enemy)))
	# 戴 4004 满余烬：开着没有 ×1.2，关掉回 ×1.2 且没有层数伤害
	XLiuying._equip_base(s, a, "weapon", XLiuying.WEAPON)
	_check("ly_wear_4004", a.has_base_equip("weapon", XLiuying.WEAPON))
	var rs := XDB.rec("Skills", XLiuying.RANSHAO)
	var on_ops := _mul(XLiuying.tq_ops(rs, a, enemy))
	G.ENABLED = false
	var off_ops := _mul(XLiuying.tq_ops(rs, a, enemy))
	var off_param := XLiuying.param_plus(a, 0, 0.0)
	G.ENABLED = true
	_check("ly_q5_no_1_2", on_ops.size() == 2 and on_ops[0] == 1.24 and off_ops.size() == 1 and is_equal_approx(off_ops[0] / on_ops[1], 1.2), [on_ops, off_ops])
	_check("ly_off_ember", off_param == 3000.0)
	# 关掉时不戴 4004 不记胜场
	G.ENABLED = false
	a.equips[0] = null
	_fresh(a)
	sd["_codexLbEmberWins"] = 10.0
	XLiuying.gain_rewards([a])
	_check("ly_off_needs_4004", float(sd._codexLbEmberWins) == 10.0)
	G.ENABLED = true


func _unrace(s: XState) -> void:
	var n: XActor = s.actor(XNanoha.ACTOR)
	s.flags[XNanoha.ADAPT_FLAG] = {str(XNanoha.ACTOR): float(2000 + 36 * 150)}
	_fresh(n)
	var races: Dictionary = XRace.state(s).actors
	races[str(XNanoha.ACTOR)] = {"race": 2, "rank": 7}  # 人族 ×1.03
	var inner := n.param_before_alien(1)
	var f := G.param_flat(n, 1)
	var before := roundf(inner * 0.5)  # 模拟内层减益压掉一半
	var after := XRaceBattle.param(n, 1, before)
	var got := G.unrace(n, 1, before, after)
	var fe := roundf(f * before / inner)
	var want := XRaceBattle.param(n, 1, before - fe) + fe
	var old_bug := after - roundf(f * (after / before - 1.0))
	_check("unrace_debuff", f > 0.0 and got == want and got > old_bug, [got, want, old_bug])
	var full := G.unrace(n, 1, inner, XRaceBattle.param(n, 1, inner))
	_check("unrace_full", full == XRaceBattle.param(n, 1, inner - f) + f)
	races.erase(str(XNanoha.ACTOR))
	s.flags[XNanoha.ADAPT_FLAG] = {}
	_fresh(n)


func _finale(s: XState) -> void:
	var lg := FakeLogic.new()
	lg.set_meta(XTianqiHorsemen.META, {"line": "war", "mode": "survival"})
	_check("finale_survival", not bool(G.facts(s, lg).finale))
	lg.set_meta(XTianqiHorsemen.META, {"line": "war", "mode": "boss"})
	_check("finale_boss", bool(G.facts(s, lg).finale))
