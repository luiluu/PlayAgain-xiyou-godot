class_name XConfig
extends RefCounted
## 西游界面配置（MV ConfigManager），与局内存档分开；默认值照正式引擎内存测量。
## 测试传入自己的 path_override；其余使用 XSave.dir_override 的测试只在内存改配置。

static var path_override := ""
static var _loaded_path := "<unloaded>"
static var _values := {}
static var _map_xy_configured := false
const DEFAULTS := {"MapXy": false, "codexSmartAI": true, "alwaysDash": true, "commandRemember": true,
	"bgmVolume": 40, "bgsVolume": 40, "meVolume": 40, "seVolume": 40,
	"CombatDamageShow": true, "CombatSkillAnimation": false, "battleAniSpeed": 4}
const VOLUMES := ["bgmVolume", "bgsVolume", "meVolume", "seVolume"]


static func path() -> String:
	if path_override != "":
		return path_override
	return "" if XSave.dir_override != "" else "user://modes/xiyou/options.json"


static func ensure_loaded() -> void:
	var p := path()
	if p == _loaded_path:
		return
	_loaded_path = p
	_values = DEFAULTS.duplicate()  # 正式版 applyData({}) 的实际默认值（含后续插件覆盖）
	_map_xy_configured = false
	if p != "" and FileAccess.file_exists(p):
		var data = JSON.parse_string(FileAccess.get_file_as_string(p))
		if data is Dictionary:
			for key in DEFAULTS:
				if key in VOLUMES:
					_values[key] = clampi(int(data.get(key, DEFAULTS[key])), 0, 100)
				elif key == "battleAniSpeed":
					_values[key] = clampi(int(data.get(key, DEFAULTS[key])), 1, 4)
				else:
					_values[key] = bool(data.get(key, DEFAULTS[key]))
			_map_xy_configured = data.has("MapXy")
	XAudio.apply_volumes(_values)


static func flag(key: String) -> bool:
	ensure_loaded()
	return bool(_values.get(key, false))


static func set_flag(key: String, value: bool) -> bool:
	if key not in DEFAULTS or key in VOLUMES or key == "battleAniSpeed":
		return false
	ensure_loaded()
	_values[key] = value
	if key == "MapXy":
		_map_xy_configured = true
	return _write()


static func volume(key: String) -> int:
	ensure_loaded()
	return int(_values.get(key, 40))


static func set_volume(key: String, value: int) -> bool:
	if key not in VOLUMES:
		return false
	ensure_loaded()
	_values[key] = clampi(value, 0, 100)
	XAudio.apply_volumes(_values)
	return _write()


## YEP_BattleAniSpeedOpt：1 四倍、2 三倍、3 二倍、4 OFF。
static func battle_speed() -> int:
	ensure_loaded()
	return int(_values.battleAniSpeed)


static func set_battle_speed(value: int) -> bool:
	ensure_loaded()
	_values.battleAniSpeed = clampi(value, 1, 4)
	return _write()


static func battle_speed_text() -> String:
	return ["四倍", "三倍", "二倍", "OFF"][battle_speed() - 1]


static func map_xy() -> bool:
	ensure_loaded()
	return bool(_values.MapXy)


static func has_map_xy() -> bool:
	ensure_loaded()
	return _map_xy_configured


static func set_map_xy(value: bool) -> bool:
	return set_flag("MapXy", value)


## Codex_SmartBattleAI 的 ConfigManager.codexSmartAI（设置「智能战斗AI（自动战斗）」）
static func smart_ai() -> bool:
	ensure_loaded()
	return bool(_values.codexSmartAI)


static func set_smart_ai(value: bool) -> bool:
	return set_flag("codexSmartAI", value)


static func _write() -> bool:
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
