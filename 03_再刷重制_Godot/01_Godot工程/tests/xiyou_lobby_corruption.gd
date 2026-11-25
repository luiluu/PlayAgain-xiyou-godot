extends Node
## 【cc·大厅异化·未经审查】方桌大厅「初步异化」叠加层（XLobbyCorruption，O-311）：
## - 阶段一、开关关掉：大厅不建任何节点；
## - 阶段二：通行逐格逐方向与阶段一相同、事件表不变；浮砖避开漩涡十字与可调查格；光尘不超过 30；
## - 6 位 NPC 与镜子：原事件的对话（transcript）与阶段一完全相同，之后才多一句，每存档一次，存读档保留，旧档当没说过；
## - 3 处可调查（裂纹两段文字、固定浮砖、苍龙落点的鳞只在 rift2 播过后）；低鸣随距离；走近漩涡染紫；小字；画面特效开关；
## - 叠加层每帧开销（无画面下的 _process 用时）打印出来，交付单引用。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const TIMEOUT_FRAMES := 3000

var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", detail)
	return ok


## 窗口模式加 -- --out=<目录> 时保存实际画面（无头时跳过）
func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name))


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func open_lobby(stage: int, x := 14, y := 25, tianqi := false, pre_flags := {}) -> XMapScene:
	XLobbyCorruption.STAGE_OVERRIDE = stage
	var s := XState.new_game(3, 1, [8, 9, 10])
	if tianqi:
		s.flags["tianqi"] = {"rules": 1}
	for k in pre_flags:
		s.flags[k] = pre_flags[k].duplicate(true) if pre_flags[k] is Dictionary else pre_flags[k]
	s.set_variable(206, -3000)   # 讨债人三人组只在欠积分时出来（页 2、3 条件变量 206 ≥ −2000 是空页）
	s.set_variable(20, 3)        # 大工匠、阿伯特的可交互页
	s.set_variable(14, 1)        # 动保协会成员
	s.set_self_switch(4, 1, "A", true)   # 奥尔夫尼的常态页，初见送礼会换页
	s.set_self_switch(4, 40, "A", true)  # 魂灯商人的图鉴页
	s.map_id = 4
	s.x = x
	s.y = y
	var map := XMapScene.new()
	add_child(map)
	for i in TIMEOUT_FRAMES:
		await frames(1)
		if map.player != null and not map.busy and map.map_id == 4:
			break
	await frames(2)
	return map


func close(map: XMapScene) -> void:
	map.queue_free()
	await frames(2)


## 选项一律选「离开」那一项（ANSWERS），免得原事件改状态、第二次对话不同
const ANSWERS := {1: 5, 7: 3, 14: 2, 17: 1, 25: 3, 40: 1, 43: 1, 50: 1, 51: 1}
const STAGE3_ACTIONS := {
	1: [Vector2i.DOWN, 8], 7: [Vector2i.RIGHT, 4], 14: [Vector2i.LEFT, 6],
	17: [Vector2i.RIGHT, 4], 21: [Vector2i.DOWN, 8], 25: [Vector2i.RIGHT, 4], 40: [Vector2i.RIGHT, 4],
}

func act(map: XMapScene, cell: Vector2i, dir: int, id := 0) -> Array:
	# NPC 会随机走动：站到事件当前格的正下方、面朝上
	for e in map.events:
		if id > 0 and e.event_id == id and not e.erased:
			var approach: Array = STAGE3_ACTIONS.get(id, [Vector2i.DOWN, 8])
			cell = e.grid + Vector2i(approach[0])
			dir = approach[1]
	map.player.locate(cell.x, cell.y)
	map.player.direction = dir
	XMessageBox.transcript.clear()
	XMessageBox.auto_answers = [ANSWERS[id]] if ANSWERS.has(id) else []
	await map._on_action()
	await frames(2)
	return XMessageBox.transcript.duplicate()


func passability(map: XMapScene) -> Array:
	var out := []
	for y in map.lower.height:
		for x in map.lower.width:
			for d in [2, 4, 6, 8]:
				out.append(map.lower.is_passable(x, y, d))
	return out


func event_digest(map: XMapScene) -> String:
	return str(map.events.map(func(e): return [e.event_id, e.page_index]))


