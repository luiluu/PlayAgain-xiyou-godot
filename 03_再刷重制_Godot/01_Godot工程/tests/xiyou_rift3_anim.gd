extends Node
## 【小A·未经审查】三阶漫画动画⑤：事件整段替换接线与双测试（T430；分镜 v0.5 第 4.2 节、第 8 节拆卡 5）。
## 覆盖：
## 1) EV205 111/411/412 结构：成立支仅 CodexRift3.play()+replayMissed()（不含 MOB_EV/XUFENG_EV 移动、SLASH_ANIM 23、静态 401）；
##    Else 支完整保留原 T412 像素过场（indent=1）；RIFT3_ANIM=false 回到与 T412 逐条一致的指令表。
## 2) MVScript.eval_expr("CodexRift3.available()") 与三层开关／缺资源守卫。
## 3) CodexRift3.replayMissed() 逐句参数（face/index/background/position/原文）严格对齐 rift.gd:306-341。
## 4) 真开 Map004 端到端：自然播满 26.0s 零弹窗直接自由移动、BGM 暂停/淡入恢复、lobby_fx 让路、不摆 XUFENG_EV、再进不重播、
##    以及 Engine.time_scale=1.6 真实秒计时准确。
## 5) 真开 Map004 端到端跳过补播：t=1.0s（5 句）、t=10.0s（4 句）、t=23.0s（2 句）逐字对齐 XRift.RIFT3_LINES 且播完清空 missed_lines。
## 6) 三层回退实机干净：缺资源走 411 Else 支回原像素过场、RIFT3_ANIM=false 回原像素过场、STAGE3=false 回二阶。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const TIMEOUT_FRAMES := 3000

var passed := 0
var total := 0


class _MockHost:
	extends RefCounted
	var msgs: Array[Dictionary] = []

	func show_message(msg: Dictionary) -> int:
		msgs.append(msg.duplicate(true))
		return 0


class _MockInterp:
	extends RefCounted
	var host

	func _init(h) -> void:
		host = h

	func is_cancelled() -> bool:
		return false


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _ev(id: int):
	var evs: Array = XDB.map(4).events
	return evs[id] if id < evs.size() else null


func _seen() -> Array:
	XConfig.ensure_loaded()
	return XConfig._values.codexWhisperSeen as Array


