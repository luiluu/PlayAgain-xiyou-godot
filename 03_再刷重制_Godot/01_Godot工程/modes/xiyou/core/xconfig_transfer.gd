class_name XConfigTransfer
extends RefCounted
## T154 设置「导入／导出配置」（玩家建议，Kyo 11-17）：把设置页的选项打成一段文本，发给别人或换机器时粘回来。
## - 导出：一行文本「ZSCFG1:」＋ base64(JSON)，JSON 里带游戏版本号（game、code）和配置格式版本（format）。
##   聊天软件可能插换行、空格，导入时全部去掉再解；直接粘 JSON（{ 开头）也认。
## - 只导出 SETTINGS 里的设置项；本机专属的（DEVICE：窗口、帧率、整数缩放、省电、画面平滑、手机按键位置……）
##   和进度类的（PROGRESS：成就、称号、换装解锁、过场看过、天启篇图鉴……）不导出，导入时也不认。
## - 导入：格式不对给提示；版本不同照样导入认得的项，不认识的、类型不对的跳过并计数（preview 先算好给玩家确认）。
##   导入前把当前设置导出成一份备份（BACKUP_NAME，和 options.json 同目录），undo() 一键换回；撤回只动设置项，不动进度。
## 测试用 XConfig.path_override（备份跟着放在同目录），不读写本机真实设置。

## 回退开关：false 时设置页不列「导入／导出配置」
static var ENABLED := true
const PREFIX := "ZSCFG1:"
## 配置格式版本：以后加了要换写法的项再加一；更高版本的文本照样读，认得的项照导
const FORMAT := 1
const BACKUP_NAME := "options_before_import.json"

## 可导出、可导入的设置项（XConfig.DEFAULTS 的键）。新加设置时三份清单必须选一份放（专项会查有没有漏）。
const SETTINGS := ["MapXy", "codexSmartAI", "alwaysDash", "commandRemember", "battleCamera",
	"bgmVolume", "bgsVolume", "meVolume", "seVolume", "CombatDamageShow", "CombatSkillAnimation", "battleAniSpeed",
	"MOG_TrPopUpBattle_Key", "CombatDamageRecordKey", "codexNotices", "codexSkillLevelNotice", "cq", "codexPowerEnabled",
	"codexBossStatusPanel", "codexEquipmentSort", "codexScreenFx", "codexBattleAutoDefault", "codexFontSize", "codexUiSkin",
	"codexBattleDim", "codexRingStyle", "codexUiMotion", "codexEncounterTarget", "codexPartyFormation", "codexQuality"]
## 画质里只有这两项是口味（像素柔边、地图平滑移动），其余（窗口、帧率上限、整数缩放、省电）跟着机器走
const QUALITY_SHARED := ["crisp", "motion"]
## 本机专属：不导出、不导入（画面平滑按平台给默认、看屏幕；手机按键位置存在 user://touch_controls.json，另不在这里）
const DEVICE := ["codexScreenSmooth"]
## 进度类：存在设置文件里但不是设置，导入别人的等于白拿成就／解锁
const PROGRESS := ["SAchievementS", "ChangeClothesLite", "DesignationN", "codexWeakFiveClearV2", "codexWhisperSeen",
	"codexTianqiBadges", "codexTianqiAliens", "codexTianqiQiyinParts", "codexTianqiGojo"]

## 换掉剪贴板（测试用）：读 Callable() -> String，写 Callable(text)
static var clipboard_get: Callable
static var clipboard_set: Callable


## 现在运行的版本号（玩家看到的那个）
static func game_version() -> String:
	XUpdateClient.init_versions()
	return XUpdateCheck.version_of(XUpdateClient.current_code())


