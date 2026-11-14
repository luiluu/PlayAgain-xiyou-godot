extends Node
## 天启篇教派连带内容·包丙（XTianqiSect.BING）：
## 一、大厅放贷人 Map004 EV038/EV039 换成老钱/小钱（各借各的、还钱、18 层后停借、教派页不出）；
## 二、18 层讨债战（Map046 EV001）：台词改写、敌群 747/766 换成老钱/小钱各带两打手、实跑战斗拿账本；
## 三、物品 1958/1961 改名改描述；贪财商人 Map192 EV006 台词改写＋「收账本」换止戈/天怒各一次；
## 四、水栽培 Map187 EV105/EV106 在天启篇不出；
## 五、开关 BING 关掉回原样，原版西游档不受影响。

var results: Array = []


class MockHost:
	extends RefCounted
	var texts: Array = []
	var choices_queue: Array = []
	var shops: Array = []

	func show_text(face: String, idx: int, lines: Array) -> void:
		texts.append({"face": face, "idx": idx, "lines": lines})

	func show_text_with_choices(face: String, idx: int, lines: Array, options: Array, _cancel_type: int) -> int:
		texts.append({"face": face, "idx": idx, "lines": lines, "options": options})
		if choices_queue.is_empty():
			return options.size() - 1
		return int(choices_queue.pop_front())

	func open_shop(goods: Array, purchase_only: bool) -> void:
		shops.append({"goods": goods, "purchase_only": purchase_only})


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
	XMessageBox.auto = true
	await _loan_hall()
	await _debt_battle()
	await _merchant_and_items()
	_hydroponics()
	_switch_off_and_original()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _tianqi_state(diff := "jiusi") -> XState:
	var s := XState.new_game_blank()
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": diff, "lineup": []}
	XState.current = s
	return s


func _plain_state() -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	return s


func _page_of(map_id: int, event_id: int) -> int:
	for ev in XDB.map(map_id).get("events", []):
		if ev != null and int(ev.id) == event_id:
			var e := MVEvent.new()
			e.map_id = map_id
			e.event_id = event_id
			e.data = ev
			var p := e._find_page()
			e.free()
			return p
	return -2


func _clean_text(t: String) -> bool:
	return not t.contains("教派") and not t.contains("天道使者") and not t.contains("求道者")


func _loan_hall() -> void:
	var s := _tianqi_state()
	_check("hall_intercepts_38_39", XTianqiSect.intercepts(s, 4, 38) and XTianqiSect.intercepts(s, 4, 39))
	# 未进塔（var 14 == 0）时置 A 开关
	var h := MockHost.new()
	await XTianqiSect.run_event(h, s, 4, 38)
	_check("loan_gate_sets_A", s.self_switch(4, 38, "A") and _clean_text(JSON.stringify(h.texts)))

	# 重置后正常借钱（老钱 38 + 小钱 39）
	s = _tianqi_state()
	s.set_variable(14, 1)
	s.set_variable(20, 10)
	h = MockHost.new()
	h.choices_queue = [0, 0]  # 两家都选「借钱」
	await XTianqiSect.run_event(h, s, 4, 38)
	await XTianqiSect.run_event(h, s, 4, 39)
	_check("loan_both_borrowed", s.variable(206) == 3600 and s.variable(850) == 1 and s.variable(849) == 1 and s.self_switch(4, 38, "B") and s.self_switch(4, 39, "B"), [s.variable(206), s.variable(850), s.variable(849)])
	_check("loan_text_clean_and_face", _clean_text(JSON.stringify(h.texts)) and h.texts[0].face == "People1", h.texts)

	# 积分不足还老钱
	s.set_variable(206, 1000)
	h = MockHost.new()
	h.choices_queue = [0]
	await XTianqiSect.run_event(h, s, 4, 38)
	_check("repay_short_rejected", s.variable(850) == 1 and s.variable(206) == 1000 and not s.self_switch(4, 38, "C"))

	# 积分充足还老钱，小钱先不还（留作讨债测试）
	s.set_variable(206, 3000)
	h = MockHost.new()
	h.choices_queue = [0, 1]
	await XTianqiSect.run_event(h, s, 4, 38)
	await XTianqiSect.run_event(h, s, 4, 39)
	_check("repay_lao_ok_keep_xiao", s.variable(206) == 600 and s.variable(850) == 0 and s.self_switch(4, 38, "C") and s.variable(849) == 1)

	# 教派禁借第 5 页在天启篇选不中
	s.set_switch(2301, true)
	s.set_switch(2302, true)
	_check("hall_sect_page5_blocked", _page_of(4, 38) != 4 and _page_of(4, 39) != 4)


