extends Node
## 事件脚本认不认得的普查：切片里每张地图的事件页与全部公共事件，把脚本（355＋655）、插件指令（356）、
## 脚本条件（111 类型 12）、变量操作的脚本／游戏数据操作数（122 操作数 4／3）各拿一份不同写法，在记录替身宿主上交给 MVInterpreter 同一入口跑，
## 看 skipped 里有没有它（认不出的运行时会照原文记 skipped、跳过；内容覆盖检查只看指令码，看不出这一层）。
## 结果按写法去重，带出现位置（Map/EV/页、CE），写到 user://script_census.json 并逐条打印 CENSUS 行；
## 断言：认不出的写法都在 KNOWN 里（新出现的认不出写法会挂），KNOWN 里已经认得的也挂（提醒删掉）。
## events7b：按调用方销号——只出现在「走不到的公共事件」（清单 unreachable，测试核切片数据里确实没有调用方）里的写法不算；
## 只出现在「只在战斗里跑的公共事件」（调用方全是战斗场合的技能／物品效果、敌群页、battleRoots 及其子事件，由数据算出）里、
## 战斗事件解释器又认得的写法也不算（原 E 类；位置里另有走不到的公共事件也行，如变量 318 在 CE110／423 战斗里、CE124 走不到）。KNOWN 清到 0。
## 只读数据；跑脚本的副作用落在一局空白新游戏上，每条写法前重开。
const EC := preload("res://tests/xiyou_event_compare.gd")
const OUT := "user://script_census.json"
## 已知认不出的写法（键＝种类|完整原文 → 分类）；现状清单，补一条删一条
const KNOWN_FILE := "res://tests/fixtures/script_census_known.json"

var results: Array = []
var host
var last_logic: XBattleLogic   # 最近一次 _try_battle 用的战斗，供读敌人数据的断言取值


## 记录替身宿主再补上地图宿主才有的界面入口（脚本按 has_method 找它们；没有就当认不出）
class CensusHost:
	extends EC.EventHost
	func open_achievements() -> void: pass
	func open_actor_book() -> void: pass
	func open_enemy_book() -> void: pass
	func open_pets() -> void: pass
	func open_pingbi() -> void: pass   # SiShiTan-PingBi 屏蔽掉落页（CE486）：宿主有这个入口，普查不再把它记成认不出
	func open_save() -> void: pass
	func open_yunshang_shop(_a = null, _b = null) -> void: pass
	func treasure_popup(_a = null, _b = null, _c = null) -> void: pass
	func erase_event(_id = 0) -> void: pass
	func flash_screen(_a = null, _b = null, _c = null) -> void: pass
	func shake_screen(_a = null, _b = null, _c = null) -> void: pass
	func change_battleback(_a = null, _b = null) -> void: pass
	func show_text_with_choices(_face: String, _idx: int, _lines: Array, _options: Array, _cancel: int) -> int: return 0


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
		var key: String = kind + "|" + str(code)   # 按完整写法去重（审查 21 期 P3④：只取前 80 字会把开头相同、后面不同的写法并成一种，藏住认不出的）
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
		if not FileAccess.file_exists(XDB.BASE + "maps/Map%03d.json" % id):   # 切片外的图没导出，别让 XDB 报读取失败
			continue
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
			if not it._host_plugin(str(row.code)):   # 要宿主画面的（仓库、怪物图鉴）交宿主，同 MVInterpreter._execute 356
				it._plugin_command(str(row.code))
		"cond":
			it._condition([12, str(row.code)])
		"var":
			await it._execute(JSON.parse_string(str(row.code)))
	return it.skipped.map(func(x): return str(x.text))


## 战斗版：同一写法交给战斗事件解释器 XBattleEventRunner（技能／物品公共事件、敌群页在战斗里跑的那一套）跑，返回认不出的原文
func _try_battle(row: Dictionary) -> Array:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	for v in [348, 881, 884]:
		s.set_variable(v, 1)
	var l := XBattleLogic.new()
	l.elite_roll = 100.0
	l.setup(2, s)
	last_logic = l
	var list := []
	match row.kind:
		"script":
			var lines: PackedStringArray = str(row.code).split("\n")
			for k in lines.size():
				list.append({"code": 355 if k == 0 else 655, "indent": 0, "parameters": [lines[k]]})
		"plugin":
			list.append({"code": 356, "indent": 0, "parameters": [str(row.code)]})
		"cond":
			list.append({"code": 111, "indent": 0, "parameters": [12, str(row.code)]})
			list.append({"code": 0, "indent": 1, "parameters": []})
			list.append({"code": 412, "indent": 0, "parameters": []})
		"var":
			list.append(JSON.parse_string(str(row.code)))
	list.append({"code": 0, "indent": 0, "parameters": []})
	var r := XBattleEventRunner.new(l, list)
	for k in 200:
		var step := r.advance()
		if step.kind == "done":
			break
		r.resume(null)
	return r.skipped.map(func(x): return str(x.text))


