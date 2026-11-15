class_name XSaveSeal
extends RefCounted
## 存档封存：加密＋签名（Kyo 11-15 D28「不允许玩家修改存档」，O-待定·存档封存）。
##
## 管哪些文件（covered）：存档目录里的存档 save_<N>、自动存档 save_auto、云裳账本 yunshang_orders_v1、魔冠账本 crown_progress_v1、
## 星级仓库 star_warehouse、跨存档变量 global。设置（options.json）、触屏设置、测试模式、瘦身日志、各种备份不封。
##
## **封存档用新文件名 <名>.ksv，明文旧档 <名>.json 留在原处当备份**（co 甲档核查 P1 返修）：补丁退回旧底包时，旧代码只认 .json，
## 看不见 .ksv，就不会覆盖、删除封存档（旧代码照旧读写它自己那份 .json，进度和封存档各走各的）。
## 读写路径一律经 active(<名>.json)：开关开着换成 .ksv，关着仍是 .json。
##
## 文件格式（封存第 1 版，二进制）：
##   0   "KYSV"            4 字节魔数
##   4   版本 u8 = 1
##   5   标志 u8（bit0＝内容先 deflate 压缩）
##   6   密钥号 u8（0＝开发／测试用的公开测试密钥；发行包用出包时注入的私密密钥，号 ≥ 1）
##   7   保留 1 字节 = 0
##   8   明文 UTF-8 字节数 u32（小端）
##   12  IV 16 字节（每次写随机）
##   28  密文：AES-256-CBC（PKCS#7 补齐）加密的（压缩后的）存档 JSON
##   末尾 32 字节：HMAC-SHA256（签名密钥，签前面全部字节）
## 先验签名（HMAC 在解密之前，常数时间比较）再解密；签名不对、长度超限、补齐（每一个补齐字节都核）不对、解压后字节数对不上，都算校验失败。
## 明文上限 MAX_PLAIN、文件上限 MAX_FILE：读文件、解压前先查，带合法签名的超大声明也不分配。
## **这只防普通改档工具和手改数字，防不住逆向**（会拆包的人能拿到密钥）。
##
## 密钥（co 甲档核查 P2④ 返修）：公开仓库里只有测试密钥（TEST_SECRET，号 0，谁都看得到，只给开发和测试用）。
## 发行密钥放在私密设计仓（不进本仓库），出包时 发行出包.py 把它写进导出用的工程副本 res://content/save_seal_key.json
## （本仓库 .gitignore 掉这个文件）。发行构建（OS 有 template 特性）里：没有注入的密钥就**不封存**（照旧写明文，读两种格式；
## 补丁装到没有密钥的旧底包上也是这样），也不认号 0 的测试密钥（否则拿公开测试密钥封的假档就能读进来）。
## 密钥文件 {"current": 号, "keys": {"号": "64 位十六进制"}}：写用 current，读认文件里所有号——以后换密钥加新号、旧号留着读老档。
##
## 旧档（明文 <名>.json）：某个存档目录第一次被读时（ensure_dir），目录里每个能解析、又比同名 .ksv 新（或没有 .ksv）的明文封存文件，
## 封成 .ksv（写临时文件 → 读回临时文件解开、和原文一字不差 → 改名替换），原 .json 不动、留作备份；全部成功后放记号 .sealed_v1（本身也封存）。
## 有记号之后不再看 .json（STRICT_AFTER_MIGRATE）：旧代码在退回期间写的 .json、手改的 .json 都不会被读进来（原文件都在，可人工找回：
## 删掉 .sealed_v1 后重进，比 .ksv 新的 .json 会重新封存）。迁移有一步不成：那个文件不动，不放记号，下个进程再试。
##
## 校验失败（read 返回 status＝"failed"）：调用方不读、不覆盖、不删。写到校验失败的文件之前先把它改名成 <文件>.failed_<时间>[_n]
## （quarantine），内容一字不动地留着，跟着「反馈问卷」导出的存档包一起走；这个名字不会被任何自动清理删掉。
##
## 开关关闭（ENABLED＝false，回退）：读写都回到 .json 明文；第一次读某个目录时，比 .json 新的 .ksv 先解开写回 .json（两种格式都读得到），
## 并去掉记号——再打开开关时重新迁移比 .ksv 新的 .json。

