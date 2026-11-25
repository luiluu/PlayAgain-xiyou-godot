extends Node
## 【小A·未经审查】T460 专项测试＋实机截图：
## 1. 配置文件读取：默认从 honghuang_first_clear.json 读出「阿夜」，支持空串／空白留空分支；
## 2. 西游大厅洪荒碑：Map004 EV82 立于 (18, 14) 空处、同层挡路、视觉节点就绪、不与原版／庆典／异化冲突，
##    调查输出「首位洪荒证道者：阿夜」；配置留空时不显示名字也不出空冒号；
## 3. 进西游档一次性播报：真写盘老存档读入＋arm_entry() 后在正式地图空闲时自动弹一次，写入 s.flags 已弹标记；
##    同局切图、存档再读不再重复弹；另一份未弹过的西游存档仍独立弹一次；开局三图 (1/2/221) 不打断开局，到厅后弹；
##    配置留空时不弹也不写已弹标记；
## 4. 天启篇不受影响：天启大厅无洪荒碑（无论清不清缓存）、可穿过 (18, 14)、无视觉节点；带 arm_entry() 进图不弹播报且不写 flags；
## 5. 回退开关 XHonghuangMonument.ENABLED = false：清缓存／不清缓存均无碑、可通行、不弹播报、不写标记。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const TIMEOUT_FRAMES := 1200

var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	if OS.get_cmdline_user_args().has("--capture-only"):
		_capture.call_deferred()
	else:
		_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", detail)
	return ok


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func shot(filename: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(filename))


func _suppress_noise(map: XMapScene) -> void:
	var ach := get_node_or_null("XAchievementPopups")
	if ach != null:
		ach.visible = false
	var toast_layer := get_tree().root.get_node_or_null("XToast")
	if toast_layer != null:
		toast_layer.visible = false
	if is_instance_valid(map.difficulty_notice):
		map.difficulty_notice.visible = false


func _make_save(tianqi := false, map_id := 4, x := 18, y := 15) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.set_variable(206, -3000)
	s.set_self_switch(4, 20, "A", true)  # 跳过首次到达自动存档事件
	if tianqi:
		s.flags["tianqi"] = {"rules": 1}
	s.map_id = map_id
	s.x = x
	s.y = y
	s.direction = 8
	return s


func _open_map(s: XState, reload := true) -> XMapScene:
	XState.current = s
	if reload:
		XHonghuangMonument.reload_map()
	var map := XMapScene.new()
	add_child(map)
	for i in TIMEOUT_FRAMES:
		await frames(1)
		if map.player != null and not map.busy and map.map_id == s.map_id:
			break
	await frames(3)
	return map


func _close(map: XMapScene) -> void:
	if is_instance_valid(map):
		map.queue_free()
	await frames(2)


func _ev(map: XMapScene, id: int) -> MVEvent:
	for e in map.events:
		if is_instance_valid(e) and e.event_id == id:
			return e
	return null


func _inspect(map: XMapScene) -> Array:
	var cell := XHonghuangMonument.CELL
	map.player.locate(cell.x, cell.y + 1)
	map.player.direction = 8
	XMessageBox.transcript.clear()
	XMessageBox.auto_answers = []
	await map._on_action()
	await frames(2)
	return XMessageBox.transcript.duplicate()


func _join(t: Array) -> String:
	return "\n".join(PackedStringArray(t.map(func(v): return str(v))))


