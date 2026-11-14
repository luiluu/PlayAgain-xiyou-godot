class_name XDemonCrown
extends RefCounted
## 【cc·八戒·未经审查】成长装备期二b：魔冠「"头顶"」7940（installNativeDemonCrownRuntime，冻结 v0.28 main.js 第 151 行装载，在心钢、狂妄外层）。
## 参照 demon_crown_probe（tests/fixtures/demon_crown_oracle.json），专项 xiyou_demon_crown。
## - 成长 b（0～1000）存在独立账本 crown_progress_v1.json（存档目录旁，原版 StorageManager.localFileDirectoryPath()），整份写：先写临时文件再改名。
##   {version 1, profiles {编号: {revision, items {uid: {spec, bonus, removed}}, battles {b:序号: …}, worldDeaths {}}}, legacy {旧档身份: 编号}}。
##   存档只记本档编号 flags._codexCrownProfile、遭遇序号 _codexCrownEncounterSeq、战斗外死亡序号 _codexCrownWorldDeathSeq。
##   改账本一律走 transaction（复制、改本档那条、写盘、replay）：账本里每件按 uid 发到存档（已有就只盖成长）、removed 的移除。
##   所以读早先的档，成长、掉落、卖掉都照账本，不能回滚；同一遭遇序号重打不重掷（开战掷点记在账本），换了敌群／地图那一场不算。
## - 实例：名字、底名、说明、图标 290000、品质 12（备注里有 14／15 取大的）、成长行「成长：八项全属性＋N%」、八项 code21 特性 ×(1＋b/100)；
##   账本不可用时特性 1，提示一次（原版 fail）。
## - 胜利：开战时穿着、活着、在出战里，结束时仍活着、仍在出战、穿的还是这件、中途没换过装备的，b ＋ (1 − b/1000)；失败／逃跑不涨。
## - 死亡（addNewState 死亡）：战斗中按「角色:第几次:uid」、战斗外按世界序号各记一次，b 减半。
## - 掉落：Map162、敌群 539～542、不朽的未知战斗（XYunshangOrders.immortal_clear），开战掷一次，胜利且 <3% 发一件，提示「获得了"头顶"！」。
## - 得到数据库那件 7940（事件、商店）改由账本发；带 uid 的被直接失去（卖出、存仓库、分解）记 removed。按底子扣（事件）不记，原版独立物品留在
##   $dataArmors 里、重放找得到就不重发，重制用 flags._codexCrownKnown 记「本档建过的 uid」顶替。
## 编号：原版 crypto 16 字节，重制 Crypto 16 字节。开战掷点：原版 Math.random，重制取战斗规则流。
## 图标 290000 画整张 Codex_DemonCrown（icon_texture，XUI／大图标接）；说明行小数按 D.display 取整（desc_rows，RJO.HE.getDescParams 包装）；
## replay 后清战力缓存（CodexCombatPower.clearCache）。CodexZones.invalidate：五乘区不移植，不用做。

const ARMOR := 7940
const ICON := 290000
const LIMIT := 1000.0
const DROP_RATE := 0.03
const DROP_MAP := 162
const DROP_TROOPS := [539, 540, 541, 542]
const FILE := "crown_progress_v1.json"
const UID := "_codexCrownUid"
const BONUS := "_codexCrownBonus"
const PROFILE_FLAG := "_codexCrownProfile"
const SEQ_FLAG := "_codexCrownEncounterSeq"
const WORLD_FLAG := "_codexCrownWorldDeathSeq"
const KNOWN_FLAG := "_codexCrownKnown"
const NAME := "\"头顶\""
const DESCRIPTION := "神武\n欲加冕成王，必承其重"
const STORAGE_TEXT := "\"头顶\"成长记录暂不可用，请恢复对应成长记录后重开游戏"
const DROP_TEXT := "获得了\"头顶\"！"

