extends Node
## 【cc·T117】天启篇烙印本体（XTianqiBrand，稿《天启篇_烙印 v0.5》第十三节 T073-b 验收）：
## 一、开关关着：mult 恒 1、K 那一项不变、不认这一场、不结算、闭关菜单照真气；西游档、天启篇档读出来再存回去逐字节不变（没有烙印键时不新建）。
## 二、开着：第十一节第 1 步（烙印 0 和 100% 对木桩 1.50 倍，七个节点逐个对）；存档带着三个角色键和首胜表来回。
## 三、专项 1～7（稿第十三节 T073-b 验收）；P2-2 甲二门禁；P2-3 正序撞节点高亮＋「烙印已到瓶颈」；P2-4 36 层首通那一场刻印者正好 95%。
## 四、端到端：真的 BattleLogic.setup 守层者敌群认出 guardian:<层>；grant 里接着 settle。

const XIAOYAO := 1
const LVSIJI := 2

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	seed(20261117)
	XTianqiSkills.reload()
	XTianqiBase.clear_cache()
	XTianqiBrand.clear_cache()
	XGojo.unlock_override = 0
	_check("default_off", not XTianqiBrand.ENABLED)
	_off()
	XTianqiBrand.ENABLED = true
	_power()
	_save_on()
	_t1_node_stall()
	_t2_line_cap()
	_t3_keys()
	_t4_not_boss()
	_t5_tier()
	_t6_assist()
	_t7_uncarved()
	_p24_climb()
	_e2e()
	_qiyin_real()
	XTianqiBrand.ENABLED = false
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _state(tianqi := true, diff := "jianxian") -> XState:
	var w := XTianqiSkills.ids(XTier.WEAK, true).filter(func(id): return id != LVSIJI)
	var lineup := [XIAOYAO, LVSIJI, w[0], w[1], w[2]]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, diff, lineup)
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


func _setb(a: XActor, brand: int, realm := 0, carved := true) -> void:
	XZhenqi.data(a)
	a.zhenqi["brand"] = brand
	a.zhenqi["brand_realm"] = realm
	a.zhenqi["brand_carved"] = 1 if carved else 0


func _logic(s: XState, c: Dictionary) -> XBattleLogic:
	var lg := XBattleLogic.new()
	lg.state = s
	lg.actors = s.battle_members()
	var cc := c.duplicate(true)
	cc["tier"] = int(cc.get("tier", 1))
	if not cc.has("fills"):
		cc["fills"] = {}
	lg.set_meta(XTianqiBrand.META, cc)
	return lg


func _boss(key: String, first_floor := 0, tier := 1) -> Dictionary:
	return {"kind": "boss", "key": key, "first_floor": first_floor, "tier": tier}


func _dmg(a: XActor) -> float:
	var t := 0.0
	for i in 20:
		var res := XDamage.calculate(XDB.rec("Skills", 1), a, XEnemy.new().setup(1, 3, 100.0), {"critical": false, "variance": false})
		t += float(res.value)
	return t / 20.0


## 读出来再存回去逐字节不变：存过一次的档（JSON 里整数已是浮点）再读再存，字节不变；角色的真气那份和第一次存的一样
func _save_roundtrip(s: XState) -> bool:
	var first := JSON.stringify(s.to_dict())
	var a := JSON.stringify(XState.from_dict(JSON.parse_string(first)).to_dict())
	var b := JSON.stringify(XState.from_dict(JSON.parse_string(a)).to_dict())
	var p1 = JSON.parse_string(first)
	var p2 = JSON.parse_string(a)
	for i in p1.actors:
		var r1 = p1.actors[i]
		var r2 = p2.actors.get(i)
		if (r1 is Dictionary) != (r2 is Dictionary) or (r1 is Dictionary and JSON.stringify(r1.get("zhenqi")) != JSON.stringify(r2.get("zhenqi"))):
			print("ZHENQI_DIFF ", r1, " VS ", r2)
			return false
	if a != b:
		var i := 0
		while i < mini(a.length(), b.length()) and a[i] == b[i]:
			i += 1
		print("ROUNDTRIP_DIFF ", a.substr(maxi(0, i - 80), 200), "\n  VS ", b.substr(maxi(0, i - 80), 200))
	return a == b


