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
var out_dir := ""


class FakeLogic extends RefCounted:
	var enemies := []
	var troop_id := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
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
	_text(s)
	if out_dir != "" and DisplayServer.get_name() != "headless":
		await _shot(s)
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
	var r_base := float(G.actor_row("raven").base)  # T258：一份、基础段都读 growth.json，不写死
	var r_share := float(G.actor_row("raven").share)
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
	s.raven["soul"] = r_base
	_fresh(r)
	var lo := r.param(4)
	s.raven["soul"] = r_base + 36.0 * r_share
	_fresh(r)
	_check("raven_flat_no_scythe", r.param(4) - lo == 24.0 * N, [r.param(4) - lo, N])
	# P2-2：人族 ×1.03 逐层平加正好 L×N（不差 ±1）
	var races: Dictionary = XRace.state(s).actors
	races[str(XRaven.ACTOR)] = {"race": 2, "rank": 7}
	s.raven["soul"] = r_base
	_fresh(r)
	var base := r.param(4)
	var bad := []
	for L in range(1, 31):
		s.raven["soul"] = r_base + G.cumulative(L) * r_share
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
	var n_base := float(row.base)
	var n_share := float(row.share)
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
	set_n.call(n_base + n_share - 1.0)
	_fresh(n)
	var mmp0 := n.mmp
	XNanoha.adapt(n, 1.0)
	var dirty_want := Y - float(roundi(Y * (n_share - 1.0) / n_share))  # T286：连续层，差一次时已有 Y×(一份−1)/一份 取整
	_check("nanoha_dirty", G.layers_of("nanoha", n) == 1.0 and n.mmp - mmp0 == dirty_want and dirty_want > 0.0, [n.mmp - mmp0, dirty_want])
	# 开关关掉回原版逐次公式
	G.ENABLED = false
	set_n.call(2100)
	mp0 = XParamPlus.bonus(n, 1)
	XNanoha.adapt(n, 1.0)
	_check("nanoha_off", cnt.call() == 2101.0 and is_equal_approx(XParamPlus.bonus(n, 1) - mp0, 30.0 * 2000.0 / 2100.0), XParamPlus.bonus(n, 1) - mp0)
	G.ENABLED = true
	# 存档读写
	set_n.call(n_base + 36.0 * n_share)
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
	var lrow := G.actor_row("liuying")  # T258：一份、基础段、每层余烬都读 growth.json
	var l_base := float(lrow.base)
	var l_share := float(lrow.share)
	var l_ember := float(lrow.ember)
	var l_cap := float(lrow.ember_cap)
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
	sd["_codexLbEmberWins"] = l_base + l_share
	sd["_codexLbEmber"] = 3000.0
	_check("ly_ember_l1", XLiuying.param_plus(a, 0, 0.0) == l_cap + l_ember, XLiuying.param_plus(a, 0, 0.0))
	sd["_codexLbEmberWins"] = l_base + 36.0 * l_share
	_check("ly_ember_l24", XLiuying.param_plus(a, 0, 0.0) == l_cap + 24.0 * l_ember and XLiuying.growth_dmg_pct(a) == 24)
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
	s.flags[XNanoha.ADAPT_FLAG] = {str(XNanoha.ACTOR): float(int(G.actor_row("nanoha").base) + 36 * int(G.actor_row("nanoha").share))}
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


func _card_text(rows: Array) -> String:
	return "\n".join(rows.map(func(r): return str(r[0])))


