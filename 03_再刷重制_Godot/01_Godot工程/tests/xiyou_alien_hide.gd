extends Node
## 异化隐藏（O-283，XAlienHide＋XAlienBattle.hidden）：对照 mv_oracle/alien_hide_probe.cjs（generated/oracle/alien_hide.json），
## 参照在装与不装正式 v0.58 installAlienationHide 的两个引擎里各量一次（hide.*／plain.*）；重制分别用「发行模拟」（ReleaseEntry.simulate_release，
## RELEASE_HIDE 默认 true）和开发版默认（两个开关都不生效）跑同样的用例。
## - 开关：HIDDEN_V058 默认 false、RELEASE_HIDE 默认 true；开发版不隐藏，发行模拟隐藏，RELEASE_HIDE=false 时发行也不隐藏，HIDDEN_V058=true 时开发版也隐藏。
## - menu：主菜单指令名（XMenu.commands）与参照一致。
## - gain：六件物品各得一件后背包里的数量、列表（物品 XItemMarks.apply_list，装备 XItemScene.bag_gear）。
## - raw：直接写进背包（模拟没迁移的旧档）后物品列表看不看得见。原版 hasItem 隐藏时恒 false；重制不另包（读档迁移已移走，背包里不会再有），只比列表和数量。
## - equip：角色 1（30 级、补上残响的武器／防具类型）对残响本体的 can_equip。
## - shop：商品表经 XItemMarks.shop_goods 后剩哪些。
## - migrate：同参照布置背包与身上，存档往返（from_dict 里迁移）后比背包物品、标记、还原的异化装备、残响件数（原版留在队伍容器、重制移进归档）、
##   卸下记录、归档数量。
## - 重制另补：仓库迁移、迁移只跑一次、身上普通异化装备还原后仍穿着、星级仓库取出、词缀不收残响、得到减少照常。
const ORACLE := "oracle/alien_hide.json"
const LEVEL := 30
var results := []
var _added_traits := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(900))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var ref = XDB.load_json(ORACLE)
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		get_tree().quit.call_deferred(1)
		return
	_switches()
	_allow_traits()
	for c in ref.cases:
		if not check(str(c.id) + ".oracle_clean", (c.errors as Array).is_empty(), c.errors):
			continue
		var id := str(c.id)
		var hide := id.begins_with("hide.")
		_set_mode(hide)
		match id.get_slice(".", 1):
			"menu": _menu(c, hide)
			"gain": _gain(c, hide)
			"raw": _raw(c, hide)
			"equip": _equip(c, hide)
			"shop": _shop(c, hide)
			"migrate": _migrate(c, hide)
	_set_mode(false)
	_extra()
	_set_mode(false)
	for t in _added_traits:
		(XDB.rec("Actors", 1).traits as Array).erase(t)
	XState.current = null
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _set_mode(hide: bool) -> void:
	XAlienBattle.HIDDEN_V058 = false
	XAlienBattle.RELEASE_HIDE = true
	ReleaseEntry.simulate_release = hide


func _switches() -> void:
	check("switch.defaults", XAlienBattle.HIDDEN_V058 == false and XAlienBattle.RELEASE_HIDE == true)
	_set_mode(false)
	check("switch.dev_open", not XAlienBattle.hidden() and not XAlienHide.active() and not XAlienHide.blocks_item(2872))
	_set_mode(true)
	check("switch.release_hidden", XAlienBattle.hidden() and XAlienHide.blocks_item(2872) and XAlienHide.blocks_base("armor", 7981))
	XAlienBattle.RELEASE_HIDE = false
	check("switch.release_hide_off", not XAlienBattle.hidden())
	_set_mode(false)
	XAlienBattle.HIDDEN_V058 = true
	check("switch.hidden_v058_dev", XAlienBattle.hidden())
	check("switch.not_hidden_ids", not XAlienHide.blocks_item(2874) and not XAlienHide.blocks_base("weapon", 7980) and not XAlienHide.blocks_base("armor", 3980))
	_set_mode(false)


