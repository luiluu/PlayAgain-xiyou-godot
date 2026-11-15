extends Node
## 【cc·天启篇】新界面 4A＋战斗可读性专项（XSkin4A）：
## - 纯函数：闪白系数（原速 1、2 倍 0.5、3 倍及以上 0）、整屏闪光每秒最多 3 次、压暗三档与设置读写、开关关掉全回 1／0。
## - 地图 HUD：挂机、回城、存档备份、地图传送换黑金胶囊，贴右上安全边距、互不重叠、不在左下摇杆区；坐标胶囊；挂机提示居中。
## - 20:9 铺满：地图视口 1600 宽、开旧页面收回 16:9、关掉再铺满；战斗 _origin 居中、背景铺满到边、压暗层盖满。
## - 触屏虚拟键：黑底旧金、按可见宽度贴右边。
## - 战斗浮字底：回合提示、敌人名字／血量数字画了胶囊底；3 倍速时受击闪白与整屏闪光不画（帧数不变）。
## - 开关关、皮肤关：HUD 回原位置原画法、视口回 1280、压暗 0、闪白系数 1。
## 内存新游戏（地图 5、敌群 2、队伍 8/9/10），XUiSkin.FORCE 强开；设置写到临时文件。
## 窗口模式：-- --out=<目录> 截图；--wide（1600×720）／--tablet（1024×768）；--before（4A 五个开关全关＝改前）；--touch（按触屏画、建虚拟键）。

const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const OPTIONS := "user://test_xiyou_ui_skin_4a_options.json"
var results := []
var out_dir := ""
var wide := false
var tablet := false
var before := false
var touch := false
var pad: XTouchControls


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg == "--wide":
			wide = true
		elif arg == "--tablet":
			tablet = true
		elif arg == "--before":
			before = true
		elif arg == "--touch":
			touch = true
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


func _windowed() -> bool:
	return DisplayServer.get_name() != "headless"


func _shot(name: String) -> void:
	if out_dir == "" or not _windowed():
		return
	await _frames(20)
	RenderingServer.force_draw(false)
	var ratio := "4x3" if tablet else ("20x9" if wide else "16x9")
	var tag := "before" if before else ("after_touch" if touch else "after")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_check("screenshot_%s_%s_%s" % [name, ratio, tag], get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s_%s.png" % [name, ratio, tag])) == OK)


func _set_all(v: bool) -> void:
	XSkin4A.HUD_V2 = v
	XSkin4A.WIDE_V2 = v
	XSkin4A.TEXT_V2 = v
	XSkin4A.DIM_V2 = v
	XSkin4A.FLASH_V2 = v


func _battle(map: XMapScene) -> XBattleScene:
	for c in map.ui.get_children():
		if c is XBattleScene:
			return c
	return null


func _run() -> void:
	XConfig.path_override = OPTIONS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OPTIONS))
	XConfig.ensure_loaded()
	if before:
		_set_all(false)
	if _windowed():
		if tablet:
			get_window().size = Vector2i(1024, 768)
		elif wide:
			get_window().size = Vector2i(1600, 720)
		await _frames(5)
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	if touch:
		XUiSkin.touch_override = 1
		XPlatform.force_mobile = true
		XTouchControls.SETTINGS_PATH = "user://test_xiyou_ui_skin_4a_touch.json"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(XTouchControls.SETTINGS_PATH))
		var platform := XPlatform.new()
		platform.quit_on_back = false
		add_child(platform)
		pad = XTouchControls.new()
		platform.add_child(pad)
	if not before:
		_pure()
	XMessageBox.auto = true
	XEnemy.force_roll = 100.0
	seed(20261115)
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.random_master = "2026111500000001"
	s.map_id = 5
	s.x = 10
	s.y = 10
	s.direction = 2
	get_tree().change_scene_to_file(MAP_SCENE)
	var ok := await _until(func(): return get_tree().current_scene is XMapScene and get_tree().current_scene.player != null and not get_tree().current_scene.busy)
	_check("map5_loaded", ok)
	if not ok:
		_finish()
		return
	var map: XMapScene = get_tree().current_scene
	await _frames(10)
	XMessageBox.auto = false
	if not before:
		_map_hud(map)
		await _map_wide(map)
		if touch:
			_touch_keys()
	await _shot("map")
	if _windowed() and not before and wide:
		var shot := await map._snapshot()
		_check("snapshot_keeps_width", shot != null and shot.get_width() == 1600, shot.get_size() if shot else null)
	await _battle_checks(map)
	if not before:
		await _skin_off(map)
	_finish()


