extends Node
## 存档封存 XSaveSeal（Kyo 11-15 D28：不许改存档，加密＋签名，改过的认得出；校验失败不读、不覆盖、不删；老档第一次读自动补签名）。
## co 甲档核查返修：封存档用新文件名 .ksv（旧代码看不见），明文 .json 留原处当备份；解压／文件大小上限；落盘读回核对；
## 补齐逐字节核；发行密钥出包注入、发行构建不认公开测试密钥；导入时校验失败的原件不被备份清理删掉。
## 全在临时目录（XSave.dir_override、各账本 path_override），不碰真实存档和设置；密钥文件也在临时目录（key_file_override）。

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


func _files(prefix: String, in_dir := "") -> Array:
	return Array(DirAccess.get_files_at(in_dir if in_dir != "" else dir)).filter(func(n): return str(n).begins_with(prefix))


func _clean(d: String) -> void:
	if not DirAccess.dir_exists_absolute(d):
		return
	for sub in DirAccess.get_directories_at(d):
		_clean(d.path_join(sub))
	for f in DirAccess.get_files_at(d):
		DirAccess.remove_absolute(d.path_join(f))
	DirAccess.remove_absolute(d)


func _reset_caches() -> void:
	XSaveSeal.forget_dirs()
	XStarWarehouse._loaded_path = "<unloaded>"
	XGlobalVars._loaded_path = "<unloaded>"
	XYunshangOrders.reload()
	XDemonCrown.forget_ledger()


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
	XSaveSeal.simulate_template = false
	XSaveSeal.key_file_override = ""
	XSaveSeal.reload_keys()
	XSaveSeal.forget_dirs()
	_codec()
	_crafted()
	_legacy()
	_old_code_rollback()
	_new_and_tamper()
	_ledgers()
	_switch_off()
	_transfer()
	_import_keeps_failed()
	_feedback()
	_release_cold_legacy()
	_migrate_fails()
	_release_keys()
	XSaveSeal.ENABLED = true
	XSaveSeal.STRICT_AFTER_MIGRATE = true
	XSaveSeal.simulate_template = false
	XSaveSeal.key_file_override = ""
	XSaveSeal.reload_keys()
	XSaveTransfer.ACCEPT_PLAIN_IMPORT = true
	XFeedback.export_dir_override = ""
	_reset_caches()
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
	check("codec.test_key_id0", int(b[6]) == 0)
	check("codec.iv_random", XSaveSeal.seal(text) != b)
	check("codec.compressed", b.size() < text.to_utf8_buffer().size(), [b.size(), text.length()])
	var bad := 0
	var positions := [0, 4, 5, 6, 8, 12, 27, 28, b.size() / 2, b.size() - 33, b.size() - 32, b.size() - 1]
	for at in positions:
		var c := b.duplicate()
		c[at] = c[at] ^ 0x01
		if not XSaveSeal.unseal(c).ok:
			bad += 1
	check("codec.flip_any_byte_fails", bad == positions.size(), bad)
	check("codec.truncated_fails", not XSaveSeal.unseal(b.slice(0, b.size() - 1)).ok and not XSaveSeal.unseal(b.slice(0, b.size() / 2)).ok)
	check("codec.appended_fails", not XSaveSeal.unseal(b + PackedByteArray([0])).ok)
	check("codec.empty_fails", not XSaveSeal.unseal(PackedByteArray()).ok)
	check("codec.covered", XSaveSeal.covered("a/save_1.json") and XSaveSeal.covered("a/save_30.ksv") and XSaveSeal.covered("a/save_auto.json")
		and XSaveSeal.covered("a/yunshang_orders_v1.ksv") and XSaveSeal.covered("a/crown_progress_v1.json") and XSaveSeal.covered("a/star_warehouse.json")
		and XSaveSeal.covered("a/global.json") and not XSaveSeal.covered("a/options.json") and not XSaveSeal.covered("a/save_1.json.bak")
		and not XSaveSeal.covered("a/save_x.json") and not XSaveSeal.covered("a/cleanup_log.json") and not XSaveSeal.covered("a/save_1.ksv.failed_x"))
	check("codec.active_name", XSave.path(3).ends_with("save_3.ksv") and XSave.auto_path().ends_with("save_auto.ksv")
		and XYunshangOrders.path().ends_with("yunshang_orders_v1.ksv") and XGlobalVars.path().ends_with("global.ksv"))


