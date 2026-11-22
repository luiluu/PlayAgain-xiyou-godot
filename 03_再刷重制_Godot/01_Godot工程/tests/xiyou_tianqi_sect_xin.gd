extends Node
## 天启篇教派连带内容·包辛（XTianqiSect.XIN）：真材料首杀与升华。
## 一、数据对得上：三个升华公共事件 1388～1390 的旧被动→新被动和本包表一致；19／25／27 层守层者事件第 1 页是「独立开关 A」普通商店页；
##    魔塔外围送真材料页、守层者随机／轮回页在天启篇选不中（包甲拦）。
## 二、31／32／33 层守层者（敌群 467／468／469）首杀各掉一件，再打不掉；输了不掉；after_map_battle 有获得提示。材料改名（去掉「真*」）。
## 三、19／25／27 层：没打赢（没开 A）或没材料不接管；有材料没人学过旧被动→只提示、不收材料；学过→收材料、所有学过的人忘旧学新、
##    记账、只一次；接管后照原页走（这里 host 没有事件节点，只看台词）。
## 四、存档：存→读后首杀、升华的账还在。
## 五、开关 XIN 关掉回原样；西游档不受影响。
## 六、实机：真进 32 层（Map156）打伏羲（战斗一开就击倒），首杀拿到永恒玄冰；真进 19 层（Map047）跟炎龙队长说话，
##    先升华、再照原页开商店（XShop.auto_log 记到原页的货单）。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
const WaitBudget := preload("res://tests/wait_budget.gd")
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const TIMEOUT_MS := 90000
var results: Array = []
var kit: Kit


class MockHost:
	extends RefCounted
	var texts: Array = []
	var events: Array = []

	func show_text(face: String, idx: int, lines: Array) -> void:
		texts.append({"face": face, "idx": idx, "lines": lines})


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok, "detail": detail})
	return ok


func _run() -> void:
	XMessageBox.auto = true
	kit = Kit.new("xiyou_tianqi_sect_xin")
	_data_matches()
	await _first_kills()
	await _sublimate()
	_save_roundtrip()
	await _switch_off_and_original()
	XGuide.MILESTONE_ENABLED = false
	XBattleScene.force_auto = true
	XShop.auto_close = true
	await _live()
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _ev(map_id: int, event_id: int) -> Dictionary:
	for ev in XDB.map(map_id).get("events", []):
		if ev != null and int(ev.id) == event_id:
			return ev
	return {}


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


## 公共事件里 hasSkill(N)／learnSkill(M) 的 N、M
func _ce_skills(id: int) -> Array:
	var src := ""
	for c in XDB.rec("CommonEvents", id).get("list", []):
		if int(c.code) == 355 or int(c.code) == 655:
			src += str(c.parameters[0]) + "\n"
	var re := RegEx.create_from_string("hasSkill\\((\\d+)\\)")
	var re2 := RegEx.create_from_string("learnSkill\\((\\d+)\\)")
	var a := re.search(src)
	var b := re2.search(src)
	return [int(a.get_string(1)) if a else 0, int(b.get_string(1)) if b else 0]


func _data_matches() -> void:
	var s := Kit.new_game()
	var bad := []
	for k in XTianqiSect.XIN_GUARDIANS:
		var g: Dictionary = XTianqiSect.XIN_GUARDIANS[k]
		var pair := _ce_skills(int(g.ce))
		if pair != [int(g.from), int(g.to)]:
			bad.append([k, pair])
		var mid := int(str(k).split(":")[0])
		var eid := int(str(k).split(":")[1])
		var pages: Array = _ev(mid, eid).get("pages", [])
		var c: Dictionary = pages[1].conditions if pages.size() > 1 else {}
		if not bool(c.get("selfSwitchValid", false)) or bool(c.get("switch1Valid", false)) or str(c.get("selfSwitchCh", "")) != "A":
			bad.append([k, "page1", c])
		# 天启篇：打赢后（A 开）选中第 1 页（普通商店页），随机／轮回页（第 5、7 页）选不中
		s.set_switch(2303, true)
		s.set_switch(2307, true)
		s.set_self_switch(mid, eid, "A", true)
		var p := _page_of(mid, eid)
		if p != 1:
			bad.append([k, "page_pick", p])
		s.set_self_switch(mid, eid, "A", false)
		s.set_switch(2303, false)
		s.set_switch(2307, false)
	_check("data_ce_and_pages", bad.is_empty(), bad)
	var troops_ok := true
	for t in XTianqiSect.XIN_KILLS:
		var name := str(XDB.rec("Troops", int(t)).get("name", ""))
		if not (name.contains("女娲") or name.contains("伏羲") or name.contains("鸿蒙老祖")):
			troops_ok = false
	_check("data_kill_troops", troops_ok)
	# 魔塔外围原版送真材料（Map195 EV008 第 3、5 页，sw2303／2307 且变量 20≥31）在天启篇选不中
	s.set_switch(2303, true)
	s.set_variable(20, 31)
	var outskirts := _page_of(195, 8)
	s.set_switch(2303, false)
	_check("outskirts_gift_blocked", outskirts != 2 and outskirts != 4, outskirts)


