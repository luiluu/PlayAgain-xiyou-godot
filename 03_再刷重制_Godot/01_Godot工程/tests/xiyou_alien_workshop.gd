extends Node
## 异化工坊（XAlienation＋XAlienWorkshop）：按正式 alien_workshop_probe.cjs 的记录逐项比对——alienation.json 与原版配置、词条说明一致；
## 合成／异化／重抽／待选／分解的返回、背包、账本与装备标记；工坊 5 条点选路线每一步的叠加层节点树（标签、class、文字、按钮可否点）、
## 提示、结束时的背包与账本。异化装备的本体名字与属性照参照抄（独立装备的随机前后缀不在本参照范围）。另查主菜单入口与窗口能打开。

var results := []
var out_dir := ""
const ORACLE := "res://modes/xiyou/generated/oracle/alien_workshop.json"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


## 窗口模式加 -- --out=<目录> 存对照截图
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


static func norm(v):
	if v is int or v is float:
		return float(v)
	if v is Array:
		return v.map(func(x): return norm(x))
	if v is Dictionary:
		var out := {}
		for k in v:
			if str(k) != "id":   # 待选里的装备 ID：原版是独立装备编号，这里是实例 ID
				out[str(k)] = norm(v[k])
		return out
	return v


## 两份节点树第一处不同（报错用）
static func first_diff(a, b) -> Array:
	if not (a is Array and b is Array):
		return [a, b]
	for i in range(maxi(a.size(), b.size())):
		var x = a[i] if i < a.size() else null
		var y = b[i] if i < b.size() else null
		if norm(x) != norm(y):
			return [i, x, y]
	return []


func _state() -> XState:
	var s := XState.new_game_blank()
	s.items = {}
	s.gear = []
	for id in [1, 8]:
		s.add_actor(id)
	XAlienation.force_roll = 0.5
	return s


func _bag(s: XState) -> Dictionary:
	var bag := {}
	for k in s.items:
		if int(s.items[k]) > 0:
			bag[str(k)] = float(s.items[k])
	return bag


func _gear(s: XState) -> Array:
	return XAlienation.owned(s).filter(func(e): return not XAlienation.mark(e).is_empty()).map(func(i): return {"name": i.name, "kind": XAlienation.kind(i), "base": float(i.base), "mark": norm(i.alien)})


## 照参照行新建一件异化装备放进背包：本体名字与属性抄参照
func _make(s: XState, row: Dictionary) -> Dictionary:
	var r := XAlienation.create(s, str(row.kind), int(row.base), str(row.origin), str(row.affix))
	var i: Dictionary = r.ok
	i.params = row.params.duplicate()
	i.alien.plainName = str(row.plainName)
	i.alien.lastName = str(XAlienation.affix(str(row.affix)).name) + "·" + str(row.plainName)
	i.name = str(row.name)
	s.gear.append(i)
	return i


func _run() -> void:
	var o = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if not check("oracle_loaded", o is Dictionary, ORACLE):
		_finish()
		return
	_config(o.config)
	_calls(o.calls)
	for p in o.pages:
		await _flow(p)
	await _menu_entry()
	_finish()


func _config(c: Dictionary) -> void:
	var g := XAlienation.config()
	check("config_ids", norm(g.ids) == norm(c.ids) and float(g.energyCost) == float(c.energyCost), [g.ids, c.ids])
	check("config_affixes", g.affixes == c.affixes, [g.affixes.size(), c.affixes.size()])
	check("config_pools", g.pools == c.pools and g.bossOnly == c.bossOnly and g.boundKeys == c.boundKeys and g.skillKeys == c.skillKeys)
	check("config_mob_maps", norm(g.mobMaps) == norm(c.mobSources.map(func(x): return x.mapId)))
	var names := []
	for id in g.mobMaps:
		names.append(str(XDB.rec("MapInfos", int(id)).get("name", "")))
	check("config_map_names", names == c.mapNames, [names, c.mapNames])


