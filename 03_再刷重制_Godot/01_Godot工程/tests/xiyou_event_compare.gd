extends Node
## 地图事件对照（效率改造第二步）：用 MV 参照引擎的 event_probe（generated/oracle/events.json）里同一批用例，
## 以同样的初始状态与应答在 Godot 的 MVInterpreter 上运行，逐项比较可观察的输出（trace）与状态变化（delta）。
## - 宿主是记录用的替身（EventHost）：不开画面、不进战斗，文字/选项/场所移动/战斗/商店/场景/存档/输入/提示只记录并按约定应答
##   （选项默认项，同一组第 4 次起取最后一项；数值 0；输入「测试」；战斗胜利），与 event_probe.cjs 相同。
## - 不比较：移动路线、动画、气泡、画面效果、音频（替身不执行）；参照引擎本身出错或没跑完的用例只列出。
## - 已知不一致登记在 tests/event_compare_baseline.json（用例 → 不一致的项目）：新出现的不一致用例或项目（退步）使测试失败；
##   登记里的用例变一致时提示更新登记（--update-baseline）。
## 参数（-- 之后）：--out=<目录> 写对照报告；--update-baseline 用本次结果重写登记；--only=<前缀,…> 只跑部分用例。

const ORACLE := "res://modes/xiyou/generated/oracle/events.json"
const BASELINE := "res://tests/event_compare_baseline.json"
const PARTY := [1, 8, 10, 9]
const MAX_STEPS := 20000
const KNOWN_ORACLE_ERRORS := ["m221e3p0", "ce1344"]

var results := []
var out_dir := ""
var update_baseline := false
var only: Array = []


class FakePlayer:
	extends RefCounted
	var transparent := false
	var direction := 2
	var grid := Vector2i.ZERO
	func queue_redraw() -> void:
		pass