func _run() -> void:
	TestEnv.isolate("xiyou_lobby_corruption")
	# 本专项要「rift2 还没播」的大厅：TestEnv 默认把 rift2 记成看过，这里去掉；漩涡二阶段的地图补丁（XRift.STAGE2，含 rift2 过场 EV203）关掉，
	# 免得过场占住大厅（阶段由 STAGE_OVERRIDE 指定，落点仍读 XRift.canglong_drop_cell）
	(XConfig._values.codexWhisperSeen as Array).erase("rift2")
	XRift.STAGE2 = false
	XRift.clear_cache()
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	# 固定非庆典日期，免受本机日期影响；庆典兼容段单独切活动日验证
	XFest.TODAY_OVERRIDE = "2026-12-20"
	XFestLobby.reload_map()

	# ---- 阶段一：不建叠加层 ----
	var m1 := await open_lobby(1)
	check("map_loaded", m1.map_id == 4 and m1.player != null, [m1.map_id])
	check("stage1.no_layer", m1.lobby_fx == null and m1.get_children().all(func(n): return not n is XLobbyCorruption))
	check("stage1.option_listed", XLobbyCorruption.ENABLED)
	m1.player.locate(14, 21)
	await frames(10)
	await shot("lobby_stage1.png")
	var pass1 := passability(m1)
	var ev1 := event_digest(m1)
	var said1 := {}
	for row in [[51, Vector2i(13, 13), 8], [50, Vector2i(14, 14), 8], [7, Vector2i(5, 17), 4], [43, Vector2i(5, 19), 4], [21, Vector2i(9, 27), 8]]:
		said1[row[0]] = await act(m1, row[1], row[2], row[0])
	for id in STAGE3_ACTIONS:
		if not said1.has(id):
			said1[id] = await act(m1, Vector2i.ZERO, 2, id)
	await close(m1)

	# ---- 开关关掉：阶段二也不建 ----
	XLobbyCorruption.ENABLED = false
	var m0 := await open_lobby(2)
	check("off.no_layer", m0.lobby_fx == null)
	var t0 := await act(m0, Vector2i(14, 22), 2)
	check("off.no_investigation", t0.is_empty(), t0)
	await close(m0)
	XLobbyCorruption.ENABLED = true

	# ---- 阶段二 ----
	# 地图数据（XDB 缓存的 Map004）进出叠加层前后一字不差（原事件跑起来会给移动路线补字段，所以比的是建层前后）
	var data_before := JSON.stringify(XDB.map(4)).sha256_text()
	var m2 := await open_lobby(2)
	check("stage2.map_data_same", JSON.stringify(m2.map_data).sha256_text() == data_before)
	var fx := m2.lobby_fx
	if not check("stage2.layer", fx != null and fx.is_inside_tree()):
		_finish()
		return
	check("stage2.pass_same", passability(m2) == pass1)
	check("stage2.events_same", event_digest(m2) == ev1, [event_digest(m2), ev1])
	check("stage2.max_stage", int(XLobbyCorruption.record(XState.current).maxStage) == 2, XState.current.flags.get(XLobbyCorruption.FLAG_KEY))
	check("stage2.no_stage3_visual", not fx.stage3_on() and absf(fx.desat_radius_cells() - 6.0) < 0.01 and not fx.has_stage3_cracks() and fx.corner_count() == 0 and fx.wall_vein_count() == 0 and not fx.gate_vein_visible() and fx.decay_furniture_count() == 0 and fx.decay_plant_count() == 0 and fx.decay_mold_count() == 0 and fx.decay_lamp_count() == 0 and fx.decay_dim_alpha() == 0.0, [fx.stage3_on(), fx.desat_radius_cells(), fx.has_stage3_cracks(), fx.corner_count(), fx.wall_vein_count(), fx.decay_furniture_count()])
	check("floats.fixed", fx.floats.has(XLobbyCorruption.FIXED_FLOAT) and fx.floats.size() >= 2 and fx.floats.size() <= 3, fx.floats)
	check("floats.avoid", fx.floats.all(_float_clear), fx.floats)
	var has_art := ResourceLoader.exists("res://content/lobby/crack_stage2.png")
	check("art.crack", fx.crack_textured() == has_art, [has_art, fx.crack_textured()])
	await frames(30)
	m2.player.locate(14, 21)
	await frames(90)
	await shot("lobby_stage2.png")
	check("motes.cap", fx.mote_count() > 0 and fx.mote_count() <= 30, fx.mote_count())

	# 追加台词：原对话与阶段一一样，之后多一句；第二次不再说
	var lines := {51: "那个圈圈", 50: "来收账的", 7: "地砖不是我弄裂的", 43: "不肯靠近大厅中间", 21: "慢了半拍"}
	var spots := {51: [Vector2i(13, 13), 8], 50: [Vector2i(14, 14), 8], 7: [Vector2i(5, 17), 4], 43: [Vector2i(5, 19), 4], 21: [Vector2i(9, 27), 8]}
	for id in lines:
		var got := await act(m2, spots[id][0], spots[id][1], id)
		var base: Array = said1[id]
		check("after.%d.original" % id, not base.is_empty() and got.slice(0, base.size()) == base, [base, got])
		check("after.%d.extra" % id, got.size() == base.size() + 1 and str(got.back()).contains(lines[id]), got)
		var again := await act(m2, spots[id][0], spots[id][1], id)
		check("after.%d.once" % id, again == base, [again, base])
	var said: Array = XLobbyCorruption.record(XState.current).said
	check("said.saved", said.has("51") and said.has("21"), said)
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(XState.current.to_dict())))
	check("said.roundtrip", (XLobbyCorruption.record(back).said as Array).has("50"), back.flags.get(XLobbyCorruption.FLAG_KEY))
	var old := XState.new_game(3, 1, [8, 9, 10])
	check("said.old_save", (XLobbyCorruption.record(old).said as Array).is_empty())

	# 可调查
	var c1 := await act(m2, XLobbyCorruption.CRACK_CELL, 2)
	var c2 := await act(m2, XLobbyCorruption.CRACK_CELL, 2)
	check("crack.texts", c1.size() == 1 and c1[0].contains("缝里不是土") and c2.size() == 1 and c2[0].contains("凉的"), [c1, c2])
	var fl := await act(m2, XLobbyCorruption.FIXED_FLOAT, 2)
	check("float.text", fl.size() == 1 and fl[0].contains("浮起来"), fl)
	var drop := XLobbyCorruption.drop_cell()
	var sc0 := await act(m2, drop, 2)
	check("scale.hidden_before_rift2", sc0.is_empty() and fx.scale_cell() == Vector2i(-1, -1), sc0)
	XConfig.whisper_mark("rift2")
	await frames(2)
	var sc1 := await act(m2, drop, 2)
	check("scale.after_rift2", fx.scale_cell() == drop and sc1.size() == 1 and sc1[0].contains("青色的鳞"), sc1)

	# 低鸣、染紫
	m2.player.locate(14, 21)
	await frames(2)
	var near := fx.hum_level()
	var tint_near := m2.player.self_modulate
	m2.player.locate(14, 5)
	await frames(2)
	check("hum.near", near > 0.25 and near <= XLobbyCorruption.HUM_MAX + 1e-6, near)
	check("hum.far", fx.hum_level() == 0.0, fx.hum_level())
	check("tint.near", tint_near != Color.WHITE, tint_near)
	check("tint.far", m2.player.self_modulate == Color.WHITE, m2.player.self_modulate)

	# 小字、画面特效开关
	var lab := fx.show_ambient()
	check("ambient.label", lab.get_parent() == m2.ui and XLobbyCorruption.AMBIENT_LINES.has(lab.text), lab.text)
	XConfig.set_flag("codexScreenFx", false)
	await frames(2)
	check("fx_off.motes", fx.mote_count() == 0, fx.mote_count())
	XConfig.set_flag("codexScreenFx", true)

	# 每帧开销（无画面，只量 _process；交付单引用）
	var t := Time.get_ticks_usec()
	for i in 600:
		fx._process(1.0 / 60.0)
	var per := (Time.get_ticks_usec() - t) / 600.0
	print("[lobby_corruption] _process 平均 %.1f 微秒/帧（600 帧，光尘 %d）" % [per, fx.mote_count()])
	check("perf.process", per < 2000.0, per)

	# 没有正式图时程序画：置空路径重建一次
	XLobbyCorruption.CRACK_TEX = ""
	var bare := XLobbyCorruption.new()
	add_child(bare)
	bare.setup(m2)
	check("art.fallback", not bare.crack_textured() and bare._cracks.size() >= 11, bare._cracks.size())
	bare.queue_free()
	XLobbyCorruption.CRACK_TEX = "res://content/lobby/crack_stage2.png"

	# 离开大厅即拆
	m2.load_map(5, 11, 13, 2)
	await frames(3)
	check("leave.freed", m2.lobby_fx == null)
	await close(m2)

	# ---- 阶段三「蚀骨」（T416 拆卡 1：视觉叠加层、开关骨架、天启篇守卫、庆典兼容与性能） ----
	await _test_stage3(pass1, ev1, data_before, per)
	await _test_stage3_interactions(said1)
	await _test_stage3_audio()
	await _test_stage3_atmosphere()
	_finish()


