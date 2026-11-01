class_name XYunshangOrders
extends RefCounted
## 【cc·白龙_12·未经审查】云裳的订单账本与天衣铺二期（installNativeYunshangRuntime.js 第 94～200、235～244、554～584 行）：
## 制作、领取、回合进度、不朽天丝奖励、角色进阶。参照 yunshang_probe 的 p8（tests/fixtures/yunshang_oracle.json），专项 xiyou_yunshang_shop。
## - 账本是存档目录旁的独立文件 yunshang_orders_v1.json（原版 StorageManager.localFileDirectoryPath()），整份写：先写临时文件再改名。
##   {version 2, profiles {编号: {journal, order, clears, bonusClears, stage, recruited}}, legacyProfiles {旧档身份: 编号}}。
##   存档里只记本档的编号 flags._yunProfile 与已重放到第几条 flags._yunSeq（原版 $gameSystem._yunProfile／_yunSeq）。
##   改账本一律走 transaction：复制整份、改本档那条、写盘、再 replay——从 _yunSeq 起把日志补到当前存档：
##   物品增减 delta、发天衣 grant（按 _yunUid 已有就不发）、移除 remove（按 _yunUid，找不到再按记下的实例号；穿着的先卸下）；
##   最后把云裳的进阶次数设成账本的 stage 并同步技能。所以开工后读早先的档，天丝照扣、订单还在，不能重抽；领取后读档天衣照发。
## - 编号：原版 Date.now＋Math.random，重制取 8 字节随机（Crypto），不碰游戏的随机数。
## - 本档还没有编号时（新局、旧档）：照原版在第一次要用账本时建一条，旧档按「读档身份」（第几格＋存档文件的 sha256）对上已有的那条，
##   同一个旧档读几次都是同一条。原版新局开局就建；重制等到第一次用（制作、领取、进阶、不朽天丝、读档重放）才写盘，测试不平白写文件。
##   **重制补的迁移**：新建的那条 stage 取存档里云裳当前的进阶次数（XAdvance.rank），旧档里已进阶的不归零（原版建条时一律 0）。
## - 账本读写出错（文件坏了、版本不对、本档编号在账本里找不到）：天衣铺首页换兜底页；不朽天丝与回合进度停下，第一次出错时提示
##   「云裳订单记录不可用，制作/进阶及天丝奖励暂停」，本局之后不再写（原版 optionalJournal、Y._storageError；新局、读档重放成功时清掉）。
## - 制作 Y.submit：战斗外、没有订单、制作池非空（按等级与进阶开放，C.robes）、不朽天丝 2942 至少 15 份；随机选一件（Math.randomInt，重制取装备随机数 XGear.roll），
##   底子是那件天衣，八项能力换成最高需求等级的布衣模板（Y.equipmentCap／model：需求等级最高、带 <Prefixes> 的 1 号防具类型身体装备，
##   同级取编号小的＝4282 如来的袈裟）的、特性清空，属性浮动用模板的 Random Variance；词缀表还是天衣自己的（空）——原版往备注里补了模板的
##   <Prefixes>，但 DreamX 的词缀表在读数据库时就解析好了，补在备注里不生效（参照 roll 0.1 也没掷出词缀）。掷完名字改回天衣名、记 _yunUid；
##   开工时就排好镶嵌孔（XOrbs.layout，同一个实例号算法），领取不重排。扣 15 份天丝、记订单 {id, spec, progress 0, roundTokens []}。
## - 回合进度 Y.progress：云裳在出战成员里时，每回合末（endTurn 包装，同一回合只记一次）用「本场编号:敌群回合数」记 1 格，满 10 格可领；同一个 token 不重记。
## - 领取 Y.claim：满 10 格；把订单那件天衣发进背包（grant）、清订单。
## - 不朽天丝（endBattle 包装，胜利、每场一次）：本场是不朽的未知战斗——地图在 C.unknownBattles、敌群在其中，来源地图在 immortalOrigins；
##   没记来源时 152／176 用 Leviathan 记的来源（XState.unknown_origin），再没有就看 unpaired 或难度变量 107 在 legacyDifficulty 里。
##   clears＋1、天丝＋1；云裳出战且学了天丝成锦 10280 时 bonusClears＋1，偶数次多给 1 份。来源地图 Game_Map.setup 包装记在 flags._yunUnknownOrigin。
## - 进阶 Y.advance：C.advance＝[{35 级, 天衣 3 件, 人道意志碎片 2530×50}, {50 级, 9 件, ×188}]；只认背包里的天衣（穿着的要先卸下）；
##   扣碎片、移除所选天衣、stage＋1，提示「云裳完成第N次进阶」。不走进阶表那一行的学技能、扣金钱（原版 onConfirmOk 包装不调旧的），技能由同步按等级与进阶学。
## - 失去天衣（gainItem 包装，第 200～204 行）：带 _yunUid 的天衣被直接失去（商店卖出、存进仓库、分解，走 XState.lose_gear）时记一条 remove，
##   读领取前的档时重放发了再移除，不能再领一次；穿上卸下、按底子扣（事件、合成材料、星级仓库）照原版不记。参照 p8.lose。
## 招募仍按存档旗标（一期），不进账本。

