extends Node
## 天启篇读档重掷修复专项（XTianqi.SEED_FROM_SAVE）：装备重铸、锁词条重铸、异化词条兜底（create／attach）、异化重抽、通关抽角色候选
## 的随机都由存档种子＋对象标识＋随存档的次数派生。每处走真实写盘读档（XSave.save → XSave.load_slot）：
##   存→掷→读→再掷结果相同；连掷几次结果不全相同、读档后整串可复现；老档缺计数字段（以及缺 orbSeed）能初始化；
##   开关关掉回到全局随机（两次读档掷出的不同、不写计数字段）。

const CONFIG := "user://xiyou_tianqi_seed_fix_config.json"
const SLOT := 1
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state(line := "war") -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 0
	s.set_variable(20, 3)
	XState.current = s
	s.flags.tianqi["line"] = line
	XTianqiLine.progress(line, s)["stage"] = XTianqiLine.stage_done(line)
	return s


func _find_weapon() -> int:
	for r in XDB.table("Weapons"):
		if r is Dictionary and str(r.get("name", "")) != "":
			var tpl := XGear.template("weapon", int(r.id))
			if XQuality.grade(tpl) == 6 and XTianqiAffixRoll.tier_of(tpl) == 4 and not XEquipment.is_exclusive(tpl):
				return int(r.id)
	return 0


func _make(s: XState, wid: int) -> Dictionary:
	var it := XGear.create("weapon", wid, s)
	XTianqiAffixRoll.set_affixes(it, [{"key": str(XTianqiAffixRoll.layer_candidates(it, "base")[0]), "tier": 4, "grade": "normal", "extra": {}},
		{"key": str(XTianqiAffixRoll.layer_candidates(it, "special")[0]), "tier": 4, "grade": "normal", "extra": {}},
		{"key": "first_strike", "tier": 4, "grade": "normal", "extra": {}}])
	s.register_gear(it)
	s.gear.append(it)
	return it


func _gear(s: XState, iid: String) -> Dictionary:
	for g in s.gear:
		if str(g.get("instanceId", "")) == iid:
			return g
	return {}


func _save() -> bool:
	return XSave.save(SLOT)


func _load() -> XState:
	return XState.current if XSave.load_slot(SLOT) else null


## 改存档文件：去掉 fn 指明的字段，模拟老档
func _strip_file(fn: Callable) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(SLOT)))
	fn.call(d)
	XSave._write(XSave.path(SLOT), d)


# ---- 重铸 ----

## 读档后对那件装备连做 n 次重铸（单条第 2 条、锁第 0 条交替），返回每次的词条串
func _reforge_run(iid: String, n: int) -> Array:
	var s := _load()
	var out := []
	if s == null:
		return out
	s.gold = 10000000
	for k in n:
		var it := _gear(s, iid)
		var r: Dictionary = XTianqiReforge.reforge(s, it, 2) if k % 2 == 0 else XTianqiReforge.reforge_locked(s, it, 0)
		out.append(JSON.stringify(r.get("ok", r)))
	return out