## O-待定·存档封存。true：封存（有密钥时）；false：照旧写明文 .json，.ksv 解开写回 .json（回退）。
static var ENABLED := true
## 目录迁移完（有记号）后不再读 .json。false：每次进目录都把比 .ksv 新的 .json 重新封存（不防把改过的明文丢回目录）。
static var STRICT_AFTER_MIGRATE := true
## 测试用：当成发行构建（不认测试密钥、要注入的密钥）
static var simulate_template := false
## 测试用：密钥文件路径（空＝res://content/save_seal_key.json）
static var key_file_override := ""

const MAGIC := "KYSV"
const VERSION := 1
const FLAG_DEFLATE := 1
const HEADER := 12
const IV_LEN := 16
const MAC_LEN := 32
const EXT := ".ksv"
const MARKER := ".sealed_v1"
const FAILED_MARK := ".failed_"
const KEY_FILE := "res://content/save_seal_key.json"
## 明文上限 128 MiB（现在最大的存档几 MB）；文件上限按明文上限加头尾算（deflate 最坏也只比原文多一点）
const MAX_PLAIN := 128 * 1024 * 1024
const MAX_FILE := MAX_PLAIN + MAX_PLAIN / 64 + 1024
const STEMS := ["save_auto", "yunshang_orders_v1", "crown_progress_v1", "star_warehouse", "global"]
## 公开测试密钥（号 0）：只给开发、测试用，发行构建不认。不是发行密钥。
const TEST_SECRET := "xiyou-remake-save-seal-PUBLIC-TEST-KEY-not-for-release"

const FAIL_TEXT := "存档校验失败"
const FAIL_HINT := "原文件已保留，可通过游戏内反馈问卷导出存档发给我们。"

## 本进程里迁移失败过的目录（不每次读都重扫）、开关关着时解开过的目录
static var _tried := {}
static var _unsealed := {}
static var _migrating := {}
static var _ok_dirs := {}
## 最近一次迁移的结果（测试、日志用）：{dir, sealed: [文件名], failed: [文件名]}
static var last_migration := {}

## 号 → [加密钥, 签名钥]；_key_src 记从哪儿读的（换了覆盖路径重读）
static var _keys := {}
static var _current := -1
static var _key_src := "<none>"


# ---- 密钥 ----

static func is_template() -> bool:
	return simulate_template or OS.has_feature("template")


static func _derive(secret: String) -> Array:
	return [(secret + "|enc|v1").sha256_buffer(), (secret + "|mac|v1").sha256_buffer()]


static func _load_keys() -> void:
	var src := key_file_override if key_file_override != "" else KEY_FILE
	if src == _key_src:
		return
	_key_src = src
	_keys = {}
	_current = -1
	if not is_template():
		_keys[0] = _derive(TEST_SECRET)
		_current = 0
	if FileAccess.file_exists(src):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(src)) == OK and json.data is Dictionary and json.data.get("keys") is Dictionary:
			for k in json.data.keys:
				var id := int(str(k)) if str(k).is_valid_int() else 0
				var hex := str(json.data.keys[k])
				if id >= 1 and id <= 255 and hex.length() >= 32:
					_keys[id] = _derive(hex)
			var cur := int(json.data.get("current", 0))
			if _keys.has(cur) and cur >= 1:
				_current = cur


## 换了密钥文件、模拟开关后重读（测试用）
static func reload_keys() -> void:
	_key_src = "<none>"
	_keys = {}
	_current = -1


## 现在能不能封存：开关开着、而且有可写的密钥（发行构建要注入的密钥）
static func active_now() -> bool:
	if not ENABLED:
		return false
	_load_keys()
	return _current >= 0


# ---- 路径 ----

static func _stem(name: String) -> String:
	for ext in [".json", EXT]:
		if name.ends_with(ext):
			return name.trim_suffix(ext)
	return ""


## 文件名归封存管吗（.json 或 .ksv）
static func covered(path: String) -> bool:
	var stem := _stem(path.get_file())
	if stem == "":
		return false
	if stem in STEMS:
		return true
	return stem.begins_with("save_") and stem.trim_prefix("save_").is_valid_int()


