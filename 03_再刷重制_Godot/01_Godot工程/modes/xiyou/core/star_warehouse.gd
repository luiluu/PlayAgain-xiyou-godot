class_name XStarWarehouse
extends RefCounted
## 星级仓库（Star_Warehouse 的通用仓库）：Map041 黄金大厅 EV1「存放／取出」＝SceneManager.push(Scene_StarSaveWarehouse／Scene_StarWarehouse)。
## 跨存档：原版放在 ConfigManager.GetEq／GetPet（save/config.rpgsave）；这里是 <存档目录>/star_warehouse.json，不读 MV 文件。
##   格式 {version, mode, gear: [装备实例…], pets: [宠物…]}：装备实例就是 XState.gear 里的字典，宠物是 XPets 的字典，都存整份。
## 只收背包里的装备（不列身上穿着的）和宠物；没有容量上限。参照 mv_oracle/star_warehouse_probe.cjs（tests/xiyou_star_warehouse）。
## - 存入装备：<PushDct> 不收（「不可存放」）；锁定、异化装备照原版能存。取出：去掉原实例编号，按本档重编号
##   （原版取出时 id = $dataWeapons.length 重分配；两档各有 xg:1 时不重编号会撞号，gear_query 按编号去重会漏件）。
## - 存入宠物：出战宠物不收（原版点了没反应，只有确定音）；其余走 XPets.release 的序号修正。取出追加在末尾。
## - 原版缺陷的处理（优化登记，见各开关）：O-124 立即写盘、O-126 跨档异化装备清配置换 uid、O-127 挡下供体与待选重抽。
## 复制问题照原版不防（存放后不存档读旧档，旧档里那件还在；用户默认甲）。

const PUSH_DCT := "PushDct"

## O-124（优化登记）：原版仓库画面不写配置，要等下一次配置写盘（关设置页等）东西才落盘，期间退出就丢。
## true＝每次存取立即写盘；false＝照原版，只改内存，等 XConfig 下一次写盘时一起写（flush_pending）
static var o_save_now := true
## O-126：异化装备的配置（actorId／partnerId／skillId／donorId）指向本档的角色和装备实例，搬到别的档就错位（原版同样带走）。
## true＝存入时清掉配置、取出时按本档账本换 uid，到工坊重配；false＝照原版原样带走
static var o_alien_reset := true
## O-127：原版存放直接 delete，不经 loseItem，吞器占用的供体、待选重抽中的异化装备也能存走（吞器开战即卸下、待选永远落空）。
## true＝这两种挡下（「不可存放」）；false＝照原版放行
static var o_block_bound := true

## O-222·仓库取出事务（Codex 审查报告第 1 项）：原来取出时先从仓库删掉并写盘，角色档要等玩家存档才有这件，
## 中途退出就两边都没有、永久丢了。true＝取出先记成「取出中」（带 whToken 记在仓库文件的 pending 里），
## 玩家存档（手动／自动，XSave.save／save_auto）成功才算取走；没存就退出、读别的档、开新局，下次打开仓库或读档时退回仓库。
## 存档写好后仓库没来得及记（进程被杀），按存档文件里有没有这个 whToken 补记取走。false＝照旧，取出即从仓库删掉。
static var o_withdraw_txn := true

## 测试改路径；空则跟 XSave.dir()
static var path_override := ""
static var _loaded_path := "<unloaded>"
static var _gear: Array = []
static var _pets: Array = []
static var _dirty := false
## 取出中的记录：[{token, kind: "gear"|"pet", index: 原位置, rec: 取出前的整份}]；随仓库文件写盘
static var _pending: Array = []
## token → WeakRef(取出时的 XState)：本进程里还是那一局就不退回
static var _owners := {}
## 最近一次存取失败的原因（写盘失败时画面提示用）；成功为空
static var last_error := ""
const WRITE_FAILED := "仓库写盘失败，这次没有存取"


static func path() -> String:
	return path_override if path_override != "" else XSave.dir().path_join("star_warehouse.json")


static func ensure_loaded() -> void:
	var p := path()
	if p == _loaded_path:
		return
	_loaded_path = p
	_gear = []
	_pets = []
	_pending = []
	_dirty = false
	if not FileAccess.file_exists(p):
		return
	var json := JSON.new()  # 不用 parse_string：损坏时不往日志打错误
	var d = json.data if json.parse(FileAccess.get_file_as_string(p)) == OK else null
	if not d is Dictionary:
		return  # 损坏的文件按空处理；下次存取时整份重写
	for e in (d.get("gear") if d.get("gear") is Array else []):
		if e is Dictionary and e.has("kind") and e.has("base"):
			_gear.append(e)
	for e in (d.get("pets") if d.get("pets") is Array else []):
		if e is Dictionary and e.has("enemy"):
			_pets.append(e)
	for e in (d.get("pending") if d.get("pending") is Array else []):
		if e is Dictionary and str(e.get("token", "")) != "" and e.get("rec") is Dictionary and str(e.get("kind")) in ["gear", "pet"]:
			_pending.append(e)
	resolve_pending()


