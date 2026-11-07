extends Node
## 原版 Drill_SpeedGear 1.6 倍（XSpeedGear）：进西游标题（entry）后物理帧率 96、time_scale 1.6、声音速率 1.06；
## 真实 1 秒约跑 96 个物理帧，等 60 帧（地图事件的「等待 60 帧」）约 0.625 秒；开关关＝60 帧／秒。

var results := []


func check(tag: String, ok: bool, detail = null) -> void:
	results.append({"name": tag, "passed": ok})
	if not ok:
		print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XSpeedGear.HEADLESS_APPLY = true
	var entry: Node = load("res://modes/xiyou/entry.tscn").instantiate()
	add_child(entry)
	await get_tree().process_frame
	check("entry.rate", Engine.physics_ticks_per_second == 96 and is_equal_approx(Engine.time_scale, 1.6)
		and is_equal_approx(AudioServer.playback_speed_scale, 1.06), [Engine.physics_ticks_per_second, Engine.time_scale, AudioServer.playback_speed_scale])
	entry.queue_free()
	# 真实秒数：1 秒里的物理帧数；60 帧用多少毫秒
	await get_tree().physics_frame
	var t0 := Time.get_ticks_msec()
	var f0 := Engine.get_physics_frames()
	while Time.get_ticks_msec() - t0 < 1000:
		await get_tree().process_frame
	var per_sec := (Engine.get_physics_frames() - f0) * 1000.0 / (Time.get_ticks_msec() - t0)
	check("real.ticks_per_second", per_sec > 86.0 and per_sec < 106.0, per_sec)
	t0 = Time.get_ticks_msec()
	for i in 60:
		await get_tree().physics_frame
	var ms := Time.get_ticks_msec() - t0
	check("real.wait60", ms > 540 and ms < 760, ms)
	XSpeedGear.ENABLED = false
	XSpeedGear.apply()
	check("switch_off", Engine.physics_ticks_per_second == 60 and is_equal_approx(Engine.time_scale, 1.0) and is_equal_approx(AudioServer.playback_speed_scale, 1.0))
	XSpeedGear.ENABLED = true
	XSpeedGear.reset()
	XSpeedGear.HEADLESS_APPLY = false
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
