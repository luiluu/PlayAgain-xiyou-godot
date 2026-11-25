extends Node
## 【cc·未经审查】T486（O-663，XRift.BACKFILL_FROM_SAVE）：旧档 EV76／EV203 自开关 A 开着、配置 codexWhisperSeen 缺 rift1／rift2 时，
## 进大厅悄悄补记这两项（不播流萤、苍龙），同一次进大厅按原逻辑播徐凤年、进三阶。新档、已进三阶的档、天启篇档、开关关掉都不补。
## R4（小o 核查 P1-1／P2-1）：EV205 自开关 A 也开着（看完徐凤年）时连 rift3 一起补，直接三阶、不重播；配置已有 rift3（哪怕缺前置键）整个不动。
## 真开大厅四条路径（没看过徐凤年／看过徐凤年／配置已三阶／新档）都走 存档→读档→进大厅，核对槽文件 SHA-256 前后一致。
## 截图：带窗口跑并加 ++ --shot=<目录>（无头时不截）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const TIMEOUT_FRAMES := 3000
var passed := 0
var total := 0
var out_dir := ""


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			out_dir = arg.substr(7)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name))


func _seen() -> Array:
	XConfig.ensure_loaded()
	return XConfig._values.codexWhisperSeen as Array


func _reset_seen(keys: Array = []) -> void:
	_seen().clear()
	for k in keys:
		XConfig.whisper_mark(k)
	XRift._mark_visit.clear()


func _old_save(r1: bool, r2: bool, r3 := false) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 4
	s.x = 14
	s.y = 26
	if r1:
		s.set_self_switch(4, XRift.RIFT1, "A", true)
	if r2:
		s.set_self_switch(4, XRift.RIFT2, "A", true)
		s.set_self_switch(4, XRift.RIFT2, "B", true)
	if r3:
		s.set_self_switch(4, XRift.RIFT3, "A", true)
		s.set_self_switch(4, XRift.RIFT3, "B", true)
	return s


func _run() -> void:
	TestEnv.isolate("xiyou_rift_backfill", false)
	XFestLobby.ENABLED = false
	XRift.STAGE2 = true
	XRift.STAGE3 = true
	XRift.RIFT3_ANIM = false  # 漫画替换支另有专项；这里验推进，走像素过场
	XRift.CHAIN_AFTER_RIFT1 = true
	XRift.BACKFILL_FROM_SAVE = true
	XRiftAlien.STAGE3_ALIEN = false
	XRift.clear_cache()
	_unit()
	await _lobby_old_save()
	await _lobby_watched_xufeng()
	await _lobby_cfg_stage3()
	await _lobby_new_game()
	await _lobby_switch_off()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


