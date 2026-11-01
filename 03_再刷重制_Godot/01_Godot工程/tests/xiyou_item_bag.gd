extends Node
## 道具用后续事件（installItemBagContinuationRuntime，XItemBagReturn）对原版参照 tests/fixtures/item_bag_oracle.json
## （mv_oracle/item_bag_probe.cjs，11 例）：真地图 → 主菜单 → 物品页 → 使用（对队友的选第 1 位）。
## 比：当场的结果提示（主说明卡／toaster）、是否回地图、事件跑完后回到物品页的分类与选中、回来后的提示、队伍与数量。
## 「换画面」一例在物品页关掉后往地图 ui 里加一个页面（原版 Scene_Map.stop 时下一个是 Scene_Battle）。
## O-待定（快照记 TP）：回 TP 两例先关掉开关对原版，再开着看改成「已生效」。
var checks := 0
var failures: Array = []
var map: XMapScene


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 20:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1500))


func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XPetCapture.clock = func(): return {"day": 1, "hour": 12, "minute": 15}
	XMessageBox.auto = true
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/item_bag_oracle.json"))
	check("source", f.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("complete", f.cases.size() == 11)
	rules()
	for c in f.cases:
		check(c.id + ".native", c.errors.is_empty(), c.errors)
		if c.id.begins_with("tp."):
			XItemBagReturn.snapshot_tp = false
			await run_case(c, c.observed)
			XItemBagReturn.snapshot_tp = true
			var fixed: Dictionary = c.observed.duplicate(true)
			var name := str(XDB.rec("Items", int(c.setup.item)).name)
			for e in fixed.used.trace:
				e.text = "已生效：" + name + "（检测到角色或背包变化）"
			await run_case(c, fixed, ".o-tp")
		else:
			await run_case(c, c.observed)
	finish()


## 纯规则：四种提示的先后、换装卡判定、只认自己的事件
func rules() -> void:
	var s := XState.new_game_blank()
	var item := XDB.rec("Items", 532)
	var ctx := XItemBagReturn.begin(s, item, 0, 0)
	check("rule.none", XItemBagReturn.result_text(s, ctx) == "未检测到效果：能量药剂（请检查使用条件）")
	ctx.inline = true
	check("rule.inline", XItemBagReturn.result_text(s, ctx).begins_with("事件已执行："))
	s._gain_raw(532, 1)
	ctx = XItemBagReturn.begin(s, item, 0, 0)
	s._gain_raw(532, -1)
	check("rule.used", XItemBagReturn.result_text(s, ctx).begins_with("已使用："))
	s.gold += 1
	check("rule.effect-first", XItemBagReturn.result_text(s, ctx).begins_with("已生效："))
	var wardrobe := XDB.rec("CommonEvents", XItemBagReturn.WARDROBE_EVENT)
	check("rule.wardrobe", XItemBagReturn.inline_wardrobe(wardrobe))
	var waiting := wardrobe.duplicate(true)
	waiting.list.insert(0, {"code": 230, "indent": 0, "parameters": [1]})
	check("rule.wardrobe-wait", not XItemBagReturn.inline_wardrobe(waiting))
	check("rule.item-calls", XItemBagReturn.item_calls(XDB.rec("Items", 2475), 1343) and not XItemBagReturn.item_calls(XDB.rec("Items", 532), 1343))
	s.actor(1)
	XItemBagReturn.snapshot_tp = false
	var tp_ctx := XItemBagReturn.begin(s, XDB.rec("Items", 789), 0, 0)
	s.actor(1).tp += 30
	check("rule.tp-native", XItemBagReturn.result_text(s, tp_ctx).begins_with("未检测到效果："))
	XItemBagReturn.snapshot_tp = true
	tp_ctx = XItemBagReturn.begin(s, XDB.rec("Items", 789), 0, 0)
	s.actor(1).tp += 30
	check("rule.tp-fixed", XItemBagReturn.result_text(s, tp_ctx).begins_with("已生效："))


func new_state(spec: Dictionary) -> XState:
	var s := XState.new_game_blank()
	s.party.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	s.map_id = 4
	s.x = 14
	s.y = 23
	s.direction = 8
	var a := s.actor(int(spec.actor))
	if spec.has("damage"):
		a.hp = a.mhp - float(spec.damage)
	for id in spec.get("pre", []):
		a.learn_skill(int(id))
	if spec.has("preActor"):
		s.add_actor(int(spec.preActor))
	s._gain_raw(2, 1)
	s._gain_raw(int(spec.item), int(spec.get("stock", 1)))
	var segment := XGuide.segment_of(XZhenqi.progress_floor(s))
	if not segment.is_empty():
		XGuide.seen(s, "seg:" + str(segment.key), true)
	return s


func results(texts: Array) -> Array:
	return texts.filter(func(t): return XItemBagReturn.is_result_text(str(t)))


func run_case(c: Dictionary, want: Dictionary, tag := "") -> void:
	var spec: Dictionary = c.setup
	var id: String = c.id + tag
	var s := new_state(spec)
	var item := XDB.rec("Items", int(spec.item))
	map = XMapScene.new()
	add_child(map)
	for i in 600:
		if map.player != null and map.map_id == 4 and not map.busy:
			break
		await frames(1)
	check(id + ".map", map.player != null and not map.busy)
	await frames(2)
	XToast.shown.clear()
	map.open_menu()
	var menu: XMenu
	for i in 300:
		var menus := map.ui.get_children().filter(func(n): return n is XMenu)
		if not menus.is_empty():
			menu = menus[0]
			break
		await frames(1)
	if menu == null:
		check(id + ".menu", false)
		await close_map()
		return
	menu._cmd_index = 0
	menu._ok()
	await frames(2)
	var page: XItemScene = menu.get_children().filter(func(n): return n is XItemScene)[0]
	page._cat = 4 if int(item.get("itypeId", 1)) == 2 else 0
	page._mode = "list"
	page._index = page.entries().find_custom(func(e): return int(e.rec.id) == int(item.id))
	# 探针里的 index 是物品页原来停的那一格（回物品页时东西没了才用到），只有回物品页的几例与重制列表一致
	check(id + ".listed", page._index >= 0 and (want.bag == null or page._index == int(spec.index)), [page._index, spec.index])
	page._refresh()
	var before_skills: Array = s.actor(int(spec.actor)).skill_ids.duplicate()
	page._ok()
	page._ok()
	if page._mode == "actor":
		page._actor = 0
		page._ok()
	var used_help: Array = want.used.trace.filter(func(e): return e.t == "help").map(func(e): return e.text)
	var used_toast: Array = want.used.trace.filter(func(e): return e.t == "toast").map(func(e): return e.text)
	var went: bool = want.used.trace.any(func(e): return e.t == "goto" and e.scene == "Scene_Map")
	check(id + ".to-map", page.to_map == went, [page.to_map, went])
	check(id + ".toast", results(XToast.shown) == used_toast, [XToast.shown, used_toast])
	if not went:
		check(id + ".notice", (page._notice.get("text", "") == used_help[0]) if used_help.size() == 1 else page._notice.is_empty(), [page._notice, used_help])
		check(id + ".count", s.item_count(int(item.id)) == int(want.used.count), [s.item_count(int(item.id)), want.used.count])
		# 新局角色 1 的初始技能两边不同（重制含职业与种族学会的），只比这次用道具前后的增减
		var got: Array = s.actor(int(spec.actor)).skill_ids.filter(func(k): return not before_skills.has(k))
		var lost: Array = before_skills.filter(func(k): return not s.actor(int(spec.actor)).skill_ids.has(k))
		var want_got: Array = Array(want.used.skills).map(func(v): return int(v)).filter(func(k): return not Array(want.before.skills).has(float(k)) and not Array(want.before.skills).has(k))
		var want_lost: Array = Array(want.before.skills).map(func(v): return int(v)).filter(func(k): return not Array(want.used.skills).map(func(v): return int(v)).has(k))
		check(id + ".skills", got == want_got and lost == want_lost, [got, lost, want_got, want_lost])
		check(id + ".no-event", s.peek_common_event() == 0 and map.skipped_log.is_empty(), map.skipped_log)
		await close_map()
		return
	if spec.get("sceneChange", false):
		map.ui.add_child(Control.new())
	XToast.shown.clear()
	var back: XItemScene
	var idle := 0
	for i in 900:
		var menus := map.ui.get_children().filter(func(n): return n is XMenu and not n.is_queued_for_deletion())
		if menus.size() == 1:
			var pages: Array = menus[0].get_children().filter(func(n): return n is XItemScene and not n.is_queued_for_deletion())
			if pages.size() == 1 and pages[0]._mode == "list":
				back = pages[0]
				break
		# 事件跑完后要让地图 _process 走几帧（回物品页在那里判），连续空闲 30 帧才算不回来
		idle = idle + 1 if not map.busy and not map._menu_open and s.peek_common_event() == 0 else 0
		if idle > 30:
			break
		await frames(1)
	var bag = want.bag
	check(id + ".returned", (back != null) == (bag != null), [back != null, bag != null, map.map_id, map.busy])
	check(id + ".map-id", map.map_id == int(want.map.mapId), [map.map_id, want.map.mapId])
	check(id + ".party", Array(s.party) == Array(want.after.party).map(func(v): return int(v)), [s.party, want.after.party])
	check(id + ".after-count", s.item_count(int(item.id)) == int(want.after.count), [s.item_count(int(item.id)), want.after.count])
	check(id + ".skipped", map.skipped_log.is_empty(), map.skipped_log)
	check(id + ".pending-cleared", not s.has_meta(XItemBagReturn.META))
	if back != null and bag != null:
		var help: Array = bag.trace.filter(func(e): return e.t == "help").map(func(e): return e.text)
		var toast: Array = bag.trace.filter(func(e): return e.t == "toast").map(func(e): return e.text)
		var ids: Array = back.entries().map(func(e): return int(e.rec.id))
		check(id + ".bag.list", ids == Array(bag.data).map(func(v): return int(v)), [ids, bag.data])
		check(id + ".bag.index", back._index == int(bag.index), [back._index, bag.index])
		check(id + ".bag.notice", back._notice.get("text", "") == help[0] and back.help_card.visible and back.help_card.rows[0][0] == help[0], [back._notice, help])
		check(id + ".bag.toast", results(XToast.shown) == toast, [XToast.shown, toast])
		# 光标挪开才换回说明；取消一路回主菜单
		if ids.size() > 1:
			back._move(-1 if back._index > 0 else 1, false)
			back._refresh()
			check(id + ".bag.notice-cleared", back._notice.is_empty())
		var restored: XMenu = back.get_parent()
		back._cancel()
		back._cancel()
		await frames(2)
		check(id + ".bag.cancel-to-menu", restored._mode == "command" and map._menu_open, restored._mode)
	await close_map()


func close_map() -> void:
	for player in [map.bgm, map.bgs, map.me, map.se]:
		player.stop()
		player.stream = null
	map.queue_free()
	await frames(3)


func finish() -> void:
	XPetCapture.clock = Callable()
	XMessageBox.auto = false
	await get_tree().create_timer(0.3, true, false, true).timeout
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
