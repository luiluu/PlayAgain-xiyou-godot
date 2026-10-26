extends Node
## XDB 的 JSON 解析缓存（木吒 2026-10-25）：命中与未命中都要和直接 JSON.parse_string 得到同一份 Variant
## （var_to_bytes 逐字节相同），缓存坏了、源内容变了、开关关了都退回直接解析。真实数据比对 db 全部表、
## manifest／slice、几张地图与几份中等大小的参照；150 MB 的 slice_d* 另由一次性脚本比对（见交付单）。
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(600))


func _direct(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and var_to_bytes(a) == var_to_bytes(b)


func _bins(dir: String) -> Array:
	return Array(DirAccess.get_files_at(dir)).filter(func(n): return n.ends_with(".bin"))


func _run() -> void:
	var dir := ProjectSettings.globalize_path("user://json_cache_test")
	XDB.cache_dir_override = dir
	XDB.json_cache = true
	# ① 刁钻的 JSON：整数与小数（JSON 数字一律 float）、大数、负零、科学计数、转义与多字节字符、空容器、null、键序
	var tricky := '{"z": 1, "a": [0.1, -0.0, 1e300, 9007199254740993, 3, -7.25e-12], "s": "引号\\"\\n\\u00e9😀", "e": {}, "l": [], "n": null, "b": [true, false], "nested": [[{"k": [1, {"x": "y"}]}]]}'
	var src := "user://tricky.json"
	var f := FileAccess.open(src, FileAccess.WRITE)
	f.store_string(tricky)
	f.close()
	var direct = _direct(src)
	var miss = XDB.parse_file(src)
	_check("tricky.miss_same", _same(direct, miss), [direct, miss])
	_check("tricky.cache_written", _bins(dir).size() == 1, _bins(dir))
	var hit = XDB.parse_file(src)
	_check("tricky.hit_same", _same(direct, hit), [direct, hit])
	_check("tricky.hit_is_fresh_copy", is_same(hit, miss) == false)
	# ② 缓存文件坏了（截断、乱写）：退回直接解析，并重写成好的
	var bin: String = dir.path_join(_bins(dir)[0])
	var g := FileAccess.open(bin, FileAccess.WRITE)
	g.store_string("XJC1garbage")
	g.close()
	_check("corrupt.falls_back", _same(direct, XDB.parse_file(src)))
	_check("corrupt.rewritten", XDB._cache_read(bin)[0] and _same(direct, XDB._cache_read(bin)[1]))
	# ③ 源内容变了：换键，不用旧缓存；旧版本缓存删掉
	f = FileAccess.open(src, FileAccess.WRITE)
	f.store_string('{"z": 2}')
	f.close()
	_check("changed.uses_new_content", _same(_direct(src), XDB.parse_file(src)))
	_check("changed.old_pruned", _bins(dir).size() == 1 and not FileAccess.file_exists(bin), _bins(dir))
	# 坏 JSON、读不到的文件会打 ERROR（并行测试按 ERROR 判失败），这里不测；代码上二者都在 _parse 里与原来一样返回 null、不写缓存
	# ⑤ 开关关掉：不读也不写缓存
	XDB.json_cache = false
	f = FileAccess.open("user://off.json", FileAccess.WRITE)
	f.store_string('[1, 2]')
	f.close()
	_check("off.same", _same(_direct("user://off.json"), XDB.parse_file("user://off.json")))
	_check("off.no_write", _bins(dir).size() == 1, _bins(dir))
	XDB.json_cache = true
	# ⑥ 真实数据：每份先未命中（写缓存）再命中，两次都与直接解析逐字节相同
	var paths: Array = []
	for name in DirAccess.get_files_at(XDB.BASE + "db"):
		if name.ends_with(".json"):
			paths.append(XDB.BASE + "db/" + name)
	paths.append_array([XDB.BASE + "manifest.json", XDB.BASE + "slice.json", XDB.BASE + "maps/Map004.json", XDB.BASE + "maps/Map186.json",
		XDB.BASE + "oracle/smart_ai.json", XDB.BASE + "oracle/formula_programs.json", XDB.BASE + "oracle/events.json"])
	_check("real.count", paths.size() > 25, paths.size())
	for p in paths:
		var want = _direct(p)
		var tag: String = "real." + p.trim_prefix(XDB.BASE)
		_check(tag + ".present", want != null)
		_check(tag + ".miss", _same(want, XDB.parse_file(p)))
		_check(tag + ".hit", _same(want, XDB.parse_file(p)))
	_check("real.cached_all", _bins(dir).size() == paths.size() + 1, [_bins(dir).size(), paths.size()])
	# ⑦ load_json 走同一条路，读失败照旧 null
	_check("load_json.same", _same(_direct(XDB.BASE + "db/System.json"), XDB.load_json("db/System.json")))
	XDB.cache_dir_override = ""
	_finish()


func _finish() -> void:
	var passed := results.filter(func(r): return r["passed"]).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