# ---- 纯函数 ----
func _pure() -> void:
	_check("flash_gain_steps_on", [1.0, 2.0, 3.0, 4.0].map(func(m): return XSkin4A.flash_gain(m)) == [1.0, 0.5, 0.0, 0.0])
	_check("rate_mult", is_equal_approx(XSkin4A.speed_mult_for_rate(4), 1.0) and is_equal_approx(XSkin4A.speed_mult_for_rate(1), 4.0) or Engine.time_scale > 1.0)
	XSkin4A.reset_flash_clock()
	XSkin4A.clock_override_ms = 10000
	var g1 := XSkin4A.screen_flash_gain(1.0)
	XSkin4A.clock_override_ms = 10100
	var g2 := XSkin4A.screen_flash_gain(1.0)
	XSkin4A.clock_override_ms = 10340
	var g3 := XSkin4A.screen_flash_gain(1.0)
	XSkin4A.clock_override_ms = 10400
	var g4 := XSkin4A.screen_flash_gain(2.0)
	XSkin4A.clock_override_ms = 10700
	var g5 := XSkin4A.screen_flash_gain(2.0)
	_check("screen_flash_rate_cap", [g1, g2, g3, g4, g5] == [1.0, 0.0, 1.0, 0.0, 0.5], [g1, g2, g3, g4, g5])
	# 一秒里连打 10 次整屏闪光，画出来的不超过 3 次
	XSkin4A.reset_flash_clock()
	var drawn := 0
	for i in 10:
		XSkin4A.clock_override_ms = 20000 + i * 100
		if XSkin4A.screen_flash_gain(1.0) > 0.0:
			drawn += 1
	_check("screen_flash_max_3_per_sec", drawn <= 3, drawn)
	XSkin4A.clock_override_ms = -1
	XSkin4A.reset_flash_clock()
	_check("dim_default_15", XConfig.battle_dim() == 15 and XSkin4A.dim_percent() == 15, XConfig.battle_dim())
	_check("dim_steps", [XSkin4A.dim_step(15, true), XSkin4A.dim_step(30, true), XSkin4A.dim_step(15, false), XSkin4A.dim_step(0, false)] == [30, 30, 0, 0])
	_check("dim_text", [XSkin4A.dim_text(0), XSkin4A.dim_text(15), XSkin4A.dim_text(30)] == ["关", "15%", "30%"])
	XConfig.set_battle_dim(30)
	XConfig._loaded_path = ""   # 重读文件：写进设置（跟存档无关）
	_check("dim_saved", XConfig.battle_dim() == 30, XConfig.battle_dim())
	XConfig.set_battle_dim(7)
	_check("dim_bad_value_default", XConfig.battle_dim() == 15, XConfig.battle_dim())
	var lay := XSkin4A.make_dim_layer(Vector2(1600, 720))
	_check("dim_layer_alpha_15", lay != null and is_equal_approx(lay.color.a, 0.15) and Rect2(lay.position, lay.size).encloses(Rect2(Vector2.ZERO, Vector2(1600, 720))))
	if lay:
		lay.free()
	XConfig.set_battle_dim(0)
	_check("dim_off_no_layer", XSkin4A.make_dim_layer(Vector2(1280, 720)) == null)
	XConfig.set_battle_dim(15)
	# 各开关关掉
	XSkin4A.FLASH_V2 = false
	_check("flash_off_gain_1", XSkin4A.flash_gain(4.0) == 1.0 and XSkin4A.screen_flash_gain(4.0) == 1.0)
	XSkin4A.FLASH_V2 = true
	XSkin4A.reset_flash_clock()
	XSkin4A.DIM_V2 = false
	_check("dim_off_0", XSkin4A.dim_percent() == 0 and XSkin4A.make_dim_layer(Vector2(1280, 720)) == null)
	XSkin4A.DIM_V2 = true
	XSkin4A.HUD_V2 = false
	XSkin4A.WIDE_V2 = false
	XSkin4A.TEXT_V2 = false
	_check("switches_off", not XSkin4A.hud_on() and not XSkin4A.wide_on() and not XSkin4A.text_on())
	_set_all(true)
	XUiSkin.FORCE = false
	_check("skin_off_all_off", not XSkin4A.hud_on() and not XSkin4A.wide_on() and not XSkin4A.text_on() and not XSkin4A.dim_on() and XSkin4A.flash_gain(4.0) == 1.0 and XSkin4A.dim_percent() == 0)
	XUiSkin.FORCE = true


