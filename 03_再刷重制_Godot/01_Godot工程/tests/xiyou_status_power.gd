extends Node
## 状态页战力条（XPowerStrip）与装备变更战力提示（XPowerNotice），对照 tests/fixtures/status_power_oracle.json
## （正式 v0.28 浏览器读数：战力条各段 drawText 的位置、宽、字号、颜色与人物属性分段，提示框几何与文字）。
## 数值本身由 XPower 计算（xiyou_power 已与 mv_oracle 比对；正式版浏览器开着五乘区成长修正，数字不同，这里只比画法）。
## 加 -- --out=<目录> 时保存截图。

const ORACLE := "res://tests/fixtures/status_power_oracle.json"
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


func frames(n := 4) -> void:
	for i in range(n):
		await get_tree().process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


static func css(c: String) -> Color:
	if c.begins_with("rgb"):
		var v := c.substr(c.find("(") + 1).trim_suffix(")").split(",")
		return Color8(int(v[0]), int(v[1]), int(v[2]), int(roundf(float(v[3]) * 255)) if v.size() > 3 else 255)
	return Color(c)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_status_power"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XConfig.set_flag("codexPowerEnabled", true)
	var o: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	var ids: Array = o.actors.map(func(x): return int(x.actorId))
	var s := XState.new_game(3, ids[0], ids.slice(1))
	await _strip(o, s)
	await _notice(o, s)
	XConfig.set_flag("codexPowerEnabled", true)
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


func _strip(o: Dictionary, s: XState) -> void:
	var page := XStatusPage.new()
	add_child(page)
	await frames()
	for i in range(o.actors.size()):
		var want: Dictionary = o.actors[i]
		page.actor_index = i
		page.rebuild()
		await frames()
		var strip := page.power_strip
		var a := s.actor(int(want.actorId))
		if not check("strip_exists_%d" % a.actor_id, strip != null and is_same(strip.actor, a)):
			continue
		# 位置：(24, 页窗原 y) 宽 = 画面宽 − 48，高 36；页窗下移 36（本页窗原 y 是 280，正式版 72，见 status_page.gd）
		var body := strip.get_parent().get_children().filter(func(n): return n is PanelContainer).back() as Control
		check("strip_rect_%d" % a.actor_id, strip.position.x == o.strip[0] and strip.size == Vector2(o.strip[2], o.strip[3])
			and body.position.y == strip.position.y + 36 and body.size.y == 720 - strip.position.y - 36,
			[strip.position, strip.size, body.position, body.size])
		var got := strip.layout()
		var p := XPower.actor(a)
		var calls: Array = want.calls
		var ok := got.size() == calls.size()
		var diff := []
		for k in range(mini(got.size(), calls.size())):
			var g: Array = got[k]
			var w: Array = calls[k]
			var text := str(w[0])
			# 数字由 XPower 填；O-031 打开时第三段多「装备提升 +N」
			if text == "战力：N":
				text = "战力：" + XPower.format(float(p.total))
			elif text.begins_with("自身"):
				text = XPowerStrip.detail_text(p)
				check("detail_original_shape_%d" % a.actor_id, XPowerStrip.SHOW_GEAR_GAIN or RegEx.create_from_string("^自身 \\S+  ·  装备战力 \\S+$").search(text) != null, text)
			var same: bool = g[0] == text and absf(float(g[1]) - float(w[1])) <= 1.0 and absf(float(g[2]) - float(w[2])) <= 1.0 \
				and float(g[3]) == float(w[3]) and int(g[4]) == int(w[4]) and (g[5] as Color).is_equal_approx(css(str(w[5]))) and g[6] == w[6]
			if not same:
				diff.append([g, w])
			ok = ok and same
		check("strip_calls_%d" % a.actor_id, ok, diff)
		if a.actor_id == 23:
			await shot("01_状态页战力条_23")
	# 第三段：自身 + 装备提升 = 总战力（O-031）；装备战力是各件装备评分之和
	var a1 := s.actor(int(o.actors[0].actorId))
	var p1 := XPower.actor(a1)
	check("gear_gain_sums_to_total", int(p1.self) + int(p1.gear) == int(p1.total) and XPowerStrip.detail_text(p1).contains("装备提升 " + XPowerNotice.delta(float(p1.gear))), p1)
	# 关掉「战力显示与估算」：不建条、页窗不下移
	XConfig.set_flag("codexPowerEnabled", false)
	XPower.clear_cache()
	page.actor_index = 0
	page.rebuild()
	await frames()
	var body0 := page.content.get_children().filter(func(n): return n is PanelContainer and not n.is_queued_for_deletion()).back() as Control
	check("strip_hidden_when_disabled", page.power_strip == null and body0.position.y == 280, [page.power_strip, body0.position])
	XConfig.set_flag("codexPowerEnabled", true)
	XPower.clear_cache()
	page.queue_free()
	await frames()


