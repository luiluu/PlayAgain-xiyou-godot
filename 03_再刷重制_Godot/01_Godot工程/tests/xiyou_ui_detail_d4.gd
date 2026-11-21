extends Node
## 【cc·T340·未经审查】界面细节 D4 提示道按字数定时、分级积压、菜单悬停暂停（私密仓 重制设定/界面细节规范_v0.1.md 第五节卡 D4）：
## 1. effective_chars：空白标点不计、汉字 1.0、其余每 2 个计 1.0（含 ×）；
## 2. calc_duration：3／8（含 ×）／20／50 字、显式 warn、橙红 color 兜底、积压 3 条与 6 条；
## 3. 用 step() 实际走时间，停留秒数与 calc_duration 误差 < 0.01s；合并续时保底 1.2s；
## 4. 菜单态悬停暂停、移开后至少 0.8s、轻点 0.12s 淡出跳过；战斗（非菜单）态胶囊穿透；
## 5. DETAIL_V1 = false 回老算法（2.0／2.8／0.7 秒）；XToast 兜底 hold_for 用 calc_duration。
## 带 -- --out=<目录> 且有窗口时：出验收图 notice_<菜单|战斗>_<短|长>.png，并写 duration_table.md（新旧停留时长对比表）。
##   拍：godot --audio-driver Dummy --path <工程> res://tests/xiyou_ui_detail_d4.tscn -- --out=<目录>
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const DT := 0.002

var results: Array = []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(800))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


func _run() -> void:
	TestEnv.isolate("xiyou_ui_detail_d4")
	XUiSkin.FORCE = true
	XUiSkin.DETAIL_V1 = true
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	XSkinNoticeLane.NOTICE_V2 = true
	XSkinNoticeLane.auto_tick = false
	XSkinNoticeLane.reset()
	_chars()
	_duration()
	_stepped()
	_merge()
	_hover_skip()
	_legacy()
	if windowed():
		await _shots()
	XSkinNoticeLane.reset()
	XSkinNoticeLane.auto_tick = true
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XUiSkin.DETAIL_V1 = true
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _near(a: float, b: float, tol := 0.01) -> bool:
	return absf(a - b) < tol


func _chars() -> void:
	check("chars_cjk3", XSkinNoticeLane.effective_chars("已存档") == 3.0)
	check("chars_punct_space_free", XSkinNoticeLane.effective_chars("存档，成功！ 。") == 4.0, XSkinNoticeLane.effective_chars("存档，成功！ 。"))
	check("chars_times", XSkinNoticeLane.effective_chars("获得敏锐斧（史诗）×1") == 8.0, XSkinNoticeLane.effective_chars("获得敏锐斧（史诗）×1"))
	check("chars_ascii_half", XSkinNoticeLane.effective_chars("abc") == 2.0 and XSkinNoticeLane.effective_chars("abcd") == 2.0 and XSkinNoticeLane.effective_chars("+50%") == 2.0)
	check("chars_empty", XSkinNoticeLane.effective_chars("") == 0.0)


