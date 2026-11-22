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
var only := ""        # -- --only=a／b／u：只跑卡 A、卡 B 或卡 U（开发时用；检查脚本不带参数，三张都跑）


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--detail-off":   # T360 截图对照：DETAIL_V1 关
			XUiSkin.DETAIL_V1 = false
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--only="):
			only = arg.substr(7)
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
	if only == "b" or only == "u":
		_done = ["victory", "gameover"]
		if only == "b":
			await _card_b()
		else:
			_done.append("card_b")
			await _card_u()
		_finish()
		return
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
	if only != "a":
		await _card_b()
		await _card_u()
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
	_check("all_parts_reached_end", _done == ["victory", "gameover"] + ([] if only == "a" else ["card_b"]) + ([] if only in ["a", "b"] else ["card_u"]), _done)
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XEnemy.force_roll = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## ======== 卡 B（T267，照 T254 1.3～1.6、原卡 D）：印盘、连击、伤害统计、掉落图标、首领名小怪名 ========

var bb: XBattleScene
var blg: XBattleLogic


## 开一场真战斗当底（新皮肤／旧皮肤），伤害统计、掉落动画两个设置打开；troop 4 是小怪战
func _open_b(new_skin: bool, troop := 4, members := [8, 9, 10], prep := Callable(), map := {}) -> bool:
	if bb != null and is_instance_valid(bb):
		bb.bgm.stop()
		bb.queue_free()
		await _frames(2)
	XUiSkin.FORCE = new_skin
	XConfig.set_flag("CombatDamageRecordKey", true)
	XConfig.set_flag("MOG_TrPopUpBattle_Key", true)
	seed(20261120)
	var s := XState.new_game(3, 1, members)
	XState.current = s
	for a in s.members():
		a.refresh_passive()
		a.param_mark_dirty()
		a.recover_all()
	s.random_master = XRandomStream.hex64(20261120)
	if prep.is_valid():
		prep.call(s)
	bb = XBattleScene.new()
	bb.setup(troop, true, false, map)
	add_child(bb)
	var ok := await _until(func(): return bb.cmd_win != null and bb.cmd_win.active)
	blg = bb.logic
	return ok


## 战争线：火花 n／上限（spark_full 读模块），印盘本线设成 line
func _war(n: int, line := "war") -> void:
	blg.set_meta("xwar_alien", {"units": {blg.enemies[0]: {"tier": "omen"}}, "sparks": n})
	if bb.seal_dial != null:
		bb.seal_dial.line = line
	bb.tianqi_meter.refresh()


func _combo(n: int) -> void:
	var c := bb.combo
	c.hits = n
	c._fresh = true
	c.step()


const B_SWITCHES := ["METER", "COMBO", "RECORD", "DROPS", "EDGE_FLASH", "NAMES"]
var _b_suffix := ""


func _b_switches(on: bool) -> void:
	XSkin2C.METER = on
	XSkin2C.COMBO = on
	XSkin2C.RECORD = on
	XSkin2C.DROPS = on
	XSkin2C.EDGE_FLASH = on
	XSkin2C.NAMES = on


## 新旧对照一张：新画法拍一张，卡 B 六个开关全关拍一张（旧画法），拼成「左旧右新」存 JPG
func _ab(name: String, settle := 2) -> void:
	if not _shooting():
		return
	await _frames(settle)
	await _shot("新_" + name + _b_suffix)
	_b_switches(false)
	await _frames(2)
	await _shot("旧_" + name + _b_suffix)
	_b_switches(true)
	var a: Image = _shots["旧_" + name + _b_suffix]
	var c: Image = _shots["新_" + name + _b_suffix]
	var out := Image.create(a.get_width() + c.get_width() + 8, 450, false, a.get_format())
	out.fill(Color.BLACK)
	out.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i(0, 0))
	out.blit_rect(c, Rect2i(Vector2i.ZERO, c.get_size()), Vector2i(a.get_width() + 8, 0))
	_check("pair_B_" + name + _b_suffix, out.save_jpg(out_dir.path_join("B对照_" + name + _b_suffix + ".jpg"), 0.85) == OK)
	for k in ["新_" + name + _b_suffix, "旧_" + name + _b_suffix]:
		DirAccess.remove_absolute(out_dir.path_join(k + ".png"))
		_shots.erase(k)


## 原尺寸局部放大（掉落七档、印盘细节）：从视口裁一块、放大 zoom 倍存 PNG
func _crop(name: String, r: Rect2, zoom := 2) -> void:
	if not _shooting():
		return
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var k := img.get_width() / get_viewport().get_visible_rect().size.x
	var ri := Rect2i(Vector2i(r.position * k), Vector2i(r.size * k))
	var sub := img.get_region(ri)
	sub.resize(int(r.size.x * zoom), int(r.size.y * zoom), Image.INTERPOLATE_NEAREST)
	_check("crop_" + name, sub.save_png(out_dir.path_join("B局部_" + name + _b_suffix + ".png")) == OK)


func _famine(cost_idx: int, lean_idx: int) -> void:
	blg.set_meta("xfamine_alien", {"units": {blg.enemies[0]: {"kind": "exhaust", "idx": cost_idx}, blg.enemies[-1]: {"kind": "lean", "idx": lean_idx}}})
	bb.tianqi_meter.refresh()


func _plague(layers: int, idx := 1, burst := false) -> void:
	blg.set_meta("xplague_alien", {"units": {blg.enemies[0]: {"idx": idx}}, "layers": layers, "burst": burst})
	bb.tianqi_meter.refresh()


func _death(doomed: Array) -> void:
	var d := {}
	for a in doomed:
		d[a] = 2
	blg.set_meta("xdeath_alien", {"units": {blg.enemies[0]: {}}, "doom": d})
	bb.tianqi_meter.refresh()


func _clear_lines() -> void:
	for k in ["xwar_alien", "xfamine_alien", "xplague_alien", "xdeath_alien"]:
		if blg.has_meta(k):
			blg.remove_meta(k)
	bb.tianqi_meter.refresh()


func _dial() -> XSkinSealDial:
	return bb.seal_dial


## 关掉所有战斗窗口（截图里只看浮层）／把指令环重新放出来
func _no_windows() -> void:
	for w in [bb.cmd_win, bb.list_win]:
		if w != null and is_instance_valid(w):
			w.visible = false
	if bb.cmd_reason_tag != null:
		bb.cmd_reason_tag.visible = false


func _windows_back() -> void:
	if bb.cmd_win != null and is_instance_valid(bb.cmd_win):
		bb.cmd_win.visible = true


