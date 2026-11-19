extends Node
## 【cc·天启篇】新界面 2C 卡 A 专项（T265，照 T254 1.1 落印、1.2 灭印）：胜利结算、全灭画面。
## 一场真战斗当底（难度 3、队伍 1/8/9/10、敌群 4），内存新游戏，不写存档；结算页、全灭页手搭在上面：
##   old：XUiSkin.FORCE＝false —— 旧画法（没有新皮肤层、旧提示窗、32 帧淡入、24 帧淡入）一行不变；
##   new：XUiSkin.FORCE＝true —— 落印／灭印。核：进场时长（首领 ≤1.0、小怪 ≤0.5）、跳过直接定格、大圆章 ≤4 枚且只给史诗以上、
##        没掉落时掉落排和详单入口都没有、品质排序关着时顺序同旧版、自动战斗 3.4 秒发 continued、详单里拖动不关页／松手没拖才关、
##        全灭提示在 NULL 全显前看不到、灭印中按确定直接全显、全显后再按才淡出回标题。
## 窗口模式加 -- --out=<目录> 拍验收截图（800×450 一套、20:9 的 1000×450 一套），每张新画法配一张旧画法对照（左旧右新）。

var results := []
var out_dir := ""
var _shots := {}     # 名字 → Image
var _done := []
var b: XBattleScene
var lg: XBattleLogic
var _helper: XActor


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _until(cond: Callable, n := 900) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _shooting() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


## 截一张：16:9 缩成 800×450，20:9 缩成 1000×450
func _shot(name: String) -> void:
	if not _shooting():
		return
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var w := 1000 if img.get_width() > 1300 else 800
	img.resize(w, 450, Image.INTERPOLATE_LANCZOS)
	_shots[name] = img
	_check("shot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK)


## 左右对照：左旧右新，中间 8px 黑缝
func _pair(name: String, before: String, after: String) -> void:
	if not (_shots.has(before) and _shots.has(after)):
		return
	var a: Image = _shots[before]
	var c: Image = _shots[after]
	var out := Image.create(a.get_width() + c.get_width() + 8, 450, false, a.get_format())
	out.fill(Color.BLACK)
	out.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i(0, 0))
	out.blit_rect(c, Rect2i(Vector2i.ZERO, c.get_size()), Vector2i(a.get_width() + 8, 0))
	_check("pair_" + name, out.save_png(out_dir.path_join("对照_" + name + ".png")) == OK)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_ui_skin_2c"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XEnemy.force_roll = 100.0
	if _shooting():
		DirAccess.make_dir_recursive_absolute(out_dir)
	_unit()
	if not await _open_battle():
		_finish()
		return
	await _victory_rules()
	await _gameover_rules()
	if _shooting():
		var token := Node.new()   # 新皮肤的战斗会申请横屏铺满；这里手搭，自己申请（20:9 视口 1600×720）
		add_child(token)
		XSkinLayout.request_wide(token, true)
		for sz in [[Vector2i(1280, 720), ""], [Vector2i(1600, 720), "_20x9"]]:
			get_window().size = sz[0]
			await _frames(4)
			XSkinLayout._apply_wide(get_tree().root)   # 窗口改大小的信号在测试里不一定及时到，直接按现在的窗口换一次
			await _frames(4)
			_check("viewport_" + str(sz[1]), int(get_viewport().get_visible_rect().size.x) == sz[0].x, [get_viewport().get_visible_rect().size, get_window().size, get_tree().root.content_scale_aspect, XSkinLayout.wide_active()])
			await _victory_shots(str(sz[1]))
			await _gameover_shots(str(sz[1]))
		get_window().size = Vector2i(1280, 720)
		token.queue_free()
	b.bgm.stop()
	b.queue_free()
	await _frames(3)
	_finish()


## ---- 纯函数 ----

