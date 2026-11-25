extends Node
## 【cc·T117】天启篇烙印本体（XTianqiBrand，稿《天启篇_烙印 v0.5》第十三节 T073-b 验收）：
## 一、开关关着：mult 恒 1、K 那一项不变、不认这一场、不结算、闭关菜单照真气；西游档、天启篇档读出来再存回去逐字节不变（没有烙印键时不新建）。
## 二、开着：第十一节第 1 步（烙印 0 和 100% 对木桩 1.50 倍，七个节点逐个对）；存档带着三个角色键和首胜表来回。
## 三、专项 1～7（稿第十三节 T073-b 验收）；P2-2 甲二门禁；P2-3 正序撞节点高亮＋「烙印已到「某段」的极限」；P2-4 36 层首通那一场刻印者正好 95%。
## 四、端到端：真的 BattleLogic.setup 守层者敌群认出 guardian:<层>；grant 里接着 settle。
## 五、T140：七印灰印／默印精英（297、220）、死亡线／饥荒线节末精英（294、430）都认首领战；玩家看到的烙印文字不用「境」「锚」，说「加深」＋段名。
## 七、T118（T073-c）：常驻六条代价各一组（生效、不生效、跨过那一点）；P2-1 判烙印不判境（4000 砥柱不吃虚不受补、4001 吃）；一条命两档、战后照常站起来；和嘲讽、七印、死亡线保命次序对一遍；开关关着不动。
## 六、T144：战争线 35、瘟疫线 248 节末那场与七印其余五场压轴前精英（250／34／11／123／188）按上下文认首领战；同敌群野外照名字不算。
## 八、T119（T073-d1）：自己疯的几率、花样解锁（P2-1：4000 砥柱抽不到抽自己、4001 能）、生熟（开场、几率、花样；心魔是生的）、保护（隔 2 回合、
## 同回合最多 2 人顺延、15% 封顶打不倒）、五种花样加断片各自的结果、行动入口最顶上（挂机、场内自动、手动三条路同一个结果）、同种子可复现；
## 烧命挪到确实出手之后（T118 小A P3②：被禁用不扣）；开关关着不取数、不拦。
## 九、T120（T073-d2）：灼痕的上限（向下取整）、一下涨多少（按异化级，骑士／守层者／使徒按终焉）、一次行动对同一个人最多一次、满了清零发作（熟只出三种）；
## 和自己疯共用隔 2 回合、同回合最多 2 人（被顺延的仍算满一次）；打赢首领战烙实（每次 +0.75、一场最多 2 次、没满过为 0、倒下的照算）；
## 不刻印 40% 照发作、烙印不变；不是首领战不烙实；真的敌人普攻打中才涨（没命中、护盾全挡不涨）；灼痕槽界面读数；开关关着不涨、不画。

const XIAOYAO := 1
const LVSIJI := 2

## 规则流替身：按取数原因给定值（没给的 next_float 给 default_float，取序号给 0），数取了几次照记
class FixStream extends XRandomStream:
	var floats := {}
	var mods := {}
	var default_float := 0.99
	var reasons := {}
	func _note(reason: String) -> void:
		draws += 1
		reasons[reason] = int(reasons.get(reason, 0)) + 1
	func next_float(reason: String, _event_key := "") -> float:
		_note(reason)
		return float(floats.get(reason, default_float))
	func next_uint(reason: String, _event_key := "") -> int:
		_note(reason)
		return 0
	func next_index_mod(n: int, reason: String, _event_key := "") -> int:
		_note(reason)
		return clampi(int(mods.get(reason, 0)), 0, maxi(0, n - 1))
	func next_int_inclusive(lo: int, _hi: int, reason: String, _event_key := "") -> int:
		_note(reason)
		return lo

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _arg(name: String, default := "") -> String:
	for x in OS.get_cmdline_user_args():
		if x.begins_with(name + "="):
			return x.substr(name.length() + 1)
	return default


func _run() -> void:
	XMessageBox.auto = true
	seed(20261117)
	XTianqiSkills.reload_table()
	XTianqiBase.clear_cache()
	XTianqiBrand.clear_cache()
	XGojo.unlock_override = 0
	# T220（T073-e）：烙印、期四总开关、熟练度默认都开了。本专项各条是在期四关着时写的（小数字的伤害比、受击率），
	# 照原条件把期四和熟练度拨回关跑；期四开着、量级 81 级的力量两端由 K 探针（tests/virtual_player/k_calibrate.gd --brand）量
	_check("default_on", XTianqiBrand.ENABLED and XTianqiBase.PHASE4 and XTianqiSkills.MASTERY, [XTianqiBrand.ENABLED, XTianqiBase.PHASE4, XTianqiSkills.MASTERY])
	XTianqiBase.PHASE4 = false
	XTianqiSkills.MASTERY = false
	XTianqiSkills.reload_table()
	XTianqiBase.clear_cache()
	_off()
	XTianqiBrand.ENABLED = true
	# T514：本专项量的是烙印本体和代价（皮薄、虚不受补、破防的单独倍率），境底＋境支关着量；它们在 xiyou_tianqi_brand_realm 专项
	XTianqiBrandRealm.ENABLED = false
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
	_t140_spread()
	_t140_text()
	_t118_costs()
	_t119_fits()
	await _t119_entry()
	_t119_seed()
	_t119_stress(int(_arg("--t119-stress", "40")))
	_t120_sear()
	_t120_settle()
	_t120_real()
	_t120_text()
	_t121_status()
	XTianqiBrand.ENABLED = false
	_t121_status_off()
	_t118_off()
	_t119_off()
	_t120_off()
	XTianqiBrandRealm.ENABLED = true  # 开头为量代价关掉的境底开关还原（T514 核 P3-2）
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
	_check("t1.no_gain_toast", XTianqiBrand.toasts.any(func(t): return str(t).contains("的烙印已到「守一」的极限，本场未再加深。")), XTianqiBrand.toasts)
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
				hl[f] = bool(XTianqiBrand.panel(s, a).highlight) and XTianqiBrand.toasts.any(func(t): return str(t).contains("的极限，打赢心魔才能继续加深"))
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
## 灰印、默印第 2 场精英（297、220）借了【首领】名的敌群：T140 起照名字前缀算首领战（Kyo 11-17「都算首领战」，撤 T117 R1 的例外）；里副本首领那场认 qiyin:<印>
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
		_check("qiyin_real.elite_%s" % pair[0], XTianqiQiyinRule.active(lg) and named and str(c.get("kind", "")) == "boss" and str(c.get("key", "")).ends_with(":%d" % int(pair[1])), [named, c])
		lg.end_battle()
	# T144（D178「都算」）：其余五印压轴前那场精英（名字不带首领前缀）也认首领战；同一敌群不经七印开战仍按名字（不是首领战）
	for pair in [["bai", 250], ["hong", 34], ["hei", 11], ["xun", 123], ["zhen", 188]]:
		_check("t144.qiyin_troop_%s" % pair[0], int(XTianqiQiyin.seal_info(str(pair[0])).troops[1]) == int(pair[1]))
		XTianqiQiyinRule.prepare(str(pair[0]), false)
		var lg := XBattleLogic.new()
		lg.setup(int(pair[1]), s)
		var c := XTianqiBrand.fight(lg)
		_check("t144.qiyin_elite_%s" % pair[0], XTianqiQiyinRule.active(lg) and str(c.get("kind", "")) == "boss" and str(c.get("key", "")).ends_with(":%d" % int(pair[1])) and not bool(c.get("ripe", true)), c)
		lg.end_battle()
		var lp := XBattleLogic.new()
		lp.setup(int(pair[1]), s)
		_check("t144.plain_troop_%s" % pair[0], str(XTianqiBrand.fight(lp).get("kind", "")) == "none", XTianqiBrand.fight(lp))
		lp.end_battle()
	# 第一场精英（249）不在 D178 里：照名字认，不带前缀就不是首领战
	XTianqiQiyinRule.prepare("bai", false)
	var l1 := XBattleLogic.new()
	l1.setup(249, s)
	_check("t144.qiyin_first_elite_none", str(XTianqiBrand.fight(l1).get("kind", "")) == "none", XTianqiBrand.fight(l1))
	l1.end_battle()
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


# ---- T140：四线节末精英走真实路径（XTianqi<线>Alien.prepare("spread") → BattleLogic.setup → facts_of）----
func _t140_spread() -> void:
	for pair in [["death", 294], ["famine", 430], ["war", 35], ["plague", 248]]:
		var s := _state()
		s.flags.tianqi["line"] = str(pair[0])
		var ok := false
		match str(pair[0]):
			"death": ok = XTianqiDeathAlien.prepare("spread", s)
			"famine": ok = XTianqiFamineAlien.prepare("spread", s)
			"war": ok = XTianqiWarAlien.prepare("spread", s)
			"plague": ok = XTianqiPlagueAlien.prepare("spread", s)
		var lg := XBattleLogic.new()
		lg.setup(int(pair[1]), s)
		var alien := false
		match str(pair[0]):
			"death": alien = XTianqiDeathAlien.active(lg)
			"famine": alien = XTianqiFamineAlien.active(lg)
			"war": alien = XTianqiWarAlien.active(lg)
			"plague": alien = XTianqiPlagueAlien.active(lg)
		var c := XTianqiBrand.fight(lg)
		_check(("t144" if pair[0] in ["war", "plague"] else "t140") + ".spread_%s" % pair[0], ok and alien and str(c.get("kind", "")) == "boss" and str(c.get("key", "")).ends_with(":%d" % int(pair[1])) and not bool(c.get("ripe", true)), [ok, alien, c])
		var a: XActor = lg.actors[0]
		_setb(a, 0, 0)
		lg.grant({"gold": 0, "exp": 0, "drops": []})
		_check(("t144" if pair[0] in ["war", "plague"] else "t140") + ".spread_%s_firsts" % pair[0], XTianqiBrand.firsts(s).has(str(c.get("key", ""))), XTianqiBrand.firsts(s))
		lg.end_battle()
	# 同一敌群不经 spread 开战（野外遇到）仍按名字认：35【前所未见】、248【十分罕见】不是首领战
	for tid in [35, 248]:
		var s2 := _state()
		var lp := XBattleLogic.new()
		lp.setup(tid, s2)
		_check("t144.plain_%d_none" % tid, str(XTianqiBrand.fight(lp).get("kind", "")) == "none", XTianqiBrand.fight(lp))
		lp.end_battle()
	_check("t144.retreat_text", XTianqiBrand.TEXT_RETREAT[1] == "烙印随首领战加深；每次到达极限，打赢心魔才能继续加深。", XTianqiBrand.TEXT_RETREAT[1])


