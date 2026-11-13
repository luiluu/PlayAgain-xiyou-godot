class_name XTianqiReforge
extends RefCounted
## 【cc·天启篇·未经审查】天启篇装备重铸（cc 草案；词条稿 v0.3 第 8.3 节只定了约束：走同一套门槛和栏位分组、不改槽数、
## 能不能重铸出「极」和稀有词条单独定）。表 tianqi_data/reforge.json（draft）。
## - 选背包里（没穿、没锁）一件带天启篇词条的装备，选其中一条：在同一层、这件能出的词条里重抽（不含这件已有的别的词条），成色重新掷。
## - 阶不变（法宝光环的阶照旧随养成），槽数不变；allow_perfect＝能不能出极（草案：能），allow_rare＝能不能抽到连击、再动（草案：不能）。
## - 花金钱：按这条的阶 1000／3000／6000／10000。
## 界面在异化工坊页（天启篇存档）底下「装备重铸」一节。只认天启篇存档（XTianqiAffixRoll.on）。
##
## 开关（O-360）：false＝没有重铸

## 开关：false＝没有重铸
static var ENABLED := true

const PATH := "res://modes/xiyou/tianqi_data/reforge.json"
const T := preload("res://modes/xiyou/core/tianqi_affix_table.gd")
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


## 能重铸的：背包里没穿、没锁、带天启篇词条的装备
static func targets(s: XState) -> Array:
	return XAlienation.owned(s).filter(func(i): return not (i.get("tianqi_affixes", []) as Array).is_empty() and not XAlienation.locked(i) and not XAlienation.bound(s, i))


static func cost(entry: Dictionary) -> int:
	var c: Array = data().get("costs", [])
	return int(c[clampi(int(entry.get("tier", 1)) - 1, 0, c.size() - 1)]) if not c.is_empty() else 0


## 这一条能重铸成的词条
static func choices(item: Dictionary, index: int) -> Array:
	var list: Array = item.get("tianqi_affixes", [])
	if index < 0 or index >= list.size():
		return []
	var layer := str(T.affix(str(list[index].key)).get("layer", ""))
	var others := []
	for i in list.size():
		if i != index:
			others.append(str(list[i].key))
	var tier := int(list[index].get("tier", 1))
	var group := "fabao" if XTianqiAffixRoll.general_artifact(item) else T.slot_group(XTianqiAffixRoll.slot_key(item))
	return T.candidates(layer, group).filter(func(k): return not others.has(k) and T.available(k, tier) \
		and (bool(data().get("allow_rare", false)) or not bool(T.affix(k).get("rare", false))))


## 重铸第 index 条；rng 返回 [0,1)（缺省 randf）。返回 {ok: 新的那条} 或 {error}
static func reforge(s: XState, item: Dictionary, index: int, rng := Callable()) -> Dictionary:
	if not on(s):
		return {"error": "现在不能重铸"}
	if not targets(s).any(func(i): return is_same(i, item)):
		return {"error": "只能重铸背包里没穿、没锁定的装备"}
	var list: Array = (item.get("tianqi_affixes", []) as Array).duplicate(true)
	if index < 0 or index >= list.size():
		return {"error": "没有这条词条"}
	var c := choices(item, index)
	if c.is_empty():
		return {"error": "这条没有别的词条可重铸"}
	var price := cost(list[index])
	if int(s.gold) < price:
		return {"error": "金钱不足（要 %d）" % price}
	if not rng.is_valid():
		rng = func(): return randf()
	var key := XTianqiAffixRoll._pick(c, rng)
	var old: Dictionary = list[index]
	var e := XTianqiAffixRoll._entry(key, int(old.get("tier", 1)), XTianqiAffixRoll.quality_key(item), rng)
	if not bool(data().get("allow_perfect", true)) and str(e.grade) == "perfect":
		e.grade = "fine"
	if bool(old.get("growth", false)):
		e["growth"] = true
	list[index] = e
	s.gain_gold(-price)
	XTianqiAffixRoll.set_affixes(item, list)
	return {"ok": e}
