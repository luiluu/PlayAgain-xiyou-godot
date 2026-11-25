extends Node
## 【小A·未经审查】T460 专项测试＋实机截图：
## 1. 配置文件读取：默认从 honghuang_first_clear.json 读出「大手子」，支持空串／空白留空分支；
## 2. 西游大厅洪荒碑：Map004 EV82 立于上方红毯楼梯右侧原花盆／烛台位 (18, 9)（Kyo 11-25 拍板），
##    不挡楼梯通行 (12..16, 7..10)，清除原 (18, 8..9) 花盆／烛台图块与蓝地垫、隐藏三阶 north_table_e / north_candle_e、
##    并在三阶整图底图上以运行时干净墙面／地砖无缝覆盖原花盆（平时／庆典一致）；
##    调查输出「首位洪荒证道者：大手子」，配置留空时不显示名字也不出空冒号；
## 3. 进西游档一次性播报：真写盘老存档读入＋arm_entry() 后在正式地图空闲时自动弹一次（Kyo 定稿文字），写入 s.flags 已弹标记；
##    同局切图、存档再读不再重复弹；另一份未弹过的西游存档仍独立弹一次；开局三图 (1/2/221) 不打断开局，到厅后弹；
##    配置留空时不弹也不写已弹标记；
## 4. 天启篇不受影响：天启大厅无洪荒碑、原花盆／烛台图块完好保留、可自由通过、无视觉节点；带 arm_entry() 进图不弹播报且不写 flags；
## 5. 回退开关 XHonghuangMonument.ENABLED = false：清缓存后无碑且原花盆／烛台图块与三阶程序件完整恢复；不清缓存也立即隐藏不弹播报。
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


func _make_save(tianqi := false, map_id := 4, x := 18, y := 10) -> XState:
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


func _tile_at(map: XMapScene, x: int, y: int, z: int) -> int:
	var w := map.lower.width
	var h := map.lower.height
	return int(map.lower.data[(z * h + y) * w + x])


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


func _dismiss_message(map: XMapScene) -> void:
	for i in 20:
		if map.message == null or not map.message.is_busy():
			break
		Input.action_press("ui_accept")
		await frames(2)
		Input.action_release("ui_accept")
		await frames(4)


func _capture_lobby_shot(stage_override: int, fest_on: bool, tianqi: bool, filename: String) -> void:
	XMessageBox.auto = true
	XHonghuangMonument.disarm_entry()
	XFest.ENABLED = fest_on
	XFestLobby.ENABLED = fest_on
	XFest.TODAY_OVERRIDE = XFest.START if fest_on else "2000-01-01"
	XLobbyCorruption.STAGE_OVERRIDE = stage_override
	var s := _make_save(tianqi, 4, 16, 11)
	s.direction = 8
	var map := await _open_map(s, true)
	await frames(12)
	_suppress_noise(map)
	await frames(2)
	await shot(filename)
	await _close(map)


## 实机截图模式（带窗口运行，加 --audio-driver Dummy）
## 覆盖：三阶平时／庆典、二阶平时、一阶平时／庆典、三阶调查弹窗、三阶进游播报弹窗、天启大厅对照
func _capture() -> void:
	TestEnv.isolate("xiyou_honghuang_monument_capture")
	XGuide.MILESTONE_ENABLED = false
	XRift.STAGE2 = true
	XRift.STAGE3 = true
	(XConfig._values.codexWhisperSeen as Array).append("rift1")
	(XConfig._values.codexWhisperSeen as Array).append("rift2")
	(XConfig._values.codexWhisperSeen as Array).append("rift3")
	XHonghuangMonument.ENABLED = true
	XHonghuangMonument.NAME_OVERRIDE = null
	XHonghuangMonument.reload_config()

	# 1. 三阶腐败大厅·平时（主图）
	await _capture_lobby_shot(0, false, false, "t460_xiyou_stage3_regular.png")
	# 2. 三阶腐败大厅·庆典
	await _capture_lobby_shot(0, true, false, "t460_xiyou_stage3_fest.png")
	# 3. 二阶初步异化大厅·平时
	await _capture_lobby_shot(2, false, false, "t460_xiyou_stage2_regular.png")
	# 4. 一阶常态大厅·平时
	await _capture_lobby_shot(1, false, false, "t460_xiyou_stage1_regular.png")
	# 5. 一阶常态大厅·庆典
	await _capture_lobby_shot(1, true, false, "t460_xiyou_stage1_fest.png")
	# 6. 天启大厅同机位对照（无碑、保留原花盆）
	await _capture_lobby_shot(0, false, true, "t460_tianqi_hall_no_monument.png")

	# 7. 三阶大厅调查洪荒碑弹窗（玩家站在 (18, 10) 面朝上调查）
	XFest.ENABLED = false
	XFestLobby.ENABLED = false
	XLobbyCorruption.STAGE_OVERRIDE = 0
	XMessageBox.auto = true
	var s_ins := _make_save(false, 4, 18, 10)
	s_ins.direction = 8
	var map := await _open_map(s_ins, true)
	XMessageBox.auto = false
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

	# 8. 三阶大厅进西游档一次性播报弹窗（Kyo 定稿文字，视野包含楼梯与洪荒碑）
	var s_bc := _make_save(false, 4, 14, 12)
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

	get_tree().quit(0)


