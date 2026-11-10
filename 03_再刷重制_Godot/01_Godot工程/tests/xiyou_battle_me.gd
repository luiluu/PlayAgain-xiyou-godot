extends Node
## 战斗胜利／全灭 ME（battle-me1）：对照原版 rpg_managers.js AudioManager.playMe／stopMe／playBgm、
## Olivia_VictorySequenceUI processVictory、BattleManager.processDefeat（v0.62.12：victoryMe Victory2、defeatMe Defeat2）。
## - ME 走 ME 总线；放 ME 时在放的 BGM 停在原位置（暂停），ME 放完从原位置接着放、0.5 秒淡入（_replayFadeTime）；
## - 胜利：Victory2 在放，Ship3（胜利画面曲）只换上不开始，ME 放完从头放并淡入；
## - 全灭：Defeat2 在放，战斗曲停掉，ME 放完也不再响；
## - 没有这首 ME：BGM 照放；停掉的 BGM，ME 放完不会自己响（stopBgm 清了 _bgmBuffer）；
## - 战斗结束时 ME 还没放完：地图 take_battle_me 接着放（同一首、位置不倒回），地图曲等 ME 放完再淡入。
## ME 放完用 stop() 再发 finished 模拟（不等七八秒真放完）。内存新游戏，不写存档。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const WaitBudget := preload("res://tests/wait_budget.gd")
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> bool:
	checks += 1
	if not ok:
		failures.append(tag)
		print("FAIL ", tag, " ", JSON.stringify(detail).left(800))
	return ok


func frames(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _stream_name(p: AudioStreamPlayer) -> String:
	return p.stream.resource_path.get_file().get_basename() if p != null and p.stream != null else ""


## ME 放完：AudioStreamPlayer 自然播完会发 finished；stop() 不发，所以手动发
func _finish_me(p: AudioStreamPlayer) -> void:
	p.stop()
	p.finished.emit()


func _battle() -> XBattleScene:
	var b := XBattleScene.new()
	b.setup(2, true, false, XDB.map(5))
	add_child(b)
	await frames(30)
	return b


func _run() -> void:
	XConfig.path_override = "user://test_xiyou_battle_me_options.json"
	XMessageBox.auto = true
	XState.current = XState.new_game(3, 1, [8, 9, 10])
	var sys := XDB.system()
	check("system_victory_me", str(sys.get("victoryMe", {}).get("name", "")) == "Victory2", sys.get("victoryMe"))
	check("system_defeat_me", str(sys.get("defeatMe", {}).get("name", "")) == "Defeat2", sys.get("defeatMe"))
	check("me_files_exist", XDB.audio_path("me", "Victory2") != "" and XDB.audio_path("me", "Defeat2") != "")
	await _generic()
	await _victory()
	await _defeat()
	await _map_handover()
	var cur := get_tree().current_scene
	if cur is XMapScene:
		cur.queue_free()
		for i in range(5):
			await get_tree().process_frame
	XMessageBox.auto = false
	DirAccess.remove_absolute(XConfig.path_override)
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks}))
	get_tree().quit.call_deferred(0 if failures.is_empty() else 1)


## 通用 playMe／stopMe
func _generic() -> void:
	var b := await _battle()
	check("me_bus", b.me.bus == XAudio.bus("ME"), b.me.bus)
	var battle_bgm := b.bgm
	check("battle_bgm_playing", battle_bgm.playing and battle_bgm.stream != null)
	var target := battle_bgm.volume_db
	b.play_me({"name": "", "volume": 90, "pitch": 100})
	check("empty_me_keeps_bgm", battle_bgm.playing and not battle_bgm.stream_paused and not b.me.playing)
	b.play_me({"name": "Inn", "volume": 80, "pitch": 100})
	check("me_plays", b.me.playing and _stream_name(b.me) == "Inn" and is_equal_approx(b.me.volume_db, linear_to_db(0.8)), _stream_name(b.me))
	check("bgm_paused_during_me", battle_bgm.stream_paused)
	await frames(3)
	_finish_me(b.me)
	check("bgm_resumes_after_me", not battle_bgm.stream_paused and battle_bgm.playing)
	check("bgm_fades_in", battle_bgm.volume_db < target - 6.0, [battle_bgm.volume_db, target])
	await get_tree().create_timer(XAudio.REPLAY_FADE + 0.2).timeout
	check("bgm_fade_reaches_target", is_equal_approx(battle_bgm.volume_db, target), [battle_bgm.volume_db, target])
	# ME 期间敌群事件 241 换曲（AudioManager.playBgm 的 !this._meBuffer）：只换上，ME 放完才放
	b.play_me({"name": "Inn", "volume": 90, "pitch": 100})
	b._change_bgm({"name": "Battle1", "volume": 90, "pitch": 100, "pan": 0})
	check("bgm_change_during_me_waits", _stream_name(b.bgm) == "Battle1" and not b.bgm.playing, [_stream_name(b.bgm), b.bgm.playing])
	_finish_me(b.me)
	check("bgm_change_plays_after_me", b.bgm.playing)
	battle_bgm = b.bgm
	# 收场 stop_bgm：战斗曲停，之后 ME 放完也不再响
	b.play_me({"name": "Inn", "volume": 90, "pitch": 100})
	b.stop_bgm()
	_finish_me(b.me)
	check("stop_bgm_stays_stopped", not battle_bgm.playing)
	battle_bgm.play()
	# 停掉的 BGM：ME 放完不会自己响
	battle_bgm.stop()
	b.play_me({"name": "Inn", "volume": 90, "pitch": 100})
	_finish_me(b.me)
	check("stopped_bgm_stays_stopped", not battle_bgm.playing)
	b.queue_free()
	await frames(2)