## 记录用宿主：接口同 XMapScene（MVInterpreter / MVScript 用到的部分）
class EventHost:
	extends Node
	var trace: Array = []
	var seen := {}
	var player := FakePlayer.new()

	func show_message(msg: Dictionary) -> int:
		var e := {"t": "msg", "face": str(msg.get("face", "")), "index": int(msg.get("index", 0)), "lines": msg.get("lines", [])}
		var pick := 0
		if msg.has("choices"):
			var sig := JSON.stringify(msg.choices)
			seen[sig] = int(seen.get(sig, 0)) + 1
			pick = msg.choices.size() - 1 if seen[sig] > 3 else (int(msg.default) if int(msg.get("default", -1)) >= 0 else 0)
			e.choices = msg.choices
			e.pick = pick
		elif msg.has("digits"):
			e.number = true
			e.pick = 0
		if msg.has("choices") or msg.has("digits") or not e.lines.is_empty():
			trace.append(e)
		return pick

	func transfer(id: int, x: int, y: int, d: int) -> void:
		trace.append({"t": "transfer", "map": id, "x": x, "y": y, "d": d})
		var s := XState.current
		s.map_id = id
		s.x = x
		s.y = y
		if d > 0:
			s.direction = d

	func start_battle(troop_id: int, can_escape: bool, can_lose: bool) -> int:
		trace.append({"t": "battle", "troop": troop_id, "escape": can_escape, "lose": can_lose})
		return 0

	func open_shop(goods: Array, _purchase_only: bool) -> void:
		trace.append({"t": "shop", "goods": goods.map(func(g): return [int(g[0]), int(g[1])])})

	func open_training() -> void:
		trace.append({"t": "scene", "name": "Scene_ActorAttributePlusPoints"})

	func open_warehouse() -> void:
		trace.append({"t": "scene", "name": "Scene_Warehouse"})

	func open_actor_warehouse() -> void:
		trace.append({"t": "scene", "name": "Star_Scene_ActorWarehouse"})

	func open_inlay_book() -> void:
		trace.append({"t": "scene", "name": "Scene_EquipInlayBook"})

	func open_race_menu(_rank := 0) -> void:
		trace.append({"t": "scene", "name": "Scene_CodexBindMenu"})

	func input_text(prompt: String, _default := "") -> String:
		trace.append({"t": "prompt", "text": prompt})
		return "测试"

	func save_game(slot: int) -> bool:
		trace.append({"t": "save", "slot": slot})
		return true

	func toast(text: String) -> void:
		trace.append({"t": "toast", "text": text})

	func return_to_title() -> void:
		trace.append({"t": "scene", "name": "Scene_Title"})

	func game_over() -> void:
		trace.append({"t": "scene", "name": "Scene_Gameover"})

	func set_followers_visible(v: bool) -> void:
		XState.current.followers_visible = v

	func gather_followers() -> void:
		pass

	func refresh_events() -> void:
		pass

	## Game_Interpreter.character：-1 为玩家（朝向同 XState，新游戏朝下）；事件不在替身里
	func character(id: int, _this_event: int):
		if id == -1:
			player.direction = XState.current.direction
			player.grid = Vector2i(XState.current.x, XState.current.y)
			return player
		return null

	func show_animation(_ch, _anim_id: int):
		return null

	## MV command221/222：淡出/淡入并等待 fadeSpeed（24 帧）
	func fade(_out: bool) -> void:
		for i in range(24):
			await get_tree().process_frame

	## 游戏时间按帧走（同参照引擎每帧 Graphics.frameCount +1，playtime = 帧数/60 取整）
	func _process(_delta: float) -> void:
		if XState.current:
			XState.current.play_seconds += 1.0 / 60.0

	func play_bgm(_a) -> void:
		pass

	func play_bgs(_a) -> void:
		pass

	func play_me(_a) -> void:
		pass

	func play_se(_a) -> void:
		pass


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg == "--update-baseline":
			update_baseline = true
		elif arg.begins_with("--only="):
			only = Array(arg.substr(7).split(",", false))
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", detail)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_event_compare"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	# 比原版翻译：副本的难度／挂机恢复优化（O-038／O-040）关掉，由 tests/xiyou_dungeon 单独对照
	XDungeon.restore_difficulty = false
	XDungeon.restore_hang_up = false
	XDungeon.battle_end_counts = false
	var oracle = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	check("oracle_loaded", oracle is Dictionary and oracle.has("cases"))
	if not (oracle is Dictionary):
		_finish()
		return
	var expected_ids := []
	var manifest: Dictionary = XDB.load_json("manifest.json")
	for id in manifest.slice.maps:
		for ev in XDB.map(int(id)).get("events", []):
			if not ev is Dictionary:
				continue
			for p in ev.pages.size():
				if ev.pages[p].list.any(func(c): return int(c.code) != 0):
					expected_ids.append("m%de%dp%d" % [int(id), int(ev.id), p])
	for id in manifest.slice.commonEvents:
		if XDB.rec("CommonEvents", int(id)).get("list", []).any(func(c): return int(c.code) != 0):
			expected_ids.append("ce%d" % int(id))
	var actual_ids: Array = oracle.cases.map(func(c): return str(c.id))
	expected_ids.sort()
	actual_ids.sort()
	check("oracle_cases_complete", expected_ids == actual_ids, [expected_ids.size(), actual_ids.size()])
	var baseline: Dictionary = {}
	if FileAccess.file_exists(BASELINE):
		var b = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
		baseline = b if b is Dictionary else {}
	var known: Dictionary = baseline.get("mismatch", {})
	var host := EventHost.new()
	add_child(host)
	var report := []
	var mismatched := {}
	var oracle_errors := []
	for c in oracle.cases:
		if not only.is_empty() and not only.any(func(p): return str(c.id).begins_with(p)):
			continue
		# 参照引擎出错或没跑完（如随机数固定后「抽到不同的为止」的循环）的用例不比较，只列出
		if c.has("errors") or not bool(c.get("finished", true)):
			oracle_errors.append(c.id)
			continue
		var got := await _run_case(c, host)
		var diffs := _compare(c, got)
		var row := {"id": c.id, "ok": diffs.is_empty(), "diffs": diffs, "skipped": got.skipped, "aborted": got.aborted}
		report.append(row)
		if not diffs.is_empty():
			mismatched[c.id] = diffs.map(func(d): return d.split(":")[0])
	var ok_count := report.filter(func(r): return r.ok).size()
	# 退步：登记外的用例不一致，或登记内的用例出现登记外的不一致项目（trace/variables/…）
	var regressions := mismatched.keys().filter(func(id):
		return not known.has(id) or mismatched[id].any(func(k): return not known[id].has(k)))
	var fixed := known.keys().filter(func(id): return not mismatched.has(id) and report.any(func(r): return r.id == id))
	print("EVENT_COMPARE ", JSON.stringify({"cases": report.size(), "match": ok_count, "mismatch": mismatched.size(),
		"oracleErrors": oracle_errors, "regressions": regressions, "nowMatching": fixed}))
	for id in regressions:
		print("REGRESSION ", id, " ", report.filter(func(r): return r.id == id)[0].diffs.slice(0, 3))
	if update_baseline and only.is_empty():
		var f := FileAccess.open(ProjectSettings.globalize_path(BASELINE), FileAccess.WRITE)
		f.store_string(JSON.stringify({"note": "地图事件对照的已知不一致（tests/xiyou_event_compare 写入；--update-baseline 重写）。值为不一致的项目。现存 4 例都是原版有而重制版未做的系统：m4e17p0／p1 更衣（Scene_ChangeClothes）、m132e6p0 奉神老妪「进阶」（Scene_ActorAdvanced）两处界面未接；m4e73p0 商店向导「战力短板」一段来自 CodexZones 五乘区预算，按数值平衡不移植（O-044／O-050）。",
			"source": str(oracle.get("sourceIdentity", {}).get("releaseVersion", "")), "match": ok_count, "cases": report.size(), "mismatch": mismatched}, "\t", true))
		f.close()
	if out_dir != "":
		_write_report(report, oracle_errors)
	check("no_regressions", regressions.is_empty() or update_baseline, regressions)
	check("no_new_oracle_errors", oracle_errors.all(func(id): return KNOWN_ORACLE_ERRORS.has(id)), oracle_errors)
	check("cases_ran", report.size() > 0 or not only.is_empty())
	_finish()


