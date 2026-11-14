extends RefCounted
## 天启篇测试共用夹具（存档门面 cc/save-rng-facade；车道须知短表「测试怎么写才算数」①②③）。用法：
##   const Kit := preload("res://tests/lib/tq_save_kit.gd")
##   var kit := Kit.new("xiyou_tianqi_save")   # 存档、配置都指到 user://test_<名>/，不碰本机真档和真设置
##   var s := Kit.new_game()                   # 走 XTianqi.start_new_game 真开局，不手写 flags["tianqi"]
##   var back := kit.roundtrip()               # XSave.save 真写盘 → XSave.load_slot 真读档（经过 JSON，走全两处读档入口）
##   kit.legacy(["drop"])                      # 改存档文件：删掉 flags.tianqi 下这些键，模拟老档
##   kit.reload_same(func(st): return 掷一次(st)) # 存 → 读 → 掷，再读 → 掷，两次结果相同
##   kit.each_seed(func(seed): ...)            # 多种子循环（默认三个）
##   kit.teardown()                            # 收尾：删临时目录里的文件、还原各 override
## 不加 class_name：只给测试 preload，不进游戏代码。

const SLOT := 1
const SEEDS := [11, 20261114, 777777]

var dir := ""
var _config := ""


func _init(test_name: String) -> void:
	dir = "user://test_" + test_name
	_config = dir.path_join("config.json")
	DirAccess.make_dir_recursive_absolute(dir)
	XSave.dir_override = dir
	XConfig.path_override = ProjectSettings.globalize_path(_config)
	XConfig._loaded_path = "<unloaded>"
	XMessageBox.auto = true


func teardown() -> void:
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			d.remove(f)
	XSave.dir_override = ""
	XConfig.path_override = ""
	XConfig._loaded_path = "<unloaded>"


## 真开局：五名弱档角色入队、选好线、开场跑完（同 xiyou_tianqi_seed_fix 的 _state）
static func new_game(difficulty := "jianxian", line := "war", orb_seed := -1) -> XState:
	var lineup := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id)).slice(0, 5)
	var s := XTianqi.start_new_game(3, difficulty, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	if orb_seed >= 0:
		s.orb_seed = orb_seed
	s.map_id = 0
	s.set_variable(20, 3)
	XState.current = s
	s.flags.tianqi["line"] = line
	XTianqiLine.progress(line, s)["stage"] = XTianqiLine.stage_done(line)
	return s


func save(slot := SLOT) -> bool:
	return XSave.save(slot)


func reload(slot := SLOT) -> XState:
	return XState.current if XSave.load_slot(slot) else null


## 存当前档再读回来（XState.current 换成读回来的那份）
func roundtrip(slot := SLOT) -> XState:
	return reload(slot) if save(slot) else null


## 存档文件原文（字典）
func raw(slot := SLOT) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(slot)))
	return d if d is Dictionary else {}


## 改存档文件：fn(存档字典) 原地改，再按正式写法写回
func edit_raw(fn: Callable, slot := SLOT) -> void:
	var d := raw(slot)
	fn.call(d)
	XSave._write(XSave.path(slot), d)


## 模拟老档：删掉存档文件里 flags.tianqi 下这些键（嵌套用「分区/键」）
func legacy(keys: Array, slot := SLOT) -> void:
	var d := raw(slot)
	var tq = d.get("flags", {}).get("tianqi")
	if tq is Dictionary:
		for k in keys:
			var parts := str(k).split("/")
			if parts.size() == 2 and tq.get(parts[0]) is Dictionary:
				tq[parts[0]].erase(parts[1])
			else:
				tq.erase(str(k))
	XSave._write(XSave.path(slot), d)


## 存一次，读两次各掷一遍：两次结果相同才算（roll(state) 返回可比较的值）
func reload_same(roll: Callable, slot := SLOT) -> bool:
	if not save(slot):
		return false
	var a = roll.call(reload(slot))
	var b = roll.call(reload(slot))
	return a == b


## 多种子循环：fn(seed) 的结果按种子收集
func each_seed(fn: Callable, seeds := SEEDS) -> Array:
	var out := []
	for sd in seeds:
		out.append(fn.call(int(sd)))
	return out
