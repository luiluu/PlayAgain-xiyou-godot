extends Node
## 【cc·T337·未经审查】界面细节 D1c（私密仓 重制设定/界面细节规范_v0.1.md 第五节卡 D1c）：动态数值定宽栏与分列对齐。
## 1. 队伍条：100%／130% 字号下 4 人（血蓝 2／4／5 位混排）量条右缘 X 逐条完全一致；数值右缘一致；
## 2. 目标列表：量条右缘整列一致；
## 3. 数量条：9／10／100（千分位 1,000 也算）个位锚点 X 不漂移；框宽按最大值定；
## 4. 属性对比页：8 行四列（当前值右｜箭头中｜新值右｜差值右）X 锚点各列行行相同；字号缩档仍同列；
## 5. T336 核查 P3-1：draw_mono_digits／draw_num_right 的落笔坐标与描边分支（mono_digit_plan／mono_outline／num_right_pos）实调；
## 6. DETAIL_V1＝false 回到旧画法（旧 last_bars 随字宽漂、对比页回整串拼接）；窗口下逐像素：关＝旧画法（--base 另跑）。
## 带 -- --out=<目录> 且有窗口时出三组验收图：party_100／party_130、gear_cmp、stepper_9_10_100。
##   拍：godot --audio-driver Dummy --path <工程> res://tests/xiyou_ui_detail_d1c.tscn -- --out=<目录>
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const SERIF_FONT := "res://content/ui_skin/fonts/TianqiUiSerif-Heavy.otf"
const SHOT := Vector2i(1280, 720)

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
	TestEnv.isolate("xiyou_ui_detail_d1c")
	get_viewport().gui_disable_input = windowed()
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XUiSkin._clock_ms = 100000
	XUiSkin.DETAIL_V1 = true
	for pct in [100, 130]:
		XFontScale.set_value("global", pct)
		await _party_strip(pct)
		await _target_list(pct)
		await _stepper(pct)
		await _gear_cmp(pct)
	XFontScale.set_value("global", 100)
	await _helpers_p31()
	await _rollback()
	if windowed():
		await _shots()
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XUiSkin._clock_ms = -1
	XUiSkin.DETAIL_V1 = true
	XFontScale.set_value("global", 100)
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _mem(n: String, hp: int, mhp: int, mp: int, mmp: int) -> Dictionary:
	return {"name": n, "level": 30, "cls": "战士", "hp": hp, "mhp": mhp, "mp": mp, "mmp": mmp, "tp": 20, "mtp": 100, "states": []}


func _team() -> Array:
	# 血蓝位数混排：2 位、4 位、5 位
	return [_mem("甲", 88, 99, 12, 50), _mem("乙", 1234, 9999, 2345, 4000), _mem("丙", 12345, 99999, 23456, 88888), _mem("丁", 7, 10, 5, 9)]


func _strip(show_tp: bool) -> XSkinPartyStrip:
	var ps := XSkinPartyStrip.new()
	ps.show_tp = show_tp
	ps.size = Vector2(560, 4 + 4 * 60 + 8)
	add_child(ps)
	ps.set_members(_team())
	return ps


func _spread(arr: Array, idx: int, key := "") -> float:
	var lo := INF
	var hi := -INF
	for b in arr:
		if key != "" and b[1] != key:
			continue
		lo = minf(lo, float(b[idx]))
		hi = maxf(hi, float(b[idx]))
	return hi - lo


