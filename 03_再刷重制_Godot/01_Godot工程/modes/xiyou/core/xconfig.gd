class_name XConfig
extends RefCounted
## 西游界面配置（MV ConfigManager），与局内存档分开。当前接入 MapXy；选项页后续复用。
## 测试传入自己的 path_override；其余使用 XSave.dir_override 的测试只在内存改配置。

static var path_override := ""
static var _loaded_path := "<unloaded>"
static var _values := {}
static var _map_xy_configured := false


static func path() -> String:
	if path_override != "":
		return path_override
	return "" if XSave.dir_override != "" else "user://modes/xiyou/options.json"


static func ensure_loaded() -> void:
	var p := path()
	if p == _loaded_path:
		return
	_loaded_path = p
	_values = {"MapXy": false}  # ConfigManager.readFlag：没有配置时为 false
	_map_xy_configured = false
	if p != "" and FileAccess.file_exists(p):
		var data = JSON.parse_string(FileAccess.get_file_as_string(p))
		if data is Dictionary:
			_values.MapXy = bool(data.get("MapXy", false))
			_map_xy_configured = data.has("MapXy")


static func map_xy() -> bool:
	ensure_loaded()
	return bool(_values.MapXy)


static func has_map_xy() -> bool:
	ensure_loaded()
	return _map_xy_configured


static func set_map_xy(value: bool) -> bool:
	ensure_loaded()
	_values.MapXy = value
	_map_xy_configured = true
	var p := path()
	if p == "":
		return true
	if DirAccess.make_dir_recursive_absolute(p.get_base_dir()) != OK:
		return false
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(_values))
	var ok := f.get_error() == OK
	f.close()
	return ok