func _unit() -> void:
	# 卡二阶的旧档：两项都补，补记不算「这一次进大厅才记的」
	_reset_seen()
	XRift.on_map_setup(4)
	var s := _old_save(true, true)
	check("u.both", XRift.backfill_from_save(s, 4) == ["rift1", "rift2"])
	check("u.saved", _seen().has("rift1") and _seen().has("rift2") and not _seen().has("rift3"), _seen())
	check("u.not_this_visit", not XConfig.whisper_seen(XRift.RIFT2_VISIT_KEY) and not XConfig.whisper_seen(XRift.THIS_VISIT_KEY))
	check("u.stage_still2", XRift.stage() == 2)
	check("u.idempotent", XRift.backfill_from_save(s, 4).is_empty())
	check("u.save_untouched", s.self_switch(4, XRift.RIFT1, "A") and s.self_switch(4, XRift.RIFT2, "A") and not s.self_switch(4, XRift.RIFT3, "A"))
	# 只缺 rift2
	_reset_seen(["rift1"])
	check("u.only_r2", XRift.backfill_from_save(s, 4) == ["rift2"])
	# 只看过流萤的档：只补 rift1，苍龙照常播
	_reset_seen()
	check("u.only_r1", XRift.backfill_from_save(_old_save(true, false), 4) == ["rift1"] and not _seen().has("rift2"), _seen())
	# 新档（没进过大厅）：不补，照常放流萤、苍龙
	_reset_seen()
	check("u.new_game", XRift.backfill_from_save(_old_save(false, false), 4).is_empty() and _seen().is_empty())
	# 已经进三阶的配置：不动
	_reset_seen(["rift1", "rift2", "rift3"])
	check("u.stage3_untouched", XRift.backfill_from_save(s, 4).is_empty() and _seen().size() == 3 and XRift.stage() == 3)
	# R4 P2-1：配置只有 rift3、缺前置键：也不改写（三阶配置保护）
	_reset_seen(["rift3"])
	var s3 := _old_save(true, true, true)
	check("u.stage3_partial_untouched", XRift.backfill_from_save(s3, 4).is_empty() and _seen() == ["rift3"] and XRift.stage() == 3, _seen())
	check("u.stage3_partial_untouched_s2", XRift.backfill_from_save(s, 4).is_empty() and _seen() == ["rift3"], _seen())
	# R4 P1-1：看过徐凤年的档（EV205 A 开着）配置空：三项都补，直接三阶
	_reset_seen()
	check("u.r3_all", XRift.backfill_from_save(s3, 4) == ["rift1", "rift2", "rift3"], _seen())
	check("u.r3_stage3", XRift.stage() == 3 and not XConfig.whisper_seen(XRift.RIFT2_VISIT_KEY))
	check("u.r3_idempotent", XRift.backfill_from_save(s3, 4).is_empty() and _seen().size() == 3)
	# 只缺 rift3（配置有 rift1／rift2）：只补 rift3、不重复记已有键
	_reset_seen(["rift1", "rift2"])
	check("u.r3_only", XRift.backfill_from_save(s3, 4) == ["rift3"] and _seen().size() == 3, _seen())
	# 只有 EV205 A（前置自开关缺）也按看过处理：链路是单向的
	_reset_seen()
	check("u.r3_alone", XRift.backfill_from_save(_old_save(false, false, true), 4) == ["rift1", "rift2", "rift3"], _seen())
	# STAGE3 关：rift3 不补，回到二阶补记
	XRift.STAGE3 = false
	_reset_seen()
	check("u.r3_stage3_off", XRift.backfill_from_save(s3, 4) == ["rift1", "rift2"], _seen())
	XRift.STAGE3 = true
	check("u.r3_save_untouched", s3.self_switch(4, XRift.RIFT3, "A") and s3.self_switch(4, XRift.RIFT3, "B"))
	# 别的地图不补
	_reset_seen()
	check("u.other_map", XRift.backfill_from_save(s, 132).is_empty() and _seen().is_empty())
	# 天启篇档不补
	var t := _old_save(true, true)
	t.flags["tianqi"] = {"rules": 1}
	check("u.tianqi", XTianqi.active(t) and XRift.backfill_from_save(t, 4).is_empty() and _seen().is_empty())
	# 回退开关
	XRift.BACKFILL_FROM_SAVE = false
	check("u.off", XRift.backfill_from_save(s, 4).is_empty() and _seen().is_empty())
	XRift.BACKFILL_FROM_SAVE = true
	XRift.STAGE2 = false
	check("u.stage2_off", XRift.backfill_from_save(s, 4).is_empty() and _seen().is_empty())
	XRift.STAGE2 = true


func _open_lobby() -> XMapScene:
	var map := XMapScene.new()
	add_child(map)
	return map