## O-待定-6：账本压缩（Kyo 2026-11-14，存档与缓存清理 ②）：原版每场战斗在账本里留一行明细、永不删，开战、结算各整份重写一次，
## 长期穿着头顶挂机的档账本只增不减（每场约 157 字节）、每场两次整份读写。true（默认）：
## - 已结算的场次折进水位 battlesDone：序号小于水位、又没有明细行的，一律当「已结算、没人倒下」（读旧档重打同一场照样不涨、不重掷掉落）；
##   有人倒下过的场次留一行最小的 {settled, deaths}（重打时倒下过的那几次不再减半）；没结算的行原样留着。成长在 items[uid].bonus，不动。
## - 开战不写盘：这一场的行先留在内存（battle.row），结算时连同结果一次写进账本；中途有人倒下要记减半时提前写。
##   与原版的差别只有一种情况：开战后没人倒下就被杀进程——原版留下一行未结算（下次同一场沿用当时的掷点和穿戴），现在等于这一场没打过。
## false：不折叠、开战照写（原版写法）。已经折叠过的账本关掉开关后水位照认（不会因此能重刷），只是不再继续折。
## 账本 version 仍是 1：退回旧补丁也读得了（旧代码不认水位，折掉的场次读旧档重打会被当成新的一场）。
static var COMPACT := true
const DONE := "battlesDone"

## 测试改路径；空则跟 XSave.dir()
static var path_override := ""
static var _loaded_path := "<unloaded>"
static var _ledger = null
static var _state_ref: WeakRef
static var _legacy := ""
static var storage_error := ""
static var error := ""
static var _mutating := false
## 本场：{key, ordinal, wears [{actor, uid, valid}], serial {角色号: 次数}, same, finished, row}；没有为 null。
## row＝开战时建好、还没写进账本的那一行（COMPACT）；已在账本里或是重打旧场次时为 null
static var battle = null


static func path() -> String:
	return path_override if path_override != "" else XSave.dir().path_join(FILE)

static func uuid() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

static func _for(s: XState) -> void:
	if _state_ref == null or _state_ref.get_ref() != s:
		_state_ref = weakref(s)
		_legacy = ""
		storage_error = ""
		battle = null

static func _fail(text: String):
	error = text
	return null


# ---- 实例 ----
static func base_id(item) -> int:
	return int(item.get("base", item.get("id", 0))) if item is Dictionary and not item.is_empty() else 0

static func is_gear(item) -> bool:
	return item is Dictionary and not item.is_empty() and (base_id(item) == ARMOR or str(item.get("note", "")).to_lower().contains("<codexdemoncrown>"))

static func bonus(item) -> float:
	return clampf(float(item.get(BONUS, 0)) if item is Dictionary else 0.0, 0.0, LIMIT)

## D.next：b ＋ (1 − b/1000)
static func next(b: float) -> float:
	b = clampf(b, 0.0, LIMIT)
	return b + (1.0 - b / LIMIT)

## D.display：Math.round
static func display(v: float) -> String:
	return str(floori(v + 0.5))