func _find(map: XMapScene, id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null


func _open_lobby() -> XMapScene:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 4
	s.x = 14
	s.y = 26
	var map := XMapScene.new()
	add_child(map)
	return map


func _prepare_rift3_trigger() -> void:
	_seen().erase("rift3")
	XConfig.whisper_mark("rift1")
	XConfig.whisper_mark("rift2")
	XRift.on_map_setup(132)  # 模拟上一次进图已看 rift2
	XMessageBox.transcript.clear()
	XRift3Anim.missed_lines.clear()
	XRift.clear_cache()


func _wait_for_anim(map: XMapScene, max_frames := 180) -> XRift3Anim:
	for _i in range(max_frames):
		await frames(1)
		var node := map.get_node_or_null(XRift3Anim.NODE_NAME)
		if node is XRift3Anim:
			return node as XRift3Anim
	return null


func _wait_not_busy(map: XMapScene, max_frames := 180) -> bool:
	for _i in range(max_frames):
		await frames(1)
		if not map.busy and map.get_node_or_null(XRift3Anim.NODE_NAME) == null:
			return true
	return false


func _plain_line(key: String) -> String:
	return str(XRift3Anim.parse_rift_line(key).text)


func _run() -> void:
	TestEnv.isolate("xiyou_rift3_anim", false)
	var old_fest := XFestLobby.ENABLED
	var old_guide := XGuide.MILESTONE_ENABLED
	var old_auto := XMessageBox.auto
	var old_stage2 := XRift.STAGE2
	var old_stage3 := XRift.STAGE3
	var old_anim := XRift.RIFT3_ANIM
	var old_enabled := XRift3Anim.ENABLED
	var old_ts := Engine.time_scale

	XFestLobby.ENABLED = false
	XGuide.MILESTONE_ENABLED = false
	XMessageBox.auto = true
	XRift.STAGE2 = true
	XRift.STAGE3 = true
	XRift.RIFT3_ANIM = true
	XRift3Anim.ENABLED = true
	XRift3Anim._asset_exists_override = Callable()

	_test_event_structure()
	_test_eval_expr_and_switches()
	await _test_replay_missed_params()
	await _test_lobby_natural_full_play()
	await _test_lobby_skip_replay(1.0, ["whisper", "sense", "hint", "follow", "after"], "skip_1s")
	await _test_lobby_skip_replay(10.0, ["sense", "hint", "follow", "after"], "skip_10s")
	await _test_lobby_skip_replay(23.0, ["follow", "after"], "skip_23s")
	await _test_missing_assets_fallback_to_pixel()
	await _test_switch_off_and_stage3_off()

	XRift3Anim._asset_exists_override = Callable()
	XRift3Anim.missed_lines.clear()
	XRift3Anim.ENABLED = old_enabled
	XRift.STAGE2 = old_stage2
	XRift.STAGE3 = old_stage3
	XRift.RIFT3_ANIM = old_anim
	XFestLobby.ENABLED = old_fest
	XGuide.MILESTONE_ENABLED = old_guide
	XMessageBox.auto = old_auto
	Engine.time_scale = old_ts
	XRift.clear_cache()

	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


func _test_event_structure() -> void:
	XRift.STAGE3 = true
	XRift.RIFT3_ANIM = true
	XRift.clear_cache()
	var r3 = _ev(XRift.RIFT3)
	check("ev.exists", r3 is Dictionary and int(r3.id) == XRift.RIFT3 and str(r3.note) == "<codex_rift_whisper:rift3>")
	check("ev.pages_3", r3.pages.size() == 3 and int(r3.pages[0].trigger) == 4 and int(r3.pages[1].trigger) == 3 and str(r3.pages[1].conditions.selfSwitchCh) == "B" and str(r3.pages[2].conditions.selfSwitchCh) == "A")
	var body: Array = r3.pages[1].list
	check("ev.mark_first", body.size() > 6 and int(body[0].code) == 355 and str(body[0].parameters[0]) == "CodexWhisper.mark('rift3');" and int(body[0].indent) == 0, body[0])
	check("ev.cond_111", int(body[1].code) == 111 and int(body[1].indent) == 0 and int(body[1].parameters[0]) == 12 and str(body[1].parameters[1]) == "CodexRift3.available()", body[1])

	var i_else := -1
	var i_end := -1
	for i in range(2, body.size()):
		if int(body[i].indent) == 0 and int(body[i].code) == 411 and i_else < 0:
			i_else = i
		elif int(body[i].indent) == 0 and int(body[i].code) == 412 and i_end < 0:
			i_end = i
	check("ev.has_411_412", i_else > 2 and i_end > i_else, [i_else, i_end])

	var then_slice: Array = body.slice(2, i_else)
	var scripts_then: Array = then_slice.filter(func(c): return int(c.code) == 355).map(func(c): return str(c.parameters[0]))
	check("ev.then_scripts_exact", scripts_then == ["CodexRift3.play();", "CodexRift3.replayMissed();"], scripts_then)
	check("ev.then_indent_1", then_slice.all(func(c): return int(c.indent) == 1), then_slice)
	check("ev.then_no_mob_xufeng_routes", not then_slice.any(func(c): return int(c.code) == 205 and (int(c.parameters[0]) == XRift.MOB_EV or int(c.parameters[0]) == XRift.XUFENG_EV)))
	check("ev.then_no_slash_anim", not then_slice.any(func(c): return int(c.code) == 212 and int(c.parameters[1]) == XRift.SLASH_ANIM))
	check("ev.then_no_static_401", not then_slice.any(func(c): return int(c.code) == 401 or int(c.code) == 101))

	var else_slice: Array = body.slice(i_else + 1, i_end)
	check("ev.else_indent_1", else_slice.size() > 20 and else_slice.all(func(c): return int(c.indent) == 1))
	check("ev.else_has_mob_routes", else_slice.filter(func(c): return int(c.code) == 205 and int(c.parameters[0]) == XRift.MOB_EV).size() == 3)
	check("ev.else_has_xufeng_routes", else_slice.filter(func(c): return int(c.code) == 205 and int(c.parameters[0]) == XRift.XUFENG_EV).size() == 4)
	check("ev.else_has_slash_23", else_slice.any(func(c): return int(c.code) == 212 and int(c.parameters[0]) == XRift.MOB_EV and int(c.parameters[1]) == XRift.SLASH_ANIM))
	var else_401: Array = else_slice.filter(func(c): return int(c.code) == 401).map(func(c): return str(c.parameters[0]))
	check("ev.else_has_all_5_lines", else_401 == [XRift.RIFT3_LINES.whisper, XRift.RIFT3_LINES.sense, XRift.RIFT3_LINES.hint, XRift.RIFT3_LINES.follow, XRift.RIFT3_LINES.after], else_401)
	check("ev.tail_self_a", i_end + 2 == body.size() - 1 and int(body[i_end + 1].code) == 123 and str(body[i_end + 1].parameters[0]) == "A" and int(body[i_end + 1].indent) == 0 and int(body[body.size() - 1].code) == 0)

	# 关掉 RIFT3_ANIM 后清缓存：无 111、无 CodexRift3、全顶层 indent=0（与 T412 原版逐条一致）
	XRift.RIFT3_ANIM = false
	XRift.clear_cache()
	var off_body: Array = _ev(XRift.RIFT3).pages[1].list
	check("ev.switch_off_flat_pixel", off_body.all(func(c): return int(c.indent) == 0) and not off_body.any(func(c): return int(c.code) == 111) and not off_body.any(func(c): return int(c.code) == 355 and str(c.parameters[0]).contains("CodexRift3")))
	XRift.RIFT3_ANIM = true
	XRift.clear_cache()


func _test_eval_expr_and_switches() -> void:
	# 1) 真实仓内缺 4 个 Muse 资源 → available() 为 false
	XRift3Anim._asset_exists_override = Callable()
	check("expr.missing_assets_false", not XRift3Anim.available() and MVScript.eval_expr("CodexRift3.available()") == false)

	# 2) 模拟 4 资源全齐 → 三层开关任一关闭即返回 false
	XRift3Anim._asset_exists_override = func(_p: String) -> bool: return true
	XRift.STAGE3 = true
	XRift.RIFT3_ANIM = true
	XRift3Anim.ENABLED = true
	check("expr.all_ready_true", XRift3Anim.available() and MVScript.eval_expr("CodexRift3.available()") == true)

	XRift.RIFT3_ANIM = false
	check("expr.rift3_anim_off_false", not XRift3Anim.available() and MVScript.eval_expr("CodexRift3.available()") == false)
	XRift.RIFT3_ANIM = true

	XRift.STAGE3 = false
	check("expr.stage3_off_false", not XRift3Anim.available() and MVScript.eval_expr("CodexRift3.available()") == false)
	XRift.STAGE3 = true

	XRift3Anim.ENABLED = false
	check("expr.enabled_off_false", not XRift3Anim.available() and MVScript.eval_expr("CodexRift3.available()") == false)
	XRift3Anim.ENABLED = true

	# 3) 缺任一必需资源 → eval_expr 返回 false
	var missing_path := XRift3Anim.REQUIRED_ASSETS[0]
	XRift3Anim._asset_exists_override = func(p: String) -> bool: return p != missing_path
	check("expr.missing_one_false", MVScript.eval_expr("CodexRift3.available()") == false)
	XRift3Anim._asset_exists_override = Callable()


func _test_replay_missed_params() -> void:
	var host := _MockHost.new()
	var interp := _MockInterp.new(host)

	# 1) missed_lines 为空时零弹窗且脚本被识别（返回 []）
	XRift3Anim.missed_lines.clear()
	var unrec_empty := await MVScript.run("CodexRift3.replayMissed();", interp)
	check("replay.empty_noop", unrec_empty.is_empty() and host.msgs.is_empty(), [unrec_empty, host.msgs])

	# 2) 全 5 句补播：核对 face/index/background/position 与逐字原文
	XRift3Anim.missed_lines = ["whisper", "sense", "hint", "follow", "after"]
	var unrec_all := await MVScript.run("CodexRift3.replayMissed();", interp)
	var actor := XDB.rec("Actors", XRift.XUFENG_ACTOR)
	var fn := str(actor.get("faceName", ""))
	var fi := int(actor.get("faceIndex", 0))
	check("replay.all5_count_and_cleared", unrec_all.is_empty() and host.msgs.size() == 5 and XRift3Anim.missed_lines.is_empty(), [unrec_all, host.msgs.size(), XRift3Anim.missed_lines])
	if host.msgs.size() == 5:
		check("replay.whisper_params", host.msgs[0] == {"face": "", "index": 0, "background": 1, "position": 1, "lines": [XRift.RIFT3_LINES.whisper]}, host.msgs[0])
		check("replay.sense_params", host.msgs[1] == {"face": fn, "index": fi, "background": 0, "position": 2, "lines": [XRift.RIFT3_LINES.sense]}, host.msgs[1])
		check("replay.hint_params", host.msgs[2] == {"face": fn, "index": fi, "background": 0, "position": 2, "lines": [XRift.RIFT3_LINES.hint]}, host.msgs[2])
		check("replay.follow_params", host.msgs[3] == {"face": fn, "index": fi, "background": 0, "position": 2, "lines": [XRift.RIFT3_LINES.follow]}, host.msgs[3])
		check("replay.after_params", host.msgs[4] == {"face": "", "index": 0, "background": 2, "position": 1, "lines": [XRift.RIFT3_LINES.after]}, host.msgs[4])


func _test_lobby_natural_full_play() -> void:
	XRift.STAGE3 = true
	XRift.RIFT3_ANIM = true
	XRift3Anim.ENABLED = true
	XRift3Anim._asset_exists_override = func(_p: String) -> bool: return true
	_prepare_rift3_trigger()

	var map := _open_lobby()
	var anim := await _wait_for_anim(map)
	check("full.anim_spawned", anim != null and map.busy)
	if anim == null:
		map.queue_free()
		await frames(2)
		return

	anim.set_process(false)
	var has_bgm := map.bgm != null and map.bgm.stream != null
	check("full.bgm_paused", (not has_bgm) or map.bgm.stream_paused, {"has_bgm": has_bgm, "paused": map.bgm.stream_paused if map.bgm != null else null})
	check("full.lobby_fx_yields", map.lobby_fx == null or (map.lobby_fx.rift_event_running() and (map.lobby_fx._hum == null or not map.lobby_fx._hum.playing)))

	# 在真实大厅宿主挂载状态下复核 Engine.time_scale=1.6 真实秒计时
	Engine.time_scale = 1.6
	var t_before := float(anim.state().t)
	anim._process(0.16)
	check("full.time_scale_real_sec", absf(float(anim.state().t) - (t_before + 0.10)) < 0.001 and absf(anim._video_player.speed_scale - (1.0 / 1.6)) < 0.001, {"t_before": t_before, "t_after": anim.state().t, "vspeed": anim._video_player.speed_scale})
	Engine.time_scale = 1.0

	# 自然推进到 26.0s 播满结束
	anim.step(XRift3Anim.TOTAL_DURATION - float(anim.state().t) + 0.05)
	var done_ok := await _wait_not_busy(map)
	check("full.free_move_restored", done_ok and not map.busy)
	check("full.missed_empty", XRift3Anim.missed_lines.is_empty(), XRift3Anim.missed_lines)
	check("full.zero_popups", XMessageBox.transcript.is_empty(), XMessageBox.transcript)
	check("full.marked_and_stage3", XConfig.whisper_seen("rift3") and XRift.stage() == 3)
	check("full.bgm_resumed", (not has_bgm) or not map.bgm.stream_paused)
	var xe := _find(map, XRift.XUFENG_EV)
	var me := _find(map, XRift.MOB_EV)
	check("full.no_pixel_actors_placed", xe != null and xe.character_name == "" and xe.grid == XRift.FALL_FROM and me != null and me.character_name == "" and me.grid == XRift.FALL_FROM)
	map.queue_free()
	await frames(2)

	# 再进一次大厅：已播过不重播
	XMessageBox.transcript.clear()
	XRift.clear_cache()
	var m2 := _open_lobby()
	var replayed := false
	for _i in range(90):
		await frames(1)
		if m2.get_node_or_null(XRift3Anim.NODE_NAME) != null:
			replayed = true
			break
	check("full.no_replay_on_reenter", not replayed and not m2.busy and XMessageBox.transcript.is_empty(), XMessageBox.transcript)
	m2.queue_free()
	await frames(2)


func _test_lobby_skip_replay(skip_at: float, expected_keys: Array[String], tag: String) -> void:
	XRift.STAGE3 = true
	XRift.RIFT3_ANIM = true
	XRift3Anim.ENABLED = true
	XRift3Anim._asset_exists_override = func(_p: String) -> bool: return true
	_prepare_rift3_trigger()

	var map := _open_lobby()
	var anim := await _wait_for_anim(map)
	check(tag + ".spawned", anim != null and map.busy)
	if anim == null:
		map.queue_free()
		await frames(2)
		return

	anim.set_process(false)
	var dt := maxf(0.0, skip_at - float(anim.state().t))
	anim.step(dt, true)
	check(tag + ".missed_recorded", anim.state().skipping and XRift3Anim.missed_lines == expected_keys, {"skipping": anim.state().skipping, "missed": XRift3Anim.missed_lines})
	anim.step(XRift3Anim.SKIP_FADE_SEC + 0.05)

	var done_ok := await _wait_not_busy(map, 240)
	var expected_texts: Array[String] = []
	for k in expected_keys:
		expected_texts.append(_plain_line(k))
	var actual_texts: Array[String] = []
	for entry in XMessageBox.transcript:
		actual_texts.append(str(entry).strip_edges())
	check(tag + ".replayed_exact", done_ok and actual_texts == expected_texts, {"actual": actual_texts, "expected": expected_texts})
	check(tag + ".missed_cleared", XRift3Anim.missed_lines.is_empty(), XRift3Anim.missed_lines)
	var xe := _find(map, XRift.XUFENG_EV)
	var me := _find(map, XRift.MOB_EV)
	check(tag + ".no_pixel_actors_and_free", not map.busy and XConfig.whisper_seen("rift3") and xe != null and xe.character_name == "" and me != null and me.character_name == "")
	map.queue_free()
	await frames(2)


func _run_pixel_lobby_check(tag: String) -> void:
	_prepare_rift3_trigger()
	var map := _open_lobby()
	var anim_spawned := false
	var mob_landed := false
	var mob_tinted := false
	var xufeng_landed := false
	for _i in range(TIMEOUT_FRAMES):
		await frames(1)
		if map.get_node_or_null(XRift3Anim.NODE_NAME) != null:
			anim_spawned = true
		var me := _find(map, XRift.MOB_EV)
		if me != null and me.character_name == XRift.MOB_IMG and me.grid == XRift.MOB_DROP:
			mob_landed = true
			if map.lobby_fx != null and me.self_modulate == XLobbyCorruption.PURPLE:
				mob_tinted = true
		var xe := _find(map, XRift.XUFENG_EV)
		if xe != null and xe.grid == XRift.XUFENG_DROP and xe.character_name != "":
			xufeng_landed = true
		if XConfig.whisper_seen("rift3") and map.player != null and not map.busy and XMessageBox.transcript.any(func(t): return str(t).contains("又来了一个人")):
			break
	check(tag + ".no_comic_anim", not anim_spawned)
	check(tag + ".pixel_actors_ran", mob_landed and mob_tinted and xufeng_landed, {"mob": mob_landed, "tint": mob_tinted, "xf": xufeng_landed})
	check(tag + ".all_5_lines", XMessageBox.transcript.size() == 5 and str(XMessageBox.transcript[0]).contains("从那头漏过来了") and str(XMessageBox.transcript[4]).contains("又来了一个人"), XMessageBox.transcript)
	check(tag + ".done_clean", not map.busy and XConfig.whisper_seen("rift3"))
	await frames(60)
	var me_end := _find(map, XRift.MOB_EV)
	var xe_end := _find(map, XRift.XUFENG_EV)
	check(tag + ".actors_faded", me_end != null and me_end.opacity == 0 and xe_end != null and xe_end.opacity == 0)
	map.queue_free()
	await frames(2)


func _test_missing_assets_fallback_to_pixel() -> void:
	# RIFT3_ANIM=true 但仓内缺 Muse 资源 → 走 411 Else 支完整回退原像素过场
	XRift.STAGE3 = true
	XRift.RIFT3_ANIM = true
	XRift3Anim.ENABLED = true
	XRift3Anim._asset_exists_override = Callable()
	check("fallback_missing.avail_false", not XRift3Anim.available())
	await _run_pixel_lobby_check("fallback_missing")


func _test_switch_off_and_stage3_off() -> void:
	# 1) RIFT3_ANIM=false：即使资源存在，也干净回退 T412 原像素过场
	XRift.STAGE3 = true
	XRift.RIFT3_ANIM = false
	XRift3Anim.ENABLED = true
	XRift3Anim._asset_exists_override = func(_p: String) -> bool: return true
	check("fallback_switch.avail_false", not XRift3Anim.available())
	await _run_pixel_lobby_check("fallback_switch")

	# 2) STAGE3=false：回二阶，无 EV205/206/207，stage()==2，available()==false
	XRift.RIFT3_ANIM = true
	XRift.STAGE3 = false
	XRift.clear_cache()
	check("stage3_off.no_events", (XDB.map(4).events as Array).size() == XRift.CANGLONG_EV + 1 and not XRift.keep_event(4, XRift.RIFT3))
	check("stage3_off.stage2_and_unavail", XRift.stage() == 2 and not XRift3Anim.available())
	XRift.STAGE3 = true
	XRift3Anim._asset_exists_override = Callable()
	XRift.clear_cache()
