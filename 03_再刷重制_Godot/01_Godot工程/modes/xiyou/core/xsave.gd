class_name XSave
extends RefCounted
## 西游模式存档：<GameApp.save_directory()>/save_<N>.json，即 user://modes/xiyou（按 modes.json 的 saveNamespace 隔离）。
## 只存 Godot 版自己的状态，不读 MV 存档。

## 正式版开局选固定存档位 1～10（开关 161～165、276～280），之后「存档」都存在那一格
const SLOTS := 30
const BACKUP_FIRST := 11
## 自动测试改到临时目录，避免覆盖开发时手动存的档。
static var dir_override := ""
## 最近一次成功存档/读档的格（installV010UsabilityRuntime：一键存档存到这一格）；新游戏到第一次存档前为 0，一键存档改为选格
static var current_slot := 0


static func dir() -> String:
	if dir_override != "":
		return dir_override
	# 未经入口进入（测试直接建档）时没有当前模式，退回西游命名空间
	var mode_dir: String = GameApp.save_directory()
	return mode_dir if mode_dir != "" else "user://modes/xiyou"

static func path(slot: int) -> String:
	return dir().path_join("save_%d.json" % slot)


static func save(slot: int) -> bool:
	if slot < 1 or slot > SLOTS or XState.current == null:
		return false
	if DirAccess.make_dir_recursive_absolute(dir()) != OK:
		return false
	var data := XState.current.to_dict()
	data["savedAt"] = Time.get_datetime_string_from_system()
	# 先写同目录临时文件，成功后替换；失败不截断原有存档。
	var temp := path(slot) + ".tmp"
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	if not ok:
		DirAccess.remove_absolute(temp)
		return false
	if DirAccess.rename_absolute(temp, path(slot)) != OK:
		DirAccess.remove_absolute(temp)
		return false
	current_slot = slot
	return true


## SaveHistory_FullData：找 11～30 中第一个空格，永不覆盖已有备份；0 为已满，-1 为写入失败。
static func backup() -> int:
	for slot in range(BACKUP_FIRST, SLOTS + 1):
		if not exists(slot):
			return slot if save(slot) else -1
	return 0


static func exists(slot: int) -> bool:
	return slot >= 1 and slot <= SLOTS and FileAccess.file_exists(path(slot))


## 在创建角色／替换当前状态前检查完整结构；损坏或未来版本的档不进入反序列化。
static func valid_data(d) -> bool:
	if not d is Dictionary or str(d.get("mode", "")) != "xiyou":
		return false
	if not (d.get("version") is int or d.get("version") is float) or int(d.version) not in [1, XState.SAVE_VERSION]:
		return false
	for key in ["difficulty", "gold", "mapId", "x", "y", "direction", "steps", "playSeconds"]:
		if not (d.get(key) is int or d.get(key) is float):
			return false
	for key in ["actors", "items", "switches", "variables", "selfSwitches"]:
		if not d.get(key) is Dictionary:
			return false
	for key in ["party", "gear"]:
		if not d.get(key) is Array:
			return false
	for key in ["rom", "seen", "flags", "actorOps", "unlockedMaps", "hangUp"]:
		if d.has(key) and typeof(d[key]) != (TYPE_ARRAY if key in ["seen", "actorOps", "unlockedMaps"] else TYPE_DICTIONARY):
			return false
	for key in d.actors:
		var row = d.actors[key]
		if XDB.rec("Actors", int(key)).is_empty() or not row is Dictionary:
			return false
		for field in ["level", "exp", "hp", "mp"]:
			if not (row.get(field) is int or row.get(field) is float):
				return false
		for field in ["skills", "equips", "states"]:
			if not row.get(field) is Array:
				return false
		if row.equips.size() != XDB.system().equipTypes.size() - 1:
			return false
		if row.has("cooldowns") and not row.cooldowns is Dictionary:
			return false
		if row.has("stateTurns") and not row.stateTurns is Dictionary:
			return false
		for field in ["buffs", "buffTurns"]:
			if row.has(field) and (not row[field] is Array or row[field].size() != 8):
				return false
		if row.has("tp") and not (row.tp is int or row.tp is float):
			return false
		if not row.equips.all(func(e): return e == null or _valid_gear(e)):
			return false
	if not d.gear.all(_valid_gear):
		return false
	for id in d.party:
		if not (id is int or id is float) or not d.actors.has(str(int(id))):
			return false
	return true


static func _valid_gear(e) -> bool:
	return e is Dictionary and str(e.get("kind", "")) in ["weapon", "armor"] and e.get("base") != null \
		and e.get("params") is Array and e.params.size() == 8 and e.get("traits") is Array \
		and e.get("meta") is Dictionary and e.get("etypeId") != null


static func summary(slot: int) -> String:
	if not exists(slot):
		return "存档 %d：空" % slot
	var d = JSON.parse_string(FileAccess.get_file_as_string(path(slot)))
	if not valid_data(d):
		return "存档 %d：无法读取" % slot
	var leader := str(XDB.rec("Actors", int(d.party[0])).get("name", "")) if not d.party.is_empty() else ""
	var lv := int(d.actors.get(str(int(d.party[0])), {}).get("level", 1)) if not d.party.is_empty() else 1
	var map_name := str(XDB.map(int(d.mapId)).get("displayName", ""))
	return "存档 %d：%s Lv%d  %s  %s" % [slot, leader, lv, map_name, str(d.get("savedAt", "")).replace("T", " ")]


static func load_slot(slot: int) -> bool:
	if not exists(slot):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(path(slot)))
	if not valid_data(d):
		return false
	XState.from_dict(d)
	# dev.015 及以前忽略 ConfigManager 脚本，没有配置文件。已完成大厅 EV20 的 Godot 档补其 MapXy=true；
	# 已有配置（包括显式 false）始终优先，不从存档回滚局外选项，不读取 MV 存档。
	if not XConfig.has_map_xy() and XState.current.self_switch(4, 20, "A"):
		XConfig.set_map_xy(true)
	current_slot = slot
	return true
