extends Node
## 工具（不是专项）：T566 抽 10 个原来看不到说明的状态，各开一次队员状态窗截图。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t566_shots.tscn -- --out=<目录>
const Kit := preload("res://tests/lib/tq_save_kit.gd")
## 覆盖：普通改写、领域增益、减益、原来整格不显示的、复活类、持续伤害、10801 起的新状态
const IDS := [560, 706, 848, 854, 902, 1099, 1819, 2554, 2733, 10808]

var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _frames(n := 8) -> void:
	for i in range(n):
		await get_tree().process_frame


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	var kit := Kit.new("t566_shots")
	XTianqiSkills.reload_table()
	var s := XTianqi.start_new_game(3, "jianxian", [1])
	XTianqi.take_pending()
	XState.current = s
	var l := XBattleLogic.new()
	l.elite_roll = 100.0
	l.setup(2, s)
	var a: XActor = l.actors[0]
	var root := Control.new()
	root.size = Vector2(1280, 720)
	add_child(root)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var shown := 0
	for id in IDS:
		a.state_ids.clear()
		a.buffs.fill(0)
		a.add_state(id)
		# 只留这一个，开战被动带的状态不进列表，截图里看得清
		var p := XPartyStatusPanel.open(root, [a], a)
		await _frames()
		var st := XDB.rec("States", id)
		p._search.text = str(st.get("name", ""))
		p._search.text_changed.emit(p._search.text)
		await _frames()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("state_%d.png" % id))
		var hit: Array = p.filtered().filter(func(r): return r.id is int and r.id == id)
		shown += 1 if not hit.is_empty() else 0
		print("SHOT %d %s | %s" % [id, str(st.get("name", "")), str(hit[0].description) if not hit.is_empty() else "（没进列表）"])
		p.close()
		await _frames(3)
	kit.teardown()
	print("TEST_RESULT=" + JSON.stringify({"passed": shown, "total": IDS.size()}))
	get_tree().quit.call_deferred(0 if shown == IDS.size() else 1)
