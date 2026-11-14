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


## 导出文件的默认名
static func file_name(slot: int) -> String:
	return "再刷重制存档%02d_%s.json" % [slot, Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")]


## 某格存档包成导出 JSON；格空或存档坏了返回 {"error": 原因}。
static func export_text(slot: int) -> Dictionary:
	if not XSave.exists(slot):
		return {"error": "这一格没有存档"}
	var d = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(slot)))
	if not XSave.valid_data(d):
		return {"error": "存档为空或损坏"}
	return {"text": JSON.stringify({"format": FORMAT, "game": GAME, "slot": slot,
		"exportedAt": Time.get_datetime_string_from_system(), "data": d})}


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
	var text := f.get_as_text()
	f.close()
	return parse_import(text)


static func parse_import(text: String) -> Dictionary:
	var json := JSON.new()  # 不用 JSON.parse_string：坏文件会往日志打 ERROR
	var value = json.data if json.parse(text) == OK else null
	if not (value is Dictionary):
		return {"error": "这不是 JSON 存档"}
	var data = value
	if value.has("format"):
		if str(value.format) == MV_FORMAT:
			return {"error": "这是原版（西游 MOD）的存档，重制版读不了原版存档"}
		if str(value.format) != FORMAT or str(value.get("game", "")) != GAME:
			return {"error": "这不是本游戏的 JSON 存档"}
		data = value.get("data")
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
	if BACKUP_BEFORE_IMPORT and FileAccess.file_exists(target):
		var keep := "%s.before_import_%s.json" % [target, Time.get_datetime_string_from_system().replace(":", "")]
		if DirAccess.copy_absolute(target, keep) != OK:
			return "原来那格存档备份不了，没有导入"
	var temp := target + ".tmp"
	var err := write_file(temp, JSON.stringify(data))
	if err != "":
		DirAccess.remove_absolute(temp)
		return err
	if DirAccess.rename_absolute(temp, target) != OK:
		DirAccess.remove_absolute(temp)
		return "替换存档失败"
	XSaveSlim.forget(target)  # 这格换成了导入的内容：瘦没瘦过下次存档重新看
	XSaveSlim.prune_import_backups(target)  # 导入前的备份每格只留最近几份（XSaveSlim.IMPORT_BACKUPS）
	return ""
