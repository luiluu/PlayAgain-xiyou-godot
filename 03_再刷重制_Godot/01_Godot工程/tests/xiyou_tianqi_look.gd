extends Node
## 天启篇画面专项（车道「庚」：XTianqiLook、XTianqiLineCards、XTianqiTable、XTianqiMeter、读档线色、楼层色调）。
## 一、素材：四线立绘、纹路都在 content/tianqi/，尺寸对；线色四条齐。
## 二、选线：有 pick_line 的宿主走竖卡，没有（或开关关掉）回到对话框选项；竖卡在自动测试下按 auto_answers 返回。
## 三、方桌：没通关 5 层细裂纹、通关后四块、选定后本线；调查方桌按阶段说话或进选线；开关关掉、原版档不建。
## 四、读档：天启篇存档选了线才有线色；原版档、没选线、开关关掉都没有。
## 五、楼层色调：选了线的 6～30 层乘本线色调，大厅、1～5 层、没选线、开关关掉不乘；地图场景换图时加上／去掉。
## 六、计量：战争线异化战里火花条的值和满值同模块；死期、病灶按 meta 读；开关关掉不显示。

## 地图场景的替身（同 xiyou_tianqi_war 的 FakeHost，多一个 pick_line）
class FakeHost extends RefCounted:
	var answers: Array = []
	var asked: Array = []
	var said: Array = []
	var picks: Array = []
	var picked: Array = []
	var moves: Array = []
	var battles: Array = []
	var map_id := 4
	func show_text(_f: String, _i: int, lines: Array) -> void:
		said.append_array(lines)
	func show_text_with_choices(_f: String, _i: int, _lines: Array, options: Array, _cancel: int) -> int:
		asked.append(options)
		return int(answers.pop_front()) if not answers.is_empty() else options.size() - 1
	func transfer(id: int, x: int, y: int, d: int, _fade := 0) -> void:
		moves.append([id, x, y, d])
		map_id = id
		XState.current.map_id = id
	func start_battle(troop: int, _e: bool, _l: bool, _random := false) -> int:
		battles.append(troop)
		XTianqiWarAlien._pending = ""
		XTianqiHorsemen._pending = ""
		return 2   # 输了回大厅，开场停在第一节

class CardHost extends FakeHost:
	func pick_line(lines: Array, playable: Array) -> int:
		picked.append([lines.size(), playable.duplicate()])
		return int(picks.pop_front()) if not picks.is_empty() else -1


var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


## 天启篇存档、5 个弱者；floors＝已通关几层（变量 20＝floors＋1）
func _state(floors := 5, line := "") -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, floors + 1)
	XState.current = s
	if line != "":
		s.flags.tianqi["line"] = line
	return s


func _run() -> void:
	_assets()
	await _choice()
	await _table()
	_save()
	await _tint()
	_meter()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _assets() -> void:
	var keys := XTianqi.LINES.map(func(l): return str(l.key))
	_check("look_all_lines", keys.all(func(k): return not XTianqiLook.info(k).is_empty()) and XTianqiLook.LOOK.size() == keys.size(), keys)
	for k in keys:
		var p := XTianqiLook.portrait(k)
		var m := XTianqiLook.mark(k)
		_check("portrait_" + k, p != null and p.get_size() == Vector2(512, 768), p.get_size() if p else null)
		_check("mark_" + k, m != null and m.get_size() == Vector2(512, 512), m.get_size() if m else null)
	_check("unknown_line_no_art", XTianqiLook.portrait("nope") == null and XTianqiLook.main_color("nope", Color.RED) == Color.RED)
	_check("materials", XTianqiLook.silhouette_material("war").shader != null and XTianqiLook.mark_material("plague").shader != null)


