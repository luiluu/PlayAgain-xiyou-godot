class_name XSave
extends RefCounted
## 西游模式存档：user://modes/xiyou/save_<N>.json（GameApp 按模式隔离目录）。只存 Godot 版自己的状态，不读 MV 存档。

const SLOTS := 3
## 自动测试改到临时目录，避免覆盖开发时手动存的档。
static var dir_override := ""


static func dir() -> String:
	return dir_override if dir_override != "" else "user://modes/xiyou"

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
