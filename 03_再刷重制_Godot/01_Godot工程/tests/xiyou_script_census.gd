extends Node
## 事件脚本认不认得的普查：切片里每张地图的事件页与全部公共事件，把脚本（355＋655）、插件指令（356）、
## 脚本条件（111 类型 12）、变量操作的脚本／游戏数据操作数（122 操作数 4／3）各拿一份不同写法，在记录替身宿主上交给 MVInterpreter 同一入口跑，
## 看 skipped 里有没有它（认不出的运行时会照原文记 skipped、跳过；内容覆盖检查只看指令码，看不出这一层）。
## 结果按写法去重，带出现位置（Map/EV/页、CE），写到 user://script_census.json 并逐条打印 CENSUS 行；
## 断言：认不出的写法都在 KNOWN 里（新出现的认不出写法会挂），KNOWN 里已经认得的也挂（提醒删掉）。
## 只读数据；跑脚本的副作用落在一局空白新游戏上，每条写法前重开。
const EC := preload("res://tests/xiyou_event_compare.gd")
const OUT := "user://script_census.json"
## 已知认不出的写法（键＝种类|原文前 80 字）；现状清单，补一条删一条
const KNOWN := {}

var results: Array = []
var host


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


## 收集：写法 → {kind, code, params, where[]}
func _collect() -> Dictionary:
	var out := {}
	var add := func(kind: String, code, where: String):
		var key: String = kind + "|" + str(code).left(80)
		if not out.has(key):
			out[key] = {"kind": kind, "code": code, "where": []}
		if out[key].where.size() < 12:
			out[key].where.append(where)
		out[key]["n"] = int(out[key].get("n", 0)) + 1
	var scan := func(list: Array, where: String):
		var i := 0
		while i < list.size():
			var c: Dictionary = list[i]
			var p: Array = c.get("parameters", [])
			match int(c.code):
				355:
					var code := str(p[0])
					while i + 1 < list.size() and int(list[i + 1].code) == 655:
						i += 1
						code += "\n" + str(list[i].parameters[0])
					add.call("script", code, where)
				356:
					add.call("plugin", str(p[0]), where)
				111:
					if int(p[0]) == 12:
						add.call("cond", str(p[1]), where)
				122:
					if int(p[3]) in [3, 4]:
						add.call("var", JSON.stringify(c), where)
			i += 1
	for id in range(1, 260):
		var m := XDB.map(id)
		if m.is_empty():
			continue
		for e in m.get("events", []):
			if e == null:
				continue
			var pages: Array = e.get("pages", [])
			for k in pages.size():
				scan.call(pages[k].get("list", []), "Map%03d/EV%03d/p%d" % [id, int(e.id), k + 1])
	var ces = XDB.table("CommonEvents")
	for ce in ces:
		if ce != null and ce is Dictionary and not ce.get("list", []).is_empty():
			scan.call(ce.list, "CE%d" % int(ce.id))
	return out


## 跑一条写法，返回认不出的原文（认得返回 []）
func _try(row: Dictionary) -> Array:
	var s := XState.new_game_blank()
	s.add_actor(1)
	s.map_id = 4
	# 公共事件常用的「选中角色」：变量 348／881／884 存角色号、物品选中的角色；都给 1 号，免得因为没选人而认不出
	for v in [348, 881, 884]:
		s.set_variable(v, 1)
	s.item_target_actor_id = 1
	XState.current = s
	var it := MVInterpreter.new(host, 4, 1, [])
	match row.kind:
		"script":
			return await MVScript.run(str(row.code), it)
		"plugin":
			it._plugin_command(str(row.code))
		"cond":
			it._condition([12, str(row.code)])
		"var":
			await it._execute(JSON.parse_string(str(row.code)))
	return it.skipped.map(func(x): return str(x.text))


func _run() -> void:
	GameApp.fast_headless_frames()
	XSave.dir_override = "user://test_xiyou_script_census"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XShop.auto_close = true
	host = EC.EventHost.new()
	add_child(host)
	var rows := _collect()
	var unknown := {}
	for key in rows:
		var miss: Array = await _try(rows[key])
		if not miss.is_empty():
			var r: Dictionary = rows[key]
			r["miss"] = miss
			unknown[key] = r
			print("CENSUS ", JSON.stringify({"key": key, "n": r.n, "where": r.where, "miss": miss.slice(0, 3)}))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"total": rows.size(), "unknown": unknown}, "  "))
	print("CENSUS_TOTAL ", rows.size(), " UNKNOWN ", unknown.size())
	_check("collected", rows.size() > 100, rows.size())
	var new_keys := unknown.keys().filter(func(k): return not KNOWN.has(k))
	_check("no_new_unknown", new_keys.is_empty(), new_keys.slice(0, 20))
	var fixed := KNOWN.keys().filter(func(k): return rows.has(k) and not unknown.has(k))
	_check("known_still_unknown", fixed.is_empty(), fixed)
	_finish()


func _finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
