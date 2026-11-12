extends Node
## 轮回入口（installReincarnationRandomRuntime：CodexReincarnationRandom.open／entryAccepted／entryHard／finishEntry）
## 对原版参照 tests/fixtures/reincarnation_entry_oracle.json（mv_oracle/reincarnation_entry_probe.cjs，8 例）：
## 原版 open 会 push Scene_ReincarnationDraft 让事件停下，探针真创建这个场景、调菜单处理函数，再让 Map221 引路人事件接着跑。
## 这里用真的 Map221 事件 3 + 自动应答，逐例比：开关 2282／2303／2307、队伍、物品 4／2896、全员学 8105、入口结果（accepted／hard）、
## 111 两个条件分支走哪边（以结果开关为准）、「本局轮回已经开启」提示。
## 比原版两层菜单时把回退开关 MVScript.REINCARNATION_LINEUP_MENU 置 true；默认（false，O-270）去掉阵容规则菜单，
## 同一批用例按「只选难度」的应答再跑一遍（nolineup.*），结果应与原版选「常规阵容」相同。
## 已知差异（不改代码，记在交付单）：①原版阵容规则菜单多一项「随机角色」（9 选 5 选人，O-035 不做）；
## ②原版 pending.active（存档里 entryPending）这条路重制没有这个存档字段，不比；③原版战斗在探针里当作胜利，这里真打（force_auto）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
var results: Array = []
var toasts_seen: Array = []


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _scene() -> Node:
	return get_tree().current_scene


func _wait(cond: Callable, timeout := 6000) -> bool:
	for i in range(timeout):
		var sc = _scene()
		if sc is XMapScene:
			for t in sc.toasts:
				if not toasts_seen.has(t):
					toasts_seen.append(t)
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _map_idle(map_id: int) -> bool:
	var s = _scene()
	return s is XMapScene and s.map_id == map_id and s.player != null and not s.busy


func _to_map221() -> XMapScene:
	XMessageBox.auto_answers = [0, 0, 0, "测试", 0, 2, 0, 0]
	XState.new_game_blank()
	XState.current.random_master = XRandomStream.hex64(20261013)
	get_tree().change_scene_to_file.call_deferred("res://modes/xiyou/map/map_scene.tscn")
	await _wait(func(): return _map_idle(221))
	return _scene()


func _event(map: XMapScene, id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null


## 用例 id → 自动应答（事件选项「轮回归来！」=1，再是难度 0 普通／1 困难／2 返回，阵容 0 常规／1 返回）
const ANSWERS := {
	"normal.classic": [1, 0, 0], "hard.classic": [1, 1, 0], "top.back": [1, 2],
	"normal.back.then.classic": [1, 0, 1, 0, 0], "hard.back.then.hard.classic": [1, 1, 1, 1, 0],
	"already.2307": [1], "already.2303": [1],
}
## 默认去掉阵容规则菜单时的应答（只有难度一层；「阵容 → 返回」的两例没有对应走法，不跑）
const ANSWERS_NO_LINEUP := {
	"normal.classic": [1, 0], "hard.classic": [1, 1], "top.back": [1, 2], "already.2307": [1], "already.2303": [1],
}


func _sorted(a: Array) -> Array:
	var out := a.map(func(x): return int(x))
	out.sort()
	return out


func _knowers(skill: int) -> int:
	var n := 0
	var s := XState.current
	for id in range(1, XDB.table("Actors").size()):
		var rec := XDB.rec("Actors", id)
		if not rec.is_empty() and str(rec.get("name", "")) != "" and not bool(rec.get("_gojo", false)) and s.actor(id).skill_ids.has(skill):  # 重制新加的五条悟（XGojo）不在原版参照里
			n += 1
	return n


func _run() -> void:
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	TestEnv.isolate("xiyou_reincarnation_entry")   # 测试目录、删旧 options.json、新源大厅漩涡过场 rift1 记成看过
	Engine.time_scale = 6.0
	seed(20261013)
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/reincarnation_entry_oracle.json"))
	_check("source", f.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	_check("complete", f.cases.size() == 8)
	for c in f.cases:
		_check(c.id + ".native", c.errors.is_empty(), c.errors)
	MVScript.REINCARNATION_LINEUP_MENU = true
	await _cases(f, ANSWERS, "")
	MVScript.REINCARNATION_LINEUP_MENU = false
	await _cases(f, ANSWERS_NO_LINEUP, "nolineup.")
	DirAccess.remove_absolute(XSave.dir())
	Engine.time_scale = 1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail).left(600))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _cases(f: Dictionary, answers: Dictionary, tag: String) -> void:
	for c in f.cases:
		if not answers.has(c.id):
			continue  # pending.active：重制没有 entryPending 存档字段
		var want: Dictionary = c.observed.after
		var sw := {}
		for p in want.switches:
			sw[int(p[0])] = bool(p[1])
		var map := await _to_map221()
		map.toasts.clear()
		toasts_seen = []  # 进入新地图后才开始记（上一例的提示留在旧场景里）
		var s := XState.current
		for k in c.setup.get("pre", {}).get("switches", {}):
			s.set_switch(int(k), true)
		XMessageBox.auto_answers = answers[c.id].duplicate()
		await map.run_event(_event(map, 3))
		var accepted: bool = bool(want.entryAccepted)
		if accepted:
			await _wait(func(): return _map_idle(4) and s.self_switch(4, 20, "A"))
		else:
			await _wait(func(): return false, 30)
		_check(tag + c.id + ".switches", [2282, 2303, 2307].all(func(i): return s.switch(i) == sw[i]), [s.switch(2282), s.switch(2303), s.switch(2307), sw])
		_check(tag + c.id + ".party", _sorted(s.party) == _sorted(want.party), [s.party, want.party])  # 顺序不比：探针新局按 1、8、9、10 入队，重制开局是 1、8、10、9
		_check(tag + c.id + ".items", s.item_count(4) == int(want.item4) and s.item_count(2896) == int(want.item2896), [s.item_count(4), s.item_count(2896), want.item4, want.item2896])
		var hard_knowers := _knowers(8105)
		var want_knowers := 0
		for p in want.knowers:
			if int(p[0]) == 8105:
				want_knowers = int(p[1])
		_check(tag + c.id + ".skill8105", hard_knowers == want_knowers, [hard_knowers, want_knowers])
		var entry: Dictionary = MVScript.reincarnation_entry
		_check(tag + c.id + ".entry", bool(entry.get("accepted", false)) == accepted and bool(entry.get("hard", false)) == bool(want.entryHard), [entry, want.entry])
		_check(tag + c.id + ".toasts", (c.observed.toasts as Array).all(func(t): return toasts_seen.has(t)) and (not (c.observed.toasts as Array).is_empty() or toasts_seen.is_empty() or accepted),
			[toasts_seen, c.observed.toasts])
		_check(tag + c.id + ".hub_or_stay", (_scene() is XMapScene) and (_scene().map_id == 4) == accepted, _scene().map_id if _scene() is XMapScene else -1)
		DirAccess.remove_absolute(XSave.path(1))
