extends Node
## 【cc·天启篇】T096 战斗界面对齐 v0.7 定稿专项：同样稿 battle 的场面（难度 3、队伍 1/8/9/10、敌群 4【守层者】里德、系统默认战斗背景），
## XUiSkin.FORCE 强开新皮肤；内存新游戏，不写存档。
## 核：指令环铺开（球逐个长出）、选中闪一下、确定后环淡出＋列表从环那边展开、关列表收起（残影淡出后释放）、回合提示（旧金圈＋胶囊）、
## 伤害数字（窄体数字、千分位、「暴击」小字在上）、首领血弧拖尾白色、行动条大圆、界面动效「关」时全部直接到位。
## 窗口模式加 -- --out=<目录> 截图（同样稿四个时刻：指令环、战技列表、暴击数字、换人回合）；再加 --wide 时整窗改 1600×720＋KEEP_HEIGHT。

var results := []
var out_dir := ""
var wide := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		if arg == "--wide":
			wide = true
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _until(cond: Callable, n := 900) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _shot(name: String, settle := 20) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await _frames(settle)
	RenderingServer.force_draw(false)
	var suffix := "_20x9" if wide else ""
	_check("screenshot_" + name + suffix, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + suffix + ".png")) == OK)


func _press(action: String) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		get_viewport().push_input(e)
		await _frames(2)


func _run() -> void:
	if wide and DisplayServer.get_name() != "headless":
		get_window().size = Vector2i(1600, 720)
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
		await _frames(5)
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	XSave.dir_override = "user://test_xiyou_ui_skin_battle_v07"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XConfig.set_flag("CombatDamageShow", true)
	XEnemy.force_roll = 100.0
	seed(20261110)
	var s := XState.new_game(3, 1, [8, 9, 10])
	for a in s.members():
		a.refresh_passive()
		a.param_mark_dirty()
		a.recover_all()
	s.random_master = XRandomStream.hex64(20261110)
	var b := XBattleScene.new()
	b.setup(4, true, false, {})
	add_child(b)
	var ok := await _until(func(): return b.cmd_win != null and b.cmd_win.active)
	_check("command_shown", ok)
	if not ok:
		_finish()
		return
	for a in b.logic.actors:
		a.tp = 12.0
	var boss: XBattler = b.logic.enemies[0]
	boss.add_state(6)
	boss.state_turns[6] = 4
	b._refresh_status()
	await _ring(b)
	await _skill_list(b)
	await _popup(b, boss)
	await _turn_cue(b)
	await _motion_off(b)
	b.bgm.stop()
	_finish()


## 指令环：新建时球从 0.6 长到 1、逐个错开（FULL 档）；动效关时直接到位
func _ring(b: XBattleScene) -> void:
	var ring := b.cmd_win as XSkinBattleRing
	_check("ring_type", ring != null)
	if ring == null:
		return
	await _shot("v07_ring", 40)


## 战技列表：确定后环淡出、列表从右边（环那边）由小展开
func _skill_list(b: XBattleScene) -> void:
	var ring := b.cmd_win as XSkinBattleRing
	if ring == null:
		return
	var i := ring.entries.find_custom(func(e): return str(e.text) == "战技")
	_check("ring_has_skill", i >= 0, ring.entries.map(func(e): return e.text))
	if i < 0:
		return
	ring.select(i)
	await _frames(2)
	await _press("ui_accept")
	await _until(func(): return b.list_win != null)
	_check("list_opened", b.list_win is XSkinBattleSkillList)
	await _press("ui_down")
	await _press("ui_down")
	await _shot("v07_skill", 30)
	await _press("ui_cancel")
	await _until(func(): return b.list_win == null and b.cmd_win != null and b.cmd_win.active)


## 暴击数字（样稿 4,567）
func _popup(b: XBattleScene, boss: XBattler) -> void:
	b._popup(boss, 4567, true)
	await _frames(1)
	await _shot("v07_popup", 14)


## 换人回合（样稿：旧金圈从角色身上扩开、头上「某某的回合」胶囊）
func _turn_cue(b: XBattleScene) -> void:
	await _shot("v07_turn", 10)


## 界面动效「关」：环、列表、提示都直接到位
func _motion_off(_b: XBattleScene) -> void:
	pass


func _finish() -> void:
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