func _duration() -> void:
	var t20 := "副本挑战完成，自动挂机已关闭，请检查掉落背包"
	var t13 := "存档失败，请通过存档菜单重试。"
	check("dur_3", _near(XSkinNoticeLane.calc_duration("已存档"), 1.855), XSkinNoticeLane.calc_duration("已存档"))
	check("dur_3_warn", _near(XSkinNoticeLane.calc_duration("没药了", true), 1.855 * 1.2), XSkinNoticeLane.calc_duration("没药了", true))
	check("dur_8_times", _near(XSkinNoticeLane.calc_duration("获得敏锐斧（史诗）×1"), 2.28), XSkinNoticeLane.calc_duration("获得敏锐斧（史诗）×1"))
	check("dur_20", _near(XSkinNoticeLane.calc_duration(t20), 3.30), XSkinNoticeLane.calc_duration(t20))
	check("dur_13_warn", _near(XSkinNoticeLane.calc_duration(t13, true), 3.246), XSkinNoticeLane.calc_duration(t13, true))
	var t50 := "一".repeat(50)
	check("dur_50_cap", _near(XSkinNoticeLane.calc_duration(t50), 5.5) and _near(XSkinNoticeLane.calc_duration(t50, true), 6.0))
	check("dur_min_floor", XSkinNoticeLane.calc_duration("") >= 1.8)
	# 积压：≤1 不变；2～4 ×0.65；≥5 ×0.5；保底 1.2
	var base := XSkinNoticeLane.calc_duration(t20)
	check("dur_backlog_0_1", _near(XSkinNoticeLane.calc_duration(t20, false, 1), base))
	check("dur_backlog_3", _near(XSkinNoticeLane.calc_duration(t20, false, 3), base * 0.65), XSkinNoticeLane.calc_duration(t20, false, 3))
	check("dur_backlog_6", _near(XSkinNoticeLane.calc_duration(t20, false, 6), base * 0.5), XSkinNoticeLane.calc_duration(t20, false, 6))
	check("dur_backlog_floor", _near(XSkinNoticeLane.calc_duration("", false, 6), 1.2) and _near(XSkinNoticeLane.calc_duration("已存档", false, 6), 1.2), XSkinNoticeLane.calc_duration("已存档", false, 6))
	# warn 来源：显式键优先；没传按 color 兜底
	check("warn_explicit", XSkinNoticeLane.is_warn({"warn": true}) and not XSkinNoticeLane.is_warn({"warn": false, "color": XUiSkin.DOWN}))
	check("warn_color", XSkinNoticeLane.is_warn({"color": XUiSkin.DOWN}) and XSkinNoticeLane.is_warn({"color": XUiSkin.POLISH_DOWN}) and XSkinNoticeLane.is_warn({"color": XUiSkin.SEL_LINE}) and XSkinNoticeLane.is_warn({"color": XUiSkin.SEL_FILL}))
	check("warn_none", not XSkinNoticeLane.is_warn({"color": XUiSkin.GOLD}) and not XSkinNoticeLane.is_warn({}))


## 走 step 直到当前这条换掉，返回走过的秒数
func _run_out(l: XSkinNoticeLane, limit := 12.0) -> float:
	var first := l.cur
	var el := 0.0
	while l.cur == first and el < limit:
		l.step(DT)
		el += DT
	return el


func _push(title: String, extra := {}) -> void:
	var it := {"kind": "toast", "title": title}
	it.merge(extra)
	XSkinNoticeLane.push(it)


func _stepped() -> void:
	var t20 := "副本挑战完成，自动挂机已关闭，请检查掉落背包"
	XSkinNoticeLane.reset()
	_push("已存档")
	var l := XSkinNoticeLane.existing()
	check("step_3", _near(_run_out(l), XSkinNoticeLane.calc_duration("已存档")), XSkinNoticeLane.calc_duration("已存档"))
	XSkinNoticeLane.reset()
	_push(t20)
	check("step_20", _near(_run_out(l), XSkinNoticeLane.calc_duration(t20)))
	XSkinNoticeLane.reset()
	_push("存档失败，请通过存档菜单重试。", {"warn": true})
	check("step_warn_flag", _near(_run_out(l), 3.246))
	XSkinNoticeLane.reset()
	_push("存档失败，请通过存档菜单重试。", {"color": XUiSkin.SEL_LINE})
	check("step_warn_color", _near(_run_out(l), 3.246))
	# 积压 3 条（cur＋后面排 3 条）
	XSkinNoticeLane.reset()
	for i in 4:
		_push(t20 + str(i))
	var el3 := _run_out(l)
	check("step_backlog3", XSkinNoticeLane.queue.size() == 2 and _near(el3, XSkinNoticeLane.calc_duration(t20 + "0", false, 3)), [el3, XSkinNoticeLane.queue.size()])
	# 积压 6 条
	XSkinNoticeLane.reset()
	for i in 7:
		_push(t20 + str(i))
	var el6 := _run_out(l)
	check("step_backlog6", _near(el6, XSkinNoticeLane.calc_duration(t20 + "0", false, 6)), el6)
	XSkinNoticeLane.reset()


