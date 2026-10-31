extends Node
## 【cc·哪吒·未经审查】批量服用丹药（XBulkPills，installBulkPillsRuntime）对照 tests/fixtures/bulk_pills_oracle.json（mv_oracle/bulk_pills_probe.cjs）：
## ① 支持名单、几个不支持的、CE1226 第 3 条阈值改 239 后 1685 不再支持（改回又支持）；
## ② 逐例服用：用了几颗、结束原因、变量 968～971、开关 2466～2469、奖励丹 1497～1500、库存、角色 1 八项能力、提示（条数与前 6 条）；
##    法宝经验丹另比全队法宝经验＝直接 MagicWeaponAllGainExp 同样次数；
## ③ 已学会时 testApply 为假（原版 fullyLearned 走不到）；
## ④ 没审过的事件：先进先出排在单槽后，槽被取走时补上；批量停在「后续事件交由地图执行」；已有预约时停在「等待已有事件」；
## ⑤ 物品页入口：选人确定开数量窗、上下 ±10 左右 ±1 夹在库存内、确定逐颗服用后留在选人；取消回选人；有预约事件时回地图。
const FIXTURE := "res://tests/fixtures/bulk_pills_oracle.json"
const VARS := [968, 969, 970, 971]
const SWS := [2466, 2467, 2468, 2469]
const REWARDS := [1497, 1498, 1499, 1500]
var passed := 0
var total := 0


