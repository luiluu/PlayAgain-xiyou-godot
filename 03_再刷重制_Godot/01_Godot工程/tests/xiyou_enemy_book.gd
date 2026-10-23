extends Node
## 怪物图鉴（XEnemyBookPage／XEnemyBook）：对照冻结 v0.28 浏览器参照 tests/fixtures/enemy_book_oracle.json
## （新局队伍 1/8/9/10、难度 2，全登记后去掉 3/5/40，目录第 1 项设出没地图与击败数）：
## 全部目录名、115 只敌人状态窗的全部 drawText/drawIcon（文字、字号逐条相等，坐标与宽差 ≤ POS_TOL，颜色经 EnemyNameColorByDifficulty 改色）、
## 6 只敌人的掉落列表、3 只强制神话（O-078 的原版模式）的状态窗与掉落；
## 再走一遍操作（未登记不开掉落、开掉落说明卡在 (880,32)、取消回目录、再取消关闭并记住光标）、
## 登记规则（战斗开始记出没地图、结束登记出现过的与击败数、地图遇敌表、插件指令、存读档）与主菜单入口（公共事件 2）。

const FIXTURE := "res://tests/fixtures/enemy_book_oracle.json"
const POS_TOL := 0.05

var results := []
var out_dir := ""


## 地图宿主替身：只接图鉴与事件刷新
class FakeHost extends Node:
	var opened := 0
	func open_enemy_book() -> void:
		opened += 1
		await get_tree().process_frame
	func refresh_events() -> void:
		pass
## 属性百分比只差浮点末位的条数：XBattler.additive_rate 的求和次序是 1+(v−1)，原版 reduce 是 (s+v)−1
static var float_tail := []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


static func _color(text: String) -> Color:
	return XQuality.parse_rgba(text) if text.begins_with("rgba") else Color(text)


## 参照操作 → 比较形：文字 [文字,x,y,宽,对齐,字号,颜色hex]（颜色按 EnemyNameColorByDifficulty 改）、图标 [图标号,x,y]
static func want_form(ops: Array, difficulty: int) -> Array:
	var out := []
	for o in ops:
		if o[0] == "i":
			out.append([int(o[1]), float(o[2]), float(o[3])])
		else:
			out.append([str(o[1]), float(o[2]), float(o[3]), float(o[4]), str(o[5]), float(o[6]),
				XEnemy.name_color(str(o[1]), difficulty, _color(str(o[7]))).to_html(false)])
	return _sorted(out)


static func got_form(ops: Array) -> Array:
	var out := []
	for o in ops:
		if o[0] == "i":
			out.append([int(o[1]), float(o[2]), float(o[3])])
		else:
			out.append([str(o[1]), float(o[2]), float(o[3]), float(o[4]), str(o[6]), float(o[7]), (o[8] as Color).to_html(false)])
	return _sorted(out)


static func _sorted(a: Array) -> Array:
	a.sort_custom(func(x, y): return [x[2], x[1], str(x[0])] < [y[2], y[1], str(y[0])] if x.size() == y.size() else x.size() < y.size())
	return a


static func diff(got: Array, want: Array) -> String:
	for i in maxi(got.size(), want.size()):
		if i >= got.size() or i >= want.size():
			return "#%d 条数 %d≠%d %s" % [i, got.size(), want.size(), JSON.stringify(want[i] if i < want.size() else got[i])]
		var g: Array = got[i]
		var w: Array = want[i]
		var bad := g.size() != w.size()
		if not bad:
			for k in w.size():
				if w[k] is String:
					if str(g[k]) != w[k] and _float_tail(str(g[k]), w[k]):
						float_tail.append([g[k], w[k]])
						continue
					bad = bad or str(g[k]) != w[k]
				else:
					bad = bad or absf(float(g[k]) - float(w[k])) > POS_TOL
		if bad:
			return "#%d got %s want %s" % [i, JSON.stringify(g), JSON.stringify(w)]
	return ""


static func _float_tail(g: String, w: String) -> bool:
	if not (g.ends_with("%") and w.ends_with("%")):
		return false
	var a := g.trim_suffix("%")
	var b := w.trim_suffix("%")
	return a.is_valid_float() and b.is_valid_float() and absf(a.to_float() - b.to_float()) < 1e-9


