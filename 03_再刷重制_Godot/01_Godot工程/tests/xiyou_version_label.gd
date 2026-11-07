extends Node
## 右下角版本号：GameApp 下有 VersionLabel，文字是 project.godot 的版本号，在右下角、不挡鼠标、发行模式也在；回退开关 XVersionLabel.SHOW。

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _run() -> void:
	for _i in range(3):
		await get_tree().process_frame
	var v := get_node_or_null("/root/GameApp/VersionLabel") as XVersionLabel
	check("node_exists", v != null)
	if v != null:
		var ver := str(ProjectSettings.get_setting("application/config/version", ""))
		check("text_is_version", ver != "" and v.label.text == ver, [v.label.text, ver])
		var r := v.label.get_global_rect()
		var vs := get_viewport().get_visible_rect().size
		check("bottom_right", r.end.x > vs.x - 40 and r.end.x <= vs.x and r.end.y > vs.y - 40 and r.end.y <= vs.y, [r, vs])
		check("ignores_mouse", v.label.mouse_filter == Control.MOUSE_FILTER_IGNORE)
		var tc := XTouchControls.new()
		check("above_touch_layer", v.layer > tc.layer or v.layer >= 121)
		tc.free()
	ReleaseEntry.simulate_release = true
	check("shows_in_release", XVersionLabel.SHOW and get_node_or_null("/root/GameApp/VersionLabel") != null)
	ReleaseEntry.simulate_release = false
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