func _finish() -> void:
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	MVInterpreter.max_steps = 0
	MVInterpreter.fixed_random = -1.0
	XDungeon.restore_difficulty = true
	XDungeon.restore_hang_up = true
	XDungeon.battle_end_counts = true
	XDungeon.battle = {}
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _run_case(c: Dictionary, host: EventHost) -> Dictionary:
	var s := XState.new_game_blank()
	s.difficulty = 3
	for id in PARTY:
		s.add_actor(id)
	s.map_id = int(c.map)
	XState.current = s
	host.trace = []
	host.seen = {}
	var list: Array
	if str(c.kind) == "common":
		list = XDB.rec("CommonEvents", int(c.common)).get("list", []).duplicate(true)
	else:
		var ev = null
		for e in XDB.map(int(c.map)).get("events", []):
			if e is Dictionary and int(e.id) == int(c.event):
				ev = e
		list = ev.pages[int(c.page)].list.duplicate(true) if ev != null else []
	# 第一条仓库指令就是 show 的页（如青霞第 2 页，正常流程里仓库已由第 1 页建好）：参照探针先建好默认仓库，这边同样
	for cmd in list:
		if int(cmd.code) == 356 and str(cmd.parameters[0]).begins_with("PHWarehouse "):
			if str(cmd.parameters[0]).begins_with("PHWarehouse show "):
				XWarehouse.create(s, str(cmd.parameters[0]).substr(len("PHWarehouse show ")))
			break
	XDungeon.battle = {}       # $gameTroop 每例新游戏都是空的
	s.orb_seed = 2147483648    # 参照固定 Math.random＝0.5 后开新局：宝珠随机流种子 floor(0.5×2³²)
	var before := _snap(s)
	MVInterpreter.max_steps = MAX_STEPS
	MVInterpreter.fixed_random = 0.5
	MVInterpreter.steps = 0
	MVInterpreter.aborted = false
	var interp := MVInterpreter.new(host, int(c.map), int(c.event), list)
	await interp.run()
	var skipped := {}
	for k in interp.skipped:
		var key := "%d %s" % [int(k.code), str(k.text).left(40)]
		skipped[key] = int(skipped.get(key, 0)) + 1
	return {"trace": host.trace.duplicate(true), "delta": _delta(before, _snap(XState.current)), "skipped": skipped, "aborted": MVInterpreter.aborted}


