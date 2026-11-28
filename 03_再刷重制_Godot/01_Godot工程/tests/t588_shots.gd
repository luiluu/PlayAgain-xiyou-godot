extends Node
## 工具（不是专项）：T588 法宝界面对照截图，开关关（改前）与开（改后）：真开物品页。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t588_shots.tscn -- --out=<目录>
const TestEnv = preload("res://tests/xiyou_test_env.gd")
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _frames(n := 20) -> void:
	for i in range(n):
		await get_tree().process_frame


func _image(page: Control, name: String) -> void:
	await _frames(40)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)
	page.queue_free()
	await _frames(3)


func _switch(on: bool) -> void:
	XHelpCard.FABAO_BRIEF_T588 = on
	XHelpCard.FABAO_FEED_GRADE_T588 = on


## 真开物品页（西游档走原版界面）：护甲分类停在这件法宝上；action 为真时打开操作菜单（吞噬升级的「喂入」行在这里）
func _page(on: bool, id: int, lv: int, action := false) -> Control:
	_switch(on)
	var s := XState.current
	s.gear.clear()
	var item := XGear.template("armor", id)
	item["level"] = lv
	s.register_gear(item)
	s.gear.append(item)
	var page := XItemScene.new()
	add_child(page)
	await _frames(6)
	for i in XShop.CATEGORIES.size():
		if str(XShop.CATEGORIES[i][1]) == "armor":
			page._cat = i
	page._ok()
	await _frames(6)
	for i in page.entries().size():
		if int(page.entries()[i].rec.get("base", 0)) == id and page.entries()[i].rec.has("instanceId"):
			page._index = i
			break
	page._refresh()
	if action:
		page._ok()
	return page


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	TestEnv.isolate("t588_shots")
	XSplashScreen.shown = true
	for tianqi in [false, true]:
		var s := XState.new_game(2, 1, [8, 9, 10])
		if tianqi:
			s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "zhengdao", "lineup": [1]}
		s.set_variable(20, 10)
		XState.current = s
		for n in get_tree().root.get_children():
			if n is XToast:
				n.queue_free()
		for pair in [[123, 5, false, "zhuxian"], [XYunshang.RELIC, 5, false, "yunshang"], [123, 30, true, "feed_menu"]]:
			var name := ("other_" if tianqi else "xiyou_") + str(pair[3])
			await _image(await _page(false, pair[0], pair[1], pair[2]), name + "_before")
			await _image(await _page(true, pair[0], pair[1], pair[2]), name + "_after")
	_switch(true)
	print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
	get_tree().quit.call_deferred(0)