# ---- 队伍条 ----
func _party_strip(pct: int) -> void:
	for tp in [false, true]:
		var ps := _strip(tp)
		await frames(2)
		var bars := ps.last_bars
		check("party_%d_tp%s_bars_drawn" % [pct, tp], bars.size() == 4 * (3 if tp else 2), bars.size())
		for key in ["hp", "mp"] + (["tp"] if tp else []):
			check("party_%d_tp%s_%s_right_edge_same" % [pct, tp, key], _spread(bars, 2, key) == 0.0, bars)
		# 旧画法对照：关开关后右缘随位数漂（证明断言咬得住）
		XUiSkin.DETAIL_V1 = false
		ps.queue_redraw()
		await frames(2)
		if not tp:
			check("party_%d_off_hp_drifts" % pct, ps.last_bars.size() == 0, ps.last_bars)   # 旧画法不记 last_bars
		XUiSkin.DETAIL_V1 = true
		ps.queue_free()
	# 定宽栏＝格宽×位数，字号变大栏变宽
	var num := XUiSkin.font("num")
	var w := XSkinPartyStrip.value_col_w(num, XUiSkin.fs(XSkinPartyStrip.NUM_FS), "hp", _team())
	var cell := XUiSkin.mono_digit_cell(num, XUiSkin.fs(XSkinPartyStrip.NUM_FS))
	check("party_%d_col_5_digits" % pct, is_equal_approx(w, cell * 5.0), [w, cell])
	check("party_%d_col_tp_3_digits" % pct, is_equal_approx(XSkinPartyStrip.value_col_w(num, 17, "tp", _team()), XUiSkin.mono_digit_cell(num, 17) * 3.0))
	var big := [{"mhp": 1234567}]
	check("party_%d_col_grows" % pct, is_equal_approx(XSkinPartyStrip.value_col_w(num, 17, "hp", big), XUiSkin.mono_digit_cell(num, 17) * 7.0))


# ---- 目标列表 ----
func _target_list(pct: int) -> void:
	var tl := XSkinTargetList.new()
	tl.size = Vector2(520, 400)
	add_child(tl)
	tl.set_rows([
		{"name": "甲", "kind": "hp", "cur": 88, "max": 99},
		{"name": "乙", "kind": "mp", "cur": 1234, "max": 9999},
		{"name": "丙", "kind": "hp", "cur": 12345, "max": 99999, "right": "+120"},
		{"name": "丁", "kind": "tp", "cur": 7, "max": 100}])
	await frames(2)
	check("target_%d_bars_drawn" % pct, tl.last_bars.size() == 4, tl.last_bars)
	check("target_%d_right_edge_same" % pct, _spread(tl.last_bars, 1) == 0.0, tl.last_bars)
	tl.queue_free()


# ---- 数量条 ----
func _stepper(pct: int) -> void:
	var st := XSkinStepper.new()
	st.size = Vector2(420, XSkinStepper.H)
	st.sound = false
	add_child(st)
	st.set_range(1, 999, 1)
	var num := XUiSkin.font("num")
	var nr := st.number_rect()
	var lasts := []
	var boxes := []
	for v in [9, 10, 100, 999]:
		var sp := XSkinStepper.number_spec(num, nr, v, 999)
		var plan := XUiSkin.mono_digit_plan(num, sp.right, 0.0, XSkinStepper.group(v), int(sp.fs), HORIZONTAL_ALIGNMENT_RIGHT)
		lasts.append(plan.glyphs.back()[1].x)
		boxes.append(sp.right)
	check("stepper_%d_ones_anchor_same" % pct, lasts.all(func(x): return x == lasts[0]), lasts)
	check("stepper_%d_box_same" % pct, boxes.all(func(x): return x == boxes[0]), boxes)
	var sp0 := XSkinStepper.number_spec(num, nr, 9, 999)
	check("stepper_%d_box_centered" % pct, absf((sp0.right - sp0.box_w / 2.0) - (nr.position.x + nr.size.x / 2.0)) < 0.01, [sp0, nr])
	# 十位、百位也各在自己的格里：「100」比「10」多的是左边一格
	var p10 := XUiSkin.mono_digit_plan(num, sp0.right, 0.0, "10", int(sp0.fs), HORIZONTAL_ALIGNMENT_RIGHT)
	var p100 := XUiSkin.mono_digit_plan(num, sp0.right, 0.0, "100", int(sp0.fs), HORIZONTAL_ALIGNMENT_RIGHT)
	check("stepper_%d_tens_anchor_same" % pct, p10.glyphs[0][1].x == p100.glyphs[1][1].x, [p10, p100])
	# 最大值位数变了框就跟着变
	var sp_big := XSkinStepper.number_spec(num, nr, 1, 99999)
	check("stepper_%d_box_by_max" % pct, sp_big.box_w > sp0.box_w, [sp_big.box_w, sp0.box_w])
	# 真画一遍不报错
	st.set_value(10)
	await frames(2)
	check("stepper_%d_draw_ok" % pct, st.value == 10)
	st.queue_free()


