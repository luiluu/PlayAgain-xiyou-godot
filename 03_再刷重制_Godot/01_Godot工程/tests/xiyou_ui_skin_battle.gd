extends Node
## 【cc·天启篇】新界面 2A 专项：战斗指令环、战技／物品列表、目标提示（XSkinBattle、XSkinBattleRing、XSkinBattleSkillList、XSkinTargetHint）。
## 同 xiyou_battle_ui 的场面（地图 5、敌群 2、队伍 8/9/10、美娜先手），XUiSkin.FORCE 强开新皮肤；内存新游戏，不写存档。
## 窗口模式加 -- --out=<目录> 截图；再加 --wide 时整个窗口改 1600×720＋KEEP_HEIGHT（看 20:9 铺满后环和列表的位置）。

const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
var results := []
var out_dir := ""
var wide := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		if arg == "--wide":
			wide = true
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
	await _frames(20)
	RenderingServer.force_draw(false)
	var suffix := "_20x9" if wide else "_16x9"
	_check("screenshot_" + name + suffix, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + suffix + ".png")) == OK)


func _press(action: String) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		get_viewport().push_input(e)
		await _frames(2)


## 真实鼠标事件（同 xiyou_battle_ui._mouse：无头时根视口临时设成 1280×720）
func _mouse(pos: Vector2, button: MouseButton) -> void:
	var root := get_tree().root
	var old := root.size
	if old.x < 1280 or old.y < 720:
		root.size = Vector2i(1280, 720)
		await _frames(1)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = down
		e.position = pos
		e.global_position = pos
		Input.parse_input_event(e)
		await _frames(2)
	if root.size != old:
		root.size = old
		await _frames(1)


func _battle(map: XMapScene) -> XBattleScene:
	for c in map.ui.get_children():
		if c is XBattleScene:
			return c
	return null


func _global(w: Control, local: Vector2) -> Vector2:
	return (w.get_parent() as CanvasItem).get_global_transform() * local


func _run() -> void:
	if wide and DisplayServer.get_name() != "headless":
		get_window().size = Vector2i(1600, 720)
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
		await _frames(5)
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF   # 滑动、锁定环直接到位（测位置用）
	XMessageBox.auto = true
	XEnemy.force_roll = 100.0
	seed(20261013)
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.random_master = "2026101300000001"
	s.gain_item(1, 5)
	s.actor(10).change_level_mv(10)
	s.actor(10).equips[0] = XGear.create("weapon", 14)
	s.actor(10).refresh_passive()
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
	var a: XActor = b._active
	_check("fixture_actor", a == s.actor(10), null if a == null else a.actor_id)
	var cold := XDB.rec("Skills", 3644)
	a.tp = maxf(a.tp, float(b.logic.skill_cost(a, cold).tp) + 3.0)
	await _ring(b, a)
	await _skill_list(b, a, cold)
	await _reasons(b, a, cold)
	await _item_list(b, a)
	await _target(b)
	_ring_layout(b)
	await _skin_off(b, a)
	_finish()


