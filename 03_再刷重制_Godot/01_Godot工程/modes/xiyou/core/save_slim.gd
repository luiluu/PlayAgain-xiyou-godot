class_name XSaveSlim
extends RefCounted
## 【cc·未经审查】存档与本机缓存自动清理（Kyo 2026-11-14「游戏的缓存自动清理，装备数据啊，过期数据之类的」）。
## 盘点见交付单 cc_save-data-cleanup：存档八九成是装备实例，卖掉／分解的不留实例；只清下面三类「确定没人读」的，
## 各一个开关，关掉回到原来的写法。
##
## 1. GEAR_ROLL_TABLE：装备实例的 equipment.affixes（掉落时掷词缀的选项表）不写进存档。它只在 XGear.roll_item 里读，
##    读的是当场 XGear.template 新建的模板，已有实例上那份没有任何代码再读，却占整份存档 18%～37%。
## 2. SEEN_STALE：seen（已看过标记）里 xg:N、而整份存档里已经没有这个实例号的不写进存档（卖掉、分解后留下的；
##    实例号只增不复用：XState.next_gear_id 随档存，register_gear 取最大）。物品的 i:N 不动。
## 3. TEMP_FILES：存档目录、JSON 缓存目录里放了一小时以上的 *.tmp（「先写临时文件再改名」写到一半被杀进程留下的，没人读）
##    每次启动进标题时删一次。
##
## 第 1、2 类只改「写出去的那一份」（XSave.save／save_auto 写盘前调 for_write）：不改内存里的装备和标记，
## 不在读档、启动时主动改写任何存档文件，玩家没再存过的旧格一个字节都不动。
## 4. STAR_WAREHOUSE（Kyo 11-14 ④）：星级仓库文件 star_warehouse.json 里的装备同样不写选项表（XStarWarehouse._save 写盘前调 for_warehouse）。
## 5. IMPORT_BACKUPS（Kyo 11-14 ①）：导入存档前的备份 save_N.json.before_import_<时间>.json 每格只留最近 IMPORT_KEEP 份
##    （原来每导入一次多一份整档、从不删）；导入成功后调 prune_import_backups。
##
## 第 1、2、4 类只改「写出去的那一份」（XSave.save／save_auto、XStarWarehouse._save 写盘前调）：不改内存里的装备和标记，
## 不在读档、启动时主动改写任何存档文件，玩家没再存过的旧格一个字节都不动。
## 备份（Kyo 11-14 ⑥：每格只留最新的一份）：某个文件磁盘上那份还没瘦过（顶层没有 saveSlim 记号）、这次要被瘦过的内容覆盖时，
## 先把原文件原样复制成 <文件>.before_slim.bak，已有就换成这次的（先写旁边的 .tmp、逐字节核对后改名，换不成旧备份留着）；
## 复制失败这次就不瘦身、照原样写。已经瘦过的文件之后普通存档不再复制。自动存档 save_auto.json 是临时文件（手动存过就删），不备份。
## 日志：某个文件由没瘦变瘦、删了临时文件或导入备份时，往引擎日志打一行，并记进存档目录的 cleanup_log.json（只留最近 LOG_KEEP 条）。

## O-待定-1·存档不带装备词缀选项表：false＝照旧整份写
static var GEAR_ROLL_TABLE := true
## O-待定-2·存档不带已不存在装备的已看过标记：false＝照旧全写
static var SEEN_STALE := true
## O-待定-3·启动时清残留临时文件：false＝不清
static var TEMP_FILES := true
## O-待定-4·星级仓库文件不带装备词缀选项表：false＝照旧整份写
static var STAR_WAREHOUSE := true
## O-待定-5·导入存档前的备份每格只留最近 IMPORT_KEEP 份：false＝照旧永远留着
static var IMPORT_BACKUPS := true

const MARK := "saveSlim"
const BACKUP_SUFFIX := ".before_slim.bak"
const LOG_FILE := "cleanup_log.json"
const LOG_KEEP := 20
const TEMP_SUFFIX := ".tmp"
const TEMP_AGE_SEC := 3600
const IMPORT_KEEP := 2
const IMPORT_MARK := ".before_import_"

## 最近一次瘦身的统计：{slim: 是否瘦了, gear: 去掉选项表的装备件数, seen: 去掉的标记条数, backup: 这次做的备份路径或 "",
##   target: 哪个文件, log: 写成后要不要记日志（磁盘上原来没有瘦过的那份，且不是自动存档）}
static var last := {}
## 已经知道「瘦过」的文件 → [修改时间, 字节数]；文件被换过（导入、外面覆盖）对不上就重新看文件，免得每次存档都读一遍
static var _slim_files := {}
static var _swept := false


