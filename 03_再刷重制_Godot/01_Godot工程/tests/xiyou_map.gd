extends Node2D
## 地图对照测试：通行判定与正式 v0.04 的 Game_Map.isPassable 逐格逐方向比较
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
