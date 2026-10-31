class_name XStarWarehouse
extends RefCounted
## 通用仓库（Star_Warehouse：Scene_StarSaveWarehouse 存放、Scene_StarWarehouse 取出；黄金大厅 Map041 EV1「通用仓库管理员」）。
## 跨存档：原版放在 ConfigManager.GetEq／GetPet（配置文件 config.rpgsave），这里另起 <存档目录>/star_warehouse.json（不读 MV 文件），
## 照 XGlobalVars 的写法：按路径只读一次，损坏按空、下次改动整份重写，先写临时文件再替换。
## - 装备：只收背包里的独立装备实例（身上穿着的不在 s.gear 里），备注带 <PushDct> 的不收（画面提示「不可存放」）。存进去是整件实例；
##   取出时原版重新分配编号（$dataWeapons.length），这里去掉 instanceId 再 register_gear 发新号——两个存档各自的 xg:N 会撞号
##   （沙僧 Q1）。异化装备的配置（使用角色、绑定队友、吞器供体编号）照原版原样带走：在别的存档里引用多半失效，开战锁队时卸下。
## - 宠物：XPets 的宠物字典整只存；出战宠物不收（原版点了没有反应）；取出放到宠物列表末尾。
## - 没有容量上限；只有装备、宠物两类。
## - O-待定（优化登记）：o_write_through——原版仓库画面不写盘，要等下一次配置写盘（关设置页等）东西才落到文件里，期间退出游戏就丢；
##   true＝每次存取立即写盘；false＝照原版只在配置写盘时（XConfig._write）一起写。
## - 防旧档复制（存放后不存档就读旧档，旧档里那件还在）照原版不防（用户 2026-10-30 默认甲）。

static var path_override := ""
static var o_write_through := true
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
		return
	for e in d.get("gear", []) if d.get("gear") is Array else []:
		if e is Dictionary and e.has("kind") and e.has("base"):
			_gear.append(e)
	for e in d.get("pets", []) if d.get("pets") is Array else []:
		if e is Dictionary and e.has("enemy"):
			_pets.append(e)


## 测试换路径后重读
static func reset() -> void:
	_loaded_path = "<unloaded>"


static func gear() -> Array:
	ensure_loaded()
	return _gear


static func pets() -> Array:
	ensure_loaded()
	return _pets


## 存放画面的装备列表（$gameParty.armors().concat(weapons())）：背包里的防具在前、武器在后，各自按入手先后
static func carried_gear(s: XState) -> Array:
	return s.gear.filter(func(e): return str(e.kind) == "armor") + s.gear.filter(func(e): return str(e.kind) == "weapon")


static func storable(rec: Dictionary) -> bool:
	return not str(rec.get("note", "")).contains("<PushDct")


## onItemOk（存放·装备）：<PushDct> 返回 false（画面弹「不可存放」）；其余从背包移走、进仓库
static func deposit_gear(s: XState, rec: Dictionary) -> bool:
	if not storable(rec):
		return false
	var i := -1
	for k in s.gear.size():
		if is_same(s.gear[k], rec):
			i = k
	if i < 0:
		return false
	s.gear.remove_at(i)
	gear().append(rec)
	_changed()
	return true


## onItemOk（取出·装备）：发新实例编号、放回背包
static func withdraw_gear(s: XState, i: int) -> bool:
	if i < 0 or i >= gear().size():
		return false
	var rec: Dictionary = gear()[i]
	gear().remove_at(i)
	rec.erase("instanceId")
	s.register_gear(rec)
	s.gear.append(rec)
	_changed()
	return true


## onItemOk（存放·宠物）：出战宠物不收（原版点了没有反应）；其余移出宠物列表（同放生的序号修正）
static func deposit_pet(s: XState, i: int) -> bool:
	var list := XPets.list(s)
	if i < 0 or i >= list.size() or i == XPets.war_index(s):
		return false
	var pet: Dictionary = list[i]
	XPets.release(s, i)
	pets().append(pet)
	_changed()
	return true


## onItemOk（取出·宠物）：放到宠物列表末尾
static func withdraw_pet(s: XState, i: int) -> bool:
	if i < 0 or i >= pets().size():
		return false
	XPets.list(s).append(pets()[i])
	pets().remove_at(i)
	_changed()
	return true


static func _changed() -> void:
	_dirty = true
	if o_write_through:
		flush()


## 配置写盘（XConfig._write）时一起写：o_write_through 关时照原版只在这里落盘
static func flush() -> bool:
	if not _dirty:
		return true
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
	_dirty = false
	return true
