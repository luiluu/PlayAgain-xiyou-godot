class_name XSaveSeal
extends RefCounted
## 存档封存：加密＋签名（Kyo 11-15 D28「不允许玩家修改存档」，O-待定·存档封存）。
##
## 管哪些文件（covered）：存档目录里的 save_<N>.json、save_auto.json、云裳账本 yunshang_orders_v1.json、魔冠账本 crown_progress_v1.json、
## 星级仓库 star_warehouse.json、跨存档变量 global.json。设置（options.json）、触屏设置、测试模式、瘦身日志、各种 .bak 备份不封。
##
## 文件格式（封存第 1 版，二进制）：
##   0   "KYSV"            4 字节魔数
##   4   版本 u8 = 1
##   5   标志 u8（bit0＝内容先 deflate 压缩）
##   6   保留 2 字节 = 0
##   8   明文 UTF-8 字节数 u32（小端）
##   12  IV 16 字节（每次写随机）
##   28  密文：AES-256-CBC（PKCS#7 补齐）加密的（压缩后的）存档 JSON
##   末尾 32 字节：HMAC-SHA256（签名密钥，签前面全部字节）
## 先验签名再解密；签名不对、长度不对、解压后字节数对不上都算「校验失败」。
## 两把密钥都由编进游戏的 SECRET 派生。**这只防普通改档工具和手改数字，防不住逆向**（会拆包的人能拿到密钥；
## 本仓库公开期间源码里就能看到，见交付单「需要用户决定」）。
##
## 旧档（明文 JSON）：某个存档目录第一次被读时（ensure_dir），把目录里能解析的明文封存文件逐个先原样复制成
## <文件>.plain_<时间>.bak（逐字节核对），再改写成封存格式（写临时文件、解开核对和原文一字不差才替换）；全部成功后在目录里放
## 记号文件 .sealed_v1（本身也是封存格式）。有记号之后再出现的明文文件按校验失败处理（STRICT_AFTER_MIGRATE）。
## 迁移有一步不成：那个文件原样留着（照明文读），不放记号，下次进来再试。
##
## 校验失败时（read 返回 status＝"failed"）：调用方不读、不覆盖、不删。存档写到校验失败的那一格前，先把原文件改名成
## <文件>.failed_<时间>（quarantine），原文件内容一字不动地留着，跟着「反馈问卷」导出的存档包一起走。

## O-待定·存档封存。true：封存格式写盘，读封存与明文旧档（旧档读到即迁移）；false：照旧写明文，两种格式都读（回退）。
static var ENABLED := true
## 目录迁移完（有记号）后，明文文件当校验失败。false：明文一直能读（只防改封存文件，不防把明文丢回目录）。
static var STRICT_AFTER_MIGRATE := true

const MAGIC := "KYSV"
const VERSION := 1
const FLAG_DEFLATE := 1
const HEADER := 12
const IV_LEN := 16
const MAC_LEN := 32
const MARKER := ".sealed_v1"
const PLAIN_BACKUP := ".plain_"
const FAILED_MARK := ".failed_"
const COVERED := ["save_auto.json", "yunshang_orders_v1.json", "crown_progress_v1.json", "star_warehouse.json", "global.json"]
## 密钥种子（改它等于作废所有已封存的存档，别改）
const SECRET := "3197f8f4a8a6d41775b4000692f23b851a8fed5b48e57aa404fd8017123569d3"

const FAIL_TEXT := "存档校验失败"
const FAIL_HINT := "原文件已保留，可通过游戏内反馈问卷导出存档发给我们。"

## 本进程里迁移失败过的目录（不每次读都重扫）
static var _tried := {}
## 最近一次迁移的结果（测试、日志用）：{dir, sealed: [文件名], backups: [文件名], failed: [文件名]}
static var last_migration := {}

static var _keys := []


static func _enc_key() -> PackedByteArray:
	if _keys.is_empty():
		_keys = [(SECRET + "|enc|v1").sha256_buffer(), (SECRET + "|mac|v1").sha256_buffer()]
	return _keys[0]

static func _mac_key() -> PackedByteArray:
	_enc_key()
	return _keys[1]


## 文件名归封存管吗
static func covered(path: String) -> bool:
	var name := path.get_file()
	if name in COVERED:
		return true
	if not (name.begins_with("save_") and name.ends_with(".json")):
		return false
	return name.trim_prefix("save_").trim_suffix(".json").is_valid_int()


static func is_sealed(bytes: PackedByteArray) -> bool:
	return bytes.size() >= 4 and bytes.slice(0, 4).get_string_from_ascii() == MAGIC


