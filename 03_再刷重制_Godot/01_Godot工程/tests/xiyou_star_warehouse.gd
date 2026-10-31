extends Node
## 通用仓库（XStarWarehouse／XStarWarehouseScene）对照 generated/oracle/star_warehouse.json（mv_oracle/star_warehouse_probe.cjs）：
## 同样的背包（皮甲 3、指虎 6、1044、带 <PushDct> 的 52）与宠物（敌人 1／2／3，第二只出战），经画面的确定／取消逐步做存取，
## 比列表、背包、仓库与提示；换局（新状态，仓库文件不变）后取出。另验：
## - 跨存档：写盘后换路径重读；取出的装备重新发实例编号（两个存档的 xg:N 撞号，沙僧 Q1）；损坏的文件当空。
## - O-待定 o_write_through：开时每次存取立即写盘；关时照原版只在配置写盘（XConfig._write）时落盘。
## - 画面：确定都放普通确定音（沙僧 Q3）、不放装备音效与蜂鸣；分类阶段说明窗空白，列表阶段显示装备说明、宠物空白；版面常量。

var results := []
var mismatches := []
var dir := "user://test_xiyou_star_warehouse"


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		mismatches.append({"name": name, "detail": detail})


static func norm(v):
	return JSON.parse_string(JSON.stringify(v))


func _fresh_files() -> void:
	XSave.dir_override = dir
	XConfig.path_override = XSave.dir().path_join("options.json")
	for f in ["star_warehouse.json", "star_warehouse.json.tmp", "options.json"]:
		if FileAccess.file_exists(XSave.dir().path_join(f)):
			DirAccess.remove_absolute(XSave.dir().path_join(f))
	XStarWarehouse.path_override = ""
	XStarWarehouse.reset()


func _state() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.gear.clear()
	XState.current = s
	return s


static func gear_of(e: Dictionary) -> Dictionary:
	return {"kind": str(e.kind), "base": int(e.base), "name": str(XDB.rec("Weapons" if str(e.kind) == "weapon" else "Armors", int(e.base)).get("name", ""))}


static func pet_of(s: XState, p: Dictionary, stored := false) -> Dictionary:
	return {"enemy": int(p.enemy)} if stored else {"enemy": int(p.enemy), "war": is_same(XPets.war_pet(s), p)}


func bag(s: XState) -> Dictionary:
	return {"equip": XStarWarehouse.carried_gear(s).map(gear_of), "pets": XPets.list(s).map(func(p): return pet_of(s, p))}


func stored(s: XState) -> Dictionary:
	return {"equip": XStarWarehouse.gear().map(gear_of), "pets": XStarWarehouse.pets().map(func(p): return pet_of(s, p, true))}


