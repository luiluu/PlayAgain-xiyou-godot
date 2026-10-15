extends Node
## 一键出售（Star_ShopOnekey＋installUnifiedQualityRuntime）、出售锁定（Star_ShopOnekey）、道具置顶（Star_ItemTop）。
## 参照：正式应用 js/plugins/Star_ShopOnekey.js、Star_ItemTop.js、js/codex/runtime/installUnifiedQualityRuntime.js（只读，规则见 XItemMarks）。
## 出售报酬（YEP_X_MoreCurrencies）：与 mv_oracle sell_reward_probe 的参照（generated/oracle/sell_rewards.json）逐例比对
## 能否卖、金币、变量、物品与装备件数的变化；商店与挂机两条路径。
## 窗口模式加 -- --out=<目录> 保存截图。

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
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n := 4) -> void:
	for i in range(n):
		await get_tree().process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func gear(s: XState, kind: String, id: int, quality: String, price: int) -> Dictionary:
	var e := XGear.create(kind, id)
	s.register_gear(e)
	e.meta = e.meta.duplicate()
	if quality == "":
		e.meta.erase("quality")
	else:
		e.meta.quality = quality
	e.price = price
	s.gear.append(e)
	return e


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_item_marks"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XGear.force_roll = 0.5
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	# ---- 一键出售指令：七档各一行（每档都含旧档 0～14） ----
	var rows := XItemMarks.onekey_grades()
	check("onekey_commands", rows.map(func(r): return r.text) == ["出售普通品质", "出售优秀品质", "出售精良品质", "出售史诗品质", "出售传说品质", "出售不朽品质", "出售神话品质"], rows)
	check("onekey_members", XItemMarks.onekey_members(0) == [0, 1] and XItemMarks.onekey_members(4) == [5, 6, 7] and XItemMarks.onekey_members(6) == [12, 14], [XItemMarks.onekey_members(4), XItemMarks.onekey_members(6)])
	# ---- 一键出售规则：该档旧档、不带 [锁定]、只卖背包；卖价 price/2 向下取整，0 价也卖 ----
	s.gear.clear()
	var w1 := gear(s, "weapon", 1, "1", 101)      # 普通 → 卖 50
	var w2 := gear(s, "weapon", 2, "0", 0)        # 普通、0 价 → 也卖
	var w3 := gear(s, "weapon", 3, "1", 80)       # 普通但锁定 → 不卖
	var w4 := gear(s, "weapon", 4, "2", 80)       # 优秀 → 不卖
	var w5 := gear(s, "weapon", 5, "", 80)        # 无品质标记 → 不卖
	var a6 := gear(s, "armor", 1, "15", 80)       # 混沌 Mod（旧档 15）→ 神话一键不卖（原版只到 14）
	var a7 := gear(s, "armor", 2, "14", 90)       # 神话 Mod（14）→ 神话一键卖 45
	XItemMarks.toggle_lock(s, w3)
	var worn := XGear.create("weapon", 6)
	s.register_gear(worn)
	worn.meta = worn.meta.duplicate()
	worn.meta.quality = "1"
	s.actor(1).equips[0] = worn
	s.gold = 1000
	var r := XItemMarks.onekey_sell(s, 0)
	check("onekey_sell_grade0", r == [2, 50] and s.gold == 1050 and not s.gear.has(w1) and not s.gear.has(w2) and s.gear.has(w3) and s.gear.has(w4) and s.gear.has(w5) and s.actor(1).equips[0] == worn, [r, s.gold])
	r = XItemMarks.onekey_sell(s, 6)
	check("onekey_sell_grade6_legacy_only", r == [1, 45] and s.gear.has(a6) and not s.gear.has(a7), r)
	# ---- 出售锁定：装备改实例名、提示；物品记 ItemSpLock、无提示 ----
	check("gear_locked_name", str(w3.name).ends_with("[锁定]") and XItemMarks.is_locked(s, w3))
	check("gear_unlock_toast", XItemMarks.toggle_lock(s, w3) == "取消锁定" and not str(w3.name).contains("[锁定]"))
	check("gear_lock_toast", XItemMarks.toggle_lock(s, w3) == "锁定完成")
	s.gain_item(1, 3)
	s.gain_item(2, 1)
	s.gain_item(3, 2)
	check("item_lock_no_toast", XItemMarks.toggle_lock(s, XDB.rec("Items", 3)) == "" and XItemMarks.is_locked(s, XDB.rec("Items", 3)))
	# 挂机自动卖出同样跳过锁定装备（名字带 [锁定]）
	check("hangup_sell_skips_lock", str(w3.name).contains("[锁定]"))
	# ---- 道具置顶：只对物品，置顶的逐个移到最前（后出现的更前），名字加 [置顶] ----
	check("top_toast", XItemMarks.toggle_top(s, XDB.rec("Items", 2)) == "置顶完成")
	XItemMarks.toggle_top(s, XDB.rec("Items", 1))
	var page := XItemScene.new()
	add_child(page)
	await frames()
	page._ok()
	await frames()
	var names: Array = page.entries().map(func(e): return str(e.rec.name))
	# 原顺序 1,2,3；置顶 2、1 → 按出现先后 1、2 逐个移到最前 → 2,1,3
	var base: Array = [0, 1, 2, 3].map(func(id): return str(XDB.rec("Items", id).get("name", "")))
	check("item_list_top_order", names == [base[2] + "[置顶]", base[1] + "[置顶]", base[3] + "[锁定]"], names)
	check("db_name_unchanged", str(XDB.rec("Items", 2).name) == base[2])
	await shot("01_置顶与锁定")
	# 操作菜单：道具置顶、出售锁定可用；取消置顶后提示、留在操作菜单，名字去标记
	page._index = 1
	page._ok()
	await frames()
	check("item_actions_enabled", page._mode == "action" and page._actions.map(func(x): return [x.symbol, x.enabled]) == [["use", page._actions[0].enabled], ["top", true], ["lock", true], ["cancel", true]], page._actions)
	var shown_before := XToast.shown.size()
	page._act = 1
	page._ok()
	await frames()
	check("item_untop", page._mode == "action" and not XItemMarks.is_top(s, XDB.rec("Items", 1)) and XToast.shown.slice(shown_before).has("取消置顶") and str(page._item.name) == base[1], [page._mode, XToast.shown.slice(shown_before), page._item.name])
	page._act = 2
	page._ok()
	await frames()
	check("item_lock_from_page", XItemMarks.is_locked(s, XDB.rec("Items", 1)) and str(page._item.name) == base[1] + "[锁定]" and page._actions[0].text.contains("[锁定]"), page._item.name)
	page._cancel()
	page._cancel()
	page._cat = 2
	page._ok()
	await frames()
	var wi: int = page.entries().find_custom(func(e): return is_same(e.rec, w4))
	page._index = wi
	page._ok()
	await frames()
	check("gear_actions_no_top", page._actions.map(func(x): return x.symbol) == ["use", "upgrade", "lock", "cancel"])
	shown_before = XToast.shown.size()
	page._act = 2
	page._ok()
	await frames()
	check("gear_lock_from_page", str(w4.name).ends_with("[锁定]") and XToast.shown.slice(shown_before).has("锁定完成") and page._mode == "action")
	page.queue_free()
	await frames()
	# ---- 存档：ItemSpLock / TopItem 与装备名随存档 ----
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	XState.current = back
	check("save_roundtrip", XItemMarks.is_locked(back, XDB.rec("Items", 3)) and XItemMarks.is_top(back, XDB.rec("Items", 2)) and back.gear.any(func(e): return str(e.name).ends_with("[锁定]")), back.flags)
	XState.current = s
	# ---- 商店：一键出售窗口与流程 ----
	var shop := XShop.new()
	shop.setup([[0, 1, 0, 0]], false)
	add_child(shop)
	await frames()
	check("shop_onekey_enabled", shop._cmd_enabled(2))
	shop._cmd = 2
	shop._ok()
	await frames()
	check("onekey_window", shop._mode == "onekey" and shop.onekey_win.visible and Rect2(shop.onekey_win.position, shop.onekey_win.size) == Rect2(350, 150, 240, 7 * 36 + XMVWindow.PADDING * 2), Rect2(shop.onekey_win.position, shop.onekey_win.size))
	await shot("02_一键出售")
	shop._cancel()
	check("onekey_cancel", shop._mode == "command" and not shop.onekey_win.visible)
	gear(s, "armor", 3, "3", 30)
	var keep := s.gear.size()
	shop._ok()
	shop._onekey = 2
	var g0 := s.gold
	shop._ok()
	check("onekey_sell_from_shop", shop._mode == "command" and not shop.onekey_win.visible and s.gold == g0 + 15 and s.gear.size() == keep - 1, [s.gold - g0, s.gear.size(), keep])
	# 出售列表：置顶在前、锁定物品不能卖（提示，留在列表）
	shop._cmd = 1
	shop._ok()
	shop._ok()
	var sell_names: Array = shop._sell_data().map(func(e): return str(e.rec.name))
	check("sell_list_marks", sell_names == [base[2] + "[置顶]", base[1] + "[锁定]", base[3] + "[锁定]"], sell_names)
	shop._sell_index = sell_names.find(base[3] + "[锁定]")
	shown_before = XToast.shown.size()
	var n3 := s.item_count(3)
	shop._ok()
	check("sell_locked_refused", shop._mode == "sell" and s.item_count(3) == n3 and XToast.shown.slice(shown_before).has("已锁定 无法出售"), [shop._mode, XToast.shown.slice(shown_before)])
	shop._sell_index = 0
	g0 = s.gold
	shop._ok()
	shop._ok()
	check("sell_unlocked_ok", shop._mode == "sell" and s.item_count(2) == 0 and s.gold == g0 + 25, [shop._mode, s.item_count(2), s.gold - g0])
	shop.queue_free()
	var only := XShop.new()
	only.setup([[0, 1, 0, 0]], true)
	add_child(only)
	await frames()
	check("purchase_only_disables_onekey", not only._cmd_enabled(2))
	only.queue_free()
	await frames()
	await _sell_rewards()
	await _item_marks_oracle()
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


