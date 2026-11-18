extends Node
## 【cc·天启篇】T196 专项：新界面战斗队伍栏展开／收起（XPartyFold）＋当前行动角色头顶的立体标记（XTurnMarker）。
## 场面同 xiyou_ui_skin_hud（地图 5、敌群 2、队伍 8/9/10），XUiSkin.FORCE 强开；设置写到 user://test_xiyou_party_fold_options.json（不碰真实设置）。
## 窗口模式加 -- --out=<目录>：存小怪战、首领战静态截图，并把「展开→收起→换人→再展开」与头顶标记特写逐帧存进 <目录>/frames_*/（再用 ffmpeg 合 GIF）。

const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const OPTIONS := "user://test_xiyou_party_fold_options.json"
var results := []
var out_dir := ""


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


func _windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


func _shot(name: String) -> void:
	if not _windowed():
		return
	await _frames(20)
	RenderingServer.force_draw(false)
	_check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


## 逐帧录 n 帧（每 step 帧存一张），crop 非空时只存那一块（原尺寸）
func _record(dir_name: String, n: int, step := 2, crop := Rect2i()) -> void:
	if not _windowed():
		await _frames(n)
		return
	var dir := out_dir.path_join(dir_name)
	DirAccess.make_dir_recursive_absolute(dir)
	var idx := 0
	for i in range(n):
		await get_tree().process_frame
		if i % step != 0:
			continue
		RenderingServer.force_draw(false)
		var img := get_viewport().get_texture().get_image()
		if crop.size != Vector2i.ZERO:
			img = img.get_region(crop)
		img.save_png(dir.path_join("f%04d.png" % idx))
		idx += 1


func _battle(map: XMapScene) -> XBattleScene:
	for c in map.ui.get_children():
		if c is XBattleScene:
			return c
	return null


func _tab() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_TAB
	e.physical_keycode = KEY_TAB
	e.pressed = true
	Input.parse_input_event(e)
	var up := e.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)


func _run() -> void:
	if FileAccess.file_exists(OPTIONS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OPTIONS))
	XConfig.path_override = OPTIONS
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	XMessageBox.auto = true
	XEnemy.force_roll = 100.0
	seed(20261013)
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.random_master = "2026101300000001"
	s.map_id = 5
	s.x = 10
	s.y = 10
	s.direction = 2
	get_tree().change_scene_to_file(MAP_SCENE)
	var ok := await _until(func(): return get_tree().current_scene is XMapScene and get_tree().current_scene.player != null and not get_tree().current_scene.busy)
	_check("map5_loaded", ok)
	var map: XMapScene = get_tree().current_scene
	await _frames(10)
	XMessageBox.auto = false
	map._set_busy(true)
	var go := func(): await map.start_battle(2, true, false)
	go.call()
	ok = await _until(func(): return _battle(map) != null and _battle(map).cmd_win != null)
	_check("command_shown", ok)
	var b: XBattleScene = _battle(map)
	if b == null:
		_finish()
		return
	await _frames(60)
	var actors: Array = b.logic.actors.duplicate()
	var a: XActor = b._active
	_check("fixture_party", actors.size() >= 3 and a != null, [actors.size(), a])
	await _layout(b, actors)
	await _shot("t196_mob_expanded")
	await _marker(b, actors)
	await _fold(b, actors)
	await _boss_shot(b)
	_rollback(b)
	_finish()


## ---- 默认展开、栏头、面板 ----
func _layout(b: XBattleScene, actors: Array) -> void:
	var f := b.party_fold
	_check("fold_exists", f != null and f.get_parent() != null)
	if f == null:
		return
	_check("fold_default_expanded", f.expanded and f.k == 1.0 and XPartyFold.saved_expanded())
	_check("fold_head_rect", f.position == Vector2(XSkinSideStatus.panel_x(), XSkinSideStatus.TOP) and f.size == Vector2(XSkinSideStatus.ROW_W, XPartyFold.HEAD_H), [f.position, f.size])
	var rows: Array = actors.map(func(m): return b.status_rows[m])
	_check("rows_in_clip", rows.all(func(r): return r.get_parent() == f.inner) and f.clip.clip_contents)
	for i in rows.size():
		var r: XSkinSideStatus = rows[i]
		_check("row_home_%d" % i, r.position == XSkinSideStatus.row_pos(i) and r.visible and r.modulate.a == 1.0, [r.position, r.visible, r.modulate.a])
	var pr := b.party_rect()
	_check("party_rect_full", is_equal_approx(pr.size.y, XPartyFold.HEAD_H + rows.size() * XSkinSideStatus.ROW_H + 4.0) and is_equal_approx(pr.size.x, 290.0), pr)
	_check("back_head", f.back is XSkinSideStatus.Back and (f.back as XSkinSideStatus.Back).head == XPartyFold.HEAD_H)
	# 缓动：团队看板 cubic-bezier(.16,1,.3,1)，头尾 0／1、前段快
	_check("ease_board", XPartyFold.ease_board(0.0) == 0.0 and XPartyFold.ease_board(1.0) == 1.0 and XPartyFold.ease_board(0.5) > 0.85 and XPartyFold.ease_board(0.1) > 0.25,
		[XPartyFold.ease_board(0.1), XPartyFold.ease_board(0.5)])