## 指令环：类型、六项、环心在角色脚底上 32、第 1 项 258° 往下逆时针每 36°、球不相叠、名字「某某的回合」；上下键、点选
func _ring(b: XBattleScene, a: XActor) -> void:
	var r = b.cmd_win
	_check("ring_type", r is XSkinBattleRing, r.get_class() if r else null)
	if not (r is XSkinBattleRing):
		return
	var ring: XSkinBattleRing = r
	_check("ring_entries", ring.entries.map(func(e): return e.text) == ["攻击", "战技", "魔法", "防御", "物品", "逃跑"], ring.entries.map(func(e): return e.text))
	_check("ring_title", ring.title == a.display_name() + "的回合", ring.title)
	var feet: Vector2 = b._origin + b.sprites[a].position
	_check("ring_center_on_actor", ring.ring_center().distance_to(feet + XSkinBattleRing.OFFSET) < 0.5, [ring.ring_center(), feet])
	var angles := range(6).map(func(i): return ring.angle_of(i))
	_check("ring_angles", angles == [258.0, 222.0, 186.0, 150.0, 114.0, 78.0], angles)
	var apart := true
	for i in 5:
		apart = apart and ring.orb_pos(i).distance_to(ring.orb_pos(i + 1)) >= XSkinBattleRing.ORB_R * 2.0 + 3.9
	_check("ring_orbs_apart", apart and is_equal_approx(ring.orb_r, XSkinBattleRing.ORB_R), [ring.radius, ring.orb_r])
	_check("ring_inside_screen", Rect2(b._origin, XBattleScene.BOX).encloses(Rect2(ring.position, ring.size)), [ring.position, ring.size, b._origin])
	_check("ring_no_canvas", not ring.canvas.visible)
	await _shot("battle_2a_ring")
	await _press("ui_down")
	_check("ring_key_down", ring.index == 1, ring.index)
	await _press("ui_up")
	await _press("ui_up")
	_check("ring_key_wrap", ring.index == 5, ring.index)
	# 点选：点第 2 个球先选中、再点确定→战技列表
	var p := _global(ring, ring.position + ring.orb_pos(1))
	await _mouse(p, MOUSE_BUTTON_LEFT)
	_check("ring_mouse_select", is_instance_valid(ring) and ring.index == 1 and b.list_win == null, ring.index if is_instance_valid(ring) else -1)
	await _mouse(p, MOUSE_BUTTON_LEFT)
	await _frames(3)
	_check("ring_mouse_confirm_opens_list", b.list_win != null)
	_check("ring_hidden_while_list", is_instance_valid(ring) and not ring.active and not ring._drawn_active)
	_check("ring_hit_outside", ring._hit(ring.position + ring.center) == -1)


## 战技列表：类型、标题、右上 MP／TP、贴在角色左边 37、行高 44、说明栏「目标 · 用完剩 TP」、说明卡在列表左边
func _skill_list(b: XBattleScene, a: XActor, cold: Dictionary) -> void:
	var w = b.list_win
	_check("list_type", w is XSkinBattleSkillList, w.get_class() if w else null)
	if not (w is XSkinBattleSkillList):
		return
	var lw: XSkinBattleSkillList = w
	_check("list_title", lw.title == "战技", lw.title)
	_check("list_header", lw.header.begins_with("MP ") and lw.header.contains("TP %d" % floori(a.tp)), lw.header)
	var feet: Vector2 = b._origin + b.sprites[a].position
	_check("list_right_of_actor", is_equal_approx(lw.position.x + lw.size.x, feet.x - XSkinBattleSkillList.GAP_TO_ACTOR), [lw.position, lw.size, feet])
	_check("list_inside_screen", Rect2(b._origin, XBattleScene.BOX).encloses(Rect2(lw.position, lw.size)), [lw.position, lw.size])
	_check("list_row_height", lw.row_local(1).position.y - lw.row_local(0).position.y == 44.0)
	var i := lw.entries.find_custom(func(e): return str(e.text) == str(cold.name))
	_check("list_has_cold", i >= 0, lw.entries.map(func(e): return e.text))
	if i >= 0:
		lw.select(i)
		var e: Dictionary = lw.entries[i]
		var c := b.logic.skill_cost(a, cold)
		_check("list_cost_text", e.skin_costs.size() > 0 and str(e.skin_costs[0].text) == "TP %d" % int(c.tp), e.skin_costs)
		_check("list_usable_no_reason", bool(e.enabled) and str(e.reason) == "", e)
		var want := "%s · 用完剩 TP %d" % [XSkinBattle.SCOPE_TEXT[int(cold.scope)], floori(a.tp) - int(c.tp)]
		_check("list_foot_target_left", lw.foot_text() == want, [lw.foot_text(), want])
		await _frames(2)
		var hc: XHelpCard = b.help_card
		_check("list_help_card_left", hc != null and hc.visible and hc.position.x + hc.size.x <= lw.position.x + 1.0, null if hc == null else [hc.position, hc.size, lw.position])
		_check("list_row_rect", lw.row_rect() == Rect2(lw.position + lw.row_local(i).position, lw.row_local(i).size))
		_check("list_select_bar_on_row", lw.bar.visible and lw.bar.target == lw.row_local(i), [lw.bar.target, lw.row_local(i)])
	await _shot("battle_2a_skill_list")
	# 鼠标点另一行：只选中
	if lw.entries.size() > 1:
		var other := 0 if lw.index != 0 else 1
		await _mouse(_global(lw, lw.row_rect(other).get_center()), MOUSE_BUTTON_LEFT)
		_check("list_mouse_select", is_instance_valid(lw) and lw.index == other, lw.index if is_instance_valid(lw) else -1)
	await _press("ui_cancel")
	await _frames(3)
	_check("list_cancel_back_to_ring", b.list_win == null and b.cmd_win is XSkinBattleRing and b.cmd_win.active)


