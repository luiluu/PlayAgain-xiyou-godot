class_name XSaveTransfer
extends RefCounted
## 存档导出／导入（平台三期，cc BP 2026-11-06）。安卓沙盒里玩家拿不到 user:// 的存档，原版二合一包
## （Codex_AndroidTouchSettings.js exportSave／prepareJSONImport）在标题右上放「导入存档」「导出存档」：
## 导出＝选已有存档 → 系统「另存为」写一个 JSON（format kyo-save-json-v1，data 是整份存档）；
## 导入＝先选 JSON 文件、检查格式，再选存档位写入。只在标题页能用（原版：请先保存并返回标题）。
## 这里同样包一层 {format, game, slot, exportedAt, data}，但 data 是重制版自己的存档（XSave），
## 所以 format／game 另取名字；原版 MV 的 JSON 存档认得出来，但照规矩不读（不迁移 MV 旧存档）。
## 文件选择走 DisplayServer.file_dialog_show（安卓是系统 SAF，返回的 content:// 可以直接给 FileAccess）。
## 导入到已有存档的格时，先把那格原样复制成 save_N.json.before_import_<时间>.json 再写（可找回）。
## 原版导入还会带 aux（魔冠、云裳在存档外的成长记录），这里没做：只搬存档本身（O-208）。

const FORMAT := "kyo-remake-save-json-v1"
## 封存（XSaveSeal，D28）开着时的导出格式：外层 JSON 照旧，存档本身是封存字节的 base64（sealed），改了就导不进来
const FORMAT_SEALED := "kyo-remake-save-sealed-v2"
## O-待定·存档封存：没签名的导出文件（旧版 v1 明文导出、直接一份明文存档）照收，导入时写成封存格式（Kyo 11-15 D37：老玩家的备份不作废）。
## 代价：改过的明文导出也能这样导进来（封存只管住游戏自己写的文件）。false＝封存开着时不收没签名的导出。
static var ACCEPT_PLAIN_IMPORT := true
const GAME := "org.kyo.xiyou.remake"
## 原版二合一包的格式名（认出来给明确提示）
const MV_FORMAT := "kyo-save-json-v1"
const FILTERS := ["*.json;JSON 存档;application/json"]

## O-206：导入覆盖已有存档前先备份那一格（原版直接覆盖）。false＝照原版直接覆盖。
static var BACKUP_BEFORE_IMPORT := true
## 测试用：代替 DisplayServer.file_dialog_show（参数同它的 mode、filename、callback）。
static var dialog_override := Callable()


static func can_pick_files() -> bool:
	return dialog_override.is_valid() or DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)


## 打开系统文件选择；callback(path: String)，取消或失败时 path 为 ""。返回是否打开了。
static func pick(save_mode: bool, filename: String, callback: Callable) -> bool:
	var mode := DisplayServer.FILE_DIALOG_MODE_SAVE_FILE if save_mode else DisplayServer.FILE_DIALOG_MODE_OPEN_FILE
	var done := func(status: bool, paths: PackedStringArray, _filter: int):
		callback.call(paths[0] if status and not paths.is_empty() else "")
	if dialog_override.is_valid():
		dialog_override.call(mode, filename, done)  # 测试按 file_dialog_show 的三个参数回调
		return true
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		return false
	return DisplayServer.file_dialog_show("导出存档" if save_mode else "导入存档", "", filename, false, mode, FILTERS, done) == OK