func _menu_labels(m: Dictionary) -> Array:
	return m.get("options", []).map(func(o): return str(o.label))


# ---- 一、关着 ----
func _off() -> void:
	XTianqiBrand.ENABLED = false
	var s := _state()
	var a: XActor = s.actors[XIAOYAO]
	var k0 := XTianqiBase.k_for(a, s)
	var p0 := XTianqiCombat.dealt_parts(a, s)
	_setb(a, 10000, 6)
	_check("off.mult", XTianqiBrand.mult(a, s) == 1.0 and XTianqiBase.k_for(a, s) == k0)
	_check("off.dealt", JSON.stringify(XTianqiCombat.dealt_parts(a, s)) == JSON.stringify(p0))
	var lg := XBattleLogic.new()
	lg.setup(39, s)
	_check("off.no_meta", not lg.has_meta(XTianqiBrand.META))
	_check("off.settle", XTianqiBrand.settle(_logic(s, _boss("guardian:6", 6))).is_empty() and int(a.zhenqi.brand) == 10000)
	var page := XZhenqi.menu(s, {"page": "actor", "id": XIAOYAO})
	_check("off.menu_qi", str(page.lines[1]).begins_with("真气"), page.lines)
	# 西游档：没有烙印键时读出来再存回去逐字节不变，不新建
	var x := _state(false)
	XZhenqi.data(x.actors[XIAOYAO]).qi = 777
	x.actors[XIAOYAO].zhenqi.firsts["normal:3"] = 1
	_check("off.xiyou_roundtrip", _save_roundtrip(x))
	var x2 := XState.from_dict(JSON.parse_string(JSON.stringify(x.to_dict())))
	_check("off.xiyou_no_keys", XZhenqi.BRAND_KEYS.all(func(k): return not x2.actors[XIAOYAO].zhenqi.has(k)))
	# 天启篇档关着：同样来回不变（这里带着烙印键也原样留）
	_check("off.tianqi_roundtrip", _save_roundtrip(s))
	var s2 := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	_check("off.keys_kept", int(s2.actors[XIAOYAO].zhenqi.get("brand", -1)) == 10000 and int(s2.actors[XIAOYAO].zhenqi.get("brand_realm", -1)) == 6)
	_check("off.no_section", XTianqiSave.peek(s2, "brand") == null)


# ---- 二、力量两端（第十一节第 1 步） ----
func _power() -> void:
	var s := _state()
	var a: XActor = s.actors[XIAOYAO]
	_setb(a, 0, 6)
	var d0 := _dmg(a)
	_setb(a, 10000, 6)
	var d100 := _dmg(a)
	_check("power.ends_1.50", d0 > 0.0 and absf(d100 / d0 - 1.5) <= 0.005, [d0, d100])
	var ok := true
	var bad := []
	for r in 7:
		var n := XTianqiBrand.node_of(r)
		_setb(a, n, r)
		var want := 1.0 + 0.5 * n / 10000.0
		if not is_equal_approx(XTianqiBrand.mult(a, s), want) or absf(_dmg(a) / d0 - want) > 0.005:
			ok = false
			bad.append([r, n, _dmg(a) / d0])
	_check("power.nodes", ok, bad)
	_check("power.k_slot", is_equal_approx(float(XTianqiCombat.dealt_parts(a, s).k), XTianqiBase.k_base(s) * XTianqiBrand.mult(a, s)))
	var e := XEnemy.new().setup(1, 3, 100.0)
	_check("power.enemy_1", XTianqiBrand.mult(e, s) == 1.0)
	var x := _state(false)
	_setb(x.actors[XIAOYAO], 10000, 6)
	_check("power.xiyou_1", XTianqiBrand.mult(x.actors[XIAOYAO], x) == 1.0)


func _save_on() -> void:
	var s := _state()
	var a: XActor = s.actors[XIAOYAO]
	_setb(a, 2500, 1)
	XTianqiBrand.settle(_logic(s, _boss("guardian:1", 1)))
	_check("save.firsts", int(XTianqiBrand.firsts(s).get("guardian:1", 0)) == 1)
	_check("save.roundtrip", _save_roundtrip(s))
	var s2 := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	_check("save.loaded", XTianqiBrand.firsts(s2).has("guardian:1") and XTianqiBrand.value(s2.actors[XIAOYAO]) == XTianqiBrand.value(a))