# ---- 地图 HUD ----
func _map_hud(map: XMapScene) -> void:
	var hud := map.map_hud
	hud.refresh()
	map.hang_overlay.refresh()
	_check("hud_skinned", hud._skinned and hud.return_button.texture_normal == null and hud._return_face.visible)
	var vs := map.get_viewport().get_visible_rect().size
	var safe := XSkin4A.safe_rect(hud)
	var rects := []
	for b in [hud.return_button, hud.backup_button, hud.transfer_button]:
		if (b as Control).visible:
			rects.append(Rect2(b.position, b.size))
	var inside := true
	for r in rects:
		inside = inside and safe.encloses(r) and r.size.y == XSkin4A.CAP_H and r.position.y < 120
	_check("hud_capsules_top_right_safe", inside and not rects.is_empty(), [rects, safe])
	var apart := true
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			apart = apart and not (rects[i] as Rect2).intersects(rects[j])
	_check("hud_capsules_apart", apart, rects)
	var last := Rect2(hud.transfer_button.position, hud.transfer_button.size)   # 最右是地图传送
	_check("hud_right_edge", absf(last.end.x - safe.end.x) < 1.0 if hud.transfer_button.visible else true, [last, safe])
	# 左下摇杆区（原版虚拟按钮 80,400,280,280）不放任何 HUD
	var stick := Rect2(0, vs.y - 330, 380, 330)
	var clear := true
	for r in rects:
		clear = clear and not (r as Rect2).intersects(stick)
	_check("hud_clear_of_stick", clear)
	if XConfig.map_xy():
		_check("coords_capsule_under_row", hud.coords.position.y >= safe.position.y + XSkin4A.CAP_H and absf(hud.coords.position.x + hud.coords.size.x - safe.end.x) < 1.0, [hud.coords.position, hud.coords.size])
	var ho := map.hang_overlay
	_check("hangup_skinned", ho._skinned and not ho._panel.visible and not ho._button_sprite.visible and ho.button.size.y == ho.SKIN_CAP_H)
	_check("hangup_left_safe", absf(ho.inter.position.x - safe.position.x) < 1.0, ho.inter.position)
	_check("hangup_tip_centered", absf(ho.tip.position.x + ho.tip.size.x / 2.0 - vs.x / 2.0) < 1.0, [ho.tip.position, vs])


