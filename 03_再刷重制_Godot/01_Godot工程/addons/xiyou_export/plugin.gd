@tool
extends EditorPlugin
## 导出插件（cc 平台 DZ 2026-11-06）：安卓导出时用 XAndroidVersion 按开发编号覆盖 version/code、version/name；
## Mac、Windows 导出时用 XDesktopVersion 覆盖版本号（cc 平台 EC 2026-11-06）。
## 编辑器（含 --headless --export-*）启用本插件才生效；关掉 XAndroidVersion.AUTO 就用预设里填的值。
## 安卓 Gradle 构建时把后台挂机插件 XiyouBgIdle 的 aar 加进包（cc 平台 android-bgidle1 2026-11-09；源码在 android_src/，
## 云端导出.py android-build 编出 BGIDLE_AAR）。aar 不在或预设没开 Gradle 构建就不加，游戏退回 O-201 的回前台补跑。

var _export: XiyouExport


func _enter_tree() -> void:
	_export = XiyouExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


const BGIDLE_AAR := "res://addons/xiyou_export/android/xiyou_bgidle.aar"


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

	func _get_android_libraries(platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		if not platform is EditorExportPlatformAndroid or not bool(get_option("gradle_build/use_gradle_build")):
			return PackedStringArray()
		if not FileAccess.file_exists(BGIDLE_AAR):
			push_warning("没找到后台挂机插件 %s（先跑 云端导出.py android-build）：这个包切后台不会起前台服务" % BGIDLE_AAR)
			return PackedStringArray()
		return PackedStringArray([BGIDLE_AAR])