# ---- 专项 1：到节点后再打 10 场不变，打赢心魔后接着涨 ----
func _t1_node_stall() -> void:
	var s := _state()
	var a: XActor = s.actors[XIAOYAO]
	_setb(a, 1000, 0)
	XTianqiSave.section(s, "brand").firsts = {"guardian:1": 1, "guardian:2": 1, "guardian:3": 1, "guardian:4": 1, "guardian:5": 1, "guardian:6": 1, "guardian:7": 1}
	XTianqiBrand.toasts.clear()
	for i in 10:
		XTianqiBrand.settle(_logic(s, _boss("guardian:6", 6)))
	_check("t1.stall_10", XTianqiBrand.value(a) == 1000, XTianqiBrand.value(a))
	_check("t1.no_gain_toast", XTianqiBrand.toasts.any(func(t): return str(t).contains("未再增长")), XTianqiBrand.toasts)
	_check("t1.stand", XTianqiBrand.stand(a) and XTianqiBrand.realm(a) == 1)
	XTianqiBrand.settle(_logic(s, _boss("guardian:6", 6)))
	_check("t1.grows_after", XTianqiBrand.value(a) > 1000, XTianqiBrand.value(a))
	_check("t1.no_double_stand", not XTianqiBrand.stand(a))


# ---- 专项 2：没通关 36 层、已在层线上的人再打 100 场不变 ----
func _t2_line_cap() -> void:
	var s := _state()
	var a: XActor = s.actors[XIAOYAO]
	var f := {}
	for i in range(1, 21):
		f["guardian:%d" % i] = 1
	XTianqiSave.section(s, "brand").firsts = f
	_setb(a, XTianqiBrand.line_at(20), 4)
	_check("t2.line20", XTianqiBrand.line_at(20) == 5500)
	for i in 100:
		XTianqiBrand.settle(_logic(s, _boss("guardian:12", 12)))
	_check("t2.stay_100", XTianqiBrand.value(a) == 5500, XTianqiBrand.value(a))


# ---- 专项 3：战斗键不撞 ----
func _t3_keys() -> void:
	var c33 := XTianqiBrand.classify({"guardian_floor": 33})
	var c34 := XTianqiBrand.classify({"summit": true, "guardian_floor": 0})
	_check("t3.keys_33_34", str(c33.key) == "guardian:33" and str(c34.key) == "summit:34" and int(c34.first_floor) == 34)
	var s := _state()
	XTianqiSave.section(s, "brand").firsts = {"guardian:33": 5, "guardian:6": 5, "shadow:war": 5, "ev:120:3:400": 5}
	c34["tier"] = 1
	_check("t3.summit_raw", not XTianqiBrand.is_ripe(s, c34))
	# 36 层骑士借 6 层哥布林的敌群：守层者层号也认出来，但骑士先认
	var ch := XTianqiBrand.classify({"horse_line": "war", "horse_mode": "body", "guardian_floor": 6})
	var cs := XTianqiBrand.classify({"horse_line": "war", "horse_mode": "shadow", "guardian_floor": 6})
	ch["tier"] = 1
	_check("t3.horseman_key", str(ch.key) == "horseman:war" and int(ch.first_floor) == 36 and str(cs.key) == "shadow:war" and int(cs.first_floor) == 35)
	_check("t3.horseman_raw", not XTianqiBrand.is_ripe(s, ch))
	var cq := XTianqiBrand.classify({"qiyin_seal": "seal1", "enemy_names": ["【首领】x"], "map": 120, "event": 3, "troop": 400})
	cq["tier"] = 1
	_check("t3.qiyin_raw", str(cq.key) == "qiyin:seal1" and not XTianqiBrand.is_ripe(s, cq))
	var cev := XTianqiBrand.classify({"enemy_names": ["【首领】x"], "map": 120, "event": 3, "troop": 400})
	cev["tier"] = 1
	_check("t3.ev_ripe", str(cev.key) == "ev:120:3:400" and XTianqiBrand.is_ripe(s, cev))
	var cev2 := XTianqiBrand.classify({"enemy_names": ["【被封印者】y"], "map": 120, "event": 3, "troop": 401})
	cev2["tier"] = 1
	_check("t3.ev_other_raw", not XTianqiBrand.is_ripe(s, cev2))
	_check("t3.survival_none", str(XTianqiBrand.classify({"horse_line": "war", "horse_mode": "survival"}).kind) == "none")
	_check("t3.dragon", str(XTianqiBrand.classify({"dragon": true, "guardian_floor": 19}).key) == "qiyin_dragon")


