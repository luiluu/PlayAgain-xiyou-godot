extends Node
## 传送／解锁链（cc 悟空 accept3）：表驱动，补「还没有地图场景专项真走到」的目标图。
## 用例表 tests/fixtures/unlock_chain_cases.json 由 03_转换工具/解锁链表.py --cases 从原版地图数据生成：
## 每个目标图挑一条能解出条件的入口（页条件＋外层条件分歧＋选项分支），写明开局要设的开关、变量、物品、独立开关、金钱和选项应答。
## 每例：新开局 → 站到来源图 → 按表设状态 → 在地图场景里执行该事件（战斗一开始击倒全部敌人）→ 断言落到原版指定的目标图与坐标。
## 用例页不是按表状态自然选中的页时（更高页恰好也满足），强制用该页执行，并在输出里记 forced（页选取另由 xiyou_event_compare 逐页对照）。
## 审查 45 P3-4：fixture 的 known_forced（用例号→自然选中的页）列出预期要强制的用例；收尾断言本分片实际 forced 与它一致，
## 页选取退步（该选用例页却选了别的页）或该强制的不再强制，都会挂。
## 落点按 MVInterpreter.TRANSFER_FIX 的优化修正（如 O-062 三十三层 (24,12)→(24,13)）。
## 已知不走的入口写在表的 skip（原因见交付单 cc_wukong-accept3）。part 分片（并行测试 300 秒上限）。
## accept4：用例另含「入口两边都没覆盖」的每一条（不只每个目标图一条）；random 字段＝分歧读的变量在事件里先被随机赋值，
## 本例把 MVInterpreter.fixed_random 固定成它（同参照固定 Math.random）；dir＝分歧要玩家朝向；同图移动断言玩家落到目标坐标。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const CASES := "res://tests/fixtures/unlock_chain_cases.json"
const PARTS := 4
const CASE_MS := 30000
const WaitBudget := preload("res://tests/wait_budget.gd")

@export var part := 1

var results: Array = []
var forced: Array = []
var fails: Array = []


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set("part", part)
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		fails.append(name)
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _scene() -> Node:
	return get_tree().current_scene


func _map_ready(map_id: int) -> bool:
	var s = _scene()
	return s is XMapScene and s.map_id == map_id and s.player != null


func _party() -> void:
	XActor.test_param_max = 1.0e30
	for a in XState.current.members():
		var eq: Array = a.equip_list()
		if eq.is_empty():
			continue
		eq[0].params = [1.0e14, 1.0e6, 5.0e13, 5.0e6, 5.0e13, 5.0e6, 1.0e5, 1.0e3]
		a.refresh_passive()
		a.hp = a.mhp
		a.mp = a.mmp


func _battle_of(map: Node) -> XBattleScene:
	if not (map is XMapScene):
		return null
	for n in map.ui.get_children():
		if n is XBattleScene:
			return n
	return null


func _apply(s: XState, c: Dictionary) -> void:
	for k in c.switches:
		s.set_switch(int(k), bool(c.switches[k]))
	for k in c.vars:
		s.set_variable(int(k), float(c.vars[k]))
	for k in c.items:
		var want := int(c.items[k])
		var have := s.item_count(int(k))
		if have != want:
			s.gain_item(int(k), want - have)
	for ch in c.self:
		s.set_self_switch(int(c.src_map), int(c.ev), str(ch), bool(c.self[ch]))
	for id in c.actors:
		if not s.party.has(int(id)):
			s.add_actor(int(id))
		# 超强者（如一护 148）在默认难度被 add_actor 拦下：来源页要的是「已在队」，照已入队的存档直接放进队伍，
		# 不开地狱等难度开关（免得改动来源图别的页）
		if not s.party.has(int(id)) and not XItemMarks.can_acquire_actor(s, int(id)):
			s.actor(int(id))
			s.party.append(int(id))
	if int(c.gold) > 0:
		s.gain_gold(int(c.gold))


