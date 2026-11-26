extends Node
## 主菜单技能页（Scene_Skill）。预期值来自正式 v0.24 浏览器实测（原版参照/claude_skill_00、_01_list）：
## 狗逍遥 Lv10（学会 6168/5980/5548/2571/2786）：技能类型 战技/魔法/被动/其他/功法；战技列表 [160 万剑诀, 101 御剑术]，
## 地图上都不能用（战斗专用），列表两列宽 602、间距 48；选第一项时说明卡在 (650,236)。
var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(1)


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name))
	preload("res://tests/ui_pixel_dump.gd").dump(get_tree().root, out_dir.path_join(name.get_basename() + ".win.json"), name)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_skill_page"
	var s := XState.new_game(3, 1, [8, 9, 10])
	for id in [1, 8, 9, 10]:
		var a := s.actor(id)
		for k in [6168, 5980, 5548, 2571, 2786]:
			a.learn_skill(k)
		a.change_level(10)
		a.refresh_passive()
		a.recover_all()
	var page := XSkillScene.new()
	page.actor_index = 0
	add_child(page)
	await frames(3)
	check("layout", page.type_win.position == Vector2(0, 0) and page.type_win.size == Vector2(240, 172) and page.status_win.position == Vector2(240, 0)
		and page.list_win.position == Vector2(0, 172) and page.list_win.size == Vector2(1280, 548))
	var names := page.types().map(func(t): return page.type_name(t))
	check("types", names == ["战技", "魔法", "被动", "其他", "功法"], names)
	check("skill_order", s.actor(1).skills().map(func(k): return int(k.id)).slice(0, 6) == [160, 2571, 2786, 5548, 5980, 6168], s.actor(1).skills().map(func(k): return int(k.id)))
	check("list_stype1", page.entries().map(func(k): return int(k.id)) == [160, 101], page.entries().map(func(k): return int(k.id)))
	check("not_usable_on_map", page.entries().all(func(k): return not page.usable(k)))
	check("help_hidden_in_type", not page.help_card.visible)
	await shot("技能_类型.png")
	XSound.system_log.clear()
	await press("ui_accept")
	check("type_to_list", page.mode == "list" and page.index == 0 and XSound.system_log == [1], XSound.system_log)
	await frames(2)
	# 两列列表固定用正式位置（O-008 的贴边放法会盖住另一列）
	check("help_position", page.help_card.visible and page.help_card.position == Vector2(650, 236), page.help_card.position)
	# v0.62.12 实跑（review_system_pages 页 skill_page）：万剑诀说明卡 Sprite_ItemHelp 400×247；块间空行只占 4+8，
	# 不被 O-007 的最小字号撑成 24（KEEP_GAP_ROWS，关掉就高出两三条空行）
	var card_h: float = page.help_card.size.y
	check("help_card_gap_rows", card_h >= 247.0 and card_h <= 252.0, card_h)
	XHelpCard.KEEP_GAP_ROWS = false
	page.help_card.show_for(page.current())
	check("help_card_gap_rows_rollback", page.help_card.size.y >= card_h + 30.0, page.help_card.size.y)
	XHelpCard.KEEP_GAP_ROWS = true
	page.help_card.show_for(page.current())
	await shot("技能_列表.png")
	await press("ui_right")
	check("right_moves_column", page.index == 1)
	XSound.system_log.clear()
	await press("ui_accept")
	check("battle_only_buzzer", page.mode == "list" and XSound.system_log == [3], XSound.system_log)
	await press("ui_cancel")
	check("list_cancel", page.mode == "type" and not page.help_card.visible)
	await press("ui_down")
	check("type_down", page.type_index == 1 and page.index == 0)
	# Q/E 换角色
	page.change_actor(1)
	check("next_actor", page.actor().actor_id == s.party[1] and page.mode == "type" and page.type_index == 0)
	page.change_actor(-1)
	# 地图上能用的技能：付消耗、回血，使用技能音（借用一个能在菜单用的回复技能数据）
	# 地图上能用的回复技能在数据里都是复活（对象 9）：用 499 先祖之魂（战技、无消耗）复活倒下的队友
	var a1 := s.actor(1)
	a1.learn_skill(499)
	var fallen := s.actor(s.party[1])
	fallen.add_state(1)
	fallen.hp = 0.0
	page.type_index = page.types().find(1)
	page.index = page.entries().find_custom(func(k): return int(k.id) == 499)
	page.mode = "list"
	check("revive_usable", page.usable(XDB.rec("Skills", 499)))
	page.ok()
	check("list_to_actor", page.mode == "actor" and not page.help_card.visible)   # v0.10：选人时隐藏说明卡
	page.actor_pick = 1
	XSound.system_log.clear()
	page.ok()
	check("use_skill_revives", fallen.is_alive() and fallen.hp > 0.0 and XSound.system_log == [23], [fallen.hp, XSound.system_log])
	page.actor_pick = 0
	XSound.system_log.clear()
	page.ok()
	check("no_valid_target_buzzer", XSound.system_log == [3], XSound.system_log)
	# 第五位也应能被选中／复活（Window_MenuActor 四行窗口会滚动）。
	s.add_actor(2)
	s.actor(2).add_state(1)
	page.actor_pick = 0
	page.actor_top = 0
	for i in range(4):
		page._move(1, false, false)
	var ref: Dictionary = XDB.load_json("oracle/party.json").get("menuActor", {})
	check("fifth_actor_scroll", page.actor_pick == int(ref.get("index", -1)) and page.actor_top == int(ref.get("topRow", -1))
		and XSkillScene.ACTOR_ROWS == int(ref.get("maxPageRows", -1)))
	page.ok()
	check("fifth_actor_revives", s.actor(2).is_alive())
	page.queue_free()

	# 主菜单：技能 → 选人 → 技能页
	var menu := XMenu.new()
	add_child(menu)
	await frames(2)
	menu._cmd_index = XMenu.COMMANDS.map(func(c): return c[1]).find("skill")
	menu._ok()
	menu._ok()
	check("menu_opens_skill", menu.get_children().any(func(n): return n is XSkillScene))
	menu.queue_free()
	await frames(2)
	# 各类型页的列表内容（排序、名字、品质色）：新源 v0.62.12 浏览器实跑（review_system_pages 页 skill_page 的 skill_3_passive／4_magic／5_other／6_function，
	# 同一批技能：另学 2000／2001（魔法）、2005／2006（被动）、2017／2018（其他））。列表按学习顺序（id 升序，职业自带的 2746／2748／41 排在后面）
	for k in [2000, 2001, 2005, 2006, 2017, 2018]:
		s.actor(1).learn_skill(k)
	var tp := XSkillScene.new()
	tp.actor_index = 0
	add_child(tp)
	await frames(3)
	var expect := {
		"魔法": [[2000, "时间停滞", Color8(255, 214, 90)], [2001, "寿命剥夺", Color8(255, 214, 90)]],
		"被动": [[2005, "天龙佛体", Color8(255, 160, 64)], [2006, "口吐箴言", Color8(255, 160, 64)], [2571, "万众一心", Color8(255, 214, 90)],
			[2786, "SupperStar", Color8(255, 72, 60)], [5548, "普通难度", Color8(255, 214, 90)], [5980, "难度适应", Color8(255, 214, 90)],
			[6168, "天道诅咒", Color8(235, 240, 247)], [2746, "妖兽化形", Color8(255, 214, 90)], [2748, "麒麟臂", Color8(255, 214, 90)], [41, "天遁仙法", Color8(255, 214, 90)]],
		"其他": [[2017, "羁绊:西天", Color8(255, 160, 64)], [2018, "西天(2)", Color8(255, 160, 64)]],
		"功法": []}
	for ti in tp.types().size():
		tp.type_index = ti
		tp.index = 0
		var tname: String = tp.type_name(tp.types()[ti])
		if not expect.has(tname):
			continue
		var got := tp.entries().map(func(k): return [int(k.id), str(k.name), XQuality.list_color(k)])
		var want: Array = expect[tname]
		var same := got.size() == want.size()
		for i in (want.size() if same else 0):
			same = same and got[i][0] == want[i][0] and got[i][1] == want[i][1] and got[i][2].is_equal_approx(want[i][2])
		check("type_page_" + tname, same, got)
	tp.queue_free()
	# 事件降级会降低最大资源；原版 changeExp 最后 refresh，不能把原来的高等级 HP 留在新上限之外。
	var level_ref: Dictionary = XDB.load_json("oracle/party.json").get("levelDown", {})
	var level_state := XState.new_game_blank()
	level_state.add_actor(1)
	var level_actor := level_state.actor(int(level_ref.get("actor", 1)))
	level_actor.change_level_mv(int(level_ref.get("from", 10)))
	level_actor.recover_all()
	level_actor.change_level_mv(int(level_ref.get("to", 1)))
	check("level_down_clamps_resources", level_actor.hp == float(level_ref.get("hp", -1)) and level_actor.mp == float(level_ref.get("mp", -1)), [level_actor.hp, level_actor.mp, level_ref])
	await _read_window_check(false)
	await _read_window_check(true)
	finish()


