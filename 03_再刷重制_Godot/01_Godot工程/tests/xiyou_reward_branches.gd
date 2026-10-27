extends Node
## 奖励分支清账（期十一）：
## 1. 事件里「变量＝常数」的分支梯（副本奖励页按 var94／var140 发装备、抽奖公共事件按变量发物品……）逐支对照数据：
##    把每个梯（同一指令列表里同一变量、同一缩进、≥3 支、分支体里有 126／127／128 加常数）单独抽成合成指令列表，
##    变量设成各支的值，在 MVInterpreter 上真跑，所得物品／武器／防具必须恰好等于数据里那一支（含同值多支的合并），
##    变量取 0 时一件不得。条件梯外面的门槛（如「队里有角色 38」）不在这里，由各楼层专项和 xiyou_event_compare 覆盖。
## 2. 更衣解锁脚本（ConfigManager.ChangeClothesLite）：切片里每一处 355／655 脚本都真跑 MVScript.run，
##    每个写进去的更衣号必须落进解锁表（写法不匹配的就解锁不了，这里会失败）。
## 来源是转换产物 generated/（由冻结 v0.28 转换，同步时已核对），不另读冻结源。
const MIN_BRANCHES := 3
## 已知缺口：CE367 牛头人酋长原文写成 if(indexOf(-33)==-1){push(-12)}（判断号与写入号不同），MVScript 只认两号相同的写法，-12 解锁不了
const KNOWN_CLOTHES_GAPS := [["CE0367", -12]]

var results: Array = []
var groups := 0
var branches := 0
var skipped_nested := 0


class Host extends Node:
	var toasts := 0
	func toast(_t: String) -> void:
		toasts += 1

	func refresh_events() -> void:
		pass


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _lists() -> Array:
	## [标签, 指令列表]
	var out := []
	var manifest: Dictionary = XDB.load_json("manifest.json")
	for id in manifest.slice.maps:
		for ev in XDB.map(int(id)).get("events", []):
			if not ev is Dictionary:
				continue
			for p in ev.pages.size():
				out.append(["Map%03d/EV%03d/p%d" % [int(id), int(ev.id), p + 1], ev.pages[p].list])
	for id in manifest.slice.commonEvents:
		out.append(["CE%04d" % int(id), XDB.rec("CommonEvents", int(id)).get("list", [])])
	return out


## 一个指令列表里的分支梯：{(变量,缩进): [[值, [[种类,编号,数量]…]]…]}
func _ladders(list: Array) -> Dictionary:
	var found := {}
	for i in list.size():
		var c: Dictionary = list[i]
		if int(c.code) != 111 or int(c.parameters[0]) != 1 or int(c.parameters[2]) != 0 or int(c.parameters[4]) != 0:
			continue
		var ind := int(c.indent)
		var gains := []
		var nested := false
		var j := i + 1
		while j < list.size() and not (int(list[j].indent) == ind and [411, 412].has(int(list[j].code))) and int(list[j].indent) > ind:
			var d: Dictionary = list[j]
			if int(d.indent) == ind + 1:
				if int(d.code) == 111:
					nested = true
				elif [126, 127, 128].has(int(d.code)) and int(d.parameters[1]) == 0 and int(d.parameters[2]) == 0:
					gains.append([int(d.code), int(d.parameters[0]), int(d.parameters[3])])
			j += 1
		if gains.is_empty():
			continue
		if nested:
			skipped_nested += 1
			continue
		var key := "%d@%d" % [int(c.parameters[1]), ind]
		if not found.has(key):
			found[key] = []
		found[key].append([int(c.parameters[3]), gains])
	return found


func _count(s: XState, kind: int, id: int) -> int:
	if kind == 126:
		return s.item_count(id)
	return s.gear_count("weapon" if kind == 127 else "armor", id)