func _test_stage3_audio() -> void:
	var map := await open_lobby(3, 14, 26)
	var fx: Variant = map.lobby_fx
	if not check("stage3.audio.hooked", fx.has_method("_update_stage3_bgm")):
		await close(map)
		return
	fx.set_process(false)
	# 开图异步等待了若干帧，量进厅时抽到的计时长度。
	var initial_drop: float = fx._bgm_drop_in + XSpeedGear.real_seconds(fx._t)
	check("stage3.drop.first_window", initial_drop >= 50.0 and initial_drop <= 80.0, initial_drop)
	map.play_bgm({"name": "TCLH-60", "volume": 80})
	var base_db := map.bgm.volume_db
	map.player.locate(14, 21)
	fx._update_stage3_bgm(0.4)
	check("stage3.detune.smooth", map.bgm.pitch_scale < 1.0 and map.bgm.pitch_scale > 0.96, map.bgm.pitch_scale)
	fx._update_stage3_bgm(0.4)
	check("stage3.detune.near", is_equal_approx(map.bgm.pitch_scale, 0.96), map.bgm.pitch_scale)
	map.player.locate(14, 25)
	fx._update_stage3_bgm(0.8)
	check("stage3.detune.far", map.bgm.pitch_scale == 1.0)
	map.player.locate(14, 21)
	for mode in ["battle", "rift", "menu", "disabled"]:
		fx._update_stage3_bgm(0.8)
		map._in_battle = mode == "battle"
		map.busy = mode == "rift"
		map.running_event_id = 75 if map.busy else 0
		map._menu_open = mode == "menu"
		XLobbyCorruption.STAGE3_BGM_DETUNE = mode != "disabled"
		fx._update_stage3_bgm(0.0)
		check("stage3.detune.reset_" + mode, map.bgm.pitch_scale == 1.0, map.bgm.pitch_scale)
		map._in_battle = false
		map.busy = false
		map.running_event_id = 0
		map._menu_open = false
		XLobbyCorruption.STAGE3_BGM_DETUNE = true

	XLobbyCorruption.STAGE3_BGM_DETUNE = false
	fx._bgm_drop_in = 0.0
	fx._update_stage3_bgm(0.0)
	check("stage3.drop.start", is_equal_approx(map.bgm.pitch_scale, 0.94) and fx._bgm_drop_in >= 35.0 and fx._bgm_drop_in <= 65.0)
	fx._update_stage3_bgm(0.1)
	check("stage3.drop.low", is_equal_approx(db_to_linear(map.bgm.volume_db - base_db), 0.15))
	fx._update_stage3_bgm(0.15)
	check("stage3.drop.hold", is_equal_approx(db_to_linear(map.bgm.volume_db - base_db), 0.15))
	fx._update_stage3_bgm(0.05)
	check("stage3.drop.rise", is_equal_approx(db_to_linear(map.bgm.volume_db - base_db), 0.575)
		and is_equal_approx(map.bgm.pitch_scale, 0.97), [map.bgm.volume_db, map.bgm.pitch_scale])
	fx._update_stage3_bgm(0.05)
	check("stage3.drop.restore", map.bgm.volume_db == base_db and map.bgm.pitch_scale == 1.0,
		[map.bgm.volume_db, base_db, map.bgm.pitch_scale])
	XLobbyCorruption.STAGE3_BGM_DETUNE = true

	var bgm_bus := AudioServer.get_bus_index(XAudio.bus("BGM"))
	var old_mute := AudioServer.is_bus_mute(bgm_bus)
	for mode in ["fade", "other_track", "mute", "menu", "dialogue", "disabled"]:
		if mode == "fade":
			XAudio.fade_in(map.bgm)
		if mode == "other_track":
			# 同一播放器上替换曲名，验证现有庆典曲白名单分支。
			map._bgm_name = "festival"
		AudioServer.set_bus_mute(bgm_bus, mode == "mute")
		map._menu_open = mode == "menu"
		map.busy = mode == "dialogue"
		XLobbyCorruption.STAGE3_BGM_DROP = mode != "disabled"
		fx._bgm_drop_in = 0.0
		fx._update_stage3_bgm(0.1)
		check("stage3.drop.skip_" + mode, fx._bgm_drop_elapsed < 0.0 and fx._bgm_drop_in > 0.0)
		if mode == "fade":
			check("stage3.drop.fade_owns_gain", is_equal_approx(map.bgm.volume_db, -80.0))
			XAudio.stop_fade(map.bgm)
		map._bgm_name = "TCLH-60"
	AudioServer.set_bus_mute(bgm_bus, old_mute)
	map._menu_open = false
	map.busy = false
	XLobbyCorruption.STAGE3_BGM_DROP = true
	fx._bgm_drop_in = 0.0
	fx._update_stage3_bgm(0.1)
	fx._update_stage3_bgm(0.1)
	check("stage3.drop.layers_with_detune", map.bgm.pitch_scale < 0.94 and map.bgm.volume_db < base_db)
	XLobbyCorruption.STAGE3_BGM_DROP = false
	fx._update_stage3_bgm(0.0)
	check("stage3.drop.cancel_keeps_detune", map.bgm.volume_db == base_db and map.bgm.pitch_scale < 1.0)
	XLobbyCorruption.STAGE3_BGM_DROP = true

	fx._update_audio(0.0)
	check("stage3.hum.near", is_equal_approx(fx.hum_level(), 0.36) and is_equal_approx(fx._hum.pitch_scale, 0.66))
	map.player.locate(14, 30)
	check("stage3.hum.expanded", fx.hum_level() > 0.0)
	XLobbyCorruption.STAGE3_HUM_DEEP = false
	fx._update_audio(0.0)
	check("stage3.hum.fallback", fx.hum_level() == 0.0 and is_equal_approx(fx._hum.pitch_scale, 0.70))
	XLobbyCorruption.STAGE3_HUM_DEEP = true

	map.player.locate(14, 21)
	fx._whisper_in = 0.0
	fx._update_whisper(0.0)
	check("stage3.whisper.positional", fx._whisper.playing and fx._whisper.bus == XAudio.bus("BGS")
		and fx._whisper.position == XLobbyCorruption.cell_px(XLobbyCorruption.CENTER)
		and is_equal_approx(fx._whisper.pitch_scale, 0.58) and fx._whisper_in >= 75.0 and fx._whisper_in <= 110.0)
	fx._update_whisper(0.25)
	check("stage3.whisper.gain", is_equal_approx(db_to_linear(fx._whisper.volume_db), 0.15))
	fx._update_whisper(1.25)
	check("stage3.whisper.ends", not fx._whisper.playing)
	fx._whisper_in = 0.0
	fx._update_whisper(0.0)
	XLobbyCorruption.STAGE3_WHISPER = false
	fx._update_whisper(0.0)
	check("stage3.whisper.disabled", not fx._whisper.playing)
	XLobbyCorruption.STAGE3_WHISPER = true

	fx._bgm_drop_in = 0.0
	fx._update_stage3_bgm(0.2)
	fx._whisper_in = 0.0
	fx._update_whisper(0.0)
	map.load_map(5, 11, 13, 2)
	check("stage3.bgm.transfer_immediate", map.bgm.pitch_scale == 1.0 and not fx._whisper.playing)
	await frames(2)
	check("stage3.audio.no_late_reset", not is_instance_valid(fx))
	await close(map)

	map = await open_lobby(3, 14, 21)
	fx = map.lobby_fx
	fx._update_stage3_bgm(0.8)
	var exit_pitch := []
	var bgm := map.bgm
	fx.tree_exited.connect(func(): exit_pitch.append(bgm.pitch_scale))
	await close(map)
	check("stage3.bgm.scene_exit", exit_pitch == [1.0], exit_pitch)


func _test_stage3_atmosphere() -> void:
	var map: Variant = await open_lobby(3)
	var fx: Variant = map.lobby_fx
	if not check("stage3.name.hooked", fx.has_method("roll_name_glitch")):
		await close(map)
		return
	var script: Variant = fx.get_script()
	var hall_name := "方桌大厅"
	var seed_rng := RandomNumberGenerator.new()
	while seed_rng.randf() >= 0.25:
		seed_rng.seed += 1
	fx._atmosphere_rng.seed = seed_rng.seed
	script._name_glitch_last_ms = -300000
	script._name_glitch_index = 0
	var data_name: String = map.map_data.displayName
	map._show_map_name(hall_name, true)
	var tween: Tween = map._map_name_tween
	var fade := 0.3 if XMapScene.MAP_NAME_BACKDROP_V2 and XUiSkin.on() else 1.0
	tween.pause()
	tween.custom_step(fade + 1.09)
	check("stage3.name.before", map.displayed_map_name() == hall_name)
	tween.custom_step(0.02)
	check("stage3.name.flash", map.displayed_map_name() == "方桌……" and map.map_name_text == hall_name)
	await shot("t418_name_glitch.png")
	tween.custom_step(0.26)
	check("stage3.name.held", map.displayed_map_name() == "方桌……")
	tween.custom_step(0.02)
	check("stage3.name.restored", map.displayed_map_name() == hall_name and map.map_data.displayName == data_name)
	await shot("t418_name_restored.png")
	fx._atmosphere_rng.seed = seed_rng.seed
	check("stage3.name.cooldown", not fx.roll_name_glitch(hall_name))
	script._name_glitch_last_ms = -300000
	XConfig.set_flag("codexScreenFx", false)
	check("stage3.name.fx_off", not fx.roll_name_glitch(hall_name))
	XConfig.set_flag("codexScreenFx", true)
	XLobbyCorruption.STAGE3_NAME_GLITCH = false
	check("stage3.name.disabled", not fx.roll_name_glitch(hall_name))
	XLobbyCorruption.STAGE3_NAME_GLITCH = true
	var expected_names := ["方桌？厅", "无人大厅", "空桌大厅", "方桌旧厅", "方桌……"]
	for expected in expected_names:
		script._name_glitch_last_ms = -300000
		fx._atmosphere_rng.seed = seed_rng.seed
		map._show_map_name(hall_name, true)
		tween = map._map_name_tween
		tween.pause()
		tween.custom_step(fade + 1.11)
		check("stage3.name.rotation", map.displayed_map_name() == expected, [expected, map.displayed_map_name()])
	var previous_tween := tween
	map.load_map(4, 14, 25, 2)
	check("stage3.name.same_map_refresh", not previous_tween.is_valid() and map.displayed_map_name() == hall_name)

	script._ambient_index = 0
	var lines := [
		"墙角的光，好像比上次亮了一点。", "刚才好像漏了一拍。", "高塔门那边，有风往里灌。",
		"有块地砖浮起来，没再落回去。", "有张熟面孔，刚才差点没认出来。"]
	var observed := []
	for i in 12:
		observed.append(fx.show_ambient().text)
	check("stage3.ambient.rotation", observed == XLobbyCorruption.AMBIENT_LINES + lines + [XLobbyCorruption.AMBIENT_LINES[0]], observed)
	check("stage3.ambient.rate", fx.ambient_chance() == 0.25 and fx.ambient_gap_ms() == 480000)
	script._ambient_index = 6
	fx.show_ambient().modulate.a = 1.0
	await shot("t418_ambient.png")
	XLobbyCorruption.STAGE3_AMBIENT = false
	check("stage3.ambient.fallback", fx.ambient_chance() == 0.2 and fx.ambient_gap_ms() == 600000
		and XLobbyCorruption.AMBIENT_LINES.has(fx.show_ambient().text))
	XLobbyCorruption.STAGE3_AMBIENT = true
	await close(map)

	var tq := await open_lobby(3, 14, 21, true)
	fx = tq.lobby_fx
	fx._atmosphere_rng.seed = seed_rng.seed
	check("stage3.atmosphere.tianqi_exempt", not fx.roll_name_glitch(hall_name) and tq.bgm.pitch_scale == 1.0
		and is_equal_approx(fx.hum_level(), 0.3) and fx.ambient_gap_ms() == 600000 and fx._whisper == null)
	await close(tq)


