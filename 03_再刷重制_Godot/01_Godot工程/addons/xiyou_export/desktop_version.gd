@tool
class_name XDesktopVersion
extends RefCounted
## Mac 和 Windows 发行包的版本号按开发编号生成（cc 平台 EC 2026-11-06，O-217·桌面版本号；做法照安卓的 XAndroidVersion）：
## 预设里 Windows 一直是 0.0.0.0、Mac 没填（Info.plist 是 Godot 默认的 1.0），exe「属性→详细信息」和 Mac「显示简介」
## 看不出是哪一版。导出时改成跟安卓一样的「0.<开发编号>」：
##   Windows：file_version、product_version＝「0.<号>.0.0」（Windows 要四段数字）
##   Mac：short_version（CFBundleShortVersionString）＝「0.<号>」，version（CFBundleVersion）＝「<号>」
## 正式发布的版本号要 Kyo 定（Kyo 11-06：「正式版本号等正式发布我们再定」）。
## 回退：AUTO = false，用 export_presets.cfg 里填的值。

static var AUTO := true


## platform 是 "windows" 或 "macos"；AUTO 关着、平台不认识或读不出开发编号时是 {}（用预设的值）。
static func overrides(platform: String, info = null) -> Dictionary:
	if not AUTO:
		return {}
	if info == null:
		info = JSON.parse_string(FileAccess.get_file_as_string(XAndroidVersion.BUILD_INFO)) if FileAccess.file_exists(XAndroidVersion.BUILD_INFO) else null
	var n := XAndroidVersion.dev_number(info)
	if n <= 0:
		return {}
	match platform:
		"windows":
			return {"application/file_version": "0.%d.0.0" % n, "application/product_version": "0.%d.0.0" % n}
		"macos":
			return {"application/short_version": "0.%d" % n, "application/version": str(n)}
	return {}
