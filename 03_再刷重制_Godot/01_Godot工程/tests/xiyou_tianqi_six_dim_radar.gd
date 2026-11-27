extends Node
## 天启篇六维雷达（T278，XSkinSixDimRadar＋角色状态页＋人物图鉴）专项：
## 一、顶点几何：半径＝档分/8，E～SSS 八档单调；缺项补 C 的中性六边形六点等距。
## 二、文字：「控制抗性 +x%」（钟离 +7%、五条悟 0%、马宝国 −10%）、六维名与说明齐全、不出现「战力」。
## 三、人物图鉴 status_ops：天启篇有 radar 操作（渡鸦／光环栏改一行字）、原版西游档与 ENABLED＝false 与改前逐项相同（无 radar、无六维行）。
## 四、状态页（新界面）天启篇、西游两种存档都能建、画一帧不报错。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _tianqi(on: bool) -> void:
	var s := XState.new_game(3, 8, [9])
	if on:
		s.flags["tianqi"] = {"rules": 1}
	XState.current = s


func _frames(n := 6) -> void:
	for i in range(n):
		await get_tree().process_frame


func _has_op(ops: Array, kind: String) -> bool:
	return ops.any(func(o): return o[0] == kind)


func _all_text(ops: Array) -> String:
	return "".join(ops.filter(func(o): return o[0] == "t").map(func(o): return str(o[1])))


