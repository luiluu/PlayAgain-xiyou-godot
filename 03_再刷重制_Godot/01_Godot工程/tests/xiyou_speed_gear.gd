extends Node
## 原版 Drill_SpeedGear 1.6 倍（XSpeedGear）：进西游标题（entry）后物理帧率 96、time_scale 1.6、声音速率 1.06；
## 真实 1 秒约跑 96 个物理帧，等 60 帧（地图事件的「等待 60 帧」）约 0.625 秒；开关关＝60 帧／秒。
## 实测三段（原版读数：ui_reference/speed_gear_ref.cjs，冻结正式源，updateScene 96～98 次／秒）：
##  真实事件「等待 60 帧」（MVInterpreter 230）——原版 61 次 updateScene、571～727 毫秒；
##  地图上玩家走 10 格（移动路线、穿透、不奔跑、速度 4）——原版每格 8 次 updateScene（distancePerFrame 0.125，含 rpg_objects 的 ×2），
##  这里只对 1.6 倍那一部分：每格帧数＝1／每帧距离，真实毫秒＝帧数／96；
##  战斗夹具角色普通攻击（startAction→endAction）——原版 46 次 updateScene（无头渲染慢时 580～1395 毫秒，理论 0.48 秒）。

const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"

var results := []


func check(tag: String, ok: bool, detail = null) -> void:
	results.append({"name": tag, "passed": ok})
	if not ok:
		print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	# 要换到地图场景，测试节点挂到根节点
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


## 真实毫秒是否约等于 物理帧数／96（加载与并行测试的抖动留 ±30%＋40 毫秒）
static func near_ticks(ms: float, frames: int) -> bool:
	var want := frames * 1000.0 / 96.0
	return absf(ms - want) <= want * 0.3 + 40.0


class QuietBattle extends XBattleScene:
	func _main() -> void:
		pass


func _attack_case() -> void:
	XEnemy.force_roll = 100.0
	XConfig.set_flag("CombatSkillAnimation", false)
	var st := XState.new_game(3, 1, [8, 9, 10])
	st.random_master = XRandomStream.hex64(20261018)
	var scene := QuietBattle.new()
	scene.setup(2, true, false, {})
	add_child(scene)
	for i in 40:
		await get_tree().physics_frame
	var logic := scene.logic
	var user: XActor = logic.actors[0]
	var logs := logic.execute(user, XDB.rec("Skills", 1), logic.enemies[1], true)
	var i := logs.find(logs.filter(func(l): return l.type == "seq_phase")[0])
	var j := logs.find(logs.filter(func(l): return l.type == "seq_end")[0])
	var player := XSequencePlayer.create(scene, logs[i - 1], logs.slice(i, j + 1))
	var f0 := Engine.get_physics_frames()
	var t0 := Time.get_ticks_msec()
	await player.play()
	var af := Engine.get_physics_frames() - f0
	var ms := Time.get_ticks_msec() - t0
	print("SPEED_GEAR attack frames=%d ms=%d" % [af, ms])
	check("battle.attack_ms", af > 20 and near_ticks(ms, af), [ms, af])
	scene.queue_free()