# ---- T140：玩家可见文字（闭关页头、角色页、心魔门槛、心魔开打、打完、提示）不用「境」「锚」，说「加深」＋段名 ----
func _t140_text() -> void:
	var s := _state()
	var a: XActor = s.actors[XIAOYAO]
	_setb(a, 4000, 2)  # 铸骨到顶（40%）
	var said := []
	var head := XZhenqi.menu(s, {"page": "retreat"})
	said.append_array(head.lines)
	for o in head.options:
		said.append(str(o.label))
	var page := XZhenqi.menu(s, {"page": "actor", "id": a.actor_id})
	said.append_array(page.lines)
	_check("t140.page_stage", " ".join(page.lines).contains("烙印「铸骨」") and " ".join(page.lines).contains("%s 的烙印已到「铸骨」的极限，打赢心魔才能继续加深" % a.display_name()), page.lines)
	var tr := XZhenqi.menu(s, {"page": "trial", "id": a.actor_id})
	said.append_array(tr.lines)
	_check("t140.trial_line", " ".join(tr.lines).contains("烙印才能加深至「砥柱」"), tr.lines)
	XZhenqi.pending_trial = {}
	XZhenqi.trial_done = {"actorId": a.actor_id, "target": 3, "brand": true, "won": true}
	var won := XZhenqi.menu(s, {"page": "trial_end"})
	said.append_array(won.lines)
	_check("t140.stand_line", " ".join(won.lines).contains("%s 的烙印加深至「砥柱」！" % a.display_name()) and XTianqiBrand.realm(a) == 3, won.lines)
	_setb(a, 4000, 2)
	XZhenqi.trial_done = {"actorId": a.actor_id, "target": 3, "brand": true, "won": false}
	var lost := XZhenqi.menu(s, {"page": "trial_end"})
	said.append_array(lost.lines)
	_check("t140.lose_line", " ".join(lost.lines).contains("%s 的烙印未能加深至「砥柱」。" % a.display_name()), lost.lines)
	_setb(a, 2000, 2)
	var gate := XZhenqi.menu(s, {"page": "trial", "id": a.actor_id})
	said.append_array(gate.lines)
	_check("t140.gate_line", " ".join(gate.lines).contains("烙印还没到「铸骨」的极限，暂不能挑战心魔。"), gate.lines)
	_setb(a, 0, 0, false)
	var carve := XZhenqi.menu(s, {"page": "carve", "id": a.actor_id})
	said.append_array(carve.lines)
	XTianqiBrand.toasts.clear()
	_setb(a, 900, 0)
	XTianqiSave.section(s, "brand").firsts = {"guardian:5": 1}  # 层线到 10%，才涨得到守一的头
	XTianqiBrand.gain(s, a, "test", 1.0)
	said.append_array(XTianqiBrand.toasts)
	_check("t140.toast_stage", XTianqiBrand.toasts.any(func(x): return str(x) == "%s 的烙印已到「守一」的极限，打赢心魔才能继续加深" % a.display_name()), XTianqiBrand.toasts)
	var bad := said.filter(func(x): return str(x).contains("境") or str(x).contains("锚") or str(x).contains("瓶颈"))
	_check("t140.no_jing_anchor", bad.is_empty() and said.size() >= 10, [bad, said.size()])
	# 文件里定死的几句也一并扫（含没走到的分支）
	var consts := [XTianqiBrand.TEXT_BOTTLENECK, XTianqiBrand.TEXT_NO_GAIN, XTianqiBrand.TEXT_GAIN] + XTianqiBrand.TEXT_CARVE_WARN + XTianqiBrand.TEXT_RETREAT
	_check("t140.consts_no_jing", not consts.any(func(x): return str(x).contains("境") or str(x).contains("锚")), consts)


# ---- T118（T073-c）常驻六条代价 ----
## 每条代价「烙印超过 over」才有：境设成能装下这个烙印的那一段（value 按本段节点截断）
func _cost_actor(lg: XBattleLogic, idx: int, brand: int) -> XActor:
	var a: XActor = lg.actors[idx]
	var r := 0
	while r < XTianqiBrand.last_realm() and XTianqiBrand.node_of(r) <= brand:  # 正好在节点上的已立入下一段（P2-1 那种人）
		r += 1
	_setb(a, brand, r)
	a.hp = a.mhp
	return a


func _cost_logic(s: XState, troop := 1) -> XBattleLogic:
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	return lg


func _kill(a: XActor) -> void:
	a.hp = 0.0
	if not a.state_ids.has(1):
		a.add_state(1)


