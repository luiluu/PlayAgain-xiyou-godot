extends Node
## 存档封存 XSaveSeal（Kyo 11-15 D28：不许改存档，加密＋签名，改过的认得出；校验失败不读、不覆盖、不删；老档第一次读自动补签名）。
## 全在临时目录（XSave.dir_override、各账本 path_override），不碰真实存档和设置。
## 查：封存往返、改一字节／截断／空文件都校验失败；明文旧档迁移（先备份、备份逐字节等于原文件、解开等于原文、记号）；
## 迁移后丢进来的明文算失败（STRICT_AFTER_MIGRATE 关掉则照读）；多槽＋自动存档＋云裳／魔冠账本＋仓库＋跨存档变量；
## 校验失败时存档页、标题摘要、读档的表现，原文件一直在；存到失败的格先改名留着；开关关闭写明文、两种都读、再打开重新迁移；
## 导出导入（封存导出、改过的导不进、旧明文导出默认拒）；反馈问卷存档包里是原样的封存字节。

var results := []
var dir := ""


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(800))


func _bytes(p: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(p)


func _put(p: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_buffer(b)
	f.close()


func _flip(p: String, at: int) -> PackedByteArray:
	var b := _bytes(p)
	b[at] = b[at] ^ 0x01
	_put(p, b)
	return b


func _files(prefix: String) -> Array:
	return Array(DirAccess.get_files_at(dir)).filter(func(n): return str(n).begins_with(prefix))


func _clean(d: String) -> void:
	if not DirAccess.dir_exists_absolute(d):
		return
	for sub in DirAccess.get_directories_at(d):
		_clean(d.path_join(sub))
	for f in DirAccess.get_files_at(d):
		DirAccess.remove_absolute(d.path_join(f))
	DirAccess.remove_absolute(d)


func _run() -> void:
	dir = OS.get_user_data_dir().path_join("test_save_seal_%d" % OS.get_process_id())
	_clean(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	XSave.dir_override = dir
	XYunshangOrders.path_override = ""
	XDemonCrown.path_override = ""
	XStarWarehouse.path_override = ""
	XGlobalVars.path_override = ""
	XSaveSeal.ENABLED = true
	XSaveSeal.STRICT_AFTER_MIGRATE = true
	_codec()
	_legacy()
	_new_and_tamper()
	_ledgers()
	_switch_off()
	_transfer()
	_feedback()
	_release_cold_legacy()
	XSaveSeal.ENABLED = true
	XSaveSeal.STRICT_AFTER_MIGRATE = true
	XSaveTransfer.ACCEPT_PLAIN_IMPORT = false
	XFeedback.export_dir_override = ""
	XStarWarehouse._loaded_path = "<unloaded>"
	XGlobalVars._loaded_path = "<unloaded>"
	XYunshangOrders.reload()
	XDemonCrown.forget_ledger()
	_clean(dir)
	XSave.dir_override = ""
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


## 编码本身：往返、每一段改一字节都失败、截断、空、版本号不认得
func _codec() -> void:
	var text := JSON.stringify({"mode": "xiyou", "名字": "云裳·天衣", "n": 123456789, "pad": "x".repeat(5000)})
	var b := XSaveSeal.seal(text)
	var r := XSaveSeal.unseal(b)
	check("codec.roundtrip", r.ok and r.text == text)
	check("codec.magic", XSaveSeal.is_sealed(b) and not b.get_string_from_utf8().contains("xiyou"))
	check("codec.iv_random", XSaveSeal.seal(text) != b)
	check("codec.compressed", b.size() < text.to_utf8_buffer().size(), [b.size(), text.length()])
	var bad := 0
	var positions := [0, 4, 5, 8, 12, 27, 28, b.size() / 2, b.size() - 33, b.size() - 32, b.size() - 1]
	for at in positions:
		var c := b.duplicate()
		c[at] = c[at] ^ 0x01
		if not XSaveSeal.unseal(c).ok:
			bad += 1
	check("codec.flip_any_byte_fails", bad == positions.size(), bad)
	check("codec.truncated_fails", not XSaveSeal.unseal(b.slice(0, b.size() - 1)).ok and not XSaveSeal.unseal(b.slice(0, b.size() / 2)).ok)
	check("codec.appended_fails", not XSaveSeal.unseal(b + PackedByteArray([0])).ok)
	check("codec.empty_fails", not XSaveSeal.unseal(PackedByteArray()).ok)
	check("codec.covered", XSaveSeal.covered("a/save_1.json") and XSaveSeal.covered("a/save_30.json") and XSaveSeal.covered("a/save_auto.json")
		and XSaveSeal.covered("a/yunshang_orders_v1.json") and XSaveSeal.covered("a/crown_progress_v1.json") and XSaveSeal.covered("a/star_warehouse.json")
		and XSaveSeal.covered("a/global.json") and not XSaveSeal.covered("a/options.json") and not XSaveSeal.covered("a/save_1.json.bak")
		and not XSaveSeal.covered("a/save_x.json") and not XSaveSeal.covered("a/save_slim_log.json"))


func _new_state() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 4
	return s


## 明文旧档迁移：开关关着时写出的明文档（与旧版本写的一样）＋各账本，打开开关后第一次读
func _legacy() -> void:
	XSaveSeal.ENABLED = false
	var s := _new_state()
	s.gold = 4321
	XState.current = s
	check("legacy.plain_save", XSave.save(1) and XSave.save(2) and XSave.save_auto())
	XYunshangOrders.reload()
	check("legacy.plain_yunshang", XYunshangOrders.save_ledger({"version": 2, "profiles": {"p": {"x": 1}}, "legacyProfiles": {}}))
	XDemonCrown.forget_ledger()
	check("legacy.plain_crown", XDemonCrown.save_ledger({"version": 1, "profiles": {"c": 2}, "legacy": {}}))
	XStarWarehouse._loaded_path = "<unloaded>"
	XStarWarehouse.ensure_loaded()
	check("legacy.plain_warehouse", XStarWarehouse._save())
	var vid := int(XGlobalVars.variable_ids()[0]) if not XGlobalVars.variable_ids().is_empty() else 0
	XGlobalVars._loaded_path = "<unloaded>"
	XGlobalVars.ensure_loaded()
	XGlobalVars._variables[vid] = 77
	check("legacy.plain_global", XGlobalVars._save())
	var names := ["save_1.json", "save_2.json", "save_auto.json", "yunshang_orders_v1.json", "crown_progress_v1.json", "star_warehouse.json", "global.json"]
	var orig := {}
	for n in names:
		orig[n] = _bytes(dir.path_join(n))
	check("legacy.all_plain", names.all(func(n): return not XSaveSeal.is_sealed(orig[n]) and orig[n].size() > 0 and char(orig[n][0]) in ["{", "["]))
	check("legacy.no_marker", not FileAccess.file_exists(dir.path_join(XSaveSeal.MARKER)))
	# 打开开关、第一次读（标题摘要）
	XSaveSeal.ENABLED = true
	var summary := XSave.summary(1)
	check("legacy.summary_ok", summary.begins_with("存档 1：") and not summary.contains("无法读取") and not summary.contains("校验失败"), summary)
	check("legacy.marker", XSaveSeal.marker_ok(dir))
	check("legacy.migrated_all", (XSaveSeal.last_migration.get("sealed", []) as Array).size() == names.size() and (XSaveSeal.last_migration.failed as Array).is_empty(), XSaveSeal.last_migration)
	for n in names:
		var p := dir.path_join(n)
		var baks := _files(n + XSaveSeal.PLAIN_BACKUP)
		check("legacy.%s.backup" % n, baks.size() == 1 and _bytes(dir.path_join(baks[0])) == orig[n], baks)
		check("legacy.%s.sealed" % n, XSaveSeal.is_sealed(_bytes(p)))
		check("legacy.%s.same_text" % n, XSaveSeal.read_text(p) == orig[n].get_string_from_utf8())
	check("legacy.load", XSave.load_slot(1) and XState.current.gold == 4321)
	check("legacy.load_auto", XSave.load_auto() and XState.current.gold == 4321)
	XYunshangOrders.reload()
	var led = XYunshangOrders.load_ledger()
	check("legacy.yunshang_reads", led is Dictionary and led.profiles.has("p"))
	XDemonCrown.forget_ledger()
	var crown = XDemonCrown.load_ledger()
	check("legacy.crown_reads", crown is Dictionary and crown.profiles.has("c"))
	XGlobalVars._loaded_path = "<unloaded>"
	XGlobalVars.ensure_loaded()
	check("legacy.global_reads", not XGlobalVars.seal_failed and XGlobalVars._variables.get(vid) == 77)
	XStarWarehouse._loaded_path = "<unloaded>"
	XStarWarehouse.ensure_loaded()
	check("legacy.warehouse_reads", not XStarWarehouse.seal_failed)
	# 第二次读不再迁移、不再备份
	XSave.summary(2)
	check("legacy.backup_once", _files("save_2.json" + XSaveSeal.PLAIN_BACKUP).size() == 1)


## 新档往返；改一字节、截断、明文丢进来都校验失败，原文件一直在；存到失败的格先改名留着；删除也改名
func _new_and_tamper() -> void:
	var s := _new_state()
	s.gold = 999
	XState.current = s
	check("new.save", XSave.save(3))
	var p3 := XSave.path(3)
	check("new.sealed_on_disk", XSaveSeal.is_sealed(_bytes(p3)) and not _bytes(p3).get_string_from_utf8().contains("\"mode\""))
	check("new.load", XSave.load_slot(3) and XState.current.gold == 999)
	# 改一字节
	var tampered := _flip(p3, _bytes(p3).size() / 2)
	check("tamper.summary", XSave.summary(3).contains(XSaveSeal.FAIL_TEXT), XSave.summary(3))
	check("tamper.seal_failed", XSave.seal_failed(3))
	check("tamper.load_refused", not XSave.load_slot(3))
	check("tamper.file_kept", _bytes(p3) == tampered)
	var page := XSaveScene.new()
	check("tamper.page_data_null", page.data(3) == null and page.seal_failed(3) and not page.seal_failed(1))
	page.index = 2
	check("tamper.page_load_enabled", page.action_enabled(0))
	page.free()
	check("tamper.export_refused", XSaveTransfer.export_text(3).get("error", "") == XSaveSeal.FAIL_TEXT)
	# 存到这一格：原文件改名留着，新档写进去
	XState.current = s
	check("tamper.save_over_ok", XSave.save(3))
	var kept := _files("save_3.json" + XSaveSeal.FAILED_MARK)
	check("tamper.quarantined", kept.size() == 1 and _bytes(dir.path_join(kept[0])) == tampered, kept)
	check("tamper.slot_readable_again", XSave.load_slot(3))
	# 截断（闪退写一半）
	var full := _bytes(p3)
	_put(p3, full.slice(0, full.size() - 40))
	check("trunc.failed", XSave.seal_failed(3) and not XSave.load_slot(3))
	check("trunc.kept", _bytes(p3).size() == full.size() - 40)
	# 删除：校验失败的不删，改名留着
	check("trunc.remove_quarantines", XSave.remove(3) and not XSave.exists(3) and _files("save_3.json" + XSaveSeal.FAILED_MARK).size() == 2)
	# 空文件
	_put(XSave.path(4), PackedByteArray())
	check("empty.failed", XSave.seal_failed(4))
	XSave.remove(4)
	# 目录已封存后丢进来的明文
	var plain := JSON.stringify(s.to_dict()).to_utf8_buffer()
	_put(XSave.path(5), plain)
	check("plain_after.failed", XSave.seal_failed(5) and not XSave.load_slot(5) and _bytes(XSave.path(5)) == plain)
	XSaveSeal.STRICT_AFTER_MIGRATE = false
	check("plain_after.loose_reads", not XSave.seal_failed(5) and XSave.load_slot(5))
	XSaveSeal.STRICT_AFTER_MIGRATE = true
	XSave.remove(5)
	# 自动存档：改过 → 摘要、读取都报校验失败；手动存档后 remove_auto 不删、改名留着
	XState.current = s
	check("auto.save", XSave.save_auto() and XSaveSeal.is_sealed(_bytes(XSave.auto_path())))
	var auto_bad := _flip(XSave.auto_path(), 40)
	check("auto.failed", XSave.auto_seal_failed() and XSave.auto_summary().contains(XSaveSeal.FAIL_TEXT) and not XSave.load_auto())
	check("auto.kept", _bytes(XSave.auto_path()) == auto_bad)
	XState.current = s
	XSave.save(6)
	check("auto.quarantined_not_deleted", not XSave.exists_auto() and _files("save_auto.json" + XSaveSeal.FAILED_MARK).size() == 1)
	# 多槽：1、2、6 都好好的
	check("multi.slots_ok", [1, 2, 6].all(func(n): return not XSave.seal_failed(n) and XSave.load_slot(n)))


## 账本、仓库、跨存档变量：改过就不读、不写、文件不动
func _ledgers() -> void:
	var yp := XYunshangOrders.path()
	XYunshangOrders.reload()
	check("ledger.yunshang_sealed_write", XYunshangOrders.save_ledger({"version": 2, "profiles": {"q": 1}, "legacyProfiles": {}}) and XSaveSeal.is_sealed(_bytes(yp)))
	var yb := _flip(yp, 20)
	XYunshangOrders.reload()
	check("ledger.yunshang_refused", XYunshangOrders.load_ledger() == null and XYunshangOrders.error.contains(XSaveSeal.FAIL_TEXT), XYunshangOrders.error)
	check("ledger.yunshang_no_overwrite", not XYunshangOrders.save_ledger({"version": 2, "profiles": {}, "legacyProfiles": {}}) and _bytes(yp) == yb)
	var cp := XDemonCrown.path()
	XDemonCrown.forget_ledger()
	check("ledger.crown_sealed_write", XDemonCrown.save_ledger({"version": 1, "profiles": {}, "legacy": {}}) and XSaveSeal.is_sealed(_bytes(cp)))
	var cb := _flip(cp, 20)
	XDemonCrown.forget_ledger()
	check("ledger.crown_refused", XDemonCrown.load_ledger() == null and not XDemonCrown.save_ledger({"version": 1, "profiles": {}, "legacy": {}}) and _bytes(cp) == cb)
	var wp := XStarWarehouse.path()
	var wb := _flip(wp, 20)
	XStarWarehouse._loaded_path = "<unloaded>"
	XStarWarehouse.ensure_loaded()
	check("ledger.warehouse_refused", XStarWarehouse.seal_failed and not XStarWarehouse._save() and XStarWarehouse.last_error.contains(XSaveSeal.FAIL_TEXT) and _bytes(wp) == wb)
	var gp := XGlobalVars.path()
	var gb := _flip(gp, 20)
	XGlobalVars._loaded_path = "<unloaded>"
	XGlobalVars.ensure_loaded()
	check("ledger.global_refused", XGlobalVars.seal_failed and not XGlobalVars._save() and _bytes(gp) == gb)
	# 收拾：换成好的，别影响后面
	for p in [yp, cp, wp, gp]:
		DirAccess.remove_absolute(p)
	XYunshangOrders.reload()
	XDemonCrown.forget_ledger()
	XStarWarehouse._loaded_path = "<unloaded>"
	XGlobalVars._loaded_path = "<unloaded>"


## 开关关掉：写明文、去掉记号，封存的老档照读；再打开：重新迁移
func _switch_off() -> void:
	XSaveSeal.ENABLED = false
	var s := _new_state()
	s.gold = 555
	XState.current = s
	check("off.save_plain", XSave.save(7) and char(_bytes(XSave.path(7))[0]) == "{")
	check("off.marker_removed", not FileAccess.file_exists(dir.path_join(XSaveSeal.MARKER)))
	check("off.reads_sealed", XSaveSeal.is_sealed(_bytes(XSave.path(1))) and XSave.load_slot(1))
	check("off.reads_plain", XSave.load_slot(7) and XState.current.gold == 555)
	check("off.sealed_still_valid", XSaveSeal.unseal(_bytes(XSave.path(1))).ok)
	XSaveSeal.ENABLED = true
	XSaveSeal._tried.clear()
	check("on_again.plain_read_ok", XSave.load_slot(7) and XState.current.gold == 555)
	check("on_again.resealed", XSaveSeal.is_sealed(_bytes(XSave.path(7))) and XSaveSeal.marker_ok(dir))


## 导出导入
func _transfer() -> void:
	var out := XSaveTransfer.export_text(1)
	var v = JSON.parse_string(str(out.get("text", "")))
	check("xfer.export_sealed", v is Dictionary and v.format == XSaveTransfer.FORMAT_SEALED and not v.has("data") and str(out.text).find("\"actors\"") < 0)
	var imp := XSaveTransfer.parse_import(str(out.text))
	check("xfer.import_ok", imp.has("data"), imp)
	var raw := Marshalls.base64_to_raw(str(v.sealed))
	raw[raw.size() / 2] = raw[raw.size() / 2] ^ 1
	v.sealed = Marshalls.raw_to_base64(raw)
	check("xfer.tampered_refused", str(XSaveTransfer.parse_import(JSON.stringify(v)).get("error", "")).contains(XSaveSeal.FAIL_TEXT))
	var plain_export := JSON.stringify({"format": XSaveTransfer.FORMAT, "game": XSaveTransfer.GAME, "slot": 1, "data": imp.data})
	check("xfer.plain_refused", str(XSaveTransfer.parse_import(plain_export).get("error", "")).contains("没有签名"))
	XSaveTransfer.ACCEPT_PLAIN_IMPORT = true
	check("xfer.plain_accepted_when_allowed", XSaveTransfer.parse_import(plain_export).has("data"))
	XSaveTransfer.ACCEPT_PLAIN_IMPORT = false
	check("xfer.raw_sealed_file", XSaveTransfer.read_import(XSave.path(1)).has("data"))
	check("xfer.import_writes_sealed", XSaveTransfer.import_to(8, imp.data) == "" and XSaveSeal.is_sealed(_bytes(XSave.path(8))) and XSave.load_slot(8))


## 反馈问卷存档包：封存文件原样进 zip（含校验失败改名留着的）
func _feedback() -> void:
	var out_dir := dir.path_join("zip_out")
	DirAccess.make_dir_recursive_absolute(out_dir)
	XFeedback.export_dir_override = out_dir
	var zip_path := XFeedback.export_saves()
	var ok := zip_path != ""
	var same := 0
	var has_failed := false
	if ok:
		var z := ZIPReader.new()
		ok = z.open(zip_path) == OK
		if ok:
			for f in z.get_files():
				if f == "save_1.json" or f == "save_2.json":
					same += 1 if z.read_file(f) == _bytes(dir.path_join(f)) else 0
				if str(f).contains(XSaveSeal.FAILED_MARK):
					has_failed = true
			z.close()
	check("feedback.zip_has_sealed_bytes", ok and same == 2, [zip_path, same])
	check("feedback.zip_has_failed_originals", has_failed)


## 发行模拟（ReleaseEntry.simulate_release）冷启动：进程刚起（XState.current＝null）读一份旧版写的明文档 → 迁移并读进来
func _release_cold_legacy() -> void:
	var cold := dir.path_join("cold")
	DirAccess.make_dir_recursive_absolute(cold)
	XSave.dir_override = cold
	XSaveSeal.ENABLED = false
	var s := _new_state()
	s.gold = 2468
	XState.current = s
	XSave.save(1)
	var plain := _bytes(XSave.path(1))
	XSaveSeal.ENABLED = true
	var saved := ReleaseEntry.simulate_release
	ReleaseEntry.simulate_release = true
	XState.current = null
	XSave.current_slot = 0
	var ok := XSave.load_slot(1)
	ReleaseEntry.simulate_release = saved
	check("release_cold.legacy_loads", ok and XState.current != null and XState.current.gold == 2468)
	check("release_cold.migrated", XSaveSeal.is_sealed(_bytes(XSave.path(1))) and XSaveSeal.marker_ok(cold)
		and Array(DirAccess.get_files_at(cold)).filter(func(n): return str(n).begins_with("save_1.json" + XSaveSeal.PLAIN_BACKUP)).size() == 1)
	check("release_cold.text_same", XSaveSeal.read_text(XSave.path(1)) == plain.get_string_from_utf8())
	XSave.dir_override = dir
