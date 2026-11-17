extends Node
## 【cc·T164】光耀度（D186）：宝石效果＝基础值×换算比，只显示、不改数值。
## D190：光耀度＝换算比÷80 级换算比，80 级＝100%、最高 100%；图鉴数字＝光耀 100% 时的效果；XTianqiGear.CAP_80 关回旧口径。
## D190b（Kyo 11-18）：光耀度是每颗宝石的，写在宝石那一行（「红宝石 光耀87%　物理攻击 +11」），装备头行没有；加多列的宝石一列一行；预览「这颗宝石镶在这件装备上」；文字里不出现「满额」。
## 一、期四关着：所有显示函数返回空，镶嵌图鉴不画说明行，详情／插槽行数同原来，八项原样。
## 二、开着：宝石行的光耀度＝该列换算比÷80 级换算比，加成＝换算比×基础值，且与 effective_params 里宝石那份一致；
##     镶嵌图鉴只多一行说明；镶嵌预览给本件的光耀度和加成；开关开／关各一遍，八项数值、effective_params 不因显示函数改变。
const Kit := preload("res://tests/lib/tq_save_kit.gd")
const DAGGER := 972
const STONE := 258  # 劣质磨刀石：镶嵌固定物攻 +2
var results: Array = []


class FixedStream extends XRandomStream:
	var value := 0.5
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return value if kind == "float" else 2147483648
	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return lo + floori((hi - lo + 1) * value)


## 真战斗伤害：这件装备戴在 1 号位成员身上，普攻敌人第 1 只（随机数固定 0.5），返回各次命中的伤害＋物攻
func _damage(s: XState, g: Dictionary) -> Array:
	XState.current = s
	var a: XActor = s.members()[0]
	var slot := a.equip_slots().find(1)
	a.equips[slot] = g
	a.refresh_passive()
	a.param_mark_dirty()
	var rand := XBattleRandom.create("0000000000000001")
	rand.rule = FixedStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(2, s, rand)
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	logic.start_turn()
	var u: XBattler = logic.actors[0]
	var e: XEnemy = logic.enemies[0]
	var hits := [float(u.param(2))]
	for l in logic.act(s.members()[0], XDB.rec("Skills", 1), e):
		if l.get("type") == "hit" and not bool(l.get("missed", false)):
			hits.append(float(l.hp))
	a.equips[slot] = null
	a.refresh_passive()
	return hits


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _rows_text(rows: Array) -> String:
	return "\n".join(rows.map(func(r): return str(r[0])))


