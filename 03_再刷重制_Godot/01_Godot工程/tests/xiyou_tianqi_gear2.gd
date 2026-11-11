extends Node
## 天启篇装备栏第二批（XTianqiGear 末段，交接单「装备栏下一批」）：
## 一、删除栏位清理（CLEAN_DELETED）：商店进货去掉删除栏位防具、原版档照旧；随机掉落抽到的在同品质、同等级段、保留栏位里重抽一次，池空不给。
## 二、坐骑（MOUNT_STATS）：七档品质的敏捷百分比、先制几率对上 gear_table.json；全队取上场最高一件不相加、助力位不算、总上限；
##     普通坐骑原来的属性不算；原版档坐骑照旧。
## 三、神器上限（ARTIFACT_CAP）：心钢／狂妄阶数 15 时按 10 算、"头顶"按 +300% 算；存档里的层数、盛名、成长不截；说明写「已达上限」；原版档不夹。
## 四、三个开关各设 false，行为回到第一批。
## 五、表里的设计数值不带 4（与 03_转换工具/天启篇数据校验.py 的 gear_table 检查同一套）。
## 验收方式：天启篇新规则没有 mv_oracle 参照，按交接单的占位表逐项比；反向验证清单在 04_验证/反向验证清单/xiyou_tianqi_gear2.json。

var results: Array = []

## 旧 0～15 档里各取一个落在七档 0～6 的（XQuality 头注：1 普通、2 优秀、3 精良、4 史诗、6 传说、8 不朽、12 神话）
const LEGACY_FOR_GRADE := [1, 2, 3, 4, 6, 8, 12]
const HORSE := 4472  # 白马
const DELETED := 3582  # 屈服的嘤嘤怪（灵兽，删除栏位）


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	XTianqiGear.reload()
	_table()
	_shop()
	_drops()
	_mount()
	_preempt()
	_artifact()
	_switches()
	XState.current = null
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 天启篇状态（同 xiyou_tianqi_gear：只写规则版本，不跑开局）；设成当前档
func _tianqi_state() -> XState:
	var s := XState.new_game_blank()
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "jiusi", "lineup": []}
	XState.current = s
	return s


func _legacy_state() -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	return s


func _horse(grade: int) -> Dictionary:
	var h := XGear.template("armor", HORSE).duplicate(true)
	var meta: Dictionary = h.get("meta", {}).duplicate()
	meta.quality = str(LEGACY_FOR_GRADE[grade])
	h.meta = meta
	return h


func _wear(a: XActor, item: Dictionary) -> void:
	var etype := int(item.etypeId)
	a.equips[a.equip_slots().find(etype)] = item
	a.refresh_passive()
	a.param_mark_dirty()


func _undress(a: XActor, etype: int) -> void:
	a.equips[a.equip_slots().find(etype)] = null
	a.refresh_passive()
	a.param_mark_dirty()


# ---- 五、表 ----
func _no_four(v, path: String, out: Array) -> void:
	if v is Dictionary:
		for k in v:
			if k != "version":
				_no_four(v[k], path + "/" + str(k), out)
	elif v is Array:
		for i in v.size():
			_no_four(v[i], "%s/%d" % [path, i], out)
	elif v is float or v is int:
		var t := str(int(v)) if float(v) == floorf(float(v)) else str(v)
		if t.contains("4"):
			out.append("%s=%s" % [path, t])


func _table() -> void:
	var t := XTianqiGear.table()
	var m: Dictionary = t.get("mount", {})
	_check("table_mount", m.get("agi_pct", []) == [5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 33.0]
		and m.get("preempt_pct", []) == [3.0, 5.0, 6.0, 8.0, 10.0, 12.0, 15.0] and float(m.get("preempt_cap_pct", 0)) == 33.0, m)
	var c: Dictionary = t.get("artifact_cap", {})
	_check("table_cap", float(c.get("heartsteel_stage", 0)) == 10.0 and float(c.get("hubris_stage", 0)) == 10.0
		and float(c.get("crown_bonus_pct", 0)) == 300.0, c)
	var fours := []
	_no_four(t, "", fours)
	_check("table_no_four", fours.is_empty(), fours)
	_check("table_draft", bool(t.get("draft", false)))


