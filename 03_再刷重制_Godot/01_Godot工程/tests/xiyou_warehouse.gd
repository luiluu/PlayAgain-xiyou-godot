extends Node
## 仓库（XWarehouse／XWarehouseScene）：对照冻结 v0.28 浏览器参照 tests/fixtures/warehouse_oracle.json
## （ui_reference/review_system_pages.js 的 warehouse：内存新局，药水 1×5、2×3、蘑菇 6×2、指路灯 4×1、武器 2／9、防具 2，
## 先存入物品 1 两次、钥匙 4、武器 2、防具 2）：七个截图状态的全部窗口文字（标题、选项、分类、列表、信息；坐标与宽差 ≤ POS_TOL，
## 字号、对齐、颜色相等）、列表光标、NEW 行、仓库内容（件数与各类数量）与背包；
## 再测规则：容量满不能存、物品 9999 取不出、重置（remove＋create）清空、存读档（实例编号不重复、旧档没有仓库）、
## 仓库管理员 Map4 EV8 第 1 页「装备道具仓库」两条指令（create、show）都认得并打开仓库。

const FIXTURE := "res://tests/fixtures/warehouse_oracle.json"
const POS_TOL := 0.05

var results := []
var out_dir := ""


class FakeHost extends Node:
	var opened := 0
	func open_warehouse() -> void:
		opened += 1
		await get_tree().process_frame
	func refresh_events() -> void:
		pass
	func character(_id: int, _event_id: int):
		return null


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


static func _color(text: String) -> String:
	return (XQuality.parse_rgba(text) if text.begins_with("rgba") else Color(text)).to_html(false)


static func want_form(texts: Array) -> Array:
	return _sorted(texts.map(func(t): return [str(t[0]), float(t[1]), float(t[2]), float(t[3]), str(t[4]), float(t[5]), _color(str(t[6]))]))


static func got_form(ops: Array) -> Array:
	var out := []
	for o in ops:
		if o[0] == "t":
			out.append([str(o[1]), float(o[2]), float(o[3]), float(o[4]), str(o[6]), float(o[7]), (o[8] as Color).to_html(false)])
	return _sorted(out)


static func _sorted(a: Array) -> Array:
	a.sort_custom(func(x, y): return [x[2], x[1], str(x[0])] < [y[2], y[1], str(y[0])])
	return a


static func diff(got: Array, want: Array) -> String:
	for i in maxi(got.size(), want.size()):
		if i >= got.size() or i >= want.size():
			return "#%d 条数 %d≠%d %s" % [i, got.size(), want.size(), JSON.stringify(want[i] if i < want.size() else got[i])]
		var g: Array = got[i]
		var w: Array = want[i]
		for k in w.size():
			var bad: bool = str(g[k]) != w[k] if w[k] is String else absf(float(g[k]) - float(w[k])) > POS_TOL
			if bad:
				return "#%d got %s want %s" % [i, JSON.stringify(g), JSON.stringify(w)]
	return ""


func _new_state() -> XState:
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	XState.current = s
	return s


## 参照的摆法
func _setup() -> XState:
	var s := _new_state()
	for p in [[1, 5], [2, 3], [6, 2], [4, 1]]:
		s.gain_item(p[0], p[1])
	s.gain_gear("weapon", 2, 1)
	s.gain_gear("weapon", 9, 1)
	s.gain_gear("armor", 2, 1)
	XWarehouse.create(s, "<仓库:999>")
	XWarehouse.open(s, "<仓库>")
	XWarehouse.deposit(s, "item", XDB.rec("Items", 1))
	XWarehouse.deposit(s, "item", XDB.rec("Items", 1))
	XWarehouse.deposit(s, "keyItem", XDB.rec("Items", 4))
	XWarehouse.deposit(s, "weapon", XItemScene.bag_gear("weapon").filter(func(e): return int(e.base) == 2)[0])
	XWarehouse.deposit(s, "armor", XItemScene.bag_gear("armor").filter(func(e): return int(e.base) == 2)[0])
	return s


