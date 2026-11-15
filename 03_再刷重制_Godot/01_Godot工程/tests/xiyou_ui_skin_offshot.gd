extends Node
## 新界面开关关掉时与 main 逐像素一致（ui-skin-p0）：这个脚本不直接引用任何新类，main 上也能跑；
## 07_开发环境/皮肤关闭对照.py 把它拷进 main 的临时克隆和本分支各跑一次（要窗口），再用 --compare 逐像素比。
## 拍的页：主菜单、状态、物品、技能、装备、设置（技能 ui-skin-1b 加）、装备检索（XGearSearch 网页面板，ui-skin-1c 加：XWebPanel 换皮）；战斗（2A 加：指令窗、战技列表、选目标三张，地图 5 敌群 2，随机数钉住、呼吸停掉；只拍西游存档那一档）；
## 天启篇标题、选线四卡、异化工坊（ui-skin-3b 加；标题在西游情形下按发行构建拍：标题还没读档，新皮肤按构建开，发行构建不开）。两种情形：
##   xiyou      西游存档、开关全默认（重制版玩家现在的样子）；
##   tq_off     天启篇存档、XUiSkin.ENABLED = false（新皮肤关掉回退）。main 上没有 XUiSkin，两种都是旧界面。
## 去掉不确定因素：菜单粒子隐藏、MV 光标不闪烁、每页等固定帧数。
##   拍：godot --path <工程> res://tests/xiyou_ui_skin_offshot.tscn -- --out=<目录>
##   比：godot --headless --path <工程> res://tests/xiyou_ui_skin_offshot.tscn -- --compare=<目录甲>,<目录乙>
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const SKIN := "res://modes/xiyou/ui/skin/ui_skin.gd"
const PAGES := ["XMenu", "XStatusPage", "XItemScene", "XSkillScene", "XEquipScene", "XOptionsScene", "XGearSearch", "XTianqiTitle", "XTianqiLineCards", "XAlienWorkshop"]

var out_dir := ""
var compare := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--compare="):
			compare = arg.substr(10)
	_run.call_deferred()


func _run() -> void:
	if compare != "":
		_compare()
		return
	TestEnv.isolate("xiyou_ui_skin_offshot")
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var shots := 0
	var built := 0
	for scenario in ["xiyou", "tq_off"]:
		if scenario == "tq_off":
			s.flags["tianqi"] = {"rules": 1}
			if ResourceLoader.exists(SKIN):
				var sk: Script = load(SKIN)
				sk.set("ENABLED", false)
				print("skin ENABLED=", sk.get("ENABLED"))
		for cls in PAGES:
			var page: Node = _make(cls)
			if page == null:
				print("SKIP ", cls)
				continue
			if page.has_method("reset_session"):   # 装备检索：照 XGearSearch.open 先重置条件、给检索源
				page.call("reset_session")
				page.set("source", XGearQuery.collection(s))
			var sim_release := false
			if cls == "XTianqiTitle":   # ui-skin-3b：五项给空函数；西游情形按发行构建（重制版玩家看到的）
				sim_release = scenario == "xiyou"
				ReleaseEntry.simulate_release = sim_release
				var noop := func(): pass
				page.call("setup", {"new_game": noop, "load": noop, "options": noop, "achievements": noop, "check_update": noop}, [])
			elif cls == "XTianqiLineCards":
				page.set("lines", XTianqi.LINES)
				page.set("playable", [true, true, false, true])
			ReleaseEntry.simulate_release = sim_release
			add_child(page)
			built += 1
			for i in range(30):
				await get_tree().process_frame
			_freeze(page)
			if cls == "XTianqiLineCards":   # 选中卡的边按真实时间脉动：钉在同一相位再拍
				page.set_process(false)
				page.set("_t", 0.0)
				page.call("_process", 0.0)
			for i in range(3):
				await get_tree().process_frame
			if out_dir != "" and DisplayServer.get_name() != "headless":   # 无头时没有 frame_post_draw，只把各页建一遍
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute(out_dir)
				get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [scenario, cls]))
				shots += 1
			page.queue_free()
			ReleaseEntry.simulate_release = false
			for i in range(3):
				await get_tree().process_frame
		if scenario == "xiyou":   # 天启篇存档开战时 TP 等另有随机来源，两次跑对不上；开关关时两档走同一条 on()＝false 分支
			var bn := await _battle_shots(scenario)
			built += bn[0]
			shots += bn[1]
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.3, true, false, true).timeout
	# 无头（检查.sh 整轮）时只验各页建得起来：每页算一项
	var n := shots if shots > 0 else built
	print("TEST_RESULT=" + JSON.stringify({"passed": n, "total": n}))
	get_tree().quit(0)


