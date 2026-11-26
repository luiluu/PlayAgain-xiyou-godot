class_name XAbyssMerchant
extends RefCounted
## 【cc·八戒·未经审查】深渊／不朽商人（正式西游 v0.30 起 installAbyssMerchantRuntime，CodexAbyssMerchant v30；数据 db/CodexMerchants.json）。
## - 每张商人路线地图（routes）在 Game_Map.setup 时开新一轮 {sequence（全局递增）, claimed, appeared, used, seed}（$gameMap._merchantRun29，这里在 XState.flags）。
## - 开战（BattleManager.startBattle 包装）记本场：地图、敌群是否在路线的 troops 里、身份、本轮序号；endBattle 记胜负（不进存档，同原版闭包变量）。
## - complete（CE1439 末条 355）：本轮没领过、本场胜利且敌群合格、还在同一张图同一轮 → 领点（reward 10）记到身份键上（点数账 $gameSystem._codexMerchants29）；
##   出现＝该身份已连续 pity−1 次没出现，或 Math.random < encounterRate（0.5）；提示「获得本副本战利品点＋10。（深渊商人出现了。）」，出现就打开商人。
## - 身份键：未知存在地图（云裳 unknownBattles）按来源地图分开（「:from:来源」，没有来源用「legacy-变量107」），不朽通关是「immortal:」，其余「abyss:」。
## - hasMerchant：本轮已领且出现 → 商人事件（备注 <CodexMerchant29>）第 2 页成立，不看页面条件（MVEvent._find_page）。
## - draw(档位, 分组)：本轮种子＋已抽次数×104729 的线性同余随机数，先等概率选基础装备、再选本档类别的特效（同库优先），
##   照 DreamX 生成一件必带这条前缀的独立装备，扣点、次数＋1；每轮最多 visitLimit（3）次。出错照原版的提示文字。
## MERCHANT29_FIX（MVEvent，O-286）：新源 v0.62.12 的 33 条 355 把 parameters 存成字符串，原版只 eval 第一个字符，complete 与 openCurrent
## 从不生效（v0.62.13 正式 MOD 已修）；默认按修好的跑，false 回到 v0.62.12 原版（商人永不出现）。

## 按层合账（T224，Kyo 11-18「同一层深渊战利点不再分 boss 计算」；11-19 改每层两份，O-603）：同一层塔里分两份战利品点——
## 深渊一份「layer:层:abyss」（同层各张深渊图共用，如 13 层的 37、38）、未知存在一份「layer:层:unknown」（同层未知存在图，普通和不朽共用，
## 如 152）；只有一张图的层照样按这张图是哪种记。领点、出现保底、商人抽取都按所属那份算，两份互不相通。
## 旧存档里按图／来源／不朽分开的点数，第一次读账时并进对应那份（记在账本 merged 里，每个旧键只并一次）。
## false＝回到原版：每张图、未知存在按来源、不朽另算（已并过的点数不拆回）。
static var LAYER_LEDGER := true
## 地图 → 层（MapInfos 的父链：各深渊挂在哪一层下面；天之上三图合一层；159 单独一张图）
const LAYERS := {37: "13", 38: "13", 152: "13", 50: "15", 51: "15", 160: "15", 52: "17", 53: "17", 161: "17",
	56: "19", 57: "19", 58: "19", 59: "19", 162: "19", 107: "天之上", 110: "天之上", 113: "天之上",
	164: "20", 165: "20", 176: "20", 167: "22", 168: "22", 141: "22", 174: "24", 177: "24", 175: "25",
	184: "26", 223: "26", 211: "28", 210: "28", 216: "29", 159: "159"}

## 按难度、出现概率给点（T224，Kyo 11-19 定 C 方案，O-603，随 LAYER_LEDGER）：同层高难恒多于低难，红柱越少见差距越大，
## 每层按两档出现概率算的期望正好 10（商人 30／90／150 档价不动）。高难＝深渊图是云裳未知存在表里的不朽来源图
## （XYunshangOrders.UNKNOWN 各图的 immortal，如 13 层的 38），未知存在是不朽通关；其余为低难。
## 出现概率（原版各层首领通关事件先掷变量 106＝1 出门，再掷 107 选图；19 层先掷 136 选一对）：13 层高难 1/3 → 低 8、高 14；
## 15～22 层高难 2/3 → 低 8、高 11。同层未知存在两档入口率相同，不朽率＝本层高难图率，用同一行。
## 表外的层（天之上不分高低、单图层、只有不朽的未知存在）每场 REWARD_FLAT。false＝每场照原版 reward（10）。
static var TIERED_REWARD := true
## 层 → [低难, 高难]
const REWARDS := {"13": [8, 14], "15": [8, 11], "17": [8, 11], "19": [8, 11], "20": [8, 11], "22": [8, 11]}
const REWARD_FLAT := 10