func _compare(ref: Dictionary, name: String, page: XWarehouseScene) -> void:
	var w: Dictionary = ref.shots[name].windows
	var parts := {"Window_WarehouseTitle": XWarehouseScene.title_ops(), "Window_WarehouseOption": XWarehouseScene.option_ops(),
		"Window_WarehouseCategory": XWarehouseScene.cat_ops(), "Window_WarehouseItemList": page.list_ops(), "Window_WarehouseInfo": XWarehouseScene.info_ops()}
	var bad := []
	for k in parts:
		var d := diff(got_form(parts[k]), want_form(w[k].texts))
		if d != "":
			bad.append("%s %s" % [k, d])
	var rect := func(c: Control) -> Array: return [c.position.x, c.position.y, c.size.x, c.size.y]
	var rects := {"Window_WarehouseTitle": page.title_win, "Window_WarehouseOption": page.option_win, "Window_WarehouseCategory": page.cat_win,
		"Window_WarehouseItemList": page.list_win, "Window_WarehouseInfo": page.info_win}
	for k in rects:
		if rect.call(rects[k]) != w[k].rect.map(func(v): return float(v)):
			bad.append("%s 矩形 %s" % [k, rect.call(rects[k])])
	if int(w.Window_WarehouseOption.index) != page.option or int(w.Window_WarehouseCategory.index) != page.category:
		bad.append("光标 选项%d 分类%d" % [page.option, page.category])
	# 列表光标（wh_5 参照里选了越界的第 2 格，只比文字）
	if name != "wh_5_deposit_weapon" and int(w.Window_WarehouseItemList.index) != page.index:
		bad.append("列表光标 %d" % page.index)
	# NEW：参照记的是画 NEW 的 (x+2, y+2)
	var s := XState.current
	var news := []
	for i in page.data.size():
		if XItemRow.shows_new(s, page.data[i].rec):
			var p := XWarehouseScene.cell(i, page.top) + Vector2(2, 2)
			news.append([p.x, p.y])
	if news != ref.shots[name].newRows.map(func(r): return [float(r[0]), float(r[1])]):
		bad.append("NEW %s" % JSON.stringify(news))
	check(name, bad.is_empty(), bad)


## 仓库内容与参照比较：件数、上限、各类的数量（装备按基础 ID）
func _contents(ref: Dictionary, name: String, s: XState) -> void:
	var want: Dictionary = ref.shots[name].warehouses["仓库"]
	var got: Dictionary = s.warehouses["仓库"]
	var ok := int(got.currentCapacity) == int(want.currentCapacity) and int(got.maxCapacity) == int(want.maxCapacity)
	for cat in ["item", "keyItem"]:
		ok = ok and got.items[cat] == want.items[cat].map(func(v): return int(v))
		for k in want.qtty[cat]:
			ok = ok and int(got.qtty[cat].get(str(k), 0)) == int(want.qtty[cat][k])
	ok = ok and got.items.weapon.map(func(e): return int(e.base)) == [2] and got.items.armor.map(func(e): return int(e.base)) == [2]
	var party: Dictionary = ref.shots[name].party
	for k in party.items:
		ok = ok and s.item_count(int(k)) == int(party.items[k])
	ok = ok and XItemScene.bag_gear("weapon").map(func(e): return int(e.base)) == party.weapons.map(func(v): return int(v[1]))
	ok = ok and XItemScene.bag_gear("armor").size() == party.armors.size()
	check(name + ".contents", ok, [got.currentCapacity, got.items.item, got.qtty, s.items])


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("fixture_loaded", ref is Dictionary and ref.get("shots", {}).has("wh_0"), FIXTURE):
		get_tree().quit.call_deferred(1)
		return
	await _flow(ref)
	_rules()
	_save()
	await _interpreter()
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.5, true, false, true).timeout
	await frames(3)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _flow(ref: Dictionary) -> void:
	var s := _setup()
	var page := XWarehouseScene.new()
	add_child(page)
	await frames()
	await shot("wh_0")
	check("open_option", page.mode == "option" and page.category == -1 and page.index == -1)
	_compare(ref, "wh_0", page)
	_contents(ref, "wh_0", s)
	page.ok()
	await shot("wh_1_withdraw_category")
	_compare(ref, "wh_1_withdraw_category", page)
	page.ok()
	await shot("wh_2_withdraw_items")
	_compare(ref, "wh_2_withdraw_items", page)
	page.cancel()
	page._move(1, 0, true)
	page.ok()
	await shot("wh_3_withdraw_weapon")
	_compare(ref, "wh_3_withdraw_weapon", page)
	page.cancel()
	page.cancel()
	page._move(1, 0, true)
	page.ok()
	page.ok()
	await shot("wh_4_deposit_items")
	_compare(ref, "wh_4_deposit_items", page)
	page.cancel()
	page._move(1, 0, true)
	page.ok()
	await shot("wh_5_deposit_weapon")
	_compare(ref, "wh_5_deposit_weapon", page)
	page.cancel()
	page.cancel()
	page._move(-1, 0, true)
	page.ok()
	page.ok()
	page.ok()
	await shot("wh_6_withdraw_one")
	_compare(ref, "wh_6_withdraw_one", page)
	_contents(ref, "wh_6_withdraw_one", s)
	check("withdraw_sound", XSound.system_log.back() == 4, XSound.system_log.slice(-3))
	# 列表移动：两列，右逐格、下跳一行、到边不动
	page.cancel()
	page.cancel()
	page._move(1, 0, true)
	page.ok()
	page.ok()          # 储存·物品：1×4、2×3、6×2
	page._move(1, 0, true)
	var a := page.index
	page._move(0, 1, true)
	var b := page.index
	page._move(0, 1, true)
	check("list_cursor", a == 1 and b == 1 and page.data.size() == 3, [a, b, page.data.size()])
	# 储存一件：药水 2 从 3 变 2，仓库加一类
	page.ok()
	check("deposit_one", s.item_count(2) == 2 and s.warehouses["仓库"].qtty.item.get("2", 0) == 1 and int(s.warehouses["仓库"].currentCapacity) == 5,
		[s.item_count(2), s.warehouses["仓库"].qtty])
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	page.cancel()
	page.cancel()
	check("cancel_to_option", not closed[0] and page.mode == "option")
	page.cancel()
	check("cancel_closes", closed[0])
	page.queue_free()
	await frames()