func _run() -> void:
	var ref = XDB.load_json("oracle/star_warehouse.json")
	if not ref is Dictionary:
		check("oracle_present", false, "先运行 mv_oracle/star_warehouse_probe.cjs")
		return _finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	_fresh_files()
	var c: Dictionary = ref.cases[0]
	var rows := {}
	for r in c.observed.rows:
		rows[str(r.step)] = r
	var s := _state()
	for g in c.setup.gear:
		s.gain_gear(str(g[0]), int(g[1]), 1)
	for id in c.setup.pets:
		XPets.list(s).append(XPets.create(int(id), false, "", func(): return 0.5))
	XPets.go_to_war(s, int(c.setup.war))
	var page := XStarWarehouseScene.new(true)
	add_child(page)
	check("save_lists", norm({"equip": XStarWarehouse.carried_gear(s).map(gear_of), "pets": XPets.list(s).map(func(p): return pet_of(s, p))}) == norm(rows.save_lists.lists),
		[XStarWarehouse.carried_gear(s).map(gear_of), rows.save_lists.lists])
	check("help_category_blank", page.help_text() == "")
	XToast.shown.clear()
	XSound.system_log.clear()
	page.ok()  # 分类 → 列表（装备，选第 1 格）
	check("list_first", page.mode == "list" and page.index == 0)
	check("help_equip", page.help_text() == str(page.current().get("description", "")) and page.help_text() != "", page.help_text())
	page.ok()  # 存皮甲
	_compare("deposit_armor", rows.deposit_armor, s)
	check("cursor_stays", page.index == 0, page.index)
	page._select(int(rows.deposit_pushdct.index))
	page.ok()
	_compare("deposit_pushdct", rows.deposit_pushdct, s)
	page.cancel()
	page._move(1, 0, true)  # 分类换到宠物
	check("help_category_blank_after", page.help_text() == "")
	page.ok()
	check("help_pet_blank", page.help_text() == "")
	page.ok()  # 存第 1 只
	_compare("deposit_pet", rows.deposit_pet, s)
	page.ok()  # 现在第 1 只是出战的：没有反应
	_compare("deposit_war_pet", rows.deposit_war_pet, s)
	page._select(99)
	page.ok()  # 空格
	_compare("deposit_empty", rows.deposit_empty, s)
	var played := XSound.system_log.duplicate()
	check("sounds_ok_only", played.count(1) == 7 and not played.has(3) and not played.has(4), played)
	page.queue_free()
	# 写盘：存放后文件里就有（O-待定 开）
	var file_text := FileAccess.get_file_as_string(XStarWarehouse.path())
	check("write_through", file_text.contains("\"gear\"") and JSON.parse_string(file_text).gear.size() == 1 and JSON.parse_string(file_text).pets.size() == 1, file_text.left(200))
	# 换局：新状态，仓库从文件重读
	XStarWarehouse.reset()
	var s2 := _state()
	s2.gain_gear("armor", 3, 1)  # 本档已有一件 xg:N，取出的那件要另发编号
	var mine: String = str(s2.gear[0].instanceId)
	var page2 := XStarWarehouseScene.new(false)
	add_child(page2)
	var want_lists: Dictionary = rows.withdraw_lists.lists
	check("withdraw_lists", norm({"equip": XStarWarehouse.gear().map(func(e): return gear_of(e).name), "pets": XStarWarehouse.pets().map(func(p): return int(p.enemy))})
		== norm({"equip": want_lists.equip.map(func(e): return e.name), "pets": want_lists.pets.map(func(p): return int(p.enemy))}), [stored(s2), want_lists])
	var stored_id := str(XStarWarehouse.gear()[0].instanceId)
	page2.ok()
	page2.ok()  # 取装备第 1 件
	page2.cancel()
	page2._move(1, 0, true)
	page2.ok()
	page2.ok()  # 取宠物第 1 只
	var want: Dictionary = rows.withdraw
	check("withdraw.bag_names", norm(s2.gear.slice(1).map(func(e): return gear_of(e).name)) == norm(want.bag.equip.map(func(e): return e.name)), s2.gear.map(gear_of))
	check("withdraw.pets", norm(XPets.list(s2).map(func(p): return int(p.enemy))) == norm(want.bag.pets.map(func(p): return int(p.enemy))))
	check("withdraw.stored_empty", XStarWarehouse.gear().is_empty() and XStarWarehouse.pets().is_empty())
	var ids := s2.gear.map(func(e): return str(e.instanceId))
	check("withdraw.new_instance_id", ids.size() == 2 and ids[0] == mine and ids[1] != mine and ids[0] != ids[1], [ids, stored_id])
	page2.queue_free()
	# 损坏的文件当空，改动后整份重写
	var f := FileAccess.open(XStarWarehouse.path(), FileAccess.WRITE)
	f.store_string("{坏")
	f.close()
	XStarWarehouse.reset()
	check("corrupt_empty", XStarWarehouse.gear().is_empty() and XStarWarehouse.pets().is_empty())
	check("corrupt_rewrite", XStarWarehouse.deposit_gear(s2, s2.gear[0]) and JSON.parse_string(FileAccess.get_file_as_string(XStarWarehouse.path())) is Dictionary)
	# O-待定 关：照原版只在配置写盘时落盘
	XStarWarehouse.o_write_through = false
	XStarWarehouse.deposit_gear(s2, s2.gear[0])
	var before_n: int = JSON.parse_string(FileAccess.get_file_as_string(XStarWarehouse.path())).gear.size()
	XConfig.set_flag("MOG_TrPopUpBattle_Key", XConfig.flag("MOG_TrPopUpBattle_Key"))
	XConfig._write()
	var after_n: int = JSON.parse_string(FileAccess.get_file_as_string(XStarWarehouse.path())).gear.size()
	check("o_off_wait_config", before_n == 1 and after_n == 2, [before_n, after_n])
	XStarWarehouse.o_write_through = true
	# 版面（MV 公式）
	check("layout", XStarWarehouseScene.HELP_RECT == Rect2(0, 0, 1280, 100) and XStarWarehouseScene.CAT_RECT == Rect2(0, 100, 1280, 64)
		and XStarWarehouseScene.LIST_RECT == Rect2(0, 164, 1280, 556) and XStarWarehouseScene.ROWS == floori((556 - 28) / 36.0))
	_finish()


func _compare(tag: String, row: Dictionary, s: XState) -> void:
	check(tag + ".bag", norm(bag(s)) == norm(row.bag), [bag(s), row.bag])
	check(tag + ".stored", norm(stored(s)) == norm(row.stored), [stored(s), row.stored])
	var toasts := XToast.shown.duplicate()
	XToast.shown.clear()
	check(tag + ".toasts", norm(toasts) == norm(row.toasts), [toasts, row.toasts])


func _finish() -> void:
	XStarWarehouse.path_override = ""
	XStarWarehouse.reset()
	XSave.dir_override = ""
	XConfig.path_override = ""
	var passed := results.filter(func(r): return r.passed).size()
	for m in mismatches.slice(0, 30):
		print("MISMATCH ", m.name, " ", JSON.stringify(m.detail).left(600))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