# ---- 属性对比 ----
func _cmp_rows() -> Array:
	return [["最大生命", 12345, 13456], ["最大魔力", 2345, 2345], ["攻击", 345, 99], ["防御", 1234, 1500],
		["魔攻", 88, 120], ["魔防", 9999, 12000], ["敏捷", 100, 110], ["幸运", 5, 4]]


func _gear_cmp(pct: int) -> void:
	var g := XSkinGearDetail.new()
	g.size = Vector2(700, 520)
	add_child(g)
	g.tab = 1
	g.compare = true
	g._cmp = _cmp_rows()
	g._place()
	g._content_h = g._measure()
	await frames(3)
	var cols := g.last_cols
	check("gear_%d_rows_drawn" % pct, cols.size() == 8, [cols.size(), g.body.size, g.size])
	for k in [1, 2, 3, 4]:
		check("gear_%d_col%d_anchor_same" % [pct, k], _spread(cols, k) == 0.0, cols)
	var c: Array = cols[0] if cols.size() > 0 else [0, 0, 0, 0, 0]
	check("gear_%d_col_order" % pct, c[1] < c[3] and c[2] > c[1] and c[2] < c[3] and c[3] < c[4], c)
	# 窄表：字号缩档后各行仍同列
	var narrow := XSkinGearDetail.cmp_cols(XUiSkin.font("num"), 330.0, _cmp_rows(), true)
	check("gear_%d_narrow_shrinks" % pct, int(narrow.fs) < 21 and int(narrow.fs) >= 14, narrow)
	# 不比较：只有当前值，右缘＝w-12
	var solo := XSkinGearDetail.cmp_cols(XUiSkin.font("num"), 700.0, _cmp_rows(), false)
	check("gear_%d_solo_right" % pct, solo.cur_r == 688.0, solo)
	g.queue_free()


# ---- T336 核查 P3-1：实调 draw_mono_digits／draw_num_right 的落笔坐标与描边分支 ----
class Probe extends Control:
	var mono_w := 0.0
	var num_w := 0.0
	var f: Font
	var args: Array = []

	func _draw() -> void:
		mono_w = XUiSkin.draw_mono_digits(self, f, args[0], args[1], args[2], args[3], Color.WHITE, args[4], args[5])
		num_w = XUiSkin.draw_num_right(self, f, 300.5, 40.4, "12345", 20, Color.WHITE)