## 当前设置 → 字典（只含 SETTINGS；画质只含 QUALITY_SHARED）
static func current_settings() -> Dictionary:
	XConfig.ensure_loaded()
	var out := {}
	for k in SETTINGS:
		if not XConfig.DEFAULTS.has(k):
			continue  # 补丁线等旧版本还没有这项设置
		var v = XConfig._values.get(k, XConfig.DEFAULTS[k])
		if k == "codexQuality" and v is Dictionary:
			var q := {}
			for sk in QUALITY_SHARED:
				if v.has(sk):
					q[sk] = v[sk]
			v = q
		out[k] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	return out


static func export_text(settings: Dictionary = current_settings()) -> String:
	var doc := {"format": FORMAT, "game": game_version(), "code": XUpdateClient.current_code(), "settings": settings}
	return PREFIX + Marshalls.utf8_to_base64(JSON.stringify(doc))


## 文本 → {ok, error, format, game, code, values（能导入的）, skipped（跳过的项数）, skipped_keys}
## error 是给玩家看的一句话；ok=false 时其余字段不可信。
static func preview(text: String) -> Dictionary:
	var out := {"ok": false, "error": "", "format": 0, "game": "", "code": 0, "values": {}, "skipped": 0, "skipped_keys": []}
	var t := text.strip_edges()
	if t == "":
		out["error"] = "没有读到配置文本。"
		return out
	var json_text := ""
	if t.begins_with("{"):
		json_text = t
	else:
		var i := t.find(PREFIX)
		if i < 0:
			out["error"] = "这不是本游戏导出的配置。"
			return out
		var b64 := ""
		for ch in t.substr(i + PREFIX.length()):
			if not ch in [" ", "\t", "\n", "\r"]:
				b64 += ch
		var raw := Marshalls.base64_to_raw(b64) if _looks_base64(b64) else PackedByteArray()
		json_text = raw.get_string_from_utf8()
	var j := JSON.new()
	if json_text == "" or j.parse(json_text) != OK or typeof(j.data) != TYPE_DICTIONARY:
		out["error"] = "配置文本不完整或已损坏，请重新复制。"
		return out
	var d: Dictionary = j.data
	var settings = d.get("settings")
	if typeof(settings) != TYPE_DICTIONARY or not (d.get("format") is float or d.get("format") is int):
		out["error"] = "配置文本不完整或已损坏，请重新复制。"
		return out
	out["format"] = int(d["format"])
	out["game"] = str(d.get("game", ""))
	out["code"] = int(d.get("code", 0)) if (d.get("code") is float or d.get("code") is int) else 0
	var values := {}
	var skipped: Array = []
	for k in settings:
		var v = _accept(str(k), settings[k])
		if v == null:
			skipped.append(str(k))
		else:
			values[str(k)] = v
	out["values"] = values
	out["skipped"] = skipped.size()
	out["skipped_keys"] = skipped
	if values.is_empty():
		out["error"] = "这份配置里没有本版本能用的设置。"
		return out
	out["ok"] = true
	return out


static var _b64_re := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")


static func _looks_base64(s: String) -> bool:
	return s.length() % 4 == 0 and _b64_re.search(s) != null


## 一项能不能导入：认得的键、类型跟默认值一样（数字不分整数小数）才收；嵌套的只收认得、类型对的子项。不收返回 null。
static func _accept(key: String, v: Variant) -> Variant:
	if not SETTINGS.has(key) or not XConfig.DEFAULTS.has(key):
		return null
	var def = XConfig.DEFAULTS[key]
	if def is bool:
		return v if v is bool else null
	if def is int or def is float:
		return int(v) if (v is int or v is float) else null
	if def is Dictionary:
		if not v is Dictionary:
			return null
		var sub := {}
		for sk in v:
			if not def.has(sk) or (key == "codexQuality" and not QUALITY_SHARED.has(sk)):
				continue
			var dv = def[sk]
			var x = v[sk]
			if dv is bool and x is bool:
				sub[sk] = x
			elif (dv is int or dv is float) and (x is int or x is float):
				sub[sk] = int(x)
			elif dv is String and x is String:
				sub[sk] = x
		return sub if not sub.is_empty() else null
	return null


