class_name XTianqiMerchant
extends RefCounted
## 【cc·天启篇·未经审查】天启篇深渊商人的货架（天启篇词条重构设计稿 v0.3 第 8.2 节；价格表 tianqi_data/abyss_shelves.json）。
## 沿用原版的战利品点、每轮次数和「武器／防具／饰品」分组（XAbyssMerchant 的 run／balance／pool／seed_random），货架从三档改成两档：
## - 寻宝（10 点）：本组本路线里能出特效词条的装备（二阶以上、史诗及以上）等概率挑一件，生成时照常掷天启篇词条，再保证带一条特效词条（随机）。
## - 珍藏（60 点；稀有词条 100 点）：先选分组、再指定一条传说词条；本体只从本路线三阶以上、不朽及以上、栏位能出这条的装备里出；
##   生成时照常掷，再保证带这条（成色照常掷，其余槽照常）。本路线没有这样的装备时货架显示不可用并写原因。
## 原来的 Mod／神话／混沌神话三档在天启篇存档里退役（XMerchant29Page 在天启篇存档里换成这两档）。
## 只认天启篇存档（XTianqiAffixRoll.on：天启篇词条开着）。
##
## 开关（O-347）：false＝天启篇存档的深渊商人照原版三档

## 开关：false＝回到原版三档
static var ENABLED := true

const PATH := "res://modes/xiyou/tianqi_data/abyss_shelves.json"
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		if XDataFile.missing(PATH):  # 发行包里没有（没发行的内容，见 发行内容审计.py）
			return {}
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func on(s: XState = null) -> bool:
	return ENABLED and XTianqiAffixRoll.on(s)


static func shelf(key: String) -> Dictionary:
	return data().get(key, {})


## 本组本路线能当这一档本体的装备（d＝路线池里的 {db, id}）
static func bodies(s: XState, g: String, shelf_key: String, affix := "") -> Array:
	var sh := shelf(shelf_key)
	return XAbyssMerchant.pool(s, g).filter(func(d):
		var tpl := XGear.template("weapon" if str(d.db) == "Weapons" else "armor", int(d.id))
		if tpl.is_empty():
			return false
		var q := XTianqiAffixRoll.QUALITY_KEYS.find(XTianqiAffixRoll.quality_key(tpl))
		if sh.has("min_quality") and q < XTianqiAffixRoll.QUALITY_KEYS.find(str(sh.min_quality)):
			return false
		if sh.has("min_tier") and XTianqiAffixRoll.tier_of(tpl) < int(sh.min_tier):
			return false
		var c := XTianqiAffixRoll.layer_candidates(tpl, str(sh.get("layer", "")))
		return not c.is_empty() and (affix == "" or c.has(affix)))


## 珍藏能指定的传说词条：本组本路线够格的装备里能出的，按表里顺序 [{key, name, rare, cost}]
static func collection_choices(s: XState, g: String) -> Array:
	var keys := {}
	for d in bodies(s, g, "collection"):
		var tpl := XGear.template("weapon" if str(d.db) == "Weapons" else "armor", int(d.id))
		for k in XTianqiAffixRoll.layer_candidates(tpl, "legendary"):
			keys[k] = true
	var out := []
	for a in XTianqiAffixTable.affixes("legendary"):
		if keys.has(str(a.key)):
			var rare := bool(a.get("rare", false))
			out.append({"key": str(a.key), "name": str(a.name), "rare": rare, "cost": cost("collection", str(a.key))})
	return out


static func cost(shelf_key: String, affix := "") -> int:
	var sh := shelf(shelf_key)
	if affix != "" and bool(XTianqiAffixTable.affix(affix).get("rare", false)) and sh.has("rare_cost"):
		return int(sh.rare_cost)
	return int(sh.get("cost", 0))


## 抽一件：成功返回装备实例，失败返回错误文字（String）。affix 只给珍藏用
static func draw(s: XState, shelf_key: String, g: String, affix := "") -> Variant:
	var cur = XAbyssMerchant.run(s)
	if not XAbyssMerchant.has_merchant(s) or cur == null or not cur.has("identity"):
		return "当前没有可交易的商人。"
	if shelf(shelf_key).is_empty() or (shelf_key == "collection" and affix == ""):
		return "货架无效。"
	var key := str(cur.identity.key)
	var price := cost(shelf_key, affix)
	if int(cur.used) >= int(XAbyssMerchant.config().visitLimit):
		return "本次商人的抽取次数已用完。"
	if XAbyssMerchant.balance(s, key) < price:
		return "本副本战利品点不足。"
	var list := bodies(s, g, shelf_key, affix)
	if list.is_empty():
		return "本路线没有能出%s的装备。" % ("这条传说词条" if shelf_key == "collection" else "特效词条")
	var random := XAbyssMerchant.seed_random(int(cur.seed) + int(cur.used) * 104729)
	var d: Dictionary = list[mini(floori(float(random.call()) * list.size()), list.size() - 1)]
	var saved_fn := XGear.roll_fn
	XGear.roll_fn = random
	var made := XGear.create("weapon" if str(d.db) == "Weapons" else "armor", int(d.id), s)
	XGear.roll_fn = saved_fn
	if made.is_empty():
		return "装备生成失败，未扣除点数。"
	var want := affix
	if shelf_key == "treasure":
		var have: Array = made.get("tianqi_affixes", [])
		if not have.any(func(a): return str(XTianqiAffixTable.affix(str(a.key)).get("layer", "")) == "special"):
			var cands := XTianqiAffixRoll.layer_candidates(made, "special").filter(func(k): return not have.any(func(a): return str(a.key) == k))
			want = str(XTianqiAffixRoll._pick(cands, random)) if not cands.is_empty() else ""
	if want != "" and not XTianqiAffixRoll.ensure_affix(made, want, random):
		return "装备生成失败，未扣除点数。"
	made._codexMerchant29 = true
	made._tianqiShelf = shelf_key
	s.register_gear(made, "tq_merchant|%s|%s" % [key, shelf_key])  # 来源键：这一位商人这一格货架的第几件
	s.gear.append(made)
	XAbyssMerchant.ledger(s).balances[key] = XAbyssMerchant.balance(s, key) - price
	cur.used = int(cur.used) + 1
	return made