## 同参照：给 $dataActors[1] 补上残响的武器／防具类型（51／52）
func _allow_traits() -> void:
	var tr: Array = XDB.rec("Actors", 1).traits
	for id in XAlienHide.WEAPON_BASES:
		_allow(tr, 51, int(XDB.rec("Weapons", id).wtypeId))
	for id in XAlienHide.ARMOR_BASES:
		_allow(tr, 52, int(XDB.rec("Armors", id).atypeId))


func _allow(tr: Array, code: int, id: int) -> void:
	if tr.any(func(t): return int(t.code) == code and int(t.dataId) == id):
		return
	var t := {"code": code, "dataId": id, "value": 1}
	tr.append(t)
	_added_traits.append(t)


func _state() -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	s.party.clear()
	s.battle_slots.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	s.items.clear()
	s.gear.clear()
	return s


func _item_list(s: XState) -> Array:
	var out := []
	for id in s.items:
		if s.item_count(int(id)) > 0:
			out.append({"rec": XDB.rec("Items", int(id)), "count": s.item_count(int(id))})
	return XItemMarks.apply_list(s, out).map(func(e): return int(e.rec.id)).filter(func(id): return XAlienHide.ITEM_IDS.has(id))


func _bases(list: Array, ids: Array) -> Array:
	var out := list.map(func(e): return int(e.base)).filter(func(b): return ids.has(b))
	out.sort()
	return out


func _menu(c: Dictionary, hide: bool) -> void:
	var names: Array = XMenu.commands().map(func(x): return x[0])
	check(str(c.id) + ".names", names == c.observed.names, [names, c.observed.names])
	check(str(c.id) + ".workshop", names.has("异化工坊") == bool(c.observed.hasWorkshop) and names.has("异化工坊") != hide)


func _gain(c: Dictionary, hide: bool) -> void:
	var s := _state()
	for id in XAlienHide.ITEM_IDS:
		s.gain_item(id, 1)
	for id in XAlienHide.WEAPON_BASES:
		s.gain_gear("weapon", id, 1)
	for id in XAlienHide.ARMOR_BASES:
		s.gain_gear("armor", id, 1)
	var o: Dictionary = c.observed
	var raw := {"items": XAlienHide.ITEM_IDS.map(func(id): return s.item_count(id)),
		"weapons": s.gear.filter(func(e): return e.kind == "weapon" and XAlienHide.WEAPON_BASES.has(int(e.base))).size(),
		"armors": s.gear.filter(func(e): return e.kind == "armor" and XAlienHide.ARMOR_BASES.has(int(e.base))).size()}
	check(str(c.id) + ".raw", JSON.stringify(raw) == JSON.stringify(_ints(o.raw)), [raw, o.raw])
	var listed := {"items": _item_list(s), "weapons": _bases(XItemScene.bag_gear("weapon"), XAlienHide.WEAPON_BASES),
		"armors": _bases(XItemScene.bag_gear("armor"), XAlienHide.ARMOR_BASES)}
	check(str(c.id) + ".listed", JSON.stringify(listed) == JSON.stringify(_ints(o.listed)), [listed, o.listed])
	check(str(c.id) + ".has", XAlienHide.ITEM_IDS.map(func(id): return s.item_count(id) > 0) == o.has, o.has)
	# 减少照常（原版只挡数量为正的 gainItem）
	s.items[2872] = 2
	s.gain_item(2872, -1)
	check(str(c.id) + ".lose_passes", s.item_count(2872) == 1)


func _raw(c: Dictionary, _hide: bool) -> void:
	var s := _state()
	s.items[2872] = 3
	s.items[2873] = 2
	check(str(c.id) + ".listed", _item_list(s) == _ints(c.observed.listed), [_item_list(s), c.observed.listed])
	check(str(c.id) + ".counts", [s.item_count(2872), s.item_count(2873)] == _ints(c.observed.counts), c.observed.counts)