const FILE := "yunshang_orders_v1.json"
const SILK := 2942
const SHARD := 2530
const COST := 15
const PROGRESS := 10
const PROFILE_FLAG := "_yunProfile"
const SEQ_FLAG := "_yunSeq"
const ORIGIN_FLAG := "_yunUnknownOrigin"
const SILK_SKILL := 10280
## C.robes：[编号, 名字, 等级, 进阶]
const ROBES := [[7920, "山河作骨", 35, 0], [7921, "百厄成锦", 35, 0], [7922, "赊月偿星", 35, 0], [7923, "不渡黄泉", 40, 1], [7924, "逆命换锦", 40, 1],
	[7925, "千军入袖", 40, 1], [7926, "空袖藏星", 45, 1], [7927, "九曲回针", 45, 1], [7928, "六衡裁身", 45, 1], [7929, "寸光留仙", 50, 2],
	[7930, "孤灯照众", 50, 2], [7931, "同袍换日", 50, 2], [7932, "一身两世", 55, 2], [7933, "万法同裳", 55, 2], [7934, "七曜流霞", 55, 2]]
const ADVANCE := [{"level": 35, "robes": 3, "shards": 50}, {"level": 50, "robes": 9, "shards": 188}]
## C.unknownBattles：地图 → {troops, immortalOrigins, legacyDifficulty, unpaired}
const UNKNOWN := {141: {"troops": [577, 578, 579, 580, 581, 582], "immortal": [168], "legacy": [2, 3]},
	152: {"troops": [454, 455], "immortal": [38], "legacy": [1]},
	160: {"troops": [470, 471, 472, 473, 474], "immortal": [51], "legacy": [2, 3]},
	161: {"troops": [544, 545, 546, 547, 548], "immortal": [53], "legacy": [2, 3]},
	162: {"troops": [539, 540, 541, 542], "immortal": [57, 59], "legacy": [2, 3]},
	176: {"troops": [570, 571, 572, 573, 574, 575], "immortal": [165, 108], "legacy": [2, 3]},
	177: {"troops": [584, 585, 586, 587, 588, 589], "immortal": [174, 175], "unpaired": true},
	210: {"troops": [724, 725, 726, 727, 728, 729], "immortal": [211, 216], "unpaired": true},
	223: {"troops": [647, 648, 649, 650, 651, 652, 653, 654, 655, 656, 657, 658, 659], "immortal": [184], "unpaired": true}}
const STORAGE_TEXT := "云裳订单记录不可用，制作/进阶及天丝奖励暂停"

## 测试改路径；空则跟 XSave.dir()
static var path_override := ""
static var _loaded_path := "<unloaded>"
static var _ledger = null
## 本局的旧档身份与出错原因（按 XState 对象记：换了局就清，等于原版 setupNewGame 清 legacyIdentity／_storageError）
static var _state_ref: WeakRef
static var _legacy := ""
static var storage_error := ""
## 上一次失败的原因（原版 throw 的 message）
static var error := ""
## 本场编号（startBattle 包装里 battle=uuid）、本场已发过不朽天丝、上次记进度的回合
static var battle_id := ""
static var _rewarded := false
static var _round_end := -1


static func path() -> String:
	return path_override if path_override != "" else XSave.dir().path_join(FILE)


static func uuid() -> String:
	return Crypto.new().generate_random_bytes(8).hex_encode()


static func _for(s: XState) -> void:
	if _state_ref == null or _state_ref.get_ref() != s:
		_state_ref = weakref(s)
		_legacy = ""
		storage_error = ""