func _run() -> void:
	GameApp.fast_headless_frames()
	XSave.dir_override = "user://test_xiyou_script_census"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XShop.auto_close = true
	host = CensusHost.new()
	add_child(host)
	var known_file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KNOWN_FILE))
	var KNOWN: Dictionary = known_file.known
	var callers := _callers()
	var unreachable := {}
	for k in known_file.get("unreachable", {}):
		unreachable[int(k)] = true
		_check("unreachable_ce%s_no_callers" % k, (callers.get(int(k), []) as Array).is_empty(), callers.get(int(k), []))
	var roots := {}
	for k in known_file.get("battleRoots", {}):
		roots[int(k)] = true
	var rows := _collect()
	var unknown := {}
	var native := 0
	var by_unreachable := 0
	var by_battle := 0
	for key in rows:
		var miss: Array = await _try(rows[key])
		if not miss.is_empty():
			var r: Dictionary = rows[key]
			var ces := _where_ces(r)
			# 「再次释放」一族（Game_Action＋forceAction，CE345 等）：战斗事件解释器 XBattleEventRunner._recast_script 原生处理
			# （xiyou_battle_common_events 的 recast_* 与 battle_common_event_oracle 参照），战斗里认得就不算认不出；
			# 地图解释器本来不跑它（只在战斗里触发）。认不出的变体（正则对不上）仍会进 unknown。
			# 捕获网的 CE173 `Star.PetSystem.PetGet()` 同理：只有战斗道具（物品 200／315／316／317，使用场合＝战斗）会调，XBattleEventRunner 认（XPetCapture.pet_get）
			var battle_only: bool = r.kind == "script" and ((("new Game_Action(actor, true)" in str(r.code) and "BattleManager.forceAction(actor)" in str(r.code))) \
					or str(r.code).strip_edges() == "Star.PetSystem.PetGet()")
			if battle_only and (await _try_battle(r)).is_empty():
				native += 1
				continue
			if not ces.is_empty() and ces.all(func(id): return unreachable.has(id)):
				by_unreachable += 1
				continue
			if not ces.is_empty() and ces.all(func(id): return unreachable.has(id) or _battle_only(id, callers, roots, {})) and (await _try_battle(r)).is_empty():
				by_battle += 1
				print("CENSUS_BATTLE_ONLY ", JSON.stringify({"key": key.left(80), "where": r.where}))
				continue
			r["miss"] = miss
			unknown[key] = r
			print("CENSUS ", JSON.stringify({"key": key, "n": r.n, "where": r.where, "miss": miss.slice(0, 3)}))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"total": rows.size(), "unknown": unknown}, "  "))
	print("CENSUS_TOTAL ", rows.size(), " UNKNOWN ", unknown.size(), " NATIVE_RECAST ", native)
	_check("collected", rows.size() > 100, rows.size())
	_check("native_recast_seen", native >= 30, native)   # 再次释放一族原生模式确实被普查看到（防普查口径悄悄失效）
	var new_keys := unknown.keys().filter(func(k): return not KNOWN.has(k))
	_check("no_new_unknown", new_keys.is_empty(), new_keys.slice(0, 20))
	var fixed := KNOWN.keys().filter(func(k): return rows.has(k) and not unknown.has(k))
	# 按调用方销号的两类都真被用到（防口径悄悄失效）：events7b 时走不到 25 种、只在战斗里跑且战斗认得 14 种
	print("CENSUS_BY_CALLERS unreachable ", by_unreachable, " battle_only ", by_battle)
	_check("by_unreachable_seen", by_unreachable >= 20, by_unreachable)
	_check("by_battle_only_seen", by_battle >= 14, by_battle)
	_check("known_empty", KNOWN.is_empty(), KNOWN.size())
	# 变量操作读敌人游戏数据（122 操作数 游戏数据 4＝敌人，序号 0；原版 gameDataOperand case 4：0 HP、1 MP、2～9＝param(0～7)）：
	# 认得之外再看读出的值对不对（取 0 说明序号或类型走歪了）；只在战斗里有敌人，地图解释器不跑
	var enemy_reads := 0
	for key in rows:
		var r: Dictionary = rows[key]
		if r.kind != "var":
			continue
		var c: Dictionary = JSON.parse_string(str(r.code))
		var q: Array = c.parameters
		if int(q[3]) != 3 or int(q[4]) != 4:
			continue
		var bm: Array = await _try_battle(r)
		var e = last_logic.enemy_at(int(q[5]))
		var want := 0.0
		if e != null:
			want = e.hp if int(q[6]) == 0 else (e.mp if int(q[6]) == 1 else e.param(int(q[6]) - 2))
		var got := XState.current.variable(int(q[0]))
		enemy_reads += 1
		_check("enemy_read_%d_%d" % [int(q[0]), int(q[6])], bm.is_empty() and e != null and got == want and (int(q[6]) != 0 or got > 0), [got, want, bm])
	_check("enemy_reads_seen", enemy_reads >= 9, enemy_reads)   # 9 种（变量 318、1341～1348）都被看到
	_check("known_still_unknown", fixed.is_empty(), fixed)
	_finish()


