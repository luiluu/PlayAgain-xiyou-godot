extends Node
## 玩家反馈 v0.01.06「存档之后存不上，读档页看不到存档」：178 哈基米去掉副手后装备栏 18 格，读档校验只认 19 格，
## 队里建过 178 的档整份被当成坏档（读档页显示空格），存档照写、把这一格原来的好档也盖掉。
## 查：XSave.CAT_SLOTS_OK 开着 178 的档能存能读、读回仍是 18 格；关掉（旧校验）复现坏档；
## XSave.SAVE_GUARD 开着时读不回来的内容不写盘、旧档留着；两个开关都关回到旧写法（照写）。

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(800))


func _read(slot: int):
	return JSON.parse_string(FileAccess.get_file_as_string(XSave.path(slot))) if XSave.exists(slot) else null


func _run() -> void:
	XSave.dir_override = OS.get_user_data_dir().path_join("test_save_cat_slots_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(XSave.dir_override)
	XSave.CAT_SLOTS_OK = true
	XSave.SAVE_GUARD = true
	var full: int = XDB.system().equipTypes.size() - 1
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.map_id = 4  # 大厅（summary 要读地图名）
	# 没有 178 的档：照旧
	check("plain_save", XSave.save(1) and XSave.valid_data(_read(1)))
	# 建出 178（招募、图鉴等任何 actor(178)）
	var cat := s.actor(XCat.ACTOR)
	check("cat_slots_short", cat.equips.size() == full - 1, [cat.equips.size(), full])
	check("cat_save_ok", XSave.save(2))
	check("cat_save_valid", XSave.valid_data(_read(2)))
	check("cat_summary_readable", not XSave.summary(2).ends_with("无法读取"), XSave.summary(2))
	check("cat_load_ok", XSave.load_slot(2))
	check("cat_load_slots", XState.current.actors.has(XCat.ACTOR) and XState.current.actor(XCat.ACTOR).equips.size() == full - 1)
	check("other_actor_short_rejected", not XSave.equips_size_ok(1, full - 1) and XSave.equips_size_ok(1, full))
	# 旧校验（CAT_SLOTS_OK 关）：178 的档判坏——复现玩家反馈
	XSave.CAT_SLOTS_OK = false
	check("old_check_rejects_cat", not XSave.valid_data(_read(2)))
	# 写盘守卫：读不回来的内容不写，原来那格的好档留着
	var before := FileAccess.get_file_as_string(XSave.path(1))
	XState.current = s
	check("guard_refuses", not XSave.save(1))
	check("guard_keeps_old", FileAccess.get_file_as_string(XSave.path(1)) == before)
	check("guard_no_tmp", not FileAccess.file_exists(XSave.path(1) + ".tmp"))
	check("guard_auto_refuses", not XSave.save_auto() and not XSave.exists_auto())
	# 两个开关都关：旧写法照写（盖掉好档，读不回来）
	XSave.SAVE_GUARD = false
	check("old_write_overwrites", XSave.save(1) and not XSave.valid_data(_read(1)))
	XSave.CAT_SLOTS_OK = true
	XSave.SAVE_GUARD = true
	check("restored_readable", XSave.valid_data(_read(1)))
	for i in range(1, XSave.SLOTS + 1):
		XSave.remove(i)
	XSave.remove_auto()
	for f in DirAccess.get_files_at(XSave.dir_override):
		DirAccess.remove_absolute(XSave.dir_override.path_join(f))
	DirAccess.remove_absolute(XSave.dir_override)
	XSave.dir_override = ""
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