## CodexQualityIcons demonCrownArt：图标 290000 画整张 img/system/Codex_DemonCrown（1254×1254），按格子大小平滑缩放
static var _icons := {}
static func icon_texture(size := 32) -> AtlasTexture:
	if not _icons.has(size):
		var p := XDB.img_path("system", "Codex_DemonCrown")
		if p == "":
			return null
		var img: Image = (load(p) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
		var a := AtlasTexture.new()  # XUI.icon_texture 要 AtlasTexture（大图标按 region 取）
		a.atlas = ImageTexture.create_from_image(img)
		a.region = Rect2(0, 0, size, size)
		_icons[size] = a
	return _icons[size]

## RJO.HE.getDescParams 包装：先 describe，算出的行里带小数的数字按 D.display 取整（XHelpCard.desc_params 调）
static func desc_rows(item: Dictionary, rows: Array) -> void:
	var dec := RegEx.create_from_string("[-+]?\\d+\\.\\d+")
	for r in rows:
		var t := str(r[0])
		var out := ""
		var at := 0
		for m in dec.search_all(t):
			out += t.substr(at, m.get_start() - at) + display(m.get_string().to_float())
			at = m.get_end()
		r[0] = out + t.substr(at)

static func gear(a) -> Dictionary:
	if a is XActor:
		for e in a.equip_list():
			if is_gear(e):
				return e
	return {}

## owned：背包与各角色身上的 7940 实例（去重）
static func owned(s: XState) -> Array:
	var out := []
	for e in s.gear:
		if is_gear(e) and base_id(e) == ARMOR:
			out.append(e)
	for a in s.actors.values():
		for e in a.raw_equip_list():
			if is_gear(e) and base_id(e) == ARMOR and not out.any(func(x): return is_same(x, e)):
				out.append(e)
	return out

## H.quality：12，备注里有 14／15 取大的
static func _quality(item: Dictionary) -> int:
	var q := 12
	for m in RegEx.create_from_string("(?i)<quality:\\s*(\\d+)>").search_all(str(item.get("note", ""))):
		if int(m.get_string(1)) in [14, 15]:
			q = maxi(q, int(m.get_string(1)))
	return q

## describe：名字、说明、图标、品质、八项倍率特性、成长行
static func describe(item: Dictionary) -> void:
	if not is_gear(item):
		return
	item.name = NAME
	item.baseName = NAME
	item.description = DESCRIPTION
	item.iconIndex = ICON
	var q := _quality(item)
	var note := RegEx.create_from_string("(?i)<(quality|ici):\\s*\\d+>").sub(str(item.get("note", "")), "", true)
	note += "\n<quality:%d>\n<ici:%d>\n" % [q, q]
	if not item.get("meta") is Dictionary:
		item.meta = {}
	item.meta.quality = str(q)
	item.meta.ici = str(q)
	var rate := 1.0 + XTianqiGear.crown_bonus(bonus(item)) / 100.0  # 天启篇八项加成夹上限（账本里的成长不截）
	var traits: Array = (item.get("traits", []) as Array).filter(func(t): return not bool(t.get("_codexCrown", false)))
	for n in range(8):
		traits.append({"code": 21, "dataId": n, "value": 1.0 if storage_error != "" else rate, "_codexCrown": true})
	item.traits = traits
	note = RegEx.create_from_string("<pos=APs text=成长[：:]八项全属性[^>]*>\\s*").sub(note, "", true)
	item.note = note + "\n<pos=APs text=成长：八项全属性＋%s%%%s size=18 color=rgba(255,255,255,1) line=false align=0>\n" % [display(XTianqiGear.crown_bonus(bonus(item))), XTianqiGear.cap_note("crown_bonus_pct", bonus(item))]


# ---- 账本文件 ----
static func load_ledger():
	var p := path()
	if p == _loaded_path and _ledger != null:
		return _ledger
	var next_l = {"version": 1, "profiles": {}, "legacy": {}}
	if FileAccess.file_exists(p):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(p)) != OK or not json.data is Dictionary:
			return _fail("\"头顶\"成长记录损坏或版本不兼容")
		next_l = json.data
		if int(next_l.get("version", 0)) != 1 or not next_l.get("profiles") is Dictionary:
			return _fail("\"头顶\"成长记录损坏或版本不兼容")
	if not next_l.get("legacy") is Dictionary:
		next_l.legacy = {}
	_ledger = next_l
	_loaded_path = path()
	return _ledger

static func save_ledger(n: Dictionary) -> bool:
	# Codex 审查第 2 项：原来 store_string／close 不查写没写完整，截断的文件照样换上去；现在写不完整就不替换、返回 false
	#（调用方的扣材料都在写成之后的重放里，失败就不扣），替换前留一份上一版 .bak（XSave.write_text_safely）
	if not XSave.write_text_safely(path(), JSON.stringify(n)):
		_fail("\"头顶\"成长记录无法写入")
		return false
	_ledger = n
	_loaded_path = path()
	return true

## 注意：别从外面写 XDemonCrown.reload()——那会调到引擎的 Script.reload，把本类所有静态变量（路径覆盖、开关）清回默认。
## 要丢掉内存里的账本、下次重读文件，用 forget_ledger()。
static func reload() -> void:
	forget_ledger()

static func forget_ledger() -> void:
	_ledger = null
	_loaded_path = "<unloaded>"

## profile()：本档那条；没有编号就新建（云裳编号或旧档身份对上已有的）。编号在、账本里没有＝记录缺失
static func profile(s: XState):
	_for(s)
	var l = load_ledger()
	if l == null:
		return null
	var id := str(s.flags.get(PROFILE_FLAG, ""))
	if id != "" and not (l.profiles as Dictionary).has(id):
		return _fail("此存档的\"头顶\"成长记录缺失")
	if id == "":
		var key := ("yun:" + str(s.flags.get(XYunshangOrders.PROFILE_FLAG))) if str(s.flags.get(XYunshangOrders.PROFILE_FLAG, "")) != "" else _legacy
		id = str(l.legacy.get(key, "")) if key != "" else ""
		if id == "" or not (l.profiles as Dictionary).has(id):
			id = uuid()
			var n: Dictionary = l.duplicate(true)
			n.profiles[id] = {"revision": 0, "items": {}, "battles": {}, "worldDeaths": {}}
			if key != "":
				n.legacy[key] = id
			if not save_ledger(n):
				return null
		s.flags[PROFILE_FLAG] = id
	return _ledger.profiles[id]

## D.record：本档那条的副本（null＝不可用）
static func record(s: XState):
	var p = profile(s)
	return p.duplicate(true) if p != null else null


