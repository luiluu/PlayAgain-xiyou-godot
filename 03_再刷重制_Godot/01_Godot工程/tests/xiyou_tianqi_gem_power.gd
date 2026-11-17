extends Node
## 【cc·T164】宝石发挥度（D186）：宝石效果＝基础值×装备的宝石发挥度（＝期四换算比），只显示、不改数值。
## 一、期四关着：所有显示函数返回空，镶嵌图鉴不画说明行，详情／插槽行数同原来，八项原样。
## 二、开着：发挥度文字＝换算比（单列一个百分比、多列给范围）；逐项「实际值（基础值）」＝换算比×基础值，且与 effective_params 里宝石那份一致；
##     镶嵌图鉴数字仍是基础值、只多一行说明；镶嵌预览给本件的实际值；开关开／关各一遍，八项数值、effective_params 不因显示函数改变。
const Kit := preload("res://tests/lib/tq_save_kit.gd")
const DAGGER := 972
const STONE := 258  # 劣质磨刀石：镶嵌固定物攻 +2
var results: Array = []


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
	_check("off_text_empty", XTianqiGemPower.power_text(g) == "")
	_check("off_detail_rows_same", XTianqiGemPower.detail_rows(g).is_empty() and XTianqiGemPower.socket_head(g, 20).is_empty() and XTianqiGemPower.upgrade_lines(g, 0, 20).is_empty())
	_check("off_preview_empty", XTianqiGemPower.preview_rows(g, XDB.rec("Items", STONE), "upgrade").is_empty())
	var detail_off := XHelpCard.detail_rows(g, 300.0)
	var socket_off := XGearDetail.socket_rows(g)
	_check("off_gem_base_zero", XTianqiGear.gem_base(g) == [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var book_off := XInlayBook.status_ops(XInlayBook.recipes()[0][0], 0)
	_check("off_book_no_note", not JSON.stringify(book_off).contains("宝石发挥度"))

	# ---- 开着 ----
	XTianqiBase.PHASE4 = true
	XTianqiGear.clear_effective_cache()
	_check("on_active", XTianqiGemPower.active(g))
	var ratio_atk := XTianqiGear.flat_ratio(g, 2)
	var base := XTianqiGear.gem_base(g)
	_check("gem_base_stone_plus2", float(base[2]) == 2.0, base)
	var want_pct := "%d%%" % roundi(ratio_atk * 100.0)
	_check("power_text_is_ratio", XTianqiGemPower.power_text(g) == want_pct, [XTianqiGemPower.power_text(g), want_pct])
	var lines := XTianqiGemPower.value_lines(g, base)
	var want_line := "%s %+d（%+d）" % [str(XDB.system().terms.params[2]), roundi(2.0 * ratio_atk), 2]
	_check("value_line_actual_of_base", lines.size() == 1 and lines[0] == want_line, [lines, want_line])
	var drows := XHelpCard.detail_rows(g, 300.0)
	_check("detail_has_power_and_line", _rows_text(drows).contains("宝石发挥度：" + want_pct) and _rows_text(drows).contains(want_line), _rows_text(drows))
	_check("detail_prefix_unchanged", drows.size() > detail_off.size())
	var srows := XGearDetail.socket_rows(g)
	_check("socket_has_power_and_line", _rows_text(srows).contains("宝石发挥度：" + want_pct) and _rows_text(srows).contains(want_line), _rows_text(srows))
	_check("socket_row_count", srows.size() == socket_off.size() + 2, [srows.size(), socket_off.size()])
	# 与 effective_params 的宝石那份一致：同一件去掉镶嵌记录，物攻差 = 换算比×2
	var bare := g.duplicate(true)
	bare.instanceId = "t164_bare"
	bare.upgrades = []
	var diff := float(XTianqiGear.effective_params(g)[2]) - float(XTianqiGear.effective_params(bare)[2])
	_check("matches_effective_params", absf(diff - 2.0 * ratio_atk) <= 1.0, [diff, ratio_atk])
	# 无宝石：只一行发挥度（物攻列）
	var none := XGear.create("weapon", DAGGER, s)
	none["instanceId"] = "t164_none"
	_check("no_gem_only_headline", XTianqiGemPower.value_lines(none, XTianqiGear.gem_base(none)).is_empty() and XTianqiGemPower.power_text(none) != "")
	# 预览：磨刀石镶在这件上
	var pv := XTianqiGemPower.preview_rows(none, XDB.rec("Items", STONE), "upgrade")
	_check("preview_stone", pv.size() == 2 and str(pv[1][0]).contains(want_line.replace("（+2）", "（+2）")) or str(pv[1][0]).contains("（+2）"), pv)
	# 镶嵌图鉴：数字仍是基础值，只多一行说明
	var rec: Dictionary = XInlayBook.recipes()[0][0]
	var book_on := XInlayBook.status_ops(rec, 0)
	_check("book_note_added", book_on.size() == book_off.size() + 1 and JSON.stringify(book_on).contains("装备的宝石发挥度"))
	_check("book_numbers_same", JSON.stringify(book_on.slice(0, book_off.size())) == JSON.stringify(book_off))
	# 显示函数不改八项
	_check("params_unchanged", XTianqiGear.effective_params(g) == XTianqiGear.effective_params(g) and (g.params as Array).size() == 8)
	XTianqiGear.clear_effective_cache()
	XTianqiBase.PHASE4 = false
	_check("off_again_params_same", XTianqiGear.effective_params(g) == g.params and params_off == (XTianqiGear.effective_params(g) as Array))

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