func _unit() -> void:
	XUiSkin.FORCE = true
	XSkin2C.ENABLED = false
	_check("master_switch_off", not XSkin2C.on() and not XSkin2C.victory_on() and not XSkin2C.gameover_on())
	XSkin2C.ENABLED = true
	XSkin2C.VICTORY = false
	_check("victory_switch_off", XSkin2C.on() and not XSkin2C.victory_on() and XSkin2C.gameover_on())
	XSkin2C.VICTORY = true
	_check("summary_default_off", not XSkin2C.GAMEOVER_SUMMARY and XSkin2C.gameover_summary(XState.current, 4).is_empty())
	_check("intro_lengths", XSkin2C.intro_len(true, XUiSkin.Motion.FULL) <= 1.0 and XSkin2C.intro_len(false, XUiSkin.Motion.FULL) <= 0.5
		and XSkin2C.intro_len(true, XUiSkin.Motion.OFF) == 0.0 and XSkin2C.intro_len(false, XUiSkin.Motion.SIMPLE) <= 0.2,
		[XSkin2C.intro_len(true, XUiSkin.Motion.FULL), XSkin2C.intro_len(false, XUiSkin.Motion.FULL)])
	var dr := _mixed_drops(30)
	var row := XSkin2C.drop_row(XVictoryScreen.grouped_drops(dr), 1168.0)
	_check("big_medals_max4", row.big.size() <= XSkin2C.BIG_MAX and row.big.size() > 0, row.big.size())
	_check("big_medals_epic_only", row.big.all(func(e): return XSkin2C.drop_grade(e[0]) >= 3))
	_check("big_medals_by_grade", row.big.size() < 2 or XSkin2C.drop_grade(row.big[0][0]) >= XSkin2C.drop_grade(row.big[-1][0]))
	_check("drop_row_fits", float(row.width) <= 1168.0 and int(row.more) > 0, [row.width, row.more])
	var row_w := XSkin2C.drop_row(XVictoryScreen.grouped_drops(dr), 1488.0)
	_check("drop_row_wide_more_room", row_w.small.size() > row.small.size(), [row_w.small.size(), row.small.size()])
	var g := XVictoryScreen.grouped_drops(dr)
	var srt := XSkin2C.sort_by_quality(g)
	_check("sort_quality_desc", range(srt.size() - 1).all(func(i): return XSkin2C.drop_grade(srt[i]) >= XSkin2C.drop_grade(srt[i + 1])))
	_check("sort_keeps_items", srt.size() == g.size())
	XUiSkin.FORCE = false


## ---- 战斗底 ----

func _open_battle() -> bool:
	seed(20261119)
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	for a in s.members():
		a.refresh_passive()
		a.param_mark_dirty()
		a.recover_all()
	s.random_master = XRandomStream.hex64(20261119)
	b = XBattleScene.new()
	b.setup(4, true, false, {})
	add_child(b)
	var ok := await _until(func(): return b.cmd_win != null and b.cmd_win.active)
	_check("battle_command_shown", ok)
	if not ok:
		return false
	lg = b.logic
	# 实际胜利时：窗口收起、伤害统计移除、敌人倒下
	for n in b.ui.get_children():
		if n is CanvasItem:
			n.hide()
	b.low_ui.hide()
	b._end_record()
	b.combo.hide()
	if b.boss_panel != null:
		b.boss_panel.set_process(false)
		b.boss_panel.hide()
	for e in lg.enemies:
		if b.sprites.has(e):
			b.sprites[e].hide()
	b.fx.hide()
	for e in b.gauges:
		b.gauges[e].box.hide()
	for i in lg.actors.size():
		var a: XActor = lg.actors[i]
		a.change_level(clampi(5 + i * 2, 2, a.max_level() - 1))
		a.exp_total = a.exp_for_level(a.level) + (a.exp_for_level(a.level + 1) - a.exp_for_level(a.level)) * (3 + i * 2) / 10
	_helper = s.actor(5)
	_helper.change_level(_helper.max_level())
	return true


## 战前快照：第二人这一场从低一级升上来；助力位满级
func _before(with_helper := false) -> Dictionary:
	var before := {}
	for i in lg.actors.size():
		var a: XActor = lg.actors[i]
		var lv := a.level - (1 if i == 1 else 0)
		before[a] = {"level": lv, "exp": a.exp_for_level(lv) + (a.exp_for_level(lv + 1) - a.exp_for_level(lv)) / 2 if i == 1 else a.exp_total - 300}
	if with_helper:
		before[_helper] = {"level": _helper.level, "exp": _helper.exp_total}
	return before