func _equip(c: Dictionary, hide: bool) -> void:
	var s := _state()
	var a: XActor = s.actor(1)
	a.change_level(LEVEL)
	var o: Dictionary = c.observed
	check(str(c.id) + ".level", a._lv == int(o.level), [a._lv, o.level])
	var base_ok := a.can_equip(XGear.template("weapon", 3980))
	check(str(c.id) + ".shard_base", base_ok == bool(o.canEquipShardBase), [base_ok, o.canEquipShardBase])
	var armor_ok := XAlienHide.ARMOR_BASES.map(func(id): return a.can_equip(XGear.template("armor", id)))
	check(str(c.id) + ".armor_base", armor_ok == o.canEquipArmorBase, [armor_ok, o.canEquipArmorBase])
	# 残响实例（异化标记的）：原版隐藏与否都穿不上（不隐藏时是没配置的异化装备）；重制隐藏时 can_equip 挡下
	var shard: Dictionary = XAlienation.create(s, "w", 3980, "mob").ok
	if hide:
		check(str(c.id) + ".shard_instance", not a.can_equip(shard) and not bool(o.canEquipShard))


func _shop(c: Dictionary, _hide: bool) -> void:
	_state()
	var goods := [[0, 2872, 0, 0], [0, 2873, 0, 0], [1, 3980, 0, 0], [1, 3981, 0, 0], [2, 7980, 0, 0], [2, 7981, 0, 0], [0, 1, 0, 0]]
	var rows := XItemMarks.shop_goods(goods, 0).map(func(g): return ["i:", "w:", "a:"][int(g[0])] + str(int(g[1])))
	check(str(c.id) + ".listed", rows == c.observed.listed, [rows, c.observed.listed])


## 同参照的布置：背包能量 3、异化石 2、物品 1；背包异化 1042 逆骨、残刃、异化防具；身上武器栏残杖
func _layout(s: XState, armor_base: int) -> Dictionary:
	s.items[2872] = 3
	s.items[2873] = 2
	s.items[1] = 1
	var a: XActor = s.actor(1)
	a.change_level(LEVEL)
	var bag: Dictionary = XAlienation.create(s, "w", 1042, "mob", "inversebone").ok
	var shard: Dictionary = XAlienation.create(s, "w", 3980, "mob").ok
	var armor: Dictionary = XAlienation.create(s, "a", armor_base, "boss").ok
	var worn: Dictionary = XAlienation.create(s, "w", 3981, "mob").ok
	s.gear.append_array([bag, shard, armor])
	a.equips[0] = worn
	return {"bag": XAlienation.mark(bag).plainName, "armor": XAlienation.mark(armor).plainName}


func _roundtrip(s: XState) -> XState:
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	XState.current = back
	return back