func _first_kills() -> void:
	var s := Kit.new_game()
	_check("names_tianqi",
		str(XDB.rec("Items", 1975).name) == "原初火种·源"
		and str(XDB.rec("Items", 1976).name) == "永恒玄冰"
		and str(XDB.rec("Items", 1977).name) == "极渊重岩"
		and str(XDB.rec("Items", 1953).name) == "原初火种"
		and not str(XDB.rec("Items", 1975).description).contains("真*"),
		[XDB.rec("Items", 1975).name, XDB.rec("Items", 1976).name, XDB.rec("Items", 1977).name])
	var h := MockHost.new()
	await XTianqiSect.after_map_battle(h, s, 467, 1)  # 输了
	_check("loss_no_drop", s.item_count(1975) == 0 and not XTianqiSect.xin_killed(s, 31))
	await XTianqiSect.after_map_battle(h, s, 467, 0)
	await XTianqiSect.after_map_battle(h, s, 468, 0)
	await XTianqiSect.after_map_battle(h, s, 469, 0)
	_check("first_kill_three", s.item_count(1975) == 1 and s.item_count(1976) == 1 and s.item_count(1977) == 1
		and XTianqiSect.xin_killed(s, 31) and XTianqiSect.xin_killed(s, 32) and XTianqiSect.xin_killed(s, 33),
		[s.item_count(1975), s.item_count(1976), s.item_count(1977)])
	_check("first_kill_text", h.texts.size() == 3 and str(h.texts[0].lines[0]).contains("原初火种·源") and str(h.texts[0].lines[0]).contains("19"), h.texts)
	await XTianqiSect.after_map_battle(h, s, 467, 0)
	await XTianqiSect.after_map_battle(h, s, 468, 0)
	await XTianqiSect.after_map_battle(h, s, 469, 0)
	_check("second_kill_none", s.item_count(1975) == 1 and s.item_count(1976) == 1 and s.item_count(1977) == 1 and h.texts.size() == 3)
	await XTianqiSect.after_map_battle(h, s, 461, 0)  # 别的守层者（25 层）不掉
	_check("other_troop_none", s.item_count(1976) == 1 and h.texts.size() == 3)


