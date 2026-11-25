extends Node
## 【cc·T518】天启篇宝珠新表（XTianqiOrbs，T013 2G）：
## 一、天启篇：18 族、五阶 3/5/6/8/10%（元素族）、1/2/3/5/6%（其余百分比行）；水风两族表外物品 3301～3310 读得到、能镶；
##     镶嵌照旧写原表数进装备（存档不改写），读装备（stat_equips、特性、元素增幅、总账 orb 桶）按新表；同族 3 颗上限连元素增幅一起算；
##     存读档后存档原文仍是原表数、读出来仍是新表；取下回到镶前；鉴定不出旧宝珠；怪物掉落、地图事件不再给旧宝珠（换残片）；
##     物品说明、插槽页显示新表效果。
## 二、西游档：配置、物品、地图、掉落、装备读数全部原样（同一对象）。
## 三、回退开关 TABLE＝false：天启篇也回原表。
const Kit := preload("res://tests/lib/tq_save_kit.gd")
const DAGGER := 972
const FIRE5 := 2956    # 烈焰·归真：原表 火焰伤害 +60%、魔法攻击 +30%
const WATER3 := 3303   # 沧澜·通玄（新）
const FRAG := 2531
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


## 一把带 n 个武器宝珠孔的匕首
func _blade(s: XState, tag: String, n := 1) -> Dictionary:
	var g := XGear.create("weapon", DAGGER, s)
	g["instanceId"] = "t518_" + tag
	g["augmentSlots"] = []
	for i in n:
		g.augmentSlots.append(XOrbs.WEAPON_TYPE)
	XOrbs.ensure(g)
	return g


func _inlay(s: XState, g: Dictionary, id: int, slot := 0) -> String:
	s.gain_item(id, 1)
	return XOrbs.apply(g, XDB.rec("Items", id), slot, s)


func _mat_orb_trait(list: Array) -> Array:
	return list.filter(func(t): return t is Dictionary and t.has("_codexOrb") and int(t.code) == 21 and int(t.dataId) == 4).map(func(t): return snappedf(float(t.value), 0.0001))


func _amp(e: Dictionary, k: String) -> float:
	return snappedf(float(e.get("yep", {}).get("elementAmplify", {}).get(k, 0.0)), 0.0001)


## 把匕首戴到 1 号位成员武器槽，返回 [成员, 槽号]
func _wear(s: XState, g: Dictionary) -> Array:
	var a: XActor = s.members()[0]
	var slot := a.equip_slots().find(1)
	a.equips[slot] = g
	a.refresh_passive()
	a.param_mark_dirty()
	return [a, slot]


func _legacy_gifts(map: Dictionary) -> Array:
	var raw: Dictionary = XDB.table("CodexOrbs")
	var out := []
	for ev in map.get("events", []):
		if ev is Dictionary:
			for p in ev.get("pages", []):
				for c in p.get("list", []):
					if int(c.code) == 126 and raw.legacyRefund.has(str(int(c.parameters[0]))):
						out.append(int(c.parameters[0]))
	return out