## 存档写盘前：返回要写的内容。瘦了就是新的顶层字典（改到的地方是浅拷贝，原字典和内存里的装备不动）并带 saveSlim 记号；
## 开关全关、或该备份却备份不了时原样返回 data。backup＝要不要守「先备份」那条（自动存档传 false）。
static func for_write(data: Dictionary, target: String, backup := true) -> Dictionary:
	return _slim(data, target, backup, GEAR_ROLL_TABLE, SEEN_STALE)


## 星级仓库写盘前（同上，只去装备选项表）
static func for_warehouse(data: Dictionary, target: String) -> Dictionary:
	return _slim(data, target, true, STAR_WAREHOUSE, false)


static func _slim(data: Dictionary, target: String, backup: bool, do_gear: bool, do_seen: bool) -> Dictionary:
	last = {"slim": false, "gear": 0, "seen": 0, "backup": "", "target": target, "log": false}
	if not do_gear and not do_seen:
		return data
	var was_slim := FileAccess.file_exists(target) and _is_slim_file(target)
	if backup and FileAccess.file_exists(target) and not was_slim:
		if not _backup(target):
			push_warning("XSaveSlim: 备份不了，这次不瘦身：" + target)
			return data
		last.backup = target + BACKUP_SUFFIX
	var stat := {"gear": 0, "strip": do_gear}
	var live := {}
	var out: Dictionary = _walk(data, live, stat)
	if is_same(out, data):
		out = data.duplicate(false)
	if do_seen and data.get("seen") is Array:
		var kept: Array = (data.seen as Array).filter(func(k): return not str(k).begins_with("xg:") or live.has(str(k)))
		last.seen = (data.seen as Array).size() - kept.size()
		out["seen"] = kept
	out[MARK] = 1
	last.slim = true
	last.gear = int(stat.gear)
	last.log = backup and not was_slim
	return out


## 写盘成功之后调（data_before＝没瘦的那份内容，text_after＝写进文件的字）：记下这个文件已瘦；
## 由没瘦变瘦（含新写的一格）的记一条日志，没瘦时的字节数只在这时算一次
static func written(data_before: Dictionary, target: String, text_after: String) -> void:
	if not bool(last.get("slim", false)) or str(last.get("target", "")) != target:
		return
	_slim_files[target] = _stamp(target)
	if not bool(last.log) or (str(last.backup) == "" and int(last.gear) == 0 and int(last.seen) == 0):
		return
	var before := JSON.stringify(data_before).to_utf8_buffer().size()
	var after := text_after.to_utf8_buffer().size()
	_log({"kind": "save", "file": target.get_file(), "gear": int(last.gear), "seen": int(last.seen),
		"before": before, "after": after, "saved": before - after, "backup": str(last.backup).get_file()})


## 这个文件被别处换掉了（导入存档）：下次重新看
static func forget(target: String) -> void:
	_slim_files.erase(target)


static func _stamp(target: String) -> Array:
	return [FileAccess.get_modified_time(target), FileAccess.get_size(target)]


static func _is_slim_file(target: String) -> bool:
	var st := _stamp(target)
	if _slim_files.get(target) == st:
		return true
	# 不整份解析：JSON.stringify 写出的顶层记号就是这几个字（字符串值里的引号会带反斜杠，对不上）
	if FileAccess.get_file_as_string(target).contains("\"%s\":1" % MARK):
		_slim_files[target] = st
		return true
	_slim_files.erase(target)
	return false


## 把 target 原样复制成 target.before_slim.bak（已有就换掉）：先写 .tmp、逐字节核对、再改名；不成功旧备份原样留着
static func _backup(target: String) -> bool:
	var bak := target + BACKUP_SUFFIX
	var part := bak + TEMP_SUFFIX  # 半路被杀留下的由 sweep_temp 清
	if DirAccess.dir_exists_absolute(part) or DirAccess.dir_exists_absolute(bak):
		return false  # 同名的目录占着：复制不进去
	if DirAccess.copy_absolute(target, part) != OK or FileAccess.get_file_as_bytes(target) != FileAccess.get_file_as_bytes(part):
		DirAccess.remove_absolute(part)
		return false
	if DirAccess.rename_absolute(part, bak) != OK:
		DirAccess.remove_absolute(part)
		return false
	return true


static func is_gear(v: Dictionary) -> bool:
	return v.get("equipment") is Dictionary and v.has("base") and str(v.get("kind", "")) in ["weapon", "armor"]