# ---- 专项 4：主席、研究员、【前所未见】、【精英】、心魔、五条悟试炼打赢后不变、不进首胜表 ----
func _t4_not_boss() -> void:
	var cases := {
		"chair": {"enemy_ids": [745], "enemy_names": ["【副本协会】主席"]},
		"chair2": {"enemy_ids": [752], "enemy_names": ["【首领】借名"]},
		"researcher": {"enemy_ids": [893], "enemy_names": ["天道研究员"]},
		"unseen": {"enemy_ids": [1], "enemy_names": ["【前所未见】嘤嘤怪"]},
		"elite": {"enemy_ids": [1], "enemy_names": ["【精英】嘤嘤怪"]},
		"weapon_trial": {"enemy_names": ["【神兵】x"]},
		"heart": {"heart": true, "guardian_floor": 6},
		"gojo": {"gojo": true, "enemy_names": ["【首领】甚尔"]},
		"weapon": {"weapon": true},
	}
	var s := _state()
	var a: XActor = s.actors[XIAOYAO]
	_setb(a, 0, 6)
	XTianqiSave.section(s, "brand").firsts = {"guardian:30": 1}
	for k in cases:
		var c := XTianqiBrand.classify(cases[k])
		var want := "special" if ["heart", "gojo", "weapon"].has(k) else "none"
		_check("t4.kind_" + k, str(c.kind) == want, c)
		c["tier"] = 1
		XTianqiBrand.settle(_logic(s, c))
	_check("t4.no_gain", XTianqiBrand.value(a) == 0, XTianqiBrand.value(a))
	_check("t4.no_firsts", XTianqiBrand.firsts(s).keys() == ["guardian:30"], XTianqiBrand.firsts(s))
	_check("t4.special_raw", not XTianqiBrand.is_ripe(s, {"kind": "special"}) and XTianqiBrand.is_ripe(s, {"kind": "none"}))
	_check("t4.boss_prefix", str(XTianqiBrand.classify({"enemy_names": ["【旧古神】z"]}).kind) == "boss" and str(XTianqiBrand.classify({"enemy_names": ["【古神】z"]}).kind) == "boss")


# ---- 专项 5：低档打赢过的，换高档还是生的；大厅、七印读到的档位是 1 ----
func _t5_tier() -> void:
	var s := _state()
	XTianqiSave.section(s, "brand").firsts = {"ev:200:5:300": 1}
	var c := XTianqiBrand.classify({"enemy_names": ["【首领】b"], "map": 200, "event": 5, "troop": 300})
	c["tier"] = 3
	_check("t5.higher_raw", not XTianqiBrand.is_ripe(s, c), [c, XTianqiBrand.firsts(s)])
	c["tier"] = 1
	_check("t5.same_ripe", XTianqiBrand.is_ripe(s, c))
	s.set_variable(XDungeon.VAR_TIER, 4)
	s.set_variable(XDungeon.VAR_INSIDE, 0)
	_check("t5.outside_1", XTianqiBrand.tier_of(s) == 1)
	s.set_variable(XDungeon.VAR_INSIDE, 1)
	_check("t5.inside_tier", XTianqiBrand.tier_of(s) == 4)
	XTianqiBrand.settle(_logic(s, _boss("ev:200:5:300", 0, 4)))
	_check("t5.records_max", int(XTianqiBrand.firsts(s)["ev:200:5:300"]) == 4)
	XTianqiBrand.settle(_logic(s, _boss("ev:200:5:300", 0, 2)))
	_check("t5.keeps_max", int(XTianqiBrand.firsts(s)["ev:200:5:300"]) == 4)
	s.set_variable(XDungeon.VAR_INSIDE, 0)


