extends Node
## 【cc·未经审查】时空漩涡三阶段（T412，XRift.STAGE3）：rift3 过场（Map004 EV205／206，徐凤年从天而降）、stage()==3、
## 三阶怪物异化默认不开（XRiftAlien.STAGE3_ALIEN）。数据核一遍，再真开大厅把过场从头放到尾。
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


func _ev(id: int):
	var evs: Array = XDB.map(4).events
	return evs[id] if id < evs.size() else null


func _seen() -> Array:
	XConfig.ensure_loaded()
	return XConfig._values.codexWhisperSeen as Array


func _run() -> void:
	TestEnv.isolate("xiyou_rift3_xufeng", false)
	XFestLobby.ENABLED = false  # 冠军庆典期间大厅多 78～81 号事件，与本专项无关
	XRift.STAGE2 = true
	XRift.STAGE3 = true
	XRift.CHAIN_AFTER_RIFT1 = true
	XRiftAlien.STAGE3_ALIEN = false
	XRift.clear_cache()
	_data()
	_stage()
	_visit_rule()
	_switch_off()
	await _lobby()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


func _data() -> void:
	var r3 = _ev(XRift.RIFT3)
	check("rift3.exists", r3 is Dictionary and int(r3.id) == 205 and str(r3.note) == "<codex_rift_whisper:rift3>", r3)
	check("rift3.pages", r3.pages.size() == 3 and int(r3.pages[0].trigger) == 4 and int(r3.pages[1].trigger) == 3 and str(r3.pages[1].conditions.selfSwitchCh) == "B" and str(r3.pages[2].conditions.selfSwitchCh) == "A")
	var watch: Array = r3.pages[0].list
	check("rift3.watch_seen", watch.any(func(c): return int(c.code) == 111 and str(c.parameters[1]) == "window.CodexWhisper&&CodexWhisper.seen('rift3')"))
	check("rift3.watch_cond", watch.any(func(c): return int(c.code) == 111 and str(c.parameters[1]) == XRift.RIFT3_CONDITION))
	check("rift3.cond_text", XRift.RIFT3_CONDITION.contains("seen('rift2')") and XRift.RIFT3_CONDITION.contains("!CodexWhisper.seen('rift3')") and XRift.RIFT3_CONDITION.contains("!CodexWhisper.seen('rift2@thisvisit')"))
	var body: Array = r3.pages[1].list
	check("rift3.mark_first", str(body[0].parameters[0]) == "CodexWhisper.mark('rift3');")
	check("rift3.self_a_last", int(body[body.size() - 2].code) == 123 and str(body[body.size() - 2].parameters[0]) == "A")
	check("rift3.lines", body.any(func(c): return int(c.code) == 401 and str(c.parameters[0]).contains("<徐凤年>")) and body.any(func(c): return int(c.code) == 401 and str(c.parameters[0]).contains("<??????>")))
	var a := XDB.rec("Actors", 152)
	check("rift3.face", body.any(func(c): return int(c.code) == 101 and str(c.parameters[0]) == str(a.faceName) and int(c.parameters[1]) == int(a.faceIndex)), [a.faceName, a.faceIndex])
	check("rift3.three_lines", body.filter(func(c): return int(c.code) == 401 and str(c.parameters[0]).contains("<徐凤年>")).size() == 3)
	var routes: Array = body.filter(func(c): return int(c.code) == 205 and int(c.parameters[0]) == XRift.XUFENG_EV).map(func(c): return c.parameters[1].list)
	check("rift3.routes", routes.size() == 4, routes.size())
	var mob_routes: Array = body.filter(func(c): return int(c.code) == 205 and int(c.parameters[0]) == XRift.MOB_EV).map(func(c): return c.parameters[1].list)
	check("mob.routes", mob_routes.size() == 3, mob_routes.size())
	var mfall: Array = mob_routes[0]
	check("mob.image", mfall.any(func(c): return int(c.code) == 41 and str(c.parameters[0]) == XRift.MOB_IMG and int(c.parameters[1]) == XRift.MOB_INDEX))
	check("mob.image_exists", XDB.img_path("characters", XRift.MOB_IMG) != "" and ResourceLoader.exists(XDB.img_path("characters", XRift.MOB_IMG)))
	check("mob.down_to_drop", XRift.FALL_FROM.y + mfall.filter(func(c): return int(c.code) == 1).size() == XRift.MOB_DROP.y)
	check("mob.fades", (mob_routes[2] as Array).any(func(c): return int(c.code) == 42 and int(c.parameters[0]) == 0))
	# 怪物先落，徐凤年后落，再斩
	var i_mob := body.find(body.filter(func(c): return int(c.code) == 205 and int(c.parameters[0]) == XRift.MOB_EV)[0])
	var i_xf := body.find(body.filter(func(c): return int(c.code) == 205 and int(c.parameters[0]) == XRift.XUFENG_EV)[0])
	var i_slash := body.find(body.filter(func(c): return int(c.code) == 212 and int(c.parameters[0]) == XRift.MOB_EV)[0])
	check("order.mob_xufeng_slash", i_mob < i_xf and i_xf < i_slash and int(body[i_slash].parameters[1]) == XRift.SLASH_ANIM, [i_mob, i_xf, i_slash])
	var me = _ev(XRift.MOB_EV)
	check("mob_ev", me is Dictionary and str(me.note) == XRift.MOB_NOTE and str(me.note) == XLobbyCorruption.MOB_TINT_NOTE and bool(me.pages[0].through) and str(me.pages[0].image.characterName) == "", me)
	var fall: Array = routes[0]
	check("fall.image", fall.any(func(c): return int(c.code) == 41 and str(c.parameters[0]) == str(a.characterName) and int(c.parameters[1]) == int(a.characterIndex)), [a.characterName, a.characterIndex])
	check("fall.image_is_7mobu7", str(a.characterName) == "7mobu7")
	var downs := fall.filter(func(c): return int(c.code) == 1).size()
	check("fall.down_to_drop", XRift.FALL_FROM.y + downs == XRift.XUFENG_DROP.y and XRift.FALL_FROM.x == XRift.XUFENG_DROP.x and XRift.FALL_FROM.y < XRift.CELL.y, downs)
	check("fall.through_dirfix", fall.any(func(c): return int(c.code) == 37) and fall.any(func(c): return int(c.code) == 35))
	# 不是被漩涡甩出来：没有从漩涡格起跳的位移跳跃（rift2 苍龙是 jump(0,2)）
	check("fall.not_thrown", routes.all(func(r): return not r.any(func(c): return int(c.code) == 14 and (int(c.parameters[0]) != 0 or int(c.parameters[1]) != 0))))
	var after_fall := body.slice(body.find(body.filter(func(c): return int(c.code) == 205 and int(c.parameters[0]) == XRift.XUFENG_EV)[0]) + 1)
	check("land.slash_shake_flash", int(after_fall[0].code) == 212 and int(after_fall[1].code) == 225 and int(after_fall[2].code) == 224)
	var xe = _ev(XRift.XUFENG_EV)
	check("xufeng_ev", xe is Dictionary and Vector2i(int(xe.x), int(xe.y)) == XRift.FALL_FROM and bool(xe.pages[0].through) and str(xe.pages[0].image.characterName) == "" and int(xe.pages[0].priorityType) == 2, xe)
	check("keep", XRift.keep_event(4, 205) and XRift.keep_event(4, 206) and XRift.keep_event(4, 207) and not XRift.keep_event(4, 208) and not XRift.keep_event(5, 205))
	check("rift2_untouched", _ev(XRift.RIFT2) is Dictionary and str(_ev(XRift.RIFT2).note) == "<codex_rift_whisper:rift2>")