func _choice() -> void:
	# 有 pick_line：竖卡选战争线 → 小小鱼一句 → 确认 → 开场（第一节输了回大厅）
	var s := _state()
	var h := CardHost.new()
	h.picks = [0]
	h.answers = [0]
	await XTianqi.run_line_choice(h, s)
	_check("cards_used", h.picked.size() == 1 and int(h.picked[0][0]) == XTianqi.LINES.size() and h.asked.size() == 1, [h.picked, h.asked])
	_check("cards_playable_list", h.picked.size() == 1 and h.picked[0][1] == XTianqi.LINES.map(func(l): return XTianqi.line_playable(str(l.key))), h.picked)
	_check("cards_chose_war", XTianqi.line_of(s) == "war", XTianqi.line_of(s))
	_check("cards_no_card_text", not h.said.any(func(t): return str(t).contains("本线特点")), h.said.slice(0, 3))
	# 再想想：什么都不选
	s = _state()
	h = CardHost.new()
	h.picks = [-1]
	await XTianqi.run_line_choice(h, s)
	_check("cards_later", XTianqi.line_of(s) == "" and h.asked.is_empty() and h.said.is_empty())
	# 开关关掉：同一个宿主回到对话框选项和卡面文字
	XTianqiLook.CARDS = false
	s = _state()
	h = CardHost.new()
	h.answers = [XTianqi.LINES.size()]
	await XTianqi.run_line_choice(h, s)
	_check("cards_off_dialog", h.picked.is_empty() and h.asked.size() == 1 and h.asked[0].size() == XTianqi.LINES.size() + 1, [h.picked, h.asked])
	XTianqiLook.CARDS = true
	# 自动测试下竖卡按 auto_answers 返回
	XMessageBox.auto = true
	XMessageBox.auto_answers = [3]
	var got: int = await XTianqiLineCards.pick(self, XTianqi.LINES, [true, true, true, true])
	XMessageBox.auto_answers = []
	var none: int = await XTianqiLineCards.pick(self, XTianqi.LINES, [true, true, true, true])
	XMessageBox.auto = false
	_check("cards_auto", got == 3 and none == -1, [got, none])
	# 真画面：四张卡、键盘左右换选中、取消返回 -1
	var c := XTianqiLineCards.new()
	c.lines = XTianqi.LINES
	c.playable = [true, false, false, true]
	add_child(c)
	await _frames(2)
	_check("cards_four", c._cards.size() == 4 and c._cards[0].selected and not c._cards[1].ok and c._cards[3].ok)
	var ev := InputEventAction.new()
	ev.action = "ui_left"
	ev.pressed = true
	c._handle(ev)
	_check("cards_wrap_left", c.index == 3 and c._cards[3].selected, c.index)
	var out := []
	c.decided.connect(func(i): out.append(i))
	var ev2 := InputEventAction.new()
	ev2.action = "ui_cancel"
	ev2.pressed = true
	c._handle(ev2)
	_check("cards_cancel", out == [-1], out)
	c.queue_free()


func _table() -> void:
	var s := _state(3)
	_check("table_hint", XTianqiTable.wanted(s) == "hint")
	s.set_variable(20, 6)
	_check("table_split", XTianqiTable.wanted(s) == "split")
	s.flags.tianqi["line"] = "war"
	_check("table_chosen", XTianqiTable.wanted(s) == "chosen")
	XTianqiLook.TABLE = false
	_check("table_off", XTianqiTable.wanted(s) == "")
	XTianqiLook.TABLE = true
	var plain := XState.new_game(3, 1, [8, 9, 10])
	_check("table_plain", XTianqiTable.wanted(plain) == "")
	_check("table_cells", XTianqiTable.is_table(Vector2i(14, 12)) and not XTianqiTable.is_table(Vector2i(14, 13)))
	# 调查：细裂纹时小小鱼拦；该选线时进选线；选过了说本线
	var t := XTianqiTable.new()
	add_child(t)
	s = _state(3)
	t.setup()
	var h := CardHost.new()
	await t.on_action(_TableHost.new(h))
	_check("table_too_early", h.said.any(func(x): return str(x).contains("还没到时候")) and h.picked.is_empty(), h.said)
	s.set_variable(20, 6)
	h.said.clear()
	h.picks = [-1]
	await t.on_action(_TableHost.new(h))
	_check("table_opens_choice", h.picked.size() == 1 and t.state == "split", [h.picked, t.state])
	s.flags.tianqi["line"] = "famine"
	h.said.clear()
	await t.on_action(_TableHost.new(h))
	_check("table_chosen_says", t.state == "chosen" and t.line == "famine" and h.said.any(func(x): return str(x).contains("饥荒之路")), h.said)
	_check("table_figs_hidden_chosen", t._figs.size() == 4 and t._figs.all(func(f): return not f.visible))
	t.queue_free()
	# 地图场景：天启篇存档在大厅建方桌，原版档不建
	s = _state()
	s.x = 14
	s.y = 14
	var map := await _open_map(s)
	_check("map_table_built", map.tianqi_table != null and is_instance_valid(map.tianqi_table) and map.tianqi_table.state == "split")
	map.queue_free()
	await _frames(2)
	plain.map_id = 4
	plain.x = 14
	plain.y = 14
	XState.current = plain
	map = await _open_map(plain)
	_check("map_table_plain_none", map.tianqi_table == null and map.get_node_or_null("TianqiFloorTint") == null)
	map.queue_free()
	await _frames(2)


## 方桌调查用的宿主：转给 CardHost，另外接 _set_busy／refresh_events
class _TableHost extends RefCounted:
	var h
	var busy := false
	func _init(host) -> void:
		h = host
	func _set_busy(b: bool) -> void:
		busy = b
	func refresh_events() -> void:
		pass
	func show_text(f: String, i: int, lines: Array) -> void:
		await h.show_text(f, i, lines)
	func show_text_with_choices(f: String, i: int, lines: Array, options: Array, cancel: int) -> int:
		return await h.show_text_with_choices(f, i, lines, options, cancel)
	func pick_line(lines: Array, playable: Array) -> int:
		return await h.pick_line(lines, playable)


func _open_map(s: XState) -> XMapScene:
	var map := XMapScene.new()
	add_child(map)
	for i in 3000:
		await _frames(1)
		if map.player != null and not map.busy and map.map_id == s.map_id:
			break
	await _frames(2)
	return map