## 记下 painter 画的每一笔（不真画）
class RecCanvas extends XMVCanvas:
	var log := []

	func text(s: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, lh := XUI.LINE_HEIGHT, alpha := 1.0, _zoom := 1.0, _pivot := Vector2.ZERO, _outline := OUTLINE) -> void:
		log.append(["text", s, x, y, max_w, align, color, size, lh, alpha])

	func icon(index: int, x: float, y: float, alpha := 1.0, size := 32.0) -> void:
		log.append(["icon", index, x, y, alpha, size])

	func face(face_name: String, index: int, x: float, y: float, _w := 144.0, _h := 144.0, _alpha := 1.0) -> void:
		log.append(["face", face_name, index, x, y])

	func cursor(r: Rect2, active := true) -> void:
		log.append(["cursor", r, active])

	func fill_rect(r: Rect2, color: Color) -> void:
		log.append(["fill", r, color])

	func gradient(r: Rect2, c1: Color, c2: Color) -> void:
		log.append(["gradient", r, c1, c2])

	func gauge(dx: float, dy: float, dw: float, rate: float, _c1: Color, _c2: Color, _lh := XUI.LINE_HEIGHT) -> void:
		log.append(["gauge", dx, dy, dw, rate])


## T545：技能页整段包只读窗口（XSkillScene.PAGE_READ_MEMO）。同一页面状态开关两态各出一份快照——旧界面是列表／类型／状态／选人窗
## 画的每一笔（含消耗数字、能不能用的半透明）和说明卡的行，新皮肤是列表行与详情牌——必须逐项相同；
## 开着时打开命中比对（READ_VERIFY），零不一致，窗口刷新完必须关严。
func _page_snapshot(page: XSkillScene) -> Array:
	var out := []
	var types := page.types()
	for ti in types.size():
		for pick in [0, 7, 20]:
			page.mode = "list"
			page.type_index = ti
			var n := page.entries().size()
			if n == 0 or (pick > 0 and pick >= n):
				continue
			page.index = pick
			page.top = maxi(pick / 2 - 5, 0)
			page._refresh()
			var row := [page.type_name(types[ti]), pick]
			for painter in [page._paint_types, page._paint_status, page._paint_list, page._paint_actors]:
				var rec := RecCanvas.new()
				rec.size = XSkillScene.LIST_RECT.size
				rec.font = page.list_win.canvas.font
				painter.call(rec)
				row.append(var_to_str(rec.log))
				rec.free()
			row.append(var_to_str(page.help_card.rows) if page.help_card.visible or page.skin != null else "")
			if page.skin != null:
				var card: XSkinCard = page.skin.card
				row.append(var_to_str(page.skin.list.items.map(func(r): return [r.text, r.get("right", ""), r.disabled, r.get("sub", ""), r.get("reason", "")])))
				row.append(var_to_str([card.title, card.subtitle, card.desc, card.sections, card.buttons]))
			out.append(row)
	return out