# ---- 重放 ----
static func _find(s: XState, uid: String) -> Dictionary:
	for e in owned(s):
		if str(e.get(UID, "")) == uid:
			return e
	return {}

static func _known(s: XState) -> Array:
	if not s.flags.get(KNOWN_FLAG) is Array:
		s.flags[KNOWN_FLAG] = []
	return s.flags[KNOWN_FLAG]

static func _remove(s: XState, item: Dictionary) -> void:
	for a in s.actors.values():
		for slot in range(a.equips.size()):
			if a.equips[slot] is Dictionary and is_same(a.equips[slot], item):
				if not XEquipment.change(s, a, slot, null):
					a.equips[slot] = null
					a.refresh_passive()
	var i := s.gear.find_custom(func(e): return is_same(e, item))
	if i >= 0:
		s.gear.remove_at(i)

## grantSpec：同一 uid 已有就只盖成长；本档建过（_codexCrownKnown）但已不在队伍里的不重发
static func _grant(s: XState, r: Dictionary, uid: String) -> void:
	var item := _find(s, uid)
	if item.is_empty():
		if _known(s).has(uid):
			return
		item = (r.spec as Dictionary).duplicate(true)
		item.erase("instanceId")
		item[UID] = uid
		s.register_gear(item)
		s.gear.append(item)
		_known(s).append(uid)
	item[BONUS] = float(r.bonus)
	describe(item)

static func replay(s: XState) -> bool:
	var p = profile(s)
	if p == null:
		return false
	_mutating = true
	for uid in p.items:
		var r: Dictionary = p.items[uid]
		if bool(r.get("removed", false)):
			var it := _find(s, str(uid))
			if not it.is_empty():
				_remove(s, it)
			continue
		_grant(s, r, str(uid))
	for a in s.actors.values():
		if not gear(a).is_empty():
			a.refresh_passive()
			a.param_mark_dirty()  # CodexZones.invalidate：五乘区不移植（O-044／O-050），没有要清的
	XPower.clear_cache()  # CodexCombatPower.clearCache
	_mutating = false
	return true

static func transaction(s: XState, fn: Callable) -> bool:
	if profile(s) == null:
		return false
	var n: Dictionary = _ledger.duplicate(true)
	var p: Dictionary = n.profiles[str(s.flags[PROFILE_FLAG])]
	if COMPACT:
		for q in n.profiles.values():  # 之前结算好的场次折进水位（这次 fn 刚结算的那行留到下次，finish 还要读它的掉落）
			if q is Dictionary:
				fold(q)
	fn.call(p)
	p.revision = int(p.get("revision", 0)) + 1
	return save_ledger(n) and replay(s)

## 把一条档案里已结算的场次折进水位。水位＝从 0 起连续有过行的序号个数（碰到没有行的序号停，不把没打过的序号算进去）；
## 水位以下：已结算、没人倒下的行删掉，已结算、有人倒下过的只留 {settled, deaths}，没结算的原样留着（有行的以行为准）。返回折了几行
static func fold(p: Dictionary) -> int:
	if not p.get("battles") is Dictionary:
		return 0
	var battles: Dictionary = p.battles
	var done := int(p.get(DONE, 0))
	while battles.has("b:%d" % done):
		done += 1
	var folded := 0
	for key in battles.keys():
		var r = battles[key]
		if int(str(key).trim_prefix("b:")) >= done or not r is Dictionary or not bool(r.get("settled", false)):
			continue
		var deaths = r.get("deaths", {})
		if not deaths is Dictionary or deaths.is_empty():
			battles.erase(key)
			folded += 1
		elif r.size() > 2:
			battles[key] = {"settled": true, "deaths": deaths}
			folded += 1
	if done > 0:
		p[DONE] = done
	return folded

static func _has_row(p: Dictionary, key: String) -> bool:
	return (p.battles as Dictionary).has(key) or int(key.trim_prefix("b:")) < int(p.get(DONE, 0))

## 账本里这一场的记录；折掉的＝已结算、没人倒下
static func _row(p: Dictionary, key: String) -> Dictionary:
	if (p.battles as Dictionary).has(key):
		return p.battles[key]
	return {"settled": true, "deaths": {}}

## 本场那一行在写进账本的副本 n 里的样子：还没写的（battle.row）这时放进去，折掉的补一行最小的
static func _materialize(n: Dictionary, b: Dictionary) -> Dictionary:
	if not (n.battles as Dictionary).has(b.key):
		n.battles[b.key] = (b.row as Dictionary).duplicate(true) if b.get("row") != null else {"settled": true, "deaths": {}}
	return n.battles[b.key]


