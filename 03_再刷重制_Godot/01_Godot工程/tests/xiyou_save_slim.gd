extends Node
## 【cc·未经审查】存档与本机缓存自动清理专项（XSaveSlim，Kyo 2026-11-14）。全部走真实写盘、真实读档（XSave.save → load_slot）。
## - 老档（旧写法写出的文件）读进来再存一次变瘦：瘦之前、瘦之后各读回，玩家可见的一切（背包、身上装备、仓库、金钱、物品、图鉴、
##   开关变量、角色能力值、新标记）一致，只差装备的 equipment.affixes 和已不存在装备的 seen。
## - 新开局档、天启篇档：同一份状态旧写法存一格、新写法存一格，读回一致；天启篇档读回后对同一件装备重铸、锁一条重铸、异化重抽，结果一致。
## - 备份：覆盖没瘦过的文件前留 before_slim.bak（与原文件逐字节相同）、瘦过的不再复制、又换成没瘦过的（导入）再存就换成新的；备份不了就不瘦。
## - 幂等：瘦过的读回再存，内容相同、没有东西可去。内存里的装备和标记不被改。
## - 各开关关掉回旧写法；星级仓库文件；导入前备份每格留 2 份；残留临时文件；日志。

const T := preload("res://modes/xiyou/core/tianqi_affix_table.gd")
var results := []
var _dir := ""


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(900))


func _text(p: String) -> String:
	return FileAccess.get_file_as_string(p)


func _read(slot: int):
	return JSON.parse_string(_text(XSave.path(slot))) if XSave.exists(slot) else null


func _switches(on: bool) -> void:
	XSaveSlim.GEAR_ROLL_TABLE = on
	XSaveSlim.SEEN_STALE = on
	XSaveSlim.STAR_WAREHOUSE = on
	XSaveSlim.IMPORT_BACKUPS = on
	XSaveSlim.TEMP_FILES = on


## 测试自己的遍历（不用 XSaveSlim 的）：所有带 instanceId 的字典
func _instances(v, out: Array) -> Array:
	if v is Dictionary:
		if v.has("instanceId"):
			out.append(v)
		for k in v:
			_instances(v[k], out)
	elif v is Array:
		for x in v:
			_instances(x, out)
	return out


func _affix_tables(v) -> int:
	return _instances(v, []).filter(func(e): return e.get("equipment") is Dictionary and e.equipment.has("affixes")).size()


## 存档内容里只允许差的两样去掉后的样子（深拷贝，不动原件）；saveCount 每存一次加一，不比
func _norm(d: Dictionary) -> Dictionary:
	var c: Dictionary = d.duplicate(true)
	var live := {}
	for e in _instances(c, []):
		live[str(e.instanceId)] = true
		if e.get("equipment") is Dictionary:
			e.equipment.erase("affixes")
	if c.get("seen") is Array:
		c.seen = (c.seen as Array).filter(func(k): return not str(k).begins_with("xg:") or live.has(str(k)))
		c.seen.sort()
	for k in ["saveSlim", "savedAt", "saveCount", "autoFromSlot"]:
		c.erase(k)
	return c


## 玩家可见的一切：存档内容（去掉只允许差的两样）＋读档后算出来的东西
func _visible(s: XState) -> Dictionary:
	var actors := {}
	for id in s.actors:
		var a: XActor = s.actors[id]
		actors[str(id)] = {"name": a.display_name(), "level": a.level, "hp": a.hp, "mp": a.mp,
			"params": range(8).map(func(i): return a.param(i)), "xparams": range(10).map(func(i): return a.xparam(i)),
			"sparams": range(10).map(func(i): return a.sparam(i)), "skills": a.skill_ids.duplicate(),
			"equips": a.equips.map(func(e): return null if e == null else [str(e.name), e.params, e.traits, str(e.description), XGear.quality(e)]),
			"suits": XEquipSuits.counts(a)}
	var bag := s.gear.map(func(e): return [str(e.instanceId), str(e.name), e.params, e.traits, str(e.description), int(e.get("price", 0)), XGear.quality(e), s.is_new(e)])
	var items := {}
	for id in s.items:
		items[str(id)] = [s.items[id], s.is_new(XDB.rec("Items", int(id)))]
	return {"dict": _norm(s.to_dict()), "actors": actors, "bag": bag, "items": items, "gold": s.gold,
		"party": s.party.duplicate(), "book": s.enemy_book, "achievements": s.achievements}


