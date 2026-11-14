extends Node
## 天启篇教派连带内容·包甲（XTianqiSect）：
## 一、大厅两位使者（Map004 EV016、EV035）不出，原来白送的两件改开局给；
## 二、教派、随机、轮回开关当条件的页全不出（扫全部地图），开局不开这些开关；
## 三、天道研究日志不在货单和掉落里，夏娜心魔（敌人 2026）掉人道意志碎片 × 10（实跑一场）；
## 四、回退开关 JIA 关掉回原样；原版档不受影响。

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
	XMessageBox.auto = true
	_hall()
	_opening()
	_sect_pages()
	_shop()
	_drops()
	_battle()
	_original()
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


## 真地图数据里的事件，按当前状态选页
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


func _hall() -> void:
	_tianqi_state()
	_check("hides_two_envoys", XTianqiSect.hides(4, 16) and XTianqiSect.hides(4, 35))
	XTianqiSect.YI = false  # 讲抽奖被动上限的使者 EV003 归包乙（xiyou_tianqi_sect_b 测）；这里只看包甲自己隐藏的
	_check("hides_only_those", not XTianqiSect.hides(4, 3) and not XTianqiSect.hides(4, 38) and not XTianqiSect.hides(4, 39) and not XTianqiSect.hides(5, 16))
	_check("real_ev016_no_page", _page_of(4, 16) == -1, _page_of(4, 16))
	_check("real_ev035_no_page", _page_of(4, 35) == -1, _page_of(4, 35))
	_check("real_ev003_kept", _page_of(4, 3) >= 0, _page_of(4, 3))
	XTianqiSect.YI = true
	_plain_state()
	_check("original_ev016_shown", _page_of(4, 16) >= 0 and _page_of(4, 35) >= 0)
	_tianqi_state()
	XTianqiSect.JIA = false
	_check("switch_off_ev016_shown", _page_of(4, 16) >= 0 and _page_of(4, 35) >= 0)
	XTianqiSect.JIA = true


func _opening() -> void:
	var cmds: Array = XTianqi.opening_commands(1, "jiusi", [1, 2, 3, 4, 5])
	var on_sw := []
	for c in cmds:
		if int(c.code) == 121 and int(c.parameters[2]) == 0:
			for id in range(int(c.parameters[0]), int(c.parameters[1]) + 1):
				if XTianqiSect.JIA_SWITCHES.has(id):
					on_sw.append(id)
	_check("opening_no_sect_switch", on_sw.is_empty(), on_sw)
	var items := cmds.filter(func(c): return int(c.code) == 126).map(func(c): return int(c.parameters[0]))
	_check("opening_gives_controller_and_lamp", items.has(1340) and items.has(386), items)
	var text := JSON.stringify(XTianqiSect.opening_commands())
	_check("opening_text_clean", not text.contains("教派") and not text.contains("天道使者") and not text.contains("求道者"), text)
	XTianqiSect.JIA = false
	var off: Array = XTianqi.opening_commands(1, "jiusi", [1, 2, 3, 4, 5]).filter(func(c): return int(c.code) == 126).map(func(c): return int(c.parameters[0]))
	XTianqiSect.JIA = true
	_check("opening_switch_off", not off.has(1340) and not off.has(386), off)


