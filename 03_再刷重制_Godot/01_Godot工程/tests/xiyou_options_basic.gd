extends Node
## 正式 options_probe 对照、配置重读/不随局内读档回滚、四路现有播放器、跑步与战斗指令记忆。
var results := []
var out_dir := ""

class QuietBattle extends XBattleScene:
	func _main() -> void:
		pass

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()

func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name":name,"passed":ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))

func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame

func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(1)

func _run() -> void:
	XSave.dir_override = "user://test_xiyou_options_basic"
	XConfig.path_override = XSave.dir().path_join("options.json")
	DirAccess.remove_absolute(XConfig.path())
	XConfig._loaded_path = "<unloaded>"
	var ref = XDB.load_json("oracle/options.json")
	if not ref is Dictionary:
		check("oracle_present", false)
		return finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs and ref.sourceIdentity.releaseVersion == manifest.releaseVersion)
	for key in ref.defaults:
		check("default_" + key, XConfig.volume(key) == int(ref.defaults[key]) if key in XConfig.VOLUMES else XConfig.flag(key) == bool(ref.defaults[key]))
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 5
	s.x = 11
	s.y = 13
	var opt := XOptionsScene.new()
	add_child(opt)
	await frames()
	for row in ref.rows:
		var i := opt.symbols().find(row.symbol)
		check("order_" + row.symbol, i == ref.rows.find(row))
		if row.symbol in ref.defaults:
			check("status_" + row.symbol, opt.status_text(i) == row.status)
	for row in ref.volume:
		XConfig.set_volume(row.symbol, int(row.initial))
		opt.index = opt.symbols().find(row.symbol)
		match row.op:
			"processOk": opt.ok()
			"cursorRight": opt._side(true)
			"cursorLeft": opt._side(false)
		check("volume_%s_%d_%s" % [row.symbol,int(row.initial),row.op], XConfig.volume(row.symbol) == int(row.value) and opt.status_text(opt.index) == row.status)
	opt._select(opt.symbols().find("alwaysDash"))
	await press("ui_left")
	check("input_flag_left_off", not XConfig.flag("alwaysDash"))
	await press("ui_accept")
	check("input_flag_ok_on", XConfig.flag("alwaysDash"))
	opt._select(11)
	if out_dir != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("设置音量.png"))
	opt.queue_free()
	await frames()
	var player := MVPlayer.new()
	for row in ref.dash:
		XConfig.set_flag("alwaysDash", row.always)
		check("dash_%s_%s" % [row.always,row.shift], player.is_dashing(row.shift) == row.dashing)
	player.touch_target = Vector2i(1,1)
	XConfig.set_flag("alwaysDash", false)
	check("mouse_destination_dashes", player.is_dashing(false))
	player.dash = false
	check("map_disabled_never_dashes", not player.is_dashing(true))
	player.free()
	# 配置与局内存档分别保存；旧配置缺字段使用正式默认，不丢已有选项。
	XConfig.set_volume("bgmVolume", 60)
	XConfig.set_flag("commandRemember", false)
	XConfig._loaded_path = "<unloaded>"
	check("config_persists", XConfig.volume("bgmVolume") == 60 and not XConfig.flag("commandRemember"))
	var save := s.to_dict()
	XConfig.set_volume("bgmVolume", 20)
	XState.from_dict(save)
	check("save_load_keeps_global_config", XConfig.volume("bgmVolume") == 20)
	var a := s.actor(1)
	a.learn_skill(160)
	a.learn_skill(161)
	var battle := XBattleScene.new()
	battle.logic = XBattleLogic.new()
	battle.logic.state = s
	var commands := battle._command_entries(a)
	a.last_command = "stype:1"
	a.last_battle_skill = 160
	for row in ref.commands:
		XConfig.set_flag("commandRemember", row.remember)
		check("remember_command_%s" % row.remember, battle.initial_command_index(a, commands) == int(row.index))
	for row in ref.skills:
		XConfig.set_flag("commandRemember", row.remember)
		var skills := battle.logic.battle_skills(a).filter(func(sk):return int(sk.stypeId)==1)
		check("remember_skill_%s" % row.remember, int(skills[battle.initial_action_index(a, skills, false)].id) == int(row.id))
	s.last_item = 2
	check("item_selection_memory", battle.initial_action_index(a, [XDB.rec("Items",1),XDB.rec("Items",2)], true) == 1)
	var restored := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check("selection_memory_saved", restored.actor(1).last_command == "stype:1" and restored.actor(1).last_battle_skill == 160 and restored.last_item == 2)
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	legacy.erase("lastItem")
	for actor in legacy.actors.values():
		actor.erase("lastCommand")
		actor.erase("lastBattleSkill")
	check("legacy_save_memory_defaults", XState.from_dict(legacy).actor(1).last_battle_skill == 0)
	battle.free()
	XState.current = s
	# 真实指令窗口：记忆选中防御，键盘确定后仍保存；关闭后下一次从攻击开始。
	var live := QuietBattle.new()
	live.setup(2, true, true, {})
	add_child(live)
	await frames(4)
	a.last_command = "guard"
	XConfig.set_flag("commandRemember", true)
	var selected := [null]
	var choose = func(): selected[0] = await live._command_for(a)
	choose.call()
	await frames()
	check("live_command_selects_last", live.cmd_win.entries[live.cmd_win.index].key == "guard")
	await press("ui_accept")
	check("live_command_records_confirm", selected[0] is Array and int(selected[0][0].id) == 2 and a.last_command == "guard")
	XConfig.set_flag("commandRemember", false)
	selected[0] = null
	choose.call()
	await frames()
	check("live_command_off_starts_attack", live.cmd_win.index == 0)
	live.cmd_win.select(live._command_entries(a).find_custom(func(e):return e.key=="guard"))
	await press("ui_accept")
	check("live_command_off_clears_memory", a.last_command == "")
	live.queue_free()
	await frames()
	var map := XMapScene.new()
	add_child(map)
	await frames(4)
	check("map_audio_buses", map.bgm.bus == XAudio.bus("BGM") and map.se.bus == XAudio.bus("SE") and map.bgs.bus == XAudio.bus("BGS") and map.me.bus == XAudio.bus("ME"))
	map.play_me({"name":"Inn","volume":70,"pitch":100})
	await frames()
	check("me_play_pauses_bgm", map.me.playing and (not map.bgm.playing or map.bgm.stream_paused) and is_equal_approx(db_to_linear(map.me.volume_db),0.7), [map.me.playing,map.bgm.playing,map.bgm.stream_paused,db_to_linear(map.me.volume_db)])
	map.play_me({"name":""})
	check("me_stop_resumes_bgm", not map.me.playing and not map.bgm.stream_paused)
	for channel in XAudio.SYMBOLS:
		XConfig.set_volume(XAudio.SYMBOLS[channel], 0)
		check("mute_"+channel, AudioServer.is_bus_mute(AudioServer.get_bus_index(XAudio.bus(channel))))
		XConfig.set_volume(XAudio.SYMBOLS[channel], 50)
		check("live_volume_"+channel, is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(XAudio.bus(channel)))),0.5))
	XSound.system(0)
	await frames()
	XSound.system(0)
	check("menu_se_uses_bus", XSound._players.all(func(p):return p.bus==XAudio.bus("SE")))
	# 入战时暂停地图两路，挂机逃跑返回后恢复原音乐，不重播。
	map.encounter_count = 9999
	XEnemy.force_roll = 100
	XHangUp.ready_start(s, true, Vector2i(s.x,s.y))
	for key in ["CommonEscape","RareEscape","UnprecedentedEscape"]:
		XHangUp.settings(s)[key] = true
	var outcome := [null]
	var fight = func(): outcome[0] = await map.start_battle(2,true,true)
	fight.call()
	await frames(4)
	check("battle_pauses_map_audio", (not map.bgm.playing or map.bgm.stream_paused) and (not map.bgs.playing or map.bgs.stream_paused), [map.bgm.playing,map.bgm.stream_paused,map.bgs.playing,map.bgs.stream_paused,map._in_battle])
	for i in 6000:
		if outcome[0] != null:
			break
		await get_tree().physics_frame
	check("battle_resumes_map_audio", outcome[0] == 1 and not map.bgm.stream_paused and not map.bgs.stream_paused)
	XHangUp.stop(s)
	map.queue_free()
	await frames()
	DirAccess.remove_absolute(XConfig.path())
	finish()

func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT="+JSON.stringify({"passed":passed,"total":results.size()}))
	get_tree().quit.call_deferred(0 if passed==results.size() else 1)
