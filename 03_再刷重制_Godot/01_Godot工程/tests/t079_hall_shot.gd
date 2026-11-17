extends Node
## 工具（不是专项）：T079 天启篇大厅 NPC 清理截图（800×450）。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t079_hall_shot.tscn -- --out=<目录>
## 两张：tq（天启篇存档，清理后）、xy（西游存档，原样）；人站 (14,8)，看北墙一排和庆典布置。
const Kit := preload("res://tests/lib/tq_save_kit.gd")

var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _frames(n := 20) -> void:
	for i in range(n):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	img.resize(800, 450, Image.INTERPOLATE_LANCZOS)
	img.save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _hall(s: XState, name: String) -> void:
	s.map_id = 4
	s.x = 14
	s.y = 8
	XState.current = s
	var map := XMapScene.new()
	add_child(map)
	for _f in 300:
		await get_tree().process_frame
		if map.player != null and map.map_id == 4 and not map.busy:
			break
	await _frames(40)
	for n in XAchievementPopup._stack:   # 开局成就提示条挡画面，截图前收掉（只影响截图）
		if is_instance_valid(n):
			n.visible = false
	var shown := []
	for e in map.events:
		if e.page_index >= 0 and e.character_name != "":
			shown.append(e.event_id)
	print("SHOWN ", name, " ", shown)
	await _shot(name)
	map.queue_free()
	await _frames(10)


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	var kit = Kit.new("t079_hall_shot")
	XConfig.whisper_mark("rift1")
	XConfig.whisper_mark("rift2")
	await _hall(Kit.new_game("jiusi"), "tq_hall")
	var plain := XState.new_game_blank()
	plain.set_variable(20, 3)
	await _hall(plain, "xy_hall")
	kit.teardown()
	get_tree().quit.call_deferred(0)
