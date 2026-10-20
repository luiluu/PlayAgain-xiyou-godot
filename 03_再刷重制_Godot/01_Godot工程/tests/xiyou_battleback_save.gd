extends Node
## 指令 283 更改战斗背景随存档（悟空_24 低级项）：与 mv_oracle/review_fix_probe.cjs 的 battleback.* 逐例比。
## 原版 $gameMap 整个进存档、同版本读档不重设地图，所以改过的战斗背景读档后还在；同图移动不 setup，也还在；
## 换到别的地图 setupBattleback 重设为地图指定（Map004 不指定＝null），再回 Map055 是它自己指定的 Translucent／Temple。
## 真实 XMapScene 跑公共事件 1387（283）、真实 XSave 存读档后重开地图场景、真实 transfer。
## battleback.versionReload（改版本号后 reloadMapIfUpdated 重载本图）重制没有这条路径，只核参照本身。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const ORACLE := "res://modes/xiyou/generated/oracle/review_fix.json"
const TIMEOUT_MS := 60000

var results: Array = []
var s: XState


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	# 换场景时测试节点不能挂在当前场景下，挂到根节点
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _wait_map(map_id: int) -> XMapScene:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		var m = get_tree().current_scene
		if m is XMapScene and m.map_id == map_id and m.player != null and not m.busy:
			return m
		await get_tree().process_frame
	return null


func _open(map_id: int) -> XMapScene:
	get_tree().change_scene_to_file(MAP_SCENE)
	return await _wait_map(map_id)


## 开战时实际用的两张图；地图不指定时同原版 $gameMap.battleback1Name() 的 null
static func _names(map: XMapScene) -> Array:
	var bm := map.battle_map()
	return [str(bm.battleback1Name), str(bm.battleback2Name)] if bool(bm.get("specifyBattleback", false)) else [null, null]


## 新局站在 Map055 跑公共事件 1387；返回改前改后
func _changed() -> Dictionary:
	s = XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 55
	s.x = 10
	s.y = 17
	var map := await _open(55)
	if map == null:
		return {}
	var out := {"before": _names(map)}
	await map.run_common_event(1387)
	out.after = _names(map)
	return out


## XSave 真存档再读档，重开地图场景（同 Scene_Load → Scene_Map，不重设地图）
func _roundtrip() -> XMapScene:
	if not XSave.save(1) or not XSave.load_slot(1):
		return null
	s = XState.current
	return await _open(s.map_id)


func _case(id: String) -> Dictionary:
	var out := await _changed()
	if out.is_empty():
		return {"error": "Map055 未载入"}
	var map := await _roundtrip()
	if map == null:
		return {"error": "存读档后地图未载入"}
	match id:
		"battleback.save":
			out.saved = s.battleback
			out.loaded = _names(map)
			out.battle = _names(map)
			out.map = float(map.map_id)  # JSON 读出的参照数字是 float
		"battleback.sameMap":
			await map.transfer(55, 11, 17, 2)
			map = await _wait_map(55)
			out.after = _names(map)
			out.battle = _names(map)
		"battleback.otherMap":
			out.erase("before")
			out.erase("after")
			await map.transfer(4, 14, 23, 2)
			map = await _wait_map(4)
			out.left = _names(map)
			await map.transfer(55, 10, 17, 2)
			map = await _wait_map(55)
			out.back = _names(map)
	return out


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_battleback_save"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	var cases: Array = (data.cases if data is Dictionary else []).filter(func(c): return str(c.id).begins_with("battleback."))
	if _check("oracle_cases", cases.size() == 4, cases.map(func(c): return c.id)):
		for c in cases:
			if not c.errors.is_empty():
				_check("oracle_" + c.id, false, c.errors)
				continue
			var want: Dictionary = c.observed
			if c.id == "battleback.versionReload":
				_check(c.id + ".mv_resets", want.reserved and want.after == ["Translucent", "Temple"], want)
				continue
			var got := await _case(c.id)
			_check(c.id, JSON.stringify(got) == JSON.stringify(want), [got, want])
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_battleback_save", "passed": results.size() - failed.size(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
