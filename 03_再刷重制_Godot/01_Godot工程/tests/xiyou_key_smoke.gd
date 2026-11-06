extends Node
## 发行包按键冒烟钩子 XKeySmoke（platform-crash1）：解析 --smoke-keys、认步、造按键事件；
## 没带参数时 GameApp 不挂它。真在发行包里按键由 07_开发环境/发行入口冒烟.py --keys 做（调试版测不到发行版的空指针闪退）。

var results: Array = []


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "ok": ok, "detail": detail})
	print(("PASS " if ok else "FAIL ") + name + ("" if detail == null else " " + str(detail)))


func _ready() -> void:
	var seq := XKeySmoke.sequence(PackedStringArray(["--report-entry", "--smoke-keys=space,wait:10,cancel"]))
	_check("parse_sequence", seq == PackedStringArray(["space", "wait:10", "cancel"]), seq)
	_check("no_arg_empty", XKeySmoke.sequence(PackedStringArray(["--report-entry"])).is_empty())
	_check("valid_steps", XKeySmoke.valid_step("j") and XKeySmoke.valid_step("accept") and XKeySmoke.valid_step("wait:0"))
	_check("bad_steps", not XKeySmoke.valid_step("jump") and not XKeySmoke.valid_step("wait:x") and not XKeySmoke.valid_step("wait:-1"))
	var e := XKeySmoke.key_event("j", true)
	_check("j_is_accept", e.pressed and e.physical_keycode == KEY_J and e.is_action_pressed("ui_accept"))
	var c := XKeySmoke.key_event("k", true)
	_check("k_is_cancel", c.is_action_pressed("ui_cancel"))
	_check("not_mounted_without_arg", GameApp.get_node_or_null("KeySmoke") == null)
	var passed := results.filter(func(r): return r.ok).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
