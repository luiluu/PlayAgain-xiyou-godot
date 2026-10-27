extends Node
## 人物图鉴（XActorBook）：对照冻结 v0.28 浏览器参照 tests/fixtures/actor_book_oracle.json（新局队伍 1/8/9/10），
## 逐个目录槽比对目录名、状态窗全部 drawText/drawIcon（文字、字号、颜色逐条相等，坐标与宽差 ≤ POS_TOL）、SV 图名，
## 技能详情的抬头、列表首屏与全部技能 ID；再走一遍操作（空槽蜂鸣不进详情、进详情说明卡宽 727 固定在 (545,8)、取消返回且卡隐藏、
## 再取消关闭）与主菜单入口（「人物图鉴」可选，确定后预约公共事件 3，其脚本为 SceneManager.push(Scene_ActorBook)）。
## 窗口模式加 -- --out=<目录> 存对照截图。

const FIXTURE := "res://tests/fixtures/actor_book_oracle.json"
## 坐标与宽的容差（XActorBook.js_width 与浏览器 measureText 一致到 0.01）
const POS_TOL := 0.05
## 不画立绘的角色：切片外的没导出 SV 图；168、173～177 在原版由运行模块换成多帧图（未移植，XActorBook.sprite_path）。
## 160（mzzd3 已随别处导出）、167 渡鸦、172 宿傩原版画的就是数据库 battlerName，照常对照。
const NO_SPRITE := [108, 143, 144, 145, 157, 168, 170, 171, 173, 174, 175, 176, 177]

var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


static func measure(s: String, size: int) -> float:
	return XActorBook.js_width(s, size)


## 参照里不画的：drawText(undefined)（MV Bitmap.drawText 跳过）、专属角色的自带图标（不在 IconSet，参照里来源图为空）；
## Godot 侧去掉 IconSet 里没有的图标（XUI.icon_texture 为空，不画）
static func drawn_ref(ops: Array) -> Array:
	return ops.filter(func(o): return not (o.size() == 3 and not (o[0] is float or o[0] is int)) and str(o[0]) != "undefined")


static func drawn_got(ops: Array) -> Array:
	return ops.filter(func(o): return o.size() != 3 or XUI.icon_texture(int(o[0])) != null)


## 167 起的专属角色（含切片里的 178 哈基米）技能图标由各运行模块改画自带图，浏览器截取时异步图还没到，参照里缺；这些角色只比文字
static func no_icons(ops: Array) -> Array:
	return ops.filter(func(o): return o.size() != 3)


## Godot 操作 → 参照形（文字 [文字,x,y,宽,字号,颜色hex(,对齐)]、图标 [图标号,x,y]）
static func to_ref(ops: Array) -> Array:
	var out := []
	for o in ops:
		if o[0] == "i":
			out.append([o[1], o[2], o[3]])
		else:
			var r := [o[1], o[2], o[3], o[4], o[7], (o[8] as Color).to_html(false)]
			if o[6] != "left":
				r.append(o[6])
			out.append(r)
	return out


