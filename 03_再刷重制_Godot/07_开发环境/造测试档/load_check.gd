extends Node
## 读档验证（T066）：从 --dir 里读 save_<slot>（同标题画面「读取存档」：XSave.load_slot 后进地图场景），等地图空闲后截图。
##   godot --path <工程> --audio-driver Dummy -s res://tests/test_main_loop.gd <临时场景> -- --dir=<存档目录> --slot=10 --shot=<png>
## --dir 是一份复制出来的存档目录（不是真存档目录）；main 开着存档封存时会在这份目录里把 .json 封成 .ksv（写在复制目录里）。
## 打印 LOAD_CHECK_RESULT={...}：读档成功、地图号、位置、队伍人数、变量 20、难度。

const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"

var dir := ""
var slot := 10
var shot := ""
var out := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			dir = arg.substr(6)
		elif arg.begins_with("--slot="):
			slot = int(arg.substr(7))
		elif arg.begins_with("--shot="):
			shot = arg.substr(7)
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _run() -> void:
	out.entered = GameApp.enter_mode("xiyou")
	await get_tree().process_frame
	XSave.dir_override = dir
	XConfig.path_override = dir.path_join("options.json")
	XConfig._loaded_path = "<unloaded>"
	XConfig.whisper_mark("rift1")
	XConfig.whisper_mark("rift2")
	out.exists = XSave.exists(slot)
	out.summary = XSave.summary(slot)
	out.loaded = XSave.load_slot(slot)
	if out.loaded:
		get_tree().change_scene_to_file(MAP_SCENE)
		var s := XState.current
		var ok := false
		for i in range(1200):
			await get_tree().process_frame
			var sc = get_tree().current_scene
			if sc is XMapScene and sc.player != null and not sc.busy and sc.map_id == s.map_id:
				ok = true
				break
		for i in range(90):
			await get_tree().process_frame
		var sc = get_tree().current_scene
		out.map_ready = ok
		out.map = sc.map_id if sc is XMapScene else -1
		out.pos = [sc.player.grid.x, sc.player.grid.y] if sc is XMapScene else []
		out.party = s.party.size()
		out.var20 = s.variable(20)
		out.difficulty = s.difficulty
		out.level1 = s.actor(1).level
		if shot != "" and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shot)
			out.shot = shot
	XSave.dir_override = ""
	XConfig.path_override = ""
	print("LOAD_CHECK_RESULT=" + JSON.stringify(out))
	get_tree().quit.call_deferred(0 if out.get("map_ready", false) else 1)