func _find(map: XMapScene, id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null


## 真开大厅：配置空、旧档自开关开着 → 这一次进大厅不播流萤、苍龙，直接播徐凤年、进三阶
func _lobby_old_save() -> void:
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	XMessageBox.transcript.clear()
	_reset_seen()
	var h0 := _save_and_load(_old_save(true, true))
	var map := _open_lobby()
	var canglong_shown := false
	var xufeng_landed := false
	for i in TIMEOUT_FRAMES:
		await frames(1)
		var ce := _find(map, XRift.CANGLONG_EV)
		if ce != null and ce.character_name != "":
			canglong_shown = true
		var xe := _find(map, XRift.XUFENG_EV)
		if xe != null and xe.grid == XRift.XUFENG_DROP and xe.character_name != "":
			if not xufeng_landed:
				await shot("backfill_xufeng.png")
			xufeng_landed = true
		if XConfig.whisper_seen("rift3") and map.player != null and not map.busy and XMessageBox.transcript.any(func(t): return str(t).contains("跟你走")):
			break
	check("l.backfilled", _seen().has("rift1") and _seen().has("rift2"), _seen())
	check("l.no_canglong", not canglong_shown)
	check("l.xufeng", xufeng_landed)
	check("l.rift3", XConfig.whisper_seen("rift3"))
	check("l.stage3", XRift.stage() == 3)
	check("l.lines", XMessageBox.transcript.any(func(t): return str(t).contains("跟你走")), XMessageBox.transcript)
	check("l.done", not map.busy)
	await frames(30)
	await shot("backfill_stage3.png")
	check("l.hash", h0 != "" and _slot_hash() == h0)
	map.queue_free()
	await frames(2)


## 存进槽 1 再读回（同导回存档后读档），返回槽文件 SHA-256
func _save_and_load(s: XState) -> String:
	XState.current = s
	if not XSave.save(1):
		return ""
	var h := _slot_hash()
	XRift.on_map_setup(132)
	XRift.clear_cache()
	if not XSave.load_slot(1):
		return ""
	return h


func _slot_hash() -> String:
	return FileAccess.get_sha256(XSave.path(1))


func _anim_node() -> Node:
	return get_tree().root.find_child(XRift3Anim.NODE_NAME, true, false)


## 进大厅 n 帧，记下有没有出苍龙、徐凤年落地、漫画
func _watch_lobby(map: XMapScene, n: int) -> Dictionary:
	var r := {"canglong": false, "xufeng": false, "anim": false}
	for i in n:
		await frames(1)
		var ce := _find(map, XRift.CANGLONG_EV)
		if ce != null and ce.character_name != "":
			r.canglong = true
		var xe := _find(map, XRift.XUFENG_EV)
		if xe != null and xe.grid == XRift.XUFENG_DROP and xe.character_name != "":
			r.xufeng = true
		if _anim_node() != null:
			r.anim = true
	return r


func _close_lobby(map: XMapScene) -> void:
	map.queue_free()
	await frames(2)
	var a := _anim_node()
	if a != null:
		a.queue_free()
		await frames(2)


## R4 P1-1：看过徐凤年的档、配置空（重装导回）：补记三项、不播漫画也不播像素过场，直接三阶；再进一次仍三阶
func _lobby_watched_xufeng() -> void:
	XRift.RIFT3_ANIM = true  # 漫画支开着也不能起
	XMessageBox.transcript.clear()
	_reset_seen()
	var h0 := _save_and_load(_old_save(true, true, true))
	var map := _open_lobby()
	var r := await _watch_lobby(map, 600)
	check("w.backfilled", _seen().has("rift1") and _seen().has("rift2") and _seen().has("rift3"), _seen())
	check("w.no_replay", not r.canglong and not r.xufeng and not r.anim, r)
	check("w.no_lines", not XMessageBox.transcript.any(func(t): return str(t).contains("跟你走")), XMessageBox.transcript)
	check("w.stage3", XRift.stage() == 3)
	await shot("watched_stage3.png")
	await _close_lobby(map)
	# 第二次进大厅
	var h1 := _save_and_load_again()
	map = _open_lobby()
	r = await _watch_lobby(map, 200)
	check("w.enter2_stage3", XRift.stage() == 3 and not r.xufeng and not r.anim and _seen().size() == 3, r)
	check("w.hash", h0 != "" and h1 == h0 and _slot_hash() == h0)
	await _close_lobby(map)
	XRift.RIFT3_ANIM = false
	XRift.clear_cache()


## 只读档、不存（第二次进大厅）
func _save_and_load_again() -> String:
	XRift.on_map_setup(132)
	XRift.clear_cache()
	XSave.load_slot(1)
	return _slot_hash()


## R4 P2-1：配置只有 rift3（缺前置键）：一个键都不改写，三阶、不播
func _lobby_cfg_stage3() -> void:
	XMessageBox.transcript.clear()
	_reset_seen(["rift3"])
	var h0 := _save_and_load(_old_save(true, true, true))
	var map := _open_lobby()
	var r := await _watch_lobby(map, 300)
	check("c3.cfg_untouched", _seen() == ["rift3"], _seen())
	check("c3.no_replay", not r.canglong and not r.xufeng and not r.anim, r)
	check("c3.stage3", XRift.stage() == 3)
	check("c3.hash", h0 != "" and _slot_hash() == h0)
	await _close_lobby(map)


## 新档（自开关全关）、配置空：不补记，流萤照常这一次进大厅播（rift1 记在这一次进图）
func _lobby_new_game() -> void:
	XMessageBox.transcript.clear()
	_reset_seen()
	var h0 := _save_and_load(_old_save(false, false))
	check("n.no_backfill", XRift.backfill_from_save(XState.current, 4).is_empty() and _seen().is_empty())
	var map := _open_lobby()
	var r := await _watch_lobby(map, 600)
	check("n.rift1_played", XConfig.whisper_seen("rift1") and int(XRift._mark_visit.get("rift1", -1)) == XRift._visit, [_seen(), XRift._mark_visit, XRift._visit])
	check("n.not_stage3", not _seen().has("rift3") and not r.xufeng, r)
	check("n.hash", h0 != "" and _slot_hash() == h0)
	await _close_lobby(map)


## 开关关掉：回到现状，旧档进几次大厅都卡二阶
func _lobby_switch_off() -> void:
	XRift.BACKFILL_FROM_SAVE = false
	XMessageBox.transcript.clear()
	_reset_seen()
	var h0 := _save_and_load(_old_save(true, true))
	var map := _open_lobby()
	for i in 300:
		await frames(1)
	check("off.no_mark", _seen().is_empty(), _seen())
	check("off.stage2", XRift.stage() == 2)
	check("off.hash", h0 != "" and _slot_hash() == h0)
	map.queue_free()
	await frames(2)
	XRift.BACKFILL_FROM_SAVE = true
