extends Node
## 安卓切后台自动存档（cc 平台 DT 2026-11-06，O-215·安卓切后台存档，开关 XAutoSave.ON_PAUSE）：
## 收到 APPLICATION_PAUSED（或手机上的 FOCUS_OUT）时，只在地图上、事件不在跑、不在战斗／主菜单／传送页、开关开着才存，
## 存到单独的自动存档文件（不碰手动存档位 1～30，也不动保存次数和「最近用过的档位」）；同一次切后台的两个通知只写一次；
## 写失败只记日志不弹窗；手动存档之后自动存档作废；桌面不触发。桌面上用 XPlatform.force_mobile 当成手机。只写测试目录。
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
	XSave.dir_override = "user://test_xiyou_pause_save"
	_clean(XSave.dir())
	XConfig.path_override = XSave.dir().path_join("options.json")
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
	# 战斗前：start_battle 第一件事就存（在 _in_battle、第一个 await 之前）
	var src := FileAccess.get_file_as_string("res://modes/xiyou/map/map_scene.gd")
	var sb := src.substr(src.find("func start_battle("))
	sb = sb.substr(0, sb.find("\nfunc "))
	var cp := sb.find('XAutoSave.checkpoint(self, "battle")')
	check("battle_checkpoint_before_battle_state", cp > 0 and cp < sb.find("_in_battle = true") and cp < sb.find("await "), cp)
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