func _rules() -> void:
	var s := _new_state()
	s.gain_item(1, 3)
	s.gain_gear("weapon", 2, 1)
	XWarehouse.create(s, "<小:2>")
	XWarehouse.open(s, "<小>")
	var ok1 := XWarehouse.deposit(s, "item", XDB.rec("Items", 1))
	var ok2 := XWarehouse.deposit(s, "weapon", s.gear[0])
	var ok3 := XWarehouse.deposit(s, "item", XDB.rec("Items", 1))
	check("capacity_full", ok1 and ok2 and not ok3 and s.item_count(1) == 2 and s.gear.is_empty() and not XWarehouse.has_space(s)
		and XWarehouse.info_text(s) == "可用空间: 0 / 2", [ok1, ok2, ok3, XWarehouse.info_text(s)])
	# 满容量时储存列表不可确定
	var page := XWarehouseScene.new()
	page.option = 1
	page.data = XWarehouse.carried(s, "item")
	var deposit_full := page._enabled()
	page.option = 0
	page.data = XWarehouse.stored(s, "item")
	check("full_disables_deposit", not deposit_full and page._enabled(), [deposit_full])
	page.free()
	check("create_default_capacity", _created_capacity("<甲>") == 50 and _created_capacity("<乙:0>") == 50 and _created_capacity("<丙:7>") == 7)
	XState.current = s
	XWarehouse.open(s, "<小>")
	# 取出的装备回到背包（同一个实例）
	var inst: Dictionary = s.warehouses["小"].items.weapon[0]
	check("withdraw_gear", XWarehouse.withdraw(s, "weapon", inst) and is_same(s.gear[0], inst) and int(s.warehouses["小"].currentCapacity) == 1)
	# 物品 9999 时取不出（gainItem 没加上 → 蜂鸣，仓库不变）
	s.gain_item(1, 9999)
	check("withdraw_full_bag", not XWarehouse.withdraw(s, "item", XDB.rec("Items", 1)) and int(s.warehouses["小"].qtty.item["1"]) == 1)
	# 重置：remove 再 create
	XWarehouse.remove(s, "<小>")
	XWarehouse.create(s, "<小:999>")
	check("reset_empties", int(s.warehouses["小"].currentCapacity) == 0 and s.warehouses["小"].items.item.is_empty() and int(s.warehouses["小"].maxCapacity) == 999)
	# 插件指令
	var args := "PHWarehouse create <新仓:30>".split(" ", false)
	check("plugin_create", XWarehouse.plugin_command(s, args) and int(s.warehouses["新仓"].maxCapacity) == 30)


