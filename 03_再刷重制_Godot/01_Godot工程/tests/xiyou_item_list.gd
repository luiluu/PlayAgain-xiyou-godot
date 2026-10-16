extends Node
## 物品列表一组对照正式版运行时读数（tests/fixtures/item_list_oracle.json：冻结 v0.28，ui_reference ?item_list_ref=1 内存新局）：
## - NEW 角标（Galv_NewItemIndication）：物品页光标停上去即看过、移开或离开列表才重画；类型 0 的装备不画也不记；
##   装备页候选同物品页；商店出售列表只画不记；战斗物品窗口不画不记；同 ID 物品再得仍旧、同基础新实例为新；随存档。
## - 「序号/9,999」与身上角色名（YEP_ItemCore）：序号按 $gameParty.weapons() 原序（基础 ID，同基础按实例），
##   筛选、排序、换装后都不按显示序重编。
## - 战斗物品窗口：XItemMarks.apply_list 的置顶顺序与标记名、「×数量」、名字宽、窗口大小、PageUp/Down。
## 内存新游戏，不写存档。窗口模式加 -- --out=<目录> 截图。

var results := []
var out_dir := ""
var fx := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func frames() -> void:
	for i in range(6):
		await get_tree().process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


func _run() -> void:
	fx = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/item_list_oracle.json"))
	XGear.force_roll = 0.5
	await _new_items()
	await _weapons()
	_seen_rules()
	await _battle_items()
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"passed": results.size() - failed.size(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit(0 if failed.is_empty() else 1)


func _ints(a: Array) -> Array:
	return a.map(func(v): return int(v))


## 正式版开局：队伍 1/8/9/10，背包没有物品与装备
func _new_state() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	return s


# ---- NEW：物品页 ----
func _new_items() -> void:
	var f: Dictionary = fx.new_items
	var s := _new_state()
	check("start_bag_empty", s.items.is_empty() and s.gear.is_empty(), [s.items, s.gear.size()])
	for g in f.gains:
		s.gain_item(int(g[0]), int(g[1]))
	var page := XItemScene.new()
	add_child(page)
	await frames()
	var shown := func() -> Array: return page.entries().map(func(e): return 1 if page._is_new_drawn(e.rec) else 0)
	var names: Array = page.entries().map(func(e): return str(e.rec.name))
	check("new_rows", names == f.rows, names)
	check("new_category_phase", shown.call() == _ints(f.category_phase.shown), shown.call())
	page._ok()
	check("new_open", page._index == int(f.open.index) and shown.call() == _ints(f.open.shown), shown.call())
	for step in ["down1", "down2"]:
		page._move(1, true)
		page._refresh()
		check("new_" + step, page._index == int(f[step].index) and shown.call() == _ints(f[step].shown), [page._index, shown.call()])
	page._ok()
	var seen: Array = page.entries().map(func(e): return 0 if s.is_new(e.rec) else 1)
	check("new_ok_to_actions", page._mode == "action" and shown.call() == _ints(f.ok_to_actions.shown) and seen == _ints(f.ok_to_actions.seen), [shown.call(), seen])
	page.queue_free()
	await frames()


# ---- 装备：NEW、序号、换装、筛选、装备页候选、商店出售 ----
var _refs := {}


func _ref_of(rec: Dictionary) -> String:
	if rec.is_empty():
		return "remove"
	for k in _refs:
		if is_same(_refs[k], rec):
			return k
	return "?" + str(rec.get("instanceId", ""))


func _weapons() -> void:
	var f: Dictionary = fx.weapons
	var s := _new_state()
	_refs = {}
	var start := {}
	for id in [1, 8, 9, 10]:
		var e = s.actor(id).equips[0]
		start[str(id)] = int(e.base) if e != null and not e.is_empty() else 0
		if start[str(id)] > 0:
			_refs["a%d" % id] = e
	check("start_weapons", start.keys().all(func(k): return int(start[k]) == int(f.start_weapons[k])), start)
	for i in range(f.gains.size()):
		s.gain_gear("weapon", int(f.gains[i]), 1)
		_refs["g%d" % i] = s.gear.back()
	var bag: Array = XItemScene.bag_gear("weapon").map(_ref_of)
	check("bag_order_by_base", bag == f.bag_order, bag)
	var knife: Dictionary = _refs["g%d" % f.gains.find(float(f.untyped_base))]
	check("untyped_never_new", not XItemRow.new_tracked(knife) and not XItemRow.shows_new(s, knife) and XItemRow.new_tracked(_refs.g1), [knife.get("wtypeId"), knife.name])
	# 物品页武器分类（Codex 默认排序）
	var page := XItemScene.new()
	add_child(page)
	await frames()
	page._cat = 2
	page._refresh()
	page._ok()
	await frames()
	var rows: Array = page.entries().map(func(e): return [_ref_of(e.rec), XItemRow.right_text(e), 1 if page._is_new_drawn(e.rec) else 0])
	check("item_weapon_rows", rows == f.item_rows.map(func(r): return [r[0], r[1], int(r[2])]), rows)
	_row_geometry(page, f.row_text)
	await shot("item_weapon_new_carry")
	page.queue_free()
	await frames()
	# 装备页候选（换装前；狗逍遥武器槽）
	var equip := XEquipScene.new()
	add_child(equip)
	await frames()
	equip._ok()
	equip._slot = 0
	equip._refresh()
	equip._ok()
	await frames()
	var ec: Dictionary = f.equip_candidates_actor1_slot0
	var shown_e := func() -> Array: return equip.candidates().filter(func(e): return not e.rec.is_empty()).map(func(e): return 1 if XItemRow.shows_new(s, e.rec) else 0)
	var cands: Array = equip.candidates().map(func(e): return [_ref_of(e.rec), XItemRow.right_text(e) if not e.rec.is_empty() else ""])
	check("equip_candidates", equip._mode == "item" and cands == ec.rows, cands)
	check("equip_new_open", shown_e.call() == _ints(ec.open.shown), shown_e.call())
	equip._move(1, true)
	equip._refresh()
	check("equip_new_down", shown_e.call() == _ints(ec.down.shown), shown_e.call())
	equip._cancel()
	equip._refresh()
	check("equip_new_cancel", shown_e.call() == _ints(ec.cancel.shown), shown_e.call())
	equip.queue_free()
	await frames()
	# 换装：g5 装到狗逍遥武器槽，原来的 a1 回背包
	var after: Dictionary = f.after_equip_g5_on_1
	XEquipment.change(s, s.actor(1), 0, _refs.g5)
	bag = XItemScene.bag_gear("weapon").map(_ref_of)
	check("after_equip_bag_order", bag == after.bag_order, bag)
	page = XItemScene.new()
	add_child(page)
	await frames()
	page._cat = 2
	page._refresh()
	page._ok()
	rows = page.entries().map(func(e): return [_ref_of(e.rec), XItemRow.right_text(e)])
	check("after_equip_item_rows", rows == after.item_rows, rows)
	var filt := XGearQuery.defaults()
	filt.scope = "bag"
	filt.type = "w2"
	page._apply_filter(filt)
	rows = page.entries().map(func(e): return [_ref_of(e.rec), XItemRow.right_text(e)])
	check("filter_bag_w2_keeps_carry", rows == after.filter_bag_type_w2, rows)
	filt = XGearQuery.defaults()
	filt.scope = "worn"
	page._apply_filter(filt)
	rows = page.entries().map(func(e): return [_ref_of(e.rec), XItemRow.right_text(e)])
	check("filter_worn_names", rows == after.filter_worn, rows)
	page.clear_filter()
	page.queue_free()
	await frames()
	# 商店出售（正式版读数取自另一新局：同样获得、g5 换给狗逍遥后，未在别的列表看过）：按背包原序、序号；画 NEW 但不记看过
	s = _new_state()
	_refs = {"a1": s.actor(1).equips[0]}
	for i in range(f.gains.size()):
		s.gain_gear("weapon", int(f.gains[i]), 1)
		_refs["g%d" % i] = s.gear.back()
	XEquipment.change(s, s.actor(1), 0, _refs.g5)
	_shop_sell(s, f.shop_sell)


## Window_ItemList 一行：名字 x 36、宽 474.125，右侧 x 0 宽 606 字号 20 右对齐（物品页列表内容宽 612）
func _row_geometry(page: XItemScene, want: Dictionary) -> void:
	var rc := RecCanvas.new()
	rc.size = page.list_win.canvas.size
	var e: Dictionary = page.entries()[3]
	XItemRow.paint(rc, e.rec, 0, XItemRow.right_text(e))
	var log := rc.log
	rc.free()
	var name: Array = log.filter(func(x): return x[0] == "text" and x[5] == "left")[0]
	var right: Array = log.filter(func(x): return x[0] == "text" and x[5] == "right")[0]
	check("row_geometry", absf(name[2] - want.name_x) < 0.5 and absf(name[4] - want.name_w) < 2.0 and right[2] == want.right_x \
		and absf(right[4] - want.right_w) < 0.5 and right[6] == int(want.right_size), [name, right])


func _shop_sell(s: XState, want: Dictionary) -> void:
	var shop := XShop.new()
	shop.setup([[0, 1, 0, 0]], false)
	add_child(shop)
	shop._cmd = 1
	shop._ok()
	shop._cat = 2
	shop._ok()
	var rows: Array = shop._sell_data().map(func(e): return [_ref_of(e.rec), XItemRow.right_text(e), 1 if XItemRow.shows_new(s, e.rec) else 0])
	check("shop_sell_rows", shop._mode == "sell" and rows == want.rows.map(func(r): return [r[0], r[1], int(r[2])]), [shop._mode, rows])
	shop._move(1, true)
	shop._refresh()
	shop._cancel()
	var still: Array = shop._sell_data().map(func(e): return 1 if XItemRow.shows_new(s, e.rec) else 0)
	check("shop_sell_never_marks_seen", still == want.rows.map(func(r): return int(r[2])), still)
	shop.free()


# ---- 看过的规则 ----
func _seen_rules() -> void:
	var f: Dictionary = fx.seen_rules
	var s := _new_state()
	s.gain_item(1, 1)
	s.gain_gear("weapon", 2, 1)
	var w1: Dictionary = s.gear[0]
	s.mark_seen(XDB.rec("Items", 1))
	s.mark_seen(w1)
	s.gain_item(1, 5)
	s.gain_gear("weapon", 2, 1)
	var w2: Dictionary = s.gear[1]
	check("same_item_stays_seen", s.is_new(XDB.rec("Items", 1)) == bool(f.same_item_after_seen))
	check("new_instance_is_new", s.is_new(w2) == bool(f.new_instance_of_seen_base) and not s.is_new(w1))
	s.gear.erase(w1)
	s.gain_gear("weapon", 2, 1)
	var w3: Dictionary = s.gear.back()
	check("instance_not_reused", str(w3.instanceId) != str(w1.instanceId) and s.is_new(w3) != bool(f.instance_id_reused_after_loss))
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	var kept := not back.is_new(XDB.rec("Items", 1)) and back.is_new(w3) and not back.is_new({"instanceId": w1.instanceId})
	check("seen_survives_save", kept == bool(f.save_round_trip_keeps_seen))
	XState.current = s


# ---- 战斗物品窗口 ----
func _battle_items() -> void:
	var f: Dictionary = fx.battle_items
	var s := _new_state()
	for g in f.gains:
		s.gain_item(int(g[0]), int(g[1]))
	s.flags.TopItem = f.top.duplicate()
	s.flags.ItemSpLock = f.lock.duplicate()
	var logic := XBattleLogic.new()
	logic.state = s
	var order: Array = XBattleScene.battle_item_order(s, logic.battle_items())
	check("battle_item_order", order.map(func(r): return int(r.id)) == _ints(f.ids), order.map(func(r): return int(r.id)))
	check("battle_item_original_recs", order.all(func(r): return is_same(r, XDB.rec("Items", int(r.id)))))
	var rows: Array = order.map(func(r): return XBattleScene.item_list_row(s, r, true))
	check("battle_item_names", rows.map(func(r): return r.text) == f.names, rows.map(func(r): return r.text))
	check("battle_item_numbers", rows.map(func(r): return r.costs[0].text) == f.numbers and rows.all(func(r): return int(r.costs[0].size) == int(f.row.number_size)), rows.map(func(r): return r.costs[0].text))
	check("battle_item_not_marked", order.all(func(r): return s.is_new(r)))
	var holder := Control.new()
	add_child(holder)
	var w := XBattleList.create(holder, rows, 450)
	check("battle_item_rect_5", w.size == Vector2(f.rect_5[2], f.rect_5[3]), w.size)
	var rc := RecCanvas.new()
	rc.size = Vector2(450 - 22, w.rows * XBattleList.LH)
	w._paint(rc)
	var row0: Array = rc.log.filter(func(x): return x[0] == "text" and x[3] == 0.0)
	var nm: Array = row0.filter(func(x): return x[5] == "left")[0]
	var num: Array = row0.filter(func(x): return x[5] == "right")[0]
	check("battle_item_row_geometry", nm[2] == float(f.row.name_x) and absf(nm[4] - float(f.row.name_w)) < 2.0 and num[2] == float(f.row.number_x) and num[4] == float(f.row.number_w) and num[6] == int(f.row.number_size), [nm, num])
	rc.free()
	# 全部放得下时 PageUp/Down 不动
	w.select(2)
	w.page(1)
	w.page(-1)
	check("battle_page_all_fit", w.index == 2 and w.top == 0, [w.index, w.top])
	w.queue_free()
	for id in f.more_gains:
		s.gain_item(int(id), 1)
	order = XBattleScene.battle_item_order(s, logic.battle_items())
	check("battle_item_20", order.size() == 20)
	w = XBattleList.create(holder, order.map(func(r): return XBattleScene.item_list_row(s, r, true)), 450)
	check("battle_item_rect_20", w.size == Vector2(f.rect_20[2], f.rect_20[3]) and w.rows == int(f.max_page_rows), w.size)
	w.select(0)
	var seq := []
	for d in [1, 1, 1, 1, -1, -1, -1, -1]:
		w.page(d)
		seq.append(["pd" if d > 0 else "pu", w.index, w.top])
	check("battle_page_sequence", seq == f.page_seq_from_0.map(func(x): return [x[0], int(x[1]), int(x[2])]), seq)
	w.select(5)
	w.page(1)
	check("battle_page_from_5", [w.index, w.top] == [int(f.page_from_5[1]), int(f.page_from_5[2])], [w.index, w.top])
	holder.queue_free()
	await frames()


## 记录画图调用的画布
class RecCanvas extends XMVCanvas:
	var log := []

	func text(s: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, lh := XUI.LINE_HEIGHT, alpha := 1.0, zoom := 1.0, pivot := Vector2.ZERO) -> void:
		log.append(["text", s, x, y, max_w, align, size])

	func icon(index: int, x: float, y: float, alpha := 1.0, size := 32.0) -> void:
		log.append(["icon", index, x, y])

	func cursor(r: Rect2, active := true) -> void:
		log.append(["cursor", r])
