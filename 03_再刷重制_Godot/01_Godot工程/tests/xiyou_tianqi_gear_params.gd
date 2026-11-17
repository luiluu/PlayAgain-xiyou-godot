extends Node
## 【cc·T104】天启篇期四装备八项统一入口 XTianqiGear.effective_params（基础数值重构 v0.4 第五节第 1、6 条，第十节 T012-b 第 3、8 条）：
## 一、总开关关着（默认）：天启篇存档上每件装备都原样返回实例的 params（同一个数组），属性、战力、说明卡逐字节同原来。
## 二、开着、天启篇存档：
##     新底子＝标准线(1＋等级×98÷90)×部位系数×品质系数（主攻按原版物攻／魔攻高的那项，一样高各一半；魔法上限 0）；
##     生成浮动不算（同一件掷两次结果一样）；词缀固定属性、镶嵌固定值按记录重算再乘换算比；
##     差值退路只在有符文之语／随机镶嵌时算、夹在新底子 ±10%；七印装备照表、武器 ×1.1；法宝、坐骑、神器、奖励装备不读表。
## 三、开着但西游档：原样返回。
## 四、同一组数（稿第十节 T012-b 第 8 条）：角色属性（_param_plus）、灵族武器本体、战力评分、说明卡、排序、商店对比、新皮装备页都读到 effective_params。
## 五、缓存：镶嵌、改八项之后重算；rows_state 的 gear 行跟总开关一致。
## 读的表：tianqi_data/gear_base.json、base_line.json。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
const DAGGER := 972  # 魔钢匕首：40 级、旧档 1、物攻 56、敏捷 10、浮动 80
const ARMOR := 852  # 轻便战甲：盔甲、40 级
const STONE := 258  # 劣质磨刀石：镶嵌固定物攻 +2
const FABAO := 13  # 大罗剑胎（法宝，不读表）
const AFFIX := 85  # 天外天·巴雷特（武器词缀）

var results: Array = []
var gb: Dictionary = {}
var line: Dictionary = {}


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	seed(20261117)
	XTianqiBase.clear_cache()
	XTianqiGear.clear_effective_cache()
	XConfig.path_override = "user://test_t104_gear_params/options.json"  # 不读写本机真实设置（战力开关）
	gb = _json("res://modes/xiyou/tianqi_data/gear_base.json")
	line = _json("res://modes/xiyou/tianqi_data/base_line.json").get("line", {})
	_check("default_off", not XTianqiBase.PHASE4)
	_off()
	_on()
	_xiyou()
	_same_numbers()
	_cache()
	XTianqiBase.PHASE4 = false
	XTianqiGear.clear_effective_cache()
	XState.current = null
	XConfig.path_override = ""
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f != null else null
	return d if d is Dictionary else {}


func _gear(kind: String, id: int, s: XState) -> Dictionary:
	var g := XGear.create(kind, id, s)
	g["instanceId"] = "t104_%d_%d" % [id, randi()]
	return g