func _stage() -> void:
	_seen().erase("rift3")
	check("stage.before", XRift.stage() == 2)
	_seen().append("rift3")
	check("stage.after_rift3", XRift.stage() == 3)
	check("alien.default_off", XRiftAlien.stage() == 2, XRiftAlien.stage())
	XRiftAlien.STAGE3_ALIEN = true
	check("alien.on", XRiftAlien.stage() == 3)
	XRiftAlien.STAGE3_ALIEN = false
	XRift.STAGE3 = false
	check("stage.off", XRift.stage() == 2)
	XRift.STAGE3 = true
	XRift.STAGE2 = false
	check("stage.stage2_off", XRift.stage() == 1)
	XRift.STAGE2 = true
	_seen().erase("rift3")


func _visit_rule() -> void:
	# rift2 在这一次进图里记下：rift3 本次不播，下一次进图才播
	XRift.on_map_setup(4)
	check("v.before", not XConfig.whisper_seen(XRift.RIFT2_VISIT_KEY))
	XConfig.whisper_mark("rift2")
	check("v.same_visit", XConfig.whisper_seen(XRift.RIFT2_VISIT_KEY))
	check("v.not_saved", not _seen().has(XRift.RIFT2_VISIT_KEY))
	XRift.on_map_setup(132)
	check("v.next_visit", not XConfig.whisper_seen(XRift.RIFT2_VISIT_KEY))
	# 不跟 CHAIN_AFTER_RIFT1：开着时 rift2 同一次也不算可播
	XConfig.whisper_mark("rift2")
	check("v.chain_ignored", XRift.CHAIN_AFTER_RIFT1 and XConfig.whisper_seen(XRift.RIFT2_VISIT_KEY))
	# rift1 的虚拟键照旧
	XRift.CHAIN_AFTER_RIFT1 = false
	XConfig.whisper_mark("rift1")
	check("v.rift1_same", XConfig.whisper_seen(XRift.THIS_VISIT_KEY))
	XRift.CHAIN_AFTER_RIFT1 = true
	check("v.rift1_chain", not XConfig.whisper_seen(XRift.THIS_VISIT_KEY))
	_seen().erase("rift1")
	_seen().erase("rift2")


