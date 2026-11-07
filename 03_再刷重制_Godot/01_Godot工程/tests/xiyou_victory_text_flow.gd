extends Node
## 胜利结算 → 胜利提示 → 回地图 的完整路径（审查报告第 3 项，O-190）：饿狼第一次满足「神之触媒」（5 阶、55 级、累计突破够、Boss 战），
## 战斗主循环自动打赢，结算页出来后全部用 Input.parse_input_event 发真实按键／左键（走视口分发：_input → _unhandled_input），
## 关掉结算页后消息窗显示神之触媒提示、确定键能关、战斗发出 finished(0)。修之前结算页的 _input 关后还在吞确定，提示关不掉。
## 只在内存里，不写存档。

var results := []


func check(tag: String, ok: bool, detail = null) -> void:
	results.append({"name": tag, "passed": ok})
	if not ok:
		print("FAIL ", tag, " ", JSON.stringify(detail))


func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func press(action: String) -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)
		await frames(2)


func click() -> void:
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = Vector2(640, 360)
		ev.global_position = ev.position
		Input.parse_input_event(ev)
		await frames(2)


func _victory_screen(b: XBattleScene) -> XVictoryScreen:
	for n in b.ui.get_children():
		if n is XVictoryScreen:
			return n
	return null


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_victory_text_flow"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = false
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true  # 超强角色可出战
	s.add_actor(XGarou.ACTOR)
	s.actor_advance[XGarou.ACTOR] = 5
	var a := s.actor(XGarou.ACTOR)
	a.change_level_mv(55)
	XGarou.sync(a)
	for m in s.battle_members():
		m.add_param(0, 1e12)
		m.add_param(2, 1e6)
		m.recover_all()
	s.garou["breakthroughs"] = 340.0
	var b := XBattleScene.new()
	b.setup(2, true, false, XDB.map(5))
	var ended := [-1]
	b.finished.connect(func(code): ended[0] = code)
	add_child(b)
	await frames(2)
	b.logic._garou_boss = true  # 神之触媒只在 Boss 战给（G._bossBattle）；夹具敌群没有 Boss 血条，直接记成 Boss 战
	for e in b.logic.enemies:
		e.hp = 1.0
	b.logic.auto = true
	var screen: XVictoryScreen = null
	for i in 3000:
		screen = _victory_screen(b)
		if screen != null or ended[0] != -1:
			break
		await frames(1)
	check("victory_screen.shown", screen != null, ended[0])
	if screen == null:
		return finish(b)
	screen.automatic = false  # 自动战斗打完的结算页会自己关；这里要手按，关掉自动
	b.logic.auto = false
	await frames(30)
	await press("ui_accept")   # 第一下：经验条走完、出「继续」提示
	await click()               # 第二下（左键）：关结算页
	await frames(10)
	check("catalyst.granted", s.item_count(XGarou.CATALYST) == 1 and b.logic.victory_texts == [XGarou.CATALYST_TEXT], [s.item_count(XGarou.CATALYST), b.logic.victory_texts])
	await frames(90)
	check("message.shown_and_waits", b.message.visible and b.message.is_busy() and ended[0] == -1, [b.message.visible, b.message.is_busy(), ended[0]])
	for i in 20:
		if ended[0] != -1:
			break
		await press("ui_accept")
		await frames(5)
	check("battle.finished_to_map", ended[0] == 0 and not b.message.is_busy(), [ended[0], b.message.is_busy()])
	finish(b)


func finish(b: Node) -> void:
	XMessageBox.auto = true
	if is_instance_valid(b):
		b.queue_free()
	await frames(3)
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() and results.size() > 0 else 1)
