extends Node
## 设置页核心杂项开关（只遇稀有/罕见/极其稀有、穿墙、三条宣传行、对话跳过、禁用遇敌、步步遇敌）：
## 对照正式 options_probe 的 misc（状态文字、开关操作、存取、对话标志、通行、304 次遇敌抽签、步数值、禁用遇敌），
## 另测对话框整页立即显示与对话跳过的实际关闭、地图上穿墙与禁用遇敌。
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func physics(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func set_value(sym: String, v) -> void:
	if sym == "cq":
		XConfig.set_flag("cq", v == true)
	else:
		XConfig.set_session(sym, v)


func raw_value(sym: String):
	return XConfig.flag("cq") if sym == "cq" else XConfig.session_value(sym)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_options_misc"
	XConfig.path_override = XSave.dir().path_join("options.json")
	DirAccess.make_dir_recursive_absolute(XSave.dir())
	DirAccess.remove_absolute(XConfig.path())
	XConfig._loaded_path = "<unloaded>"
	XConfig._session.clear()
	var ref = XDB.load_json("oracle/options.json")
	if not (ref is Dictionary and ref.has("misc")):
		check("oracle_present", false)
		return finish()
	var ms: Dictionary = ref.misc
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs and ref.sourceIdentity.releaseVersion == manifest.releaseVersion)
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s

	# 设置页：初始状态文字与开关操作
	var opt := XOptionsScene.new()
	add_child(opt)
	await physics(2)
	for row in ms.rows:
		var i := opt.symbols().find(row.symbol)
		var want: String = "" if row.status == null else str(row.status)
		check("row_" + row.symbol, i >= 0 and opt._list[i][2] and opt.status_text(i) == want, opt.status_text(i))
	var ops_ok := true
	for row in ms.ops:
		var sym: String = row.symbol
		set_value(sym, row.initial)
		opt.index = opt.symbols().find(sym)
		match row.op:
			"processOk": opt.ok()
			"cursorRight": opt._side(true)
			"cursorLeft": opt._side(false)
		if raw_value(sym) != row.value or opt.status_text(opt.index) != row.status:
			ops_ok = false
			check("op_%s_%s_%s" % [sym, row.initial, row.op], false, [raw_value(sym), opt.status_text(opt.index)])
	check("ops_all", ops_ok)
	# 未设置时按左键也算改变并播光标音（!== 比较）
	XConfig.set_session("ydgb", null)
	opt.index = opt.symbols().find("ydgb")
	XSound.system_log.clear()
	opt._side(false)
	check("null_to_off_sounds", XConfig.session_value("ydgb") == false and XSound.system_log == [0], XSound.system_log)
	opt.queue_free()

	# 存取：只有穿墙写进配置；其余重读配置后仍是本次运行的值、不入文件
	for sym in XConfig.SESSION_FLAGS:
		XConfig.set_session(sym, true)
	XConfig.set_flag("cq", true)
	var data = JSON.parse_string(FileAccess.get_file_as_string(XConfig.path()))
	var saved: Array = XConfig.SESSION_FLAGS.filter(func(k): return data.has(k)) + (["cq"] if data.has("cq") else [])
	check("persist_saved", saved == ms.persist.saved, saved)
	XConfig._loaded_path = "<unloaded>"
	check("persist_cq_reload", XConfig.flag("cq") == ms.persist.applied.cq)
	check("session_survives_reload", XConfig.SESSION_FLAGS.all(func(k): return XConfig.flag(k)))
	var f := FileAccess.open(XConfig.path(), FileAccess.WRITE)
	f.store_string(JSON.stringify({"cq": 1}))
	f.close()
	XConfig._loaded_path = "<unloaded>"
	check("cq_truthy", XConfig.flag("cq") == ms.persist.cqTruthy)
	XConfig._session.clear()
	XConfig.set_flag("cq", false)

	# 通行
	for row in ms.passable:
		XConfig.set_flag("cq", row.cq)
		check("passable_%s_%s" % [row.cq, row.open], (row.open or XConfig.flag("cq")) == row.passable)
	XConfig.set_flag("cq", false)

	# 遇敌抽签、步数值
	var troops_ok := true
	for row in ms.troops:
		for k in row.flags:
			XConfig.set_session(k, row.flags[k])
		var list: Array = []
		for i in row.weights.size():
			list.append({"troopId": i + 1, "weight": row.weights[i], "regionSet": []})
		var got := XMapScene.encounter_troop(list, int(row.random))
		if got != int(row.troop):
			troops_ok = false
			check("troop_%s_%s_%d" % [row.weights, row.flags, int(row.random)], false, got)
	check("troops_all_%d" % ms.troops.size(), troops_ok)
	XConfig._session.clear()
	for row in ms.progress:
		XConfig.set_session("yd100", true if row.yd100 else null)
		check("progress_%s_%s" % [row.yd100, row.bush], XMapScene.encounter_progress_value(row.bush) == float(row.value))
	XConfig._session.clear()

	# 对话框：整页一帧画完；对话跳过时文字结束直接关闭，标志照 clearFlags
	for row in ms.message:
		XConfig.set_session("dhtg", row.dhtg)
		var box := XMessageBox.new()
		add_child(box)
		await physics(1)
		var r := [null]
		var go = func(): r[0] = await box.run({"lines": ["测试文字一行。"]})
		go.call()
		await physics(12)
		check("msg_flags_%s" % row.dhtg, box._show_fast == row.showFast and box._line_fast == row.lineShowFast and box._pause_skip == row.pauseSkip,
			[box._show_fast, box._line_fast, box._pause_skip])
		await physics(30)
		if row.pauseSkip:
			check("msg_auto_close_%s" % row.dhtg, r[0] == 0, r[0])
		else:
			check("msg_waits_%s" % row.dhtg, r[0] == null and box.win.pause, [r[0], box.win.pause])
		box.queue_free()
		await physics(1)
	XConfig._session.clear()

	# 地图：穿墙与禁用遇敌
	s.map_id = 5
	var map := XMapScene.new()
	add_child(map)
	await physics(4)
	await map.load_map(5, 11, 13, 2)
	await physics(2)
	var blocked := Vector3i(-1, -1, 0)
	for y in map.lower.height:
		for x in map.lower.width:
			for d in [2, 4, 6, 8]:
				if blocked.x < 0 and not map.lower.is_passable(x, y, d):
					blocked = Vector3i(x, y, d)
	XConfig.set_flag("cq", true)
	check("map_cq_passes", blocked.x >= 0 and map.lower.is_passable(blocked.x, blocked.y, blocked.z) and not map.lower.is_passable(-1, 0, 2), blocked)
	XConfig.set_flag("cq", false)
	check("map_cq_off_blocks", not map.lower.is_passable(blocked.x, blocked.y, blocked.z))
	XConfig.set_session("ydgb", true)
	map.encounter_count = 0
	await map._encounter()
	check("ydgb_no_battle", not map._in_battle and not map.busy and map.encounter_count > 0, [map._in_battle, map.encounter_count])
	XConfig._session.clear()
	map.queue_free()
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