func _card_b() -> void:
	_b_switches(true)
	_check("b_switches_default", XSkin2C.METER and XSkin2C.COMBO and XSkin2C.RECORD and XSkin2C.DROPS and XSkin2C.EDGE_FLASH and XSkin2C.NAMES)
	XUiSkin.FORCE = true
	_check("b_switch_off", (func():
		XSkin2C.METER = false
		var r := not XSkin2C.meter_on() and XSkin2C.combo_on()
		XSkin2C.METER = true
		return r).call())
	XUiSkin.FORCE = false
	_check("b_xiyou_old", not XSkin2C.meter_on() and not XSkin2C.record_on() and not XSkin2C.drops_on() and not XSkin2C.names_on())
	await _b_rules()
	await _b_record_layouts()
	_b_record_values_same()
	_b_drop_rng_same()
	if _shooting():
		for sz in [[Vector2i(1280, 720), ""], [Vector2i(1600, 720), "_20x9"]]:
			_b_suffix = str(sz[1])
			get_window().size = sz[0]
			await _frames(4)
			await _b_shots()
		_b_suffix = ""
		get_window().size = Vector2i(1280, 720)
		await _frames(4)
	if bb != null and is_instance_valid(bb):
		bb.bgm.stop()
		bb.queue_free()
		bb = null
	await _frames(2)
	XUiSkin.motion_override = -1
	_done.append("card_b")


## ---- 印盘、连击规则 ----

func _b_rules() -> void:
	var ok := await _open_b(true)
	_check("b_battle_shown", ok)
	if not ok:
		return
	var d := _dial()
	_check("b_dial_built", d != null and d.get_parent() == bb.ui)
	if d == null:
		return
	_check("b_dial_pos", absf(d.position.x - (bb.auto_btn.get_parent().position.x - 4.0)) < 0.5 and absf(d.position.y - (bb._origin.y + 142.0)) < 0.5, d.position)
	# 火花：菱形颗数＝上限、亮的颗数＝当前值
	_war(7)
	await _frames(2)
	var full := XTianqiWarAlien.spark_full(blg)
	_check("b_war_diamonds", d.last.get("diamonds") == full and d.last.get("lit") == 7, d.last)
	_check("b_war_tag", str(d.last.tags[0].text) == "火花7 / %d" % full, d.last.get("tags"))
	_check("b_war_center_wax", d.last.get("center") == "wax")
	# 满了归零：签上「全体再动」、四边一闪
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	_war(0)
	await _frames(2)
	_check("b_war_full_tag", str(d.last.tags[0].text).ends_with("全体再动") and d.last.get("edge", false), d.last)
	await _until(func(): return bb.tianqi_meter.flash_left("war") <= 0.0, 90)
	await _frames(2)
	_check("b_war_flash_ends", not str(d.last.tags[0].text).ends_with("全体再动"), d.last.get("tags"))
	# 上限超过 14：弧形条
	var war_data: Dictionary = XTianqiWarAlien.data().sparks
	var keep_full = war_data.full
	war_data.full = 16
	_war(4)
	await _frames(2)
	_check("b_arc_bar_over14", d.last.get("diamonds") == -1 and is_equal_approx(float(d.last.get("arc_bar", -1.0)), 0.25), d.last)
	war_data.full = keep_full
	# 病灶：常态 12、终焉 8；爆发时签上「爆发」
	_clear_lines()
	_plague(5, 1)
	await _frames(2)
	_check("b_plague_12", d.last.get("ring_key") == "plague" and d.last.get("diamonds") == 12 and d.last.get("lit") == 5, d.last)
	_plague(5, 3)
	await _frames(2)
	_check("b_plague_finale_8", d.last.get("diamonds") == 8 and str(d.last.tags[0].text) == "病灶5 / 8", d.last)
	_plague(6, 3, true)
	await _frames(2)
	_check("b_plague_burst_tag", str(d.last.tags[0].text) == "病灶爆发" and not d.last.get("edge", false), d.last.get("tags"))
	# 饥荒：环上没有菱形，只有七颗小圆
	_clear_lines()
	_famine(1, 1)
	await _frames(2)
	_check("b_famine_no_diamonds", d.last.get("ring_key") == "famine" and d.last.get("diamonds") == 0 and d.last.get("circles") == 7, d.last)
	_check("b_famine_tag", str(d.last.tags[0].text).begins_with("饥饿消耗 ×") and str(d.last.tags[0].text).contains("回复 ×"), d.last.get("tags"))
	# 死亡：一人一颗，被挂的亮；被挂的人换去助力位时 +1
	_clear_lines()
	_death([])
	await _frames(2)
	_check("b_death_none", d.last.get("diamonds") == blg.actors.size() and d.last.get("lit") == 0 and str(d.last.tags[0].text) == "死期暂无", d.last)
	_death([blg.actors[0], blg.actors[1]])
	await _frames(2)
	_check("b_death_two", d.last.get("diamonds") == blg.actors.size() and d.last.get("lit") == 2, d.last)
	_death([blg.actors[0], blg.actors[1], blg.actors[2]])
	await _frames(2)
	_check("b_death_many_text", str(d.last.tags[0].text).contains("等 3 人"), d.last.get("tags"))
	var helper := XState.current.actor(5)
	if helper != null:
		helper.recover_all()
		_death([blg.actors[0], helper])
		await _frames(2)
		_check("b_death_helper_plus1", d.last.get("diamonds") == blg.actors.size() + 1 and d.last.get("lit") == 2, d.last)
	# 多条线：环上是本线、签的顺序照旧、四枚签不超出环高
	_war(3, "plague")
	_plague(4, 1)
	_famine(1, 1)
	_death([blg.actors[0]])
	await _frames(2)
	var keys: Array = d.last.get("tags", []).map(func(t): return str(t.key))
	_check("b_multi_ring_is_line", d.last.get("ring_key") == "plague" and keys == ["plague", "war", "death", "famine"], keys)
	var tg: Array = d.last.get("tags", [])
	_check("b_multi_tags_in_ring", tg.size() == 4 and float(tg[0].y) >= 0.0 and float(tg[-1].y) + XSkinSealDial.TAG_H <= XSkinSealDial.RING + 0.5, tg)
	d.line = "war"
	# 连击：数字在环心、没有计量时出素环、断了淡出
	_clear_lines()
	await _frames(2)
	_check("b_no_line_no_ring", not d.last.has("center"), d.last)
	_combo(12)
	await _frames(2)
	_check("b_combo_plain_ring", d.last.get("center") == "combo" and d.last.get("combo") == 12 and d.last.get("ring_key") == "" and d.last.get("circles") == 7 and d.last.get("tier") == 2, d.last)
	_combo(123)
	await _frames(2)
	_check("b_combo_three_digits_40", d.last.get("combo_fs") == 40 and d.last.get("tier") == 4, d.last)
	bb.combo._broken = true
	bb.combo.step()
	await _until(func(): return bb.combo.num_alpha() <= 0.0, 400)   # 连击按物理帧淡，机器忙时物理帧少
	await _frames(2)
	_check("b_combo_fades", not d.last.has("center"), d.last)
	_check("b_combo_tiers", [0, 1, 9, 10, 29, 30, 49, 50, 999].map(func(h): return XComboCounter.tier(h)) == [0, 1, 1, 2, 2, 3, 3, 4, 4])
	# METER 关、COMBO 开：只有素环；METER 开、COMBO 关：连击回旧画法接在环下
	_war(5)
	XSkin2C.METER = false
	_combo(5)
	await _frames(2)
	_check("b_meter_off_plain", d.last.get("ring_key") == "" and d.last.get("center") == "combo", d.last)
	XSkin2C.METER = true
	XSkin2C.COMBO = false
	await _frames(2)
	_check("b_combo_off_old_under", d.last.get("center") == "wax" and bb.combo.under_dial, d.last)
	XSkin2C.COMBO = true
	XUiSkin.motion_override = -1