## 取出列表（原版 ConfigManager.GetEq／GetPet，按存入先后）
static func gear() -> Array:
	ensure_loaded()
	return _gear


## 取出画面列的装备：异化隐藏生效时不列残响（O-283；仓库跨存档，读档迁移管不到，原版没管，重制补）
static func withdrawable_gear() -> Array:
	return XAlienHide.filter_gear(gear().duplicate())


static func pets() -> Array:
	ensure_loaded()
	return _pets


## 取出列表的宠物名：原版仓库里的宠物不在 $gameParty.Pets，Game_Enemy.name 不去稀有度标签（Star_PetSystem 1172）。
## 原版捕获来的还带 Capture 标记、名字后加「宝宝」，重制宠物不记这个标记，不加（交付单已知差异）
static func stored_pet_name(pet: Dictionary) -> String:
	return (XEnemy.elite_title() if bool(pet.get("elite", false)) else "") + str(XDB.rec("Enemies", int(pet.get("enemy", 0))).get("name", "")) + str(pet.get("letter", ""))


## 存放列表（原版 $gameParty.armors().concat(weapons())：防具在前，各按本体、编号）
static func carried_gear() -> Array:
	return XItemScene.bag_gear("armor") + XItemScene.bag_gear("weapon")


static func push_dct(rec: Dictionary) -> bool:
	return rec.get("meta", {}).has(PUSH_DCT) if rec.get("meta") is Dictionary else str(rec.get("note", "")).contains("<" + PUSH_DCT + ">")


## 存入一件；返回 "" 成功，否则返回提示文字（「不可存放」），东西不动
static func deposit_gear(s: XState, rec: Dictionary) -> String:
	last_error = ""
	var i := s.gear.find_custom(func(e): return is_same(e, rec))
	if i < 0:
		return "不可存放"
	if push_dct(rec) or o_block_bound and (XAlienation.reserved(s, rec) or XAlienation.is_pending(s, rec)):
		return "不可存放"
	ensure_loaded()
	# Codex 审查第 4 项：先写盘、写好了才从背包拿掉；写盘失败什么都不动（异化配置也还原），把原因交给画面
	var config = XAlienation.mark(rec).get("config") if not XAlienation.mark(rec).is_empty() else null
	if o_alien_reset and not XAlienation.mark(rec).is_empty():
		XAlienation.mark(rec).config = {}
	var token := str(rec.get("whToken", ""))
	var undo := _take_pending(token)   # 取出还没存档又存回来：取消那笔取出
	rec.erase("whToken")
	_gear.append(rec)
	if not _changed():
		_gear.pop_back()
		_restore_pending(undo, rec, token)
		if config != null:
			XAlienation.mark(rec).config = config
		last_error = WRITE_FAILED
		return WRITE_FAILED
	s.lose_gear(rec, false)  # 原版直接改 $gameParty._armors，不经 gainItem，不记云裳账本
	return ""


## 取出一件：按本档重编号（O-126 开时异化装备另换 uid），放回背包。写盘失败返回 false、仓库与背包都不动（last_error 说明）
static func withdraw_gear(s: XState, rec: Dictionary) -> bool:
	last_error = ""
	ensure_loaded()
	var i := _gear.find_custom(func(e): return is_same(e, rec))
	if i < 0 or XAlienHide.blocks_gear(rec):
		return false
	var token := _begin_withdraw("gear", i, rec)
	_gear.remove_at(i)
	if not _changed():
		_gear.insert(i, rec)
		_take_pending(token)
		last_error = WRITE_FAILED
		return false
	rec.erase("instanceId")
	s.register_gear(rec)
	if XAlienHide.active():
		XAlienHide.restore(rec)  # 异化隐藏生效：取出的异化装备还原成普通装备（同读档迁移）
	if o_alien_reset and not XAlienation.mark(rec).is_empty():
		var led := XAlienation.ledger(s)
		led.sequence = int(led.sequence) + 1
		XAlienation.mark(rec).uid = "alien-%d" % int(led.sequence)
	_own(token, s, rec)
	s.gear.append(rec)
	return true


## 存入一只宠物（序号）；出战宠物返回 false、不动
static func deposit_pet(s: XState, index: int) -> bool:
	last_error = ""
	var list := XPets.list(s)
	if index < 0 or index >= list.size() or index == XPets.war_index(s):
		return false
	var pet: Dictionary = list[index]
	ensure_loaded()
	var token := str(pet.get("whToken", ""))
	var undo := _take_pending(token)
	pet.erase("whToken")
	_pets.append(pet)
	if not _changed():
		_pets.pop_back()
		_restore_pending(undo, pet, token)
		last_error = WRITE_FAILED
		return false
	XPets.release(s, index)
	return true


static func withdraw_pet(s: XState, pet: Dictionary) -> bool:
	last_error = ""
	ensure_loaded()
	var i := _pets.find_custom(func(e): return is_same(e, pet))
	if i < 0:
		return false
	var token := _begin_withdraw("pet", i, pet)
	_pets.remove_at(i)
	if not _changed():
		_pets.insert(i, pet)
		_take_pending(token)
		last_error = WRITE_FAILED
		return false
	_own(token, s, pet)
	XPets.list(s).append(pet)
	return true


