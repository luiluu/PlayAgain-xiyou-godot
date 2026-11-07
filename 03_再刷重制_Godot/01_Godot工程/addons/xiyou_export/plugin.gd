@tool
extends EditorPlugin
## 导出插件（cc 平台 DZ 2026-11-06）：安卓导出时用 XAndroidVersion 按开发编号覆盖 version/code、version/name；
## Mac、Windows 导出时用 XDesktopVersion 覆盖版本号（cc 平台 EC 2026-11-06）。
## 编辑器（含 --headless --export-*）启用本插件才生效；关掉 XAndroidVersion.AUTO 就用预设里填的值。

var _export: XiyouExport


func _enter_tree() -> void:
	_export = XiyouExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class XiyouExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "xiyou_export"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid or platform is EditorExportPlatformWindows or platform is EditorExportPlatformMacOS

	func _get_export_options_overrides(platform: EditorExportPlatform) -> Dictionary:
		if platform is EditorExportPlatformAndroid:
			return XAndroidVersion.overrides()
		if platform is EditorExportPlatformWindows:
			return XDesktopVersion.overrides("windows")
		if platform is EditorExportPlatformMacOS:
			return XDesktopVersion.overrides("macos")
		return {}