## 带合法签名的坏内容（密钥公开时谁都能造）：超大声明长度、补齐错（末字节对、前面不对）都拒；签名在先
func _crafted() -> void:
	var k: Array = XSaveSeal._keys[0]
	var sign := func(head_body: PackedByteArray) -> PackedByteArray:
		var out := head_body.duplicate()
		out.append_array(Crypto.new().hmac_digest(HashingContext.HASH_SHA256, k[1], head_body))
		return out
	var b := XSaveSeal.seal("{\"a\":1}")
	var body := b.slice(0, b.size() - 32)
	body.encode_u32(8, XSaveSeal.MAX_PLAIN + 1)
	var big := XSaveSeal.unseal(sign.call(body))
	check("crafted.oversize_rejected", not big.ok and str(big.why).contains("上限"), big)
	# 补齐：手工加密一份「末字节 4、前三个不是 4」的
	var plain := "{\"a\":12}".to_utf8_buffer()  # 8 字节、不压缩（标志 0）：补齐 8 个
	var z := plain.duplicate()
	var pad := 16 - z.size() % 16
	for i in range(pad - 1):
		z.append(0x77)
	z.append(pad)
	var iv := Crypto.new().generate_random_bytes(16)
	var aes := AESContext.new()
	aes.start(AESContext.MODE_CBC_ENCRYPT, k[0], iv)
	var cipher := aes.update(z)
	aes.finish()
	var head := PackedByteArray()
	head.append_array("KYSV".to_ascii_buffer())
	head.append_array(PackedByteArray([1, 0, 0, 0, 0, 0, 0, 0]))
	head.encode_u32(8, plain.size())
	head.append_array(iv)
	head.append_array(cipher)
	var bad_pad := XSaveSeal.unseal(sign.call(head))
	check("crafted.padding_all_bytes", not bad_pad.ok and str(bad_pad.why).contains("补齐"), bad_pad)
	# 文件超过上限：读之前就拒（不整份读进来）
	check("crafted.limits", XSaveSeal.MAX_FILE > XSaveSeal.MAX_PLAIN and XSaveSeal.MAX_PLAIN <= 128 * 1024 * 1024)


func _new_state() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 4
	return s


const NAMES := ["save_1", "save_2", "save_auto", "yunshang_orders_v1", "crown_progress_v1", "star_warehouse", "global"]


## 明文旧档迁移：开关关着时写出的明文档（与旧版本写的一样）＋各账本，打开开关后第一次读
func _legacy() -> void:
	XSaveSeal.ENABLED = false
	_reset_caches()
	var s := _new_state()
	s.gold = 4321
	XState.current = s
	check("legacy.plain_save", XSave.save(1) and XSave.save(2) and XSave.save_auto() and XSave.path(1).ends_with(".json"))
	check("legacy.plain_yunshang", XYunshangOrders.save_ledger({"version": 2, "profiles": {"p": {"x": 1}}, "legacyProfiles": {}}))
	check("legacy.plain_crown", XDemonCrown.save_ledger({"version": 1, "profiles": {"c": 2}, "legacy": {}}))
	XStarWarehouse.ensure_loaded()
	check("legacy.plain_warehouse", XStarWarehouse._save())
	var vid := int(XGlobalVars.variable_ids()[0]) if not XGlobalVars.variable_ids().is_empty() else 0
	XGlobalVars.ensure_loaded()
	XGlobalVars._variables[vid] = 77
	check("legacy.plain_global", XGlobalVars._save())
	var orig := {}
	for n in NAMES:
		orig[n] = _bytes(dir.path_join(n + ".json"))
	check("legacy.all_plain", NAMES.all(func(n): return orig[n].size() > 0 and char(orig[n][0]) in ["{", "["]))
	check("legacy.no_ksv", NAMES.all(func(n): return not FileAccess.file_exists(dir.path_join(n + ".ksv"))))
	# 打开开关、第一次读（标题摘要）
	XSaveSeal.ENABLED = true
	_reset_caches()
	var summary := XSave.summary(1)
	check("legacy.summary_ok", summary.begins_with("存档 1：") and not summary.contains("无法读取") and not summary.contains("校验失败"), summary)
	check("legacy.marker", XSaveSeal.marker_ok(dir))
	check("legacy.migrated_all", (XSaveSeal.last_migration.get("sealed", []) as Array).size() == NAMES.size() and (XSaveSeal.last_migration.failed as Array).is_empty(), XSaveSeal.last_migration)
	for n in NAMES:
		var k := dir.path_join(n + ".ksv")
		check("legacy.%s.json_kept" % n, _bytes(dir.path_join(n + ".json")) == orig[n])
		check("legacy.%s.sealed" % n, XSaveSeal.is_sealed(_bytes(k)))
		check("legacy.%s.same_text" % n, XSaveSeal.read_text(k) == orig[n].get_string_from_utf8())
	check("legacy.load", XSave.load_slot(1) and XState.current.gold == 4321)
	check("legacy.load_auto", XSave.load_auto() and XState.current.gold == 4321)
	var led = XYunshangOrders.load_ledger()
	check("legacy.yunshang_reads", led is Dictionary and led.profiles.has("p"))
	var crown = XDemonCrown.load_ledger()
	check("legacy.crown_reads", crown is Dictionary and crown.profiles.has("c"))
	XGlobalVars.ensure_loaded()
	check("legacy.global_reads", not XGlobalVars.seal_failed and XGlobalVars._variables.get(vid) == 77)
	XStarWarehouse.ensure_loaded()
	check("legacy.warehouse_reads", not XStarWarehouse.seal_failed)


