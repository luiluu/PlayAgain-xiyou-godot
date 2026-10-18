class_name XDB
extends RefCounted
## 西游模式数据库：读取转换器生成的 generated/db/*.json（原 MV 数据，ID 不变）。
## 表按需加载并缓存；JSON 数字一律是 float，取 ID 时用 int()。

const BASE := "res://modes/xiyou/generated/"
static var _tables := {}


static func available() -> bool:
	return FileAccess.file_exists(BASE + "db/System.json")


static func load_json(rel: String) -> Variant:
	var text := FileAccess.get_file_as_string(BASE + rel)
	if text == "":
		push_error("XDB: 读取失败 " + rel)
		return null
	return JSON.parse_string(text)


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