func _switch_off() -> void:
	XRift.STAGE3 = false
	XRift.clear_cache()
	check("off.size", (XDB.map(4).events as Array).size() == XRift.CANGLONG_EV + 1, (XDB.map(4).events as Array).size())
	check("off.keep", not XRift.keep_event(4, 205) and XRift.keep_event(4, 204))
	XRift.STAGE3 = true
	XRift.clear_cache()
	check("on.size", (XDB.map(4).events as Array).size() == XRift.MOB_EV + 1)


func _open_lobby() -> XMapScene:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 4
	s.x = 14
	s.y = 26
	var map := XMapScene.new()
	add_child(map)
	return map


func _find(map: XMapScene, id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null


## 真开大厅：rift1、rift2 上次看过 → 这次进大厅 rift3 自动播完，徐凤年落在落点、走开；再进一次不重播
func _lobby() -> void:
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	XMessageBox.transcript.clear()
	XConfig.whisper_mark("rift1")
	XConfig.whisper_mark("rift2")
	XRift.on_map_setup(132)  # 「上一次进图」看的
	XRift.clear_cache()
	var map := _open_lobby()
	var landed := false
	var mob_seen := false
	var mob_tinted := false
	var shot_fall := false
	var shot_land := false
	for i in TIMEOUT_FRAMES:
		await frames(1)
		var me := _find(map, XRift.MOB_EV)
		if me != null and me.character_name == XRift.MOB_IMG and me.grid == XRift.MOB_DROP:
			mob_seen = true
			if map.lobby_fx != null and me.self_modulate == XLobbyCorruption.PURPLE:
				mob_tinted = true
		var xe := _find(map, XRift.XUFENG_EV)
		if xe != null and not shot_fall and xe.character_name != "" and xe.grid.y > XRift.FALL_FROM.y + 2:
			shot_fall = true
			await shot("rift3_fall.png")
		if xe != null and xe.grid == XRift.XUFENG_DROP and xe.character_name != "":
			landed = true
			if not shot_land and me != null and me.opacity == 255 and me.character_name == XRift.MOB_IMG:
				shot_land = true
				await frames(26)
				await shot("rift3_strike.png")
		if XConfig.whisper_seen("rift3") and map.player != null and not map.busy and XMessageBox.transcript.any(func(t): return str(t).contains("又来了一个人")):
			break
	check("lobby.marked", XConfig.whisper_seen("rift3"))
	check("lobby.landed", landed)
	check("lobby.mob_landed", mob_seen)
	check("lobby.mob_tinted", mob_tinted, map.lobby_fx != null)
	var me := _find(map, XRift.MOB_EV)
	check("lobby.mob_gone", me != null and me.opacity == 0, me.opacity if me != null else null)
	check("lobby.lines", XMessageBox.transcript.any(func(t): return str(t).contains("跟你走")), XMessageBox.transcript)
	check("lobby.done", not map.busy, map.busy)
	check("lobby.stage3", XRift.stage() == 3 and XRiftAlien.stage() == 2)
	await frames(60)
	var xe := _find(map, XRift.XUFENG_EV)
	check("lobby.left", xe != null and xe.opacity == 0, xe.opacity if xe != null else null)
	map.queue_free()
	await frames(2)
	# 再进一次：已播过，第 1 页直接开 A，不重播
	XMessageBox.transcript.clear()
	XRift.clear_cache()
	var m2 := _open_lobby()
	for i in 240:
		await frames(1)
	check("lobby.no_replay", not XMessageBox.transcript.any(func(t): return str(t).contains("跟你走")) and not m2.busy, XMessageBox.transcript)
	m2.queue_free()
	await frames(2)