static func _fail(text: String):
	error = text
	return null


# ---- 账本文件 ----
## loadLedger：读一次后留在内存（换了路径重读）；坏了、版本不对返回 null（error 记原因）
static func load_ledger():
	var p := path()
	if p == _loaded_path and _ledger != null:
		return _ledger
	var next = {"version": 2, "profiles": {}, "legacyProfiles": {}}
	if FileAccess.file_exists(p):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(p)) != OK or not json.data is Dictionary:
			return _fail("云裳订单记录损坏")
		next = json.data
		if int(next.get("version", 0)) != 1 and int(next.get("version", 0)) != 2:
			return _fail("云裳订单记录版本不兼容")
		if not next.get("profiles") is Dictionary:
			return _fail("云裳订单记录损坏")
	next.version = 2
	if not next.get("legacyProfiles") is Dictionary:
		next.legacyProfiles = {}
	next.erase("active")
	_ledger = next
	_loaded_path = p
	return _ledger


## saveLedger：先写临时文件再改名
static func save_ledger(next: Dictionary) -> bool:
	var p := path()
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var tmp := "%s.%s.tmp" % [p, uuid()]
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		_fail("云裳订单记录无法写入")
		return false
	f.store_string(JSON.stringify(next))
	f.close()
	if DirAccess.rename_absolute(tmp, p) != OK:
		DirAccess.remove_absolute(tmp)
		_fail("云裳订单记录无法写入")
		return false
	_ledger = next
	_loaded_path = p
	return true


## Y.reloadJournal：丢掉内存里的，下次重读文件
static func reload() -> void:
	_ledger = null
	_loaded_path = "<unloaded>"


static func _new_profile(s: XState) -> Dictionary:
	return {"journal": [], "order": null, "clears": 0, "stage": XAdvance.rank(s, XYunshang.ACTOR), "recruited": false}


## profile()：本档那一条；没有编号就新建（旧档按读档身份对上）。编号在、账本里没有＝记录缺失，返回 null
static func profile(s: XState):
	_for(s)
	var l = load_ledger()
	if l == null:
		return null
	var id := str(s.flags.get(PROFILE_FLAG, ""))
	if id != "" and not (l.profiles as Dictionary).has(id):
		return _fail("此存档的云裳订单记录缺失；请恢复对应订单文件，暂不可制作或进阶")
	if id == "":
		id = str(l.legacyProfiles.get(_legacy, "")) if _legacy != "" else ""
		if id == "":
			id = uuid()
			var n: Dictionary = l.duplicate(true)
			n.profiles[id] = _new_profile(s)
			if _legacy != "":
				n.legacyProfiles[_legacy] = id
			if not save_ledger(n):
				return null
		if not (_ledger.profiles as Dictionary).has(id):
			return _fail("云裳旧档绑定记录损坏")
		s.flags[PROFILE_FLAG] = id
	return _ledger.profiles[id]


## 存档里的数读回是浮点：按 _yunUid 找身上与背包里的天衣
static func find_uid(s: XState, uid: String) -> Dictionary:
	if uid == "":
		return {}
	for e in s.gear:
		if str(e.get("_yunUid", "")) == uid:
			return e
	for a in s.actors.values():
		for e in a.equip_list():
			if str(e.get("_yunUid", "")) == uid:
				return e
	return {}


## removeUid：按 _yunUid（找不到再按记下的实例号且底子相同）移除；穿着的先卸下
static func remove_uid(s: XState, uid: String, instance: String, base_id: int) -> void:
	var item := find_uid(s, uid)
	if item.is_empty() and instance != "":
		for e in s.gear:
			if str(e.get("instanceId", "")) == instance and int(e.get("base", 0)) == base_id:
				item = e
				e._yunUid = uid
				break
	if item.is_empty():
		return
	for a in s.actors.values():
		for slot in range(a.equips.size()):
			if a.equips[slot] is Dictionary and is_same(a.equips[slot], item):
				if not XEquipment.change(s, a, slot, null):
					a.equips[slot] = null
					a.refresh_passive()
	var i := s.gear.find_custom(func(e): return is_same(e, item))
	if i >= 0:
		s.gear.remove_at(i)