func _run() -> void:
	TestEnv.isolate("xiyou_honghuang_monument")
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	XFest.ENABLED = false
	XFestLobby.ENABLED = false
	XRift.STAGE2 = true
	XRift.STAGE3 = true
	XLobbyCorruption.STAGE_OVERRIDE = 0
	(XConfig._values.codexWhisperSeen as Array).append("rift1")
	(XConfig._values.codexWhisperSeen as Array).append("rift2")
	(XConfig._values.codexWhisperSeen as Array).append("rift3")

	# ==== 1. 配置读取与留空分支 ====
	XHonghuangMonument.ENABLED = true
	XHonghuangMonument.NAME_OVERRIDE = null
	XHonghuangMonument.reload_config()
	check("cfg.default_name", XHonghuangMonument.winner_name() == "大手子", XHonghuangMonument.winner_name())
	check("cfg.monument_lines_with_name", "\n".join(XHonghuangMonument.monument_lines()).contains("首位洪荒证道者：大手子"), XHonghuangMonument.monument_lines())
	var bc_joined := "\n".join(XHonghuangMonument.broadcast_lines())
	check("cfg.broadcast_lines_with_name", bc_joined.contains("大手子") and bc_joined.contains("这个名字已经刻在大厅的洪荒碑上，有空可以去看看。"), XHonghuangMonument.broadcast_lines())

	XHonghuangMonument.NAME_OVERRIDE = "   "
	check("cfg.blank_is_empty", XHonghuangMonument.winner_name() == "", XHonghuangMonument.winner_name())
	var blank_mon := "\n".join(XHonghuangMonument.monument_lines())
	check("cfg.blank_monument_no_name", not blank_mon.contains("大手子") and not blank_mon.contains("首位洪荒证道者："), blank_mon)
	check("cfg.blank_broadcast_empty", XHonghuangMonument.broadcast_lines().is_empty(), XHonghuangMonument.broadcast_lines())

	XHonghuangMonument.NAME_OVERRIDE = null
	XHonghuangMonument.reload_config()

	# ==== 2. 西游大厅洪荒碑：新坐标 (18,9)、去花盆、不挡楼梯、视觉层、调查文案 ====
	XHonghuangMonument.disarm_entry()
	var s_xy := _make_save(false, 4, 18, 10)
	var map := await _open_map(s_xy, true)
	var ev := _ev(map, XHonghuangMonument.EVENT_ID)
	check("monument.ev_present", ev != null)
	check("monument.ev_pos", ev != null and ev.grid == Vector2i(18, 9), ev.grid if ev else null)
	check("monument.ev_active_and_blocking", ev != null and not ev.page.is_empty() and ev.is_normal_priority() and not ev.through)
	check("monument.cell_blocked", map.is_blocked(XHonghuangMonument.CELL, map.player))
	check("monument.view_present", map.monument_fx != null and is_instance_valid(map.monument_fx))
	# 原花盆／烛台图块已清（z=3 上下半截为 0，z=0 蓝地垫换为白大理石 1542）
	check("monument.pot_tiles_cleared",
		_tile_at(map, 18, 8, 3) == 0
		and _tile_at(map, 18, 9, 3) == 0
		and _tile_at(map, 18, 9, 0) == XHonghuangMonument.FLOOR_TILE_ID,
		[_tile_at(map, 18, 8, 3), _tile_at(map, 18, 9, 3), _tile_at(map, 18, 9, 0)])
	# 原版 Map004 在 (18, 9) 无冲突事件，且在二阶异化圈外
	var raw_map: Dictionary = XDB.load_json("maps/Map004.json")
	var raw_conflict := false
	for re in raw_map.get("events", []):
		if re is Dictionary and Vector2i(int(re.x), int(re.y)) == XHonghuangMonument.CELL:
			raw_conflict = true
	check("monument.no_raw_event_conflict", not raw_conflict)
	check("monument.outside_rift_radius", Vector2(XHonghuangMonument.CELL).distance_to(Vector2(XLobbyCorruption.CENTER)) > XLobbyCorruption.RADIUS)
	# 不挡楼梯通行（楼梯本体 x=12..16 上下 y=9↔8↔7 全通，且紧邻碑侧的 x=16 从 y=10→7→10 全通；避开站在 (14,10) 的金甲 NPC EV01）
	var stairs_ok := true
	for sx in range(12, 17):
		for sy in [9, 8]:
			map.player.locate(sx, sy)
			if not map.player.can_pass(8):
				stairs_ok = false
		for sy in [7, 8]:
			map.player.locate(sx, sy)
			if not map.player.can_pass(2):
				stairs_ok = false
	for sy in [10, 9, 8]:
		map.player.locate(16, sy)
		if not map.player.can_pass(8):
			stairs_ok = false
	for sy in [7, 8, 9]:
		map.player.locate(16, sy)
		if not map.player.can_pass(2):
			stairs_ok = false
	check("monument.stairs_unblocked", stairs_ok)
	# 调查位 (18, 10) 可达
	check("monument.inspect_spot_open", not map.is_blocked(Vector2i(18, 10), map.player))

	var t_named := _join(await _inspect(map))
	check("monument.inspect_named", t_named.contains("首位洪荒证道者：大手子"), t_named)

	# 名字留空时调查不显示名字
	XHonghuangMonument.NAME_OVERRIDE = ""
	var t_empty := _join(await _inspect(map))
	check("monument.inspect_blank_no_name", not t_empty.contains("大手子") and not t_empty.contains("首位洪荒证道者：") and t_empty.contains("洪荒碑"), t_empty)
	XHonghuangMonument.NAME_OVERRIDE = null
	await _close(map)

	# 2b. 一阶／二阶／三阶 × 平时／庆典全部存在、去花盆且可调查
	for cfg in [[1, false], [1, true], [2, false], [3, false], [3, true]]:
		var stg: int = int(cfg[0])
		var fest_on: bool = bool(cfg[1])
		var tag := "stage%d_%s" % [stg, "fest" if fest_on else "reg"]
		XLobbyCorruption.STAGE_OVERRIDE = stg
		XFest.ENABLED = fest_on
		XFestLobby.ENABLED = fest_on
		XFest.TODAY_OVERRIDE = XFest.START if fest_on else "2000-01-01"
		var s_stg := _make_save(false, 4, 18, 10)
		var m_stg := await _open_map(s_stg, true)
		var ev_stg := _ev(m_stg, XHonghuangMonument.EVENT_ID)
		check("monument.%s.present" % tag, ev_stg != null and not ev_stg.page.is_empty() and m_stg.monument_fx != null and is_instance_valid(m_stg.monument_fx))
		check("monument.%s.pot_cleared" % tag, _tile_at(m_stg, 18, 8, 3) == 0 and _tile_at(m_stg, 18, 9, 3) == 0)
		if stg == 3:
			check("monument.%s.stage3_cover" % tag, m_stg.monument_fx.stage3_pot_covered() and m_stg.lobby_fx != null and m_stg.chars.z_index > m_stg.lobby_fx.z_index)
			var want_f := 6 if fest_on else 8
			var want_l := 2 if fest_on else 4
			check("monument.%s.decay_pot_hidden" % tag, m_stg.lobby_fx.decay_furniture_count() == want_f and m_stg.lobby_fx.decay_lamp_count() == want_l,
				[m_stg.lobby_fx.decay_furniture_count(), m_stg.lobby_fx.decay_lamp_count()])
		check("monument.%s.inspect" % tag, _join(await _inspect(m_stg)).contains("首位洪荒证道者：大手子"))
		await _close(m_stg)
	XLobbyCorruption.STAGE_OVERRIDE = 0
	XFest.ENABLED = false
	XFestLobby.ENABLED = false

	# ==== 3. 进西游档一次性播报（老存档真写盘读档＋同局不重复＋再读不重复＋他档独立弹）====
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
	check("bc.fires_once_on_entry", bc_text.contains("大手子") and bc_text.contains("这个名字已经刻在大厅的洪荒碑上"), bc_text)
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
	check("bc.slot2_fires_independently", _join(XMessageBox.transcript).contains("大手子") and XHonghuangMonument.broadcast_seen(XState.current), XMessageBox.transcript)
	await _close(m3)

	# 3e. 西游新开局过场图（Map001 / Map002 / Map221）不消耗武装、不打断开局，到 Map004 后弹一次
	var s_open := _make_save(false, 221, 5, 5)
	XHonghuangMonument.arm_entry()
	check("bc.opening_map_defers", XHonghuangMonument.consume_broadcast(s_open, 1).is_empty() and XHonghuangMonument.is_entry_armed())
	check("bc.opening_map221_defers", XHonghuangMonument.consume_broadcast(s_open, 221).is_empty() and XHonghuangMonument.is_entry_armed())
	var after_open := XHonghuangMonument.consume_broadcast(s_open, 4)
	check("bc.hall_after_opening_fires", "\n".join(after_open).contains("大手子") and XHonghuangMonument.broadcast_seen(s_open) and not XHonghuangMonument.is_entry_armed())

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

	# ==== 4. 天启篇不受影响（沿用西游缓存直接切天启：cache_stale 自动重读，原花盆完整保留、无碑、不弹播报）====
	var s_warm := _make_save(false, 4, 14, 22)
	XState.current = s_warm
	XHonghuangMonument.reload_map()
	var _warm_data := XDB.map(4)
	var s_tq := _make_save(true, 4, 18, 10)
	XMessageBox.transcript.clear()
	XHonghuangMonument.arm_entry()
	var m_tq := await _open_map(s_tq, false)  # 故意 reload=false，测自动作废缓存、不串档
	await frames(6)
	var ev_tq := _ev(m_tq, XHonghuangMonument.EVENT_ID)
	check("tianqi.ev_hidden", ev_tq == null or ev_tq.page.is_empty())
	check("tianqi.pot_preserved",
		_tile_at(m_tq, 18, 8, 3) == 374
		and _tile_at(m_tq, 18, 9, 3) == 381
		and _tile_at(m_tq, 18, 9, 0) == 3293,
		[_tile_at(m_tq, 18, 8, 3), _tile_at(m_tq, 18, 9, 3), _tile_at(m_tq, 18, 9, 0)])
	check("tianqi.no_view", m_tq.monument_fx == null)
	check("tianqi.no_broadcast", not _join(XMessageBox.transcript).contains("洪荒首通播报") and not XHonghuangMonument.is_entry_armed())
	check("tianqi.flags_clean", not s_tq.flags.has(XHonghuangMonument.FLAG_KEY))
	var t_tq_inspect := _join(await _inspect(m_tq))
	check("tianqi.inspect_nothing", not t_tq_inspect.contains("洪荒碑") and not t_tq_inspect.contains("大手子"), t_tq_inspect)
	await _close(m_tq)

	# ==== 5. 回退开关 ENABLED = false：无碑、原花盆与三阶程序件完整恢复、不弹播报 ====
	XHonghuangMonument.ENABLED = false
	var s_off := _make_save(false, 4, 18, 10)
	XMessageBox.transcript.clear()
	XHonghuangMonument.arm_entry()
	var m_off := await _open_map(s_off, false)  # cache_stale 自动重读恢复原花盆
	await frames(6)
	check("rollback.no_ev", _ev(m_off, XHonghuangMonument.EVENT_ID) == null)
	check("rollback.pot_restored",
		_tile_at(m_off, 18, 8, 3) == 374
		and _tile_at(m_off, 18, 9, 3) == 381
		and _tile_at(m_off, 18, 9, 0) == 3293)
	check("rollback.no_view", m_off.monument_fx == null)
	check("rollback.stage3_decay_restored", m_off.lobby_fx != null and m_off.lobby_fx.decay_furniture_count() == 9 and m_off.lobby_fx.decay_lamp_count() == 5,
		[m_off.lobby_fx.decay_furniture_count() if m_off.lobby_fx else -1, m_off.lobby_fx.decay_lamp_count() if m_off.lobby_fx else -1])
	check("rollback.no_broadcast", not _join(XMessageBox.transcript).contains("洪荒首通播报") and not XHonghuangMonument.broadcast_seen(s_off))
	await _close(m_off)

	# 恢复开关
	XHonghuangMonument.ENABLED = true
	XHonghuangMonument.NAME_OVERRIDE = null
	XHonghuangMonument.disarm_entry()
	XHonghuangMonument.reload_map()

	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=", JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