func _t118_costs() -> void:
	var s := _state()
	# 0. P2-1 门槛：六条各在节点上不算、多 1 万分点算（境设成已在下一段）
	var lg := _cost_logic(s)
	var a: XActor = lg.actors[0]
	for row in XTianqiBrand.data().costs.list:
		var over := roundi(float(row.over) * 100)
		var r := 0
		while XTianqiBrand.node_of(r) < over:
			r += 1
		r += 1
		_setb(a, over, r)
		var at := XTianqiBrand.has_cost(a, str(row.key))
		_setb(a, over + 1, r)
		_check("t118.gate_%s" % row.key, not at and XTianqiBrand.has_cost(a, str(row.key)) and XTianqiBrand.realm(a) == r, [over, r])
	lg.end_battle()

	# 1. 出头鸟＋外人项
	lg = _cost_logic(s)
	var e: XEnemy = lg.enemies[0]
	a = _cost_actor(lg, 0, 2000)
	var b := _cost_actor(lg, 1, 0)
	lg.turn = 2
	lg.act(a, a.attack_skill(), e)  # 真出手记「打过敌人」
	_check("t118.bird_noted", int(XTianqiBrand.fight(lg).hits.get(a, -1)) == 2, XTianqiBrand.fight(lg).hits)
	lg.turn = 3
	_check("t118.bird_on", is_equal_approx(XTianqiBrand.aggro_mult(lg, e, a), 1.8 * 2.0), XTianqiBrand.aggro_mult(lg, e, a))
	_check("t118.outsider_zero", is_equal_approx(XTianqiBrand.aggro_mult(lg, e, b), 2.0), XTianqiBrand.aggro_mult(lg, e, b))
	_check("t118.bird_actor_user", XTianqiBrand.aggro_mult(lg, a, b) == 1.0)
	lg.turn = 4
	_check("t118.bird_stale", is_equal_approx(XTianqiBrand.aggro_mult(lg, e, a), 1.8), XTianqiBrand.aggro_mult(lg, e, a))  # 上一回合没出手
	lg.turn = 3
	_setb(a, 1000, 1)
	_check("t118.bird_at_node", is_equal_approx(XTianqiBrand.aggro_mult(lg, e, a), 1.9), XTianqiBrand.aggro_mult(lg, e, a))  # 正好 10% 不算出头鸟
	_setb(a, 1001, 2)
	_check("t118.bird_cross", is_equal_approx(XTianqiBrand.aggro_mult(lg, e, a), (2.0 - 0.1001) * 2.0), XTianqiBrand.aggro_mult(lg, e, a))
	_setb(a, 2000, 2)
	for x in lg.actors:
		if x != a and x != b:
			_kill(x)
	var atk := e.attack_skill()
	var share := func(n: int) -> float:  # 走敌人真的选目标（targets_for → _targets_for 单体随机）
		var hit := 0
		for i in n:
			if lg.targets_for(e, atk) == [a]:
				hit += 1
		return float(hit) / n
	var on_share: float = share.call(600)
	_check("t118.bird_draws", on_share > 0.57, on_share)  # 3.6 : 2 ≈ 0.64（不带出头鸟 1.8 : 2 ≈ 0.47）
	# 嘲讽照常盖过：挑衅状态 414（受击率大）挂在烙印 0 的坦克身上，出头鸟那位抽中的比例掉到两成以下
	b.add_state(414)
	var taunt_share: float = share.call(600)
	_check("t118.taunt_over_bird", b.tgr >= 5.0 and taunt_share < 0.3, [b.tgr, taunt_share])  # 受击率型嘲讽是乘的：3.6 : 10 ≈ 0.26（不带烙印 1 : 5 ≈ 0.17）；四骑士混子、挑衅者、混子之盾在后面几层整个换目标
	lg.end_battle()

	# 2. 皮薄：物防、魔防倍率；攻击不动
	lg = _cost_logic(s)
	a = lg.actors[0]
	var base3 := _rate_off(a, 3)
	var base2 := _rate_off(a, 2)
	var thin := func(brand: int, i: int) -> float:
		_cost_actor(lg, 0, brand)
		return a.param_rate(i) / (base3 if i == 3 else (_rate_off(a, 5) if i == 5 else base2))
	_check("t118.thin_at25", is_equal_approx(thin.call(2500, 3), 1.0))
	_check("t118.thin_2799", is_equal_approx(thin.call(2799, 3), 1.0))  # 多不到 3 点不降
	_check("t118.thin_2800", is_equal_approx(thin.call(2800, 3), 0.99), thin.call(2800, 3))
	_check("t118.thin_full", is_equal_approx(thin.call(10000, 3), 0.75) and is_equal_approx(thin.call(10000, 5), 0.75), [thin.call(10000, 3), thin.call(10000, 5)])
	_check("t118.thin_atk", is_equal_approx(thin.call(10000, 2), 1.0))
	lg.end_battle()

	# 3. 虚不受补（P2-1 验收：烙印正好 4000、境在砥柱不吃，4001 吃）
	lg = _cost_logic(s)
	a = lg.actors[0]
	var healed := func(brand: int, hp_rate: float, amt: float) -> float:
		_cost_actor(lg, 0, brand)
		a.hp = floorf(a.mhp * hp_rate)
		var h0 := a.hp
		lg.gain_hp(a, amt)
		return a.hp - h0
	_check("t118.weak_heal_4000", healed.call(4000, 0.6, 100.0) == 100.0 and XTianqiBrand.realm(a) == 3, healed.call(4000, 0.6, 100.0))
	_check("t118.weak_heal_4001", healed.call(4001, 0.6, 100.0) == 50.0, healed.call(4001, 0.6, 100.0))
	_check("t118.weak_heal_low", healed.call(4001, 0.4, 100.0) == 100.0, healed.call(4001, 0.4, 100.0))  # 一半以下照常
	_check("t118.weak_heal_dmg", healed.call(4001, 0.6, -100.0) == -100.0)  # 扣血不动
	_cost_actor(lg, 0, 4001)
	lg.end_battle()
	a.hp = floorf(a.mhp * 0.6)
	var h1 := a.hp
	var rc := XResourceContext.new()
	rc.gain(a, "hp", 100.0)
	_check("t118.weak_heal_outside", a.hp - h1 == 100.0, a.hp - h1)  # 战斗外不算

	# 4. 不合群：队友放的全体友方落不到过 55% 的人身上，自己放的、点名给他的照吃
	lg = _cost_logic(s)
	a = _cost_actor(lg, 0, 0)
	b = _cost_actor(lg, 1, 5501)
	var group := XDB.rec("Skills", 108)
	var one := XDB.rec("Skills", 108).duplicate()
	one["scope"] = 7
	var by_a := lg.targets_for(a, group)
	_check("t118.no_group_on", int(group.scope) == 8 and by_a.has(a) and not by_a.has(b) and by_a.size() == lg.alive(lg.actors).size() - 1, by_a.size())
	_check("t118.no_group_self", lg.targets_for(b, group).has(b))
	_check("t118.no_group_single", lg.targets_for(a, one, b) == [b])
	_setb(b, 5500, 4)
	_check("t118.no_group_at_node", lg.targets_for(a, group).has(b))
	lg.end_battle()

	# 5. 烧命：出手前付当前生命 4%（向下取整），扣不死，不算受到伤害（不充 TP）
	lg = _cost_logic(s)
	e = lg.enemies[0]
	a = _cost_actor(lg, 0, 7001)
	a.hp = 1000.0 if a.mhp >= 1000.0 else a.mhp
	var hp0 := a.hp
	a.tp = 0.0
	var bl := XTianqiBrand.burn(lg, a)
	_check("t118.burn_on", bl.get("type", "") == "regen" and float(bl.hp) == floorf(hp0 * 0.04) and a.hp == hp0 - floorf(hp0 * 0.04) and a.tp == 0.0, [bl.get("hp"), a.hp, a.tp])
	a.hp = 1.0
	_check("t118.burn_no_kill", XTianqiBrand.burn(lg, a).is_empty() and a.hp == 1.0)
	_cost_actor(lg, 0, 7000)
	_check("t118.burn_at_node", XTianqiBrand.burn(lg, a).is_empty())
	a = _cost_actor(lg, 0, 7001)
	var hp_pre := a.hp
	var logs := lg.act(a, a.attack_skill(), e)
	var burn_at := logs.find(logs.filter(func(l): return str(l.get("type", "")) == "regen" and l.get("target") == a).front() if logs.any(func(l): return str(l.get("type", "")) == "regen" and l.get("target") == a) else null)
	var act_at := logs.find(logs.filter(func(l): return str(l.get("type", "")) == "action").front() if logs.any(func(l): return str(l.get("type", "")) == "action") else null)
	# T119（T118 小A P3②）：挪到 execute 里确实出手之后扣。返修（小A P1）：记录插在「行动」之前，行动那条的血量是扣完的
	_check("t118.burn_in_act", burn_at >= 0 and burn_at < act_at, logs.map(func(l): return l.get("type")))
	var paid_hp := float(logs[burn_at].hp) if burn_at >= 0 else -1.0
	_check("t119.burn_act_views", act_at >= 0 and paid_hp >= 1.0 and float(logs[act_at].views.get(a, {}).get("hp", -1.0)) == hp_pre - paid_hp,
		[hp_pre, paid_hp, logs[act_at].views.get(a, {}).get("hp") if act_at >= 0 else null])
	# 带 yepSeq 的技能＋烧命：「行动」后面（跳过 battle_text）紧跟 seq_phase，BattleScene._play 照样交给 XSequencePlayer
	var seq_k := act_at + 1
	while seq_k < logs.size() and str(logs[seq_k].type) == "battle_text":
		seq_k += 1
	_check("t119.burn_keeps_seq", XActionSequence.has_sequence(a.attack_skill()) and burn_at >= 0 and seq_k < logs.size() and str(logs[seq_k].type) == "seq_phase",
		logs.map(func(l): return l.get("type")))
	# 被禁用的行动（禁用号角）：execute 直接返回，不扣
	a.hp = a.mhp
	var hp_b := a.hp
	var horn_logs := lg.act(a, XDB.rec("Items", 255), e)
	_check("t119.burn_blocked_no_pay", a.hp == hp_b and not horn_logs.any(func(l): return str(l.get("type", "")) == "regen"), [hp_b, a.hp])
	_check("t118.burn_guard", not lg.act(a, XDB.rec("Skills", 2), null).any(func(l): return str(l.get("type", "")) == "regen" and l.get("target") == a))
	lg.end_battle()

	# 6. 一条命：过 70% 一场只能被复活一次，过 85% 不能；正好 70% 不限；战后照常站起来
	lg = _cost_logic(s)
	a = _cost_actor(lg, 0, 7001)
	_kill(a)
	a.remove_state(1)
	var first := a.is_alive()
	_kill(a)
	a.remove_state(1)
	_check("t118.one_life_once", first and a.is_dead(), [first, a.is_dead()])
	a = _cost_actor(lg, 1, 7000)
	for i in 3:
		_kill(a)
		a.remove_state(1)
	_check("t118.one_life_at_node", a.is_alive())
	a = _cost_actor(lg, 2, 8501)
	_kill(a)
	a.remove_state(1)
	_check("t118.one_life_none", a.is_dead())
	var c8 := _cost_actor(lg, 3, 8500)  # 正好 85%：只是「一场一次」那档
	_kill(c8)
	c8.remove_state(1)
	var c8a := c8.is_alive()
	_kill(c8)
	c8.remove_state(1)
	_check("t118.one_life_8500", c8a and c8.is_dead())
	lg.end_battle()
	a.remove_state(1)
	_check("t118.one_life_after_battle", a.is_alive() and a.hp >= 1.0)  # 打完照常站起来（不拦战斗外的复活）

	# 7. 和死亡线保命次序：死亡线先拦（不记次数），解开后烙印这一次照常给，再死被一条命拦
	var sd := _state()
	sd.flags.tianqi["line"] = "death"
	var ok := XTianqiDeathAlien.prepare("spread", sd)
	var ld := XBattleLogic.new()
	ld.setup(294, sd)
	a = _cost_actor(ld, 0, 7500)
	var df := XTianqiDeathAlien.fight(ld)
	df.no_revive[a] = true
	_kill(a)
	a.remove_state(1)
	var line_first := a.is_dead() and int(XTianqiBrand.fight(ld).revived.get(a, 0)) == 0
	df.no_revive.erase(a)
	a.remove_state(1)
	var once := a.is_alive() and int(XTianqiBrand.fight(ld).revived.get(a, 0)) == 1
	_kill(a)
	a.remove_state(1)
	_check("t118.order_death_line", ok and line_first and once and a.is_dead(), [ok, line_first, once, a.is_dead()])
	ld.end_battle()

	# 8. 和七印规则一起：里副本（白印不愈）里六条照常算，七印规则不受影响
	var sq := _state()
	sq.set_variable(20, 33)
	sq.flags.tianqi["line"] = "war"
	XTianqiWarLine.progress(sq)["stage"] = XTianqiWarLine.STAGE_DONE
	XTianqiQiyinRule.prepare("bai", false)
	var lq := XBattleLogic.new()
	lq.setup(250, sq)
	a = _cost_actor(lq, 0, 8501)
	_kill(a)
	a.remove_state(1)
	_check("t118.qiyin_rule", XTianqiQiyinRule.rule_of(lq) == "no_cure" and a.is_dead() and not XTianqiBrand.fight(lq).is_empty(), XTianqiQiyinRule.rule_of(lq))
	lq.end_battle()


## 烙印开关关着时的倍率（对照基准）
func _rate_off(a: XActor, i: int) -> float:
	var was := XTianqiBrand.ENABLED
	XTianqiBrand.ENABLED = false
	var r := a.param_rate(i)
	XTianqiBrand.ENABLED = was
	return r


## 开关关着：六条都不生效（烙印满的人也一样）
func _t118_off() -> void:
	var s := _state()
	var lg := _cost_logic(s)
	var a: XActor = lg.actors[0]
	_setb(a, 10000, 6)
	var e: XEnemy = lg.enemies[0]
	var ok := true
	for row in XTianqiBrand.data().costs.list:
		ok = ok and not XTianqiBrand.has_cost(a, str(row.key))
	ok = ok and XTianqiBrand.aggro_mult(lg, e, a) == 1.0 and XTianqiBrand.def_rate(a, 3) == 1.0 and XTianqiBrand.burn(lg, a).is_empty()
	_kill(a)
	a.remove_state(1)
	_check("t118.off_all", ok and a.is_alive() and XTianqiBrand.fight(lg).is_empty(), ok)
	lg.end_battle()


