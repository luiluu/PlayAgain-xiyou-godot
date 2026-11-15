extends Node
## 工具（不是专项）：XTextFix 名字框修正前后的对话窗截图对比，照 tests/xiyou_message.gd 的开窗与截图写法。
## 用法（要真窗口，不能 --headless）：godot --path 01_Godot工程 res://tests/text_fix_shots.tscn -- --out=<目录>
## 每处写 <名>_原版.png（XTextFix 全关）与 <名>_修正.png（全开），再写 shots.json 记两边的原文。
const CASES := [
	["map008_副本协会主席", 8, 7, 0, 1],  # 缺前导 \n：<副本协会主席> 漏在正文里
	["map004_天才灵魂", 4, 36, 0, 175],  # /n< 写反
	["map071_双转义", 71, 22, 0, 5],  # \c\[4] 双转义，[4] 漏出来
	["map121_孤立n", 121, 1, 4, 35],  # 行首孤立 \n
	["map144_缺左括号", 144, 2, 1, 5],  # \n太上老君藏身处>（覆盖表补 <）
]
var out_dir := ""
var box: XMessageBox


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _phys(n := 1) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _until(cond: Callable, n := 600) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await _phys()
	return false


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	get_viewport().push_input(e)
	await _phys()
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	get_viewport().push_input(r)


## 取那条 401 所在的整段对话（往前到 101，往后到不是 401 为止）
func _message(map_id: int, ev: int, page: int, cmd: int) -> Dictionary:
	var list: Array = XDB.map(map_id).events[ev].pages[page].list
	var head := cmd
	while head > 0 and int(list[head].code) == 401:
		head -= 1
	var p: Array = list[head].parameters if int(list[head].code) == 101 else ["", 0, 0, 2]
	var lines := []
	var i := head + 1 if int(list[head].code) == 101 else cmd
	while i < list.size() and int(list[i].code) == 401:
		lines.append(str(list[i].parameters[0]))
		i += 1
	return {"face": str(p[0]), "index": int(p[1]), "position": int(p[3]) if p.size() > 3 else 2, "lines": lines}


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("需要真窗口和 -- --out=<目录>")
		# 工具不是专项：整轮测试（并行测试.py 跑 tests/ 下全部场景）里没给参数时报跳过、算通过
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	XMessageBox.auto = false
	XState.new_game(3, 1, [])
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.16)
	bg.size = Vector2(1280, 720)
	add_child(bg)
	box = XMessageBox.new()
	add_child(box)
	await _phys()
	var record := []
	for c in CASES:
		for on in [false, true]:
			XTextFix.set_all(on)
			var msg := _message(c[1], c[2], c[3], c[4])
			var done := {"v": null}
			var go := func(): done.v = await box.run(msg)
			go.call()
			await _until(func(): return box.win.pause and box._wait == 0)
			await _phys(12)
			await RenderingServer.frame_post_draw
			var file := out_dir.path_join("%s_%s.png" % [c[0], "修正" if on else "原版"])
			get_viewport().get_texture().get_image().save_png(file)
			record.append({"case": c[0], "fixed": on, "lines": msg.lines, "png": file.get_file()})
			while done.v == null:
				await _press("ui_accept")
				await _phys(4)
			await _phys(20)
	XTextFix.set_all(true)
	var f := FileAccess.open(out_dir.path_join("shots.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(record, "  "))
	f.close()
	print("TEXT_FIX_SHOTS=%d" % record.size())
	get_tree().quit.call_deferred(0)