func _run() -> void:
	XMessageBox.auto = true
	seed(20261117)
	XTianqiBase.clear_cache()
	XTianqiGear.clear_effective_cache()
	XConfig.path_override = "user://test_t164_gem_power/options.json"
	var s := Kit.new_game("jianxian")
	var g := XGear.create("weapon", DAGGER, s)
	g["instanceId"] = "t164_g"
	XGearUpgrade.apply_effects(g, XDB.rec("Items", STONE), true, s)

	# ---- 关着 ----
	XTianqiBase.PHASE4 = false
	XTianqiGear.clear_effective_cache()
	var params_off: Array = (XTianqiGear.effective_params(g) as Array).duplicate()
	_check("off_inactive", not XTianqiGemPower.active(g))
	_check("off_text_empty", XTianqiGemPower.gems(g).is_empty() and XTianqiGemPower.gem_lines(g, [0.0, 0.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0]).size() == 1)
	_check("off_detail_rows_same", XTianqiGemPower.detail_rows(g).is_empty() and XTianqiGemPower.upgrade_lines(g, 0, 20).is_empty())
	_check("off_preview_empty", XTianqiGemPower.preview_rows(g, XDB.rec("Items", STONE), "upgrade").is_empty())
	var detail_off := XHelpCard.detail_rows(g, 300.0)
	var socket_off := XGearDetail.socket_rows(g)
	_check("off_gem_base_zero", XTianqiGear.gem_base(g) == [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var book_off := XInlayBook.status_ops(XInlayBook.recipes()[0][0], 0)
	_check("off_book_no_note", not JSON.stringify(book_off).contains("光耀"))

	# ---- 开着 ----
	XTianqiBase.PHASE4 = true
	XTianqiGear.clear_effective_cache()
	_check("on_active", XTianqiGemPower.active(g))
	var ratio_atk := XTianqiGear.flat_ratio(g, 2)
	var pow_atk := XTianqiGemPower.power_of(g, 2)
	_check("g_level_le_80", int(str(g.meta.get("req_level", "0"))) <= 80, g.meta)
	var base := XTianqiGear.gem_base(g)
	_check("gem_base_stone_plus2", float(base[2]) == 2.0, base)
	var want_pct := "%d%%" % roundi(pow_atk * 100.0)
	var gl := XTianqiGemPower.gems(g)
	_check("gems_one_stone", gl.size() == 1 and str(gl[0].name) != "" and gl[0].base == base, gl)
	var gname := str(gl[0].name)
	var lines := XTianqiGemPower.gem_lines(g, base)
	var want_line := "光耀%s　%s +%d" % [want_pct, str(XDB.system().terms.params[2]), roundi(2.0 * ratio_atk)]
	_check("gem_line_power_and_actual", lines.size() == 1 and lines[0] == want_line, [lines, want_line])
	_check("gem_line_with_name", XTianqiGemPower.gem_lines(g, base, gname) == [gname + " " + want_line], XTianqiGemPower.gem_lines(g, base, gname))
	var drows := XHelpCard.detail_rows(g, 300.0)
	_check("detail_has_gem_line", _rows_text(drows).contains(gname + " " + want_line) and not _rows_text(drows).contains("光耀度"), _rows_text(drows))
	_check("detail_prefix_unchanged", drows.size() > detail_off.size())
	var srows := XGearDetail.socket_rows(g)
	_check("socket_has_line", _rows_text(srows).contains(want_line) and not _rows_text(srows).contains("光耀度"), _rows_text(srows))
	_check("socket_row_count", srows.size() == socket_off.size() + 1, [srows.size(), socket_off.size()])
	# 全部文字不出现「满额」
	var all_text := _rows_text(drows) + _rows_text(srows) + XTianqiGemPower.NOTE + XTianqiGemPower.PREVIEW_HEAD + JSON.stringify(XInlayBook.status_ops(XInlayBook.recipes()[0][0], 0))
	_check("no_manE_word", not all_text.contains("满额"))
	# 与 effective_params 的宝石那份一致：同一件去掉镶嵌记录，物攻差 = 换算比×2
	var bare := g.duplicate(true)
	bare.instanceId = "t164_bare"
	bare.upgrades = []
	var diff := float(XTianqiGear.effective_params(g)[2]) - float(XTianqiGear.effective_params(bare)[2])
	_check("matches_effective_params", absf(diff - 2.0 * ratio_atk) <= 1.0, [diff, ratio_atk])
	# 无宝石：什么都不加
	var none := XGear.create("weapon", DAGGER, s)
	none["instanceId"] = "t164_none"
	_check("no_gem_no_rows", XTianqiGemPower.gems(none).is_empty() and XTianqiGemPower.detail_rows(none).is_empty() and XTianqiGemPower.gem_lines(none, XTianqiGear.gem_base(none)).is_empty())
	# 预览：磨刀石镶在这件上
	var pv := XTianqiGemPower.preview_rows(none, XDB.rec("Items", STONE), "upgrade")
	var want_pv := "光耀%d%%　%s +%d" % [roundi(XTianqiGemPower.power_of(none, 2) * 100.0), str(XDB.system().terms.params[2]), roundi(2.0 * XTianqiGear.flat_ratio(none, 2))]
	_check("preview_stone", pv.size() == 2 and str(pv[0][0]) == XTianqiGemPower.PREVIEW_HEAD and str(pv[1][0]).lstrip("　 ") == want_pv, pv)
	# 预览按「待镶这颗自己加成的列」算，不读已镶宝石那一列（g 已镶物攻磨刀石，预览一颗只加物防的）
	var def_only := [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0]
	var want_def := "光耀%d%%" % roundi(XTianqiGemPower.power_of(g, 3) * 100.0)
	var def_lines := XTianqiGemPower.gem_lines(g, def_only)
	_check("preview_uses_preview_column", def_lines.size() == 1 and def_lines[0].begins_with(want_def) and def_lines[0].contains(str(XDB.system().terms.params[3])), [def_lines, want_def])
	# 一颗宝石加多列：名字一行，每列一行各写各的光耀度，不写范围
	var multi := [1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0]
	var ml := XTianqiGemPower.gem_lines(g, multi, "多项宝石")
	_check("multi_col_one_line_each", ml.size() == 6 and ml[0] == "多项宝石" and ml.slice(1).all(func(l): return str(l).begins_with("光耀") and not str(l).contains("～")), ml)
	# 同一颗宝石镶在越高级的装备上越光耀：40 级 < 80 级＝100%
	var hi_g := none.duplicate(true)
	hi_g.meta = (hi_g.meta as Dictionary).duplicate()
	hi_g.meta["req_level"] = "40"
	XTianqiGear.clear_effective_cache()
	var l40 := XTianqiGemPower.gem_lines(hi_g, base)[0] as String
	hi_g.meta["req_level"] = "80"
	XTianqiGear.clear_effective_cache()
	var l80 := XTianqiGemPower.gem_lines(hi_g, base)[0] as String
	_check("same_gem_brighter_on_higher_gear", l80.begins_with("光耀100%") and not l40.begins_with("光耀100%"), [l40, l80])
	# 新皮肤详情牌：宝石行（含名字行）留「说明」，不被拆进「自带」
	var core_v2: bool = XUiSkin.CORE_V2
	XUiSkin.CORE_V2 = true
	var secs := XSkinTemplatePage.help_sections([{"text": "红宝石 光耀87%　物理攻击 +11"}, {"text": "　光耀87%　生命 +30"}, {"text": "生命:+100"}])
	XUiSkin.CORE_V2 = core_v2
	var head_sec := ""
	var line_sec := ""
	for sec in secs:
		for r in sec.rows:
			if str(r.text).begins_with("红宝石"):
				head_sec = sec.title
			elif str(r.text).contains("生命 +30"):
				line_sec = sec.title
	_check("skin_gem_lines_same_section", head_sec != "" and head_sec == line_sec and head_sec != "自带", [head_sec, line_sec])
	var card := {"sections": []}
	XTianqiGemPower.dress_card(none, XDB.rec("Items", STONE), "upgrade", -1, card)
	_check("dress_card_section", card.sections.size() == 1 and card.sections[0].title == "镶在这件装备上" and str(card.sections[0].rows[0].text).begins_with("光耀"), card)
	# 宝珠、符文之语：基础值进逐项
	var orb_rec: Dictionary = {}
	for id in range(1, 6000):
		var r := XDB.rec("Items", id)
		if not r.is_empty() and not XOrbs.parse(r).attach.is_empty():
			orb_rec = r
			break
	if not orb_rec.is_empty():
		var gs: Array = none.get("augmentSlots", [])
		_check("augment_preview_runs", gs.is_empty() or XTianqiGemPower.preview_lines(none, orb_rec, "augment", 0) is Array)
	# P2（小A 复核）：宝珠预览——有效孔出光耀度＋逐项，孔号越界／孔没类型短路返回空
	var aug_type := ""
	var aug_rec: Dictionary = {}
	for id in range(1, 6000):
		var orec := XDB.rec("Items", id)
		if orec.is_empty():
			continue
		var attach: Dictionary = XOrbs.parse(orec).attach
		for k in attach.keys():
			if not XTianqiGemPower.touched(XTianqiGear.orb_lines_fixed(attach[k])).is_empty():
				aug_type = str(k)
				aug_rec = orec
				break
		if aug_type != "":
			break
	_check("augment_orb_found", aug_type != "")
	var ag := none.duplicate(true)
	ag["instanceId"] = "t164_aug"
	ag["augmentSlots"] = [aug_type, ""]
	var apv := XTianqiGemPower.preview_lines(ag, aug_rec, "augment", 0)
	_check("augment_preview_lines", apv.size() >= 2 and apv[0] == XTianqiGemPower.PREVIEW_HEAD and str(apv[1]).begins_with("光耀"), apv)
	_check("augment_empty_type_short_circuit", XTianqiGemPower.preview_lines(ag, aug_rec, "augment", 1).is_empty())
	_check("augment_slot_out_of_range_short_circuit", XTianqiGemPower.preview_lines(ag, aug_rec, "augment", 9).is_empty() and XTianqiGemPower.preview_lines(ag, aug_rec, "augment", -1).is_empty())
	_check("augment_empty_rec_short_circuit", XTianqiGemPower.preview_lines(ag, {}, "augment", 0).is_empty())
	# P2：符文之语——模板八项进 gem_base，逐项行出得来
	var rtpl := {}
	for r in XDB.table("Runewords"):
		if r is Dictionary and XRunewords.template_id(r, none) != 0:
			var cand := XDB.rec("Weapons", XRunewords.template_id(r, none))
			if absf(float(cand.get("params", [0, 0, 0, 0, 0, 0, 0, 0])[2])) > 0.0:
				rtpl = cand
				break
	var rwg := none.duplicate(true)
	rwg["instanceId"] = "t164_rw"
	rwg["runewordName"] = str(rtpl.get("name", ""))
	var rw_base := XTianqiGear.gem_base(rwg)
	var rw_params: Array = XTianqiGear.runeword_params(rwg)
	_check("runeword_in_gem_base", not rtpl.is_empty() and rw_params.size() >= 8 and absf(float(rw_base[2]) - float(rw_params[2])) < 0.01 and float(rw_base[2]) != 0.0, [rw_base, rw_params])
	var rw_gems := XTianqiGemPower.gems(rwg)
	var rw_lines := XTianqiGemPower.gem_lines(rwg, rw_base, "符文之语")
	_check("runeword_gem_row", rw_gems.any(func(x): return x.name == "符文之语") and not rw_lines.is_empty() and str(rw_lines[0]).begins_with("符文之语"), [rw_gems, rw_lines])
	# 镶嵌图鉴：只多一行说明
	var rec: Dictionary = XInlayBook.recipes()[0][0]
	var book_on := XInlayBook.status_ops(rec, 0)
	_check("book_note_added", book_on.size() == book_off.size() + 1 and JSON.stringify(book_on).contains(XTianqiGemPower.NOTE))
	# D190：天启档图鉴数字＝基础值×80 级换算比；CAP_80 关回基础值，与期四关着时逐字节相同
	var btpl := XDB.rec("Weapons", int(rec.get("weapon", 0)))
	var bbase := float(btpl.get("params", [0, 0, 0, 0, 0, 0, 0, 0])[2])
	var bfull := XEnemyBookPage.js_num(roundf(bbase * XTianqiGear.full_ratio(2)))
	_check("book_numbers_full", bbase != 0.0 and bfull != XEnemyBookPage.js_num(bbase) and JSON.stringify(book_on).contains("\"" + bfull + "\""), [bbase, bfull])
	XTianqiGear.CAP_80 = false
	_check("book_numbers_cap_off_same", JSON.stringify(XInlayBook.status_ops(rec, 0).slice(0, book_off.size())) == JSON.stringify(book_off))
	XTianqiGear.CAP_80 = true
	# D190：光耀度口径——80 级＝100%、超 80 不超 100%、0 级约 23～32%
	var lv := none.duplicate(true)
	lv["instanceId"] = "t164_lv"
	var pcts := {}
	for L in [0, 40, 80, 81, 90, 99, 100]:
		lv.meta = (lv.meta as Dictionary).duplicate()
		lv.meta["req_level"] = str(L)
		XTianqiGear.clear_effective_cache()
		var row := []
		for i in [0, 2, 3, 6, 7]:
			row.append(XTianqiGemPower.power_of(lv, i))
		pcts[L] = row
	_check("level80_is_100", (pcts[80] as Array).all(func(x): return absf(x - 1.0) < 1e-9), pcts[80])
	_check("level_over80_capped", [81, 90, 99, 100].all(func(L): return (pcts[L] as Array).all(func(x): return absf(x - 1.0) < 1e-9)), pcts)
	_check("never_over_100", pcts.values().all(func(row): return (row as Array).all(func(x): return x <= 1.0 + 1e-9)))
	_check("level0_23_to_32", (pcts[0] as Array).all(func(x): return x >= 0.225 and x <= 0.325), pcts[0])
	_check("level40_between", (pcts[40] as Array).all(func(x): return x > (pcts[0] as Array)[0] and x < 1.0))
	lv.meta["req_level"] = "99"
	XTianqiGear.clear_effective_cache()
	var line99 := XTianqiGemPower.gem_lines(lv, [0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	_check("level99_gem_100", line99.size() == 1 and str(line99[0]).begins_with("光耀100%"), line99)
	# CAP_80 关回旧口径：90 级换算比读到 90 行，光耀度＝换算比本身
	XTianqiGear.CAP_80 = false
	XTianqiGear.clear_effective_cache()
	lv.meta["req_level"] = "90"
	_check("cap_off_old_ratio", absf(XTianqiGear.flat_ratio(lv, 2) - 6.27) < 1e-9 and absf(XTianqiGemPower.power_of(lv, 2) - 6.27) < 1e-9 and XTianqiGear.full_ratio(2) == 1.0)
	XTianqiGear.CAP_80 = true
	XTianqiGear.clear_effective_cache()
	# 战斗结果：≤80 级的装备 CAP_80 开／关伤害相同；超 80 级特例才变（八项按 80 级读）
	var dmg_cap_on := _damage(s, g)
	XTianqiGear.CAP_80 = false
	XTianqiGear.clear_effective_cache()
	var dmg_cap_off := _damage(s, g)
	XTianqiGear.CAP_80 = true
	XTianqiGear.clear_effective_cache()
	_check("damage_same_cap_on_off_le80", dmg_cap_on == dmg_cap_off and dmg_cap_on.size() >= 2, [dmg_cap_on, dmg_cap_off])
	# P2：非天启档（总开关开着、但当前存档不是天启档）——图鉴不画说明行
	var keep_state: XState = XState.current
	XState.current = null
	_check("nontianqi_book_no_note", XInlayBook.status_ops(rec, 0).size() == book_off.size() and not JSON.stringify(XInlayBook.status_ops(rec, 0)).contains("光耀"))
	XState.current = keep_state
	# 显示函数不改八项、不改伤害：开着先量一次，把所有显示函数都调一遍，再量一次，必须相同（真战斗，随机数固定）
	var params_before: Array = (XTianqiGear.effective_params(g) as Array).duplicate()
	var dmg_on_before := _damage(s, g)
	for fn in 3:
		XHelpCard.detail_rows(g, 300.0)
		XGearDetail.socket_rows(g)
		XTianqiGemPower.preview_rows(none, XDB.rec("Items", STONE), "upgrade")
		XTianqiGemPower.gems(g)
	XInlayBook.status_ops(rec, 0)
	var dmg_on_after := _damage(s, g)
	_check("params_unchanged", XTianqiGear.effective_params(g) == params_before and (g.params as Array).size() == 8)
	_check("damage_unchanged_by_display_on", dmg_on_before == dmg_on_after and dmg_on_before.size() >= 2, [dmg_on_before, dmg_on_after])
	# 关着：同样量一次、调显示、再量
	XTianqiBase.PHASE4 = false
	XTianqiGear.clear_effective_cache()
	var dmg_off_before := _damage(s, g)
	XHelpCard.detail_rows(g, 300.0)
	XGearDetail.socket_rows(g)
	XTianqiGemPower.preview_rows(none, XDB.rec("Items", STONE), "upgrade")
	var dmg_off_after := _damage(s, g)
	_check("damage_unchanged_by_display_off", dmg_off_before == dmg_off_after and dmg_off_before.size() >= 2, [dmg_off_before, dmg_off_after])
	# 开／关两态的伤害都由 effective_params 决定，显示层不掺手；off 与 params 原值（关着读 g.params）一致
	_check("off_params_same", XTianqiGear.effective_params(g) == g.params and params_off == (XTianqiGear.effective_params(g) as Array))
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