# ---- T119（T073-d1）发作 ----
## 真开一场（敌群 1），规则流换成 FixStream；ripe 按参数改；其余角色烙印 0（几率 0，不取数）
func _fit_logic(s: XState, ripe := false, troop := 1) -> XBattleLogic:
	for x in s.battle_members():
		_setb(x, 0, 0)
		x.recover_all()
	var lg := _cost_logic(s, troop)
	XTianqiBrand.fight(lg)["ripe"] = ripe
	var fs := FixStream.new()
	fs.domain = "rule"
	fs.floats["brand_fit"] = 0.0  # 掷必中
	lg.random.rule = fs
	return lg


func _fs(lg: XBattleLogic) -> FixStream:
	return lg.random.rule as FixStream


## 让 idx 号角色（烙印满）在第 2 回合开始发作 kinds[kind_idx]（生的：第 1 回合不掷）
func _fit_at(lg: XBattleLogic, idx: int, kind_idx: int) -> XActor:
	var a := _cost_actor(lg, idx, 10000)
	_fs(lg).mods["brand_fit_kind"] = kind_idx
	lg.start_turn()
	lg.start_turn()
	return a


func _fit_turns(lg: XBattleLogic, a: XActor) -> Array:
	return XTianqiBrand.fight(lg).get("fit_log", []).filter(func(r): return int(r.actor) == a.actor_id).map(func(r): return int(r.turn))


func _types(logs: Array) -> Array:
	return logs.map(func(l): return str(l.get("type", "")))


func _t119_fits() -> void:
	var s := _state()
	# 1. 几率：满烙印生 13.5%、熟 5.4%；正好 10% 为 0
	var lg := _fit_logic(s)
	var a := _cost_actor(lg, 0, 10000)
	_check("t119.chance_raw", is_equal_approx(XTianqiBrand.fit_chance(lg, a), 0.135), XTianqiBrand.fit_chance(lg, a))
	XTianqiBrand.fight(lg).ripe = true
	_check("t119.chance_ripe", is_equal_approx(XTianqiBrand.fit_chance(lg, a), 0.054), XTianqiBrand.fit_chance(lg, a))
	XTianqiBrand.fight(lg).ripe = false
	_cost_actor(lg, 0, 1000)
	_check("t119.chance_at_10", XTianqiBrand.fit_chance(lg, a) == 0.0 and XTianqiBrand.fit_kinds(lg, a) == ["daze"], XTianqiBrand.fit_kinds(lg, a))  # 烙印 ≤ 1000 被打疯只有发呆
	# 2. 花样解锁判烙印不判境（P2-1）：4000、境在砥柱抽不到抽自己；4001 能
	_setb(a, 4000, 3)
	var k4000 := XTianqiBrand.fit_kinds(lg, a)
	_setb(a, 4001, 3)
	var k4001 := XTianqiBrand.fit_kinds(lg, a)
	_check("t119.kinds_4000", k4000 == ["daze", "misfire"] and XTianqiBrand.realm(a) == 3, k4000)
	_check("t119.kinds_4001", k4001 == ["daze", "misfire", "hit_self"], k4001)
	_setb(a, 10000, 6)
	_check("t119.kinds_full_raw", XTianqiBrand.fit_kinds(lg, a) == ["daze", "misfire", "hit_self", "break_guard", "hit_ally", "swap"], XTianqiBrand.fit_kinds(lg, a))
	XTianqiBrand.fight(lg).ripe = true
	_check("t119.kinds_full_ripe", XTianqiBrand.fit_kinds(lg, a) == ["daze", "misfire", "break_guard"], XTianqiBrand.fit_kinds(lg, a))
	_setb(a, 4001, 3)
	_check("t119.kinds_ripe_partial", XTianqiBrand.fit_kinds(lg, a) == ["daze", "misfire"], XTianqiBrand.fit_kinds(lg, a))  # 已解锁的里面有哪几种出哪几种
	lg.end_battle()

	# 3. 开场与间隔：掷必中时生的 2／5／8 回合发作（第 1 回合不掷、隔 2 回合）；熟的 4／7（前 3 回合不掷）
	lg = _fit_logic(s)
	a = _cost_actor(lg, 0, 10000)
	for i in 9:
		lg.start_turn()
	_check("t119.raw_turns", _fit_turns(lg, a) == [2, 5, 8], _fit_turns(lg, a))
	_check("t119.no_draw_zero", int(_fs(lg).reasons.get("brand_fit", 0)) == 3, _fs(lg).reasons)  # 只有他掷（烙印 0 的人几率 0 不取数），间隔里不掷
	lg.end_battle()
	lg = _fit_logic(s, true)
	a = _cost_actor(lg, 0, 10000)
	for i in 9:
		lg.start_turn()
	_check("t119.ripe_turns", _fit_turns(lg, a) == [4, 7], _fit_turns(lg, a))
	lg.end_battle()

	# 4. 同回合最多 2 人：三个满烙印的人第 2 回合两个开始、第三个顺延到第 3 回合
	lg = _fit_logic(s)
	var three := [_cost_actor(lg, 0, 10000), _cost_actor(lg, 1, 10000), _cost_actor(lg, 2, 10000)]
	for i in 6:
		lg.start_turn()
	var per := {}
	for r in XTianqiBrand.fight(lg).fit_log:
		per[int(r.turn)] = int(per.get(int(r.turn), 0)) + 1
	_check("t119.max_two", per.values().all(func(n): return n <= 2) and _fit_turns(lg, three[0]) == [2, 5] and _fit_turns(lg, three[1]) == [2, 5] and _fit_turns(lg, three[2]) == [3, 6],
		[per, _fit_turns(lg, three[0]), _fit_turns(lg, three[2])])
	lg.end_battle()

	# 5. 发呆：空过（不出招、敌人血不动），报一句；同回合第二个行动位也空过、不再报
	lg = _fit_logic(s)
	a = _fit_at(lg, 0, 0)
	var e: XEnemy = lg.enemies[0]
	var ehp := e.hp
	var fa := lg.brand_forced(a)
	var logs := lg.act(a, fa[0], fa[1])
	_check("t119.daze", XTianqiBrand.is_fit_command(fa[0]) and str(fa[0][XTianqiBrand.FIT_KEY]) == "daze" and not _types(logs).has("action") and e.hp == ehp
		and logs.any(func(l): return str(l.get("type", "")) == "battle_text" and str(l.text).contains("发呆")), _types(logs))
	var fa2 := lg.brand_forced(a)
	_check("t119.second_slot_idle", str(fa2[0].get(XTianqiBrand.FIT_KEY, "")) == "idle" and not _types(lg.act(a, fa2[0], fa2[1])).has("battle_text") and e.hp == ehp, fa2)
	lg.turn = 3
	_check("t119.one_round", lg.brand_forced(a).is_empty())
	lg.end_battle()

	# 6. 哑火：普攻随机一个敌人，算出手（出头鸟记打过人、过 70% 照付烧命）
	lg = _fit_logic(s)
	a = _fit_at(lg, 0, 1)
	_fs(lg).mods["brand_fit_target"] = lg.alive(lg.enemies).size() - 1
	fa = lg.brand_forced(a)
	var tgt = fa[1]
	var last_alive = lg.alive(lg.enemies).back()  # T449：DECK 下普攻吃物理增伤后可能把目标打死，出手前先记
	logs = lg.act(a, fa[0], fa[1])
	var acted := logs.filter(func(l): return str(l.get("type", "")) == "action")
	_check("t119.misfire", tgt is XEnemy and tgt == last_alive and not acted.is_empty() and int(acted[0].skill.id) == a.attack_skill_id()
		and int(XTianqiBrand.fight(lg).hits.get(a, -1)) == int(lg.turn), [tgt, _types(logs)])
	_check("t119.misfire_burns", logs.any(func(l): return str(l.get("type", "")) == "regen" and l.get("target") == a))
	lg.end_battle()

	# 7. 抽自己：打自己一下，≤ 最大生命 15%、打不倒、不算出手（不付烧命、没有「行动」）；烙印加成按 1、K 照乘
	lg = _fit_logic(s)
	a = _fit_at(lg, 0, 2)
	fa = lg.brand_forced(a)
	var hp0 := a.hp
	logs = lg.act(a, fa[0], fa[1])
	var regens := logs.filter(func(l): return str(l.get("type", "")) == "regen")
	_check("t119.hit_self", fa[1] == a and regens.size() == 1 and regens[0].target == a and a.is_alive() and hp0 - a.hp == float(regens[0].hp)
		and float(regens[0].hp) <= floorf(a.mhp * 0.15) and not _types(logs).has("action"), [_types(logs), hp0, a.hp, a.mhp])
	var b: XActor = lg.actors[1]
	var v_full := XTianqiBrand.strike_value(lg, a, b)
	_setb(a, 0, 0)
	var v_zero := XTianqiBrand.strike_value(lg, a, b)
	_setb(a, 10000, 6)
	_check("t119.strike_no_brand", v_full > 0.0 and v_full == v_zero and is_equal_approx(XTianqiBrand.mult(a), 1.5), [v_full, v_zero])
	# 对照：平时这个人的烙印确实进了 K 那一项（不然上面那条是白比）
	_check("t119.strike_k_live", is_equal_approx(float(XTianqiCombat.dealt_parts(a, s).get("k", 0.0)), XTianqiBase.k_base(s) * 1.5), XTianqiCombat.dealt_parts(a, s))
	a.hp = 1.0
	_check("t119.strike_no_kill", XTianqiBrand.strike(lg, a, a).is_empty() and a.hp == 1.0 and a.is_alive())
	# 封顶：目标最大生命很小时按 15% 截
	b.hp = b.mhp
	var cap := floorf(b.mhp * 0.15)
	var r := XTianqiBrand.strike(lg, a, b)
	_check("t119.strike_cap", not r.is_empty() and float(r.hp) <= cap and (float(r.hp) == cap or float(r.hp) == XTianqiBrand.strike_value(lg, a, b)), [r.get("hp"), cap])
	# 封顶一定咬得住的一例：打敌人 1（满烙印的普攻远超它最大生命的 15%）
	var tiny: XEnemy = lg.enemies[0]
	tiny.hp = tiny.mhp
	var tcap := floorf(tiny.mhp * 0.15)
	var raw_v := XTianqiBrand.strike_value(lg, a, tiny)
	var rt := XTianqiBrand.strike(lg, a, tiny)
	_check("t119.strike_cap_bites", raw_v > tcap and float(rt.get("hp", -1)) == tcap and tiny.hp == tiny.mhp - tcap, [tiny.mhp, raw_v, rt.get("hp"), tiny.hp])
	lg.end_battle()

	# 8. 六亲不认：普攻一个活着的队友（不是自己），同样封顶、打不倒；没有队友就发呆
	lg = _fit_logic(s)
	a = _fit_at(lg, 0, 4)
	fa = lg.brand_forced(a)
	var mate = fa[1]
	var mhp0: float = mate.hp if mate is XActor else 0.0
	logs = lg.act(a, fa[0], fa[1])
	_check("t119.hit_ally", mate is XActor and mate != a and lg.actors.has(mate) and mate.is_alive() and mhp0 - mate.hp <= floorf(mate.mhp * 0.15) and not _types(logs).has("action"),
		[mate, _types(logs)])
	lg.turn = 5
	XTianqiBrand.fight(lg).fit_now[a] = {"kind": "hit_ally", "from": 5, "to": 5}
	for x in lg.actors:
		if x != a:
			_kill(x)
	fa = lg.brand_forced(a)
	_check("t119.hit_ally_alone", str(fa[0].get(XTianqiBrand.FIT_KEY, "")) == "daze", fa)
	lg.end_battle()

	# 9. 破防：不拦行动；这一回合和下一回合受到的生命伤害 ×1.3（XDamage 天启篇乘区），第三回合恢复
	lg = _fit_logic(s)
	a = _fit_at(lg, 0, 3)
	e = lg.enemies[0]
	var dmg := func() -> float:
		return float(XDamage.calculate(e.attack_skill(), e, a, {"critical": false, "variance": false}).breakdown.row.beforeFixed)  # 取整之前（小怪伤害个位数，比取整后的比例不准）
	var on2: float = dmg.call()
	var forced2 := lg.brand_forced(a)
	lg.turn = 3
	var on3: float = dmg.call()
	lg.turn = 4
	var off4: float = dmg.call()
	_check("t119.break_guard", forced2.is_empty() and is_equal_approx(XTianqiBrand.taken_mult(a), 1.0) and off4 > 0.0 and absf(on2 / off4 - 1.3) < 0.001 and on2 == on3,
		[on2, on3, off4])
	lg.turn = 2
	_check("t119.break_guard_mult", is_equal_approx(XTianqiBrand.taken_mult(a), 1.3))
	lg.end_battle()

	# 10. 断片（换人 T086 落地前的兜底）：两回合不行动、人在场上；这两回合队友点名给他的落不到他身上，全体的照吃
	lg = _fit_logic(s)
	a = _fit_at(lg, 0, 5)
	b = lg.actors[1]
	var f2 := lg.brand_forced(a)
	var named2 := XTianqiBrand.filter_group(lg, b, {"scope": 7}, [a])
	lg.turn = 3
	var f3 := lg.brand_forced(a)
	lg.turn = 4
	var f4 := lg.brand_forced(a)
	var named4 := XTianqiBrand.filter_group(lg, b, {"scope": 7}, [a])
	_check("t119.blackout", str(f2[0].get(XTianqiBrand.FIT_KEY, "")) == "blackout" and str(f3[0].get(XTianqiBrand.FIT_KEY, "")) == "blackout" and f4.is_empty() and a.is_alive(), [f2, f3, f4])
	_check("t119.blackout_named", named2.is_empty() and named4 == [a] and XTianqiBrand.filter_group(lg, a, {"scope": 7}, [a]) == [a], [named2, named4])
	# 断片是两回合，间隔从最后一回合算：第 2、3 回合断片，最早第 6 回合再发作
	_check("t119.blackout_gap", int(XTianqiBrand.fight(lg).fit_last.get(a, 0)) == 3)
	lg.end_battle()

	# 11. 被打疯（d2 的口子）：同回合满 2 人时顺延到下一回合
	lg = _fit_logic(s)
	var c0 := _cost_actor(lg, 0, 10000)
	var c1 := _cost_actor(lg, 1, 10000)
	var c2 := _cost_actor(lg, 2, 0)
	lg.start_turn()  # 第 1 回合不自己疯
	var t0 := XTianqiBrand.trigger(lg, c0)
	var t1 := XTianqiBrand.trigger(lg, c1)
	var t2 := XTianqiBrand.trigger(lg, c2)
	_fs(lg).floats["brand_fit"] = 0.99
	lg.start_turn()
	_check("t119.trigger_queue", t0[0] == "started" and t1[0] == "started" and t2[0] == "queued" and _fit_turns(lg, c2) == [2] and XTianqiBrand.fit_kinds(lg, c2) == ["daze"],
		[t0[0], t1[0], t2[0], _fit_turns(lg, c2)])
	# 返修（小A P3②）：发作中被打疯也顺延（和破防一样），不丢；间隔过了再发
	var t3 := XTianqiBrand.trigger(lg, c2)
	_check("t119.trigger_in_fit_queues", t3[0] == "queued" and XTianqiBrand._queued(XTianqiBrand.fight(lg), c2), t3[0])
	lg.end_battle()

	# 12. 生熟：首领战第一次是生的，打赢记首胜后同一键再打是熟的（几率 ×0.4、前 3 回合不掷、花样只三种）；心魔、五条悟试炼总是生的
	var fl := XTianqiBrand._firsts_rw(s)
	fl.erase("guardian:7")
	var cb := _boss("guardian:7", 7)
	var raw := XTianqiBrand.is_ripe(s, cb)
	fl["guardian:7"] = 1
	var ripe := XTianqiBrand.is_ripe(s, cb)
	var heart := XTianqiBrand.is_ripe(s, {"kind": "special", "key": "", "tier": 1})
	_check("t119.ripe_second", not raw and ripe and not heart, [raw, ripe, heart])
	fl.erase("guardian:7")
	# 真开两场 6 层守层者（敌群 39）：第一场生，记首胜后第二场熟，几率换成 ×0.4、花样换成三种
	fl.erase("guardian:6")
	var lr := XBattleLogic.new()
	lr.setup(39, s)
	var ar: XActor = lr.actors[0]
	_setb(ar, 10000, 6)
	var raw_p := XTianqiBrand.fit_chance(lr, ar)
	var raw_k := XTianqiBrand.fit_kinds(lr, ar)
	lr.end_battle()
	fl["guardian:6"] = 1
	var lr2 := XBattleLogic.new()
	lr2.setup(39, s)
	_check("t119.ripe_real", not bool(XTianqiBrand.fight(lr).ripe) and bool(XTianqiBrand.fight(lr2).ripe) and is_equal_approx(XTianqiBrand.fit_chance(lr2, ar), raw_p * 0.4)
		and raw_k.size() == 6 and XTianqiBrand.fit_kinds(lr2, ar) == ["daze", "misfire", "break_guard"], [raw_p, raw_k, XTianqiBrand.fit_kinds(lr2, ar)])
	lr2.end_battle()
	fl.erase("guardian:6")


