extends Node
## events7：事件指令 261 播放电影（原版 Graphics.playVideo；只有宇智波鼬 CE1514「血轮眼开」、CE1516「幻术世界」两段）。
## - 转换产物：movies/<名>.json 帧数与 ffprobe 量的一致（86／76 帧、30 帧每秒），首末帧图与音轨都在。
## - XMoviePlayer：盖在画面上（层 89，在提示 90 下面），按时间逐帧换图，放够 帧数÷帧率 秒才发 finished，然后移除自己。
## - 地图：command261 先显示待显示文字再放（$gameMessage.isBusy），放完才执行下一条（waitMode 'video'）。
## - 战斗：XBattleEventRunner 记一条 movie，接着往下执行（画面层 XBattleScene._play 放完再演后面的记录）。
## - CE1514／1516 原版指令里确有 261，片名与产物对得上。
const MOVIES := {"血轮眼开": 86, "幻术世界": 76}   # 冻结源 movies/*.webm：ffprobe -count_frames（3840×2160 VP9，30 帧）

var results := []


class Host:
	extends Node
	var order: Array = []
	func refresh_events() -> void:
		pass
	func show_message(msg: Dictionary):
		order.append("msg:" + "".join(PackedStringArray(msg.get("lines", []))))
		await get_tree().process_frame
		return 0
	func play_movie(name: String) -> void:
		order.append("movie:" + name + ":var" + str(int(XState.current.variable(1))))
		var t0 := Time.get_ticks_msec()
		var m := XMoviePlayer.start(name)
		if m != null:
			await m.finished
		order.append("movie_end:%d" % (Time.get_ticks_msec() - t0))


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))


static func _cmd(code: int, parameters: Array, indent := 0) -> Dictionary:
	return {"code": code, "indent": indent, "parameters": parameters}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# 产物
	for name in MOVIES:
		var meta := XMoviePlayer.info(name)
		check("meta." + name, int(meta.get("frames", 0)) == MOVIES[name] and int(meta.get("fps", 0)) == 30, meta)
		check("frames." + name, ResourceLoader.exists(XMoviePlayer.frame_path(name, 0)) and ResourceLoader.exists(XMoviePlayer.frame_path(name, MOVIES[name] - 1))
			and not ResourceLoader.exists(XMoviePlayer.frame_path(name, MOVIES[name])))
		check("audio." + name, ResourceLoader.exists("%smovies/%s.ogg" % [XDB.BASE, name]))
	check("missing_movie_null", XMoviePlayer.start("不存在的片子") == null)
	# 公共事件里的 261
	var ces: Array = XDB.table("CommonEvents")
	for pair in [[1514, "血轮眼开"], [1516, "幻术世界"]]:
		var found: Array = (ces[pair[0]].list as Array).filter(func(c): return int(c.code) == 261).map(func(c): return str(c.parameters[0]))
		check("ce%d_261" % pair[0], found == [pair[1]], found)
	# 播放器本身
	var t0 := Time.get_ticks_msec()
	var m := XMoviePlayer.start("血轮眼开")
	var toast := XToast.new()
	check("player_on_root", m != null and m.get_parent() == get_tree().root and m.layer == 89 and m.layer < toast.layer)
	toast.free()
	var seen := {}
	while is_instance_valid(m) and not m.is_queued_for_deletion():
		seen[m.shown] = true
		await get_tree().process_frame
	var ms := Time.get_ticks_msec() - t0
	check("player_duration", ms >= 86 * 1000 / 30 - 50, ms)
	check("player_frames_advance", seen.size() >= 20 and seen.has(0), seen.size())
	await get_tree().process_frame
	check("player_removed", get_tree().root.get_children().filter(func(n): return n is XMoviePlayer).is_empty())
	# 地图解释器：文字先显示，片子放完再设变量
	XState.new_game(3, 1, [8, 9, 10])
	var host := Host.new()
	add_child(host)
	var it := MVInterpreter.new(host, 4, 0, [_cmd(316, [0, 1, 0, 0, 1, true]), _cmd(261, ["幻术世界"]), _cmd(122, [1, 1, 0, 0, 7]), _cmd(0, [])])
	await it.run()
	var order := host.order
	check("map_order", order.size() == 3 and str(order[0]).begins_with("msg:") and order[1] == "movie:幻术世界:var0", order)
	check("map_waits_movie", order.size() == 3 and int(str(order[2]).split(":")[1]) >= 76 * 1000 / 30 - 50, order)
	check("map_after_movie", int(XState.current.variable(1)) == 7)
	# 空片名（MV name.length 为 0 不放）
	host.order.clear()
	await MVInterpreter.new(host, 4, 0, [_cmd(261, [""]), _cmd(0, [])]).run()
	check("map_empty_name", host.order.is_empty(), host.order)
	host.queue_free()
	# 战斗：记一条 movie，不拦着往下执行
	var runner := XBattleEventRunner.new(null, [_cmd(261, ["血轮眼开"]), _cmd(0, [])])
	var r := runner.advance()
	check("battle_log", r.kind == "done" and runner.logs.size() == 1 and runner.logs[0].type == "movie" and runner.logs[0].name == "血轮眼开" and runner.skipped.is_empty(), [r, runner.logs])
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