# ---- 一、删除栏位清理 ----
func _shop() -> void:
	var goods := [[2, DELETED, 0, 0], [2, HORSE, 0, 0], [1, 1, 0, 0], [0, 1, 0, 0]]
	_tianqi_state()
	var kept: Array = XShopStock.prepare_policy(goods.duplicate(true)).map(func(g): return [int(g[0]), int(g[1])])
	XShopStock.close_policy()
	_check("shop_deleted_gone", kept == [[2, HORSE], [1, 1], [0, 1]], kept)
	_check("deleted_armor", XTianqiGear.deleted_armor(DELETED) and not XTianqiGear.deleted_armor(HORSE) and not XTianqiGear.deleted_armor(7900))
	_legacy_state()
	var legacy: Array = XShopStock.prepare_policy(goods.duplicate(true))
	XShopStock.close_policy()
	_check("shop_legacy_same", legacy.size() == 4, legacy.size())


## 和 DELETED 同组（品质、等级段）的保留栏位防具：直接扫 Armors 表（不依赖哪只敌人会掉）
func _same_group_pool(rec: Dictionary) -> Array:
	var out := []
	var want := XTianqiGear.drop_group(rec)
	var t: Array = XDB.table("Armors")
	for i in range(1, t.size()):
		var r = t[i]
		if r is Dictionary and str(r.get("name", "")) != "" and XTianqiGear.ORDER.has(int(r.get("etypeId", 0))) \
				and int(r.etypeId) != XTianqiGear.ARTIFACT and XTianqiGear.drop_group(r) == want:
			out.append([3, i])
		if out.size() >= 8:
			break
	return out


func _drops() -> void:
	_tianqi_state()
	var rec := XDB.rec("Armors", DELETED)
	var pool := _same_group_pool(rec)
	_check("reroll_pool_found", not pool.is_empty(), XTianqiGear.drop_group(rec))
	# 固定随机：0.5 → 池子中间那件
	var drops := [{"kind": 3, "id": DELETED}, {"kind": 1, "id": 1}]
	var out := XTianqiGear.reroll_drops(drops, func(): return 0.5, pool)
	var got: Dictionary = out[0] if not out.is_empty() else {}
	var got_rec := XDB.rec("Armors", int(got.get("id", 0)))
	var cands := XTianqiGear.reroll_pool(rec, pool)
	_check("reroll_kept_slot", out.size() == 2 and not cands.is_empty() and int(got.kind) == 3 and int(got.id) == int(cands[cands.size() / 2][1])
		and XTianqiGear.ORDER.has(int(got_rec.get("etypeId", 0))) and int(got.get("tianqi_reroll", 0)) == DELETED, out)
	_check("reroll_same_grade", XQuality.grade(got_rec) == XQuality.grade(rec) and XTianqiGear.drop_group(got_rec) == XTianqiGear.drop_group(rec),
		[XTianqiGear.drop_group(got_rec), XTianqiGear.drop_group(rec)])
	_check("reroll_other_untouched", out.size() == 2 and int(out[1].kind) == 1 and int(out[1].id) == 1, out)
	var empty := XTianqiGear.reroll_drops(drops, func(): return 0.5, [])
	_check("reroll_empty_pool_drops", empty.size() == 1 and int(empty[0].kind) == 1, empty)
	# 掉落表做的池：只有武器、防具；重抽池里全是同组、保留栏位的
	var all_pool := XTianqiGear.drop_pool()
	_check("drop_pool_built", not all_pool.is_empty() and all_pool.all(func(r): return int(r[0]) in [2, 3]), all_pool.size())
	_check("drop_pool_filtered", XTianqiGear.reroll_pool(rec).all(func(r):
		var o := XDB.rec("Weapons" if int(r[0]) == 2 else "Armors", int(r[1]))
		return XTianqiGear.drop_group(o) == XTianqiGear.drop_group(rec) and (int(r[0]) == 2 or not XTianqiGear.deleted_armor(int(r[1])))))
	_legacy_state()
	_check("reroll_legacy_same", XTianqiGear.reroll_drops(drops, func(): return 0.5, pool) == drops)