func _helpers_p31() -> void:
	var f := load(SERIF_FONT) as Font
	if not check("p31_font", f != null):
		return
	var fs := 34
	var cell := XUiSkin.mono_digit_cell(f, fs)
	# 落笔坐标：左／中／右三种对齐，baseline 取整
	var left := XUiSkin.mono_digit_plan(f, 100.0, 50.4, "777", fs, HORIZONTAL_ALIGNMENT_LEFT)
	check("p31_total", is_equal_approx(left.total, cell * 3.0), left)
	check("p31_baseline_rounded", left.glyphs.all(func(g): return g[1].y == 50.0), left)
	check("p31_left_first_x", left.glyphs[0][1].x == roundf(100.0 + (cell - XUiSkin.mono_digit_slots(f, "7", fs)[0][2]) * 0.5), left)
	var mid := XUiSkin.mono_digit_plan(f, 100.0, 50.0, "777", fs, HORIZONTAL_ALIGNMENT_CENTER)
	var rig := XUiSkin.mono_digit_plan(f, 100.0, 50.0, "777", fs, HORIZONTAL_ALIGNMENT_RIGHT)
	check("p31_center_shift", is_equal_approx(left.glyphs[0][1].x - mid.glyphs[0][1].x, left.total * 0.5) or absf(left.glyphs[0][1].x - mid.glyphs[0][1].x - left.total * 0.5) <= 1.0, [left, mid])
	check("p31_right_shift", absf(left.glyphs[0][1].x - rig.glyphs[0][1].x - left.total) <= 1.0, [left, rig])
	var gl: Array = left.glyphs
	check("p31_cell_step", absf((gl[1][1].x - gl[0][1].x) - cell) <= 1.0 and absf((gl[2][1].x - gl[1][1].x) - cell) <= 1.0, gl)
	# 非数字（逗号）按自身宽、不占数字格
	var cm := XUiSkin.mono_digit_slots(f, "1,0", fs)
	check("p31_comma_own_width", is_equal_approx(float(cm[1][3]), float(cm[1][2])) and is_equal_approx(float(cm[0][3]), cell), cm)
	# 描边分支：-1 跟 ds；显式 0 不描边；显式 2＋色照传
	var ds_ol := XUiSkin.mono_outline(Color.WHITE, -1, Color.RED)
	check("p31_outline_follow_ds", int(ds_ol.px) == XUiSkin.outline_size() and ds_ol.col == XUiSkin.outline_color(1.0), ds_ol)
	var ds_ol2 := XUiSkin.mono_outline(Color(1, 1, 1, 0.5), -1, Color.RED)
	check("p31_outline_follow_ds_alpha", ds_ol2.col == XUiSkin.outline_color(0.5), ds_ol2)
	var o0 := XUiSkin.mono_outline(Color.WHITE, 0, Color.RED)
	check("p31_outline_zero", int(o0.px) == 0, o0)
	var o2 := XUiSkin.mono_outline(Color.WHITE, 2, Color(0, 0, 0, 0.5))
	check("p31_outline_explicit", int(o2.px) == 2 and o2.col == Color(0, 0, 0, 0.5), o2)
	var old := XUiSkin.FONT_V00300
	XUiSkin.FONT_V00300 = false
	check("p31_outline_fontmode_off", int(XUiSkin.mono_outline(Color.WHITE, -1, Color.RED).px) == 0)
	XUiSkin.FONT_V00300 = true
	check("p31_outline_fontmode_on", int(XUiSkin.mono_outline(Color.WHITE, -1, Color.RED).px) == XUiSkin.T100_OUTLINE_PX)
	XUiSkin.FONT_V00300 = old
	# draw_num_right：右缘取整、返回字宽
	var tw := f.get_string_size("12345", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var pos := XUiSkin.num_right_pos(f, 300.5, 40.4, "12345", 20)
	check("p31_num_right_pos", pos == Vector2(roundf(300.5 - tw), 40.0), [pos, tw])
	# 真调一遍（带窗口时才有像素，这里验返回值与不崩；各分支都走）
	for ol in [-1, 0, 2]:
		var pr := Probe.new()
		pr.f = f
		pr.size = Vector2(400, 80)
		pr.args = [200.0, 40.0, "1,234", fs, HORIZONTAL_ALIGNMENT_CENTER, ol]
		add_child(pr)
		await frames(2)
		check("p31_draw_mono_return_%d" % ol, is_equal_approx(pr.mono_w, XUiSkin.mono_digits_width(f, "1,234", fs)), pr.mono_w)
		check("p31_draw_num_return_%d" % ol, is_equal_approx(pr.num_w, tw), pr.num_w)
		pr.queue_free()
	if windowed():
		await _p31_pixels(f)


## 窗口下：描边分支真画一遍，按像素验（右对齐右缘不越过锚点、outline 0 与 2 的墨迹范围差）
func _p31_pixels(f: Font) -> void:
	var fs := 34
	var inks := {}
	for ol in [0, 2]:
		var vp := SubViewport.new()
		vp.size = Vector2i(300, 90)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var pr := Probe.new()
		pr.f = f
		pr.size = Vector2(300, 90)
		pr.args = [150.0, 60.0, "111", fs, HORIZONTAL_ALIGNMENT_RIGHT, ol]
		vp.add_child(pr)
		await frames(3)
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var bb := Rect2i()
		var first := true
		for y in img.get_height():
			for x in 160:   # 只看锚点 150 左边那一块（num_right 的 12345 画在 x≈300 右侧，不进来）
				if img.get_pixel(x, y).a > 0.05:
					var p := Rect2i(x, y, 1, 1)
					bb = p if first else bb.merge(p)
					first = false
		inks[ol] = bb
		vp.queue_free()
	check("p31_pixels_ink_exists", inks[0].size.x > 0 and inks[2].size.x > 0, inks)
	check("p31_pixels_right_edge_within_anchor", inks[0].end.x <= 152, inks)
	check("p31_pixels_outline_grows", inks[2].size.x > inks[0].size.x and inks[2].size.y > inks[0].size.y, inks)


# ---- 回退开关 ----
func _rollback() -> void:
	XUiSkin.DETAIL_V1 = false
	var g := XSkinGearDetail.new()
	g.size = Vector2(700, 520)
	add_child(g)
	g.tab = 1
	g.compare = true
	g._cmp = _cmp_rows()
	g._place()
	g._content_h = g._measure()
	await frames(3)
	check("rollback_gear_old_path", g.last_cols.is_empty(), g.last_cols)
	g.queue_free()
	var ps := _strip(false)
	await frames(2)
	check("rollback_party_old_path", ps.last_bars.is_empty(), ps.last_bars)
	ps.queue_free()
	XUiSkin.DETAIL_V1 = true


# ---- 窗口：三组验收图 ----
func _shots() -> void:
	var win := get_window()
	win.size = SHOT
	for pct in [100, 130]:
		XFontScale.set_value("global", pct)
		var root := _stage()
		var ps := XSkinPartyStrip.new()
		ps.show_tp = false
		ps.position = Vector2(20, 60)
		ps.size = Vector2(580, 4 + 4 * 60 + 8)
		root.add_child(ps)
		ps.set_members(_team())
		var ps2 := XSkinPartyStrip.new()
		ps2.show_tp = true
		ps2.position = Vector2(640, 60)
		ps2.size = Vector2(580, 4 + 4 * 60 + 8)
		root.add_child(ps2)
		ps2.set_members(_team())
		_caption(root, "队伍条 %d%%：左 主菜单（血蓝）｜右 战斗（含 TP）；红线＝量条右缘最大值" % pct, Vector2(20, 18))
		await frames(3)
		_rule(root, ps.last_bars, ps.position)
		_rule(root, ps2.last_bars, ps2.position)
		await _grab("party_%d" % pct)
		root.queue_free()
		await frames(2)
	XFontScale.set_value("global", 100)
	# 属性对比
	var r2 := _stage()
	var g := XSkinGearDetail.new()
	g.position = Vector2(290, 40)
	g.size = Vector2(700, 560)
	r2.add_child(g)
	g.tab = 1
	g.compare = true
	g._cmp = _cmp_rows()
	g._place()
	g._content_h = g._measure()
	g.item = {"id": 1}
	await frames(3)
	await _grab("gear_cmp")
	r2.queue_free()
	await frames(2)
	# 数量条 9／10／100
	var r3 := _stage()
	var y := 80.0
	for v in [9, 10, 100]:
		var st := XSkinStepper.new()
		st.position = Vector2(300, y)
		st.size = Vector2(420, XSkinStepper.H)
		st.sound = false
		r3.add_child(st)
		st.set_range(1, 999, 1)
		st.set_value(v)
		y += 90.0
	await frames(3)
	var sp := XSkinStepper.number_spec(XUiSkin.font("num"), Rect2(Vector2(300 + 44 + 6 + 44 + 6, 0), Vector2(420 - 44 * 4 - 6 * 5 - 64, 44)), 9, 999)
	_caption(r3, "数量条 9／10／100：个位始终对齐（红线＝个位右缘）", Vector2(300, 30))
	var line := ColorRect.new()
	line.color = Color("ff3030")
	line.position = Vector2(sp.right, 70)
	line.size = Vector2(1, 270)
	r3.add_child(line)
	await frames(2)
	await _grab("stepper_9_10_100")
	r3.queue_free()


func _stage() -> Control:
	var root := Control.new()
	root.size = Vector2(SHOT)
	var bg := ColorRect.new()
	bg.color = Color("090808")
	bg.size = root.size
	root.add_child(bg)
	add_child(root)
	return root


func _caption(root: Control, text: String, pos: Vector2) -> void:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_override("font", XUiSkin.font("body"))
	lb.add_theme_font_size_override("font_size", 20)
	lb.add_theme_color_override("font_color", XUiSkin.GOLD)
	lb.position = pos
	root.add_child(lb)


func _rule(root: Control, bars: Array, origin: Vector2) -> void:
	var mx := -INF
	for b in bars:
		mx = maxf(mx, float(b[2]))
	for key in ["hp", "mp", "tp"]:
		var xs := bars.filter(func(b): return b[1] == key)
		if xs.is_empty():
			continue
		var l := ColorRect.new()
		l.color = Color(1, 0.2, 0.2, 0.8)
		l.position = origin + Vector2(float(xs[0][2]), 0)
		l.size = Vector2(1, 4 + 4 * 60 + 8)
		root.add_child(l)


func _grab(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	check("shot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK)