## ---- 伤害统计：各人数、各站位、首领／小怪，上沿 ≥ 616、不压我方身体 ----

func _bodies() -> Array:
	var out := []
	for a in blg.actors:
		if bb.sprites.has(a):
			out.append(XBattleScene.body_rect(bb.sprites[a]))
	return out


func _record_clear_of_bodies(tag: String) -> void:
	var r := bb.record
	if r == null:
		_check("b_rec_exists_" + tag, false)
		return
	await _frames(3)
	var bodies := _bodies()
	for lvl in [0, 1]:
		r.collapsed = lvl == 1
		r.avoid = 0
		await _frames(2)
		var rect: Rect2 = r.current_rect()
		var hit := bodies.filter(func(bd): return bd.intersects(rect))
		_check("b_rec_top616_%s_%d" % [tag, lvl], rect.position.y >= 616.0 and hit.is_empty(), [rect, hit])
	r.collapsed = false


func _b_record_layouts() -> void:
	var keep := XConfig.party_formation()
	for f in [XPartyFormation.ROWS, XPartyFormation.DIAMOND, XPartyFormation.COLUMN]:
		XConfig.set_party_formation(f)
		for troop in [4, 430]:
			for members in [[8, 9, 10], [8], [8, 9]]:
				if not await _open_b(true, troop, members):
					_check("b_open_%d_%d" % [f, troop], false)
					continue
				_no_windows()
				await _record_clear_of_bodies("%d_%d_%d" % [f, troop, members.size() + 1])
				await _frames(1)
	XConfig.set_party_formation(keep)
	# 谁占格、排序、超过 4 人、窗口避让（四人小怪战）
	await _open_b(true)
	var r := bb.record
	if r == null:
		return
	r.values = [0.0, 0.0, 0.0, 0.0, 0.0]
	await _frames(2)
	var occ := r.occupants()
	_check("b_rec_occupants_on_field", occ.size() == blg.actors.size(), [occ, r.slots])
	_check("b_rec_ties_by_slot", occ == range(occ.size()), occ)
	r.values = [10.0, 300.0, 300.0, 50.0, 0.0]
	_check("b_rec_sorted", r.occupants() == [1, 2, 3, 0], r.occupants())
	# 助力位：没上过场、0 伤不占格；换下场的有伤害照样留格；五人有伤害只排前 4、合计是全队
	r.slots = r.slots.duplicate()
	while r.slots.size() < 5:
		r.slots.append(0)
	r.slots[4] = 5
	_check("b_rec_helper_zero_no_cell", not r.occupants().has(4), r.occupants())
	r.values = [10.0, 300.0, 300.0, 50.0, 70.0]
	_check("b_rec_five_top4", r.shown_cells() == [1, 2, 4, 3] and is_equal_approx(r.total(), 730.0), [r.shown_cells(), r.total()])
	r.values = [10.0, 300.0, 300.0, 50.0, 0.0]
	r.slots[4] = 0
	# 窗口避让：相交 → 一行；一行仍相交 → 隐藏；窗口全关 0.15 秒后恢复
	_windows_back()
	var fake := Control.new()
	var wins := []
	r.windows_source = func(): return wins
	wins.append(Rect2(r.band_rect().position + Vector2(r.band_rect().size.x - 40, 4), Vector2(30, 20)))
	await _frames(3)
	_check("b_rec_avoid_line", r.level() == 1, [r.level(), r.band_rect(), r.line_rect()])
	wins.clear()
	wins.append(r.line_rect().grow(-2))
	await _frames(3)
	_check("b_rec_avoid_hide", r.level() == 2, r.level())
	await _until(func(): return not r.visible, 30)
	_check("b_rec_hidden_fades", not r.visible)
	wins.clear()
	await _frames(2)
	_check("b_rec_restore_waits", r.level() == 2)
	await _until(func(): return r.level() == 0, 30)
	_check("b_rec_restored", r.level() == 0 and r.avoid == 0)
	r.windows_source = bb.record_window_rects
	fake.free()
	# 真实指令环：6 项环在后下位，不该压着展开带以外的东西；有就让
	await _frames(3)
	var real := bb.record_window_rects()
	_check("b_rec_real_windows", real.size() > 0, real.size())
	# 点一下暗带：收成一行、记在本机，再点展开
	r.windows_source = func(): return []
	await _until(func(): return r.level() == 0, 30)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	r._gui_input(ev)
	_check("b_rec_tap_collapse", r.collapsed and XDamageRecord._load_collapsed() and r.level() == 1)
	r._gui_input(ev)
	_check("b_rec_tap_expand", not r.collapsed and not XDamageRecord._load_collapsed())
	r.windows_source = bb.record_window_rects


## values 和旧画法逐次一致：同一串 record() 喂新旧两块，values 每次都一样
func _b_record_values_same() -> void:
	if blg == null:
		return
	var a := XDamageRecord.new()
	var c := XDamageRecord.new()
	XUiSkin.FORCE = false
	a.setup(XState.current.battle_slots, 4)
	XUiSkin.FORCE = true
	c.setup(XState.current.battle_slots, 4)
	var same := a.skin == false and c.skin == true
	var e: XEnemy = blg.enemies[0]
	for i in 40:
		var u: XActor = blg.actors[i % blg.actors.size()]
		var dmg := float((i * 7919) % 5000) - 300.0
		a.record(u, e, dmg)
		c.record(u, e, dmg)
		same = same and a.values == c.values
	_check("b_rec_values_same", same, [a.values, c.values])
	a.free()
	c.free()


## 掉落：新画法下弹跳轨迹与旧画法逐帧一致（随机数同种子）
func _b_drop_rng_same() -> void:
	if blg == null or bb == null:
		return
	var items := _mixed_drops(6).map(func(d): return XDB.rec(["", "Items", "Weapons", "Armors"][int(d.kind)], int(d.id)))
	var tracks := []
	for on in [false, true]:
		XSkin2C.DROPS = on
		var p := XDropPopup.new()
		p._visual_rng.seed = 4242
		var host := Node2D.new()
		bb.field.add_child(host)
		p.setup(host, 120.0, items)
		bb.field.add_child(p)
		var tr := []
		for f in 120:
			p.step()
			tr.append(p.icons.map(func(g): return [g.x, g.y, g.alpha]))
		tracks.append(tr)
		p.queue_free()
		host.queue_free()
	XSkin2C.DROPS = true
	_check("b_drop_track_same", tracks[0] == tracks[1] and not tracks[0].is_empty())


## ---- 验收截图 ----

func _drop_at(e: XEnemy, grades: Array) -> XDropPopup:
	var items := []
	for g in grades:
		items.append(_item_of_grade(g))
	var p := XDropPopup.new()
	p.setup(bb.sprites[e], bb.sprites[e].height(), items)
	bb.field.add_child(p)
	return p


func _item_of_grade(g: int) -> Dictionary:
	for d in _mixed_drops(80):
		var rec := XSkin2C.drop_rec(d)
		if XSkin2C.drop_grade(d) == g:
			return rec
	return XDB.rec("Items", 1)