# ---- 状态快照与变化（与 event_probe.cjs 的 snap/delta 同一结构） ----
func _snap(s: XState) -> Dictionary:
	var sw := {}
	for k in s.switches:
		if s.switches[k]:
			sw[str(k)] = true
	var vars := {}
	for k in s.variables:
		var v = s.variables[k]
		if v is float or v is int:
			if float(v) != 0.0:
				vars[str(k)] = float(v)
		elif str(v) != "":
			vars[str(k)] = str(v)
	var ss := {}
	for k in s.self_switches:
		if s.self_switches[k]:
			ss[str(k)] = true
	var items := {}
	for k in s.items:
		if int(s.items[k]) != 0:
			items[str(k)] = int(s.items[k])
	var weapons := {}
	var armors := {}
	for g in s.gear:
		var table: Dictionary = weapons if str(g.get("kind", "")) == "weapon" else armors
		var base := str(int(g.get("base", 0)))
		table[base] = int(table.get(base, 0)) + 1
	var actors := {}
	for id in s.party:
		var a := s.actor(id)
		var skills := Array(a.skill_ids).duplicate()
		skills.sort()
		actors[str(id)] = {"name": a.display_name(), "level": a.level, "classId": a.class_id, "skills": skills}
	var flags := {}
	for k in s.flags:
		if str(k).begins_with("DCultyL"):
			flags[str(k)] = bool(s.flags[k])
		elif str(k) == "SaveGameId":
			flags[str(k)] = float(s.flags[k])
	return {"switches": sw, "variables": vars, "selfSwitches": ss, "gold": s.gold, "items": items, "weapons": weapons, "armors": armors,
		"party": Array(s.party).duplicate(), "actors": actors, "difficulty": s.difficulty, "encounter": s.encounter_enabled,
		"followers": s.followers_visible, "actorName": s.actor_name, "actorMaxLevel": s.actor_max_level, "flags": flags,
		"screen": s.screen.target_snapshot()}


func _map_delta(a: Dictionary, b: Dictionary, empty) -> Dictionary:
	var out := {}
	var keys := a.keys()
	for k in b.keys():
		if not keys.has(k):
			keys.append(k)
	for k in keys:
		var x = a.get(k, empty)
		var y = b.get(k, empty)
		if JSON.stringify(x) != JSON.stringify(y):
			out[k] = (float(y) - float(x)) if empty is int and (x is int or x is float) and (y is int or y is float) else y
	return out


func _delta(a: Dictionary, b: Dictionary) -> Dictionary:
	var d := {}
	var put := func(k: String, v):
		if v is Dictionary and v.is_empty():
			return
		d[k] = v
	put.call("switches", _map_delta(a.switches, b.switches, false))
	put.call("variables", _map_delta(a.variables, b.variables, 0))
	put.call("selfSwitches", _map_delta(a.selfSwitches, b.selfSwitches, false))
	if a.gold != b.gold:
		d.gold = float(b.gold - a.gold)
	for k in ["items", "weapons", "armors"]:
		put.call(k, _map_delta(a[k], b[k], 0))
	if JSON.stringify(a.party) != JSON.stringify(b.party):
		d.party = b.party
	var actors := {}
	for id in b.actors:
		var x: Dictionary = a.actors.get(id, {})
		var y: Dictionary = b.actors[id]
		var ch := {}
		for f in y:
			if JSON.stringify(x.get(f)) != JSON.stringify(y[f]):
				ch[f] = y[f]
		if not ch.is_empty():
			actors[id] = ch
	put.call("actors", actors)
	for k in ["difficulty", "encounter", "followers", "actorName", "actorMaxLevel"]:
		if a[k] != b[k]:
			d[k] = b[k]
	put.call("flags", _map_delta(a.flags, b.flags, null))
	if JSON.stringify(a.screen) != JSON.stringify(b.screen):
		d.screen = b.screen
	return d


