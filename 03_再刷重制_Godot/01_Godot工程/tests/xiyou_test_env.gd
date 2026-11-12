## 测试公共夹具（第十五批 FG，2026-11-07）：存档与配置放测试自己的目录、每次从默认配置起跑，新源大厅漩涡过场当作看过。
##
## 用法：const TestEnv = preload("res://tests/xiyou_test_env.gd")，_run 开头 TestEnv.isolate("xiyou_<测试名>")。
## 为什么：新源（v0.62.12）大厅 Map4 的 EV76 在 CodexWhisper.seen('rift1') 为假时自动播漩涡过场，占住地图几百到几千帧，
## 开菜单、按挂机键、招募事件都被忽略。本机测试目录常留着上次的 options.json（已记 rift1）所以能过，云端每次是新目录就挂
## （11-07 actor_p0、item_bag、hangup 都这样撞过）。测过场本身的测试（opening_branches、guide 等）传 rift_seen = false。
extends RefCounted


## 设 XSave.dir_override 与 XConfig.path_override 到 user://test_<name>，删掉上次留下的 options.json 并按默认值重读；
## rift_seen 为真时把 rift1、rift2（漩涡二阶段，XRift）记成看过（立即写盘）。返回测试目录。
static func isolate(name: String, rift_seen := true) -> String:
	XSave.dir_override = "user://test_" + name
	XConfig.path_override = XSave.dir().path_join("options.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(XConfig.path_override))
	XConfig._loaded_path = "<unloaded>"
	if rift_seen:
		XConfig.whisper_mark("rift1")
		XConfig.whisper_mark("rift2")   # 漩涡二阶段过场（XRift，Map4 EV203：rift1 看过就播）同样占住大厅，一并记成看过
	return XSave.dir()
