extends Node
## 玩家反馈 v0.01.10（安卓）：强退后重进读档，云裳装备页全空。
## 夹具：云裳穿满一身（含账本领来的天衣，带 _yunUid），真写盘；再把云裳订单账本 yunshang_orders_v1.json 改成与存档对不上的各种样子
## （强退时两份文件写入先后不一致、同一局存在两格、账本比存档新／旧），冷启动读档后逐格核对装备。

var results := []
const SILK := 2942


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(2000))
	return ok


func _ready() -> void:
	_run.call_deferred()


static func _equips(a: XActor) -> Array:
	return a.equips.map(func(e): return int(e.base) if e is Dictionary else 0)


static func _uids(s: XState) -> Array:
	var out := []
	for e in s.actor(XYunshang.ACTOR).raw_equip_list():
		if str(e.get("_yunUid", "")) != "":
			out.append(str(e._yunUid))
	return out


## 云裳 55 级、进阶 2，账本里做两件天衣（一件穿上、一件留背包），其余空栏挑数据库里第一件穿得上的
func _build(stage := 2, robes := 2) -> XState:
	var s := XState.new_game(3, 1, [8])
	XState.current = s
	s.actor_max_level = 99
	XYunshang.recruit(s)
	var ys: XActor = s.actor(XYunshang.ACTOR)
	ys.change_level_mv(55)
	if stage > 0:
		s.actor_advance[XYunshang.ACTOR] = stage
	XYunshang.sync(ys)
	for n in robes:
		s.gain_item(SILK, XYunshangOrders.COST)
		var err := XYunshangOrders.submit(s)
		check("setup.submit%d" % n, err == "", err)
		XYunshangOrders.start_battle()
		for t in XYunshangOrders.PROGRESS:
			XYunshangOrders.progress(s, "t%d:%d" % [n, t])
		var err2 := XYunshangOrders.claim(s)
		check("setup.claim%d" % n, err2 == "", err2)
	var robe: Dictionary = XYunshangOrders.owned(s)[0]
	check("setup.robe_equip", XEquipment.change(s, ys, ys.equip_slots().find(int(robe.etypeId)), robe))
	var relic := XGear.template("armor", XYunshang.RELIC)
	s.register_gear(relic)
	s.gear.append(relic)
	XEquipment.change(s, ys, ys.equip_slots().find(int(relic.etypeId)), relic)
	_fill(s, ys)
	return s


static func _fill(s: XState, a: XActor) -> void:
	for kind in ["weapon", "armor"]:
		var table: Array = XDB.table("Weapons" if kind == "weapon" else "Armors")
		for rec in table:
			if not rec is Dictionary or str(rec.get("name", "")) == "":
				continue
			var empty := range(a.equips.size()).filter(func(i): return a.equips[i] == null)
			if empty.is_empty():
				return
			var e := XGear.template(kind, int(rec.id))
			for i in empty:
				if XEquipment.fits(a, i, e):
					s.register_gear(e)
					s.gear.append(e)
					if XEquipment.change(s, a, i, e):
						break


## 丢掉账本的内存缓存（同 XYunshangOrders.reload）。不直接调 XYunshangOrders.reload()：从类名调它会被当成 Script.reload()，
## 整个脚本重编译、静态开关全回默认值（KEEP_WORN_ON_LOAD 设 false 就白设了）
static func _drop_ledger_cache() -> void:
	XYunshangOrders._ledger = null
	XYunshangOrders._loaded_path = "<unloaded>"


func _ledger_text() -> String:
	return XSaveSeal.read_text(XYunshangOrders.path())


func _write_ledger(text: String) -> void:
	XSaveSeal.store(XYunshangOrders.path(), text)
	_drop_ledger_cache()


func _cold_load(release: bool) -> XState:
	ReleaseEntry.simulate_release = release
	XState.current = null
	_drop_ledger_cache()
	if not XSave.load_slot(1):
		return null
	return XState.current