## safely／fail：出错记下、提示一次，已有的魔冠倍率退回 1
static func _safely(s: XState, fn: Callable) -> bool:
	_for(s)
	if storage_error != "":
		return false
	error = ""
	var ok := bool(fn.call())
	if not ok and error != "":
		storage_error = error
		XToast.show_text(STORAGE_TEXT)
		for e in owned(s):
			describe(e)
		for a in s.actors.values():
			if not gear(a).is_empty():
				a.refresh_passive()
				a.param_mark_dirty()
	return ok

static func _spec(s: XState) -> Dictionary:
	var it := XGear.create("armor", ARMOR, s)
	it.erase("instanceId")
	it[BONUS] = 0.0
	describe(it)
	return it

## adopt：没有 uid 的魔冠（旧档）收进账本，成长照实例上的
static func _adopt(s: XState) -> bool:
	var list := owned(s).filter(func(e): return str(e.get(UID, "")) == "")
	if list.is_empty():
		return true
	return transaction(s, func(p):
		for e in list:
			var uid := uuid()
			e[UID] = uid
			_known(s).append(uid)
			var spec: Dictionary = e.duplicate(true)
			spec.erase("instanceId")
			p.items[uid] = {"spec": spec, "bonus": bonus(e), "removed": false})

## 本档还没碰过账本、身上也没有魔冠：不用建（新局不平白写盘；原版 setupNewGame 就建）
static func _idle(s: XState) -> bool:
	return str(s.flags.get(PROFILE_FLAG, "")) == "" and owned(s).is_empty()


# ---- 接线 ----
## gainItem 包装：得到数据库那件改由账本发，返回发了几件
static func grant(s: XState, amount: int) -> int:
	var got := 0
	for i in range(amount):
		var uid := uuid()
		if _safely(s, func(): return transaction(s, func(p): p.items[uid] = {"spec": _spec(s), "bonus": 0.0, "removed": false})):
			got += 1
	return got

static func mutating() -> bool:
	return _mutating

## gainItem 包装：带 uid 的被直接失去，记 removed（重放时移除）；成功返回 true
static func lost(s: XState, item: Dictionary) -> bool:
	var uid := str(item.get(UID, ""))
	if _mutating or uid == "":
		return false
	return _safely(s, func(): return transaction(s, func(p):
		if (p.items as Dictionary).has(uid):
			p.items[uid].removed = true))

## startBattle 包装（原 startBattle 之前）：收编、记穿着的人；掉落战斗或有人穿着才建这一场的账（roll 只在新建且是掉落战斗时调）
static func begin(s: XState, troop: int, roll: Callable) -> void:
	_for(s)
	battle = null
	if storage_error != "" or s == null:
		return
	if _idle(s) and not _drop_battle(s, troop):
		return
	_safely(s, func():
		if not _adopt(s):
			return false
		var wears := []
		for a in s.battle_members():
			var g := gear(a)
			if a.is_alive() and not g.is_empty() and str(g.get(UID, "")) != "":
				wears.append({"actor": int(a.actor_id), "uid": str(g[UID])})
		var eligible := _drop_battle(s, troop)
		if wears.is_empty() and not eligible:
			return true
		var ordinal := int(s.flags.get(SEQ_FLAG, 0))
		var key := "b:%d" % ordinal
		var p = profile(s)
		if p == null:
			return false
		var pending = null
		if not _has_row(p, key):
			var row := {"troop": troop, "map": s.map_id, "eligible": eligible, "roll": float(roll.call()) if eligible else null, "wears": wears, "deaths": {}, "settled": false}
			if COMPACT:
				pending = row  # 先不写盘：结算（或中途有人倒下）时一起写
			elif not transaction(s, func(n): n.battles[key] = row):
				return false
		var r: Dictionary = pending if pending != null else _row(profile(s), key)
		var list := []
		for x in wears:
			list.append({"actor": x.actor, "uid": x.uid, "valid": (r.get("wears", []) as Array).any(func(y): return int(y.actor) == x.actor and str(y.uid) == x.uid)})
		battle = {"key": key, "ordinal": ordinal, "wears": list, "serial": {}, "same": int(r.get("map", -1)) == s.map_id and int(r.get("troop", -1)) == troop, "finished": false, "row": pending}
		return true)

