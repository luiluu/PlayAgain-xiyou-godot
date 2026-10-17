extends Node
## 真气第一批（XZhenqi）与修行页（XGuide）：与 mv_oracle/zhenqi_probe.cjs 的冻结 v0.28 参照（generated/oracle/zhenqi.json）逐例比——
## 路线、境界名／加成／门槛、允许境界、天道补偿表、Boss 奖励表、溢出再动、胜利结算（守层者首通与重复、路线系数、阵亡、溢出上限、
## 大圆满与精进提示、Boss 敌群在大厅按进度层）、存读档、新档初值、地图楼层、Boss 判定、修行页行文（不含不移植的五个乘区）、战力条文字、倍率格式。
## 另测：BattleLogic 钩子（首回合超额记溢出、grant 只记一次）、旧档缺 zhenqi 读回初值。

const ORACLE := "res://modes/xiyou/generated/oracle/zhenqi.json"
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 15:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _norm(v):
	if v is float:
		return int(v) if v == floorf(v) and absf(v) < 1e15 else snappedf(v, 0.000001)
	if v is Dictionary:
		var keys: Array = v.keys()
		keys.sort()
		var out := {}
		for k in keys:
			out[str(k)] = _norm(v[k])
		return out
	if v is Array:
		return v.map(func(x): return _norm(x))
	return v


