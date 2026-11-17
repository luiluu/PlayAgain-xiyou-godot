extends Node
## 天启篇大厅 NPC 清理（XTianqiHall，T079／D138）：
## 一、删的 13 件、并的 19 件在天启篇都不出，宿主照常出；西游档、回退开关关掉都回原样；
## 二、七印祭坛入口 EV048：没有一印揭开时不出（天顶剑提示作废），揭开后出；
## 三、治愈辅 5978 全工程只有 EV057 一处学习入口，天启篇 EV057 不出；五只猫（110～114）数据不动；
## 四、合并选单：治疗（免费冷却、付费扣钱）、补给领一次就不再列、名单挪到改版向导、讨债人并进赌桌、招募／商店分组／传送的宿主不接；
## 五、真地图（XMapScene）里跑宿主选单，功能照旧。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
const CATS := [110, 111, 112, 113, 114]
var results: Array = []


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


func _run() -> void:
	var kit = Kit.new("xiyou_tianqi_hall")   # 存档、配置都写测试目录，不碰本机设置
	XConfig.whisper_mark("rift1")   # 大厅漩涡过场（EV76）、二阶段过场当作播过：不占住大厅，退出时也不挂在色调等待上
	XConfig.whisper_mark("rift2")
	_lists()
	_hidden()
	_altar()
	_healing_skill()
	await _live()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	kit.teardown()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _plain_state() -> XState:
	var s := XState.new_game_blank()
	s.set_variable(20, 3)
	XState.current = s
	return s


func _ev(map_id: int, event_id: int) -> Dictionary:
	for ev in XDB.map(map_id).get("events", []):
		if ev != null and int(ev.id) == event_id:
			return ev
	return {}


## 真地图数据里的事件，按当前状态选页
func _page_of(map_id: int, event_id: int) -> int:
	var ev := _ev(map_id, event_id)
	if ev.is_empty():
		return -2
	var e := MVEvent.new()
	e.map_id = map_id
	e.event_id = event_id
	e.data = ev
	var p := e._find_page()
	e.free()
	return p


## 一、清单与 D138 对得上：删 13、并 19，宿主不在删并名单里
func _lists() -> void:
	_check("deleted_13", XTianqiHall.DELETED.size() == 13, XTianqiHall.DELETED)
	_check("merged_19", XTianqiHall.MERGED.size() + [XTianqiHall.ALTAR_EVENT].size() == 19 and not XTianqiHall.MERGED.has(XTianqiHall.ALTAR_EVENT), XTianqiHall.MERGED.keys())  # 48 并 73 改为祭坛入口专门处理
	_check("no_overlap", XTianqiHall.DELETED.all(func(id): return not XTianqiHall.MERGED.has(id)))
	var hosts := XTianqiHall.MERGED.values()
	_check("hosts_not_removed", hosts.all(func(id): return not XTianqiHall.DELETED.has(int(id)) and not XTianqiHall.MERGED.has(int(id))), hosts)
	_check("labels_cover_menu_sources", XTianqiHall.MERGED.keys().all(func(src): return not XTianqiHall.HOSTS.has(int(XTianqiHall.MERGED[src])) or XTianqiHall.LABELS.has(src)))
	_check("t071_events_untouched", [70, 78, 79, 80, 81, 1, 7].all(func(id): return not XTianqiHall.DELETED.has(id) and not XTianqiHall.MERGED.has(id)))
	var text := JSON.stringify([XTianqiHall.HOSTS, XTianqiHall.LABELS, XTianqiHall.ROSTER_LABELS, XTianqiHall.GIVEN_LINE])
	_check("menu_text_no_xiyou", not text.contains("西游") and not text.contains("天道") and not text.contains("教派"), text)