## 实机截图模式（带窗口运行，加 --audio-driver Dummy）
func _capture() -> void:
	TestEnv.isolate("xiyou_honghuang_monument_capture")
	XGuide.MILESTONE_ENABLED = false
	XFest.ENABLED = false
	XLobbyCorruption.STAGE_OVERRIDE = 1  # 常态明亮西游大厅，便于 Kyo 清晰过目碑体与位置
	(XConfig._values.codexWhisperSeen as Array).append("rift1")
	(XConfig._values.codexWhisperSeen as Array).append("rift2")
	(XConfig._values.codexWhisperSeen as Array).append("rift3")
	XHonghuangMonument.ENABLED = true
	XHonghuangMonument.NAME_OVERRIDE = null
	XHonghuangMonument.reload_config()
	XHonghuangMonument.disarm_entry()

	# 1. 西游大厅洪荒碑全景（常态大厅，玩家站碑旁偏左，清晰展示碑体与红毯东侧空处）
	XMessageBox.auto = true
	var s_xy := _make_save(false, 4, 16, 15)
	s_xy.direction = 6
	var map := await _open_map(s_xy, true)
	await frames(10)
	_suppress_noise(map)
	await frames(2)
	await shot("t460_xiyou_hall_monument.png")

	# 2. 调查洪荒碑弹窗（关闭 auto，定格消息框拍一张，拍完模拟确认键正常关闭避免挂协程）
	XMessageBox.auto = false
	map.player.locate(XHonghuangMonument.CELL.x, XHonghuangMonument.CELL.y + 1)
	map.player.direction = 8
	map._on_action()
	for i in 60:
		await frames(1)
		if map.message.is_busy():
			break
	await frames(18)
	_suppress_noise(map)
	await frames(2)
	await shot("t460_xiyou_monument_inspect.png")
	await _dismiss_message(map)
	await _close(map)

	# 3. 进西游档一次性播报弹窗（玩家常规落点 (14, 16)，定格播报消息框且可见洪荒碑）
	var s_bc := _make_save(false, 4, 14, 16)
	s_bc.direction = 2
	XState.current = s_bc
	XHonghuangMonument.reload_map()
	XHonghuangMonument.arm_entry()
	var map_bc := XMapScene.new()
	add_child(map_bc)
	for i in 120:
		await frames(1)
		if map_bc.message != null and map_bc.message.is_busy():
			break
	await frames(18)
	_suppress_noise(map_bc)
	await frames(2)
	await shot("t460_xiyou_entry_broadcast.png")
	await _dismiss_message(map_bc)
	await _close(map_bc)

	# 4. 天启大厅同机位对照（确认无洪荒碑）
	XMessageBox.auto = true
	XHonghuangMonument.disarm_entry()
	var s_tq := _make_save(true, 4, 16, 15)
	s_tq.direction = 6
	var map_tq := await _open_map(s_tq, true)
	await frames(10)
	_suppress_noise(map_tq)
	await frames(2)
	await shot("t460_tianqi_hall_no_monument.png")
	await _close(map_tq)

	get_tree().quit(0)


func _dismiss_message(map: XMapScene) -> void:
	for i in 20:
		if map.message == null or not map.message.is_busy():
			break
		Input.action_press("ui_accept")
		await frames(2)
		Input.action_release("ui_accept")
		await frames(4)


