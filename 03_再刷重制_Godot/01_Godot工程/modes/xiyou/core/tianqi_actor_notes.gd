class_name XTianqiActorNotes
extends RefCounted
## 【小A·T556·未经审查】天启篇人物图鉴全员备注只读读取（Kyo 11-27 事项 84 定稿：两行无前缀，故事＋特点，不含内部数值与编号）。
## 数据源 modes/xiyou/tianqi_data/actor_notes.json（全员 163 位天启篇图鉴可见角色）。
## 只认天启篇存档（XTianqi.active）且开关开着；西游档或 ENABLED＝false 恒返回空数组，图鉴自动回退原版 <ActorNote>。

## 回退开关：false＝天启篇图鉴回退原版 Actors.json <ActorNote>
static var ENABLED := true

const PATH := "res://modes/xiyou/tianqi_data/actor_notes.json"

static var _data: Dictionary = {}
static var _failed := false


static func table() -> Dictionary:
	if _data.is_empty() and not _failed:
		if XDataFile.missing(PATH):
			_failed = true
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("XTianqiActorNotes: 读不到或解析失败 " + PATH)
			_failed = true
	return _data


static func reload_table() -> void:
	_data = {}
	_failed = false


## 只认天启篇存档且开关开着
static func active() -> bool:
	if not ENABLED or XState.current == null or not XTianqi.active(XState.current):
		return false
	return not table().is_empty()


## 返回该角色的备注行（[故事, 特点]）；西游档、开关关或未录时返回 []（首句供发行空壳规则 2 照搬）
static func lines_of(id: int) -> Array:
	if not active():
		return []
	var actors = table().get("actors", {})
	if not actors is Dictionary:
		return []
	var row = actors.get(str(id))
	if not row is Dictionary:
		return []
	var out := []
	var story := str(row.get("story", "")).strip_edges()
	var trait_text := str(row.get("trait", "")).strip_edges()
	if story != "":
		out.append(story)
	if trait_text != "":
		out.append(trait_text)
	return out