## 两组操作的第一处不同（没有不同返回 ""）
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
					bad = bad or str(g[k]) != w[k]
				elif k == 0 and w.size() == 3:
					bad = bad or int(g[k]) != int(w[k])
				elif k == 4 and w.size() >= 6:
					bad = bad or int(g[k]) != int(w[k])
				else:
					bad = bad or absf(float(g[k]) - float(w[k])) > POS_TOL
		if bad:
			return "#%d got %s want %s" % [i, JSON.stringify(g), JSON.stringify(w)]
	return ""


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("fixture_loaded", ref is Dictionary and ref.get("actors", {}).size() == 179, FIXTURE):
		get_tree().quit.call_deferred(1)
		return
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	check("index_names", XActorBook.index_names() == ref.index, XActorBook.index_names().slice(0, 5))
	var bad := {"status": [], "sprite": [], "header": [], "list": [], "skills": []}
	for key in ref.actors:
		var id := int(key)
		var a: Dictionary = ref.actors[key]
		var got := drawn_got(to_ref(XActorBook.status_ops(id, measure)))
		var d := diff(no_icons(got), no_icons(drawn_ref(a.status))) if id >= 167 else diff(got, drawn_ref(a.status))
		if d != "":
			bad.status.append("%d %s" % [id, d])
		var p := XActorBook.sprite_path(id)
		if id in NO_SPRITE:
			if p != "":
				bad.sprite.append("%d 切片外角色不该画 %s" % [id, p])
		elif str(a.get("sprite", "")) != (str(XDB.rec("Actors", id).get("battlerName", "")) if p != "" else ""):
			bad.sprite.append("%d %s 图 %s" % [id, a.get("sprite", ""), p])
		if not a.has("header"):
			continue
		d = diff(to_ref(XActorBook.header_ops(id)), a.header)
		if d != "":
			bad.header.append("%d %s" % [id, d])
		var skills: Array = XActorBook.book_skills(id, false)
		var ids: Array = skills.map(func(x): return int(x.id))
		if ids != a.skills.map(func(x): return int(x)):
			bad.skills.append("%d got %s want %s" % [id, ids, a.skills])
		var ops := []
		for i in mini(XActorBook.LIST_ROWS, skills.size()):
			ops += XActorBook.list_row_ops(id, skills[i], i * XActorBook.LH, measure)
		d = diff(no_icons(drawn_got(to_ref(ops))), no_icons(drawn_ref(a.list))) if id >= 167 else diff(drawn_got(to_ref(ops)), drawn_ref(a.list))
		if d != "":
			bad.list.append("%d %s" % [id, d])
	for k in bad:
		check("oracle_" + k, bad[k].is_empty(), {"count": bad[k].size(), "first": bad[k].slice(0, 6)})
	await _flow(ref)
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
	var book := XActorBook.new()
	add_child(book)
	await frames()
	var geo: Dictionary = ref.geo
	var rect := func(w: Control) -> Array: return [w.position.x, w.position.y, w.size.x, w.size.y]
	check("geometry", rect.call(book.index_win) == geo.index.slice(0, 4).map(func(x): return float(x))
		and rect.call(book.status_win) == geo.status.map(func(x): return float(x))
		and rect.call(book.header_win) == geo.header.map(func(x): return float(x))
		and rect.call(book.list_win) == geo.list.map(func(x): return float(x))
		and book.index_win.opacity == int(geo.opacity[0]),
		[rect.call(book.index_win), rect.call(book.status_win), rect.call(book.header_win), rect.call(book.list_win)])
	# 0 号槽：状态窗空、确定蜂鸣不进详情
	check("slot0_blank", book.index == 0 and book._status_ops.is_empty() and book._sprite_tex == null)
	book.ok()
	check("slot0_ok_buzzer", book.mode == "index" and not book.header_win.visible)
	book._move(1, true)
	await frames()
	check("select_1", book.index == 1 and not book._status_ops.is_empty() and book._sprite_tex != null)
	await shot("actor_book_1")
	book.ok()
	await frames()
	check("details_open", book.mode == "skills" and book.list_win.visible and book.header_win.visible
		and not book.index_win.visible and not book.status_win.visible and book.skill_index == 0)
	check("help_card", book.help_card.visible and book.help_card.position == Vector2(ref.geo.help[0], ref.geo.help[1])
		and book.help_card.size.x == XActorBook.HELP_WIDTH and int(book.help_card.rows.size()) > 0, [book.help_card.position, book.help_card.size])
	# Codex_ActorBookSkillDetails 给说明卡的是技能浅拷贝（isSkill 为假）：伤害技能也不插「伤害属性」行
	var dmg_i := -1
	for k in book.skill_list.size():
		if [1, 2, 5, 6].has(int(book.skill_list[k].get("damage", {}).get("type", 0))):
			dmg_i = k
			break
	var has_attr := func(rows: Array) -> bool:
		return rows.any(func(r): return str(r[0]).contains("伤害属性："))
	if dmg_i >= 0:
		book.select_skill(dmg_i)
		await frames()
	var dmg_skill: Dictionary = book.skill_list[dmg_i] if dmg_i >= 0 else {}
	check("help_skill_copy_no_element_row", dmg_i >= 0 and book.help_card.skill_copy and not has_attr.call(book.help_card.rows)
		and has_attr.call(XHelpCard.content(dmg_skill, "skill")), [dmg_i, book.help_card.rows.slice(0, 4)])
	book.select_skill(0)
	await frames()
	await shot("actor_book_1_skills")
	book._move(1, true)
	check("details_move", book.skill_index == 1)
	book.cancel()
	await frames()
	check("details_back", book.mode == "index" and book.index_win.visible and book.status_win.visible
		and not book.list_win.visible and not book.help_card.visible and book.index == 1)
	# 目录首按上循环到最后一槽；翻页 19 行
	book._move(-1, true)
	book._move(-1, true)
	check("index_wrap", book.index == XActorBook.actor_count() - 1 and book.top == XActorBook.actor_count() - XActorBook.INDEX_ROWS, [book.index, book.top])
	book._move(1, true)
	book._page(1)
	check("index_page", book.index == XActorBook.INDEX_ROWS and book.top == XActorBook.INDEX_ROWS, [book.index, book.top])
	var closed := [false]
	book.closed.connect(func(): closed[0] = true)
	book.cancel()
	check("cancel_closes", closed[0])
	book.queue_free()
	await frames()


func _menu_entry() -> void:
	var menu := XMenu.new()
	add_child(menu)
	await frames()
	var i := menu.command_names().find("人物图鉴")
	check("menu_enabled", i >= 0 and menu.command_enabled(i))
	menu._cmd_index = i
	menu._ok()
	check("menu_reserves_ce3", menu.event_state.peek_common_event() == 3, menu.event_state.peek_common_event())
	menu.event_state.clear_common_event()
	var ce := XDB.rec("CommonEvents", 3)
	check("ce3_script", ce.get("list", []).size() > 0 and str(ce.list[0].parameters[0]) == "SceneManager.push(Scene_ActorBook)", ce.get("list", []))
	menu.queue_free()
	await frames()
