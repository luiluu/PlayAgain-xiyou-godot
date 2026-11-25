extends Node
## 【cc·T514】天启篇七境境底＋境支（XTianqiBrandRealm；T013 3A，养成线 v0.3 第三节第 5 条、烙印 v0.6 第四节第 5 条）：
## 一、表：七行境底、六境 19 支（逆命本线支 hidden，摆出来 18 支）、数是整数；九条带攻境支去攻（任何选法物攻、魔攻倍率都是 1）。
## 二、属性：守一生命 +5%；逆命默认支逐项对；迎劫生命 +8%（D129）。
## 三、换伤支：四条全选 K 那一项 ×1.12；承伤池 铸骨、真形 −10%、四条 +12%、破防 +30% 相加。
## 四、生存：不染减益 10% 不中、砥柱低血受疗 +15%、迎劫大伤三成、逆命每场一次回 20%。
## 五、换支：第一次免费、之后花钱（钱不够不换）、hidden／没立到的不让选；闭关菜单一览、立境后当场选。
## 六、存档：选过的支来回不丢；西游档、开关关着一律没有。

const XIAOYAO := 1
const LVSIJI := 2

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	seed(20261125)
	XTianqiBase.clear_cache()
	XTianqiBrand.clear_cache()
	_check("default_on", XTianqiBrandRealm.ENABLED and XTianqiBrand.ENABLED, [XTianqiBrandRealm.ENABLED, XTianqiBrand.ENABLED])
	_table()
	_params()
	_trade()
	_survive()
	_swap()
	_save()
	_off()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _state(tianqi := true) -> XState:
	var w := XTianqiSkills.ids(XTier.WEAK, true).filter(func(id): return id != LVSIJI)
	var lineup := [XIAOYAO, LVSIJI, w[0], w[1], w[2]]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, "jianxian", lineup)
		XTianqi.take_pending()
	else:
		s = XState.new()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	return s


func _setr(a: XActor, realm: int, brand := -1) -> void:
	XZhenqi.data(a)
	a.zhenqi["brand_realm"] = realm
	a.zhenqi["brand"] = XTianqiBrand.node_of(realm) if brand < 0 else brand
	a.zhenqi["brand_carved"] = 1
	a.zhenqi.erase(XTianqiBrandRealm.KEY)


func _pick_all(a: XActor, keys: Dictionary) -> void:
	var bb := {}
	for r in keys:
		bb[str(r)] = str(keys[r])
	XZhenqi.data(a)[XTianqiBrandRealm.KEY] = bb


func _rate_ratio(a: XActor, i: int) -> float:
	var on := a.param_rate(i)
	XTianqiBrandRealm.ENABLED = false
	var off := a.param_rate(i)
	XTianqiBrandRealm.ENABLED = true
	return on / off if off != 0.0 else 0.0


func _table() -> void:
	var d := XTianqiBrandRealm.data()
	var base: Array = d.get("base", [])
	_check("table.base7", base.size() == 7 and base.map(func(b): return str(b.realm)) == XTianqiBrand.data().nodes.realms)
	var total := 0
	var shown := 0
	var ints := true
	for r in range(1, 7):
		total += XTianqiBrandRealm.all_branches(r).size()
		shown += XTianqiBrandRealm.branches(r).size()
	for b in base:
		for k in b.get("params", {}):
			ints = ints and typeof(b.params[k]) in [TYPE_INT, TYPE_FLOAT] and float(b.params[k]) == floorf(float(b.params[k]))
	_check("table.19", total == 19 and shown == 18, [total, shown])
	_check("table.int", ints and int(d.get("branch_pct", 0)) == 3)
	_check("table.no_branch_shouyi", XTianqiBrandRealm.all_branches(0).is_empty())
	# 九条带攻的去攻（D129）：所有支的属性里都没有物攻、魔攻；四条换伤支（D145）
	var atk := 0
	var trade := []
	for r in range(1, 7):
		for b in XTianqiBrandRealm.all_branches(r):
			atk += Array(b.get("params", [])).filter(func(k): return k == "atk" or k == "mat").size()
			if bool(b.get("trade", false)):
				trade.append(str(b.name))
	_check("table.no_atk", atk == 0, atk)
	_check("table.trade4", trade == ["锋骨", "化刃", "劫火", "开印"], trade)