func _test_stage3(pass1: Array, ev1: String, data_before: String, per2: float) -> void:
	# 1) 总闸＋全部 15 个子开关（含 STAGE3_DECAY）默认开启；null 存档不激活三阶
	var switches_on := XLobbyCorruption.STAGE3_ENABLED \
		and XLobbyCorruption.STAGE3_GROUND and XLobbyCorruption.STAGE3_FOUR_COLORS and XLobbyCorruption.STAGE3_WALL_VEINS and XLobbyCorruption.STAGE3_DECAY \
		and XLobbyCorruption.STAGE3_BGM_DETUNE and XLobbyCorruption.STAGE3_BGM_DROP and XLobbyCorruption.STAGE3_HUM_DEEP and XLobbyCorruption.STAGE3_WHISPER \
		and XLobbyCorruption.STAGE3_NPC_FX and XLobbyCorruption.STAGE3_NPC_LINES and XLobbyCorruption.STAGE3_MIRROR and XLobbyCorruption.STAGE3_STUMP \
		and XLobbyCorruption.STAGE3_INVESTIGATIONS and XLobbyCorruption.STAGE3_NAME_GLITCH and XLobbyCorruption.STAGE3_AMBIENT
	check("stage3.switches_default_on", switches_on)
	XLobbyCorruption.STAGE_OVERRIDE = 3
	check("stage3.null_state_off", not XLobbyCorruption.stage3_active(null))

	# 2) 天启篇存档：零三阶视觉变化（含腐烂破败层），且 maxStage 不写成 3（新档不建键、旧档 maxStage=2 不升写）
	var mtq := await open_lobby(3, 14, 25, true)
	var fxtq := mtq.lobby_fx
	check("stage3.tianqi_active_guard", XTianqi.active(XState.current) and not XLobbyCorruption.stage3_active(XState.current) and fxtq != null and not fxtq.stage3_on())
	check("stage3.final_tianqi_guard", fxtq != null and not fxtq.has_node("Stage3Backdrop"))
	check("stage3.tianqi_no_maxstage", not XState.current.flags.has(XLobbyCorruption.FLAG_KEY), XState.current.flags.get(XLobbyCorruption.FLAG_KEY))
	await frames(10)
	check("stage3.tianqi_zero_visual", absf(fxtq.desat_radius_cells() - 6.0) < 0.01 and not fxtq.has_stage3_cracks() \
		and fxtq.corner_count() == 0 and fxtq.wall_vein_count() == 0 and not fxtq.gate_vein_visible() \
		and fxtq.decay_furniture_count() == 0 and fxtq.decay_plant_count() == 0 and fxtq.decay_mold_count() == 0 and fxtq.decay_lamp_count() == 0 and fxtq.decay_dim_alpha() == 0.0 \
		and fxtq.floats.has(XLobbyCorruption.FIXED_FLOAT) and fxtq.floats.size() >= 2 and fxtq.floats.size() <= 3 \
		and fxtq.mote_count() <= 30 and fxtq.corner_mote_count() == 0,
		[fxtq.desat_radius_cells(), fxtq.has_stage3_cracks(), fxtq.corner_count(), fxtq.wall_vein_count(), fxtq.decay_furniture_count(), fxtq.floats, fxtq.mote_count()])
	await close(mtq)

	var mtq_old := await open_lobby(3, 14, 25, true, {XLobbyCorruption.FLAG_KEY: {"said": [], "crack": 0, "maxStage": 2}})
	check("stage3.tianqi_old_maxstage_kept", int(XState.current.flags[XLobbyCorruption.FLAG_KEY].get("maxStage", 0)) == 2, XState.current.flags.get(XLobbyCorruption.FLAG_KEY))
	await close(mtq_old)

	# 3) 西游档阶段三默认（非庆典常态）：视觉全层、通行逐格不变、浮砖校验、粒子、性能与实机截图
	var m3 := await open_lobby(3)
	check("stage3.map_data_same", JSON.stringify(m3.map_data).sha256_text() == data_before)
	var fx3 := m3.lobby_fx
	if not check("stage3.layer", fx3 != null and fx3.is_inside_tree() and fx3.stage3_on() and XLobbyCorruption.stage3_active(XState.current)):
		await close(m3)
		return
	check("stage3.max_stage", int(XLobbyCorruption.record(XState.current).maxStage) == 3, XState.current.flags.get(XLobbyCorruption.FLAG_KEY))
	check("stage3.pass_same", passability(m3) == pass1)
	check("stage3.events_same", event_digest(m3) == ev1, [event_digest(m3), ev1])
	var backdrop := fx3.get_node_or_null("Stage3Backdrop") as Sprite2D
	var runoff := fx3.get_node_or_null("Stage3Runoff") as Sprite2D
	var roots := fx3.get_node_or_null("Stage3Roots") as Sprite2D
	check("stage3.final_scenery", backdrop != null and backdrop.texture.get_size() == Vector2(1392, 1584)
		and runoff != null and runoff.texture.get_size() == backdrop.texture.get_size()
		and roots != null and roots.texture.get_size() == backdrop.texture.get_size())
	var front := fx3.get_node_or_null("Stage3Foreground") as Sprite2D
	var vortex := fx3.get_node_or_null("Stage3Vortex") as Sprite2D
	check("stage3.final_layers", front != null and front.z_index == 10 and not m3.upper.visible
		and vortex != null and vortex.hframes == 8 and vortex.vframes == 4
		and vortex.texture.get_size() == Vector2(2176, 1088)
		and vortex.position == Vector2(696, 920))
	var plate_sizes := {
		XLobbyCorruption.CRACK3_TEX: Vector2(528, 528),
		XLobbyCorruption.CRACK3_GLOW_TEX: Vector2(528, 528),
		XLobbyCorruption.WALL_VEIN_TEX: Vector2(48, 96),
		XLobbyCorruption.WALL_VEIN_H_TEX: Vector2(96, 48),
		XLobbyCorruption.GATE_VEIN_TEX: Vector2(144, 96),
	}
	for path in plate_sizes:
		var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
		check("stage3.final_plate.%s" % path.get_file(), texture != null and texture.get_size() == plate_sizes[path])
	var gate: Texture2D = load(XLobbyCorruption.GATE_VEIN_TEX) if ResourceLoader.exists(XLobbyCorruption.GATE_VEIN_TEX) else null
	var aperture := gate.get_image().get_region(Rect2i(48, 0, 48, 96)) if gate != null else null
	check("stage3.final_gate_aperture", aperture != null and not aperture.get_used_rect().has_area())
	for cell in XLobbyCorruption.STAGE3_DECAY_PLANTS.slice(2):
		var blocked := not [2, 4, 6, 8].any(func(d): return m3.lower.is_passable(cell.x, cell.y, d))
		check("stage3.withered_plant_beside_wall.%s" % cell, blocked and not m3.events.any(func(e): return e.grid == cell))

	# 3.1 地面升级：10 格褪色、11×11 裂纹占位、5～7 块离地浮砖（含 (11,17) 与 (18,16)）
	check("stage3.desat_10", absf(fx3.desat_radius_cells() - 10.0) < 0.01, fx3.desat_radius_cells())
	var has_c3 := ResourceLoader.exists(XLobbyCorruption.CRACK3_TEX)
	check("stage3.crack3_ready", fx3.has_stage3_cracks() and fx3.crack3_textured() == has_c3 and (has_c3 or fx3._cracks3.size() >= 15), [fx3.has_stage3_cracks(), fx3.crack3_textured(), fx3._cracks3.size()])
	check("stage3.floats_count_fixed", fx3.floats.has(XLobbyCorruption.FIXED_FLOAT) and fx3.floats.has(XLobbyCorruption.FIXED_FLOAT_S3) \
		and fx3.floats.size() >= 5 and fx3.floats.size() <= 7, fx3.floats)
	check("stage3.floats_ok", fx3.floats.all(func(f): return _float_s3_clear(m3, fx3, f)), fx3.floats)
	# 验证近圈固定浮砖 (18,16) 抬高约 11px 且玩家踩上去平滑归零（按固定 60fps 步长测，免受无头帧率影响）
	for _i in 20:
		fx3._process(1.0 / 60.0)
	var lift_s3 := float(fx3._float_lift.get(XLobbyCorruption.FIXED_FLOAT_S3, 0.0))
	check("stage3.float_near_lift", lift_s3 >= 8.5 and lift_s3 <= 13.5, lift_s3)
	m3.player.locate(XLobbyCorruption.FIXED_FLOAT_S3.x, XLobbyCorruption.FIXED_FLOAT_S3.y)
	for _i in 90:
		fx3._process(1.0 / 60.0)
	var lift_stepped := float(fx3._float_lift.get(XLobbyCorruption.FIXED_FLOAT_S3, 99.0))
	check("stage3.float_step_flat", lift_stepped <= 0.1, lift_stepped)

	# 3.2 四角四线渗色与 50 粒光尘（36 中央 + 12 四角 + <=2 亮尘）
	check("stage3.corners_4", fx3.corner_count() == 4, fx3.corner_count())
	m3.player.locate(14, 21)
	await frames(60)
	var corner_a_ok := fx3._corner_sprites.all(func(sp): return sp.modulate.a > 0.08 and sp.modulate.a <= XLobbyCorruption.STAGE3_CORNER_ALPHA + 0.001)
	check("stage3.corners_alpha", corner_a_ok, fx3._corner_sprites.map(func(sp): return sp.modulate.a))
	check("stage3.motes_50", fx3.mote_count() >= 48 and fx3.mote_count() <= 50 and fx3.corner_mote_count() == 12, [fx3.mote_count(), fx3.corner_mote_count()])

	# 3.3 墙面与高塔之门蚀骨纹（非庆典常态：门框＋2 北隔墙＋2 西墙＋2 东墙 ＝ 7 处）
	check("stage3.wall_veins_7", fx3.wall_vein_count() == 7 and fx3.gate_vein_visible(), [fx3.wall_vein_count(), fx3.gate_vein_visible()])
	check("stage3.wall_alpha", fx3._wall_veins_node.modulate.a <= XLobbyCorruption.STAGE3_WALL_ALPHA_MAX + 0.001, fx3._wall_veins_node.modulate.a)

	# 3.8 大厅腐烂破败层（Kyo 11-23；T460 洪荒碑启用时隐藏楼梯东侧 north_table_e 与 north_candle_e → 8 家具、4 灯）
	var exp_f := 8 if XHonghuangMonument.ENABLED else 9
	var exp_l := 4 if XHonghuangMonument.ENABLED else 5
	check("stage3.decay_counts", fx3.decay_furniture_count() == exp_f and fx3.decay_plant_count() == 6 \
		and fx3.decay_mold_count() == 16 and fx3.decay_lamp_count() == exp_l \
		and fx3.decay_dim_alpha() >= XLobbyCorruption.STAGE3_DECAY_DIM_BASE - 0.005,
		[fx3.decay_furniture_count(), fx3.decay_plant_count(), fx3.decay_mold_count(), fx3.decay_lamp_count(), fx3.decay_dim_alpha()])
	fx3.trigger_decay_flicker()
	fx3._process(0.08)
	var flicker_a := fx3.decay_dim_alpha()
	check("stage3.decay_flicker", flicker_a > XLobbyCorruption.STAGE3_DECAY_DIM_BASE + 0.03, flicker_a)
	for _i in 30:
		fx3._process(1.0 / 60.0)
	check("stage3.decay_flicker_recover", absf(fx3.decay_dim_alpha() - XLobbyCorruption.STAGE3_DECAY_DIM_BASE) < 0.005, fx3.decay_dim_alpha())

	# 三阶常态实机截图（漩涡中心与南厢家具、高塔之门与北隔墙烛台红桌、西南角与西墙）
	m3.player.locate(14, 21)
	await frames(15)
	await shot("lobby_stage3_center.png")
	m3.player.locate(14, 7)
	await frames(15)
	await shot("lobby_stage3_gate.png")
	m3.player.locate(8, 21)
	await frames(15)
	await shot("lobby_stage3_sw_corner.png")

	# 4) 关「画面特效」：粒子全部清零，四角渗色保留静止极淡底色，腐烂灯光不闪烁保留静态压暗；重开恢复
	XConfig.set_flag("codexScreenFx", false)
	fx3.trigger_decay_flicker()
	await frames(3)
	var static_a_ok := fx3._corner_sprites.all(func(sp): return absf(sp.modulate.a - XLobbyCorruption.STAGE3_CORNER_ALPHA_STATIC) < 0.005)
	check("stage3.fx_off_motes_zero", fx3.mote_count() == 0 and fx3.corner_mote_count() == 0 and static_a_ok \
		and absf(fx3.decay_dim_alpha() - XLobbyCorruption.STAGE3_DECAY_DIM_BASE) < 0.005,
		[fx3.mote_count(), fx3.corner_mote_count(), static_a_ok, fx3.decay_dim_alpha()])
	XConfig.set_flag("codexScreenFx", true)
	await frames(4)
	check("stage3.fx_on_motes_back", fx3.mote_count() >= 48 and fx3.mote_count() <= 50, fx3.mote_count())

	# 5) 性能对比：阶段三 vs 阶段二 _process 单帧耗时（空闲守增幅 < 200 微秒；机器忙时按三阶/二阶比值 < 1.8 判，防高负载误红）
	var t3 := Time.get_ticks_usec()
	for _i in 600:
		fx3._process(1.0 / 60.0)
	var per3 := (Time.get_ticks_usec() - t3) / 600.0
	var diff := per3 - per2
	var ratio := per3 / maxf(per2, 1.0)
	print("[lobby_corruption] 阶段三 vs 阶段二 _process：%.1f vs %.1f 微秒/帧（增幅 %+.1f 微秒，比值 %.2fx，光尘 %d）" % [per3, per2, diff, ratio, fx3.mote_count()])
	check("stage3.perf_delta", diff < maxf(200.0, per2 * 0.8) and per3 < maxf(2000.0, per2 * 1.8), [per3, per2, diff, ratio])

	# 6) 全部贴花与腐烂 4 类热替换口验证：有图切 Sprite2D，恢复后回程序占位
	var orig_c3 := XLobbyCorruption.CRACK3_TEX
	var orig_wv := XLobbyCorruption.WALL_VEIN_TEX
	var orig_wh := XLobbyCorruption.WALL_VEIN_H_TEX
	var orig_gv := XLobbyCorruption.GATE_VEIN_TEX
	var orig_df := XLobbyCorruption.DECAY_FURNITURE_TEX
	var orig_dp := XLobbyCorruption.DECAY_PLANT_TEX
	var orig_dm := XLobbyCorruption.DECAY_MOLD_TEX
	var orig_dl := XLobbyCorruption.DECAY_LAMP_TEX
	XLobbyCorruption.CRACK3_TEX = "res://content/lobby/crack_stage2.png"
	XLobbyCorruption.WALL_VEIN_TEX = "res://content/lobby/crack_stage2.png"
	XLobbyCorruption.WALL_VEIN_H_TEX = "res://content/lobby/crack_stage2.png"
	XLobbyCorruption.GATE_VEIN_TEX = "res://content/lobby/crack_stage2.png"
	XLobbyCorruption.DECAY_FURNITURE_TEX = "res://content/lobby/crack_stage2.png"
	XLobbyCorruption.DECAY_PLANT_TEX = "res://content/lobby/crack_stage2.png"
	XLobbyCorruption.DECAY_MOLD_TEX = "res://content/lobby/crack_stage2.png"
	XLobbyCorruption.DECAY_LAMP_TEX = "res://content/lobby/crack_stage2.png"
	var swapped := XLobbyCorruption.new()
	add_child(swapped)
	swapped.setup(m3)
	var dtex := swapped.decay_textured()
	check("stage3.hot_swap_textures", swapped.crack3_textured() and swapped.wall_veins_textured() and swapped.gate_vein_textured() \
		and bool(dtex.get("furniture", false)) and bool(dtex.get("plant", false)) and bool(dtex.get("mold", false)) and bool(dtex.get("lamp", false)),
		[swapped.crack3_textured(), swapped.wall_veins_textured(), swapped.gate_vein_textured(), dtex])
	swapped.queue_free()
	XLobbyCorruption.CRACK3_TEX = orig_c3
	XLobbyCorruption.WALL_VEIN_TEX = orig_wv
	XLobbyCorruption.WALL_VEIN_H_TEX = orig_wh
	XLobbyCorruption.GATE_VEIN_TEX = orig_gv
	XLobbyCorruption.DECAY_FURNITURE_TEX = orig_df
	XLobbyCorruption.DECAY_PLANT_TEX = orig_dp
	XLobbyCorruption.DECAY_MOLD_TEX = orig_dm
	XLobbyCorruption.DECAY_LAMP_TEX = orig_dl
	await close(m3)

	# 7) 庆典兼容：XFestLobby.decor() 为真时高塔之门纹＋中央红桌椅/双烛台腐烂自动隐藏，浮砖避开庆典格；结束后恢复
	XFest.TODAY_OVERRIDE = "2026-11-20"
	XFestLobby.reload_map()
	var m_fest := await open_lobby(3, 14, 7)
	var fx_fest := m_fest.lobby_fx
	check("stage3.fest_gate_hidden", XFestLobby.decor() and fx_fest != null and not fx_fest.gate_vein_visible() and fx_fest.wall_vein_count() == 6 \
		and fx_fest.decay_furniture_count() == exp_f - 2 and fx_fest.decay_lamp_count() == exp_l - 2,
		[XFestLobby.decor(), fx_fest.gate_vein_visible() if fx_fest else null, fx_fest.wall_vein_count() if fx_fest else -1, fx_fest.decay_furniture_count() if fx_fest else -1, fx_fest.decay_lamp_count() if fx_fest else -1])
	check("stage3.fest_floats_avoid", fx_fest != null and fx_fest.floats.all(func(f): return _float_s3_clear(m_fest, fx_fest, f)), fx_fest.floats if fx_fest else [])
	var olf := fx_fest._event_by_id(1)
	check("stage3.fest_olf_outside", olf.grid == Vector2i(17, 5) and olf.self_modulate == Color.WHITE and not fx_fest._npc_fx.has(olf.get_instance_id()), olf.grid)
	for cell in [XLobbyCorruption.STAGE3_INVEST_CELL, XLobbyCorruption.FIXED_FLOAT_S3]:
		check("stage3.fest_investigation_clear.%s" % cell, not m_fest.events.any(func(e): return e.grid == cell))
	await frames(15)
	var fest_backdrop := fx_fest.get_node_or_null("Stage3Backdrop") as Sprite2D
	check("stage3.final_fest_backdrop", fest_backdrop != null and fest_backdrop.texture.resource_path.ends_with("_fest.png"))
	await shot("lobby_stage3_fest_gate.png")
	XFest.TODAY_OVERRIDE = "2026-12-20"
	await frames(2)
	check("stage3.final_regular_backdrop", fest_backdrop != null and fest_backdrop.texture.resource_path.ends_with("_backdrop.png"))
	check("stage3.fest_gate_restored", not XFestLobby.decor() and fx_fest.gate_vein_visible() and fx_fest.wall_vein_count() == 7 \
		and fx_fest.decay_furniture_count() == exp_f and fx_fest.decay_lamp_count() == exp_l,
		[XFestLobby.decor(), fx_fest.gate_vein_visible(), fx_fest.wall_vein_count(), fx_fest.decay_furniture_count(), fx_fest.decay_lamp_count()])
	await close(m_fest)
	XFestLobby.reload_map()

	# 8) 5 个视觉开关（总闸＋4 子开关含 STAGE3_DECAY）各自置 false 精确退回对应表现
	XLobbyCorruption.STAGE3_ENABLED = false
	var m_off := await open_lobby(3)
	var fx_off := m_off.lobby_fx
	await frames(20)
	m_off.player.locate(14, 21)
	await frames(15)
	await shot("lobby_stage3_off.png")
	check("stage3.off_all", fx_off != null and not fx_off.stage3_on() and absf(fx_off.desat_radius_cells() - 6.0) < 0.01 \
		and not fx_off.has_stage3_cracks() and fx_off.floats.has(XLobbyCorruption.FIXED_FLOAT) and fx_off.floats.size() >= 2 and fx_off.floats.size() <= 3 \
		and fx_off.corner_count() == 0 and fx_off.wall_vein_count() == 0 and fx_off.mote_count() <= 30 and fx_off.corner_mote_count() == 0 \
		and fx_off.decay_furniture_count() == 0 and fx_off.decay_plant_count() == 0 and fx_off.decay_mold_count() == 0 and fx_off.decay_lamp_count() == 0 and fx_off.decay_dim_alpha() == 0.0,
		[fx_off.stage3_on(), fx_off.desat_radius_cells(), fx_off.has_stage3_cracks(), fx_off.floats, fx_off.corner_count(), fx_off.wall_vein_count(), fx_off.decay_furniture_count(), fx_off.mote_count()])
	await close(m_off)
	XLobbyCorruption.STAGE3_ENABLED = true

	XLobbyCorruption.STAGE3_GROUND = false
	var m_ng := await open_lobby(3)
	var fx_ng := m_ng.lobby_fx
	await frames(10)
	check("stage3.off_ground", fx_ng != null and absf(fx_ng.desat_radius_cells() - 6.0) < 0.01 and not fx_ng.has_stage3_cracks() \
		and fx_ng.floats.has(XLobbyCorruption.FIXED_FLOAT) and fx_ng.floats.size() >= 2 and fx_ng.floats.size() <= 3 \
		and fx_ng.corner_count() == 4 and fx_ng.wall_vein_count() == 7 and fx_ng.decay_furniture_count() == exp_f,
		[fx_ng.desat_radius_cells(), fx_ng.has_stage3_cracks(), fx_ng.floats, fx_ng.corner_count(), fx_ng.wall_vein_count(), fx_ng.decay_furniture_count()])
	await close(m_ng)
	XLobbyCorruption.STAGE3_GROUND = true

	XLobbyCorruption.STAGE3_FOUR_COLORS = false
	var m_nc := await open_lobby(3)
	var fx_nc := m_nc.lobby_fx
	await frames(15)
	check("stage3.off_four_colors", fx_nc != null and fx_nc.corner_count() == 0 and fx_nc.mote_count() <= 30 and fx_nc.corner_mote_count() == 0 \
		and absf(fx_nc.desat_radius_cells() - 10.0) < 0.01 and fx_nc.has_stage3_cracks() and fx_nc.wall_vein_count() == 7 and fx_nc.decay_furniture_count() == exp_f,
		[fx_nc.corner_count(), fx_nc.mote_count(), fx_nc.corner_mote_count(), fx_nc.desat_radius_cells(), fx_nc.wall_vein_count(), fx_nc.decay_furniture_count()])
	await close(m_nc)
	XLobbyCorruption.STAGE3_FOUR_COLORS = true

	XLobbyCorruption.STAGE3_WALL_VEINS = false
	var m_nw := await open_lobby(3)
	var fx_nw := m_nw.lobby_fx
	await frames(10)
	check("stage3.off_wall_veins", fx_nw != null and fx_nw.wall_vein_count() == 0 and not fx_nw.gate_vein_visible() \
		and absf(fx_nw.desat_radius_cells() - 10.0) < 0.01 and fx_nw.has_stage3_cracks() and fx_nw.corner_count() == 4 and fx_nw.decay_furniture_count() == exp_f,
		[fx_nw.wall_vein_count(), fx_nw.gate_vein_visible(), fx_nw.desat_radius_cells(), fx_nw.corner_count(), fx_nw.decay_furniture_count()])
	await close(m_nw)
	XLobbyCorruption.STAGE3_WALL_VEINS = true

	XLobbyCorruption.STAGE3_DECAY = false
	var m_nd := await open_lobby(3)
	var fx_nd := m_nd.lobby_fx
	await frames(15)
	m_nd.player.locate(14, 21)
	await frames(15)
	await shot("lobby_stage3_decay_off.png")
	m_nd.player.locate(14, 7)
	await frames(15)
	await shot("lobby_stage3_decay_off_gate.png")
	check("stage3.off_decay", fx_nd != null and fx_nd.decay_furniture_count() == 0 and fx_nd.decay_plant_count() == 0 \
		and fx_nd.decay_mold_count() == 0 and fx_nd.decay_lamp_count() == 0 and fx_nd.decay_dim_alpha() == 0.0 \
		and absf(fx_nd.desat_radius_cells() - 10.0) < 0.01 and fx_nd.has_stage3_cracks() and fx_nd.corner_count() == 4 and fx_nd.wall_vein_count() == 7,
		[fx_nd.decay_furniture_count(), fx_nd.decay_plant_count(), fx_nd.decay_mold_count(), fx_nd.decay_lamp_count(), fx_nd.decay_dim_alpha()])
	await close(m_nd)
	XLobbyCorruption.STAGE3_DECAY = true


