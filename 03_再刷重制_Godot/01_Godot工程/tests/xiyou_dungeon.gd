extends Node
## 副本系统对照（XDungeon；严格级）：用 MV 参照引擎 dungeon_probe 的剧本（generated/oracle/dungeon.json），
## 以同样的初始状态、选项与战斗结果在 MVInterpreter 上逐步运行，比较每一步取的事件页、输出（trace）、状态变化（delta）与副本状态（after）。
## - 第一轮关掉 O-038／O-040（原版行为），必须与参照逐项一致；第二轮打开，只核对优化改动的难度与挂机开关，其余仍须一致。
## - 另查：入口定义解析、上下文随存档往返、离开后清除、Boss 熟练度与神秘珠只领一次。

const ORACLE := "res://modes/xiyou/generated/oracle/dungeon.json"
const MAX_STEPS := 20000

var results := []


class Ch:
	extends RefCounted
	var character_name := ""

	func start_balloon(_id: int) -> void:    # 指令 213（九层女神、精灵商人）：参照不画气泡
		pass

	func is_balloon_playing() -> bool:
		return false


## 记录用宿主：在地图事件对照的替身上，按剧本回答选项、给战斗结果，并替事件提供当前页的图像与暂时消除
class DungeonHost:
	extends "res://tests/xiyou_event_compare.gd".EventHost
	var picks: Array = []
	var battle_result := "win"
	var game_over_hit := false
	var erased := {}

	func show_message(msg: Dictionary) -> int:
		var e := {"t": "msg", "face": str(msg.get("face", "")), "index": int(msg.get("index", 0)), "lines": msg.get("lines", [])}
		var pick := 0
		if msg.has("choices"):
			pick = int(picks.pop_front()) if not picks.is_empty() else msg.choices.size() - 1
			e.choices = msg.choices
			e.pick = pick
		if msg.has("choices") or not e.lines.is_empty():
			trace.append(e)
		return pick

	func start_battle(troop_id: int, can_escape: bool, can_lose: bool) -> int:
		trace.append({"t": "battle", "troop": troop_id, "escape": can_escape, "lose": can_lose})
		return 2 if battle_result == "lose" else 0

	func game_over() -> void:
		game_over_hit = true
		super.game_over()

	func transfer(id: int, x: int, y: int, d: int) -> void:
		super.transfer(id, x, y, d)
		erased = {}

	func erase_event(id: int) -> void:
		erased[id] = true

	func character(id: int, this_event: int):
		if id == -1:
			return super.character(id, this_event)
		var want := this_event if id == 0 else id
		var ch := Ch.new()
		var page := Main.page_of(XState.current.map_id, want, erased)
		if page >= 0:
			ch.character_name = str(Main.event_rec(XState.current.map_id, want).pages[page].image.characterName)
		return ch


## 内部类里引用本脚本的静态函数
const Main := preload("res://tests/xiyou_dungeon.gd")


static func event_rec(map_id: int, id: int) -> Dictionary:
	for e in XDB.map(map_id).get("events", []):
		if e is Dictionary and int(e.id) == id:
			return e
	return {}


## Game_Event.findProperPageIndex（暂时消除的为 −1）
static func page_of(map_id: int, id: int, erased: Dictionary) -> int:
	var ev := event_rec(map_id, id)
	if ev.is_empty() or erased.has(id):
		return -1
	var s := XState.current
	for i in range(ev.pages.size() - 1, -1, -1):
		var c: Dictionary = ev.pages[i].conditions
		if c.switch1Valid and not s.switch(int(c.switch1Id)):
			continue
		if c.switch2Valid and not s.switch(int(c.switch2Id)):
			continue
		if c.variableValid and s.variable(int(c.variableId)) < float(c.variableValue):
			continue
		if c.selfSwitchValid and not s.self_switch(map_id, id, str(c.selfSwitchCh)):
			continue
		if c.itemValid and s.item_count(int(c.itemId)) <= 0:
			continue
		if c.actorValid and not s.party.has(int(c.actorId)):
			continue
		return i
	return -1


