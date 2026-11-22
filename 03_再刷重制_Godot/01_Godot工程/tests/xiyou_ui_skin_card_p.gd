extends Node
## 【cc·T364·未经审查】新界面卡 P：图鉴三本（人物 XActorBook、怪物 XEnemyBookPage、镶嵌 XInlayBook）→ XSkinBookPage。
## - 门控：天启篇建新页；XSkinBookPage.ENABLED＝false、西游存档、XUiSkin.ENABLED＝false 都不建（三本同一个开关），旧窗照旧。
## - 对应表（T254 3.14～3.16）逐行：旧页 status_ops 画出来的每一段字（标签除外）在新页右大牌的数据里都取得到；目录行＝旧目录；
##   技能详情行＝旧技能列表（类型、未解锁）、说明进长说明卡；掉落行＝旧掉落（行尾掉率）；招式权重照旧显示；镶嵌页签、属性、效果、宝珠。
## - 左目录一屏 11 行（镶嵌多一行页签 10 行）；上下键换行、Q／E（人物）／左右（怪物）翻页、确定／取消层级同旧页。
## - 战斗里的「怪物信息」：同一版式的压暗弹层，目录只有本场敌人，确定不做事。
## 带 -- --out=<目录> 且有窗口时截图：每页 800×450＋1000×450（断言真尺寸）、各状态、字体 130%、旧画法对照。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const BATTLE_FIXTURE := "res://tests/fixtures/battle_enemy_book_oracle.json"

var results: Array = []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(900))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