## 20:9：无头时把根视口设成 1600×720、窗口当 1600×720（XSkinLayout.window_override）；窗口模式 --wide 就是真窗口
func _map_wide(map: XMapScene) -> void:
	var root := get_tree().root
	var old := root.size
	if not _windowed():
		XSkinLayout.window_override = Vector2(1600, 720)
		root.size = Vector2i(1600, 720)
		XSkinLayout._apply_wide(root)
		await _frames(3)
	var sim := not _windowed() or wide
	if not sim:
		_check("map_wide_16x9_no_change", map.get_viewport().get_visible_rect().size == Vector2(1280, 720))
		return
	_check("map_wide_active", map.wide_active() and map.get_viewport().get_visible_rect().size.x == 1600, map.get_viewport().get_visible_rect().size)
	map.map_hud.refresh()
	map.hang_overlay.refresh()
	_check("hud_right_follows_wide", map.map_hud.transfer_button.position.x + map.map_hud.transfer_button.size.x > 1500.0 or not map.map_hud.transfer_button.visible, map.map_hud.transfer_button.position)
	# 开一页按 1280 排的旧页面 → 收回 16:9；关掉 → 再铺满
	var page := Control.new()
	page.name = "LegacyProbe"
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	map.ui.add_child(page)
	await _frames(2)
	_check("legacy_page_narrows", not map.wide_active() and map.get_viewport().get_visible_rect().size.x == 1280, map.get_viewport().get_visible_rect().size)
	page.queue_free()
	await _frames(3)
	_check("legacy_closed_widens", map.wide_active() and map.get_viewport().get_visible_rect().size.x == 1600, map.get_viewport().get_visible_rect().size)
	XSkin4A.WIDE_V2 = false
	map._update_wide()
	await _frames(2)
	_check("wide_switch_off_16x9", not map.wide_active() and map.get_viewport().get_visible_rect().size.x == 1280)
	XSkin4A.WIDE_V2 = true
	map._update_wide()
	await _frames(2)
	_check("wide_switch_on_again", map.wide_active())
	if not _windowed():
		root.size = old
		await _frames(1)
		root.size = Vector2i(1600, 720)   # 战斗也按 20:9 验（结束时还原）
		await _frames(2)


