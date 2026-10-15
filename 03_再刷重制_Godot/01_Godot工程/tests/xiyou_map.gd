extends Node2D
## 地图对照测试：通行判定与正式版的 Game_Map.isPassable 逐格逐方向比较，循环地图另比循环方向与越过边缘的一步
## （oracle 由 03_转换工具/mv_oracle/map_probe.cjs 生成）。窗口模式加 -- --out=<目录> 时另存每张地图的整图截图。

var results: Array = []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	var oracle = JSON.parse_string(FileAccess.get_file_as_string("res://modes/xiyou/generated/oracle/maps.json"))
	if not oracle is Dictionary:
		_check("oracle_present", false, "先运行 mv_oracle/map_probe.cjs")
		return _finish()
	for id_s in oracle:
		var map := XDB.map(int(id_s))
		var lower := MVTilemap.new()
		var upper := MVTilemap.new()
		add_child(lower)
		add_child(upper)
		lower.setup(map, false)
		upper.setup(map, true)
		var rows: Array = oracle[id_s].passable
		var wrong := []
		for y in range(rows.size()):
			for x in range(str(rows[y]).length()):
				var expect := ("0x" + str(rows[y])[x]).hex_to_int()
				var mine := 0
				for i in range(4):
					if lower.is_passable(x, y, [2, 4, 6, 8][i]):
						mine |= 1 << i
				if mine != expect:
					wrong.append([x, y, mine, expect])
		_check("map%s.passable" % id_s, wrong.is_empty(), wrong.slice(0, 8))
		# 循环地图：循环方向与越过边缘的那一步（正式版只有十四层 Map030 横向循环）
		var loop: Array = oracle[id_s].get("loop", [false, false])
		_check("map%s.loop" % id_s, [lower.loop_x, lower.loop_y] == loop, [[lower.loop_x, lower.loop_y], loop])
		for key in ["wrapLeft", "wrapUp"]:
			if not oracle[id_s].has(key):
				continue
			var mine := ""
			for i in range(lower.height if key == "wrapLeft" else lower.width):
				var at := Vector2i(0, i) if key == "wrapLeft" else Vector2i(i, 0)
				var d := 4 if key == "wrapLeft" else 8
				var to := lower.round_cell(at + MVCharacter.dir_offset(d))
				mine += "1" if lower.is_valid(to) and lower.is_passable(at.x, at.y, d) and lower.is_passable(to.x, to.y, 10 - d) else "0"
			_check("map%s.%s" % [id_s, key], mine == oracle[id_s][key], [mine, oracle[id_s][key]])
		if out_dir != "" and DisplayServer.get_name() != "headless":
			var size := Vector2(lower.width, lower.height) * MVTiles.TILE_SIZE
			var scale_f := minf(get_viewport_rect().size.x / size.x, get_viewport_rect().size.y / size.y)
			lower.scale = Vector2.ONE * scale_f
			upper.scale = lower.scale
			for i in range(3):
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out_dir.path_join("map%s.png" % id_s))
		lower.queue_free()
		upper.queue_free()
		await get_tree().process_frame
	_finish()


func _finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("MISMATCH ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