# ---- 二、坐骑 ----
func _mount() -> void:
	var s := _tianqi_state()
	var a := s.actor(1)
	a.change_level(80)
	_undress(a, XTianqiGear.MOUNT)
	var base := a.param(6)
	var agi_ok := []
	var pre_ok := []
	var agi: Array = [5, 10, 15, 20, 25, 30, 33]
	var pre: Array = [3, 5, 6, 8, 10, 12, 15]
	for g in 7:
		var h := _horse(g)
		_check("grade_%d" % g, XQuality.grade(h) == g, XQuality.grade(h))
		var row := XTianqiGear.mount_row(h)
		pre_ok.append(float(row.preempt) == float(pre[g]))
		_wear(a, h)
		agi_ok.append(is_equal_approx(a.param(6), roundf(base * (1.0 + agi[g] / 100.0))))
	_check("mount_agi_table", agi_ok.all(func(x): return x), [agi_ok, base])
	_check("mount_preempt_table", pre_ok.all(func(x): return x), pre_ok)
	# 普通坐骑原来的属性、特性不算：穿着白马时其余七项能力值和不穿一样
	_undress(a, XTianqiGear.MOUNT)
	var bare := range(8).map(func(i): return a.param(i))
	_wear(a, _horse(0))
	var worn := range(8).map(func(i): return a.param(i))
	var same := true
	for i in 8:
		if i != 6 and not is_equal_approx(float(bare[i]), float(worn[i])):
			same = false
	_check("mount_old_effects_off", same and not a.trait_objects().any(func(o): return int(o.get("etypeId", 0)) == XTianqiGear.MOUNT), [bare, worn])
	# 原版档：坐骑照原版数据（白马自带的属性照算，没有表里的百分比）
	var old := _legacy_state()
	var oa := old.actor(1)
	oa.change_level(80)
	_undress(oa, XTianqiGear.MOUNT)
	var ob := range(8).map(func(i): return oa.param(i))
	var horse := XGear.template("armor", HORSE)
	_wear(oa, horse)
	var expect := range(8).map(func(i): return float(ob[i]) + float(horse.params[i]))
	var got := range(8).map(func(i): return oa.param(i))
	_check("mount_legacy", not XTianqiGear.plain_mount(horse) and XTianqiGear.mount_preempt(old) == 0.0
		and oa.trait_objects().any(func(o): return is_same(o, horse)), [expect, got])


func _preempt() -> void:
	var w := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id)).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jiusi", w)
	XTianqi.take_pending()
	for id in w:
		s.add_actor(int(id))
	XState.current = s
	s.battle_slots = [w[0], w[1], w[2], w[3], w[4]]
	_wear(s.actor(w[0]), _horse(2))  # 精良 6%
	_wear(s.actor(w[1]), _horse(4))  # 传说 10%
	_check("preempt_best_not_sum", is_equal_approx(XTianqiGear.mount_preempt(s), 0.10), XTianqiGear.mount_preempt(s))
	_wear(s.actor(w[4]), _horse(6))  # 助力位的神话 15%：不算
	_check("preempt_helper_ignored", s.helper() != null and is_equal_approx(XTianqiGear.mount_preempt(s), 0.10), XTianqiGear.mount_preempt(s))
	var r := XTianqiGear.apply_preempt(s, {"pre": 0.05, "sur": 0.03})
	_check("preempt_added", is_equal_approx(float(r.pre), 0.15) and is_equal_approx(float(r.sur), 0.03), r)
	r = XTianqiGear.apply_preempt(s, {"pre": 0.30, "sur": 0.03})
	_check("preempt_cap", is_equal_approx(float(r.pre), 0.33), r)
	r = XTianqiGear.apply_preempt(s, {"pre": 0.50, "sur": 0.03})
	_check("preempt_cap_not_lower", is_equal_approx(float(r.pre), 0.50), r)
	var old := _legacy_state()
	for id in w.slice(0, 2):
		old.add_actor(int(id))
	old.battle_slots = [w[0], w[1], 0, 0, 0]
	_wear(old.actor(w[0]), _horse(6))
	XState.current = old
	_check("preempt_legacy", XTianqiGear.apply_preempt(old, {"pre": 0.05, "sur": 0.03}).pre == 0.05)


