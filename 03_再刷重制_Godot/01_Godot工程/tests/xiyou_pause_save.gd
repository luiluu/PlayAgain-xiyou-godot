extends Node
## 安卓切后台自动存档（cc 平台 DT 2026-11-06，O-215·安卓切后台存档，开关 XAutoSave.ON_PAUSE）：
## 收到 APPLICATION_PAUSED（或手机上的 FOCUS_OUT）时，只在地图上、事件不在跑、不在战斗／主菜单／传送页、开关开着才存，
## 存到单独的自动存档文件（不碰手动存档位 1～30，也不动保存次数和「最近用过的档位」）；同一次切后台的两个通知只写一次；
## 写失败只记日志不弹窗；手动存档之后自动存档作废；桌面不触发。桌面上用 XPlatform.force_mobile 当成手机。只写测试目录。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _clean(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


## 清掉自动存档和去重记录，下一次切后台当成新的一次
func _fresh() -> void:
	XSave.remove_auto()
	XAutoSave.reset()


func _run() -> void:
	GameApp.fast_headless_frames()
	_clean(TestEnv.isolate("xiyou_pause_save"))   # 清掉上一轮的存档（isolate 已设好测试目录与配置路径、按默认值重读）
	XConfig.whisper_mark("rift1")   # _clean 连 options.json 一起删了，重写一次：新源大厅漩涡过场当作看过
	XMessageBox.auto = true
	XPlatform.force_mobile = true
	var s := XState.new_game(3, 1, [8, 10, 9])
	s.map_id = 4
	s.x = 14
	s.y = 23
	s.set_self_switch(4, 20, "A", true)
	# 新源（v0.62.12）方桌大厅多了无条件自动执行的事件 76「时空漩涡_字幕1」（47 条字幕演出，跑完开独立开关 A）：
	# 不关掉的话进图就在演出、地图 busy，切后台照规矩跳过（skip:event），下面「地图上能存」的几项都测不到
	s.set_self_switch(4, 76, "A", true)
	s.flags.SaveGameId = 1
	XSave.current_slot = 1
	var platform := XPlatform.new()
	add_child(platform)
	var map := XMapScene.new()
	add_child(map)
	await frames(4)
	check("defaults", XAutoSave.ON_PAUSE and XAutoSave.DEDUP_MSEC > 0)
	check("hook_set_by_map", XPlatform.pause_hook.is_valid())
	check("map_idle_after_setup", not map.busy)  # 前提：没有自动执行事件在跑（否则下面全是 skip:event）

	# 地图上切后台：存到自动存档，手动存档位、保存次数、最近档位都不动
	_fresh()
	var count := s.save_count
	platform.on_paused()
	check("map_saves", XSave.exists_auto() and XAutoSave.last_result == "saved", XAutoSave.last_result)
	check("manual_slots_untouched", range(1, XSave.SLOTS + 1).all(func(n): return not XSave.exists(n)))
	check("count_and_slot_kept", s.save_count == count and XSave.current_slot == 1, [s.save_count, count, XSave.current_slot])
	check("no_popup", not map.busy)

	# 去重：同一次切后台接着来的 FOCUS_OUT 不再写
	XSave.remove_auto()
	platform._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("dedup_focus_out", not XSave.exists_auto() and XAutoSave.last_result == "dup", XAutoSave.last_result)
	platform.on_paused()
	check("dedup_paused_again", not XSave.exists_auto() and XAutoSave.last_result == "dup", XAutoSave.last_result)
	# 过了去重窗口再切后台就照常存
	var t0 := Time.get_ticks_msec()
	check("after_window_saves", XAutoSave.on_pause(map, t0 + XAutoSave.DEDUP_MSEC + 1) == "saved" and XSave.exists_auto())

	# 只有 FOCUS_OUT（有的机器切后台先丢焦点）也存
	_fresh()
	platform._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("focus_out_saves", XSave.exists_auto(), XAutoSave.last_result)

	# 不该存的几种
	for spec in [["battle", "_in_battle"], ["event", "busy"], ["menu", "_menu_open"]]:
		_fresh()
		map.set(spec[1], true)
		platform.on_paused()
		check("no_save_in_" + spec[0], not XSave.exists_auto() and XAutoSave.last_result.begins_with("skip"), XAutoSave.last_result)
		map.set(spec[1], false)
	_fresh()
	map.transfer_page = XMapTransferScene.new()
	platform.on_paused()
	check("no_save_in_transfer", not XSave.exists_auto(), XAutoSave.last_result)
	map.transfer_page.free()
	map.transfer_page = null

	# 回退开关：关掉就不存（回到原版：切后台只暂停）
	_fresh()
	XAutoSave.ON_PAUSE = false
	platform.on_paused()
	check("switch_off_no_save", not XSave.exists_auto(), XAutoSave.last_result)
	XAutoSave.ON_PAUSE = true

	# 桌面：失焦（切窗口）不存
	_fresh()
	XPlatform.force_mobile = false
	platform._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	platform.on_paused()
	check("desktop_no_save", not XSave.exists_auto(), XAutoSave.last_result)
	XPlatform.force_mobile = true

	# 写不进去：只记日志，不弹窗，不改状态
	_fresh()
	# 临时文件的位置被同名文件夹占着，写不进去
	var good_dir := XSave.dir_override
	var bad_dir := good_dir.path_join("blocked")
	XSave.dir_override = bad_dir
	DirAccess.make_dir_recursive_absolute(XSave.auto_path() + ".tmp")
	platform.on_paused()
	check("fail_logged_no_popup", XAutoSave.last_result == "fail" and not XSave.exists_auto() and not map.busy and XSave.current_slot == 1, XAutoSave.last_result)
	DirAccess.remove_absolute(XSave.auto_path() + ".tmp")
	DirAccess.remove_absolute(bad_dir)
	XSave.dir_override = good_dir

	# 手动存档之后自动存档作废；读自动存档回到原来的档位
	_fresh()
	platform.on_paused()
	check("auto_summary", XSave.auto_summary().begins_with("自动存档"), XSave.auto_summary())
	s.gold = 4321
	XSave.current_slot = 3
	check("load_auto", XSave.load_auto() and XSave.current_slot == 1 and XState.current.gold != 4321, [XSave.current_slot])
	s = XState.current
	check("auto_kept_after_load", XSave.exists_auto())
	var title_page: Control = load("res://modes/xiyou/entry.tscn").instantiate()
	add_child(title_page)
	await frames(3)
	check("title_continue_button", title_page.find_child("ContinueAuto", true, false) != null)
	title_page.queue_free()
	await frames(1)
	check("manual_save_drops_auto", XSave.save(2) and not XSave.exists_auto())
	title_page = load("res://modes/xiyou/entry.tscn").instantiate()
	add_child(title_page)
	await frames(3)
	check("title_no_button_after_save", title_page.find_child("ContinueAuto", true, false) == null)
	title_page.queue_free()
	await frames(1)

	# Codex 报告第 5 项（平台 EH，O-221·自动存档检查点）：切后台碰上菜单／战斗时跳过，杀进程就丢进度；
	# 改成进主菜单、开战前各存一份安全检查点（地图上、事件没在跑时；不存战斗中间态）
	check("checkpoint_default_on", XAutoSave.CHECKPOINTS)
	check("event_battles_default_off", not XAutoSave.EVENT_BATTLES)
	_fresh()
	check("checkpoint_on_map_saves", XAutoSave.checkpoint(map, "battle") == "checkpoint:battle" and XSave.exists_auto(), XAutoSave.last_result)
	# 检查点不占切后台的去重窗口：紧接着切后台照样存
	XSave.remove_auto()
	check("checkpoint_not_dedup_pause", XAutoSave.on_pause(map) == "saved" and XSave.exists_auto(), XAutoSave.last_result)
	for spec in [["battle", "_in_battle"], ["event", "busy"], ["menu", "_menu_open"]]:
		_fresh()
		map.set(spec[1], true)
		XAutoSave.checkpoint(map, "menu")
		check("checkpoint_skip_in_" + spec[0], not XSave.exists_auto() and XAutoSave.last_result == "skip:" + spec[0], XAutoSave.last_result)
		map.set(spec[1], false)
	_fresh()
	XAutoSave.CHECKPOINTS = false
	XAutoSave.checkpoint(map, "menu")
	check("checkpoint_switch_off", not XSave.exists_auto() and XAutoSave.last_result == "skip:checkpoints_off", XAutoSave.last_result)
	XAutoSave.CHECKPOINTS = true
	_fresh()
	XPlatform.force_mobile = false
	XAutoSave.checkpoint(map, "menu")
	check("checkpoint_desktop_no_save", not XSave.exists_auto(), XAutoSave.last_result)
	XPlatform.force_mobile = true
	# 开战前检查点（平台 EJ，审查第 51 期 P2-1）：原来写在 start_battle 里，入口都先置 busy，永远被当成「事件」跳过。
	# 真走一次随机遇敌、一次事件战斗（指令 301），开打那一刻要有检查点
	_fresh()
	map.map_data.encounterList = [{"troopId": 1, "weight": 1, "regionSet": []}]
	map._encounter()
	check("encounter_checkpoint_saves", XSave.exists_auto() and XAutoSave.last_result == "checkpoint:battle", XAutoSave.last_result)
	await _end_battle(map)
	map.map_data.encounterList = []
	# 事件里开的战斗不存（平台 FB，审查第 52 期 P2-1）：事件先扣东西再开打（Map207 奇兽地先扣许可证再打 319），
	# 301 那一刻存下的是「扣了、没打」，读回来事件不会重跑。这里事件先扣 100 金再开打：自动存档要停在事件开始前那份。
	_fresh()
	var gs := XState.current
	var gold_was := gs.gold
	gs.gold = 500
	check("event_battle_pre_save", XSave.save_auto())  # 事件开始前的那份（如进主菜单时的检查点）
	XAutoSave.reset()
	var ev := [{"code": 125, "indent": 0, "parameters": [1, 0, 100]}, {"code": 301, "indent": 0, "parameters": [0, 1, false, true]}, {"code": 0, "indent": 0, "parameters": []}]
	map._set_busy(true)  # 同 run_event：事件跑着
	var interp := MVInterpreter.new(map, map.map_id, 0, ev)
	var done := {"v": false}
	var go := func():
		await interp.run()
		done.v = true
	go.call()
	await _until(func(): return _battle(map) != null)
	var saved = JSON.parse_string(FileAccess.get_file_as_string(XSave.auto_path()))
	check("event_battle_no_checkpoint", XAutoSave.last_result == "skip:in_event" and gs.gold == 400, "%s gold=%d" % [XAutoSave.last_result, gs.gold])
	check("event_battle_auto_keeps_pre_event", saved is Dictionary and int(saved.get("gold", -1)) == 500, str(saved.get("gold", null) if saved is Dictionary else saved))
	await _end_battle(map)
	await _until(func(): return done.v)
	map._set_busy(false)
	# 回退 EVENT_BATTLES = true：照 dev.393 存（存下的是扣完之后），确认断言咬得住这个差别
	_fresh()
	gs.gold = 500
	XAutoSave.EVENT_BATTLES = true
	map._set_busy(true)
	interp = MVInterpreter.new(map, map.map_id, 0, ev)
	done.v = false
	go.call()
	await _until(func(): return _battle(map) != null)
	saved = JSON.parse_string(FileAccess.get_file_as_string(XSave.auto_path()))
	check("event_battle_rollback_saves_after_deduct", XAutoSave.last_result == "checkpoint:battle" and saved is Dictionary and int(saved.get("gold", -1)) == 400, XAutoSave.last_result)
	await _end_battle(map)
	await _until(func(): return done.v)
	map._set_busy(false)
	XAutoSave.EVENT_BATTLES = false
	gs.gold = gold_was
	# 限频：60 秒内第二次战斗检查点跳过，过了就存
	var t := Time.get_ticks_msec()
	XSave.remove_auto()
	check("battle_checkpoint_rate_limited", XAutoSave.battle_checkpoint(map, false, t) == "skip:recent" and not XSave.exists_auto(), XAutoSave.last_result)
	check("battle_checkpoint_after_gap", XAutoSave.battle_checkpoint(map, false, t + XAutoSave.BATTLE_GAP_MSEC + 1) == "checkpoint:battle" and XSave.exists_auto(), XAutoSave.last_result)
	# 挂机中跳过（挂机已有定时存）
	_fresh()
	var hs := XState.current
	var hang_was := [hs.hang_up_active, hs.hang_up_origin]
	hs.hang_up_active = true
	hs.hang_up_origin = Vector2i(1, 1)
	check("battle_checkpoint_skip_hangup", XAutoSave.battle_checkpoint(map) == "skip:hangup" and not XSave.exists_auto(), XAutoSave.last_result)
	hs.hang_up_active = hang_was[0]
	hs.hang_up_origin = hang_was[1]
	# 事件里开的战斗不受 busy 阻挡，事件外 busy 照旧挡
	_fresh()
	map.busy = true
	check("in_event_skipped_by_default", XAutoSave.battle_checkpoint(map, true) == "skip:in_event" and not XSave.exists_auto(), XAutoSave.last_result)
	XAutoSave.reset()
	XAutoSave.EVENT_BATTLES = true
	check("in_event_ignores_busy", XAutoSave.battle_checkpoint(map, true) == "checkpoint:battle")
	XAutoSave.EVENT_BATTLES = false
	XAutoSave.reset()
	XSave.remove_auto()
	check("not_in_event_busy_skips", XAutoSave.battle_checkpoint(map, false) == "skip:event" and not XSave.exists_auto(), XAutoSave.last_result)
	map.busy = false
	# 进主菜单：真开一次菜单，开的那一刻就有检查点
	_fresh()
	map.open_menu()
	check("menu_checkpoint_saves", XSave.exists_auto() and XAutoSave.last_result == "checkpoint:menu", XAutoSave.last_result)
	await frames(3)

	# 离开地图：钩子失效，切后台不存也不报错
	_fresh()
	map.queue_free()
	await frames(2)
	platform.on_paused()
	check("off_map_no_save", not XSave.exists_auto() and not XPlatform.pause_hook.is_valid(), XAutoSave.last_result)
	_finish()


func _until(cond: Callable, n := 3000) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _battle(map: XMapScene) -> XBattleScene:
	for c in map.ui.get_children():
		if c is XBattleScene and not c.is_queued_for_deletion():
			return c
	return null


## 等战斗起来，当逃跑结束（同 xiyou_battle_transition 的收尾），再等回到地图
func _end_battle(map: XMapScene) -> void:
	await _until(func(): return _battle(map) != null and _battle(map).logic != null)
	var b := _battle(map)
	if b != null:
		b.logic.escaped = true
		b.finished.emit(1)
	await _until(func(): return not map._in_battle and _battle(map) == null)
	await frames(2)


func _finish() -> void:
	XPlatform.force_mobile = null
	XPlatform.pause_hook = Callable()
	XAutoSave.reset()
	_clean(XSave.dir())
	XSave.dir_override = ""
	XSave.current_slot = 0
	XConfig.path_override = ""
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
