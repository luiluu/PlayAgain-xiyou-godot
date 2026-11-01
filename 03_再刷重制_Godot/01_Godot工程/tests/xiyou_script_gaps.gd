extends Node
## 事件脚本普查第一批（悟空 events1，xiyou_script_census 列出的认不出写法里玩家看得到的）：
## - 大厅小盖盖调速（Map004 EV044）：$gamePlayer._moveSpeed = 3／4／5 → XState.player_move_speed；走路速度＝它＋冲刺 1（realMoveSpeed），随存档；
##   对照 mv_oracle/script_gaps_probe（generated/oracle/script_gaps.json）的 moveSpeed.*；下载具回 4（getOffVehicle setMoveSpeed(4)）另核。
## - 牛头人／纯爱战士认证（Map017 EV004）：条件分支脚本 $gameSystem.defeatNumber(66) >= 999／9999 → XEnemyBook.defeat_number；
##   对照 defeat.* 各例的分支；再用真事件页（选「认证 牛头人」）核 999 只时开称号 5、成就 121，998 只时不开。
## - 大厅猫哥「清理存档」（Map004 EV024）DataManager.cleanupIndependentItems()：无操作，不再记认不出。
## 反向：写法稍变（速度写成变量、击败数写成别的对象）仍记认不出。
const REF := "oracle/script_gaps.json"

var results: Array = []
var toasts: Array = []
var messages: Array = []


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


## 解释器的 host：只提供这些脚本与事件页用到的服务
func toast(text: String) -> void:
	toasts.append(text)


func show_message(msg: Dictionary) -> int:
	messages.append(msg)
	return 0   # 选项取第一项（「正常」／「认证 牛头人」）


func refresh_events() -> void:
	pass


func script(code: String) -> Array:
	return await MVScript.run(code, MVInterpreter.new(self, 0, 0, []))


func _ready() -> void:
	_run.call_deferred()


func _ref() -> Dictionary:
	var out := {}
	for c in XDB.load_json(REF).cases:
		out[str(c.id)] = c
	return out


func _speed(ref: Dictionary) -> void:
	for speed in [3, 4, 5]:
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		var miss: Array = await script("$gamePlayer._moveSpeed = %d" % speed)
		var o: Dictionary = ref["moveSpeed.%d" % speed].observed
		var p := MVPlayer.new()
		p.touch_target = Vector2i(-1, -1)
		var walk := p.walk_speed()
		p.dash = true
		p.touch_target = Vector2i(0, 0)   # 点地走路算冲刺（is_dashing）
		var dash := p.walk_speed()
		p.free()
		var loaded := XState.from_dict(s.to_dict())
		_check("speed%d" % speed, miss.is_empty() and s.player_move_speed == int(o.moveSpeed) and walk == int(o.walk) and dash == int(o.dash)
			and loaded.player_move_speed == int(o.afterLoad), [miss, s.player_move_speed, walk, dash, loaded.player_move_speed, o])
	# 旧存档没有这个字段：照新游戏 4
	var d := XState.new_game(3, 1, [8, 9, 10]).to_dict()
	d.erase("playerMoveSpeed")
	_check("speed_old_save", XState.from_dict(d).player_move_speed == 4)
	# 反向：速度写成变量，仍认不出
	_check("speed_var_unknown", (await script("$gamePlayer._moveSpeed = $gameVariables.value(1)")).size() == 1)


func _defeat(ref: Dictionary) -> void:
	for id in ref:
		if not str(id).begins_with("defeat."):
			continue
		var c: Dictionary = ref[id]
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		for i in int(c.setup.kills):
			XEnemyBook.add_defeat(s, 66)
		var it := MVInterpreter.new(self, 0, 0, [
			{"code": 111, "indent": 0, "parameters": [12, str(c.setup.condition)]},
			{"code": 122, "indent": 1, "parameters": [1, 1, 0, 0, 1]}, {"code": 0, "indent": 1, "parameters": []},
			{"code": 411, "indent": 0, "parameters": []},
			{"code": 122, "indent": 1, "parameters": [1, 1, 0, 0, 2]}, {"code": 0, "indent": 1, "parameters": []},
			{"code": 412, "indent": 0, "parameters": []}, {"code": 0, "indent": 0, "parameters": []}])
		await it.run()
		_check(str(id), it.skipped.is_empty() and XEnemyBook.defeat_number(s, 66) == int(c.observed.defeatNumber) and int(s.variable(1)) == int(c.observed.branch),
			[it.skipped, XEnemyBook.defeat_number(s, 66), s.variable(1), c.observed])
	# 真事件页：选「认证 牛头人」；999 只开称号 5、成就 121，998 只不开
	for kills in [998, 999]:
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		for i in kills:
			XEnemyBook.add_defeat(s, 66)
		var page: Dictionary = XDB.map(17).events[4].pages[0]
		var it := MVInterpreter.new(self, 17, 4, page.list)
		await it.run()
		var ok: bool = kills >= 999
		_check("map17_ev4_%d" % kills, it.skipped.is_empty() and XDesignation.unlocked(5) == ok and s.achievements.has("121") == ok,
			[it.skipped, XDesignation.unlocked(5), s.achievements.keys()])
	# 反向：别的对象上的同名函数仍认不出（按假走）
	var it2 := MVInterpreter.new(self, 0, 0, [])
	it2._condition([12, "$gameTroop.defeatNumber(66) >= 1"])
	_check("defeat_other_unknown", it2.skipped.size() == 1, it2.skipped)


func _cleanup() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var before := JSON.stringify(s.gear)
	var miss: Array = await script("DataManager.cleanupIndependentItems();")
	_check("cleanup_noop", miss.is_empty() and JSON.stringify(s.gear) == before, miss)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_script_gaps"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	var ref := _ref()
	_check("ref_loaded", ref.size() == 10, ref.size())
	await _speed(ref)
	await _defeat(ref)
	await _cleanup()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