func _victory(drops: Array, boss: bool, auto := false, helper := false) -> XVictoryScreen:
	var v := XVictoryScreen.new()
	var info := {"boss": boss}
	if helper:
		info.helper = _helper
	v.setup({"gold": 12345, "exp": 6789, "drops": drops}, _before(helper), lg.actors, auto, info)
	b.ui.add_child(v)
	return v


## 停在第 t 秒（不走 _process）
func _freeze(v: XVictoryScreen, t: float) -> void:
	v.set_process(false)
	v._elapsed = t
	v._update_exp(clampf(t / 3.0, 0, 1))
	v._ready_to_close = t >= 1.0
	for row in v.rows:
		if row.notified:
			row.lv_scale = 1.0
			row.lv_opacity = 255.0
	if v._skin != null:
		v._skin._process(0.0)
	else:
		v.modulate.a = clampf(t / (32.0 / 60.0), 0.0, 1.0)
		v.hint.visible = t >= 1.0
		v.canvas.queue_redraw()


func _key(action: String, pressed := true) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	return e


func _mouse(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	return e


func _motion(pos: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	return e


## ---- 胜利结算规则 ----

func _victory_rules() -> void:
	var drops := _mixed_drops(30)
	for mode in ["old", "new"]:
		XUiSkin.FORCE = mode == "new"
		XUiSkin.motion_override = XUiSkin.Motion.FULL
		var new: bool = mode == "new"
		var v := _victory(drops, true, false, true)
		await _frames(2)
		_check("%s_victory_skin_layer" % mode, (v._skin != null) == new)
		_check("%s_victory_old_canvas" % mode, v.canvas.visible == not new)
		_check("%s_helper_row" % mode, v.rows.size() == lg.actors.size() + (1 if new else 0), v.rows.size())
		# 品质排序：新画法开着按档排；关着／旧画法同旧序
		var old_order := XVictoryScreen.grouped_drops(drops)
		if new:
			_check("new_sorted_by_quality", v._drops == XSkin2C.sort_by_quality(old_order))
		else:
			_check("old_order_unchanged", v._drops == old_order)
		# 跑到底：1 秒前确定＝跳过（直接定格、可关），再确定＝continued
		var fired := [0]
		v.continued.connect(func(): fired[0] += 1)
		v._elapsed = 0.3
		v._input(_key("ui_accept"))
		_check("%s_skip_to_final" % mode, v._ready_to_close and v._elapsed >= 3.0 and fired[0] == 0)
		if new:
			_check("new_skip_intro_done", v._skin.intro_done())
		v._input(_key("ui_accept"))
		_check("%s_runs_to_end" % mode, fired[0] == 1)
		v.queue_free()
		await _frames(2)
		# 品质排序开关关着：新画法顺序同旧
		if new:
			XSkin2C.DROP_SORT_QUALITY = false
			var v2 := _victory(drops, false)
			_check("new_sort_off_same_as_old", v2._drops == old_order)
			v2.queue_free()
			XSkin2C.DROP_SORT_QUALITY = true
	# 新画法：进场时长、自动关、没掉落、详单
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	for boss in [true, false]:
		var v := _victory(drops, boss)
		await _frames(1)
		_freeze(v, (1.0 if boss else 0.5) - 0.001)
		_check("intro_not_done_before_%s" % ("boss" if boss else "minor"), not v._skin.intro_done())
		_freeze(v, 1.0 if boss else 0.5)
		_check("intro_done_at_%s" % ("boss" if boss else "minor"), v._skin.intro_done())
		v.queue_free()
	# 自动战斗：3.4 秒自己发 continued（真跑 _process）
	var va := _victory(drops, false, true)
	var auto_fired := [0]
	va.continued.connect(func(): auto_fired[0] += 1)
	var t0 := Time.get_ticks_msec()
	while auto_fired[0] == 0 and Time.get_ticks_msec() - t0 < 6000:
		await get_tree().process_frame
	var ok: bool = auto_fired[0] > 0
	_check("auto_continue", ok and auto_fired[0] == 1, (Time.get_ticks_msec() - t0) / 1000.0)
	_check("auto_continue_time", va._elapsed >= 3.4 and va._elapsed < 3.6, va._elapsed)
	va.queue_free()
	# 没有掉落：掉落排、「看全部掉落」、详单都没有
	var vn := _victory([], true)
	await _frames(2)
	_freeze(vn, 3.0)
	_check("no_drops_no_hint", not vn._skin.hints.hints.any(func(h): return str(h[0]) == "↑"), vn._skin.hints.hints)
	vn._skin.handle(_key("ui_up"))
	_check("no_drops_no_detail", not vn._skin.detail)
	_check("no_drops_row_empty", vn._skin._row.big.is_empty() and vn._skin._row.small.is_empty())
	vn.queue_free()
	# 详单：↑ 打开；拖动滚列表不关页；松手没拖才关
	var vd := _victory(drops, true)
	await _frames(2)
	_freeze(vd, 3.0)
	var closed := [0]
	vd.continued.connect(func(): closed[0] += 1)
	vd._input(_key("ui_up"))
	_check("detail_opens", vd._skin.detail)
	_check("detail_hint_collapse", vd._skin.hints.hints.any(func(h): return str(h[1]) == "收起"))
	var pr: Rect2 = vd._skin._detail_rect()
	var p0 := pr.position + Vector2(200, pr.size.y - 60)
	vd._input(_mouse(p0, true))
	vd._input(_motion(p0 - Vector2(0, 90)))
	vd._input(_mouse(p0 - Vector2(0, 90), false))
	_check("detail_drag_scrolls", vd._drop_top > 0, vd._drop_top)
	_check("detail_drag_not_close", closed[0] == 0 and vd._skin.detail)
	vd._input(_key("ui_down"))
	_check("detail_scroll_capped", vd._drop_top <= XSkin2C.detail_scroll_max(vd))
	vd._input(_key("ui_cancel"))
	_check("detail_cancel_closes_detail_only", not vd._skin.detail and closed[0] == 0)
	vd._input(_key("ui_up"))
	vd._input(_mouse(p0, true))
	vd._input(_mouse(p0, false))
	_check("detail_tap_continues", closed[0] == 1)
	vd.queue_free()
	await _frames(2)
	XUiSkin.motion_override = -1
	XUiSkin.FORCE = false
	_done.append("victory")


## ---- 全灭规则 ----

func _gameover_rules() -> void:
	for mode in ["old", "new"]:
		XUiSkin.FORCE = mode == "new"
		XUiSkin.motion_override = XUiSkin.Motion.FULL
		var g := XGameOverScreen.new()
		g.set_physics_process(false)
		add_child(g)
		await _frames(1)
		var st := g.state()
		_check("%s_gameover_skin" % mode, bool(st.skin) == (mode == "new") and st.image == "NULL", st)
		var fin := [false]
		g.finished.connect(func(): fin[0] = true)
		if mode == "new":
			for i in 30:
				g.step(false)
			_check("new_hint_hidden_mid_intro", not g.state().shown and g.state().hint == 0.0, g.state())
			g.step(true)
			_check("new_press_jumps_to_full", g.state().shown and not g.state().fading_out, g.state())
			for i in XSkin2C.GO_HINT_DELAY:
				g.step(false)
			_check("new_hint_after_full", is_equal_approx(float(g.state().hint), 1.0), g.state())
			# 不按不走
			for i in 40:
				g.step(false)
			_check("new_waits_without_press", not g.state().fading_out and not g.state().done)
		else:
			for i in XGameOverScreen.FADE_FRAMES + 2:
				g.step(false)
			_check("old_waits_without_press", g.state().frame == XGameOverScreen.FADE_FRAMES and not g.state().fading_out)
		g.step(true)
		_check("%s_fading_out" % mode, g.state().fading_out)
		for i in XGameOverScreen.FADE_FRAMES + 2:
			g.step(false)
		_check("%s_gameover_finished" % mode, fin[0] and g.state().done)
		await _frames(2)
	# 新画法跑满 60 帧不按：自己到全显
	XUiSkin.FORCE = true
	var g2 := XGameOverScreen.new()
	g2.set_physics_process(false)
	add_child(g2)
	await _frames(1)
	for i in XSkin2C.GO_INTRO_FULL:
		g2.step(false)
	_check("new_intro_full_after_1s", g2.state().shown, g2.state())
	g2.queue_free()
	XUiSkin.motion_override = -1
	XUiSkin.FORCE = false
	_done.append("gameover")


## ---- 验收截图 ----

## suffix：""＝16:9（800×450），"_20x9"＝1000×450
func _victory_shots(suffix: String) -> void:
	var drops := _mixed_drops(30)
	var few := _mixed_drops(8)
	var bg: Texture2D = load("res://content/ui_skin/phase01/bg/war_%s.png" % ("1600x720" if suffix != "" else "1280x720"))
	# 旧画法对照（定格）
	XUiSkin.FORCE = false
	var vo := _victory(drops, true)
	await _frames(2)
	_freeze(vo, 3.0)
	await _shot("旧_结算定格" + suffix)
	vo.queue_free()
	var vo2 := _victory([], false, true)
	await _frames(2)
	_freeze(vo2, 2.0)
	await _shot("旧_结算无掉落自动" + suffix)
	vo2.queue_free()
	XUiSkin.FORCE = true
	var plan := []
	if suffix == "":
		plan = [
			["首领进场_0.10", drops, true, false, false, 0.10, XUiSkin.Motion.FULL, 100],
			["首领进场_0.25", drops, true, false, false, 0.25, XUiSkin.Motion.FULL, 100],
			["首领进场_0.45", drops, true, false, false, 0.45, XUiSkin.Motion.FULL, 100],
			["首领进场_1.0", drops, true, false, false, 1.0, XUiSkin.Motion.FULL, 100],
			["小怪半程_0.25", few, false, false, false, 0.25, XUiSkin.Motion.FULL, 100],
			["小怪半程_0.5", few, false, false, false, 0.5, XUiSkin.Motion.FULL, 100],
			["定格常态", few, false, false, false, 3.0, XUiSkin.Motion.FULL, 100],
			["有人升级", few, true, false, false, 3.0, XUiSkin.Motion.FULL, 100],
			["五人满级助力", few, true, false, true, 3.0, XUiSkin.Motion.FULL, 100],
			["掉落很多", drops, true, false, false, 3.0, XUiSkin.Motion.FULL, 100],
			["无掉落自动", [], false, true, false, 2.0, XUiSkin.Motion.FULL, 100],
			["前1秒跳过", few, true, false, false, 0.6, XUiSkin.Motion.FULL, 100],
			["字体130", drops, true, false, true, 3.0, XUiSkin.Motion.FULL, 130],
			["简化_0.1", few, true, false, false, 0.1, XUiSkin.Motion.SIMPLE, 100],
			["关", few, true, false, false, 0.0, XUiSkin.Motion.OFF, 100],
		]
	else:
		plan = [
			["掉落很多", drops, true, false, false, 3.0, XUiSkin.Motion.FULL, 100],
			["五人满级助力", few, true, false, true, 3.0, XUiSkin.Motion.FULL, 100],
		]
	for p in plan:
		XUiSkin.motion_override = int(p[6])
		XFontScale.set_value("global", int(p[7]))
		var v := _victory(p[1], bool(p[2]), bool(p[3]), bool(p[4]))
		await _frames(2)
		v._skin._bg = bg
		if str(p[0]) == "前1秒跳过" or str(p[0]) == "首领进场_1.0":
			v._ready_to_close = false
		_freeze(v, float(p[5]))
		if str(p[0]) == "前1秒跳过":
			v._ready_to_close = false
			v._skin._process(0.0)
		var name := "新_结算_%s%s" % [p[0], suffix]
		await _shot(name)
		_pair("结算_%s%s" % [p[0], suffix], ("旧_结算无掉落自动" if str(p[0]) == "无掉落自动" else "旧_结算定格") + suffix, name)
		if str(p[0]) == "掉落很多":
			v._skin.open_detail(true)
			v._skin._process(0.0)
			await _shot("新_结算_详单首屏" + suffix)
			_pair("结算_详单首屏" + suffix, "旧_结算定格" + suffix, "新_结算_详单首屏" + suffix)
			v._drop_top = XSkin2C.detail_scroll_max(v)
			v._skin._process(0.0)
			await _shot("新_结算_详单滚到底" + suffix)
			_pair("结算_详单滚到底" + suffix, "旧_结算定格" + suffix, "新_结算_详单滚到底" + suffix)
		v.queue_free()
		await _frames(2)
	XFontScale.set_value("global", 100)
	XUiSkin.motion_override = -1
	XUiSkin.FORCE = false


func _gameover_shots(suffix: String) -> void:
	await _frames(2)
	var shot := ImageTexture.create_from_image(get_viewport().get_texture().get_image()) if _shooting() else null
	# 旧画法（淡入完）
	XUiSkin.FORCE = false
	var go := XGameOverScreen.new()
	go.set_physics_process(false)
	add_child(go)
	for i in XGameOverScreen.FADE_FRAMES:
		go.step()
	await _shot("旧_全灭" + suffix)
	go.queue_free()
	await _frames(2)
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	var plan := [["灭印_0.3", 18, false], ["灭印_0.7", 42, false], ["A定格", 80, false], ["B定格", 80, true]] if suffix == "" else [["A定格", 80, false]]
	for p in plan:
		XSkin2C.GAMEOVER_SUMMARY = bool(p[2])
		var g := XGameOverScreen.new()
		g.set_physics_process(false)
		g.battle_shot = shot
		g.summary = ["第 31 层 · 艰险 · 战争线", "倒在【守层者】里德面前"] if bool(p[2]) else []
		add_child(g)
		await _frames(1)
		for i in int(p[1]):
			g.step()
		var name := "新_全灭_%s%s" % [p[0], suffix]
		await _shot(name)
		_pair("全灭_%s%s" % [p[0], suffix], "旧_全灭" + suffix, name)
		g.queue_free()
		await _frames(2)
	XSkin2C.GAMEOVER_SUMMARY = false
	XUiSkin.motion_override = -1
	XUiSkin.FORCE = false


## n 样掉落：先挑有品质、显示档史诗以上的武器防具（最多 6 样，档高低混着），再轮着补物品、武器、防具（每 4 样重复一样成 ×2）
func _mixed_drops(n: int) -> Array:
	var out := []
	var high := {3: 0, 4: 0, 5: 0, 6: 0}
	for k in [[2, "Weapons"], [3, "Armors"]]:
		for id in range(1, 3000):
			var rec := XDB.rec(str(k[1]), id)
			if rec.is_empty() or str(rec.get("name", "")) == "" or int(rec.get("iconIndex", 0)) <= 0 or not XQuality.has_quality(rec):
				continue
			var gr := XQuality.show_grade(rec)
			if gr >= 3 and high[gr] < 2 and out.size() < 6:
				high[gr] += 1
				out.append({"kind": int(k[0]), "id": id})
	var kinds := [[1, "Items"], [2, "Weapons"], [3, "Armors"]]
	var next := {1: 1, 2: 1, 3: 1}
	var guard := 0
	while out.size() < n and guard < 6000:
		guard += 1
		var k: Array = kinds[out.size() % 3]
		var id: int = next[k[0]]
		next[k[0]] = id + 1
		var rec := XDB.rec(str(k[1]), id)
		if rec.is_empty() or str(rec.get("name", "")) == "" or int(rec.get("iconIndex", 0)) <= 0:
			continue
		if XQuality.has_quality(rec) and XQuality.show_grade(rec) >= 3:
			continue
		out.append({"kind": int(k[0]), "id": id})
		if out.size() % 4 == 0:
			out.append({"kind": int(k[0]), "id": id})
	# 打乱成「物品／武器／防具编号序」以外的顺序，好看出排序
	var mixed := out.slice(0, n)
	mixed.reverse()
	return mixed


func _finish() -> void:
	_check("all_parts_reached_end", _done == ["victory", "gameover"], _done)
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XEnemy.force_roll = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