func _sublimate() -> void:
	var s := Kit.new_game()
	var h := MockHost.new()
	# 没打赢（A 没开）：不接管
	s.gain_item(1975, 1)
	_check("no_A_no_intercept", not XTianqiSect.intercepts(s, 47, 13))
	s.set_self_switch(47, 13, "A", true)
	s.gain_item(1975, -1)
	_check("no_item_no_intercept", not XTianqiSect.intercepts(s, 47, 13))
	s.gain_item(1975, 1)
	_check("item_intercepts", XTianqiSect.intercepts(s, 47, 13))
	# 有材料、没人学过永恒之火：只提示，不收
	for id in s.party:
		s.actor(int(id)).forget_skill(6133)
	var nobody := XTianqiSect.xin_learners(s, 6133).is_empty()
	await XTianqiSect.run_event(h, s, 47, 13)
	_check("none_hint_keep_item", nobody and s.item_count(1975) == 1 and h.texts.size() == 1
		and str(h.texts[0].lines[0]).contains("炎龙队长") and str(h.texts[0].lines[0]).contains("没人会") and str(h.texts[0].face) == "DF_Actor11"
		and not XTianqiSect.xin_sublimed(s, 19), [nobody, h.texts])
	# 两个人学了：都升华
	var a1 := int(s.party[0])
	var a2 := int(s.party[1])
	s.actor(a1).learn_skill(6133)
	s.actor(a2).learn_skill(6133)
	var learned := s.actor(a1).skill_ids.has(6133) and s.actor(a2).skill_ids.has(6133)
	h = MockHost.new()
	await XTianqiSect.run_event(h, s, 47, 13)
	var ok := true
	for id in [a1, a2]:
		var a := s.actor(id)
		ok = ok and not a.skill_ids.has(6133) and a.skill_ids.has(6236)
	_check("sublimate_ok", learned and ok and s.item_count(1975) == 0 and XTianqiSect.xin_sublimed(s, 19)
		and h.texts.size() == 1 and str(h.texts[0].lines[0]).contains("永恒之火"), [learned, ok, s.item_count(1975), h.texts])
	# 只一次：再拿到材料也不接管
	s.gain_item(1975, 1)
	_check("sublimate_once", not XTianqiSect.intercepts(s, 47, 13) and not bool(XTianqiSect.xin_sublimate(s, 47, 13).ok))
	# 25、27 层同样走得通
	s.set_self_switch(147, 1, "A", true)
	s.set_self_switch(182, 1, "A", true)
	s.gain_item(1976, 1)
	s.gain_item(1977, 1)
	s.actor(a1).learn_skill(6138)
	s.actor(a1).learn_skill(6238)
	var r25 := XTianqiSect.xin_sublimate(s, 147, 1)
	var r27 := XTianqiSect.xin_sublimate(s, 182, 1)
	_check("sublimate_25_27", bool(r25.ok) and bool(r27.ok) and s.actor(a1).skill_ids.has(6237) and s.actor(a1).skill_ids.has(6239)
		and not s.actor(a1).skill_ids.has(6138) and not s.actor(a1).skill_ids.has(6238) and s.item_count(1976) == 0 and s.item_count(1977) == 0,
		[r25, r27])
	# 别的守层者事件不接管
	_check("others_untouched", not XTianqiSect.intercepts(s, 47, 12) and not XTianqiSect.intercepts(s, 147, 4))


func _save_roundtrip() -> void:
	var s := Kit.new_game()
	XTianqiSect.xin_grant_kill(s, 467)
	s.set_self_switch(182, 1, "A", true)
	XTianqiSect.xin_grant_kill(s, 469)
	s.actor(int(s.party[0])).learn_skill(6238)
	XTianqiSect.xin_sublimate(s, 182, 1)
	var back := kit.roundtrip()
	_check("save_roundtrip", back != null and XTianqiSect.xin_killed(back, 31) and XTianqiSect.xin_killed(back, 33) and not XTianqiSect.xin_killed(back, 32)
		and XTianqiSect.xin_sublimed(back, 27) and XTianqiSect.xin_grant_kill(back, 467) == 0 and back.item_count(1975) == 1,
		back.flags.get("tianqi", {}).get("sect_xin") if back != null else null)


func _switch_off_and_original() -> void:
	var s := Kit.new_game()
	s.set_self_switch(47, 13, "A", true)
	s.gain_item(1975, 1)
	XTianqiSect.XIN = false
	var h := MockHost.new()
	await XTianqiSect.after_map_battle(h, s, 468, 0)
	_check("switch_off",
		not XTianqiSect.intercepts(s, 47, 13)
		and s.item_count(1976) == 0 and h.texts.is_empty()
		and str(XDB.rec("Items", 1975).name) == "真*原初火种"
		and str(XDB.rec("Items", 1976).name) == "真*永恒玄冰",
		[XDB.rec("Items", 1975).name])
	XTianqiSect.XIN = true

	var p := XState.new_game_blank()
	XState.current = p
	XTextFix.sync_mode()
	p.set_self_switch(47, 13, "A", true)
	p.gain_item(1975, 1)
	h = MockHost.new()
	await XTianqiSect.after_map_battle(h, p, 467, 0)
	_check("original_untouched",
		not XTianqiSect.intercepts(p, 47, 13)
		and p.item_count(1975) == 1 and h.texts.is_empty()
		and str(XDB.rec("Items", 1975).name) == "真*原初火种"
		and str(XDB.rec("Items", 1977).name) == "真*极渊重岩"
		and not p.flags.get("tianqi", {}).has("sect_xin"),
		[XDB.rec("Items", 1975).name, p.flags.get("tianqi", {})])


