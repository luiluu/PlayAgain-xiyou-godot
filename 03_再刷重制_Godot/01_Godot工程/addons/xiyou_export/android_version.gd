@tool
class_name XAndroidVersion
extends RefCounted
## 安卓版本号按开发编号生成（cc 平台 DZ 2026-11-06，O-待定·安卓版本号）：预设里一直是 versionCode 1、versionName 0.0.0，
## 每个包都一样，手机上分不出新旧，也装不上更新（系统要 versionCode 变大才肯覆盖安装）。这里导出时改成
## versionCode＝开发编号的数字（dev.383 → 383）、versionName＝「0.<数字>」（0.383）。正式上架的版本号要 Kyo 定。
## 回退：AUTO = false，用 export_presets.cfg 里填的 version/code、version/name。

static var AUTO := true
const BUILD_INFO := "res://content/build_info.json"


## {"version/code": int, "version/name": String}；AUTO 关着或读不出开发编号时是 {}（用预设的值）。
static func overrides(info = null) -> Dictionary:
	if not AUTO:
		return {}
	if info == null:
		info = JSON.parse_string(FileAccess.get_file_as_string(BUILD_INFO)) if FileAccess.file_exists(BUILD_INFO) else null
	var n := dev_number(info)
	if n <= 0:
		return {}
	return {"version/code": n, "version/name": "0.%d" % n}


## build_info 的 developmentVersion「dev.383」→ 383；不是这个样子返回 0。
static func dev_number(info) -> int:
	if not info is Dictionary:
		return 0
	var v := str(info.get("developmentVersion", ""))
	if not v.begins_with("dev."):
		return 0
	var digits := v.substr(4)
	return int(digits) if digits.is_valid_int() and int(digits) > 0 else 0
