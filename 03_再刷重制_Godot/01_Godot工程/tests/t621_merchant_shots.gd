extends Node
## 工具（不是专项）：T621 深渊商人站位截图。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t621_merchant_shots.tscn -- --out=<目录> [--maps=37,174] [--before]
## 每张商人路线图：本轮记成「已领点、商人出现」，人站商人右下一格，拍商人那一片（--before＝MOVE_STUCK 关，拍原版站位）；打印商人格与四邻能不能站（游戏自己的通行判断）。
var out_dir := ""
var only := []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		if arg == "--before":
			XAbyssMerchant.MOVE_STUCK = false
		if arg.begins_with("--maps="):
			only = Array(arg.substr(7).split(",")).map(func(v): return int(v))
	_run.call_deferred()


func _frames(n := 20) -> void:
	for i in range(n):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	img.resize(800, 450, Image.INTERPOLATE_LANCZOS)
	img.save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _boss(md: Dictionary) -> Vector2i:
	for ev in md.events:
		if ev != null and JSON.stringify(ev.pages).contains("[1439]"):
			return Vector2i(int(ev.x), int(ev.y))
	for ev in md.events:
		if ev != null and JSON.stringify(ev.pages).contains("\"code\":301"):
			return Vector2i(int(ev.x), int(ev.y))
	return Vector2i(-1, -1)


func _map(id: int, ev_id: int) -> void:
	var md := XDB.map(id)
	if md.is_empty():
		print("SKIP map ", id, " 不在切片")
		return
	var b := _boss(md)
	var s := XState.new_game_blank()
	s.map_id = id
	# 人站商人右下一格（镜头对着商人那一片）；商人位置照 MOVE_STUCK 现取
	var mev: Dictionary = {}
	for ev in md.events:
		if ev != null and int(ev.id) == ev_id:
			mev = ev
	var fp := XAbyssMerchant.fixed_pos(id, mev)
	var mp := fp if fp.x >= 0 else Vector2i(int(mev.x), int(mev.y))
	s.x = mp.x + 1
	s.y = mp.y + 1
	s.flags[XAbyssMerchant.RUN_FLAG] = {"sequence": 1, "claimed": true, "appeared": true, "used": 0, "seed": 1,
		"identity": {"key": "x", "kind": "深渊商人", "map": id}}
	XState.current = s
	var map := XMapScene.new()
	add_child(map)
	for _f in 300:
		await get_tree().process_frame
		if map.player != null and map.map_id == id and not map.busy:
			break
	await _frames(30)
	for n in XAchievementPopup._stack:
		if is_instance_valid(n):
			n.visible = false
	var mer = null
	for e in map.events:
		if e.event_id == ev_id:
			mer = e
	var p: Vector2i = mer.grid
	var faces := []
	for d in [[2, Vector2i(0, 1)], [4, Vector2i(-1, 0)], [6, Vector2i(1, 0)], [8, Vector2i(0, -1)]]:
		var n: Vector2i = p + d[1]
		if map.lower.check_passage(n.x, n.y, 0x0f):
			faces.append(d[0])
	print("MER map=%d ev=%d pos=%s page=%d own_pass=%s stand_faces=%s boss=%s" % [id, ev_id, p, mer.page_index, map.lower.check_passage(p.x, p.y, 0x0f), faces, b])
	await _shot("t621_map%03d_%s" % [id, "after" if XAbyssMerchant.MOVE_STUCK else "before"])
	map.queue_free()
	await _frames(10)


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	print("XTestMode.enabled=", XTestMode.enabled())
	var path := "user://t621_merchant_shots.json"
	XConfig.path_override = path
	for k in ["rift1", "rift2", "rift3"]:
		XConfig.whisper_mark(k)
	for me in XDB.table("CodexMerchants").merchantEvents:
		if only.is_empty() or only.has(int(me.map)):
			await _map(int(me.map), int(me.event))
	XConfig.path_override = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	get_tree().quit.call_deferred(0)
