class_name XGlobalVars
extends RefCounted
## 跨存档变量（Drill_VariablesAcrossArchive＋Drill_CoreOfGlobalSave）：插件参数列出的变量／开关（西游：变量 900／899／1000／1476、开关 2281）
## 每次经 setValue 改值（指令 121／122、脚本）就记进全局存储并写盘；新开局（Game_Map.initialize）与读档（extractSaveContents）后，
## 全局存储里有值的格盖掉本局的值。玉皇大帝「能作用于当前存档和所有新存档」、开局 Map002 调公共事件 1322／1328 靠的就是它。
## 文件：<存档目录>/global.json（正式版是游戏根目录 save/drill_global.rpgsave；Godot 版不读 MV 文件）。
## 值照原样存：变量存 setValue 收到的原值（正式版不取整，盖回去也是原值），开关存 true/false；存过 0／false 也算有值。
## 正式版内存里的存储整局不清，读档、新开局都不重读文件；这里按路径只读一次，效果相同。

## 测试改路径；空则跟 XSave.dir()（测试的 XSave.dir_override 也跟着走临时目录）
static var path_override := ""
static var _loaded_path := "<unloaded>"
static var _switches := {}      # id -> bool
static var _variables := {}     # id -> 原值
static var _id_cache := {}      # 插件参数键 -> id 列表（每次改变量都要查，只解析一次）


static func _ids(key: String) -> Array:
	if _id_cache.has(key):
		return _id_cache[key]
	var raw = XDB.plugin("Drill_VariablesAcrossArchive").get(key, "")
	var parsed = JSON.parse_string(str(raw)) if str(raw) != "" else []
	_id_cache[key] = (parsed if parsed is Array else []).map(func(v): return int(v))
	return _id_cache[key]

static func switch_ids() -> Array:
	return _ids("跨存档的开关")

static func variable_ids() -> Array:
	return _ids("跨存档的变量")


static func path() -> String:
	return path_override if path_override != "" else XSave.dir().path_join("global.json")


static func ensure_loaded() -> void:
	var p := path()
	if p == _loaded_path:
		return
	_loaded_path = p
	_switches = {}
	_variables = {}
	if not FileAccess.file_exists(p):
		return
	var json := JSON.new()  # 不用 parse_string：损坏时不往日志打错误
	var d = json.data if json.parse(FileAccess.get_file_as_string(p)) == OK else null
	if not d is Dictionary:
		return  # 损坏的文件按空处理（正式版 JSON.parse 会直接报错停机）；下次改值时整份重写
	var sw = d.get("switches", {})
	var vars = d.get("variables", {})
	for k in (sw if sw is Dictionary else {}):
		if str(k).is_valid_int() and sw[k] is bool:
			_switches[int(k)] = sw[k]
	for k in (vars if vars is Dictionary else {}):
		if str(k).is_valid_int() and (vars[k] is float or vars[k] is int):
			_variables[int(k)] = vars[k]


## 内存里的全局存储（只读副本，测试与调试用）
static func stored() -> Dictionary:
	ensure_loaded()
	return {"switches": _switches.duplicate(), "variables": _variables.duplicate()}


## Game_Switches.setValue 之后
static func on_switch(id: int, on: bool) -> void:
	if not switch_ids().has(id):
		return
	ensure_loaded()
	_switches[id] = on
	_save()


## Game_Variables.setValue 之后：存原值（取整前）
static func on_variable(id: int, value) -> void:
	if not variable_ids().has(id):
		return
	ensure_loaded()
	_variables[id] = value
	_save()


## 新开局、读档后：全局存储里有值的格盖掉本局（不经 setValue，不触发写盘）
static func apply(s: XState) -> void:
	ensure_loaded()
	for id in variable_ids():
		if _variables.has(id):
			s.variables[id] = _variables[id]
	for id in switch_ids():
		if _switches.has(id):
			s.switches[id] = _switches[id]


## 同 XSave：先写临时文件再替换；写盘失败只丢这一次（内存里仍有，本次运行照常生效），不影响游戏
static func _save() -> bool:
	var p := path()
	if DirAccess.make_dir_recursive_absolute(p.get_base_dir()) != OK:
		return false
	var sw := {}
	var vars := {}
	for k in _switches:
		sw[str(k)] = _switches[k]
	for k in _variables:
		vars[str(k)] = _variables[k]
	var temp := p + ".tmp"
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"version": 1, "mode": "xiyou", "switches": sw, "variables": vars}))
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	if not ok or DirAccess.rename_absolute(temp, p) != OK:
		DirAccess.remove_absolute(temp)
		return false
	return true