const ORACLE := "res://modes/xiyou/generated/oracle/sell_rewards.json"


func _gear_count(s: XState) -> int:
	return s.gear.size()


## 每例新开一局：持有该物品（装备按参照实例的价格）→ 卖出 → 与参照的变化逐项比对
func _sell_rewards() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if not check("sell_oracle_loaded", data is Dictionary and data.get("cases", []).size() >= 20, ORACLE):
		return
	var tags := {}
	for c in data.cases:
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		s.gold = 1000
		var kind := str(c.kind)
		var id := int(c.id)
		var n := int(c.number)
		var rec: Dictionary
		if kind == "item":
			s.gain_item(id, n)
			rec = XDB.rec("Items", id)
		else:
			rec = XGear.create(kind, id)
			s.register_gear(rec)
			rec.price = int(c.price)
			rec.meta = rec.meta.duplicate()
			rec.meta.quality = "1"
			s.gear.append(rec)
		var tag := "%s%d_%s" % [kind, id, c.via]
		check("sell_enabled_" + tag, XItemMarks.can_sell(rec) == bool(c.enabled), [XItemMarks.can_sell(rec), c.enabled])
		if not bool(c.enabled) and c.via == "shop":
			continue
		var vars0 := s.variables.duplicate()
		var items0 := s.items.duplicate()
		var gear0 := _gear_count(s)
		if c.via == "hangUp" and kind != "item":
			# 挂机自动卖出走 XHangUpAuto.after_battle_sell（每 1 场卖、旧档 1 开）
			var cfg := XHangUpAuto.sell_config(s)
			cfg.SellQuality = 1
			cfg["quality1"] = true
			XHangUpAuto.better_frequency = 0
			XHangUpAuto.after_battle_sell(s)
		else:
			XItemMarks.sell(s, rec, n)
		var dv := {}
		for k in s.variables:
			if float(s.variables[k]) != float(vars0.get(k, 0)):
				dv[str(int(k))] = int(s.variables[k] - vars0.get(k, 0))
		var di := {}
		for k in items0.keys() + s.items.keys():
			var d := s.item_count(int(k)) - int(items0.get(k, 0))
			if d != 0:
				di[str(int(k))] = d
		var want_gear := 0
		for k in ["weapons", "armors"]:
			for v in c.delta[k].values():
				want_gear += int(v)
		var want_vars := {}
		for k in c.delta.vars:
			want_vars[str(k)] = int(c.delta.vars[k])
		var want_items := {}
		for k in c.delta.items:
			want_items[str(k)] = int(c.delta.items[k])
		var ok: bool = s.gold - 1000 == int(c.delta.gold) and dv == want_vars and di == want_items and _gear_count(s) - gear0 == want_gear
		check("sell_reward_" + tag, ok, [s.gold - 1000, dv, di, _gear_count(s) - gear0, c.delta])
		for v in want_vars:
			tags["var" + v] = true
		for v in want_items:
			if int(want_items[v]) > 0:
				tags["item"] = true
	# 参照至少覆盖：变量报酬、物品报酬、不能卖
	check("sell_oracle_coverage", tags.has("item") and tags.keys().any(func(k): return k.begins_with("var")) and data.cases.any(func(c): return not c.enabled), tags.keys())
	# 商店：0 价但有报酬的可以卖，并按数量给报酬（weapon 73：变量 201 +1）
	var s2 := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s2
	var e := XGear.create("weapon", 73)
	s2.register_gear(e)
	e.price = 0
	s2.gear.append(e)
	var shop := XShop.new()
	shop.setup([], false)
	add_child(shop)
	await frames()
	shop._cmd = 1
	shop._ok()
	shop._cat = 2
	shop._ok()
	shop._sell_index = shop._sell_data().find_custom(func(x): return is_same(x.rec, e))
	var v0 := s2.variable(201)
	shop._ok()
	shop._ok()
	check("shop_sell_zero_price_reward", not s2.gear.has(e) and s2.variable(201) == v0 + 1 and shop._mode == "sell", [s2.variable(201), shop._mode])
	shop.queue_free()
	await frames()