# ---- 专项 6：最低难度助力位再打一场正好 +13 万分点 ----
func _t6_assist() -> void:
	var s := _state(true, "xunchang")
	var h := s.helper()
	_check("t6.has_helper", h != null)
	if h == null:
		return
	XTianqiSave.section(s, "brand").firsts = {"horseman:war": 1, "guardian:3": 1}
	_setb(h, 9500, 6)
	var out := XTianqiBrand.settle(_logic(s, _boss("guardian:3", 3)))
	_check("t6.plus13", XTianqiBrand.value(h) == 9513, [XTianqiBrand.value(h), out])
	var a: XActor = s.battle_members()[0]
	_setb(a, 9500, 6)
	XTianqiBrand.settle(_logic(s, _boss("guardian:3", 3)))
	_check("t6.fighter_plus25", XTianqiBrand.value(a) == 9525, XTianqiBrand.value(a))


# ---- 专项 7＋P2-2：不刻印、铸骨、烙印 40% ----
func _t7_uncarved() -> void:
	var s := _state()
	var a: XActor = s.actors[XIAOYAO]
	_setb(a, 0, 2, false)
	var d0 := _dmg(a)
	_setb(a, 4000, 2, false)
	_check("t7.dmg_1.20", absf(_dmg(a) / d0 - 1.2) <= 0.005, _dmg(a) / d0)
	_check("t7.gate_closed", XTianqiBrand.at_node(a) and not XTianqiBrand.can_stand(a))
	var p := XTianqiBrand.panel(s, a)
	_check("t7.no_plus", not bool(p.plus) and not str(p.text).contains("+") and int(p.sealed_from) == 4000, p)
	_check("t7.bar_sealed", XTianqiBrand.bar_text(s, a).contains("×") and not XTianqiBrand.bar_text(s, a).contains("‖"), XTianqiBrand.bar_text(s, a))
	var page := XZhenqi.menu(s, {"page": "actor", "id": XIAOYAO})
	_check("t7.no_entry", not _menu_labels(page).has("挑战心魔") and _menu_labels(page).has("进行刻印"), _menu_labels(page))
	_check("t7.trial_refused", not XZhenqi.menu(s, {"page": "trial", "id": XIAOYAO}).has("battle"))
	# 不刻印的封顶 40%：烙实也不越过
	XTianqiSave.section(s, "brand").firsts = {"horseman:war": 1}
	_setb(a, 3990, 2, false)
	XTianqiBrand.settle(_logic(s, _boss("guardian:5", 5).merged({"fills": {XIAOYAO: 2}})))
	_check("t7.cap40", XTianqiBrand.value(a) == 4000, XTianqiBrand.value(a))
	var confirm := XZhenqi.menu(s, {"page": "carve", "id": XIAOYAO})
	_check("t7.carve_confirm", not XTianqiBrand.carved(a) and _menu_labels(confirm).has("刻印"))
	XZhenqi.menu(s, {"page": "carve", "id": XIAOYAO, "ok": true})
	_check("t7.carved", XTianqiBrand.carved(a) and XTianqiBrand.can_stand(a))
	page = XZhenqi.menu(s, {"page": "actor", "id": XIAOYAO})
	_check("t7.entry_after_carve", _menu_labels(page).has("挑战心魔") and not _menu_labels(page).has("进行刻印"), _menu_labels(page))
	_check("t7.plus_after_carve", str(XTianqiBrand.panel(s, a).text).ends_with("+"))
	_check("t7.trial_battle", XZhenqi.menu(s, {"page": "trial", "id": XIAOYAO}).has("battle"))
	XZhenqi.pending_trial = {}