## 公共事件 → 调用方（切片里导出的数据）：117（公共事件、地图事件页、敌群页）、物品／技能效果 44、自动／并行触发（条件开关有地方打开才算）
func _callers() -> Dictionary:
	var out := {}
	var add := func(ce: int, who: Dictionary):
		if not out.has(ce):
			out[ce] = []
		out[ce].append(who)
	var switch_on := {}
	var lists := []   # [列表, 调用方]
	var ces = XDB.table("CommonEvents")
	for ce in ces:
		if ce is Dictionary:
			lists.append([ce.get("list", []), {"kind": "ce", "id": int(ce.id)}])
	for id in range(1, 260):
		if not FileAccess.file_exists(XDB.BASE + "maps/Map%03d.json" % id):
			continue
		for e in XDB.map(id).get("events", []):
			if e is Dictionary:
				for pg in e.get("pages", []):
					lists.append([pg.get("list", []), {"kind": "map", "id": id}])
	for t in XDB.table("Troops"):
		if t is Dictionary:
			for pg in t.get("pages", []):
				lists.append([pg.get("list", []), {"kind": "troop", "id": int(t.id)}])
	for pair in lists:
		for c in pair[0]:
			var p: Array = c.get("parameters", [])
			match int(c.code):
				117:
					add.call(int(p[0]), pair[1])
				121:
					if int(p[2]) == 0:
						for sw in range(int(p[0]), int(p[1]) + 1):
							switch_on[sw] = true
				355, 655:
					var m := RegEx.create_from_string("\\$gameSwitches\\.setValue\\(\\s*(\\d+)\\s*,\\s*true").search(str(p[0]))
					if m:
						switch_on[int(m.get_string(1))] = true
	for table in ["Items", "Skills"]:
		for rec in XDB.table(table):
			if rec is Dictionary:
				for e in rec.get("effects", []):
					if int(e.code) == 44:
						add.call(int(e.dataId), {"kind": table, "id": int(rec.id), "occasion": int(rec.get("occasion", 0))})
	for ce in ces:
		if ce is Dictionary and int(ce.get("trigger", 0)) != 0 and switch_on.has(int(ce.switchId)):
			add.call(int(ce.id), {"kind": "trigger", "switch": int(ce.switchId)})
	return out


## 只在战斗里跑：有调用方，且每个调用方都是战斗场合（occasion 1）的物品／技能、敌群页、battleRoots，或本身只在战斗里跑的公共事件
static func _battle_only(id: int, callers: Dictionary, roots: Dictionary, seen: Dictionary) -> bool:
	if roots.has(id):
		return true
	if seen.has(id):
		return false
	seen[id] = true
	var list: Array = callers.get(id, [])
	if list.is_empty():
		return false
	for who in list:
		match str(who.kind):
			"troop":
				pass
			"Items", "Skills":
				if int(who.occasion) != 1:
					return false
			"ce":
				if not _battle_only(int(who.id), callers, roots, seen.duplicate()):
					return false
			_:
				return false
	return true


## 写法出现的位置全是公共事件时返回编号表（位置记满 12 处时可能没记全，返回空表＝不按调用方销号）
static func _where_ces(r: Dictionary) -> Array:
	var out := []
	if int(r.get("n", 0)) > (r.where as Array).size():
		return out
	for w in r.where:
		if not str(w).begins_with("CE"):
			return []
		out.append(int(str(w).substr(2)))
	return out


func _finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