## 写时复制的遍历：没改到的原样返回同一个对象；碰到装备实例记下实例号、去掉选项表（浅拷贝），不再往里走。
static func _walk(v, live: Dictionary, stat: Dictionary):
	if v is Dictionary:
		if v.has("instanceId"):
			live[str(v.instanceId)] = true
		if is_gear(v):
			if not bool(stat.strip) or not (v.equipment as Dictionary).has("affixes"):
				return v
			var item: Dictionary = v.duplicate(false)
			var eq: Dictionary = (v.equipment as Dictionary).duplicate(false)
			eq.erase("affixes")
			item["equipment"] = eq
			stat.gear = int(stat.gear) + 1
			return item
		var out = null
		for k in v:
			var c = v[k]
			if c is Dictionary or c is Array:
				var r = _walk(c, live, stat)
				if not is_same(r, c):
					if out == null:
						out = v.duplicate(false)
					out[k] = r
		return v if out == null else out
	if v is Array:
		var out2 = null
		for i in range(v.size()):
			var c2 = v[i]
			if c2 is Dictionary or c2 is Array:
				var r2 = _walk(c2, live, stat)
				if not is_same(r2, c2):
					if out2 == null:
						out2 = v.duplicate(false)
					out2[i] = r2
		return v if out2 == null else out2
	return v


# ---- 残留临时文件 ----

## 进标题时调：本进程只扫一次
static func sweep_once() -> void:
	if _swept:
		return
	_swept = true
	sweep_temp([XSave.dir(), XDB.cache_dir()])


## 删 dirs 里（不进子目录）修改时间早于 now − TEMP_AGE_SEC 的 *.tmp；返回 {files: [名字…], bytes}
static func sweep_temp(dirs: Array, now := -1.0) -> Dictionary:
	var report := {"files": [], "bytes": 0}
	if not TEMP_FILES:
		return report
	if now < 0:
		now = Time.get_unix_time_from_system()
	for dir in dirs:
		if str(dir) == "" or not DirAccess.dir_exists_absolute(str(dir)):
			continue
		for name in DirAccess.get_files_at(str(dir)):
			if not name.ends_with(TEMP_SUFFIX):
				continue
			var p := str(dir).path_join(name)
			var mtime := FileAccess.get_modified_time(p)
			if mtime <= 0 or now - float(mtime) < TEMP_AGE_SEC:
				continue
			var f := FileAccess.open(p, FileAccess.READ)
			var size := int(f.get_length()) if f != null else 0
			if f != null:
				f.close()
			if DirAccess.remove_absolute(p) == OK:
				report.files.append(name)
				report.bytes = int(report.bytes) + size
	if not (report.files as Array).is_empty():
		_log({"kind": "temp", "files": report.files, "saved": int(report.bytes)})
	return report


# ---- 导入存档前的备份 ----

## 导入成功后调：target 这格的 before_import 备份只留最近 IMPORT_KEEP 份（文件名里的时间 YYYY-MM-DDTHHMMSS 定宽，按名字排就是按时间排）。
## 返回删掉的文件名
static func prune_import_backups(target: String) -> Array:
	var removed := []
	if not IMPORT_BACKUPS:
		return removed
	var dir := target.get_base_dir()
	var prefix := target.get_file() + IMPORT_MARK
	var names := Array(DirAccess.get_files_at(dir)).filter(func(n): return str(n).begins_with(prefix) and str(n).ends_with(".json"))
	names.sort()
	var bytes := 0
	while names.size() > IMPORT_KEEP:
		var name := str(names.pop_front())
		var p := dir.path_join(name)
		var size := FileAccess.get_file_as_bytes(p).size()
		if DirAccess.remove_absolute(p) == OK:
			removed.append(name)
			bytes += size
	if not removed.is_empty():
		_log({"kind": "import_backup", "files": removed, "saved": bytes})
	return removed


# ---- 日志 ----

static func log_path() -> String:
	return XSave.dir().path_join(LOG_FILE)


static func read_log() -> Array:
	var d = JSON.parse_string(FileAccess.get_file_as_string(log_path())) if FileAccess.file_exists(log_path()) else null
	return d if d is Array else []


static func _log(entry: Dictionary) -> void:
	entry["at"] = Time.get_datetime_string_from_system()
	print("XSaveSlim: ", JSON.stringify(entry))
	var list := read_log()
	list.append(entry)
	if list.size() > LOG_KEEP:
		list = list.slice(list.size() - LOG_KEEP)
	XSave.write_text_safely(log_path(), JSON.stringify(list), false)