func _reforge() -> void:
	var s := _state()
	var wid := _find_weapon()
	_check("rf_weapon", wid > 0)
	var it := _make(s, wid)
	var iid := str(it.instanceId)
	_check("rf_saved", _save())
	var a := _reforge_run(iid, 4)
	var b := _reforge_run(iid, 4)
	_check("rf_reload_same", a.size() == 4 and a == b, [a, b])
	_check("rf_runs_differ", a.size() == 4 and not (a[0] == a[2] and a[1] == a[3]), a)
	_check("rf_ok", a.all(func(x): return not x.contains("error")), a)
	var c := _reforge_run(iid, 2)
	_check("rf_prefix_same", c == a.slice(0, 2), [c, a])
	# 计数在装备上，存进存档后从那里接着掷
	var s2 := XState.current
	_check("rf_counter", int(_gear(s2, iid).get("tq_rng_n", -1)) == 2, _gear(s2, iid).get("tq_rng_n"))
	_check("rf_saved2", _save())
	var d := _reforge_run(iid, 1)
	var e := _reforge_run(iid, 1)
	_check("rf_after_save_same", not d.is_empty() and d == e, [d, e])
	_check("rf_continues", d == [a[2]], [d, a])
	# 另一件同一模板的装备：同次数不同结果
	var s3 := _load()
	var it2 := _make(s3, wid)
	s3.gold = 10000000
	var r2 := JSON.stringify(XTianqiReforge.reforge(s3, it2, 2).get("ok", {}))
	var it3 := _make(s3, wid)
	var r3 := JSON.stringify(XTianqiReforge.reforge(s3, it3, 2).get("ok", {}))
	var it4 := _make(s3, wid)
	var r4 := JSON.stringify(XTianqiReforge.reforge(s3, it4, 2).get("ok", {}))
	_check("rf_items_independent", not (r2 == r3 and r3 == r4), [r2, r3, r4])
	# 老档：存档里那件装备已重铸过、却没有 tq_rng_n（去掉字段），读档能补上从 0 开始、照样可复现
	_strip_file(func(dd): for g in dd.gear: (g as Dictionary).erase("tq_rng_n"))
	var raw = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(SLOT)))
	_check("rf_legacy_stripped", (raw.gear as Array).all(func(g): return not (g as Dictionary).has("tq_rng_n")))
	var leg := _reforge_run(iid, 1)
	_check("rf_legacy_init", leg.size() == 1 and not leg[0].contains("error") and int(_gear(XState.current, iid).get("tq_rng_n", -1)) == 1, leg)
	_check("rf_legacy_same", _reforge_run(iid, 1) == leg)
	var oid := iid
	# 更老的档：连 orbSeed 都没有（XState.from_dict 由存档内容算），两次读档也一样
	_strip_file(func(dd): dd.erase("orbSeed"))
	_check("rf_no_orb_same", _reforge_run(oid, 2) == _reforge_run(oid, 2))
	# 开关关掉：回到全局随机，不写计数
	XTianqi.SEED_FROM_SAVE = false
	_save()
	var off1 := _reforge_run(oid, 4)
	var off2 := _reforge_run(oid, 4)
	_check("rf_off_differs", off1 != off2, [off1, off2])
	var cnt := int(_gear(_load(), oid).get("tq_rng_n", 0))
	_reforge_run(oid, 2)
	_check("rf_off_no_counter", int(_gear(XState.current, oid).get("tq_rng_n", 0)) == cnt, cnt)
	XTianqi.SEED_FROM_SAVE = true


# ---- 异化：兜底选词条（create／attach 不传 rng）、重抽 ----

func _create_run(n: int) -> Array:
	var s := _load()
	var out := []
	for k in n:
		var r := XTianqiAlienGear.create(s, "armor", 52, "war", "shigu")
		out.append(str(r.ok.alien.affix) if r.has("ok") else "error")
	return out


func _reroll_run(iid: String, n: int) -> Array:
	var s := _load()
	var out := []
	if s == null:
		return out
	for k in n:
		var r := XAlienation.reroll(s, _gear(s, iid))
		out.append(str(r.ok.next) if r.has("ok") else JSON.stringify(r))
		XAlienation.resolve(s, false)  # 不要新的，留着原词条再抽
	return out