## 行动入口最顶上：挂机、场内自动、手动三条路同一个结果（第十一节第 9 步：同一个种子下哑火三条路一样）
func _t119_entry() -> void:
	var s := _state()
	var got := []
	var prohibited = s.flags.get("HangUpProhibited", false)
	s.flags["HangUpProhibited"] = false
	for mode in ["hangup", "auto", "manual"]:
		var lg := _fit_logic(s)
		var a := _fit_at(lg, 0, 1)
		_fs(lg).mods["brand_fit_target"] = 1
		s.hang_up_active = mode == "hangup"
		s.hang_up_origin = Vector2i(1, 1) if mode == "hangup" else Vector2i(-1, -1)
		lg.auto = mode == "auto"
		var sc := XBattleScene.new()
		sc.logic = lg
		var cmd = await sc._command(a)
		got.append([mode, XHangUp.is_active(s), lg.auto, str(cmd[0].get(XTianqiBrand.FIT_KEY, "")) if cmd is Array and cmd[0] is Dictionary else "", lg.enemies.find(cmd[1]) if cmd is Array else -9])
		sc.free()
		lg.end_battle()
	s.hang_up_active = false
	s.hang_up_origin = Vector2i(-1, -1)
	s.flags["HangUpProhibited"] = prohibited
	_check("t119.entry_hangup", got[0][1] and got[0][3] == "misfire", got)
	_check("t119.entry_auto", got[1][2] and got[1][3] == "misfire", got)
	_check("t119.entry_same", got.all(func(g): return g[3] == "misfire" and g[4] == got[0][4] and g[4] >= 0), got)
	# 同一回合 decide、run_turn 走的也是它（自动战斗的专属出手、智能 AI 都在它后面）
	var lg2 := _fit_logic(s)
	var a2 := _fit_at(lg2, 0, 0)
	lg2.auto = true
	var d := lg2.decide(a2)
	_check("t119.entry_decide", str(d[0].get(XTianqiBrand.FIT_KEY, "")) == "daze", d)
	lg2.end_battle()