## 存档入口用的路径：先让所在目录迁移（开着）或解开写回（关着），再给实际读写的文件
static func resolve(json_path: String) -> String:
	if covered(json_path):
		if active_now():
			var dir := json_path.get_base_dir()
			if not ensure_dir(dir) and json_path.ends_with(".json") and FileAccess.file_exists(json_path) \
					and not FileAccess.file_exists(active(json_path)):
				# 这个目录迁移没成（磁盘满、写不进）：没封存过的旧档照旧用明文 .json，别当成空档（下个进程再试迁移）
				return json_path
		else:
			ensure_plain_dir(json_path.get_base_dir())
	return active(json_path)


## 实际读写的文件：给 <名>.json，封存开着时换成 <名>.ksv
static func active(json_path: String) -> String:
	if active_now() and covered(json_path) and json_path.ends_with(".json"):
		return json_path.trim_suffix(".json") + EXT
	return json_path


static func is_sealed(bytes: PackedByteArray) -> bool:
	return bytes.size() >= 4 and bytes.slice(0, 4).get_string_from_ascii() == MAGIC


# ---- 编码 ----

## 把文字封成封存格式的字节（用当前密钥）；没有可用密钥返回空
static func seal(text: String) -> PackedByteArray:
	_load_keys()
	if _current < 0:
		return PackedByteArray()
	var plain := text.to_utf8_buffer()
	var body := plain.compress(FileAccess.COMPRESSION_DEFLATE)
	var pad := 16 - body.size() % 16
	for i in range(pad):
		body.append(pad)
	var iv := Crypto.new().generate_random_bytes(IV_LEN)
	var aes := AESContext.new()
	aes.start(AESContext.MODE_CBC_ENCRYPT, _keys[_current][0], iv)
	var cipher := aes.update(body)
	aes.finish()
	var out := PackedByteArray()
	out.append_array(MAGIC.to_ascii_buffer())
	out.append_array(PackedByteArray([VERSION, FLAG_DEFLATE, _current, 0, 0, 0, 0, 0]))
	out.encode_u32(8, plain.size())
	out.append_array(iv)
	out.append_array(cipher)
	out.append_array(Crypto.new().hmac_digest(HashingContext.HASH_SHA256, _keys[_current][1], out))
	return out


## 解开封存字节：{"ok": true, "text": …} 或 {"ok": false, "why": …}
static func unseal(bytes: PackedByteArray) -> Dictionary:
	if not is_sealed(bytes):
		return {"ok": false, "why": "不是封存格式"}
	var n := bytes.size()
	if n > MAX_FILE:
		return {"ok": false, "why": "文件太大"}
	if n < HEADER + IV_LEN + 16 + MAC_LEN or (n - HEADER - IV_LEN - MAC_LEN) % 16 != 0:
		return {"ok": false, "why": "长度不对"}
	if int(bytes[4]) != VERSION:
		return {"ok": false, "why": "封存版本 %d 不认得" % int(bytes[4])}
	_load_keys()
	var kid := int(bytes[6])
	if not _keys.has(kid):
		return {"ok": false, "why": "密钥号 %d 不认得" % kid}
	# 签名在先：没过签名的字节一个都不解密、不解压
	var mac := Crypto.new().hmac_digest(HashingContext.HASH_SHA256, _keys[kid][1], bytes.slice(0, n - MAC_LEN))
	if not Crypto.new().constant_time_compare(mac, bytes.slice(n - MAC_LEN)):
		return {"ok": false, "why": "签名不对"}
	var flags := int(bytes[5])
	var plain_len := bytes.decode_u32(8)
	if plain_len > MAX_PLAIN:
		return {"ok": false, "why": "声明的长度超过上限"}
	var aes := AESContext.new()
	aes.start(AESContext.MODE_CBC_DECRYPT, _keys[kid][0], bytes.slice(HEADER, HEADER + IV_LEN))
	var body := aes.update(bytes.slice(HEADER + IV_LEN, n - MAC_LEN))
	aes.finish()
	var pad := int(body[body.size() - 1]) if not body.is_empty() else 0
	if pad < 1 or pad > 16 or pad > body.size():
		return {"ok": false, "why": "补齐不对"}
	for i in range(body.size() - pad, body.size()):
		if int(body[i]) != pad:
			return {"ok": false, "why": "补齐不对"}
	body = body.slice(0, body.size() - pad)
	if not flags & FLAG_DEFLATE and body.size() != plain_len:
		return {"ok": false, "why": "长度不对"}
	# decompress 按 plain_len 分配、最多解出这么多（plain_len 已过上限检查），压缩炸弹解不出更多
	var plain := body.decompress(plain_len, FileAccess.COMPRESSION_DEFLATE) if flags & FLAG_DEFLATE else body
	if plain.size() != plain_len:
		return {"ok": false, "why": "长度不对"}
	return {"ok": true, "text": plain.get_string_from_utf8()}