func _touch_keys() -> void:
	if pad == null:
		return
	await _frames(2)
	_check("touch_skinned", pad._skinned)
	var sb := (pad._buttons.ok as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	_check("touch_ok_dark_gold", sb.bg_color.is_equal_approx(XTouchControls.SKIN_FILL) and sb.border_color.is_equal_approx(Color(XUiSkin.GOLD, 0.75)), [sb.bg_color, sb.border_color])
	var vw := pad.screen_size().x
	_check("touch_cancel_right_edge", (pad.rects.cancel as Rect2).end.x > vw - 140.0, [pad.rects.cancel, vw])


# ---- 战斗 ----
func _battle_checks(map: XMapScene) -> void:
	map.battleback_override = ["Sand", "Snowfield"]   # 亮背景（沙漠＋雪原）
	map._set_busy(true)
	var go := func(): await map.start_battle(2, true, false)
	go.call()
	var ok := await _until(func(): return _battle(map) != null and _battle(map).cmd_win != null)
	_check("battle_command_shown", ok)
	var b := _battle(map)
	if b == null:
		return
	var vs := b.get_viewport_rect().size
	if before:
		await _shot("battle")
		return
	_check("battle_origin_centered", is_equal_approx(b._origin.x, (vs.x - 1280.0) / 2.0), [b._origin, vs])
	var sim := not _windowed() or wide
	if sim:
		_check("battle_wide_1600", vs.x == 1600, vs)
	var cover := true
	for c in b.get_children():
		if c is TextureRect and (c as TextureRect).stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED:
			cover = cover and Rect2(c.position, c.size).encloses(Rect2(Vector2.ZERO, vs))
	_check("battle_background_fills", cover)
	var dim := b.find_child("BattleDim", false, false) as ColorRect
	_check("battle_dim_15", dim != null and is_equal_approx(dim.color.a, 0.15) and Rect2(dim.position, dim.size).encloses(Rect2(Vector2.ZERO, vs)), dim.color if dim else null)
	_check("battle_dim_below_field", dim != null and dim.get_index() < b.field.get_index())
	# 浮字底：回合提示（指令环名字）、敌人名字和血量数字
	XSkin4A.backing_count = 0
	b.cmd_win.queue_redraw()
	var e: XEnemy = b.logic.enemies[0]
	b._show_enemy_gauge(e, 2.0)
	await _frames(3)
	_check("text_backing_drawn", XSkin4A.backing_count >= 3, XSkin4A.backing_count)
	XSkin4A.TEXT_V2 = false
	XSkin4A.backing_count = 0
	b.cmd_win.queue_redraw()
	b._refresh_enemy_gauge(e)
	await _frames(3)
	_check("text_backing_off", XSkin4A.backing_count == 0, XSkin4A.backing_count)
	XSkin4A.TEXT_V2 = true
	await _shot("battle")
	# 3 倍速：受击闪白、整屏闪光不画（帧数照旧）
	var saved_speed := XConfig.battle_speed()
	XConfig.set_battle_speed(2)   # 三倍
	var sp: XBattlerSprite = b.sprites[e]
	sp.flash(Color(1, 1, 1))
	_check("x3_no_white_flash", sp.sprite.modulate.is_equal_approx(Color.WHITE), sp.sprite.modulate)
	XSkin4A.reset_flash_clock()
	b.screen_fx.start_flash([255, 255, 255, 200], 12)
	_check("x3_no_screen_flash", b.screen_fx.flash_gain == 0.0 and b.screen_fx.flash_duration == 12, [b.screen_fx.flash_gain, b.screen_fx.flash_duration])
	XConfig.set_battle_speed(4)   # 原速
	sp.flash(Color(1, 1, 1))
	_check("x1_white_flash", sp.sprite.modulate.is_equal_approx(Color(1, 1, 1) * 2.0), sp.sprite.modulate)
	XSkin4A.reset_flash_clock()
	b.screen_fx.start_flash([255, 255, 255, 200], 12)
	_check("x1_screen_flash", b.screen_fx.flash_gain == 1.0)
	XConfig.set_battle_speed(saved_speed)


# ---- 开关关、皮肤关：回旧 ----
func _skin_off(map: XMapScene) -> void:
	XUiSkin.FORCE = false
	var hud := map.map_hud
	hud.refresh()
	map.hang_overlay.refresh()
	_check("off_hud_old_rects", not hud._skinned and hud.backup_button.position == XMapHUD.BACKUP_RECT.position and hud.transfer_button.get_rect() == XMapHUD.TRANSFER_RECT
		and hud.return_button.position == XMapHUD.RETURN_RECT.position and hud.return_button.texture_normal != null, [hud.backup_button.position, hud.transfer_button.get_rect()])
	_check("off_hangup_old", not map.hang_overlay._skinned and map.hang_overlay._panel.visible and map.hang_overlay.inter.position == XHangUpOverlay.INTER_POS and map.hang_overlay.tip.position == XHangUpOverlay.TIP_POS)
	map._update_wide()
	await _frames(2)
	_check("off_view_1280", XSkin4A.view_size(map) == Vector2(1280, 720) and not map.wide_active())   # 视口还宽是因为战斗没结束、战斗自己的铺满还在
	if pad != null:
		await _frames(2)
		var sb := (pad._buttons.ok as Panel).get_theme_stylebox("panel") as StyleBoxFlat
		_check("off_touch_old", not pad._skinned and not sb.bg_color.is_equal_approx(XTouchControls.SKIN_FILL))
	XUiSkin.FORCE = true
	XSkin4A.HUD_V2 = false
	hud.refresh()
	_check("hud_switch_off_old", not hud._skinned and hud.backup_button.position == XMapHUD.BACKUP_RECT.position)
	XSkin4A.HUD_V2 = true


func _finish() -> void:
	_set_all(true)
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XUiSkin.touch_override = -1
	XSkinLayout.window_override = Vector2.ZERO
	XSkin4A.clock_override_ms = -1
	if touch:
		XPlatform.force_mobile = null
		DirAccess.remove_absolute(ProjectSettings.globalize_path(XTouchControls.SETTINGS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OPTIONS))
	XConfig.path_override = ""
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