func _setup_state(ref: Dictionary) -> XState:
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	s.difficulty = int(ref.difficulty)
	XEnemyBook.complete(s)
	for id in ref.removed:
		XEnemyBook.remove(s, int(id))
	var rec: Dictionary = ref.record
	s.enemy_book.maps[str(int(rec.enemy))] = rec.maps.duplicate()
	s.enemy_book.defeat[str(int(rec.enemy))] = int(rec.defeat)
	return s


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("fixture_loaded", ref is Dictionary and ref.get("status", {}).size() > 100, FIXTURE):
		get_tree().quit.call_deferred(1)
		return
	var s := _setup_state(ref)
	var diff_id := int(ref.difficulty)
	check("js_num", XEnemyBookPage.js_num(0.7 * 100) == "70" and XEnemyBookPage.js_num(100 - 0.7 * 100) == "30"
		and XEnemyBookPage.js_num(0.1 * 3 * 100) == "30.000000000000004" and XEnemyBookPage.js_num(-20) == "-20",
		[XEnemyBookPage.js_num(0.1 * 3 * 100), XEnemyBookPage.js_num(100 - 0.7 * 100)])
	var page := XEnemyBookPage.new()
	add_child(page)
	await frames()
	# 目录
	var ids: Array = ref.names.map(func(x): return int(x[0]))
	check("index_ids", page.ids == ids, [page.ids.size(), ids.size()])
	var bad_names := []
	for i in ref.names.size():
		if page.index_name(i) != str(ref.names[i][1]):
			bad_names.append([i, page.index_name(i), ref.names[i][1]])
	check("index_names", bad_names.is_empty(), bad_names.slice(0, 6))
	var idx_ops := []
	for i in XEnemyBookPage.ROWS:
		idx_ops.append(XEnemyBookPage._t(str(i + 1), 6, i * 36.0, 40))
		idx_ops.append(XEnemyBookPage._t(page.index_name(i), 46, i * 36.0, XEnemyBookPage.INDEX_NAME_W))
	var d := diff(got_form(idx_ops), want_form(ref.index0, diff_id))
	check("index_page0", d == "", d)
	# 状态窗
	var bad := []
	for key in ref.status:
		var i := int(key)
		var e := page.enemy(ids[i])
		d = diff(got_form(XEnemyBookPage.status_ops(e)), want_form(ref.status[key][1], diff_id))
		if d != "":
			bad.append("%d(敌人%d) %s" % [i, ids[i], d])
	check("oracle_status", bad.is_empty(), {"count": bad.size(), "first": bad.slice(0, 6)})
	print("属性百分比浮点末位不同 %d 处（见 float_tail 注释）：%s" % [float_tail.size(), JSON.stringify(float_tail.slice(0, 3))])
	# 掉落列表
	bad = []
	for key in ref.drops:
		var e := page.enemy(int(ref.drops[key][0]))
		var rows := XEnemyBookPage.drop_rows(e)
		var names: Array = rows.map(func(r): return [int(r.id), str(r.item.name)])
		var want_names: Array = ref.drops[key][1].map(func(r): return [int(r[0]), str(r[1])])
		var ops := []
		for k in mini(rows.size(), XEnemyBookPage.ROWS):
			ops += XEnemyBookPage.drop_row_ops(rows[k], k * 36.0)
		d = diff(got_form(ops), want_form(ref.drops[key][2], diff_id))
		if names != want_names or d != "":
			bad.append("%s %s %s %s" % [key, JSON.stringify(names).left(300), JSON.stringify(want_names).left(300), d])
	check("oracle_drops", bad.is_empty(), {"count": bad.size(), "first": bad.slice(0, 4)})
	# 原版模式：强制神话
	bad = []
	for key in ref.elite:
		var id := int(ref.elite[key][0])
		var e := XEnemy.new().setup(id, diff_id, 0.0)
		d = diff(got_form(XEnemyBookPage.status_ops(e)), want_form(ref.elite[key][2], diff_id))
		var names: Array = XEnemyBookPage.drop_rows(e).map(func(r): return [int(r.id), str(r.item.name)])
		var want_names: Array = ref.elite[key][3].map(func(r): return [int(r[0]), str(r[1])])
		if d != "" or names != want_names or not e.elite:
			bad.append("%d %s %s %s" % [id, d, JSON.stringify(names).left(200), JSON.stringify(want_names).left(200)])
	check("oracle_elite", bad.is_empty(), {"count": bad.size(), "first": bad.slice(0, 3)})
	page.queue_free()
	await frames()
	await _flow(ref)
	_registration()
	await _interpreter()
	await _menu_entry()
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.3, true, false, true).timeout
	await frames(3)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _flow(ref: Dictionary) -> void:
	XEnemyBookPage.last_index = 0
	var book := XEnemyBookPage.new()
	add_child(book)
	await frames()
	var geo: Dictionary = ref.geo
	var rect := func(w: Control) -> Array: return [w.position.x, w.position.y, w.size.x, w.size.y]
	check("geometry", rect.call(book.index_win) == geo.index.map(func(x): return float(x))
		and rect.call(book.status_win) == geo.status.map(func(x): return float(x))
		and rect.call(book.drop_win) == geo.drops.map(func(x): return float(x)) and int(geo.rows) == XEnemyBookPage.ROWS,
		[rect.call(book.index_win), rect.call(book.status_win)])
	await shot("enemy_book_0")
	check("open_first", book.index == 0 and not book._status_ops.is_empty() and book.mode == "index" and not book.drop_win.visible)
	# 第 3 项（敌人 3）未登记：状态窗空、确定不开掉落
	book.select(2)
	await frames()
	check("unknown_blank", book._status_ops.is_empty() and book._sprite_tex == null)
	book.ok()
	check("unknown_no_drops", book.mode == "index" and not book.drop_win.visible)
	book.select(0)
	book.ok()
	await frames()
	check("drops_open", book.mode == "drops" and book.drop_win.visible and not book.status_win.visible and book.drop_index == 0 and not book.drop_list.is_empty())
	await shot("enemy_book_0_drops")
	check("drops_help", book.help_card.visible and book.help_card.position == Vector2(880, 32), [book.help_card.position, book.help_card.size])
	book._move(1, true)
	check("drops_move", book.drop_index == 1 and book.help_card.visible)
	book.cancel()
	check("drops_cancel", book.mode == "index" and not book.drop_win.visible and book.status_win.visible and not book.help_card.visible and book.index == 0)
	book._page_jump(1)
	check("page_jump", book.index == XEnemyBookPage.ROWS and book.top > 0)
	var closed := [false]
	book.closed.connect(func(): closed[0] = true)
	book.cancel()
	check("cancel_closes", closed[0] and XEnemyBookPage.last_index == XEnemyBookPage.ROWS)
	book.queue_free()
	await frames()
	var again := XEnemyBookPage.new()
	add_child(again)
	await frames()
	check("remembers_index", again.index == XEnemyBookPage.ROWS)
	again.queue_free()
	XEnemyBookPage.last_index = 0
	await frames()