const RUN_FLAG := "_merchantRun29"
const LEDGER_FLAG := "_codexMerchants29"
const LABELS := ["Mod特效", "神话特效", "混沌神话特效"]
const CATEGORIES := ["mod", "mythic", "chaos"]

## 本场战斗（原版闭包变量 battle）：{map, troop, eligible, identity, won, run}；不在路线地图开战为空
static var battle: Dictionary = {}
## 商人界面开着（M.active）
static var active := false


static func config() -> Dictionary:
	var c = XDB.table("CodexMerchants")
	return c if c is Dictionary else {}


static func route(map_id: int) -> Dictionary:
	return config().get("routes", {}).get(str(map_id), {})


static func ledger(s: XState) -> Dictionary:
	if not s.flags.get(LEDGER_FLAG) is Dictionary:
		s.flags[LEDGER_FLAG] = {"sequence": 0, "balances": {}, "misses": {}}
	var l: Dictionary = s.flags[LEDGER_FLAG]
	if LAYER_LEDGER:
		merge_layers(l)
	return l


## 本层这张图记哪一份：layer:层:abyss／layer:层:unknown；不在层表里返回空
static func layer_key(map_id: int) -> String:
	if not LAYERS.has(map_id):
		return ""
	return "layer:%s:%s" % [LAYERS[map_id], "unknown" if is_unknown(map_id) else "abyss"]


## 旧键（abyss:地图[:from:来源]、immortal:地图[:from:来源]）→ 所属那份的层键；认不出的地图返回空（不动）
static func layer_key_of(old_key: String) -> String:
	var parts := old_key.split(":")
	if parts.size() < 2 or not (parts[0] == "abyss" or parts[0] == "immortal") or not parts[1].is_valid_int():
		return ""
	return layer_key(int(parts[1]))


## 高难的深渊图：未知存在表里各图的不朽来源
static func high_abyss(map_id: int) -> bool:
	return XYunshangOrders.UNKNOWN.values().any(func(r): return (r.get("immortal", []) as Array).has(map_id))


## 这一场领多少点：按层表取低／高难，表外的层 REWARD_FLAT；关掉时照配置 reward
static func reward_of(who: Dictionary) -> int:
	if LAYER_LEDGER and TIERED_REWARD and who.has("high"):
		var row: Array = REWARDS.get(str(LAYERS.get(int(who.get("map", 0)), "")), [])
		return int(row[1 if bool(who.high) else 0]) if row.size() == 2 else REWARD_FLAT
	return int(config().get("reward", 10))


## 点数名（提示文字用）
static func points_name(key: String) -> String:
	if not LAYER_LEDGER:
		return "本副本战利品点"
	return "本层未知存在战利品点" if ledger_key(key).ends_with(":unknown") else "本层深渊战利品点"


## 把账本里的旧键并进层键：点数相加，保底计数取大；并过的记进 merged（旧键→点数），旧键删掉
static func merge_layers(l: Dictionary) -> void:
	var bal: Dictionary = l.get("balances", {})
	var miss: Dictionary = l.get("misses", {})
	var olds := []
	for k in bal.keys() + miss.keys():
		if not olds.has(k) and layer_key_of(str(k)) != "":
			olds.append(k)
	if olds.is_empty():
		return
	if not l.get("merged") is Dictionary:
		l.merged = {}
	for k in olds:
		var to := layer_key_of(str(k))
		if bal.has(k):
			bal[to] = int(bal.get(to, 0)) + int(bal[k])
			l.merged[k] = int(l.merged.get(k, 0)) + int(bal[k])
			bal.erase(k)
		if miss.has(k):
			miss[to] = maxi(int(miss.get(to, 0)), int(miss[k]))
			miss.erase(k)


static func run(s: XState):
	var r = s.flags.get(RUN_FLAG)
	return r if r is Dictionary else null


## Game_Map.setup 包装（换图时，见 XMapScene._load_map）
static func on_map_setup(s: XState, from: int, to: int) -> void:
	if from == to:
		return
	if not route(to).is_empty():
		var l := ledger(s)
		l.sequence = int(l.sequence) + 1
		s.flags[RUN_FLAG] = {"sequence": l.sequence, "claimed": false, "appeared": false, "used": 0,
			"seed": floori(MVEventCore.random_float(s) * 0x7fffffff)}
	else:
		s.flags.erase(RUN_FLAG)


static func is_unknown(map_id: int) -> bool:
	return XYunshangOrders.UNKNOWN.has(map_id)