var rune_item := 24     # 本例副本的挑战符文（十层起中级符文 64）
var track_kun := false  # 艾坤（角色 3）在队：after 多记坤坤任务（变量 346 与黄昏的信徒技能）
const KUN_SKILLS := [2765, 4397, 4398, 4399, 4400, 4401, 4402, 4403, 4404, 4405, 4406, 4407, 4408]


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", detail)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_dungeon"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	_static_checks()
	var oracle = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	check("oracle_loaded", oracle is Dictionary and oracle.has("cases") and oracle.cases.size() >= 119)
	if oracle is Dictionary:
		var host := DungeonHost.new()
		add_child(host)
		# 第一轮：原版行为，逐项一致
		XDungeon.restore_difficulty = false
		XDungeon.restore_hang_up = false
		for c in oracle.cases:
			var got := await _run_case(c, oracle.setup, host)
			for i in c.steps.size():
				if i >= got.steps.size():
					check("%s.step%d.ran" % [c.id, i], false, "Godot 提前结束")
					break
				var diffs := _compare(c.steps[i], got.steps[i])
				check("%s.step%d" % [c.id, i], diffs.is_empty(), diffs)
		# 第二轮：O-038／O-040
		XDungeon.restore_difficulty = true
		XDungeon.restore_hang_up = true
		for c in oracle.cases:
			var got := await _run_case(c, oracle.setup, host)
			_check_optimized(c, got)
	_finish()


func _finish() -> void:
	XDungeon.restore_difficulty = true
	XDungeon.restore_hang_up = true
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	MVInterpreter.max_steps = 0
	MVInterpreter.fixed_random = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 剧本 ----

func _run_case(c: Dictionary, setup: Dictionary, host: DungeonHost) -> Dictionary:
	var st: Dictionary = c.setup
	var diff := int(st.get("difficulty", 3))
	var s := XState.new_game_blank()
	for id in Array(setup.party) + Array(st.get("actors", [])):
		s.add_actor(int(id))
	track_kun = Array(st.get("actors", [])).any(func(x): return int(x) == 3)
	s.difficulty = diff
	s.set_switch(int(setup.diffSwitch[str(diff)]), true)
	for i in range(1, 9):
		s.flags["DCultyL%d" % i] = i == diff
	s.orb_seed = int(setup.orbSeed)
	s.orb_state.n = {}
	XState.current = s
	XDungeon.battle = {}
	MVInterpreter.fixed_random = float(st.get("rand", 0.5))
	await _run_list(host, XDB.rec("CommonEvents", 822).list, 0, 0)
	for id in st.get("sw", []):
		s.set_switch(int(id), true)
	for k in st.get("vars", {}):
		s.set_variable(int(k), float(st.vars[k]))
	rune_item = int(c.get("rune", 24))
	var base := int(c.tierBase)
	for t in range(2, int(st.get("tier", 1)) + 1):
		s.set_switch(base + t - 1, true)
		s.set_switch(base + t - 2, false)
	_warp(host, c.at)
	var steps := []
	for step in c.script:
		var res := await _run_step(step, host)
		steps.append(res)
		if res.get("gameOver", false):
			break
	return {"steps": steps}


func _warp(host: DungeonHost, at: Dictionary) -> void:
	var s := XState.current
	s.map_id = int(at.map)
	s.x = int(at.x)
	s.y = int(at.y)
	host.erased = {}


func _run_list(host: DungeonHost, list: Array, event_id: int, page: int) -> bool:
	MVInterpreter.max_steps = MAX_STEPS
	MVInterpreter.steps = 0
	MVInterpreter.aborted = false
	var interp := MVInterpreter.new(host, XState.current.map_id, event_id, list.duplicate(true))
	await interp.run()
	return not MVInterpreter.aborted