## 不能用的原因：冷却、预热、TP 不够；行变暗、说明栏只写原因
func _reasons(b: XBattleScene, a: XActor, cold: Dictionary) -> void:
	var id := int(cold.id)
	var L := b.logic
	_check("reason_none_when_usable", L.can_use(a, cold))
	a.cooldowns[id] = 2
	_check("reason_cooldown", not L.can_use(a, cold) and XSkinBattle.reason(L, a, cold, false) == "冷却 2 回合", XSkinBattle.reason(L, a, cold, false))
	a.cooldowns.erase(id)
	a.warmups[id] = 1
	_check("reason_warmup", XSkinBattle.reason(L, a, cold, false) == "预热 1 回合", XSkinBattle.reason(L, a, cold, false))
	a.warmups.erase(id)
	var tp := a.tp
	a.tp = 0.0
	var row := b._list_entry(a, cold, false)
	var d := XSkinBattle.decorate(L, a, cold, row, false)
	_check("reason_tp_short", not bool(d.enabled) and str(d.reason) == "TP 不够", d.reason)
	var one := XSkinBattleSkillList.create_list(b.ui, [d], "战技")
	one.active = false  # 只看说明栏，不收键
	_check("reason_foot_only_reason", one.foot_text() == "TP 不够", one.foot_text())
	one.queue_free()
	await _frames(1)
	a.tp = tp
	_check("reason_restored", L.can_use(a, cold))
	# 范围文字：攻击（scope 1）、全体（2）、自己（11）
	_check("scope_texts", XSkinBattle.target_text(a, XDB.rec("Skills", 1)) == "敌方单体" and XSkinBattle.SCOPE_TEXT[2] == "敌方全体" and XSkinBattle.SCOPE_TEXT[11] == "自己")


## 物品列表：标题「物品」、右侧「×数量」、说明栏「用完剩 ×n」
func _item_list(b: XBattleScene, a: XActor) -> void:
	var ring: XSkinBattleRing = b.cmd_win
	ring.select(4)
	await _press("ui_accept")
	await _frames(3)
	var w = b.list_win
	_check("item_list_type", w is XSkinBattleSkillList)
	if not (w is XSkinBattleSkillList):
		return
	var lw: XSkinBattleSkillList = w
	_check("item_list_title", lw.title == "物品" and lw.header == "", [lw.title, lw.header])
	var n := b.logic.state.item_count(1)
	var i := lw.entries.find_custom(func(e): return str(e.skin_costs[0].text) == "×%d" % n if not e.skin_costs.is_empty() else false)
	_check("item_row_count", i >= 0, lw.entries.map(func(e): return e.get("skin_costs")))
	if i >= 0:
		lw.select(i)
		_check("item_foot", lw.foot_text().ends_with("用完剩 ×%d" % (n - 1)), lw.foot_text())
	await _shot("battle_2a_item_list")
	await _press("ui_cancel")
	await _frames(3)
	ring = b.cmd_win
	ring.select(0)


## 目标提示：攻击→选敌，头上胶囊写名字＋「敌方单体」；左右换目标跟着换；取消收起，指令环回来
func _target(b: XBattleScene) -> void:
	await _press("ui_accept")
	await _frames(5)
	_check("target_mode", b._target_mode == "enemy")
	var hint: XSkinTargetHint = b.get_meta("skin_target_hint") if b.has_meta("skin_target_hint") else null
	_check("hint_shown", hint != null and hint.visible)
	if hint == null:
		return
	var t = b._hover
	_check("hint_name", t != null and hint.target_name == t.display_name() and hint.sub == "敌方单体" and hint.enemy, [hint.target_name, hint.sub])
	var feet: Vector2 = b._origin + b.sprites[t].position
	var pr := hint.pill_rect()
	_check("hint_above_target", pr.end.y <= feet.y - b.sprites[t].height() and absf(pr.get_center().x - feet.x) < 1.0, [pr, feet])
	await _shot("battle_2a_target")
	await _press("ui_left")
	_check("hint_follows", b._hover != t and hint.target_name == b._hover.display_name() and hint.visible)
	await _press("ui_cancel")
	await _frames(3)
	_check("hint_hidden_on_cancel", not hint.visible and b._target_mode == "")
	_check("ring_back_after_target", b.cmd_win is XSkinBattleRing and b.cmd_win.active and b.cmd_win.modulate.a == 1.0)