func check(label: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", label, " ", JSON.stringify(detail).left(3000))


func _ready() -> void:
	_run.call_deferred()


## 探针 newGame：新局，队伍 1、8、9、10
func _state() -> XState:
	var s := XState.new_game_blank()
	s.party.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	XState.current = s
	return s


static func _nums(a: Array) -> Array:
	return a.map(func(v): return float(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else v)


func _snap(s: XState, item_id: int) -> Dictionary:
	var a := s.actor(1)
	a.param_mark_dirty()
	return {"stock": float(s.item_count(item_id)), "vars": VARS.map(func(v): return float(s.variable(v))),
		"switches": SWS.map(func(v): return s.switch(v)), "rewards": REWARDS.map(func(v): return float(s.item_count(v))),
		"param": range(8).map(func(i): return float(a.param(i)))}


static func _wear(a: XActor, kind: String, base: int) -> void:
	var item := XGear.template(kind, base)
	var slot := 0 if kind == "weapon" else a.equip_slots().find(int(item.etypeId))
	a.equips[slot] = item
	a.refresh_passive()


static func _magic_exp(s: XState) -> Array:
	var out := []
	for a in s.members():
		for e in a.equips:
			if XMagicWeapon.is_magic(e):
				out.append([a.actor_id, XMagicWeapon.level_of(e), XMagicWeapon.exp_of(e)])
	return out


func _effective_for(item: Dictionary) -> Callable:
	var page := XItemScene.new()
	page._item = item
	return func(t): return page._effective(t)


func _batch(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var setup: Dictionary = c.setup
	var s := _state()
	var id := int(setup.item)
	var item := XDB.rec("Items", id)
	s.gain_item(id, int(setup.stock))
	if setup.preVar != null:
		s.set_variable(int(setup.preVar[0]), float(setup.preVar[1]))
	var before := _snap(s, id)
	check(c.id + ".before", before == {"stock": float(o.before.stock), "vars": _nums(o.before.vars), "switches": o.before.switches,
		"rewards": _nums(o.before.rewards), "param": _nums(o.before.param)}, [before, o.before])
	var for_friend := int(item.scope) in [7, 8, 9, 10, 11]
	check(c.id + ".forFriend", for_friend == bool(o.forFriend), [for_friend, o.forFriend])
	var targets := [s.actor(1)] if for_friend else []
	var host := XBulkPills.EventHost.new()
	add_child(host)
	var r: Dictionary = await XBulkPills.run(host, s, item, int(setup.requested), targets, for_friend, _effective_for(item))
	host.queue_free()
	check(c.id + ".used", float(r.used) == float(o.used), [r.used, o.used])
	check(c.id + ".reason", str(r.reason) == str(o.reason), [r.reason, o.reason])
	check(c.id + ".remaining", float(r.remaining) == float(o.after.stock), [r.remaining, o.after.stock])
	var after := _snap(s, id)
	check(c.id + ".after", after == {"stock": float(o.after.stock), "vars": _nums(o.after.vars), "switches": o.after.switches,
		"rewards": _nums(o.after.rewards), "param": _nums(o.after.param)}, [after, o.after])
	var uniq := []
	for e in r.events:
		if not uniq.has(e):
			uniq.append(e)
	check(c.id + ".events", _nums(uniq) == _nums(o.events) and r.events.size() == int(o.eventCount), [r.events, o.events, o.eventCount])
	check(c.id + ".toasts", host.toasts.size() == int(o.toastCount) and host.toasts.slice(0, 6) == o.toasts, [host.toasts, o.toasts, o.toastCount])
	check(c.id + ".slot_empty", s.peek_common_event() == 0, s.peek_common_event())
	# 法宝经验丹：全队穿上法宝再吃一遍，法宝经验＝另开一局同样装备、直接 MagicWeaponAllGainExp 同样次数（探针没穿法宝，能力不比）
	if not o.commands.is_empty():
		var amount := float(str(o.commands[0]).split(" ")[1])
		var wearing := [[1, "armor", 121], [8, "armor", 3551], [9, "armor", 3552], [10, "armor", 4516]]
		var s1 := _state()
		var s2 := _state()
		for w in wearing:
			_wear(s1.actor(int(w[0])), str(w[1]), int(w[2]))
			_wear(s2.actor(int(w[0])), str(w[1]), int(w[2]))
		var exp_before := _magic_exp(s1)
		s1.gain_item(id, int(setup.stock))
		XState.current = s1
		var h1 := XBulkPills.EventHost.new()
		add_child(h1)
		await XBulkPills.run(h1, s1, item, int(setup.requested), [], false, _effective_for(item))
		h1.queue_free()
		for i in range(int(o.commandCount)):
			XMagicWeapon.party_gain_exp(s2, amount)
		var got := _magic_exp(s1)
		check(c.id + ".magic_exp", got == _magic_exp(s2) and got != exp_before, [got, _magic_exp(s2), exp_before])


func _supports(o: Dictionary) -> void:
	check("supports.ids", _nums(XBulkPills.supported_ids()) == _nums(o.supported), [XBulkPills.supported_ids(), o.supported])
	var yes := XBulkPills.supported_ids().filter(func(id): return XBulkPills.supports(XDB.rec("Items", id)))
	check("supports.yes", _nums(yes) == _nums(o.yes), [yes, o.yes])
	var no := [1684, 1701, 1718, 1497, 1].filter(func(id): return XBulkPills.supports(XDB.rec("Items", id)))
	check("supports.no", _nums(no) == _nums(o.no), [no, o.no])
	var list: Array = XDB.rec("CommonEvents", 1226).list
	var saved: Array = (list[2].parameters as Array).duplicate()
	list[2].parameters[3] = 239
	var tampered := XBulkPills.supports(XDB.rec("Items", 1685))
	list[2].parameters = saved
	check("supports.tampered", tampered == bool(o.tampered1685), [tampered, o.tampered1685])
	check("supports.restored", XBulkPills.supports(XDB.rec("Items", 1685)) == bool(o.restored1685), o.restored1685)
	# 装备、独立实例不算
	var inst := XDB.rec("Items", 1685).duplicate(true)
	inst["instanceId"] = 1
	check("supports.instance", not XBulkPills.supports(inst), inst.keys())


## ③ 原版 fullyLearned 前一步：已学会效果 43 的技能后 testApply 为假（物品页 _effective 同样为假，蜂鸣）
func _learned(rows: Array) -> void:
	for row in rows:
		var s := _state()
		var a := s.actor(1)
		var item := XDB.rec("Items", int(row.item))
		var eff := _effective_for(item)
		var before: bool = eff.call(a)
		a.learn_skill(int(row.skill))
		var after: bool = eff.call(a)
		check("learned.%d" % int(row.item), before == bool(row.before.testApply) and after == bool(row.after.testApply), [before, after, row])


## ④ 没审过的事件与已有预约
func _deferred() -> void:
	var s := _state()
	s.defer_common_events([501, 502, 503])
	check("defer.first_in_slot", s.peek_common_event() == 501, s.peek_common_event())
	s.clear_common_event()
	check("defer.fifo_2", s.peek_common_event() == 502, s.peek_common_event())
	s.clear_common_event()
	s.clear_common_event()
	check("defer.drained", s.peek_common_event() == 0, s.peek_common_event())
	var got := s.capture_common_events(func(): s.reserve_common_event(7); s.reserve_common_event(0); s.reserve_common_event(8))
	check("capture", got == [7, 8] and s.peek_common_event() == 0, [got, s.peek_common_event()])
	# 已有预约：第二颗的目标检查时（服用之外）占了槽，这颗照吃，下一颗前停在「等待已有事件」
	s.gain_item(1726, 5)
	var host := XBulkPills.EventHost.new()
	add_child(host)
	var calls := {"n": 0}
	var eff := func(_t):
		calls.n += 1
		if calls.n == 2:
			s.reserve_common_event(9)
		return true
	var r: Dictionary = await XBulkPills.run(host, s, XDB.rec("Items", 1726), 5, [s.actor(1)], true, eff)
	check("wait_event", int(r.used) == 2 and str(r.reason) == XBulkPills.WAIT_EVENT and s.peek_common_event() == 9, r)
	s.clear_common_event()
	# 没审过的事件：第二颗通过支持检查后、服用前把 CE1226 改坏，这颗照吃，事件留给地图（占槽），批量停下
	s.gain_item(1685, 5)
	var list: Array = XDB.rec("CommonEvents", 1226).list
	var saved: Array = (list[2].parameters as Array).duplicate()
	calls.n = 0
	var eff2 := func(_t):
		calls.n += 1
		if calls.n == 2:
			list[2].parameters[3] = 239
		return true
	r = await XBulkPills.run(host, s, XDB.rec("Items", 1685), 5, [s.actor(1)], true, eff2)
	list[2].parameters = saved
	check("deferred_event", int(r.used) == 2 and str(r.reason) == XBulkPills.DEFERRED and r.events == [1226] and s.peek_common_event() == 1226
		and s.variable(968) == 1.0 and s.item_count(1685) == 3, [r, s.peek_common_event(), s.variable(968)])
	s.clear_common_event()
	# 1685 的 44 换成别的事件就不支持
	var wrong := XDB.rec("Items", 1685).duplicate(true)
	for e in wrong.effects:
		if int(e.code) == 44:
			e.dataId = 1227
	check("wrong_event_unsupported", not XBulkPills.supports(wrong), wrong.effects)
	host.queue_free()


## ⑤ 物品页：1685 对队友，选人后开数量窗
func _scene() -> void:
	var s := _state()
	s.gain_item(1685, 25)
	var page := XItemScene.new()
	add_child(page)
	page._item = XItemMarks.decorate(s, XDB.rec("Items", 1685))
	page._mode = "actor"
	page._actor = 0
	page._ok()
	check("scene.open", not page._bulk.is_empty() and int(page._bulk.available) == 25 and int(page._bulk.number) == 1 and page.bulk_win.visible, page._bulk.keys())
	page._bulk_change(10)
	page._bulk_change(10)
	page._bulk_change(10)
	check("scene.clamp_up", int(page._bulk.number) == 25, page._bulk.number)
	page._bulk_change(-10)
	page._bulk_change(-1)
	check("scene.step", int(page._bulk.number) == 14, page._bulk.number)
	for i in range(3):
		page._bulk_change(-10)
	check("scene.clamp_down", int(page._bulk.number) == 1, page._bulk.number)
	page._bulk_cancel()
	check("scene.cancel", page._bulk.is_empty() and page._mode == "actor" and s.item_count(1685) == 25, [page._mode, s.item_count(1685)])
	page._ok()
	page._bulk_change(1)
	await page._bulk_ok()
	check("scene.used", page.last_bulk.get("used") == 2 and s.item_count(1685) == 23 and s.variable(968) == 2.0 and page._mode == "actor"
		and page._bulk.is_empty() and not page.bulk_win.visible and not page.to_map, [page.last_bulk, s.item_count(1685), page._mode])
	var notice := XBulkPills.notice(XDB.rec("Items", 1685), page.last_bulk)
	check("scene.notice", notice == "已服用 凝血丹 × 2；剩余 23 颗" and XToast.shown.has(notice), notice)
	# 吃光：回列表
	page._ok()
	page._bulk_change(30)
	await page._bulk_ok()
	check("scene.all_back_to_list", s.item_count(1685) == 0 and page._mode == "list", [s.item_count(1685), page._mode])
	# 已有预约：蜂鸣不开窗
	s.gain_item(1685, 3)
	s.reserve_common_event(9)
	page._mode = "actor"
	page._ok()
	check("scene.reserved_blocks", page._bulk.is_empty(), page._bulk.keys())
	s.clear_common_event()
	# 法宝经验丹不对队友：操作菜单「使用」直接开窗；不支持的（1684）照旧单颗用
	s.gain_item(1901, 2)
	page._item = XItemMarks.decorate(s, XDB.rec("Items", 1901))
	page._mode = "action"
	page._use_direct()
	check("scene.direct_open", not page._bulk.is_empty() and not bool(page._bulk.for_friend) and page._bulk.targets.is_empty(), page._bulk.keys())
	page._bulk_cancel()
	check("scene.direct_cancel_list", page._mode == "list", page._mode)
	page.queue_free()


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not ref is Dictionary:
		print("FAIL fixture")
		print('TEST_RESULT={"passed":0,"total":1}')
		get_tree().quit(1)
		return
	var batches := 0
	for c in ref.cases:
		check(str(c.id) + ".oracle_ok", c.errors.is_empty(), c.errors)
		if c.id == "supports":
			_supports(c.observed)
		elif str(c.id).begins_with("batch."):
			await _batch(c)
			batches += 1
		elif c.id == "learned":
			_learned(c.observed)
	check("batches", batches == 7, batches)
	await _deferred()
	await _scene()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