func _run_step(step: Dictionary, host: DungeonHost) -> Dictionary:
	var s := XState.current
	var before := _snap(s)
	host.trace = []
	host.picks = Array(step.get("picks", [])).duplicate()
	host.battle_result = str(step.get("battle", "win"))
	host.game_over_hit = false
	var out := {"do": step.do}
	match str(step.do):
		"event":
			var id := int(step.event)
			var page := page_of(s.map_id, id, host.erased)
			out.page = page
			if page >= 0:
				out.finished = await _run_list(host, event_rec(s.map_id, id).pages[page].list, id, page)
		"common":
			out.finished = await _run_list(host, XDB.rec("CommonEvents", int(step.id)).list, 0, 0)
		"item":
			s.gain_item(int(step.id), int(step.n) - s.item_count(int(step.id)))
		"hang":
			XDungeon.set_hang_up(s, bool(step.enabled))
			s.hang_up_active = bool(step.active)
			s.hang_up_origin = Vector2i(s.x, s.y) if bool(step.active) else Vector2i(-1, -1)
		"roundtrip":
			var active := s.hang_up_active
			XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
			XState.current.hang_up_active = active    # 挂机运行状态（$gameParty._hangUpData.state）在原版随存档
			s = XState.current
		"warp":
			_warp(host, step)
		"face":
			s.direction = int(step.d)
	if host.game_over_hit:
		out.gameOver = true
	out.trace = host.trace.duplicate(true)
	out.delta = _delta(before, _snap(XState.current))
	out.after = _focus(XState.current, host)
	out.context = not XDungeon.context(XState.current).is_empty()
	return out


# ---- 状态（与 dungeon_probe.cjs 的 snap／delta／focus 同一结构） ----

func _snap(s: XState) -> Dictionary:
	var sw := {}
	for k in s.switches:
		if s.switches[k]:
			sw[str(k)] = true
	var vars := {}
	for k in s.variables:
		if float(s.variables[k]) != 0.0:
			vars[str(k)] = float(s.variables[k])
	var ss := {}
	for k in s.self_switches:
		if s.self_switches[k]:
			ss[str(k).replace(",", ",")] = true
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
	var flags := {}
	for k in s.flags:
		if str(k).begins_with("DCultyL"):
			flags[str(k)] = bool(s.flags[k])
	return {"switches": sw, "variables": vars, "selfSwitches": ss, "gold": s.gold, "items": items, "weapons": weapons, "armors": armors,
		"difficulty": s.difficulty, "flags": flags}


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
	for k in ["switches", "selfSwitches"]:
		var m := _map_delta(a[k], b[k], false)
		if not m.is_empty():
			d[k] = m
	for k in ["variables", "items", "weapons", "armors"]:
		var m := _map_delta(a[k], b[k], 0)
		if not m.is_empty():
			d[k] = m
	if a.gold != b.gold:
		d.gold = float(b.gold - a.gold)
	if a.difficulty != b.difficulty:
		d.difficulty = b.difficulty
	var f := _map_delta(a.flags, b.flags, null)
	if not f.is_empty():
		d.flags = f
	return d


func _focus(s: XState, _host: DungeonHost) -> Dictionary:
	var vars := {}
	for v in [5, 6, 21, 94, 450, 364, 206, 214, 243]:
		vars[str(v)] = s.variable(v)
	var sw := {}
	for id in [229, 230, 882, 1565, 1566, 1567, 1568]:
		sw[str(id)] = s.switch(id)
	var out := {"difficulty": s.difficulty, "map": s.map_id, "x": s.x, "y": s.y, "hangEnabled": XHangUp.enabled(s),
		"hangActive": s.hang_up_active, "rune": s.item_count(rune_item), "vars": vars, "switches": sw}
	if track_kun:
		var a := s.actor(3)
		out.kun = {"found": s.variable(346), "skills": KUN_SKILLS.filter(func(id): return a.skill_ids.has(id))}
	return out


## 数值统一成整数（能整除时），再序列化比较
static func norm(v):
	if v is float and v == floorf(v) and absf(v) < 1e15:
		return int(v)
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(k)] = norm(v[k])
		return out
	if v is Array:
		return v.map(func(x): return norm(x))
	return v


## 参照里有、Godot 尚未实现的提示（按开头匹配），比较前从参照里去掉；实现后删掉对应一项
## - 「降服 」：真气灵根（installNativeZhenqiRuntime unlockSpecs，Boss 有灵根元素的 Element Absorb 时胜后提示），八戒 claude/bajie-zhenqi 在做
const PENDING_TOASTS := ["降服 "]

static func pending(want_trace) -> Array:
	return Array(want_trace if want_trace is Array else []).filter(func(e): return not (str(e.get("t", "")) == "toast"
		and PENDING_TOASTS.any(func(p): return str(e.get("text", "")).begins_with(p))))


