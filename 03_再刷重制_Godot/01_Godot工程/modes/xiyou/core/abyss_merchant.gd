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
	return s.flags[LEDGER_FLAG]


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
	return int(ledger(s).balances.get(key, 0))


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
	l.balances[who.key] = int(l.balances.get(who.key, 0)) + int(c.reward)
	var misses := int(l.misses.get(who.key, 0))
	cur.appeared = misses >= int(c.pity) - 1 or MVEventCore.random_float(s) < float(c.encounterRate)
	l.misses[who.key] = 0 if cur.appeared else misses + 1
	var text := "获得本副本战利品点＋%d。" % int(c.reward) + ((str(who.kind) + "出现了。") if cur.appeared else "")
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
		return "本副本战利品点不足。"
	var list := pool(s, g)
	if list.is_empty():
		return "本分组暂无装备。"
	var random := seed_random(int(cur.seed) + int(cur.used) * 104729)
	var d: Dictionary = _choose(list, random)
	var affix = _choose(candidates(CATEGORIES[tier], str(d.db)), random)
	if affix == null:
		return "对应类别没有可用特效。"
	var made := generate(s, d, affix, random)
	if made.is_empty():
		return "装备生成失败，未扣除点数。"
	ledger(s).balances[key] = balance(s, key) - cost
	cur.used = int(cur.used) + 1
	return made


## M.generate：去掉模板自带的词缀表，换成「这条特效 100%」的前缀，照 DreamX makeItem 生成；随机数全用 random，
## 预掷池（RomDreamX 等）这次从空开始、用完还原
static func generate(s: XState, d: Dictionary, affix: Dictionary, random: Callable) -> Dictionary:
	var kind := "weapon" if str(d.db) == "Weapons" else "armor"
	var blue := XGear.template(kind, int(d.id))
	if blue.is_empty():
		return {}
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
	var made := XGear.roll_item(blue, s)
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
	s.register_gear(made)
	s.gear.append(made)
	return made
