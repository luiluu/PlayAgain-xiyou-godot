extends Node
## 工具（不是专项）：文字批 2／3（T027）改到的五处界面截图：技能卡、天平、设置页、再挑战菜单、战力页（1280×720，16:9）。
## 用法（要真窗口，不能 --headless；Kyo 要求带窗口一律静音）：
##   godot --path 01_Godot工程 res://tests/text_batch23_shots.tscn --audio-driver Dummy -- --out=<目录>
const Kit := preload("res://tests/lib/tq_save_kit.gd")
var out_dir := ""
var _kit


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _phys(n := 1) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _shot(name: String) -> void:
	await _phys(8)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


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
	await _phys(2)


func _bg() -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.16)
	bg.size = Vector2(1280, 720)
	add_child(bg)
	return bg


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数或无窗口")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_kit = Kit.new("text_batch23_shots")
	XMessageBox.auto = false
	XPower.SHOW_POWER_UI = true
	XTianqiSkills.CARDS = true  # 角色卡默认关（等数值线一起开）：截图要看改写后的说明，临时开
	var s: XState = Kit.new_game("jiusi")
	s.gain_gold(5000)
	# 1 技能卡
	var bg := _bg()
	var card := XHelpCard.new()
	add_child(card)
	card.place_original(Rect2(200, 180, 420, 36))
	card.show_for(XDB.rec("Skills", 1240), "skill")
	await _shot("1_技能卡")
	card.show_for(XDB.rec("Armors", 4521), "armor")
	await _shot("1b_装备卡_暂未实装已收")
	card.queue_free()
	# 2 天平
	var box := XMessageBox.new()
	add_child(box)
	var done := {"v": false}
	var go := func():
		await XTianqiMoney.run_scale(box, s)
		done.v = true
	go.call()
	await _phys(30)
	await _press("ui_accept")  # 天平开场白
	await _phys(30)
	await _shot("2_天平")
	await _press("ui_cancel")
	await _phys(30)
	for i in 6:
		if done.v:
			break
		await _press("ui_cancel")
		await _phys(10)
	box.queue_free()
	# 3 设置页
	var opt := XOptionsScene.new()
	add_child(opt)
	await _phys(10)
	await _shot("3_设置页")
	for i in 1:  # E 换分类：常规 → 战斗（看「首领状态面板」所在页）
		for pressed in [true, false]:
			var k := InputEventKey.new()
			k.keycode = KEY_E
			k.physical_keycode = KEY_E
			k.pressed = pressed
			Input.parse_input_event(k)
			await _phys(3)
	await _phys(10)
	await _shot("3b_设置页_战斗")
	for pressed in [true, false]:
		var k2 := InputEventKey.new()
		k2.keycode = KEY_E
		k2.physical_keycode = KEY_E
		k2.pressed = pressed
		Input.parse_input_event(k2)
		await _phys(3)
	await _phys(10)
	await _shot("3c_设置页_遇敌")
	opt.queue_free()
	await _phys(4)
	# 4 再挑战菜单（牢妲）
	var box2 := XMessageBox.new()
	add_child(box2)
	s = Kit.new_game("jiusi")
	var done2 := {"v": false}
	var go2 := func():
		await XTianqiTrim.run_laoda(box2, s)
		done2.v = true
	go2.call()
	await _phys(40)
	await _shot("4_再挑战菜单")
	for i in 6:
		if done2.v:
			break
		await _press("ui_cancel")
		await _phys(10)
	box2.queue_free()
	# 5 战力页
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	var a := s.actor(s.party[0])
	XPowerPanel.open(host, a)
	await _phys(20)
	await _shot("5_战力页")
	bg.queue_free()
	_kit.teardown()
	print("TEXT_BATCH23_SHOTS=done")
	get_tree().quit.call_deferred(0)