# ---- 比较 ----
## JSON 往返后比较（数字一律浮点，键一律字符串）
static func _norm(v):
	return JSON.parse_string(JSON.stringify(v))


func _trace_norm(trace: Array) -> Array:
	return trace.map(func(e):
		var x: Dictionary = e.duplicate(true)
		if x.t == "msg" and x.has("number"):
			x.number = true
		if x.t == "transfer":
			x.erase("d")
		return _norm(x))


func _compare(c: Dictionary, got: Dictionary) -> Array:
	var diffs := []
	var want_trace := _trace_norm(c.trace)
	# O-027／O-062：落点修正是有意的优化，参照里的原版落点按同一张表换算后再比
	for e in want_trace:
		if e.t == "transfer":
			var to: Vector2i = MVInterpreter.TRANSFER_FIX.get("%d:%d:%d:%d:%d" % [int(c.map), int(c.get("event", 0)), int(e.map), int(e.x), int(e.y)], Vector2i(int(e.x), int(e.y)))
			e.x = float(to.x)
			e.y = float(to.y)
	var got_trace := _trace_norm(got.trace)
	for i in range(maxi(want_trace.size(), got_trace.size())):
		var w = want_trace[i] if i < want_trace.size() else null
		var g = got_trace[i] if i < got_trace.size() else null
		if JSON.stringify(w) != JSON.stringify(g):
			diffs.append("trace:%d 原版 %s ｜ Godot %s" % [i, JSON.stringify(w).left(160), JSON.stringify(g).left(160)])
			break
	var want_delta: Dictionary = _norm(c.delta)
	var got_delta: Dictionary = _norm(got.delta)
	var keys := want_delta.keys()
	for k in got_delta.keys():
		if not keys.has(k):
			keys.append(k)
	for k in keys:
		if JSON.stringify(want_delta.get(k)) != JSON.stringify(got_delta.get(k)):
			diffs.append("%s: 原版 %s ｜ Godot %s" % [k, JSON.stringify(want_delta.get(k)).left(200), JSON.stringify(got_delta.get(k)).left(200)])
	if got.aborted:
		diffs.append("aborted: Godot 超过 %d 步" % MAX_STEPS)
	return diffs


func _write_report(report: Array, oracle_errors: Array) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open(out_dir.path_join("事件对照.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"cases": report, "oracleErrors": oracle_errors}, "\t"))
	f.close()
	var lines := ["# 地图事件对照报告", "", "一致 %d / %d；参照引擎出错或未结束 %d：%s" % [report.filter(func(r): return r.ok).size(), report.size(), oracle_errors.size(), ", ".join(oracle_errors)], ""]
	var kinds := {}
	var skip_total := {}
	for r in report:
		for d in r.diffs:
			var k := str(d).split(":")[0]
			kinds[k] = int(kinds.get(k, 0)) + 1
		for k in r.skipped:
			skip_total[k] = int(skip_total.get(k, 0)) + int(r.skipped[k])
	lines.append("## 不一致项目分布")
	for k in kinds:
		lines.append("- %s：%d 个用例" % [k, kinds[k]])
	lines.append("")
	lines.append("## Godot 跳过的指令（按次数）")
	var sk := skip_total.keys()
	sk.sort_custom(func(a, b): return skip_total[a] > skip_total[b])
	for k in sk.slice(0, 60):
		lines.append("- %d × %s" % [skip_total[k], k])
	lines.append("")
	lines.append("## 不一致的用例")
	for r in report:
		if not r.ok:
			lines.append("- **%s**" % r.id)
			for d in r.diffs:
				lines.append("  - " + str(d))
	f = FileAccess.open(out_dir.path_join("事件对照.md"), FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