func _calls(rows: Array) -> void:
	var s := _state()
	var by := {}
	for r in rows:
		by[str(r.step)] = r
	var made: Array = by.made.items
	var E := XAlienation.energy_id()
	var S := XAlienation.stone_id()
	var got := {}
	got["craft-short"] = {"r": XAlienation.craft(s, 1)}
	s.gain_item(E, 45)
	got["craft-2"] = {"r": XAlienation.craft(s, 2), "bag": _bag(s)}
	got["craft-1"] = {"r": XAlienation.craft(s, 1)}
	var a := _make(s, made[0])
	var b := _make(s, made[1])
	check("call_made_details", XAlienation.details(s, a) == by.made.details[0] and XAlienation.details(s, b) == by.made.details[1], [XAlienation.details(s, a), by.made.details])
	check("call_made_pool", a.alien.pool == by.made.pool[0] and b.alien.pool == by.made.pool[1], [a.alien.pool, by.made.pool])
	check("call_made_ledger", norm(XAlienation.ledger(s)) == norm(by.made.ledger), [XAlienation.ledger(s), by.made.ledger])
	got["attach-bad"] = {"r": XAlienation.create(s, "w", 1042, "mob", "pest")}
	got["reroll"] = {"r": XAlienation.reroll(s, a), "bag": _bag(s), "ledger": XAlienation.ledger(s).duplicate(true)}
	got["reroll-pending"] = {"r": XAlienation.reroll(s, b)}
	got["craft-pending"] = {"r": XAlienation.craft(s, 1)}
	got["resolve-new"] = {"r": XAlienation.resolve(s, true), "gear": _gear(s), "ledger": XAlienation.ledger(s).duplicate(true)}
	got["reroll-no-stone"] = {"r": XAlienation.reroll(s, a)}
	got["dismantle-boss"] = {"r": XAlienation.dismantle(s, b), "bag": _bag(s), "gear": _gear(s)}
	s.gain_item(S, 1)
	got["reroll-2"] = {"r": XAlienation.reroll(s, a), "ledger": XAlienation.ledger(s).duplicate(true)}
	got["resolve-old"] = {"r": XAlienation.resolve(s, false), "gear": _gear(s), "ledger": XAlienation.ledger(s).duplicate(true)}
	var c := _make(s, {"kind": "w", "base": 1042, "origin": "mob", "affix": "mimic", "params": [], "plainName": "c", "name": "百相·c[锁定]"})
	got["locked"] = {"canOperate": XAlienation.can_operate(s, c), "locked": XAlienation.locked(c), "r": XAlienation.dismantle(s, c)}
	var d := _make(s, {"kind": "w", "base": 1042, "origin": "mob", "affix": "hollow", "params": [], "plainName": "d", "name": "空壳·d"})
	got["needs-config"] = {"mimic": XAlienation.needs_configuration(c), "hollow": XAlienation.needs_configuration(d), "inverse": XAlienation.needs_configuration(a)}
	for r in rows:
		var k := str(r.step)
		if not got.has(k):
			continue
		var want := {}
		for f in r:
			if f != "step":
				want[f] = r[f]
		var mine: Dictionary = got[k]
		if mine.has("r"):
			mine.r = mine.r.error if mine.r.has("error") else mine.r
			want.r = want.r.thrown if want.r.has("thrown") else want.r.ok
			if mine.r is Dictionary and mine.r.has("ok"):
				mine.r = true if k.begins_with("resolve") else mine.r.ok
		check("call_" + k, norm(mine) == norm(want), [mine, want])


func _prep(name: String, s: XState, items: Array) -> void:
	var E := XAlienation.energy_id()
	var S := XAlienation.stone_id()
	match name:
		"list":
			s.gain_item(E, 45)
		"keep-old":
			s.gain_item(S, 1)
		"locked-equipped":
			s.gain_item(S, 2)
		"recent":
			var l := XAlienation.ledger(s)
			for n in 12:
				l.recent.append({"name": "测试装备%d" % n, "origin": "mob" if n % 3 else "boss", "uid": "x%d" % n, "kind": "w", "id": 1})
	for row in items:
		_make(s, row)


func _flow(p: Dictionary) -> void:
	var name := str(p.name)
	var s := _state()
	_prep(name, s, p.items)
	var toast0 := XToast.shown.size()
	var page := XAlienWorkshop.new()
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	add_child(page)
	await frames()
	await shot("alien_" + name)
	if name == "list":
		await _layout(page)
	var bad := []
	var screen := 0
	if norm(XAlienWorkshop.flatten(page.tree)) != norm(p.screens[0]):
		bad.append([0, first_diff(XAlienWorkshop.flatten(page.tree), p.screens[0])])
	for step in p.steps:
		screen += 1
		if not bad.is_empty():
			break
		if str(step) == "Escape":
			var ev := InputEventKey.new()
			ev.keycode = KEY_ESCAPE
			ev.pressed = true
			page._unhandled_input(ev)
		elif not page.click(str(step)):
			bad.append([screen, "missing " + str(step)])
			break
		await frames(1)
		if name == "list" and screen == 3:
			await shot("alien_list_pending")
		var want = p.screens[screen]
		var got = null if closed[0] else XAlienWorkshop.flatten(page.tree)
		if norm(got) != norm(want):
			bad.append([screen, first_diff(got, want)])
	check("pages_" + name, bad.is_empty(), bad)
	check("toasts_" + name, XToast.shown.slice(toast0) == p.toasts, [XToast.shown.slice(toast0), p.toasts])
	check("after_" + name, _bag(s) == norm(p.bag) and norm(_gear(s)) == norm(p.gear) and norm(XAlienation.ledger(s)) == norm(p.ledger),
		[_bag(s), p.bag, _gear(s), p.gear, XAlienation.ledger(s), p.ledger])
	page.queue_free()
	await frames()