## 同种子可复现：同一个种子开两场满烙印的战斗，各跑 12 回合（run_turn，角色不给指令＝普攻），发作记录和双方血量逐项一样
func _t119_seed() -> void:
	var runs := []
	for i in 2:
		var s := _state()
		for x in s.battle_members():
			_setb(x, 10000, 6)
			x.recover_all()
		var lg := XBattleLogic.new()
		lg.setup(1, s, XBattleRandom.create(XRandomStream.hex64(20261117)))
		XTianqiBrand.fight(lg)["ripe"] = false
		for e in lg.enemies:
			var p: Array = (e as XEnemy).data().params.duplicate()
			p[0] = float(p[0]) + 1000000.0
			(e as XEnemy).zq_ref = {"p": p, "k": 1}
			e.param_mark_dirty()
			e.param_refresh()
			e.hp = e.mhp
		var hps := []
		for t in 12:
			if lg.is_over():
				break
			lg.run_turn({})
			hps.append((lg.actors + lg.enemies).map(func(x): return x.hp))
		runs.append([XTianqiBrand.fight(lg).fit_log.duplicate(true), hps])
		lg.end_battle()
	_check("t119.seed_same", runs[0][0] == runs[1][0] and runs[0][1] == runs[1][1], [runs[0][0].size(), runs[1][0].size()])
	_check("t119.seed_fits_happen", runs[0][0].size() >= 3, runs[0][0])


## 开关关着：不认这一场，不掷、不拦、不破防
func _t119_off() -> void:
	var s := _state()
	var lg := _cost_logic(s)
	var a: XActor = lg.actors[0]
	_setb(a, 10000, 6)
	var fs := FixStream.new()
	fs.domain = "rule"
	fs.floats["brand_fit"] = 0.0
	lg.random.rule = fs
	var logs := XTianqiBrand.start_turn(lg)
	_check("t119.off", logs.is_empty() and fs.reasons.get("brand_fit", 0) == 0 and lg.brand_forced(a).is_empty() and XTianqiBrand.taken_mult(a) == 1.0
		and XTianqiBrand.trigger(lg, a)[0] == "", fs.reasons)
	lg.end_battle()


## 第十一节第 9 步的无界面那一半：自动战斗连打同一只守层者 n 场（先生 n/4 场、再熟 n 场，各自换种子），满烙印全队，
## 每场最多 30 回合。不卡死（每场都结束或打满回合）、熟的场次里没有抽自己／六亲不认／断片、发作都在保护之内（同回合 ≤ 2 人、同一人间隔 ≥ 3）。
## 默认 40 场（专项里跑）；--t119-stress=1000 手动跑满稿里的 1000 场
func _t119_stress(n: int) -> void:
	var s := _state()
	var fl := XTianqiBrand._firsts_rw(s)
	var bad := []
	var fits := {"raw": 0, "ripe": 0}
	var kinds := {}
	var sources := {}
	var turns := 0
	for phase in ["raw", "ripe"]:
		var count := maxi(1, n / 4) if phase == "raw" else n
		for i in count:
			if phase == "raw":
				fl.erase("guardian:6")
			else:
				fl["guardian:6"] = 1
			for x in s.battle_members():
				_setb(x, 10000, 6)
				x.recover_all()
			var lg := XBattleLogic.new()
			lg.setup(39, s, XBattleRandom.create(XRandomStream.hex64(7000 + i + (100000 if phase == "ripe" else 0))))
			lg.auto = true
			var c := XTianqiBrand.fight(lg)
			if bool(c.ripe) != (phase == "ripe"):
				bad.append([phase, i, "ripe", c.ripe])
			var t := 0
			while not lg.is_over() and t < 30:
				lg.run_turn({})
				t += 1
			turns += t
			var per := {}
			var last := {}
			for r in c.get("fit_log", []):
				fits[phase] += 1
				kinds[r.kind] = int(kinds.get(r.kind, 0)) + 1
				sources[r.source] = int(sources.get(r.source, 0)) + 1
				per[int(r.turn)] = int(per.get(int(r.turn), 0)) + 1
				if phase == "ripe" and str(r.kind) in ["hit_self", "hit_ally", "blackout"]:
					bad.append([phase, i, "ripe_kind", r])
				if last.has(r.actor) and int(r.turn) - int(last[r.actor]) < 3:
					bad.append([phase, i, "gap", r])
				last[r.actor] = int(r.turn) + (1 if str(r.kind) == "blackout" else 0)
				if phase == "ripe" and int(r.turn) <= 3 and str(r.source) == "self":  # 被打疯（T120 灼痕）不管前几回合
					bad.append([phase, i, "ripe_open", r])
				if phase == "raw" and int(r.turn) <= 1 and str(r.source) == "self":
					bad.append([phase, i, "raw_open", r])
			if per.values().any(func(v): return v > 2):
				bad.append([phase, i, "per_round", per])
			lg.end_battle()
	fl.erase("guardian:6")
	print("T119_STRESS ", JSON.stringify({"battles": n + maxi(1, n / 4), "turns": turns, "fits": fits, "kinds": kinds, "sources": sources, "bad": bad.size()}))
	_check("t119.stress", bad.is_empty() and fits.raw + fits.ripe > 0, bad.slice(0, 5))


# ---- T120（T073-d2）：灼痕和烙实 ----

func _sear_kinds(lg: XBattleLogic, a: XActor) -> Array:
	return XTianqiBrand.fight(lg).get("fit_log", []).filter(func(r): return int(r.actor) == a.actor_id and str(r.source) == "sear").map(func(r): return str(r.kind))