func _b_shots() -> void:
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	await _open_b(true, 4, [8, 9, 10])
	var d := _dial()
	var r := bb.record
	# 1. 整屏：火花、连击、伤害统计、掉落（岩浆暗底）
	_war(8)
	_combo(37)
	r.values = [123500.0, 45700.0, 9876.0, 3210.0, 0.0]
	_no_windows()
	_drop_at(blg.enemies[-1], [4, 3, 0])
	await _frames(70)
	await _ab("1_整屏_暗底")
	# 2. 印盘：火花四个时刻
	_combo(0)
	bb.combo._broken = true
	bb.combo.step()
	for st in [[3, "平时"], [6, "过半"], [8, "最后三颗"]]:
		_war(int(st[0]))
		await _frames(30)
		await _ab("2_火花_" + str(st[1]))
		await _crop("火花_" + str(st[1]), Rect2(d.position, Vector2(330, 128)))
	_war(10)
	await _frames(2)
	_war(0)
	await _frames(6)
	await _ab("2_火花_满的那一下", 0)
	await _frames(40)
	_war(5)
	for st in [[3, "1档"], [12, "2档"], [30, "3档"], [58, "4档"]]:
		_combo(int(st[0]))
		await _frames(14)
		await _crop("连击_" + str(st[1]), Rect2(d.position, Vector2(330, 128)))
	_combo(9)
	await _frames(12)
	_combo(10)
	await _frames(3)
	await _crop("连击_升档那一下", Rect2(d.position, Vector2(330, 128)))
	await _ab("2_连击_升档", 0)
	bb.combo._broken = true
	bb.combo.step()
	await _frames(40)
	# 3. 四条线
	_clear_lines()
	_plague(5, 1)
	await _ab("3_瘟疫")
	_clear_lines()
	_death([])
	await _ab("3_死亡_没人被挂")
	_death([blg.actors[0], blg.actors[1]])
	await _ab("3_死亡_两人被挂")
	_death([blg.actors[0], blg.actors[1], blg.actors[2]])
	await _ab("3_死亡_超过两人")
	_clear_lines()
	_famine(1, 1)
	await _ab("3_饥荒")
	_clear_lines()
	_war(6)
	_plague(9, 1)
	await _ab("3_两条线")
	_death([blg.actors[0]])
	_famine(1, 1)
	await _ab("3_四条线")
	await _crop("四条线", Rect2(d.position, Vector2(420, 128)))
	_clear_lines()
	_combo(7)
	await _ab("3_素环_只有连击")
	bb.combo._broken = true
	bb.combo.step()
	await _frames(40)
	var war_data: Dictionary = XTianqiWarAlien.data().sparks
	var keep_full = war_data.full
	war_data.full = 16
	_war(11)
	await _ab("3_上限16弧形条")
	await _crop("上限16弧形条", Rect2(d.position, Vector2(330, 128)))
	war_data.full = keep_full
	_war(8)
	# 4. 伤害统计
	for n in [1, 2, 3]:
		await _open_b(true, 4, [[], [8], [8, 9]][n - 1])
		_war(8)
		_no_windows()
		bb.record.values = [123500.0, 45700.0, 9876.0, 0.0, 0.0]
		await _ab("4_伤害统计_%d人" % n, 4)
	await _open_b(true, 4, [8, 9, 10])
	r = bb.record
	d = _dial()
	_war(8)
	_no_windows()
	r.values = [123500.0, 45700.0, 9876.0, 3210.0, 0.0]
	await _ab("4_伤害统计_4人", 4)
	r.slots = r.slots.duplicate()
	while r.slots.size() < 5:
		r.slots.append(0)
	r.slots[4] = 5
	r.values = [123500.0, 45700.0, 9876.0, 3210.0, 88000.0]
	await _ab("4_伤害统计_换过人5人排前4", 4)
	r.slots[4] = 0
	r.values = [123500.0, 45700.0, 9876.0, 3210.0, 0.0]
	r.collapsed = true
	await _ab("4_伤害统计_一行", 4)
	r.collapsed = false
	await _frames(4)
	r.values = [123500.0, 145700.0, 9876.0, 3210.0, 0.0]
	await _frames(5)
	await _ab("4_伤害统计_超过第一名那一下", 0)
	_windows_back()
	await _frames(20)
	await _ab("4_伤害统计_指令环开着", 4)
	# 后下位（4 人两排第 4 位）出 6 项环 → 让成一行；7 项环（带「换人」）→ 整条淡出；8 行战技列表 → 淡出
	var back: XActor = blg.actors[3]
	for n in [6, 7]:
		await _ring_for(back, n)
		await _frames(20)
		_check("b_rec_ring%d_level" % n, r.level() == (1 if n == 6 else 2), [n, r.level(), bb.record_window_rects()])
		await _ab("4_伤害统计_后下位%d项环" % n, 2)
	_list_for(back, 8)
	await _frames(20)
	_check("b_rec_list8_hidden", r.level() == 2, r.level())
	await _ab("4_伤害统计_后下位8行战技列表", 2)
	bb._close_windows()
	await _frames(30)
	# 菱形站位、首领战、大体型站后下位
	var keep := XConfig.party_formation()
	XConfig.set_party_formation(XPartyFormation.DIAMOND)
	await _open_b(true, 4, [8, 9, 10])
	_no_windows()
	bb.record.values = [123500.0, 45700.0, 9876.0, 3210.0, 0.0]
	await _ab("4_伤害统计_菱形站位", 4)
	XConfig.set_party_formation(keep)
	await _open_b(true, 430, [8, 9, 10])
	_war(8)
	_no_windows()
	bb.record.values = [123500.0, 45700.0, 9876.0, 3210.0, 0.0]
	await _ab("7_高首领_光头强", 20)
	await _open_b(true, 4, [8, 9, 10], func(st: XState):
		if not st.party.has(XMira.ACTOR):
			st.actor(XMira.ACTOR)
			st.party.append(XMira.ACTOR)
		st.set_switch(XItemMarks.SUPER_SWITCHES[0], true)
		st.set_battle_slot(3, XMira.ACTOR)
		st.actor(XMira.ACTOR).recover_all()
		st.actor_advance[XMira.ACTOR] = 3
		var m := st.actor(XMira.ACTOR)
		m.learn_skill(10161)
		m.state_ids.append(XMira.DRAGON))
	var mira: XActor = blg.actors[-1]
	_check("b_mira_back_low", mira.actor_id == XMira.ACTOR and blg.actors.size() == 4, blg.actors.map(func(a): return a.actor_id))
	blg._state_add(mira, XMira.DRAGON)
	await _until(func(): return str(bb.sprites[mira]._look_key).contains("MiraDragon"), 60)
	_no_windows()
	bb.record.values = [123500.0, 45700.0, 9876.0, 3210.0, 0.0]
	await _ab("4_伤害统计_大体型后下位", 10)
	_check("b_rec_clear_big_form", not XBattleScene.body_rect(bb.sprites[mira]).intersects(bb.record.current_rect()), [XBattleScene.body_rect(bb.sprites[mira]), bb.record.current_rect()])
	# 5. 掉落七档、传说落地那一下
	await _open_b(true, 4, [8, 9, 10])
	_no_windows()
	var en: XEnemy = blg.enemies[-1]
	var p := _drop_at(en, [0, 1, 2, 3, 4, 5, 6])
	for g in p.icons:   # 七个摆开：横向排、同一高度，看得清
		g.vx = 0.0
	for k in p.icons.size():
		p.icons[k].x = -150.0 + 50.0 * int(p.icons[k].node.grade)
	await _until(func(): return p.icons.all(func(g): return g.node.land_ms >= 0 and absf(float(g.dy)) < 1.5 and float(g.y) == -float(g.intY)), 150)
	var sp: Node2D = bb.sprites[en]
	await _crop("掉落七档", Rect2(bb.field.position + sp.position + Vector2(-190, -sp.height() / 3.0 - 130), Vector2(380, 180)), 2)
	await _ab("5_掉落七档", 0)
	await _frames(240)
	var leg := _drop_at(en, [4])
	await _until(func(): return leg.icons[0].node.land_ms >= 0, 120)
	await _frames(3)
	await _ab("5_传说落地那一下", 0)
	await _frames(60)
	# 6. 字体 130%；动效简化、关（满的那一下）
	_war(8)
	_combo(37)
	bb.record.values = [123500.0, 45700.0, 9876.0, 3210.0, 0.0]
	XConfig.set_font_size_percent("global", 130)
	await _frames(10)
	await _ab("6_字体130", 4)
	XConfig.set_font_size_percent("global", 100)
	bb.combo._broken = true
	bb.combo.step()
	for m in [[XUiSkin.Motion.SIMPLE, "简化"], [XUiSkin.Motion.OFF, "关"]]:
		XUiSkin.motion_override = int(m[0])
		_war(10)
		await _frames(2)
		_war(0)
		await _frames(6)
		await _ab("6_动效%s_满的那一下" % str(m[1]), 0)
		await _frames(40)
	XUiSkin.motion_override = -1