func _alien() -> void:
	XTianqiAlienGear.force_roll = -1.0
	XAlienation.force_roll = -1.0
	var fam := XTianqiAlienGear.family("war", "shigu")
	_check("al_family", fam.size() >= 3, fam)
	var s := _state()
	_save()
	var a := _create_run(6)
	var b := _create_run(6)
	_check("al_create_same", a.size() == 6 and a == b, [a, b])
	_check("al_create_varies", a.any(func(x): return x != a[0]), a)
	_check("al_create_in_family", a.all(func(x): return fam.has(x)), a)
	# 重抽：一件本体
	s = _load()
	var made: Dictionary = XTianqiAlienGear.create(s, "armor", 52, "war", "shigu", str(fam[0])).ok
	s.register_gear(made)
	s.gear.append(made)
	s.gain_item(XAlienation.stone_id(), 30)
	var iid := str(made.instanceId)
	_save()
	var r1 := _reroll_run(iid, 6)
	var r2 := _reroll_run(iid, 6)
	_check("al_reroll_same", r1.size() == 6 and r1 == r2, [r1, r2])
	_check("al_reroll_varies", r1.any(func(x): return x != r1[0]) and r1.all(func(x): return fam.has(x) and x != str(fam[0])), r1)
	_check("al_reroll_prefix", _reroll_run(iid, 3) == r1.slice(0, 3))
	_check("al_reroll_counter", int(_gear(XState.current, iid).get("tq_rng_n", -1)) == 3, _gear(XState.current, iid))
	# 老档：存档里那件没有 tq_rng_n（随机身份还在），从 0 接着掷，和第一次读档一样
	_save()
	_strip_file(func(dd): for g in dd.gear: (g as Dictionary).erase("tq_rng_n"))
	var raw = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(SLOT)))
	_check("al_legacy_stripped", (raw.gear as Array).all(func(g): return not (g as Dictionary).has("tq_rng_n")))
	var leg := _reroll_run(iid, 2)
	_check("al_legacy_init", leg == r1.slice(0, 2) and int(_gear(XState.current, iid).get("tq_rng_n", -1)) == 2, [leg, r1])
	# 测试钩子 force_roll 照旧优先
	XAlienation.force_roll = 0.0
	var fr := _reroll_run(iid, 1)
	XAlienation.force_roll = -1.0
	_check("al_force_roll", fr == [str(fam.filter(func(k): return k != str(fam[0]))[0])], fr)
	# 开关关掉
	XTianqi.SEED_FROM_SAVE = false
	_save()
	var o1 := _reroll_run(iid, 6) + _create_run(6)
	var o2 := _reroll_run(iid, 6) + _create_run(6)
	_check("al_off_differs", o1 != o2, [o1, o2])
	var n_saved := int(_gear(_load(), iid).get("tq_rng_n", 0))
	_reroll_run(iid, 2)
	_check("al_off_no_counter", int(_gear(XState.current, iid).get("tq_rng_n", 0)) == n_saved, n_saved)
	XTianqi.SEED_FROM_SAVE = true


# ---- 随机身份 tq_seed_id：进出仓库、重编号不换流；复制品拿新号 ----

func _reforge_once(s: XState, it: Dictionary) -> String:
	s.gold = 10000000
	return JSON.stringify(XTianqiReforge.reforge(s, it, 2).get("ok", {}))


func _reroll_once(s: XState, it: Dictionary) -> String:
	var r := XAlienation.reroll(s, it)
	XAlienation.resolve(s, false)
	return str(r.ok.next) if r.has("ok") else JSON.stringify(r)


func _new_gear(s: XState, before: Array) -> Dictionary:
	for g in s.gear:
		if not before.any(func(x): return is_same(x, g)):
			return g
	return {}


