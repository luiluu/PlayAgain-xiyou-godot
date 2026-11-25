extends Node
## 【cc·未经审查】T486（O-663，XRift.BACKFILL_FROM_SAVE）：旧档 EV76／EV203 自开关 A 开着、配置 codexWhisperSeen 缺 rift1／rift2 时，
## 进大厅悄悄补记这两项（不播流萤、苍龙），同一次进大厅按原逻辑播徐凤年、进三阶。新档、已进三阶的档、天启篇档、开关关掉都不补。
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


func _old_save(r1: bool, r2: bool) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 4
	s.x = 14
	s.y = 26
	if r1:
		s.set_self_switch(4, XRift.RIFT1, "A", true)
	if r2:
		s.set_self_switch(4, XRift.RIFT2, "A", true)
		s.set_self_switch(4, XRift.RIFT2, "B", true)
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
	XRift.on_map_setup(132)
	XRift.clear_cache()
	_old_save(true, true)
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
	map.queue_free()
	await frames(2)


## 开关关掉：回到现状，旧档进几次大厅都卡二阶
func _lobby_switch_off() -> void:
	XRift.BACKFILL_FROM_SAVE = false
	XMessageBox.transcript.clear()
	_reset_seen()
	XRift.on_map_setup(132)
	XRift.clear_cache()
	_old_save(true, true)
	var map := _open_lobby()
	for i in 300:
		await frames(1)
	check("off.no_mark", _seen().is_empty(), _seen())
	check("off.stage2", XRift.stage() == 2)
	map.queue_free()
	await frames(2)
	XRift.BACKFILL_FROM_SAVE = true
