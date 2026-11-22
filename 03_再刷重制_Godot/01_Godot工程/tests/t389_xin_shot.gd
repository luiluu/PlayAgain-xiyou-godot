extends Node
## 工具（不是专项）：T389 教派包辛截图（800×450）。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t389_xin_shot.tscn -- --out=<目录>
## 两张：xin_kill32（32 层打赢伏羲后的获得提示，直接调 xin_after_battle）、xin_sublimate19（19 层炎龙队长升华台词）。
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


func _map(s: XState, map_id: int, x: int, y: int) -> XMapScene:
	s.map_id = map_id
	s.x = x
	s.y = y
	s.direction = 8
	XState.current = s
	var map := XMapScene.new()
	add_child(map)
	for _f in 300:
		await get_tree().process_frame
		if map.player != null and map.map_id == map_id and not map.busy:
			break
	await _frames(40)
	for n in XAchievementPopup._stack:
		if is_instance_valid(n):
			n.visible = false
	return map


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	var kit = Kit.new("t389_xin_shot")
	XConfig.whisper_mark("rift1")
	XConfig.whisper_mark("rift2")
	XMessageBox.auto = false
	XGuide.MILESTONE_ENABLED = false  # 楼层里程碑说明会先占住对话框
	var s := Kit.new_game("jiusi")
	s.set_variable(20, 33)
	var map := await _map(s, 156, 8, 16)
	XTianqiSect.xin_after_battle(map, s, 468)
	await _frames(240)
	await _shot("xin_kill32")
	map.queue_free()
	await _frames(10)

	s = Kit.new_game("jiusi")
	s.set_variable(20, 20)
	s.set_self_switch(47, 13, "A", true)
	s.gain_item(1975, 1)
	s.actor(int(s.party[0])).learn_skill(6133)
	map = await _map(s, 47, 14, 3)
	for e in map.events:
		if e.event_id == 13:
			map.run_event(e)
	await _frames(240)
	await _shot("xin_sublimate19")
	kit.teardown()
	get_tree().quit.call_deferred(0)