func _hidden() -> void:
	Kit.new_game("jiusi")
	var gone := (XTianqiHall.DELETED + XTianqiHall.MERGED.keys()).filter(func(id): return _ev(4, int(id)).size() > 0 and _page_of(4, int(id)) != -1)
	_check("tq_removed_have_no_page", gone.is_empty(), gone)
	var hosts_shown := [1, 6, 17, 60, 71, 73, 54, 27].filter(func(id): return _page_of(4, id) < 0)
	_check("tq_hosts_shown", hosts_shown.is_empty(), hosts_shown)
	_check("tq_hides_only_hall", not XTianqiHall.hides(5, 41) and not XTianqiHall.hides(4, 70) and not XTianqiHall.hides(4, 62))
	# 西游档：清理一件都不作数
	_plain_state()
	_check("plain_hides_none", (XTianqiHall.DELETED + XTianqiHall.MERGED.keys()).all(func(id): return not XTianqiHall.hides(4, int(id))))
	_check("plain_ev041_shown", _page_of(4, 41) >= 0 and _page_of(4, 47) >= 0 and _page_of(4, 57) >= 0 and _page_of(4, 5) >= 0, [_page_of(4, 41), _page_of(4, 47), _page_of(4, 57)])
	# 回退开关
	Kit.new_game("jiusi")
	XTianqiHall.ENABLED = false
	_check("switch_off_hides_none", (XTianqiHall.DELETED + XTianqiHall.MERGED.keys()).all(func(id): return not XTianqiHall.hides(4, int(id))))
	_check("switch_off_ev041_shown", _page_of(4, 41) >= 0 and _page_of(4, 47) >= 0 and _page_of(4, 57) >= 0)
	XTianqiHall.ENABLED = true
	# 招募：15、19 原版最后一页就是无条件空页，两边都从不出现（清单误记成「实际招募」）
	for id in [15, 19]:
		var pages: Array = _ev(4, id).pages
		var last: Dictionary = pages[pages.size() - 1]
		var c: Dictionary = last.conditions
		_check("recruit_%d_dead_in_original" % id, not (c.switch1Valid or c.switch2Valid or c.variableValid or c.selfSwitchValid or c.itemValid or c.actorValid) \
			and (last.list as Array).all(func(x): return int(x.code) == 0))


func _altar() -> void:
	var s := Kit.new_game("jiusi")
	_check("altar_locked_hidden", not XTianqiQiyin.intercepts(s, 4, 48) and XTianqiHall.hides(4, 48) and _page_of(4, 48) == -1)
	s.set_variable(20, 32)   # 打过 31 层：白、红两印揭开
	_check("altar_open_shown", XTianqiQiyin.intercepts(s, 4, 48) and not XTianqiHall.hides(4, 48) and _page_of(4, 48) >= 0)
	_plain_state()
	_check("altar_plain_shown", not XTianqiHall.hides(4, 48) and _page_of(4, 48) >= 0)


## 三、治愈辅：扫全部地图与公共事件，学 5978 的只有大厅 EV057
func _healing_skill() -> void:
	var where := []
	for f in DirAccess.get_files_at(XDB.BASE + "maps"):
		if not f.begins_with("Map") or not f.ends_with(".json"):
			continue
		var mid := int(f.substr(3, 3))
		for ev in XDB.map(mid).get("events", []):
			if ev == null:
				continue
			for p in ev.pages:
				if _teaches(p.list, 5978):
					where.append("%d:%d" % [mid, int(ev.id)])
					break
	for ce in XDB.table("CommonEvents"):
		if ce is Dictionary and _teaches(ce.get("list", []), 5978):
			where.append("ce:%d" % int(ce.id))
	_check("heal_skill_only_ev057", where == ["4:57"], where)
	Kit.new_game("jiusi")
	_check("heal_skill_entry_gone_tq", _page_of(4, 57) == -1)
	_plain_state()
	_check("heal_skill_entry_plain", _page_of(4, 57) >= 0)
	# 五只猫：数据还在，EV057 原数据照旧送这五只（没改 generated）
	_check("cats_data_kept", CATS.all(func(id): return str(XDB.rec("Actors", id).get("name", "")) != ""), CATS.map(func(id): return XDB.rec("Actors", id).get("name", "")))
	var adds := []
	for c in _ev(4, 57).pages[0].list:
		if int(c.code) == 129 and int(c.parameters[1]) == 0:
			adds.append(int(c.parameters[0]))
	_check("ev057_data_unchanged", CATS.all(func(id): return adds.has(id)), adds)