func _run() -> void:
	TestEnv.isolate("xiyou_honghuang_monument")
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	XFest.ENABLED = false
	XLobbyCorruption.STAGE_OVERRIDE = 0
	(XConfig._values.codexWhisperSeen as Array).append("rift1")
	(XConfig._values.codexWhisperSeen as Array).append("rift2")
	(XConfig._values.codexWhisperSeen as Array).append("rift3")

	# ==== 1. 配置读取与留空分支 ====
	XHonghuangMonument.ENABLED = true
	XHonghuangMonument.NAME_OVERRIDE = null
	XHonghuangMonument.reload_config()
	check("cfg.default_name", XHonghuangMonument.winner_name() == "阿夜", XHonghuangMonument.winner_name())
	check("cfg.monument_lines_with_name", "\n".join(XHonghuangMonument.monument_lines()).contains("首位洪荒证道者：阿夜"), XHonghuangMonument.monument_lines())
	check("cfg.broadcast_lines_with_name", "\n".join(XHonghuangMonument.broadcast_lines()).contains("阿夜"), XHonghuangMonument.broadcast_lines())

	XHonghuangMonument.NAME_OVERRIDE = "   "
	check("cfg.blank_is_empty", XHonghuangMonument.winner_name() == "", XHonghuangMonument.winner_name())
	var blank_mon := "\n".join(XHonghuangMonument.monument_lines())
	check("cfg.blank_monument_no_name", not blank_mon.contains("阿夜") and not blank_mon.contains("首位洪荒证道者："), blank_mon)
	check("cfg.blank_broadcast_empty", XHonghuangMonument.broadcast_lines().is_empty(), XHonghuangMonument.broadcast_lines())

	XHonghuangMonument.NAME_OVERRIDE = null
	XHonghuangMonument.reload_config()

	# ==== 2. 西游大厅洪荒碑：位置、碰撞、视觉层、调查文案 ====
	XHonghuangMonument.disarm_entry()
	var s_xy := _make_save(false, 4, 18, 15)
	var map := await _open_map(s_xy, true)
	var ev := _ev(map, XHonghuangMonument.EVENT_ID)
	check("monument.ev_present", ev != null)
	check("monument.ev_pos", ev != null and ev.grid == XHonghuangMonument.CELL, ev.grid if ev else null)
	check("monument.ev_active_and_blocking", ev != null and not ev.page.is_empty() and ev.is_normal_priority() and not ev.through)
	check("monument.cell_blocked", map.is_blocked(XHonghuangMonument.CELL, map.player))
	check("monument.view_present", map.monument_fx != null and is_instance_valid(map.monument_fx))
	# 位置核对：不落原版 Map004 事件，在二阶异化圈外，且四邻均可通行
	var raw_map: Dictionary = XDB.load_json("maps/Map004.json")
	var raw_conflict := false
	for re in raw_map.get("events", []):
		if re is Dictionary and Vector2i(int(re.x), int(re.y)) == XHonghuangMonument.CELL:
			raw_conflict = true
	check("monument.no_raw_event_conflict", not raw_conflict)
	check("monument.outside_rift_radius", Vector2(XHonghuangMonument.CELL).distance_to(Vector2(XLobbyCorruption.CENTER)) > XLobbyCorruption.RADIUS)
	var neigh_ok := true
	for off in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var nc: Vector2i = XHonghuangMonument.CELL + off
		if map.is_blocked(nc, map.player):
			neigh_ok = false
	check("monument.neighbors_open", neigh_ok)

	var t_named := _join(await _inspect(map))
	check("monument.inspect_named", t_named.contains("首位洪荒证道者：阿夜"), t_named)

	# 名字留空时调查不显示名字
	XHonghuangMonument.NAME_OVERRIDE = ""
	var t_empty := _join(await _inspect(map))
	check("monument.inspect_blank_no_name", not t_empty.contains("阿夜") and not t_empty.contains("首位洪荒证道者：") and t_empty.contains("洪荒碑"), t_empty)
	XHonghuangMonument.NAME_OVERRIDE = null
	await _close(map)

	# ==== 3. 进西游档一次性播报（老存档真写盘读档＋同局不重复＋再读不重复＋他档独立弹）====
	# 3a. 造老西游存档（不含 honghuang_first_clear 键）写盘 → 读盘 + arm_entry() → 进图自动弹一次
	var old_s := _make_save(false, 4, 14, 22)
	old_s.flags.erase(XHonghuangMonument.FLAG_KEY)
	XState.current = old_s
	check("bc.save_legacy", XSave.save(1))
	XState.current = null
	check("bc.load_legacy", XSave.load_slot(1))
	check("bc.legacy_unseen_before", not XHonghuangMonument.broadcast_seen(XState.current))

	XMessageBox.transcript.clear()
	XHonghuangMonument.arm_entry()
	var m1 := await _open_map(XState.current, true)
	await frames(6)
	var bc_text := _join(XMessageBox.transcript)
	check("bc.fires_once_on_entry", bc_text.contains("阿夜") and bc_text.contains("洪荒"), bc_text)
	check("bc.marked_seen", XHonghuangMonument.broadcast_seen(XState.current))
	check("bc.disarmed_after", not XHonghuangMonument.is_entry_armed())

	# 3b. 同局换图再回大厅：不再重复弹
	XMessageBox.transcript.clear()
	await m1.load_map(4, 14, 22, 2)
	await frames(6)
	check("bc.no_repeat_same_session", not _join(XMessageBox.transcript).contains("洪荒首通播报"), XMessageBox.transcript)
	await _close(m1)

	# 3c. 保存已弹过的档 → 清空 XState.current → 真读档 + arm_entry() → 不再弹
	check("bc.save_after_seen", XSave.save(1))
	XState.current = null
	check("bc.reload_seen", XSave.load_slot(1))
	check("bc.seen_persisted", XHonghuangMonument.broadcast_seen(XState.current))
	XMessageBox.transcript.clear()
	XHonghuangMonument.arm_entry()
	var m2 := await _open_map(XState.current, true)
	await frames(6)
	check("bc.no_repeat_after_reload", not _join(XMessageBox.transcript).contains("洪荒首通播报"), XMessageBox.transcript)
	check("bc.disarmed_on_seen_reload", not XHonghuangMonument.is_entry_armed())
	await _close(m2)

	# 3d. 另一份未弹过的西游档（槽 2）：独立再弹一次
	var s2 := _make_save(false, 4, 14, 22)
	XState.current = s2
	check("bc.save_slot2", XSave.save(2))
	XState.current = null
	check("bc.load_slot2", XSave.load_slot(2))
	XMessageBox.transcript.clear()
	XHonghuangMonument.arm_entry()
	var m3 := await _open_map(XState.current, true)
	await frames(6)
	check("bc.slot2_fires_independently", _join(XMessageBox.transcript).contains("阿夜") and XHonghuangMonument.broadcast_seen(XState.current), XMessageBox.transcript)
	await _close(m3)

	# 3e. 西游新开局过场图（Map001 / Map002 / Map221）不消耗武装、不打断开局，到 Map004 后弹一次
	var s_open := _make_save(false, 221, 5, 5)
	XHonghuangMonument.arm_entry()
	check("bc.opening_map_defers", XHonghuangMonument.consume_broadcast(s_open, 1).is_empty() and XHonghuangMonument.is_entry_armed())
	check("bc.opening_map221_defers", XHonghuangMonument.consume_broadcast(s_open, 221).is_empty() and XHonghuangMonument.is_entry_armed())
	var after_open := XHonghuangMonument.consume_broadcast(s_open, 4)
	check("bc.hall_after_opening_fires", "\n".join(after_open).contains("阿夜") and XHonghuangMonument.broadcast_seen(s_open) and not XHonghuangMonument.is_entry_armed())

	# 3f. 配置留空时不弹播报也不写 broadcast_seen
	var s_blank := _make_save(false, 4, 14, 22)
	XHonghuangMonument.NAME_OVERRIDE = ""
	XHonghuangMonument.arm_entry()
	XMessageBox.transcript.clear()
	var m_blank := await _open_map(s_blank, true)
	await frames(6)
	check("bc.blank_name_no_broadcast", not _join(XMessageBox.transcript).contains("洪荒首通播报") and not XHonghuangMonument.broadcast_seen(s_blank))
	await _close(m_blank)
	XHonghuangMonument.NAME_OVERRIDE = null

	# ==== 4. 天启篇不受影响（清缓存＋沿用西游缓存两种情况）====
	# 先让西游档把 Map004 缓存起来，再不清缓存直接切天启档
	var s_warm := _make_save(false, 4, 14, 22)
	XState.current = s_warm
	XHonghuangMonument.reload_map()
	var _warm_data := XDB.map(4)
	var s_tq := _make_save(true, 4, 18, 15)
	XMessageBox.transcript.clear()
	XHonghuangMonument.arm_entry()
	var m_tq := await _open_map(s_tq, false)  # 故意 reload=false，测从西游切天启不串档
	await frames(6)
	var ev_tq := _ev(m_tq, XHonghuangMonument.EVENT_ID)
	check("tianqi.ev_hidden", ev_tq == null or ev_tq.page.is_empty())
	check("tianqi.cell_passable", not m_tq.is_blocked(XHonghuangMonument.CELL, m_tq.player))
	check("tianqi.no_view", m_tq.monument_fx == null)
	check("tianqi.no_broadcast", not _join(XMessageBox.transcript).contains("洪荒首通播报") and not XHonghuangMonument.is_entry_armed())
	check("tianqi.flags_clean", not s_tq.flags.has(XHonghuangMonument.FLAG_KEY))
	var t_tq_inspect := _join(await _inspect(m_tq))
	check("tianqi.inspect_nothing", not t_tq_inspect.contains("洪荒碑") and not t_tq_inspect.contains("阿夜"), t_tq_inspect)
	await _close(m_tq)

	# ==== 5. 回退开关 ENABLED = false ====
	# 5a. 不清缓存直接关开关：EV82 立即隐藏、无视觉节点、不弹播报
	XHonghuangMonument.ENABLED = false
	var s_off1 := _make_save(false, 4, 18, 15)
	XMessageBox.transcript.clear()
	XHonghuangMonument.arm_entry()
	var m_off1 := await _open_map(s_off1, false)
	await frames(6)
	var ev_off1 := _ev(m_off1, XHonghuangMonument.EVENT_ID)
	check("rollback.no_reload_ev_hidden", ev_off1 == null or ev_off1.page.is_empty())
	check("rollback.no_reload_passable", not m_off1.is_blocked(XHonghuangMonument.CELL, m_off1.player))
	check("rollback.no_reload_no_view", m_off1.monument_fx == null)
	check("rollback.no_reload_no_broadcast", not _join(XMessageBox.transcript).contains("洪荒首通播报") and not XHonghuangMonument.broadcast_seen(s_off1))
	await _close(m_off1)

	# 5b. 清缓存重读：Map004 事件表连 EV82 都不存在
	var s_off2 := _make_save(false, 4, 18, 15)
	var m_off2 := await _open_map(s_off2, true)
	check("rollback.reloaded_no_ev", _ev(m_off2, XHonghuangMonument.EVENT_ID) == null)
	check("rollback.reloaded_no_view", m_off2.monument_fx == null)
	await _close(m_off2)

	# 恢复开关
	XHonghuangMonument.ENABLED = true
	XHonghuangMonument.NAME_OVERRIDE = null
	XHonghuangMonument.disarm_entry()
	XHonghuangMonument.reload_map()

	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=", JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