func _save() -> void:
	var s := _state(5, "plague")
	var d := s.to_dict()
	_check("save_line", XTianqiLook.line_of_save(d) == "plague" and XSaveScene.save_line(d) == "plague")
	s.flags.tianqi.erase("line")
	_check("save_no_line", XTianqiLook.line_of_save(s.to_dict()) == "")
	var plain := XState.new_game(3, 1, [8, 9, 10])
	_check("save_plain", XTianqiLook.line_of_save(plain.to_dict()) == "" and XTianqiLook.line_of_save(null) == "")
	d = _state(5, "plague").to_dict()   # to_dict 的 flags 和存档对象是同一份，上面删过线，重建一份
	XTianqiLook.SAVE_COLOR = false
	_check("save_off", XSaveScene.save_line(d) == "" and XTianqiLook.line_of_save(d) == "plague")
	XTianqiLook.SAVE_COLOR = true


func _tint() -> void:
	var s := _state(5, "war")
	var f6 := XDungeon.map_floor(13)
	_check("floor_of_13", f6 == 6, f6)
	_check("tint_floor6", XTianqiLook.floor_tint(s, 13) == XTianqiLook.info("war").tint)
	_check("tint_lobby_none", XTianqiLook.floor_tint(s, 4) == Color.WHITE)
	s.flags.tianqi.erase("line")
	_check("tint_no_line", XTianqiLook.floor_tint(s, 13) == Color.WHITE)
	s.flags.tianqi["line"] = "war"
	XTianqiLook.FLOOR_TINT = false
	_check("tint_off", XTianqiLook.floor_tint(s, 13) == Color.WHITE)
	XTianqiLook.FLOOR_TINT = true
	_check("tint_plain", XTianqiLook.floor_tint(XState.new_game(3, 1, [8, 9, 10]), 13) == Color.WHITE)
	# apply_floor_tint：加上、换色、去掉
	var n := Node2D.new()
	add_child(n)
	XTianqiLook.apply_floor_tint(n, s, 13)
	var cm := n.get_node_or_null("TianqiFloorTint") as CanvasModulate
	_check("apply_tint_add", cm != null and cm.color == XTianqiLook.info("war").tint)
	XTianqiLook.apply_floor_tint(n, s, 4)
	await _frames(1)
	_check("apply_tint_remove", n.get_node_or_null("TianqiFloorTint") == null)
	n.queue_free()


func _meter() -> void:
	var s := _state(5, "war")
	_check("meter_war_prepare", XTianqiWarAlien.prepare("omen", s))
	var lg := XBattleLogic.new()
	lg.setup(30, s)
	var m := XTianqiMeter.make(lg, func(): return {})
	add_child(m)
	m.refresh()
	var war: Array = m.rows.filter(func(r): return r.key == "war")
	_check("meter_war_row", war.size() == 1 and int(war[0].full) == XTianqiWarAlien.spark_full(lg) and int(war[0].value) == 0, m.rows)
	XTianqiWarAlien.fight(lg).sparks = 7
	m.refresh()
	_check("meter_war_value", m.rows.size() == 1 and int(m.rows[0].value) == 7 and str(m.rows[0].text) == "7／%d" % XTianqiWarAlien.spark_full(lg), m.rows)
	XTianqiWarAlien.fight(lg).sparks = 0
	m.refresh()
	_check("meter_war_flash", m._flash.has("war"))
	# 死期、病灶：按 meta 读（模块不在也能显示）
	var a: XActor = lg.actors[0]
	lg.set_meta("xdeath_alien", {"units": {lg.enemies[0]: {}}, "doom": {a: true}})
	lg.set_meta("xplague_alien", {"units": {lg.enemies[0]: {}}, "layers": 9})
	m.refresh()
	var keys := m.rows.map(func(r): return str(r.key))
	_check("meter_order", keys == ["war", "death", "plague"], keys)
	_check("meter_doomed", m.doomed == [a] and str(m.rows[1].text).contains(a.display_name()), m.rows)
	_check("meter_plague", int(m.rows[2].value) == 9 and int(m.rows[2].full) > 0, m.rows[2])
	# 场上本线异化怪都倒下：战争行不显示
	for e in lg.enemies:
		e.hp = 0
		e.add_state(1)
	m.refresh()
	_check("meter_war_gone", not m.rows.any(func(r): return r.key == "war"), m.rows)
	XTianqiLook.METER = false
	m.refresh()
	_check("meter_off", m.rows.is_empty() and m.doomed.is_empty())
	XTianqiLook.METER = true
	# 不是天启篇异化战：一行都没有
	var plain := XBattleLogic.new()
	plain.setup(30, _state(5, "war"))
	var m2 := XTianqiMeter.make(plain)
	add_child(m2)
	m2.refresh()
	_check("meter_plain_none", m2.rows.is_empty())
	m.queue_free()
	m2.queue_free()
	XTianqiWarAlien.end(lg)