func _teaches(list: Array, skill: int) -> bool:
	for c in list:
		if int(c.code) == 318 and int(c.parameters[2]) == 0 and int(c.parameters[3]) == skill:
			return true
		if (int(c.code) == 355 or int(c.code) == 655) and str(c.parameters[0]).contains("learnSkill(%d)" % skill):
			return true
	return false


func _labels(map: XMapScene, s: XState, id: int) -> Array:
	return XTianqiHall.menu(map, s, id).map(func(o): return str(o[0]))


func _event(map: XMapScene, id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null


## 四、五：真地图
func _live() -> void:
	var s := Kit.new_game("jiusi")
	s.map_id = 4
	s.x = 14
	s.y = 25
	var map := XMapScene.new()
	add_child(map)
	for _f in 300:
		await get_tree().process_frame
		if map.player != null and map.map_id == 4 and not map.busy:
			break
	_check("live_in_hall", map.map_id == 4 and not map.busy, [map.map_id, map.busy])
	# 选单内容
	var l6 := _labels(map, s, 6)
	_check("menu6_heals", l6 == ["买东西／治疗", "限时免费治疗", "付费治疗", "离开"], l6)
	var l1 := _labels(map, s, 1)
	_check("menu1_gifts", l1.has("开局补给") and l1.has("寻宝诀下篇") and l1.has("滑稽币（十分钟一次）") and not l1.has("召唤符文赠礼") and not l1.has("难度赠礼"), l1)
	var l71 := _labels(map, s, 71)
	_check("menu71_roster_speed", l71.has("强者名单") and l71.has("超强者名单") and l71.has("调节移动速度"), l71)
	_check("menu73_tip", _labels(map, s, 73).has("商人交易提示") and not _labels(map, s, 73).has("符文图鉴"), _labels(map, s, 73))
	_check("menu17_repair", _labels(map, s, 17).has("修复形象"), _labels(map, s, 17))
	_check("menu8_cleanup", _labels(map, s, 8).has("整理存档"), _labels(map, s, 8))
	_check("menu60_no_debt", _labels(map, s, 60).is_empty(), _labels(map, s, 60))   # 没欠债：讨债人不成立，赌桌照原样
	s.set_variable(206, -3000)
	_check("menu60_debt", _labels(map, s, 60) == ["赌局", "讨债人的限制与福利", "离开"], _labels(map, s, 60))
	s.set_variable(206, 0)
	# 招募、商店分组、传送：宿主不接；源本来就下架
	_check("no_menu_recruit_shop_door", XTianqiHall.menu(map, s, 15).is_empty() and XTianqiHall.menu(map, s, 54).is_empty() and XTianqiHall.menu(map, s, 27).is_empty())
	_check("o410_still_hides_65_66", XTianqiTrim.hides(4, 65) and XTianqiTrim.hides(4, 66) and XTianqiHall.source_page(map, 65).is_empty() and XTianqiHall.source_page(map, 66).is_empty())
	_check("shop54_still_xiandao", XTianqiTrim.shop_goods(s, 4, 54, [[2, XTianqiTrim.DIVINE_PAGE_FIRST, 0, 0]]).any(func(g): return int(g[1]) == int(XTianqiTrim.XIANDAO[1])))
	_check("intercepts_hosts", XTianqiHall.intercepts(map, s, 4, 6) and XTianqiHall.intercepts(map, s, 4, 1) and not XTianqiHall.intercepts(map, s, 4, 62) and not XTianqiHall.intercepts(map, s, 5, 6))
	# 付费治疗：扣 1000 金、回满
	var a := s.actor(s.party[0])
	a.hp = 1.0
	s.gold = 5000
	XMessageBox.auto_answers = [2, 0]
	await map.run_event(_event(map, 6))
	_check("paid_heal_cost", s.gold == 4000, s.gold)
	_check("paid_heal_full", is_equal_approx(a.hp, a.mhp), [a.hp, a.mhp])
	# 限时免费治疗：回满并记下时间；马上再来不回
	a.hp = 1.0
	XMessageBox.auto_answers = [1, 0]
	await map.run_event(_event(map, 5 + 1))
	_check("free_heal_full", is_equal_approx(a.hp, a.mhp) and s.variable(163) > -600, [a.hp, s.variable(163)])
	a.hp = 1.0
	XMessageBox.auto_answers = [1, 0]
	await map.run_event(_event(map, 6))
	_check("free_heal_cooldown", is_equal_approx(a.hp, 1.0), a.hp)
	_check("free_heal_gold_untouched", s.gold == 4000, s.gold)
	# 宿主自己那一项：阿卡拉原页照跑（离开）
	XMessageBox.auto_answers = [0, 3]
	XMessageBox.transcript.clear()
	await map.run_event(_event(map, 6))
	_check("host_own_page", XMessageBox.transcript.has("选择：离开") and XMessageBox.transcript.has("选择：买东西／治疗"), XMessageBox.transcript)
	# 开局补给：领一次，记在源事件 9 的独立开关上，选单不再列
	var pts := s.variable(206)
	var shard := s.item_count(2530)
	XMessageBox.auto_answers = [l1.find("开局补给")]
	XMessageBox.transcript.clear()
	await map.run_event(_event(map, 1))
	_check("gift9_given", s.variable(206) == pts + 4500 and s.item_count(2530) == shard + 20, [s.variable(206) - pts, s.item_count(2530) - shard])
	_check("gift9_self_switch", s.self_switch(4, 9, "A") and not s.self_switch(4, 1, "A"))
	_check("gift9_given_line", XMessageBox.transcript.any(func(t): return str(t).contains("收好了")), XMessageBox.transcript)
	_check("gift9_not_listed_again", not _labels(map, s, 1).has("开局补给"), _labels(map, s, 1))
	# 名单：改版向导说
	XMessageBox.auto_answers = [_labels(map, s, 71).find("强者名单")]
	XMessageBox.transcript.clear()
	await map.run_event(_event(map, 71))
	var said := XMessageBox.transcript.duplicate()
	_check("roster_by_guide", said.any(func(t): return str(t).contains("强者名单（")) and not said.any(func(t): return str(t).contains("破阵")), said)
	# 移动速度（并进改版向导）：选「快」
	XMessageBox.auto_answers = [_labels(map, s, 71).find("调节移动速度"), 1]
	XMessageBox.transcript.clear()
	await map.run_event(_event(map, 71))
	_check("speed_menu_ran", XMessageBox.transcript.has("选择：快"), XMessageBox.transcript)
	# 回退开关：宿主不弹选单
	XTianqiHall.ENABLED = false
	_check("switch_off_no_menu", XTianqiHall.menu(map, s, 6).is_empty() and not XTianqiHall.intercepts(map, s, 4, 6))
	XTianqiHall.ENABLED = true
	# 西游档：不接
	var plain := _plain_state()
	_check("plain_no_menu", XTianqiHall.menu(map, plain, 6).is_empty() and not XTianqiHall.intercepts(map, plain, 4, 1))
	XState.current = s
	XMessageBox.auto_answers = []
	map.queue_free()
	for _f in 60:   # 淡入淡出、提示条的计时器跑完再退，免得退出时报资源还在用（偶发）
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