func _params() -> void:
	var s := _state()
	var a: XActor = s.battle_members()[0]
	_setr(a, 0)
	_check("param.shouyi_hp", absf(_rate_ratio(a, 0) - 1.05) < 1e-6, _rate_ratio(a, 0))
	_check("param.shouyi_other", absf(_rate_ratio(a, 2) - 1.0) < 1e-6 and absf(_rate_ratio(a, 5) - 1.0) < 1e-6)
	# 逆命、默认支（每境第一条：涤尘 魔防生命、金骨 物防生命、不移 物防魔防、定形 生命魔防、迎锋 物防生命、逆鳞 生命物防）
	_setr(a, 6)
	var want := {0: 1.0 + (5 + 3 * 4 + 8 + 3 + 3 * 5) / 100.0, 1: 1.05, 2: 1.0, 3: 1.0 + (5 + 3 * 4) / 100.0, 4: 1.0, 5: 1.0 + (5 + 3 * 3) / 100.0, 6: 1.05, 7: 1.05}
	var got := {}
	var ok := true
	for i in 8:
		got[i] = snappedf(XTianqiBrandRealm.param_rate(a, i), 0.0001)
		ok = ok and absf(XTianqiBrandRealm.param_rate(a, i) - float(want[i])) < 1e-6
	_check("param.niming_default", ok, [got, want])
	_check("param.chain", absf(_rate_ratio(a, 0) - float(want[0])) < 1e-6, _rate_ratio(a, 0))
	# 迎劫这一境自己：生命 +8%（3＋D129 的 5），没有物攻魔攻
	_setr(a, 5)
	var r4 := XTianqiBrandRealm.param_rate(a, 0)
	_setr(a, 4)
	_check("param.yingjie_hp8", absf(r4 - XTianqiBrandRealm.param_rate(a, 0) - 0.08 - 0.03) < 1e-6, [r4, XTianqiBrandRealm.param_rate(a, 0)])
	# 穷举所有选法：物攻、魔攻倍率都是 1
	_setr(a, 6)
	var flat := true
	for r in range(1, 7):
		for b in XTianqiBrandRealm.all_branches(r):
			_pick_all(a, {r: b.key})
			flat = flat and XTianqiBrandRealm.param_rate(a, 2) == 1.0 and XTianqiBrandRealm.param_rate(a, 4) == 1.0
	_check("param.no_atk_any_pick", flat)


func _fight(s: XState) -> XBattleLogic:
	var lg := XBattleLogic.new()
	lg.setup(1, s)
	return lg


func _trade() -> void:
	var s := _state()
	var lg := _fight(s)
	var a: XActor = lg.actors[0]
	_setr(a, 6)
	var k0 := XTianqiBase.k_for(a, s)
	var t0 := XTianqiBrand.taken_mult(a)
	_check("trade.taken_base", absf(t0 - 0.9) < 1e-6, t0)  # 铸骨 −5%、真形 −5%
	_pick_all(a, {2: "fenggu", 4: "huaren", 5: "jiehuo", 6: "kaiyin"})
	_check("trade.dealt", absf(XTianqiBrandRealm.dealt_mult(a, s) - 1.12) < 1e-6 and absf(XTianqiBase.k_for(a, s) / k0 - 1.12) < 1e-6, [XTianqiBrandRealm.dealt_mult(a, s), XTianqiBase.k_for(a, s) / k0])
	_check("trade.taken", absf(XTianqiBrand.taken_mult(a) - 1.02) < 1e-6, XTianqiBrand.taken_mult(a))
	XTianqiBrand.fight(lg)["guard_break"] = {a: int(lg.turn)}
	_check("trade.with_break_guard", absf(XTianqiBrand.taken_mult(a) - 1.32) < 1e-6, XTianqiBrand.taken_mult(a))  # 同池相加
	XTianqiBrand.fight(lg).erase("guard_break")
	# 只选一条：×1.03；不刻印、停铸骨只能选锋骨（境到 2）
	_setr(a, 2, 4000)
	_pick_all(a, {2: "fenggu"})
	_check("trade.one", absf(XTianqiBrandRealm.dealt_mult(a, s) - 1.03) < 1e-6 and absf(XTianqiBrand.taken_mult(a) - 0.98) < 1e-6, [XTianqiBrandRealm.dealt_mult(a, s), XTianqiBrand.taken_mult(a)])
	lg.end_battle()
	_check("trade.taken_outside", XTianqiBrand.taken_mult(a) == 1.0)