## ---- 头顶标记 ----
func _marker(b: XBattleScene, actors: Array) -> void:
	var m := b.turn_marker
	_check("marker_exists", m != null and m.get_parent() == b.fx and m.z_index == XBattleScene.POPUP_Z - 1, null if m == null else [m.get_parent(), m.z_index])
	if m == null:
		return
	var a: XActor = b._active
	await _until(func(): return m.alpha >= 1.0, 120)
	_check("marker_on_active", m.shown_for == a and m.visible and m.alpha == 1.0, [m.shown_for, m.alpha])
	var s: XBattlerSprite = b.sprites[a]
	var head := s.position + Vector2(0, -s.height() - XTurnMarker.GAP)
	_check("marker_above_head", absf(m.position.x - head.x) < 0.5 and m.position.y <= head.y + 0.01 and m.position.y >= head.y - XTurnMarker.BOB - 0.01, [m.position, head])
	# 会动：浮动＋转
	var y0 := m.position.y
	var r0 := m.spin()
	await _frames(20)
	_check("marker_moves", m.position.y != y0 and m.spin() != r0, [y0, m.position.y, r0, m.spin()])
	# 特写（原尺寸，宝石周围 128×128）
	var c := b._origin + m.position + Vector2(0, -XTurnMarker.DEPTH)
	await _record("frames_marker", 120, 2, Rect2i(Vector2i(c) - Vector2i(64, 64), Vector2i(128, 128)))
	# 换人：滑到新角色头上
	var other: XActor = actors[0] if actors[0] != a else actors[1]
	b._set_active(other)
	await _frames(3)
	_check("marker_gliding", m.shown_for == other and m._glide < 1.0, m._glide)
	await _until(func(): return m._glide >= 1.0, 60)
	var so: XBattlerSprite = b.sprites[other]
	var head2 := so.position + Vector2(0, -so.height() - XTurnMarker.GAP)
	await _frames(1)
	_check("marker_on_other", absf(m.position.x - head2.x) < 0.5 and absf(m.position.y - head2.y) <= XTurnMarker.BOB + 0.01, [m.position, head2])
	# 敌人行动（_active 空）：停一会再淡出
	b._set_active(null)
	await _frames(3)
	_check("marker_hide_delay", m.alpha == 1.0)
	ok_wait(await _until(func(): return m.alpha == 0.0 and not m.visible, 120), "marker_hidden")
	b._set_active(a)
	await _until(func(): return m.alpha >= 1.0, 120)
	_check("marker_back", m.shown_for == a and m.alpha == 1.0)
	# 换人回合提示演出中让开
	XSkinTurnCue.last_ms = Time.get_ticks_msec()
	await _frames(4)
	_check("marker_yields_cue", m.alpha < 1.0, m.alpha)
	XSkinTurnCue.last_ms = -100000
	await _until(func(): return m.alpha >= 1.0, 120)


func ok_wait(ok: bool, name: String) -> void:
	_check(name, ok)


