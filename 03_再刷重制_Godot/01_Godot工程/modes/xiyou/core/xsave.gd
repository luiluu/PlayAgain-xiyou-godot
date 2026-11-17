class_name XSave
extends RefCounted
## 西游模式存档：<GameApp.save_directory()>/save_<N>.json，即 user://modes/xiyou（按 modes.json 的 saveNamespace 隔离）。
## 只存 Godot 版自己的状态，不读 MV 存档。

## 正式版开局选固定存档位 1～10（开关 161～165、276～280），之后「存档」都存在那一格
const SLOTS := 30
const BACKUP_FIRST := 11
## 自动测试改到临时目录，避免覆盖开发时手动存的档。
static var dir_override := ""
## 最近一次成功存档/读档的格（installV010UsabilityRuntime：一键存档存到这一格）；新游戏到第一次存档前为 0，一键存档改为选格
static var current_slot := 0
## 【cc·未经审查】玩家反馈 v0.01.06「存档之后存不上，读档页看不到存档」：178 哈基米去掉副手（XCat.equip_slots）后装备栏只有 18 格，
## 读档校验却要求每名角色都是 19 格，队里建过 178 的档整份判成坏档（读档页当空格、标题「旧的回忆」灰），存档照写照覆盖旧档。
## true：178 按自己的槽数（少副手一格）也算合法；false 回旧校验（只认 19 格）。
static var CAT_SLOTS_OK := true
## 【cc·未经审查】同上：写盘前先按读档校验核一遍要写的内容，读不回来就不写、返回 false（旧档留着，界面报存档失败）；false 回旧写法（照写）。
static var SAVE_GUARD := true


static func dir() -> String:
	if dir_override != "":
		return dir_override
	# 未经入口进入（测试直接建档）时没有当前模式，退回西游命名空间
	var mode_dir: String = GameApp.save_directory()
	return mode_dir if mode_dir != "" else "user://modes/xiyou"

## 封存（XSaveSeal）开着时是 save_<N>.ksv（旧代码看不见，不会覆盖），关着时是 save_<N>.json
static func path(slot: int) -> String:
	return XSaveSeal.resolve(dir().path_join("save_%d.json" % slot))


static func save(slot: int) -> bool:
	if slot < 1 or slot > SLOTS or XState.current == null:
		return false
	if DirAccess.make_dir_recursive_absolute(dir()) != OK:
		return false
	# Game_System.onBeforeSave：保存次数加 1（写盘失败也不退回，与正式版相同）
	XState.current.save_count += 1
	XDemonCrown.before_save(XState.current)  # 魔冠 makeSaveContents 包装：收编、重放
	var data := XState.current.to_dict()
	data["savedAt"] = Time.get_datetime_string_from_system()
	if not _write(path(slot), data, true):
		return false
	XStarWarehouse.after_save(XState.current)  # 仓库取出事务：存档写好才算取走（O-222·仓库取出事务）
	current_slot = slot
	XAutosaveNotice.loading = false  # YEP_X_Autosave saveGameWithoutRescue 清 _autosaveLoading
	remove_auto()  # 手动存过（含挂机定时存、事件 Autosave），切后台那份就旧了
	return true


## 先写同目录临时文件，成功后替换；失败不截断原有存档。
## 写之前过一遍 XSaveSlim（装备词缀选项表、已不存在装备的已看过标记不进存档；slim_backup＝覆盖没瘦过的旧文件前先备份，自动存档不备份）。
static func _write(target: String, data: Dictionary, slim_backup := false) -> bool:
	var full := data
	data = XSaveSlim.for_write(full, target, slim_backup)
	var text := JSON.stringify(data)
	if SAVE_GUARD and not valid_data(JSON.parse_string(text)):
		push_warning("XSave: 要写的存档读档校验不过，不写，保留旧档：" + target)
		return false
	# 封存（XSaveSeal）：这格原来是校验失败的档就先改名留着，不覆盖；.ksv 写封存格式（读回解开核对后才替换），.json 写明文
	if not XSaveSeal.quarantine_if_failed(target):
		return false
	if not XSaveSeal.write_file(target, text):
		return false
	XSaveSlim.written(full, target, text)
	return true


