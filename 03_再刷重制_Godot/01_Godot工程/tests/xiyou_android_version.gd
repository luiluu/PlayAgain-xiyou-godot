extends Node
## 安卓版本号按开发编号生成（cc 平台 DZ 2026-11-06，O-216·安卓版本号，开关 XAndroidVersion.AUTO）。
## 导出插件 addons/xiyou_export 用它覆盖 version/code、version/name；真导出由 发行入口冒烟.py --platform android 查。
## 另含 Mac／Windows 的 XDesktopVersion（cc 平台 EC 2026-11-06，O-待定·桌面版本号）；真导出由 发行入口冒烟.py（mac／windows）查。
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _run() -> void:
	check("default_on", XAndroidVersion.AUTO)
	check("dev_383", XAndroidVersion.overrides({"developmentVersion": "dev.383"}) == {"version/code": 383, "version/name": "0.383"},
		XAndroidVersion.overrides({"developmentVersion": "dev.383"}))
	check("dev_number", XAndroidVersion.dev_number({"developmentVersion": "dev.1024"}) == 1024)
	for bad in [{}, [], {"developmentVersion": "v0.28"}, {"developmentVersion": "dev."}, {"developmentVersion": "dev.0"}, {"developmentVersion": "dev.12a"}]:
		check("bad_%s" % JSON.stringify(bad), XAndroidVersion.overrides(bad) == {}, XAndroidVersion.overrides(bad))
	# 不给参数时读工程自己的 build_info.json
	var info = JSON.parse_string(FileAccess.get_file_as_string(XAndroidVersion.BUILD_INFO))
	var n := int(str(info.developmentVersion).substr(4))
	check("reads_build_info", n > 0 and XAndroidVersion.overrides() == {"version/code": n, "version/name": "0.%d" % n}, XAndroidVersion.overrides())
	# 回退：关掉就用预设里的值（不覆盖）
	XAndroidVersion.AUTO = false
	check("switch_off_no_override", XAndroidVersion.overrides({"developmentVersion": "dev.383"}) == {})
	XAndroidVersion.AUTO = true
	# 桌面（平台 EC）：Windows 四段、Mac 两个键；不认识的平台、坏编号、开关关着都不覆盖
	check("desktop_default_on", XDesktopVersion.AUTO)
	var d383 := {"developmentVersion": "dev.383"}
	check("windows_383", XDesktopVersion.overrides("windows", d383) == {"application/file_version": "0.383.0.0", "application/product_version": "0.383.0.0"},
		XDesktopVersion.overrides("windows", d383))
	check("macos_383", XDesktopVersion.overrides("macos", d383) == {"application/short_version": "0.383", "application/version": "383"},
		XDesktopVersion.overrides("macos", d383))
	check("desktop_unknown_platform", XDesktopVersion.overrides("linux", d383) == {})
	check("desktop_bad", XDesktopVersion.overrides("windows", {"developmentVersion": "v0.28"}) == {})
	check("desktop_reads_build_info", XDesktopVersion.overrides("macos") == {"application/short_version": "0.%d" % n, "application/version": str(n)},
		XDesktopVersion.overrides("macos"))
	XDesktopVersion.AUTO = false
	check("desktop_switch_off_no_override", XDesktopVersion.overrides("windows", d383) == {} and XDesktopVersion.overrides("macos", d383) == {})
	XDesktopVersion.AUTO = true
	# 插件登记在工程设置里
	var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	check("plugin_enabled", enabled.has("res://addons/xiyou_export/plugin.cfg"), enabled)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