## 补丁退回旧底包：旧代码只认 .json——覆盖 save_1.json、删 save_auto.json、在空格写 save_9.json，都碰不到 .ksv；
## 回到新版照读 .ksv，旧代码写的 .json 不读（有记号）；删掉记号后比 .ksv 新的 .json 重新封存（人工找回的办法）
func _old_code_rollback() -> void:
	var plain1 := _bytes(dir.path_join("save_1.json"))
	var d: Dictionary = JSON.parse_string(plain1.get_string_from_utf8())
	d.gold = 1
	OS.delay_msec(1100)  # 修改时间按秒：让「旧代码写的」比 .ksv 新
	_put(dir.path_join("save_1.json"), JSON.stringify(d).to_utf8_buffer())
	DirAccess.remove_absolute(dir.path_join("save_auto.json"))
	var ksv1 := _bytes(dir.path_join("save_1.ksv"))
	XSaveSeal.forget_dirs()
	check("rollback.ksv_untouched", _bytes(dir.path_join("save_1.ksv")) == ksv1 and FileAccess.file_exists(dir.path_join("save_auto.ksv")))
	check("rollback.new_reads_ksv", XSave.load_slot(1) and XState.current.gold == 4321)
	check("rollback.auto_still_there", XSave.exists_auto() and XSave.load_auto())
	# 人工找回：删记号重进，比 .ksv 新的 .json 重新封存
	DirAccess.remove_absolute(dir.path_join(XSaveSeal.MARKER))
	XSaveSeal.forget_dirs()
	check("rollback.recover_by_marker", XSave.load_slot(1) and XState.current.gold == 1 and XSaveSeal.marker_ok(dir))
	# 还原成 4321 给后面用
	XState.current.gold = 4321
	XSave.save(1)


## 新档往返；改一字节、截断、明文写进 .ksv 都校验失败，原文件一直在；存到失败的格先改名留着；删除也改名
func _new_and_tamper() -> void:
	var s := _new_state()
	s.gold = 999
	XState.current = s
	check("new.save", XSave.save(3))
	var p3 := XSave.path(3)
	check("new.ksv_name", p3.ends_with("save_3.ksv") and not FileAccess.file_exists(dir.path_join("save_3.json")))
	check("new.sealed_on_disk", XSaveSeal.is_sealed(_bytes(p3)) and not _bytes(p3).get_string_from_utf8().contains("\"mode\""))
	check("new.no_tmp_left", _files("save_3.ksv.").filter(func(n): return str(n).ends_with(".tmp")).is_empty())
	check("new.load", XSave.load_slot(3) and XState.current.gold == 999)
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
	XState.current = s
	check("tamper.save_over_ok", XSave.save(3))
	var kept := _files("save_3.ksv" + XSaveSeal.FAILED_MARK)
	check("tamper.quarantined", kept.size() == 1 and _bytes(dir.path_join(kept[0])) == tampered, kept)
	check("tamper.slot_readable_again", XSave.load_slot(3))
	var full := _bytes(p3)
	_put(p3, full.slice(0, full.size() - 40))
	check("trunc.failed", XSave.seal_failed(3) and not XSave.load_slot(3))
	check("trunc.kept", _bytes(p3).size() == full.size() - 40)
	check("trunc.remove_quarantines", XSave.remove(3) and not XSave.exists(3) and _files("save_3.ksv" + XSaveSeal.FAILED_MARK).size() == 2)
	_put(XSave.path(4), PackedByteArray())
	check("empty.failed", XSave.seal_failed(4))
	XSave.remove(4)
	# 明文写进 .ksv（改档工具把解开的内容存回去）
	var plain := JSON.stringify(s.to_dict()).to_utf8_buffer()
	_put(XSave.path(5), plain)
	check("plain_in_ksv.failed", XSave.seal_failed(5) and not XSave.load_slot(5) and _bytes(XSave.path(5)) == plain)
	XSave.remove(5)
	# 有记号后丢进来的明文 .json：不读（STRICT），关掉 STRICT 才重新封存
	_put(dir.path_join("save_6.json"), plain)
	XSaveSeal.forget_dirs()
	check("plain_after.ignored", not XSave.exists(6) and not XSave.load_slot(6))
	XSaveSeal.STRICT_AFTER_MIGRATE = false
	XSaveSeal.forget_dirs()
	check("plain_after.loose_migrates", XSave.exists(6) and XSave.load_slot(6))
	XSaveSeal.STRICT_AFTER_MIGRATE = true
	XSave.remove(6)
	DirAccess.remove_absolute(dir.path_join("save_6.json"))
	XState.current = s
	check("auto.save", XSave.save_auto() and XSaveSeal.is_sealed(_bytes(XSave.auto_path())))
	var auto_bad := _flip(XSave.auto_path(), 40)
	check("auto.failed", XSave.auto_seal_failed() and XSave.auto_summary().contains(XSaveSeal.FAIL_TEXT) and not XSave.load_auto())
	check("auto.kept", _bytes(XSave.auto_path()) == auto_bad)
	XState.current = s
	XSave.save(7)
	check("auto.quarantined_not_deleted", not XSave.exists_auto() and _files("save_auto.ksv" + XSaveSeal.FAILED_MARK).size() == 1)
	check("multi.slots_ok", [1, 2, 7].all(func(n): return not XSave.seal_failed(n) and XSave.load_slot(n)))


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
	for p in [yp, cp, wp, gp]:
		DirAccess.remove_absolute(p)
	_reset_caches()