## 账本类文件（头顶成长、云裳订单）共用的写法（Codex 审查第 2 项，哪吒 save1）：写到同目录临时文件，flush 后查写入错误，
## 写不完整就删掉临时文件、不替换旧文件、返回 false；替换前把旧文件（能解析的才算有效）复制成 <文件>.bak，留上一版。
## 封存管的文件（XSaveSeal.covered）按开关封存写；校验失败的旧文件不覆盖、不写（返回 false）。别的文件（瘦身日志）照旧写明文。
static func write_text_safely(target: String, text: String, keep_backup := true) -> bool:
	if XSaveSeal.covered(target):
		return _write_sealed_ledger(target, text, keep_backup)
	if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK:
		return false
	var temp := "%s.%s.tmp" % [target, Crypto.new().generate_random_bytes(8).hex_encode()]
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	# close 之后再按长度核一遍：写满磁盘、文件大小上限等截断时 get_error 也可能来不及报
	if ok:
		var check := FileAccess.open(temp, FileAccess.READ)
		ok = check != null and check.get_length() == text.to_utf8_buffer().size()
		if check != null:
			check.close()
	if not ok:
		DirAccess.remove_absolute(temp)
		return false
	if keep_backup and FileAccess.file_exists(target):
		var old := JSON.new()
		if old.parse(FileAccess.get_file_as_string(target)) == OK and old.data is Dictionary:
			DirAccess.copy_absolute(target, target + ".bak")
	if DirAccess.rename_absolute(temp, target) != OK:
		DirAccess.remove_absolute(temp)
		return false
	return true


static func _write_sealed_ledger(target: String, text: String, keep_backup: bool) -> bool:
	var old := XSaveSeal.read(target)
	if str(old.status) == "failed":
		push_warning("XSave: 账本校验失败，不覆盖：" + target)
		return false
	if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK:
		return false
	if keep_backup and str(old.status) != "missing":
		var json := JSON.new()
		if json.parse(str(old.text)) == OK and json.data is Dictionary:
			DirAccess.copy_absolute(target, target + ".bak")
	return XSaveSeal.write_file(target, text)


## 读一格存档文件（封存或明文旧档）：{"status": "missing"|"sealed"|"plain"|"failed", "text": …}，见 XSaveSeal.read
static func read_file(p: String) -> Dictionary:
	return XSaveSeal.read(p)


## 这格存档有文件但校验失败（被改过或坏了）
static func seal_failed(slot: int) -> bool:
	return exists(slot) and str(read_file(path(slot)).status) == "failed"

static func auto_seal_failed() -> bool:
	return exists_auto() and str(read_file(auto_path()).status) == "failed"


## 安卓切后台自动存档（XAutoSave，O-215·安卓切后台存档）：单独一个文件，不占手动存档位 1～30。
## 不加保存次数、不改 current_slot（一键存档仍存回玩家自己的档位）；记下当时的档位，读回来时接着用那一格。
static func auto_path() -> String:
	return XSaveSeal.resolve(dir().path_join("save_auto.json"))

static func save_auto() -> bool:
	if XState.current == null:
		return false
	if DirAccess.make_dir_recursive_absolute(dir()) != OK:
		return false
	XDemonCrown.before_save(XState.current)
	var data := XState.current.to_dict()
	data["savedAt"] = Time.get_datetime_string_from_system()
	data["autoFromSlot"] = current_slot
	if not _write(auto_path(), data):
		return false
	XStarWarehouse.after_save(XState.current)
	return true

static func exists_auto() -> bool:
	return FileAccess.file_exists(auto_path())

static func remove_auto() -> void:
	if exists_auto() and XSaveSeal.quarantine_if_failed(auto_path()):  # 校验失败的改名留着，不删
		DirAccess.remove_absolute(auto_path())

## 标题页按钮上的一句话
static func auto_summary() -> String:
	if auto_seal_failed():
		return "自动存档：" + XSaveSeal.FAIL_TEXT
	var d = _parse(read_file(auto_path()).text) if exists_auto() else null
	if not valid_data(d):
		return ""
	return "自动存档：%s" % str(d.get("savedAt", "")).replace("T", " ")

## 读切后台的自动存档；读完文件留着（直到下次手动存档），档位回到存它时玩家在用的那一格。
static func load_auto() -> bool:
	if not exists_auto():
		return false
	var text := str(read_file(auto_path()).text)
	var d = _parse(text)
	if not valid_data(d):
		return false
	var from := int(d.get("autoFromSlot", 0))
	if not _load_data(d, from, text):
		return false
	current_slot = from if from >= 1 and from <= SLOTS else 0
	XAutosaveNotice.loading = true  # 进地图出「存档加载成功！」（重制自己的后台存档，读法同 load_slot）
	return true


## SaveHistory_FullData：找 11～30 中第一个空格，永不覆盖已有备份；0 为已满，-1 为写入失败。
static func backup() -> int:
	for slot in range(BACKUP_FIRST, SLOTS + 1):
		if not exists(slot):
			return slot if save(slot) else -1
	return 0


## 存档页「删除」（StorageManager.remove）：删掉这格的文件
static func remove(slot: int) -> bool:
	if not exists(slot):
		return false
	if seal_failed(slot):  # 校验失败的档不删：改名留着（XSaveSeal.quarantine_if_failed），这格空出来
		return XSaveSeal.quarantine_if_failed(path(slot))
	return DirAccess.remove_absolute(path(slot)) == OK