static func identity(s: XState, troop: int) -> Dictionary:
	var id := int(s.map_id)
	var origin = s.flags.get(XYunshangOrders.ORIGIN_FLAG)
	if origin == null:
		origin = s.unknown_origin
	var unknown := is_unknown(id)
	var immortal := unknown and XYunshangOrders.immortal_clear(s, troop)
	var key := ("immortal:" if immortal else "abyss:") + str(id)
	if LAYER_LEDGER and LAYERS.has(id):
		return {"key": layer_key(id), "kind": "不朽商人" if immortal else "深渊商人", "map": id,
			"high": immortal if unknown else high_abyss(id)}
	if unknown:
		key += ":from:" + (("legacy-" + str(int(s.variable(107)))) if origin == null else str(int(origin)))
	return {"key": key, "kind": "不朽商人" if immortal else "深渊商人", "map": id}


## BattleManager.startBattle 包装
static func battle_started(s: XState, troop: int) -> void:
	var r := route(int(s.map_id))
	if r.is_empty():
		battle = {}
		return
	var cur = run(s)
	battle = {"map": int(s.map_id), "troop": troop, "eligible": (r.get("troops", []) as Array).any(func(t): return int(t) == troop), "identity": identity(s, troop),
		"won": false, "run": int(cur.sequence) if cur != null else -1}


## BattleManager.endBattle 包装（0 胜利）
static func battle_ended(result: int) -> void:
	if not battle.is_empty():
		battle.won = result == 0


static func has_merchant(s: XState) -> bool:
	var r = run(s) if s != null else null
	return r != null and bool(r.claimed) and bool(r.appeared)


static func balance(s: XState, key: String) -> int:
	return int(ledger(s).balances.get(ledger_key(key), 0))


## 记账用的键：按层合账时旧身份键（升级前就开着的这一轮）也落到所属层
static func ledger_key(key: String) -> String:
	if LAYER_LEDGER:
		var k := layer_key_of(key)
		if k != "":
			return k
	return key


## M.complete(interpreter)：领到点数返回 true；出现时提示后打开商人（interp 为 null 时不开）
static func complete(s: XState, interp = null) -> bool:
	var cur = run(s)
	var r := route(int(s.map_id))
	if cur == null or r.is_empty() or bool(cur.claimed) or battle.is_empty() or not bool(battle.won) or not bool(battle.eligible) \
			or int(battle.map) != int(s.map_id) or int(battle.run) != int(cur.sequence):
		return false
	var c := config()
	var l := ledger(s)
	var who: Dictionary = battle.identity
	cur.claimed = true
	cur.identity = who.duplicate()
	cur.pool = (r.get("pool", []) as Array).duplicate(true)
	var gain := reward_of(who)
	l.balances[who.key] = int(l.balances.get(who.key, 0)) + gain
	var misses := int(l.misses.get(who.key, 0))
	cur.appeared = misses >= int(c.pity) - 1 or MVEventCore.random_float(s) < float(c.encounterRate)
	l.misses[who.key] = 0 if cur.appeared else misses + 1
	# 按层合账时带上这一份现有的点数（Kyo 11-19 清单 3；玩家可见文字，待小A 审）
	var total := ("（本层共 %d 点）" % int(l.balances[who.key])) if LAYER_LEDGER else ""
	var text := "获得%s＋%d%s。" % [points_name(str(who.key)), gain, total] + ((str(who.kind) + "出现了。") if cur.appeared else "")
	if interp != null:
		if interp.host.has_method("refresh_events"):
			interp.host.refresh_events()
		interp.host.toast(text)
		if cur.appeared:
			await open_current(interp)
	return true


## M.openCurrent：有商人且界面没开着时打开（事件停在这条指令上，关掉再往下）
static func open_current(interp) -> bool:
	if not has_merchant(XState.current) or active:
		return false
	active = true
	if interp != null and interp.host.has_method("open_merchant29"):
		await interp.host.open_merchant29()
	active = false
	return true


## group(d)：武器／饰品（装备类型 9～12）／防具
static func group(d: Dictionary) -> String:
	if str(d.db) == "Weapons":
		return "武器"
	return "饰品" if [9, 10, 11, 12].has(int(XDB.rec("Armors", int(d.id)).get("etypeId", 0))) else "防具"


static func item(d: Dictionary) -> Dictionary:
	return XDB.rec(str(d.db), int(d.id))


## M.pool(g)：本轮领点时定下的池（没领过用路线的），按分组筛；g 为空不筛
static func pool(s: XState, g := "") -> Array:
	var cur = run(s)
	var src: Array = cur.pool if cur != null and cur.has("pool") else route(int(s.map_id)).get("pool", [])
	return src.filter(func(d): return g == "" or group(d) == g)