func _seed_ids() -> void:
	XStarWarehouse.path_override = ""
	XStarWarehouse._loaded_path = "<unloaded>"
	var s := _state()
	var it := _make(s, _find_weapon())
	if XStarWarehouse.push_dct(it):  # 这把带「不可存放」标签：测试件去掉它（只测随机身份，不测存放规则）
		if it.get("meta") is Dictionary:
			(it.meta as Dictionary).erase(XStarWarehouse.PUSH_DCT)
		it["note"] = str(it.get("note", "")).replace("<" + XStarWarehouse.PUSH_DCT + ">", "")
	_check("sw_storable", not XStarWarehouse.push_dct(it))
	var iid := str(it.instanceId)
	var fam := XTianqiAlienGear.family("war", "shigu")
	var al: Dictionary = XTianqiAlienGear.create(s, "armor", 52, "war", "shigu", str(fam[0])).ok
	s.register_gear(al)
	s.gear.append(al)
	s.gain_item(XAlienation.stone_id(), 30)
	var aid := str(al.instanceId)
	var uid0 := str(al.alien.uid)
	_save()
	# 基准：读档直接掷（第一次掷时才分配随机身份）
	s = _load()
	var base_rf := _reforge_once(s, _gear(s, iid))
	var base_al := _reroll_once(s, _gear(s, aid))
	var sid := str(_gear(s, iid).get("tq_seed_id", ""))
	_check("sid_assigned", XRandomStream.valid_hex(sid) and XRandomStream.valid_hex(str(_gear(s, aid).get("tq_seed_id", ""))) and sid != str(_gear(s, aid).tq_seed_id), [sid, _gear(s, aid).get("tq_seed_id")])
	# 读档 → 存进星辰仓库再取出（instanceId 重编、异化 uid 重分）→ 掷：结果不变
	s = _load()
	for iid_x in [iid, aid]:
		var g := _gear(s, iid_x)
		_check("star_deposit_%s" % iid_x, XStarWarehouse.deposit_gear(s, g) == "")
		var before := s.gear.duplicate()
		_check("star_withdraw_%s" % iid_x, XStarWarehouse.withdraw_gear(s, g))
	var w_rf: Dictionary = s.gear.filter(func(g): return int(g.base) == int(it.base) and str(g.kind) == "weapon")[0]
	var w_al: Dictionary = s.gear.filter(func(g): return XTianqiAlienGear.is_tq(g))[0]
	_check("star_renumbered", str(w_rf.instanceId) != iid and str(w_al.instanceId) != aid and str(w_al.alien.uid) != uid0, [w_rf.instanceId, w_al.instanceId, w_al.alien.uid])
	_check("star_reforge_same", _reforge_once(s, w_rf) == base_rf, [base_rf])
	_check("star_reroll_same", _reroll_once(s, w_al) == base_al, [base_al])
	_check("star_sid_kept", str(w_rf.get("tq_seed_id", "")) == sid)
	# 普通仓库：存进去、存档、读档、取出再掷，结果也不变
	s = _load()
	XWarehouse.create(s, "<种子测试仓:99>")
	var g2 := _gear(s, iid)
	_check("wh_deposit", XWarehouse.deposit(s, "weapon", g2))
	_save()
	s = _load()
	var stored: Dictionary = (XWarehouse.current(s).items.weapon as Array).filter(func(e): return e is Dictionary and str(e.get("instanceId", "")) == iid)[0]
	_check("wh_withdraw", XWarehouse.withdraw(s, "weapon", stored))
	_check("wh_reforge_same", _reforge_once(s, _gear(s, iid)) == base_rf)
	_reroll_once(s, _gear(s, aid))
	# 同一档里分配的号各不相同、存档里不会出现两件同号
	_save()
	var raw = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(SLOT)))
	var ids := (raw.gear as Array).map(func(g): return str(g.get("tq_seed_id", ""))).filter(func(x): return x != "")
	var uniq := {}
	for x in ids:
		uniq[x] = true
	_check("sid_unique", ids.size() >= 2 and uniq.size() == ids.size(), ids)
	# 复制路径：云裳发货（spec 复制）、仓库原版复制（O 开关关时被吞噬占用的武器多出一份）不带号，要用时拿新号
	s = _load()
	var spec := (_gear(s, iid) as Dictionary).duplicate(true)
	spec["_yunUid"] = "seed-fix-test"
	var before2 := s.gear.duplicate()
	XYunshangOrders.grant_spec(s, spec)
	var copy := _new_gear(s, before2)
	_check("yun_copy_no_sid", not copy.is_empty() and not copy.has("tq_seed_id"), copy.keys())
	_reforge_once(s, copy)
	_check("yun_copy_new_sid", XRandomStream.valid_hex(str(copy.get("tq_seed_id", ""))) and str(copy.tq_seed_id) != sid)
	var crown_spec := {"spec": (_gear(s, iid) as Dictionary).duplicate(true), "bonus": 0.0, "removed": false}
	var before3 := s.gear.duplicate()
	XDemonCrown._grant(s, crown_spec, "seed-fix-crown")
	var crown := _new_gear(s, before3)
	_check("crown_copy_no_sid", not crown.is_empty() and not crown.has("tq_seed_id"))
	# 仓库原版复制：吞噬异化占着的武器
	var donor := _gear(s, iid)
	var sw := _gear(s, aid) if not _gear(s, aid).is_empty() else (s.gear.filter(func(g): return XTianqiAlienGear.is_tq(g))[0] as Dictionary)
	XAlienation.mark(sw).affix = "swallow"
	XAlienation.mark(sw).config = {"donorId": str(donor.instanceId)}
	_check("dup_reserved", XAlienation.reserved(s, donor))
	XWarehouse.create(s, "<种子测试仓:99>")
	XWarehouse.o_reserved_no_dup = false
	var n0: int = (XWarehouse.current(s).items.weapon as Array).size()
	XWarehouse.deposit(s, "weapon", donor)
	XWarehouse.o_reserved_no_dup = true
	var wl: Array = XWarehouse.current(s).items.weapon
	_check("dup_copy_no_sid", wl.size() == n0 + 1 and not (wl[-1] as Dictionary).has("tq_seed_id") and donor.has("tq_seed_id"), wl.size())
	XStarWarehouse.path_override = ""
	XStarWarehouse._loaded_path = "<unloaded>"
	if FileAccess.file_exists(XStarWarehouse.path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(XStarWarehouse.path()))