# ---- 读 ----

static func _read_bytes(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	if f.get_length() > MAX_FILE:
		f.close()
		return null
	var b := f.get_buffer(f.get_length())
	f.close()
	return b


## 读一个文件：{"status": "missing"|"sealed"|"plain"|"failed", "text": 文字（failed／missing 为 ""）, "why": 失败原因}
## 封存管的文件先确保所在目录迁移过（开关开着）或 .ksv 解开写回过（开关关着）。.ksv 不是封存格式也算失败。
static func read(path: String) -> Dictionary:
	if covered(path):
		if active_now():
			ensure_dir(path.get_base_dir())
		else:
			ensure_plain_dir(path.get_base_dir())
	if not FileAccess.file_exists(path):
		return {"status": "missing", "text": ""}
	var raw = _read_bytes(path)
	if raw == null:
		return {"status": "failed", "text": "", "why": "读不了或太大"}
	var bytes: PackedByteArray = raw
	if is_sealed(bytes):
		var r := unseal(bytes)
		return {"status": "sealed", "text": r.text} if r.ok else {"status": "failed", "text": "", "why": r.why}
	if path.ends_with(EXT):
		return {"status": "failed", "text": "", "why": "封存文件不是封存格式"}
	return {"status": "plain", "text": bytes.get_string_from_utf8()}


## 读成文字；没有或校验失败返回 ""
static func read_text(path: String) -> String:
	return str(read(path).text)


static func failed(path: String) -> bool:
	return str(read(path).status) == "failed"


# ---- 写 ----

## 写一个文件：.ksv 写封存格式、别的写明文。同目录临时文件 → flush 查错 → 读回核对（封存的解开和原文一字不差，明文逐字节）→ 改名替换。
## 失败不动原文件、返回 false。
static func write_file(path: String, text: String) -> bool:
	var sealed := path.ends_with(EXT)
	var bytes := seal(text) if sealed else text.to_utf8_buffer()
	if sealed and bytes.is_empty():
		return false
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return false
	var temp := path + ".tmp"  # 同 XSave 原来的写法（残留的由 XSaveSlim.sweep_temp 清）
	if not _put(temp, bytes) or not _verify(temp, bytes, text, sealed) or DirAccess.rename_absolute(temp, path) != OK:
		DirAccess.remove_absolute(temp)
		return false
	wrote(path)
	return true


## 旧名（测试夹具用）：写到 path，按扩展名封存或明文
static func store(path: String, text: String) -> bool:
	return write_file(path, text)


static func _verify(temp: String, bytes: PackedByteArray, text: String, sealed: bool) -> bool:
	var back = _read_bytes(temp)
	if back == null or back != bytes:
		return false
	if not sealed:
		return true
	var r := unseal(back)
	return r.ok and str(r.text) == text


## 写成一个封存管的文件之后调：开关关着写了明文，就去掉目录记号（再打开开关时重新迁移，不把这些明文当成没用的旧档）
static func wrote(path: String) -> void:
	if covered(path) and path.ends_with(".json") and not active_now():
		var m := path.get_base_dir().path_join(MARKER)
		if FileAccess.file_exists(m):
			DirAccess.remove_absolute(m)
		_ok_dirs.erase(path.get_base_dir())


static func _put(path: String, bytes: PackedByteArray) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	return ok


## 写到 path 之前调：path 校验失败就先把它改名成唯一的 <文件>.failed_<时间>[_n] 留着（不覆盖、不删）。返回能不能接着写。
static func quarantine_if_failed(path: String) -> bool:
	if not FileAccess.file_exists(path) or not failed(path):
		return true
	var keep := unique_name("%s%s%s" % [path, FAILED_MARK, _stamp()])
	if DirAccess.rename_absolute(path, keep) != OK:
		push_warning("XSaveSeal: 校验失败的存档改不了名，不写：" + path)
		return false
	push_warning("XSaveSeal: 校验失败的存档已改名留着：" + keep)
	return true


## base 已有就加 _2、_3……（suffix 加在最后）
static func unique_name(base: String, suffix := "") -> String:
	var p := base + suffix
	var n := 1
	while FileAccess.file_exists(p):
		n += 1
		p = "%s_%d%s" % [base, n, suffix]
	return p


static func _stamp() -> String:
	return Time.get_datetime_string_from_system().replace(":", "").replace("-", "")


# ---- 旧档迁移 ----

static func marker_ok(dir: String) -> bool:
	var m := dir.path_join(MARKER)
	if not FileAccess.file_exists(m):
		return false
	var b = _read_bytes(m)
	return b != null and unseal(b).ok


## 封存开着：这个目录还没迁移过就迁移（见文件头）。返回目录是否已封存（有记号）。
static func ensure_dir(dir: String) -> bool:
	if not active_now() or dir == "" or not DirAccess.dir_exists_absolute(dir):
		return false
	if STRICT_AFTER_MIGRATE and _ok_dirs.has(dir) and FileAccess.file_exists(dir.path_join(MARKER)):
		return true
	if STRICT_AFTER_MIGRATE and marker_ok(dir):
		_ok_dirs[dir] = true
		return true
	if _tried.has(dir) or _migrating.has(dir):
		return false
	_migrating[dir] = true
	var done := _migrate_dir(dir)
	_migrating.erase(dir)
	return done


static func _migrate_dir(dir: String) -> bool:
	last_migration = {"dir": dir, "sealed": [], "failed": []}
	var all_ok := true
	for name in DirAccess.get_files_at(dir):
		var p := dir.path_join(name)
		if not (covered(p) and name.ends_with(".json")):
			continue
		var k := p.trim_suffix(".json") + EXT
		if FileAccess.file_exists(k) and FileAccess.get_modified_time(k) >= FileAccess.get_modified_time(p):
			continue
		var raw = _read_bytes(p)
		if raw == null or is_sealed(raw):
			continue
		var text: String = (raw as PackedByteArray).get_string_from_utf8()
		var json := JSON.new()
		if json.parse(text) != OK:
			continue  # 写了一半的坏明文：不封，原样留着
		if quarantine_if_failed(k) and write_file(k, text) and FileAccess.file_exists(k):
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


## 封存关着（回退）：比 .json 新的 .ksv 解开写回 .json（每个目录本进程一次），去掉记号
static func ensure_plain_dir(dir: String) -> void:
	if active_now():
		return
	if dir == "" or _unsealed.has(dir) or not DirAccess.dir_exists_absolute(dir):
		return
	_unsealed[dir] = true
	for name in DirAccess.get_files_at(dir):
		var k := dir.path_join(name)
		if not (covered(k) and name.ends_with(EXT)):
			continue
		var p := k.trim_suffix(EXT) + ".json"
		if FileAccess.file_exists(p) and FileAccess.get_modified_time(p) >= FileAccess.get_modified_time(k):
			continue
		var raw = _read_bytes(k)
		if raw == null:
			continue
		var r := unseal(raw)
		if r.ok:
			write_file(p, str(r.text))
	var m := dir.path_join(MARKER)
	if FileAccess.file_exists(m):
		DirAccess.remove_absolute(m)
	_ok_dirs.erase(dir)


## 测试用：清掉本进程的目录记忆
static func forget_dirs() -> void:
	_tried.clear()
	_unsealed.clear()
	_ok_dirs.clear()


static func _put_marker(dir: String) -> bool:
	var m := dir.path_join(MARKER)
	var temp := m + ".tmp"
	var b := seal(JSON.stringify({"sealedAt": Time.get_datetime_string_from_system(), "version": VERSION}))
	if b.is_empty() or not _put(temp, b) or DirAccess.rename_absolute(temp, m) != OK:
		DirAccess.remove_absolute(temp)
		return false
	return true