## 独立按表算的新底子（不调 XTianqiGear.new_base）
func _expect_base(item: Dictionary, ref: Array, mult := 1.0, qiyin := false) -> Array:
	var lv := clampi(int(str(item.meta.req_level)), 0, 90)
	var conv := 1.0 + lv * 98.0 / 90.0
	var lv_atk := float(line.A0) + float(line.A1) * conv
	var lv_hp := lv_atk * float(line.hp_mult)
	var g := float(gb.grades[XTianqiAffixRoll.QUALITY_KEYS[XQuality.grade(item)]])
	var slot: Dictionary = {}
	for k in gb.slots:
		if int(gb.slots[k].etype) == int(item.etypeId):
			slot = gb.slots[k]
	var atk := float(ref[2])
	var mat := float(ref[4])
	var sa := 1.0 if atk > mat else (0.5 if atk == mat else 0.0)
	var sm := 1.0 if mat > atk else (0.5 if atk == mat else 0.0)
	var c := func(k: String) -> float: return float(slot.get(k, 0.0)) * g * mult
	var out := [lv_hp * c.call("hp"), 0.0, lv_atk * c.call("atk") * sa, lv_atk * c.call("def"), lv_atk * c.call("atk") * sm,
		lv_atk * c.call("def"), lv_atk * c.call("agi"), lv_atk * c.call("luk")]
	# D182（T082）：表里没有、原版不为零的副属性 ＝ 标准线 × 本部位最大系数 × 品质 × sub_stat.ratio（七印不给）
	var sub := 0.0 if qiyin else float(gb.get("sub_stat", {}).get("ratio", 0.0))
	var k_main := 0.0
	for k in ["atk", "hp", "def", "agi", "luk"]:
		k_main = maxf(k_main, float(slot.get(k, 0.0)))
	for i in 8:
		if out[i] == 0.0 and float(ref[i]) != 0.0 and sub > 0.0:
			out[i] = (lv_hp if i <= 1 else lv_atk) * k_main * g * sub * signf(float(ref[i]))
	return out


func _ratio(item: Dictionary, i: int) -> float:
	var cols := ["hp", "hp", "atk", "def", "atk", "def", "agi", "luk"]
	return float(gb.ratio[str(clampi(int(str(item.meta.req_level)), 0, 90))][cols[i]])


func _affix_sum(item: Dictionary) -> Array:
	var out := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for a in item.get("affixIds", []):
		var r := XDB.rec(str(a.table), int(a.id))
		for i in 8:
			out[i] += float(r.params[i])
	return out


func _expect(item: Dictionary, extra := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]) -> Array:
	var tpl := XGear.template(str(item.kind), int(item.base))
	var nb := _expect_base(item, tpl.params)
	var af := _affix_sum(item)
	var out := []
	for i in 8:
		out.append(roundf(maxf(0.0, nb[i] + _ratio(item, i) * (af[i] + float(extra[i])))))
	return out


func _near(a: Array, b: Array, tol := 0.0) -> bool:
	if a.size() != 8 or b.size() != 8:
		return false
	for i in 8:
		if absf(float(a[i]) - float(b[i])) > tol:
			return false
	return true


# ---- 一、关着 ----
func _off() -> void:
	XTianqiBase.PHASE4 = false
	var s := Kit.new_game("jianxian")
	var items := [_gear("weapon", DAGGER, s), _gear("armor", ARMOR, s), XGear.template("armor", FABAO), XDB.rec("Weapons", DAGGER)]
	var same := true
	for it in items:
		same = same and is_same(XTianqiGear.effective_params(it), it.params) and not XTianqiGear.applies(it)
	_check("off_same_array", same)
	_check("off_flat_ratio_1", XTianqiGear.flat_ratio(items[0], 2) == 1.0)
	_check("off_rows_state", XTianqiBase.rows_state().get("gear") == false)


