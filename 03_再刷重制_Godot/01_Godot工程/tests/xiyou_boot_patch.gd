extends Node
## 自动更新第 0 批：补丁叠加载入（core/boot_patch.gd）。
## 用 PCKPacker 现做一个小补丁包（工程里没有的路径），验登记、校验、载入的各分支；只写 user://_test_boot_patch/，跑完删掉。
## 发行模板里「补丁替换已有脚本、数据、图」由 07_开发环境/补丁叠加验证.py 在包内确认，这里只验载入器自己的判断。

const BootPatchScript := preload("res://core/boot_patch.gd")
const DIR := "user://_test_boot_patch"
const PROBE_JSON := "res://_boot_patch_probe/data.json"
const PROBE_GD := "res://_boot_patch_probe/lib.gd"
var results: Array = []

func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)

func _check(name: String, ok: bool) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL " + name)

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _state(d: Dictionary) -> String:
	var p := DIR.path_join("active.json")
	_write(p, JSON.stringify(d))
	return p

func _cleanup() -> void:
	var da := DirAccess.open(DIR)
	if da:
		for n in da.get_files():
			da.remove(n)
		DirAccess.remove_absolute(DIR)

func _run() -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(DIR)
	# 做补丁包
	_write(DIR.path_join("src.json"), '{"v":"patched"}')
	_write(DIR.path_join("src.gd"), "extends RefCounted\nstatic func version() -> String:\n\treturn \"patched\"\n")
	var pk := PCKPacker.new()
	pk.pck_start(DIR.path_join("p.pck"))
	pk.add_file(PROBE_JSON, DIR.path_join("src.json"))
	pk.add_file(PROBE_GD, DIR.path_join("src.gd"))
	_check("补丁包做出来了", pk.flush() == OK)
	var pck := DIR.path_join("p.pck")
	var sha := FileAccess.get_sha256(pck)
	var size := FileAccess.open(pck, FileAccess.READ).get_length()
	var base: int = BootPatchScript.base_code()
	_check("底包编号读得到", base > 0)
	var good := {"file": "p.pck", "sha256": sha, "size": size, "base": base, "code": base + 1}

	# 自动加载顺序：BootPatch 在 GameApp 前面
	var proj := FileAccess.get_file_as_string("res://project.godot")
	var i := proj.find("BootPatch=")
	_check("BootPatch 是第一个自动加载", i > 0 and i < proj.find("GameApp=") and proj.find("[autoload]") < i)
	_check("启动时没有补丁、照常启动", BootPatchScript.result["loaded"] == false)

	# 不载入的各分支
	var r: Dictionary = BootPatchScript.apply(DIR.path_join("none.json"))
	_check("没有登记", not r["loaded"] and r["reason"] == "没有登记")
	_write(DIR.path_join("active.json"), "{坏的")
	r = BootPatchScript.apply(DIR.path_join("active.json"))
	_check("登记不是 JSON", not r["loaded"] and r["reason"] == "登记坏了")
	for bad_name in ["../p.pck", "a/p.pck", "", "..\\p.pck"]:
		var d := good.duplicate()
		d["file"] = bad_name
		r = BootPatchScript.apply(_state(d))
		_check("文件名带路径或为空：" + bad_name, not r["loaded"] and r["reason"] == "登记坏了")
	var d2 := good.duplicate()
	d2["base"] = base - 1
	r = BootPatchScript.apply(_state(d2))
	_check("底包不符", not r["loaded"] and r["reason"] == "底包不符")
	d2 = good.duplicate()
	d2["file"] = "q.pck"
	r = BootPatchScript.apply(_state(d2))
	_check("文件不在", not r["loaded"] and r["reason"] == "文件不在")
	d2 = good.duplicate()
	d2["size"] = size + 1
	r = BootPatchScript.apply(_state(d2))
	_check("字节数不符", not r["loaded"] and r["reason"] == "字节数不符")
	d2 = good.duplicate()
	d2["sha256"] = "0".repeat(64)
	r = BootPatchScript.apply(_state(d2))
	_check("校验不符", not r["loaded"] and r["reason"] == "校验不符")
	# 截断的包：字节数、SHA 照截断后的填也对不上原登记
	var bytes := FileAccess.get_file_as_bytes(pck)
	var cut := FileAccess.open(DIR.path_join("cut.pck"), FileAccess.WRITE)
	cut.store_buffer(bytes.slice(0, bytes.size() / 2))
	cut.close()
	d2 = good.duplicate()
	d2["file"] = "cut.pck"
	d2.erase("size")
	r = BootPatchScript.apply(_state(d2))
	_check("截断的包（不给字节数也靠 SHA 拦住）", not r["loaded"] and r["reason"] == "校验不符")
	BootPatchScript.enabled = false
	r = BootPatchScript.apply(_state(good))
	_check("开关关着不载入", not r["loaded"] and r["reason"] == "开关关着")
	BootPatchScript.enabled = true
	_check("以上都没把补丁载进来", not FileAccess.file_exists(PROBE_JSON))

	# 载入
	r = BootPatchScript.apply(_state(good))
	_check("校验通过就载入", r["loaded"] and r["reason"] == "已载入" and r["code"] == base + 1 and r["base"] == base)
	var j = JSON.parse_string(FileAccess.get_file_as_string(PROBE_JSON))
	_check("补丁里的数据读得到", typeof(j) == TYPE_DICTIONARY and j.get("v") == "patched")
	var lib = load(PROBE_GD)
	_check("补丁里的脚本能载入并运行", lib != null and lib.version() == "patched")

	_cleanup()
	var passed := results.filter(func(x): return x["passed"]).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
