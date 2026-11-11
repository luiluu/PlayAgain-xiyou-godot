class_name XTianqiAffixTable
extends RefCounted
## 天启篇词条总表（来源：天启篇词条重构设计稿 v0.3），数据在 tianqi_data/affix_table.json。
## 只读查表：不掷随机数、不碰存档、不引用 XDB 或转换产物。掷词条、结算、深渊商人接线是下一步的事。
## 每条词条存「一排数值」；层的 tier_start 决定从第几阶开始出，第 t 阶取这一排从 (t - tier_start) 起的三个数，
## 依次是普通、上品、极（所以上一阶的极＝下一阶的上品）。三种成色的值都在这里现算，表里不展开。
## Python 那边 03_转换工具/天启篇词条表校验.py 用同一套算法校验，改一边要改另一边。

const DATA := "res://modes/xiyou/tianqi_data/affix_table.json"
const GRADES := ["normal", "fine", "perfect"]  # 普通、上品、极
const MAX_TIER := 4

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = d if d is Dictionary else {}
	return _data


## 测试用：换掉表（传空字典＝下次重新读文件）
static func reload(d := {}) -> void:
	_data = d


static func _find(list_key: String, key: String) -> Dictionary:
	for x in data().get(list_key, []):
		if str(x.get("key", "")) == key:
			return x
	return {}


static func affix(key: String) -> Dictionary:
	return _find("affixes", key)


static func affixes(layer := "") -> Array:
	return data().get("affixes", []).filter(func(a): return layer == "" or str(a.layer) == layer)


static func layer(key: String) -> Dictionary:
	return _find("layers", key)


static func tier_start(affix_key: String) -> int:
	var a := affix(affix_key)
	return int(layer(str(a.get("layer", ""))).get("tier_start", 0)) if not a.is_empty() else 0


## 第 tier 阶（1～4）、成色 grade（normal／fine／perfect）的数值；不能出的阶、不认识的键返回 null。
static func value(affix_key: String, tier: int, grade: String) -> Variant:
	var a := affix(affix_key)
	var g := GRADES.find(grade)
	if a.is_empty() or g < 0 or tier < 1 or tier > MAX_TIER:
		return null
	var start := tier_start(affix_key)
	if start <= 0 or tier < start:
		return null
	var vals: Array = a.get("values", [])
	if bool(a.get("fixed", false)):
		return vals[0] if not vals.is_empty() else null
	var i := tier - start + g
	return vals[i] if i < vals.size() else null


## 能不能出：value 不是 null
static func available(affix_key: String, tier: int) -> bool:
	return value(affix_key, tier, "normal") != null


static func tier_of_level(level: int) -> int:
	for t in data().get("tiers", []):
		var hi = t.get("max_level")
		if level >= int(t.min_level) and (hi == null or level <= int(hi)):
			return int(t.tier)
	return 1 if level < 1 else MAX_TIER


## 通用法宝按养成进度分阶：progress＝当前等级／满级（0～1）
static func artifact_tier(progress: float) -> int:
	for step in data().get("artifact_aura", {}).get("tier_by_growth", []):
		var b = step.get("below")
		if b == null or progress < float(b.num) / float(b.den):
			return int(step.tier)
	return MAX_TIER


## 栏位键（weapon、offhand、head、body、hands、waist、legs、feet、necklace、ring、artifact、mount）→ 栏位组键
static func slot_group(slot_key: String) -> String:
	return str(_find("slots", slot_key).get("group", ""))


static func slot_has_aura(slot_key: String) -> bool:
	return bool(_find("slots", slot_key).get("aura", false))


## 某层在某栏位组能出的词条键（按表里的顺序）。光环层只看栏位组能不能出光环，不看标签。
static func candidates(layer_key: String, group_key: String) -> Array:
	var g := _find("slot_groups", group_key)
	if g.is_empty() or not (layer_key in g.get("layers", [])):
		return []
	var tags: Array = g.get("tags", [])
	var out := []
	for a in affixes(layer_key):
		if layer_key == "aura" or str(a.tag) in tags:
			out.append(str(a.key))
	return out


## 难度键（XTianqi.DIFFICULTIES 的 key）→ {base, special, legendary} 三层几率（合计 1）
static func layer_odds(difficulty_key: String) -> Dictionary:
	return data().get("layer_odds", {}).get(difficulty_key, {})


## 品质键（putong、youxiu、jingliang、shishi、chuanshuo、buxiu、shenhua）→ 普通词条槽数
static func slot_count(quality_key: String) -> int:
	return int(_find("qualities", quality_key).get("slots", 0))


static func quality_layers(quality_key: String) -> Array:
	return _find("qualities", quality_key).get("layers", [])


## 不是极时出上品的几率
static func fine_chance(quality_key: String) -> float:
	return float(data().get("grade_odds", {}).get("fine_by_quality", {}).get(quality_key, 0))


static func perfect_chance() -> float:
	return float(data().get("grade_odds", {}).get("perfect", 0))
