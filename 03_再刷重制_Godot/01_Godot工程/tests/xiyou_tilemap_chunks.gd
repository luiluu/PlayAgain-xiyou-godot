extends Node2D
## 地图分块绘制（Codex 审查报告第 15 项）：150×150 的天之上（Map069）换水面帧时只重画画面内的水面，画面外的块不画；
## 整张平移看遍后每格恰好画一次（静态块），循环地图（十四层 Map030）连两侧多画的一屏也一样。回退开关 CHUNKED = false 两边都跑。
## 实测（无头，M1 Pro）：整张画每 30 帧卡 320～480 毫秒、画布命令约 8.5 MB；分块后最长一帧 16 毫秒以内、约 0.2～0.9 MB。
var results := []

func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))

func _ready() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _layers(id: int) -> Array:
	var data := XDB.map(id)
	var lower := MVTilemap.new()
	var upper := MVTilemap.new()
	add_child(lower)
	add_child(upper)
	lower.setup(data, false)
	upper.setup(data, true)
	return [lower, upper]

func _total(tm: MVTilemap) -> int:
	var mx := MVTilemap.LOOP_MARGIN.x if tm.loop_x else 0
	var my := MVTilemap.LOOP_MARGIN.y if tm.loop_y else 0
	return (tm.width + 2 * mx) * (tm.height + 2 * my)

## 平移把整张图（含循环两侧）都过一遍画面
func _sweep(tms: Array) -> void:
	var tm: MVTilemap = tms[0]
	var mx := MVTilemap.LOOP_MARGIN.x if tm.loop_x else 0
	var my := MVTilemap.LOOP_MARGIN.y if tm.loop_y else 0
	var vs := get_viewport_rect().size
	for y in range(-my * MVTilemap.TS, (tm.height + my) * MVTilemap.TS, int(vs.y)):
		for x in range(-mx * MVTilemap.TS, (tm.width + mx) * MVTilemap.TS, int(vs.x)):
			for t in tms:
				(t as MVTilemap).position = -Vector2(x, y)
			await frames(1)

func _run() -> void:
	if not XDB.available():
		check("skipped_no_data", true)
		return _finish()
	for chunked in [true, false]:
		MVTilemap.CHUNKED = chunked
		var tag := "chunked" if chunked else "rollback"
		var tms := _layers(69)
		var lower: MVTilemap = tms[0]
		var upper: MVTilemap = tms[1]
		await frames(3)
		check(tag + "_map069_size", lower.width == 150 and lower.height == 150 and lower._has_a1)
		var d0 := lower.drawn_cells + upper.drawn_cells
		var w0 := lower.water_cells + upper.water_cells
		await frames(31)  # 过一次换水面帧
		var redrawn := lower.drawn_cells + upper.drawn_cells - d0 + lower.water_cells + upper.water_cells - w0
		if chunked:
			# 1280×720 画面最多跨 (27/16+2)×(15/16+2) 块 = 4×3 块，每层 12×256 格
			check(tag + "_water_tick_redraws_view_only", redrawn > 0 and redrawn <= 2 * 12 * 256, redrawn)
			check(tag + "_offscreen_not_drawn", d0 <= 2 * 12 * 256, d0)
		else:
			check(tag + "_water_tick_redraws_whole_map", redrawn == 2 * 150 * 150, redrawn)
		await _sweep(tms)
		if chunked:
			check(tag + "_each_cell_drawn_once", lower.drawn_cells == _total(lower) and upper.drawn_cells == _total(upper), [lower.drawn_cells, upper.drawn_cells, _total(lower)])
		for t in tms:
			t.queue_free()
		# 循环地图：两侧多画的一屏也分块画到
		var loop := _layers(30)
		await frames(2)
		await _sweep(loop)
		check(tag + "_loop_map_covers_margin", (loop[0] as MVTilemap).loop_x and ((loop[0] as MVTilemap).drawn_cells == _total(loop[0]) if chunked else (loop[0] as MVTilemap).drawn_cells >= _total(loop[0])), [(loop[0] as MVTilemap).drawn_cells, _total(loop[0])])
		for t in loop:
			t.queue_free()
		await frames(1)
	MVTilemap.CHUNKED = true
	_finish()

func _finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