func _test_stage3_interactions(original: Dictionary) -> void:
	(XConfig._values.codexWhisperSeen as Array).erase("rift3")
	var before_rift := await open_lobby(3, 14, 22, false, {XLobbyCorruption.FLAG_KEY: {"said": [], "crack": 2}})
	check("stage3.crack_waits_for_rift", await act(before_rift, XLobbyCorruption.CRACK_CELL, 2) == [XLobbyCorruption.CRACK_TEXTS[1]] \
		and not XState.current.flags[XLobbyCorruption.FLAG_KEY].has("s3_crack"))
	await close(before_rift)
	XConfig.whisper_mark("rift3")

	var map := await open_lobby(3, 14, 21)
	var fx := map.lobby_fx
	var olf := fx._event_by_id(1)
	var debt := fx._event_by_id(50)
	var artisan := fx._event_by_id(7)
	var chest := fx._event_by_id(67)
	var purple := XLobbyCorruption.PURPLE
	check("stage3.tint_near_party", map.player.self_modulate.is_equal_approx(Color.WHITE.lerp(purple, 0.25)) \
		and map.followers.all(func(f): return f.self_modulate.is_equal_approx(Color.WHITE.lerp(purple, 0.25))))
	map.player.locate(14, 23)
	await frames(2)
	check("stage3.tint_fade", map.player.self_modulate.is_equal_approx(Color.WHITE.lerp(purple, 0.25 / 3.0)))
	map.player.locate(14, 24)
	await frames(2)
	check("stage3.tint_radius", map.player.self_modulate == Color.WHITE)
	check("stage3.npc_realtime_and_exclusions", fx._npc_fx.has(olf.get_instance_id()) \
		and fx._npc_fx.has(artisan.get_instance_id()) and fx._npc_fx.has(debt.get_instance_id()) \
		and fx._event_by_id(75).self_modulate == Color.WHITE and chest.self_modulate == Color.WHITE and not fx._npc_fx.has(chest.get_instance_id()))
	olf.locate(17, 5)
	fx._next_npc_refresh = fx._t
	fx._update_tint()
	check("stage3.npc_leaves_range", olf.self_modulate == Color.WHITE and not fx._npc_fx.has(olf.get_instance_id()))
	olf.locate(14, 10)
	fx._next_npc_refresh = fx._t
	fx._update_tint()
	check("stage3.npc_returns_to_range", olf.self_modulate != Color.WHITE and fx._npc_fx.has(olf.get_instance_id()))
	check("stage3.debt_render_only", debt.grid == Vector2i(14, 13) and debt.real == Vector2(14, 13) and debt.frames_offset.y == -5.0)
	fx._next_wall_tremor = fx._t
	fx._next_npc_refresh = fx._t
	fx._update_tint()
	check("stage3.wall_render_only", artisan.grid == Vector2i(4, 17) and artisan.real == Vector2(4, 17) and artisan.frames_offset.y == -1.0)
	fx._wall_tremor_until = 0.0
	fx._next_npc_refresh = fx._t
	fx._update_tint()
	check("stage3.wall_offset_restored", artisan.frames_offset.y == 0.0)
	check("stage3.stump_shadow", is_instance_valid(fx._stump_shadow) and is_equal_approx(fx._stump_shadow.self_modulate.a, 0.28) \
		and fx._stump_shadow.position.x > 0.0 and fx._stump_shadow.position.y < 0.0)
	fx._next_bubble = 0.0
	fx._update_bubbles(0.0)
	check("stage3.bubble_interval", fx._next_bubble >= 50.0 and fx._next_bubble <= 95.0)
	map.player.locate(14, 17)
	await frames(15)
	await shot("stage3_npc.png")

	var ghost_seen := {}
	map.busy_changed.connect(func(busy: bool):
		if busy and is_instance_valid(fx._dialogue_ghost):
			var ghost := fx._dialogue_ghost
			var speaker := fx._event_by_id(fx._ghost_speaker_id)
			ghost_seen[fx._ghost_speaker_id] = is_instance_valid(speaker) and is_equal_approx(ghost.modulate.a, 0.32) \
				and is_equal_approx(ghost.position.x - speaker.position.x, 3.0) and ghost.texture == speaker._tex)
	for id in STAGE3_ACTIONS:
		var base: Array = original[id]
		var got := await act(map, Vector2i.ZERO, 2, id)
		if id == 21:
			check("stage3.mirror.stage2_first", got.size() == base.size() + 1 and got.slice(0, base.size()) == base \
				and str(got.back()) == XLobbyCorruption.AFTER_LINES[21][3] and not is_instance_valid(fx._mirror_ghost), got)
			_check_mirror_frame(fx)
			got = await act(map, Vector2i.ZERO, 2, id)
		check("stage3.dialogue.%d.original_then_extra" % id, not base.is_empty() and got.slice(0, base.size()) == base \
			and got.size() == base.size() + 1 and str(got.back()).ends_with(XLobbyCorruption.STAGE3_AFTER_LINES[id][3]), [base, got])
		check("stage3.dialogue.%d.once" % id, await act(map, Vector2i.ZERO, 2, id) == base)
	check("stage3.ghost.only_while_speaking", ghost_seen == {40: true, 17: true} and not is_instance_valid(fx._dialogue_ghost), ghost_seen)
	await get_tree().create_timer(0.65).timeout
	check("stage3.mirror.fade_clears", not is_instance_valid(fx._mirror_ghost))
	var record := XLobbyCorruption.record(XState.current)
	check("stage3.old_record_defaults", not record.has("s3_crack"))
	var c1 := await act(map, XLobbyCorruption.CRACK_CELL, 2)
	var c2 := await act(map, XLobbyCorruption.CRACK_CELL, 2)
	var c3 := await act(map, XLobbyCorruption.CRACK_CELL, 2)
	check("stage3.crack_sequence", c1 == [XLobbyCorruption.CRACK_TEXTS[0]] and c2 == [XLobbyCorruption.CRACK_TEXTS[1]] \
		and c3 == [XLobbyCorruption.STAGE3_CRACK_TEXT] and record.crack == 2 and record.s3_crack and is_instance_valid(fx._crack_scorch), [c1, c2, c3])
	check("stage3.crack_once", await act(map, XLobbyCorruption.CRACK_CELL, 2) == [XLobbyCorruption.CRACK_TEXTS[1]])
	var drop := XLobbyCorruption.drop_cell()
	check("stage3.scale_swallowed", XLobbyCorruption.canglong_dropped() and fx.scale_cell() == Vector2i(-1, -1) \
		and not fx._scale_node.visible and not fx.is_investigation(drop) and (await act(map, drop, 2)).is_empty())
	var west_float := XLobbyCorruption.FIXED_FLOAT
	check("stage3.west_float_only_visual", fx.floats.has(west_float) and not fx.is_investigation(west_float) \
		and (await act(map, west_float, 2)).is_empty())
	var investigations := {XLobbyCorruption.STAGE3_INVEST_CELL: XLobbyCorruption.STAGE3_WALL_TEXT, XLobbyCorruption.FIXED_FLOAT_S3: XLobbyCorruption.STAGE3_FLOAT_TEXT}
	for cell in investigations:
		var pass4 := [2, 4, 6, 8].all(func(dir): return map.lower.is_passable(cell.x, cell.y, dir))
		var clear := not map.events.any(func(e): return e.grid == cell)
		check("stage3.investigation.%s" % str(cell), pass4 and clear and await act(map, cell, 2) == [investigations[cell]])
	var restored := XState.from_dict(JSON.parse_string(JSON.stringify(XState.current.to_dict())))
	var back := XLobbyCorruption.record(restored)
	check("stage3.persist_all", back.s3_crack and back.said.has("21") and not back.said.has("7") \
		and STAGE3_ACTIONS.keys().all(func(id): return back.said.has("s3:%d" % id)), back)
	var artisan_instance := artisan.get_instance_id()
	map.events.erase(artisan)
	artisan.queue_free()
	await frames(2)
	fx._next_npc_refresh = fx._t
	fx._update_tint()
	check("stage3.released_event_cleared", not is_instance_valid(artisan) and not fx._npc_fx.has(artisan_instance) and not fx._npc_y_offsets.has(artisan_instance))
	fx.queue_free()
	await frames(2)
	check("stage3.exit_restores_rendering", map.player.self_modulate == Color.WHITE and olf.self_modulate == Color.WHITE \
		and debt.self_modulate == Color.WHITE and debt.frames_offset.y == 0.0 and not is_instance_valid(fx) \
		and not debt.get_children().any(func(n): return n is Sprite2D))
	await close(map)
	map = await open_lobby(3)
	fx = map.lobby_fx
	map.load_map(5, 11, 13, 2)
	await frames(3)
	check("stage3.transfer_frees_fx_and_events", map.map_id == 5 and map.lobby_fx == null and not is_instance_valid(fx))
	await close(map)
	await _test_stage3_interaction_switches()
	await _test_stage3_tianqi_source()