func _notice(o: Dictionary, s: XState) -> void:
	var n: Dictionary = o.notice
	var a := s.actor(int(n.examples[0].actorId))
	for ex in n.examples:
		check("notice_text_%d" % int(ex.after), XPowerNotice.message(a, float(ex.before), float(ex.after)) == str(ex.text), XPowerNotice.message(a, float(ex.before), float(ex.after)))
	check("notice_text_equal", XPowerNotice.message(a, 5, 5).ends_with("战力变化 0\n当前总战力：5"))
	check("notice_text_large", XPowerNotice.message(a, 0, 123456).contains("+12.35万"))
	# 装备页：清空 → 装上；装备真的变了才弹，数值是换装前后的总战力
	var equip := XEquipScene.new()
	add_child(equip)
	await frames()
	var worn := a.equips.duplicate()
	var before := float(XPower.actor(a).total)
	equip._cmd = 1  # 清空
	equip._ok()
	await frames()
	var layer := XPowerNotice.current()
	var after := float(XPower.actor(a).total)
	check("notice_on_clear", layer != null and XPowerNotice.last_change.get("before") == before and XPowerNotice.last_change.get("after") == after
		and layer.box.text == XPowerNotice.message(a, before, after), [XPowerNotice.last_change, before, after])
	if layer != null:
		var box := layer.box.get_global_rect()
		check("notice_anchor", absf(box.end.x - (1280 - n.right)) <= 1 and absf(box.end.y - (720 - n.bottom)) <= 1, box)
		check("notice_height", absf(box.size.y - n.box[3]) <= 2, box)
		check("notice_width_close", absf(box.size.x - n.box[2]) <= 24, [box.size.x, n.box[2]])
		var st := layer.box.style
		check("notice_style", st.bg_color.is_equal_approx(css(n.background)) and st.corner_radius_top_left == n.radius and st.border_width_left == 1
			and XPowerNotice.GOLD.is_equal_approx(css(n.color)) and XPowerNotice.FONT_SIZE == 20)
		await shot("02_装备变更战力提示")
	# 再清空一次：身上已空，不变就不弹（last_change 不变）
	XPowerNotice.last_change = {}
	equip._cmd = 1
	equip._ok()
	await frames()
	check("no_notice_without_change", XPowerNotice.last_change.is_empty())
	# 装回原来的武器
	if worn[0] != null and not (worn[0] as Dictionary).is_empty():
		equip._cmd = 0
		equip._ok()
		equip._slot = 0
		equip._ok()
		var idx := equip.candidates().find_custom(func(r): return is_same(r.get("rec", r), worn[0]))
		check("weapon_candidate_found", idx >= 0, equip.candidates().size())
		if idx >= 0:
			equip._item_index = idx
			equip._ok()
			await frames()
			check("notice_on_equip", XPowerNotice.last_change.get("delta", 0) == float(XPower.actor(a).total) - after and XPowerNotice.current() != null)
	# 3.5 秒后消失；关掉战力时不弹
	await get_tree().create_timer(XPowerNotice.TIMEOUT + 0.2).timeout
	check("notice_timeout", XPowerNotice.current() == null)
	XConfig.set_flag("codexPowerEnabled", false)
	XPowerNotice.last_change = {}
	equip._cmd = 1
	equip._ok()
	await frames()
	check("no_notice_when_disabled", XPowerNotice.last_change.is_empty() and XPowerNotice.current() == null)
	equip.queue_free()
	await frames()
