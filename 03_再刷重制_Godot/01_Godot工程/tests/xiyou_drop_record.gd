extends Node
## 设置「开启掉落动画」（MOG_TrPopUpBattle）与「战斗伤害记录」（Star_CombatDamageRecord＋Bailong 精确版）：
## 伤害数字写法、记录窗位置与按栏位计数、掉落图标逐帧弹跳/淡出，以及实战里倒下即得、胜利不重复发放、记录随结算移除；
## 两项关闭时不弹图标、不建记录、胜利时才发放。配置只写测试目录。窗口模式加 -- --out=<目录> 截图。

var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", detail)


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func until(f: Callable, limit := 6000) -> bool:
	for i in limit:
		if f.call():
			return true
		await get_tree().physics_frame
	return f.call()


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name))


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_drop_record"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	seed(20261014)
	_format()
	_record_unit()
	_popup_unit()
	var s := XState.new_game(3, 1, [8, 10, 9])
	s.map_id = 5
	s.x = 11
	s.y = 13
	var map := XMapScene.new()
	add_child(map)
	await frames(4)
	# 两项都开
	XConfig.set_flag("MOG_TrPopUpBattle_Key", true)
	XConfig.set_flag("CombatDamageRecordKey", true)
	await _battle_on(map, s)
	# 两项都关
	XConfig.set_flag("MOG_TrPopUpBattle_Key", false)
	XConfig.set_flag("CombatDamageRecordKey", false)
	await _battle_off(map, s)
	map.queue_free()
	await frames(2)
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	XBattleScene.force_auto = false
	XEnemy.force_roll = -1.0
	Engine.time_scale = 1.0
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _format() -> void:
	var f := XDamageRecord.format_damage
	var got := [f.call(0.0), f.call(9999.0), f.call(10000.0), f.call(15000.0), f.call(123456789.0), f.call(1e12), f.call(25e15), f.call(3e28)]
	check("format_damage", got == ["0", "9999", "1万", "1.5万", "1.23亿", "1兆", "2.5京", "3穰"], got)


func _record_unit() -> void:
	var r := XDamageRecord.new()
	r.setup([1, 8, 0, 10, 9], 4)
	add_child(r)
	check("record_rect", r.size == Vector2(248, 108) and r.position == Vector2(1020, 600), [r.position, r.size])
	var a := XActor.new()
	a.actor_id = 10
	var e := XEnemy.new()
	r.record(a, e, 1234.7)
	r.record(e, a, 500.0)          # 敌人打角色不计
	r.record(a, a, 500.0)          # 角色打角色不计（Bailong 只计敌人目标）
	r.record(a, e, -30.0)          # 治疗不计
	check("record_slot", r.values == [0.0, 0.0, 0.0, 1234.0, 0.0] and r.total() == 1234.0, r.values)
	r.queue_free()


func _popup_unit() -> void:
	var host := Node2D.new()
	host.position = Vector2(300, 400)
	add_child(host)
	var p := XDropPopup.new()
	add_child(p)
	p.set_physics_process(false)
	var items := [XDB.rec("Items", 1), XDB.rec("Items", 1), XDB.rec("Items", 1)]
	p.setup(host, 96.0, items)
	var ints: Array = p.icons.map(func(g): return g.intY)
	var sorted := ints.duplicate()
	sorted.sort()
	sorted.reverse()
	check("popup_setup", p.icons.size() == 3 and ints == sorted and p.icons.map(func(g): return g.wait) == [70, 50, 30]
		and p.icons.all(func(g): return g.intY >= 0.0 and g.intY <= 31.0 and g.y == -40.0 and absf(g.vx) <= 0.5 + 2.0 / 8.0), [ints, p.icons.map(func(g): return g.wait)])
	# 弹跳：落下、横移，最后停在 −intY；停稳后第一个淡出的是排在最后（wait 最小）的
	var landed := -1
	for f in range(1, 200):
		p.step()
		if landed < 0 and p.icons.all(func(g): return g.y == -g.intY and absf(g.dy) < 1.0):
			landed = f
	check("popup_lands_and_fades", landed > 0 and p.done() and p.position == host.position, [landed, p.icons.map(func(g): return [g.y, g.alpha])])
	p.queue_free()
	host.queue_free()


func _start(map: XMapScene) -> Dictionary:
	var res := {"value": null, "done": false}
	map._set_busy(true)
	var go := func():
		res.value = await map.start_battle(2, true, false)
		res.done = true
	go.call()
	await until(func(): return _find_battle() != null, 600)
	return res


func _find_battle() -> XBattleScene:
	var found: Array = get_tree().root.find_children("*", "XBattleScene", true, false)
	return found[0] if not found.is_empty() else null


func _battle_on(map: XMapScene, s: XState) -> void:
	var before := s.item_count(1)
	var res := await _start(map)
	var b := _find_battle()
	check("battle_on_started", b != null)
	if b == null:
		return
	check("record_built", b.record != null and b.record.position == b._origin + Vector2(1020, 600) and b.record.get_index() < b.ui.get_index(), null if b.record == null else b.record.position)
	for e in b.logic.enemies:
		b.logic._treasure[e] = [{"kind": 1, "id": 1}]
		e.hp = 1.0
	var popped := await until(func(): return b.field.get_children().any(func(c): return c is XDropPopup))
	var gained_now := s.item_count(1) - before
	check("drop_gained_on_collapse", popped and gained_now >= 1 and b.logic.drop_lock, [popped, gained_now, b.logic.drop_lock])
	check("record_counts", b.record != null and b.record.total() > 0.0, null if b.record == null else b.record.values)
	await frames(10)
	await shot("01_掉落动画与伤害记录.png")
	var removed := await until(func(): return not is_instance_valid(b) or b.record == null)
	var no_screen := is_instance_valid(b) and not b.ui.get_children().any(func(c): return c is XVictoryScreen)
	check("record_removed_at_victory", removed and no_screen and b.logic.is_won(), [removed, no_screen])
	await until(func(): return res.done, 6000)
	check("battle_on_won", res.done and res.value == 0, res.value)
	check("drops_not_doubled", s.item_count(1) - before == 3, s.item_count(1) - before)


func _battle_off(map: XMapScene, s: XState) -> void:
	await until(func(): return not map.busy, 600)
	var before := s.item_count(1)
	var res := await _start(map)
	var b := _find_battle()
	check("battle_off_started", b != null and b.record == null)
	if b == null:
		return
	for e in b.logic.enemies:
		b.logic._treasure[e] = [{"kind": 1, "id": 1}]
		e.hp = 1.0
	var popped := false
	var mid_gain := false
	while not b.logic.is_won() and not res.done:
		popped = popped or b.field.get_children().any(func(c): return c is XDropPopup)
		mid_gain = mid_gain or s.item_count(1) != before
		await get_tree().physics_frame
	await until(func(): return res.done, 6000)
	check("off_no_popup_gain_at_victory", not popped and not mid_gain and s.item_count(1) - before == 3, [popped, mid_gain, s.item_count(1) - before])
