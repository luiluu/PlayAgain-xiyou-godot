extends Node
## 换装卡战斗外观（八戒_71 期一）：与原版同一场面（ui_reference/review_system_pages.js 的 battle_costume：地图 5、敌群 2、难度 3、
## 狗逍遥／修／罗琳／美娜，狗逍遥学会 6801「变身——深渊骑士」，开战推上状态 1201）。核对各角色精灵的图、格子尺寸与站位
## （tests/fixtures/battle_costume_oracle.json），再关掉狗逍遥的换装开关看换回自身形态。内存新游戏，不写存档。
## 窗口模式加 -- --out=<目录> 截 battle_costume_card.png（标准级成对截图）。

const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const FIXTURE := "res://tests/fixtures/battle_costume_oracle.json"
var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
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


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw(false)
	_check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


func _battle(map: XMapScene) -> XBattleScene:
	for c in map.ui.get_children():
		if c is XBattleScene:
			return c
	return null


func _run() -> void:
	XMessageBox.auto = true
	XEnemy.force_roll = 100.0
	seed(20261013)
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.random_master = "2026101300000001"
	s.actor(1).learn_skill(6801)
	s.map_id = 5
	s.x = 10
	s.y = 10
	s.direction = 2
	get_tree().change_scene_to_file(MAP_SCENE)
	var ok := await _until(func(): return get_tree().current_scene is XMapScene and get_tree().current_scene.player != null and not get_tree().current_scene.busy)
	_check("map5_loaded", ok)
	var map: XMapScene = get_tree().current_scene
	await _frames(10)
	XMessageBox.auto = false
	map._set_busy(true)
	var go := func(): await map.start_battle(2, true, false)
	go.call()
	ok = await _until(func(): return _battle(map) != null and _battle(map).cmd_win != null)
	_check("command_shown", ok)
	var b: XBattleScene = _battle(map)
	if b == null:
		_finish()
		return
	await _frames(30)
	var got := []
	for a in b.logic.actors:
		var sp: XBattlerSprite = b.sprites[a]
		var tex = sp.look.frame("walk", 0).get("tex")
		got.append({"actor": a.actor_id, "image": str(tex.resource_path).get_file().get_basename() if tex else "", "states": a.state_ids.duplicate(),
			"cell": [sp.look.cell.x, sp.look.cell.y], "home": [sp.home.x, sp.home.y]})
	var want: Array = ref.actors.map(func(r): return {"actor": int(r.actor), "image": str(r.bitmap[0]).get_file().get_basename(), "states": r.states.map(func(x): return int(x)),
		"cell": [float(r.frame[2]), float(r.frame[3])], "home": [float(r.x), float(r.y)]})
	_check("actors_like_original", JSON.stringify(got) == JSON.stringify(want), {"got": got, "want": want})
	await _shot("battle_costume_card")
	# 关掉开关（原版设置页只在战斗外可开；这里直接改，看精灵按外观键换回自身形态）
	var a1: XActor = b.logic.actors[0]
	XCostumes.set_enabled(s, 1, false)
	b.show_views(b.logic.views([a1]))
	await _frames(3)
	var tex1 = b.sprites[a1].look.frame("walk", 0).get("tex")
	_check("disabled_back_to_own", tex1 != null and str(tex1.resource_path).get_file().get_basename() == str(a1.data().battlerName), tex1.resource_path if tex1 else null)
	XCostumes.set_enabled(s, 1, true)
	_finish()


func _finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