func _run() -> void:
	XTianqiSixDim.ENABLED = true
	var R := XSkinSixDimRadar
	# 一、几何
	var c := Vector2(100, 100)
	var neu := R.points(c, 80.0, {})
	var same := true
	for p in neu:
		same = same and is_equal_approx(p.distance_to(c), 30.0)   # C＝3 分＝80×3/8
	_check("neutral_hexagon", neu.size() == 6 and same, neu)
	var prev := -1.0
	var mono := true
	for l in R.LETTERS:
		var d := R.points(c, 80.0, {"output": l})[0].distance_to(c)
		mono = mono and d > prev
		prev = d
	_check("letters_monotonic", mono)
	_check("sss_reaches_rim", is_equal_approx(R.points(c, 80.0, {"output": "SSS"})[0].distance_to(c), 80.0))
	_check("top_vertex_up", R.points(c, 80.0, {"output": "SSS"})[0].is_equal_approx(Vector2(100, 20)))
	var gojo := {"output": "S", "survive": "A", "speed": "B", "wit": "SS", "resolve": "C", "support": "E"}
	var gp := R.points(c, 80.0, gojo)
	_check("gojo_shape", is_equal_approx(gp[3].distance_to(c), 70.0) and is_equal_approx(gp[5].distance_to(c), 10.0))
	# 节点用法：直接赋值也更新悬停说明、compact 传给 paint
	var node := XSkinSixDimRadar.new()
	add_child(node)
	node.six = gojo
	_check("node_assign_updates_tooltip", node.tooltip_text == R.tip_text(gojo) and node.tooltip_text.begins_with("输出 S：杀伤与爆发能力"), node.tooltip_text)
	node.compact = true
	_check("node_compact_passed", node.paint_opts().get("compact") == true)
	node.compact = false
	_check("node_noncompact_passed", node.paint_opts().get("compact") == false)
	node.opts = {"fs": 16}
	_check("node_opts_kept", node.paint_opts().get("fs") == 16)
	node.set_six({}, 0)
	_check("node_empty_six_tooltip_neutral", node.tooltip_text.contains("输出 C："))
	node.queue_free()
	# 二、文字
	_tianqi(true)
	_check("resist_text_zhongli", R.resist_text(XTianqiSixDim.resist_pct_of(XTianqiSixDim.of_actor(107))) == "控制抗性 +7%")
	_check("resist_text_gojo", R.resist_text(XTianqiSixDim.resist_pct_of(XTianqiSixDim.of_actor(180))) == "控制抗性 0%")
	_check("resist_text_mabaoguo", R.resist_text(XTianqiSixDim.resist_pct_of(XTianqiSixDim.of_actor(60))) == "控制抗性 −10%")
	var names_ok := true
	for d in R.DIMS:
		names_ok = names_ok and R.DIM_NAMES.has(d) and R.DIM_HINTS.has(d) and not str(R.DIM_HINTS[d]).contains("战力")
	_check("names_hints_complete", names_ok and R.DIMS == XTianqiSixDim.DIMS)
	_check("tip_six_lines", R.tip_text(gojo).split("\n").size() == 6 and not R.tip_text(gojo).contains("战力"))
	# 三、人物图鉴
	var radar_ids := []
	for id in [180, 107, 175, 168, 45, 174, 71, 6, 31, 60]:
		var ops := XActorBook.status_ops(id, func(s, size): return XActorBook.js_width(s, size))
		_check("book_radar_%d" % id, _has_op(ops, "radar") and not _all_text(ops).contains("战力"))
		for o in ops:
			if o[0] == "radar":
				radar_ids.append(o[1] == XTianqiSixDim.of_actor(id))
	_check("book_radar_data_matches", radar_ids.size() == 10 and not radar_ids.has(false))
	var raven := XActorBook.status_ops(167, func(s, size): return XActorBook.js_width(s, size))
	_check("book_raven_line", not _has_op(raven, "radar") and _all_text(raven).contains("六维：输出"))
	var aura := XActorBook.status_ops(127, func(s, size): return XActorBook.js_width(s, size))
	_check("book_aura_line", not _has_op(aura, "radar") and _all_text(aura).contains("六维：输出"))
	# 「其他」列有技能的 45：技能往下让到雷达下面，不压雷达
	var o45 := XActorBook.status_ops(45, func(s, size): return XActorBook.js_width(s, size))
	var radar_bottom := 0.0
	for o in o45:
		if o[0] == "radar":
			radar_bottom = float(o[3]) + XActorBook.RADAR_H / 2.0
	var other_ok := radar_bottom > 0
	for o in o45:
		if o[0] == "i" and float(o[2]) >= XActorBook.CONTENT_W * 0.65:
			other_ok = other_ok and float(o[3]) >= radar_bottom - 4.0
	_check("book_other_column_below_radar", other_ok, radar_bottom)
	# 原版西游档、开关关：没有 radar、没有六维行，且与关开关前同一份
	_tianqi(false)
	var legacy := XActorBook.status_ops(180, func(s, size): return XActorBook.js_width(s, size))
	_check("book_legacy_no_six", not _has_op(legacy, "radar") and not _all_text(legacy).contains("六维"))
	_tianqi(true)
	XTianqiSixDim.ENABLED = false
	var fx_prev := XTianqiElements.ENABLED
	var notes_prev := XTianqiActorNotes.ENABLED
	XTianqiElements.ENABLED = false  # T482：元素效果开着时旧窗口多一行「角色属性」，这条只比六维开关，所以关着元素效果比
	XTianqiActorNotes.ENABLED = false  # T556：天启篇全员备注开着时旧窗口多出统一备注，这条只比六维开关，所以关着备注比
	var hide_prev: Array = XSkinBookPage.HIDE_ARMOR_TYPES
	XSkinBookPage.HIDE_ARMOR_TYPES = []  # T571：天启篇不列防具「矢」，同上理由关着比
	var off := XActorBook.status_ops(180, func(s, size): return XActorBook.js_width(s, size))
	XTianqiElements.ENABLED = fx_prev
	XTianqiActorNotes.ENABLED = notes_prev
	XSkinBookPage.HIDE_ARMOR_TYPES = hide_prev
	_check("book_disabled_equals_legacy", off == legacy)
	XTianqiSixDim.ENABLED = true
	# 四、状态页（新界面）
	for on in [true, false]:
		_tianqi(on)
		var s := XState.current
		s.add_actor(180)
		s.add_actor(60)
		s.party.assign([180, 60])
		XUiSkin.FORCE = true
		var p := XStatusPage.new()
		add_child(p)
		await _frames()
		var ok := p.skin != null
		for i in 2:
			p.actor_index = i
			p.skin.sync()
			await _frames(3)
		_check("status_page_draws_tianqi_%s" % on, ok)
		p.queue_free()
		await _frames(2)
	XUiSkin.FORCE = false
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