static func exists(slot: int) -> bool:
	return slot >= 1 and slot <= SLOTS and FileAccess.file_exists(path(slot))


## 在创建角色／替换当前状态前检查完整结构；损坏或未来版本的档不进入反序列化。
## 同档去重的新格式（顶层带 gearPool，见 XSaveSlim）先就地还原成普通内容再查：读存档的地方都先过这里，所以新旧格式都读得了。
static func valid_data(d) -> bool:
	if not d is Dictionary or str(d.get("mode", "")) != "xiyou":
		return false
	if not XSaveSlim.unpool(d):
		return false
	if not (d.get("version") is int or d.get("version") is float) or int(d.version) not in [1, XState.SAVE_VERSION]:
		return false
	for key in ["difficulty", "gold", "mapId", "x", "y", "direction", "steps", "playSeconds"]:
		if not (d.get(key) is int or d.get(key) is float):
			return false
	for key in ["actors", "items", "switches", "variables", "selfSwitches"]:
		if not d.get(key) is Dictionary:
			return false
	for key in ["party", "gear"]:
		if not d.get(key) is Array:
			return false
	for key in ["rom", "seen", "flags", "actorOps", "unlockedMaps", "hangUp"]:
		if d.has(key) and typeof(d[key]) != (TYPE_ARRAY if key in ["seen", "actorOps", "unlockedMaps"] else TYPE_DICTIONARY):
			return false
	for key in d.actors:
		var row = d.actors[key]
		if XDB.rec("Actors", int(key)).is_empty() or not row is Dictionary:
			return false
		for field in ["level", "exp", "hp", "mp"]:
			if not (row.get(field) is int or row.get(field) is float):
				return false
		for field in ["skills", "equips", "states"]:
			if not row.get(field) is Array:
				return false
		if not equips_size_ok(int(key), row.equips.size()):
			return false
		if row.has("cooldowns") and not row.cooldowns is Dictionary:
			return false
		if row.has("stateTurns") and not row.stateTurns is Dictionary:
			return false
		for field in ["buffs", "buffTurns"]:
			if row.has(field) and (not row[field] is Array or row[field].size() != 8):
				return false
		if row.has("tp") and not (row.tp is int or row.tp is float):
			return false
		if row.has("resourceDeathBlocked") and not row.resourceDeathBlocked is bool:
			return false
		if row.has("classId") and not (row.classId is int or row.classId is float):
			return false
		for field in ["classExp", "looks"]:
			if row.has(field) and not row[field] is Dictionary:
				return false
		if row.has("nickname") and not row.nickname is String:
			return false
		if not row.equips.all(func(e): return e == null or _valid_gear(e)):
			return false
		if not XSaveCheck.actor_row(row):
			return false
	if not d.gear.all(_valid_gear):
		return false
	for id in d.party:
		if not (id is int or id is float) or not d.actors.has(str(int(id))):
			return false
	# 出战栏位可缺省（旧 Godot 档）；新档不接受重复、无效角色或损坏类型，避免读档时悄悄换成前五人。
	if d.has("battleSlots"):
		if not d.battleSlots is Array or d.battleSlots.size() != XState.MAX_BATTLE_MEMBERS:
			return false
		var seen := {}
		for id in d.battleSlots:
			if not (id is int or id is float) or float(id) != floorf(float(id)):
				return false
			if id == 0:
				continue
			if not d.party.has(id) or seen.has(int(id)):
				return false
			seen[int(id)] = true
	# from_dict 及读完就跑的包装实际读到的其余字段（审计第 10 项）：坏一处就整个不读，不留半个新局
	return XSaveCheck.top(d)


## 角色装备栏格数：数据库装备类型数减 1（19 格）；178 哈基米去掉副手少一格（CAT_SLOTS_OK）
static func equips_size_ok(actor_id: int, n: int) -> bool:
	var full: int = XDB.system().equipTypes.size() - 1
	return n == full or (CAT_SLOTS_OK and actor_id == XCat.ACTOR and n == full - 1)


static func _valid_gear(e) -> bool:
	return e is Dictionary and str(e.get("kind", "")) in ["weapon", "armor"] and e.get("base") != null \
		and e.get("params") is Array and e.params.size() == 8 and e.get("traits") is Array \
		and e.get("meta") is Dictionary and e.get("etypeId") != null


static func summary(slot: int) -> String:
	if not exists(slot):
		return "存档 %d：空" % slot
	var r := read_file(path(slot))
	if str(r.status) == "failed":
		return "存档 %d：%s" % [slot, XSaveSeal.FAIL_TEXT]
	var d = _parse(r.text)
	if not valid_data(d):
		return "存档 %d：无法读取" % slot
	var leader := str(XDB.rec("Actors", int(d.party[0])).get("name", "")) if not d.party.is_empty() else ""
	var lv := int(d.actors.get(str(int(d.party[0])), {}).get("level", 1)) if not d.party.is_empty() else 1
	var map_name := str(XDB.map(int(d.mapId)).get("displayName", ""))
	return "存档 %d：%s Lv%d  %s  %s" % [slot, leader, lv, map_name, str(d.get("savedAt", "")).replace("T", " ")]