func _harmful() -> int:
	for id in range(2, 60):
		if XSmartAI.harmful_state(id) and not XDB.rec("States", id).is_empty():
			return id
	return -1


func _survive() -> void:
	var s := _state()
	var lg := _fight(s)
	var a: XActor = lg.actors[0]
	var hid := _harmful()
	_setr(a, 0)
	var off := lg.state_rate(a, hid)
	_setr(a, 1)
	_check("buran.state", hid > 0 and absf(XTianqiBrandRealm.state_rate(a, hid) - 0.9) < 1e-6 and absf(lg.state_rate(a, hid) - off * 0.9) < 1e-6, [hid, off, lg.state_rate(a, hid)])
	_check("buran.death_untouched", XTianqiBrandRealm.state_rate(a, 1) == 1.0)
	_check("buran.debuff", absf(XTianqiBrandRealm.debuff_rate(a) - 0.9) < 1e-6)
	# 砥柱：低于一半 +15%，一半以上照常
	_setr(a, 3, 4000)  # 刚立砥柱、烙印 40% 没超过：不吃虚不受补
	a.hp = floorf(a.mhp * 0.4)
	var low := XTianqiBrand.heal(a, 100.0)
	a.hp = floorf(a.mhp * 0.6)
	var high := XTianqiBrand.heal(a, 100.0)
	_check("dizhu.low_heal", low == 115.0 and high == 100.0, [low, high])
	_setr(a, 2)
	a.hp = floorf(a.mhp * 0.4)
	_check("dizhu.not_yet", XTianqiBrand.heal(a, 100.0) == 100.0)
	# 迎劫：0.8 最大生命 → 0.5 ＋ 0.3×0.7 ＝ 0.71；一半以内不动
	_setr(a, 5)
	a.hp = a.mhp
	var m := a.mhp
	var big := XTianqiBrandRealm.big_hit(lg, a, m * 0.8)
	_check("yingjie.big_hit", absf(big - (m * 0.8 - floorf(m * 0.3 * 0.3))) < 1e-6 and XTianqiBrandRealm.big_hit(lg, a, m * 0.5) == m * 0.5, [m, big])
	_setr(a, 4)
	_check("yingjie.not_yet", XTianqiBrandRealm.big_hit(lg, a, m * 0.8) == m * 0.8)
	# 迎劫接在 execute_hp_damage 里（行动外直接调：照 xiyou_boss_output 给一份资源账）
	lg._action_resources = lg._new_lifecycle_resources()
	_setr(a, 5)
	a.hp = a.mhp
	var before := a.hp
	lg.execute_hp_damage(lg.enemies[0], a, floorf(a.mhp * 0.8), false)
	var lost := before - a.hp
	_check("yingjie.real", lost < floorf(a.mhp * 0.8) and lost > floorf(a.mhp * 0.5), [lost, a.mhp])
	# 逆命：掉到三成以下回 20%，每场一次
	_setr(a, 6)
	a.hp = a.mhp
	lg.execute_hp_damage(lg.enemies[0], a, floorf(a.mhp * 0.9), false)
	var after1 := a.hp
	var mhp := a.mhp
	_check("niming.rally", after1 > mhp * 0.15 and after1 >= floorf(mhp * 0.2), [after1, mhp])
	a.hp = floorf(mhp * 0.5)
	lg.execute_hp_damage(lg.enemies[0], a, floorf(mhp * 0.4), false)
	_check("niming.once", a.hp < mhp * 0.3, [a.hp, mhp])
	lg.end_battle()