# ---- 通关抽角色候选 ----

func _offer_run() -> Array:
	var s := _load()
	return XTianqi.draw_offer(s) if s != null else []


func _offer() -> void:
	var s := _state()
	s.set_variable(20, 11)  # 两次可抽
	_check("of_ready", XTianqi.draw_ready(s))
	s.flags.tianqi.erase("offer")
	_save()
	var a := _offer_run()
	var b := _offer_run()
	_check("of_same", not a.is_empty() and a == b, [a, b])
	# 老档、更老的档（没有 orbSeed）
	_strip_file(func(dd): dd.erase("orbSeed"))
	_check("of_no_orb_same", _offer_run() == _offer_run())
	# 第二次抽：收下一位后，下一次候选也是读档不变
	s = _load()
	var o := XTianqi.draw_offer(s)
	_check("of_take", XTianqi.take_draw(s, int(o[0])))
	_save()
	var c := _offer_run()
	var d := _offer_run()
	_check("of_second_same", not c.is_empty() and c == d, [c, d])
	# 两次的种子不同（同一池子洗出来的顺序不同）
	var pool := range(40)
	var p0 := pool.duplicate()
	var p1 := pool.duplicate()
	var g0 := RandomNumberGenerator.new()
	g0.seed = XRandomStream.parse64(XRandomStream.derive(XRandomStream.hex64(int(s.orb_seed)), "tianqi|offer|0"))
	var g1 := RandomNumberGenerator.new()
	g1.seed = XRandomStream.parse64(XRandomStream.derive(XRandomStream.hex64(int(s.orb_seed)), "tianqi|offer|1"))
	XTianqi._shuffle(p0, g0)
	XTianqi._shuffle(p1, g1)
	_check("of_draws_independent", p0 != p1)
	# 开关关掉：至少有一次读档候选不同（池子够大才比，池子小于等于候选数时整池原样返回）
	XTianqi.SEED_FROM_SAVE = false
	var runs := []
	for k in 8:
		runs.append(_offer_run())
	XTianqi.SEED_FROM_SAVE = true
	_check("of_off_differs", runs.any(func(x): return x != runs[0]), runs)


func _run() -> void:
	XMessageBox.auto = true
	seed(20261114)
	XSave.dir_override = "user://test_xiyou_tianqi_seed_fix"
	XConfig.path_override = ProjectSettings.globalize_path(CONFIG)
	XConfig._loaded_path = "<unloaded>"
	_reforge()
	_alien()
	_offer()
	_seed_ids()
	XTianqi.SEED_FROM_SAVE = true
	XSave.remove(SLOT)
	XSave.dir_override = ""
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig.path_override = ""
	XConfig._loaded_path = "<unloaded>"
	var passed := results.filter(func(x): return x.passed).size()
	for x in results:
		if not x.passed:
			print("FAIL ", x.name, " ", JSON.stringify(x.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