func _merge() -> void:
	XSkinNoticeLane.reset()
	_push("已存档")
	var l := XSkinNoticeLane.existing()
	l.step(1.7)   # 总长 1.855，快淡出前并进同名条
	var total := l._total(l.cur)
	_push("已存档")
	check("merge_left_1_2", int(l.cur.get("count", 0)) == 2 and l._total(l.cur) - l.t >= 1.2 - 0.001, [l.cur, l.t, total])
	XSkinNoticeLane.reset()


func _menu_page() -> Control:
	var c := Control.new()
	c.add_to_group(XUiSkin.FULLSCREEN_GROUP)
	get_tree().root.add_child(c)
	return c


func _hover_skip() -> void:
	XSkinNoticeLane.reset()
	var l := XSkinNoticeLane.existing()
	# 战斗／地图态（没有全屏菜单）：胶囊穿透
	_push("已存档")
	l.step(0.01)
	check("hover_battle_ignore", l.chip.mouse_filter == Control.MOUSE_FILTER_IGNORE and not l.hover)
	XSkinNoticeLane.reset()
	var page := _menu_page()
	_push("获得敏锐斧（史诗）×1")
	l.step(0.01)
	check("hover_menu_stop", l.chip.mouse_filter == Control.MOUSE_FILTER_STOP)
	# 悬停暂停：走 20 秒还在原条上、t 不动
	l.step(1.0)
	var t0 := l.t
	l.set_hover(true)
	l.step(20.0)
	check("hover_pause", l.t == t0 and not l.cur.is_empty(), [l.t, t0])
	# 移开后至少还留 0.8s（原本剩 2.28-1.01≈1.27，不夹；推到快结束再验夹取）
	l.t = l._total(l.cur) - 0.1
	l.set_hover(false)
	check("hover_leave_0_8", _near(l._total(l.cur) - l.t, 0.8, 0.001), [l.t, l._total(l.cur)])
	var el := _run_out(l)
	check("hover_leave_run_out", _near(el, 0.8, 0.01), el)
	# 轻点跳过：0.12s 内换条
	XSkinNoticeLane.reset()
	_push("第一条")
	_push("第二条")
	l.step(0.01)
	l.skip()
	var el2 := _run_out(l)
	check("skip_012", _near(el2, 0.12, 0.01) and str(l.cur.get("title", "")) == "第二条", [el2, l.cur])
	# 点击事件走通：鼠标左键按下 gui_input → skip
	XSkinNoticeLane.reset()
	_push("点我")
	l.step(0.01)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	l.chip.gui_input.emit(e)
	check("click_skips", _near(l._total(l.cur) - l.t, 0.12, 0.001), [l.t, l._total(l.cur)])
	# DETAIL_V1 关：不暂停、不收鼠标
	XSkinNoticeLane.reset()
	XUiSkin.DETAIL_V1 = false
	_push("已存档")
	l.step(0.01)
	check("hover_off_with_detail_off", l.chip.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	XUiSkin.DETAIL_V1 = true
	page.free()
	XSkinNoticeLane.reset()


func _legacy() -> void:
	XUiSkin.DETAIL_V1 = false
	XSkinNoticeLane.reset()
	_push("已存档")
	var l := XSkinNoticeLane.existing()
	check("legacy_2s", _near(l._total(l.cur), XSkinNoticeLane.HOLD, 0.0001), l._total(l.cur))
	for i in 4:
		_push("积压%d" % i)
	check("legacy_backlog_0_7", _near(l._total(l.cur), XSkinNoticeLane.HOLD_FAST, 0.0001))
	check("toast_hold_legacy", XToast.hold_for("已存档") == XToast.TIMEOUT)
	XUiSkin.DETAIL_V1 = true
	check("toast_hold_new", _near(XToast.hold_for("已存档"), XSkinNoticeLane.calc_duration("已存档")) and XToast.hold_for("已存档") != XToast.TIMEOUT)
	XSkinNoticeLane.reset()


# ---- 验收图与对比表 ----

const SAMPLES := [
	["已存档", false, "存档成功"],
	["没药了", true, "库存不足（警示）"],
	["已保存到存档 1。", false, "手动存档"],
	["获得 敏锐斧（史诗）×1", false, "获得装备"],
	["存档失败，请通过存档菜单重试。", true, "存档失败（警示）"],
	["副本挑战完成，自动挂机已关闭，请检查掉落背包", false, "副本完成"],
	["宝箱收获：太虚裂空剑、星渊护腕、天启圣戒、能量药剂 × 2、生命药剂 × 5、金钱 12000，请及时到背包里整理，别让背包满了", false, "超长宝箱（两行）"],
]


func _write_table() -> void:
	var lines := ["# T340 D4 提示停留时长：新旧对比", "",
		"旧：提示道单行 2.0 s、折两行 2.8 s；积压 >2 条一律 0.7 s；XToast 兜底写死 3.0 s。新：clamp(1.6+0.085N, 1.8, 5.5)，警示 ×1.2 封顶 6.0；积压 2～4 条 ×0.65、≥5 条 ×0.5，保底 1.2 s。",
		"", "| 文案 | 场景 | 等效字数 N | 旧（提示道，积压时 0.7 s） | 新（常规） | 新（警示） | 新·积压3条 | 新·积压6条 |", "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |"]
	var wf := XUiSkin.font("body")
	for s in SAMPLES:
		var txt: String = s[0]
		var rows := XSkinNoticeLane.wrap(txt, wf, 18, float(XUiSkin.CENTER_MAX) - 80.0, 2).size()
		var old := 2.0 if rows < 2 else 2.8
		var nw := XSkinNoticeLane.calc_duration(txt, bool(s[1]))
		lines.append("| %s | %s | %s | %.2f s | %.2f s | %.2f s | %.2f s | %.2f s |" % [txt.left(24) + ("…" if txt.length() > 24 else ""), s[2], str(XSkinNoticeLane.effective_chars(txt)),
			old, XSkinNoticeLane.calc_duration(txt), XSkinNoticeLane.calc_duration(txt, true), XSkinNoticeLane.calc_duration(txt, bool(s[1]), 3), XSkinNoticeLane.calc_duration(txt, bool(s[1]), 6)])
	lines.append("")
	var f := FileAccess.open(out_dir.path_join("duration_table.md"), FileAccess.WRITE)
	f.store_string("\n".join(lines))


func _shot(name: String) -> void:
	await frames(3)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_write_table()
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 4
	XState.current = s
	var shorts := "已存档"
	var long := "宝箱收获：太虚裂空剑、星渊护腕、天启圣戒、能量药剂 × 2、生命药剂 × 5、金钱 12000 已放进背包"
	# 地图／战斗态（无全屏菜单）：直接上沿
	var l := XSkinNoticeLane.lane_node()
	XSkinNoticeLane.reset()
	_push(shorts, {"icon": 907})
	l.step(0.5)
	await _shot("notice_map_short")
	XSkinNoticeLane.reset()
	_push(long)
	l.step(0.5)
	await _shot("notice_map_long")
	# 菜单态
	var page := XSkinTemplatePage.new()
	page.add_to_group(XUiSkin.FULLSCREEN_GROUP)
	get_tree().root.add_child(page)
	await frames(3)
	XSkinNoticeLane.reset()
	_push(shorts, {"icon": 907})
	l.step(0.5)
	await _shot("notice_menu_short")
	XSkinNoticeLane.reset()
	_push(long)
	l.step(0.5)
	await _shot("notice_menu_long")
	XSkinNoticeLane.reset()
	page.queue_free()