func _compare(want: Dictionary, got: Dictionary) -> Array:
	var diffs := []
	want = want.duplicate()
	want.trace = pending(want.get("trace"))
	for k in ["page", "trace", "delta", "after", "gameOver"]:
		var a := JSON.stringify(norm(want.get(k)), "", true)
		var b := JSON.stringify(norm(got.get(k)), "", true)
		if a != b:
			diffs.append("%s: 参照 %s ≠ Godot %s" % [k, a.left(600), b.left(600)])
	return diffs


# ---- O-038／O-040 ----

## 打开优化时：离开副本（上下文清除）或选档没进成后，难度回到开局难度、挂机开关回到进门前；其余输出与原版相同
func _check_optimized(c: Dictionary, got: Dictionary) -> void:
	var base := int(c.setup.get("difficulty", 3))
	for i in got.steps.size():
		var want: Dictionary = c.steps[i]
		var g: Dictionary = got.steps[i]
		var name := "%s.opt.step%d" % [c.id, i]
		var same := true
		for k in ["page", "trace"]:
			if JSON.stringify(norm(pending(want.trace) if k == "trace" else want.get(k)), "", true) != JSON.stringify(norm(g.get(k)), "", true):
				same = false
		check(name + ".trace", same)
		var in_dungeon := float(g.after.vars["21"]) != 0.0
		if not in_dungeon and str(want.do) == "event":
			check(name + ".difficulty", int(g.after.difficulty) == base, [g.after.difficulty, base])
		if in_dungeon:
			check(name + ".context", bool(g.context) or str(c.id).begins_with("d2.reenter"))
	if str(c.id) in ["d2.escape", "d2.clear-normal", "hall.enable-hang"] or str(c.id).ends_with(".escape") or str(c.id).ends_with(".clear-normal"):
		# 进门前挂机开着：离开后的第一步就恢复（原版要找大厅大工匠）
		var entered := false
		for g in got.steps:
			if float(g.after.vars["21"]) != 0.0:
				entered = true
			elif entered:
				check(c.id + ".opt.hangRestored", bool(g.after.hangEnabled), g.after)
				break
		check(c.id + ".opt.contextCleared", not bool(got.steps[-1].context))


