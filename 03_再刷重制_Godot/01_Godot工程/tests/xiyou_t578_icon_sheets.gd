extends Node
## 【cc·未经审查】T578 西游档技能页仍卡（安卓 v0.04.07，玩家存档 12）：XUI.KEEP_ICON_SHEETS（O-待定）图标分图常驻。
## XMVCanvas 每次重画先清 _keep，IconSet 分图最后一个引用跟着放掉，XUI.icon_texture 的 load() 又把整张图重解一遍。
## 断言：开关两态取到的图块（分图路径、区域、像素）逐个相同；技能页移动、切类型、翻页、滚轮，战斗技能窗移动、翻页，
## 每一步画出来的图标（XMVCanvas._keep 里的图块）两态逐个相同；关着时不攥任何分图（同原来每次 load），开着时最多攥 4 张、只攥 IconSet。
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail).left(800))


func _set_keep(on: bool) -> void:
	if on:
		XUI.KEEP_ICON_SHEETS = true
	else:  # 回退支（回退开关覆盖.py 认字面量）
		XUI.KEEP_ICON_SHEETS = false
	XUI._icon_sheets.clear()


## 一个图块的指纹：分图路径、区域、区域像素的哈希（无头渲染取不到像素时记 "noimg"，两态照样比路径和区域）
func _tile_sig(t: Texture2D) -> Array:
	if t == null:
		return ["null"]
	if t is AtlasTexture:
		var a := t as AtlasTexture
		var img: Image = a.atlas.get_image() if a.atlas != null else null
		var px := "noimg"
		if img != null and not img.is_empty():
			px = str(hash(img.get_region(Rect2i(a.region)).get_data()))
		return [a.atlas.resource_path if a.atlas != null else "", a.region, px]
	return [t.resource_path, t.get_size()]


func _canvas_sig(c: XMVCanvas) -> Array:
	return c._keep.map(func(t): return _tile_sig(t))


func _frame() -> void:
	await get_tree().process_frame


func _passive_ids(n: int) -> Array:
	var ids := []
	var rows: Array = XDB.table("Skills")
	for i in range(1, rows.size()):
		var r = rows[i]
		if r is Dictionary and int(r.get("stypeId", 0)) == 4 and str(r.get("name", "")) != "" and int(r.get("iconIndex", 0)) > 0 and not XTianqiSkills.is_shell(i):
			ids.append(i)
	var out := []
	var k := 0
	while out.size() < n and k < ids.size() * 3:
		var id: int = ids[(k * 7919) % ids.size()]
		k += 1
		if not out.has(id):
			out.append(id)
	return out


func _state() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var picks := _passive_ids(60)
	for id in s.party:
		var a := s.actor(id)
		for sid in picks:
			a.learn_skill(sid)
		a.change_level(80)
		a.refresh_passive()
		a.recover_all()
	return s


# ---- 1. 直接取图：两态图块相同、关着不攥、开着只攥 IconSet ----
func _direct() -> void:
	var idx := [1, 100, 1599, 1600, 3199, 3200, 4800, 6399]
	var sigs := {}
	for on in [false, true]:
		_set_keep(on)
		var row := []
		for i in idx:
			row.append(_tile_sig(XUI.icon_texture(i)))
		sigs[on] = row
		if on:
			var a1: AtlasTexture = XUI.icon_texture(100)
			var a2: AtlasTexture = XUI.icon_texture(101)
			check("direct.on_same_sheet", a1 != null and a2 != null and a1.atlas == a2.atlas)
			var ok_keys := XUI._icon_sheets.size() > 0 and XUI._icon_sheets.size() <= 4
			for p in XUI._icon_sheets:
				ok_keys = ok_keys and str(p).get_file().begins_with("IconSet_")
			check("direct.on_holds_iconsets_only", ok_keys, XUI._icon_sheets.keys())
		else:
			check("direct.off_holds_nothing", XUI._icon_sheets.is_empty(), XUI._icon_sheets.keys())
	check("direct.tiles_same", sigs[false] == sigs[true], [sigs[false].slice(0, 2), sigs[true].slice(0, 2)])
	check("direct.tiles_nonnull", sigs[true].all(func(r): return r[0] != "null"), sigs[true])
	check("direct.zero_null", XUI.icon_texture(0) == null)