# ---- 编码 ----

## 把文字封成封存格式的字节
static func seal(text: String) -> PackedByteArray:
	var plain := text.to_utf8_buffer()
	var body := plain.compress(FileAccess.COMPRESSION_DEFLATE)
	var pad := 16 - body.size() % 16
	for i in range(pad):
		body.append(pad)
	var iv := Crypto.new().generate_random_bytes(IV_LEN)
	var aes := AESContext.new()
	aes.start(AESContext.MODE_CBC_ENCRYPT, _enc_key(), iv)
	var cipher := aes.update(body)
	aes.finish()
	var out := PackedByteArray()
	out.append_array(MAGIC.to_ascii_buffer())
	out.append_array(PackedByteArray([VERSION, FLAG_DEFLATE, 0, 0, 0, 0, 0, 0]))
	out.encode_u32(8, plain.size())
	out.append_array(iv)
	out.append_array(cipher)
	out.append_array(Crypto.new().hmac_digest(HashingContext.HASH_SHA256, _mac_key(), out))
	return out


## 解开封存字节：{"ok": true, "text": …} 或 {"ok": false, "why": …}
static func unseal(bytes: PackedByteArray) -> Dictionary:
	if not is_sealed(bytes):
		return {"ok": false, "why": "不是封存格式"}
	var n := bytes.size()
	if n < HEADER + IV_LEN + 16 + MAC_LEN or (n - HEADER - IV_LEN - MAC_LEN) % 16 != 0:
		return {"ok": false, "why": "长度不对"}
	if int(bytes[4]) != VERSION:
		return {"ok": false, "why": "封存版本 %d 不认得" % int(bytes[4])}
	var signed := bytes.slice(0, n - MAC_LEN)
	var mac := Crypto.new().hmac_digest(HashingContext.HASH_SHA256, _mac_key(), signed)
	if not Crypto.new().constant_time_compare(mac, bytes.slice(n - MAC_LEN)):
		return {"ok": false, "why": "签名不对"}
	var flags := int(bytes[5])
	var plain_len := bytes.decode_u32(8)
	var aes := AESContext.new()
	aes.start(AESContext.MODE_CBC_DECRYPT, _enc_key(), bytes.slice(HEADER, HEADER + IV_LEN))
	var body := aes.update(bytes.slice(HEADER + IV_LEN, n - MAC_LEN))
	aes.finish()
	var pad := int(body[body.size() - 1]) if not body.is_empty() else 0
	if pad < 1 or pad > 16 or pad > body.size():
		return {"ok": false, "why": "补齐不对"}
	body = body.slice(0, body.size() - pad)
	var plain := body.decompress(plain_len, FileAccess.COMPRESSION_DEFLATE) if flags & FLAG_DEFLATE else body
	if plain.size() != plain_len:
		return {"ok": false, "why": "长度不对"}
	return {"ok": true, "text": plain.get_string_from_utf8()}


## 按当前开关要写进文件的字节
static func encode(text: String) -> PackedByteArray:
	return seal(text) if ENABLED else text.to_utf8_buffer()


# ---- 读 ----

## 读一个文件：{"status": "missing"|"sealed"|"plain"|"failed", "text": 文字（failed／missing 为 ""）, "why": 失败原因}
## 封存管的文件先确保所在目录迁移过（ensure_dir）。
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": "missing", "text": ""}
	var cov := covered(path)
	if cov and ENABLED:
		ensure_dir(path.get_base_dir())
	var bytes := FileAccess.get_file_as_bytes(path)
	if is_sealed(bytes):
		var r := unseal(bytes)
		return {"status": "sealed", "text": r.text} if r.ok else {"status": "failed", "text": "", "why": r.why}
	if cov and ENABLED and STRICT_AFTER_MIGRATE and marker_ok(path.get_base_dir()):
		return {"status": "failed", "text": "", "why": "目录已封存，出现了明文文件"}
	return {"status": "plain", "text": bytes.get_string_from_utf8()}


## 读成文字；没有或校验失败返回 ""
static func read_text(path: String) -> String:
	return str(read(path).text)


static func failed(path: String) -> bool:
	return str(read(path).status) == "failed"


# ---- 写 ----

## 写一个文件：同目录临时文件 → flush 查错、按字节数核对 → 改名替换。失败不动原文件、返回 false。
## seal_it＝false 时不管开关都写明文（瘦身日志等不归封存管的文件）。
static func store(path: String, text: String, seal_it := true) -> bool:
	var bytes := encode(text) if seal_it else text.to_utf8_buffer()
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return false
	var temp := "%s.%s.tmp" % [path, Crypto.new().generate_random_bytes(6).hex_encode()]
	if not _put(temp, bytes):
		DirAccess.remove_absolute(temp)
		return false
	if DirAccess.rename_absolute(temp, path) != OK:
		DirAccess.remove_absolute(temp)
		return false
	wrote(path, seal_it)
	return true