## 开关关掉：读写回到 .json 明文，比 .json 新的 .ksv 先解开写回；再打开：比 .ksv 新的 .json 重新封存
func _switch_off() -> void:
	XSaveSeal.ENABLED = false
	_reset_caches()
	check("off.path_json", XSave.path(7).ends_with("save_7.json"))
	check("off.reads_sealed_via_unseal", XSave.load_slot(7) and XState.current != null)
	var s := _new_state()
	s.gold = 555
	XState.current = s
	OS.delay_msec(1100)
	check("off.save_plain", XSave.save(8) and char(_bytes(dir.path_join("save_8.json"))[0]) == "{")
	check("off.marker_removed", not FileAccess.file_exists(dir.path_join(XSaveSeal.MARKER)))
	check("off.reads_plain", XSave.load_slot(8) and XState.current.gold == 555)
	XSaveSeal.ENABLED = true
	_reset_caches()
	check("on_again.migrated", XSave.load_slot(8) and XState.current.gold == 555 and XSaveSeal.is_sealed(_bytes(dir.path_join("save_8.ksv"))) and XSaveSeal.marker_ok(dir))


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
	# D37：旧版明文导出照收，导入时写成封存格式
	var plain_imp := XSaveTransfer.parse_import(plain_export)
	check("xfer.plain_accepted_d37", plain_imp.has("data"), plain_imp)
	check("xfer.plain_import_sealed", XSaveTransfer.import_to(11, plain_imp.data) == "" and XSaveSeal.is_sealed(_bytes(XSave.path(11))) and XSave.load_slot(11)
		and not FileAccess.file_exists(dir.path_join("save_11.json")))
	XSaveTransfer.ACCEPT_PLAIN_IMPORT = false
	check("xfer.plain_refused_when_off", str(XSaveTransfer.parse_import(plain_export).get("error", "")).contains("没有签名"))
	XSaveTransfer.ACCEPT_PLAIN_IMPORT = true
	check("xfer.raw_sealed_file", XSaveTransfer.read_import(XSave.path(1)).has("data"))
	check("xfer.import_writes_sealed", XSaveTransfer.import_to(9, imp.data) == "" and XSaveSeal.is_sealed(_bytes(XSave.path(9))) and XSave.load_slot(9))