## 扫全部地图：条件里带教派／随机／轮回开关的页，天启篇里一页都选不中（连开关打开也不行）；原版档照旧选得中
func _sect_pages() -> void:
	var files := DirAccess.get_files_at(XDB.BASE + "maps")
	var pages := 0
	var chosen := []
	var seen_orig := false
	var tq := _tianqi_state()
	for sw in XTianqiSect.JIA_SWITCHES:
		tq.set_switch(int(sw), true)  # 即便被打开，天启篇里这些页也不出
	var plain := XState.new_game_blank()
	for sw in XTianqiSect.JIA_SWITCHES:
		plain.set_switch(int(sw), true)
	for f in files:
		if not f.begins_with("Map") or not f.ends_with(".json"):
			continue
		var mid := int(f.substr(3, 3))
		for ev in XDB.map(mid).get("events", []):
			if ev == null:
				continue
			var gated := []
			for i in ev.pages.size():
				var c: Dictionary = ev.pages[i].conditions
				if (bool(c.switch1Valid) and XTianqiSect.JIA_SWITCHES.has(int(c.switch1Id))) or (bool(c.switch2Valid) and XTianqiSect.JIA_SWITCHES.has(int(c.switch2Id))):
					gated.append(i)
			if gated.is_empty():
				continue
			pages += gated.size()
			var e := MVEvent.new()
			e.map_id = mid
			e.event_id = int(ev.id)
			e.data = ev
			XState.current = tq
			var p := e._find_page()
			if gated.has(p):
				chosen.append([mid, int(ev.id), p])
			XState.current = plain
			if gated.has(e._find_page()):
				seen_orig = true
			e.free()
	_check("sect_pages_scanned", pages >= 100, pages)
	_check("sect_pages_never_chosen_in_tianqi", chosen.is_empty(), chosen)
	_check("sect_pages_chosen_in_original", seen_orig)
	# 点名：六大试炼、终末之间入口、魔塔外围送真材料
	_tianqi_state()
	for t in [[5, 2, [4, 5]], [18, 3, [1, 2]], [44, 2, [8, 9]], [67, 2, [4, 5]], [85, 1, [8, 9]], [171, 1, [2, 3]], [146, 3, [0, 1]], [195, 8, [2, 4]]]:
		var named := true
		for ev in XDB.map(int(t[0])).get("events", []):
			if ev != null and int(ev.id) == int(t[1]):
				for i in t[2]:
					var c: Dictionary = ev.pages[i].conditions
					named = named and ((bool(c.switch1Valid) and XTianqiSect.JIA_SWITCHES.has(int(c.switch1Id))) or (bool(c.switch2Valid) and XTianqiSect.JIA_SWITCHES.has(int(c.switch2Id))))
		_check("named_pages_sect_gated_%d_%d" % [t[0], t[1]], named, t)
	var cond := {"switch1Valid": true, "switch1Id": 2302, "switch2Valid": false, "switch2Id": 1}
	XTianqiSect.JIA = false
	_check("pages_switch_off", not XTianqiSect.page_blocked(_tianqi_state(), cond))
	XTianqiSect.JIA = true
	_check("pages_block_tianqi_only", XTianqiSect.page_blocked(_tianqi_state(), cond) and not XTianqiSect.page_blocked(_plain_state(), cond))
	_check("pages_other_switch_untouched", not XTianqiSect.page_blocked(_tianqi_state(), {"switch1Valid": true, "switch1Id": 16, "switch2Valid": false, "switch2Id": 1}))


func _shop() -> void:
	var s := _tianqi_state()
	var goods := [[0, 1959, 0, 0, false], [0, 1960, 0, 0], [0, 2530, 0, 0], [2, 1960, 0, 0]]
	var left := XTianqiSect.shop_goods(s, 204, 3, goods).map(func(g): return [int(g[0]), int(g[1])])
	_check("shop_no_journal", left == [[0, 1959], [0, 2530], [2, 1960]], left)  # 只去物品 1960，武器 1960 不动
	_check("shop_original", XTianqiSect.shop_goods(_plain_state(), 204, 3, goods).size() == 4)
	XState.current = s
	XTianqiSect.JIA = false
	_check("shop_switch_off", XTianqiSect.shop_goods(s, 204, 3, goods).size() == 4)
	XTianqiSect.JIA = true
	# 全部货单（地图事件里的 302）都没有研究日志
	var any := false
	for f in DirAccess.get_files_at(XDB.BASE + "maps"):
		if not f.begins_with("Map") or not f.ends_with(".json"):
			continue
		for ev in XDB.map(int(f.substr(3, 3))).get("events", []):
			if ev == null:
				continue
			for p in ev.pages:
				for c in p.list:
					if int(c.code) in [302, 605] and int(c.parameters[0]) == 0 and int(c.parameters[1]) == 1960:
						any = true
	_check("no_map_shop_sells_journal", not any)