## 写成一个封存管的文件之后调：开关关着写了明文，就去掉目录记号（再打开开关时重新迁移，不把这些明文当成被改过）
static func wrote(path: String, seal_it := true) -> void:
	if seal_it and not ENABLED and covered(path):
		var m := path.get_base_dir().path_join(MARKER)
		if FileAccess.file_exists(m):
			DirAccess.remove_absolute(m)


static func _put(path: String, bytes: PackedByteArray) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	if ok:
		var check := FileAccess.open(path, FileAccess.READ)
		ok = check != null and check.get_length() == bytes.size()
		if check != null:
			check.close()
	return ok


## 写到 path 之前调：path 校验失败就先把它改名成 <文件>.failed_<时间> 留着（不覆盖、不删）。返回能不能接着写。
static func quarantine_if_failed(path: String) -> bool:
	if not FileAccess.file_exists(path) or not failed(path):
		return true
	var keep := "%s%s%s" % [path, FAILED_MARK, _stamp()]
	var n := 1
	while FileAccess.file_exists(keep):
		n += 1
		keep = "%s%s%s_%d" % [path, FAILED_MARK, _stamp(), n]
	if DirAccess.rename_absolute(path, keep) != OK:
		push_warning("XSaveSeal: 校验失败的存档改不了名，不写：" + path)
		return false
	push_warning("XSaveSeal: 校验失败的存档已改名留着：" + keep)
	return true


static func _stamp() -> String:
	return Time.get_datetime_string_from_system().replace(":", "").replace("-", "")


# ---- 旧档迁移 ----

static func marker_ok(dir: String) -> bool:
	var m := dir.path_join(MARKER)
	return FileAccess.file_exists(m) and unseal(FileAccess.get_file_as_bytes(m)).ok


## 这个目录还没迁移过就迁移（见文件头）。返回目录是否已封存（有记号）。
static func ensure_dir(dir: String) -> bool:
	if not ENABLED or dir == "" or not DirAccess.dir_exists_absolute(dir):
		return false
	if marker_ok(dir):
		return true
	if _tried.has(dir):
		return false
	last_migration = {"dir": dir, "sealed": [], "backups": [], "failed": []}
	var all_ok := true
	for name in DirAccess.get_files_at(dir):
		var p := dir.path_join(name)
		if not covered(p):
			continue
		var bytes := FileAccess.get_file_as_bytes(p)
		if is_sealed(bytes):
			continue
		var text := bytes.get_string_from_utf8()
		var json := JSON.new()
		if json.parse(text) != OK:
			continue  # 写了一半的坏明文：不封，原样留着（有记号后读到算校验失败）
		if _migrate(p, bytes, text):
			last_migration.sealed.append(name)
		else:
			last_migration.failed.append(name)
			all_ok = false
	if not all_ok or not _put_marker(dir):
		_tried[dir] = true
		return false
	if not (last_migration.sealed as Array).is_empty():
		print("XSaveSeal: 旧存档已补上签名：", JSON.stringify(last_migration))
	return true


static func _migrate(path: String, bytes: PackedByteArray, text: String) -> bool:
	var bak := "%s%s%s.bak" % [path, PLAIN_BACKUP, _stamp()]
	if not FileAccess.file_exists(bak):
		var part := bak + ".part"
		if not _put(part, bytes) or FileAccess.get_file_as_bytes(part) != bytes or DirAccess.rename_absolute(part, bak) != OK:
			DirAccess.remove_absolute(part)
			return false
	last_migration.backups.append(bak.get_file())
	var sealed := seal(text)
	var r := unseal(sealed)
	if not r.ok or str(r.text) != text:
		return false
	var temp := "%s.%s.tmp" % [path, Crypto.new().generate_random_bytes(6).hex_encode()]
	if not _put(temp, sealed) or DirAccess.rename_absolute(temp, path) != OK:
		DirAccess.remove_absolute(temp)
		return false
	return true


static func _put_marker(dir: String) -> bool:
	var m := dir.path_join(MARKER)
	var temp := m + ".tmp"
	if not _put(temp, seal(JSON.stringify({"sealedAt": Time.get_datetime_string_from_system(), "version": VERSION}))) \
			or DirAccess.rename_absolute(temp, m) != OK:
		DirAccess.remove_absolute(temp)
		return false
	return true