## grantSpec：同一个 _yunUid 已有就不发；新实例号
static func grant_spec(s: XState, spec: Dictionary) -> void:
	if not find_uid(s, str(spec.get("_yunUid", ""))).is_empty():
		return
	var n := spec.duplicate(true)
	n.erase("instanceId")
	s.register_gear(n)
	s.gear.append(n)


## replay：从 _yunSeq 起把日志补到当前存档，再把云裳的进阶次数设成账本的
static func replay(s: XState) -> bool:
	var p = profile(s)
	if p == null:
		return false
	var journal: Array = p.journal
	for j in range(int(s.flags.get(SEQ_FLAG, 0)), journal.size()):
		var op: Dictionary = journal[j]
		if op.has("delta"):
			s.gain_item(int(op.item), int(op.delta))
		if op.get("grant") is Dictionary:
			grant_spec(s, op.grant)
		if op.has("remove"):
			remove_uid(s, str(op.remove), str(op.get("instance", "")), int(op.get("baseId", 0)))
		s.flags[SEQ_FLAG] = j + 1
	if s.actors.has(XYunshang.ACTOR):
		if int(p.stage) > 0:
			s.actor_advance[XYunshang.ACTOR] = int(p.stage)
		else:
			s.actor_advance.erase(XYunshang.ACTOR)
		XYunshang.sync(s.actor(XYunshang.ACTOR))
	return true


## transaction：复制整份、改本档那条、写盘、重放
static func transaction(s: XState, fn: Callable) -> bool:
	if profile(s) == null:
		return false
	var n: Dictionary = _ledger.duplicate(true)
	fn.call(n.profiles[str(s.flags[PROFILE_FLAG])])
	return save_ledger(n) and replay(s)


## optionalJournal：本局出过错就不再写；这次出错记下、提示一次
static func _optional(s: XState, fn: Callable) -> void:
	_for(s)
	if storage_error != "":
		return
	error = ""
	if not bool(fn.call()) and error != "":
		storage_error = error
		XToast.show_text(STORAGE_TEXT)


## Y.ledger：本档那条的副本（null＝不可用）
static func ledger(s: XState):
	var p = profile(s)
	return p.duplicate(true) if p != null else null


static func order(s: XState):
	var p = profile(s)
	return p.order if p != null else null


# ---- 读档 ----
## extractSaveContents 包装：记下旧档身份（第几格＋文件的 sha256），重放；出错只记下、普通读档照常。
## 存档里没有编号、账本里也没有这个旧档身份时不新建（原版这里会建一条并写进 $gameSystem；重制的新局要到第一次用账本才建，
## 读这种档时什么都不用补，存档读回再存一字不差）
static func after_load(s: XState, identity: String) -> void:
	_for(s)
	_legacy = identity
	error = ""
	if str(s.flags.get(PROFILE_FLAG, "")) == "":
		var l = load_ledger()
		if l == null or not (l.legacyProfiles as Dictionary).has(identity):
			storage_error = "" if l != null else error
			return
	storage_error = "" if replay(s) else error
	if storage_error != "" and s.actors.has(XYunshang.ACTOR):
		XYunshang.sync(s.actor(XYunshang.ACTOR))


static func identity(slot: int, text: String) -> String:
	return "legacy-slot:%d:%s" % [slot, text.sha256_text()]


# ---- 制作、领取 ----
## Y.pool：按等级与进阶开放的天衣
static func pool(a: XActor) -> Array:
	var st := XYunshang.stage(a)
	return ROBES.filter(func(r): return a.level >= int(r[2]) and st >= int(r[3]))


## Y.equipmentCap：带 <Prefixes>、有需求等级的 1 号防具类型身体装备里最高的需求等级（编号 8001 以前）；
## model：其中编号在天衣之前、需求等级最高的（同级取编号小的；没有时 4282 C.ordinaryClothModel）
static var _model := -1
static var _cap := 1
static func model() -> int:
	if _model < 0:
		_model = 4282
		var best := -1
		var re := RegEx.create_from_string("(?i)<req_level:\\s*(\\d+)>")
		var pre := RegEx.create_from_string("(?i)<Prefixes>")
		for id in range(1, 8001):
			var r := XDB.rec("Armors", id)
			if r.is_empty() or int(r.get("etypeId", 0)) != 4 or int(r.get("atypeId", 0)) != 1:
				continue
			var m := re.search(str(r.get("note", "")))
			if m == null or pre.search(str(r.note)) == null:
				continue
			_cap = maxi(_cap, int(m.get_string(1)))
			if id < XYunshang.ROBE_FIRST and int(m.get_string(1)) > best:
				best = int(m.get_string(1))
				_model = id
	return _model