## 写盘成功（或 o_save_now 关时记脏、等 XConfig 写盘）返回 true；写盘失败返回 false，脏标记不清
static func _changed() -> bool:
	if o_save_now:
		return _save()
	_dirty = true
	return true


# ---- 取出事务（o_withdraw_txn）----
static func _begin_withdraw(kind: String, index: int, rec: Dictionary) -> String:
	if not o_withdraw_txn:
		return ""
	var token := "wh-%d-%d" % [Time.get_unix_time_from_system(), randi()]
	_pending.append({"token": token, "kind": kind, "index": index, "rec": rec.duplicate(true)})
	return token


static func _own(token: String, s: XState, rec: Dictionary) -> void:
	if token == "":
		return
	rec["whToken"] = token
	_owners[token] = weakref(s)


static func _take_pending(token: String) -> Dictionary:
	if token == "":
		return {}
	var i := _pending.find_custom(func(e): return str(e.token) == token)
	if i < 0:
		return {}
	var e: Dictionary = _pending[i]
	_pending.remove_at(i)
	return e


static func _restore_pending(entry: Dictionary, rec: Dictionary, token: String) -> void:
	if entry.is_empty():
		return
	_pending.append(entry)
	rec["whToken"] = token


static func _owned_by(token: String, s) -> bool:
	var w = _owners.get(token)
	return s != null and w is WeakRef and is_same(w.get_ref(), s)


## 存档写好之后（XSave.save／save_auto）：这一局取出的都算取走（还在身上的、已经卖掉用掉的都是），记进仓库文件；
## 写盘失败就留着，下次按存档文件里的 whToken 补记
static func after_save(s: XState) -> void:
	ensure_loaded()
	if _pending.is_empty():
		return
	var before := _pending.size()
	_pending = _pending.filter(func(e): return not _owned_by(str(e.token), s))
	if _pending.size() != before:
		_strip_tokens(s)
		_changed()


## 读档之后（XSave._load_data）：存档里带着的 whToken 都算取走（存档写好、仓库没来得及记的那种），去掉标记；
## 其余不属于当前这一局的取出按存档文件补记或退回仓库
static func after_load(s: XState, text: String) -> void:
	ensure_loaded()
	var before := _pending.size()
	_pending = _pending.filter(func(e): return not text.contains(str(e.token)))
	_strip_tokens(s)
	var changed := _pending.size() != before
	if resolve_pending(false) or changed:
		_changed()


## 取出中、又不属于当前这一局的：哪个存档文件里有这个 whToken 就算取走，都没有就退回仓库原位。返回有没有变化（write 真时顺手写盘）
static func resolve_pending(write := true) -> bool:
	var loose := _pending.filter(func(e): return not _owned_by(str(e.token), XState.current))
	if loose.is_empty():
		return false
	var texts := []
	for slot in range(1, XSave.SLOTS + 1):
		if XSave.exists(slot):
			texts.append(FileAccess.get_file_as_string(XSave.path(slot)))
	if XSave.exists_auto():
		texts.append(FileAccess.get_file_as_string(XSave.auto_path()))
	for e in loose:
		_pending.erase(e)
		var token := str(e.token)
		if texts.any(func(t): return t.contains(token)):
			continue   # 存档里有：取走
		var into: Array = _gear if e.kind == "gear" else _pets
		into.insert(clampi(int(e.get("index", into.size())), 0, into.size()), e.rec)
	if write:
		_changed()
	return true


static func _strip_tokens(s: XState) -> void:
	var all: Array = s.gear.duplicate()
	for a in s.actors.values():
		all.append_array(a.raw_equip_list())
	all.append_array(XPets.list(s))
	for e in all:
		if e is Dictionary and e.has("whToken") and not _pending.any(func(p): return str(p.token) == str(e.whToken)):
			e.erase("whToken")


## XConfig 写盘时一起写（o_save_now 关时照原版的落盘时机）；写盘失败返回 false、脏标记留着
static func flush_pending() -> bool:
	if _dirty:
		return _save()
	return true


## 同 XGlobalVars：先写临时文件再替换。写盘失败返回 false，脏标记不清（Codex 审查第 4 项：原来写盘前就清了）
static func _save() -> bool:
	var p := path()
	if DirAccess.make_dir_recursive_absolute(p.get_base_dir()) != OK:
		return false
	var full := {"version": 1, "mode": "xiyou", "gear": _gear, "pets": _pets}
	if not _pending.is_empty():
		full["pending"] = _pending
	# 装备的词缀选项表不进文件（XSaveSlim.STAR_WAREHOUSE；只改写出去的那份，覆盖没瘦过的旧文件前先备份）
	var data := XSaveSlim.for_warehouse(full, p)
	var temp := p + ".tmp"
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		return false
	var text := JSON.stringify(data)
	f.store_string(text)
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	if not ok or DirAccess.rename_absolute(temp, p) != OK:
		DirAccess.remove_absolute(temp)
		return false
	XSaveSlim.written(full, p, text)
	_dirty = false
	return true