func _text(s: XState) -> void:
	var r: XActor = s.actor(XRaven.ACTOR)
	var n: XActor = s.actor(XNanoha.ACTOR)
	var a: XActor = s.actor(XLiuying.ACTOR)
	var r_row := G.actor_row(G.RAVEN)
	var n_row := G.actor_row(G.NANOHA)
	var l_row := G.actor_row(G.LIUYING)
	var r_base := float(r_row.base)
	var r_share := float(r_row.share)
	var r_mat := roundi(G.flat_per_layer(G.RAVEN, 4))
	var n_base := float(n_row.base)
	var n_share := float(n_row.share)
	var n_hp := roundi(G.flat_per_layer(G.NANOHA, 0))
	var n_mp := roundi(G.flat_per_layer(G.NANOHA, 1))
	var l_base := float(l_row.base)
	var l_share := float(l_row.share)
	var l_ember := int(l_row.ember)
	var l_dmg1 := G.dmg_pct_of(1)

	# T286（D247）：状态行不再说「第几层」，改「计数 → 加了多少」；括号提示越往后越慢
	var slow := "（越往后涨得越慢）"
	var slow_r := "（超20万起算，越往后涨得越慢）"
	var no_layer := func(t: String) -> bool: return not t.contains("层")
	# 1) 渡鸦状态行：没学 10136 或未到起点空；到起点＋0；半份；拐点；接入 ledger_help
	r.forget_skill(10136)
	s.raven["soul"] = r_base
	_check("txt_raven_no10136", G.status_line(G.RAVEN, r) == "" and XRaven.ledger_help(r, XDB.rec("Skills", 10137)).size() == 2)
	r.learn_skill(10136)
	s.raven["soul"] = r_base - 1.0
	_check("txt_raven_below", G.status_line(G.RAVEN, r) == "")
	s.raven["soul"] = r_base
	var r0 := G.status_line(G.RAVEN, r)
	var r0_want := "冥冠：灵魂 %s → 魔法攻击 +0%s" % [G._fmt_int(roundi(r_base)), slow_r]
	_check("txt_raven_start", r0 == r0_want and no_layer.call(r0), [r0, r0_want])
	s.raven["soul"] = r_base + r_share / 2.0
	var rh := G.status_line(G.RAVEN, r)
	var rh_want := "冥冠：灵魂 %s → 魔法攻击 +%s%s" % [G._fmt_int(floori(r_base + r_share / 2.0)), G._fmt_int(roundi(r_mat * 0.5)), slow_r]
	_check("txt_raven_half", rh == rh_want, [rh, rh_want])
	s.raven["soul"] = r_base + G.cumulative(24) * r_share
	var r24 := G.status_line(G.RAVEN, r)
	var r24_want := "冥冠：灵魂 %s → 魔法攻击 +%s%s" % [G._fmt_int(roundi(r_base + G.cumulative(24) * r_share)), G._fmt_int(24 * r_mat), slow_r]
	var lh := XRaven.ledger_help(r, XDB.rec("Skills", 10137))
	_check("txt_raven_l24", r24 == r24_want and no_layer.call(r24) and lh.size() == 3 and lh[2] == r24, [r24, r24_want, lh])

	# 2) 奈叶状态行：未到起点空；起点＋0；带半次的小数；拐点；接入 5683 说明卡且图鉴 skill_copy=true 不带实时行
	var set_n := func(v): s.flags[XNanoha.ADAPT_FLAG] = {str(XNanoha.ACTOR): float(v)}
	XHelpCard.scene_actor = n
	set_n.call(n_base - 0.5)
	_check("txt_nanoha_below", G.status_line(G.NANOHA, n) == "" and not _card_text(XHelpCard.content(XDB.rec("Skills", 5683), "skill", false, 300.0)).contains("超限适应"))
	set_n.call(n_base)
	var n0 := G.status_line(G.NANOHA, n)
	var n0_want := "超限适应：适应 %s 次 → 额外最大生命 +0、最大魔法 +0%s" % [G._fmt_num(n_base), slow]
	_check("txt_nanoha_start", n0 == n0_want and no_layer.call(n0), [n0, n0_want])
	set_n.call(n_base + 12.5)
	var nh := G.status_line(G.NANOHA, n)
	var nh_l := 12.5 / n_share
	var nh_want := "超限适应：适应 %s 次 → 额外最大生命 +%s、最大魔法 +%s%s" % [G._fmt_num(n_base + 12.5), G._fmt_int(roundi(n_hp * nh_l)), G._fmt_int(roundi(n_mp * nh_l)), slow]
	_check("txt_nanoha_half", nh == nh_want and nh.contains(".5 次"), [nh, nh_want])
	set_n.call(n_base + G.cumulative(24) * n_share)
	var n24 := G.status_line(G.NANOHA, n)
	var n24_want := "超限适应：适应 %s 次 → 额外最大生命 +%s、最大魔法 +%s%s" % [G._fmt_num(n_base + G.cumulative(24) * n_share), G._fmt_int(24 * n_hp), G._fmt_int(24 * n_mp), slow]
	var card_n := _card_text(XHelpCard.content(XDB.rec("Skills", 5683), "skill", false, 300.0))
	var book_n := _card_text(XHelpCard.content(XDB.rec("Skills", 5683), "skill", true, 300.0))
	_check("txt_nanoha_l24", n24 == n24_want and no_layer.call(n24) and card_n.contains(n24) and not book_n.contains("超限适应"), [n24, n24_want])

	# 3) 流萤状态行：未到起点空；起点＋0；一份＝余烬＋ember、伤害 +1%（不含前 3000）；层内小数伤害向下取整；拐点；接入 10624 说明卡
	var sd := a.state_data
	XHelpCard.scene_actor = a
	sd["_codexLbEmberWins"] = l_base - 1.0
	_check("txt_ly_below", G.status_line(G.LIUYING, a) == "" and not _card_text(XHelpCard.content(XDB.rec("Skills", 10624), "skill", false, 300.0)).contains("不熄之火"))
	sd["_codexLbEmberWins"] = l_base
	var l0 := G.status_line(G.LIUYING, a)
	var l0_want := "不熄之火：胜场 %s → 额外余烬生命 +0、伤害 +0%%%s" % [G._fmt_int(roundi(l_base)), slow]
	_check("txt_ly_start", l0 == l0_want and no_layer.call(l0), [l0, l0_want])
	sd["_codexLbEmberWins"] = l_base + l_share
	var l1 := G.status_line(G.LIUYING, a)
	var l1_want := "不熄之火：胜场 %s → 额外余烬生命 +%s、伤害 +%d%%%s" % [G._fmt_int(roundi(l_base + l_share)), G._fmt_int(l_ember), l_dmg1, slow]
	_check("txt_ly_l1_no3000", l1 == l1_want, [l1, l1_want])
	sd["_codexLbEmberWins"] = l_base + l_share + 27.0
	var lm := G.status_line(G.LIUYING, a)
	var lm_l := 1.0 + 27.0 / (G.price(2) * l_share)
	var lm_want := "不熄之火：胜场 %s → 额外余烬生命 +%s、伤害 +%d%%%s" % [G._fmt_int(roundi(l_base + l_share + 27.0)), G._fmt_int(floori(l_ember * lm_l + 1e-9)), l_dmg1, slow]
	_check("txt_ly_mid_floor", lm == lm_want, [lm, lm_want])
	sd["_codexLbEmberWins"] = l_base + G.cumulative(24) * l_share
	var l24 := G.status_line(G.LIUYING, a)
	var l24_want := "不熄之火：胜场 %s → 额外余烬生命 +%s、伤害 +%d%%%s" % [G._fmt_int(roundi(l_base + G.cumulative(24) * l_share)), G._fmt_int(24 * l_ember), G.dmg_pct_of(24), slow]
	var card_l := _card_text(XHelpCard.content(XDB.rec("Skills", 10624), "skill", false, 300.0))
	var book_l := _card_text(XHelpCard.content(XDB.rec("Skills", 10624), "skill", true, 300.0))
	_check("txt_ly_l24", l24 == l24_want and no_layer.call(l24) and card_l.contains(l24) and not book_l.contains("不熄之火"), [l24, l24_want])
	# 卡面说明（skill_rework desc）也不再说「成层／每层」成长
	var c10136_desc := _card_text(XHelpCard.content(XDB.rec("Skills", 10136), "skill", true, 300.0))
	_check("txt_desc_no_layers", not book_n.contains("成层") and not book_l.contains("成层") and not c10136_desc.contains("成层") and book_n.contains("越往后涨得越慢") and c10136_desc.contains("越往后涨得越慢"), [book_n, book_l, c10136_desc])

	# 4) 卡面内容（天启篇）：10136、5683、10624、weapon:4004
	var c10136 := _card_text(XHelpCard.content(XDB.rec("Skills", 10136), "skill", true, 300.0))
	_check("card_10136", c10136.contains("20万") and c10136.contains("魂海刻度") and not c10136.contains("4.25") and not c10136.contains("1.1"), c10136)
	_check("card_5683", book_n.contains("2,000") and book_n.contains("达标楼层") and not book_n.contains("结算伤害*0.05") and not book_n.contains("1-45级"), book_n)
	_check("card_10624", book_l.contains("10 层") and book_l.contains("+3%") and book_l.contains("−5%") and book_l.contains("9 倍火属性") and book_l.contains("300 场") and not book_l.contains("12层") and not book_l.contains("真实伤害") and not book_l.contains("全队生效"), book_l)
	var w4004 := XGear.create("weapon", XLiuying.WEAPON, s)
	var cw := _card_text(XHelpCard.content(w4004, "weapon", false, 300.0))
	var dw := _card_text(XHelpCard.detail_rows(w4004, 300.0))
	_check("card_4004", cw.contains("纪念武器") and dw.contains("纪念武器") and not cw.contains("10000") and not cw.contains("最终伤害") and not cw.contains("基础生命10点") and not dw.contains("10000"), [cw, dw])

	# 5) 西游存档文字零变化
	var xiyou := XState.new_game(2, 1, [8, 9, 10])
	XState.current = xiyou
	var xr := _join(xiyou, XRaven.ACTOR)
	xr.learn_skill(10136)
	xiyou.raven["soul"] = r_base + r_share
	var xn := _join(xiyou, XNanoha.ACTOR)
	xiyou.flags[XNanoha.ADAPT_FLAG] = {str(XNanoha.ACTOR): n_base + n_share}
	var xa := _join(xiyou, XLiuying.ACTOR)
	xa.state_data["_codexLbEmberWins"] = l_base + l_share
	_check("xiyou_status_empty", G.status_line(G.RAVEN, xr) == "" and G.status_line(G.NANOHA, xn) == "" and G.status_line(G.LIUYING, xa) == "")
	_check("xiyou_ledger", XRaven.ledger_help(xr, XDB.rec("Skills", 10137)).size() == 2)
	var x10136 := _card_text(XHelpCard.content(XDB.rec("Skills", 10136), "skill", false, 300.0))
	XHelpCard.scene_actor = xn
	var x5683 := _card_text(XHelpCard.content(XDB.rec("Skills", 5683), "skill", false, 300.0))
	XHelpCard.scene_actor = xa
	var x10624 := _card_text(XHelpCard.content(XDB.rec("Skills", 10624), "skill", false, 300.0))
	var x4004 := _card_text(XHelpCard.content(XGear.create("weapon", XLiuying.WEAPON, xiyou), "weapon", false, 300.0))
	_check("xiyou_cards_untouched", x10136.contains("4.25") and x5683.contains("结算伤害*0.05") and not x5683.contains("超限适应") and x10624.contains("12层") and not x10624.contains("不熄之火") and x4004.contains("每10000最大生命"), [x10136, x5683, x10624, x4004])
	XHelpCard.scene_actor = null
	XState.current = s


func _shot(s: XState) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var shots := [
		["raven_10137", XRaven.ACTOR, 10137],
		["nanoha_5683", XNanoha.ACTOR, 5683],
		["liuying_10624", XLiuying.ACTOR, 10624],
	]
	for item in shots:
		var name := str(item[0])
		var aid := int(item[1])
		var sid := int(item[2])
		var idx := s.party.find(aid)
		if idx < 0:
			continue
		var sc := XSkillScene.new()
		sc.actor_index = idx
		add_child(sc)
		sc.mode = "list"
		var types := sc.types()
		for ti in types.size():
			sc.type_index = ti
			var ents := sc.entries()
			for ei in ents.size():
				if int(ents[ei].get("id", 0)) == sid:
					sc.index = ei
					break
			if sc.index < ents.size() and int(ents[sc.index].get("id", 0)) == sid:
				break
		sc._refresh()
		if sc.skin != null:
			sc.skin._sync_card(sc.actor())
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		var ok := get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK
		_check("shot_" + name, ok)
		sc.queue_free()
		await get_tree().process_frame