func _same(name: String, a, b) -> void:
	var ja := JSON.stringify(a)
	var jb := JSON.stringify(b)
	var at := 0
	while at < mini(ja.length(), jb.length()) and ja[at] == jb[at]:
		at += 1
	check(name, ja == jb, [ja.substr(maxi(0, at - 120), 300), jb.substr(maxi(0, at - 120), 300)])


func _with_tables(kind: String, want: int) -> Array:
	var out := []
	for r in XDB.table("Weapons" if kind == "weapon" else "Armors"):
		if r is Dictionary and str(r.get("name", "")) != "" and not (r.get("equipment", {}).get("affixes", []) as Array).is_empty() \
				and not XEquipment.is_exclusive(XGear.template(kind, int(r.id))) and not XAlienHide.blocks_base(kind, int(r.id)):
			out.append(int(r.id))
			if out.size() >= want:
				break
	return out


## 一份像玩了一阵的原版档：身上有初始装备，背包十几件带词缀选项表的装备，仓库两件，看过又卖掉的留下失效标记
func _old_state() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.map_id = 4
	s.gold = 123456
	s.gain_item(1, 7)
	for id in _with_tables("weapon", 8):
		s.gain_gear("weapon", id, 1)
	for id in _with_tables("armor", 8):
		s.gain_gear("armor", id, 1)
	for e in s.gear:
		s.mark_seen(e)
	s.mark_seen(XDB.rec("Items", 1))
	XWarehouse.create(s, "<仓库:999>")
	XWarehouse.open(s, "<仓库>")
	XWarehouse.deposit(s, "weapon", s.gear.filter(func(e): return e.kind == "weapon")[0])
	XWarehouse.deposit(s, "armor", s.gear.filter(func(e): return e.kind == "armor")[0])
	for i in 3:  # 看过又卖掉的
		s.lose_gear(s.gear[s.gear.size() - 1])
	return s


func _tianqi_state() -> XState:
	var lineup := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id)).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	s.gold = 5000000
	# 一件带三条天启篇词条的神话四阶武器（同 xiyou_tianqi_reforge 的造法）
	var wid := 0
	for r in XDB.table("Weapons"):
		if r is Dictionary and str(r.get("name", "")) != "":
			var tpl := XGear.template("weapon", int(r.id))
			if XQuality.grade(tpl) == 6 and XTianqiAffixRoll.tier_of(tpl) == 4 and not XEquipment.is_exclusive(tpl):
				wid = int(r.id)
				break
	var it := XGear.create("weapon", wid, s)
	XTianqiAffixRoll.set_affixes(it, [{"key": str(XTianqiAffixRoll.layer_candidates(it, "base")[0]), "tier": 4, "grade": "normal", "extra": {}},
		{"key": str(XTianqiAffixRoll.layer_candidates(it, "special")[0]), "tier": 4, "grade": "normal", "extra": {}},
		{"key": "first_strike", "tier": 4, "grade": "normal", "extra": {}}])
	s.register_gear(it)
	s.gear.append(it)
	# 一件天启篇异化装备、几颗异化石
	var alien: Dictionary = XTianqiAlienGear.create(s, "armor", 52, "war", "shigu", "inversebone").get("ok", {})
	if not alien.is_empty():
		s.gear.append(alien)
	s.gain_item(XAlienation.stone_id(), 5)
	for id in _with_tables("armor", 4):
		s.gain_gear("armor", id, 1)
	return s