func _check_mirror_frame(fx: XLobbyCorruption) -> void:
	for i in TIMEOUT_FRAMES:
		await frames(1)
		if not is_instance_valid(fx):
			return
		if fx._mirror_pending:
			break
	var ghost := fx._mirror_ghost
	check("stage3.mirror.at_mirror_before_line", is_instance_valid(ghost) and not fx.host.busy \
		and ghost.position.distance_to(XLobbyCorruption.cell_px(Vector2i(9, 26))) < 5.0 \
		and ghost.texture == fx.host.player._tex and ghost.modulate.a > 0.0)
	await shot("stage3_mirror.png")


func _test_stage3_interaction_switches() -> void:
	XLobbyCorruption.STAGE3_NPC_FX = false
	var map := await open_lobby(3, 14, 21)
	var fx := map.lobby_fx
	XLobbyCorruption.STAGE3_NPC_FX = true  # 只随进图取值
	fx._next_bubble = 0.0
	fx._update_bubbles(0.0)
	var ghost_seen := [false]
	map.busy_changed.connect(func(busy: bool):
		if busy and is_instance_valid(fx._dialogue_ghost):
			ghost_seen[0] = true)
	var talk := await act(map, Vector2i.ZERO, 2, 40)
	check("stage3.switch_npc_fx", not ghost_seen[0] and not talk.is_empty() and str(talk.back()).ends_with(XLobbyCorruption.STAGE3_AFTER_LINES[40][3]) \
		and fx._npc_fx.is_empty() and fx._next_bubble >= 60.0 and fx._next_bubble <= 120.0)
	map.player.locate(14, 21)
	await frames(2)
	check("stage3.switch_party_tint", map.player.self_modulate.is_equal_approx(Color.WHITE.lerp(XLobbyCorruption.PURPLE, 0.05)))
	await close(map)

	XLobbyCorruption.STAGE3_NPC_LINES = false
	map = await open_lobby(3)
	talk = await act(map, Vector2i.ZERO, 2, 7)
	check("stage3.switch_npc_lines", str(talk.back()).ends_with(XLobbyCorruption.AFTER_LINES[7][3]) \
		and XLobbyCorruption.record(XState.current).said == ["7"] and not map.lobby_fx._npc_fx.is_empty())
	await close(map)
	XLobbyCorruption.STAGE3_NPC_LINES = true

	XLobbyCorruption.STAGE3_MIRROR = false
	map = await open_lobby(3)
	talk = await act(map, Vector2i.ZERO, 2, 21)
	var mirror := map.lobby_fx._event_by_id(21)
	check("stage3.switch_mirror", str(talk.back()) == XLobbyCorruption.AFTER_LINES[21][3] and not map.lobby_fx.wants_after(mirror) \
		and not is_instance_valid(map.lobby_fx._mirror_ghost) and XLobbyCorruption.record(XState.current).said == ["21"])
	await close(map)
	XLobbyCorruption.STAGE3_MIRROR = true

	XLobbyCorruption.STAGE3_STUMP = false
	map = await open_lobby(3)
	check("stage3.switch_stump", not is_instance_valid(map.lobby_fx._stump_shadow) and not map.lobby_fx.wants_after(map.lobby_fx._event_by_id(25)))
	await close(map)
	XLobbyCorruption.STAGE3_STUMP = true

	XLobbyCorruption.STAGE3_INVESTIGATIONS = false
	map = await open_lobby(3, 14, 22, false, {XLobbyCorruption.FLAG_KEY: {"crack": 2}})
	fx = map.lobby_fx
	check("stage3.switch_investigations", not is_instance_valid(fx._crack_scorch) and not fx.is_investigation(XLobbyCorruption.STAGE3_INVEST_CELL) \
		and not fx.is_investigation(XLobbyCorruption.FIXED_FLOAT_S3) and fx.is_investigation(XLobbyCorruption.FIXED_FLOAT) \
		and await act(map, XLobbyCorruption.CRACK_CELL, 2) == [XLobbyCorruption.CRACK_TEXTS[1]] and not XLobbyCorruption.record(XState.current).has("s3_crack"))
	var drop := XLobbyCorruption.drop_cell()
	check("stage3.switch_restores_stage2_props", fx.scale_cell() == drop and fx._scale_node.visible \
		and fx.is_investigation(drop) and await act(map, drop, 2) == [XLobbyCorruption.SCALE_TEXT] \
		and await act(map, XLobbyCorruption.FIXED_FLOAT, 2) == [XLobbyCorruption.FLOAT_TEXT])
	await close(map)
	XLobbyCorruption.STAGE3_INVESTIGATIONS = true


