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
	"CombatDamageShow": true, "CombatSkillAnimation": false, "battleAniSpeed": 4,
	"codexNotices": {"race": true, "chest": true, "zhenqi": true, "points": true, "drop": true, "learn": true, "dungeon": true, "share": true},
	"codexSkillLevelNotice": true}
const VOLUMES := ["bgmVolume", "bgsVolume", "meVolume", "seVolume"]
## 消息提醒（installV019UsabilityRuntime NOTICE 顺序＋技能升级通告）：[键, 名字, 说明]
const NOTICES := [["race", "种族消息", "种族祝福、猎物、血契、反攻等"], ["chest", "宝箱消息", "开宝箱后的收获汇总"],
	["zhenqi", "真气消息", "真气精进、大圆满、降服灵根等"], ["points", "积分消息", "肝帝积分、滑稽值、额外抽奖券"],
	["drop", "掉落消息", "副本Boss专属掉落、权能、锻造锤"], ["learn", "领悟消息", "角色领悟新技能"],
	["dungeon", "副本消息", "副本完成、逃离、关闭挂机"], ["share", "共享消息", "光环等技能共享、羁绊激活与失效"],
	["skillLevel", "技能升级通告", "技能升级时右上角的通告"]]


static func path() -> String:
	if path_override != "":
		return path_override
	return "" if XSave.dir_override != "" else "user://modes/xiyou/options.json"


static func ensure_loaded() -> void:
	var p := path()
	if p == _loaded_path:
		return
	_loaded_path = p
	_values = DEFAULTS.duplicate(true)  # 正式版 applyData({}) 的实际默认值（含后续插件覆盖）
	_map_xy_configured = false
	if p != "" and FileAccess.file_exists(p):
		var data = JSON.parse_string(FileAccess.get_file_as_string(p))
		if data is Dictionary:
			for key in DEFAULTS:
				if key in VOLUMES:
					_values[key] = clampi(int(data.get(key, DEFAULTS[key])), 0, 100)
				elif key == "battleAniSpeed":
					_values[key] = clampi(int(data.get(key, DEFAULTS[key])), 1, 4)
				elif key == "codexNotices":
					# 原版 applyData：只有存成 false 的类别才关闭
					var saved = data.get(key)
					for k in _values[key]:
						_values[key][k] = not (saved is Dictionary and saved.get(k) is bool and saved[k] == false)
				elif key == "codexSkillLevelNotice":
					_values[key] = not (data.get(key) is bool and data[key] == false)
				else:
					_values[key] = bool(data.get(key, DEFAULTS[key]))
			_map_xy_configured = data.has("MapXy")
	XAudio.apply_volumes(_values)


static func flag(key: String) -> bool:
	ensure_loaded()
	return bool(_values.get(key, false))


static func set_flag(key: String, value: bool) -> bool:
	if key not in DEFAULTS or key in VOLUMES or key in ["battleAniSpeed", "codexNotices"]:
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


## 消息提醒某一类是否显示（skillLevel 为技能升级通告）
static func notice_on(key: String) -> bool:
	ensure_loaded()
	if key == "skillLevel":
		return bool(_values.codexSkillLevelNotice)
	return bool(_values.codexNotices.get(key, true))


static func set_notice(key: String, on: bool) -> bool:
	ensure_loaded()
	if key == "skillLevel":
		_values.codexSkillLevelNotice = on
	elif _values.codexNotices.has(key):
		_values.codexNotices[key] = on
	else:
		return false
	return _write()


## 设置页「消息提醒」的状态文字
static func notices_text() -> String:
	var off := NOTICES.filter(func(n): return not notice_on(n[0])).size()
	return "%d项关闭" % off if off > 0 else "全部显示"


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