func _t120_sear() -> void:
	var s := _state()
	# 1. 上限：60 ＋ 等级 × 0.5 ＋ 烙印 × 0.5，向下取整（稿第四节第 4 条那张表）
	var lg := _fit_logic(s)
	var a: XActor = lg.actors[0]
	var lv0 := a.level
	a.change_level(81)
	_setb(a, 0, 0)
	var c0 := XTianqiBrand.sear_cap(a)
	_setb(a, 4000, 2, false)
	var c40 := XTianqiBrand.sear_cap(a)
	_setb(a, 10000, 6)
	var c100 := XTianqiBrand.sear_cap(a)
	_setb(a, 4050, 3)
	var c405 := XTianqiBrand.sear_cap(a)  # 100 ＋ 20.25 → 120（向下取整）
	a.change_level(20)
	_setb(a, 0, 0)
	var c20 := XTianqiBrand.sear_cap(a)
	a.change_level(21)
	var c21 := XTianqiBrand.sear_cap(a)  # 60 ＋ 10.5 → 70
	_check("t120.cap", [c0, c40, c100, c405, c20, c21] == [100, 120, 150, 120, 70, 70], [c0, c40, c100, c405, c20, c21])
	a.change_level(lv0)
	_setb(a, 0, 0)
	# 2. 一下涨多少：没异化 3；各线、漩涡记的级；骑士、守层者、使徒按终焉
	var e: XEnemy = lg.enemies[0]
	var per := [XTianqiBrand.sear_per_hit(lg, e)]
	for t in ["qinran", "shigu", "huaxing", "zhongyan"]:
		lg.set_meta("xwar_alien", {"preset": "", "units": {e: {"tier": t}}})
		per.append(XTianqiBrand.sear_per_hit(lg, e))
	lg.set_meta("xrift_alien", {"units": {e: {"tier": "huaxing"}}})
	lg.remove_meta("xwar_alien")
	per.append(XTianqiBrand.sear_per_hit(lg, e))
	lg.remove_meta("xrift_alien")
	lg.set_meta("xdeath_alien", {"preset": "apostle20", "units": {e: {"tier": "shigu"}}})
	per.append(XTianqiBrand.sear_per_hit(lg, e))
	lg.remove_meta("xdeath_alien")
	e.horseman = {"rec": {}}
	per.append(XTianqiBrand.sear_per_hit(lg, e))
	e.horseman = {}
	var fin := int(XTianqiBrand.data().sear.per_hit["终焉"])  # T390：终焉一下读表（标定数）
	per.append(XTianqiBrand.sear_per_hit(lg, XEnemy.new().setup(_guardian_enemy(), 0, 100.0)) if _guardian_enemy() > 0 else fin)
	_check("t120.per_hit", per == [3, 6, 9, 12, fin, 12, fin, fin, fin], per)
	lg.end_battle()

	# 3. 一次行动对同一个人最多一次；换一次行动再算；同一次行动里两只敌人各算一次；没掉血（没命中、护盾全挡）不涨；不在出战里的不涨
	lg = _fit_logic(s)
	a = lg.actors[0]
	e = lg.enemies[0]
	var e2: XEnemy = lg.enemies[1] if lg.enemies.size() > 1 else XEnemy.new().setup(1, 1, 100.0)
	XTianqiBrand.act_begin(lg)
	a.hp = a.mhp
	var hp0 := a.hp
	a.hp -= 1.0
	XTianqiBrand.sear_hit(lg, e, a, hp0)
	XTianqiBrand.sear_hit(lg, e, a, hp0)  # 同一次行动第二段
	var once := XTianqiBrand.sear_of(lg, a)
	XTianqiBrand.sear_hit(lg, e2, a, hp0)  # 同一次行动里另一只敌人（反击那种）
	var two := XTianqiBrand.sear_of(lg, a)
	XTianqiBrand.act_begin(lg)
	XTianqiBrand.sear_hit(lg, e, a, a.hp)  # 生命没掉
	var none := XTianqiBrand.sear_of(lg, a)
	XTianqiBrand.sear_hit(lg, e, a, hp0)
	var again := XTianqiBrand.sear_of(lg, a)
	XTianqiBrand.sear_hit(lg, a, lg.actors[1], 999999.0)  # 队友打的不算
	var bench := XActor.new()
	XTianqiBrand.sear_hit(lg, e, bench, 999999.0)
	_check("t120.once_per_action", [once, two, none, again] == [3, 6, 6, 9] and XTianqiBrand.sear_of(lg, lg.actors[1]) == 0 and XTianqiBrand.sear_of(lg, bench) == 0, [once, two, none, again])
	lg.end_battle()

	# 4. 满了：满过几次 +1、槽清零（溢出不留）、这一回合还没行动就当场发作；已经行动过的顺延到下一回合开头
	lg = _fit_logic(s)
	_fs(lg).floats["brand_fit"] = 0.99  # 不自己疯
	a = _cost_actor(lg, 0, 10000)
	var b := _cost_actor(lg, 1, 10000)
	lg.start_turn()
	lg.start_turn()
	lg.current_order = [a]  # a 还没行动，b 行动过了
	var cap := XTianqiBrand.sear_cap(a)
	var f1 := XTianqiBrand.sear_add(lg, a, cap - 1)
	var f2 := XTianqiBrand.sear_add(lg, a, 5)
	var fb := XTianqiBrand.sear_add(lg, b, XTianqiBrand.sear_cap(b) + 40)
	var tl := XTianqiBrand.take_logs(lg)
	_check("t120.fill", f1 == 0 and f2 == 1 and fb == 1 and XTianqiBrand.sear_of(lg, a) == 0 and XTianqiBrand.sear_of(lg, b) == 0
		and XTianqiBrand.fills_of(lg, a) == 1 and XTianqiBrand.fills_of(lg, b) == 1, [f1, f2, fb, XTianqiBrand.sear_of(lg, a)])
	_check("t120.fill_now", _fit_turns(lg, a) == [2] and _sear_kinds(lg, a).size() == 1 and _fit_turns(lg, b).is_empty() and XTianqiBrand._queued(XTianqiBrand.fight(lg), b), [_fit_turns(lg, a), _fit_turns(lg, b)])
	_check("t120.fill_text", tl.filter(func(l): return str(l.get("type", "")) == "battle_text" and str(l.text).contains("发亮了")).size() == 2, tl)
	lg.start_turn()
	_check("t120.fill_next_turn", _fit_turns(lg, b) == [3], _fit_turns(lg, b))
	_check("t120.take_logs_once", XTianqiBrand.take_logs(lg).is_empty())
	lg.end_battle()

	# 5. 熟的战斗：被打疯照常、不管前 3 回合，花样只出发呆、哑火、破防
	var got := []
	for k in 6:
		lg = _fit_logic(s, true)
		_fs(lg).mods["brand_fit_kind"] = k
		a = _cost_actor(lg, 0, 10000)
		lg.start_turn()
		lg.current_order = [a]
		XTianqiBrand.sear_add(lg, a, XTianqiBrand.sear_cap(a))
		got.append_array(_sear_kinds(lg, a))
		lg.end_battle()
	_check("t120.ripe_kinds", got.size() == 6 and got.all(func(k): return k in ["daze", "misfire", "break_guard"]) and got.has("break_guard"), got)

	# 6. 和自己疯共用保护：自己疯过的人隔 2 回合内灼痕满了顺延（仍算满一次）；同回合已有 2 人发作时第三个顺延
	lg = _fit_logic(s)
	a = _fit_at(lg, 0, 0)  # 第 2 回合自己疯
	_fs(lg).floats["brand_fit"] = 0.99
	lg.turn = 3
	lg.current_order = [a]
	var fa := XTianqiBrand.sear_add(lg, a, XTianqiBrand.sear_cap(a))
	_check("t120.gap_shared", fa == 1 and XTianqiBrand.fills_of(lg, a) == 1 and _fit_turns(lg, a) == [2] and XTianqiBrand._queued(XTianqiBrand.fight(lg), a), _fit_turns(lg, a))
	lg.turn = 4
	lg.start_turn()  # 第 5 回合：过了间隔，顺延的发
	_check("t120.gap_later", _fit_turns(lg, a) == [2, 5] and _sear_kinds(lg, a).size() == 1, _fit_turns(lg, a))
	lg.end_battle()
	lg = _fit_logic(s)
	var p0 := _cost_actor(lg, 0, 10000)
	var p1 := _cost_actor(lg, 1, 10000)
	var p2 := _cost_actor(lg, 2, 0)
	lg.start_turn()
	lg.start_turn()  # 第 2 回合 p0、p1 自己疯
	_fs(lg).floats["brand_fit"] = 0.99
	lg.current_order = [p2]
	var fp := XTianqiBrand.sear_add(lg, p2, XTianqiBrand.sear_cap(p2))
	_check("t120.max_two_shared", fp == 1 and XTianqiBrand.fills_of(lg, p2) == 1 and _fit_turns(lg, p2).is_empty() and _fit_turns(lg, p0) == [2] and _fit_turns(lg, p1) == [2], _fit_turns(lg, p2))
	lg.start_turn()
	_check("t120.max_two_later", _fit_turns(lg, p2) == [3], _fit_turns(lg, p2))
	lg.end_battle()

	# 7. 倒下的人：满了照记、不发作；后面战斗里也不清
	lg = _fit_logic(s)
	a = lg.actors[0]
	lg.start_turn()
	XTianqiBrand.sear_add(lg, a, XTianqiBrand.sear_cap(a))
	_kill(a)
	var dead_fill := XTianqiBrand.sear_add(lg, a, XTianqiBrand.sear_cap(a))
	_check("t120.dead_fills_kept", dead_fill == 1 and XTianqiBrand.fills_of(lg, a) == 2, XTianqiBrand.fills_of(lg, a))
	a.remove_state(1)
	a.hp = a.mhp
	lg.end_battle()


## 找一只名字带【守层者】的敌人（没有就 0）
func _guardian_enemy() -> int:
	for e in XDB.table("Enemies"):
		if e is Dictionary and str(e.get("name", "")).begins_with("【守层者】"):
			return int(e.id)
	return 0


func _sear_gain(out: Array, a: XActor) -> int:
	var n := 0
	for r in out:
		if int(r[0]) == a.actor_id and str(r[2]) == "sear":
			n += int(r[1])
	return n


func _t120_settle() -> void:
	var s := _state()
	var bm := s.battle_members()
	var a: XActor = bm[0]
	var b: XActor = bm[1]
	var d: XActor = bm[2]
	var u: XActor = bm[3]
	_setb(a, 5000, 4)
	_setb(b, 5000, 4)
	_setb(d, 5000, 4)
	_setb(u, 4000, 2, false)
	XTianqiSave.section(s, "brand").firsts = {"guardian:12": 1, "horseman:war": 1}
	# 再打一只打赢过的守层者：fills a 1 次、b 3 次（封顶 2）、d 倒下 2 次、u 不刻印 40% 2 次；不刻印的人只有烙实这一路
	var lg := _logic(s, _boss("guardian:12", 12))
	XTianqiBrand.fight(lg).fills = {a.actor_id: 1, b.actor_id: 3, d.actor_id: 2, u.actor_id: 2}
	_kill(d)
	var out := XTianqiBrand.settle(lg)
	var ga := _sear_gain(out, a)
	var gb := _sear_gain(out, b)
	var gd := _sear_gain(out, d)
	_check("t120.settle_per_fill", ga == 75, out)
	_check("t120.settle_cap_two", gb == 150, out)
	_check("t120.settle_dead", gd == 150, out)
	_check("t120.uncarved_40_stays", XTianqiBrand.value(u) == 4000 and _sear_gain(out, u) == 0, [XTianqiBrand.value(u), out])
	d.remove_state(1)
	d.hp = d.mhp
	# 没满过的首领战：烙实 0（刻印的人再打的追赶照给，但没有 sear 那一笔）
	_setb(a, 5000, 4)
	lg = _logic(s, _boss("guardian:12", 12))
	out = XTianqiBrand.settle(lg)
	_check("t120.settle_zero", _sear_gain(out, a) == 0 and not out.any(func(r): return str(r[2]) == "sear"), out)
	# 不是首领战：满过也不变
	_setb(a, 5000, 4)
	lg = _logic(s, {"kind": "none", "key": "", "first_floor": 0})
	XTianqiBrand.fight(lg).fills = {a.actor_id: 2}
	out = XTianqiBrand.settle(lg)
	_check("t120.not_boss", out.is_empty() and XTianqiBrand.value(a) == 5000, out)
	lg = _logic(s, {"kind": "special", "key": "", "first_floor": 0})
	XTianqiBrand.fight(lg).fills = {a.actor_id: 2}
	out = XTianqiBrand.settle(lg)
	_check("t120.special", out.is_empty() and XTianqiBrand.value(a) == 5000, out)
	# 不刻印的人到 40% 后在首领战里照常发作（自己疯 4.5%、被打疯照常），烙印不变
	lg = _fit_logic(s)
	u = lg.actors[3]
	_setb(u, 4000, 2, false)
	var p := XTianqiBrand.fit_chance(lg, u)
	lg.start_turn()
	lg.current_order = [u]
	XTianqiBrand.sear_add(lg, u, XTianqiBrand.sear_cap(u))
	XTianqiBrand.fight(lg).kind = "boss"
	XTianqiBrand.fight(lg).key = "guardian:12"
	XTianqiBrand.settle(lg)
	_check("t120.uncarved_fits", is_equal_approx(p, 0.045) and _fit_turns(lg, u).size() == 1 and XTianqiBrand.value(u) == 4000, [p, _fit_turns(lg, u), XTianqiBrand.value(u)])
	lg.end_battle()
	XTianqiSave.section(s, "brand").firsts = {}