## 给某人开一个 n 项的指令环（按他的真实指令，不够补「换人」等），摆法照战斗场景
func _ring_for(a: XActor, n: int) -> void:
	bb._close_windows()
	await _frames(1)
	var opts: Array = bb._command_entries(a)
	var extra := ["换人", "三系技能"]
	while opts.size() < n:
		var o: Dictionary = opts[0].duplicate()
		o.text = extra[(opts.size()) % extra.size()]
		o.key = "x%d" % opts.size()
		opts.append(o)
	opts = opts.slice(0, n)
	bb.cmd_win = XSkinBattle.command(bb.ui, opts, XBattleScene.CMD_W, a)
	bb.cmd_win.select(0)
	bb._place_near_actor(bb.cmd_win, a)


func _list_for(a: XActor, n: int) -> void:
	bb._close_windows()
	var rows := []
	for i in n:
		rows.append({"text": "战技 %d" % (i + 1), "icon": 64 + i, "enabled": true, "costs": [{"text": "10MP"}]})
	bb.list_win = XSkinBattle.list(bb.ui, rows, XBattleScene.LIST_W, false, a, "战技")
	bb.list_win.select(0)
	bb._place_near_actor(bb.list_win, a, Vector2(16, 16))


func _finish_b() -> void:
	pass


## ======== 卡 U（T273，照 T254「卡 U」）：战斗→结算的衔接；附 T267 核查遗留（P2-1 雪地整屏、P3-1～4） ========
## 跑真的 BattleScene._victory()（troop 430 首领战、troop 4 小怪战），从最后一击起逐帧看：衔接层建没建、快照在 _end_record 之前、
## 0.5 秒 ui 隐藏后衔接层仍在原位、进场时飞、跳过无残留、挂机释放；开关关／旧皮肤时 record 当帧置空、总时长三种一样。

const U_SNOW := {"specifyBattleback": true, "battleback1Name": "IceCave", "battleback2Name": "Snowfield"}   # 地面冰原（battlebacks1 没有 Snowfield）、远景雪原
const U_BOSS := 430
const U_MINOR := 2      # 三只普通怪，没有首领血条
var _u_pool := []


func _card_u() -> void:
	_b_switches(true)
	XSkin2C.HANDOFF = true
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	XUiSkin.FORCE = true
	_check("u_switch_default", XSkin2C.HANDOFF and XSkin2C.handoff_on())
	XUiSkin.FORCE = false
	_check("u_xiyou_off", not XSkin2C.handoff_on())
	await _u_leftovers()
	await _u_rules()
	if _shooting():
		for sz in [[Vector2i(1280, 720), ""], [Vector2i(1600, 720), "_20x9"]]:
			_b_suffix = str(sz[1])
			get_window().size = sz[0]
			await _frames(4)
			await _u_shots()
		_b_suffix = ""
		get_window().size = Vector2i(1280, 720)
		await _frames(4)
	_u_close()
	await _frames(2)
	XSkin2C.HANDOFF = true
	XUiSkin.motion_override = -1
	_done.append("card_u")


func _u_close() -> void:
	Engine.time_scale = 1.0
	if bb != null and is_instance_valid(bb):
		bb.bgm.stop()
		bb.queue_free()
		bb = null


## 第一个敌人掉这几档各一件（其余敌人不掉），场上同时放出这几件的掉落图标；返回掉落
func _u_seed(grades: Array) -> Array:
	if _u_pool.is_empty():
		_u_pool = _mixed_drops(80)
	var ds := []
	for g in grades:
		for d in _u_pool:
			if XSkin2C.drop_grade(d) == g:
				ds.append(d)
				break
	for e in blg.enemies:
		blg._treasure[blg.stable_id(e)] = ds.duplicate(true) if e == blg.enemies[0] else []
	if not ds.is_empty():
		var p := _drop_at(blg.enemies[0], grades)
		# 掉落图标落地后约 1 秒就淡出，等 1.0 秒等待期满多半已释放（照稿：已释放的不飞）。这里让图标一直留着，好核、好拍「飞进大圆章」
		for g in p.icons:
			g.wait = 100000
	return ds


## 平时的一场：战争线火花 7／10、23 连击、伤害统计四人、场上两件史诗以上（池里最高的两档）＋一件普通
func _u_prep_full() -> void:
	_war(7)
	_combo(23)
	bb.record.values = [123500.0, 45700.0, 9876.0, 3210.0, 0.0]
	if _u_pool.is_empty():
		_u_pool = _mixed_drops(80)
	var hi := []
	for g in [6, 5, 4, 3]:
		if hi.size() < 2 and _u_pool.any(func(d): return XSkin2C.drop_grade(d) == g):
			hi.append(g)
	_u_seed(hi + [0])


## T291：同平时一场，但场上的掉落图标已经淡出（alpha 0、纵向放大、节点还在）——真实战斗等待期满时的样子
func _u_prep_faded() -> void:
	_u_prep_full()
	for p in bb.field.get_children():
		if p is XDropPopup:
			for g in p.icons:
				g.alpha = 0
				g.sy = 2.5


## 没有印盘：没线、没连击（伤害统计照常）
func _u_prep_bare() -> void:
	_clear_lines()
	bb.record.values = [123500.0, 45700.0, 9876.0, 3210.0, 0.0]
	_u_seed([5, 0])