## 版面对原版游戏窗口主题（installGamePanelTheme）的实测读数（八戒_63 ui_reference/review_system_pages：alien_list）：
## 面板 x100 宽 1080；列表按钮 x132 宽 320.27、两键相距 55.19（O-087：第 2 个不右推 7）；详情标题 x487.27；收益绿、代价红
func _layout(page: XAlienWorkshop) -> void:
	for i in 3:
		await get_tree().process_frame
	var found := {}
	var walk := func(n: Node, f: Callable) -> void:
		for c in n.get_children():
			if c is PanelContainer and not found.has("pane") and c.get_theme_stylebox("panel") is XAlienWorkshop.PaneFrame:
				found.pane = c.get_global_rect()
			if c is Button and c.text in ["逆骨·血吼", "疫囊·尼伯龙根指环"]:
				found[c.text] = c.get_global_rect()
			if c is Label and c.text == "逆骨·血吼":
				found.h2 = c.get_global_rect()
			if c is Label and c.text.begins_with("收益："):
				found.good = c.label_settings.font_color
			if c is Label and c.text.begins_with("代价："):
				found.bad = c.label_settings.font_color
			f.call(c, f)
	walk.call(page, walk)
	var near := func(a: float, b: float) -> bool: return absf(a - b) <= 1.0
	var ok: bool = found.size() == 6 and near.call(found.pane.position.x, 100) and near.call(found.pane.size.x, 1080) \
		and near.call(found["逆骨·血吼"].position.x, 132) and near.call(found["逆骨·血吼"].size.x, 320.27) \
		and near.call(found["疫囊·尼伯龙根指环"].position.x, 132) and near.call(found["疫囊·尼伯龙根指环"].position.y - found["逆骨·血吼"].position.y, 55.19) \
		and near.call(found.h2.position.x, 487.27) and found.good == XAlienWorkshop.GOOD and found.bad == XAlienWorkshop.BAD
	check("layout_game_panel_theme", ok, found)
	# 焦点框照原版 :focus-visible：打开时焦点在第一个按钮但不画框，键盘移动焦点后才画
	var first := get_viewport().gui_get_focus_owner()
	check("focus_hidden_on_open", first is Button and first.has_focus() and not first.has_focus(true), first)
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = "ui_down"
		e.pressed = down
		get_viewport().push_input(e)
		await get_tree().process_frame
	var moved := get_viewport().gui_get_focus_owner()
	check("focus_visible_after_key", moved is Button and moved != first and moved.has_focus(true), [first, moved])
	# O-089 回退：不预先聚焦（原版重画后焦点不在任何按钮上）
	XAlienWorkshop.focus_first = false
	moved.release_focus()
	var plain := XAlienWorkshop.new()
	add_child(plain)
	for i in 4:
		await get_tree().process_frame
	check("o089_original_no_focus", get_viewport().gui_get_focus_owner() == null, get_viewport().gui_get_focus_owner())
	XAlienWorkshop.focus_first = true
	plain.queue_free()
	await get_tree().process_frame
	# O-087 回退：第 2 个起右推 7（与原版读数 x139 一致）
	# 另开一个实例看，不动流程页（静态选中项先存后还）
	var keep := XAlienWorkshop.selected
	XAlienWorkshop.list_indent_quirk = true
	var other := XAlienWorkshop.new()
	add_child(other)
	for i in 3:
		await get_tree().process_frame
	found.clear()
	walk.call(other, walk)
	XAlienWorkshop.list_indent_quirk = false
	other.queue_free()
	XAlienWorkshop.selected = keep
	await get_tree().process_frame
	check("o087_original_indent", found.has("疫囊·尼伯龙根指环") and near.call(found["疫囊·尼伯龙根指环"].position.x, 139), found.get("疫囊·尼伯龙根指环"))


func _menu_entry() -> void:
	var cmd: Array = XMenu.COMMANDS.filter(func(c): return c[1] == "alienation")
	check("menu_alienation_enabled", cmd.size() == 1 and cmd[0][2] == true)
	var s := _state()
	var menu := XMenu.new()
	menu.event_state = s
	add_child(menu)
	await frames()
	menu._cmd_index = XMenu.COMMANDS.map(func(c): return c[1]).find("alienation")
	menu._ok()
	await frames(3)
	check("menu_opens_workshop", menu.get_children().any(func(n): return n is XAlienWorkshop))
	menu.queue_free()
	await frames()


func _finish() -> void:
	XAlienation.force_roll = -1.0
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.5, true, false, true).timeout
	await frames(3)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
