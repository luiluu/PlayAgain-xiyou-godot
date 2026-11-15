class_name XWhatsNew
extends RefCounted
## 【cc·update-whatsnew·未经审查】更新装好、重启进游戏后弹一次「本次更新内容」（Kyo 2026-11-15）。
## 只管记录，界面在 XWhatsNewPage（标题画面弹、设置页「本次更新内容」再看）。
##
## 记录：user://updates/whatsnew.json  {"code": 481, "version": "0.01.11", "date": "2026-11-15", "notes": ["……"], "seen": false}
## 两处写：
##   - 装补丁（XUpdatePage._install 登记成功后，note_install）：清单 latest 的说明。补丁号和清单最新号不一样时不记
##     （说明讲的是最新那一版，不是装的这一版）；
##   - 查清单（XUpdateClient.check 之后，note_check，FROM_CHECK）：查到「已是最新」且最新号＝现在运行的号、而记录里还不是这个号时，
##     记下这一版的说明。覆盖整包首次启动、旧客户端装的补丁（装的时候还没有这段代码）。同一个号已经有记录就不动（不会把已读改回未读）。
## 一律不改补丁格式和清单格式：只读清单里本来就有的 latest.version／code／date／notes。
## 什么时候弹（pending）：开关开着、记录完整、记录的号＝现在运行的号（XUpdateClient.current_code）、没看过、说明不空。
## 退回补丁、换了别的号：号对不上，不弹；记录留着无害，下次记新号时覆盖。
## 回退开关 ENABLED（O-待定）＝false：不记、不弹、设置页不列入口，回到只有「有新版本」框里能看说明的样子。

## O-待定 开关：false 回退为不记录、不弹「本次更新内容」
static var ENABLED := true
## 查清单时补记（整包首次启动、旧客户端装的补丁）。false 只认游戏内装补丁时记下的。
static var FROM_CHECK := true
const FILE := "user://updates/whatsnew.json"
## 测试换路径
static var path := FILE
## 一份说明最多存多少行（清单是 Kyo 写的，防坏数据撑爆页面）
const MAX_NOTES := 40


static func _read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or typeof(j.data) != TYPE_DICTIONARY:
		return {}
	return validate(j.data)


## 记录逐项查字段和类型（co 甲档核查 P2）：code 正整数（JSON 读出来是浮点，要是整数值）、version／date 字符串、
## notes 数组、seen 布尔；缺一项或类型不对一律当坏数据（返回空字典：不弹、不报错，查清单时同号也会重记）。
## 通过的返回整理过的副本（code 为 int）。
static func validate(d: Variant) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	for k in ["code", "version", "date", "notes", "seen"]:
		if not d.has(k):
			return {}
	var c = d["code"]
	if not ((c is int and c > 0) or (c is float and c > 0.0 and c == floorf(c) and c < 2147483647.0)):
		return {}
	if not (d["version"] is String) or not (d["date"] is String) or not (d["notes"] is Array) or not (d["seen"] is bool):
		return {}
	return {"code": int(c), "version": d["version"], "date": d["date"], "notes": d["notes"], "seen": d["seen"]}


static func _write(d: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	return true


## 把说明整理成字符串数组（只收非空字符串）
static func clean_notes(notes: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if notes is Array or notes is PackedStringArray:
		for n in notes:
			if n is String and n.strip_edges() != "" and out.size() < MAX_NOTES:
				out.append(n.strip_edges())
	return out


## 记下一版的说明（未读）。说明为空不记；返回记没记。
static func remember(code: int, version: String, date: String, notes: Variant) -> bool:
	if not ENABLED or code <= 0:
		return false
	var n := clean_notes(notes)
	if n.is_empty():
		return false
	return _write({"code": code, "version": version, "date": date, "notes": Array(n), "seen": false})


## 游戏内装补丁登记成功后调。result 是 state＝patch 的检查结果（XUpdateCheck.evaluate），patch 是装的那份。
static func note_install(result: Dictionary, patch: Dictionary) -> bool:
	var code := int(patch.get("code", 0))
	if code <= 0 or code != int(result.get("code", 0)):
		return false  # 装的不是清单最新那一版：说明对不上，不记
	return remember(code, str(result.get("version", "")), str(result.get("date", "")), result.get("notes", []))


## 查完清单调（XUpdateClient.check）。最新号＝现在运行的号、记录里还不是这个号时补记。
static func note_check(result: Dictionary, running_code: int) -> bool:
	if not ENABLED or not FROM_CHECK or running_code <= 0:
		return false
	if str(result.get("state", "")) != XUpdateCheck.LATEST or int(result.get("code", 0)) != running_code:
		return false
	if int(_read().get("code", 0)) == running_code:
		return false  # 这一版已经记过（看没看过都不动）；坏记录 _read 返回空，照样重记
	return remember(running_code, str(result.get("version", "")), str(result.get("date", "")), result.get("notes", []))


## 现在运行的这一版的记录（看没看过都给，设置页再看用）；没有、号不对、说明空返回空字典。
static func current(running_code: int) -> Dictionary:
	if not ENABLED or running_code <= 0:
		return {}
	var d := _read()
	if d.is_empty() or d["code"] != running_code:
		return {}
	var n := clean_notes(d.get("notes"))
	if n.is_empty():
		return {}
	return {"code": running_code, "version": str(d.get("version", "")), "date": str(d.get("date", "")),
		"notes": n, "seen": d["seen"]}


## 要弹的那份（没看过的）；没有返回空字典。
static func pending(running_code: int) -> Dictionary:
	var d := current(running_code)
	return {} if d.is_empty() or d["seen"] else d


## 记已读（弹出来就算看过：玩家关掉、或弹的时候退出游戏都不再弹）。
static func mark_seen(running_code: int) -> void:
	var d := _read()
	if d.is_empty() or d["code"] != running_code or d["seen"]:
		return
	d["seen"] = true
	_write(d)