func _swap() -> void:
	var s := _state()
	var a: XActor = s.battle_members()[0]
	_setr(a, 3)
	s.gold = 0
	var pre := XTianqiBrandRealm.price(s, a, 2)
	_check("swap.first_free", pre == 0 and XTianqiBrandRealm.choose(s, a, 2, "suihuo") == "" and XTianqiBrandRealm.branch_of(a, 2).key == "suihuo", pre)
	var p := XTianqiBrandRealm.price(s, a, 2)
	_check("swap.price_positive", p > 0, p)
	_check("swap.poor", XTianqiBrandRealm.choose(s, a, 2, "jingu") != "" and XTianqiBrandRealm.branch_of(a, 2).key == "suihuo")
	s.gold = p + 7
	_check("swap.paid", XTianqiBrandRealm.choose(s, a, 2, "jingu") == "" and int(s.gold) == 7 and XTianqiBrandRealm.branch_of(a, 2).key == "jingu", s.gold)
	_check("swap.same_free", XTianqiBrandRealm.choose(s, a, 2, "jingu") == "" and int(s.gold) == 7)
	_check("swap.not_reached", XTianqiBrandRealm.choose(s, a, 4, "dingxing") != "")
	_setr(a, 6)
	_check("swap.hidden", XTianqiBrandRealm.choose(s, a, 6, "benxian") != "" and XTianqiBrandRealm.branches(6).size() == 3)
	# 闭关菜单：人物页有「加深分支」、一览列到立到的段、选完回一览
	var page := XZhenqi.menu(s, {"page": "actor", "id": a.actor_id})
	var labels: Array = page.get("options", []).map(func(o): return str(o.label))
	_check("menu.entry", labels.any(func(l): return l.begins_with("加深分支")), labels)
	var lst := XZhenqi.menu(s, {"page": "branch", "id": a.actor_id})
	_check("menu.list", lst.options.size() == 7, lst.options.size())
	var pk := XZhenqi.menu(s, {"page": "branch_pick", "id": a.actor_id, "r": 1})
	_check("menu.pick", pk.options.size() == 4 and str(pk.lines[1]).contains("免费"), pk)
	var st := XZhenqi.menu(s, {"page": "branch_set", "id": a.actor_id, "r": 1, "k": "qingxin"})
	_check("menu.set", XTianqiBrandRealm.branch_of(a, 1).key == "qingxin" and st.next.page == "branch", st)
	# 打赢心魔：立入下一段后当场到选分支
	_setr(a, 1)
	XZhenqi.trial_done = {"actorId": a.actor_id, "target": 2, "won": true, "brand": true}
	var te := XZhenqi.menu(s, {"page": "trial_end"})
	_check("menu.after_stand", XTianqiBrand.realm(a) == 2 and te.get("next", {}).get("page") == "branch_pick" and int(te.next.r) == 2, te)
	# 不染这一段不显示的西游档
	var ox := _state(false)
	var b: XActor = ox.battle_members()[0]
	_check("menu.xiyou", XTianqiBrandRealm.choose(ox, b, 1, "dichen") != "" and not b.zhenqi.has(XTianqiBrandRealm.KEY))


func _save() -> void:
	var s := _state()
	var a: XActor = s.battle_members()[0]
	_setr(a, 6)
	_pick_all(a, {1: "qingxin", 6: "wentian"})
	var back := XZhenqi.from_save(JSON.parse_string(JSON.stringify(a.zhenqi)))
	_check("save.roundtrip", back.get(XTianqiBrandRealm.KEY) == {"1": "qingxin", "6": "wentian"} and int(back.brand_realm) == 6, back.get(XTianqiBrandRealm.KEY))
	var plain := XZhenqi.from_save({"qi": 5, "realm": 2})
	_check("save.no_new_key", not plain.has(XTianqiBrandRealm.KEY))


func _off() -> void:
	var s := _state()
	var lg := _fight(s)
	var a: XActor = lg.actors[0]
	_setr(a, 6)
	_pick_all(a, {2: "fenggu"})
	XTianqiBrandRealm.ENABLED = false
	var ok := XTianqiBrandRealm.param_rate(a, 0) == 1.0 and XTianqiBrandRealm.dealt_mult(a, s) == 1.0 and XTianqiBrandRealm.taken_add(a) == 0.0 \
		and XTianqiBrandRealm.debuff_rate(a) == 1.0 and XTianqiBrandRealm.big_hit(lg, a, a.mhp * 0.9) == a.mhp * 0.9
	var labels: Array = XZhenqi.menu(s, {"page": "actor", "id": a.actor_id}).get("options", []).map(func(o): return str(o.label))
	_check("off.all_one", ok and not labels.any(func(l): return l.begins_with("加深分支")), labels)
	XTianqiBrandRealm.ENABLED = true
	lg.end_battle()
	# 西游档：同样的数据一律没有
	var x := _state(false)
	var b: XActor = x.battle_members()[0]
	_setr(b, 6)
	_check("off.xiyou", XTianqiBrandRealm.param_rate(b, 0) == 1.0 and XTianqiBrandRealm.dealt_mult(b, x) == 1.0 and XTianqiBrandRealm.taken_add(b) == 0.0)