func _debt_battle() -> void:
	var s := _tianqi_state()
	s.map_id = 46
	# 模拟 Map046 EV001 台词改写
	var msg_lao := {"face": "Evil", "index": 3, "lines": ["\\n<天道使者>嘿嘿，你居然打过了深渊骑士，不过，你没还我钱，我是不会放过你的，言而无信之人，接招吧！"]}
	var msg_xiao := {"face": "Actor112", "index": 1, "lines": ["\\n<求道者>我说了我会动真格的，接招吧！"]}
	msg_lao = XTianqiSect.rewrite_message(s, 46, 1, msg_lao)
	msg_xiao = XTianqiSect.rewrite_message(s, 46, 1, msg_xiao)
	_check("battle_text_rewritten", _clean_text(JSON.stringify([msg_lao, msg_xiao])) and msg_lao.lines[0].contains("老钱") and msg_xiao.lines[0].contains("小钱"), [msg_lao, msg_xiao])

	# 实跑老钱讨债战（敌群 747）：1 主将 + 2 打手，打赢掉 1958 老钱的账本
	var t747 := XDB.rec("Troops", 747)
	_check("troop_747_three_members", str(t747.name) == "老钱" and (t747.members as Array).size() == 3, t747)
	var lg := XBattleLogic.new()
	lg.setup(747, s)
	var names747 := lg.enemies.map(func(e): return str(e.data().name))
	_check("battle_747_names_and_sv", names747 == ["老钱", "老钱的打手", "老钱的打手"] and str(lg.enemies[0].data().note).contains("Enemy_Mage"), names747)
	var drops747 := []
	for _i in 400:
		lg._treasure.clear()
		var d: Array = lg.drops_of(lg.enemies[0])
		if not d.is_empty():
			drops747 = d
			break
	lg.gain_drops(drops747)
	lg.end_battle(1)
	_check("battle_747_dropped_lao_ledger", s.item_count(1958) == 1, [s.item_count(1958), lg.drop_chances(lg.enemies[0])])

	# 实跑小钱讨债战（敌群 766）：1 主将 + 2 打手，打赢掉 1961 小钱的账本
	var t766 := XDB.rec("Troops", 766)
	_check("troop_766_three_members", str(t766.name) == "小钱" and (t766.members as Array).size() == 3, t766)
	var lg2 := XBattleLogic.new()
	lg2.setup(766, s)
	var names766 := lg2.enemies.map(func(e): return str(e.data().name))
	_check("battle_766_names_and_sv", names766 == ["小钱", "小钱的打手", "小钱的打手"] and str(lg2.enemies[0].data().note).contains("Actor12_2"), names766)
	var drops766 := []
	for _i in 400:
		lg2._treasure.clear()
		var d: Array = lg2.drops_of(lg2.enemies[0])
		if not d.is_empty():
			drops766 = d
			break
	lg2.gain_drops(drops766)
	lg2.end_battle(1)
	_check("battle_766_dropped_xiao_ledger", s.item_count(1961) == 1, [s.item_count(1961), lg2.drop_chances(lg2.enemies[0])])


func _merchant_and_items() -> void:
	var s := _tianqi_state()
	var it_lao := XDB.rec("Items", 1958)
	var it_xiao := XDB.rec("Items", 1961)
	_check("items_renamed", str(it_lao.name) == "老钱的账本" and str(it_xiao.name) == "小钱的账本" and _clean_text(str(it_lao.description) + str(it_xiao.description)), [it_lao, it_xiao])

	# 贪财商人 Map192 EV006
	s.set_variable(14, 1)
	s.gain_item(1958, 1)
	s.gain_item(1961, 1)
	_check("merchant_intercepted", XTianqiSect.intercepts(s, 192, 6))

	# 1. 打开商店
	var h := MockHost.new()
	h.choices_queue = [0]
	await XTianqiSect.run_event(h, s, 192, 6)
	_check("merchant_shop_opened", h.shops.size() == 1 and (h.shops[0].goods as Array).size() == XTianqiSect.BING_GREEDY_SHOP_ITEMS.size() and _clean_text(JSON.stringify(h.texts)), h.shops)

	# 2. 收账本换止戈（1959）和天怒（1962）各一次
	h = MockHost.new()
	h.choices_queue = [1, 0]  # 收账本 -> 选老钱的账本
	await XTianqiSect.run_event(h, s, 192, 6)
	h = MockHost.new()
	h.choices_queue = [1, 0]  # 收账本 -> 此时只剩小钱的账本
	await XTianqiSect.run_event(h, s, 192, 6)
	_check("merchant_exchanged_both", s.item_count(1958) == 0 and s.item_count(1961) == 0 and s.item_count(1959) == 1 and s.item_count(1962) == 1)

	# 3. 不可重复换（哪怕再塞一本账本也不给换）
	s.gain_item(1958, 1)
	_check("merchant_once_only", not XTianqiSect.bing_can_exchange(s, "lao") and not XTianqiSect.bing_exchange_ledger(s, "lao").ok)


func _hydroponics() -> void:
	_tianqi_state()
	_check("hydroponics_hidden", XTianqiSect.hides(187, 105) and XTianqiSect.hides(187, 106) and _page_of(187, 105) == -1 and _page_of(187, 106) == -1)


func _switch_off_and_original() -> void:
	var tq := _tianqi_state()
	XTianqiSect.BING = false
	_check("switch_off_restores",
		not XTianqiSect.hides(187, 105)
		and not XTianqiSect.intercepts(tq, 4, 38)
		and not XTianqiSect.intercepts(tq, 192, 6)
		and str(XDB.rec("Items", 1958).name) == "天道信物"
		and str(XDB.rec("Items", 1961).name) == "天道研究日志[典藏版]"
		and (XDB.rec("Troops", 747).members as Array).size() == 1
		and str(XDB.rec("Enemies", 871).name) == "天道使者"
	)
	XTianqiSect.BING = true

	var orig := _plain_state()
	_check("original_untouched",
		not XTianqiSect.hides(187, 105)
		and _page_of(187, 105) >= 0
		and not XTianqiSect.intercepts(orig, 4, 38)
		and not XTianqiSect.intercepts(orig, 192, 6)
		and str(XDB.rec("Items", 1958).name) == "天道信物"
		and (XDB.rec("Troops", 747).members as Array).size() == 1
		and str(XDB.rec("Enemies", 871).name) == "天道使者"
	)