## 导出文件的默认名：天启篇开局建的档叫「再刷一把天启篇存档」，其余照旧「再刷重制存档」（文字审 18-005）。
## 只是系统「另存为」框里的建议名：导入只看 JSON 里的 format／game，不看文件名，旧名字导出的文件照样导得进。
static func file_name(slot: int, tianqi := false) -> String:
	return "%s%02d_%s.json" % ["再刷一把天启篇存档" if tianqi else "再刷重制存档", slot,
		Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")]


## 存档原文（XSave 写盘的字典）是不是天启篇开局建的档：与 XTianqi.active 同口径（flags.tianqi.rules ≥ 1）
static func is_tianqi_data(d) -> bool:
	if not (d is Dictionary) or not (d.get("flags") is Dictionary):
		return false
	var tq = d.flags.get("tianqi")
	return tq is Dictionary and int(tq.get("rules", 0)) >= 1


## 某格存档包成导出 JSON：{"text", "tianqi" 是不是天启篇档}；格空或存档坏了返回 {"error": 原因}。
static func export_text(slot: int) -> Dictionary:
	if not XSave.exists(slot):
		return {"error": "这一格没有存档"}
	var r := XSave.read_file(XSave.path(slot))
	if str(r.status) == "failed":
		return {"error": XSaveSeal.FAIL_TEXT}
	var d = XSave._parse(r.text)
	if not XSave.valid_data(d):
		return {"error": "存档为空或损坏"}
	if XSaveSeal.active_now():
		# valid_data 会就地还原同档去重，导出原文（读出来的那份字）再封一次，内容与存档一字不差
		return {"text": JSON.stringify({"format": FORMAT_SEALED, "game": GAME, "slot": slot,
			"exportedAt": Time.get_datetime_string_from_system(), "sealed": Marshalls.raw_to_base64(XSaveSeal.seal(str(r.text)))})}
	return {"text": JSON.stringify({"format": FORMAT, "game": GAME, "slot": slot,
		"exportedAt": Time.get_datetime_string_from_system(), "data": d}), "tianqi": is_tianqi_data(d)}


## 把导出 JSON 写到选好的位置（安卓是 content:// URI）。返回出错原因，成功为 ""。
static func write_file(path: String, text: String) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "写不进这个位置（%s）" % error_string(FileAccess.get_open_error())
	f.store_string(text)
	f.flush()
	var err := f.get_error()
	f.close()
	return "" if err == OK else "写入失败（%s）" % error_string(err)


## 读选好的文件并检查：{"data": 存档} 或 {"error": 原因}。也接受直接是一份重制版存档（没包外层）。
static func read_import(path: String) -> Dictionary:
	if path == "":
		return {"error": "没有选文件"}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"error": "打不开这个文件（%s）" % error_string(FileAccess.get_open_error())}
	if f.get_length() > XSaveSeal.MAX_FILE:  # 导入文件大小上限（co 甲档核查 P2②）
		f.close()
		return {"error": "文件太大，不是本游戏的存档"}
	var bytes := f.get_buffer(f.get_length())
	f.close()
	if XSaveSeal.is_sealed(bytes):  # 直接选了一份封存格式的存档文件
		return _parse_sealed(bytes)
	return parse_import(bytes.get_string_from_utf8())


static func _parse_sealed(bytes: PackedByteArray) -> Dictionary:
	var r := XSaveSeal.unseal(bytes)
	if not r.ok:
		return {"error": XSaveSeal.FAIL_TEXT + "：这个存档文件被改动过或已损坏，不能导入"}
	var data = XSave._parse(r.text)
	if not XSave.valid_data(data):
		return {"error": "JSON 缺少完整的游戏存档数据，或是更新版本的存档"}
	return {"data": data}


static func parse_import(text: String) -> Dictionary:
	var json := JSON.new()  # 不用 JSON.parse_string：坏文件会往日志打 ERROR
	var value = json.data if json.parse(text) == OK else null
	if not (value is Dictionary):
		return {"error": "这不是 JSON 存档"}
	var data = value
	if value.has("format"):
		if str(value.format) == MV_FORMAT:
			return {"error": "这是原版（西游 MOD）的存档，重制版读不了原版存档"}
		if str(value.get("game", "")) != GAME or not str(value.format) in [FORMAT, FORMAT_SEALED]:
			return {"error": "这不是本游戏的 JSON 存档"}
		if str(value.format) == FORMAT_SEALED:
			var raw := Marshalls.base64_to_raw(str(value.get("sealed", ""))) if value.get("sealed") is String else PackedByteArray()
			return _parse_sealed(raw)
		data = value.get("data")
	if XSaveSeal.active_now() and not ACCEPT_PLAIN_IMPORT:
		return {"error": "这是旧版本导出的存档（没有签名），不能导入；请用当前版本重新导出"}
	if not XSave.valid_data(data):
		return {"error": "JSON 缺少完整的游戏存档数据，或是更新版本的存档"}
	return {"data": data}


## 写进第 slot 格。那格有档时先原样复制一份 .before_import_<时间>.json。返回出错原因，成功为 ""。
static func import_to(slot: int, data: Dictionary) -> String:
	if slot < 1 or slot > XSave.SLOTS:
		return "存档位不对"
	if DirAccess.make_dir_recursive_absolute(XSave.dir()) != OK:
		return "建不了存档目录"
	var target := XSave.path(slot)
	# 校验失败的旧档（D28）：不管备不备份，先改名成唯一的 .failed_<时间>，不进导入备份的自动清理（co 甲档核查 P2①）
	if not XSaveSeal.quarantine_if_failed(target):
		return "原来那格存档校验失败、留不下来，没有导入"
	if BACKUP_BEFORE_IMPORT and FileAccess.file_exists(target):
		# 同一秒导入两次不再盖掉上一份备份：重名加 _2、_3……（仍以 .json 结尾，清理照旧按时间留最近几份）
		var keep := XSaveSeal.unique_name("%s.before_import_%s" % [target, Time.get_datetime_string_from_system().replace(":", "")], ".json")
		if DirAccess.copy_absolute(target, keep) != OK:
			return "原来那格存档备份不了，没有导入"
	if not XSaveSeal.write_file(target, JSON.stringify(data)):  # .ksv 封存、.json 明文；读回核对后才替换
		return "替换存档失败"
	XSaveSlim.forget(target)  # 这格换成了导入的内容：瘦没瘦过下次存档重新看
	XSaveSlim.prune_import_backups(target)  # 导入前的备份每格只留最近几份（XSaveSlim.IMPORT_BACKUPS）
	return ""