# ---- 三、神器上限 ----
func _artifact() -> void:
	var s := _tianqi_state()
	var n15 := XHeartsteel.stage_need(15)
	var heart := XGear.template("armor", XHeartsteel.ARMOR).duplicate(true)
	heart[XHeartsteel.STACKS] = n15
	var lev := XGear.template("armor", XHeartsteel.LEVIATHAN).duplicate(true)
	lev[XHeartsteel.STACKS] = n15
	_check("heart_stage_raw", XHeartsteel.stage(heart) == 15 and XHeartsteel.stacks(heart) == n15)
	_check("heart_capped", is_equal_approx(XHeartsteel.hp_rate(heart), 2.0) and is_equal_approx(XHeartsteel.hp_rate(lev), 2.1),
		[XHeartsteel.hp_rate(heart), XHeartsteel.hp_rate(lev)])
	var hub := XGear.template("armor", XHubris.ARMOR).duplicate(true)
	hub[XHubris.FAME] = n15
	var atx := XGear.template("armor", XHubris.ATARAXIA).duplicate(true)
	_check("hubris_capped", is_equal_approx(XHubris.rate_for(hub, XHubris.growth(hub)), 2.1) and is_equal_approx(XHubris.rate_for(atx, n15), 2.2)
		and XHubris.growth(hub) == n15, XHubris.rate_for(hub, XHubris.growth(hub)))
	var rows: Array = XGrowthHelp.heart_rows(heart)
	_check("heart_cap_text", str(rows[0]).contains(XTianqiGear.CAP_TEXT) and str(rows[1]).contains("已达上限"), rows.slice(0, 2))
	var hrows: Array = XGrowthHelp.hubris_rows(hub)
	_check("hubris_cap_text", str(hrows[0]).contains(XTianqiGear.CAP_TEXT), hrows.slice(0, 2))
	var below := XGear.template("armor", XHeartsteel.ARMOR).duplicate(true)
	below[XHeartsteel.STACKS] = XHeartsteel.stage_need(9)
	_check("heart_below_cap", is_equal_approx(XHeartsteel.hp_rate(below), 1.9) and not str(XGrowthHelp.heart_rows(below)[0]).contains(XTianqiGear.CAP_TEXT))
	# "头顶"：成长 900 → 按 300 算；实例上的成长值不截
	var crown := XGear.template("armor", XDemonCrown.ARMOR).duplicate(true)
	crown[XDemonCrown.BONUS] = 900.0
	XDemonCrown.describe(crown)
	var t21: Array = (crown.traits as Array).filter(func(t): return bool(t.get("_codexCrown", false)))
	_check("crown_capped", t21.size() == 8 and t21.all(func(t): return is_equal_approx(float(t.value), 4.0)) and float(crown[XDemonCrown.BONUS]) == 900.0,
		t21.map(func(t): return t.value))
	_check("crown_cap_text", str(crown.note).contains("＋300%" + XTianqiGear.CAP_TEXT), str(crown.note).right(80))
	# 原版档不夹
	_legacy_state()
	_check("legacy_heart", is_equal_approx(XHeartsteel.hp_rate(heart), 2.5) and is_equal_approx(XHubris.rate_for(hub, n15), 2.6))
	XDemonCrown.describe(crown)
	t21 = (crown.traits as Array).filter(func(t): return bool(t.get("_codexCrown", false)))
	_check("legacy_crown", t21.all(func(t): return is_equal_approx(float(t.value), 10.0)) and not str(crown.note).contains(XTianqiGear.CAP_TEXT),
		t21.map(func(t): return t.value))


# ---- 四、开关 ----
func _switches() -> void:
	var s := _tianqi_state()
	XTianqiGear.CLEAN_DELETED = false
	var kept: Array = XShopStock.prepare_policy([[2, DELETED, 0, 0]])
	XShopStock.close_policy()
	var drops := [{"kind": 3, "id": DELETED}]
	_check("switch_clean_off", kept.size() == 1 and XTianqiGear.reroll_drops(drops, func(): return 0.5, []) == drops)
	XTianqiGear.CLEAN_DELETED = true
	XTianqiGear.MOUNT_STATS = false
	var a := s.actor(1)
	a.change_level(80)
	var horse := XGear.template("armor", HORSE)
	_wear(a, horse)
	_check("switch_mount_off", not XTianqiGear.plain_mount(horse) and a.trait_objects().any(func(o): return is_same(o, horse))
		and XTianqiGear.mount_preempt(s) == 0.0)
	XTianqiGear.MOUNT_STATS = true
	_check("switch_mount_on", XTianqiGear.plain_mount(horse) and not a.trait_objects().any(func(o): return is_same(o, horse)))
	XTianqiGear.ARTIFACT_CAP = false
	var heart := XGear.template("armor", XHeartsteel.ARMOR).duplicate(true)
	heart[XHeartsteel.STACKS] = XHeartsteel.stage_need(15)
	_check("switch_cap_off", is_equal_approx(XHeartsteel.hp_rate(heart), 2.5) and XTianqiGear.crown_bonus(900.0) == 900.0)
	XTianqiGear.ARTIFACT_CAP = true
	_check("switch_cap_on", is_equal_approx(XHeartsteel.hp_rate(heart), 2.0) and XTianqiGear.crown_bonus(900.0) == 300.0)