func _migrate(c: Dictionary, hide: bool) -> void:
	var o: Dictionary = c.observed
	var s := _state()
	var plain := _layout(s, int(o.armorBase))
	var b := _roundtrip(s)
	var id := str(c.id)
	var items := {"1": b.item_count(1), "2872": b.item_count(2872), "2873": b.item_count(2873)}
	check(id + ".items", JSON.stringify(items) == JSON.stringify(_ints(o.items)), [items, o.items])
	check(id + ".marker", bool(b.flags.get(XAlienHide.MARKER, false)) == bool(o.marker))
	var stash = b.flags.get(XAlienHide.STASH_ITEMS)
	check(id + ".stash_items", JSON.stringify(_ints(stash)) == JSON.stringify(_ints(o.stashItems)), [stash, o.stashItems])
	if hide:
		var wl := XItemScene.bag_gear("weapon").map(func(e): return {"base": int(e.base), "alien": e.has("alien"), "plain": str(e.name) == str(plain.bag)})
		check(id + ".weapons", JSON.stringify(wl) == JSON.stringify(_ints(o.weaponsListed)), [wl, o.weaponsListed])
		var al := XItemScene.bag_gear("armor").filter(func(e): return int(e.base) == int(o.armorBase)) \
			.map(func(e): return {"base": int(e.base), "alien": e.has("alien"), "plain": str(e.name) == str(plain.armor)})
		check(id + ".armors", JSON.stringify(al) == JSON.stringify(_ints(o.armorsListed)), [al, o.armorsListed])
		var archived: Array = b.flags.get(XAlienHide.STASH_GEAR, [])
		var shards := archived.filter(func(e): return e.kind == "weapon" and XAlienHide.WEAPON_BASES.has(int(e.base))).size()
		check(id + ".shards_archived", shards == int(o.rawShards) and not b.gear.any(func(e): return XAlienHide.hidden_gear(e)), [shards, o.rawShards])
		var slot0 = b.actor(1).equips[0]
		check(id + ".slot0", (0 if not slot0 is Dictionary or slot0.is_empty() else int(slot0.base)) == int(o.slot0), slot0)
		var eq: Array = b.flags.get(XAlienHide.STASH_EQUIP, []).map(func(e): return {"actorId": int(e.actorId), "slot": int(e.slot), "baseId": int(e.base)})
		check(id + ".stash_equip", JSON.stringify(eq) == JSON.stringify(_ints(o.stashEquip)), [eq, o.stashEquip])
		# 原版先还原再归档（restoreAlien 在 isHiddenGear 之前）：归档的残响也去了异化标记，实例整件保留
		check(id + ".archived_kept_whole", archived.all(func(e): return e.has("instanceId") and not e.has("alien") and int(e.get(XAlienHide.RESTORED, 0)) == 1), archived)
	else:
		# 开发版：什么都不动，异化装备、残响照旧（原版不装隐藏模块时读档把没配置的残杖卸回背包，重制不卸，只比拥有的件）
		var owned := b.gear.duplicate()
		owned.append_array(b.actor(1).equip_list())
		var mine := owned.filter(func(e): return int(e.base) == 1042 or XAlienHide.WEAPON_BASES.has(int(e.base))).map(func(e): return {"base": int(e.base), "alien": e.has("alien"), "plain": false})
		mine.sort_custom(func(x, y): return x.base < y.base)
		check(id + ".weapons_owned", JSON.stringify(mine) == JSON.stringify(_ints(o.weaponsListed)), [mine, o.weaponsListed])
		check(id + ".armor_alien", b.gear.any(func(e): return int(e.base) == int(o.armorBase) and e.has("alien")) == not bool(o.armorsListed.is_empty()) and o.armorsListed[0].alien)
		check(id + ".no_stash", not b.flags.has(XAlienHide.STASH_GEAR) and not b.flags.has(XAlienHide.STASH_EQUIP))