func _case(c: Dictionary) -> void:
	var tag := "%s_to%d_%d_%d" % [c.id, int(c.dest), int(c.xy[0]), int(c.xy[1])]
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.map_id = int(c.src_map)
	s.x = int(c.pos[0])
	s.y = int(c.pos[1])
	s.direction = int(c.get("dir", 2))
	_apply(s, c)
	_party()
	# 固定随机数在进图前就设好：来源页是自动执行（深渊之门等）时进图即跑，用的也是这个值
	MVInterpreter.fixed_random = float(c.get("random", -1.0))
	# accept5：random_seq＝事件里每一次随机代入各取一个值（按抽取顺序；「遇到深渊」与「深渊难度」要取不同值）
	MVInterpreter.random_sequence = Array(c.get("random_seq", []))
	MVInterpreter._sequence_at = 0
	get_tree().change_scene_to_file(MAP_SCENE)
	var t0 := WaitBudget.new(CASE_MS)
	while t0.waiting() and not (_map_ready(int(c.src_map)) and not _scene().busy):
		await get_tree().process_frame
	if not _check(tag + "_src_loaded", _map_ready(int(c.src_map)), [_scene().get("map_id")]):
		_reset_random()
		return
	var map: XMapScene = _scene()
	var e: MVEvent = null
	for x in map.events:
		if x.event_id == int(c.ev):
			e = x
	if not _check(tag + "_event", e != null):
		_reset_random()
		return
	if e.page_index != int(c.page):
		forced.append([c.id, e.page_index])
		e.page_index = int(c.page)
		e.page = e.data.pages[int(c.page)]
	XMessageBox.auto_answers = c.answers.duplicate()
	var same_map := int(c.dest) == int(c.src_map)
	var want: Vector2i = MVInterpreter.TRANSFER_FIX.get("%d:%d:%d:%d:%d" % [int(c.src_map), int(c.ev), int(c.dest), int(c.xy[0]), int(c.xy[1])],
		Vector2i(int(c.xy[0]), int(c.xy[1])))
	var st := {"done": false}
	(func():
		await map.run_event(e)
		st.done = true).call()
	var landed = null
	t0 = WaitBudget.new(CASE_MS)
	while t0.waiting() and landed == null:
		var b := _battle_of(_scene())
		if b != null and not b.logic.enemies.is_empty():
			for en in b.logic.enemies:
				if en.is_alive():
					en.hp = 0.0
					en.add_state(1)
		if _map_ready(int(c.dest)) and (not same_map or _scene().player.grid == want):
			landed = _scene().player.grid
		await get_tree().process_frame
	_reset_random()
	# 落点修正（O-062 等，MVInterpreter.TRANSFER_FIX）照游戏用的表
	_check(tag + "_landed", landed == want,
		{"want": c.xy, "got": landed, "scene_map": _scene().get("map_id"), "cond": c.cond})
	# 目标图的自动事件（过场）跑完再换下一例，免得旧解释器挂在已释放的场景上
	var t1 := WaitBudget.new(5000)
	while t1.waiting() and not st.done:
		await get_tree().process_frame


func _reset_random() -> void:
	MVInterpreter.fixed_random = -1.0
	MVInterpreter.random_sequence = []
	MVInterpreter._sequence_at = 0


func _run() -> void:
	GameApp.fast_forward()
	XSave.dir_override = "user://test_xiyou_unlock_chain_%d" % part
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261105)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASES))
	var cases: Array = data.cases
	var known: Dictionary = data.get("known_forced", {})
	var want_forced := {}
	var mine := 0
	for i in range(cases.size()):
		if i % PARTS == part - 1:
			mine += 1
			if known.has(cases[i].id):
				want_forced[str(cases[i].id)] = int(known[cases[i].id])
			await _case(cases[i])
	_check("part%d_has_cases" % part, mine > 0)
	var got_forced := {}
	for f in forced:
		got_forced[str(f[0])] = int(f[1])
	_check("part%d_forced_pages_as_known" % part, got_forced == want_forced, {"want": want_forced, "got": got_forced})
	_finish()


func _finish() -> void:
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	print("强制页：", JSON.stringify(forced))
	print("失败：", JSON.stringify(fails))
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