## 登记规则（ResisterTiming 2）与存档字段
func _registration() -> void:
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	# 找一个含隐藏成员的敌群
	var troop := 0
	for t in XDB.table("Troops"):
		if t is Dictionary and t.get("members", []).size() >= 2 and t.members.any(func(m): return bool(m.get("hidden", false))) \
				and t.members.any(func(m): return not bool(m.get("hidden", false))):
			troop = int(t.id)
			break
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	var appeared := XEnemyBook.on_battle_start(s, troop, {"displayName": "测试图"}, logic.enemies)
	var hidden_ids: Array = logic.enemies.filter(func(e): return e.hidden).map(func(e): return e.enemy_id)
	var shown: Array = logic.enemies.filter(func(e): return not e.hidden)
	check("battle_start_maps", logic.enemies.all(func(e): return XEnemyBook.record_maps(s, e.enemy_id) == ["测试图"])
		and not hidden_ids.is_empty() and appeared.size() == shown.size(), [troop, appeared, hidden_ids])
	check("not_registered_before_end", logic.enemies.all(func(e): return not XEnemyBook.registered(s, e.enemy_id)))
	shown[0].hp = 0.0
	XEnemyBook.on_battle_end(s, appeared, logic.enemies)
	check("battle_end_registers", shown.all(func(e): return XEnemyBook.registered(s, e.enemy_id))
		and hidden_ids.all(func(id): return not XEnemyBook.registered(s, id) or shown.any(func(e): return e.enemy_id == id)), hidden_ids)
	check("defeat_counted", XEnemyBook.defeat_number(s, shown[0].enemy_id) == 1 + shown.filter(func(e): return e != shown[0] and e.enemy_id == shown[0].enemy_id and e.is_dead()).size())
	# 再进同图：地图名不重复
	XEnemyBook.on_battle_start(s, troop, {"displayName": "测试图"}, logic.enemies)
	check("maps_no_dup", XEnemyBook.record_maps(s, shown[0].enemy_id) == ["测试图"])
	# Game_Map.setup：遇敌表
	var map_id := 0
	for id in range(1, 240):
		if not XDB.map(int(id)).get("encounterList", []).is_empty():
			map_id = int(id)
			break
	var m := XDB.map(map_id)
	XEnemyBook.on_map_setup(s, m)
	var first_troop := XDB.rec("Troops", int(m.encounterList[0].troopId))
	check("map_setup_maps", XEnemyBook.record_maps(s, int(first_troop.members[0].enemyId)).has(str(m.displayName)), [map_id, m.displayName])
	# 插件指令
	XEnemyBook.plugin_command(s, PackedStringArray(["EnemyBook", "complete"]))
	check("plugin_complete", XEnemyBook.ids().all(func(id): return XEnemyBook.registered(s, id)))
	XEnemyBook.plugin_command(s, PackedStringArray(["EnemyBook", "remove", "1"]))
	check("plugin_remove", not XEnemyBook.registered(s, 1))
	# 存读档
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check("save_roundtrip", not XEnemyBook.registered(back, 1) and XEnemyBook.registered(back, 2)
		and XEnemyBook.defeat_number(back, shown[0].enemy_id) == XEnemyBook.defeat_number(s, shown[0].enemy_id)
		and XEnemyBook.record_maps(back, shown[0].enemy_id) == ["测试图"])
	var blank := XState.new_game_blank().to_dict()
	blank.erase("enemyBook")
	var old := XState.from_dict(blank)
	check("old_save_blank", not XEnemyBook.registered(old, 1) and XEnemyBook.defeat_number(old, 1) == 0)