func _static_checks() -> void:
	var door := event_rec(3, 7)
	check("spec.door_loaded", not door.is_empty())
	if door.is_empty():
		return
	var spec := XDungeon.entry_spec(door.pages[3].list)
	check("spec.rune", int(spec.get("rune", 0)) == 24, spec)
	check("spec.tiers", spec.get("tiers", []) == [1, 2, 3, 4], spec)
	check("spec.transfer", spec.get("transfers", []) == [[123, 14, 23]], spec)
	# 同一模板的其他副本入口：每页都认得出，符文与目的地图一致
	for d in [[5, 8, 220, 24], [7, 1, 8, 24], [13, 1, 14, 24], [61, 10, 129, 24], [61, 11, 130, 24], [15, 4, 131, 24], [17, 2, 22, 64], [12, 17, 16, 64], [20, 5, 21, 110], [65, 1, 34, 110], [64, 2, 63, 110], [30, 6, 39, 110], [32, 4, 43, 171], [45, 2, 48, 171], [46, 2, 49, 171], [47, 11, 54, 171], [116, 2, 163, 397]]:
		var ev := event_rec(d[0], d[1])
		var ok: bool = not ev.is_empty() and ev.pages.all(func(pg):
			var sp := XDungeon.entry_spec(pg.list)
			return int(sp.get("rune", 0)) == d[3] and int(sp.transfers[0][0]) == d[2])
		check("spec.map%d_ev%d" % [d[0], d[1]], ok)
	check("spec.not_exit", XDungeon.entry_spec(event_rec(123, 6).pages[0].list).is_empty())
	check("spec.not_map001", XDungeon.entry_spec(XDB.map(1).events[1].pages[0].list).is_empty())
	# 条件分歧「角色」的种类（坤坤任务 CE819 按「习得技能」分级）：不在队也按角色本身判
	var cs := XState.new_game_blank()
	cs.add_actor(1)
	XState.current = cs
	cs.actor(3).learn_skill(2765)
	var ci := MVInterpreter.new(self, 1, 0, [])
	var cls := cs.actor(3).class_id
	check("cond.actor_kinds", ci._condition([4, 1, 0]) and not ci._condition([4, 3, 0]) and ci._condition([4, 3, 3, 2765])
		and not ci._condition([4, 3, 3, 4408]) and ci._condition([4, 3, 2, cls]) and not ci._condition([4, 3, 2, cls + 1])
		and not ci._condition([4, 3, 6, 1]) and not ci._condition([4, 9999, 0]))
	# 指令 225 画面震动（十二层三首领）：照 Game_Screen.updateShake，强度 5、速度 5、60 帧
	var ms := XMapScene.new()
	ms.shake_screen(5, 5, 60)
	var seq := []
	for i in 61:
		ms._update_shake()
		seq.append(ms._shake.value)
	ms.free()
	check("shake.screen", seq.slice(0, 8) == [2.5, 5.0, 7.5, 10.0, 12.5, 10.0, 7.5, 5.0] and seq[59] == 0.0 and seq[60] == 0.0, seq)
	# 转换器 v17：YEP <Damage Formula> 块替换数据库公式。十四层首领技能 4013 的块有加减 HP/MP/TP 副作用，未翻译；
	# 1051 只是「var 名 = 式＋value = 式」，代入后翻译，elementRate → element_rate
	var k4013: Dictionary = XDB.rec("Skills", 4013).damage
	var k1051: Dictionary = XDB.rec("Skills", 1051).damage
	check("formula.custom_block", bool(k4013.custom) and k4013.formulaGd == null and str(k4013.formula).contains("gainHp")
		and bool(k1051.custom) and str(k1051.formulaGd).contains("element_rate(8)"), [k4013, k1051])
	var fa := XEnemy.new().setup(161, 3, 100.0)
	var fb := XEnemy.new().setup(161, 3, 100.0)
	var want := ((1500.0 + fa.atk * 15.0) * (1.0 + fa.element_rate(8) * 10.0) - fb.def * 2.0)
	check("formula.custom_eval", is_equal_approx(XDamage.eval_formula(XDB.rec("Skills", 1051), fa, fb, []), maxf(want, 0.0)), want)
	check("floor.dungeon_map", XDungeon.map_floor(124) == 2, XDungeon.map_floor(124))
	check("floor.parse_cn", XDungeon.parse_floor("十二层:冰封洞穴") == 12 and XDungeon.parse_floor("二十层") == 20 and XDungeon.parse_floor("24层 速行天") == 24)
	# Boss 熟练度：第 1 次 +10 抽奖券；同一场神秘珠只判一次
	var s := XState.new_game_blank()
	s.map_id = 124
	XState.current = s
	XDungeon.battle_finished(424, 0, 124)
	var t1 := XDungeon.boss_reward(s)
	check("boss.first", s.item_count(XDungeon.TICKET) == 10 and str(t1[0]).begins_with("土地公公 熟练度 1 次：抽奖券 +10"), t1)
	check("boss.orb_once", bool(XDungeon.battle.orb))
	XDungeon.battle_finished(424, 2, 124)
	XDungeon.boss_reward(s)
	check("boss.lost_no_orb", not bool(XDungeon.battle.orb) and int(s.boss_mastery["424"]) == 2)
	# 上下文随存档
	s.dungeon = {"context": {"entryMap": 3, "entryEvent": 7, "baseDifficulty": 5, "hangEnabled": true, "rune": 24, "id": 22, "tier": 1}}
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check("save.context", int(XDungeon.context(back).get("baseDifficulty", 0)) == 5 and int(back.boss_mastery.get("424", 0)) == 2)
	# 进度审查 25%：读档／新游戏清掉上一档最近一场事件战斗的标记（不随存档），读档后不会凭旧胜利再领神秘珠
	XDungeon.battle_finished(424, 0, 124)
	XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	var cleared_on_load := XDungeon.battle.is_empty()
	XDungeon.battle_finished(424, 0, 124)
	XState.new_game_blank()
	check("load.clears_battle", cleared_on_load and XDungeon.battle.is_empty() and XDungeon.boss_reward(s).is_empty())
	XState.current = s
	XDungeon.battle = {}