## submit：成功返回 ""，否则返回原因
static func submit(s: XState) -> String:
	error = ""
	if not replay(s):
		return error
	var p = profile(s)
	var a := s.actor(XYunshang.ACTOR)
	var list := pool(a)
	if p.order != null:
		return "请先完成并领取当前订单"
	if list.is_empty():
		return "35级才能解锁首批制作池"
	if s.item_count(SILK) < COST:
		return "需要15份不朽天丝"
	var r: Array = list[mini(floori(XGear.roll(s) * list.size()), list.size() - 1)]
	var tpl := XGear.template("armor", model())
	var locked := XGear.template("armor", int(r[0]))
	locked.params = (tpl.params as Array).duplicate()
	locked.traits = []
	var variance = tpl.get("meta", {}).get("Random Variance")
	if variance != null:
		locked.meta["Random Variance"] = variance
	else:
		locked.meta.erase("Random Variance")
	var spec := XGear.roll_item(locked, s)
	spec.name = str(r[1])
	spec.baseName = str(r[1])
	spec._yunUid = uuid()
	spec._yunRobeKey = int(r[0]) - XYunshang.ROBE_FIRST
	spec._yunEquipmentCap = _cap
	spec.instanceId = "xg:%d" % s.next_gear_id
	XOrbs.layout(spec, s.orb_seed)
	spec.erase("instanceId")
	var ok := transaction(s, func(n):
		n.journal.append({"item": SILK, "delta": -COST})
		n.order = {"id": uuid(), "spec": spec, "progress": 0, "roundTokens": []})
	return "" if ok else error


static func claim(s: XState) -> String:
	error = ""
	if not replay(s):
		return error
	var p = profile(s)
	if p.order == null or int(p.order.progress) < PROGRESS:
		return "订单尚未完成"
	var result: Dictionary = p.order.spec.duplicate(true)
	var ok := transaction(s, func(n):
		n.journal.append({"grant": result, "order": n.order.id})
		n.order = null)
	return "" if ok else error


## Y.progress：记一格（已满、同一个 token、没订单返回 false）；账本不可用返回 null
static func progress(s: XState, token: String):
	var p = profile(s)
	if p == null:
		return null
	if p.order == null or int(p.order.progress) >= PROGRESS or (p.order.roundTokens as Array).has(token):
		return false
	return transaction(s, func(n):
		n.order.roundTokens.append(token)
		n.order.progress = mini(PROGRESS, int(n.order.progress) + 1))


# ---- 战斗 ----
static func start_battle() -> void:
	battle_id = uuid()
	_rewarded = false
	_round_end = -1


## endTurn 包装：云裳在出战成员里时记 1 格（同一回合一次）。本档还没有账本编号就不可能有订单，不去建（原版这里会建一条空的）
static func end_turn(logic) -> void:
	var s: XState = logic.state
	if s == null or _round_end == int(logic.turn) or str(s.flags.get(PROFILE_FLAG, "")) == "":
		return
	_round_end = int(logic.turn)
	if logic.actors.any(func(a): return XYunshang.own(a)):
		_optional(s, func(): return progress(s, "%s:%d" % [battle_id, int(logic.turn)]) != null)


## Game_Map.setup 包装：去未知战斗的地图时记上一张图（同图重进保留），去别处清掉
static func on_map_setup(s: XState, from: int, to: int) -> void:
	if not UNKNOWN.has(to):
		s.flags.erase(ORIGIN_FLAG)
	elif from != to:
		s.flags[ORIGIN_FLAG] = from


## Y.isImmortalClear
static func immortal_clear(s: XState, troop: int) -> bool:
	var route: Dictionary = UNKNOWN.get(s.map_id, {})
	if route.is_empty() or not (route.troops as Array).has(troop):
		return false
	var origin = s.flags.get(ORIGIN_FLAG)
	if origin == null and (s.map_id == 152 or s.map_id == 176):
		origin = s.unknown_origin
	if origin != null:
		return (route.immortal as Array).has(int(origin))
	return bool(route.get("unpaired", false)) or (route.get("legacy", []) as Array).has(int(s.variables.get(107, 0)))