## 公共事件 2 走地图解释器：插件指令 EnemyBook open 交给宿主打开图鉴；EnemyBook complete 全登记
func _interpreter() -> void:
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	var h := FakeHost.new()
	add_child(h)
	var it := MVInterpreter.new(h, s.map_id, 0, XDB.rec("CommonEvents", 2).list)
	await it.run()
	check("ce2_opens_book", h.opened == 1 and it.skipped.is_empty(), [h.opened, it.skipped])
	var it2 := MVInterpreter.new(h, s.map_id, 0, [{"code": 356, "indent": 0, "parameters": ["EnemyBook complete"]}, {"code": 0, "indent": 0, "parameters": []}])
	await it2.run()
	check("plugin_complete_via_event", h.opened == 1 and it2.skipped.is_empty() and XEnemyBook.ids().all(func(id): return XEnemyBook.registered(s, id)))
	h.queue_free()
	await frames()


func _menu_entry() -> void:
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	var menu := XMenu.new()
	add_child(menu)
	await frames()
	var i := menu.command_names().find("怪物图鉴")
	check("menu_enabled", i >= 0 and menu.command_enabled(i))
	menu._cmd_index = i
	menu._ok()
	check("menu_reserves_ce2", menu.event_state.peek_common_event() == 2, menu.event_state.peek_common_event())
	menu.event_state.clear_common_event()
	var ce := XDB.rec("CommonEvents", 2)
	check("ce2_script", int(ce.list[0].code) == 356 and str(ce.list[0].parameters[0]) == "EnemyBook open", ce.get("list", []))
	menu.queue_free()
	await frames()
