extends Node
## 天启篇人物图鉴全员备注（XTianqiActorNotes，T556）专项：
## 一、天启篇存档下，人物图鉴全部可见角色（163 位，含 167～174 与 180 五条悟）均有 2 行非空备注（故事＋特点），
##     且无阿拉伯数字、百分号、倍率号或出戏元词；新图鉴 XSkinBookPage.actor_info 与旧图鉴 XActorBook.status_ops 同步生效。
## 二、五人样稿（小铃兰 127、宿傩 172、钟离 107、渡鸦 167、雪清寒 18）与原说明书四人（175～178）均输出统一两行。
## 三、回退开关 XTianqiActorNotes.ENABLED = false 与西游档、无存档状态均零改动回退原版 <ActorNote>。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _tianqi_on() -> void:
	var s := XState.new()
	s.flags["tianqi"] = {"rules": 1}
	XState.current = s


func _measure(s: String, size: int) -> float:
	return XActorBook.js_width(s, size)


func _ops_texts(ops: Array) -> String:
	var buf := PackedStringArray()
	for o in ops:
		if o is Array and o.size() >= 2 and str(o[0]) == "t":
			buf.append(str(o[1]))
	return "\n".join(buf)


func _run() -> void:
	_tianqi_on()
	XTianqiActorNotes.ENABLED = true
	XTianqiActorNotes.reload_table()
	_check("tq_active", XTianqiActorNotes.active())

	var ids := XActorBook.index_ids().filter(func(i): return int(i) > 0)
	_check("visible_actor_count_163", ids.size() == 163, ids.size())

	var forbidden := RegEx.create_from_string("[0-9%×*]|测试角色|定制角色|特殊角色|图像已接入|繁星版|高爆版|候选池|暂未|编入|图鉴|收藏|模板|玩法")
	var missing := []
	var bad_fmt := []
	var skin_miss := []
	for raw_id in ids:
		var id := int(raw_id)
		var lines := XTianqiActorNotes.lines_of(id)
		if lines.size() != 2:
			missing.append(id)
			continue
		for idx in lines.size():
			var t := str(lines[idx])
			if t.strip_edges() == "" or not t.ends_with("。") or forbidden.search(t) != null or (idx == 1 and t.contains("倍")):
				bad_fmt.append([id, t])
		var info := XSkinBookPage.actor_info(id)
		if info.get("note", []) != lines:
			skin_miss.append(id)

	_check("all_163_have_two_lines", missing.is_empty(), missing.slice(0, 10))
	_check("all_163_no_numbers_or_forbidden", bad_fmt.is_empty(), bad_fmt.slice(0, 5))
	_check("skin_book_reads_all_163", skin_miss.is_empty(), skin_miss.slice(0, 10))

	# 原本单行标签无显示的 9 位（167～174 与 180 五条悟）现在在新旧图鉴都有 2 行备注
	var fixed_nine := [167, 168, 169, 170, 171, 172, 173, 174, 180]
	var nine_ok := true
	for id in fixed_nine:
		var lines := XTianqiActorNotes.lines_of(id)
		var ops_txt := _ops_texts(XActorBook.status_ops(id, _measure))
		if lines.size() != 2 or not ops_txt.contains(str(lines[0]).substr(0, 12)) or not ops_txt.contains(str(lines[1]).substr(0, 12)):
			nine_ok = false
			break
	_check("previously_blank_9_actors_visible", nine_ok)

	# 样稿与 175～178 原说明书四人检查
	var l_su := XTianqiActorNotes.lines_of(172)
	var l_zl := XTianqiActorNotes.lines_of(107)
	var l_gy := XTianqiActorNotes.lines_of(175)
	_check("sample_sukuna_lines", l_su.size() == 2 and str(l_su[0]).contains("诅咒之王") and str(l_su[1]).contains("咒焰"), l_su)
	_check("sample_zhongli_no_raw_number", l_zl.size() == 2 and not str(l_zl[1]).contains("150"), l_zl)
	_check("reworked_guyu_two_lines", l_gy.size() == 2 and not str(l_gy[1]).contains("60"), l_gy)

	# 回退开关 ENABLED = false
	XTianqiActorNotes.ENABLED = false
	_check("switch_off_inactive", not XTianqiActorNotes.active() and XTianqiActorNotes.lines_of(127).is_empty())
	var off_suzuran: Array = XSkinBookPage.actor_info(127).get("note", [])
	var off_sukuna: Array = XSkinBookPage.actor_info(172).get("note", [])
	_check("switch_off_fallback_legacy", off_suzuran == ["罗德岛干员铃兰，九倍的温柔与坚强。"] and off_sukuna.is_empty(), [off_suzuran, off_sukuna])
	XTianqiActorNotes.ENABLED = true

	# 西游档（非天启篇）零改动
	XState.current = XState.new()
	_check("legacy_save_inactive", not XTianqiActorNotes.active() and XTianqiActorNotes.lines_of(127).is_empty())
	var leg_suzuran: Array = XSkinBookPage.actor_info(127).get("note", [])
	var leg_ops := _ops_texts(XActorBook.status_ops(127, _measure))
	_check("legacy_save_keeps_original", leg_suzuran == ["罗德岛干员铃兰，九倍的温柔与坚强。"] and leg_ops.contains("九倍的温柔与坚强") and not leg_ops.contains("拉条再动"), leg_suzuran)

	# 无存档安全返回空
	XState.current = null
	_check("null_state_safe", not XTianqiActorNotes.active() and XTianqiActorNotes.lines_of(127).is_empty())

	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