## 读回来之后对同一件装备重铸、锁一条重铸、异化重抽，把结果记下来
func _rework(s: XState) -> Dictionary:
	var seq := [0.31, 0.72, 0.05, 0.93, 0.44, 0.61, 0.18, 0.87]
	var n := [0]
	var rng := func():
		n[0] += 1
		return seq[(n[0] - 1) % seq.size()]
	var out := {}
	var weapon = s.gear.filter(func(e): return not (e.get("tianqi_affixes", []) as Array).is_empty() and XAlienation.mark(e).is_empty())
	var w: Dictionary = weapon[0] if not weapon.is_empty() else {}
	out["reforge"] = XTianqiReforge.reforge(s, w, 0, rng) if not w.is_empty() else {"error": "没找到"}
	out["locked"] = XTianqiReforge.reforge_locked(s, w, 1, rng) if not w.is_empty() else {"error": "没找到"}
	out["weapon"] = [w.get("name"), w.get("tianqi_affixes"), w.get("params"), w.get("traits"), w.get("note"), w.get("description")]
	var aliens = s.gear.filter(func(e): return XTianqiAlienGear.is_tq(e))
	var a: Dictionary = aliens[0] if not aliens.is_empty() else {}
	XAlienation.force_roll = 0.3
	out["reroll"] = XAlienation.reroll(s, a) if not a.is_empty() else {"error": "没找到"}
	out["resolve"] = XAlienation.resolve(s, true)
	XAlienation.force_roll = -1.0
	out["alien"] = [a.get("name"), XAlienation.mark(a), a.get("traits"), a.get("note")]
	out["gold"] = s.gold
	out["stones"] = s.item_count(XAlienation.stone_id())
	return out