## 指令多时（屠苏、云裳等可到十几项）：半径加大、球不相叠、弧不超过 252°、整环收在画面里
func _ring_layout(b: XBattleScene) -> void:
	var opts := []
	for i in 16:
		opts.append({"text": "指令%d" % i, "key": "k%d" % i})
	var ring := XSkinBattleRing.create_ring(b.ui, opts, "测试")
	ring.active = false
	var apart := true
	for i in 15:
		apart = apart and ring.orb_pos(i).distance_to(ring.orb_pos(i + 1)) >= ring.orb_r * 2.0
	_check("ring16_apart", apart and ring.radius > XSkinBattleRing.RADIUS and ring.radius <= XSkinBattleRing.MAX_RADIUS and ring.orb_r >= 28.0, [ring.radius, ring.orb_r])
	_check("ring16_span", is_equal_approx(ring.angle_of(0) - ring.angle_of(15), XSkinBattleRing.MAX_SPAN_DEG))
	ring.place_for_actor(Vector2(819, 230), XBattleScene.BOX)
	_check("ring16_inside", Rect2(Vector2.ZERO, XBattleScene.BOX).encloses(Rect2(ring.position, ring.size)), [ring.position, ring.size])
	# 位置参数（两排站位要挪时改这里）
	var old := XSkinBattleRing.OFFSET
	XSkinBattleRing.OFFSET = Vector2(-40, -32)
	var r6 := XSkinBattleRing.create_ring(b.ui, opts.slice(0, 6), "")
	r6.active = false
	r6.place_for_actor(Vector2(819, 427), XBattleScene.BOX)
	_check("ring_offset_param", r6.ring_center().distance_to(Vector2(779, 395)) < 0.5, r6.ring_center())
	XSkinBattleRing.OFFSET = old
	# 长指令名：球里缩字或折两行，最小 14
	_check("ring_font_shrinks", r6.orb_font_size("七曜元素选择", 70.0) >= XUiSkin.FS_MIN and r6.orb_font_size("攻击", 70.0) == 23)
	ring.queue_free()
	r6.queue_free()


## 开关关着：指令窗、列表都回到原 XBattleList（矩形同原版），目标提示不建
func _skin_off(b: XBattleScene, a: XActor) -> void:
	XUiSkin.FORCE = false
	XUiSkin.ENABLED = false
	var opts := b._command_entries(a)
	var cw := XSkinBattle.command(b.ui, opts, XBattleScene.CMD_W, a)
	_check("off_command_plain", not (cw is XSkinBattleRing) and cw.size == Vector2(220, opts.size() * XBattleList.LH + XBattleList.PAD * 2), [cw.get_class(), cw.size])
	var lw := XSkinBattle.list(b.ui, [{"text": "x", "enabled": true, "costs": []}], XBattleScene.LIST_W, false, a, "战技")
	_check("off_list_plain", not (lw is XSkinBattleSkillList) and lw.size.x == XBattleScene.LIST_W)
	_check("off_row_rect_same", lw.row_rect() == Rect2(lw.position + Vector2(0, lw.padding), Vector2(lw.size.x, XBattleList.LH)))
	var hint: XSkinTargetHint = b.get_meta("skin_target_hint") if b.has_meta("skin_target_hint") else null
	if hint != null:
		hint.visible = false
	XSkinBattle.target_hint(b, b.logic.enemies[0], XDB.rec("Skills", 1), [])
	_check("off_no_hint", hint == null or not hint.visible)
	cw.queue_free()
	lw.queue_free()
	XUiSkin.ENABLED = true


func _finish() -> void:
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
