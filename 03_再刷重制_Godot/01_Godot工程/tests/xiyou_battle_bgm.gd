extends Node
## 敌群事件 241 播放 BGM 换战斗曲（审查 59 P3-1）：原版 AudioManager.playBgm 在 isCurrentBgm（只比名字）时不重放，
## 只 updateBgmParameters；名字不同才换曲，空名停。用真战斗画面（敌群 2、地图 5），曲目取死神觉醒敌群 2013／2018 用的两首。
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		print("FAIL ", tag, " ", JSON.stringify(detail).left(800))


func frames(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var b := XBattleScene.new()
	b.setup(2, true, false, XDB.map(5))
	add_child(b)
	await frames(30)
	var one := {"name": "Number One", "volume": 80, "pitch": 100, "pan": 0}
	b._change_bgm(one)
	var p1: AudioStreamPlayer = b.bgm
	check("first_play", p1 != null and p1.stream != null and p1.playing, [p1 != null and p1.stream != null])
	await frames(5)
	b._change_bgm(one.duplicate())
	check("same_name_same_params_keeps_player", b.bgm == p1 and is_instance_valid(p1) and p1.playing)
	var quieter := one.duplicate()
	quieter.volume = 40
	b._change_bgm(quieter)
	check("same_name_new_volume_updates_only", b.bgm == p1 and p1.playing
		and is_equal_approx(p1.volume_db, linear_to_db(0.4)), [b.bgm == p1, p1.volume_db])
	b._change_bgm({"name": "fade to black", "volume": 70, "pitch": 100, "pan": 0})
	var p2: AudioStreamPlayer = b.bgm
	check("other_name_replaces", p2 != p1 and p2.stream != null and p2.playing
		and is_equal_approx(p2.volume_db, linear_to_db(0.7)), [p2 != p1, p2.volume_db])
	await frames(2)
	check("old_player_freed", not is_instance_valid(p1) or not p1.playing)
	b._change_bgm({"name": "", "volume": 90, "pitch": 100, "pan": 0})
	check("empty_name_stops", b.bgm.stream == null and not p2.playing)
	# 停了以后同名再放：原版 stopBgm 清掉 _currentBgm，不算当前曲，照常从头放
	b._change_bgm(one)
	var p3: AudioStreamPlayer = b.bgm
	b.bgm.stop()
	b._change_bgm(one)
	check("stopped_same_name_restarts", b.bgm != p3 and b.bgm.playing)
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks}))
	get_tree().quit(0 if failures.is_empty() else 1)