## seedRandom：s = s×1664525＋1013904223（32 位），返回 s／2³²
static func seed_random(seed: int) -> Callable:
	var box := [seed & 0xFFFFFFFF]
	return func() -> float:
		box[0] = (int(box[0]) * 1664525 + 1013904223) & 0xFFFFFFFF
		return float(box[0]) / 4294967296.0


static func _choose(list: Array, random: Callable):
	return list[floori(float(random.call()) * list.size())] if not list.is_empty() else null


static func candidates(cat: String, typ: String) -> Array:
	var all: Array = config().get("affixes", {}).get(cat, [])
	var native := all.filter(func(d): return str(d.db) == typ)
	return native if not native.is_empty() else all


## M.draw(tier, g)：成功返回装备实例，失败返回原版的错误文字（String）
static func draw(s: XState, tier, g := "") -> Variant:
	var cur = run(s)
	if not has_merchant(s) or not cur.has("identity"):
		return "当前没有可交易的商人。"
	if not (tier is int) or tier < 0 or tier > 2:
		return "抽奖档位无效。"
	var c := config()
	var key := str(cur.identity.key)
	var cost := int(c.costs[tier])
	if int(cur.used) >= int(c.visitLimit):
		return "本次商人的抽取次数已用完。"
	if balance(s, key) < cost:
		return points_name(key) + "不足。"
	var list := pool(s, g)
	if list.is_empty():
		return "本分组暂无装备。"
	var random := seed_random(int(cur.seed) + int(cur.used) * 104729)
	var d: Dictionary = _choose(list, random)
	var affix = _choose(candidates(CATEGORIES[tier], str(d.db)), random)
	if affix == null:
		return "对应类别没有可用特效。"
	var made := generate(s, d, affix, random, "abyss|%s" % key)
	if made.is_empty():
		return "装备生成失败，未扣除点数。"
	ledger(s).balances[ledger_key(key)] = balance(s, key) - cost
	cur.used = int(cur.used) + 1
	return made


## M.generate：去掉模板自带的词缀表，换成「这条特效 100%」的前缀，照 DreamX makeItem 生成；随机数全用 random，
## 预掷池（RomDreamX 等）这次从空开始、用完还原
## O-待定-1（T547，Kyo 11-26「深渊的装备也会随机词条」）：西游档商人买的装备保留底装备自带的随机词条行，照普通掉落掷
## （同一张词条表、同样的概率与行数），买的那条特效先合进去、照旧必出；随机数照旧用本轮种子。只管新买的，旧装备不动。
## 天启篇不走这里（XTianqiMerchant）。false＝原版：删掉底装备的词条表，只留买的那一条。
static var KEEP_BASE_AFFIXES := true


static func generate(s: XState, d: Dictionary, affix: Dictionary, random: Callable, source := "") -> Dictionary:
	var kind := "weapon" if str(d.db) == "Weapons" else "armor"
	var blue := XGear.template(kind, int(d.id))
	if blue.is_empty():
		return {}
	var keep := KEEP_BASE_AFFIXES and not XTianqi.active(s)
	var forced := []
	if keep:
		forced = [{"table": str(affix.db), "id": int(affix.id), "kind": "prefix"}]
	else:
		var eq: Dictionary = blue.get("equipment", {}).duplicate(true)
		eq.affixes = [{"kind": "prefix", "choices": [{"chance": 100, "ids": [int(affix.id)]}]}]
		blue.equipment = eq
		var meta: Dictionary = blue.get("meta", {})
		for k in ["prefix", "suffix", "prefixSuffixUseWeaponDatabase", "prefixSuffixUseArmorDatabase"]:
			meta.erase(k)
		meta["prefixSuffixUseArmorDatabase" if str(affix.db) == "Armors" else "prefixSuffixUseWeaponDatabase"] = true
		blue.meta = meta
	var saved := {}
	for k in ["x", "xn", "xs", "xsn"]:
		saved[k] = s.rom.get(k)
	s.rom.x = []
	s.rom.xn = 0
	s.rom.xs = []
	s.rom.xsn = 0
	var saved_fn := XGear.roll_fn
	XGear.roll_fn = random
	var made := XGear.roll_item(blue, s, [], forced)
	XGear.roll_fn = saved_fn
	for k in saved:
		if saved[k] == null:
			s.rom.erase(k)
		else:
			s.rom[k] = saved[k]
	if made.is_empty():
		return {}
	made._codexExtraAffix29 = {"db": str(affix.db), "id": int(affix.id)}
	made._codexMerchant29 = true
	s.register_gear(made, source)
	s.gear.append(made)
	return made