func _read_window_check(skin_on: bool) -> void:
	var tag := "skin" if skin_on else "classic"
	var force: bool = XUiSkin.FORCE
	XUiSkin.FORCE = skin_on
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var a := s.actor(1)
	var rows: Array = XDB.table("Skills")
	var learned := 0
	for i in range(1, rows.size()):
		var r = rows[i]
		if learned < 60 and r is Dictionary and int(r.get("stypeId", 0)) == 4 and str(r.get("name", "")) != "" and not XTianqiSkills.is_shell(i):
			a.learn_skill(i)
			learned += 1
	for k in [499, 2000, 2001, 2017]:
		a.learn_skill(k)
	a.change_level(80)
	a.refresh_passive()
	a.recover_all()
	var verify: bool = XActor.READ_VERIFY
	var fatal: bool = XActor.READ_VERIFY_FATAL
	XSkillScene.PAGE_READ_MEMO = false
	var page := XSkillScene.new()
	page.actor_index = 0
	add_child(page)
	await frames(2)
	check("read_window_%s_skin_matches" % tag, (page.skin != null) == skin_on)
	var old := _page_snapshot(page)
	XSkillScene.PAGE_READ_MEMO = true
	XActor.READ_VERIFY = true
	XActor.READ_VERIFY_FATAL = false
	XActor.read_mismatches.clear()
	var hits: int = XActor.read_hits
	var new := _page_snapshot(page)
	page.index = 0
	page._move(1, false, false)
	await frames(2)  # 真画一遍（painter 走窗口）
	check("read_window_%s_hits" % tag, XActor.read_hits > hits, XActor.read_hits - hits)
	check("read_window_%s_no_mismatch" % tag, XActor.read_mismatches.is_empty(), XActor.read_mismatches.slice(0, 3))
	check("read_window_%s_closed" % tag, XActor._read_depth == 0, XActor._read_depth)
	var diff := -1
	for i in maxi(old.size(), new.size()):
		if i >= old.size() or i >= new.size() or old[i] != new[i]:
			diff = i
			break
	check("read_window_%s_same" % tag, old.size() > 5 and diff == -1, [old.size(), new.size(), diff, old[diff].slice(0, 2) if diff >= 0 and diff < old.size() else []])
	check("read_window_%s_has_costs" % tag, old.any(func(r): return r[4].contains("MP") or r[4].contains("TP")))
	XActor.READ_VERIFY = verify
	XActor.READ_VERIFY_FATAL = fatal
	XUiSkin.FORCE = force
	page.queue_free()
	await frames(1)


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