# ---- 2. 技能页：移动、切类型、翻页、滚轮，每一步画出来的图标两态相同 ----
func _skill_page_run(on: bool) -> Array:
	_set_keep(on)
	_state()
	var page := XSkillScene.new()
	page.actor_index = 0
	add_child(page)
	var steps := []
	var snap := func(label: String):
		steps.append([label, _canvas_sig(page.list_win.canvas), _canvas_sig(page.type_win.canvas), _canvas_sig(page.status_win.canvas)])
	await _frame()
	await _frame()
	snap.call("open")
	var types := page.types()
	for ti in range(1, types.size()):
		page._move(1, false, false)
		await _frame()
		snap.call("type%d" % ti)
	var pi := maxi(types.find(4), 0)
	page.type_index = pi
	page._refresh()
	await _frame()
	snap.call("to_passive")
	page.mode = "list"
	page.index = 0
	page._refresh()
	await _frame()
	snap.call("enter_list")
	for i in 6:
		page._move(1, false, false)
		await _frame()
		snap.call("move%d" % i)
	for i in 2:
		page._page(1)
		await _frame()
		snap.call("page%d" % i)
	page._wheel(1)
	await _frame()
	snap.call("wheel")
	page.change_actor(1)
	await _frame()
	snap.call("change_actor")
	page.queue_free()
	await _frame()
	return steps


func _skill_page() -> void:
	var off: Array = await _skill_page_run(false)
	var held_off := XUI._icon_sheets.size()
	var on: Array = await _skill_page_run(true)
	check("page.off_holds_nothing", held_off == 0, held_off)
	check("page.steps_same", off == on, _first_diff(off, on))
	var icons := 0
	for st in on:
		icons += (st[1] as Array).size()
	check("page.icons_drawn", icons > 20, icons)
	print("T578 page steps=%d list_icons=%d sheets_held=%d" % [on.size(), icons, XUI._icon_sheets.size()])


# ---- 3. 战斗技能窗（XBattleList）：移动、翻页，两态相同 ----
func _battle_list_run(on: bool) -> Array:
	_set_keep(on)
	var s := _state()
	var a := s.actor(s.party[0])
	var entries := []
	for sk in a.skills():
		entries.append({"text": str(sk.get("name", "")), "icon": int(sk.get("iconIndex", 0)), "costs": [{"text": "12", "icon": 100}], "enabled": true})
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	var w := XBattleList.create(host, entries, 600)
	var steps := []
	await _frame()
	steps.append(["open", _canvas_sig(w.canvas)])
	for i in 5:
		w.select(w.index + 1)
		await _frame()
		steps.append(["move%d" % i, _canvas_sig(w.canvas)])
	w.page(1)
	await _frame()
	steps.append(["page", _canvas_sig(w.canvas)])
	host.queue_free()
	await _frame()
	return steps


func _battle_list() -> void:
	var off: Array = await _battle_list_run(false)
	var on: Array = await _battle_list_run(true)
	check("battle_list.steps_same", off == on, _first_diff(off, on))
	check("battle_list.icons_drawn", (on[0][1] as Array).size() > 3, on[0])


func _first_diff(x: Array, y: Array):
	for i in mini(x.size(), y.size()):
		if x[i] != y[i]:
			return [i, x[i], y[i]]
	return [x.size(), y.size()]


func _run() -> void:
	XSave.dir_override = "user://t578_test"
	XConfig.path_override = XSave.dir().path_join("options.json")
	var keep0 := XUI.KEEP_ICON_SHEETS
	_direct()
	await _skill_page()
	await _battle_list()
	XUI.KEEP_ICON_SHEETS = keep0
	XUI._icon_sheets.clear()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