func _test_stage3_tianqi_source() -> void:
	var map := await open_lobby(3, 14, 6, true)
	var fx := map.lobby_fx
	var s := XState.current
	# 选商店向导的符文图鉴，从 XTianqiHall.run_host 实际代调 EV40 的 after_event。
	var opts := XTianqiHall.menu(map, s, 73)
	var index := opts.find_custom(func(opt): return opt[1] == ["src", 40])
	if check("stage3.tianqi_source_menu_has_40", index >= 0, opts):
		XMessageBox.transcript.clear()
		XMessageBox.auto_answers = [index, 1]
		await XTianqiHall.run_host(map, s, fx._event_by_id(73))
		check("stage3.tianqi_source_exercised", XMessageBox.transcript.has("选择：" + XTianqiHall.LABELS[40]), XMessageBox.transcript)
		check("stage3.tianqi_source_no_s3", not XMessageBox.transcript.any(func(line): return str(line).ends_with(XLobbyCorruption.STAGE3_AFTER_LINES[40][3])) \
			and not is_instance_valid(fx._dialogue_ghost) and not s.flags.has(XLobbyCorruption.FLAG_KEY))
	var npc := fx._event_by_id(14)
	check("stage3.tianqi_wants_guard", npc != null and not fx.wants_after(npc))
	check("stage3.tianqi_crack_stays_stage2", await act(map, XLobbyCorruption.CRACK_CELL, 2) == [XLobbyCorruption.CRACK_TEXTS[0]] \
		and not fx.is_investigation(XLobbyCorruption.STAGE3_INVEST_CELL) and not s.flags.has(XLobbyCorruption.FLAG_KEY))
	await close(map)


