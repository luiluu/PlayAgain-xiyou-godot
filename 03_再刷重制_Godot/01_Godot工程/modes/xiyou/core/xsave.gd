class_name XSave
extends RefCounted
## 西游模式存档：<GameApp.save_directory()>/save_<N>.json，即 user://modes/xiyou（按 modes.json 的 saveNamespace 隔离）。
## 只存 Godot 版自己的状态，不读 MV 存档。

## 正式版开局选固定存档位 1～10（开关 161～165、276～280），之后「存档」都存在那一格
const SLOTS := 10
## 自动测试改到临时目录，避免覆盖开发时手动存的档。
static var dir_override := ""


static func dir() -> String:
	if dir_override != "":
		return dir_override
	# 未经入口进入（测试直接建档）时没有当前模式，退回西游命名空间
	var mode_dir: String = GameApp.save_directory()
	return mode_dir if mode_dir != "" else "user://modes/xiyou"

static func path(slot: int) -> String:
	return dir().path_join("save_%d.json" % slot)


static func save(slot: int) -> bool:
	DirAccess.make_dir_recursive_absolute(dir())
	var data := XState.current.to_dict()
	data["savedAt"] = Time.get_datetime_string_from_system()
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true


static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))


static func summary(slot: int) -> String:
	if not exists(slot):
		return "存档 %d：空" % slot
	var d = JSON.parse_string(FileAccess.get_file_as_string(path(slot)))
	if not d is Dictionary:
		return "存档 %d：无法读取" % slot
	var leader := str(XDB.rec("Actors", int(d.party[0])).get("name", "")) if not d.party.is_empty() else ""
	var lv := int(d.actors.get(str(int(d.party[0])), {}).get("level", 1)) if not d.party.is_empty() else 1
	var map_name := str(XDB.map(int(d.mapId)).get("displayName", ""))
	return "存档 %d：%s Lv%d  %s  %s" % [slot, leader, lv, map_name, str(d.get("savedAt", "")).replace("T", " ")]


static func load_slot(slot: int) -> bool:
	if not exists(slot):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(path(slot)))
	if not d is Dictionary or str(d.get("mode", "")) != "xiyou":
		return false
	XState.from_dict(d)
	return true
