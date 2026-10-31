class_name XStarWarehouse
extends RefCounted
## 星级仓库（Star_Warehouse 的通用仓库）：Map041 黄金大厅 EV1「存放／取出」＝SceneManager.push(Scene_StarSaveWarehouse／Scene_StarWarehouse)。
## 跨存档：原版放在 ConfigManager.GetEq／GetPet（save/config.rpgsave）；这里是 <存档目录>/star_warehouse.json，不读 MV 文件。
##   格式 {version, mode, gear: [装备实例…], pets: [宠物…]}：装备实例就是 XState.gear 里的字典，宠物是 XPets 的字典，都存整份。
## 只收背包里的装备（不列身上穿着的）和宠物；没有容量上限。参照 mv_oracle/star_warehouse_probe.cjs（tests/xiyou_star_warehouse）。
## - 存入装备：<PushDct> 不收（「不可存放」）；锁定、异化装备照原版能存。取出：去掉原实例编号，按本档重编号
##   （原版取出时 id = $dataWeapons.length 重分配；两档各有 xg:1 时不重编号会撞号，gear_query 按编号去重会漏件）。
## - 存入宠物：出战宠物不收（原版点了没反应，只有确定音）；其余走 XPets.release 的序号修正。取出追加在末尾。
## - 原版缺陷的处理（优化登记，见各开关）：O-待定 立即写盘、O-待定 跨档异化装备清配置换 uid、O-待定 挡下供体与待选重抽。
## 复制问题照原版不防（存放后不存档读旧档，旧档里那件还在；用户默认甲）。

const PUSH_DCT := "PushDct"

## O-待定（优化登记）：原版仓库画面不写配置，要等下一次配置写盘（关设置页等）东西才落盘，期间退出就丢。
## true＝每次存取立即写盘；false＝照原版，只改内存，等 XConfig 下一次写盘时一起写（flush_pending）
static var o_save_now := true
## O-待定：异化装备的配置（actorId／partnerId／skillId／donorId）指向本档的角色和装备实例，搬到别的档就错位（原版同样带走）。
## true＝存入时清掉配置、取出时按本档账本换 uid，到工坊重配；false＝照原版原样带走
static var o_alien_reset := true
## O-待定：原版存放直接 delete，不经 loseItem，吞器占用的供体、待选重抽中的异化装备也能存走（吞器开战即卸下、待选永远落空）。
## true＝这两种挡下（「不可存放」）；false＝照原版放行
static var o_block_bound := true

## 测试改路径；空则跟 XSave.dir()
static var path_override := ""
static var _loaded_path := "<unloaded>"
static var _gear: Array = []
static var _pets: Array = []
static var _dirty := false


static func path() -> String:
	return path_override if path_override != "" else XSave.dir().path_join("star_warehouse.json")


static func ensure_loaded() -> void:
	var p := path()
	if p == _loaded_path:
		return
	_loaded_path = p
	_gear = []
	_pets = []
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


## 取出列表（原版 ConfigManager.GetEq／GetPet，按存入先后）
static func gear() -> Array:
	ensure_loaded()
	return _gear


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
	var i := s.gear.find_custom(func(e): return is_same(e, rec))
	if i < 0:
		return "不可存放"
	if push_dct(rec) or o_block_bound and (XAlienation.reserved(s, rec) or XAlienation.is_pending(s, rec)):
		return "不可存放"
	s.gear.remove_at(i)
	if o_alien_reset and not XAlienation.mark(rec).is_empty():
		XAlienation.mark(rec).config = {}
	ensure_loaded()
	_gear.append(rec)
	_changed()
	return ""


## 取出一件：按本档重编号（O-待定 开时异化装备另换 uid），放回背包
static func withdraw_gear(s: XState, rec: Dictionary) -> bool:
	ensure_loaded()
	var i := _gear.find_custom(func(e): return is_same(e, rec))
	if i < 0:
		return false
	_gear.remove_at(i)
	rec.erase("instanceId")
	s.register_gear(rec)
	if o_alien_reset and not XAlienation.mark(rec).is_empty():
		var led := XAlienation.ledger(s)
		led.sequence = int(led.sequence) + 1
		XAlienation.mark(rec).uid = "alien-%d" % int(led.sequence)
	s.gear.append(rec)
	_changed()
	return true


## 存入一只宠物（序号）；出战宠物返回 false、不动
static func deposit_pet(s: XState, index: int) -> bool:
	var list := XPets.list(s)
	if index < 0 or index >= list.size() or index == XPets.war_index(s):
		return false
	var pet: Dictionary = list[index]
	XPets.release(s, index)
	ensure_loaded()
	_pets.append(pet)
	_changed()
	return true


static func withdraw_pet(s: XState, pet: Dictionary) -> bool:
	ensure_loaded()
	var i := _pets.find_custom(func(e): return is_same(e, pet))
	if i < 0:
		return false
	_pets.remove_at(i)
	XPets.list(s).append(pet)
	_changed()
	return true


static func _changed() -> void:
	if o_save_now:
		_save()
	else:
		_dirty = true


## XConfig 写盘时一起写（o_save_now 关时照原版的落盘时机）
static func flush_pending() -> void:
	if _dirty:
		_save()


## 同 XGlobalVars：先写临时文件再替换；写盘失败只丢这一次（内存里仍有）
static func _save() -> bool:
	_dirty = false
	var p := path()
	if DirAccess.make_dir_recursive_absolute(p.get_base_dir()) != OK:
		return false
	var temp := p + ".tmp"
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"version": 1, "mode": "xiyou", "gear": _gear, "pets": _pets}))
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	if not ok or DirAccess.rename_absolute(temp, p) != OK:
		DirAccess.remove_absolute(temp)
		return false
	return true