func shot(name: String, sz := Vector2i(800, 450)) -> void:
	if not windowed():
		return
	var win := get_window()
	var old := win.size
	win.size = sz
	await frames(12)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	check("screenshot_size_" + name, img.get_size() == sz, [img.get_size(), sz])
	check("screenshot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK)
	win.size = old
	await frames(4)


func shots(name: String) -> void:
	if not windowed():
		return
	await shot(name + "_16x9", Vector2i(800, 450))
	await shot(name + "_20x9", Vector2i(1000, 450))


func act(page: Node, action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	page._unhandled_input(e)


func key(page: Node, k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	page._unhandled_input(e)


func _state(tianqi := true) -> XState:
	var s := XState.new_game_blank()
	s.party.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	if tianqi:
		s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian"}
	XState.current = s
	return s


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_card_p")
	get_viewport().gui_disable_input = windowed()
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XFontScale.set_value("global", 100)
	await _gate()
	await _actor()
	await _enemy_battle()
	await _enemy()
	await _inlay()
	await _font130()
	XUiSkin.motion_override = -1
	XFontScale.set_value("global", 100)
	XSkinBookPage.ENABLED = true
	XUiSkin.ENABLED = true
	XState.current = null
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.5, true, false, true).timeout
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 门控 ----

func _gate() -> void:
	for scen in ["switch_off", "skin_off", "xiyou"]:
		var s := _state(scen != "xiyou")
		XSkinBookPage.ENABLED = scen != "switch_off"
		XUiSkin.ENABLED = scen != "skin_off"
		XEnemyBook.add(s, 1)
		var a := XActorBook.new()
		add_child(a)
		var e := XEnemyBookPage.new()
		add_child(e)
		var b := XInlayBook.new()
		add_child(b)
		await frames(2)
		check("gate.%s.actor_old" % scen, a.skin == null and a.index_win.visible and a.status_win.visible and a.index_rows() == XListPager.rows_for(XActorBook.INDEX_ROWS, XActorBook.actor_count()))
		check("gate.%s.enemy_old" % scen, e.skin == null and e.index_win.visible and e.status_win.visible)
		check("gate.%s.inlay_old" % scen, b.skin == null and b.type_win.visible and b.mode == "type" and b.list.is_empty())
		if scen == "switch_off":   # 旧画法对照（旧页只按 1280×720 摆，只拍 16:9）
			e.visible = false   # R1 P1-3：只留人物旧页（选 1 号有名角色，免得右边一片空）
			b.visible = false
			a.select(XActorBook.index_ids().find(1))
			await frames(2)
			await shot("actor_old_compare_16x9")
			e.visible = true
			b.visible = true
			a.visible = false
			b.visible = false
			await shot("enemy_old_compare_16x9")
			e.visible = false
			b.visible = true
			b.ok()
			await shot("inlay_old_compare_16x9")
		for n in [a, e, b]:
			n.queue_free()
		await frames(2)
	XSkinBookPage.ENABLED = true
	XUiSkin.ENABLED = true
	var s2 := _state(true)
	check("gate.skin_on", XUiSkin.on() and XSkinBookPage.wanted(), s2.flags)


# ---- 人物图鉴 ----

## 旧页状态窗画的字（标签不算）
const ACTOR_LABELS := ["生命", "魔法", "物理攻击", "物理防御", "魔法攻击", "魔法防御", "敏捷", "幸运", "初始值", "品质 ", "最大进阶次数 ",
	"主动", "被动", "其他", "光环", "武器掌握", "防具掌握", "人物属性：", "／", "确认查看全部", ""]


func _flat(v, out: Array) -> void:
	if v is Dictionary:
		for k in v:
			_flat(v[k], out)
	elif v is Array:
		for x in v:
			_flat(x, out)
	elif v is String:
		out.append(v)


## 旧页备注的分段：每行按 n 字切
func _chunks(lines: Array, n: int) -> Array:
	var out := []
	for line in lines:
		var l := str(line)
		for k in ceili(l.length() / float(n)):
			out.append(l.substr(k * n, n))
	return out


func _actor_reachable(id: int) -> Array:
	var ops := XActorBook.status_ops(id, func(t, sz): return XActorBook.js_width(t, sz))
	var info := XSkinBookPage.actor_info(id)
	var have := []
	_flat(info, have)
	for c in info.get("cols", []):
		for sk in c.skills:
			have.append(str(sk.name))
	have.append("、".join(info.get("weapons", [])))
	have.append("、".join(info.get("armors", [])))
	var note_old := ""
	var note_new := "".join(info.get("note", []))
	var have2 := have.filter(func(h): return not (info.get("note", []) as Array).has(h))
	var chunks := _chunks(info.get("note", []), 32)
	var missing := []
	for o in ops:
		if o[0] != "t":
			continue
		var t := str(o[1])
		if t in ACTOR_LABELS or t.begins_with("六维："):
			continue
		if not chunks.is_empty() and t == str(chunks[0]):
			note_old += str(chunks.pop_front())   # 备注：旧页每 32 字一段，按次序拼起来要等于新页的整段
			continue
		if have2.any(func(h): return str(h) == t or str(h).contains(t)):
			continue
		missing.append(t)
	if note_old != note_new:
		missing.append(["note", note_old, note_new])
	return missing


func _actor() -> void:
	var s := _state(true)
	var a := XActorBook.new()
	add_child(a)
	await frames(3)
	if not check("actor.skin_built", a.skin != null):
		a.queue_free()
		return
	var sk := a.skin
	check("actor.opens_on_first_named", a.index == XActorBook.index_ids().find_custom(func(i): return int(i) > 0) and a.actor_id() > 0, a.index)
	check("actor.old_windows_hidden", not a.index_win.visible and not a.status_win.visible and not a.header_win.visible and not a.list_win.visible)
	check("actor.rows_11", sk.list.visible_rows() == 11 and a.index_rows() == 11, [sk.list.visible_rows(), a.index_rows()])
	var names := XActorBook.index_names()
	check("actor.index_rows_eq_old", sk.list.items.size() == names.size() and range(names.size()).all(func(i): return str(sk.list.items[i].text) == str(names[i])), [sk.list.items.size(), names.size()])
	check("actor.unknown_grey", range(names.size()).all(func(i): return (str(names[i]) != "？？？") or sk.list.items[i].color == XUiSkin.TEXT_3))
	# 对应表：几位有代表性的角色，旧页每段字新页都取得到
	var probe_ids := [1, 8, 9, 10]
	for id in [167, 168, 174, 179]:
		if XActorBook.named(id) and not XImportedBalance.is_hidden_actor(id):
			probe_ids.append(id)
	for id in probe_ids:
		var miss := _actor_reachable(id)
		check("actor.map.%d" % id, miss.is_empty(), miss)
		var info := XSkinBookPage.actor_info(id)
		var old_skills := XActorBook.book_skills(id, true).map(func(x): return int(x.id))
		var new_skills := []
		for c in info.cols:
			new_skills += c.skills.map(func(x): return int(x.id))
		new_skills.sort()
		old_skills.sort()
		check("actor.skills_all.%d" % id, new_skills == old_skills, [new_skills.size(), old_skills.size()])
		check("actor.advance.%d" % id, str(info.line).contains(XActorBook.advance_max(id)))
	# R1 P1-1：名字品质色走 XUiSkin.quality_color（不过 legacy_color）
	var col_ok := true
	for id in probe_ids:
		var inf := XSkinBookPage.actor_info(id)
		var q = XDB.rec("Actors", id).get("meta", {}).get("Actorquality", 0)
		var raw := int(float(str(q).strip_edges())) if str(q).strip_edges().is_valid_float() else 0
		if raw == 12:
			raw = 10
		var want := XUiSkin.quality_color(clampi(XActorBook.quality_grade(raw), 0, 6)) if raw != 0 else XUiSkin.TEXT
		if inf.name_color != want:
			col_ok = false
	check("actor.name_quality_color", col_ok)
	await shots("actor_book")
	# R1 P2-4：目录态选中行放大，进详情后目录复原、技能列表选中行放大
	check("actor.sel_scale_index", is_equal_approx(sk.list.sel_scale.k(sk.list.index), XUiSkin.SEL_SCALE), sk.list.sel_scale.k(sk.list.index))
	var home := XActorBook.index_ids().find(1)
	a.select(home)
	await frames(1)
	# 上下键：换行同旧页
	act(a, "ui_down")
	await frames(1)
	check("actor.down", a.index == home + 1 and sk.list.index == home + 1 and int(sk.info.id) == a.actor_id(), [a.index, sk.list.index])
	act(a, "ui_up")
	# Q／E 翻 11 行
	key(a, KEY_E)
	await frames(1)
	check("actor.page_e", a.index == home + 11 and sk.list.index == home + 11, [a.index, sk.list.index])
	key(a, KEY_Q)
	await frames(1)
	check("actor.page_q", a.index == home, a.index)
	# 「？？？」槽：右牌空、确定蜂鸣不进详情
	var unk := XActorBook.index_ids().find(0)
	if unk >= 0:
		a.select(unk)
		await frames(1)
		check("actor.unknown_card", not bool(sk.info.get("known", true)))
		await shots("actor_book_unknown")
		act(a, "ui_accept")
		check("actor.unknown_no_detail", a.mode == "index")
		a.select(home)
	# 技能详情
	act(a, "ui_accept")
	await frames(2)
	check("actor.detail_mode", a.mode == "skills" and sk.detail_list.visible and not sk.list.active)
	check("actor.detail_rows_eq_old", sk.detail_list.items.size() == a.skill_list.size() and range(a.skill_list.size()).all(func(i): return str(sk.detail_list.items[i].text) == str(a.skill_list[i].name)))
	check("actor.detail_type_tag", range(a.skill_list.size()).all(func(i): return str(sk.detail_list.items[i].tags[0].text) == XSkinBookPage.skill_type(a.actor_id(), a.skill_list[i])))
	check("actor.detail_card", sk.card.visible and str(sk.card.title) == str(a.skill_list[0].name), [sk.card.title])
	check("actor.old_help_hidden", not a.help_card.visible)
	act(a, "ui_down")
	await frames(1)
	check("actor.detail_down", a.skill_index == 1 and sk.detail_list.index == 1 and str(sk.card.title) == str(a.skill_list[1].name))
	await get_tree().create_timer(0.3, true, false, true).timeout
	check("actor.sel_scale_detail", is_equal_approx(sk.list.sel_scale.k(sk.list.index), 1.0) and is_equal_approx(sk.detail_list.sel_scale.k(sk.detail_list.index), XUiSkin.SEL_SCALE),
		[sk.list.sel_scale.k(sk.list.index), sk.detail_list.sel_scale.k(sk.detail_list.index)])
	await shots("actor_book_skills")
	act(a, "ui_cancel")
	await frames(1)
	check("actor.detail_cancel", a.mode == "index" and not sk.detail_list.visible and not sk.card.visible and sk.list.active)
	# 特殊角色：没学会的变灰、写「未解锁」；技能多的长名单（内部滚动）
	for id in [167, 179]:
		var slot := XActorBook.index_ids().find(id)
		if slot < 0:
			continue
		a.select(slot)
		await frames(1)
		if id == 167:
			await shots("actor_book_raven_long")
			check("actor.raven_skill_scroll_range", sk._skill_max >= 0.0)
			# R1 P1-2：牌头高按掌握那几行算，不裁字
			check("actor.raven_head_fits", sk.head_bottom >= sk.mastery_end - 0.5 and sk.mastery_end > 0.0, [sk.head_bottom, sk.mastery_end])
		act(a, "ui_accept")
		await frames(2)
		if a.skill_list.size() > sk.detail_list.visible_rows():   # R1 P2-2：技能详情 PageDown 照旧翻一页
			act(a, "ui_page_down")
			await frames(1)
			check("actor.detail_pagedown.%d" % id, a.skill_index == mini(sk.detail_list.visible_rows(), a.skill_list.size() - sk.detail_list.visible_rows()) and a.skill_index > 0 and sk.detail_list.index == a.skill_index, [a.skill_index, sk.detail_list.visible_rows()])
			act(a, "ui_page_up")
			await frames(1)
		var known := XActorBook.known_skill_ids(id)
		var ok_locked := true
		for i in a.skill_list.size():
			var locked: bool = not known.has(int(a.skill_list[i].id))
			if bool(sk.detail_list.items[i].get("disabled", false)) != locked or (locked and str(sk.detail_list.items[i].get("right", "")) != "未解锁"):
				ok_locked = false
		check("actor.locked_rows.%d" % id, ok_locked)
		if id == 179:   # 流萤天火轰击：长说明，收起／Y 展开
			var k := a.skill_list.map(func(x): return int(x.id)).find(10622)
			if k >= 0:
				a.select_skill(k)
				await frames(2)
				await shots("actor_book_skill_long")
				if sk.card.can_expand():
					sk.card.set_expanded(true)
					await frames(2)
					check("actor.card_expand", sk.card.expanded)
					await shot("actor_book_skill_expand_16x9")
					sk.card.set_expanded(false)
		act(a, "ui_cancel")
		await frames(1)
	# 取消离开
	var closed := [false]
	a.closed.connect(func(): closed[0] = true)
	act(a, "ui_cancel")
	check("actor.cancel_closes", closed[0])
	a.queue_free()
	await frames(2)


# ---- 怪物图鉴 ----

const ENEMY_LABELS := ["出没于：", "击败数", "弱化属性", "抗性属性", "命中率", "回避率", "暴击率", "暴击闪避率", "魔法闪避率", "魔法反射率", "反击率", ""]


func _enemy_reachable(e: XEnemy, all: bool) -> Array:
	var ops := XEnemyBookPage.status_ops(e, all)
	var info := XSkinBookPage.enemy_info(e, all)
	var have := []
	_flat(info, have)
	for mv in info.get("moves", []):
		have.append(str(mv.name) + "   " + str(mv.cond) + "  权重:" + str(mv.weight))
	if str(info.get("race", "")) != "":
		have.append("种族: " + str(info.race))
	var terms: Array = XDB.system().get("terms", {}).get("params", [])
	var missing := []
	var note_old := ""
	var note_new := "".join(info.get("note", []))
	var have2 := have.filter(func(h): return not (info.get("note", []) as Array).has(h))
	var chunks := _chunks(info.get("note", []), 15)
	var icons_old := []
	for o in ops:
		if o[0] == "i":
			if int(o[1]) > 0:
				icons_old.append(int(o[1]))
			continue
		if o[0] != "t":
			continue
		var t := str(o[1])
		if t in ENEMY_LABELS or t in terms:
			continue
		if not chunks.is_empty() and t == str(chunks[0]):
			note_old += str(chunks.pop_front())   # 备注：旧页每 15 字一段
			continue
		if have2.any(func(h): return str(h) == t or str(h).contains(t)):
			continue
		missing.append(t)
	var icons_new := []
	for x in info.get("weak", []) + info.get("resist", []):
		icons_new.append(int(x.icon))
	for mv in info.get("moves", []):
		if int(mv.icon) > 0:
			icons_new.append(int(mv.icon))
	for ic in icons_old:
		if not icons_new.has(ic):
			missing.append(["icon", ic])
	if note_old != note_new:
		missing.append(["note", note_old, note_new])
	return missing


func _enemy() -> void:
	var s := _state(true)
	var ids := XEnemyBook.ids()
	for i in mini(ids.size(), 40):
		if i % 3 != 2:
			XEnemyBook.add(s, int(ids[i]))
			XEnemyBook.add_defeat(s, int(ids[i]))
	XEnemyBookPage.last_index = 0
	var p := XEnemyBookPage.new()
	add_child(p)
	await frames(3)
	if not check("enemy.skin_built", p.skin != null):
		p.queue_free()
		return
	var sk := p.skin
	check("enemy.old_windows_hidden", not p.index_win.visible and not p.status_win.visible and not p.drop_win.visible)
	check("enemy.rows_11", sk.list.visible_rows() == 11 and p.index_rows() == 11)
	check("enemy.index_rows_eq_old", sk.list.items.size() == p.ids.size() and range(p.ids.size()).all(func(i): return str(sk.list.items[i].text) == p.index_name(i) and str(sk.list.items[i].num) == "%03d" % (i + 1)))
	# 对应表：前 40 只里已登记的逐只核
	var n_checked := 0
	var all_miss := []
	for i in mini(p.ids.size(), 40):
		var id := int(p.ids[i])
		if not XEnemyBook.registered(s, id):
			continue
		var miss := _enemy_reachable(p.enemy(id), true)
		if not miss.is_empty():
			all_miss.append([id, miss])
		n_checked += 1
	check("enemy.map_all_registered", n_checked > 10 and all_miss.is_empty(), [n_checked, all_miss.slice(0, 3)])
	# 招式权重照旧显示：「权重 N」＝行动表 rating
	var e0 := p.enemy(int(p.ids[0]))
	var info0 := XSkinBookPage.enemy_info(e0, true)
	var acts: Array = e0.data().get("actions", [])
	var ratings := []
	for k in mini(10, acts.size()):
		ratings.append(XEnemyBookPage.js_num(float(acts[k].get("rating", 0))))
	var ws: Array = info0.moves.map(func(m): return str(m.weight))
	ws.sort()
	ratings.sort()
	check("enemy.weights_shown", ws == ratings and ws.size() > 0, [ws, ratings])
	# R1 P1-1：难度色照旧（不过 legacy_color）
	check("enemy.name_difficulty_color", info0.name_color == XEnemy.name_color(e0.display_name(), XEnemyBookPage._difficulty(), XUiSkin.TEXT))
	# R1 P2-1：招式多的那只，十条都画得到（压行距，还放不下就能滚到）
	var most := 0
	for i in mini(p.ids.size(), 40):
		var id2 := int(p.ids[i])
		if XEnemyBook.registered(s, id2) and (p.enemy(id2).data().get("actions", []) as Array).size() > (p.enemy(int(p.ids[most])).data().get("actions", []) as Array).size():
			most = i
	p.select(most)
	await frames(2)
	var nm: int = (sk.info.moves as Array).size()
	check("enemy.moves_all_reachable", nm > 0 and nm * sk.moves_row_h <= sk._skill_rect.size.y + sk._skill_max + 0.5, [nm, sk.moves_row_h, sk._skill_rect.size.y, sk._skill_max])
	await shots("enemy_book_many_moves")
	if sk._skill_max > 0.0:
		sk.scroll_skills(9999.0)
		check("enemy.moves_scroll_end", is_equal_approx(sk.skill_scroll, sk._skill_max))
	p.select(0)
	await frames(1)
	await shots("enemy_book")
	# 左右翻一页（11 行）
	act(p, "ui_right")
	await frames(1)
	check("enemy.right_page", p.index == 11 and sk.list.index == 11, p.index)
	act(p, "ui_left")
	await frames(1)
	check("enemy.left_page", p.index == 0)
	# 掉落
	var with_drops := -1
	for i in mini(p.ids.size(), 40):
		if XEnemyBook.registered(s, int(p.ids[i])) and not XEnemyBookPage.drop_rows(p.enemy(int(p.ids[i]))).is_empty():
			with_drops = i
			break
	if check("enemy.has_drop_case", with_drops >= 0):
		p.select(with_drops)
		act(p, "ui_accept")
		await frames(2)
		check("enemy.drops_mode", p.mode == "drops" and sk.detail_list.visible and sk.card.visible)
		var ok_rows := true
		for i in p.drop_list.size():
			var r: Dictionary = p.drop_list[i]
			var row: Dictionary = sk.detail_list.items[i]
			var full := str(row.text) + "   " + str(row.right) + str(row.get("sub", ""))
			if full != str(r.item.name):
				ok_rows = false
		check("enemy.drop_rows_eq_old", ok_rows and sk.detail_list.items.size() == p.drop_list.size())
		check("enemy.drop_card_title", str(sk.card.title).contains(str(p.drop_list[0].base.name)), [sk.card.title])
		await shots("enemy_book_drops")
		check("enemy.drops_hint", sk._hint_list == [["上下", "选掉落"], ["取消", "回目录"]])
		act(p, "ui_accept")   # 确定回目录（照旧）
		check("enemy.drops_ok_back", p.mode == "index" and not sk.detail_list.visible)
	# 没登记的：右牌「还没遇到过」，确定不进掉落
	var unreg := -1
	for i in p.ids.size():
		if not XEnemyBook.registered(s, int(p.ids[i])):
			unreg = i
			break
	if unreg >= 0:
		p.select(unreg)
		await frames(1)
		check("enemy.unregistered_card", not bool(sk.info.known) and sk.list.items[unreg].color == XUiSkin.TEXT_3)
		await shots("enemy_book_unregistered")
		act(p, "ui_accept")
		check("enemy.unregistered_no_drops", p.mode == "index")
		p.select(0)
	var closed := [false]
	p.closed.connect(func(): closed[0] = true)
	act(p, "ui_cancel")
	check("enemy.cancel_closes", closed[0])
	p.queue_free()
	await frames(2)


func _enemy_battle() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(BATTLE_FIXTURE))
	if not check("battle.fixture", ref is Dictionary and ref.has("troop")):
		return
	var s := _state(true)
	s.difficulty = int(ref.difficulty)
	XEnemyBook.on_map_setup(s, XDB.map(5))
	XEnemy.force_roll = 100.0
	var logic := XBattleLogic.new()
	logic.setup(int(ref.troop), s)
	XEnemy.force_roll = -1.0
	var p := XEnemyBookPage.new()
	p.setup_battle(logic.enemies)
	add_child(p)
	XSkinLayout.request_wide(p, true)   # 战斗场景本来就铺满（4A）；单独建弹层时替它要一次
	await frames(3)
	if not check("battle.skin_built", p.skin != null and p.skin.in_battle and p.skin.dim != null and p.skin.backdrop == null):
		p.queue_free()
		return
	var sk := p.skin
	check("battle.title", sk.page_title() == "怪物信息")
	check("battle.rows_only_battle", sk.list.items.size() == p.ids.size() and not sk.list.items[0].has("num"))
	check("battle.unregistered_values_shown", bool(sk.info.known) and not bool(sk.info.hide))
	var miss := _enemy_reachable(p.enemy(int(p.ids[0])), false)
	check("battle.map", miss.is_empty(), miss)
	XEnemyBookPage.BATTLE_SHOW_UNREGISTERED = false
	var hidden := XSkinBookPage.enemy_info(p.enemy(int(p.ids[0])), false)
	XEnemyBookPage.BATTLE_SHOW_UNREGISTERED = true
	check("battle.rollback_hide", bool(hidden.hide) and hidden.params.all(func(x): return x[1] == XEnemyBookPage.UNKNOWN_DATA))
	await shots("enemy_battle_info")
	act(p, "ui_accept")
	check("battle.ok_noop", p.mode == "index")
	var closed := [false]
	p.closed.connect(func(): closed[0] = true)
	act(p, "ui_cancel")
	check("battle.cancel_closes", closed[0])
	p.queue_free()
	await frames(2)


# ---- 镶嵌图鉴 ----

func _inlay_reachable(r: Dictionary, k: int) -> Array:
	var ops := XInlayBook.status_ops(r, k)
	var info := XSkinBookPage.inlay_info(r, k)
	var have := []
	_flat(info, have)
	var eff := ""
	for sp in info.get("effects", []):
		for part in sp:
			eff += str(part[0])
	var skip := ["武器镶嵌属性:", "防具镶嵌属性:", "武器镶嵌效果:", "防具镶嵌效果:", "需求武器镶嵌类型:", "需求防具镶嵌类型:", "镶嵌顺序:", "镶嵌顺序为从左到右显示", ""] + XInlayBook.ATTRS
	var chars := ""
	var missing := []
	for o in ops:
		if o[0] != "t":
			continue
		var t := str(o[1])
		if t in skip:
			continue
		if t.length() == 1 and float(o[4]) == XInlayBook._w(t) * 2.0:   # 效果的逐字操作
			chars += t
			continue
		if not have.any(func(h): return str(h) == t or str(h).contains(t)):
			missing.append(t)
	if chars.replace(" ", "") != eff.replace(" ", ""):
		missing.append(["effect", chars, eff])
	return missing


func _inlay() -> void:
	_state(true)
	XSkinNoticeLane.reset()   # R1 P3-2：怪物页点未登记弹的「未解锁」别留到镶嵌图里
	await frames(1)
	var b := XInlayBook.new()
	add_child(b)
	await frames(3)
	if not check("inlay.skin_built", b.skin != null):
		b.queue_free()
		return
	var sk := b.skin
	check("inlay.enter_index_weapon", b.mode == "index" and b.type_index == 0 and b.index == (0 if not b.lists[0].is_empty() else -1) and sk.inner_tabs.index == 0)
	check("inlay.rows_10", sk.list.visible_rows() == 10)
	check("inlay.rows_eq_old", sk.list.items.size() == b.lists[0].size() and range(b.lists[0].size()).all(func(i): return str(sk.list.items[i].text) == str(b.lists[0][i].name)))
	var all_miss := []
	for kk in 2:
		for r in b.lists[kk]:
			var m := _inlay_reachable(r, kk)
			if not m.is_empty():
				all_miss.append([r.get("name", ""), m])
	check("inlay.map_all", all_miss.is_empty(), all_miss.slice(0, 3))
	await shots("inlay_book")
	key(b, KEY_E)
	await frames(1)
	check("inlay.tab_e_armor", b.type_index == 1 and b.mode == "index" and sk.inner_tabs.index == 1 and sk.list.items.size() == b.lists[1].size())
	await shots("inlay_book_armor")
	key(b, KEY_Q)
	await frames(1)
	check("inlay.tab_q_weapon", b.type_index == 0 and sk.list.items.size() == b.lists[0].size())
	act(b, "ui_down")
	check("inlay.down", b.index == 1 and sk.list.index == 1)
	# R1 P2-2：PageDown／右键翻目录一页（不切页签）；Q／E 才切
	if b.lists[0].size() > sk.list.visible_rows():
		act(b, "ui_page_down")
		await frames(1)
		check("inlay.pagedown_pages", b.type_index == 0 and b.index == 1 + sk.list.visible_rows() and sk.list.index == b.index, [b.type_index, b.index])
		act(b, "ui_page_up")
		await frames(1)
		act(b, "ui_right")
		await frames(1)
		check("inlay.right_pages", b.type_index == 0 and b.index == 1 + sk.list.visible_rows(), [b.type_index, b.index])
		act(b, "ui_left")
		await frames(1)
		check("inlay.left_back", b.index == 1, b.index)
	# 空页签：一句居中、右牌不画
	var keep: Array = b.lists[1]
	b.lists[1] = []
	key(b, KEY_E)
	await frames(1)
	check("inlay.empty", sk.list.items.is_empty() and sk.info.is_empty() and sk.list.empty_text == XSkinBookPage.T_INLAY_EMPTY)
	await shot("inlay_book_empty_16x9")
	b.lists[1] = keep
	key(b, KEY_Q)
	var closed := [false]
	b.closed.connect(func(): closed[0] = true)
	act(b, "ui_cancel")
	check("inlay.cancel_closes_directly", closed[0])
	b.queue_free()
	await frames(2)


# ---- 字体 130% ----

func _font130() -> void:
	var s := _state(true)
	for i in 30:
		XEnemyBook.add(s, i + 1)
	XFontScale.set_value("global", 130)
	check("font130.mult", XUiSkin.font_mult() >= 1.29)
	var a := XActorBook.new()
	add_child(a)
	await frames(3)
	check("font130.actor_rows_11", a.skin != null and a.skin.list.visible_rows() == 11)
	await shots("actor_book_font130")
	a.queue_free()
	XEnemyBookPage.last_index = 0
	var e := XEnemyBookPage.new()
	add_child(e)
	await frames(3)
	await shots("enemy_book_font130")
	e.queue_free()
	var b := XInlayBook.new()
	add_child(b)
	await frames(3)
	await shots("inlay_book_font130")
	b.queue_free()
	XFontScale.set_value("global", 100)
	await frames(2)