func _drops() -> void:
	var s := _tianqi_state()
	var rows := [{"kind": 1, "id": 1960, "chance": 0.5, "extra": false}, {"kind": 2, "id": 7, "chance": 0.1, "extra": false}]
	var shana := XTianqiSect.drop_rows(s, 2026, rows)
	_check("drops_shana_shard", shana.size() == 2 and int(shana[0].id) == 2530 and int(shana[0].count) == 10 and float(shana[0].chance) == 0.5 and int(shana[1].id) == 7, shana)
	var other := XTianqiSect.drop_rows(s, 893, rows)
	_check("drops_other_no_journal", other.size() == 1 and int(other[0].id) == 7, other)
	_check("drops_original", XTianqiSect.drop_rows(_plain_state(), 2026, rows) == rows)
	XState.current = s
	XTianqiSect.JIA = false
	_check("drops_switch_off", XTianqiSect.drop_rows(s, 2026, rows) == rows)
	XTianqiSect.JIA = true
	var text := JSON.stringify(shana)
	_check("drops_no_journal_left", not text.contains("1960"), text)


## 实跑夏娜心魔战（敌群 2028）：打赢发奖励，掉的是碎片 × 10、没有研究日志
func _battle() -> void:
	var s := _tianqi_state()
	s.map_id = 5
	var lg := XBattleLogic.new()
	lg.setup(2028, s)
	var e: XEnemy = lg.enemies[0]
	_check("battle_enemy_is_shana", e.enemy_id == 2026, e.enemy_id)
	var rows: Array = lg.drop_chances(e)
	var shard_rows := rows.filter(func(r): return int(r.kind) == 1 and int(r.id) == 2530)
	_check("battle_rows_shard_only", shard_rows.size() == 1 and int(shard_rows[0].count) == 10 and rows.all(func(r): return not (int(r.kind) == 1 and int(r.id) == 1960)), rows)
	var got := {}
	for i in 400:  # 概率不是必掉：多掷几次直到掉出来（每次抽到的结果缓存，换 token 重掷）
		lg._treasure.clear()
		var d: Array = lg.drops_of(e)
		if not d.is_empty():
			got = d[0]
			break
	_check("battle_rolled_shard", not got.is_empty() and int(got.kind) == 1 and int(got.id) == 2530 and int(got.get("count", 1)) == 10, got)
	var before := s.item_count(2530)
	lg.gain_drops([got])
	_check("battle_gained_ten", s.item_count(2530) - before == 10 and s.item_count(1960) == 0, [before, s.item_count(2530), s.item_count(1960)])
	lg.end_battle(1)
	# 开关关掉：回到研究日志 × 1
	XTianqiSect.JIA = false
	var lg2 := XBattleLogic.new()
	lg2.setup(2028, s)
	var rows2: Array = lg2.drop_chances(lg2.enemies[0])
	XTianqiSect.JIA = true
	lg2.end_battle(1)
	_check("battle_switch_off_journal", rows2.any(func(r): return int(r.kind) == 1 and int(r.id) == 1960 and not r.has("count")), rows2)


func _original() -> void:
	var s := _plain_state()
	s.map_id = 5
	var lg := XBattleLogic.new()
	lg.setup(2028, s)
	var rows: Array = lg.drop_chances(lg.enemies[0])
	lg.end_battle(1)
	_check("original_battle_journal", rows.any(func(r): return int(r.kind) == 1 and int(r.id) == 1960 and not r.has("count")) and not rows.any(func(r): return int(r.id) == 2530), rows)
	_check("original_no_hides", not XTianqiSect.hides(4, 16) and not XTianqiSect.hides(4, 35))