func _run_ladder(s: XState, host: Host, var_id: int, ind: int, rows: Array, value: int) -> Array:
	## 合成列表：每支「if var==值」＋它的加常数指令＋end
	var cmds := []
	for r in rows:
		cmds.append({"code": 111, "indent": 0, "parameters": [1, var_id, 0, int(r[0]), 0]})
		for g in r[1]:
			cmds.append({"code": g[0], "indent": 1, "parameters": [g[1], 0, 0, g[2]]})
		cmds.append({"code": 0, "indent": 1, "parameters": []})
		cmds.append({"code": 412, "indent": 0, "parameters": []})
	cmds.append({"code": 0, "indent": 0, "parameters": []})
	s.set_variable(var_id, value)
	var seen := {}
	for r in rows:
		for g in r[1]:
			seen["%d:%d" % [g[0], g[1]]] = [g[0], g[1]]
	var before := {}
	for k in seen:
		before[k] = _count(s, seen[k][0], seen[k][1])
	var interp := MVInterpreter.new(host, 1, 0, cmds)
	await interp.run()
	var delta := {}
	for k in seen:
		var d := _count(s, seen[k][0], seen[k][1]) - int(before[k])
		if d != 0:
			delta[k] = d
	return [delta, interp.skipped]


func _expect(rows: Array, value: int) -> Dictionary:
	var e := {}
	for r in rows:
		if int(r[0]) == value:
			for g in r[1]:
				var k := "%d:%d" % [g[0], g[1]]
				e[k] = int(e.get(k, 0)) + int(g[2])
	return e


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_reward_branches"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var host := Host.new()
	add_child(host)
	var lists := _lists()
	var bad := 0
	var rows_run := 0
	for L in lists:
		var ladders := _ladders(L[1])
		for key in ladders:
			var rows: Array = ladders[key]
			if rows.size() < MIN_BRANCHES:
				continue
			var parts: PackedStringArray = str(key).split("@")
			var var_id := int(parts[0])
			groups += 1
			branches += rows.size()
			var values := {}
			for r in rows:
				values[int(r[0])] = true
			var vals: Array = values.keys()
			vals.append(0 if not values.has(0) else -999)
			for v in vals:
				var res = await _run_ladder(s, host, var_id, int(parts[1]), rows, int(v))
				rows_run += 1
				var want := _expect(rows, int(v))
				if res[0] != want or not res[1].is_empty():
					bad += 1
					if bad <= 12:
						print("FAIL ladder ", L[0], " var", var_id, "=", v, " 得 ", JSON.stringify(res[0]), " 应 ", JSON.stringify(want), " 跳过 ", JSON.stringify(res[1]))
	_check("ladders_found", groups >= 40, groups)
	_check("ladders_all_branches", bad == 0, bad)
	print("梯：", groups, " 个，分支 ", branches, " 支，真跑 ", rows_run, " 次；含嵌套条件而略过 ", skipped_nested, " 支")
	await _clothes(lists)
	_finish()


func _chains(list: Array) -> Array:
	var out := []
	var i := 0
	while i < list.size():
		if int(list[i].code) == 355:
			var code := str(list[i].parameters[0])
			while i + 1 < list.size() and int(list[i + 1].code) == 655:
				i += 1
				code += "\n" + str(list[i].parameters[0])
			out.append(code)
		i += 1
	return out


func _clothes(lists: Array) -> void:
	var re := RegEx.create_from_string("ChangeClothesLite\\.push\\((-?\\d+)\\)")
	var sites := 0
	var ids := {}
	var bad := []
	for L in lists:
		for code in _chains(L[1]):
			if not code.contains("ChangeClothesLite"):
				continue
			sites += 1
			XConfig.clothes_unlocked().clear()
			await MVScript.run(code, null)
			for m in re.search_all(code):
				var id := int(m.get_string(1))
				ids[id] = true
				if not XChangeClothes.unlocked(id) and not KNOWN_CLOTHES_GAPS.has([L[0], id]):
					bad.append([L[0], id])
	XConfig.clothes_unlocked().clear()
	_check("clothes_sites", sites >= 40, sites)
	_check("clothes_all_unlock", bad.is_empty(), bad.slice(0, 10))
	print("更衣解锁：", sites, " 处脚本，涉及 ", ids.size(), " 个更衣号")


func _finish() -> void:
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