# ---- 二、开着、天启篇 ----
func _on() -> void:
	XTianqiBase.PHASE4 = true
	XTianqiGear.clear_effective_cache()
	var s := Kit.new_game("jianxian")
	_check("on_rows_state", XTianqiBase.rows_state().get("gear") == true)
	var d1 := _gear("weapon", DAGGER, s)
	var d2 := _gear("weapon", DAGGER, s)
	var e1 := XTianqiGear.effective_params(d1)
	_check("weapon_base", _near(e1, _expect(d1)), [e1, _expect(d1), d1.params, d1.affixIds])
	_check("weapon_main_atk_no_mat_no_mp", float(e1[2]) > 0.0 and float(e1[4]) == 0.0 and float(e1[1]) == 0.0 and float(e1[0]) == 0.0, [e1, d1.params, d1.affixIds, d2.params, d2.affixIds])
	# 浮动不算：两次掷出的原 params 不同（浮动 ±80），词缀一样时有效八项一样
	_check("variance_rolled", d1.params != d2.params and JSON.stringify(d1.affixIds) == JSON.stringify(d2.affixIds), [d1.params, d2.params])
	if JSON.stringify(d1.affixIds) == JSON.stringify(d2.affixIds):
		_check("variance_dropped", XTianqiGear.effective_params(d2) == e1, [d1.params, d2.params])
	var ar := _gear("armor", ARMOR, s)
	var ea := XTianqiGear.effective_params(ar)
	_check("armor_base", _near(ea, _expect(ar)), [ea, _expect(ar)])
	_check("armor_hp_def_mdf", float(ea[0]) > float(ar.params[0]) and float(ea[3]) > 0.0 and float(ea[3]) == float(ea[5]) and float(ea[2]) == 0.0, ea)
	# 词缀固定属性：按 affixIds 重拼（天外天·巴雷特 85：生命 1500、魔法 1000、物攻 200、敏捷 150）× 换算比
	var af := d1.duplicate(true)
	af.instanceId = "t104_af"
	XGear.combine(af, XDB.rec("Weapons", AFFIX), "prefix")
	af.affixIds.append({"table": "Weapons", "id": AFFIX, "kind": "prefix"})
	var eaf := XTianqiGear.effective_params(af)
	_check("affix_fixed_scaled", _near(eaf, _expect(af)) and float(eaf[1]) > 0.0 and float(eaf[6]) > 0.0, [eaf, _expect(af)])
	# 镶嵌固定值按记录重算 × 换算比
	var up := d1.duplicate(true)
	up.instanceId = "t104_up"
	XGearUpgrade.apply_effects(up, XDB.rec("Items", STONE), true, s)
	var eu := XTianqiGear.effective_params(up)
	_check("upgrade_fixed_scaled", _near(eu, _expect(up, [0, 0, 2, 0, 0, 0, 0, 0])), [eu, _expect(up, [0, 0, 2, 0, 0, 0, 0, 0])])
	# 差值退路：有符文之语时，多出来的乘换算比夹在新底子 ±10%
	var nb := _expect_base(d1, XGear.template("weapon", DAGGER).params)
	var rw := d1.duplicate(true)
	rw.instanceId = "t104_rw"
	rw.runewordName = "测试"
	rw.params[2] = float(rw.params[2]) + 100000.0
	var er := XTianqiGear.effective_params(rw)
	_check("resid_clamped_up", absf(float(er[2]) - roundf(float(_expect(d1)[2]) + nb[2] * 0.1)) <= 1.0, [er, nb])
	rw.params[2] = float(rw.params[2]) - 200000.0
	er = XTianqiGear.effective_params(rw)
	_check("resid_clamped_down", absf(float(er[2]) - roundf(float(_expect(d1)[2]) - nb[2] * 0.1)) <= 1.0, er)
	# T148：新底子为 0 的项（MP）不再被 ±10% 夹成 0，符文之语加的数按换算比放行
	var rm := d1.duplicate(true)
	rm.instanceId = "t148_rm"
	rm.runewordName = "测试"
	rm.params[1] = float(rm.params[1]) + 500.0
	var erm := XTianqiGear.effective_params(rm)
	var want_mp := roundf(float(_expect(d1)[1]) + XTianqiGear.flat_ratio(rm, 1) * 500.0)
	_check("resid_zero_base_passes", float(nb[1]) == 0.0 and float(erm[1]) > 0.0 and absf(float(erm[1]) - want_mp) <= 1.0, [erm, want_mp, nb])
	# T082（T104 小A 核第 3 条）：认得出的符文之语按 XRunewords.template_id 找回模板，加的八项当固定加值乘换算比、不夹 ±10%
	var rtpl := {}
	for r in XDB.table("Runewords"):
		if r is Dictionary and XRunewords.template_id(r, d1) != 0:
			var cand := XDB.rec("Weapons", XRunewords.template_id(r, d1))
			if absf(float(cand.get("params", [0, 0, 0, 0, 0, 0, 0, 0])[2])) > 0.0:
				rtpl = cand
				break
	var rk := d1.duplicate(true)
	rk.instanceId = "t082_rw"
	rk.runewordName = str(rtpl.get("name", ""))
	for i in 8:
		rk.params[i] = float(rk.params[i]) + float(rtpl.get("params", [0, 0, 0, 0, 0, 0, 0, 0])[i])
	var erk := XTianqiGear.effective_params(rk)
	var want_rk := _expect(d1, rtpl.get("params", [0, 0, 0, 0, 0, 0, 0, 0]))
	_check("runeword_template_scaled", not rtpl.is_empty() and XTianqiGear.runeword_params(rk) == rtpl.params and _near(erk, want_rk, 1.0), [erk, want_rk, rtpl.get("name")])
	# T148：upgrade_fixed 的 current 判定看前面已镶的固定值（0 → 前一块加成非 0 后，current 块生效）
	var cz := XTianqiGear.upgrade_fixed({"kind": "weapon", "base": DAGGER, "upgrades": []}, [0, 0, 0, 0, 0, 0, 0, 0])
	_check("upgrade_fixed_empty", cz.fixed == [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0] and not cz.random)
	var plain := d1.duplicate(true)
	plain.instanceId = "t104_plain"
	plain.params[2] = float(plain.params[2]) + 100000.0
	_check("resid_dropped_without_history", XTianqiGear.effective_params(plain) == e1)
	# 七印：80 级神话、武器 ×1.1、实例八项（占位 1）一样高 → 物攻魔攻各一半
	var qy := {"kind": "weapon", "base": float(DAGGER), "etypeId": 1, "wtypeId": 1, "params": [1, 1, 1, 1, 1, 1, 1, 1],
		"meta": {"req_level": "80", "quality": "14"}, "qiyin": {"kind": "weapon"}, "instanceId": "t104_qy"}
	var eq := XTianqiGear.effective_params(qy)
	var nq := _expect_base(qy, qy.params, 1.1, true)
	_check("qiyin_weapon", _near(eq, nq.map(func(v): return roundf(v))) and float(eq[2]) == float(eq[4]) and float(eq[2]) > 1.0, [eq, nq])
	var qs := qy.duplicate(true)
	qs.etypeId = 4
	qs.kind = "armor"
	qs.erase("wtypeId")
	qs.atypeId = 1
	qs.qiyin = {"kind": "set"}
	qs.instanceId = "t104_qs"
	var es := XTianqiGear.effective_params(qs)
	_check("qiyin_set_no_mult", _near(es, _expect_base(qs, qs.params, 1.0, true).map(func(v): return roundf(v))), es)
	qs.qiyin.true_seal = true
	qs.instanceId = "t104_qs2"
	_check("qiyin_true_seal_mult", _near(XTianqiGear.effective_params(qs), _expect_base(qs, qs.params, 1.1, true).map(func(v): return roundf(v))))
	# 不读表：法宝、奖励装备、没有等级需求的
	var fb := XGear.template("armor", FABAO)
	_check("fabao_not_read", is_same(XTianqiGear.effective_params(fb), fb.params) and not XTianqiGear.applies(fb))
	var rwd := ar.duplicate(true)
	rwd[XTianqiRewards.FIELD] = {"kind": "seal"}
	_check("reward_not_read", is_same(XTianqiGear.effective_params(rwd), rwd.params))
	var nolv := ar.duplicate(true)
	nolv.meta.erase("req_level")
	_check("no_req_level_not_read", is_same(XTianqiGear.effective_params(nolv), nolv.params))
	# 数据库原件（商店、图鉴里的记录）也读表
	var rec := XDB.rec("Weapons", DAGGER)
	var er2 := XTianqiGear.effective_params(rec)
	_check("db_record_read", _near(er2, _expect_base(rec, XGear.template("weapon", DAGGER).params).map(func(v): return roundf(v))), er2)