func _float_clear(f: Vector2i) -> bool:
	return not XLobbyCorruption.VORTEX_CELLS.has(f) and absi(f.x - 14) > 2 and absi(f.y - 19) > 1 \
		and f != XLobbyCorruption.CRACK_CELL and f != XLobbyCorruption.drop_cell()


func _float_s3_clear(map: XMapScene, fx: XLobbyCorruption, f: Vector2i) -> bool:
	var fest_cells := [Vector2i(12, 10), Vector2i(14, 10), Vector2i(15, 10), Vector2i(16, 10)]
	var pass4 := [2, 4, 6, 8].all(func(dir): return map.lower.is_passable(f.x, f.y, dir))
	return _float_clear(f) and f != XLobbyCorruption.STAGE3_INVEST_CELL and not fest_cells.has(f) and pass4 and fx.float_ok(f)


func _finish() -> void:
	XLobbyCorruption.STAGE_OVERRIDE = 0
	XLobbyCorruption.ENABLED = true
	XLobbyCorruption.STAGE3_ENABLED = true
	XLobbyCorruption.STAGE3_GROUND = true
	XLobbyCorruption.STAGE3_FOUR_COLORS = true
	XLobbyCorruption.STAGE3_WALL_VEINS = true
	XLobbyCorruption.STAGE3_DECAY = true
	XFest.TODAY_OVERRIDE = ""
	XFestLobby.reload_map()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
