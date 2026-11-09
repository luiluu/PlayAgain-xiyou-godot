extends Node
## 战力先藏（O-243，Kyo 2026-11-08）：XPower.SHOW_POWER_UI 默认 false，各页不再出现「战力」；
## 打开开关（回退）时与藏之前一致（那一半由 xiyou_power／status_power／help_card／gear_search 等专项开着开关逐字对照）。
## 这里只做扫描型断言：开关关着时，所有显示处的文字与控件里没有「战力」，排版没有留下空条。

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func frames(n := 4) -> void:
	for i in range(n):
		await get_tree().process_frame


## 递归收集控件上的文字
static func texts(n: Node, out := []) -> Array:
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	elif n is RichTextLabel:
		out.append((n as RichTextLabel).text)
	for c in n.get_children():
		texts(c, out)
	return out


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_power_hidden"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XConfig.set_flag("codexPowerEnabled", true)
	XPower.clear_cache()
	# 默认值：脚本里的初值就是 false（别的专项会把它改成 true，所以先读一遍再测）
	var src := FileAccess.get_file_as_string("res://modes/xiyou/core/power.gd")
	check("default_hidden", src.contains("static var SHOW_POWER_UI := false"))
	XPower.SHOW_POWER_UI = false
	var ids := [23]
	var s := XState.new_game(3, 23, [])
	var a: XActor = s.actor(23)
	# 文字函数
	check("ui_enabled_false", not XPower.ui_enabled() and XPower.enabled())
	check("status_text_empty", XPower.status_text(a) == "")
	check("menu_text_empty", XPower.menu_text(a) == "")
	# 状态页：没有战力条／按钮，页窗不下移
	var page := XStatusPage.new()
	add_child(page)
	await frames()
	page.rebuild()
	await frames()
	check("status_no_strip", page.power_strip == null and page.power_button == null)
	check("status_page_y", page.page_win.position.y == XStatusPage.PAGE_Y, page.page_win.position)
	var found := texts(page).filter(func(t): return str(t).contains("战力"))
	check("status_no_power_text", found.is_empty(), found)
	page.queue_free()
	# 设置页：不列「战力显示与估算」
	var opt := XOptionsScene.new()
	add_child(opt)
	await frames()
	check("options_no_power_row", not opt.symbols().has("codexPowerEnabled"), opt.symbols())
	var optn := texts(opt).filter(func(t): return str(t).contains("战力"))
	check("options_no_power_text", optn.is_empty(), optn)
	opt.queue_free()
	# 说明卡：武器／防具没有「装备战力」行
	var weapon := XDB.rec("Weapons", 2)
	var armor := XDB.rec("Armors", 2)
	for obj in [weapon, armor]:
		var rows := XHelpCard.detail_rows(obj, 400.0)
		var bad := rows.filter(func(r): return str(r[0]).contains("战力"))
		check("help_detail_no_power_%s" % str(obj.get("name", "")), bad.is_empty(), bad)
		var rows2 := XHelpCard.content(obj)
		var bad2 := rows2.filter(func(r): return str(r[0]).contains("战力"))
		check("help_content_no_power_%s" % str(obj.get("name", "")), bad2.is_empty(), bad2)
	# 装备检索：行摘要、详情、排序项
	var rec := {"item": weapon, "owner": ""}
	check("gear_row_no_power", not XGearSearch.row_small(rec).contains("战力"), XGearSearch.row_small(rec))
	var blocks := XGearSearch.detail_blocks(rec)
	var gb := blocks.filter(func(b): return str(b.get("text", "")).contains("战力") or str(b.get("tag", "")) == "power")
	check("gear_detail_no_power", gb.is_empty(), gb)
	var sorts := XGearSearch.sort_options([rec], {"term": "", "sortTerm": ""})
	check("gear_sort_no_power", sorts.filter(func(o): return str(o[1]).contains("战力") or str(o[0]) == "power").is_empty(), sorts)
	# 装备变更提示：不弹、不记
	XPowerNotice.last_change = {}
	XPowerNotice.notify(a, 1.0, 2.0)
	check("notice_silent", XPowerNotice.last_change.is_empty())
	# 打开开关（回退）：这些显示处都回来
	XPower.SHOW_POWER_UI = true
	check("rollback_text", XPower.status_text(a).begins_with("战力 ") and XPower.menu_text(a) != "")
	var opt2 := XOptionsScene.new()
	add_child(opt2)
	await frames()
	check("rollback_options_row", opt2.symbols().has("codexPowerEnabled"))
	opt2.queue_free()
	check("rollback_help_row", XHelpCard.content(weapon).any(func(r): return str(r[0]).contains("装备战力：")))
	check("rollback_gear_row", XGearSearch.row_small(rec).contains("战力"))
	XPower.SHOW_POWER_UI = false
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