# ---- 三、开着但西游档 ----
func _xiyou() -> void:
	XTianqiBase.PHASE4 = true
	var s := XState.new_game_blank()
	XState.current = s
	var d := XGear.create("weapon", DAGGER, s)
	_check("xiyou_same_array", is_same(XTianqiGear.effective_params(d), d.params) and XTianqiGear.flat_ratio(d, 2) == 1.0)


# ---- 四、同一组数 ----
func _same_numbers() -> void:
	XTianqiBase.PHASE4 = true
	XTianqiGear.clear_effective_cache()
	var s := Kit.new_game("jianxian")
	var a: XActor = s.members()[0]
	var d := _gear("weapon", DAGGER, s)
	var eff := XTianqiGear.effective_params(d)
	var slot := a.equip_slots().find(1)
	a.equips[slot] = null
	a.refresh_passive()
	a.param_mark_dirty()
	var bare := a.param_plus(2)
	a.equips[slot] = d
	a.refresh_passive()
	a.param_mark_dirty()
	var boosted := a.passive_values("passiveWPNM%02d" % int(d.wtypeId)).is_empty()
	_check("actor_no_weapon_passive", boosted)  # 下一条只在没有武器类型放大被动时成立
	if boosted:
		_check("actor_param_plus", is_equal_approx(a.param_plus(2) - bare, float(eff[2])), [a.param_plus(2), bare, eff])
	_check("weapon_body", is_equal_approx(XRaceBattle.weapon_body(d, 2), float(eff[2])), [XRaceBattle.weapon_body(d, 2), eff])
	_check("gear_query_sort", is_equal_approx(XGearQuery.metric(d, {"sort": "param2"}), float(eff[2])))
	_check("shop_worst", XShop._worst_equipped_param(a, 1, 2) == int(eff[2]))
	_check("skin_equip_param_of", XSkinEquipPage.param_of(d, 2) == int(eff[2]) and XSkinEquipPage.main_param(d) == 2)
	var rows := XHelpCard.desc_params(d, 1)
	var hit := false
	for r in rows:
		if r is Array and str(r[0]).ends_with(":" + XHelpCard._num(eff[2])):
			hit = true
	_check("help_card_rows", hit, rows.map(func(r): return r[0] if r is Array else r))
	# 战力：开着读这件 ＝ 关着读一件八项换成有效八项的复制品
	XConfig.set_flag("codexPowerEnabled", true)
	if XPower.enabled():
		XPower.clear_cache()
		var on_total := float(XPower.equipment(d).get("total", 0.0))
		XTianqiBase.PHASE4 = false
		var copy := d.duplicate(true)
		copy.params = eff.duplicate()
		var off_total := float(XPower.equipment(copy).get("total", 0.0))
		XTianqiBase.PHASE4 = true
		_check("power_same", on_total > 0.0 and is_equal_approx(on_total, off_total), [on_total, off_total])
	else:
		_check("power_same", false, "战力开关没开成")
	a.equips[slot] = null
	a.refresh_passive()


# ---- 五、缓存 ----
func _cache() -> void:
	XTianqiBase.PHASE4 = true
	XTianqiGear.clear_effective_cache()
	var s := Kit.new_game("jianxian")
	var d := _gear("weapon", DAGGER, s)
	var before := XTianqiGear.effective_params(d).duplicate()
	XGearUpgrade.apply_effects(d, XDB.rec("Items", STONE), true, s)  # 原地改：upgrades 变长、params 改值
	var after := XTianqiGear.effective_params(d)
	_check("cache_refresh_on_upgrade", float(after[2]) > float(before[2]), [before, after])
	d.meta.req_level = "60"
	_check("cache_refresh_on_level", float(XTianqiGear.effective_params(d)[2]) > float(after[2]))
	XTianqiBase.PHASE4 = false
	_check("cache_not_used_when_off", is_same(XTianqiGear.effective_params(d), d.params))