static func backup_path() -> String:
	var p := XConfig.path()
	return "" if p == "" else p.get_base_dir().path_join(BACKUP_NAME)


## 内存里的备份（配置只在内存时用，如截图模式）
static var _mem_backup := ""


static func has_backup() -> bool:
	var b := backup_path()
	return FileAccess.file_exists(b) if b != "" else _mem_backup != ""


## 导入：先备份当前设置，再合进去。返回 preview 的结果（ok=false 时没动任何东西）。
static func apply(text: String) -> Dictionary:
	var r := preview(text)
	if not r["ok"]:
		return r
	var backup := export_text()
	var b := backup_path()
	if b != "":
		var f := FileAccess.open(b, FileAccess.WRITE)
		if f == null:
			r["ok"] = false
			r["error"] = "无法备份当前设置，没有导入。"
			return r
		f.store_string(backup)
		f.close()
	else:
		_mem_backup = backup
	if not XConfig.import_values(r["values"]):
		r["ok"] = false
		r["error"] = "写入设置失败，没有导入。"
		return r
	after_change()
	return r


## 撤回上次导入：换回导入前的设置（只动设置项）。成功后删掉备份。
static func undo() -> bool:
	var b := backup_path()
	var text := _mem_backup if b == "" else (FileAccess.get_file_as_string(b) if FileAccess.file_exists(b) else "")
	var r := preview(text)
	if not r["ok"] or not XConfig.import_values(r["values"]):
		return false
	if b != "":
		DirAccess.remove_absolute(b)
	_mem_backup = ""
	after_change()
	return true


## 界面风格现值（导入／撤回前后比，变了设置页要关回地图重建）；没有这项的版本是 null
static func skin_value() -> Variant:
	XConfig.ensure_loaded()
	return XConfig._values.get("codexUiSkin")


## 导入、撤回后让改了的设置立刻生效（音量在 XConfig 重读时已经套上）
static func after_change() -> void:
	XPower.clear_cache()
	XGraphics.apply()


static func copy_to_clipboard(text: String) -> void:
	if clipboard_set.is_valid():
		clipboard_set.call(text)
	else:
		DisplayServer.clipboard_set(text)


static func read_clipboard() -> String:
	if clipboard_get.is_valid():
		return str(clipboard_get.call())
	return DisplayServer.clipboard_get()


## 能不能存成文件（PC／Mac；安卓、iOS 只走剪贴板）
static func file_supported() -> bool:
	return not XPlatform.is_mobile()


## 导出到文件：放进系统「下载」文件夹（同反馈存档包，XFeedback.export_dir）；返回完整路径，失败返回 ""
static func export_file(text: String = export_text()) -> String:
	var out := XFeedback.export_dir().path_join("再刷一把配置_%s.txt" % Time.get_datetime_string_from_system().replace(":", "").replace("T", "_"))
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	f.close()
	return out


static func read_file(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## 一句话说明导入结果（给玩家）
static func result_text(r: Dictionary) -> String:
	if not r.get("ok", false):
		return str(r.get("error", ""))
	var s := "已导入 %d 项设置" % r["values"].size()
	if int(r["skipped"]) > 0:
		s += "，跳过 %d 项本版本不认识的设置" % int(r["skipped"])
	return s + "。"


## 确认前的提示：来自哪个版本、会导入几项、跳过几项
static func confirm_text(r: Dictionary) -> String:
	var s := "将导入 %d 项设置" % r["values"].size()
	if int(r["skipped"]) > 0:
		s += "（跳过 %d 项不认识的）" % int(r["skipped"])
	var from := str(r.get("game", ""))
	if from != "" and from != game_version():
		s += "，配置来自版本 %s，本机是 %s" % [from, game_version()]
	return s + "。再按一次确定导入，导入前会自动备份当前设置。"
