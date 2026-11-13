extends Node2D
## 地图绘制合批（12 层下雪变卡反馈，v0.01.06）：
## - 图块 MVTilemap.SORTED_DRAW：每块按「格内次序 → 图集」归组。查：同一格里的图块与次序和逐格画完全一样（只丢掉本来就不画的空格），
##   图集切换次数大降（切换一次＝断一批绘制）。回退 SORTED_DRAW = false 回到逐格逐层。
## - 天气 XScreenFxView.BATCH_WEATHER：暗幕和全部雨雪合成一组三角形一次画完；回退 false 逐片画。无头下只查两支都能跑、粒子数照旧。
## 画面逐像素一致在真窗口实测过（九张图、雨雪暴风雨新旧截图 0 像素差；无头取不到画面，这里不测）。
var results := []

func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	print(("PASS " if ok else "FAIL ") + name + " " + JSON.stringify(detail))

func _ready() -> void:
	_run.call_deferred()

func _layers(id: int) -> Array:
	var data := XDB.map(id)
	var lower := MVTilemap.new()
	var upper := MVTilemap.new()
	add_child(lower)
	add_child(upper)
	lower.setup(data, false)
	upper.setup(data, true)
	return [lower, upper]

## 各格的 id 序列（按格坐标分组，保持出现次序）
func _per_cell(cmds: PackedInt32Array, tm: MVTilemap, keep_only_drawn: bool) -> Dictionary:
	var out := {}
	for j in range(0, cmds.size(), 3):
		if keep_only_drawn and tm.sheet_of(cmds[j]) < 0:
			continue
		var k := Vector2i(cmds[j + 1], cmds[j + 2])
		if not out.has(k):
			out[k] = []
		out[k].append(cmds[j])
	return out

func _switches(cmds: PackedInt32Array, tm: MVTilemap) -> int:
	var n := 0
	var last := -2
	for j in range(0, cmds.size(), 3):
		var sh := tm.sheet_of(cmds[j])
		if sh < 0:
			continue
		if sh != last:
			n += 1
			last = sh
	return n

func _run() -> void:
	if not XDB.available():
		check("skipped_no_data", true)
		return _finish()
	# 5 一层（雪地）、23 十二层冰封洞穴、29 十三层、47 十九层、69 天之上（水面）、30 十四层（循环）、4 大厅
	for id in [5, 23, 29, 47, 69, 30, 4]:
		var tms := _layers(id)
		var same := true
		var bad := []
		var old_sw := 0
		var new_sw := 0
		for tm in tms:
			for c in (tm as MVTilemap)._chunks:
				for water in [false, true]:
					if water and c.water == null:
						continue
					MVTilemap.SORTED_DRAW = false
					var old: PackedInt32Array = tm.part_commands(c.rect, water)
					MVTilemap.SORTED_DRAW = true
					var now: PackedInt32Array = tm.part_commands(c.rect, water)
					old_sw += _switches(old, tm)
					new_sw += _switches(now, tm)
					if _per_cell(old, tm, true) != _per_cell(now, tm, false):
						same = false
						if bad.size() < 3:
							bad.append(c.rect)
		check("map%d_same_cells_same_order" % id, same, bad)
		check("map%d_fewer_sheet_switches" % id, new_sw * 3 <= old_sw or old_sw < 30, [old_sw, new_sw])
		for t in tms:
			t.queue_free()
		await get_tree().process_frame
	MVTilemap.SORTED_DRAW = true
	await _weather()
	_finish()

func _weather() -> void:
	XState.new_game(3, 1, [8, 9, 10])
	var view := XScreenFxView.new()
	add_child(view)
	for t in ["snow", "rain", "storm"]:
		XState.current.screen.change_weather(t, 7, 0)
		XScreenFxView.BATCH_WEATHER = false
		for i in 5:
			await get_tree().physics_frame
		await get_tree().process_frame
		var n_old: int = view._weather._sprites.size()
		XScreenFxView.BATCH_WEATHER = true
		for i in 5:
			await get_tree().physics_frame
		await get_tree().process_frame
		check("weather_%s_both_paths" % t, n_old == 70 and view._weather._sprites.size() == 70 and view._weather.visible, [n_old, view._weather._sprites.size()])
	XState.current.screen.change_weather("none", 0, 0)
	for i in 3:  # 头一帧清粒子，下一帧才隐藏
		await get_tree().physics_frame
	check("weather_off_clears", not view._weather.visible and not view._weather.has_sprites())
	view.queue_free()

func _finish() -> void:
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_map_draw_batching", "passed": results.size() - failed.size(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