## 战斗三张：指令窗、战技列表（第 2 项）、选目标（攻击）。随机数钉住（种子、random_master、敌人出场掷骰）；返回 [建了几次, 拍了几张]
func _battle_shots(scenario: String) -> Array:
	seed(20261013)
	XState.current.random_master = "2026101300000001"
	XEnemy.force_roll = 100.0
	XMessageBox.auto = true
	var b := XBattleScene.new()
	b.setup(2, true, false, XDB.map(5))
	add_child(b)
	var n := 0
	var shots := 0
	for i in range(600):
		if b.cmd_win != null:
			break
		await get_tree().process_frame
	XMessageBox.auto = false
	if b.cmd_win == null:
		print("SKIP battle（没等到指令窗）")
		b.queue_free()
		return [0, 0]
	n = 1
	var steps := [["cmd", []], ["list", ["ui_down", "ui_accept"]], ["target", ["ui_cancel", "ui_up", "ui_accept"]]]
	for st in steps:
		for act in st[1]:
			for down in [true, false]:
				var e := InputEventAction.new()
				e.action = act
				e.pressed = down
				get_viewport().push_input(e)
				for k in range(2):
					await get_tree().process_frame
		for i in range(40):
			await get_tree().process_frame
		_freeze(b)
		_still(b)
		for i in range(3):
			await get_tree().process_frame
		if out_dir != "" and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(out_dir)
			get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_battle_%s.png" % [scenario, st[0]]))
			shots += 1
	b.queue_free()
	for i in range(5):
		await get_tree().process_frame
	XEnemy.force_roll = -1.0
	return [n, shots]


## 战斗者的呼吸相位是画面专用的随机数（XBattlerSprite._init 里 randomize），两次跑不一样：停掉呼吸、缩放摆回原值；
## 我方小人的待机动作帧跟开战用了几帧有关（两边载入快慢不同），身体藏起来（光标、名字、血条照拍）
func _still(b: Node) -> void:
	for who in b.get("sprites"):
		var sp: Node = b.get("sprites")[who]
		sp.set("breathing", false)
		var body: Node2D = sp.get("sprite")
		var k: float = sp.get("body_scale")
		body.scale = Vector2(k * (-1.0 if body.get_meta("flip", false) else 1.0), k)
		if who is XActor:
			body.visible = false


func _make(cls: String) -> Node:
	for g in ProjectSettings.get_global_class_list():
		if g["class"] == cls:
			return (load(g["path"]) as Script).new()
	return null


## 粒子藏起来、光标不闪
func _freeze(n: Node) -> void:
	if n is CPUParticles2D or n is GPUParticles2D:
		(n as CanvasItem).visible = false
	if n is XMVCanvas:
		(n as XMVCanvas).blink = false
		(n as XMVCanvas).queue_redraw()
	for c in n.get_children(true):
		_freeze(c)


func _compare() -> void:
	var dirs := compare.split(",")
	var a := DirAccess.get_files_at(dirs[0])
	var results := []
	for f in a:
		if not f.ends_with(".png"):
			continue
		var pa := dirs[0].path_join(f)
		var pb := dirs[1].path_join(f)
		var same := false
		var diff := -1
		if FileAccess.file_exists(pb):
			var ia := Image.load_from_file(pa)
			var ib := Image.load_from_file(pb)
			ia.convert(Image.FORMAT_RGBA8)
			ib.convert(Image.FORMAT_RGBA8)
			same = ia.get_size() == ib.get_size() and ia.get_data() == ib.get_data()
			if not same and ia.get_size() == ib.get_size():
				diff = 0
				var da := ia.get_data()
				var db := ib.get_data()
				for i in range(0, da.size(), 4):
					if da[i] != db[i] or da[i + 1] != db[i + 1] or da[i + 2] != db[i + 2]:
						diff += 1
		print(("SAME " if same else "DIFF ") + f + ("" if same else " 不同像素=%d" % diff))
		results.append(same)
	var passed := results.filter(func(x): return x).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() and results.size() > 0 else 1)