## 重制另补的入口（参照没量）
func _extra() -> void:
	# 仓库：能量记数量移出、残响整件移出、普通异化装备还原留在仓库
	_set_mode(false)
	var s := _state()
	XWarehouse.create(s, "<仓库:999>")
	var w: Dictionary = s.warehouses["仓库"]
	var alien: Dictionary = XAlienation.create(s, "w", 1042, "mob", "inversebone").ok
	var plain_name := str(XAlienation.mark(alien).plainName)
	var shard: Dictionary = XAlienation.create(s, "a", 7980, "mob").ok
	w.items.item.append_array([2873, 1])
	w.qtty.item["2873"] = 5
	w.qtty.item["1"] = 2
	w.items.weapon.append(alien)
	w.items.armor.append(shard)
	w.currentCapacity = 9
	# 身上穿一件普通异化武器（不是残响）：还原后照旧穿着
	var a: XActor = s.actor(1)
	a.change_level(LEVEL)
	var worn: Dictionary = XAlienation.create(s, "w", 1042, "boss", "inversebone").ok
	a.equips[0] = worn
	s.alien_ledger = {"sequence": 9, "pending": {"uid": "alien-1"}, "recent": [{"name": "x"}], "metrics": {}}
	_set_mode(true)
	var b := _roundtrip(s)
	var bw: Dictionary = b.warehouses["仓库"]
	check("extra.warehouse_items", bw.items.item == [1] and int(bw.qtty.item.get("1", 0)) == 2 and not bw.qtty.item.has("2873"), bw)
	check("extra.warehouse_gear", bw.items.armor.is_empty() and bw.items.weapon.size() == 1 and not bw.items.weapon[0].has("alien") \
		and str(bw.items.weapon[0].name) == plain_name and int(bw.items.weapon[0].get(XAlienHide.RESTORED, 0)) == 1, bw.items)
	check("extra.warehouse_capacity", int(bw.currentCapacity) == 3, bw.currentCapacity)
	check("extra.warehouse_stash", int(b.flags[XAlienHide.STASH_ITEMS].get("2873", 0)) == 5 and (b.flags[XAlienHide.STASH_WAREHOUSE] as Array).size() == 2)
	var e0 = b.actor(1).equips[0]
	check("extra.worn_restored_kept", e0 is Dictionary and int(e0.base) == 1042 and not e0.has("alien"), e0)
	check("extra.pending_cleared", b.alien_ledger.pending == null and (b.alien_ledger.recent as Array).size() == 1)
	# 只跑一次：再读一次不重复累加
	var n_before := JSON.stringify(_ints(b.flags.get(XAlienHide.STASH_ITEMS)))
	b.items[2872] = 4  # 迁移后又出现（理论上拿不到；只看会不会再迁一次）
	var c := _roundtrip(b)
	check("extra.migrate_once", JSON.stringify(_ints(c.flags.get(XAlienHide.STASH_ITEMS))) == n_before and c.item_count(2872) == 4 and XAlienHide.last_report.is_empty(),
		[n_before, c.flags.get(XAlienHide.STASH_ITEMS), c.item_count(2872), XAlienHide.last_report])
	# 开发版读档不迁移、不打标记
	_set_mode(false)
	var d := _state()
	d.items[2872] = 2
	var d2 := _roundtrip(d)
	check("extra.dev_no_migrate", d2.item_count(2872) == 2 and not d2.flags.has(XAlienHide.MARKER))
	# 词缀不收残响（isValidItem），开发版照收
	check("extra.affix_dev", XGear.valid_affix("Weapons", 3980) == not XDB.rec("Weapons", 3980).is_empty())
	_set_mode(true)
	check("extra.affix_hidden", not XGear.valid_affix("Weapons", 3980) and not XGear.valid_affix("Armors", 7981) and XGear.valid_affix("Weapons", 1042) == XGear.valid_affix("Weapons", 1042))
	# 星级仓库：取出列表不列残响，残响取不出；取出的普通异化装备还原
	var sp := "user://alien_hide_star_%d.json" % (Time.get_ticks_usec() % 1000003)
	XStarWarehouse.path_override = ProjectSettings.globalize_path(sp)
	XStarWarehouse.o_save_now = true
	_set_mode(false)
	var t := _state()
	var g1: Dictionary = XAlienation.create(t, "w", 1042, "mob", "inversebone").ok
	var g2: Dictionary = XAlienation.create(t, "w", 3981, "mob").ok
	t.gear.append_array([g1, g2])
	check("extra.star_deposit", XStarWarehouse.deposit_gear(t, g1) == "" and XStarWarehouse.deposit_gear(t, g2) == "")
	_set_mode(true)
	var shown := XStarWarehouse.withdrawable_gear()
	check("extra.star_list", shown.size() == 1 and is_same(shown[0], g1), shown.size())
	check("extra.star_shard_blocked", not XStarWarehouse.withdraw_gear(t, g2) and t.gear.is_empty())
	check("extra.star_withdraw_restored", XStarWarehouse.withdraw_gear(t, g1) and t.gear.size() == 1 and not t.gear[0].has("alien"))
	_set_mode(false)
	check("extra.star_dev_lists_all", XStarWarehouse.withdrawable_gear().size() == 1)
	DirAccess.remove_absolute(XStarWarehouse.path())
	XStarWarehouse.path_override = ""
	# 兜底：没经迁移直接进背包的残响（如别处直接 append）装备列表也不列，开发版照列
	_set_mode(true)
	var u := _state()
	u.gear.append(XAlienation.create(u, "w", 3981, "mob").ok)
	check("extra.bag_gear_hidden", XItemScene.bag_gear("weapon").is_empty())
	_set_mode(false)
	check("extra.bag_gear_dev", XItemScene.bag_gear("weapon").size() == 1)
	# 主菜单「异化工坊」在发行模拟里点不到：commands 里没有
	_set_mode(true)
	check("extra.menu_release", not XMenu.commands().any(func(x): return x[1] == "alienation") and XMenu.commands().size() == XMenu.COMMANDS.size() - 1)


static func _ints(v):
	if v is Dictionary:
		var o := {}
		for k in v:
			o[str(k)] = _ints(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _ints(x))
	if v is float:
		return int(v)
	return v