## co 甲档核查 P2①：校验失败的格导入多次（超过导入备份保留份数、同一秒），校验失败的原件始终在（唯一 .failed_ 名，不被清理）
func _import_keeps_failed() -> void:
	var data = XSaveTransfer.parse_import(str(XSaveTransfer.export_text(1).text)).data
	var p := XSave.path(10)
	XSave.save(10)
	var bad := _flip(p, 30)
	for i in range(XSaveSlim.IMPORT_KEEP + 3):
		XSaveTransfer.import_to(10, data)
	var kept := _files("save_10.ksv" + XSaveSeal.FAILED_MARK)
	check("import.failed_original_survives_prune", kept.size() == 1 and _bytes(dir.path_join(kept[0])) == bad, kept)
	var backups := _files("save_10.ksv.before_import_")
	check("import.backups_pruned_unique", backups.size() == XSaveSlim.IMPORT_KEEP, backups)
	check("import.slot_ok", XSave.load_slot(10))


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
				if f == "save_1.ksv" or f == "save_2.ksv":
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
	_reset_caches()
	var s := _new_state()
	s.gold = 2468
	XState.current = s
	XSave.save(1)
	var plain := _bytes(cold.path_join("save_1.json"))
	XSaveSeal.ENABLED = true
	_reset_caches()
	var saved := ReleaseEntry.simulate_release
	ReleaseEntry.simulate_release = true
	XState.current = null
	XSave.current_slot = 0
	var ok := XSave.load_slot(1)
	ReleaseEntry.simulate_release = saved
	check("release_cold.legacy_loads", ok and XState.current != null and XState.current.gold == 2468)
	check("release_cold.migrated", XSaveSeal.is_sealed(_bytes(cold.path_join("save_1.ksv"))) and XSaveSeal.marker_ok(cold)
		and _bytes(cold.path_join("save_1.json")) == plain)
	check("release_cold.text_same", XSaveSeal.read_text(cold.path_join("save_1.ksv")) == plain.get_string_from_utf8())
	XSave.dir_override = dir


## 发行密钥（co 甲档核查 P2④）：发行构建没注入密钥就不封存（照旧 .json 明文）、不认测试密钥；注入后用私密号写、旧号照读
func _release_keys() -> void:
	var test_blob := XSaveSeal.seal("{\"a\":1}")
	XSaveSeal.simulate_template = true
	XSaveSeal.key_file_override = dir.path_join("no_such_key.json")
	XSaveSeal.reload_keys()
	check("keys.release_without_key_no_seal", not XSaveSeal.active_now() and XSave.path(1).ends_with("save_1.json") and XSaveSeal.seal("x").is_empty())
	check("keys.release_rejects_test_key", not XSaveSeal.unseal(test_blob).ok)
	var kf := dir.path_join("key.json")
	_put(kf, JSON.stringify({"current": 3, "keys": {"2": "ab".repeat(32), "3": "cd".repeat(32)}}).to_utf8_buffer())
	XSaveSeal.key_file_override = kf
	XSaveSeal.reload_keys()
	var b3 := XSaveSeal.seal("{\"b\":2}")
	check("keys.release_with_key_seals", XSaveSeal.active_now() and int(b3[6]) == 3 and XSaveSeal.unseal(b3).ok and XSave.path(1).ends_with(".ksv"))
	check("keys.release_still_rejects_test_key", not XSaveSeal.unseal(test_blob).ok)
	_put(kf, JSON.stringify({"current": 2, "keys": {"2": "ab".repeat(32)}}).to_utf8_buffer())
	XSaveSeal.reload_keys()
	check("keys.other_key_not_accepted", not XSaveSeal.unseal(b3).ok)
	XSaveSeal.simulate_template = false
	XSaveSeal.key_file_override = ""
	XSaveSeal.reload_keys()
	check("keys.dev_test_key_back", XSaveSeal.active_now() and XSaveSeal.unseal(test_blob).ok)


## 迁移写不进（.ksv 的临时文件位置被占）：不放记号，旧档照旧从 .json 读，不当成空档；腾出来后下个进程迁移
func _migrate_fails() -> void:
	var d2 := dir.path_join("mfail")
	DirAccess.make_dir_recursive_absolute(d2)
	XSave.dir_override = d2
	XSaveSeal.ENABLED = false
	_reset_caches()
	var s := _new_state()
	s.gold = 1357
	XState.current = s
	XSave.save(1)
	XSaveSeal.ENABLED = true
	_reset_caches()
	DirAccess.make_dir_recursive_absolute(d2.path_join("save_1.ksv.tmp"))
	XState.current = null
	check("mfail.falls_back_to_json", XSave.exists(1) and XSave.path(1).ends_with(".json") and XSave.load_slot(1) and XState.current.gold == 1357)
	check("mfail.no_marker", not XSaveSeal.marker_ok(d2) and not FileAccess.file_exists(d2.path_join("save_1.ksv")))
	DirAccess.remove_absolute(d2.path_join("save_1.ksv.tmp"))
	XSaveSeal.forget_dirs()
	check("mfail.retry_next_process", XSave.load_slot(1) and XSave.path(1).ends_with(".ksv") and XSaveSeal.marker_ok(d2))
	XSave.dir_override = dir