## 跑一次 _victory()。opts：new（新皮肤，默认 true）、troop、prep、map、hang（挂机中）、skip_at（结算进场后几秒按确定）、
## until（看到第几秒）、shots（每 0.1 秒拍一张的名字；空＝不拍）、shot_from（从第几秒起拍）、time_scale（拍图时放慢，默认 0.25）
func _u_flow(opts := {}) -> Dictionary:
	var o := {"lit": -1, "lead": Vector2.INF, "dial_pos": Vector2.INF}
	if not await _open_b(bool(opts.get("new", true)), int(opts.get("troop", U_BOSS)), [8, 9, 10], Callable(), opts.get("map", {})):
		o.open_failed = true
		return o
	_no_windows()
	var prep: Callable = opts.get("prep", _u_prep_full)
	prep.call()
	await _frames(int(opts.get("settle", 70)))
	var d := _dial()
	if d != null and d.last.has("lit"):
		o.lit = int(d.last.lit)
		o.dial_pos = d.global_position
	var r := bb.record
	if r != null and r.last.has("lead_dot"):
		o.lead = r.get_global_transform_with_canvas() * Vector2(r.last.lead_dot)
	if bool(opts.get("hang", false)):
		XState.current.hang_up_active = true
		XState.current.hang_up_origin = Vector2i(1, 1)
	var shots := str(opts.get("shots", ""))
	var ts := float(opts.get("time_scale", 0.25 if shots != "" else 1.0))
	var from := float(opts.get("shot_from", 0.0))
	var skip_at := float(opts.get("skip_at", -1.0))
	var end_t := float(opts.get("until", 2.25))
	Engine.time_scale = ts
	if bool(opts.get("auto", false)):
		bb.logic.auto = true   # 自动战斗：XVictoryScreen.automatic
	var t0 := Time.get_ticks_usec()
	bb._victory()
	o.record_null = bb.record == null
	var ho = bb.get_node_or_null("Skin2CHandoff")
	o.ho = ho != null
	if ho != null:
		o.ho_lit = int(ho.info.get("lit", -1))
		o.ho_lead = ho.lead_pos
		o.dial_moved = d != null and d.get_parent() == ho
		o.record_in_ho = ho.record != null and ho.record == r
		o.camera_excl = not bb._camera.get("base", {}).has(ho) and bb._camera.get("base", {}).has(bb.field)
	var screen: XVictoryScreen = null
	var k := 0
	var hide_checked := false
	var ho_peak := 0
	while true:
		var now := (Time.get_ticks_usec() - t0) / 1e6 * ts
		if now >= end_t:
			break
		if screen == null:
			for c in bb.ui.get_children():
				if c is XVictoryScreen:
					screen = c
			if screen != null:
				o.t_screen = now
				o.automatic = screen.automatic
				o.boss = screen.boss
				o.drop_grades = screen._drops.map(func(x): return XSkin2C.drop_grade(x))
				o.fliers = ho.fliers.size() if ho != null and is_instance_valid(ho) else -1
				o.flier_targets = screen._skin.big_targets().size() if screen._skin != null else -1
		if ho != null and is_instance_valid(ho):
			if not hide_checked and now > 0.62 and screen == null:
				hide_checked = true
				o.ui_all_hidden = not bb.tianqi_meter.visible and not bb.message.visible   # 0.5 秒 ui 那批照旧隐藏了（计量条、消息窗）
				o.ho_visible = ho.is_visible_in_tree() and d != null and d.is_visible_in_tree()
				o.dial_pos_after = d.global_position if d != null else Vector2.INF
				o.tags_faded = d != null and d.tag_alpha == 0.0
				o.record_gone = ho.record == null
			ho_peak = maxi(ho_peak, int(ho.last.get("fliers", 0)))
		elif bool(o.ho) and not o.has("t_ho_gone"):
			o.t_ho_gone = now
		if now > 0.62 and not o.has("field_ui_hidden"):   # T291 发现②：0.5 秒隐藏那一批之后，敌人名字／血条／首领胶囊也没了
			o.field_ui_hidden = bb.gauges.values().all(func(g): return not g.box.visible) and not bb.boss_panel.visible
		if screen != null and not o.has("t_close") and screen._ready_to_close:
			o.t_close = now
		if skip_at >= 0.0 and screen != null and not o.has("t_skip") and now - float(o.t_screen) >= skip_at:
			screen._confirm()
			o.t_skip = now
		if shots != "" and now >= from + k * 0.1:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var w := 1000 if img.get_width() > 1300 else 800
			img.resize(w, 450, Image.INTERPOLATE_LANCZOS)
			if k == 0:
				_check("u_shot_size_" + shots + _b_suffix, img.get_size() == Vector2i(w, 450) and (w == 1000) == (_b_suffix == "_20x9"), img.get_size())
			var nm := "U_%s%s_%02d_%.1fs" % [shots, _b_suffix, k, from + k * 0.1]
			_check("shot_" + nm, img.save_jpg(out_dir.path_join(nm + ".jpg"), 0.78) == OK)
			k += 1
			continue
		await get_tree().process_frame
	Engine.time_scale = 1.0
	if screen != null and is_instance_valid(screen):
		o.field_ui_at_screen = bb.gauges.values().all(func(g): return not g.box.visible) and not bb.boss_panel.visible
	o.ho_alive_end = ho != null and is_instance_valid(ho)
	o.flier_peak = ho_peak
	o.screen = screen
	if screen != null and is_instance_valid(screen) and not o.has("t_skip"):
		if not screen._ready_to_close:
			await _until(func(): return screen._ready_to_close, 240)
		screen._confirm()   # 关页，_victory 走完
	await _frames(2)
	if bool(opts.get("hang", false)) and XState.current != null:
		XState.current.hang_up_active = false
	return o