## 参照数字取 6 位小数（toFixed）：浮点按 1e-6 容差比，其余逐项相同
func _same(a, b) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) <= 1.000001e-6
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			var kb = k if b.has(k) else str(k)
			if not b.has(kb) or not _same(a[k], b[kb]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not _same(a[i], b[i]):
				return false
		return true
	return JSON.stringify(_norm(a)) == JSON.stringify(_norm(b))


const SWITCHES := [2500, 2494, 2489, 2461, 2487, 2462, 2483, 2463]


func _fresh() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 4
	XZhenqi.toasts.clear()
	return s


func _set_zq(a: XActor, d: Dictionary) -> void:
	var z := XZhenqi.default_data()
	for k in d:
		z[k] = d[k]
	a.zhenqi = XZhenqi.from_save(z)


func _state(s: XState, a: XActor) -> Dictionary:
	var st := XZhenqi.state_of(s, a)
	st.describe = XZhenqi.describe(s, a)
	return st


func _battle(s: XState, troop: int, opts: Dictionary) -> Dictionary:
	if opts.has("route"):
		s.set_switch(int(opts.route), true)
	if opts.has("progress"):
		s.set_variable(20, int(opts.progress) + 1)
	for id in opts.get("data", {}):
		_set_zq(s.actor(int(id)), opts.data[id])
	var before := {}
	for a in s.members():
		before[a.actor_id] = int(XZhenqi.data(a).qi)
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	var b := XZhenqi.battle
	var info := {"troopId": b.troopId, "route": b.route.key, "guardianFloor": b.guardianFloor, "floor": b.floor, "comp": b.comp}
	for id in opts.get("dead", []):
		s.actor(int(id)).hp = 0
	for id in opts.get("ovf", {}):
		b.ovf[int(id)] = int(opts.ovf[id])
	XZhenqi.toasts.clear()
	XZhenqi.on_victory(s, logic.actors, logic.enemies)
	var gains := {}
	var firsts := {}
	for a in s.members():
		gains[str(a.actor_id)] = int(a.zhenqi.qi) - before[a.actor_id]
		var f: Array = a.zhenqi.firsts.keys()
		f.sort()
		firsts[str(a.actor_id)] = f
	for id in opts.get("dead", []):
		s.actor(int(id)).hp = 1

	return {"battle": info, "gains": gains, "firsts": firsts, "toasts": XZhenqi.toasts.duplicate(), "cleared": XZhenqi.battle.is_empty()}


func _boss_troop() -> int:
	var troops = XDB.table("Troops")
	for t in troops:
		if t is Dictionary and not t.get("members", []).is_empty() and not XZhenqi.GUARDIANS.has(int(t.id)):
			for m in t.members:
				var e := XEnemy.new()
				e.enemy_id = int(m.enemyId)
				if XZhenqi.is_boss_enemy(e):
					return int(t.id)
	return 0


func _case(id: String, setup: Dictionary):
	var s := _fresh()
	if id.begins_with("route."):
		if setup.has("switch"):
			s.set_switch(int(setup.switch), true)
		return XZhenqi.route(s).key
	if id.begins_with("state."):
		s.set_variable(20, int(setup.progressFloor) + 1)
		var a := s.actor(1)
		_set_zq(a, {"realm": int(setup.realm), "qi": int(setup.qi)})
		return _state(s, a)
	match id:
		"realm.allowed":
			var allowed := []
			for pf in range(35):
				s.set_variable(20, pf + 1)
				allowed.append([pf, XZhenqi.progress_floor(s), XZhenqi.allowed_realm(s)])
			return {"allowed": allowed, "required": range(XZhenqi.REALMS.size()).map(func(i): return XZhenqi.required_floor(i)),
				"majorByQi": [0, 599, 600, 2500, 499999, 500000, 9000000].map(func(q): return [q, XZhenqi.major_by_qi(q)])}
		"comp.table":
			return XZhenqi.ROUTES.map(func(r): return [r.key, range(35).map(func(f): return XZhenqi.comp_for(r.key, f))])
		"boss.reward":
			return XZhenqi.ROUTES.map(func(r): return [r.coef, range(34).map(func(f): return XZhenqi.boss_reward(f, int(r.coef)))])
		"victory.guardian20.twice":
			var first := _battle(s, 456, {})
			return {"first": first, "second": _battle(s, 456, {})}
		"save.roundtrip":
			_battle(s, 456, {"ovf": {1: 3}})
			var before: Dictionary = s.actor(1).zhenqi.duplicate(true)
			var s2 := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
			return {"before": before, "after": s2.actor(1).zhenqi, "retro": {"route": "normal", "floors": 0}}
		"newgame.default":
			return {"data": XZhenqi.data(s.actor(9)), "retro": {"route": "normal", "floors": 0}}
		"format.mult":
			return [0, 0.00004, 0.0003, 0.05, 0.123, 0.99, 1, 1.04, 1.05, 9.96, 123.4, 999.9, 1000, 12345.6].map(func(v): return [v, XZhenqi.mult(v)])
	if id.begins_with("overflow."):
		# note_overflow 按 BattleLogic 传入的追加次数（makeActionTimes − 1）；只有首回合当前顺序调用
		var n := int(setup.makeActionTimes)
		XZhenqi.battle = {"ovf": {}}
		if setup.array == "current":
			XZhenqi.note_overflow(s.actor(1), n - 1)
		return {"ovf": int(XZhenqi.battle.ovf.get(1, 0)), "entries": 1 + mini(n - 1, 4), "actionDMG": 0}
	if id.begins_with("victory.boss."):
		var t := _boss_troop()
		var opts := {"progress": int(setup.progress)}
		if id.ends_with("f26"):
			opts.route = 2483
		var r := _battle(s, t, opts)
		r.troop = t
		return r
	if id.begins_with("victory."):
		var opts := {}
		for k in ["route", "progress", "dead", "ovf", "data"]:
			if setup.has(k):
				opts[k] = setup[k]
		return _battle(s, int(setup.troop), opts)
	if id.begins_with("page."):
		if setup.has("route"):
			s.set_switch(int(setup.route), true)
		if setup.has("progress"):
			s.set_variable(20, int(setup.progress) + 1)
		for aid in setup.get("data", {}):
			_set_zq(s.actor(int(aid)), setup.data[aid])
		var a := s.actor(1)
		var st := XGuide.strip_text(s, a)
		var ctx := XGuide.context(s)
		return {"rows": XGuide.page_rows(s, a), "strip": st[0], "stripWarn": st[1], "context": {"route": ctx.route.key, "floor": ctx.floor, "comp": ctx.comp}}
	return null


## 修行页：参照去掉「五个乘区」一段（不移植，O-044）后逐行比
func _strip_zones(rows: Array) -> Array:
	var out := []
	var skipping := false
	for r in rows:
		if r.type == "head" and str(r.text).begins_with("五个乘区"):
			skipping = true
			out.pop_back()   # 段前的空行
			continue
		if skipping and r.type == "blank":
			skipping = false
		if not skipping:
			out.append(r)
	return out


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if check("zhenqi_oracle_loaded", data is Dictionary and data.get("cases", []).size() >= 150, ORACLE):
		for c in data.cases:
			if not c.errors.is_empty():
				check("oracle_" + c.id, false, c.errors)
				continue
			if c.id in ["map.floor", "boss.enemies"]:
				continue
			var got = _case(c.id, c.setup)
			var want = c.observed
			if c.id.begins_with("page."):
				want = want.duplicate(true)
				want.rows = _strip_zones(want.rows)
			check(c.id, got != null and _same(got, want), [got, want])
		for c in data.cases:
			if c.id == "map.floor":
				var bad := []
				var n := 0
				for row in c.observed:
					var mid := int(row[0])
					# 切片外的地图没有转换出显示名，只比能从 MapInfos 名称得出的
					if not FileAccess.file_exists("res://modes/xiyou/generated/maps/Map%03d.json" % mid) and XZhenqi.parse_floor(str(XDB.rec("MapInfos", mid).get("name", ""))) == 0:
						continue
					n += 1
					if XZhenqi.map_floor(mid) != int(row[1]):
						bad.append([row, XZhenqi.map_floor(mid)])
				check("map_floor_%d" % n, bad.is_empty() and n >= 40, bad.slice(0, 5))
			elif c.id == "boss.enemies":
				var want := {}
				for id in c.observed:
					want[int(id)] = true
				var bad := []
				var enemies = XDB.table("Enemies")
				for e in enemies:
					if e is Dictionary:
						var x := XEnemy.new()
						x.enemy_id = int(e.id)
						if XZhenqi.is_boss_enemy(x) != want.has(int(e.id)):
							bad.append(int(e.id))
				check("boss_enemies_%d" % want.size(), bad.is_empty(), bad.slice(0, 10))
	_hooks()
	_old_save()
	_page_ui()
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_zhenqi", "passed": results.size() - failed.size(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit(0 if failed.is_empty() else 1)


## BattleLogic：首回合当前顺序的超额追加记溢出（下个回合不记）；grant 记真气、同一场再 grant 不重复
func _hooks() -> void:
	var s := _fresh()
	var logic := XBattleLogic.new()
	logic.setup(456, s)
	var a: XActor = logic.actors[0]
	# 用追加行动特性 100% ×8 的替身：makeActionTimes = 9 → 追加 8，超额 4
	XZhenqi.battle.ovf.clear()
	XZhenqi.note_overflow(a, 8)
	check("hook_overflow_excess", int(XZhenqi.battle.ovf.get(a.actor_id, 0)) == 4, XZhenqi.battle.ovf)
	var before := int(XZhenqi.data(a).qi)
	logic.grant({"exp": 0, "gold": 0, "drops": []})
	var once := int(XZhenqi.data(a).qi) - before
	logic.grant({"exp": 0, "gold": 0, "drops": []})
	check("hook_grant_once", once == 260 + 4 and int(XZhenqi.data(a).qi) - before == once, [once, int(XZhenqi.data(a).qi) - before])
	logic.end_battle()

	# 首回合排序里真的调到 note_overflow：start_turn 前后 battle.ovf 只可能增加，且下个回合排序不再增加
	var s2 := _fresh()
	var l2 := XBattleLogic.new()
	l2.setup(1, s2)
	l2.start_turn()
	var after_first: Dictionary = XZhenqi.battle.ovf.duplicate()
	l2.end_turn()
	l2.start_turn()
	check("hook_next_turn_no_overflow", XZhenqi.battle.ovf == after_first, [after_first, XZhenqi.battle.ovf])



func _old_save() -> void:
	var s := _fresh()
	XZhenqi.data(s.actor(1)).qi = 123
	var d = JSON.parse_string(JSON.stringify(s.to_dict()))
	check("save_keeps_qi", int(XZhenqi.data(XState.from_dict(d).actor(1)).qi) == 123)
	for k in d.actors:
		d.actors[k].erase("zhenqi")
	var old := XState.from_dict(d)
	check("old_save_default", _same(XZhenqi.data(old.actor(1)), XZhenqi.default_data()))
	check("battle_cleared_on_load", XZhenqi.battle.is_empty())


## 修行页绘制（标准级，tests/fixtures/zhenqi_page_ui_oracle.json）：标题位置、文字行起点与颜色码、四列位置与宽
func _page_ui() -> void:
	var o = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/zhenqi_page_ui_oracle.json"))
	var s := _fresh()
	s.set_variable(20, 4)
	_set_zq(s.actor(1), {"qi": 700})
	XState.current = s
	var ops := XStatusPage._guide_ops(s.actor(1))
	var h: Array = o.head
	check("page_ui_head", ops[0][1] == h[0] and ops[0][2] == float(h[1]) and ops[0][3] == float(h[2]) and ops[0][4] == float(h[3]) and ops[0][8] == h[6], ops[0])
	var line := ops.filter(func(op): return float(op[3]) == 252.0)
	check("page_ui_text_colors", line.size() >= 4 and line[0][2] == 6.0 and line[1][1].begins_with("人界") and line[1][8] == o.colors.C6 and line.any(func(op): return op[8] == o.colors.C3), line)
	var cols := ops.filter(func(op): return op[1] in ["项目", "难度（含补强）", "自身", "当前"])
	var ok: bool = cols.size() == 4
	for j in range(mini(4, cols.size())):
		var w: Array = o.colsHeader[j]
		ok = ok and cols[j][2] == float(w[1]) and cols[j][4] == float(w[2]) and cols[j][6] == w[3]
	check("page_ui_cols", ok, cols)