func _run() -> void:
	XMessageBox.auto = true
	seed(20261114)
	_dir = OS.get_user_data_dir().path_join("test_xiyou_save_slim_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_dir)
	XSave.dir_override = _dir
	XStarWarehouse._loaded_path = "<unloaded>"
	var bak := func(slot: int) -> String: return XSave.path(slot) + XSaveSlim.BACKUP_SUFFIX

	# ---- 老档：旧写法的文件 → 读 → 再存（变瘦）→ 读 ----
	_switches(false)
	var s := _old_state()
	check("old_built", s.gear.size() >= 10 and _affix_tables(s.to_dict()) >= 15, [s.gear.size(), _affix_tables(s.to_dict())])
	check("old_write", XSave.save(1))
	var old_text := _text(XSave.path(1))
	var old_d = _read(1)
	check("old_format", not old_d.has("saveSlim") and _affix_tables(old_d) >= 15 and not FileAccess.file_exists(bak.call(1)), _affix_tables(old_d))
	var stale: Array = (old_d.seen as Array).filter(func(k): return str(k).begins_with("xg:") and not _instances(old_d, []).any(func(e): return str(e.instanceId) == str(k)))
	check("old_has_stale_seen", stale.size() == 3, stale)
	_switches(true)
	check("old_load", XSave.load_slot(1))
	var vis_old := _visible(XState.current)
	var mem_tables := _affix_tables(XState.current.to_dict())
	var mem_seen: int = XState.current.seen.size()
	check("slim_write", XSave.save(1))
	var slim_text := _text(XSave.path(1))
	var slim_d = _read(1)
	check("slim_marked", slim_d.get("saveSlim") == 1.0 and _affix_tables(slim_d) == 0, _affix_tables(slim_d))
	check("slim_seen_dropped", (slim_d.seen as Array).size() == (old_d.seen as Array).size() - 3 and stale.all(func(k): return not slim_d.seen.has(k)), slim_d.seen)
	check("slim_item_seen_kept", (slim_d.seen as Array).has("i:1"))
	check("slim_smaller", slim_text.length() < old_text.length() * 0.9, [old_text.length(), slim_text.length()])
	check("slim_stats", XSaveSlim.last.slim and int(XSaveSlim.last.gear) == mem_tables and int(XSaveSlim.last.seen) == 3, XSaveSlim.last)
	check("memory_untouched", _affix_tables(XState.current.to_dict()) == mem_tables and XState.current.seen.size() == mem_seen)
	check("backup_exact", FileAccess.get_file_as_bytes(bak.call(1)) == old_text.to_utf8_buffer())
	check("slim_load", XSave.load_slot(1))
	_same("old_vs_slim_visible", vis_old, _visible(XState.current))
	check("loaded_no_tables", _affix_tables(XState.current.to_dict()) == 0)
	# 读回来的还能用：换装、卖掉、再掉一件
	var s1: XState = XState.current
	var before_n := s1.gear.size()
	s1.gain_gear("weapon", _with_tables("weapon", 1)[0], 1)
	check("gain_after_slim", s1.gear.size() == before_n + 1 and s1.gear[s1.gear.size() - 1].equipment.has("affixes"))
	# 幂等：瘦过的读回再存，没有东西可去；内容相同；备份不再动
	check("reload_for_idem", XSave.load_slot(1))
	check("idem_write", XSave.save(1) and int(XSaveSlim.last.gear) == 0 and int(XSaveSlim.last.seen) == 0 and str(XSaveSlim.last.backup) == "", XSaveSlim.last)
	_same("idem_same", _norm(slim_d), _norm(_read(1)))
	var again = _read(1)
	again.erase("savedAt"); again.erase("saveCount")
	var first = slim_d.duplicate(true)
	first.erase("savedAt"); first.erase("saveCount")
	_same("idem_bytes", first, again)
	check("backup_kept", FileAccess.get_file_as_bytes(bak.call(1)) == old_text.to_utf8_buffer())
	var log1 := XSaveSlim.read_log()
	check("log_first_slim", log1.size() == 1 and str(log1[0].kind) == "save" and str(log1[0].file) == "save_1.json" and int(log1[0].saved) > 0 \
		and int(log1[0].gear) == mem_tables and int(log1[0].seen) == 3 and str(log1[0].backup) == "save_1.json.before_slim.bak", log1)
	# 又换成没瘦过的（导入）再存：备份换成这次的原文件（每格只留最新一份）
	var imported: Dictionary = JSON.parse_string(old_text)
	imported.gold = 4321.0
	check("import_ok", XSaveTransfer.import_to(1, imported) == "")
	var imported_bytes := FileAccess.get_file_as_bytes(XSave.path(1))
	check("import_load", XSave.load_slot(1) and XState.current.gold == 4321)
	check("import_resave", XSave.save(1) and str(XSaveSlim.last.backup) != "")
	check("backup_replaced", FileAccess.get_file_as_bytes(bak.call(1)) == imported_bytes and imported_bytes != old_text.to_utf8_buffer())
	check("one_backup_per_slot", Array(DirAccess.get_files_at(_dir)).filter(func(f): return str(f).contains("before_slim")).size() == 1, DirAccess.get_files_at(_dir))
	# 备份不了：这次不瘦身、照原样写，旧备份留着
	check("import_again", XSaveTransfer.import_to(1, imported) == "" and XSave.load_slot(1))
	DirAccess.make_dir_recursive_absolute(bak.call(1) + XSaveSlim.TEMP_SUFFIX)
	check("backup_fail_still_saves", XSave.save(1) and not XSaveSlim.last.slim)
	check("backup_fail_unslim", not _read(1).has("saveSlim") and _affix_tables(_read(1)) > 0)
	check("backup_fail_keeps_old_backup", FileAccess.get_file_as_bytes(bak.call(1)) == imported_bytes)
	DirAccess.remove_absolute(bak.call(1) + XSaveSlim.TEMP_SUFFIX)
	check("after_fail_slims_again", XSave.save(1) and XSaveSlim.last.slim and _read(1).has("saveSlim"))

	# ---- 各开关各自回旧写法 ----
	check("sw_reload", XSave.load_slot(1))
	XState.current.seen["xg:999999"] = true
	XSaveSlim.GEAR_ROLL_TABLE = false
	check("sw_gear_off", XSave.save(2) and _affix_tables(_read(2)) == 0 and not _read(2).seen.has("xg:999999"))
	# 上面读回的是瘦过的档，内存里已经没有选项表；换一份带选项表的状态来看开关
	var s2 := _old_state()
	XSaveSlim.GEAR_ROLL_TABLE = false
	XSaveSlim.SEEN_STALE = true
	check("sw_gear_off_keeps_tables", XSave.save(2) and _affix_tables(_read(2)) == _affix_tables(s2.to_dict()) and (_read(2).seen as Array).size() == s2.seen.size() - 3)
	XSaveSlim.GEAR_ROLL_TABLE = true
	XSaveSlim.SEEN_STALE = false
	check("sw_seen_off_keeps_seen", XSave.save(2) and _affix_tables(_read(2)) == 0 and (_read(2).seen as Array).size() == s2.seen.size())
	XSaveSlim.GEAR_ROLL_TABLE = false
	var expect := s2.to_dict()
	check("sw_both_off", XSave.save(2) and not _read(2).has("saveSlim"))
	expect["saveCount"] = s2.save_count
	expect["savedAt"] = _read(2).savedAt
	check("sw_both_off_old_bytes", _text(XSave.path(2)) == JSON.stringify(expect))
	_switches(true)

	# ---- 自动存档：瘦、不备份 ----
	XState.current = s2
	check("auto_unslim_first", XSave.save_auto())
	XSaveSlim.GEAR_ROLL_TABLE = false
	XSaveSlim.SEEN_STALE = false
	check("auto_old", XSave.save_auto() and not JSON.parse_string(_text(XSave.auto_path())).has("saveSlim"))
	_switches(true)
	check("auto_slim", XSave.save_auto() and JSON.parse_string(_text(XSave.auto_path())).has("saveSlim") and _affix_tables(JSON.parse_string(_text(XSave.auto_path()))) == 0)
	check("auto_no_backup", not FileAccess.file_exists(XSave.auto_path() + XSaveSlim.BACKUP_SUFFIX))
	var vis_mem_auto_src := s2.to_dict().duplicate(true)  # 没瘦的整份内容
	check("auto_load", XSave.load_auto())
	# 内存里是整数、读回的有些是小数：两边都过一遍 JSON 再比
	_same("auto_roundtrip", _norm(XState.from_dict(JSON.parse_string(JSON.stringify(vis_mem_auto_src))).to_dict()), _norm(XState.current.to_dict()))
	XSave.remove_auto()

	# ---- 新开局档（发行模式）：同一份状态旧写法一格、新写法一格，读回一致 ----
	var saved_release := ReleaseEntry.simulate_release
	ReleaseEntry.simulate_release = true
	var s3 := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s3
	s3.map_id = 4
	_switches(false)
	check("new_old_write", XSave.save(3))
	_switches(true)
	XState.current = s3
	check("new_slim_write", XSave.save(4) and not FileAccess.file_exists(bak.call(4)) and _affix_tables(_read(4)) == 0 and _affix_tables(_read(3)) > 0)
	check("new_old_load", XSave.load_slot(3))
	var vis_new_old := _visible(XState.current)
	check("new_slim_load", XSave.load_slot(4))
	_same("new_old_vs_slim_visible", vis_new_old, _visible(XState.current))
	ReleaseEntry.simulate_release = saved_release

	# ---- 天启篇档：读回一致；重铸、锁一条重铸、异化重抽结果一致 ----
	var s4 := _tianqi_state()
	_switches(false)
	check("tq_old_write", XSave.save(5))
	_switches(true)
	XState.current = s4
	check("tq_slim_write", XSave.save(6) and _affix_tables(_read(6)) == 0 and _affix_tables(_read(5)) > 0)
	check("tq_old_load", XSave.load_slot(5))
	var vis_tq_old := _visible(XState.current)
	var rework_old := _rework(XState.current)
	check("tq_slim_load", XSave.load_slot(6))
	_same("tq_old_vs_slim_visible", vis_tq_old, _visible(XState.current))
	var rework_slim := _rework(XState.current)
	check("tq_reforge_ran", rework_old.reforge.has("ok") and rework_old.locked.has("ok"), [rework_old.reforge, rework_old.locked])
	check("tq_reroll_ran", rework_old.reroll.has("ok") and not rework_old.resolve.has("error"), [rework_old.reroll, rework_old.resolve])
	_same("tq_rework_same", rework_old, rework_slim)

	# ---- 星级仓库文件 ----
	var s5 := _old_state()
	var wh := XStarWarehouse.path()
	XSaveSlim.STAR_WAREHOUSE = false
	var g1: Dictionary = s5.gear[0]
	var g2: Dictionary = s5.gear[1]
	var show := func(e: Dictionary): return JSON.stringify([str(e.name), e.params, e.traits, str(e.description), str(e.note), e.meta, e.equipment.get("suits"), e.equipment.get("requirements")])
	var show1: String = show.call(g1)
	var show2: String = show.call(g2)
	check("wh_old_deposit", XStarWarehouse.deposit_gear(s5, g1) == "")
	var wh_old := FileAccess.get_file_as_bytes(wh)
	check("wh_old_format", _text(wh).contains("\"affixes\"") and not _text(wh).contains("saveSlim"))
	XSaveSlim.STAR_WAREHOUSE = true
	check("wh_slim_deposit", XStarWarehouse.deposit_gear(s5, g2) == "")
	var wh_d = JSON.parse_string(_text(wh))
	check("wh_slim_format", wh_d.get("saveSlim") == 1.0 and (wh_d.gear as Array).size() == 2 and not _text(wh).contains("\"affixes\""), _text(wh).left(200))
	check("wh_backup", FileAccess.get_file_as_bytes(wh + XSaveSlim.BACKUP_SUFFIX) == wh_old)
	check("wh_memory_untouched", g1.equipment.has("affixes") and g2.equipment.has("affixes"))
	XStarWarehouse._loaded_path = "<unloaded>"  # 从文件重读
	var stored := XStarWarehouse.gear().duplicate()
	check("wh_reload", stored.size() == 2 and show.call(stored[0]) == show1 and show.call(stored[1]) == show2)
	var n5 := s5.gear.size()
	check("wh_withdraw", XStarWarehouse.withdraw_gear(s5, stored[0]) and XStarWarehouse.withdraw_gear(s5, stored[1]) and s5.gear.size() == n5 + 2)
	check("wh_withdrawn_same", show.call(s5.gear[n5]) == show1 and show.call(s5.gear[n5 + 1]) == show2)
	XState.current = s5
	check("wh_save_after", XSave.save(7) and XSave.load_slot(7))

	# ---- 导入存档前的备份：每格留最近 2 份 ----
	var fake := func(slot: int, stamp: String) -> String:
		var p := "%s.before_import_%s.json" % [XSave.path(slot), stamp]
		var f := FileAccess.open(p, FileAccess.WRITE)
		f.store_string("{}")
		f.close()
		return p.get_file()
	for f in DirAccess.get_files_at(_dir):
		if str(f).contains(".before_import_"):
			DirAccess.remove_absolute(_dir.path_join(f))
	var f_a: String = fake.call(1, "2026-01-01T000000")
	var f_b: String = fake.call(1, "2026-02-01T000000")
	var f_c: String = fake.call(1, "2026-03-01T000000")
	var f_other: String = fake.call(2, "2026-01-01T000000")
	var f_ten: String = fake.call(10, "2026-01-01T000000")
	check("imp_import", XSaveTransfer.import_to(1, imported) == "")
	var left := Array(DirAccess.get_files_at(_dir)).filter(func(f): return str(f).begins_with("save_1.json.before_import_"))
	left.sort()
	check("imp_keep_two", left.size() == 2 and left[0] == f_c and left[1] > f_c and not left.has(f_a) and not left.has(f_b), left)
	check("imp_other_slots_untouched", FileAccess.file_exists(_dir.path_join(f_other)) and FileAccess.file_exists(_dir.path_join(f_ten)))
	check("imp_newest_is_real", FileAccess.get_file_as_bytes(_dir.path_join(left[1])).size() > 1000)
	XSaveSlim.IMPORT_BACKUPS = false
	fake.call(1, "2026-04-01T000000")
	fake.call(1, "2026-05-01T000000")
	check("imp_off_import", XSaveTransfer.import_to(1, imported) == "")
	check("imp_off_keeps_all", Array(DirAccess.get_files_at(_dir)).filter(func(f): return str(f).begins_with("save_1.json.before_import_")).size() >= 4)
	XSaveSlim.IMPORT_BACKUPS = true
	check("imp_log", XSaveSlim.read_log().any(func(e): return str(e.kind) == "import_backup" and (e.files as Array).has(f_a)))

	# ---- 残留临时文件 ----
	var touch := func(name: String) -> void:
		var f := FileAccess.open(_dir.path_join(name), FileAccess.WRITE)
		f.store_string("half")
		f.close()
	touch.call("save_9.json.tmp")
	touch.call("crown_progress_v1.json.0123456789abcdef.tmp")
	touch.call("keep.json")
	DirAccess.make_dir_recursive_absolute(_dir.path_join("sub"))
	var fsub := FileAccess.open(_dir.path_join("sub/inner.tmp"), FileAccess.WRITE)
	fsub.store_string("x")
	fsub.close()
	var now := Time.get_unix_time_from_system()
	check("tmp_fresh_kept", (XSaveSlim.sweep_temp([_dir], now).files as Array).is_empty() and FileAccess.file_exists(_dir.path_join("save_9.json.tmp")))
	XSaveSlim.TEMP_FILES = false
	check("tmp_off", (XSaveSlim.sweep_temp([_dir], now + 7200).files as Array).is_empty() and FileAccess.file_exists(_dir.path_join("save_9.json.tmp")))
	XSaveSlim.TEMP_FILES = true
	var swept := XSaveSlim.sweep_temp([_dir, _dir.path_join("no_such_dir"), ""], now + 7200)
	check("tmp_old_removed", (swept.files as Array).size() == 2 and int(swept.bytes) == 8 and not FileAccess.file_exists(_dir.path_join("save_9.json.tmp")) \
		and not FileAccess.file_exists(_dir.path_join("crown_progress_v1.json.0123456789abcdef.tmp")), swept)
	check("tmp_others_kept", FileAccess.file_exists(_dir.path_join("keep.json")) and FileAccess.file_exists(_dir.path_join("sub/inner.tmp")) \
		and XSave.exists(1) and FileAccess.file_exists(bak.call(1)) and FileAccess.file_exists(wh))
	check("tmp_log", XSaveSlim.read_log().any(func(e): return str(e.kind) == "temp" and (e.files as Array).has("save_9.json.tmp")))
	XSaveSlim._swept = false
	XSaveSlim.sweep_once()
	check("tmp_once", XSaveSlim._swept)

	# ---- 日志只留最近 20 条 ----
	for i in 25:
		XSaveSlim._log({"kind": "test", "n": i})
	var log2 := XSaveSlim.read_log()
	check("log_capped", log2.size() == XSaveSlim.LOG_KEEP and int(log2[log2.size() - 1].n) == 24 and int(log2[0].n) == 5, log2.size())

	_cleanup(_dir)
	XSave.dir_override = ""
	XStarWarehouse._loaded_path = "<unloaded>"
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


func _cleanup(dir: String) -> void:
	for d in DirAccess.get_directories_at(dir):
		_cleanup(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