func _u_rules() -> void:
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	# 旧皮肤：一行不变（record 当帧置空、没有衔接层）
	var old := await _u_flow({"new": false, "until": 2.15})
	_check("u_old_record_null_same_frame", old.get("record_null", false) and not old.get("ho", true), old)
	# 新皮肤、开关关：照原版移除
	XSkin2C.HANDOFF = false
	var off := await _u_flow({"until": 2.15})
	XSkin2C.HANDOFF = true
	_check("u_off_no_layer", off.get("record_null", false) and not off.get("ho", true), off)
	# 新皮肤、开关开：首领战
	var on := await _u_flow({"until": 2.15})
	_check("u_on_layer_built", on.get("ho", false) and on.get("dial_moved", false) and on.get("camera_excl", false), on)
	_check("u_record_null_same_frame", on.get("record_null", false) and on.get("record_in_ho", false), on)
	_check("u_snapshot_before_end_record", int(on.get("ho_lit", -2)) == int(on.lit) and int(on.lit) == 7 and (on.get("ho_lead", Vector2.INF) as Vector2).distance_to(on.lead) < 0.5, [on.get("ho_lit"), on.lit, on.get("ho_lead"), on.lead])
	_check("u_after_ui_hide_still_there", on.get("ui_all_hidden", false) and on.get("ho_visible", false) and (on.get("dial_pos_after", Vector2.INF) as Vector2).distance_to(on.dial_pos) < 0.5, on)
	_check("u_wait_tags_record_faded", on.get("tags_faded", false) and on.get("record_gone", false), on)
	_check("u_boss_flag", on.get("boss", false), on.get("boss"))
	_check("u_fliers_for_big_medals", int(on.get("fliers", -1)) == 2 and int(on.get("flier_targets", -1)) == 2 and int(on.get("flier_peak", 0)) >= 2, [on.get("fliers"), on.get("flier_targets"), on.get("flier_peak")])
	_check("u_layer_freed_after_intro", not on.get("ho_alive_end", true) and float(on.get("t_ho_gone", 9.0)) <= float(on.get("t_screen", 0.0)) + 0.95, [on.get("t_ho_gone"), on.get("t_screen")])
	# 总时长不变：从最后一击到建结算页、到可以关，三种一样（容差两帧）
	for k in ["t_screen", "t_close"]:
		var vals := [float(old.get(k, -1.0)), float(off.get(k, -1.0)), float(on.get(k, -1.0))]
		_check("u_same_total_" + k, vals.min() > 0.0 and vals.max() - vals.min() < 0.05, vals)
	_check("u_wait_is_original", absf(float(on.get("t_screen", 0.0)) - 1.0) < 0.05, on.get("t_screen"))
	# T291 发现②：结算页出来时敌人名字／血条／首领状态胶囊不再压在上面（新旧皮肤都要；开关关回旧样子）
	_check("u_field_ui_cleared_new", on.get("field_ui_hidden", false) and on.get("field_ui_at_screen", false), [on.get("field_ui_hidden"), on.get("field_ui_at_screen")])
	_check("u_field_ui_cleared_old", old.get("field_ui_hidden", false) and old.get("field_ui_at_screen", false), [old.get("field_ui_hidden"), old.get("field_ui_at_screen")])
	XSkin2C.RESULT_CLEAR = false
	var keep := await _u_flow({"until": 1.5})
	XSkin2C.RESULT_CLEAR = true
	_check("u_field_ui_switch_off_keeps", not keep.get("field_ui_hidden", true), [keep.get("field_ui_hidden"), keep.get("field_ui_at_screen")])
	# T291 发现①：掉落图标已淡出（等待期满的真实样子）也飞；快照开关关＝回到建结算页才扫，淡出的飞不了
	var faded := await _u_flow({"prep": _u_prep_faded, "until": 1.5})
	_check("u_faded_drops_still_fly", int(faded.get("fliers", -1)) == 2 and int(faded.get("flier_targets", -1)) == 2, [faded.get("fliers"), faded.get("flier_targets")])
	XSkin2C.HANDOFF_DROP_SNAP = false
	var faded_off := await _u_flow({"prep": _u_prep_faded, "until": 1.5})
	XSkin2C.HANDOFF_DROP_SNAP = true
	_check("u_faded_drops_snap_switch_off", int(faded_off.get("fliers", -1)) == 0, faded_off.get("fliers"))
	# 小怪战
	var minor := await _u_flow({"troop": U_MINOR, "until": 1.7})
	_check("u_minor_flag", minor.get("ho", false) and not minor.get("boss", true), minor.get("boss"))
	_check("u_minor_layer_freed", not minor.get("ho_alive_end", true) and float(minor.get("t_ho_gone", 9.0)) <= float(minor.get("t_screen", 0.0)) + 0.5, [minor.get("t_ho_gone"), minor.get("t_screen")])
	# 没有印盘：不建衔接层
	var bare := await _u_flow({"prep": _u_prep_bare, "until": 1.2})
	_check("u_no_dial_no_layer", not bare.get("ho", true) and bare.get("record_null", false), bare)
	# 跳过：飞着的东西直接消失
	var sk := await _u_flow({"skip_at": 0.6, "until": 1.75})
	_check("u_skip_no_leftover", sk.has("t_skip") and not sk.get("ho_alive_end", true) and float(sk.get("t_ho_gone", 9.0)) - float(sk.get("t_skip", 0.0)) < 0.05, [sk.get("t_skip"), sk.get("t_ho_gone")])
	# 自动战斗、简化、关：不飞，0.12 秒淡出
	for m in [XUiSkin.Motion.SIMPLE, XUiSkin.Motion.OFF]:
		XUiSkin.motion_override = m
		var sm := await _u_flow({"until": 1.4})
		_check("u_motion%d_no_fly" % m, sm.get("ho", false) and int(sm.get("flier_peak", -1)) == 0 and not sm.get("ho_alive_end", true) and float(sm.get("t_ho_gone", 9.0)) <= float(sm.get("t_screen", 0.0)) + 0.2, [sm.get("flier_peak"), sm.get("t_ho_gone"), sm.get("t_screen")])
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	# T291（T273 核查 P3-1）：自动战斗（v.automatic）走同一支「不飞、0.12 秒淡出」，动效开着也一样
	var au := await _u_flow({"auto": true, "until": 1.4})
	_check("u_auto_no_fly", au.get("automatic", false) and au.get("ho", false) and int(au.get("flier_peak", -1)) == 0 and int(au.get("fliers", -1)) == 0 and not au.get("ho_alive_end", true) and float(au.get("t_ho_gone", 9.0)) <= float(au.get("t_screen", 0.0)) + 0.2, [au.get("automatic"), au.get("flier_peak"), au.get("t_ho_gone"), au.get("t_screen")])
	# 挂机中：不弹结算页，等待期满衔接层直接释放
	var hg := await _u_flow({"hang": true, "until": 1.25})
	_check("u_hangup_released", hg.get("ho", false) and hg.get("screen") == null and not hg.get("ho_alive_end", true) and float(hg.get("t_ho_gone", 9.0)) <= 1.1, [hg.get("t_ho_gone"), hg.get("screen")])
	_u_close()