# ---- 实机 ----

func _wait_map(map_id: int) -> XMapScene:
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while t0.waiting():
		var sc = get_tree().current_scene
		if sc is XMapScene and sc.map_id == map_id and sc.player != null and not sc.busy:
			return sc
		await get_tree().process_frame
	return null


func _goto(s: XState, map_id: int, x: int, y: int) -> XMapScene:
	s.map_id = map_id
	s.x = x
	s.y = y
	s.direction = 8
	XState.current = s
	XTextFix.sync_mode()
	XTextFix.clear_cache()
	get_tree().change_scene_to_file(MAP_SCENE)
	return await _wait_map(map_id)


func _battle_of(map: XMapScene) -> XBattleScene:
	for n in map.ui.get_children():
		if n is XBattleScene:
			return n
	return null


func _run_live_event(map: XMapScene, id: int, answers: Array, kill := false) -> bool:
	var e: MVEvent = null
	for x in map.events:
		if x.event_id == id:
			e = x
	if e == null or e.page.is_empty():
		return false
	XMessageBox.auto_answers = answers.duplicate()
	var st := {"done": false}
	(func():
		await map.run_event(e)
		st.done = true).call()
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while not st.done and t0.waiting():
		if kill:
			var b := _battle_of(map)
			if b != null and not b.logic.enemies.is_empty():
				for en in b.logic.enemies:
					if en.is_alive():
						en.hp = 0.0
						en.add_state(1)
		await get_tree().process_frame
	return st.done


func _live() -> void:
	var s := Kit.new_game("jiusi")
	s.set_variable(20, 32)
	var map := await _goto(s, 156, 8, 16)
	if not _check("live_32_loaded", map != null):
		return
	var done := await _run_live_event(map, 1, [0], true)
	_check("live_32_first_kill", done and s.item_count(1976) == 1 and XTianqiSect.xin_killed(s, 32) and s.self_switch(156, 1, "A"),
		[done, s.item_count(1976), s.variable(20)])
	_check("live_32_text", XMessageBox.transcript.any(func(t): return str(t).contains("永恒玄冰") and str(t).contains("25")), XMessageBox.transcript.slice(-6))

	s = Kit.new_game("jiusi")
	s.set_variable(20, 20)
	s.set_self_switch(47, 13, "A", true)
	s.gain_item(1975, 1)
	var a1 := int(s.party[0])
	s.actor(a1).learn_skill(6133)
	map = await _goto(s, 47, 14, 3)
	if not _check("live_19_loaded", map != null):
		return
	XMessageBox.transcript.clear()
	XShop.auto_log.clear()
	done = await _run_live_event(map, 13, [0])
	_check("live_19_sublimate", done and s.item_count(1975) == 0 and s.actor(a1).skill_ids.has(6236) and not s.actor(a1).skill_ids.has(6133),
		[done, s.item_count(1975)])
	_check("live_19_line_then_shop",
		XMessageBox.transcript.size() >= 2 and str(XMessageBox.transcript[0]).contains("龙炎") and str(XMessageBox.transcript[0]).contains("永恒之火")
		and str(XMessageBox.transcript[1]).contains("有什么需要的吗")  # 升华台词在前，原页开场白在后（名字框不进 transcript）
		and XShop.auto_log.size() == 1,
		[XMessageBox.transcript.duplicate(), XShop.auto_log.size()])
	# 升华过之后再说话：不接管，照原页
	XShop.auto_log.clear()
	done = await _run_live_event(map, 13, [0])
	_check("live_19_after_plain", done and XShop.auto_log.size() == 1)