## endBattle 包装（原 endBattle 之前）：胜利且是不朽的未知战斗，每场一次给不朽天丝
static func end_battle(logic, result: int) -> void:
	var s: XState = logic.state
	if s == null or result != 0 or _rewarded or not immortal_clear(s, int(logic.troop_id)):
		return
	_rewarded = true
	var cloud = null
	for a in logic.actors:
		if XYunshang.own(a):
			cloud = a
	var bonus: bool = cloud != null and (cloud.skill_ids as Array).has(SILK_SKILL)
	_optional(s, func(): return transaction(s, func(p):
		p.clears = int(p.clears) + 1
		if bonus:
			p.bonusClears = int(p.get("bonusClears", 0)) + 1
		p.journal.append({"item": SILK, "delta": 1 + (1 if bonus and int(p.bonusClears) % 2 == 0 else 0)})))


## gainItem 包装：这一件被直接失去时记移除（transaction 的重放会把它从背包拿掉）；账本不可用返回 false
static func lost(s: XState, item: Dictionary) -> bool:
	error = ""
	var uid := str(item.get("_yunUid", ""))
	return uid != "" and transaction(s, func(p):
		p.journal.append({"remove": uid, "instance": str(item.get("instanceId", "")), "baseId": int(item.get("base", 0))}))


# ---- 进阶 ----
## owned()：背包里的天衣（穿着的不算），照 $gameParty.armors() 的次序（YEP independentItemSort：按底子，同底子按实例先后，同 XItemScene.bag_gear）
static func owned(s: XState) -> Array:
	var list := s.gear.filter(func(e): return str(e.get("kind", "")) == "armor" and int(e.get("base", 0)) >= XYunshang.ROBE_FIRST and int(e.get("base", 0)) < XYunshang.ROBE_END)
	list.sort_custom(func(a, b): return [int(a.base), XItemScene.instance_no(a)] < [int(b.base), XItemScene.instance_no(b)])
	return list


## Y.robeLabel：「名字　编号N」（N＝在背包天衣里的第几件）
static func robe_label(s: XState, item: Dictionary) -> String:
	var list := owned(s)
	return "%s　编号%d" % [str(item.get("name", "")), list.find_custom(func(e): return is_same(e, item)) + 1]


## Y.advanceRequirements：够了返回 ""
static func requirements(s: XState, a: XActor) -> String:
	var st := XYunshang.stage(a)
	if st >= ADVANCE.size():
		return "已完成两次进阶"
	var req: Dictionary = ADVANCE[st]
	if a.level < int(req.level):
		return "等级不足：需要%d级" % int(req.level)
	if s.item_count(SHARD) < int(req.shards):
		return "人道意志碎片不足：需要%d份" % int(req.shards)
	if owned(s).size() < int(req.robes):
		return "背包天衣不足：需要%d件（已装备天衣须先卸下）" % int(req.robes)
	return ""


static func needed(a: XActor) -> int:
	var st := XYunshang.stage(a)
	return int(ADVANCE[st].robes) if st < ADVANCE.size() else 0


## Y.advance(selected)：成功返回 ""
static func advance(s: XState, selected: Array) -> String:
	error = ""
	if not replay(s):
		return error
	var a := s.actor(XYunshang.ACTOR)
	var st := XYunshang.stage(a)
	if st >= ADVANCE.size() or a.level < int(ADVANCE[st].level):
		return "等级不足或已完成两次进阶"
	var req: Dictionary = ADVANCE[st]
	if selected.size() != int(req.robes):
		return "天衣数量不符"
	var allowed := owned(s)
	var seen := []
	for i in selected:
		if not allowed.any(func(e): return is_same(e, i)) or seen.any(func(e): return is_same(e, i)):
			return "请选择背包中的不同天衣，已装备天衣须先卸下"
		seen.append(i)
	if s.item_count(SHARD) < int(req.shards):
		return "人道意志碎片不足"
	for i in selected:
		if str(i.get("_yunUid", "")) == "":
			i._yunUid = uuid()
	var ok := transaction(s, func(p):
		p.journal.append({"item": SHARD, "delta": -int(req.shards)})
		for i in selected:
			p.journal.append({"remove": str(i._yunUid), "instance": str(i.get("instanceId", "")), "baseId": int(i.base)})
		p.stage = st + 1)
	if not ok:
		return error
	XToast.show_text("云裳完成第%d次进阶" % (st + 1), true)
	return ""