## 开局选存档位页（T102，开局界面提案 v0.2 第四节）用的只读摘要：不写盘、不改 current_slot；summary() 字符串照旧给读档页、导出用。
## state：empty（没文件）／ok／failed（校验失败，text＝XSaveSeal.FAIL_TEXT）／invalid（valid_data 不过，text＝「无法读取」）。
## party 不够 5 个不补；Actors 表里查不到的 id 跳过。
static func summary_dict(slot: int) -> Dictionary:
	var out := {"slot": slot, "state": "empty", "text": "", "leader_id": 0, "leader_name": "", "level": 1, "map_name": "",
		"saved_at": "", "play_seconds": 0.0, "is_tianqi": false, "difficulty": "", "party_ids": []}
	if not exists(slot):
		return out
	var r := read_file(path(slot))
	if str(r.status) == "failed":
		out.state = "failed"
		out.text = XSaveSeal.FAIL_TEXT
		return out
	var d = _parse(r.text)
	if not valid_data(d):
		out.state = "invalid"
		out.text = "无法读取"
		return out
	out.state = "ok"
	if not d.party.is_empty():
		out.leader_id = int(d.party[0])
		out.leader_name = str(XDB.rec("Actors", out.leader_id).get("name", ""))
		out.level = int(d.actors.get(str(out.leader_id), {}).get("level", 1))
	out.map_name = str(XDB.map(int(d.mapId)).get("displayName", ""))
	out.saved_at = str(d.get("savedAt", "")).replace("T", " ")
	out.play_seconds = float(d.get("playSeconds", 0))
	var tq = d.get("flags", {}).get("tianqi") if d.get("flags") is Dictionary else null
	out.is_tianqi = tq is Dictionary and int(tq.get("rules", 0)) >= 1
	if out.is_tianqi:
		out.difficulty = str(tq.get("difficulty", ""))
		out.party_ids = Array(d.party).map(func(id): return int(id)).filter(func(id): return not XDB.rec("Actors", id).is_empty())
	return out


static func load_slot(slot: int) -> bool:
	if not exists(slot):
		return false
	var text := str(read_file(path(slot)).text)
	var d = _parse(text)
	if not valid_data(d):
		return false
	if not _load_data(d, slot, text):
		return false
	current_slot = slot
	XAutosaveNotice.loading = true  # YEP_X_Autosave loadGameWithoutRescue：_autosaveLoading，进地图出「存档加载成功！」
	return true


static func _load_data(d: Dictionary, slot: int, text: String) -> bool:
	XState.from_dict(d)
	XDungeon.repair_after_load(XState.current)  # T055：旧档残留的变量 21 错值（副本外 −1、副本内 0）按副本上下文修正
	XYunshangOrders.after_load(XState.current, XYunshangOrders.identity(slot, text))  # 云裳 extractSaveContents 包装：订单账本重放
	XDemonCrown.after_load(XState.current, XDemonCrown.identity(text))  # 魔冠 extractSaveContents 包装（在云裳外层）：收编、重放成长账本
	XTusuXuan.after_load(XState.current)  # 屠苏／璇 extractSaveContents 包装：专属技能按习得表同步
	XCat.restore_trial(XState.current, -1)  # 小猫 extractSaveContents 包装：存档里留着试炼就还原队伍
	XTianqiGojoTrial.after_load(XState.current)  # 天启篇五条悟：存档里留着试炼就还原队伍和战前状态；旧四阶进阶迁移成两阶
	XFestReward.after_load(XState.current)  # 冠军庆典：称号 45 并进 41、收尾期后剩币自动换精魂、活动期间当天第一次读档的提醒（进地图时弹）
	XStarWarehouse.after_load(XState.current, text)  # 仓库取出事务：存档里带着的 whToken 记成取走，别的局没存档的取出退回仓库
	# dev.015 及以前忽略 ConfigManager 脚本，没有配置文件。已完成大厅 EV20 的 Godot 档补其 MapXy=true；
	# 已有配置（包括显式 false）始终优先，不从存档回滚局外选项，不读取 MV 存档。
	if not XConfig.has_map_xy() and XState.current.self_switch(4, 20, "A"):
		XConfig.set_map_xy(true)
	return true


## 不往日志打 ERROR 的解析（校验失败读出的是空串）
static func _parse(text):
	if str(text) == "":
		return null
	var json := JSON.new()
	return json.data if json.parse(str(text)) == OK else null