func _created_capacity(text: String) -> int:
	var s := _new_state()
	XWarehouse.create(s, text)
	return int(s.warehouses[XWarehouse.sentence(text).split(":")[0]].maxCapacity)


func _save() -> void:
	var s := _setup()
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var s2 := XState.from_dict(d)
	var w: Dictionary = s2.warehouses.get("仓库", {})
	var ids := []
	for e in s2.gear:
		ids.append(str(e.instanceId))
	for cat in ["weapon", "armor"]:
		for e in w.items[cat]:
			ids.append(str(e.instanceId))
	s2.gain_gear("weapon", 3, 1)
	var fresh := str(s2.gear.back().instanceId)
	check("save_roundtrip", not w.is_empty() and int(w.currentCapacity) == 5 and w.items.item == [1] and int(w.qtty.item["1"]) == 2
		and w.items.keyItem == [4] and int(w.items.weapon[0].base) == 2 and not ids.has(fresh), [w.get("items"), fresh, ids])
	d.erase("phwarehouse")
	check("old_save_empty", XState.from_dict(d).warehouses.is_empty())
	d.selfSwitches["4,8,A"] = true
	var migrated := XState.from_dict(d)
	var old: Dictionary = migrated.warehouses.get("仓库", {})
	check("old_unlocked_save_migrates", int(old.get("maxCapacity", 0)) == 999 and int(old.get("currentCapacity", -1)) == 0)
	var saved := s.to_dict().duplicate(true)
	saved.selfSwitches["4,8,A"] = true
	var existing := XState.from_dict(saved)
	check("unlocked_save_keeps_contents", int(existing.warehouses["仓库"].currentCapacity) == 5
		and int(existing.warehouses["仓库"].qtty.item["1"]) == 2)
	saved.phwarehouse = {}
	check("explicit_empty_not_migrated", XState.from_dict(saved).warehouses.is_empty())


## 仓库管理员 Map4 EV8 第 1 页「装备道具仓库」：PHWarehouse create <仓库:999>、show <仓库> → 打开一次
func _interpreter() -> void:
	var ev: Dictionary = {}
	for e in XDB.map(4).events:
		if e is Dictionary and int(e.get("id", 0)) == 8:
			ev = e
	if not check("map4_ev8_present", not ev.is_empty()):
		return
	var cmds: Array = ev.pages[0].list.filter(func(c): return int(c.code) == 356 and str(c.parameters[0]).begins_with("PHWarehouse"))
	cmds = cmds.slice(0, 2).map(func(c): return {"code": 356, "indent": 0, "parameters": c.parameters})
	cmds.append({"code": 0, "indent": 0, "parameters": []})
	var s := _new_state()
	s.map_id = 4
	var h := FakeHost.new()
	add_child(h)
	var it := MVInterpreter.new(h, 4, 8, cmds)
	await it.run()
	check("ev8_opens", cmds.size() == 3 and h.opened == 1 and it.skipped.is_empty() and s.warehouses.has("仓库")
		and int(s.warehouses["仓库"].maxCapacity) == 999, [cmds.size(), h.opened, it.skipped])
	# dev.165 前的 Godot 档已经执行过自开关 A；第二页不再 create，只 show。
	var legacy := _new_state().to_dict().duplicate(true)
	legacy.erase("phwarehouse")
	legacy.selfSwitches["4,8,A"] = true
	s = XState.from_dict(legacy)
	cmds = ev.pages[1].list.filter(func(c): return int(c.code) == 356 and str(c.parameters[0]).begins_with("PHWarehouse show")).slice(0, 1)
	cmds = cmds.map(func(c): return {"code": 356, "indent": 0, "parameters": c.parameters})
	cmds.append({"code": 0, "indent": 0, "parameters": []})
	h.opened = 0
	it = MVInterpreter.new(h, 4, 8, cmds)
	await it.run()
	check("legacy_ev8_p1_opens", cmds.size() == 2 and h.opened == 1 and it.skipped.is_empty(), [h.opened, it.skipped])
	s = _new_state()
	check("show_missing_does_not_create", not XWarehouse.open(s, "<仓库>") and s.warehouses.is_empty())
	h.queue_free()
	await frames()