static func _drop_battle(s: XState, troop: int) -> bool:
	return s.map_id == DROP_MAP and troop in DROP_TROOPS and XYunshangOrders.immortal_clear(s, troop)

## endBattle 包装（原 endBattle 之后，最外层）：结算这一场
static func finish(s: XState, result: int) -> void:
	var b = battle
	if b == null or b.finished:
		return
	b.finished = true
	_safely(s, func():
		var p = profile(s)
		if p == null:
			return false
		if b.get("row") == null and not _has_row(p, b.key):
			return _fail("战斗成长记录缺失") != null
		if b.get("row") != null or not bool(_row(p, b.key).settled):
			var members := s.battle_members()
			var winners := (b.wears as Array).filter(func(x):
				var a: XActor = s.actors.get(int(x.actor))
				return bool(x.valid) and a != null and a.is_alive() and members.has(a) and str(gear(a).get(UID, "")) == str(x.uid))
			var ok := transaction(s, func(n):
				var r: Dictionary = _materialize(n, b)
				r.settled = true
				r.result = result
				if result != 0 or not bool(b.same):
					return
				for x in winners:
					var g = n.items.get(str(x.uid))
					if g != null and not bool(g.get("removed", false)):
						g.bonus = next(float(g.bonus))
				if bool(r.eligible) and float(r.roll) < DROP_RATE:
					r.dropUid = uuid()
					n.items[r.dropUid] = {"spec": _spec(s), "bonus": 0.0, "removed": false})
			if not ok:
				return false
			b["row"] = null
			if result == 0 and str(_row(profile(s), b.key).get("dropUid", "")) != "":
				XToast.show_text(DROP_TEXT)
		s.flags[SEQ_FLAG] = int(b.ordinal) + 1
		return true)
	battle = null

## addNewState 包装：穿着的人新倒下，b 减半（战斗中按人按次、战斗外按世界序号各一次）
static func on_death(s: XState, a) -> void:
	if _mutating or s == null or not (a is XActor) or not is_same(s.actors.get(a.actor_id), a) or storage_error != "":
		return
	var g := gear(a)
	var uid := str(g.get(UID, ""))
	if uid == "":
		return
	_safely(s, func():
		var id := int(a.actor_id)
		if battle != null:
			var serial := int(battle.serial.get(id, 0)) + 1
			battle.serial[id] = serial
			var key := "%d:%d:%s" % [id, serial, uid]
			var p = profile(s)
			if p == null:
				return false
			var now: Dictionary = battle.row if battle.get("row") != null else _row(p, battle.key)
			if (now.get("deaths", {}) as Dictionary).has(key):
				return true
			var b: Dictionary = battle
			var done := transaction(s, func(n):
				_materialize(n, b).deaths[key] = true
				var r = n.items.get(uid)
				if r != null and not bool(r.get("removed", false)):
					r.bonus = float(r.bonus) * 0.5)
			if done:
				b["row"] = null  # 这一行已经在账本里了
			return done
		var serial := int(s.flags.get(WORLD_FLAG, 0))
		var key := "w:%d:%d:%s" % [serial, id, uid]
		s.flags[WORLD_FLAG] = serial + 1
		var p = profile(s)
		if p == null:
			return false
		if (p.worldDeaths as Dictionary).has(key):
			return true
		return transaction(s, func(n):
			n.worldDeaths[key] = true
			var r = n.items.get(uid)
			if r != null and not bool(r.get("removed", false)):
				r.bonus = float(r.bonus) * 0.5))

## changeEquip／forceChangeEquip／discardEquip 包装：战斗中换掉了开战穿的那件，这一场不再算
static func equip_changed(a) -> void:
	if battle == null or not (a is XActor):
		return
	var uid := str(gear(a).get(UID, ""))
	for x in battle.wears:
		if int(x.actor) == int(a.actor_id) and str(x.uid) != uid:
			x.valid = false

## makeSaveContents 包装：收编、重放
static func before_save(s: XState) -> void:
	if _mutating or s == null or _idle(s):
		return
	_for(s)
	_safely(s, func(): return _adopt(s) and replay(s))

## extractSaveContents 包装：记旧档身份，收编、重放（本档没碰过账本、也没有魔冠就什么都不做）
static func after_load(s: XState, identity: String) -> void:
	_for(s)
	_legacy = identity
	error = ""
	battle = null
	if _idle(s):
		return
	_safely(s, func(): return profile(s) != null and _adopt(s) and replay(s))

static func identity(text: String) -> String:
	return "legacy:" + text.sha256_text()