## 胜利：Victory2＋Ship3 排队
func _victory() -> void:
	var b := await _battle()
	var battle_bgm := b.bgm
	b._victory()          # 不 await：结算画面会一直等确定
	await frames(2)
	check("victory_me_playing", b.me.playing and _stream_name(b.me) == "Victory2", _stream_name(b.me))
	check("victory_me_bus", b.me.bus == XAudio.bus("ME"))
	check("victory_bgm_queued_not_playing", b.bgm == battle_bgm and _stream_name(b.bgm) == "Ship3" and not b.bgm.playing, [_stream_name(b.bgm), b.bgm.playing])
	_finish_me(b.me)
	check("victory_bgm_starts_after_me", b.bgm.playing and not b.bgm.stream_paused and b.bgm.get_playback_position() < 1.0, b.bgm.get_playback_position())
	check("victory_bgm_fades_in", b.bgm.volume_db < linear_to_db(0.9) - 6.0, b.bgm.volume_db)
	b.queue_free()
	await frames(2)


## 全灭：Defeat2，战斗曲停、ME 放完不回来
func _defeat() -> void:
	var b := await _battle()
	var battle_bgm := b.bgm
	b._defeat_me()
	check("defeat_me_playing", b.me.playing and _stream_name(b.me) == "Defeat2", _stream_name(b.me))
	check("defeat_battle_bgm_stopped", not battle_bgm.playing)
	_finish_me(b.me)
	await frames(2)
	check("defeat_battle_bgm_not_back", not battle_bgm.playing)
	# _defeat 整条走一遍（消息窗自动翻页）：ME 跟消息一起出
	var b2 := await _battle()
	var done := [false]
	var run := func(): await b2._defeat(); done[0] = true
	run.call()
	await frames(2)
	check("defeat_me_with_message", b2.me.playing and _stream_name(b2.me) == "Defeat2" and not b2.bgm.playing, [_stream_name(b2.me), b2.bgm.playing])
	b.queue_free()
	b2.queue_free()
	await frames(2)


## 战斗结束时 ME 还在放：地图接着放，地图曲等它放完再淡入
func _map_handover() -> void:
	var s := XState.new_game_blank()
	s.map_id = 4
	s.x = 14
	s.y = 23
	get_tree().change_scene_to_file(MAP_SCENE)
	var m: XMapScene = null
	var t0 := WaitBudget.new(120000)
	while t0.waiting() and m == null:
		var c = get_tree().current_scene
		if c is XMapScene and c.map_id == 4 and c.player != null and not c.busy:
			m = c
		await get_tree().process_frame
	if not check("map_open", m != null):
		return
	var b := XBattleScene.new()
	b.setup(2, true, false, XDB.map(5))
	m.ui.add_child(b)
	await frames(30)
	b.play_me(XDB.system().get("victoryMe", {}))
	await get_tree().create_timer(0.3).timeout
	var pos := b.me.get_playback_position()
	check("handover_none_when_silent", not m.take_battle_me(null))
	check("handover_taken", m.take_battle_me(b))
	check("handover_map_me_playing", m.me.playing and _stream_name(m.me) == "Victory2" and m.me.get_playback_position() >= pos - 0.05,
		[_stream_name(m.me), m.me.get_playback_position(), pos])
	check("handover_battle_me_stopped", not b.me.playing)
	b.queue_free()
	# 地图曲在 ME 期间停着，ME 放完淡入
	if m.bgm.stream == null:
		m.play_bgm({"name": "Town1", "volume": 90, "pitch": 100, "pan": 0})
	var target := m.bgm.volume_db
	m.bgm.stream_paused = true
	_finish_me(m.me)
	check("map_bgm_resumes_after_me", not m.bgm.stream_paused)
	check("map_bgm_fades_in", m.bgm.volume_db < target - 6.0, [m.bgm.volume_db, target])
	await get_tree().create_timer(XAudio.REPLAY_FADE + 0.2).timeout
	check("map_bgm_fade_reaches_target", is_equal_approx(m.bgm.volume_db, target), [m.bgm.volume_db, target])
	# 真走一场可败的战斗（敌群 4、全队 1 血、自动打输）：Defeat2 由地图接着放，地图曲停着；ME 放完地图曲淡入
	if m.bgm.stream == null:
		m.play_bgm({"name": "Town1", "volume": 90, "pitch": 100, "pan": 0})
	var map_target := m.bgm.volume_db
	for a in XState.current.members():
		a.hp = 1
	XBattleScene.force_auto = true
	var result: int = await m.start_battle(4, true, true)
	XBattleScene.force_auto = false
	check("real_battle_lost", result == 2, result)
	check("real_defeat_me_on_map", m.me.playing and _stream_name(m.me) == "Defeat2", [m.me.playing, _stream_name(m.me)])
	check("real_map_bgm_waits_for_me", m.bgm.stream_paused)
	_finish_me(m.me)
	check("real_map_bgm_back_after_me", not m.bgm.stream_paused and m.bgm.volume_db < map_target - 6.0, [m.bgm.stream_paused, m.bgm.volume_db])
	await get_tree().create_timer(XAudio.REPLAY_FADE + 0.2).timeout
	check("real_map_bgm_fade_done", is_equal_approx(m.bgm.volume_db, map_target), [m.bgm.volume_db, map_target])
	# 换歌时收掉没淡完的淡入：新曲是自己的音量
	m.bgm.stream_paused = true
	m.me.play()
	_finish_me(m.me)
	m.play_bgm({"name": "Battle1", "volume": 50, "pitch": 100, "pan": 0})
	await get_tree().create_timer(XAudio.REPLAY_FADE + 0.2).timeout
	check("new_bgm_not_clobbered_by_fade", is_equal_approx(m.bgm.volume_db, linear_to_db(0.5)), m.bgm.volume_db)
