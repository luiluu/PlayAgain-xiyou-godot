extends Node
## 工具（不是专项）：把 XTextFix 修正后的数据库表与地图写到 XIYOU_TEXT_FIX_DUMP 目录（db/、maps/ 与 generated 同结构），
## 给 07_开发环境/文字审/scan_beta_text.py --gen-dir 重扫用；另写 warnings.json（覆盖表没套上的条目）。
## 用法：XIYOU_TEXT_FIX_DUMP=<目录> godot --headless --path 01_Godot工程 res://tests/text_fix_dump.tscn
## 只写环境变量给的目录，不写 generated。


func _ready() -> void:
	_run.call_deferred()


func _write(path: String, value) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(value))
	f.close()


func _run() -> void:
	var out := OS.get_environment("XIYOU_TEXT_FIX_DUMP")
	if out == "" or out.begins_with("res://"):
		print("需要 XIYOU_TEXT_FIX_DUMP=<目录>")
		get_tree().quit.call_deferred(2)
		return
	XTextFix.set_all(true)
	XTextFix.warnings.clear()
	for name in DirAccess.get_files_at(XDB.BASE + "db"):
		if name.ends_with(".json"):
			var t := name.get_basename()
			# 只导出 XTextFix 处理的表；其余原样拷（扫描脚本要读全套）
			_write(out.path_join("db").path_join(name), XDB.table(t) if XTextFix.TABLES.has(t) else XDB.load_json("db/" + name))
	for name in DirAccess.get_files_at(XDB.BASE + "maps"):
		if name.begins_with("Map") and name.ends_with(".json") and name.substr(3, 3).is_valid_int():
			_write(out.path_join("maps").path_join(name), XDB.map(int(name.substr(3, 3))))
		elif name.ends_with(".json"):
			_write(out.path_join("maps").path_join(name), XDB.load_json("maps/" + name))
	_write(out.path_join("warnings.json"), XTextFix.warnings)
	print("TEXT_FIX_DUMP=" + JSON.stringify({"dir": out, "warnings": XTextFix.warnings.size()}))
	get_tree().quit.call_deferred(0)
