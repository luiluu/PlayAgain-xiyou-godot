extends Node
## 冠军之路四关战斗截图（冠军庆典，cc 11-15）：不是专项，要窗口（不加 --headless）。单独跑：
##   godot --path 01_Godot工程 res://tests/virtual_player/fest_road_shots.tscn -- --out=<目录>

var out_dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	_go.call_deferred()


func _go() -> void:
	XConfig.path_override = ProjectSettings.globalize_path("user://test_fest_road_shots/config.json")
	XConfig._loaded_path = "<unloaded>"
	XFest.TODAY_OVERRIDE = XFest.START
	var s := XState.new_game_blank()
	XState.current = s
	for id in [1, 2, 3, 4, 5]:
		if not s.party.has(id):
			s.add_actor(id)
	s.init_battle_slots()
	for i in 5:
		s.set_battle_slot(i, [1, 2, 3, 4, 5][i])
	DirAccess.make_dir_recursive_absolute(out_dir)
	var shots := []
	for st in XFestRoad.TEAMS.size():
		shots.append([0, st])
	shots.append([1, XFestRoad.TEAMS.size() - 1])  # 困难版决赛
	for pair in shots:
		var tier: int = pair[0]
		var st: int = pair[1]
		XFestRoad.in_road_battle = true
		XFestRoad.battle_streak = st
		var b := XBattleScene.new()
		b.setup(XFestRoad.troop_id(tier, st), false, true, XDB.map(4))
		add_child(b)
		for _i in 150:
			await get_tree().process_frame
		var path := out_dir.path_join("fest_road_%s_%d_%s.png" % [str(XFestRoad.TIERS[tier].key), st + 1, str(XFestRoad.TEAMS[st].name)])
		RenderingServer.force_draw(false)
		var err := get_viewport().get_texture().get_image().save_png(path)
		print("SHOT ", path, " ", err, " enemies=", b.logic.enemies.map(func(e): return "%s mhp=%d hp=%d atk=%d mat=%d" % [str(e.data().name), int(e.mhp), int(e.hp), int(e.param(2)), int(e.param(4))]))
		b.queue_free()
		await get_tree().process_frame
	XFestRoad.in_road_battle = false
	get_tree().quit(0)
