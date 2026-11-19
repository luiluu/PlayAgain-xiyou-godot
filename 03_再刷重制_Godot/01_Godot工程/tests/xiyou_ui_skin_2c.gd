extends Node
## 【cc·天启篇】新界面 2C 专项（T250）：胜利结算、全灭画面、本线计量条、伤害统计、连击、掉落图标换新皮。
## 两轮同一场战斗（难度 3、队伍 1/8/9/10、敌群 4），内存新游戏，不写存档：
##   old：西游存档、XUiSkin.FORCE＝false —— 六处都走旧画法（没有新皮肤的层、旧提示窗照旧、滚动上限照旧 size−11）；
##   new：XUiSkin.FORCE＝true —— 走 XSkin2C（胜利页压暗层、提示画在页内、计量条挪到圆钮下、连击按 digits 画、全灭盖层透明度跟淡入）。
## 窗口模式加 -- --out=<目录> 拍改前／改后对照（800×450，另拼一张左右对照）：战斗 HUD（计量条＋连击＋伤害统计＋掉落图标）、
## 胜利结算（新版 A、B 两版）、全灭（新版 A、B 两版）。

var results := []
var out_dir := ""
var _shots := {}   # 名字 → Image（800×450）


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


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await _frames(6)
	RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	img.resize(800, 450, Image.INTERPOLATE_LANCZOS)
	_shots[name] = img
	_check("screenshot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK)


## 局部放大（掉落图标这类小东西）：原尺寸截一块再放大 2 倍
func _crop(name: String, r: Rect2) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	var ri := Rect2i(r).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var sub := img.get_region(ri)
	sub.resize(ri.size.x * 2, ri.size.y * 2, Image.INTERPOLATE_NEAREST)
	_shots[name] = sub
	_check("crop_" + name, sub.save_png(out_dir.path_join(name + ".png")) == OK)


## 左右对照：左旧右新，各 800×450，中间留 8px 黑缝
func _pair(name: String, before: String, after: String) -> void:
	if not (_shots.has(before) and _shots.has(after)):
		return
	var a: Image = _shots[before]
	var b: Image = _shots[after]
	var out := Image.create(1608, 450, false, a.get_format())
	out.fill(Color.BLACK)
	out.blit_rect(a, Rect2i(0, 0, 800, 450), Vector2i(0, 0))
	out.blit_rect(b, Rect2i(0, 0, 800, 450), Vector2i(808, 0))
	_check("pair_" + name, out.save_png(out_dir.path_join("对照_" + name + ".png")) == OK)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_ui_skin_2c"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XConfig.set_flag("CombatDamageRecordKey", true)
	XConfig.set_flag("MOG_TrPopUpBattle_Key", true)
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XEnemy.force_roll = 100.0
	_unit()
	for mode in ["old", "new"]:
		XUiSkin.FORCE = mode == "new"
		_check("on_%s" % mode, XSkin2C.on() == (mode == "new"))
		await _battle(mode)
	_pair("战斗HUD", "old_hud", "new_hud")
	_pair("胜利结算_A", "old_victory", "new_victory_A")
	_pair("胜利结算_B", "old_victory", "new_victory_B")
	_pair("全灭_A", "old_gameover", "new_gameover_A")
	_pair("全灭_B", "old_gameover", "new_gameover_B")
	_finish()


## 不起战斗的纯函数
func _unit() -> void:
	XUiSkin.FORCE = true
	_check("line_names", XSkin2C.LINE_NAMES.size() == 4 and XSkin2C.LINE_NAMES.war == "战争线")
	XSkin2C.ENABLED = false
	_check("master_switch_off", not XSkin2C.on() and not XSkin2C.victory_on() and not XSkin2C.meter_on())
	XSkin2C.ENABLED = true
	XSkin2C.METER = false
	_check("meter_switch_off", XSkin2C.on() and not XSkin2C.meter_on())
	XSkin2C.METER = true
	XUiSkin.FORCE = false


func _battle(mode: String) -> void:
	seed(20261119)
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	for a in s.members():
		a.refresh_passive()
		a.param_mark_dirty()
		a.recover_all()
	s.random_master = XRandomStream.hex64(20261119)
	var b := XBattleScene.new()
	b.setup(4, true, false, {})
	add_child(b)
	var ok := await _until(func(): return b.cmd_win != null and b.cmd_win.active)
	_check("%s_command_shown" % mode, ok)
	if not ok:
		b.queue_free()
		return
	var new := mode == "new"
	var lg: XBattleLogic = b.logic
	var boss: XBattler = lg.enemies[0]
	var a0: XActor = lg.actors[0]
	# 计量条：战争线火花 3／满、死亡线挂一个人
	lg.set_meta("xwar_alien", {"units": {boss: {"tier": "omen"}}, "sparks": 3})
	lg.set_meta("xdeath_alien", {"units": {boss: {}}, "doom": {a0: true}})
	b.tianqi_meter.refresh()
	_check("%s_meter_rows" % mode, b.tianqi_meter.rows.size() == 2, b.tianqi_meter.rows)
	if new:
		_check("new_meter_under_toggles", is_equal_approx(b.tianqi_meter.position.y - b._origin.y, XSkinBattle.ROUND_TOGGLE_Y + XSkinBattle.ROUND_TOGGLE_SIZE.y + 12.0), b.tianqi_meter.position)
	else:
		_check("old_meter_pos", b.tianqi_meter.position == b._origin + XBattleScene.TIANQI_METER_POS, b.tianqi_meter.position)
	# 连击 12 下
	b.combo.set_physics_process(false)
	for i in 12:
		b.combo.applied(a0, boss, true, 1, 1000.0)
	b.combo.step()
	_check("%s_combo_digits" % mode, b.combo.hits == 12 and b.combo.digits.size() == 2 and b.combo.timer > 0, [b.combo.hits, b.combo.digits.size()])
	# 伤害统计
	_check("%s_record_built" % mode, b.record != null)
	if b.record != null:
		var dmg := [123456.0, 45678.0, 9876.0, 3210.0]
		for i in mini(dmg.size(), lg.actors.size()):
			b.record.record(lg.actors[i], boss, dmg[i])
		_check("%s_record_total" % mode, is_equal_approx(b.record.total(), 182220.0) or lg.actors.size() < 4, b.record.total())
	# 掉落图标：在首领脚下弹 5 个，等落地
	var drops := _sample_drops(5)
	var p := XDropPopup.new()
	p.setup(b.sprites[boss], b.sprites[boss].height(), drops.map(func(d): return XDB.rec(["", "Items", "Weapons", "Armors"][int(d.kind)], int(d.id))))
	p.set_physics_process(false)
	b.field.add_child(p)
	for i in 30:
		p.step()
	b.combo.queue_redraw()
	await _shot("%s_hud" % mode)
	await _crop("%s_drops" % mode, Rect2(b._origin + b.sprites[boss].position - Vector2(160, 200), Vector2(320, 240)))
	# 胜利结算：手搭一页（升级一人、掉落 30 样，样稿那种「一下来很多」）
	for n in b.ui.get_children():
		if n is CanvasItem:
			n.hide()
	b.low_ui.hide()
	b._end_record()   # 实际流程：胜利时伤害统计先移除、连击早已淡完
	b.combo.hide()
	b.boss_panel.set_process(false)   # 首领状态面板自己会按回合重显；实际胜利时首领已倒下，这里藏起
	b.boss_panel.hide()
	for e in lg.enemies:
		if b.sprites.has(e):
			b.sprites[e].hide()
	b.fx.hide()   # 头顶角标
	for e in b.gauges:   # 敌人名字与小血条（实际胜利时敌人已倒下，名字淡掉）
		b.gauges[e].box.hide()
	p.queue_free()
	# 队员练到 12～15 级；第二人这一场从 11 级升上来（看「等级提升！」）
	var before := {}
	for i in lg.actors.size():
		var a: XActor = lg.actors[i]
		a.change_level(clampi(5 + i * 2, 2, a.max_level() - 1))
		a.exp_total = a.exp_for_level(a.level) + (a.exp_for_level(a.level + 1) - a.exp_for_level(a.level)) * (3 + i * 2) / 10
		var lv := a.level - (1 if i == 1 else 0)
		before[a] = {"level": lv, "exp": a.exp_for_level(lv) + (a.exp_for_level(lv + 1) - a.exp_for_level(lv)) / 2 if i == 1 else a.exp_total - 300}
	var vdrops := _sample_drops(30)
	var v := XVictoryScreen.new()
	v.setup({"gold": 12345, "exp": 6789, "drops": vdrops}, before, lg.actors, false)
	b.ui.add_child(v)
	await _frames(2)
	_check("%s_victory_dim" % mode, (v.get_node_or_null("Skin2CDim") != null) == new)
	_check("%s_victory_scroll_max" % mode, v._drop_scroll_max() == (XSkin2C.drop_scroll_max(v) if new else maxi(0, v._drops.size() - 11)), v._drop_scroll_max())
	v._elapsed = 3.0
	v._update_exp(1.0)
	v._ready_to_close = true
	v.hint.visible = not XSkin2C.victory_on()
	await get_tree().create_timer(0.7).timeout   # 等淡入补间走完（32 帧）
	v.modulate.a = 1.0
	for row in v.rows:   # 升级字样停在放大完、全亮那一帧
		if row.notified:
			row.lv_scale = 1.0
			row.lv_opacity = 255.0
	v.set_process(false)
	v.canvas.queue_redraw()
	_check("%s_victory_hint_window" % mode, v.hint.visible == not new)
	if new:
		_check("new_victory_levelup", v.rows.any(func(r): return r.notified))
		XSkin2C.VICTORY_STYLE = XSkin2C.Style.A
		v.canvas.queue_redraw()
		await _shot("new_victory_A")
		XSkin2C.VICTORY_STYLE = XSkin2C.Style.B
		_check("new_victory_b_scroll", XSkin2C.drop_scroll_max(v) == maxi(0, ceili(v._drops.size() / 12.0) - 2), XSkin2C.drop_scroll_max(v))
		v.canvas.queue_redraw()
		await _shot("new_victory_B")
		XSkin2C.VICTORY_STYLE = XSkin2C.Style.A
	else:
		await _shot("old_victory")
	v.queue_free()
	b.bgm.stop()
	b.queue_free()   # 全灭画面在地图上出（战斗已收场），先把战斗整个拿掉
	await _frames(3)
	# 全灭画面（地图上是加在 ui 上；这里盖在最上面）
	var g := XGameOverScreen.new()
	g.set_physics_process(false)
	add_child(g)
	for i in XGameOverScreen.FADE_FRAMES:
		g.step()
	var overlay := g.get_node_or_null("Skin2COverlay") as Control
	_check("%s_gameover_overlay" % mode, (overlay != null) == new)
	_check("%s_gameover_state_same" % mode, g.state().frame == XGameOverScreen.FADE_FRAMES and g.state().image == "NULL", g.state())
	if new and overlay != null:
		_check("new_gameover_alpha_follows", is_equal_approx(overlay.modulate.a, 1.0))
		XSkin2C.GAMEOVER_STYLE = XSkin2C.Style.A
		overlay.queue_redraw()
		await _shot("new_gameover_A")
		XSkin2C.GAMEOVER_STYLE = XSkin2C.Style.B
		overlay.queue_redraw()
		await _shot("new_gameover_B")
		XSkin2C.GAMEOVER_STYLE = XSkin2C.Style.A
	else:
		await _shot("old_gameover")
	g.queue_free()
	await _frames(3)
	_done.append(mode)


## 取 n 样有名字、有图标的掉落：物品、武器、防具轮着取（武器防具带品质色）
func _sample_drops(n: int) -> Array:
	var out := []
	var kinds := [[2, "Weapons"], [3, "Armors"], [1, "Items"]]
	var next := {1: 1, 2: 1, 3: 1}
	var guard := 0
	while out.size() < n and guard < 5000:
		guard += 1
		var k: Array = kinds[out.size() % 3]
		var id: int = next[k[0]]
		next[k[0]] = id + 1
		var rec := XDB.rec(str(k[1]), id)
		if rec.is_empty() or str(rec.get("name", "")) == "" or int(rec.get("iconIndex", 0)) <= 0:
			continue
		out.append({"kind": int(k[0]), "id": id})
		if out.size() % 4 == 0:
			out.append({"kind": int(k[0]), "id": id})   # 同一样再来一次（合并成 ×2）
	return out.slice(0, n)


var _done := []


func _finish() -> void:
	_check("both_rounds_reached_end", _done == ["old", "new"], _done)   # 中途脚本报错时协程会断，这一条兜住
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XEnemy.force_roll = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