func _run() -> void:
	seed(20261125)
	var kit := Kit.new("xiyou_tianqi_orbs")
	XTianqiOrbs.TABLE = true
	XTianqiOrbs.clear_cache()
	var s := Kit.new_game("jianxian")

	# ---- 一、天启篇 ----
	var cfg := XOrbs.config()
	_check("tq_18_families", cfg.families.size() == 18 and cfg.items.size() == 90, [cfg.families.size(), cfg.items.size()])
	_check("tq_no_legacy_identify", int(cfg.legacyShare) == 0)
	_check("tq_edge_r1", cfg.items["2947"].effects == ["物理伤害+3%", "物理攻击+1%"], cfg.items["2947"].effects)
	_check("tq_edge_r5", cfg.items["2951"].effects == ["物理伤害+10%", "物理攻击+6%"], cfg.items["2951"].effects)
	_check("tq_guard_r4", cfg.items["3000"].effects == ["物理防御+5%", "魔法防御+5%"], cfg.items["3000"].effects)
	_check("tq_heal_r3", cfg.items["2994"].effects[0] == "治疗效果+6%", cfg.items["2994"].effects)
	var ranks := []
	for r in 5:
		ranks.append(XTianqiOrbs.line_value("Element Amplify 2", r + 1))
		ranks.append(XTianqiOrbs.line_value("MAT", r + 1))
	_check("tq_rank_table", ranks == [3, 1, 5, 2, 6, 3, 8, 5, 10, 6], ranks)
	var w1 := XDB.rec("Items", 3301)
	var f5 := XDB.rec("Items", 3310)
	_check("tq_new_items", str(w1.get("name", "")) == "宝珠·沧澜·凝砂" and str(f5.get("name", "")) == "宝珠·啸风·归真"
		and XOrbs.spec(3301) == {"family": 16, "rank": 1, "effects": ["水系伤害+3%", "魔法攻击+1%", "魔法防御+1%"]}
		and XOrbs.spec(3310).family == 17 and XOrbs.slot_of(3310) == XOrbs.WEAPON_TYPE
		and XOrbs.parse(f5).attach.get(XOrbs.WEAPON_TYPE, []).has("Element Amplify 15: +10%"), [w1.get("name"), f5.get("name"), XOrbs.spec(3301)])
	_check("tq_new_item_refund", XOrbs.refund(3305) == 31 and XOrbs.is_orb_item(3306))
	var r1 := XDB.rec("Items", 2947)
	_check("tq_item_text", str(r1.note).contains("text=物理伤害+3% size=") and not str(r1.note).contains("text=物理伤害+10% size=")
		and str(r1.note).contains("Element Amplify 1: +10%") and str(r1.description).contains("物理伤害+3%；物理攻击+1%"), r1.description)

	# 镶嵌：存档写原表、读按新表
	var g := _blade(s, "a")
	var base_amp := _amp(g, "2")
	_check("tq_inlay_ok", _inlay(s, g, FIRE5) == "")
	_check("tq_raw_unchanged", _mat_orb_trait(g.traits) == [1.3] and _amp(g, "2") == snappedf(base_amp + 0.6, 0.0001), [g.traits, _amp(g, "2")])
	var worn := _wear(s, g)
	var a: XActor = worn[0]
	var view: Dictionary = a.stat_equips().filter(func(e): return str(e.get("instanceId", "")) == "t518_a")[0]
	_check("tq_view_values", _mat_orb_trait(view.traits) == [1.06] and _amp(view, "2") == snappedf(base_amp + 0.1, 0.0001), [_mat_orb_trait(view.traits), _amp(view, "2")])
	_check("tq_all_traits", _mat_orb_trait(a.all_traits()) == [1.06], _mat_orb_trait(a.all_traits()))
	var ob_on := XDamage.own_bonus(a, 2)
	_check("tq_ledger_orb_bucket", XTianqiLedger.orb_amplify(view) == {"2": 0.1}, XTianqiLedger.orb_amplify(view))
	var rows := XGearDetail.socket_rows(g).map(func(r): return str(r[0]))
	_check("tq_socket_row", rows.any(func(t): return t.contains("火焰伤害+10%") and t.contains("魔法攻击+6%")), rows)

	# 存读档：存档原文仍是原表数，读回来仍按新表
	var back := kit.roundtrip()
	var a2: XActor = back.members()[0] if back != null else null
	var g2: Dictionary = a2.equips[worn[1]] if a2 != null else {}
	_check("tq_roundtrip_raw", _mat_orb_trait(g2.get("traits", [])) == [1.3] and _amp(g2, "2") == snappedf(base_amp + 0.6, 0.0001), [g2.get("traits"), _amp(g2, "2")])
	var view2: Array = a2.stat_equips().filter(func(e): return str(e.get("instanceId", "")) == "t518_a") if a2 != null else []
	_check("tq_roundtrip_view", view2.size() == 1 and _mat_orb_trait(view2[0].traits) == [1.06] and _amp(view2[0], "2") == snappedf(base_amp + 0.1, 0.0001))
	_check("tq_roundtrip_bonus", a2 != null and absf(XDamage.own_bonus(a2, 2) - ob_on) < 1e-9, [ob_on, XDamage.own_bonus(a2, 2) if a2 != null else null])
	s = back
	a = a2
	g = g2

	# 取下：回到镶前
	_check("tq_remove", XOrbs.apply(g, {}, 0, s) == "" and _mat_orb_trait(g.traits) == [] and _amp(g, "2") == base_amp and s.item_count(FIRE5) >= 1)

	# 水系新宝珠
	var gw := _blade(s, "w")
	_check("tq_water_inlay", _inlay(s, gw, WATER3) == "")
	var vw: Dictionary = XTianqiOrbs.views([gw])[0]
	_check("tq_water_view", _amp(vw, "14") == snappedf(_amp(gw, "14"), 0.0001) and _amp(vw, "14") >= 0.06 and _mat_orb_trait(vw.traits) == [1.03], [_amp(vw, "14"), vw.traits])

	# 同族 3 颗上限（元素增幅也算）：4 把各镶一颗烈焰·归真，只算阶高、靠前的 3 把
	var four := []
	for i in 4:
		var gi := _blade(s, "c%d" % i)
		_inlay(s, gi, FIRE5)
		four.append(gi)
	var vs := XTianqiOrbs.views(four)
	var amp_sum := 0.0
	for i in 4:
		amp_sum += _amp(vs[i], "2") - _amp(XGear.create("weapon", DAGGER, s), "2")
	_check("tq_cap_amp", absf(amp_sum - 0.3) < 1e-6, amp_sum)
	_check("tq_cap_trait_identity", is_same(vs[3].traits.filter(func(t): return t.has("_codexOrb"))[0], four[3].traits.filter(func(t): return t.has("_codexOrb"))[0])
		and not is_same(vs[0].traits.filter(func(t): return t.has("_codexOrb"))[0], four[0].traits.filter(func(t): return t.has("_codexOrb"))[0]))
	_check("tq_cap_filter", XOrbs.filter_traits(vs.reduce(func(acc, e): return acc + e.traits, []), four).filter(func(t): return t.has("_codexOrb") and int(t.dataId) == 4).size() == 3)

	# 鉴定不出旧宝珠
	s.gain_item(3031, 200)
	var idf := XOrbs.identify(s, 3031, 200)
	var got: Array = idf.get("outputs", []).map(func(x): return int(x.id))
	_check("tq_identify_new_only", idf.ok and got.all(func(id): return cfg.items.has(str(id))) and got.any(func(id): return id >= 3301), got)

	# 掉落、地图
	var drop_in := [{"kind": 1, "id": 2052, "chance": 1.0}, {"kind": 1, "id": 2947, "chance": 1.0}, {"kind": 2, "id": 2052, "chance": 1.0}]
	_check("tq_drop_rows", XTianqiOrbs.drop_rows(s, drop_in).map(func(r): return [int(r.kind), int(r.id)]) == [[1, 2947], [2, 2052]])
	XTextFix.clear_cache()
	var m64 := XDB.map(64)
	var frag_cmds := []
	var toasts := []
	for p in m64.events[1].pages:
		for k in p.list.size():
			var c: Dictionary = p.list[k]
			if int(c.code) == 126 and int(c.parameters[0]) == FRAG:
				frag_cmds.append(int(c.parameters[3]))
				toasts.append(str(p.list[k + 1].parameters[0]))
	_check("tq_map_no_legacy", _legacy_gifts(m64).is_empty() and _legacy_gifts(XDB.map(132)).is_empty() and _legacy_gifts(XDB.map(155)).is_empty())
	_check("tq_map_fragments", frag_cmds.size() >= 4 and frag_cmds.all(func(n): return n == 9) and toasts.all(func(t): return t.contains("窃取了9枚宝珠残片！") and not t.contains("黑荆棘")), [frag_cmds, toasts])

	# ---- 三、回退开关 ----
	XTianqiOrbs.TABLE = false
	XTianqiOrbs.clear_cache()
	XTextFix.clear_cache()
	_check("off_config_raw", is_same(XOrbs.config(), XDB.table("CodexOrbs")) and XOrbs.config().families.size() == 16)
	_check("off_no_new_items", XDB.rec("Items", 3301).is_empty())
	_check("off_item_text", str(XDB.rec("Items", 2947).note).contains("text=物理伤害+10% size="))
	_check("off_map_legacy", not _legacy_gifts(XDB.map(64)).is_empty())
	var gx := _blade(s, "x")
	_inlay(s, gx, FIRE5)
	_check("off_view_identity", is_same(XTianqiOrbs.views([gx])[0], gx))
	XTianqiOrbs.TABLE = true
	XTianqiOrbs.clear_cache()

	# ---- 二、西游档 ----
	var x := XState.new_game(3, 1, [8, 9, 10])
	XState.current = x
	XTextFix.sync_mode()
	XTextFix.clear_cache()
	var xc := XOrbs.config()
	_check("xy_config_raw", is_same(xc, XDB.table("CodexOrbs")) and xc.families.size() == 16 and int(xc.legacyShare) == 50)
	_check("xy_no_new_items", XDB.rec("Items", 3301).is_empty() and XDB.rec("Items", 3310).is_empty())
	_check("xy_item_text", is_same(XDB.rec("Items", 2947), XDB.table("Items")[2947]))
	_check("xy_map_legacy", _legacy_gifts(XDB.map(64)).size() == 4)
	_check("xy_drop_rows", XTianqiOrbs.drop_rows(x, drop_in) == drop_in)
	var gy := _blade(x, "y")
	_inlay(x, gy, FIRE5)
	var lst := [gy]
	_check("xy_view_identity", is_same(XTianqiOrbs.views(lst), lst))
	var wy := _wear(x, gy)
	var ay: XActor = wy[0]
	_check("xy_all_traits_raw", _mat_orb_trait(ay.all_traits()) == [1.3], _mat_orb_trait(ay.all_traits()))
	_check("xy_socket_row_plain", not XGearDetail.socket_rows(gy).any(func(r): return str(r[0]).contains("火焰伤害+")))

	XState.current = null
	XTextFix.sync_mode()
	XTextFix.clear_cache()
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