func _run() -> void:
	XSave.dir_override = OS.get_user_data_dir().path_join("test_yunshang_gear_load_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(XSave.dir_override)
	XYunshangOrders.path_override = XSave.dir_override.path_join(XYunshangOrders.FILE)
	XConfig.path_override = XSave.dir_override.path_join("options.json")
	var saved_release := ReleaseEntry.simulate_release
	var s := _build()
	var ys: XActor = s.actor(XYunshang.ACTOR)
	var want := _equips(ys)
	var worn_uid: String = _uids(s)[0] if not _uids(s).is_empty() else ""
	check("setup.full", want.filter(func(b): return b > 0).size() >= 10 and worn_uid != "", [want, worn_uid])
	check("save_slot", XSave.save(1))
	var ledger_at_save := _ledger_text()
	var profile_id := str(s.flags.get(XYunshangOrders.PROFILE_FLAG, ""))
	var seq := int(s.flags.get(XYunshangOrders.SEQ_FLAG, 0))
	var cases := {}
	# 1. 账本与存档一致
	cases["same"] = ledger_at_save
	# 2. 账本比存档新：存档后又做了一件（只扣天丝）没存就强退
	var l2: Dictionary = JSON.parse_string(ledger_at_save)
	(l2.profiles[profile_id].journal as Array).append({"item": SILK, "delta": -15})
	cases["newer_delta"] = JSON.stringify(l2)
	# 3. 账本比存档新：存档后把穿着的那件天衣卖了／存进星级仓库（记了 remove）没存就强退
	var l3: Dictionary = JSON.parse_string(ledger_at_save)
	(l3.profiles[profile_id].journal as Array).append({"remove": worn_uid, "instance": "", "baseId": 0})
	cases["newer_remove_worn"] = JSON.stringify(l3)
	# 3b. 同上，但卖掉的是背包里那件：读档照原版从背包移除（防复制不受影响）
	var bag_uid := str(XYunshangOrders.owned(s)[0].get("_yunUid", "")) if not XYunshangOrders.owned(s).is_empty() else ""
	check("setup.bag_robe", bag_uid != "" and bag_uid != worn_uid, [bag_uid, worn_uid])
	var l3b: Dictionary = JSON.parse_string(ledger_at_save)
	(l3b.profiles[profile_id].journal as Array).append({"remove": bag_uid, "instance": "", "baseId": 0})
	cases["newer_remove_bag"] = JSON.stringify(l3b)
	# 4. 账本比存档旧（日志比 _yunSeq 短：账本回到了 .bak）
	var l4: Dictionary = JSON.parse_string(ledger_at_save)
	l4.profiles[profile_id].journal = (l4.profiles[profile_id].journal as Array).slice(0, maxi(0, seq - 3))
	cases["older_short"] = JSON.stringify(l4)
	# 5. 账本里没有本档这条（换机、清数据、导入存档）
	var l5: Dictionary = JSON.parse_string(ledger_at_save)
	l5.profiles.erase(profile_id)
	cases["missing_profile"] = JSON.stringify(l5)
	# 6. 账本 stage 与存档对不上（0）
	var l6: Dictionary = JSON.parse_string(ledger_at_save)
	l6.profiles[profile_id].stage = 0
	cases["stage0"] = JSON.stringify(l6)
	# 7. 账本文件不在
	cases["no_file"] = ""
	# 8. 账本坏了
	cases["corrupt"] = "{\"version\": 2, \"profi"
	# 9. 存档里的 _yunSeq 被回到 0（旧档），账本整份重放
	cases["seq0"] = ledger_at_save
	for release in [false, true]:
		for k in cases:
			var tag := ("release." if release else "dev.") + str(k)
			if k == "no_file":
				DirAccess.remove_absolute(XYunshangOrders.path())
				_drop_ledger_cache()
			else:
				_write_ledger(cases[k])
			if k == "seq0":
				var d: Dictionary = JSON.parse_string(XSaveSeal.read_text(XSave.path(1)))
				d.flags[XYunshangOrders.SEQ_FLAG] = 0
				XSaveSeal.store(XSave.path(1), JSON.stringify(d))
			var t := _cold_load(release)
			if not check(tag + ".loaded", t != null):
				continue
			var got := _equips(t.actor(XYunshang.ACTOR))
			check(tag + ".equips", got == want, {"got": got, "want": want, "bag_robes": XYunshangOrders.owned(t).size()})
			if k == "newer_remove_worn":
				check(tag + ".kept_logged", XYunshangOrders.kept_on_load == [worn_uid], XYunshangOrders.kept_on_load)
				check(tag + ".seq_advanced", int(t.flags.get(XYunshangOrders.SEQ_FLAG, 0)) == seq + 1, t.flags.get(XYunshangOrders.SEQ_FLAG))
			var bag_left := XYunshangOrders.owned(t).filter(func(e): return str(e.get("_yunUid", "")) == bag_uid).size()
			check(tag + ".bag_robe", bag_left == (0 if k == "newer_remove_bag" else 1), bag_left)
			# 读完进一场战斗的开战刷新（加减状态会走 release_to_party）
			var y2: XActor = t.actor(XYunshang.ACTOR)
			y2.add_state(4)
			y2.remove_state(4)
			check(tag + ".equips_after_refresh", _equips(y2) == want, _equips(y2))
			# 还原第 1 格到原样，下一种情况从同一个起点读
			XState.current = s
			XSave.save(1)
	# 反向：关掉 KEEP_WORN_ON_LOAD 回到原版，穿着的天衣被读档重放卸下移除（专项咬得住）
	XYunshangOrders.KEEP_WORN_ON_LOAD = false
	_write_ledger(cases["newer_remove_worn"])
	var r := _cold_load(true)
	check("switch_off.worn_removed", r != null and _equips(r.actor(XYunshang.ACTOR)) != want and _uids(r).is_empty(), _equips(r.actor(XYunshang.ACTOR)) if r != null else null)
	XYunshangOrders.KEEP_WORN_ON_LOAD = true
	XState.current = s
	XSave.save(1)
	_advance_case()
	ReleaseEntry.simulate_release = saved_release
	for fname in DirAccess.get_files_at(XSave.dir_override):
		DirAccess.remove_absolute(XSave.dir_override.path_join(fname))
	DirAccess.remove_absolute(XSave.dir_override)
	XSave.dir_override = ""
	XYunshangOrders.path_override = ""
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## co 甲档核查 P2：存档时穿着天衣，之后卸下拿去进阶、不存档，强退再读旧档——进阶次数随账本保留，被消耗的那件不能也留着（白拿一件）。
## 真调 XYunshangOrders.advance；新账本带 src "advance"，旧账本（本修复前写的，没有来源）按结构认，两种都核
func _advance_case() -> void:
	for legacy in [false, true]:
		var tag := "advance." + ("legacy_ledger" if legacy else "tagged")
		var s := _build(0, 3)
		var ys: XActor = s.actor(XYunshang.ACTOR)
		var worn: String = _uids(s)[0] if not _uids(s).is_empty() else ""
		s.gain_item(XYunshangOrders.SHARD, 50)
		check(tag + ".setup", worn != "" and XYunshang.stage(ys) == 0 and XYunshangOrders.owned(s).size() == 2, [worn, XYunshang.stage(ys)])
		check(tag + ".save", XSave.save(1))
		var slot := ys.equips.find_custom(func(e): return e is Dictionary and str(e.get("_yunUid", "")) == worn)
		check(tag + ".unequip", XEquipment.change(s, ys, slot, null))
		var err := XYunshangOrders.advance(s, XYunshangOrders.owned(s))
		check(tag + ".advanced", err == "" and XAdvance.rank(s, XYunshang.ACTOR) == 1 and XYunshangOrders.owned(s).is_empty(), [err, XAdvance.rank(s, XYunshang.ACTOR)])
		if legacy:  # 抹掉来源，模拟 v0.01.10 写下的账本
			var l: Dictionary = JSON.parse_string(_ledger_text())
			for p in l.profiles.values():
				for op in p.journal:
					op.erase("src")
			_write_ledger(JSON.stringify(l))
		for release in [false, true]:
			var t2 := _cold_load(release)
			var tg := tag + (".release" if release else ".dev")
			if not check(tg + ".loaded", t2 != null):
				continue
			check(tg + ".stage_kept", XAdvance.rank(t2, XYunshang.ACTOR) == 1, XAdvance.rank(t2, XYunshang.ACTOR))
			check(tg + ".consumed_worn_removed", XYunshangOrders.find_uid(t2, worn).is_empty() and XYunshangOrders.owned(t2).is_empty(), [_uids(t2), XYunshangOrders.owned(t2).size()])
			check(tg + ".not_kept", not XYunshangOrders.kept_on_load.has(worn), XYunshangOrders.kept_on_load)
			check(tg + ".shards_spent", t2.item_count(XYunshangOrders.SHARD) == 0, t2.item_count(XYunshangOrders.SHARD))
		XState.current = s
	# 结构识别不误伤：卖出的 remove（单条、前面没有碎片扣除）紧跟在进阶之后也不算进阶消耗
	var j := [{"item": XYunshangOrders.SHARD, "delta": -50}, {"remove": "a"}, {"remove": "b"}, {"remove": "c"}, {"remove": "sold"}, {"item": SILK, "delta": 2}, {"remove": "sold2"}]
	check("advance.structure", XYunshangOrders.advance_removes(j).keys() == [1, 2, 3], XYunshangOrders.advance_removes(j))
	# 带来源的照来源认（不靠前面的碎片扣除）
	check("advance.tagged", XYunshangOrders.advance_removes([{"remove": "x", "src": "advance"}, {"remove": "y"}]).keys() == [0])
