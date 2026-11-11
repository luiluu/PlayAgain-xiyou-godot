extends Node
## 【cc·大厅异化·未经审查】方桌大厅「初步异化」叠加层（XLobbyCorruption，O-待定）：
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


func open_lobby(stage: int, x := 14, y := 25) -> XMapScene:
	XLobbyCorruption.STAGE_OVERRIDE = stage
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.set_variable(206, -3000)   # 讨债人三人组只在欠积分时出来（页 2、3 条件变量 206 ≥ −2000 是空页）
	s.set_variable(20, 1)        # 大工匠第 1 页
	s.set_variable(14, 1)        # 动保协会成员
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
const ANSWERS := {50: 1, 51: 1, 7: 3, 43: 1}

func act(map: XMapScene, cell: Vector2i, dir: int, id := 0) -> Array:
	# NPC 会随机走动：站到事件当前格的正下方、面朝上
	for e in map.events:
		if id > 0 and e.event_id == id and id != 21:
			cell = e.grid + Vector2i(0, 1)
			dir = 8
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
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false

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
	check("floats.fixed", fx.floats.has(XLobbyCorruption.FIXED_FLOAT) and fx.floats.size() >= 2 and fx.floats.size() <= 3, fx.floats)
	check("floats.avoid", fx.floats.all(_float_clear), fx.floats)
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

	# 离开大厅即拆
	m2.load_map(5, 11, 13, 2)
	await frames(3)
	check("leave.freed", m2.lobby_fx == null)
	await close(m2)
	_finish()


func _float_clear(f: Vector2i) -> bool:
	return not XLobbyCorruption.VORTEX_CELLS.has(f) and absi(f.x - 14) > 2 and absi(f.y - 19) > 1 \
		and f != XLobbyCorruption.CRACK_CELL and f != XLobbyCorruption.drop_cell()


func _finish() -> void:
	XLobbyCorruption.STAGE_OVERRIDE = 0
	XLobbyCorruption.ENABLED = true
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