## ---- 展开／收起 ----
func _fold(b: XBattleScene, actors: Array) -> void:
	var f := b.party_fold
	if f == null:
		return
	var a: XActor = b._active
	var ai := actors.find(a)
	var rows: Array = actors.map(func(m): return b.status_rows[m])
	# 先让焦点停在第 2 个人身上（收起后要滚过去）
	var second: XActor = actors[1]
	b._set_active(second)
	await _frames(2)
	_check("focus_follows", f.focus == second and f.focus_index() == 1)
	# Tab 收起：中途在动、0.25 秒后到位
	await _record("frames_fold_0", 30, 2)
	_tab()
	await _frames(4)
	_check("collapse_animating", not f.expanded and f.k > 0.0 and f.k < 1.0, f.k)
	await _record("frames_fold_1", 40, 2)
	_check("collapsed", f.k == 0.0 and not f.busy(), f.k)
	_check("collapse_saved", not XPartyFold.saved_expanded())
	var r2: XSkinSideStatus = b.status_rows[second]
	_check("collapsed_focus_top", r2.position.y == XSkinSideStatus.row_pos(0).y and r2.visible and r2.modulate.a == 1.0, [r2.position, r2.modulate.a])
	_check("collapsed_others_hidden", rows.filter(func(r): return r != r2 and r.visible).is_empty(), rows.map(func(r): return r.visible))
	_check("collapsed_clip_one_row", is_equal_approx(f.clip.size.y, XSkinSideStatus.ROW_H + 4.0), f.clip.size)
	_check("collapsed_party_rect", is_equal_approx(b.party_rect().size.y, XPartyFold.HEAD_H + XSkinSideStatus.ROW_H + 4.0), b.party_rect())
	_check("chevron_right", f.k == 0.0)
	# 收起时换人：滑到新的一行，不跳
	var third: XActor = actors[2]
	b._set_active(third)
	await _frames(3)
	var r3: XSkinSideStatus = b.status_rows[third]
	_check("switch_sliding", f.busy() and r3.position.y > XSkinSideStatus.row_pos(0).y and r3.visible, [r3.position, f.scroll])
	await _record("frames_fold_2", 40, 2)
	_check("switch_done", r3.position.y == XSkinSideStatus.row_pos(0).y and r3.modulate.a == 1.0 and not r2.visible, [r3.position, r3.modulate.a, r2.visible])
	# 敌人行动（null）不换
	b._set_active(null)
	await _frames(2)
	_check("null_keeps_focus", f.focus == third)
	await _shot("t196_mob_collapsed")
	# 点栏头展开
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(20, 10)
	f._gui_input(click)
	await _frames(3)
	_check("expand_animating", f.expanded and f.k > 0.0 and f.k < 1.0, f.k)
	await _record("frames_fold_3", 50, 2)
	_check("expanded_again", f.k == 1.0 and XPartyFold.saved_expanded())
	for i in rows.size():
		var r: XSkinSideStatus = rows[i]
		_check("reexpand_row_%d" % i, r.position == XSkinSideStatus.row_pos(i) and r.visible and r.modulate.a == 1.0, [r.position, r.modulate.a])
	# 动效「关」：直接到位
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	f.toggle()
	_check("motion_off_instant", f.k == 0.0 and not f.busy())
	f.toggle()
	_check("motion_off_instant_back", f.k == 1.0)
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	b._set_active(a if ai >= 0 else actors[0])
	await _frames(30)


## ---- 首领战截图 ----
func _boss_shot(b: XBattleScene) -> void:
	var e: XEnemy = b.logic.enemies[0]
	e.enemy_id = 6
	e.boss_difficulty_boss = true
	await _frames(60)
	await _shot("t196_boss_expanded")
	if b.party_fold != null:
		b.party_fold.set_expanded(false, false)
		await _frames(30)
		await _shot("t196_boss_collapsed")
		b.party_fold.set_expanded(true, false)
		await _frames(30)


## ---- 回退开关、旧界面 ----
func _rollback(b: XBattleScene) -> void:
	XPartyFold.ENABLED = false
	_check("rollback_head_h", XPartyFold.head_h() == 0.0 and XSkinSideStatus.row_pos(0).y == XSkinSideStatus.TOP + 2.0)
	var dummy := Control.new()
	_check("rollback_attach_null", XPartyFold.attach(dummy, null, func(): return []) == null)
	dummy.free()
	XPartyFold.ENABLED = true
	XTurnMarker.ENABLED = false
	_check("rollback_marker_null", XTurnMarker.make(b, 6) == null and not XTurnMarker.on())
	XTurnMarker.ENABLED = true
	XUiSkin.FORCE = false
	XUiSkin.ENABLED = false
	_check("old_ui_no_fold", not XPartyFold.on() and XPartyFold.head_h() == 0.0 and not XTurnMarker.on())
	XUiSkin.ENABLED = true
	XUiSkin.FORCE = true


func _finish() -> void:
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XConfig.path_override = ""
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