## ---- T267 核查遗留 P3-1～4 ----
func _u_leftovers() -> void:
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	# P3-3：火花上限 >14 弧形条，满的那一下（计量已归零）整圈全亮
	await _open_b(true, U_MINOR)
	_no_windows()
	var d := _dial()
	blg.set_meta("xwar_alien", {"units": {blg.enemies[0]: {"tier": "omen"}}, "sparks": 0})
	bb.tianqi_meter.refresh()
	await _frames(3)
	d.freeze()   # 冻结住再改 rows（不让 0.1 秒刷新盖回去）；上限改 16 走弧形条，计量 0（满的那一下已归零）
	d.frozen.rows[0].full = 16
	d.frozen.rows[0].value = 0
	d.queue_redraw()
	await _frames(2)
	_check("p33_arc_bar_empty_idle", int(d.last.get("diamonds", 0)) == -1 and float(d.last.get("arc_bar", -1.0)) == 0.0, d.last)
	d.frozen.flash["war"] = 0.4   # 满的那一下（还剩 0.4 秒）
	d.queue_redraw()
	await _frames(2)
	_check("p33_arc_bar_full_when_flash", float(d.last.get("arc_bar", -1.0)) == 1.0, d.last)
	# P3-4：伤害统计收／展进 XConfig（默认展开；T267 旧文件读到迁一次再删）
	_check("p34_default_expanded", XConfig.DEFAULTS.has(XDamageRecord.CONFIG_KEY) and XConfig.DEFAULTS[XDamageRecord.CONFIG_KEY] == false)
	XDamageRecord.save_collapsed(true)
	_check("p34_saved_in_config", XConfig.flag(XDamageRecord.CONFIG_KEY) and XDamageRecord._load_collapsed())
	XDamageRecord.save_collapsed(false)
	var cf := ConfigFile.new()
	cf.set_value("record", "collapsed", true)
	cf.save(XDamageRecord._ui_path())
	_check("p34_migrate_old_file", XDamageRecord._load_collapsed() and not FileAccess.file_exists(XDamageRecord._ui_path()) and XConfig.flag(XDamageRecord.CONFIG_KEY))
	XDamageRecord.save_collapsed(false)
	# T291（T273 核查 P3-3）：设置文件路径是空串（截图模式或只设了存档目录）时 _ui_path 返回空串，不拼相对路径，读取也不炸
	var keep_po := XConfig.path_override
	XConfig.path_override = ""
	var keep_dir := XSave.dir_override
	XSave.dir_override = "user://test_xiyou_ui_skin_2c"
	_check("p33b_ui_path_empty_guard", XConfig.path() == "" and XDamageRecord._ui_path() == "", [XConfig.path(), XDamageRecord._ui_path()])
	XDamageRecord._load_collapsed()
	XSave.dir_override = keep_dir
	XConfig.path_override = keep_po
	# P3-2：小怪名的菱形让整组宽 +16，状态图标按整组宽摆
	XUiSkin.FORCE = true
	_check("p32_icon_width_new", XSkin2C.enemy_name_width(100.0) == 116.0)
	XSkin2C.NAMES = false
	_check("p32_icon_width_names_off", XSkin2C.enemy_name_width(100.0) == 100.0)
	XSkin2C.NAMES = true
	XUiSkin.FORCE = false
	_check("p32_icon_width_old_skin", XSkin2C.enemy_name_width(100.0) == 100.0)
	XUiSkin.FORCE = true
	# 名字右缘（菱形＋名字整组居中于 320）不进图标左缘（icon_center − 16）
	var nw := 100.0
	var name_right := 320.0 + (XSkin2C.ENEMY_NAME_LEAD + nw) / 2.0
	_check("p32_icon_clear_of_name", XEnemyStateIcon.icon_center(XSkin2C.enemy_name_width(nw)).x - 16.0 >= name_right, [XEnemyStateIcon.icon_center(XSkin2C.enemy_name_width(nw)).x - 16.0, name_right])
	# P3-1：首领名胶囊不碰血量数字顶缘（NAMES 开）；NAMES 关回旧画法不记胶囊
	await _open_b(true, U_BOSS)
	_no_windows()
	await _frames(30)
	var arc = bb.boss_hp
	_check("p31_boss_arc", arc is XSkinBossArc, str(arc))
	if arc is XSkinBossArc:
		arc.last_name_rect = Rect2()
		arc.queue_redraw()
		await _frames(2)
		var rr: Rect2 = arc.last_name_rect
		_check("p31_name_pill_clear_of_hp", rr.has_area() and rr.end.y <= arc.last_num_top - XSkinBossArc.NAME_NUM_GAP + 0.01, [rr, arc.last_num_top])
		XSkin2C.NAMES = false
		arc.queue_redraw()   # T291（T273 核查 P3-4）：不手动清 last_name_rect，靠 _draw 开头自己清
		await _frames(2)
		_check("p31_names_off_old", not arc.last_name_rect.has_area())
		XSkin2C.NAMES = true
	# T291（T273 核查 P3-2）：全灭印盘按稿 0.12 秒淡出（动效关直接隐藏；开关关不管）
	for m in [[XUiSkin.Motion.FULL, "full"], [XUiSkin.Motion.OFF, "off"]]:
		XUiSkin.motion_override = m[0]
		await _open_b(true, U_BOSS)
		_no_windows()
		_war(5)
		await _frames(30)
		var dl := _dial()
		bb._fade_seal_dial_on_defeat()
		if m[0] == XUiSkin.Motion.OFF:
			_check("p32b_defeat_dial_hidden_motion_off", not dl.visible, dl.visible)
		else:
			_check("p32b_defeat_dial_fading", dl.modulate.a > 0.0 or dl.visible, dl.modulate.a)
			await get_tree().create_timer(XSkin2C.HO_OUT + 0.15).timeout
			_check("p32b_defeat_dial_faded_out", dl.modulate.a == 0.0, dl.modulate.a)
		_u_close()
		await _frames(2)
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	await _open_b(true, U_BOSS)
	_no_windows()
	_war(5)
	await _frames(30)
	XSkin2C.DEFEAT_FADE = false
	var dl2 := _dial()
	bb._fade_seal_dial_on_defeat()
	await get_tree().create_timer(XSkin2C.HO_OUT + 0.15).timeout
	XSkin2C.DEFEAT_FADE = true
	_check("p32b_defeat_fade_switch_off", dl2.modulate.a > 0.9 and dl2.visible, dl2.modulate.a)
	_u_close()
	await _frames(2)


## ---- 拍图（窗口模式） ----
func _u_shots() -> void:
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	# P2-1：雪地亮底整屏（火花、连击、伤害统计、掉落同屏），左旧右新
	await _open_b(true, U_MINOR, [8, 9, 10], Callable(), U_SNOW)
	_no_windows()
	_war(8)
	_combo(37)
	bb.record.values = [123500.0, 45700.0, 9876.0, 3210.0, 0.0]
	_drop_at(blg.enemies[-1], [4, 3, 0])
	await _frames(70)
	await _ab("1_整屏_亮底_雪地")
	_u_close()
	await _frames(2)
	# 卡 U：首领战、小怪战、没有印盘，从最后一击起每 0.1 秒一张（首领 0～2.0 秒 21 张、小怪 0～1.5 秒 16 张）
	await _u_flow({"shots": "首领战", "until": 2.05, "map": U_SNOW})
	await _u_flow({"prep": _u_prep_faded, "shots": "首领战掉落已淡出", "until": 2.05, "map": U_SNOW})   # T291：真实时序（图标已淡出）下掉落照样飞进大圆章
	await _u_flow({"troop": U_MINOR, "shots": "小怪战", "until": 1.55, "map": U_SNOW})
	await _u_flow({"prep": _u_prep_bare, "shots": "没有印盘", "until": 2.05, "map": U_SNOW})
	# 跳过（进场 0.2 秒按确定，拍按前、按后）、简化、关、挂机中：各拍等待期末到进场
	await _u_flow({"skip_at": 0.2, "shots": "跳过", "shot_from": 1.1, "until": 1.45, "map": U_SNOW})
	for m in [[XUiSkin.Motion.SIMPLE, "简化"], [XUiSkin.Motion.OFF, "关"]]:
		XUiSkin.motion_override = m[0]
		await _u_flow({"shots": "动效" + str(m[1]), "shot_from": 0.9, "until": 1.55, "map": U_SNOW})
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	await _u_flow({"hang": true, "shots": "挂机中", "shot_from": 0.8, "until": 1.35, "map": U_SNOW})
	_u_close()
