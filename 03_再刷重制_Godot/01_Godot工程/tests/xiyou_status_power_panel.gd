extends Node
## 状态页「战力 N」按钮与角色战力面板（XPowerPanel，installEquipmentStatusRuntime renderPower）：
## - 覆盖说明：新开局各角色初始状态的「尚未完整评估的技能」「战力未计入」与正式版逐角色一致（tests/fixtures/power_coverage_oracle.json）。
## - 面板：各行文字与几何对照 tests/fixtures/power_panel_oracle.json（正式 v0.28 浏览器 DOM 读数）。
## 数值由 XPower 计算（xiyou_power 与 mv_oracle 比对；正式版浏览器开着五乘区成长修正，数字不同，面板只比结构与位置）。
## 加 -- --out=<目录> 时保存截图。

const COVERAGE := "res://tests/fixtures/power_coverage_oracle.json"
const PANEL_ORACLE := "res://tests/fixtures/power_panel_oracle.json"
## 正式版另有专属模块的角色（未移植）：小猫（178）的「至圣喵心与连携」由 CodexCat 追加
const UNPORTED_EXTRA := {"178": [["至圣喵心与连携", "剑心、追击、巨龙试炼不计入战力参考"]]}
## 未移植模块造成的差异，整角色跳过：157／160 带 <CodexDisabledActor>（正式版不能行动，技能都算条件不满足）；
## 167 渡鸦的变身钩子（formHooks：神话封解作为另一条路线评估，Godot 只评不变身路线，所以多列一条「强化/变身/切换」）
const UNPORTED_SKIP := ["157", "160", "167"]
var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_status_power_panel"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XConfig.set_flag("codexPowerEnabled", true)
	XState.new_game(3, 1, [])
	_coverage()
	XPower.clear_cache()
	var o: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PANEL_ORACLE))
	XState.new_game(3, 1, [2, 23, 85])
	await _panel(o)
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


func _coverage() -> void:
	var o: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(COVERAGE))
	var bad := []
	var t0 := Time.get_ticks_msec()
	for id in o.ids:
		var key := str(int(id))
		if UNPORTED_SKIP.has(key):
			continue
		var want: Dictionary = o.actors.get(key, {"unknown": [], "unmodeled": []})
		var a := XState.current.actor(int(id))
		var ev := XPower.evaluate(a, false)
		var unknown: Array = ev.coverage.unknown.map(func(r): return str(r.name))
		var unmodeled: Array = ev.coverage.unmodeled.map(func(r): return [str(r.name), str(r.reason)])
		var expect_unmodeled: Array = want.unmodeled.filter(func(r): return not UNPORTED_EXTRA.get(key, []).has(r))
		if unknown != want.unknown or unmodeled != expect_unmodeled:
			bad.append({"id": key, "got": [unknown, unmodeled], "want": [want.unknown, expect_unmodeled]})
	print("coverage %d actors %d ms" % [o.ids.size(), Time.get_ticks_msec() - t0])
	check("coverage_all_actors", bad.is_empty(), bad)
	check("coverage_cases", o.ids.size() >= 150 and o.actors.size() >= 30)


func frames(n := 4) -> void:
	for i in range(n):
		await get_tree().process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


## 战力数字换成 N（正式版浏览器开着五乘区成长修正，数字不同）；承伤与页签照原样比
static func norm(t: String) -> String:
	if t.contains("承伤"):
		return t
	return RegEx.create_from_string("\\d+(?:\\.\\d+)?(?:万亿|万|亿)?").sub(t, "N", true)


## 面板里看得见的文字节点 [种类, 文字, 全局矩形, 节点]
static func godot_rows(root: Node) -> Array:
	var out := []
	for n in root.find_children("*", "", true, false):
		if not (n is Control) or not n.is_visible_in_tree():
			continue
		if n is Button:
			out.append(["button", n.text, n.get_global_rect(), n])
		elif n is Label and n.text != "":
			var holder: Node = n.get_parent()
			if holder is PanelContainer and holder.has_meta("pill"):
				out.append(["pill", n.text, holder.get_global_rect(), n])
			else:
				out.append(["label", n.text, n.get_global_rect(), n])
	return out


func _panel(o: Dictionary) -> void:
	var s := XState.current
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	for key in o.actors:
		var want_rows: Array = o.actors[key]
		var a := s.actor(int(key))
		var panel := XPowerPanel.open(host, a)
		await frames()
		var got := godot_rows(panel)
		var used := {}
		var bad := []
		var attr := ""
		for r in got:
			if r[3].has_meta("span") and r[2].position.y < 240:
				if r[3].get_theme_color("font_color") == XWebPanel.MUTED or r[3].label_settings.font_color == XWebPanel.MUTED:
					attr += r[1]
		for w in want_rows:
			var tag: String = w[0]
			var text: String = norm(w[2])
			var rect := Rect2(w[3], w[4], w[5], w[6])
			if tag == "div" and w[1] == "cq-note" and text.begins_with("人物属性："):
				if not check("panel_%s_attr_text" % key, attr == text, [attr, text]):
					pass
				continue
			var hit := -1
			for i in range(got.size()):
				if not used.has(i) and norm(got[i][1]) == text and (tag != "button" or got[i][0] == "button") and (w[1] != "cq-pill" or got[i][0] == "pill"):
					hit = i
					break
			if hit < 0:
				bad.append(["missing", w])
				continue
			used[hit] = true
			var g: Rect2 = got[hit][2]
			# 行内元素（strong 高 21、属性元素名高 15）在行框里垂直居中
			var gy := g.position.y
			var gh := g.size.y
			if tag == "strong" or (tag == "span" and rect.size.y < 20):
				gy += (gh - rect.size.y) / 2
				gh = rect.size.y
			var numeric := text.contains("N")
			var w_ok := numeric or absf(g.size.x - rect.size.x) <= 3.0 or (tag in ["div", "h3"] and g.size.x >= rect.size.x - 3.0) or tag == "h2" or (tag == "strong" and g.size.x >= rect.size.x - 3.0)
			if absf(g.position.x - rect.position.x) > 2.0 and not (numeric and tag in ["span"]) or absf(gy - rect.position.y) > 2.0 or absf(gh - rect.size.y) > 1.5 or not w_ok:
				bad.append(["rect", w, [g.position.x, gy, g.size.x, gh]])
		check("panel_%s_rows" % key, bad.is_empty(), bad)
		# 胶囊不重叠、间距 7、高 28.8
		var pill_rects: Array = got.filter(func(r): return r[0] == "pill").map(func(r): return r[2])
		var pills_ok := pill_rects.size() == 3
		for i in range(1, pill_rects.size()):
			pills_ok = pills_ok and absf(pill_rects[i].position.x - pill_rects[i - 1].end.x - 7) < 0.5 and absf(pill_rects[i].size.y - 28.8) < 0.5
		check("panel_%s_pills_gap" % key, pills_ok, pill_rects)
		check("panel_%s_count" % key, used.size() >= want_rows.size() - 1, [used.size(), want_rows.size()])
		await shot("power_panel_%s" % key)
		panel.close()
		await frames()