## 真的战斗：敌人普攻打中才涨（照稿 3 点），没命中不涨；灼痕槽界面读到这一格
func _t120_real() -> void:
	var s := _state()
	var lg := _fit_logic(s)
	_fs(lg).floats["brand_fit"] = 0.99
	var a: XActor = lg.actors[0]
	var e: XEnemy = lg.enemies[0]
	lg.start_turn()
	_fs(lg).floats["hit"] = 0.0
	_fs(lg).floats["evade"] = 0.99
	_fs(lg).floats["critical"] = 0.99
	a.hp = a.mhp
	var hp0 := a.hp
	var logs := lg.act(e, e.attack_skill(), a)
	var hit := XTianqiBrand.sear_of(lg, a)
	_check("t120.real_hit", a.hp < hp0 and hit == 3, [hp0, a.hp, hit, _types(logs)])
	# 护盾全挡：生命不掉、不涨
	var granted := XShieldLedger.grant(a, "t120", 1.0e9, 99)
	var hp2 := a.hp
	lg.act(e, e.attack_skill(), a)
	_check("t120.real_shield", granted > 0.0 and a.hp == hp2 and XTianqiBrand.sear_of(lg, a) == hit, [granted, hp2, a.hp, XTianqiBrand.sear_of(lg, a)])
	# 界面：出战每人一行，读当前值和上限
	var bar := XTianqiSearBar.make(lg, func(): return {})
	bar.refresh()
	_check("t120.ui_rows", bar.rows.size() == lg.actors.size() and int(bar.rows[0].value) == hit and int(bar.rows[0].cap) == XTianqiBrand.sear_cap(a), bar.rows)
	bar.free()
	lg.end_battle()

	# 真打一场（敌群 1 当首领战认、生的）：敌人血加厚、自动连打 30 回合，没异化的一下临时调到 20（小怪一下 3 点，30 回合满不了），
	# 灼痕真的会满、满了真的发作（来源 sear），发作记录守保护（同回合 ≤ 2 人、同一人间隔 ≥ 3）；把这一场当打赢结算，烙实按满过几次给（每人 ≤ 1.5%）
	var fl := XTianqiBrand._firsts_rw(s)
	fl["horseman:war"] = 1
	for x in s.battle_members():
		_setb(x, 5000, 4)
		x.recover_all()
	var ph: Dictionary = XTianqiBrand.data().sear.per_hit
	var ph0 := int(ph["没异化"])
	ph["没异化"] = 20
	var lr := XBattleLogic.new()
	lr.setup(1, s, XBattleRandom.create(XRandomStream.hex64(20261120)))
	var cr := XTianqiBrand.fight(lr)
	cr.kind = "boss"
	cr.key = "ev:t120"
	cr.ripe = false
	lr.auto = true
	for en in lr.enemies:
		var pp: Array = (en as XEnemy).data().params.duplicate()
		pp[0] = float(pp[0]) + 100000000.0
		(en as XEnemy).zq_ref = {"p": pp, "k": 1}
		en.param_mark_dirty()
		en.param_refresh()
		en.hp = en.mhp
	var t := 0
	while not lr.is_over() and t < 30:
		for x in lr.actors:
			if x.is_alive():
				x.hp = x.mhp  # 不让人倒下，专看灼痕
		lr.run_turn({})
		t += 1
	var c := XTianqiBrand.fight(lr)
	var sear_fits: Array = c.get("fit_log", []).filter(func(r): return str(r.source) == "sear")
	var total_fills := 0
	for k in c.fills:
		total_fills += int(c.fills[k])
	var per := {}
	var last := {}
	var bad := []
	for r in c.get("fit_log", []):
		per[int(r.turn)] = int(per.get(int(r.turn), 0)) + 1
		if last.has(r.actor) and int(r.turn) - int(last[r.actor]) < 3:
			bad.append(r)
		last[r.actor] = int(r.turn) + (1 if str(r.kind) == "blackout" else 0)
	print("T120_REAL ", JSON.stringify({"turns": t, "fills": c.fills, "sear_fits": sear_fits.size(), "all_fits": c.get("fit_log", []).size()}))
	_check("t120.real_fills", total_fills > 0 and not sear_fits.is_empty() and sear_fits.size() <= total_fills, [total_fills, sear_fits.size()])
	_check("t120.real_protect", bad.is_empty() and per.values().all(func(n): return n <= 2), [bad, per])
	var before := {}
	for x in lr.actors:
		before[x] = XTianqiBrand.value(x)
	var out := XTianqiBrand.settle(lr)
	var ok := true
	for x in lr.actors:
		var want := mini(int(c.fills.get(x.actor_id, 0)), 2) * 75
		if _sear_gain(out, x) != want:
			ok = false
	_check("t120.real_settle", ok and total_fills > 0, [c.fills, out])
	lr.end_battle()
	ph["没异化"] = ph0
	fl.erase("ev:t120")
	fl.erase("horseman:war")


func _t120_text() -> void:
	var txt := XTianqiBrand.TEXT_SEAR_FULL % ["x", XTianqiBrand.sear_name()]
	_check("t120.text", txt == "x 的印纹发亮了！" and not ["境", "锚", "异化", "病", "火"].any(func(w): return txt.contains(w)), txt)


func _t120_off() -> void:
	var s := _state()
	var lg := _cost_logic(s)
	var a: XActor = lg.actors[0]
	var e: XEnemy = lg.enemies[0]
	XTianqiBrand.act_begin(lg)
	XTianqiBrand.sear_hit(lg, e, a, 999999.0)
	var bar := XTianqiSearBar.make(lg, func(): return {})
	bar.refresh()
	_check("t120.off", XTianqiBrand.fight(lg).is_empty() and XTianqiBrand.sear_of(lg, a) == 0 and XTianqiBrand.sear_add(lg, a, 999) == 0 and XTianqiBrand.take_logs(lg).is_empty()
		and XTianqiBrand.sear_rows(lg).is_empty() and bar.rows.is_empty())
	bar.free()
	lg.end_battle()


# ---- T121：状态界面修行页的烙印行（XTianqiBrand.status_rows ← XGuide.panel_rows／detail_rows）----
func _t121_status() -> void:
	var s := _state()
	XState._become_current(s)
	var a: XActor = s.actor(s.party[0])
	_setb(a, 1500, 1, true)
	var r := XTianqiBrand.status_rows(s, a)
	_check("t121.row_carved", r.size() == 2 and str(r[0]).contains("「不染」") and str(r[0]).contains(" 15%") and str(r[0]).contains("伤害 \\C[3]+8%") and str(r[1]).contains("首领战获胜可加深") and str(r[1]).contains("「不染」上限 25%"), r)
	_setb(a, 2500, 1, true)
	r = XTianqiBrand.status_rows(s, a)
	_check("t121.row_stand", str(r[0]).contains("25%+") and str(r[1]).contains("已达「不染」上限") and str(r[1]).contains("心魔"), r)
	_setb(a, 4000, 2, false)
	r = XTianqiBrand.status_rows(s, a)
	_check("t121.row_sealed", not str(r[0]).contains("+\\C") and not str(r[0]).contains("40%+") and str(r[1]).contains("未刻印止步于「铸骨」（40%）") and str(r[1]).contains("刻印后"), r)
	_setb(a, 1200, 1, false)
	r = XTianqiBrand.status_rows(s, a)
	_check("t121.row_uncarved", str(r[1]).contains("仅在首领战受击时积累") and str(r[1]).contains("「铸骨」上限 40%"), r)
	_setb(a, 10000, 6, true)
	r = XTianqiBrand.status_rows(s, a)
	_check("t121.row_end", str(r[0]).contains("「逆命」") and str(r[0]).contains(" 100%") and str(r[0]).contains("+50%") and str(r[1]) == XTianqiBrand.TEXT_HOW_END, r)
	_check("t121.costs_all", XTianqiBrand.cost_names(a, s) == ["出头鸟", "皮薄", "虚不受补", "不合群", "烧命", "一条命"], XTianqiBrand.cost_names(a, s))
	_setb(a, 8000, 5, true)
	_check("t121.costs_revive_once", XTianqiBrand.cost_names(a, s) == ["出头鸟", "皮薄", "虚不受补", "不合群", "烧命", XTianqiBrand.TEXT_REVIVE_ONCE], XTianqiBrand.cost_names(a, s))
	_setb(a, 7000, 4, true)
	_check("t121.costs_revive_once_edge", not XTianqiBrand.cost_names(a, s).has(XTianqiBrand.TEXT_REVIVE_ONCE), XTianqiBrand.cost_names(a, s))
	_setb(a, 1000, 0, true)
	_check("t121.costs_none_at_node", XTianqiBrand.cost_names(a, s).is_empty(), XTianqiBrand.cost_names(a, s))
	# 接进修行页：第 4 页两行、第 5 页「烙印」段在难度对照前；不出「境」「锚」「真气」
	_setb(a, 4500, 3, true)
	var pr := "\n".join(XGuide.panel_rows(s, a).map(func(x): return str(x.get("text", ""))))
	var det := XGuide.detail_rows(s, a)
	var dr := "\n".join(det.map(func(x): return str(x.get("text", ""))))
	_check("t121.page4", pr.contains("烙印：") and pr.contains("「砥柱」") and pr.contains("45%") and pr.contains("加深："), pr)
	_check("t121.page5", str(det[0].text) == "烙印" and dr.contains("代价：出头鸟、皮薄、虚不受补") and dr.find("烙印") < dr.find("难度对照"), dr)
	var all := pr + "\n" + dr
	_check("t121.no_jing_anchor", not all.replace("秘境", "").contains("境") and not all.contains("锚") and not all.contains("真气"), all)


func _t121_status_off() -> void:
	var s := _state()
	XState._become_current(s)
	var a: XActor = s.actor(s.party[0])
	_setb(a, 4500, 3, true)
	var det := XGuide.detail_rows(s, a)
	var pr := "\n".join(XGuide.panel_rows(s, a).map(func(x): return str(x.get("text", ""))))
	_check("t121.off_empty", XTianqiBrand.status_rows(s, a).is_empty() and not pr.contains("烙印") and str(det[0].text).begins_with("难度对照"), [pr, det[0]])
	var sx := _state(false)
	var ax: XActor = sx.actor(sx.party[0]) if not sx.party.is_empty() else null
	_check("t121.xiyou_empty", ax == null or XTianqiBrand.status_rows(sx, ax).is_empty(), null)