## 执行正式引擎七档筛选（不是在测试里重写筛选公式），并检查锁定／置顶、窗口尺寸与 O-027 的依据。
func _item_marks_oracle() -> void:
	var file := "res://modes/xiyou/generated/oracle/item_marks.json"
	var data = JSON.parse_string(FileAccess.get_file_as_string(file)) if FileAccess.file_exists(file) else null
	if not check("marks_oracle_loaded", data is Dictionary and data.get("onekey", []).size() == 7, file):
		return
	for c in data.onekey:
		var s := XState.new_game(3, 1, [8, 9, 10])
		s.gear.clear()
		s.gold = 1000
		for spec in c.specs:
			var e := XGear.create(str(spec.kind), int(spec.base))
			s.register_gear(e)
			e.meta = e.meta.duplicate()
			if spec.quality == null:
				e.meta.erase("quality")
			else:
				e.meta.quality = str(int(spec.quality))
			e.price = int(spec.price)
			e.name = str(spec.label) + ("[锁定]" if spec.locked else "")
			e.audit_label = str(spec.label)
			if spec.get("worn", false):
				s.actor(1).equips[0] = e
			else:
				s.gear.append(e)
		var before: Array = s.gear.map(func(e): return str(e.audit_label))
		var v0 := s.variable(201)
		XItemMarks.onekey_sell(s, int(c.grade))
		var remaining: Array = s.gear.map(func(e): return str(e.audit_label))
		var sold: Array = before.filter(func(label): return not remaining.has(label))
		sold.sort()
		remaining.sort()
		check("onekey_oracle_grade%d" % int(c.grade), sold == c.sold and remaining == c.remaining and s.gold - 1000 == int(c.gold) and s.variable(201) - v0 == int(c.var201) and bool(c.worn) and s.actor(1).equips[0].get("audit_label") == "worn", [sold, remaining, s.gold - 1000, c])
	var state := XState.new_game(3, 1, [8, 9, 10])
	for c in data.marks:
		var rec := XDB.rec("Items", int(c.id))
		if c.op == "lock":
			XItemMarks.toggle_lock(state, rec)
		else:
			XItemMarks.toggle_top(state, rec)
		check("marks_oracle_%d_%s" % [int(c.id), c.op], state.flags.get("ItemSpLock", []) == c.locks.map(func(id): return int(id)) and state.flags.get("TopItem", []) == c.tops.map(func(id): return int(id)), [state.flags, c])
	state.flags.ItemSpLock = [3]
	state.flags.TopItem = [1, 2]
	var entries := [1, 2, 3].map(func(id): return {"rec": XDB.rec("Items", id)})
	var actual := XItemMarks.apply_list(state, entries).map(func(e): return {"id": int(e.rec.id), "name": str(e.rec.name)})
	check("marks_oracle_list", actual == data.listOrder.map(func(e): return {"id": int(e.id), "name": str(e.name)}), [actual, data.listOrder])
	# O-030：参照证实原版跨类型加名；Godot 只按物品标记，不改变同编号装备。
	var collision := XGear.create("weapon", 1)
	collision.id = int(data.collision.id)
	collision.name = "collision"
	state.flags.ItemSpLock = [int(collision.id)]
	state.flags.TopItem = [int(collision.id)]
	var collision_list := XItemMarks.apply_list(state, [{"rec": collision}])
	check("O030_typed_item_marks", str(data.collision.name) == "collision[锁定][置顶]" and collision_list[0].rec.name == "collision" and not XItemMarks.is_locked(state, collision) and not XItemMarks.is_top(state, collision))
	XState.current = state
	var shop := XShop.new()
	shop.setup([], false)
	add_child(shop)
	await frames()
	var rect: Array = data.layout.rect
	check("onekey_oracle_layout", shop.onekey_win.position == Vector2(rect[0], rect[1]) and shop.onekey_win.size == Vector2(rect[2], rect[3]) and XShop.LH == data.layout.lineHeight and XMVWindow.PADDING == data.layout.padding and XItemMarks.onekey_grades().map(func(row): return row.text) == data.layout.commands, [shop.onekey_win.size, data.layout])
	shop.queue_free()
	var tilemap := MVTilemap.new()
	tilemap.setup(XDB.map(4), false)
	for c in data.passability:
		var actual_dirs := []
		for d in [2, 4, 6, 8]:
			var dest := Vector2i(int(c.x), int(c.y)) + MVCharacter.dir_offset(d)
			actual_dirs.append(tilemap.is_passable(int(c.x), int(c.y), d) and tilemap.is_passable(dest.x, dest.y, MVCharacter.reverse_dir(d)))
		check("return_tile_oracle_%d_%d" % [int(c.x), int(c.y)], actual_dirs == c.dirs, [actual_dirs, c.dirs])
	tilemap.free()
	check("return_fix_only_seventh", MVInterpreter.TRANSFER_FIX == {"61:9:4:12:18": Vector2i(14, 23)})
	await frames()