func _run() -> void:
	XSpeedGear.HEADLESS_APPLY = true
	var entry: Node = load("res://modes/xiyou/entry.tscn").instantiate()
	add_child(entry)
	await get_tree().process_frame
	check("entry.rate", Engine.physics_ticks_per_second == 96 and is_equal_approx(Engine.time_scale, 1.6)
		and is_equal_approx(AudioServer.playback_speed_scale, 1.06), [Engine.physics_ticks_per_second, Engine.time_scale, AudioServer.playback_speed_scale])
	entry.queue_free()
	# 真实秒数：每秒物理帧数。先空转 0.5 秒（实例化入口时的卡顿会让引擎追帧，第一次跑量到过 107.7），再量 2 秒；
	# 范围按原版实测 updateScene 96.2～97.6 次／秒（speed_gear_ref.cjs 三次）取 96 ± 5%
	var w0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - w0 < 500:
		await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	var f0 := Engine.get_physics_frames()
	while Time.get_ticks_msec() - t0 < 2000:
		await get_tree().process_frame
	var per_sec := (Engine.get_physics_frames() - f0) * 1000.0 / (Time.get_ticks_msec() - t0)
	print("SPEED_GEAR ticks_per_second=%.1f" % per_sec)
	check("real.ticks_per_second", per_sec >= 96.0 * 0.95 and per_sec <= 96.0 * 1.05, per_sec)
	t0 = Time.get_ticks_msec()
	for i in 60:
		await get_tree().physics_frame
	var ms := Time.get_ticks_msec() - t0
	check("real.wait60", ms > 540 and ms < 760, ms)
	# ① 真实事件：地图解释器「等待 60 帧」按物理帧走（原来按渲染帧，headless 下几乎不等、带窗口时 60 帧要 1 秒）
	var host := Node.new()
	add_child(host)
	MVInterpreter.HEADLESS_RENDER_WAIT = false  # 带窗口时的走法；改之前（按渲染帧等）这里 headless 几十毫秒就等完、对不上 0.625 秒
	t0 = Time.get_ticks_msec()
	f0 = Engine.get_physics_frames()
	await MVInterpreter.new(host, 0, 0, [{"code": 230, "indent": 0, "parameters": [60]}, {"code": 0, "indent": 0, "parameters": []}]).run()
	var wf := Engine.get_physics_frames() - f0
	ms = Time.get_ticks_msec() - t0
	print("SPEED_GEAR wait60 frames=%d ms=%d" % [wf, ms])
	check("event.wait60_frames", wf >= 59 and wf <= 62, wf)
	check("event.wait60_ms", ms > 540 and ms < 760, ms)
	MVInterpreter.HEADLESS_RENDER_WAIT = true
	host.queue_free()
	# ② 地图上走 10 格
	var st := XState.new_game(3, 1, [8, 9, 10])
	st.map_id = 8
	st.x = 20
	st.y = 26
	get_tree().change_scene_to_file(MAP_SCENE)
	var map: XMapScene = null
	for i in 3000:
		await get_tree().process_frame
		var m = get_tree().current_scene
		if m is XMapScene and m.map_id == 8 and m.player != null and not m.busy:
			map = m
			break
	check("map.loaded", map != null)
	if map != null:
		for i in 30:
			await get_tree().physics_frame
		var pl: MVCharacter = map.player
		pl.through = true
		var x0 := pl.grid.x
		var list := []
		for i in 10:
			list.append({"code": 3, "indent": 0, "parameters": []})
		list.append({"code": 0, "indent": 0, "parameters": []})
		f0 = Engine.get_physics_frames()
		t0 = Time.get_ticks_msec()
		pl.force_move_route({"list": list, "repeat": false, "skippable": true, "wait": false})
		while pl.is_route_forcing() or pl.is_moving():
			await get_tree().physics_frame
			if Engine.get_physics_frames() - f0 > 2000:
				break
		var mf := Engine.get_physics_frames() - f0
		ms = Time.get_ticks_msec() - t0
		var per_tile := mf / maxf(1.0, float(pl.grid.x - x0))
		print("SPEED_GEAR move10 tiles=%d frames=%d ms=%d per_tile=%.2f dpf=%s" % [pl.grid.x - x0, mf, ms, per_tile, pl.distance_per_frame()])
		check("map.move10_tiles", pl.grid.x - x0 == 10, pl.grid.x - x0)
		# 每格帧数＝1／每帧距离（距离倍数由 MVCharacter 管，八戒那边改；这里只看物理帧率）
		check("map.move10_ms", near_ticks(ms, mf), [ms, mf])
		# 游戏时间（play_seconds）按真实时间走，不随齿轮快 1.6 倍（原版 playtime＝frameCount／60，审查第 52 期 P2-2）
		var p0 := XState.current.play_seconds
		t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 1500:
			await get_tree().process_frame
		var real := (Time.get_ticks_msec() - t0) / 1000.0
		var gained := XState.current.play_seconds - p0
		print("SPEED_GEAR play_seconds real=%.3f gained=%.3f" % [real, gained])
		check("map.play_seconds_real_time", absf(gained - real) <= real * 0.08, [gained, real])
		map.queue_free()
	# ③ 战斗普通攻击（行动序列演出，按物理帧走）
	await _attack_case()
	XSpeedGear.ENABLED = false
	XSpeedGear.apply()
	check("switch_off", Engine.physics_ticks_per_second == 60 and is_equal_approx(Engine.time_scale, 1.0) and is_equal_approx(AudioServer.playback_speed_scale, 1.0))
	XSpeedGear.ENABLED = true
	XSpeedGear.reset()
	XSpeedGear.HEADLESS_APPLY = false
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
