class_name XDB
extends RefCounted
## 西游模式数据库：读取转换器生成的 generated/db/*.json（原 MV 数据，ID 不变）。
## 表按需加载并缓存；JSON 数字一律是 float，取 ID 时用 int()。

const BASE := "res://modes/xiyou/generated/"
static var _tables := {}
## 解析结果的只读缓存（木吒 2026-10-25）：大 JSON 每个测试场景、每次启动都要重新解析（Skills 23 MB 约 1.2 秒，
## slice_d* 150 MB 约 5 秒）。按文件内容 SHA-256 与引擎版本作键，把 JSON.parse_string 的结果 var_to_bytes 后 zstd 压缩存起来，
## 命中时 bytes_to_var 还原（同一份 Variant，回归 xiyou_json_cache 逐字节比对）。键只看内容，不看修改时间；缓存坏了就照常解析再重写。
## 回退：环境变量 XIYOU_JSON_CACHE=0，或把 json_cache 设为 false，即与原来一样每次直接解析。
const CACHE_FORMAT := 1
const CACHE_MAGIC := "XJC1"
static var json_cache := OS.get_environment("XIYOU_JSON_CACHE") != "0"
static var cache_dir_override := ""  # 测试用；空＝默认目录


static func available() -> bool:
	return FileAccess.file_exists(BASE + "db/System.json")


static func load_json(rel: String) -> Variant:
	return parse_file(BASE + rel)


## 读一份 JSON；与 JSON.parse_string(FileAccess.get_file_as_string(path)) 相同，读不到返回 null 并报错。
static func parse_file(path: String) -> Variant:
	if json_cache:
		var bytes := FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty():
			var file := _cache_file(path, bytes)
			var hit = _cache_read(file)
			if hit[0]:
				return hit[1]
			var value = _parse(path)
			if value != null:
				_cache_write(path, file, value)
			return value
	return _parse(path)


static func _parse(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("XDB: 读取失败 " + path.trim_prefix(BASE))
		return null
	return JSON.parse_string(text)


static func cache_dir() -> String:
	if cache_dir_override != "":
		return cache_dir_override
	# 导出版 res:// 只读，放用户目录；开发与测试放工程的 .godot（不入 Git，各工作树各一份，测试的临时 HOME 不影响）
	return "user://xiyou_json_cache" if OS.has_feature("template") else ProjectSettings.globalize_path("res://.godot/xiyou_json_cache")


static func _cache_file(path: String, bytes: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(("%d|%s|%s|" % [CACHE_FORMAT, Engine.get_version_info().hash, path]).to_utf8_buffer())
	h.update(bytes)
	return cache_dir().path_join(path.trim_prefix("res://").replace("/", "__") + "." + h.finish().hex_encode() + ".bin")


## 返回 [是否命中, 值]；文件不在、头不对、解压或还原失败都算未命中。
static func _cache_read(file: String) -> Array:
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null or f.get_length() <= 12:
		return [false, null]
	var head := f.get_buffer(4).get_string_from_ascii()
	var size := f.get_64()
	var packed := f.get_buffer(f.get_length() - 12)
	f.close()
	if head != CACHE_MAGIC or size <= 0 or packed.is_empty():
		return [false, null]
	var raw := packed.decompress(size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != size:
		return [false, null]
	return [true, bytes_to_var(raw)]


static func _cache_write(path: String, file: String, value: Variant) -> void:
	var dir := file.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return
	var raw := var_to_bytes(value)
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	# 先写临时文件再改名：几个测试同时写同一份时，读者只会看到完整文件或没有文件
	var temp := "%s.%d.%d.tmp" % [file, OS.get_process_id(), Time.get_ticks_usec()]
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(CACHE_MAGIC.to_ascii_buffer())
	f.store_64(raw.size())
	f.store_buffer(packed)
	f.close()
	if DirAccess.rename_absolute(temp, file) != OK:
		DirAccess.remove_absolute(temp)
		return
	# 同一源文件的旧版本缓存删掉，免得目录越积越大
	var prefix := path.trim_prefix("res://").replace("/", "__") + "."
	for name in DirAccess.get_files_at(dir):
		if name.begins_with(prefix) and name.ends_with(".bin") and dir.path_join(name) != file and name.count(".") == prefix.count(".") + 1:
			DirAccess.remove_absolute(dir.path_join(name))


static func table(name: String) -> Variant:
	if not _tables.has(name):
		_tables[name] = load_json("db/%s.json" % name)
		if name == "Skills" and _tables[name] is Array:
			XZhenqi.patch_rewards(_tables[name])  # 真气突破奖励的数值（CodexZhenqi.patchRewards）
	return _tables[name]


## 取一条记录；不存在或为空时返回 {}。
static func rec(name: String, id: int) -> Dictionary:
	var t: Array = table(name)
	if id <= 0 or id >= t.size() or t[id] == null:
		return {}
	return t[id]


static func system() -> Dictionary:
	return table("System")


static func plugin(name: String) -> Dictionary:
	return table("Plugins").get(name, {})


static func map(map_id: int) -> Dictionary:
	var key := "map:%d" % map_id
	if not _tables.has(key):
		_tables[key] = load_json("maps/Map%03d.json" % map_id)
	return _tables[key] if _tables[key] != null else {}


static func img_path(folder: String, name: String) -> String:
	for ext in [".png", ".jpg"]:
		var p := "%simg/%s/%s%s" % [BASE, folder, name, ext]
		if ResourceLoader.exists(p):
			return p
	return ""


static func audio_path(folder: String, name: String) -> String:
	var p := "%saudio/%s/%s.ogg" % [BASE, folder, name]
	return p if ResourceLoader.exists(p) else ""
