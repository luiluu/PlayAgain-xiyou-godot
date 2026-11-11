extends Node
## 【cc·悟空·未经审查】v0.62 宝宝路线号角商店全部角色免费（XBabyAllActors，installBabyAllActorsRuntime）对照
## tests/fixtures/baby_all_actors_oracle.json（mv_oracle/baby_all_actors_probe.cjs 在 v0.62.12 新源量：新局队伍 1/8/9/10，
## 真实 Scene_Shop.prepare 整条链改出的商品表、免费期间号角的额外货币买入价、超强者开放、号角→角色）。另验领取一次、每次 1 支、
## 商店关掉后价格还原、开关 ENABLED 关掉回 v0.28。
const FIXTURE := "res://tests/fixtures/baby_all_actors_oracle.json"
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> bool:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail).left(600))
	return ok


func _ready() -> void:
	XCanglong.original_data()  # 按原版比：漩涡二阶段、苍龙重做与解放（O-待定）关掉，新行为由 xiyou_rift2_canglong 核
	_run.call_deferred()


func _state() -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	s.map_id = 4
	s.party.clear()
	s.battle_slots.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	return s


func _goods(s: XState, goods: Array) -> Array:
	var r := XBabyAllActors.prepare(s, goods)
	XBabyAllActors.free_open = r[1]
	var out := XItemMarks.shop_goods(r[0], s.map_id)
	return [out, r[1]]


func _ints(a: Array) -> Array:
	return a.map(func(g): return (g as Array).map(func(v): return int(v)))


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("fixture", ref is Dictionary and ref.cases.size() == 6, FIXTURE):
		return _finish()
	var c := {}
	for k in ref.cases:
		check(k.id + ".clean", k.errors.is_empty(), k.errors)
		c[k.id] = k
	# 号角 → 角色
	var hm: Dictionary = c.horn_actor.observed
	var bad := []
	for k in hm:
		var got := XBabyAllActors.horn_actor(XDB.rec("Items", int(k)))
		if got != int(hm[k]):
			bad.append([k, got, hm[k]])
	check("horn_actor", bad.is_empty(), bad)
	for id in ["off", "on", "on.no_horn", "on.owned"]:
		var o: Dictionary = c[id].observed
		var set: Dictionary = c[id].setup
		var s := _state()
		s.switches[XBabyAllActors.SWITCH] = bool(set.baby)
		if set.has("saved"):
			s.saved_actors.assign(set.saved.map(func(v): return int(v)))
			XBabyAllActors.taken(s).append_array(set.taken.map(func(v): return int(v)))
			s.variables[int(set.recruitedVar)] = 1
			s.gain_item(int(set.bag), 1)
		var g := _goods(s, set.goods)
		check(id + ".goods", _ints(g[0]) == _ints(o.goods), [g[0].size(), o.goods.size(), _ints(g[0]).slice(0, 6), _ints(o.goods).slice(0, 6)])
		check(id + ".free", g[1] == o.free)
		var r := XItemMarks.sell_rewards(XDB.rec("Items", 10))
		check(id + ".horn_price", r.buy_items.keys().map(func(k): return str(k)) == o.hornItemBuyPrice.keys() and r.buy_vars.is_empty() == o.hornVariableBuyPrice.is_empty(), [r.buy_items, o.hornItemBuyPrice])
		XBabyAllActors.free_open = false
		check(id + ".restored", XItemMarks.sell_rewards(XDB.rec("Items", 10)).buy_items.size() == o.restoredItemBuyPrice.size())
	var s2 := _state()
	check("super.off", XItemMarks.super_enabled(s2) == bool(c.super.observed.off))
	s2.switches[XBabyAllActors.SWITCH] = true
	check("super.on", XItemMarks.super_enabled(s2) == bool(c.super.observed.on))
	# 领取：买 1 支（免费、最多 1），之后不再列出
	var s := _state()
	s.switches[XBabyAllActors.SWITCH] = true
	var g: Array = _goods(s, [[0, 10, 0, 0]])[0]
	var horn := XDB.rec("Items", 10)
	check("buy.listed", g.any(func(r): return int(r[1]) == 10))
	check("buy.max1", XItemMarks.max_buy(s, horn, 0) == 1, XItemMarks.max_buy(s, horn, 0))
	check("buy.can", XItemMarks.can_buy(s, horn, 0))
	XItemMarks.buy(s, horn, 0, 1)
	var after := XBabyAllActors.bought(s, horn, g)
	check("buy.got", s.item_count(10) == 1 and s.item_count(188) == 0 and s.gold == 0, [s.item_count(10), s.gold])
	check("buy.taken", XBabyAllActors.taken(s) == [11] and not after.any(func(r): return int(r[1]) == 10), XBabyAllActors.taken(s))
	s.gain_item(10, -1)  # 用掉或卖掉也不再列
	check("buy.not_again", not _goods(s, [[0, 10, 0, 0]])[0].any(func(r): return int(r[1]) == 10))
	XBabyAllActors.free_open = false
	# 商店界面：关掉时还原
	var shop := XShop.new()
	shop.setup([[0, 10, 0, 0]], false)
	check("shop.free_open", XBabyAllActors.free_open == true)
	add_child(shop)
	await get_tree().process_frame
	shop.queue_free()
	await get_tree().process_frame
	check("shop.closed_restore", XBabyAllActors.free_open == false)
	# 开关关掉回 v0.28
	XBabyAllActors.ENABLED = false
	var s3 := _state()
	s3.switches[XBabyAllActors.SWITCH] = true
	var off := _goods(s3, [[0, 10, 0, 0], [0, 1, 0, 0]])
	check("off.unchanged", _ints(off[0]) == [[0, 10, 0, 0], [0, 1, 0, 0]] and off[1] == false, off)
	check("off.super_not_opened", XItemMarks.super_enabled(s3) == false)
	XBabyAllActors.ENABLED = true
	XBabyAllActors.free_open = false
	_finish()


func _finish() -> void:
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