# ---- P2-3、P2-4：正序爬 1～36 层 ----
func _p24_climb() -> void:
	var s := _state()
	var a: XActor = s.battle_members()[0]
	var h := s.helper()
	_setb(a, 0, 0)
	if h != null:
		_setb(h, 0, 0)
	var ends := {}
	var hl := {}
	for f in range(1, 37):
		var key := "guardian:%d" % f
		if f == 34:
			key = "summit:34"
		elif f == 35:
			key = "shadow:war"
		elif f == 36:
			key = "horseman:war"
		XTianqiBrand.toasts.clear()
		var c := _boss(key, f)
		if f == 36:
			c["fills"] = {a.actor_id: 2}
		XTianqiBrand.settle(_logic(s, c))
		if f % 5 == 0:
			ends[f] = XTianqiBrand.value(a)
			if f <= 30:
				hl[f] = bool(XTianqiBrand.panel(s, a).highlight) and XTianqiBrand.toasts.any(func(t): return str(t).contains("烙印已到瓶颈"))
		for x in [a, h]:
			if x != null and XTianqiBrand.can_stand(x):
				XTianqiBrand.stand(x)
	_check("p24.segment_ends", ends == {5: 1000, 10: 2500, 15: 4000, 20: 5500, 25: 7000, 30: 8500, 35: 9200}, ends)
	_check("p23.highlight", hl.values().all(func(v): return v) and hl.size() == 6, hl)
	_check("p24.exact_95", XTianqiBrand.value(a) == 9500, XTianqiBrand.value(a))
	_check("p24.cleared36_after", XTianqiBrand.cap_now(s, a) == 10000)
	if h != null:
		_check("p24.helper_half", XTianqiBrand.value(h) > 0 and XTianqiBrand.value(h) < XTianqiBrand.value(a), XTianqiBrand.value(h))


# ---- 端到端：真开一场守层者 ----
func _e2e() -> void:
	var s := _state()
	var lg := XBattleLogic.new()
	lg.setup(39, s)  # 6 层守层者
	var c := XTianqiBrand.fight(lg)
	_check("e2e.guardian6", str(c.get("key", "")) == "guardian:6" and str(c.get("kind", "")) == "boss" and not bool(c.get("ripe", true)), c)
	var a: XActor = lg.actors[0]
	_setb(a, 1000, 1)
	lg.grant({"gold": 0, "exp": 0, "drops": []})
	_check("e2e.grant_settles", XTianqiBrand.firsts(s).has("guardian:6") and XTianqiBrand.value(a) == 1300, XTianqiBrand.value(a))
	var lg2 := XBattleLogic.new()
	lg2.setup(39, s)
	_check("e2e.ripe_second", bool(XTianqiBrand.fight(lg2).get("ripe", false)))


# ---- 甲核 R1 P1：七印里副本走真实路径（XTianqiQiyinRule.setup → facts_of）----
## 灰印、默印第 2 场精英（297、220）借了【首领】名的敌群，不能按名字前缀认成首领；里副本首领那场认 qiyin:<印>
func _qiyin_real() -> void:
	var s := _state()
	s.set_variable(20, 33)
	s.flags.tianqi["line"] = "war"
	XTianqiWarLine.progress(s)["stage"] = XTianqiWarLine.STAGE_DONE
	for pair in [["hui", 297], ["mo", 220]]:
		XTianqiQiyinRule.prepare(str(pair[0]), false)
		var lg := XBattleLogic.new()
		lg.setup(int(pair[1]), s)
		var named := lg.enemies.any(func(e): return str(e.data().get("name", "")).contains("【首领】"))
		var c := XTianqiBrand.fight(lg)
		_check("qiyin_real.elite_%s" % pair[0], XTianqiQiyinRule.active(lg) and named and str(c.get("kind", "")) == "none", [named, c])
		lg.end_battle()
	XTianqiQiyinRule.prepare("hui", true)
	var lb := XBattleLogic.new()
	lb.setup(296, s)
	var cb := XTianqiBrand.fight(lb)
	_check("qiyin_real.boss_hui", str(cb.get("key", "")) == "qiyin:hui" and str(cb.get("kind", "")) == "boss", cb)
	lb.end_battle()
	# P2-1：zhenqi 为空的角色经 gain 写入后键是全的
	var a: XActor = s.actors[XIAOYAO]
	a.zhenqi = {}
	XTianqiBrand.gain(s, a, "test", 1.0)
	_check("gain_ensure_keys", a.zhenqi.has("qi") and a.zhenqi.has("brand_realm") and int(a.zhenqi.get("brand", 0)) == 100, a.zhenqi)
	# P2-2：开着烙印时闭关列表页头不出真气文案
	var r := XZhenqi.menu(s, {"page": "retreat"})
	_check("retreat_head_brand", not " ".join(r.lines).contains("真气") and str(r.lines[0]).contains("烙印"), r.lines)
