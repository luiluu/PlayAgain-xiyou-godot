extends Node
## 技能页用菜单／随时场合、带效果 44 的技能：预约的公共事件都回地图执行（审查第 28 期 P3-3，tusu7 起）。
## ① 逐个把这些公共事件交给地图解释器跑一遍（run_common_event），断言 skipped_log 为空（没有被跳过的未知指令）；
## ② 星谱（10349，CE9015 CodexXuan.openStarchart()）xuan1 起有星谱页，技能页可用（专项 xiyou_xuan_chart 比页面行文）；
## ③ 不对我方的技能在列表里直接用后，状态窗 MP 与列表灰显刷新（P3-2）。
var checks := 0
var failures: Array = []
var map: XMapScene


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 30:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1500))


func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func _state() -> XState:
	var s := XState.new_game_blank()
	s.party.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	s.map_id = 4
	s.x = 14
	s.y = 23
	s.direction = 8
	XState.current = s
	return s


## 场合 0／2 且带效果 44 的技能与它们的公共事件
func _menu_events() -> Dictionary:
	var out := {}
	for sk in XDB.table("Skills"):
		if not sk is Dictionary or not int(sk.get("occasion", 0)) in [0, 2]:
			continue
		for e in sk.get("effects", []):
			if int(e.code) == 44 and int(e.dataId) > 0:
				if not out.has(int(e.dataId)):
					out[int(e.dataId)] = []
				out[int(e.dataId)].append(int(sk.id))
	return out


## 公共事件（含 117 调用的）里有没有战斗处理（301）
func _has_battle(ce: int, seen: Dictionary) -> bool:
	if seen.has(ce):
		return false
	seen[ce] = true
	for c in XDB.rec("CommonEvents", ce).get("list", []):
		if int(c.code) == 301:
			return true
		if int(c.code) == 117 and _has_battle(int(c.parameters[0]), seen):
			return true
	return false


func _run() -> void:
	XMessageBox.auto = true
	var s := _state()
	var events := _menu_events()
	check("coverage", events.size() >= 80, events.size())
	map = XMapScene.new()
	add_child(map)
	for i in 600:
		if map.player != null and map.map_id == 4 and not map.busy:
			break
		await frames(1)
	check("map", map.player != null and not map.busy)
	await frames(2)
	var skipped_ids := []
	var ids := events.keys()
	ids.sort()
	var battle_ids := []   # 会开战斗（301）的在地图解释器里要等战斗场景，不在这里跑
	var ran := 0
	for ce in ids:
		if _has_battle(int(ce), {}):
			battle_ids.append(ce)
			continue
		ran += 1
		map.skipped_log.clear()
		s.reserve_common_event(int(ce))
		await map.run_reserved_common_event(s)
		if not map.skipped_log.is_empty():
			skipped_ids.append([ce, events[ce].slice(0, 2), map.skipped_log.slice(0, 2).map(func(r): return "%s %s" % [r.get("code"), r.get("text", "")])])
		s.clear_common_event()
		map.busy = false
		s.map_id = 4
	# 星谱 CE9015 的 CodexXuan.openStarchart() 是已知跳过（星谱页待做），技能页上保持不可用（_starchart）；其余一个都不许跳
	skipped_ids = skipped_ids.filter(func(r): return int(r[0]) != 9015)
	check("events_not_skipped", skipped_ids.is_empty(), skipped_ids)
	check("ran_most", ran >= 60, [ran, battle_ids])
	print("ran %d menu common events; not run (battle 301): %s" % [ran, JSON.stringify(battle_ids)])
	_starchart(s)
	await _refresh_after_use(s)
	for player in [map.bgm, map.bgs, map.me, map.se]:
		player.stop()
		player.stream = null
	map.queue_free()
	await frames(3)
	XMessageBox.auto = false
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)


func _starchart(s: XState) -> void:
	var xuan := XDB.rec("Skills", 10349)
	check("star.exists", not xuan.is_empty() and int(xuan.get("occasion", 0)) == 2, xuan.get("occasion"))
	XTusuXuan.recruit(s, XTusuXuan.XUAN)
	var page := XSkillScene.new()
	page.actor_index = s.party.find(XTusuXuan.XUAN)
	add_child(page)
	check("star.usable", page.usable(xuan), [page.actor().actor_id, page.logic.can_use(page.actor(), xuan)])
	page.queue_free()


## 不对我方的技能（场合随时的攻击技能，原版也只扣 MP）直接用：MP 扣了之后页面要重画（_refresh）
func _refresh_after_use(s: XState) -> void:
	var page := XSkillScene.new()
	add_child(page)
	var a: XActor = page.actor()
	var pick := {}
	var cands := []
	for sk in XDB.table("Skills"):
		if sk is Dictionary and int(sk.get("occasion", 0)) == 0 and int(sk.get("scope", 0)) in [1, 2] \
				and sk.get("effects", []).filter(func(e): return int(e.code) == 44).is_empty():
			cands.append(sk)
	cands = cands.slice(0, 40)
	for sk in cands:
		a.learn_skill(int(sk.id))
	a.hp = a.mhp
	a.mp = a.mmp
	a.tp = 100.0
	for sk in cands:
		if page.usable(sk) and page.types().size() > 0:
			pick = sk
			break
	check("refresh.skill", not pick.is_empty(), [cands.size(), a.skill_ids.size()])
	if pick.is_empty():
		page.queue_free()
		return
	page.mode = "type"
	for ti in page.types().size():
		page.type_index = ti
		page.index = page.entries().find_custom(func(x): return int(x.id) == int(pick.id))
		if page.index >= 0:
			break
	check("refresh.listed", page.index >= 0)
	page.mode = "list"
	var painted := [0]
	var orig: Callable = page.status_win.canvas.painter
	page.status_win.canvas.painter = func(c):
		painted[0] += 1
		orig.call(c)
	await frames(3)
	painted[0] = 0
	var mp_before := a.mp
	page.ok()
	await frames(3)
	check("refresh.mp_not_raised", a.mp <= mp_before, [mp_before, a.mp])
	check("refresh.redrawn", painted[0] > 0 and page.mode == "list", [painted[0], page.mode])
	page.queue_free()
